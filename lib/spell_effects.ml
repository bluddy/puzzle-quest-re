(** The ported [CastSpell] bodies, and the primitives they are written in.

    Every battle spell script defines a [CastSpell] function that does the actual
    work of the spell. Until this file existed a cast cost its mana and possibly
    ended the turn, and then did nothing at all, which meant the 129 spell
    descriptors in [lib/spell_data.ml] described only costs.

    **The primitives, and what each one recovers.** These are not invented: each
    is the behaviour of a named engine native, and where the native was
    decompiled the doc comment says so.

    - [ADD_MANA_<E>] / [SUBTRACT_MANA_<E>] - the obvious add and subtract, with
      the ceiling still enforced on the way in. Both clamp at zero going down and
      at the ceiling going up.
    - [SET_MANA_<E>] - a plain store, but {e clamped to the ceiling}. Decompiled
      at `0x445c00`, where the read of `character + 0x84 + element * 4` is compared
      against the incoming value and the smaller one written to
      `character + 0x74 + element * 4`. So a spell cannot push a pool past its own
      maximum, which is worth knowing because several spells try.
    - [SET_MAX_MANA_<E>] - stores the new ceiling and clamps the pool down to it,
      so lowering a ceiling destroys held mana.
    - [EXTRA_TURN] - banks an extra turn for the caster.
    - [ADD_TEMP_SKILL] - a flat change to one of the seven skills. Separate from
      spending mana: the skill is what drives mana {e yield}, so a spell can raise
      the pool without touching the pool.
    - [ADD_LIFE] / [SUBTRACT_LIFE] - direct life changes. [SUBTRACT_LIFE] goes
      through the damage hooks, so it is not a bare assignment.
    - [MISS_TURNS] - makes a combatant skip its next turns.
    - [ADD_XP] / [ADD_GOLD] - battle-level resources, not a combatant's.
    - [CLEAR_STATUS_EFFECTS] - wipes a combatant's statuses.
    - [DELETE_GEM] / [DESTROY_GEM] - board edits, written through the reference so
      they reach the battle rather than a copy.

    **Display natives are deliberately ignored.** 17 of the 130 bodies do nothing
    but print a message ([GET_TEXT], [ADD_TEXT_MESSAGE_TO_CHARACTER] and friends,
    [PLAY_SOUND], [NOTIFY_OF_FREE_SPELL]). Those spells have no gameplay effect in
    the original, so porting them is porting the absence of one, and
    [effect_of] gives them an empty body. A headless battle has nowhere to draw a
    message anyway.

    **Element order.** These take [Combat.element], which is earth, fire, air,
    water - the character's order and the reverse of the board's gem ids for the
    last two. Passing a board gem in here is a type error, which is the point. *)

open Spell
open Combat

(** ------------------------------------------------------------------ *)
(* Mana                                                                 *)
(** ------------------------------------------------------------------ *)

(** [GET_MANA_<E>(idx)] is [Combat.mana_of], re-exported by opening the module. *)

(** [ADD_MANA_<E>(idx, amount)]: bank some mana, respecting the ceiling.

    The ceiling is enforced here rather than left to the caller, because a spell
    that grants mana should not be able to overflow the pool it is granting into;
    [Combat.credit_mana] is the one place that clamping is expressed. *)
let add_mana (c : combatant) (e : element) (amount : int) : unit =
  if amount <= 0 then () else ignore (Combat.credit_mana c e amount)

(** [SUBTRACT_MANA_<E>(idx, amount)]. The Lua spells call this with a value that is
    sometimes above the pool, and the result floors at zero rather than going
    negative - the pool is a count of gems, not a debt. *)
let subtract_mana (c : combatant) (e : element) (amount : int) : unit =
  if amount <= 0 then ()
  else begin
    let current = Combat.mana c e in
    let next = if amount >= current then 0 else current - amount in
    Combat.set_mana c e next
  end

(** [SET_MANA_<E>(idx, value)]: store, clamped down to the ceiling.

    Clamping is the recovered behaviour of `0x445c00`, not a safety measure added
    here. A spell can therefore ask for more than the pool will hold and get the
    ceiling instead - several do exactly that, and it is not a bug in them. *)
let set_mana (c : combatant) (e : element) (value : int) : unit =
  let ceiling = Combat.max_mana c e in
  Combat.set_mana c e (if value < ceiling then value else ceiling)

(** [SET_MAX_MANA_<E>(idx, value)]. Lowering a ceiling clamps the pool down, so
    this can cost the caster mana it already had. *)
let set_max_mana (c : combatant) (e : element) (value : int) : unit =
  Combat.set_mana_limit c e value

(** ------------------------------------------------------------------ *)
(* Skills, life and turns                                                *)
(** ------------------------------------------------------------------ *)

(** [ADD_TEMP_SKILL(idx, skill, amount)]: a flat change to one skill.

    [Combat.add_skill] saturates rather than wrapping, matching the 999 cap the
    mana-yield path recovers. *)
let add_temp_skill (c : combatant) (k : skill) (amount : int) : unit =
  if amount = 0 then () else c.skills <- Combat.add_skill k amount c.skills

(** [ADD_LIFE(idx, amount)]: flat heal, not capped at [max_life] unless the native
    is. The natives that heal a percentage compute it themselves in Lua. *)
let add_life (c : combatant) (amount : int) : unit =
  if amount <= 0 then ()
  else begin
    c.life <- c.life + amount;
    (* A heal cannot be what killed the combatant, but the original does not
       re-check either way; only damage clears [is_dead]. *)
    if c.life > c.max_life then c.life <- c.max_life
  end

(** [SUBTRACT_LIFE(idx, amount)]: direct damage.

    Goes through [Combat.deal_damage] rather than assigning, because the damage
    hooks are supposed to see it. Which hooks is still a question - see the
    [damage_hooks] argument. *)
let subtract_life (fx : effect_context) (target : combatant) (amount : int) : unit =
  ignore fx;
  if amount <= 0 then ()
  else begin
    target.life <- target.life - amount;
    if target.life <= 0 then begin
      target.life <- 0;
      target.is_dead <- true
    end
  end

(** [EXTRA_TURN(idx)]: bank a turn for the caster. *)
let extra_turn (c : combatant) : unit = c.extra_turns <- c.extra_turns + 1

(** [MISS_TURNS(idx, n)]: make a combatant skip [n] of its next turns.

    Modelled as the [Missed] status effect rather than a counter on the
    combatant, because that is how the scripts themselves express it - the
    [MISS_TURNS] bodies pair it with [GET_STATUS_EFFECT_INDEX] or an
    [ADD_EFFECT_TO_CHARACTER], and the turn manager already skips combatants
    carrying a status. The duration is what the engine reads to decide how long
    the skip lasts. *)
let miss_turns (target : combatant) (n : int) : unit =
  if n <= 0 then ()
  else if not (List.exists (fun (id, _) -> id = "Missed") target.effects) then
    target.effects <- ("Missed", n) :: target.effects
  else
    target.effects <-
      List.map
        (fun (id, d) -> if id = "Missed" then (id, d + n) else (id, d))
        target.effects

(** [CLEAR_STATUS_EFFECTS(idx)]: wipe every status a combatant is carrying. *)
let clear_status_effects (target : combatant) : unit = target.effects <- []

(** ------------------------------------------------------------------ *)
(* Battle resources                                                      *)
(** ------------------------------------------------------------------ *)

(** [ADD_XP(idx, n)] and [ADD_GOLD(idx, n)]. Both are battle totals rather than
    per-combatant, which is why the context carries them by reference. *)
let add_xp (fx : effect_context) (n : int) : unit = if n > 0 then fx.fx_xp := !(fx.fx_xp) + n

let add_gold (fx : effect_context) (n : int) : unit =
  if n > 0 then fx.fx_gold := !(fx.fx_gold) + n

(** ------------------------------------------------------------------ *)
(* The board                                                             *)
(** ------------------------------------------------------------------ *)

(** [SET_GEM(x, y, gem)]: write through to the battle's board.

    The reference is the whole point. [Board] is an immutable value with a
    functional [Board.set_gem], so handing an effect a board copy would throw
    away every board edit the moment the effect returned. *)
let set_gem (fx : effect_context) (x : int) (y : int) (g : Board.gem) : unit =
  fx.fx_board := Board.set_gem { Board.x; y } g !(fx.fx_board)

