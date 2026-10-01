(** Pure OCaml Match-3 Simulation Engine for Puzzle Quest: Challenge of the Warlords
    Clean-room implementation matching decompiled CBoard / CBattleManager mechanics.
*)

type mana_element =
  | Air
  | Earth
  | Fire
  | Water

type gem =
  | Empty
  | Mana of mana_element
  | Skull
  | RedSkull
  | Gold
  | Experience
  | Wildcard of int  (** Multiplier: 2, 3, 4, 5, etc. Matches any mana element *)

type position = { x : int; y : int }

type direction =
  | Up
  | Down
  | Left
  | Right

type swap = {
  from_pos : position;
  to_pos : position;
}

type match_result = {
  gems_cleared : (position * gem) list;
  air_mana : int;
  earth_mana : int;
  fire_mana : int;
  water_mana : int;
  gold : int;
  xp : int;
  damage : int;
  extra_turn : bool;
  wildcards_created : (position * int) list;
}

type board = {
  width : int;
  height : int;
  grid : gem array array;  (** grid.(y).(x) *)
}

(** Board dimensions (Standard Puzzle Quest is 8x8) *)
let default_width = 8
let default_height = 8

(** Initialize a board from a 2D array *)
let create_board ?(width = default_width) ?(height = default_height) (grid : gem array array) : board =
  { width; height; grid }

(** Create a deep copy of a board *)
let copy_board (b : board) : board =
  let new_grid = Array.init b.height (fun y -> Array.copy b.grid.(y)) in
  { b with grid = new_grid }

(** Get gem at (x, y) *)
let get_gem (b : board) (p : position) : gem =
  if p.x < 0 || p.x >= b.width || p.y < 0 || p.y >= b.height then Empty
  else b.grid.(p.y).(p.x)

(** Set gem at (x, y) *)
let set_gem (b : board) (p : position) (g : gem) : unit =
  if p.x >= 0 && p.x < b.width && p.y >= 0 && p.y < b.height then
    b.grid.(p.y).(p.x) <- g

(** Gem equality for matching purposes (Wildcards match any elemental mana) *)
let gems_match (g1 : gem) (g2 : gem) : bool =
  match (g1, g2) with
  | Empty, _ | _, Empty -> false
  | Mana m1, Mana m2 -> m1 = m2
  | Skull, Skull -> true
  | RedSkull, RedSkull -> true
  | Skull, RedSkull | RedSkull, Skull -> true  (* Skulls and Red Skulls match together *)
  | Gold, Gold -> true
  | Experience, Experience -> true
  | Wildcard _, Mana _ | Mana _, Wildcard _ -> true
  | Wildcard _, Wildcard _ -> true
  | _ -> false

(** Check if two gems can form a 3-gem combination *)
let match_triple (g1 : gem) (g2 : gem) (g3 : gem) : bool =
  if g1 = Empty || g2 = Empty || g3 = Empty then false
  else
    (* If any non-mana gems are involved, they must all be matching skulls/coins/stars *)
    match (g1, g2, g3) with
    | Skull, Skull, Skull
    | RedSkull, RedSkull, RedSkull
    | Skull, Skull, RedSkull
    | Skull, RedSkull, Skull
    | RedSkull, Skull, Skull
    | RedSkull, RedSkull, Skull
    | RedSkull, Skull, RedSkull
    | Skull, RedSkull, RedSkull -> true
    | Gold, Gold, Gold -> true
    | Experience, Experience, Experience -> true
    | _ ->
        (* Check if they can be unified to a single mana element *)
        let element_of = function
          | Mana m -> Some m
          | Wildcard _ -> None
          | _ -> None
        in
        let elems = List.filter_map element_of [g1; g2; g3] in
        match elems with
        | [] -> (* All 3 are wildcards *) true
        | e :: rest ->
            List.for_all (( = ) e) rest
            && (match g1 with Mana _ | Wildcard _ -> true | _ -> false)
            && (match g2 with Mana _ | Wildcard _ -> true | _ -> false)
            && (match g3 with Mana _ | Wildcard _ -> true | _ -> false)

