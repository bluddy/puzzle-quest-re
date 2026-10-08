(** Hand-ported item scripts.

    [tools/extract_items.ps1] generates the descriptors; the behaviour lives in
    each item's Lua and is ported here, the same split as spells.

    Only the hooks that can be reproduced with machinery the battle loop already
    has are ported. Several very common ones are deliberately absent because they
    need a native that does not exist here yet, and approximating them would be
    worse than not having them:

    - `GET_MAX_MANA_*`, the per-element mana ceiling. 8 items compare a mana pool
      against its cap. The loop models no cap at all, so there is nothing honest
      to compare to.
    - `DESTROY_GEM` and the board-mutating spell helpers. These reach into the
      live grid mid-damage-event.
    - `ADD_TEMP_SKILL` / `ADD_TEMP_RESISTANCE`, which stage a bonus to be applied
      outside the current hook. The staging has no model here.
    - `PERCENTILE_CHANCE_SYNC`, which the original draws fresh {e per call}. The
      context reads one value per damage event, so an item using it is ported
      only where a single roll per event is faithful anyway, which is nowhere;
      IBSH is therefore left unported rather than ported approximately.

    Each entry keeps the Lua it came from, since these are short enough to check
    by eye and the thresholds are the whole behaviour. *)

open Item

(** IAOM: minus one on a hit of two or more.

    ```lua
    if (damage > 1) then damage = damage - 1; NOTIFY_OF_ACTIVATED_ITEM(); end
    return damage
    ``` *)
let hook_iaom _ctx damage _source _target = if damage > 1 then damage - 1 else damage

(** IAOR: plus two on a hit of three or more. *)
let hook_iaor _ctx damage _source _target = if damage >= 3 then damage + 2 else damage

(** IBOI: plus four once there are eight or more red gems on the board. *)
let hook_iboi ctx damage _source _target =
  if item_red ctx >= 8 then damage + 4 else damage

(** IBSH would be minus one at a 10% roll; see the header for why it is not
    ported. Kept as a stub so the id is accounted for rather than silently
    missing. *)
let hook_ibsh _ctx damage _source _target = damage

