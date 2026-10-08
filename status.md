# Puzzle Quest Clean-Room Reimplementation — Status

**Date:** 2026-10-08  
**Branch:** master (clean-room OCaml port)  
**Sync:** working tree clean. This sync wired the campaign to the battle
engine: quest Lua's `QUEST_BATTLE` calls and OnCompleteAction branches are
scanned into per-stage tables (128 stage actions over 155 `<Battle>`
elements), and `run_quest_battle` runs the stage's fight through the shared
constructor - monster roster, the fight's spells plus the player's known
spells, companion hooks - then `quest_battle_settle` applies life, spoils,
the stage transition, capture and ruin release. The demo's scripted
"battle won" is gone: it runs the real loop and reports what happened.
Plus the `campaign.quest_battle_flow` claim and the
`port.quest_battle_loop` decision. Build, all 28 suites and the
extractor/validator checks verified green.

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
- **Ruin registry (NEW):** `register_ruin` / `set_ruin_done` port the refcount from
  `Engine_QUEST_ADD_RUIN_452010.c` / `Engine_QUEST_SET_RUIN_DONE_452150.c` — a ruin
  shared by several quests (ROTO holds three) stays registered until the last release;
  releases come from extracted `QUEST_SET_RUIN_DONE` calls bucketed by hook
  (`ruin_dones_on_battle` / `_on_end` / `_on_abandon`) and fire at battle success,
  turn-in and the new `quest_abandon`. Absent id = no-op, as in the engine.
- **Capture (NEW):** `lib/capture.ml` ports the `[CAPTURE_HELP]` rules - the
  shipped 8x8 grid parses G/R/B/Y mana, S, O, X and * into the battle's own
  gems, a swap resolves through `Board.resolve_matches` + `apply_gravity`
  with no refill, and the attempt ends won (grid empty) or lost (no legal
  move). Defeats count per monster id from road wins (encounter sprite ->
  monster) and quest wins (battle_monster); `capture_eligible` applies the
  two `[CAPTURE_LISTHELP]` gates (dungeon built, 3+ wins), `capture_finish`
  adds the captive once, and `test_capture.ml` pins the charset, the
  settle loop, both battle paths, the gates and the save.
- **Companions (NEW):** `lib/campaign_companion_hooks.ml` ports the ten
  `OnStartBattle` bodies from `Assets/Companions/*.lua` into one rule table -
  CHECK_TYPE guards over the monster's type tags, NPAT's percentile roll plus
  life guard, NWIN's fire-skill threshold - over five payoffs (enemy damage,
  hero resistance/skill/mana, halved enemy banks); `lib/campaign_companions.ml`
  is the data half (text tags, home, portrait, hook flag). Hooks fire in party
  order after `Battle.create` and before the first turn, hits riding the
  log's `Damage` event since `[SPELL_EFFECT_DAMAGE2]` has none of its own.
  `player_to_combatant` / `encounter_to_combatant` now populate combatant
  skills, so `skill_of` reads profession and monster affinities in campaign
  battles at all; `RewardCompanion` dedups and caps the party at eight
  (`[COMPANIONS_HELP]`).
- **Rewards (NEW):** gold/XP/items/awards/companions read from the quest script by
  `tools/extract_quests.py`, which now statically scans quest Lua (file-scope string
  constants + `QUEST_*` calls per top-level function).
- **Save/Load:** JSON; now snapshots **live** map visibility (not static defaults),
  restores it into the tables on load, persists `awards`, the ruin registry
  (counts + done set) and capture state (dungeon flag, defeat counts,
  captives) with old-save defaults; quest states stored as the same ints the player record uses.
- **Quest battles (NEW):** `tools/extract_quests.py` scans quest Lua's
  `QUEST_BATTLE` calls into per-stage tables (128 actions, 155 `<Battle>`
  elements), and `Campaign.run_quest_battle` runs the stage's fight through
  the shared battle constructor - roster, spell line-ups, companion hooks -
  feeding `quest_battle_settle` (life, spoils, stage, capture, ruin release).
- **Tests:** `test/test_campaign.ml` (112), `test/test_capture.ml` (57),
  `test/test_companion.ml` (110) and `test/test_quest_battle.ml` (74) - 353
  assertions over prerequisites (every
  extracted condition), the accept -> battle -> turn-in lifecycle with real
  rewards, the both-endpoints road rule, the ruin registry (refcounts, shared
  ruins, the three release paths, the abandonable gate), capture grid parsing
  and charset, the no-refill settle loop on exact win/loss grids, defeat
  counting on the road and quest paths, the two capture gates, captives, save
  round-trips that diverge between save and load so a load that ignores the
  file cannot pass, every companion rule against the extracted data, the
  eight-slot party cap, a road battle whose log opens on the pre-battle
  hit, and the quest-battle loop (stage picks the fight, per-stage capture
  flag, loss branches, settle driving the win bookkeeping).
