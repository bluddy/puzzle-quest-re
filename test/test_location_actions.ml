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
    the guarded groups actually land on a real player, that a message's
    callback fires through execute_callback like the UI's OK button, and
    that the companion gates read the party - each dual-arm quest queues
    one box for the companion along and the other for the companion away
    (QK06, QS00, Q3S0; QP01's label, Q2Q7's conversation).

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

let active_with_vars qid stage vars =
  { (active qid stage) with Campaign.quest_vars = [ (qid, vars) ] }

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

(* group / query rows carry the var, item and clause slots now; the
   compact builders keep the older assertions readable, empty lists =
   unconstrained. *)
(* query rows carry the var / item / clause slots; the compact builder
   keeps the older assertions readable, empty lists = unconstrained.
   [cl st] is the stage-clause every elseif arm of a stage branch emits. *)
let cl st = ([ st ], [], None, [], [], []) in
let qr st loc ?(clauses = []) tag = (st, loc, [], [], [], clauses, tag) in

let q0i2 = quest "Q0I2" in
check "Q0I2's query rows carry stage, node, gate and label"
  (q0i2.Campaign_quests.query_actions =
   [ qr 1 "CENM" "[QUEST_Q0I2_ACTION1]";
     qr 2 "CENM" ~clauses:[ cl 1 ] "[QUEST_Q0I2_ACTION2]" ]);
let q0q0 = quest "Q0Q0" in
check "Q0Q0's complete groups are success, failure, then the live chain"
  (List.map (fun (st, suc, loc, _, _, _, _, _, _) -> (st, suc, loc))
     q0q0.Campaign_quests.complete_effects
   = [ (1, 1, ""); (1, 0, ""); (1, -1, ""); (2, -1, "") ]);
check "Q0I3 turns in straight from execute at stage 2"
  ((quest "Q0I3").Campaign_quests.execute_effects =
   [ (2, "", [], [], [], [ cl 1 ], [ Campaign_quests.Complete ], false) ]);

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
(* The Lua is an exclusive elseif on lostToThief: a fresh player (var
   absent = 0) gets Q0Q0a only - the twin row fires when the thief won. *)
check "Q0Q0's stage-2 execute queues the thief-lost conversation only"
  (take_conv () = Some "Conv_Q0Q0a" && take_conv () = None);

drain ();
let _p3b = Campaign.execute_action (active_with_vars "Q0Q0" 2 [ ("lostToThief", 1) ]) "Q0Q0" "WSIR" in
check "with lostToThief=1 the same execute queues the thief-won twin"
  (take_conv () = Some "Conv_Q0Q0b" && take_conv () = None);

(* Q1G3's OnExecuteAction is ONE if/elseif chain: the questState==1 arm
   writes questState = 2, and Lua does not re-enter the chain afterwards,
   so the questState==2 arms are siblings that cannot fire this call. The
   nand clauses are what enforce that mutual exclusion. *)
drain ();
let p4 = Campaign.execute_action (active "Q1G3" 1) "Q1G3" "CGAL" in
check "Q1G3's stage-1 arm fires alone: the box shows, the stage advances"
  (state_of p4 "Q1G3" = Some 2
   && not (List.mem "Q1G3" p4.Campaign.completed_quests)
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q1G3_TRADE]"
       | None -> false)
   && take_msg () = None && take_conv () = None);

(* The stage-2 arm is reachable, but only on a later call once the stage
   really is 2 - which p7 below pins. *)

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

(* Q0Q0's OnCompleteAction at questState==1 is ONE arm: it writes
   lostToThief, advances questState to 2 and posts the box. The
   elseif (questState==2) then QUEST_COMPLETE arm is a sibling of that
   chain, so it cannot fire in the same call - the nand clauses hold it
   out. Success and failure differ only in which box posts. *)
drain ();
let p11 = Campaign.complete_action ~success:true (active "Q0Q0" 1) "Q0Q0" "WSIR" in
check "Q0Q0's success posts ACTION1 and advances to stage 2, no turn-in"
  (state_of p11 "Q0Q0" = Some 2
   && not (List.mem "Q0Q0" p11.Campaign.completed_quests)
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0Q0_ACTION1]"
       | None -> false)
   && take_msg () = None);

