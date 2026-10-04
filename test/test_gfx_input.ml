(* What a click means.

   Pure decision-making with no SDL in it, which is the only reason it can be
   tested here at all. The test that matters is the trap: a click outside the
   spell bar has to {e decline the spell}, not re-ask. When the spell prompt was
   the only thing reading clicks, it asked again, the player could never reach the
   swap prompt, and it looked like clicks were not being registered at all. *)

open Pq_gfx

let failures = ref 0

let show = function
  | Input.Cast i -> Printf.sprintf "Cast %d" i
  | Input.Decline -> "Decline"
  | Input.First_cell (x, y) -> Printf.sprintf "First_cell (%d,%d)" x y
  | Input.Swap (a, b, c, d) -> Printf.sprintf "Swap (%d,%d)-(%d,%d)" a b c d
  | Input.No_match -> "No_match"
  | Input.Pass -> "Pass"
  | Input.Miss -> "Miss"

let check_opt name got want =
  let sh = function None -> "None" | Some i -> Printf.sprintf "Some %d" i in
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (sh got) (sh want);
    incr failures
  end

let check_eq name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (show got) (show want);
    incr failures
  end

(* The front end's geometry: four 120px buttons 12px apart in a 900px window, with
   a 96px bar along the bottom. *)
let bar =
  { Input.count = 4; button_w = 120; gap = 12; top_y = 680 - 96; left_x = 186 }

let lay = Layout.create ~cell:64 ~cols:8 ~rows:8 ~window_w:900 ~window_h:680

let always_valid _ _ = true
let never_valid _ _ = false

let spell ?(usable = 3) mx my = Input.in_spell_prompt bar ~usable mx my

let swap ?(first = None) ?(valid = always_valid) mx my =
  Input.in_swap_prompt bar lay ~first ~valid mx my

let () =
  (* --- the spell prompt, which is where the trap was --- *)
  check_eq "a live button casts" (spell 200 620) (Input.Cast 0);
  check_eq "the last live button casts" (spell 450 620) (Input.Cast 2);
  check_eq "button 2 is found at its right edge" (spell 570 620) (Input.Cast 2);
  (* THE regression. Clicking the board while being asked for a spell must decline
     the spell so the turn proceeds to the swap. *)
  check_eq "a board click declines the spell" (spell 450 300) Input.Decline;
  check_eq "an empty part of the bar declines the spell" (spell 20 620)
    Input.Decline;
  check_eq "a button that is not affordable declines too" (spell ~usable:1 700 620)
    Input.Decline;
  check_eq "a click above the bar declines the spell" (spell 450 100)
    Input.Decline;
  check_eq "with nothing affordable every click declines" (spell ~usable:0 450 300)
    Input.Decline;
  (* The buttons themselves are found across their whole width. *)
  check_opt "button 1 is found at its left edge" (Input.bar_button bar 186 600)
    (Some 0);
  check_opt "button 1 is found at its right edge" (Input.bar_button bar 306 600)
    (Some 0);
  check_opt "button 0 is not found past its right edge"
    (Input.bar_button bar 310 600) None;
  check_opt "nothing is found above the bar" (Input.bar_button bar 200 400) None

let () =
  (* --- the swap prompt --- *)
  check_eq "a board click with nothing pending starts a swap" (swap 450 300)
    (Input.First_cell (4, 3));
  check_eq "the second click of an adjacent pair completes the swap"
    (swap ~first:(Some (4, 3)) 546 300)
    (Input.Swap (4, 3, 5, 3));
  check_eq "the pair can be built upwards too"
    (swap ~first:(Some (4, 4)) 450 300)
    (Input.Swap (4, 4, 4, 3));
  check_eq "a diagonal restarts the selection" (swap ~first:(Some (4, 3)) 546 372)
    (Input.First_cell (5, 4));
  check_eq "the same cell twice restarts the selection"
    (swap ~first:(Some (4, 3)) 450 300)
    (Input.First_cell (4, 3));
  check_eq "an adjacent pair that matches no run is rejected"
    (swap ~first:(Some (4, 3)) ~valid:never_valid 546 300)
    Input.No_match;
  (* The same trap in a different window: the bar must let the turn end, or a
     player who cannot find a legal swap is stuck. *)
  check_eq "a bar click during a swap ends the turn" (swap 200 620) Input.Pass;
  check_eq "a click off the board and off the bar is ignored" (swap 5 300)
    Input.Miss;
  (* A pending first cell survives the clicks in between, so two slow clicks
     work. *)
  check_eq "a click far away while a cell is pending starts over"
    (swap ~first:(Some (0, 0)) 450 300)
    (Input.First_cell (4, 3));
  check_eq "a downward neighbour completes the swap"
    (swap ~first:(Some (4, 3)) 450 372)
    (Input.Swap (4, 3, 4, 4))

let () =
  (* The two prompts must not both trap the player. Reading a click sequence the
     way a human would - decline the spell, then swap - has to come out the same
     way through both. *)
  check_eq "declining then swapping: the first click declines"
    (spell 450 300) Input.Decline;
  check_eq "declining then swapping: the next click starts a cell"
    (swap 450 300) (Input.First_cell (4, 3));
  check_eq "declining then swapping: the click after that completes it"
    (swap ~first:(Some (4, 3)) 546 300)
    (Input.Swap (4, 3, 5, 3));
  (* A cast is a cast: the swap prompt is not consulted at all, because the engine
     only asks for one when the spell kept the turn. *)
  check_eq "casting never reaches the swap prompt" (spell 200 620) (Input.Cast 0)

let () =
  if !failures = 0 then print_endline "all gfx input tests passed"
  else begin
    Printf.printf "%d gfx input test(s) failed\n" !failures;
    exit 1
  end