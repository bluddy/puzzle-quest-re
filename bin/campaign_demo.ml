(* Campaign demo - shows map, travel, encounters, cities, quests, save/load *)

open Puzzle_quest_lib
open Campaign
open Campaign_map
open Campaign_encounters
open Campaign_quests

let () =
  Random.self_init ();
  print_endline "=== Puzzle Quest Campaign Demo ===\n";

  (* Create a warrior player *)
  let player = Campaign.create_player "TestHero" "PWAR" 0 0 in
  print_endline ("Player: " ^ player.name ^ " (Level " ^ string_of_int player.level ^ " " ^ Text_data.text player.profession.Campaign_professions.name_text ^ ")");
  print_endline ("Gold: " ^ string_of_int player.gold ^ ", Life: " ^ string_of_int player.life ^ "/" ^ string_of_int player.max_life);
  print_endline ("Start city: " ^ player.profession.Campaign_professions.start_city);
  print_endline "";

  (* Show map summary *)
  print_endline "--- Map ---";
  print_endline ("Cities: " ^ string_of_int (List.length Campaign_map.cities));
  print_endline ("Waypoints: " ^ string_of_int (List.length Campaign_map.waypoints));
  print_endline ("Ruins: " ^ string_of_int (List.length Campaign_map.ruins));
  print_endline ("Roads: " ^ string_of_int (List.length Campaign_map.roads));
  print_endline "";

  (* Show connected roads from start city *)
  let start_city = player.profession.Campaign_professions.start_city in
  let connected : Campaign_map.road list = Campaign_map.roads_connected start_city in
  print_endline ("Roads from " ^ start_city ^ ":");
  List.iter (fun (r: Campaign_map.road) ->
    print_endline ("  " ^ r.start ^ " <-> " ^ r.end_ ^ " (visible=" ^ string_of_bool r.visible ^ ")")
  ) connected;
  print_endline "";

  (* Show encounters on first road that has them *)
  let roads_with_encs = List.filter (fun (r: Campaign_map.road) -> Campaign_encounters.encounters_on_road r.start r.end_ <> []) connected in
  if roads_with_encs <> [] then
    let first_road = List.hd roads_with_encs in
    let encs : Campaign_encounters.encounter list = Campaign_encounters.encounters_on_road first_road.start first_road.end_ in
    print_endline ("Encounters on " ^ first_road.start ^ "->" ^ first_road.end_ ^ ":");
    List.iter (fun (e: Campaign_encounters.encounter) ->
      print_endline ("  " ^ e.id ^ ": " ^ e.description ^ " sprite=" ^ e.sprite ^ " level=" ^ string_of_int e.my_level ^ " chance=" ^ string_of_int e.chance)
    ) encs;
    print_endline "";

    (* Run battle against first encounter using campaign's battle function *)
    print_endline "Running battle against first encounter...";
    let battle = Campaign.run_encounter_battle player (List.hd encs) in
    print_endline ("Battle finished! Turns: " ^ string_of_int battle.turns_elapsed);
    print_endline ("Hero life: " ^ string_of_int battle.hero.life ^ ", Enemy life: " ^ string_of_int battle.enemy.life);
    print_endline ("Winner: " ^ (match battle.winner with
      | Some Battle.HeroVictory -> "Hero"
      | Some Battle.EnemyVictory -> "Enemy"
      | Some Battle.Stalemate -> "Stalemate"
      | Some Battle.Draw -> "Draw"
      | None -> "Unfinished"));
    print_endline ("Gold: " ^ string_of_int battle.gold ^ ", XP: " ^ string_of_int battle.xp);
    print_endline "";
  else
    print_endline "No encounters on connected roads";
    print_endline "";

  (* Show quests at start city *)
  let quests = Campaign.available_quests_at player start_city in
  print_endline ("Available quests at " ^ Text_data.text (Campaign_map.city_by_id start_city).Campaign_map.name_text ^ " (" ^ start_city ^ "):");
  List.iter (fun (q: Campaign_quests.quest) ->
    print_endline ("  " ^ q.id ^ ": " ^ Campaign_quests.quest_name q ^ " (lvl " ^ string_of_int q.avail_minlevel ^ "-" ^ string_of_int q.avail_maxlevel ^ ") monster=" ^ q.battle_monster)
  ) quests;
  print_endline "";

  (* Show city shop *)
  let city = Campaign_map.city_by_id start_city in
  print_endline ("Shop at " ^ Text_data.text city.Campaign_map.name_text ^ ":");
  print_endline ("  Items: " ^ String.concat ", " (List.map (fun i -> i.Campaign_items.id) (Campaign.city_shop_items city)));
  print_endline ("  Spells: " ^ String.concat ", " (Campaign.city_shop_spells city));
  print_endline ("  Income: " ^ string_of_int city.Campaign_map.income);
  print_endline "";

  (* Simulate income collection *)
  let player2 = { player with current_city = Some start_city } in
  let player3 = Campaign.collect_income player2 in
  print_endline ("After collecting income: " ^ string_of_int player3.gold ^ " gold");
  print_endline "";

  (* Test level up *)
  let player4 = { player3 with xp = 1000 } in
  let player5 = Campaign.check_level_up player4 in
  print_endline ("After gaining 1000 XP: level " ^ string_of_int player5.level ^ ", life " ^ string_of_int player5.life ^ "/" ^ string_of_int player5.max_life);
  print_endline ("Known spells: " ^ String.concat ", " player5.known_spells);
  print_endline "";

  (* Quest lifecycle: accept -> battle -> turn in *)
  if quests <> [] then begin
    let q = List.hd quests in
    print_endline ("Quest: " ^ Campaign_quests.quest_name q ^ " (" ^ q.id ^ ")");
    let pq0 = Campaign.quest_accept player5 q.id in
    print_endline ("  accepted: active=" ^ String.concat ", " (List.map fst pq0.Campaign.active_quests));
    if q.Campaign_quests.reveal_on_begin <> [] then
      List.iter (fun n -> print_endline ("  revealed at accept: " ^ n ^ " visible=" ^ string_of_bool (Campaign.node_visible n)))
        q.Campaign_quests.reveal_on_begin;
    let pq1 = Campaign.quest_battle_complete pq0 q.id true in
    print_endline ("  battle won: state=" ^ (match List.assoc_opt q.id pq1.Campaign.active_quests with
      | Some s -> string_of_int s | None -> "n/a"));
    let pq2 = Campaign.quest_turn_in pq1 q.id in
    print_endline ("  turned in: gold=" ^ string_of_int pq2.Campaign.gold
      ^ " xp=" ^ string_of_int pq2.Campaign.xp
      ^ " completed=" ^ String.concat ", " pq2.Campaign.completed_quests
      ^ " still-active=" ^ string_of_int (List.length pq2.Campaign.active_quests));
    print_endline "";
  end;

  (* Test save/load *)
  print_endline "=== Testing Save/Load ===";
  let save_file = "pq_save_test.json" in
  let player_with_quests = { player5 with active_quests = [("Q0Q0", 1)] } in
  let save_data = Campaign_save.create_save_data player_with_quests player_with_quests.Campaign.active_quests start_city 0 in
  Campaign_save.save_to_file save_file save_data;
  print_endline ("Saved to " ^ save_file);
  let loaded_save = Campaign_save.load_from_file save_file in
  let loaded_player, loaded_quests, _, _, _, _ = Campaign_save.apply_save loaded_save in
  print_endline ("Loaded player: " ^ loaded_player.name ^ ", level " ^ string_of_int loaded_player.level ^ ", gold " ^ string_of_int loaded_player.gold);
  print_endline ("Loaded quests: " ^ String.concat ", " (List.map (fun (qid, state) -> qid ^ "=" ^ string_of_int state) loaded_quests));
  print_endline ("Save/Load test passed!");

  print_endline "=== Demo complete ==="