(* The battle screen's geometry.

   Two kinds of number live in Battle_layout and this is where each is pinned:
   the rectangles transcribed from `Assets/Screens/GameMenu.xml` - the character
   pads, their seven spell rows, the life bar, the turn plates, the missed-turn
   badges and the turn line - against the asset's own values, and the two the
   XML has no opinion about (the mana bars and the combat log) against each
   other. A round that moves a rectangle has to move it here first. *)

open Pq_gfx

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

let check_rect name (r : Layout.rect) (x, y, w, h) =
  if r.Layout.x = x && r.Layout.y = y && r.Layout.w = w && r.Layout.h = h then
    Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d,%d %dx%d, want %d,%d %dx%d)\n" name
      r.Layout.x r.Layout.y r.Layout.w r.Layout.h x y w h;
    incr failures
  end

let () =
  (* --- what GameMenu.xml says --- *)
  check_rect "pad_grid is 584 square at (217,130)"
    Battle_layout.pad_grid (217, 130, 584, 584);
  check_int "so the original's cells are 73px" Battle_layout.grid_cell 73;
  check_int "and eight of them fill the pad"
    (Battle_layout.grid_cell * 8) Battle_layout.pad_grid.Layout.w;
  check_rect "pad_gamechar0 is 180x348 at (11,119)"
    (Battle_layout.panel Battle_layout.Hero) (11, 119, 180, 348);
  check_rect "pad_gamechar1 is 180x348 at (835,119)"
    (Battle_layout.panel Battle_layout.Foe) (835, 119, 180, 348);
  (* icon_enemylifepts, the only life bar the XML names: 837,121 175x18. *)
  check_rect "the life bar is icon_enemylifepts, exactly"
    (Battle_layout.life_bar Battle_layout.Foe) (837, 121, 175, 18);
  check_rect "and the hero's is the same shape in its own pad"
    (Battle_layout.life_bar Battle_layout.Hero) (13, 121, 175, 18);
  check_rect "icon_ltimebg sits at (135,16)"
    (Battle_layout.timer_plate Battle_layout.Hero) (135, 16, 90, 90);
  check_rect "icon_rtimebg sits at (784,16)"
    (Battle_layout.timer_plate Battle_layout.Foe) (784, 16, 90, 90);
  check_rect "str_ltime is 90x30 at (132,38)"
    (Battle_layout.timer_text Battle_layout.Hero) (132, 38, 90, 30);
  check_rect "str_rtime is 90x30 at (781,38)"
    (Battle_layout.timer_text Battle_layout.Foe) (781, 38, 90, 30);
  check "the countdown band sits over its plate"
    ((Battle_layout.timer_text Battle_layout.Hero).Layout.y
    >= (Battle_layout.timer_plate Battle_layout.Hero).Layout.y
    && (Battle_layout.timer_text Battle_layout.Hero).Layout.y
       < (Battle_layout.timer_plate Battle_layout.Hero).Layout.y
          + (Battle_layout.timer_plate Battle_layout.Hero).Layout.h);
  check_rect "icon_missturn0 sits at (53,100)"
    (Battle_layout.missed_badge Battle_layout.Hero) (53, 100, 90, 24);
  check_rect "icon_missturn1 sits at (876,100)"
    (Battle_layout.missed_badge Battle_layout.Foe) (876, 100, 90, 24);
  check_rect "str_turn is 124x18 at (450,736)" Battle_layout.turn_rect
    (450, 736, 124, 18);
  check_int "and is centred on the screen"
    (Battle_layout.turn_rect.Layout.x + (Battle_layout.turn_rect.Layout.w / 2))
    (Battle_layout.game_w / 2);
  check_rect "str_battlename is 512x25 at (256,95)"
    Battle_layout.battle_name_rect (256, 95, 512, 25)

