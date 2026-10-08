open Puzzle_quest_lib
open Board
open Combat
open Item

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_eq name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

(** [check_eq] for string options, which is what GET_ITEM returns. *)
let check_str_eq name got want =
  let show = function None -> "<none>" | Some s -> "\"" ^ s ^ "\"" in
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (show got) (show want);
    incr failures
  end

let lcg seed =
  let s = ref seed in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

let fighter ?(life = 60) id name =
  Combat.make_combatant ~cunning:5 ~max_life:life ~life id name

let descriptor ?(location = Weapon) ?(restriction = NoRequirement)
    ?(on_start_battle = false) id =
  { id; location; shop_cost = 0; rarity = 0; icon = 0; restriction; on_start_battle }

(* ------------------------------------------------------------------ *)
(* The generated descriptor table                                        *)
(* ------------------------------------------------------------------ *)

let () =
  check_eq "160 items are in the table" (List.length Item_data.descriptors) 160;
  let count_loc l =
    List.length
      (List.filter (fun (d : descriptor) -> d.location = l) Item_data.descriptors)
  in
  check_eq "56 weapons" (count_loc Weapon) 56;
  check_eq "44 misc" (count_loc Misc) 44;
  check_eq "34 head" (count_loc Head) 34;
  check_eq "26 body" (count_loc Body) 26;
  let restricted =
    List.length
      (List.filter
         (fun (d : descriptor) -> d.restriction <> NoRequirement)
         Item_data.descriptors)
  in
  check_eq "74 carry a restriction" restricted 74;
  check_eq "86 are unrestricted" (160 - restricted) 86;
  (* IALS is the Arkliche Staff, restricted to 20 earth skill. *)
  (match Item_data.descriptor_of "IALS" with
  | Some d ->
      check "IALS needs 20 earth"
        (match d.restriction with Skill (SEarth, 20) -> true | _ -> false);
      check "and it is a weapon" (d.location = Weapon);
      check "with a real shop cost" (d.shop_cost = 1560)
  | None -> check "IALS is present" false);
  check "an unknown id is absent" (Item_data.descriptor_of "NOPE" = None)

(** An item id from the generated table with the given location and no
    restriction. Picked from the data rather than hardcoded so the fixtures do
    not depend on remembering which of the 160 ids happens to be which. *)
let some_item ~(location : item_location) ~(restricted : bool) : item =
  let ok (d : Item.descriptor) =
    d.location = location
    && (d.restriction <> NoRequirement) = restricted
  in
  let d = List.hd (List.filter ok Item_data.descriptors) in
  Option.get (Item_hooks.item_of_id d.Item.id)

(* ------------------------------------------------------------------ *)
(* GET_ITEM and SET_ITEM                                                *)
(* ------------------------------------------------------------------ *)

