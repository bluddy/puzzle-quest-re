# Puzzle Quest: Challenge of the Warlords - Reverse Engineering & OCaml Reimplementation

This repository contains the reverse-engineering analysis, reverse-engineered file format parsers, documentation, and a clean-room reimplementation of *Puzzle Quest: Challenge of the Warlords* (PC 2007) in **OCaml**.

The reimplementation targets cross-platform desktop (via SDL2 / `tsdl`) and eventual compilation to mobile (Android).

**No Lua layer.** The engine embeds no Lua runtime; content is authored in
OCaml. The original's entire scripting surface is 37 named callbacks in a table
at `0x005239E8`, which ports directly to a record of optional functions. This
also removes the constraint that the enemy AI cannot read its own inventory or
spells, because that state lives in a VM the C++ side cannot see. See
[`COMBAT_FLOW.md`](docs/COMBAT_FLOW.md) §4 and the decision in
[`REVERSE_ENGINEERING_PLAN.md`](docs/REVERSE_ENGINEERING_PLAN.md).

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
- [x] **Option C: Enemy Battle AI** ([docs/BATTLE_AI.md](docs/BATTLE_AI.md)):
  - Fully recovered `CBattleManager::EvaluateBoard` (0x00440C20) and `BattleAI_ScoreMatchResult` (0x0043F970), plus the gem-compatibility predicate, the run-measuring routine, and the default scoring weights.
  - Ported to OCaml in [lib/ai.ml](lib/ai.ml) with tests in [test/test_ai.ml](test/test_ai.ml).
  - Notable findings: the AI's ten resource weights, its two independent jitter terms (difficulty and hero level), and four hardcoded probe windows that miss ~4.8% of scoring moves — reproduced verbatim.
- [x] **Option D: End-of-Battle Score** ([docs/BATTLE_SCORE.md](docs/BATTLE_SCORE.md)):
  - Recovered both the solo and co-op formulas, the difficulty scaling, and the 50,000 clamp.
  - Ported to OCaml in [lib/score.ml](lib/score.ml) with tests in [test/test_score.ml](test/test_score.ml).
- [x] **Option E: Combat Flow** ([docs/COMBAT_FLOW.md](docs/COMBAT_FLOW.md)):
  - Turn order is a rotation of the roster seeded by the highest Cunning, so the scan picks only who leads.
  - Banked extra turns replay the matcher's slot; recovered the drain loop's re-read-after-advance behaviour.
  - Status effect expiry is a decrement-and-test, and the per-effect stack limit.
  - Ported to OCaml in [lib/combat.ml](lib/combat.ml) with tests in [test/test_combat.ml](test/test_combat.ml).
  - Recovered the 37-hook scripting table, which is the basis for dropping Lua.

---

## Project Structure

* `lib/`: Core OCaml library modules (`puzzle_quest_lib`):
  * `board.ml`: Pure functional 8x8 match-3 simulation engine, swap validation, cascades, and gravity.
  * `ai.ml`: Enemy move selection — probe windows, match scoring, difficulty and hero-level jitter.
  * `combat.ml`: Turn order, banked extra turns, status effect lifetimes, and the 37-hook record.
  * `score.ml`: End-of-battle score, both solo and co-op paths.
  * `crypto.ml`: WETSTD32 cipher algorithms (CRC-16, Transposition, Substitution, XOR).
  * `save_file.ml`: `.pqhero` binary deserializer, PNG thumbnail slicer, and hero state parser.
* `bin/`: CLI utilities:
  * `pq_save_tool.ml`: Save file inspector, PNG extractor, and interactive board simulator.
* `test/`: Automated test suites (`test_board.ml`, `test_ai.ml`, `test_score.ml`, `test_combat.ml`).
* `docs/`: Comprehensive reverse-engineering documentation:
  * [`REVERSE_ENGINEERING_PLAN.md`](docs/REVERSE_ENGINEERING_PLAN.md): Strategic roadmap and completed milestones.
  * [`GAME_KNOWLEDGE_BASE.md`](docs/GAME_KNOWLEDGE_BASE.md): Mechanics, formulas, attributes, and combat rules.
  * [`BATTLE_AI.md`](docs/BATTLE_AI.md): Enemy AI move selection, scoring weights, and probe windows.
  * [`BATTLE_SCORE.md`](docs/BATTLE_SCORE.md): End-of-battle score formula, solo and co-op.
  * [`COMBAT_FLOW.md`](docs/COMBAT_FLOW.md): Turn order, extra turns, status effects, and the hook table.
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
