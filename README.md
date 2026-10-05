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
  - Recovered mana yield - `(skill + 100) * run_multiplier * 0.01`, skill capped at 999.
- **Mana pools have a per-element ceiling.** `GET_MAX_MANA_*` reads `character + 0x84 + element * 4`, and the setter at `0x004839F0` clamps the current pool down to the new maximum, so lowering a ceiling can destroy mana already held. The base value is not recovered; `Combat.default_mana_limit` is a chosen default of 20, per combatant so a fight can set its own.
- **The ceiling has to clear the largest threshold the scripts test.** The scripts compare `GET_MANA_*` against 8, 10, 12, 14, 15 and 20, and all nine conditional turn rules need 8 or more. An earlier default of 10 made every condition at 12 or above permanently false, silently killing the turn rules for `SBAC`, `SBRA`, `SCHL`, `SSOA` and `SSWP`. 20 is the smallest default that leaves nothing unreachable; real characters go higher still, via skills and the "+N to max Fire mana" items, so set an explicit ceiling when testing mana-gated behaviour.
  - **The stat-based extra turn**: chance is `gained / 100`, rolled per element per match, which is why extra turns become common late game. Found by playtesting observation and confirmed at `0x0047D4F0`.
  - **Casting usually ends the turn**, so the caster does not also swap. The rule is stated per spell in each spell's DETL line; 97 of 129 end it, 13 keep it, 10 end it after an effect, and 9 are conditional on the caster's mana.
- **The AI's spell choice is per-spell, not first-affordable.** All 130 spells define their own `ShouldAICastSpell`: 107 call `Std_AISpellcastingChance` (a Lua function in `Assets/Scripts/`), 37 count gems on the board, 20 read `EVALUATE_BOARD`. **All 129 hooks ported** - 53 generated, 76 hand-written. `SCHG` and `SFBA` were the last two and were long recorded as unobtainable; both helpers turned out to be local functions in the spells own `.lua`, which sits in `game/Assets.zip` in this repo.
  - **These hooks return a number, not a boolean.** `Std_AISpellcastingChance` returns 0 or 1 and three hooks return negatives (`SMBU` -50, `SSBL` and `SSTL` -10), so the engine has to be comparing numerically: `> 0` is the only reading consistent with those negatives meaning veto. Separately, the *modifier* those hooks pass works the other way: the percentile roll is 0..99 with low being the lucky end and the spell casts when `percentile <= 50 + modifier`, so a positive modifier makes it cast more often.
  - **Only one hook reads `GET_ITEM`, not twelve.** An earlier count said twelve; that counted calls inside `SDUP.lua` rather than scripts, and `SDUP` is the only spell script that mentions it.
  - Ported to OCaml in [lib/spell.ml](lib/spell.ml), with tests in [test/test_spell.ml](test/test_spell.ml) for the core rules and [test/test_spell_hooks.ml](test/test_spell_hooks.ml) for the 76 hand-written hooks.
- [x] **Option G: Headless Battle Loop** ([lib/battle.ml](lib/battle.ml)):
  - A complete, seeded, animation-free battle: both sides take turns, the AI picks moves, matches cascade, damage lands, deaths end the fight, and a turn cap forces a stalemate.
  - Bridges the row-index mismatch: `Board` uses rows `0..7`, the engine uses row 0 as a spawn buffer with rows `1..8` playable. `ai_view` presents the engine's 9-row grid and `play_move` undoes the same shift, otherwise every swap lands one row low.
  - Casting a spell no longer banks an extra turn; in the original that comes from a status effect hook, not from casting.
  - Cooldowns from the `Data cooldown` attribute are enforced, per combatant rather than per spell record.
  - Both damage-hook chains run: the attacker's `GIVE_DAMAGE`, then the defender's `RECEIVE_DAMAGE`.
  - Matching, Red Skull explosions, 5-run wildcards, gold, and XP all come from `Board.resolve_matches`; the board reports its own run groupings so there is one matcher rather than two.
  - Skills are modelled per element and drive mana yield, rather than being read off the mana balance.
  - Tests in [test/test_battle.ml](test/test_battle.ml) cover the coordinate bridge, determinism, size-based and stat-based extra turns, mana burn, cooldowns, the turn-ending rule, damage hooks, gold/XP/Heroic Effort, death, and the stalemate cap.

