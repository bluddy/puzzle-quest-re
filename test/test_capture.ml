(* The capture side game: charset and row parsing, the no-refill play loop,
   and the campaign state around it - defeat counts, the two [CAPTURE_LISTHELP]
   gates, captives, and the save round-trip.

   The grids under test come from three places: handcrafted rows where the
   expected outcome has to be exact (one swap that empties the board, a grid
   with no legal swap at all), the shipped capture_grid data via
   Campaign.capture_begin, and the shipped help strings themselves, which the
   text tables have to carry verbatim.

   The map tables and the ruin registry are global mutable state (quest accept
   reveals REGB, a save load rewrites the map), so this file snapshots them
   first and restores at the end, like test_campaign does. *)

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

let fresh () = Campaign.create_player "Tester" "PWAR" 0 0

let state_of (p : Campaign.player) qid = List.assoc_opt qid p.Campaign.active_quests

let pos x y = { Board.x = x; Board.y = y }
let swap x1 y1 x2 y2 = { Board.from_pos = pos x1 y1; Board.to_pos = pos x2 y2 }

(* ------------------------------------------------------------------ *)
(* 1. The charset and the row order                                   *)
(* ------------------------------------------------------------------ *)

let () =
  let c = Capture.create [ "GRYBSOX*"; "S........" ] in
  check "G parses as earth"
    (Board.get_gem c.Capture.board (pos 0 0) = Board.Mana Board.Earth);
  check "R parses as fire"
    (Board.get_gem c.Capture.board (pos 1 0) = Board.Mana Board.Fire);
  check "Y parses as air"
    (Board.get_gem c.Capture.board (pos 2 0) = Board.Mana Board.Air);
  check "B parses as water"
    (Board.get_gem c.Capture.board (pos 3 0) = Board.Mana Board.Water);
  check "S parses as a skull"
    (Board.get_gem c.Capture.board (pos 4 0) = Board.Skull);
  check "O parses as gold"
    (Board.get_gem c.Capture.board (pos 5 0) = Board.Gold);
  check "X parses as experience"
    (Board.get_gem c.Capture.board (pos 6 0) = Board.Experience);
  check "the grid wildcard parses as a wildcard"
    (Board.get_gem c.Capture.board (pos 7 0) = Board.Wildcard 2);
  check "row 0 is the top row, row 1 below it"
    (Board.get_gem c.Capture.board (pos 0 0) = Board.Mana Board.Earth
     && Board.get_gem c.Capture.board (pos 0 1) = Board.Skull);
  check "cells past the last char of a short row are empty"
    (Board.get_gem c.Capture.board (pos 4 1) = Board.Empty
     && Board.get_gem c.Capture.board (pos 0 7) = Board.Empty);
  check "the dash parses as empty"
    (Board.get_gem (Capture.of_grid [ "--------" ]) (pos 0 0) = Board.Empty);
  check_int "the grid carries nine gems" (Capture.gems_left c.Capture.board) 9

(* ------------------------------------------------------------------ *)
(* 2. The play loop: no refill, win, lose                             *)
(* ------------------------------------------------------------------ *)

(* Two rows that only the middle swap turns into a triple each: R,G,R over
   G,R,G with (1,0)-(1,1) exchanged gives RRR over GGG - every gem on the
   board is in a match, so if anything refills, the grid cannot read as
   cleared. *)
let win_rows = [ "RGR....."; "GRG....." ]
let winning = swap 1 0 1 1

let () =
  let t0 = Capture.create win_rows in
  check "the handcrafted grid starts in play"
    (t0.Capture.status = Capture.Playing);
  check_int "six gems to start" (Capture.gems_left t0.Capture.board) 6;
  check "the winning swap is legal"
    (Board.is_valid_swap t0.Capture.board (pos 1 0) (pos 1 1));
  (match Capture.play t0 winning with
   | None -> check "the winning swap plays" false
   | Some t1 ->
     check "clearing every gem wins the attempt"
       (t1.Capture.status = Capture.Won);
     check "nothing refills the emptied grid"
       (Capture.gems_left t1.Capture.board = 0);
     check "a finished attempt rejects further swaps"
       (Capture.play t1 winning = None));
  check "a swap that makes no match is rejected"
    (Capture.play t0 (swap 0 0 1 0) = None);

  (* RGRG: every adjacent swap leaves a pair, never a run. *)
  let l0 = Capture.create [ "RGRG...." ] in
  check "a grid with no legal swap reads as lost"
    (l0.Capture.status = Capture.Lost);
  check "a swap on a lost attempt is rejected"
    (Capture.play l0 winning = None)

(* ------------------------------------------------------------------ *)
(* 3. Gravity without refill                                          *)
(* ------------------------------------------------------------------ *)

(* The same two winning rows over a row of golds: the match clears the top,
   the golds drop, and no gem takes their place. *)
