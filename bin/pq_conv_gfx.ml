(** The conversation window: portraits, dialogue lines, and the scriptcall
    battles a conversation can trigger.

    The engine triggers conversations via [Lua_QUEST_CONVERSATION]; the
    generated [Campaign_conversations] actions carry the flow, and a
    [scriptcall] action names a quest callback ([scriptcall_object] is the
    quest id, [scriptcall_function] the callback). This front end walks the
    actions on click and hands each scriptcall to [Campaign.execute_callback]:
    the callback's extracted body effects apply first (quest-state writes,
    grants, nested conversations), then a battle-table callback runs a
    headless fight and the player settles it (stage, capture record,
    spoils); an outcome banner shows the battle until clicked, and
    conversations the body queued print as prompts. A [ShowMessage] effect
    (the extracted message boxes - arrival, execute, the lone OnEnd) shows
    as a modal popup over whatever is on screen: title, wrapped text, and
    an OK click that fires the box's callback through [execute_callback],
    exactly like the game's message window.

    Missing art falls back to flat colours, so a fresh checkout still runs.
    Run [tools/extract_text_tables.py] first to populate the conversation
    texts; backdrops and portraits resolve from [game/Assets] (override
    with [PQ_GAME_ASSETS]).

    Usage: [pq_conv_gfx [CONV_ID]] or [pq_conv_gfx --conv CONV_ID], default
    [Conv_Q0I2a] (the Conv_ prefix may be omitted); [Conv_Q1Q6b] fires a
    NOCAPTURE callback battle, for example. [--shot [FILE]] draws one frame,
    writes it as a P6 ppm (default conv_shot.ppm), and exits - the same
    photograph path pq_map_gfx uses. *)

open Puzzle_quest_lib
open Pq_gfx
open Tsdl
open Campaign
module E = Tsdl.Sdl.Event

let window_w = Layout.game_screen_w
let window_h = Layout.game_screen_h

let asset_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p && Sys.is_directory p -> p
  | _ -> "assets/gfx"

type image = Gl.texture * int * int  (* texture plus its pixel size *)

type ui = {
  gl : Gl.context;
  images : (string * image) list;
  fonts : Pq_gfx.Font.t option;
  system : Font_layout.metrics option;
  mutable conversation : Campaign_conversations.conversation option;
  mutable action_index : int;
  mutable player : Campaign.player;
  mutable battle : (Campaign.player * Battle.battle) option;  (* settled callback fight *)
  mutable message : Campaign.pending_message option;  (* modal box, top of the stack *)
}

(* Conversation images are referenced by the conversation XML as paths rooted
   at the game assets folder (Assets\Portraits\Portrait_NPC_X.png), while the
   shipped backdrops are JPEGs under names the data still calls .png. Each
   reference is resolved against PQ_GAME_ASSETS (default game/Assets), then
   the flat extracted dir, trying both extensions; anything missing falls
   back to flat colours. *)
let game_root () =
  match Sys.getenv_opt "PQ_GAME_ASSETS" with
  | Some p when Sys.file_exists p && Sys.is_directory p -> p
  | _ -> "game/Assets"

let image_roots () =
  List.filter (fun d -> Sys.file_exists d && Sys.is_directory d)
    [ game_root (); asset_dir () ]

let forward_slashes (p : string) : string =
  String.init (String.length p) (fun i -> if p.[i] = '\\' then '/' else p.[i])

let swap_ext (p : string) : string =
  if Filename.check_suffix p ".png" then Filename.chop_suffix p ".png" ^ ".jpg"
  else if Filename.check_suffix p ".jpg" then Filename.chop_suffix p ".jpg" ^ ".png"
  else p

let candidate_paths (p : string) : string list =
  let p = forward_slashes p in
  let bases = [ p; swap_ext p ] in
  let flat = List.map Filename.basename bases in
  List.concat_map
    (fun root ->
      List.concat_map (fun b -> [ Filename.concat root b ]) bases
      @ List.concat_map (fun b -> [ Filename.concat root b ]) flat)
    (image_roots ())

