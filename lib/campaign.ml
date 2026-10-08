(* Campaign engine core types and map logic *)

open Campaign_map
open Campaign_encounters
open Campaign_quests
open Campaign_items
open Campaign_professions
open Campaign_conversations
open Campaign_types
open Battle
open Combat

(* ------------------------------------------------------------------ *)
(* Player character *)
(* ------------------------------------------------------------------ *)

type equipment = {
  weapon: item option;
  armor: item option;
  helm: item option;
  gauntlets: item option;
  ring1: item option;
  ring2: item option;
  mount: item option;
  banner: item option;
  companion: item option;
}

type player = {
  name: string;
  profession: profession;
  sex: int;           (* 0 = male, 1 = female *)
  age: int;           (* 0 = young, 1 = old *)
  level: int;
  xp: int;
  gold: int;
  life: int;
  max_life: int;
  mana: int;          (* current mana per color: earth, fire, air, water *)
  max_mana: int;
  skills: skill_affinities;  (* base affinities from profession + items *)
  equipment: equipment;
  inventory: item list;
  known_spells: string list; (* spell ids *)
  active_quests: (string * int) list; (* quest_id * state *)
  completed_quests: string list;
  companions: string list;   (* companion monster ids *)
  awards: string list;       (* quest awards earned *)
  current_city: string option; (* for income collection *)
}

let default_equipment = {
  weapon = None; armor = None; helm = None; gauntlets = None;
  ring1 = None; ring2 = None; mount = None; banner = None; companion = None
}

let create_player name prof_id sex age =
  let prof = profession_by_id prof_id in
  let starts = prof.starts in
  {
    name; profession = prof; sex; age;
    level = 1; xp = 0; gold = starts.gold;
    life = 30 + prof.life_per_level; max_life = 30 + prof.life_per_level;
    mana = 0; max_mana = 0;
    skills = prof.skills;
    equipment = default_equipment;
    inventory = [];
    known_spells = [];
    active_quests = [];
    completed_quests = [];
    companions = [];
    awards = [];
    current_city = None;
  }

(* ------------------------------------------------------------------ *)
(* Map / Travel *)
(* ------------------------------------------------------------------ *)

type node_kind = City | Waypoint | Ruin

type map_node = {
  id: string;
  kind: node_kind;
  x: int;
  y: int;
  visible: bool;
  (* kind-specific *)
  city_data: city option;
  waypoint_data: waypoint option;
  ruin_data: ruin option;
}

let build_map () =
  let nodes = Hashtbl.create 100 in
  List.iter (fun (c: city) ->
    Hashtbl.add nodes c.id {
      id = c.id; kind = City;
      x = c.x; y = c.y; visible = c.visible;
      city_data = Some c; waypoint_data = None; ruin_data = None;
    }) cities;
  List.iter (fun (w: waypoint) ->
    Hashtbl.add nodes w.id {
      id = w.id; kind = Waypoint;
      x = w.x; y = w.y; visible = w.visible;
      city_data = None; waypoint_data = Some w; ruin_data = None;
    }) waypoints;
  List.iter (fun (r: ruin) ->
    Hashtbl.add nodes r.id {
      id = r.id; kind = Ruin;
      x = r.x; y = r.y; visible = r.visible;
      city_data = None; waypoint_data = None; ruin_data = Some r;
    }) ruins;
  nodes

type travel_state =
  | AtNode of string
  | Traveling of { from_: string; to_: string; progress: float; total_time: float }
  | InEncounter of encounter
  | InCity of string
  | InRuin of string
  | InConversation of conversation

let map_nodes = build_map ()

(* Mutable road visibility *)
type road_entry = { start: string; end_: string; mutable visible: bool }

let road_table = Hashtbl.create 100
let () =
  List.iter (fun (r: road) ->
    Hashtbl.add road_table (r.start, r.end_) { start = r.start; end_ = r.end_; visible = r.visible };
    Hashtbl.add road_table (r.end_, r.start) { start = r.end_; end_ = r.start; visible = r.visible }
  ) roads

(* Modify map node visibility *)
let set_node_visible (id: string) (vis: bool) : unit =
  try
    let node = Hashtbl.find map_nodes id in
    Hashtbl.replace map_nodes id { node with visible = vis }
  with Not_found -> ()

let set_road_visible (start: string) (end_: string) (vis: bool) : unit =
  (try (Hashtbl.find road_table (start, end_)).visible <- vis with Not_found -> ());
  if start <> end_ then
    (try (Hashtbl.find road_table (end_, start)).visible <- vis with Not_found -> ())

let get_road_visible (start: string) (end_: string) : bool =
  try
    let road = Hashtbl.find road_table (start, end_) in
    road.visible
  with Not_found -> false

let node_by_id id = Hashtbl.find map_nodes id

