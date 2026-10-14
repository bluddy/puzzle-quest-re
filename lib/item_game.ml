(* The forge skill game: the board the [FORGEITEMS_FAIL] string implies, the
   one a rune triple is *created* through rather than a forge button that
   always succeeds. [ItemGameMenu.xml] is the shipped screen (pad_grid at
   (217,130) 584x584 - the capture grid's own geometry - and a 21-icon
   [ITEMGAME_TARGET] meter down the right), [ITEMGAME_HELP] gives the goal
   ("Destroy Hammers and Anvils (by any means available) to score points"),
   and English/Rules_ItemGame.png carries the whole rule set, transcribed:

     4-OF-A-KIND   destroys a row or column
     5-OF-A-KIND   destroys all gems of matching type and a row or column
     HEROIC EFFORT creates a random Hammer & Anvil on the board
     SPECIAL       after Hammers & Anvils are destroyed, the board resets
     DEFEAT        you lose if there are no moves left & ...

   The defeat line trails off - clipped in the shipped 128x512 art - and the
   menu carries timer="on", so the second defeat condition is almost certainly
   a clock the port does not model; see forge.item_game_numbers in
   docs/reverse/evidence.yml. What the image does give is implemented here
   against the battle's own [Board]: a Hammer is a gem that matches only
   hammers and scores a point when destroyed, matches resolve through the
   shared engine (wildcard spawns off - no wildcard rule appears in the item
   game's rules), and the 4/5 extras clear lines off the run's own axis.

   Three numbers are NOT recovered - the exe answers no strings, its RTTI is
   orphaned, and no Lua touches forging - so they are port choices, recorded
   in port.item_game_rules: [hammers_per_board], [target_for_band] (the ten
   Easy..Godlike bands become targets; the meter's 21 icons fix the ceiling,
   so band b asks 3+2b points and Godlike fills it exactly), and the
   reset-after-every-destruction reading of SPECIAL, which is the literal
   [ITEMGAMEMENU_TEXT] ("Each time one or more of them are destroyed, the
   board will reset") rather than the looser "all of them" gloss. *)

open Board

type status = Playing | Won | Lost

type t = {
  board : board;
  score : int;  (** hammers destroyed, one point each ([ITEMGAME_TARGET] is
                    literally "POINTS", and its meter icons are the
                    [img_hammanv] gem itself, one per point) *)
  target : int;
  status : status;
  rng : int -> int;
}

(** [HEROICEFFORT_TEXT]: "a cascade of 5 or more series of gems". The battle
    reads the same threshold from its rules; here it is the one number the
    recovered rule set names. *)
let heroic_depth = 5

(** How many hammers a board carries. Port choice - the rules image never
    says, and a board full of them would make the 4/5 extras pointless. *)
let hammers_per_board = 4

(** The ten [FORGEITEMS_TARGET*] bands as point targets. Port choice: the
    meter is 21 [icon_point] cells, so band b asks 3+2b and Godlike (band 9)
    fills the meter exactly, while the gifted triple's band 1 asks a
    forgiving 5. *)
let target_for_band (band : int) : int = 3 + (2 * max 0 (min 9 band))

let blank_board () : board =
  of_array_matrix
    (Array.init default_height (fun _ ->
         Array.init default_width (fun _ -> Empty)))

let hammers_on_board (b : board) : int =
  let n = ref 0 in
  for y = 0 to b.height - 1 do
    for x = 0 to b.width - 1 do
      if get_gem b { x; y } = Hammer then incr n
    done
  done;
  !n

(** Whether dropping a hammer at [p] would complete a hammer run of three.
    Seeding and the heroic spawn both avoid it: a board that opens on a
    hammer line hands the player a free point, and the rule set never
    mentions pre-existing runs waiting to be swept (capture's board does
    carry them, but that is that game's recorded choice). *)
let hammer_run_at (b : board) (p : position) : bool =
  let b' = set_gem p Hammer b in
  List.exists
    (fun (coords, g) -> g = Hammer && List.exists (fun q -> q = p) coords)
    (find_matches b')

(** A fresh layout: full random refill that has a legal move, then the
    hammers one at a time in cells that are free and do not complete a line.
    The bounded retry is the same guard [reshuffle] carries - a pathological
    rng must not hang the forge. *)
let fresh_board ~(rng : int -> int) : board =
  let b = reshuffle ~rng (blank_board ()) in
  let b = ref b in
  for _ = 1 to hammers_per_board do
    let placed = ref false in
    let tries = ref 0 in
    while (not !placed) && !tries < 40 do
      incr tries;
      let p = { x = rng default_width; y = rng default_height } in
      if get_gem !b p <> Hammer && not (hammer_run_at !b p) then begin
        b := set_gem p Hammer !b;
        placed := true
      end
    done
  done;
  !b

(* HEROIC EFFORT: a random hammer, on a cell that is not already one and
   does not complete a line - the seeding rule again. *)
let spawn_hammer ~(rng : int -> int) (b : board) : board =
  let placed = ref b in
  let ok = ref false in
  let tries = ref 0 in
  while (not !ok) && !tries < 40 do
    incr tries;
    let p = { x = rng default_width; y = rng default_height } in
    if get_gem !placed p <> Hammer && not (hammer_run_at !placed p) then begin
      placed := set_gem p Hammer !placed;
      ok := true
    end
  done;
  !placed

(* One cascade step under the item game's rules: the shared match resolution
   (wildcards off), then the rules image's extras per run - a run of 4
   destroys its own row or column, a run of 5 destroys every gem of its type
   as well - then gravity and refill. Returns the next board and the
   hammers this step destroyed, which is the point score. *)
let step ~(rng : int -> int) (b : board) : (board * int) option =
  match resolve_matches ~wildcards_enabled:false b with
  | None -> None
  | Some (b_cleared, res) ->
    let cleared = Hashtbl.create 64 in
    List.iter (fun (p, _) -> Hashtbl.replace cleared p true) res.gems_cleared;
    let line_cells (run : position list) : position list =
      let head = List.hd run in
      if List.for_all (fun p -> p.y = head.y) run then
        List.init default_width (fun x -> { x; y = head.y })
      else List.init default_height (fun y -> { x = head.x; y })
    in
    let sweep_cells (g : gem) : position list =
      let acc = ref [] in
      for y = 0 to b.height - 1 do
        for x = 0 to b.width - 1 do
          let p = { x; y } in
          if get_gem b p = g then acc := p :: !acc
        done
      done;
      !acc
    in
    List.iter
      (fun (run, g) ->
        let n = List.length run in
        if n >= 4 then
          List.iter (fun p -> Hashtbl.replace cleared p true) (line_cells run);
        if n >= 5 && g <> Empty then
          List.iter (fun p -> Hashtbl.replace cleared p true) (sweep_cells g))
      res.runs;
    (* The score reads the PRE-clear board: a hammer that was in the match
       itself is gone from b_cleared but is still a point. *)
    let hammers =
      Hashtbl.fold
        (fun p _ n -> if get_gem b p = Hammer then n + 1 else n)
        cleared 0
    in
    let emptied =
      Hashtbl.fold (fun p _ acc -> set_gem p Empty acc) cleared b_cleared
    in
    Some (refill_board ~rng (apply_gravity emptied), hammers)

(** Open a game: a fresh board under [target] points. A target below 1 is
    clamped up - a game the player has already won is not a game. *)
let create ?(rng = Random.int) ~(target : int) () : t =
  let board = fresh_board ~rng in
  let status = if find_all_legal_moves board = [] then Lost else Playing in
  { board; score = 0; target = max 1 target; status; rng }

(** Open a game over a given board - how the tests pin the mechanics on
    boards they constructed rather than on whatever the rng dealt, and what a
    front would use to restore a position. A board with no legal move opens
    Lost, the same rule capture's [status_of] applies. *)
let of_board ?(rng = Random.int) ~(target : int) (board : board) : t =
  let status = if find_all_legal_moves board = [] then Lost else Playing in
  { board; score = 0; target = max 1 target; status; rng }

(** One move. [None] when the swap is not legal (or the game is over); the
    returned game carries the cascaded board, the new score, and the status
    the rules produce: Won once the target is met, a full board reset after
    any destruction ([ITEMGAMEMENU_TEXT]: "Each time one or more of them are
    destroyed, the board will reset"), a heroic spawn when the cascade ran
    [depth] deep ([depth] defaults to [heroic_depth]; a test lowers it to
    reach the spawn without building a five-step cascade), and Lost when a
    non-scoring move leaves no legal swap. *)
let play ?(depth = heroic_depth) (t : t) (sw : swap) : t option =
  match t.status with
  | Won | Lost -> None
  | Playing ->
    if not (is_valid_swap t.board sw.from_pos sw.to_pos) then None
    else begin
      let b = ref (swap_gems t.board sw.from_pos sw.to_pos) in
      let gained = ref 0 in
      let steps = ref 0 in
      let continue = ref true in
      while !continue do
        match step ~rng:t.rng !b with
        | None -> continue := false
        | Some (b', hammers) ->
          incr steps;
          gained := !gained + hammers;
          b := b'
      done;
      let score = t.score + !gained in
      let heroic = !steps >= depth in
      if score >= t.target then Some { t with board = !b; score; status = Won }
      else if !gained > 0 then begin
        let fresh = fresh_board ~rng:t.rng in
        let fresh =
          if heroic then spawn_hammer ~rng:t.rng fresh else fresh
        in
        { t with board = fresh; score; status = Playing } |> Option.some
      end
      else begin
        let b' = if heroic then spawn_hammer ~rng:t.rng !b else !b in
        let status =
          if find_all_legal_moves b' = [] then Lost else Playing
        in
        Some { t with board = b'; score; status }
      end
    end

(* Greedy test driver, capture's shape: first legal move until the game ends.
    The move bound exists because the reset keeps dealing fresh boards -
    unlike capture's shrinking grid this game does not obviously terminate,
    so a pathological target would loop forever. *)
let auto_play ?(max_moves = 400) (t : t) : t =
  let rec go n t =
    if n <= 0 then t
    else
      match t.status with
      | Won | Lost -> t
      | Playing -> (
        match find_all_legal_moves t.board with
        | [] -> { t with status = Lost }
        | sw :: _ -> (
          match play t sw with
          | Some t' -> go (n - 1) t'
          | None -> { t with status = Lost }))
  in
  go max_moves t
