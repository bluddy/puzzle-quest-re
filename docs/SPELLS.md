# Spells, Mana, and the Stat-Based Extra Turn

Recovered from `game/Puzzle Quest.unpacked.exe`, cross-referenced against
`Assets.zip`. Decompiler output in `docs/decompiled/spells/`.

**This document answers a question from playtesting.** A player observed that
matching a colour with a high skill in that element makes a free extra turn more
likely, and suspected the probability is a ratio against a maximum, rising as
the character grows. That is correct, and the mechanism is at `0x0047D4F0`. §4
has the exact formula.

---

## 1. Spell definitions

130 spell XML files in `Assets.zip`, under `Assets/Spells/`. The schema is
uniform:

```xml
<Spell id="SBAV">
   <Text  name="[SPELL_SBAV_NAME]" description="..." detail="..."/>
   <Cost  earth="20" fire="5" air="5" water="10" />
   <Learn  score="960" masks="1" keys="2" />
   <Data   cooldown="3" />
   <Input  type="none" />
   <Script  file="Assets\Spells\SBAV.lua" object="SBAV"/>
</Spell>
```

`FUN_00474D20` parses it into a 0x48-byte descriptor:

| Offset | Field | Source |
| :--- | :--- | :--- |
| `+0x04` | id, packed big-endian from 4 chars | `id` |
| `+0x2C` | earth cost | `Cost/@earth` |
| `+0x2E` | fire cost | `Cost/@fire` |
| `+0x30` | air cost | `Cost/@air` |
| `+0x32` | water cost | `Cost/@water` |
| `+0x34` | input type: 1 column, 2 row, 3 grid | `Input/@type` |
| `+0x38` | learn score | `Learn/@score` |
| `+0x3C` | learn masks | `Learn/@masks` |
| `+0x40` | learn keys | `Learn/@keys` |
| `+0x44` | cooldown in turns | `Data/@cooldown` |

Note the element order in the struct is **earth, fire, air, water**, not the
air/earth/fire/water order used by the board engine's gem ids. Worth watching
when wiring the two together.

The two shared code paths are visible in the same file. `Input/@type` of `none`
leaves `+0x34` at 0, and `+0x14` on the spell manager is a "cost already
charged" latch.

### Cost distribution

Across all 130 spells:

| Total mana | Spells |
| :--- | :--- |
| 5–13 | 37 |
| 14–16 | 32 |
| 18–26 | 22 |
| 30–45 | 28 |
| 50–80 | 11 |

Per-element maxima are tight: air 30, earth 30, fire 32, water 30. Cooldowns
run 0–5, with 2 and 3 most common. Learn scores span 250 to 2000.

---

## 2. Casting and paying

`Lua_HANDLE_SPELL_COST` (`0x0048E62C`) is the payment path and it is short:

```c
spell = spell_manager[0x18];            // the pending cast
if (spell) {
    SUBTRACT_MANA(0, spell->earth);     // +0x2C
    SUBTRACT_MANA(1, spell->fire);      // +0x2E
    SUBTRACT_MANA(2, spell->air);       // +0x30
    SUBTRACT_MANA(3, spell->water);     // +0x32
}
spell_manager[0x14] = 1;                // "cost paid" latch
```

The four mana pools live on the character at `+0x74`, `+0x78`, `+0x7C`, `+0x80`
in the same earth/fire/air/water order.

`Lua_IS_SPELL_CASTABLE` (`0x00496332`) is the affordability test, and it is a
plain per-pool comparison:

```c
castable = 1;
if (char->mana.earth < spell->earth) castable = 0;
if (char->mana.fire  < spell->fire)  castable = 0;
if (char->mana.air   < spell->air)   castable = 0;
if (char->mana.water < spell->water) castable = 0;
if (char->mana[0x7C] < spell->[0x30] && !spells_disallowed_this_turn)
    castable = 0;
```

The last line is the interesting one: the air check is gated on a "spells
disallowed this turn" flag, which is what `DISALLOW_SPELLS_THIS_TURN` sets. That
is how a status effect suppresses spellcasting.

There is also a `+0x0C` term in the condition that the decompiler renders as an
extra comparison, reading a stack local rather than a struct field. I have not
resolved what it is; it may be the same disallowed-spells flag read a second
time, or a cooldown check.

### Resistance

