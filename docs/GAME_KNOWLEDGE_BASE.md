# Puzzle Quest: Game Knowledge Base, Mechanics & Engine Architecture

This document synthesizes verified gameplay mechanics, engine rules, data schemas, and memory structures for *Puzzle Quest: Challenge of the Warlords*.

---

## 1. High-Level Game Flow & Architecture

### Main Menu
* **Modes**: New Quest, Continue Quest, Single Player (Instant Action), Multiplayer (LAN / Direct IP / Internet), Settings, High Scores, Multiplayer High Scores.
* **Hero Selection**:
  * Four Core Classes: **Druid**, **Knight**, **Warrior**, **Wizard**.
  * Each class has specific initial attribute distributions, mana growth curves, and spell learning tables.

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

### Gem Types & Matching Effects
* **Elemental Gems (Green, Red, Blue, Yellow)**: Add mana to the respective elemental pool.
* **Coins (Gold)**: Awards Gold directly to player reserves (capped at 99,999).
* **Purple Stars (Experience)**: Awards XP (capped at 99,999 in battle).
* **Skulls**: Deals physical damage equal to base skull count + Battle attribute bonuses and active equipment/companion multipliers.
* **+5 Skulls (Heavy/Explosive Skulls)**: Deals 5 base damage + regular skull damage; triggers surrounding area destruction.
* **Wildcards / Multipliers (x2, x3, x4, etc.)**: Can substitute for any mana gem; multiplies resulting mana or damage.

### Turn & Move Resolution
* **Turn Sequence**: Alternate turns between Player and Opponent.
* **4-of-a-Kind**: Destroys the 4 gems, awards standard yields, and grants an **Extra Turn** (`EXTRA_TURN`).
* **5-of-a-Kind**: Clears matched gems, creates a **Wildcard gem**, and grants an **Extra Turn**.
* **Illegal Move Penalty**:
  * An invalid swap (does not produce a match-3+) snaps back.
  * In combat with `SET_ILLEGAL_MOVE_DAMAGE_ENABLED` active: deals **5 points of damage** to the moving combatant and forfeits the turn!
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
