(** Spells, mana, and the stat-based extra turn.

    Recovered from the spell manager at 0x004622C0 and the mana-gain path at
    0x0047D4F0, cross-referenced against the 130 spell XML files in
    Assets.zip. See docs/SPELLS.md.

    The extra turn roll is the mechanic that emerged from playtesting rather
    than from disassembly: matching an element at high skill raises the chance
    of a free turn. It is [gained / 100], per element, per match, and it is why
    extra turns become common late. *)

open Combat

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
}

let total_cost (s : spell) =
  s.cost_earth + s.cost_fire + s.cost_air + s.cost_water

let make_spell ?(cost_earth = 0) ?(cost_fire = 0) ?(cost_air = 0) ?(cost_water = 0)
    ?(cooldown = 0) ?(learn_score = 0) ?(learn_masks = 0) ?(learn_keys = 0)
    ?(input_type = 0) ?(use_count = 0) id name =
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

(** [BattleAI_PickSpell] (0x00440FB0).

    Reproduces the original's behaviour faithfully, which is: a
    difficulty-gated random skip, then an affordability filter, then the
    {e first} affordable spell. There is no ranking of any kind.

    That is the same gap as the move chooser, and it is the thing a harder AI
    has to fix. The ranking is deliberately not written yet so that the
    current behaviour stays testable and any improvement shows up as a visible
    diff rather than a silent behaviour change. *)
let pick_ai_spell ?(difficulty = 1) ?(roll = Random.int) (c : combatant)
    (spells : spell list) : spell option =
  (* 50% skip on easy, 25% on normal, none at hard. *)
  let skip_chance = if difficulty = 0 then 50 else if difficulty = 1 then 25 else 0 in
  let skipped = skip_chance > 0 && roll 100 < skip_chance in
  if skipped then None
  (* [can_cast] rather than [is_castable]: a spell on cooldown is as
     unavailable as one the caster cannot pay for, and the original's
     first-affordable-wins then skips straight past it to the next spell. *)
  else List.find_opt (can_cast ~spells_disallowed:false c) spells
