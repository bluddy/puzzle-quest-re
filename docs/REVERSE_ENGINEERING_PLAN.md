# Puzzle Quest: Challenge of the Warlords - Reverse Engineering & Reimplementation Plan

## 1. Project Goal
Reverse engineer the original 2007 Windows PC release of *Puzzle Quest: Challenge of the Warlords* (`Puzzle Quest.exe`) to produce:
1. Complete architectural and algorithmic documentation of the game engine (Infinite Interactive WET Engine).
2. Documented Lua 5.1 native bridge (all ~163 C exported functions, signatures, calling conventions, engine pointers).
3. Complete data structure layouts (Character, Board, Gem, Spell, Quest, Inventory, AI).
4. A clean, modern OCaml recreation. Parity with the original's *mechanics* is
   the target; parity with the original's *content pipeline* was deliberately
   abandoned when the Lua layer was dropped — see the decision in Phase 5.

---

## 2. Technical Findings Summary (Target Binary)
* **Binary**: `game/Puzzle Quest.exe` (x86 32-bit PE, ~2.7 MB).
* **Original Build Information**:
  * PDB Path: `d:\WarlordsChampions\Project\WarlordsChampions\Game\Final Release (Unicode)\Game.pdb`
  * Compiler: Microsoft Visual Studio .NET 2003 (MSVC 7.1, `msvcr71.dll`, `msvcp71.dll`).
  * Target Platform: Windows x86, Unicode character set (`wchar_t`).
* **Original Engine**: Infinite Interactive **WET Engine** (*Warlords Engine Technology*).
* **Auxiliary DLLs**:
  * `wetstd32.dll`: Engine helper utilities (block substitution/transposition/XOR encryption, CRC32, Base64/ASCII conversion).
  * `FreeSL.dll` / `wrap_oal.dll` / `alut.dll`: OpenAL-based 3D sound system.
  * Direct3D 9 (`d3d9.dll`, `d3dx9_28.dll`), DirectInput 8 (`dinput8.dll`), DirectDraw (`ddraw.dll`).
  * Winsock 2 (`ws2_32.dll`) for multiplayer.
* **Embedded Scripting**:
  * Embedded **Lua 5.1** interpreter statically compiled into the executable.
  * 163 C functions exported to Lua scripts (`EVALUATE_BOARD`, `DESTROY_GEM`, `ADD_LIFE`, `GET_SKILL`, etc.).
  * High-level game content, quest dialogues, item triggers, and spell logic defined in `Assets.zip` (`.xml` + `.lua`).

---

## 3. Phased Execution Roadmap

### Phase 1: Tooling, Infrastructure & Automation
- [x] Git repository initialization and `.gitignore` setup.
- [x] Python virtual environment (`venv`) with binary inspection tools (`pefile`, `capstone`).
- [x] SteamStub DRM unpacking (`game/Puzzle Quest.unpacked.exe`).
- [x] Ghidra project setup (headless analysis & symbol export).
- [x] Automated Ghidra / Python analysis pipeline for extracting cross-references, decompiler output, and symbol maps.
- [x] Living documentation suite:
  - `docs/REVERSE_ENGINEERING_PLAN.md`: Strategic roadmap and progress tracker.
  - `docs/GAME_KNOWLEDGE_BASE.md`: High-level game mechanics, rules, and hypotheses.
  - `docs/LUA_API.md`: Detailed catalog of all 191 Lua-exported C functions and their signatures.
  - `docs/DATA_STRUCTURES.md`: Engine structs, memory layouts, offsets, and class hierarchies.
  - `docs/SAVE_FILE_FORMAT.md`: Complete `.pqhero` encryption and binary schema specification.

### Phase 2: The Lua Native Bridge (Gateway into Core Engine)
- [x] Located `lua_State*` creation and registration loop at `0x004976FE`–`0x00499E89`.
- [x] Extracted all 191 exported function pointers and their internal native dispatchers into `tools/lua_bindings.json`.
- [x] Batch-decompiled 345 C/Lua native functions into `docs/decompiled/`.

