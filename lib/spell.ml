(** Spells, mana, and the stat-based extra turn.

    Recovered from the spell manager at 0x004622C0 and the mana-gain path at
    0x0047D4F0, cross-referenced against the 130 spell XML files in
    Assets.zip. See docs/SPELLS.md.

    The extra turn roll is the mechanic that emerged from playtesting rather
    than from disassembly: matching an element at high skill raises the chance
    of a free turn. It is [gained / 100], per element, per match, and it is why
    extra turns become common late. *)

open Combat

(** The colour names the game's scripts use for the elements. [GEM_YELLOW] and
    friends appear throughout the spell scripts. *)
type gem_kind = GYellow | GBlue | GRed | GGreen | GSkull | GRedSkull | GGold | GPurple | GAny

let mana_of_gem = function
  | GYellow -> Some Air
  | GBlue -> Some Water
  | GRed -> Some Fire
  | GGreen -> Some Earth
  | _ -> None

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
    case ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â it is how the original AI chooses. [ctx_evaluation] and
    [ctx_percentile] are precomputed once per turn rather than per spell, because
    [Std_AISpellcastingChance] reads both and they do not change within a turn.

    [ctx_board] is the live board, in [Board]'s 0-based rows. Several hooks sweep
    it directly. *)
type ai_context = {
  ctx_caster : combatant;
  ctx_enemy : combatant;
  ctx_board : Board.board;
  (** [EVALUATE_BOARD]: the score of the best move available. *)
  ctx_evaluation : int;
  (** [PERCENTILE_CHANCE_SYNC]: a 0..99 roll, one per turn. *)
  ctx_percentile : int;
  (** Injected randomness for hooks that need it. *)
  ctx_roll : int -> int;
}
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
  cast_spell : (ai_context -> unit) option;
}

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

    37 of the 130 spells call this with a modifier of 0, so they are cast on at
    most half the turns that reach them, and never when the board is good. *)
let ai_spellcasting_chance ~modifier (ctx : ai_context) : bool =
  if ctx.ctx_percentile > 50 + modifier then false else ctx.ctx_evaluation <= 30

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
let spell_of_descriptor (d : descriptor) ?(name = "") () : spell =
  make_spell ~cost_earth:d.cost_earth ~cost_fire:d.cost_fire ~cost_air:d.cost_air
    ~cost_water:d.cost_water ~cooldown:d.cooldown ~learn_score:d.learn_score
    ~learn_masks:d.learn_masks ~learn_keys:d.learn_keys ~input_type:d.input_type
    ~turn_cost:d.turn_cost d.id name
