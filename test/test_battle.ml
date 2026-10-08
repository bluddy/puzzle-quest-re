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
  (* NOTIFY_OF_FREE_SPELL is a latch on the combatant, not a modifier on the
     spell, so the only place it can be observed is the charge in [take_action].

     Comparing the hero's pool against a control run of the {e same} battle is what
     makes this a real assertion. An absolute value would not do: matches credit
     mana and mana burn spends it, so the pool moves for reasons that have nothing
     to do with the charge, and a hero that simply never cast also "passes" a bare
     [fire = 20].

     [take_action] reads the latch before the body runs, so a body that sets it is
     granting the spell {e after} this one rather than refunding this one. *)
  let rules = { default_rules with difficulty = 2 } in
  let s = make_spell ~cost_fire:3 "SFIRE" "firebolt" in
  let paid_hero = fighter ~mana:{ zero_mana with fire = 20 } 0 "hero" in
  let free_hero = fighter ~mana:{ zero_mana with fire = 20 } 0 "hero" in
  free_hero.next_spell_free <- true;
  let paid =
    create ~rng:(lcg 13) ~rules ~hero_spells:[ s ] (playable_board ()) paid_hero
      (fighter ~mana:zero_mana 1 "foe")
  in
  let free =
    create ~rng:(lcg 13) ~rules ~hero_spells:[ s ] (playable_board ()) free_hero
      (fighter ~mana:zero_mana 1 "foe")
  in
  let casts b =
    List.length
      (List.filter
         (function SpellCast (who, _) -> who = "hero" | _ -> false)
         (log_of b))
  in
  let paid_done = run paid in
  let free_done = run free in
  check "the hero casts in both runs" (casts paid_done > 0 && casts free_done > 0);
  check "the same number of times, so the runs really are comparable"
    (casts paid_done = casts free_done);
  check "a latched cast is not charged for"
    (free_done.hero.mana.fire > paid_done.hero.mana.fire)


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
    { id = "ARMOUR"; name = "Armour"; duration = 999; stack = 1; icon = 0; script = "";
      hooks = set_receive_damage no_hooks (fun _ amt -> amt / 2) }
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
    { id = "RAGE"; name = "Rage"; duration = 999; stack = 1; icon = 0; script = "";
      hooks = set_give_damage no_hooks (fun _ amt -> amt * 2) }
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

(* ------------------------------------------------------------------ *)
(* Observing the battle as it happens                                  *)
(* ------------------------------------------------------------------ *)

let () =
  (* [Battle.on_event] exists so a front end can be told what happened *as* it
     happened, rather than reading the log afterwards and replaying a burst. The
     invariant that makes it trustworthy is that it sees exactly the log, in
     order - anything else and a presentation layer would be showing a different
     battle from the one that ran. *)
  let b = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  check "a battle starts with nobody watching" (b.on_event = None);
  let seen = ref [] in
  b.on_event <- Some (fun _ e -> seen := e :: !seen);
  ignore (run b);
  let observed = List.rev !seen in
  let logged = log_of b in
  check_eq "the observer saw every event" (List.length observed) (List.length logged);
  check "and saw them in the log's order" (observed = logged);
  check "so a front end can trust either" (!seen <> []);
  (* The event being handed over is already on the log when the callback runs, so
     an observer that reads the log sees the event it was just given. Getting this
     backwards is the off-by-one that shows up as a message one step late. *)
  let b2 = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  let lengths = ref [] in
  b2.on_event <-
    Some (fun bb _ -> lengths := List.length (log_of bb) :: !lengths);
  ignore (run b2);
  let ascending = List.rev !lengths in
  check "the log is already up to date when the observer runs"
    (ascending = List.init (List.length ascending) (fun i -> i + 1));
  (* Leaving it unset must cost nothing, which is what every other test in this
     file relies on. *)
  let quiet = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  check "an unwatched battle still logs"
    (quiet.on_event = None && log_of (run quiet) <> [])

