#!/usr/bin/env python3
"""Generate lib/cutscene_data.ml from the game's cutscene descriptors.

A cutscene is two XML files and a JPEG:

    <Lang>/CutScenes/<Name>.xml     the outer timing layer: total duration,
                                    voice path, the slideshow viewport, the
                                    subtitle anchor (textx/texty), font, and
                                    the timed <Text time=...> cue lines -
                                    these are the ONLY part that differs per
                                    language (plus the voice path, .ogg for
                                    English, .wav elsewhere)
    Assets/CutScenes/<Name>.xml     the inner SlideShow: Bitmaps (the JPEGs),
                                    Images (a placed bitmap inside the
                                    viewport), Clears (letterbox strips), and
                                    Displays - a window [start, start+duration)
                                    in which an image shows, optionally
                                    keyframed (alpha fades, y pans; key times
                                    are relative to the display's start)
    Assets/CutScenes/<Name>.jpg     the art (the pc/ subdir carries the logo
                                    slides' own descriptors and JPEGs)

Both layers name the same viewport, which is what the player clips to - the
chapter slides draw a 1024x630 image inside a 0,128,1024x512 band with the
subtitles below at textx/texty.

The 18 scenes ship: six story chapters (Chap1_Intro .. Chap4_End_*) with four
cue lines each, and twelve Logo_* publisher/rating slides with no cues. Only
Logo_ESRB_10 is referenced by the executable (the boot splash, pushed at
0x4d88f1); the five QUEST_CUTSCENE calls in the quest corpus play Chap2/3/4
and Q3Q7's two endings; Chap1_Intro and the other eleven logos are referenced
by nothing in this build.

    python tools/extract_cutscenes.py            # -> lib/cutscene_data.ml
    python tools/extract_cutscenes.py --check    # fail if stale
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import xml.etree.ElementTree as ET

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT = REPO / "lib" / "cutscene_data.ml"
ASSETS = REPO / "game" / "Assets"

LANGUAGES = ("English", "French", "German", "Italian", "Spanish")
SCENE_DIR = ASSETS / "English" / "CutScenes"


def ocaml_string(s: str) -> str:
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


def outer_path(language: str, name: str) -> pathlib.Path:
    return ASSETS / language / "CutScenes" / f"{name}.xml"


def inner_path(file_attr: str) -> pathlib.Path | None:
    """Resolve the outer's file= attribute: Assets/CutScenes/<name>.xml,
    with the pc/ subdir fallback the logo slides need (their inner files live
    only there)."""
    rel = file_attr.replace("\\", "/")
    direct = ASSETS / rel
    if direct.is_file():
        return direct
    pc = ASSETS / "Assets" / "CutScenes" / "pc" / pathlib.Path(rel).name
    if pc.is_file():
        return pc
    return None


def resolve_bitmap(rel: str) -> str:
    """Point a bitmap at the file that actually ships: most sit directly
    under Assets/CutScenes, the logo slides' art only under its pc/
    subdirectory (ESRB_10.jpg, Logo_valusoft.jpg ...). Emits the real path
    so the player's ordinary loader finds it without a fallback. """
    rel = rel.replace("\\", "/")
    if (ASSETS / rel).is_file():
        return rel
    name = pathlib.Path(rel).name
    pc = ASSETS / "Assets" / "CutScenes" / "pc" / name
    if pc.is_file():
        return f"Assets/CutScenes/pc/{name}"
    return rel


def parse_inner(path: pathlib.Path) -> tuple[list[str], list[tuple[int, int, int, int]],
                                             list[tuple[int, int, int, int, int, int]],
                                             list[dict]]:
    root = ET.parse(path).getroot()
    bitmaps: list[str] = []
    for b in root.findall("Bitmap"):
        i = int(b.get("id", "0"))
        while len(bitmaps) <= i:
            bitmaps.append("")
        bitmaps[i] = resolve_bitmap(b.get("file", ""))
    images: dict[int, tuple[int, int, int, int, int, int]] = {}
    for im in root.findall("Image"):
        images[int(im.get("id", "0"))] = (
            int(im.get("bitmap", "0")),
            int(im.get("x", "0")),
            int(im.get("y", "0")),
            int(im.get("width", "0")),
            int(im.get("height", "0")),
            int(im.get("id", "0")),
        )
    displays: list[dict] = []
    for d in root.findall("Display"):
        keys = [
            {"param": k.get("parameter", ""), "value": float(k.get("value", "0")),
             "time": int(k.get("time", "0"))}
            for k in d.findall("Key")
        ]
        displays.append({
            "image": int(d.get("image", "0")),
            "start": int(d.get("start", "0")),
            "duration": int(d.get("duration", "0")),
            "keys": keys,
        })
    # image placement lives in image order of appearance: emit as an array
    # indexed by image id (the display refers to it by id)
    n = (max(images) + 1) if images else 0
    place = []
    for i in range(n):
        if i in images:
            bitmap, x, y, w, h, _ = images[i]
            place.append((i, bitmap, x, y, w, h))
        else:
            place.append((i, 0, 0, 0, 0, 0))
    vx = int(root.get("x", "0"))
    vy = int(root.get("y", "0"))
    vw = int(root.get("width", "1024"))
    vh = int(root.get("height", "768"))
    return bitmaps, place, [(vx, vy, vw, vh)], displays


