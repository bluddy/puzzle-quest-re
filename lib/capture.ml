(* The capture side game: an 8x8 grid the player clears with normal battle
   matches and no refill. [CAPTURE_HELP] ("To capture this creature you must
   clear the grid of gems, matching them as if you were in a normal battle")
   gives the goal and the rules: the same swaps and the same match resolution
   as a battle, over a grid that only ever shrinks - gravity drops what is
   left, nothing spawns back, so the attempt ends when the grid is empty (won)
   or no swap makes a match (lost).

   The grid comes from the shipped capture_grid strings; the charset is the
   inventory the extractors saw: G/R/B/Y mana, S skull, O gold, X experience,
   * wildcard, - empty.

   Two chosen behaviours, both documented in evidence campaign.capture_state:
   the grid is laid out exactly as shipped, so runs that already exist (17 of
   the 60 grids carry one) wait for the first swap's resolution to clear them,
   and an all-empty grid (8 of them, placeholders on non-combat monsters)
   reads as won, the goal already met. The wildcard multiplier for * is chosen
   2: the charset itself carries no multiplier, and unlike the battle's 5-match
   spawn (min 8 count) there is no engine rule to recover here. *)

open Board

type status = Playing | Won | Lost

type t = { board: board; status: status }

let gem_of_char (c : char) : gem =
  match c with
  | '-' -> Empty
  | 'S' -> Skull
  | 'G' -> Mana Earth
  | 'R' -> Mana Fire
  | 'Y' -> Mana Air
  | 'B' -> Mana Water
  | 'O' -> Gold
  | 'X' -> Experience
  | '*' -> Wildcard 2
  | _ -> Empty

(* Parse the shipped grid rows: row i is y = i (top row first), x counts
   columns. Rows and columns beyond the 8x8 window are ignored; unset cells
   read as Empty. *)
let of_grid (rows : string list) : board =
  let bindings = ref [] in
  List.iteri
    (fun y row ->
      if y < default_height then
        String.iteri
          (fun x c ->
            if x < default_width then
              bindings := ({ x; y }, gem_of_char c) :: !bindings)
          row)
    rows;
  create_board ~width:default_width ~height:default_height !bindings

let gems_left (b : board) : int =
  let n = ref 0 in
  for y = 0 to b.height - 1 do
    for x = 0 to b.width - 1 do
      if get_gem b { x; y } <> Empty then incr n
    done
  done;
  !n

let is_cleared (b : board) : bool = gems_left b = 0

let status_of (b : board) : status =
  if is_cleared b then Won
  else if find_all_legal_moves b = [] then Lost
  else Playing

(* Clear every match on the board and drop, repeat: battle's resolve+gravity
   without the refill. Wildcard spawns from 5+ matches stay - they are part of
   the match rules, not the refill. *)
let rec settle (b : board) : board =
  match resolve_matches b with
  | None -> b
  | Some (b', _) -> settle (apply_gravity b')

let create (rows : string list) : t =
  let board = of_grid rows in
  { board; status = status_of board }

(* A swap on a finished attempt is rejected: [CAPTURE_FAIL] keeps the attempt
   over but retryable as a fresh one. Returns None when the swap is not legal
   (out of range, touches Empty, or makes no match). *)
let play (t : t) (sw : swap) : t option =
  match t.status with
  | Won | Lost -> None
  | Playing ->
    if not (is_valid_swap t.board sw.from_pos sw.to_pos) then None
    else
      let b = settle (swap_gems t.board sw.from_pos sw.to_pos) in
      Some { board = b; status = status_of b }

(* Greedy test driver: first legal move until the attempt ends. Every move
   clears at least three gems and spawns at most one wildcard, so the grid
   strictly shrinks and this terminates. *)
let auto_play (t : t) : t =
  let rec go t =
    match t.status with
    | Won | Lost -> t
    | Playing ->
      match find_all_legal_moves t.board with
      | [] -> { t with status = Lost }
      | sw :: _ -> (
          match play t sw with
          | Some t' -> go t'
          | None -> { t with status = Lost })
  in
  go t
