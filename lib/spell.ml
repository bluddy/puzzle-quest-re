(** Spells, mana, and the stat-based extra turn.

    Recovered from the spell manager at 0x004622C0 and the mana-gain path at
    0x0047D4F0, cross-referenced against the 130 spell XML files in
    Assets.zip. See docs/SPELLS.md.

    The extra turn roll is the mechanic that emerged from playtesting rather
    than from disassembly: matching an element at high skill raises the chance
    of a free turn. It is [gained / 100], per element, per match, and it is why
    extra turns become common late. *)

open Combat

(** Whether casting a spell ends your turn.

    The overwhelming majority of spells end it, which means the caster does
    {e not} also make a swap that turn. Only a minority hand the turn back. This
    is not an inference: the game states the rule in each spell's own
    description, and [lib/spell_data.ml] is that text transcribed. *)
type turn_cost =
  | EndsTurn  (** the default: no turn clause in the description *)
  | KeepsTurn  (** "Your turn does not end" *)
  | KeepsTurnIfMana of element * int
      (** "Your turn does not end if Red Mana is 15+" *)
  | EndsTurnAfterEffect
      (** "the turn ends", called out after a gem-destruction effect *)

(** A spell as the game's assets describe it: the four costs, the cooldown, the
    learn requirements, the input type, and the turn rule. [lib/spell_data.ml]
    holds all 129 of these, parsed from [Assets/Spells/*.xml] and
    [English/StandardSpellsText.xml].

    [Spell.spell] is the runtime object with mutable state and identity; a
    descriptor is the static data a spell is built from. [spell_of_descriptor]
    turns one into the other. *)
type descriptor = {
  id : string;
  cost_earth : int;
  cost_fire : int;
  cost_air : int;
  cost_water : int;
  cooldown : int;
  learn_score : int;
  learn_masks : int;
  learn_keys : int;
  input_type : int;  (** 0 none, 1 column, 2 row, 3 grid *)
  turn_cost : turn_cost;
}

(** What a spell's [ShouldAICastSpell] is evaluated against.

    Every one of the 130 battle spells defines the hook, so this is not a corner
    case: it is how the original AI chooses. [ctx_evaluation] and
    [ctx_percentile] are precomputed once per turn rather than per spell, because
    [Std_AISpellcastingChance] reads both and they do not change within a turn.

    [ctx_board] is the live board, in [Board]'s 0-based rows. Several hooks sweep
    it directly.

    [ctx_items] is [GET_ITEM]. The original implements it as a four-slot array of
    item id strings and only SDUP's duplication script reads it, through
    [Item.get_item_slot]; there is deliberately no wrapper here, since one would
    have no caller until SDUP is ported. [None] means "no loadout in scope", which
    is what a bare spell built in a test gets. *)
type ai_context = {
  ctx_caster : combatant;
  ctx_enemy : combatant;
  (** [GET_NUM_ENEMIES] plus repeated [GET_ENEMY]. [ctx_enemy] is element 0 of
      this and is kept separately because 49 of the 52 hooks that read an enemy
      only ever read the first one. SSWP is the exception: it sums Air mana over
      the whole enemy side. *)
  ctx_enemies : combatant list;
  ctx_board : Board.board;
  (** [EVALUATE_BOARD]: the score of the best move available. *)
  ctx_evaluation : int;
  (** [PERCENTILE_CHANCE_SYNC]: a 0..99 roll, one per turn. *)
  ctx_percentile : int;
  (** Injected randomness for hooks that need it. *)
  ctx_roll : int -> int;
  ctx_items : Item.loadout option;
  (** The enemy side's loadout, for SDUP, which compares the two sides' four
      slots. Separate from [ctx_items] because the loadout lives on the battle
      rather than on the combatant. *)
  ctx_enemy_items : Item.loadout option;
}

(** The three board bonus flags, at their recovered offsets on the battle
    manager. Mutable, and shared with the battle rather than copied, because the
    spells that switch them off do so for the duration of a board sweep and the
    next match has to see them back on.

    Each is a single byte written by one Lua bridge, all three recovered from
    [docs/decompiled]:

    | field | offset | native | what it gates |
    | --- | --- | --- | --- |
    | [wildcard_chance] | `+0x390` | [SET_WILDCARD_CHANCE_ENABLED] | a 5-or-more run creating a wildcard |
    | [extra_turn_chance] | `+0x391` | [SET_EXTRATURN_CHANCE_ENABLED] | the stat-based extra turn roll |
    | [damage_multiplier] | `+0x392` | [SET_DAMAGE_MULTIPLIER_ENABLED] | skull damage scaling |

    [SetMultiplierEffects] in [GridUtilities.lua] sets all three together, which is
    how the board-sweeping spells use them: switch them off, sweep the board, switch
    them back on, so the gems being removed cannot also pay out a bonus.

    **Not one of these is the 4-or-5-of-a-kind pattern flag.** That is
    [SET_45_PATTERN_ENABLED], which writes `+0x395`. An earlier note in
    [docs/DATA_STRUCTURES.md] attributed "4-of-a-kind grants an extra turn" to
    `+0x391`; the decompilation says otherwise, since [FUN_0047D4F0] reads
    `+0x391` in the stat-roll path and [Lua_SET_45_PATTERN_ENABLED.c] writes
    `+0x395`.

    [damage_multiplier] has no consumer in the port yet. Skull damage here is a
    flat 1 for a skull and 5 for a red skull, with no scaling term, so there is
    nothing for the flag to gate. It is modelled rather than dropped so the three
    stay together and so whoever recovers the scaling has the switch already in
    place - but it is honest to say that today setting it changes nothing. *)
type multiplier_flags = {
  mutable wildcard_chance : bool;
  mutable extra_turn_chance : bool;
  mutable damage_multiplier : bool;
}

let default_multiplier_flags =
  { wildcard_chance = true; extra_turn_chance = true; damage_multiplier = true }

type spell = {
  id : string;
  name : string;
  (* Note the engine's element order here is earth, fire, air, water, which
     is *not* the board gem-id order in [Ai]. *)
  cost_earth : int;
  cost_fire : int;
  cost_air : int;
  cost_water : int;
  cooldown : int;
  learn_score : int;
  learn_masks : int;
  learn_keys : int;
  input_type : int;  (** 0 none, 1 column, 2 row, 3 grid *)
  mutable use_count : int;
(* Defaults to [EndsTurn], which is right for 97 of the 129 spells. Only the
     exceptions need to be set; see [lib/spell_data.ml] for the full table. *)
  turn_cost : turn_cost;
  (* The spell's own AI hooks, ported from its Lua script. Both are [None] only
     for a bare spell built in a test: all 130 game spells define both. *)
  should_ai_cast : (ai_context -> bool) option;
  is_cast_legal : (ai_context -> bool) option;
  (* Set when [CastSpell] is ported; see [lib/spell_effects.ml]. *)
  cast_spell : (effect_context -> unit) option;
  (** [HANDLE_SPELL_COST] sets this on the spell, at `+0x14` on the descriptor.
      See [Spell_effects.handle_spell_cost] for why that matters. *)
  mutable cost_charged : bool;
}

(** What a [CastSpell] body gets to work with.

    Separate from [ai_context] on purpose. The AI hook only ever reads - it asks
    whether a spell is worth casting - whereas the effect body writes: it moves
    mana, deals damage, edits the board, and grants turns. Sharing one record
    would mean every read-only hook carried mutable handles it has no business
    touching, and the compiler would not object.

    The three differences that matter in practice:

    - [fx_board] is a {e reference}, not a board. [SET_GEM], [DESTROY_GEM] and
      [ADD_EFFECT_TO_GRID] mutate the board in place, and [Board] is an immutable
      value with a functional [Board.set_gem]. Handing the effect a copy would
      silently discard every board edit; the reference writes through to the
      battle's own cell.
    - [fx_roll] is the battle's single random source, so an effect that rolls
      ([SFBA] searching for a skull, several skills using [GET_RANDOM_SYNC])
      draws from the same stream as everything else and keeps replays
      deterministic.
    - [fx_gold] and [fx_xp] are references because they belong to the battle, not
      to either combatant, and [ADD_GOLD] and [ADD_XP] write them.

    [fx_input] is the cell the spell was aimed at, for the spells whose
    [input_type] is not 0. It is [None] when the spell needs no target. *)
and effect_context = {  fx_caster : combatant;   fx_enemies : combatant list;   fx_board : Board.board ref;   fx_roll : int -> int;   fx_gold : int ref;   fx_xp : int ref;   fx_input : Board.position option;   fx_items : Item.loadout option;   fx_enemy_items : Item.loadout option;   (** The battle's own bonus flags, by reference through the record rather than       copied. [SetMultiplierEffects] writes all three, and a sweep that switched       them off on a private copy would leave the battle's unchanged. *)   fx_flags : multiplier_flags;   (** The spell being cast. [HANDLE_SPELL_COST] takes no element or amount: it       reads the descriptor's own four costs, through what the decompilation calls       a current-spell singleton. This is that. *)   fx_spell : spell option;}

let total_cost (s : spell) =
  s.cost_earth + s.cost_fire + s.cost_air + s.cost_water

let make_spell ?(cost_earth = 0) ?(cost_fire = 0) ?(cost_air = 0) ?(cost_water = 0)
    ?(cooldown = 0) ?(learn_score = 0) ?(learn_masks = 0) ?(learn_keys = 0)
    ?(input_type = 0) ?(use_count = 0) ?(turn_cost = EndsTurn) ?should_ai_cast
    ?is_cast_legal ?cast_spell id name =
  {
    id;
    name;
    cost_earth;
    cost_fire;
    cost_air;
    cost_water;
    cooldown;
    learn_score;
    learn_masks;
    learn_keys;
    input_type;
    use_count;
    turn_cost;
    should_ai_cast;
    is_cast_legal;
    cast_spell;
    cost_charged = false;
  }

(** [Lua_IS_SPELL_CASTABLE]. A plain per-pool comparison. Note the original
    gates the air check on a "spells disallowed this turn" flag, which is how
    a status effect suppresses casting; {!spells_disallowed} is that flag. *)
let is_castable ?(spells_disallowed = false) (c : combatant) (s : spell) : bool =
  c.mana.earth >= s.cost_earth
  && c.mana.fire >= s.cost_fire
  && c.mana.air >= s.cost_air
  && c.mana.water >= s.cost_water
  && not (spells_disallowed && s.cost_air > 0)

(** [Lua_HANDLE_SPELL_COST]. Deducts all four pools, each clamped at zero.
    Mana is allowed to go negative in the original for status effects, but a
    spell you can cast is by definition affordable, so the clamp is a no-op
    here. *)
let pay_cost (c : combatant) (s : spell) : unit =
  c.mana <-
    {
      earth = c.mana.earth - s.cost_earth;
      fire = c.mana.fire - s.cost_fire;
      air = c.mana.air - s.cost_air;
      water = c.mana.water - s.cost_water;
    }

(** Whether [c] keeps playing after casting [s], and so also gets to make a swap
    that turn.

    The conditional case is evaluated against the caster's mana at the moment of
    the cast, which is the same instant the game's description refers to. Note
    this is the {e caster's} mana, not the enemy's. *)
let keeps_turn (c : combatant) (s : spell) : bool =
  match s.turn_cost with
  | EndsTurn | EndsTurnAfterEffect -> false
  | KeepsTurn -> true
  | KeepsTurnIfMana (e, threshold) -> mana_of e c.mana >= threshold

(** Cooldowns, from the [Data cooldown] attribute the spell XMLs carry.

    58 of the 129 spells have one; the rest are castable every turn. A cooldown
    counts the caster's own turns, so it ticks in [tick_cooldowns] at the end of
    a turn rather than on a global counter.

    The counter lives on the combatant, not on the spell, because a spell record
    is shared between both sides here and one side's cast must not gate the
    other's. [is_castable] is deliberately *not* extended with a cooldown check:
    it models the original's mana test, which is what the spell picker consults.
    The cooldown is a separate gate, applied by [can_cast] below. *)
let cooldown_left (c : combatant) (s : spell) : int =
  match List.assoc_opt s.id c.cooldowns with Some n -> n | None -> 0

let is_ready (c : combatant) (s : spell) : bool = cooldown_left c s <= 0

(** Affordability and cooldown together: what the AI actually needs. *)
let can_cast ?(spells_disallowed = false) (c : combatant) (s : spell) : bool =
  is_castable ~spells_disallowed c s && is_ready c s

(** Starts [s]'s cooldown after a cast. A spell with no [Data cooldown] is
    never put on cooldown, so its absence from the list is the signal. *)
let start_cooldown (c : combatant) (s : spell) : unit =
  if s.cooldown > 0 then c.cooldowns <- (s.id, s.cooldown) :: c.cooldowns

(** Ticks every cooldown down by one and drops those that reach zero, so the map
    does not grow across a long battle. *)
let tick_cooldowns (c : combatant) : unit =
  c.cooldowns <-
    List.filter_map
      (fun (id, n) ->
        let n' = n - 1 in
        if n' <= 0 then None else Some (id, n'))
      c.cooldowns

(** [FUN_004466E0]. Resistance codes 0 (none) through 4, mapping to the
    snd_resistspell variants. A resisted cast still pays its cost: resistance
    reduces the effect, it does not refund. *)
type resistance = RNone | RMinor | RModerate | RStrong | RImmune

let resist_by_code = function
  | 0 -> RNone
  | 1 -> RMinor
  | 2 -> RModerate
  | 3 -> RStrong
  | _ -> RImmune

(** The run-size multiplier, 1.0 / 2.0 / 3.0 for a 3 / 4 / 5-of-a-kind. The
    same tiers the AI's move scoring rewards. *)
let run_multiplier (run_length : int) : float =
  if run_length >= 5 then 3.0 else if run_length >= 4 then 2.0 else 1.0

(** Mana yielded by a match in one element.

    The original computes [(skill_value + 100.0) * multiplier * 0.01] in
    float, with the skill value capped at 999 upstream. The +100 floor means a
    character with no skill in an element still banks one mana per matched gem.

    Returns a float rather than an int because the extra turn roll truncates
    it, and the difference between 10.99 and 10 is observable. *)
let mana_yield ~(skill : int) ~(run_length : int) : float =
  let skill_cap = 999 in
  let skill = if skill > skill_cap then skill_cap else skill in
  (float_of_int (skill + 100)) *. run_multiplier run_length *. 0.01

(** The stat-based extra turn, from [0x0047D4F0].

    [chance] is the mana banked divided by 100, so the probability rises with
    the skill in the matched element and with the run size. The original's
    comparison is a truncating [roll < (int)gained], which [extra_turn_roll]
    reproduces; fractional mana is floored, so a gain of 10.99 counts as 10. *)
let extra_turn_chance (gained : float) : float =
  let n = float_of_int (int_of_float gained) in
  if n < 0.0 then 0.0 else n /. 100.0

(** Rolls for the extra turn. [enabled] is the board mode flag at `+0x391`;
    puzzle and research modes leave it clear and never grant these. [pending]
    is the turn manager's latch, which caps the award at one per pending
    state: a second success is dropped rather than stacking.

    [roll] is injected so the truncation and the comparison can both be
    asserted; pass [Random.int] in production. *)
let extra_turn_roll ~(gained : float) ~(pending : bool) ~enabled ~roll : bool =
  enabled && not pending && roll 100 < int_of_float gained

(** Applies a match to a combatant: credits the mana for one element, banks a
    free extra turn if the roll succeeds, and returns whether one was granted.

    This is the whole of the playtesting observation in one function. Four
    elements matched means four independent rolls, which is why a broad match
    is far likelier to yield a turn than a narrow one. *)
let apply_match_gain ?(enabled = true) ?(roll = Random.int) ?(pending = false) t
    (c : combatant) ~(e : element) ~(skill : int) ~(run_length : int) : bool =
  let gained = mana_yield ~skill ~run_length in
  (* The original accumulates in float and the pools are integers, so the
     credit truncates. *)
  c.mana <- add_mana e (int_of_float gained) c.mana;
  if extra_turn_roll ~gained ~pending ~enabled ~roll then begin
    grant_extra_turn t c.id;
    true
  end
  else false


(** [Std_AISpellcastingChance] from [Assets/Scripts/StandardUtilityScripts.lua].

    Not "a modifier percent". The body is:

    ```lua
    function Std_AISpellcastingChance(modifier)
        local evaluation = EVALUATE_BOARD();
        local chance = PERCENTILE_CHANCE_SYNC();
        if (chance > 50 + modifier) then return 0; end
        if (evaluation > 30) then return 0; end
        return 1;
    end
    ```

    So it casts when the percentile is at or under 50 plus the modifier, and
    only when the board has no good move lined up. That second clause is the real
    answer to why the enemy sometimes plays a move instead of casting: a board
    worth more than 30 points is worth more than whatever the spell does.

    The modifier is a [float], not an int: SDDI passes `numYellow * 1.5`, and
    Lua's `>` promotes the comparison, so a fractional modifier shifts the
    threshold fractionally. Keeping it a float here is what makes SDDI's 7.5
    behave as it does.

    37 of the 130 spells call this with a modifier of 0, so those are cast on at
    most half the turns that reach them, and never when the board is good. *)
let ai_spellcasting_chance ~(modifier : float) (ctx : ai_context) : bool =
  if float_of_int ctx.ctx_percentile > 50.0 +. modifier then false
  else ctx.ctx_evaluation <= 30

(** The same, from an integer modifier, which is what most hooks pass. *)
let ai_spellcasting_chance_i ~(modifier : int) (ctx : ai_context) : bool =
  ai_spellcasting_chance ~modifier:(float_of_int modifier) ctx

(** A spell's [ShouldAICastSpell]. [None] means "the script does not define one",
    which for the 130 battle spells never happens but which a bare spell built in
    a test will hit; such a spell is treated as wanting to be cast, since the
    hook's return of 0 is what suppresses a spell, not its absence. *)
let should_ai_cast (s : spell) (ctx : ai_context) : bool =
  match s.should_ai_cast with Some f -> f ctx | None -> true

(** A spell's [IsCastSpellLegal]: whether it may be cast at all, as opposed to
    whether the AI would like to. Separate from affordability, which
    [can_cast] covers. *)
let is_cast_legal (s : spell) (ctx : ai_context) : bool =
  match s.is_cast_legal with Some f -> f ctx | None -> true

(** [BattleAI_PickSpell] (0x00440FB0).

    The decompilation reads as a thin driver: a difficulty-gated skip, then walk
    the enemy's spell list, and take the first candidate that passes. What was
    missing is that {e every} spell defines its own [ShouldAICastSpell], and that
    is where the intelligence lives: 107 of the 130 call
    [Std_AISpellcastingChance], 20 consult [EVALUATE_BOARD], 37 count gems on
    the board. So the original's spell choice is per-spell evaluation, not
    list order.

    The skip is a percentile roll against a difficulty-scaled threshold. The
    per-spell hook is consulted in list order and the first that says yes wins,
    which is why spell order still matters even though the spells now get a
    vote. *)
let pick_ai_spell ?(difficulty = 1) ?(roll = Random.int) (ctx : ai_context)
    (spells : spell list) : spell option =
  let skip_chance = if difficulty = 0 then 50 else if difficulty = 1 then 25 else 0 in
  if skip_chance > 0 && roll 100 < skip_chance then None
  else
    List.find_opt
      (fun (s : spell) ->
        (* Order matters: the original checks what it can pay for first, then
           the spell's own legality, then its preference. *)
        can_cast ~spells_disallowed:false ctx.ctx_caster s
        && is_cast_legal s ctx
        && should_ai_cast s ctx)
      spells

(** The gem kinds the spell scripts refer to, as [CountGems]' arguments.

    [GYellow] and friends are the game's colour names, not the board's gem ids:
    Earth is green, Fire red, Air yellow, Water blue. That is the reverse of the
    board's id order, which is exactly where a transposition would creep in, so
    the mapping is done once here rather than at each call site. [GStar] is the
    purple star, id 7 on the board. *)
type gem_kind = GYellow | GBlue | GRed | GGreen | GSkull | GRedSkull | GGold | GStar | GAny

let gem_kind_of_board = function
  | Board.Mana Air -> GYellow
  | Board.Mana Water -> GBlue
  | Board.Mana Fire -> GRed
  | Board.Mana Earth -> GGreen
  | Board.Skull -> GSkull
  | Board.RedSkull -> GRedSkull
  | Board.Gold -> GGold
  | Board.Experience -> GStar
  | _ -> GAny

(** The board gem a kind stands for. Tests and fixtures build boards out of
    these; [count_gems] goes the other way. *)
let gem_of_kind = function
  | GYellow -> Board.Mana Air
  | GBlue -> Board.Mana Water
  | GRed -> Board.Mana Fire
  | GGreen -> Board.Mana Earth
  | GSkull -> Board.Skull
  | GRedSkull -> Board.RedSkull
  | GGold -> Board.Gold
  | GStar -> Board.Experience
  | GAny -> Board.Empty

(** [CountGems]: how many gems of one kind are on the board. 37 of the 130 AI
    hooks read the board through this. *)
let count_gems (kind : gem_kind) (ctx : ai_context) : int =
  let matches g = if kind = GAny then g <> Board.Empty else gem_kind_of_board g = kind in
  let n = ref 0 in
  for y = 0 to ctx.ctx_board.Board.height - 1 do
    for x = 0 to ctx.ctx_board.Board.width - 1 do
      if matches (Board.get_gem ctx.ctx_board { Board.x; y }) then incr n
    done
  done;
  !n

(** Shorthand the hooks use constantly: [count_gems GYellow ctx]. *)
let gyellow = count_gems GYellow
let gblue = count_gems GBlue
let gred = count_gems GRed
let ggreen = count_gems GGreen
let gskull = count_gems GSkull
let gredskull = count_gems GRedSkull
let ggold = count_gems GGold
let gstar = count_gems GStar

(** [GET_ITEM(n)]: the item id in slot [n] of the caster's loadout, or [""] when
    there is no loadout in scope or the slot is empty. The empty case is [Some
    ""] rather than [None] because the original returns a string and the scripts
    test it against the empty string. *)
let ctx_get_item (ctx : ai_context) (n : int) : string =
  Option.value (Item.loadout_for ctx.ctx_items n) ~default:""


(** The game's colour names for the elements, which is how the spell
    descriptions refer to them. Earth is green, Fire red, Air yellow, Water
    blue. Note this is the {e reverse} of the board's gem-id order, and the
    descriptions are also where the transposed Air/Water bug would come from. *)
let string_of_element = function
  | Earth -> "green"
  | Fire -> "red"
  | Air -> "yellow"
  | Water -> "blue"

let string_of_turn_cost = function
  | EndsTurn -> "EndsTurn"
  | KeepsTurn -> "KeepsTurn"
  | EndsTurnAfterEffect -> "EndsTurnAfterEffect"
  | KeepsTurnIfMana (e, n) -> Printf.sprintf "KeepsTurnIfMana(%s,%d)" (string_of_element e) n

(** Builds a runtime spell from a descriptor. The name is passed separately
    because it comes from the localisation table's [NAME] tag rather than the
    descriptor; [tools/extract_spell_data.ps1] does not extract it. *)
let spell_of_descriptor (d : descriptor) ?(name = "") ?should_ai_cast ?is_cast_legal
    ?cast_spell () : spell =
  make_spell ~cost_earth:d.cost_earth ~cost_fire:d.cost_fire ~cost_air:d.cost_air
    ~cost_water:d.cost_water ~cooldown:d.cooldown ~learn_score:d.learn_score
    ~learn_masks:d.learn_masks ~learn_keys:d.learn_keys ~input_type:d.input_type
    ~turn_cost:d.turn_cost ?should_ai_cast ?is_cast_legal ?cast_spell d.id name






