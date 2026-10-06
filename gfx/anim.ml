(** Turning a [Battle.step] into somewhere a gem should be drawn, right now.

    Pure, and that is the whole design. The engine says what happened and hands
    over the boards on either side; this module works out the in-between, and
    because it is arithmetic on boards it can be tested without a window - which is
    the only way to be sure a cascade falls the way it claims to.

    ## Matching gems across a cascade

    The hard part is not the interpolation, it is deciding which gem in [cleared]
    is which gem in [after]. Gems are values: a board full of fire mana has
    sixteen indistinguishable fire gems, so identity cannot be used.

    Gravity is what makes it tractable. It moves gems **down within a column and
    preserves their order**, and refills add new gems at the top. So walking each
    column from the bottom, the k-th gem in one is the k-th gem in the other, and
    whatever is left over at the top of [after] is new. That is [fall_pairs], and
    it is exact rather than heuristic - which matters, because a wrong pairing looks
    fine until a gem visibly teleports.

    ## What is drawn, and when

    Three phases per cascade step, each with its own duration, and they run in
    order:

    1. [Pop] - the matched gems, scaled and faded out, still sitting where they
       were. Drawn over [before].
    2. [Fall] - everything else dropping into place. Drawn over [cleared].
    3. Nothing - [after] is simply the next step's board, or the board at rest.

    A swap is one phase: the two gems cross over. *)

open Puzzle_quest_lib

type phase =
  | Popping of { before : Board.board; runs : (Board.position list * Board.gem) list }
  | Falling of { cleared : Board.board; pairs : fall list; entrants : fall list }
  | Sliding of {
      before : Board.board;
      after : Board.board;
      a : Board.position;
      b : Board.position;
    }

and fall = { x : int; from_y : int; to_y : int; gem : Board.gem }

(* ------------------------------------------------------------- durations -- *)

(* Short enough to feel like a consequence rather than a wait. The original's own
   timings are not recovered; these are ours and they are the first thing to change
   if it feels wrong. *)
let pop_seconds = 0.14
let fall_seconds = 0.18
let slide_seconds = 0.13

(* ------------------------------------------------------------ the matcher -- *)

(** The gems in one column, **bottom-up**.

    The order is the whole point of this function, so it is worth being explicit
    about: iterating downwards and consing produces the list top-down, because each
    lower row ends up in front. That is wrong here - it pairs a column's gems with
    the wrong partners as soon as a new gem arrives at the top, pairing the topmost
    survivor with the newcomer instead of the bottom one. Iterating upwards and
    consing puts the bottom row first, which is the order the pairing needs.

    [test_gfx_anim] pins the order rather than trusting this comment. *)
let gems_in_column (b : Board.board) (x : int) : (int * Board.gem) list =
  let out = ref [] in
  for y = 0 to b.Board.height - 1 do
    match Board.get_gem b { Board.x; y } with
    | Board.Empty -> ()
    | g -> out := (y, g) :: !out
  done;
  !out

(** How each gem gets from [cleared] to [after], per column.

    See the note at the top: bottom-up pairing within a column, because gravity
    preserves order and refills arrive at the top. Whatever in [after] has no
    partner is an entrant, and is listed separately because it does not fall from
    where a gem was - it drops in from above the board.

    Both columns are walked in one pass rather than in two phases, so the split
    between "fell" and "new" falls out of where the lists stop overlapping instead
    of being computed twice and hoped to agree. *)
let fall_pairs ~(cleared : Board.board) ~(after : Board.board) :
    fall list * fall list =
  let pairs = ref [] and entrants = ref [] in
  let rec split x from_col to_col =
    match (from_col, to_col) with
    | [], (ty, g) :: rest ->
        (* Enter from just above the board, so a new gem drops *in* rather than
           fading into existence at its final row. *)
        entrants := { x; from_y = -1; to_y = ty; gem = g } :: !entrants;
        split x [] rest
    | (fy, g) :: from_rest, (ty, _) :: to_rest ->
        (* Only gems that actually move. A stationary gem is left out so the
           renderer can draw [cleared] as its base layer and offset just these -
           which means a gem cannot go missing by being absent from this list, the
           failure mode that a complete-but-filtered list invites. *)
        if fy <> ty then pairs := { x; from_y = fy; to_y = ty; gem = g } :: !pairs;
        split x from_rest to_rest
    | _ -> ()
  in
  for x = 0 to cleared.Board.width - 1 do
    split x (gems_in_column cleared x) (gems_in_column after x)
  done;
  (List.rev !pairs, List.rev !entrants)

(* ------------------------------------------------------------- the queue -- *)

type t = { mutable queue : (phase * float) list; mutable now : float }

