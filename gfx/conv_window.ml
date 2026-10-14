(** The conversation window, shared by the conversation front and the world
    map: portraits, dialogue lines, the scriptcall battles a conversation
    can trigger, and the message boxes the quest engine queues.

    The engine queues conversation ids ([Campaign.pending_conversations]:
    OnBegin intros, guarded arrivals, nested callback trees) and message
    boxes ([Campaign.pending_messages]: arrival boxes, execute messages, the
    lone OnEnd). This window pops them in the game's own order - a battle
    banner holds everything until clicked, then the modal message box, then
    the current conversation's actions. Walking an action hands each
    [scriptcall] to [Campaign.callback_open]: the callback's extracted body
    effects apply first (quest-state writes, grants, nested conversations),
    then a battle-table callback's fight runs through the host's runner -
    [Battle.run] headless by default, or the world map's battle screen when
    it installs its hooks - and the outcome banner waits for a click. A
    [ShowMessage] box draws title, wrapped text and an OK hint; dismissing it
    fires the box's callback the same way.

    Missing art falls back to flat colours, so a fresh checkout still runs.
    Textures resolve from [game/Assets] (override with [PQ_GAME_ASSETS]),
    then the flat extracted dir; fonts come from the caller. *)

open Puzzle_quest_lib
open Campaign

let window_w = Layout.game_screen_w
let window_h = Layout.game_screen_h

let asset_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p && Sys.is_directory p -> p
  | _ -> "assets/gfx"

type image = Gl.texture * int * int  (* texture plus its pixel size *)

