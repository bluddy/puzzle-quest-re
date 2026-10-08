# Puzzle Quest — Gap Analysis: Current vs. Complete Game

## What We Have (✅ Working)

| Layer | Components |
|-------|------------|
| **Battle Core** | Board, gems, matches, cascades, gravity, refill, combat stats, mana, damage, status effects |
| **Spells** | 130 spells ported; 11 with 13 grid-effect calls (`Std_GridSpellEffect`) |
| **Spell Effects** | 21 caster/grid FX, 22 sounds, 24 constants; particle system (6 textures, gravity/velocity/color/size, additive/alpha) |
| **Animation** | Per-gem pop (fade/shrink), column-bottom-up fall, entrant slide; `Battle.on_step` observer |
| **Sound** | Cascade steps, spell sounds via `Spell_fx.calls_of_spell`, `Audio.play_all` fixed |
| **Text** | 10 bitmap fonts, float-text messages, bounded stack |
| **Write-back fix** | Spell board/gold/XP edits persist |
| **Tests** | 4 suites (battle, spell_fx, spell_effects, gfx_fx) — all green |

| Campaign Data (extracted) | Count |
|---------------------------|-------|
| Cities / Waypoints / Ruins / Roads | 20 / 40 / 28 / 93 |
| Encounters | 57 (with `my_level`, `chance` from Lua) |
| Quests | 142 (state machines, localized text, battle rewards) |
| Items / Professions / Monsters | 160 / 4 / 60 (with capture grids) |
| Conversations | 273 (backdrops, portraits, branching) |

| Campaign Engine | Status |
|-----------------|--------|
| Player creation, skills, level-up, spells | ✅ |
| Map graph, travel, encounter triggering | ✅ |
| Quest state machine (Inactive→Active→Completed/Failed) | ✅ |
| Quest lifecycle (accept → battle → turn-in, prerequisites, rewards) | ✅ |
| Map visibility (quest reveals, road rule, save/restore) | ✅ |
| Global text (2,630 tags — names render, not `[TAG]`) | ✅ |
| City shops, spells, income | ✅ |
| Save/Load (JSON round-trip, live map state + awards) | ✅ |
| Ruin registry (refcounts, hook-bucketed releases, save) | ✅ |
| Capture (grid, settle, gates, captives, save) | ✅ |
| Companion hooks (ten `OnStartBattle` bodies, party dispatch, 8-slot cap) | ✅ |

---

## What's Missing (🔴 Gaps to Complete Game)

### 1. Quest System — Prerequisites & Branching
| Gap | Details |
|-----|---------|
| ~~Prerequisite checks~~ | ✅ `donequest0/1/2`, `notdonequest`, `notactivequest`, `companion0/1`, `notcompanion`, `item`, `notitem`, `award`, `notaward` all wired in `is_quest_available` |
| ~~Quest rewards~~ | ✅ gold/XP/items/awards/companions from the quest script (`run_quest_on_end`), not the 200/200 default |
| ~~Quest failure paths~~ | `quest_abandon` runs OnAbandon (releases + state reset) and respects the `abandonable` flag; `run_quest_on_fail` still has no caller — no OnFail hook |
| Conversation callbacks | `CallbackConv*` grants (item/award/companion/xp) are applied at turn-in rather than at the dialogue; `QUEST_REMOVE_COMPANION` sites inside callbacks (Q3Q5, QU02) have no arrival event to run under |

