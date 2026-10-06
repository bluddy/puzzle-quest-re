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

(* The message fonts. Seven `font_msg_*` styles exist and this is what they are
   for: the float-text palette. They are all the same face - WC_Message - so the
   seven atlases the HUD already loads cover them; what differs is the colour,
   which the font carries, so naming the tag is naming the colour. *)
let message_fonts =
  List.filter_map
    (fun tag -> Option.map (fun m -> (tag, m)) (Font_layout.metrics_of_tag tag))
    [ "font_msg_white"; "font_msg_red"; "font_msg_orange"; "font_msg_yellow";
      "font_msg_green"; "font_msg_cyan"; "font_msg_purple" ]

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
(* The live float messages, fed by [Battle.on_event] as the battle runs. *)
  float_text : Float_text.t;
  (* The mixer. Silent by construction: no device, no sounds extracted, or an
     unknown tag all mean "play nothing", never an error. *)
  audio : Audio.t;
  (* The cascade animation. Fed by [Battle.on_step], drained by the frame loop. *)
  anim : Anim.t;
  (* Spell effects, from the game's own descriptors: a name and a point is all it
     takes, and the timings come out of `lib/fx_data.ml`. *)
  fx : Fx.t;
  (* The six particle textures, keyed by the file name the descriptors use. None of
     them is a registry frame - they are whole 32x32 and 64x64 images - so they are
     loaded individually rather than cut out of a sheet. A missing one costs the
     particles that use it and nothing else. *)
  fx_textures : (string * Gl.texture * int * int) list;
}


(** Where the particle textures live, alongside the font atlases. *)
let fx_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p -> Filename.concat p "Particles"
  | _ -> "assets/gfx/Particles"

let u : ui option ref = ref None

let ui () = match !u with Some x -> x | None -> failwith "ui not created"

let battle () = match (ui ()).b with Some b -> b | None -> failwith "no battle"
let layout () = (ui ()).layout

(** The message a subject is anchored to.

    A message belongs over the character it is about, and the characters have no
    portraits placed yet - so the hero's side is the left margin and the foe's the
    right, either side of the board. When the portraits arrive this is the one
    function that moves.

    The anchor is a one-pixel box: [place_message] takes the box's smaller corner
    and centres the text on it, which is exactly what a point anchor wants, and it
    clamps the result into the screen on the way. *)
let message_anchor (s : Float_text.subject) : Font_layout.box =
  let lay = layout () in
  let board = Layout.board_rect lay in
  let point x y = { Font_layout.x0 = x; y0 = y; x1 = x; y1 = y } in
  match s with
  | Float_text.Both -> point (board.Layout.x + (board.Layout.w / 2)) (board.Layout.y - 40)
  | Float_text.Hero -> point (board.Layout.x / 2) (board.Layout.y + (board.Layout.h / 2))
  | Float_text.Foe ->
      point (board.Layout.x + board.Layout.w - (board.Layout.w / 4))
        (board.Layout.y + (board.Layout.h / 2))

(** Clock for message lifetimes, in seconds.

    [Tsdl.Sdl.get_ticks] would do, but the float messages have to age in step with
    the frame loop's own notion of time, and mixing a millisecond counter with a
    float accumulator is how a message ends up expiring on the wrong frame. This
    is a plain float the presentation layer advances. *)

(** Where a character stands, for an effect aimed at one.

    The original asks the character for its screen point and then subtracts the
    camera offset (`Engine_ADD_ANIMEFFECT_TO_CHARACTER_47b370`). There is no camera
    here - the board is fixed and the portraits are painted into the backdrop - so
    these are two points measured off that 1024x768 art: the hero's chest on the
    left, and the foe's on the right.

    Measured rather than derived, and recorded as such: the board rectangle *is*
    derivable, but the portraits are not - the hero is a figure painted into the
    backdrop and the foe is only its name and life total, so "the foe's screen point"
    has no recovered answer here. Both are also the same points the float messages
    are anchored to, which is the tidier way to be wrong: one number for each side
    rather than two that drift apart. *)