def load() -> dict[str, dict]:
    """name -> {outer per language, inner structures}."""
    names = sorted(p.stem for p in SCENE_DIR.glob("*.xml"))
    out: dict[str, dict] = {}
    for name in names:
        entry: dict = {"outer": {}, "inner": None}
        file_attr = None
        for lang in LANGUAGES:
            p = outer_path(lang, name)
            if not p.is_file():
                continue
            root = ET.parse(p).getroot()
            file_attr = file_attr or root.get("file", "")
            cues = [
                (int(t.get("time", "0")), t.text or "")
                for t in root.findall("Text")
            ]
            entry["outer"][lang] = {
                "duration": int(root.get("duration", "0")),
                "voice": root.get("voice", "").replace("\\", "/"),
                "voicedelay": int(root.get("voicedelay", "0")),
                "sound": root.get("sound", ""),
                "font": root.get("font", ""),
                "textx": int(root.get("textx", "0")),
                "texty": int(root.get("texty", "0")),
                "cues": cues,
            }
        if file_attr:
            inner = inner_path(file_attr)
            if inner is None:
                # Logo_non_usa ships its outer timing but no inner slideshow
                # anywhere (neither Assets/CutScenes nor pc/) - an orphaned
                # descriptor for a build we do not have. Skip it rather than
                # fail: nothing references it either.
                print(f"  note: {name} has no inner slideshow - skipped",
                      file=sys.stderr)
                continue
            bitmaps, place, viewport, displays = parse_inner(inner)
            entry["inner"] = {
                "bitmaps": bitmaps, "place": place, "viewport": viewport,
                "displays": displays,
            }
        out[name] = entry
    return out


