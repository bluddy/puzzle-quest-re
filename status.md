# Puzzle Quest Clean-Room Reimplementation — Status

**Date:** 2026-10-07  
**Branch:** main (clean-room OCaml port)

---

## What Works

### Battle Layer (Complete)
- **Board & gems:** 8×8 grid, swap validation, match detection, cascades, gravity, refill
- **Combat:** Hero/foe stats, life/mana, damage, status effects, spell casting
- **Spells:** 130 spells ported from Lua; 11 spells with 13 grid-effect calls (`Std_GridSpellEffect`)
- **Animation:** Per-gem pop (matched fade/shrink), column-bottom-up fall, entrant slide; `Battle.on_step` observer
- **Sound:** Full `Audio.play_all` fix; cascade step sounds (1 silent, 2=`snd_cascade1`, 7+=`snd_cascade6`); spell sounds via `Spell_fx.calls_of_spell`
- **Spell effects:** 21 caster/grid effects, 22 sound tags, 24 constants; particle system (6 textures, gravity/velocity/color/size interpolation, additive/alpha blending)
- **Write-back fix:** Spell board/gold/XP edits now persist (was silently discarded)
- **Text:** 10 bitmap fonts, float-text event messages, bounded stack
- **Tests:** 4 test suites (battle, spell_fx, spell_effects, gfx_fx) — all green

### Campaign Layer (Complete — First Playable Loop with Save/Load)
- **Map data:** 20 cities, 40 waypoints, 28 ruins, 93 roads (typed graph)
- **Encounters:** 57 road encounters with appearance logic (`my_level`, `chance` extracted from Lua)
- **Quests:** 142 quests with state machines, prerequisites, localized text, battle rewards
- **Items/Professions/Monsters:** 160 items, 4 classes (Warrior/Druid/Knight/Wizard), 60 monsters with capture grids
- **Conversations:** 273 dialogue trees with backdrops, portraits, branching
- **Engine:** Player creation, travel, encounter triggering, city shops/income, quest state machine, level-up
- **Save/Load:** JSON serialization for player, quests, map visibility, location; round-trip tested in demo
- **Demo:** `bin/campaign_demo.exe` runs new game → map → roads → encounters → battle → quests → shop → income → level-up → save → load

---

## Evidence & Documentation

| File | Claims | Questions | Decisions |
|------|--------|-----------|-----------|
| `docs/reverse/evidence.yml` | 67 | 10 | 17 |

Key decisions recorded:
- `port.effect_context_is_written_back` — spell board/gold/XP write-back contract
- `port.grid_effects_are_an_observer_not_an_event` — `Battle.on_grid_fx` third observer
- `spell.match_resolution_after_a_spell` — open: does engine cascade after spell board edits?

---

## Build / Test

```bash
# Build everything
opam exec -- dune build

# Run all tests
opam exec -- dune runtest --force

# Campaign demo
opam exec -- dune exec bin/campaign_demo.exe

# Graphics battle (SDL2/OpenGL)
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_play_gfx.exe -- --demo 6
```

All tests pass. Extractor `--check` modes validate against source assets.

---

## Next Milestones

| Priority | Area | Description |
|----------|------|-------------|
| **High** | **Campaign → Battle Integration** | Wire `Encounter → Battle → Quest.on_complete → rewards → map` |
| **High** | **Save / Load** | ~~Binary format (or JSON) for player + quest states + map progress~~ **DONE** |
| **High** | **AI Overhaul** | Strategic gem evaluation, spell priority, cascade planning |
| **Medium** | **City UI** | Shop buy/sell, spell learning, companion management, tavern rumors |
| **Medium** | **World Map Rendering** | SDL2 map view: nodes, roads, hero marker, fog-of-war (visibility flags) |
| **Medium** | **Companions / Mounts** | Capture mini-game, party slots, mount speed/fly, banner effects |
| **Low** | **Enemy Variety** | Distinct monster spell rosters, resistances, multi-phase bosses |
| **Low** | **Hotseat MP** | Two players, shared screen, same battle engine |
| **Low** | **Polish** | Key remap, color-blind palettes, UI scale, tooltips, settings menu |

---

## Architecture Notes

- **No Lua at runtime** — all logic ported to OCaml; extractors run once at dev time
- **Data-driven** — generated `lib/campaign_*.ml` modules are pure data + lookup fns
- **Observer pattern** — `Battle.on_event`, `on_step`, `on_grid_fx` keep battle headless-testable
- **Asset pipeline** — `assets/gfx/` holds extracted PNGs (fonts, particles, sheets); `PQ_GFX_ASSETS` env var
- **Module graph:** `lib/dune` exports `Campaign` + 7 data modules under `Puzzle_quest_lib`

---

## Known Gaps

1. **Quest prerequisite checks** — `donequest*`, `companion*`, `item`, `award` conditions stubbed
2. **Ruins / companion capture** — mini-game board logic not implemented
3. **Map visibility progression** — roads/ruins unlock via quests (`visible="no"` → `"yes"`)
4. **Spell targeting UI** — grid spells (SFOD, SCON, etc.) need cell selection in graphics
5. **Monster spell rosters** — AI only uses `Spell` tags from monster XML; no dynamic selection
6. **Conversation branching** — `Action.type` variants (`talk_youngmale`, `wait`, `end`) not wired to dialogue UI

---

## Quick Start for Contributors

```bash
# 1. Install deps (OCaml 5.3, SDL2, SDL2_mixer, imagelib@jpeg-codec)
opam install dune tsdl tsdl-mixer tgls imagelib

# 2. Build
opam exec -- dune build

# 3. Run demo
opam exec -- dune exec bin/campaign_demo.exe

# 4. Graphics battle
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_play_gfx.exe
```

---

## File Index (Generated)

```
lib/
  campaign.ml              # Engine core
  campaign_map.ml          # 20 cities, 40 waypoints, 28 ruins, 93 roads
  campaign_encounters.ml   # 57 encounters (my_level, chance)
  campaign_quests.ml       # 142 quests + localized text
  campaign_items.ml        # 160 items
  campaign_professions.ml  # 4 classes (skills, spells, XP)
  campaign_monsters.ml     # 60 monsters (capture grids)
  campaign_conversations.ml# 273 dialogues
  campaign_types.ml        # Shared type aliases
  campaign_save.ml         # JSON save/load
tools/
  extract_campaign_map.py
  extract_encounters.py
  extract_quests.py
  extract_items_professions_monsters.py
  extract_conversations.py
bin/
  campaign_demo.ml         # Playable loop with save/load
```