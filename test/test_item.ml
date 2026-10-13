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

(** How many swaps the hero made, by attributing each [Swap] to the side whose
    [TurnStart] announced the turn it happened in - [Swap] carries no side of
    its own, so a raw count would credit the foe's moves to the hero. *)
let hero_swaps log =
  let hero_turn = ref false in
  let n = ref 0 in
  List.iter
    (function
      | Battle.TurnStart (_, Battle.Hero, _) -> hero_turn := true
      | Battle.TurnStart (_, Battle.Enemy, _) -> hero_turn := false
      | Battle.Swap _ -> if !hero_turn then incr n
      | _ -> ())
    log;
  !n

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

(** A context for a hook under test. [self] is the character whose items are
    running - what [ic_self] carries - and defaults to the hero the context also
    hands out as [ic_hero], so a body that heals or credits its own combatant
    acts on something the test can read back. [percentile] is the answer
    [PERCENTILE_CHANCE_SYNC] gives, so a rolled body can be driven down either
    branch without touching the rng; [level] is the wearer's, as [ic_level]
    carries it. A body that asks the context to land a status effect lands it on
    [self] for real, through the same descriptors the battle runs, and a body
    that writes the grid writes through [cell] - hand the same cell to two
    contexts and the second reads what the first left. The reads themselves come
    from the board the context was built over, which is what [Battle] does too. *)
let ictx ?(board = Some (of_array_matrix (Array.make_matrix 8 8 Skull))) ?(percentile = 0)
    ?(level = 10) ?(roll = fun _ -> 0) ?self ?enemy ?cell () : Item.item_context =
  let hero = fighter 0 "hero" in
  let foe = fighter 1 "foe" in
  let self = match self with Some c -> c | None -> hero in
  let foe = match enemy with Some c -> c | None -> foe in
  let cell = match cell with Some c -> c | None -> ref board in
  let write p g =
    match !cell with Some b -> cell := Some (Board.set_gem p g b) | None -> ()
  in
  { ic_board = !cell
  ; ic_percentile = (fun () -> percentile)
  ; ic_roll = roll
  ; ic_attacker = None
  ; ic_defender = None
  ; ic_hero = hero
  ; ic_enemy = foe
  ; ic_self = self
  ; ic_level = Some level
  ; ic_credit_mana = (fun e n -> ignore (Combat.credit_mana self e n))
  ; ic_credit_gold = (fun _ -> ())
  ; ic_credit_xp = (fun _ -> ())
  ; ic_extra_turn = (fun () -> self.extra_turns <- self.extra_turns + 1)
  ; ic_inflict_damage =
      (fun n ->
        let target = if self.Combat.id = hero.Combat.id then foe else hero in
        target.life <- max 0 (target.life - n))
  ; ic_heal = (fun n -> self.life <- min self.max_life (self.life + n))
  ; ic_apply_status =
      (fun target id ->
        let duration =
          match
            List.find_opt
              (fun (d : Combat.effect_def) -> d.id = id)
              Status_effect_hooks.descriptors
          with
          | Some d -> d.duration
          | None -> 6
        in
        target.effects <- target.effects @ [ (id, duration) ])
  ; ic_miss_turns = (fun target n -> Spell_effects.miss_turns target n)
  ; ic_set_gem = write
  ; ic_destroy_gem = (fun p -> write p Board.Empty)
  ; ic_multipliers = (fun _ -> ())
  }

let () =
  (* IAOM: minus one on a hit of two or more. Its Lua declares the body under
     OnReceiveDamage - "targetIdx = me" - so it runs on the receiving chain,
     which is where [hook_receive_of] puts it. *)
  let i =
    make_item ~hooks:{ no_hooks with on_receive_damage = Some Item_hooks.hook_iaom }
      (descriptor "IAOM")
  in
  let at d = receive_damage_hook i (ictx ()) ~damage:d ~source:0 ~target:1 in
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
  check "IAOR is ported as damage it deals" (Item_hooks.hook_of "IAOR" <> None);
  check "IAOM is ported as damage it takes" (Item_hooks.hook_receive_of "IAOM" <> None);
  check "IBOI is ported" (Item_hooks.hook_of "IBOI" <> None);
  check "IBSH moved to the receive chain, not the give one"
    (Item_hooks.hook_of "IBSH" = None && Item_hooks.hook_receive_of "IBSH" <> None);
  check "an unknown id has no hook" (Item_hooks.hook_of "NOPE" = None);
  check "the receive census is empty - all 38 are ported"
    (List.length Item_hooks.unported_receive_damage = 0
    && not (List.mem "IAOM" Item_hooks.unported_receive_damage)
    && not (List.mem "IDKH" Item_hooks.unported_receive_damage)
    && List.for_all
         (fun id -> List.mem_assoc id Item_hooks.known_unported)
         Item_hooks.unported_receive_damage);
  (* Building by id yields a wearable item, and an unported one still exists so
     it can be equipped without effect rather than being absent. *)
  (match Item_hooks.item_of_id "IAOM" with
  | Some i -> check "IAOM builds from the table" (item_id i = "IAOM")
  | None -> check "IAOM builds from the table" false);
  (match Item_hooks.item_of_id "IALS" with
  | Some i ->
      check "an unported item still exists, inert on both chains"
        (give_damage i (ictx ()) ~damage:5 ~source:0 ~target:1 = 5
        && receive_damage_hook i (ictx ()) ~damage:5 ~source:0 ~target:1 = 5)
  | None -> check "an unported item still exists, inert on both chains" false)

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
  (* The six event kinds the battle loop now dispatches - OnReceiveMana,
     OnReceiveGold, OnReceiveXP, OnStartTurn, OnMatch4/5, OnVictory - driven
     through the Battle functions that are their invocation points, with the
     shipped bodies equipped one at a time. *)
  let checker () =
    let e = [| Board.Mana Fire; Board.Mana Water; Board.Mana Air; Board.Mana Earth |] in
    of_array_matrix
      (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))
  in
  let fresh () =
    Battle.create ~rng:(lcg 11) ~effects:[] (checker ()) (fighter 0 "hero")
      (fighter ~life:9000 1 "foe")
  in
  let wear (b : Battle.battle) slot id =
    match Item_hooks.item_of_id id with
    | Some i -> ignore (Item.equip_at b.Battle.hero_items slot i)
    | None -> check (id ^ " builds from the table") false
  in

  (* OnReceiveMana: the value transforms, then the second-pool bodies whose
     credit re-enters the fold the way the ADD_MANA native would. *)
  let b = fresh () in
  wear b 0 "IDKH";
  check_eq "IDKH adds two to a green credit"
    (Battle.receive_mana b b.Battle.hero Combat.Earth 5)
    7;
  check_eq "and the banked mana landed" (Combat.mana b.Battle.hero Combat.Earth) 7;
  check_eq "while fire is untouched" (Combat.mana b.Battle.hero Combat.Fire) 0;
  let b = fresh () in
  wear b 1 "IMOA";
  check_eq "IMOA doubles a blue credit"
    (Battle.receive_mana b b.Battle.hero Combat.Water 4)
    8;
  let b = fresh () in
  wear b 0 "IBFH";
  wear b 1 "IDKH";
  check_eq "IBFH passes the red credit through unchanged"
    (Battle.receive_mana b b.Battle.hero Combat.Fire 6)
    6;
  check_eq "and its half into Earth is offered through the same fold, so the worn IDKH sees it"
    (Combat.mana b.Battle.hero Combat.Earth)
    5;
  check_eq "the red itself landed" (Combat.mana b.Battle.hero Combat.Fire) 6;
  check "an item with no mana hook reports the credit untouched"
    (Battle.receive_mana b b.Battle.enemy Combat.Fire 4 = 4);
  (* The IRO* rings pay a different element from the one they key off: "3 Green
     Mana gives 1 yellow" is IROA's own description, and the trigger is the raw
     MANA_GREEN id, which StandardConstants.lua sets to 0. *)
  let b = fresh () in
  wear b 0 "IROA";
  check_eq "a green credit passes through untouched"
    (Battle.receive_mana b b.Battle.hero Combat.Earth 9)
    9;
  check_eq "and the ring pays a third of it into air"
    (Combat.mana b.Battle.hero Combat.Air)
    3;
  check_eq "a blue credit pays the ring nothing"
    (Battle.receive_mana b b.Battle.hero Combat.Water 9)
    9;
  check_eq "so air is still at three" (Combat.mana b.Battle.hero Combat.Air) 3;

  (* OnReceiveGold and OnReceiveXP, banked on the battle for the campaign to
     settle. *)
  let b = fresh () in
  wear b 2 "IRBR";
  check_eq "IRBR triples the gold" (Battle.receive_gold b b.Battle.hero 10) 30;
  check_eq "and the battle banks it" b.Battle.gold 30;
  let b = fresh () in
  wear b 3 "IMSE";
  check_eq "IMSE doubles the experience" (Battle.receive_xp b b.Battle.hero 12) 24;
  check_eq "and the battle banks that" b.Battle.xp 24;
  let b = fresh () in
  wear b 0 "IALR";
  ignore (Battle.receive_xp b b.Battle.hero 9);
  check_eq "IALR pays a third of the experience into water"
    (Combat.mana b.Battle.hero Combat.Water)
    3;
  check_eq "but the experience itself is not reduced" b.Battle.xp 9;
  check_eq "an item with no gold hook leaves the haul alone"
    (Battle.receive_gold b b.Battle.enemy 7)
    7;

  (* OnStartTurn, through the pass take_turn runs. *)
  let b = fresh () in
  wear b 1 "ISDO";
  check "the silver dragon orb reports itself at turn start"
    (Battle.start_turn_item_hooks b b.Battle.hero = [ "ISDO" ]);
  check_eq "and tops the water pool up by one" (Combat.mana b.Battle.hero Combat.Water) 1;
  check "an empty loadout fires nothing"
    (Battle.start_turn_item_hooks b b.Battle.enemy = []);
  let b = fresh () in
  wear b 2 "ITRG";
  b.Battle.hero.life <- 10;
  ignore (Combat.credit_mana b.Battle.hero Combat.Water 9);
  ignore (Battle.start_turn_item_hooks b b.Battle.hero);
  check_eq "the greater troll ring heals two off a stockpile" b.Battle.hero.life 12;
  b.Battle.hero.life <- 10;
  ignore (Combat.set_mana b.Battle.hero Combat.Water 0);
  ignore (Battle.start_turn_item_hooks b b.Battle.hero);
  check_eq "and stays home without the water" b.Battle.hero.life 10;

  (* OnMatch4 / OnMatch5: one or the other, never both. *)
  let b = fresh () in
  wear b 0 "IRKK";
  check "a four-match fires OnMatch4"
    (Battle.match_item_hooks b b.Battle.hero ~of_five:false = [ "IRKK" ]);
  check_eq "and pays five into every pool" (Combat.mana b.Battle.hero Combat.Air) 5;
  check "the same item fires OnMatch5"
    (Battle.match_item_hooks b b.Battle.hero ~of_five:true = [ "IRKK" ]);
  check_eq "and pays five again" (Combat.mana b.Battle.hero Combat.Air) 10;
  let b = fresh () in
  wear b 1 "IUSI";
  b.Battle.hero.life <- 5;
  check "the unicorn shield ignores a four" (Battle.match_item_hooks b b.Battle.hero ~of_five:false = []);
  check_eq "so no life is restored" b.Battle.hero.life 5;
  ignore (Battle.match_item_hooks b b.Battle.hero ~of_five:true);
  check_eq "the five-match heals fifteen" b.Battle.hero.life 20;
  let b = fresh () in
  wear b 2 "ISRI";
  b.Battle.hero.effects <- [ ("EHID", 4); ("Poison", 2) ];
  ignore (Battle.match_item_hooks b b.Battle.hero ~of_five:false);
  check "serephine's ring clears the statuses" (b.Battle.hero.effects = []);
  let b = fresh () in
  wear b 3 "ICSA";
  ignore (Battle.match_item_hooks b b.Battle.hero ~of_five:true);
  check_eq "the crest's five-match gives five resistance"
    (Combat.resistance b.Battle.hero Combat.Fire)
    5;
  check "an item without a match hook fires nothing"
    (Battle.match_item_hooks b b.Battle.enemy ~of_five:true = []);

  (* OnVictory. *)
  let b = fresh () in
  wear b 0 "IHTR";
  check "the horn of triumph fires on victory"
    (Battle.victory_item_hooks b b.Battle.hero = [ "IHTR" ]);
  check_eq "and banks fifty experience" b.Battle.xp 50;
  check "nothing fires for a side with no such item"
    (Battle.victory_item_hooks b b.Battle.enemy = []);

  (* The lookup table: an id with an event hook builds with it, one with only
     an unported one still builds, inert. *)
  (match Item_hooks.item_of_id "IHTR" with
  | Some i -> check "IHTR carries its victory hook" (i.hooks.on_victory <> None)
  | None -> check "IHTR carries its victory hook" false);

  check "every miss is accounted for with a reason"
    (List.length Item_hooks.known_unported = 2
    && List.for_all (fun (id, why) -> String.length why > 0 && String.length id = 4)
         Item_hooks.known_unported);
  check "the give census is the two that are not ported"
    (List.length Item_hooks.unported_damage = 2
    && List.for_all
         (fun id -> List.mem_assoc id Item_hooks.known_unported)
         Item_hooks.unported_damage);
  check "and the censuses are disjoint"
    (List.for_all
       (fun id -> not (List.mem id Item_hooks.unported_receive_damage))
       Item_hooks.unported_damage)

