(** An interactive battle in a window: the ASCII runner's counterpart.

    The battle logic is the same [Battle] the headless tools drive, and the human
    still chooses through the same two hooks - this only replaces what was a
    [read_line] with a window and a mouse. Nothing about the recovered rules is
    re-implemented here.

    Text is drawn with the game's own bitmap fonts, loaded out of
    [Assets.zip] by [tools/extract_gfx_assets.py] - see gfx/font.ml. The HUD is
    the one place it appears: the console still prints what a click did, because
    that is useful and free, but everything a player needs in order to choose a
    move is on screen.

    No CRT filter, no scanlines. See the note in tools/graphics_plan.md. *)

open Puzzle_quest_lib
open Pq_gfx
(* Not [open Tsdl.Sdl]: it has a [Gl] submodule for context attributes, which would
   shadow [Pq_gfx.Gl]. Only the event module is needed unqualified. *)
module E = Tsdl.Sdl.Event

(* The window is the game's own screen size, not a preference: the backdrop menu
   in Assets/Screens declares 1024x768, and the border frames in the registry are
   cut to exactly that (top 1024x95, left 19x653, right 21x653, bottom 1024x20).
   At any other size the border is either cropped or stretched. *)
let window_w = Layout.game_screen_w
and window_h = Layout.game_screen_h

(* The board's cells are 71px in the gem sheet, and the sheet is drawn 1:1, so 71
   is the size a gem is {e meant} to be. An 8x8 board of them is 568 square. *)
let cell = 71
let bar_h = 96

(* The decoration frames, by the tags the registry gives them. Naming the tag
   rather than the rectangle is the point: Skin_data has the coordinates, and a
   decoration cut to fit the screen is not something to hardcode. *)
let frame_border_top = "img_border_top"
and frame_border_left = "img_border_left"
and frame_border_right = "img_border_right"
and frame_border_bottom = "img_border_bottom"
and frame_backdrop = Skin.frame_tag_backdrop
and frame_selection = "img_selglow"
and frame_timer_l = "img_ltimebg"
and frame_timer_r = "img_rtimebg"

(* ------------------------------------------------------------------ battle -- *)

(* The shared seeded generator; see lib/rng.ml. *)
let lcg seed =
  let g = Rng.create seed in
  fun n -> Rng.int g n

let skill n =
  { Combat.earth = n; fire = n; air = n; water = n; battle = n; morale = n;
    cunning = n }

let spell_of id = Spell_data.descriptor_of id |> Option.map (fun (d : Spell.descriptor) -> Spell.spell_of_descriptor d ~name:d.id ())

let demo_spells = List.filter_map spell_of [ "SBAC"; "SBAV"; "SBNA"; "SBRA" ]

let fresh_board rng =
  let gems =
    [| Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Water;
       Board.Mana Board.Air |]
  in
  Board.of_array_matrix
    (Array.init Board.default_height (fun _ ->
         Array.init Board.default_width (fun _ -> gems.(rng 4))))

(* ------------------------------------------------------------------- state -- *)

