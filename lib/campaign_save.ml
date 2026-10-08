(* Campaign save/load — clean JSON format, minimal imports to avoid type confusion *)

[@@@ocaml.warning "-32-33"]

open Yojson.Basic.Util

(* ------------------------------------------------------------------ *)
(* Save data structures - independent of campaign types *)
(* ------------------------------------------------------------------ *)

type save_equipment = {
  weapon: string option;
  armor: string option;
  helm: string option;
  gauntlets: string option;
  ring1: string option;
  ring2: string option;
  mount: string option;
  banner: string option;
  companion: string option;
}

type save_player = {
  name: string;
  profession_id: string;
  sex: int;
  age: int;
  level: int;
  xp: int;
  gold: int;
  life: int;
  max_life: int;
  skills: Campaign_types.skill_affinities;
  equipment: save_equipment;
  inventory: string list;
  known_spells: string list;
  active_quests: (string * int) list;
  completed_quests: string list;
  companions: string list;
  awards: string list;
  current_city: string option;
}

type save_quest_state = {
  quest_id: string;
  state: int;
  vars: (string * string) list;
}

type save_map_visibility = {
  visible_cities: string list;
  visible_waypoints: string list;
  visible_ruins: string list;
  visible_roads: (string * string) list;
}

type save_campaign = {
  player: save_player;
  quests: save_quest_state list;
  map_visibility: save_map_visibility;
  ruin_counts: (string * int) list;
  ruin_done: string list;
  current_location: string;
  travel_state: int;
}

(* ------------------------------------------------------------------ *)
(* JSON serialization *)
(* ------------------------------------------------------------------ *)

let skill_affinities_to_json (s: Campaign_types.skill_affinities) =
  `Assoc [
    "earth", `Int s.earth; "fire", `Int s.fire; "air", `Int s.air;
    "water", `Int s.water; "battle", `Int s.battle;
    "cunning", `Int s.cunning; "morale", `Int s.morale;
  ]

