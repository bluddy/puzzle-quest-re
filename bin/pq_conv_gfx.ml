(** The conversation window: portraits, dialogue text, choices, and input.

    The engine triggers conversations via [Lua_QUEST_CONVERSATION] with two
    string arguments (conversation ID and starting point). This front end
    draws the conversation UI: character portrait, dialogue text, and
    choice buttons. The actual dialogue flow is driven by the engine's
    [Lua_QUEST_CONVERSATION] which we call with the conversation ID and
    starting point. The front end renders the current line and any choices,
    and reports the player's selection back to the engine.

    Missing art falls back to flat colours, so a fresh checkout still runs.
    Run [tools/extract_text_tables.py] first to populate the conversation texts. *)

open Puzzle_quest_lib
open Pq_gfx
open Tsdl
module E = Tsdl.Sdl.Event

let window_w = Layout.game_screen_w
let window_h = Layout.game_screen_h

let asset_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p && Sys.is_directory p -> p
  | _ -> "assets/gfx"

type ui = {
  gl : Gl.context;
  portraits : (string * Gl.texture option) list;
  fonts : Pq_gfx.Font.t option;
  system : Font_layout.metrics option;
  small : Font_layout.metrics option;
  mutable conversation : Conversation.t option;
  mutable current_line : int;
  mutable scroll : int;
  mutable choices : (string * string) list option;  (* (text, target) for choices *)
  mutable selected_choice : int option;
}

let portrait_names = [
    "NPC_Darkhunter"; "NPC_Drong"; "NPC_Drong_Large"; "NPC_NGrd";
    "NPC_Serephine"; "NPC_Nwin"; "NPC_Nkha"; "NPC_Nfli";
    "NPC_Nemy"; "NPC_Nemy_Large"; "NPC_Nemy_Small";
    "Queen_Gwendholyn"; "Emperor_Selentius_XVII"; "Imperial_Guard";
    "Princess_Serephine"; "Q0I2b_Guard"; "Q0I2c_Emperor";
    "Q0I3a_Emperor"; "Q0I4a_Princess"; "Q0I4c_Princess";
    "Q0I4d_Princess"; "Q0I4e_Emperor"; "Q0I5a_Emperor";
    "Q3Q5_Dhk"; "Q3Q5_Nkha"; "Q3Q5_Nwin"; "Q3Q5_Nfli";
    "Q3Q5_Neli"; "Q3Q5_Nkha"; "Q3Q5_Nwin"; "Q3Q5_Nfli"; "Q3Q5_Neli";
    "Q3S0_Nser"; "Q3S0_Nwin"; "Q3S0_Nkha"; "Q3S0_Nfli"; "Q3S0_Neli";
    "Q3W0_Nser"; "Q3S0_Nser"; "Q3S0_Nser"; "Q3S0_Nser"; "Q3S0_Nser";
    "Q3Q5_Dhk"; "Q3Q5_Nkha"; "Q3Q5_Nwin"; "Q3Q5_Nfli"; "Q3Q5_Neli";
    "Q3S0_Nser"; "Q3S0_Nwin"; "Q3S0_Nkha"; "Q3S0_Nfli"; "Q3S0_Neli";
    "Q0I2a_Queen"; "Q0I2b_Guard"; "Q0I2c_Emperor"; "Q0I3a_Emperor";
    "Q0I4a_Princess"; "Q0I4b_Princess"; "Q0I4c_Princess"; "Q0I4d_Princess";
    "Q0I4e_Emperor"; "Q0I5a_Emperor"; "Q3Q5_Dhk"; "Q3Q5_Nkha";
    "Q3Q5_Nwin"; "Q3Q5_Nfli"; "Q3Q5_Neli"; "Q3S0_Nser"; "Q3S0_Nwin";
    "Q3S0_Nkha"; "Q3S0_Nfli"; "Q3S0_Neli"; "Q3W0_Nser";
  ]

let load_portraits () : (string * Gl.texture option) list =
  List.map (fun name ->
      let path = Filename.concat (asset_dir ()) (Printf.sprintf "Portrait_%s.png" name) in
      let tex =
        if Sys.file_exists path then
          let px, w, h = Assets.load_image path in
          Some (Gl.texture_of_bigarray ~w ~h px)
        else None
      in
      (name, tex))
    portrait_names

type portrait_key = string

let get_portrait (ui : ui) (name : string) : Gl.texture option =
  Option.bind (List.find_opt (fun (n, _) -> n = name) ui.portraits) (fun (_, tex_opt) -> tex_opt)

let portrait_rect : Layout.rect =
  { Layout.x = 50; y = 150; w = 256; h = 384 }

let dialogue_rect : Layout.rect =
  { Layout.x = 330; y = 150; w = 660; h = 300 }

let max_visible_lines = 12
let line_height = 24

let name_x = 100
let name_y = 100

let text_color = Layout.rgb 230 230 230
let name_colour = Layout.rgb 255 215 0
let choice_colour = Layout.rgb 200 200 100
let highlight_colour = Layout.rgb 255 255 100

type choice = {
  text: string;
  target: string;  (* next conversation node ID *)
}

let measure_text (m : Font_layout.metrics) (s : string) : int =
  Font_layout.measure m s

let draw_text
    (gl : Gl.context) (fonts : Pq_gfx.Font.t) (m : Font_layout.metrics)
    (colour : Layout.colour)
    (s : string) (x : int) (y : int) : Gl.run list =
  Pq_gfx.Font.draw gl fonts m ~colour:colour s ~x:x ~y:y

