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
  * reward_gold/xp  = first call site in file order among the engine hooks;
    if/else reward branches are not evaluated (source order puts the
    if-branch first) - see campaign.quest_rewards_conditional
  * reward_items/awards/companions = all engine-hook call sites (superset on
    the few quests whose branches grant different items). Reward calls inside
    conversation/message callbacks are NOT in these turn-in buckets: they are
    extracted per callback (callback_effects) and apply when the dialogue
    fires the scriptcall, so nothing double-applies.
  * conversations_begin/abandon = QUEST_CONVERSATION sites in OnBegin (intro
    - fired at accept; branches take the first source-order tree) and
    OnAbandon. conversation_callbacks carries the sites inside callbacks
    (fired when the dialogue runs that scriptcall).
  * query_actions = OnQueryAction's menu label per branch: (state, location,
    text tag), source order, first match wins at runtime; -1 / "" are the
    wildcards for untested guards (Q3Q1 has no questState test).
  * enter/execute/complete/end_effects = the location-action flow, one
    effect group per open-if guard key: OnEnterLocation (arrival),
    OnExecuteAction (the player starts the action here), OnCompleteAction
    (return from the action, keyed with the success side; -1 = either) and
    OnEnd (turn-in, state guard only). Groups carry Conversation,
    ShowMessage, SetQuestState and Complete rows attributed by the branch
    Lua would run - see make_guard_lookup / resolve_message. OnCancelAction
    sites are counted but not stored (no cancel event in the port yet).
  * callback_effects = the non-battle half of each callback body, keyed
    (quest, callback): questState writes (first source order), QUEST_COMPLETE
    (ends the quest: OnEnd runs as at turn-in), reward calls, nested
    QUEST_CONVERSATION, and QUEST_MESSAGE(_CALLBACK) as ShowMessage (title +
    text tags, callback name) - queued when the dialogue fires the scriptcall.
    QUEST_UPDATE_MAP
    and QUEST_STOP_MOVEMENT are skipped (bookkeeping the port's own state
    already carries), and other Lua locals (triedNecro, didShrine, ...) are
    not tracked - their guards are unevaluated anyway.
  * battles/battle_actions/battle_stage_advances/battle_stage_fails = the
    quest-battle loop. Every QUEST_BATTLE / _NOCAPTURE / _CUSTOM call, from
    any hook (OnExecuteAction for location actions, conversation callbacks
    for script-driven fights), is attributed to its questState guard by a
    block scanner over if/elseif/else/end (see scan_battle_branches); the
    second argument indexes the quest's ordered Battle list, and capture
    comes from the primitive - the third argument disagrees on some sites
    (Q0Q2 passes 1 to QUEST_BATTLE_NOCAPTURE) and the primitive wins, per
    evidence campaign.capture_eligible. OnCompleteAction's success/else
    sides give the post-battle transitions: win-side questState = N feeds
    battle_stage_advances, else-side feeds battle_stage_fails. Where a
    stage has two win-side values the first source-order one wins (Q1E0's
    location split); calls without a questState guard (most conversation
    callbacks, Q3D1's range guard, QS02's currBattle index) and range
    guards are listed by --check, and the OCaml side falls back to
    stage + 1 on win and no change on loss for anything missing.