### 2. Ruins & Companion Capture
| Gap | Details |
|-----|---------|
| ~~Ruin registration~~ | ✅ refcount table (`register_ruin` / `set_ruin_done`): shared ruins hold until every quest releases; releases bucketed by hook (battle / turn-in / abandon), saved and restored |
| ~~Ruin mini-game~~ | ✅ `lib/capture.ml`: grid parse, no-refill settle, win/lose, auto-play; gates, captives and save in `campaign.ml` |
| ~~Quest battle capture flag~~ | `QUEST_BATTLE` passes capture=1 and `QUEST_BATTLE_NOCAPTURE` capture=0 to `QUEST_ENCOUNTER_ADD`; the stage's own primitive now decides capture (primitive over the Lua string check), so a quest kill of a non-capturable variant no longer counts |
| Companion system | Party hooks ✅ (`OnStartBattle` rule table, party dispatch, 8-slot cap); `QUEST_REMOVE_COMPANION` arrival rules run through `enter_location` (six: Q3S0 x5, QS00 x1); companion equipping and the two callback-site removals (Q3Q5, QU02) still open; the rune's start hook waits on the forge |
| Ruin visibility | Ruins reveal through `ruin_reveals` at quest accept; no unlock-by-city-entry |

### 3. Map Progression & Visibility
| Gap | Details |
|-----|---------|
| ~~Road unlock~~ | ✅ `set_location_visible` applies the recovered both-endpoints rule; reveals from extracted `QUEST_SET_VISIBILITY` / `QUEST_ADD_RUIN` calls, saved and restored |
| Ruin visibility | Ruins reveal via `ruin_reveals`; no unlock-by-city-entry logic |
| Fog of war | Visibility flags exist and save; no hero position on the map, no visible-range logic |

### 4. Spell Targeting (Grid Spells)
| Gap | Details |
|-----|---------|
| Nine input spells | ✓ six grid (SCON, SFBA, SFOD, SPRO, SSPA, STHR), two column (SCLI, SLIS), one row (SCHG); the aim reaches the body through `choose_aim` -> `fx_input`, and each reader no-ops on `None` |
| UI | ✓ cell selection landed (`Input.in_target_prompt`: aim, bar-cancel, miss; the console asks for `b3`-style cells); hover cursor and valid-target highlighting still open (cosmetic) |
| AI | ✓ the six hooks' `SET_INPUT_DATA` picks are ported (`ctx_aim`, cleared per candidate, read into `fx_input`); SFOD/SSPA/SPRO store nothing and so aim at nothing (`port.ai_aim_fallback`) |

### 5. Monster AI & Spell Rosters
| Gap | Details |
|-----|---------|
| Dynamic spell selection | Quest and road fights both load the static `Spell` tags now; still no mana-aware choice |
| AI weights | `Ai.weights` exist but only used for swap evaluation, not spell choice |
| Difficulty scaling | ✓ campaign fights compute `rules.difficulty` from the recovered bands (`rules_for_battle`: road my_level, quest level_base) - gates the spell skip and the evaluator jitter |

### 6. Conversation System
| Gap | Details |
|-----|---------|
| Branching dialogues | `Action.type` = `talk_youngmale`/`oldmale`/`youngfemale`/`oldfemale`/`wait`/`end`; no choice nodes |
| Quest integration | Conversations triggered by quest state; no `Conversation` → `Quest` hooks |
| Portrait/backdrop rendering | Assets extracted; no SDL2 rendering |

### 7. World Map UI (SDL2)
| Gap | Details |
|-----|---------|
| Map rendering | No node/road drawing, no hero marker, no fog-of-war overlay |
| Travel UI | No path selection, no travel animation, no encounter popup |
| City entry | No city screen, no shop UI, no tavern/rumors |

### 8. City Services UI
| Gap | Details |
|-----|---------|
| Shop buy/sell | Item list shown in demo; no transaction logic, no gold check, no inventory add |
| Spell learning | City spells listed; no learn action, no gold/mana cost |
| Companion management | No party screen, no equip/unequip companion |
| Tavern rumors | `Rumors` XML extracted; no rumor display |

### 9. Equipment & Inventory
| Gap | Details |
|-----|---------|
| Equip logic | `equipment` record exists; no `can_equip` checks, no stat bonuses applied |
| Item effects | Damage hooks fold in battle; `OnStartBattle` wired for the six items (`campaign.item_start_battle`, rune JXXX waits on the forge); the mana/gold/xp, start-turn, match and victory hooks are still never invoked |
| Inventory limits | No capacity, no sorting, no discard |

