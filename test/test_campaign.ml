(* The campaign engine: prerequisites, the quest lifecycle, map visibility, and
   the save round-trip.

   These are the parts of the campaign that were proved only by watching the demo
   print lines. A demo that prints "revealed at accept: WSIR visible=true" shows
   the happy path once; it does not show that a prerequisite *blocks* an offer,
   that a lost battle leaves the quest at state 1, or that loading a save puts a
   hidden road back behind a hidden endpoint.

   The map tables are global mutable state, so the whole file snapshots them
   first and restores at the end; between the snapshot and the restore every
   test either works on a fresh player record or sets the node flags it is about
   to assert on, rather than assuming what the shipped data says. *)

open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

(* ------------------------------------------------------------------ *)
(* Snapshot / restore of the mutable map tables                       *)
(* ------------------------------------------------------------------ *)

type snap = {
  nodes : (string * bool) list;
  roads : (string * string * bool) list;
}

let take_snapshot () = {
  nodes =
    List.map (fun (c : Campaign_map.city) ->
        (c.Campaign_map.id, Campaign.node_visible c.Campaign_map.id)) Campaign_map.cities
    @ List.map (fun (w : Campaign_map.waypoint) ->
        (w.Campaign_map.id, Campaign.node_visible w.Campaign_map.id)) Campaign_map.waypoints
    @ List.map (fun (r : Campaign_map.ruin) ->
        (r.Campaign_map.id, Campaign.node_visible r.Campaign_map.id)) Campaign_map.ruins;
  roads =
    List.map (fun (r : Campaign_map.road) ->
        (r.Campaign_map.start, r.Campaign_map.end_,
         Campaign.get_road_visible r.Campaign_map.start r.Campaign_map.end_))
      Campaign_map.roads;
}

let restore (s : snap) =
  List.iter (fun (id, vis) -> Campaign.set_node_visible id vis) s.nodes;
  List.iter (fun (a, b, vis) -> Campaign.set_road_visible a b vis) s.roads

let initial = take_snapshot ()

let quest id : Campaign_quests.quest = Campaign_quests.quest_by_id id

let fresh () = Campaign.create_player "Tester" "PWAR" 0 0

let state_of (p : Campaign.player) qid = List.assoc_opt qid p.Campaign.active_quests

(* ------------------------------------------------------------------ *)
(* 1. Prerequisites                                                   *)
(* ------------------------------------------------------------------ *)

let base = quest "Q0T0"   (* CBAR, level 1-1000, no conditions of its own *)

