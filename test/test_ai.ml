open Puzzle_quest_lib
open Board
open Ai

(** Always returns the minimum, so every random band in the scoring function
    contributes nothing and the arithmetic can be asserted exactly. *)
let min_rng _ = 0

(** Always returns the maximum, i.e. an inclusive-range roll lands on [hi]. *)
let max_rng n = n - 1

(** An rng that returns a scripted sequence of values, repeating the last one
    once exhausted. Use this when a single call to [score_match_result]
    draws more than one random number. *)
let scripted values =
  let i = ref 0 in
  fun n ->
    let v = List.nth values (min !i (List.length values - 1)) in
    incr i;
    if v >= n then n - 1 else v

let stable_score ?(weights = default_weights) res len x =
  score_match_result ~weights ~rng:min_rng ~difficulty:2 ~hero:no_hero res len x

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

(* ------------------------------------------------------------------ *)
(* Fixtures                                                            *)
(* ------------------------------------------------------------------ *)

(** A fully specified board, given as eight eight-character rows.
    Characters: [e]arth [f]ire [w]ater [a]ir [s]kull [r]ed skull [g]old
    [x]p [. ]empty, and [2]..[8] for the wildcard multipliers. Rows are
    listed top to bottom, so the last row is row 7.

    Empty is the useful blocker in these fixtures: gem id 0 fails the guard
    at the top of 0x47AFF0, so an empty cell neither joins a run nor starts
    one. *)
let board rows =
  let of_char = function
    | 'e' -> Mana Earth
    | 'f' -> Mana Fire
    | 'w' -> Mana Water
    | 'a' -> Mana Air
    | 's' -> Skull
    | 'r' -> RedSkull
    | 'g' -> Gold
    | 'x' -> Experience
    | '2' -> Wildcard 2
    | '3' -> Wildcard 3
    | '4' -> Wildcard 4
    | '5' -> Wildcard 5
    | '6' -> Wildcard 6
    | '7' -> Wildcard 7
    | '8' -> Wildcard 8
    (* [.] is an empty cell. Empty never matches, per 0x47AFF0's guard on
       gem id 0, so it is a safe blocker. *)
    | '.' -> Empty
    | c -> failwith (Printf.sprintf "unknown board character %c" c)
  in
  let matrix =
    Array.of_list
      (List.map
         (fun row ->
           Array.of_list
             (List.init 8 (fun x ->
                  if x >= String.length row then Empty
                  else of_char row.[x])))
         rows)
  in
  of_array_matrix matrix

(** A board with no runs and no productive swap: a 4-cycle over the mana
    elements, laid out so no two orthogonally adjacent cells share an
    element. Written out rather than generated, so the fixture is readable
    in the test output. *)
let locked_board =
  board
    [ "fwaefwae"; "aefwaefw"; "fwaefwae"; "aefwaefw";
      "fwaefwae"; "aefwaefw"; "fwaefwae"; "aefwaefw" ]

