(** Combat flow: turn order, extra turns, status effect lifetimes, and the
    hook table.

    Recovered from the turn manager singleton at 0x005829B8 and the status
    effect descriptors loaded from Assets/StatusEffects. See
    docs/COMBAT_FLOW.md for the annotated disassembly and a confidence table.

    The hook set is the reason this engine has no Lua layer. The original
    dispatches 32 named callbacks out of a Lua table; here they are optional
    function values in a record. An absent hook and a no-op hook stay
    distinguishable, matching Lua's [nil] versus a function that returns
    without doing anything. *)

(** The four mana elements, in the engine's internal order. 0x474D20 parses
    spell costs as earth/fire/air/water into consecutive shorts. *)
type element = Earth | Fire | Air | Water

let all_elements = [ Earth; Fire; Air; Water ]

type mana = { earth : int; fire : int; air : int; water : int }

let zero_mana = { earth = 0; fire = 0; air = 0; water = 0 }

(** The per-element mana ceiling, one int per element, same order as [mana].

    **Recovered**: the storage and the setter semantics. `GET_MAX_MANA_*`
    (0x48dce0 and siblings) reads `character + 0x84 + element * 4`, and the
    setter at 0x4839f0 stores the new ceiling then clamps the {e current} pool
    down to it. So lowering a ceiling can reduce mana you already hold, and the
    four ceilings are contiguous ints at +0x84.

    **Not recovered**: the starting value. Nothing in the save file stores it -
    [SAVE_FILE_FORMAT.md] has the masteries and the current reserves but no cap
    field - so the ceiling is a derived runtime quantity and its base value has
    not been located in the binary. Treat the constant below as a chosen
    parameter rather than a recovered fact; it is a field on the combatant so a
    fight can set its own.

    **Why the default is 20 and not 10.** The ceiling has to clear the largest
    number any script compares a pool against, or the comparison is dead code
    rather than a conditional. The spell scripts test `GET_MANA_*` against 8, 10,
    12, 14, 15 and 20, and all nine spells whose turn rule is `KeepsTurnIfMana`
    need 8 or more. Twenty is therefore the smallest default under which every
    threshold the game actually uses is reachable, which makes it the right
    ceiling to ship: too low and mechanics silently switch off, too high and the
    hooks that gate on "a lot of mana" stop meaning anything.

    It is a floor, not a model of a real character. Characters raise their
    ceilings with skills and with the "+N to max Fire Mana" item bonuses, and the
    ceiling in a real late fight is comfortably above 20 - the AI hooks that scale
    a modifier by two or three times a pool ([SFBO], [SSOB], [SFSP]) assume pools
    in the twenties and thirties. Anything testing those should set an explicit
    ceiling on the combatant rather than inherit this. *)
let default_mana_limit = 20

let zero_caps =
  { earth = default_mana_limit
  ; fire = default_mana_limit
  ; air = default_mana_limit
  ; water = default_mana_limit
  }


let mana_of e m =
  match e with
  | Earth -> m.earth
  | Fire -> m.fire
  | Air -> m.air
  | Water -> m.water

let add_mana e amount m =
  match e with
  | Earth -> { m with earth = m.earth + amount }
  | Fire -> { m with fire = m.fire + amount }
  | Air -> { m with air = m.air + amount }
  | Water -> { m with water = m.water + amount }

let total_mana m = m.earth + m.fire + m.air + m.water

(** The seven character skills, not just the four elemental ones.

    The mana economy only cares about the first four, but the save file stores all
    seven and so do item restrictions: 28 of the 160 items require a Battle,
    Morale, or Cunning level rather than an elemental one. Modelling only the
    elements would have silently made those 28 items unrestrictable. *)
type skill =
  | SEarth
  | SFire
  | SAir
  | SWater
  | SBattle
  | SMorale
  | SCunning

type skills = {
  earth : int;
  fire : int;
  air : int;
  water : int;
  battle : int;
  morale : int;
  cunning : int;
}

let zero_skills =
  { earth = 0; fire = 0; air = 0; water = 0; battle = 0; morale = 0; cunning = 0 }

let skill_in (s : skill) (k : skills) : int =
  match s with
  | SEarth -> k.earth
  | SFire -> k.fire
  | SAir -> k.air
  | SWater -> k.water
  | SBattle -> k.battle
  | SMorale -> k.morale
  | SCunning -> k.cunning

