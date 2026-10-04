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
# gfx/assets.ml - the frame table there is written against Assets.xml, not this
# list.
WANTED = [
    "Assets/Skin/Skin_Gems_Grid.png",
    "Assets/Skin/Skin_Battle_Misc.png",
    "Assets/Skin/Skin_Backdrop_Battle.jpg",
]

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
    missing = []
    try:
        with zipfile.ZipFile(args.zip) as z:
            names = set(z.namelist())
            for want in WANTED:
                # Archive paths use forward slashes; the asset tree in the game
                # uses backslashes, so only match on the leaf where it matters.
                if want not in names:
                    missing.append(want)
                    print(f"  warning: not in archive, skipping: {want}",
                          file=sys.stderr)
                    continue
                dest = args.out_dir / pathlib.Path(want).name
                dest.write_bytes(z.read(want))
                print(f"  extracted {dest.name:32s} {dest.stat().st_size:>9,d} bytes")
    except zipfile.BadZipFile as e:
        print(f"error: {args.zip} is not a readable zip: {e}", file=sys.stderr)
        return 1

    print(f"done -> {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())