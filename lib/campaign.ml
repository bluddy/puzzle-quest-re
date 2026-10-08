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
  dungeon_built: bool;       (* capture gate; chosen: true, see capture section *)
  monster_defeats: (string * int) list; (* monster id * wins toward capture *)
  captives: string list;     (* monster ids captured *)
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
    dungeon_built = true;
    monster_defeats = [];
    captives = [];
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

(* Ruin registration: Engine_QUEST_ADD_RUIN_452010.c inserts the id with count 1
   or increments the existing count, reveals the node, and purges any pending
   done-notification for that id (so re-registering clears "done"); the count is
   what keeps a shared ruin registered while another quest still holds it.
   Engine_QUEST_SET_RUIN_DONE_452150.c finds the entry (absent -> no-op),
   decrements, and at zero removes it and pushes a done notification. Holders
   come from the extracted scripts: register on accept, release on battle
   success, turn-in and abandon - see Campaign_quests.quest.ruin_reveals and
   ruin_dones_* (tools/extract_quests.py groups the call sites by hook). *)
let ruin_counts : (string, int) Hashtbl.t = Hashtbl.create 16
let ruin_done_ids : string list ref = ref []

let ruin_count (id: string) : int =
  match Hashtbl.find_opt ruin_counts id with Some n -> n | None -> 0

let ruin_is_done (id: string) : bool = List.mem id !ruin_done_ids

