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

(* ------------------------------------------------------------------ *)
(* The ranked chooser                                                    *)
(* ------------------------------------------------------------------ *)

(** Weights for [score_spell]. Each term is scaled to roughly 0..1000 so the
    weights are readable as relative importance rather than as magic numbers.

    Note what is {e not} here: spell effect strength. The 130 spell scripts have
    not been ported yet, so there is no damage number or heal amount to compare
    spells by. Until there is, these are meta signals read off the spell
    descriptor, which is still a strict improvement on list order, but it is not
    a claim that the chooser knows which spell is strongest. See
    [score_spell] for what each term means and what it is a proxy for. *)
type spell_weights = {
  w_potency : int;  (** how advanced the spell is, from its learn score *)
  w_economy : int;  (** how cheaply it is cast, relative to repeatability *)
  w_rationing : int;  (** how rare each cast is, from its cooldown *)
  w_affinity : int;  (** how well the caster's skills pay for it *)
  w_headroom : int;  (** penalty for emptying the caster's pools *)
}

let default_spell_weights =
  {
    w_potency = 100;
    w_economy = 40;
    w_rationing = 25;
    w_affinity = 60;
    w_headroom = 50;
  }

(** The learn score the original's own spells top out at. Used to normalise, so
    the weight above reads as a proportion of the ceiling rather than as an
    absolute. *)
let learn_score_ceiling = 1000

(** How well suited the caster's training is to this spell's cost.

    A spell is paid for out of one or more elemental pools, and the pools it
    draws on are exactly the ones the character earns. A fire spell is cheap for
    a fire specialist and ruinous for one with no fire at all, and the descriptor
    can tell us the first case from the second without knowing what the spell
    {e does}.

    Returns 0 for a spell with no cost at all, which would otherwise divide by
    zero and dominate everything. *)
let affinity_of (c : combatant) (s : spell) : float =
  let costs = [ (Earth, s.cost_earth); (Fire, s.cost_fire); (Air, s.cost_air); (Water, s.cost_water) ] in
  let paid = List.filter (fun (_, n) -> n > 0) costs in
  match paid with
  | [] -> 0.0
  | _ ->
      (* The weakest pool the spell needs is what gates it, so that is the one to
         score: a spell cheap in a pool the caster has nothing in is not cheap. *)
      let worst =
        List.fold_left
          (fun acc (e, n) -> min acc (float_of_int (skill_in e c.skills) /. float_of_int n))
          infinity paid
      in
      if worst = infinity then 0.0
      else
        (* 10x a caster's skill fully covers a 1-point cost. Beyond that the
           spell is affordable on skill alone and the term stops mattering. *)
        min 1.0 (worst /. 10.0)

(** Fraction of the caster's total mana the spell would consume. Used to
    discourage spending a whole pool on one cast when a cheaper spell would leave
    headroom for the next turn. *)
let spend_fraction (c : combatant) (s : spell) : float =
  let have = total_mana c.mana in
  if have <= 0 then 1.0
  else min 1.0 (float_of_int (total_cost s) /. float_of_int have)

(** Scores one castable spell. Higher is better.

    Every term is a proxy for effect strength rather than effect strength
    itself, because the spell scripts are not ported. The reasoning behind each:

    - {b potency}: [learn_score] is the score a hero needs to have learned the
      spell. The game gates its strongest effects behind high scores, so it is
      the best available stand-in for "this spell is powerful". A 990-score spell
      beats a 350-score one under any weighting that gets the ordering right.
    - {b economy}: a cheap spell can be cast many times a battle. Only a modest
      weight, because a cheap spell is cheap for a reason.
    - {b rationing}: a spell on a long cooldown is cast rarely, so each cast has
      to be worth more. This is what stops the chooser from spending every turn
      on the cheapest spell available.
    - {b affinity}: the caster's skill in the elements the spell draws on.
    - {b headroom}: a penalty for the fraction of the pool spent. This is what
      makes the chooser save a big spell for a turn it is worth using on.

    Deterministic: no rng, and ties keep the first candidate, matching the
    original's strict [<] comparison in [pick_ai_spell]. *)
let score_spell ?(weights = default_spell_weights) (c : combatant) (s : spell) : int =
  let potency =
    (* Normalised against the ceiling, then to 0..1000. *)
    min learn_score_ceiling (max 0 s.learn_score) * 1000 / learn_score_ceiling
  in
  let cost = total_cost s in
  (* A free spell is maximally repeatable. 25 mana is treated as the practical
     ceiling for a single cast; beyond that the term has saturated anyway. *)
  let economy = if cost <= 0 then 1000 else 1000 - min 1000 (cost * 1000 / 25) in
  (* Same 25-turn reference, scaled down since rationing matters less. *)
  let rationing = if s.cooldown <= 0 then 0 else min 1000 (s.cooldown * 1000 / 10) in
  let affinity = int_of_float (affinity_of c s *. 1000.0) in
  (* A full-spend is the worst case, so this is a penalty of up to 1000. *)
  let headroom = 1000 - int_of_float (spend_fraction c s *. 1000.0) in
  (weights.w_potency * potency
   + weights.w_economy * economy
   + weights.w_rationing * rationing
   + weights.w_affinity * affinity
   + weights.w_headroom * headroom)
  / (weights.w_potency + weights.w_economy + weights.w_rationing
    + weights.w_affinity + weights.w_headroom)

(** The replacement for [pick_ai_spell]: scores every castable spell and takes the
    best, rather than the first affordable one.

    The difficulty skip is kept. It is a recovered behaviour, it is orthogonal to
    ranking, and dropping it would confound the comparison between the two
    choosers with a change in cast frequency. *)
let pick_ranked_spell ?(weights = default_spell_weights) ?(difficulty = 1)
    ?(roll = Random.int) (c : combatant) (spells : spell list) : spell option =
  let skip_chance = if difficulty = 0 then 50 else if difficulty = 1 then 25 else 0 in
  if skip_chance > 0 && roll 100 < skip_chance then None
  else
    let best = ref None and best_score = ref min_int in
    List.iter
      (fun s ->
        if can_cast ~spells_disallowed:false c s then begin
          let sc = score_spell ~weights c s in
          if !best_score < sc then begin
            best_score := sc;
            best := Some s
          end
        end)
      spells;
    !best

(** Which chooser the AI uses. A global rather than a per-battle field, because
    this is a policy switch for the enhanced build: set it once at startup and
    every battle follows. Keeping it out of [Battle.rules] would also mean the
    faithful port had a knob on it, which is the thing most worth keeping clean.

    Defaults to [Faithful], so the recovered behaviour is what runs unless
    something asks otherwise. *)
type spell_policy =
  | Faithful  (** the original's first-affordable-wins *)
  | Ranked  (** [pick_ranked_spell] *)

let spell_policy : spell_policy ref = ref Faithful

let set_spell_policy (p : spell_policy) : unit = spell_policy := p
let get_spell_policy () : spell_policy = !spell_policy

(** The entry point the battle loop calls. Dispatches on the global, so the loop
    itself has no knowledge of the two policies. *)
let pick_spell ?weights ?(difficulty = 1) ?(roll = Random.int) (c : combatant)
    (spells : spell list) : spell option =
  match !spell_policy with
  | Faithful -> pick_ai_spell ~difficulty ~roll c spells
  | Ranked -> pick_ranked_spell ?weights ~difficulty ~roll c spells

let string_of_spell_policy = function Faithful -> "faithful" | Ranked -> "ranked"
