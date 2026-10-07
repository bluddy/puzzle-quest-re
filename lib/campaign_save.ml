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
  let save = { player = save_player_of_json (json |> member "player");
    quests = (json |> member "quests" |> to_list) |> List.map (fun v -> { quest_id = v |> member "quest_id" |> to_string; state = v |> member "state" |> to_int; vars = (v |> member "vars" |> to_list) |> List.map (fun v -> (v |> member "key" |> to_string, v |> member "value" |> to_string)) });
    map_visibility = (let m = json |> member "map_visibility" in { visible_cities = (m |> member "visible_cities" |> to_list) |> List.map to_string; visible_waypoints = (m |> member "visible_waypoints" |> to_list) |> List.map to_string; visible_ruins = (m |> member "visible_ruins" |> to_list) |> List.map to_string; visible_roads = (m |> member "visible_roads" |> to_list) |> List.map (fun v -> (v |> member "from" |> to_string, v |> member "to" |> to_string)) });
    current_location = json |> member "current_location" |> to_string;
    travel_state = json |> member "travel_state" |> to_int; }
  in
  save

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
      current_city = s.current_city }
end

(* ------------------------------------------------------------------ *)
(* Public API *)
(* ------------------------------------------------------------------ *)

let create_save_data player active_quests current_location travel_state =
  let _player_save = SaveConvert.player_to_save player in
  let quests = List.map (fun (qid, state) ->
    { quest_id = qid; state = (match state with
        | Campaign.Inactive -> 0 | Campaign.Active s -> s | Campaign.Completed -> 3 | Campaign.Failed -> 4);
      vars = [] }) active_quests in
  { player = SaveConvert.player_to_save player;
    quests;
    map_visibility = (let module M = struct
      let cities : Campaign_map.city list = Campaign_map.cities
      let waypoints : Campaign_map.waypoint list = Campaign_map.waypoints
      let ruins : Campaign_map.ruin list = Campaign_map.ruins
      let roads : Campaign_map.road list = Campaign_map.roads
    end in
    { visible_cities = List.map (fun (c : Campaign_map.city) -> c.id) M.cities;
      visible_waypoints = List.map (fun (w : Campaign_map.waypoint) -> w.id) M.waypoints;
      visible_ruins = List.map (fun (r : Campaign_map.ruin) -> r.id) M.ruins;
      visible_roads = List.map (fun (r : Campaign_map.road) -> (r.start, r.end_)) M.roads });
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
  let save = { player = save_player_of_json (json |> member "player");
    quests = (json |> member "quests" |> to_list) |> List.map (fun v -> { quest_id = v |> member "quest_id" |> to_string; state = v |> member "state" |> to_int; vars = (v |> member "vars" |> to_list) |> List.map (fun v -> (v |> member "key" |> to_string, v |> member "value" |> to_string)) });
    map_visibility = (let m = json |> member "map_visibility" in { visible_cities = (m |> member "visible_cities" |> to_list) |> List.map to_string; visible_waypoints = (m |> member "visible_waypoints" |> to_list) |> List.map to_string; visible_ruins = (m |> member "visible_ruins" |> to_list) |> List.map to_string; visible_roads = (m |> member "visible_roads" |> to_list) |> List.map (fun v -> (v |> member "from" |> to_string, v |> member "to" |> to_string)) });
    current_location = json |> member "current_location" |> to_string;
    travel_state = json |> member "travel_state" |> to_int; }
  in
  save

let apply_save save =
  let player = SaveConvert.player_from_save save.player in
  let active_quests = List.map (fun sq ->
    let state = match sq.state with
      | 0 -> Campaign.Inactive | 1 -> Campaign.Active 1 | 2 -> Campaign.Active 2
      | 3 -> Campaign.Completed | 4 -> Campaign.Failed | _ -> Campaign.Inactive in
    (sq.quest_id, state)) save.quests in
  let completed_quests = save.player.completed_quests in
  let current_location = save.current_location in
  let travel_state = save.travel_state in
  (player, active_quests, completed_quests, current_location, travel_state)