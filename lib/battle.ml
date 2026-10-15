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
  | MissedTurn of string  (** the actor sat this one out under [Missed] *)
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

(** A human at the keyboard.

    This is deliberately two hooks and nothing more. The recovered engine has no
    player input at all - both sides are driven by [Spell.pick_ai_spell] and the
    board evaluator - so rather than bolt a front end onto that, the only thing
    replaced is {e selection}: which spell to cast and which swap to make.
    Everything after the choice is untouched, so a human turn goes through the
    same cost charge, cooldown tick, keeps-turn test and effect body as a
    machine one.

    The hooks deliberately do not take the [battle]. That would make [player] and
    [battle] mutually recursive, and it is not needed: a front end that wants to
    show the board closes over a [battle ref] it fills in after [create] returns.

    [choose_spell] receives only the spells that are actually available, and
    returning [None] holds the spell and falls through to the swap.

    [choose_aim] is the second half of a cast whose spell asks for a target
    (a non-zero [input_type]). It runs just after [choose_spell] picks the
    spell and before the body does, and [None] means "run as if nothing was
    aimed" - which for these spells is a no-op, so a front end that cannot
    ask should say [None] rather than guess a cell. *)
type player = {
  choose_spell : spell list -> spell option;
  choose_aim : spell -> Board.position option;
  choose_swap : swap list -> swap option;
}

type rules = {
  difficulty : int;
  (** 0 easy, 1 normal, 2 hard - the player's Difficulty option, not a level
      band; see [Campaign.difficulty] and [Spell.difficulty_for_levels] *)
  time_limit : int;
  (** 0 none, 1 16 sec, 2 12 sec, 3 8 sec, 4 4 sec - the player's Turn Time
      Limit option, the other dropdown the hero view offers beside Difficulty.
      This is the battle-start copy of it: the engine writes the setting into
      turn_manager+0x34 at start (Sub_44a780.c:651, in the same function that
      copies Difficulty into CBattleManager+0x48), the turn clock's delay table
      reads it ({0,16000,12000,8000,4000} ms, matching [TIMELIMIT0..4]), and
      the victory spoils pay (setting x 5)% for it. The port copies it into the
      rules for the same reason Difficulty rides here, but models no turn clock
      yet - so nothing in the loop reads it; see Campaign.timelimit. *)
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
  (* [None] - the default - leaves the recovered AI in charge of both decisions,
     which is what every faithful test and the headless runner rely on. *)
  player : player option;
}

let default_rules =
  {
    difficulty = 1;
    time_limit = 0;
    hero_level = 10;
    hero_level_cap = 20;
    max_turns = 200;
    extra_turns_enabled = true;
    size_patterns = true;
    hero_skill_cap = 999;
    heroic_effort_depth = 5;
    ai_weights = Ai.default_weights;
    player = None;
  }