def render(data: dict[str, dict]) -> str:
    lines = [
        "(* Generated by tools/extract_cutscenes.py - do not edit. *)",
        "",
        "(* The cutscene descriptors: the outer timing layer per language (total",
        "   duration, subtitle anchor, the timed cues - the only per-language",
        "   part besides the voice path) over the shared inner SlideShow",
        "   (bitmaps, image placements inside the viewport, and the Display",
        "   timeline, whose Key lists interpolate alpha and y relative to the",
        "   display's own start).",
        "",
        "   The viewport is what the player clips to - the chapter slides draw",
        "   a 1024x630 image inside a 0,128,1024x512 band with the subtitles",
        "   below at textx/texty. Image id 0 in the logo slides is a placed",
        "   off-screen thumb, so its displays read as black - the 'Black' the",
        "   slideshow comments call them.",
        "",
        "   Only Logo_ESRB_10 is pushed by the executable (the boot splash),",
        "   the five QUEST_CUTSCENE sites play Chap2/3/4 and Q3Q7's two",
        "   endings, and Chap1_Intro plus the other eleven logos are referenced",
        "   by nothing in this build - the port plays Chap1 on New Quest, a",
        "   documented port choice (port.cutscene_shell). *)",
        "",
        "(** One keyframed value: [param] is \"alpha\" or \"y\", linearly",
        "    interpolated against [time] (ms, relative to its display's start). *)",
        "type key = { param : string; value : float; time : int }",
        "",
        "(** A placed bitmap inside the viewport: [bitmap] indexes the",
        "    slideshow's bitmap list; x/y are viewport-relative. *)",
        "type placement = {",
        "  image_id : int;",
        "  bitmap : int;",
        "  x : int;",
        "  y : int;",
        "  w : int;",
        "  h : int;",
        "}",
        "",
        "(** [start_ms, start_ms+dur_ms) of visibility; drawn in document order",
        "    so later displays layer over earlier ones. *)",
        "type display = {",
        "  image : int;",
        "  start_ms : int;",
        "  dur_ms : int;",
        "  keys : key list;",
        "}",
        "",
        "type slideshow = {",
        "  bitmaps : string list;  (** JPEG paths, resolved by the player *)",
        "  viewport : int * int * int * int;  (** x, y, w, h on screen *)",
        "  placements : placement list;  (** indexed by image id *)",
        "  displays : display list;",
        "}",
        "",
        "type cue = { time_ms : int; text : string }",
        "",
        "type scene = {",
        "  duration : int;  (** total wall time, ms - outlives the slideshow *)",
        "  font : string;",
        "  textx : int;  (** subtitle anchor, screen coordinates *)",
        "  texty : int;",
        "  voice : string array;  (** [lang id] voice path (unwired: no audio *)",
        "  cues : cue array array;  (** [lang id] - the text layer only *)",
        "  slide : slideshow;",
        "}",
        "",
        "let scenes : (string * scene) list = [",
    ]
    for name in sorted(data):
        entry = data[name]
        en = entry["outer"].get("English") or next(iter(entry["outer"].values()))
        inner = entry["inner"]
        lines.append(f"  ({ocaml_string(name)}, {{")
        lines.append(f"    duration = {en['duration']};")
        lines.append(f"    font = {ocaml_string(en['font'])};")
        lines.append(f"    textx = {en['textx']}; texty = {en['texty']};")
        voices = "; ".join(
            ocaml_string(entry["outer"].get(L, {}).get("voice", ""))
            for L in LANGUAGES)
        lines.append(f"    voice = [| {voices} |];")
        lines.append("    cues = [|")
        for L in LANGUAGES:
            cues = entry["outer"].get(L, {}).get("cues", [])
            parts = "; ".join(
                f"{{ time_ms = {t}; text = {ocaml_string(txt)} }}"
                for t, txt in cues)
            lines.append(f"      [| {parts} |];")
        lines.append("    |];")
        lines.append("    slide = {")
        bm = "; ".join(ocaml_string(b) for b in inner["bitmaps"])
        lines.append(f"      bitmaps = [ {bm} ];")
        vx, vy, vw, vh = inner["viewport"][0]
        lines.append(f"      viewport = ({vx}, {vy}, {vw}, {vh});")
        lines.append("      placements = [")
        for i, bitmap, x, y, w, h in inner["place"]:
            lines.append(
                f"        {{ image_id = {i}; bitmap = {bitmap}; x = {x}; "
                f"y = {y}; w = {w}; h = {h} }};")
        lines.append("      ];")
        lines.append("      displays = [")
        for d in inner["displays"]:
            lines.append(
                f"        {{ image = {d['image']}; start_ms = {d['start']}; "
                f"dur_ms = {d['duration']};")
            if d["keys"]:
                keys = "; ".join(
                    f"{{ param = {ocaml_string(k['param'])}; "
                    f"value = {k['value']}; time = {k['time']} }}"
                    for k in d["keys"])
                lines.append(f"          keys = [ {keys} ];")
            else:
                lines.append("          keys = [];")
            lines.append("        };")
        lines.append("      ];")
        lines.append("    };")
        lines.append("  });")
    lines += [
        "]",
        "",
        "(* The lookup takes what the scripts carry: \"CutScenes\\\\Chap2_Intro.xml\"",
        "   or a bare name - backslashes normalised, directories dropped, .xml",
        "   chopped. *)",
        "let scene_of (name : string) : scene option =",
        "  let norm = String.map (fun c -> if c = '\\\\' then '/' else c) name in",
        "  let base = Filename.basename norm in",
        "  let base =",
        "    if Filename.check_suffix base \".xml\" then",
        "      Filename.chop_suffix base \".xml\"",
        "    else base",
        "  in",
        "  List.assoc_opt base scenes",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if the committed file differs")
    args = ap.parse_args()

    data = load()
    if not data:
        print("error: no cutscenes parsed", file=sys.stderr)
        return 1
    story = sum(1 for v in data.values() if v["outer"].get("English", {}).get("cues"))
    print(f"  {len(data)} scenes ({story} with cues), "
          f"{len(LANGUAGES)} languages")
    text = render(data)

    if args.check:
        if not OUT.is_file():
            print(f"error: {OUT} missing", file=sys.stderr)
            return 1
        if OUT.read_text(encoding="utf-8") != text:
            print("error: lib/cutscene_data.ml is stale, "
                  "re-run tools/extract_cutscenes.py", file=sys.stderr)
            return 1
        print("  up to date")
        return 0

    OUT.write_text(text, encoding="utf-8")
    print(f"  wrote {OUT} ({len(text):,d} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