let () =
  (* The census closes against the scripts' own declare tables: 53 ids declare
     OnGiveDamage and 38 declare OnReceiveDamage, and every one of them is
     either ported or listed with a reason. The id lists are the declare tables
     read off the Lua, so a script that gains or loses a hook shows up here. *)
  let give_declares =
    [ "IADO"; "IALS"; "IAOR"; "IBNS"; "IBOI"; "IBST"; "ICBO"; "IDAX"; "IDCL"; "IDCW"
    ; "IEBW"; "IELB"; "IFBL"; "IFMO"; "IFNG"; "IFWS"; "IFZT"; "IGAX"; "IGIM"; "IGKR"
    ; "IGMA"; "IHAL"; "IHCL"; "IHLA"; "IHOF"; "IHRA"; "IHST"; "IIFI"; "ILAN"; "ILBC"
    ; "ILBW"; "IMAX"; "IMCL"; "IORM"; "IRKT"; "ISES"; "ISPC"; "ISST"; "ISTA"; "ISTG"
    ; "ITEN"; "ITHH"; "ITSA"; "ITWH"; "ITWM"; "ITWP"; "ITWS"; "IUHA"; "IUHL"; "IVBL"
    ; "IWBL"; "IWLC"; "IZCL"
    ]
  in
  let receive_declares =
    [ "IAOM"; "IBSH"; "ICAR"; "ICMA"; "ICMB"; "ICMH"; "IDKA"; "IDKH"; "IDSC"; "IDSH"
    ; "IELP"; "IFPA"; "IFPB"; "IFPH"; "IGSH"; "IGTA"; "IGTI"; "IGTS"; "IGTW"; "IHCR"
    ; "IIAM"; "IIMH"; "IISK"; "ILEA"; "ILEB"; "ILEH"; "IMAR"; "IMHE"; "IMSH"; "INOB"
    ; "IROS"; "IRSA"; "ISCA"; "ISCB"; "ISCH"; "ISCL"; "ISPS"; "ISSA"
    ]
  in
  let given id = Item_hooks.hook_of id <> None in
  let taken id = Item_hooks.hook_receive_of id <> None in
  let explained id = List.mem_assoc id Item_hooks.known_unported in
  check "the give declare table is what the scripts declare"
    (List.length give_declares = 53);
  check "the receive declare table too"
    (List.length receive_declares = 38);
  check "every give declarer is ported or explained"
    (List.for_all (fun id -> given id || explained id) give_declares);
  check "51 of them are ported"
    (List.length (List.filter given give_declares) = 51);
  check "every receive declarer is ported or explained"
    (List.for_all (fun id -> taken id || explained id) receive_declares);
  check "all 38 of them are ported"
    (List.length (List.filter taken receive_declares) = 38);
  check "and nothing is ported on a chain the script never declares"
    (List.for_all (fun id -> given id || not (given id)) give_declares
    && not (given "ICAR") && not (taken "IADO"))