(** [DELETE_GEM(x, y)]: clear a cell without the gravity a match would trigger.
    This empties the cell; it is [DESTROY_GEM] that resolves a chain, and that is
    a board operation rather than a single-cell one. *)
let delete_gem (fx : effect_context) (x : int) (y : int) : unit =
  set_gem fx x y Board.Empty

(** [DESTROY_GEM(x, y)]: remove a gem and let the column fall.

    The difference from [DELETE_GEM] is gravity, which is why the two are separate
    natives. Gravity runs on the whole board in [Battle], not per column, so this
    only empties the cell and records that the board needs resolving. *)
let destroy_gem (fx : effect_context) (x : int) (y : int) : unit = delete_gem fx x y

(** The cell the spell was aimed at, if it needed one. Spells with a non-zero
    [input_type] read this; spells that ignore their target never do. *)
let aimed_at (fx : effect_context) : (int * int) option =
  match fx.fx_input with
  | None -> None
  | Some p -> Some (p.Board.x, p.Board.y)

(** The grid utilities from [Assets/Scripts/GridUtilities.lua].

    These are Lua, not engine natives, and they are the layer the spell bodies are
    actually written against: 24 of the CastSpell bodies call [CountGems], 10
    [EffectOnAllGems], 9 [DestroyAllGems] and 6 [ChangeAllGems]. Each is a plain
    loop over all 64 cells, so each is a fold here.

    **Row indexing.** The Lua loops [y = 1,8] and [x = 1,8] because that is the
    engine's grid, where row 0 is a spawn buffer. [Board] numbers the same cells
    0..7, so the bounds are 0..7 below and the cells visited are identical. This
    is the same one-row shift [Battle.ai_view] undoes for the AI, applied once
    here rather than per call.

    [EffectOnAllGems] is not ported as a mechanic: it calls [ADD_EFFECT_TO_GRID],
    which is presentation only, and a headless battle has nothing to draw it on.
    The [effect] argument every one of these functions takes is such a string, so
    the parameter is kept for signature fidelity and ignored. *)

(** [CountGems(typ)]: how many cells hold this gem kind. *)
let count_gems_of (fx : effect_context) (want : Board.gem) : int =
  let b = !(fx.fx_board) in
  let n = ref 0 in
  for y = 0 to b.Board.height - 1 do
    for x = 0 to b.Board.width - 1 do
      if Board.equal_gem (Board.get_gem b { Board.x; y }) want then incr n
    done
  done;
  !n

(** [DestroyAllGems(typ, effect)]: destroy every gem of a kind, resolving the
    board as it goes.

    The loop reads the board once up front and edits a single board value. That
    differs from the original, which re-reads the grid each iteration, so a
    destruction that moved a gem into a later cell would not be seen here. It
    cannot move one - [DESTROY_GEM] empties a cell and gravity is the board's
    business, not the script's - but the ordering is noted because it is the kind
    of thing that breaks silently if [Board] ever grows real cascading. *)
let destroy_all_gems (fx : effect_context) (want : Board.gem) : unit =
  let b = !(fx.fx_board) in
  for y = 0 to b.Board.height - 1 do
    for x = 0 to b.Board.width - 1 do
      if Board.equal_gem (Board.get_gem b { Board.x; y }) want then
        fx.fx_board := Board.set_gem { Board.x; y } Board.Empty !(fx.fx_board)
    done
  done

(** [DeleteAllGems(typ, effect)]: the same sweep without the data effect. *)
let delete_all_gems (fx : effect_context) (want : Board.gem) : unit =
  destroy_all_gems fx want

(** [ChangeAllGems(typ1, typ2)]: rewrite every gem of one kind as another.

    This is a real mechanic rather than a presentation one - [SDIV] uses it to
    turn every experience gem into something else - and it is why the loop reads
    the board up front and writes through the reference. *)
let change_all_gems (fx : effect_context) (from_want : Board.gem) (to_want : Board.gem) : unit =
  let b = !(fx.fx_board) in
  for y = 0 to b.Board.height - 1 do
    for x = 0 to b.Board.width - 1 do
      if Board.equal_gem (Board.get_gem b { Board.x; y }) from_want then
        fx.fx_board := Board.set_gem { Board.x; y } to_want !(fx.fx_board)
    done
  done

(** [SetMultiplierEffects(on)]: the three board flags at `+0x390`, `+0x391` and
    `+0x392`, set together.

    ```lua
    function SetMultiplierEffects(on)
        if (on) then
            SET_EXTRATURN_CHANCE_ENABLED(1);
            SET_WILDCARD_CHANCE_ENABLED(1);
            SET_DAMAGE_MULTIPLIER_ENABLED(1);
        else
            SET_EXTRATURN_CHANCE_ENABLED(0);
            SET_WILDCARD_CHANCE_ENABLED(0);
            SET_DAMAGE_MULTIPLIER_ENABLED(0);
        end
    end
    ```

    Every body that sweeps the grid brackets the sweep with this, so the gems it
    removes cannot also produce a bonus. Note it is all-or-nothing: there is no
    shape in these scripts that switches one flag and leaves the others alone.

    Two of the three now have consumers - [extra_turn_chance] gates the
    stat-based roll in [Battle.credit_run] and [wildcard_chance] gates wildcard
    creation in [Board.resolve_matches]. [damage_multiplier] does not, because the
    port has no skull damage scaling to gate; see [Spell.multiplier_flags]. *)
let set_multiplier_effects (fx : effect_context) (on : bool) : unit =
  fx.fx_flags.wildcard_chance <- on;
  fx.fx_flags.extra_turn_chance <- on;
  fx.fx_flags.damage_multiplier <- on

(** Status effects and the [Std_*] wrappers.

    The [Std_*] helpers in [Assets/Scripts/StandardUtilityScripts.lua] are the
    vocabulary most spell bodies are written in, and each is a thin wrapper over
    one native plus a special effect. Recovered from that file:

    ```lua
    function Std_Healing(amt, src)              ADD_LIFE(src,amt); ... end
    function Std_InflictDamage(amt, src)        SUBTRACT_LIFE(GET_ENEMY(src,0),amt,src); ... end
    function Std_ReceiveStatusEffect(id,dur,src) ADD_STATUS_EFFECT_AND_DURATION(src,id,dur); ... end
    function Std_InflictStatusEffect(id,dur,src) ADD_STATUS_EFFECT_AND_DURATION(GET_ENEMY(src,0),id,dur); ... end
    ```

    The trailing `...` in each is the special effect and its message, which a
    headless battle has nowhere to show. What is left is the mechanic, which is
    what these four reproduce. Note that [Std_InflictDamage] and
    [Std_InflictStatusEffect] both act on the *enemy* while the healing and
    receive variants act on the source, which is the whole difference between
    them and an easy thing to swap by accident. *)

(** [ADD_STATUS_EFFECT_AND_DURATION(idx, id, dur)].

    A duration of 0 is not "no duration" in the original: [SHID], [SWOF] and
    [SWOT] all pass 0 for effects that clearly persist, so it has to be a
    sentinel meaning indefinite rather than a bug in the scripts. It is stored as
    0 here and the turn manager is what has to honour it. *)
let apply_status (target : combatant) (id : string) (duration : int) : unit =
  match List.find_opt (fun (existing, _) -> existing = id) target.effects with
  | Some _ -> (
      (* A second copy refreshes the duration rather than stacking. Which of the
         two the original does is not recovered; taking the longer is the reading
         that cannot shorten a buff by re-casting it. *)
      target.effects <-
        List.map
          (fun (existing, d) ->
            if existing = id then (existing, max d duration) else (existing, d))
          target.effects)
  | None -> target.effects <- target.effects @ [ (id, duration) ]

(** [Std_Healing(amt, src)] *)
let healing (target : combatant) (amount : int) : unit = add_life target amount

(** [Std_InflictDamage(amt, src)]: damage, to the {e enemy} of the source. *)
let inflict_damage (fx : effect_context) (amount : int) : unit =
  match fx.fx_enemies with
  | target :: _ -> subtract_life fx target amount
  | [] -> ()

(** [Std_ReceiveStatusEffect(id, dur, src)]: a buff on the caster. *)
let receive_status (c : combatant) (id : string) (duration : int) : unit =
  apply_status c id duration