let load_conv_image (p : string) : image option =
  if p = "" then None
  else
    (* The annotation matters: [open Campaign] brings [quest_effect]'s [None]
       into scope, and an un-annotated first branch would pick it up. *)
    let rec try_path (cands : string list) : image option =
      match cands with
      | [] -> None
      | c :: rest ->
          if Sys.file_exists c then
            (try
               let px, w, h = Assets.load_image c in
               Some (Gl.texture_of_bigarray ~w ~h px, w, h)
             with _ -> try_path rest)
          else try_path rest
    in
    try_path (candidate_paths p)

(* Every image the conversations name: one backdrop per conversation and one
   portrait per character entry, deduplicated by reference. *)
let conv_image_paths () : string list =
  let add acc p = if p = "" || List.mem p acc then acc else p :: acc in
  List.fold_left
    (fun acc (c : Campaign_conversations.conversation) ->
      let acc = add acc c.Campaign_conversations.backdrop in
      List.fold_left
        (fun acc (ch : Campaign_conversations.conv_character) ->
          add acc ch.Campaign_conversations.portrait)
        acc c.Campaign_conversations.characters)
    [] Campaign_conversations.conversations

let get_image (ui : ui) (path : string) : image option =
  List.assoc_opt path ui.images

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

let solid (rs : Gl.run list ref) (gl : Gl.context) (dst : Layout.rect)
    ?(rotate = 0.0) (col : Layout.colour) : unit =
  let first = Gl.push_quad ~rotate gl dst None col in
  rs := !rs @ [ { Gl.first; count = 6; tex = None; colour = col; clip = None; blend = None } ]

let textured (rs : Gl.run list ref) (gl : Gl.context) (dst : Layout.rect)
    ((tex, iw, ih) : image) (col : Layout.colour) : unit =
  let first =
    Gl.push_quad ~tex_size:(iw, ih) gl dst
      (Some { Layout.x = 0; y = 0; w = iw; h = ih })
      (Layout.rgb 255 255 255)
  in
  rs := !rs @ [ { Gl.first; count = 6; tex = Some tex; colour = col; clip = None; blend = None } ]

(* Portrait art keeps its aspect inside the frame; a missing or unnamed
   portrait is the flat grey box. *)
let fit_rect (dst : Layout.rect) (iw : int) (ih : int) : Layout.rect =
  let s = min (float_of_int dst.Layout.w /. float_of_int iw)
      (float_of_int dst.Layout.h /. float_of_int ih) in
  let w = int_of_float (float_of_int iw *. s) in
  let h = int_of_float (float_of_int ih *. s) in
  { Layout.x = dst.Layout.x + ((dst.Layout.w - w) / 2);
    y = dst.Layout.y + ((dst.Layout.h - h) / 2);
    w; h }

let draw_portrait (ui : ui) (rs : Gl.run list ref) (gl : Gl.context)
    (path : string) : unit =
  match get_image ui path with
  | Some img ->
      let _, iw, ih = img in
      textured rs gl (fit_rect portrait_rect iw ih) img (Layout.rgb 255 255 255)
  | None -> solid rs gl portrait_rect (Layout.rgb 80 80 80)

let text_of (ui : ui) (rs : Gl.run list ref) (gl : Gl.context)
    (colour : Layout.colour) (s : string) (x : int) (y : int) : unit =
  match (ui.fonts, ui.system) with
  | Some ff, Some m -> rs := !rs @ Font.draw gl ff m ~colour:colour s ~x:x ~y:y
  | _ -> ()

let measure_of (ui : ui) : string -> int =
  match ui.system with
  | Some m -> Font_layout.measure m
  | None -> fun s -> 8 * String.length s

(* Greedy word wrap: [Text_data] lines arrive unwrapped and the dialogue
   rect is fixed (660px), so long lines would run off the panel otherwise. *)
let wrap_lines (measure : string -> int) (max_w : int) (s : string) : string list =
  let words = String.split_on_char ' ' s in
  let rec go line acc = function
    | [] -> List.rev (if line = "" then acc else line :: acc)
    | w :: rest ->
      let candidate = if line = "" then w else line ^ " " ^ w in
      if measure candidate <= max_w then go candidate acc rest
      else go w (line :: acc) rest
  in
  match words with
  | [] -> [ "" ]
  | _ -> go "" [] words

