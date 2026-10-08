#!/usr/bin/env python3
"""
Extract Quests: XML metadata + Lua scripts + localized text.
Generates lib/campaign_quests.ml

Quest Lua is analyzed statically (no Lua runtime in the port): for each script
we resolve file-scope string constants and pull the QUEST_* calls out of each
top-level function body, so the OCaml side can drive map reveals and OnEnd
rewards directly from extracted data.

Hook grouping (evidence: docs/reverse/evidence.yml campaign.map_visibility,
decompiled Engine_QUEST_SET_VISIBILITY_450e40.c):
  * reveal_on_begin = QUEST_SET_VISIBILITY(...,1) in OnBegin and CallbackConvA*
    (quest accepted / intro conversation callback)
  * reveal_on_end   = calls in every other hook, applied at turn-in until
    conversation callbacks are wired to the quest state machine
  * ruin_reveals    = QUEST_ADD_RUIN targets (OnBegin / CallbackConvA in the
    shipped set; registration happens once, at accept)
  * ruin_dones_*    = QUEST_SET_RUIN_DONE call sites grouped by the hook they
    sit in: OnAbandon fires when the player abandons, OnCompleteAction fires
    after a won quest battle, every other hook fires at turn-in. Deduplicated
    per bucket, so mutually exclusive Lua branches collapse to one release and
    guards (Q0I5's didShrine check) run unconditionally - the same branch
    heuristic as the reward fields, bounded by the engine's no-op on an
    unregistered id.
  * reward_gold/xp  = first call site in file order; if/else reward branches
    are not evaluated (source order puts the if-branch first) - see
    campaign.quest_rewards_conditional
  * reward_items/awards/companions = all call sites (superset on the few
    quests whose branches grant different items)

Paths: quest XML lives in game/Assets/Assets/Quests, but the Script/Text
file= attributes are rooted at game/Assets (Assets\\Quests\\X.lua,
English\\Quests\\X_Text.xml).
"""

import xml.etree.ElementTree as ET
from pathlib import Path
import re
import sys

XML_DIR = Path("game/Assets/Assets/Quests")
ASSETS_ROOT = Path("game/Assets")


# ---------------------------------------------------------------- Lua scan

def scan(src, blank_strings=False):
    """Single-pass scanner over Lua source. Always blanks comments; optionally
    blanks string interiors too. Length-preserving (newlines survive), so
    offsets from the masked pass index the kept pass unchanged."""
    out = list(src)
    n = len(src)

    def blank(a, b):
        for k in range(a, min(b, n)):
            if out[k] != '\n':
                out[k] = ' '

    def long_opener(j):
        """If src[j:] starts a [[-style long bracket, return (level, content_start)."""
        if j < n and src[j] == '[':
            k = j + 1
            while k < n and src[k] == '=':
                k += 1
            if k < n and src[k] == '[':
                return k - j - 1, k + 1
        return None

    i = 0
    while i < n:
        c = src[i]
        if c == '-' and i + 1 < n and src[i + 1] == '-':
            op = long_opener(i + 2)
            if op is not None:
                level, content = op
                close = ']' + '=' * level + ']'
                end = src.find(close, content)
                end = n if end == -1 else end + len(close)
                blank(i, end)
                i = end
            else:
                end = src.find('\n', i)
                end = n if end == -1 else end
                blank(i, end)
                i = end
            continue
        if c in ('"', "'"):
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == c:
                    j += 1
                    break
                if src[j] == '\n':
                    break
                j += 1
            if blank_strings:
                blank(i + 1, j - 1 if j > i + 1 and src[j - 1] == c else j)
            i = j
            continue
        if c == '[':
            op = long_opener(i)
            if op is not None:
                level, content = op
                close = ']' + '=' * level + ']'
                end = src.find(close, content)
                end = n if end == -1 else end + len(close)
                if blank_strings:
                    blank(content, end - len(close))
                i = end
                continue
        i += 1
    return ''.join(out)


