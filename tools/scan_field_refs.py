"""Find every instruction in the battle binary that touches a struct field offset.

The Lua_* wrappers in docs/decompiled/ show the multiplier flags being *written*
at +0x390/+0x391/+0x392 but never read, which left the port guessing whether a
consumer exists. This scans the real .text section for references to a given
displacement so the question can be answered from the binary instead.

Usage:
    python tools/scan_field_refs.py 0x390 0x391 0x392
    python tools/scan_field_refs.py 0x392 --context 12

Writes are reported separately from reads, because a field that is only ever
written is a field with no consumer - which is a finding, not a gap.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import sys

try:
    import pefile
except ImportError:  # pragma: no cover
    sys.exit("pefile is required: pip install -r requirements.txt")

try:
    import capstone
except ImportError:  # pragma: no cover
    sys.exit("capstone is required: pip install -r requirements.txt")

REPO = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_BINARIES = [
    REPO / "game" / "Puzzle Quest.unpacked.exe",
    REPO / "game" / "Puzzle Quest.exe",
]

# x86 mnemonics that only consume their memory operand, i.e. a read. Anything
# else touching the displacement is a write (or a read-modify-write, which we
# report as such rather than guessing).
READ_ONLY = {"cmp", "test", "push"}
# Reads the operand and leaves it in a register.
READ_MOVE = {"movzx", "movsx", "mov"}
WRITE_ONLY = {"mov", "stosb"}


def classify(insn) -> str:
    """Best-effort read/write classification for the matched operand."""
    mnem = insn.mnemonic
    ops = insn.operands
    mems = [i for i, op in enumerate(ops) if op.type == capstone.x86.X86_OP_MEM]
    if not mems:
        return "?"
    last = mems[-1]
    # For mov, operand 0 is the destination: `mov [eax+N], bl` writes the field,
    # `mov al, [eax+N]` reads it. Both are mnemonics "mov", so position decides.
    if mnem in READ_ONLY:
        return "read"
    if mnem in READ_MOVE:
        return "write" if last == 0 else "read"
    if mnem in WRITE_ONLY:
        return "write"
    if mnem.startswith("j") or mnem in {"call", "ret", "nop", "int3"}:
        return "other"
    return "read-modify-write"


def scan(binary: pathlib.Path, wanted: set[int]):
    pe = pefile.PE(str(binary), fast_load=True)
    image_base = pe.OPTIONAL_HEADER.ImageBase
    text = None
    for section in pe.sections:
        if section.Name.rstrip(b"\x00") == b".text":
            text = section
            break
    if text is None:
        sys.exit(f"no .text section in {binary}")

    code = text.get_data()
    start = image_base + text.VirtualAddress

    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    # .text opens with import thunks and jump tables, and md.disasm() silently
    # stops at the first byte it cannot decode. Without skipdata the scan covers
    # only the first few hundred bytes and reports "no references" for
    # everything - which is exactly the false negative this tool exists to avoid.
    md.skipdata = True

    hits = collections.defaultdict(list)
    decoded = 0
    for insn in md.disasm(code, start):
        decoded += 1
        if insn.id == 0:
            continue
        for op in insn.operands:
            if op.type != capstone.x86.X86_OP_MEM:
                continue
            disp = op.mem.disp & 0xFFFFFFFF
            if disp in wanted:
                hits[disp].append((insn.address, insn, classify(insn)))
    return hits, md, code, start, decoded


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("offsets", nargs="+", help="field offsets, e.g. 0x390")
    ap.add_argument("--binary", type=pathlib.Path, default=None)
    ap.add_argument(
        "--context",
        type=int,
        default=0,
        help="print N instructions around each hit (implies --show-all)",
    )
    ap.add_argument(
        "--show-all", action="store_true", help="list every hit, not just a summary"
    )
    args = ap.parse_args()

    wanted = {int(o, 0) for o in args.offsets}
    binary = args.binary
    if binary is None:
        binary = next((p for p in DEFAULT_BINARIES if p.exists()), None)
    if binary is None or not binary.exists():
        sys.exit("no binary found; pass --binary")

    hits, md, code, start, decoded = scan(binary, wanted)
    coverage = decoded * 100.0 / max(len(code), 1)
    print(
        f"{binary.name}: .text {len(code):,} bytes, {decoded:,} instructions "
        f"decoded ({coverage:.1f}% of bytes touched)"
    )
    if coverage < 50:
        print(
            "  WARNING: low decode coverage - treat a 'no references' result as "
            "unproven rather than as evidence of absence."
        )
    print()

    print(f"{binary.name}: {len(wanted)} offset(s) requested\n")
    for off in sorted(wanted):
        found = hits.get(off, [])
        if not found:
            print(f"+0x{off:03x}: NO REFERENCES - field is never touched")
            continue
        kinds = collections.Counter(k for _, _, k in found)
        summary = ", ".join(f"{n} {k}" for k, n in sorted(kinds.items()))
        print(f"+0x{off:03x}: {len(found)} reference(s) [{summary}]")
        reads = [h for h in found if h[2] == "read"]
        writes = [h for h in found if h[2] == "write"]
        print(f"          reads: {len(reads)}   writes: {len(writes)}")
        if not reads:
            print("          => NO CONSUMER: written but never read")
        if args.context or args.show_all:
            limit = len(found) if args.context == 0 else 10**9
            shown = 0
            for addr, insn, kind in found:
                if shown >= limit:
                    break
                shown += 1
                print(f"          0x{addr:08x}  {kind:20s} {insn.mnemonic} {insn.op_str}")
                if args.context:
                    lo = addr - 0x40
                    region = code[lo - start : addr - start]
                    for near in md.disasm(region, lo):
                        if near.address >= addr:
                            break
                        print(f"                     | {near.mnemonic} {near.op_str}")
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())