(* The shared seeded generator.

   This module exists because of a specific bug: the tools each had their own LCG
   and drew from its low bits, where `state mod 4` has period exactly four. Boards
   came out as vertical stripes - every row the same four-colour pattern - and
   because it produced a plausible-looking board rather than a crash, nothing
   caught it until someone looked at the screen.

   So the tests here are about {e variety}, not about matching a reference
   sequence. A generator that returns the right values in the wrong pattern is
   still wrong, and that is precisely what a value-by-value test misses. *)

open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let draw_seq seed n range =
  let g = Rng.create seed in
  List.init n (fun _ -> Rng.int g range)

let () =
  (* The contract with Random.int. *)
  let g = Rng.create 1 in
  check "0 .. n-1 for n = 4"
    (List.for_all (fun v -> v >= 0 && v < 4) (List.init 200 (fun _ -> Rng.int g 4)));
  let g = Rng.create 1 in
  check "0 .. n-1 for n = 8"
    (List.for_all (fun v -> v >= 0 && v < 8) (List.init 200 (fun _ -> Rng.int g 8)));
  let g = Rng.create 1 in
  check "n = 1 always gives 0" (List.for_all (( = ) 0) (List.init 20 (fun _ -> Rng.int g 1)));
  let g = Rng.create 1 in
  check "n = 0 does not crash" (Rng.int g 0 = 0);
  (* A non-power-of-two range, since the board uses 4 but rosters and gem seeding
     use 8 and 6. *)
  let g = Rng.create 1 in
  check "0 .. n-1 for n = 6"
    (List.for_all (fun v -> v >= 0 && v < 6) (List.init 200 (fun _ -> Rng.int g 6)));
  let g = Rng.create 1 in
  check "float stays in 0 .. 1"
    (List.for_all (fun _ -> let f = Rng.float g in f >= 0.0 && f < 1.0)
       (List.init 200 (fun _ -> ())))

let () =
  (* The bug itself: period four in the low bits. If this ever regresses, boards
     go striped again. *)
  let seq4 = draw_seq 7 64 4 in
  let distinct4 = List.sort_uniq compare seq4 in
  check "four-valued draws use all four values"
    (List.length distinct4 = 4);
  let arr = Array.of_list seq4 in
  let period4 = ref true in
  for i = 0 to Array.length arr - 1 do
    if arr.(i) <> arr.(i mod 4) then period4 := false
  done;
  check "four-valued draws do not have period 4" (not !period4);
  (* A 64-cell board row must not be the same four values repeated sixteen
     times, which is exactly what a period-four generator produces. *)
  let row = Array.of_list (draw_seq 7 64 4) in
  let striped =
    let ok = ref true in
    for i = 0 to Array.length row - 1 do
      if row.(i) <> row.(i mod 4) then ok := false
    done;
    !ok
  in
  check "a 64-draw row is not a four-cycle repeated" (not striped)

let () =
  (* Variety across seeds and across ranges. *)
  let seq8 = draw_seq 3 128 8 in
  check "eight-valued draws use all eight"
    (List.length (List.sort_uniq compare seq8) = 8);
  let seq3 = draw_seq 5 128 3 in
  check "three-valued draws use all three"
    (List.length (List.sort_uniq compare seq3) = 3);
  (* A board: 64 draws in 0..3 should be roughly balanced. A period-four generator
     is exactly balanced, which is itself the tell - real randomness wobbles. *)
  let counts = Array.make 4 0 in
  List.iter (fun v -> counts.(v) <- counts.(v) + 1) (draw_seq 11 64 4);
  let all_equal = Array.for_all (fun c -> c = 16) counts in
  check "a 64-draw four-way split is not perfectly uniform (that means period 4)"
    (not all_equal);
  (* Different seeds must give different sequences. *)
  check "seed 1 and seed 2 differ"
    (draw_seq 1 64 4 <> draw_seq 2 64 4);
  (* Reproducibility is the point of a seeded generator, so pin it. *)
  check "the same seed reproduces the same sequence"
    (draw_seq 42 128 8 = draw_seq 42 128 8)

let () =
  (* A generated board must not be row-periodic - the symptom that was reported.
     Four rows that each start with the same element is a striped board. *)
  let g = Rng.create 7 in
  let row _ =
    List.init Board.default_width (fun _ -> Rng.int g 4)
  in
  let rows = List.init 4 (fun _ -> row ()) in
  let heads = List.map List.hd rows in
  check "four board rows do not all start with the same element"
    (List.length (List.sort_uniq compare heads) > 1);
  (* Rng.list is what a tool fills a board with, so check that too. *)
  let g = Rng.create 7 in
  let vals = Rng.list g ~length:64 ~range:4 in
  check "Rng.list returns the requested length" (List.length vals = 64);
  check "Rng.list stays in range"
    (List.for_all (fun v -> v >= 0 && v < 4) vals)

let () =
  if !failures = 0 then print_endline "all rng tests passed"
  else begin
    Printf.printf "%d rng test(s) failed\n" !failures;
    exit 1
  end