### 10. Companion / Mount System
| Gap | Details |
|-----|---------|
| Party slots | `companions: string list` with the recovered 8-slot cap (`RewardCompanion` dedups, ninth refused); `RemoveCompanion` drops by id and the arrival rules run through `Campaign.enter_location` (no travel step calls it yet); no swap/remove UI |
| Mount | `mount` equipment slot exists; no speed/fly logic, no banner effects |
| Capture flow | Engine side done (eligibility, begin/finish, captives, save); no encounter UI wiring a battle win to the capture menu |

### 11. Character Creation
| Gap | Details |
|-----|---------|
| Class selection | 4 professions extracted; no creation screen |
| Sex/age/portrait | Portraits extracted per class/sex/age; no selection UI |
| Starting stats | `profession.starts` used; no customization |

### 12. Game Flow / Menus
| Gap | Details |
|-----|---------|
| Main menu | New Game / Load Game / Options / Credits |
| Pause menu | Resume / Save / Load / Options / Quit |
| Options | Volume, key remap, color-blind, UI scale |
| Save slots | Multiple save files, metadata preview |

### 13. Graphics Battle (SDL2/OpenGL)
| Gap | Details |
|-----|---------|
| Full battle view | `pq_play_gfx` exists but minimal; no HUD, no spell list, no mana bars |
| Grid spell UI | No cell selection, no preview |
| Spell list UI | No castable-spell panel, no cost display, no cooldown display |
| Combat log | Float-text exists; no persistent log panel |

### 14. AI Overhaul
| Gap | Details |
|-----|---------|
| Gem evaluation | Current: first legal swap; need mana-need weighting, cascade setup, skull denial |
| Spell priority | Need affordability check, effect-value estimation, keeps-turn prediction |
| Cascade planning | Multi-step lookahead (2-3 swaps) |

---

## Priority Order (Suggested)

| Phase | Focus | Rationale |
|-------|-------|-----------|
| **1 ✅** | Quest prerequisites + rewards | Unlocks map progression, makes quests meaningful |
| **2 ✅** | Map visibility + road/ruin unlock | Gives purpose to quests, opens world |
| **2 ✅** | Global text tables | Names render as strings; blocks every UI otherwise |
| **3 ✅** | Capture engine ✅ + companion hooks ✅ | Core progression loop (capture → party → bonuses); equip bonuses remain in 8 |
| **4 ✅** | Campaign tests | The new lifecycle/visibility logic is verified only by demo output |
| **5 ✅** | Grid spell targeting | Player aim (click-to-aim) and machine aim (six hook picks) both land; `spell.sfba_target_writeback` settled |
| **6 ✅** | Monster spell AI + difficulty | Road rosters load; campaign fights compute their band from the levels |
| **7** | World map SDL2 + travel UI | Makes campaign playable visually |
| **7** | City UI (shop, spells, tavern) | Completes town loop |
| **8** | Conversation branching + portraits | Narrative delivery |
| **8** | Equipment/item effects + mount | Stat progression depth |
| **9** | Character creation + main menu | Polish for "game" feel |
| **10** | Full graphics battle + AI overhaul | Competitive AI, visual polish |

---

## Quick Wins (Can land this week)

