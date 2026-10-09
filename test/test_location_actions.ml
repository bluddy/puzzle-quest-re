(* Location actions: the city-action flow around dialogue and battles -
   query, execute, complete, enter, and the message queue the boxes pop
   from. The extraction prints the groups; this file proves the engine
   runs them the way the Lua bodies did: query is first-match (Q0Q0's
   stage-2 branch shows POPUP1, not POPUP2), execute queues the action's
   conversation or message and can turn the quest in on the spot (Q0I3 at
   stage 2), complete applies the success/failure split and, because every
   matching group runs against the live state, Q0Q0's stage-1 outcome
   walks state 1 -> 2 -> Complete in a single call, enter fires guarded
   arrivals, and turn-in pays OnEnd's message box.

   What the listings did not show: that the queues fill and drain, that
   the guarded groups actually land on a real player, and that a message's
   callback fires through execute_callback like the UI's OK button.

   The map tables and the ruin registry are global mutable state, so the
   whole file snapshots them first and restores at the end, like
   test_campaign and test_callback_effects. Both pending queues are global
   too: drained at the start and before every assertion on them. *)

open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

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
let ruin_counts0 = Campaign.ruin_counts_snapshot ()
let ruin_done0 = Campaign.ruin_done_snapshot ()

let drain () =
  let rec gc () =
    match Campaign.take_pending_conversation () with
    | None -> ()
    | Some _ -> gc ()
  in
  let rec gm () =
    match Campaign.take_pending_message () with
    | None -> ()
    | Some _ -> gm ()
  in
  gc ();
  gm ()

let take_conv () = Campaign.take_pending_conversation ()
let take_msg () = Campaign.take_pending_message ()

let fresh () = Campaign.create_player "Tester" "PWAR" 0 0

let active qid stage =
  { (fresh ()) with Campaign.active_quests = [ (qid, stage) ] }

let state_of (p : Campaign.player) qid = List.assoc_opt qid p.Campaign.active_quests

let quest id : Campaign_quests.quest = Campaign_quests.quest_by_id id

let seed_state = ref 0

let seed n =
  seed_state := (!seed_state * 75 + 74) mod 65537;
  if n <= 0 then 0 else !seed_state mod n

let () =
(* ---------------------------------------------------------------- *)
(* The extracted tables                                             *)
(* ---------------------------------------------------------------- *)

let q0i2 = quest "Q0I2" in
check "Q0I2's query rows carry stage, node and label"
  (q0i2.Campaign_quests.query_actions =
   [ (1, "CENM", "[QUEST_Q0I2_ACTION1]");
     (2, "CENM", "[QUEST_Q0I2_ACTION2]") ]);
let q0q0 = quest "Q0Q0" in
check "Q0Q0's complete groups are success, failure, then the live chain"
  (List.map (fun (st, suc, loc, _) -> (st, suc, loc))
     q0q0.Campaign_quests.complete_effects
   = [ (1, 1, ""); (1, 0, ""); (1, -1, ""); (2, -1, "") ]);
check "Q0I3 turns in straight from execute at stage 2"
  ((quest "Q0I3").Campaign_quests.execute_effects = [ (2, "", [ Campaign_quests.Complete ]) ]);

(* ---------------------------------------------------------------- *)
(* query: first match wins                                          *)
(* ---------------------------------------------------------------- *)

check "Q0I2 offers its stage-1 action at CENM"
  (Campaign.query_actions (active "Q0I2" 1) "CENM"
   = [ ("Q0I2", "[QUEST_Q0I2_ACTION1]") ]);
check "Q0I2 offers its stage-2 action at CENM"
  (Campaign.query_actions (active "Q0I2" 2) "CENM"
   = [ ("Q0I2", "[QUEST_Q0I2_ACTION2]") ]);
check "Q0I2 offers nothing at the wrong node"
  (Campaign.query_actions (active "Q0I2" 1) "CBAR" = []);
check "Q0Q0's stage-2 branch shows POPUP1, not POPUP2 (first match wins)"
  (Campaign.query_actions (active "Q0Q0" 2) "WSIR"
   = [ ("Q0Q0", "[QUEST_Q0Q0_POPUP1]") ]);
