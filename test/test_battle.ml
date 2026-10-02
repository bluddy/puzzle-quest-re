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
  (* Compared as a rendered trace rather than a turn count: with two evenly
     matched combatants on 60 life neither side reliably dies, so every seed
     runs to the 200-turn cap and the counts are all identical. The trace is
     what determinism actually has to hold for. *)
  let play seed =
    let b =
      create ~rng:(lcg seed)
        (playable_board ())
        (fighter ~life:60 0 "hero")
        (fighter ~life:60 1 "foe")
    in
    List.map format_event (log_of (run b))
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
  check "and did not exceed the cap" (done_b.turns_elapsed <= rules.max_turns);
  (* Regression: a burn used to call [refill_board], which only fills Empty cells.
     A regenerated board has none, so the burn was a no-op and the AI burned on
     every single turn for the whole cap. *)
  check "and did not burn on every turn" (done_b.mana_burns < done_b.turns_elapsed);
  check "the board is playable afterwards" (Board.has_valid_move done_b.board)

let () =
  (* The board a burn hands back must be playable, not merely different. *)
  let rng = lcg 61 in
  let unplayable = locked_board () in
  check "the fixture really is unplayable" (not (Board.has_valid_move unplayable));
  let after = Board.reshuffle ~rng unplayable in
  check "a burn makes it playable" (Board.has_valid_move after);
  check "with no empty cells left"
    (let empty = ref 0 in
     for y = 0 to after.height - 1 do
       for x = 0 to after.width - 1 do
         if get_gem after { x; y } = Empty then incr empty
       done
     done;
     !empty = 0)

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
(* Cooldowns                                                            *)
(* ------------------------------------------------------------------ *)