let save_equipment_to_json e =
  `Assoc [
    "weapon", (match e.weapon with Some s -> `String s | None -> `Null);
    "armor", (match e.armor with Some s -> `String s | None -> `Null);
    "helm", (match e.helm with Some s -> `String s | None -> `Null);
    "gauntlets", (match e.gauntlets with Some s -> `String s | None -> `Null);
    "ring1", (match e.ring1 with Some s -> `String s | None -> `Null);
    "ring2", (match e.ring2 with Some s -> `String s | None -> `Null);
    "mount", (match e.mount with Some s -> `String s | None -> `Null);
    "banner", (match e.banner with Some s -> `String s | None -> `Null);
    "companion", (match e.companion with Some s -> `String s | None -> `Null);
  ]

let save_player_to_json (p: save_player) =
  `Assoc [
    "name", `String p.name;
    "profession_id", `String p.profession_id;
    "sex", `Int p.sex; "age", `Int p.age;
    "level", `Int p.level; "xp", `Int p.xp;
    "gold", `Int p.gold; "life", `Int p.life; "max_life", `Int p.max_life;
    "skills", skill_affinities_to_json p.skills;
    "equipment", save_equipment_to_json p.equipment;
    "inventory", `List (List.map (fun s -> `String s) p.inventory);
    "known_spells", `List (List.map (fun s -> `String s) p.known_spells);
    "active_quests", `List (List.map (fun (qid, state) -> `Assoc [("quest_id", `String qid); ("state", `Int state)]) p.active_quests);
    "completed_quests", `List (List.map (fun s -> `String s) p.completed_quests);
    "companions", `List (List.map (fun s -> `String s) p.companions);
    "awards", `List (List.map (fun s -> `String s) p.awards);
    "current_city", (match p.current_city with Some s -> `String s | None -> `Null);
  ]

let save_quest_state_to_json q =
  `Assoc [
    "quest_id", `String q.quest_id;
    "state", `Int q.state;
    "vars", `List (List.map (fun (k, v) -> `Assoc [("key", `String k); ("value", `String v)]) q.vars);
  ]

let save_map_visibility_to_json m =
  `Assoc [
    "visible_cities", `List (List.map (fun s -> `String s) m.visible_cities);
    "visible_waypoints", `List (List.map (fun s -> `String s) m.visible_waypoints);
    "visible_ruins", `List (List.map (fun s -> `String s) m.visible_ruins);
    "visible_roads", `List (List.map (fun (a, b) -> `Assoc [("from", `String a); ("to", `String b)]) m.visible_roads);
  ]

let save_campaign_to_json s =
  `Assoc [
    "player", save_player_to_json s.player;
    "quests", `List (List.map save_quest_state_to_json s.quests);
    "map_visibility", save_map_visibility_to_json s.map_visibility;
    "ruin_counts", `List (List.map (fun (id, n) -> `Assoc [("id", `String id); ("count", `Int n)]) s.ruin_counts);
    "ruin_done", `List (List.map (fun id -> `String id) s.ruin_done);
    "current_location", `String s.current_location;
    "travel_state", `Int s.travel_state;
  ]

(* ------------------------------------------------------------------ *)
(* JSON deserialization *)
(* ------------------------------------------------------------------ *)

let skill_affinities_of_json json : Campaign_types.skill_affinities =
  { earth = json |> member "earth" |> to_int;
    fire = json |> member "fire" |> to_int;
    air = json |> member "air" |> to_int;
    water = json |> member "water" |> to_int;
    battle = json |> member "battle" |> to_int;
    cunning = json |> member "cunning" |> to_int;
    morale = json |> member "morale" |> to_int; }

let save_equipment_of_json json =
  let opt_member name = try Some (json |> member name |> to_string) with _ -> None in
  { weapon = opt_member "weapon"; armor = opt_member "armor"; helm = opt_member "helm";
    gauntlets = opt_member "gauntlets"; ring1 = opt_member "ring1"; ring2 = opt_member "ring2";
    mount = opt_member "mount"; banner = opt_member "banner"; companion = opt_member "companion"; }

let save_player_of_json json =
  { name = json |> member "name" |> to_string;
    profession_id = json |> member "profession_id" |> to_string;
    sex = json |> member "sex" |> to_int; age = json |> member "age" |> to_int;
    level = json |> member "level" |> to_int; xp = json |> member "xp" |> to_int;
    gold = json |> member "gold" |> to_int; life = json |> member "life" |> to_int;
    max_life = json |> member "max_life" |> to_int;
    skills = skill_affinities_of_json (json |> member "skills");
    equipment = save_equipment_of_json (json |> member "equipment");
    inventory = (json |> member "inventory" |> to_list) |> List.map to_string;
    known_spells = (json |> member "known_spells" |> to_list) |> List.map to_string;
    active_quests = (json |> member "active_quests" |> to_list) |> List.map (fun v -> (v |> member "quest_id" |> to_string, v |> member "state" |> to_int));
    completed_quests = (json |> member "completed_quests" |> to_list) |> List.map to_string;
    companions = (json |> member "companions" |> to_list) |> List.map to_string;
    awards = (json |> member "awards" |> to_list) |> List.map to_string;
    current_city = match json |> member "current_city" with `Null -> None | `String s -> Some s | _ -> None; }

let save_quest_state_of_json json =
  { quest_id = json |> member "quest_id" |> to_string;
    state = json |> member "state" |> to_int;
    vars = (json |> member "vars" |> to_list) |> List.map (fun v -> (v |> member "key" |> to_string, v |> member "value" |> to_string)); }

let save_map_visibility_of_json json =
  { visible_cities = (json |> member "visible_cities" |> to_list) |> List.map to_string;
    visible_waypoints = (json |> member "visible_waypoints" |> to_list) |> List.map to_string;
    visible_ruins = (json |> member "visible_ruins" |> to_list) |> List.map to_string;
    visible_roads = (json |> member "visible_roads" |> to_list) |> List.map (fun v -> (v |> member "from" |> to_string, v |> member "to" |> to_string)); }

let save_campaign_of_json json =
  { player = save_player_of_json (json |> member "player");
    quests = (json |> member "quests" |> to_list) |> List.map (fun v -> { quest_id = v |> member "quest_id" |> to_string; state = v |> member "state" |> to_int; vars = (v |> member "vars" |> to_list) |> List.map (fun v -> (v |> member "key" |> to_string, v |> member "value" |> to_string)) });
    map_visibility = (let m = json |> member "map_visibility" in { visible_cities = (m |> member "visible_cities" |> to_list) |> List.map to_string; visible_waypoints = (m |> member "visible_waypoints" |> to_list) |> List.map to_string; visible_ruins = (m |> member "visible_ruins" |> to_list) |> List.map to_string; visible_roads = (m |> member "visible_roads" |> to_list) |> List.map (fun v -> (v |> member "from" |> to_string, v |> member "to" |> to_string)) });
    (* saves written before the ruin registry existed load as empty *)
    ruin_counts = (match json |> member "ruin_counts" with
      | `Null -> []
      | j -> j |> to_list |> List.map (fun v -> (v |> member "id" |> to_string, v |> member "count" |> to_int)));
    ruin_done = (match json |> member "ruin_done" with
      | `Null -> []
      | j -> j |> to_list |> List.map to_string);
    current_location = json |> member "current_location" |> to_string;
    travel_state = json |> member "travel_state" |> to_int; }

(* ------------------------------------------------------------------ *)
(* Public API *)
(* ------------------------------------------------------------------ *)

[@@ocaml.warning "-32"]
let save_to_file filename save =
  let json = save_campaign_to_json save in
  let out = open_out_bin filename in
  output_string out (Yojson.Basic.pretty_to_string json);
  output_string out "\n";
  close_out out

let load_from_file filename =
  let ic = open_in filename in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  let json = Yojson.Basic.from_string (Bytes.to_string buf) in
  save_campaign_of_json json

(* ------------------------------------------------------------------ *)
(* Conversion functions - use fully qualified module paths *)
(* ------------------------------------------------------------------ *)

module SaveConvert = struct
  open Campaign
  open Campaign_items
  open Campaign_types

  let skill_affinities_to_save (s: Campaign_types.skill_affinities) : skill_affinities =
    { earth = s.earth; fire = s.fire; air = s.air; water = s.water;
      battle = s.battle; cunning = s.cunning; morale = s.morale }

  let equipment_to_save (e: Campaign.equipment) : save_equipment =
    let opt_map = function
      | Some i -> Some i.id
      | None -> None
    in
    { weapon = opt_map e.weapon; armor = opt_map e.armor; helm = opt_map e.helm;
      gauntlets = opt_map e.gauntlets; ring1 = opt_map e.ring1; ring2 = opt_map e.ring2;
      mount = opt_map e.mount; banner = opt_map e.banner; companion = opt_map e.companion }

  let player_to_save (p: Campaign.player) : save_player =
    { name = p.name; profession_id = p.profession.id; sex = p.sex; age = p.age;
      level = p.level; xp = p.xp; gold = p.gold; life = p.life; max_life = p.max_life;
      skills = skill_affinities_to_save p.skills;
      equipment = equipment_to_save p.equipment;
      inventory = List.map (fun (i: Campaign_items.item) -> i.id) p.inventory;
      known_spells = p.known_spells; active_quests = p.active_quests;
      completed_quests = p.completed_quests; companions = p.companions;
      awards = p.awards;
      current_city = p.current_city }

  let skill_affinities_from_save (s: skill_affinities) : Campaign_types.skill_affinities =
    { earth = s.earth; fire = s.fire; air = s.air; water = s.water;
      battle = s.battle; cunning = s.cunning; morale = s.morale }

  let equipment_from_save (e: save_equipment) : Campaign.equipment =
    { weapon = (match e.weapon with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      armor = (match e.armor with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      helm = (match e.helm with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      gauntlets = (match e.gauntlets with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      ring1 = (match e.ring1 with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      ring2 = (match e.ring2 with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      mount = (match e.mount with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      banner = (match e.banner with Some id -> Some (Campaign_items.item_by_id id) | None -> None);
      companion = (match e.companion with Some id -> Some (Campaign_items.item_by_id id) | None -> None); }

  let player_from_save (s: save_player) : Campaign.player =
    let prof = Campaign_professions.profession_by_id s.profession_id in
    { name = s.name; profession = prof; sex = s.sex; age = s.age;
      level = s.level; xp = s.xp; gold = s.gold; life = s.life; max_life = s.max_life;
      mana = 0; max_mana = 0;
      skills = skill_affinities_from_save s.skills;
      equipment = equipment_from_save s.equipment;
      inventory = List.map (fun id -> Campaign_items.item_by_id id) s.inventory;
      known_spells = s.known_spells; active_quests = s.active_quests;
      completed_quests = s.completed_quests; companions = s.companions;
      awards = s.awards;
      current_city = s.current_city }
end

(* ------------------------------------------------------------------ *)
(* Public API *)
(* ------------------------------------------------------------------ *)

let create_save_data player active_quests current_location travel_state =
  let quests = List.map (fun (qid, state) -> { quest_id = qid; state; vars = [] }) active_quests in
  { player = SaveConvert.player_to_save player;
    quests;
    (* snapshot the live map state, not the static data defaults *)
    map_visibility =
      { visible_cities = List.filter_map (fun (c : Campaign_map.city) -> if Campaign.node_visible c.id then Some c.id else None) Campaign_map.cities;
        visible_waypoints = List.filter_map (fun (w : Campaign_map.waypoint) -> if Campaign.node_visible w.id then Some w.id else None) Campaign_map.waypoints;
        visible_ruins = List.filter_map (fun (r : Campaign_map.ruin) -> if Campaign.node_visible r.id then Some r.id else None) Campaign_map.ruins;
        visible_roads = List.filter_map (fun (r : Campaign_map.road) -> if Campaign.get_road_visible r.start r.end_ then Some (r.start, r.end_) else None) Campaign_map.roads };
    ruin_counts = Campaign.ruin_counts_snapshot ();
    ruin_done = Campaign.ruin_done_snapshot ();
    current_location; travel_state }

let save_to_file filename save =
  let json = save_campaign_to_json save in
  let out = open_out_bin filename in
  output_string out (Yojson.Basic.pretty_to_string json);
  output_string out "\n";
  close_out out

let load_from_file filename =
  let ic = open_in filename in
  let len = in_channel_length ic in
  let buf = Bytes.create len in
  really_input ic buf 0 len;
  close_in ic;
  let json = Yojson.Basic.from_string (Bytes.to_string buf) in
  save_campaign_of_json json

let apply_save save =
  let player = SaveConvert.player_from_save save.player in
  (* quest states are the saved ints, same representation as player.active_quests *)
  let active_quests = List.map (fun sq -> (sq.quest_id, sq.state)) save.quests in
  let completed_quests = save.player.completed_quests in
  let awards = save.player.awards in
  let current_location = save.current_location in
  let travel_state = save.travel_state in
  (* restore map visibility into the live tables: hide everything first, then
     show exactly what the save recorded *)
  List.iter (fun (c : Campaign_map.city) -> Campaign.set_node_visible c.Campaign_map.id false) Campaign_map.cities;
  List.iter (fun (w : Campaign_map.waypoint) -> Campaign.set_node_visible w.Campaign_map.id false) Campaign_map.waypoints;
  List.iter (fun (r : Campaign_map.ruin) -> Campaign.set_node_visible r.Campaign_map.id false) Campaign_map.ruins;
  List.iter (fun (r : Campaign_map.road) -> Campaign.set_road_visible r.Campaign_map.start r.Campaign_map.end_ false) Campaign_map.roads;
  List.iter (fun id -> Campaign.set_node_visible id true) save.map_visibility.visible_cities;
  List.iter (fun id -> Campaign.set_node_visible id true) save.map_visibility.visible_waypoints;
  List.iter (fun id -> Campaign.set_node_visible id true) save.map_visibility.visible_ruins;
  List.iter (fun (a, b) -> Campaign.set_road_visible a b true) save.map_visibility.visible_roads;
  (* same treatment for the ruin registry: replace the live tables with the
     counts and done set the save recorded *)
  Campaign.restore_ruin_state save.ruin_counts save.ruin_done;
  (player, active_quests, completed_quests, awards, current_location, travel_state)