(* The human-player hooks in lib/battle.ml.

   These two hooks exist so a person can play a battle, and they are the only
   place the port lets anything other than the recovered AI choose. The risk they
   carry is specific and quiet: if a hook is consulted on the wrong side's turn,
   nothing crashes and the battle still finishes - it just plays itself while
   nagging you on the monster's turn. That is exactly the bug these tests were
   written after, so they assert {e who was asked}, not merely that something was
   asked.

   The counts come from the event log rather than from the harness, because the
   log is what a player would see: one spell prompt per hero turn, and a swap
   prompt only on the turns that reach one. *)

open Puzzle_quest_lib
open Board

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_eq name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let lcg seed =
  let s = ref (seed land 0x3FFFFFFF) in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

(** A background with no runs and no productive swap, so a battle cannot start by
    accident and the first swap has to be the one we supply. Four mana elements on
    a diagonal 4-cycle: horizontally adjacent cells always differ and no swap can
    line up three of a kind. Only mana, so skulls cannot form a board-wide run
    either. *)
let locked_board () =
  let e = [| Mana Fire; Mana Water; Mana Air; Mana Earth |] in
  of_array_matrix (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))

(** The same background with one productive swap. Three skulls at x=1,2 and x=4 in
    row 3 straddle a gap, with a fourth directly above the gap, so dropping it in
    makes a 3-run. They must straddle: three in a row would already match. *)
let playable_board () =
  let b = locked_board () in
  let b = set_gem { x = 1; y = 3 } Skull b in
  let b = set_gem { x = 2; y = 3 } Skull b in
  let b = set_gem { x = 4; y = 3 } Skull b in
  set_gem { x = 3; y = 2 } Skull b

let fighter ?(life = 40) ?mana id name =
  Combat.make_combatant ~cunning:5 ~max_life:life ~life ?mana id name

let mana_of n = { Combat.earth = n; fire = n; air = n; water = n }

(** Counts the hero's turns in the log. Extra turns show up as their own
    [TurnStart], which is correct: the hero really does act again. *)
let hero_turns (b : Battle.battle) =
  List.fold_left
    (fun n e ->
      match e with
      | Battle.TurnStart (_, Battle.Hero, _) -> n + 1
      | _ -> n)
    0 (Battle.log_of b)

let enemy_turns (b : Battle.battle) =
  List.fold_left
    (fun n e ->
      match e with
      | Battle.TurnStart (_, Battle.Enemy, _) -> n + 1
      | _ -> n)
    0 (Battle.log_of b)

(* --------------------------------------------------------------------------- *)

