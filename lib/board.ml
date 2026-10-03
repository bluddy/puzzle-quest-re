(** Pure Functional Match-3 Simulation Engine for Puzzle Quest: Challenge of the Warlords
    Implemented using immutable persistent maps (PosMap).
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

module Position = struct
  type t = position
  let compare p1 p2 =
    let c = Int.compare p1.y p2.y in
    if c <> 0 then c else Int.compare p1.x p2.x
end

module PosMap = Map.Make(Position)

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
  heroic_effort : bool;
  (** The matched runs exactly as [find_matches] grouped them, before the Red
      Skull explosion sweep pulls in neighbouring gems. The battle loop needs
      the groupings rather than the totals: mana yield and the extra turn roll
      are per element per {e run}, so a 4-run of skulls followed by a 3-run of
      fire is two independent rolls, not one roll over a bag of gems. *)
  runs : (position list * gem) list;
}

type board = {
  width : int;
  height : int;
  grid : gem PosMap.t;
}

let default_width = 8
let default_height = 8

(** Get gem at position; out-of-bounds or unset defaults to Empty *)
let get_gem (b : board) (p : position) : gem =
  if p.x < 0 || p.x >= b.width || p.y < 0 || p.y >= b.height then Empty
  else
    match PosMap.find_opt p b.grid with
    | Some g -> g
    | None -> Empty

(** Set gem at position (pure functional: returns new board) *)
let set_gem (p : position) (g : gem) (b : board) : board =
  if p.x < 0 || p.x >= b.width || p.y < 0 || p.y >= b.height then b
  else { b with grid = PosMap.add p g b.grid }

(** Create a board from a list of ((x, y), gem) bindings *)
let create_board ?(width = default_width) ?(height = default_height) (bindings : (position * gem) list) : board =
  let m = List.fold_left (fun acc (p, g) -> PosMap.add p g acc) PosMap.empty bindings in
  { width; height; grid = m }

(** Create a board from a 2D array representation *)
let of_array_matrix ?(width = default_width) ?(height = default_height) (matrix : gem array array) : board =
  let bindings = ref [] in
  for y = 0 to height - 1 do
    for x = 0 to width - 1 do
      bindings := ({ x; y }, matrix.(y).(x)) :: !bindings
    done
  done;
  create_board ~width ~height !bindings

(** Swap two gems purely functionally *)
let swap_gems (b : board) (p1 : position) (p2 : position) : board =
  let g1 = get_gem b p1 in
  let g2 = get_gem b p2 in
  b |> set_gem p1 g2 |> set_gem p2 g1

(** Gem matching rules (Wildcards substitute for any elemental mana) *)
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

(** Check if three gems form a valid 3-match *)
let match_triple (g1 : gem) (g2 : gem) (g3 : gem) : bool =
  if g1 = Empty || g2 = Empty || g3 = Empty then false
  else
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
        let is_mana_or_wildcard = function
          | Mana _ | Wildcard _ -> true
          | _ -> false
        in
        if is_mana_or_wildcard g1 && is_mana_or_wildcard g2 && is_mana_or_wildcard g3 then
          let element_of = function
            | Mana m -> Some m
            | _ -> None
          in
          let elems = List.filter_map element_of [g1; g2; g3] in
          match elems with
          | [] -> true  (* All 3 are wildcards *)
          | e :: rest -> List.for_all (( = ) e) rest
        else
          false

(** Find all matches (runs >= 3) on the board *)
let find_matches (b : board) : (position list * gem) list =
  let matches = ref [] in

  (* Horizontal scans *)
  for y = 0 to b.height - 1 do
    let x = ref 0 in
    while !x < b.width - 2 do
      let g1 = get_gem b { x = !x; y } in
      let g2 = get_gem b { x = !x + 1; y } in
      let g3 = get_gem b { x = !x + 2; y } in
      if match_triple g1 g2 g3 then begin
        let run_len = ref 3 in
        while !x + !run_len < b.width && match_triple g1 g2 (get_gem b { x = !x + !run_len; y }) do
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
      let g1 = get_gem b { x; y = !y } in
      let g2 = get_gem b { x; y = !y + 1 } in
      let g3 = get_gem b { x; y = !y + 2 } in
      if match_triple g1 g2 g3 then begin
        let run_len = ref 3 in
        while !y + !run_len < b.height && match_triple g1 g2 (get_gem b { x; y = !y + !run_len }) do
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
      let swapped_board = swap_gems b p1 p2 in
      let matches = find_matches swapped_board in
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

