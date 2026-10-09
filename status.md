# Puzzle Quest Clean-Room Reimplementation — Status

**Date:** 2026-10-09  
**Branch:** master (clean-room OCaml port)  
**Sync:** working tree clean. Conversation UI implemented — 273 dialogue trees with portraits, backdrops, and branching choices now render via `pq_conv_gfx.exe`. The pure geometry lives in `gfx/conversation_layout.ml` and the panel photographs itself with `--conv --shot`. All 29 suites pass, extractor/validator checks verified green.

---

## What Works

### Battle Layer (Complete)
- **Board & gems:** 8×8 grid, swap validation, match detection, cascades, gravity, refill
- **Combat:** Hero/foe stats, life/mana, damage, status effects, spell casting
- **Spells:** 130 spells ported from Lua; 11 spells with 13 grid-effect calls (`Std_GridSpellEffect`); the nine `Input` spells aim from the cast question (`choose_aim` -> `fx_input`) and the six hook picks land as `ctx_aim`
- **Animation:** Per-gem pop (matched fade/shrink), column-bottom-up fall, entrant slide; `Battle.on_step` observer
- **Sound:** Full `Audio.play_all` fix; cascade step sounds (1 silent, 2=`snd_cascade1`, 7+=`snd_cascade6`); spell sounds via `Spell_fx.calls_of_spell`
- **Spell effects:** 21 caster/grid effects, 22 sound tags, 24 constants; particle system (6 textures, gravity/velocity/color/size interpolation, additive/alpha blending)
- **Write-back fix:** Spell board/gold/XP edits now persist (was silently discarded)
- **Text:** 10 bitmap fonts, float-text event messages, bounded stack

### Campaign Layer (Data + engine complete; UI started)
- **Map data:** 20 cities, 40 waypoints, 28 ruins, 93 roads (typed graph)
- **Encounters:** 57 road encounters with appearance logic (`my_level`, `chance` extracted from Lua); road fights load the monster's spell roster and compute their difficulty band from `my_level`
- **Quests:** 142 quests with state machines, prerequisites, per-quest text, battle rewards
- **Items/Professions/Monsters:** 160 items, 4 classes (Warrior/Druid/Knight/Wizard), 60 monsters with capture grids
- **Conversations:** 273 dialogue trees with backdrops, portraits, branching
- **Conversation UI (NEW):** `bin/pq_conv_gfx.exe` — renders portrait, backdrop, dialogue text, and choice buttons; `gfx/conversation_layout.ml` holds 14 assertions over recovered coordinates; `--conv --shot` pixel-checks the panel
- **Global text (NEW):** `lib/text_data.ml` — 2,630 tags from the fifteen
  `English/*Text.xml` TextLibrary files; `Text_data.text` resolves a tag or returns
  it unchanged. Quest titles, city/item/monster/profession names now render as
  strings (`Family Reunion`, `Bartonia`, `Warrior`) instead of `[TAG]`.
- **Engine:** Player creation, travel (journey step: begin, advance, arrival, departure encounter roll), encounter triggering, city shops/income (buy at the registry cost, gold checked), level-up
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
- **Companion removal (NEW):** eight `QUEST_REMOVE_COMPANION` sites - six
  arrival rules (Q3S0 states 2-6 over five cities, QS00 at CENM) extracted
  into each quest's `enter_removes`; `Campaign.enter_location` runs them
  when the hero arrives and drops the companion through `RemoveCompanion`.
  The two sites inside conversation callbacks (Q3Q5, QU02) count but have
  no arrival to run under.
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
- **Item start hooks (NEW):** `tools/extract_items.ps1` reads each script's
  declare table for `OnStartBattle` (six of 160 - IDHE/IFLH helms credit
  mana, the four IWL* walls raise max life and life), `lib/item_hooks.ml`
  ports the bodies, and `open_battle` fires them on both sides after the
  companion pass; `loadout_of_equipment` folds the nine-field character
  panel into the four battle slots by each item's own location, so a wall
  in the gauntlets field still wears the body slot.
- **Tests:** `test/test_campaign.ml` (175), `test/test_capture.ml` (57),
  `test/test_companion.ml` (110) and `test/test_quest_battle.ml` (74) - 416
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
| `docs/reverse/evidence.yml` | 83 | 10 (4 open) | 27 |

Key decisions recorded:
- `port.item_start_battle_dispatch` — items fire after companions, both sides, panel folds by item location
- `port.human_aim_click` — one click aims a spell (the bar cancels back to the spell question)
- `port.ai_aim_fallback` — hooks that store nothing aim at nothing; SCHG's row rides as y, the column slot0 as x
- `port.campaign_task_level` — road task is the encounter's my_level, quest task the monster's base; hero_level_cap stays default
- `port.map_screen_mapping` — the map fits the window whole; 16px click radius; 120 units/s walk
- `port.city_services` — buying checks gold against cost only; ShopMenu's rows and buttons reused; rumors in tag order
- `port.conversation_ui` — portrait at (96,50), dialogue at y=170, choices at y=350; text wraps at 560px; `--conv --shot` pixel-checks
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