Paths: quest XML lives in game/Assets/Assets/Quests, but the Script/Text
file= attributes are rooted at game/Assets (Assets\\Quests\\X.lua,
English\\Quests\\X_Text.xml).
"""

import xml.etree.ElementTree as ET
from pathlib import Path
import re
import os
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
    'remove_companion': re.compile(
        r'QUEST_REMOVE_COMPANION\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)\s*\)'),
    'conversation': re.compile(
        r'QUEST_CONVERSATION\s*\(\s*("[^"\n]*"|[A-Za-z_]\w*)'),
    'complete': re.compile(r'QUEST_COMPLETE\s*\('),
    # groups: callback flag, title arg, text arg, location arg, quest id
    # token, callback name token (the last two only on the _CALLBACK form;
    # both may be a literal or a file constant like myCode).
    'message': re.compile(
        r'QUEST_MESSAGE(_CALLBACK)?\s*\(\s*([^,]+),\s*([^,]+),\s*([^,)]*?)'
        r'(?:\s*,\s*("[^"\n]*"|[A-Za-z_]\w*)\s*,\s*'
        r'("[^"\n]*"|[A-Za-z_]\w*)\s*)?\)'),
    # OnQueryAction's menu label: `return GET_TEXT("[TAG]")`. Also matches
    # OnSave's step-text returns - counted as query_elsewhere.
    'query': re.compile(r'return\s+GET_TEXT\s*\(\s*"(\[[^"\n]*\])"\s*\)'),
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


def conversation_id(path):
    """Assets\\Conversations\\Conv_X.xml -> Conv_X (the id the conversation
    table is keyed by)."""
    name = path.replace('\\', '/').rsplit('/', 1)[-1]
    if name.lower().endswith('.xml'):
        name = name[:-4]
    return name


# QUEST_CONVERSATION sites grouped by the engine event that runs their hook.
# OnBegin / OnAbandon stay flat string lists (no guards to attribute); the
# location-action events (enter/execute/complete) are folded into the
# unified effect groups below so one runtime fold fires conversations,
# messages, state writes and completes together under one guard.
CONV_BUCKETS = {
    'OnBegin': 'begin',
    'OnAbandon': 'abandon',
}
ACTION_HOOKS = {
    'OnEnterLocation': 'enter',
    'OnExecuteAction': 'execute',
    'OnCompleteAction': 'complete',
    'OnEnd': 'end',
}

# message-argument variable assignments: `local myTitle = GET_TEXT("[T]")`,
# bare `myMessage = GET_TEXT("[T]")`, or a plain string literal binding.
MSG_ASSIGN = re.compile(
    r'(?:local\s+)?([A-Za-z_]\w*)\s*=\s*'
    r'(?:GET_TEXT\s*\(\s*"(\[[^"\n]*\])"\s*\)|"(\[[^"\n]*\])")')


# ---------------------------------------------------------------- quest battles
#
# One pass over a hook body attributes QUEST_BATTLE* calls and (for
# OnCompleteAction) questState assignments to the branch Lua would evaluate:
# a frame stack over if/elseif/else/end (plus do/function/repeat as opaque
# frames) so compound headers like `idLocation==X and questState==2` and
# multi-stage headers like `questState==3 or questState==4` resolve the way
# the script means them, and an assignment inside `if (success == 1)` stays
# on the win side even when a nested if/else splits it (Q1E0).
#
# The polarity of the success test matters: `success == 1` opens the win
# branch and `success == 0` the fail branch (Q3Q5, Q1Q0, Q3Q2, Q0I6, Q0Q7
# invert it), and an elseif/else that carries no success test of its own
# runs only when the chain's last success test failed - so after
# `if (success == 0)` every later branch of that chain is the win side.
# A frame remembers both the side of the branch currently open and the side
# of the last success test in its chain to compute that.

BATTLE_CALL = re.compile(
    r'QUEST_BATTLE(\w*)\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*|\d+)\s*,\s*(\d+)')
STATE_ASSIGN = re.compile(r'questState\s*=\s*(\d+)')
STATE_EQ = re.compile(r'questState\s*==\s*(\d+)')
IDLOC_EQ = re.compile(r'idLocation\s*==\s*("[^"\n]*"|[A-Za-z_]\w*)')
LUA_KW = re.compile(r'\b(if|then|else|elseif|end|do|function|repeat|until)\b')


def success_side(header):
    """'win' / 'fail' when the header tests success: `success == 1` opens the
    win branch, `success == 0` the fail branch; None when it does not."""
    m = re.search(r'success\s*==\s*(\d+)', header)
    if m is None:
        return None
    return 'win' if int(m.group(1)) != 0 else 'fail'


def flip_side(side):
    return 'fail' if side == 'win' else 'win'


def scan_battle_branches(body_ns, body_nc, collect_assigns):
    """Returns (calls, assigns) in source order. calls are
    (full_name, index_arg, third_arg, stages | None); assigns are
    (value, side, stage | None). stage is None when no questState== guard
    covers the event; side is 'win' / 'fail' / 'none'."""
    kws = [(m.group(1), m.start()) for m in LUA_KW.finditer(body_ns)]
    events = [(m.start(), 'call', m) for m in BATTLE_CALL.finditer(body_ns)]
    if collect_assigns:
        events += [(m.start(), 'assign', m) for m in STATE_ASSIGN.finditer(body_ns)]
    events.sort(key=lambda t: t[0])

    stack = []  # {'stages': [int] | None, 'side': 'win'|'fail'|None,
                #  'chain': 'win'|'fail'|None, 'generic': bool}
                # side is the branch currently open at this frame, chain the
                # side of the last success test in the frame's if/elseif
                # chain (later branches run under its negation).
    calls, assigns = [], []
    ei = 0

    def active_stages():
        for fr in reversed(stack):
            if not fr['generic'] and fr['stages']:
                return list(fr['stages'])
        return None

    def side():
        for fr in reversed(stack):
            if not fr['generic'] and fr['side'] is not None:
                return fr['side']
        return 'none'

    def header_at(pos):
        then = next((p for k, p in kws if k == 'then' and p > pos), len(body_ns))
        return body_nc[pos:then]

    def flush(p, kind, m):
        if kind == 'call':
            stages = active_stages()
            calls.append(("QUEST_BATTLE" + m.group(1), m.group(3),
                          int(m.group(4)), stages))
        else:
            assigns.append((int(m.group(1)), side(), active_stages()))

    for k, pos in kws:
        while ei < len(events) and events[ei][0] < pos:
            flush(*events[ei])
            ei += 1
        if k == 'if':
            header = header_at(pos)
            s = success_side(header)
            stack.append({
                'stages': [int(x) for x in STATE_EQ.findall(header)],
                'side': s,
                'chain': s,
                'generic': False,
            })
        elif k == 'elseif' and stack and not stack[-1]['generic']:
            header = header_at(pos)
            fr = stack[-1]
            fr['stages'] = [int(x) for x in STATE_EQ.findall(header)]
            s = success_side(header)
            if s is not None:
                fr['chain'] = s
                fr['side'] = s
            else:
                fr['side'] = flip_side(fr['chain']) if fr['chain'] else None
        elif k == 'else' and stack and not stack[-1]['generic']:
            fr = stack[-1]
            fr['stages'] = []
            fr['side'] = flip_side(fr['chain']) if fr['chain'] else None
        elif k in ('do', 'function', 'repeat'):
            stack.append({'stages': None, 'side': None, 'chain': None,
                          'generic': True})
        elif k in ('end', 'until'):
            if stack:
                stack.pop()
    while ei < len(events):
        flush(*events[ei])
        ei += 1
    return calls, assigns


def header_states(header, s_max):
    """questState tests in one if-header -> the finite state set they allow.
    `==`/`>`/`>=`/`<`/`<=` expand (the open range tops out at s_max, the
    file's highest state value + 1 - states below 1 do not exist); `~=`  negates, subtracted when positives exist, complemented when alone.
    No test -> []."""
    pos, neg = [], set()
    for m in re.finditer(r'questState\s*(==|~=|>=|<=|>|<)?\s*(\d+)', header):
        op = m.group(1) or '=='
        n = int(m.group(2))
        if op == '==':
            pos.append(n)
        elif op == '>':
            pos.extend(range(n + 1, s_max + 1))
        elif op == '>=':
            pos.extend(range(n, s_max + 1))
        elif op == '<':
            pos.extend(range(1, n))
        elif op == '<=':
            pos.extend(range(1, n + 1))
        else:  # ~=
            neg.add(n)
    if pos:
        return [x for x in dedup(pos) if x not in neg]
    if neg:
        return [x for x in range(1, s_max + 1) if x not in neg]
    return []


def make_guard_lookup(body_ns, body_nc, consts, s_max):
    """Context lookup for effect attribution: lookup(pos) ->
    (stages | None, locs | None, side) evaluated over the if-chain OPEN at
    pos - the same frame walk as scan_battle_branches (if/elseif/else over
    end, do/function/repeat opaque), plus idLocation tests. stages is the
    innermost open header's questState set (None = untested; an
    else-branch carries [] and falls through, since it means "not these");
    locs likewise from idLocation== resolved through the file constants;
    side is 'win'/'fail'/'none' from the success tests. Closed blocks do
    not leak - unlike nearest-preceding scans."""
    kws = [(m.group(1), m.start()) for m in LUA_KW.finditer(body_ns)]
    idloc = re.compile(r'idLocation\s*==\s*("[^"\n]*"|[A-Za-z_]\w*)')

    def header_at(pos):
        then = next((p for k, p in kws if k == 'then' and p > pos), len(body_ns))
        return body_nc[pos:then]

    def header_locs(header):
        out = []
        for g in idloc.finditer(header):
            tok = g.group(1)
            loc = tok[1:-1] if tok.startswith('"') else consts.get(tok)
            if loc is not None:
                out.append(loc)
        return out

    stack = []
    changes = []  # (keyword pos, snapshot) - snapshot valid from pos on

    def snap():
        stages = locs = None
        side = 'none'
        for fr in reversed(stack):
            if fr['generic']:
                continue
            if stages is None and fr['stages']:
                stages = list(fr['stages'])
            if locs is None and fr['locs']:
                locs = list(fr['locs'])
            if side == 'none' and fr['side'] is not None:
                side = fr['side']
        return (stages, locs, side)

    changes.append((-1, snap()))
    for k, pos in kws:
        if k == 'if':
            header = header_at(pos)
            s = success_side(header)
            stack.append({
                'stages': header_states(header, s_max),
                'locs': header_locs(header),
                'side': s,
                'chain': s,
                'generic': False,
            })
        elif k == 'elseif' and stack and not stack[-1]['generic']:
            header = header_at(pos)
            fr = stack[-1]
            fr['stages'] = header_states(header, s_max)
            fr['locs'] = header_locs(header)
            s = success_side(header)
            if s is not None:
                fr['chain'] = s
                fr['side'] = s
            else:
                fr['side'] = flip_side(fr['chain']) if fr['chain'] else None
        elif k == 'else' and stack and not stack[-1]['generic']:
            fr = stack[-1]
            fr['stages'] = []
            fr['locs'] = []
            fr['side'] = flip_side(fr['chain']) if fr['chain'] else None
        elif k in ('do', 'function', 'repeat'):
            stack.append({'stages': None, 'locs': None, 'side': None,
                          'chain': None, 'generic': True})
        elif k in ('end', 'until'):
            if stack:
                stack.pop()
        changes.append((pos, snap()))

    import bisect
    poses = [p for p, _ in changes]

    def lookup(pos):
        return changes[bisect.bisect_right(poses, pos) - 1][1]

    return lookup


def guard_keys(stages, locs):
    """Expand a guard snapshot into the (state, loc) key pairs to record:
    None = untested = the runtime wildcard (-1 / \"\"). An else-branch's
    [] never reaches here (snap() skips falsy lists)."""
    sts = stages if stages is not None else [-1]
    lxs = locs if locs is not None else [""]
    return [(st, lx) for st in sts for lx in lxs]


def build_msg_assigns(body):
    """{var: [(pos, tag)]} for every GET_TEXT / literal binding in the body,
    source order - the message arguments are locals, and the branch an
    assignment sits in is the branch whose text it carries."""
    out = {}
    for m in MSG_ASSIGN.finditer(body):
        tag = m.group(2) or m.group(3)
        out.setdefault(m.group(1), []).append((m.start(), tag))
    return out


def resolve_message(msg_assigns, hit, lookup, consts=None):
    """One QUEST_MESSAGE(_CALLBACK) site -> (rows, err): rows are
    [(pos, st, suc, loc, title, text, cb)] in assignment order, err the
    unresolved text token when nothing resolves (rows empty then).

    The text variable's each preceding assignment is its own row - the
    common shape
        if success==1 then myMessage=WIN else myMessage=FAIL end;
        QUEST_MESSAGE(...)
    puts both branches' texts in front of one site, and only the
    assignment records which side it came from (the site itself sits
    after the chain closed).  A row's guard merges the assignment's
    open-if context with the site's: stages/locs intersect (empty =
    dead row, dropped), the success side prefers the assignment.
    Literal / inline GET_TEXT arguments carry no assignment, so their
    row takes the site context alone.  The third call argument
    (idLocation / myLocation) is where the engine anchors the box, not
    a condition - the open-if context already carries location truth."""
    title_tok = hit.group(2).strip()
    text_tok = hit.group(3).strip()
    cb_tok = hit.group(6)
    cb = ""
    if cb_tok:
        if cb_tok.startswith('"'):
            cb = cb_tok[1:-1]
        elif consts is not None:
            cb = consts.get(cb_tok, "")
    site_pos = hit.start()
    site = lookup(site_pos) if lookup else (None, None, 'none')

    def tags(tok, limit):
        if tok.startswith('"'):
            return [(tok[1:-1], None)]
        if tok.startswith('GET_TEXT'):
            m = re.search(r'"(\[[^"\n]*\])"', tok)
            return [(m.group(1), None)] if m else []
        return [(tag, apos) for apos, tag in msg_assigns.get(tok, [])
                if apos < limit]

    text_cands = tags(text_tok, site_pos)
    if not text_cands:
        return [], text_tok
    title_cands = tags(title_tok, site_pos)

    def title_for(tpos):
        usable = [(tag, p) for tag, p in title_cands
                  if p is None or (tpos is not None and p <= tpos)]
        if not usable:
            usable = [(tag, p) for tag, p in title_cands
                      if p is None or p < site_pos]
        if not usable:
            return ""
        # nearest assignment wins; a literal/inline tag has no position
        # and stands in wherever it appears
        return max(usable, key=lambda c: -1 if c[1] is None else c[1])[0]

    rows = []
    for ttag, tpos in text_cands:
        a = lookup(tpos) if (lookup and tpos is not None) else site
        # merge assignment + site context
        stages = a[0] if a[0] is not None else site[0]
        if site[0] is not None and a[0] is not None:
            stages = [x for x in a[0] if x in site[0]]
            if not stages:
                continue
        locs = site[1]
        if a[1] is not None and site[1] is not None:
            locs = [x for x in a[1] if x in site[1]]
            if not locs:
                continue
        elif a[1] is not None:
            locs = a[1]
        side = a[2] if a[2] != 'none' else site[2]
        suc = 1 if side == 'win' else (0 if side == 'fail' else -1)
        for st in (stages if stages is not None else [-1]):
            for lx in (locs if locs is not None else [""]):
                rows.append((tpos if tpos is not None else site_pos,
                             st, suc, lx, title_for(tpos), ttag, cb))
    return rows, None



def analyze_lua(src, qid, stats):
    """Returns reveal/reward fields extracted from one quest script."""
    nc = scan(src, blank_strings=False)
    ns = scan(src, blank_strings=True)
    consts = lua_constants(nc)
    funcs = extract_functions(ns)

    # raw call counts for --check reconciliation
    for kind, rx in RAW_RE.items():
        stats['raw'][kind] += len(rx.findall(nc))
    stats['raw']['battle_call'] += len(BATTLE_CALL.findall(nc))

    # open-ended header tests (questState > N) expand to a finite set: the
    # file's own highest state value plus one.
    _sv = [int(x) for x in re.findall(r'questState\s*[^\dn]{0,3}(\d+)', src)]
    s_max = max(_sv + [5]) + 1

    reveals = {'begin': [], 'end': []}
    ruins = []
    ruin_dones = {'end': [], 'battle': [], 'abandon': []}
    gold = xp = 0
    items, awards, companions = [], [], []
    battle_actions = []
    stage_advances = {}
    stage_fails = {}
    enter_removes = []
    cb_removes = []
    conv_buckets = {'begin': [], 'abandon': []}
    conv_callbacks = {}
    cb_events = {}
    # location-action effect groups: event -> {guard key -> [(pos, eff)]}.
    # enter/execute/end key on (state, loc), complete on (state, success,
    # loc); positions order the group's effects in source order, groups
    # themselves emit by first-effect position (Lua's evaluation order).
    eff_groups = {'enter': {}, 'execute': {}, 'complete': {}, 'end': {}}
    query_actions = []

    for hook, (start, end) in funcs.items():
        body = nc[start:end]
        body_ns = ns[start:end]
        # Engine hooks fire from the quest lifecycle; everything else is a
        # conversation/message callback (or a helper only they call).
        is_callback = not hook.startswith('On')
        lookup = make_guard_lookup(body_ns, body, consts, s_max)
        msg_assigns = build_msg_assigns(body)
        ev = ACTION_HOOKS.get(hook)

        def add_group(evk, key, pos, eff):
            eff_groups[evk].setdefault(key, []).append((pos, eff))

        def keys_for(evk, pos, force_loc=None):
            """Guard keys for an effect site: expand the open-if snapshot
            at pos into the group's key form (complete keys carry the
            success side; OnEnd effects are turn-in events, not
            location-bound, so their loc guard collapses to wildcard)."""
            stages, locs, side = lookup(pos)
            if evk == 'end':
                locs = None
            if force_loc is not None:
                locs = [force_loc]
            suc = 1 if side == 'win' else (0 if side == 'fail' else -1)
            out = []
            for st, lx in guard_keys(stages, locs):
                out.append((st, suc, lx) if evk == 'complete' else (st, lx))
            return out

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
            if is_callback:
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'gold', int(hit.group(1))))
            elif gold == 0:
                gold = int(hit.group(1))
        for hit in CALL_PATTERNS['xp'].finditer(body):
            stats['extracted']['xp'] += 1
            stats['hooks'][('xp', hook)] += 1
            if is_callback:
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'xp', int(hit.group(1))))
            elif xp == 0:
                xp = int(hit.group(1))
        for hit in CALL_PATTERNS['item'].finditer(body):
            stats['extracted']['item'] += 1
            stats['hooks'][('item', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            if is_callback:
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'item', target))
            else:
                items.append(target)
        for hit in CALL_PATTERNS['award'].finditer(body):
            stats['extracted']['award'] += 1
            stats['hooks'][('award', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            if is_callback:
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'award', target))
            else:
                awards.append(target)
        for hit in CALL_PATTERNS['companion'].finditer(body):
            stats['extracted']['companion'] += 1
            stats['hooks'][('companion', hook)] += 1
            target = resolve(hit.group(1), consts)
            if target is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            if is_callback:
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'companion', target))
            else:
                companions.append(target)
        # QUEST_CONVERSATION: the hook that runs the call opens the tree.
        # Begin/abandon fire unconditionally (flat lists); the four action
        # events fold into the effect groups so one guard-matched fold
        # fires conversations, messages, state writes and completes
        # together under the branch Lua would have run.
        for hit in CALL_PATTERNS['conversation'].finditer(body):
            stats['extracted']['conversation'] += 1
            stats['hooks'][('conversation', hook)] += 1
            tok = resolve(hit.group(1), consts)
            if tok is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            cid = conversation_id(tok)
            if hook in CONV_BUCKETS:
                if cid not in conv_buckets[CONV_BUCKETS[hook]]:
                    conv_buckets[CONV_BUCKETS[hook]].append(cid)
            elif is_callback:
                lst = conv_callbacks.setdefault(hook, [])
                if cid not in lst:
                    lst.append(cid)
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'conversation', cid))
            elif ev is not None:
                for key in keys_for(ev, hit.start()):
                    add_group(ev, key, hit.start(), ('conversation', cid))
            else:
                # an engine hook outside the four events has no arrival
                # event of its own: noted, and kept as a wildcard execute
                # entry rather than dropped.
                stats['conv_other_hooks'].append((qid, hook, cid))
                add_group('execute', (-1, ""), hit.start(),
                          ('conversation', cid))
        # QUEST_COMPLETE / QUEST_MESSAGE: event hooks feed the groups,
        # callback sites keep their effect rows; anything else (CompleteQ's
        # body, OnCancelAction) is counted for reconciliation only.
        for hit in CALL_PATTERNS['complete'].finditer(body):
            stats['extracted']['complete'] += 1
            stats['hooks'][('complete', hook)] += 1
            if is_callback:
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'complete', None))
            elif ev is not None:
                for key in keys_for(ev, hit.start()):
                    add_group(ev, key, hit.start(), ('complete', None))
        for hit in CALL_PATTERNS['message'].finditer(body):
            stats['extracted']['message'] += 1
            stats['hooks'][('message', hook)] += 1
            if hook == 'OnCancelAction':
                continue  # dormant: no cancel event in the port yet
            rows, err = resolve_message(msg_assigns, hit, lookup, consts)
            if err is not None:
                stats['unresolved'].append((qid, hook, err))
                continue
            if is_callback:
                pos, _st, _suc, _lx, title, text, cb = rows[0]
                cb_events.setdefault(hook, []).append(
                    (pos, 'message', (title, text, cb)))
            elif ev is not None:
                for pos, st, suc, lx, title, text, cb in rows:
                    key = (st, suc, lx) if ev == 'complete' else (st, lx)
                    add_group(ev, key, pos, ('message', (title, text, cb)))
        # OnQueryAction's menu label: the first branch Lua would show for
        # the hero's current (state, location).  GET_TEXT returns in other
        # functions (OnSave's step text) count for reconciliation but are
        # not actionable.
        if hook == 'OnQueryAction':
            for hit in CALL_PATTERNS['query'].finditer(body):
                stats['extracted']['query'] += 1
                stats['hooks'][('query', hook)] += 1
                for st, lx in keys_for('query', hit.start()):
                    query_actions.append((st, lx, hit.group(1)))
        else:
            for _hit in CALL_PATTERNS['query'].finditer(body):
                stats['extracted']['query'] += 1
                stats['hooks'][('query', hook)] += 1
        # questState writes: callbacks drive the state machine from the
        # dialogue (first source-order value wins, like the reward fields);
        # the action events record them as guarded SetQuestState effects.
        # OnBegin / OnAbandon writes are outside this flow (unattributed
        # there, as before).
        if is_callback:
            for hit in STATE_ASSIGN.finditer(body):
                cb_events.setdefault(hook, []).append(
                    (hit.start(), 'state', int(hit.group(1))))
        elif ev is not None:
            for hit in STATE_ASSIGN.finditer(body):
                for key in keys_for(ev, hit.start()):
                    add_group(ev, key, hit.start(),
                              ('state', int(hit.group(1))))
        # QUEST_REMOVE_COMPANION: the OnEnterLocation sites carry the whole
        # rule - the questState and idLocation guards in the surrounding if,
        # the companion id as the argument. The nearest preceding guard of
        # each kind is the branch the call sits in (the elseif chain puts
        # them in the header just above). A site in a conversation callback
        # fires when that callback runs, so it is attributed to the hook by
        # name; any other On* hook has no port event and stays listed.
        for hit in CALL_PATTERNS['remove_companion'].finditer(body):
            stats['extracted']['remove_companion'] += 1
            stats['hooks'][('remove_companion', hook)] += 1
            comp = resolve(hit.group(1), consts)
            if hook != 'OnEnterLocation':
                if is_callback and comp is not None:
                    cb_removes.append((hook, comp))
                else:
                    stats['remove_elsewhere'].append(
                        (qid, hook, comp if comp else hit.group(1)))
                continue
            st = None
            for g in STATE_EQ.finditer(body[:hit.start()]):
                st = int(g.group(1))
            loc_tok = None
            for g in IDLOC_EQ.finditer(body[:hit.start()]):
                loc_tok = g.group(1)
            loc = resolve(loc_tok, consts) if loc_tok else None
            if st is None or loc is None or comp is None:
                stats['unresolved'].append((qid, hook, hit.group(1)))
                continue
            enter_removes.append((st, loc, comp))
        calls, assigns = scan_battle_branches(
            body_ns, body, collect_assigns=(hook == 'OnCompleteAction'))
        for full_name, idx_arg, third, stages in calls:
            if stages is None:
                stats['battle_unattributed'].append(
                    (qid, hook, 'no questState guard', full_name))
                continue
            if not idx_arg.isdigit():
                stats['battle_unattributed'].append(
                    (qid, hook, 'non-literal index', full_name + '(' + idx_arg + ')'))
                continue
            stats['extracted']['battle_call'] += 1
            capture = full_name != 'QUEST_BATTLE_NOCAPTURE' and third == 1
            for st in stages:
                battle_actions.append((st, int(idx_arg), capture))
        for value, sd, stages in assigns:
            if stages is None:
                stats['battle_unattributed'].append(
                    (qid, hook, 'assign without questState guard', value))
                continue
            if sd == 'none':
                stats['battle_unattributed'].append(
                    (qid, hook, 'assign outside success branch', value))
                continue
            for stage in stages:
                table = stage_advances if sd == 'win' else stage_fails
                if stage not in table:
                    table[stage] = value
                elif table[stage] != value:
                    stats['battle_conflicts'].append(
                        (qid, hook, sd, stage, table[stage], value))

    battle_actions = dedup(battle_actions)

    def finalize_cb(effs):
        """Ordered effects for one callback: first source-order value wins
        for state/gold/xp (the reward convention); value-carrying grants
        dedup preserving order; Message keeps one entry per site."""
        out, first, seen = [], set(), set()
        for _, kind, val in sorted(effs, key=lambda t: t[0]):
            if kind in ('state', 'gold', 'xp'):
                if kind in first:
                    continue
                first.add(kind)
            elif kind == 'message':
                pass
            else:
                if (kind, val) in seen:
                    continue
                seen.add((kind, val))
            out.append((kind, val))
        return out

    def finalize_groups(evk):
        """[(guard key, effects)] for one event: dedup identical rows,
        effects in source order, groups by first-effect position (Lua's
        evaluation order - the runtime takes the first match)."""
        d = eff_groups[evk]
        rows = []
        for key, members in d.items():
            # dedup preserving insertion order, then a stable sort by
            # position - effects sharing an assignment position keep the
            # sites' processing order (a bare set() would tie-break by
            # hash seed and flip rows between runs)
            seen_m, ordered = set(), []
            for m in members:
                if m not in seen_m:
                    seen_m.add(m)
                    ordered.append(m)
            uniq = sorted(ordered, key=lambda t: t[0])
            rows.append((min(p for p, _ in members), key,
                         [eff for _, eff in uniq]))
        rows.sort(key=lambda r: r[0])
        return [(key, effs) for _first, key, effs in rows]

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
        'battle_actions': battle_actions,
        'battle_stage_advances': list(stage_advances.items()),
        'battle_stage_fails': list(stage_fails.items()),
        'enter_removes': enter_removes,
        'remove_companion_on_callbacks': dedup(cb_removes),
        'conversations_begin': conv_buckets['begin'],
        'conversations_abandon': conv_buckets['abandon'],
        'conversation_callbacks': [(cb, cs) for cb, cs in conv_callbacks.items()],
        'callback_effects': [(cb, finalize_cb(evts))
                             for cb, evts in sorted(cb_events.items())],
        'query_actions': dedup(query_actions),
        'enter_effects': finalize_groups('enter'),
        'execute_effects': finalize_groups('execute'),
        'complete_effects': finalize_groups('complete'),
        'end_effects': finalize_groups('end'),
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
        'battle_actions': [], 'battle_stage_advances': [],
        'battle_stage_fails': [], 'enter_removes': [],
        'remove_companion_on_callbacks': [],
        'conversations_begin': [], 'conversations_abandon': [],
        'conversation_callbacks': [],
        'callback_effects': [],
        'query_actions': [], 'enter_effects': [], 'execute_effects': [],
        'complete_effects': [], 'end_effects': [],
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
        # every <Battle> element in order: the Lua battle index selects one
        "battles": [(b.get("monster") or "",
                     [sp.get("id") for sp in b.findall("Spell")])
                    for b in root.findall("Battle")],
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


def ocaml_str_pairs(pairs):
    if not pairs:
        return "[]"
    parts = ['("%s", "%s")' % (ocaml_str(a), ocaml_str(b)) for a, b in pairs]
    return "[" + "; ".join(parts) + "]"


def ocaml_battles(battles):
    if not battles:
        return "[]"
    parts = ['("%s", %s)' % (ocaml_str(m), ocaml_list(s)) for m, s in battles]
    return "[" + "; ".join(parts) + "]"


def ocaml_battle_actions(actions):
    if not actions:
        return "[]"
    parts = ['(%d, %d, %s)' % (st, idx, "true" if cap else "false")
             for st, idx, cap in actions]
    return "[" + "; ".join(parts) + "]"


def ocaml_int_pairs(pairs):
    if not pairs:
        return "[]"
    return "[" + "; ".join("(%d, %d)" % p for p in pairs) + "]"


def ocaml_state_triples(rows):
    if not rows:
        return "[]"
    return "[" + "; ".join('(%d, "%s", "%s")' % (st, ocaml_str(loc), ocaml_str(cid))
                           for st, loc, cid in rows) + "]"


def ocaml_effect(kind, val):
    if kind == 'state':
        return f'SetQuestState {val}'
    if kind == 'complete':
        return 'Complete'
    if kind == 'gold':
        return f'GiveGold {val}'
    if kind == 'xp':
        return f'GiveXp {val}'
    if kind == 'message':
        title, text, cb = val
        return (f'ShowMessage ("{ocaml_str(title)}", '
                f'"{ocaml_str(text)}", "{ocaml_str(cb)}")')
    ctor = {'item': 'GiveItem', 'award': 'GiveAward',
            'companion': 'GiveCompanion', 'conversation': 'Conversation'}[kind]
    return f'{ctor} "{ocaml_str(val)}"'


def ocaml_callback_effects(pairs):
    if not pairs:
        return "[]"
    parts = ['("%s", [%s])' % (ocaml_str(cb),
                               "; ".join(ocaml_effect(k, v) for k, v in effs))
             for cb, effs in pairs]
    return "[" + "; ".join(parts) + "]"


def ocaml_callback_pairs(pairs):
    """[(callback, [conversation ids])] - the scriptcall sites inside
    callbacks, ordered, deduped by the extractor."""
    if not pairs:
        return "[]"
    parts = ['("%s", %s)' % (ocaml_str(cb), ocaml_list(convs))
             for cb, convs in pairs]
    return "[" + "; ".join(parts) + "]"


def ocaml_query_actions(rows):
    """[(state, location, label tag)] - state -1 / loc "" = wildcard."""
    if not rows:
        return "[]"
    return "[" + "; ".join(
        '(%d, "%s", "%s")' % (st, ocaml_str(loc), ocaml_str(tag))
        for st, loc, tag in rows) + "]"


def ocaml_loc_groups(rows):
    """[((state, loc), effects)] -> [(state, loc, effects)]; state -1 /
    loc "" = wildcard."""
    if not rows:
        return "[]"
    parts = ['(%d, "%s", [%s])'
             % (st, ocaml_str(loc),
                "; ".join(ocaml_effect(k, v) for k, v in effs))
             for (st, loc), effs in rows]
    return "[" + "; ".join(parts) + "]"


def ocaml_complete_groups(rows):
    """[((state, success, loc), effects)] -> [(state, success, loc,
    effects)]; -1 fields = wildcard."""
    if not rows:
        return "[]"
    parts = ['(%d, %d, "%s", [%s])'
             % (st, suc, ocaml_str(loc),
                "; ".join(ocaml_effect(k, v) for k, v in effs))
             for (st, suc, loc), effs in rows]
    return "[" + "; ".join(parts) + "]"


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
            'unresolved': [], 'missing_lua': [],
            'battle_unattributed': [], 'battle_conflicts': [],
            'remove_elsewhere': [], 'conv_other_hooks': []}


def main():
    import argparse
    from collections import Counter
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
        n_enter = sum(len(q["enter_removes"]) for q in quests)
        n_cb = sum(len(q["remove_companion_on_callbacks"]) for q in quests)
        print(f"remove_companion: {stats['raw']['remove_companion']} raw -> "
              f"{n_enter} enter-location rules, {n_cb} callback hooks, "
              f"{len(stats['remove_elsewhere'])} in other hooks")
        for q in quests:
            for row in q["remove_companion_on_callbacks"]:
                print(f"  callback: {(q['id'],) + row}")
        for row in stats['remove_elsewhere']:
            print(f"  elsewhere: {row}")
        n_conv = {b: sum(len(q[f"conversations_{b}"]) for q in quests)
                  for b in ('begin', 'abandon')}
        n_conv_cb = sum(len(v) for q in quests for _, v in q["conversation_callbacks"])
        print(f"conversations: begin={n_conv['begin']} "
              f"abandon={n_conv['abandon']} callbacks={n_conv_cb}")
        if stats['conv_other_hooks']:
            print(f"conversation sites in other hooks -> execute "
                  f"({len(stats['conv_other_hooks'])}):")
            for row in stats['conv_other_hooks']:
                print(f"  {row}")
        print("action effect groups (enter/execute/complete/end):")
        for evk, field in (('enter', 'enter_effects'),
                           ('execute', 'execute_effects'),
                           ('complete', 'complete_effects'),
                           ('end', 'end_effects')):
            groups = sum(len(q[field]) for q in quests)
            kinds = Counter()
            for q in quests:
                for _k, effs in q[field]:
                    for k, _v in effs:
                        kinds[k] += 1
            print(f"  {evk:8s}: {groups} groups, "
                  + (", ".join(f"{k}={n}" for k, n in sorted(kinds.items()))
                     or "none"))
        n_query = sum(len(q["query_actions"]) for q in quests)
        n_query_q = sum(1 for q in quests if q["query_actions"])
        print(f"query actions: {n_query} rows across {n_query_q} quests")
        eff_kinds = Counter()
        n_eff = 0
        for q in quests:
            for _, effs in q["callback_effects"]:
                n_eff += 1
                for k, _ in effs:
                    eff_kinds[k] += 1
        print(f"callback effects: {n_eff} callbacks, "
              + (", ".join(f"{k}={n}" for k, n in sorted(eff_kinds.items()))
                 or "none"))
        n_battles = sum(len(q["battles"]) for q in quests)
        n_actions = sum(len(q["battle_actions"]) for q in quests)
        n_adv = sum(len(q["battle_stage_advances"]) for q in quests)
        n_fail = sum(len(q["battle_stage_fails"]) for q in quests)
        print(f"battle calls: {stats['raw']['battle_call']} raw -> "
              f"{stats['extracted']['battle_call']} attributed "
              f"({n_actions} stage actions), battles={n_battles} "
              f"advances={n_adv} fails={n_fail}")
        if stats['battle_unattributed']:
            print(f"unattributed battle events ({len(stats['battle_unattributed'])}):")
            for row in stats['battle_unattributed']:
                print(f"  {row}")
        if stats['battle_conflicts']:
            print(f"conflicting transitions (first source-order wins):")
            for row in stats['battle_conflicts']:
                print(f"  {row}")
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
            if q['battles'] or q['battle_actions']:
                print(f"    battles={q['battles']} actions={q['battle_actions']} "
                      f"adv={q['battle_stage_advances']} fail={q['battle_stage_fails']}")
            if q['enter_removes']:
                print(f"    enter_removes={q['enter_removes']}")
            if q['remove_companion_on_callbacks']:
                print(f"    cb_removes={q['remove_companion_on_callbacks']}")
            if q['query_actions']:
                print(f"    query={q['query_actions']}")
            if (q['conversations_begin'] or q['conversations_abandon']
                    or q['enter_effects'] or q['execute_effects']
                    or q['complete_effects'] or q['end_effects']
                    or q['conversation_callbacks'] or q['callback_effects']):
                print(f"    conv: begin={q['conversations_begin']} "
                      f"abandon={q['conversations_abandon']} "
                      f"cb={q['conversation_callbacks']}")
                for cb, effs in q['callback_effects']:
                    print(f"    {cb}: {effs}")
                for lbl, field in (('enter', 'enter_effects'),
                                   ('exec', 'execute_effects'),
                                   ('comp', 'complete_effects'),
                                   ('end', 'end_effects')):
                    for k, effs in q[field]:
                        print(f"    {lbl} {k}: {effs}")
            if q['texts']:
                for tag, txt in list(q['texts'].items())[:2]:
                    print(f"    {tag}: {txt[:60]}")
        return

    lines = []

    # Callback battles table - conversation/message callbacks that trigger battles
    # Generated from unattributed QUEST_BATTLE calls in quest scripts.
    # Rows are (quest, callback, battle_index, capture, custom); the monster
    # is deliberately not listed - it resolves from the quest's battles
    # [battle_index], so it cannot drift from the <Battle> elements (the
    # hand-transcribed column had four wrong ids: Q0Q7/CallbackAmbush,
    # Q1Q4/CallbackMsgA, Q1Q4/CallbackMsgB, Q1Q6/CallbackConvB). Capture is
    # the primitive's: QUEST_BATTLE always captures, QUEST_BATTLE_NOCAPTURE
    # never does (evidence campaign.capture_eligible - the stage's primitive
    # decides, the third Lua argument disagrees on some sites).
    known_callback_battles = [
        ("Q0I2", "CallbackGuardian", 0, True, False),
        ("Q0Q0", "CallbackAmbush", 0, True, False),
        ("Q0Q7", "CallbackAmbush", 1, True, False),
        ("Q0T1", "CallbackConvA", 0, True, True),  # CUSTOM
        ("Q0T2", "CallbackConvA", 0, True, True),  # CUSTOM
        ("Q1E0", "OnExecuteAction", 1, True, False),
        ("Q1Q4", "CallbackMsgA", 0, True, False),
        ("Q1Q4", "CallbackMsgB", 1, True, False),
        ("Q1Q6", "CallbackConvB", 1, False, False),  # NOCAPTURE
        ("Q1Q6", "CallbackMsgA", 0, True, False),
        ("Q1Q7", "CallbackMsgB", 0, True, False),
        ("Q1Q8", "CallbackMsgB", 0, True, False),
        ("Q1R0", "CallbackMsgA", 0, True, False),
        ("Q1R1", "CallbackMsgA", 0, True, False),
        ("Q1R2", "CallbackMsgA", 0, True, False),
        ("Q1R3", "CallbackMsgA", 0, True, False),
        ("Q1R3", "CallbackMsgE", 1, True, False),
        ("Q2M0", "CallbackConvB", 0, True, False),
        ("Q2Q9", "CallbackConvC", 0, False, False),  # NOCAPTURE
        ("Q3D0", "CallbackMsg", 0, True, False),
        ("Q3D1", "CallbackConvB", 0, True, False),
        ("Q3E0", "CallbackMsg", 0, True, False),
        ("Q3E1", "CallbackMsg", 0, True, False),
        ("Q3E2", "CallbackMsg", 0, True, False),
        ("Q3I3", "CallbackConvB", 1, True, False),
        ("Q3Q5", "OnExecuteAction", 0, True, False),  # three identical sites
        ("Q3Q5", "CallbackConvB", 0, True, False),
        ("Q3Q5", "CallbackConvC", 0, True, False),
        ("Q3Q5", "CallbackConvD", 0, True, False),
        ("QA01", "CallbackConvB", 0, True, False),
        ("QA03", "CallbackConvB", 0, True, False),
        ("QK06", "MsgCallbackA", 0, True, False),
        ("QS00", "CallbackConvB", 0, True, False),
        # QS02 has non-literal index (currBattle) - skip for now
    ]

    lines.append("(* Generated by tools/extract_quests.py — do not edit *)")
    lines.append("")
    # The non-battle half of a conversation/message callback body: what runs
    # when the dialogue fires that scriptcall (the battle half lives in
    # callback_battle). Renamed SetQuestState to stay clear of Campaign's
    # quest_effect.SetState. ShowMessage queues a title/text message box
    # (text tags) with an optional callback to fire when it is dismissed;
    # the same effect carries the location-action hooks' message sites.
    lines.append("type callback_effect =")
    lines.append("  | SetQuestState of int")
    lines.append("  | Complete")
    lines.append("  | GiveGold of int")
    lines.append("  | GiveXp of int")
    lines.append("  | GiveItem of string")
    lines.append("  | GiveAward of string")
    lines.append("  | GiveCompanion of string")
    lines.append("  | Conversation of string")
    lines.append("  | ShowMessage of string * string * string")
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
    lines.append("  battles: (string * string list) list;")
    lines.append("  battle_actions: (int * int * bool) list;")
    lines.append("  battle_stage_advances: (int * int) list;")
    lines.append("  battle_stage_fails: (int * int) list;")
    lines.append("  enter_removes: (int * string * string) list;")
    lines.append("  remove_companion_on_callbacks: (string * string) list;")
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
    lines.append("  conversations_begin: string list;")
    lines.append("  conversations_abandon: string list;")
    lines.append("  conversation_callbacks: (string * string list) list;")
    lines.append("  callback_effects: (string * callback_effect list) list;")
    lines.append("  query_actions: (int * string * string) list;")
    lines.append("  enter_effects: (int * string * callback_effect list) list;")
    lines.append("  execute_effects: (int * string * callback_effect list) list;")
    lines.append("  complete_effects:")
    lines.append("    (int * int * string * callback_effect list) list;")
    lines.append("  end_effects: (int * string * callback_effect list) list;")
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
        lines.append(f'    battles = {ocaml_battles(q["battles"])};')
        lines.append(f'    battle_actions = {ocaml_battle_actions(q["battle_actions"])};')
        lines.append(f'    battle_stage_advances = {ocaml_int_pairs(q["battle_stage_advances"])};')
        lines.append(f'    battle_stage_fails = {ocaml_int_pairs(q["battle_stage_fails"])};')
        lines.append(f'    enter_removes = {ocaml_state_triples(q["enter_removes"])};')
        lines.append(f'    remove_companion_on_callbacks = '
                     f'{ocaml_str_pairs(q["remove_companion_on_callbacks"])};')
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
        lines.append(f'    conversations_begin = {ocaml_list(q["conversations_begin"])};')
        lines.append(f'    conversations_abandon = {ocaml_list(q["conversations_abandon"])};')
        lines.append(f'    conversation_callbacks = {ocaml_callback_pairs(q["conversation_callbacks"])};')
        lines.append(f'    callback_effects = {ocaml_callback_effects(q["callback_effects"])};')
        lines.append(f'    query_actions = {ocaml_query_actions(q["query_actions"])};')
        lines.append(f'    enter_effects = {ocaml_loc_groups(q["enter_effects"])};')
        lines.append(f'    execute_effects = {ocaml_loc_groups(q["execute_effects"])};')
        lines.append(f'    complete_effects = {ocaml_complete_groups(q["complete_effects"])};')
        lines.append(f'    end_effects = {ocaml_loc_groups(q["end_effects"])};')
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

    # Callback battles table - conversation/message callbacks that trigger battles
    # Generated from unattributed QUEST_BATTLE calls in quest scripts
    lines.append("")
    lines.append("(* Conversation/message callbacks that trigger battles *)")
    lines.append("type callback_battle = {")
    lines.append("  cb_monster_id: string;")
    lines.append("  cb_battle_index: int;")
    lines.append("  cb_capture: bool;")
    lines.append("  cb_custom: bool;")
    lines.append("}")
    lines.append("")
    lines.append("let callback_battles_table = [")
    quest_lookup = {q["id"]: q for q in quests}
    emitted = {}
    for qid, cb_name, idx, capture, custom in known_callback_battles:
        key = (qid, cb_name)
        row = (idx, capture, custom)
        if key in emitted:
            if emitted[key] != row:
                raise SystemExit(
                    "callback row conflict: %s/%s %r vs %r"
                    % (qid, cb_name, emitted[key], row))
            continue
        emitted[key] = row
        battles = quest_lookup[qid]["battles"]
        if not 0 <= idx < len(battles):
            raise SystemExit(
                "callback row out of range: %s/%s index %d, %d battles"
                % (qid, cb_name, idx, len(battles)))
        monster = battles[idx][0]
        lines.append(f'  ("{qid}", "{cb_name}"), {{ cb_monster_id = "{monster}"; cb_battle_index = {idx}; cb_capture = {str(capture).lower()}; cb_custom = {str(custom).lower()}; }};')
    lines.append("]")
    lines.append("")
    lines.append("let callback_battles (key: string * string) : callback_battle option =")
    lines.append("  try Some (List.assoc key callback_battles_table) with Not_found -> None")
    lines.append("")

    # Write via temp+rename: a plain truncate fails on Windows when another
    # process (dune's cache, an editor) holds a mapping of the output file.
    out = Path(args.output)
    tmp = out.with_name(out.name + ".new")
    tmp.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    os.replace(tmp, out)
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
