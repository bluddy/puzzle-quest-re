(* The seventeen status effect scripts, tested against the descriptors and bodies
   that came out of the game's own assets.

   [tools/extract_status_effects.ps1] generates the descriptors and
   [Status_effect_hooks] carries the behaviour, so what is asserted here is the
   {e pair} working: that an id a spell applies actually resolves to a body, and
   that the body does what its Lua says.

   Two of these have comments in their scripts that disagree with the code, and
   the tests assert the code:

   - Vigiled's header says "gain 5 of each mana"; ManaGain adds 3.
   - Disease's header says "-1 every mana" and the code names only Air, then
     subtracts from all four.

   Three are indefinite (Hidden, Wall of Fire, Wall of Thorns) and cancel
   themselves by setting their duration to 1, so their tests are about the cancel
   and not about a countdown. *)

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
    Printf.printf "FAIL - %s (got %s, want %s)\n" name
      (match got with `Int n -> string_of_int n | `Bool b -> string_of_bool b | _ -> "?")
      (match want with `Int n -> string_of_int n | `Bool b -> string_of_bool b | _ -> "?");
    incr failures
  end

(* ------------------------------------------------------------------ *)
(* Fixtures                                                             *)
(* ------------------------------------------------------------------ *)

let defs = Status_effect_hooks.descriptors

let def_of id =
  match Status_effect_data.descriptor_of id with
  | Some d -> d
  | None -> failwith ("no descriptor for " ^ id)

(* The descriptor with the body attached, which is what a battle actually holds. *)
let live id =
  match List.find_opt (fun (d : effect_def) -> d.id = id) defs with
  | Some d -> d
  | None -> failwith ("no hook for " ^ id)

let hero ?(mana = zero_mana) ?(life = 100) ?(max_life = 100) () =
  make_combatant ~mana ~life ~max_life 0 "hero"

let foe ?(mana = zero_mana) ?(life = 100) ?(max_life = 100) () =
  make_combatant ~mana ~life ~max_life 1 "foe"

(* A roll that hands out the given values in order, then 0 forever. Favored draws
   once per point of experience, so a fixed roll has to be a sequence rather than a
   single number. *)
let seq_roll (values : int list) =
  let rest = ref values in
  fun n -> if n <= 0 then 0
    else match !rest with [] -> 0 | v :: t -> rest := t; v

let state () = { spells_disallowed = false }

(* The three runners, with the plumbing filled in. *)
let start_turn ?(enemies = []) ?(roll = fun _ -> 0) c turn =
  run_start_of_turn_effects c defs ~turn ~enemies ~roll ~battle:(state ())

let extra_turn ?(enemies = []) c =
  run_extra_turn_effects c defs ~enemies ~roll:(fun _ -> 0) ~battle:(state ())

let give ?(enemies = []) attacker defender amount =
  give_damage ~attacker ~defender defs ~enemies ~roll:(fun _ -> 0) ~battle:(state ()) amount

let receive ?(enemies = []) defender attacker amount =
  receive_damage ~defender ~attacker defs ~enemies ~roll:(fun _ -> 0) ~battle:(state ()) amount

let query ?(roll = fun _ -> 0) c k value =
  query_skill c defs ~k ~roll ~battle:(state ()) value

let match_run ?(of_five = false) c =
  run_match_effects c defs ~of_five ~enemies:[] ~roll:(fun _ -> 0) ~battle:(state ())

