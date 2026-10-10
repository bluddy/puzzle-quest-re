(* The capture window's geometry, read from the shipped CaptureMenu.xml:
   pad_grid is 584x584 at (217, 130) in the 1024x768 screen - the same fixed
   screen [Layout.game_screen_w/h] and the map front draw in - the [CAPTURE]
   title sits at (256, 95) and [CAPTURE_HELP] runs along y=733, centred.

   One control has no XML element: the give-up button. The original backs out
   of the minigame with the gamepad's [CANCEL]; a console window has no
   gamepad, so the port draws a [CANCEL] button, top-right and aligned with
   the grid's right edge, clear of the centred title. Everything else is
   arithmetic the XML already fixed, which is exactly the kind of thing these
   pure modules exist to pin. *)

type hit = Cell of int * int | Cancel | Miss

let grid_x = 217
let grid_y = 130
let grid_size = 584
let cols = 8
let cell = grid_size / cols

let title_y = 95
let help_y = 733

let cancel_w = 140
let cancel_h = 30
let cancel_rect : Layout.rect =
  { x = grid_x + grid_size - cancel_w; y = 90; w = cancel_w; h = cancel_h }

let in_rect (r : Layout.rect) (mx : int) (my : int) : bool =
  mx >= r.x && mx < r.x + r.w && my >= r.y && my < r.y + r.h

(** The window rectangle for one grid cell, column [c] left to right and row
    [r] top to bottom in the shipped grid's own string order. *)
let cell_rect (c : int) (r : int) : Layout.rect =
  { x = grid_x + (c * cell); y = grid_y + (r * cell); w = cell; h = cell }

(** What a window position means to the minigame: a cell to select or swap,
    the give-up button, or nothing. The grid's edges are inclusive at the top
    and exclusive at 217+584 / 130+584, so the window's right margin can
    never read as column 8. *)
let hit (mx : int) (my : int) : hit =
  if in_rect cancel_rect mx my then Cancel
  else if
    mx >= grid_x && mx < grid_x + grid_size
    && my >= grid_y && my < grid_y + grid_size
  then Cell ((mx - grid_x) / cell, (my - grid_y) / cell)
  else Miss
