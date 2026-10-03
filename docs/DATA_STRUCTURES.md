# Puzzle Quest: Recovered Data Structures & Memory Layouts

This document details the reverse-engineered C++ class layouts, offsets, and data types recovered via Ghidra decompilation of `Puzzle Quest.exe`.

---

## 1. `CCharacter` (Combatant State)
Derived from analysis of `Lua_ADD_LIFE`, `Lua_ADD_MANA_*`, `Lua_ADD_XP`, `Lua_ADD_GOLD`, `Lua_GET_SKILL`:

```cpp
class CCharacter {
public:
    void* m_vtable;                     // +0x00: Virtual method table pointer

    // ... [0x04 - 0x44]: Base entity / animation / name properties
    int   m_characterId;                // +0x44: (param_1[0x11]) Used in modifier callbacks

    // --- Attributes / Skills (capped at 999) ---
    // Accessed via: param_1[skill_idx + 0x12]
    int   m_skills[7];                  // +0x48: [0] Earth/Air, [1] Fire, [2] Water, [3] Air/Earth
                                        // +0x58: [4] Battle
                                        // +0x5C: [5] Morale
                                        // +0x60: [6] Cunning

    // --- Core Vitality & Progression ---
    int   m_maxLife;                    // +0x64: Maximum HP cap
    int   m_unknown_68;                 // +0x68: Level / Hero class descriptor
    int   m_currentXP;                  // +0x6C: Current accumulated XP in battle (capped at 99,999)
    int   m_currentLife;                // +0x70: Current HP (clamped to m_maxLife)

    // --- Elemental Mana Reserves ---
    // Accessed via: param_1[element_idx + 0x1D]
    int   m_currentMana[4];             // +0x74: [0] Air
                                        // +0x78: [1] Earth
                                        // +0x7C: [2] Fire
                                        // +0x80: [3] Water

    // --- Elemental Mana Maximum Caps ---
    // Accessed via: param_1[element_idx + 0x21]
    int   m_maxMana[4];                 // +0x84: [0] Max Air Mana
                                        // +0x88: [1] Max Earth Mana
                                        // +0x8C: [2] Max Fire Mana
                                        // +0x90: [3] Max Water Mana

    // --- Gold & State Flags ---
    int   m_currentGold;                // +0x94: Current Gold (capped at 99,999)
    // ...
    uint8_t m_isDirty;                  // +0xBC: Set to 1 when stats/gold/XP change (triggers UI redraw)
};
```

---

## 2. `CBoard` (Match-3 Grid & Gravity Engine)
* **Singleton Location**: `0x005830D8` (Retrieved via `GetBoardSingleton()` at `0x0047A820`)
* **Total Allocated Size**: `0x42C` (1068 bytes)
* **Constructor**: `0x0047A730`
* **VTable**: `0x0052322C`

### Coordinate System & Grid Memory
* Coordinate translation in Lua wrappers (`x = arg1 - 1`, `y = arg2`):
  * $x \in [0..7]$ (columns)
  * $y \in [1..8]$ (rows) with row $y = 0$ reserved as the falling gem buffer / top spawn row.
* **Tile Index Formula**:
  $$\text{Index} = y + x \times 9$$
  $$\text{Tile Address} = \text{this} + (\text{Index} \times 8) - 0x44$$
* **Tile Structure (`sizeof(Tile) = 8`)**:
```cpp
struct Tile {
    int m_gemType;          // +0x00: Gem Type ID (0-7, wildcards, skull variants)
    int m_stateFlags;       // +0x04: Animation / destruction / cascade flags
};
```

### Key Board Methods
* `SwapGems(int x1, int y1, int x2, int y2)`: `0x0047B280`
* `CheckMatch(int x, int y, int direction, MatchResult* outResult)`: `0x0047C8C0`
* `DestroyGem(int x, int y)`: `0x0047E000` (Triggers explosion animations, SFX, and yields)
* `DeleteGem(int x, int y)`: `0x0047AC70` (Silent gem removal without triggering match yields)

---

## 3. `CBattleManager` (Combat & AI Move Search)
* **Singleton Location**: `0x005828DC` (Retrieved via `GetBattleManager()` at `0x0043F870`)
* **VTable**: `0x0052135C`

### Move Candidate & Best Move Memory Layout
During `EvaluateBoard()` (`0x00440C20`):
```cpp
struct MoveCandidate {
    int x;                  // +0x00: Column (0 to 7)
    int y;                  // +0x04: Row (1 to 8)
    int direction;          // +0x08: 1 = Horizontal swap (with x+1), 0 = Vertical swap (with y+1)
    int score;              // +0x0C: Evaluated heuristic score
};

class CBattleManager {
public:
    void* m_vtable;                 // +0x00

    // ... [0x04 - 0x28]
    bool  m_hasValidMove;           // +0x2C: True if at least one legal move exists
    int   m_bestMoveX;              // +0x30: Best move column
    int   m_bestMoveY;              // +0x34: Best move row
    int   m_bestMoveDirection;      // +0x38: 1 = Horizontal (x, x+1), 0 = Vertical (y, y+1)
    int   m_bestMoveScore;          // +0x3C: Score of best move
    int   m_maxScore;               // +0x40: Highest evaluated score across all legal moves
};
```

---

## 4. Battle Rules & Game Mode Configuration Flags

Each of these writes one byte on the battle manager, recovered from the Lua bridge
in `docs/decompiled/`:

| native | offset | what it gates |
| --- | --- | --- |
| `Lua_SET_WILDCARD_CHANCE_ENABLED` | `+0x390` | a 5-or-more run creating a wildcard |
| `Lua_SET_EXTRATURN_CHANCE_ENABLED` | `+0x391` | the **stat-based** extra turn roll |
| `Lua_SET_DAMAGE_MULTIPLIER_ENABLED` | `+0x392` | skull damage scaling |
| `Lua_SET_45_PATTERN_ENABLED` | `+0x395` | 4-in-a-row and 5-in-a-row matching patterns |
| `Lua_SET_ILLEGAL_MOVE_DAMAGE_ENABLED` | - | whether an illegal move damages the player |

**Correction.** This section previously said `SET_EXTRATURN_CHANCE_ENABLED`
toggles "4-of-a-kind granting an extra turn". That is the description of
`SET_45_PATTERN_ENABLED`, which is a different byte at a different offset.
`FUN_0047D4F0` reads `+0x391` in the *stat-based* roll - `if (board->[0x391] != 0)`
wrapping the percentile comparison - so `+0x391` is the flag on the mana-gain
extra turn, and `+0x395` is the 4-and-5 pattern one. The two extra-turn mechanisms
are separate; see `COMBAT_FLOW.md` §1 and `SPELLS.md` §4.

`SetMultiplierEffects` in `Assets/Scripts/GridUtilities.lua` sets `+0x390`,
`+0x391` and `+0x392` together, which is how the board-sweeping spells suppress
bonuses while they sweep. It does not touch `+0x395`.
