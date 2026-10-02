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
  | SizeTurn of string
  | HeroicEffort of string
  | GoldGained of string * int
  | XpGained of string * int
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
  (* Cascade depth at which Heroic Effort fires. The recovered value is 5, from
     the counter test in [FUN_0047AE80]. Exposed as a rule because a five-deep
     chain is impractical to hand-build for a test, and the accounting around it
     is what needs proving. *)
  heroic_effort_depth : int;
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
    heroic_effort_depth = 5;
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
  mutable gold : int;  (** won across the battle, as [Engine_ADD_GOLD] would *)
  mutable xp : int;
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

(** The side dealing damage, which is whoever is not [defender]. *)
let attacker_of (b : battle) (defender : combatant) : combatant =
  if defender.id = b.enemy.id then b.hero else b.enemy

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

    A character's skill is a separate field from its mana balance in the
    original: the extra turn roll reads the skill, so a character sitting on a
    large unearned pool rolls no better than its training justifies. Clamped to
    [rules.hero_skill_cap] because the original clamps at 999 before computing
    the yield. *)
let skill_of (c : combatant) (b : battle) (e : element) : int =
  min b.rules.hero_skill_cap (skill_in e c.skills)

(** Credits mana and rolls for the extra turn, once per matched run.

    The roll is per run rather than per gem, which is the whole of the
    playtesting observation: a 4-run in one element is one roll at the doubled
    yield, not two rolls at the single rate. *)
let credit_run (b : battle) (attacker : combatant) (e : element) (n : int) : unit =
  let gained = mana_yield ~skill:(skill_of attacker b e) ~run_length:n in
  (* The original accumulates in float and the pools are integers, so the credit
     truncates. *)
  let banked = int_of_float gained in
  attacker.mana <- add_mana e banked attacker.mana;
  emit b (ManaGained (attacker.name, element_index e, banked));
  if
    extra_turn_roll ~gained ~pending:b.tm.extra_turn_pending
      ~enabled:b.rules.extra_turns_enabled ~roll:b.rng
  then begin
    b.tm.extra_turn_pending <- false;
    grant_extra_turn b.tm attacker.id;
    emit b (BankedTurn attacker.name)
  end

(** Resolves every match, cascading until quiet. Returns the total damage.

    Matching, Red Skull explosions, 5-run wildcards, gold and XP all come from
    [Board.resolve_matches] rather than a second implementation here: an earlier
    version of this loop hand-rolled the matcher to get at the run groupings, and
    silently dropped explosions, wildcards, gold and XP along the way. The board
    now reports its own [MatchResult.runs], so there is one matcher. *)
