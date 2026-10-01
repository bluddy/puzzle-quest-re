# Puzzle Quest: Challenge of the Warlords - Reverse Engineering & Reimplementation Plan

## 1. Project Goal
Reverse engineer the original 2007 Windows PC release of *Puzzle Quest: Challenge of the Warlords* (`Puzzle Quest.exe`) to produce:
1. Complete architectural and algorithmic documentation of the game engine (Infinite Interactive WET Engine).
2. Documented Lua 5.1 native bridge (all ~163 C exported functions, signatures, calling conventions, engine pointers).
3. Complete data structure layouts (Character, Board, Gem, Spell, Quest, Inventory, AI).
4. A clean, modern C++ (C++20) recreation capable of running the original game data (`Assets.zip`) with 100% mechanic and logic parity.

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
* **Grid State**: $8 \times 8$ tile matrix, gem types (0–7: Red/Fire, Yellow/Air, Blue/Water, Green/Earth, Skull, +5 Skull, Gold, Mana Surge/Wildcard multipliers 2x–8x).
* **Move Rules**: Gem swap validation (horizontal/vertical adjacent swap only valid if creating a match-3+).
* **Match Resolution**:
  * Matching clusters (horizontal, vertical, L-shapes, T-shapes).
  * 4-of-a-kind (grants Extra Turn + mana/damage).
  * 5-of-a-kind (creates Wildcard gem + Extra Turn).
  * Cascades & Gravity: Tile drop calculations, filling top row with pseudo-random or fixed gems.
  * Cascades mana/damage accumulation and multiplier chaining.
* **AI Evaluation**: Reverse-engineer `EVALUATE_BOARD` to uncover the AI's heuristic scoring matrix for board moves based on enemy archetype, difficulty, and available mana.

#### B. RPG Mechanics, Stats & Combat Flow
* **Combatants**: Hero vs Enemy (Health, Mana reserves, Max mana caps, Masteries, Morale, Battle, Cunning).
* **Turn Sequence**: Turn initiative, status effect tick (Poison, Disease, Burn, Web, Silence, Stun), Action phase (Spell cast or Gem swap), Post-move cascade resolution, Extra-turn determination, Turn handoff.
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

### Phase 5: Modern C++ Reimplementation
* Stand up clean C++20 engine:
  * Platform layer: SDL2 / SDL3 (cross-platform windowing, input, audio, timing).
  * Embedded Lua 5.1/LuaJIT runtime.
  * Direct loading of original game assets (`Assets.zip`).
* Rebuild and verify:
  1. `BoardSimulator` and deterministic test suite.
  2. `CombatEngine` with Lua integration.
  3. `WorldMapEngine` with city graphs and quest state.
  4. Complete UI / Game Loop.
