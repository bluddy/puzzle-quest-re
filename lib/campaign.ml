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
  companions: string list;   (* the traveling party: companion ids, up to 8 *)
  recruited_companions: string list; (* every companion ever granted; the party is the equipped subset *)
  awards: string list;       (* quest awards earned *)
  current_city: string option; (* for income collection *)
  dungeon_built: bool;       (* capture gate; chosen: true, see capture section *)
  monster_defeats: (string * int) list; (* monster id * wins toward capture *)
  captives: string list;     (* monster ids captured *)
  mount: string option;      (* the chosen ride: a captured, rideable monster id *)
  runes: string list;        (* collected rune ids - forge ingredients *)
  mount_levels: (string * int) list;
      (* mount id -> training level; absent = the level 1 a capture starts at *)
  quest_vars: (string * (string * int) list) list;
      (* quest id -> persisted script vars (triedToKeepKey, doneConv, ...):
         the engine's per-quest sandbox, absent var = 0 *)
}

let default_equipment = {
  weapon = None; armor = None; helm = None; gauntlets = None;
  ring1 = None; ring2 = None; mount = None; companion = None
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
    recruited_companions = [];
    awards = [];
    current_city = None;
    dungeon_built = true;
    monster_defeats = [];
    captives = [];
    mount = None;
    (* [RUNESANDITEMS_HELP]: "To begin, you have been given the 3 most
       common Runes" - the three with no guard and no location, which
       cannot be claimed anywhere else. *)
    runes = [ "UDAG"; "UCRA"; "UFIR" ];
    mount_levels = [];
    quest_vars = [];
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
(* The journey step                                                    *)
(* ------------------------------------------------------------------ *)

(* How long the crossing takes: the file's own distance heuristic, measured
   in map units, divided by how fast the hero covers them. Walking is one
   unit per tick; a chosen mount multiplies that (port.mount_travel_speed
   extends port.travel_model). The tiers are the registry's mount_speed -
   the capture strings call them slow, average and fast - and the rumor
   "[a] mount moves you faster" holds for every tier, so even a slow mount
   beats walking. What a mount grants beyond speed - its skill bonus, its
   own spell - rides into every battle (port.mount_skill_formula); flying
   and the training-based encounter avoidance stay GAPS gaps. The encounter
   scripts say when appearance is asked - OnQueryAppearance is "called when
   a hero moves to a new location" - but not how often a road is polled
   while it is being crossed, so the port asks once, at departure. Both
   readings are port.travel_model. *)

(* The chosen ride's speed multiplier: 1.0 on foot, then per tier 1.5 slow
   / 2.0 average / 2.5 fast. A mount has to be a captive the registry
   marks rideable ([INV_MOUNTS_TEXT]: "Mounts are beasts you have
   captured"); a non-captive, a non-mount, or a missing id rides nothing. *)
let mounted_speed (player: player) : float =
  match player.mount with
  | None -> 1.0
  | Some mid ->
    (try
       let m = Campaign_monsters.monster_by_id mid in
       if m.mount = 1 then 1.5 +. 0.5 *. float_of_int m.mount_speed else 1.0
     with Not_found -> 1.0)

(* [MOUNTS_HELP]: "You may choose a single mount to ride into combat." One
   at a time - picking a mount swaps the previous choice, None dismounts -
   and the choice is free: mounts differ only in what they grant. *)
let set_mount (player: player) (mid: string option) : player =
  match mid with
  | None -> { player with mount = None }
  | Some id ->
    (try
       let m = Campaign_monsters.monster_by_id id in
       if List.mem id player.captives && m.mount = 1 then
         { player with mount = Some id }
       else player
     with Not_found -> player)

let add_skill_affinities (a: skill_affinities) (b: skill_affinities)
    : skill_affinities =
  { earth = a.earth + b.earth; fire = a.fire + b.fire;
    air = a.air + b.air; water = a.water + b.water;
    battle = a.battle + b.battle; cunning = a.cunning + b.cunning;
    morale = a.morale + b.morale }

(* A mount's training level: 1 until the Stable says otherwise
   ([SELECTMOUNTMENU_TEXT] - training "adds +1 to its level"). *)
let mount_level (p: player) (mid: string) : int =
  match List.assoc_opt mid p.mount_levels with Some n -> n | None -> 1

(* The ridden mount's skill delta at the mount's training level. The
   capture strings are the only statement of the formula - MDSP
   "increases your Fire Mastery by +2 (+1 more per 2 levels)" - and the
   fields line up piecewise: mount_addstat the printed +N,
   mount_addperlevel the "+M more", mount_addlevel the "per K levels".
   The port reads the step as (level - 1) / addlevel: a freshly captured
   mount (level 1) shows exactly the printed +N, and every K training
   levels gained adds another M - [SELECTMOUNTMENU_TEXT] is what makes
   the level the mount's rather than the rider's: training "helps to
   improve your skills in combat". mount_stat is the engine's 0-based
   SKILL_ index (skill_of_index), which is why MSCO/MSWO read Earth and
   MRAT Cunning - the same names their strings give. The delta is
   computed, never stored: player.skills stays the profession base and
   the bonus rides the combatant, like a companion's SkillBonus. A
   hand-built mount field on a non-rideable monster grants nothing.
   (port.mount_training, which supersedes port.mount_skill_formula) *)
let mount_skill_bonus (player: player) : skill_affinities =
  let zero : skill_affinities =
    { earth = 0; fire = 0; air = 0; water = 0; battle = 0;
      cunning = 0; morale = 0 }
  in
  match player.mount with
  | None -> zero
  | Some mid ->
    (try
       let m = Campaign_monsters.monster_by_id mid in
       if m.mount <> 1 then zero
       else
         let steps =
           (mount_level player mid - 1) / max 1 m.mount_addlevel
         in
         let n = m.mount_addstat + (steps * m.mount_addperlevel) in
         if n = 0 then zero
         else
           (match skill_of_index m.mount_stat with
            | SEarth -> { zero with earth = n }
            | SFire -> { zero with fire = n }
            | SAir -> { zero with air = n }
            | SWater -> { zero with water = n }
            | SBattle -> { zero with battle = n }
            | SMorale -> { zero with morale = n }
            | SCunning -> { zero with cunning = n })
     with Not_found -> zero)

(* [MOUNTS_HELP]: "they provide an extra spell for you in combat." The id
   rides ahead of the learned list the way a quest fight's spell does;
   spells_of_ids dedups it against known_spells and drops unknown ids. *)
let mount_spell_ids (player: player) : string list =
  match player.mount with
  | None -> []
  | Some mid ->
    (try
       let m = Campaign_monsters.monster_by_id mid in
       if m.mount = 1 && m.mount_spell <> "" then [ m.mount_spell ] else []
     with Not_found -> [])

(* [TRAINMOUNTS_DESC]: "You must defeat this creature in a timed battle
   to train it to the next level. The higher the level, the faster you
   will need to be!" - the fight is the mount's own kind at the next
   level ([TRAINMOUNTS_DETAIL] prints both numbers before the
   confirm). Both numbers are port choices (port.mount_training): sixty
   seconds for the first training, five shorter each level down to
   twenty, and the clock read as three turns a second - the port runs
   the battle headless under the auto-AI, which needs the slack a human
   matching gems quickly has. *)
type training_challenge = {
  creature_level : int;
  seconds : int;
  turn_limit : int;
}

let training_challenge (p: player) (mid: string) : training_challenge option =
  match
    (try Some (Campaign_monsters.monster_by_id mid) with Not_found -> None)
  with
  | Some m when m.mount = 1 && List.mem mid p.captives ->
    let next = mount_level p mid + 1 in
    let seconds = max 20 (60 - 5 * (next - 2)) in
    Some
      { creature_level = next; seconds; turn_limit = seconds * 3 }
  | _ -> None

(* [YOURCITY_MOUNTS_TEXT]: "As mounts gain levels through training, they
   also begin to let you avoid some encounters on the map." The chance is
   a port reading - ten percent a training level, capped at half - rolled
   once at departure by the front end (port.mount_training). *)
let mount_avoid_chance (p: player) : int =
  match p.mount with
  | None -> 0
  | Some mid -> min 50 (10 * mount_level p mid)

let mount_avoids ?(rng = Random.int) (p: player) : bool =
  let chance = mount_avoid_chance p in
  chance > 0 && rng 100 < chance

let travel_time (player: player) (from_: string) (to_: string) : float =
  node_distance from_ to_ /. mounted_speed player

let road_exists (start_: string) (end_: string) : bool =
  Hashtbl.mem road_table (start_, end_)

(* Begin a journey: the road has to be in the graph and revealed - the same
   both-endpoints rule the map draws by, so a hidden road cannot be walked.
   The hero's mount shortens the crossing before the walk starts; the front
   end just feeds [walk_speed *. dt] against that [total_time]. *)
let begin_travel (player: player) (from_: string) (to_: string) : travel_state option =
  if road_exists from_ to_ && get_road_visible from_ to_ then
    Some (Traveling { from_ = from_; to_ = to_; progress = 0.0;
                      total_time = travel_time player from_ to_ })
  else None

(* One tick of walking: [dt] distance units at the port's one-unit speed.
   Arrival is a move to a new location - the moment the encounter scripts
   name - so [AtNode] is where a completed walk lands. The other
   constructors pass through: a journey step does not interpret the states
   around it. *)
let advance_travel (ts: travel_state) (dt: float) : travel_state =
  match ts with
  | Traveling t ->
      let progress = t.progress +. dt in
      if progress >= t.total_time then AtNode t.to_
      else Traveling { t with progress }
  | _ -> ts

(* The encounter waiting on a road, asked once at departure: the road's own
   list filtered by each script's appearance roll, first active in data order.
   Nothing recovered says the engine picks between two that appear at once. *)
let road_encounter (player: player) (start_: string) (end_: string) : encounter option =
  match encounters_on_road_visible player start_ end_ with
  | [] -> None
  | e :: _ -> Some e

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
   prevented, and the leave message rides no campaign event - its own arm
   carries the gate in enter_effects (apply_loc_groups / companion_ok). *)
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
(* City transactions                                                   *)
(* ------------------------------------------------------------------ *)

(* The shop sells at the registry's own cost: [SHOPMENU_TEXT] says items
   grey out when they are "too expensive for you to buy", and the only
   number an item carries is [cost]. Buying does not check the skill the
   same text mentions for red items - that marking is about {e wearing}
   the item, and nothing recovered gates the purchase on it; equip stays
   its own flow. *)
let buy_item (player: player) (i: item) : player option =
  if player.gold < i.cost then None
  else
    Some
      { player with
        gold = player.gold - i.cost;
        inventory = i :: player.inventory }

(* The tavern's rumors, resolved: every [RUMOR_*_NAME] in the TextLibrary
   paired with its [RUMOR_*_DESC], in table order. Which tavern tells which
   rumor first is in no asset, and the player keeps no book of them yet (the
   INV_RUMORS strings describe one), so this is the raw sequence the window
   cycles - port.city_services. *)
let rumors : (string * string) list =
  List.filter_map
    (fun (k, v) ->
      let n = String.length k in
      if n > 12 && String.sub k 0 7 = "[RUMOR_" && String.sub k (n - 6) 6 = "_NAME]"
      then
        match Text_data.lookup (String.sub k 0 (n - 6) ^ "_DESC]") with
        | Some d -> Some (v, d)
        | None -> None
      else None)
    Text_data.entries

(* ------------------------------------------------------------------ *)
(* Conversation system                                                   *)
(* ------------------------------------------------------------------ *)

(* Start a conversation by ID. The conversation runs in the UI layer;
   this function just validates the ID and returns the conversation data. *)
let start_conversation (conv_id: string) : Conversation.t option =
  Conversation.find (Conversation.load_all ()) conv_id

(* Check if a conversation ID exists. *)
let has_conversation (conv_id: string) : bool =
  Conversation.find (Conversation.load_all ()) conv_id <> None

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

(* The capture a won fight raises, if any: the encounter's monster when both
   [CAPTURE_LISTHELP] gates hold - dungeon built, that enemy down three times
   - and the hero does not hold it yet ([PETS_DETAILS] counts enemies
   captured, one apiece). The id form is the shared core: callback battles
   carry a monster id rather than an encounter (cb_monster_id), and the city
   Pets tab walks the whole registry through [capture_candidates]
   (port.capture_surfaces). *)
let capture_offer_id (player: player) (monster_id: string) : string option =
  if monster_id = "" then None
  else
    (try
       ignore (Campaign_monsters.monster_by_id monster_id);
       if capture_eligible player monster_id
          && not (List.mem monster_id player.captives)
       then Some monster_id
       else None
     with Not_found -> None)

let capture_offer (player: player) (enc: encounter) : string option =
  if enc.sprite = "" then None
  else
    (try
       capture_offer_id player (Campaign_monsters.monster_by_sprite enc.sprite).id
     with Not_found -> None)

(* Every enemy the [CAPTURE_LISTHELP] gates hold for and the hero does not
   hold yet, in registry order - the rows the city Pets tab offers. *)
let capture_candidates (player: player) : string list =
  List.map
    (fun (m : Campaign_monsters.monster) -> m.id)
    (List.filter
       (fun (m : Campaign_monsters.monster) ->
          capture_eligible player m.id && not (List.mem m.id player.captives))
       Campaign_monsters.monsters)

(* The callback's own gate: a fight the stage allows captured (cb_capture -
   QUEST_BATTLE_NOCAPTURE rows say no), won, with both [CAPTURE_LISTHELP]
   gates holding after the settle recorded this defeat. Split from
   execute_callback so the NOCAPTURE rule is testable without winning a
   140-life fight under the auto-AI. *)
let callback_capture_offer (player: player) ~(won: bool) ~(capture: bool)
    (monster_id: string) : string option =
  if won && capture then capture_offer_id player monster_id else None

(* ------------------------------------------------------------------ *)
(* Runes and the forge                                                 *)
(* ------------------------------------------------------------------ *)

(* [RUNE_HELP]: "You must defeat this guardian to claim the Rune." The
   guardian fight surface is not wired yet (GAPS), so the gate is what the
   table states and the port can already hold: the rune exists, it is a
   world drop (location <> "" - the three gifted runes sit nowhere), the
   hero stands at that node, and does not hold it. The guard-monster check
   rides along with the fight when that surface lands. *)
let rune_claimable (p: player) (rune_id: string) : bool =
  match Campaign_runes.rune_by_id rune_id with
  | None -> false
  | Some k ->
    let loc = Campaign_runes.rune_location k in
    loc <> "" && p.current_city = Some loc
    && not (List.mem rune_id p.runes)

let claim_rune (p: player) (rune_id: string) : player option =
  if rune_claimable p rune_id then
    Some { p with runes = rune_id :: p.runes }
  else None

(* Every rune the hero holds, registry order - bases, then modifiers,
   then powers - the way the forge list shows them. *)
let held_runes (p: player) : Campaign_runes.rune_kind list =
  List.filter
    (fun k -> List.mem (Campaign_runes.rune_id k) p.runes)
    (List.map (fun r -> Campaign_runes.Base_rune r) Campaign_runes.base_runes
     @ List.map
         (fun r -> Campaign_runes.Modifier_rune r)
         Campaign_runes.modifier_runes
     @ List.map (fun r -> Campaign_runes.Power_rune r) Campaign_runes.power_runes)

(* The rune whose world drop sits at this node, if any: the 35 guarded
   runes each own their location, so a node answers one. *)
let rune_at_node (node: string) : string option =
  if node = "" then None
  else
    List.find_map
      (fun k ->
        if Campaign_runes.rune_location k = node then
          Some (Campaign_runes.rune_id k)
        else None)
      (List.map (fun r -> Campaign_runes.Base_rune r) Campaign_runes.base_runes
       @ List.map
           (fun r -> Campaign_runes.Modifier_rune r)
           Campaign_runes.modifier_runes
       @ List.map
           (fun r -> Campaign_runes.Power_rune r)
           Campaign_runes.power_runes)

(* The guardian fight at a rune's node, as a road encounter: the shipped
   encounter type is a sprite and a level, so the keeper fight is the
   guard monster under the [RUNEKEEPER] name. *)
let runekeeper_encounter (rune_id: string) : encounter option =
  match Campaign_runes.rune_by_id rune_id with
  | None -> None
  | Some k -> (
    let guard = Campaign_runes.rune_guard k in
    if guard = "" then None
    else
      try
        let m = Campaign_monsters.monster_by_id guard in
        Some
          { Campaign_encounters.id = "RUNEKEEPER";
            description = Text_data.text "[RUNEKEEPER]";
            start = "";
            end_ = Campaign_runes.rune_location k;
            index = 0;
            sprite = m.Campaign_monsters.sprite;
            lua_file = "";
            lua_object = "";
            my_level = m.Campaign_monsters.level_base;
            chance = 0 }
      with Not_found -> None)

(* What the forge builds from three held runes. The (base, modifier) pair
   picks the item's name and icon from the shipped 150-row table, the base
   its slot (position), and the modifier edits both data values exactly as
   its own description states - UMAS "Adds +2 to Base Rune ability",
   UCHA "Adds -1 to Base Rune ability and adds +150% to Power Rune
   ability" - so base' = base.data * data_mult + data_add and power'
   likewise with the power fields. The difficulty stacks both diff fields
   scaled by the modifier's multiplier; the ten [FORGEITEMS_TARGET*]
   bands that read it arrive with the forge UI (port.rune_forge_formula
   records the stack and the rounding). *)
type forge_spec = {
  name_text: string;
  icon: int;
  position: string;
  base_data: int;
  power_data: int;
  difficulty: int;
}

let forge_spec_of ~(base: string) ~(modifier: string) ~(power: string) :
    forge_spec option =
  match
    ( (try Some (Campaign_runes.base_by_id base) with Not_found -> None),
      (try Some (Campaign_runes.modifier_by_id modifier)
           with Not_found -> None),
      (try Some (Campaign_runes.power_by_id power) with Not_found -> None),
      Campaign_runes.forged_name_of base modifier )
  with
  | Some b, Some m, Some pw, Some n ->
    let base_data =
      int_of_float (float_of_int b.Campaign_runes.data
                    *. m.Campaign_runes.data_mult)
      + m.Campaign_runes.data_add
    in
    let power_data =
      int_of_float
        (Float.round (float_of_int pw.Campaign_runes.data
                      *. m.Campaign_runes.power_mult))
      + m.Campaign_runes.power_add
    in
    let difficulty =
      int_of_float
        (Float.round
           (float_of_int
              (b.Campaign_runes.diff_add + m.Campaign_runes.diff_add)
            *. m.Campaign_runes.diff_mult))
    in
    Some
      { name_text = n.Campaign_runes.name_text;
        icon = n.Campaign_runes.icon;
        position = b.Campaign_runes.position;
        base_data;
        power_data;
        difficulty }
  | _ -> None

(* The held-rune gate over the same arithmetic. *)
let forge_rune (p: player) ~(base: string) ~(modifier: string)
    ~(power: string) : forge_spec option =
  if
    List.mem base p.runes && List.mem modifier p.runes
    && List.mem power p.runes
  then forge_spec_of ~base ~modifier ~power
  else None

(* The [FORGEITEMS_TARGET0..9] band a difficulty falls in: ten equal
   sixty-point steps. The exe's own thresholds are not recovered, so the
   bucketing is a port choice (port.forge_ui); every shipped combination
   lands between 100 and 600. *)
let forge_band (difficulty: int) : int =
  max 0 (min 9 (difficulty / 60))

(* Fill one %d in a shipped string; the descs carry %% where the display
   wants a single percent. Printf.sprintf will not take a tag that only
   becomes a format after Text_data resolves it. *)
let fill_int (pat: string) (n: int) : string =
  let filled =
    match String.index_opt pat '%' with
    | Some i when i + 1 < String.length pat && pat.[i + 1] = 'd' ->
      String.sub pat 0 i ^ string_of_int n
      ^ String.sub pat (i + 2) (String.length pat - i - 2)
    | _ -> pat
  in
  let b = Buffer.create (String.length filled) in
  let i = ref 0 in
  while !i < String.length filled do
    if
      !i + 1 < String.length filled && filled.[!i] = '%'
      && filled.[!i + 1] = '%'
    then begin
      Buffer.add_char b '%';
      i := !i + 2
    end
    else begin
      Buffer.add_char b filled.[!i];
      incr i
    end
  done;
  Buffer.contents b

(* What the battle's runtime hooks read for a minted item: JXXX's codes
   and the modifier-edited data, plus the panel facts the item view and
   the loadout need. The r_ prefix keeps the labels clear of forge_spec's
   (name_text, icon, position) and the item table's. *)
type rune_item_params = {
  r_base_code: string;
  r_base_data: int;
  r_power_code: string;
  r_power_data: int;
  r_position: string;
  r_icon: int;
}

(* The in-session registry of minted items, keyed by id. The id encodes
   the triple ("R" ^ base ^ modifier ^ power), so a save's inventory can
   rebuild one without this table - see [rebuild_rune_item] - and the
   table is what the loadout's runtime builder and Item_hooks' start
   payoffs read while the session runs. *)
let rune_item_specs : (string, rune_item_params) Hashtbl.t = Hashtbl.create 32

let rune_minted_id (base: string) (modifier: string) (power: string) : string
    =
  "R" ^ base ^ modifier ^ power

(* The minted item, computed from the triple alone: the same arithmetic
   as [forge_rune], then the [Campaign_items.item] view - name and icon
   from the (base, modifier) table, the slot from the base, and the power
   text both abilities with their data filled, base first
   (port.rune_item_mint). *)
let rune_item_of_triple ~(base: string) ~(modifier: string)
    ~(power: string) : (item * rune_item_params) option =
  match forge_spec_of ~base ~modifier ~power with
  | None -> None
  | Some s ->
    let b = Campaign_runes.base_by_id base in
    let pw = Campaign_runes.power_by_id power in
    let params =
      { r_base_code = b.Campaign_runes.code;
        r_base_data = s.base_data;
        r_power_code = pw.Campaign_runes.code;
        r_power_data = s.power_data;
        r_position = s.position;
        r_icon = s.icon }
    in
    let it =
      { id = rune_minted_id base modifier power;
        name_text = s.name_text;
        power_text =
          fill_int
            (String.trim (Text_data.text b.Campaign_runes.desc_text))
            s.base_data
          ^ " "
          ^ fill_int
              (String.trim (Text_data.text pw.Campaign_runes.desc_text))
              s.power_data;
        location = s.position;
        cost = 0;
        rarity = 0;
        icon = s.icon;
        restriction_type = "none";
        lua_file = "Assets\\Runes\\JXXX.lua";
        lua_object = "JXXX";
        lua_source = "" }
    in
    Some (it, params)

(* Publish a mint: the session registry plus the start payoffs JXXX's
   OnStartBattle runs - powers 0-3 credit POWERDATA of that mana, 4
   raises max life and life (ceiling first, the way the walls do). *)
let register_rune_item (id: string) (p: rune_item_params) : unit =
  Hashtbl.replace rune_item_specs id p;
  let payoffs =
    match p.r_power_code with
    | "0" -> [ Item_hooks.AddMana (Combat.Fire, p.r_power_data) ]
    | "1" -> [ Item_hooks.AddMana (Combat.Earth, p.r_power_data) ]
    | "2" -> [ Item_hooks.AddMana (Combat.Air, p.r_power_data) ]
    | "3" -> [ Item_hooks.AddMana (Combat.Water, p.r_power_data) ]
    | "4" ->
      [ Item_hooks.AddMaxLife p.r_power_data; Item_hooks.AddLife p.r_power_data ]
    | _ -> []
  in
  Hashtbl.replace Item_hooks.rune_start_payoffs id payoffs

(* The [MAXRUNEITEM] cap: how many minted rune items the inventory holds
   before the forge refuses ("You must sell some in the shop before creating
   any more", [MAXRUNEITEM0/1]). The count is minted ids - "R" + the triple,
   which no fixed item's id can collide with. The NUMBER is a port choice:
   the exe answers no strings for the item game and its RTTI is orphaned, so
   the threshold is unrecovered (forge.item_game_numbers); 10 is a round
   bound well above what one quest's runes can mint. *)
let rune_item_cap = 10

let rune_item_count (p: player) : int =
  List.length
    (List.filter
       (fun (i: item) -> String.length i.id > 0 && i.id.[0] = 'R')
       p.inventory)

(* Forge for keeps: the item joins the inventory (once - [RUNEDUP_TEXT]:
   a duplicate yields no extra copy) and the session registry. The
   [MAXRUNEITEM] cap refuses the creation outright, so a driver that only
   reads the option still cannot blow past it. *)
let forge_item (p: player) ~(base: string) ~(modifier: string)
    ~(power: string) : (player * item) option =
  if rune_item_count p >= rune_item_cap then None
  else if
    List.mem base p.runes && List.mem modifier p.runes
    && List.mem power p.runes
  then
    match rune_item_of_triple ~base ~modifier ~power with
    | None -> None
    | Some (it, params) ->
      register_rune_item it.id params;
      let p =
        if List.exists (fun (i: item) -> i.id = it.id) p.inventory then p
        else { p with inventory = it :: p.inventory }
      in
      Some (p, it)
  else None

(* Rebuild a minted item from its id, the way a loaded save does: the id
   encodes the triple, so the arithmetic and the registry come back
   without the session that minted it. *)
let rebuild_rune_item (id: string) : item option =
  if String.length id = 13 && id.[0] = 'R' then
    let base = String.sub id 1 4 in
    let modifier = String.sub id 5 4 in
    let power = String.sub id 9 4 in
    match rune_item_of_triple ~base ~modifier ~power with
    | Some (it, params) ->
      register_rune_item it.id params;
      Some it
    | None -> None
  else None

(* An inventory or slot id back to its item: the fixed table first, then
   a minted rune rebuilt from the id. Unknown ids still raise. *)
let resolve_item (id: string) : item =
  try item_by_id id
  with Not_found -> (
    match rebuild_rune_item id with
    | Some it -> it
    | None -> raise Not_found)

(* A minted item as the battle's runtime item: JXXX's OnGiveDamage reads
   the base code (0/1 add BASEDATA on hits of 3+, 9 on hits of 6+) and
   the start payoffs ride Item_hooks' rune table. Base D (damage per full
   mana pool) needs the max-mana caps the loop does not model, base E's
   reflect damages the attacker outside the damage-transform signature,
   and powers 9/A want a per-event percentile - the same three absences
   [Item_hooks] documents for the fixed items, so those runes forge but
   their bodies stay quiet. *)
let runtime_rune_item (id: string) : Item.item option =
  match Hashtbl.find_opt rune_item_specs id with
  | None -> None
  | Some p ->
    let location =
      match p.r_position with
      | "weapon" -> Item.Weapon
      | "head" -> Item.Head
      | "body" -> Item.Body
      | _ -> Item.Misc
    in
    let d =
      { Item.id;
        location;
        shop_cost = 0;
        rarity = 0;
        icon = p.r_icon;
        restriction = Item.NoRequirement;
        on_start_battle =
          (match p.r_power_code with "0" | "1" | "2" | "3" | "4" -> true | _ -> false) }
    in
    let give =
      match p.r_base_code with
      | "0" | "1" ->
        Some
          (fun (_ctx: Item.item_context) dmg _src _tgt ->
            if dmg >= 3 then dmg + p.r_base_data else dmg)
      | "9" ->
        Some
          (fun (_ctx: Item.item_context) dmg _src _tgt ->
            if dmg >= 6 then dmg + p.r_base_data else dmg)
      | _ -> None
    in
    Some
      (Item.make_item
         ~hooks:{ Item.no_hooks with Item.on_give_damage = give }
         d)

(* ------------------------------------------------------------------ *)
(* Battle Integration *)
(* ------------------------------------------------------------------ *)

(* Convert campaign player to battle combatant *)
let to_combat_skills (s: skill_affinities) : skills =
  { earth = s.earth; fire = s.fire; air = s.air; water = s.water;
    battle = s.battle; morale = s.morale; cunning = s.cunning }

let player_to_combatant (p: player) : combatant =
  (* The ridden mount's skill bonus rides the combatant only - mounting and
     dismounting never rewrite player.skills, the profession base
     (port.mount_skill_formula). *)
  let sk = add_skill_affinities p.skills (mount_skill_bonus p) in
  make_combatant
    ~cunning:sk.cunning
    ~skills:(to_combat_skills sk)
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
   placement, so the panel's extra fields (gauntlets, rings, mount, companion)
   fold in by whatever location they carry. Two items of one location leave the
   later field's in the slot; that is a choice, since the engine's own fold is
   not recovered. No banner field: nothing in the shipped game ever fills one
   (port.banner_slot_removed). *)
let loadout_of_equipment (e: equipment) : Item.loadout =
  let l = Item.new_loadout () in
  List.iter
    (fun (slot : Campaign_items.item option) ->
      match slot with
      | None -> ()
      | Some ci ->
        (match
           (match runtime_rune_item ci.Campaign_items.id with
           | Some it -> Some it
           | None -> Item_hooks.item_of_id ci.Campaign_items.id)
         with
         | None -> ()
         | Some i -> ignore (Item.equip l i)))
    [ e.weapon; e.armor; e.helm; e.gauntlets; e.ring1; e.ring2;
      e.mount; e.companion ];
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

(* The rules a campaign fight runs under. One of [default_rules]' fields stops
   being a default here: the hero's own level, which the board evaluator reads
   for its hero-level band. [hero_level_cap] stays at the default because
   nothing recovered says what the engine passes.

   Difficulty does NOT come from the levels - it is the player's Easy/Normal/
   Hard option, the second dropdown the single-player hero view offers next to
   the turn Time Limit. The original keeps it in the registry value
   "Difficulty" under `Software\Infinite Interactive\Puzzle Quest` (0x4223c2
   reads it into the global battle start copies into CBattleManager.m_difficulty
   at 0x44bb39; the settings object holds it at +0x74 beside "Time Limit" at
   +0x70 and defaults it to 1 at 0x43729e). [AILEVEL1] is "Normal",
   [AILEVEL0]/[AILEVEL2] carry the -/+25% XP the choice buys. It gates the
   AI's spell skip, the evaluator's jitter and the results screen's scaling -
   never the hero/task gap: [Spell.difficulty_for_levels], the level-band
   helper, has no caller anywhere in the shipped corpus (quest.difficulty_
   consumers). The choice lives in this ref (the settings default, three values
   0..2 as the dropdown has three rows) and the port's Settings screen sets it;
   port.difficulty_source / port.settings_surface. *)
let difficulty : int ref = ref 1

let set_difficulty (d : int) : unit = difficulty := max 0 (min 2 d)

(* The Turn Time Limit, the other dropdown the single-player hero view offers
   beside Difficulty (SinglePlayerMenu.xml: drop_timelimit rows [TIMELIMIT0..4]
   = None/16/12/8/4 sec, drop_difficulty rows [AILEVEL0..2]). The original keeps
   it in the settings object at +0x70 beside Difficulty at +0x74, defaulting to 0
   (0x43729e writes [+0x74]=1, [+0x70]=0), machine-wide in the registry like
   Difficulty. Battle start copies it into turn_manager+0x34 (Sub_44a780.c:651,
   the same function that copies Difficulty into CBattleManager+0x48): the turn
   clock's delay table reads it ({0,16000,12000,8000,4000} ms, exactly
   [TIMELIMIT0..4], with a negative value meaning custom seconds) and the victory
   spoils pay (setting x 5)% for it - 0/5/10/15/20%. The port has no turn clock,
   so this drives only the spoils term; the countdown on the battle plates and
   the timeout remain open (see forge.item_game_numbers' sibling below and
   [Battle.rules.time_limit]). Five values, 0..4, as the dropdown has five rows.
   port.settings_surface. *)
let timelimit : int ref = ref 0

let set_timelimit (t : int) : unit = timelimit := max 0 (min 4 t)

let rules_for_battle ~(player: player) : Battle.rules =
  { Battle.default_rules with
    difficulty = !difficulty;
    time_limit = !timelimit;
    hero_level = player.level }

(* The same rules with a playable front's mouse-backed choices installed in
   [Battle.rules.player]: [Some hooks] is a fight the player plays, [None] the
   auto-AI on both sides, which is what the headless path and every test drive.
   A separate function rather than [?human] on [rules_for_battle] because an
   optional argument before only-labeled ones is never erased, and every
   existing call site omits it. *)
let playable_rules (human : Battle.player option) ~(player: player)
    : Battle.rules =
  match human with
  | None -> rules_for_battle ~player
  | Some h -> { (rules_for_battle ~player) with player = Some h }

(* Open a battle between player and encounter: the hero walks in with the
   spells the player knows and the monster with its own registry roster -
   the loadout choice recorded in port.quest_battle_loop, shared with the
   quest path below - at the difficulty the player's option asks for.
   Split from [run_encounter_battle] so a playable front can host the fight
   itself: [?human] puts the mouse-backed choices in the rules, the caller
   runs the returned un-run battle on its own screen, then settles it through
   [process_battle_result]. [None] when the encounter's sprite names no
   registry monster - the headless runner re-raises [Not_found], as it did
   before the split. *)
let encounter_battle_open ?rng ?human (player: player) (enc: encounter)
    : battle option =
  match
    (try Some (Campaign_monsters.monster_by_sprite enc.sprite)
     with Not_found -> None)
  with
  | None -> None
  | Some monster ->
    let hero = player_to_combatant player in
    let enemy = encounter_to_combatant enc player.level in
    Some
      (open_battle ?rng
         ~rules:(playable_rules human ~player)
         ~hero ~enemy
         ~hero_spells:(spells_of_ids
           (mount_spell_ids player @ player.known_spells))
         ~enemy_spells:(spells_of_ids monster.spells)
         ~hero_items:(loadout_of_equipment player.equipment)
         ~enemy_tags:(monster_type_tags monster)
         ~companions:player.companions ())

let run_encounter_battle ?rng ?human (player: player) (enc: encounter) : battle =
  match encounter_battle_open ?rng ?human player enc with
  | Some b -> Battle.run b
  | None -> raise Not_found

(* The training attempt behind [TRAINMOUNTS_DETAIL]: the mount's own kind
   at the next level, run as a normal headless fight - trained only when
   the hero wins inside the turn budget the seconds translate to. The
   level lands as the new mount level ([TRAINMOUNTS_SUCCESS] carries it);
   a failure changes nothing but answers with the battle for the report.
   None means the id is not one of your rideable mounts. *)
let train_mount ?(rng = Random.int) (player: player) (mid: string)
    : (player * battle * bool) option =
  match training_challenge player mid with
  | None -> None
  | Some ch -> (
    match
      (try Some (Campaign_monsters.monster_by_id mid) with Not_found -> None)
    with
    | None -> None
    | Some m ->
      let hero = player_to_combatant player in
      let enemy = monster_to_combatant m ch.creature_level in
      let b =
        Battle.run
          (open_battle ~rng
             ~rules:(rules_for_battle ~player)
             ~hero_spells:(spells_of_ids
               (mount_spell_ids player @ player.known_spells))
             ~enemy_spells:(spells_of_ids m.spells)
             ~hero_items:(loadout_of_equipment player.equipment)
             ~hero ~enemy
             ~enemy_tags:(monster_type_tags m)
             ~companions:player.companions ())
      in
      let trained =
        Battle.hero_won b && b.Battle.turns_elapsed <= ch.turn_limit
      in
      let player =
        if trained then
          { player with mount_levels =
              (mid, ch.creature_level)
              :: List.filter (fun (id, _) -> id <> mid) player.mount_levels }
        else player
      in
      Some (player, b, trained))

(* The victory spoils from FUN_0043E400: the defeated monster's carried gold
   and xp, rolled from its Reward range (mingold..maxgold, minxp..maxxp as the
   XML loader stores them), then three scales in the engine's own order - the
   anti-farm level gap, the Time Limit bonus ((setting x 5)%, paid for a more
   frantic clock), and the Difficulty option's +/-25%. Paid only on a decisive
   victory; see the retired question xp.difficulty_scaling and
   Score.time_limit_scale in docs/reverse/evidence.yml. *)
let spoils_of_victory (rng: int -> int) ~(hero_level: int)
    (m: Campaign_monsters.monster) ~(difficulty: int) ~(time_limit: int)
    : int * int =
  let roll lo hi = if hi <= lo then lo else rng (hi - lo + 1) + lo in
  let gold = roll m.Campaign_monsters.mingold m.Campaign_monsters.maxgold in
  let xp = roll m.Campaign_monsters.minxp m.Campaign_monsters.maxxp in
  let enemy_level = m.Campaign_monsters.level_base in
  let gold = Score.level_gap_scale ~hero_level ~enemy_level gold in
  let xp = Score.level_gap_scale ~hero_level ~enemy_level xp in
  let gold = Score.time_limit_scale ~time_limit gold in
  let xp = Score.time_limit_scale ~time_limit xp in
  (Score.compute_victory_spoils ~game_mode:0 ~difficulty gold,
   Score.compute_victory_spoils ~game_mode:0 ~difficulty xp)

(* Process battle result and update player/quest state *)
type battle_result = {
  player_won: bool;
  gold_gained: int;
  xp_gained: int;
  final_life: int;
}

let process_battle_result (player: player) (enc: encounter) (battle: battle) : player * battle_result =
  let hero = battle.hero in
  let player_won = Battle.hero_won battle in
  let monster =
    if enc.sprite <> "" then
      (try Some (Campaign_monsters.monster_by_sprite enc.sprite) with Not_found -> None)
    else None
  in
  (* a decisive win also pays the spoils of the defeated monster, reading the
     two settings off the battle the engine copied them into at start (the
     +0x48 / +0x34 analogue) rather than the live refs *)
  let spoils =
    if player_won then
      match monster with
      | Some m ->
        spoils_of_victory battle.rng ~hero_level:player.level m
          ~difficulty:battle.Battle.rules.difficulty
          ~time_limit:battle.Battle.rules.time_limit
      | None -> (0, 0)
    else (0, 0)
  in
  let gold_gained = battle.gold + fst spoils in
  let xp_gained = battle.xp + snd spoils in
  let new_player = {
    player with
      gold = player.gold + gold_gained;
      xp = player.xp + xp_gained;
      life = hero.life;
    } in
  (* a road win counts toward capture eligibility *)
  let new_player =
    if player_won then
      match monster with
      | Some m -> record_defeat new_player m.id
      | None -> new_player
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
    (* [COMPANIONS_HELP]: "You can have up to 8 companions at a time."
       The grant fills the roster unconditionally - [COMPANIONSTATUS_NEW0]
       refuses the ninth only from the party, which is the equipped set. *)
    let roster =
      if List.mem companion_id p.recruited_companions then p.recruited_companions
      else companion_id :: p.recruited_companions
    in
    if List.mem companion_id p.companions || List.length p.companions >= 8
    then { p with recruited_companions = roster }
    else { p with recruited_companions = roster;
                  companions = companion_id :: p.companions }
  | RemoveCompanion companion_id ->
    (* Leaving the party, not the roster: [COMPANIONSTATUS_OUT0] still
       knows where they live. *)
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

(* ------------------------------------------------------------------ *)
(* Companion equip: the party is the equipped subset of the roster.     *)
(* [COMPANIONS_HELP]: "Most others can be left at a location and        *)
(* picked up later" - [COMPANIONSTATUS_OUT1] gates the pickup on the    *)
(* companion's home, which is the only location the registry carries.   *)
(* ------------------------------------------------------------------ *)

type companion_slot =
  | Traveling                    (* in the party: its OnStartBattle hook fires *)
  | At_home                      (* recruited, standing at home, party has room *)
  | At_home_full                 (* recruited, at home, party full: [COMPANIONSTATUS_NEW0] *)
  | Away of string               (* recruited, elsewhere: home id, [COMPANIONSTATUS_OUT0] *)
  | Not_recruited                (* never granted *)

let companion_home (cid: string) : string =
  try (Campaign_companions.companion_by_id cid).home with Not_found -> ""

let companion_slot (p: player) (cid: string) : companion_slot =
  if List.mem cid p.companions then Traveling
  else if not (List.mem cid p.recruited_companions) then Not_recruited
  else if p.current_city = Some (companion_home cid) then
    if List.length p.companions < 8 then At_home else At_home_full
  else Away (companion_home cid)

(* Equipping a companion: they join the party where they live, and only
   there. Unequip is free - [COMPANIONS_HELP] lets you leave anyone at
   wherever you stand. Both no-op on a refusal, so a driver that read
   [companion_slot] cannot double-apply. *)
let add_companion (p: player) (cid: string) : player =
  match companion_slot p cid with
  | At_home -> { p with companions = cid :: p.companions }
  | _ -> p

let remove_companion (p: player) (cid: string) : player =
  { p with companions = List.filter (fun c -> c <> cid) p.companions }

(* ------------------------------------------------------------------ *)
(* Pending conversations                                                 *)
(* ------------------------------------------------------------------ *)

(* Conversation ids the quest engine has queued for the player: OnBegin
   intros, OnEnterLocation arrivals, OnAbandon epilogues (the shipped data
   has none, the field exists for completeness), and the nested
   QUEST_CONVERSATION sites inside conversation callbacks. The UI layer
    drains them one at a time (campaign_demo prints them; pq_conv_gfx polls).
    The location-action flow (execute/complete/enter effects) queues the same
    way. Stored as ids, not records: resolving the id to conversation data
    stays with whoever displays it. *)
let pending_conversations : string list ref = ref []

let queue_conversation (conv_id : string) : unit =
  pending_conversations := !pending_conversations @ [conv_id]

let take_pending_conversation () : string option =
  match !pending_conversations with
  | [] -> None
  | conv :: rest -> pending_conversations := rest; Some conv

(* A message box queued by an extracted ShowMessage effect - a
   QUEST_MESSAGE(_CALLBACK) site in a callback body or in one of the
   location-action hooks. Title and text are text tags (resolve with
   Text_data.text), [pmsg_quest] the quest whose script posted it, and
   [pmsg_callback] the callback to fire when the box is dismissed ("" when
   the site carried none). Same drain discipline as conversations: the UI
   pops one at a time, closing it with [take_pending_message] (and firing
   the callback through [execute_callback] when there is one). *)
type pending_message = {
  pmsg_title : string;
  pmsg_text : string;
  pmsg_quest : string;
  pmsg_callback : string;
}

let pending_messages : pending_message list ref = ref []

let queue_message ~(qid : string) ?(callback : string = "") (title : string)
    (text : string) : unit =
  pending_messages :=
    !pending_messages
    @ [ { pmsg_title = title; pmsg_text = text; pmsg_quest = qid;
          pmsg_callback = callback } ]

let take_pending_message () : pending_message option =
  match !pending_messages with
  | [] -> None
  | m :: rest -> pending_messages := rest; Some m

(* [enter_location] lives at the end of this file with the rest of the
   location-action flow: its enter_effects need apply_callback_effect (and
   quest_turn_in for the few arrival Completes), both defined later. *)

(* ------------------------------------------------------------------ *)
(* Quest lifecycle (player level)                                     *)
(* ------------------------------------------------------------------ *)

(* A companion gate from the extracted guards: every (id, must-be-present)
   must hold against the traveling party ([] = no companion test = ungated).
   Lua's QUEST_HERO_HAS_COMPANION_SELECTED reads the selected hero of the
   single-hero engine; the port reads player.companions. *)
let companion_ok (p : player) (gate : (string * bool) list) : bool =
  List.for_all
    (fun (cid, present) -> List.mem cid p.companions = present)
    gate

(* The engine's per-quest script sandbox: the locals OnSave/OnLoad persist
   (triedToKeepKey, doneConv, doneNecro1, ...). player.quest_vars maps the
   quest id to its var store; an absent var reads 0, the value the scripts
   initialize to before OnBegin resets. quest_accept clears the store -
   a (re)accepted quest runs OnBegin against a fresh script instance. *)
let script_var_get (p : player) (qid : string) (name : string) : int =
  match List.assoc_opt qid p.quest_vars with
  | None -> 0
  | Some vars -> (match List.assoc_opt name vars with None -> 0 | Some v -> v)

let script_var_set (p : player) (qid : string) (name : string) (value : int) :
    player =
  let vars =
    match List.assoc_opt qid p.quest_vars with None -> [] | Some vars -> vars
  in
  let vars = (name, value) :: List.filter (fun (n, _) -> n <> name) vars in
  { p with quest_vars =
             (qid, vars) :: List.filter (fun (q, _) -> q <> qid) p.quest_vars }

(* QUEST_HERO_HAS_ITEM: the traveling inventory, tag by item id. *)
let has_item_tag (p : player) (tag : string) : bool =
  List.exists (fun (it : item) -> it.id = tag) p.inventory

(* One extracted script-var test (name, ~=, value) against the store. *)
let var_test_ok (p : player) (qid : string)
    ((name, neg, value) : string * bool * int) : bool =
  let cur = script_var_get p qid name in
  if neg then cur <> value else cur = value

(* One extracted inventory test (tag, must-have). *)
let item_test_ok (p : player) ((tag, want) : string * bool) : bool =
  has_item_tag p tag = want

(* One nand clause: an earlier arm of an if/elseif/else chain the row sits
   past. The clause "fires" when every dimension it tested holds against
   the event - empty state/location lists mean that dimension was untested
   (matches any), side None no success test (Some _ against a context
   without an outcome cannot fire). A row applies only when NO clause
   fires: the elseif arm runs when the earlier arms did not. *)
let clause_ok (p : player) (qid : string) ~(st : int) ~(loc : string)
    ~(suc : bool option)
    ((stages, locs, side, cnd, vnd, ind) : clause) : bool =
  (match stages with [] -> true | l -> List.mem st l)
  && (match locs with [] -> true | l -> List.mem loc l)
  && (match side, suc with
      | None, _ -> true
      | Some _, None -> false
      | Some want, Some got -> want = got)
  && companion_ok p cnd
  && List.for_all (var_test_ok p qid) vnd
  && List.for_all (item_test_ok p) ind

(* A row's whole arm conjunction: the pretty companion gate plus the
   script-var / inventory tests its header carried against the LIVE
   accumulator, and every earlier-arm clause failing (clause_ok = the
   clause fires = the row is blocked). The clauses test the fold-ENTRY
   snapshot [snap]: they re-check the predecessor arm's key as the chain
   saw it, so an earlier arm's SetQuestState / remove_companion cannot
   unblock a sibling arm of its own if/elseif chain (Q1S0, Q1G3, Q3S0). *)
let cond_ok (p : player) (snap : player) (qid : string) ~(st : int)
    ~(loc : string) ~(suc : bool option)
    ((cnd, vnd, ind, ncl) :
       (string * bool) list * (string * bool * int) list *
       (string * bool) list * clause list) : bool =
  companion_ok p cnd
  && List.for_all (var_test_ok p qid) vnd
  && List.for_all (item_test_ok p) ind
  && List.for_all (fun cl -> not (clause_ok snap qid ~st ~loc ~suc cl)) ncl

(* Accept a quest: runs OnBegin (node reveals + ruin registration) and adds
   it to active_quests at state 1. The OnBegin intro conversation queues for
   the UI - the first begin row whose companion gate holds against the
   accepting party (the if/else trees take the first source-order row that
   fires, same convention as the reward fields; Q0Q8 and Q3Q6 open only
   with their companion along). No-op if the quest isn't available. *)
let quest_accept (player: player) (qid: string) : player =
  let q = quest_by_id qid in
  if not (is_quest_available player q) then player
  else
    let qi = { quest = q; state = Inactive; vars = [] } in
    let _qi, effects = run_quest_on_begin qi in
    let p = List.fold_left apply_quest_effect player effects in
    if List.exists (fun (id, _) -> id = qid) p.active_quests then p
    else begin
      (match List.find_opt
               (fun (_, gate) -> companion_ok p gate)
               q.conversations_begin with
       | Some (conv, _) -> queue_conversation conv
       | None -> ());
      { p with active_quests = (qid, 1) :: p.active_quests;
               (* re-accept = fresh script instance: the sandbox resets *)
               quest_vars = List.filter (fun (q, _) -> q <> qid) p.quest_vars }
    end

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
   fail-branch state (battle_stage_fails) applies when there is one - Q2M4
    retries its lost fight from state 2; a quest with no fail entry keeps
    its stage (Q0E0 shows a message and stays; Q0Q7's Dugog fight at state
    3 stays 3 on a loss while a win walks to 4, where the same fight
    repeats until a win walks on to 5).

   [?capture] and [?monster] override that stage-derived defeat record for
   conversation/message callback battles: their monster and capture flag
   belong to the callback's own QUEST_BATTLE primitive (Q1Q6/CallbackConvB
   is a NOCAPTURE fight against MGUU, not the stage's MSCO), while the
   stage advance still runs - the engine fires OnCompleteAction after a
   callback battle returns to the map too (Q3Q5 sets doneNecro there). Both
   overrides travel together; given one without the other falls back to the
   stage's own pair. *)
let quest_battle_complete ?capture ?monster (player: player) (qid: string)
    (success: bool) : player =
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
        match capture, monster with
        | Some c, Some m -> c, m
        | _ ->
          (match List.find_opt
                   (fun (st, _, _, cnd, vnd, ind, ncl) ->
                      st = stage
                      && cond_ok player player qid ~st:stage ~loc:""
                           ~suc:(Some true)
                           (cnd, vnd, ind, ncl))
                   q.battle_actions with
           | Some (_, idx, cap, _, _, _, _) ->
             let m = match List.nth_opt q.battles idx with
               | Some (mid, _) -> mid
               | None -> q.battle_monster
             in
             cap, m
           | None -> true, q.battle_monster)
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

(* The monster a quest battle fights, resolved the way quest_battle_complete
   resolves it: the current stage's battle action when one matches, else the
   quest's default battle_monster. None when the quest is inactive or the id is
   empty. Separated so the spoils settle and the completion bookkeeping agree
   on which monster was defeated. *)
let quest_battle_monster (player: player) (qid: string) : string option =
  match List.assoc_opt qid player.active_quests with
  | None -> None
  | Some stage ->
    let q = quest_by_id qid in
    let mid =
      match List.find_opt
              (fun (st, _, _, cnd, vnd, ind, ncl) ->
                 st = stage
                 && cond_ok player player qid ~st:stage ~loc:""
                      ~suc:(Some true)
                      (cnd, vnd, ind, ncl))
              q.battle_actions with
      | Some (_, idx, _, _, _, _, _) ->
        (match List.nth_opt q.battles idx with
         | Some (mid, _) -> mid
         | None -> q.battle_monster)
      | None -> q.battle_monster
    in
    if mid = "" then None else Some mid

(* Settle a finished quest battle against the player: life follows the fight
   either way, a win also takes the battle spoils - the match harvest (gold
   and xp, as a road win does) plus the defeated monster's carried spoils - then
   quest_battle_complete runs the stage, capture and ruin bookkeeping
   ([?capture]/[?monster] pass through for callback battles).
   Split from run_quest_battle so both outcomes can be driven
   directly - the auto-AI loses most fights at the heroes the data hands it,
   and the win bookkeeping has to be testable regardless. *)
let quest_battle_settle ?capture ?monster (player: player) (qid: string)
    (success: bool) (b: battle) : player =
  let p = { player with life = b.hero.life } in
  let p =
    if success then
      let mid = match monster with
        | Some m when m <> "" -> Some m
        | _ -> quest_battle_monster player qid
      in
      let spoils =
        match mid with
        | Some mid ->
          (try
             let m = Campaign_monsters.monster_by_id mid in
             spoils_of_victory b.rng ~hero_level:player.level m
               ~difficulty:b.Battle.rules.difficulty
               ~time_limit:b.Battle.rules.time_limit
           with Not_found -> (0, 0))
        | None -> (0, 0)
      in
      { p with gold = p.gold + b.gold + fst spoils; xp = p.xp + b.xp + snd spoils }
    else p
  in
  quest_battle_complete ?capture ?monster p qid success

(* What an open quest-stage fight hands a playable front: the un-run battle -
   with the human's choices in its rules when [?human] was given - and the
   finish that settles it. Split from [run_quest_battle] so the map can play
   the stage's fight on the battle screen and only then settle, the way the
   headless path does in one call. The capture offer the win makes available
   comes back with the settled player, computed where the stage's capture flag
   and the monster id live - the same two gates a callback's offer rides
   (port.capture_surfaces), after the settle has recorded this defeat. *)
type quest_fight = {
  qf_battle : battle;  (** un-run; run it, then hand it to [qf_finish] *)
  qf_finish : battle -> player * string option;
      (** the settled player plus the capture offer, from the finished fight *)
}

(* Open the quest battle for the player's current stage of [qid]: the stage
   picks the action, the action's index picks the <Battle> element (monster
   roster plus the hero's spell line-up for this fight), companion
   OnStartBattle hooks fire as they do on the road. Returns None when the
   quest is not active, the stage has no battle of its own (conversation-
   driven fights are not wired to the state machine - see GAPS), or the
   monster id is not in the registry. *)
let quest_battle_open ?(rng = Random.int) ?human (player: player)
    (qid: string) : quest_fight option =
  match List.assoc_opt qid player.active_quests with
  | None -> None
  | Some stage ->
    let q = quest_by_id qid in
    match List.find_opt
            (fun (st, _, _, cnd, vnd, ind, ncl) ->
               st = stage
               && cond_ok player player qid ~st:stage ~loc:"" ~suc:None
                    (cnd, vnd, ind, ncl))
            q.battle_actions with
    | None -> None
    | Some (_, idx, capture_flag, _, _, _, _) ->
      match List.nth_opt q.battles idx with
      | None -> None
      | Some (monster_id, hero_spell_ids) ->
        match (try Some (Campaign_monsters.monster_by_id monster_id)
               with Not_found -> None) with
        | None -> None
        | Some monster ->
          let hero = player_to_combatant player in
          let enemy = monster_to_combatant monster player.level in
          let b =
            open_battle ~rng
              ~rules:(playable_rules human ~player)
              ~hero_spells:(spells_of_ids
                (hero_spell_ids @ mount_spell_ids player
                 @ player.known_spells))
              ~enemy_spells:(spells_of_ids monster.spells)
              ~hero_items:(loadout_of_equipment player.equipment)
              ~hero ~enemy
              ~enemy_tags:(monster_type_tags monster)
              ~companions:player.companions ()
          in
          Some
            { qf_battle = b;
              qf_finish =
                (fun finished ->
                  let won = Battle.hero_won finished in
                  let p = quest_battle_settle player qid won finished in
                  let offer =
                    callback_capture_offer p ~won ~capture:capture_flag
                      monster_id
                  in
                  (p, offer)) }

let run_quest_battle ?(rng = Random.int) ?human (player: player) (qid: string)
    : (player * battle) option =
  match quest_battle_open ~rng ?human player qid with
  | None -> None
  | Some qf ->
    let finished = Battle.run qf.qf_battle in
    let p, _offer = qf.qf_finish finished in
    Some (p, finished)

(* Turn in a quest: runs OnEnd - rewards, end-of-quest node reveals, and
   CompleteQuest bookkeeping (moves it out of active_quests into
   completed_quests) - plus the extracted end_effects: OnEnd's own
   questState writes and turn-in message box. State-guarded (state -1 = any
   stage); the state writes no-op once CompleteQuest has removed the quest,
   the message queues regardless. No-op if the quest isn't active.

   The effects apply inline rather than through apply_callback_effect, which
   lives later in this file and calls back into quest_turn_in ([Complete]
   behaves as a turn-in) - the two must not recurse. Only SetQuestState and
   ShowMessage occur in end_effects (tools/extract_quests.py --check). *)
let quest_turn_in (player: player) (qid: string) : player =
  if not (List.exists (fun (id, _) -> id = qid) player.active_quests) then player
  else
    let q = quest_by_id qid in
    let qi = { quest = q; state = Active 2; vars = quest_var_set [] "questState" "2" } in
    (* end_effects first: their guards test the stage the fold STARTED at
        (a CompleteQuest inside run_quest_on_end would otherwise have removed
        it); a clause reads the stage as of the last row that fired, so a
        later chain re-testing a state an earlier one wrote still sees it. *)
    let p =
      let rec go snap acc rows =
        match rows with
        | [] -> acc
        | (st, _loc, cnd, vnd, ind, ncl, effs, term) :: rest ->
          let cur =
            match List.assoc_opt qid acc.active_quests with
            | Some s -> s
            | None -> -2
          in
          if (st = -1 || st = cur)
             && cond_ok acc snap qid ~st:cur ~loc:"" ~suc:None
                  (cnd, vnd, ind, ncl) then
            let acc' =
              List.fold_left
                (fun a e ->
                  match e with
                  | SetQuestState n ->
                    { a with active_quests =
                               List.map (fun (id, s) ->
                                   if id = qid then (id, n) else (id, s))
                                 a.active_quests }
                  | ShowMessage (title, text, cb) ->
                    queue_message ~qid ~callback:cb title text; a
                  | _ -> a)
                acc effs
            in
            if term then acc' else go acc acc' rest
          else go snap acc rest
      in
      go player player q.end_effects
    in
    let _qi, effects = run_quest_on_end qi in
    List.fold_left apply_quest_effect p effects

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
      let p = { p with active_quests = List.filter (fun (id, _) -> id <> qid) p.active_quests } in
      (match q.conversations_abandon with
       | conv :: _ -> queue_conversation conv
       | [] -> ());
      p

(* Complete a road encounter: run the battle and apply loot. Road encounters
   are random travel fights; quest progress is driven by quest_battle_complete
   and quest_turn_in (quest Lua calls QUEST_BATTLE for its own fight - road
   wins never advance quest state). *)

(* ------------------------------------------------------------------ *)
(* Conversation/Message callbacks that trigger battles                *)
(* ------------------------------------------------------------------ *)

(* The table and its [callback_battle] type live in Campaign_quests (generated
   by tools/extract_quests.py from unattributed QUEST_BATTLE calls; key:
   (quest_id, callback_name)). This module opens Campaign_quests, so
   [callback_battles] below is that table - do not shadow it with a stub:
   a local [fun _ -> None] makes execute_callback silently return None. *)

(* Apply one extracted effect - from a callback's [callback_effects] row or
   a location-action group. Rewards reuse [apply_quest_effect] so grants run
   through the same inventory/cap/level-up path as turn-in. [SetQuestState]
   writes the active quest's stage directly - apply_quest_effect's SetState
   is a no-op, the lifecycle functions own the stage - and no-ops when the
   quest is not active (the Lua write happened unconditionally, but a
   dialogue for a quest the port dropped cannot advance anything). [Complete]
   ends the quest from dialogue: QUEST_COMPLETE behaves as a turn-in, running
   OnEnd (inferred: OnEnd is documented "called when a quest has ended", ships
   no decompiled body, and quest_turn_in already no-ops when not active).
   [Conversation] queues the next tree; [ShowMessage] queues a message box
   with the callback to fire when it is dismissed. *)
let apply_callback_effect (p : player) (qid : string) (e : callback_effect) : player =
  match e with
  | SetQuestState n ->
    (match List.assoc_opt qid p.active_quests with
     | None -> p
     | Some _ ->
       { p with active_quests =
                  List.map (fun (id, s) -> if id = qid then (id, n) else (id, s))
                      p.active_quests })
  (* the engine's per-quest sandbox write (triedToKeepKey = 1 and friends);
     questState writes ride SetQuestState above, never this arm *)
  | SetVar (name, value) -> script_var_set p qid name value
  | Complete -> quest_turn_in p qid
  | GiveGold n -> apply_quest_effect p (RewardGold n)
  | GiveXp n -> apply_quest_effect p (RewardXP n)
  | GiveItem id -> apply_quest_effect p (RewardItem id)
  | GiveAward id -> apply_quest_effect p (RewardAward id)
  | GiveCompanion id -> apply_quest_effect p (RewardCompanion id)
  | Conversation conv -> queue_conversation conv; p
  | ShowMessage (title, text, cb) ->
    queue_message ~qid ~callback:cb title text; p

(* What a conversation/message callback did: the player with its body's
   effects applied, the battle when it triggered one, and the capture the
   won fight just made available (cb_capture offered, both gates holding,
   enemy not already held) - the surface's offer, computed where the monster
   id and the stage's capture flag live. *)
type callback_result = {
  cb_player : player;
  cb_battle : battle option;
  cb_capture_offer : string option;
}

(* An open callback, split from [execute_callback] so a playable front can
   host the battle: the player with the body's effects already applied, the
   un-run battle when the pair has one ([None] is an effects-only body), and
   the settle that runs the finished fight the way the fused path does - the
   stage advance reading the stage the body left, the defeat record under the
   callback's own capture flag, and the offer after the settle has recorded
   it. [execute_callback] is this plus [Battle.run]. *)
type callback_fight = {
  cf_player : player;  (** the body's effects applied, the fight not run *)
  cf_battle : battle option;  (** the fight to play, when the pair has one *)
  cf_settle : battle -> player * string option;
      (** the settled player plus the capture offer, from the finished fight;
          only meaningful when [cf_battle] is [Some] *)
}

(* Open a conversation/message callback by name. The extracted body effects
   apply first (state writes, grants, nested conversations, QUEST_COMPLETE)
   and the battle - when the callback has one - comes back un-run: that is
   the order the Lua body runs in, so the stage advance that follows reads
   the stage the callback left (Q3D1/CallbackConvB sets 5 before its fight;
   Q1Q6/CallbackConvB has no state write and settles from the stage as
   before). [None] means the pair has neither effects nor a battle - an
   unknown name, or a body only doing bookkeeping the port skips
   (QUEST_UPDATE_MAP, other Lua locals). *)
let callback_open ?(rng = Random.int) ?human (player: player) (qid: string)
    (callback_name: string) : callback_fight option =
  let q_opt = (try Some (quest_by_id qid) with Not_found -> None) in
  let effects :
      ((string * bool) list * (string * bool * int) list *
       (string * bool) list * clause list * callback_effect) list option =
    match q_opt with
    | None -> None
    | Some q -> List.assoc_opt callback_name q.callback_effects
  in
  match effects, callback_battles (qid, callback_name) with
  | None, None -> None
  | _, cbrow ->
    (* Lua runs the body in source order; the two extracted
       QUEST_REMOVE_COMPANION callback sites (Q3Q5 CallbackConvE drops
       NDKH, QU02 CallbackConvB drops NSUN) sit above the message, so the
       companion leaves before the effects fold. Absent from the party the
       removal is the no-op QUEST_REMOVE_COMPANION's own absent-id check
       would have made of it. *)
    let p =
      match q_opt with
      | None -> player
      | Some q ->
        List.fold_left
          (fun acc (cb, cid) ->
            if cb = callback_name then remove_companion acc cid else acc)
          player q.remove_companion_on_callbacks
    in
    let p =
      match effects with
      | None -> p
      | Some effs ->
        (* each row carries its whole arm conjunction (Lua tests at the if
           in the body, so the fold's accumulator is the party and var
           store those tests see); callbacks have no location and no
           battle outcome yet, so clauses evaluate against loc "" / no
           success - a side-tested clause cannot fire there, which keeps
           the row live as the pre-clause behaviour did. The clause guards
           re-check a predecessor arm's key, so they read the fold-ENTRY
           snapshot [p]; the row's own header reads the live accumulator. *)
        let cur =
          match List.assoc_opt qid p.active_quests with
          | Some s -> s
          | None -> -2
        in
        List.fold_left
          (fun acc (cnd, vnd, ind, ncl, e) ->
            if cond_ok acc p qid ~st:cur ~loc:"" ~suc:None
                 (cnd, vnd, ind, ncl) then
              apply_callback_effect acc qid e
            else acc)
          p effs
    in
    (match cbrow with
     | None ->
       Some { cf_player = p; cf_battle = None;
              cf_settle = fun _ -> (p, None) }
     | Some cb -> (
       match (try Some (Campaign_monsters.monster_by_id cb.cb_monster_id)
              with Not_found -> None) with
       | None ->
         Some { cf_player = p; cf_battle = None;
                cf_settle = fun _ -> (p, None) }
       | Some monster ->
         let battles = match q_opt with Some q -> q.battles | None -> [] in
         let hero = player_to_combatant p in
         let enemy = monster_to_combatant monster p.level in
         let hero_spells =
           (match List.nth_opt battles cb.cb_battle_index with
            | Some (_, spells) -> spells
            | None -> []) @ mount_spell_ids p @ p.known_spells
         in
         let b =
           open_battle ~rng
             ~rules:(playable_rules human ~player)
             ~hero_spells:(spells_of_ids hero_spells)
             ~enemy_spells:(spells_of_ids monster.spells)
             ~hero_items:(loadout_of_equipment p.equipment)
             ~hero ~enemy
             ~enemy_tags:(monster_type_tags monster)
             ~companions:p.companions ()
         in
         Some
           { cf_player = p;
             cf_battle = Some b;
             cf_settle =
               (fun finished ->
                 let won = Battle.hero_won finished in
                 (* The defeat record is the callback's own primitive:
                    cb_capture says whether this site captures (Q1Q6/
                    CallbackConvB does not) and cb_monster_id the monster the
                    callback called - the stage's battle_actions describe the
                    location fights, not this one. *)
                 let p' =
                   quest_battle_settle ~capture:cb.cb_capture
                     ~monster:cb.cb_monster_id p qid won finished
                 in
                 (* The offer: a won fight the stage allows captured, both
                    gates now holding after the settle recorded this defeat. *)
                 let offer =
                   callback_capture_offer ~won ~capture:cb.cb_capture p'
                     cb.cb_monster_id
                 in
                 (p', offer)) }))

(* Execute a conversation/message callback by name: open it, run its fight
   when it has one through [Battle.run], settle. The headless path - a
   playable front calls [callback_open] instead and hosts the fight itself.
   [None] means the pair has neither effects nor a battle. *)
let execute_callback ?(rng = Random.int) ?human (player: player) (qid: string)
    (callback_name: string) : callback_result option =
  match callback_open ~rng ?human player qid callback_name with
  | None -> None
  | Some cf -> (
    match cf.cf_battle with
    | None ->
      Some { cb_player = cf.cf_player; cb_battle = None;
             cb_capture_offer = None }
    | Some b ->
      let finished = Battle.run b in
      let p, offer = cf.cf_settle finished in
      Some { cb_player = p; cb_battle = Some finished;
             cb_capture_offer = offer })

let complete_encounter (player: player) (enc: encounter) : player =
  let battle = run_encounter_battle player enc in
  let new_player, _result = process_battle_result player enc battle in
  new_player

(* ------------------------------------------------------------------ *)
(* Location actions: query / execute / complete / enter              *)
(* ------------------------------------------------------------------ *)

(* Apply a quest's guarded effect groups for one event: every group whose
   guard matches runs, in source order, and each later group's guard re-reads
   the state as the fold sees it - OnCompleteAction bodies run sequential
   if-blocks, and Q0Q0 writes questState = 2 at state 1 before a state-2
   turn-in test in the same body. The pre-event stage is the fallback once a
   group Completes the quest: Lua's questState variable outlives the
   CompleteQuest bookkeeping, so later guards still see it. A row that
   carries the terminates flag ends the fold once applied: its Lua body
   stopped in a bare `return;` (Q2Q7's Conv_Q2Q7b branch), so the groups
   after it never ran in the script either. *)
(* [matches] tests the row's own key (state / success / location wildcards)
   against the event; [~location] is the event's real node, which the nand
   clauses test (a row's key may collapse location to "" while an earlier
   arm's clause pins the node it excluded). *)
let apply_loc_groups (player : player) (qid : string)
    (rows :
       (int * string * (string * bool) list * (string * bool * int) list *
        (string * bool) list * clause list * callback_effect list * bool)
         list)
    ~(location : string)
    (matches : int -> string -> player -> bool) : player =
  (* A clause re-checks the key of an earlier arm of the SAME if/elseif
     chain, so it must be tested against the stage the chain STARTED at -
     the state as of the last row that actually fired. Two failure modes
     pin this down:

     - reading the LIVE accumulator unblocks a later arm once its own
       predecessor writes the state it excluded (Q1G3's write-to-2, or
       Q1S0's NKHA write) - the arm wrongly fires as a sibling of the
       chain it was excluded by;
     - reading the fold-entry stage breaks a later CHAIN that re-tests the
       state a prior chain wrote (Q1G3 and Q0Q0 run a second `if` after
       the first wrote state 2 - the second chain's clause must see 2, not
       the fold's entry 1).

     Advancing the snapshot on every fired row threads that needle: a
     clause only ever names its own chain's predecessor, and a predecessor
     that fired has already been consumed by it, while an unrelated chain
     that fired earlier leaves the snapshot at its post-write stage. *)
  let rec go snap acc rows =
    match rows with
    | [] -> acc
    | (st, loc, cnd, vnd, ind, ncl, effs, term) :: rest ->
      if matches st loc acc
         && cond_ok acc snap qid
              ~st:(match List.assoc_opt qid snap.active_quests with
                   | Some s -> s
                   | None -> -2)
              ~loc:location ~suc:None
              (cnd, vnd, ind, ncl)
      then
        let acc' =
          List.fold_left (fun a e -> apply_callback_effect a qid e) acc effs
        in
        if term then acc' else go acc acc' rest
      else go snap acc rest
  in
  go player player rows

let apply_complete_groups (player : player) (qid : string)
    (rows :
       (int * int * string * (string * bool) list * (string * bool * int)
        list * (string * bool) list * clause list * callback_effect list *
        bool)
         list)
  ~(location : string) ~(success : bool)
  (matches : int -> int -> string -> player -> bool) : player =
  (* The clause guards an earlier arm of the SAME if/elseif chain, so it is
     tested against the stage the chain started at - the state as of the
     last row that FIRED - not the live accumulator, and not the fold-entry
     stage either. Reading the live accumulator lets a later arm fire once
     its own predecessor writes the state it excluded (Q1G3's write-to-2,
     Q1S0's NKHA write). Reading the fold-entry stage breaks a later chain
     that re-tests a state a prior chain already wrote: Q1G3 and Q0Q0 run a
     second `if` after the first wrote state 2, and that chain's clause must
     see 2. A clause only ever names its own chain's predecessor, and a
     predecessor that fired has been consumed by it, so advancing the
     snapshot on every fired row threads the needle. *)
  let rec go snap acc rows =
    match rows with
    | [] -> acc
    | (st, suc, loc, cnd, vnd, ind, ncl, effs, term) :: rest ->
      if matches st suc loc acc
         && cond_ok acc snap qid
              ~st:(match List.assoc_opt qid snap.active_quests with
                   | Some s -> s
                   | None -> -2)
              ~loc:location ~suc:(Some success)
              (cnd, vnd, ind, ncl)
      then
        let acc' =
          List.fold_left (fun a e -> apply_callback_effect a qid e) acc effs
        in
        if term then acc' else go acc acc' rest
      else go snap acc rest
  in
  go player player rows

(* A hero arrived at [location]: every active quest gets its OnEnterLocation
   rules evaluated against the arrival (effects applying in active-quest
   order so a later rule sees an earlier removal - the order the engine's
   single hero would), then the extracted enter_effects: arrival
   conversations, messages, state writes and completes under their guard
   (state -1 = any stage, loc "" = any node, gate [] = no companion test),
   live like the sequential if-blocks of the Lua body.

   The group fold runs BEFORE the remove rules apply: Lua evaluates the
   QUEST_HERO_HAS_COMPANION_SELECTED tests at if-entry, while the removes
   sit inside the chosen arm (Q3S0 messages then removes, QS00 removes
   then messages) - the gates must see the party the arrival started
   with. The removes themselves matched stage+location at build time, so
   the reorder cannot change which of them fire. *)
let enter_location (player: player) (location: string) : player =
  List.fold_left
    (fun p (qid, st) ->
      let q = quest_by_id qid in
      let qi = { quest = q; state = Active st;
                 vars = quest_var_set [] "questState" (string_of_int st) } in
      let _, removes = run_quest_on_enter_location qi location in
      let p =
        apply_loc_groups p qid q.enter_effects ~location
          (fun st' loc' p' ->
            let cur =
              match List.assoc_opt qid p'.active_quests with
              | Some s -> s
              | None -> st
            in
            (st' = -1 || st' = cur) && (loc' = "" || loc' = location))
      in
      List.fold_left (fun p' e -> apply_quest_effect p' e) p removes)
    player player.active_quests

(* What the hero can do at [location]: for each active quest, the first
   OnQueryAction label whose whole arm conjunction (state, location,
   companion, script vars, inventory, earlier-arm clauses) all match -
   source order, the branch Lua would show (state -1 / loc "" = any, empty
   lists = unconstrained). [(qid, text tag)]; quests with no matching
   branch are left out. *)
let query_actions (player : player) (location : string) :
    (string * string) list =
  List.filter_map
    (fun (qid, st) ->
      let q = quest_by_id qid in
      match List.find_opt
              (fun (st', loc', cnd, vnd, ind, ncl, _) ->
                 (st' = -1 || st' = st)
                 && (loc' = "" || loc' = location)
                 && cond_ok player player qid ~st ~loc:location ~suc:None
                      (cnd, vnd, ind, ncl))
              q.query_actions
      with
      | Some (_, _, _, _, _, _, tag) -> Some (qid, tag)
      | None -> None)
    player.active_quests

(* Start [qid]'s action here: OnExecuteAction's matching groups run - the
   action's conversation or message queues, its state write applies, and
   some actions complete straight from execute (Q0I3 turns in at the
   finish). No-op when the quest is not active or no group matches. The
   caller then shows the queued dialogue/message and, when the action has a
   battle, runs it and follows with [complete_action] - the engine fires
   OnCompleteAction on the return to the map. *)
let execute_action (player : player) (qid : string) (location : string) :
    player =
  match List.assoc_opt qid player.active_quests with
  | None -> player
  | Some st0 ->
    let q = quest_by_id qid in
    apply_loc_groups player qid q.execute_effects ~location
      (fun st loc p ->
        let cur =
          match List.assoc_opt qid p.active_quests with
          | Some s -> s
          | None -> st0
        in
        (st = -1 || st = cur) && (loc = "" || loc = location))

(* [qid]'s action finished at [location]: OnCompleteAction's matching groups
   run under the outcome - [success] is the battle result or the dialogue's
   own conclusion, and a group keyed -1 matches either. Guards read the live
   stage, so calling this after quest_battle_complete matches Lua (the stage
   the return finds), while a group keyed to the pre-battle stage simply does
   not match anymore. No-op when the quest is not active or no group matches. *)
let complete_action ?(success = true) (player : player) (qid : string)
    (location : string) : player =
  match List.assoc_opt qid player.active_quests with
  | None -> player
  | Some st0 ->
    let q = quest_by_id qid in
    apply_complete_groups player qid q.complete_effects
      ~location ~success
      (fun st suc loc p ->
        let cur =
          match List.assoc_opt qid p.active_quests with
          | Some s -> s
          | None -> st0
        in
        (st = -1 || st = cur)
        && (suc = -1 || suc = (if success then 1 else 0))
        && (loc = "" || loc = location))

(* The travel step a driver should call: [advance_travel], and when the walk
   lands on [AtNode] the location's quest events run through
   [enter_location] - the OnEnterLocation rules, the extracted arrival
   groups (boxes, nested trees, companion removals) - so walking into a node
   fires the arrival moment the Lua scripts name. Mid-road steps pass the
   player through untouched. Both pending queues fill as usual; the driver
   drains them after. *)
let advance_travel_with_events (player : player) (ts : travel_state)
    (dt : float) : player * travel_state =
  match advance_travel ts dt with
  | AtNode id -> (enter_location player id, AtNode id)
  | ts' -> (player, ts')