let () =
  let p = fresh () in

  check "a clean quest at the right level is offered"
    (Campaign.is_quest_available p base);
  check "below the level floor is not offered"
    (not (Campaign.is_quest_available { p with Campaign.level = 0 } base));
  check "above the level ceiling is not offered"
    (not (Campaign.is_quest_available p { base with Campaign_quests.avail_maxlevel = 0 }));
  check "an already-active quest is not offered twice"
    (not (Campaign.is_quest_available
            { p with Campaign.active_quests = [ ("Q0T0", 1) ] } base));

  (* donequest0/1/2: three slots, one rule. *)
  let gated0 = { base with Campaign_quests.avail_donequest0 = "Q0Z9" } in
  check "donequest0 blocks until the quest is done"
    (not (Campaign.is_quest_available p gated0));
  check "donequest0 opens once the quest is done"
    (Campaign.is_quest_available { p with Campaign.completed_quests = [ "Q0Z9" ] } gated0);
  let gated1 = { base with Campaign_quests.avail_donequest1 = "Q0Z9" } in
  check "donequest1 blocks until the quest is done"
    (not (Campaign.is_quest_available p gated1));
  check "donequest1 opens once the quest is done"
    (Campaign.is_quest_available { p with Campaign.completed_quests = [ "Q0Z9" ] } gated1);
  let gated2 = { base with Campaign_quests.avail_donequest2 = "Q0Z9" } in
  check "donequest2 blocks until the quest is done"
    (not (Campaign.is_quest_available p gated2));
  check "donequest2 opens once the quest is done"
    (Campaign.is_quest_available { p with Campaign.completed_quests = [ "Q0Z9" ] } gated2);

  let notdone = { base with Campaign_quests.avail_notdonequest = "Q0Z9" } in
  check "notdonequest offers the quest while it is undone"
    (Campaign.is_quest_available p notdone);
  check "notdonequest blocks once it is done"
    (not (Campaign.is_quest_available
            { p with Campaign.completed_quests = [ "Q0Z9" ] } notdone));

  let notactive = { base with Campaign_quests.avail_notactivequest = "Q0Z9" } in
  check "notactivequest offers the quest while nothing else is on it"
    (Campaign.is_quest_available p notactive);
  check "notactivequest blocks while the other quest is active"
    (not (Campaign.is_quest_available
            { p with Campaign.active_quests = [ ("Q0Z9", 1) ] } notactive));

  let with_comp = { base with Campaign_quests.avail_companion0 = "NFAKE" } in
  check "companion0 needs the companion in the party"
    (not (Campaign.is_quest_available p with_comp));
  check "companion0 opens with the companion in the party"
    (Campaign.is_quest_available { p with Campaign.companions = [ "NFAKE" ] } with_comp);

  let with_comp1 = { base with Campaign_quests.avail_companion1 = "NFAKE" } in
  check "companion1 needs the companion in the party"
    (not (Campaign.is_quest_available p with_comp1));

  let no_comp = { base with Campaign_quests.avail_notcompanion = "NFAKE" } in
  check "notcompanion offers the quest without the companion"
    (Campaign.is_quest_available p no_comp);
  check "notcompanion blocks with the companion in the party"
    (not (Campaign.is_quest_available { p with Campaign.companions = [ "NFAKE" ] } no_comp));

  let need_item = { base with Campaign_quests.avail_item = "IBSH" } in
  check "item needs it in the inventory"
    (not (Campaign.is_quest_available p need_item));
  check "item opens with it in the inventory"
    (Campaign.is_quest_available
       { p with Campaign.inventory = [ Campaign_items.item_by_id "IBSH" ] } need_item);

  let no_item = { base with Campaign_quests.avail_notitem = "IBSH" } in
  check "notitem offers the quest without the item"
    (Campaign.is_quest_available p no_item);
  check "notitem blocks with the item held"
    (not (Campaign.is_quest_available
            { p with Campaign.inventory = [ Campaign_items.item_by_id "IBSH" ] } no_item));

  let need_award = { base with Campaign_quests.avail_award = "AFAKE" } in
  check "award needs the award"
    (not (Campaign.is_quest_available p need_award));
  check "award opens with the award"
    (Campaign.is_quest_available { p with Campaign.awards = [ "AFAKE" ] } need_award);

  let no_award = { base with Campaign_quests.avail_notaward = "AFAKE" } in
  check "notaward offers the quest without the award"
    (Campaign.is_quest_available p no_award);
  check "notaward blocks with the award held"
    (not (Campaign.is_quest_available { p with Campaign.awards = [ "AFAKE" ] } no_award));

  (* The same rules against the shipped data, not a record built for them.
     Q0I1 needs Q0Q0 done and level 3; Q0T1 needs Q0T0 done, Q0Q0 undone. *)
  let q0i1 = quest "Q0I1" and q0t1 = quest "Q0T1" in
  check "Q0I1 is closed until Q0Q0 is done"
    (not (Campaign.is_quest_available { p with Campaign.level = 3 } q0i1));
  check "Q0I1 opens at level 3 with Q0Q0 done"
    (Campaign.is_quest_available
       { p with Campaign.level = 3; Campaign.completed_quests = [ "Q0Q0" ] } q0i1);
  check "Q0I1 is level-gated even with Q0Q0 done"
    (not (Campaign.is_quest_available { p with Campaign.completed_quests = [ "Q0Q0" ] } q0i1));
  check "Q0T1 opens once Q0T0 is done"
    (Campaign.is_quest_available { p with Campaign.completed_quests = [ "Q0T0" ] } q0t1);
  check "Q0T1 stays shut while Q0Q0 is done"
    (not (Campaign.is_quest_available
            { p with Campaign.completed_quests = [ "Q0T0"; "Q0Q0" ] } q0t1));

  (* Location is a separate filter from the prerequisite check. *)
  let at_cbar = Campaign.available_quests_at p "CBAR" in
  check "the start city offers Q0T0"
    (List.exists (fun (q : Campaign_quests.quest) -> q.Campaign_quests.id = "Q0T0") at_cbar);
  check "another city does not offer it"
    (not (List.exists (fun (q : Campaign_quests.quest) -> q.Campaign_quests.id = "Q0T0")
             (Campaign.available_quests_at p "CDKO")));

  check "accepting an unavailable quest changes nothing"
    ((Campaign.quest_accept { p with Campaign.level = 1 } "Q0I1").Campaign.active_quests
     = p.Campaign.active_quests)

(* ------------------------------------------------------------------ *)
(* 2. Quest lifecycle: accept -> battle -> turn in                    *)
(* ------------------------------------------------------------------ *)

