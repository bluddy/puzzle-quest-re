open Puzzle_quest_lib
open Score

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

let hero ?(max_life = 100) ?(level = 10) ?(current_life = 100) ?(power = 0) () =
  { max_life; level; current_life; power }

let solo ?(turns = 0) ?(difficulty = 1) ?(game_mode = 0) () =
  { difficulty; game_mode; turns; co_op_contributors = 0; co_op = false }

(* Difficulty 2 is unscaled, so the arithmetic below stays in integers. *)
let coop ?(turns = 0) ?(difficulty = 2) ?(game_mode = 0) ?(contributors = 2) () =
  { difficulty; game_mode; turns; co_op_contributors = contributors; co_op = true }

(* ------------------------------------------------------------------ *)
(* Solo path: (turns + 20) * 25 - max_life + current_life             *)
(* ------------------------------------------------------------------ *)

let () =
  (* A 20-turn fight at full health on a 100 HP hero: 40 * 25 - 100 + 100. *)
  check_eq "solo, 20 turns, full health" (compute_score ~inputs:(solo ~turns:20 ()) ~hero_index:0 [ hero () ]) 1000;
  check_eq "solo, 0 turns, full health" (compute_score ~inputs:(solo ()) ~hero_index:0 [ hero () ]) 500;
  (* The turns term dominates: 25 per turn, the health term is worth 1 per HP. *)
  check_eq "each turn is worth 25" (compute_score ~inputs:(solo ~turns:21 ()) ~hero_index:0 [ hero () ]) 1025;
  check_eq "missing 50 HP costs 50 points"
    (compute_score ~inputs:(solo ~turns:20 ()) ~hero_index:0 [ hero ~current_life:50 () ])
    950;
  (* A large max_life can push the score negative, which floors at 1. *)
  check_eq "solo floors at 1"
    (compute_score ~inputs:(solo ()) ~hero_index:0 [ hero ~max_life:10000 ~current_life:1 () ])
    1;
  check_eq "solo at exactly 1 is not clamped"
    (compute_score ~inputs:(solo ()) ~hero_index:0 [ hero ~max_life:499 ~current_life:0 () ])
    1

(* ------------------------------------------------------------------ *)
(* Solo path ignores difficulty and the cap                            *)
(* ------------------------------------------------------------------ *)

let () =
  let score_at difficulty =
    compute_score ~inputs:(solo ~turns:50 ~difficulty ()) ~hero_index:0 [ hero () ]
  in
  check_eq "solo is unscaled at easy" (score_at 0) (score_at 1);
  check_eq "solo is unscaled at hard" (score_at 2) (score_at 1);
  (* 70 turns at full health is 70 * 25 = 1750, well under the cap anyway.
     The cap lives on the co-op path, so this only guards against someone
     adding it to the solo branch. *)
  check "solo stays under the cap for a long fight" (score_at 2 < 50000)

(* ------------------------------------------------------------------ *)
(* Co-op base value                                                    *)
(* ------------------------------------------------------------------ *)

let () =
  (* (turns + 10) * 250 + (cur - max) * 4 - contributors * 15 *)
  let solo_hero = hero ~max_life:100 ~current_life:100 ~level:10 () in
  let base turns contributors =
    ((turns + 10) * 250) + 0 - (contributors * 15)
  in
  (* A lone hero contributes nothing from the loop, so this is pure base. *)
  check_eq "co-op base, 0 turns, 2 contributors"
    (compute_score ~inputs:(coop ~turns:0 ~contributors:2 ()) ~hero_index:0 [ solo_hero ])
    (base 0 2);
  check_eq "co-op base, 20 turns"
    (compute_score ~inputs:(coop ~turns:20 ~contributors:2 ()) ~hero_index:0 [ solo_hero ])
    (base 20 2);
  (* Damage taken is a penalty: (cur - max) * 4 is negative. *)
  check_eq "co-op penalises lost health"
    (compute_score ~inputs:(coop ~turns:0 ~contributors:0 ()) ~hero_index:0
       [ hero ~max_life:100 ~current_life:60 () ])
    (base 0 0 - 160);
  ()