let () =
  let g0 = Capture.create [ "RGR....."; "GRG....."; "O.O....." ] in
  check_int "eight gems to start" (Capture.gems_left g0.Capture.board) 8;
  match Capture.play g0 winning with
  | None -> check "the gravity grid plays" false
  | Some g1 ->
    check_int "no refill: only the two golds remain"
      (Capture.gems_left g1.Capture.board) 2;
    check "the golds dropped to the bottom row"
      (Board.get_gem g1.Capture.board (pos 0 7) = Board.Gold
       && Board.get_gem g1.Capture.board (pos 2 7) = Board.Gold);
    check "the cleared cells stayed empty"
      (Board.get_gem g1.Capture.board (pos 0 0) = Board.Empty
       && Board.get_gem g1.Capture.board (pos 1 0) = Board.Empty
       && Board.get_gem g1.Capture.board (pos 2 0) = Board.Empty);
    check "with no move left the attempt is lost"
      (g1.Capture.status = Capture.Lost)

(* ------------------------------------------------------------------ *)
(* 4. The help strings ship verbatim                                  *)
(* ------------------------------------------------------------------ *)

let () =
  check "the capture goal ships in the text tables"
    (Text_data.text "[CAPTURE_HELP]"
     = "To capture this creature you must clear the grid of gems, matching them as if you were in a normal battle.");
  check "the dungeon prerequisite ships"
    (Text_data.text "[CAPTURE_LISTHELP1]" = "* Built a Dungeon");
  check "the defeat-count prerequisite ships"
    (Text_data.text "[CAPTURE_LISTHELP2]" = "* Defeated that enemy 3+ times");
  check "the failure message ships"
    (Text_data.text "[CAPTURE_FAIL]"
     = "You have failed to capture this enemy, but you may try again later.")

(* ------------------------------------------------------------------ *)
(* 5. Defeats, the two gates, and captives                            *)
(* ------------------------------------------------------------------ *)

let ruin_counts0 = Campaign.ruin_counts_snapshot ()
let ruin_done0 = Campaign.ruin_done_snapshot ()

let () =
  let e0 = fresh () in
  check "no defeats yet: not eligible"
    (not (Campaign.capture_eligible e0 "MTRO"));
  let e1 =
    List.fold_left (fun p _ -> Campaign.record_defeat p "MTRO") e0 [ 1; 2; 3 ]
  in
  check_int "three defeats counted" (Campaign.monster_defeats e1 "MTRO") 3;
  check "three defeats: eligible"
    (Campaign.capture_eligible e1 "MTRO");
  check "an unknown monster counts zero, not an exception"
    (Campaign.monster_defeats e1 "ZZZZ" = 0);
  let e2 = { e1 with Campaign.dungeon_built = false } in
  check "without a built dungeon the defeats do not qualify"
    (not (Campaign.capture_eligible e2 "MTRO"));

  (* The quest path: Q0I0 (level 7 + Q0Q4) battles MTRO. *)
  Campaign.restore_ruin_state [] [];
  let q0i0 () =
    { (fresh ()) with Campaign.level = 7; Campaign.completed_quests = [ "Q0Q4" ] }
  in
  let a1 = Campaign.quest_accept (q0i0 ()) "Q0I0" in
  check "the quest is active"
    (state_of a1 "Q0I0" = Some 1
     && Campaign.monster_defeats a1 "MTRO" = 0);
  let lost = Campaign.quest_battle_complete a1 "Q0I0" false in
  check_int "a failed quest battle records no defeat"
    (Campaign.monster_defeats lost "MTRO") 0;
  let won = Campaign.quest_battle_complete a1 "Q0I0" true in
  check_int "a won quest battle records one defeat"
    (Campaign.monster_defeats won "MTRO") 1;

  (* The road path: a shipped encounter whose sprite resolves to a monster. *)
  let road_enc =
    List.find
      (fun (e : Campaign_encounters.encounter) ->
        try
          ignore (Campaign_monsters.monster_by_sprite e.Campaign_encounters.sprite);
          true
        with Not_found -> false)
      Campaign_encounters.encounters
  in
  let road_mid =
    (Campaign_monsters.monster_by_sprite road_enc.Campaign_encounters.sprite)
      .Campaign_monsters.id
  in
  let hero = Combat.make_combatant ~cunning:5 ~max_life:30 ~life:30 1 "Hero" in
  let enemy = Combat.make_combatant ~cunning:5 ~max_life:10 ~life:10 2 "Enemy" in
  let b = Battle.create (Board.create_board []) hero enemy in
  let base = fresh () in
  let p_loss, r_loss = Campaign.process_battle_result base road_enc b in
  check "a lost road battle records no defeat"
    (not r_loss.Campaign.player_won
     && Campaign.monster_defeats p_loss road_mid = 0);
  enemy.Combat.is_dead <- true;
  let p_win, r_win = Campaign.process_battle_result base road_enc b in
  check "a won road battle records one defeat"
    (r_win.Campaign.player_won
     && Campaign.monster_defeats p_win road_mid = 1);

  (* Begin and finish: an all-empty shipped grid is already cleared, a
     populated one starts in play, and only a win adds the captive. *)
  check "an all-empty shipped grid reads as won at once"
    ((Campaign.capture_begin "MRAX").Capture.status = Capture.Won);
  check "a populated shipped grid starts in play"
    ((Campaign.capture_begin "MTRO").Capture.status = Capture.Playing);
  let eligible = List.fold_left (fun p _ -> Campaign.record_defeat p "MRAX")
      (List.fold_left (fun p _ -> Campaign.record_defeat p "MTRO") (fresh ()) [ 1; 2; 3 ])
      [ 1; 2; 3 ]
  in
  check "the captured monster is eligible"
    (Campaign.capture_eligible eligible "MRAX");
  let got = Campaign.capture_finish eligible "MRAX"
      (Campaign.capture_begin "MRAX") in
  check "a won attempt adds the captive"
    (got.Campaign.captives = [ "MRAX" ]);
  let again = Campaign.capture_finish got "MRAX"
      (Campaign.capture_begin "MRAX") in
  check "recapturing does not duplicate the captive"
    (again.Campaign.captives = [ "MRAX" ]);
  let lost_attempt =
    Campaign.capture_finish got "MTRO" (Capture.create [ "RGRG...." ])
  in
  check "a lost attempt adds no captive"
    (lost_attempt.Campaign.captives = [ "MRAX" ])

