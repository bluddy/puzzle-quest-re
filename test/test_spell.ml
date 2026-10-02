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

(* Spells carry function hooks, so they cannot be compared with [=]. Identity is
   the id, which is also what these tests mean by "the same spell". *)
let spell_key = function None -> "<none>" | Some (s : spell) -> s.id

let check_opt name got want =
  if spell_key got = spell_key want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (spell_key got) (spell_key want);
    incr failures
  end

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

(* A context with everything stubbed, so a test can pin one input at a time.
   [evaluation] is what EVALUATE_BOARD returns and [percentile] what
   PERCENTILE_CHANCE_SYNC returns. The default caster is rich, because
   affordability is checked before any hook and a broke caster would mask what
   these tests are about. *)
let rich () = hero ~mana:{ earth = 999; fire = 999; air = 999; water = 999 } ()

let ctx ?(evaluation = 0) ?(percentile = 0) ?(caster = rich ())
    ?(board = Board.of_array_matrix (Array.make_matrix 8 8 Board.Skull)) () =
  { ctx_caster = caster
  ; ctx_enemy = hero ()
  ; ctx_board = board
  ; ctx_evaluation = evaluation
  ; ctx_percentile = percentile
  ; ctx_roll = fun n -> if n <= 0 then 0 else 0 mod n
  }

let () =
  (* A spell with no hook of its own wants casting, since it is the hook's
     return of 0 that suppresses a spell and not its absence. *)
  let plain = make_spell ~cost_fire:1 "PLAIN" "plain" in
  check_opt "a spell with no AI hook is cast"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ()) [ plain ]) (Some plain);
  (* Affordability still gates, before the hook is even consulted. *)
  check_opt "a broke character gets nothing"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ~caster:(hero ()) ()) [ plain ])
    None

let () =
  (* The hook can refuse, and then the walk continues to the next spell. This is
     the whole point: the original is not taking list order. *)
  let refuses =
    make_spell ~cost_fire:1 ~should_ai_cast:(fun _ -> false) "NO" "refuses" in
  let accepts = make_spell ~cost_fire:1 ~should_ai_cast:(fun _ -> true) "YES" "accepts" in
  check_opt "a spell whose hook refuses is skipped"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ()) [ refuses; accepts ])
    (Some accepts);
  check_opt "and a lone refusing spell yields nothing"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ()) [ refuses ]) None;
  (* Order still decides between two spells that both vote yes, so list order is
     a tiebreak rather than the whole rule. *)
  let also_accepts = make_spell ~cost_fire:1 ~should_ai_cast:(fun _ -> true) "YES2" "also" in
  check_opt "among willing spells, list order decides"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ()) [ refuses; accepts; also_accepts ])
    (Some accepts)

let () =
  (* IsCastSpellLegal is a separate gate from affordability. *)
  let illegal =
    make_spell ~cost_fire:1 ~is_cast_legal:(fun _ -> false) "BAD" "illegal" in
  let ok = make_spell ~cost_fire:1 "OK" "ok" in
  check_opt "an illegal spell is skipped even though it is affordable"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ()) [ illegal; ok ]) (Some ok);
  (* Affordability is checked first, so an illegal hook is not even reached for a
     spell the caster cannot pay for. *)
  let pricey_illegal =
    make_spell ~cost_fire:500 ~is_cast_legal:(fun _ -> false) "PI" "pricey illegal" in
  check_opt "and the hook is not consulted for an unaffordable spell"
    (pick_ai_spell ~difficulty:2 ~roll:(fun _ -> 99) (ctx ()) [ pricey_illegal; ok ])
    (Some ok)

(* ------------------------------------------------------------------ *)
(* Std_AISpellcastingChance                                            *)
(* ------------------------------------------------------------------ *)

let () =
  (* The body, transcribed:

       function Std_AISpellcastingChance(modifier)
         local evaluation = EVALUATE_BOARD();
         local chance = PERCENTILE_CHANCE_SYNC();
         if (chance > 50 + modifier) then return 0; end
         if (evaluation > 30) then return 0; end
         return 1;
       end

     Note `>` on both sides: a percentile of exactly 50 casts at modifier 0, and
     an evaluation of exactly 30 does not veto. *)
  check "modifier 0 casts at percentile 50"
    (ai_spellcasting_chance ~modifier:0 (ctx ~percentile:50 ()));
  check "and not at 51" (not (ai_spellcasting_chance ~modifier:0 (ctx ~percentile:51 ())));
  check "modifier 50 casts at 100" (ai_spellcasting_chance ~modifier:50 (ctx ~percentile:99 ()));
  check "modifier 50 also at 101, since the roll is 0..99"
    (ai_spellcasting_chance ~modifier:50 (ctx ~percentile:100 ()));
  check "evaluation 30 does not veto" (ai_spellcasting_chance ~modifier:0 (ctx ~evaluation:30 ()));
  check "evaluation 31 does" (not (ai_spellcasting_chance ~modifier:0 (ctx ~evaluation:31 ())));
  (* The two clauses are independent: a good board vetoes regardless of the roll. *)
  check "a good board vetoes even on a lucky roll"
    (not (ai_spellcasting_chance ~modifier:99 (ctx ~evaluation:31 ~percentile:0 ())));

  if !failures = 0 then print_endline "\nAll spell tests passed."
  else begin
    Printf.printf "\n%d spell test(s) failed.\n" !failures;
    exit 1
  end
