(** Faithful OCaml port of the AI heuristic recovered from
    [CBattleManager::EvaluateBoard] (0x00440C20) and
    [BattleAI_ScoreMatchResult] (0x0043F970).

    Verified against the x86 build; see docs/BATTLE_AI.md for the annotated
    disassembly walkthrough. *)

open Board

(** The engine's probe window. Matches caused by a swap can only start at
    offset [-2, +1] along the swap axis and [-2, 0] across it. These four
    tables are the literal contents of .rdata at 0x005212D8..0x00521357,
    read as (dx, dy) pairs. *)
let offsets_after_horizontal_swap_h = [ (-2, 0); (1, 0) ]
let offsets_after_horizontal_swap_v = [ (0, -2); (1, -2); (0, -1); (1, -1); (0, 0); (1, 0) ]
let offsets_after_vertical_swap_h = [ (-2, 0); (-1, 0); (0, 0); (-2, 1); (-1, 1); (0, 1) ]
let offsets_after_vertical_swap_v = [ (0, -2); (0, 1) ]

type direction =
  | Horizontal
  | Vertical

(** Per-resource weights live at CBattleManager+0x04..+0x28 (ten consecutive
    ints, indexed by [resource] below). [0x43F8D0] initialises them all to 1
    and then overwrites seven of them. *)
type weights = {
  w_earth : int;  (** +0x04, default 2 *)
  w_fire : int;   (** +0x08, default 2 *)
  w_water : int;  (** +0x0C, default 2 *)
  w_air : int;    (** +0x10, default 2 *)
  w_skull : int;  (** +0x14, default 10 *)
  w_gold : int;   (** +0x18, default 1 *)
  w_xp : int;     (** +0x1C, default 1 *)
  w_red_skull : int;  (** +0x20, default 20 *)
  w_ice : int;    (** +0x24, default 20 *)
  w_unknown_10 : int; (** +0x28, default 20 *)
}

let default_weights =
  {
    w_earth = 2;
    w_fire = 2;
    w_water = 2;
    w_air = 2;
    w_skull = 10;
    w_gold = 1;
    w_xp = 1;
    w_red_skull = 20;
    w_ice = 20;
    w_unknown_10 = 20;
  }

let gem_id = function
  | Empty -> 0
  | Mana Earth -> 1
  | Mana Fire -> 2
  | Mana Water -> 3
  | Mana Air -> 4
  | Skull -> 5
  | Experience -> 7
  | Gold -> 6
  | RedSkull -> 0xf
  | Wildcard m -> 6 + m

(** Inverse of {!gem_id}, for the ids the board engine can produce. *)
let gem_of_id = function
  | 1 -> Mana Earth
  | 2 -> Mana Fire
  | 3 -> Mana Water
  | 4 -> Mana Air
  | 5 -> Skull
  | 6 -> Gold
  | 7 -> Experience
  | 0xf -> RedSkull
  | m when m >= 8 && m <= 14 -> Wildcard (m - 6)
  | _ -> Empty

(** [0x47AFF0]: does gem [a] participate in a match with gem [b]? *)
let ids_match a b =
  if a = 0 || b = 0 then false
  else if a = b then true
  else if (a = 5 && b = 0xf) || (a = 0xf && b = 5) then true
  else
    let is_mana id = id >= 1 && id <= 4 in
    let is_wildcard id = id >= 8 && id <= 14 in
    (is_wildcard a && is_mana b) || (is_mana a && is_wildcard b)

(** Maximal run length through [(x,y)] in the given direction, matching
    [CBoard::CheckMatch] (0x0047C8C0). Returns 0 for out-of-bounds/empty. *)
let check_match (b : board) (x : int) (y : int) (d : direction) : int =
  if x < 0 || x >= b.width || y < 1 || y > b.height then 0
  else
    let g0 = get_gem b { x; y } in
    if g0 = Empty then 0
    else
      let id0 = gem_id g0 in
      let dx, dy = match d with Horizontal -> (1, 0) | Vertical -> (0, 1) in
      let step sign i = ((x + (sign * dx * i)), (y + (sign * dy * i))) in
      let in_bounds (nx, ny) = nx >= 0 && nx < b.width && ny >= 1 && ny <= b.height in
      let count sign =
        let n = ref 0 in
        let i = ref 1 in
        while !i < 8 && in_bounds (step sign !i) do
          let nx, ny = step sign !i in
          if ids_match id0 (gem_id (get_gem b { x = nx; y = ny })) then incr n else i := 8;
          incr i
        done;
        !n
      in
      1 + count 1 + count (-1)

(** The nine resource buckets the engine accumulates per match, in
    [0x47B0C0] offset order: +0x14, +0x30, +0x4C, +0x68, +0x84, +0xA0,
    +0xBC, +0xD8, +0xF4, +0x110. *)