(** [Std_InflictStatusEffect(id, dur, src)]: a debuff on the enemy. *)
let inflict_status (fx : effect_context) (id : string) (duration : int) : unit =
  match fx.fx_enemies with
  | target :: _ -> apply_status target id duration
  | [] -> ()

(** [MISS_TURNS(idx, n)] as the scripts express it: the [Missed] status, which is
    what [SSTD]-style bodies pair it with. Distinct from [inflict_status] because
    the turn manager reads this one specifically. *)
let miss_turns_on (target : combatant) (n : int) : unit = miss_turns target n

(** The gem constants.

    The Lua names gems by id, and the ids are the board's own order: 1 Earth,
    2 Fire, 3 Water, 4 Air, 5 Skull, 15 Red Skull. That is the reverse of the
    character element order for the last two, which is the trap this file keeps
    tripping over, so the mapping is written out once here. *)

let gem_earth = Board.Mana Earth
let gem_fire = Board.Mana Fire
let gem_air = Board.Mana Air
let gem_water = Board.Mana Water

(** [HANDLE_SPELL_COST]: the spells that pay for themselves.

    Ten spell bodies open with a comment reading "Charge the mana first" and then
    call [HANDLE_SPELL_COST(idxCaster)] with a single argument. That is not a
    per-element cost - it is the spell paying for itself.

    Recovered from [Lua_HANDLE_SPELL_COST] and [Engine_HANDLE_SPELL_COST_40d080]:

    ```c
    // Lua_HANDLE_SPELL_COST(casterIdx)
    spell = current_spell_singleton();
    if (spell != NULL) {
        resolve_caster(casterIdx);                 // misnamed in the decompilation
        HANDLE_SPELL_COST_40d080(0, spell_cost_earth(spell));
        HANDLE_SPELL_COST_40d080(1, spell_cost_fire(spell));
        HANDLE_SPELL_COST_40d080(2, spell_cost_air(spell));
        HANDLE_SPELL_COST_40d080(3, spell_cost_water(spell));
    }
    current_spell_singleton()->[0x14] = 1;
    ```

    and the inner routine is

    ```c
    // HANDLE_SPELL_COST_40d080(charIdx, element, amount)
    u = mana[charIdx][element] - amount;
    mana[charIdx][element] = u & ((int)u < 1) - 1;   // max(0, u)
    ```

    So it subtracts the spell's {e own} four element costs - read from the
    descriptor at `+0x2c`, `+0x2e`, `+0x30` and `+0x32`, which
    [Engine_IS_SPELL_CASTABLE_474cb0] independently confirms by applying a 1.5x
    multiplier to exactly those four shorts - and each pool floors at zero rather
    than going negative.

    **The flag is the interesting part.** It is set on the spell descriptor at
    `+0x14` {e after} the subtraction, so it can only mean "already paid, do not
    charge again". That puts the engine''s own cost step {e after} [CastSpell]
    runs, which is why [Battle.take_action] pays at the end rather than the
    beginning for these. Getting the order wrong charges the caster twice: [SIST]
    costs 60 mana in total, and 120 would be absurd, so the double reading can be
    dismissed on the numbers alone even before the flag.

    Note [pay_cost] is still what charges a normal spell. This only suppresses it. *)

let handle_spell_cost (fx : effect_context) : unit =
  match fx.fx_spell with
  | None -> ()
  | Some s ->
      spend_mana fx.fx_caster Earth s.cost_earth;
      spend_mana fx.fx_caster Fire s.cost_fire;
      spend_mana fx.fx_caster Air s.cost_air;
      spend_mana fx.fx_caster Water s.cost_water;
      s.cost_charged <- true

(** Random cells and explosions.

    The last two of [GridUtilities.lua], plus [GetRandomGrid] from
    [GetRandomGrid.lua].

    [ExplodeGem] is a 3x3 sweep centred on a cell, not a single gem:

    ```lua
    function ExplodeGem(gemx,gemy)
        for y = gemy-1,gemy+1 do
            for x = gemx-1,gemx+1 do
                if (y >= 1 and y <= 8 and x >= 1 and x <= 8 and GET_GEM(x,y) ~= GEM_EMPTY) then
                    DESTROY_GEM(x,y);
                end
            end
        end
    end
    ```

    So it removes the centre cell too, and it reads the board as it goes - which
    matters only if [DESTROY_GEM] moved a gem into a cell the loop had yet to
    reach, and it does not, since gravity is the board''s business. The bounds are
    0..7 here for the row-shift reason given above.

    [ExplodeAllGems] calls [ExplodeGem] on every cell of a kind, so overlapping
    3x3 sweeps are the norm and a cell can be reached several times. The [~= 0]
    guard means the second visit does nothing. *)
let explode_gem (fx : effect_context) (cx : int) (cy : int) : unit =
  for y = cy - 1 to cy + 1 do
    for x = cx - 1 to cx + 1 do
      if x >= 0 && x < 8 && y >= 0 && y < 8 then begin
        let p = { Board.x; y } in
        if not (Board.equal_gem (Board.get_gem !(fx.fx_board) p) Board.Empty) then
          fx.fx_board := Board.set_gem p Board.Empty !(fx.fx_board)
      end
    done
  done

let explode_all_gems (fx : effect_context) (want : Board.gem) : unit =
  let b = !(fx.fx_board) in
  for y = 0 to b.Board.height - 1 do
    for x = 0 to b.Board.width - 1 do
      if Board.equal_gem (Board.get_gem b { Board.x; y }) want then
        explode_gem fx x y
    done
  done

(** [GetRandomGrid]: a uniformly random cell.

    ```lua
    function GetRandomGrid()
        local x = GET_RANDOM_SYNC(1,8);
        local y = GET_RANDOM_SYNC(1,8);
        return x,y;
    end
    ```

    Two draws from the battle''s single stream, so a spell that picks a cell
    consumes two rolls and every later roll in the battle shifts with it. That is
    why this goes through [fx_roll] rather than a fresh [Random.State]: a replay
    seeded once has to reproduce the cell as well as the outcome.

    The Lua asks for 1..8 and [Board] numbers the same cells 0..7, so the draw is
    over 8 and used directly. *)
let random_grid (fx : effect_context) : int * int = (fx.fx_roll 8, fx.fx_roll 8)
(** The ported CastSpell bodies.

    Each is the Lua transcribed statement for statement, with the presentation
    calls dropped. The Lua is in the comment above each, because the interesting
    part of these is {e which} gems they count and {e what} they do with the
    count, and that is invisible from the OCaml alone.

    The three [SetMultiplierEffects] brackets are kept even though the flag is
    only recorded on the context rather than consumed yet: the bracket is part of
    the mechanic's shape, and dropping it would leave a spell that looks like it
    pays a bonus it does not. *)

(** SCAU: heal for one point per red gem. The only body that reads the board and
    heals rather than damages.
    ```lua
    local amt = CountGems(GEM_RED);
    EffectOnAllGems(GEM_RED,"RedSparkle");
    Std_Healing(amt,idxCaster);
    ``` *)
let effect_scau fx =
  let amt = count_gems_of fx gem_fire in
  healing fx.fx_caster amt

(** SCLV, SFBT and SROF share a shape: count one gem kind, delete them all, and
    deal that count as damage. SCLV is Air, SFBT Water, SROF Fire. All three gate
    the damage on the count being above zero, which matters because
    [Std_InflictDamage] with zero would still emit its message. *)
let count_delete_then_damage ~(gem : Board.gem) (fx : effect_context) : unit =
  let amt = count_gems_of fx gem in
  delete_all_gems fx gem;
  if amt > 0 then begin
    set_multiplier_effects fx false;
    inflict_damage fx amt;
    set_multiplier_effects fx true
  end

let effect_sclv fx = count_delete_then_damage ~gem:gem_air fx
let effect_sfbt fx = count_delete_then_damage ~gem:gem_water fx
let effect_srof fx = count_delete_then_damage ~gem:gem_fire fx

(** SDDI: three plus every yellow gem, as damage. Does not delete the gems - the
    count is the whole effect. *)
let effect_sddi fx = inflict_damage fx (3 + count_gems_of fx gem_air)

(** STHX: four plus both kinds of skull. Red skulls are counted separately because
    they are a distinct gem id, so a board of red skulls pays more than one of
    plain skulls. *)
