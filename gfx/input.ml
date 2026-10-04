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

(** Where the spell bar is. Separated from [Layout] because the bar is chrome, not
    board, and has no relationship to the board's geometry. *)
type bar = { count : int; button_w : int; gap : int; top_y : int; left_x : int }

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
  | Miss
      (** Neither board nor bar: ignored. *)

let bar_button (b : bar) (mx : int) (my : int) : int option =
  if my < b.top_y then None
  else
    let i = (mx - b.left_x) / (b.button_w + b.gap) in
    if i < 0 || i >= b.count then None
    else if mx - b.left_x - (i * (b.button_w + b.gap)) > b.button_w then None
    else Some i

(** The spell prompt. [usable] is how many live buttons there are.

    A click on a live button casts it. {e Everything else declines} - including a
    click on a button that is not currently affordable, because the player asked
    to move on and blocking them would be the same trap in a smaller window. *)
let in_spell_prompt (b : bar) ~usable (mx : int) (my : int) : action =
  match bar_button b mx my with
  | Some i when i < usable -> Cast i
  | _ -> Decline

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