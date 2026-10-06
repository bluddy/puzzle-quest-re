(* Turning a board step into somewhere to draw a gem.

   The load-bearing function here is [Anim.fall_pairs], because it decides which
   gem in one board is which gem in the next. Get it wrong and text looks fine,
   tests pass, and a gem visibly teleports mid-cascade - so it is tested against
   boards built by hand rather than against a battle. *)

open Pq_gfx
open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let e = Board.Mana Board.Earth
let f = Board.Mana Board.Fire
let a = Board.Mana Board.Air
let w = Board.Mana Board.Water

(** A board from rows of gems, top row first. [Empty] for a gap.

    The size comes from the array rather than the 8x8 default, so a fixture can be
    two columns wide and still mean something. *)
let board_of rows =
  let height = List.length rows in
  let width = List.length (List.hd rows) in
  Board.of_array_matrix ~width ~height
    (Array.of_list (List.map (fun row -> Array.of_list row) rows))

(* ------------------------------------------------------------ the matcher -- *)

let test_nothing_moves () =
  let b = board_of [ [ e; f ]; [ a; w ] ] in
  let pairs, entrants = Anim.fall_pairs ~cleared:b ~after:b in
  check_int "an unchanged board moves nothing" (List.length pairs) 0;
  check_int "and gains nothing" (List.length entrants) 0

let test_every_gem_is_accounted_for () =
  (* The invariant that matters: every gem in [after] is a fall, an entrant, or
     stationary in [cleared] as well. Anything else is a gem that would go missing
     from the frame.

     The boards are columns on purpose. A "column" here is one x, and the fixtures
     have to be taller than they are wide for there to be anything to fall.

     The gap is at the *top*, so the column grows rather than shifts: the new gem
     lands on row 0 and everything else stays put. *)
  let cleared = board_of [ [ Empty ]; [ e ]; [ f ] ] in
  let after = board_of [ [ a ]; [ e ]; [ f ] ] in
  let pairs, entrants = Anim.fall_pairs ~cleared ~after in
  check_int "nothing fell" (List.length pairs) 0;
  check_int "and one gem arrived" (List.length entrants) 1;
  (match entrants with
  | [ fl ] ->
      check "the arrival is the new gem" (fl.Anim.gem = a);
      check_int "landing on row 0" fl.Anim.to_y 0;
      check_int "having entered from above the board" fl.Anim.from_y (-1)
  | _ -> check "there is exactly one entrant" false)

let test_a_gem_falls_to_its_new_row () =
  (* A gap at the bottom of a column: gravity pulls both remaining gems down one
     row. Top-down the column reads [earth, fire, empty], so bottom-up the gems are
     fire at row 1 and earth at row 0; afterwards they are fire at row 2 and earth
     at row 1. *)
  let cleared = board_of [ [ e ]; [ f ]; [ Empty ] ] in
  let after = board_of [ [ Empty ]; [ e ]; [ f ] ] in
  let pairs, entrants = Anim.fall_pairs ~cleared ~after in
  check_int "two gems fell" (List.length pairs) 2;
  check_int "and none arrived" (List.length entrants) 0;
  let of_gem g = List.find_opt (fun (fl : Anim.fall) -> fl.Anim.gem = g) pairs in
  (match of_gem f with
  | Some fl ->
      check_int "fire fell from row 1" fl.Anim.from_y 1;
      check_int "to row 2" fl.Anim.to_y 2
  | None -> check "fire is among the falls" false);
  (match of_gem e with
  | Some fl ->
      check_int "earth fell from row 0" fl.Anim.from_y 0;
      check_int "to row 1" fl.Anim.to_y 1
  | None -> check "earth is among the falls" false);
  List.iter
    (fun (fl : Anim.fall) ->
      check "and no gem moves upwards" (fl.Anim.to_y > fl.Anim.from_y))
    pairs