`FUN_004466E0` returns a 0–4 resistance code for the target, mapping to sound
effects 7–10 and `L"snd_resistspell"`. A resisted cast still pays its cost
(`FUN_0043FE30` checks the latch, not the resistance result), which matches the
game: resistance reduces the effect, it does not refund.

### The actual cast

`FUN_0043FE30` (`Engine_CAST_SPELL`) is the sequence:

1. Read the pending spell from the current turn's slot.
2. Check resistance; play the resist animation if triggered.
3. If the cost was already charged, skip straight to the effect.
4. Otherwise deduct all four pools, each clamped at zero.
5. Increment the spell's use count if it has one.
6. `FUN_00475120` runs the effect.

Note step 3's latch: payment and effect are separate, and a spell can be paid
for in one pass and resolved in another. That is what lets a free spell
(`NOTIFY_OF_FREE_SPELL`) skip the deduction without skipping the effect.

---

## 3. Mana gain from matching

When a match clears, `FUN_00465FE0` computes each pool's yield:

```c
value = vfunc_0x20(5, char->skills[idx], char->[0x11], idx);
if (value > 999) value = 999;
```

The skill array is at `+0x48`, seven entries; index 5 is the one used here. The
999 cap is why skill values saturate rather than running away.

The four elemental pools then scale by a per-match multiplier:

```
yield = (skill_value + 100.0) * match_multiplier * 0.01
```

The constants are `100.0f` at `0x005217B4` and `0.01f` at `0x0051E4C8`. The
`+ 100` floor means a character with zero skill still banks one mana per matched
gem, and the `0.01` is just a scale factor so the multiply reads as a
percentage. The multiplier is 1.0 for a 3-run, 2.0 for a 4-run and 3.0 for a
5-run - the same tiers the AI's move scoring rewards.

### Mana has a ceiling

A pool is not unbounded. `GET_MAX_MANA_*` (`0x0048DCE0` and siblings) reads
`character + 0x84 + element * 4`, so the four maxima are four contiguous ints
sitting immediately after the four current pools at `+0x74`. The setter at
`0x004839F0` stores the new maximum and then clamps the pool down to it:

```
max = new_value
if (current > max) current = max
```

Two consequences worth having straight:

- **Lowering a ceiling can take mana away.** It is not a pure cap; it is a clamp
  on the way through. An item that *lowers* max mana can therefore destroy mana
  the character is currently holding.
- **The ceiling is per element.** Setting Fire's maximum does not touch Earth's.

The base value is **not recovered**. Nothing in the save file persists it -
`docs/SAVE_FILE_FORMAT.md` records the masteries and the current reserves, but
no maximum-mana field - so the ceiling is a derived runtime quantity and its
starting value has not been located in the binary. `Combat.default_mana_limit`
is set to 10 as a placeholder, and it is deliberately low compared to real
characters because of the next paragraph.

### The ceiling has to clear the largest threshold the scripts use

This is the one place where an unverified default actively breaks mechanics, so it
is worth stating plainly rather than leaving as a hidden trap. Grepping the spell
scripts for `GET_MANA_* >= n` gives the thresholds the game actually tests:

| threshold | occurrences |
| --- | --- |
| 8 | 1 |
| 10 | 2 |
| 12 | 4 |
| 14 | 1 |
| 15 | 9 |
| 20 | 1 |

(18 in total across the 130 spell scripts.) All nine spells whose turn rule is
`KeepsTurnIfMana` need 8 or more.

A ceiling of **10**, which was the placeholder this section originally carried,
silently disables everything above it: at 10, every condition at 12 or above is
permanently false, taking the turn rules for `SBAC`, `SBRA`, `SCHL`, `SSOA` and
`SSWP` with it, along with the cast conditions of the nine spells reading `>= 15`.
That is not a tuning choice, it is dead code.

`Combat.default_mana_limit` is therefore **20**: the smallest default under which
every threshold the game uses is reachable, so no mechanic is switched off. It is
a floor rather than a model of a real character. Characters raise their ceilings
with skills and with the "+N to max Fire Mana" item bonuses, and a real late fight
sits comfortably above 20 - the AI hooks that scale a modifier by two or three
times a pool (`SFBO`, `SSOB`, `SFSP`) assume pools in the twenties and thirties.
Anything testing those should set an explicit ceiling on the combatant rather than
inherit the default.