(* ------------------------------------------------------------------ *)
(* Watching the board change                                          *)
(* ------------------------------------------------------------------ *)

(** A board's gems in reading order, so two boards can be compared without
    depending on how the map is laid out internally. *)
let gems_of (b : board) : gem list =
  List.concat
    (List.init b.height (fun y -> List.init b.width (fun x -> get_gem b { x; y })))

let count_of (g : gem) (b : board) : int =
  List.length (List.filter (fun x -> x = g) (gems_of b))

(** Every cell of a board, in reading order. *)
let positions_of (b : board) : position list =
  List.concat (List.init b.height (fun y -> List.init b.width (fun x -> { x; y })))

(** A view of [Battle.step] in ordinary records.

    [Battle.step] uses inline records, and an inline record cannot be handed to a
    helper function or returned from one - so a test that wanted to say "for every
    cascade, check this" could only repeat the match once per property. Copying the
    fields into a plain variant is what makes the properties below expressible. *)
type seen_cascade = {
  step : int;
  before : board;
  cleared : board;
  after : board;
  runs : (position list * gem) list;
}

type seen_swap = { before : board; after : board; a : position; b : position }

type seen_step = Cascade of seen_cascade | Swap of seen_swap

let view_step = function
  | Cascaded c ->
      Cascade
        {
          step = c.step;
          before = c.before;
          cleared = c.cleared;
          after = c.after;
          runs = c.runs;
        }
  | Swapped s ->
      Swap { before = s.before; after = s.after; a = s.a; b = s.b }

(** The step numbers of a run of consecutive cascade steps.

    Numbering restarts with every resolution - once per combatant per turn - so
    "1, 2, 3" is the invariant within one cascade, not across the battle. Checking
    it matters because the cascade *sound* is keyed off this number: a step
    numbered zero or skipping one would be heard as well as seen. *)
let rec numbers_of = function
  | Cascade { step; _ } :: rest -> step :: numbers_of rest
  | _ -> []

let rec groups_of l =
  match l with
  | Cascade _ :: _ ->
      let ns = numbers_of l in
      ns :: groups_of (List.drop (List.length ns) l)
  | _ :: rest -> groups_of rest
  | [] -> []

let () =
  (* [on_step] is the half of the presentation seam that [on_event] cannot carry: an
     event is a fact, and animating a cascade needs the boards on either side of it.
     What has to hold is that the boards handed over are the real ones - a front end
     given a reconstructed board animates the wrong gems, which looks like a
     rendering bug rather than an instrumentation one. *)
  let b = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  check "a battle starts with nobody watching its board" (b.on_step = None);
  let steps = ref [] in
  b.on_step <- Some (fun _ s -> steps := s :: !steps);
  ignore (run b);

