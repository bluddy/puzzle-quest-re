# Combat Flow — Turn Order, Status Effects, and the Hook Table

Recovered from `game/Puzzle Quest.unpacked.exe`. Decompiler output in
`docs/decompiled/turn_manager/` and `docs/decompiled/status_effects/`.

**This document settles the Lua question.** The game does not need a Lua layer,
and the reason is concrete: the entire scripting surface is **37 named
callbacks**, listed in §4. Every one of them is a dispatch on a name string
resolved out of a Lua table. That is a small, closed, statically-enumerable
interface — the kind of thing that ports to OCaml function values directly.

---

## 1. The turn manager

Singleton at `0x005829B8`, 0x4C bytes, vtable at `0x00522274`. Reached through
`FUN_004646E0` (`Engine_EXTRA_TURN_4646E0`), which is the accessor every other
subsystem goes through.

```c
struct TurnManager {
    void* m_vtable;            // +0x00
    int   m_turnOrder[8];      // +0x04: character index per turn slot
    int   m_turnsLeft[8];      // +0x14: extra turns banked, per character
    int   m_currentTurn;       // +0x28: slot index, not character index
    int   m_round;             // +0x2C
    uint8_t m_flagA;           // +0x30
    uint8_t m_flagB;           // +0x31: set when the loop exits on defeat
    uint8_t m_extraTurn;       // +0x32
    uint8_t m_animationPending;// +0x40
    uint8_t m_animationActive; // +0x41
    int   m_animStart;         // +0x38
    int   m_animDelay;         // +0x3C
    int   m_extraTurnRound;    // +0x44
    int   m_extraTurnChar;     // +0x48
    int   m_numCharacters;     // +0x24
};
```

The split between `m_currentTurn` and the turn order matters: `+0x28` indexes a
*slot*, and `m_turnOrder[slot]` gives the character. Almost every access in the
code is the pair `m_turnOrder[*(int *)(param_1 + 0x28)]`, which is why
`FUN_00464B70` and `FUN_00464F30` both read that way.

### `m_turnsLeft` is extra turns, not a countdown

`FUN_00464730` initialises it to `0` for every character at battle start. It is
only ever incremented by the `EXTRA_TURN` path, and `FUN_00464E30` drains it
one per handoff:

```c
while (m_turnsLeft[current] > 0) {
    m_turnsLeft[current]--;
    advance_slot();
}
```

So a character who earns an extra turn replays their slot immediately, before
the order moves on. A 4-of-a-kind therefore gives the matcher another full turn,
and a 5-of-a-kind plus a second 4-of-a-kind gives them two.

---

## 2. Turn order and initiative

`FUN_00464730` builds the order at battle start. It is not a fixed hero-then-enemy
sequence — it sorts, and then **rotates so the highest-Cunning combatant goes
first**:

```c
best = -1;
for each character i:
    cunning = vfunc_0x20(i, 5);        // skill slot 5
    if (best < cunning) { best = cunning; first = i; }
    else if (cunning == best && tiebreak...) { first = i; }
```

The tiebreak is a second and third comparison, both against fields reached
through the character vtable at `+0x6C` and `+0x94`. I have not resolved what
those two are; they are almost certainly level and a class or power rating,
since Cunning is the documented initiative stat and the tiebreak is comparing
*more* of the same kind of thing.

The rotation:

```c
for (slot = 0; slot < n; slot++) {
    m_turnOrder[slot] = (slot + first) % n;
    m_turnsLeft[slot] = 0;
}
```

Note the modulo: order is a rotation, not a sort. The scan only finds *who goes
first*; everyone after them keeps roster order. So the tiebreak fields affect
only initiative, never the sequence of the rest of the round.

Game modes 2, 5 and 6 collapse the order to a single combatant:

```c
if (game_mode in {2, 5, 6}) { first = 0; m_numCharacters = 1; }
```

Those are the puzzle and spell-research modes, which have no turn order because
the player never swaps.

### The handoff loop