let current_action (ui : ui) (conv : Campaign_conversations.conversation) =
  let actions = conv.Campaign_conversations.actions in
  if ui.action_index >= 0 && ui.action_index < List.length actions then
    Some (List.nth actions ui.action_index)
  else None

let draw_conversation (ui : ui) (rs : Gl.run list ref) (gl : Gl.context) : unit =
  match ui.conversation with
  | None -> ()
  | Some conv ->
      (* Backdrop fills the window; the dim keeps the text readable. *)
      (match get_image ui conv.Campaign_conversations.backdrop with
       | Some img ->
           textured rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
             img (Layout.rgb 255 255 255)
       | None -> ());
      solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
        (Layout.rgba 0 0 0 180);
      (* The current action names its character; wait/end/scriptcall actions
         fall back to whoever the conversation opens on. *)
      let chars = conv.Campaign_conversations.characters in
      let speaker =
        let by_action =
          match current_action ui conv with
          | Some action when action.Campaign_conversations.character >= 0 ->
              List.nth_opt chars action.Campaign_conversations.character
          | _ -> None
        in
        match by_action with Some c -> Some c | None -> List.nth_opt chars 0
      in
      (match speaker with
       | Some c ->
           draw_portrait ui rs gl c.Campaign_conversations.portrait;
           text_of ui rs gl name_colour
             (Text_data.text c.Campaign_conversations.name) name_x name_y
       | None -> draw_portrait ui rs gl "");
      solid rs gl dialogue_rect (Layout.rgb 20 20 20);
      (* Current line inside the dialogue rect, wrapped. *)
      (match current_action ui conv with
       | Some action ->
         let content =
           if action.Campaign_conversations.text = "" then "..."
           else Text_data.text action.Campaign_conversations.text
         in
         let wrapped =
           List.take max_visible_lines
             (wrap_lines (measure_of ui) (dialogue_rect.Layout.w - 16) content)
         in
         List.iteri (fun i line ->
             text_of ui rs gl text_color line
               (dialogue_rect.Layout.x + 8)
               (dialogue_rect.Layout.y + 8 + (i * line_height)))
           wrapped
       | None ->
         text_of ui rs gl text_color "Conversation ended."
           (dialogue_rect.Layout.x + 8) (dialogue_rect.Layout.y + 8));
      (* The skip button the hit test knows. *)
      solid rs gl Conversation_layout.skip_btn (Layout.rgb 60 60 90);
      text_of ui rs gl text_color "Skip"
        (Conversation_layout.skip_btn.Layout.x + 34)
        (Conversation_layout.skip_btn.Layout.y + 8)

(* Outcome of a callback battle, on top of the conversation until clicked. *)
let draw_battle_banner (ui : ui) (rs : Gl.run list ref) (gl : Gl.context) : unit =
  match ui.battle with
  | None -> ()
  | Some (p, b) ->
    let won = b.Battle.enemy.is_dead && not b.Battle.hero.is_dead in
    let measure = measure_of ui in
    let box = { Layout.x = 262; y = 284; w = 500; h = 200 } in
    solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h } (Layout.rgba 0 0 0 200);
    solid rs gl box (Layout.rgb 30 30 40);
    let centred s =
      box.Layout.x + ((box.Layout.w - measure s) / 2)
    in
    let title = if won then "Victory!" else "Defeat" in
    text_of ui rs gl
      (if won then name_colour else Layout.rgb 200 200 200)
      title (centred title) (box.Layout.y + 24);
    let monster = Text_data.text b.Battle.enemy.name in
    text_of ui rs gl text_color monster (centred monster) (box.Layout.y + 64);
    let line2 =
      Printf.sprintf "%d turns - life %d" b.Battle.turns_elapsed p.Campaign.life
    in
    text_of ui rs gl text_color line2 (centred line2) (box.Layout.y + 100);
    let line3 =
      if won then Printf.sprintf "+%d gold - +%d xp" b.Battle.gold b.Battle.xp
      else "no spoils"
    in
    text_of ui rs gl text_color line3 (centred line3) (box.Layout.y + 132);
    let hint = "click to continue" in
    text_of ui rs gl (Layout.rgb 240 210 90) hint (centred hint) (box.Layout.y + 164)

