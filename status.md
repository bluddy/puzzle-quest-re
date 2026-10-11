# Puzzle Quest Clean-Room Reimplementation — Status

**Date:** 2026-10-11  
**Branch:** master (clean-room OCaml port)  
**Sync:** working tree clean. Five follow-ups since mount training. The quest scanner's effect-group ordering is now deterministic - equal-position rows keep the sites' source order instead of hashing between regenerations (three quests had been flipping their ShowMessage pairs; found by regenerating and diffing). The last two QUEST_REMOVE_COMPANION sites landed: Q3Q5's CallbackConvE drops NDKH, QU02's CallbackConvB drops NSUN - attributed by callback name into `remove_companion_on_callbacks` and applied by `execute_callback` before the effects fold, the Lua body's source order; a second fire finds the companion already gone, the no-op the engine's absent-id check would have made (`campaign.quest_remove_companion` extended with both callback scripts). And message-row extraction learned branch arms: an assignment in a sibling arm of a branch open at the site is dead there, so sites stopped collecting their twin's text - 68 phantom rows dropped across nine quests (duplicate SUCCESS/NOCOMP boxes in Q3Q6, QK06, QS02, Q1Q8, Q1R3, Q3Q4, QS00; cross-arm FAILURE copies in Q1Q0, Q3Q2), each verified against the Lua. That rule closed the copies but both arms still shared one group key, so the dual-arm gap closed next: the guard snapshots now parse `QUEST_HERO_HAS_COMPANION_SELECTED` into `(companion id, present)` pairs per open frame (an else-arm flips the single test), every group and query key carries the conjunction, and `companion_ok` checks it against `player.companions` when a group applies - QS00 queues NOCOMP vs PRELUDE (the remove rules now run after the group fold, so the gates read the party the arrival started with), QK06 NOCOMP vs BUTTON, QP01's label only with NPAT along; 54 groups + 4 query rows gated. The three flat lists closed the last of the companion gap this round: OnBegin conversations queue only when their pair holds (Q0Q8/Q3Q6, both NKHA), `callback_effects` rows fold under the gate at `execute_callback` time (12 sites - Q3Q7/CallbackConvC posts its HUNGRY box only with NDRO along), and the 15 `battle_actions` stage actions decide fight-versus-box by companion (QA00 with NDKH, QD01-QD03 NDRO, the QK00/QU00 family NKHA/NSUN, Q3D3 NELI+NFLI; all 15 spot-audited against the Lua, both chain polarities). Only the Lua `return`-early-exit and the chains under untracked tests stay out of scope (GAPS row updated). All 34 suites pass, extractor/validator checks verified green.

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
- **Conversations:** 273 dialogue trees (233 `scriptcall` actions; no choice nodes in the data)
- **Conversation UI (NEW):** `bin/pq_conv_gfx.exe` — draws the backdrop full-window (dimmed), the current action's aspect-fit portrait and speaker name, word-wrapped dialogue and a skip button; clicks walk the action list; `gfx/conversation_layout.ml` holds 14 assertions over recovered coordinates; `--conv ID --shot [FILE]` photographs one frame as P6 ppm (default conv_shot.ppm). Images resolve from `game/Assets` (`PQ_GAME_ASSETS` overrides) with a `.png`/`.jpg` swap — the shipped backdrops are JPEGs — and missing art falls back to flat colours
- **Conversation callbacks (NEW):** each `scriptcall` action fires through `Campaign.execute_callback` — the body's extracted `callback_effects` apply first (quest-state writes, gold/XP/item/award/companion grants, nested conversations, `QUEST_COMPLETE` ending the quest through OnEnd exactly like a turn-in, `QUEST_MESSAGE` queues a modal box through `Campaign.pending_messages`, which `pq_conv_gfx` shows as a title/text/OK popup whose dismiss fires the box's callback), then the 13 conversation pairs inside the 33-row `callback_battles` table run their headless fight (stage, capture, spoils settle) and banner the outcome; a pair with neither effects nor battle answers `None`. Effects-before-battle matches the Lua body order (Q3D1/CallbackConvB writes state 5 before its fight, so the settle advances from 5)
- **Conversation triggers (NEW):** the quest engine queues conversation ids in `Campaign.pending_conversations` — `quest_accept` queues the OnBegin intro (first source-order site; Q3Q7's award branch keeps both trees, first wins), `enter_location` queues the arrivals attributed to their `(questState, idLocation)` guard (state `-1` = any stage), callbacks queue nested trees; `campaign_demo` prints the queue and `pq_conv_gfx` prompts it. The 94 `OnExecuteAction` and 50 `OnCompleteAction` sites now run through the location-action API below
- **Location actions (NEW):** the city-action flow a driver calls around dialogue and battles - `Campaign.query_actions` lists each active quest's first matching `OnQueryAction` label at a node (source order, `(questState, idLocation)` guards, `-1`/`""` = any), `execute_action` starts it (its conversation or message queues, state writes apply, and some actions turn the quest in on the spot - Q0I3 at stage 2), `complete_action ~success` runs `OnCompleteAction`'s outcome split, and `enter_location` fires guarded arrivals; every matching group runs in source order against the live state, so a body that writes `questState = 2` before a stage-2 `CompleteQuest` test completes in one call (Q0Q0, Q1G3 at CGAL). The 502 query rows, 48/180/382/143 enter/execute/complete/end groups and the OnEnd box at turn-in reconcile 1:1 with the Lua sites; `campaign_demo` walks Q0I2's whole chain; `test_location_actions.ml` (30) pins first-match, the outcome split, the live chains, arrivals, travel arrival through `advance_travel_with_events` and the queue. The map window's Actions tab and the shared `Conv_window` host this loop interactively
- **Global text (NEW):** `lib/text_data.ml` — 2,630 tags from the fifteen
  `English/*Text.xml` TextLibrary files; `Text_data.text` resolves a tag or returns
  it unchanged. Quest titles, city/item/monster/profession names now render as
  strings (`Family Reunion`, `Bartonia`, `Warrior`) instead of `[TAG]`.
- **Engine:** Player creation, travel (journey step: begin, advance, arrival, mount-shortened crossing, departure encounter roll), encounter triggering, city shops/income (buy at the registry cost, gold checked), level-up
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
  settle loop, both battle paths, the gates, the save and the offer.
  The map front now wires the win to the menu: `capture_offer` runs the
  same two gates (plus not-already-held and a resolvable sprite) over a
  won road encounter, and `pq_map_gfx` opens the minigame through
  `capture_begin` - `gfx/capture_layout.ml` places the 8x8 pad_grid, the
  [CAPTURE]/help lines and the give-up button; a terminal state takes one
  more click to run `capture_finish` (`port.capture_ui`).
  The other two surfaces follow (`port.capture_surfaces`): a won callback
  battle whose stage allows capture raises `cb_capture_offer` through
  `callback_capture_offer`, the conversation banner parks it, and the map
  takes it on dismiss (`Conv_window.take_capture_offer`) - quest fights in
  play are these callbacks, so they are covered without a quest-battle
  screen; and the city's Pets tab (`[PETS]` - Captives) lists
  `capture_candidates` (gates holding, not yet held) as click-to-play rows
  over the held captives. Win reads everywhere went to `Battle.hero_won`:
  `sweep_deaths` clears `is_dead` every pass, so the flag read as a loss
  for every real fight, and status-effect kills (poison, Fire Bombed,
  win reads through `Battle.hero_won` - the sweep clears `is_dead` every pass.
- **Runes & the forge (NEW):** `tools/extract_runes.py` pulls the three
  registries out of `Assets/Runes/Runes.xml` into `lib/campaign_runes.ml`
  - 15 base runes (slot position, the JXXX switch code, the base ability,
  a guarding monster and a map node), 10 modifiers carrying the forge
  arithmetic as plain fields, 13 powers carrying the item effect, and the
  150-row (base, modifier) name table. `player.runes` holds the
  collection; a fresh hero starts with the three gifted runes
  ([RUNESANDITEMS_HELP]), `claim_rune` gates a world rune on standing at
  its node, and `forge_rune` computes the spec exactly as each modifier's
  description states (base' = data x data_mult + data_add, power' likewise
  rounded nearest, difficulty stacking both diff fields -
  `port.rune_forge_formula`). What remains: the forged item in inventory
  and battle (JXXX's hooks), the SelectRuneMenu UI with its ten
  [FORGEITEMS_TARGET*] bands, and the runekeeper fight surface.
  The mint followed (`port.rune_item_mint`): `forge_item` adds the item to
  the inventory once (a duplicate triple yields no extra copy -
  [RUNEDUP_TEXT]), the loadout resolves minted ids into runtime items
  whose JXXX hooks ride the existing machinery - OnGiveDamage for bases
  0/1/9, per-item OnStartBattle payoffs for powers 0-4 in
  `Item_hooks.rune_start_payoffs` - and a save rebuilds a mint from its
  self-describing id ("R" ^ base ^ modifier ^ power) alone. JXXX's other
  bodies need machinery the port does not have (max-mana caps, a reflect
  outside the damage-transform signature, a per-event percentile, and the
  hook kinds battle never invokes) and stay quiet, the way [Item_hooks]
  documents the same absences for fixed items.
  The surfaces followed (`port.forge_ui`): the city's Forge tab picks the
  triple from the held runes and shows the `[FORGEITEMS_TARGET*]` band
  before the centred forge button (`forge_band`, ten equal sixty-point
  steps - the exe's thresholds are not recovered), and clicking the rune
  node you stand on opens the keeper popup - the guard monster under
  [RUNEKEEPER] - whose win claims the rune through `claim_rune`. The
  skill game `[FORGEITEMS_FAIL]` expects and the [FORGEITEMS_HELP0]
  building gate stay open.
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
- **Companion equip (NEW):** the party is the equipped subset of a recruited
  roster - `recruited_companions` keeps everyone ever granted,
  `RewardCompanion` fills both (the ninth is refused from the party only,
  `[COMPANIONSTATUS_NEW0]`), `RemoveCompanion` leaves the roster intact;
  `add_companion` rejoins them where they live (`companion_home`,
  `[COMPANIONSTATUS_OUT1]`'s home gate) and `remove_companion` is free
  anywhere (`[COMPANIONS_HELP]`); `companion_slot` reads
  Traveling/At_home/At_home_full/Away/Not_recruited for a driver; the save
  carries the roster separately (old saves default it to the party), and the
  map city panel's Companions tab (`[COMPANIONS]`, `[COMPANIONS_DETAILS]`)
  sorts the rows by status and a click leaves or picks up. The hooks follow
  the party, so the equip act gates the passive - no separate skill fold
  exists to invent, companions ship no skills of their own
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
  companion pass; `loadout_of_equipment` folds the eight-field character
  panel into the four battle slots by each item's own location, so a wall
  in the gauntlets field still wears the body slot.
- **Tests:** `test/test_campaign.ml` (223), `test/test_capture.ml` (84),
  `test/test_companion.ml` (77), `test/test_quest_battle.ml` (101),
  `test/test_callback_effects.ml` (24), `test/test_location_actions.ml` (30)
  and `test/test_runes.ml` (62) - 601
  assertions over prerequisites (every
  extracted condition), the accept -> battle -> turn-in lifecycle with real
  rewards, the both-endpoints road rule, the ruin registry (refcounts, shared
  ruins, the three release paths, the abandonable gate), capture grid parsing
  and charset, the no-refill settle loop on exact win/loss grids, defeat
  counting on the road and quest paths, the two capture gates, captives, save
  round-trips that diverge between save and load so a load that ignores the
  file cannot pass, every companion rule against the extracted data, the
  eight-slot party cap, a road battle whose log opens on the pre-battle
  hit, the quest-battle loop (stage picks the fight, per-stage capture
  flag, loss branches, settle driving the win bookkeeping), and the
  conversation triggers + callback effects (queue fill/drain, state writes,
  grants, completes, reattribution, effects-before-battle ordering), and the
  location-action flow (query first-match, execute/complete groups, live-state
  chains, arrivals, travel arrival through advance_travel_with_events, the
  message queue and the OnEnd box), and companion equip (roster vs party,
  the four refusals, the home gate, the hook following the party, the save
  keeping the roster separate).
- **Demo:** `bin/campaign_demo.exe` runs new game → map → roads → encounters → battle →
  quest accept (prints reveals) → a real quest battle through `run_quest_battle`
  (turns, life, winner, spoils, stage) → turn-in when the stage advanced → shop →
  income → level-up → companion equip (grant, leave, pick up at home) → save → load. Verified green 2026-10-10.

---

## Evidence & Documentation

| File | Claims | Questions | Decisions |
|------|--------|-----------|-----------|
| `docs/reverse/evidence.yml` | 90 | 10 (4 open) | 40 |

Key decisions recorded:
- `port.item_start_battle_dispatch` — items fire after companions, both sides, panel folds by item location
- `port.human_aim_click` — one click aims a spell (the bar cancels back to the spell question)
- `port.ai_aim_fallback` — hooks that store nothing aim at nothing; SCHG's row rides as y, the column slot0 as x
- `port.campaign_task_level` — road task is the encounter's my_level, quest task the monster's base; hero_level_cap stays default
- `port.map_screen_mapping` — the map fits the window whole; 16px click radius; 120 units/s walk
- `port.city_services` — buying checks gold against cost only; ShopMenu's rows and buttons reused; rumors in tag order
- `port.location_action_flow` - query is first match; execute/complete/enter apply every matching group live; the 3rd message arg is the display anchor
- `port.full_loop_map_actions` - the map Actions tab + travel arrivals + shared Conv_window host the location-event loop; complete_action stays caller-driven
- `campaign.companion_roster_equip` - equipping is party membership over a recruited roster; add at home, leave anywhere; the hooks are the passives
- `port.aim_hover_highlight` - hover lights the shape the spell reads (column/row/cell); all 64 cells stay valid, no filter
- `port.mount_travel_speed` - the chosen captive divides the road (1.5 slow / 2.0 average / 2.5 fast); `equipment.mount` stays an item slot
- `port.mount_skill_formula` - bonus = addstat + ((level - 1) / addlevel) * addperlevel on the combatant (never player.skills); mount_stat is skill_of_index; the mount spell is prepended to all three hero lists
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

# Run all tests (31 suites: 21 engine + 10 graphics)
opam exec -- dune runtest --force

# Campaign demo
opam exec -- dune exec bin/campaign_demo.exe

# Graphics battle (SDL2/OpenGL)
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_play_gfx.exe -- --demo 6

# World map (SDL2/OpenGL); --city opens the start city's panel
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_map_gfx.exe

# Conversation panel (SDL2/OpenGL); --conv picks the tree (Conv_ prefix optional),
# --shot [FILE] writes one frame as P6 ppm (default conv_shot.ppm) and exits;
# portraits/backdrops load from game/Assets (PQ_GAME_ASSETS overrides)
PQ_GFX_ASSETS=assets/gfx opam exec -- dune exec bin/pq_conv_gfx.exe -- --conv Q0I2a --shot
```

All 30 suites pass (exit 0, 2026-10-09). Extractor `--check` modes validate against
source assets.

---

## Next Milestones

| Priority | Area | Description |
|----------|------|-------------|
| **High** | **Ruin capture + companions** | Phase 3 landed: capture engine (grid, states, gates, captives, save) and companion hooks (ten OnStartBattle bodies, party dispatch, 8-slot cap, quest battles included, companion removal through enter_location); companion equip landed (roster + party, home-gated pickup, the map Companions tab) |
| **High** | **Campaign → Battle Integration** | **Landed:** `execute_callback` runs every scriptcall — extracted body effects first (state, grants, nested conversations, `QUEST_COMPLETE`), then the 33-row `callback_battles` table's fight; quest state queues the intro/arrival/nested conversations (`pending_conversations`). Landed further: the location-action flow (query/execute/complete/enter groups with live-state folds), the message popup (queue + conv-gfx modal), the map window's Actions tab, travel arrivals through `advance_travel_with_events`, and the shared `Conv_window` that opens queued trees over the map. Still open: the two callback-site `QUEST_REMOVE_COMPANION` removals |
| **Medium** | **World Map Rendering** | SDL2 map view: nodes, roads, hero marker, fog-of-war (visibility flags now exist) |
| **Medium** | **Grid Spell Targeting** | Landed: hover lights the shape the spell reads (column/row/cell via `Layout.aim_cells`), the HUD prompt says aim, click-to-aim was already wired; `fx.ml`'s `play_for_fx` still skips `target = Grid` calls - their cells arrive through `on_grid_fx`, by design (`port.grid_effects_are_an_observer_not_an_event`) |
| **Medium** | **City UI** | Shop buy/sell, spell learning, tavern rumors, and the Companions tab (leave/pick up); a dedicated hero screen and captive teaching remain open |
| **Medium** | **Companions / Mounts** | Companion equip landed (roster/party + the ten hooks as the passives), mount speed landed (the chosen captive divides the road, tiers 1.5/2.0/2.5) and mount combat bonuses landed (skill bonus on the combatant, the mount spell in all three battle paths); mount training/encounter avoidance and banner effects remain open |
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

1. **Campaign → Battle Integration** — landed: `pq_conv_gfx` walks the actions and hands each `scriptcall` to `execute_callback`, which applies the body's extracted effects first (state writes, grants, nested conversations, `QUEST_COMPLETE` = OnEnd) and then runs the 33-row table's fight behind an outcome banner; quest state queues conversations (`pending_conversations`: OnBegin intros, guarded arrivals, nested trees — printed by the demo). The location-action flow and the message popup are landed (`query_actions`/`execute_action`/`complete_action`/`enter_location` with live-state groups, `pending_messages`, the conv-gfx modal box, `test_location_actions.ml`); the map window's Actions tab, travel arrivals through `advance_travel_with_events`, and the shared `Conv_window` that opens queued trees over the map are landed (`start_conversation` as a direct API remains unused).
2. **Companion edges** — arrival removal is extracted and run (`enter_location`, six rules; the Q3Q5/QU02 callback sites have no arrival event to run under; travel arrival now runs `enter_location` through `advance_travel_with_events`); the rune's `OnStartBattle` waits on the forge's rune state; companion equip landed (roster + party, home-gated pickup, map Companions tab)
3. **Fog of war / visible range** — visibility flags exist and save correctly, and the map window now draws the hero's position (current node, or on the road); still open is visible-*range* logic - recomputing what the hero can see from where they stand - and fog painting
4. **Spell targeting** — both halves wired: the player aims from the cast question (click / `b3`, `choose_aim` -> `fx_input`) and the six hooks' `SET_INPUT_DATA` picks land for machines too (`ctx_aim`, cleared per candidate); hover and the shape highlight landed (`Layout.aim_cells`, the play front's first `mouse_motion` handler, the HUD aim prompt); SFOD/SSPA/SPRO aim at nothing when the machine casts them, since their hooks store no cell (`port.ai_aim_fallback`)
5. **Monster spell rosters** — quest and road fights both load the monster's registry `Spell` tags now; mana-aware dynamic selection and any weighting of spell choice beyond each hook's own board reads remain open
6. **Conversation branching** — wired: `pq_conv_gfx` walks the `talk_*/wait/end/scriptcall` actions with the speaking character's portrait and name (the data ships no choice nodes, so there is nothing to branch on), and quest state now queues trees (`pending_conversations`: intros, arrivals, nested callback trees); the map window's shared `Conv_window` now opens those queued trees over the map, and the Actions tab drives the location-action flow
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
  campaign.ml              # Engine core: prerequisites, quest lifecycle, visibility, execute_callback,
                             # pending conversation/message queues, location-action flow
                             # (query/execute/complete/enter + end at turn-in), per-callback effects,
                             # travel arrivals (advance_travel_with_events), companion equip
                             # (recruited roster + traveling party, home-gated pickup)
  campaign_map.ml          # 20 cities, 40 waypoints, 28 ruins, 93 roads
  campaign_encounters.ml   # 57 encounters (my_level, chance)
  campaign_quests.ml       # 142 quests + per-quest text + extracted rewards/reveals + conversations
                             # + callback_effects + callback_battles + query/enter/execute/complete/end groups
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
  extract_quests.py        # XML + static Lua scan (QUEST_* calls, rewards, reveals, conversations,
                             # per-callback effects, callback battles)
  extract_items_professions_monsters.py
  extract_conversations.py
  extract_companions.py    # Companion XML + OnStartBattle flag
bin/
  campaign_demo.ml         # Playable loop with save/load
  pq_conv_gfx.ml           # Thin front over gfx/conv_window (standalone conversation tester)
gfx/
  conversation_layout.ml   # Pure geometry + 14 assertions; --conv --shot
  conv_window.ml           # Shared conversation/message/battle window (map + pq_conv_gfx)
```