let () =
  let p = fresh () in
  let q0t0 = quest "Q0T0" in
  (* Hide what OnBegin is about to reveal, so the reveal has something to do. *)
  List.iter (fun id -> Campaign.set_location_visible id false) q0t0.Campaign_quests.reveal_on_begin;

  let p1 = Campaign.quest_accept p "Q0T0" in
  check "accept puts the quest at state 1"
    (state_of p1 "Q0T0" = Some 1);
  check "accept reveals every node the script asks for"
    (List.for_all Campaign.node_visible q0t0.Campaign_quests.reveal_on_begin);
  let p1b = Campaign.quest_accept p1 "Q0T0" in
  check "accepting twice does not duplicate the entry"
    (state_of p1b "Q0T0" = Some 1
     && List.length (List.filter (fun (id, _) -> id = "Q0T0")
                       p1b.Campaign.active_quests) = 1);

  let p2 = Campaign.quest_battle_complete p1 "Q0T0" false in
  check "a lost battle leaves the quest at state 1"
    (state_of p2 "Q0T0" = Some 1);
  let p3 = Campaign.quest_battle_complete p1 "Q0T0" true in
  check "a won battle moves it to state 2"
    (state_of p3 "Q0T0" = Some 2);
  check "a battle on a quest that is not active does nothing"
    (Campaign.quest_battle_complete (fresh ()) "Q0T0" true = (fresh ()));

  let gold_before = p3.Campaign.gold and xp_before = p3.Campaign.xp in
  let p4 = Campaign.quest_turn_in p3 "Q0T0" in
  check "turn-in moves the quest out of the active list"
    (state_of p4 "Q0T0" = None);
  check "turn-in records the completion"
    (List.mem "Q0T0" p4.Campaign.completed_quests);
  check_int "turn-in pays the gold the script grants"
    p4.Campaign.gold (gold_before + q0t0.Campaign_quests.reward_gold);
  check_int "turn-in pays the xp the script grants"
    p4.Campaign.xp (xp_before + q0t0.Campaign_quests.reward_xp);
  check "turn-in grants the item"
    (List.exists (fun (i : Campaign_items.item) -> i.Campaign_items.id = "IBSH")
       p4.Campaign.inventory);
  check "a second turn-in pays nothing"
    (let p5 = Campaign.quest_turn_in p4 "Q0T0" in
     p5.Campaign.xp = p4.Campaign.xp && state_of p5 "Q0T0" = None);

  (* Rewards that only OnEnd carries: gold, an item, an award (Q1G3) and a
     companion (Q0Q4). Driven through run_quest_on_end + apply_quest_effect,
     which is what quest_turn_in does, so a grant landing in the wrong bucket
     fails here rather than at play time. *)
  let effects_of qid =
    let q = quest qid in
    let qi = { Campaign.quest = q; Campaign.state = Campaign.Active 2; Campaign.vars = [] } in
    let _qi, effects = Campaign.run_quest_on_end qi in
    (q, effects)
  in
  let apply player effects = List.fold_left Campaign.apply_quest_effect player effects in

  let q1g3, e1 = effects_of "Q1G3" in
  let before1 = fresh () in
  let r1 = apply before1 e1 in
  check_int "Q1G3 gold lands in the purse"
    r1.Campaign.gold (before1.Campaign.gold + q1g3.Campaign_quests.reward_gold);
  check_int "Q1G3 xp lands in the ledger"
    r1.Campaign.xp (before1.Campaign.xp + q1g3.Campaign_quests.reward_xp);
  check "Q1G3 grants its item"
    (List.exists (fun (i : Campaign_items.item) -> i.Campaign_items.id = "ISTA")
       r1.Campaign.inventory);
  check "Q1G3 grants its award"
    (List.mem "AMME" r1.Campaign.awards);

  let q0q4, e2 = effects_of "Q0Q4" in
  let r2 = apply (fresh ()) e2 in
  check "Q0Q4 grants a companion the script asked for"
    (List.exists (fun c -> List.mem c r2.Campaign.companions)
       q0q4.Campaign_quests.reward_companions);
  check "Q0Q4 completes the quest"
    (List.mem "Q0Q4" r2.Campaign.completed_quests);

  (* An end-of-quest reveal: Q0Q7 opens CDKO when it ends. *)
  let q0q7 = quest "Q0Q7" in
  if List.mem "CDKO" q0q7.Campaign_quests.reveal_on_end then begin
    Campaign.set_location_visible "CDKO" false;
    ignore (apply (fresh ()) (snd (effects_of "Q0Q7")));
    check "OnEnd reveals the nodes the script asks for"
      (Campaign.node_visible "CDKO")
  end

(* ------------------------------------------------------------------ *)
(* 3. Map visibility: the both-endpoints road rule                    *)
(* ------------------------------------------------------------------ *)

