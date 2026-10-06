#!/usr/bin/env python3
"""Generate lib/skin_data.ml from the game's own bitmap registry.

`Assets/Assets.xml` is the WET engine's asset registry, and it has two halves that
matter here:

  <Bitmap tag="..." >path</Bitmap>       a sheet: a tag and the image behind it
  <BitmapImage tag="..." bitmap="..."    a named rectangle inside a sheet, with
      x y width height destwidth destheight/>

422 named rectangles across the sheets, which is the whole decoration vocabulary
of the game: the backdrop and its border, the selection glow, the turn-timer
backgrounds, button states, cursor art, dialog furniture. Everything the
presentation layer draws should come from here rather than from coordinates
somebody eyeballed off a PNG.

This is the same discipline `gfx/assets.ml` applies to the gem sheet, promoted to
the general case - and it has an immediate payoff: the four gem frames the port
hardcodes can be *checked* against the registry instead of trusted.

Note the paths use backslashes (`Assets\\Skin\\Skin_Gems_Grid.png`) while the
archive uses forward slashes, and the tag is not always the file's name, so both
are normalised here rather than at each use.

    python tools/extract_skin_data.py
    python tools/extract_skin_data.py --check     # verify the committed file is current
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT = REPO / "lib" / "skin_data.ml"
REGISTRY = "Assets/Assets.xml"

SHEET_RE = re.compile(r'<Bitmap\s+tag="([^"]+)"[^>]*>([^<]+)</Bitmap>')
FRAME_RE = re.compile(r"<BitmapImage\s+([^/]*?)/>")
SOUND_RE = re.compile(r"<Sound\s+([^>]*?)>")

# Sound tags that do not follow the `snd_<stem>` -> `<Stem>.wav` rule. Each of these
# was read off the archive rather than guessed: the four element sounds all carry
# a "Mana" suffix, the two button sounds are named Button*, and three interface
# sounds are named after what they *are* rather than what they are called.
#
# The voice tags resolve by language instead - `snd_voice_defeat` is
# `English/Sounds/VDefeat.wav`, and there are three copies of each, one per
# language, which is why the archive holds more voice files than voice tags.
SOUND_RENAMES = {
    "snd_earth": "EarthMana",
    "snd_air": "AirMana",
    "snd_fire": "FireMana",
    "snd_water": "WaterMana",
    "snd_buttdown": "ButtonDown",
    "snd_buttup": "ButtonUp",
    "snd_illegal": "IllegalMove",
    "snd_questconv": "QuestConversation",
    "snd_questconvclick": "QuestConversationClick",
}

# Voice lines, which sit in a per-language directory behind a `V` prefix and are
# CamelCased by hand. Note `snd_voice_victory` -> `VVictorious`: the tag and the
# file disagree, which is the kind of thing that makes a convention unusable as a
# convention.
VOICE_RENAMES = {
    "snd_voice_defeat": "VDefeat",
    "snd_voice_heroiceffort": "VHeroicEffort",
    "snd_voice_neardeath": "VNearDeath",
    "snd_voice_newspell": "VNewSpell",
    "snd_voice_questcomplete": "VQuestComplete",
    "snd_voice_queststage": "VQuestStage",
    "snd_voice_victory": "VVictorious",
}

# How a sound tag was resolved. Mirrors the gem sheet's Named/Inferred split: a
# reader should be able to tell a straight filename match from a rule applied on
# top, and from a tag with no file behind it at all.
HOW_EXACT = "Exact"      # the tag, minus its prefix, is a file stem
HOW_RENAMED = "Renamed"  # SOUND_RENAMES supplied the stem
HOW_ABSENT = "Absent"    # no file in the archive - every music tag, it turns out


def attrs(s: str) -> dict[str, str]:
    return dict(re.findall(r'(\w+)="([^"]*)"', s))


def normalise(path: str) -> str:
    """`Assets\\Skin\\Skin_Gems_Grid.png` -> `Assets/Skin/Skin_Gems_Grid`.

    The extension goes too, because the caller pairs this with the image decoder
    and there are two JPGs in the tree that differ only by directory."""
    p = path.strip().replace("\\", "/")
    for ext in (".png", ".jpg", ".jpeg"):
        if p.lower().endswith(ext):
            return p[: -len(ext)]
    return p


def parse_sounds(z: zipfile.ZipFile, language: str) -> list[tuple[dict[str, str], str | None, str]]:
    """Registry sound tags -> (attrs, resolved file or None, how it was resolved).

    The mapping is a convention with exceptions, so it is recorded rather than
    assumed. `snd_damage` -> `Damage.wav` is a straight stem match; the element
    and button sounds need a rename; the voices live under a per-language
    directory with a `V` prefix; and **every music tag has no file behind it in
    this archive at all**, which is worth knowing before anyone writes a music
    player against the registry."""
    names = z.namelist()
    stems = {}
    for n in names:
        if n.startswith("Assets/Sounds/") and n.lower().endswith(".wav"):
            stems.setdefault(n.split("/")[-1][:-4].lower(), n)
    out = []
    for m in SOUND_RE.finditer(z.read(REGISTRY).decode("utf-8")):
        a = attrs(m.group(1))
        tag = a.get("tag", "")
        if tag in VOICE_RENAMES:
            path = f"{language}/Sounds/{VOICE_RENAMES[tag]}.wav"
            out.append((a, path if path in names else None,
                        HOW_RENAMED if path in names else HOW_ABSENT))
            continue
        if tag in SOUND_RENAMES:
            stem = SOUND_RENAMES[tag]
            path = stems.get(stem.lower())
            out.append((a, path, HOW_RENAMED if path else HOW_ABSENT))
            continue
        bare = tag[4:] if tag[:4] in ("snd_", "musc") else tag
        path = stems.get(bare.lower())
        out.append((a, path, HOW_EXACT if path else HOW_ABSENT))
    return out


def ocaml_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(sheets: list[tuple[str, str]], frames: list[dict[str, str]],
           sounds: list[tuple[dict[str, str], str | None, str]]) -> str:
    L: list[str] = []
    w = L.append

    w("(* Generated by tools/extract_skin_data.py from game/Assets.zip. Do not edit.")
    w("")
    w("   The game's own bitmap registry, Assets/Assets.xml, in two parts:")
    w("")
    w("   - a [sheet]: a tag and the image behind it;")
    w("   - a [frame]: a named rectangle inside a sheet, with the size it is meant")
    w("     to be *drawn* at as well as the size it is stored at.")
    w("")
    w("   422 named frames. This is the decoration vocabulary of the whole game - the")
    w("   backdrop and its border, the selection glow, the turn-timer backgrounds,")
    w("   button states, dialog furniture - so a renderer should look tags up here")
    w("   rather than carry coordinates of its own. The gem frames the port needs are")
    w("   in this table too, which means [test_skin_data] can check the port's gem")
    w("   coordinates against the registry instead of trusting them.")
    w("")
    w("   [dest_w] and [dest_h] are worth keeping: several frames are stored larger")
    w("   than they are drawn, the red glow frames being 88x88 on disk for 64x64 on")
    w("   screen, so the registry is the only place that knows to scale them. *)\n")
    w("type sheet = { tag : string; file : string }  (** no extension: see the note in the generator *)\n")
    w("type frame = {")
    w("  tag : string;")
    w("  sheet : string;")
    w("  x : int;")
    w("  y : int;")
    w("  w : int;")
    w("  h : int;")
    w("  dest_w : int;")
    w("  dest_h : int;")
    w("}\n")

    w("let sheets : sheet array =")
    w("  [|")
    for tag, path in sheets:
        w(f"    {{ tag = {ocaml_str(tag)}; file = {ocaml_str(normalise(path))} }};")
    w("  |]\n")

    w("""let sheet_of_tag (tag : string) : sheet option =
  let rec go (l : sheet list) =
    match l with
    | [] -> None
    | (s : sheet) :: rest -> if s.tag = tag then Some s else go rest
  in
  go (Array.to_list sheets)