drain ();
let p12 = Campaign.complete_action ~success:false (active "Q0Q0" 1) "Q0Q0" "WSIR" in
check "Q0Q0's failure posts ACTION2 instead, same stage, no turn-in"
  (state_of p12 "Q0Q0" = Some 2
   && not (List.mem "Q0Q0" p12.Campaign.completed_quests)
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
(* companion gates: the extracted (id, present) tests read the party *)
(* ---------------------------------------------------------------- *)

drain ();
let g1 =
  Campaign.execute_action
    { (active "QK06" 1) with Campaign.companions = [ "NKHA" ] }
    "QK06" "" in
check "QK06 execute with NKHA along queues the button box"
  ((match take_msg () with
    | Some m ->
      m.Campaign.pmsg_text = "[QUEST_QK06_BUTTON]"
      && m.Campaign.pmsg_callback = "MsgCallbackA"
      && m.Campaign.pmsg_quest = "QK06"
    | None -> false)
   && take_msg () = None && take_conv () = None
   && state_of g1 "QK06" = Some 1);

drain ();
let _g2 = Campaign.execute_action (active "QK06" 1) "QK06" "" in
check "QK06 execute with NKHA away queues the NOCOMP box instead"
  ((match take_msg () with
    | Some m ->
      m.Campaign.pmsg_text = "[QUEST_QK06_NOCOMP]"
      && m.Campaign.pmsg_callback = ""
    | None -> false)
   && take_msg () = None && take_conv () = None);

check "QP01's label shows only with NPAT along"
  (Campaign.query_actions
     { (active "QP01" 1) with Campaign.companions = [ "NPAT" ] }
     "WPIK"
   = [ ("QP01", "[QUEST_QP01_ACTION1]") ]);

check "QP01 offers nothing with NPAT away (the gate holds the label)"
  (Campaign.query_actions (active "QP01" 1) "WPIK" = []);

drain ();
let g3 =
  Campaign.complete_action ~success:true
    { (active "Q2Q7" 1) with Campaign.companions = [ "NDRO" ] }
    "Q2Q7" "" in
check "Q2Q7's win queues its conversation with NDRO along"
  (take_conv () = Some "Conv_Q2Q7b" && take_conv () = None);
check "Q2Q7's NDRO branch returns: no fall-through box, stage stays 1"
  (state_of g3 "Q2Q7" = Some 1 && take_msg () = None);

drain ();
let g4 =
  Campaign.complete_action ~success:true (active "Q2Q7" 1) "Q2Q7" "" in
check "Q2Q7's win skips the conversation with NDRO away"
  (take_conv () = None);
check "Q2Q7 without NDRO falls through: KILL box and stage 2"
  ((match take_msg () with
    | Some m -> m.Campaign.pmsg_text = "[QUEST_Q2Q7_KILL]"
    | None -> false)
   && state_of g4 "Q2Q7" = Some 2);

drain ();
let g4f =
  Campaign.complete_action ~success:false (active "Q2Q7" 1) "Q2Q7" "" in
check "Q2Q7's failure keeps the FAILURE box at stage 1"
  ((match take_msg () with
    | Some m -> m.Campaign.pmsg_text = "[QUEST_Q2Q7_FAILURE]"
    | None -> false)
   && state_of g4f "Q2Q7" = Some 1);

drain ();
let g5 =
  Campaign.enter_location
    { (active "QS00" 1) with Campaign.companions = [ "NSER" ] }
    "CENM" in
check "QS00's arrival with NSER along queues the prelude and removes her"
  ((match take_msg () with
    | Some m ->
      m.Campaign.pmsg_text = "[QUEST_QS00_PRELUDE]"
      && m.Campaign.pmsg_callback = "ConvB"
    | None -> false)
   && take_msg () = None && take_conv () = None
   && not (List.mem "NSER" g5.Campaign.companions));

drain ();
let _g6 = Campaign.enter_location (active "QS00" 1) "CENM" in
check "QS00's arrival with NSER away queues the NOCOMP box"
  ((match take_msg () with
    | Some m -> m.Campaign.pmsg_text = "[QUEST_QS00_NOCOMP]"
    | None -> false)
   && take_msg () = None && take_conv () = None);

drain ();
let g7 =
  Campaign.enter_location
    { (active "Q3S0" 2) with Campaign.companions = [ "NSER" ] }
    "WLOB" in
check "Q3S0's sword point with NSER along queues the leave box and removes"
  ((match take_msg () with
    | Some m -> m.Campaign.pmsg_text = "[QUEST_Q3S0_LEAVE0]"
    | None -> false)
   && take_msg () = None && take_conv () = None
   && not (List.mem "NSER" g7.Campaign.companions));

drain ();
let _g8 =
  Campaign.enter_location { (active "Q3S0" 2) with Campaign.companions = [] }
    "WLOB" in
check "Q3S0's sword point with NSER away queues nothing"
  (take_msg () = None && take_conv () = None);

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
(* travel: advance_travel_with_events fires the arrival moment       *)
(* ---------------------------------------------------------------- *)

drain ();
let walking : Campaign.travel_state =
  Campaign.Traveling
    { from_ = "CENM"; to_ = "WSIR"; progress = 0.0; total_time = 0.5 }
in
let p20, ts20 = Campaign.advance_travel_with_events (active "Q0Q0" 1) walking 0.25 in
check "a mid-road step passes the player through untouched"
  (state_of p20 "Q0Q0" = Some 1
   && (match ts20 with
       | Campaign.Traveling t -> t.progress > 0.0 && t.total_time = 0.5
       | _ -> false)
   && take_msg () = None && take_conv () = None);

drain ();
let p21, ts21 = Campaign.advance_travel_with_events (active "Q0Q0" 1) walking 1.0 in
check "landing on the ambush node runs enter_location (Q0Q0 box)"
  (ts21 = Campaign.AtNode "WSIR" && state_of p21 "Q0Q0" = Some 1
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q0Q0_AMBUSH]"
       | None -> false)
   && take_conv () = None);

