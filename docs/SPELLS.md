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
5-run — the same tiers the AI's move scoring rewards.

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
  roll below 10 succeeds — roughly one turn in ten per element per match. Four
  elements in one match makes it near-certain.
- **The early game is stingy.** At skill 0 a 3-run banks 1 mana, so a 3-match
  has a 1% chance per element.

The comparison is a truncating `roll < (int)gained`, so fractional mana is
floored: a `gained` of 10.99 counts as 10.

Two guards. `board->[0x391]` is a mode flag, so puzzle and research modes never
grant these. And the `m_extraTurn` check means at most one is banked per
pending state — a second success is dropped rather than stacking.

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

`FUN_00440FB0` (`BattleAI_PickSpell`) iterates the enemy's spell list and skips
candidates on a percentile roll gated by difficulty:

```c
if (difficulty == 0 && roll(1,100) < 50) skip;   // 50% skip on easy
if (difficulty == 1 && roll(1,100) < 25) skip;   // 25% skip on normal
```

Then it checks each skill against the character's current mana, and on a
survivable candidate writes the index to `CBattleManager + 0x44` and clears
`m_hasValidMove`. So the AI's spell choice is:

- A random gate on difficulty, deliberately making the enemy less reliable on
  easier settings.
- An affordability filter identical to `IS_SPELL_CASTABLE`.
- **No scoring whatsoever.** It takes the first affordable spell, not the best
  one.

That last point is the same gap as the move chooser. The enemy has spells, and
picks one by coin flip filtered by whether it can pay. A harder AI would rank
them, and now that spells are in OCaml alongside the move scorer, that ranking
is a small amount of work rather than a research project.

### What the ranked chooser replaces it with

`Spell.pick_ranked_spell` scores every castable spell and takes the best. It is
selected through a **global**, `Spell.spell_policy`, defaulting to `Faithful`:

```ocaml
Spell.set_spell_policy Spell.Ranked;   (* once, at startup *)
```

It is a global rather than a field of `Battle.rules` on purpose: this is a
policy switch for the enhanced build, set once and obeyed by every battle, and
keeping it off the faithful port means the recovered behaviour stays a clean
thing to test against. `Spell.pick_spell` is the entry point the battle loop
calls; it dispatches and the loop knows nothing about the two policies.

Five weighted terms, each scaled to roughly 0..1000 so the weights read as
relative importance. **None of them is effect strength** — the 130 spell scripts
are not ported, so there is no damage number to compare spells by. These are
descriptor properties:

| Term | Source | Proxy for |
| :--- | :--- | :--- |
| potency | `learn_score` | how advanced the spell is; the game gates its strongest effects behind high scores |
| economy | `total_cost` | how often it can be cast across a battle |
| rationing | `cooldown` | how rare each cast is, so each has to be worth more |
| affinity | caster's `skills` in the elements the cost draws on | whether this caster can pay for it sustainably |
| headroom | fraction of the pool spent | saving a big spell for a turn worth using it on |

So it is a strict improvement on list order, but it is not a claim that the
chooser knows which spell is strongest. That arrives when the effect bodies do,
and at that point potency becomes a real measurement rather than the best
available proxy.

The difficulty skip is kept in both. It is a recovered behaviour, it is
orthogonal to ranking, and dropping it would confound chooser comparisons with a
change in cast frequency.

Observed difference, same seed, 120-turn fight, foe at 400 skill in every element:

```
faithful:  42 casts, all SCRAP
ranked:    17 casts: SCRAP 5  DULL 3  SOLID 7  GREAT 2
```

The ranked chooser casts *fewer* times, because the better spells cost more of
the same pool. That is the intended trade, not a regression.

Note the interaction: `FUN_004406F0` temporarily sets difficulty to 2 to get a
deterministic board evaluation, and `BattleAI_PickSpell` reads the same field.
So a board re-check mid-cascade can also change the enemy's spell behaviour
unless the caller restores it. `FUN_0047E500` does restore it.

---

## 6. OCaml port

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

---

## 7. Confidence

| Claim | Confidence |
| :--- | :--- |
| Spell struct layout and the earth/fire/air/water order | High — `FUN_00474D20` |
| Affordability is a per-pool comparison | High — `Lua_IS_SPELL_CASTABLE` |
| A resisted cast still pays its cost | High — `FUN_0043FE30` checks the latch, not the resistance |
| Mana yield is `(skill + 100) * multiplier * 0.01`, capped at 999 | High — constants read at `0x5217B4` and `0x51E4C8` |
| **Extra turn chance is `gained / 100`, per element, per match** | **High** — the roll and the truncation are both explicit at `0x47D4F0` |
| Run-size multiplier is 1 / 2 / 3 for 3 / 4 / 5-of-a-kind | High — same tiers the AI scores |
| The AI picks the first affordable spell, unranked | High — `FUN_00440FB0` |
| The extra `+0x0C` term in `IS_SPELL_CASTABLE` | Low — unresolved, possibly a second read of the disallowed flag |
| The rescale factor near `0x51E39C` | Low — present in the call path, purpose unidentified |
