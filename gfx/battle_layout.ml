(** Where the battle screen's furniture sits.

    The geometry is recovered rather than designed: `Assets/Screens/GameMenu.xml`
    is the original's battle screen, and it declares every rectangle here by
    name - the character pads, the seven spell pads under each of them, the grid
    pad, the life-point bar, the two timer plates, the missed-turn badges and the
    turn line. This module is the transcription, plus the two rectangles the XML
    has no opinion about (the mana bars and the combat log), so a test can pin
    the recovered numbers against the asset and the designed ones against each
    other.

    Deliberately free of SDL and of the board: everything is a rectangle in the
    game's own 1024x768 screen, which is the size [Layout] already fixes the
    window to. The board rectangle is *not* recovered here - the port centres its
    board and reserves a band for the log, so the log is derived from whatever
    board it is given rather than from the XML's pad. *)

type side =
  | Hero  (** `pad_gamechar0`, the left pad: the player's side. *)
  | Foe  (** `pad_gamechar1`, the right pad. *)

let other = function Hero -> Foe | Foe -> Hero

let game_w = Layout.game_screen_w
let game_h = Layout.game_screen_h

(* ---------------------------------------------------------------- recovered -- *)

(** `pad_grid`: 584 square at (217,130), so the original's cells are 73px.
    The port draws the gem sheet 1:1 at its own 71px (`pq_play_gfx`), so this is
    the reference the port's board is *not* - kept because it is what the asset
    says and because 584 is the number every other screen's pad agrees with. *)
let pad_grid : Layout.rect = { x = 217; y = 130; w = 584; h = 584 }

let grid_cell = pad_grid.Layout.w / 8

(** `pad_gamechar0` / `pad_gamechar1`: 180x348 at x=11 and x=835, y=119. The
    panel a character's portrait, life and mana live in. *)
let panel : side -> Layout.rect = function
  | Hero -> { x = 11; y = 119; w = 180; h = 348 }
  | Foe -> { x = 835; y = 119; w = 180; h = 348 }

(** `icon_enemylifepts`: (837,121) 175x18 - the life bar, two pixels into the
    foe's pad and five narrower than it. The XML only names it for the enemy, and
    the enemy's pad is the same shape as the hero's, so both sides take it. *)
let life_bar (s : side) : Layout.rect =
  let p = panel s in
  { x = p.Layout.x + 2; y = p.Layout.y + 2; w = p.Layout.w - 5; h = 18 }

(** `pad_gamechar{0,1}_sp0..sp6`: seven rows, 178x37 at y=462 stepping 41, so a
    4px gutter between rows. This is the spell list - the row under the last one
    ends at 745, three pixels short of the screen's bottom edge. *)
let spell_count = 7
let spell_row_h = 37
let spell_row_pitch = 41
let spell_rows_top = 462
let spell_row_w = 178

let spell_rows (s : side) : Layout.rect array =
  let x = (panel s).Layout.x in
  Array.init spell_count (fun i ->
      {
        Layout.x = x;
        y = spell_rows_top + (i * spell_row_pitch);
        w = spell_row_w;
        h = spell_row_h;
      })

(** `icon_ltimebg` / `icon_rtimebg`: the 90x90 turn plates at (135,16) and
    (784,16), with `str_ltime` / `str_rtime` centred on them. The port used to
    pin these to the screen's outer ends; the XML says where they go. *)
let timer_plate : side -> Layout.rect = function
  | Hero -> { x = 135; y = 16; w = 90; h = 90 }
  | Foe -> { x = 784; y = 16; w = 90; h = 90 }

(** `str_ltime` / `str_rtime`: the 90x30 countdown band centred over each
    plate at (132,38) and (781,38), font_button - where the original puts the
    two-digit seconds the Time Limit buys. *)
let timer_text : side -> Layout.rect = function
  | Hero -> { x = 132; y = 38; w = 90; h = 30 }
  | Foe -> { x = 781; y = 38; w = 90; h = 30 }

(** `icon_missturn0` / `icon_missturn1`: 90x24 at (53,100) and (876,100) - the
    badge that says a character is sitting this turn out. The art for it is in
    the battle sheet as `img_missturn_1..5`. *)
let missed_badge : side -> Layout.rect = function
  | Hero -> { x = 53; y = 100; w = 90; h = 24 }
  | Foe -> { x = 876; y = 100; w = 90; h = 24 }

(** `str_turn`: 124x18 centred at (450,736), font_small - whose side's turn it
    is, at the bottom of the screen under everything else. *)
let turn_rect : Layout.rect = { x = 450; y = 736; w = 124; h = 18 }

(** `str_battlename`: 512x25 at (256,95), the fight's title above the grid. Kept
    for the round that draws it; the port's top band is narrower than the
    original's (its board starts at y=44, not y=130), so it does not fit yet. *)
let battle_name_rect : Layout.rect = { x = 256; y = 95; w = 512; h = 25 }

(* ----------------------------------------------------------------- designed -- *)

(** The mana bars: four of them, filling the foot of the panel just above the
    first spell row. The XML has no mana rectangles - the original draws them
    inside the portrait art - so this is the port's layout, chosen to obey two
    recovered numbers rather than to invent a third: the bars end where the spell
    rows begin, and they are the panel's own width less a three-pixel inset. *)
let mana_bar_h = 16
let mana_bar_pitch = 20
let mana_count = 4

let mana_bars (s : side) : Layout.rect array =
  let p = panel s in
  let bottom = spell_rows_top - 4 in
  Array.init mana_count (fun i ->
      let y = bottom - mana_bar_h - ((mana_count - 1 - i) * mana_bar_pitch) in
      { Layout.x = p.Layout.x + 3; y; w = p.Layout.w - 6; h = mana_bar_h })

(** The combat log, which the original does not have: a band under the board,
    between the two panels, running up to the turn line. Derived from the board
    it is given rather than pinned, so it follows the port's board wherever the
    centring rules put it, and the panel columns are what keep it from growing
    sideways into the spell rows. *)
let log_rect ~(board : Layout.rect) : Layout.rect =
  let y = board.Layout.y + board.Layout.h + 8 in
  { x = board.Layout.x; y; w = board.Layout.w; h = max 0 (turn_rect.Layout.y - y - 6) }

let log_line_h = 16

let log_lines (r : Layout.rect) : int = r.Layout.h / log_line_h

(* ------------------------------------------------------------------ derived -- *)

(** The band the log sits in, as a full-width rectangle: the bottom [bar_h]
    pixels of the screen, which is what the front end reserves when it builds its
    board. The log itself is narrower (see {!log_rect}); this is the painted
    backdrop behind it. *)
let log_band (h : int) : Layout.rect =
  { x = 0; y = game_h - h; w = game_w; h }
