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
- [x] **Option F: Spells and Mana** ([docs/SPELLS.md](docs/SPELLS.md)):
  - Parsed all 129 battle spell descriptors from `Assets/Spells/*.xml`: costs, cooldowns, learn requirements, input types. Regenerable with `tools/extract_spell_data.ps1`.
  - Recovered mana yield — `(skill + 100) * run_multiplier * 0.01`, skill capped at 999.
  - **The stat-based extra turn**: chance is `gained / 100`, rolled per element per match, which is why extra turns become common late game. Found by playtesting observation and confirmed at `0x0047D4F0`.
  - **Casting usually ends the turn**, so the caster does not also swap. The rule is stated per spell in each spell's DETL line; 97 of 129 end it, 13 keep it, 10 end it after an effect, and 9 are conditional on the caster's mana.
  - **The AI's spell choice is per-spell, not first-affordable.** All 130 spells define their own `ShouldAICastSpell`: 107 call `Std_AISpellcastingChance` (a Lua function in `Assets/Scripts/`), 37 count gems on the board, 20 read `EVALUATE_BOARD`, 12 read `GET_ITEM`. 77 hooks ported — 49 generated, 28 hand-written.
  - Ported to OCaml in [lib/spell.ml](lib/spell.ml) with tests in [test/test_spell.ml](test/test_spell.ml).
- [x] **Option G: Headless Battle Loop** ([lib/battle.ml](lib/battle.ml)):
  - A complete, seeded, animation-free battle: both sides take turns, the AI picks moves, matches cascade, damage lands, deaths end the fight, and a turn cap forces a stalemate.
  - Bridges the row-index mismatch: `Board` uses rows `0..7`, the engine uses row 0 as a spawn buffer with rows `1..8` playable. `ai_view` presents the engine's 9-row grid and `play_move` undoes the same shift, otherwise every swap lands one row low.
  - Casting a spell no longer banks an extra turn; in the original that comes from a status effect hook, not from casting.
  - Cooldowns from the `Data cooldown` attribute are enforced, per combatant rather than per spell record.
  - Both damage-hook chains run: the attacker's `GIVE_DAMAGE`, then the defender's `RECEIVE_DAMAGE`.
  - Matching, Red Skull explosions, 5-run wildcards, gold, and XP all come from `Board.resolve_matches`; the board reports its own run groupings so there is one matcher rather than two.
  - Skills are modelled per element and drive mana yield, rather than being read off the mana balance.
  - Tests in [test/test_battle.ml](test/test_battle.ml) cover the coordinate bridge, determinism, size-based and stat-based extra turns, mana burn, cooldowns, the turn-ending rule, damage hooks, gold/XP/Heroic Effort, death, and the stalemate cap.

Enhancement ideas are kept out of the port and tracked in
[`ENHANCEMENTS.md`](docs/ENHANCEMENTS.md), including the ranked AI spell
chooser, which is implemented but off by default.

---

## Project Structure

* `lib/`: Core OCaml library modules (`puzzle_quest_lib`):
  * `board.ml`: Pure functional 8x8 match-3 simulation engine, swap validation, cascades, and gravity.
  * `ai.ml`: Enemy move selection — probe windows, match scoring, difficulty and hero-level jitter.
  * `combat.ml`: Turn order, banked extra turns, status effect lifetimes, and the 37-hook record.
  * `spell.ml`: Spell costs, mana yield, the stat-based extra turn roll, the turn-ending rule, and the AI's spell pick.
  * `spell_data.ml`: The 129 spell descriptors parsed from the game's assets. Generated.
  * `spell_ai.ml`: Per-spell `ShouldAICastSpell` hooks. Generated.
  * `spell_ai_manual.ml`: Hand-ported hooks that read the board.
  * `score.ml`: End-of-battle score, both solo and co-op paths.
  * `battle.ml`: Headless battle loop wiring board, AI, combat, and spells together.
  * `crypto.ml`: WETSTD32 cipher algorithms (CRC-16, Transposition, Substitution, XOR).
  * `save_file.ml`: `.pqhero` binary deserializer, PNG thumbnail slicer, and hero state parser.
* `bin/`: CLI utilities:
  * `pq_save_tool.ml`: Save file inspector, PNG extractor, and interactive board simulator.
  * `pq_battle.ml`: Plays a seeded headless battle and prints the trace or a summary.
* `test/`: Automated test suites (`test_board.ml`, `test_ai.ml`, `test_score.ml`, `test_combat.ml`, `test_spell.ml`, `test_battle.ml`).
* `docs/`: Comprehensive reverse-engineering documentation:
  * [`REVERSE_ENGINEERING_PLAN.md`](docs/REVERSE_ENGINEERING_PLAN.md): Strategic roadmap and completed milestones.
  * [`GAME_KNOWLEDGE_BASE.md`](docs/GAME_KNOWLEDGE_BASE.md): Mechanics, formulas, attributes, and combat rules.
  * [`BATTLE_AI.md`](docs/BATTLE_AI.md): Enemy AI move selection, scoring weights, and probe windows.
  * [`BATTLE_SCORE.md`](docs/BATTLE_SCORE.md): End-of-battle score formula, solo and co-op.
  * [`COMBAT_FLOW.md`](docs/COMBAT_FLOW.md): Turn order, extra turns, status effects, and the hook table.
  * [`SPELLS.md`](docs/SPELLS.md): Spell costs, mana yield, and the stat-based extra turn.
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

### Play a Headless Battle
```powershell
dune exec bin/pq_battle.exe -- --seed 7 --hero-skill 200
dune exec bin/pq_battle.exe -- --seed 7 --trace --board
```
The same seed always produces the same fight, so a trace is reproducible.

### Watch the AI Decide Spells
```powershell
dune exec bin/pq_battle.exe -- --seed 5 --turns 120 --spells 4 --difficulty 2 --foe-skill 400 --trace
```
`--spells N` hands the foe N real spells from the game's own table. Each one
carries its ported `ShouldAICastSpell`, which reads the board, so `--trace` shows
the enemy weighing a gem count or a board evaluation before it commits. Give the
foe skill (`--foe-skill`), or it earns too little mana to afford anything but the
cheapest spell.