def lua_constants(nc):
    """File-scope (first occurrence wins) `local NAME = "VALUE"` bindings."""
    consts = {}
    for m in re.finditer(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*"([^"\n]*)"', nc):
        consts.setdefault(m.group(1), m.group(2))
    return consts


def extract_functions(ns):
    """Map top-level `local function NAME` to body span (start, end) in the
    shared offset space. Block structure tracked with Lua's real openers:
    function/if/do open, end/until close (for/while pair with their `do`)."""
    toks = [(m.group(0), m.start()) for m in re.finditer(r'[A-Za-z_]\w*', ns)]
    funcs = {}
    stack = []  # (kind, name, body_start)
    for idx, (tok, pos) in enumerate(toks):
        if tok in ('function', 'if', 'do', 'repeat'):
            name = None
            body_start = pos
            if tok == 'function' and idx >= 2 and toks[idx - 1][0] == 'local' \
                    and idx + 1 < len(toks):
                name = toks[idx + 1][0]
                body_start = toks[idx + 1][1] + len(name)
            stack.append((tok, name, body_start))
        elif tok in ('end', 'until'):
            if not stack:
                continue
            kind, name, body_start = stack.pop()
            if kind == 'function' and name and not stack:
                funcs[name] = (body_start, pos)
    return funcs


CALL_PATTERNS = {
    # second arg defaults to 1 when omitted (e.g. Q2Q3: QUEST_SET_VISIBILITY(x))
    'visibility': re.compile(
        r'QUEST_SET_VISIBILITY\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*(?:,\s*(\d+)\s*)?\)'),
    'add_ruin': re.compile(
        r'QUEST_ADD_RUIN\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*\)'),
    'set_ruin_done': re.compile(
        r'QUEST_SET_RUIN_DONE\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*\)'),
    'gold': re.compile(r'QUEST_REWARD_GOLD\s*\(\s*(\d+)\s*\)'),
    'xp': re.compile(r'QUEST_REWARD_XP\s*\(\s*(\d+)\s*\)'),
    'item': re.compile(
        r'QUEST_REWARD_ITEM\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*\)'),
    'award': re.compile(
        r'QUEST_ADD_AWARD\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*\)'),
    'companion': re.compile(
        r'QUEST_ADD_COMPANION\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*\)'),
}
# raw counts: the call name and open paren, whatever the arguments look like
RAW_RE = {k: re.compile(v.pattern.split(r'\s*\(')[0] + r'\s*\(')
          for k, v in CALL_PATTERNS.items()}


def resolve(tok, consts):
    if tok.startswith('"'):
        return tok[1:-1]
    return consts.get(tok)


def dedup(items):
    seen = set()
    out = []
    for x in items:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out


def reveal_bucket(hook):
    if hook == 'OnBegin' or hook.startswith('CallbackConvA'):
        return 'begin'
    return 'end'


def ruin_done_bucket(hook):
    """Which engine event runs this hook's QUEST_SET_RUIN_DONE calls:
    OnAbandon on abandon, OnCompleteAction after a won battle, everything
    else at turn-in (OnEnd plus any stray conversation callback)."""
    if hook == 'OnAbandon':
        return 'abandon'
    if hook == 'OnCompleteAction':
        return 'battle'
    return 'end'


