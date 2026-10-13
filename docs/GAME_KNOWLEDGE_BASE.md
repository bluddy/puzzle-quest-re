# Puzzle Quest: Game Knowledge Base, Mechanics & Engine Architecture

This document synthesizes verified gameplay mechanics, engine rules, data schemas, and memory structures for *Puzzle Quest: Challenge of the Warlords*.

---

## 1. High-Level Game Flow & Architecture

### Main Menu
* **Modes**: New Quest, Continue Quest, Single Player (Instant Action), Multiplayer (LAN / Direct IP / Internet), Settings, High Scores, Multiplayer High Scores.
* **New Quest** and **Continue Quest** drop you straight into the game.
* **Single Player** opens the hero view first, where two things are chosen separately from the hero: the **turn Time Limit** (`drop_timelimit`, rows `[TIMELIMIT0..4]`) and the **Difficulty** (`drop_difficulty`, rows `[AILEVEL0..2]`). That screen's menu then offers **Quest**, **Instant Action**, **Choose Opponent**, **Your Citadel**, **Shop**, **Create Hero** and **Delete Hero**; **Quest** starts the game proper.
* **Hero Selection**:
  * Four Core Classes: **Druid**, **Knight**, **Warrior**, **Wizard**.
  * Each class has specific initial attribute distributions, mana growth curves, and spell learning tables.

### Difficulty (the `m_difficulty` setting)
* Three rows, chosen per game in the single-player hero view: `[AILEVEL0]` **"Easy (-25% XP)"**, `[AILEVEL1]` **"Normal"**, `[AILEVEL2]` **"Hard (+25% XP)"**. The choice is advertised as an experience modifier as well as an AI strength.
* Kept machine-wide, not per hero: the registry value `Difficulty` under `Software\Infinite Interactive\Puzzle Quest`, written back beside `Time Limit` (the two settings sit next to each other in the settings object, `+0x74` and `+0x70`, Difficulty defaulting to `1` = Normal). Battle start copies it into `CBattleManager.m_difficulty` at `+0x48`.
* It gates the AI's spell skip (50 % / 25 % / 0 % of candidates skipped at Easy / Normal / Hard), the board evaluator's jitter (`±50` always at Easy, `±20` on 40 % of matches at Normal, never at Hard, plus a hero-level band that Hard ignores) and the score and payout scaling on the results screen.
* **Where the ∓25 % XP is applied is not yet located** (`xp.difficulty_scaling` in `docs/reverse/evidence.yml`): the one difficulty-scaled XP writer found is `FUN_0043E400` (`*3/4` at Easy, `*5/4` at Hard - exactly the advertised amounts), called by the results screen on the branch gated by `turn_manager+0x30`.
* `Std_GetDifficulty(heroLevel, taskLevel)` in `StandardUtilityScripts.lua` is a five-band level-gap helper with **no callers anywhere** in the shipped corpus or the exe, and the quest scripts' `OnQueryDifficulty` - a constant `0..4` in all 142 quests - feeds only the opponent panel's `[OPPDIFFICULTY0..4]` pips. Neither sets the battle's difficulty.

### The battle AI, in the author's own words
From an interview with the developer who scripted the game's AI:
* **It does not cheat and does not look ahead.** Every available move is scored 0-100 on what it yields *immediately*; spells are scored the same way and the best is taken. On **Hard** it always picks the best, on **Normal** one of the top 10 %, on **Easy** one of the top 50 %.
* **Scores are biased slightly higher toward the bottom of the board**, because matching lower down tends to open more cascade possibilities.
* Against the recovered code (`docs/BATTLE_AI.md`, `docs/reverse/evidence.yml`):
  * the bottom bias is real and is the anchor's **row**, not its column - `CBoard_CheckMatch` stores `(x, y)` and `BattleAI_ScoreMatchResult` adds the `y`, one point per row (`ai.anchor_term_is_the_row`);
  * the difficulty percentages are realised as **score jitter** rather than a top-N pick - `±50` at Easy, `±20` on 40 % of matches at Normal, none at Hard (`ai.difficulty_is_the_player_option`);
  * and the spell loop does **not** take the highest-scoring spell: `BattleAI_PickSpell` (`0x440FB0`) walks the roster in order, applies the difficulty-gated skip, and takes the **first** hook that returns non-zero, which is the port's `pick_ai_spell`. The interview's "score them all, take the best" is the simplification; the decompile is the authority.