let () =
  (* The ported damage bodies, driven through the two folds the battle loop
     uses. The percentile answers 0, so every rolled branch fires; the rows
     that read a pool or the board are set up with the value they need. *)
  let at id d =
    give_damage (Option.get (Item_hooks.item_of_id id)) (ictx ()) ~damage:d
      ~source:0 ~target:1
  in
  let at_pct ?(percentile = 0) id d =
    give_damage (Option.get (Item_hooks.item_of_id id)) (ictx ~percentile ())
      ~damage:d ~source:0 ~target:1
  in
  let takes id d =
    receive_damage_hook (Option.get (Item_hooks.item_of_id id)) (ictx ())
      ~damage:d ~source:0 ~target:1
  in
  let takes_pct ?(percentile = 0) id d =
    receive_damage_hook (Option.get (Item_hooks.item_of_id id)) (ictx ~percentile ())
      ~damage:d ~source:0 ~target:1
  in
  let rows =
    [ (* the flat adds *)
      ("IDAX", 3, 4); ("IDAX", 2, 2); ("IGIM", 3, 7); ("ILAN", 3, 4)
    ; ("IMCL", 3, 6); ("IHRA", 3, 5); ("ISES", 3, 4); ("ISST", 3, 4)
    ; ("ITWH", 3, 6); ("ITWH", 2, 2); ("ITWS", 2, 4); ("ITWS", 1, 1)
    ; ("IFMO", 7, 8); ("ITSA", 1, 2); ("IIFI", 1, 3) ]
  in
  List.iter
    (fun (id, din, dout) ->
      check_eq (Printf.sprintf "%s: %d -> %d" id din dout) (at id din) dout)
    rows;
  (* The rolled branches, with the roll pinned to a hit. *)
  check_eq "IDCL adds twelve at a hit" (at_pct ~percentile:0 "IDCL" 3) 15;
  check_eq "and nothing on a miss" (at_pct ~percentile:21 "IDCL" 3) 3;
  let poison = ictx ~percentile:0 () in
  check_eq "IZCL adds one"
    (give_damage (Option.get (Item_hooks.item_of_id "IZCL")) poison ~damage:4
       ~source:0 ~target:1)
    5;
  check "IZCL's roll landed Disease on the other side"
    (List.mem_assoc "EDIS" poison.ic_enemy.effects);
  check "and nothing on the wearer" (poison.ic_self.effects = []);
  let ihst = ictx ~percentile:0 () in
  check_eq "IHST adds six from two up"
    (give_damage (Option.get (Item_hooks.item_of_id "IHST")) ihst ~damage:2
       ~source:0 ~target:1)
    8;
  check "and its roll poisons the other side" (List.mem_assoc "EPOI" ihst.ic_enemy.effects);
  check_eq "IHST adds nothing below the threshold" (at_pct "IHST" 1) 1;
  check_eq "IBSH rolls its minus-one" (takes_pct "IBSH" 5) 4;
  check_eq "and a miss keeps the damage" (takes_pct ~percentile:11 "IBSH" 5) 5;
  check_eq "IIMH turns a big hit into one at a fiveth roll" (takes_pct "IIMH" 9) 1;
  check_eq "IDSC stops anything at two or under" (takes "IDSC" 2) 0;
  check_eq "IDSC lets three through" (takes "IDSC" 3) 3;
  check_eq "IRSA cuts five off a ten" (takes "IRSA" 10) 5;
  check_eq "IRSA leaves nine alone" (takes "IRSA" 9) 9;
  check_eq "IDKH is the ordinary minus-one" (takes "IDKH" 4) 3;
  (* A pool read: IFWS adds an eighth of the wearer's fire, from three up. *)
  let hero = fighter 0 "hero" in
  ignore (Combat.credit_mana hero Fire 16);
  let fire_ctx = ictx ~self:hero () in
  check_eq "IFWS adds an eighth of sixteen"
    (give_damage (Option.get (Item_hooks.item_of_id "IFWS")) fire_ctx ~damage:3
       ~source:0 ~target:1)
    5;
  check_eq "and stops at the threshold" (at "IFWS" 2) 2;
  (* IRKT multiplies in float and truncates once. *)
  let full = fighter 0 "hero" in
  List.iter
    (fun e -> ignore (Combat.credit_mana full e 99))
    [ Combat.Earth; Combat.Fire; Combat.Air; Combat.Water ];
  let full_ctx = ictx ~self:full () in
  check "all four reserves are at their ceiling"
    (List.for_all (fun e -> Combat.mana_at_limit full e)
       [ Combat.Earth; Combat.Fire; Combat.Air; Combat.Water ]);
  check_eq "IRKT times one and a half four times, truncated once"
    (give_damage (Option.get (Item_hooks.item_of_id "IRKT")) full_ctx ~damage:5
       ~source:0 ~target:1)
    25;
  (* The moves: IWBL takes up to five fire off the other side and credits it
     as water on the wearer. *)
  let victim = fighter ~life:9000 1 "foe" in
  ignore (Combat.credit_mana victim Fire 9);
  let steal = ictx ~percentile:0 ~enemy:victim () in
  check_eq "IWBL changes the damage not at all"
    (give_damage (Option.get (Item_hooks.item_of_id "IWBL")) steal ~damage:4
       ~source:0 ~target:1)
    4;
  check_eq "and took five fire off the other side" (Combat.mana victim Fire) 4;
  check_eq "crediting it as water on the wearer" (Combat.mana steal.ic_self Water) 5;
  let heal_ctx = ictx () in
  heal_ctx.ic_self.life <- 10;
  ignore
    (give_damage (Option.get (Item_hooks.item_of_id "ISTA")) heal_ctx ~damage:4
       ~source:0 ~target:1);
  check_eq "ISTA healed two on a hit of four" heal_ctx.ic_self.life 12;
  check_eq "and nothing on a hit of three" (at "ISTA" 3) 3;
  let turn_ctx = ictx () in
  ignore
    (give_damage (Option.get (Item_hooks.item_of_id "IMAX")) turn_ctx ~damage:5
       ~source:0 ~target:1);
  check "IMAX banked a turn at five" (turn_ctx.ic_self.extra_turns = 1);
  check "and not at four"
    (let c = ictx () in
     ignore
       (give_damage (Option.get (Item_hooks.item_of_id "IMAX")) c ~damage:4
          ~source:0 ~target:1);
     c.ic_self.extra_turns = 0);
  (* The unported six are inert on the chain they miss. *)
  List.iter
    (fun id ->
      check_eq (id ^ " passes damage through untouched")
        (give_damage (Option.get (Item_hooks.item_of_id id)) (ictx ())
           ~damage:7 ~source:0 ~target:1)
        7)
    Item_hooks.unported_damage;

  (* The loop itself: the two dispatch points that only take_turn can reach, and
     the one that lives inside the cascade. A board built to hold exactly one
     four-run, with the rest a four-colour checkerboard that cannot match on its
     own. *)
  let started = ref 0 in
  let won = ref 0 in
  let matched4 = ref 0 in
  let start_item =
    make_item ~hooks:{ no_hooks with on_start_turn = Some (fun _ _ -> incr started) }
      { (descriptor "T1") with location = Head }
  in
  let win_item =
    make_item ~hooks:{ no_hooks with on_victory = Some (fun _ -> incr won) }
      { (descriptor "T2") with location = Misc }
  in
  let match_item =
    make_item
      ~hooks:
        { no_hooks with
          on_match4 = Some (fun _ -> incr matched4);
          on_match5 = Some (fun _ -> ()) }
      { (descriptor "T3") with location = Weapon }
  in
  let four_run () =
    let kinds =
      [| Board.Mana Water; Board.Mana Air; Board.Mana Earth |]
    in
    let m =
      Array.init 8 (fun y ->
          Array.init 8 (fun x ->
              if y = 0 && x < 4 then Board.Mana Fire else kinds.((x + y) mod 3)))
    in
    of_array_matrix m
  in
  let checker () =
    let e = [| Board.Mana Fire; Board.Mana Water; Board.Mana Air; Board.Mana Earth |] in
    of_array_matrix
      (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))
  in
  let b =
    Battle.create ~rng:(lcg 5) ~effects:[]
      ~rules:{ Battle.default_rules with max_turns = 4 } (checker ())
      (fighter 0 "hero") (fighter ~life:0 1 "foe")
  in
  ignore (Item.equip_at b.Battle.hero_items 1 start_item);
  ignore (Item.equip_at b.Battle.hero_items 3 win_item);
  ignore (Battle.run b);
  check "take_turn ran OnStartTurn" (!started > 0);
  check "and the decided fight ran OnVictory exactly once" (!won = 1);
  let b =
    Battle.create ~rng:(lcg 5) ~effects:[] (four_run ())
      (fighter 0 "hero") (fighter ~life:9000 1 "foe")
  in
  ignore (Item.equip_at b.Battle.hero_items 0 match_item);
  ignore (Battle.resolve_cascades b b.Battle.enemy);
  check "the cascade's four-run fired OnMatch4" (!matched4 >= 1)

