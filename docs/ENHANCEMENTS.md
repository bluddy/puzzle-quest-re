# Enhancement Ideas

**None of this is implemented as a default.** Everything here is a deliberate
departure from the original's behaviour, kept out of the faithful port so that
what the game actually does stays clean and testable. The project's stated
priority is recreation; this file is where the ideas wait.

Anything promoted out of here and into `lib/` should be off by default and
switchable, so the ported behaviour remains reachable and comparable.

---

## Ranked AI spell chooser

**Status: implemented behind an off-by-default global. Not part of the port.**

The original's `BattleAI_PickSpell` (`0x00440FB0`) takes the *first* affordable
spell in list order, with no scoring. An enemy carrying twenty spells therefore
casts the cheapest one forever and never touches the rest. That is the recovered
behaviour and `Spell.pick_ai_spell` reproduces it exactly.

`Spell.pick_ranked_spell` is the replacement. Selected through the global
`Spell.spell_policy`:

```ocaml
Spell.set_spell_policy Spell.Ranked;   (* once, at startup *)
```

`Spell.pick_spell` dispatches; the battle loop knows nothing about the two
policies. The default is `Faithful`, so the recovered behaviour is what runs
unless something asks otherwise.

### What it scores on

Five weighted terms, each scaled to roughly 0..1000 so the weights read as
relative importance. See `docs/SPELLS.md` for the full table and the observed
difference; the honest limitation is repeated here because it matters:

**None of the terms is effect strength.** The 130 spell scripts are not ported,
so there is no damage number to compare spells by. Each term is a descriptor
property standing in for it — `learn_score` for potency, cost for economy,
`cooldown` for rationing, the caster's `skills` for affinity, and the fraction
of the pool spent for headroom. Potency becomes a real measurement once the
effect bodies land, at which point the weights should be refitted.

### Open questions

- Cast count drops when the chooser works as intended, because the better spells
  cost more of the same pool. Whether that is a net win in play is a judgement
  call the numbers cannot settle without the effect bodies.
- Affinity currently scores only whether the caster can *pay*, not whether the
  spell suits them. A damage spell is worthless to a healer whatever it costs.
- The chooser ignores the board entirely. The move scorer has a board; the spell
  chooser has no idea a match is available.

---

## Ranked AI move chooser

`Ai.evaluate_board` is a faithful port, including its four clipped probe windows
and the ~4.8% of scoring moves they miss. Two obvious departures, both of which
would be *improvements over the original* and so belong here rather than in
`lib/ai.ml`:

- Widen the probe windows. The clipping is a recovered quirk, not a design.
- Score lookahead beyond the committed move, which the original does not attempt
  at all.

Note that fixing the probe windows would make the recreation *less* faithful, so
this cannot be a toggle on the same code path without care.

---

## Informed AI

The project's stated motivation for dropping Lua was that the original AI cannot
read its own inventory, spells, or stats because that state lives in a scripting
VM the C++ side cannot see. With everything in one language this becomes
available. Concretely:

- Item use, which is entirely absent from the AI today.
- Choosing *not* to cast, to save a spell for a turn it is worth using on.
- Status effect awareness: an effect that amplifies damage should change when
  the AI spends its turn.

---

## Notes on what is deliberately *not* an enhancement

These were all bugs in this port, found and fixed, and are recorded here only so
nobody mistakes them for intentional departures:

- Casting used to always be followed by a swap. The game's own spell descriptions
  say otherwise for 116 of 129 spells.
- Mana burn used to call `refill_board`, which is a no-op on a full board.
- `gold` and `xp` were assigned per swap instead of accumulated.
- Extra turns read the mana balance instead of the skill field.