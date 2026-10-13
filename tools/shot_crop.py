"""Crop and nearest-neighbour enlarge a region of a P6 ppm, writing a png.

    python tools/shot_crop.py battle_ui.ppm x y w h scale out.png
"""
from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def main() -> None:
    src = Path(sys.argv[1])
    x, y, w, h, scale = (int(v) for v in sys.argv[2:7])
    out = Path(sys.argv[7])

    raw = src.read_bytes()
    head, rest = raw.split(b"\n", 1)
    dims, body = rest.split(b"\n", 1)
    if body.startswith(b"255"):
        body = body.split(b"\n", 1)[1]
    sw, sh = (int(v) for v in dims.split())
    if head != b"P6" or len(body) != sw * sh * 3:
        raise SystemExit(f"{src}: not a raw P6 ({head}, {len(body)} bytes)")

    rows = bytearray()
    for dy in range(h * scale):
        sy = y + dy // scale
        row = bytearray()
        for dx in range(w * scale):
            sx = x + dx // scale
            i = (sy * sw + sx) * 3
            row += body[i : i + 3]
        rows += b"\x00" + bytes(row)

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(rows), 6))
        + chunk(b"IEND", b"")
    )
    out.write_bytes(png)
    print(f"wrote {out} ({w * scale}x{h * scale})")


if __name__ == "__main__":
    main()