let solid (rs : Gl.run list ref) (gl : Gl.context) (dst : Layout.rect)
    ?(rotate = 0.0) (col : Layout.colour) : unit =
  let first = Gl.push_quad ~rotate gl dst None col in
  rs := !rs @ [ { Gl.first; count = 6; tex = None; colour = col; clip = None; blend = None } ]

let textured (rs : Gl.run list ref) (gl : Gl.context) (dst : Layout.rect)
    (tex : Gl.texture) (col : Layout.colour) : unit =
  let uv = { Layout.x = 0; y = 0; w = 256; h = 256 } in
  let first = Gl.push_quad ~tex_size:(256, 256) gl dst (Some { Layout.x = 0; y = 0; w = 256; h = 256 }) (Layout.rgb 255 255 255) in
  rs := !rs @ [ { Gl.first; count = 6; tex = Some tex; colour = col; clip = None; blend = None } ]

let draw_portrait (rs : Gl.run list ref) (gl : Gl.context) (portrait : Gl.texture option) : unit =
  match portrait with
  | Some tex -> textured rs gl portrait_rect tex (Layout.rgb 255 255 255)
  | None -> solid rs gl portrait_rect (Layout.rgb 80 80 80)

let draw_conversation (ui : ui) (rs : Gl.run list ref) (gl : Gl.context) : unit =
  match ui.conversation with
  | None -> ()
| Some conv ->
      let sys = ui.system and f = ui.fonts in
      let measure s = match sys with Some m -> Font_layout.measure m s | None -> 8 * String.length s in
      let text (colour : Layout.colour) s x y =
        match (ui.fonts, ui.system) with
        | Some ff, Some m -> rs := !rs @ Pq_gfx.Font.draw gl ff m ~colour:colour s ~x:x ~y:y
        | _ -> ()
      in
      (* Background panel *)
      solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h } (Layout.rgba 0 0 0 180);
      (* Character portrait *)
      let portrait_name = conv.Conversation.speaker_name in
      let portrait = get_portrait ui conv.Conversation.speaker_name in
      draw_portrait rs gl (get_portrait ui conv.Conversation.speaker_name);
      (* Dialogue background *)
      solid rs gl dialogue_rect (Layout.rgb 20 20 20);
      (* Speaker name *)
      text name_colour conv.Conversation.speaker_name name_x name_y;
      (* Dialogue text *)
      let visible_lines = Conversation_layout.to_display_list conv in
List.iteri (fun i (speaker, line_text) ->
          if i < max_visible_lines then
            text text_color speaker name_x (name_y + i * line_height);
            text text_color line_text dialogue_rect.Layout.x (dialogue_rect.Layout.y + i * line_height)
      ) (List.take max_visible_lines (List.drop 0 visible_lines));
      (* No choices implemented yet - placeholder *)
      ()

let draw (ui : ui) : unit =
  let gl = ui.gl in
  Gl.begin_frame ui.gl;
  let rs = ref [] in
  (* Background: dimmed map *)
  solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h } (Layout.rgba 0 0 0 180);
  match ui.conversation with
  | Some conv -> draw_conversation ui rs gl
  | None -> ();
  Gl.submit ui.gl !rs;
  Gl.present ui.gl

let handle_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.conversation with
  | None -> ()
  | Some _ ->
      (* TODO: handle choice selection *)
      ()

let step (ui : ui) (dt : float) : unit =
  (* No automatic advancement - player controls pace *)
  ()

let () =
  Random.self_init ();
  let gl = Gl.create ~title:"Puzzle Quest - Conversation" ~width:window_w ~height:window_h in
  let segments = [("placeholder", None)] in
  let missing = List.length (List.filter (fun (_, t) -> t = None) segments) in
  if missing > 0 then
    Printf.printf "  %d of %d portrait textures missing from %s - run tools/extract_gfx_assets.py\n"
      missing (List.length portrait_names) (asset_dir ());
  let fonts =
    Pq_gfx.Font.create ~styles:
      (List.filter_map Font_layout.metrics_of_tag [ "font_system"; "font_small" ])
  in
  (match fonts with
  | None ->
      Printf.printf "  no font atlases in %s - run tools/extract_gfx_assets.py (no labels)\n" (Pq_gfx.Font.face_dir ())
  | Some _ -> ());
  let conversation = Conversation.find (Conversation.load_all ()) "Q0I2a" in
  let ui =
    { gl; portraits = load_portraits (); fonts; system = Font_layout.metrics_of_tag "font_system";
      small = Font_layout.metrics_of_tag "font_small";
      conversation = conversation; current_line = 0; scroll = 0; choices = None; selected_choice = None }
  in
  Printf.printf "renderer: %s\n  GL: %s\n  conversation: %s\n"
    (Gl.renderer_name ()) (Gl.gl_version ()) (match conversation with Some c -> c.Conversation.id | None -> "none");
  flush stdout;
  let ev = Sdl.Event.create () in
  let last = ref (Sdl.get_ticks ()) in
  let running = ref true in
  while !running do
    while Sdl.poll_event (Some ev) && !running do
      let t = E.get ev E.typ in
      if t = E.quit then exit 0
      else if t = E.mouse_button_down then
        handle_click ui (E.get ev E.mouse_button_x) (E.get ev E.mouse_button_y)
    done;
    let now = Sdl.get_ticks () in
    let dt = float_of_int (Int32.to_int (Int32.sub now !last)) /. 1000.0 in
    last := now;
    step ui (min dt 0.1);
    draw ui;
    Sdl.delay 16l
  done;
  Gl.destroy gl;
  print_endline "conversation closed"