1. ~~**Quest prerequisite checks**~~ ✅ wired to `is_quest_available`
2. ~~**Road/ruin unlock on quest complete**~~ ✅ reveals from extracted `QUEST_SET_VISIBILITY` / `QUEST_ADD_RUIN`
3. ~~**Global text tables**~~ ✅ `lib/text_data.ml`, 2,630 tags, `test_text_data`
4. ~~**Campaign tests**~~ ✅ `test_campaign.ml` — prerequisites, quest lifecycle, visibility reveal, ruin registry, save round-trip (112 assertions)
5. ~~**Ruin capture board**~~ ✅ `lib/capture.ml` + campaign gates/captives/save (57 assertions); success adds the captive
6. **Companion equip** — add `companion` slot to equipment, apply monster skills as passive bonuses
7. **Mount speed** — `mount` slot → modify travel time between nodes
8. **Grid spell cell selection** — mouse hover → highlight valid cells; click → pass cell to `Std_GridSpellEffect`

---

## Evidence / Documentation Gaps

| File | Needs |
|------|-------|
| `evidence.yml` | ✅ `campaign.map_visibility`, `campaign.quest_rewards_conditional`, `campaign.global_text_tables`, `campaign.ruin_registry`, `campaign.capture_eligible`, `campaign.capture_board`, `campaign.companion_start_battle`, `port.companion_hooks_fire_for_the_party`, `campaign.quest_battle_flow`, `port.quest_battle_loop`, `campaign.quest_remove_companion`, `spells.input_aim`, `port.human_aim_click`, `spells.ai_aim`, `port.ai_aim_fallback`, `campaign.battle_setup`, `port.campaign_task_level`; still to add: monster AI |
| `graphics_plan.md` | Phase 4: world map rendering, city UI, conversation UI |
| `README.md` | Update "What works" with Save/Load, Quest/Map gaps |
| `tools/graphics_plan.md` | Add phases for city UI, world map, conversation UI |

---

## File Index (Current)

```
lib/
  board.ml                 # 8×8 board, matches, gravity, refill
  combat.ml                # combatant, skills, mana, status effects
  battle.ml                # battle loop, spells, cascades, observers
  spell.ml                 # spell descriptors, costs, AI hooks
  spell_effects.ml         # 130 spell bodies (ported from Lua)
  spell_fx.ml              # 21 FX assets, 22 sounds, 24 constants
  fx_data.ml / gfx/fx.ml   # particle system (keyframe interp, blending)
  campaign.ml              # engine: player, map, travel, encounters, quests
  campaign_map.ml          # 20 cities, 40 waypoints, 28 ruins, 93 roads
  campaign_encounters.ml   # 57 encounters (my_level, chance)
  campaign_quests.ml       # 142 quests (state machines, text)
  campaign_items.ml        # 160 items
  campaign_professions.ml  # 4 classes (skills, spells, XP)
  campaign_monsters.ml     # 60 monsters (capture grids)
  campaign_conversations.ml# 273 dialogues
  campaign_companions.ml   # 10 companions (text tags, home, hook flag)
  campaign_companion_hooks.ml # hand-ported OnStartBattle rule table
  campaign_types.ml        # shared type aliases
  campaign_save.ml         # JSON save/load (live map state + awards)
  text_data.ml             # global TextLibrary, 2,630 tags
  ai.ml / score.ml         # swap evaluation, board scoring
tools/
  extract_campaign_map.py
  extract_encounters.py
  extract_quests.py        # XML + static Lua scan
  extract_items_professions_monsters.py
  extract_conversations.py
  extract_companions.py    # companion XML + OnStartBattle flag
  extract_spell_fx.py
  extract_fx_data.py
  extract_skin_data.py
  extract_fonts.py
  extract_text_tables.py
bin/
  campaign_demo.exe        # playable loop + save/load
  pq_play_gfx.exe          # SDL2/OpenGL battle (minimal)
  pq_play.exe / pq_battle.exe # ASCII battle runners
```

---

## Next Action

Phases 1, 2, 3 and 4 are landed (prerequisites, rewards, visibility, text,
campaign tests, capture, companion hooks, quest battle loop, item start
hooks, companion removal, cell selection, AI aiming, monster rosters). Pick one:

- **Campaign tests (rest)** — travel, encounter triggering, income and
  level-up; the rest of Known Gap 1