"""Sample pixels of a P6 ppm and print them as a small layout audit.

    python tools/shot_probe.py battle_ui.ppm 13,121 20,130 100,470 ...
"""
import sys
from pathlib import Path


def load(path):
    data = Path(path).read_bytes()
    # P6\n<w> <h>\n255\n
    parts = data.split(b"\n", 3)
    header = parts[0]
    if header != b"P6":
        raise SystemExit(f"{path}: not a P6 ppm ({header!r})")
    dims = parts[1].split()
    w, h = int(dims[0]), int(dims[1])
    body = parts[3] if len(parts) > 3 else b""
    return w, h, body


def px(w, body, x, y):
    i = (y * w + x) * 3
    return tuple(body[i : i + 3])


def main():
    path = sys.argv[1]
    w, h, body = load(path)
    print(f"{path}: {w}x{h}")
    for arg in sys.argv[2:]:
        x, y = (int(v) for v in arg.split(","))
        r, g, b = px(w, body, x, y)
        print(f"  ({x:4d},{y:4d}) = {r:3d},{g:3d},{b:3d}")


if __name__ == "__main__":
    main()