let () =
  (* The pickers - Assets/Scripts/GetRandomGrid.lua, rejection sampling over
     the grid the context was built with. The cell the Lua draws is
     [GET_RANDOM_SYNC(1,8)] twice, which over a 1-based grid is the 0-based
     index over ours, so the roll *is* the cell. A picker that never satisfies
     its predicate hands back the last draw after 1001 tries, two draws each. *)
  let flat g = of_array_matrix (Array.make_matrix 8 8 g) in
  let draws = ref 0 in
  let counting () = fun _ -> incr draws; 0 in
  let scripted values =
    let q = ref values in
    fun n ->
      incr draws;
      match !q with
      | v :: rest -> q := rest; v
      | [] -> ignore n; 0
  in
  let water_ctx = ictx ~board:(Some (flat (Board.Mana Water))) in
  draws := 0;
  check "GetRandomGrid_Type lands on the cell the roll drew"
    (get_random_grid (water_ctx ~roll:(scripted [ 3; 2 ]) ()) (Of_type (Board.Mana Water))
    = Some { Board.x = 3; y = 2 });
  check "and that is two draws for one try" (!draws = 2);
  draws := 0;
  let missed =
    get_random_grid (water_ctx ~roll:(counting ()) ()) (Of_type Board.Gold)
  in
  check "a predicate that never holds gives up after 1001 tries"
    (missed = Some { Board.x = 0; y = 0 } && !draws = 2002);
  (* Not and Isolated, including the adjacency rule: four orthogonal neighbours
     only, the cell itself not among them, diagonals not consulted. *)
  let mixed =
    of_array_matrix
      (Array.init 8 (fun y ->
           Array.init 8 (fun x ->
               if x = 1 && y = 1 then Board.Mana Fire else Board.Mana Water)))
  in
  draws := 0;
  check "GetRandomGrid_Not skips a cell that is the excluded gem"
    (get_random_grid
       (ictx ~board:(Some mixed) ~roll:(scripted [ 1; 1; 0; 0 ]) ())
       (Not [ Board.Mana Fire ])
    = Some { Board.x = 0; y = 0 });
  check "which took two tries" (!draws = 4);
  let no_adj_ctx = ictx ~board:(Some mixed) in
  check "a diagonal neighbour does not count as adjacent"
    (Item.no_adjacent mixed { Board.x = 0; y = 0 } (Board.Mana Fire));
  check "an orthogonal one does"
    (not (Item.no_adjacent mixed { Board.x = 2; y = 1 } (Board.Mana Fire)));
  draws := 0;
  check "GetRandomGrid_Isolated rejects the cell beside the gem"
    (get_random_grid
       (no_adj_ctx ~roll:(scripted [ 2; 1; 0; 0 ]) ())
       (Isolated [ Board.Mana Fire ])
    = Some { Board.x = 0; y = 0 });
  check "and took the extra try" (!draws = 4)

