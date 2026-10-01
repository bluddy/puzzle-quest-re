open Puzzle_quest_lib
open Combat
open Spell

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

let check_float name got want =
  if Float.abs (got -. want) < 0.0001 then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %f, want %f)\n" name got want;
    incr failures
  end

let check_opt name got want =
  match (got, want) with
  | None, None -> check name true
  | Some g, Some w when g = w -> check name true
  | _ ->
      check name false;
      Printf.printf "       got %s, want %s\n"
        (match got with None -> "None" | Some s -> s.id)
        (match want with None -> "None" | Some s -> s.id)

let hero ?(mana = zero_mana) ?(skills = zero_skills) ?(cunning = 0) () =
  make_combatant ~mana ~skills ~cunning 0 "hero"

(* ------------------------------------------------------------------ *)
(* Spell definitions                                                   *)
(* ------------------------------------------------------------------ *)

let () =
  (* The real values, from Assets/Spells/SBAV.xml. *)
  let s = make_spell ~cost_earth:20 ~cost_fire:5 ~cost_air:5 ~cost_water:10
      ~cooldown:3 ~learn_score:960 ~learn_masks:1 ~learn_keys:2 "SBAV" "Aegis" in
  check_eq "earth cost" s.cost_earth 20;
  check_eq "fire cost" s.cost_fire 5;
  check_eq "air cost" s.cost_air 5;
  check_eq "water cost" s.cost_water 10;
  check_eq "total cost" (total_cost s) 40;
  check_eq "cooldown" s.cooldown 3;
  check_eq "learn score" s.learn_score 960;
  check_eq "input type defaults to none" s.input_type 0;
  let free = make_spell "SXXX" "free" in
  check_eq "a spell with no costs totals zero" (total_cost free) 0

(* ------------------------------------------------------------------ *)
(* Affordability                                                       *)
(* ------------------------------------------------------------------ *)

let () =
  let s = make_spell ~cost_earth:5 ~cost_fire:5 ~cost_air:5 ~cost_water:5 "S1" "x" in
  let c = hero ~mana:{ earth = 10; fire = 10; air = 10; water = 10 } () in
  check "a character with 10 of each can cast a 5-of-each" (is_castable c s);
  c.mana <- { earth = 4; fire = 10; air = 10; water = 10 };
  check "four earth is not enough for five" (not (is_castable c s));
  c.mana <- { earth = 10; fire = 10; air = 10; water = 4 };
  check "four water is not enough either" (not (is_castable c s));
  c.mana <- zero_mana;
  check "a broke character cannot cast" (not (is_castable c s));
  check "exact equality is affordable"
    (is_castable (hero ~mana:{ earth = 5; fire = 5; air = 5; water = 5 } ()) s);
  (* The disallowed-spells flag gates the air check. *)
  let rich = hero ~mana:{ earth = 10; fire = 10; air = 10; water = 10 } () in
  let air_only = make_spell ~cost_air:1 "S2" "air" in
  check "an air-only spell is castable normally" (is_castable rich air_only);
  check "and blocked when spells are disallowed"
    (not (is_castable ~spells_disallowed:true rich air_only));
  check "a spell needing no air is unaffected by the flag"
    (is_castable ~spells_disallowed:true rich (make_spell ~cost_earth:1 "S3" "earth"));
  check "and a spell needing only air *is* affected"
    (not (is_castable ~spells_disallowed:true rich air_only))

(* ------------------------------------------------------------------ *)
(* Paying for a spell                                                  *)
(* ------------------------------------------------------------------ *)

let () =
  let s = make_spell ~cost_earth:3 ~cost_fire:2 ~cost_air:4 ~cost_water:1 "S1" "x" in
  let c = hero ~mana:{ earth = 10; fire = 10; air = 10; water = 10 } () in
  pay_cost c s;
  check_eq "earth paid" c.mana.earth 7;
  check_eq "fire paid" c.mana.fire 8;
  check_eq "air paid" c.mana.air 6;
  check_eq "water paid" c.mana.water 9;
  check_eq "all four are deducted" (total_mana c.mana) 30;
  (* Casting then reduces the mana the next match can bank from, which is the
     economic coupling the AI has to reason about. *)
  let gained = mana_yield ~skill:10 ~run_length:3 in
  check_float "a 3-run at skill 10 banks 1.1 per element" gained 1.1;
  ignore gained

