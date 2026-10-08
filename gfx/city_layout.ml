(** The city panel's geometry, read out of Assets/Screens/ShopMenu.xml:
    the title at (96, 50), the gold line at (96, 115), the seven buy rows
    stepping 26 pixels from y=170, the mode button at (60, 402) and Done at
    (486, 402).

    Pure, the same contract [Map_view] keeps: no SDL, no window, testable
    without a display. *)

type hit =
  | Row of int
      (** The nth row of the list the panel shows, 0-based - buy in the
          shop, next rumor in the tavern. *)
  | Tab
      (** The mode button: the next city tab. *)
  | Leave
      (** Done: back to the map. *)
  | Elsewhere
      (** The panel body: the tavern reads it as "another rumor". *)

let title_x = 96
let title_y = 50
let gold_x = 96
let gold_y = 115

(** The buy rows: ShopMenu gives a 22px marker at x=70 every 26 pixels,
    seven of them. *)
let row_x = 70
let row_y0 = 170
let row_step = 26
let row_h = 22
let max_rows = 7

(** How far right a row reaches. The marker itself is 22px wide, but the row
    {e is} the item's line and nothing says where the engine stopped
    hit-testing: 480 covers a name and a price inside the panel and stops
    short of the buttons - port.city_services. *)
let row_w = 480

let mode_btn : Layout.rect = { Layout.x = 60; y = 402; w = 160; h = 50 }
let done_btn : Layout.rect = { Layout.x = 486; y = 402; w = 160; h = 50 }

let in_rect (r : Layout.rect) (mx : int) (my : int) : bool =
  mx >= r.Layout.x && mx < r.Layout.x + r.Layout.w
  && my >= r.Layout.y && my < r.Layout.y + r.Layout.h

(** Where a click in the city panel lands. Buttons first - they sit below
    the rows, but a rectangle is only ever in one place. *)
let hit (mx : int) (my : int) : hit =
  if in_rect done_btn mx my then Leave
  else if in_rect mode_btn mx my then Tab
  else
    let dy = my - row_y0 in
    let i = dy / row_step in
    if
      mx >= row_x && mx < row_x + row_w && dy >= 0 && i >= 0 && i < max_rows
      && dy mod row_step < row_h
    then Row i
    else Elsewhere