check "an inactive hero has no actions anywhere"
  (Campaign.query_actions (fresh ()) "CENM" = []);

(* ---------------------------------------------------------------- *)
(* execute: the action starts, its dialogue queues                   *)
(* ---------------------------------------------------------------- *)

drain ();
let p1 = Campaign.execute_action (active "Q0I2" 1) "Q0I2" "CENM" in
check "execute queues Q0I2's conversation and leaves the stage alone"
  (take_conv () = Some "Conv_Q0I2b" && take_conv () = None
   && state_of p1 "Q0I2" = Some 1 && take_msg () = None);

drain ();
let p2 = Campaign.execute_action (active "Q0I2" 2) "Q0I2" "CENM" in
check "execute at stage 2 queues the guardian box with its callback"
  (state_of p2 "Q0I2" = Some 2
   && (match take_msg () with
       | Some m ->
         m.Campaign.pmsg_text = "[QUEST_Q0I2_GUARDIAN]"
         && m.Campaign.pmsg_callback = "CallbackGuardian"
         && m.Campaign.pmsg_quest = "Q0I2"
         && take_msg () = None
       | None -> false)
   && take_conv () = None);

drain ();
let _p3 = Campaign.execute_action (active "Q0Q0" 2) "Q0Q0" "WSIR" in
check "Q0Q0's stage-2 execute queues both conversations in order"
  (take_conv () = Some "Conv_Q0Q0a" && take_conv () = Some "Conv_Q0Q0b"
   && take_conv () = None);

drain ();
let p4 = Campaign.execute_action (active "Q1G3" 1) "Q1G3" "CGAL" in
check "Q1G3 at CGAL writes state 2 then completes in the same call"
  (state_of p4 "Q1G3" = None
   && List.mem "Q1G3" p4.Campaign.completed_quests
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q1G3_TRADE]"
       | None -> false)
   && take_msg () = None);

drain ();
let _p5 = Campaign.execute_action (fresh ()) "Q0I2" "CENM" in
check "execute on an inactive quest queues nothing"
  (take_conv () = None && take_msg () = None);

drain ();
let p6 = Campaign.execute_action (active "Q0I3" 2) "Q0I3" "CENM" in
check "Q0I3's execute at stage 2 completes the quest on the spot"
  (state_of p6 "Q0I3" = None && List.mem "Q0I3" p6.Campaign.completed_quests
   && take_conv () = None && take_msg () = None);

drain ();
let p7 = Campaign.execute_action (active "Q1G3" 2) "Q1G3" "CGAL" in
check "Q1G3's return node completes the quest from execute"
  (state_of p7 "Q1G3" = None && List.mem "Q1G3" p7.Campaign.completed_quests);

(* ---------------------------------------------------------------- *)
(* complete: the outcome split, live through the fold                *)
(* ---------------------------------------------------------------- *)

drain ();
let p8 = Campaign.complete_action ~success:true (active "Q0I2" 2) "Q0I2" "CENM" in
check "Q0I2's success queues its turn-in conversation, quest still active"
  (take_conv () = Some "Conv_Q0I2c" && take_conv () = None
   && state_of p8 "Q0I2" = Some 2 && take_msg () = None);

drain ();
let p9 = Campaign.complete_action ~success:false (active "Q0I2" 2) "Q0I2" "CENM" in
check "Q0I2's failure queues the failure box instead"
  (take_conv () = None
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0I2_FAIL]"
       | None -> false)
   && state_of p9 "Q0I2" = Some 2);

drain ();
let p10 = Campaign.complete_action ~success:true (active "Q0I2" 1) "Q0I2" "CENM" in
check "no complete group matches at stage 1 (Q0I2 stays put)"
  (state_of p10 "Q0I2" = Some 1
   && take_conv () = None && take_msg () = None);

