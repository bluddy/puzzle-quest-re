(* Conversation triggers and per-callback effects: what the quest engine
   queues when a conversation should open (OnBegin intros, OnEnterLocation
   arrivals, nested trees inside callbacks) and what a callback body applies
   when the dialogue fires its scriptcall (state writes, grants,
   QUEST_COMPLETE, queued conversations) - the non-battle half of
   execute_callback.

    What this file proves that the extraction listings did not: that the
    queues actually fill and drain (accept queues the intro, an arrival at a
    guarded location queues its tree - and only when its companion gate
    holds, a wildcard-state arrival queues at any stage, firing a callback
    queues its nested tree or message box), that the
    effects land on a real player (state 1 -> 2, gold/xp/item/companion
    grants, a completes quest runs OnEnd exactly like turn-in), that
    reattribution kept rewards single-owner (Q0T0's IBSH and Q0Q4's NDKH live
    in their callbacks, not the turn-in buckets), that a message-only
    callback queues its box without touching the player, and that body
    effects apply before a battle-table callback settles (Q3D1/CallbackConvB
    writes questState = 5 first, so the stage advance reads 5).

    The map tables and the ruin registry are global mutable state, so the
    whole file snapshots them first and restores at the end, like
    test_campaign and test_quest_battle. The pending queues are global too:
    both drained at the start and before every assertion on them. *)

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
  let rec go () =
    match Campaign.take_pending_conversation () with
    | None -> ()
    | Some _ -> go ()
  in
  go ();
  let rec gm () =
    match Campaign.take_pending_message () with
    | None -> ()
    | Some _ -> gm ()
  in
  gm ()

let take_one () = Campaign.take_pending_conversation ()

let fresh () = Campaign.create_player "Tester" "PWAR" 0 0

let active qid stage = { (fresh ()) with Campaign.active_quests = [ (qid, stage) ] }

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
check "Q0I2's OnBegin intro conversation"
  (q0i2.Campaign_quests.conversations_begin = [ "Conv_Q0I2a" ]);
check "Q0I2's callback effects: a state write and a complete"
  (List.assoc_opt "CallbackConvB" q0i2.Campaign_quests.callback_effects
   = Some [ Campaign_quests.SetQuestState 2 ]
   && List.assoc_opt "CallbackConvC" q0i2.Campaign_quests.callback_effects
      = Some [ Campaign_quests.Complete ]);

let q3q1 = quest "Q3Q1" in
check "Q3Q1's arrivals are attributed to state+location"
  (q3q1.Campaign_quests.enter_effects =
   [ (1, "WETO", [], [ Campaign_quests.Conversation "Conv_Q3Q1b" ]);
     (2, "CYLA", [], [ Campaign_quests.Conversation "Conv_Q3Q1c" ]) ]);

let q0q5 = quest "Q0Q5" in
check "Q0Q5's wildcard-state arrival carries its companion gate"
  (q0q5.Campaign_quests.enter_effects =
   [ (-1, "WHPS", [ ("NDKH", true) ],
       [ Campaign_quests.Conversation "Conv_Q0Q5b" ]) ]);

let q3q7 = quest "Q3Q7" in
check "Q3Q7's branch keeps both trees (first source order fires)"
  (q3q7.Campaign_quests.conversations_begin = [ "Conv_Q3Q7a"; "Conv_Q3Q7aa" ]);

check "callback rewards left the turn-in buckets"
  ((quest "Q0T0").Campaign_quests.reward_items = []
   && (quest "Q0Q4").Campaign_quests.reward_companions = []);

(* Message rows: an assignment in a sibling arm of a branch open at the
   site is dead there - without that rule each site picked up its twin's
   text and queued a box Lua never shows. *)
let q3q6 = quest "Q3Q6" in
check "Q3Q6's success group carries one box - the callback one"
  (List.map (fun (_, _, _, _, e) -> e)
     (List.filter (fun (st, suc, _, _, _) -> st = 1 && suc = 1)
        q3q6.Campaign_quests.complete_effects)
  = [ [ Campaign_quests.ShowMessage
          ("[QUEST_Q3Q6_NAME]", "[QUEST_Q3Q6_SUCCESS1]", "CallbackMsgA");
        Campaign_quests.SetQuestState 2 ] ]);

let q1q0 = quest "Q1Q0" in
check "Q1Q0 keeps its failure box and only at the wildcard state"
  (List.filter (fun (_, suc, _, _, _) -> suc = 0)
     q1q0.Campaign_quests.complete_effects
  = [ (-1, 0, "", [],
        [ Campaign_quests.ShowMessage
            ("[QUEST_Q1Q0_NAME]", "[QUEST_Q1Q0_FAILURE]", "") ]) ]);