let test_enters_from_above_the_board () =
  (* A brand new gem must drop *in* from off the top, not appear at its final row.
     So its start is above row 0 - which is what makes the top of the board read as
     a ceiling rather than as a gap. *)
  let cleared = board_of [ [ e ]; [ f ]; [ Empty ] ] in
  let after = board_of [ [ a ]; [ e ]; [ f ] ] in
  let pairs, entrants = Anim.fall_pairs ~cleared ~after in
  check_int "two gems fell" (List.length pairs) 2;
  check_int "and one arrived" (List.length entrants) 1;
  List.iter
    (fun (fl : Anim.fall) ->
      check "an entrant starts above the board" (fl.Anim.from_y < 0);
      check "and lands on the board" (fl.Anim.to_y >= 0))
    entrants;
  match entrants with
  | [ fl ] -> check "the entrant is the new gem" (fl.Anim.gem = a)
  | _ -> check "there is exactly one entrant" false

let test_order_is_preserved_within_a_column () =
  (* Gravity preserves order, so a column's gems pair off bottom-up in sequence.
     Checking every destination in the column rather than one gem is what proves
     the pairing is positional and not accidental. *)
  let cleared = board_of [ [ e ]; [ f ]; [ a ]; [ Empty ] ] in
  let after = board_of [ [ Empty ]; [ e ]; [ f ]; [ a ] ] in
  let pairs, _ = Anim.fall_pairs ~cleared ~after in
  check_int "three gems fell" (List.length pairs) 3;
  let dests = List.map (fun (fl : Anim.fall) -> fl.Anim.to_y) pairs in
  check "each lands one row below where it started"
    (List.sort compare dests = [ 1; 2; 3 ]);
  List.iter
    (fun (fl : Anim.fall) -> check "and none moves up" (fl.Anim.to_y > fl.Anim.from_y))
    pairs

let test_an_untouched_column_contributes_nothing () =
  (* Two columns, a gap in only one. The untouched column must not appear in the
     fall list at all - if it did, the renderer would draw it twice. *)
  let cleared = board_of [ [ e; w ]; [ f; e ]; [ Empty; f ] ] in
  let after = board_of [ [ Empty; w ]; [ e; e ]; [ f; f ] ] in
  let pairs, _ = Anim.fall_pairs ~cleared ~after in
  check "only column 0 contributes" (List.for_all (fun (fl : Anim.fall) -> fl.Anim.x = 0) pairs);
  check_int "and it contributes both of its movers" (List.length pairs) 2

(* -------------------------------------------------------------- the queue -- *)

let test_the_column_order_is_bottom_up () =
  (* The pairing walks each column bottom-up, and getting that backwards is silent:
     it still pairs every gem with something, it just pairs the wrong gems - the
     topmost survivor with the newcomer instead of the bottom one. So the order is
     pinned here rather than left to a comment.

     A column with a gap at the top and a newcomer is the case that tells the two
     orders apart. *)
  let cleared = board_of [ [ Empty ]; [ e ]; [ f ] ] in
  let after = board_of [ [ a ]; [ e ]; [ f ] ] in
  let _, entrants = Anim.fall_pairs ~cleared ~after in
  (match entrants with
  | [ fl ] -> check "the newcomer is the air gem, not a survivor" (fl.Anim.gem = a)
  | _ -> check "there is exactly one entrant" false);
  (* And a column that only shifts: the gems keep their relative order, so a
     top-down pairing would still look right here - which is why the case above is
     the one that matters. *)
  let shifted_cleared = board_of [ [ e ]; [ f ]; [ Empty ] ] in
  let shifted_after = board_of [ [ Empty ]; [ e ]; [ f ] ] in
  let pairs, _ = Anim.fall_pairs ~cleared:shifted_cleared ~after:shifted_after in
  check "a pure shift pairs each gem with itself"
    (List.for_all
       (fun (fl : Anim.fall) -> fl.Anim.to_y = fl.Anim.from_y + 1)
       pairs)

