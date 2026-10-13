"""Print the rectangles Assets/Screens/*.xml declares for the names asked for.

    python tools/screen_rects.py GameMenu.xml pad_grid str_turn ...
"""
import re
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ZIP = REPO / "game" / "Assets.zip"

PAT = re.compile(
    r'name="(?P<name>[^"]+)"[^>]*?x="(?P<x>-?\d+)"\s+y="(?P<y>-?\d+)"'
    r'\s+width="(?P<w>-?\d+)"\s+height="(?P<h>-?\d+)"'
)


def main() -> None:
    screen = sys.argv[1] if len(sys.argv) > 1 else "GameMenu.xml"
    want = set(sys.argv[2:])
    with zipfile.ZipFile(ZIP) as z:
        text = z.read(f"Assets/Screens/{screen}").decode("utf-8", "replace")
    for m in PAT.finditer(text):
        name = m.group("name")
        if want and not any(name == w or name.startswith(w) for w in want):
            continue
        print(
            f"{name:24s} x={m.group('x'):>5s} y={m.group('y'):>4s} "
            f"w={m.group('w'):>4s} h={m.group('h'):>4s}"
        )


if __name__ == "__main__":
    main()
