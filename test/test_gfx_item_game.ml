(* The forge skill game's window geometry: ItemGameMenu.xml's pad_grid and
   meter come straight from the shipped screen, so what needs pinning is the
   arithmetic - cell size, the grid's exclusive edges, and the 21-icon
   target meter stepping 44 both ways from (851,359). No context, no
   display. *)

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
  check "the grid is 584 wide at the shipped 8 columns - the capture pad"
    (Item_game_layout.cols = 8 && Item_game_layout.cell = 73
    && Item_game_layout.grid_x = 217 && Item_game_layout.grid_y = 130
    && Item_game_layout.grid_size = 584);
  check "cell (0,0) is the pad's top-left"
    (eq_rect (Item_game_layout.cell_rect 0 0)
       { Layout.x = 217; y = 130; w = 73; h = 73 });
  check "cell (7,7) lands on the pad's bottom-right"
    (eq_rect (Item_game_layout.cell_rect 7 7)
       { Layout.x = 217 + (7 * 73); y = 130 + (7 * 73); w = 73; h = 73 });
  check "the pad's own corners hit cells (0,0) and (7,7)"
    (Item_game_layout.hit 217 130 = `Cell (0, 0)
    && Item_game_layout.hit 800 713 = `Cell (7, 7));
  check "a click one cell in reads column 1, not column 0"
    (Item_game_layout.hit 290 130 = `Cell (1, 0));
  check "the grid's right and bottom edges are exclusive"
    (Item_game_layout.hit 801 130 = `Miss
    && Item_game_layout.hit 217 714 = `Miss);
  check "a click outside the pad misses"
    (Item_game_layout.hit 0 0 = `Miss && Item_game_layout.hit 100 400 = `Miss);
  check "the title is the shipped [ITEMGAME] band, centred on the screen"
    (Item_game_layout.title_cx = 512 && Item_game_layout.title_y = 95);
  check "the help line runs along the shipped y=733"
    (Item_game_layout.help_y = 733 && Item_game_layout.screen_w = 1024);
  check "the hero's name sits in the left column at y=148"
    (Item_game_layout.hero_name_cx = 48 + (133 / 2)
    && Item_game_layout.hero_name_y = 148);
  check "the item's name and power text fill the right column"
    (eq_rect Item_game_layout.item_name_rect
       { Layout.x = 849; y = 145; w = 130; h = 45 }
    && eq_rect Item_game_layout.item_desc_rect
         { Layout.x = 849; y = 192; w = 130; h = 120 });
  check "the rules panel takes the shipped 128x395 at (50,324)"
    (eq_rect Item_game_layout.rules_rect
       { Layout.x = 50; y = 324; w = 128; h = 395 });
  check "the POINTS label sits over the meter at (847,323)"
    (Item_game_layout.targets_cx = 847 + (134 / 2)
    && Item_game_layout.targets_y = 323);
  (* The meter: 21 icons, three across, stepping 44 from (851,359). *)
  check "the meter is the shipped 21 icons"
    (Item_game_layout.meter_count = 21);
  check "icon 0 is the top-left of the meter"
    (eq_rect (Item_game_layout.meter_rect 0)
       { Layout.x = 851; y = 359; w = 40; h = 40 });
  check "the first row steps 44 across"
    (eq_rect (Item_game_layout.meter_rect 1)
       { Layout.x = 895; y = 359; w = 40; h = 40 }
    && eq_rect (Item_game_layout.meter_rect 2)
         { Layout.x = 939; y = 359; w = 40; h = 40 });
  check "the second row steps 44 down"
    (eq_rect (Item_game_layout.meter_rect 3)
       { Layout.x = 851; y = 403; w = 40; h = 40 });
  check "the last icon is the meter's bottom-right"
    (eq_rect (Item_game_layout.meter_rect 20)
       { Layout.x = 939; y = 623; w = 40; h = 40 });
  check "the meter index clamps rather than reading past the end"
    (eq_rect (Item_game_layout.meter_rect 21)
       (Item_game_layout.meter_rect 20)
    && eq_rect (Item_game_layout.meter_rect (-1))
         (Item_game_layout.meter_rect 0));
  if !failures = 0 then print_endline "all item game layout tests passed"
  else begin
    Printf.printf "%d item game layout test(s) failed\n" !failures;
    exit 1
  end