`FUN_00464E30` is the main advance. Order of operations per step, which is worth
preserving exactly:

1. Bail if the battle is over (`FUN_00464870` && `FUN_004648F0`).
2. If `m_extraTurn` is set, clear it and return — the extra turn is the *whole*
   iteration, not a modifier on the next one.
3. Advance the slot, wrapping at `m_numCharacters`; on wrap, increment `m_round`.
4. Drain `m_turnsLeft[current]` to zero, advancing the slot on each drain. This
   is the extra-turn replay loop.
5. Call the per-turn init (`FUN_00447120`).
6. Re-check for defeat, then re-check `m_turnsLeft` and return if empty.

Two subtleties. Step 4 can wrap the slot past `m_round` several times in one
iteration if a character has banked several extra turns. And step 6 re-reads
`m_turnsLeft` *after* the init call, which means the init is allowed to bank
another extra turn and have it honoured in the same iteration.

### Battle end

`FUN_00464870` sweeps all characters and, for any with the dead flag at `+0x12`
set and `currentLife < 1`, clears the flag and reports that something died. It
skips the sweep entirely in game modes 2, 5 and 6. `FUN_004648F0` then decides
whether the battle is actually over, and in the non-multiplayer path also
resolves victory/defeat and the loot.

The player-2 branch of `FUN_004648F0` is worth flagging: it bails out early
returning `0` if two characters disagree on the value at `+0x0C`. I read that
as a team-consistency guard, but I have not confirmed it.

---

## 3. Status effects

### Storage and lifetime

Effects are defined by `Assets/StatusEffects/<Name>.xml` and implemented by a
companion `.lua`. The XML carries only data:

```xml
<StatusEffect id="EDIS">
	<Text    name="[STATUS_DISEASE_NAME]" description="[STATUS_DISEASE_DESC]" />
	<Graphics icon="1"/>
	<Data    duration="6" stack="4"/>
	<Script  file="Assets\StatusEffects\Disease.lua" object="Disease"/>
</StatusEffect>
```

`FUN_00475760` parses this: `id` into `+0x04`, `icon` into `+0x38`, `duration`
and `stack` into `+0x3C` and `+0x40`, and the script path into the object. The
loader at `FUN_004644B0` walks `Assets\StatusEffects\*.xml` and builds a table of
0x44-byte descriptors.

`FUN_00475220` is the duration countdown, and it is the entire expiry rule:

```c
if (duration < 1) return 1;      // already expired, stay expired
duration -= 1;
return duration > 0;
```

It is called once per turn per affected character. There is no separate
"remove" path; an effect lapses when the countdown returns false.

### The effect scripts

Every status effect in the game is a Lua table of callbacks. Disease, in full:

```lua
local function OnStartTurn(characterIdx,turnNumber)
	SUBTRACT_MANA_AIR(characterIdx,1);
	SUBTRACT_MANA_EARTH(characterIdx,1);
	SUBTRACT_MANA_FIRE(characterIdx,1);
	SUBTRACT_MANA_WATER(characterIdx,1);
	ADD_EFFECT_TO_CHARACTER(characterIdx,"RedSparkle");
	return;
end

Disease = { OnStartTurn = OnStartTurn };
```

Hasted, showing a different hook:

```lua
local function OnExtraTurn(characterIdx)
	Std_InflictDamage(4,characterIdx);
	return;
end

Hasted = { OnExtraTurn = OnExtraTurn };
```

The behaviour is small, declarative, and a closed set of hooks. Seventeen
scripts in the base game; none of them does anything a function value could not.

### Hooks actually used by status effects

Scanning every `Assets/StatusEffects/*.lua`:

| Hook | Used by |
| :--- | :--- |
| `OnStartTurn` | Blinded, Disease, FireBombed, PaladinsAuraed |
| `OnExtraTurn` | Hasted |
| `OnGiveDamage` | Challenged, HandOfPowered, Hidden, SingingBladesed |
| `OnReceiveDamage` | FireShielded, Hidden, WallOfFired, WallOfThornsed |
| `OnQuerySkill` | Enraged, Fear |
| `OnReceiveXP` | Favored |
| `OnMatch4`, `OnMatch5` | Vigiled |

