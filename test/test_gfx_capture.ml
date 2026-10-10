(* The capture window's geometry: CaptureMenu.xml's pad_grid and buttons
   come straight from the shipped screen, so what needs pinning is the
   arithmetic - cell size, the grid's exclusive edges, and the give-up
   button the port added. No context, no display. *)

open Pq_gfx

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let eq_rect (a : Layout.rect) (b : Layout.rect) =
  a.Layout.x = b.Layout.x && a.Layout.y = b.Layout.y
  && a.Layout.w = b.Layout.w && a.Layout.h = b.Layout.h

let () =
  check "the grid is 584 wide at the shipped 8 columns"
    (Capture_layout.cols = 8 && Capture_layout.cell = 73);
  check "cell (0,0) is the pad's top-left"
    (eq_rect (Capture_layout.cell_rect 0 0)
       { Layout.x = 217; y = 130; w = 73; h = 73 });
  check "cell (7,7) lands on the pad's bottom-right"
    (eq_rect (Capture_layout.cell_rect 7 7)
       { Layout.x = 217 + (7 * 73); y = 130 + (7 * 73); w = 73; h = 73 });
  check "the pad's own corners hit cells (0,0) and (7,7)"
    (Capture_layout.hit 217 130 = Capture_layout.Cell (0, 0)
    && Capture_layout.hit 800 713 = Capture_layout.Cell (7, 7));
  check "a click one cell in reads column 1, not column 0"
    (Capture_layout.hit 290 130 = Capture_layout.Cell (1, 0));
  check "the grid's right and bottom edges are exclusive"
    (Capture_layout.hit 801 130 = Capture_layout.Miss
    && Capture_layout.hit 217 714 = Capture_layout.Miss);
  check "a click outside the pad misses"
    (Capture_layout.hit 0 0 = Capture_layout.Miss
    && Capture_layout.hit 100 400 = Capture_layout.Miss
    && Capture_layout.hit 217 129 = Capture_layout.Miss);
  check "the give-up button sits at the pad's top-right"
    (eq_rect Capture_layout.cancel_rect
       { Layout.x = 217 + 584 - 140; y = 90; w = 140; h = 30 });
  check "a click on the give-up button reads Cancel"
    (Capture_layout.hit 700 100 = Capture_layout.Cancel
    && Capture_layout.hit 661 90 = Capture_layout.Cancel);
  check "the button's edges are exclusive too"
    (Capture_layout.hit 801 100 = Capture_layout.Miss
    && Capture_layout.hit 700 120 = Capture_layout.Miss);
  if !failures = 0 then print_endline "all capture layout tests passed"
  else begin
    Printf.printf "%d capture layout test(s) failed\n" !failures;
    exit 1
  end