let node_visible (id: string) : bool =
  try (node_by_id id).visible with Not_found -> false

let roads_from_node node =
  roads_connected node
  |> List.filter (fun (r: road) -> get_road_visible r.start r.end_)

let visible_nodes () =
  Hashtbl.fold (fun _ (n: map_node) acc -> if n.visible then n :: acc else acc) map_nodes []

(* Reveal/hide a map node with the engine's road rule: a road is visible only
   when both endpoints are visible, maintained lazily over the roads touching
   the changed node (Engine_QUEST_SET_VISIBILITY_450e40.c: the other endpoint's
   visible flag decides, hiding is unconditional). Quest reveals come from the
   extracted QUEST_SET_VISIBILITY / QUEST_ADD_RUIN calls - see
   Campaign_quests.quest.reveal_on_begin / reveal_on_end / ruin_reveals. *)
let set_location_visible (id: string) (vis: bool) : unit =
  set_node_visible id vis;
  List.iter (fun (r: road) ->
    if r.start = id || r.end_ = id then begin
      let other = if r.start = id then r.end_ else r.start in
      let other_vis = try (node_by_id other).visible with Not_found -> false in
      set_road_visible r.start r.end_ (vis && other_vis)
    end
  ) roads

(* Distance heuristic for travel time *)
let node_distance a b =
  let na = node_by_id a in
  let nb = node_by_id b in
  let dx = float (na.x - nb.x) in
  let dy = float (na.y - nb.y) in
  sqrt (dx *. dx +. dy *. dy)

(* ------------------------------------------------------------------ *)
(* Encounter logic - ported from Lua OnQueryAppearance patterns *)
(* ------------------------------------------------------------------ *)

type encounter_appearance_result = Appears | StaysHidden

let check_encounter_appearance (player: player) (enc: encounter) : encounter_appearance_result =
  (* Data extracted from Lua at compile time: my_level and chance *)
  if player.level >= enc.my_level && (Random.int 100 + 1) <= enc.chance then
    Appears
  else
    StaysHidden

let encounters_on_road_visible (player: player) (start: string) (end_: string) : encounter list =
  let all = encounters_on_road start end_ in
  List.filter (fun e -> check_encounter_appearance player e = Appears) all

(* ------------------------------------------------------------------ *)
(* Quest logic - ported from Lua quest state machines *)
(* ------------------------------------------------------------------ *)

type quest_state = 
  | Inactive
  | Active of int  (* state variable from quest script *)
  | Completed
  | Failed

type quest_instance = {
  quest: quest;
  state: quest_state;
  (* quest-specific variables stored as key-value *)
  vars: (string * string) list;
}

let quest_var_get (vars: (string * string) list) (key: string) : string option =
  try Some (List.assoc key vars) with Not_found -> None

let quest_var_set (vars: (string * string) list) (key: string) (value: string) : (string * string) list =
  let rec go acc = function
    | [] -> (key, value) :: acc
    | (k, v) :: rest ->
      if k = key then (key, value) :: rest @ acc else go ((k, v) :: acc) rest
  in
  List.rev (go [] vars)

(* Run a quest hook - returns new quest_instance and any effects *)
type quest_effect =
  | RewardGold of int
  | RewardXP of int
  | RewardItem of string
  | RewardAward of string
  | RewardCompanion of string
  | AddQuest of string
  | CompleteQuest of string
  | FailQuest of string
  | SetState of int
  | EncounterBattle of string * string * int  (* code, monster, ? *)
  | ShowRewardMenu of string * string
  | RevealNode of string  (* node id from QUEST_SET_VISIBILITY / QUEST_ADD_RUIN *)
  | None

let run_quest_on_begin (qi: quest_instance) : quest_instance * quest_effect list =
  let q = qi.quest in
  (* OnBegin reveals plus the intro conversation callback (CallbackConvA), and
     ruin registration (QUEST_ADD_RUIN, OnBegin in the shipped set) *)
  let reveals = List.map (fun n -> RevealNode n) (q.reveal_on_begin @ q.ruin_reveals) in
  let new_vars = quest_var_set qi.vars "questState" "1" in
  { qi with state = Active 1; vars = new_vars }, reveals @ [SetState 1]

let run_quest_on_end (qi: quest_instance) : quest_instance * quest_effect list =
  (* Rewards as extracted from the quest script (OnEnd plus reward callbacks);
     conditional if/else reward branches take the first source-order value - see
     evidence campaign.quest_rewards_conditional *)
  let q = qi.quest in
  let rewards =
    (if q.reward_gold > 0 then [RewardGold q.reward_gold] else [])
    @ (if q.reward_xp > 0 then [RewardXP q.reward_xp] else [])
    @ List.map (fun i -> RewardItem i) q.reward_items
    @ List.map (fun a -> RewardAward a) q.reward_awards
    @ List.map (fun c -> RewardCompanion c) q.reward_companions
  in
  let reveals = List.map (fun n -> RevealNode n) q.reveal_on_end in
  { qi with state = Completed },
  rewards @ reveals @ [ShowRewardMenu (quest_name q, quest_desc q); CompleteQuest q.id]

