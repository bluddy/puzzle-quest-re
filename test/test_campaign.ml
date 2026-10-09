(* The campaign engine: prerequisites, the quest lifecycle, map visibility, the
   ruin registry, and the save round-trip.

   These are the parts of the campaign that were proved only by watching the demo
   print lines. A demo that prints "revealed at accept: WSIR visible=true" shows
   the happy path once; it does not show that a prerequisite *blocks* an offer,
   that a lost battle leaves the quest at state 1, that a ruin shared by two
   quests outlives the first release, or that loading a save puts a hidden road
   back behind a hidden endpoint.

   The map tables and the ruin registry are global mutable state, so the whole
   file snapshots them first and restores at the end; between the snapshot and
   the restore every test either works on a fresh player record or sets the state
   it is about to assert on, rather than assuming what the shipped data says. *)

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

(* ------------------------------------------------------------------ *)
(* 5. Ruin registration: refcounts, releases, and the save round-trip  *)
(* ------------------------------------------------------------------ *)

let () =
  (* The registry is global mutable state, like the map tables above. The
     sections before this one only touch Q0T0, which holds no ruins, so the
     table starts empty - and the assertions below prove that too. *)
  let counts0 = Campaign.ruin_counts_snapshot () in
  let done0 = Campaign.ruin_done_snapshot () in
  Campaign.restore_ruin_state [] [];

  (* -- the registry itself: Engine_QUEST_ADD_RUIN / Engine_QUEST_SET_RUIN_DONE *)

  Campaign.set_location_visible "REGB" false;
  Campaign.register_ruin "REGB";
  check "registering a ruin reveals its node"
    (Campaign.node_visible "REGB");
  check_int "the first hold counts 1" (Campaign.ruin_count "REGB") 1;
  check "a registered ruin is not done"
    (not (Campaign.ruin_is_done "REGB"));

  Campaign.register_ruin "REGB";
  check_int "a second quest on the same ruin counts 2"
    (Campaign.ruin_count "REGB") 2;
  Campaign.set_ruin_done "REGB";
  check_int "one release leaves the other hold" (Campaign.ruin_count "REGB") 1;
  check "still not done while a hold remains"
    (not (Campaign.ruin_is_done "REGB"));
  Campaign.set_ruin_done "REGB";
  check_int "the last release empties the count" (Campaign.ruin_count "REGB") 0;
  check "the last release marks the ruin done"
    (Campaign.ruin_is_done "REGB");

  Campaign.set_ruin_done "REGB";
  check "releasing an empty ruin is a no-op"
    (Campaign.ruin_count "REGB" = 0 && Campaign.ruin_is_done "REGB");
  Campaign.set_ruin_done "ZZZZ";
  check "releasing a ruin nobody registered is inert"
    (not (Campaign.ruin_is_done "ZZZZ"));
  Campaign.register_ruin "REGB";
  check "re-registering clears the done flag (ADD_RUIN purges the notification)"
    (Campaign.ruin_count "REGB" = 1 && not (Campaign.ruin_is_done "REGB"));
  Campaign.restore_ruin_state [] [];

  (* -- through the quest lifecycle *)

  (* Q0I0 (Troll Trouble, REGB): registers on accept, releases OnCompleteAction
     (battle won) and OnAbandon. Needs level 7 and Q0Q4 done. *)
  let q0i0 () =
    { (fresh ()) with Campaign.level = 7; Campaign.completed_quests = [ "Q0Q4" ] } in
  Campaign.set_location_visible "REGB" false;
  let p1 = Campaign.quest_accept (q0i0 ()) "Q0I0" in
  check "accepting a ruin quest registers its ruin"
    (state_of p1 "Q0I0" = Some 1 && Campaign.ruin_count "REGB" = 1);
  check "and reveals the ruin node"
    (Campaign.node_visible "REGB");

  let lost = Campaign.quest_battle_complete p1 "Q0I0" false in
  check "a lost quest battle keeps the hold"
    (state_of lost "Q0I0" = Some 1 && Campaign.ruin_count "REGB" = 1
     && not (Campaign.ruin_is_done "REGB"));

  let won = Campaign.quest_battle_complete p1 "Q0I0" true in
  check "the won quest battle releases the ruin (OnCompleteAction)"
    (Campaign.ruin_count "REGB" = 0 && Campaign.ruin_is_done "REGB");
  check "the state still advanced" (state_of won "Q0I0" = Some 2);

  (* Abandon is the other release path - Q0I0 is flagged abandonable. *)
  Campaign.restore_ruin_state [] [];
  let p2 = Campaign.quest_accept (q0i0 ()) "Q0I0" in
  let p3 = Campaign.quest_abandon p2 "Q0I0" in
  check "abandoning releases the ruin (OnAbandon)"
    (Campaign.ruin_count "REGB" = 0 && Campaign.ruin_is_done "REGB");
  check "and drops the quest from the active list"
    (state_of p3 "Q0I0" = None);
  let again = Campaign.quest_accept p3 "Q0I0" in
  check "an abandoned quest can be taken again, hold restored"
    (state_of again "Q0I0" = Some 1 && Campaign.ruin_count "REGB" = 1);

  (* The abandonable flag withholds OnAbandon: Q0T0 is not abandonable. *)
  let p4 = Campaign.quest_accept (fresh ()) "Q0T0" in
  let p5 = Campaign.quest_abandon p4 "Q0T0" in
  check "a quest flagged not-abandonable stays active"
    (state_of p5 "Q0T0" = Some 1);
  check "abandoning a quest that is not active does nothing"
    (Campaign.quest_abandon (fresh ()) "Q0I0" = fresh ());

  (* Q1S0 registers ROTO and releases only OnEnd, so turn-in is what empties
     it. Needs level 12, Q0Q8 done and companion NKHA. *)
  Campaign.restore_ruin_state [] [];
  let q1s0 () =
    { (fresh ()) with Campaign.level = 12; Campaign.completed_quests = [ "Q0Q8" ];
      Campaign.companions = [ "NKHA" ] } in
  let s1 = Campaign.quest_accept (q1s0 ()) "Q1S0" in
  check "Q1S0 registers ROTO on accept"
    (state_of s1 "Q1S0" = Some 1 && Campaign.ruin_count "ROTO" = 1);
  let s2 = Campaign.quest_turn_in s1 "Q1S0" in
  check "turn-in releases the ruin (OnEnd)"
    (Campaign.ruin_count "ROTO" = 0 && Campaign.ruin_is_done "ROTO"
     && state_of s2 "Q1S0" = None);

  (* A shared ruin: Q0S1 and Q0S3 both hold ROTO and each releases it
     OnCompleteAction - the site has to outlive the first release. *)
  Campaign.restore_ruin_state [] [];
  let spoil () =
    { (fresh ()) with Campaign.level = 11; Campaign.completed_quests = [ "Q0Q0" ] } in
  let a1 = Campaign.quest_accept (spoil ()) "Q0S1" in
  let a2 = Campaign.quest_accept a1 "Q0S3" in
  check "two quests hold the same ruin"
    (Campaign.ruin_count "ROTO" = 2);
  let a3 = Campaign.quest_battle_complete a2 "Q0S1" true in
  check "the first quest's release leaves the second hold"
    (Campaign.ruin_count "ROTO" = 1 && not (Campaign.ruin_is_done "ROTO")
     && state_of a3 "Q0S1" = Some 2);
  let a4 = Campaign.quest_battle_complete a3 "Q0S3" true in
  check "the second quest's release empties the ruin"
    (Campaign.ruin_count "ROTO" = 0 && Campaign.ruin_is_done "ROTO"
     && state_of a4 "Q0S3" = Some 2);

  (* Q0I5 (Imperial Reply, RDPS) releases OnCompleteAction *and* in a
     didShrine-guarded OnEnd; the guard is not evaluated, so turn-in releases a
     second time and the engine's absent-id no-op absorbs it. *)
  Campaign.restore_ruin_state [] [];
  let q0i5 () =
    { (fresh ()) with Campaign.level = 8; Campaign.completed_quests = [ "Q0I4" ] } in
  let i1 = Campaign.quest_accept (q0i5 ()) "Q0I5" in
  let i2 = Campaign.quest_battle_complete i1 "Q0I5" true in
  check "Q0I5 releases on the battle"
    (Campaign.ruin_count "RDPS" = 0 && Campaign.ruin_is_done "RDPS");
  let i3 = Campaign.quest_turn_in i2 "Q0I5" in
  check "the guarded OnEnd release is an inert repeat"
    (Campaign.ruin_count "RDPS" = 0 && Campaign.ruin_is_done "RDPS"
     && state_of i3 "Q0I5" = None);

  (* -- the registry travels with the save *)
  let path = Filename.temp_file "pq_ruin_test" ".json" in
  Campaign.restore_ruin_state [] [];
  let sp = Campaign.quest_accept (q0i0 ()) "Q0I0" in
  let sp = Campaign.quest_battle_complete sp "Q0I0" true in
  Campaign.register_ruin "RSTR";
  let save = Campaign_save.create_save_data sp sp.Campaign.active_quests "CGAL" 0 in
  Campaign_save.save_to_file path save;

  (* Diverge from what was saved, so a load that ignores the file cannot pass. *)
  ignore (Campaign.register_ruin "RSTR");
  ignore (Campaign.register_ruin "RDPS");
  let loaded = Campaign_save.load_from_file path in
  ignore (Campaign_save.apply_save loaded);
  Sys.remove path;

  check_int "load restores a released ruin's count"
    (Campaign.ruin_count "REGB") 0;
  check "load restores the done flag"
    (Campaign.ruin_is_done "REGB");
  check_int "load restores a live hold" (Campaign.ruin_count "RSTR") 1;
  check "load drops the diverged hold"
    (Campaign.ruin_count "RDPS" = 0 && not (Campaign.ruin_is_done "RDPS"));

  (* Back to where the file started. *)
  Campaign.restore_ruin_state counts0 done0;
  restore initial;
  check "the registry snapshot restores what the sections before found"
    (Campaign.ruin_counts_snapshot () = counts0
     && Campaign.ruin_done_snapshot () = done0);
  check "the map is left as it was found"
    (take_snapshot () = initial)

let () =
  (* QUEST_REMOVE_COMPANION: a companion leaves the party when the hero
     arrives at a quest stage's location - Q3S0's five sword points and
     QS00's at CENM are the six rules the scanner attributes to
     OnEnterLocation; the two conversation-callback sites (Q3Q5, QU02) have
     no arrival event to run under and stay out of the table. *)
  let with_rules =
    List.filter (fun (q : Campaign_quests.quest) -> q.enter_removes <> [])
      Campaign_quests.quests
  in
  check "only Q3S0 and QS00 carry enter rules"
    (List.map (fun (q : Campaign_quests.quest) -> q.id) with_rules
     = [ "Q3S0"; "QS00" ]);
  let q3s0 = Campaign_quests.quest_by_id "Q3S0" in
  check "Q3S0 pairs each state with its location and companion"
    (q3s0.enter_removes =
     [ (2, "WLOB", "NSER"); (3, "CKUN", "NWIN"); (4, "WWAS", "NKHA");
       (5, "WHVA", "NFLI"); (6, "WBSP", "NELI") ]);
  check_int "QS00 has one rule"
    (List.length (Campaign_quests.quest_by_id "QS00").enter_removes) 1;
  check "Q3Q5's callback site stays out of the arrival table"
    ((Campaign_quests.quest_by_id "Q3Q5").enter_removes = []);

  let base = Campaign.create_player "Leaver" "PWAR" 0 1 in
  let active =
    { base with
      Campaign.companions = [ "NSER"; "NWIN" ];
      Campaign.active_quests = [ ("Q3S0", 2) ] }
  in
  let arrived where =
    (Campaign.enter_location active where).Campaign.companions
  in
  check "state 2 arriving at WLOB drops Serephine"
    (arrived "WLOB" = [ "NWIN" ]);
  check "the same arrival at CKUN drops nobody"
    (arrived "CKUN" = [ "NSER"; "NWIN" ]);
  check "an arrival with nobody selected changes nothing"
    ((Campaign.enter_location
        { active with Campaign.companions = [ "NWIN" ] } "WLOB")
     .Campaign.companions = [ "NWIN" ]);
  check "no active quest means no rule to run"
    ((Campaign.enter_location
        { active with Campaign.active_quests = [] } "WLOB")
     .Campaign.companions = [ "NSER"; "NWIN" ]);
  let s0 =
    { base with
      Campaign.companions = [ "NSER"; "NFLI" ];
      Campaign.active_quests = [ ("QS00", 1) ] }
  in
  check "QS00 drops Serephine at CENM"
    ((Campaign.enter_location s0 "CENM").Campaign.companions = [ "NFLI" ]);
  check "removing someone not in the party is a no-op"
    ((Campaign.apply_quest_effect active (Campaign.RemoveCompanion "NKHA"))
     .Campaign.companions = [ "NSER"; "NWIN" ])

let () =
  (* Campaign fights stop running on hand-set defaults: the recovered hero/task
     band decides difficulty (the gate on the AI's spell skip and the
     evaluator's jitter), the hero's real level feeds the evaluator, and a road
     monster walks in with its own registry spell roster - which it never did:
     the encounter path passed no enemy_spells at all, so no road monster had
     ever cast anything. *)
  let hero_level30 = { (fresh ()) with Campaign.level = 30 } in
  let band task =
    (Campaign.rules_for_battle ~player:hero_level30 ~task_level:task)
      .Battle.difficulty
  in
  check_int "task 1 against a level-30 hero is band 0" (band 1) 0;
  check_int "task 25 against a level-30 hero is band 1" (band 25) 1;
  check_int "task 30 against a level-30 hero is band 2" (band 30) 2;
  check_int "task 37 against a level-30 hero is band 3" (band 37) 3;
  check_int "task 40 against a level-30 hero is band 4" (band 40) 4;
  check_int "the hero's own level reaches the evaluator"
    (Campaign.rules_for_battle ~player:hero_level30 ~task_level:1)
      .Battle.hero_level
    30;

  let road =
    { Campaign_encounters.id = "EXXX";
      description = "test";
      start = "CGAL";
      end_ = "WRAR";
      index = 0;
      sprite = "ZGSP";
      lua_file = "";
      lua_object = "";
      my_level = 1;
      chance = 0 }
  in
  let b = Campaign.run_encounter_battle hero_level30 road in
  check_int "the road fight takes the encounter's own level as its task"
    b.Battle.rules.Battle.difficulty 0;
  check_int "and carries the hero's level for the evaluator"
    b.Battle.rules.Battle.hero_level 30;
  check "the road monster brings its registry spell roster"
    (List.exists (fun (s : Spell.spell) -> s.Spell.id = "SWMG")
       b.Battle.enemy_spells);
  check "the whole roster lands, not just its first spell"
    (List.length b.Battle.enemy_spells = 3)

(* ------------------------------------------------------------------ *)
(* 6. Travel, encounter appearance, income, level-up                  *)
(* ------------------------------------------------------------------ *)

let () =
  (* Travel: the map answers where and how far, and a road is an edge only     between nodes the graph knows. These are the primitives a front end moves
     along; there is no journey step in the engine yet (GAPS, World Map). *)
  let d = Campaign.node_distance "CBAR" "WTHR" in
  check "distance is positive between distinct nodes" (d > 0.);
  check "distance is symmetric"
    (abs_float (d -. Campaign.node_distance "WTHR" "CBAR") < 1e-9);
  check "a node is zero from itself"
    (Campaign.node_distance "CBAR" "CBAR" = 0.);
  check "the seed city reaches its waypoint"
    (List.exists (fun (r : Campaign_map.road) -> r.Campaign_map.end_ = "WTHR")
       (Campaign.roads_from_node "CBAR"));
  check "a node with no roads returns an empty list, not an exception"
    (Campaign.roads_from_node "ZZZZ" = []);

  (* The journey step: begin only on a revealed road, walk it against the
     nodes' distance, arrive at the far node - and the departure roll can
     stop the hero on a road that holds an active encounter. *)
  Campaign.set_location_visible "CBAR" true;
  Campaign.set_location_visible "WTHR" true;
  (match Campaign.begin_travel "CBAR" "WTHR" with
  | Some (Campaign.Traveling t) ->
      check "the journey is timed by the nodes' distance"
        (abs_float (t.total_time -. d) < 1e-9
         && t.progress = 0.0
         && t.to_ = "WTHR");
      check "one tick walks but does not arrive"
        (match Campaign.advance_travel (Campaign.Traveling t) (d /. 2.) with
         | Campaign.Traveling t2 ->
             t2.progress = d /. 2. && t2.to_ = "WTHR"
         | _ -> false);
      check "the arrival tick lands on the far node"
        (match Campaign.advance_travel (Campaign.Traveling t) d with
         | Campaign.AtNode "WTHR" -> true
         | _ -> false)
  | _ -> check "a revealed road opens a journey" false);
  Campaign.set_location_visible "WTHR" false;
  check "a journey on a hidden road cannot begin"
    (Campaign.begin_travel "CBAR" "WTHR" = None);
  Campaign.set_location_visible "WTHR" true;
  check "a journey into the void cannot begin"
    (Campaign.begin_travel "CBAR" "ZZZZ" = None);
  check "and a step outside traveling changes nothing"
    (match Campaign.advance_travel (Campaign.AtNode "CBAR") 5.0 with
     | Campaign.AtNode "CBAR" -> true
     | _ -> false);
  let walker = { (fresh ()) with Campaign.level = 1 } in
  check "a road with no encounter stops nobody"
    (Campaign.road_encounter walker "CBAR" "WTHR" = None);
  let rec stopped n =
    n = 0 || (Campaign.road_encounter walker "CGAL" "WRAR" <> None || stopped (n - 1))
  in
  check "the goblin eventually stops a journey out of its road"
    (stopped 1000);
  check "a hero under its level is never stopped"
    (Campaign.road_encounter { walker with Campaign.level = 0 } "CGAL" "WRAR"
     = None)

let () =
  (* Encounter appearance: the two extracted conditions from OnQueryAppearance
     patterns - the hero's level reaches the encounter's, and a chance roll
     against its percentage. The shipped goblin rolls 2 percent, so the gates
     are tested on synthetic chances (100 and 0 make each side certain) and
     the real encounter over many rolls, where "sometimes" is the only honest
     word. The suite runs on OCaml's fixed default seed, so the walk is the
     same walk every run. *)
  let eago =
    List.find (fun (e : Campaign_encounters.encounter) -> e.Campaign_encounters.id = "EAGO")
      Campaign_encounters.encounters
  in
  let low = { (fresh ()) with Campaign.level = 1 } in
  let hidden = { low with Campaign.level = 0 } in
  let with_chance c = { eago with Campaign_encounters.chance = c } in
  check "at chance 100 a level-1 hero meets a level-1 encounter"
    (Campaign.check_encounter_appearance low (with_chance 100) = Campaign.Appears);
  check "the level gates even at chance 100"
    (Campaign.check_encounter_appearance hidden (with_chance 100) = Campaign.StaysHidden);
  check "the roll gates even a qualified hero at chance 0"
    (Campaign.check_encounter_appearance low (with_chance 0) = Campaign.StaysHidden);
  check "a hero below the encounter's level never does"
    (Campaign.check_encounter_appearance hidden eago = Campaign.StaysHidden);
  let rec walk n appeared hidden_seen =
    if n = 0 then (appeared, hidden_seen)
    else
      let a = Campaign.check_encounter_appearance low eago = Campaign.Appears in
      walk (n - 1) (appeared || a) (hidden_seen || not a)
  in
  let appeared, hidden_seen = walk 1000 false false in
  check "the real goblin appears within a thousand rolls" appeared;
  check "and stays hidden within them too" hidden_seen;
  check "the encounter sits on its road in the data"
    (List.exists (fun (e : Campaign_encounters.encounter) -> e.Campaign_encounters.id = "EAGO")
       (Campaign_encounters.encounters_on_road "CGAL" "WRAR"));
  check "and not on the seed city's road"
    (not (List.exists (fun (e : Campaign_encounters.encounter) -> e.Campaign_encounters.id = "EAGO")
            (Campaign_encounters.encounters_on_road "CGAL" "WTHR")));
  (* The visible list is that data filtered by the roll, so walk the filter
     until its 2 percent lands: empty-after-a-thousand is one roll in 10^9. *)
  let rec roll n =
    if n = 0 then []
    else
      let l = Campaign.encounters_on_road_visible low "CGAL" "WRAR" in
      if l <> [] then l else roll (n - 1)
  in
  check "the road's visible list eventually shows the goblin"
    (List.exists (fun (e : Campaign_encounters.encounter) -> e.Campaign_encounters.id = "EAGO")
       (roll 1000))

let () =
  (* Income: standing in a city pays its registry value per visit; standing
     nowhere pays nothing. *)
  let p = fresh () in
  check_int "the seed city pays its income"
    (Campaign.collect_income { p with Campaign.current_city = Some "CBAR" }).Campaign.gold
    (p.Campaign.gold + 100);
  check "collecting with no city changes nothing"
    ((Campaign.collect_income p).Campaign.gold = p.Campaign.gold);
  check_int "a second city pays its own rate"
    (Campaign.collect_income { p with Campaign.current_city = Some "CDRA" }).Campaign.gold
    (p.Campaign.gold + 150)

let () =
  (* Level-up: the profession table decides the threshold, one call pays one
     level's life, and a spell due at that level lands in the book. The warrior
     table (level 2 costs 40 xp, life 2 per level, SWLO at 2, no level-1
     grant) is the fixture. *)
  let p = fresh () in
  check_int "level 2 costs 40 on the warrior table"
    (Campaign.xp_for_level p.Campaign.profession 2) 40;
  check_int "level 3 costs 80"
    (Campaign.xp_for_level p.Campaign.profession 3) 80;
  check_int "a level the table does not list falls back to leveladd"
    (Campaign.xp_for_level p.Campaign.profession 51) (5000 * 51);
  check "level-up below the threshold is a no-op"
    ((Campaign.check_level_up { p with Campaign.xp = 39 }).Campaign.level = 1);
  check "exactly at the threshold it fires"
    ((Campaign.check_level_up { p with Campaign.xp = 40 }).Campaign.level = 2);
  let up = Campaign.check_level_up { p with Campaign.xp = 40 } in
  check_int "the level gains its life" up.Campaign.max_life (p.Campaign.max_life + 2);
  check_int "current life gains with it" up.Campaign.life (p.Campaign.life + 2);
  check "the level's spell is learned"
    (List.mem "SWLO" up.Campaign.known_spells);
  check "one call pays exactly one level, whatever the xp holds"
    ((Campaign.check_level_up { p with Campaign.xp = 9999 }).Campaign.level = 2);
  check "a second call pays the next one"
    ((Campaign.check_level_up
        (Campaign.check_level_up { p with Campaign.xp = 9999 })).Campaign.level
     = 3)

let () =
  (* City transactions: the shop charges the registry's cost, takes the gold
     or refuses, and the tavern's rumors are the TextLibrary's own pairs. *)
  let p = fresh () in
  let forsale = List.hd Campaign_items.items in
  let price = forsale.Campaign_items.cost in
  let rich = { p with Campaign.gold = price + 5 } in
  (match Campaign.buy_item rich forsale with
  | Some bought ->
      check_int "the gold is paid exactly" bought.Campaign.gold 5;
      check "the item lands in the inventory"
        (List.exists
           (fun (i : Campaign_items.item) ->
             i.Campaign_items.id = forsale.Campaign_items.id)
           bought.Campaign.inventory)
  | None -> check "a rich buyer buys" false);
  check "one gold piece short is refused"
    (Campaign.buy_item { p with Campaign.gold = price - 1 } forsale = None);
  check "and a broke hero's inventory never grows"
    ((Campaign.buy_item { p with Campaign.gold = 0 } forsale) = None
     && p.Campaign.inventory = []);
  check "the tavern has its full fifty-five rumors"
    (List.length Campaign.rumors = 55);
  check "every rumor carries both halves"
    (List.for_all (fun (n, d) -> n <> "" && d <> "") Campaign.rumors);
  (match Campaign.rumors with
  | (name, desc) :: _ ->
      check "the first is the library's first"
        (name = Text_data.text "[RUMOR_U000_NAME]"
         && desc = Text_data.text "[RUMOR_U000_DESC]")
  | [] -> check "the first is the library's first" false)

check "one call pays exactly one level, whatever the xp holds"
    ((Campaign.check_level_up { p with Campaign.xp = 9999 }).Campaign.level = 2);
  check "a second call pays the next one"
    ((Campaign.check_level_up
        (Campaign.check_level_up { p with Campaign.xp = 9999 })).Campaign.level
     = 3)

let () =
  (* City transactions: the shop charges the registry's cost, takes the gold
     or refuses, and the tavern's rumors are the TextLibrary's own pairs. *)
  let p = fresh () in
  let forsale = List.hd Campaign_items.items in
  let price = forsale.Campaign_items.cost in
  let rich = { p with Campaign.gold = price + 5 } in
  (match Campaign.buy_item rich forsale with
  | Some bought ->
      check_int "the gold is paid exactly" bought.Campaign.gold 5;
      check "the item lands in the inventory"
        (List.exists
           (fun (i : Campaign_items.item) ->
             i.Campaign_items.id = forsale.Campaign_items.id)
           bought.Campaign.inventory)
  | None -> check "a rich buyer buys" false);
  check "one gold piece short is refused"
    (Campaign.buy_item { p with Campaign.gold = price - 1 } forsale = None);
  check "and a broke hero's inventory never grows"
    ((Campaign.buy_item { p with Campaign.gold = 0 } forsale) = None
     && p.Campaign.inventory = []);
  check "the tavern has its full fifty-five rumors"
    (List.length Campaign.rumors = 55);
  check "every rumor carries both halves"
    (List.for_all (fun (n, d) -> n <> "" && d <> "") Campaign.rumors);
  (match Campaign.rumors with
  | (name, desc) :: _ ->
      check "the first rumor is the library's first"
        (name = Text_data.text "[RUMOR_U000_NAME]"
         && desc = Text_data.text "[RUMOR_U000_DESC]")
  | [] -> check "the first is the library's first" false)

let () =
  (* Conversation system: the engine triggers conversations via
     Lua_QUEST_CONVERSATION with two string args (conversation ID and
     starting point). The text data is in the TextLibrary under tags
     like [Conv_Q0I2a_NAME1], [Conv_Q0I2a_0000], etc. *)
  let convs = Conversation.load_all () in
  check "the conversation table loads"
    (List.length convs > 200);
  check "Q0I2a exists and has the right speaker"
    (match Conversation.find convs "Q0I2a" with
     | Some c -> c.Conversation.speaker_name = "Queen Gwendholyn"
     | None -> false);
  check "Q0I2a has the expected first line"
    (match Conversation.find convs "Q0I2a" with
     | Some c -> List.hd c.Conversation.lines = { Conversation.speaker = "Queen Gwendholyn"; text = "I have another message for you to deliver." }
     | None -> false);
  check "a non-existent conversation returns None"
    (Conversation.find convs "NONEXISTENT" = None)

let () =
  if !failures > 0 then begin
    Printf.printf "\n%d failure(s)\n" !failures;
    exit 1
  end;
  print_endline "all campaign tests passed"