let qk06 = quest "QK06" in
check "QK06's execute groups split the NOCOMP / BUTTON arms by NKHA"
  (List.map (fun (_, _, _, e) -> e) qk06.Campaign_quests.execute_effects
  = [ [ Campaign_quests.ShowMessage
          ("[QUEST_QK06_NAME]", "[QUEST_QK06_NOCOMP]", "") ];
      [ Campaign_quests.ShowMessage
          ("[QUEST_QK06_NAME]", "[QUEST_QK06_BUTTON]", "MsgCallbackA") ] ]);

let qs00 = quest "QS00" in
check "QS00's arrival keeps one box per arm, no NOCOMP twin"
  (List.map (fun (_, _, _, e) -> e) qs00.Campaign_quests.enter_effects
  = [ [ Campaign_quests.ShowMessage
          ("[QUEST_QS00_NAME]", "[QUEST_QS00_NOCOMP]", "") ];
      [ Campaign_quests.ShowMessage
          ("[QUEST_QS00_NAME]", "[QUEST_QS00_PRELUDE]", "ConvB") ];
      [ Campaign_quests.ShowMessage
          ("[QUEST_QS00_NAME]", "[QUEST_QS00_REENTER]", "") ] ]);

check "location-action conversations live in the execute/complete groups"
  (List.exists
     (fun (q : Campaign_quests.quest) ->
       List.exists (fun (_, _, _, effs) ->
           List.exists (function Campaign_quests.Conversation _ -> true | _ -> false)
             effs)
         q.Campaign_quests.execute_effects)
     Campaign_quests.quests
   && List.exists
        (fun (q : Campaign_quests.quest) ->
          List.exists (fun (_, _, _, _, effs) ->
              List.exists (function Campaign_quests.Conversation _ -> true | _ -> false)
                effs)
              q.Campaign_quests.complete_effects)
        Campaign_quests.quests);

check "no OnAbandon conversations ship (the queue path is completeness only)"
  (List.for_all (fun (q : Campaign_quests.quest) -> q.Campaign_quests.conversations_abandon = [])
      Campaign_quests.quests);

(* ---------------------------------------------------------------- *)
(* Queueing: accept, arrival, nested callback trees                  *)
(* ---------------------------------------------------------------- *)

drain ();

(* Q0I2 needs level 6 and Q0Q0 + Q0Q4 done. *)
let accepter () =
  { (fresh ()) with Campaign.level = 6; Campaign.completed_quests = [ "Q0Q0"; "Q0Q4" ] } in
let p0 = Campaign.quest_accept (accepter ()) "Q0I2" in
check "accepting a quest queues its intro conversation"
  (take_one () = Some "Conv_Q0I2a" && take_one () = None);

check "a second accept of the same quest queues nothing more"
  (let _p1 = Campaign.quest_accept p0 "Q0I2" in
   drain (); true);

check "an arrival at the guarded location queues the tree (Q0Q6 state 1, NDKH along)"
  (let p = { (active "Q0Q6" 1) with Campaign.companions = [ "NDKH" ] } in
   drain ();
   let _p2 = Campaign.enter_location p "WALF" in
   take_one () = Some "Conv_Q0Q6b" && take_one () = None);

check "the same arrival queues nothing with NDKH away (Q0Q6 gate)"
  (let p = active "Q0Q6" 1 in
   drain ();
   let _p2b = Campaign.enter_location p "WALF" in
   take_one () = None);

check "an arrival at the wrong stage queues nothing (Q0Q6 state 2)"
  (let p = { (active "Q0Q6" 2) with Campaign.companions = [ "NDKH" ] } in
   drain ();
   let _p3 = Campaign.enter_location p "WALF" in
   take_one () = None);

check "an arrival at the wrong location queues nothing"
  (let p = { (active "Q0Q6" 1) with Campaign.companions = [ "NDKH" ] } in
   drain ();
   let _p4 = Campaign.enter_location p "CBAR" in
   take_one () = None);

check "a wildcard-state arrival queues at any stage (Q0Q5 at WHPS, NDKH along)"
  (let p = { (active "Q0Q5" 3) with Campaign.companions = [ "NDKH" ] } in
   drain ();
   let _p5 = Campaign.enter_location p "WHPS" in
   take_one () = Some "Conv_Q0Q5b" && take_one () = None);

check "the wildcard-state arrival is gated too (Q0Q5 without NDKH)"
  (let p = active "Q0Q5" 3 in
   drain ();
   let _p5b = Campaign.enter_location p "WHPS" in
   take_one () = None);