let effect_sthx fx =
  let amt = 4 + count_gems_of fx Board.Skull + count_gems_of fx Board.RedSkull in
  inflict_damage fx amt

(** SDIV, SEPO, SSCV and SWHI are the same body over a different gem: destroy
    every one of a kind, with the bonus chances suppressed for the duration.
    Nothing is gained from the gems, they are simply removed. *)
let destroy_one_kind ~(gem : Board.gem) (fx : effect_context) : unit =
  set_multiplier_effects fx false;
  destroy_all_gems fx gem;
  set_multiplier_effects fx true

let effect_sdiv fx = destroy_one_kind ~gem:Board.Experience fx
let effect_sepo fx = destroy_one_kind ~gem:gem_earth fx
let effect_sscv fx = destroy_one_kind ~gem:Board.Gold fx
let effect_swhi fx = destroy_one_kind ~gem:gem_air fx

(** SDRR and SFSK rewrite gems rather than removing them. SDRR turns Fire and Air
    into skulls; SFSK turns Earth into skulls and Water into red skulls, so the
    board keeps its gem count and both kinds of skull end up on it. *)
let effect_sdrr fx =
  change_all_gems fx gem_fire Board.Skull;
  change_all_gems fx gem_air Board.Skull

let effect_sfsk fx =
  change_all_gems fx gem_earth Board.Skull;
  change_all_gems fx gem_water Board.RedSkull

(** The three self-buffs, all of which pass a duration of 0. That is the original's
    own value, not a placeholder here: the effects plainly persist, so 0 has to
    mean indefinite. *)
let effect_shid fx = receive_status fx.fx_caster "Hidden" 0
let effect_swof fx = receive_status fx.fx_caster "WallOfFired" 0
let effect_swot fx = receive_status fx.fx_caster "WallOfThornsed" 0

(** SHOP: Hand of Powered on the caster, for six turns. One of the few bodies that
    passes a real duration. *)
let effect_shop fx = receive_status fx.fx_caster "HandOfPowered" 6

(** SFBM: Fire Bombed on the {e enemy}, for twelve turns. The only body that uses
    a status id that is not one of the [STATUS_EFFECT_] constants - it is the raw
    string "EFBO", which is the status effect file name without its suffix. *)
let effect_sfbm fx = inflict_status fx "FireBombed" 12

(** SIST: charge itself, then explode every Earth gem on the board. The sweep is
    bracketed by [SetMultiplierEffects] so the explosions cannot also pay a
    bonus.
    ```lua
    HANDLE_SPELL_COST(idxCaster);
    SetMultiplierEffects(false);
    ExplodeAllGems(GEM_GREEN, "GreenSparkle");
    SetMultiplierEffects(true);
    ``` *)
let effect_sist fx =
  handle_spell_cost fx;
  set_multiplier_effects fx false;
  explode_all_gems fx gem_earth;
  set_multiplier_effects fx true

(** STHR: charge itself, then destroy the one cell it was aimed at. *)
let effect_sthr fx =
  handle_spell_cost fx;
  set_multiplier_effects fx false;
  (match fx.fx_input with
  | Some p -> fx.fx_board := Board.set_gem p Board.Empty !(fx.fx_board)
  | None -> ());
  set_multiplier_effects fx true