let create () : t = { queue = []; now = 0.0 }

let clear (t : t) =
  t.queue <- [];
  t.now <- 0.0

let duration = function Popping _ -> pop_seconds | Falling _ -> fall_seconds | Sliding _ -> slide_seconds

let is_busy (t : t) = t.queue <> []

(** The animation's own clock, in seconds since it was created. A caller that has
    no frame loop of its own - the screenshot harness - needs to fast-forward to a
    chosen point rather than wait for real time to pass. *)
let now (t : t) = t.now

(** Enqueue a step. A step while one is already running is queued behind it rather
    than replacing it, so a cascade does not skip its own middle. *)
let push_step (t : t) (s : Battle.step) =
  let phases : phase list =
    match s with
    | Battle.Swapped { before; after; a; b } -> [ Sliding { before; after; a; b } ]
    | Battle.Cascaded { before; cleared; after; runs; step = _ } ->
        let pairs, entrants = fall_pairs ~cleared ~after in
        (* Both phases are queued: the pop has to finish before anything falls, or
           the gems overlap mid-flight and the gaps are never seen. *)
        [ Popping { before; runs }; Falling { cleared; pairs; entrants } ]
  in
  (* Deadlines accumulate rather than each being measured from now. Measuring each
     from now would give the pop and the fall overlapping deadlines - the pop
     ending at now + 0.14 and the fall at now + 0.18 - so the fall would already
     be a quarter done before the pop finished, and the gaps would never be seen. *)
  let until = ref t.now in
  List.iter
    (fun p ->
      until := !until +. duration p;
      t.queue <- t.queue @ [ (p, !until) ])
    phases

(** Advance the clock and drop finished phases. Returns true while there is
    something to draw. *)
let advance (t : t) (dt : float) =
  t.now <- t.now +. dt;
  t.queue <- List.filter (fun (_, until) -> until > t.now) t.queue;
  is_busy t

(** Progress through the current phase, 0 at its start and 1 at its end. *)
let progress (t : t) : (phase * float) option =
  match t.queue with
  | [] -> None
  | (p, until) :: _ ->
      let total = duration p in
      let elapsed = max 0.0 (min total (until -. t.now)) in
      Some (p, if total <= 0.0 then 1.0 else 1.0 -. (elapsed /. total))

(* ------------------------------------------------------------ what to draw -- *)

(** The cells the matched gems occupy, deduplicated.

    [runs] can name the same cell twice when a Red Skull explosion pulled a gem
    into a run it was not matched with, and drawing it twice is harmless but
    counting it twice is not. *)
let matched_cells (runs : (Board.position list * Board.gem) list) : Board.position list =
  let seen = Hashtbl.create 16 in
  List.fold_left
    (fun acc (coords, _) ->
      List.fold_left
        (fun acc p ->
          if Hashtbl.mem seen (p.Board.x, p.Board.y) then acc
          else begin
            Hashtbl.replace seen (p.Board.x, p.Board.y) ();
            p :: acc
          end)
        acc coords)
    [] runs
  |> List.rev

(** How a popping gem is scaled, at progress [p].

    Grows briefly then collapses: a matched gem in the original flashes rather than
    simply vanishing, and a straight shrink reads as a gap appearing. *)
let pop_scale (p : float) : float =
  if p < 0.3 then 1.0 +. (0.25 *. (p /. 0.3))
  else max 0.0 (1.25 *. (1.0 -. ((p -. 0.3) /. 0.7)))

let pop_alpha (p : float) : int =
  let a = 1.0 -. p in
  int_of_float (255.0 *. max 0.0 (min 1.0 a))

let fall_y (f : fall) (p : float) : float =
  let from_ = float_of_int f.from_y and to_ = float_of_int f.to_y in
  from_ +. ((to_ -. from_) *. p)

(** Where the two swapped gems are, at progress [p].

    Each travels the whole way and they cross at the midpoint. **The axis that
    moves is whichever differs** - a horizontal swap interpolates x and holds y, a
    vertical one the reverse - because a legal swap is always orthogonal and the
    step record carries two positions rather than a direction. Interpolating both
    axes would send a horizontal swap diagonally, and interpolating only y (which is
    what this did first) left it not moving at all.

    [p] is clamped so an over-long frame cannot push a gem past its destination. *)
let slide_pos (a : Board.position) (b : Board.position) (p : float) :
    Board.position * Board.position =
  let p = max 0.0 (min 1.0 p) in
  let lerp u v = u +. ((v -. u) *. p) in
  let ax = float_of_int a.Board.x and bx = float_of_int b.Board.x in
  let ay = float_of_int a.Board.y and by = float_of_int b.Board.y in
  if a.Board.x <> b.Board.x then
    ( { Board.x = int_of_float (lerp ax bx); y = a.Board.y },
      { Board.x = int_of_float (lerp bx ax); y = b.Board.y } )
  else
    ( { Board.x = a.Board.x; y = int_of_float (lerp ay by) },
      { Board.x = b.Board.x; y = int_of_float (lerp by ay) } )