let () =
  let l = new_loadout () in
  let w = make_item (descriptor "W1") in
  let h = make_item ~hooks:no_hooks { (descriptor "H1") with location = Head } in
  check "a fresh loadout is empty" (equipped l = []);
  ignore (equip l w);
  check_eq "one item is worn" (List.length (equipped l)) 1;
  check "and it is in the weapon slot" (get_item l Weapon = Some w);
  ignore (equip l h);
  check_eq "now two" (List.length (equipped l)) 2;
  (* Equipping over an occupied slot displaces what was there. *)
  let w2 = make_item (descriptor "W2") in
  let displaced = equip l w2 in
  check "the old weapon comes back" (displaced = Some w);
  check "and the new one takes the slot" (get_item l Weapon = Some w2);
  check_eq "still two items" (List.length (equipped l)) 2;
  (* Slot order is fixed: weapon, head, body, misc. That is what makes two
     items' modifiers compose in a repeatable way. *)
  check "order is weapon then head"
    (List.map item_id (equipped l) = [ "W2"; "H1" ])

let () =
  (* A mutable default would be shared between battles, so equipping anything in
     one battle would leak into the next. This is the check that it is not. *)
  let a = new_loadout () in
  let b = new_loadout () in
  ignore (equip a (make_item (descriptor "W1")));
  check_eq "the second loadout is still empty" (List.length (equipped b)) 0;
  check_eq "and the first still holds its item" (List.length (equipped a)) 1

let () =
  (* Restrictions are checked against skill, not the mana balance: the pool is
     spendable, the skill is not. *)
  let staff = make_item { (descriptor "IALS") with restriction = Skill (SEarth, 20) } in
  let trained = Combat.make_combatant ~skills:{ zero_skills with earth = 25 } 0 "a" in
  let untrained = Combat.make_combatant 0 "b" in
  check "a trained character may wear it" (can_equip trained ~level:20 staff);
  check "an untrained one may not" (not (can_equip untrained ~level:20 staff));
  check "regardless of level" (not (can_equip untrained ~level:99 staff));
  let restricted_level = make_item { (descriptor "L1") with restriction = Level 30 } in
  check "a level requirement compares against level"
    (can_equip untrained ~level:30 restricted_level);
  check "and not below it" (not (can_equip untrained ~level:29 restricted_level));
  check "an unrestricted item always can"
    (can_equip untrained ~level:0 (make_item (descriptor "U1")))

(* ------------------------------------------------------------------ *)
(* Hooks                                                                 *)
(* ------------------------------------------------------------------ *)

let ictx ?(board = Some (of_array_matrix (Array.make_matrix 8 8 Skull))) ?(percentile = 0)
    () : Item.item_context =
  { ic_board = board
  ; ic_percentile = percentile
  ; ic_roll = (fun _ -> 0)
  ; ic_attacker = None
  ; ic_defender = None
  ; ic_hero = fighter 0 "hero"
  ; ic_enemy = fighter 1 "foe"
  }

let () =
  (* IAOM: minus one above one damage. *)
  let i = make_item ~hooks:{ no_hooks with on_give_damage = Some Item_hooks.hook_iaom } (descriptor "IAOM") in
  let at d = give_damage i (ictx ()) ~damage:d ~source:0 ~target:1 in
  check_eq "IAOM leaves one alone" (at 1) 1;
  check_eq "IAOM takes one off two" (at 2) 1;
  check_eq "IAOM takes one off ten" (at 10) 9;
  (* IAOR: plus two from three up. *)
  let j = make_item ~hooks:{ no_hooks with on_give_damage = Some Item_hooks.hook_iaor } (descriptor "IAOR") in
  let at2 d = give_damage j (ictx ()) ~damage:d ~source:0 ~target:1 in
  check_eq "IAOR leaves one alone" (at2 1) 1;
  check_eq "IAOR leaves two alone" (at2 2) 2;
  check_eq "IAOR adds two at three" (at2 3) 5

let () =
  (* IBOI: plus four when the board has eight or more red gems. *)
  let i = make_item ~hooks:{ no_hooks with on_give_damage = Some Item_hooks.hook_iboi } (descriptor "IBOI") in
  let reds n =
    let left = ref n in
    of_array_matrix
      (Array.init 8 (fun _ ->
           Array.init 8 (fun _ ->
               if !left > 0 then begin
                 decr left;
                 Board.Mana Fire
               end else Board.Skull)))
  in
  let at n d = give_damage i (ictx ~board:(Some (reds n)) ()) ~damage:d ~source:0 ~target:1 in
  check_eq "IBOI does nothing with seven reds" (at 7 5) 5;
  check_eq "and adds four at eight" (at 8 5) 9;
  check_eq "and it applies even at zero damage, which the Lua does" (at 8 0) 4

let () =
  (* Two items compose by threading: the second sees what the first returned,
     rather than both reading the original number. *)
  let minus_one =
    make_item
      ~hooks:{ no_hooks with on_give_damage = Some (fun _ d _ _ -> if d > 1 then d - 1 else d) }
      { (descriptor "A") with location = Head }
  in
  let plus_ten =
    make_item
      ~hooks:{ no_hooks with on_give_damage = Some (fun _ d _ _ -> d + 10) }
      { (descriptor "B") with location = Misc }
  in
  (* Different slots on purpose: one item per slot, so two weapons would just
     displace each other. *)
  let l = new_loadout () in
  ignore (equip l minus_one);
  ignore (equip l plus_ten);
  (* 9 -> minus one -> 8 -> plus ten -> 18. If they did not thread it would be
     19 (plus ten reads the original) or 9 (last write wins). *)
  check_eq "two items thread in slot order"
    (fold_give_damage l (ictx ()) ~damage:9 ~source:0 ~target:1
       ~f:(fun _ n -> n))
    18;
  check_eq "and the order is what decides" (fold_give_damage l (ictx ()) ~damage:9 ~source:0 ~target:1 ~f:(fun _ n -> n)) 18

let () =
  (* An item with no hook for an event passes the damage through untouched,
     which is what makes an unported item inert rather than broken. *)
  let plain = make_item (descriptor "PLAIN") in
  check_eq "an item with no hook is transparent"
    (give_damage plain (ictx ()) ~damage:7 ~source:0 ~target:1)
    7

let () =
  (* CountGems, as the item scripts call it. *)
  let cell = ref 0 in
  let pick f =
    let i = !cell in
    incr cell;
    f i
  in
  let board =
    of_array_matrix
      (Array.init 8 (fun _ ->
           Array.init 8 (fun _ ->
               pick (fun i ->
                   if i < 6 then Board.Mana Earth
                   else if i < 12 then Board.Skull
                   else Board.Gold))))
  in
  let ctx = ictx ~board:(Some board) () in
  check_eq "six green" (item_green ctx) 6;
  check_eq "six skulls" (count_gems GSkull ctx) 6;
  check_eq "the other 52 are gold" (count_gems GGold ctx) 52;
  check_eq "a missing board reads zero" (count_gems GSkull { ctx with ic_board = None }) 0

let () =
  (* The lookup table. *)
  check "IAOM is ported" (Item_hooks.hook_of "IAOM" <> None);
  check "IBOI is ported" (Item_hooks.hook_of "IBOI" <> None);
  check "IBSH is not, and says so" (Item_hooks.hook_of "IBSH" = None);
  check "an unknown id has no hook" (Item_hooks.hook_of "NOPE" = None);
  (* Building by id yields a wearable item, and an unported one still exists so
     it can be equipped without effect rather than being absent. *)
  (match Item_hooks.item_of_id "IAOM" with
  | Some i -> check "IAOM builds from the table" (item_id i = "IAOM")
  | None -> check "IAOM builds from the table" false);
  (match Item_hooks.item_of_id "IBSH" with
  | Some i ->
      check "an unported item still exists"
        (give_damage i (ictx ()) ~damage:5 ~source:0 ~target:1 = 5)
  | None -> check "an unported item still exists" false)

let () =
  (* Item hooks and status-effect hooks both apply, and the status effect is the
     outer layer. This is the regression guard for the bug where putting the
     status hook inside the item fold meant it was skipped whenever the loadout
     was empty. *)
  let def =
    { id = "RAGE"; name = "Rage"; duration = 999; stack = 1; icon = 0; script = "";
      hooks = Combat.set_give_damage Combat.no_hooks (fun _ n -> n * 2) }
  in
  let hero = fighter 0 "hero" in
  apply_effect def hero;
  let board =
    of_array_matrix
      (Array.init 8 (fun y ->
           Array.init 8 (fun x ->
               if y = 4 && x < 4 then Board.Skull else Board.Mana Earth)))
  in
  let b =
    Battle.create ~rng:(lcg 3) ~effects:[ def ]
      ~rules:{ Battle.default_rules with max_turns = 3 }
      board hero (fighter ~life:9000 1 "foe")
  in
  let done_b = Battle.run b in
  let raw =
    List.fold_left
      (fun acc -> function Battle.MatchResolved (_, r) -> acc + r.damage | _ -> acc) 0
      (Battle.log_of done_b)
  in
  let dealt =
    List.fold_left
      (fun acc -> function Battle.Damage (_, n) -> acc + n | _ -> acc) 0
      (Battle.log_of done_b)
  in
  check "the status effect applied with an empty loadout" (raw > 0 && dealt > raw)

let () =
  (* GET_ITEM returns a string id, or the empty string for an empty slot. The
     scripts test against "", which is why the empty case is Some "" and not
     None. *)
  let l = new_loadout () in
  check "an empty loadout reports empty strings"
    (List.for_all (fun n -> Item.get_item_slot l n = Some "") [ 0; 1; 2; 3 ]);
  let w = some_item ~location:Weapon ~restricted:false in
  ignore (equip l w);
  check_str_eq "slot 0, the weapon, now reports its id"
    (Item.get_item_slot l 0) (Some (Item.item_id w));
  check "and the others are still empty" (Item.get_item_slot l 1 = Some "");
  (* The slot-to-index mapping is a choice, weapon/head/body/misc. *)
  check "slot_at 0 is the weapon" (slot_at 0 = Some Weapon);
  check "slot_at 3 is misc" (slot_at 3 = Some Misc);
  check "an out-of-range slot is nothing" (slot_at 9 = None);
  check "and reads as empty" (Item.get_item_slot l 9 = Some "")

let () =
  (* SET_ITEM writes a slot by id, displacing what was there. It lives in
     Item_hooks because it needs Item_data, which depends on Item. *)
  let l = new_loadout () in
  (* Copying into an occupied slot hands back what was there. *)
  let held = some_item ~location:Weapon ~restricted:false in
  ignore (equip l held);
  let copy = some_item ~location:Head ~restricted:false in
  let copied = Item_hooks.set_item_slot l 0 (Item.item_id copy) in
  check "the displaced item comes back" (copied <> None);
  check "and it is the one that was in the slot"
    (match copied with Some i -> Item.item_id i = Item.item_id held | None -> false);
  check "and the slot now holds the copy"
    (Item.get_item_slot l 0 = Some (Item.item_id copy));
  check "an unknown id copies nothing"
    (Item_hooks.set_item_slot l 1 "NOPE" = None);
  check "and leaves that slot alone" (Item.get_item_slot l 1 = Some "")

let () =
  (* SDUP's duplication: build the list of slots where the enemy has something
     the caster does not, then take one at random.

     One weapon each with different ids. Both go in the same slot, which is the
     point: there is only ever one item per slot, so the duplication has to look
     across slots to find anything. *)
  let enemy = new_loadout () in
  let enemy_w = some_item ~location:Weapon ~restricted:false in
  let caster_w = some_item ~location:Head ~restricted:false in
  ignore (equip enemy enemy_w);
  let caster = new_loadout () in
  ignore (equip caster caster_w);
  let copy_into slot =
    Item_hooks.duplicate_item ~caster ~enemy ~roll:(fun _ -> slot)
  in
  check "the two weapons differ, so slot 0 is a candidate" (copy_into 0 = Some 0);
  let fresh = new_loadout () in
  let empty = new_loadout () in
  check "nothing to copy when the enemy has nothing"
    (Item_hooks.duplicate_item ~caster:fresh ~enemy:empty ~roll:(fun _ -> 0) = None);
  let only_enemy = new_loadout () in
  ignore (equip only_enemy enemy_w);
  check "but there is something when the enemy has an item"
    (Item_hooks.duplicate_item ~caster:fresh ~enemy:only_enemy ~roll:(fun _ -> 0) = Some 0);
  check "and it landed in the caster's slot"
    (Item.get_item_slot fresh 0 = Some (Item.item_id enemy_w));
  check "a same-item pair has nothing to copy"
    (Item_hooks.duplicate_item ~caster:fresh ~enemy:fresh ~roll:(fun _ -> 0) = None)

let () =
  (* The battle loop keeps each side's loadout apart, which is what makes
     GET_ITEM answerable per combatant. The board is only a starting position
     here; nothing in this block plays it. *)
  let e = [| Board.Mana Fire; Board.Mana Water; Board.Mana Air; Board.Mana Earth |] in
  let board =
    of_array_matrix
      (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))
  in
  let b = Battle.create ~rng:(lcg 5) board (fighter 0 "hero") (fighter 1 "foe") in
  let carried = some_item ~location:Weapon ~restricted:false in
  ignore (Battle.give_item b b.hero ~level:1 carried);
  check_eq "the item is on the hero" (List.length (Item.equipped b.hero_items)) 1;
  check "and readable through GET_ITEM"
    (Item.get_item_slot b.hero_items 0 = Some (Item.item_id carried));
  check "while the foe has nothing" (Item.get_item_slot b.enemy_items 0 = Some "");
  ignore (Battle.give_item b b.enemy ~level:1 carried);
  check_eq "the foe now has one too" (List.length (Item.equipped b.enemy_items)) 1;
  check "and the hero still has exactly one"
    (List.length (Item.equipped b.hero_items) = 1)

