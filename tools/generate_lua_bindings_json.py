#!/usr/bin/env python3
"""
Generates a JSON map of all 191 Lua bridge functions with their name, native VA, and string VA.
This JSON will be read directly by Ghidra's decompiler script so it does not rely on instruction-pattern scanning in Java.
"""

import json
import pefile
import capstone

def main():
    pe = pefile.PE("game/Puzzle Quest.unpacked.exe")
    image_base = pe.OPTIONAL_HEADER.ImageBase
    cs = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)

    start_va = 0x497600
    end_va = 0x499f00
    code = pe.__data__[start_va - image_base : end_va - image_base]

    instructions = list(cs.disasm(code, start_va))

    bindings = []
    for i, inst in enumerate(instructions):
        if inst.mnemonic == "call" and "4f7160" in inst.op_str:
            pushes = []
            for j in range(i - 1, max(0, i - 8), -1):
                if instructions[j].mnemonic == "push":
                    pushes.append(instructions[j].op_str)

            func_va = None
            if len(pushes) >= 2 and pushes[1].startswith("0x"):
                func_va = int(pushes[1], 16)

            string_val = None
            for j in range(i - 1, max(0, i - 16), -1):
                if instructions[j].mnemonic == "call" and "4f7090" in instructions[j].op_str:
                    for k in range(j - 1, max(0, j - 4), -1):
                        p = instructions[k]
                        if p.mnemonic == "push" and p.op_str.startswith("0x52"):
                            s_va = int(p.op_str, 16)
                            s = pe.__data__[s_va - image_base : s_va - image_base + 120].split(b"\x00")[0].decode("ascii", errors="ignore")
                            string_val = s
                            break
                    break
            if string_val and func_va:
                bindings.append({
                    "name": string_val,
                    "va": hex(func_va)
                })

    out_file = "tools/lua_bindings.json"
    with open(out_file, "w") as f:
        json.dump(bindings, f, indent=2)

    print(f"Wrote {len(bindings)} bindings to {out_file}")

if __name__ == "__main__":
    main()