(* A queued message box, modal over the conversation (or the empty screen):
   dim, panel, title, wrapped body, OK hint. Dismissed by any click, which
   fires its callback if it carries one. *)
let draw_message (ui : ui) (rs : Gl.run list ref) (gl : Gl.context) : unit =
  match ui.message with
  | None -> ()
  | Some (m : Campaign.pending_message) ->
    let measure = measure_of ui in
    let box = { Layout.x = 200; y = 240; w = 600; h = 280 } in
    solid rs gl { Layout.x = 0; y = 0; w = window_w; h = window_h }
      (Layout.rgba 0 0 0 200);
    solid rs gl box (Layout.rgb 30 30 40);
    let title = Text_data.text m.Campaign.pmsg_title in
    text_of ui rs gl name_colour title
      (box.Layout.x + 16) (box.Layout.y + 16);
    let body = Text_data.text m.Campaign.pmsg_text in
    List.iteri (fun i line ->
        text_of ui rs gl text_color line
          (box.Layout.x + 16)
          (box.Layout.y + 56 + (i * line_height)))
      (List.take 8 (wrap_lines measure (box.Layout.w - 32) body));
    let ok = "OK - click to continue" in
    text_of ui rs gl (Layout.rgb 240 210 90) ok
      (box.Layout.x + ((box.Layout.w - measure ok) / 2))
      (box.Layout.y + box.Layout.h - 32)

let draw ?(present = true) (ui : ui) : unit =
  let gl = ui.gl in
  Gl.begin_frame ui.gl;
  let rs = ref [] in
  (match ui.conversation with
   | Some _ -> draw_conversation ui rs gl
   | None -> ());
  draw_message ui rs gl;
  draw_battle_banner ui rs gl;
  Gl.submit ui.gl !rs;
  if present then Gl.present ui.gl

(* Conversations the firing callback queued (nested QUEST_CONVERSATION)
   print as prompts; the overlay would open them next. *)
let drain_queued () : unit =
  let rec go () =
    match take_pending_conversation () with
    | None -> ()
    | Some conv_id ->
      Printf.printf "  queued conversation: %s\n" conv_id;
      go ()
  in
  go ()

(* Dismiss the modal box: its callback applies through execute_callback -
   body effects first, then its battle if the table has one - and any
   conversation the body queued comes up next. *)
let dismiss_message (ui : ui) (m : Campaign.pending_message) : unit =
  ui.message <- None;
  Printf.printf "  message ok: [%s] %s\n"
    m.Campaign.pmsg_title m.Campaign.pmsg_text;
  flush stdout;
  if m.Campaign.pmsg_callback <> "" then begin
    Printf.printf "  firing %s on %s\n"
      m.Campaign.pmsg_callback m.Campaign.pmsg_quest;
    flush stdout;
    (match execute_callback ~rng:Random.int ui.player m.Campaign.pmsg_quest
             m.Campaign.pmsg_callback with
     | Some res ->
       ui.player <- res.cb_player;
       (match res.cb_battle with
        | Some b -> ui.battle <- Some (res.cb_player, b)
        | None -> ());
       drain_queued ()
     | None -> drain_queued ())
  end