---

## 4. The stat-based extra turn

**This is the mechanic the playtesting observation describes, and it is at
`0x0047D4F0`, in the mana-gain path.** After crediting a pool, the game rolls
for a free extra turn against the amount just banked:

```c
if (board->[0x391] != 0) {                    // extra turns enabled
    roll = FUN_004BD1F0(1, 100, 0);           // percentile roll, 1..100
    if (roll < (int)gained) {                  // gained = the pool just credited
        if (!turn_manager->m_extraTurn) {
            turn_manager->m_extraTurn = 1;
            GrantExtraTurn(1, 1);
            PLAY_SOUND(L"snd_extraturn");
        }
    }
}
```

So the probability is **`gained / 100`**, and `gained` is the mana banked by that
match in that element. With the §3 formula substituted:

```
chance = (skill + 100) * multiplier * 0.01 / 100
```

The consequences match what the player remembered:

- **A high skill in the matched element raises the chance**, linearly.
- **It is per element and per match.** Four elements matched means four
  independent rolls, so a broad match is much likelier to yield a turn than a
  narrow one.
- **Extra turns become common late game** because skill saturates at 999. At
  skill 999 a single-element 3-run gives `(999+100)*1*0.01 = 10.99` mana, so a
  roll below 10 succeeds â€” roughly one turn in ten per element per match. Four
  elements in one match makes it near-certain.
- **The early game is stingy.** At skill 0 a 3-run banks 1 mana, so a 3-match
  has a 1% chance per element.

The comparison is a truncating `roll < (int)gained`, so fractional mana is
floored: a `gained` of 10.99 counts as 10.

Two guards. `board->[0x391]` is a mode flag, so puzzle and research modes never
grant these. And the `m_extraTurn` check means at most one is banked per
pending state â€” a second success is dropped rather than stacking.

This is a completely separate mechanism from the 4-of-a-kind extra turn in
[`COMBAT_FLOW.md`](COMBAT_FLOW.md) §1. Both write to the same
`m_turnsLeft` bank, so they stack: a 5-of-a-kind from a high-skill character can
bank two turns. But the triggers are independent, and only the match-size one is
deterministic.

### The mana-burn rescale

`FUN_0047D4F0` is also where a rescale factor is threaded through, and it is
worth noting for a future AI because it changes the economy. The match
multiplier argument defaults to 1.0 and is overridden to the run-size tiers; on
a rescale the whole gain is multiplied by a separate factor held at
`0x0051E39C`-adjacent state. I have not identified what sets it.

---

## 5. The AI's spell choice

`FUN_00440FB0` (`BattleAI_PickSpell`) reads as a thin driver:

```c
if (difficulty == 0 && roll(1,100) < 50) skip;   // 50% skip on easy
if (difficulty == 1 && roll(1,100) < 25) skip;   // 25% skip on normal
```

then walk the enemy's spell list and take the first candidate that passes an
affordability filter and writes the index to `CBattleManager + 0x44`, clearing
`m_hasValidMove`.

**The intelligence is per spell, not in this function.** All 130 battle spells
define their own `ShouldAICastSpell`, and that is where the decision is actually
made:

```lua
-- SBNA
local function ShouldAICastSpell(idxCaster)
  local bonus = CountGems(GEM_YELLOW);
  if (bonus < 5) then return 0; end
  return Std_AISpellcastingChance(3*bonus);
end
```

```lua
-- SBRA
local function ShouldAICastSpell(idxCaster)
  local evaluation = EVALUATE_BOARD();
  local chance = PERCENTILE_CHANCE_SYNC();
  local numRedGems = 0;
  ... sweep the board counting red gems ...
  chance = chance + numRedGems;
  if (GET_MANA_FIRE(idxCaster) >= 15) then chance = chance - 30;
  else chance = chance + 30; end
  if (chance < 50) then return 0; end
  if (evaluation > 30) then return 0; end
  if (numRedGems < 6) then return 0; end
  return 1;
end
```

Across the 130 hooks: 107 call `Std_AISpellcastingChance`, 37 use `CountGems`,
21 use `PERCENTILE_CHANCE_SYNC`, and 20 use `EVALUATE_BOARD`.

