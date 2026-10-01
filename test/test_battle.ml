open Puzzle_quest_lib
open Board
open Combat
open Spell
open Battle

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

let check_outcome name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name
      (match got with None -> "unfinished" | Some o -> format_event (BattleEnd o))
      (match want with None -> "unfinished" | Some o -> format_event (BattleEnd o));
    incr failures
  end

(** A deterministic rng: a small linear congruential generator, so tests do
    not depend on Random's implementation. *)
let lcg seed =
  let s = ref seed in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

(** A background with no runs and no productive swap. Four mana elements on a
    diagonal 4-cycle: each row steps by one element, so horizontally adjacent
    cells always differ and no swap can line up three of a kind. Using only
    mana also keeps skulls out of it, since skulls match each other and would
    turn the whole board into one giant run. *)
let locked_board () =
  let e = [| Mana Fire; Mana Water; Mana Air; Mana Earth |] in
  of_array_matrix
    (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))

(** The same background with one productive swap, so a battle can actually
    start. Skulls at x=1,2 and x=4 in row 3 straddle a gap, and a skull sits
    directly above the gap, so dropping it in makes a 3-run. The skulls must
    straddle: three in a row would already be a match before anyone moved. *)
let playable_board () =
  let b = locked_board () in
  let b = set_gem { x = 1; y = 3 } Skull b in
  let b = set_gem { x = 2; y = 3 } Skull b in
  let b = set_gem { x = 4; y = 3 } Skull b in
  set_gem { x = 3; y = 2 } Skull b

let fighter ?(life = 40) ?(cunning = 5) ?mana id name =
  Combat.make_combatant ~cunning ~max_life:life ~life ?mana id name

(* ------------------------------------------------------------------ *)
(* The row-index bridge                                                 *)
(* ------------------------------------------------------------------ *)

let () =
  (* Ai writes against the engine's convention, where row 0 is a spawn buffer
     and rows 1..8 play. The board module uses 0..7 for all eight rows. The
     bridge has to make row 0 of the board visible as row 1 to the AI, or the
     top playable row would be silently unscored. *)
  let b =
    create (locked_board ()) (fighter 0 "hero") (fighter 1 "foe")
  in
  let view = ai_view b in
  check_eq "the AI view is one row taller" view.height 9;
  check "row 0 is the empty spawn buffer" (get_gem view { x = 0; y = 0 } = Empty);
  (* Board row 0 must land on AI row 1. *)
  check "board row 0 becomes AI row 1"
    (get_gem view { x = 3; y = 1 } = get_gem b.board { x = 3; y = 0 });
  check "board row 7 becomes AI row 8"
    (get_gem view { x = 3; y = 8 } = get_gem b.board { x = 3; y = 7 });
  (* And the top row must still be playable, which is the whole point. *)
  let top = Array.init 8 (fun x -> if x < 2 then Mana Fire else Skull) in
  let rows = Array.init 8 (fun _ -> Array.make 8 Skull) in
  rows.(0) <- top;
  let b2 = create (of_array_matrix rows) (fighter 0 "hero") (fighter 1 "foe") in
  check "a match on the top board row is reachable by the AI"
    (Ai.evaluate_board ~rng:(lcg 1) ~difficulty:2 (ai_view b2)).has_valid_move

(* ------------------------------------------------------------------ *)
(* A full battle resolves to a winner                                   *)
(* ------------------------------------------------------------------ *)

let () =
  let b =
    create ~rng:(lcg 42)
      (playable_board ())
      (fighter ~life:60 0 "hero")
      (fighter ~life:60 1 "foe")
  in
  let done_b = run b in
  check "a battle terminates" (done_b.winner <> None);
  check "it terminates on the turn cap rather than looping"
    (done_b.turns_elapsed <= default_rules.max_turns);
  check "the log is non-empty" (log_of done_b <> []);
  check "every turn was logged" (done_b.turns_elapsed > 0);
  (* The two combatants must be distinct actors, not the same one twice. *)
  let sides = List.filter_map (function TurnStart (_, s, _) -> Some s | _ -> None) (log_of done_b) in
  check "both sides take turns" (List.mem Hero sides && List.mem Enemy sides);
  check "the sides alternate"
    (let rec alt = function
       | Hero :: Enemy :: rest -> alt rest
       | Enemy :: Hero :: rest -> alt rest
       | _ -> true
     in
     alt sides)