let hero_point () = message_anchor Float_text.Hero
let foe_point () = message_anchor Float_text.Foe
let now_seconds = ref 0.0

(** One frame's worth of presentation time, in seconds.

    The idle loop's delay is the only clock in the front end, so the frame rate is
    this number by definition: 16ms is a 60Hz frame and close enough at any rate a
    window manager will give us. Both the idle loop and the step observer advance
    by it, so a message and a falling gem age by the same amount on either path. *)
let frame_seconds = 0.016

(** Whether the front end is showing frames as the battle happens, rather than only
    settling everything before one screenshot.

    `--demo` and `--shot` set it false: they want a settled state (or a named instant
    inside the first animation) rather than a paced replay, and they have no loop to
    pace into. *)
let paced = ref true

(** Animation frames the step observer has drawn while blocking, across the whole
    process.

    Not decoration: `--demo` and `--shot` deliberately skip the block, so without a
    counter there is no way to tell a paced run that animated from one that quietly
    fell back to queueing everything and settling it at the end. The counter is the
    difference between "it looked fine" and "it ran". *)
let drained_frames = ref 0

(** Advance the clock, expire finished messages, and return whether the screen
    changed enough to be worth redrawing. *)
let advance_clock (dt : float) : bool =
  now_seconds := !now_seconds +. dt;
  let before = Float_text.count (ui ()).float_text in
  Float_text.tick (ui ()).float_text !now_seconds;
  Float_text.count (ui ()).float_text <> before

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

let fx_sprite_size name =
  match List.find_opt (fun (n, _, _, _) -> n = name) (ui ()).fx_textures with
  | Some (_, _, w, h) -> (w, h)
  | None -> (0, 0)

(** Draw whatever effects are running, over the board and under the HUD text.

    A particle is drawn from its own texture and an effect's own bitmap from the
    registry sheet, so the two are looked up differently - which is why this cannot
    be folded into [emit_gem]. Additive runs are marked as such, because an additive
    sparkle drawn with the ordinary blend is a grey dot. *)
let draw_fx (rs : Gl.run list ref) =
  let st = ui () in
  let gl = st.gl in
  let skin = st.skin in
  let sprites = Fx.frame st.fx ~texture_size:(fx_sprite_size) in
  List.iter
    (fun (s : Fx.sprite) ->
      match Fx.quad_of_sprite ~texture_size:fx_sprite_size s with
      | None -> ()
      | Some (dst, uv, colour, rotation, blend) ->
          let tex, dims =
            match s.Fx.image with
            | Fx.Region { sheet; _ } ->
                (* A spell effect\'s own bitmap is a region of a registry sheet, so it
                   comes from the same place the border and the glows do. *)
                ( match Skin.sheet_texture skin sheet with
                  | Some (tex, w, h) -> (Some tex, (w, h))
                  | None -> (None, (0, 0)) )
            | Fx.Particle_sprite { texture; _ } -> (
                match List.find_opt (fun (n, _, _, _) -> n = texture) st.fx_textures with
                | Some (_, tex, w, h) -> (Some tex, (w, h))
                | None -> (None, (0, 0)))
          in
          (match tex with
          | None -> ()
          | Some tex ->
              let first =
                Gl.push_quad ~tex_size:dims ~rotate:rotation gl dst (Some uv) colour
              in
              rs :=
                !rs
                @ [
                    {
                      Gl.first;
                      count = 6;
                      tex = Some tex;
                      colour;
                      clip = None;
                      blend =
                        (match blend with
                        | Fx_data.Additive -> Some Gl.Additive
                        | Fx_data.Alpha_blend -> Some Gl.Alpha);
                    };
                  ]))
    sprites

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
    runs := !runs @ [ { Gl.first; count = 6; tex = None; colour = col; clip = None; blend = None } ]
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
          @ [ { Gl.first; count = 6; tex = Some sheet; colour = Layout.rgba 255 255 255 255; clip = None; blend = None } ]
    | _ -> emit dst (Layout.gem_colour g)
  in
  emit
    { Layout.x = 0; y = bg.Input.top_y; w = window_w; h = bar_h }
    (Layout.rgb 20 22 30);
  (* The backdrop and the border go down first, so everything else is on top of
     them. Both come from one sheet, and both are absent together. *)
  draw_decorations runs;