let frames : frame array =""")
    w("  [|")
    for f in frames:
        w(
            "    { tag = %s; sheet = %s; x = %s; y = %s; w = %s; h = %s; dest_w = %s; dest_h = %s };"
            % (
                ocaml_str(f["tag"]),
                ocaml_str(f["bitmap"]),
                f["x"],
                f["y"],
                f["width"],
                f["height"],
                f.get("destwidth", f["width"]),
                f.get("destheight", f["height"]),
            )
        )
    w("  |]\n")

    w("""let frame_of_tag (tag : string) : frame option =
  let rec go (l : frame list) =
    match l with
    | [] -> None
    | (f : frame) :: rest -> if f.tag = tag then Some f else go rest
  in
  go (Array.to_list frames)

(** Every frame on one sheet, in registry order.

    The sheet's frames are contiguous in the file, so this is a scan rather than
    an index - and a scan is what keeps [frames] a plain array that can be read
    straight out of the registry. *)
let frames_on (sheet : string) : frame array =
  Array.of_list
    (List.filter (fun (f : frame) -> f.sheet = sheet) (Array.to_list frames))

(** The scale a frame is meant to be drawn at, as a numerator and a denominator.

    Returns 1,1 when the frame is drawn at its stored size, which is the common
    case. The red glows are the exception: 88x88 stored, 64x64 drawn. *)