**Correction: only one hook reads `GET_ITEM`, not twelve.** An earlier count here
said twelve. That came from counting *calls* rather than *scripts* - SDUP's body
contains four `GET_ITEM` calls, plus one in its `CastSpell`, and the figure was
never re-derived. Grepping `Assets/Spells/*.lua` for the name returns exactly one
file, `SDUP.lua`, which is also the only spell that duplicates an item and so the
only one with a reason to ask. The port now has `GET_ITEM`, so that hook is
implemented.

So the enemy consults the board and its own mana before choosing. It is not
taking list order; list order is only the tiebreak between spells that all vote
yes.

### `Std_AISpellcastingChance`

Lua, in `Assets/Scripts/StandardUtilityScripts.lua` — not an engine native,
which is why `Std_` and `CountGems` do not appear in the binary's string table
while `EVALUATE_BOARD` and `PERCENTILE_CHANCE_SYNC` do.

```lua
function Std_AISpellcastingChance(modifier)
  local evaluation = EVALUATE_BOARD();
  local chance = PERCENTILE_CHANCE_SYNC();
  if (chance > 50 + modifier) then return 0; end
  if (evaluation > 30) then return 0; end
  return 1;
end
```

Two clauses. The modifier is added to 50 and the percentile must come in at or
under it — so it is not "a modifier percent", and the modifier is a float, since
`SDDI` passes `numYellow * 1.5`. And `evaluation > 30` vetoes regardless of the
roll.

**That veto is the real answer to why the enemy sometimes plays a move instead of
casting.** A board worth more than 30 points is worth more than whatever the
spell does.

Two consequences worth stating because they are easy to get backwards:

- A modifier of -20 is **not** a veto. It puts the bar at 30, so the spell still
  casts on percentiles 0..30. `SCTH`, `SDRR` and `SSWM` all use -20 this way and
  still fire when their board gate is not met. Only `SCON`'s -100 actually
  vetoes, since that puts the bar at -50.
- 31 spells pass a modifier of 0, so they are cast on at most half the turns that
  reach them, and never when the board is good.

### What is ported

**All 129.** Nothing is missing:

- 53 mechanical hooks are generated into `lib/spell_ai.ml` by
  `tools/extract_spell_ai.ps1`.
- 76 that read the board, the pools, the life, the status effects or the items
  are hand-written in `lib/spell_ai_manual.ml`, each with its Lua alongside.

The last two were `SCHG` and `SFBA`, and both were recorded here as unobtainable
for reasons that turned out to be wrong:

- `SCHG` was blocked on `EvaluateRows`, "a Lua helper whose body has not been
  transcribed". It is a local function in `SCHG.lua` itself, ten lines below
  `CastSpell`. Nothing outside the spell's own script was ever needed.
- `SFBA` was blocked on `SET_INPUT_DATA`, which writes back the cell the spell
  targets. The *scoring* is portable and is ported; the write-back is not,
  because in a headless port the target comes from the spell's `input_type`,
  which is the human's aim. See `hook_sfba`.

Worth recording as a process note: both were declared unobtainable on the grounds
that guessing would put a fabricated function in the middle of the AI's decision.
That reasoning was right and it is why the gap was visible rather than papered
over - and it was still wrong, because the source was one file read away. The
`Assets.zip` sits at `game/Assets.zip` in this repository. It should have been
opened before either claim was written down.

**What the return value means.** These functions return a *number*, not a
boolean: `Std_AISpellcastingChance` returns 0 or 1, and three hooks return
negatives (`SMBU` -50, `SSBL` and `SSTL` -10). In Lua 0 is truthy, so the engine
cannot be using ordinary truthiness - if it were, `Std_AISpellcastingChance`
returning 0 would still read as true and every one of the 130 hooks would always
fire, which would make the entire system pointless. The comparison has to be
numeric, and `> 0` is the only reading consistent with those three negatives being
intended as vetoes. `Spell.ai_spellcasting_chance` implements that, so a negative
modifier is a veto and a positive one raises the percentile the spell needs rather
than making it more likely to happen sooner.

This also means the extractor's first pattern had a blind spot worth recording:
it required a non-negative literal, so `SCHV`, `SCLE` and `SSTL` (all -15 or -10)
were invisible to it, and `SSNK`'s bare `return 1` did not match either. It now
accepts a sign and a constant body, which is where four of the fifty extra hooks
came from.

