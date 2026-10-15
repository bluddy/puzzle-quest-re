(* The auto-save: dirty flag, pump, and the Continue load.

   The original keeps a dirty byte on the hero, set by its state-changing
   events, and a per-frame pump writes Saves\<hero>.pqhero whenever it is up
   (FUN_0044d53c, the [MSG_AUTOSAVE] queue); the port keeps that shape -
   Campaign.dirty, Campaign_autosave.pump - over its own JSON round-trip.
   The load-bearing assertions are the ones that close the loop a player
   would notice: a mutation marks the hero dirty, the pump turns that into
   a file, and a load brings the player, an active quest's stage, the map
   visibility and the ruin registry back exactly - Continue that continues.
   The file is written beside the test binary (the working directory) and
   removed at the end, so a stale save from a previous run cannot answer
   any of this. *)

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

let check_str name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %S, want %S)\n" name got want;
    incr failures
  end

let () =
  (try Sys.remove Campaign_autosave.filename with Sys_error _ -> ());
  let start = Campaign.create_player "Saver" "PWAR" 0 1 in
  let start_city =
    start.Campaign.profession.Campaign_professions.start_city
  in

  (* The flag is the contract: mutators raise it, nothing else clears it
     but a successful save or a load. *)
  Campaign.dirty := false;
  check "a fresh process is not dirty" (not !Campaign.dirty);
  let rich = { start with Campaign.gold = 9999; Campaign.current_city = Some start_city } in
  (match Campaign.buy_item rich (List.hd Campaign_items.items) with
  | Some _ -> ()
  | None -> check "a rich hero buys" false);
  check "a purchase marks the hero dirty" !Campaign.dirty;

  (* A clean pump writes nothing. *)
  Campaign.dirty := false;
  check "a clean pump does not save"
    (not (Campaign_autosave.pump rich));
  check "and leaves no file"
    (not (Sys.file_exists Campaign_autosave.filename));

  (* A dirty pump writes the file and clears the flag. *)
  Campaign.dirty := true;
  check "a dirty pump saves" (Campaign_autosave.pump rich);
  check "the save file is there" (Sys.file_exists Campaign_autosave.filename);
  check "and the flag is down" (not !Campaign.dirty);

  (* Continue: the load restores the player, an active quest's stage, the
     location, and (through apply_save) the live visibility tables. *)
  let quest_city =
    match Campaign_map.cities with
    | c :: _ -> c.Campaign_map.id
    | [] -> start_city
  in
  let victim =
    match Campaign_map.cities with
    | _ :: c2 :: _ -> c2.Campaign_map.id
    | _ -> start_city
  in
  let hero =
    { rich with
      Campaign.name = "Continued";
      Campaign.gold = 4242;
      Campaign.level = 7;
      Campaign.current_city = Some quest_city;
      Campaign.active_quests = [ ("Q0E0", 3) ] }
  in
  Campaign.set_node_visible victim false;
  Campaign.register_ruin "RUIN_TEST";
  Campaign.dirty := false;
  ignore (Campaign_autosave.save hero);
  (* change the world after the save, so the load has something to undo *)
  Campaign.set_node_visible victim true;
  ignore (Campaign.set_ruin_done "RUIN_TEST");
  let hero2 = { hero with Campaign.gold = 1 } in
  let loaded = ref None in
  (match Campaign_autosave.load () with
  | None -> check "the save loads back" false
  | Some (p, quests, _completed, _awards, loc, travel) ->
      loaded := Some p;
      check "the save loads back" true;
      check_str "the name came back" p.Campaign.name "Continued";
      check_int "the gold came back" p.Campaign.gold 4242;
      check_int "the level came back" p.Campaign.level 7;
      check_str "the location came back" loc quest_city;
      check_int "the travel slot is the standing 0" travel 0;
      check "the quest stage came back"
        (List.assoc_opt "Q0E0" p.Campaign.active_quests = Some 3
         && List.assoc_opt "Q0E0" quests = Some 3);
      check "the hidden node is hidden again" (not (Campaign.node_visible victim));
      check "the ruin registry came back"
        (Campaign.ruin_count "RUIN_TEST" = 1
         && not (Campaign.ruin_is_done "RUIN_TEST")));
  check "a load clears the flag" (not !Campaign.dirty);
  check "a clean pump after a load does not rewrite"
    (not (Campaign_autosave.pump hero2));

  (* The mutators a Continue player keeps hitting still mark: a purchase on
     the loaded hero, a revealed node, a recorded defeat. *)
  (match !loaded with
  | None -> check "the loaded hero is around to mutate" false
  | Some p ->
      Campaign.dirty := false;
      (match Campaign.buy_item p (List.hd Campaign_items.items) with
      | Some _ -> ()
      | None -> check "the loaded hero buys" false);
      check "the loaded hero's purchase marks" !Campaign.dirty);
  Campaign.dirty := false;
  Campaign.set_node_visible "NOWHERE" true;
  check "a revealed node marks" !Campaign.dirty;
  Campaign.dirty := false;
  ignore (Campaign.record_defeat hero2 "MGOBLIN");
  check "a recorded defeat marks" !Campaign.dirty;

  (try Sys.remove Campaign_autosave.filename with Sys_error _ -> ());
  if !failures > 0 then begin
    Printf.printf "\n%d failure(s)\n" !failures;
    exit 1
  end;
  print_endline "all campaign autosave tests passed"