check "Q3Q1's stage 1 arrival queues its own tree only"
  (let p = active "Q3Q1" 1 in
   drain ();
   let _p6 = Campaign.enter_location p "WETO" in
   take_one () = Some "Conv_Q3Q1b" && take_one () = None);

check "Q3Q1's stage 2 arrival queues the other tree"
  (let p = active "Q3Q1" 2 in
   drain ();
   let _p7 = Campaign.enter_location p "CYLA" in
   take_one () = Some "Conv_Q3Q1c" && take_one () = None);

check "firing a callback with a nested conversation queues it"
  (drain ();
   let p = active "Q0Q4" 1 in
   match Campaign.execute_callback ~rng:seed p "Q0Q4" "CallbackEnterMaethelburg" with
   | None -> false
   | Some _r -> take_one () = Some "Conv_Q0Q4b" && take_one () = None);

(* ---------------------------------------------------------------- *)
(* Effects on a real player                                          *)
(* ---------------------------------------------------------------- *)

check "Q0I2/CallbackConvB writes questState 1 -> 2"
  (match Campaign.execute_callback ~rng:seed (active "Q0I2" 1) "Q0I2" "CallbackConvB" with
   | None -> false
   | Some r ->
     r.Campaign.cb_battle = None && state_of r.Campaign.cb_player "Q0I2" = Some 2);

check "Q0I2/CallbackConvC completes the quest and pays OnEnd"
  (let before = active "Q0I2" 2 in
   match Campaign.execute_callback ~rng:seed before "Q0I2" "CallbackConvC" with
   | None -> false
   | Some r ->
     let p = r.Campaign.cb_player in
     r.Campaign.cb_battle = None
     && state_of p "Q0I2" = None
     && List.mem "Q0I2" p.Campaign.completed_quests
     && p.Campaign.gold = before.Campaign.gold + 100
     && p.Campaign.xp = before.Campaign.xp + 20);

check "Q0T0/CallbackConvB grants its item and xp (the reattributed reward)"
  (let before = active "Q0T0" 1 in
   match Campaign.execute_callback ~rng:seed before "Q0T0" "CallbackConvB" with
   | None -> false
   | Some r ->
     let p = r.Campaign.cb_player in
     r.Campaign.cb_battle = None
     && List.exists (fun (i : Campaign_items.item) -> i.Campaign_items.id = "IBSH")
          p.Campaign.inventory
     && p.Campaign.xp = before.Campaign.xp + 1);

check "Q0Q4/CallbackCompanion grants NDKH and completes the quest"
  (let before = active "Q0Q4" 1 in
   match Campaign.execute_callback ~rng:seed before "Q0Q4" "CallbackCompanion" with
   | None -> false
   | Some r ->
     let p = r.Campaign.cb_player in
     List.mem "NDKH" p.Campaign.companions
     && List.mem "Q0Q4" p.Campaign.completed_quests);

check "a Message-only callback queues its box and applies nothing else"
  (drain ();
   let before = active "Q0Q6" 1 in
   match Campaign.execute_callback ~rng:seed before "Q0Q6" "CallbackConvB" with
   | None -> false
   | Some r ->
     let msg = Campaign.take_pending_message () in
     r.Campaign.cb_battle = None && r.Campaign.cb_player = before
     && (match msg with
         | Some m ->
           m.Campaign.pmsg_text = "[Q0Q6_GIFT]"
           && m.Campaign.pmsg_quest = "Q0Q6"
           && Campaign.take_pending_message () = None
         | None -> false));

check "an unknown callback answers None (no effects, no battle)"
  (Campaign.execute_callback ~rng:seed (fresh ()) "Q0I2" "CallbackNope" = None);

(* ---------------------------------------------------------------- *)
(* Effects run before the battle settles                             *)
(* ---------------------------------------------------------------- *)

(* Q3D1/CallbackConvB writes questState = 5, then its fight settles from 5:
   a win advances to 6 (stage + 1, no extracted advance entry), a loss
   stays 5. Applying the effects after the settle would leave 5 either way;
   the old, effectless path would leave 1 or 2. *)
check "Q3D1/CallbackConvB applies state 5 before its battle settles"
  (let before = active "Q3D1" 1 in
   match Campaign.execute_callback ~rng:seed before "Q3D1" "CallbackConvB" with
   | None -> false
   | Some r ->
     (match r.Campaign.cb_battle with
      | None -> false
      | Some b ->
         let won = Battle.hero_won b in
         state_of r.Campaign.cb_player "Q3D1" = (if won then Some 6 else Some 5)));

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
print_endline "all callback effect tests passed"