(** Check if Mana Burn condition is reached (0 legal moves available) *)
let is_mana_burn (b : board) : bool =
  find_all_legal_moves b = []

(** Resolve matches: clears matched gems, calculates rewards, spawns wildcards.
    Returns (new_board, match_result) or None if no matches. *)
let resolve_matches (b : board) : (board * match_result) option =
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
    let to_explode = Queue.create () in

    List.iter
      (fun (coords, _sample_gem) ->
        let count = List.length coords in
        if count >= 4 then extra_turn := true;

        if count >= 5 then begin
          let mid_pos = List.nth coords (count / 2) in
          let multiplier = min 8 count in
          wildcards := (mid_pos, multiplier) :: !wildcards
        end;

        List.iter
          (fun p ->
            let g = get_gem b p in
            if not (Hashtbl.mem to_clear p) then begin
              Hashtbl.replace to_clear p g;
              if g = RedSkull then Queue.push p to_explode
            end)
          coords)
      raw_matches;

    (* Process Red Skull radius 1 explosions (3x3 area), harvesting all benefits *)
    while not (Queue.is_empty to_explode) do
      let center = Queue.pop to_explode in
      for dy = -1 to 1 do
        for dx = -1 to 1 do
          let p = { x = center.x + dx; y = center.y + dy } in
          if p.x >= 0 && p.x < b.width && p.y >= 0 && p.y < b.height then
            if not (Hashtbl.mem to_clear p) then begin
              let g = get_gem b p in
              if g <> Empty then begin
                Hashtbl.replace to_clear p g;
                if g = RedSkull then Queue.push p to_explode
              end
            end
        done
      done
    done;

    (* Harvest all benefits (damage, mana, gold, xp) from cleared & exploded tiles *)
    Hashtbl.iter
      (fun _ g ->
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
            air := !air * mult;
            earth := !earth * mult;
            fire := !fire * mult;
            water := !water * mult
        | Empty -> ())
      to_clear;

    (* Build new board with cleared gems set to Empty *)
    let b_after_clear =
      Hashtbl.fold
        (fun p _ acc_b -> set_gem p Empty acc_b)
        to_clear b
    in

    (* Place newly created wildcards *)
    let b_after_wildcards =
      List.fold_left
        (fun acc_b (p, mult) -> set_gem p (Wildcard mult) acc_b)
        b_after_clear !wildcards
    in

    let cleared_list =
      Hashtbl.fold (fun p g acc -> (p, g) :: acc) to_clear []
    in

    Some
      ( b_after_wildcards,
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
          heroic_effort = false;
          runs = raw_matches;
        } )

(** Pure functional gravity: drops gems down into Empty spaces column by column *)
let apply_gravity (b : board) : board =
  let new_grid = ref b.grid in
  for x = 0 to b.width - 1 do
    (* Collect all non-empty gems in column from top to bottom into a stack;
       head of the stack will be the bottom-most gem *)
    let non_empty = ref [] in
    for y = 0 to b.height - 1 do
      let p = { x; y } in
      let g = get_gem b p in
      if g <> Empty then non_empty := g :: !non_empty
    done;
    (* Place non-empty gems starting at bottom *)
    let curr_gems = ref !non_empty in
    for y = b.height - 1 downto 0 do
      let p = { x; y } in
      match !curr_gems with
      | g :: rest ->
          new_grid := PosMap.add p g !new_grid;
          curr_gems := rest
      | [] ->
          new_grid := PosMap.add p Empty !new_grid
    done
  done;
  { b with grid = !new_grid }