(** Find all matches on the board (horizontal and vertical runs >= 3) *)
let find_matches (b : board) : (position list * gem) list =
  let matches = ref [] in

  (* Horizontal scans *)
  for y = 0 to b.height - 1 do
    let x = ref 0 in
    while !x < b.width - 2 do
      let g1 = b.grid.(y).(!x) in
      let g2 = b.grid.(y).(!x + 1) in
      let g3 = b.grid.(y).(!x + 2) in
      if match_triple g1 g2 g3 then begin
        let run_len = ref 3 in
        while !x + !run_len < b.width && match_triple g1 g2 b.grid.(y).(!x + !run_len) do
          incr run_len
        done;
        let coords = List.init !run_len (fun i -> { x = !x + i; y }) in
        matches := (coords, g1) :: !matches;
        x := !x + !run_len
      end else
        incr x
    done
  done;

  (* Vertical scans *)
  for x = 0 to b.width - 1 do
    let y = ref 0 in
    while !y < b.height - 2 do
      let g1 = b.grid.(!y).(x) in
      let g2 = b.grid.(!y + 1).(x) in
      let g3 = b.grid.(!y + 2).(x) in
      if match_triple g1 g2 g3 then begin
        let run_len = ref 3 in
        while !y + !run_len < b.height && match_triple g1 g2 b.grid.(!y + !run_len).(x) do
          incr run_len
        done;
        let coords = List.init !run_len (fun i -> { x; y = !y + i }) in
        matches := (coords, g1) :: !matches;
        y := !y + !run_len
      end else
        incr y
    done
  done;

  !matches

(** Check if a swap between two adjacent positions is legal *)
let is_valid_swap (b : board) (p1 : position) (p2 : position) : bool =
  let dx = abs (p1.x - p2.x) in
  let dy = abs (p1.y - p2.y) in
  if (dx = 1 && dy = 0) || (dx = 0 && dy = 1) then begin
    let g1 = get_gem b p1 in
    let g2 = get_gem b p2 in
    if g1 = Empty || g2 = Empty then false
    else begin
      (* Perform temporary swap on copy *)
      let temp_board = copy_board b in
      set_gem temp_board p1 g2;
      set_gem temp_board p2 g1;
      let matches = find_matches temp_board in
      List.exists
        (fun (coords, _) ->
          List.exists (fun p -> p = p1 || p = p2) coords)
        matches
    end
  end else
    false

(** Find all possible legal moves on the current board *)
let find_all_legal_moves (b : board) : swap list =
  let moves = ref [] in
  (* Horizontal swaps *)
  for y = 0 to b.height - 1 do
    for x = 0 to b.width - 2 do
      let p1 = { x; y } in
      let p2 = { x = x + 1; y } in
      if is_valid_swap b p1 p2 then
        moves := { from_pos = p1; to_pos = p2 } :: !moves
    done
  done;
  (* Vertical swaps *)
  for y = 0 to b.height - 2 do
    for x = 0 to b.width - 1 do
      let p1 = { x; y } in
      let p2 = { x; y = y + 1 } in
      if is_valid_swap b p1 p2 then
        moves := { from_pos = p1; to_pos = p2 } :: !moves
    done
  done;
  List.rev !moves

