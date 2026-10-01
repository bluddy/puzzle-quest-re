# Puzzle Quest Battle AI — Reverse Engineering Notes

Target: `game/Puzzle Quest.unpacked.exe` (x86 PE, `Puzzle Quest.exe` with the
SteamStub removed, OEP `0x504520`). All addresses below are virtual addresses in
the unpacked image.

The AI move chooser is reached from the Lua bridge via `EVALUATE_BOARD`
(`0x48D240`), which is a three-line wrapper:

```c
// docs/decompiled/Lua_EVALUATE_BOARD.c
CBattleManager_GetSingleton();
iVar1 = CBattleManager_EvaluateBoard();
FUN_004f7020(param_2, (double)iVar1);   // push the result as a Lua number
return 1;
```

So `CBattleManager::EvaluateBoard` returns the score of the best move it found,
and the `CBattleManager` singleton is left holding the best move's coordinates.

---

## 1. Entry points

| Address | Recovered name | Role |
| :--- | :--- | :--- |
| `0x00440C20` | `CBattleManager_EvaluateBoard` | Enumerate every adjacent pair, score it, keep the best |
| `0x0043F970` | `BattleAI_ScoreMatchResult` | Score a single match result |
| `0x00440FB0` | `BattleAI_PickSpell` | Enemy spell choice, also gated on difficulty |
| `0x0043FAF0` | `BattleAI_CommitBestMove` | Executes the stored best move |
| `0x0043F920` | `BattleAI_GetBestMovePair` | Reads the stored best move out as two `short` pairs |
| `0x00443F8D0` | `BattleAI_InitWeights` | Writes the default weight table |
| `0x0043F870` | `CBattleManager_GetSingleton` | Allocates the singleton on first use |
| `0x0047C8C0` | `CBoard_CheckMatch` | Measures a run through a cell |
| `0x0047AFF0` | `CBoard_GemsMatch` | The gem-compatibility predicate |
| `0x0047B0C0` | `CBoard_AccumulateGem` | Adds one gem to a match result's counters |

Decompiler output lives in `docs/decompiled/battle_ai/` and
`docs/decompiled/battle_manager_core/`.

---

## 2. `CBattleManager` layout

Singleton pointer at `0x005828DC`. Allocated 0x4C bytes by
`CBattleManager_GetSingleton`, which also sets `[0x12] = 1`, i.e.
`m_difficulty = 1` at `+0x48` right out of the constructor.

```c
struct CBattleManager {
    void*  m_vtable;               // +0x00  = 0x0052135C
    // ... [0x04 - 0x28] ten scoring weights, see §4
    bool   m_hasValidMove;         // +0x2C
    int    m_bestMoveX;            // +0x30
    int    m_bestMoveY;            // +0x34
    int    m_bestMoveDirection;    // +0x38  1 = horizontal, 0 = vertical
    int    m_bestMoveScore;        // +0x3C
    int    m_maxScore;             // +0x40
    int    m_pendingSpell;         // +0x44  set by BattleAI_PickSpell
    int    m_difficulty;           // +0x48  0 = easy, 1 = normal, 2+ = no jitter
};
```

`FUN_004406F0` temporarily sets `m_difficulty = 2` and restores it on exit.
That is how the engine gets a *deterministic* board evaluation: at difficulty 2
neither jitter term in `BattleAI_ScoreMatchResult` runs. It is used from
`FUN_0047E500` when re-checking the board after a cascade.

`m_difficulty` is also read by `FUN_0043DA90` (damage dealt, divided by 3 at
difficulty 0 and by 3/2 at difficulty 1) and by `BattleAI_PickSpell`, which
skips a candidate spell on a `PERCENTILE_CHANCE` roll of 50% at difficulty 0 and
25% at difficulty 1.

---

## 3. The probe windows

`EvaluateBoard` does not scan the whole board after each tentative swap. It
consults a fixed set of offsets relative to the swapped pair, from four tables
in `.rdata` at `0x005212D8`–`0x00521357`, read as `(dx, dy)` int32 pairs:

| Table | Address range | Used after | Entries |
| :--- | :--- | :--- | :--- |
| H | `0x5212D8` | horizontal swap, horizontal probe | 2 |
| V | `0x5212E8` | horizontal swap, vertical probe | 6 |
| H | `0x521318` | vertical swap, horizontal probe | 6 |
| V | `0x521348` | vertical swap, vertical probe | 2 |

Decoded, as `(dx, dy)`:

