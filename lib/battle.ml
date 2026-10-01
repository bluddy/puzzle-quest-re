(** A playable battle loop.

    Wires [Board], [Ai], [Combat] and [Spell] into a turn cycle that runs
    headless. The structure follows [FUN_0047C3E0] (the enemy turn state
    machine), [FUN_0047E500] (the cascade driver) and [FUN_0047D4F0] (the mana
    gain and stat-based extra turn).

    The original's state machine interleaves animation lengths with the rules.
    Here the two are separated, so a battle is a function of state and a seeded
    rng and is therefore reproducible, which the timing-driven original is not.
    That is the main practical gain and it is what makes the AI work testable.

    **Row indexing.** [Board] treats rows 0..7 as all playable. The engine
    reserves row 0 as a spawn buffer and plays on rows 1..8, and [Ai] is
    written against that convention. {!ai_view} bridges the two by presenting
    the board to [Ai] as a 9-row grid with an empty row 0, so [Ai] sees the
    engine's coordinates without the board module having to know about them. *)

open Board
open Combat
open Spell
open Ai

type side = Hero | Enemy

type event =
  | TurnStart of int * side * string  (** slot, side, name *)
  | ExtraTurn of string
  | SpellCast of string * string  (** caster, spell id *)
  | SpellHeld of string
  | Swap of int * int * direction
  | MatchResolved of int * match_result
  | BankedTurn of string
  | SizeTurn of string  (** from a 4- or 5-of-a-kind *)
  | ManaBurn
  | Refilled
  | ManaGained of string * int * int  (** name, element id, amount *)
  | Damage of string * int
  | Death of string
  | TurnEnd of int
  | BattleEnd of outcome

and outcome =
  | HeroVictory
  | EnemyVictory
  | Draw
  | Stalemate

type rules = {
  difficulty : int;  (** 0 easy, 1 normal, 2+ hard *)
  hero_level : int;
  hero_level_cap : int;
  max_turns : int;  (** stalemate guard *)
  extra_turns_enabled : bool;  (** board flag at +0x391 *)
  size_patterns : bool;  (** 4- and 5-of-a-kind grant a turn *)
  hero_skill_cap : int;  (** skill ceiling, drives the extra turn roll *)
  ai_weights : Ai.weights;
}

let default_rules =
  {
    difficulty = 1;
    hero_level = 10;
    hero_level_cap = 20;
    max_turns = 200;
    extra_turns_enabled = true;
    size_patterns = true;
    hero_skill_cap = 999;
    ai_weights = Ai.default_weights;
  }

type battle = {
  rules : rules;
  mutable board : board;  (** 8x8, all rows playable *)
  hero : combatant;
  enemy : combatant;
  tm : turn_manager;
  mutable turns_elapsed : int;
  mutable mana_burns : int;
  mutable winner : outcome option;
  mutable log : event list;  (** reversed *)
  rng : int -> int;
  hero_spells : spell list;
  enemy_spells : spell list;
  effects : effect_def list;
}

let emit (b : battle) (e : event) = b.log <- e :: b.log
let log_of (b : battle) = List.rev b.log

(** Presents the 8x8 board to [Ai] as the engine's 9-row grid, with row 0 left
    empty as the spawn buffer. [Ai] never reads row 0.

    The shape is confirmed by the decompiled
    [docs/decompiled/mana_burn/Engine_DELETE_GEM_47ac70.c]: its bounds check is
    x in [0,8) and y in [0,9), and it indexes the grid as
    [base + y*8 + x*0x48], so there really are eight columns and nine rows with
    0x48 bytes per cell. Row 0 is the buffer gems fall in from above. *)
let ai_view (b : battle) : board =
  let rows =
    Array.init 9 (fun y ->
        if y = 0 then Array.make 8 Empty
        else Array.init 8 (fun x -> get_gem b.board { x; y = y - 1 }))
  in
  of_array_matrix ~width:8 ~height:9 rows

let refill (b : battle) : unit =
  b.board <- refill_board ~rng:b.rng (apply_gravity b.board);
  emit b Refilled

(** Element a gem belongs to, for crediting mana after a match. Skull, gold and
    xp are not elements and credit nothing. *)
let element_of_gem (g : gem) : element option =
  match g with
  | Mana Earth -> Some Earth
  | Mana Fire -> Some Fire
  | Mana Air -> Some Air
  | Mana Water -> Some Water
  | _ -> None

let element_index (e : element) : int =
  match e with Earth -> 0 | Fire -> 1 | Air -> 2 | Water -> 3

(** The skill that drives mana yield for an element.

    In the original this is a skill field on the character, separate from the
    mana pool: a character can sit on a big pool it has not earned, and the
    extra turn roll uses the skill rather than the balance. [Combat.combatant]
    does not model skills yet, so this reads the current pool, which for a
    character playing normally tracks the skill closely enough to order the
    rolls. Clamped to [rules.hero_skill_cap] because the original clamps at 999
    before the yield is computed. One place to change when skills are modelled
    properly. *)
let skill_of (c : combatant) (b : battle) (e : element) : int =
  min b.rules.hero_skill_cap (mana_of e c.mana)

(** Counts the matches on the current board, grouping by run the way
    [resolve_matches] does. Kept separate so the battle loop can both credit
    mana per element and award size-based turns from the same pass. *)
let find_runs (b : battle) : (position list * gem) list = find_matches b.board

let run_length (coords : position list) = List.length coords

(** Applies one cascade step's effects and returns the damage dealt. *)
let apply_run (b : battle) (defender : combatant) (coords : position list)
    (g : gem) (step : int) : int =
  let attacker = if defender.id = b.enemy.id then b.hero else b.enemy in
  let n = run_length coords in
  (* Damage: a plain skull is 1, a red skull 5. Matches the accumulation in
     [Board.resolve_matches]. *)
  let damage = match g with Skull -> n | RedSkull -> 5 * n | _ -> 0 in
  (* Mana credit is per element matched, one independent roll each. The
     skill that drives the yield is the character's skill in that element,
     modelled on the combatant; see [skill_of]. *)
  (match element_of_gem g with
  | None -> ()
  | Some e ->
      let skill = skill_of attacker b e in
      let gained = mana_yield ~skill ~run_length:n in
      attacker.mana <- add_mana e (int_of_float gained) attacker.mana;
      emit b (ManaGained (attacker.name, element_index e, int_of_float gained));
      if
        extra_turn_roll ~gained ~pending:b.tm.extra_turn_pending
          ~enabled:b.rules.extra_turns_enabled ~roll:b.rng
      then begin
        b.tm.extra_turn_pending <- false;
        grant_extra_turn b.tm attacker.id;
        emit b (BankedTurn attacker.name)
      end);
  (* A 4- or 5-of-a-kind grants a deterministic extra turn, independent of the
     stat roll. *)
  if b.rules.size_patterns && n >= 4 then begin
    grant_extra_turn b.tm attacker.id;
    emit b (SizeTurn attacker.name)
  end;
  (* Clear the matched cells and collect them for the result. *)
  b.board <-
    List.fold_left (fun acc p -> set_gem p Empty acc) b.board coords;
  ignore g;
  ignore step;
  damage

(** Resolves every match, cascading until quiet. Returns the total damage.

    Each step builds its own [match_result] from the runs it found rather than
    going through [Board.resolve_matches], because the loop needs the run
    groupings to award size-based turns and mana per element before the cells
    are cleared. *)
let resolve_cascades (b : battle) (defender : combatant) : int =
  let step = ref 0 in
  let total = ref 0 in
  let going = ref true in
  while !going do
    let runs = find_runs b in
    if runs = [] then going := false
    else begin
      incr step;
      let damage =
        List.fold_left (fun acc (coords, g) -> acc + apply_run b defender coords g !step) 0 runs
      in
      total := !total + damage;
      let cleared =
        List.concat_map (fun (coords, g) -> List.map (fun p -> (p, g)) coords) runs
      in
      let res =
        {
          gems_cleared = cleared;
          air_mana = 0;
          earth_mana = 0;
          fire_mana = 0;
          water_mana = 0;
          gold = 0;
          xp = 0;
          damage;
          extra_turn = List.exists (fun (coords, _) -> List.length coords >= 4) runs;
          wildcards_created = [];
          heroic_effort = false;
        }
      in
      emit b (MatchResolved (!step, res));
      refill b
    end
  done;
  !total

(** Plays a swap for whichever side is acting, then resolves the cascade. *)
let play_move (b : battle) (defender : combatant) : unit =
  let e =
    evaluate_board ~weights:b.rules.ai_weights ~rng:b.rng ~difficulty:b.rules.difficulty
      ~hero:{ level = b.rules.hero_level; level_cap = b.rules.hero_level_cap }
      (ai_view b)
  in
  match (e.has_valid_move, e.best) with
  | true, Some c ->
      (* The candidate comes back in the AI's coordinates, which put row 0
         above the board. Undo the same shift [ai_view] applied, otherwise every
         swap lands one row low. *)
      let sx = c.cand_x and sy = c.cand_y - 1 in
      let src = { x = sx; y = sy } in
      let dst =
        match c.cand_direction with
        | Horizontal -> { x = sx + 1; y = sy }
        | Vertical -> { x = sx; y = sy + 1 }
      in
      b.board <- swap_gems b.board src dst;
      emit b (Swap (sx, sy, c.cand_direction));
      let dealt = resolve_cascades b defender in
      if dealt > 0 then begin
        let taken = receive_damage defender [] dealt in
        defender.life <- max 0 (defender.life - taken);
        (* The defeat sweep keys off the flag, not the life total, so it has to
           be raised here or nobody is ever reported dead. *)
        if defender.life < 1 then defender.is_dead <- true;
        emit b (Damage (defender.name, taken))
      end
  | _ ->
      (* No legal move. The original reshuffles and calls it Mana Burn. *)
      b.mana_burns <- b.mana_burns + 1;
      emit b ManaBurn;
      b.board <- refill_board ~rng:b.rng b.board;
      emit b Refilled

(** The acting side casts if it wants to, else plays a move. Both sides use the
    same path; the original scripts the player through the UI and runs the same
    rules underneath. *)
let take_action (b : battle) (actor : combatant) (defender : combatant)
    (spells : spell list) : unit =
  (match pick_ai_spell ~difficulty:b.rules.difficulty ~roll:b.rng actor spells with
  | None -> emit b (SpellHeld actor.name)
  | Some s ->
      pay_cost actor s;
      s.use_count <- s.use_count + 1;
      emit b (SpellCast (actor.name, s.id)));
  (* Casting does not by itself bank a turn. In the original, an EXTRA_TURN
     comes from a status effect's hook, which is what [run_start_of_turn_effects]
     and [request_extra_turn] drive; a plain cast just spends mana. *)
  (* Either way the actor still takes a board action. Casting is not a
     substitute for swapping, and the original's state machine does both. *)
  play_move b defender

(** One turn for the current combatant. *)
let take_turn (b : battle) : unit =
  if b.winner <> None then ()
  else begin
    let actor = current b.tm in
    let is_hero = actor.id = b.hero.id in
    let defender = if is_hero then b.enemy else b.hero in
    let spells = if is_hero then b.hero_spells else b.enemy_spells in
    emit b (TurnStart (b.tm.current_slot, (if is_hero then Hero else Enemy), actor.name));
    run_start_of_turn_effects actor b.effects b.turns_elapsed;
    take_action b actor defender spells;
    if sweep_deaths b.tm then
      List.iter (fun c -> if c.life = 0 then emit b (Death c.name)) [ b.hero; b.enemy ];
    (* The outcome has to be recorded here, not only at the end of [run]. A dead
       combatant keeps taking turns until the loop exits otherwise, which both
       wastes the cap and lets a corpse deal damage. *)
    (match b.hero.life, b.enemy.life with
    | 0, 0 -> b.winner <- Some Draw
    | 0, _ -> b.winner <- Some EnemyVictory
    | _, 0 -> b.winner <- Some HeroVictory
    | _ -> ());
    b.turns_elapsed <- b.turns_elapsed + 1;
    emit b (TurnEnd b.turns_elapsed);
    ignore (advance_turn b.tm)
  end

(** Runs to completion. The winner lands in [winner], the trace in [log_of]. *)
let run (b : battle) : battle =
  while b.winner = None && b.turns_elapsed < b.rules.max_turns do
    take_turn b
  done;
  let outcome =
    match b.winner with
    | Some o -> o
    | None ->
        if b.hero.life = 0 && b.enemy.life = 0 then Draw
        else if b.hero.life = 0 then EnemyVictory
        else if b.enemy.life = 0 then HeroVictory
        else Stalemate
  in
  b.winner <- Some outcome;
  emit b (BattleEnd outcome);
  b

let create ?(rules = default_rules) ?(rng = Random.int) ?(hero_spells = [])
    ?(enemy_spells = []) ?(effects = []) (board : board) (hero : combatant)
    (enemy : combatant) : battle =
  if hero.id = enemy.id then invalid_arg "Battle.create: combatants need distinct ids";
  {
    rules;
    board;
    hero;
    enemy;
    tm = initialise [ hero; enemy ];
    turns_elapsed = 0;
    mana_burns = 0;
    winner = None;
    log = [];
    rng;
    hero_spells;
    enemy_spells;
    effects;
  }

let element_name = function
  | Earth -> "earth"
  | Fire -> "fire"
  | Air -> "air"
  | Water -> "water"

let format_event = function
  | TurnStart (slot, side, name) ->
      Printf.sprintf "turn %2d  [%s] %s" slot
        (match side with Hero -> "hero" | Enemy -> "enemy")
        name
  | ExtraTurn name -> Printf.sprintf "             %s replays" name
  | SpellCast (who, id) -> Printf.sprintf "             %s casts %s" who id
  | SpellHeld who -> Printf.sprintf "             %s holds" who
  | Swap (x, y, d) ->
      Printf.sprintf "             swap (%d,%d) %s" x y
        (match d with Horizontal -> "right" | Vertical -> "down")
  | MatchResolved (n, r) ->
      Printf.sprintf "             step %d: %d damage" n r.damage
  | BankedTurn who -> Printf.sprintf "             %s banks a free turn" who
  | SizeTurn who -> Printf.sprintf "             %s earns an extra turn" who
  | ManaBurn -> "             no moves: mana burn"
  | Refilled -> "             board refilled"
  | ManaGained (who, e, amount) ->
      Printf.sprintf "             %s banks %d %s" who amount
        (element_name (match e with 0 -> Earth | 1 -> Fire | 2 -> Air | _ -> Water))
  | Damage (who, amount) -> Printf.sprintf "             %s takes %d" who amount
  | Death who -> Printf.sprintf "             %s falls" who
  | TurnEnd n -> Printf.sprintf "turn %2d  ." n
  | BattleEnd o ->
      Printf.sprintf "result: %s"
        (match o with
        | HeroVictory -> "hero victory"
        | EnemyVictory -> "enemy victory"
        | Draw -> "draw"
        | Stalemate -> "stalemate")

let print_log (b : battle) : unit =
  List.iter (fun e -> print_endline (format_event e)) (log_of b)
