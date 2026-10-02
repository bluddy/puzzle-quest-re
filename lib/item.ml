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
}

let descriptor_of_raw (d : raw_descriptor) : descriptor =
  { id = d.id
  ; location = d.location
  ; shop_cost = d.shop_cost
  ; rarity = d.rarity
  ; icon = d.icon
  ; restriction = restriction_of d
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

    [ic_percentile] is [PERCENTILE_CHANCE_SYNC], read once for the whole damage
    event rather than per item. 27 items call it and the original draws a fresh
    value per call, so with several items on a character this is a deviation; it
    is noted in [lib/item_hooks.ml] rather than hidden.

    [ic_max_mana] used to be [None] and is no longer a field: the ceilings now
    live on the combatants, as [Combat.max_mana], because they are raised by
    items and have to persist across the fight rather than being recomputed. *)
type item_context = {
  ic_board : Board.board option;
  ic_percentile : int;
  ic_roll : int -> int;
  ic_attacker : combatant option;
  ic_defender : combatant option;
  ic_hero : combatant;
  ic_enemy : combatant;
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

(** The damage hooks an item can define, with the signatures its own scripts use.

    Note that the damage hooks name both parties. `OnGiveDamage` is called on the
    {e attacker's} item and receives the defender, and vice versa, which is what
    lets an item distinguish damage it dealt from damage it took. *)
type hooks = {
  on_give_damage : (item_context -> int -> int -> int -> int) option;
      (** (ctx, damage, sourceIdx, targetIdx) -> damage *)
  on_receive_damage : (item_context -> int -> int -> int -> int) option;
      (** (ctx, damage, sourceIdx, targetIdx) -> damage *)
  on_receive_mana : (item_context -> int -> element -> int -> int) option;
      (** (ctx, value, element, characterIdx) -> value *)
  on_receive_gold : (int -> int -> int) option;
  on_receive_xp : (int -> int -> int) option;
  on_query_skill : (int -> int -> int -> int) option;
      (** (value, characterIdx, skillIdx) -> value *)
  on_query_resistance : (int -> element -> int -> int) option;
  on_start_turn : (int -> int -> unit) option;
  on_start_battle : (int -> unit) option;
  on_match4 : (int -> int -> int) option;
  on_match5 : (int -> int -> int) option;
  on_cast_spell : (int -> unit) option;
  on_enemy_cast_spell : (int -> unit) option;
  on_victory : (int -> unit) option;
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

let receive_mana (i : item) (ctx : item_context) ~(value : int) ~(e : element)
    ~(character : int) : int =
  match i.hooks.on_receive_mana with
  | Some f -> f ctx value e character
  | None -> value

let receive_gold (i : item) ~(value : int) ~(character : int) : int =
  match i.hooks.on_receive_gold with Some f -> f value character | None -> value

let receive_xp (i : item) ~(value : int) ~(character : int) : int =
  match i.hooks.on_receive_xp with Some f -> f value character | None -> value

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