(* ------------------------------------------------------------------ *)
(* 6. Save / load round-trip, and the old-save defaults               *)
(* ------------------------------------------------------------------ *)

let () =
  let path = Filename.temp_file "pq_capture_test" ".json" in
  let sp =
    { (fresh ()) with
      Campaign.dungeon_built = false;
      Campaign.monster_defeats = [ ("MTRO", 4) ];
      Campaign.captives = [ "MRAX" ] }
  in
  let save = Campaign_save.create_save_data sp [] "CGAL" 0 in
  Campaign_save.save_to_file path save;
  let loaded = Campaign_save.load_from_file path in
  let p2, _quests, _completed, _awards, _loc, _travel =
    Campaign_save.apply_save loaded in
  Sys.remove path;

  check "load restores dungeon_built" (not p2.Campaign.dungeon_built);
  check_int "load restores the defeat counts"
    (Campaign.monster_defeats p2 "MTRO") 4;
  check "load restores the captives" (p2.Campaign.captives = [ "MRAX" ]);

  (* A save written before the capture state existed: strip the three fields
     and prove they come back as the defaults. *)
  let stripped =
    match Campaign_save.save_campaign_to_json save with
    | `Assoc fs ->
      `Assoc
        (List.map
           (fun (k, v) ->
             if k = "player" then
               (k,
                match v with
                | `Assoc pfs ->
                  `Assoc
                    (List.filter
                       (fun (n, _) ->
                         n <> "dungeon_built" && n <> "monster_defeats"
                         && n <> "captives")
                       pfs)
                | other -> other)
             else (k, v))
           fs)
    | other -> other
  in
  let old = Campaign_save.save_campaign_of_json stripped in
  let p3, _, _, _, _, _ = Campaign_save.apply_save old in
  check "an old save loads dungeon_built as the default true"
    p3.Campaign.dungeon_built;
  check "an old save loads no defeats"
    (Campaign.monster_defeats p3 "MTRO" = 0);
  check "an old save loads no captives" (p3.Campaign.captives = [])

(* ------------------------------------------------------------------ *)
(* 7. Greedy play over every shipped grid                             *)
(* ------------------------------------------------------------------ *)

let () =
  let outcome (m : Campaign_monsters.monster) =
    ( m.Campaign_monsters.id,
      (Capture.auto_play (Campaign.capture_begin m.Campaign_monsters.id))
        .Capture.status )
  in
  let results = List.map outcome Campaign_monsters.monsters in
  check_int "every shipped grid was tried" (List.length results) 60;
  check "greedy play always reaches a verdict"
    (List.for_all
       (fun (_, s) -> s = Capture.Won || s = Capture.Lost)
       results);
  check "at least one shipped grid auto-wins"
    (List.exists (fun (_, s) -> s = Capture.Won) results);

(* Back to where the process started. *)
Campaign.restore_ruin_state ruin_counts0 ruin_done0;
restore initial;
check "the registry is left as it was found"
  (Campaign.ruin_counts_snapshot () = ruin_counts0
   && Campaign.ruin_done_snapshot () = ruin_done0);
check "the map is left as it was found"
  (take_snapshot () = initial)

let () =
  if !failures > 0 then begin
    Printf.printf "\n%d failure(s)\n" !failures;
    exit 1
  end;
  print_endline "all capture tests passed"