(* ------------------------------------------------------------------ *)
(* Co-op per-character contribution                                    *)
(* ------------------------------------------------------------------ *)

let () =
  let me = hero ~max_life:100 ~level:10 ~power:0 () in
  let score_with other =
    compute_score ~inputs:(coop ~turns:0 ~contributors:0 ()) ~hero_index:0 [ me; other ]
  in
  let base = ((0 + 10) * 250) + 0 - 0 in
  (* Every ally also contributes its own [level * 100], independent of any
     delta, so each expectation carries that term too. *)
  let ally ?(level = 10) ?(max_life = 100) ?(power = 0) () =
    base + ((max_life - 100) * 3) + ((level - 10) * 250) + level_step (level - 10)
    + (power * 100) + (level * 100)
  in
  check_eq "life_delta is scaled by 3"
    (score_with (hero ~max_life:120 ~level:10 ())) (ally ~max_life:120 ());
  check_eq "a lower-life ally subtracts"
    (score_with (hero ~max_life:80 ~level:10 ())) (ally ~max_life:80 ());
  check_eq "an ally 1 level below"
    (score_with (hero ~max_life:100 ~level:9 ())) (ally ~level:9 ());
  check_eq "an ally 1 level above"
    (score_with (hero ~max_life:100 ~level:11 ())) (ally ~level:11 ());
  check_eq "an ally 5 levels above"
    (score_with (hero ~max_life:100 ~level:15 ())) (ally ~level:15 ());
  (* power * 100 *)
  check_eq "an ally's power is scaled by 100"
    (score_with (hero ~max_life:100 ~level:10 ~power:3 ())) (ally ~power:3 ());
  (* An identical ally has every delta at zero, so only level * 100 remains. *)
  check_eq "an identical ally contributes only level * 100"
    (score_with (hero ~max_life:100 ~level:10 ())) (base + 1000);
  (* The hero's own entry contributes nothing. *)
  check_eq "the hero's own entry is skipped"
    (compute_score ~inputs:(coop ~turns:0 ~contributors:0 ()) ~hero_index:0 [ me ])
    base;
  ()

(* ------------------------------------------------------------------ *)
(* The step term is flat, tested directly rather than through a confound *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "step at zero" (level_step 0) 0;
  check_eq "step one level above" (level_step 1) 150;
  check_eq "step five levels above" (level_step 5) 150;
  check_eq "step one level below" (level_step (-1)) (-150);
  check_eq "step fifty levels below" (level_step (-50)) (-150);
  check "the step ignores magnitude"
    (level_step 1 = level_step 40 && level_step (-1) = level_step (-40))

(* ------------------------------------------------------------------ *)
(* Game mode 4 divides the scaled terms by ten                         *)
(* ------------------------------------------------------------------ *)

let () =
  let me = hero ~max_life:100 ~level:10 () in
  let other = hero ~max_life:100 ~level:11 () in
  let score mode =
    compute_score ~inputs:(coop ~turns:0 ~game_mode:mode ()) ~hero_index:0 [ me; other ]
  in
  let base = ((0 + 10) * 250) + 0 - 2 * 15 in
  (* Ally at level 11 against a hero at level 10: +250 (or +25) for the
     level delta, +150 for the step, and +1100 (or +110) for its own level. *)
  check_eq "normal mode adds 250 + 150 + 1100"
    (score 0) (base + 250 + 150 + 1100);
  (* Mode 4 divides the level term and both 100-multiples by ten; the flat
     150 step is not scaled. *)
  check_eq "game mode 4 divides the level and 100-multiples by ten"
    (score 4) (base + 25 + 150 + 110);
  check "game mode 4 is well below normal mode" (score 4 < score 0);
  ()

(* ------------------------------------------------------------------ *)
(* Difficulty scaling on the co-op path                                 *)
(* ------------------------------------------------------------------ *)

let () =
  let me = hero ~max_life:100 ~level:10 () in
  let score_at difficulty =
    compute_score ~inputs:{ (coop ~turns:0 ()) with difficulty } ~hero_index:0 [ me ]
  in
  let raw = compute_score ~inputs:(coop ~turns:0 ~difficulty:2 ()) ~hero_index:0 [ me ] in
  check_eq "easy scores a third" (score_at 0) (raw / 3);
  check_eq "normal scores two thirds" (score_at 1) ((raw * 2) / 3);
  check_eq "hard is unscaled" (score_at 2) raw;
  check_eq "difficulties 3 and above are unscaled" (score_at 7) raw;
  check "easy is well below normal" (score_at 0 < score_at 1);
  (* Game mode 4 skips the difficulty scaling entirely. *)
  check_eq "game mode 4 skips difficulty scaling"
    (compute_score ~inputs:(coop ~turns:0 ~difficulty:0 ~game_mode:4 ()) ~hero_index:0 [ me ])
    (compute_score ~inputs:(coop ~turns:0 ~difficulty:1 ~game_mode:4 ()) ~hero_index:0 [ me ]);
  ()

(* ------------------------------------------------------------------ *)
(* Clamping                                                            *)
(* ------------------------------------------------------------------ *)

let () =
  let me = hero ~max_life:100 ~level:10 () in
  (* Push the base over 50 000 with a very long fight. *)
  let long_fight = compute_score ~inputs:(coop ~turns:500 ()) ~hero_index:0 [ me ] in
  check_eq "the co-op path caps at 50 000" long_fight 50000;
  (* Drive it negative: a huge max_life against a tiny current_life. *)
  let wrecked = hero ~max_life:100000 ~level:0 ~current_life:0 () in
  check_eq "the co-op path floors at 1"
    (compute_score ~inputs:(coop ~turns:0 ()) ~hero_index:0 [ wrecked ])
    1;
  check_eq "a score of exactly 50 000 is not clamped"
    (compute_score ~inputs:(coop ~turns:190 ()) ~hero_index:0 [ me ])
    49970;
  check_eq "just over the cap is clamped"
    (compute_score ~inputs:(coop ~turns:191 ()) ~hero_index:0 [ me ])
    50000;
  check_eq "just under the cap passes through"
    (compute_score ~inputs:(coop ~turns:189 ()) ~hero_index:0 [ me ])
    49720;
  ()

(* ------------------------------------------------------------------ *)
(* The co-op payout helper, whose difficulty sense is inverted         *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "payout: easy multiplies by 3/4" (compute_co_op_payout ~game_mode:0 ~difficulty:0 1000) 750;
  check_eq "payout: normal is unscaled" (compute_co_op_payout ~game_mode:0 ~difficulty:1 1000) 1000;
  check_eq "payout: hard multiplicates by 5/4" (compute_co_op_payout ~game_mode:0 ~difficulty:2 1000) 1250;
  check_eq "payout: game mode 4 is unscaled" (compute_co_op_payout ~game_mode:4 ~difficulty:0 1000) 1000;
  (* Both functions rise with difficulty; neither is inverted. The discrepancy
     is the baseline: this one leaves difficulty 1 alone while the score
     function discounts it. Pinned so a future reader does not "fix" one to
     match the other without noticing. *)
  check "the payout is monotonic in difficulty"
    (compute_co_op_payout ~game_mode:0 ~difficulty:0 1000
    < compute_co_op_payout ~game_mode:0 ~difficulty:1 1000
    && compute_co_op_payout ~game_mode:0 ~difficulty:1 1000
       < compute_co_op_payout ~game_mode:0 ~difficulty:2 1000);
  let score_at d =
    compute_score ~inputs:{ (coop ~turns:0 ()) with difficulty = d } ~hero_index:0 [ hero () ]
  in
  check "difficulty 1 is discounted for the score"
    (score_at 1 < score_at 2);
  check "difficulty 1 is untouched for the payout"
    (compute_co_op_payout ~game_mode:0 ~difficulty:1 1000 = 1000);
  ()

let () =
  if !failures = 0 then print_endline "\nAll score tests passed."
  else begin
    Printf.printf "\n%d score test(s) failed.\n" !failures;
    exit 1
  end
