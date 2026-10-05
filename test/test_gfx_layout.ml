(* Board geometry, and nothing else.

   [Pq_gfx.Layout] is the one piece of the graphics front that is pure arithmetic,
   and that is deliberate: cell positions and click hit-testing are exactly the
   things that are easy to get subtly wrong and annoying to debug through a
   window. These tests need no context and no display. *)

open Pq_gfx
open Puzzle_quest_lib

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
    Printf.printf "FAIL - %s (got %s, want %s)\n" name got want;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let check_opt name got want =
  let sh = function
    | None -> "None"
    | Some (a, b) -> Printf.sprintf "Some (%d,%d)" a b
  in
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (sh got) (sh want);
    incr failures
  end

let check_pair name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    let sh (a, b) = Printf.sprintf "(%d,%d)" a b in
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (sh got) (sh want);
    incr failures
  end

let show_rect r =
  Printf.sprintf "(%d,%d %dx%d)" r.Layout.x r.Layout.y r.Layout.w r.Layout.h

(* 8x8 at 64px in a 900x680 window: the board is 512 square, so it is centred
   with 194 left over on each side horizontally and 84 vertically. *)
let lay = Layout.create ~reserve_top:0 ~reserve_bottom:0 ~cell:64 ~cols:8 ~rows:8 ~window_w:900 ~window_h:680

let () =
  (* The window size is the one the art is drawn for, and the art is the evidence:
     the backdrop frame is 1024x768 and the four border frames tile it exactly (see
     test_skin_data). Asserted here because this is where the constant lives, so a
     change to it cannot drift away from the decoration without a failure. *)
  check_int "the window is the backdrop's width" Layout.game_screen_w
    (Option.get (Skin_data.frame_of_tag "img_backdrop")).Skin_data.dest_w;
  check_int "and its height"
    (Option.get (Skin_data.frame_of_tag "img_backdrop")).Skin_data.dest_h
    Layout.game_screen_h;
  (* The top inset the board is placed below is read from the border frame rather
     than typed, so the art and the layout cannot disagree. *)
  check_int "the top inset is the top border's height" (Skin.top_inset ())
    (Option.get (Skin_data.frame_of_tag "img_border_top")).Skin_data.h;
  check_int "which is also the top panel's" (Skin.top_inset ())
    (Option.get (Skin_data.frame_of_tag "img_toppanel")).Skin_data.h

let () =
  (* Docked furniture. The board centres in what is left after the top panel and
     the bar, rather than being centred in the window and half-hidden under them -
     which is what it did before [reserve_top] existed. *)
  let screen = Layout.game_screen_w and bar = 96 in
  let inset = Skin.top_inset () in
  let docked = Layout.create ~reserve_top:inset ~reserve_bottom:bar ~cell:71
      ~cols:8 ~rows:8 ~window_w:screen ~window_h:Layout.game_screen_h
  in
  check_int "the board starts below the top panel" docked.Layout.origin_y
    (inset + 4);
  check "and ends above the bar"
    (docked.Layout.origin_y + (8 * 71) <= Layout.game_screen_h - bar);
  (* The vertical centring is within the free space, not the window: had it been
     centred in the window it would land 48px higher, under the panel. *)
  check "which is not where an undocked board would be"
    (docked.Layout.origin_y
    <> (Layout.create ~reserve_top:0 ~reserve_bottom:0 ~cell:71 ~cols:8 ~rows:8
          ~window_w:screen ~window_h:Layout.game_screen_h)
       .Layout.origin_y);
  (* A board too tall for the free space must not produce a negative origin, or the
     top row renders off-screen with no indication why. *)
  let too_tall =
    Layout.create ~reserve_top:inset ~reserve_bottom:bar ~cell:200 ~cols:8 ~rows:8
      ~window_w:screen ~window_h:Layout.game_screen_h
  in
  check "an oversized board still starts at the inset, not above it"
    (too_tall.Layout.origin_y >= inset);
  check_int "and starts exactly at it" too_tall.Layout.origin_y inset

let () =
  check_int "origin centres the board horizontally" lay.Layout.origin_x 194;
  check_int "origin centres the board vertically" lay.Layout.origin_y 84;
  check_eq "board rect covers every cell" (show_rect (Layout.board_rect lay))
    "(194,84 512x512)";
  check_eq "cell (0,0) is the top-left" (show_rect (Layout.cell_rect lay 0 0))
    "(194,84 64x64)";
  check_eq "cell (7,7) is the bottom-right" (show_rect (Layout.cell_rect lay 7 7))
    "(642,532 64x64)";
  (* Row-major, so x is the fast axis. This is the transposition that has bitten
     the port in mana, status effects and the AI, and it is worth pinning. *)
  check_eq "cell (1,0) is one step right" (show_rect (Layout.cell_rect lay 1 0))
    "(258,84 64x64)";
  check_eq "cell (0,1) is one step down" (show_rect (Layout.cell_rect lay 0 1))
    "(194,148 64x64)"