(** The turn clock's delay table, from [FUN_00464d70] - the recovered millisecond
    budget a Time Limit setting buys for one turn.

    The engine indexes it with turn_manager+0x34 (the Time Limit setting, the same
    field the spoils read): `{0, 16000, 12000, 8000, 4000}` ms for
    [TIMELIMIT0..4] (None/16/12/8/4 sec), and a negative value means custom
    seconds (`n * -1000`), which is how a Lua-set limit rides the same field. The
    port's setting is clamped to 0..4, so the negative arm is what the original
    can express but a port driver will not produce - kept because the table is
    the recovery, not the port's clamp. *)
let time_limit_delay_ms (time_limit : int) : int =
  if time_limit < 0 then time_limit * -1000
  else
    match time_limit with
    | 1 -> 16000
    | 2 -> 12000
    | 3 -> 8000
    | 4 -> 4000
    | _ -> 0  (* 0 (None) and anything past the fifth row *)

(** The countdown as the plates show it: `"%02d"` of the remaining seconds,
    computed the way [FUN_0040F7D0] does - `(ms + 900) / 1000`, so a full 16 s
    reads 16 and it drops to 0 only in the last 100 ms. *)
let clock_secs_of_ms (ms : int) : int = (ms + 900) / 1000

(** One visible step of a turn, with the board states needed to animate it.

    Separate from [event] on purpose. An event says *what happened*; a step says
    *what the board looked like before and after*, which is a different thing and
    arrives at a different time. `MatchResolved` fires while the matched gems are
    still on the board; the animation needs the board with them gone, and then the
    board after gravity has pulled everything down.

    The three states in a cascade are all necessary and none is derivable from the
    others:

    - [before] - the board as the player last saw it, with the matches still in it.
    - [cleared] - the matches removed, gravity *not yet applied*. This is the state
      with the gaps in it, and it is what a match pop resolves to.
    - [after] - gravity applied and the gaps refilled. What a cascade fall resolves
      to, and what the next step's [before] will be.

    [Board.board] is persistent, so holding on to these costs nothing but a
    reference. *)
type step =
  | Swapped of {
      before : board;
      after : board;
      a : Board.position;
      b : Board.position;
    }
  | Cascaded of {
      step : int;
      before : board;
      cleared : board;
      after : board;
      runs : (Board.position list * Board.gem) list;
    }

(** A spell's request for an effect on one grid cell: `Std_GridSpellEffect`.

    The cell and the constant are both the spell's, and the caster's name is
    carried because the effect is aimed at the caster's *side* of the board in the
    common case - `Std_EnemySpellEffect` aims at the other one - and a front end
    showing a sparkle needs to know which side that is without also holding the
    spell table. *)
type grid_fx = {
  grid_fx_cell : Board.position;
  grid_fx_effect : Spell_fx.fx;
  grid_fx_caster : string;
}

type battle = {
  rules : rules;
  mutable board : board;  (** 8x8, all rows playable *)
  hero : combatant;
  enemy : combatant;
  tm : turn_manager;
  mutable turns_elapsed : int;
  mutable mana_burns : int;
  (* The turn clock: the Time Limit setting copied into the rules at battle start
     (the turn_manager's +0x34 analogue) buys a per-turn budget through
     [time_limit_delay_ms], and each turn arms a deadline from it - the
     +0x38/+0x3c pair. [clock_now_ms] is the wall millisecond tick the engine
     read from DAT_0057f484, which the battle cannot read itself (it has no
     clock) so the front end feeds it; [clock_deadline_ms] is [Some] while a
     human's own decision is being timed and [None] while the AI acts - the
     original gates the countdown on the acting character being a player, and
     the AI's instant turns disarm it. Expiry is the front's to notice: see
     [clock_expired]. *)
  mutable clock_now_ms : int;
  mutable clock_deadline_ms : int option;
  mutable gold : int;  (** won across the battle, as [Engine_ADD_GOLD] would *)
  mutable xp : int;
  mutable winner : outcome option;
  (* The battle's narration, newest first. See [Battle.log_of] to read it in
     order. *)
  mutable log : event list;
  (** Called as each event happens, rather than the log being read back afterwards.

      [None] - the default - means exactly what it meant before this existed: the
      log accumulates and nothing observes it. Setting it costs the recovered code
      path nothing, because [emit] was already the single place an event is
      recorded, so this is a second call at a point that already existed rather
      than a new interposition in the battle logic.

      What it buys is *ordering*. Reading the log after a turn hands a
      presentation layer every event in that turn at once, so it replays a burst;
      being called as they occur gives the same events in sequence.
      [MatchResolved] is already emitted once per cascade step and carries which
      runs matched, so cascades arrive individually with no further change here.

      It lives on the battle rather than in [rules] because a rule is how the fight
      is played and this is who is watching it - and because [rules] and [battle]
      refer to each other, so a callback mentioning [battle] cannot be a field of
      [rules]. It is mutable so a front end can attach one after [create], which is
      the only point at which the battle exists to hand it.

      The callback receives the battle as it stands at that moment, so it can read
      live state - the board, the mana pools, whose turn it is - instead of
      reconstructing them. It must not mutate the battle. *)
  mutable on_event : (battle -> event -> unit) option;
  (** Called as each {e visible} step of a turn happens, with the board states
      around it. See [step].

      This is the second half of the presentation seam, and it exists because
      [on_event] cannot carry it: an event is a fact, and animating a cascade needs
      the boards on either side of it. Kept as a separate callback rather than
      folded into the event type so that the log stays a log - putting a board in
      every event would make reading it a rendering concern, and every faithful
      test that inspects the log would have to know about it.

      Defaults to [None] and costs one branch at each of the three points it is
      called, so an unwatched battle resolves exactly as it did before. *)
  mutable on_step : (battle -> step -> unit) option;
  (** Called when a spell asks for an effect on a grid cell.

      Thirteen call sites across eleven spells do, and the *cell* is the whole
      point: it comes from the spell body, which is where the game gets it, so it
      cannot be recovered from the script's text and cannot be guessed by a front
      end. Routing it through the battle is what keeps that true - a front end that
      tried to work out where a sparkle went would be reconstructing the spell's
      control flow.

      A separate observer rather than an event, for the reason [on_step] is: this is
      not something that happened, it is something that should be shown. Putting a
      board cell in every log entry would make reading the log a rendering concern.

      Defaults to [None], and the spell body then does nothing - so a headless
      battle, and every faithful test, are unaffected. *)
  mutable on_grid_fx : (grid_fx -> unit) option;
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

(** Record an event, and tell the observer about it if there is one.

    This was a one-liner that consed onto the log. It is still that, plus an
    optional callback - see [Battle.rules.on_event] for why the callback lives
    here and what it is for.

    The order matters and is deliberate: the event is on the log {e before} the
    observer runs, so an observer that reads [log_of] sees the event it was handed
    and everything before it. An observer reading a log that does not yet contain
    the event it was just given is the kind of off-by-one that only shows up as a
    message appearing one step late. *)
let emit (b : battle) (e : event) =
  b.log <- e :: b.log;
  match b.on_event with
  | None -> ()
  | Some f -> f b e
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

(* ------------------------------------------------------------------ *)
(* Item hooks: the context they run in, and the six dispatch points     *)
(* ------------------------------------------------------------------ *)

(** The other side of a one-on-one fight. The item natives that act on someone
    else - [Std_InflictDamage] - want the enemy of the character the hook is
    running for, and a battle here is one hero against one monster, so that pair
    is the whole answer. *)
let opponent_of (b : battle) (c : combatant) : combatant =
  if c.id = b.hero.id then b.enemy else b.hero

(** [Std_InflictDamage(amt, idx)]: direct damage to [self]'s enemy, which is
    what IJAH, ISTL and IWHP reach for when a mana credit lands on them.

    It does not run the damage hooks, matching [Spell_effects.subtract_life],
    which does not either, and it raises [is_dead] the way that one does so the
    sweep at the end of the turn can see the kill. It emits, because a life
    total that moves with nobody told about it is the kind of silent change the
    log exists to catch. *)
let inflict_from_hook (b : battle) (self : combatant) (n : int) : unit =
  if n <= 0 then ()
  else begin
    let target = opponent_of b self in
    target.life <- max 0 (target.life - n);
    if target.life < 1 then target.is_dead <- true;
    emit b (Damage (target.name, n))
  end

(** The context an item hook runs in outside a damage event.

    [ic_percentile] is the battle's rng behind a closure rather than a number:
    [PERCENTILE_CHANCE_SYNC] draws per call, so a body that asks gets a fresh
    roll and a body that does not ask costs none - which is what keeps the rng
    stream of a fight whose items never ask exactly as it was. Everything a
    body can do is either read through [ic_self] or one of the callbacks, which
    are bound to [self] and to {e this} battle: that binding is what lets a body
    credit a second pool and have that credit run the mana fold again, the way
    the ADD_MANA native would.

    [ic_credit_xp] and [ic_credit_gold] go through the status-effect fold too,
    so a hook that banks experience lands on Favored exactly as the per-match
    experience does. *)
let rec item_context (b : battle) ~(self : combatant) : Item.item_context =
  {
    Item.ic_board = Some b.board;
    ic_percentile = (fun () -> b.rng 100);
    ic_roll = b.rng;
    ic_attacker = None;
    ic_defender = None;
    ic_hero = b.hero;
    ic_enemy = b.enemy;
    ic_self = self;
    ic_level =
      (if self.Combat.id = b.hero.Combat.id then Some b.rules.hero_level else None);
    ic_credit_mana = (fun e n -> ignore (receive_mana b self e n));
    ic_credit_gold = (fun n -> ignore (receive_gold b self n));
    ic_credit_xp = (fun n -> ignore (receive_xp b self n));
    ic_extra_turn = (fun () -> grant_extra_turn b.tm self.id);
    ic_inflict_damage = (fun n -> inflict_from_hook b self n);
    ic_heal = (fun n -> Spell_effects.healing self n);
    ic_apply_status =
      (fun target id ->
        match List.find_opt (fun (d : effect_def) -> d.id = id) b.effects with
        | Some d -> Spell_effects.apply_status target id d.duration
        | None -> ());
    (* MISS_TURNS, which lands as the [Missed] pseudo-status - see
       [spend_missed_turn] for where the loop spends it. *)
    ic_miss_turns = (fun target n -> Spell_effects.miss_turns target n);
    (* The board is the battle's, written through the same way the spell
       bodies write [fx_board]: a value swapped into [b.board], so the write
       survives the callback. Gravity is not part of [DESTROY_GEM] here - it
       runs when the event that fired the hook gets back to the grid, exactly
       as it does after a spell body. *)
    ic_set_gem = (fun p g -> b.board <- Board.set_gem p g b.board);
    ic_destroy_gem = (fun p -> b.board <- Board.set_gem p Board.Empty b.board);
    ic_multipliers =
      (fun on ->
        b.multipliers.Spell.wildcard_chance <- on;
        b.multipliers.Spell.extra_turn_chance <- on;
        b.multipliers.Spell.damage_multiplier <- on);
  }

(** [OnReceiveMana]: fold the receiver's own items over the offered amount,
    then bank what they turned it into, stopping at the ceiling as the native
    does. Returns what was actually banked, which is what the [ManaGained]
    event reports.

    The fold runs against a context whose [ic_credit_mana] is {e this} function,
    so IBFH crediting a second pool re-enters it - the recursion the Lua gets
    for free by calling ADD_MANA_EARTH from inside OnReceiveMana. It terminates
    because every such body credits a shrinking share of a share; see
    [Item_hooks.hook_ring]. *)
and receive_mana (b : battle) (c : combatant) (e : element) (n : int) : int =
  if n <= 0 then 0
  else begin
    let v =
      Item.fold_receive_mana (loadout_of b c) (item_context b ~self:c) ~value:n ~e
    in
    (* [bank_mana], not [credit_mana]: this fold {e is} the hook [credit_mana]
       dispatches to, and calling the dispatcher back would re-enter it. *)
    Combat.bank_mana c e v
  end

(** [OnReceiveGold]: fold, then bank into the battle's running total, which is
    what [Campaign] settles into the player's purse at the end. Returns what was
    added, so the spell write-back can report the same number. *)
and receive_gold (b : battle) (c : combatant) (n : int) : int =
  if n <= 0 then 0
  else begin
    let v = Item.fold_receive_gold (loadout_of b c) (item_context b ~self:c) ~value:n in
    b.gold <- b.gold + v;
    v
  end

(** [OnReceiveXP]: the items fold first, then the status effects, which is the
    inner-then-outer order the damage chain runs in - the item hook is the more
    specific modifier and the status effect the wrapper over it. Returns what
    was banked. *)
and receive_xp (b : battle) (c : combatant) (n : int) : int =
  if n <= 0 then 0
  else begin
    let v = Item.fold_receive_xp (loadout_of b c) (item_context b ~self:c) ~value:n in
    let v =
      Combat.receive_xp c b.effects ~enemies:[ opponent_of b c ] ~roll:b.rng
        ~battle:b.effect_state v
    in
    b.xp <- b.xp + v;
    v
  end

(** [OnStartTurn] for whoever is about to act, run before the status effects'
    own start hooks. The split is the unrecovered one the damage chain already
    records: items first, on the reading that equipment is the more persistent
    modifier. *)
let start_turn_item_hooks (b : battle) (actor : combatant) : string list =
  Item.run_start_turn (loadout_of b actor) (item_context b ~self:actor)
    ~turn:b.turns_elapsed

(** The same context, dressed for a damage event: [ic_attacker] and
    [ic_defender] are the two parties the damage bodies name in their
    signatures. [self] differs between the two chains, so the callbacks bound
    inside [item_context] point at the right combatant for each. *)
let damage_context (b : battle) ~(self : combatant) ~(attacker : combatant)
    ~(defender : combatant) : Item.item_context =
  let base = item_context b ~self in
  { base with Item.ic_attacker = Some attacker; ic_defender = Some defender }

(** [OnMatch4] / [OnMatch5] for the side that made the match, and the status
    effects' own pair at the same point - Vigiled is the only implementer there
    and [Combat.run_match_effects] existed for it without a caller. The extra
    turn that makes a four-run special is what the Lua comments tie these hooks
    to, so they fire under the same [size_patterns] gate it does. *)
let match_item_hooks (b : battle) (c : combatant) ~(of_five : bool) : string list =
  Item.run_match (loadout_of b c) (item_context b ~self:c) ~of_five

(** [OnVictory] for the side that won. Fires once, at the moment the winner is
    decided rather than at the end of [run], so a battle that is already over
    cannot run it twice. *)
let victory_item_hooks (b : battle) (winner : combatant) : string list =
  Item.run_victory (loadout_of b winner) (item_context b ~self:winner)

(** The effective skill for any of the seven, the fold [skill_of] takes an
    element out of.

    A character's skill is a separate field from its mana balance in the
    original: the extra turn roll reads the skill, so a character sitting on a
    large unearned pool rolls no better than its training justifies. Clamped to
    [rules.hero_skill_cap] because the original clamps at 999 before computing
    the yield.

    The fold order is the binary's kind-5 query at 0x466610: raw skill, then the
    equipped items' OnQuerySkill hooks, then the active status effects'
    OnQuerySkill hooks, then the temp-skill accumulator at
    record[skillIdx*4 + 0x68]. Level does not fold in (quest.base_value_from_level). *)
let skill_value (c : combatant) (b : battle) (k : skill) : int =
  let trained = min b.rules.hero_skill_cap (skill_in k c.skills) in
  (* Items first, then status effects, then the accumulator - the binary's
     order. Fear halves and Enraged folds in the Fire pool, so the trained
     value is the starting point rather than the answer. *)
  let with_items =
    Item.run_query_skill (loadout_of b c) (item_context b ~self:c) ~k trained
  in
  let with_status =
    query_skill c b.effects ~k ~roll:b.rng ~battle:b.effect_state with_items
  in
  with_status + skill_in k c.temp_skills

(** The skill that drives mana yield for an element: [skill_value] read for the
    element's own skill name. *)
let skill_of (c : combatant) (b : battle) (e : element) : int =
  skill_value c b (skill_of_element e)

(** Credits mana and rolls for the extra turn, once per matched run.

    The roll is per run rather than per gem, which is the whole of the
    playtesting observation: a 4-run in one element is one roll at the doubled
    yield, not two rolls at the single rate. *)
let credit_run (b : battle) (attacker : combatant) (e : element) (n : int) : unit =
  let gained = mana_yield ~skill:(skill_of attacker b e) ~run_length:n in
  (* The original accumulates in float and the pools are integers, so the credit
     truncates. [receive_mana] runs the receiver's OnReceiveMana items over the
     offer first - the ADD_MANA native is what fires them - and [credit_mana]
     inside it stops at the element's ceiling, which is what the AI's "is the
     pool full" test depends on. What it returns, and what the event reports, is
     what was banked after both. *)
  let banked = receive_mana b attacker e (int_of_float gained) in
  emit b (ManaGained (attacker.name, element_index e, banked));
  if
    extra_turn_roll ~gained ~pending:b.tm.extra_turn_pending
      ~enabled:b.multipliers.Spell.extra_turn_chance ~roll:b.rng
  then begin
    b.tm.extra_turn_pending <- false;
    grant_extra_turn b.tm attacker.id;
    emit b (BankedTurn attacker.name)
  end

(** Tell the observer about a step, if anyone is watching. *)
let step_to (b : battle) (s : step) =
  match b.on_step with None -> () | Some f -> f b s

(** Apply a swap and hand the observer the two boards around it.

    Both the human's move and the AI's go through here, so the slide animation
    cannot exist on one path and not the other - which is the kind of asymmetry that
    looks like a bug in the player's own turns only. *)
let apply_swap (b : battle) (a : Board.position) (c : Board.position)
    (dir : Ai.direction) =
  let before = b.board in
  b.board <- swap_gems before a c;
  emit b (Swap (a.Board.x, a.Board.y, dir));
  step_to b (Swapped { before; after = b.board; a; b = c })

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
        (* The board is advanced to the clearing state *before* the runs run:
           a match hook that writes a cell - IMGS sweeps every star off the
           grid - has to land in the grid the cascade goes on with, and the
           [b.board <- cleared] that used to follow the runs would throw that
           write away. A hook therefore reads the grid with its matches already
           gone, which is the grid the cascade itself is working from. *)
        let before = b.board in
        b.board <- cleared;
        (* Mana and the extra turn roll are per run, from the board's grouping. *)
        List.iter
          (fun (coords, g) ->
            let n = List.length coords in
            (match element_of_gem g with
            | Some e -> credit_run b attacker e n
            | None -> ());
            (* A 4- or 5-of-a-kind grants a deterministic extra turn, independent
               of the stat roll. The match hooks - items and status effects -
               hang off the same test: the Lua ties OnMatch4 to "matches 4 gems
               (and receives an extra turn)", so a fight with size patterns off
               has no event to fire them on either. They emit nothing of their
               own, the way the start-battle payoffs do not. *)
            if b.rules.size_patterns && n >= 4 then begin
              let of_five = n >= 5 in
              grant_extra_turn b.tm attacker.id;
              emit b (SizeTurn attacker.name);
              ignore (match_item_hooks b attacker ~of_five);
              run_match_effects attacker b.effects ~of_five ~enemies:[ defender ]
                ~roll:b.rng ~battle:b.effect_state
            end)
          res.runs;
emit b (MatchResolved (!step, res));
        if res.gold > 0 then emit b (GoldGained (attacker.name, res.gold));
        if res.xp > 0 then emit b (XpGained (attacker.name, res.xp));
        (* The three boards: [before] is what the player was looking at, [cleared]
           is the same board with the matches gone and the gaps still open - plus
           whatever a match hook wrote into it - and [after] is gravity having
           pulled everything down and the gaps been refilled. *)
        let post_hooks = b.board in
        refill b;
        step_to b
          (Cascaded
             { step = !step; before; cleared = post_hooks; after = b.board; runs = res.runs })
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

     Both go through their hook: [receive_gold] folds the mover's OnReceiveGold
     items (IRBR triples, IXHD banks a turn) over the haul, and [receive_xp]
     folds OnReceiveXP first - IMSE doubling, IALR paying mana out of it -
     and then the status effects, Favored's [OnReceiveXP] converting a share of
     the experience into healing on the spot rather than into a later award.
     That a hook sees the amount before the ceiling and the folds is the point:
     the natives are what the Lua calls with the raw number. *)
  if !gold > 0 then ignore (receive_gold b attacker !gold);
  if !xp > 0 then ignore (receive_xp b attacker !xp);
  !total

(** Runs the two damage chains over a cascade's [dealt] and applies the result.

    Shared by the swap path ([play_swap_result]) and the cast path
    ([take_action]): the engine's post-cascade flow is one code path - the
    cascade driver (state 1, [FUN_0047E500]) pops matches and the damage lands
    through the same GIVE_DAMAGE / RECEIVE_DAMAGE chains whichever action
    created the match. [defender] is the combatant being damaged; the attacker
    is derived from it. *)
let apply_cascade_damage (b : battle) ~(defender : combatant) (dealt : int) :
    unit =
  if dealt > 0 then begin
    (* Two chains run, and within each the attacker's side is the inner one.

       The order matters and is not arbitrary. For a given combatant the original
       runs GIVE_DAMAGE before RECEIVE_DAMAGE, so an item that amplifies what it
       deals and an item that reduces what it takes compose as amplify-then-reduce
       rather than the other way round. Across the two combatants it runs the
       attacker's chain first, so the defender's receive hooks see the
       already-amplified number. *)
    let attacker = attacker_of b defender in
    (* One percentile per [PERCENTILE_CHANCE_SYNC] call rather than one per
       event: the contexts carry the battle's rng behind a closure, so nothing
       is drawn until a body asks, and two bodies asking get two rolls. *)
    let give_ctx = damage_context b ~self:attacker ~attacker ~defender in
    (* Items first, then status effects, each as its own chain.

       The {e relative} order of an item hook against a status-effect hook is not
       recovered: the original dispatches both through the same name-based
       callback table, and nothing in the binary or the scripts fixes whether a
       character's worn item runs before or after the status effects on it. Items
       are placed first here on the assumption that equipment is the more
       persistent modifier, and this comment is the record of that being a choice
       rather than a recovery.

       What {e is} recovered is the order across the two combatants: the
       attacker's chain runs before the defender's, so a defender's reduction
       sees the already-amplified number. *)
    let grid_before = b.board in
    let outgoing =
      give_damage ~attacker ~defender b.effects ~enemies:[ defender ] ~roll:b.rng
        ~battle:b.effect_state
        (Item.fold_give_damage (loadout_of b attacker) give_ctx ~damage:dealt
           ~source:attacker.id ~target:defender.id
           ~f:(fun (i : Item.item) n ->
             Item.give_damage i give_ctx ~damage:n ~source:attacker.id
               ~target:defender.id))
    in
    (* Built here rather than beside [give_ctx] so the defender's chain reads the
       grid the attacker's hooks left behind - IADO's sweep is on one side and
       ICAR's cell pick is on the other, and the Lua's live grid would show the
       sweep to the second body. The contexts draw no rng either way. *)
    let take_ctx = damage_context b ~self:defender ~attacker ~defender in
    let taken =
      receive_damage ~defender ~attacker b.effects ~enemies:[ attacker ] ~roll:b.rng
        ~battle:b.effect_state
        (Item.fold_receive_damage (loadout_of b defender) take_ctx ~damage:outgoing
           ~source:attacker.id ~target:defender.id
           ~f:(fun (i : Item.item) n ->
             Item.receive_damage_hook i take_ctx ~damage:n ~source:attacker.id
               ~target:defender.id))
    in
    defender.life <- max 0 (defender.life - taken);
    (* The defeat sweep keys off the flag, not the life total, so it has to be
       raised here or nobody is ever reported dead. *)
    if defender.life < 1 then defender.is_dead <- true;
    emit b (Damage (defender.name, taken));
    (* A hook that destroyed a cell - IADO's red-skull sweep is the only one -
       leaves the grid short, and the next swap would resolve the holes. Gravity
       and refill run here for the reason they run after a spell body; on an
       intact board both are the identity and refill draws nothing, so a fight
       whose items only change numbers pays no rng for this. *)
    b.board <- Board.refill_board ~rng:b.rng (Board.apply_gravity b.board);
    if b.board <> grid_before then emit b Refilled
  end

(** Plays a swap for whichever side is acting, then resolves the cascade.

    [defender] is the combatant whose turn it is - the naming is the engine's,
    not mine, and [attacker_of] is what turns it round. *)
let rec play_move (b : battle) (defender : combatant) : unit =
  (* [defender] is the combatant being attacked, not the one attacking. That
     naming is easy to get wrong and getting it wrong is silent: the whole
     function behaves reasonably either way, it just asks the wrong side whether
     it is human. [attacker_of] is what turns it round, and the mover is the
     attacker. *)
  let mover = attacker_of b defender in
  let is_hero = mover.Combat.id = b.hero.Combat.id in
  match (b.rules.player, is_hero) with
  | Some p, true ->
      (* A human picks from the legal swaps rather than from the evaluator's
         favourite. [find_all_legal_moves] applies the same legality test the
         AI's [has_valid_move] uses, so a swap the human is offered is one the
         engine would have accepted; only the ranking is skipped. *)
      (match p.choose_swap (find_all_legal_moves b.board) with
      | Some m ->
          (* [swap] carries two positions rather than a direction, and the event
             wants the direction, so derive it. A legal swap is always
             orthogonal, so one of the two is strictly greater. *)
          apply_swap b m.from_pos m.to_pos
            (if m.Board.to_pos.x > m.Board.from_pos.x then Horizontal else Vertical);
          play_swap_result b defender
      | None ->
          (* Declining the swap ends the turn without one, which is what a player
             means by passing. *)
          ())
  | _ ->
      let e =
        evaluate_board ~weights:b.rules.ai_weights ~rng:b.rng
          ~difficulty:b.rules.difficulty
          ~hero:{ level = b.rules.hero_level; level_cap = b.rules.hero_level_cap }
          (ai_view b)
      in
      (match (e.has_valid_move, e.best) with
      | true, Some c ->
          (* The candidate comes back in the AI's coordinates, which put row 0
             above the board. Undo the same shift [ai_view] applied, otherwise
             every swap lands one row low. *)
          let sx = c.cand_x and sy = c.cand_y - 1 in
          let src = { x = sx; y = sy } in
          let dst =
            match c.cand_direction with
            | Horizontal -> { x = sx + 1; y = sy }
            | Vertical -> { x = sx; y = sy + 1 }
          in
          apply_swap b src dst c.cand_direction;
          play_swap_result b defender
      | _ ->
          (* No legal move. The original regenerates the board and calls it Mana
             Burn; see [Board.reshuffle], which also explains why filling empty
             cells is not enough. *)
          b.mana_burns <- b.mana_burns + 1;
          emit b ManaBurn;
          b.board <- reshuffle ~rng:b.rng b.board;
          emit b Refilled)

(** Resolves the cascade after a swap is on the board and runs the damage chain.

    Split out of [play_move] so the human and AI paths share it exactly. The only
    thing that differs between a human turn and a machine one is which swap was
    chosen; everything from here on is the recovered code path. *)
and play_swap_result (b : battle) (defender : combatant) : unit =
  let dealt = resolve_cascades b defender in
  apply_cascade_damage b ~defender dealt

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
      ctx_aim = ref None;
      ctx_items = Some (loadout_of b actor);
      ctx_enemy_items = Some (loadout_of b defender);
    }

(** The context a [CastSpell] body runs against.

    [fx_board], [fx_gold] and [fx_xp] are boxed *copies* of the battle's values, and
    the caller has to write them back - which [cast_spell] does, and which is worth
    saying out loud because the alternative reading of a field named [fx_board]
    holding a [board ref] is that it *is* the battle's board. It is not: [Board] is a
    persistent value, so [ref b.board] is a fresh cell holding a copy, and a body's
    [SET_GEM] lands in that cell and nowhere else unless someone reads it back.

    The combatants are the other way round. [fx_caster] and the defender are the
    battle's own mutable records, so mana, life and status effects survive a call
    with no write-back - and that asymmetry is why the missing write-back was
    invisible for so long: the half of a cast that a player notices worked. *)
let effect_context (b : battle) (actor : combatant) (defender : combatant)
    (s : Spell.spell) (aim : Board.position option) (p : int) :
    Spell.effect_context =
  { Spell.fx_caster = actor
  ; Spell.fx_enemies = [ defender ]
  ; Spell.fx_board = ref b.board
  ; Spell.fx_roll = b.rng
  ; Spell.fx_gold = ref b.gold
  ; Spell.fx_xp = ref b.xp
  ; Spell.fx_input = aim
  ; Spell.fx_items = Some (loadout_of b actor)
  ; Spell.fx_enemy_items = Some (loadout_of b defender)
  ; Spell.fx_flags = b.multipliers
  ; Spell.fx_spell = Some s
  ; Spell.fx_percentile = p
  ; Spell.fx_grid_effect =
      (match b.on_grid_fx with
      | None -> None
      | Some f ->
          Some
            (fun cell fx ->
              f { grid_fx_cell = cell; grid_fx_effect = fx; grid_fx_caster = actor.Combat.name }))
  ; Spell.fx_effective_skill = (fun k -> skill_value actor b k)
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
  (* Only {e selection} changes for a human. [ShouldAICastSpell] is deliberately
     not consulted: it is the engine's opinion about whether a machine would cast
     this, and a player is entitled to disagree with it. What the player is
     offered is filtered by [can_cast] - affordable, off cooldown, and not
     suppressed - which is the same legality the affordability filter applies on
     the AI path.

     The machine's aim comes back with its spell: [pick_ai_spell] runs each
     candidate's hook against a [ctx_aim] it cleared first, so what the context
     holds afterwards is the winning hook's cell or nothing - the six hooks that
     say "Store a grid in case we cast!" storing, and the three aimed spells
     whose hooks store nothing storing nothing at all. *)
  let chosen, machine_aim =
    match (b.rules.player, actor.Combat.id = b.hero.Combat.id) with
    | Some p, true ->
        let disallowed = b.effect_state.Combat.spells_disallowed in
        ( p.choose_spell
            (List.filter
               (fun (s : spell) -> can_cast ~spells_disallowed:disallowed actor s)
               spells),
          None )
    | _ ->
        let ctx = ai_context b actor defender ~percentile ~evaluation in
        let c =
          pick_ai_spell ~difficulty:b.rules.difficulty ~roll:b.rng
            ~spells_disallowed:b.effect_state.Combat.spells_disallowed ctx spells
        in
        (c, !(ctx.Spell.ctx_aim))
  in
  let still_turn =
    match chosen with
    | None ->
        (* Nothing cast, so the turn is the caster's to use. *)
        emit b (SpellHeld actor.name);
        true
    | Some s ->
        (* Where the aim comes from. A human's is their own click, collected by
           the front end's choose_aim the moment the spell was picked; a
           machine's is the cell its hook stored during pick_ai_spell, or None
           when the hook stored nothing - which is what the aimed effects no-op
           on, as they did before either path existed. *)
        let aim =
          if s.Spell.input_type = 0 then None
          else
            match (b.rules.player, actor.Combat.id = b.hero.Combat.id) with
            | Some p, true -> p.choose_aim s
            | _ -> Option.map (fun (x, y) -> { Board.x; y }) machine_aim
        in
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
             let fx = effect_context b actor defender s aim percentile in
             f fx;
             (* The body's writes go through three boxed values, and nothing else
                picks them up: the board it edited, and the battle's gold and xp
                totals. A combatant is a mutable record, so mana and life survive on
                their own - which is precisely why this stayed hidden: the visible
                half of every cast worked.

                Read back *before* the cascade below, or it runs on the board as it
                was before the spell and every cell the spell edited is thrown
                away. *)
             b.board <- !(fx.Spell.fx_board);
             (* What the body added to the boxed gold and xp is what its
                ADD_GOLD / ADD_XP calls banked, so that delta - not the whole
                boxed total, which started as a copy of the battle's - is what
                runs through the receiver's hooks. A body that spends rather
                than earns writes the total straight back. *)
             let gained_gold = !(fx.Spell.fx_gold) - b.gold in
             if gained_gold > 0 then ignore (receive_gold b actor gained_gold)
             else b.gold <- !(fx.Spell.fx_gold);
             let gained_xp = !(fx.Spell.fx_xp) - b.xp in
             if gained_xp > 0 then ignore (receive_xp b actor gained_xp)
             else b.xp <- !(fx.Spell.fx_xp);
             (* After a cast the engine runs the cascade driver (state 1 ->
                FUN_0047E500): a spell-completed line resolves immediately, with
                the same mana, gold, XP, extra-turn and damage hooks a swap's
                cascade gets. [PickSpell] (0x440FB0) clears the best-move flag
                when a cast is chosen (0x441172), so [CommitBestMove] (0x43FAF0)
                returns 0 and the turn's state machine goes straight to state 1
                rather than through the swap's state 2 gravity step - but the
                driver itself is the same code either way. Before this was
                recovered only gravity and refill ran here, so a line a spell
                completed sat on the board until the next swap scored it. *)
             let dealt = resolve_cascades b defender in
             apply_cascade_damage b ~defender dealt;
             if actor.is_dead then emit b (Death actor.name)
         | None -> ());
        (* Charged last, and only if the body did not charge itself. See
           [Spell_effects.handle_spell_cost]. The free-spell latch suppresses it
           the same way. *)
        if not s.Spell.cost_charged && not was_free then pay_cost actor s;
        keeps
  in
  if still_turn then play_move b defender

(** The life-based verdict, recorded the moment it becomes true, with OnVictory
    firing at the same transition - so it runs once per battle, however many
    times [run] is called afterwards. It runs after a skipped turn as well as a
    played one: a corpse that sits out its turn under [Missed] still has to end
    the fight rather than hold the loop open until the status runs out. *)
let record_outcome (b : battle) : unit =
  match b.hero.life, b.enemy.life with
  | 0, 0 -> b.winner <- Some Draw
  | 0, _ ->
      b.winner <- Some EnemyVictory;
      ignore (victory_item_hooks b b.enemy)
  | _, 0 ->
      b.winner <- Some HeroVictory;
      ignore (victory_item_hooks b b.hero)
  | _ -> ()

(** [MISS_TURNS] as the loop reads it: spend one turn of the [Missed] status
    and say so. Returns [true] when the actor sat this one out.

    The placement is the whole behaviour. It runs after the worn items'
    [OnStartTurn] and before the status effects' own start hooks, which is what
    makes ITUT - "Owner never takes a turn" - do exactly that: its body runs
    first and sets [Missed], this spends it, and the action never happens. It
    also means a missed turn ticks nothing else: [run_start_of_turn_effects]
    would drop [Missed] on the floor, because it keeps only ids it has a
    descriptor for and [Missed] is a pseudo-status with none - so the check has
    to come before it, or the status would be gone before anything could act on
    it. *)
let spend_missed_turn (b : battle) (actor : combatant) : bool =
  match List.assoc_opt "Missed" actor.effects with
  | Some n when n > 0 ->
      actor.effects <-
        (if n <= 1 then List.filter (fun (id, _) -> id <> "Missed") actor.effects
         else
           List.map
             (fun (id, d) -> if id = "Missed" then (id, d - 1) else (id, d))
             actor.effects);
      emit b (MissedTurn actor.name);
      true
  | _ -> false

(** One turn for the current combatant. *)
let take_turn (b : battle) : unit =
  if b.winner <> None then ()
  else begin
    let actor = current b.tm in
    let is_hero = actor.id = b.hero.id in
    let defender = if is_hero then b.enemy else b.hero in
    let spells = if is_hero then b.hero_spells else b.enemy_spells in
    (* Arm this turn's clock before the event so the observer and the plate see
       the fresh deadline: the human's turn gets a deadline from the Time Limit
       delay table, every other turn disarms - the AI waits for nothing, which is
       the original's +0x10/+0x11 gate over the countdown. *)
    b.clock_deadline_ms <-
      (if is_hero && b.rules.player <> None && b.rules.time_limit > 0 then
         Some (b.clock_now_ms + time_limit_delay_ms b.rules.time_limit)
       else None);
    emit b (TurnStart (b.tm.current_slot, (if is_hero then Hero else Enemy), actor.name));
    (* The worn items' OnStartTurn run before the status effects' own start
       hooks, for the reason the damage chain gives: items first. ISDO tops up
       water, the troll rings heal off a stockpile, IEGM pays out of full
       reserves. *)
    ignore (start_turn_item_hooks b actor);
    if spend_missed_turn b actor then begin
      (* The turn advances - the round, the cap and any banked extra turn all
         move on - but nothing of the turn happens: no status ticks, no spell,
         no swap, and no cooldown tick either, since cooldowns count the actor's
         own turns and this was not one. *)
      record_outcome b;
      b.turns_elapsed <- b.turns_elapsed + 1;
      emit b (TurnEnd b.turns_elapsed);
      ignore (advance_turn b.tm)
    end
    else begin
      run_start_of_turn_effects actor b.effects ~turn:b.turns_elapsed ~enemies:[ defender ]
        ~roll:b.rng ~battle:b.effect_state;
      take_action b actor defender spells;
      if sweep_deaths b.tm then
        List.iter (fun c -> if c.life = 0 then emit b (Death c.name)) [ b.hero; b.enemy ];
      record_outcome b;
      (* Cooldowns count the caster's own turns, so this is the natural tick: by
         the time the next turn starts the spell that was just cast has one fewer
         turn left. Ticking after the cast rather than before means a cooldown of
         3 blocks the next two casts, not three. *)
      tick_cooldowns actor;
      b.turns_elapsed <- b.turns_elapsed + 1;
      emit b (TurnEnd b.turns_elapsed);
      ignore (advance_turn b.tm)
    end
  end

(** Whether the turn clock is currently running - i.e. this is a human's turn
    under a Time Limit. The AI's turns and the untimed setting both leave the
    deadline [None]. *)
let clock_armed (b : battle) : bool = b.clock_deadline_ms <> None

(** The milliseconds left on the current turn's clock.

    While armed it counts down from the delay table against the wall tick the
    front end feeds; while disarmed (the AI's turn) it holds the full delay,
    frozen - which is what the original's disabled countdown reads, since
    [FUN_00464c30] returns the cached delay once the refresh flag clears. At
    Time Limit 0 the delay is 0 and the plates are hidden anyway. *)
let clock_remaining_ms (b : battle) : int =
  match b.clock_deadline_ms with
  | Some d -> max 0 (d - b.clock_now_ms)
  | None -> time_limit_delay_ms b.rules.time_limit

(** The human has outstayed the Time Limit: the deadline passed on a turn that
    was being timed. The front end notices this each frame while a question is
    open and force-ends the turn - the original's [FUN_00415800], which plays
    snd_forceendturn and hands play to the opponent with no swap and no spell.
    It cannot fire during the AI's turns: they never arm a deadline, and the
    human's own hooks are the only place the front checks. *)
let clock_expired (b : battle) : bool =
  match b.clock_deadline_ms with
  | Some d -> b.clock_now_ms >= d
  | None -> false

(** The outcome as the rest of the game asks for it: did the hero win?
    Reading [is_dead] after [run] cannot answer - [sweep_deaths] clears the
    flag on every pass (faithful to FUN_00464870, pinned by test_combat), so
    the life-based [winner] the run derives is the battle's own verdict.
    Stalemate and draws are not wins. *)
let hero_won (b : battle) : bool = b.winner = Some HeroVictory

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
  let battle =
    {
      rules;
      board;
      hero;
      enemy;
      tm = initialise [ hero; enemy ];
      turns_elapsed = 0;
      mana_burns = 0;
      clock_now_ms = 0;
      clock_deadline_ms = None;
      gold = 0;
      xp = 0;
      winner = None;
      log = [];
      (* Nobody is watching by default, which is what every faithful test and the
         headless runner rely on. See [Battle.on_event]. *)
      on_event = None;
      on_step = None;
      on_grid_fx = None;
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
  in
  (* Register this fight as the one [ADD_MANA_<E>] answers to, so a spell body
     crediting mana and a status effect doing the same run the receiver's
     OnReceiveMana fold instead of banking behind it - IMOA doubles the blue a
     spell granted, not only the blue a match banked. The membership test is
     physical equality rather than a compare on [id]: every fight has a hero at
     id 0, so an id check would fold a foreign combatant into this loadout, and
     a combatant that is not one of these two has to fall through to the raw
     clamp instead. *)
  Combat.mana_credit_hook :=
    Some
      (fun c e n ->
        if c == battle.hero || c == battle.enemy then receive_mana battle c e n
        else Combat.bank_mana c e n);
  battle

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
  | MissedTurn name -> Printf.sprintf "             %s is stunned and misses the turn" name
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



