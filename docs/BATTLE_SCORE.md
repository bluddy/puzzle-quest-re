# End-of-Battle Score — `FUN_0043DA90`

Recovered from `game/Puzzle Quest.unpacked.exe`. The decompiler output at
`docs/decompiled/damage_xrefs/Sub_43e5f0.c` is the *caller*; this document
describes the score function it calls.

I originally expected this to be a damage formula, since it reads
`m_difficulty` and scales by it. It is not. It is the **battle score**, computed
once at the end of a fight and displayed on the results screen. The call site
settles it:

```c
// FUN_0043E5F0, the post-battle results handler
...
score = FUN_0043DA90(hero_index);      // 0x0043EAF9 / 0x0043EA6A
...
*(int **)(param_1 + 0x84) = score;      // stored on the results screen
...
FUN_004b4d40();                          // "accessing hiscores"
swprintf(buf, fmt, score);              // "[SCORE_N]" / "[NEWHIGHSCORE_N]"
```

---

## 1. Signature and character access

```c
int ComputeBattleScore(int hero_index);   // 0x0043DA90
```

`hero_index` indexes the global character array. The body fetches that
character through the standard accessor pair used everywhere in this codebase
(`FUN_0047C60` / `FUN_00446200`, then a copy into a stack local), and reads
three fields off it:

| Offset | Field | Meaning |
| :--- | :--- | :--- |
| `+0x64` | `m_maxLife` | Maximum HP |
| `+0x68` | level | Hero level |
| `+0x70` | `m_currentLife` | Current HP |

The turn manager singleton at `0x005829B8` (via `FUN_004646E0`) supplies two
more inputs:

| Offset | Role |
| :--- | :--- |
| `+0x34` | Time Limit setting (0..4), NOT elapsed turns - see below |
| `+0x2C` | Used only on the co-op path; likely heroes contributed |

---

## 2. Two branches

The function splits on a caller-supplied flag byte. In the disassembly it is
read at `0x43DACF` (`MOV AL, byte ptr [ESP + 0xC6]`) and tested at `0x43DAD8`.
I could not resolve which field it is: it is a stack local rather than a
character field, and the accessor inlines obscure its origin. The two branches
below are labelled solo and co-op on the strength of the *other* differences
between them, so treat those names as inference.

### Solo

```
score = (time_limit + 20) * 25 - max_life + current_life
if (score < 1) score = 1
return score
```

No difficulty scaling on this path, and no 50 000 cap. The `time_limit` term
reads the Time Limit setting (0..4), so it is a small fixed base - 500 for
None up to 600 for the 4-second clock - rather than a count that grows with
battle length. The score's variation on this path comes from the health terms
(`- max_life + current_life`), not from how long the fight ran. (The field was
labelled "Elapsed turns" until the settings round settled it: the delay table
indexes the same field into the five [TIMELIMIT0..4] presets, the spoils
multiply it by 5 for a percentage, battle start writes the setting there, and
nothing ever increments it. See score.time_limit_term.)

### Co-op

Base value, before the per-character loop:

```
score = (time_limit + 10) * 250
      + (current_life - max_life) * 4
      - turn_manager[0x2C] * 15
```

The `(current_life - max_life)` term is negative for a living character and
zero at full health, so it functions as a *survival* penalty rather than a
bonus. Everything is scaled 10x relative to the solo path, consistent with a
co-op fight being worth roughly ten solo fights.

### The per-character loop

Iterates every character except `hero_index`. For each one whose
`local_150 != local_a8` — a comparison against a second copy of the same
character, most likely a "has this hero levelled or changed" guard, though I
have not confirmed it — the contribution is:

```c
level_delta = other->level - hero->level;
life_delta  = other->max_life - hero->max_life;

score += (life_delta) * 3;
score += level_delta * SCALE;                  // 250, or 25 in game mode 4
score += (level_delta > 0 ? +150 : level_delta < 0 ? -150 : 0);
score += other->vfunc_0x24() * (100 or 10);    // times 10 in game mode 4
score += other->level * (100 or 10);
```

Three details worth being precise about, all verified in the disassembly:

**The ±150 term is a step function, not a linear one.** At `0x43DC21` the
compiler emits a pair of `SETGE` / `SETLE` plus mask-and-increment idioms:

```
0043dc21  XOR EDX,EDX
0043dc23  CMP EAX,EDI        ; other->level vs hero->level
0043dc25  SETGE DL           ; DL = other->level >= hero->level
0043dc28  XOR ECX,ECX
0043dc2a  DEC EDX            ; EDX = DL - 1  =>  0 if >=, -1 if <
0043dc2b  AND EDX,0xffffff6a ; -150 or 0
0043dc31  CMP EAX,EDI
0043dc33  SETLE CL           ; CL = other->level <= hero->level
0043dc36  DEC ECX            ; ECX = CL - 1  =>  0 if <=, -1 if >
0043dc37  AND ECX,0x96       ;  150 or 0
0043dc3d  ADD ECX,ESI
0043dc3f  LEA ESI,[ECX + EDX*0x1]
```