let run_quest_on_fail (qi: quest_instance) : quest_instance * quest_effect list =
  { qi with state = Failed }, [FailQuest qi.quest.id]

let run_quest_on_abandon (qi: quest_instance) : quest_instance * quest_effect list =
  { qi with state = Inactive; vars = quest_var_set qi.vars "questState" "0" }, [SetState 0]

let run_quest_on_enter_location (qi: quest_instance) (_location: string) : quest_instance * quest_effect list =
  qi, []

(* Check if quest is available for player at location *)
let is_quest_available (player: player) (q: quest) : bool =
  player.level >= q.avail_minlevel &&
  player.level <= q.avail_maxlevel &&
  (* not available while already active *)
  (not (List.exists (fun (qid, _) -> qid = q.id) player.active_quests)) &&
  (* donequest prerequisites: all must be completed *)
  (q.avail_donequest0 = "" || List.mem q.avail_donequest0 player.completed_quests) &&
  (q.avail_donequest1 = "" || List.mem q.avail_donequest1 player.completed_quests) &&
  (q.avail_donequest2 = "" || List.mem q.avail_donequest2 player.completed_quests) &&
  (* notdonequest: must NOT be completed *)
  (q.avail_notdonequest = "" || not (List.mem q.avail_notdonequest player.completed_quests)) &&
  (* notactivequest: must NOT be active (in progress) *)
  (q.avail_notactivequest = "" || not (List.exists (fun (qid, _) -> qid = q.avail_notactivequest) player.active_quests)) &&
  (* companion prerequisites: must have companion in party *)
  (q.avail_companion0 = "" || List.mem q.avail_companion0 player.companions) &&
  (q.avail_companion1 = "" || List.mem q.avail_companion1 player.companions) &&
  (* notcompanion: must NOT have this companion *)
  (q.avail_notcompanion = "" || not (List.mem q.avail_notcompanion player.companions)) &&
  (* item prerequisite: must have item in inventory *)
  (q.avail_item = "" || List.exists (fun (i: item) -> i.id = q.avail_item) player.inventory) &&
  (* notitem: must NOT have this item *)
  (q.avail_notitem = "" || not (List.exists (fun (i: item) -> i.id = q.avail_notitem) player.inventory)) &&
  (* award prerequisite: must have award *)
  (q.avail_award = "" || List.mem q.avail_award player.awards) &&
  (* notaward: must NOT have this award *)
  (q.avail_notaward = "" || not (List.mem q.avail_notaward player.awards))

let available_quests_at (player: player) (location: string) : quest list =
  let qs = quests_at_location location in
  List.filter (is_quest_available player) qs

(* ------------------------------------------------------------------ *)
(* City services *)
(* ------------------------------------------------------------------ *)

let city_shop_items (city: city) : item list =
  List.map (fun tag -> item_by_id tag) city.items

let city_shop_spells (city: city) : string list =
  city.spells

(* ------------------------------------------------------------------ *)
(* Income *)
(* ------------------------------------------------------------------ *)

let collect_income (player: player) : player =
  match player.current_city with
  | Some city_id ->
    let city = city_by_id city_id in
    { player with gold = player.gold + city.income }
  | None -> player

(* ------------------------------------------------------------------ *)
(* Level up *)
(* ------------------------------------------------------------------ *)

let xp_for_level (prof: profession) (level: int) : int =
  try List.assoc level prof.xp.levels with Not_found -> prof.xp.leveladd * level

let check_level_up (player: player) : player =
  let needed = xp_for_level player.profession (player.level + 1) in
  if player.xp >= needed then
    let new_level = player.level + 1 in
    let life_gain = player.profession.life_per_level in
    let new_player = { player with
      level = new_level;
      max_life = player.max_life + life_gain;
      life = player.life + life_gain;
    } in
    let new_spells =
      List.filter_map (fun (lvl, spell) ->
        if lvl = new_level then Some spell else None
      ) player.profession.spells_by_level
    in
    { new_player with known_spells = new_spells @ new_player.known_spells }
  else player

(* ------------------------------------------------------------------ *)
(* Battle Integration *)
(* ------------------------------------------------------------------ *)

(* Convert campaign player to battle combatant *)
let player_to_combatant (p: player) : combatant =
  make_combatant
    ~cunning:p.skills.cunning
    ~max_life:p.max_life
    ~life:p.life
    0 p.name  (* distinct positive ID *)