(** [SET_ITEM(idx, n, id)`, the other half of SDUP's item duplication: copies the
    item id out of the enemy into one of the caster's slots, displacing whatever
    was there.

    Lives here rather than in [Item] because it needs [Item_data] to turn an id
    back into an item, and [Item_data] depends on [Item]. That dependency is the
    reason [Item.get_item_slot] can read a slot but not write one. *)
let set_item_slot (l : loadout) (n : int) (id : string) : Item.item option =
  match Item_data.descriptor_of id with
  | None -> None
  | Some d -> Item.equip_at l n (make_item d)

(** The item in a slot, as [GET_ITEM] reports it: the id, or [""] when empty. *)
let get_item_slot (l : loadout) (n : int) : string = Option.value (Item.get_item_slot l n) ~default:""

(** SDUP's item duplication, which is the only place in the whole asset set that
    reads [GET_ITEM] or calls [SET_ITEM].

    ```lua
    local idxEnemy = GET_ENEMY(idxCaster,0);
    if (GET_ITEM(idxEnemy,0) ~= GET_ITEM(idxCaster,0) and GET_ITEM(idxEnemy,0) ~= "") then
      legalList[legalListSize] = 0; legalListSize = legalListSize + 1;
    end
    -- ...same for slots 1, 2 and 3...
    if (legalListSize > 0) then
      local myChoice = GET_RANDOM_SYNC(0,legalListSize-1);
      local myItem = legalList[myChoice];
      SET_ITEM(idxCaster,myItem,GET_ITEM(idxEnemy,myItem));
    end
    ```

    So it builds the list of slots where the enemy has something the caster does
    not, then picks one at random. Returns the slot it copied into, or [None] when
    there was nothing worth copying.

    Written here rather than alongside SDUP's hook so the [GET_ITEM] and [SET_ITEM]
    halves are live and tested rather than dead code awaiting the spell's port. *)
let duplicate_item ~(caster : loadout) ~(enemy : loadout) ~(roll : int -> int) =
  let candidates =
    List.filter_map
      (fun n ->
        let theirs = Item.get_item_slot enemy n in
        let ours = Item.get_item_slot caster n in
        (* The Lua tests `~= ""` and `~=` against the caster's own slot. *)
        if theirs <> ours && theirs <> Some "" then Some (n, theirs) else None)
      [ 0; 1; 2; 3 ]
  in
  match candidates with
  | [] -> None
  | _ ->
      let n, id = List.nth candidates (roll (List.length candidates)) in
      ignore (set_item_slot caster n (Option.value id ~default:""));
      Some n

(** The ported hooks by item id. *)
let hook_of = function
  | "IAOM" -> Some hook_iaom
  | "IAOR" -> Some hook_iaor
  | "IBOI" -> Some hook_iboi
  | _ -> None

(** Ids with hooks that exist in Lua but are not reproduced yet, so the gap can
    be measured rather than assumed. *)
let known_unported =
  [ "IAOB"; "IAOD"; "IADO"; "IAOR"; "IAOS"; "IAPD"; "IBFH"; "IBIS"; "IBLI"
  ; "IBNS"; "IBOI"; "IBSH"; "IBST"; "IBWS"; "ICAR"; "ICMH"; "ICOS"
  ]

(** Builds a runtime item for [id] from the generated descriptors. Returns [None]
    if the id is not in the table. An item with no ported hook still comes back,
    as an inert item, so an unported item is worn but does nothing rather than
    not existing. *)
let item_of_id (id : string) : item option =
  match Item_data.descriptor_of id with
  | None -> None
  | Some d ->
      let hooks =
        match hook_of id with Some f -> { no_hooks with on_give_damage = Some f } | None -> no_hooks
      in
      Some (make_item ~hooks d)

(** OnStartBattle, hand-ported from the six scripts that declare it - the
    bodies behind the [on_start_battle] flag the descriptor table carries.

    IDHE and IFLH top up a mana bank ([ADD_MANA_WATER(characterIdx,10)],
    [ADD_MANA_FIRE(characterIdx,8)]); the four IWL* walls raise the ceiling
    and the pool together ([ADD_MAX_LIFE] then [ADD_LIFE], the order the
    scripts use: ceiling first, so the life rise is measured against the new
    one). Everything is silent - [NOTIFY_OF_ACTIVATED_ITEM] has no log event
    of its own - and the mana credit is uncapped, the same reading
    [Campaign_companion_hooks]'s ManaBonus already makes.

    The rune JXXX declares OnStartBattle too, and is deliberately absent: its
    body reads the equipped rune's power code and data at fire time, state the
    forge that produces runes does not model yet. A fixed stand-in would be a
    rune that never rolls what the game rolls. *)
type start_payoff =
  | AddMana of Combat.element * int
  | AddLife of int
  | AddMaxLife of int

let start_payoffs_of (id : string) : start_payoff list =
  match id with
  | "IDHE" -> [ AddMana (Combat.Water, 10) ]
  | "IFLH" -> [ AddMana (Combat.Fire, 8) ]
  | "IWLB" -> [ AddMaxLife 100; AddLife 100 ]
  | "IWLM" -> [ AddMaxLife 200; AddLife 200 ]
  | "IWLR" -> [ AddMaxLife 20; AddLife 20 ]
  | "IWLS" -> [ AddMaxLife 50; AddLife 50 ]
  | _ -> []

let apply_start_payoff (who : Combat.combatant) (p : start_payoff) : unit =
  match p with
  | AddMana (e, n) -> who.mana <- Combat.add_mana e n who.mana
  | AddLife n -> who.life <- who.life + n
  | AddMaxLife n -> who.max_life <- who.max_life + n

(** Fires every equipped item's start hook on its owner, in the loadout's fixed
    slot order ([Item.equipped]), returning the ids that had a body to run.
    Mirrors the companion pass in [Campaign.open_battle]: unknown items and
    items without the hook are inert. *)
let apply_start_battle (who : Combat.combatant) (l : loadout) : string list =
  List.fold_left
    (fun fired i ->
      match start_payoffs_of (item_id i) with
      | [] -> fired
      | payoffs ->
          List.iter (apply_start_payoff who) payoffs;
          fired @ [ item_id i ])
    [] (equipped l)