let () =
  (* --- the seven spell rows: pad_gamechar0_sp0..sp6 --- *)
  let hero_rows = Battle_layout.spell_rows Battle_layout.Hero in
  let foe_rows = Battle_layout.spell_rows Battle_layout.Foe in
  check_int "there are seven rows" (Array.length hero_rows) 7;
  check_rect "the first row is 178x37 at (11,462)" hero_rows.(0)
    (11, 462, 178, 37);
  check_rect "the seventh row is at (11,708)" hero_rows.(6) (11, 708, 178, 37);
  check_int "the step between rows is 41"
    (hero_rows.(1).Layout.y - hero_rows.(0).Layout.y)
    Battle_layout.spell_row_pitch;
  check "the gutter is 4px, so no two rows touch"
    (hero_rows.(0).Layout.y + hero_rows.(0).Layout.h < hero_rows.(1).Layout.y
    && hero_rows.(5).Layout.y + hero_rows.(5).Layout.h < hero_rows.(6).Layout.y);
  check "the rows are the panel's own column"
    (hero_rows.(0).Layout.x = (Battle_layout.panel Battle_layout.Hero).Layout.x
    && hero_rows.(0).Layout.w <= (Battle_layout.panel Battle_layout.Hero).Layout.w);
  check "and so are the enemy's"
    (foe_rows.(0).Layout.x = (Battle_layout.panel Battle_layout.Foe).Layout.x
    && foe_rows.(6).Layout.y = hero_rows.(6).Layout.y
    && foe_rows.(6).Layout.w = hero_rows.(6).Layout.w);
  check "the last row still fits on the screen"
    (hero_rows.(6).Layout.y + hero_rows.(6).Layout.h <= Battle_layout.game_h)

let () =
  (* --- the mana bars, which the XML has no opinion about: they must sit inside
     the panel and finish where the spell rows begin --- *)
  let hero = Battle_layout.panel Battle_layout.Hero in
  let bars = Battle_layout.mana_bars Battle_layout.Hero in
  check_int "there is one bar per element" (Array.length bars) 4;
  check "every bar is inside its panel"
    (Array.for_all
       (fun (r : Layout.rect) ->
         r.Layout.x >= hero.Layout.x
         && r.Layout.x + r.Layout.w <= hero.Layout.x + hero.Layout.w
         && r.Layout.y >= hero.Layout.y
         && r.Layout.y + r.Layout.h <= hero.Layout.y + hero.Layout.h)
       bars);
  check "and they end just above the first spell row"
    (bars.(3).Layout.y + bars.(3).Layout.h
    = Battle_layout.spell_rows_top - 4);
  check "with a 20px step, so the bars do not touch either"
    (bars.(1).Layout.y - bars.(0).Layout.y = Battle_layout.mana_bar_pitch
    && bars.(0).Layout.y + bars.(0).Layout.h < bars.(1).Layout.y);
  check "and clear of the life bar at the top"
    (bars.(0).Layout.y
    > (Battle_layout.life_bar Battle_layout.Hero).Layout.y
       + (Battle_layout.life_bar Battle_layout.Hero).Layout.h)

let () =
  (* --- the log, derived from the board the front end actually builds --- *)
  let lay =
    Layout.create ~reserve_top:0 ~reserve_bottom:96 ~cell:71 ~cols:8 ~rows:8
      ~window_w:Battle_layout.game_w ~window_h:Battle_layout.game_h
  in
  let board = Layout.board_rect lay in
  let log = Battle_layout.log_rect ~board in
  check "the board is centred between the two panels"
    (board.Layout.x > (Battle_layout.panel Battle_layout.Hero).Layout.x
       + (Battle_layout.panel Battle_layout.Hero).Layout.w
    && board.Layout.x + board.Layout.w < (Battle_layout.panel Battle_layout.Foe).Layout.x);
  check "the log sits under the board"
    (log.Layout.y = board.Layout.y + board.Layout.h + 8);
  check "and runs between the panels, clear of the spell rows"
    (log.Layout.x > (Battle_layout.panel Battle_layout.Hero).Layout.x
       + (Battle_layout.panel Battle_layout.Hero).Layout.w
    && log.Layout.x + log.Layout.w
       < (Battle_layout.panel Battle_layout.Foe).Layout.x);
  check "stopping short of the turn line"
    (log.Layout.y + log.Layout.h < Battle_layout.turn_rect.Layout.y);
  check_int "which leaves six lines of narration"
    (Battle_layout.log_lines log) 6;
  let band = Battle_layout.log_band 96 in
  check_rect "the band behind it is the bottom 96px, full width" band
    (0, 672, 1024, 96);
  check "and reaches the screen's bottom edge"
    (band.Layout.y + band.Layout.h = Battle_layout.game_h)

let () =
  check_int "the other side flips"
    (match Battle_layout.other Battle_layout.Hero with
    | Battle_layout.Foe -> 1
    | Battle_layout.Hero -> 0)
    1;
  if !failures = 0 then print_endline "all battle layout tests passed"
  else begin
    Printf.printf "%d battle layout test(s) failed\n" !failures;
    exit 1
  end
