(* The global TextLibrary, and the names the campaign carries as tags.

   `lib/text_data.ml` is the language front over five generated tables - one
   per shipped language, each game/Assets/<Language>/*Text.xml plus the
   Conversations and Quests subdirectories, 10,448 identical tags - turned
   into lookups. It exists because the per-asset extracts do not hold these
   strings: a quest's own *_Text.xml has its step lines but not
   [QUEST_X_NAME], and the map data stores [CITY_CBAR_NAME] rather than
   "Bartonia". Every name in the campaign is a tag, so the whole question is
   whether the table resolves them - and, since the switch is live, whether
   each language's table answers the same tags.

   The load-bearing assertion is the every-name group: every name_text and
   desc_text the generated campaign data carries resolves to something other
   than itself. A tag that stops resolving prints as a tag in every future
   UI, which is visible but never fatal - so it is fatal here. The language
   group after it pins the recovered id order, the per-language routing
   (interface strings and quest step lines alike) and the existence-gate
   fallback for the five ids this build ships no table for. *)

open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_str name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %S, want %S)\n" name got want;
    incr failures
  end

let check_eq_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

(* A tag resolves when the table gives back something other than the tag. *)
let resolves tag = Text_data.text tag <> tag

let () =
  (* The strings themselves, from the game's own tables. *)
  check_str "quest title resolves"
    (Text_data.text "[QUEST_Q0T0_NAME]") "Family Reunion";
  check_str "quest description resolves"
    (Text_data.text "[QUEST_Q0T0_DESC]")
    "Your father has requested your presence in Siria.  You must travel there and meet him.";
  check_str "city name resolves"
    (Text_data.text "[CITY_CBAR_NAME]") "Bartonia";
  check_str "item name resolves"
    (Text_data.text "[ITEM_ILSW_NAME]") "Longsword";
  check_str "profession name resolves"
    (Text_data.text "[PROF_PWAR_NAME]") "Warrior";
  check "monster name resolves"
    (resolves "[MONSTER_MARB_NAME]");

  (* An unknown tag reads as itself rather than raising, so a string missing
     from the tables is visible in the UI instead of crashing it. *)
  check_str "unknown tag returns itself"
    (Text_data.text "[NO_SUCH_TAG_HERE]") "[NO_SUCH_TAG_HERE]";
  check "unknown tag is absent from lookup"
    (Text_data.lookup "[NO_SUCH_TAG_HERE]" = None);
  check "known tag is present in lookup"
    (Text_data.lookup "[CITY_CBAR_NAME]" = Some "Bartonia");

  (* Every name the campaign data carries resolves. *)
  let unresolved = ref [] in
  let need tag = if not (resolves tag) then unresolved := tag :: !unresolved in
  let count = ref 0 in
  let need_all tags = List.iter (fun t -> incr count; need t) tags in

  List.iter (fun (q : Campaign_quests.quest) -> need_all [ q.name_text; q.desc_text ])
    Campaign_quests.quests;
  List.iter (fun (c : Campaign_map.city) -> need_all [ c.Campaign_map.name_text; c.Campaign_map.desc_text ])
    Campaign_map.cities;
  List.iter (fun (w : Campaign_map.waypoint) -> need_all [ w.Campaign_map.name_text; w.Campaign_map.desc_text ])
    Campaign_map.waypoints;
  List.iter (fun (r : Campaign_map.ruin) -> need_all [ r.Campaign_map.name_text; r.Campaign_map.desc_text ])
    Campaign_map.ruins;
  List.iter (fun (i : Campaign_items.item) -> need_all [ i.Campaign_items.name_text ])
    Campaign_items.items;
  List.iter (fun (m : Campaign_monsters.monster) -> need_all [ m.Campaign_monsters.name_text ])
    Campaign_monsters.monsters;
  List.iter (fun (p : Campaign_professions.profession) ->
      need_all [ p.Campaign_professions.name_text; p.Campaign_professions.desc_text ])
    Campaign_professions.professions;

  check (Printf.sprintf "every campaign name resolves (%d tags)" !count)
    (!unresolved = []);
  List.iter (fun t -> Printf.printf "     unresolved: %s\n" t)
    (List.sort compare !unresolved);

  (* And the accessors the UI calls route through the table. *)
  let q0t0 = Campaign_quests.quest_by_id "Q0T0" in
  check_str "quest_name goes through the table"
    (Campaign_quests.quest_name q0t0) "Family Reunion";
  check_str "quest_desc goes through the table"
    (Campaign_quests.quest_desc q0t0) (Text_data.text q0t0.Campaign_quests.desc_text);

  (* The language switch: five shipped tables, identical tag sets, and every
     consumer routing through the current one. The id order is the exe's own
     recovered table (Spanish is 3, Italian 4), and set_language mirrors its
     existence gate - an id with no table in this build falls back to
     English rather than half-switching. *)
  let q0e0 = Campaign_quests.quest_by_id "Q0E0" in
  let settings_of () = Text_data.text "[SETTINGS]" in
  let tag_count () = List.length (Text_data.entries ()) in
  check_str "name table is the recovered id order"
    (String.concat ";" (Array.to_list Text_data.names))
    "English;French;German;Spanish;Italian";
  check_eq_int "English boots as id 0" !Text_data.language 0;
  check_eq_int "every language carries the same tag set" (tag_count ()) 10448;

  Text_data.set_language 1;
  check_eq_int "French is id 1" !Text_data.language 1;
  check_str "French interface string routes" (settings_of ()) "Paramètres";
  check_str "French quest step routes through quest_text"
    (Campaign_quests.quest_text q0e0 "[QUEST_Q0E0_ACTION]")
    "Détruire les catapultes";
  check_eq_int "French carries the same tag set" (tag_count ()) 10448;

  Text_data.set_language 2;
  check_str "German interface string routes" (settings_of ()) "Einstellungen";
  check_str "German quest step routes"
    (Campaign_quests.quest_text q0e0 "[QUEST_Q0E0_ACTION]")
    "Zerstöre die Katapulte";

  Text_data.set_language 3;
  check_str "Spanish is id 3, before Italian" (settings_of ())
    "Configuración";
  check_str "Spanish quest step routes"
    (Campaign_quests.quest_text q0e0 "[QUEST_Q0E0_ACTION]")
    "Destruye las catapultas";

  Text_data.set_language 4;
  check_str "Italian is id 4" (settings_of ()) "Impostazioni";
  check_str "Italian quest step routes"
    (Campaign_quests.quest_text q0e0 "[QUEST_Q0E0_ACTION]")
    "Distruggi le Catapulte";

  (* The existence gate: ids 5..9 (Polish..Taiwanese) know no table in this
     build, so the setter falls back to English - the original skips their
     GameText.xml the same way. *)
  Text_data.set_language 7;
  check_eq_int "an unshipped id falls back to English" !Text_data.language 0;
  check_str "and the text is English again" (settings_of ()) "Settings";
  Text_data.set_language (-1);
  check_eq_int "a negative id clamps to English" !Text_data.language 0;

  (* Back on English, the quest path is the baked value again (q.texts
     first, the table behind it) and nothing above leaked. *)
  check_str "English quest step unchanged after the tour"
    (Campaign_quests.quest_text q0e0 "[QUEST_Q0E0_ACTION]")
    "Destroy the Catapults";
  check_str "English quest_name unchanged after the tour"
    (Campaign_quests.quest_name q0t0) "Family Reunion";

  if !failures > 0 then begin
    Printf.printf "\n%d failure(s)\n" !failures;
    exit 1
  end;
  print_endline "all text data tests passed"