let () =
  (* Hit testing. The centre of each cell must come back as that cell, and the
     boundary belongs to the cell on the low side. *)
  List.iter
    (fun (x, y) ->
      check_pair
        (Printf.sprintf "hit at the centre of cell (%d,%d)" x y)
        (match Layout.hit lay (194 + (x * 64) + 32) (84 + (y * 64) + 32) with
        | Some c -> c
        | None -> (-1, -1))
        (x, y))
    [ (0, 0); (7, 0); (0, 7); (7, 7); (3, 4); (1, 6) ];
  check_opt "the top-left pixel of the board is cell (0,0)" (Layout.hit lay 194 84) (Some (0, 0));
  check_opt "the last pixel of the board is cell (7,7)" (Layout.hit lay 705 595) (Some (7, 7));
  (* The right edge, taken at the vertical centre of the bottom row. *)
  check_opt "the rightmost edge still belongs to cell (7,7)"
    (Layout.hit lay 705 (84 + (7 * 64) + 32))
    (Some (7, 7))

let () =
  (* A miss must miss. Clamping would hand back column 0 and turn a click beside
     the board into a real move, which is the worst possible failure for an input
     path. *)
  check_opt "left of the board misses" (Layout.hit lay 193 300) None;
  check_opt "above the board misses" (Layout.hit lay 300 83) None;
  check_opt "below the board misses" (Layout.hit lay 300 596) None;
  check_opt "right of the board misses" (Layout.hit lay 706 300) None;
  check_opt "negative coordinates miss" (Layout.hit lay (-5) (-5)) None;
  check_opt "far off-window misses" (Layout.hit lay 5000 5000) None

let () =
  check "in_bounds rejects x = -1" (not (Layout.in_bounds lay (-1) 0));
  check "in_bounds rejects x = 8" (not (Layout.in_bounds lay 8 0));
  check "in_bounds accepts (7,7)" (Layout.in_bounds lay 7 7)

let () =
  (* Every gem kind must map to a colour, or an unhandled kind renders as nothing
     and the board silently loses a piece. *)
  let all =
    [ Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Water;
      Board.Mana Board.Air; Board.Skull; Board.RedSkull; Board.Gold;
      Board.Experience; Board.Wildcard 2; Board.Wildcard 8; Board.Empty ]
  in
  check "gem_colour is total over every gem kind"
    (List.for_all (fun g -> (Layout.gem_colour g).Layout.a = 255) all);
  check "every gem kind has a label"
    (List.for_all (fun g -> Layout.gem_letter g <> "") all);
  (* The four mana elements must be four distinct colours, or the board is
     unreadable - which is the whole point of the placeholder. *)
  let elements =
    List.map Layout.gem_colour
      [ Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Water;
        Board.Mana Board.Air ]
  in
  check "the four elements are all different colours"
    (let rec all_different = function
      | [] -> true
      | [ _ ] -> true
      | c :: tl -> List.for_all (fun d -> d <> c) tl && all_different tl
    in
     all_different elements);
  (* A 2x wildcard is tinted towards earth and an 8x towards air, so the hue keeps
     meaning instead of inventing a fifth colour. *)
  let w2 = Layout.gem_colour (Board.Wildcard 2) in
  let w8 = Layout.gem_colour (Board.Wildcard 8) in
  check "a 2x wildcard leans green like earth"
    (w2.Layout.g > w2.Layout.b);
  check "an 8x wildcard leans yellow like air"
    (w8.Layout.r > w8.Layout.b && w8.Layout.g > w8.Layout.b)

let () =
  check "a non-positive cell size is rejected"
    (try
       ignore (Layout.create ~reserve_top:0 ~reserve_bottom:0 ~cell:0 ~cols:8 ~rows:8 ~window_w:100 ~window_h:100);
       false
     with Invalid_argument _ -> true);
  check "a non-positive column count is rejected"
    (try
       ignore (Layout.create ~reserve_top:0 ~reserve_bottom:0 ~cell:8 ~cols:0 ~rows:8 ~window_w:100 ~window_h:100);
       false
     with Invalid_argument _ -> true)

let () =
  if !failures = 0 then print_endline "all gfx layout tests passed"
  else begin
    Printf.printf "%d gfx layout test(s) failed\n" !failures;
    exit 1
  end