type ui = {
  gl : Gl.context;
  gem_sheet : Gl.texture option;
  mutable b : Battle.battle option;
  (* Fixed: the window is not resizable, so the board geometry never moves. *)
  layout : Layout.t;
  mutable first_cell : (int * int) option;  (** first half of a pending swap *)
  (* None when no font atlas could be loaded, which is a supported state: the
     battle is still playable, it just has no labels. *)
  fonts : Font.t option;
  system : Font_layout.metrics option;  (** font_system - the HUD's body text *)
  small : Font_layout.metrics option;  (** font_small - the tight fits *)
  button : Font_layout.metrics option;  (** font_button - the spell bar *)
  xp : Font_layout.metrics option;  (** font_xp, which is purple *)
  gold : Font_layout.metrics option;  (** font_gold, which is orange *)
  (* The decoration sheets. The backdrop and the border are both on one, and both
     are absent together; [Skin.create] reports what it could not load and every
     draw call then declines. A checkout without the art still plays. *)
  skin : Skin.t;
}

let u : ui option ref = ref None

let ui () = match !u with Some x -> x | None -> failwith "ui not created"

let battle () = match (ui ()).b with Some b -> b | None -> failwith "no battle"
let layout () = (ui ()).layout

(* ------------------------------------------------------------------- input -- *)

let ev = E.create ()
let some_ev = Some ev

(** Draw the current frame. Every piece of state the player can act on is on
    screen: the board, whose cells they may swap, and the spell bar, whose buttons
    they may press. *)
(* The spell bar's geometry, in the form gfx/input.ml interprets. Kept in one
   place so the drawing and the click handling cannot disagree about where the
   buttons are - they used to compute it separately, which is exactly the kind of
   duplication that makes a button that is drawn but not clickable. *)
let bar () : Input.bar =
  let n = List.length demo_spells in
  let bw = 120 and gap = 12 and bar_y = window_h - bar_h in
  let x0 = (window_w - (n * bw + ((n - 1) * gap))) / 2 in
  { Input.count = n; button_w = bw; gap; top_y = bar_y; left_x = x0 }

(** The heads-up display: everything a player needs in order to choose a move,
    which until now existed only in the console.

    Life and mana are drawn as numbers in the game's own fonts rather than as
    bars, because that is what the original's battle screen does - the portrait
    frames carry the bars, and those live in Skin_Battle_Misc.png, which is
    extracted but not yet placed. Mana is labelled per element in the board's own
    order, and the costs under each spell button are the spell's four costs, so an
    unaffordable spell explains {e itself} rather than just being grey.

    Colours come from the named fonts, which is why [font_xp] and [font_gold] are
    worth having: they are the game's own purple and orange, not ones picked here.

    Returns runs to append to the frame's own, so text and geometry share one
    vertex-buffer upload - [Gl.submit] takes a single run list, and a second pass
    would mean re-uploading the buffer for the sake of a few dozen glyphs. *)
let draw_hud (gl : Gl.context) (spells : Spell.spell list) : Gl.run list =
  let u = ui () in
  let b = battle () in
  let lay = layout () in
  let bg = bar () in
  let out = ref [] in
  let put rs = out := !out @ rs in
  (* [fonts] being None is a supported state, not an error: a checkout with no
     atlases extracted still plays, it just has no labels. *)
  let with_font m f =
    match u.fonts with
    | None -> ()
    | Some fonts -> put (f fonts m)
  in
  let centred m s ~cx ~y = with_font m (fun fonts m -> Font.draw_centred gl fonts m s ~cx ~y) in
  let grey = Layout.rgb 130 132 140 and white = Layout.rgb 255 255 255 in
  let hero = b.Battle.hero and foe = b.Battle.enemy in
  (* The HUD lives in the margins the board leaves, not on top of it: the board is
     centred in the window minus the bar, so there is a band above it and one
     below, and putting text there is the difference between a HUD and a
     collision. *)
  (* Clear of the timer plates, which are 90px wide at each end of the top panel. *)
  let pad = 104 in
  (* --- life: hero at the top left, the foe at the top right --- *)
  let life_line (c : Combat.combatant) ~x ~right =
    match u.system with
    | None -> ()
    | Some m ->
        let s = Printf.sprintf "%s %d/%d" c.Combat.name c.Combat.life c.Combat.max_life in
        let x = if right then window_w - 104 - Font_layout.measure m s else x in
        with_font m (fun fonts m -> Font.draw gl fonts m s ~x ~y:pad)
  in
  life_line hero ~x:pad ~right:false;
  life_line foe ~x:0 ~right:true;
  (* --- the hero's mana, one row per element, in the board's element order --- *)
  (match u.small with
  | None -> ()
  | Some m ->
      let row (name : string) (get : Combat.mana -> int) y =
        let s = Printf.sprintf "%s %2d" name (get hero.Combat.mana) in
        with_font m (fun fonts m -> Font.draw gl fonts m s ~x:pad ~y)
      in
      row "E" (fun (x : Combat.mana) -> x.Combat.earth) (pad + 22);
      row "F" (fun (x : Combat.mana) -> x.Combat.fire) (pad + 36);
      row "A" (fun (x : Combat.mana) -> x.Combat.air) (pad + 50);
      row "W" (fun (x : Combat.mana) -> x.Combat.water) (pad + 64));
  (* --- gold and experience, right-aligned under the foe's life, in the game's
         own gold and xp colours --- *)
  let right_number (m : Font_layout.metrics option) (v : int) y =
    match m with
    | None -> ()
    | Some m ->
        let s = Printf.sprintf "%d" v in
        with_font m (fun fonts m ->
            Font.draw gl fonts m s ~x:(window_w - 104 - Font_layout.measure m s) ~y)
  in
  right_number u.gold b.Battle.gold (pad + 22);
  right_number u.xp b.Battle.xp (pad + 40);
  (* --- each spell button labelled with its name and its four costs --- *)
  List.iteri
    (fun i (s : Spell.spell) ->
      let x = bg.Input.left_x + (i * (bg.Input.button_w + bg.Input.gap)) in
      let col = if Spell.can_cast hero s then white else grey in
      let centre text m y =
        with_font m (fun fonts m ->
            let w = Font_layout.measure m text in
            Font.draw gl fonts m ~colour:col text
              ~x:(x + ((bg.Input.button_w - w) / 2))
              ~y)
      in
      (match u.button with Some m -> centre s.Spell.name m (bg.Input.top_y + 26) | None -> ());
      (* Costs in the same element order as the mana readout, so the row under the
         name is read the same way as the column on the left. *)
      match u.small with
      | Some m ->
          centre
            (Printf.sprintf "%d %d %d %d" s.Spell.cost_earth s.Spell.cost_fire
               s.Spell.cost_air s.Spell.cost_water)
            m (bg.Input.top_y + 56)
      | None -> ())
    spells;
  (* A prompt, so the window says what it wants rather than only the console
     doing it. It sits in the band between the board and the bar. *)
  (match u.small with
  | Some m ->
      let prompt =
        match u.first_cell with
        | Some _ -> "click an adjacent gem to swap"
        | None -> "click a gem, then an adjacent one  -  or a button to cast"
      in
      let board = Layout.board_rect lay in
      centred m prompt ~cx:(window_w / 2) ~y:(board.Layout.y + board.Layout.h + 8)
  | None -> ());
  !out

(** The backdrop and the four border pieces.

    Every rectangle is the one the registry records. Note that only the origin is
    passed: [Skin.draw] takes the frame's {e destination} size from the registry
    and ignores the width and height in the placement, because a border is cut to
    a size and a placement that disagreed with the cut would be the bug. So the
    window size and the border size cannot drift apart silently - the backdrop is
    1024x768 and the window is [Layout.game_screen_w].

    Order matters: the backdrop covers the whole screen and the borders are cut
    out of the same sheet, so the border goes on afterwards or the backdrop hides
    it. *)
let draw_decorations (rs : Gl.run list ref) =
  let s = (ui ()).skin in
  let at x y = { Layout.x = x; y; w = 0; h = 0 } in
  ignore (Skin.draw s rs frame_backdrop ~place:(at 0 0));
  ignore (Skin.draw s rs frame_border_top ~place:(at 0 0));
  ignore (Skin.draw s rs frame_border_left ~place:(at 0 0));
  ignore (Skin.draw s rs frame_border_right ~place:(at window_w 0));
  ignore (Skin.draw s rs frame_border_bottom ~place:(at 0 window_h))

(** The turn counters: the two 90x90 plates the registry puts either side of the
    board, in the top panel.

    The plate art is placed by the registry and only its position is ours: they go
    at the outer ends of the top panel, clear of the HUD in the middle and clear of
    the board below. The hourglass ([img_timer_0]) is {e not} drawn - it belongs to
    the timed minigames, and there is nothing on a battle screen for it to count,
    so guessing a place for it would be decoration for its own sake. *)
let draw_timer (rs : Gl.run list ref) =
  let s = (ui ()).skin in
  let pad = 6 in
  let y = (Skin.top_inset () - 90) / 2 + 2 in
  ignore (Skin.draw s rs frame_timer_l ~place:{ Layout.x = pad; y; w = 0; h = 0 });
  ignore
    (Skin.draw s rs frame_timer_r
       ~place:{ Layout.x = window_w - pad - 90; y; w = 0; h = 0 })

let draw ?(present = true) () =
  let b = battle () in
  let lay = layout () in
  let bg = bar () in
  let gl = (ui ()).gl in
  Gl.begin_frame gl;
  (* Each quad is emitted with the colour its run will be drawn with, so the run
     list and the vertex buffer stay in step. *)
  let runs = ref [] in
  let emit dst col =
    let first = Gl.push_quad gl dst None col in
    runs := !runs @ [ { Gl.first; count = 6; tex = None; colour = col } ]
  in
  (* A gem, drawn from the sheet when a frame was identified for it. The fallback
     is the flat colour rather than a guessed sprite: drawing the wrong gem would
     be worse than drawing an obvious placeholder. *)
  let emit_gem x y g =
    let dst = Layout.cell_rect lay x y in
    match ((ui ()).gem_sheet, Assets.frame g) with
    | Some sheet, Some uv ->
        let first =
          Gl.push_quad ~tex_size:(Assets.sheet_width, Assets.sheet_height) gl dst
            (Some uv) (Layout.rgba 255 255 255 255)
        in
        runs :=
          !runs
          @ [ { Gl.first; count = 6; tex = Some sheet; colour = Layout.rgba 255 255 255 255 } ]
    | _ -> emit dst (Layout.gem_colour g)
  in
  emit
    { Layout.x = 0; y = bg.Input.top_y; w = window_w; h = bar_h }
    (Layout.rgb 20 22 30);
  (* The backdrop and the border go down first, so everything else is on top of
     them. Both come from one sheet, and both are absent together. *)
  draw_decorations runs;
  for y = 0 to lay.Layout.rows - 1 do
    for x = 0 to lay.Layout.cols - 1 do
      let g = Board.get_gem b.Battle.board { Board.x = x; y } in
      emit_gem x y g
    done
  done;
  (* The pending first half of a swap. The game marks it with a glow sprite
     (`img_selglow`), which is 200x50 - wider than a cell and half as tall, so it
     is a lozenge drawn across the cell rather than a box around it. The flat
     overlay is only the fallback for when the sheet is missing. *)
  (match (ui ()).first_cell with
  | None -> ()
  | Some (x, y) ->
      let r = Layout.cell_rect lay x y in
      if not (Skin.draw (ui ()).skin runs frame_selection ~place:r) then
        emit
          { Layout.x = r.Layout.x + 4; y = r.Layout.y + 4; w = r.Layout.w - 8;
            h = r.Layout.h - 8 }
          (Layout.rgba 255 255 255 80));
  List.iteri
    (fun i (s : Spell.spell) ->
      let affordable = Spell.can_cast b.Battle.hero s in
      emit
        { Layout.x = bg.Input.left_x + (i * (bg.Input.button_w + bg.Input.gap));
          y = bg.Input.top_y + 20; w = bg.Input.button_w; h = bar_h - 40 }
        (if affordable then Layout.rgb 70 120 200 else Layout.rgb 50 54 66))
    demo_spells;
  (* The turn counters, in the game's own timer furniture: a background either
     side of the top panel and the hourglass over it. There is no countdown in a
     turn-based battle, so what is shown is how many turns have gone. *)
  draw_timer runs;
  (* Text goes in last, on top. *)
  let runs = !runs @ draw_hud gl demo_spells in
  Gl.submit gl runs;
  (* Reading the default framebuffer after a swap gives an undefined buffer, so a
     screenshot must render without presenting and read before the swap. *)
  if present then Gl.present gl

let rec wait_click () =
  draw ();
  if Tsdl.Sdl.poll_event some_ev then begin
    let t = E.get ev E.typ in
    if t = E.quit then exit 0
    else if t = E.mouse_button_down then
      (E.get ev E.mouse_button_x, E.get ev E.mouse_button_y)
    else wait_click ()
  end
  else begin
    Tsdl.Sdl.delay 16l;
    wait_click ()
  end

let choose_spell spells : Spell.spell option =
  (* Only affordable, off-cooldown spells are live, so anything offered is a legal
     cast. Spell.can_cast is the engine's own affordability test, the same one the
     AI path uses. *)
  let usable =
    List.filter (Spell.can_cast (battle ()).Battle.hero) spells
  in
  let bg = bar () in
  Printf.printf "\n  your turn - click a button to cast, or click the board to\n\
                 \  make a match without casting:\n";
  List.iteri
    (fun i (s : Spell.spell) -> Printf.printf "    %d) %s\n" (i + 1) s.Spell.id)
    usable;
  if usable = [] then
    print_string "    (nothing affordable - just make a match)\n";
  flush stdout;
  let rec ask () =
    let mx, my = wait_click () in
    match Input.in_spell_prompt bg ~usable:(List.length usable) mx my with
    | Input.Cast i when i < List.length usable ->
        let s : Spell.spell = List.nth usable i in
        Printf.printf "  cast %s\n" s.Spell.id;
        flush stdout;
        Some s
    | Input.Cast _ ->
        (* Unreachable while [usable] and the bar agree, but a mismatch must not
           become an infinite loop. *)
        ask ()
    | Input.Decline ->
        Printf.printf "  no spell - make a match\n";
        flush stdout;
        None
    | _ -> ask ()
  in
  ask ()

let choose_swap (_legal : Board.swap list) : Board.swap option =
  let lay = layout () in
  let bg = bar () in
  let valid (ax, ay) (bx, by) =
    Board.is_valid_swap (battle ()).Battle.board { Board.x = ax; y = ay }
      { Board.x = bx; y = by }
  in
  Printf.printf "  swap: click a gem, then an adjacent one\n";
  flush stdout;
  (ui ()).first_cell <- None;
  let rec ask () =
    let mx, my = wait_click () in
    let first = (ui ()).first_cell in
    match Input.in_swap_prompt bg lay ~first ~valid mx my with
    | Input.First_cell (x, y) ->
        (ui ()).first_cell <- Some (x, y);
        Printf.printf "  selected (%d,%d) - now click a neighbour\n" x y;
        flush stdout;
        ask ()
    | Input.Swap (ax, ay, bx, by) ->
        (ui ()).first_cell <- None;
        Printf.printf "  swap (%d,%d)-(%d,%d)\n" ax ay bx by;
        flush stdout;
        Some
          {
            Board.from_pos = { Board.x = ax; y = ay };
            Board.to_pos = { Board.x = bx; y = by };
          }
    | Input.No_match ->
        (ui ()).first_cell <- None;
        Printf.printf "  that swap makes no match\n";
        flush stdout;
        ask ()
    | Input.Pass ->
        Printf.printf "  ending the turn without a move\n";
        flush stdout;
        None
    | Input.Miss -> ask ()
    (* Neither of these can come out of the swap prompt: [Pass] covers every bar
       click and [Cast] is unreachable while the bar and the drawing agree. They
       are listed so a new variant fails loudly here rather than silently hanging
       the player on an unhandled click. *)
    | Input.Cast _ | Input.Decline -> ask ()
  in
  ask ()

(* -------------------------------------------------------------------- main -- *)

let () =
  let args = Array.to_list Sys.argv in
  let seed = ref 7 and diff = ref 2 and shot = ref "" in
  let rec parse = function
    | [] -> ()
    | "--seed" :: n :: r ->
        seed := int_of_string n;
        parse r
    | "--difficulty" :: n :: r ->
        diff := int_of_string n;
        parse r
    | "--shot" :: f :: r ->
        shot := f;
        parse r
    | _ :: r -> parse r
  in
  parse (List.tl args);
  let rng = lcg !seed in
  let mana =
    { Combat.earth = 14; fire = 14; air = 14; water = 14 }
  in
  let hero =
    Combat.make_combatant ~cunning:5 ~max_life:60 ~life:60 ~mana
      ~skills:(skill 4) 0 "you"
  in
  let foe =
    Combat.make_combatant ~cunning:3 ~max_life:60 ~life:60
      ~skills:(skill 4) 1 "foe"
  in
  let gl = Gl.create ~title:"Puzzle Quest" ~width:window_w ~height:window_h in
  (* The gem sheet is loaded once. If it is missing the board falls back to flat
     colours, so a fresh checkout still runs - it just looks like the placeholder
     it was. *)
  let gem_sheet =
    match Assets.sheet_path () with
    | path when Sys.file_exists path ->
        let px, w, h = Assets.load_rgba path in
        Printf.printf "  gem sheet %s (%dx%d)\n" path w h;
        Some (Gl.texture_of_bigarray ~w ~h px)
    | path ->
        Printf.printf
          "  no gem sheet at %s - run tools/extract_gfx_assets.ps1 (flat colours)\n"
          path;
        None
  in
  Printf.printf "renderer: %s\n  GL: %s\n" (Gl.renderer_name ()) (Gl.gl_version ());
  flush stdout;
  let lay =
    Layout.create ~cell ~cols:Board.default_width ~rows:Board.default_height ~window_w ~window_h ~reserve_top:(Skin.top_inset ()) ~reserve_bottom:bar_h
  in
  (* The HUD's five fonts, named by their tags in the game's own English/Font.xml.
     Only these five faces get decoded: ten are shipped and the other five are
     quest and script faces this screen never draws. *)
  let want = List.filter_map Font_layout.metrics_of_tag
      [ "font_system"; "font_small"; "font_button"; "font_xp"; "font_gold" ]
  in
  let fonts = Font.create ~styles:want in
  (match fonts with
  | None ->
      Printf.printf
        "  no font atlases in %s - run tools/extract_gfx_assets.py (no labels)\n"
        (Font.face_dir ())
  | Some _ -> Printf.printf "  fonts: %d atlases\n" (List.length want));
  flush stdout;
  u :=
    Some
      { gl;
        gem_sheet;
        b = None;
        layout = lay;
        first_cell = None;
        fonts;
        system = Font_layout.metrics_of_tag "font_system";
        small = Font_layout.metrics_of_tag "font_small";
        button = Font_layout.metrics_of_tag "font_button";
        xp = Font_layout.metrics_of_tag "font_xp";
        gold = Font_layout.metrics_of_tag "font_gold";
        (* Two sheets carry the whole frame: the backdrop the border is cut out
           of, and the sheet the selection glow and turn counters live on. *)
        skin = Skin.create ~gl ~sheets:[ "bmp_skin_backdrop"; "bmp_skin_battlemisc" ] };
  let rules =
    { Battle.default_rules with
      difficulty = !diff;
      player = Some { Battle.choose_spell; choose_swap } }
  in
  let b =
    Battle.create ~rng ~rules ~hero_spells:demo_spells ~enemy_spells:demo_spells
      (fresh_board rng) hero foe
  in
  (ui ()).b <- Some b;
  (* --shot draws one frame, writes it as raw RGBA and exits. What the window
     actually shows is then measurable instead of described. *)
  if !shot <> "" then begin
    draw ~present:false ();
    let px = Gl.read_frame_rgba ~width:window_w ~height:window_h in
    let oc = open_out_bin !shot in
    output_string oc (Printf.sprintf "P6\n%d %d\n255\n" window_w window_h);
    (* P6 is RGB; drop the alpha byte from each pixel. *)
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
  Printf.printf "  cell %dpx, board at (%d,%d)\n" cell lay.Layout.origin_x
    lay.Layout.origin_y;
  Printf.printf
    "  hero life %d/%d   click a gem then an adjacent one to swap\n\n"
    hero.Combat.life hero.Combat.max_life;
  flush stdout;
  let finished = Battle.run b in
  draw ();
  print_newline ();
  (match finished.Battle.winner with
  | Some Battle.HeroVictory -> print_string "  You win.\n"
  | Some Battle.EnemyVictory -> print_string "  You lose.\n"
  | Some Battle.Draw -> print_string "  Mutual destruction.\n"
  | Some Battle.Stalemate -> print_string "  Stalemate.\n"
  | None -> print_string "  No outcome recorded.\n");
  Printf.printf "  %d turns, %d mana burns\n" finished.Battle.turns_elapsed
    finished.Battle.mana_burns;
  flush stdout;
  (* Leave the final frame up rather than closing on it. *)
  let rec linger () =
    draw ();
    if Tsdl.Sdl.poll_event some_ev then
      if E.get ev E.typ = E.quit then ()
      else linger ()
    else begin
      Tsdl.Sdl.delay 16l;
      linger ()
    end
  in
  linger ();
  Gl.destroy gl