open Puzzle_quest_lib

(** Where everything sits on screen, and what colour it is.

    Deliberately free of SDL and OpenGL. Every number here is arithmetic on the
    board, and arithmetic is exactly the thing that should be testable without a
    window - so this module knows nothing about a context, and [Gl] knows nothing
    about the game's element colours. *)

type colour = { r : int; g : int; b : int; a : int }

let rgb r g b = { r; g; b; a = 255 }
let rgba r g b a = { r; g; b; a }

type rect = { x : int; y : int; w : int; h : int }

(** The resolution the game's own screen furniture is drawn for.

    Not a preference. `Assets/Screens/Backdrop.xml` declares a 1024x768 menu, and
    the border frames in the registry are cut to exactly that: top 1024x95, left
    19x653, right 21x653, bottom 1024x20. A window of any other size either crops
    the border or stretches it, so the window is this size and the decoration fits.
*)
let game_screen_w = 1024
let game_screen_h = 768

(** Board geometry.

    The board is [cols] x [rows] cells of [cell] pixels, centred in a window of
    [window_w] x [window_h]. Centring rather than pinning to a corner because the
    original's board sits in the middle of the combat screen, and because a
    centred board survives a window resize without a second set of rules.

    [reserve_top] and [reserve_bottom] are the heights of anything docked along
    the top and bottom edges - the top panel and the spell bar. They are
    subtracted before centring, not after, so the board centres in the space that
    is actually free instead of sitting half under the panel with a row hidden.
    Default 0, which is the plain case.

    [origin_x] and [origin_y] are the top-left of cell (0, 0) in window pixels,
    with y growing downwards as SDL and OpenGL both expect.

    A board taller than the free space is clamped to start at [reserve_top] rather
    than being pushed off the top of the screen. Overflowing the bottom is the
    better failure: the first row is still where a player expects it, whereas a
    negative origin renders the top of the board outside the window with nothing to
    explain it. It cannot happen at the sizes this project uses, which is why it is
    a clamp and not an error. *)
type t = {
  cell : int;
  cols : int;
  rows : int;
  origin_x : int;
  origin_y : int;
}

let create ~reserve_top ~reserve_bottom ~cell ~cols ~rows ~window_w ~window_h : t =
  if cell <= 0 then invalid_arg "Pq_gfx.Layout.create: cell must be positive";
  if cols <= 0 || rows <= 0 then
    invalid_arg "Pq_gfx.Layout.create: cols and rows must be positive";
  let board_w = cell * cols and board_h = cell * rows in
  let free_h = window_h - reserve_top - reserve_bottom in
  {
    cell;
    cols;
    rows;
    origin_x = (window_w - board_w) / 2;
    origin_y = max reserve_top (reserve_top + ((free_h - board_h) / 2));
  }

(** The destination rectangle for one cell, in window pixels. *)
let cell_rect (t : t) (x : int) (y : int) : rect =
  { x = t.origin_x + (x * t.cell); y = t.origin_y + (y * t.cell); w = t.cell; h = t.cell }

let board_rect (t : t) : rect =
  { x = t.origin_x; y = t.origin_y; w = t.cell * t.cols; h = t.cell * t.rows }

let in_bounds (t : t) (x : int) (y : int) : bool =
  x >= 0 && x < t.cols && y >= 0 && y < t.rows

(** Which cell a window position falls in, or [None] if it misses the board.

    Negative input is not clamped: a click to the left of the board is a miss,
    and clamping would hand back column 0 and turn a mis-click into a real move. *)
let hit (t : t) (mx : int) (my : int) : (int * int) option =
  let fx = mx - t.origin_x and fy = my - t.origin_y in
  if fx < 0 || fy < 0 then None
  else
    let x = fx / t.cell and y = fy / t.cell in
    if in_bounds t x y then Some (x, y) else None

(** The four gem colours, chosen to stay distinguishable at a glance and to keep
    the same hue family the original uses: earth green, fire red, water blue, air
    yellow. Skull is grey and red skull is a brighter red.

    These are placeholders for the real sprite art, and being placeholders they are
    named as such - see [tools/graphics_plan.md] phase 2. What matters here is
    that every gem kind maps to exactly one colour and that the mapping is total,
    so an unhandled kind cannot silently render as nothing. *)
let gem_colour : Board.gem -> colour = function
  | Board.Mana Board.Earth -> rgb 106 168 79
  | Board.Mana Board.Fire -> rgb 204 74 58
  | Board.Mana Board.Water -> rgb 62 133 199
  | Board.Mana Board.Air -> rgb 226 200 74
  | Board.Skull -> rgb 150 150 158
  | Board.RedSkull -> rgb 232 64 64
  | Board.Gold -> rgb 214 173 60
  | Board.Experience -> rgb 176 122 214
  | Board.Wildcard n ->
      (* A wildcard stands in for every element, so it is tinted across the
         element range by its multiplier: a 2x is mostly earth, an 8x mostly air.
         That keeps the hue meaning instead of inventing a fifth colour. *)
      let t = float_of_int (max 2 (min 8 n) - 2) /. 6.0 in
      let lerp a b = int_of_float (float_of_int a *. (1.0 -. t) +. float_of_int b *. t) in
      rgba (lerp 106 226) (lerp 168 200) (lerp 79 74) 255
  | Board.Empty -> rgba 40 44 56 255

(** A short label for a gem kind, for when text exists. *)
let gem_letter : Board.gem -> string = function
  | Board.Mana Board.Earth -> "E"
  | Board.Mana Board.Fire -> "F"
  | Board.Mana Board.Water -> "W"
  | Board.Mana Board.Air -> "A"
  | Board.Skull -> "S"
  | Board.RedSkull -> "R"
  | Board.Gold -> "G"
  | Board.Experience -> "X"
  | Board.Wildcard _ -> "*"
  | Board.Empty -> " "