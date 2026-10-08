(* The quest-battle loop: a stage selects an action, the action's index
   selects the quest's <Battle> element, and the fight runs through the real
   engine - board, companion OnStartBattle hooks, spell line-ups on both
   sides - with the outcome feeding quest_battle_settle.

   What this file proves that the demo printing "battle won" did not: that
   the stage table drives which monster and which spells show up (Q0Q7's
   three fights are three different enemies), that a QUEST_BATTLE_NOCAPTURE
   stage records no defeat while its capturing sibling does, that a lost
   fight follows the script's else-branch state (Q0Q7 sends Dugog to the
   retry state 4) while a quest with no else entry keeps its stage, that a
   conversation-gated stage has no battle to run, and that the win/lose
   transitions match the extracted OnCompleteAction branches (including
   Q1E0, where two win-side values compete and source order decides).

   The real runs take a fixed die ([seed]) and every one of them comes back
   a loss: the auto-AI hero the engine hands a fresh character loses to the
   registry monsters, which is why the AI overhaul is its own workstream.
   So the runs prove execution - which fight, which roster, whose hooks,
   life, and the loss branches - while quest_battle_settle drives the win
   bookkeeping (advance, capture, ruin release, spoils) directly, once,
   against the same battle the loop actually ran.

   The map tables and the ruin registry are global mutable state, so the
   whole file snapshots them first and restores at the end, like
   test_campaign. *)

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

(* A real warrior arrives at these by leveling: create_player grants no
   spells (the level-1 entry is only handed out by check_level_up as level 2
   comes, so it is seeded by hand here), and every level-up above adds the
   profession's spell and life. The fixtures level instead of setting the
   level field, so life and loadout match the level. *)
let warrior lvl =
  let rec go p =
    if p.Campaign.level >= lvl then p
    else go (Campaign.check_level_up { p with Campaign.xp = 999999 })
  in
  go { (Campaign.create_player "Tester" "PWAR" 0 0)
       with Campaign.known_spells = [ "SBAC" ] }

let fresh () = warrior 1

let state_of (p : Campaign.player) qid = List.assoc_opt qid p.Campaign.active_quests

let quest id : Campaign_quests.quest = Campaign_quests.quest_by_id id

let spell_ids (ss : Spell.spell list) =
  List.map (fun (s : Spell.spell) -> s.Spell.id) ss

(* Every loop battle takes this die: a deterministic stream (fresh state per
   run) rather than one constant, so reshuffles and rolls actually vary and
   the fight terminates the same way every time. *)
let seed_state = ref 0

let seed n =
  seed_state := (!seed_state * 75 + 74) mod 65537;
  if n <= 0 then 0 else !seed_state mod n

let active qid stage = { (fresh ()) with Campaign.active_quests = [ (qid, stage) ] }

(* ------------------------------------------------------------------ *)
(* The extracted tables                                                *)
(* ------------------------------------------------------------------ *)

let quests = Campaign_quests.quests

let () =
check "142 quests ship" (List.length quests = 142);

check "every stage action points inside its quest's Battle list"
  (List.for_all
     (fun (q : Campaign_quests.quest) ->
       List.for_all (fun (_, i, _) -> i < List.length q.battles) q.battle_actions)
     quests);

check_int "the shipped data holds 155 Battle elements"
  (List.fold_left
     (fun n (q : Campaign_quests.quest) -> n + List.length q.battles) 0 quests)
  155;
check_int "and 128 stage actions"
  (List.fold_left
     (fun n (q : Campaign_quests.quest) -> n + List.length q.battle_actions) 0 quests)
  128;

let q0i0 = quest "Q0I0" in
check "Q0I0: one battle, captured"
  (q0i0.Campaign_quests.battles = [ ("MTRO", []) ]
   && q0i0.Campaign_quests.battle_actions = [ (1, 0, true) ]
   && q0i0.Campaign_quests.battle_stage_advances = []
   && q0i0.Campaign_quests.battle_stage_fails = []);

let q0e0 = quest "Q0E0" in
check "Q0E0: the fight hands the hero a spell"
  (q0e0.Campaign_quests.battles = [ ("MCTP", [ "SFSK" ]) ]
   && q0e0.Campaign_quests.battle_actions = [ (1, 0, true) ]
   && q0e0.Campaign_quests.battle_stage_advances = [ (1, 2) ]);

let q0s1 = quest "Q0S1" in
check "Q0S1: two no-capture fights, state 1 -> 2 -> 3"
  (q0s1.Campaign_quests.battles = [ ("MOGR", []); ("MOGR", []) ]
   && q0s1.Campaign_quests.battle_actions = [ (1, 0, false); (2, 1, false) ]
   && q0s1.Campaign_quests.battle_stage_advances = [ (1, 2) ]
   && q0s1.Campaign_quests.battle_stage_fails = []);