(** Pure functional refill: fills Empty cells with newly spawned random gems *)
let refill_board ?(rng = Random.int) (b : board) : board =
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
  let grid = ref b.grid in
  for y = 0 to b.height - 1 do
    for x = 0 to b.width - 1 do
      let p = { x; y } in
      if get_gem b p = Empty then
        grid := PosMap.add p (random_gem ()) !grid
    done
  done;
  { b with grid = !grid }

(** Whether any single swap can produce a run of three or more.

    This is a stricter test than [Ai.evaluate_board], which deliberately probes
    only a clipped window and so misses some legal moves. That is fine for the
    AI, whose probe windows are a recovered quirk, but wrong for deciding whether
    a board is playable: mana burn has to guarantee the player has something to
    do, and the AI's answer is not the ground truth on that. Hence the separate
    exhaustive check rather than calling into [Ai], which also keeps [board] below
    [ai] in the dependency order. *)
let has_valid_move (b : board) : bool =
  let makes_match b = match resolve_matches b with None -> false | Some _ -> true in
  let found = ref false in
  let y = ref 0 in
  while (not !found) && !y < b.height do
    let x = ref 0 in
    while (not !found) && !x < b.width do
      if !x < b.width - 1 then begin
        let p = { x = !x; y = !y } and q = { x = !x + 1; y = !y } in
        if makes_match (swap_gems b p q) then found := true
      end;
      if (not !found) && !y < b.height - 1 then begin
        let p = { x = !x; y = !y } and q = { x = !x; y = !y + 1 } in
        if makes_match (swap_gems b p q) then found := true
      end;
      incr x
    done;
    incr y
  done;
  !found

(** Mana Burn: regenerates the whole board, retrying until it is playable.

    The original's [FUN_0047ADB0] clears the entire 9x8 grid before the refill, so
    a burn replaces the gems rather than permuting them in place. That matters
    for correctness, not just fidelity: a permute-in-place version is a no-op
    when there is nothing to permute, and a board regenerated by [refill_board]
    has no [Empty] cells to fill, so a burn on a full board would change nothing
    and the battle would burn on every turn forever.

    [attempts] bounds the retry. A fresh random board is almost always playable,
    and [has_valid_move] is a full sweep, so this converges immediately in
    practice; the bound is there so a pathological rng cannot hang a battle. The
    last board generated is returned either way. *)
let reshuffle ?(rng = Random.int) ?(attempts = 20) (b : board) : board =
  let rec go remaining =
    let cleared =
      { b with grid = PosMap.empty }
    in
    let filled = refill_board ~rng cleared in
    if has_valid_move filled || remaining <= 0 then filled else go (remaining - 1)
  in
  go attempts

(** Pure functional cascade: resolves matches, applies gravity, refills until quiescent.
    If chain reaction reaches >= 5 steps, awards a Heroic Effort (+100 XP & Extra Turn). *)
let cascade_step ?(rng = Random.int) (initial_b : board) : board * match_result list =
  let rec loop b acc =
    match resolve_matches b with
    | None ->
        let results = List.rev acc in
        let chain_len = List.length results in
        if chain_len >= 5 then
          (* Heroic Effort triggered! Awards +100 XP and an extra turn *)
          let updated_results =
            match List.rev results with
            | [] -> []
            | last :: rest_rev ->
                let heroic_last =
                  {
                    last with
                    xp = last.xp + 100;
                    extra_turn = true;
                    heroic_effort = true;
                  }
                in
                List.rev (heroic_last :: rest_rev)
          in
          (b, updated_results)
        else
          (b, results)
    | Some (b_cleared, res) ->
        let b_dropped = apply_gravity b_cleared in
        let b_refilled = refill_board ~rng b_dropped in
        loop b_refilled (res :: acc)
  in
  loop initial_b []

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
      Printf.printf "%s|" (string_of_gem (get_gem b { x; y }))
    done;
    Printf.printf "\n  +---+---+---+---+---+---+---+---+\n"
  done

(** Structural equality on gems, for the sweeps in [Spell_effects] that compare a
    cell against a kind. Written out rather than using [Stdlib.( = )] because the
    gem type carries an empty case that is not a variant of its own, and because
    naming the comparison keeps the sweeps readable. *)
let equal_gem (a : gem) (b : gem) : bool = a = b