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
  extra_turns_enabled : bool;  (** initial value of the +0x391 board flag *)
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
  (** The three board bonus flags, mutable and shared with the spell effect
      context. [rules.extra_turns_enabled] seeds the first of them; the other two
      start on. See [Spell.multiplier_flags] for the recovered offsets. *)
  multipliers : Spell.multiplier_flags;
  hero_spells : spell list;
  enemy_spells : spell list;
  effects : effect_def list;
  (* The per-turn spell latch [DISALLOW_SPELLS_THIS_TURN] raises. It is battle state
     rather than combatant state because it is about {e this turn}: cleared at the
     top of every turn and set again by Blinded's start-turn hook. See
     [Combat.battle_state]. *)
  effect_state : battle_state;
  (* Equipped items, per side. These live on the battle rather than on the
     combatants because [Item] depends on [Combat], so a loadout cannot be named
     from inside [Combat] without a cycle. The battle is also the only thing that
     knows which side is which.

     Two fields rather than a map keyed by combatant id, matching the existing
     hero/enemy shape. That is correct for the one-on-one case and is the thing
     to revisit first if co-op rosters ever arrive. *)
  hero_items : Item.loadout;
  enemy_items : Item.loadout;
}

(** The loadout belonging to whichever side [c] is on. *)
let loadout_of (b : battle) (c : combatant) : Item.loadout =
  if c.id = b.hero.id then b.hero_items else b.enemy_items

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
  let trained = min b.rules.hero_skill_cap ((skill_in (skill_of_element e) c.skills)) in
  (* Fear halves and Enraged folds in the Fire pool, so the trained value is the
     starting point rather than the answer. This is the only read of a skill that
     goes through the status effects. *)
  query_skill c b.effects ~k:(skill_of_element e) ~roll:b.rng ~battle:b.effect_state trained

(** Credits mana and rolls for the extra turn, once per matched run.

    The roll is per run rather than per gem, which is the whole of the
    playtesting observation: a 4-run in one element is one roll at the doubled
    yield, not two rolls at the single rate. *)
let credit_run (b : battle) (attacker : combatant) (e : element) (n : int) : unit =
  let gained = mana_yield ~skill:(skill_of attacker b e) ~run_length:n in
  (* The original accumulates in float and the pools are integers, so the credit
     truncates. [credit_mana] also stops at the element's ceiling, which is what
     the AI's "is the pool full" test depends on. *)
  let banked = credit_mana attacker e (int_of_float gained) in
  emit b (ManaGained (attacker.name, element_index e, banked));
  if
    extra_turn_roll ~gained ~pending:b.tm.extra_turn_pending
      ~enabled:b.multipliers.Spell.extra_turn_chance ~roll:b.rng
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
    match resolve_matches ~wildcards_enabled:b.multipliers.Spell.wildcard_chance b.board with
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
     once per swap, and the original's ADD_GOLD and ADD_XP both accumulate.

     The xp total goes through [receive_xp] first, because Favored's
     [OnReceiveXP] converts a share of it into healing on the spot rather than
     into a later award. The battle total still gets the {e whole} amount: the
     hook returns the value unchanged and only adds life, so nothing is lost
     either way. *)
  b.gold <- b.gold + !gold;
  b.xp <- b.xp + receive_xp attacker b.effects ~enemies:[ defender ] ~roll:b.rng
      ~battle:b.effect_state !xp;
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
        (* Two chains run, and within each the attacker's side is the inner one.

           The order matters and is not arbitrary. For a given combatant the
           original runs GIVE_DAMAGE before RECEIVE_DAMAGE, so an item that
           amplifies what it deals and an item that reduces what it takes compose
           as amplify-then-reduce rather than the other way round. Across the two
           combatants it runs the attacker's chain first, so the defender's
           receive hooks see the already-amplified number. *)
