(** Drawing text with the game's own bitmap fonts.

    Each face is one atlas texture, and each glyph is one textured quad through
    [Gl]'s batcher - so a line of text is a single run and a screen full of text
    is one upload. There is no font pipeline here because there does not need to
    be: the atlas and the metrics are both in the game's own assets, which is why
    this project renders text rather than loading a TTF. Nothing in this module
    needs SDL_ttf, and nothing links it.

    The one thing that {e is} ours is the pen movement between glyphs; see
    [Font_layout] for what the engine does and why the two may disagree.

    ## Colour is the font's, not the caller's

    Each of the thirty-two named fonts carries an RGB colour in
    [<Language>/Font.xml], and that is where the original's coloured numbers come
    from: [font_xp] is purple, [font_gold] orange, and the seven [font_msg_*]
    styles are the float-message palette. A caller wanting a different colour
    passes one, but the default is the font's own - which is the whole point of
    having thirty-two of them.

    Bytes are stored B, G, R, A in the engine's font record ([FUN_004c9950] reads
    +0x28..+0x2b in that order), so that ordering is worth stating before someone
    "fixes" it. *)

open Puzzle_quest_lib

(** One loaded face: its atlas texture. Metrics come from the caller's style,
    because a style names a face and several styles share one. *)
type face = { texture : Gl.texture; tex_w : int; tex_h : int }

type t = (string, face) Hashtbl.t

(** Where the atlases were extracted to, overridable for a test or a packager. *)
let face_dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p -> Filename.concat p "Fonts"
  | _ -> "assets/gfx/Fonts"

let face_path (name : string) : string = Filename.concat (face_dir ()) (name ^ ".png")

(** Load the atlases the given styles need, once each.

    Ten faces are shipped and a battle screen needs two or three, so this does not
    read all of them: a font that is never drawn should not cost a decode.

    Returns [None] only if nothing at all could be loaded, which is the caller's
    cue to carry on without text. A missing atlas is otherwise not fatal. *)
let create ~(styles : Font_layout.metrics list) : t option =
  let t = Hashtbl.create 8 in
  let wanted =
    List.fold_left
      (fun acc (m : Font_layout.metrics) ->
        let n = m.Font_layout.face.Font_data.name in
        if List.mem n acc then acc else n :: acc)
      [] styles
  in
  List.iter
    (fun (name : string) ->
      let path = face_path name in
      if Sys.file_exists path then
        try
          let px, w, h = Png.load_rgba path in
          Hashtbl.replace t name
            { texture = Gl.texture_of_bigarray ~w ~h px; tex_w = w; tex_h = h }
        with e ->
          Printf.printf "  font atlas %s failed to load: %s\n" path
            (Printexc.to_string e)
      else Printf.printf "  no atlas for face %s (%s)\n" name path)
    wanted;
  if Hashtbl.length t = 0 then None else Some t

let face_of (t : t) (m : Font_layout.metrics) : face option =
  Hashtbl.find_opt t m.Font_layout.face.Font_data.name

(** The font's own colour, which is the default for text drawn in it. *)
let colour_of (m : Font_layout.metrics) : Layout.colour =
  Layout.rgba m.Font_layout.style.Font_data.r m.Font_layout.style.Font_data.g
    m.Font_layout.style.Font_data.b m.Font_layout.style.Font_data.a

(** Emit one line of text, as a single batched run.

    Returns the runs to hand to [Gl.submit]; empty when the face has no atlas, or
    when the string has nothing drawable in it.

    Glyphs are drawn at the rectangle the atlas gives them rather than at a
    computed baseline, because the atlas already has each glyph positioned within
    its cell - which is why the style's [yoffset] is applied once to the line
    rather than per glyph.

    One run for the whole line matters: the alternative is a run per glyph, and
    [Gl.submit] sets the texture and colour uniforms immediately before each
    draw, so a screen of text as a hundred runs is a hundred redundant uniform
    sets for no benefit. *)
let draw_into (win : Gl.context) (t : t) (m : Font_layout.metrics) ?colour (s : string)
    ~(x : int) ~(y : int) : Gl.run list =
  match face_of t m with
  | None -> []
  | Some f ->
      let col = match colour with Some c -> c | None -> colour_of m in
      let y = y + m.Font_layout.style.Font_data.yoffset in
      let placed = Font_layout.place_line m s y in
      let first = ref None and count = ref 0 in
      List.iter
        (fun (p : Font_layout.placed) ->
          let g = p.Font_layout.glyph in
          (* A code the face has no rectangle for cannot be sampled. The original
             substitutes the face's fallback character; we do not know its value,
             so nothing is drawn rather than something wrong. *)
          if Font_layout.has_glyph m p.Font_layout.code then begin
            let dst =
              { Layout.x = x + p.Font_layout.x; y = p.Font_layout.y;
                w = g.Font_data.w; h = g.Font_data.h }
            in
            let uv =
              Some
                { Layout.x = g.Font_data.x; y = g.Font_data.y; w = g.Font_data.w;
                  h = g.Font_data.h }
            in
            let q = Gl.push_quad ~tex_size:(f.tex_w, f.tex_h) win dst uv col in
            (match !first with None -> first := Some q | Some _ -> ());
            incr count
          end)
        placed;
      (match !first with
      | None -> []
      | Some first -> [ { Gl.first; count = !count * 6; tex = Some f.texture; colour = col } ])

(** Draw several lines, stacked by the style's line height. *)
let draw_lines (win : Gl.context) (t : t) (m : Font_layout.metrics) ?colour
    (lines : string list) ~(x : int) ~(y : int) : Gl.run list =
  let lh = Font_layout.line_height m in
  List.mapi
    (fun i line -> draw_into win t m ?colour line ~x ~y:(y + (i * lh)))
    lines
  |> List.concat

(** Draw one line, left edge at [x]. *)
let draw (win : Gl.context) (t : t) (m : Font_layout.metrics) ?colour (s : string) ~(x : int)
    ~(y : int) : Gl.run list =
  draw_into win t m ?colour s ~x ~y

(** Centre one line on [cx]. *)
let draw_centred (win : Gl.context) (t : t) (m : Font_layout.metrics) ?colour (s : string)
    ~(cx : int) ~(y : int) : Gl.run list =
  draw win t m ?colour s ~x:(cx - (Font_layout.measure m s / 2)) ~y

(** Centre one line on [cx] at a baseline, rather than a top edge.

    The engine positions text by baseline - [FontData] records a [baseline] per
    style - so a HUD that wants text sitting {e on} a line needs this rather than
    [draw_centred], which takes the top of the line. *)
let draw_baseline (win : Gl.context) (t : t) (m : Font_layout.metrics) ?colour (s : string)
    ~(cx : int) ~(baseline_y : int) : Gl.run list =
  draw win t m ?colour s ~x:(cx - (Font_layout.measure m s / 2))
    ~y:(baseline_y - m.Font_layout.style.Font_data.baseline)

let destroy (t : t) = Hashtbl.iter (fun _ (f : face) -> Gl.destroy_texture f.texture) t