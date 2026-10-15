(** The playable battle screen, as a module the other fronts can host.

    This is [bin/pq_play_gfx.ml]'s whole body moved into the library: the same
    blocking model - [Battle.run] re-enters the window through the human's
    three hooks and the three observers, and each hook pumps SDL events
    internally - but reached through [create] / [hooks] / [run] instead of
    only through a standalone executable. The world map hosts it so a quest,
    callback or road fight is a fight the player plays rather than a banner
    reporting one that already happened.

    One screen per process, held in a module-level slot: the host blocks while
    a fight runs, so two could never draw at once. [create] loads the art once
    over the host's own GL context; [run] resets the per-fight state, attaches
    the observers to the un-run battle it is handed and plays it out.

    Nothing about the recovered rules is re-implemented here - see the note in
    [Battle_layout] and docs/BATTLE_AI.md. No CRT filter, no scanlines; see
    the note in tools/graphics_plan.md. *)

open Puzzle_quest_lib
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
   is the size a gem is {e meant} to be. An 8x8 board of them is 568 square. The
   original's `pad_grid` is 584 - 73px cells - which is the one place the port
   and the asset disagree by two pixels a cell; see [Battle_layout.pad_grid]. *)
let cell = 71

(* The band under the board: the combat log's backdrop, full width. The original
   has no log and so has no band - its spell rows run to y=745 - which is why this
   number is the port's rather than recovered. *)
let bar_h = 96

(* The side the player sits on: `pad_gamechar0`, the left pad. The spell buttons
   are that pad's seven rows, so this is the one place the choice is made. *)
let side = Battle_layout.Hero

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

(** Where the particle textures live, alongside the font atlases. *)
let fx_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p -> Filename.concat p "Particles"
  | _ -> "assets/gfx/Particles"

(* ------------------------------------------------------------------- state -- *)

type t = {
  gl : Gl.context;
  gem_sheet : Gl.texture option;
  mutable b : Battle.battle option;
  (* Fixed: the window is not resizable, so the board geometry never moves. *)
  layout : Layout.t;
  mutable first_cell : (int * int) option;  (** first half of a pending swap *)
  mutable hover : (int * int) option;  (** the cell the mouse is over *)
  mutable aim_shape : int;  (** 0 = no aim question open; else the spell's input_type *)
  (* None when no font atlas could be loaded, which is a supported state: the
     battle is still playable, it just has no labels. *)
  fonts : Font.t option;
  system : Font_layout.metrics option;  (** font_system - the HUD's body text *)
  small : Font_layout.metrics option;  (** font_small - the tight fits *)
  button : Font_layout.metrics option;  (** font_button - the spell rows *)
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

(* The one screen this module holds. A host creates it once and blocks while a
   fight runs, so a module-level slot rather than a value threaded through every
   draw - which is also what the standalone front always was. *)
let u : t option ref = ref None

let ui () = match !u with Some x -> x | None -> failwith "battle screen not created"

let battle () = match (ui ()).b with Some b -> b | None -> failwith "no battle"
let layout () = (ui ()).layout

(** The message a subject is anchored to.

    A message belongs over the character it is about, and the characters now have
    somewhere to be about: `pad_gamechar0` and `pad_gamechar1`, the two side
    panels, where the life and mana bars are drawn. [Battle_layout] holds their
    rectangles, so the float messages rise off the same rectangles the bars do
    rather than off a guess about where a portrait would be.

    The anchor is a one-pixel box: [place_message] takes the box's smaller corner
    and centres the text on it, which is exactly what a point anchor wants, and it
    clamps the result into the screen on the way. *)
let message_anchor (s : Float_text.subject) : Font_layout.box =
  let point x y = { Font_layout.x0 = x; y0 = y; x1 = x; y1 = y } in
  let over (side : Battle_layout.side) =
    let p = Battle_layout.panel side in
    point (p.Layout.x + (p.Layout.w / 2)) (p.Layout.y + (p.Layout.h / 3))
  in
  match s with
  | Float_text.Both ->
      let board = Layout.board_rect (layout ()) in
      point (board.Layout.x + (board.Layout.w / 2)) (board.Layout.y - 40)
  | Float_text.Hero -> over Battle_layout.Hero
  | Float_text.Foe -> over Battle_layout.Foe

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

(** One frame's worth of presentation time, in seconds.

    The idle loop's delay is the only clock in the front end, so the frame rate is
    this number by definition: 16ms is a 60Hz frame and close enough at any rate a
    window manager will give us. Both the idle loop and the step observer advance
    by it, so a message and a falling gem age by the same amount on either path. *)
let frame_seconds = 0.016

(* Clock for message lifetimes, in seconds. [Tsdl.Sdl.get_ticks] would do, but the
   float messages have to age in step with the frame loop's own notion of time, and
   mixing a millisecond counter with a float accumulator is how a message ends up
   expiring on the wrong frame. This is a plain float the presentation layer
   advances. *)
let now_seconds = ref 0.0

(** Whether the front end is showing frames as the battle happens, rather than only
    settling everything before one screenshot.

    `--demo` and `--shot` set it false: they want a settled state (or a named instant
    inside the first animation) rather than a paced replay, and they have no loop to
    pace into. A hosted fight is always paced. *)
let paced = ref true

(** Animation frames the step observer has drawn while blocking, across the whole
    process.

    Not decoration: `--demo` and `--shot` deliberately skip the block, so without a
    counter there is no way to tell a paced run that animated from one that quietly
    fell back to queueing everything and settling it at the end. The counter is the
    difference between "it looked fine" and "it ran". *)
let drained_frames = ref 0

(** The cell captured by the last [choose_spell]. The engine asks for it right
    after the spell is picked - [choose_aim] is the other half of the pair - so
    the target question can live inside the spell question, where "cancel" can
    mean "back to the spell question" instead of "cast nothing". *)
let cast_aim : Board.position option ref = ref None

(** How many grid effects this process has been asked for.

    Reported with the demo line, and in a demo it reads zero - which is the game's
    AI rather than a broken wire. Four of the eleven spells that put an effect on a
    cell ask for `Std_AISpellcastingChance(0)`, and the rest are gated behind the
    rule that the AI only casts when the board is worth 30 points or less, so a
    six-turn demo almost always just moves.

    It is printed anyway, for the reason the sound counter is: "wired up but never
    reached" and "not wired up" look identical from the outside, and a number that
    says which is cheaper than finding out by eye. The path itself is proven by
    `test_battle`, which drives one through the human hook where the choice is
    scripted rather than probabilistic. *)
let grid_fx_played = ref 0

(* The turn clock's front-end half. The battle holds the deadline (the
   turn_manager's +0x38) but has no wall clock, so the front feeds it the
   millisecond tick the engine read from DAT_0057f484, notices the expiry
   while a question is open - the only time the human is deciding - and draws
   the countdown. [timed_out] latches for the turn so the open question
   declines at once rather than re-asking; [clock_last_secs] is the displayed
   second, for the snd_tick rollover. *)
let timed_out : bool ref = ref false
let clock_last_secs : int ref = ref 0

(* Feed the battle's turn clock the same wall time the float messages age by:
   the battle cannot read a clock itself, so DAT_0057f484 is driven here, off
   the front's one accumulator. *)
let feed_battle_clock () =
  match (ui ()).b with
  | Some b -> b.Battle.clock_now_ms <- int_of_float (!now_seconds *. 1000.0)
  | None -> ()

(** snd_tick on every whole-second rollover of a running countdown - the
    frame-function's own gate (FUN_0040F7D0 plays it when the displayed second
    changes). Only while the clock is armed: the AI's frozen delay never
    moves, so it never ticks. *)
let service_clock () =
  match (ui ()).b with
  | None -> ()
  | Some b ->
    if Battle.clock_armed b then begin
      let secs = Battle.clock_secs_of_ms (Battle.clock_remaining_ms b) in
      if secs <> !clock_last_secs then begin
        ignore (Audio.play (ui ()).audio "snd_tick");
        clock_last_secs := secs
      end
    end

(** The turn ran out: snd_forceendturn, a red float at the offender, and the
    latch that makes every remaining question of this turn decline at once -
    the original's [FUN_00415800], minus the [-%d] life penalty (the vtable
    query behind it is not pinned, so no damage is claimed here). *)
let fire_timeout () =
  timed_out := true;
  ignore (Audio.play (ui ()).audio "snd_forceendturn");
  Float_text.say (ui ()).float_text ~font:"font_msg_red"
    ~subject:Float_text.Hero
    ~anchor:(message_anchor Float_text.Hero)
    "Time expired!" !now_seconds

(** Advance the clock, expire finished messages, feed the turn clock, and
    return whether the screen changed enough to be worth redrawing. *)
let advance_clock (dt : float) : bool =
  now_seconds := !now_seconds +. dt;
  feed_battle_clock ();
  service_clock ();
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

(* SHGO is in this list for a reason that is only visible in the demo line: it is
   one of the eleven spells that puts an effect on a *grid cell*, and unlike SBAC -
   which is also in the list, and was there first - its AI hook asks for a real
   chance of being cast. A demo list made only of zero-chance spells never
   exercises the grid-effect path, and a path that never runs is
   indistinguishable from a path that is broken. *)
let demo_spells =
  List.filter_map spell_of [ "SBAC"; "SBAV"; "SBNA"; "SBRA"; "SHGO"; "SBSG" ]

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

(** The spell buttons: the seven pads down the hero's side of the screen, in the
    original's own rectangles. Kept in one place so the drawing and the click
    handling cannot disagree about where the buttons are - they used to compute it
    separately, which is exactly the kind of duplication that makes a button that
    is drawn but not clickable. *)
let bar () : Input.bar =
  Input.of_rects (Battle_layout.spell_rows side)

(** The heads-up display: everything a player needs in order to choose a move,
    laid out on the original's own rectangles.

    The side panels carry the characters ([Battle_layout.panel]): their name and
    life across the recovered life bar, their level and the player's purse in the
    portrait area, and the four mana pools as bars with their ceilings underneath
    - a bar rather than a number because a pool that is *nearly* full and one
    that is nearly empty are the same digits and different information.

    The seven rows under each panel are the spells ([Battle_layout.spell_rows]),
    with the four costs on the second line in the same element order as the mana
    bars above them, so the row explains itself against the column it needs. A
    spell the hero cannot pay for is drawn grey and clicks as a decline, which is
    what the prompt has always meant by "not usable".

    [spells] is the battle's own hero roster - the rows are drawn from it and
    read from it, so a campaign fight shows the spells that fight brought rather
    than the standalone front's demo list.

    Colours come from the named fonts where a colour exists for the thing (gold
    and xp are the game's own orange and purple), from the element colours the
    board already uses for the mana bars, and from one grey for anything
    unavailable.

    Returns runs to append to the frame's own, so text and geometry share one
    vertex-buffer upload - [Gl.submit] takes a single run list, and a second pass
    would mean re-uploading the buffer for the sake of a few dozen glyphs. *)
let draw_hud (gl : Gl.context) (spells : Spell.spell list) : Gl.run list =
  let u = ui () in
  let b = battle () in
  let lay = layout () in
  let out = ref [] in
  let put rs = out := !out @ rs in
  (* [fonts] being None is a supported state, not an error: a checkout with no
     atlases extracted still plays, it just has no labels. *)
  let with_font m f =
    match u.fonts with
    | None -> ()
    | Some fonts -> put (f fonts m)
  in
  let centred m text ~cx ~y =
    with_font m (fun fonts m -> Font.draw_centred gl fonts m text ~cx ~y)
  in
  (* Truncate to a width rather than letting a long line run out of its
     rectangle: the log sits between two panels and a spell name sits in a
     178px pad, and neither has anywhere to overflow into. *)
  let fit (m : Font_layout.metrics) ~(max_w : int) (s : string) : string =
    if Font_layout.measure m s <= max_w then s
    else
      let rec cut n =
        if n <= 0 then ""
        else
          let t = String.sub s 0 n in
          if Font_layout.measure m t <= max_w then t else cut (n - 1)
      in
      cut (String.length s - 1)
  in
  let grey = Layout.rgb 130 132 140 and white = Layout.rgb 255 255 255 in
  let hero = b.Battle.hero and foe = b.Battle.enemy in
  let board = Layout.board_rect lay in
  let panel_block (c : Combat.combatant) (s : Battle_layout.side) =
    let p = Battle_layout.life_bar s in
    (* Name and life over the bar itself: the bar is the widest thing in the
       panel and the line is short, so the text sits on its fill. *)
    (match u.system with
    | None -> ()
    | Some m ->
        let text =
          Printf.sprintf "%s  %d/%d" c.Combat.name c.Combat.life c.Combat.max_life
        in
        with_font m (fun fonts m ->
            Font.draw gl fonts m ~colour:white
              (fit m ~max_w:(p.Layout.w - 6) text)
              ~x:(p.Layout.x + 3) ~y:(p.Layout.y + 24)));
    (* The portrait area under the bar is the player's purse, in the game's own
       gold and xp colours. The foe has no purse, so its portrait area stays
       empty until there is portrait art to put in it. *)
    if s = Battle_layout.Hero then begin
      let pr = Battle_layout.panel s in
      let top = pr.Layout.y + 48 in
      (match u.gold with
      | None -> ()
      | Some gm ->
          with_font gm (fun fonts gm ->
              Font.draw gl fonts gm
                (Printf.sprintf "%d gold" b.Battle.gold)
                ~x:(pr.Layout.x + 6) ~y:top));
      (match u.xp with
      | None -> ()
      | Some xm ->
          with_font xm (fun fonts xm ->
              Font.draw gl fonts xm
                (Printf.sprintf "%d xp" b.Battle.xp)
                ~x:(pr.Layout.x + 6) ~y:(top + 20)))
    end;
    (* The four pools, one bar each, in the board's own element order, with the
       value over the fill: `n/c` so the ceiling is visible without a second
       read of the same number. *)
    let bars = Battle_layout.mana_bars s in
    let element (i : int) (get : Combat.mana -> int) (ceiling : Combat.mana -> int)
        (letter : string) =
      let r = bars.(i) in
      let text =
        Printf.sprintf "%s %d/%d" letter (get c.Combat.mana)
          (ceiling c.Combat.max_mana)
      in
      match u.small with
      | None -> ()
      | Some m ->
          with_font m (fun fonts m ->
              Font.draw gl fonts m ~colour:white text ~x:(r.Layout.x + 4)
                ~y:(r.Layout.y + 1))
    in
    element 0 (fun m -> m.Combat.earth) (fun m -> m.Combat.earth) "E";
    element 1 (fun m -> m.Combat.fire) (fun m -> m.Combat.fire) "F";
    element 2 (fun m -> m.Combat.air) (fun m -> m.Combat.air) "A";
    element 3 (fun m -> m.Combat.water) (fun m -> m.Combat.water) "W"
  in
  panel_block hero Battle_layout.Hero;
  panel_block foe Battle_layout.Foe;
  (* --- each spell row: name, then the four costs in the element order the mana
         bars are read in, so the column on the left and the row on the side say
         the same thing --- *)
  let rows = Battle_layout.spell_rows side in
  List.iteri
    (fun i (s : Spell.spell) ->
      if i < Array.length rows then begin
        let r = rows.(i) in
        let col = if Spell.can_cast hero s then white else grey in
        let centre text m y =
          with_font m (fun fonts m ->
              let text = fit m ~max_w:(r.Layout.w - 8) text in
              let w = Font_layout.measure m text in
              Font.draw gl fonts m ~colour:col text
                ~x:(r.Layout.x + ((r.Layout.w - w) / 2)) ~y)
        in
        (match u.button with
        | None -> ()
        | Some m -> centre s.Spell.name m (r.Layout.y + 1));
        match u.small with
        | None -> ()
        | Some m ->
            centre
              (Printf.sprintf "%d %d %d %d" s.Spell.cost_earth s.Spell.cost_fire
                 s.Spell.cost_air s.Spell.cost_water)
              m (r.Layout.y + 21)
      end)
    spells;
  (* The enemy's rows are the same seven pads on the other side; the port does
     not model the AI's hand, so they carry the roster it fights with as a name
     each, greyed - a label, not a control. *)
  (match u.small with
  | None -> ()
  | Some m ->
      let foe_rows = Battle_layout.spell_rows Battle_layout.Foe in
      List.iteri
        (fun i (s : Spell.spell) ->
          let r = foe_rows.(i) in
          let name = fit m ~max_w:(r.Layout.w - 8) s.Spell.name in
          let w = Font_layout.measure m name in
          with_font m (fun fonts m ->
              Font.draw gl fonts m ~colour:grey name
                ~x:(r.Layout.x + ((r.Layout.w - w) / 2)) ~y:(r.Layout.y + 10)))
        (List.filteri (fun i _ -> i < Battle_layout.spell_count) b.Battle.enemy_spells));
  (* A prompt, so the window says what it wants rather than only the console
     doing it. It sits in the band between the top of the screen and the board,
     which is empty by construction: the board is centred below the top inset. *)
  (match u.small with
  | Some m ->
      let prompt =
        if u.aim_shape <> 0 then
          match u.hover with
          | Some _ -> "aim - click the board to cast, or a row to cancel"
          | None -> "aim - hover the board, then click to cast"
        else
          match u.first_cell with
          | Some _ -> "click an adjacent gem to swap"
          | None -> "click a gem, then an adjacent one  -  or a row to cast"
      in
      centred m prompt ~cx:(window_w / 2) ~y:14
  | None -> ());
  (* The combat log: the battle's own narration, oldest at the top, as many
     lines as the band under the board will hold. The engine already keeps the
     list in that order ([Battle.log_of]); this is a window onto its tail. *)
  let log = Battle_layout.log_rect ~board in
  let n = Battle_layout.log_lines log in
  let skip = max 0 (List.length (Battle.log_of b) - n) in
  let rec drop k l =
    if k <= 0 then l else match l with [] -> [] | _ :: t -> drop (k - 1) t
  in
  let lines = drop skip (Battle.log_of b) in
  (match u.small with
  | None -> ()
  | Some m ->
      List.iteri
        (fun i e ->
          let text = String.trim (Battle.format_event e) in
          let col =
            match e with
            | Battle.TurnStart _ -> white
            | Battle.BattleEnd _ -> Layout.rgb 250 210 90
            | Battle.Damage _ | Battle.Death _ -> Layout.rgb 235 120 110
            | _ -> grey
          in
          with_font m (fun fonts m ->
              Font.draw gl fonts m ~colour:col
                (fit m ~max_w:(log.Layout.w - 12) text)
                ~x:(log.Layout.x + 6)
                ~y:(log.Layout.y + (i * Battle_layout.log_line_h))))
        lines);
  (* The turn line, at the original's own place under everything: whose turn the
     last [TurnStart] in the narration announced. *)
  (match u.small with
  | None -> ()
  | Some m ->
      let rec text = function
        | [] -> ""
        | Battle.TurnStart (_, Battle.Hero, _) :: _ -> "your turn"
        | Battle.TurnStart (_, Battle.Enemy, name) :: _ -> name ^ "'s turn"
        | _ :: rest -> text rest
      in
      match text (Battle.log_of b) with
      | "" -> ()
      | line ->
          with_font m (fun fonts m ->
              let w = Font_layout.measure m line in
              Font.draw gl fonts m ~colour:white line
                ~x:(Battle_layout.turn_rect.Layout.x
                   + ((Battle_layout.turn_rect.Layout.w - w) / 2))
                ~y:Battle_layout.turn_rect.Layout.y));
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

(** The turn counters: the two 90x90 plates `GameMenu.xml` puts either side of the
    top panel - `icon_ltimebg` at (135,16) and `icon_rtimebg` at (784,16), with
    `str_ltime` / `str_rtime` centred over them. [Battle_layout] holds both pairs.

    What goes on them is the Time Limit countdown: the two-digit seconds the
    hero view's `drop_timelimit` buys, `"%02d"` of `(ms + 900)/1000` exactly as
    [FUN_0040F7D0] formats it, on the *active* side only - the original shows one
    plate, whichever character's turn it is. At Time Limit 0 the original hides
    both plates entirely ([FUN_0040FCB0]), so an untimed battle draws no
    countdown furniture. The number sits in the str_ltime / str_rtime band the
    XML gives it, font_button.

    The hourglass ([img_timer_0]) is likewise not drawn - it belongs to the timed
    minigames, and the battle countdown is plain text.

    Both plates only ever drew once the front end started loading the sheet they
    are cut from: their registry rows name `bmp_skin_gemsgrid`, which was not in
    the sheet list, so [Skin.draw] declined silently and the plates were geometry
    with no art behind it. *)
let draw_timer (rs : Gl.run list ref) =
  let st = ui () in
  match st.b with
  | None -> ()
  | Some b ->
    if b.Battle.rules.Battle.time_limit > 0 then begin
      (* The active side is the last [TurnStart] in the log - the same read the
         turn line below makes. [Battle.side] and [Battle_layout.side] name the
         two halves differently (Enemy / Foe), so they are mapped here. *)
      let active =
        let rec last = function
          | [] -> Battle.Hero
          | Battle.TurnStart (_, side, _) :: _ -> side
          | _ :: rest -> last rest
        in
        last (Battle.log_of b)
      in
      let side =
        match active with
        | Battle.Hero -> Battle_layout.Hero
        | Battle.Enemy -> Battle_layout.Foe
      in
      let plate = Battle_layout.timer_plate side in
      let frame = if side = Battle_layout.Hero then frame_timer_l else frame_timer_r in
      ignore
        (Skin.draw st.skin rs frame
           ~place:{ plate with Layout.w = 0; Layout.h = 0 });
      let secs = Battle.clock_secs_of_ms (Battle.clock_remaining_ms b) in
      match (st.fonts, st.button) with
      | Some fonts, Some m ->
        let r = Battle_layout.timer_text side in
        rs :=
          !rs
          @ Font.draw_centred st.gl fonts m (Printf.sprintf "%02d" secs)
              ~cx:(r.Layout.x + (r.Layout.w / 2)) ~y:r.Layout.y
      | _ -> ()
    end

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
  let gl = (ui ()).gl in
  (* The hero's own roster, so the row grounds and the HUD labels are the spells
     this fight brought - never the standalone front's demo list. *)
  let hero_spells = b.Battle.hero_spells in
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
  emit (Battle_layout.log_band bar_h) (Layout.rgb 20 22 30);
  (* The backdrop and the border go down first, so everything else is on top of
     them. Both come from one sheet, and both are absent together. *)
  draw_decorations runs;
  (* The battle screen's own geometry: the two side panels with their life bars,
     the four mana bars along each panel's foot, and the seven spell rows under
     them. Every rectangle comes from [Battle_layout], which recovered them from
     `Assets/Screens/GameMenu.xml` - the drawing and the click handling share
     that module, so a row cannot be drawn in one place and hit in another. *)
  let board = Layout.board_rect lay in
  (* The log gets its own ground: it is text on what would otherwise be the
     backdrop art, and a narration line over a painted landscape is unreadable.
     It goes down after the backdrop for the same reason the panels do. *)
  emit (Battle_layout.log_rect ~board) (Layout.rgb 14 16 22);
  let pool_at (i : int) (m : Combat.mana) =
    match i with
    | 0 -> m.Combat.earth
    | 1 -> m.Combat.fire
    | 2 -> m.Combat.air
    | _ -> m.Combat.water
  in
  let gem_at (i : int) : Board.gem =
    match i with
    | 0 -> Board.Mana Board.Earth
    | 1 -> Board.Mana Board.Fire
    | 2 -> Board.Mana Board.Air
    | _ -> Board.Mana Board.Water
  in
  let fill (r : Layout.rect) (frac : float) (col : Layout.colour) =
    let f = max 0.0 (min 1.0 frac) in
    let w = int_of_float (float_of_int r.Layout.w *. f) in
    if w > 0 then emit { r with Layout.w = w } col
  in
  List.iter
    (fun (side : Battle_layout.side) ->
      let c = if side = Battle_layout.Hero then b.Battle.hero else b.Battle.enemy in
      emit (Battle_layout.panel side) (Layout.rgb 26 28 38);
      let life = Battle_layout.life_bar side in
      emit life (Layout.rgb 58 60 70);
      let lf =
        if c.Combat.max_life <= 0 then 0.0
        else float_of_int c.Combat.life /. float_of_int c.Combat.max_life
      in
      fill life lf (Layout.rgb 84 176 96);
      (* The badge the original shows over a character who is sitting a turn
         out: the art is `img_missturn_1` in the battle sheet, and a checkout
         without it gets a flat marker rather than nothing. *)
      if List.mem_assoc "Missed" c.Combat.effects then begin
        let badge = Battle_layout.missed_badge side in
        if not (Skin.draw (ui ()).skin runs "img_missturn_1" ~place:badge) then
          emit badge (Layout.rgb 226 190 70)
      end;
      Array.iteri
        (fun i r ->
          emit r (Layout.rgb 34 36 46);
          let pool = pool_at i c.Combat.mana and ceil = pool_at i c.Combat.max_mana in
          let f = if ceil <= 0 then 0.0 else float_of_int pool /. float_of_int ceil in
          fill r f (Layout.gem_colour (gem_at i)))
        (Battle_layout.mana_bars side))
    [ Battle_layout.Hero; Battle_layout.Foe ];
  let spell_rows = Battle_layout.spell_rows side in
  List.iteri
    (fun i (s : Spell.spell) ->
      if i < Array.length spell_rows then begin
        let r = spell_rows.(i) in
        emit r
          (if Spell.can_cast b.Battle.hero s then Layout.rgb 70 120 200
           else Layout.rgb 50 54 66)
      end)
    hero_spells;
  (* The enemy's rows are the same pads on the other side, in a neutral ground:
     the port does not model the AI's hand, so they are a list to read rather
     than buttons to press. *)
  Array.iter
    (fun (r : Layout.rect) -> emit r (Layout.rgb 34 36 46))
    (Battle_layout.spell_rows Battle_layout.Foe);
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
  (* The cell under the mouse, faintly, whenever the mouse is on the board. *)
  (match (ui ()).hover with
  | None -> ()
  | Some (hx, hy) ->
      let r = Layout.cell_rect lay hx hy in
      emit
        { Layout.x = r.Layout.x + 2; y = r.Layout.y + 2; w = r.Layout.w - 4;
          h = r.Layout.h - 4 }
        (Layout.rgba 240 210 90 36));
  (* The open aim question lights the shape the spell reads - the whole column,
     the whole row, or the one cell - under the mouse. Every cell is a valid
     target (port.human_aim_click), so the shape is the highlight and there is
     nothing to filter; the same glow the pending swap uses. *)
  if (ui ()).aim_shape <> 0 then
    (match (ui ()).hover with
    | None -> ()
    | Some (hx, hy) ->
        List.iter
          (fun (x, y) ->
            let r = Layout.cell_rect lay x y in
            if not (Skin.draw (ui ()).skin runs frame_selection ~place:r) then
              emit
                { Layout.x = r.Layout.x + 4; y = r.Layout.y + 4;
                  w = r.Layout.w - 8; h = r.Layout.h - 8 }
                (Layout.rgba 255 255 255 80))
          (Layout.aim_cells lay ~shape:(ui ()).aim_shape (hx, hy)));
  (* The turn counters, in the game's own timer furniture: a background either
     side of the top panel. There is no countdown in a turn-based battle, so what
     is shown is how many turns have gone. *)
  draw_timer runs;
  (* Spell effects go in after the gems and before the text, so a sparkle is over the
     board and under the numbers it belongs to. *)
  draw_fx runs;
  (* Text goes in last, on top: the HUD, then the float messages over everything. *)
  let runs = !runs @ draw_hud gl hero_spells in
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
  (* The turn already expired: stop waiting and hand the caller a no-click, so
     the open question declines rather than re-asking against a dead clock. *)
  if !timed_out then (-1, -1)
  else begin
  (* The animation clock and the float-message clock are advanced together, and the
     redraw happens when either has something new to show. While a cascade is
     animating this is the only thing running, so it is also the frame loop: the
     delay is what paces it.

     Tying the two clocks together is deliberate rather than tidy. They are both
     presentation time, they both need to advance together or a message outlives
     the pop it belongs to, and keeping one idle delta avoids the temptation to
     advance them separately and get that wrong. [advance_clock] feeds the turn
     clock on the same delta, so the Time Limit counts down against the same
     wall time the messages age by. *)
  let anim_changed = Anim.advance (ui ()).anim frame_seconds in
  (* The effects carry their own clock for the same reason the cascade does, and are
     advanced on the same delta: an effect that runs at a different rate from the
     gems popping around it reads as two systems rather than one. *)
  let fx_changed = Fx.advance (ui ()).fx frame_seconds in
  let messages_changed = advance_clock frame_seconds in
  (* The turn clock: a human who outstays the Time Limit loses the turn - the
     original checks the deadline every frame the screen draws (FUN_0040F7D0)
     and force-ends the turn when it passes (FUN_00415800). Only ever reached
     while a question is open, which is the only time the human is deciding. *)
  if
    (match (ui ()).b with
    | Some bd when Battle.clock_expired bd -> true
    | _ -> false)
  then begin
    fire_timeout ();
    draw ();  (* the red float is up before the caller sees the decline *)
    (-1, -1)
  end
  else begin
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
    else if t = E.mouse_motion then begin
      (* Hover is presentation only: the cell under the mouse drives the aim
         highlight and the faint ring, and a change repaints even when the battle
         clocks are idle - the battle is paused inside a question, so nothing else
         would. *)
      let cell =
        Layout.hit (ui ()).layout (E.get ev E.mouse_motion_x)
          (E.get ev E.mouse_motion_y)
      in
      if cell <> (ui ()).hover then begin
        (ui ()).hover <- cell;
        draw ()
      end;
      wait_click ()
    end
    else wait_click ()
  end
  else begin
    Tsdl.Sdl.delay (Int32.of_int (int_of_float (frame_seconds *. 1000.)));
    wait_click ()
  end
  end
  end

let choose_aim (_s : Spell.spell) : Board.position option = !cast_aim

let choose_spell spells : Spell.spell option =
  (* Which rows are live is the engine's own affordability test, [Spell.can_cast]
     - the same one the AI path uses - asked per row rather than as a count of a
     filtered list. The two used to be separate, and a list filtered front-first
     made the row you clicked and the spell you got disagree whenever the first
     spell was the unaffordable one. *)
  let hero = (battle ()).Battle.hero in
  let live i = i < List.length spells && Spell.can_cast hero (List.nth spells i) in
  let bg = bar () in
  Printf.printf "\n  your turn - click a row to cast, or click the board to\n\
                 \  make a match without casting:\n";
  List.iteri
    (fun i (s : Spell.spell) ->
      Printf.printf "    %d) %s%s\n" (i + 1) s.Spell.id
        (if live i then "" else "  (not enough mana)"))
    spells;
  if not (List.exists live (List.init (List.length spells) Fun.id)) then
    print_string "    (nothing affordable - just make a match)\n";
  flush stdout;
  let rec ask () =
    let mx, my = wait_click () in
    if !timed_out then None
    else match Input.in_spell_prompt bg ~live mx my with
    | Input.Cast i when live i ->
        let s : Spell.spell = List.nth spells i in
        (* The button's own click, before the spell's sound. Both are real tags:
           `snd_buttup` is the button, and the spell sound follows from the observer
           when the battle emits the cast. *)
        ignore (Audio.play (ui ()).audio "snd_buttup");
        if s.Spell.input_type = 0 then begin
          cast_aim := None;
          Printf.printf "  cast %s\n" s.Spell.id;
          flush stdout;
          Some s
        end
        else begin
          (* The spell wants a cell. The three input kinds are all answered by
             one: column spells read x, row spells read y, grid spells both, so
             the prompt names the kind and any board cell will do. *)
          let what =
            match s.Spell.input_type with
            | 1 -> "column"
            | 2 -> "row"
            | _ -> "cell"
          in
          Printf.printf
            "  cast %s - click a %s (or a spell row to cancel)\n" s.Spell.id
            what;
          flush stdout;
          (* The highlight is live for exactly as long as the question is open. *)
          (ui ()).aim_shape <- s.Spell.input_type;
          let rec target () =
            let mx, my = wait_click () in
            if !timed_out then None
            else match Input.in_target_prompt bg (layout ()) mx my with
            | Input.Aim (x, y) ->
                (ui ()).aim_shape <- 0;
                cast_aim := Some { Board.x = x; y = y };
                Printf.printf "  cast %s at (%d,%d)\n" s.Spell.id x y;
                flush stdout;
                Some s
            | Input.Cancel ->
                (ui ()).aim_shape <- 0;
                Printf.printf "  cast cancelled\n";
                flush stdout;
                ask ()
            (* A click that answered nothing - off the board and off the bar -
               asks again rather than dropping the player out of aiming with the
               spell already picked. The remaining variants cannot come out of
               this prompt; they are listed so a new one fails loudly here. *)
            | Input.Miss | Input.Cast _ | Input.Decline | Input.First_cell _
            | Input.Swap _ | Input.No_match | Input.Pass ->
                target ()
          in
          target ()
        end
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
    if !timed_out then None
    else match Input.in_swap_prompt bg lay ~first ~valid mx my with
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
       the player on an unhandled click - and so are the aiming variants, which
       belong to a different question entirely. *)
    | Input.Cast _ | Input.Decline | Input.Aim _ | Input.Cancel -> ask ()
  in
  ask ()

(** A spell asked for an effect on one grid cell.

    The cell comes from the spell body - the game gets it there too - so this does
    not work out where the sparkle went, it is told. The constant names the effect,
    through the same table `lib/spell_fx.ml` was transcribed from, and the caster's
    name says whose side of the board to aim from.

    Aimed at the middle of the cell rather than its top-left corner, because an
    effect's own rectangle is centred on its aim point: `dest_x` is negative half
    its width, so a point at the corner would push the effect down and right by
    half a sprite. *)
let on_grid_fx (g : Battle.grid_fx) =
  incr grid_fx_played;
  let lay = layout () in
  let cell = Layout.cell_rect lay g.Battle.grid_fx_cell.Board.x g.Battle.grid_fx_cell.Board.y in
  let at = { Fx.x = float_of_int (cell.Layout.x + (cell.Layout.w / 2));
             y = float_of_int (cell.Layout.y + (cell.Layout.h / 2)) } in
  match Spell_fx.asset_of g.Battle.grid_fx_effect with
  | None -> ()
  | Some asset -> ignore (Fx.play (ui ()).fx asset ~at)

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
  (* A new turn: clear the timeout latch and re-seed the tick tracker so the
     turn's first frame does not read as a rollover - the deadline was armed
     just before this event, so the remaining is the fresh delay. *)
  (match e with
  | Battle.TurnStart _ ->
      timed_out := false;
      clock_last_secs := Battle.clock_secs_of_ms (Battle.clock_remaining_ms b)
  | _ -> ());
  (* A cast is the one event whose sound needs more than the event: it depends on
     what the spell does, and the event carries only its id. So the spell is looked
     up by name here, against the fight's own roster - a campaign fight brings
     spells the demo list never had. *)
  let spell =
    match e with
    | Battle.SpellCast (_, id) ->
        List.find_opt (fun (s : Spell.spell) -> s.Spell.id = id) b.Battle.hero_spells
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
     first demo screenshot showed. [advance_clock] also feeds the turn clock and
     runs the snd_tick rollover, so the countdown and its tick age with the same
     delta the float messages do. *)
  let dt = float_of_int pause_ms /. 1000.0 in
  ignore (advance_clock dt);
  if pause_ms > 0 then begin
    draw ();
    Tsdl.Sdl.delay (Int32.of_int pause_ms)
  end

(* ------------------------------------------------------------ public API -- *)

(** Load the screen's art over the host's GL context: the gem sheet, the three
    decoration sheets, the fonts (HUD, the five named faces plus the seven message
    colours), the six particle textures and the mixer. A missing piece costs what
    it carries and nothing else - a checkout without the art still plays.

    Called once per process; the result is the module's one screen, and [hooks]
    and [run] reach it through the slot. The host owns the window and the frame
    loop outside a fight. *)
let create ~(gl : Gl.context) : t =
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
  let lay =
    Layout.create ~cell ~cols:Board.default_width ~rows:Board.default_height
      ~window_w ~window_h ~reserve_top:(Skin.top_inset ())
      ~reserve_bottom:bar_h
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
  let t =
    { gl;
      gem_sheet;
      b = None;
      layout = lay;
      first_cell = None;
      hover = None;
      aim_shape = 0;
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
      (* Three sheets carry the frame: the backdrop the border is cut out of,
         the battle sheet the selection glow and the missed-turn badge live on,
         and the gems-grid sheet the two turn plates are cut from - those two
         are `img_ltimebg` / `img_rtimebg`, whose registry rows name
         `bmp_skin_gemsgrid`, which is why the plates used to draw nowhere at
         all. The gems sheet is loaded twice (the gem sprites are its other
         consumer); a 512x512 texture is cheap and one code path is not. *)
      skin =
        Skin.create ~gl
          ~sheets:[ "bmp_skin_backdrop"; "bmp_skin_battlemisc";
                    "bmp_skin_gemsgrid" ] }
  in
  u := Some t;
  t

(** The human's three choices, for [Battle.rules.player].

    A campaign fight built with this in its rules is one the player plays: the
    engine asks for a spell, an aim and a swap through these, and each pumps SDL
    events on the screen [create] built. [None] in the rules is the auto-AI on
    both sides - the headless path. *)
let hooks () : Battle.player =
  { Battle.choose_spell; choose_aim; choose_swap }

(** Play one fight to completion on the screen and return it finished.

    The battle must be one the campaign opened ([Campaign.open_battle] and the
    open/settle splits that ride it) with [hooks] in its rules; the observers are
    attached here, the only point at which the battle exists to hand them. The
    per-fight presentation state resets first, so a second fight in the same
    process starts on a clean board rather than the last one's hover. *)
let run (b : Battle.battle) : Battle.battle =
  let t = ui () in
  t.b <- Some b;
  t.first_cell <- None;
  t.hover <- None;
  t.aim_shape <- 0;
  cast_aim := None;
  now_seconds := 0.0;
  drained_frames := 0;
  grid_fx_played := 0;
  timed_out := false;
  clock_last_secs := 0;
  b.Battle.clock_now_ms <- 0;
  b.Battle.clock_deadline_ms <- None;
  (* A hosted fight is always paced: the cascade is watched, not settled and
     redrawn. `--demo` and `--shot` are the only runs that skip the block, and
     neither goes through here. *)
  paced := true;
  b.Battle.on_event <- Some (on_battle_event ~pause_ms:90);
  b.Battle.on_step <- Some on_battle_step;
  b.Battle.on_grid_fx <- Some on_grid_fx;
  Battle.run b

(* -------------------------------------------------------------------- main -- *)

(** The standalone front this module was extracted from: [pq_play_gfx]'s whole
    argument line, unchanged. It builds its own window and demo battle rather
    than hosting one, which is what makes `--demo`, `--shot` and `--pace`
    possible - they want a settled board or a named instant, not a paced replay
    with a player in it. *)
let standalone () =
  let args = Array.to_list Sys.argv in
  let seed = ref 7 and diff = ref 2 and tl = ref 0 and shot = ref ""
  and demo_turns = ref 0 in
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
    | "--timelimit" :: n :: r ->
        tl := int_of_string n;
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
  Printf.printf "renderer: %s\n  GL: %s\n" (Gl.renderer_name ()) (Gl.gl_version ());
  flush stdout;
  let t = create ~gl in
  (* `--demo N` plays N turns with nobody at the keyboard before anything is
     drawn. It exists because `--shot` on its own photographs the board before the
     battle has done anything, which cannot show damage numbers, cascades or any
     other event-driven thing - and "the float text renders" is not a claim worth
     making on the strength of a screenshot of an empty board. *)
  let rules =
    { Battle.default_rules with
      difficulty = !diff;
      time_limit = !tl;
      player = (if !demo_turns > 0 then None
                else Some { Battle.choose_spell; choose_aim; choose_swap }) }
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
  b.Battle.on_grid_fx <- Some on_grid_fx;
  paced := (!demo_turns = 0 && !shot = "") || !pace;
  t.b <- Some b;
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
    | Some tstop ->
        let anim = t.anim in
        let fx = t.fx in
        let stop = Anim.now anim +. tstop in
        while Anim.now anim < stop && (ignore (Anim.advance anim 0.016); true) do
          ignore (Fx.advance fx 0.016)
        done
    | None ->
        let anim = t.anim in
        let fx = t.fx in
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
      "  demo: %d turns, %d events, %d messages live, %d sounds started, %d animation frames, %d effects, %d of them on a grid cell\n"
      b.Battle.turns_elapsed
      (List.length (Battle.log_of b))
      (Float_text.count t.float_text)
      t.audio.Audio.played
      !drained_frames
      (Fx.played t.fx)
      !grid_fx_played;
    flush stdout
  end;
  (* `--pace` is a smoke run, not a game: the turns are played and animated and then
     the process ends. Without this it would fall through into [Battle.run] and sit
     there waiting for clicks that nothing is going to send. *)
  if !pace then begin
    Audio.destroy t.audio;
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
    Audio.destroy t.audio;
    Gl.destroy gl;
    exit 0
  end;
  Printf.printf "  cell %dpx, board at (%d,%d)\n" cell t.layout.Layout.origin_x
    t.layout.Layout.origin_y;
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
  Audio.destroy t.audio;
  Gl.destroy gl