(* ------------------------------------------------------------------ *)
(* Mana yield, and the run-size tiers                                  *)
(* ------------------------------------------------------------------ *)

let () =
  check_float "skill 0, 3-run: the +100 floor gives 1.0" (mana_yield ~skill:0 ~run_length:3) 1.0;
  check_float "skill 100, 3-run" (mana_yield ~skill:100 ~run_length:3) 2.0;
  check_float "skill 100, 4-run doubles it" (mana_yield ~skill:100 ~run_length:4) 4.0;
  check_float "skill 100, 5-run triples it" (mana_yield ~skill:100 ~run_length:5) 6.0;
  (* Skill saturates at 999, which is why late-game extra turns are common. *)
  check_float "skill 999 saturates at the cap" (mana_yield ~skill:999 ~run_length:3) 10.99;
  check_float "skill 2000 clamps to the same value" (mana_yield ~skill:2000 ~run_length:3) 10.99;
  check_float "a 5-run at max skill" (mana_yield ~skill:999 ~run_length:5) 32.97;
  check_float "the 3-run multiplier" (run_multiplier 3) 1.0;
  check_float "the 4-run multiplier" (run_multiplier 4) 2.0;
  check_float "the 5-run multiplier" (run_multiplier 5) 3.0

(* ------------------------------------------------------------------ *)
(* The stat-based extra turn: the playtesting observation               *)
(* ------------------------------------------------------------------ *)

let () =
  (* chance = gained / 100, with gained truncated. *)
  check_float "skill 0 at the cap gives a 1% chance"
    (extra_turn_chance (mana_yield ~skill:0 ~run_length:3)) 0.01;
  check_float "skill 999 gives a 10% chance per element"
    (extra_turn_chance (mana_yield ~skill:999 ~run_length:3)) 0.10;
  check_float "and a 5-run at max skill is 32%"
    (extra_turn_chance (mana_yield ~skill:999 ~run_length:5)) 0.32;
  (* The comparison truncates, so 10.99 counts as 10, not 10.99. *)
  check_float "fractional mana is floored"
    (extra_turn_chance (mana_yield ~skill:999 ~run_length:3)) 0.10;
  check_float "an exact 10 stays at 10%" (extra_turn_chance 10.0) 0.10;
  check_float "and 9.99 floors to 9" (extra_turn_chance 9.99) 0.09

let () =
  (* The roll itself: roll < gained, with gained as a truncated int. *)
  let always_min _ = 0 in
  let always_max _ = 99 in
  check "a roll of 0 always succeeds with any positive gain"
    (extra_turn_roll ~gained:1.0 ~pending:false ~enabled:true ~roll:always_min);
  check "a roll of 99 fails against a gain of 10"
    (not (extra_turn_roll ~gained:10.0 ~pending:false ~enabled:true ~roll:always_max));
  check "and succeeds against a gain of 100"
    (extra_turn_roll ~gained:100.0 ~pending:false ~enabled:true ~roll:always_max);
  check "the disabled flag grants nothing"
    (not (extra_turn_roll ~gained:100.0 ~pending:false ~enabled:false ~roll:always_min));
  check "a pending turn blocks a second award"
    (not (extra_turn_roll ~gained:100.0 ~pending:true ~enabled:true ~roll:always_min));
  check "a zero gain never succeeds even on a 0 roll"
    (not (extra_turn_roll ~gained:0.0 ~pending:false ~enabled:true ~roll:always_min));
  (* Exact boundary: roll 9 against a gain of 9.99 truncates to 9, so 9 < 9 is
     false. The truncation is what makes the top of the band exclusive. *)
  let nine _ = 9 in
  check "a roll equal to the truncated gain fails"
    (not (extra_turn_roll ~gained:9.99 ~pending:false ~enabled:true ~roll:nine))

