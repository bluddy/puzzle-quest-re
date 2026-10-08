# Puzzle Quest Clean-Room Reimplementation — Status

**Date:** 2026-10-08  
**Branch:** master (clean-room OCaml port)  
**Sync:** working tree clean. This sync landed two things: the campaign
quest-lifecycle work (prerequisites, accept/battle/turn-in, map reveals, save of
live visibility + awards) and the global text tables that make every campaign
name render as a string. Build, all 24 suites and the demo verified green.

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

### Campaign Layer (Data + engine complete; UI not started)
- **Map data:** 20 cities, 40 waypoints, 28 ruins, 93 roads (typed graph)
- **Encounters:** 57 road encounters with appearance logic (`my_level`, `chance` extracted from Lua)
- **Quests:** 142 quests with state machines, prerequisites, per-quest text, battle rewards
- **Items/Professions/Monsters:** 160 items, 4 classes (Warrior/Druid/Knight/Wizard), 60 monsters with capture grids
- **Conversations:** 273 dialogue trees with backdrops, portraits, branching
- **Global text (NEW):** `lib/text_data.ml` — 2,630 tags from the fifteen
  `English/*Text.xml` TextLibrary files; `Text_data.text` resolves a tag or returns
  it unchanged. Quest titles, city/item/monster/profession names now render as
  strings (`Family Reunion`, `Bartonia`, `Warrior`) instead of `[TAG]`.
- **Engine:** Player creation, travel, encounter triggering, city shops/income, level-up
- **Quest prerequisites (NEW):** `is_quest_available` checks every extracted condition —
  `donequest0/1/2`, `notdonequest`, `notactivequest`, `companion0/1`, `notcompanion`,
  `item`, `notitem`, `award`, `notaward` — plus level band and not-already-active.
- **Quest lifecycle (NEW):** `quest_accept` (OnBegin → reveals) → `quest_battle_complete`
  (state 1→2 on win, no-op on loss) → `quest_turn_in` (OnEnd → gold/XP/items/awards/
  companions + `CompleteQuest` bookkeeping). Road encounters no longer advance quest
  state — quest Lua drives its own fight (`QUEST_BATTLE`), that separation is now real.
- **Map visibility (NEW):** mutable node/road tables, `set_location_visible` implements
  the recovered rule (road visible only when **both** endpoints are, citing
  `Engine_QUEST_SET_VISIBILITY_450e40.c`); reveals come from extracted
  `QUEST_SET_VISIBILITY` / `QUEST_ADD_RUIN` calls grouped by hook
  (`reveal_on_begin` / `reveal_on_end` / `ruin_reveals`).
- **Rewards (NEW):** gold/XP/items/awards/companions read from the quest script by
  `tools/extract_quests.py`, which now statically scans quest Lua (file-scope string
  constants + `QUEST_*` calls per top-level function).
- **Save/Load:** JSON; now snapshots **live** map visibility (not static defaults),
  restores it into the tables on load, and persists `awards`; quest states stored as
  the same ints the player record uses.
- **Demo:** `bin/campaign_demo.exe` runs new game → map → roads → encounters → battle →
  quest accept (prints reveals) → battle win → turn-in (prints rewards) → shop → income →
  level-up → save → load. Verified green 2026-10-08.

---

## Evidence & Documentation

| File | Claims | Questions | Decisions |
|------|--------|-----------|-----------|
| `docs/reverse/evidence.yml` | 70 | 10 (5 open) | 17 |

Key decisions recorded:
- `port.effect_context_is_written_back` — spell board/gold/XP write-back contract
- `port.grid_effects_are_an_observer_not_an_event` — `Battle.on_grid_fx` third observer
- `campaign.map_visibility` — road/neighbour rule from `Engine_QUEST_SET_VISIBILITY_450e40.c`
- `campaign.quest_rewards_conditional` — branching reward callbacks take the first source-order branch
- `campaign.global_text_tables` — every campaign name resolves through the TextLibrary

Open questions (5): `font.advance_field_mapping`, `quest.base_value_from_level`,
`quest.difficulty_consumers`, `spell.match_resolution_after_a_spell`,
`spell.sfba_target_writeback`.

---

## Build / Test