`FUN_00475340` is the dispatch: a 17-case switch on effect id, each case guarded
by a re-entrancy flag at a distinct global (`DAT_00582E9C` through
`DAT_00582EA5`) so a script cannot recurse into its own effect. The re-entrancy
flags are a detail we can drop, since OCaml has no re-entrancy hazard here.

---

## 4. The hook table

The decisive finding for dropping Lua. At `0x005239E8` the binary contains 37
null-terminated ASCII names, contiguous, in dispatch order. This is the complete
scripting surface:

```
 0 ShouldAICastSpell     19 OnEnd
 1 OnCastSpell           20 OnAbandon
 2 OnDefeat              21 OnEnterLocation
 3 OnEnemyCastSpell      22 OnExecuteAction
 4 OnExtraTurn           23 OnCompleteAction
 5 OnGiveDamage          24 OnCancelAction
 6 OnMatch4              25 OnQueryAction
 7 OnMatch5              26 OnLoad
 8 OnQueryResistance     27 OnSave
 9 OnQuerySkill          28 OnQueryProgress
10 OnReceiveDamage       29 OnQueryPercentage
11 OnReceiveGold         30 OnQueryDifficulty
12 OnReceiveMana         31 OnQueryAppearance
13 OnReceiveXP           32 OnQueryDisappearance
14 OnStartBattle         33 OnAppear
15 OnStartTurn           34 OnDisappear
16 OnVictory             35 OnComplete
17 OnInit                36 OnExecute
18 OnBegin
```

The strings run out at `0x00523C3C`; `0x00523C40` begins a Lua argument-type
error message, so 37 is the real count and not a scan artifact.

Every one of these is a named callback on a Lua table, dispatched by name. The
engine does not evaluate expressions or hold state in the VM; it calls a hook and
reads back arguments the hook mutated through the 191 native bindings.

So the layer's only real job is to be a **late-bound function table with named
entry points**. In OCaml that is a record of optional function fields:

```ocaml
type hooks = {
  on_start_turn : (int -> int -> unit) option;
  on_extra_turn : (int -> unit) option;
  on_give_damage : (int -> int -> int) option;
  (* ... 34 more *)
}
```

and status effects become, in full:

```ocaml
let disease = {
  def_id = "EDIS"; def_duration = 6; def_max_stack = 4; def_icon = 1;
  def_hooks = set_start_turn no_hooks (fun idx _turn ->
      let c = (!the_roster).(idx) in
      List.iter (fun e -> c.mana <- add_mana e (-1) c.mana) all_elements);
}
```

No VM, no FFI, no host-language boundary. The 191 bindings become ordinary
OCaml functions the hooks call directly. `hooks` is option-valued rather than
defaulting to no-ops so that an absent hook and a hook that returns without doing
anything stay distinguishable, matching Lua's `nil`.

Note that the hooks are the *extension* surface, not the implementation. Six of
them are AI-facing (`ShouldAICastSpell`, `OnQueryAction`, `OnQuerySkill`,
`OnQueryResistance`, `OnQueryDifficulty`, and the battle outcome ones), and those
are precisely the ones a harder AI would want to override.

### What we give up

Real, and worth stating plainly. The original's *content* — 260 spell scripts, 17
status effects, quest logic, dialogue — is authored in Lua. Dropping the layer
means we author our own definitions rather than loading `Assets.zip`. The XML
data files are still perfectly usable, since they are just data; it is the
`.lua` halves we replace.

Concretely: `Assets.zip` gives us 4,401 entries. The XMLs are readable today and
the Lua files are not. We can parse the XML for ids, costs, durations, stacks
and icons, and hand-write the ~20 effect behaviours and the spell effects in
OCaml. That is a bounded amount of work, and it is the same work the AI project
needs done anyway.