type match_resources = {
  r_earth : int;
  r_fire : int;
  r_water : int;
  r_air : int;
  r_skull : int;
  r_gold : int;
  r_xp : int;
  r_red_skull : int;
  r_ice : int;
  r_unknown_10 : int;
}

let zero_resources =
  {
    r_earth = 0;
    r_fire = 0;
    r_water = 0;
    r_air = 0;
    r_skull = 0;
    r_gold = 0;
    r_xp = 0;
    r_red_skull = 0;
    r_ice = 0;
    r_unknown_10 = 0;
  }

(** Accumulate the gems of one run into the resource buckets, applying the
    wildcard multiplier chain ([0x47B0C0]: 2,3,4,5,6,7,8 by wildcard id). *)
let accumulate (res : match_resources) (mult : int ref) (b : board) (x : int) (y : int)
    (d : direction) (len : int) : match_resources =
  let dx, dy = match d with Horizontal -> (1, 0) | Vertical -> (0, 1) in
  let step i = (x + (dx * i), y + (dy * i)) in
  let acc =
    List.init len (fun i ->
        let nx, ny = step i in
        gem_id (get_gem b { x = nx; y = ny }))
    |> List.fold_left
         (fun (r : match_resources) id ->
           match id with
           | 1 -> { r with r_earth = r.r_earth + 1 }
           | 2 -> { r with r_fire = r.r_fire + 1 }
           | 3 -> { r with r_water = r.r_water + 1 }
           | 4 -> { r with r_air = r.r_air + 1 }
           | 5 -> { r with r_skull = r.r_skull + 1 }
           | 6 -> { r with r_gold = r.r_gold + 1 }
           | 7 -> { r with r_xp = r.r_xp + 1 }
           | 0xf ->
               (* 0x47B0C0 case 0xf: +5 to the skull bucket, plus a recorded
                  position in the red-skull list. *)
               { r with r_skull = r.r_skull + 5; r_red_skull = r.r_red_skull + 1 }
           | 0x10 -> { r with r_ice = r.r_ice + 1 }
           | 0x11 -> { r with r_unknown_10 = r.r_unknown_10 + 1 }
           | m when m >= 8 && m <= 14 ->
               (* 0x47B0C0: ids 8..14 multiply by 2,3,4,5,6,7,8 *)
               mult := !mult * (m - 6);
               r
            | _ -> r)
         res
  in
  (* The wildcard multiplier is applied to every bucket at the end of
     CheckMatch, not to the wildcards themselves. *)
  if !mult = 1 then acc
  else
    {
      r_earth = acc.r_earth * !mult;
      r_fire = acc.r_fire * !mult;
      r_water = acc.r_water * !mult;
      r_air = acc.r_air * !mult;
      r_skull = acc.r_skull * !mult;
      r_gold = acc.r_gold * !mult;
      r_xp = acc.r_xp * !mult;
      r_red_skull = acc.r_red_skull * !mult;
      r_ice = acc.r_ice * !mult;
      r_unknown_10 = acc.r_unknown_10 * !mult;
    }

(** Hero level, as read by [BattleAI_ScoreMatchResult] from the current
    player's character (short at [CCharacter+0x1C1], with the level cap at
    [+0x1BF]). Both are -1 when no hero is present. *)
type hero_level_info = {
  level : int;  (** < 0 means "no hero", which disables the level band *)
  level_cap : int;
}

let no_hero = { level = -1; level_cap = -1 }

(** The +/- random band the AI adds as a function of hero level, from
    0x43FA7C..0x43FAD4. Returns 0 when the band collapses. *)
let level_jitter_band { level; level_cap } : int =
  if level < 0 then 0
  else if level <= 4 then (5 - level) * 10
  else if level < level_cap / 4 then ((level_cap / 4) - level) * 20 + 30
  else if level < level_cap / 2 then ((level_cap / 2) - level) * 15 + 20
  else
    let t = (level_cap * 3) / 4 in
    if t <= level then 0 else (t - level + 1) * 10

(** [BattleAI_ScoreMatchResult] (0x0043F970).

    {1 base = weighted resource sum + 3*run_length + match.x + 30*(len>3)
     + 30*(len>4); 2 difficulty = AI skill level at CBattleManager+0x48;
    3 jitter = a +/- random band from the difficulty (always at 0, 40% of
    the time at 1, never at 2+) plus a second band scaled by hero level.} *)