let test_queue_runs_phases_in_order () =
  let t = Anim.create () in
  check "a new animation is not busy" (not (Anim.is_busy t));
  let b = board_of [ [ e; f ]; [ a; w ] ] in
  Anim.push_step t (Battle.Cascaded { step = 1; before = b; cleared = b; after = b; runs = [] });
  check "a cascade makes it busy" (Anim.is_busy t);
  (* Pop then fall, and the fall must not start until the pop is done. *)
  check "the first phase is the pop" (match Anim.progress t with
      | Some (Anim.Popping _, _) -> true
      | _ -> false);
  let dt = Anim.pop_seconds +. 0.001 in
  ignore (Anim.advance t dt);
  check "after the pop, the fall is current" (match Anim.progress t with
      | Some (Anim.Falling _, _) -> true
      | _ -> false);
  ignore (Anim.advance t (Anim.fall_seconds +. 0.001));
  check "and then it is finished" (not (Anim.is_busy t))

let test_a_swap_is_one_phase () =
  let t = Anim.create () in
  let before = board_of [ [ e; f ]; [ a; w ] ] in
  let after = board_of [ [ f; e ]; [ a; w ] ] in
  Anim.push_step t
    (Battle.Swapped { before; after; a = { Board.x = 0; y = 0 }; b = { Board.x = 1; y = 0 } });
  check "a swap slides" (match Anim.progress t with Some (Anim.Sliding _, _) -> true | _ -> false);
  ignore (Anim.advance t (Anim.slide_seconds +. 0.001));
  check "and is finished in one phase" (not (Anim.is_busy t))

let test_slide_crosses_at_the_midpoint () =
  (* At the halfway point the two gems are on the same square: they have each
     travelled half the distance, which is what "crossing" means. At the end they
     have swapped. Both axes are checked, because a horizontal swap that
     interpolated y instead would look like nothing happening. *)
  let horiz_a = { Board.x = 2; y = 3 } and horiz_b = { Board.x = 5; y = 3 } in
  let mid_a, mid_b = Anim.slide_pos horiz_a horiz_b 0.5 in
  check_int "a horizontal swap crosses" mid_a.Board.x mid_b.Board.x;
  check "and holds its row" (mid_a.Board.y = horiz_a.Board.y && mid_b.Board.y = horiz_b.Board.y);
  let end_a, end_b = Anim.slide_pos horiz_a horiz_b 1.0 in
  check "at the end they have swapped"
    (end_a.Board.x = horiz_b.Board.x && end_b.Board.x = horiz_a.Board.x);
  (* And the same the other way up. *)
  let vert_a = { Board.x = 2; y = 1 } and vert_b = { Board.x = 2; y = 6 } in
  let vmid_a, vmid_b = Anim.slide_pos vert_a vert_b 0.5 in
  check "a vertical swap crosses too" (vmid_a.Board.y = vmid_b.Board.y);
  check "and holds its column"
    (vmid_a.Board.x = vert_a.Board.x && vmid_b.Board.x = vert_b.Board.x);
  let vend_a, _ = Anim.slide_pos vert_a vert_b 1.0 in
  check_int "arriving at the far end" vend_a.Board.y vert_b.Board.y;
  (* At the start nothing has moved, and progress past one is clamped. *)
  let start_a, _ = Anim.slide_pos horiz_a horiz_b 0.0 in
  check "and it starts where it was"
    (start_a.Board.x = horiz_a.Board.x && start_a.Board.y = horiz_a.Board.y);
  let over_a, over_b = Anim.slide_pos horiz_a horiz_b 5.0 in
  check "progress past one is clamped"
    (over_a.Board.x = horiz_b.Board.x && over_b.Board.x = horiz_a.Board.x)