let q0q7 = quest "Q0Q7" in
check "Q0Q7: three fights, capture only on the caravan one"
  (q0q7.Campaign_quests.battles = [ ("MWIG", []); ("MOGR", []); ("MDGG", []) ]
   && q0q7.Campaign_quests.battle_actions = [ (2, 0, true); (3, 2, false); (4, 2, false) ]
   && q0q7.Campaign_quests.battle_stage_advances = [ (2, 3) ]
   && q0q7.Campaign_quests.battle_stage_fails = [ (3, 4) ]);

let q1e0 = quest "Q1E0" in
check "Q1E0: two win-side values, source order decides"
  (q1e0.Campaign_quests.battle_stage_advances = [ (1, 3) ]);

let q2m4 = quest "Q2M4" in
check "Q2M4: either stage wins to 3 and loses to 2"
  (q2m4.Campaign_quests.battle_stage_advances = [ (1, 3); (2, 3) ]
   && q2m4.Campaign_quests.battle_stage_fails = [ (1, 2); (2, 2) ]
   && q2m4.Campaign_quests.battle_actions = [ (1, 0, false); (2, 0, false) ]);

let q3q2 = quest "Q3Q2" in
check "Q3Q2: four fights in a row, four monsters"
  (q3q2.Campaign_quests.battles =
     [ ("MZOM", []); ("MWIG", []); ("MDOO", []); ("MARK", []) ]
   && q3q2.Campaign_quests.battle_actions =
     [ (1, 0, true); (2, 1, true); (3, 2, true); (4, 3, true) ]
   && q3q2.Campaign_quests.battle_stage_advances = []);

(* ------------------------------------------------------------------ *)
(* The loop itself: Q0I0 - capture, ruin release, spoils, turn-in      *)
(* ------------------------------------------------------------------ *)

Campaign.restore_ruin_state [] [];
let base0i0 () =
  { (warrior 7) with Campaign.completed_quests = [ "Q0Q4" ] } in
Campaign.set_location_visible "REGB" false;
let p1 = Campaign.quest_accept (base0i0 ()) "Q0I0" in
check "accepting Q0I0 holds REGB and reveals it"
  (state_of p1 "Q0I0" = Some 1
   && Campaign.ruin_count "REGB" = 1
   && Campaign.node_visible "REGB");

check "a quest with no active entry has no battle"
  (Campaign.run_quest_battle ~rng:seed (fresh ()) "Q0I0" = None);

(match Campaign.run_quest_battle ~rng:seed p1 "Q0I0" with
 | None -> check "Q0I0 stage 1 has a battle to run" false
 | Some (p2, b) ->
   check "the fight runs to a finish" (Battle.log_of b <> []);
   check "the hero took the loss: no else entry, stage stays 1"
     (state_of p2 "Q0I0" = Some 1);
   check "a lost fight records no defeat"
     (Campaign.monster_defeats p2 "MTRO" = 0);
   check "life follows the battle"
     (p2.Campaign.life = b.Battle.hero.life
      && p2.Campaign.life < p1.Campaign.life);
   check "a loss takes no spoils"
     (p2.Campaign.gold = p1.Campaign.gold && p2.Campaign.xp = p1.Campaign.xp);
   check "the ruin stays held after a loss"
     (Campaign.ruin_count "REGB" = 1 && not (Campaign.ruin_is_done "REGB"));
   check "MTRO's roster reached the enemy side"
     (spell_ids b.Battle.enemy_spells = [ "SRGN" ]);
   (* The same battle, marked won: the win bookkeeping runs exactly as it
      would if the hero had pulled it off. *)
   let pw = Campaign.quest_battle_settle p1 "Q0I0" true b in
   check "the stage advances by the default 1 -> 2"
     (state_of pw "Q0I0" = Some 2);
   check "the win is a capture: MTRO's defeat is on record"
     (Campaign.monster_defeats pw "MTRO" = 1);
   check "the ruin released OnCompleteAction"
     (Campaign.ruin_count "REGB" = 0 && Campaign.ruin_is_done "REGB");
   check "spoils went to the player"
     (pw.Campaign.gold = p1.Campaign.gold + b.Battle.gold
      && pw.Campaign.xp = p1.Campaign.xp + b.Battle.xp);
   let p3 = Campaign.quest_turn_in pw "Q0I0" in
   check "turn-in completes the quest"
     (state_of p3 "Q0I0" = None
      && List.mem "Q0I0" p3.Campaign.completed_quests));

Campaign.restore_ruin_state [] [];

(* ------------------------------------------------------------------ *)
(* No-capture stages: Q0S1 through two fights and out                  *)
(* ------------------------------------------------------------------ *)