`0xFFFFFF6A` is `-150` and `0x96` is `150`. So a single level of difference
costs or grants a flat 150 regardless of magnitude. The linear `level_delta *
250` term is what scales with distance; the 150 is a discrete nudge for being
the highest- or lowest-leveled hero in the party.

**The `level * 100` term is unconditional.** Every contributing party member
adds their own level times 100, independent of any delta. At level 10 that is
1000, which dwarfs the per-delta terms. An ally identical to the hero still
contributes it. Worth knowing before tuning anything here: the score is
dominated by raw party levels, not by how the fight went.

**The `0x24` virtual call is unexplained.** It is invoked as
`(**(code **)(*other + 0x24))()` with no arguments, and its result is scaled by
100. I have not identified what it returns. It is a plausible candidate for a
character's accumulated damage, kills, or a class power rating.

**Game mode 4 divides several terms by ten.** The `GET_GAME_ID` singleton
(`FUN_004481D0`) field `+0x04` is compared against 4 four separate times, each
time switching a multiplier between 250 and 25, or 100 and 10. The flat 150
step is *not* scaled. Mode 4 appears to be a reduced-value mode, plausibly a
practice or low-stakes variant. I have not identified which game mode 4 is.

### Difficulty and clamping

After the loop, at `0x43DC8D`:

```c
if (game_id != 4) {
    if (difficulty == 0)      score = score / 3;
    else if (difficulty == 1) score = (score * 2) / 3;
}
if (score < 1)      score = 1;
if (score > 50000)  score = 50000;
```

Both divisions are signed truncating divisions by 3, written as the standard
`IMUL` by `0x55555556` sequence, so they round toward zero. The difficulty
scaling is the same one that drives the AI's move selection: a player on an easy
setting scores a third of what the same fight is worth on normal, and a player
on normal scores two thirds. Difficulty 2 and above are unscaled.

The 50 000 cap is at `0x43DCD6` (`CMP ESI, 0xC350`).

The difficulty field is `CBattleManager + 0x48`, the same one `BattleAI_InitWeights`
initialises to 1 and `FUN_004406F0` temporarily sets to 2. Difficulty is a
single shared setting: it makes the enemy both weaker and your score lower.

---

## 2a. This score has nothing to do with move choice

Worth stating plainly, because the two functions share a field and a word.

The **battle score** in this document is the number on the post-battle results
screen. It is computed once, after the fight is over, by the results handler.
Nothing reads it back. It cannot influence a single move the enemy makes.

The **match score** in [`BATTLE_AI.md`](BATTLE_AI.md) is a different number in a
different function (`BattleAI_ScoreMatchResult`, 0x43F970). That one does pick
moves. The only thing the two share is `m_difficulty`, read independently by
each.

So the allies, the level difference, and the ±150 step described above are all
purely about the score a player banks. They are not an influence on the AI's
play, however much they look like it.

---

## 3. The sibling function

`FUN_0043E400` is the **victory-spoils** function, not a co-op counterpart.
The results screen at `0x43E5F0` calls it with two `(gold, xp)` out-params,
but only on the branch gated by `turn_manager+0x30` - and that flag is a
**decisive-victory** marker, not a co-op one (see below). It fills the
out-parameters from each defeated enemy's carried gold and xp
(`other->vfunc_0x38()` and `other->vfunc_0x34()`), reduces them by an
anti-farm level gap, applies a Time Limit bonus, and then applies its own
difficulty scaling:

```c
if (difficulty == 0)      out = out * 3 / 4;
else if (difficulty == 2) out = out * 5 / 4;
// difficulty == 1: unscaled
```

The `turn_manager+0x30` flag is set at battle end (`FUN_004648f0`) to "the
first standing character is the primary hero", where standing is the
per-character `+0x12` the death sweep clears on life < 1. It is therefore true
on every decisive win - solo included - and false on a defeat or a pyrrhic
finish. The `xp.difficulty_scaling` question that used to live here is retired:
the -/+25 % the Difficulty menu advertises pays on every decisive spoils
payout, and the earlier "co-op branch" reading of this function was wrong.

### The oddity: the two functions disagree about which difficulty is neutral

An earlier draft of this document called these mappings "inverted". That was
wrong, and the error is worth correcting precisely because the arithmetic looks
like it supports the claim at a glance.

Both functions are **monotonically increasing in difficulty**:

| Difficulty | `FUN_0043DA90` (score) | `FUN_0043E400` (payout) |
| :--- | :--- | :--- |
| 0 (easy) | ×1/3 | ×3/4 |
| 1 | ×2/3 | ×1 |
| 2 | ×1 | ×5/4 |
| 3+ | ×1 | ×5/4 |