let () =
  (* OnStartBattle: the flag the generator reads out of each script, the six
     hand-ported bodies behind it, and the pass that fires them when the
     battle opens. The rune JXXX declares the hook too and is absent from
     both the flag and the table - it reads forged-rune state the forge does
     not model. *)
  let start_ids =
    List.filter_map
      (fun (d : descriptor) -> if d.on_start_battle then Some d.id else None)
      Item_data.descriptors
  in
  check "exactly six scripts declare OnStartBattle"
    (List.sort compare start_ids = [ "IDHE"; "IFLH"; "IWLB"; "IWLM"; "IWLR"; "IWLS" ]);
  check "the hand-ported table covers every flag and nothing else"
    (List.for_all
       (fun (d : descriptor) ->
         d.on_start_battle = (Item_hooks.start_payoffs_of d.id <> []))
       Item_data.descriptors);

  (* Each body applied to its owner, straight through the loadout. *)
  let loadout_of_id id =
    let l = new_loadout () in
    (match Item_hooks.item_of_id id with
     | Some i -> ignore (equip l i)
     | None -> check (id ^ " exists in Item_data") false);
    l
  in
  let he = fighter 0 "he" in
  check "IDHE fires and is reported"
    (Item_hooks.apply_start_battle he (loadout_of_id "IDHE") = [ "IDHE" ]);
  check_eq "IDHE adds 10 water" he.mana.water 10;
  check_eq "IDHE leaves fire alone" he.mana.fire 0;
  let fh = fighter 0 "fh" in
  ignore (Item_hooks.apply_start_battle fh (loadout_of_id "IFLH"));
  check_eq "IFLH adds 8 fire" fh.mana.fire 8;
  check_eq "IFLH leaves water alone" fh.mana.water 0;
  let wl = fighter 0 "wl" in
  check "the wall fires"
    (Item_hooks.apply_start_battle wl (loadout_of_id "IWLM") = [ "IWLM" ]);
  check_eq "IWLM raises the ceiling by 200" wl.max_life 260;
  check_eq "IWLM raises life by 200" wl.life 260;
  let plain = fighter 0 "plain" in
  check "an item without the hook is inert"
    (Item_hooks.apply_start_battle plain (loadout_of_id "IAOM") = []);
  check_eq "and changes no mana" plain.mana.fire 0;
  check "an empty loadout fires nothing"
    (Item_hooks.apply_start_battle plain (new_loadout ()) = []);
  (* Slot order is the loadout's fixed one: head before body. *)
  let both = new_loadout () in
  (match Item_hooks.item_of_id "IDHE" with Some i -> ignore (equip both i) | None -> ());
  (match Item_hooks.item_of_id "IWLB" with Some i -> ignore (equip both i) | None -> ());
  check "worn slots fire in fixed order"
    (Item_hooks.apply_start_battle (fighter 0 "ord") both = [ "IDHE"; "IWLB" ])

let () =
  (* The equipment panel folds into the four battle slots by each item's own
     location: helm to head, armor to body, weapon to weapon, and the panel's
     extra fields to wherever their item says. *)
  let some_item_by_id id = Some (Campaign_items.item_by_id id) in
  let e =
    { Campaign.default_equipment with
      Campaign.helm = some_item_by_id "IDHE";
      Campaign.armor = some_item_by_id "IWLS";
      Campaign.weapon = some_item_by_id "IAOR";
      Campaign.ring1 = some_item_by_id "IALR" }
  in
  let l = Campaign.loadout_of_equipment e in
  check_str_eq "the helm lands in the head slot"
    (Item.get_item l Head |> Option.map Item.item_id) (Some "IDHE");
  check_str_eq "the armor lands in the body slot"
    (Item.get_item l Body |> Option.map Item.item_id) (Some "IWLS");
  check_str_eq "the weapon lands in the weapon slot"
    (Item.get_item l Weapon |> Option.map Item.item_id) (Some "IAOR");
  check_str_eq "the ring lands in the misc slot"
    (Item.get_item l Misc |> Option.map Item.item_id) (Some "IALR");
  (* A body item parked in a non-body panel field still lands by location. *)
  let e2 =
    { Campaign.default_equipment with
      Campaign.gauntlets = Some (Campaign_items.item_by_id "IWLR") }
  in
  check_str_eq "a wall in the gauntlets slot still wears the body slot"
    (Item.get_item (Campaign.loadout_of_equipment e2) Body
     |> Option.map Item.item_id)
    (Some "IWLR")

let () =
  (* Both start passes in one place: companions first, then the items on each
     side, when the battle opens. NSUN needs the Minotaur tag to fire. *)
  let e =
    { Campaign.default_equipment with
      Campaign.helm = Some (Campaign_items.item_by_id "IDHE") }
  in
  let hero = fighter 0 "hero" in
  let enemy = fighter 1 "foe" in
  let b =
    Campaign.open_battle ~hero ~enemy ~enemy_tags:[ "Minotaur" ]
      ~companions:[ "NSUN" ]
      ~hero_items:(Campaign.loadout_of_equipment e) ()
  in
  check_eq "the equipped helm fired through open_battle" b.hero.mana.water 10;
  check_eq "the fire companion fired alongside it" b.hero.mana.fire 10;
  check_eq "the enemy side, with no items, is untouched" b.enemy.mana.water 0;
  let bare = Campaign.open_battle ~hero:(fighter 0 "h2") ~enemy:(fighter 1 "e2")
      ~enemy_tags:[] ~companions:[] ()
  in
  check_eq "no gear and no party changes nothing" bare.hero.mana.water 0;

  if !failures = 0 then print_endline "\nAll item tests passed."
  else begin
    Printf.printf "\n%d item test(s) failed.\n" !failures;
    exit 1
  end