- [x] **Option H: Graphics Front End**:
  - SDL2 for the window, input and GL context; `tgls` for OpenGL, which also covers OpenGL ES for Android behind one module.
  - A sprite batcher, an 8x8 board drawn from live battle state, and mouse play through the same two hooks the ASCII runner uses.
  - Real gem sprites, cut from the frames `Assets/Assets.xml` names.
  - Text in the game's own bitmap fonts, and a HUD. See [Graphics](#graphics-sdl2--opengl).
- [x] **Option I: Decoration**:
  - `Assets/Assets.xml` read as data: 44 sheets and 422 named rectangles, with the size each is meant to be drawn at.
  - The window is 1024x768, which is what the backdrop and the border frame are cut for.
  - Backdrop, border, selection glow and turn-counter plates, all addressed by tag.

There is no enhancements file, and that is a deliberate end state rather than an
omission. One used to exist, for a ranked AI spell chooser to replace the
original's first-affordable-wins. Recovering the real per-spell `ShouldAICastSpell`
hooks made it pointless: the port now does what the game does rather than something
ranked, so there is nothing to keep out of the default.

---

## Project Structure

* `lib/`: Core OCaml library modules (`puzzle_quest_lib`):
  * `board.ml`: Pure functional 8x8 match-3 simulation engine, swap validation, cascades, and gravity.
  * `ai.ml`: Enemy move selection — probe windows, match scoring, difficulty and hero-level jitter.
  * `combat.ml`: Turn order, banked extra turns, status effect lifetimes, and the 37-hook record.
  * `item.ml` / `item_data.ml` / `item_hooks.ml`: Items, their descriptors and their `IT_*` hooks.
  * `spell.ml`: Spell costs, mana yield, the stat-based extra turn roll, the turn-ending rule, and the AI's spell pick.
  * `spell_data.ml`: The 129 spell descriptors parsed from the game's assets. Generated.
  * `spell_ai.ml`: Per-spell `ShouldAICastSpell` hooks. Generated.
  * `spell_ai_manual.ml`: Hand-ported hooks that read the board.
  * `spell_effects.ml`: Per-spell `CastSpell` bodies — all 129 of them.
  * `status_effect_data.ml`: Status effect descriptors from the game's XML. Generated.
  * `skin_data.ml`: The bitmap registry - 44 sheets, 422 named rectangles. Generated.
  * `status_effect_hooks.ml`: The 17 status effect scripts, hand-ported.
  * `font_data.ml`: The ten bitmap font glyph tables and the 32 named fonts. Generated.
  * `score.ml`: End-of-battle score, both solo and co-op paths.
  * `battle.ml`: Headless battle loop wiring board, AI, combat, and spells together.
  * `crypto.ml`: WETSTD32 cipher algorithms (CRC-16, Transposition, Substitution, XOR).
  * `save_file.ml`: `.pqhero` binary deserializer, PNG thumbnail slicer, and hero state parser.
* `gfx/`: The presentation layer (`pq_gfx`), split so the arithmetic is testable without a window:
  * `layout.ml`: Board geometry and gem colours. Pure.
  * `input.ml`: What a click means, given which prompt is open. Pure.
  * `font_layout.ml`: Glyph advances, measuring, wrapping, and float-message placement. Pure.
  * `gl.ml`: The only file naming `Tgl3`/`Tgles3`; the window, the context and the sprite batcher.
  * `png.ml`: PNG and JPEG to an RGBA bigarray, shared by the sheets and the font atlases.
  * `assets.ml`: The gem sheet's frames, looked up in the registry rather than hardcoded.
  * `font.ml`: A font atlas to one texture, and one batched run per line of text.
  * `skin.ml`: The backdrop, the border and the other decorations, addressed by registry tag.
* `bin/`: CLI utilities:
  * `pq_save_tool.ml`: Save file inspector, PNG extractor, and interactive board simulator.
  * `pq_battle.ml`: Plays a seeded headless battle and prints the trace or a summary.
  * `pq_play_gfx.ml`: The same battle in a window, with a mouse and a HUD.
* `pq_play.ml`: The same battle with you on the hero's turns.
* `test/`: Automated test suites (`test_board.ml`, `test_ai.ml`, `test_score.ml`, `test_combat.ml`, `test_spell.ml`, `test_battle.ml`, `test_font_data.ml`, `test_skin_data.ml`, `test_gfx_font_layout.ml`).
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
  * [`reverse/`](docs/reverse/README.md): **Evidence database** — every claim the port rests on, with its source, its confidence, and what would refute it. Run `python tools/validate_evidence.py --report`.