let resolve_cascades (b : battle) (defender : combatant) : int =
  let attacker = attacker_of b defender in
  let step = ref 0 in
  let total = ref 0 in
  let gold = ref 0 and xp = ref 0 in
  let going = ref true in
  while !going do
    match resolve_matches b.board with
    | None -> going := false
    | Some (cleared, res) ->
        incr step;
        (* Damage is the board's, since only it knows which gems the explosion
           sweep pulled in. *)
        total := !total + res.damage;
        gold := !gold + res.gold;
        xp := !xp + res.xp;
        (* Mana and the extra turn roll are per run, from the board's grouping. *)
        List.iter
          (fun (coords, g) ->
            let n = List.length coords in
            (match element_of_gem g with
            | Some e -> credit_run b attacker e n
            | None -> ());
            (* A 4- or 5-of-a-kind grants a deterministic extra turn, independent
               of the stat roll. *)
            if b.rules.size_patterns && n >= 4 then begin
              grant_extra_turn b.tm attacker.id;
              emit b (SizeTurn attacker.name)
            end)
          res.runs;
        emit b (MatchResolved (!step, res));
        if res.gold > 0 then emit b (GoldGained (attacker.name, res.gold));
        if res.xp > 0 then emit b (XpGained (attacker.name, res.xp));
        b.board <- cleared;
        refill b
  done;
  (* Heroic Effort: the original's [FUN_0047AE80] fires when a swap's cascade
     counter reaches 5, awarding +100 XP and an extra turn. The counter is the
     per-swap step number and starts at 1 for the first step, so the award is for
     a chain of five or more. [Sub_47ae80.c] in docs/decompiled/mana_burn is the
     decompilation; it also shows steps 0 and 1 only picking a cascade sound,
     which is why the test is silent for the first two. *)
  if !step >= b.rules.heroic_effort_depth then begin
    (* Additive: [Sub_47ae80.c] calls [Engine_ADD_XP](100) as a separate call
       from the per-match xp harvest, so a chain that also collected xp gems
       banks both. *)
    xp := !xp + 100;
    grant_extra_turn b.tm attacker.id;
    emit b (HeroicEffort attacker.name)
  end;
  (* Added to the battle's running totals rather than assigned: this is called
     once per swap, and the original's ADD_GOLD and ADD_XP both accumulate. *)
  b.gold <- b.gold + !gold;
  b.xp <- b.xp + !xp;
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
        (* Both hook chains run: the attacker's GIVE_DAMAGE first, then the
           defender's RECEIVE_DAMAGE. Order matters, since a pair of effects
           that amplify and reduce cancel out differently depending on which
           sees the other's number first. The original's receive hook is the
           outer one, since it is the defender's armour. *)
        let outgoing = give_damage (attacker_of b defender) b.effects dealt in
        let taken = receive_damage defender b.effects outgoing in
        defender.life <- max 0 (defender.life - taken);
        (* The defeat sweep keys off the flag, not the life total, so it has to
           be raised here or nobody is ever reported dead. *)
        if defender.life < 1 then defender.is_dead <- true;
        emit b (Damage (defender.name, taken))
      end
  | _ ->
      (* No legal move. The original regenerates the board and calls it Mana Burn;
         see [Board.reshuffle], which also explains why filling empty cells is
         not enough. *)
      b.mana_burns <- b.mana_burns + 1;
      emit b ManaBurn;
      b.board <- reshuffle ~rng:b.rng b.board;
      emit b Refilled

(** One turn for the acting side: at most one spell, then a swap only if the
    spell handed the turn back.

    This is the part that is easy to get wrong. Casting usually {e consumes} the
    turn, so a spell that ends it means no swap that turn either. An earlier
    version always swapped, which is right for the 13 spells that keep the turn
    and wrong for the other 116.

    Whether the turn is kept belongs to the spell, not to the caster's intent: the
    original's spell picker has no opinion about it at all, it just takes the
    first affordable spell and lets the spell's own rule decide. So nothing here
    consults the AI. *)
let take_action (b : battle) (actor : combatant) (defender : combatant)
    (spells : spell list) : unit =
  let still_turn =
    match pick_spell ~difficulty:b.rules.difficulty ~roll:b.rng actor spells with
    | None ->
        (* Nothing cast, so the turn is the caster's to use. *)
        emit b (SpellHeld actor.name);
        true
    | Some s ->
        (* The mana check runs before the cost is paid: the conditional spells
           test the pool the caster has, not the pool left afterwards. *)
        let keeps = keeps_turn actor s in
        pay_cost actor s;
        start_cooldown actor s;
        s.use_count <- s.use_count + 1;
        emit b (SpellCast (actor.name, s.id));
        keeps
  in
  if still_turn then play_move b defender

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
    (* Cooldowns count the caster's own turns, so this is the natural tick: by
       the time the next turn starts the spell that was just cast has one fewer
       turn left. Ticking after the cast rather than before means a cooldown of
       3 blocks the next two casts, not three. *)
    tick_cooldowns actor;
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
    gold = 0;
    xp = 0;
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
  | HeroicEffort who ->
      Printf.sprintf "             %s: heroic effort (+100 xp, extra turn)" who
  | GoldGained (who, n) -> Printf.sprintf "             %s picks up %d gold" who n
  | XpGained (who, n) -> Printf.sprintf "             %s gains %d xp" who n
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
