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

type ui = {
  gl : Gl.context;
  segments : ((int * int) * Gl.texture option) list;
  fonts : Font.t option;
  system : Font_layout.metrics option;
  mutable player : Campaign.player;
  mutable journey : Campaign.travel_state option;
  mutable popup : Campaign_encounters.encounter option;
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

(** A click: the popup takes it as the fight; otherwise the map offers a     node to walk to. *)
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
      match Map_view.hit_node mx my with
      | None -> ()
      | Some id -> (
          let here =
            match ui.player.Campaign.current_city with
            | Some c -> c
            | None -> ""
          in
          if id = here then begin
            Printf.printf "  already at %s\n" id;
            flush stdout
          end
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
                | None -> ())))

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
          flush stdout
      | other -> ui.journey <- Some other)
  | None, _ -> ()

let () =
  Random.self_init ();
  let shot = ref "" in
  Arg.parse
    [ ( "--shot",
        Arg.Set_string shot,
        "draw one frame, write it as a P6 ppm, and exit" ) ]
    (fun a -> raise (Arg.Bad a))
    "pq_map_gfx [--shot FILE]";
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
      journey = None; popup = None }
  in
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