```c
// after a horizontal swap at (x, y) <-> (x+1, y)
static const int kHAfterH[2][2] = { {-2, 0}, {1, 0} };
static const int kVAfterH[6][2] = { {0,-2}, {1,-2}, {0,-1}, {1,-1}, {0,0}, {1,0} };

// after a vertical swap at (x, y) <-> (x, y+1)
static const int kHAfterV[6][2] = { {-2,0}, {-1,0}, {0,0}, {-2,1}, {-1,1}, {0,1} };
static const int kVAfterV[2][2] = { {0,-2}, {0,1} };
```

Each probe is bounds-checked, and the two loops use *different* bounds, which
the decompiler renders as inconsistent comparisons:

* horizontal probe: `x` in `[0, 5]`, `y` in `[1, 8]`
* vertical probe: `x` in `[0, 7]`, `y` in `[1, 6]`

Row `y = 0` is the spawn buffer above the visible board and is never scored.

### The windows are exactly minimal, not arbitrary

The design principle is the obvious one: a swap only disturbs the two cells it
exchanges, so a run created by that swap must contain one of them, and there is
no reason to look anywhere else. Measured against that principle, the tables
turn out to be *exactly* the minimal probe set, no more and no less.

A horizontal swap at `(x, y)` with `(x+1, y)` admits runs starting at
`x-2 .. x+1` on the swap axis and at `y-2 .. y` on the cross axis. The two
windows together cover that: `kHAfterH` probes the two extremes `x-2` and
`x+1` along the axis, and `kVAfterH` probes both columns across three rows.
`CBoard_CheckMatch` measures the *maximal* run through the probe cell in both
directions, so a single probe at a run's far end finds the whole thing — the
interior start positions never need their own probe.

Simulating the exact tables against an exhaustive brute-force match check over
random boards, with the bounds checks removed:

```
matching swaps        : 45435
missed WITH bounds    : 2165  (4.77%)
missed WITHOUT bounds : 0     (0.0000%)
```

Zero misses with the bounds lifted. Every offset the tables contain is
load-bearing, and none of them is missing. The tables are not the interesting
part.

### The bounds checks are the lossy part

That 4.77% is the bounds, not the offsets. The horizontal loop clips `x` to 5
and the vertical loop clips `y` to 6, which is correct for a run *start* but
wrong for a run's *interior*. The miss distribution matches those two clips
precisely:

```
horizontal swaps, x = 5: 719    vertical swaps, y = 6: 730
horizontal swaps, x = 6: 354    vertical swaps, y = 7: 362
```

A run starting at `x = 5` on row `y` is perfectly legal, but the horizontal
probe rejects it because the clip reads as `x <= 5` rather than `x <= 7`. The
engine is refusing to look at run starts in the last two columns, and the last
two rows on the vertical axis.

No board was ever reported as having no moves when moves existed, so the
omission degrades move *choice* rather than triggering a spurious Mana Burn. It
is a real bug in the original, and a conservative one to reproduce: widening the
bounds to `[0,7]` and `[1,8]` for both loops makes the enumeration complete
with no other change, at the cost of departing from the original.

---

## 4. `BattleAI_ScoreMatchResult` (`0x0043F970`)

The match result struct that `CBoard_CheckMatch` fills is 0x128 bytes, holding ten
resource counters at a 0x1C stride starting at `+0x14`, plus the run length at
`+0x0C` and the anchor cell at `+0x00`/`+0x04`.

### Base score

```c
score  = m[0x14] * w[0x04]     // earth
       + m[0x30] * w[0x08]     // fire
       + m[0x4C] * w[0x0C]     // water
       + m[0x68] * w[0x10]     // air
       + m[0x84] * w[0x14]     // skull
       + m[0xA0] * w[0x18]     // gold
       + m[0xBC] * w[0x1C]     // xp
       + m[0xD8] * w[0x20]     // red skull
       + m[0xF4] * w[0x24]     // ice
       + m[0x110]* w[0x28]     // (unidentified)
       + run_length * 3
       + match_x;              // the anchor's x coordinate, unweighted

if (run_length > 3) score += 0x1E;   // 30
if (run_length > 4) score += 0x1E;   // 30
```

The `match_x` term is a real bias toward matches anchored in low columns. It is
one point per column, small but not zero, and it is unconditional.

### Default weights

`BattleAI_InitWeights` (`0x0043F8D0`) sets all ten to 1, then overwrites seven.
The final table:

| Offset | Resource | Default |
| :--- | :--- | :--- |
| `+0x04` | earth | 2 |
| `+0x08` | fire | 2 |
| `+0x0C` | water | 2 |
| `+0x10` | air | 2 |
| `+0x14` | skull | 10 |
| `+0x18` | gold | 1 |
| `+0x1C` | xp | 1 |
| `+0x20` | red skull | 20 |
| `+0x24` | ice | 20 |
| `+0x28` | (unidentified) | 20 |