let score_match_result ?(weights = default_weights) ?(rng = Random.int)
    ?(difficulty = 0) ?(hero = no_hero) (res : match_resources) (run_length : int)
    (match_x : int) : int =
  let base =
    (res.r_earth * weights.w_earth)
    + (res.r_fire * weights.w_fire)
    + (res.r_water * weights.w_water)
    + (res.r_air * weights.w_air)
    + (res.r_skull * weights.w_skull)
    + (res.r_gold * weights.w_gold)
    + (res.r_xp * weights.w_xp)
    + (res.r_red_skull * weights.w_red_skull)
    + (res.r_ice * weights.w_ice)
    + (res.r_unknown_10 * weights.w_unknown_10)
    + (3 * run_length)
    + match_x
    + (if run_length > 3 then 30 else 0)
    + (if run_length > 4 then 30 else 0)
  in
  (* [Engine_GET_RANDOM_4bd280] takes (min, max) and returns a value in
     that inclusive range. *)
  let rand_between lo hi = if hi <= lo then lo else lo + rng (hi - lo + 1) in
  let with_difficulty =
    if difficulty = 0 then base + rand_between (-50) 50
    else if difficulty = 1 && rng 100 < 40 then base + rand_between (-20) 20
    else base
  in
  (* Difficulty >= 2 skips the hero-level band entirely (0x43FA5A: JGE). *)
  let band = if difficulty >= 2 then 0 else level_jitter_band hero in
  with_difficulty + rand_between (-band) band

type candidate = {
  cand_x : int;
  cand_y : int;
  cand_direction : direction;
  cand_score : int;
}

type evaluation = {
  has_valid_move : bool;
  best : candidate option;
  best_score : int;  (** -10000 when no legal move exists *)
}

let no_move_evaluation = { has_valid_move = false; best = None; best_score = -10000 }

(** The engine's per-swap probe: sum scores over the offset window only.
    Returns [None] when no match is found (i.e. the swap is illegal). *)
let score_swap ?(weights = default_weights) ?(rng = Random.int) ?(difficulty = 0)
    ?(hero = no_hero) (b : board) (x : int) (y : int) (d : direction) :
    candidate option =
  let h_offsets, v_offsets =
    match d with
    | Horizontal ->
        (offsets_after_horizontal_swap_h, offsets_after_horizontal_swap_v)
    | Vertical -> (offsets_after_vertical_swap_h, offsets_after_vertical_swap_v)
  in
  (* Bound checks mirror the two loops in the original: the horizontal window
     is clipped to x in [0,5] and y in [1,8]; the vertical window to
     x in [0,7] and y in [1,6]. *)
  let probe offsets xmin xmax ymin ymax dir =
    List.fold_left
      (fun (total, found) (dx, dy) ->
        let nx = x + dx and ny = y + dy in
        if nx >= xmin && nx <= xmax && ny >= ymin && ny <= ymax then
          let len = check_match b nx ny dir in
          if len >= 3 then begin
            let mult = ref 1 in
            let res = accumulate zero_resources mult b nx ny dir len in
            (total + score_match_result ~weights ~rng ~difficulty ~hero res len nx, true)
          end
          else (total, found)
        else (total, found))
      (0, false) offsets
  in
  let h_total, h_found = probe h_offsets 0 5 1 8 Horizontal in
  let v_total, v_found = probe v_offsets 0 7 1 6 Vertical in
  if not (h_found || v_found) then None
  else
    Some
      {
        cand_x = x;
        cand_y = y;
        cand_direction = d;
        cand_score = h_total + v_total;
      }

(** [CBattleManager::EvaluateBoard] (0x00440C20). Enumerates every adjacent
    pair on the live board, tentatively swaps, scores the resulting matches
    within the probe window, and keeps the highest. Ties keep the first
    candidate encountered, matching the original's strict `<` comparison. *)
let evaluate_board ?(weights = default_weights) ?(rng = Random.int) ?(difficulty = 0)
    ?(hero = no_hero) (b : board) : evaluation =
  let best = ref None in
  let best_score = ref (-10000) in
  let consider x y d =
    let p2 =
      match d with
      | Horizontal -> { x = x + 1; y }
      | Vertical -> { x; y = y + 1 }
    in
    let board_after = swap_gems b { x; y } p2 in
    match score_swap ~weights ~rng ~difficulty ~hero board_after x y d with
    | None -> ()
    | Some c -> if !best_score < c.cand_score then begin
        best_score := c.cand_score;
        best := Some c
      end
  in
  (* Row index 0 is the spawn buffer and is never swapped, matching the
     original's y loop starting at 1. *)
  for y = 1 to b.height do
    for x = 0 to b.width - 1 do
      if x < b.width - 1 then consider x y Horizontal;
      if y < b.height then consider x y Vertical
    done
  done;
  match !best with
  | None -> no_move_evaluation
  | Some c -> { has_valid_move = true; best = Some c; best_score = !best_score }