let attacker = attacker_of b defender in
        let ictx =
          Item.
            {
              ic_board = Some b.board;
              ic_percentile = b.rng 100;
              ic_roll = b.rng;
              ic_attacker = Some attacker;
              ic_defender = Some defender;
              ic_hero = b.hero;
              ic_enemy = b.enemy;
            }
        in
        (* Items first, then status effects, each as its own chain.

           The {e relative} order of an item hook against a status-effect hook is
           not recovered: the original dispatches both through the same
           name-based callback table, and nothing in the binary or the scripts
           fixes whether a character's worn item runs before or after the status
           effects on it. Items are placed first here on the assumption that
           equipment is the more persistent modifier, and this comment is the
           record of that being a choice rather than a recovery.

           What {e is} recovered is the order across the two combatants: the
           attacker's chain runs before the defender's, so a defender's
           reduction sees the already-amplified number. *)
        let outgoing =
          give_damage ~attacker ~defender b.effects ~enemies:[ defender ] ~roll:b.rng
            ~battle:b.effect_state
            (Item.fold_give_damage (loadout_of b attacker) ictx ~damage:dealt
               ~source:attacker.id ~target:defender.id
               ~f:(fun (i : Item.item) n -> Item.give_damage i ictx ~damage:n
                     ~source:attacker.id ~target:defender.id))
        in
        let taken =
          receive_damage ~defender ~attacker b.effects ~enemies:[ attacker ] ~roll:b.rng
            ~battle:b.effect_state
            (Item.fold_receive_damage (loadout_of b defender) ictx ~damage:outgoing
               ~source:attacker.id ~target:defender.id
               ~f:(fun (i : Item.item) n -> Item.receive_damage_hook i ictx ~damage:n
                     ~source:attacker.id ~target:defender.id))
        in
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

(** Builds the context the AI spell hooks are evaluated against.

    [EVALUATE_BOARD] and [PERCENTILE_CHANCE_SYNC] are read once here rather than
    per spell: [Std_AISpellcastingChance] consults both, neither changes within a
    turn, and evaluating the board once per candidate would both cost more and
    consume the board's rng differently depending on the spell list.

    [PERCENTILE_CHANCE_SYNC] returns 0..99, which is what the Lua compares
    against, so the range here has to stay 100 to match.

    Both values are passed in rather than read here, because [take_action] draws
    the percentile once per turn and hands the same number to the effect context.
    Reading it twice would consume two rolls and let the effect see a different
    value from the one the AI hook decided on. *)

(** [EVALUATE_BOARD]: the score of the best move available to the acting side. *)
let board_evaluation (b : battle) : int =
  let e =
    evaluate_board ~weights:b.rules.ai_weights ~rng:b.rng ~difficulty:b.rules.difficulty
      ~hero:{ level = b.rules.hero_level; level_cap = b.rules.hero_level_cap }
      (ai_view b)
  in
  if e.has_valid_move then e.best_score else 0

let ai_context (b : battle) (actor : combatant) (defender : combatant)
    ~(percentile : int) ~(evaluation : int) : Spell.ai_context =
  Spell.
    {
      ctx_caster = actor;
      ctx_enemy = defender;
      (* A [battle] is one hero against one monster, so GET_NUM_ENEMIES is
         always 1 here and SSWP's loop over the enemy side has a single
         iteration. Keeping it a list rather than hardcoding that means the
         hook reads the same as the Lua when a multi-enemy fight is added. *)
      ctx_enemies = [ defender ];
      ctx_board = b.board;
      ctx_evaluation = evaluation;
      ctx_percentile = percentile;
      ctx_roll = b.rng;
      ctx_items = Some (loadout_of b actor);
      ctx_enemy_items = Some (loadout_of b defender);
    }

(** The context a [CastSpell] body runs against.

    [fx_board] is a reference to the battle's own cell rather than a copy, which
    is what lets a spell's board edits survive the call. [fx_gold] and [fx_xp] are
    likewise shared, because they belong to the battle rather than to either
    combatant. *)
let effect_context (b : battle) (actor : combatant) (defender : combatant)
    (s : Spell.spell) (p : int) : Spell.effect_context =
  { Spell.fx_caster = actor
  ; Spell.fx_enemies = [ defender ]
  ; Spell.fx_board = ref b.board
  ; Spell.fx_roll = b.rng
  ; Spell.fx_gold = ref b.gold
  ; Spell.fx_xp = ref b.xp
  ; Spell.fx_input = None
  ; Spell.fx_items = Some (loadout_of b actor)
  ; Spell.fx_enemy_items = Some (loadout_of b defender)
  ; Spell.fx_flags = b.multipliers
  ; Spell.fx_spell = Some s
  ; Spell.fx_percentile = p
  }

(** One turn for the acting side: at most one spell, then a swap only if the
    spell handed the turn back.

    Two things are easy to get wrong here.

    Casting usually {e consumes} the turn, so a spell that ends it means no swap
    that turn either. An earlier version always swapped, which is right for the
    13 spells that keep the turn and wrong for the other 116.

    And the spell choice is not "first affordable". Every spell carries its own
    [ShouldAICastSpell], which reads the board, the caster's mana, and the
    percentiles, and the first spell that votes yes wins. The caller does not
    get a say beyond the difficulty skip inside [Spell.pick_ai_spell]. *)