* `tools/`: Python and Ghidra scripts for DRM unpacking, decompilation, symbol extraction, and evidence validation.
* `game/`: Original game binaries and assets (not tracked in git).

---

## Building & Running

### Requirements
* OCaml 5.x with Opam
* Dune 3.x
* Required opam packages: `tsdl`, `tsdl-mixer`, `tgls`, `imagelib`, `containers`
* **`imagelib` must be the `jpeg-codec` fork.** The opam release cannot read the
  game's backdrop, which is a JPEG, and there is no PNG of it — the only copy is
  `Assets/Skin/Skin_Backdrop_Standard.jpg`. Pin it with:

```sh
opam pin add imagelib https://github.com/bluddy/ocaml-imagelib.git#jpeg-codec
opam install imagelib
```

Pinned at `00243ab8`. The fork is what wires JPEG into `ImageLib.openfile`; the
release raises `Not_yet_implemented "jpg"`. `gfx/png.ml` copes with both builds'
differing extension spellings, but only the fork can decode a JPEG at all.

This is the second git pin in the project — `tsdl-mixer` is pinned the same way —
and neither is recorded in a committed opam file, so **this section is the only
thing that tells a fresh clone what to pin.**

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

### Graphics (SDL2 + OpenGL)

```powershell
dune exec bin/gl_probe.exe
```

`tsdl` provides the window, input and GL context; `tgls` provides OpenGL, and also
OpenGL ES, so the same code covers desktop and Android. The probe reports the
driver it actually got - here a hardware 3.3 core context on Intel Iris Xe - and
checks that a shader compiles, a texture uploads and an alpha-blended quad draws.

Graphics assets are **not committed** - they are copyrighted Valusoft/Uzzle
material, same as `game/Assets.zip`, and `.gitignore` says so. Extract the ones
the battle screen needs once:

```powershell
python tools/extract_gfx_assets.py
```

That pulls three sheets and all ten font atlases into `assets/gfx/`. Python is the
default because PowerShell script execution is gated by policy on some machines,
and a build step you cannot run is one that will not be run. Two equivalents, if
you prefer:

```powershell
# bsdtar, no script at all (Windows 10+ ships tar, which reads zips)
tar -xf game\Assets.zip -C assets\gfx Assets/Skin/Skin_Gems_Grid.png

# the PowerShell route, bypassing policy for this invocation only
powershell -ExecutionPolicy Bypass -File tools/extract_gfx_assets.ps1
```

All three produce identical bytes; the extractor asserts nothing about the others
being present.

The glyph tables, the 32 named fonts and the bitmap registry are turned into OCaml
separately, and those files *are* committed:

```powershell
python tools/extract_fonts.py            # -> lib/font_data.ml
python tools/extract_skin_data.py        # -> lib/skin_data.ml
python tools/extract_fonts.py --check    # fail if the committed file is stale
python tools/extract_skin_data.py --check
```

Without the atlases the board still runs and the battle is still playable, on flat
colours, with no labels and no frame.

A playable window exists: `dune exec bin/pq_play_gfx.exe` runs the same
`Battle` as the ASCII runner with the mouse choosing instead of `read_line` -
click a gem then an adjacent one to swap, or a button on the bar to cast. It draws
at 1024x768, the game's own screen size, with its backdrop, its border and its
own bitmap fonts. Gems are the game's sprites, text is set in the game's fonts,
and there is no CRT filter and no placeholder typography.

### Decoration comes from the game's own registry

`Assets/Assets.xml` is the engine's asset registry: 44 sheets and **422 named
rectangles**, each with the size it is meant to be *drawn* at as well as the size
it is stored at. `tools/extract_skin_data.py` turns it into `lib/skin_data.ml`, so
decoration is addressed by the tag the game uses rather than by coordinates
somebody measured off a PNG:

```ocaml
Skin.draw skin runs "img_border_top" ~place
```

Three things that registry settled, none of which were obvious:

* **The window is 1024x768 because the art says so.** `Assets/Screens/Backdrop.xml`
  declares a 1024x768 menu, and the four border frames tile it exactly — top
  1024x95, left 19x653, right 21x653, bottom 1024x20, with 95+653 = 748 and
  748+20 = 768. `test_skin_data` asserts that tiling, so the window size cannot
  drift away from the decoration.
