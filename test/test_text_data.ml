(* The global TextLibrary, and the names the campaign carries as tags.

   `lib/text_data.ml` is game/Assets/<Language>/*Text.xml - fifteen TextLibrary
   files, 2,630 tags - turned into a lookup. It exists because the per-asset
   extracts do not hold these strings: a quest's own *_Text.xml has its step
   lines but not [QUEST_X_NAME], and the map data stores [CITY_CBAR_NAME]
   rather than "Bartonia". Every name in the campaign is a tag, so the whole
   question is whether the table resolves them.

   The load-bearing assertion is the last group: every name_text and desc_text
   the generated campaign data carries resolves to something other than itself.
   A tag that stops resolving prints as a tag in every future UI, which is
   visible but never fatal - so it is fatal here. *)

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

  if !failures > 0 then begin
    Printf.printf "\n%d failure(s)\n" !failures;
    exit 1
  end;
  print_endline "all text data tests passed"