let spoil () =
  { (warrior 11) with Campaign.completed_quests = [ "Q0Q0" ] } in
Campaign.set_location_visible "ROTO" false;
let s1 = Campaign.quest_accept (spoil ()) "Q0S1" in
check "accepting Q0S1 holds ROTO"
  (state_of s1 "Q0S1" = Some 1 && Campaign.ruin_count "ROTO" = 1);

(match Campaign.run_quest_battle ~rng:seed s1 "Q0S1" with
 | None -> check "Q0S1 stage 1 has a battle" false
 | Some (s2, b1) ->
   check "the first fight runs to a finish" (Battle.log_of b1 <> []);
   check "state 1 stays on the loss (no else entry)" (state_of s2 "Q0S1" = Some 1);
   check "QUEST_BATTLE_NOCAPTURE records no defeat"
     (Campaign.monster_defeats s2 "MOGR" = 0);
   check "and a loss leaves ROTO held"
     (Campaign.ruin_count "ROTO" = 1 && not (Campaign.ruin_is_done "ROTO"));
   let s2w = Campaign.quest_battle_settle s1 "Q0S1" true b1 in
   check "state 1 -> 2 (extracted advance)" (state_of s2w "Q0S1" = Some 2);
   check "the no-capture win still records no defeat"
     (Campaign.monster_defeats s2w "MOGR" = 0);
   check "and OnCompleteAction still released ROTO"
     (Campaign.ruin_count "ROTO" = 0 && Campaign.ruin_is_done "ROTO");
   (match Campaign.run_quest_battle ~rng:seed s2w "Q0S1" with
    | None -> check "stage 2 has the second battle" false
    | Some (s3, b2) ->
      check "the second fight runs too" (Battle.log_of b2 <> []);
      check "state 2 -> stays 2 on the loss as well" (state_of s3 "Q0S1" = Some 2);
      check "still no defeat recorded"
        (Campaign.monster_defeats s3 "MOGR" = 0);
      let s3w = Campaign.quest_battle_settle s2w "Q0S1" true b2 in
      check "state 2 -> 3 (default advance)" (state_of s3w "Q0S1" = Some 3);
      check "stage 3 has no battle of its own"
        (Campaign.run_quest_battle ~rng:seed s3w "Q0S1" = None);
      let s4 = Campaign.quest_turn_in s3w "Q0S1" in
      check "turn-in after the loop completes the quest"
        (state_of s4 "Q0S1" = None
         && List.mem "Q0S1" s4.Campaign.completed_quests
         && s4.Campaign.active_quests = [])));

Campaign.restore_ruin_state [] [];

(* ------------------------------------------------------------------ *)
(* Conversation gate, per-stage identity, companion hooks: Q0Q7        *)
(* ------------------------------------------------------------------ *)

check "stage 1 of Q0Q7 leads with a conversation, so no battle runs"
  (Campaign.run_quest_battle ~rng:seed (active "Q0Q7" 1) "Q0Q7" = None);

let caravan = { (active "Q0Q7" 2) with Campaign.companions = [ "NDKH" ] } in
(match Campaign.run_quest_battle ~rng:seed caravan "Q0Q7" with
 | None -> check "stage 2 of Q0Q7 has a battle" false
 | Some (q2, bw) ->
   check "the stage-2 fight is the Wight (index 0)"
     (bw.Battle.enemy.name = "[MONSTER_MWIG_NAME]");
   check "NDKH's Undead hook opens the log with its hit"
     (match Battle.log_of bw with
      | Battle.Damage (n, 10) :: _ -> n = "[MONSTER_MWIG_NAME]"
      | _ -> false);
   check "the Wight's roster is on the enemy side"
     (spell_ids bw.Battle.enemy_spells = [ "SSPF"; "SCTO" ]);
   check "the caravan fight runs to a finish" (Battle.log_of bw <> []);
   check "losing at stage 2, which has no else entry, keeps the stage"
     (state_of q2 "Q0Q7" = Some 2
      && Campaign.monster_defeats q2 "MWIG" = 0);
   let q3p = Campaign.quest_battle_settle caravan "Q0Q7" true bw in
   check "capturing the caravan counts the Wight's defeat"
     (Campaign.monster_defeats q3p "MWIG" = 1);
   check "state 2 -> 3 (extracted advance)" (state_of q3p "Q0Q7" = Some 3);
   (match Campaign.run_quest_battle ~rng:seed (active "Q0Q7" 3) "Q0Q7" with
    | None -> check "stage 3 of Q0Q7 has a battle" false
    | Some (q4, bd) ->
      check "the Dugog fight is index 2, not 0"
        (bd.Battle.enemy.name = "[MONSTER_MDGG_NAME]");
      check "without the companion the log opens on the turn"
        (match Battle.log_of bd with
         | Battle.TurnStart _ :: _ -> true
         | _ -> false);
      check "the Dugog fight runs too" (Battle.log_of bd <> []);
      check "losing the Dugog fight takes the retry state 4 (else-branch)"
        (state_of q4 "Q0Q7" = Some 4);
      check "QUEST_BATTLE_NOCAPTURE again: Dugog's defeat is not recorded"
        (Campaign.monster_defeats q4 "MDGG" = 0);
      (match Campaign.run_quest_battle ~rng:seed q4 "Q0Q7" with
       | None -> check "stage 4 has the retry battle" false
       | Some (q5, b4) ->
         check "stage 4 runs the same Dugog fight, no capture"
           (b4.Battle.enemy.name = "[MONSTER_MDGG_NAME]");
         check "stage 4 has no else entry: the loss keeps it"
           (state_of q5 "Q0Q7" = Some 4);
         let q5w = Campaign.quest_battle_settle q4 "Q0Q7" true b4 in
         check "a win at stage 4 walks on to 5"
           (state_of q5w "Q0Q7" = Some 5);
         check "and records no Dugog defeat"
           (Campaign.monster_defeats q5w "MDGG" = 0))));