let test_pop_shrinks_to_nothing () =
  check "a popping gem starts at full size" (Anim.pop_scale 0.0 = 1.0);
  check "and ends at nothing" (Anim.pop_scale 1.0 = 0.0);
  check "it is opaque at the start" (Anim.pop_alpha 0.0 = 255);
  check "and gone at the end" (Anim.pop_alpha 1.0 = 0);
  check "the scale never goes negative" (Anim.pop_scale 0.9 >= 0.0)

let test_matched_cells_are_deduplicated () =
  (* A Red Skull explosion can pull a gem into a run it was not matched with, so
     the same cell can be named twice. Drawing it twice is harmless; counting it
     twice is not. *)
  let p1 = { Board.x = 1; y = 1 } and p2 = { Board.x = 1; y = 1 } in
  let p3 = { Board.x = 2; y = 1 } in
  let runs = [ ([ p1; p3 ], e); ([ p2 ], f) ] in
  check_int "the same cell twice is one cell" (List.length (Anim.matched_cells runs)) 2

let test_only_the_matched_gems_fade () =
  (* The fade belongs to the matched gems, not to the frame. Carrying one alpha for
     the whole board would dim everything at once, which reads as the board flashing
     rather than as the matched three bursting - so the stationary gems' alpha is
     pinned here, not just [pop_alpha]'s curve. *)
  let t = Anim.create () in
  let b = board_of [ [ e; f ]; [ a; w ] ] in
  Anim.push_step t
    (Battle.Cascaded
       { step = 1; before = b; cleared = b; after = b;
         runs = [ ([ { Board.x = 0; y = 0 } ], e) ] });
  ignore (Anim.advance t (Anim.pop_seconds /. 2.0));
  let frame = Anim.frame t in
  check_int "the whole board is still drawn" (List.length frame) 4;
  let alpha_of g = List.find_opt (fun (pl : Anim.placed_gem) -> pl.Anim.gem = g) frame in
  (match alpha_of e with
  | Some pl ->
      check "the matched gem has begun to fade" (pl.Anim.alpha < 255);
      check "and to shrink" (pl.Anim.w < 1.0)
  | None -> check "the matched gem is drawn" false);
  (match alpha_of w with
  | Some pl ->
      check "a gem that did not match is untouched" (pl.Anim.alpha = 255);
      check "and has not shrunk" (pl.Anim.w = 1.0)
  | None -> check "a stationary gem is drawn" false)

let test_a_falling_frame_is_opaque () =
  (* No fade on the fall: a gem that arrived while fading up would look like it
     materialised instead of landing. *)
  let t = Anim.create () in
  let cleared = board_of [ [ Empty; e ]; [ Empty; f ]; [ Empty; Empty ] ] in
  let after = board_of [ [ a; e ]; [ e; f ]; [ f; w ] ] in
  Anim.push_step t
    (Battle.Cascaded { step = 1; before = cleared; cleared; after; runs = [] });
  ignore (Anim.advance t (Anim.pop_seconds +. (Anim.fall_seconds /. 2.0)));
  let frame = Anim.frame t in
  check "there is a frame to draw" (frame <> []);
  check "and every gem in it is opaque"
    (List.for_all (fun (pl : Anim.placed_gem) -> pl.Anim.alpha = 255) frame)

let () =
  test_nothing_moves ();
  test_every_gem_is_accounted_for ();
  test_a_gem_falls_to_its_new_row ();
  test_enters_from_above_the_board ();
  test_order_is_preserved_within_a_column ();
  test_an_untouched_column_contributes_nothing ();
  test_the_column_order_is_bottom_up ();
  test_queue_runs_phases_in_order ();
  test_a_swap_is_one_phase ();
  test_slide_crosses_at_the_midpoint ();
  test_pop_shrinks_to_nothing ();
  test_only_the_matched_gems_fade ();
  test_a_falling_frame_is_opaque ();
  test_matched_cells_are_deduplicated ();
  if !failures = 0 then print_endline "all animation tests passed"
  else begin
    Printf.printf "%d animation test(s) failed\n" !failures;
    exit 1
  end