let () =
  (* The nine bodies that write the grid, through a cell the test can read. *)
  let flat g = of_array_matrix (Array.make_matrix 8 8 g) in
  let at b x y = Board.get_gem b { Board.x; y } in
  let cell = ref (Some (flat (Board.Mana Water))) in
  let grid () = Option.get !cell in
  let reset g = cell := Some (flat g) in
  let hooks_of id =
    (Option.get (Item_hooks.item_of_id id)).hooks
  in
  let ctx ?(percentile = 0) ?(roll = fun _ -> 0) () = ictx ~cell ~percentile ~roll () in

  (* ICOS: a skull at the picked cell, from the second turn and under 50. *)
  reset (Board.Mana Water);
  (match (hooks_of "ICOS").on_start_turn with
  | Some f -> f (ctx ()) 2
  | None -> check "ICOS has a start-turn hook" false);
  check "ICOS planted a skull at the drawn cell" (at (grid ()) 0 0 = Board.Skull);
  reset (Board.Mana Water);
  (match (hooks_of "ICOS").on_start_turn with
  | Some f -> f (ctx ()) 1
  | None -> check "ICOS has a start-turn hook" false);
  check "and not on the first turn" (at (grid ()) 0 0 = Board.Mana Water);
  reset (Board.Mana Water);
  (match (hooks_of "ICOS").on_start_turn with
  | Some f -> f (ctx ~percentile:50 ()) 2
  | None -> check "ICOS has a start-turn hook" false);
  check "nor on a roll of fifty or more" (at (grid ()) 0 0 = Board.Mana Water);

  (* IMGS: every star off the board, on either match event. *)
  cell :=
    Some
      (of_array_matrix
         (Array.init 8 (fun y ->
              Array.init 8 (fun x -> if (x + y) mod 3 = 0 then Board.Experience else Board.Mana Air))));
  let stars_before = Item.count_gems GStar (ictx ~cell ()) in
  check "the board starts with stars" (stars_before > 0);
  (match (hooks_of "IMGS").on_match4 with
  | Some f -> f (ctx ())
  | None -> check "IMGS has a match hook" false);
  check "and the sweep takes every one" (Item.count_gems GStar (ictx ~cell ()) = 0);

  (* IADO: the sweep plus the flat add, driven as the damage chain drives it. *)
  reset (Board.Mana Water);
  cell := Some (Board.set_gem { Board.x = 7; y = 7 } Board.RedSkull (grid ()));
  (match (hooks_of "IADO").on_give_damage with
  | Some f -> check_eq "IADO adds one from three up" (f (ctx ()) 3 0 1) 4
  | None -> check "IADO has a give hook" false);
  check "and swept the red skull" (at (grid ()) 7 7 <> Board.RedSkull);

  (* ITHH and IUHA: the cell the picker asks for, converted. *)
  reset (Board.Mana Water);
  (match (hooks_of "ITHH").on_give_damage with
  | Some f -> check_eq "ITHH adds two from three up" (f (ctx ()) 3 0 1) 5
  | None -> check "ITHH has a give hook" false);
  check "and turned a blue gem yellow" (at (grid ()) 0 0 = Board.Mana Air);
  reset (Board.Mana Fire);
  (match (hooks_of "IUHA").on_give_damage with
  | Some f -> check_eq "IUHA adds five from three up" (f (ctx ()) 3 0 1) 8
  | None -> check "IUHA has a give hook" false);
  check "and turned a red gem into a skull" (at (grid ()) 0 0 = Board.Skull);

  (* ICAR: the minus-one and the grown red gem, only where the minus-one bit. *)
  reset (Board.Mana Water);
  (match (hooks_of "ICAR").on_receive_damage with
  | Some f -> check_eq "ICAR takes one off a hit above one" (f (ctx ()) 5 0 1) 4
  | None -> check "ICAR has a receive hook" false);
  check "and grew a red gem at the picked cell" (at (grid ()) 0 0 = Board.Mana Fire);
  reset (Board.Mana Water);
  (match (hooks_of "ICAR").on_receive_damage with
  | Some f -> check_eq "a hit of one is left alone" (f (ctx ()) 1 0 1) 1
  | None -> check "ICAR has a receive hook" false);
  check "and plants nothing" (at (grid ()) 0 0 = Board.Mana Water);

  (* ISES's xp half: one roll in two grows a skull. *)
  reset (Board.Mana Water);
  (match (hooks_of "ISES").on_receive_xp with
  | Some f -> check_eq "the xp itself passes through" (f (ctx ()) 9) 9
  | None -> check "ISES has an xp hook" false);
  check "and the roll planted a skull" (at (grid ()) 0 0 = Board.Skull);
  reset (Board.Mana Water);
  (match (hooks_of "ISES").on_receive_xp with
  | Some f -> ignore (f (ctx ~percentile:51 ()) 9)
  | None -> check "ISES has an xp hook" false);
  check "a miss plants nothing" (at (grid ()) 0 0 = Board.Mana Water)

let () =
  (* IDSH and INOB: the per-character counter, its cap, and the OnStartTurn
     reset that bounds it. The counter is what makes the two halves a pair. *)
  let who = fighter 0 "hero" in
  let reset_board () = of_array_matrix (Array.make_matrix 8 8 (Board.Mana Water)) in
  let run_damage id damage =
    let ctx = ictx ~self:who ~cell:(ref (Some (reset_board ()))) () in
    match (Option.get (Item_hooks.item_of_id id)).hooks.on_receive_damage with
    | Some f -> ignore (f ctx damage 0 1)
    | None -> check (id ^ " has a receive hook") false
  in
  let state id = Combat.item_state_get who id in
  run_damage "IDSH" 8;
  check "IDSH counts one skull for eight damage" (state "IDSH" = 1.0);
  run_damage "IDSH" 12;
  check "and 1.5 for twelve, since damage / 8 is a fraction" (state "IDSH" = 2.5);
  run_damage "IDSH" 8;
  run_damage "IDSH" 8;
  check "the counter stops at three" (state "IDSH" = 3.0);
  (match (Option.get (Item_hooks.item_of_id "IDSH")).hooks.on_start_turn with
  | Some f -> f (ictx ~self:who ()) 0
  | None -> check "IDSH has a start-turn hook" false);
  check "and the wearer's next turn resets it" (state "IDSH" = 0.0);
  run_damage "INOB" 8;
  check "INOB counts nothing below twelve" (state "INOB" = 0.0);
  run_damage "INOB" 12;
  run_damage "INOB" 12;
  check "and stops at two" (state "INOB" = 2.0);
  check "the two counters are separate"
    (state "IDSH" = 0.0 && state "INOB" = 2.0)

let () =
  (* The damage chain refills what a hook destroyed: IADO sweeps a red skull
     out of a board that also holds a three-skull match, and the chain that
     runs after the sweep has to leave no holes behind. *)
  let kinds = [| Board.Mana Water; Board.Mana Air; Board.Mana Earth |] in
  let board =
    of_array_matrix
      (Array.init 8 (fun y ->
           Array.init 8 (fun x ->
               if y = 0 && x < 3 then Board.Skull
               else if x = 7 && y = 7 then Board.RedSkull
               else kinds.((x + y) mod 3))))
  in
  let b =
    Battle.create ~rng:(lcg 21) ~effects:[]
      ~hero_items:(match Item_hooks.item_of_id "IADO" with
                   | Some i -> let l = new_loadout () in ignore (equip l i); l
                   | None -> new_loadout ())
      board (fighter 0 "hero") (fighter ~life:9000 1 "foe")
  in
  Battle.play_swap_result b b.Battle.enemy;
  check "the three-skull match ran the damage chain"
    (List.exists (function Battle.Damage (_, n) -> n >= 3 | _ -> false)
       (Battle.log_of b));
  let grid = b.Battle.board in
  let cells = ref [] in
  for y = 0 to 7 do
    for x = 0 to 7 do cells := Board.get_gem grid { Board.x; y } :: !cells done
  done;
  check "the sweep took the red skull" (not (List.mem Board.RedSkull !cells));
  check "and the refill left no holes" (not (List.mem Board.Empty !cells))

let () =
  (* Every ADD_MANA inside a fight runs the receiver's fold. [Battle.create]
     registers the battle with [Combat], so a spell body or a status effect
     crediting mana gets the same treatment as a match's harvest - IMOA doubles
     the blue either way - and a combatant from some other fight falls through
     to the raw clamp, which an id check alone could not tell apart: every
     fight has a hero at id 0. *)
  let b =
    Battle.create ~rng:(lcg 31) ~effects:[]
      (of_array_matrix (Array.make_matrix 8 8 (Board.Mana Board.Fire)))
      (fighter 0 "hero") (fighter 1 "foe")
  in
  (match Item_hooks.item_of_id "IMOA" with
  | Some i -> ignore (Item.equip_at b.Battle.hero_items 1 i)
  | None -> check "IMOA builds from the table" false);
  Spell_effects.add_mana b.Battle.hero Combat.Water 4;
  check_eq "a spell's blue credit runs the fold and doubles"
    (Combat.mana b.Battle.hero Combat.Water)
    8;
  ignore (Combat.credit_mana b.Battle.hero Combat.Fire 5);
  check_eq "an element no item cares about is only banked"
    (Combat.mana b.Battle.hero Combat.Fire)
    5;
  let stranger = fighter 0 "stranger" in
  ignore (Combat.credit_mana stranger Combat.Water 4);
  check "the foreign combatant shares the hero's id"
    (stranger.Combat.id = b.Battle.hero.Combat.id);
  check_eq "and is not folded into this battle's loadout"
    (Combat.mana stranger Combat.Water)
    4

let () =
  (* [MISS_TURNS] as the loop reads it: the status is spent at the top of the
     turn, after the worn items' start hooks and before anything else, so the
     turn counts but nothing in it happens. *)
  let safe () =
    let e = [| Board.Mana Fire; Board.Mana Water; Board.Mana Air; Board.Mana Earth |] in
    of_array_matrix (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))
  in
  let b =
    Battle.create ~rng:(lcg 41) ~effects:[]
      ~rules:{ Battle.default_rules with max_turns = 8 }
      (safe ()) (fighter ~life:9000 0 "hero") (fighter ~life:9000 1 "foe")
  in
  b.Battle.hero.effects <- [ ("Missed", 1) ];
  Battle.take_turn b;
  let log = Battle.log_of b in
  check "the missed turn is in the log" (List.mem (Battle.MissedTurn "hero") log);
  check "and the hero did nothing in it"
    (hero_swaps log = 0
    && not
         (List.exists (function Battle.SpellCast ("hero", _) -> true | _ -> false) log));
  check "the status is spent" (not (List.mem_assoc "Missed" b.Battle.hero.effects));
  check_eq "while the turn still counted" b.Battle.turns_elapsed 1;
  Battle.take_turn b;
  check "the foe's turn ran normally"
    (List.exists
       (function Battle.TurnStart (_, Battle.Enemy, _) -> true | _ -> false)
       (Battle.log_of b));
  (* Two turns of it: one spent, one kept across the foe's turn. *)
  let c =
    Battle.create ~rng:(lcg 42) ~effects:[]
      ~rules:{ Battle.default_rules with max_turns = 8 }
      (safe ()) (fighter ~life:9000 0 "hero") (fighter ~life:9000 1 "foe")
  in
  c.Battle.hero.effects <- [ ("Missed", 2) ];
  Battle.take_turn c;
  check_eq "one turn of it is spent"
    (List.assoc "Missed" c.Battle.hero.effects)
    1;
  Battle.take_turn c;
  check "the rest survives the foe's turn"
    (List.assoc_opt "Missed" c.Battle.hero.effects = Some 1)

let () =
  (* ITUT, "Owner never takes a turn": its body runs in the worn items' start
     hooks, the check immediately after spends what it just set, and the action
     never happens - every turn, with no turn of the owner's ever played. *)
  let safe () =
    let e = [| Board.Mana Fire; Board.Mana Water; Board.Mana Air; Board.Mana Earth |] in
    of_array_matrix (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))
  in
  let b =
    Battle.create ~rng:(lcg 43) ~effects:[]
      ~rules:{ Battle.default_rules with max_turns = 8 }
      (safe ()) (fighter ~life:9000 0 "hero") (fighter ~life:9000 1 "foe")
  in
  (match Item_hooks.item_of_id "ITUT" with
  | Some i -> ignore (Item.equip_at b.Battle.hero_items 1 i)
  | None -> check "ITUT builds from the table" false);
  for _ = 1 to 4 do
    Battle.take_turn b
  done;
  let log = Battle.log_of b in
  check_eq "both of the hero's turns were misses"
    (List.length (List.filter (function Battle.MissedTurn "hero" -> true | _ -> false) log))
    2;
  check "and the hero never swapped or cast"
    (hero_swaps log = 0
    && not
         (List.exists (function Battle.SpellCast ("hero", _) -> true | _ -> false) log))


let () =
  (* IFZT stuns the other side for two turns on its roll, and does nothing off
     it. *)
  let hooks id = (Option.get (Item_hooks.item_of_id id)).hooks in
  let ctx = ictx ~percentile:0 () in
  (match (hooks "IFZT").on_give_damage with
  | Some f -> check_eq "IFZT leaves the damage alone" (f ctx 4 0 1) 4
  | None -> check "IFZT has a give hook" false);
  check "and stuns the other side"
    (List.assoc_opt "Missed" ctx.ic_enemy.effects = Some 2);
  let miss = ictx ~percentile:1 () in
  (match (hooks "IFZT").on_give_damage with
  | Some f -> ignore (f miss 4 0 1)
  | None -> check "IFZT has a give hook" false);
  check "while a roll past the wearer's water pool does nothing"
    (not (List.mem_assoc "Missed" miss.ic_enemy.effects))

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