(* Gems come from the animation while it is running, and from the battle's own
     board when it is not. That is the whole seam: [Anim.frame] returns fractional
     cell positions for whatever phase is current, and this turns them into quads.
     A cell is a float here, which is what makes a gem's motion read as motion
     rather than as a jump between two frames. *)
  let anim = (ui ()).anim in
  if Anim.is_busy anim then begin
    (* Confined to the board: a gem dropping in from above the top row must not
       paint over the title art. The scissor rides on each run rather than being
       enabled around the pushes, because [Gl.submit] is where drawing happens. *)
    let board = Layout.board_rect lay in
    let clip = Some board in
    List.iter
      (fun (g : Anim.placed_gem) ->
        let dst =
          { Layout.x = lay.Layout.origin_x + (int_of_float (g.Anim.x *. float_of_int lay.Layout.cell));
            y = lay.Layout.origin_y + (int_of_float (g.Anim.y *. float_of_int lay.Layout.cell));
            w = int_of_float (g.Anim.w *. float_of_int lay.Layout.cell);
            h = int_of_float (g.Anim.h *. float_of_int lay.Layout.cell) }
        in
        match ((ui ()).gem_sheet, Assets.frame g.Anim.gem) with
        | Some sheet, Some uv ->
            let sprite_colour = Layout.rgba 255 255 255 g.Anim.alpha in
            let first =
              Gl.push_quad ~tex_size:(Assets.sheet_width, Assets.sheet_height) gl dst
                (Some uv) sprite_colour
            in
            runs :=
              !runs
              @ [ { Gl.first; count = 6; tex = Some sheet; colour = sprite_colour; clip; blend = None } ]
        | _ ->
            (* No sprite: a flat colour, faded by alpha like the sprite path. *)
            let flat = Layout.gem_colour g.Anim.gem in
            let col = { flat with Layout.a = g.Anim.alpha } in
            let first = Gl.push_quad gl dst None col in
            runs := !runs @ [ { Gl.first; count = 6; tex = None; colour = col; clip; blend = None } ])
      (Anim.frame anim);
  end
  else
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
  (* Spell effects go in after the gems and before the text, so a sparkle is over the
     board and under the numbers it belongs to. *)
  draw_fx runs;
  (* Text goes in last, on top: the HUD, then the float messages over everything. *)
  let runs = !runs @ draw_hud gl demo_spells in
  let runs =
    match (ui ()).fonts with
    | None -> runs
    | Some fonts ->
        let lookup tag = List.assoc_opt tag message_fonts in
        runs
        @ Float_text.draw gl fonts (ui ()).float_text ~screen_w:window_w
            ~screen_h:window_h ~metrics_of:lookup
  in
  Gl.submit gl runs;
  (* Reading the default framebuffer after a swap gives an undefined buffer, so a
     screenshot must render without presenting and read before the swap. *)
  if present then Gl.present gl

(** Wait for a click, keeping messages alive meanwhile.

    The clock is advanced on every pass, not only on events, so a message fades
    while the player is thinking rather than sitting on screen until their next
    move. The redraw is conditional for the same reason: repainting at 60Hz an
    unchanged screen costs a full vertex-buffer upload for nothing, and this loop
    runs for as long as the player hesitates.

    The frame delay is the loop's clock. Nothing here measures elapsed time, so
    the pacing is tied to the idle rate - which is fine for a message fading over
    about a second, and would not be fine for anything that has to keep time with
    the battle. It does not: the battle is paused while this runs. *)