### Phase 3: Core Game Logic Reverse Engineering
#### A. Board & Match-3 Simulation Engine
* [x] **Grid State**: $8 \times 8$ tile matrix, gem types 0–7 plus 0x0F and 0x10–0x11 (red skull and two unidentified specials), wildcards 8–14 (×2–×8).
* [x] **Move Rules**: Adjacent horizontal/vertical swap, valid only if it creates a run of 3+.
* [x] **Match Resolution**:
  * Matching clusters along both axes.
  * 4-of-a-kind (Extra Turn + mana/damage), 5-of-a-kind (Wildcard + Extra Turn).
  * Cascades & Gravity: tile drop, top-row refill, per-cascade accumulation.
  * Wildcard multiplier *chaining* (a 2x and a 3x in one run scale it by 6).
* [x] **AI Evaluation**: `EVALUATE_BOARD` fully recovered. See [`BATTLE_AI.md`](BATTLE_AI.md).
  * Weighted sum over ten resource buckets, plus `3 × run_length`, plus the anchor column, plus 30 per bonus tier.
  * Default weights: mana 2 each, skull 10, red skull 20, gold/xp 1, specials 20.
  * Two jitter terms: difficulty-driven (±50 always at easy, ±20 on 40% at normal, none at hard) and hero-level-driven, the latter widening as the hero nears its level cap.
  * Move enumeration uses four hardcoded probe windows in `.rdata` that miss ~4.8% of scoring moves. Reproduced verbatim rather than corrected.

#### B. RPG Mechanics, Stats & Combat Flow
* [x] **Combatants**: Hero vs Enemy. Health at `+0x64`/`+0x70`, level at `+0x68`, four mana pools at `+0x74`, cunning at skill slot 5. Modelled in `lib/combat.ml`.
* [x] **Turn Sequence**: Turn order is a rotation of the roster seeded by the highest Cunning, so the scan only picks who leads. Banked extra turns replay the matcher. Ported in `lib/combat.ml`; see [`COMBAT_FLOW.md`](COMBAT_FLOW.md).
* [x] **Status Effects**: Data read from `Assets/StatusEffects/*.xml`; expiry is a decrement-and-test with no separate removal path. Effect behaviour is a Lua table of named callbacks in the original.
* [x] **The scripting surface**: 37 named hooks at `0x005239E8`. See below.
* [x] **Spell resolution**: `HANDLE_SPELL_COST` and `IS_SPELL_CASTABLE` recovered. Castability is a per-pool comparison; the air check is gated on the "spells disallowed this turn" flag. See [`SPELLS.md`](SPELLS.md).
* [x] **Mana yield**: `(skill + 100) * run_multiplier * 0.01`, skill capped at 999, multipliers 1/2/3 for 3/4/5-of-a-kind.
* [x] **Stat-based extra turn**: chance is `gained / 100`, rolled per element per match at `0x0047D4F0`. Identified from a playtesting observation and confirmed in the binary.
* [ ] **Spell effect bodies**: the 130 `.lua` effect scripts. Must be rewritten in OCaml; the XML gives ids, costs and cooldowns but not effects.
* [x] **The AI's spell ranking**: `Spell.pick_ranked_spell`, behind the global `Spell.spell_policy` (default `Faithful`). Five weighted descriptor terms — potency, economy, rationing, affinity, headroom. Scored on `learn_score`, cost, cooldown, and the caster's skills, **not** on effect strength, which is unavailable until the effect bodies land. See `docs/SPELLS.md` §5.
* **Mini-game Variations**:
  * Spell Research (clear board using exact sequence).
  * Mount Training (clear specific targets within turn/time limit).
  * Item Forging / Citadel (crafting with runes).
  * City Sieges / Captures.