let add_skill (s : skill) (amount : int) (k : skills) : skills =
  match s with
  | SEarth -> { k with earth = k.earth + amount }
  | SFire -> { k with fire = k.fire + amount }
  | SAir -> { k with air = k.air + amount }
  | SWater -> { k with water = k.water + amount }
  | SBattle -> { k with battle = k.battle + amount }
  | SMorale -> { k with morale = k.morale + amount }
  | SCunning -> { k with cunning = k.cunning + amount }

let total_skills k =
  k.earth + k.fire + k.air + k.water + k.battle + k.morale + k.cunning

(** The element a skill name refers to, for the paths that only ever deal in the
    four elemental ones: mana yield, and the spell AI's affinity term. *)
let element_of_skill = function
  | SEarth -> Some Earth
  | SFire -> Some Fire
  | SAir -> Some Air
  | SWater -> Some Water
  | _ -> None

(** The skill name an element maps to, which is the direction the mana yield and
    the spell AI's affinity term need: they have an [element] in hand and want
    its skill value. *)
let skill_of_element = function
  | Earth -> SEarth
  | Fire -> SFire
  | Air -> SAir
  | Water -> SWater

let skill_name = function
  | SEarth -> "earth"
  | SFire -> "fire"
  | SAir -> "air"
  | SWater -> "water"
  | SBattle -> "battle"
  | SMorale -> "morale"
  | SCunning -> "cunning"

(** A combatant. Only the fields the turn manager and status effects read are
    modelled. [cunning] is the initiative stat at skill slot 5; [is_dead] is
    the flag the defeat sweep at [FUN_00464870] clears. *)
type combatant = {
  id : int;
  name : string;
  cunning : int;
  max_life : int;
  mutable life : int;
  mutable mana : mana;
  (* The per-element ceiling. See [default_mana_limit] for what is and is not
     recovered about the base value. *)
  mutable max_mana : mana;
  (* Trained skill per element. Drives mana yield and the extra turn roll, and
     is independent of the balance above: spending mana never lowers it. *)
  mutable skills : skills;
  mutable is_dead : bool;
  (* Per-character extra turns banked. This is the original's m_turnsLeft,
     which is only ever incremented by EXTRA_TURN. *)
  mutable extra_turns : int;
  (* Active status effects, as (effect id, remaining duration). *)
  mutable effects : (string * int) list;
  (* Spell cooldowns in turns left, keyed by spell id. Per combatant rather
     than on the [Spell.spell] record because a spell object is shared between
     the two sides in our model, and one side's cast must not gate the other's. *)
  mutable cooldowns : (string * int) list;
}

let make_combatant ?(cunning = 0) ?(max_life = 100) ?(life = 100) ?(mana = zero_mana)
    ?(max_mana = zero_caps) ?(skills = zero_skills) ?(extra_turns = 0) ?(effects = [])
    ?(cooldowns = []) id name =
  {
    id;
    name;
    cunning;
    max_life;
    life;
    mana;
    max_mana;
    skills;
    is_dead = false;
    extra_turns;
    effects;
    cooldowns;
  }


(** Status effect definitions, parsed from the [Assets/StatusEffects/*.xml]
    descriptors. [max_stack] is the [stack] attribute: how many copies can sit
    on one character at once. *)
type effect_def = {
  def_id : string;
  def_duration : int;
  def_max_stack : int;
  def_icon : int;
  def_hooks : hooks;
}

(** The 32 script hooks, in the order they appear in the table at
    0x005239E8. [on_receive_damage] and friends return a modified value in
    the original; the rest return unit. *)
and hooks = {
  should_ai_cast_spell : (unit -> bool) option;
  on_cast_spell : (int -> unit) option;
  on_defeat : (int -> unit) option;
  on_enemy_cast_spell : (int -> unit) option;
  on_extra_turn : (int -> unit) option;
  on_give_damage : (int -> int -> int) option;
  on_match4 : (int -> int -> int) option;
  on_match5 : (int -> int -> int) option;
  on_query_resistance : (int -> element -> int) option;
  on_query_skill : (int -> int -> int) option;
  on_receive_damage : (int -> int -> int) option;
  on_receive_gold : (int -> int -> int) option;
  on_receive_mana : (int -> element -> int -> int) option;
  on_receive_xp : (int -> int -> int) option;
  on_start_battle : (int -> unit) option;
  on_start_turn : (int -> int -> unit) option;
  on_enter_location : (int -> unit) option;
  on_victory : (int -> unit) option;
  on_init : (unit -> unit) option;
  on_begin : (unit -> unit) option;
  on_abandon : (unit -> unit) option;
  on_execute_action : (int -> int) option;
  on_complete_action : (int -> int) option;
  on_cancel_action : (int -> int) option;
  on_query_action : (int -> bool) option;
  on_load : (int -> unit) option;
  on_save : (int -> int) option;
  on_query_progress : (int -> int) option;
  on_query_percentage : (int -> int) option;
  on_query_difficulty : (int -> int) option;
    on_query_appearance : (int -> int) option;
    on_end : (unit -> unit) option;
    on_query_disappearance : (int -> int) option;
    on_appear : (int -> unit) option;
    on_disappear : (int -> unit) option;
    on_complete : (int -> unit) option;
    on_execute : (int -> unit) option;
}

let no_hooks =
  {
    should_ai_cast_spell = None;
    on_cast_spell = None;
    on_defeat = None;
    on_enemy_cast_spell = None;
    on_extra_turn = None;
    on_give_damage = None;
    on_match4 = None;
    on_match5 = None;
    on_query_resistance = None;
    on_query_skill = None;
    on_receive_damage = None;
    on_receive_gold = None;
    on_receive_xp = None;
    on_receive_mana = None;
    on_start_battle = None;
    on_start_turn = None;
    on_enter_location = None;
    on_victory = None;
    on_init = None;
    on_begin = None;
    on_abandon = None;
    on_execute_action = None;
    on_complete_action = None;
    on_cancel_action = None;
    on_query_action = None;
    on_load = None;
    on_save = None;
    on_query_progress = None;
    on_query_percentage = None;
    on_query_difficulty = None;
    on_query_appearance = None;
    on_end = None;
    on_query_disappearance = None;
    on_appear = None;
    on_disappear = None;
    on_complete = None;
    on_execute = None;
  }

(** The status effect hooks, extracted from a record of arbitrary shape. The
    type varies per hook, so this is per-hook rather than a fold. *)
let set_start_turn h f = { h with on_start_turn = Some f }
let set_extra_turn h f = { h with on_extra_turn = Some f }
let set_receive_damage h f = { h with on_receive_damage = Some f }
let set_give_damage h f = { h with on_give_damage = Some f }
let set_query_skill h f = { h with on_query_skill = Some f }
let set_receive_xp h f = { h with on_receive_xp = Some f }
let set_match4 h f = { h with on_match4 = Some f }
let set_match5 h f = { h with on_match5 = Some f }

(** The hook names as they appear in the binary's table, for diagnostics and
    for keeping the OCaml record honest against the original. *)
let all_hook_names =
  [
    "ShouldAICastSpell";
    "OnCastSpell";
    "OnDefeat";
    "OnEnemyCastSpell";
    "OnExtraTurn";
    "OnGiveDamage";
    "OnMatch4";
    "OnMatch5";
    "OnQueryResistance";
    "OnQuerySkill";
    "OnReceiveDamage";
    "OnReceiveGold";
    "OnReceiveMana";
    "OnReceiveXP";
    "OnStartBattle";
    "OnStartTurn";
    "OnVictory";
    "OnInit";
    "OnBegin";
    "OnEnd";
    "OnAbandon";
    "OnEnterLocation";
    "OnExecuteAction";
    "OnCompleteAction";
    "OnCancelAction";
    "OnQueryAction";
    "OnLoad";
    "OnSave";
    "OnQueryProgress";
    "OnQueryPercentage";
    "OnQueryDifficulty";
    "OnQueryAppearance";
    "OnQueryDisappearance";
    "OnAppear";
    "OnDisappear";
    "OnComplete";
    "OnExecute";
  ]

(* ------------------------------------------------------------------ *)
(* Turn order                                                          *)
(* ------------------------------------------------------------------ *)

type turn_manager = {
  combatants : combatant array;
  mutable turn_order : int array;  (** slot -> combatant index *)
  mutable current_slot : int;
  mutable round : int;
  mutable extra_turn_pending : bool;
  mutable finished : bool;
}

let current_index (t : turn_manager) = t.turn_order.(t.current_slot)

let current (t : turn_manager) = t.combatants.(current_index t)

(** [FUN_00464730]. Finds the highest-Cunning combatant and rotates the roster
    so they act first. The scan only picks who leads; everyone else keeps
    roster order, because the order is a rotation rather than a sort.

    [tiebreak] supplies the second and third comparison in the original,
    which reads two unidentified fields through the character vtable. The
    default makes them agree, so ties fall to the first combatant found. *)
let initialise ?(tiebreak = fun _ _ -> 0) ?(single_combatant = false)
    (combatants : combatant list) : turn_manager =
  (* Puzzle and spell-research modes (game modes 2, 5, 6) set the roster to a
     single combatant, so the rotation and the drain loop only ever see one. *)
  let all = if single_combatant then [| List.hd combatants |] else Array.of_list combatants in
  let n = Array.length all in
  if n = 0 then invalid_arg "Combat.initialise: no combatants";
  let first =
    if single_combatant then 0
    else begin
      let best = ref (-1) and first = ref 0 and best_tie = ref min_int in
      Array.iteri
        (fun i c ->
          if !best < c.cunning then begin
            best := c.cunning;
            first := i;
            best_tie := tiebreak c i
          end
          else if c.cunning = !best then begin
            let t = tiebreak c i in
            (* The original's second and third comparisons are strict, so an
               equal tiebreak keeps whoever is already in front. *)
            if t > !best_tie then begin
              best_tie := t;
              first := i
            end
          end)
        all;
      !first
    end
  in
  let order = Array.init n (fun slot -> (slot + first) mod n) in
  Array.iter (fun c -> c.extra_turns <- 0) all;
  { combatants = all; turn_order = order; current_slot = 0; round = 0; extra_turn_pending = false; finished = false }

(** [FUN_00464870]. Sweeps for the dead and clears their flag. Returns true if
    anyone died this pass. *)
let sweep_deaths (t : turn_manager) : bool =
  let died = ref false in
  Array.iter
    (fun c ->
      if c.is_dead && c.life < 1 then begin
        c.is_dead <- false;
        died := true
      end)
    t.combatants;
  !died

(** [FUN_00464E30]'s drain loop.

    Faithful to the original, including a subtlety worth stating: the loop
    decrements the current combatant, {e then} advances the slot, and re-reads
    the {e new} current combatant's bank. So it drains one banked turn per
    combatant it steps through, rather than draining a single combatant's whole
    bank at once. A combatant with two banked turns and an empty slot in front
    of them has one consumed here and resolves the other on their next turn. *)
let drain_extra_turns (t : turn_manager) : int =
  let consumed = ref 0 in
  let step () =
    t.current_slot <- (t.current_slot + 1) mod Array.length t.combatants;
    if t.current_slot = 0 then t.round <- t.round + 1
  in
  let current () = t.combatants.(current_index t) in
  let n = Array.length t.combatants in
  (* Bounded by the roster size: each pass steps to a different combatant, so
     it cannot loop forever even if every combatant has turns banked. *)
  let budget = ref n in
  while !budget > 0 && (current ()).extra_turns > 0 do
    decr budget;
    (current ()).extra_turns <- (current ()).extra_turns - 1;
    consumed := !consumed + 1;
    step ()
  done;
  !consumed

(** [FUN_00464E30]. Advances to the next combatant, honouring banked extra
    turns and the pending-extra-turn flag.

    The order of the two early exits is load-bearing and matches the original:
    the extra-turn branch comes {e before} the advance, so a banked extra turn
    is the entire iteration rather than a modifier on the next one. *)
let advance_turn (t : turn_manager) : int =
  if t.finished then current_index t
  else if t.extra_turn_pending then begin
    t.extra_turn_pending <- false;
    current_index t
  end
  else begin
    t.current_slot <- (t.current_slot + 1) mod Array.length t.combatants;
    if t.current_slot = 0 then t.round <- t.round + 1;
    ignore (drain_extra_turns t);
    current_index t
  end

(** Grants an extra turn. This is the only thing that ever increments
    [extra_turns]; a 4-of-a-kind calls it, which is why the matcher replays
    their slot. *)
let grant_extra_turn (t : turn_manager) (i : int) : unit =
  t.combatants.(i).extra_turns <- t.combatants.(i).extra_turns + 1

let request_extra_turn (t : turn_manager) : unit = t.extra_turn_pending <- true

(* ------------------------------------------------------------------ *)
(* Status effects                                                      *)
(* ------------------------------------------------------------------ *)

(** [FUN_00475220]. The whole expiry rule: decrement, and report whether the
    effect is still live. Already-expired effects stay expired. *)
let tick_duration (remaining : int) : bool * int =
  if remaining < 1 then (false, remaining) else (remaining - 1 > 0, remaining - 1)

let active_effects (c : combatant) = c.effects

(** Applies a status effect, respecting its stack limit.

    The [stack] attribute caps how many copies of {e this} effect one
    combatant can carry, not how many effects overall, so the count is taken
    over matching ids only. Reapplying an effect already present refreshes its
    duration rather than adding a second copy. *)
let apply_effect (def : effect_def) (c : combatant) : unit =
  let copies id = List.length (List.filter (fun (eid, _) -> eid = id) c.effects) in
  if copies def.def_id > 0 then
    c.effects <-
      List.map
        (fun (id, d) -> if id = def.def_id then (id, def.def_duration) else (id, d))
        c.effects
  else if copies def.def_id < def.def_max_stack then
    c.effects <- c.effects @ [ (def.def_id, def.def_duration) ]

(** Runs one turn of effects on a combatant: the {e start} hooks fire, then
    every duration ticks down, and lapsed effects are dropped.

    Hooks run before the tick, so an effect that expires this turn still takes
    effect - matching the original, where the countdown is consulted after the
    turn's callbacks have run. *)
let run_start_of_turn_effects (c : combatant) (defs : effect_def list) (turn : int) : unit =
  let def_of_id id = List.find_opt (fun d -> d.def_id = id) defs in
  List.iter
    (fun (id, _) ->
      match def_of_id id with
      | Some d -> (
          match d.def_hooks.on_start_turn with
          | Some f -> f c.id turn
          | None -> ())
      | None -> ())
    c.effects;
  c.effects <-
    List.filter_map
      (fun (id, d) ->
        match def_of_id id with
        | None -> None
        | Some _ ->
            let live, d' = tick_duration d in
            if live then Some (id, d') else None)
      c.effects

(** Runs the extra-turn hooks for every active effect. Hasted uses this to
    deal its damage. *)
let run_extra_turn_effects (c : combatant) (defs : effect_def list) : unit =
  List.iter
    (fun (id, _) ->
      match List.find_opt (fun d -> d.def_id = id) defs with
      | Some d -> (
          match d.def_hooks.on_extra_turn with
          | Some f -> f c.id
          | None -> ())
      | None -> ())
    c.effects

(** Applies damage through the receive-damage hooks, which may reduce or
    amplify it. Returns the amount actually taken. *)
let receive_damage (c : combatant) (defs : effect_def list) (amount : int) : int =
  List.fold_left
    (fun acc (id, _) ->
      match List.find_opt (fun d -> d.def_id = id) defs with
      | Some d -> (
          match d.def_hooks.on_receive_damage with Some f -> f c.id acc | None -> acc)
      | None -> acc)
    amount c.effects

(** Applies outgoing damage through the give-damage hooks. *)
let give_damage (c : combatant) (defs : effect_def list) (amount : int) : int =
  List.fold_left
    (fun acc (id, _) ->
      match List.find_opt (fun d -> d.def_id = id) defs with
      | Some d -> (
          match d.def_hooks.on_give_damage with Some f -> f c.id acc | None -> acc)
      | None -> acc)
    amount c.effects

(* ------------------------------------------------------------------ *)
(* Helpers                                                             *)
(* ------------------------------------------------------------------ *)

let subtract_mana (c : combatant) (e : element) (amount : int) : unit =
  c.mana <- add_mana e (-amount) c.mana

let status_names (c : combatant) = List.map fst c.effects

let describe (t : turn_manager) : string =
  let names = Array.map (fun c -> c.name) t.combatants in
  let order = String.concat " -> " (Array.to_list (Array.map (fun i -> names.(i)) t.turn_order)) in
  Printf.sprintf "round %d, slot %d (%s); order: %s" t.round t.current_slot
    names.(current_index t) order


(** Credits mana, stopping at the element's ceiling.

    This is where the cap is enforced going {e up}; [set_mana_limit] enforces it
    going down. Both halves matter: the AI hooks test
    `GET_MANA_X >= GET_MAX_MANA_X` to mean "the pool is full", which only means
    something if the pool can reach the cap and can never pass it. *)
let credit_mana (c : combatant) (e : element) (amount : int) : int =
  if amount <= 0 then 0
  else begin
    let granted = min amount (max 0 (mana_of e c.max_mana - mana_of e c.mana)) in
    if granted > 0 then c.mana <- add_mana e granted c.mana;
    granted
  end

(** Sets an element's ceiling and clamps the pool to it, matching the setter at
    0x4839f0: the pool is reduced if it sat above the new ceiling and left alone
    if it sat below. So lowering a ceiling can take mana away. *)
let set_mana_limit (c : combatant) (e : element) (limit : int) : unit =
  c.max_mana <-
    (match e with
    | Earth -> { c.max_mana with earth = limit }
    | Fire -> { c.max_mana with fire = limit }
    | Air -> { c.max_mana with air = limit }
    | Water -> { c.max_mana with water = limit });
  let have = mana_of e c.mana in
  if have > limit then c.mana <- add_mana e (limit - have) c.mana

(** Whether a pool is at its ceiling, which is the test the item and spell AI
    hooks make with `GET_MANA_X >= GET_MAX_MANA_X`. *)
let mana_at_limit (c : combatant) (e : element) : bool =
  mana_of e c.mana >= mana_of e c.max_mana

(** Combatant accessors, shared by the spell layer.

    These live here rather than in [Spell] because they are operations on a
    combatant, and three modules want them: the spell AI hooks, the spell effect
    bodies, and the battle loop. They used to sit in [Spell], which meant a file
    opening both modules had two different functions called [mana_of] with their
    arguments in opposite orders, and the disambiguation had to be written out at
    every call site. *)

(** [GET_MANA_<E>(idx)]: the pool for one element. *)
let mana (c : combatant) (e : element) : int = mana_of e c.mana

(** [GET_MAX_MANA_<E>(idx)]: the ceiling for one element. *)
let max_mana (c : combatant) (e : element) : int = mana_of e c.max_mana

(** [SET_MANA_<E>(idx, value)]: store the pool, {e clamped to the ceiling}.

    The clamp is recovered, not defensive. [Engine_SET_MANA_AIR_445c00] reads
    [character + 0x84 + element * 4] and compares it against the incoming value,
    writing the smaller of the two to [character + 0x74 + element * 4]. A spell can
    therefore ask for more than the pool holds and get the ceiling instead, which
    several of them do. *)
let set_mana (c : combatant) (e : element) (value : int) : unit =
  let ceiling = mana_of e c.max_mana in
  let v = if value < ceiling then value else ceiling in
  c.mana <- (match e with
    | Earth -> { c.mana with earth = v }
    | Fire -> { c.mana with fire = v }
    | Air -> { c.mana with air = v }
    | Water -> { c.mana with water = v })

(** [ADD_MANA_<E>(idx, n)] in its saturating form: the pool never goes below zero. *)
let spend_mana (c : combatant) (e : element) (amount : int) : unit =
  let current = mana_of e c.mana in
  let v = if amount >= current then 0 else current - amount in
  set_mana c e v

(** [GET_LIFE(idx)] and [GET_MAX_LIFE(idx)]. Lua divides these with [/] on
    integers and truncates, which the damage-gated hooks rely on. *)
let life (c : combatant) : int = c.life

let max_life (c : combatant) : int = c.max_life

(** [HAS_STATUS_EFFECT(idx, STATUS_EFFECT_X)].

    The 17 effects in [Assets/StatusEffects] are the only ones a hook can test, so
    the constants reduce to their file names. The [STATUS_EFFECT_] prefix does not
    map onto them by stripping the prefix: the game appends a participle to most,
    so [HASTE] is the file [Hasted] and [WALLOFFIRE] is [WallOfFired]. Those are
    spelled out by the callers rather than derived, because deriving them is
    silently wrong for exactly the cases that matter. *)
let has_status (c : combatant) (name : string) : bool =
  List.exists (fun (id, _) -> id = name) c.effects

(** [GET_NUM_STATUS_EFFECTS(idx)]: counts stacks of all kinds, which is what SCOU
    reads rather than testing a named effect. *)
let num_status_effects (c : combatant) : int = List.length c.effects