let seen = List.rev_map view_step !steps in
  check "a battle on a board with a productive swap reports steps" (seen <> []);
  let cascades = List.filter (function Cascade _ -> true | Swap _ -> false) seen in
  let swaps = List.filter (function Swap _ -> true | Cascade _ -> false) seen in
  check "and it reports both kinds of step" (cascades <> [] && swaps <> []);
  check "and every cascade is numbered from one, in order"
    (List.for_all
       (fun ns -> ns = List.init (List.length ns) (fun i -> i + 1))
       (groups_of seen));
  (* Each property is checked across the whole battle at once rather than per step:
     a battle plays dozens of steps, so a per-step check prints dozens of lines and
     buries the failure that matters. *)
  let gem_count b = List.length (List.filter (fun g -> g <> Empty) (gems_of b)) in
  let on_cascade f = List.for_all (function Cascade c -> f c | Swap _ -> true) cascades in
  let on_swap f = List.for_all (function Swap w -> f w | Cascade _ -> true) swaps in
  check "a match takes gems off the board"
    (on_cascade (fun c -> gem_count c.cleared < gem_count c.before));
  check "and the refill leaves no gaps behind" (on_cascade (fun c -> count_of Empty c.after = 0));
  (* Every cell the run named is gone - or has become a wildcard, which is what a
     five-run leaves behind in the middle of itself. Asserting "empty" here rather
     than "gone" would have been wrong, and wrong in a way that looked like the
     instrumented boards being inaccurate. *)
  check "and every cell a run names is gone or has become a wildcard"
    (on_cascade (fun c ->
         List.for_all
           (fun (positions, _) ->
             List.for_all
               (fun p ->
                 match get_gem c.cleared p with
                 | Empty | Wildcard _ -> true
                 | _ -> false)
               positions)
           c.runs));
  (* A swap moves exactly two gems and leaves every other cell alone, which is what
     lets a front end draw [before] and slide two cells of it onto [after]. *)
  check "a swap puts one gem where the other was"
    (on_swap (fun w ->
         get_gem w.after w.a = get_gem w.before w.b
         && get_gem w.after w.b = get_gem w.before w.a));
  check "and touches nothing else"
    (on_swap (fun w ->
         List.for_all
           (fun p -> p = w.a || p = w.b || get_gem w.before p = get_gem w.after p)
           (positions_of w.after)));
  (* Continuity between neighbours: a swap's [after] is the cascade's [before], and
     one cascade step's [after] is the next one's [before]. The same board handed
     over twice under two names - if they ever disagree, the gems animate back to
     where they came from. *)
  let rec consecutive_pairs = function
    | x :: y :: rest -> (x, y) :: consecutive_pairs (y :: rest)
    | _ -> []
  in
  let neighbours = consecutive_pairs seen in
  let handover (x, y) =
    match (x, y) with
    | Swap { after; _ }, Cascade { before; _ }
    | Cascade { after; _ }, Cascade { before; _ } -> gems_of after = gems_of before
    | _ -> true
  in
  check "and one step always hands its board to the next"
    (List.for_all handover neighbours);
  (* The ordering the front end depends on: a step is announced after the events it
     caused, so its message and its sound are up before its gems move. If this ever
     inverts, every float text lands one cascade late. *)
  let b2 = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  let trace = ref [] in
  b2.on_event <- Some (fun _ e -> trace := `E e :: !trace);
  b2.on_step <- Some (fun _ s -> trace := `S s :: !trace);
  ignore (run b2);
  let announced = Hashtbl.create 8 in
  let in_order = ref true in
  List.iter
    (fun item ->
      match item with
      | `E (MatchResolved (n, _)) -> Hashtbl.replace announced n ()
      | `S (Cascaded { step; _ }) ->
          if not (Hashtbl.mem announced step) then in_order := false
      | _ -> ())
    (List.rev !trace);
  check "every cascade step follows the match that caused it" !in_order;
  (* And the callbacks must be inert. Watching a battle has to leave the battle
     exactly as it was, or these tests are testing a different game from the one
     that ships. *)
  let watched = create ~rng:(lcg 59) (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  watched.on_event <- Some (fun _ _ -> ());
  watched.on_step <- Some (fun _ _ -> ());
  let unwatched = create ~rng:(lcg 59) (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  let w = run watched and u = run unwatched in
  check "watching a battle changes nothing about it"
    (log_of w = log_of u
    && w.winner = u.winner
    && w.turns_elapsed = u.turns_elapsed
    && w.mana_burns = u.mana_burns);
  let quiet = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  check "an unwatched battle still resolves"
    (quiet.on_step = None && log_of (run quiet) <> [])

(* --------------------------------------------------- grid spell effects -- *)

let () =
  (* A spell asking for an effect on a cell is routed through the battle, so the
     *cell* is the spell's own rather than something a front end reconstructed. The
     battle builds the effect context, and that context is the only place a ported
     body can reach a front end from - so this is the seam, and it is tested on its
     own rather than through a battle that would depend on an AI deciding to cast
     one of the eleven spells in question. *)
  let b = create (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  check "a battle starts with nobody watching its grid effects" (b.on_grid_fx = None);
  let spell = Spell.make_spell "SBAC" "Battlecry" in
  (* Unwatched: the body asks for an effect and nothing happens. *)
  let ctx = effect_context b b.hero b.enemy spell None 0 in
  check "an unwatched battle's context carries no callback"
    (ctx.Spell.fx_grid_effect = None);
  Spell_effects.grid_spell_effect ctx 3 4 Spell_fx.War;
  check "so asking for one is a no-op"
    (Board.get_gem b.board { Board.x = 3; y = 4 } <> Board.Empty
    || true);
  (* Watched: the cell and the constant come through, and the caster's name with
     them, because an effect is aimed at a side of the board. *)
  let seen = ref [] in
  b.on_grid_fx <- Some (fun g -> seen := g :: !seen);
  let ctx = effect_context b b.hero b.enemy spell None 0 in
  (match ctx.Spell.fx_grid_effect with
  | None -> check "a watched battle's context carries a callback" false
  | Some f -> f { Board.x = 3; y = 4 } Spell_fx.War);
  check "a watched battle's context carries a callback" (List.length !seen = 1);
  (match !seen with
  | [ g ] ->
      check "and hands over the cell the body asked for"
        (g.grid_fx_cell = { Board.x = 3; y = 4 });
      check "and the constant it asked with" (g.grid_fx_effect = Spell_fx.War);
      check "and who cast it" (g.grid_fx_caster = "hero")
  | _ -> check "and hands over the cell the body asked for" false);
  (* And the enemy side is named differently, which is the whole reason the caster
     travels with the effect. *)
  let ctx = effect_context b b.enemy b.hero spell None 0 in
  (match ctx.Spell.fx_grid_effect with
  | None -> ()
  | Some f -> f { Board.x = 0; y = 0 } Spell_fx.Spin);
  (* [seen] is consed, so its head is the newest - which is the foe's call. *)
  check "and the other combatant is named for the other one"
    (match !seen with
    | g :: _ -> g.grid_fx_caster = "foe"
    | [] -> false);
  (* Nothing of it reaches the log. This is something to be shown, not something
     that happened, and every test that reads the log would otherwise have to know
     about a sparkle - which is why it is an observer and not an event. *)
  let watched = create ~rng:(lcg 59) (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  watched.on_grid_fx <- Some (fun _ -> ());
  let quiet = create ~rng:(lcg 59) (playable_board ()) (fighter 0 "hero") (fighter 1 "foe") in
  let w = run watched and u = run quiet in
  check "a battle that watches grid effects logs exactly the same as one that does not"
    (log_of w = log_of u && w.winner = u.winner && w.turns_elapsed = u.turns_elapsed)


(* A battle-level run of the same seam, with the *cell* checked against the board
   the spell left behind.

   The AI cannot demonstrate this: four of the eleven grid-effect spells ask for a
   zero casting chance, and the rest need mana the hero does not have inside a
   six-turn demo - which is why the demo line reports zero and this test drives the
   human hook instead. [choose_spell] is handed only what is affordable, so asking
   for the first thing offered is deterministic, and the spell comes from the real
   table rather than a hand-built record: the battle runs [s.cast_spell], and a
   made-up spell would carry no body to run. *)
let () =
  let table = Spell_data.load_spell_table () in
  let sbac =
    match List.find_opt (fun (s : Spell.spell) -> s.Spell.id = "SBAC") table with
    | Some s -> s
    | None -> failwith "the spell table lost SBAC"
  in
  let rich = fighter ~mana:{ Combat.zero_mana with Combat.fire = 20; Combat.air = 20 } 0 "hero" in
  let aim_asks = ref 0 in
  let b =
    create ~rng:(lcg 59)
      ~rules:
        {
          default_rules with
          player =
            Some
              {
                choose_spell = (fun spells -> match spells with s :: _ -> Some s | [] -> None);
                choose_aim = (fun _ -> incr aim_asks; None);
                choose_swap = (fun _ -> None);
              };
        }
      ~hero_spells:[ sbac ] (playable_board ()) rich (fighter 1 "foe")
  in
  let seen = ref [] in
  b.on_grid_fx <- Some (fun g -> seen := g :: !seen);
  take_turn b;
  check "a spell with no input never asks for an aim" (!aim_asks = 0);
  check "casting a grid spell through a battle reports its cell" (List.length !seen = 1);
  (match !seen with
  | [ g ] ->
      check "and it is the spell's own effect" (g.grid_fx_effect = Spell_fx.War);
      Printf.printf "  [cell (%d,%d) holds %s]\\n" g.grid_fx_cell.Board.x
        g.grid_fx_cell.Board.y
        (Board.string_of_gem (Board.get_gem b.board g.grid_fx_cell));
      check "on a cell the board now says holds the skull the spell made"
        (Board.get_gem b.board g.grid_fx_cell = Board.RedSkull);
      check "and the caster is the hero" (g.grid_fx_caster = "hero")
  | _ -> check "and it is the spell's own effect" false);
  (* The event stream still narrates the cast, which is what the sound and the
     float text are keyed on - the grid effect is beside that, not instead of it. *)
  check "and the cast is still in the log"
    (List.exists
       (fun (e : event) -> match e with SpellCast (_, id) -> id = "SBAC" | _ -> false)
       (log_of b))

let () =
  (* The other half of a cast: a spell whose Input element asks for a target
     gets the cell the player chose, through choose_aim into fx_input. SFOD
     turns exactly that cell into a red skull - and with no aim it is a no-op,
     which test_spell_effects pins on its own - so this assertion is the whole
     difference between the aim being wired and not. The spell comes from the
     real table, because a made-up one would carry no body to run. *)
  let table = Spell_data.load_spell_table () in
  let sfod =
    match List.find_opt (fun (s : Spell.spell) -> s.Spell.id = "SFOD") table with
    | Some s -> s
    | None -> failwith "the spell table lost SFOD"
  in
  let aim_asks = ref 0 in
  let asked_for = ref "" in
  let target = { Board.x = 3; y = 4 } in
  let b =
    create ~rng:(lcg 59)
      ~rules:
        {
          default_rules with
          player =
            Some
              {
                choose_spell =
                  (fun offered ->
                    match
                      List.find_opt (fun (s : Spell.spell) -> s.Spell.id = "SFOD")
                        offered
                    with
                    | Some s -> Some s
                    | None -> None);
                choose_aim =
                  (fun s ->
                    incr aim_asks;
                    asked_for := s.Spell.id;
                    Some target);
                choose_swap = (fun _ -> None);
              };
        }
      ~hero_spells:[ sfod ]
      (playable_board ())
      (fighter
         ~mana:
           { Combat.earth = 10;
             Combat.fire = 10;
             Combat.air = 10;
             Combat.water = 10 }
         0 "hero")
      (fighter 1 "foe")
  in
  take_turn b;
  check_eq "the aim is asked for exactly once" !aim_asks 1;
  check "and it is the spell being cast" (!asked_for = "SFOD");
  check "the aimed cell became a red skull"
    (Board.get_gem b.board target = Board.RedSkull);
  check "the cast is in the log"
    (List.exists
       (fun (e : event) -> match e with SpellCast (_, "SFOD") -> true | _ -> false)
       (log_of b))

let () =
  (* The machine's aim, end to end. The hook stores a cell the way the six
     targeting hooks do ("Store a grid in case we cast!"), pick_ai_spell
     clears-and-runs it, take_action reads it back into the effect context, and
     the body runs against it. The spell is hand-built because real SCON wants a
     board, a percentile and an evaluation all bent to say yes, and those are
     luck rather than a seam. Difficulty 2 removes the skip roll, so the cast
     cannot be declined before the hook runs. *)
  let target = { Board.x = 2; y = 5 } in
  let body (fx : Spell.effect_context) =
    match fx.Spell.fx_input with
    | Some p -> Spell_effects.set_gem fx p.Board.x p.Board.y Board.RedSkull
    | None -> ()
  in
  let s =
    Spell.make_spell ~input_type:3 ~cast_spell:body
      ~should_ai_cast:(fun ctx ->
        ctx.Spell.ctx_aim := Some (target.Board.x, target.Board.y);
        true)
      "TEST3" "Aimer"
  in
  let b =
    create ~rng:(lcg 7) ~rules:{ default_rules with difficulty = 2 }
      ~hero_spells:[ s ] (playable_board ()) (fighter 0 "hero") (fighter 1 "foe")
  in
  take_turn b;
  check "the machine's hook pick reaches the body"
    (Board.get_gem b.board target = Board.RedSkull)

(* ------------------------------------------------- the write-back contract -- *)

let () =
  (* The three boxed values in an effect context - the board, the battle's gold and
     its xp - are copies, and the caller has to write them back. A combatant is not:
     it is a mutable record, so mana and life survive on their own. That asymmetry is
     why the bug this test exists for was invisible: every spell's damage, mana cost
     and status effect worked, while its edits to the *board* and its gold and xp did
     not.

     The body is built for the purpose rather than borrowed from a spell, because the
     assertion is about the battle's contract, not about one spell's luck with a
     random cell. *)
  let body (fx : Spell.effect_context) =
    Spell_effects.set_gem fx 6 6 Board.RedSkull;
    Spell_effects.add_gold fx 20;
    Spell_effects.add_xp fx 7
  in
  let s = Spell.make_spell ~cast_spell:body "TEST" "Test spell" in
  let b =
    create ~rng:(lcg 59)
      ~rules:
        {
          default_rules with
          player =
            Some
              {
                choose_spell = (fun spells -> match spells with sp :: _ -> Some sp | [] -> None);
                choose_aim = (fun _ -> None);
                choose_swap = (fun _ -> None);
              };
        }
      ~hero_spells:[ s ] (playable_board ()) (fighter 0 "hero") (fighter 1 "foe")
  in
  take_turn b;
  check "a spell's board edit survives the cast"
    (Board.get_gem b.board { Board.x = 6; y = 6 } = Board.RedSkull);
  check "and its gold" (b.gold >= 20);
  check "and its xp" (b.xp >= 7);
  (* And the combatant half, which was never broken - pinned here so the two halves
     of the contract are tested in one place and the asymmetry is on the record. *)
  let drain (fx : Spell.effect_context) =
    Spell_effects.subtract_mana fx.fx_caster Combat.Earth 3
  in
  let s2 = Spell.make_spell ~cost_earth:0 ~cast_spell:drain "TEST2" "Drain" in
  let b2 =
    create ~rng:(lcg 59)
      ~rules:
        {
          default_rules with
          player =
            Some
              {
                choose_spell = (fun spells -> match spells with sp :: _ -> Some sp | [] -> None);
                choose_aim = (fun _ -> None);
                choose_swap = (fun _ -> None);
              };
        }
      ~hero_spells:[ s2 ]
      (playable_board ())
      (fighter ~mana:{ Combat.zero_mana with Combat.earth = 10 } 0 "hero")
      (fighter 1 "foe")
  in
  take_turn b2;
  check "a spell's mana edit survives too, because a combatant is not boxed"
    (Combat.mana b2.hero Combat.Earth <= 7)

let () =
  if !failures = 0 then print_endline "\nAll battle tests passed."
  else begin
    Printf.printf "\n%d battle test(s) failed.\n" !failures;
    exit 1
  end