let rec wait_click () =
  (* The animation clock and the float-message clock are advanced together, and the
     redraw happens when either has something new to show. While a cascade is
     animating this is the only thing running, so it is also the frame loop: the
     delay is what paces it.

     Tying the two clocks together is deliberate rather than tidy. They are both
     presentation time, they both need to advance together or a message outlives
     the pop it belongs to, and keeping one idle delta avoids the temptation to
     advance them separately and get that wrong. *)
  let anim_changed = Anim.advance (ui ()).anim frame_seconds in
  (* The effects carry their own clock for the same reason the cascade does, and are
     advanced on the same delta: an effect that runs at a different rate from the
     gems popping around it reads as two systems rather than one. *)
  let fx_changed = Fx.advance (ui ()).fx frame_seconds in
  let messages_changed = advance_clock frame_seconds in
  if anim_changed || messages_changed || fx_changed then draw ();
  if Tsdl.Sdl.poll_event some_ev then begin
    let t = E.get ev E.typ in
    if t = E.quit then exit 0
    else if t = E.mouse_button_down then begin
      (* Always repaint before acting on the click: the click may have landed on a
         board whose gems moved since the last frame. *)
      draw ();
      (E.get ev E.mouse_button_x, E.get ev E.mouse_button_y)
    end
    else wait_click ()
  end
  else begin
    Tsdl.Sdl.delay (Int32.of_int (int_of_float (frame_seconds *. 1000.)));
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
        (* The button's own click, before the spell's sound. Both are real tags:
           `snd_buttup` is the button, and the spell sound follows from the observer
           when the battle emits the cast. *)
        ignore (Audio.play (ui ()).audio "snd_buttup");
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

(** Called by the battle as each event happens.

    This is the whole point of `Battle.on_event`: the engine resolves a turn
    internally, so without an observer the front end either waits for the turn to
    finish and replays a burst of events, or polls the log and misses the order.
    Being called in sequence means a cascade's messages arrive one at a time, in
    the order the cascade actually happened.

    The pause between events is the presentation layer's business, not the
    engine's - the engine has no clock and should not grow one. [pause_ms] is zero
    in `--shot` mode, because a screenshot of a burst is a screenshot of the last
    frame, and the point of `--shot` is to see one specific thing. *)
let on_battle_step (_b : Battle.battle) (s : Battle.step) =
  let anim = (ui ()).anim in
  Anim.push_step anim s;
  (* Play the step out before the engine is allowed to carry on.

     This is not a nicety, it is the difference between the cascade being seen and
     being replayed. `Battle` resolves a whole turn synchronously, so every step of
     a six-step cascade arrives back to back while nothing is drawing; if the steps
     are only queued, the board is already final by the time the animation queue is
     drained by [wait_click], and what the player then watches is the board
     rewinding through every state it already passed through.

     Blocking here costs nothing: the engine is single-threaded and has no clock, so
     the only thing that can happen while this runs is that no further steps are
     produced - which is the point. Each step's events have already been emitted
     (the engine emits them before it refills), so its message and its sound are up
     before its gems move; that ordering is why the block goes here and not in the
     event callback.

     `--demo` and `--shot` skip the block, because they have no frame loop to block
     into and one specific frame is the thing being asked for. *)
  if !paced then begin
    let guard = ref 0 in
    while Anim.advance anim frame_seconds && !guard < 10_000 do
      incr guard;
      incr drained_frames;
      (* The message clock ages with the animation clock here for the same reason
         it does in [wait_click]: they are both presentation time, and a message
         whose step is now animating must not be still fully opaque when its gems
         land. *)
      ignore (advance_clock frame_seconds);
      draw ();
      Tsdl.Sdl.delay (Int32.of_int (int_of_float (frame_seconds *. 1000.)))
    done
  end