(** Resolve matched gems, compute rewards, damage, extra turns, and wildcard creation *)
let resolve_matches (b : board) : match_result option =
  let raw_matches = find_matches b in
  if raw_matches = [] then None
  else
    let air = ref 0 in
    let earth = ref 0 in
    let fire = ref 0 in
    let water = ref 0 in
    let gold_res = ref 0 in
    let xp_res = ref 0 in
    let dmg = ref 0 in
    let extra_turn = ref false in
    let wildcards = ref [] in
    let to_clear = Hashtbl.create 64 in

    List.iter
      (fun (coords, _sample_gem) ->
        let count = List.length coords in
        if count >= 4 then extra_turn := true;

        (* 5-match generates a Wildcard at the center of the match *)
        if count >= 5 then begin
          let mid_pos = List.nth coords (count / 2) in
          let multiplier = min 8 count in
          wildcards := (mid_pos, multiplier) :: !wildcards
        end;

        (* Calculate match rewards *)
        List.iter
          (fun p ->
            let g = get_gem b p in
            Hashtbl.replace to_clear p g;
            match g with
            | Mana Air -> incr air
            | Mana Earth -> incr earth
            | Mana Fire -> incr fire
            | Mana Water -> incr water
            | Skull -> dmg := !dmg + 1
            | RedSkull -> dmg := !dmg + 5
            | Gold -> incr gold_res
            | Experience -> incr xp_res
            | Wildcard mult ->
                (* Wildcard applies multiplier to mana *)
                air := !air * mult;
                earth := !earth * mult;
                fire := !fire * mult;
                water := !water * mult
            | Empty -> ())
          coords)
      raw_matches;

    (* Clear matched cells on board *)
    let cleared_list =
      Hashtbl.fold
        (fun p g acc ->
          set_gem b p Empty;
          (p, g) :: acc)
        to_clear []
    in

    (* Place newly created wildcards *)
    List.iter
      (fun (p, mult) -> set_gem b p (Wildcard mult))
      !wildcards;

    Some
      {
        gems_cleared = cleared_list;
        air_mana = !air;
        earth_mana = !earth;
        fire_mana = !fire;
        water_mana = !water;
        gold = !gold_res;
        xp = !xp_res;
        damage = !dmg;
        extra_turn = !extra_turn;
        wildcards_created = !wildcards;
      }

(** Apply gravity: shift gems down into Empty cells *)
let apply_gravity (b : board) : unit =
  for x = 0 to b.width - 1 do
    let write_y = ref (b.height - 1) in
    for y = b.height - 1 downto 0 do
      let g = b.grid.(y).(x) in
      if g <> Empty then begin
        if !write_y <> y then begin
          b.grid.(!write_y).(x) <- g;
          b.grid.(y).(x) <- Empty
        end;
        decr write_y
      end
    done
  done

(** Fill empty top cells with newly spawned random gems *)
let refill_board ?(rng = Random.int) (b : board) : unit =
  let random_gem () =
    match rng 7 with
    | 0 -> Mana Air
    | 1 -> Mana Earth
    | 2 -> Mana Fire
    | 3 -> Mana Water
    | 4 -> Skull
    | 5 -> Gold
    | _ -> Experience
  in
  for y = 0 to b.height - 1 do
    for x = 0 to b.width - 1 do
      if b.grid.(y).(x) = Empty then
        b.grid.(y).(x) <- random_gem ()
    done
  done

(** Full cascade step: clears matches, drops gravity, and refills until stable *)
let cascade_step (b : board) : match_result list =
  let all_results = ref [] in
  let finished = ref false in
  while not !finished do
    match resolve_matches b with
    | None -> finished := true
    | Some res ->
        all_results := res :: !all_results;
        apply_gravity b;
        refill_board b
  done;
  List.rev !all_results

(** ASCII board visualization *)
let string_of_gem = function
  | Empty -> " . "
  | Mana Air -> " A "
  | Mana Earth -> " E "
  | Mana Fire -> " F "
  | Mana Water -> " W "
  | Skull -> " S "
  | RedSkull -> " R "
  | Gold -> " G "
  | Experience -> " X "
  | Wildcard m -> Printf.sprintf "*%d*" (min 9 m)

let print_board (b : board) : unit =
  Printf.printf "    0   1   2   3   4   5   6   7\n";
  Printf.printf "  +---+---+---+---+---+---+---+---+\n";
  for y = 0 to b.height - 1 do
    Printf.printf "%d |" y;
    for x = 0 to b.width - 1 do
      Printf.printf "%s|" (string_of_gem b.grid.(y).(x))
    done;
    Printf.printf "\n  +---+---+---+---+---+---+---+---+\n"
  done