So the four mana elements are worth equal, modest amounts; a plain skull is
five times a mana gem; a red skull is worth ten times one, and the three
special-gem buckets are worth 20 each. Nothing in the recovered code
reconfigures the weights per enemy archetype — the difficulty field is the only
knob the AI has.

### Difficulty jitter

```c
if (m_difficulty == 0)
    score += rnd(-50, 50);
else if (m_difficulty == 1 && rnd(1, 100) < 40)
    score += rnd(-20, 20);
// difficulty >= 2: no jitter
```

Easy AI always jitters, by a wide band. Normal AI jitters on 40% of matches,
by a narrow band. Hard AI does not jitter at all.

### Hero-level jitter

Read from the current player's character: a `short` at `+0x1C1` is the hero
level, `+0x1BF` is the level cap. If no hero is present the level reads as `-1`
and this whole term is skipped. The band widens as the hero approaches its cap,
so a maxed hero faces a noticeably less reliable opponent:

```c
if (m_difficulty >= 2) skip;          // 0x43FA5A jumps straight out
if (level < 0)       skip;

if (level <= 4)
    band = (5 - level) * 10;
else if (level < cap / 4)
    band = (cap / 4 - level) * 20 + 30;
else if (level < cap / 2)
    band = (cap / 2 - level) * 15 + 20;
else {
    t = cap * 3 / 4;
    band = (t <= level) ? 0 : (t - level + 1) * 10;
}
score += rnd(-band, band);
```

With `cap = 20`: level 0 gets ±50, level 4 gets ±10, level 5 drops to ±95
(the tests are strict `<`, so level 5 skips the `cap/4` band entirely), level 9
gets ±35, and level 16 or above gets nothing.

Note the discontinuity at level 5. It falls out of the `cap/4` comparison being
strict rather than inclusive, and it is in the original.

---

## 5. `CBoard_CheckMatch` (`0x0047C8C0`)

Measures the maximal run through a cell along one axis and writes the result
into a 0x128-byte match-result struct.

### Gem compatibility (`0x0047AFF0`)

```c
bool GemsMatch(int a, int b) {
    if (a == 0 || b == 0) return false;      // empty never matches
    if (a == b) return true;
    if (a == 5 && b == 0xf) return true;      // skull <-> red skull
    if (a == 0xf && b == 5) return true;
    if (a in [8,14] && b in [1,4]) return true;   // wildcard <-> mana
    if (a in [1,4]  && b in [8,14]) return true;
    return false;
}
```

Three consequences worth calling out, all of which the OCaml port reproduces:

* A wildcard substitutes only for the four mana elements. It does **not** stand
  in for gold, xp, or a skull.
* Two *different* multipliers do not match each other, because neither is in
  `[1,4]`. Only identical wildcards match.
* An empty cell matches nothing, in either position. This is what makes empty
  cells safe as blockers in the test fixtures.

### Gem ids

From the `switch` in `CBoard_AccumulateGem` (`0x0047B0C0`):

| Id | Gem |
| :--- | :--- |
| 0 | empty |
| 1 | earth |
| 2 | fire |
| 3 | water |
| 4 | air |
| 5 | skull |
| 6 | gold |
| 7 | xp |
| 8–14 | wildcard multipliers, ×2 through ×8 |
| 15 | red skull |

The `0x47BF50` animation switch corroborates the specials: ids 8–14 all take the
same effect branch, `0x0F` is `L"RedSkull"`, and 5 / 0x10 / 0x11 share
`L"WhiteSparkle"`. The red-skull animation is the one that triggers the radius-1
explosion in `FUN_0047D4F0`.

### The wildcard multiplier chain

`CBoard_AccumulateGem` multiplies into a running total rather than into any
bucket:

| Id | Operation |
| :--- | :--- |
| 8 | `total <<= 1` (×2) |
| 9 | `total *= 3` |
| 10 | `total <<= 2` (×4) |
| 11 | `total *= 5` |
| 12 | `total *= 6` |
| 13 | `total *= 7` |
| 14 | `total <<= 3` (×8) |

`CBoard_CheckMatch` then applies that total to all ten counters in a final pass,
so a 2x and a 3x wildcard in one run scale the run's yield by 6, not by 5 and
not by 7. A red skull adds 5 to the skull bucket *and* 1 to the red-skull
bucket, and appends its position to a list at `+0xDC` indexed by the count at
`+0xD8`.

---

## 6. `EvaluateBoard` control flow

