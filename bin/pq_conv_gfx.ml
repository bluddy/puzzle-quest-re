(** The conversation window front: portraits, dialogue lines, and the
    scriptcall battles a conversation can trigger - the whole window lives
    in [Pq_gfx.Conv_window], shared with the world map.

    Usage: [pq_conv_gfx [CONV_ID]] or [pq_conv_gfx --conv CONV_ID], default
    [Conv_Q0I2a] (the Conv_ prefix may be omitted); [Conv_Q1Q6b] fires a
    NOCAPTURE callback battle, for example. [--shot [FILE]] draws one frame,
    writes it as a P6 ppm (default conv_shot.ppm), and exits - the same
    photograph path pq_map_gfx uses. *)

open Puzzle_quest_lib
open Pq_gfx
open Tsdl
module E = Tsdl.Sdl.Event

let () =
  Random.self_init ();
  let window_w = Conv_window.window_w and window_h = Conv_window.window_h in
  let gl = Gl.create ~title:"Puzzle Quest - Conversation" ~width:window_w ~height:window_h in
  let fonts =
    Font.create ~styles:
      (List.filter_map Font_layout.metrics_of_tag [ "font_system"; "font_small" ])
  in
  (match fonts with
  | None ->
      Printf.printf "  no font atlases in %s - run tools/extract_gfx_assets.py (no labels)\n" (Font.face_dir ())
  | Some _ -> ());
  let conv_id = ref "Conv_Q0I2a" and shot = ref "" in
  let rec parse_args = function
    | [] -> ()
    | "--conv" :: id :: rest -> conv_id := id; parse_args rest
    | "--shot" :: rest ->
        (match rest with
         | f :: _ when String.length f > 0 && f.[0] <> '-' ->
             shot := f; parse_args (List.tl rest)
         | _ -> shot := "conv_shot.ppm"; parse_args rest)
    | a :: rest ->
        if String.length a > 0 && a.[0] <> '-' then conv_id := a;
        parse_args rest
  in
  parse_args (List.tl (Array.to_list Sys.argv));
  let ui =
    Conv_window.create ~gl ~fonts
      ~system:(Font_layout.metrics_of_tag "font_system")
      ~player:(Campaign.create_player "TestHero" "PWAR" 0 0)
  in
  Conv_window.open_conv ui !conv_id;
  Printf.printf "renderer: %s\n  GL: %s\n  conversation: %s\n"
    (Gl.renderer_name ()) (Gl.gl_version ())
    (match ui.Conv_window.conversation with
     | Some c -> c.Campaign_conversations.id
     | None -> "none");
  flush stdout;
  (* --shot is how this front is checked without a display: one frame, the
     same raw RGBA path pq_map_gfx photographs its panel with. *)
  if !shot <> "" then begin
    Conv_window.draw ~present:false ui;
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
    Gl.destroy gl;
    exit 0
  end;
  let ev = Sdl.Event.create () in
  let last = ref (Sdl.get_ticks ()) in
  let running = ref true in
  while !running do
    while Sdl.poll_event (Some ev) && !running do
      let t = E.get ev E.typ in
      if t = E.quit then exit 0
      else if t = E.mouse_button_down then
        Conv_window.handle_click ui (E.get ev E.mouse_button_x) (E.get ev E.mouse_button_y)
    done;
    let now = Sdl.get_ticks () in
    let dt = float_of_int (Int32.to_int (Int32.sub now !last)) /. 1000.0 in
    last := now;
    Conv_window.step ui (min dt 0.1);
    Conv_window.draw ui;
    Sdl.delay 16l
  done;
  Gl.destroy gl;
  print_endline "conversation closed"