let handle_click (ui : ui) (mx : int) (my : int) : unit =
  match ui.battle with
  | Some _ -> ui.battle <- None
  | None ->
    (match ui.message with
     | Some m -> dismiss_message ui m
     | None ->
    (match ui.conversation with
     | None -> ()
     | Some conv ->
       (match Conversation_layout.hit mx my with
        | `Skip -> ui.conversation <- None
        (* No conversation ships choice nodes (actions are talk/wait/end/
           scriptcall), so the choice band just advances like the rest. *)
        | `Choice _ | `Portrait | `Dialogue | `Miss ->
          match current_action ui conv with
          | None -> ui.conversation <- None
          | Some action ->
            if action.Campaign_conversations.type_ = "scriptcall" then
              ()  (* step fires it *)
            else begin
              ui.action_index <- ui.action_index + 1;
              if ui.action_index >= List.length conv.Campaign_conversations.actions then
                ui.conversation <- None
            end)))

(* Run the current action when it is a scriptcall: the quest callback fires
   once (body effects, then its battle if it has one), the conversation
   moves on, and any battle outcome banner waits for a click. *)
let step (ui : ui) (_dt : float) : unit =
  match ui.battle with
  | Some _ -> ()
  | None ->
    (match ui.message with
     | Some _ -> ()  (* modal until the click dismisses it *)
     | None ->
    (match take_pending_message () with
     | Some m ->
       ui.message <- Some m;
       Printf.printf "  message: [%s] %s\n" m.Campaign.pmsg_title
         m.Campaign.pmsg_text;
       flush stdout
     | None ->
    (match ui.conversation with
     | None -> ()
     | Some conv ->
       (match current_action ui conv with
        | Some action when action.Campaign_conversations.type_ = "scriptcall" ->
          ui.action_index <- ui.action_index + 1;
          (match (action.Campaign_conversations.scriptcall_object,
                  action.Campaign_conversations.scriptcall_function) with
           | Some obj, Some fn ->
             (match execute_callback ~rng:Random.int ui.player obj fn with
              | Some res ->
                ui.player <- res.cb_player;
                (match res.cb_battle with
                 | Some battle ->
                   let won =
                     battle.Battle.enemy.is_dead
                     && not battle.Battle.hero.is_dead
                   in
                   ui.battle <- Some (res.cb_player, battle);
                   Printf.printf "  %s: %s in %d turns (life %d, +%d gold, +%d xp) [%s/%s]\n"
                     (Text_data.text battle.Battle.enemy.name)
                     (if won then "won" else "lost")
                     battle.Battle.turns_elapsed res.cb_player.Campaign.life
                     (if won then battle.Battle.gold else 0)
                     (if won then battle.Battle.xp else 0)
                     obj fn;
                   flush stdout
                 | None -> ());
                drain_queued ()
              | None -> drain_queued ())
           | _ -> ())
        | _ -> ()))))

let () =
  Random.self_init ();
  let gl = Gl.create ~title:"Puzzle Quest - Conversation" ~width:window_w ~height:window_h in
  let image_paths = conv_image_paths () in
  let images =
    List.filter_map
      (fun p -> Option.map (fun im -> (p, im)) (load_conv_image p))
      image_paths
  in
  let missing = List.length image_paths - List.length images in
  if missing > 0 then
    Printf.printf
      "  %d of %d conversation images missing from %s (backdrops/portraits; set PQ_GAME_ASSETS)\n"
      missing (List.length image_paths) (game_root ());
  let fonts =
    Pq_gfx.Font.create ~styles:
      (List.filter_map Font_layout.metrics_of_tag [ "font_system"; "font_small" ])
  in
  (match fonts with
  | None ->
      Printf.printf "  no font atlases in %s - run tools/extract_gfx_assets.py (no labels)\n" (Pq_gfx.Font.face_dir ())
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
  let conversation =
    let find id =
      try Some (Campaign_conversations.conversation_by_id id)
      with Not_found -> None
    in
    match find !conv_id with
    | Some c -> Some c
    | None ->
        (match find ("Conv_" ^ !conv_id) with
         | Some c -> Some c
         | None ->
             Printf.printf "  no conversation %s - using Conv_Q0I2a\n" !conv_id;
             find "Conv_Q0I2a")
  in
  let ui =
    { gl; images; fonts; system = Font_layout.metrics_of_tag "font_system";
      conversation; action_index = 0;
      player = Campaign.create_player "TestHero" "PWAR" 0 0;
      battle = None; message = None }
  in
  Printf.printf "renderer: %s\n  GL: %s\n  conversation: %s\n"
    (Gl.renderer_name ()) (Gl.gl_version ())
    (match conversation with Some c -> c.Campaign_conversations.id | None -> "none");
  flush stdout;
  (* --shot is how this front is checked without a display: one frame, the
     same raw RGBA path pq_map_gfx photographs its panel with. *)
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