No inversion. In both, a harder setting is worth more. The real discrepancy is
the **anchor point**: `FUN_0043DA90` treats difficulty 2 and above as the
unscaled baseline, while `FUN_0043E400` treats difficulty 1 as its baseline and
pays a bonus at 2.

So the same setting is discounted in one function and not the other:

| Difficulty | Score | Payout |
| :--- | :--- | :--- |
| 1 | discounted to 2/3 | untouched |
| 2 | untouched | boosted to 5/4 |

Both curves are individually sensible — one ramps up to a ceiling at 2, the
other straddles its midpoint at 1 — but they cannot both be calibrated against
the same difficulty-selection UI. Either difficulty 1 is meant to be the
"normal, no adjustment" setting, in which case the score function is
double-discounting the common case, or difficulty 2 is, in which case the payout
function pays a bonus on top of an already-reduced score.

**Checked against the difficulty menu, 2026-10-13: the payout function is the
one that matches it.** The three rows are `[AILEVEL0]` "Easy (-25% XP)",
`[AILEVEL1]` "Normal" and `[AILEVEL2]` "Hard (+25% XP)" - baseline at
difficulty 1, ×3/4 at 0, ×5/4 at 2, which is `FUN_0043E400` exactly, and the
menu proves difficulty 1 is the neutral setting. Whether a *solo* fight pays
the modifier was the open question `xp.difficulty_scaling`, now retired: the
results screen calls this function with its `(gold, xp)` out-params on the
branch gated by `turn_manager+0x30`, and that flag is a decisive-victory
marker (the primary hero standing at battle end), not a co-op one - so a solo
decisive win pays the ±25 %, and the other branch (defeat or pyrrhic) feeds
zeros. `docs/GAME_KNOWLEDGE_BASE.md` carries the menu side of it. The score
curve's own 1/3, 2/3, 1 calibration is then the odd one out, and it is a
different quantity (the displayed score, not experience), so it no longer has
to agree.

---

## 4. Confidence

| Claim | Confidence |
| :--- | :--- |
| Function is the end-of-battle score, not damage | High — call site and string tags |
| Both branch formulas, the loop body, the difficulty scaling, the 50 000 cap | High — read from disassembly |
| The ±150 term is a flat step, not linear | High — `SETGE`/`SETLE` at `0x43DC21` |
| The `time_limit` and `m_maxLife` / `m_currentLife` field identities | High — life offsets agree across the two functions; `+0x34` is pinned to the Time Limit setting by the delay table, the spoils and the battle-start copy (score.time_limit_term) |
| Game mode 4 is a reduced-value mode | Medium — consistent across four call sites, purpose unidentified |
| The two branches are solo vs co-op | Medium — inferred from the 10x scaling and the `turn_manager[0x2C]` term |
| The branch flag at `[ESP + 0xC6]` | Low — not resolved to a source field |
| `vfunc_0x24` on a character | Low — unidentified, and a large term |
| The `local_150 != local_a8` loop guard | High — it skips same-team characters, so only enemy-team members pay spoils (part of the `xp.difficulty_scaling` retirement) |

The two low-confidence items in the co-op branch are the two that matter. The
`vfunc_0x24` term in particular is scaled by 100 and is probably the single
largest contributor to a co-op score, so a faithful port of that path is not
possible until it is identified.

---

## 5. OCaml port

`lib/score.ml`, with tests in `test/test_score.ml`. `Score.character` models
only the three fields the function reads plus `power` for the unidentified
`vfunc_0x24`. `Score.level_step` is exposed separately so the flat ±150 term can
be asserted directly rather than inferred through the linear terms it sits
between.

Both unresolved co-op items are left as explicit seams rather than guesses:
`?party_member_contributes` is the hook for the loop guard, and
`character.power` stands in for `vfunc_0x24`. The tests exercise the formula's
arithmetic, not the parts still in the dark, and `docs/BATTLE_SCORE.md` keeps
the confidence table honest about which is which.

The spoils sibling is wired too. `Score.compute_victory_spoils` (renamed from
`compute_co_op_payout`, because `xp.difficulty_scaling` retired the co-op
reading) holds the ±25 % difficulty scale, and `Score.level_gap_scale` holds
the anti-farm reduction from `FUN_0043d4c0`. `Campaign.spoils_of_victory`
rolls a defeated monster's carried gold and xp from its Reward range and runs
both scales over them; the road settle (`process_battle_result`) and the quest
settle (`quest_battle_settle`) add the result to the match harvest on a win.
The Time Limit bonus (`turn_manager+0x34 * 5` %) is wired as
`Score.time_limit_scale`, applied by `Campaign.spoils_of_victory` between the
anti-farm gap and this function's difficulty scale - the settings round
retired the "no Time Limit model" note it used to carry.

