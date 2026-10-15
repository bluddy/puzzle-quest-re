#!/usr/bin/env python3
"""Generate the TextLibrary modules from the game's per-language text tables.

Every string the game shows that is not owned by one particular asset lives in a
TextLibrary: one XML file per subject, all of them `<Text tag="...">value</Text>`
entries under a `<TextLibrary>` root. The build ships five languages, each with
the same fifteen top-level files plus two subdirectories the port merges in:

    <Lang>/StandardQuestsText.xml    quest titles and descriptions
    <Lang>/StandardSitesText.xml     city names, waypoint and ruin names
    <Lang>/StandardItemsText.xml     item names and descriptions
    <Lang>/StandardMonstersText.xml  monster names, descriptions, capture text
    <Lang>/StandardSpellsText.xml    spell names and descriptions
    <Lang>/StandardProfessionsText.xml  the four classes
    <Lang>/StandardAwardsText.xml    award names
    <Lang>/StandardCompanionsText.xml   companion names and dialogue
    <Lang>/StandardRumorsText.xml    tavern rumors
    <Lang>/StandardQuestGroupsText.xml   quest group headings
    <Lang>/StandardStatusEffectsText.xml status effect names
    <Lang>/StandardSpellEffectsText.xml  spell effect school names
    <Lang>/GameText.xml              interface strings
    <Lang>/RunesText.xml             rune mini-game text
    <Lang>/TutorialsText.xml         tutorial panels
    <Lang>/Conversations/            conversation dialogues (273 files)
    <Lang>/Quests/                   quest step lines (143 files)

The conversation and quest subdirectories used to be read from English only
(the conversations path was hardcoded, the quests not merged at all); both are
per-language in the assets and all five languages carry identical tag sets -
10,425 tags - so the language switch is a pure table swap. Quest step lines
([QUEST_X_NAME] tags live here too, not in StandardQuestsText) ride the same
flat table, which is what lets `Campaign_quests.quest_text` route them by
language instead of the English values baked into campaign_quests.ml.

The original picks its language at startup (FUN at 0x4d8d00): for each of ten
ids - 0=English 1=French 2=German 3=Spanish 4=Italian 5=Polish 6=Russian
7=Japanese 8=Korean 9=Taiwanese, the order and names the exe's own jump table
at 0x4b3d60 pushes - it checks that `<Lang>\\GameText.xml` exists, then matches
a `-FRENCH`-style switch in the options string or the stored id word (config
+0x20, default 0xFFFF = unset); anything unmatched falls back to English. Only
five languages ship in this build's Assets, so ids 5..9 have no table and the
existence gate skips them. `Text_data.set_language` mirrors the exe's setter
(0x4b4a60), which stores the id and clears the font/texture caches so the next
draw reloads them.

    python tools/extract_text_tables.py                  # -> six modules
    python tools/extract_text_tables.py --check          # fail if stale
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import xml.etree.ElementTree as ET

REPO = pathlib.Path(__file__).resolve().parent.parent
LIB = REPO / "lib"
ASSETS = REPO / "game" / "Assets"

# The recovered id table: original language id -> (module suffix, asset dir).
# Ids 0..4 are the five that ship; the exe knows 5..9 too but their GameText
# files are absent from this build and its existence gate skips them.
SHIPPED = (
    (0, "en", "English"),
    (1, "fr", "French"),
    (2, "de", "German"),
    (3, "es", "Spanish"),
    (4, "it", "Italian"),
)
KNOWN_IDS = ("English", "French", "German", "Spanish", "Italian",
             "Polish", "Russian", "Japanese", "Korean", "Taiwanese")


def ocaml_string(s: str) -> str:
    """An OCaml string literal. The tables carry real newlines and quotes."""
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def load(language: str) -> tuple[dict[str, str], list[str], int, int]:
    """All TextLibrary files for one language: top level, Conversations, Quests.

    Returns (tag -> text, file names in order, entry count, duplicate tags).
    Later entries win; files are read in sorted name order so the result does
    not depend on the filesystem.
    """
    lang_dir = ASSETS / language
    if not lang_dir.is_dir():
        raise SystemExit(f"error: {lang_dir} not found")
    files = sorted(lang_dir.glob("*Text.xml"))
    if not files:
        raise SystemExit(f"error: no *Text.xml under {lang_dir}")

    # Conversation dialogues and quest step lines are per-language TextLibrary
    # files in their own subdirectories - merge them all, the tags are global.
    for sub in ("Conversations", "Quests"):
        d = lang_dir / sub
        if d.is_dir():
            files.extend(sorted(d.glob("*_Text.xml")))

    table: dict[str, str] = {}
    entries = 0
    dupes: set[str] = set()
    for path in files:
        root = ET.parse(path).getroot()
        for node in root.findall("Text"):
            tag = node.get("tag")
            if tag is None:
                continue
            entries += 1
            if tag in table:
                dupes.add(tag)
            table[tag] = node.text or ""
    return table, [p.name for p in files], entries, len(dupes)


def render_data(table: dict[str, str], language: str, files: list[str],
                entries: int, dupes: int) -> str:
    lines = [
        "(* Generated by tools/extract_text_tables.py - do not edit. *)",
        "",
        f"(* The {language} TextLibrary: {len(table):,} tags from {len(files)} files",
        "   under game/Assets/%s/ - the fifteen Standard*/Game/Runes/Tutorials" % language,
        "   tables plus the Conversations and Quests subdirectories (the quest",
        "   step lines and the dialogue live there, not in the top-level",
        "   tables). All five shipped languages carry the same tag set, so the",
        "   language switch in Text_data is a table swap and nothing else.",
        "",
        f"   {entries} entries read, {dupes} tags seen twice; later entries won. *)",
        "",
        "let entries : (string * string) list = [",
    ]
    for tag in sorted(table):
        lines.append(f"  {ocaml_string(tag)}, {ocaml_string(table[tag])};")
    lines += [
        "]",
        "",
        "let table : (string, string) Hashtbl.t = Hashtbl.create 16384",
        "let () = List.iter (fun (k, v) -> Hashtbl.replace table k v) entries",
        "",
        "let lookup (tag : string) : string option = Hashtbl.find_opt table tag",
        "",
        "let text (tag : string) : string =",
        "  match lookup tag with Some s -> s | None -> tag",
        "",
    ]
    return "\n".join(lines)


def render_dispatcher() -> str:
    """The language-aware front: text_data.ml keeps the consumers' API.

    Text_data.text / lookup keep their signatures and route through the
    current language; entries becomes a function so module-level consumers
    (rumors, conversation load_all) re-read after a switch.
    """
    names = "; ".join(ocaml_string(n) for n in
                      [d for _, _, d in SHIPPED])
    dispatch_entries = "\n".join(
        f"  | {lang_id} -> Text_data_{suffix}.entries"
        for lang_id, suffix, _ in SHIPPED[1:])
    dispatch_lookup = "\n".join(
        f"  | {lang_id} -> Text_data_{suffix}.lookup tag"
        for lang_id, suffix, _ in SHIPPED[1:])
    return "\n".join([
        "(* Generated by tools/extract_text_tables.py - do not edit. *)",
        "",
        "(* The language front over the five shipped TextLibrary tables.",
        "",
        "   The original picks a language at startup from ten ids - 0=English",
        "   1=French 2=German 3=Spanish 4=Italian, then Polish/Russian/",
        "   Japanese/Korean/Taiwanese - by checking that <Lang>\\GameText.xml",
        "   exists and matching a -FRENCH-style switch or the stored id",
        "   (config +0x20, 0xFFFF = unset); this build ships five, so the",
        "   setter clamps to them. [Text_data.set_language] mirrors the exe's",
        "   setter (0x4b4a60), which stores the id and clears the font and",
        "   texture caches so the next draw reloads them - here the tables are",
        "   all resident and a lookup routes through the new one, which is why",
        "   [entries] is a function: the module-level consumers (the tavern's",
        "   rumors, conversation load_all) must re-read after a switch.",
        "",
        "   The five data modules carry identical tag sets (10,425 tags each),",
        "   quest step lines included, so every tag resolves in every",
        "   language. Anything missing falls back to the tag itself, as the",
        "   English table always has. *)",
        "",
        "(** The current language, as the original's id: [Text_data.name_of]",
        "    renders it and [set_language] changes it (clamped to the five",
        "    that ship; the exe's ids 5..9 have no table in this build and its",
        "    existence gate skips them, so the port does not offer them). *)",
        "let language : int ref = ref 0",
        "",
        "(** The recovered name table, in id order - the exe's jump table at",
        "    0x4b3d60 pushes exactly these strings. *)",
        f"let names : string array = [| {names} |]",
        "",
        "let name_of (id : int) : string =",
        "  if id >= 0 && id < Array.length names then names.(id)",
        "  else names.(0)",
        "",
        "let is_shipped (id : int) : bool = id >= 0 && id < Array.length names",
        "",
        "let is_english () : bool = !language = 0",
        "",
        "let set_language (id : int) : unit =",
        "  language := if is_shipped id then id else 0",
        "",
        "let entries () : (string * string) list =",
        "  match !language with",
        dispatch_entries,
        "  | _ -> Text_data_en.entries",
        "",
        "let lookup (tag : string) : string option =",
        "  match !language with",
        dispatch_lookup,
        "  | _ -> Text_data_en.lookup tag",
        "",
        "let text (tag : string) : string =",
        "  match lookup tag with Some s -> s | None -> tag",
        "",
    ])


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if any committed file differs")
    args = ap.parse_args()

    outputs: dict[pathlib.Path, str] = {LIB / "text_data.ml": render_dispatcher()}
    for lang_id, suffix, language in SHIPPED:
        table, files, entries, dupes = load(language)
        if not table:
            print("error: tables parsed empty", file=sys.stderr)
            return 1
        print(f"  [{lang_id}] {language}: {len(table):,} tags from "
              f"{len(files)} files ({entries} entries, {dupes} duplicated)")
        outputs[LIB / f"text_data_{suffix}.ml"] = render_data(
            table, language, files, entries, dupes)

    if args.check:
        stale = False
        for out, text in outputs.items():
            if not out.is_file():
                print(f"error: {out} missing", file=sys.stderr)
                stale = True
            elif out.read_text(encoding="utf-8") != text:
                print(f"error: {out} is stale, re-run tools/extract_text_tables.py",
                      file=sys.stderr)
                stale = True
        if stale:
            return 1
        print("  up to date")
        return 0

    for out, text in outputs.items():
        out.write_text(text, encoding="utf-8")
        print(f"  wrote {out} ({len(text):,d} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
