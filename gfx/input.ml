(** What a click means, given what is currently being asked for.

    Pure decision-making, deliberately free of SDL: the front end does the I/O and
    hands the coordinates here. That split is not tidiness, it is the only reason
    this file can be tested at all - and testing it is how a trap gets caught.

    The trap was this. When the spell prompt was the only thing reading clicks,
    clicking anywhere that was not a spell button simply asked again, forever. The
    player could not decline a spell, so the swap prompt was never reached and no
    swap was ever possible. It looked exactly like "clicks are not registered"
    while the clicks were arriving perfectly well.

    So: a click outside the spell bar means {e decline the spell}. Which is also
    what it should mean, because in the real game you can make a match without
    casting anything. *)

(** Where the spell buttons are: their rectangles, in window pixels.

    Rectangles rather than a row of numbers because the two layouts the game has
    are not the same shape - the front end once laid its spells out in one
    horizontal strip along the bottom, and they now sit in the original's seven
    stacked pads down the side (`Battle_layout.spell_rows`). A bar that stores
    the rectangles it was handed cannot disagree with the drawing, which is the
    whole point of the type living next to the code that draws them. *)
type bar = { rects : Layout.rect array }

(** Buttons left to right, [count] of them, [button_h] tall from [top_y]. *)
let horizontal ~count ~button_w ~button_h ~gap ~top_y ~left_x : bar =
  {
    rects =
      Array.init count (fun i ->
          {
            Layout.x = left_x + (i * (button_w + gap));
            y = top_y;
            w = button_w;
            h = button_h;
          });
  }

(** Buttons top to bottom - the side panel's spell rows. [pitch] is the step
    between row tops, so a gutter is [pitch - button_h]. *)
let vertical ~count ~button_w ~button_h ~pitch ~top_y ~left_x : bar =
  {
    rects =
      Array.init count (fun i ->
          {
            Layout.x = left_x;
            y = top_y + (i * pitch);
            w = button_w;
            h = button_h;
          });
  }

(** Wrap rectangles the caller already has - [Battle_layout.spell_rows], say. *)
let of_rects (rects : Layout.rect array) : bar = { rects }

type action =
  | Cast of int
      (** Cast the given button index. *)
  | Decline
      (** Not a spell button: make a match instead. *)
  | First_cell of int * int
      (** The first half of a swap. *)
  | Swap of int * int * int * int
      (** (from_x, from_y, to_x, to_y), already checked legal. *)
  | No_match
  | Pass
      (** The bar was clicked while choosing a swap: end the turn. *)
  | Aim of int * int
      (** The cell a spell was aimed at: see [in_target_prompt]. *)
  | Cancel
      (** The bar was clicked while aiming: back to the spell question. *)
  | Miss
      (** Neither board nor bar: ignored. *)

let bar_button (b : bar) (mx : int) (my : int) : int option =
  let rec find i =
    if i >= Array.length b.rects then None
    else
      let r = b.rects.(i) in
      if mx >= r.Layout.x && mx < r.Layout.x + r.Layout.w && my >= r.Layout.y
         && my < r.Layout.y + r.Layout.h
      then Some i
      else find (i + 1)
  in
  find 0

(** The spell prompt. [live] answers whether a given button may be pressed - the
    front end passes "is this spell affordable", so a greyed row is a real
    rectangle whose click means decline rather than an index that has to line up
    with a filtered list.

    A click on a live button casts it. {e Everything else declines} - including
    a click on a button that is not currently affordable, because the player asked
    to move on and blocking them would be the same trap in a smaller window. *)
let in_spell_prompt (b : bar) ~live (mx : int) (my : int) : action =
  match bar_button b mx my with
  | Some i when live i -> Cast i
  | _ -> Decline

(** The target prompt, for a spell whose [input_type] is not 0.

    The three kinds - column, row, grid - are all answered by a cell: the
    column spells read its [x], the row spells its [y], the grid spells both.
    So one prompt covers all three, and no cell the board owns is an invalid
    target here; anything worth rejecting would have to be rejected by the
    spell, and none of the nine do.

    The bar is the way out, the same way it is everywhere else: clicking it
    cancels the cast and returns to the spell question, so a player who
    aimed at the wrong spell is never stuck holding it. *)
let in_target_prompt (b : bar) (lay : Layout.t) (mx : int) (my : int) : action =
  if bar_button b mx my <> None then Cancel
  else match Layout.hit lay mx my with
    | None -> Miss
    | Some (x, y) -> Aim (x, y)

(** The swap prompt. [valid] answers whether two cells would actually make a match,
    which needs the board and so is supplied by the caller. *)
let in_swap_prompt (b : bar) (lay : Layout.t) ~(first : (int * int) option)
    ~(valid : int * int -> int * int -> bool) (mx : int) (my : int) : action =
  if bar_button b mx my <> None then Pass
  else
    match Layout.hit lay mx my with
    | None -> Miss
    | Some (x, y) -> (
        match first with
        | None -> First_cell (x, y)
        | Some (px, py) ->
            (* A click that is not adjacent {e restarts} the selection rather than
               complaining. With a click-based UI - as opposed to the original's
               drag - reselecting is what a player means, and refusing leaves them
               stuck on a mis-click with no way forward but hitting the exact
               neighbour. *)
            if abs (px - x) + abs (py - y) <> 1 then First_cell (x, y)
            else if valid (px, py) (x, y) then Swap (px, py, x, y)
            else No_match)