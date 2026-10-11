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
    map, and when that drains the driver follows with [complete_action]. This
    front end draws those states and feeds them clicks; nothing about the
    recovered rules is re-implemented here.

    The art contract is the battle front's: without
    tools/extract_gfx_assets.py the sixteen map segments are missing and the
    window still opens, on flat colours, which is the only state a fresh
    checkout can honestly be in.

    The road fight itself runs headless through the campaign API and the
    window reports the result on the console - hosting the battle view
    inside the map is the coupling neither front end wants yet. A won fight
    whose monster passes the capture gates opens the minigame instead
    ([Campaign.capture_offer]): CaptureMenu.xml's grid drawn as flat gem
    colours, two clicks a swap through [Capture.play], and the console's
    [CANCEL] button standing in for the gamepad back-out. *)
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

type city_tab = Shop | Spells | Tavern | Actions | Companions | Pets | Forge

type city_view = {
  cid : string;
  mutable tab : city_tab;
  mutable rumor : int;
  mutable forge_base : string option;  (** the triple the forge tab holds *)
  mutable forge_mod : string option;
  mutable forge_pow : string option;
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
  | Forge -> Shop

let tab_label (t : city_tab) : string =
  match t with
  | Shop -> Text_data.text "[BUYITEMS]"
  | Spells -> Text_data.text "[SELECTSPELLMENU_HEADING]"
  | Tavern -> Text_data.text "[RUMORS]"
  | Actions -> "Actions"
  | Companions -> Text_data.text "[COMPANIONS]"
  | Pets -> Text_data.text "[PETS]"
  | Forge -> Text_data.text "[FORGEITEMS]"

let open_city (ui : ui) (cid : string) : unit =
  ui.city <-
    Some
      { cid; tab = Shop; rumor = 0; forge_base = None; forge_mod = None;
        forge_pow = None };
  Printf.printf "  entered %s\n"
    (Text_data.text (Campaign_map.city_by_id cid).Campaign_map.name_text);
  flush stdout

(** The console's half of the tavern: the name is on screen, the whole text     is where a paragraph can be read. The panel has no word-wrap - that is a     font feature this front does not use yet. *)
let show_rumor (cv : city_view) : unit =
  match List.nth_opt Campaign.rumors cv.rumor with
  | Some (n, d) ->
      Printf.printf "  rumor %d/%d - %s\n    %s\n" (cv.rumor + 1)
        (List.length Campaign.rumors) n d;
      flush stdout
  | None -> ()

let advance_rumor (cv : city_view) : unit =
  let n = List.length Campaign.rumors in
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
                (if cv.forge_pow = Some id then None else Some id)))
  | City_layout.Forge ->
      if cv.tab <> Forge then ()
      else (
        match (cv.forge_base, cv.forge_mod, cv.forge_pow) with
        | Some b, Some m, Some w -> (
            match Campaign.forge_item ui.player ~base:b ~modifier:m ~power:w with
            | Some (player, it) ->
                ui.player <- player;
                cv.forge_base <- None;
                cv.forge_mod <- None;
                cv.forge_pow <- None;
                Printf.printf "  %s %s\n"
                  (Text_data.text "[FORGEITEMS_SUCCESS]")
                  (Text_data.text it.Campaign_items.name_text);
                flush stdout
            | None ->
                Printf.printf "  %s\n" (Text_data.text "[FORGEITEMS_FAIL]");
                flush stdout)
        | _ ->
            Printf.printf "  %s\n" (Text_data.text "[FORGEITEMS_3RUNES]");
            flush stdout)
  | City_layout.Elsewhere -> (
      match cv.tab with
      | Tavern -> advance_rumor cv
      | Shop | Spells | Actions | Companions | Pets | Forge -> ())

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
      match List.nth_opt Campaign.rumors cv.rumor with
      | Some (n, _) ->
          text ~colour:(Layout.rgb 240 210 90) n
            (City_layout.row_x + 30)
            City_layout.row_y0;
          text ~colour:(Layout.rgb 150 150 160)
            (Printf.sprintf "rumor %d/%d - click for another"
               (cv.rumor + 1) (List.length Campaign.rumors))
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

let handle_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.capture with
  | Some _ -> handle_capture_click ui mx my
  | None -> (
  match ui.popup with
  | Some enc ->
      (* The road fight holds everything, dialogue included. *)
      let battle = Campaign.run_encounter_battle ui.player enc in
      let player, result = Campaign.process_battle_result ui.player enc battle in
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
      | None -> ())
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
                    (* The departure roll: the port asks the road once, here. *)
                    (match Campaign.road_encounter ui.player here id with
                    | Some enc ->
                        ui.popup <- Some enc;
                        ui.popup_rune <- None;
                        Printf.printf "  %s stops you on the road!\n"
                          enc.Campaign_encounters.description;
                        flush stdout
                    | None -> ())))))

(** One frame: the hosted dialogue first - it holds walking while a box, a
    tree or a banner is up, and when it drains the pending action completes
    - then the road popup holds the journey where it is, then walking,
    which through [advance_travel_with_events] fires the arrival moment. *)
let step (ui : ui) (dt : float) : unit =
  Conv_window.sync_player ui.conv ui.player;
  (* The minigame holds the hosted dialogue where it is too: no scriptcall
     fires a battle behind the grid. *)
  if ui.capture = None then begin
    Conv_window.step ui.conv dt;
    ui.player <- Conv_window.player_of ui.conv
  end;
  if Conv_window.busy ui.conv || ui.capture <> None then ()
  else begin
    (match ui.pending with
    | Some (qid, loc) ->
        ui.pending <- None;
        ui.player <- Campaign.complete_action ~success:true ui.player qid loc;
        Printf.printf "  %s: action finished at %s\n" qid loc;
        flush stdout
    | None -> ());
    match (ui.journey, ui.popup) with
    | Some _, Some _ -> ()
    (* the minigame holds the journey where it is, like the popup does *)
    | _, _ when ui.capture <> None -> ()
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
  let shot = ref "" and open_city_flag = ref false in
  Arg.parse
    [ ( "--shot",
        Arg.Set_string shot,
        "draw one frame, write it as a P6 ppm, and exit" );
      ( "--city",
        Arg.Set open_city_flag,
        "open the start city's panel on startup (for --shot)" ) ]
    (fun a -> raise (Arg.Bad a))
    "pq_map_gfx [--shot FILE] [--city]";
  let gl =
    Gl.create ~title:"Puzzle Quest - world map" ~width:window_w
      ~height:window_h
  in
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
      conv = Conv_window.create ~gl ~fonts ~system ~player:hero;
      pending = None;
      capture = None;
      capture_sel = None }
  in
  if !open_city_flag then open_city ui start_city;
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