let () =
  (* The rule under test (Engine_QUEST_SET_VISIBILITY_450e40.c): a road is
     visible only when both endpoints are, and hiding is unconditional. Set the
     endpoints explicitly rather than trusting the shipped flags. *)
  let road () = Campaign.get_road_visible "CBAR" "WTHR" in

  Campaign.set_location_visible "CBAR" true;
  Campaign.set_location_visible "WTHR" true;
  check "both endpoints visible: the road is"
    (Campaign.node_visible "CBAR" && Campaign.node_visible "WTHR" && road ());

  Campaign.set_location_visible "WTHR" false;
  check "hiding one endpoint hides the road"
    (not (road ()));
  check "the other endpoint is untouched"
    (Campaign.node_visible "CBAR");
  check "the hidden node reads as hidden"
    (not (Campaign.node_visible "WTHR"));
  check "the road flag agrees in the reverse direction"
    (Campaign.get_road_visible "WTHR" "CBAR" = road ());

  Campaign.set_location_visible "WTHR" true;
  check "showing it again brings the road back"
    (road ());

  Campaign.set_location_visible "CBAR" false;
  Campaign.set_location_visible "WSIR" false;
  Campaign.set_location_visible "CBAR" true;
  check "one of two hidden endpoints is not enough"
    (not (Campaign.get_road_visible "CBAR" "WSIR"));
  Campaign.set_location_visible "WSIR" true;
  check "the second endpoint makes it enough"
    (Campaign.get_road_visible "CBAR" "WSIR");

  Campaign.set_location_visible "WTHR" false;
  check "roads_from_node leaves a hidden road out"
    (not (List.exists (fun (r : Campaign_map.road) ->
             (r.Campaign_map.start = "CBAR" && r.Campaign_map.end_ = "WTHR")
             || (r.Campaign_map.start = "WTHR" && r.Campaign_map.end_ = "CBAR"))
             (Campaign.roads_from_node "CBAR")));
  Campaign.set_location_visible "WTHR" true;

  check "an unknown node is inert, not an exception"
    (begin Campaign.set_location_visible "ZZZZ" true;
           not (Campaign.node_visible "ZZZZ") end)

(* ------------------------------------------------------------------ *)
(* 4. Save / load round-trip                                          *)
(* ------------------------------------------------------------------ *)

let () =
  let path = Filename.temp_file "pq_campaign_test" ".json" in

  (* A player carrying every field the save has to survive. *)
  let p =
    { (fresh ()) with
      Campaign.gold = 777; Campaign.xp = 1234; Campaign.level = 3;
      Campaign.inventory = [ Campaign_items.item_by_id "IBSH" ];
      Campaign.known_spells = [ "SCHG" ];
      Campaign.active_quests = [ ("Q0T0", 2) ];
      Campaign.completed_quests = [ "Q0T1" ];
      Campaign.companions = [ "NDKH" ];
      Campaign.awards = [ "AMME" ];
      Campaign.current_city = Some "CBAR" } in

  (* Visibility as it is *now*, not as the data shipped: one node hidden. *)
  Campaign.set_location_visible "WSIR" false;
  Campaign.set_location_visible "WTHR" true;

  let save = Campaign_save.create_save_data p p.Campaign.active_quests "CBAR" 0 in
  Campaign_save.save_to_file path save;

  (* Diverge from what was saved, so a load that ignores the file cannot pass. *)
  Campaign.set_location_visible "WSIR" true;
  check "before load the divergence is visible"
    (Campaign.node_visible "WSIR");

  let loaded = Campaign_save.load_from_file path in
  let p2, quests, completed, awards, location, _travel =
    Campaign_save.apply_save loaded in
  Sys.remove path;

  check_int "load restores gold" p2.Campaign.gold 777;
  check_int "load restores xp" p2.Campaign.xp 1234;
  check_int "load restores level" p2.Campaign.level 3;
  check "load restores the inventory"
    (List.exists (fun (i : Campaign_items.item) -> i.Campaign_items.id = "IBSH")
       p2.Campaign.inventory);
  check "load restores known spells"
    (p2.Campaign.known_spells = [ "SCHG" ]);
  check "load restores active quest state"
    (List.assoc_opt "Q0T0" quests = Some 2);
  check "load restores completions"
    (List.mem "Q0T1" completed);
  check "load restores awards"
    (List.mem "AMME" awards);
  check "load restores the location"
    (location = "CBAR" && p2.Campaign.current_city = Some "CBAR");

  check "load puts a hidden node back behind the save"
    (not (Campaign.node_visible "WSIR"));
  check "load keeps a visible node visible"
    (Campaign.node_visible "WTHR");
  check "the road follows the restored endpoint"
    (Campaign.get_road_visible "CBAR" "WTHR"
     = (Campaign.node_visible "CBAR" && Campaign.node_visible "WTHR"));

  (* Back to where the file started. *)
  restore initial;
  check "the snapshot restores the shipped visibility"
    (take_snapshot () = initial)

let () =
  if !failures > 0 then begin
    Printf.printf "\n%d failure(s)\n" !failures;
    exit 1
  end;
  print_endline "all campaign tests passed"