drain ();
let quiet : Campaign.travel_state =
  Campaign.Traveling
    { from_ = "CBAR"; to_ = "CENM"; progress = 0.0; total_time = 0.5 }
in
let _p22, ts22 = Campaign.advance_travel_with_events (active "Q0Q0" 1) quiet 1.0 in
check "a plain arrival queues nothing"
  (ts22 = Campaign.AtNode "CENM" && take_msg () = None && take_conv () = None);

(* ---------------------------------------------------------------- *)
(* the untracked chains: script vars drive the arms                  *)
(* ---------------------------------------------------------------- *)

(* Q1S0: OnExecuteAction at stage 2 is an if/elseif/else over NKHA and
   triedToKeepKey - the three arms the old tables merged into one row. *)
drain ();
let q1s0_nkha =
  { (active "Q1S0" 2) with Campaign.companions = [ "NKHA" ] }
in
let p_q1s0a = Campaign.execute_action q1s0_nkha "Q1S0" "ROTO" in
check "Q1S0: NKHA + tried=0 queues the key conversation and writes tried=1"
  (take_conv () = Some "Conv_Q1S0b" && take_conv () = None
   && take_msg () = None
   && Campaign.script_var_get p_q1s0a "Q1S0" "triedToKeepKey" = 1
   && state_of p_q1s0a "Q1S0" = Some 2);

drain ();
let q1s0_tried =
  { (active_with_vars "Q1S0" 2 [ ("triedToKeepKey", 1) ])
    with Campaign.companions = [ "NKHA" ] }
in
let p_q1s0b = Campaign.execute_action q1s0_tried "Q1S0" "ROTO" in
check "Q1S0: NKHA + tried=1 queues only Khalkusno's box"
  (take_conv () = None
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_Q1S0_KHALKUSNO]"
       | None -> false)
   && take_msg () = None
   && Campaign.script_var_get p_q1s0b "Q1S0" "triedToKeepKey" = 1
   && state_of p_q1s0b "Q1S0" = Some 2);