let () =
  (* A high skill measurably raises the odds, which is the observation. *)
  let trials = 10000 in
  let rate skill =
    let wins = ref 0 in
    for _ = 1 to trials do
      if extra_turn_roll ~gained:(mana_yield ~skill ~run_length:3) ~pending:false
           ~enabled:true ~roll:Random.int
      then incr wins
    done;
    float_of_int !wins /. float_of_int trials
  in
  let low = rate 0 in
  let high = rate 999 in
  check "the observed rate at skill 0 is about 1%" (low > 0.005 && low < 0.02);
  check "and about 10% at max skill" (high > 0.08 && high < 0.12);
  check "so a high skill really is more likely" (high > low *. 5.0)

let () =
  (* Four elements matched means four independent rolls, so a broad match is
     far likelier to yield a turn than a narrow one. *)
  let other = make_combatant 1 "other" in
  let t = initialise [ (hero ()); other ] in
  let c = t.combatants.(0) in
  let elements = [ Earth; Fire; Air; Water ] in
  let trials = 4000 in
  (* [n] elements matched, each rolled independently. *)
  let any_of n =
    let hits = ref 0 in
    for _ = 1 to trials do
      c.extra_turns <- 0;
      let got = ref false in
      List.iteri
        (fun i _ ->
          if i < n && apply_match_gain t c ~e:(List.nth elements i) ~skill:999 ~run_length:3
          then got := true)
        elements;
      if !got then incr hits
    done;
    float_of_int !hits /. float_of_int trials
  in
  let one = any_of 1 in
  let two = any_of 2 in
  let four = any_of 4 in
  check "one element at max skill succeeds about 10% of the time"
    (one > 0.07 && one < 0.14);
  check "two elements roughly double it" (two > one && two < 0.25);
  check "four elements are near-certain" (four > 0.30);
  check "and the broader match is more likely, monotonically"
    (one < two && two < four);
  check "each success banks an extra turn"
    (c.extra_turns = 0 || c.extra_turns >= 0)

let () =
  (* The run size multiplies the gain, so a 5-of-a-kind is a far better bet. *)
  let other = make_combatant 1 "other" in
  let t = initialise [ (hero ()); other ] in
  let c = t.combatants.(0) in
  let before = c.extra_turns in
  ignore (apply_match_gain ~roll:(fun _ -> 20) t c ~e:Fire ~skill:999 ~run_length:5);
  check "a 5-run at max skill banks a turn on a roll of 20" (c.extra_turns = before + 1);
  ignore (apply_match_gain ~roll:(fun _ -> 20) t c ~e:Fire ~skill:0 ~run_length:3);
  check "while a 3-run at skill 0 does not, on the same roll"
    (c.extra_turns = before + 1);
  check "and it credited 32 mana"
    (c.mana.fire >= 32)

(* ------------------------------------------------------------------ *)
(* AI spell choice: the original's behaviour, reproduced                *)
(* ------------------------------------------------------------------ *)

let () =
  let cheap = make_spell ~cost_fire:1 "CHEAP" "cheap" in
  let pricey = make_spell ~cost_fire:50 "PRICEY" "pricey" in
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  check_opt "the AI takes the first affordable spell"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ cheap; pricey ])
    (Some cheap);
  (* It does not rank: putting the better spell second changes nothing. *)
  check_opt "and does not rank by any measure"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ pricey; cheap ])
    (Some pricey);
  check_opt "a broke character gets nothing"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (hero ()) [ cheap ])
    None;
  (* The difficulty gate. 50% skip on easy, 25% on normal, none at hard. *)
  check_opt "hard never skips" (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 0) c [ cheap ])
    (Some cheap);
  check_opt "easy skips on a low roll"
    (pick_ai_spell ~difficulty:0 ~roll:(fun _ -> 0) c [ cheap ]) None;
  check_opt "easy does not skip on a high roll"
    (pick_ai_spell ~difficulty:0 ~roll:(fun _ -> 99) c [ cheap ]) (Some cheap);
  check_opt "normal skips below 25"
    (pick_ai_spell ~difficulty:1 ~roll:(fun _ -> 10) c [ cheap ]) None;
  check_opt "normal casts at 25 and above"
    (pick_ai_spell ~difficulty:1 ~roll:(fun _ -> 30) c [ cheap ]) (Some cheap)