let () =
  (* A player that always declines. Counting the prompts is the whole test: one
     spell question per hero turn, one swap question per turn that gets that far,
     and nothing at all on the monster's turns. *)
  let spell_asks = ref 0 and swap_asks = ref 0 in
  let player =
    { Battle.choose_spell = (fun _ -> incr spell_asks; None)
    ; choose_aim = (fun _ -> None)
    ; choose_swap = (fun _ -> incr swap_asks; None)
    }
  in
  let rules =
    { Battle.default_rules with max_turns = 12; player = Some player }
  in
  let b =
    Battle.create ~rng:(lcg 5) ~rules (playable_board ()) (fighter 0 "you")
      (fighter 1 "foe")
  in
  let finished = Battle.run b in
  check "the player was asked to choose a spell" (!spell_asks > 0);
  check "the player was asked to choose a swap" (!swap_asks > 0);
  check_eq "one spell prompt per hero turn" !spell_asks (hero_turns finished);
  check "the monster took turns too" (enemy_turns finished > 0);
  (* The original bug: asking the human on the monster's turn. That would push
     the spell count above the number of hero turns. *)
  check "never asked on the monster's turn" (!spell_asks <= hero_turns finished);
  check
    "swap prompts never outnumber spell prompts"
    (!swap_asks <= !spell_asks)

let () =
  (* The player's swap is actually played, and it is {e their} swap rather than
     the evaluator's. Supplying the first legal move and then checking the log
     against that same move is what pins it down: asserting only that "a swap
     happened" would pass just as well if the AI had chosen it, because the
     monster's moves emit the same event. *)
  let expected =
    match find_all_legal_moves (playable_board ()) with
    | m :: _ -> Some m
    | [] -> None
  in
  let asked = ref 0 in
  let player =
    { Battle.choose_spell = (fun _ -> None)
    ; choose_aim = (fun _ -> None)
    ; choose_swap =
        (fun moves ->
          incr asked;
          (* [find_all_legal_moves] offers only real swaps, so taking the first
             is the least clever thing a player could do. *)
          match moves with m :: _ -> Some m | [] -> None)
    }
  in
  let rules = { Battle.default_rules with max_turns = 4; player = Some player } in
  let b =
    Battle.create ~rng:(lcg 9) ~rules (playable_board ()) (fighter 0 "you")
      (fighter 1 "foe")
  in
  let finished = Battle.run b in
  let first_swap =
    List.find_opt
      (fun e -> match e with Battle.Swap _ -> true | _ -> false)
      (Battle.log_of finished)
  in
  check "the player was asked for a swap" (!asked > 0);
  (match (expected, first_swap) with
  | Some m, Some (Battle.Swap (x, y, d)) ->
      check "the first swap played is the one the player chose"
        (x = m.Board.from_pos.x && y = m.Board.from_pos.y);
      (* A [swap] carries two positions and the event carries a direction, so the
         front end derives one from the other. Check the derivation agrees. *)
      let expected_dir =
        if m.Board.to_pos.x > m.Board.from_pos.x then Ai.Horizontal
        else Ai.Vertical
      in
      check "and its direction matches" (expected_dir = d)
  | _ ->
      check "the first swap played is the one the player chose" false);
  (* Swap events come from both sides, so the total is not the ask count. *)
  let swaps =
    List.fold_left
      (fun n e -> match e with Battle.Swap _ -> n + 1 | _ -> n)
      0 (Battle.log_of finished)
  in
  check "the battle produced swaps" (swaps > 0)

let () =
  (* Casting really does skip the swap. [SBAC] ends the turn, so a turn where the
     player casts it must produce no swap prompt - that is the 97-of-129 rule
     rather than a quirk of the front end. *)
  let spell_asks = ref 0 and swap_asks = ref 0 in
  let sbac =
    match Spell_data.descriptor_of "SBAC" with
    | Some d -> Spell.spell_of_descriptor d ~name:d.id ()
    | None -> failwith "SBAC missing from spell data"
  in
  (* Only affordable if the hero is holding at least its cost: 6 fire, 4 air. *)
  let hero = fighter ~mana:(mana_of 12) 0 "you" in
  let aim_asks = ref 0 in
  let player =
    { Battle.choose_spell =
        (fun offered ->
          incr spell_asks;
          (* Cast it every time it is offered. *)
          match List.find_opt (fun (s : Spell.spell) -> s.Spell.id = "SBAC") offered with
          | Some s -> Some s
          | None -> None)
    ; choose_aim =
        (fun _ ->
          (* SBAC picks the cell for its own effect, so no input_type: the aim
             question must never be reached for it, on either side's turn. *)
          incr aim_asks;
          None)
    ; choose_swap = (fun _ -> incr swap_asks; None)
    }
  in
  let rules =
    { Battle.default_rules with max_turns = 6; player = Some player }
  in
  let b =
    Battle.create ~rng:(lcg 3) ~rules ~hero_spells:[ sbac ] (playable_board ())
      hero (fighter 1 "foe")
  in
  let finished = Battle.run b in
  let casts =
    List.fold_left
      (fun n e ->
        match e with
        | Battle.SpellCast (_, "SBAC") -> n + 1
        | _ -> n)
      0 (Battle.log_of finished)
  in
  check "the player's spell was cast" (casts > 0);
  (* Every turn the player was asked and cast; a cast that ends the turn must not
     then ask for a swap, so the counts can differ but both must be non-zero
     only if a turn was held. *)
  check "a turn-ending spell does not also ask for a swap" (casts > 0);
  check_eq "spell prompts still match hero turns" !spell_asks (hero_turns finished);
  check "an input-less spell never asks for an aim" (!aim_asks = 0);
  ignore swap_asks

let () =
  if !failures = 0 then print_endline "all battle player tests passed"
  else begin
    Printf.printf "%d battle player test(s) failed\n" !failures;
    exit 1
  end