let register_ruin (id: string) : unit =
  set_location_visible id true;
  Hashtbl.replace ruin_counts id (ruin_count id + 1);
  (* ADD_RUIN purges the id's pending done notification on every register *)
  ruin_done_ids := List.filter (fun r -> r <> id) !ruin_done_ids

let set_ruin_done (id: string) : unit =
  match ruin_count id with
  | 0 -> ()  (* no entry: the engine's find fails and nothing happens *)
  | 1 ->
    Hashtbl.remove ruin_counts id;
    if not (List.mem id !ruin_done_ids) then ruin_done_ids := id :: !ruin_done_ids
  | n -> Hashtbl.replace ruin_counts id (n - 1)

(* save/load: snapshot the live registry, like the visibility tables *)
let ruin_counts_snapshot () =
  Hashtbl.fold (fun k v acc -> (k, v) :: acc) ruin_counts []

let ruin_done_snapshot () = !ruin_done_ids

let restore_ruin_state (counts: (string * int) list) (done_ids: string list) : unit =
  Hashtbl.reset ruin_counts;
  List.iter (fun (id, n) -> if n > 0 then Hashtbl.replace ruin_counts id n) counts;
  ruin_done_ids := List.sort_uniq compare done_ids

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
  | RemoveCompanion of string  (* QUEST_REMOVE_COMPANION: leaves the party *)
  | AddQuest of string
  | CompleteQuest of string
  | FailQuest of string
  | SetState of int
  | EncounterBattle of string * string * int  (* code, monster, ? *)
  | ShowRewardMenu of string * string
  | RevealNode of string  (* node id from QUEST_SET_VISIBILITY *)
  | RegisterRuin of string  (* QUEST_ADD_RUIN: refcount + reveal *)
  | RuinDone of string  (* QUEST_SET_RUIN_DONE: refcount down, mark done at 0 *)
  | None

let run_quest_on_begin (qi: quest_instance) : quest_instance * quest_effect list =
  let q = qi.quest in
  (* OnBegin reveals plus the intro conversation callback (CallbackConvA), and
     ruin registration (QUEST_ADD_RUIN from OnBegin / the conversation) *)
  let reveals = List.map (fun n -> RevealNode n) q.reveal_on_begin in
  let registers = List.map (fun n -> RegisterRuin n) q.ruin_reveals in
  let new_vars = quest_var_set qi.vars "questState" "1" in
  { qi with state = Active 1; vars = new_vars }, reveals @ registers @ [SetState 1]

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
  (* QUEST_SET_RUIN_DONE calls outside OnAbandon / OnCompleteAction (OnEnd plus
     stray callbacks) release the ruin at turn-in; guards on those calls are not
     evaluated, so the release may find the ruin already released - the engine's
     absent-id no-op bounds that, see evidence campaign.ruin_registry *)
  let ruins = List.map (fun n -> RuinDone n) q.ruin_dones_on_end in
  { qi with state = Completed },
  rewards @ reveals @ ruins @ [ShowRewardMenu (quest_name q, quest_desc q); CompleteQuest q.id]

let run_quest_on_fail (qi: quest_instance) : quest_instance * quest_effect list =
  { qi with state = Failed }, [FailQuest qi.quest.id]

let run_quest_on_abandon (qi: quest_instance) : quest_instance * quest_effect list =
  { qi with state = Inactive; vars = quest_var_set qi.vars "questState" "0" },
  List.map (fun n -> RuinDone n) qi.quest.ruin_dones_on_abandon @ [SetState 0]

(* OnEnterLocation: a hero has arrived at a new location. The extracted rules
   say which quest state plus location pair makes which companion leave
   (Q3S0's five sword points, Q3W0's at CENM). The Lua's
   QUEST_HERO_HAS_COMPANION_SELECTED guard needs no check here: dropping
   someone who is not in the party is the no-op the guard would have
   prevented, and the leave message rides no campaign event. *)
let run_quest_on_enter_location (qi: quest_instance) (location: string) : quest_instance * quest_effect list =
  let state = match qi.state with Active n -> n | _ -> -1 in
  qi,
  List.filter_map
    (fun (st, loc, cid) ->
      if st = state && loc = location then Some (RemoveCompanion cid) else None)
    qi.quest.enter_removes

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
(* Capture                                                             *)
(* ------------------------------------------------------------------ *)

(* [CAPTURE_LISTHELP] gates an attempt on two things: a dungeon built and the
   enemy defeated 3+ times. dungeon_built is chosen true - the requirement
   comes from the string, but no shipped data carries a dungeon to build, so
   the flag exists to gate rather than to withhold. Defeats count won battles
   per monster id: road wins via process_battle_result (the encounter's sprite
   maps back to its monster record) and quest wins via quest_battle_complete
   (the quest's battle_monster). *)

let monster_defeats (p: player) (monster_id: string) : int =
  try List.assoc monster_id p.monster_defeats with Not_found -> 0

let record_defeat (p: player) (monster_id: string) : player =
  let n = monster_defeats p monster_id + 1 in
  { p with monster_defeats =
      (monster_id, n) :: List.filter (fun (id, _) -> id <> monster_id) p.monster_defeats }

let capture_eligible (p: player) (monster_id: string) : bool =
  p.dungeon_built && monster_defeats p monster_id >= 3

(* The attempt runs on the monster's shipped capture grid. *)
let capture_begin (monster_id: string) : Capture.t =
  Capture.create (Campaign_monsters.monster_by_id monster_id).capture_grid

(* A won attempt adds the monster to the captives (once); a lost one changes
   nothing - [CAPTURE_FAIL] "you may try again later". An in-progress attempt
   is not persisted: the grid is deterministic data, so a loaded player rebuilds
   it with capture_begin. *)
let capture_finish (p: player) (monster_id: string) (attempt: Capture.t) : player =
  match attempt.status with
  | Capture.Won ->
    if List.mem monster_id p.captives then p
    else { p with captives = monster_id :: p.captives }
  | Capture.Playing | Capture.Lost -> p

(* ------------------------------------------------------------------ *)
(* Battle Integration *)
(* ------------------------------------------------------------------ *)

(* Convert campaign player to battle combatant *)
let to_combat_skills (s: skill_affinities) : skills =
  { earth = s.earth; fire = s.fire; air = s.air; water = s.water;
    battle = s.battle; morale = s.morale; cunning = s.cunning }

let player_to_combatant (p: player) : combatant =
  make_combatant
    ~cunning:p.skills.cunning
    ~skills:(to_combat_skills p.skills)
    ~max_life:p.max_life
    ~life:p.life
    0 p.name  (* distinct positive ID *)

(* Convert a registry monster to a battle combatant, scaled to the player's
   level the way road encounters are *)
let monster_to_combatant (m: Campaign_monsters.monster) (player_level: int) : combatant =
  let life = m.life + (player_level - 1) * 5 in
  let max_life = life in
  make_combatant
    ~cunning:m.skills.cunning
    ~skills:(to_combat_skills m.skills)
    ~max_life
    ~life
    1 m.name_text  (* distinct positive ID *)

(* Convert encounter to battle combatant *)
let encounter_to_combatant (enc: encounter) (player_level: int) : combatant =
  monster_to_combatant (Campaign_monsters.monster_by_sprite enc.sprite) player_level

(* The monster type tags the companion scripts CHECK_TYPE against; the
   monster record keeps up to four, unset ones read "". *)
let monster_type_tags (m: Campaign_monsters.monster) : string list =
  List.filter (fun t -> t <> "") [m.type1; m.type2; m.type3; m.type4]

(* A legal no-start-match board: the same diagonal the demo runner seeds.
   Matches never sit at the opening cursor, so a battle can start at once. *)
let fresh_board () : Board.board =
  let e = Array.make 4 (Board.Mana Fire) in
  e.(0) <- Board.Mana Fire;
  e.(1) <- Board.Mana Water;
  e.(2) <- Board.Mana Air;
  e.(3) <- Board.Mana Earth;
  Board.of_array_matrix
    (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4))))

(* Resolve spell ids against the runtime table, the way the engine builds a
   spell list: descriptor data plus the AI hook and cast effect. Unknown ids
   drop out, which keeps an unported spell out of the lineup rather than in
   it as a blank; duplicates collapse, first occurrence first. *)
let spell_table : Spell.spell list Lazy.t = lazy (Spell_data.load_spell_table ())

let spells_of_ids (ids: string list) : Spell.spell list =
  let table = Lazy.force spell_table in
  let rec uniq = function
    | [] -> []
    | x :: xs -> x :: uniq (List.filter (fun y -> y <> x) xs)
  in
  List.filter_map
    (fun id -> List.find_opt (fun (s: Spell.spell) -> s.Spell.id = id) table)
    (uniq ids)

(* The battle loadout built from the character's equipment panel: each slot's
   item becomes a runtime [Item] by id and lands where its own location says -
   the four XML locations (weapon/head/body/misc, [ITMLOC0..3]) decide the
   placement, so the panel's extra fields (gauntlets, rings, mount, banner,
   companion) fold in by whatever location they carry. Two items of one
   location leave the later field's in the slot; that is a choice, since the
   engine's own fold is not recovered. *)
let loadout_of_equipment (e: equipment) : Item.loadout =
  let l = Item.new_loadout () in
  List.iter
    (fun (slot : Campaign_items.item option) ->
      match slot with
      | None -> ()
      | Some ci ->
        (match Item_hooks.item_of_id ci.Campaign_items.id with
         | None -> ()
         | Some i -> ignore (Item.equip l i)))
    [ e.weapon; e.armor; e.helm; e.gauntlets; e.ring1; e.ring2;
      e.mount; e.banner; e.companion ];
  l

(* Open a battle between two combatants: board, companion OnStartBattle
   hooks (their hits land before the first turn), then each side's item
   start hooks, then the run. Shared by road encounters and quest battles
   so all of it is the same setup on both paths. [rules] arrives from
   [rules_for_battle] in production and stays at [Battle.default_rules]
   where a test means to pin the fields itself. *)
let open_battle ?(hero_spells = []) ?(enemy_spells = [])
    ?(hero_items = Item.new_loadout ()) ?(enemy_items = Item.new_loadout ())
    ?(rng = Random.int) ?(rules = Battle.default_rules)
    ~(hero: combatant) ~(enemy: combatant) ~(enemy_tags: string list)
    ~(companions: string list) () : battle =
  let battle = Battle.create ~rng ~rules ~hero_spells ~enemy_spells
      ?hero_items:(Some hero_items) ?enemy_items:(Some enemy_items)
      (fresh_board ()) hero enemy in
  let hooks =
    Campaign_companion_hooks.apply_start_battle
      ~rng:(fun () -> battle.rng 100)
      ~hero ~enemy
      ~enemy_types:enemy_tags
      ~companions ()
  in
  List.iter (fun (name, amt) ->
    Battle.emit battle (Battle.Damage (name, amt))) hooks.damaged;
  (* Items after companions: the engine runs both kinds of start-of-battle
     callback before the first turn and the order between the kinds is not
     recovered, and every shipped body is independent of the others'. *)
  ignore (Item_hooks.apply_start_battle hero hero_items);
  ignore (Item_hooks.apply_start_battle enemy enemy_items);
  battle

(* The rules a campaign fight runs under. Two of [default_rules]' fields stop
   being defaults here: difficulty, from the recovered hero/task level band
   (ai.difficulty_from_levels - the gate on the AI's spell skip and the
   evaluator's jitter), and the hero's own level, which the board evaluator
   reads for its hero-level band. The task level is the encounter's own
   [my_level] on the road - the same field the spawn gate compares the hero
   against - and the monster's registry base in a quest fight; nothing
   recovered computes either of those at fight time, and [hero_level_cap]
   stays at the default because nothing recovered says what the engine
   passes. That mapping is a choice - port.campaign_task_level. *)
let rules_for_battle ~(player: player) ~(task_level: int) : Battle.rules =
  { Battle.default_rules with
    difficulty =
      Spell.difficulty_for_levels ~hero_level:player.level ~task_level;
    hero_level = player.level }

(* Run a battle between player and encounter. The hero walks in with the
   spells the player knows and the monster with its own registry roster -
   the loadout choice recorded in port.quest_battle_loop, shared with the
   quest path below - at the difficulty the encounter's level asks for. *)
let run_encounter_battle (player: player) (enc: encounter) : battle =
  let monster = Campaign_monsters.monster_by_sprite enc.sprite in
  let hero = player_to_combatant player in
  let enemy = encounter_to_combatant enc player.level in
  let battle = open_battle
      ~rules:(rules_for_battle ~player ~task_level:enc.my_level)
      ~hero ~enemy
      ~hero_spells:(spells_of_ids player.known_spells)
      ~enemy_spells:(spells_of_ids monster.spells)
      ~hero_items:(loadout_of_equipment player.equipment)
      ~enemy_tags:(monster_type_tags monster)
      ~companions:player.companions ()
  in
  Battle.run battle

(* Process battle result and update player/quest state *)
type battle_result = {
  player_won: bool;
  gold_gained: int;
  xp_gained: int;
  final_life: int;
}

let process_battle_result (player: player) (enc: encounter) (battle: battle) : player * battle_result =
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
  (* a road win counts toward capture eligibility *)
  let new_player =
    if player_won && enc.sprite <> "" then begin
      try
        let m = Campaign_monsters.monster_by_sprite enc.sprite in
        record_defeat new_player m.id
      with Not_found -> new_player
    end
    else new_player
  in
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
  | RewardCompanion companion_id ->
    (* [COMPANIONS_HELP]: "You can have up to 8 companions at a time." *)
    if List.mem companion_id p.companions || List.length p.companions >= 8
    then p
    else { p with companions = companion_id :: p.companions }
  | RemoveCompanion companion_id ->
    { p with companions = List.filter (fun c -> c <> companion_id) p.companions }
  | RevealNode node_id -> set_location_visible node_id true; p
  | RegisterRuin id -> register_ruin id; p
  | RuinDone id -> set_ruin_done id; p
  | CompleteQuest qid ->
    { p with
        active_quests = List.filter (fun (id, _) -> id <> qid) p.active_quests;
        completed_quests =
          if List.mem qid p.completed_quests then p.completed_quests
          else qid :: p.completed_quests }
  | _ -> p

(* A hero arrived at [location]: every active quest gets its OnEnterLocation
   rules evaluated against the arrival, effects applying in active-quest
   order so a later rule sees an earlier removal - the order the engine's
   single hero would. *)
let enter_location (player: player) (location: string) : player =
  List.fold_left
    (fun p (qid, st) ->
      let q = quest_by_id qid in
      let qi = { quest = q; state = Active st;
                 vars = quest_var_set [] "questState" (string_of_int st) } in
      let _, effects = run_quest_on_enter_location qi location in
      List.fold_left (fun p' e -> apply_quest_effect p' e) p effects)
    player player.active_quests

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

(* Resolve the quest's battle at its current stage. On success the stage
   moves to the OnCompleteAction success-branch value when the script sets
   one (battle_stage_advances) and to stage + 1 otherwise - which is state 2
   for the usual single-battle quest, where most scripts release the ruin
   they registered through QUEST_SET_RUIN_DONE in that branch, so the
   refcount drops with the state bump. Whether the win counts for capture
   is this stage's QUEST_BATTLE primitive (the third Lua argument disagrees
   on some sites and the primitive wins - see evidence
   campaign.capture_eligible), and the monster comes from this stage's
   <Battle> element rather than the quest's first. On failure the script's
   else-branch state (battle_stage_fails) applies when there is one -
   Q0Q7 sends a lost Dugog fight to state 4, the no-capture retry; a quest
   with no else entry keeps its stage (Q0E0 shows a message and stays). *)
let quest_battle_complete (player: player) (qid: string) (success: bool) : player =
  match List.assoc_opt qid player.active_quests with
  | None -> player
  | Some stage ->
    let q = quest_by_id qid in
    if success then begin
      let next = match List.assoc_opt stage q.battle_stage_advances with
        | Some n -> n
        | None -> stage + 1
      in
      let p = { player with active_quests =
        List.map (fun (id, s) -> if id = qid then (id, next) else (id, s))
          player.active_quests } in
      let capture, monster_id =
        match List.find_opt (fun (st, _, _) -> st = stage) q.battle_actions with
        | Some (_, idx, cap) ->
          let m = match List.nth_opt q.battles idx with
            | Some (mid, _) -> mid
            | None -> q.battle_monster
          in
          cap, m
        | None -> true, q.battle_monster
      in
      let p = if capture && monster_id <> "" then record_defeat p monster_id else p in
      List.fold_left apply_quest_effect p
        (List.map (fun n -> RuinDone n) q.ruin_dones_on_battle)
    end
    else match List.assoc_opt stage q.battle_stage_fails with
      | Some next ->
        { player with active_quests =
          List.map (fun (id, s) -> if id = qid then (id, next) else (id, s))
            player.active_quests }
      | None -> player

(* Settle a finished quest battle against the player: life follows the fight
   either way, a win also takes the battle spoils (gold and xp, as a road win
   does), then quest_battle_complete runs the stage, capture and ruin
   bookkeeping. Split from run_quest_battle so both outcomes can be driven
   directly - the auto-AI loses most fights at the heroes the data hands it,
   and the win bookkeeping has to be testable regardless. *)
let quest_battle_settle (player: player) (qid: string) (success: bool)
    (b: battle) : player =
  let p = { player with life = b.hero.life } in
  let p =
    if success then { p with gold = p.gold + b.gold; xp = p.xp + b.xp }
    else p
  in
  quest_battle_complete p qid success

(* Run the quest battle for the player's current stage of [qid]: the stage
   picks the action, the action's index picks the <Battle> element (monster
   roster plus the hero's spell line-up for this fight), companion
   OnStartBattle hooks fire as they do on the road, and the outcome feeds
   quest_battle_settle. Returns None when the quest is not active, the stage
   has no battle of its own (conversation-driven fights are not wired to the
   state machine - see GAPS), or the monster id is not in the registry. *)
let run_quest_battle ?(rng = Random.int) (player: player) (qid: string)
    : (player * battle) option =
  match List.assoc_opt qid player.active_quests with
  | None -> None
  | Some stage ->
    let q = quest_by_id qid in
    match List.find_opt (fun (st, _, _) -> st = stage) q.battle_actions with
    | None -> None
    | Some (_, idx, _) ->
      match List.nth_opt q.battles idx with
      | None -> None
      | Some (monster_id, hero_spell_ids) ->
        match (try Some (Campaign_monsters.monster_by_id monster_id)
               with Not_found -> None) with
        | None -> None
        | Some monster ->
          let hero = player_to_combatant player in
          let enemy = monster_to_combatant monster player.level in
          let battle =
            Battle.run
              (open_battle ~rng
                 ~rules:(rules_for_battle ~player ~task_level:monster.level_base)
                 ~hero_spells:(spells_of_ids
                   (hero_spell_ids @ player.known_spells))
                 ~enemy_spells:(spells_of_ids monster.spells)
                 ~hero_items:(loadout_of_equipment player.equipment)
                 ~hero ~enemy
                 ~enemy_tags:(monster_type_tags monster)
                 ~companions:player.companions ())
          in
          let won = battle.enemy.is_dead && not battle.hero.is_dead in
          Some (quest_battle_settle player qid won battle, battle)

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

(* Abandon a quest: runs OnAbandon (ruin releases, state back to 0) and drops it
   from active_quests, which makes it available again. No-op if it is not active
   or the quest is not flagged abandonable (Data abandon="yes") - the flag is
   what withholds the Abandon option, so OnAbandon never fires without it. *)
let quest_abandon (player: player) (qid: string) : player =
  if not (List.exists (fun (id, _) -> id = qid) player.active_quests) then player
  else
    let q = quest_by_id qid in
    if not q.abandonable then player
    else
      let qi = { quest = q; state = Active 1; vars = quest_var_set [] "questState" "1" } in
      let _qi, effects = run_quest_on_abandon qi in
      let p = List.fold_left apply_quest_effect player effects in
      { p with active_quests = List.filter (fun (id, _) -> id <> qid) p.active_quests }

(* Complete a road encounter: run the battle and apply loot. Road encounters
   are random travel fights; quest progress is driven by quest_battle_complete
   and quest_turn_in (quest Lua calls QUEST_BATTLE for its own fight - road
   wins never advance quest state). *)
let complete_encounter (player: player) (enc: encounter) : player =
  let battle = run_encounter_battle player enc in
  let new_player, _result = process_battle_result player enc battle in
  new_player