let () =
  (* A spell on cooldown must not be picked even though it is affordable, and it
     must be picked again once the counter runs out. Difficulty 2 removes the
     AI's random skip, so any gap in the casts is the cooldown and nothing else. *)
  let s = make_spell ~cost_fire:1 ~cooldown:3 "SCD" "cooldown" in
  let b =
    create ~rng:(lcg 31)
      ~rules:{ default_rules with difficulty = 2; max_turns = 40 }
      ~enemy_spells:[ s ] (playable_board ())
      (fighter 0 "hero")
      (fighter ~mana:{ zero_mana with fire = 500 } 1 "foe")
  in
  let done_b = run b in
  let events = log_of done_b in
  let casts = List.filter_map (function SpellCast (_, id) -> Some id | _ -> None) events in
  check "a cooldown spell is still cast" (casts <> []);
  (* 40 turns at a 3-turn cooldown, counting the caster's own turns only, is at
     most 14 casts. Without the cooldown it would be every one of the foe's 20. *)
  check "and far fewer times than the fight has turns" (List.length casts <= 15);
  check "but not zero" (List.length casts > 0);
  (* The load-bearing claim is the {e gap}, measured in the foe's own turns.
     Asserting the counter reaches zero by the end of the battle would be a
     fragile statement about where the fight happened to stop. *)
  let foe_turn_of_each_cast =
    let turn = ref 0 in
    List.filter_map
      (fun e ->
        match e with
        | TurnStart (_, Enemy, _) ->
            incr turn;
            None
        | SpellCast (_, _) -> Some !turn
        | _ -> None)
      events
  in
  let gaps =
    let rec go acc = function
      | a :: (b :: _ as rest) -> go ((b - a) :: acc) rest
      | _ -> acc
    in
    go [] foe_turn_of_each_cast
  in
  check "no two casts are closer than the cooldown" (List.for_all (fun g -> g >= 3) gaps);
  check "and there was more than one cast to measure" (List.length gaps > 0)

let () =
  (* A spell with no Data cooldown is never gated. *)
  let s = make_spell ~cost_fire:1 ~cooldown:0 "SNC" "no cooldown" in
  let b =
    create ~rng:(lcg 37)
      ~rules:{ default_rules with difficulty = 2; max_turns = 20 }
      ~enemy_spells:[ s ] (playable_board ())
      (fighter 0 "hero")
      (fighter ~mana:{ zero_mana with fire = 500 } 1 "foe")
  in
  let done_b = run b in
  let casts =
    List.length
      (List.filter (function SpellCast (_, "SNC") -> true | _ -> false) (log_of done_b))
  in
  check "a spell without a cooldown casts every turn" (casts >= 8);
  check "and never enters the cooldown map" (cooldown_left done_b.enemy s = 0)

let () =
  (* Cooldowns are per combatant, not per spell record. The two sides share one
     spell object here, so the hero casting must not gate the foe. *)
  let s = make_spell ~cost_fire:1 ~cooldown:5 "SSH" "shared" in
  let hero = fighter ~mana:{ zero_mana with fire = 500 } 0 "hero" in
  let foe = fighter ~mana:{ zero_mana with fire = 500 } 1 "foe" in
  start_cooldown hero s;
  check "the caster is gated" (not (is_ready hero s));
  check "the other side is not" (is_ready foe s);
  check "and the other side can cast it" (can_cast foe s);
  check "while the gated side cannot" (not (can_cast hero s))

let () =
  (* Ticking walks the counter down and drops it at zero, so the map does not
     grow over a long battle. *)
  let s = make_spell ~cooldown:2 "S2" "two" in
  let c = make_combatant 0 "hero" in
  start_cooldown c s;
  check_eq "a 2-turn cooldown starts at 2" (cooldown_left c s) 2;
  tick_cooldowns c;
  check_eq "then 1" (cooldown_left c s) 1;
  tick_cooldowns c;
  check_eq "then gone" (cooldown_left c s) 0;
  check "and removed from the map" (c.cooldowns = [])

(* ------------------------------------------------------------------ *)
(* Damage hooks                                                         *)
(* ------------------------------------------------------------------ *)

let () =
  (* A receive-damage hook halves what the defender takes. Without this wired
     into the loop the hook exists in Combat and is never called.

     The duration is long enough to outlast the fight: a short one would tick
     away mid-battle and the test would be measuring the expiry instead. *)
  let def =
    { def_id = "ARMOUR"; def_duration = 999; def_max_stack = 1; def_icon = 0;
      def_hooks = set_receive_damage no_hooks (fun _ amt -> amt / 2) }
  in
  let foe_life_after with_armour =
    let foe = Combat.make_combatant ~cunning:5 ~max_life:9000 ~life:9000 1 "foe" in
    if with_armour then apply_effect def foe;
    let b =
      create ~rng:(lcg 41) ~effects:(if with_armour then [ def ] else [])
        ~rules:{ default_rules with max_turns = 12 }
        (playable_board ()) (fighter ~life:9000 0 "hero") foe
    in
    (run b).enemy.life
  in
  (* Compared as two otherwise identical fights rather than raw against taken
     damage: the foe's own attacks land on an unarmoured hero, so summing every
     Damage event mixes the two directions and the ratio means nothing. *)
  let bare = foe_life_after false and armoured = foe_life_after true in
  let bare_damage = 9000 - bare and armoured_damage = 9000 - armoured in
  check "the bare fight costs the foe life" (bare_damage > 0);
  check "and the armoured one costs it less" (armoured_damage < bare_damage);
  (* Halving applies per hit and truncates each time, so the total comes out
     under half rather than exactly half: 4+3 damage halves to 2+1. Asserting
     "no more than half" is the precise claim. *)
  check "by at least half" (armoured_damage * 2 <= bare_damage)

let () =
  (* A give-damage hook doubles what the attacker deals, and the two chains
     compose: the amplifier runs on the way out, the armour on the way in. *)
  let amp =
    { def_id = "RAGE"; def_duration = 999; def_max_stack = 1; def_icon = 0;
      def_hooks = set_give_damage no_hooks (fun _ amt -> amt * 2) }
  in
  let hero = Combat.make_combatant ~max_life:4000 ~life:4000 0 "hero" in
  apply_effect amp hero;
  let b =
    create ~rng:(lcg 43) ~effects:[ amp ] ~rules:{ default_rules with max_turns = 3 }
      (playable_board ()) hero
      (Combat.make_combatant ~max_life:4000 ~life:4000 1 "foe")
  in
  let done_b = run b in
  let raw =
    List.fold_left
      (fun acc -> function MatchResolved (_, r) -> acc + r.damage | _ -> acc) 0
      (log_of done_b)
  in
  let taken =
    List.fold_left
      (fun acc -> function Damage (_, n) -> acc + n | _ -> acc) 0
      (log_of done_b)
  in
  check "damage was dealt" (raw > 0);
  check "the amplifier doubled it" (taken > raw);
  check "and the foe survived" (done_b.enemy.life > 0)

(* ------------------------------------------------------------------ *)
(* Gold, XP, and Heroic Effort                                          *)
(* ------------------------------------------------------------------ *)

let () =
  (* Gold and XP come from the board's matcher, so the loop has to carry them
     through rather than zeroing the fields as it used to.

     The board is built so the AI's best move drops a gold gem into a column
     that already holds two, completing a 3-run of gold. Gold costs no life, so
     the battle continues and the harvest is observable in isolation. *)
  let b = locked_board () in
  let b = set_gem { x = 2; y = 2 } Gold b in
  let b = set_gem { x = 2; y = 3 } Gold b in
  let b = set_gem { x = 2; y = 4 } Gold b in
  let bt =
    create ~rng:(lcg 47) ~rules:{ default_rules with max_turns = 1 } b
      (fighter ~life:300 0 "hero") (fighter ~life:300 1 "foe")
  in
  let done_b = run bt in
  let steps =
    List.filter_map (function MatchResolved (_, r) -> Some r | _ -> None) (log_of done_b)
  in
  check "the gold run resolved" (steps <> []);
  check "three gold were harvested" (List.exists (fun (r : match_result) -> r.gold = 3) steps);
  check "and it cost no life" (List.for_all (fun (r : match_result) -> r.damage = 0) steps);
  check "gold is banked on the battle" (done_b.gold >= 3);
  check "and the gold event is logged"
    (List.exists (fun e -> match e with GoldGained (_, n) -> n = 3 | _ -> false)
       (log_of done_b))

let () =
  (* Heroic Effort: the original's [FUN_0047AE80] fires when a swap's cascade
     counter reaches 5, awarding +100 XP and an extra turn.

     The threshold is lowered to 2 rather than hand-building a five-deep chain,
     which is impractical and would test the fixture instead of the rule. The
     accounting is what matters here: the award is once per swap, not once per
     step past the threshold. *)
  let rules = { default_rules with heroic_effort_depth = 2; max_turns = 6 } in
  let bt =
    create ~rng:(lcg 53) ~rules (playable_board ()) (fighter ~life:9000 0 "hero")
      (fighter ~life:9000 1 "foe")
  in
  let done_b = run bt in
  let deepest =
    List.fold_left
      (fun acc -> function MatchResolved (n, _) -> max acc n | _ -> acc) 0
      (log_of done_b)
  in
  check "the battle cascaded at least two deep" (deepest >= 2);
  check "the heroic award fired" (done_b.xp >= 100);
  check "and is logged"
    (List.exists (fun e -> match e with HeroicEffort _ -> true | _ -> false) (log_of done_b));
  (* Once per qualifying swap, so with at most 6 turns there can be no more than
     6 awards, and each is worth exactly 100. *)
  check "the award is 100 xp each"
    (done_b.xp = 100 * List.length
       (List.filter (fun e -> match e with HeroicEffort _ -> true | _ -> false)
          (log_of done_b)));
  check "never more than one per swap" (done_b.xp <= 600);
  check "with the board still 8x8" (done_b.board.height = 8)

let () =
  (* A chain shorter than the threshold must not award anything. *)
  let rules = { default_rules with heroic_effort_depth = 99; max_turns = 6 } in
  let bt =
    create ~rng:(lcg 59) ~rules (playable_board ()) (fighter ~life:9000 0 "hero")
      (fighter ~life:9000 1 "foe")
  in
  let done_b = run bt in
  check "no heroic award below the threshold" (done_b.xp = 0);
  check "and nothing logged"
    (not (List.exists (fun e -> match e with HeroicEffort _ -> true | _ -> false)
            (log_of done_b)))

(* ------------------------------------------------------------------ *)
(* Skills                                                                *)
(* ------------------------------------------------------------------ *)

let () =
  (* Skill, not mana balance, drives the yield. A character with a big pool and
     no training must bank less than one with the same pool and high skill, and
     the extra turn roll follows the skill. *)
  let unskilled = Combat.make_combatant ~mana:{ zero_mana with fire = 500 } 0 "a" in
  let trained =
    Combat.make_combatant ~mana:{ zero_mana with fire = 500 }
      ~skills:{ zero_skills with fire = 500 } 1 "b"
  in
  let b = create ~rng:(lcg 59) (locked_board ()) unskilled (fighter 1 "foe") in
  let untrained_yield = mana_yield ~skill:(skill_of unskilled b Fire) ~run_length:3 in
  let trained_yield = mana_yield ~skill:(skill_of trained b Fire) ~run_length:3 in
  check "an untrained character banks the floor" (untrained_yield = 1.0);
  (* (500 + 100) * 1.0 * 0.01 = 6.0 for a 3-run. *)
  check "a trained one banks far more" (trained_yield = 6.0);
  check "and the pool alone does not help"
    (skill_of unskilled b Fire = 0);
  check "skill is read from the skill field" (skill_of trained b Fire = 500);
  check "the cap clamps it at 999" (skill_of trained { b with rules = { b.rules with hero_skill_cap = 20 } } Fire = 20)

(* ------------------------------------------------------------------ *)
(* Casting ends the turn                                               *)
(* ------------------------------------------------------------------ *)

let () =
  (* The rule under test: an ordinary spell ends the turn, so the caster does
     not also swap. This is the common case and the battle loop previously had
     it exactly backwards. *)
  let s = make_spell ~cost_fire:1 "SORD" "ordinary" in
  let b =
    create ~rng:(lcg 67) ~rules:{ default_rules with difficulty = 2 }
      ~enemy_spells:[ s ] (playable_board ())
      (fighter ~life:500 0 "hero")
      (fighter ~mana:{ zero_mana with fire = 500 } ~life:500 1 "foe")
  in
  let done_b = run b in
  let events = log_of done_b in
  check "the spell was cast" (List.exists (fun e -> match e with SpellCast _ -> true | _ -> false) events);
  (* Walk the log: a foe turn that cast an ordinary spell must contain no swap. *)
  let foa_turns_with_a_swap =
    let in_foe = ref false and bad = ref 0 and good = ref 0 in
    List.iter
      (fun e ->
        match e with
        | TurnStart (_, Enemy, _) ->
            in_foe := true;
            good := 0
        | TurnStart (_, Hero, _) -> in_foe := false
        | SpellCast (_, _) when !in_foe -> incr good
        | Swap _ when !in_foe -> incr bad
        | _ -> ())
      events;
    (!bad, !good)
  in
  let bad, casting_turns = foa_turns_with_a_swap in
  check "at least one turn cast the spell" (casting_turns > 0);
  check "and none of those turns also swapped" (bad = 0)

let () =
  (* A spell that keeps the turn does hand it back, so the caster also swaps. *)
  let s = make_spell ~cost_fire:1 ~turn_cost:KeepsTurn "SKEEP" "keeps" in
  let b =
    create ~rng:(lcg 71) ~rules:{ default_rules with difficulty = 2 }
      ~enemy_spells:[ s ] (playable_board ())
      (fighter ~life:500 0 "hero")
      (fighter ~mana:{ zero_mana with fire = 500 } ~life:500 1 "foe")
  in
  let done_b = run b in
  let events = log_of done_b in
  let both =
    let in_foe = ref false and hits = ref 0 in
    let cast = ref false and swapped = ref false in
    List.iter
      (fun e ->
        match e with
        | TurnStart (_, Enemy, _) ->
            if !cast && !swapped then incr hits;
            in_foe := true;
            cast := false;
            swapped := false
        | TurnStart (_, Hero, _) ->
            in_foe := false;
            if !cast && !swapped then incr hits;
            cast := false;
            swapped := false
        | SpellCast _ when !in_foe -> cast := true
        | Swap _ when !in_foe -> swapped := true
        | _ -> ())
      events;
    if !cast && !swapped then incr hits;
    !hits
  in
  check "a turn-keeping spell casts and then swaps" (both > 0)

let () =
  (* The conditional form tests the caster's mana at the moment of the cast. *)
  let spell = make_spell ~cost_fire:2 ~turn_cost:(KeepsTurnIfMana (Fire, 15)) "SCOND" "cond" in
  check "below the threshold the turn ends" (not (keeps_turn (fighter ~mana:zero_mana 0 "a") spell));
  check "at the threshold it is kept" (keeps_turn (fighter ~mana:{ zero_mana with fire = 15 } 0 "a") spell);
  check "above it too" (keeps_turn (fighter ~mana:{ zero_mana with fire = 99 } 0 "a") spell);
  (* The threshold is on the named element only: a full pool elsewhere does not
     help. This is the failure mode a transposition would cause, and the element
     ordering differs between the spell description and the board. *)
  check "another element's mana does not satisfy it"
    (not (keeps_turn (fighter ~mana:{ zero_mana with earth = 99; air = 99; water = 99 } 0 "a") spell))

let () =
  (* The generated table. Spot-checking against the descriptions in
     English/StandardSpellsText.xml, which is where the values come from. *)
  let turn_cost_of id =
    match Spell_data.descriptor_of id with
    | Some (d : Spell.descriptor) -> d.turn_cost
    | None -> Spell.EndsTurn
  in
  check "SBAC keeps the turn if fire mana is 15+"
    (turn_cost_of "SBAC" = Spell.KeepsTurnIfMana (Fire, 15));
  check "SCHA keeps the turn outright" (turn_cost_of "SCHA" = Spell.KeepsTurn);
  check "SBRL ends the turn after the effect"
    (turn_cost_of "SBRL" = Spell.EndsTurnAfterEffect);
  check "an ordinary spell ends the turn" (turn_cost_of "SBAV" = Spell.EndsTurn);
  check "an unknown id defaults to ending the turn" (turn_cost_of "NOPE" = Spell.EndsTurn);
  check "the table covers the 129 battle spells"
    (List.length Spell_data.spell_descriptors = 129);
  let ends_turn =
    List.length
      (List.filter
         (fun (d : Spell.descriptor) -> string_of_turn_cost d.turn_cost = "EndsTurn")
         Spell_data.spell_descriptors)
  in
  let keeps =
    List.length
      (List.filter
         (fun (d : Spell.descriptor) -> string_of_turn_cost d.turn_cost = "KeepsTurn")
         Spell_data.spell_descriptors)
  in
  (* The counts the extraction reported, so a change in the spell data shows up
     here rather than as a silent behaviour change. *)
  check "97 spells end the turn by default" (ends_turn = 97);
  check "13 spells keep the turn outright" (keeps = 13);
  check "so the common case really is ending it" (ends_turn > keeps * 5)

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