(* Convert encounter to battle combatant *)
let encounter_to_combatant (enc: encounter) (player_level: int) : combatant =
  let monster = Campaign_monsters.monster_by_sprite enc.sprite in
  let level = player_level in
  let base_life = monster.life in
  let life = base_life + (level - 1) * 5 in
  let max_life = life in
  make_combatant
    ~cunning:monster.skills.cunning
    ~max_life
    ~life
    1 monster.name_text  (* distinct positive ID *)

(* Run a battle between player and encounter *)
let run_encounter_battle (player: player) (enc: encounter) : battle =
  let hero = player_to_combatant player in
  let enemy = encounter_to_combatant enc player.level in
  let board =
    let e = Array.make 4 (Board.Mana Fire) in
    e.(0) <- Board.Mana Fire;
    e.(1) <- Board.Mana Water;
    e.(2) <- Board.Mana Air;
    e.(3) <- Board.Mana Earth;
    Board.of_array_matrix
      (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))
  in
  let battle = Battle.create board hero enemy in
  let final_battle = Battle.run battle in
  final_battle

(* Process battle result and update player/quest state *)
type battle_result = {
  player_won: bool;
  gold_gained: int;
  xp_gained: int;
  final_life: int;
}

let process_battle_result (player: player) (_enc: encounter) (battle: battle) : player * battle_result =
  let hero = battle.hero in
  let enemy = battle.enemy in
  let player_won = enemy.is_dead && not hero.is_dead in
  let gold_gained = battle.gold in
  let xp_gained = battle.xp in
  let new_player = {
    player with
      gold = player.gold + gold_gained;
      xp = player.xp + xp_gained;
      life = hero.life;
    } in
  let result = {
    player_won;
    gold_gained;
    xp_gained;
    final_life = hero.life;
  } in
  (new_player, result)

(* Apply a single quest effect to a player *)
let apply_quest_effect p qeffect =
  match qeffect with
  | RewardGold g -> { p with gold = p.gold + g }
  | RewardXP x -> { p with xp = p.xp + x }
  | RewardItem item_id ->
    (try { p with inventory = (item_by_id item_id) :: p.inventory } with Not_found -> p)
  | RewardAward award_id -> { p with awards = award_id :: p.awards }
  | RewardCompanion companion_id -> { p with companions = companion_id :: p.companions }
  | RevealNode node_id -> set_location_visible node_id true; p
  | CompleteQuest qid ->
    { p with
        active_quests = List.filter (fun (id, _) -> id <> qid) p.active_quests;
        completed_quests =
          if List.mem qid p.completed_quests then p.completed_quests
          else qid :: p.completed_quests }
  | _ -> p

(* ------------------------------------------------------------------ *)
(* Quest lifecycle (player level)                                     *)
(* ------------------------------------------------------------------ *)

(* Accept a quest: runs OnBegin (node reveals + ruin registration) and adds
   it to active_quests at state 1. No-op if the quest isn't available. *)
let quest_accept (player: player) (qid: string) : player =
  let q = quest_by_id qid in
  if not (is_quest_available player q) then player
  else
    let qi = { quest = q; state = Inactive; vars = [] } in
    let _qi, effects = run_quest_on_begin qi in
    let p = List.fold_left apply_quest_effect player effects in
    if List.exists (fun (id, _) -> id = qid) p.active_quests then p
    else { p with active_quests = (qid, 1) :: p.active_quests }

(* Resolve the quest's battle: on success state 1 -> 2 (kill done, turn-in
   pending); on failure the quest stays active at 1 (Q0E0 OnCompleteAction
   keeps questState = 1 and only shows a message). *)
let quest_battle_complete (player: player) (qid: string) (success: bool) : player =
  if not success then player
  else { player with active_quests =
    List.map (fun (id, s) -> if id = qid then (id, 2) else (id, s)) player.active_quests }

(* Turn in a quest: runs OnEnd - rewards, end-of-quest node reveals, and
   CompleteQuest bookkeeping (moves it out of active_quests into
   completed_quests). No-op if the quest isn't active. *)
let quest_turn_in (player: player) (qid: string) : player =
  if not (List.exists (fun (id, _) -> id = qid) player.active_quests) then player
  else
    let q = quest_by_id qid in
    let qi = { quest = q; state = Active 2; vars = quest_var_set [] "questState" "2" } in
    let _qi, effects = run_quest_on_end qi in
    List.fold_left apply_quest_effect player effects

(* Complete a road encounter: run the battle and apply loot. Road encounters
   are random travel fights; quest progress is driven by quest_battle_complete
   and quest_turn_in (quest Lua calls QUEST_BATTLE for its own fight - road
   wins never advance quest state). *)
let complete_encounter (player: player) (enc: encounter) : player =
  let battle = run_encounter_battle player enc in
  let new_player, _result = process_battle_result player enc battle in
  new_player