Open questions (4): `font.advance_field_mapping`, `quest.base_value_from_level`,
`quest.difficulty_consumers`, `spell.match_resolution_after_a_spell`.

---

## Build / Test

```bash
# Build everything
opam exec -- dune build

# Run all tests (29 suites: 19 engine + 10 graphics)
opam exec -- dune runtest --force

# Campaign demo
opam exec -- dune exec bin/campaign_demo.exe

# Graphics battle (SDL2/OpenGL)
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_play_gfx.exe -- --demo 6

# World map (SDL2/OpenGL); --city opens the start city's panel
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_map_gfx.exe

# Conversation panel (SDL2/OpenGL); --conv --shot pixel-checks the panel
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_conv_gfx.exe -- --conv Q0I2a --shot
```

All 29 suites pass (exit 0, 2026-10-09). Extractor `--check` modes validate against
source assets.

---

## Next Milestones

| Priority | Area | Description |
|----------|------|-------------|
| **High** | **Ruin capture + companions** | Phase 3 landed: capture engine (grid, states, gates, captives, save) and companion hooks (ten OnStartBattle bodies, party dispatch, 8-slot cap, quest battles included, companion removal through enter_location); companion equipping still open |
| **High** | **Campaign → Battle Integration** | Landed: encounter and quest fights both run through the real battle engine (`run_quest_battle` → settle → turn-in); the 36 guardless `QUEST_BATTLE` calls (conversation callbacks) still have no battle to run |
| **Medium** | **World Map Rendering** | SDL2 map view: nodes, roads, hero marker, fog-of-war (visibility flags now exist) |
| **Medium** | **Grid Spell Targeting** | Cell selection UI for the 11 grid spells; `fx.ml` currently drops `target = Grid` effects |
| **Medium** | **City UI** | Shop buy/sell, spell learning, companion management, tavern rumors (conversation panel done) |
| **Medium** | **Companions / Mounts** | Companion equip slot + passive bonuses, mount speed/fly, banner effects (party list and battle hooks now exist) |
| **Low** | **Enemy Variety** | Distinct monster spell rosters, resistances, multi-phase bosses |
| **Low** | **Hotseat MP** | Two players, shared screen, same battle engine |
| **Low** | **Polish** | Key remap, color-blind palettes, UI scale, tooltips, settings menu |
| **Optional** | **AI Enhancements** | *Beyond 1.0:* cascade planning, strategic gem evaluation, spell priority reordering — the original AI only scores immediate swaps via probe window and uses spell list order + hook returns |

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

1. **Campaign → Battle Integration** — 36 guardless `QUEST_BATTLE` calls in conversation callbacks (Q3Q5, QU02, etc.) have no battle to run; the engine supports `run_quest_battle` but the callback wiring is missing.
2. **Companion edges** — arrival removal is extracted and run (`enter_location`, six rules; the Q3Q5/QU02 callback sites have no arrival event to run under, and no travel step calls enter_location yet); the rune's `OnStartBattle` waits on the forge's rune state; equip slot and UI open
3. **Fog of war / visible range** — visibility flags exist and save correctly, and the map window now draws the hero's position (current node, or on the road); still open is visible-*range* logic - recomputing what the hero can see from where they stand - and fog painting
4. **Spell targeting** — both halves wired: the player aims from the cast question (click / `b3`, `choose_aim` -> `fx_input`) and the six hooks' `SET_INPUT_DATA` picks land for machines too (`ctx_aim`, cleared per candidate); hover cursor and valid-target highlighting are cosmetic-open, and SFOD/SSPA/SPRO aim at nothing when the machine casts them, since their hooks store no cell (`port.ai_aim_fallback`)
5. **Monster spell rosters** — quest and road fights both load the monster's registry `Spell` tags now; mana-aware dynamic selection and any weighting of spell choice beyond each hook's own board reads remain open
6. **Conversation branching** — `Action.type` variants (`talk_youngmale`, `wait`, `end`) not wired to dialogue UI
7. **Conditional quest rewards** — if/else reward branches take the first source-order value (recorded as `campaign.quest_rewards_conditional`)
8. **Languages** — `text_data.ml` ships English only; French, German, Italian and Spanish carry the same 2,638 entries and the extractor takes `--language`

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
  conversation.ml          # Conversation data: load_all, find, next_line from TextLibrary
tools/
  extract_campaign_map.py
  extract_encounters.py
  extract_quests.py        # XML + static Lua scan (QUEST_* calls, rewards, reveals)
  extract_items_professions_monsters.py
  extract_conversations.py
  extract_companions.py    # Companion XML + OnStartBattle flag
bin/
  campaign_demo.ml         # Playable loop with save/load
  pq_conv_gfx.ml           # Conversation panel: portrait, backdrop, dialogue, choices
gfx/
  conversation_layout.ml   # Pure geometry + 14 assertions; --conv --shot
```