```
for y in 1..8:
  for x in 0..7:
    if x < 7:
      swap (x,y) <-> (x+1,y)
      score = sum over kHAfterH (dir=h) and kVAfterH (dir=v)
      if any probe matched: push {x, y, dir=1, score}
      swap back
    if y < 8:
      swap (x,y) <-> (x,y+1)
      score = sum over kHAfterV (dir=h) and kVAfterV (dir=v)
      if any probe matched: push {x, y, dir=0, score}
      swap back

best = argmax over pushed candidates, keeping the first on a tie
m_maxScore      = best.score          // -10000 if none
m_hasValidMove  = best exists
m_bestMoveX/Y/Direction/Score = best
return best.score
```

The tie-break is a strict `<` in the scan loop, so the earliest candidate wins.
Candidates are pushed in the order above, which means horizontal swaps are
preferred over vertical ones at the same `(x, y)` when scores tie, and lower `y`
is preferred over higher `y`. This is worth preserving: it is observable, and a
different iteration order would change which of several equally-scoring moves
the enemy takes.

`m_bestMoveScore` and the return value are the same number, so the Lua-visible
return from `EVALUATE_BOARD` is redundant with the singleton's `+0x3C`.

### Committing the move

`BattleAI_GetBestMovePair` (`0x0043F920`) reads the stored best move and
expands it into the two cells to animate, incrementing `x` for a horizontal
swap and `y` for a vertical one. `BattleAI_CommitBestMove` (`0x0043FAF0`) then
calls `CBoard_SwapGems` and `FUN_0047DC30` to play it. The caller
`FUN_0047C3E0` drives this as a small state machine at `+0x354`, with a 1000 ms
delay between the "show the hint" and "play the move" steps.

---

## 7. OCaml port

`lib/ai.ml` implements the above:

| Original | OCaml |
| :--- | :--- |
| `CBoard_GemsMatch` | `Ai.ids_match` |
| `CBoard_CheckMatch` | `Ai.check_match` |
| `CBoard_AccumulateGem` | `Ai.accumulate` |
| `BattleAI_ScoreMatchResult` | `Ai.score_match_result` |
| hero-level band | `Ai.level_jitter_band` |
| `CBattleManager::EvaluateBoard` | `Ai.evaluate_board` |
| `BattleAI_InitWeights` | `Ai.default_weights` |

The difficulty and hero level are threaded through as explicit parameters
(`~difficulty`, `~hero`) rather than held in a singleton, which keeps the
scoring function pure and directly testable. The probe windows are exposed as
the four `offsets_after_*` lists so the tests can assert on them.

`test/test_ai.ml` covers the gem-id mapping, the compatibility predicate, run
measurement including the wildcard bridge, each term of the scoring formula, the
weight table, the multiplier chain, every branch of the hero-level band, both
jitter terms, swap legality, and `evaluate_board`'s best-move and no-move
outcomes. Boards are written as eight eight-character rows using empty cells as
blockers.

```powershell
dune build
dune runtest
```

---

## 8. Open questions

* The identity of gem ids `0x10` and `0x11`. Both take
  `L"WhiteSparkle"` in the destroy animation and both are weighted 20 by the AI.
  `0x11` is special-cased in `FUN_0041E880`, which counts `0x11` cells in a
  column or row and clamps a counter at `+0x70` against a ceiling at `+0x74`,
  so it looks like a limited-quantity board feature rather than a gem type.
* The two `w[0x24]` / `w[0x28]` buckets are never written by any Lua binding in
  the recovered catalogue, so nothing in the original data pipeline appears to
  populate them either.
* `FUN_0043DA90` scales the *score* by difficulty, dividing by 3 at difficulty 0
  and by 3/2 at difficulty 1 — the same field that makes the AI weaker. That
  function turned out to be the end-of-battle score rather than a damage
  formula; it is written up separately in [`BATTLE_SCORE.md`](BATTLE_SCORE.md).

---

## 9. The AI is stateless with respect to the fight

`EvaluateBoard` reads exactly two things beyond the board: `m_difficulty`, and
the hero's level and level cap for the jitter band. It never reads the enemy
character's inventory, spell list, or stats — those live in the Lua layer and
are not reachable from the C++ side at all. The AI is therefore choosing moves
from board state and a difficulty scalar, with no notion of what it owns or
what it is playing against.

That is not a limitation of this port; it is the design of the original, and it
is why the AI plays naively against a player who is hoarding a spell it cannot
see. A difficulty that factors in items and spells has to be a new layer that
either wraps or replaces `EvaluateBoard`, not a retuning of its weight table.
The weight table has no inputs for that kind of decision.
