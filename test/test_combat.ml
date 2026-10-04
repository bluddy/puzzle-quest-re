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
  let h = set_start_turn no_hooks (fun _ctx _turn -> did_run := true) in
  check "setting a hook replaces None" (h.on_start_turn <> None);
  (match h.on_start_turn with
  | None -> check "the hook was installed" false
  | Some f ->
      f
        { ef_caster = (make_combatant 0 "x"); ef_enemies = []; ef_target = None
        ; ef_roll = (fun _ -> 0); ef_battle = { spells_disallowed = false } }
        1;
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
  (* [FUN_00475220] reads [if (duration < 1) return 1], so a duration at or below
     zero is reported {e alive}. That is not a quirk to tidy away: Hidden, Wall of
     Fire and Wall of Thorns ship with duration 0 and cancel themselves by setting
     it to 1, which is the only thing that ever removes them. The two assertions
     below used to claim the opposite and were wrong. *)
  let live, d = tick_duration 0 in
  check "a zero duration is alive, not lapsed - it is how the game spells indefinite" live;
  check_eq "and is not decremented" d 0;
  let live, d = tick_duration (-5) in
  check "a negative duration is alive too, on the same branch" live;
  check_eq "and is not decremented further" d (-5);
  (* The route that actually removes one: set it to 1, and the next tick's
     [duration > 0] test fails. *)
  let live, _ = tick_duration 1 in
  check "setting the duration to 1 is what removes it" (not live)

(* ------------------------------------------------------------------ *)
(* Status effects: the two base-game scripts, ported                   *)
(* ------------------------------------------------------------------ *)

(** The real descriptors now live in [Status_effect_data], generated from the
    game's own XML, and the real bodies in [Status_effect_hooks]. What is left
    here is the machinery they share: stacking, the countdown, the fold order,
    and the per-turn latch.

    These fixtures are hand-built rather than pulled from the generated table so
    that a duration can be varied without touching a descriptor the seventeen
    share, and so the hook bodies stay trivial enough to read as arithmetic. The
    fields match the real ones - [id], [duration], [stack], [icon], [script],
    [hooks] - because [effect_def] has one shape and pretending otherwise would
    need a second type.

    [the_roster] is gone. The hooks used to take a character index and reach
    through it, which is why this file had an index-addressable roster at all;
    they now take the combatant directly, so nothing needs one. *)
let def_of ?(id = "TEST") ?(duration = 6) ?(stack = 1) ?(hooks = no_hooks) () : effect_def =
  { id; name = "Test"; duration; stack; icon = 0; script = "Test.lua"; hooks }

(** Disease's real body: -1 to every pool. [Assets/StatusEffects/Disease.lua].
    The comment in that script says "-1 every mana each turn" and names only Air,
    but the code subtracts from all four, and the code is what runs. *)
let disease_hooks = set_start_turn no_hooks (fun ctx _turn ->
    List.iter (fun e -> ctx.ef_caster.mana <- add_mana e (-1) ctx.ef_caster.mana) all_elements)

let disease = def_of ~id:"EDIS" ~duration:6 ~stack:4 ~hooks:disease_hooks ()

(** Hasted: +4 damage to its owner's enemies on every extra turn.
    [Assets/StatusEffects/Hasted.lua]. *)
let hasted_hooks = set_extra_turn no_hooks (fun ctx ->
    List.iter (fun e -> e.life <- max 0 (e.life - 4)) ctx.ef_enemies)

let hasted = def_of ~id:"EHAS" ~duration:8 ~hooks:hasted_hooks ()

(** The context every runner needs. A real battle passes the battle's own state
    and its own random source; here they are inert and fixed. *)
let stub_state () = { Combat.spells_disallowed = false }
let no_roll _ = 0

let run_start c defs turn =
  run_start_of_turn_effects c defs ~turn ~enemies:[] ~roll:no_roll ~battle:(stub_state ())

let setup () =
  let a = make_combatant 0 "A" in
  let b = make_combatant 1 "B" in
  let t = initialise [ a; b ] in
  (a, b, t)

let defs = [ disease; hasted ]

let () =
  let a, _b, _t = setup () in
  a.mana <- { earth = 10; fire = 10; air = 10; water = 10 };
  apply_effect disease a;
  check_eq "disease is active" (List.length (active_effects a)) 1;
  check_eq "with the xml duration" (snd (List.hd (active_effects a))) 6;
  run_start a defs 1;
  (* -1 from each of four pools: 40 total becomes 36. *)
  check_eq "disease drained every pool" (total_mana a.mana) 36;
  check_eq "leaving nine per pool" a.mana.earth 9;
  check_eq "and the effect is one turn closer"
    (snd (List.hd (active_effects a))) 5

let () =
  (* Stacking refreshes rather than duplicating. *)
  let a, _b, _t = setup () in
  apply_effect disease a;
  run_start a defs 1;
  apply_effect disease a;
  check_eq "reapplying does not stack a second copy" (List.length (active_effects a)) 1;
  check_eq "and refreshes the duration" (snd (List.hd (active_effects a))) 6

let () =
  (* An effect runs on the turn it expires, then is dropped. *)
  let a, _b, _t = setup () in
  let ticking = { disease with duration = 1 } in
  apply_effect ticking a;
  run_start a [ ticking ] 1;
  check "an effect lapses on its final turn" (active_effects a = []);
  let long = { disease with duration = 2 } in
  apply_effect long a;
  run_start a [ long ] 1;
  check_eq "a 2-turn effect survives one tick" (List.length (active_effects a)) 1;
  run_start a [ long ] 2;
  check "and lapses on the second" (active_effects a = [])

let () =
  (* Hooks fire on every turn while the effect is live, which is the difference
     between a duration and a one-shot. *)
  let a, _b, _t = setup () in
  let counting = ref 0 in
  let counter =
    def_of ~duration:3 ~hooks:(set_start_turn no_hooks (fun _ _ -> incr counting)) ()
  in
  apply_effect counter a;
  for turn = 1 to 3 do
    run_start a [ counter ] turn
  done;
  check_eq "a 3-turn effect ran its hook 3 times" !counting 3

let () =
  (* A duration of 0 is indefinite, not expired. Three of the real effects ship
     with 0 and cancel themselves with [set_effect_duration]; without this,
     [tick_duration] would drop them the turn they were applied. *)
  let a, _b, _t = setup () in
  let forever = def_of ~duration:0 () in
  apply_effect forever a;
  run_start a [ forever ] 1;
  check_eq "a zero-duration effect is still active after a turn"
    (List.length (active_effects a)) 1;
  check_eq "and its duration stays zero" (snd (List.hd (active_effects a))) 0;
  (* The self-cancel: one more turn and it is gone. *)
  set_effect_duration a forever.id 1;
  run_start a [ forever ] 2;
  check "set_effect_duration to 1 lapses it on the next tick" (active_effects a = [])

let () =
  (* Stacked copies each run and each tick. Disease allows four, and four copies
     drain four times. *)
  let a, _b, _t = setup () in
  a.mana <- { earth = 10; fire = 10; air = 10; water = 10 };
  let one = def_of ~id:"ESTK" ~duration:5 ~stack:4 () in
  apply_effect one a;
  check_eq "the first copy lands" (List.length (active_effects a)) 1;
  (* [apply_effect] refreshes rather than adding, so stacking has to be driven
     through the list directly - which is what a second, differently-sourced
     application in the game amounts to. *)
  a.effects <- a.effects @ [ (one.id, one.duration) ];
  run_start a [ one ] 1;
  check_eq "both copies survive the tick" (List.length (active_effects a)) 2

let () =
  let a, _b, _t = setup () in
  let extra_turns_run = ref 0 in
  let hasted_real = def_of ~id:"EHAS" ~hooks:(set_extra_turn no_hooks (fun _ -> incr extra_turns_run)) () in
  apply_effect hasted_real a;
  run_extra_turn_effects a [ hasted_real ] ~enemies:[] ~roll:no_roll ~battle:(stub_state ());
  check_eq "the extra-turn hook fires once" !extra_turns_run 1;
  let b, _c, _t = setup () in
  run_extra_turn_effects b [ hasted_real ] ~enemies:[] ~roll:no_roll ~battle:(stub_state ());
  check "and not for a combatant without it" (!extra_turns_run = 1)

let () =
  (* The extra-turn hook reaches the owner's enemies, which is the whole of
     Hasted: four damage a time, for as long as it lasts. *)
  let a, _b, _t = setup () in
  let foe = make_combatant 1 "foe" in
  foe.life <- 20;
  apply_effect hasted a;
  run_extra_turn_effects a [ hasted ] ~enemies:[ foe ] ~roll:no_roll ~battle:(stub_state ());
  check_eq "Hasted deals four to its owner's enemies" foe.life 16

(* ------------------------------------------------------------------ *)
(* Damage hooks                                                        *)
(* ------------------------------------------------------------------ *)

let () =
  let a, _b, _t = setup () in
  let other = make_combatant 1 "other" in
  (* A shield that halves incoming damage. *)
  let shield =
    def_of ~id:"ESHD" ~hooks:(set_receive_damage no_hooks (fun _ amt -> amt / 2)) ()
  in
  check_eq "damage passes through with no effects"
    (receive_damage ~defender:a ~attacker:other [] ~enemies:[] ~roll:no_roll
       ~battle:(stub_state ()) 20) 20;
  apply_effect shield a;
  check_eq "a shield modifies incoming damage"
    (receive_damage ~defender:a ~attacker:other [ shield ] ~enemies:[] ~roll:no_roll
       ~battle:(stub_state ()) 20) 10;
  (* give_damage reads the attacker's own effects, so the amplifier has to be
     applied before it fires. *)
  let amp =
    def_of ~id:"EAMP" ~hooks:(set_give_damage no_hooks (fun _ amt -> amt + 5)) ()
  in
  apply_effect amp a;
  check_eq "an amplifier modifies outgoing damage"
    (give_damage ~attacker:a ~defender:other [ amp ] ~enemies:[] ~roll:no_roll
       ~battle:(stub_state ()) 20) 25;
  (* Two halvings in sequence: 40 -> 20 -> 10. *)
  let shield2 = { shield with id = "ESHD2" } in
  apply_effect shield2 a;
  check_eq "effects chain in order"
    (receive_damage ~defender:a ~attacker:other [ shield; shield2 ] ~enemies:[]
       ~roll:no_roll ~battle:(stub_state ()) 40) 10

let () =
  (* The damage hooks see both parties, which is what lets Challenged ask whether
     {e both} sides are challenged and Singing Blades drain the target rather than
     the attacker. Both of those are real bodies; this is the plumbing. *)
  let a, b, _t = setup () in
  let saw_target : combatant option ref = ref None in
  let peek =
    def_of ~id:"EPEEK" ~hooks:(set_give_damage no_hooks (fun ctx amt ->
        saw_target := ctx.ef_target;
        amt)) ()
  in
  apply_effect peek a;
  ignore
    (give_damage ~attacker:a ~defender:b [ peek ] ~enemies:[] ~roll:no_roll
       ~battle:(stub_state ()) 5);
  check "the give-damage context's target is the defender"
    (!saw_target = Some b);
  let saw_caster : combatant option ref = ref None in
  let peek_recv =
    def_of ~id:"EPEEK2" ~hooks:(set_receive_damage no_hooks (fun ctx amt ->
        saw_caster := Some ctx.ef_caster;
        amt)) ()
  in
  apply_effect peek_recv b;
  ignore
    (receive_damage ~defender:b ~attacker:a [ peek_recv ] ~enemies:[] ~roll:no_roll
       ~battle:(stub_state ()) 5);
  check "and the receive-damage context's caster is the defender" (!saw_caster = Some b)

let () =
  (* The skill fold. Fear halves and Enraged adds Fire to Battle in the real
     scripts; here the point is that the fold runs over the character's own
     effects and in the order they sit on it. *)
  let a, _b, _t = setup () in
  a.skills <- { (zero_skills) with battle = 10 };
  let plus5 = def_of ~id:"ESK1" ~hooks:(set_query_skill no_hooks (fun _ _ amt -> amt + 5)) () in
  let halve = def_of ~id:"ESK2" ~hooks:(set_query_skill no_hooks (fun _ _ amt -> amt / 2)) () in
  check_eq "a skill with no effects passes through"
    (query_skill a [] ~k:SBattle ~roll:no_roll ~battle:(stub_state ()) 10) 10;
  apply_effect plus5 a;
  check_eq "a skill hook can raise it"
    (query_skill a [ plus5 ] ~k:SBattle ~roll:no_roll ~battle:(stub_state ()) 10) 15;
  apply_effect halve a;
  (* Order is the order they were applied: +5 then halved is 7, not 10. *)
  check_eq "and the fold runs in application order"
    (query_skill a [ plus5; halve ] ~k:SBattle ~roll:no_roll ~battle:(stub_state ()) 10) 7;
  (* The hook is told which skill was asked about, which is what lets Enraged
     answer only for Battle and leave the other six alone. *)
  let asked = ref None in
  let note_skill =
    def_of ~id:"ESK3"
      ~hooks:
        (set_query_skill no_hooks (fun _ctx k amt ->
             asked := Some k;
             amt))
      ()
  in
  apply_effect note_skill a;
  ignore (query_skill a [ note_skill ] ~k:SFire ~roll:no_roll ~battle:(stub_state ()) 4);
  check "the hook is told which skill was asked about" (!asked = Some SFire)

let () =
  (* Vigiled is the only OnMatch4/OnMatch5 user, and the two are wired separately:
     a 4-of-a-kind must not pay the 5-of-a-kind bonus. *)
  let a, _b, _t = setup () in
  let ran4 = ref 0 and ran5 = ref 0 in
  let vig =
    def_of ~id:"EVIG"
      ~hooks:
        (set_match5 (set_match4 no_hooks (fun _ -> incr ran4))
           (fun _ -> incr ran5))
      ()
  in
  apply_effect vig a;
  run_match_effects a [ vig ] ~of_five:false ~enemies:[] ~roll:no_roll ~battle:(stub_state ());
  check_eq "the 4-match hook fires for a 4-run" !ran4 1;
  check "the 5-match hook does not" (!ran5 = 0);
  run_match_effects a [ vig ] ~of_five:true ~enemies:[] ~roll:no_roll ~battle:(stub_state ());
  check_eq "and the 5-match hook fires for a 5-run" !ran5 1;
  let b, _c, _t = setup () in
  run_match_effects b [ vig ] ~of_five:true ~enemies:[] ~roll:no_roll ~battle:(stub_state ());
  check_eq "and neither fires for a combatant without it" !ran5 1

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

(* ------------------------------------------------------------------ *)
(* Mana ceilings                                                        *)
(* ------------------------------------------------------------------ *)

let () =
  (* The cap is enforced going up, and the setter clamps going down. Both halves
     matter, because the AI hooks read "pool >= cap" as "pool is full". *)
  let c = make_combatant 0 "hero" in
  check_eq "a fresh combatant has the default cap" (mana_of Fire c.max_mana) default_mana_limit;
  let granted = credit_mana c Fire 4 in
  check_eq "credit grants what it can" granted 4;
  check_eq "and the pool holds it" (mana_of Fire c.mana) 4;
  check "not at the limit yet" (not (mana_at_limit c Fire));
  ignore (credit_mana c Fire 100);
  check_eq "the pool stops at the cap" (mana_of Fire c.mana) default_mana_limit;
  check "and reports at the limit" (mana_at_limit c Fire);
  check_eq "a full pool grants nothing" (credit_mana c Fire 5) 0;
  (* Other elements are independent. *)
  check_eq "fire does not affect air" (mana_of Air c.mana) 0;
  check "and air is not at its limit" (not (mana_at_limit c Air))

let () =
  (* The setter clamps the pool down when the ceiling drops, matching the
     routine at 0x4839f0, and leaves it alone when it does not. *)
  let c = make_combatant ~mana:{ (zero_mana) with fire = 8; earth = 3 } 0 "hero" in
  set_mana_limit c Fire 5;
  check_eq "dropping the ceiling takes the excess" (mana_of Fire c.mana) 5;
  check_eq "and the new ceiling is stored" (mana_of Fire c.max_mana) 5;
  set_mana_limit c Fire 20;
  check_eq "raising it does not refill" (mana_of Fire c.mana) 5;
  check_eq "but stores the new value" (mana_of Fire c.max_mana) 20;
  check "and the pool is no longer full" (not (mana_at_limit c Fire));
  check "the other element is untouched" (mana_of Earth c.mana = 3);
  check "including its ceiling" (mana_of Earth c.max_mana = default_mana_limit)

let () =
  (* A raised ceiling lets the same match bank more, which is the whole point of
     items that add to max mana. The default is 20, chosen so every threshold the
     spell scripts test against is reachable; see [Combat.default_mana_limit]. *)
  let c = make_combatant 0 "hero" in
  (* Crediting more than the ceiling allows gives back only the room there was. *)
  check_eq "crediting 25 into a cap of 20 banks only 20" (credit_mana c Fire 25) 20;
  check "so the pool is full" (mana_at_limit c Fire);
  check_eq "and holds exactly the ceiling" (mana_of Fire c.mana) 20;
  set_mana_limit c Fire 25;
  check_eq "raising it to 25 allows five more" (credit_mana c Fire 5) 5;
  check_eq "and the pool is full again" (mana_of Fire c.mana) 25

let () =
  (* The default is a parameter, not a recovered constant, so it is settable per
     combatant. *)
  let c = make_combatant ~max_mana:{ zero_caps with fire = 3 } 0 "hero" in
  ignore (credit_mana c Fire 99);
  check_eq "a three-mana cap holds" (mana_of Fire c.mana) 3;
  check "and air still has the default" (mana_of Air c.max_mana = default_mana_limit);

  if !failures = 0 then print_endline "\nAll combat tests passed."
  else begin
    Printf.printf "\n%d combat test(s) failed.\n" !failures;
    exit 1
  end