### Phase 4: Subsystems & Asset Architecture
* **Virtual File System**: Transparent loading from `Assets.zip` or uncompressed directory overrides.
* **XML Data Pipeline**: Parsing hero classes, enemy archetypes, city nodes, road connectivity graph, item tables, and quest trees.
* **UI Screen System**: XML-driven layout schema in `Assets/Screens/*.xml`, button callbacks, event routing, font rendering.
* **Audio & Music**: SFX and ambient playback routing.
* **Save Game Format**: Reverse engineering the profile / hero save format (saved in `%APPDATA%` or Windows registry / user documents).

### Phase 5: Modern OCaml Reimplementation
* Stand up clean OCaml engine (Dune, `puzzle_quest_lib`):
  * Platform layer: SDL2 via `tsdl` (cross-platform windowing, input, audio, timing).
  * **No Lua runtime.** See the decision below.
  * Original `Assets.zip` XML data parsed directly; the `.lua` content files are
    replaced by OCaml implementations.
* Rebuild and verify:
  1. `BoardSimulator` and deterministic test suite. — **done**, `lib/board.ml`
  2. `CombatEngine` with turn order, extra turns, and status effects. — **done**, `lib/combat.ml`
  3. A headless battle loop tying board, AI, combat, and spells together. — **done**, `lib/battle.ml`
  4. `WorldMapEngine` with city graphs and quest state.
  5. Spell effect table — the 130 scripts, rewritten in OCaml.
  6. A ranked AI spell chooser, replacing the original's first-affordable-wins.

**One known modelling gap.** The original's extra turn roll reads a character's
*skill* in an element, which is a separate field from its current mana balance.
`Combat.skills` now models it properly, and the save file's four skill values feed
it.

**Mana Burn regenerates, it does not permute.** `FUN_0047ADB0` clears the whole
9x8 grid before the refill (`docs/decompiled/mana_burn/Sub_47adb0.c`). An earlier
version called `refill_board`, which only fills `Empty` cells; a regenerated board
has none, so a burn on a full board changed nothing and the AI burned on every
turn for the whole cap. `Board.reshuffle` clears and refills, retrying until
`Board.has_valid_move` says the board is playable.

---

## Decision: no Lua layer

**Decided.** The engine will not embed a Lua runtime, and content will be
authored in OCaml rather than loaded from the original `.lua` files.

The reason is not preference. The original's entire scripting surface is **37
named callbacks** in a contiguous table at `0x005239E8`, each dispatched by name
out of a Lua table. The VM does not evaluate expressions or hold game state; it
is a late-bound function table with named entry points. In OCaml that is a
record of optional function fields, and the 191 native bindings become ordinary
functions the hooks call directly. There is no FFI boundary and no host-language
crossing to pay for.

It also removes the constraint that motivated this work. In the original, an AI
cannot read its own inventory or spells because that state lives in a scripting
VM the C++ side cannot see. With everything in one language, an informed AI is
the default rather than a retrofit.

**What is given up.** The original's *content* is authored in Lua: 260 spell
scripts, 17 status effects, quest logic, dialogue. `Assets.zip` holds 4,401
entries; the XMLs remain parseable and give us ids, costs, durations, stacks and
icons, but the `.lua` halves are replaced by hand-written OCaml. The ~20 status
effect behaviours and the spell effect table are a bounded amount of work, and
most of it is work the AI project needs regardless.

**What this retires.** The original goal of "100% mechanic and logic parity with
the original game data" in §1. Parity with the original *mechanics* is retained
and is what the tests assert. Parity with the original *content pipeline* is
deliberately abandoned. `LUA_API.md` remains valuable regardless: it is a
complete inventory of what the engine can do, and the best available
specification for the functions we reimplement.

**Reversible.** The hook record is a drop-in seam. If a Lua interpreter is ever
wanted, `Combat.hooks` is exactly the surface it would need to bind, and
`LUA_API.md` is the binding table.
  4. Complete UI / Game Loop.