(* ------------------------------------------------------------------ *)
(* Reproducibility                                                      *)
(* ------------------------------------------------------------------ *)

let () =
  let play seed =
    let b =
      create ~rng:(lcg seed)
        (playable_board ())
        (fighter ~life:60 0 "hero")
        (fighter ~life:60 1 "foe")
    in
    (run b).turns_elapsed
  in
  check "the same seed replays identically" (play 1 = play 1);
  check "a different seed plays differently" (play 1 <> play 99);
  (* Determinism is the reason for separating animation from the rules. *)
  check "and it is stable across repeated runs" (play 5 = play 5)

(* ------------------------------------------------------------------ *)
(* Extra turns reach the turn order                                     *)
(* ------------------------------------------------------------------ *)

let () =
  (* A banked turn has to survive into the turn manager, because that is what
     makes the matcher replay its slot. *)
  let other = make_combatant 1 "foe" in
  let tm = initialise [ (make_combatant 0 "hero"); other ] in
  let before = tm.combatants.(0).extra_turns in
  grant_extra_turn tm 0;
  check_eq "a granted turn is banked" tm.combatants.(0).extra_turns (before + 1);
  check_eq "and the drain consumes it" (drain_extra_turns tm) 1;
  check_eq "leaving none" tm.combatants.(0).extra_turns 0

let () =
  (* A 4-of-a-kind in a live battle must show up as a SizeTurn event.

     Row 3 reads "E S S air S", which has no run in it, and a skull sits
     directly above the air. Dropping that skull in turns the row into a
     4-of-a-kind. The skulls have to straddle the gap: three skulls side by side
     would already be a match before anybody moved, and the AI would then accept
     the no-op swap of a skull with itself as its best move. *)
  let b = locked_board () in
  let b = set_gem { x = 1; y = 3 } Skull b in
  let b = set_gem { x = 2; y = 3 } Skull b in
  let b = set_gem { x = 4; y = 3 } Skull b in
  let b = set_gem { x = 3; y = 2 } Skull b in
  let b =
    create ~rng:(lcg 3) ~rules:{ default_rules with size_patterns = true } b
      (fighter 0 "hero") (fighter 1 "foe")
  in
  let done_b = run b in
  let events = log_of done_b in
  check "the battle ran" (done_b.turns_elapsed > 0);
  check "the swap that dropped the skull in is logged"
    (List.exists (fun e -> match e with Swap (3, 2, Vertical) -> true | _ -> false) events);
  (* The size turn is deterministic, so it must land in the very first cascade,
     before any refill can manufacture another one. Checking the whole battle
     instead would only measure how often random skulls later lined up four. *)
  let first_size_turn =
    List.find_opt (function SizeTurn _ -> true | _ -> false) events
  in
  check "a 4-of-a-kind earns a size turn" (first_size_turn <> None);
  check "and it lands in the opening cascade, before the first turn ends"
    (let opening =
       let rec take acc = function
         | [] -> List.rev acc
         | TurnEnd _ :: _ -> List.rev acc
         | e :: rest -> take (e :: acc) rest
       in
       take [] events
     in
     List.exists (function SizeTurn _ -> true | _ -> false) opening)

let () =
  (* With the extra turn mechanic disabled, no BankedTurn may ever be logged.
     That is the board flag at +0x391 and it gates the whole roll. *)
  let rules = { default_rules with extra_turns_enabled = false; size_patterns = false } in
  let b =
    create ~rng:(lcg 11) ~rules
      (playable_board ())
      (fighter ~life:80 0 "hero")
      (fighter ~life:80 1 "foe")
  in
  let done_b = run b in
  let banked =
    List.exists (function BankedTurn _ -> true | _ -> false) (log_of done_b)
  in
  check "no stat-based turn when the flag is clear" (not banked);
  check "and no size-based turn either"
    (not (List.exists (function SizeTurn _ -> true | _ -> false) (log_of done_b)));
  check "the battle still completes" (done_b.winner <> None)

(* ------------------------------------------------------------------ *)
(* Mana burn                                                            *)
(* ------------------------------------------------------------------ *)