(* ------------------------------------------------------------------ *)
(* The table itself                                                     *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "all seventeen descriptors are generated"
    (`Int (List.length Status_effect_data.descriptors)) (`Int 17);
  check_eq "and all seventeen have a ported body"
    (`Int (List.length Status_effect_hooks.descriptors)) (`Int 17);
  check "none is left unported" (Status_effect_hooks.known_unported = []);
  check "the ids are unique"
    (let ids = List.map (fun (d : effect_def) -> d.id) Status_effect_data.descriptors in
     List.length ids = List.length (List.sort_uniq compare ids));
  check "every generated id resolves to a name"
    (List.for_all
       (fun (d : effect_def) -> Status_effect_data.name_of d.id = Some d.name)
       Status_effect_data.descriptors);
  (* Every id a spell applies must resolve, or the spell applies something inert.
     This is the assertion that would have caught the friendly-name bug. *)
  let applied =
    [ "EBLI"; "ECHA"; "EDIS"; "EENR"; "EFAV"; "EFBO"; "EFEA"; "EFSH"; "EHAS"
    ; "EHID"; "EHOP"; "EPAU"; "EPOI"; "ESBL"; "EVIG"; "EWOF"; "EWOT" ]
  in
  check "every status a spell applies has a descriptor"
    (List.for_all (fun id -> Status_effect_data.descriptor_of id <> None) applied)

(* ------------------------------------------------------------------ *)
(* OnStartTurn                                                          *)
(* ------------------------------------------------------------------ *)

let () =
  (* Disease: one off every pool. The header names only Air; the code does all
     four, and 40 becomes 36. *)
  let c = hero ~mana:{ earth = 10; fire = 10; air = 10; water = 10 } () in
  apply_effect (live "EDIS") c;
  start_turn c 1;
  check_eq "Disease drains every pool" (`Int (total_mana c.mana)) (`Int 36);
  check_eq "leaving nine in Earth" (`Int c.mana.earth) (`Int 9);
  check_eq "and nine in Air, despite the header naming only Air" (`Int c.mana.air) (`Int 9)

let () =
  (* Poison: a life a turn, and not below zero. *)
  let c = hero ~life:3 () in
  apply_effect (live "EPOI") c;
  start_turn c 1;
  check_eq "Poison takes a life" (`Int c.life) (`Int 2);
  apply_effect (live "EPOI") c;
  start_turn c 2;
  start_turn c 3;
  check_eq "and stops at zero rather than going negative" (`Int c.life) (`Int 0)

let () =
  (* Paladin's Aura: two of each pool a turn. *)
  let c = hero () in
  apply_effect (live "EPAU") c;
  start_turn c 1;
  check_eq "PaladinsAuraed banks two of each" (`Int (total_mana c.mana)) (`Int 8);
  (* The ceiling stops it going further: default_mana_limit is 20. *)
  for _ = 1 to 20 do start_turn c 1 done;
  check_eq "and never past the ceiling" (`Int (total_mana c.mana)) (`Int 80)

let () =
  (* Fire Bombed: five damage once the caster has 12 Fire, to its enemies. *)
  let c = hero ~mana:{ zero_mana with fire = 12 } () in
  let f = foe ~life:20 () in
  apply_effect (live "EFBO") c;
  start_turn ~enemies:[ f ] c 1;
  check_eq "FireBombed hits for five at 12 Fire" (`Int f.life) (`Int 15);
  let c2 = hero ~mana:{ zero_mana with fire = 11 } () in
  let f2 = foe ~life:20 () in
  apply_effect (live "EFBO") c2;
  start_turn ~enemies:[ f2 ] c2 1;
  check_eq "and not at 11" (`Int f2.life) (`Int 20)

let () =
  (* Blinded: no spells this turn. The latch is cleared at the top of every turn
     and set again by the hook, so what matters is that a character {e without}
     Blinded is never blocked - including one who was blocked last turn.

     A blinded character stays blocked on the next turn too, and that is correct
     rather than a missing clear: Blinded is a five-turn effect whose hook runs
     every turn. The clearing is observable only from the outside. *)
  let c = hero () in
  let s = state () in
  run_start_of_turn_effects c defs ~turn:1 ~enemies:[] ~roll:(fun _ -> 0) ~battle:s;
  check "an unblinded character is not blocked" (not s.spells_disallowed);
  let blocked = hero () in
  apply_effect (live "EBLI") blocked;
  run_start_of_turn_effects blocked defs ~turn:1 ~enemies:[] ~roll:(fun _ -> 0) ~battle:s;
  check_eq "Blinded disallows spells" (`Bool s.spells_disallowed) (`Bool true);
  run_start_of_turn_effects blocked defs ~turn:2 ~enemies:[] ~roll:(fun _ -> 0) ~battle:s;
  check "and keeps disallowing while it lasts, because the hook runs each turn"
    s.spells_disallowed;
  (* The clear, from outside: something else set the flag and nothing re-raises
     it. *)
  let plain = hero () in
  s.spells_disallowed <- true;
  run_start_of_turn_effects plain defs ~turn:1 ~enemies:[] ~roll:(fun _ -> 0) ~battle:s;
  check "the latch clears for anyone the hooks do not block" (not s.spells_disallowed)

(* ------------------------------------------------------------------ *)
(* OnExtraTurn                                                          *)
(* ------------------------------------------------------------------ *)

let () =
  (* Hasted: four damage to the owner's enemies per extra turn. Note the argument
     is the caster and Std_InflictDamage hits that character's *enemy*, so it is
     the enemies that lose life, not the Hasted character. *)
  let c = hero ~life:20 () in
  let f = foe ~life:20 () in
  apply_effect (live "EHAS") c;
  extra_turn ~enemies:[ f ] c;
  check_eq "Hasted hits the owner's enemies" (`Int f.life) (`Int 16);
  check_eq "and not the owner" (`Int c.life) (`Int 20)

(* ------------------------------------------------------------------ *)
(* OnGiveDamage                                                         *)
(* ------------------------------------------------------------------ *)

let () =
  (* Challenged: +50%, but only when both sides carry it. The division truncates,
     so an odd hit loses its remainder. *)
  let a = hero () and b = foe () in
  apply_effect (live "ECHA") a;
  apply_effect (live "ECHA") b;
  check_eq "Challenged adds half when both sides have it" (`Int (give a b 10)) (`Int 15);
  check_eq "truncating, so 5 becomes 7" (`Int (give a b 5)) (`Int 7);
  let lone = hero () and plain = foe () in
  apply_effect (live "ECHA") lone;
  check_eq "a lone Challenged does nothing" (`Int (give lone plain 10)) (`Int 10);
  let other = hero () and also_plain = foe () in
  apply_effect (live "ECHA") also_plain;
  check_eq "and it has to be the defender too" (`Int (give other also_plain 10)) (`Int 10)

let () =
  (* Hand of Powered: a flat +2, and it stacks to +4. *)
  let a = hero () and b = foe () in
  apply_effect (live "EHOP") a;
  check_eq "HandOfPowered adds two" (`Int (give a b 10)) (`Int 12);
  a.effects <- a.effects @ [ ("EHOP", 6) ];
  check_eq "two copies add four" (`Int (give a b 10)) (`Int 14)

let () =
  (* Hidden: double damage while it lasts, and being hit ends it. *)
  let a = hero () and b = foe () in
  apply_effect (live "EHID") a;
  check_eq "Hidden doubles outgoing damage" (`Int (give a b 10)) (`Int 20);
  check_eq "and Hidden is indefinite" (`Int (snd (List.hd a.effects))) (`Int 0);
  (* Being hit sets the duration to 1, which is not a removal: it still doubles
     this turn and dies on the next tick. *)
  ignore (receive a b 5);
  check_eq "being hit schedules Hidden to lapse" (`Int (snd (List.hd a.effects))) (`Int 1);
  check_eq "and it still doubles until the tick" (`Int (give a b 10)) (`Int 20);
  start_turn a 1;
  check "and then it is gone" (not (has_status a "EHID"));
  let c = hero () in
  apply_effect (live "EHID") c;
  start_turn c 1;
  check "an untouched Hidden is still there after a turn" (has_status c "EHID")

let () =
  (* Singing Blades: four off the *target's* every pool when the wielder hits. The
     hook lives on the wielder, so it has to be applied to [a]. *)
  let a = hero () in
  let b = foe ~mana:{ earth = 20; fire = 20; air = 20; water = 20 } () in
  apply_effect (live "ESBL") a;
  check_eq "SingingBladesed returns the damage unchanged" (`Int (give a b 10)) (`Int 10);
  check_eq "and takes four off each of the target's pools"
    (`Int (total_mana b.mana)) (`Int 64);
  check "the wielder's pools are untouched" (total_mana a.mana = 0);
  (* It floors rather than going negative. *)
  let poor = foe ~mana:{ zero_mana with earth = 2 } () in
  ignore (give a poor 10);
  check_eq "and floors at zero" (`Int poor.mana.earth) (`Int 0)

(* ------------------------------------------------------------------ *)
(* OnReceiveDamage                                                      *)
(* ------------------------------------------------------------------ *)

let () =
  (* Fire Shielded: one off anything above one. *)
  let d = hero () and s = hero () in
  apply_effect (live "EFSH") d;
  check_eq "FireShielded takes one off a 5" (`Int (receive d s 5)) (`Int 4);
  check_eq "and off a 2" (`Int (receive d s 2)) (`Int 1);
  check_eq "but not off a 1, because the test is > 1" (`Int (receive d s 1)) (`Int 1)

let () =
  (* Wall of Fire and Wall of Thorns: damage comes out of a pool, and the wall
     falls when the pool does. The overflow is what comes off life. *)
  let d = hero ~mana:{ zero_mana with fire = 10 } () and s = hero () in
  apply_effect (live "EWOF") d;
  check_eq "WallOfFire absorbs a hit inside the pool" (`Int (receive d s 4)) (`Int 0);
  check_eq "and the pool paid" (`Int d.mana.fire) (`Int 6);
  check_eq "an overflow comes off life" (`Int (receive d s 10)) (`Int 4);
  check_eq "the pool emptied" (`Int d.mana.fire) (`Int 0);
  check "and the wall scheduled itself to lapse" (snd (List.hd d.effects) = 1);
  (* A hit that exactly empties the pool also breaks it: the comparison is
     <= 0, not < 0. *)
  let d2 = hero ~mana:{ zero_mana with fire = 5 } () and s2 = hero () in
  apply_effect (live "EWOF") d2;
  check_eq "a hit that exactly empties the pool deals nothing"
    (`Int (receive d2 s2 5)) (`Int 0);
  check "but still breaks the wall" (snd (List.hd d2.effects) = 1);
  (* And its own start-turn hook drains two more, breaking it if it empties.
     This one goes further than the damage case: the hook sets the duration to 1
     and the {e same} turn's countdown then removes it, so a wall that empties its
     pool on the way into a turn is gone before the turn begins rather than
     lasting one more turn. Damage breaks it mid-turn and it survives to the
     tick, which is the asymmetry. *)
  let d3 = hero ~mana:{ zero_mana with fire = 2 } () in
  apply_effect (live "EWOF") d3;
  start_turn d3 1;
  check_eq "WallOfFire bleeds two Fire a turn" (`Int d3.mana.fire) (`Int 0);
  check "and is gone immediately when that empties it" (not (has_status d3 "EWOF"));
  (* With room to spare it survives, and keeps costing. *)
  let d4 = hero ~mana:{ zero_mana with fire = 6 } () in
  apply_effect (live "EWOF") d4;
  start_turn d4 1;
  check_eq "with Fire to spare it stands and costs two" (`Int d4.mana.fire) (`Int 4);
  check "and is still standing" (has_status d4 "EWOF");
  (* Wall of Thorns is the same body against Earth. *)
  let t = hero ~mana:{ zero_mana with earth = 3 } () in
  let s3 = hero () in
  apply_effect (live "EWOT") t;
  check_eq "WallOfThornsed pays out of Earth" (`Int (receive t s3 2)) (`Int 0);
  check_eq "and Earth fell by two" (`Int t.mana.earth) (`Int 1);
  check "it did not touch Fire" (t.mana.fire = 0);
  let t2 = hero () in
  apply_effect (live "EWOT") t2;
  start_turn t2 1;
  check_eq "and its bleed is Earth, not Fire" (`Int (total_mana t2.mana)) (`Int 0)

(* ------------------------------------------------------------------ *)
(* OnQuerySkill                                                         *)
(* ------------------------------------------------------------------ *)

let () =
  (* Fear halves every skill and ignores which one was asked about. *)
  let c = hero () in
  c.skills <- { zero_skills with battle = 10; cunning = 9 };
  check_eq "a skill with no effects passes through" (`Int (query c SBattle 10)) (`Int 10);
  apply_effect (live "EFEA") c;
  check_eq "Fear halves Battle" (`Int (query c SBattle 10)) (`Int 5);
  check_eq "and halves Cunning too, since it ignores skillIdx" (`Int (query c SCunning 9)) (`Int 4)

let () =
  (* Enraged adds the Fire pool to Battle, and only to Battle. *)
  let c = hero ~mana:{ zero_mana with fire = 7 } () in
  c.skills <- { zero_skills with battle = 10; cunning = 9 };
  apply_effect (live "EENR") c;
  check_eq "Enraged adds the Fire pool to Battle" (`Int (query c SBattle 10)) (`Int 17);
  check_eq "and leaves Cunning alone" (`Int (query c SCunning 9)) (`Int 9);
  check_eq "and Fire itself alone" (`Int (query c SFire 10)) (`Int 10)

let () =
  (* Both together: Enraged reads the pool directly, so it does not see Fear's
     halving, and the order they sit in decides the result. *)
  let c = hero ~mana:{ zero_mana with fire = 8 } () in
  c.skills <- { zero_skills with battle = 10 };
  apply_effect (live "EFEA") c;
  apply_effect (live "EENR") c;
  check_eq "Fear then Enraged: half of ten is five, plus eight" (`Int (query c SBattle 10)) (`Int 13)

(* ------------------------------------------------------------------ *)
(* OnReceiveXP                                                          *)
(* ------------------------------------------------------------------ *)

let () =
  (* Favored: a fresh 50% roll per point of experience. Ten points is ten rolls,
     not one - which is why the roll is a sequence here. *)
  let c = hero ~life:50 () in
  apply_effect (live "EFAV") c;
  (* All ten inside the threshold (<= 50) so all ten heal. *)
  ignore
    (receive_xp c defs ~enemies:[] ~roll:(seq_roll [ 50; 50; 50; 50; 50; 50; 50; 50; 50; 50 ])
       ~battle:(state ()) 10);
  check_eq "Favored heals on every roll inside the threshold" (`Int c.life) (`Int 60);
  (* All ten outside it. *)
  let c2 = hero ~life:50 () in
  apply_effect (live "EFAV") c2;
  ignore
    (receive_xp c2 defs ~enemies:[] ~roll:(seq_roll [ 51; 51; 51; 51; 51; 51; 51; 51; 51; 51 ])
       ~battle:(state ()) 10);
  check_eq "and nothing at all when every roll is outside" (`Int c2.life) (`Int 50);
  (* Half of them, which is the case a single roll would get wrong. *)
  let c3 = hero ~life:50 () in
  apply_effect (live "EFAV") c3;
  ignore
    (receive_xp c3 defs ~enemies:[] ~roll:(seq_roll [ 10; 90; 10; 90; 10; 90; 10; 90; 10; 90 ])
       ~battle:(state ()) 10);
  check_eq "a mix of rolls heals the mix that passed" (`Int c3.life) (`Int 55);
  (* The XP itself is untouched - only the healing is extra. *)
  let returned =
    receive_xp c3 defs ~enemies:[] ~roll:(seq_roll []) ~battle:(state ()) 7
  in
  check_eq "and the experience is returned unchanged" (`Int returned) (`Int 7);
  (* Healing clamps at max life. *)
  let c4 = hero ~life:99 () in
  apply_effect (live "EFAV") c4;
  ignore
    (receive_xp c4 defs ~enemies:[] ~roll:(seq_roll [ 0; 0; 0; 0; 0; 0; 0; 0; 0; 0 ])
       ~battle:(state ()) 10);
  check_eq "and healing stops at max life" (`Int c4.life) (`Int 100)

(* ------------------------------------------------------------------ *)
(* OnMatch4 / OnMatch5                                                  *)
(* ------------------------------------------------------------------ *)

let () =
  (* Vigiled: three of each pool on a 4-run or a 5-run. The header says five. *)
  let c = hero () in
  apply_effect (live "EVIG") c;
  match_run ~of_five:false c;
  check_eq "Vigiled banks three of each on a 4-run" (`Int (total_mana c.mana)) (`Int 12);
  match_run ~of_five:true c;
  check_eq "and three more on a 5-run" (`Int (total_mana c.mana)) (`Int 24);
  let plain = hero () in
  match_run plain;
  check "an unvigiled character banks nothing" (total_mana plain.mana = 0)

(* ------------------------------------------------------------------ *)
(* Stacking and expiry, through the real descriptors                   *)
(* ------------------------------------------------------------------ *)

let () =
  (* Four of the seventeen stack. A second copy from a different source is
     representable, and each copy runs and ticks on its own. *)
  let c = hero ~mana:{ earth = 10; fire = 10; air = 10; water = 10 } () in
  let d = live "EDIS" in
  check_eq "Disease stacks four" (`Int d.stack) (`Int 4);
  c.effects <- c.effects @ [ ("EDIS", 6); ("EDIS", 6) ];
  start_turn c 1;
  check_eq "two copies drain two" (`Int (total_mana c.mana)) (`Int 32);
  check_eq "and both survive the tick" (`Int (List.length (active_effects c))) (`Int 2);
  check "Poison stacks four" ((def_of "EPOI").stack = 4)

let () =
  (* All three ship with duration 0, and the three leave in different ways.

     Hidden only ever leaves by being hit - nothing drains it - so it really is
     permanent.

     The walls pay their owner two Fire (or Earth) a turn to stand there, so
     "indefinite" only means "no countdown": a wall with an empty pool dies on its
     first turn, and a wall on 20 Fire dies on the tenth. Neither would be right
     to describe as permanent. *)
  let c = hero () in
  apply_effect (live "EHID") c;
  for turn = 1 to 30 do
    start_turn c turn
  done;
  check "Hidden is still up after thirty turns with nothing to cancel it"
    (has_status c "EHID");
  List.iter
    (fun (id, pool) ->
      let d = hero ~mana:{ zero_mana with fire = 20; earth = 20 } () in
      ignore pool;
      apply_effect (live id) d;
      for turn = 1 to 30 do
        start_turn d turn
      done;
      check (id ^ " is not permanent either: its own bleed starves it")
        (not (has_status d id)))
    [ ("EWOF", Fire); ("EWOT", Earth) ];
  check "their xml duration is 0"
    (List.for_all (fun id -> (def_of id).duration = 0) [ "EHID"; "EWOF"; "EWOT" ]);
  (* A wall fed generously outlives its pool would otherwise allow. *)
  let rich = hero ~mana:{ zero_mana with fire = 20 } () in
  apply_effect (live "EWOF") rich;
  for turn = 1 to 9 do
    start_turn rich turn
  done;
  check "a wall on twenty Fire survives nine turns of bleeding"
    (has_status rich "EWOF");
  check_eq "having paid eighteen" (`Int rich.mana.fire) (`Int 2)

let () =
  (* A spell-applied status and its body are the same object. This is the join
     that the friendly-name bug broke: SHID writes an id, and that id has to find
     a descriptor with a body attached. *)
  let c = hero () in
  Spell_effects.apply_status c "EHID" 0;
  check "a spell's status id resolves to a descriptor"
    (Status_effect_data.descriptor_of "EHID" <> None);
  check "and that descriptor has a body"
    (match Status_effect_data.descriptor_of "EHID" with
    | Some d -> (match Status_effect_hooks.hooks_of d.id with Some _ -> true | None -> false)
    | None -> false);
  check "so the applied effect really is Hidden" (has_status c "EHID")

let () =
  if !failures = 0 then print_endline "All status effect tests passed."
  else begin
    Printf.printf "%d status effect test(s) failed.\n" !failures;
    exit 1
  end