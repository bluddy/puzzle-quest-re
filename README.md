# Puzzle Quest: Challenge of the Warlords - Reverse Engineering & OCaml Reimplementation

This repository contains the reverse-engineering analysis, reverse-engineered file format parsers, documentation, and a clean-room reimplementation of *Puzzle Quest: Challenge of the Warlords* (PC 2007) in **OCaml**.

The reimplementation targets cross-platform desktop (via SDL2 / `tsdl`) and eventual compilation to mobile (Android).

---

## Current Status & Milestones

- [x] **DRM Decryption**: Unpacked SteamStub Variant 2.0 (x86), restoring `.text` section and original entry point (OEP: `0x504520`).
- [x] **Lua 5.1 Native Bridge Extraction**: All 191 engine functions exposed to Lua cataloged and mapped with addresses and categories.
- [x] **Automated Decompilation**: Headless Ghidra pipeline decompiling engine subsystems into `docs/decompiled/`.
- [x] **Option A: Save File Tool (`.pqhero`)**:
  - Reverse-engineered WET engine 3-layer involution crypto (Transposition, Substitution, XOR) and CRC16-ARC.
  - Discovered original 2007 engine bug: wide-string literal truncation resulted in effective key `b"j"`.
  - Implemented parser and CLI tool in OCaml ([lib/save_file.ml](lib/save_file.ml), [lib/crypto.ml](lib/crypto.ml), [bin/pq_save_tool.ml](bin/pq_save_tool.ml)) for hero stats, progression, spells, and portrait PNG extraction.
- [x] **Option B: Match-3 Simulation Engine**:
  - Implemented pure functional match-3 simulation in OCaml ([lib/board.ml](lib/board.ml)).
  - Features: 3/4/5-of-a-kind, extra turns, wildcards with multipliers, skull damage, gravity, multi-step cascade resolution, and Mana Burn (reshuffle when no legal moves remain).
  - Comprehensive unit test suite ([test/test_board.ml](test/test_board.ml)).

---

## Project Structure

* `lib/`: Core OCaml library modules (`puzzle_quest_lib`):
  * `board.ml`: Pure functional 8x8 match-3 simulation engine, swap validation, cascades, and gravity.
  * `crypto.ml`: WETSTD32 cipher algorithms (CRC-16, Transposition, Substitution, XOR).
  * `save_file.ml`: `.pqhero` binary deserializer, PNG thumbnail slicer, and hero state parser.
* `bin/`: CLI utilities:
  * `pq_save_tool.ml`: Save file inspector, PNG extractor, and interactive board simulator.
* `test/`: Automated test suites (`test_board.ml`).
* `docs/`: Comprehensive reverse-engineering documentation:
  * [`REVERSE_ENGINEERING_PLAN.md`](docs/REVERSE_ENGINEERING_PLAN.md): Strategic roadmap and completed milestones.
  * [`GAME_KNOWLEDGE_BASE.md`](docs/GAME_KNOWLEDGE_BASE.md): Mechanics, formulas, attributes, and combat rules.
  * [`SAVE_FILE_FORMAT.md`](docs/SAVE_FILE_FORMAT.md): Detailed `.pqhero` format and crypto specification.
  * [`LUA_API.md`](docs/LUA_API.md): Catalog of 191 native C functions registered to Lua.
  * [`DATA_STRUCTURES.md`](docs/DATA_STRUCTURES.md): Engine memory layouts and structures.
* `tools/`: Python and Ghidra scripts for DRM unpacking, decompilation, and symbol extraction.
* `game/`: Original game binaries and assets (not tracked in git).

---

## Building & Running

### Requirements
* OCaml 5.x with Opam
* Dune 3.x
* Required opam packages: `tsdl`, `tsdl-mixer`, `tgls`, `imagelib`, `containers`

### Build
```powershell
dune build --display=quiet
```

### Run Tests
```powershell
dune runtest --display=quiet
```

### Inspect a Save File
```powershell
dune exec bin/pq_save_tool.exe -- info "<path_to_save>.pqhero"
```

### Simulate Match-3 Board Battles
```powershell
dune exec bin/pq_save_tool.exe -- board-sim
```