drain ();
let p11 = Campaign.complete_action ~success:true (active "Q0Q0" 1) "Q0Q0" "WSIR" in
check "Q0Q0's success writes state 2 then completes in the same call"
  (state_of p11 "Q0Q0" = None
   && List.mem "Q0Q0" p11.Campaign.completed_quests
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0Q0_ACTION1]"
       | None -> false)
   && take_msg () = None);

drain ();
let p12 = Campaign.complete_action ~success:false (active "Q0Q0" 1) "Q0Q0" "WSIR" in
check "Q0Q0's failure takes the same live chain with the other box"
  (state_of p12 "Q0Q0" = None
   && List.mem "Q0Q0" p12.Campaign.completed_quests
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0Q0_ACTION2]"
       | None -> false)
   && take_msg () = None);

drain ();
let p13 = Campaign.complete_action ~success:true (active "Q0I3" 1) "Q0I3" "RSLV" in
check "Q0I3's success advances the stage and pays the kill box"
  (state_of p13 "Q0I3" = Some 2
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0I3_KILL]"
       | None -> false)
   && take_conv () = None);

drain ();
let p14 = Campaign.complete_action ~success:false (active "Q0I3" 1) "Q0I3" "RSLV" in
check "Q0I3's failure leaves stage 1 and queues its own box"
  (state_of p14 "Q0I3" = Some 1
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0I3_FAILURE]"
       | None -> false));

(* ---------------------------------------------------------------- *)
(* enter: guarded arrivals and the message queue itself              *)
(* ---------------------------------------------------------------- *)

drain ();
let p15 = Campaign.enter_location (active "Q0I2" 1) "CENM" in
check "the guarded arrival queues its box with the right fields"
  (state_of p15 "Q0I2" = Some 1
   && (match take_msg () with
       | Some m ->
         m.Campaign.pmsg_title = "[QUEST_Q0I2_NAME]"
         && m.Campaign.pmsg_text = "[QUEST_Q0I2_ENMOUTH]"
         && m.Campaign.pmsg_callback = ""
         && take_msg () = None
       | None -> false)
   && take_conv () = None);

drain ();
let _p16 = Campaign.enter_location (active "Q0I2" 1) "CBAR" in
check "the wrong node queues nothing on arrival"
  (take_msg () = None && take_conv () = None);

drain ();
let _p17 = Campaign.enter_location (active "Q0Q0" 1) "WSIR" in
check "Q0Q0's ambush box carries the callback that fires its fight"
  (match take_msg () with
   | Some m ->
     m.Campaign.pmsg_text = "[QUEST_Q0Q0_AMBUSH]"
     && m.Campaign.pmsg_callback = "CallbackAmbush"
     && take_msg () = None
   | None -> false);

drain ();
let _p18 = Campaign.execute_callback ~rng:seed (active "Q0Q0" 1)
    "Q0Q0" "CallbackAmbush" in
check "firing the ambush callback answers with its table battle"
  (match _p18 with
   | Some r -> r.Campaign.cb_battle <> None
   | None -> false);

(* ---------------------------------------------------------------- *)
(* end: turn-in pays the OnEnd message box                           *)
(* ---------------------------------------------------------------- *)

drain ();
let p19 = Campaign.quest_turn_in (active "Q0Q4" 1) "Q0Q4" in
check "turning Q0Q4 in queues its OnEnd box (the game's only one)"
  (List.mem "Q0Q4" p19.Campaign.completed_quests
   && state_of p19 "Q0Q4" = None
   && (match take_msg () with
       | Some m ->
         m.Campaign.pmsg_title = "[QUEST_Q0Q4_END_HDR]"
         && m.Campaign.pmsg_text = "[QUEST_Q0Q4_END_DEMO]"
         && m.Campaign.pmsg_quest = "Q0Q4"
         && take_msg () = None
       | None -> false)
   && take_conv () = None);

(* ---------------------------------------------------------------- *)
(* Global state cleanup                                              *)
(* ---------------------------------------------------------------- *)

drain ();
restore initial;
Campaign.restore_ruin_state ruin_counts0 ruin_done0;

if !failures > 0 then begin
  Printf.printf "\n%d failure(s)\n" !failures;
  exit 1
end;
print_endline "all location action tests passed"
