"""Disassemble the function containing a VA, plus a window around it.

    python tools/disasm_at.py 0x48a118 [--before 0x200] [--window 0x300]

Finds the function start by walking back over MSVC's 0xCC padding, then
disassembles forward from there (or from --before bytes before the address)
for --window bytes.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import pefile

try:
    import capstone
except ImportError:  # pragma: no cover
    sys.exit("capstone is required: pip install -r requirements.txt")

REPO = pathlib.Path(__file__).resolve().parent.parent
BIN = REPO / "game" / "Puzzle Quest.unpacked.exe"


def load():
    pe = pefile.PE(str(BIN))
    data = BIN.read_bytes()
    return pe, data


def off_of(pe, data, va: int) -> int:
    rva = va - pe.OPTIONAL_HEADER.ImageBase
    for s in pe.sections:
        if s.VirtualAddress <= rva < s.VirtualAddress + max(s.Misc_VirtualSize, s.SizeOfRawData):
            return rva - s.VirtualAddress + s.PointerToRawData
    raise SystemExit(f"va {va:#x} not in any section")


def va_of(pe, off: int) -> int:
    for s in pe.sections:
        if s.PointerToRawData <= off < s.PointerToRawData + s.SizeOfRawData:
            return pe.OPTIONAL_HEADER.ImageBase + (off - s.PointerToRawData + s.VirtualAddress)
    raise SystemExit(f"off {off:#x} not in any section")


def func_start(data, off: int) -> int:
    i = off
    while i > 0 and data[i - 1] != 0xCC:
        i -= 1
    return i


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("va", help="address inside the function")
    ap.add_argument("--before", default="0", help="start this many bytes before va")
    ap.add_argument("--window", default="0x400")
    ap.add_argument("--func", action="store_true", help="start at the function entry")
    args = ap.parse_args()

    va = int(args.va, 0)
    pe, data = load()
    off = off_of(pe, data, va)
    start = func_start(data, off) if args.func else off - int(args.before, 0)
    window = int(args.window, 0)

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    print(f"; entry guess {va_of(pe, func_start(data, off)):#x}")
    for insn in md.disasm(data[start : start + window], va_of(pe, start)):
        mark = "  <--" if insn.address == va else ""
        print(f"{insn.address:08x}  {insn.mnemonic:8s} {insn.op_str}{mark}")
        if insn.mnemonic == "ret" and insn.address > va:
            break


if __name__ == "__main__":
    main()