let on_battle_event ~(pause_ms : int) (b : Battle.battle) (e : Battle.event) =
  (* A cast is the one event whose sound needs more than the event: it depends on
     what the spell does, and the event carries only its id. So the spell is looked
     up by name here, where the spell list is in scope. *)
  let spell =
    match e with
    | Battle.SpellCast (_, id) -> List.find_opt (fun (s : Spell.spell) -> s.Spell.id = id) demo_spells
    | _ -> None
  in
  ignore (Audio.play_all (ui ()).audio (Sound_map.with_spell e spell));
  ignore (Float_text.say_event (ui ()).float_text e ~anchor_of:message_anchor !now_seconds);
  (* The effect, which is the same lookup in the other direction: the spell's script
     named a SPELLFX constant, the constant named an effect, and the effect plays
     itself out over its own descriptor's duration.

     Aimed at the caster, which is what `Std_CastSpellEffect` does - the enemy and
     grid forms aim elsewhere and are not wired up yet. A cast by either side plays
     on the caster's own portrait, so which combatant cast is read off the event's
     first field. *)
  (match e with
  | Battle.SpellCast (who, id) ->
      (* The event carries the caster's *name*, so whose side to play on is a
         comparison against the hero's. The anchor is a one-pixel box and the player
         wants a point, so the middle of it is taken. *)
      let a = if who = b.Battle.hero.Combat.name then hero_point () else foe_point () in
      let at = { Fx.x = float_of_int (a.Font_layout.x0); y = float_of_int a.Font_layout.y0 } in
      ignore (Fx.play_for_fx (ui ()).fx id ~at)
  | _ -> ());
  (* The clock advances whether or not the frame is actually shown. In `--demo`
     there is no real pause, but messages still have to expire or the screen fills
     with every message the battle has ever produced - which is exactly what the
     first demo screenshot showed. *)
  let dt = float_of_int pause_ms /. 1000.0 in
  now_seconds := !now_seconds +. dt;
  Float_text.tick (ui ()).float_text !now_seconds;
  if pause_ms > 0 then begin
    draw ();
    Tsdl.Sdl.delay (Int32.of_int pause_ms)
  end

(* -------------------------------------------------------------------- main -- *)

let () =
  let args = Array.to_list Sys.argv in
  let seed = ref 7 and diff = ref 2 and shot = ref "" and demo_turns = ref 0 in
  let shot_at = ref None in
  (* `--pace` plays a demo with the front end's blocking animation loop, so the
     interactive path can be exercised without a keyboard: same observer, same
     frames, just no input to supply. *)
  let pace = ref false in
  let rec parse = function
    | [] -> ()
    | "--seed" :: n :: r ->
        seed := int_of_string n;
        parse r
    | "--difficulty" :: n :: r ->
        diff := int_of_string n;
        parse r
| "--pace" :: r ->
        pace := true;
        parse r
    | "--shot" :: f :: r ->
        shot := f;
        parse r
    | "--shot-at" :: n :: r ->
        shot_at := Some (float_of_string n);
        parse r
    | "--demo" :: n :: r ->
        demo_turns := int_of_string n;
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
        let px, w, h = Assets.load_gem_sheet path in
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
(* The fonts this screen draws with, named by their tags in the game's own
     English/Font.xml. Only the faces behind these get decoded: ten are shipped
     and the rest are quest and script faces this screen never draws.

     The message tags have to be in this list as well as in [message_fonts]. They
     share the WC_Message face, so they cost one extra atlas - and leaving them
     out is completely silent: the metrics resolve, the text is laid out, and
     [Font.draw] returns no quads because the atlas was never loaded. That is how
     the first render of the float text came out with 32 messages live and an
     empty screen. [Font.create] now complains if a requested style did not get
     its atlas, which is the guard that should have existed. *)
  let want =
    List.filter_map Font_layout.metrics_of_tag
      ([ "font_system"; "font_small"; "font_button"; "font_xp"; "font_gold" ]
      @ List.map fst message_fonts)
  in
  let fonts = Font.create ~styles:want in
  (match fonts with
  | None ->
      Printf.printf
        "  no font atlases in %s - run tools/extract_gfx_assets.py (no labels)\n"
        (Font.face_dir ())
  | Some _ -> Printf.printf "  fonts: %d atlases\n" (List.length want));
  flush stdout;
  (* The six particle textures the effect descriptors name. Loaded whole, each
     one, keyed by the file name `lib/fx_data.ml` uses - so a particle asking for
     `Sparkle.png` finds it by the same string the archive used. *)
  let fx_textures =
    List.filter_map
      (fun tex ->
        let path = Filename.concat (fx_dir ()) tex in
        if not (Sys.file_exists path) then None
        else
          let px, w, h = Assets.load_image path in
          Some (tex, Gl.texture_of_bigarray ~w ~h px, w, h))
      Fx_data.textures
  in
  let missing = List.length Fx_data.textures - List.length fx_textures in
  if missing > 0 then
    Printf.printf
      "  %d of %d particle textures missing from %s - run tools/extract_gfx_assets.py\n"
      missing
      (List.length Fx_data.textures)
      (fx_dir ());
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
        float_text = Float_text.create ();
        audio = Audio.create ();
        anim = Anim.create ();
        fx = Fx.create ();
        fx_textures;
        (* Two sheets carry the whole frame: the backdrop the border is cut out
           of, and the sheet the selection glow and turn counters live on. *)
        skin = Skin.create ~gl ~sheets:[ "bmp_skin_backdrop"; "bmp_skin_battlemisc" ] };
