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
  - Floating text driven by the battle's own event stream, placed by the recovered rule.
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
  * `text_data.ml`: The global TextLibrary — 2,630 tags behind every quest, city,
    item and monster name in the game, so a campaign tag renders as a string
    rather than as `[CITY_CBAR_NAME]`. Generated.
  * `score.ml`: End-of-battle score, both solo and co-op paths.
  * `battle.ml`: Headless battle loop wiring board, AI, combat, and spells together.
  * `crypto.ml`: WETSTD32 cipher algorithms (CRC-16, Transposition, Substitution, XOR).
  * `save_file.ml`: `.pqhero` binary deserializer, PNG thumbnail slicer, and hero state parser.
* `gfx/`: The presentation layer (`pq_gfx`), split so the arithmetic is testable without a window:
  * `layout.ml`: Board geometry and gem colours. Pure.
  * `input.ml`: What a click means, given which prompt is open. Pure.
  * `font_layout.ml`: Glyph advances, measuring, wrapping, and float-message placement. Pure.
  * `float_text.ml`: Which battle events become floating text, and its bounded stack. Pure apart from the draw call.
  * `sound_map.ml`: Which sound an event plays, including the recovered cascade ladder. Pure.
  * `audio.ml`: The mixer, lazy chunk loading, and the recovered do-not-restart rule.
  * `anim.ml`: Board snapshots to gem positions - swap slide, match pop, column fall. Pure.
  * `fx.ml`: Effect descriptors to sprites - keyframes, emitters, gravity. Pure.
  * `fx_data.ml`, `spell_fx.ml`: Generated. Which effect a spell asks for, and what that effect is.
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
* `test/`: Automated test suites (`test_board.ml`, `test_ai.ml`, `test_score.ml`, `test_combat.ml`, `test_spell.ml`, `test_battle.ml`, `test_font_data.ml`, `test_skin_data.ml`, `test_gfx_font_layout.ml`, `test_gfx_float_text.ml`, `test_gfx_sound_map.ml`, `test_gfx_anim.ml`, `test_spell_fx.ml`, `test_gfx_fx.ml`,
`test_text_data.ml`, `test_campaign.ml`).
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
* Required opam packages: `tsdl`, `tsdl-mixer`, `tgls`, `imagelib`, `containers` (all from the opam release; only `imagelib` is pinned, see below)
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

That pulls three sheets, all ten font atlases and the sound banks into `assets/gfx/` - 82 files, of which 69 are audio. Python is the
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

The glyph tables, the 32 named fonts, the bitmap registry, the spell effect
tables and the global text libraries are turned into OCaml separately, and those
files *are* committed:

```powershell
python tools/extract_fonts.py            # -> lib/font_data.ml
python tools/extract_skin_data.py        # -> lib/skin_data.ml
python tools/extract_spell_fx.py         # -> lib/spell_fx.ml
python tools/extract_fx_data.py          # -> lib/fx_data.ml
python tools/extract_text_tables.py      # -> lib/text_data.ml
python tools/extract_fonts.py --check    # fail if the committed file is stale
python tools/extract_skin_data.py --check
python tools/extract_spell_fx.py --check
python tools/extract_fx_data.py --check
python tools/extract_text_tables.py --check
```

Without the atlases the board still runs and the battle is still playable, on flat
colours, with no labels and no frame.

A playable window exists: `dune exec bin/pq_play_gfx.exe` runs the same
`Battle` as the ASCII runner with the mouse choosing instead of `read_line` -
click a gem then an adjacent one to swap, or a button on the bar to cast. It draws
at 1024x768, the game's own screen size, with its backdrop, its border and its
own bitmap fonts. Gems are the game's sprites, text is set in the game's fonts,
and there is no CRT filter and no placeholder typography.

```
dune exec bin/pq_play_gfx.exe -- --seed 7
dune exec bin/pq_play_gfx.exe -- --shot frame.ppm        # one frame, no input
dune exec bin/pq_play_gfx.exe -- --demo 14 --shot f.ppm # play 14 turns, then shoot
```

`--demo N` plays `N` turns with nobody at the keyboard before drawing. It exists
because `--shot` on its own photographs the board before the battle has done
anything, which cannot show a damage number or a cascade - and "the float text
renders" is not a claim worth making on the strength of a screenshot of an empty
board.

### The screen reacts to the battle

