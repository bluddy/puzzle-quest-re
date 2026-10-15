(** The world map in a window: the node graph, the road graph, the hero on
    it, and a click to walk somewhere.

    Everything about {e what happens} belongs to the engine:
    [Campaign.begin_travel] only opens a revealed road, [advance_travel_with_events]
    walks it and runs the arrival moment ([enter_location]: OnEnterLocation
    rules, guarded arrival boxes and trees), [road_encounter] asks the road's
    list once at departure - and when the hero stops, the popup says so. The
    city panel's Actions tab lists [Campaign.query_actions] for the node and
    clicking one starts it through [execute_action]; the queued dialogue,
    messages and callback battles run in the shared [Conv_window] over the
    map, and when that drains the driver runs the stage's fight - if the
    stage has one, through [Campaign.quest_battle_open] and the battle
    screen - and follows with [complete_action] under the real outcome. This
    front end draws those states and feeds them clicks; nothing about the
    recovered rules is re-implemented here.

    The art contract is the battle front's: without
    tools/extract_gfx_assets.py the sixteen map segments are missing and the
    window still opens, on flat colours, which is the only state a fresh
    checkout can honestly be in.

    The road fight and every quest fight are played on the battle screen
    ([Battle_screen], hosted on this window's GL context): the popup's click
    opens the encounter through [Campaign.encounter_battle_open] with the
    screen's mouse-backed choices in its rules, [Battle_screen.run] plays it,
    and [Campaign.process_battle_result] settles. A won fight whose monster
    passes the capture gates opens the minigame instead
    ([Campaign.capture_offer]): CaptureMenu.xml's grid drawn as flat gem
    colours, two clicks a swap through [Capture.play], and the console's
    [CANCEL] button standing in for the gamepad back-out. The city's Forge
    tab opens the forge skill game the same way ([Item_game] over
    ItemGameMenu.xml's grid and meter): the [MAXRUNEITEM] cap refuses a
    full bag up front, a win mints through [Campaign.forge_item], and a loss
    prints [FORGEITEMS_FAIL]. Callback battles a conversation triggers
    follow the battle-screen seam through [Conv_window], which this front
    hands the screen's hooks and runner. *)
open Puzzle_quest_lib
open Pq_gfx
module E = Tsdl.Sdl.Event
module Sdl = Tsdl.Sdl

let window_w = Layout.game_screen_w
and window_h = Layout.game_screen_h

(** The front end's walking rate, in map units per second. The journey model
    measures time in map units and leaves the tick to whoever drives
    [advance_travel] (port.travel_model); at 120 a second the seed city to
    its waypoint is about a second and a cross-map haul about fifteen. *)
let walk_speed = 120.0

let asset_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p && Sys.is_directory p -> p
  | _ -> "assets/gfx"

(** The sixteen segments, loaded where tools/extract_gfx_assets.py writes
    them. [None] per segment rather than a crash: a missing piece draws as a
    flat tile. *)
let load_segments () : ((int * int) * Gl.texture option) list =
  List.concat
    (List.init Map_view.segments_side (fun r ->
         List.init Map_view.segments_side (fun c ->
             let path =
               Filename.concat (asset_dir ())
                 (Printf.sprintf "Map%d%d.jpg" r c)
             in
             let tex =
               if Sys.file_exists path then
                 let px, w, h = Assets.load_image path in
                 Some (Gl.texture_of_bigarray ~w ~h px)
               else None
             in
             ((r, c), tex))))

type city_tab =
  | Shop
  | Spells
  | Tavern
  | Actions
  | Companions
  | Pets
  | Forge
  | Training
  | Settings

type city_view = {
  cid : string;
  mutable tab : city_tab;
  mutable rumor : int;
  mutable forge_base : string option;  (** the triple the forge tab holds *)
  mutable forge_mod : string option;
  mutable forge_pow : string option;
  mutable train_pending : string option;
      (** the mount whose [TRAINMOUNTS_DETAIL] is on the console - a
          second click on the same row starts the attempt *)
}

type ui = {
  gl : Gl.context;
  segments : ((int * int) * Gl.texture option) list;
  fonts : Font.t option;
  system : Font_layout.metrics option;
  mutable player : Campaign.player;
  mutable journey : Campaign.travel_state option;
  mutable popup : Campaign_encounters.encounter option;
  mutable popup_rune : string option;
      (** the rune the popup's Runekeeper guards, if this is that fight *)
  mutable city : city_view option;
  conv : Conv_window.state;  (* hosted dialogue over the map, always present *)
  mutable pending : (string * string) option;  (* (qid, loc): action awaiting complete *)
  mutable capture : (string * Capture.t) option;  (* monster id + live attempt *)
  mutable capture_sel : (int * int) option;  (* first gem of a pending swap *)
  mutable forge_game :
      (string * string * string * Item_game.t) option;
      (** the forge skill game over the city panel: the held triple (base,
          modifier, power) plus the live board - the [FORGEITEMS_FAIL] game
          [ItemGameMenu.xml] ships, won to mint through [forge_item] and
          lost to the failure line (port.item_game_rules) *)
  mutable forge_sel : (int * int) option;  (* first gem of a pending swap *)
  skin : Skin.t;  (** the gems-grid sheet, for the hammer art the meter and
                      the board's hammers draw from (img_hammanv_on/off) *)
  rules_tex : Gl.texture option;
      (** English/Rules_ItemGame.png, the skill game's own rules panel *)
}

let node_colour (k : Campaign.node_kind) : Layout.colour =
  match k with
  | Campaign.City -> Layout.rgb 240 210 90
  | Campaign.Waypoint -> Layout.rgb 205 205 215
  | Campaign.Ruin -> Layout.rgb 150 90 200

(* One solid quad in the frame's run list. Colours go to the run, so the
   quad itself is pushed colourless and the run carries the paint - the same
   pairing every other front here uses. *)
let solid (rs : Gl.run list ref) (gl : Gl.context) (dst : Layout.rect)
    ?(rotate = 0.0) (col : Layout.colour) : unit =
  let first = Gl.push_quad ~rotate gl dst None col in
  rs :=
    !rs
    @ [ { Gl.first; count = 6; tex = None; colour = col; clip = None;
          blend = None } ]

let segment (rs : Gl.run list ref) (gl : Gl.context) (dst : Layout.rect)
    (tex : Gl.texture) : unit =
  let uv =
    { Layout.x = 0; y = 0; w = Map_view.segment_px; h = Map_view.segment_px }
  in
  let first =
    Gl.push_quad ~tex_size:(Map_view.segment_px, Map_view.segment_px) gl dst
      (Some uv) (Layout.rgb 255 255 255)
  in
  rs :=
    !rs
    @ [ { Gl.first; count = 6; tex = Some tex; colour = Layout.rgb 255 255 255;
          clip = None; blend = None } ]

(** Where the hero is in world pixels: along the road while walking, at the     current node otherwise. *)
let hero_world (ui : ui) : int * int =
  match ui.journey with
  | Some (Campaign.Traveling t) ->
      let a = Campaign.node_by_id t.from_ in
      let b = Campaign.node_by_id t.to_ in
      let f =
        if t.total_time <= 0.0 then 1.0
        else t.progress /. t.total_time
      in
      ( a.x + int_of_float (float_of_int (b.x - a.x) *. f),
        a.y + int_of_float (float_of_int (b.y - a.y) *. f) )
  | _ -> (
      match ui.player.Campaign.current_city with
      | Some id -> (
          match Hashtbl.find_opt Campaign.map_nodes id with
          | Some n -> (n.Campaign.x, n.Campaign.y)
          | None -> (0, 0))
      | None -> (0, 0))

(** The city panel's tabs: the mode button walks them in this order, and the
    labels are the game's own strings. *)
let next_tab (t : city_tab) : city_tab =
  match t with
  | Shop -> Spells
  | Spells -> Tavern
  | Tavern -> Actions
  | Actions -> Companions
  | Companions -> Pets
  | Pets -> Forge
  | Forge -> Training
  | Training -> Settings
  | Settings -> Shop

let tab_label (t : city_tab) : string =
  match t with
  | Shop -> Text_data.text "[BUYITEMS]"
  | Spells -> Text_data.text "[SELECTSPELLMENU_HEADING]"
  | Tavern -> Text_data.text "[RUMORS]"
  | Actions -> "Actions"
  | Companions -> Text_data.text "[COMPANIONS]"
  | Pets -> Text_data.text "[PETS]"
  | Forge -> Text_data.text "[FORGEITEMS]"
  | Training -> Text_data.text "[TRAINMOUNTS]"
  | Settings -> Text_data.text "[SETTINGS]"

let open_city (ui : ui) (cid : string) : unit =
  ui.city <-
    Some
      { cid; tab = Shop; rumor = 0; forge_base = None; forge_mod = None;
        forge_pow = None; train_pending = None };
  Printf.printf "  entered %s\n"
    (Text_data.text (Campaign_map.city_by_id cid).Campaign_map.name_text);
  flush stdout

(** The console's half of the tavern: the name is on screen, the whole text     is where a paragraph can be read. The panel has no word-wrap - that is a     font feature this front does not use yet. *)
let show_rumor (cv : city_view) : unit =
  match List.nth_opt (Campaign.rumors ()) cv.rumor with
  | Some (n, d) ->
      Printf.printf "  rumor %d/%d - %s\n    %s\n" (cv.rumor + 1)
        (List.length (Campaign.rumors ())) n d;
      flush stdout
  | None -> ()

let advance_rumor (cv : city_view) : unit =
  let n = List.length (Campaign.rumors ()) in
  if n > 0 then begin
    cv.rumor <- (cv.rumor + 1) mod n;
    show_rumor cv
  end

(** The companion rows: registry order, but the traveling party first, so     the seven visible rows carry the companions that matter here. *)
let companion_rows (p : Campaign.player) : string list =
  let rank cid =
    match Campaign.companion_slot p cid with
    | Campaign.Traveling -> 0
    | Campaign.At_home -> 1
    | Campaign.At_home_full -> 2
    | Campaign.Away _ -> 3
    | Campaign.Not_recruited -> 4
  in
  List.sort
    (fun a b -> compare (rank a) (rank b))
    (List.map (fun c -> c.Campaign_companions.id) Campaign_companions.companions)

(** Where a companion lives, as a name when the node is a city and the raw     id otherwise (the waypoints some call home ship no name tag here). *)
let node_label (id : string) : string =
  try Text_data.text (Campaign_map.city_by_id id).Campaign_map.name_text
  with Not_found -> id

(** The Pets tab's rows: every enemy the [CAPTURE_LISTHELP] gates hold for
    and the hero does not hold yet (a click opens the minigame), then the
    captives already held (display - [PETS_HELP]). *)
let pet_rows (p : Campaign.player) : [ `Ready of string | `Held of string ] list
    =
  List.map (fun id -> `Ready id) (Campaign.capture_candidates p)
  @ List.map (fun id -> `Held id) p.Campaign.captives

(** A monster's display name - save data can name an id the registry
    dropped, and the row still has to draw. *)
let monster_name (id : string) : string =
  try
    Text_data.text (Campaign_monsters.monster_by_id id).Campaign_monsters.name_text
  with Not_found -> id

(** The forge tab's rows: the held runes in registry order, each tagged     with the slot it fills. *)
let rune_rows (p : Campaign.player) :
    [ `Base of string | `Mod of string | `Pwr of string ] list =
  List.map
    (fun (k : Campaign_runes.rune_kind) ->
      match k with
      | Campaign_runes.Base_rune r -> `Base r.Campaign_runes.id
      | Campaign_runes.Modifier_rune r -> `Mod r.Campaign_runes.id
      | Campaign_runes.Power_rune r -> `Pwr r.Campaign_runes.id)
    (Campaign.held_runes p)

(** A rune's display name; the tables all carry a name tag. *)
let rune_display (id : string) : string =
  Text_data.text
    (match Campaign_runes.rune_by_id id with
    | Some (Campaign_runes.Base_rune r) -> r.Campaign_runes.name_text
    | Some (Campaign_runes.Modifier_rune r) -> r.Campaign_runes.name_text
    | Some (Campaign_runes.Power_rune r) -> r.Campaign_runes.name_text
    | None -> id)

(** The training tab's rows: the rideable captives, registry order -
    [SELECTMOUNTMENU_TEXT]'s "list shows all of your mounts". *)
let mount_rows (p : Campaign.player) : string list =
  List.map
    (fun (m : Campaign_monsters.monster) -> m.Campaign_monsters.id)
    (List.filter
       (fun (m : Campaign_monsters.monster) ->
         m.Campaign_monsters.mount = 1
         && List.mem m.Campaign_monsters.id p.Campaign.captives)
       Campaign_monsters.monsters)

(** Fill a recovered %s in a runtime string - Printf.sprintf will not take     a tag that only becomes a format after Text_data resolves it. *)
let fill1 (pat : string) (arg : string) : string =
  match String.index_opt pat '%' with
  | Some i when i + 1 < String.length pat && pat.[i + 1] = 's' ->
      String.sub pat 0 i ^ arg
      ^ String.sub pat (i + 2) (String.length pat - i - 2)
  | _ -> pat

(** Fill two runtime ints in a shipped string: [PETS_DETAILS] carries "%d of
    %d" and Printf.sprintf will not take a tag that only becomes a format
    after Text_data resolves it. *)
let fill2 (pat : string) (a : string) (b : string) : string =
  match String.index_opt pat '%' with
  | Some i when i + 1 < String.length pat && pat.[i + 1] = 'd' ->
      let head = String.sub pat 0 i in
      let rest = String.sub pat (i + 2) (String.length pat - i - 2) in
      (match String.index_opt rest '%' with
      | Some j when j + 1 < String.length rest && rest.[j + 1] = 'd' ->
          head ^ a ^ String.sub rest 0 j ^ b
          ^ String.sub rest (j + 2) (String.length rest - j - 2)
      | _ -> head ^ a ^ rest)
  | _ -> pat

(** A click inside the city panel: Done leaves, the mode button tabs, rows     buy (shop) or advance the rumor (tavern), and the body advances it too. *)
let handle_city_click (ui : ui) (cv : city_view) (mx : int) (my : int) : unit =
  match City_layout.hit mx my with
  | City_layout.Leave ->
      ui.city <- None;
      print_endline "  left the city";
      flush stdout
  | City_layout.Tab ->
      cv.tab <- next_tab cv.tab;
      Printf.printf "  %s\n" (tab_label cv.tab);
      flush stdout;
      if cv.tab = Tavern then show_rumor cv;
      if cv.tab = Pets then begin
        Printf.printf "  %s\n" (Text_data.text "[YOURCITY_PETS_TEXT]");
        flush stdout
      end
  | City_layout.Row i -> (
      match cv.tab with
      | Shop -> (
          let items =
            Campaign.city_shop_items (Campaign_map.city_by_id cv.cid)
          in
          match List.nth_opt items i with
          | None -> ()
          | Some item -> (
              match Campaign.buy_item ui.player item with
              | Some p ->
                  ui.player <- p;
                  Printf.printf "  bought %s for %d gold\n"
                    (Text_data.text item.Campaign_items.name_text)
                    item.Campaign_items.cost;
                  flush stdout
              | None ->
                  Printf.printf "  cannot afford %s (%d gold needed)\n"
                    (Text_data.text item.Campaign_items.name_text)
                    item.Campaign_items.cost;
                  flush stdout))
      | Spells ->
          (* The list is a display: spells come from captives, not from the
             purse - LEARNTALLSPELLS says so, and the research flow is
             another workstream. *)
          ()
      | Tavern -> advance_rumor cv
      | Actions -> (
          match List.nth_opt (Campaign.query_actions ui.player cv.cid) i with
          | None -> ()
          | Some (qid, tag) ->
              Printf.printf "  action: %s - %s\n" qid (Text_data.text tag);
              flush stdout;
              ui.player <- Campaign.execute_action ui.player qid cv.cid;
              ui.pending <- Some (qid, cv.cid))
      | Companions -> (
          match List.nth_opt (companion_rows ui.player) i with
          | None -> ()
          | Some cid -> (
              let name =
                Text_data.text (Campaign_companions.companion_by_id cid).Campaign_companions.name_text
              in
              match Campaign.companion_slot ui.player cid with
              | Campaign.Traveling ->
                  ui.player <- Campaign.remove_companion ui.player cid;
                  Printf.printf "  left %s behind\n" name;
                  flush stdout
              | Campaign.At_home ->
                  ui.player <- Campaign.add_companion ui.player cid;
                  Printf.printf "  %s joined the party\n" name;
                  flush stdout
              | Campaign.At_home_full ->
                  Printf.printf "  %s: %s\n" name
                    (Text_data.text "[COMPANIONSTATUS_NEW0]");
                  flush stdout
              | Campaign.Away h ->
                  Printf.printf "  %s: %s\n" name
                    (fill1 (Text_data.text "[COMPANIONSTATUS_OUT0]")
                       (node_label h));
                  flush stdout
              | Campaign.Not_recruited -> ()))
      | Pets -> (
          match List.nth_opt (pet_rows ui.player) i with
          | None -> ()
          | Some (`Ready mid) ->
              (* The city's capture entry: the minigame opens over the
                 panel, [CANCEL] comes back to it. *)
              ui.capture <- Some (mid, Campaign.capture_begin mid);
              ui.capture_sel <- None;
              Printf.printf "  capturing %s - swap two gems, or Cancel\n"
                (monster_name mid);
              flush stdout
          | Some (`Held mid) ->
              Printf.printf "  %s: %s\n" (monster_name mid)
                (Text_data.text "[PETS_HELP]");
              flush stdout)
      | Forge -> (
          (* Clicking a held rune fills its slot; clicking it again clears
             it - the picker SelectRuneMenu runs over three columns. *)
          match List.nth_opt (rune_rows ui.player) i with
          | None -> ()
          | Some (`Base id) ->
              cv.forge_base <-
                (if cv.forge_base = Some id then None else Some id)
          | Some (`Mod id) ->
              cv.forge_mod <-
                (if cv.forge_mod = Some id then None else Some id)
          | Some (`Pwr id) ->
              cv.forge_pow <-
                (if cv.forge_pow = Some id then None else Some id))
      | Training -> (
          match List.nth_opt (mount_rows ui.player) i with
          | None -> ()
          | Some mid ->
              if cv.train_pending = Some mid then begin
                (* The second click is [TRAINMOUNTS_DETAIL]'s "Continue?"
                   - run the attempt and report. *)
                cv.train_pending <- None;
                (match
                   Campaign.train_mount ~rng:Random.int ui.player mid
                 with
                | Some (p', _b, true) ->
                    ui.player <- p';
                    Printf.printf "  %s\n"
                      (fill1
                         (Text_data.text "[TRAINMOUNTS_SUCCESS]")
                         (string_of_int
                            (Campaign.mount_level ui.player mid)));
                    flush stdout
                | Some (_, _b, false) ->
                    let ch =
                      match Campaign.training_challenge ui.player mid with
                      | Some c -> c
                      | None -> { Campaign.creature_level = 0; seconds = 0;
                                  turn_limit = 0 }
                    in
                    Printf.printf
                      "  training failed - the creature outlasted the clock \
                       (%d turn limit)\n"
                      ch.Campaign.turn_limit;
                    flush stdout
                | None ->
                    Printf.printf "  cannot train %s\n" (monster_name mid);
                    flush stdout)
              end
              else begin
                cv.train_pending <- Some mid;
                match Campaign.training_challenge ui.player mid with
                | Some ch ->
                    Printf.printf "  %s\n"
                      (fill2
                         (Text_data.text "[TRAINMOUNTS_DETAIL]")
                         (string_of_int ch.Campaign.creature_level)
                         (string_of_int ch.Campaign.seconds));
                    flush stdout
                | None -> ()
              end)
      | Settings ->
          (* The hero view's two dropdowns (SinglePlayerMenu's drop_difficulty
             and drop_timelimit), as cycle rows: one click advances the value
             and wraps. A droplist widget is a port choice; the row strings and
             the 0..2 / 0..4 clamps are the recovered parts. The settings are
             machine-wide in the original (registry), so they live in the two
             Campaign refs rather than in this city.

             The third row is the language: the original has no in-game row for
             it (GameText carries no [LANGUAGE] tag; selection is a -FRENCH-style
             launch-argument switch behind the existence gate, see Text_data), so
             the port offers the five shipped languages here as a cycle row - the
             label is a port literal, the values the exe's own name table. *)
          (match i with
          | 0 ->
              Campaign.set_difficulty ((!Campaign.difficulty + 1) mod 3);
              Printf.printf "  %s : %s\n"
                (Text_data.text "[DIFFICULTY]")
                (Text_data.text
                   (Printf.sprintf "[AILEVEL%d]" !Campaign.difficulty));
              flush stdout
          | 1 ->
              Campaign.set_timelimit ((!Campaign.timelimit + 1) mod 5);
              Printf.printf "  %s : %s\n"
                (Text_data.text "[TIMELIMIT]")
                (Text_data.text
                   (Printf.sprintf "[TIMELIMIT%d]" !Campaign.timelimit));
              flush stdout
          | 2 ->
              Text_data.set_language
                ((!Text_data.language + 1) mod (Array.length Text_data.names));
              Printf.printf "  Language : %s\n"
                (Text_data.name_of !Text_data.language);
              flush stdout
          | _ -> ()))
  | City_layout.Forge ->
      if cv.tab <> Forge then ()
      else (
        match (cv.forge_base, cv.forge_mod, cv.forge_pow) with
        | Some b, Some m, Some w ->
            (* The skill game gates creation: [MAXRUNEITEM] refuses the
               attempt outright, then [FORGEITEMS_FAIL] becomes the game's
               own loss line rather than a held-rune miss. *)
            if Campaign.rune_item_count ui.player >= Campaign.rune_item_cap
            then begin
              Printf.printf "  %s\n" (Text_data.text "[MAXRUNEITEM0]");
              Printf.printf "  %s\n" (Text_data.text "[MAXRUNEITEM1]");
              flush stdout
            end
            else
              (match Campaign.forge_rune ui.player ~base:b ~modifier:m ~power:w with
              | None ->
                  Printf.printf "  %s\n" (Text_data.text "[FORGEITEMS_3RUNES]");
                  flush stdout
              | Some spec ->
                  let target =
                    Item_game.target_for_difficulty spec.Campaign.difficulty
                  in
                  ui.forge_game <-
                    Some (b, m, w, Item_game.create ~rng:Random.int ~target ());
                  ui.forge_sel <- None;
                  Printf.printf "  %s - destroy hammers and anvils for %d points\n"
                    (Text_data.text "[ITEMGAMEMENU_HEADING]")
                    target;
                  flush stdout)
        | _ ->
            Printf.printf "  %s\n" (Text_data.text "[FORGEITEMS_3RUNES]");
            flush stdout)
  | City_layout.Elsewhere -> (
      match cv.tab with
      | Tavern -> advance_rumor cv
      | Shop | Spells | Actions | Companions | Pets | Forge | Training
      | Settings -> ())

(** The city panel: dim the map, then ShopMenu's own furniture - title,     gold line, the list at y=170, mode and Done at y=402. *)
let draw_city (rs : Gl.run list ref) (gl : Gl.context) (ui : ui)
    (cv : city_view) : unit =
  solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
    (Layout.rgba 0 0 0 150);
  let px, py, pw, ph = (48, 30, 680, 440) in
  solid rs gl { Layout.x = px; y = py; w = pw; h = ph }
    (Layout.rgb 24 26 34);
  solid rs gl { Layout.x = px; y = py; w = pw; h = 3 }
    (Layout.rgb 240 210 90);
  let sys = ui.system and f = ui.fonts in
  let measure s =
    match sys with
    | Some m -> Font_layout.measure m s
    | None -> 8 * String.length s
  in
  let text ?(colour = Layout.rgb 230 230 230) s x y =
    match (f, sys) with
    | Some ff, Some m -> rs := !rs @ Font.draw gl ff m s ~x ~y ~colour
    | _ -> ()
  in
  let city = Campaign_map.city_by_id cv.cid in
  text (Text_data.text city.Campaign_map.name_text) City_layout.title_x
    City_layout.title_y;
  text
    (Printf.sprintf "Gold: %d" ui.player.Campaign.gold)
    City_layout.gold_x City_layout.gold_y;
  let row_y i = City_layout.row_y0 + (i * City_layout.row_step) in
  (match cv.tab with
  | Shop ->
      List.iteri
        (fun i (item : Campaign_items.item) ->
          if i < City_layout.max_rows then begin
            let afford = ui.player.Campaign.gold >= item.Campaign_items.cost in
            let col =
              if afford then Layout.rgb 230 230 230
              else Layout.rgb 120 120 120
            in
            text ~colour:col
              (Text_data.text item.Campaign_items.name_text)
              (City_layout.row_x + 30) (row_y i + 3);
            let price = string_of_int item.Campaign_items.cost in
            text ~colour:col price
              (City_layout.row_x + City_layout.row_w - measure price - 8)
              (row_y i + 3)
          end)
        (Campaign.city_shop_items city)
  | Spells ->
      List.iteri
        (fun i id ->
          if i < City_layout.max_rows then begin
            let name =
              match Campaign.spells_of_ids [ id ] with
              | s :: _ -> s.Spell.name
              | [] -> id
            in
            text name (City_layout.row_x + 30) (row_y i + 3)
          end)
        (Campaign.city_shop_spells city);
      text ~colour:(Layout.rgb 150 150 160)
        (Text_data.text "[RESEARCHSPELLS_HELP1]")
        City_layout.row_x
        (City_layout.row_y0 + (City_layout.max_rows * City_layout.row_step) + 8)
  | Tavern -> (
      match List.nth_opt (Campaign.rumors ()) cv.rumor with
      | Some (n, _) ->
          text ~colour:(Layout.rgb 240 210 90) n
            (City_layout.row_x + 30)
            City_layout.row_y0;
          text ~colour:(Layout.rgb 150 150 160)
            (Printf.sprintf "rumor %d/%d - click for another"
               (cv.rumor + 1) (List.length (Campaign.rumors ())))
            City_layout.row_x
            (City_layout.row_y0 + 30)
      | None -> ())
  | Actions ->
      List.iteri
        (fun i (qid, tag) ->
          if i < City_layout.max_rows then begin
            let qname =
              match
                try Some (Campaign_quests.quest_by_id qid) with Not_found -> None
              with
              | Some q -> Text_data.text q.Campaign_quests.name_text
              | None -> qid
            in
            text
              (qname ^ " - " ^ Text_data.text tag)
              (City_layout.row_x + 30) (row_y i + 3)
          end)
        (Campaign.query_actions ui.player cv.cid)
  | Companions ->
      List.iteri
        (fun i cid ->
          if i < City_layout.max_rows then begin
            let c = Campaign_companions.companion_by_id cid in
            let slot = Campaign.companion_slot ui.player cid in
            let col, status =
              match slot with
              | Campaign.Traveling -> (Layout.rgb 240 210 90, "with you")
              | Campaign.At_home -> (Layout.rgb 230 230 230, "here")
              | Campaign.At_home_full ->
                  (Layout.rgb 230 180 90, "party full")
              | Campaign.Away h -> (Layout.rgb 150 150 160, node_label h)
              | Campaign.Not_recruited -> (Layout.rgb 100 100 110, "")
            in
            text ~colour:col
              (Text_data.text c.Campaign_companions.name_text)
              (City_layout.row_x + 30) (row_y i + 3);
            if status <> "" then begin
              let w = measure status in
              text ~colour:col status
                (City_layout.row_x + City_layout.row_w - w - 8) (row_y i + 3)
            end
          end)
        (companion_rows ui.player);
      text ~colour:(Layout.rgb 150 150 160)
        (fill1 (Text_data.text "[COMPANIONS_DETAILS]")
           (string_of_int (List.length ui.player.Campaign.companions)))
        City_layout.row_x
        (City_layout.row_y0 + (City_layout.max_rows * City_layout.row_step) + 8)
  | Pets ->
      List.iteri
        (fun i row ->
          if i < City_layout.max_rows then begin
            let name, status, col =
              match row with
              | `Ready mid ->
                  (monster_name mid, "ready", Layout.rgb 240 210 90)
              | `Held mid ->
                  (monster_name mid, "captured", Layout.rgb 150 150 160)
            in
            text ~colour:col name (City_layout.row_x + 30) (row_y i + 3);
            let w = measure status in
            text ~colour:col status
              (City_layout.row_x + City_layout.row_w - w - 8) (row_y i + 3)
          end)
        (pet_rows ui.player);
      text ~colour:(Layout.rgb 150 150 160)
        (fill2 (Text_data.text "[PETS_DETAILS]")
           (string_of_int (List.length ui.player.Campaign.captives))
           (string_of_int (List.length Campaign_monsters.monsters)))
        City_layout.row_x
        (City_layout.row_y0 + (City_layout.max_rows * City_layout.row_step) + 8)
  | Forge ->
      List.iteri
        (fun i row ->
          if i < City_layout.max_rows then begin
            let id, kind, selected =
              match row with
              | `Base id -> (id, "base", cv.forge_base = Some id)
              | `Mod id -> (id, "modifier", cv.forge_mod = Some id)
              | `Pwr id -> (id, "power", cv.forge_pow = Some id)
            in
            let col =
              if selected then Layout.rgb 240 210 90
              else Layout.rgb 230 230 230
            in
            text ~colour:col
              (rune_display id)
              (City_layout.row_x + 30) (row_y i + 3);
            let w = measure kind in
            text ~colour:col kind
              (City_layout.row_x + City_layout.row_w - w - 8) (row_y i + 3)
          end)
        (rune_rows ui.player);
      let status =
        match (cv.forge_base, cv.forge_mod, cv.forge_pow) with
        | Some b, Some m, Some w -> (
            match
              Campaign.forge_rune ui.player ~base:b ~modifier:m ~power:w
            with
            | Some s ->
                (* the tag is a literal here - the runtime-format rule is
                   about tags that only become formats after Text_data *)
                Printf.sprintf "%s / %s / %s - %s"
                  (rune_display b) (rune_display m) (rune_display w)
                  (Text_data.text
                     (Printf.sprintf "[FORGEITEMS_TARGET%d]"
                        (Campaign.forge_band s.Campaign.difficulty)))
            | None -> Text_data.text "[FORGEITEMS_3RUNES]")
        | _ -> Text_data.text "[FORGEITEMS_3RUNES]"
      in
      text ~colour:(Layout.rgb 150 150 160) status City_layout.row_x
        (City_layout.row_y0
        + (City_layout.max_rows * City_layout.row_step)
        + 8);
      let held = List.length (rune_rows ui.player) in
      if held > City_layout.max_rows then
        text ~colour:(Layout.rgb 150 150 160)
          (Printf.sprintf "(%d more - not visible)"
             (held - City_layout.max_rows))
          City_layout.row_x
          (City_layout.row_y0
          + ((City_layout.max_rows + 1) * City_layout.row_step)
          + 8)
  | Training ->
      List.iteri
        (fun i mid ->
          if i < City_layout.max_rows then begin
            let selected = cv.train_pending = Some mid in
            let col =
              if selected then Layout.rgb 240 210 90
              else Layout.rgb 230 230 230
            in
            text ~colour:col
              (monster_name mid)
              (City_layout.row_x + 30) (row_y i + 3);
            let lvl =
              "level "
              ^ string_of_int (Campaign.mount_level ui.player mid)
            in
            let w = measure lvl in
            text ~colour:col lvl
              (City_layout.row_x + City_layout.row_w - w - 8) (row_y i + 3)
          end)
        (mount_rows ui.player);
      let status =
        match cv.train_pending with
        | Some _ -> "second click starts the timed battle"
        | None -> Text_data.text "[TRAINMOUNTS_HELP1]"
      in
      text ~colour:(Layout.rgb 150 150 160) status City_layout.row_x
        (City_layout.row_y0
        + (City_layout.max_rows * City_layout.row_step)
        + 8)
  | Settings ->
      (* The hero view's two droplists, laid out as cycle rows on the city
         list's own geometry: label left, the current value right in the gold
         highlight. The values come from the same [AILEVEL*]/[TIMELIMIT*] tags
         the original droplist rows carry; a droplist widget is a port choice
         (recorded in port.settings_surface). The third row is the language -
         a port row (the original has no row: it selects via a launch-argument
         switch and the existence gate, see Text_data), its label a literal and
         its values Text_data's recovered name table. *)
      let setting_row i label value =
        if i < City_layout.max_rows then begin
          text label (City_layout.row_x + 30) (row_y i + 3);
          let w = measure value in
          text ~colour:(Layout.rgb 240 210 90) value
            (City_layout.row_x + City_layout.row_w - w - 8) (row_y i + 3)
        end
      in
      setting_row 0
        (Text_data.text "[DIFFICULTY]")
        (Text_data.text (Printf.sprintf "[AILEVEL%d]" !Campaign.difficulty));
      setting_row 1
        (Text_data.text "[TIMELIMIT]")
        (Text_data.text (Printf.sprintf "[TIMELIMIT%d]" !Campaign.timelimit));
      setting_row 2 "Language" (Text_data.name_of !Text_data.language);
      text ~colour:(Layout.rgb 150 150 160)
        "click a row to cycle the option"
        City_layout.row_x
        (City_layout.row_y0
        + (City_layout.max_rows * City_layout.row_step)
        + 8));
  solid rs gl City_layout.mode_btn (Layout.rgb 44 48 60);
  solid rs gl City_layout.done_btn (Layout.rgb 44 48 60);
  if cv.tab = Forge then
    solid rs gl City_layout.forge_btn (Layout.rgb 44 48 60);
  (match (f, sys) with
  | Some ff, Some m ->
      let l1 = tab_label (next_tab cv.tab) in
      rs :=
        !rs
        @ Font.draw gl ff m l1
            ~x:
              (City_layout.mode_btn.Layout.x
              + ((City_layout.mode_btn.Layout.w - Font_layout.measure m l1) / 2))
            ~y:(City_layout.mode_btn.Layout.y + 16);
      let l2 = Text_data.text "[DONE]" in
      rs :=
        !rs
        @ Font.draw gl ff m l2
            ~x:
              (City_layout.done_btn.Layout.x
              + ((City_layout.done_btn.Layout.w - Font_layout.measure m l2) / 2))
            ~y:(City_layout.done_btn.Layout.y + 16);
      if cv.tab = Forge then begin
        let l3 = Text_data.text "[FORGEITEMS]" in
        rs :=
          !rs
          @ Font.draw gl ff m l3
              ~x:
                (City_layout.forge_btn.Layout.x
                + ((City_layout.forge_btn.Layout.w - Font_layout.measure m l3)
                  / 2))
              ~y:(City_layout.forge_btn.Layout.y + 16)
      end
  | _ -> ())

(* The hammer art at a chosen size: [Skin.draw] insists on the registry's own
   destination size (64x64), but the skill game's meter icons are 40x40 in
   44px slots and its board cells are 73, so the quad is pushed here with the
   caller's rectangle and the registry's source pixels - the same shape the
   battle front's effect drawer uses. *)
let draw_skin_scaled (rs : Gl.run list ref) (skin : Skin.t) (gl : Gl.context)
    (tag : string) ~(dst : Layout.rect) : bool =
  match Skin_data.frame_of_tag tag with
  | None -> false
  | Some f -> (
    match Skin.sheet_texture skin f.Skin_data.sheet with
    | None -> false
    | Some (tex, tw, th) ->
      let uv =
        { Layout.x = f.Skin_data.x; y = f.Skin_data.y; w = f.Skin_data.w;
          h = f.Skin_data.h }
      in
      let first =
        Gl.push_quad ~tex_size:(tw, th) gl dst (Some uv)
          (Layout.rgb 255 255 255)
      in
      rs :=
        !rs
        @ [ { Gl.first; count = 6; tex = Some tex;
              colour = Layout.rgb 255 255 255; clip = None; blend = None } ];
      true)

(* The skill game's rules panel, from the shipped English/Rules_ItemGame.png.
   It lives with the other language assets rather than in the flat gfx dir,
   so the roots the conversation art resolves against are tried first. *)
let load_rules_texture () : Gl.texture option =
  let roots =
    List.filter
      (fun d -> Sys.file_exists d && Sys.is_directory d)
      (match Sys.getenv_opt "PQ_GAME_ASSETS" with
      | Some p when Sys.file_exists p && Sys.is_directory p -> [ p ]
      | _ -> [ "game/Assets"; asset_dir () ])
  in
  let rec try_path = function
    | [] -> None
    | c :: rest -> (
        if Sys.file_exists c then
          try
            let px, w, h = Assets.load_image c in
            Some (Gl.texture_of_bigarray ~w ~h px)
          with _ -> try_path rest
        else try_path rest)
  in
  try_path
    (List.concat_map
       (fun r -> [ Filename.concat r "English/Rules_ItemGame.png" ])
       roots)

(* The forge skill game over everything: ItemGameMenu.xml's grid (the capture
   grid's own 584 at (217,130)), the 21-icon [ITEMGAME_TARGET] meter down the
   right, the rules panel, the hero's name and the item being forged, and the
   shipped title and help lines. Hammers draw as img_hammanv_on art; the other
   gems are flat colours with their letters, the capture window's convention.
   A terminal state changes the hint and takes one more click, which is where
   [Campaign.forge_item] (a win) or [FORGEITEMS_FAIL] (a loss) runs. *)
let draw_forge_game (rs : Gl.run list ref) (gl : Gl.context) (ui : ui)
    ((base, modifier, power, game) :
      string * string * string * Item_game.t) : unit =
  solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
    (Layout.rgba 0 0 0 190);
  (* The grid's ground, under the gems. *)
  solid rs gl
    { Layout.x = Item_game_layout.grid_x - 6; y = Item_game_layout.grid_y - 6;
      w = Item_game_layout.grid_size + 12; h = Item_game_layout.grid_size + 12 }
    (Layout.rgb 24 26 34);
  let board = Item_game.(game.board) in
  for r = 0 to 7 do
    for c = 0 to 7 do
      let rect = Item_game_layout.cell_rect c r in
      let gem = Board.get_gem board { Board.x = c; y = r } in
      if gem = Board.Hammer then begin
        (* 64px of art centred in the 73px cell. *)
        if
          not
            (draw_skin_scaled rs ui.skin gl "img_hammanv_on"
               ~dst:
                 { rect with
                   Layout.x = rect.Layout.x + ((rect.Layout.w - 64) / 2);
                   y = rect.Layout.y + ((rect.Layout.h - 64) / 2) })
        then begin
          solid rs gl
            { Layout.x = rect.Layout.x + 2; y = rect.Layout.y + 2;
              w = rect.Layout.w - 4; h = rect.Layout.h - 4 }
            (Layout.gem_colour gem)
        end
      end
      else begin
        solid rs gl
          { Layout.x = rect.Layout.x + 2; y = rect.Layout.y + 2;
            w = rect.Layout.w - 4; h = rect.Layout.h - 4 }
          (Layout.gem_colour gem);
        let label = Layout.gem_letter gem in
        if label <> " " then
          match (ui.fonts, ui.system) with
          | Some f, Some m ->
            rs :=
              !rs
              @ Font.draw gl f m label
                  ~x:
                    (rect.Layout.x
                    + ((rect.Layout.w - Font_layout.measure m label) / 2))
                  ~y:(rect.Layout.y + 20)
          | _ -> ()
      end
    done
  done;
  (* The pending swap's first gem: a gold ring, the capture window's own. *)
  (match ui.forge_sel with
  | Some (c, r) ->
      let rect = Item_game_layout.cell_rect c r in
      let x = rect.Layout.x and y = rect.Layout.y in
      let w = rect.Layout.w and h = rect.Layout.h in
      let gold = Layout.rgb 240 210 90 in
      solid rs gl { Layout.x = x; y; w; h = 3 } gold;
      solid rs gl { Layout.x = x; y = y + h - 3; w; h = 3 } gold;
      solid rs gl { Layout.x = x; y; w = 3; h } gold;
      solid rs gl { Layout.x = x + w - 3; y; w = 3; h } gold
  | None -> ());
  (* The rules panel, when the art is there. *)
  (match ui.rules_tex with
  | None -> ()
  | Some tex ->
    let d = Item_game_layout.rules_rect in
    let first =
      Gl.push_quad ~tex_size:(128, 512) gl d
        (Some { Layout.x = 0; y = 0; w = 128; h = 512 })
        (Layout.rgb 255 255 255)
    in
    rs :=
      !rs
      @ [ { Gl.first; count = 6; tex = Some tex;
            colour = Layout.rgb 255 255 255; clip = None; blend = None } ]);
  (* The 21-icon meter: lit icons are the points already scored. *)
  for i = 0 to Item_game_layout.meter_count - 1 do
    let d = Item_game_layout.meter_rect i in
    let lit = i < Item_game.(game.score) in
    if
      not
        (draw_skin_scaled rs ui.skin gl
           (if lit then "img_hammanv_on" else "img_hammanv_off")
           ~dst:d)
    then
      solid rs gl d
        (if lit then Layout.rgb 196 160 96 else Layout.rgb 60 62 72)
  done;
  (match (ui.fonts, ui.system) with
  | Some f, Some m ->
      let text ?(colour = Layout.rgb 230 230 230) s x y =
        rs := !rs @ Font.draw gl f m s ~x ~y ~colour
      in
      text (Text_data.text "[ITEMGAME]") (Item_game_layout.title_cx - (Font_layout.measure m (Text_data.text "[ITEMGAME]") / 2)) Item_game_layout.title_y
        ~colour:(Layout.rgb 240 210 90);
      let hint =
        match Item_game.(game.status) with
        | Item_game.Playing -> Text_data.text "[ITEMGAME_HELP]"
        | Item_game.Won -> "the item is forged - click to collect it"
        | Item_game.Lost -> Text_data.text "[FORGEITEMS_FAIL]"
      in
      text hint
        (Item_game_layout.screen_w / 2 - (Font_layout.measure m hint / 2))
        Item_game_layout.help_y;
      text (ui.player.Campaign.name)
        (Item_game_layout.hero_name_cx - (Font_layout.measure m ui.player.Campaign.name / 2))
        Item_game_layout.hero_name_y;
      (* The item being forged, from the same triple the mint will use. *)
      (match Campaign.rune_item_of_triple ~base ~modifier ~power with
      | None -> ()
      | Some (it, _) ->
        let name = Text_data.text it.Campaign_items.name_text in
        text name
          (Item_game_layout.item_name_rect.Layout.x
          + ((Item_game_layout.item_name_rect.Layout.w - Font_layout.measure m name) / 2))
          (Item_game_layout.item_name_rect.Layout.y + 4);
        let desc = Text_data.text it.Campaign_items.power_text in
        let words = String.split_on_char ' ' desc in
        let rec wrap col acc = function
          | [] -> List.rev (if col = "" then acc else col :: acc)
          | w :: rest ->
            let cand = if col = "" then w else col ^ " " ^ w in
            if Font_layout.measure m cand <= Item_game_layout.item_desc_rect.Layout.w - 8
            then wrap cand acc rest
            else wrap w (col :: acc) rest
        in
        List.iteri
          (fun i line ->
            text line
              (Item_game_layout.item_desc_rect.Layout.x + 4)
              (Item_game_layout.item_desc_rect.Layout.y + 4 + (i * 16)))
          (List.take 12 (wrap "" [] words)));
      text (Text_data.text "[ITEMGAME_TARGET]")
        (Item_game_layout.targets_cx - (Font_layout.measure m (Text_data.text "[ITEMGAME_TARGET]") / 2))
        Item_game_layout.targets_y
  | _ -> ())

(* The capture minigame over everything: CaptureMenu.xml's grid as flat gem
   colours with the shipped letters, its title and help lines, the port's
   give-up button, and a gold ring on the first gem of a pending swap. A
   terminal state changes the hint and takes one more click, which is where
   [Campaign.capture_finish] runs (in the click handler). *)
let draw_capture (rs : Gl.run list ref) (gl : Gl.context) (ui : ui)
    (attempt : Capture.t) : unit =
  solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
    (Layout.rgba 0 0 0 190);
  let board = attempt.Capture.board in
  for r = 0 to 7 do
    for c = 0 to 7 do
      let rect = Capture_layout.cell_rect c r in
      let gem = Board.get_gem board { Board.x = c; y = r } in
      solid rs gl
        { Layout.x = rect.Layout.x + 2; y = rect.Layout.y + 2;
          w = rect.Layout.w - 4; h = rect.Layout.h - 4 }
        (Layout.gem_colour gem);
      let label = Layout.gem_letter gem in
      if label <> " " then (
        match (ui.fonts, ui.system) with
        | Some f, Some m ->
            rs :=
              !rs
              @ Font.draw gl f m label
                  ~x:
                    (rect.Layout.x
                    + ((rect.Layout.w - Font_layout.measure m label) / 2))
                  ~y:(rect.Layout.y + 48)
        | _ -> ())
    done
  done;
  (* The pending swap's first gem: a gold ring on the cell. *)
  (match ui.capture_sel with
  | Some (c, r) ->
      let rect = Capture_layout.cell_rect c r in
      let x = rect.Layout.x and y = rect.Layout.y in
      let w = rect.Layout.w and h = rect.Layout.h in
      let gold = Layout.rgb 240 210 90 in
      solid rs gl { Layout.x = x; y; w; h = 3 } gold;
      solid rs gl { Layout.x = x; y = y + h - 3; w; h = 3 } gold;
      solid rs gl { Layout.x = x; y; w = 3; h } gold;
      solid rs gl { Layout.x = x + w - 3; y; w = 3; h } gold
  | None -> ());
  (match (ui.fonts, ui.system) with
  | Some f, Some m ->
      let title = Text_data.text "[CAPTURE]" in
      rs :=
        !rs
        @ Font.draw gl f m title
            ~x:((window_w - Font_layout.measure m title) / 2)
            ~y:(Capture_layout.title_y + 22) ~colour:(Layout.rgb 240 210 90);
      let hint =
        match attempt.Capture.status with
        | Capture.Playing -> Text_data.text "[CAPTURE_HELP]"
        | Capture.Won -> "grid cleared - click to collect the captive"
        | Capture.Lost -> Text_data.text "[CAPTURE_FAIL]"
      in
      rs :=
        !rs
        @ Font.draw gl f m hint
            ~x:((window_w - Font_layout.measure m hint) / 2)
            ~y:(Capture_layout.help_y + 14);
      let cr = Capture_layout.cancel_rect in
      solid rs gl cr (Layout.rgb 40 44 56);
      solid rs gl { cr with Layout.h = 3 } (Layout.rgb 240 210 90);
      let label = Text_data.text "[CANCEL]" in
      rs :=
        !rs
        @ Font.draw gl f m label
            ~x:
              (cr.Layout.x
              + ((cr.Layout.w - Font_layout.measure m label) / 2))
            ~y:(cr.Layout.y + 21)
  | _ -> ())

let draw ?(present = true) (ui : ui) : unit =
  let gl = ui.gl in
  Gl.begin_frame gl;
  let rs = ref [] in
  (* Under the segments, so holes in the art are flat tiles rather than the
     clear colour. *)
  solid rs gl Map_view.rect (Layout.rgb 30 34 44);
  List.iter
    (fun ((r, c), tex) ->
      let dst = Map_view.segment_rect r c in
      match tex with
      | Some t -> segment rs gl dst t
      | None -> solid rs gl dst (Layout.rgb 46 52 66))
    ui.segments;
  (* Roads: both endpoints visible is the drawing of the same rule travel     uses - a hidden endpoint hides the road. Thin rotated quads; [rotate]
     turns the corners about the centre, which is exactly a segment. *)
  List.iter
    (fun (road : Campaign_map.road) ->
      match
        ( Hashtbl.find_opt Campaign.map_nodes road.Campaign_map.start,
          Hashtbl.find_opt Campaign.map_nodes road.Campaign_map.end_ )
      with
      | Some a, Some b when a.Campaign.visible && b.Campaign.visible ->
          let ax, ay = Map_view.world_to_screen a.Campaign.x a.Campaign.y in
          let bx, by = Map_view.world_to_screen b.Campaign.x b.Campaign.y in
          let dx = float_of_int (bx - ax) and dy = float_of_int (by - ay) in
          let len = sqrt ((dx *. dx) +. (dy *. dy)) in
          if len >= 2.0 then begin
            let half = int_of_float (len /. 2.0) in
            let dst =
              { Layout.x = ((ax + bx) / 2) - half; y = ((ay + by) / 2) - 1;
                w = half * 2; h = 2 }
            in
            solid rs gl dst ~rotate:(atan2 dy dx) (Layout.rgb 168 158 120)
          end
      | _ -> ())
    Campaign_map.roads;
  (* Nodes: visible ones only - the flags the fog already maintains. *)
  Hashtbl.iter
    (fun _ (n : Campaign.map_node) ->
      if n.visible then begin
        let sx, sy = Map_view.world_to_screen n.Campaign.x n.Campaign.y in
        let s =
          match n.Campaign.kind with
          | Campaign.City -> 9
          | Campaign.Waypoint -> 5
          | Campaign.Ruin -> 7
        in
        solid rs gl
          { Layout.x = sx - (s / 2); y = sy - (s / 2); w = s; h = s }
          (node_colour n.Campaign.kind)
      end)
    Campaign.map_nodes;
  (* The hero: a red marker over wherever they stand. *)
  let hwx, hwy = hero_world ui in
  let hx, hy = Map_view.world_to_screen hwx hwy in
  solid rs gl { Layout.x = hx - 7; y = hy - 7; w = 14; h = 14 }
    (Layout.rgb 235 70 60);
  (* The city panel sits over the map, under the encounter popup - a fight     found on the road outranks browsing. *)
  (match ui.city with
  | Some cv -> draw_city rs gl ui cv
  | None -> ());
  (* The hosted dialogue over whatever is underneath; the road popup still     outranks it in the click order below. *)
  if Conv_window.busy ui.conv then Conv_window.draw ~present:false ui.conv;
  (* The encounter popup: dim the map, banner, and the one line that says     what a click does. *)
  (match ui.popup with
  | Some enc ->
      solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
        (Layout.rgba 0 0 0 150);
      let bw = 620 and bh = 150 in
      let bx = (window_w - bw) / 2 and by = (window_h - bh) / 2 in
      solid rs gl { Layout.x = bx; y = by; w = bw; h = bh }
        (Layout.rgb 24 26 34);
      solid rs gl { Layout.x = bx; y = by; w = bw; h = 3 }
        (Layout.rgb 240 210 90);
      (match (ui.fonts, ui.system) with
      | Some f, Some m ->
          let title =
            match ui.popup_rune with
            | Some _ -> "A Runekeeper guards a rune here!"
            | None ->
                "The " ^ enc.Campaign_encounters.description
                ^ " blocks the road!"
          in
          rs :=
            !rs
            @ Font.draw gl f m title
                ~x:(bx + ((bw - Font_layout.measure m title) / 2))
                ~y:(by + 44);
          let hint = "click to fight" in
          rs :=
            !rs
            @ Font.draw gl f m hint
                ~x:(bx + ((bw - Font_layout.measure m hint) / 2))
                ~y:(by + 90) ~colour:(Layout.rgb 240 210 90)
      | _ -> ())
  | None ->
      ());
  (* The capture minigame outranks everything, popup included. *)
  (match ui.capture with
  | Some (_, attempt) -> draw_capture rs gl ui attempt
  | None -> ());
  (* The forge skill game over the city panel - drawn last so it is the
     topmost thing up, capture included. *)
  (match ui.forge_game with
  | Some fg -> draw_forge_game rs gl ui fg
  | None -> ());
  Gl.submit gl !rs;
  if present then Gl.present gl

(* The minigame holds every click while it is up: a terminal state takes one
   more click to apply and close, otherwise a click selects a gem, swaps it
   with an orthogonally adjacent second, or backs out through [CANCEL]. *)
let handle_capture_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.capture with
  | None -> ()
  | Some (mid, attempt) -> (
    match attempt.Capture.status with
    | Capture.Won | Capture.Lost ->
        let won = attempt.Capture.status = Capture.Won in
        ui.player <- Campaign.capture_finish ui.player mid attempt;
        ui.capture <- None;
        ui.capture_sel <- None;
        (if won then
           Printf.printf "  captured %s!\n"
             (try
                Text_data.text
                  (Campaign_monsters.monster_by_id mid)
                    .Campaign_monsters.name_text
              with Not_found -> mid)
         else Printf.printf "  %s\n" (Text_data.text "[CAPTURE_FAIL]"));
        flush stdout
    | Capture.Playing -> (
        match Capture_layout.hit mx my with
        | Capture_layout.Cancel ->
            ui.capture <- None;
            ui.capture_sel <- None;
            Printf.printf "  capture cancelled - try again later\n";
            flush stdout
        | Capture_layout.Cell (c, r) -> (
            match ui.capture_sel with
            | Some (c0, r0) when c0 = c && r0 = r -> ui.capture_sel <- None
            | Some (c0, r0) when abs (c0 - c) + abs (r0 - r) = 1 -> (
                match
                  Capture.play attempt
                    { Board.from_pos = { Board.x = c0; Board.y = r0 };
                      Board.to_pos = { Board.x = c; Board.y = r } }
                with
                | Some next ->
                    ui.capture <- Some (mid, next);
                    ui.capture_sel <- None
                | None ->
                    (* an illegal swap reselects on the clicked gem *)
                    ui.capture_sel <- Some (c, r))
            | _ -> ui.capture_sel <- Some (c, r))
        | Capture_layout.Miss -> ()))

(* The forge skill game holds every click while it is up, capture included -
   the two cannot be open at once, but the priority keeps the draw and the
   click in the same order. A terminal state takes one more click, which is
   where the mint ([Campaign.forge_item], a win) or [FORGEITEMS_FAIL] (a
   loss) runs and the runes stay held either way. *)
let handle_forge_game_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.forge_game with
  | None -> ()
  | Some (base, modifier, power, game) -> (
    match Item_game.(game.status) with
    | Item_game.Won | Item_game.Lost ->
        let won = Item_game.(game.status) = Item_game.Won in
        ui.forge_game <- None;
        ui.forge_sel <- None;
        if won then
          match
            Campaign.forge_item ui.player ~base ~modifier ~power
          with
          | Some (player, it) ->
              ui.player <- player;
              Printf.printf "  %s %s\n"
                (Text_data.text "[FORGEITEMS_SUCCESS]")
                (Text_data.text it.Campaign_items.name_text);
              flush stdout
          | None ->
              (* The cap cannot race - it is checked before the game opens
                 and forge_item re-checks it - so this is the held-rune gate
                 failing under a triple the panel offered. *)
              Printf.printf "  %s\n" (Text_data.text "[FORGEITEMS_FAIL]");
              flush stdout
        else begin
          Printf.printf "  %s\n" (Text_data.text "[FORGEITEMS_FAIL]");
          flush stdout
        end
    | Item_game.Playing -> (
        match Item_game_layout.hit mx my with
        | `Miss -> ()
        | `Cell (c, r) -> (
            match ui.forge_sel with
            | Some (c0, r0) when c0 = c && r0 = r -> ui.forge_sel <- None
            | Some (c0, r0) when abs (c0 - c) + abs (r0 - r) = 1 -> (
                match
                  Item_game.play game
                    { Board.from_pos = { Board.x = c0; Board.y = r0 };
                      Board.to_pos = { Board.x = c; Board.y = r } }
                with
                | Some next ->
                    ui.forge_game <- Some (base, modifier, power, next);
                    ui.forge_sel <- None
                | None ->
                    (* an illegal swap reselects on the clicked gem *)
                    ui.forge_sel <- Some (c, r))
            | _ -> ui.forge_sel <- Some (c, r))))

let handle_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.forge_game with
  | Some _ -> handle_forge_game_click ui mx my
  | None -> (
  match ui.capture with
  | Some _ -> handle_capture_click ui mx my
  | None -> (
  match ui.popup with
  | Some enc ->
      (* The road fight holds everything, dialogue included - and is played
         on the battle screen rather than run headless: opened with the
         screen's choices, run through it, then settled. *)
      (match
         Campaign.encounter_battle_open ~rng:Random.int
           ~human:(Battle_screen.hooks ()) ui.player enc
       with
      | None ->
          Printf.printf "  no registry monster behind the %s - nothing to fight\n"
            enc.Campaign_encounters.description;
          flush stdout;
          ui.popup <- None
      | Some opened ->
          let battle = Battle_screen.run opened in
          let player, result =
            Campaign.process_battle_result ui.player enc battle
          in
          ui.player <- player;
          ui.popup <- None;
          Printf.printf "  %s: %s in %d turns (life %d, +%d gold, +%d xp)\n"
            enc.Campaign_encounters.description
            (if result.Campaign.player_won then "won" else "lost")
            battle.Battle.turns_elapsed result.Campaign.final_life
            result.Campaign.gold_gained result.Campaign.xp_gained;
          flush stdout;
          (* A won fight whose monster passes the capture gates opens the
             minigame right away (port.capture_ui). *)
          if result.Campaign.player_won then
            (match Campaign.capture_offer ui.player enc with
            | Some mid ->
                ui.capture <- Some (mid, Campaign.capture_begin mid);
                ui.capture_sel <- None;
                Printf.printf "  the %s can be captured - swap two gems, or Cancel\n"
                  enc.Campaign_encounters.description;
                flush stdout
            | None -> ());
          (* A won keeper fight claims the rune it guards ([RUNE_HELP]). *)
          (match ui.popup_rune with
          | Some rid ->
              ui.popup_rune <- None;
              if result.Campaign.player_won then
                (match Campaign.claim_rune ui.player rid with
                | Some p' ->
                    ui.player <- p';
                    Printf.printf "  %s %s\n" (Text_data.text "[RUNE_SUCCESS]")
                      (Text_data.text (rune_display rid));
                    flush stdout
                | None -> ())
          | None -> ()))
  | None ->
      if Conv_window.busy ui.conv then begin
        Conv_window.handle_click ui.conv mx my;
        (* The click may have dismissed a battle banner whose won fight
           left a capture waiting - open it over whatever the conversation
           still holds (port.capture_surfaces). *)
        (match Conv_window.take_capture_offer ui.conv with
        | Some mid ->
            ui.capture <- Some (mid, Campaign.capture_begin mid);
            ui.capture_sel <- None;
            Printf.printf "  capture available: %s - swap two gems, or Cancel\n"
              (monster_name mid);
            flush stdout
        | None -> ())
      end
      else (
      match ui.city with
      | Some cv -> handle_city_click ui cv mx my
      | None -> (
          match Map_view.hit_node mx my with
          | None -> ()
          | Some id -> (
              let here =
                match ui.player.Campaign.current_city with
                | Some c -> c
                | None -> ""
              in
              if id = here then
                (* Clicking the city you stand in opens it - the city click     the screen exists for. A rune node offers its keeper; waypoints     otherwise just say where you already are. *)
                match Hashtbl.find_opt Campaign.map_nodes id with
                | Some n when n.Campaign.kind = Campaign.City ->
                    open_city ui id
                | _ -> (
                    match Campaign.rune_at_node id with
                    | Some rid when Campaign.rune_claimable ui.player rid -> (
                        match Campaign.runekeeper_encounter rid with
                        | Some enc ->
                            ui.popup <- Some enc;
                            ui.popup_rune <- Some rid;
                            Printf.printf
                              "  a Runekeeper guards a rune here - click to \
                               fight!\n";
                            flush stdout
                        | None ->
                            Printf.printf "  already at %s\n" id;
                            flush stdout)
                    | _ ->
                        Printf.printf "  already at %s\n" id;
                        flush stdout)
              else
                match Campaign.begin_travel ui.player here id with
                | None ->
                    Printf.printf "  no revealed road to %s\n" id;
                    flush stdout
                | Some journey ->
                    ui.journey <- Some journey;
                    Printf.printf "  walking to %s\n" id;
                    flush stdout;
                    (* The departure roll: the port asks the road once,
                       here - unless the trained mount slips past it
                       (port.mount_training). *)
                    if Campaign.mount_avoids ui.player then begin
                      Printf.printf
                        "  your mount avoids the encounter (%d%% chance)\n"
                        (Campaign.mount_avoid_chance ui.player);
                      flush stdout
                    end
                    else
                    (match Campaign.road_encounter ui.player here id with
                    | Some enc ->
                        ui.popup <- Some enc;
                        ui.popup_rune <- None;
                        Printf.printf "  %s stops you on the road!\n"
                          enc.Campaign_encounters.description;
                        flush stdout
                    | None -> ()))))))

(** One frame: the hosted dialogue first - it holds walking while a box, a
    tree or a banner is up, and when it drains the pending action completes
    - then the road popup holds the journey where it is, then walking,
    which through [advance_travel_with_events] fires the arrival moment. *)
let step (ui : ui) (dt : float) : unit =
  Conv_window.sync_player ui.conv ui.player;
  (* The minigames hold the hosted dialogue where it is too: no scriptcall
     fires a battle behind the grids. *)
  if ui.capture = None && ui.forge_game = None then begin
    Conv_window.step ui.conv dt;
    ui.player <- Conv_window.player_of ui.conv
  end;
  if Conv_window.busy ui.conv || ui.capture <> None || ui.forge_game <> None
  then ()
  else begin
    (match ui.pending with
    | Some (qid, loc) ->
        ui.pending <- None;
        (* The action's stage fight, when the stage has one: opened with the
           screen's choices, played on the battle screen, settled - then
           [complete_action] runs OnCompleteAction under the real outcome,
           which is the engine's order on the return to the map. A stage with
           no battle completes as it always did, success implied. *)
        (match
           Campaign.quest_battle_open ~rng:Random.int
             ~human:(Battle_screen.hooks ()) ui.player qid
         with
        | None ->
            ui.player <- Campaign.complete_action ~success:true ui.player qid loc
        | Some qf ->
            let battle = Battle_screen.run qf.Campaign.qf_battle in
            let won = Battle.hero_won battle in
            let player, offer = qf.Campaign.qf_finish battle in
            ui.player <- player;
            Printf.printf "  %s: %s in %d turns (life %d)\n" qid
              (if won then "won" else "lost")
              battle.Battle.turns_elapsed player.Campaign.life;
            flush stdout;
            (* The win's capture offer, computed by the settle where the
               stage's flag and monster id live (port.capture_surfaces). *)
            (match offer with
            | Some mid ->
                ui.capture <- Some (mid, Campaign.capture_begin mid);
                ui.capture_sel <- None;
                Printf.printf "  capture available: %s - swap two gems, or Cancel\n"
                  (monster_name mid);
                flush stdout
            | None -> ());
            ui.player <-
              Campaign.complete_action ~success:won ui.player qid loc);
        Printf.printf "  %s: action finished at %s\n" qid loc;
        flush stdout
    | None -> ());
    match (ui.journey, ui.popup) with
    | Some _, Some _ -> ()
    (* the minigames hold the journey where it is, like the popup does *)
    | _, _ when ui.capture <> None || ui.forge_game <> None -> ()
    | Some j, None -> (
        let p', ts' =
          Campaign.advance_travel_with_events ui.player j (walk_speed *. dt)
        in
        match ts' with
        | Campaign.Traveling j' ->
            ui.player <- p';
            ui.journey <- Some (Campaign.Traveling j')
        | Campaign.AtNode id ->
            ui.player <- { p' with Campaign.current_city = Some id };
            ui.journey <- None;
            Printf.printf "  arrived at %s\n" id;
            flush stdout;
            (* Arriving in a city is entering it. *)
            (match Hashtbl.find_opt Campaign.map_nodes id with
            | Some n when n.Campaign.kind = Campaign.City -> open_city ui id
            | _ -> ())
        | other ->
            ui.player <- p';
            ui.journey <- Some other)
    | None, _ -> ()
  end

let () =
  Random.self_init ();
  let shot = ref "" and open_city_flag = ref false
  and itemgame_flag = ref false and settings_flag = ref false
  and lang = ref (-1) in
  Arg.parse
    [ ( "--shot",
        Arg.Set_string shot,
        "draw one frame, write it as a P6 ppm, and exit" );
      ( "--city",
        Arg.Set open_city_flag,
        "open the start city's panel on startup (for --shot)" );
      ( "--itemgame",
        Arg.Set itemgame_flag,
        "open the forge skill game over the gifted triple (for --shot)" );
      ( "--settings",
        Arg.Set settings_flag,
        "open the city panel's Settings tab on startup (for --shot)" );
      ( "--lang",
        Arg.Set_int lang,
        "boot in language 0..4 (English..Italian), for --shot" ) ]
    (fun a -> raise (Arg.Bad a))
    "pq_map_gfx [--shot FILE] [--city] [--itemgame] [--settings] [--lang N]";
  (* The language sets before anything draws or any module-level table is
     read through Text_data - the whole switch is live, but a shot wants the
     boot language to be the one it photographs. Unshipped ids fall back to
     English inside set_language. *)
  if !lang >= 0 then Text_data.set_language !lang;
  let gl =
    Gl.create ~title:"Puzzle Quest - world map" ~width:window_w
      ~height:window_h
  in
  (* The playable battle screen, hosted on this window's context: road,
     quest-stage and callback fights all run through it, so the art loads
     once here rather than per fight. The module holds the one screen per
     process - [Battle_screen.hooks] and [Battle_screen.run] reach it, so
     the handle is not threaded through the ui record. *)
  ignore (Battle_screen.create ~gl);
  let segments = load_segments () in
  let missing =
    List.length (List.filter (fun (_, t) -> t = None) segments)
  in
  if missing > 0 then
    Printf.printf
      "  %d of %d map segments missing from %s - run tools/extract_gfx_assets.py (flat tiles)\n"
      missing
      (Map_view.segments_side * Map_view.segments_side)
      (asset_dir ());
  let fonts =
    Font.create
      ~styles:
        (List.filter_map Font_layout.metrics_of_tag
           [ "font_system"; "font_small" ])
  in
  (match fonts with
  | None ->
      Printf.printf "  no font atlases in %s - run tools/extract_gfx_assets.py (no labels)\n"
        (Font.face_dir ())
  | Some _ -> ());
  let start = Campaign.create_player "Hero" "PWAR" 0 1 in
  let start_city =
    start.Campaign.profession.Campaign_professions.start_city
  in
  let hero = { start with Campaign.current_city = Some start_city } in
  let system = Font_layout.metrics_of_tag "font_system" in
  let ui =
    { gl; segments; fonts; system;
      player = hero;
      journey = None; popup = None; popup_rune = None; city = None;
      conv =
        Conv_window.create ~gl ~fonts ~system ~player:hero
          ~human:(Battle_screen.hooks ())
          ~run_battle:Battle_screen.run
          ();
      pending = None;
      capture = None;
      capture_sel = None;
      forge_game = None;
      forge_sel = None;
      (* The gems-grid sheet carries the hammer art the skill game's meter
         and board draw from; a checkout without it falls back to flat
         squares, the same contract every other sheet here keeps. *)
      skin = Skin.create ~gl ~sheets:[ "bmp_skin_gemsgrid" ];
      rules_tex = load_rules_texture () }
  in
  if !open_city_flag then open_city ui start_city;
  (* --itemgame prefills the gifted triple the Forge tab would hold and
     opens the skill game, so --shot can photograph it without a click
     sequence - the same discipline the battle front's --demo/--shot uses. *)
  if !itemgame_flag then begin
    open_city ui start_city;
    match ui.city with
    | None -> ()
    | Some cv ->
        cv.tab <- Forge;
        cv.forge_base <- Some "UDAG";
        cv.forge_mod <- Some "UCRA";
        cv.forge_pow <- Some "UFIR";
        let target =
          match
            Campaign.forge_rune ui.player ~base:"UDAG" ~modifier:"UCRA"
              ~power:"UFIR"
          with
          | Some spec ->
              Item_game.target_for_difficulty spec.Campaign.difficulty
          | None -> 1
        in
        ui.forge_game <-
          Some ("UDAG", "UCRA", "UFIR", Item_game.create ~rng:Random.int ~target ())
  end;
  (* --settings opens the city panel's Settings tab so --shot can photograph
     the two dropdown rows without cycling the mode button eight times. *)
  if !settings_flag then begin
    open_city ui start_city;
    match ui.city with
    | None -> ()
    | Some cv -> cv.tab <- Settings
  end;
  Printf.printf
    "renderer: %s\n  GL: %s\n  map: %d world px at 3/8 scale, origin (%d, %d)\n"
    (Gl.renderer_name ()) (Gl.gl_version ()) Map_view.world Map_view.origin_x
    Map_view.origin_y;
  print_endline
    "  click a revealed node to walk there; the city's Actions tab runs quest\n  actions (their dialogue opens over the map); click the popup to fight;\n  close the window to quit";
  flush stdout;
  (* --shot is how this front is checked without a display: one frame, the
     same raw RGBA path the battle front photographs with. *)
  if !shot <> "" then begin
    draw ~present:false ui;
    let px = Gl.read_frame_rgba ~width:window_w ~height:window_h in
    let oc = open_out_bin !shot in
    output_string oc (Printf.sprintf "P6\n%d %d\n255\n" window_w window_h);
    let n = window_w * window_h in
    let rgb = Bytes.create (n * 3) in
    for i = 0 to n - 1 do
      Bytes.set rgb (i * 3 + 0) (Bigarray.Array1.get px ((i * 4) + 0));
      Bytes.set rgb (i * 3 + 1) (Bigarray.Array1.get px ((i * 4) + 1));
      Bytes.set rgb (i * 3 + 2) (Bigarray.Array1.get px ((i * 4) + 2))
    done;
    output_bytes oc rgb;
    close_out oc;
    Printf.printf "wrote %s (%dx%d)\n" !shot window_w window_h;
    flush stdout;
    Gl.destroy gl;
    exit 0
  end;
  let ev = Sdl.Event.create () in
  let last = ref (Sdl.get_ticks ()) in
  let running = ref true in
  while !running do
    while Sdl.poll_event (Some ev) && !running do
      let t = E.get ev E.typ in
      if t = E.quit then running := false
      else if t = E.mouse_button_down then
        handle_click ui (E.get ev E.mouse_button_x)
          (E.get ev E.mouse_button_y)
    done;
    if !running then begin
      let now = Sdl.get_ticks () in
      let dt =
        float_of_int (Int32.to_int (Int32.sub now !last)) /. 1000.0
      in
      last := now;
      (* Cap the frame: a stall must not teleport the hero across a road. *)
      step ui (min dt 0.1);
      draw ui;
      Sdl.delay 16l
    end
  done;
  Gl.destroy gl;
  print_endline "map closed"