(* `--demo N` plays N turns with nobody at the keyboard before anything is
     drawn. It exists because `--shot` on its own photographs the board before the
     battle has done anything, which cannot show damage numbers, cascades or any
     other event-driven thing - and "the float text renders" is not a claim worth
     making on the strength of a screenshot of an empty board. *)
  let rules =
    { Battle.default_rules with
      difficulty = !diff;
      player = (if !demo_turns > 0 then None else Some { Battle.choose_spell; choose_swap }) }
  in
  let b =
    Battle.create ~rng ~rules ~hero_spells:demo_spells ~enemy_spells:demo_spells
      (fresh_board rng) hero foe
  in
  (* Attached after [create], which is the only point at which the battle exists to
     hand the observer. With no `--shot` the events are paced; with one they are
     not, because a screenshot of a paced sequence is a screenshot of whichever
     frame happened to be last. *)
  b.Battle.on_event <-
    Some (on_battle_event ~pause_ms:(if !shot = "" then 90 else 0));
  b.Battle.on_step <- Some on_battle_step;
  paced := (!demo_turns = 0 && !shot = "") || !pace;
  (ui ()).b <- Some b;
  if !demo_turns > 0 then begin
    for _ = 1 to !demo_turns do
      if b.Battle.winner = None then Battle.take_turn b
    done;
    (* The demo plays with no frame loop, so both queues have built up with nothing
       draining them. Settle them before drawing, or the screenshot shows whichever
       cascade happened first rather than the board the battle ended on.

       Both clocks are advanced together, because they are both presentation time
       and an effect stopped half way is a different picture from a cascade stopped
       half way.

       `--shot-at T` stops part way in instead, which is how a fall, a pop or a
       spell effect gets looked at: the first phase starts the instant the queue
       does, so T of about a fifth of a second lands inside it. *)
    (match !shot_at with
    | Some t ->
        let anim = (ui ()).anim in
        let fx = (ui ()).fx in
        let stop = Anim.now anim +. t in
        while Anim.now anim < stop && (ignore (Anim.advance anim 0.016); true) do
          ignore (Fx.advance fx 0.016)
        done
    | None ->
        let anim = (ui ()).anim in
        let fx = (ui ()).fx in
        let guard = ref 0 in
        while Anim.advance anim 0.05 && !guard < 10_000 do
          incr guard;
          ignore (Fx.advance fx 0.05)
        done;
        (* And the effects themselves, which have their own durations. *)
        let guard2 = ref 0 in
        while Fx.is_busy fx && !guard2 < 10_000 do
          incr guard2;
          ignore (Fx.advance fx 0.05)
        done);
    Printf.printf
      "  demo: %d turns, %d events, %d messages live, %d sounds started, %d animation frames, %d effects\n"
      b.Battle.turns_elapsed
      (List.length (Battle.log_of b))
      (Float_text.count (ui ()).float_text)
      (ui ()).audio.Audio.played
      !drained_frames
      (Fx.played (ui ()).fx);
    flush stdout
  end;
  (* `--pace` is a smoke run, not a game: the turns are played and animated and then
     the process ends. Without this it would fall through into [Battle.run] and sit
     there waiting for clicks that nothing is going to send. *)
  if !pace then begin
    Audio.destroy (ui ()).audio;
    Gl.destroy gl;
    exit 0
  end;
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
    Audio.destroy (ui ()).audio;
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
  Audio.destroy (ui ()).audio;
  Gl.destroy gl