let draw_scale (f : frame) : int * int =
  if f.dest_w = f.w then (1, 1)
  else
    let rec gcd a b = if b = 0 then a else gcd b (a mod b) in
    let g = gcd f.w f.dest_w in
    (f.dest_w / g, f.w / g)

(** A sound the registry names.

   The tag is what the game asks for - `snd_damage`, `snd_cascade3` - and it is
   what [Engine_PLAY_SOUND_4b38a0] is passed, so the port addresses sounds the
   same way rather than by filename.

   [file] is where the audio actually is, and it is **not** derivable from the tag
   by one rule: most tags are `snd_<stem>` for a `<Stem>.wav`, the four element
   sounds carry a `Mana` suffix, the buttons are `Button*`, and the voices sit in
   a per-language directory behind a `V` prefix. [how] records which of those got
   the tag, so a reader can tell a straight filename match from a rename.

   [Absent] is worth noticing: **every `music_*` tag has no file behind it in this
   archive.** There is no music to play, and a music player written against this
   table would find that out at runtime. *)
type sound = {
  tag : string;
  kind : string;  (* "interface" or "music" *)
  priority : int;
  fade : int;
  file : string option;  (** relative to assets/gfx *)
  how : string;  (* "Exact" | "Renamed" | "Absent" *)
}

let sounds : sound array =""")
    w("  [|")
    for a, path, how in sounds:
        if path is None:
            f = "None"
        elif path.startswith("Assets/"):
            f = "Some " + ocaml_str(path.split("/", 1)[1])
        else:
            f = "Some " + ocaml_str(path)
        w("    { tag = %s; kind = %s; priority = %s; fade = %s; file = %s; how = %s };"
          % (ocaml_str(a.get("tag", "")), ocaml_str(a.get("type", "")),
             a.get("priority", "0"), a.get("fade", "0"), f, ocaml_str(how)))
    w("  |]\n")

    w("""let sound_of_tag (tag : string) : sound option =
  let rec go (l : sound list) =
    match l with
    | [] -> None
    | (s : sound) :: rest -> if s.tag = tag then Some s else go rest
  in
  go (Array.to_list sounds)

(** The file for a sound tag, or [None] if the registry has no audio for it.

    This is the one place a missing sound is allowed to be missing: the original
    also asks for sounds that are not there - every music tag - and
    `Engine_PLAY_SOUND_4b38a0` looks the name up in a map and plays what it finds,
    which is nothing. *)
let sound_file (tag : string) : string option =
  match sound_of_tag tag with Some s -> s.file | None -> None

(** The sounds that actually have audio behind them. *)
let playable_sounds : sound array =
  Array.of_list (List.filter (fun (s : sound) -> s.file <> None) (Array.to_list sounds))""")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--zip", type=pathlib.Path, default=REPO / "game" / "Assets.zip")
    ap.add_argument("--language", default="English",
                    help="whose voice lines to resolve")
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if the committed file differs")
    args = ap.parse_args()

    if not args.zip.is_file():
        print(f"error: {args.zip} not found", file=sys.stderr)
        return 1
    try:
        with zipfile.ZipFile(args.zip) as z:
            raw = z.read(REGISTRY).decode("utf-8")
            sounds = parse_sounds(z, args.language)
    except (zipfile.BadZipFile, KeyError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    sheets = [(m.group(1), m.group(2)) for m in SHEET_RE.finditer(raw)]
    frames = [attrs(m.group(1)) for m in FRAME_RE.finditer(raw)]
    known = {t for t, _ in sheets}
    orphans = [f["tag"] for f in frames if f["bitmap"] not in known]
    if not sheets or not frames:
        print("error: registry parsed empty", file=sys.stderr)
        return 1

    resolved = sum(1 for _, p, _ in sounds if p)
    print(f"  {len(sheets)} sheets, {len(frames)} named frames")
    print(f"  {len(sounds)} named sounds, {resolved} of them with audio behind them")
    if orphans:
        # Not fatal: the registry references sheets this parse did not see, and the
        # port only needs the ones it draws. Worth printing rather than dropping.
        print(f"  note: {len(orphans)} frames name an unseen sheet, e.g. "
              f"{', '.join(orphans[:3])}", file=sys.stderr)

    text = render(sheets, frames, sounds)

    if args.check:
        if not args.out.is_file():
            print(f"error: {args.out} missing", file=sys.stderr)
            return 1
        if args.out.read_text(encoding="utf-8") != text:
            print(f"error: {args.out} is stale, re-run tools/extract_skin_data.py",
                  file=sys.stderr)
            return 1
        print("  up to date")
        return 0

    args.out.write_text(text, encoding="utf-8")
    print(f"  wrote {args.out} ({len(text):,d} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())