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
| City shops, spells, income | ✅ |
| Save/Load (JSON round-trip) | ✅ |

---

## What's Missing (🔴 Gaps to Complete Game)

### 1. Quest System — Prerequisites & Branching
| Gap | Details |
|-----|---------|
| Prerequisite checks | `donequest0/1/2`, `notdonequest`, `notactivequest`, `companion0/1`, `notcompanion`, `item`, `notitem`, `award`, `notaward` all stubbed |
| Quest availability | Level range works; all other conditions return `true` |
| Quest rewards | Only gold/XP; no item/award/companion grants |
| Quest failure paths | `OnComplete(success=0)` only does `FailQuest`; no `OnFail` hook |

### 2. Ruins & Companion Capture
| Gap | Details |
|-----|---------|
| Ruin mini-game | 8×8 capture grids extracted per monster; no board logic, no capture attempt flow |
| Companion system | Monster `capture` grids extracted; no party slots, no companion equipping, no companion bonuses |
| Ruin visibility | Ruins have `visible="no"` + `attach` city; no unlock logic |

### 3. Map Progression & Visibility
| Gap | Details |
|-----|---------|
| Road unlock | Roads have `visible="no"`; no quest-triggered reveal |
| Ruin unlock | Ruins attach to cities; no unlock via quest completion |
| Fog of war | No hero position tracking on map; no visible-range logic |

### 4. Spell Targeting (Grid Spells)
| Gap | Details |
|-----|---------|
| 11 spells × 13 calls | `SBAC`, `SBSG`, `SCON`, `SFOD`, `SHGO`, `SSHO`, `SSPA`, `SSTU`, `STHR`, `SWMG`, `SWTd` |
| UI | No cell selection cursor; no valid-target highlighting; no cancel |
| AI | Cannot cast grid spells (no targeting logic) |

### 5. Monster AI & Spell Rosters
| Gap | Details |
|-----|---------|
| Dynamic spell selection | Monsters only use static `Spell` tags from XML; no mana-aware choice |
| AI weights | `Ai.weights` exist but only used for swap evaluation, not spell choice |
| Difficulty scaling | `rules.difficulty` unused in spell selection |

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
| Item effects | `Item.onGiveDamage` etc. extracted; no hook integration in battle |
| Inventory limits | No capacity, no sorting, no discard |

### 10. Companion / Mount System
| Gap | Details |
|-----|---------|
| Party slots | `companions: string list` exists; no max size, no swap UI |
| Mount | `mount` equipment slot exists; no speed/fly logic, no banner effects |
| Capture flow | No ruin encounter → capture board → success/fail → add to party |

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
| **1** | Quest prerequisites + rewards | Unlocks map progression, makes quests meaningful |
| **2** | Map visibility + road/ruin unlock | Gives purpose to quests, opens world |
| **3** | Ruin capture + companion system | Core progression loop (capture → party → bonuses) |
| **4** | Grid spell targeting UI | Required for 11/130 spells; enables AI spell casting |
| **5** | Monster spell AI + difficulty | Makes encounters distinct, scales with level |
| **6** | World map SDL2 + travel UI | Makes campaign playable visually |
| **6** | City UI (shop, spells, tavern) | Completes town loop |
| **7** | Conversation branching + portraits | Narrative delivery |
| **7** | Equipment/item effects + mount | Stat progression depth |
| **8** | Character creation + main menu | Polish for "game" feel |
| **9** | Full graphics battle + AI overhaul | Competitive AI, visual polish |

---

## Quick Wins (Can land this week)

1. **Quest prerequisite checks** — wire `donequest*`, `companion*`, `item`, `award` to quest availability
2. **Road/ruin unlock on quest complete** — `OnComplete(success=1)` → set `visible=true` on attached roads/ruins
3. **Ruin capture board** — reuse `Board` + `Battle` with capture grid as initial state; success → add monster to companions
4. **Companion equip** — add `companion` slot to equipment, apply monster skills as passive bonuses
4. **Mount speed** — `mount` slot → modify travel time between nodes
5. **Grid spell cell selection** — mouse hover → highlight valid cells; click → pass cell to `Std_GridSpellEffect`

---

## Evidence / Documentation Gaps

| File | Needs |
|------|-------|
| `evidence.yml` | Add claims for: quest prerequisites, ruin capture, map visibility, grid spell targeting, monster AI |
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
  campaign_types.ml        # shared type aliases
  campaign_save.ml         # JSON save/load
  ai.ml / score.ml         # swap evaluation, board scoring
tools/
  extract_campaign_map.py
  extract_encounters.py
  extract_quests.py
  extract_items_professions_monsters.py
  extract_conversations.py
  extract_spell_fx.py
  extract_fx_data.py
  extract_skin_data.py
  extract_fonts.py
bin/
  campaign_demo.exe        # playable loop + save/load
  pq_play_gfx.exe          # SDL2/OpenGL battle (minimal)
  pq_play.exe / pq_battle.exe # ASCII battle runners
```

---

## Next Action

Pick **one** from Phase 1:
- **Quest prerequisite checks** (unlocks map progression)
- **Road/ruin unlock on quest complete** (gives quests purpose)

Which do you want to tackle first?