The engine narrates itself: `Battle.event` has 21 variants, and `Battle.on_event`
hands them over **as they occur** rather than in a batch at the end of a turn.
That is what lets floating text appear one at a time in the order the cascade
happened, and it cost one optional field - `emit` was already the single place an
event is recorded. It defaults to `None`, so every faithful test and the headless
runner are untouched.

Float messages are placed by the recovered rule (anchor on the box's smaller
corner, clamp to a 20px margin) and coloured by the font itself - `font_msg_red`
for damage, `font_msg_green` for mana, and six more. Which *events* become text is
our choice, not a recovery: the original's float text is driven by spell scripts
calling `ADD_TEXT_MESSAGE`, and a headless battle runs no scripts. That boundary
is asserted event by event in `test_gfx_float_text`, including the events that
deliberately say nothing.

The stack is bounded at eight, because a cascade emits mana events faster than
they expire and an unbounded column walks off the bottom of the screen taking the
damage number with it. The original bounds it too - a fixed ring of 60-unit slots.

### Sound

`Assets/Assets.xml` has a third section after the bitmaps: **82 named sounds**.
The port addresses them by the tag the engine passes to `PLAY_SOUND` -
`snd_damage`, `snd_cascade3` - rather than by filename, which matters because the
tag doesn't *give* the filename:

| tag | file | |
| --- | --- | --- |
| `snd_damage` | `Damage.wav` | straight stem match |
| `snd_earth` | `EarthMana.wav` | renamed |
| `snd_buttdown` | `ButtonDown.wav` | renamed |
| `snd_voice_victory` | `VVictorious.wav` | renamed, in a per-language directory |
| `music_theme` | *nothing* | no audio in the archive |

`lib/skin_data.ml` records *how* each tag resolved - `Exact`, `Renamed` or
`Absent` - so a filename match is never confused with a rule applied on top. **68 of
the 82 have audio; all 14 music tags have none**, and there is no Ogg, MP3 or module
file anywhere in the archive. If you extend this, that is the thing to know first.

Two rules are recovered rather than chosen:

- **A match does not make a noise.** `FUN_0047AE80` switches on the cascade counter
  and *skips the sound for the first two values*, so step 1 is silent, step 2 plays
  `snd_cascade1`, and seven or more keeps `snd_cascade6`. A port that gave every
  match a noise would look and behave almost identically and nothing in a screenshot
  would show it.
- **A sound already sounding is not restarted.** That matters more than it sounds: a
  cascade emits several `ManaGained` events in quick succession, and without the rule
  each one cuts the last off and restarts it, which is a click rather than a sound.

Heroic effort plays **two** sounds, the voice line then the effect, which is why
the event-to-sound mapping returns a list rather than a tag.

One deliberate divergence: the original compares against a single global "currently
playing" sound, so two sounds never overlap from this path. Here each tag has its
own channel, so a cascade rumbles *under* the damage numbers instead of replacing
them.

A *spell's* sound used to be a guess - `snd_spellfire` for anything that cost mana -
and is now recovered. Every spell script passes a `SPELLFX_*` constant to one of four
`Std_*SpellEffect` helpers, and each helper resolves that constant through
`Std_GetSpellSoundAsset` to one of six spell sounds. `tools/extract_spell_fx.py`
reads both tables and all 130 spell scripts into `lib/spell_fx.ml`, so the port looks
the constant up by spell id and plays what the game plays. See
`port.spell_fx_follows_the_script`, which supersedes `port.spell_sound_is_guessed`.

The same table names the *picture*: `Std_GetSpellFXAsset` maps 21 constants to effect
assets, and those are keyframed descriptors - 48 of them under `Assets/Effects`, with
51 particle emitters under `Assets/Particles`. `tools/extract_fx_data.py` turns both
into `lib/fx_data.ml`, and `gfx/fx.ml` plays them: keyframes ramp per parameter,
emitters release `release` particles every `interval` up to `max`, particles fall
under their own gravity, and each one fades between a start and an end size and
colour once its `start` fraction of life is past.

So a spell's timing is the game's: `SpellHealing` runs for 2.1 seconds because its
descriptor says so, rather than because this port guessed a duration. `fx.ml` is
pure, so all of that is asserted in `test_gfx_fx` rather than watched on screen.

Playing one needed two things the batcher did not have. Quads now rotate - by turning
their four corners about their own centre in pixel space, which is exact for a
rectangle and costs no vertex attribute - because `SpellHealing` turns its ring
through 12.4 radians. And each draw batch carries its own blend mode, because all but
a handful of particles ask for `additive` and an additive sparkle drawn with the
ordinary alpha blend is a grey dot.