(** The gems to draw for one frame, and where.

    This is the join between the geometry above and the renderer: the animation
    decides *which* board is current and where each gem has got to, and the caller
    turns that into quads. Keeping it here means the renderer never has to know
    what a cascade is.

    A cell is either fractional (mid-fall, mid-slide) or whole. Fractional rows are
    what make the motion read as motion rather than as a jump between two frames. *)
type placed_gem = {
  x : float;  (** fractional column *)
  y : float;  (** fractional row; may be above 0 for a gem dropping in *)
  w : float;
  h : float;
  gem : Board.gem;
  alpha : int;  (** per-gem opacity, 0..255 *)
}

let cell_size = 1.0

(** Every gem the current frame should draw, with [cleared]-relative positions.

    Returned in no particular order: they are drawn as sprites and do not overlap
    except mid-fall, where the ones behind should be behind. *)
let frame (t : t) : placed_gem list =
  match progress t with
  | None -> []
  | Some (Popping { before; runs }, p) ->
      let popping = matched_cells runs in
      let is_popping x y = List.exists (fun (c : Board.position) -> c.Board.x = x && c.Board.y = y) popping in
      List.concat_map
        (fun y ->
          List.concat_map
            (fun x ->
              let g = Board.get_gem before { Board.x = x; y } in
              if g = Board.Empty then []
              else
                (* Only the matched gems pop. The rest of the board holds still,
                   which is what makes the pop read as a consequence rather than as
                   the whole board twitching. *)
                let scale = if is_popping x y then pop_scale p else 1.0 in
                let shrink = (1.0 -. scale) /. 2.0 in
                (* The fade rides on the matched gem alone. A whole-frame alpha
                   would dim the stationary board too, which reads as the entire
                   board flashing rather than the matched three bursting. *)
                let alpha = if is_popping x y then pop_alpha p else 255 in
                [ { x = float_of_int x +. shrink;
                    y = float_of_int y +. shrink;
                    w = cell_size *. scale;
                    h = cell_size *. scale;
                    gem = g;
                    alpha } ])
            (List.init before.Board.width (fun i -> i)))
        (List.init before.Board.height (fun i -> i))
  | Some (Falling { cleared; pairs; entrants }, p) ->
      (* Everything still standing stays where it was; the movers and the newcomers
         are drawn on top at their interpolated positions. Stationary gems are not
         in [pairs] precisely so this base layer cannot miss one. *)
      let base =
        List.concat_map
          (fun y ->
            List.concat_map
              (fun x ->
                let g = Board.get_gem cleared { Board.x = x; y } in
                if g = Board.Empty then []
                else
                  [ { x = float_of_int x; y = float_of_int y; w = cell_size;
                      h = cell_size; gem = g; alpha = 255 } ])
              (List.init cleared.Board.width (fun i -> i)))
          (List.init cleared.Board.height (fun i -> i))
      in
      let moving (fl : fall) =
        { x = float_of_int fl.x;
          y = fall_y fl p;
          w = cell_size;
          h = cell_size;
          gem = fl.gem;
          alpha = 255 }
      in
      base @ List.map moving pairs @ List.map moving entrants
  | Some (Sliding { before; a; b; after = _ }, p) ->
      let (pa, pb) = slide_pos a b p in
      List.concat_map
        (fun y ->
          List.concat_map
            (fun x ->
              (* The two swapped cells are drawn from [before] at their moving
                 positions; every other cell is where it always was. *)
              let cell = { Board.x = x; y } in
              if (x = a.Board.x && y = a.Board.y) then
                [ { x = float_of_int pa.Board.x; y = float_of_int pa.Board.y;
                    w = cell_size; h = cell_size;
                    gem = Board.get_gem before a;
                    alpha = 255 } ]
              else if (x = b.Board.x && y = b.Board.y) then
                [ { x = float_of_int pb.Board.x; y = float_of_int pb.Board.y;
                    w = cell_size; h = cell_size;
                    gem = Board.get_gem before b;
                    alpha = 255 } ]
              else
                let g = Board.get_gem before cell in
                if g = Board.Empty then []
                else
                  [ { x = float_of_int x; y = float_of_int y; w = cell_size;
                      h = cell_size; gem = g; alpha = 255 } ])
            (List.init before.Board.width (fun i -> i)))
        (List.init before.Board.height (fun i -> i))