An unported hook is treated as **never cast**, not as always cast. An absent hook
means the script defines none, which is a yes; an unported one means we know it
exists and have not read it yet, and guessing yes would have the AI fire spells
the game deliberately suppresses.

Note the interaction: `FUN_004406F0` temporarily sets difficulty to 2 to get a
deterministic board evaluation, and `BattleAI_PickSpell` reads the same field.
So a board re-check mid-cascade can also change the enemy's spell behaviour
unless the caller restores it. `FUN_0047E500` does restore it.

---

## 6. Does casting end your turn?

Almost always **yes**. This is the rule most likely to be got wrong, because
it is not a field in the spell XML and the natural assumption is that casting
and swapping are separate things you both do in a turn.

The game states the rule per spell, in the spell's own DETL line in
`English/StandardSpellsText.xml`. `tools/extract_spell_data.ps1` parses those
lines into `lib/spell_data.ml`. Transcribed, not inferred. Over the 129 battle
spells (SARC excluded, it is the spell-research mini-game descriptor):

| Turn rule | Count | Source text |
| :--- | ---: | :--- |
| `EndsTurn` | 97 | no turn clause at all â€” the default |
| `KeepsTurn` | 13 | "Your turn does not end" |
| `EndsTurnAfterEffect` | 10 | "the turn ends", after a gem-destruction effect |
| `KeepsTurnIfMana` | 9 | "Your turn does not end if _COLOUR_ Mana is N+" |

The conditional form, all nine of them:

| Spell | Condition |
| :--- | :--- |
| `SBAC`, `SBRA` | fire mana >= 15 |
| `SMBU` | fire mana >= 8 |
| `SSGZ` | earth mana >= 15 |
| `SCHL`, `SSOA` | air mana >= 15 |
| `SSWP` | air mana >= 14 |
| `SCLM`, `SCOU` | water mana >= 10 |

Two things worth flagging. The colour names map to elements as **Earth green,
Fire red, Air yellow, Water blue**, which is the reverse of the board's gem-id
order â€” that is where an Air/Water transposition would come from. And the
threshold is tested against the *caster's* mana at the moment of the cast, before
the cost is paid.

So a spell that ends the turn means the caster does not also make a swap. The
battle loop's `take_action` consults `Spell.keeps_turn` and skips the swap when
the turn is consumed. An earlier version always swapped, which is right for the
13 turn-keeping spells and wrong for the other 116.

The AI has no opinion on any of this. `BattleAI_PickSpell` takes the first
affordable spell and lets the spell's own rule decide, so there is deliberately
no turn-cost logic in the picker.

---

## 7. OCaml port

`lib/spell.ml`, tests in `test/test_spell.ml`.

| Original | OCaml |
| :--- | :--- |
| spell XML descriptor | `Spell.spell` |
| `Lua_IS_SPELL_CASTABLE` | `Spell.is_castable` |
| `Lua_HANDLE_SPELL_COST` | `Spell.pay_cost` |
| `FUN_004466E0` resistance | `Spell.resist` |
| mana yield, §3 | `Spell.mana_yield` |
| extra turn roll, §4 | `Spell.maybe_extra_turn` |
| `BattleAI_PickSpell` | `Spell.pick_ai_spell` |

`mana_yield` returns the float the original works in, because the extra turn
roll truncates it and the difference between 10.99 and 10 is observable.
`maybe_extra_turn` does the truncation explicitly rather than hiding it in an
int return.

`pick_ai_spell` reproduces the original's behaviour rather than improving it: a
difficulty-gated skip and an affordability filter, first affordable wins. The
ranking that should replace it is deliberately not written yet, so the current
behaviour stays testable and the improvement stays a visible diff.

### The `CastSpell` bodies

`lib/spell_effects.ml`, tests in `test/test_spell_effects.ml`.

**All 129.** The count is asserted against two independent things - the dispatch
table and the real spell table in `lib/spell_data.ml` - so a body registered under
an id no spell uses cannot read as progress.

Unlike `ShouldAICastSpell`, these do not all take the same shape. They are the
scripts themselves, and the interesting part of each is usually *which* gems it
counts and *what* it does with the count. The file is grouped by that rather than
by spell: board sweeps, gem rewrites, the mana and skill group, delete-and-heal,
scatters, status sweeps, and the last twenty-eight.