let () =
  (* A locked board has no productive swap, so the loop must reshuffle rather
     than pass. *)
  let rules = { default_rules with max_turns = 12 } in
  let b =
    create ~rng:(lcg 5) ~rules
      (locked_board ())
      (fighter ~life:100 0 "hero")
      (fighter ~life:100 1 "foe")
  in
  let done_b = run b in
  check "a locked board triggers mana burn" (done_b.mana_burns > 0);
  check "mana burn is logged" (List.exists (fun e -> e = ManaBurn) (log_of done_b));
  check "and the board is refilled after it"
    (List.exists (fun e -> e = Refilled) (log_of done_b));
  (* A burn always produces a playable board, otherwise the loop would spin. *)
  check "burning kept the battle progressing" (done_b.turns_elapsed > 0);
  check "and did not exceed the cap" (done_b.turns_elapsed <= rules.max_turns)

(* ------------------------------------------------------------------ *)
(* Spells in the loop                                                   *)
(* ------------------------------------------------------------------ *)

let () =
  (* Both sides run the same action path, so a spell cast appears in the log
     and its cost is paid. *)
  let s = make_spell ~cost_fire:3 "SFIRE" "firebolt" in
  let rules = { default_rules with difficulty = 2 } in
  let b =
    create ~rng:(lcg 13) ~rules ~enemy_spells:[ s ]
      (playable_board ())
      (fighter ~mana:{ zero_mana with fire = 20 } 0 "hero")
      (fighter ~mana:{ zero_mana with fire = 20 } 1 "foe")
  in
  let done_b = run b in
  let casts = List.filter_map (function SpellCast (_, id) -> Some id | _ -> None) (log_of done_b) in
  check "a spell was cast during the battle" (casts <> []);
  check "it was the spell we supplied" (List.for_all (fun id -> id = "SFIRE") casts);
  check_eq "and its use count went up" s.use_count (List.length casts);
  check "the caster paid for it"
    (done_b.enemy.mana.fire < 20 || done_b.hero.mana.fire < 20)

let () =
  (* A spell the caster cannot afford must never be picked, and a held spell
     must be logged rather than silently dropped. *)
  let pricey = make_spell ~cost_fire:500 "SPRICEY" "too much" in
  let b =
    create ~rng:(lcg 17) ~enemy_spells:[ pricey ]
      (playable_board ())
      (fighter 0 "hero")
      (fighter ~mana:{ zero_mana with fire = 1 } 1 "foe")
  in
  let done_b = run b in
  check "an unaffordable spell is never cast"
    (not (List.exists (function SpellCast (_, "SPRICEY") -> true | _ -> false) (log_of done_b)));
  check "holding is logged"
    (List.exists (fun e -> match e with SpellHeld _ -> true | _ -> false) (log_of done_b))

(* ------------------------------------------------------------------ *)
(* Damage and death                                                     *)
(* ------------------------------------------------------------------ *)

let () =
  (* Damage has to come off the defender's life and eventually kill it, or the
     stalemate guard is the only thing ending a fight. *)
  let weak = fighter ~life:1 1 "foe" in
  let b =
    create ~rng:(lcg 23) (playable_board ()) (fighter ~life:200 0 "hero") weak
  in
  let done_b = run b in
  check_outcome "a one-life foe dies" done_b.winner (Some HeroVictory);
  check "its death is logged"
    (List.exists (fun e -> match e with Death "foe" -> true | _ -> false) (log_of done_b));
  check "and the battle stopped promptly" (done_b.turns_elapsed < 20)

let () =
  let strong = fighter ~life:500 1 "foe" in
  let rules = { default_rules with max_turns = 6 } in
  let b =
    create ~rng:(lcg 29) ~rules
      (playable_board ())
      (fighter ~life:500 0 "hero") strong
  in
  let done_b = run b in
  check_outcome "two unkillable combatants stalemate" done_b.winner (Some Stalemate);
  check_eq "on exactly the turn cap" done_b.turns_elapsed rules.max_turns

(* ------------------------------------------------------------------ *)
(* Guards                                                               *)
(* ------------------------------------------------------------------ *)

let () =
  check "create rejects a duplicate id"
    (try
       ignore (create (locked_board ()) (fighter 0 "same") (fighter 0 "same"));
       false
     with Invalid_argument _ -> true);
  check "a battle starts unfinished" ((create (locked_board ()) (fighter 0 "h") (fighter 1 "f")).winner = None);
  check "and starts on turn zero"
    ((create (locked_board ()) (fighter 0 "h") (fighter 1 "f")).turns_elapsed = 0)

let () =
  if !failures = 0 then print_endline "\nAll battle tests passed."
  else begin
    Printf.printf "\n%d battle test(s) failed.\n" !failures;
    exit 1
  end