### World Map & Exploration Graph
* **Graph Structure**: Nodes represent Cities, Ruins, Dungeons, and Shrines connected by bidirectional Road edges (defined in `Assets/Cities/Roads.xml`).
* **Graph Navigation**: Clicking an unvisited or remote location triggers pathfinding along the edge network (`QUEST_MOVE`, `QUEST_STOP_MOVEMENT`).
* **Random Encounters**: Movement along roads can trigger monster encounters (`QUEST_ENCOUNTER_ADD`, `QUEST_ENCOUNTER_BATTLE`, `QUEST_ENCOUNTER_TURNBACK`, `QUEST_ENCOUNTER_CONTINUE`).

### Location Options & The Citadel
When visiting a city or Citadel (the player's home base):
* **Citadel Rooms & Upgrades** (purchased with Gold):
  * **Dungeon**: Holds captured monsters (unlocked after defeating that monster type 3+ times).
  * **Mage Tower (Spell Research)**: Learn spells from captured monsters via a board-clearing match-3 puzzle mini-game.
  * **Stables (Mount Training)**: Train captured mounts to level them up via a timed/turn-limited puzzle mini-game.
  * **Forge**: Craft custom magic equipment using combinations of Runes (Base + Modifier + Power).
* **Tavern**: Purchase rumors for lore, clues, and unlocking optional quest locations (first rumor is free, subsequent ones cost Gold).
* **Shop**: Buy equipment (Weapons, Armor, Helmets, Rings) gated by Gold cost and minimum skill level requirements.
* **Get Quests**: Choose active quests (`QUEST_IS_ACTIVE`, `QUEST_COMPLETE`, `QUEST_COMPLETE_PART`).
  * Story quests are highlighted in red (mandatory progression).
  * Side quests provide extra Gold, XP, Runes, and Companions.

### Hero Inventory & Management
The Hero management screen (`Assets/Screens/HeroDetailsMenu.xml`, `ManageHeroMenu.xml`) features tabs:
1. **Magic Items**: Equipped gear (Head, Weapon, Armor, Misc) and inventory bag.
2. **Spells**: Grimoire of learned spells; **up to 7 spells** can be equipped for combat.
3. **Companions**: Recruited story NPCs granting unique passive bonuses in battles or exploration.
4. **Captives**: Monsters imprisoned in the Citadel dungeon for spell research.
5. **Mounts**: Trained beast mounts providing mobility and special combat abilities.
6. **Cities**: Conquered/sieged cities paying regular Gold tributes.
7. **Rumors & Lore**: Collected rumors.
8. **Victories & Awards**: Trophies and special quest completions (`QUEST_HERO_HAS_AWARD`).

---

## 2. The Seven Core Attributes
1. **Earth Mastery**: Starting earth mana, max earth mana cap, earth mana surge chance, resistance to earth spells.
2. **Fire Mastery**: Starting fire mana, max fire mana cap, fire mana surge chance, resistance to fire spells.
3. **Water Mastery**: Starting water mana, max water mana cap, water mana surge chance, resistance to water spells.
4. **Air Mastery**: Starting air mana, max air mana cap, air mana surge chance, resistance to air spells.
5. **Battle**: Increases damage dealt by Skulls and weapon attacks.
6. **Morale**: Increases maximum Life (HP) and resistance to all spell elements.
7. **Cunning**: Determines turn initiative (who moves first); increases starting gold/wildcard chances; contributes to enemy capture.

*All skills are stored consecutively from `+0x48` to `+0x60` in `CCharacter` and are capped at **999**.*

---

## 3. Match-3 Combat Mechanics

### Grid Structure
* $8 \times 8$ active battle grid ($x \in [0..7], y \in [1..8]$).
* Buffer row $y = 0$ at the top for newly generated falling gems.

### Battle screen layout (`Assets/Screens/GameMenu.xml`)
The battle screen is declared widget by widget, and every rectangle below is transcribed into `gfx/battle_layout.ml` (pinned by `test/test_gfx_battle_layout.ml`):
* **Board**: `pad_grid` 584x584 at (217,130) - eight 73px cells - inside `icon_grid` (212,45) 600x680; the fight's title `str_battlename` is 512x25 at (256,95).
* **Character pads**: `pad_gamechar0/1` 180x348 at (11,119) and (835,119), with portrait art `img_gamechar0/1` (180x320) over them and `icon_enemylifepts` - the life bar, 175x18 at (837,121) - inside the enemy's.
* **Spell pads**: seven per side, 178x37 from y=462 stepping 41 (a 4px gutter), at x=11 and x=835; the seventh ends at y=745, three pixels off the screen.
* **Turn plates**: `icon_ltimebg`/`icon_rtimebg` 90x90 at (135,16)/(784,16), carrying `str_ltime`/`str_rtime` (each side's time limit - the countdown `drop_timelimit` chooses).
* **Missed-turn badges**: `icon_missturn0/1` 90x24 at (53,100)/(876,100); the art is `img_missturn_1..5` in `Skin_Battle_Misc`.
* **Turn line**: `str_turn` 124x18 at (450,736) - centred. `SidePanels.xml` adds the two 176-wide sliding panels.
* The port draws these as they are; its own additions are the four mana bars per panel and a combat log under the board, and it centres its board on the gem sheet's 71px cells instead of pinning the 584 pad (`port.battle_screen_layout`).

### Gem Types & Matching Effects
* **Elemental Gems (Green, Red, Blue, Yellow)**: Add mana to the respective elemental pool.
* **Coins (Gold)**: Awards Gold directly to player reserves (capped at 99,999).
* **Purple Stars (Experience)**: Awards XP (capped at 99,999 in battle).
* **Skulls**: Deals physical damage equal to base skull count + Battle attribute bonuses and active equipment/companion multipliers.
* **+5 Skulls (Heavy/Explosive Red Skulls)**:
  * Deals 5 base damage + regular skull damage.
  * **Explosion Radius 1**: Explodes all tiles in its $3 \times 3$ vicinity ($\Delta x, \Delta y \in \{-1, 0, 1\}$).
  * **Full Harvest**: Destroys all blocks in the explosion radius, collecting their full benefits (damage from skulls, elemental mana, gold from coins, XP from stars).
* **Wildcards / Multipliers (x2, x3, x4, etc.)**: Can substitute for any mana gem; multiplies resulting mana or damage.

### Turn & Move Resolution
* **Turn Sequence**: Alternate turns between Player and Opponent.
* **4-of-a-Kind**: Destroys the 4 gems, awards standard yields, and grants an **Extra Turn** (`EXTRA_TURN`).
* **5-of-a-Kind**: Clears matched gems, creates a **Wildcard gem**, and grants an **Extra Turn**.
* **Heroic Effort (Cascade Chain ≥ 5)**:
  * Achieving a chain reaction of **5 or more consecutive cascade matches** from a single swap (falling gems creating successive matches) triggers a **Heroic Effort**!
  * Awards: **+100 Experience Points (XP)** and grants an **Extra Turn**.
* **Illegal Move Penalty**:
  * An invalid swap (does not produce a match-3+) snaps back.
  * In combat with `SET_ILLEGAL_MOVE_DAMAGE_ENABLED` active: deals **5 points of damage** to the moving combatant and forfeits the turn!
* **Mana Burn (No Available Moves)**:
  * When no legal swaps exist on the board for the active combatant, **Mana Burn** occurs.
  * **Both players lose all their stored elemental mana** (Air, Earth, Fire, and Water pools drop to 0).
  * The board is automatically cleared and reshuffled until at least one valid move is available.
* **Spell Casting**:
  * Spells require specific mana thresholds (e.g. 8 Earth, 4 Fire).
  * Up to 7 spells equipped.
  * Casting a spell consumes mana and may or may not end the turn depending on the spell effect.
* **Victory / Defeat**:
  * Battle ends when either combatant's Life drops to 0 (`m_currentLife <= 0`).

---

## 4. Mini-Game Variations (Citadel)
* **Spell Research**:
  * Solve an isolated puzzle board with a specific starting configuration.
  * Extra turn chance disabled (`SET_EXTRATURN_CHANCE_ENABLED = 0`).
  * Illegal move damage disabled (`SET_ILLEGAL_MOVE_DAMAGE_ENABLED = 0`).
  * Goal: Clear all gems completely with zero remaining tiles.
* **Mount Training**:
  * Clear a specified quota of target gems within a turn or time limit.
* **Item Forging (Runes)**:
  * Combine a Base Rune + Modifier Rune + Power Rune.
  * Match puzzle board to complete the forging process without running out of moves.