This retires the "100% parity with original data" goal in
`REVERSE_ENGINEERING_PLAN.md`. For a project whose point is an AI smarter than
the original, that is the right trade — but it is a decision, and it is recorded
as one in the plan document and the README rather than left implicit.

### The 191 bindings still matter

Dropping Lua does not make the native bridge irrelevant. It makes it
*unnecessary at runtime* while remaining the best available documentation of
what the engine can do. `LUA_API.md` is a complete inventory of the mechanics:
`ADD_STATUS_EFFECT`, `SET_MANA_FIRE`, `HANDLE_SPELL_COST`, `PERCENTILE_CHANCE`
and the rest. We implement the ones we need as OCaml functions, informed by that
inventory.

---

## 5. OCaml port

`lib/combat.ml`, tests in `test/test_combat.ml`.

| Original | OCaml |
| :--- | :--- |
| `TurnManager` | `Combat.turn_manager` |
| `FUN_00464730` order build | `Combat.initialise` |
| `FUN_00464E30` handoff | `Combat.advance_turn` |
| `FUN_00464E30` drain loop | `Combat.drain_extra_turns` |
| `FUN_00464870` death sweep | `Combat.sweep_deaths` |
| `EXTRA_TURN` | `Combat.grant_extra_turn` |
| `FUN_00475220` expiry | `Combat.tick_duration` |
| hook dispatch `FUN_00475340` | `Combat.hooks` record |
| the 37-name table | `Combat.all_hook_names` |
| `Assets/StatusEffects/*.xml` | `Combat.effect_def` |
| the two base-game effect scripts | `test_combat.ml` `disease` and `hasted` |

The turn order and handoff are ported faithfully, including the modulo rotation,
the pre-advance extra-turn branch, and the order of the defeat check against the
extra-turn check. Those orderings are observable and a port that "tidied" them
would diverge.

Two details the tests pin because getting them wrong is easy:

The **drain loop re-reads after advancing**, so it consumes one banked turn per
combatant it steps through rather than emptying one combatant's bank at a time.
A combatant with two banked turns and an empty slot ahead of them has one
consumed in the drain and resolves the other on their next turn. This is
`sweep_deaths` and `drain_extra_turns` in the port, and it is bounded by the
roster size so a roster where everyone has turns banked still terminates.

The **stack limit is per effect, not overall.** `def_max_stack` caps copies of
one effect id; a combatant may carry four Diseases and a Hasted at once. An
earlier draft counted all effects together, which silently capped a character at
one disease regardless of its `stack="4"`.

Effect hooks run *before* the duration tick, so an effect fires on the turn it
expires and is dropped after. That is what the original does, since the
countdown is consulted only after the turn's callbacks have run.

---

## 6. Confidence

| Claim | Confidence |
| :--- | :--- |
| The 37 hook names and their order | High — read directly from `.rdata`, terminated by an error string |
| Effects are Lua tables of those hooks, not expressions | High — 17 scripts inspected |
| Turn order is a rotation seeded by the highest Cunning | High — `FUN_00464730` |
| The tiebreak only picks who leads, never reorders the roster | High — the scan sets one index; the order is `(slot + first) % n` |
| `m_turnsLeft` is banked extra turns, drained per handoff | High — only ever incremented by `EXTRA_TURN` |
| The drain consumes one turn per step, not a whole bank | Medium — follows from the re-read order, but the loop's own bound is not explicit in the source |
| Effect expiry is a decrement-and-test, no separate removal | High — `FUN_00475220` is the only path |
| The stack limit is per effect id | Medium — the XML attribute is per-file; the application rule is inferred from the loader |
| Game modes 2/5/6 collapse to one combatant | High — explicit in `FUN_00464730` |
| The two tiebreak fields at vtable `+0x6C` and `+0x94` | Low — unread, almost certainly level and a class rating |
| The `+0x0C` agreement check in the player-2 branch | Low — team-consistency guard, unconfirmed |
| Spell and item scripts, 260 of them | High on existence and shape, unread in detail |