```bash
# Build everything
opam exec -- dune build

# Run all tests (24 suites: 15 engine + 9 graphics)
opam exec -- dune runtest --force

# Campaign demo
opam exec -- dune exec bin/campaign_demo.exe

# Graphics battle (SDL2/OpenGL)
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_play_gfx.exe -- --demo 6
```

All 24 suites pass (exit 0, 2026-10-08). Extractor `--check` modes validate against
source assets.

---

## Next Milestones

| Priority | Area | Description |
|----------|------|-------------|
| **High** | **Campaign tests** | `test_text_data` landed; prerequisites, lifecycle, visibility and save-restore still verified only by demo output |
| **High** | **Campaign → Battle Integration** | Wire `Encounter → Battle → quest_battle_complete → turn-in → rewards → map` into one loop (partly landed; still demo-scripted) |
| **High** | **AI Overhaul** | Strategic gem evaluation, spell priority, cascade planning |
| **Medium** | **City UI** | Shop buy/sell, spell learning, companion management, tavern rumors |
| **Medium** | **World Map Rendering** | SDL2 map view: nodes, roads, hero marker, fog-of-war (visibility flags now exist) |
| **Medium** | **Grid Spell Targeting** | Cell selection UI for the 11 grid spells; `fx.ml` currently drops `target = Grid` effects |
| **Medium** | **Companions / Mounts** | Capture mini-game, party slots, mount speed/fly, banner effects |
| **Low** | **Enemy Variety** | Distinct monster spell rosters, resistances, multi-phase bosses |
| **Low** | **Hotseat MP** | Two players, shared screen, same battle engine |
| **Low** | **Polish** | Key remap, color-blind palettes, UI scale, tooltips, settings menu |

---

## Architecture Notes

- **No Lua at runtime** — all logic ported to OCaml; extractors run once at dev time
  (quest Lua is now *statically scanned* by `extract_quests.py`, not interpreted)
- **Data-driven** — generated `lib/campaign_*.ml` modules are pure data + lookup fns
- **Observer pattern** — `Battle.on_event`, `on_step`, `on_grid_fx` keep battle headless-testable
- **Map state is mutable** — node/road visibility lives in tables (restored by save/load),
  everything else campaign-side is pure `player -> player`
- **Asset pipeline** — `assets/gfx/` holds extracted PNGs (fonts, particles, sheets); `PQ_GFX_ASSETS` env var
- **Module graph:** `lib/dune` exports `Campaign`, the generated campaign data
  modules and `Text_data` under `Puzzle_quest_lib`

---

## Known Gaps

1. **Campaign tests** — prerequisites/lifecycle/visibility/save round-trip untested
   in `test/` (`test_text_data` covers names only)
2. **Ruins / companion capture** — mini-game board logic not implemented
3. **Fog of war / hero marker** — visibility flags exist and save correctly, but there is
   no hero position on the map and no visible-range logic
4. **Spell targeting UI** — grid spells (SFOD, SCON, etc.) need cell selection in graphics
5. **Monster spell rosters** — AI only uses `Spell` tags from monster XML; no dynamic selection
6. **Conversation branching** — `Action.type` variants (`talk_youngmale`, `wait`, `end`)
   not wired to dialogue UI
7. **Conditional quest rewards** — if/else reward branches take the first source-order
   value (recorded as `campaign.quest_rewards_conditional`)
8. **Languages** — `text_data.ml` ships English only; French, German, Italian and
   Spanish carry the same 2,638 entries and the extractor takes `--language`

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
  campaign.ml              # Engine core: prerequisites, quest lifecycle, visibility
  campaign_map.ml          # 20 cities, 40 waypoints, 28 ruins, 93 roads
  campaign_encounters.ml   # 57 encounters (my_level, chance)
  campaign_quests.ml       # 142 quests + per-quest text + extracted rewards/reveals
  campaign_items.ml        # 160 items
  campaign_professions.ml  # 4 classes (skills, spells, XP)
  campaign_monsters.ml     # 60 monsters (capture grids)
  campaign_conversations.ml# 273 dialogues
  campaign_types.ml        # Shared type aliases
  campaign_save.ml         # JSON save/load incl. live map visibility + awards
tools/
  extract_campaign_map.py
  extract_encounters.py
  extract_quests.py        # XML + static Lua scan (QUEST_* calls, rewards, reveals)
  extract_items_professions_monsters.py
  extract_conversations.py
bin/
  campaign_demo.ml         # Playable loop with save/load
```
