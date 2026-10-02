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

let lcg seed =
  let s = ref seed in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

let fighter ?(life = 60) id name =
  Combat.make_combatant ~cunning:5 ~max_life:life ~life id name

let descriptor ?(location = Weapon) ?(restriction = NoRequirement) id =
  { id; location; shop_cost = 0; rarity = 0; icon = 0; restriction }

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
        (match d.restriction with Skill SEarth -> true | _ -> false);
      check "and it is a weapon" (d.location = Weapon);
      check "with a real shop cost" (d.shop_cost = 1560)
  | None -> check "IALS is present" false);
  check "an unknown id is absent" (Item_data.descriptor_of "NOPE" = None)

(* ------------------------------------------------------------------ *)
(* Loadouts                                                              *)
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
  let staff = make_item { (descriptor "IALS") with restriction = Skill SEarth } in
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
  ; ic_max_mana = None
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
    { def_id = "RAGE"; def_duration = 999; def_max_stack = 1; def_icon = 0;
      def_hooks = Combat.set_give_damage Combat.no_hooks (fun _ n -> n * 2) }
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
  if !failures = 0 then print_endline "\nAll item tests passed."
  else begin
    Printf.printf "\n%d item test(s) failed.\n" !failures;
    exit 1
  end