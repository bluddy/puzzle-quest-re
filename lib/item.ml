(** Equipment items.

    Items are a first-class source of the same 37 hook callbacks that status
    effects and spells use, so a character can carry up to four: weapon, head,
    body, and one miscellaneous slot. 160 of them exist in [Assets/Items], and
    [lib/item_data.ml] holds their static descriptors.

    **Why items get their own hook record.** The callback {e names} are shared
    with status effects but their {e signatures} are not. An item's
    [OnGiveDamage] is `function(damage, sourceIdx, targetIdx)`, three arguments
    with the damage first, because it needs to know who did the damage and who
    took it. The status-effect record in [Combat.hooks] is `int -> int -> int`,
    which carries only a character index and an amount. Widening the status
    record to suit items would mean touching working, tested code for no gain, so
    the two records are separate and the {e dispatch} is what stays shared: both
    are walked in the same order at the same points in [Battle], and an item with
    no hooks for a given event simply does not appear in that walk.

    The damage hooks are the important ones: 53 items hook [OnGiveDamage] and 38
    hook [OnReceiveDamage], out of 160. That is where most of an item's strength
    lives, and it is also the part the battle loop already had a hole in - the
    status-effect equivalents were called with an empty effect list. *)

open Combat

type item_location =
  | Weapon
  | Head
  | Body
  | Misc

(** What restricts equipping an item. 86 are unrestricted, 58 need a skill, 16 a
    level.

    The skill form covers all seven character skills, not just the four
    elemental ones: 30 of the 58 skill restrictions are elemental and the other28
    ask for Battle, Morale, or Cunning.

    [Skill] carries its own threshold because the XML's [level] attribute means
    different things on the two forms. On `type="skill" skill="earth" level="20"`
    it is the required *skill* level; on `type="level" level="10"` it is the
    required *hero* level. Sharing one number between them, which an earlier
    version did, makes a 20-earth staff wearable by anyone.

    [NoRequirement] rather than [None], because a constructor named [None] here
    would shadow [option]'s across the whole module and silently turn every
    `ref None` into a [restriction ref]. *)