drain ();
let p_q1s0c = Campaign.execute_action (active "Q1S0" 2) "Q1S0" "ROTO" in
check "Q1S0: NKHA away completes with keptHeirloom=1"
  (take_conv () = None && take_msg () = None
   && Campaign.script_var_get p_q1s0c "Q1S0" "keptHeirloom" = 1
   && state_of p_q1s0c "Q1S0" = None
   && List.mem "Q1S0" p_q1s0c.Campaign.completed_quests);

drain ();
let q1s0_cdko =
  { (active_with_vars "Q1S0" 2 [ ("triedToKeepKey", 1) ])
    with Campaign.companions = [ "NKHA" ] }
in
let p_q1s0d = Campaign.execute_action q1s0_cdko "Q1S0" "CDKO" in
check "Q1S0: at Cdko the origin row wins over both companion arms"
  (take_conv () = None && take_msg () = None
   && Campaign.script_var_get p_q1s0d "Q1S0" "keptHeirloom" = 0
   && state_of p_q1s0d "Q1S0" = None
   && List.mem "Q1S0" p_q1s0d.Campaign.completed_quests);

(* QA03: the stage action fights only with NDKH along and doneConv already
   set by the conversation - the battle row's two clauses pin both else
   arms out. *)
drain ();
let qa03_alone =
  { (active_with_vars "QA03" 1 [ ("doneConv", 1) ]) with Campaign.companions = [] }
in
let _p_qa03a = Campaign.execute_action qa03_alone "QA03" "WSGK" in
check "QA03: NDKH away queues only the NOCOMP box"
  (take_conv () = None
   && (match take_msg () with
       | Some m -> m.Campaign.pmsg_text = "[QUEST_QA03_NOCOMP]"
       | None -> false)
   && take_msg () = None);

drain ();
let qa03_conv =
  { (active_with_vars "QA03" 1 [ ("doneConv", 0) ])
    with Campaign.companions = [ "NDKH" ] }
in
let p_qa03b = Campaign.execute_action qa03_conv "QA03" "WSGK" in
check "QA03: NDKH + doneConv=0 queues the conversation"
  (take_conv () = Some "Conv_QA03b" && take_conv () = None
   && take_msg () = None
   && Campaign.script_var_get p_qa03b "QA03" "doneConv" = 0);

(* Q3Q5: the necropolis sites are per-arm script-var chains with an
   inventory gate on the ISES rod - exactly the two dimensions the old
   tables could not see. *)
drain ();
let q3q5_plain = active_with_vars "Q3Q5" 1 [ ("doneNecro1", 0) ] in
let p_q3q5a = Campaign.execute_action q3q5_plain "Q3Q5" "WBBR" in
check "Q3Q5: no ISES at the first necropolis queues the no-rod conversation"
  (take_conv () = Some "Conv_Q3Q5b" && take_conv () = None && take_msg () = None
   && state_of p_q3q5a "Q3Q5" = Some 1);

drain ();
let q3q5_ises =
  { (active_with_vars "Q3Q5" 1 [ ("doneNecro1", 0) ])
    with Campaign.inventory = [ Campaign_items.item_by_id "ISES" ] }
in
let _p_q3q5b = Campaign.execute_action q3q5_ises "Q3Q5" "WBBR" in
check "Q3Q5: with ISES in the pack the rod conversation takes the arm"
  (take_conv () = Some "Conv_Q3Q5bb" && take_conv () = None && take_msg () = None);

drain ();
let q3q5_tried =
  active_with_vars "Q3Q5" 1
    [ ("doneNecro1", 0); ("triedNecro1", 1) ]
in
let _p_q3q5c = Campaign.execute_action q3q5_tried "Q3Q5" "WBBR" in
check "Q3Q5: tried=1 blocks both necropolis conversations"
  (take_conv () = None && take_msg () = None);

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