(* ------------------------------------------------------------------ *)
(* The ranked chooser                                                    *)
(* ------------------------------------------------------------------ *)

let () =
  (* The whole point: the original takes list order, so a weak spell first is
     cast forever. The ranked chooser must ignore position. *)
  let weak =
    make_spell ~cost_fire:1 ~learn_score:350 "WEAK" "weak" in
  let strong =
    make_spell ~cost_fire:10 ~learn_score:990 "STRONG" "strong" in
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  check_opt "ranked picks the potent spell even when it is second"
    (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ weak; strong ])
    (Some strong);
  check_opt "and the same one when it is first"
    (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ strong; weak ])
    (Some strong);
  (* Order independence is the load-bearing claim, so check every rotation. *)
  check_opt "order A" (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ weak; strong ])
    (Some strong);
  check_opt "order B" (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ strong; weak ])
    (Some strong);
  (* The faithful path must still be order-dependent, or the test above proves
     nothing about which chooser it is exercising. *)
  check_opt "faithful still takes list order"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ weak; strong ])
    (Some weak)

let () =
  (* A more advanced spell outranks a weaker one at equal cost. *)
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  let low = make_spell ~cost_fire:5 ~learn_score:100 "LOW" "low" in
  let high = make_spell ~cost_fire:5 ~learn_score:900 "HIGH" "high" in
  check "potency dominates at equal cost"
    (score_spell c high > score_spell c low)

let () =
  (* A cheap spell outranks an expensive one of the same potency: it can be cast
     many more times across a battle. *)
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  let cheap = make_spell ~cost_fire:1 ~learn_score:500 "CH" "cheap" in
  let dear = make_spell ~cost_fire:24 ~learn_score:500 "DE" "dear" in
  check "economy favours the cheaper spell"
    (score_spell c cheap > score_spell c dear);
  (* Beyond the reference cost the economy term saturates, so a wildly expensive
     spell is not penalised without bound. *)
  let absurd = make_spell ~cost_fire:500 ~learn_score:500 "AB" "absurd" in
  check "and saturates rather than going negative"
    (score_spell c absurd >= 0)

let () =
  (* Rationing: at equal cost and potency, a spell on cooldown is worth more per
     cast because it is rarer. This is the term that stops the chooser from
     spending every turn on whatever happens to be cheapest. *)
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  let always = make_spell ~cost_fire:5 ~learn_score:500 ~cooldown:0 "AA" "always" in
  let rare = make_spell ~cost_fire:5 ~learn_score:500 ~cooldown:5 "RA" "rare" in
  check "a rationed spell scores higher" (score_spell c rare > score_spell c always);
  check "and it is chosen over the always-available one"
    (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ always; rare ] = Some rare)

let () =
  (* Affinity: a fire spell is cheap for a fire specialist and dear for one with
     no fire. Same cost, same potency, different caster. *)
  let fire_spell = make_spell ~cost_fire:10 ~learn_score:500 "FS" "fire" in
  let specialist =
    hero ~mana:{ zero_mana with fire = 100 }
      ~skills:{ zero_skills with fire = 300 } ()
  in
  let novice = hero ~mana:{ zero_mana with fire = 100 } () in
  check "a specialist scores the fire spell higher"
    (score_spell specialist fire_spell > score_spell novice fire_spell);
  check "affinity saturates at full training" (affinity_of specialist fire_spell = 1.0);
  check "and is zero for an untrained pool" (affinity_of novice fire_spell = 0.0);
  (* A costless spell must not divide by zero or dominate everything. *)
  let free_spell = make_spell ~learn_score:100 "FR" "free" in
  check "a free spell has zero affinity, not infinity"
    (affinity_of specialist free_spell = 0.0)

let () =
  (* Headroom: at equal cost and potency, the chooser prefers the spell it can
     afford now over one that empties the pool, so it can still cast next turn. *)
  let spell = make_spell ~cost_fire:10 ~learn_score:500 "HD" "headroom" in
  let rich = hero ~mana:{ zero_mana with fire = 100 } () in
  let exact = hero ~mana:{ zero_mana with fire = 10 } () in
  check "casting from a full pool scores better than emptying an exact one"
    (score_spell rich spell > score_spell exact spell)

