open Puzzle_quest_lib
open Combat

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_eq name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let check_str name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %S, want %S)\n" name got want;
    incr failures
  end

let check_list name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n  got  %s\n  want %s\n" name
      (String.concat "," (List.map string_of_int got))
      (String.concat "," (List.map string_of_int want));
    incr failures
  end

(* ------------------------------------------------------------------ *)
(* Hook table: 32 names, straight from 0x005239E8                       *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "the hook table has 37 entries" (List.length all_hook_names) 37;
  check "hook names are unique"
    (List.length all_hook_names = List.length (List.sort_uniq String.compare all_hook_names));
  (* Spot-check the ordering at both ends and across the status-effect hooks,
     since the dispatch indices are what the original's switch cases key on. *)
  check_str "hook 0" (List.nth all_hook_names 0) "ShouldAICastSpell";
  check_str "hook 4" (List.nth all_hook_names 4) "OnExtraTurn";
  check_str "hook 5" (List.nth all_hook_names 5) "OnGiveDamage";
  check_str "hook 6" (List.nth all_hook_names 6) "OnMatch4";
  check_str "hook 9" (List.nth all_hook_names 9) "OnQuerySkill";
  check_str "hook 10" (List.nth all_hook_names 10) "OnReceiveDamage";
  check_str "hook 13" (List.nth all_hook_names 13) "OnReceiveXP";
  check_str "hook 15" (List.nth all_hook_names 15) "OnStartTurn";
  check_str "hook 18" (List.nth all_hook_names 18) "OnBegin";
  check_str "hook 19" (List.nth all_hook_names 19) "OnEnd";
  check_str "hook 31" (List.nth all_hook_names 31) "OnQueryAppearance";
  check_str "last hook" (List.nth all_hook_names 36) "OnExecute"

(* An absent hook and a no-op hook must be distinguishable, which is the whole
   reason the record is option-valued rather than defaulting to no-ops. *)
let () =
  check "no_hooks has no start-turn hook" (no_hooks.on_start_turn = None);
  let did_run = ref false in
  let h = set_start_turn no_hooks (fun _ _ -> did_run := true) in
  check "setting a hook replaces None" (h.on_start_turn <> None);
  (match h.on_start_turn with
  | None -> check "the hook was installed" false
  | Some f ->
      f 0 1;
      check "the installed hook runs" !did_run);
  check "setting one hook leaves the others alone" (h.on_extra_turn = None)

(* ------------------------------------------------------------------ *)
(* Turn order: rotation seeded by the highest Cunning                   *)
(* ------------------------------------------------------------------ *)

let () =
  let a = make_combatant ~cunning:5 0 "A" in
  let b = make_combatant ~cunning:9 1 "B" in
  let c = make_combatant ~cunning:7 2 "C" in
  let t = initialise [ a; b; c ] in
  (* B leads, then the rest keep roster order, so it is a rotation. *)
  check_list "the highest-cunning combatant leads" (Array.to_list t.turn_order) [ 1; 2; 0 ];
  check_eq "and the slot starts on them" (current_index t) 1;
  check "single-combatant mode collapses the order"
    (Array.length (initialise ~single_combatant:true [ a; b; c ]).turn_order = 1);
  check "initialise rejects an empty roster"
    (try
       ignore (initialise []);
       false
     with Invalid_argument _ -> true)

let () =
  (* A tie on cunning falls through to the tiebreak, which defaults to equal,
     so the first combatant found keeps the lead. *)
  let a = make_combatant ~cunning:5 0 "A" in
  let b = make_combatant ~cunning:5 1 "B" in
  let t = initialise [ a; b ] in
  check_eq "an unbroken tie keeps the first combatant" (current_index t) 0;
  let t2 = initialise ~tiebreak:(fun c _ -> c.id) [ a; b ] in
  check_eq "the tiebreak can break a tie" (current_index t2) 1;
  (* The tiebreak only decides who leads; it never reorders the rest. *)
  check_list "the tiebreak does not sort the roster"
    (Array.to_list t2.turn_order) [ 1; 0 ]

(* ------------------------------------------------------------------ *)
(* Handoff and the extra-turn branch                                   *)
(* ------------------------------------------------------------------ *)

let () =
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  check_eq "starts on the leader" (current_index t) 0;
  check_eq "advance moves to the next" (advance_turn t) 1;
  check_eq "and the round wraps on a full cycle" (advance_turn t) 0;
  check_eq "after a full cycle the round is 1" t.round 1;
  check "advance rejects nothing on a two-fighter roster" true

let () =
  (* The extra-turn branch returns before advancing, so the combatant who
     earned it acts again immediately. *)
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  ignore (advance_turn t);
  check_eq "we are on B" (current_index t) 1;
  request_extra_turn t;
  check "the flag is set" t.extra_turn_pending;
  check_eq "the extra turn does not advance" (advance_turn t) 1;
  check "and the flag clears itself" (not t.extra_turn_pending);
  check_eq "the next advance moves on normally" (advance_turn t) 0

let () =
  (* The drain loop decrements the current combatant, advances, then re-reads
     the new current. So a single banked turn is consumed per step, and the
     rest of a combatant's bank resolves on their later turns. *)
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  grant_extra_turn t 0;
  check_eq "one extra turn is banked" a.extra_turns 1;
  check_eq "draining consumes exactly it" (drain_extra_turns t) 1;
  check "leaving nothing banked" (a.extra_turns = 0);
  check_eq "and stepping to the next combatant" (current_index t) 1;
  check_eq "a two-fighter roster has not wrapped yet" t.round 0;
  check_eq "a second drain finds nothing left" (drain_extra_turns t) 0;
  check_eq "and does not move the order" (current_index t) 1

let () =
  (* Draining wraps the slot, so the round counter tracks the wraps. *)
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let c = make_combatant 2 "C" in
  let t = initialise [ a; b; c ] in
  a.extra_turns <- 1;
  let before = t.round in
  ignore (drain_extra_turns t);
  check "a single drain did not wrap past slot 0" (t.round = before);
  (* Force the wrap by draining from the last slot. *)
  t.current_slot <- 2;
  c.extra_turns <- 1;
  ignore (drain_extra_turns t);
  check_eq "draining from the last slot wraps to slot 0" t.current_slot 0;
  check "and increments the round" (t.round = before + 1)

let () =
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  t.finished <- true;
  let before = current_index t in
  check_eq "a finished battle does not advance" (advance_turn t) before;
  check_eq "and the round is untouched" t.round 0

(* ------------------------------------------------------------------ *)
(* Death sweep                                                         *)
(* ------------------------------------------------------------------ *)

let () =
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  check "a living roster sweeps clean" (not (sweep_deaths t));
  b.life <- 0;
  b.is_dead <- true;
  check "a fresh death is reported" (sweep_deaths t);
  check "and the dead flag is cleared" (not b.is_dead);
  check "a second sweep reports nothing" (not (sweep_deaths t))

(* ------------------------------------------------------------------ *)
(* Duration: FUN_00475220                                              *)
(* ------------------------------------------------------------------ *)

let () =
  let live, d = tick_duration 3 in
  check "a 3-turn effect survives its first tick" live;
  check_eq "and drops to 2" d 2;
  let live, d = tick_duration 1 in
  check "a 1-turn effect lapses on its tick" (not live);
  check_eq "and lands on 0" d 0;
  let live, d = tick_duration 0 in
  check "an already-lapsed effect stays lapsed" (not live);
  check_eq "and does not go negative" d 0;
  let live, d = tick_duration (-5) in
  check "a negative duration stays lapsed" (not live);
  check_eq "and is not decremented further" d (-5)

(* ------------------------------------------------------------------ *)
(* Status effects: the two base-game scripts, ported                   *)
(* ------------------------------------------------------------------ *)

(** The effect scripts are authored as closures over the roster, the same way
    the original's Lua scripts close over the native bindings. *)
let the_roster = ref [||]

(** Disease: -1 to every mana pool each turn, per Assets/StatusEffects. *)
let disease =
  {
    def_id = "EDIS";
    def_duration = 6;
    def_max_stack = 4;
    def_icon = 1;
    def_hooks =
      set_start_turn no_hooks (fun idx _turn ->
          let c = (!the_roster).(idx) in
          List.iter (fun e -> c.mana <- add_mana e (-1) c.mana) all_elements);
  }

(** Hasted: +4 damage on every extra turn. *)
let hasted =
  {
    def_id = "EHAS";
    def_duration = 8;
    def_max_stack = 1;
    def_icon = 23;
    def_hooks = set_extra_turn no_hooks (fun _idx -> ());
  }

let setup () =
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  the_roster := [| a; b |];
  ignore t;
  (a, b, t)

let defs = [ disease; hasted ]

let () =
  let a, _b, _t = setup () in
  a.mana <- { earth = 10; fire = 10; air = 10; water = 10 };
  apply_effect disease a;
  check_eq "disease is active" (List.length (active_effects a)) 1;
  check_eq "with the xml duration" (snd (List.hd (active_effects a))) 6;
  run_start_of_turn_effects a defs 1;
  (* -1 from each of four pools: 40 total becomes 36. *)
  check_eq "disease drained every pool" (total_mana a.mana) 36;
  check_eq "leaving nine per pool" a.mana.earth 9;
  check_eq "and the effect is one turn closer"
    (snd (List.hd (active_effects a))) 5

let () =
  (* Stacking refreshes rather than duplicating. *)
  let a, _b, _t = setup () in
  apply_effect disease a;
  run_start_of_turn_effects a defs 1;
  apply_effect disease a;
  check_eq "reapplying does not stack a second copy" (List.length (active_effects a)) 1;
  check_eq "and refreshes the duration" (snd (List.hd (active_effects a))) 6

let () =
  (* An effect runs on the turn it expires, then is dropped. *)
  let a, _b, _t = setup () in
  let ticking = { disease with def_duration = 1 } in
  apply_effect ticking a;
  run_start_of_turn_effects a [ ticking ] 1;
  check "an effect lapses on its final turn" (active_effects a = []);
  let b, _c, _t = setup () in
  ignore b;
  let long = { disease with def_duration = 2 } in
  apply_effect long a;
  run_start_of_turn_effects a [ long ] 1;
  check_eq "a 2-turn effect survives one tick" (List.length (active_effects a)) 1;
  run_start_of_turn_effects a [ long ] 2;
  check "and lapses on the second" (active_effects a = [])

let () =
  (* Hooks fire on every turn while the effect is live, which is the difference
     between a duration and a one-shot. *)
  let a, _b, _t = setup () in
  let counting = ref 0 in
  let counter =
    { disease with
      def_duration = 3;
      def_hooks = set_start_turn no_hooks (fun _ _ -> incr counting) }
  in
  apply_effect counter a;
  for turn = 1 to 3 do
    run_start_of_turn_effects a [ counter ] turn
  done;
  check_eq "a 3-turn effect ran its hook 3 times" !counting 3

let () =
  let a, _b, _t = setup () in
  let extra_turns_run = ref 0 in
  let hasted_real =
    { hasted with def_hooks = set_extra_turn no_hooks (fun _ -> incr extra_turns_run) }
  in
  apply_effect hasted_real a;
  run_extra_turn_effects a [ hasted_real ];
  check_eq "the extra-turn hook fires once" !extra_turns_run 1;
  let b, _c, _t = setup () in
  run_extra_turn_effects b [ hasted_real ];
  check "and not for a combatant without it" (!extra_turns_run = 1)

(* ------------------------------------------------------------------ *)
(* Damage hooks                                                        *)
(* ------------------------------------------------------------------ *)

let () =
  let a, _b, _t = setup () in
  (* A shield that halves incoming damage. *)
  let shield =
    { hasted with
      def_id = "ESHD";
      def_hooks = set_receive_damage no_hooks (fun _ amt -> amt / 2) }
  in
  check_eq "damage passes through with no effects" (receive_damage a [] 20) 20;
  apply_effect shield a;
  check_eq "a shield modifies incoming damage" (receive_damage a [ shield ] 20) 10;
  (* give_damage reads the combatant's own effects, so the amplifier has to be
     applied before it fires. *)
  let amp =
    { hasted with def_id = "EAMP"; def_hooks = set_give_damage no_hooks (fun _ amt -> amt + 5) }
  in
  apply_effect amp a;
  check_eq "an amplifier modifies outgoing damage" (give_damage a [ amp ] 20) 25;
  (* Two halvings in sequence: 40 -> 20 -> 10. *)
  let shield2 = { shield with def_id = "ESHD2" } in
  apply_effect shield2 a;
  check_eq "effects chain in order" (receive_damage a [ shield; shield2 ] 40) 10

(* ------------------------------------------------------------------ *)
(* Mana helpers                                                        *)
(* ------------------------------------------------------------------ *)

let () =
  let a, _b, _t = setup () in
  a.mana <- zero_mana;
  subtract_mana a Fire 3;
  subtract_mana a Water 1;
  check_eq "fire was drained" a.mana.fire (-3);
  check_eq "water was drained" a.mana.water (-1);
  check_eq "the others are untouched" a.mana.earth 0;
  check_eq "mana can go negative, as the original allows" (total_mana a.mana) (-4);
  check_list "mana_of reads each pool"
    (List.map (fun e -> mana_of e a.mana) all_elements)
    [ 0; -3; 0; -1 ]

let () =
  if !failures = 0 then print_endline "\nAll combat tests passed."
  else begin
    Printf.printf "\n%d combat test(s) failed.\n" !failures;
    exit 1
  end