- **Demo:** `bin/campaign_demo.exe` runs new game → map → roads → encounters → battle →
  quest accept (prints reveals) → a real quest battle through `run_quest_battle`
  (turns, life, winner, spoils, stage) → turn-in when the stage advanced → shop →
  income → level-up → save → load. Verified green 2026-10-08.

---

## Evidence & Documentation

| File | Claims | Questions | Decisions |
|------|--------|-----------|-----------|
| `docs/reverse/evidence.yml` | 75 | 10 (5 open) | 20 |

Key decisions recorded:
- `port.effect_context_is_written_back` — spell board/gold/XP write-back contract
- `port.grid_effects_are_an_observer_not_an_event` — `Battle.on_grid_fx` third observer
- `campaign.map_visibility` — road/neighbour rule from `Engine_QUEST_SET_VISIBILITY_450e40.c`
- `campaign.quest_rewards_conditional` — branching reward callbacks take the first source-order branch
- `campaign.global_text_tables` — every campaign name resolves through the TextLibrary
- `campaign.ruin_registry` — ruin refcounts: register on accept, release on battle/turn-in/abandon
- `campaign.capture_eligible` - capture gates: dungeon built + 3 wins over that monster
- `campaign.capture_board` - capture clears an 8x8 grid with battle rules, no refill
- `campaign.companion_start_battle` - the ten OnStartBattle bodies as guards over payoffs
- `port.companion_hooks_fire_for_the_party` - party-wide dispatch, eight-slot cap, ACTIVATE_COMPANION as bookkeeping

Open questions (5): `font.advance_field_mapping`, `quest.base_value_from_level`,
`quest.difficulty_consumers`, `spell.match_resolution_after_a_spell`,
`spell.sfba_target_writeback`.

---

## Build / Test

```bash
# Build everything
opam exec -- dune build

# Run all tests (28 suites: 19 engine + 9 graphics)
opam exec -- dune runtest --force

# Campaign demo
opam exec -- dune exec bin/campaign_demo.exe

# Graphics battle (SDL2/OpenGL)
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_play_gfx.exe -- --demo 6
```

All 28 suites pass (exit 0, 2026-10-08). Extractor `--check` modes validate against
source assets.

---

## Next Milestones

| Priority | Area | Description |
|----------|------|-------------|
| **High** | **Ruin capture + companions** | Phase 3 landed: capture engine (grid, states, gates, captives, save) and companion hooks (ten OnStartBattle bodies, party dispatch, 8-slot cap, quest battles included); companion removal still open |
| **High** | **Campaign tests (rest)** | `test_campaign` covers prerequisites, lifecycle, visibility, ruin registry, save; travel, encounters, income and level-up still untested |
| **High** | **Campaign → Battle Integration** | Landed: encounter and quest fights both run through the real battle engine (`run_quest_battle` → settle → turn-in); the 36 guardless `QUEST_BATTLE` calls (conversation callbacks) still have no battle to run |
| **High** | **AI Overhaul** | Strategic gem evaluation, spell priority, cascade planning |
| **Medium** | **City UI** | Shop buy/sell, spell learning, companion management, tavern rumors |
| **Medium** | **World Map Rendering** | SDL2 map view: nodes, roads, hero marker, fog-of-war (visibility flags now exist) |
| **Medium** | **Grid Spell Targeting** | Cell selection UI for the 11 grid spells; `fx.ml` currently drops `target = Grid` effects |
| **Medium** | **Companions / Mounts** | Companion equip slot + passive bonuses, mount speed/fly, banner effects (party list and battle hooks now exist) |
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

1. **Campaign tests (rest)** — `test_campaign.ml` covers prerequisites, the quest
   lifecycle, the visibility rule, the ruin registry and the save round-trip
   (353 assertions across four campaign suites); travel, encounter triggering, income and level-up are untested
2. **Companion edges** — `QUEST_REMOVE_COMPANION` (5 sites in Q3S0.lua) and the
   leave-a-companion-at-a-location flow are not extracted; the six items and
   one rune that declare OnStartBattle are unwired; equip slot and UI open
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
  campaign_companions.ml   # 10 companions (text tags, home, hook flag)
  campaign_companion_hooks.ml # Hand-ported OnStartBattle rule table
  campaign_types.ml        # Shared type aliases
  campaign_save.ml         # JSON save/load incl. live map visibility + awards
tools/
  extract_campaign_map.py
  extract_encounters.py
  extract_quests.py        # XML + static Lua scan (QUEST_* calls, rewards, reveals)
  extract_items_professions_monsters.py
  extract_conversations.py
  extract_companions.py    # Companion XML + OnStartBattle flag
bin/
  campaign_demo.ml         # Playable loop with save/load
```