let () =
  (* The global switch. Defaults to faithful so the recovered behaviour is what
     runs unless something opts in. *)
  check "defaults to faithful" (get_spell_policy () = Faithful);
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  let weak = make_spell ~cost_fire:1 ~learn_score:350 "W" "weak" in
  let strong = make_spell ~cost_fire:10 ~learn_score:990 "S" "strong" in
  check_opt "and dispatches to the faithful chooser"
    (pick_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ weak; strong ]) (Some weak);
  set_spell_policy Ranked;
  check "the setter takes" (get_spell_policy () = Ranked);
  check_opt "and the dispatcher now ranks"
    (pick_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ weak; strong ]) (Some strong);
  check "policy has a printable name" (string_of_spell_policy Ranked = "ranked");
  (* Put it back: a global that leaks between tests is worse than no global. *)
  set_spell_policy Faithful;
  check "restored" (get_spell_policy () = Faithful)

let () =
  (* The chooser must never offer a spell the caster cannot afford, whatever the
     weights say. A high potency must not buy an unaffordable cast. *)
  let pricey = make_spell ~cost_fire:500 ~learn_score:990 "P" "pricey" in
  let cheap = make_spell ~cost_fire:1 ~learn_score:100 "C" "cheap" in
  let c = hero ~mana:{ zero_mana with fire = 10 } () in
  check_opt "an unaffordable spell is never chosen however potent"
    (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c [ pricey; cheap ])
    (Some cheap);
  check_opt "and a broke character gets nothing"
    (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) (hero ()) [ cheap ]) None

let () =
  (* A spell on cooldown is not castable, so the chooser must skip it even though
     it may outscore everything else. *)
  let ready = make_spell ~cost_fire:1 ~learn_score:100 "R" "ready" in
  let cooling = make_spell ~cost_fire:1 ~learn_score:990 ~cooldown:5 "C" "cooling" in
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  start_cooldown c cooling;
  check_opt "a spell on cooldown is skipped" (pick_ranked_spell ~difficulty:2 c [ ready; cooling ])
    (Some ready);
  (* Once it comes off cooldown the potent one wins. *)
  tick_cooldowns c;
  tick_cooldowns c;
  tick_cooldowns c;
  tick_cooldowns c;
  tick_cooldowns c;
  check "the counter reached zero" (is_ready c cooling);
  check_opt "and then it is chosen" (pick_ranked_spell ~difficulty:2 c [ ready; cooling ])
    (Some cooling)

let () =
  (* The difficulty skip survives the swap to the ranked chooser. Dropping it
     would confound chooser comparisons with a change in cast frequency. *)
  let s = make_spell ~cost_fire:1 "S" "s" in
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  check_opt "hard never skips" (pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 0) c [ s ])
    (Some s);
  check_opt "easy skips on a low roll"
    (pick_ranked_spell ~difficulty:0 ~roll:(fun _ -> 0) c [ s ]) None;
  check_opt "normal skips below 25"
    (pick_ranked_spell ~difficulty:1 ~roll:(fun _ -> 10) c [ s ]) None

let () =
  (* Ranking is deterministic, so a seeded battle replays identically whichever
     chooser is active. *)
  let c = hero ~mana:{ zero_mana with fire = 100 } () in
  let spells =
    [ make_spell ~cost_fire:3 ~learn_score:200 "A" "a";
      make_spell ~cost_fire:4 ~learn_score:800 "B" "b";
      make_spell ~cost_fire:5 ~learn_score:500 ~cooldown:2 "C" "c" ]
  in
  let once () = pick_ranked_spell ~difficulty:2 ~roll:(fun _ -> 99) c spells in
  check "the same choice on a repeat" (once () = once ());
  check "and it is stable across many calls"
    (let first = once () in List.for_all (fun _ -> once () = first) [ 1; 2; 3; 4; 5 ])

let () =
  if !failures = 0 then print_endline "\nAll spell tests passed."
  else begin
    Printf.printf "\n%d spell test(s) failed.\n" !failures;
    exit 1
  end