* **The backdrop is a JPEG**, and the file the registry names is
  `Skin_Backdrop_Standard.jpg` — not the `Skin_Backdrop_Battle.jpg` this repository
  was extracting, which `Assets.xml` never mentions. Hence the `imagelib` pin above.
* **Some frames are stored larger than they are drawn** — the red glows are 88x88 on
  disk for 64x64 on screen — so the registry's destination size is honoured rather
  than ignored.

The board's top inset is read from the border frame rather than typed, so the art
and the layout cannot disagree. A missing sheet costs its decoration and nothing
else: every draw call declines and the battle is still playable.

### Text: the game's own fonts

`Assets.zip` ships ten bitmap font atlases with a per-glyph table each, and
`<Language>/Font.xml` names 32 logical fonts - a face, a baseline, a line height
and an **RGB colour**. That last part is why there are thirty-two: `font_xp` is
purple, `font_gold` orange, and the seven `font_msg_*` styles are the float-message
palette. Naming the font names the colour, so the HUD takes its text colour from
the font rather than passing one.

This replaced a recorded decision to use `tsdl-ttf`. The argument for it was that
the game's strings are translated into five languages and so need font rendering
rather than a fixed glyph set - true, and beside the point, because the glyph
tables cover codes 32..8482. So text needed no dependency and no font pipeline.
`tsdl-ttf` is installed but **linked by nothing**.

One number is an inference rather than a recovery: the per-glyph advance.
`FUN_004c7650` sums a stored advance field, but adds a second field for the first
character and subtracts it for the last, and the two disagree for a one-character
string - so what that field is, is unknown. It cannot be settled from the binary
either, because the `FontData` attribute names are present but unreferenced: the
engine never parses these files. The port advances by the ink width instead,
supported by measuring the atlas - the table's two bearings sum to the ink width
rather than adding to it, and cells are packed edge to edge. The exception is the
space, which has a 1px placeholder rectangle, so the advance is
`max width (leading + trailing)`. See `gfx/font_layout.ml`,
`port.advance_is_ink_width` and the open question `font.advance_field_mapping`.

Float-message placement is a transcription, not a guess: `gfx/font_layout.ml`
anchors on the box's smaller corner, then clamps to a 20px margin with the
near-edge rule overriding the far-edge one, and reproduces the original's asymmetry
where the vertical clamp never looks at the text's height.

`tools/graphics_plan.md` records the decision, what is reused from the rails
project's engine, how Android differs (one GLSL version line, behind one module),
and why the two earlier plans - SDL3, and SDL2 without OpenGL - were both wrong.
`bin/sdl3_probe.exe` and `tools/sdl3_readiness.md` are kept; that path works too,
it is just not the shortest road.

### Play a Headless Battle
```powershell
dune exec bin/pq_battle.exe -- --seed 7 --hero-skill 200
dune exec bin/pq_battle.exe -- --seed 7 --trace --board
```
The same seed always produces the same fight, so a trace is reproducible.

### Play It Yourself
```powershell
dune exec bin/pq_play.exe -- --seed 7
dune exec bin/pq_play.exe -- --seed 7 --hero-mana 20 --spell SBAV --spell SBRA
dune exec bin/pq_play.exe -- --list
```
You take the hero's turns; the monster is driven by the recovered AI. On your
turn:

* **cast** by number, from the spells you can currently afford;
* **swap** two adjacent squares by coordinate, e.g. `c3 d3` - checked against the
  same legality test the AI's move generator uses, so an illegal swap is
  rejected rather than silently doing nothing;
* `l` lists the legal swaps, `p` passes your turn, `q` quits.

Casting a spell that ends your turn skips the swap, because in the original a
spell that consumes the turn means no swap happens that turn either.

Only the *choice* is yours. Everything after it - the cost charge, the cooldown
tick, the keeps-turn test, the effect body, the cascade, the damage chain - is the
recovered code path, so the hooks are two callbacks on `Battle.rules.player` and
default to `None`, which leaves the AI in charge of both decisions. Every
headless run and faithful test is unaffected.

### Watch the AI Decide Spells
```powershell
dune exec bin/pq_battle.exe -- --seed 5 --turns 120 --spells 4 --difficulty 2 --foe-skill 400 --trace
```
`--spells N` hands the foe N real spells from the game's own table. Each one
carries its ported `ShouldAICastSpell`, which reads the board, so `--trace` shows
the enemy weighing a gem count or a board evaluation before it commits. Give the
foe skill (`--foe-skill`), or it earns too little mana to afford anything but the
cheapest spell.


