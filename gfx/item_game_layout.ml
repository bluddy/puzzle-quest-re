(* The forge skill game's window geometry, read from the shipped
   ItemGameMenu.xml - capture's grid, a 21-icon target meter, and the three
   text bands the screen declares:

     pad_grid      (217,130) 584x584        the capture grid's own numbers
     str_capture   (256,95)  w512 h25       [ITEMGAME] "Forge an Item"
     str_help      (0,733)   w1024 h18      [ITEMGAME_HELP]
     str_name0     (48,148)  w133 h20       the hero's name, centred
     icon_char0    (50,175)  128x128        the hero's portrait
     str_name1     (849,145) w130 h45       the item being forged
     str_desc1     (849,192) w130 h120      its power text
     icon_rules    (50,324)  128x395        English/Rules_ItemGame.png
     str_targets   (847,323) w134 h24       [ITEMGAME_TARGET] "POINTS"
     icon_point0   (851,359) 40x40          the meter, 3 across stepping 44
                                            in 7 rows stepping 44 - 21 icons
     icon_grid     (212,45)  600x680        the frame behind the grid

   The meter icons all ship img_hammanv_off; the game flips the first [score]
   to img_hammanv_on at runtime, which is what makes it a progress meter over
   the target [Item_game.target_for_band] asks for. *)

let screen_w = Layout.game_screen_w
let screen_h = Layout.game_screen_h

let grid_x = 217
let grid_y = 130
let grid_size = 584
let cols = 8
let cell = grid_size / cols  (* 73 - capture's own cell *)

(* The title and help bands are centred strings; the box the XML gives is the
   placement, and the centre is what a draw wants. *)
let title_cx = 256 + (512 / 2)
let title_y = 95
let help_y = 733

let hero_name_cx = 48 + (133 / 2)
let hero_name_y = 148
let portrait_rect : Layout.rect = { x = 50; y = 175; w = 128; h = 128 }

let item_name_rect : Layout.rect = { x = 849; y = 145; w = 130; h = 45 }
let item_desc_rect : Layout.rect = { x = 849; y = 192; w = 130; h = 120 }

(* Rules_ItemGame.png is 128x512 and the screen gives it 128x395 - the XML's
   own box, squashing the art the way the original draws it. *)
let rules_rect : Layout.rect = { x = 50; y = 324; w = 128; h = 395 }

let targets_cx = 847 + (134 / 2)
let targets_y = 323

(* The meter: 21 icons, three across, stepping 44 both ways from (851,359). *)
let meter_count = 21
let meter_x0 = 851
let meter_y0 = 359
let meter_step = 44
let meter_icon = 40

let meter_rect (i : int) : Layout.rect =
  let i = max 0 (min (meter_count - 1) i) in
  { x = meter_x0 + ((i mod 3) * meter_step);
    y = meter_y0 + ((i / 3) * meter_step);
    w = meter_icon; h = meter_icon }

let in_rect (r : Layout.rect) (mx : int) (my : int) : bool =
  mx >= r.x && mx < r.x + r.w && my >= r.y && my < r.y + r.h

(** The window rectangle for one grid cell, column [c] and row [r]. *)
let cell_rect (c : int) (r : int) : Layout.rect =
  { x = grid_x + (c * cell); y = grid_y + (r * cell); w = cell; h = cell }

(** What a window position means to the game: a cell to select or swap, or
    nothing. The edges are inclusive at the top-left and exclusive at
    217+584 / 130+584, so the margins cannot read as column 8. *)
let hit (mx : int) (my : int) : [ `Cell of int * int | `Miss ] =
  if
    mx >= grid_x && mx < grid_x + grid_size
    && my >= grid_y && my < grid_y + grid_size
  then `Cell ((mx - grid_x) / cell, (my - grid_y) / cell)
  else `Miss