def analyze_lua(src, qid, stats):
    """Returns reveal/reward fields extracted from one quest script."""
    nc = scan(src, blank_strings=False)
    ns = scan(src, blank_strings=True)
    consts = lua_constants(nc)
    funcs = extract_functions(ns)

    # raw call counts for --check reconciliation
    for kind, rx in RAW_RE.items():
        stats['raw'][kind] += len(rx.findall(nc))

    reveals = {'begin': [], 'end': []}
    ruins = []
    ruin_dones = {'end': [], 'battle': [], 'abandon': []}
    gold = xp = 0
    items, awards, companions = [], [], []

    for hook, (start, end) in funcs.items():
        body = nc[start:end]
        m = CALL_PATTERNS['visibility'].finditer(body)
        for hit in m:
            stats['extracted']['visibility'] += 1
            stats['hooks'][('visibility', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            if int(hit.group(2) or "1") == 1:
                reveals[reveal_bucket(hook)].append(target)
        for hit in CALL_PATTERNS['add_ruin'].finditer(body):
            stats['extracted']['add_ruin'] += 1
            stats['hooks'][('add_ruin', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            ruins.append(target)
        for hit in CALL_PATTERNS['set_ruin_done'].finditer(body):
            stats['extracted']['set_ruin_done'] += 1
            stats['hooks'][('set_ruin_done', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            ruin_dones[ruin_done_bucket(hook)].append(target)
        for hit in CALL_PATTERNS['gold'].finditer(body):
            stats['extracted']['gold'] += 1
            stats['hooks'][('gold', hook)] += 1
            if gold == 0:
                gold = int(hit.group(1))
        for hit in CALL_PATTERNS['xp'].finditer(body):
            stats['extracted']['xp'] += 1
            stats['hooks'][('xp', hook)] += 1
            if xp == 0:
                xp = int(hit.group(1))
        for hit in CALL_PATTERNS['item'].finditer(body):
            stats['extracted']['item'] += 1
            stats['hooks'][('item', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            items.append(target)
        for hit in CALL_PATTERNS['award'].finditer(body):
            stats['extracted']['award'] += 1
            stats['hooks'][('award', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            awards.append(target)
        for hit in CALL_PATTERNS['companion'].finditer(body):
            stats['extracted']['companion'] += 1
            stats['hooks'][('companion', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            companions.append(target)

    return {
        'reveal_on_begin': dedup(reveals['begin']),
        'reveal_on_end': dedup(reveals['end']),
        'ruin_reveals': dedup(ruins),
        'ruin_dones_on_end': dedup(ruin_dones['end']),
        'ruin_dones_on_battle': dedup(ruin_dones['battle']),
        'ruin_dones_on_abandon': dedup(ruin_dones['abandon']),
        'reward_gold': gold,
        'reward_xp': xp,
        'reward_items': dedup(items),
        'reward_awards': dedup(awards),
        'reward_companions': dedup(companions),
    }


# ---------------------------------------------------------------- XML

def parse_quest_text(xml_path):
    """Parse the localized text XML for a quest."""
    if not xml_path.exists():
        return {}
    tree = ET.parse(xml_path)
    root = tree.getroot()
    texts = {}
    for text_elem in root.findall("Text"):
        tag = text_elem.get("tag")
        content = text_elem.text or ""
        texts[tag] = content
    return texts


def parse_quest(xml_path, stats):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    qid = root.get("id")
    text_elem = root.find("Text")
    script_elem = root.find("Script")
    data_elem = root.find("Data")
    avail_elem = root.find("Available")
    battle_elem = root.find("Battle")

    # file= attrs are rooted at game/Assets
    text_file = text_elem.get("file") if text_elem is not None else None
    texts = {}
    if text_file:
        texts = parse_quest_text(ASSETS_ROOT / text_file.replace("\\", "/"))

    lua_source = ""
    if script_elem is not None:
        lua_path = ASSETS_ROOT / script_elem.get("file").replace("\\", "/")
        if lua_path.exists():
            lua_source = lua_path.read_text(encoding="utf-8")
        else:
            stats['missing_lua'].append(str(lua_path))

    lua_fields = analyze_lua(lua_source, qid, stats) if lua_source else {
        'reveal_on_begin': [], 'reveal_on_end': [], 'ruin_reveals': [],
        'ruin_dones_on_end': [], 'ruin_dones_on_battle': [],
        'ruin_dones_on_abandon': [],
        'reward_gold': 0, 'reward_xp': 0, 'reward_items': [],
        'reward_awards': [], 'reward_companions': [],
    }

    return {
        "id": qid,
        "name_text": text_elem.get("name") if text_elem is not None else "",
        "desc_text": text_elem.get("description") if text_elem is not None else "",
        "group": text_elem.get("group") if text_elem is not None else "",
        "text_file": text_file if text_file else "",
        "texts": texts,
        "lua_file": script_elem.get("file") if script_elem is not None else "",
        "lua_object": script_elem.get("object") if script_elem is not None else "",
        "lua_source": lua_source,
        "abandonable": data_elem.get("abandon") == "yes" if data_elem is not None else False,
        "icon": int(data_elem.get("icon")) if data_elem is not None else 0,
        "important": data_elem.get("important") == "yes" if data_elem is not None else False,
        "avail_location": avail_elem.get("location") if avail_elem is not None else "",
        "avail_minlevel": int(avail_elem.get("minlevel")) if avail_elem is not None else 0,
        "avail_maxlevel": int(avail_elem.get("maxlevel")) if avail_elem is not None else 1000,
        "avail_repeat": int(avail_elem.get("repeat")) if avail_elem is not None else 0,
        "avail_donequest0": avail_elem.get("donequest0") if avail_elem is not None else "",
        "avail_donequest1": avail_elem.get("donequest1") if avail_elem is not None else "",
        "avail_donequest2": avail_elem.get("donequest2") if avail_elem is not None else "",
        "avail_notdonequest": avail_elem.get("notdonequest") if avail_elem is not None else "",
        "avail_notactivequest": avail_elem.get("notactivequest") if avail_elem is not None else "",
        "avail_companion0": avail_elem.get("companion0") if avail_elem is not None else "",
        "avail_companion1": avail_elem.get("companion1") if avail_elem is not None else "",
        "avail_notcompanion": avail_elem.get("notcompanion") if avail_elem is not None else "",
        "avail_item": avail_elem.get("item") if avail_elem is not None else "",
        "avail_notitem": avail_elem.get("notitem") if avail_elem is not None else "",
        "avail_award": avail_elem.get("award") if avail_elem is not None else "",
        "avail_notaward": avail_elem.get("notaward") if avail_elem is not None else "",
        "battle_monster": battle_elem.get("monster") if battle_elem is not None else "",
        "battle_spells": [sp.get("id") for sp in battle_elem.findall("Spell")] if battle_elem is not None else [],
        **lua_fields,
    }


# ---------------------------------------------------------------- emit

def ocaml_str(s):
    return (s.replace('\\', '\\\\').replace('"', '\\"')
             .replace('\r', '').replace('\n', '\\n'))


def ocaml_list(items):
    if not items:
        return "[]"
    return "[" + "; ".join('"%s"' % ocaml_str(i) for i in items) + "]"


def ocaml_lua(source):
    if not source:
        return '""'
    parts = ['"%s"' % ocaml_str(line)
             for line in source.splitlines(keepends=True)]
    if not parts:
        return '""'
    return ' ^\n      '.join(parts)


def new_stats():
    from collections import Counter
    return {'raw': Counter(), 'extracted': Counter(), 'hooks': Counter(),
            'unresolved': [], 'missing_lua': []}


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", default="lib/campaign_quests.ml")
    args = parser.parse_args()

    stats = new_stats()
    quests = []
    for xml in sorted(XML_DIR.glob("Q*.xml")):
        quests.append(parse_quest(xml, stats))

    with_lua = sum(1 for q in quests if q["lua_source"])
    with_texts = sum(1 for q in quests if q["texts"])
    text_tags = sum(len(q["texts"]) for q in quests)

    if args.check:
        print(f"Quests: {len(quests)}")
        print(f"lua sources loaded: {with_lua}/{len(quests)}")
        print(f"texts loaded: {with_texts}/{len(quests)} quests, {text_tags} tags")
        if stats['missing_lua']:
            print("MISSING LUA:")
            for p in stats['missing_lua']:
                print(f"  {p}")
        print("call reconciliation (raw -> extracted in function bodies):")
        for kind in CALL_PATTERNS:
            print(f"  {kind}: {stats['raw'][kind]} -> {stats['extracted'][kind]}")
        print("by hook:")
        for (kind, hook), n in sorted(stats['hooks'].items()):
            print(f"  {kind:11s} {hook}: {n}")
        if stats['unresolved']:
            print(f"UNRESOLVED targets ({len(stats['unresolved'])}):")
            for qid, hook, tok in stats['unresolved']:
                print(f"  {qid} {hook}: {tok}")
        print("")
        for q in quests:
            print(f"  {q['id']}: {q['name_text']} avail@{q['avail_location']} "
                  f"lvl{q['avail_minlevel']}-{q['avail_maxlevel']} "
                  f"monster={q['battle_monster']} spells={q['battle_spells']}")
            print(f"    reveal_begin={q['reveal_on_begin']} reveal_end={q['reveal_on_end']} "
                  f"ruins={q['ruin_reveals']}")
            print(f"    ruin_dones: end={q['ruin_dones_on_end']} "
                  f"battle={q['ruin_dones_on_battle']} "
                  f"abandon={q['ruin_dones_on_abandon']}")
            print(f"    reward: gold={q['reward_gold']} xp={q['reward_xp']} "
                  f"items={q['reward_items']} awards={q['reward_awards']} "
                  f"companions={q['reward_companions']}")
            if q['texts']:
                for tag, txt in list(q['texts'].items())[:2]:
                    print(f"    {tag}: {txt[:60]}")
        return

    lines = []
    lines.append("(* Generated by tools/extract_quests.py — do not edit *)")
    lines.append("")
    lines.append("type quest = {")
    lines.append("  id: string;")
    lines.append("  name_text: string;")
    lines.append("  desc_text: string;")
    lines.append("  group: string;")
    lines.append("  text_file: string;")
    lines.append("  texts: (string * string) list;")
    lines.append("  lua_file: string;")
    lines.append("  lua_object: string;")
    lines.append("  lua_source: string;")
    lines.append("  abandonable: bool;")
    lines.append("  icon: int;")
    lines.append("  important: bool;")
    lines.append("  avail_location: string;")
    lines.append("  avail_minlevel: int;")
    lines.append("  avail_maxlevel: int;")
    lines.append("  avail_repeat: int;")
    lines.append("  avail_donequest0: string;")
    lines.append("  avail_donequest1: string;")
    lines.append("  avail_donequest2: string;")
    lines.append("  avail_notdonequest: string;")
    lines.append("  avail_notactivequest: string;")
    lines.append("  avail_companion0: string;")
    lines.append("  avail_companion1: string;")
    lines.append("  avail_notcompanion: string;")
    lines.append("  avail_item: string;")
    lines.append("  avail_notitem: string;")
    lines.append("  avail_award: string;")
    lines.append("  avail_notaward: string;")
    lines.append("  battle_monster: string;")
    lines.append("  battle_spells: string list;")
    lines.append("  reveal_on_begin: string list;")
    lines.append("  reveal_on_end: string list;")
    lines.append("  ruin_reveals: string list;")
    lines.append("  ruin_dones_on_end: string list;")
    lines.append("  ruin_dones_on_battle: string list;")
    lines.append("  ruin_dones_on_abandon: string list;")
    lines.append("  reward_gold: int;")
    lines.append("  reward_xp: int;")
    lines.append("  reward_items: string list;")
    lines.append("  reward_awards: string list;")
    lines.append("  reward_companions: string list;")
    lines.append("}")
    lines.append("")

    lines.append("let quests = [")
    for q in quests:
        texts_list = "[" + "; ".join(
            '("%s", "%s")' % (ocaml_str(k), ocaml_str(v))
            for k, v in q["texts"].items()) + "]"
        lines.append("  {")
        lines.append(f'    id = "{q["id"]}";')
        lines.append(f'    name_text = "{ocaml_str(q["name_text"])}";')
        lines.append(f'    desc_text = "{ocaml_str(q["desc_text"])}";')
        lines.append(f'    group = "{ocaml_str(q["group"])}";')
        lines.append(f'    text_file = "{q["text_file"].replace(chr(92), chr(92)+chr(92))}";')
        lines.append(f"    texts = {texts_list};")
        lines.append(f'    lua_file = "{q["lua_file"].replace(chr(92), chr(92)+chr(92))}";')
        lines.append(f'    lua_object = "{q["lua_object"]}";')
        lines.append(f"    lua_source = {ocaml_lua(q['lua_source'])};")
        lines.append(f'    abandonable = {str(q["abandonable"]).lower()};')
        lines.append(f'    icon = {q["icon"]};')
        lines.append(f'    important = {str(q["important"]).lower()};')
        lines.append(f'    avail_location = "{q["avail_location"]}";')
        lines.append(f'    avail_minlevel = {q["avail_minlevel"]};')
        lines.append(f'    avail_maxlevel = {q["avail_maxlevel"]};')
        lines.append(f'    avail_repeat = {q["avail_repeat"]};')
        lines.append(f'    avail_donequest0 = "{q["avail_donequest0"]}";')
        lines.append(f'    avail_donequest1 = "{q["avail_donequest1"]}";')
        lines.append(f'    avail_donequest2 = "{q["avail_donequest2"]}";')
        lines.append(f'    avail_notdonequest = "{q["avail_notdonequest"]}";')
        lines.append(f'    avail_notactivequest = "{q["avail_notactivequest"]}";')
        lines.append(f'    avail_companion0 = "{q["avail_companion0"]}";')
        lines.append(f'    avail_companion1 = "{q["avail_companion1"]}";')
        lines.append(f'    avail_notcompanion = "{q["avail_notcompanion"]}";')
        lines.append(f'    avail_item = "{q["avail_item"]}";')
        lines.append(f'    avail_notitem = "{q["avail_notitem"]}";')
        lines.append(f'    avail_award = "{q["avail_award"]}";')
        lines.append(f'    avail_notaward = "{q["avail_notaward"]}";')
        lines.append(f'    battle_monster = "{q["battle_monster"]}";')
        lines.append(f'    battle_spells = {ocaml_list(q["battle_spells"])};')
        lines.append(f'    reveal_on_begin = {ocaml_list(q["reveal_on_begin"])};')
        lines.append(f'    reveal_on_end = {ocaml_list(q["reveal_on_end"])};')
        lines.append(f'    ruin_reveals = {ocaml_list(q["ruin_reveals"])};')
        lines.append(f'    ruin_dones_on_end = {ocaml_list(q["ruin_dones_on_end"])};')
        lines.append(f'    ruin_dones_on_battle = {ocaml_list(q["ruin_dones_on_battle"])};')
        lines.append(f'    ruin_dones_on_abandon = {ocaml_list(q["ruin_dones_on_abandon"])};')
        lines.append(f'    reward_gold = {q["reward_gold"]};')
        lines.append(f'    reward_xp = {q["reward_xp"]};')
        lines.append(f'    reward_items = {ocaml_list(q["reward_items"])};')
        lines.append(f'    reward_awards = {ocaml_list(q["reward_awards"])};')
        lines.append(f'    reward_companions = {ocaml_list(q["reward_companions"])};')
        lines.append("  };")
    lines.append("]")
    lines.append("")

    lines.append("let quest_by_id id = List.find (fun q -> q.id = id) quests")
    lines.append("let quests_at_location loc = List.filter (fun q -> q.avail_location = loc) quests")
    lines.append("")
    # The quest's own *_Text.xml has the step lines but not [QUEST_X_NAME] -
    # titles and descriptions live in English/StandardQuestsText.xml, so an
    # unknown tag falls through to the global table rather than returning the
    # tag (see tools/extract_text_tables.py).
    lines.append("let quest_text q tag = try List.assoc tag q.texts with Not_found -> Text_data.text tag")
    lines.append("let quest_name q = quest_text q q.name_text")
    lines.append("let quest_desc q = quest_text q q.desc_text")
    lines.append("")

    Path(args.output).write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
