(** End-of-battle score, recovered from [FUN_0043DA90] (0x0043DA90).

    This is the score shown on the post-battle results screen, not a damage
    formula. It reads the same [m_difficulty] field that drives the AI's move
    selection, which is what made it look like one. See
    docs/BATTLE_SCORE.md for the annotated disassembly and a confidence table
    on the parts that are not fully pinned down. *)

(** A character as the score function reads it. Only the three fields it
    actually touches are modelled; [level] is [CCharacter+0x68] and
    [power] stands in for the unidentified [vfunc+0x24]. *)
type character = {
  max_life : int;  (** +0x64 *)
  level : int;  (** +0x68 *)
  current_life : int;  (** +0x70 *)
  power : int;  (** vfunc+0x24, unidentified; scaled by 100 *)
}

(** Inputs the score function pulls from the turn manager singleton at
    0x005829B8, plus the two switches that select a path through it. *)
type inputs = {
  difficulty : int;  (** 0 easy, 1 normal, 2+ unscaled *)
  game_mode : int;  (** 4 selects the reduced-value multipliers *)
  turns : int;  (** turn manager +0x34 *)
  co_op_contributors : int;  (** turn manager +0x2C, co-op path only *)
  co_op : bool;  (** selects the co-op branch *)
}

let clamp score = if score < 1 then 1 else if score > 50000 then 50000 else score

(** Signed truncating division by 3, matching the [IMUL] by 0x55555556 the
    compiler emits for the difficulty scaling. OCaml's [/] already truncates
    toward zero, so this is just the division made explicit. *)
let div3 n = n / 3

(** Difficulty scaling for the solo/co-op score path: easy scores a third,
    normal two thirds, hard is unscaled. Skipped entirely in game mode 4. *)
let scale_by_difficulty ~game_mode ~difficulty score =
  if game_mode = 4 then score
  else if difficulty = 0 then div3 score
  else if difficulty = 1 then (score * 2) / 3
  else score

(** The flat level-difference nudge from the co-op loop. A single level of
    difference is worth +/-150 whatever the magnitude, which the compiler
    spells as a pair of SETGE/SETLE plus mask idioms at 0x43DC21 rather than a
    multiply. Exposed so it can be tested directly instead of inferred
    through the linear terms. *)
let level_step level_delta =
  if level_delta > 0 then 150 else if level_delta < 0 then -150 else 0

(** [FUN_0043DA90]. [hero_index] selects the hero; [roster] is the full
    character list, and every other member contributes to a co-op score.

    The solo path is fully recovered. The co-op path carries two
    unresolved pieces, both flagged in docs/BATTLE_SCORE.md: the meaning of
    [character.power], and the loop guard that decides which party members
    contribute. {!party_member_contributes} is the hook for the latter. *)
let compute_score ?(party_member_contributes = fun _ _ -> true) ~inputs ~hero_index
    (roster : character list) : int =
  let hero = List.nth roster hero_index in
  (* Game mode 4 divides the level term and both 100-multiples by ten. The
     flat 150 step is not affected. *)
  let level_scale = if inputs.game_mode = 4 then 25 else 250 in
  let hundred_scale = if inputs.game_mode = 4 then 10 else 100 in
  if not inputs.co_op then
    (* (turns + 20) * 25 - max_life + current_life, floored at 1. No
       difficulty scaling and no 50 000 cap on this path. *)
    let score = ((inputs.turns + 20) * 25) - hero.max_life + hero.current_life in
    if score < 1 then 1 else score
  else
    let base =
      ((inputs.turns + 10) * 250)
      + ((hero.current_life - hero.max_life) * 4)
      - (inputs.co_op_contributors * 15)
    in
    let step_term = level_step in
    let contribution other =
      let level_delta = other.level - hero.level in
      let life_delta = other.max_life - hero.max_life in
      (life_delta * 3)
      + (level_delta * level_scale)
      + step_term level_delta
      + (other.power * hundred_scale)
      + (other.level * hundred_scale)
    in
    let total =
      List.mapi (fun i other -> (i, other)) roster
      |> List.fold_left
           (fun acc (i, other) ->
             if i <> hero_index && party_member_contributes i other then
               acc + contribution other
             else acc)
           base
    in
    clamp (scale_by_difficulty ~game_mode:inputs.game_mode ~difficulty:inputs.difficulty total)

(** [FUN_0043E400], the co-op counterpart, applied to one of its two
    out-parameters.

    The caller applies a [turns * 5] percent bonus first, so [raw] here is
    the post-bonus value.

    Both this and {!compute_score} scale monotonically upward with difficulty;
    neither is inverted. They differ on the baseline: this one treats
    difficulty 1 as unscaled and pays a bonus at 2, while {!compute_score}
    treats 2 and above as unscaled and discounts 0 and 1. So difficulty 1 is
    discounted for the score and untouched for the payout. Unexplained, and
    documented as an open discrepancy in docs/BATTLE_SCORE.md. *)
let compute_co_op_payout ~game_mode ~difficulty raw =
  if game_mode = 4 then raw
  else if difficulty = 0 then (raw * 3) / 4
  else if difficulty = 2 then (raw * 5) / 4
  else raw
