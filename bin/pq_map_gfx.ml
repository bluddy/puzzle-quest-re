(** The world map in a window: the node graph, the road graph, the hero on
    it, and a click to walk somewhere.

    Everything about {e what happens} belongs to the engine:
    [Campaign.begin_travel] only opens a revealed road, [advance_travel]
    walks it and lands on [AtNode], [road_encounter] asks the road's list
    once at departure - and when the hero stops, the popup says so. This
    front end draws those states and feeds them clicks; nothing about the
    recovered rules is re-implemented here.

    The art contract is the battle front's: without
    tools/extract_gfx_assets.py the sixteen map segments are missing and the
    window still opens, on flat colours, which is the only state a fresh
    checkout can honestly be in.

    The fight itself runs headless through the campaign API and the window
    reports the result on the console - hosting the battle view inside the
    map is the coupling neither front end wants yet. *)
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

type city_tab = Shop | Spells | Tavern

type city_view = {
  cid : string;
  mutable tab : city_tab;
  mutable rumor : int;
}

type ui = {
  gl : Gl.context;
  segments : ((int * int) * Gl.texture option) list;
  fonts : Font.t option;
  system : Font_layout.metrics option;
  mutable player : Campaign.player;
  mutable journey : Campaign.travel_state option;
  mutable popup : Campaign_encounters.encounter option;
  mutable city : city_view option;
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
  match t with Shop -> Spells | Spells -> Tavern | Tavern -> Shop

let tab_label (t : city_tab) : string =
  match t with
  | Shop -> Text_data.text "[BUYITEMS]"
  | Spells -> Text_data.text "[SELECTSPELLMENU_HEADING]"
  | Tavern -> Text_data.text "[RUMORS]"

let open_city (ui : ui) (cid : string) : unit =
  ui.city <- Some { cid; tab = Shop; rumor = 0 };
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
      if cv.tab = Tavern then show_rumor cv
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
      | Tavern -> advance_rumor cv)
  | City_layout.Elsewhere -> (
      match cv.tab with Tavern -> advance_rumor cv | Shop | Spells -> ())

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
      | None -> ()));
  solid rs gl City_layout.mode_btn (Layout.rgb 44 48 60);
  solid rs gl City_layout.done_btn (Layout.rgb 44 48 60);
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
            ~y:(City_layout.done_btn.Layout.y + 16)
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
            "The " ^ enc.Campaign_encounters.description ^ " blocks the road!"
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
  Gl.submit gl !rs;
  if present then Gl.present gl

let handle_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.popup with
  | Some enc ->
      let battle = Campaign.run_encounter_battle ui.player enc in
      let player, result = Campaign.process_battle_result ui.player enc battle in
      ui.player <- player;
      ui.popup <- None;
      Printf.printf "  %s: %s in %d turns (life %d, +%d gold, +%d xp)\n"
        enc.Campaign_encounters.description
        (if result.Campaign.player_won then "won" else "lost")
        battle.Battle.turns_elapsed result.Campaign.final_life
        result.Campaign.gold_gained result.Campaign.xp_gained;
      flush stdout
  | None -> (
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
                (* Clicking the city you stand in opens it - the city click     the screen exists for. Waypoints just say where you already are. *)
                match Hashtbl.find_opt Campaign.map_nodes id with
                | Some n when n.Campaign.kind = Campaign.City ->
                    open_city ui id
                | _ ->
                    Printf.printf "  already at %s\n" id;
                    flush stdout
              else
                match Campaign.begin_travel here id with
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
                        Printf.printf "  %s stops you on the road!\n"
                          enc.Campaign_encounters.description;
                        flush stdout
                    | None -> ()))))

(** One frame's walking. The popup holds the journey where it is. *)
let step (ui : ui) (dt : float) : unit =
  match (ui.journey, ui.popup) with
  | Some _, Some _ -> ()
  | Some j, None -> (
      match Campaign.advance_travel j (walk_speed *. dt) with
      | Campaign.Traveling j' -> ui.journey <- Some (Campaign.Traveling j')
      | Campaign.AtNode id ->
          ui.journey <- None;
          ui.player <- { ui.player with Campaign.current_city = Some id };
          Printf.printf "  arrived at %s\n" id;
          flush stdout;
          (* Arriving in a city is entering it. *)
          (match Hashtbl.find_opt Campaign.map_nodes id with
          | Some n when n.Campaign.kind = Campaign.City -> open_city ui id
          | _ -> ())
      | other -> ui.journey <- Some other)
  | None, _ -> ()

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
  let ui =
    { gl; segments; fonts; system = Font_layout.metrics_of_tag "font_system";
      player = { start with Campaign.current_city = Some start_city };
      journey = None; popup = None; city = None }
  in
  if !open_city_flag then open_city ui start_city;
  Printf.printf
    "renderer: %s\n  GL: %s\n  map: %d world px at 3/8 scale, origin (%d, %d)\n"
    (Gl.renderer_name ()) (Gl.gl_version ()) Map_view.world Map_view.origin_x
    Map_view.origin_y;
  print_endline
    "  click a revealed node to walk there; click the popup to fight; close the window to quit";
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
