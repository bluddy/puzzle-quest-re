#!/usr/bin/env python3
"""
Exports a complete catalog of the 187 Lua C-API bindings from the unpacked Puzzle Quest binary.
Produces docs/LUA_API.md with addresses, parameter patterns, and engine hooks.
"""

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
            # Look backwards for function pointer push
            func_va = None
            for j in range(i - 1, max(0, i - 6), -1):
                prev = instructions[j]
                if prev.mnemonic == "push" and prev.op_str.startswith("0x4"):
                    func_va = int(prev.op_str, 16)
                    break

            # Look backwards for string push
            string_val = None
            string_va = None
            for j in range(i - 1, max(0, i - 16), -1):
                prev = instructions[j]
                if prev.mnemonic == "call" and "4f7090" in prev.op_str:
                    for k in range(j - 1, max(0, j - 4), -1):
                        p = instructions[k]
                        if p.mnemonic == "push" and p.op_str.startswith("0x52"):
                            string_va = int(p.op_str, 16)
                            s = pe.__data__[string_va - image_base : string_va - image_base + 120].split(b"\x00")[0].decode("ascii", errors="ignore")
                            string_val = s
                            break
                    break
            bindings.append((string_val, string_va, func_va, inst.address))

    # Group by category prefix
    categories = {
        "Board & Match-3": [],
        "Character, Stats & Mana": [],
        "Quests & Story Encounters": [],
        "Tutorial & UI": [],
        "General / System": []
    }

    for name, sva, fva, cva in bindings:
        n = name or "UNKNOWN"
        if any(k in n for k in ["GEM", "GRID", "BOARD", "LIGHTNING"]):
            categories["Board & Match-3"].append((n, sva, fva, cva))
        elif any(k in n for k in ["MANA", "LIFE", "XP", "GOLD", "SKILL", "STATUS", "EFFECT", "CHARACTER", "ENEMY", "ITEM", "RUNE", "COMPANION"]):
            categories["Character, Stats & Mana"].append((n, sva, fva, cva))
        elif n.startswith("QUEST_"):
            categories["Quests & Story Encounters"].append((n, sva, fva, cva))
        elif n.startswith("TUTORIAL_") or any(k in n for k in ["MENU", "GAMEPAD", "BUTTON"]):
            categories["Tutorial & UI"].append((n, sva, fva, cva))
        else:
            categories["General / System"].append((n, sva, fva, cva))

    # Generate Markdown documentation
    lines = []
    lines.append("# Puzzle Quest: Lua 5.1 C-API Native Bridge Reference")
    lines.append("")
    lines.append("This document catalogs all **187 native C functions** exported to the embedded Lua 5.1 environment in `Puzzle Quest.exe`.")
    lines.append("All functions are registered in the global environment (`LUA_GLOBALSINDEX` = `-10002`) inside the initialization function `0x4976FE`–`0x499E89`.")
    lines.append("")
    lines.append("## Global Lua State")
    lines.append("* `g_L` pointer address: `0x00583108`")
    lines.append("* Registration routine: `0x004976F0`")
    lines.append("* `lua_pushstring`: `0x004F7090`")
    lines.append("* `lua_pushcclosure`: `0x004F7160`")
    lines.append("* `lua_settable`: `0x004F7410`")
    lines.append("")

    for cat_name, entries in categories.items():
        lines.append(f"## {cat_name} ({len(entries)} functions)")
        lines.append("")
        lines.append("| Lua Function | Native C Function VA | String VA | Registration Call | Notes |")
        lines.append("| :--- | :--- | :--- | :--- | :--- |")
        for n, sva, fva, cva in sorted(entries, key=lambda x: x[0]):
            fva_str = f"`{hex(fva)}`" if fva else "`N/A`"
            sva_str = f"`{hex(sva)}`" if sva else "`N/A`"
            cva_str = f"`{hex(cva)}`" if cva else "`N/A`"
            lines.append(f"| **`{n}`** | {fva_str} | {sva_str} | {cva_str} | |")
        lines.append("")

    with open("docs/LUA_API.md", "w") as f:
        f.write("\n".join(lines))

    print(f"Generated docs/LUA_API.md with {len(bindings)} functions across {len(categories)} categories.")

if __name__ == "__main__":
    main()