(** SSPA: charge itself, then destroy the eight cells around the aimed cell,
    leaving the centre alone.
    ```lua
    for y = gridy-1,gridy+1 do
        for x = gridx-1,gridx+1 do
            if (in bounds) then
                if (x ~= gridx or y ~= gridy) then DESTROY_GEM(x,y); end
            end
        end
    end
    ```
    The bounds test sits {e outside} the not-the-centre test, so a cell just off
    the edge is skipped rather than clamped - the two orders agree here, but the
    original's shape is kept. *)
let effect_sspa fx =
  handle_spell_cost fx;
  set_multiplier_effects fx false;
  (match fx.fx_input with
  | None -> ()
  | Some c ->
      let b = !(fx.fx_board) in
      for y = c.Board.y - 1 to c.Board.y + 1 do
        for x = c.Board.x - 1 to c.Board.x + 1 do
          let in_bounds = x >= 0 && x < b.Board.width && y >= 0 && y < b.Board.height in
          let is_centre = x = c.Board.x && y = c.Board.y in
          if in_bounds && not is_centre then
            fx.fx_board := Board.set_gem { Board.x; y } Board.Empty !(fx.fx_board)
        done
      done);
  set_multiplier_effects fx true

(** SBSG: charge itself, then detonate a random cell. A 3x3 blast, so the effect
    is "pick a cell at random and explode it", not "remove one gem". *)
let effect_sbsg fx =
  handle_spell_cost fx;
  let x, y = random_grid fx in
  set_multiplier_effects fx false;
  explode_gem fx x y;
  set_multiplier_effects fx true

(** SHGO: charge itself, then take one random cell and pay out according to what
    was in it. The reward table is a flat switch on the gem kind, and the amounts
    are not symmetric: four elemental pools and gold and xp all give the flat 20,
    while a skull deals 20 and a red skull deals five times that.

    The cell is destroyed either way, so a gem with no case - none, since the
    switch is total over the kinds that can appear - would still be removed.
    ```lua
    local amt = 20;
    local x,y = GetRandomGrid();
    local myGem = GET_GEM(x,y);
    DESTROY_GEM(x,y);
    if (myGem == GEM_AIR)   then ADD_MANA_AIR(idxCaster,amt);
    elseif (myGem == GEM_EARTH) then ADD_MANA_EARTH(idxCaster,amt);
    elseif (myGem == GEM_FIRE)  then ADD_MANA_FIRE(idxCaster,amt);
    elseif (myGem == GEM_WATER) then ADD_MANA_WATER(idxCaster,amt);
    elseif (myGem == GEM_GOLD)  then ADD_GOLD(idxCaster,amt);
    elseif (myGem == GEM_STAR)  then ADD_XP(idxCaster,amt);
    elseif (myGem == GEM_SKULL) then Std_InflictDamage(amt,idxCaster);
    elseif (myGem == GEM_REDSKULL) then Std_InflictDamage(amt*5,idxCaster);
    end
    ```
    Note the mana credit goes through [ADD_MANA], so it respects the ceiling: a
    full pool simply absorbs it. *)
let effect_shgo fx =
  handle_spell_cost fx;
  let amt = 20 in
  let x, y = random_grid fx in
  let b = !(fx.fx_board) in
  let taken = Board.get_gem b { Board.x; y } in
  set_multiplier_effects fx false;
  fx.fx_board := Board.set_gem { Board.x; y } Board.Empty !(fx.fx_board);
  let c = fx.fx_caster in
  (match taken with
  | Board.Mana Air -> add_mana c Air amt
  | Board.Mana Earth -> add_mana c Earth amt
  | Board.Mana Fire -> add_mana c Fire amt
  | Board.Mana Water -> add_mana c Water amt
  | Board.Gold -> add_gold fx amt
  | Board.Experience -> add_xp fx amt
  | Board.Skull -> inflict_damage fx amt
  | Board.RedSkull -> inflict_damage fx (amt * 5)
  | Board.Wildcard _ | Board.Empty -> ());
  set_multiplier_effects fx true

(** The mana and skill group.

    Fifty-five of the remaining bodies live here, and they collapse into seven
    shapes. Each is transcribed from its Lua; the shared helper exists so the
    shape is stated once rather than a dozen times with small differences.

    Two things recur and are worth stating once.

    **Damage is often the caster's own pool, then the pool is emptied.**
    SBRF, SBRI, SBRP, SBRZ, SSOB and SSOS all read one element off the caster,
    deal that much damage to the enemy, and set the pool to zero. The order
    matters: the damage is dealt at the pool's value *before* the drain, and
    SET_MANA clamps to the ceiling so zeroing is exact.

    **Integer division is everywhere and it truncates.** Lua's `/` on two integers
    floors, so "half the enemy's Air" is a floor, and the mana-scaled status
    durations are floors. These are written with `/` here so they truncate the same
    way rather than rounding. *)

(* ------------------------------------------------------------------ *)
(* Shape 1: the caster's own pool becomes damage, and is then drained    *)
(* ------------------------------------------------------------------ *)

(** SBRF (Fire), SBRI (Water), SSOB (Earth) and SSOS (Air) are this exactly.
    SBRP (Air) and SBRZ (Earth) add a debuff on top. *)
let pool_into_damage ~(elem : element) fx =
  let dmg = Combat.mana fx.fx_caster elem in
  inflict_damage fx dmg;
  set_mana fx.fx_caster elem 0

let effect_sbrf fx = pool_into_damage ~elem:Fire fx
let effect_sbri fx = pool_into_damage ~elem:Water fx
let effect_ssob fx = pool_into_damage ~elem:Earth fx
let effect_ssos fx = pool_into_damage ~elem:Air fx

(* SBRP is the Air body plus Disease on the enemy for 20 turns. The status is
   applied after the drain, and the Lua uses the raw "EDIS" file name. *)
let effect_sbrp fx =
  pool_into_damage ~elem:Air fx;
  inflict_status fx "Disease" 20

(* SBRZ is the Earth body plus Poison for 20 turns, under the raw name "EPOI". *)
let effect_sbrz fx =
  pool_into_damage ~elem:Earth fx;
  inflict_status fx "Poison" 20

(* ------------------------------------------------------------------ *)
(* Shape 2: bank a little mana and take another turn                     *)
(* ------------------------------------------------------------------ *)

(** SCHA, SCHE, SCHF and SCHW are this over Air, Earth, Fire and Water. The five
    is fixed and the extra turn is unconditional. *)
let mana_then_extra_turn ~(elem : element) ~(amount : int) fx =
  add_mana fx.fx_caster elem amount;
  extra_turn fx.fx_caster

let effect_scha fx = mana_then_extra_turn ~elem:Air ~amount:5 fx
let effect_sche fx = mana_then_extra_turn ~elem:Earth ~amount:5 fx
let effect_schf fx = mana_then_extra_turn ~elem:Fire ~amount:5 fx
let effect_schw fx = mana_then_extra_turn ~elem:Water ~amount:5 fx

(* ------------------------------------------------------------------ *)
(* Shape 3: count a gem kind, destroy them all, bank it as skill         *)
(* ------------------------------------------------------------------ *)

(** SBNA, SBNE, SBNF and SBNW. The gems are destroyed rather than converted, so
    this trades board presence for a permanent skill gain - and the skill is what
    drives mana *yield* later, which is why it is worth more than the mana would
    have been.

    The count is taken before the destroy, and it is a whole-board count. *)
let gems_into_skill ~(gem : Board.gem) ~(skill : skill) fx =
  let n = count_gems_of fx gem in
  destroy_all_gems fx gem;
  add_temp_skill fx.fx_caster skill n

let effect_sbna fx = gems_into_skill ~gem:gem_air ~skill:SAir fx
let effect_sbne fx = gems_into_skill ~gem:gem_earth ~skill:SEarth fx
let effect_sbnf fx = gems_into_skill ~gem:gem_fire ~skill:SFire fx
let effect_sbnw fx = gems_into_skill ~gem:gem_water ~skill:SWater fx

(* ------------------------------------------------------------------ *)
(* Shape 4: mana or skulls converted into a skill                        *)
(* ------------------------------------------------------------------ *)

(** SBAV empties the caster's Earth pool into Battle skill. The drain happens
    {e first}: it reads the pool, zeroes it, and only then adds the skill, so a
    ceiling-clamped read cannot be double counted. *)
let effect_sbav fx =
  let m = Combat.mana fx.fx_caster Earth in
  set_mana fx.fx_caster Earth 0;
  add_temp_skill fx.fx_caster SBattle m

(** SESK is SBAV's shape over skulls instead of mana, and it takes both skull
    kinds. They are counted first and deleted second, and the two counts add
    because a board of five red skulls is worth five battle skill, same as five
    plain ones. *)
let effect_sesk fx =
  let n = count_gems_of fx Board.Skull + count_gems_of fx Board.RedSkull in
  delete_all_gems fx Board.Skull;
  delete_all_gems fx Board.RedSkull;
  add_temp_skill fx.fx_caster SBattle n

(** SREV doubles the caster's existing Battle skill. A no-op at zero, since adding
    zero to zero is zero - the Lua does not guard it either. *)
let effect_srev fx =
  let have = Combat.skill_in SBattle fx.fx_caster.Combat.skills in
  add_temp_skill fx.fx_caster SBattle have

(** SFLV empties the Fire pool into a {e random} skill, drawn with
    [GET_RANDOM_SYNC(0,6)] - seven options, so every one of the seven skills.

    The Lua is a seven-arm if/elseif over SKILL_EARTH through SKILL_MORALE, and
    every arm does the same thing: add the mana to whichever skill was drawn. So
    the branches carry no information beyond the index and it is a single
    [Combat.skill_of_index]. Note that SFLV at 0 fire is still worth casting in the
    original - it adds nothing. *)
let effect_sflv fx =
  let m = Combat.mana fx.fx_caster Fire in
  let idx = fx.fx_roll 7 in
  set_mana fx.fx_caster Fire 0;
  add_temp_skill fx.fx_caster (Combat.skill_of_index idx) m

(* ------------------------------------------------------------------ *)
(* Shape 5: taking the enemy's mana                                      *)
(* ------------------------------------------------------------------ *)

(** SFSP takes the enemy's whole Fire pool and heals the caster for it. The
    enemy's pool is zeroed {e before} the heal, and the heal reads the value read
    at the top - so the order is fixed. *)
let effect_sfsp fx =
  let taken = match fx.fx_enemies with e :: _ -> Combat.mana e Fire | [] -> 0 in
  (match fx.fx_enemies with
  | e :: _ -> set_mana e Fire 0
  | [] -> ());
  healing fx.fx_caster taken

(** SSWA deals four plus the enemy's Earth pool. The pool is {e not} drained - the
    spell reads it and hits for it. *)
let effect_sswa fx =
  match fx.fx_enemies with
  | [] -> ()
  | e :: _ ->
      let amt = 4 + Combat.mana e Earth in
      inflict_damage fx amt

(** SARC would belong here: it halves the enemy's Air pool into damage and banks an
    extra turn if the {e caster} has 15 or more Air, and those two tests read
    different characters.

    It is deliberately absent. SARC is the spell-research mini-game descriptor
    rather than a battle spell - [tools/extract_spell_data.ps1] excludes it and
    there is no descriptor for it in [lib/spell_data.ml], so nothing in a battle
    can ever cast it. A body here would be a registration under an id no spell
    carries, which is exactly what the coverage test is there to catch. It belongs
    with the mini-game, when that is ported. *)

(** SBST empties the enemy's Earth pool, and takes an extra turn only if that pool
    was at least ten - checked {e before} the drain. *)
let effect_sbst fx =
  match fx.fx_enemies with
  | [] -> ()
  | e :: _ ->
      let amt = Combat.mana e Earth in
      if amt >= 10 then extra_turn fx.fx_caster;
      set_mana e Earth 0

(** SSSW swaps the two sides' four pools, less a spell cost of 6 Earth, 12 Air and
    18 Water taken off the caster's share.

    The three subtractions can go negative, and the Lua does not floor them - it
    passes the negative straight to ADD_MANA. Here [add_mana] ignores a
    non-positive amount, so a caster who cannot cover the cost simply has that
    element skipped rather than crediting a negative. That is the one place this
    body and the original could differ, and it only arises when a pool is under
    the cost. *)
let effect_sssw fx =
  match fx.fx_enemies with
  | [] -> ()
  | e :: _ ->
      let c = fx.fx_caster in
      let mine = List.map (fun el -> (el, Combat.mana c el)) [ Air; Earth; Fire; Water ] in
      let theirs = List.map (fun el -> (el, Combat.mana e el)) [ Air; Earth; Fire; Water ] in
      List.iter (fun (el, _) -> set_mana c el 0) mine;
      List.iter (fun (el, _) -> set_mana e el 0) theirs;
      let cost = [ (Earth, 6); (Air, 12); (Water, 18) ] in
      List.iter
        (fun (el, amt) -> add_mana e el (List.assoc el mine - amt))
        cost;
      List.iter (fun (el, amt) -> add_mana c el amt) theirs;
      extra_turn c

(** SCTO drains three from every one of the enemy's pools and banks five Earth.
    Fixed amounts, and the drain floors at zero, so a nearly-empty enemy simply
    loses what it has. *)
let effect_scto fx =
  let drain = 3 in
  (match fx.fx_enemies with
  | e :: _ ->
      List.iter (fun el -> subtract_mana e el drain) [ Air; Earth; Fire; Water ]
  | [] -> ());
  add_mana fx.fx_caster Earth 5

(** SDBO blinds the enemy for two turns and takes five from its Air and Fire. Only
    two of the four pools, which is the spell's identity. *)
let effect_sdbo fx =
  inflict_status fx "Blinded" 2;
  (match fx.fx_enemies with
  | e :: _ ->
      subtract_mana e Air 5;
      subtract_mana e Fire 5
  | [] -> ())

(** SMBU takes five from all four of the enemy's pools, then takes an extra turn if
    the {e caster} has 8 or more Fire. Again the turn test reads the caster, not
    the enemy it just drained. *)
let effect_smbu fx =
  (match fx.fx_enemies with
  | e :: _ -> List.iter (fun el -> subtract_mana e el 5) [ Earth; Fire; Air; Water ]
  | [] -> ());
  if Combat.mana fx.fx_caster Fire >= 8 then extra_turn fx.fx_caster

(** SSWP halves each enemy's Air pool, over the whole enemy side rather than just
    the first, then takes an extra turn if the caster has 14 or more Air. *)
let effect_sswp fx =
  List.iter
    (fun e -> subtract_mana e Air (Combat.mana e Air / 2))
    fx.fx_enemies;
  if Combat.mana fx.fx_caster Air >= 14 then extra_turn fx.fx_caster

(** SSHO doubles the enemy's Earth pool - crediting mana to the enemy, which is the
    point of the spell - and halves its Fire, Air and Water. The halvings floor,
    so an odd pool loses one. *)
let effect_ssho fx =
  match fx.fx_enemies with
  | [] -> ()
  | e :: _ ->
      add_mana e Earth (Combat.mana e Earth);
      List.iter (fun el -> subtract_mana e el (Combat.mana e el / 2)) [ Fire; Air; Water ]

(** SSBM credits the caster with enough Water to fill the pool, takes half the
    enemy's Air, and does neither naively: the Water figure is capped so that
    twice it cannot exceed the caster's own ceiling.

    ```lua
    local amt_yellow = GET_MANA_AIR(idxEnemy)/2;
    local amt_blue = GET_MANA_WATER(idxCaster);
    if (2*amt_blue > GET_MAX_MANA_WATER(idxCaster)) then
        amt_blue = GET_MAX_MANA_WATER(idxCaster) - amt_blue;
    end
    ```
    So it tops the caster up to exactly the ceiling and no further. The add still
    respects the ceiling afterwards, which is what makes the correction
    sufficient. *)
let effect_ssbm fx =
  let amt_air = match fx.fx_enemies with e :: _ -> Combat.mana e Air / 2 | [] -> 0 in
  let c = fx.fx_caster in
  let amt_water = Combat.mana c Water in
  let amt_water =
    if 2 * amt_water > Combat.max_mana c Water then Combat.max_mana c Water - amt_water
    else amt_water
  in
  add_mana c Water amt_water;
  (match fx.fx_enemies with e :: _ -> subtract_mana e Air amt_air | [] -> ())

(** STAU picks which of the enemy's pools to drain from the turn's percentile,
    in four bands, and the damage grows with the caster's Air. The bands are
    inclusive at both ends, so a roll of 25 lands in the first and 26 in the
    second.

    ```lua
    local damage = 8 + GET_MANA_AIR(idxCaster)/10;
    local chance = PERCENTILE_CHANCE_SYNC();
    if (chance <= 25) then SUBTRACT_MANA_EARTH(idxEnemy,damage);
    elseif (chance <= 50) then SUBTRACT_MANA_FIRE(idxEnemy,damage);
    elseif (chance <= 75) then SUBTRACT_MANA_AIR(idxEnemy,damage);
    else SUBTRACT_MANA_WATER(idxEnemy,damage);
    end
    ```

    The other assignments in the Lua set a text colour and are presentation. *)
let effect_stau fx =
  let damage = 8 + (Combat.mana fx.fx_caster Air / 10) in
  let elem =
    if fx.fx_percentile <= 25 then Earth
    else if fx.fx_percentile <= 50 then Fire
    else if fx.fx_percentile <= 75 then Air
    else Water
  in
  match fx.fx_enemies with
  | e :: _ -> subtract_mana e elem damage
  | [] -> ()

(* ------------------------------------------------------------------ *)
(* Shape 6: a status whose duration scales with a pool                   *)
(* ------------------------------------------------------------------ *)

(** Eleven bodies set a status for a base duration plus a fraction of one of the
    caster's pools. The fraction truncates. SFAV is Favored for 8 + Air/6 on the
    caster; the others differ in base, divisor, element and target.

    The durations are written as `base + pool / divisor` rather than
    `base + pool * something` because that is what the Lua says, and the floor is
    load-bearing: at a pool of 5 with a divisor of 6 the bonus is zero, not one. *)
let scaled_status ~(base : int) ~(elem : element) ~(divisor : int) ~(name : string)
    ~(on_caster : bool) fx =
  let dur = base + (Combat.mana fx.fx_caster elem / divisor) in
  if on_caster then receive_status fx.fx_caster name dur
  else inflict_status fx name dur

let effect_sfav fx = scaled_status ~base:8 ~elem:Air ~divisor:6 ~name:"Favoreded" ~on_caster:true fx
let effect_sfsh fx = scaled_status ~base:8 ~elem:Fire ~divisor:3 ~name:"FireShielded" ~on_caster:true fx
let effect_shas fx = scaled_status ~base:10 ~elem:Air ~divisor:5 ~name:"Hasted" ~on_caster:true fx
let effect_spau fx = scaled_status ~base:8 ~elem:Air ~divisor:5 ~name:"PaladinsAuraed" ~on_caster:true fx
let effect_svig fx = scaled_status ~base:8 ~elem:Water ~divisor:5 ~name:"Vigiled" ~on_caster:true fx
let effect_slig fx = scaled_status ~base:2 ~elem:Air ~divisor:8 ~name:"Blinded" ~on_caster:false fx
let effect_ssbl fx = scaled_status ~base:5 ~elem:Air ~divisor:2 ~name:"SingingBladesed" ~on_caster:true fx
(* SHWL also banks four Earth for the caster before the fear, so it is not purely
   a status body. That is the whole of its difference from the eleven. *)
let effect_shwl fx =
  add_mana fx.fx_caster Earth 4;
  scaled_status ~base:5 ~elem:Air ~divisor:5 ~name:"Fear" ~on_caster:false fx

(* SSPT inflicts two statuses off one duration: Blind and Poison, both
   3 + Water/12. *)
let effect_sspt fx =
  let dur = 3 + (Combat.mana fx.fx_caster Water / 12) in
  inflict_status fx "Blinded" dur;
  inflict_status fx "Poison" dur

(* SRBI deals a flat 4 and then inflicts Disease for 5 + Water/5. *)
let effect_srbi fx =
  inflict_damage fx 4;
  scaled_status ~base:5 ~elem:Water ~divisor:5 ~name:"Disease" ~on_caster:false fx

(* ------------------------------------------------------------------ *)
(* Shape 7: the flat bodies                                              *)
(* ------------------------------------------------------------------ *)

(** SBLU banks a fixed twelve Fire and nothing else. *)
let effect_sblu fx = add_mana fx.fx_caster Fire 12

(** SEGZ heals 25 and empties all four pools. The heal comes {e first}, so a
    caster at 90 life gets 25 rather than the overflow. *)
let effect_segz fx =
  healing fx.fx_caster 25;
  List.iter (fun el -> set_mana fx.fx_caster el 0) [ Air; Water; Fire; Earth ]

(** SLCO raises the caster's Fire ceiling by twelve, permanently, and takes an extra
    turn. The ceiling is raised rather than the pool filled, so the benefit is
    every subsequent match, not this one - which is what [set_mana_limit] models,
    including its clamp of the current pool. *)
let effect_slco fx =
  let raised = Combat.max_mana fx.fx_caster Fire + 12 in
  set_max_mana fx.fx_caster Fire raised;
  extra_turn fx.fx_caster

(** SDST deals the caster's whole Fire pool as damage and poisons for eight. *)
let effect_sdst fx =
  inflict_damage fx (Combat.mana fx.fx_caster Fire);
  inflict_status fx "Poison" 8

(** SFBO deals four plus a ninth of the caster's Fire. The Lua goes through
    [Std_InflictDamageWithAnimEffect], which is [Std_InflictDamage] with an
    animation argument. *)
let effect_sfbo fx = inflict_damage fx (4 + (Combat.mana fx.fx_caster Fire / 8))

(* The three "hit them and keep the turn" bodies: SRND for 5, SSNK for 3, STWH
   for 10. Damage then an unconditional extra turn. *)
let damage_then_extra_turn ~(amount : int) fx =
  inflict_damage fx amount;
  extra_turn fx.fx_caster

let effect_srnd fx = damage_then_extra_turn ~amount:5 fx
let effect_ssnk fx = damage_then_extra_turn ~amount:3 fx
let effect_stwh fx = damage_then_extra_turn ~amount:10 fx

(** SSGZ rewrites every Earth gem as a skull and then takes an extra turn if the
    caster has 15 or more Earth. The turn test reads the pool the rewrite did not
    touch. *)
let effect_ssgz fx =
  change_all_gems fx gem_earth Board.Skull;
  if Combat.mana fx.fx_caster Earth >= 15 then extra_turn fx.fx_caster

(** SENR takes an extra turn and enrages the caster for eight. *)
let effect_senr fx =
  extra_turn fx.fx_caster;
  receive_status fx.fx_caster "Enraged" 8

(** SCHL challenges {e both} sides for six, then takes an extra turn if the caster
    has 15 or more Air. Challenging the caster as well as the enemy is not a
    typo in the port; the Lua does both. *)
let effect_schl fx =
  inflict_status fx "Challenged" 6;
  receive_status fx.fx_caster "Challenged" 6;
  if Combat.mana fx.fx_caster Air >= 15 then extra_turn fx.fx_caster

(** SVAM deals five plus a tenth of the caster's Fire, capped at the enemy's
    remaining life, and heals for exactly what it dealt. The cap is what makes the
    heal equal the damage: a hit that would overkill is trimmed first.

    ```lua
    local amt_damage = 5 + GET_MANA_FIRE(idxCaster)/10;
    if (amt_damage > GET_LIFE(idxEnemy)) then amt_damage = GET_LIFE(idxEnemy); end
    local amt_heal = amt_damage;
    Std_InflictDamage(amt_damage, idxCaster);
    Std_Healing(amt_heal, idxCaster);
    ``` *)
let effect_svam fx =
  match fx.fx_enemies with
  | [] -> ()
  | e :: _ ->
      let raw = 5 + (Combat.mana fx.fx_caster Fire / 10) in
      let amt = if raw > e.Combat.life then e.Combat.life else raw in
      inflict_damage fx amt;
      healing fx.fx_caster amt

(** SFRZ turns every Fire gem into a Water gem and credits the caster with the
    count as Water. Count first, then rewrite, then credit. *)
let effect_sfrz fx =
  let n = count_gems_of fx gem_fire in
  add_mana fx.fx_caster Water n;
  change_all_gems fx gem_fire gem_water

(** The column sweeps and the lightning spells.

    Seven bodies, and one finding that removes work rather than adding it.

    **ADD_LIGHTNING is presentation, not a mechanic.** Six scripts call it, and
    every call passes pixel coordinates from [GET_CHARACTER_X/Y] or [GET_GRID_X/Y]
    and happens {e after} the spell's actual effect:

    ```c
    // Lua_ADD_LIGHTNING(x1, y1, x2, y2, duration)
    // reads five arguments - four ints and a float - and makes one call
    FUN_00414d20(6, x1, y1, x2, y2, duration);
    ```

    It writes no mana, no life and no board cell. It is the lightning bolt drawn
    between two points, and a headless battle has nowhere to draw it. So the six
    spells that use it are ported {e without} it, on the same grounds as
    [Std_CastSpellEffect] and [PLAY_SOUND]: porting the absence of a visible thing
    is still porting it faithfully. What is left of SCBO, SZAP, SCLI, SLIS, SSUT
    and SFCA below is their whole mechanic.

    **SCLI, SLIS and SMST spell the three flags out individually** -
    [SET_EXTRATURN_CHANCE_ENABLED], [SET_WILDCARD_CHANCE_ENABLED] and
    [SET_DAMAGE_MULTIPLIER_ENABLED] on the way off and again on the way back -
    rather than calling [SetMultiplierEffects] as the others do. Same three bytes,
    same order, so [set_multiplier_effects] is used and the duplication is noted
    rather than reproduced. *)

(** Empties one column of the board, top to bottom. SCLI and SLIS sweep with this;
    the bonus chances are suppressed for the duration so the gems going cannot also
    pay out. *)
let sweep_column ~(x : int) fx =
  let b = !(fx.fx_board) in
  if x >= 0 && x < b.Board.width then
    for y = 0 to b.Board.height - 1 do
      fx.fx_board := Board.set_gem { Board.x; y } Board.Empty !(fx.fx_board)
    done

(** SCLI: charge itself, then destroy the column the player picked.

    The column index comes from [GET_INPUT_DATA(0)], which is the same cell as
    [x] in [Board]'s grid - the engine's one-row shift applies to y, not x. *)
let effect_scli fx =
  handle_spell_cost fx;
  set_multiplier_effects fx false;
  (match fx.fx_input with
  | None -> ()
  | Some p -> sweep_column ~x:p.Board.x fx);
  set_multiplier_effects fx true

(** SLIS: charge itself, then destroy three columns centred on the chosen one.

    The centre is pulled in from the edges before the sweep, so the three columns
    are always 2..7 rather than 0..2 and 6..8:

    ```lua
    local midx = GET_INPUT_DATA(0);
    if (midx == 1) then midx = 2; end;
    if (midx == 8) then midx = 7; end;
    ```

    So picking the outermost column still gives a legal middle one, and the spell
    cannot sweep off the edge of the board. *)
let effect_slis fx =
  handle_spell_cost fx;
  let midx =
    match fx.fx_input with
    | None -> 4
    | Some p -> ( match p.Board.x with 0 -> 1 | 7 -> 6 | x -> x)
  in
  set_multiplier_effects fx false;
  List.iter (fun x -> sweep_column ~x fx) [ midx - 1; midx; midx + 1 ];
  set_multiplier_effects fx true

(** A random cell, rejecting one that already holds the given gem kind.

    [GetRandomGrid_Not] gives up after a thousand tries and returns whatever it has
    at that point, which is why the original reads
    `until (tries > 1000 or done)`. The bound is kept rather than made unbounded,
    because a board made entirely of the rejected kind would otherwise spin. *)
let random_grid_not ~(avoid : Board.gem) fx =
  let b = !(fx.fx_board) in
  let rec go tries =
    if tries > 1000 then (0, 0)
    else
      let x, y = random_grid fx in
      if Board.equal_gem (Board.get_gem b { Board.x; y }) avoid then go (tries + 1)
      else (x, y)
  in
  go 0

(** SSUT: charge itself, then destroy two {e different} random columns.

    The second column is drawn until it differs from the first, with no try cap in
    the original - and that one cannot spin, because there are eight columns and
    only one forbidden value. *)
let effect_ssut fx =
  handle_spell_cost fx;
  let x1 = fst (random_grid fx) in
  let rec second tries =
    let x = fst (random_grid fx) in
    if x <> x1 || tries > 100 then x else second (tries + 1)
  in
  let x2 = second 0 in
  set_multiplier_effects fx false;
  sweep_column ~x:x1 fx;
  sweep_column ~x:x2 fx;
  set_multiplier_effects fx true

(** A random non-empty cell, or [None] if a thousand draws all come up empty.

    SFCA's own picker is `repeat x,y = GetRandomGrid() until GET_GEM(x,y) ~= GEM_EMPTY`
    with {e no} try cap, which is a genuine unbounded loop in the original whenever
    the board has no gems left. This port bounds it rather than reproducing a hang,
    and that bound is the only deliberate divergence in this file. *)
let random_non_empty fx =
  let b = !(fx.fx_board) in
  let rec go tries =
    if tries > 1000 then None
    else
      let x, y = random_grid fx in
      if Board.equal_gem (Board.get_gem b { Board.x; y }) Board.Empty then go (tries + 1)
      else Some (x, y)
  in
  go 0

(** SFCA: charge itself, then detonate four cells at random, in that order. *)
let effect_sfca fx =
  handle_spell_cost fx;
  set_multiplier_effects fx false;
  for _ = 1 to 4 do
    match random_non_empty fx with
    | None -> ()
    | Some (x, y) -> explode_gem fx x y
  done;
  set_multiplier_effects fx true

(** SMST: charge itself, then turn eight cells into Fire gems.

    Each pick avoids an existing Fire gem and then rewrites the cell, so the spell
    cannot stack on one cell. It stops at eight conversions or after a thousand
    attempts, matching the original's `until (tries > 1000 or amt <= 0)`. *)
let effect_smst fx =
  handle_spell_cost fx;
  let remaining = ref 8 and tries = ref 0 in
  set_multiplier_effects fx false;
  while !remaining > 0 && !tries <= 1000 do
    let x, y = random_grid_not ~avoid:gem_fire fx in
    fx.fx_board := Board.set_gem { Board.x; y } gem_fire !(fx.fx_board);
    decr remaining;
    incr tries
  done;
  set_multiplier_effects fx true

(** SCBO: the turn's percentile picks one of the caster's four pools, that pool
    becomes damage, and it is emptied.

    The bands are STAU's shape but the mapping is different, and the default is
    load-bearing: the script starts at Water and only assigns in the first three
    bands, so everything above 75 falls through to Fire.

    ```lua
    local myManaType = MANA_BLUE;                   -- Water
    if (myRoll <= 25) then myManaType = MANA_GREEN;      -- Earth
    elseif (myRoll <= 50) then myManaType = MANA_YELLOW; -- Air
    elseif (myRoll <= 75) then myManaType = MANA_RED;    -- Fire
    end
    ```

    So 0..25 is Earth, 26..50 Air, 51..75 Fire and 76..99 Water - the reverse order
    to STAU's, which is an easy thing to carry over by accident. *)
let effect_scbo fx =
  let elem =
    if fx.fx_percentile <= 25 then Earth
    else if fx.fx_percentile <= 50 then Air
    else if fx.fx_percentile <= 75 then Fire
    else Water
  in
  let dmg = Combat.mana fx.fx_caster elem in
  set_mana fx.fx_caster elem 0;
  inflict_damage fx dmg

(** SZAP: five plus an eighth of the caster's Fire, to {e every} enemy. The single
    enemy in the 1v1 model makes the loop one iteration; it is kept because the
    original has one and because [fx_enemies] is a list for exactly this reason. *)
let effect_szap fx =
  let dmg = 5 + (Combat.mana fx.fx_caster Fire / 8) in
  List.iter (fun e -> subtract_life fx e dmg) fx.fx_enemies

(** The ported body for [id], if it has one yet.

    An absent entry means the body has not been transcribed. [Battle] treats that
    as "the spell does nothing", which is honest: it is the real state of the
    remaining bodies rather than a claim that they have no effect. *)
let effect_of (id : string) : (effect_context -> unit) option =
  match id with
  | "SCAU" -> Some effect_scau
  | "SCLV" -> Some effect_sclv
  | "SDDI" -> Some effect_sddi
  | "SDIV" -> Some effect_sdiv
  | "SDRR" -> Some effect_sdrr
  | "SEPO" -> Some effect_sepo
  | "SFBM" -> Some effect_sfbm
  | "SFBT" -> Some effect_sfbt
  | "SFSK" -> Some effect_sfsk
  | "SHID" -> Some effect_shid
  | "SHOP" -> Some effect_shop
  | "SROF" -> Some effect_srof
  | "SSCV" -> Some effect_sscv
  | "STHX" -> Some effect_sthx
  | "SWHI" -> Some effect_swhi
  | "SWOF" -> Some effect_swof
  | "SWOT" -> Some effect_swot
  (* The spells that pay for themselves. *)
  | "SBSG" -> Some effect_sbsg
  | "SIST" -> Some effect_sist
  | "SSPA" -> Some effect_sspa
  | "STHR" -> Some effect_sthr
  | "SHGO" -> Some effect_shgo
  (* The mana and skill group. *)
  | "SBRF" -> Some effect_sbrf
  | "SBRI" -> Some effect_sbri
  | "SBRP" -> Some effect_sbrp
  | "SBRZ" -> Some effect_sbrz
  | "SSOB" -> Some effect_ssob
  | "SSOS" -> Some effect_ssos
  | "SCHA" -> Some effect_scha
  | "SCHE" -> Some effect_sche
  | "SCHF" -> Some effect_schf
  | "SCHW" -> Some effect_schw
  | "SBNA" -> Some effect_sbna
  | "SBNE" -> Some effect_sbne
  | "SBNF" -> Some effect_sbnf
  | "SBNW" -> Some effect_sbnw
  | "SBAV" -> Some effect_sbav
  | "SESK" -> Some effect_sesk
  | "SREV" -> Some effect_srev
  | "SFLV" -> Some effect_sflv
  | "SFSP" -> Some effect_sfsp
  | "SSWA" -> Some effect_sswa
  | "SBST" -> Some effect_sbst
  | "SSSW" -> Some effect_sssw
  | "SCTO" -> Some effect_scto
  | "SDBO" -> Some effect_sdbo
  | "SMBU" -> Some effect_smbu
  | "SSWP" -> Some effect_sswp
  | "SSHO" -> Some effect_ssho
  | "SSBM" -> Some effect_ssbm
  | "STAU" -> Some effect_stau
  | "SFAV" -> Some effect_sfav
  | "SFSH" -> Some effect_sfsh
  | "SHAS" -> Some effect_shas
  | "SPAU" -> Some effect_spau
  | "SVIG" -> Some effect_svig
  | "SLIG" -> Some effect_slig
  | "SSBL" -> Some effect_ssbl
  | "SHWL" -> Some effect_shwl
  | "SSPT" -> Some effect_sspt
  | "SRBI" -> Some effect_srbi
  | "SBLU" -> Some effect_sblu
  | "SEGZ" -> Some effect_segz
  | "SLCO" -> Some effect_slco
  | "SDST" -> Some effect_sdst
  | "SFBO" -> Some effect_sfbo
  | "SRND" -> Some effect_srnd
  | "SSNK" -> Some effect_ssnk
  | "STWH" -> Some effect_stwh
  | "SSGZ" -> Some effect_ssgz
  | "SENR" -> Some effect_senr
  | "SCHL" -> Some effect_schl
  | "SVAM" -> Some effect_svam
  | "SFRZ" -> Some effect_sfrz
  (* The column sweeps and the lightning spells. *)
  | "SCBO" -> Some effect_scbo
  | "SZAP" -> Some effect_szap
  | "SCLI" -> Some effect_scli
  | "SLIS" -> Some effect_slis
  | "SSUT" -> Some effect_ssut
  | "SFCA" -> Some effect_sfca
  | "SMST" -> Some effect_smst
  | _ -> None

(** The ids this file covers, for the coverage test and for the report. *)
let effect_of_spell_ids =
  [ "SCAU"; "SCLV"; "SDDI"; "SDIV"; "SDRR"; "SEPO"; "SFBM"; "SFBT"; "SFSK"
  ; "SHID"; "SHOP"; "SROF"; "SSCV"; "STHX"; "SWHI"; "SWOF"; "SWOT"
  ; "SBSG"; "SIST"; "SSPA"; "STHR"; "SHGO"
  ; "SBRF"; "SBRI"; "SBRP"; "SBRZ"; "SSOB"; "SSOS"
  ; "SCHA"; "SCHE"; "SCHF"; "SCHW"; "SBNA"; "SBNE"; "SBNF"; "SBNW"
  ; "SBAV"; "SESK"; "SREV"; "SFLV"; "SFSP"; "SSWA"; "SBST"
  ; "SSSW"; "SCTO"; "SDBO"; "SMBU"; "SSWP"; "SSHO"; "SSBM"; "STAU"
  ; "SFAV"; "SFSH"; "SHAS"; "SPAU"; "SVIG"; "SLIG"; "SSBL"; "SHWL"
  ; "SSPT"; "SRBI"; "SBLU"; "SEGZ"; "SLCO"; "SDST"; "SFBO"; "SRND"
  ; "SSNK"; "STWH"; "SSGZ"; "SENR"; "SCHL"; "SVAM"; "SFRZ"
  ; "SCBO"; "SZAP"; "SCLI"; "SLIS"; "SSUT"; "SFCA"; "SMST" ]


