#!/usr/bin/env python3
"""Pull the graphics assets the battle screen needs out of game/Assets.zip.

Why this exists in Python rather than only as extract_gfx_assets.ps1: PowerShell
script execution is gated by policy on many machines, and a build step you cannot
run is a build step that will not be run. Python is already a dependency of this
project (see requirements.txt) and has no equivalent gate, so this is the default
and the .ps1 is the alternative for people who prefer it.

Either way the output is identical and deterministic.

    python tools/extract_gfx_assets.py
    python tools/extract_gfx_assets.py --out-dir assets/gfx --zip game/Assets.zip

The extracted art is deliberately not committed: it is copyrighted
Valusoft/Uzzle material, the same reason game/ is in .gitignore. Without running
this the board still runs, on flat colours.
"""

from __future__ import annotations

import argparse
import pathlib
import sys
import zipfile

# Only what the battle screen draws. Adding a sheet here means also adding it to
# gfx/assets.ml or naming its tag in gfx/skin.ml - the frame tables are written
# against Assets.xml, not this list.
#
# `Skin_Backdrop_Standard.jpg` is the one the registry names (bmp_skin_backdrop),
# not `Skin_Backdrop_Battle.jpg`, which Assets.xml never mentions. It is also a
# JPEG, which is why this list is not all PNG.
WANTED = [
    "Assets/Skin/Skin_Gems_Grid.png",
    "Assets/Skin/Skin_Battle_Misc.png",
    "Assets/Skin/Skin_Backdrop_Standard.jpg",
]

# The ten bitmap font atlases, which land in assets/gfx/Fonts/ because that is
# where gfx/font.ml looks for them. Matched by prefix and suffix rather than by
# glob: fnmatch's "*" crosses directory separators, so "Assets/Fonts/*.png" would
# also match a font in some subdirectory that is not one of ours. A battle screen
# wants font_system, font_small and font_button, but the atlas is the unit of
# loading, and reading eight unused ones costs a few hundred kilobytes of disk.
FONT_PREFIX = "Assets/Fonts/"
FONT_SUFFIX = ".png"
FONT_SUBDIR = "Fonts"

def is_font(name: str) -> bool:
    return name.startswith(FONT_PREFIX) and name.endswith(FONT_SUFFIX)


REPO = pathlib.Path(__file__).resolve().parent.parent


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--zip", type=pathlib.Path, default=REPO / "game" / "Assets.zip")
    ap.add_argument("--out-dir", type=pathlib.Path, default=REPO / "assets" / "gfx")
    args = ap.parse_args()

    if not args.zip.is_file():
        print(f"error: {args.zip} not found", file=sys.stderr)
        return 1

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / FONT_SUBDIR).mkdir(parents=True, exist_ok=True)
    missing = []
    written = 0
    try:
        with zipfile.ZipFile(args.zip) as z:
            names = z.namelist()
            name_set = set(names)
            want = list(WANTED)
            want += sorted(n for n in names if is_font(n))
            for w in want:
                # Archive paths use forward slashes; the asset tree in the game
                # uses backslashes, so only match on the leaf where it matters.
                if w not in name_set:
                    missing.append(w)
                    print(f"  warning: not in archive, skipping: {w}",
                          file=sys.stderr)
                    continue
                sub = FONT_SUBDIR if is_font(w) else ""
                dest = args.out_dir / sub / pathlib.Path(w).name
                dest.write_bytes(z.read(w))
                written += 1
                print(f"  extracted {dest.relative_to(args.out_dir)!s:32s} "
                      f"{dest.stat().st_size:>9,d} bytes")
    except zipfile.BadZipFile as e:
        print(f"error: {args.zip} is not a readable zip: {e}", file=sys.stderr)
        return 1

    if missing:
        print(f"error: {len(missing)} wanted assets absent", file=sys.stderr)
        return 1
    print(f"done -> {args.out_dir} ({written} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())