An effect's own bitmap is a region of the battle sheet, addressed the way the
decoration is (`bmp_skin_battlemisc` plus a rectangle); its particles are six whole
32x32 and 64x64 PNGs, extracted whole because none of them is a registry frame. The
six are named by file in the descriptors, so `assets/gfx/Particles/Sparkle.png` is
found by the same string the archive used.

**Which cell is the part that cannot be looked up.** Eleven spells put an effect on a
grid cell, and the cell is whatever the spell body had just chosen: a random isolated
cell for `SBAC`, the aimed cell for `SFOD`, three literals for `SCON`. So the battle
carries it - `Battle.on_grid_fx` is a third observer, called by the spell body through
the same primitive the Lua used, and the front end is *told* where rather than working
it out. Not an event: a log entry is something that happened, and reading the log
should not require knowing about a sparkle.

Getting that seam in place turned up a bug behind it. An effect context holds the
board, the gold and the xp as refs, and they are *copies* - `Board` is persistent, so
`ref b.board` is a fresh cell - while the combatants are shared mutable records. The
cast path applied gravity and a refill to the battle's board without reading the
body's back, so **every spell's board edit was silently discarded**, along with its
gold and xp, while its damage, its mana cost and its status effects all worked. The
visible half of a cast was fine, which is why it survived: the spell bodies are tested
against their own board, and the battle tests assert the log and the totals. It was
found by asking a question the new seam made askable - *is the cell the spell reported
the cell the board now holds?* - and getting `no`.

What it does not settle is whether a line completed by a spell should then resolve.
It is now reachable for the first time, and recorded as
`spell.match_resolution_after_a_spell` rather than guessed at.

Three things it deliberately does not interpret, each recorded rather than papered
over: `Shape steps` (2 in seven particles), the planar `planes` codes, and
`AnimPosition`. The five Ring particles - which is what `SpellHealing` actually
plays - use the last two, so a healing ring is emitted from its centre rather than
around a ring until the engine's particle code has been read.

Audio is silent by construction: no device, no extracted bank, or an unknown tag
all mean "play nothing", never an error. The demo line reports how many sounds were
started, because otherwise "is it wired up" has no observable answer.

### Gems move

`Battle.on_event` narrates what happened; it cannot animate, because an event is a
fact and a falling gem needs the board on either side of the change. So there is a
second observer. `Battle.step` carries the boards:

| step | carries |
| --- | --- |
| `Swapped` | the board before, the board after, and the two cells |
| `Cascaded` | `before` (what you were looking at), `cleared` (matches gone, gaps open), `after` (gravity and refill), and the runs |

`Battle.on_step` hands those over at the three points that produce them. It is one
optional field, it defaults to `None`, and `test_battle` asserts that a watched
battle and an unwatched one produce identical logs - so this is instrumentation
rather than a change to the fight.

The part that took a second pass is pacing. `Battle` resolves a whole turn
synchronously, so all six steps of a cascade arrive back to back while nothing is
drawing; queueing them means the board is already final by the time anything is
shown, and the player watches the board rewind through states it has already been
in. So the front end **blocks in `on_step` until the animation it just queued has
finished**. The engine is single-threaded and has no clock, so the only thing that
can happen meanwhile is that no further steps are produced - which is the point.

What that buys, all driven off the snapshots rather than off a timeline:

- **Swap slide** - the two gems cross, in one 0.13s phase, on both axes.
- **Match pop** - only the matched gems shrink and fade. The fade is per gem, not
  per frame; one alpha for the whole board would dim the stationary board too, which
  reads as the board flashing.
- **Cascade fall** - gems pair off **bottom-up within a column**, which is what
  gravity does to a column, and newcomers drop in from above row 0. The board clips
  them: a scissor rides on each draw batch, because the vertex batcher does not draw
  when you push.

The durations (0.14s pop, 0.18s fall, 0.13s slide) are ours - nothing in the port
knows the original's timing table. The pairing is what `test_gfx_anim` pins hardest,
because a fall that pairs every gem with *something* still looks plausible and still
teleports the wrong ones.

```sh
dune exec bin/pq_play_gfx.exe -- --demo 6 --pace          # play 6 turns, animated, then exit
dune exec bin/pq_play_gfx.exe -- --demo 6 --shot-at 0.2 --shot fall.ppm
```

`--pace` plays a demo through the same blocking loop the interactive game uses, so
the paced path can be exercised without a keyboard, and reports how many animation
frames it drew. `--shot-at T` stops inside the first phase, which is how a fall gets
looked at.

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


