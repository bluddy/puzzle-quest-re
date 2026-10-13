"""Print the push sequence immediately before each call to an address.

    python tools/callsite_args.py 0x47d4f0 0x47d000 0x47d600

Reads the pushes right-to-left (last push = first stack argument) for every
`call` to the target in the window, which is how a call's arguments are read
out of a disassembly without a decompiler re-run.
"""
from __future__ import annotations

import pathlib
import struct
import sys

import capstone
import pefile

REPO = pathlib.Path(__file__).resolve().parent.parent
BIN = REPO / "game" / "Puzzle Quest.unpacked.exe"

PUSHES = {"push", "pushal", "pushad", "pusha"}
# An instruction that ends the straight-line run before a call.
FLOWS = {"ret", "retf", "jmp", "call", "jo", "jno", "jb", "jae", "je", "jne",
         "jbe", "ja", "js", "jns", "jp", "jnp", "jl", "jge", "jle", "jg",
         "loop", "loope", "loopne", "int", "iret", "iretd", "ud2"}


def main() -> None:
    target = int(sys.argv[1], 0)
    lo = int(sys.argv[2], 0) if len(sys.argv) > 2 else target - 0x800
    hi = int(sys.argv[3], 0) if len(sys.argv) > 3 else target + 0x800

    pe = pefile.PE(str(BIN))
    data = BIN.read_bytes()
    base = pe.OPTIONAL_HEADER.ImageBase

    def off(va: int) -> int:
        rva = va - base
        for s in pe.sections:
            if s.VirtualAddress <= rva < s.VirtualAddress + max(s.Misc_VirtualSize, s.SizeOfRawData):
                return rva - s.VirtualAddress + s.PointerToRawData
        raise SystemExit(f"va {va:#x} not mapped")

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    insns = list(md.disasm(data[off(lo) : off(hi)], lo))
    by_addr = {i.address: n for n, i in enumerate(insns)}

    for n, i in enumerate(insns):
        if i.mnemonic != "call":
            continue
        # Direct call to the target, absolute or relative.
        hit = False
        if i.op_str == hex(target):
            hit = True
        elif i.op_str.startswith("0x"):
            try:
                hit = int(i.op_str, 16) == target
            except ValueError:
                hit = False
        if not hit:
            continue

        # Walk backwards collecting pushes until a flow instruction.
        pushes: list[str] = []
        m = n - 1
        while m >= 0 and len(pushes) < 12:
            p = insns[m]
            if p.mnemonic in PUSHES:
                pushes.append(p.op_str)
            elif p.mnemonic in FLOWS or p.mnemonic.startswith("j"):
                break
            m -= 1
        pushes.reverse()  # now left-to-right = first-pushed ... last-pushed
        # Stack args, first argument first: last push is arg1.
        args = list(reversed(pushes))
        print(f"{i.address:#010x}  call {target:#x}")
        for k, a in enumerate(args, start=1):
            print(f"      arg{k} = push {a}")


if __name__ == "__main__":
    main()