let take_action (b : battle) (actor : combatant) (defender : combatant)
    (spells : spell list) : unit =
  (* One percentile draw for the whole turn, and it is drawn {e after} the board
     evaluation as before, so the random stream is consumed in the order it
     always was. Both the AI hook and the effect read this same value: [STAU]
     picks which of the caster's pools to drain from it, so a second draw would
     have the spell drain a different element than the one its own AI hook just
     reasoned about. *)
  let evaluation = board_evaluation b in
  let percentile = b.rng 100 in
  let still_turn =
    match pick_ai_spell ~difficulty:b.rules.difficulty ~roll:b.rng
            ~spells_disallowed:b.effect_state.Combat.spells_disallowed
            (ai_context b actor defender ~percentile ~evaluation) spells with
    | None ->
        (* Nothing cast, so the turn is the caster's to use. *)
        emit b (SpellHeld actor.name);
        true
    | Some s ->
        (* The AI hook has already run, so every mana-gated decision - including the
           conditional turn rules - saw the pool the caster has rather than the
           pool left afterwards. The {e charge} happens at the end; see
           [Spell_effects.handle_spell_cost] for why. *)
        let keeps = keeps_turn actor s in
        start_cooldown actor s;
        s.use_count <- s.use_count + 1;
        s.Spell.cost_charged <- false;
        (* [NOTIFY_OF_FREE_SPELL] latches on the combatant rather than on the
           spell, so it is read {e before} the body runs: a body that sets the flag
           is granting the spell after this one, not refunding this one. *)
        let was_free = actor.next_spell_free in
        actor.next_spell_free <- false;
        emit b (SpellCast (actor.name, s.id));
        (* The effect runs before the charge. That is the normal case and it makes
           no difference, but ten spells open with "Charge the mana first" and
           subtract their own costs via [HANDLE_SPELL_COST], which sets
           [cost_charged] and suppresses the charge below. Paying first would
           charge those twice - [SIST] costs 60 mana, and 120 is not a number the
           game could intend. *)
        (match s.Spell.cast_spell with
        | Some f ->
            let fx = effect_context b actor defender s percentile in
            f fx;
            (* A board sweep empties cells; the board has to resolve them before
               the next move or the grid is left short of gems. *)
            b.board <- Board.apply_gravity b.board;
            b.board <- Board.refill_board ~rng:b.rng b.board;
            if actor.is_dead then emit b (Death actor.name)
        | None -> ());
        (* Charged last, and only if the body did not charge itself. See
           [Spell_effects.handle_spell_cost]. The free-spell latch suppresses it
           the same way. *)
        if not s.Spell.cost_charged && not was_free then pay_cost actor s;
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
    run_start_of_turn_effects actor b.effects ~turn:b.turns_elapsed ~enemies:[ defender ]
      ~roll:b.rng ~battle:b.effect_state;
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

(** [effects] defaults to the seventeen real status effects rather than to none.
    It has to: a battle where nothing implements a status effect is a battle where
    Poison does not tick and Hidden does not double anything, which is a silent
    wrong answer rather than an absent feature. A caller that wants the table
    inert says [~effects:[]]. *)
let create ?(rules = default_rules) ?(rng = Random.int) ?(hero_spells = [])
    ?(enemy_spells = []) ?(effects = Status_effect_hooks.descriptors) ?hero_items
    ?enemy_items (board : board) (hero : combatant) (enemy : combatant) : battle =
  if hero.id = enemy.id then invalid_arg "Battle.create: combatants need distinct ids";
  (* [IS_MONSTER(idx)] is a property of the character rather than of the spell, so
     it is set here rather than asked of every fixture: a [Battle] is one hero
     against one monster, and [SRGN] is the only script that reads the flag. *)
  enemy.is_monster <- true;
  hero.is_monster <- false;
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
    multipliers =
      { Spell.wildcard_chance = true
      ; extra_turn_chance = rules.extra_turns_enabled
      ; damage_multiplier = true
      };
    hero_spells;
    enemy_spells;
    effects;
    effect_state = { Combat.spells_disallowed = false };
    hero_items = (match hero_items with Some l -> l | None -> Item.new_loadout ());
    enemy_items = (match enemy_items with Some l -> l | None -> Item.new_loadout ());
  }

(** Puts [i] on [c]'s side, if [c] may wear it. Returns the item it displaced, or
    [None]. Used at battle setup rather than mid-fight, so there is no turn cost
    to model. *)
let give_item (b : battle) (c : combatant) ~(level : int) (i : Item.item) :
    Item.item option =
  if Item.can_equip c ~level i then Item.equip (loadout_of b c) i else None

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