type restriction =
  | NoRequirement
  | Skill of skill * int  (** the skill, and the level required in it *)
  | Level of int  (** the hero's own level *)

let skill_needed (r : restriction) : (skill * int) option =
  match r with Skill (s, n) -> Some (s, n) | _ -> None

(** The descriptor as the generator emits it: [restriction] is the {e kind} of
    requirement and the detail sits alongside it, because a table of 160 records
    reads better that way than as a nested [Skill e]. [descriptor_of_raw] folds
    the pair back into a single [restriction]. *)
type raw_descriptor = {
  id : string;
  location : item_location;
  shop_cost : int;
  rarity : int;
  icon : int;
  restriction_kind : restriction_kind;
  restriction_skill : skill option;
  restriction_level : int;
  on_start_battle : bool;
      (** Whether the item's script declares [OnStartBattle] in its table. The
          one behaviour the generator reads directly from the Lua; the bodies
          are hand-ported in [Item_hooks]. *)
}

and restriction_kind = RK_none | RK_skill | RK_level

let restriction_of (d : raw_descriptor) : restriction =
  match d.restriction_kind with
  | RK_skill -> (
      match d.restriction_skill with
      | Some e -> Skill (e, d.restriction_level)
      | None -> NoRequirement)
  | RK_level -> (match d.restriction_level with 0 -> NoRequirement | n -> Level n)
  | RK_none -> NoRequirement

type descriptor = {
  id : string;
  location : item_location;
  shop_cost : int;
  rarity : int;
  icon : int;
  restriction : restriction;
  on_start_battle : bool;
}

let descriptor_of_raw (d : raw_descriptor) : descriptor =
  { id = d.id
  ; location = d.location
  ; shop_cost = d.shop_cost
  ; rarity = d.rarity
  ; icon = d.icon
  ; restriction = restriction_of d
  ; on_start_battle = d.on_start_battle
  }

(** The gem kinds the item and spell scripts refer to, as [CountGems]' arguments.

    [GYellow] and friends are the game's colour names, not the board's gem ids:
    Earth is green, Fire red, Air yellow, Water blue. That is the reverse of the
    board's id order, which is exactly where a transposition would creep in, so
    the mapping lives here once rather than at each call site. [GStar] is the
    purple star, gem id 7 on the board. Shared with [Spell], which has the same
    vocabulary in its own scripts. *)
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

(** What an item hook is evaluated against.

    Wider than the spell hook context because the item scripts reach further: they
    read the board, roll dice, and compare against the {e other} combatant.

    [ic_percentile] is [PERCENTILE_CHANCE_SYNC], and it is a {e function} for
    the same reason the native is one: the original draws a fresh value per
    call, so a body that asks twice gets two rolls and two items asking get two
    rolls each. The battle binds it to the fight's rng, which means a hook that
    never asks costs no draw at all - the phantom per-damage-event roll an
    [int] field used to force is gone, and with it the deviation that kept the
    percentile bodies (IBSH and fifteen others) unported.

    [ic_self] is the character whose items are running: the receiver of the
    mana, the owner at turn start, the matcher, the winner. The Lua passes
    [characterIdx] alongside the value for the same purpose, and rather than
    invent an index scheme the port carries the combatant, so [ic_attacker] and
    [ic_defender] stay what they were - the damage event's two parties - and are
    [None] outside one.

    [ic_level] is that character's level, where the battle has one to give: only
    the hero's, from [Battle.rules], so an enemy-worn hook sees [None] and a
    body that reads the level falls through. Nothing in the campaign puts items
    on a monster.

    The [ic_*] callbacks are the natives a body reaches for: [ADD_MANA_<E>],
    [ADD_GOLD], [ADD_XP], [EXTRA_TURN], [Std_InflictDamage], [Std_Healing] and
    [ADD_STATUS_EFFECT] and [MISS_TURNS], bound by whoever built the context - the
    first six to [ic_self], the last two taking the combatant the body names,
    because every script that calls them passes their target. They
    are callbacks rather than calls because two of them must re-enter the very
    fold that is running them - a mana credit inside [OnReceiveMana] has to see
    [OnReceiveMana] again, exactly as the native would - and because [Item]
    cannot name the battle that owns the loadouts. Bodies that only touch their
    own combatant ([ADD_TEMP_RESISTANCE], [ADD_TEMP_SKILL],
    [CLEAR_STATUS_EFFECTS], [ADD_LIFE]) go straight through [Combat] and
    [ic_self] instead, so the callback set stays the natives that need the
    battle to answer.

    [ic_max_mana] used to be [None] and is no longer a field: the ceilings now
    live on the combatants, as [Combat.max_mana], because they are raised by
    items and have to persist across the fight rather than being recomputed.

    The three board callbacks are how a body writes the grid: [ic_set_gem] for
    [SET_GEM], [ic_destroy_gem] for [DESTROY_GEM] (which empties the cell and
    leaves the gravity to whoever drives the event, the way the spell bodies'
    [fx_board] writes do), and [ic_multipliers] for [SetMultiplierEffects],
    the pair of calls GridUtilities.lua wraps a sweep in. Reads go through
    [ic_board], which whoever built the context took at hook entry - so a body
    that empties cells and then reads them sees the grid it started with, which
    for the sweeps the nine bodies make is the same grid either way. *)
type item_context = {
  ic_board : Board.board option;
  ic_percentile : unit -> int;
  ic_roll : int -> int;
  ic_attacker : combatant option;
  ic_defender : combatant option;
  ic_hero : combatant;
  ic_enemy : combatant;
  ic_self : combatant;
  ic_level : int option;
  ic_credit_mana : element -> int -> unit;
  ic_credit_gold : int -> unit;
  ic_credit_xp : int -> unit;
  ic_extra_turn : unit -> unit;
  ic_inflict_damage : int -> unit;
  ic_heal : int -> unit;
  ic_apply_status : combatant -> string -> unit;
  ic_miss_turns : combatant -> int -> unit;
  ic_set_gem : Board.position -> Board.gem -> unit;
  ic_destroy_gem : Board.position -> unit;
  ic_multipliers : bool -> unit;
}


(** [CountGems] as the item scripts use it. *)
let count_gems (kind : gem_kind) (ctx : item_context) : int =
  match ctx.ic_board with
  | None -> 0
  | Some b ->
      let matches g =
        if kind = GAny then g <> Board.Empty else gem_kind_of_board g = kind
      in
      let n = ref 0 in
      for y = 0 to b.Board.height - 1 do
        for x = 0 to b.Board.width - 1 do
          if matches (Board.get_gem b { Board.x; y }) then incr n
        done
      done;
      !n

let item_yellow ctx = count_gems GYellow ctx
let item_green ctx = count_gems GGreen ctx
let item_red ctx = count_gems GRed ctx
let item_blue ctx = count_gems GBlue ctx

(** The other side of a one-on-one fight, from the point of view of [ic_self].
    A body reaches for it with [GET_ENEMY(idx, 0)] - drain the attacker's mana,
    double the damage against a wounded foe - and a battle here is one hero
    against one monster, so that pair is the whole answer. *)
let other_side (ctx : item_context) : combatant =
  if ctx.ic_self.Combat.id = ctx.ic_hero.Combat.id then ctx.ic_enemy else ctx.ic_hero

(** The [GetRandomGrid_*] family from `Assets/Scripts/GetRandomGrid.lua`, as
    three shapes rather than seven functions: the Lua's Not / Not2 / Not3 differ
    only in how many gems they exclude, and Isolated / Isolated2 only in how
    many they stay away from. *)
type random_pick =
  | Of_type of Board.gem
      (** [GetRandomGrid_Type]: the cell is this gem. *)
  | Not of Board.gem list
      (** [GetRandomGrid_Not/Not2/Not3]: the cell is none of these. *)
  | Isolated of Board.gem list
      (** [GetRandomGrid_Isolated/Isolated2]: the cell is none of these and has
          no orthogonal neighbour that is either. *)

(** [NoAdjacentGems(x,y,typ)]: the four orthogonal neighbours inside the grid -
    the cell itself is not among them, and diagonals are not consulted, which
    is what the Lua checks and all it checks. *)
let no_adjacent (grid : Board.board) (p : Board.position) (g : Board.gem) : bool =
  let clear dx dy =
    let q = { Board.x = p.Board.x + dx; y = p.Board.y + dy } in
    q.Board.x < 0
    || q.Board.x >= grid.Board.width
    || q.Board.y < 0
    || q.Board.y >= grid.Board.height
    || Board.get_gem grid q <> g
  in
  clear (-1) 0 && clear 1 0 && clear 0 (-1) && clear 0 1

(** [GetRandomGrid_*]: rejection-sample the grid until the predicate holds, two
    draws per try - x then y - and up to 1001 tries, then return whatever the
    last draw was whether or not it held, which is what the Lua returns.

    [GET_RANDOM_SYNC(1,8)] is a uniform 1..8 over a 1-based grid; the board here
    is 0-based, so the +1 the Lua adds and the -1 the port would need cancel and
    [ic_roll 8] lands on the cell directly - same number of draws either way,
    which is what the rng stream cares about. Returns [None] when there is no
    board to sample. *)
let get_random_grid (ctx : item_context) (pick : random_pick) : Board.position option =
  match ctx.ic_board with
  | None -> None
  | Some grid ->
      let gem_at p = Board.get_gem grid p in
      let holds p =
        match pick with
        | Of_type g -> gem_at p = g
        | Not gs -> not (List.mem (gem_at p) gs)
        | Isolated gs ->
            (not (List.mem (gem_at p) gs))
            && List.for_all (fun g -> no_adjacent grid p g) gs
      in
      let cell = ref { Board.x = 0; y = 0 } in
      let tries = ref 0 in
      let satisfied = ref false in
      while (not !satisfied) && !tries <= 1000 do
        (* Drawn in the Lua's order - x, then y. A record literal would let
           the compiler pick the order and the two rolls could land the other
           way round, which is invisible until a test scripts them. *)
        let x = ctx.ic_roll 8 in
        let y = ctx.ic_roll 8 in
        cell := { Board.x = x; y };
        satisfied := holds !cell;
        incr tries
      done;
      Some !cell

(** [DestroyAllGems(typ, effect)] from GridUtilities.lua: walk the grid y-major
    and empty every cell of that gem. The sparkle is presentation and dropped;
    the empties are left for whoever drives the event to gravity and refill,
    which is what [DESTROY_GEM] means here - see [Spell_effects.destroy_gem]. *)
let destroy_all (ctx : item_context) (g : Board.gem) : unit =
  match ctx.ic_board with
  | None -> ()
  | Some grid ->
      for y = 0 to grid.Board.height - 1 do
        for x = 0 to grid.Board.width - 1 do
          let p = { Board.x; y } in
          if Board.get_gem grid p = g then ctx.ic_destroy_gem p
        done
      done

(** The damage hooks an item can define, with the signatures its own scripts use.

    Note that the damage hooks name both parties. `OnGiveDamage` is called on the
    {e attacker's} item and receives the defender, and vice versa, which is what
    lets an item distinguish damage it dealt from damage it took.

    The five event hooks - receive mana/gold/xp, start turn, match, victory -
    take the context and the value (or nothing) rather than a character index.
    Their Lua passes [characterIdx] to say {e whose} event it is, and the port
    knows that from the loadout it is walking, so the index would be a number
    with nothing behind it; [item_context.ic_self] carries the combatant instead.
    [on_match4]/[on_match5] return nothing, as their Lua does - see the
    [port.match_hooks_return_unit] decision, which the item record now follows
    too (it used to be typed [int -> int -> int] for no body that ever ran). *)
type hooks = {
  on_give_damage : (item_context -> int -> int -> int -> int) option;
      (** (ctx, damage, sourceIdx, targetIdx) -> damage *)
  on_receive_damage : (item_context -> int -> int -> int -> int) option;
      (** (ctx, damage, sourceIdx, targetIdx) -> damage *)
  on_receive_mana : (item_context -> int -> element -> int) option;
      (** (ctx, value, element) -> value *)
  on_receive_gold : (item_context -> int -> int) option;
      (** (ctx, value) -> value *)
  on_receive_xp : (item_context -> int -> int) option;
      (** (ctx, value) -> value *)
  on_query_skill : (int -> int -> int -> int) option;
      (** (value, characterIdx, skillIdx) -> value *)
  on_query_resistance : (int -> element -> int -> int) option;
  on_start_turn : (item_context -> int -> unit) option;
      (** (ctx, turnNumber) -> () *)
  on_start_battle : (int -> unit) option;
  on_match4 : (item_context -> unit) option;
  on_match5 : (item_context -> unit) option;
  on_cast_spell : (int -> unit) option;
  on_enemy_cast_spell : (int -> unit) option;
  on_victory : (item_context -> unit) option;
}

let no_hooks =
  { on_give_damage = None
  ; on_receive_damage = None
  ; on_receive_mana = None
  ; on_receive_gold = None
  ; on_receive_xp = None
  ; on_query_skill = None
  ; on_query_resistance = None
  ; on_start_turn = None
  ; on_start_battle = None
  ; on_match4 = None
  ; on_match5 = None
  ; on_cast_spell = None
  ; on_enemy_cast_spell = None
  ; on_victory = None
  }

type item = { descriptor : descriptor; hooks : hooks }

let item_id (i : item) = i.descriptor.id
let location_of (i : item) = i.descriptor.location

let make_item ?(hooks = no_hooks) (d : descriptor) : item = { descriptor = d; hooks }

(** Whether a character may equip [i], given their skills and hero level.

    The skill requirement is the item's own element, and it is checked against
    the {e skill} rather than the mana balance, for the same reason the extra turn
    roll reads skill: the pool is spendable, the skill is not. The threshold is
    the one the item carries, not [level]. *)
let can_equip (c : combatant) ~(level : int) (i : item) : bool =
  match i.descriptor.restriction with
  | NoRequirement -> true
  | Skill (e, needed) -> skill_in e c.skills >= needed
  | Level n -> level >= n

(** Why [can_equip] said no, for a message or a test. *)
let cannot_equip_reason (c : combatant) ~(level : int) (i : item) : string option =
  if can_equip c ~level i then None
  else
    match i.descriptor.restriction with
    | NoRequirement -> None
    | Skill (e, needed) ->
        Some
          (Printf.sprintf "needs %d %s, has %d" needed (skill_name e)
             (skill_in e c.skills))
    | Level n -> Some (Printf.sprintf "needs hero level %d, is %d" n level)

(** Runs an item's [OnGiveDamage]. [attacker] is whose item it is, [defender] the
    other party, matching the Lua's `sourceIdx` and `targetIdx`. *)
let give_damage (i : item) (ctx : item_context) ~(damage : int) ~(source : int)
    ~(target : int) : int =
  match i.hooks.on_give_damage with Some f -> f ctx damage source target | None -> damage

(** Runs an item's [OnReceiveDamage]. Same arguments, from the defender's side. *)
let receive_damage_hook (i : item) (ctx : item_context) ~(damage : int) ~(source : int)
    ~(target : int) : int =
  match i.hooks.on_receive_damage with Some f -> f ctx damage source target | None -> damage

let receive_mana (i : item) (ctx : item_context) ~(value : int) ~(e : element) : int =
  match i.hooks.on_receive_mana with Some f -> f ctx value e | None -> value

let receive_gold (i : item) (ctx : item_context) ~(value : int) : int =
  match i.hooks.on_receive_gold with Some f -> f ctx value | None -> value

let receive_xp (i : item) (ctx : item_context) ~(value : int) : int =
  match i.hooks.on_receive_xp with Some f -> f ctx value | None -> value

(** The items a character is carrying, keyed by slot. *)
type loadout = {
  mutable weapon : item option;
  mutable head : item option;
  mutable body : item option;
  mutable misc : item option;
}

(** A fresh, empty loadout.

    A function rather than a value, because the record is mutable and this is used
    as a default argument. An `?hero_items = Item.empty_loadout` default would
    hand the {e same} record to every battle that did not pass one, so equipping
    anything in one battle would leak into the next. *)
let new_loadout () : loadout = { weapon = None; head = None; body = None; misc = None }

(** The four equipped items, in a fixed order so hook dispatch is deterministic.
    The original walks the roster in slot order, and a fixed order here is what
    makes two items' modifiers compose in a repeatable way. *)
let equipped (l : loadout) : item list =
  List.filter_map (fun x -> x) [ l.weapon; l.head; l.body; l.misc ]

(** Puts [i] in its slot and returns whatever it displaced, or [None]. A slot
    holds one item of the matching location, so equipping over an occupied slot
    replaces it implicitly rather than needing an explicit unequip first. *)
let equip (l : loadout) (i : item) : item option =
  let previous : item option ref = ref None in
  (match i.descriptor.location with
  | Weapon ->
      previous := l.weapon;
      l.weapon <- Some i
  | Head ->
      previous := l.head;
      l.head <- Some i
  | Body ->
      previous := l.body;
      l.body <- Some i
  | Misc ->
      previous := l.misc;
      l.misc <- Some i);
  !previous

(** The item in a given slot, as the spell hooks' [GET_ITEM] would read it. *)
let get_item (l : loadout) (loc : item_location) : item option =
  match loc with
  | Weapon -> l.weapon
  | Head -> l.head
  | Body -> l.body
  | Misc -> l.misc

(** The slot order [GET_ITEM] indexes, recovered from SDUP's item-duplication
    script: it walks slots 0 to 3 and compares the holder's against the enemy's
    to find something worth copying, so the indices are a fixed four-slot array.

    The {e mapping} from index to slot is not recovered. This uses weapon, head,
    body, misc, which matches [equipped]'s order; nothing in the scripts pins the
    engine's own ordering, so that part is a choice. *)
let slot_at (n : int) : item_location option =
  match n with
  | 0 -> Some Weapon
  | 1 -> Some Head
  | 2 -> Some Body
  | 3 -> Some Misc
  | _ -> None

(** Puts [i] into a specific slot index rather than the slot its location implies.

    Needed because [SET_ITEM] takes an explicit slot, and routing a copy through
    [equip] would file it under the item's own location instead. *)
let equip_at (l : loadout) (n : int) (i : item) : item option =
  let previous = ref None in
  let place x =
    previous := x;
    Some i
  in
  (match slot_at n with
  | Some Weapon -> l.weapon <- place l.weapon
  | Some Head -> l.head <- place l.head
  | Some Body -> l.body <- place l.body
  | Some Misc -> l.misc <- place l.misc
  | None -> ());
  !previous


(** [GET_ITEM(idx, n)]: the item id in slot [n], or [""] when the slot is empty.

    The original returns a {e string}, not an index: [Engine_GET_ITEM_483af0]
    pushes a std::string - and the scripts compare ids directly and test against
    the empty string, which is why the empty case is [Some ""] rather than
    [None]. *)
let get_item_slot (l : loadout) (n : int) : string option =
  match slot_at n with
  | None -> Some ""
  | Some loc -> (
      match get_item l loc with Some i -> Some (item_id i) | None -> Some "")

(** The loadout [GET_ITEM(idx, n)] would read for a given combatant, which is
    what the spell AI hooks need in order to answer it. *)
let loadout_for (b : loadout option) (n : int) : string option =
  match b with None -> Some "" | Some l -> get_item_slot l n

(** Folds [f] over every equipped item's [OnGiveDamage], in slot order.

    The value is threaded: each item sees what the previous one returned. That is
    the whole point of the chain, since an item that halves damage and an item
    that adds a flat bonus have to compose rather than both reading the original
    number and the last write winning arbitrarily. *)
let fold_give_damage (l : loadout) (ctx : item_context) ~(damage : int) ~(source : int)
    ~(target : int) ~(f : item -> int -> int) : int =
  List.fold_left
    (fun acc i -> f i (give_damage i ctx ~damage:acc ~source ~target))
    damage (equipped l)

let fold_receive_damage (l : loadout) (ctx : item_context) ~(damage : int) ~(source : int)
    ~(target : int) ~(f : item -> int -> int) : int =
  List.fold_left
    (fun acc i -> f i (receive_damage_hook i ctx ~damage:acc ~source ~target))
    damage (equipped l)

(** The same threading for the value hooks: each item sees what the previous one
    returned, so an item that doubles a mana credit and an item that adds a flat
    one compose rather than both reading the number the match produced. The
    side effects - a second pool credited, gold banked, an extra turn granted -
    happen as each body runs, which is what the natives they call would do. *)
let fold_receive_mana (l : loadout) (ctx : item_context) ~(value : int) ~(e : element) :
    int =
  List.fold_left
    (fun acc i ->
      match i.hooks.on_receive_mana with Some f -> f ctx acc e | None -> acc)
    value (equipped l)

let fold_receive_gold (l : loadout) (ctx : item_context) ~(value : int) : int =
  List.fold_left
    (fun acc i -> match i.hooks.on_receive_gold with Some f -> f ctx acc | None -> acc)
    value (equipped l)

let fold_receive_xp (l : loadout) (ctx : item_context) ~(value : int) : int =
  List.fold_left
    (fun acc i -> match i.hooks.on_receive_xp with Some f -> f ctx acc | None -> acc)
    value (equipped l)

(** [OnStartTurn], walked in the loadout's fixed slot order like every other
    dispatch, returning the ids that had a body. The turn number is the battle's
    own elapsed count, which is what [Combat.run_start_of_turn_effects] is
    handed too. *)
let run_start_turn (l : loadout) (ctx : item_context) ~(turn : int) : string list =
  List.fold_left
    (fun fired i ->
      match i.hooks.on_start_turn with
      | Some f ->
          f ctx turn;
          fired @ [ item_id i ]
      | None -> fired)
    [] (equipped l)

(** [OnMatch4] / [OnMatch5], one or the other: a run of five is the match5
    event, not both. The Lua says as much - IRKK's match5 body is a call to its
    own match4, which would be redundant if the engine fired both. *)
let run_match (l : loadout) (ctx : item_context) ~(of_five : bool) : string list =
  List.fold_left
    (fun fired i ->
      let h = if of_five then i.hooks.on_match5 else i.hooks.on_match4 in
      match h with
      | Some f ->
          f ctx;
          fired @ [ item_id i ]
      | None -> fired)
    [] (equipped l)

(** [OnVictory], for the side that won. *)
let run_victory (l : loadout) (ctx : item_context) : string list =
  List.fold_left
    (fun fired i ->
      match i.hooks.on_victory with
      | Some f ->
          f ctx;
          fired @ [ item_id i ]
      | None -> fired)
    [] (equipped l)