**The finding that unblocked twenty-one of them.** `ADD_EFFECT_TO_GRID` and
`ADD_EFFECT_TO_CHARACTER` read as though they should do something to the board,
which is what stalled them. They do not:

```c
// Lua_ADD_EFFECT_TO_GRID(x, y, name)
iVar2 = sStack_1c + 0x24;   // the cell's pixel coordinates
iVar1 = sStack_1a + 0x24;
FUN_004bddc0(iVar1, iVar2); // one animeffect call
```

A sparkle drawn on a cell - no gem, no life, no mana. So the headless port drops
it, and what remains in each of those twenty-one bodies is the whole mechanic,
which in most cases is the single `SET_GEM` or `DELETE_GEM` the sparkle was
decorating. This is the same conclusion that settled `ADD_LIGHTNING`.

**Not presentation, unlike its neighbours.** `ADD_TEMP_RESISTANCE` sits beside
these in the decompilation and looks similar, but is *not* an animation, and it is
the one that needed new model rather than a new body:

```c
iVar5 = <resolve combatant from arg 1>;
piVar1 = (int *)(iVar5 + 0x94 + iVar2 * 4);
*piVar1 = *piVar1 + iVar4;      // accumulate, no clamp, no expiry
```

Four ints at `combatant + 0x94`, indexed by the Lua mana id - which is the board's
order, 1 Earth, 2 Fire, 3 Water, 4 Air, and *not* `element`'s. That transposition
is the trap, and it is why it is `Combat.resistance` / `Combat.add_resistance`
rather than a bare array that callers index. It is a real field and not a status
effect because `GET_RESISTANCE` is a separate Lua API that other content reads.
`SSAN` is the only spell that sets it: five points to one of the four elements,
drawn at random.

**Three model additions the last twenty-eight needed.** Each is a mechanic the
scripts use and the combatant record did not have:

| Addition | Why |
| :--- | :--- |
| `Combatant.resist` | `ADD_TEMP_RESISTANCE`; read back by `GET_RESISTANCE` |
| `Combatant.gold` | `GET_GOLD(idx)` is per combatant, so `SSTL`'s transfer is between two holders |
| `Combatant.is_monster` | `IS_MONSTER`; only `SRGN` reads it, to let a monster buy extra healing with its own Water |
| `Combatant.next_spell_free` | `NOTIFY_OF_FREE_SPELL`, one byte at `+0x14`; read before the body runs, so it grants the spell *after* this one |

**Three scripts compute a value they never spend.** `SWOP` builds
`5 + Fire/8` for a message and deals no damage at all. `SSWM`'s message is built
from `numSkulls`, which is not a local in that function and does not exist in
scope. `SHBT` assigns a `doneMsg` global it never reads. All three are bugs in the
scripts' *text* and none changes a mechanic, so they are recorded where they occur
rather than given an effect they never had.

**One deliberate divergence.** `SFCA`'s original is an unbounded
`repeat ... until GET_GEM(x,y) ~= GEM_EMPTY`. It is not reachable in practice -
boards are refilled before spell effects run, and four 3x3 explosions remove at
most 36 of 64 cells - but it is still a loop that cannot terminate as written.
The port caps it at 1000 attempts. That cap is the only place this port does not
transcribe the original faithfully, and it is deliberate.

---

## 8. Confidence

| Claim | Confidence |
| :--- | :--- |
| Spell struct layout and the earth/fire/air/water order | High â€” `FUN_00474D20` |
| Affordability is a per-pool comparison | High â€” `Lua_IS_SPELL_CASTABLE` |
| A resisted cast still pays its cost | High â€” `FUN_0043FE30` checks the latch, not the resistance |
| Mana yield is `(skill + 100) * multiplier * 0.01`, capped at 999 | High â€” constants read at `0x5217B4` and `0x51E4C8` |
| **Extra turn chance is `gained / 100`, per element, per match** | **High** â€” the roll and the truncation are both explicit at `0x47D4F0` |
| Run-size multiplier is 1 / 2 / 3 for 3 / 4 / 5-of-a-kind | High â€” same tiers the AI scores |
| The AI picks the first affordable spell, unranked | High â€” `FUN_00440FB0` |
| The extra `+0x0C` term in `IS_SPELL_CASTABLE` | Low â€” unresolved, possibly a second read of the disallowed flag |
| The rescale factor near `0x51E39C` | Low â€” present in the call path, purpose unidentified |