type state = {
  gl : Gl.context;
  images : (string * image) list;
  fonts : Font.t option;
  system : Font_layout.metrics option;
  mutable conversation : Campaign_conversations.conversation option;
  mutable action_index : int;
  mutable player : Campaign.player;
  mutable battle : (Campaign.player * Battle.battle) option;
  mutable message : Campaign.pending_message option;
  mutable capture_offer : string option;
      (** A won callback fight's [cb_capture_offer], waiting for its banner to
          be dismissed; the map front takes it through
          [take_capture_offer] and opens the minigame (port.capture_surfaces).
          The conversation front has no capture window and leaves it. *)
  human : Battle.player option;
      (** The playable front's mouse-backed choices, when a host installs
          them: a callback fight then builds with these in its rules and the
          player plays it rather than watching the auto-AI. *)
  run_battle : Battle.battle -> Battle.battle;
      (** How a fight is run once opened. The default is [Battle.run], the
          headless loop; the world map passes its battle screen's [run] so the
          fight is played on the window rather than behind a banner. *)
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

let get_image (ui : state) (path : string) : image option =
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

let draw_portrait (ui : state) (rs : Gl.run list ref) (gl : Gl.context)
    (path : string) : unit =
  match get_image ui path with
  | Some img ->
      let _, iw, ih = img in
      textured rs gl (fit_rect portrait_rect iw ih) img (Layout.rgb 255 255 255)
  | None -> solid rs gl portrait_rect (Layout.rgb 80 80 80)

let text_of (ui : state) (rs : Gl.run list ref) (gl : Gl.context)
    (colour : Layout.colour) (s : string) (x : int) (y : int) : unit =
  match (ui.fonts, ui.system) with
  | Some ff, Some m -> rs := !rs @ Font.draw gl ff m ~colour:colour s ~x:x ~y:y
  | _ -> ()

let measure_of (ui : state) : string -> int =
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

let current_action (ui : state) (conv : Campaign_conversations.conversation) =
  let actions = conv.Campaign_conversations.actions in
  if ui.action_index >= 0 && ui.action_index < List.length actions then
    Some (List.nth actions ui.action_index)
  else None

let draw_conversation (ui : state) (rs : Gl.run list ref) (gl : Gl.context) : unit =
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
let draw_battle_banner (ui : state) (rs : Gl.run list ref) (gl : Gl.context) : unit =
  match ui.battle with
  | None -> ()
  | Some (p, b) ->
    let won = Battle.hero_won b in
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
let draw_message (ui : state) (rs : Gl.run list ref) (gl : Gl.context) : unit =
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

(* Open a conversation by id: the bare id first, then with the Conv_ prefix
   the data uses - the same fallback the conversation front's argument
   parser has. Unknown ids print and leave the window empty. *)
let open_conv (ui : state) (conv_id : string) : unit =
  let find id =
    try Some (Campaign_conversations.conversation_by_id id)
    with Not_found -> None
  in
  match find conv_id with
  | Some c ->
      ui.conversation <- Some c;
      ui.action_index <- 0;
      Printf.printf "  conversation: %s\n" c.Campaign_conversations.id;
      flush stdout
  | None -> (
      match find ("Conv_" ^ conv_id) with
      | Some c ->
          ui.conversation <- Some c;
          ui.action_index <- 0;
          Printf.printf "  conversation: %s\n" c.Campaign_conversations.id;
          flush stdout
      | None ->
          Printf.printf "  no conversation %s\n" conv_id;
          flush stdout)

(* True while something still holds the window: a banner, a box, or a tree
   mid-actions. The driver finishes an action's outcome when this falls. *)
let busy (ui : state) : bool =
  ui.battle <> None || ui.message <> None || ui.conversation <> None

(* The capture a dismissed battle banner left waiting, taken once. The map
   front calls this right after handing a click to this window: a banner
   click is what frees the offer. *)
let take_capture_offer (ui : state) : string option =
  let o = ui.capture_offer in
  ui.capture_offer <- None;
  o

let player_of (ui : state) : Campaign.player = ui.player

let sync_player (ui : state) (p : Campaign.player) : unit = ui.player <- p

(* Dismiss the modal box: its callback applies through [callback_open] - body
   effects first, then its battle if the table has one, run through the host's
   runner - and any conversation the body queued comes up next through [step]. *)
let dismiss_message (ui : state) (m : Campaign.pending_message) : unit =
  ui.message <- None;
  Printf.printf "  message ok: [%s] %s\n"
    m.Campaign.pmsg_title m.Campaign.pmsg_text;
  flush stdout;
  if m.Campaign.pmsg_callback <> "" then begin
    Printf.printf "  firing %s on %s\n"
      m.Campaign.pmsg_callback m.Campaign.pmsg_quest;
    flush stdout;
    (match
       callback_open ~rng:Random.int ?human:ui.human ui.player
         m.Campaign.pmsg_quest m.Campaign.pmsg_callback
     with
     | None -> ()
     | Some cf ->
       ui.player <- cf.cf_player;
       (match cf.cf_battle with
        | None -> ()
        | Some b ->
          let finished = ui.run_battle b in
          let p, offer = cf.cf_settle finished in
          ui.player <- p;
          ui.battle <- Some (p, finished);
          ui.capture_offer <- offer))
  end

let handle_click (ui : state) (mx : int) (my : int) : unit =
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

(* Run the current action when it is a scriptcall: the quest callback opens
   once (body effects, then its battle if the host's runner plays it), the
   conversation moves on, and any battle outcome banner waits for a click. *)
let step_scriptcall (ui : state) (conv : Campaign_conversations.conversation) : unit =
  match current_action ui conv with
  | Some action when action.Campaign_conversations.type_ = "scriptcall" ->
    ui.action_index <- ui.action_index + 1;
    (match (action.Campaign_conversations.scriptcall_object,
            action.Campaign_conversations.scriptcall_function) with
     | Some obj, Some fn ->
       (match
          callback_open ~rng:Random.int ?human:ui.human ui.player obj fn
        with
        | None -> ()
        | Some cf ->
          ui.player <- cf.cf_player;
          (match cf.cf_battle with
           | None -> ()
           | Some b ->
             let finished = ui.run_battle b in
             let won = Battle.hero_won finished in
             let p, offer = cf.cf_settle finished in
             ui.player <- p;
             ui.battle <- Some (p, finished);
             ui.capture_offer <- offer;
             Printf.printf "  %s: %s in %d turns (life %d, +%d gold, +%d xp) [%s/%s]\n"
               (Text_data.text finished.Battle.enemy.name)
               (if won then "won" else "lost")
               finished.Battle.turns_elapsed p.Campaign.life
               (if won then finished.Battle.gold else 0)
               (if won then finished.Battle.xp else 0)
               obj fn;
             flush stdout))
     | _ -> ())
  | _ -> ()

let step (ui : state) (_dt : float) : unit =
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
     | Some conv -> step_scriptcall ui conv
     | None -> (
         (* Idle: the next queued tree opens - intros, arrivals, nested
            callback trees, whatever the driver or a body just queued. *)
         match take_pending_conversation () with
         | Some conv_id -> open_conv ui conv_id
         | None -> ()))))

let draw ?(present = true) (ui : state) : unit =
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

(* Create the window's state: fonts are the caller's (the map already owns
   a system atlas), and the conversation art preloads once - the same cost
   the conversation front pays. [?human] and [?run_battle] are the playable
   host's seam: with them a callback fight builds with the mouse-backed
   choices in its rules and runs through the battle screen instead of the
   headless loop. *)
let create ~(gl : Gl.context) ~(fonts : Font.t option)
    ~(system : Font_layout.metrics option) ~(player : Campaign.player)
    ?human ?(run_battle = Battle.run) () : state =
  let images =
    List.filter_map
      (fun p -> Option.map (fun im -> (p, im)) (load_conv_image p))
      (conv_image_paths ())
  in
  let missing = List.length (conv_image_paths ()) - List.length images in
  if missing > 0 then
    Printf.printf
      "  %d of %d conversation images missing from %s (backdrops/portraits; set PQ_GAME_ASSETS)\n"
      missing (List.length (conv_image_paths ())) (game_root ());
  { gl; images; fonts; system;
    conversation = None; action_index = 0; player;
    battle = None; message = None; capture_offer = None;
    human; run_battle }
