"""Convert a P6 ppm (what `--shot` writes) to a PNG, with no dependencies.

    python tools/ppm_to_png.py battle_ui.ppm [out.png]

The graphics front writes PPM because reading the framebuffer back gives raw
RGB and a ppm is three lines of header; PNG is what a person can open. zlib and
struct are stdlib, so this costs nothing to keep around.
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
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_suffix(".png")

    raw = src.read_bytes()
    head, rest = raw.split(b"\n", 1)
    if head != b"P6":
        raise SystemExit(f"{src}: not a P6 ppm ({head!r})")
    dims, body = rest.split(b"\n", 1)
    w, h = (int(v) for v in dims.split())
    body = body.split(b"\n", 1)[1] if body.startswith(b"255") else body
    # Above only strips the maxval line when the split caught it; be explicit.
    if len(body) != w * h * 3:
        # The maxval line may still be attached to dims' next line.
        body = rest.split(b"\n", 2)[2] if len(rest.split(b"\n", 2)) > 2 else body
    if len(body) != w * h * 3:
        raise SystemExit(f"{src}: expected {w * h * 3} bytes, got {len(body)}")

    rows = b"".join(b"\x00" + body[y * w * 3 : (y + 1) * w * 3] for y in range(h))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 6))
        + chunk(b"IEND", b"")
    )
    dst.write_bytes(png)
    print(f"wrote {dst} ({w}x{h})")


if __name__ == "__main__":
    main()