(* ------------------------------------------------------------------ *)
(* Probe tables, read verbatim from .rdata at 0x005212D8                *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "h-window after a horizontal swap has 2 entries"
    (List.length offsets_after_horizontal_swap_h) 2;
  check_eq "v-window after a horizontal swap has 6 entries"
    (List.length offsets_after_horizontal_swap_v) 6;
  check_eq "h-window after a vertical swap has 6 entries"
    (List.length offsets_after_vertical_swap_h) 6;
  check_eq "v-window after a vertical swap has 2 entries"
    (List.length offsets_after_vertical_swap_v) 2

(* ------------------------------------------------------------------ *)
(* Gem ids                                                             *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "earth is id 1" (gem_id (Mana Earth)) 1;
  check_eq "fire is id 2" (gem_id (Mana Fire)) 2;
  check_eq "water is id 3" (gem_id (Mana Water)) 3;
  check_eq "air is id 4" (gem_id (Mana Air)) 4;
  check_eq "skull is id 5" (gem_id Skull) 5;
  check_eq "gold is id 6" (gem_id Gold) 6;
  check_eq "xp is id 7" (gem_id Experience) 7;
  check_eq "red skull is id 0xf" (gem_id RedSkull) 0xf;
  check_eq "a 2x wildcard is id 8" (gem_id (Wildcard 2)) 8;
  check_eq "an 8x wildcard is id 14" (gem_id (Wildcard 8)) 14;
  List.iter
    (fun g -> check ("gem_of_id inverts gem_id for " ^ string_of_gem g) (gem_of_id (gem_id g) = g))
    [ Mana Earth; Mana Fire; Mana Water; Mana Air; Skull; Gold; Experience; RedSkull;
      Wildcard 2; Wildcard 3; Wildcard 4; Wildcard 5; Wildcard 6; Wildcard 7 ]

(* ------------------------------------------------------------------ *)
(* Matching predicate, 0x47AFF0                                        *)
(* ------------------------------------------------------------------ *)

let () =
  check "skull and red skull match each other" (ids_match 5 0xf && ids_match 0xf 5);
  check "skull does not match fire" (not (ids_match 5 2));
  check "a wildcard stands in for every mana element"
    (List.for_all (fun id -> ids_match 8 id && ids_match id 8) [ 1; 2; 3; 4 ]);
  check "identical wildcards match" (ids_match 8 8);
  check "a 2x and a 3x wildcard do not match" (not (ids_match 8 9));
  check "a wildcard does not stand in for gold" (not (ids_match 8 6));
  check "a wildcard does not stand in for a skull" (not (ids_match 8 5));
  check "gold does not match fire" (not (ids_match 6 2));
  check "an empty cell never matches" (not (ids_match 0 1) && not (ids_match 1 0))

(* ------------------------------------------------------------------ *)
(* check_match, 0x47C8C0                                               *)
(* ------------------------------------------------------------------ *)

let () =
  let b =
    board
      [ "........"; "........"; "........"; "..ggg...";
        "........"; "........"; "........"; "........" ]
  in
  check_eq "a 3-run measures 3 from its middle cell" (check_match b 3 3 Horizontal) 3;
  check_eq "a 3-run measures 3 from either end" (check_match b 4 3 Horizontal) 3;
  check_eq "a 3-run measures 3 from the other end" (check_match b 2 3 Horizontal) 3;
  check_eq "the same cells are not a vertical run" (check_match b 3 3 Vertical) 1;
  check_eq "the row above has no run" (check_match b 3 2 Horizontal) 0;
  check "row 0 is the spawn buffer, outside the playable area" (check_match b 3 0 Horizontal = 0);
  check "x = width is out of range" (check_match b 8 3 Horizontal = 0);
  check "y = height + 1 is out of range" (check_match b 3 9 Horizontal = 0);
  let b5 =
    board
      [ "........"; "........"; "fffff..."; "........";
        "........"; "........"; "........"; "........" ]
  in
  check_eq "a 5-run measures 5 from an interior cell" (check_match b5 2 2 Horizontal) 5;
  check_eq "a 5-run measures 5 from either end" (check_match b5 0 2 Horizontal) 5;
  check_eq "that column is a vertical run of 1" (check_match b5 2 2 Vertical) 1;
  (* A wildcard stands in for whichever mana element it neighbours, so the
     fixture walls the run with empty cells to isolate it. *)
  let bw =
    board
      [ "........"; "........"; "........"; "ff2....."; "........";
        "........"; "........"; "........" ]
  in
  check_eq "a wildcard bridges two fire gems" (check_match bw 1 3 Horizontal) 3

(* ------------------------------------------------------------------ *)
(* Scoring formula, 0x43F970                                           *)
(* ------------------------------------------------------------------ *)

let () =
  (* base = sum(count * weight) + 3 * run_length + match_x + 30 per bonus tier *)
  let three_fire = { zero_resources with r_fire = 3 } in
  check_eq "3 fire: 3 gems at weight 2 plus 3 per cell"
    (stable_score three_fire 3 0) 15;
  check_eq "a 4-run adds 30" (stable_score three_fire 4 0) 48;
  check_eq "a 5-run adds 30 twice" (stable_score three_fire 5 0) 81;
  check_eq "match_x is added" (stable_score three_fire 3 4) 19;
  check_eq "skulls are weighted 10" (stable_score { zero_resources with r_skull = 3 } 3 0) 39;
  check_eq "red skulls are weighted 20" (stable_score { zero_resources with r_red_skull = 3 } 3 0) 69;
  check_eq "gold is weighted 1" (stable_score { zero_resources with r_gold = 3 } 3 0) 12;
  check_eq "xp is weighted 1" (stable_score { zero_resources with r_xp = 3 } 3 0) 12;
  check_eq "all four mana elements weigh 2"
    (stable_score
       { zero_resources with r_earth = 1; r_fire = 1; r_water = 1; r_air = 1 }
       3 0)
    17;
  (* Weights are configurable: 0x43F8D0 only sets the defaults. *)
  let no_mana = { default_weights with w_fire = 0; w_earth = 0; w_water = 0; w_air = 0 } in
  check_eq "zeroed mana weights leave only the length terms"
    (stable_score ~weights:no_mana three_fire 3 0)
    9

(* ------------------------------------------------------------------ *)
(* Resource accumulation, 0x47B0C0                                     *)
(* ------------------------------------------------------------------ *)

let () =
  let reds =
    board
      [ "........"; "........"; "rrr....."; "........";
        "........"; "........"; "........"; "........" ]
  in
  let mult = ref 1 in
  let res = accumulate zero_resources mult reds 0 2 Horizontal 3 in
  check_eq "each red skull banks 5 damage" res.r_skull 15;
  check_eq "red skulls are also counted separately" res.r_red_skull 3;
  check_eq "no wildcard was involved" !mult 1;
  (* A wildcard multiplies every bucket in the run, per the tail of
     CheckMatch, rather than counting as a gem itself. *)
  let bw =
    board
      [ "........"; "........"; "........"; "ff2....."; "........";
        "........"; "........"; "........" ]
  in
  let mult2 = ref 1 in
  let res2 = accumulate zero_resources mult2 bw 0 3 Horizontal 3 in
  check_eq "the 2x wildcard sets the multiplier to 2" !mult2 2;
  check_eq "2 fire gems doubled to 4" res2.r_fire 4;
  let bw2 =
    board
      [ "........"; "........"; "........"; "23f....."; "........";
        "........"; "........"; "........" ]
  in
  let mult3 = ref 1 in
  let res3 = accumulate zero_resources mult3 bw2 0 3 Horizontal 3 in
  check_eq "a 2x and a 3x wildcard chain to 6" !mult3 6;
  check_eq "the single fire gem is multiplied by 6" res3.r_fire 6

(* ------------------------------------------------------------------ *)
(* Hero level band, 0x43FA7C                                           *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "level 0 sits in the lowest band" (level_jitter_band { level = 0; level_cap = 20 }) 50;
  check_eq "level 1" (level_jitter_band { level = 1; level_cap = 20 }) 40;
  check_eq "level 4" (level_jitter_band { level = 4; level_cap = 20 }) 10;
  (* cap/4 == 5, and the test is a strict <, so level 5 falls through to the
     cap/2 band rather than the cap/4 band. *)
  check_eq "level 5 uses the cap/2 band" (level_jitter_band { level = 5; level_cap = 20 }) 95;
  check_eq "level 7 uses the cap/2 band" (level_jitter_band { level = 7; level_cap = 20 }) 65;
  check_eq "level 9 uses the cap/2 band" (level_jitter_band { level = 9; level_cap = 20 }) 35;
  (* cap*3/4 == 15; level 16 is past the top threshold so the band is 0. *)
  check_eq "level 16 has no band" (level_jitter_band { level = 16; level_cap = 20 }) 0;
  check_eq "level 14 uses the top band" (level_jitter_band { level = 14; level_cap = 20 }) 20;
  check_eq "level 15 sits at the threshold and gets nothing"
    (level_jitter_band { level = 15; level_cap = 20 }) 0;
  check "no hero means no band" (level_jitter_band no_hero = 0)

(* ------------------------------------------------------------------ *)
(* Difficulty jitter, 0x43FA08                                          *)
(* ------------------------------------------------------------------ *)

let () =
  let res = { zero_resources with r_fire = 3 } in
  let at difficulty rng = score_match_result ~rng ~difficulty ~hero:no_hero res 3 0 in
  check_eq "difficulty 0 rolls the full -50..50 band" (at 0 min_rng) (15 - 50);
  check_eq "difficulty 0 at the top of the band" (at 0 max_rng) (15 + 50);
  (* Difficulty 1 draws a 1..100 roll first; below 40 it then draws from
     the -20..20 band. *)
  check_eq "difficulty 1 at the top of its band"
    (at 1 (scripted [ 0; 1000 ])) (15 + 20);
  check_eq "difficulty 1 at the bottom of its band"
    (at 1 (scripted [ 0; 0 ])) (15 - 20);
  check_eq "difficulty 1 skips the band at 40"
    (at 1 (scripted [ 40; 1000 ])) 15;
  check_eq "difficulty 1 skips the band above 40"
    (at 1 (scripted [ 99; 1000 ])) 15;
  check_eq "difficulty 2 never applies the difficulty band" (at 2 (scripted [ 0; 1000 ])) 15;
  (* At difficulty 2 the hero level is ignored too (0x43FA5A jumps out). *)
  let low = { level = 0; level_cap = 20 } in
  check_eq "difficulty 2 ignores the hero level band"
    (score_match_result ~rng:min_rng ~difficulty:2 ~hero:low res 3 0)
    15;
  check_eq "difficulty 1 still applies the hero level band"
    (score_match_result ~rng:(scripted [ 0; 0; 0 ]) ~difficulty:1 ~hero:low res 3 0)
    (15 - 20 - 50)

(* ------------------------------------------------------------------ *)
(* score_swap                                                          *)
(* ------------------------------------------------------------------ *)

let () =
  (* Row 3 is "ffaf....": the air at x=2 blocks the fires at x=0,1, and the
     fire at x=3 can only reach them by swapping with that air. *)
  let b =
    board
      [ "........"; "........"; "........"; "ffaf....";
        "........"; "........"; "........"; "........" ]
  in
  check_eq "no run through (2,3) before the swap" (check_match b 2 3 Horizontal) 1;
  check_eq "no run through (3,3) before the swap" (check_match b 3 3 Horizontal) 1;
  let swapped = swap_gems b { x = 2; y = 3 } { x = 3; y = 3 } in
  check_eq "the swap creates a 3-run" (check_match swapped 2 3 Horizontal) 3;
  (match score_swap ~rng:min_rng ~difficulty:2 swapped 2 3 Horizontal with
  | None -> check "the productive swap scores" false
  | Some c -> check "the productive swap scores positively" (c.cand_score > 0));
  (* Swapping (0,1) touches two empty cells, so nothing matches. *)
  (match score_swap ~rng:min_rng ~difficulty:2 b 0 1 Horizontal with
  | Some _ -> check "a swap of two empty cells does not score" false
  | None -> check "a swap of two empty cells does not score" true);
  (* The mirror-image swap sends the fire away from the pair, so it is dead. *)
  (match score_swap ~rng:min_rng ~difficulty:2 b 1 3 Horizontal with
  | Some _ -> check "the mirror swap that clears the blocker does not score" false
  | None -> check "the mirror swap that clears the blocker does not score" true)

(* ------------------------------------------------------------------ *)
(* evaluate_board                                                      *)
(* ------------------------------------------------------------------ *)

let () =
  let b =
    board
      [ "........"; "........"; "........"; "ffaf....";
        "........"; "........"; "........"; "........" ]
  in
  let e = evaluate_board ~rng:min_rng ~difficulty:2 b in
  check "a board with a match reports a valid move" e.has_valid_move;
  (match e.best with
  | None -> check "a best move is recorded" false
  | Some c ->
      check "the best move is the productive one"
        (c.cand_x = 2 && c.cand_y = 3 && c.cand_direction = Horizontal);
      check "the reported score is the candidate's score" (e.best_score = c.cand_score));
  (* A 4-cycle background has no runs and no productive swap, which is the
     locked-board case the engine signals with m_hasValidMove = false. *)
  let e2 = evaluate_board ~rng:min_rng ~difficulty:2 locked_board in
  check "a 4-cycle board has no legal move" (not e2.has_valid_move);
  check_eq "no move reports the -10000 sentinel" e2.best_score (-10000);
  check "no move has no best candidate" (e2.best = None);
  (* An empty board is trivially locked too. *)
  let blank = board (List.init 8 (fun _ -> "........")) in
  let e3 = evaluate_board ~rng:min_rng ~difficulty:2 blank in
  check "an empty board has no legal move" (not e3.has_valid_move)

let () =
  if !failures = 0 then print_endline "\nAll AI tests passed."
  else begin
    Printf.printf "\n%d AI test(s) failed.\n" !failures;
    exit 1
  end
