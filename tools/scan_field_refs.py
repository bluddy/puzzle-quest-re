"""Find every aligned instruction in the battle binary that touches a struct offset.

This answers "what reads this field?" properly. The naive version - linearly
sweeping .text with capstone - is not good enough, because x86 has no reliable
framing: once a linear sweep steps into a jump table or an embedded string it
desynchronises and every instruction after that point is decoded at the wrong
alignment. A sweep can report "no references" for an offset that is read
dozens of times, and the result is indistinguishable from a real answer.

So this walks the code instead of sweeping it, using recursive descent from
function entry points:

  * seeds are the PE entry point, the import thunks, every function pointer in
    a vtable-shaped run of .rdata, the PE export table, and any addresses
    already recovered into docs/decompiled/;
  * each seed is disassembled by following control flow, not by marching
    forward, so a mis-guessed branch never corrupts what follows it;
  * direct call targets are harvested as new seeds and the whole thing is
    iterated to a fixed point.

Coverage is then reported as the fraction of .text whose bytes were decoded as
instruction bytes by that walk. That number is the honest denominator for any
"no references" answer this tool gives.

Usage:
    python tools/scan_field_refs.py 0x390 0x391 0x392
    python tools/scan_field_refs.py 0x392 --context 20
    python tools/scan_field_refs.py --coverage-only
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
import struct
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

# Capstone groups x86 mnemonics; these are the control-flow ones we care about.
JMP = capstone.x86.X86_GRP_JUMP
CALL = capstone.x86.X86_GRP_CALL
RET = capstone.x86.X86_GRP_RET
INT = capstone.x86.X86_GRP_INT

TERMINATORS = {"ret", "retf", "retn", "iret", "iretd", "iretq",
               "int3", "int", "ud2", "hlt", "jmpl"}


def _all_printable(v: int) -> bool:
    """True if all four bytes are printable ASCII, i.e. the dword is text.

    This is the noise test for pointer scans. A code pointer essentially never
    has all four bytes printable, whereas a dword read out of the middle of a
    string almost always does. Note the weaker "printable or zero" test is
    useless here: every address in this image ends in a 0x00 byte, so it
    rejects almost every real function pointer.
    """
    return all(32 <= c <= 126 for c in struct.pack("<I", v))


class Binary:
    """A PE image with a recursive-descent code map over .text."""

    def __init__(self, path: pathlib.Path, use_decileaved_seeds: bool = True):
        self.path = path
        self.pe = pefile.PE(str(path), fast_load=False)
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.raw = self.pe.__data__

        text = next(
            s for s in self.pe.sections if s.Name.rstrip(b"\x00") == b".text"
        )
        self.text = text
        self.tlo = self.base + text.VirtualAddress
        self.thi = self.tlo + text.Misc_VirtualSize
        self.text_off = self.pe.get_offset_from_rva(text.VirtualAddress)
        self.code = self.text.get_data()

        self.md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        self.md.detail = True
        # Recursive descent must NOT skip data: stepping over an undecodable
        # byte is exactly the linear-sweep bug this tool exists to avoid.
        self.md.skipdata = False

        self._insn_at: dict[int, object] = {}
        self._covered: set[int] = set()      # addresses decoded as instructions
        self.func_starts: dict[int, str] = {}  # address -> provenance
        self.calls: set[int] = set()          # direct call targets in .text

        self.seed_provenance: collections.Counter = collections.Counter()
        if use_decileaved_seeds:
            self._seed()

    # ---------- helpers ----------
    def in_text(self, va: int) -> bool:
        return self.tlo <= va < self.thi

    def insn(self, va: int):
        """Decode the single instruction at va, or None if it is not code."""
        if va in self._insn_at:
            return self._insn_at[va]
        off = va - self.tlo
        if off < 0 or off >= len(self.code):
            self._insn_at[va] = None
            return None
        for i in self.md.disasm(self.code[off:off + 15], va, count=1):
            self._insn_at[va] = i
            # Mark every byte the instruction occupies, not just its first.
            # Counting only the start address makes "covered bytes" a synonym
            # for "instruction count" and turns each instruction's tail into a
            # phantom one-byte hole, which is how an earlier version of this
            # tool reported 26% coverage for a .text that is mostly code.
            for k in range(off, off + i.size):
                self._covered.add(k)
            return i
        self._insn_at[va] = None
        return None

    def branch_target(self, insn) -> int | None:
        """Absolute target of a direct relative branch, else None."""
        if not (insn.group(JMP) or insn.group(CALL)):
            return None
        ops = insn.operands
        if not ops or ops[0].type != capstone.x86.X86_OP_IMM:
            return None
        return ops[0].imm & 0xFFFFFFFF

    # ---------- seeding ----------
    def _add_seed(self, va: int, why: str) -> bool:
        if not self.in_text(va):
            return False
        if va in self.func_starts:
            return False
        self.func_starts[va] = why
        self.seed_provenance[why] += 1
        return True

    def _seed(self) -> None:
        # 1. PE entry point
        self._add_seed(self.base + self.pe.OPTIONAL_HEADER.AddressOfEntryPoint,
                       "entrypoint")

        # 2. import thunks: the IAT holds addresses that are jumped to through
        #    a one-instruction stub, so the thunks are code starts too.
        try:
            iat = self.pe.OPTIONAL_HEADER.DATA_DIRECTORY[
                pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IAT"]]
            lo = self.base + iat.VirtualAddress
            size = iat.Size
            off = self.pe.get_offset_from_rva(iat.VirtualAddress)
            for k in range(0, max(size, 0) - 3, 4):
                v = struct.unpack_from("<I", self.raw, off + k)[0]
                if self.in_text(v):
                    self._add_seed(v, "iat")
        except Exception:
            pass

        # 3. export table
        try:
            for e in self.pe.DIRECTORY_ENTRY_EXPORT.symbols:
                self._add_seed(e.address + self.base, "export")
        except Exception:
            pass

        # 4. vtable-shaped runs of .rdata. A C++ vtable is a run of code
        #    pointers terminated by a null or a non-code dword, and every entry
        #    is a function start.
        for sec in self.pe.sections:
            nm = sec.Name.rstrip(b"\x00")
            if nm in (b".rdata", b".data"):
                self._scan_pointer_runs(sec)

        # 5. addresses already recovered into docs/decompiled/. The filenames
        #    record offsets that are image-base relative, not absolute VAs.
        self._seed_from_decompiled()

        # 6. the byte after every run of int3 padding - the main seed source.
        self._seed_from_padding()

    def _scan_pointer_runs(self, sec) -> None:
        off = self.pe.get_offset_from_rva(sec.VirtualAddress)
        blob = self.raw[off:off + sec.SizeOfRawData]
        n = len(blob) // 4
        i = 0
        while i < n:
            v = struct.unpack_from("<I", blob, i * 4)[0]
            if not self.in_text(v) or _all_printable(v):
                i += 1
                continue
            j = i
            while j < n:
                w = struct.unpack_from("<I", blob, j * 4)[0]
                if not self.in_text(w) or _all_printable(w):
                    break
                j += 1
            # only runs long enough to be a dispatch table, not a stray pointer
            if j - i >= 5:
                for k in range(i, j):
                    self._add_seed(struct.unpack_from("<I", blob, k * 4)[0],
                                   "vtable")
            i = j

    def _seed_from_padding(self) -> None:
        """Seed the byte after every run of 0xCC.

        MSVC pads each function out to a 16-byte boundary with int3, so the byte
        after any run of 0xCC is a function start. This is by far the highest
        precision seed available in an image with no exception directory: 0xCC
        padding is unambiguous in a way that neither a linear sweep nor a
        pointer scan is.
        """
        code, n = self.code, len(self.code)
        i = 0
        while i < n:
            if code[i] == 0xCC:
                j = i
                while j < n and code[j] == 0xCC:
                    j += 1
                if j < n:
                    self._add_seed(self.tlo + j, "int3-padding")
                i = j
            else:
                i += 1

    def _seed_from_decompiled(self) -> None:
        dd = REPO / "docs" / "decompiled"
        if not dd.is_dir():
            return
        pat = re.compile(r"_([0-9a-fA-F]{5,8})\.c$")
        for f in dd.glob("*.c"):
            m = pat.search(f.name)
            if not m:
                continue
            v = int(m.group(1), 16)
            # Recorded offsets are image-base relative.
            for cand in (v + self.base, v):
                if self._add_seed(cand, "decompiled"):
                    break

    # ---------- traversal ----------
    def walk(self, start: int) -> int:
        """Recursively disassemble one function. Returns its highest address."""
        work = [start]
        seen: set[int] = set()
        highest = start
        while work:
            va = work.pop()
            while va not in seen:
                if not self.in_text(va):
                    break
                seen.add(va)
                insn = self.insn(va)
                if insn is None:
                    break
                highest = max(highest, insn.address + insn.size)
                tgt = self.branch_target(insn)
                mnem = insn.mnemonic
                if insn.group(CALL):
                    if tgt is not None and self.in_text(tgt):
                        self.calls.add(tgt)
                        self._add_seed(tgt, "call")
                    va = insn.address + insn.size
                    continue
                if insn.group(JMP):
                    if mnem.startswith("j") and mnem != "jmp":
                        # conditional: both edges are real code
                        if tgt is not None and self.in_text(tgt):
                            work.append(tgt)
                        va = insn.address + insn.size
                        continue
                    # unconditional jmp: tail call, target may be another seed
                    if tgt is not None and self.in_text(tgt):
                        self._add_seed(tgt, "jmp")
                        if tgt not in seen:
                            work.append(tgt)
                    break
                if mnem in TERMINATORS or insn.group(RET) or insn.group(INT):
                    break
                va = insn.address + insn.size
        return highest

    def build(self, max_rounds: int = 200, verbose: bool = False) -> None:
        """Walk every seed, then walk the call targets that walk exposed, until
        no new function appears.

        New call targets are discovered inside walk(), so this has to iterate to
        a fixed point rather than doing one pass: a single pass leaves most of
        .text unreachable, because the functions that reach a given region are
        themselves only reachable from elsewhere.
        """
        done: set[int] = set()
        for rnd in range(1, max_rounds + 1):
            todo = [a for a in self.func_starts if a not in done]
            if not todo:
                break
            before_n, before_c = len(done), len(self._covered)
            for a in todo:
                self.walk(a)
                done.add(a)
            if verbose and (rnd <= 3 or len(done) - before_n < 40):
                print(f"  round {rnd:3d}: +{len(done)-before_n:5d} functions, "
                      f"+{len(self._covered)-before_c:6d} bytes, "
                      f"coverage {self.coverage():.1f}%", file=sys.stderr)
            if len(done) == before_n:
                break
        self._done = done

    def coverage(self) -> float:
        return 100.0 * len(self._covered) / max(len(self.code), 1)

    def covered_bytes(self) -> int:
        return len(self._covered)

    def uncovered_ranges(self, limit: int = 12):
        """Contiguous byte ranges of .text never decoded as instructions."""
        out = []
        start = None
        for off in range(len(self.code)):
            if off not in self._covered:
                if start is None:
                    start = off
            else:
                if start is not None:
                    out.append((start, off))
                    start = None
        if start is not None:
            out.append((start, len(self.code)))
        out.sort(key=lambda r: -(r[1] - r[0]))
        return out[:limit]


def classify(insn) -> str:
    mnem = insn.mnemonic
    ops = insn.operands
    mems = [i for i, op in enumerate(ops) if op.type == capstone.x86.X86_OP_MEM]
    if not mems:
        return "?"
    last = mems[-1]
    if mnem in ("cmp", "test", "push"):
        return "read"
    if mnem in ("mov", "movzx", "movsx"):
        return "write" if last == 0 else "read"
    if mnem == "lea":
        return "address-of"
    if mnem.startswith("j") or mnem in ("call", "ret", "nop", "int3"):
        return "other"
    return "read-modify-write"


def find_refs(b: Binary, wanted: set[int]):
    hits = collections.defaultdict(list)
    for off in b._covered:
        insn = b._insn_at.get(b.tlo + off)
        if insn is None:
            continue
        for op in insn.operands:
            if op.type != capstone.x86.X86_OP_MEM:
                continue
            disp = op.mem.disp & 0xFFFFFFFF
            if disp in wanted:
                hits[disp].append((insn.address, insn, classify(insn)))
    return hits


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("offsets", nargs="*", help="field offsets, e.g. 0x390")
    ap.add_argument("--binary", type=pathlib.Path, default=None)
    ap.add_argument("--context", type=int, default=0,
                    help="print N instructions before each hit")
    ap.add_argument("--show-all", action="store_true")
    ap.add_argument("--coverage-only", action="store_true")
    ap.add_argument("--max-hits", type=int, default=10)
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    binary = args.binary
    if binary is None:
        binary = next((p for p in DEFAULT_BINARIES if p.exists()), None)
    if binary is None or not binary.exists():
        sys.exit("no binary found; pass --binary")

    print(f"{binary.name}: building code map by recursive descent ...",
          file=sys.stderr)
    b = Binary(binary)
    b.build(verbose=args.verbose)

    print(f"  functions found : {len(b.func_starts):6d}   "
          f"(seeds: {dict(b.seed_provenance)})")
    print(f"  .text           : 0x{b.tlo:08x}-0x{b.thi:08x}  {len(b.code):,} bytes")
    print(f"  covered bytes   : {b.covered_bytes():,}  ({b.coverage():.1f}%)")
    print(f"  instructions    : {sum(1 for i in b._insn_at.values() if i):,}")

    gaps = b.uncovered_ranges()
    if gaps:
        total = sum(e - s for s, e in b.uncovered_ranges(limit=10**9))
        print(f"  uncovered       : {total:,} bytes in {len(b.uncovered_ranges(limit=10**9)):,} ranges")
        for s, e in gaps[:5]:
            print(f"      0x{b.tlo+s:08x}-0x{b.tlo+e:08x}  {e-s:,} bytes")
    print()

    if args.coverage_only or not args.offsets:
        return 0

    wanted = {int(o, 0) for o in args.offsets}
    hits = find_refs(b, wanted)
    for off in sorted(wanted):
        found = hits.get(off, [])
        if not found:
            print(f"+0x{off:03x}: NO REFERENCES in covered code")
            continue
        kinds = collections.Counter(k for _, _, k in found)
        summary = ", ".join(f"{n} {k}" for k, n in sorted(kinds.items()))
        reads = [h for h in found if h[2] == "read"]
        writes = [h for h in found if h[2] == "write"]
        print(f"+0x{off:03x}: {len(found)} reference(s) [{summary}]  "
              f"reads={len(reads)} writes={len(writes)}")
        if not reads and writes:
            print("          => no consumer: written but never read")
        limit = len(found) if (args.show_all and not args.context) else args.max_hits
        for addr, insn, kind in found[:limit]:
            print(f"          0x{addr:08x}  {kind:19s} {insn.mnemonic} {insn.op_str}")
            if args.context:
                lo = max(b.tlo, addr - 0x40)
                off = lo - b.tlo
                for near in b.md.disasm(b.code[off:off + 0x40], lo):
                    if near.address >= addr:
                        break
                    print(f"                     | {near.mnemonic} {near.op_str}")
        if len(found) > limit:
            print(f"          ... {len(found)-limit} more")
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())