(* ------------------------------------------------------------------ *)
(* Transitions the script wrote by hand                                *)
(* ------------------------------------------------------------------ *)

check "Q1E0's win at stage 1 goes to 3 (first source-order value wins)"
  (state_of (Campaign.quest_battle_complete (active "Q1E0" 1) "Q1E0" true) "Q1E0"
   = Some 3);

check "Q2M4 win at stage 1 -> 3"
  (state_of (Campaign.quest_battle_complete (active "Q2M4" 1) "Q2M4" true) "Q2M4"
   = Some 3);
check "Q2M4 loss at stage 1 -> 2 (retry)"
  (state_of (Campaign.quest_battle_complete (active "Q2M4" 1) "Q2M4" false) "Q2M4"
   = Some 2);
check "Q2M4 win at stage 2 -> 3"
  (state_of (Campaign.quest_battle_complete (active "Q2M4" 2) "Q2M4" true) "Q2M4"
   = Some 3);
check "Q2M4 loss at stage 2 -> 2 (stays)"
  (state_of (Campaign.quest_battle_complete (active "Q2M4" 2) "Q2M4" false) "Q2M4"
   = Some 2);

check "Q3Q2 walks 1 -> 2 -> 3 -> 4 -> 5 on four wins (no entries, +1)"
  (let p = active "Q3Q2" 1 in
   let p = Campaign.quest_battle_complete p "Q3Q2" true in
   let p = Campaign.quest_battle_complete p "Q3Q2" true in
   let p = Campaign.quest_battle_complete p "Q3Q2" true in
   let p = Campaign.quest_battle_complete p "Q3Q2" true in
   state_of p "Q3Q2" = Some 5);
check "and stage 5 has no battle left to run"
  (Campaign.run_quest_battle ~rng:seed (active "Q3Q2" 5) "Q3Q2" = None);
check "a loss with no else entry keeps its stage (Q0I0 stays put)"
  (state_of (Campaign.quest_battle_complete (active "Q0I0" 1) "Q0I0" false) "Q0I0"
   = Some 1);

(* ------------------------------------------------------------------ *)
(* Spell line-ups come from the <Battle> element, both sides           *)
(* ------------------------------------------------------------------ *)

(match Campaign.run_quest_battle ~rng:seed (active "Q0E0" 1) "Q0E0" with
 | None -> check "Q0E0 stage 1 has a battle" false
 | Some (_, be) ->
   check "the hero walks in with the fight's spell, SFSK"
     (List.mem "SFSK" (spell_ids be.Battle.hero_spells));
   check "the enemy is the quest's monster"
     (be.Battle.enemy.name = "[MONSTER_MCTP_NAME]"));

(match Campaign.run_quest_battle ~rng:seed (active "Q3Q2" 2) "Q3Q2" with
 | None -> check "Q3Q2 stage 2 has a battle" false
 | Some (_, b32) ->
   check "stage 2 picks index 1, the second monster"
     (b32.Battle.enemy.name = "[MONSTER_MWIG_NAME]"));

(* ------------------------------------------------------------------ *)
(* Global state cleanup                                                *)
(* ------------------------------------------------------------------ *)

restore initial;
Campaign.restore_ruin_state ruin_counts0 ruin_done0;

if !failures > 0 then begin
  Printf.printf "\n%d failure(s)\n" !failures;
  exit 1
end;
print_endline "all quest battle tests passed"
