(** Laying out text: where each glyph goes, how wide a string is, and where a
    floating message lands.

    No SDL and no OpenGL, for the reason [Layout] gives - the arithmetic is the
    part worth testing, and it is the part that can be tested without a window.
    The glyph {e rectangles} come from [Font_data]; this module decides what to do
    with them.

    ## The advance is an inference, and it is the weakest thing here

    A glyph table gives each character a rectangle and two more numbers,
    [leading] and [trailing]. The obvious reading is that a character occupies
    [leading + width + trailing] pixels. **That is wrong**, and it is worth
    recording why, because it is the reading the attribute names invite:

    - **[leading] + [trailing] equals [width]**, for essentially every glyph in
      every face. Across the ten faces, [width - leading - trailing] is 0 or 1 for
      90-99% of glyphs and never exceeds 3. They are two halves of the ink box, not
      bearings that add to it, so summing them double-counts the glyph and gives
      roughly twice the tracking the original has.
    - **The atlas packs each glyph's ink edge to edge.** Measured off
      [Assets/Fonts/System.png], cells sit one pixel apart and a glyph's ink fills
      its cell completely - there is no left bearing baked into the sheet to be
      compensated for. So [leading] is not an ink offset either: the ink of code
      33 starts one pixel into a cell whose [leading] is 2.

    What is left is that **[width] is the advance and the ink is drawn at the
    pen**, which is what this module does. It renders at the spacing the original
    does, which is the test that settled it.

    What the engine does is in [FUN_004c7650], and it is still not fully known:

    ```
      first character :  glyph+0x1c + glyph+0x18
      middle characters:         glyph+0x18
      last character  :  glyph+0x14 - glyph+0x1c
    ```

    [FUN_004c9030] settles one field: a string's height is read straight out of the
    font record rather than computed, and it is the same number as
    [FontData/@height]. The glyph rectangle is [x, y, w] at +0x10, +0x12, +0x14 -
    [FUN_004c75e0] treats all three being zero as the "no such glyph" sentinel.
    So +0x18 is the advance. What +0x1c is, is not settled: for a single 'A' in
    [Small] the first-character and last-character branches disagree, 25 against
    10, and only one of them can be right. It is not the XML's [leading] or
    [trailing] either, since those two already account for the whole ink box.

    Note that the engine does not read these XML files at runtime, so this cannot
    be settled by finding the parser. The strings "leading", "trailing" and
    "FontData" are in the binary as UTF-16 at 0x0012bc60 with no reference to them
    from anywhere - they are an asset-build tool's vocabulary, compiled in and
    unused. The runtime glyph records are pre-baked.

    ## Everything else here is ported

    [place_message] is a transcription of the float-text positioning in
    [Engine_ADD_TEXT_MESSAGE_415120], which centres the text on the box it was
    given and then keeps it on screen. *)

open Puzzle_quest_lib

type metrics = {
  style : Font_data.style;
  face : Font_data.face;
}

(** The face a style names, or [None] if the tables disagree - which would mean
    the generated data is stale, so it is worth being able to say so. *)
let metrics_of_style (s : Font_data.style) : metrics option =
  match Font_data.face_of_name s.Font_data.face with
  | Some f -> Some { style = s; face = f }
  | None -> None

let metrics_of_tag (tag : string) : metrics option =
  match Font_data.style_of_tag tag with None -> None | Some s -> metrics_of_style s

let line_height (m : metrics) = Font_data.line_height m.style

(** The baseline, in the same units as the glyph rectangles.

    [FontData] records each glyph's rectangle at whatever row it happens to sit
    in the atlas, and the style's [baseline] says where the text's baseline is
    within the line. Glyph rectangles are already positioned for drawing, so this
    is only used by the callers that need to reason about a line rather than draw
    one. *)
let baseline (m : metrics) = m.style.Font_data.baseline

(** How far the pen moves after drawing [code], in pixels.

    Normally the glyph's ink width, because [leading] and [trailing] together
    already measure it (see the note at the top). The exception is a cell with no
    ink, and the space is the one in every face: its rectangle is 1px wide because
    there is nothing to draw, so its width says nothing, while its two bearings
    still add up to a real space - 7px in [System], 5 in [Small].

    So the advance is the larger of the two. For an inked glyph that is the ink
    width; for a blank one it is the cell the table says it has. Without the
    second case, [measure "you 60"] comes out as "you60" - which is exactly what
    the first render of the HUD did.

    The rule's cost, stated rather than hidden: 127 of the 1,948 glyphs have
    bearings exceeding their ink by more than 3px, and all but one are in the
    heading and script faces - WC_Heading, WC_Quest, WC_Button and the three script
    fonts - where the metrics genuinely differ. The three faces the battle screen
    draws, System, Small and WC_Message, have one offender between them. Those 127
    get an advance larger than their ink, which for a few of the Greek slots in
    WC_Heading means four times it; if a script or heading face is ever used for
    real text, those are the first advances to revisit. *)
let advance (m : metrics) (code : int) : int =
  match Font_data.glyph_of_code m.face code with
  | None -> 0
  | Some g -> max g.Font_data.w (g.Font_data.leading + g.Font_data.trailing)

(** Where a glyph's ink starts, relative to the pen.

    Zero, and deliberately so: the atlas packs each glyph's cell edge to edge with
    one pixel between cells, so there is no baked-in offset to undo. A face that
    did carry one would set this from its [leading] and nothing else would change. *)
let bearing (_m : metrics) (_code : int) : int = 0

(** One character placed: where its ink goes, and where the pen goes next. *)
type placed = {
  code : int;
  glyph : Font_data.glyph;
  x : int;  (** left edge of the ink, relative to the string's left edge *)
  y : int;  (** top edge of the ink, relative to the line's top edge *)
  pen : int;  (** pen position after this character *)
}

(** The codes of [s], with two substitutions the engine makes on the way in.

    Both are read out of [FUN_004c7650] rather than invented:

    - **0xa0 becomes 0x20.** A non-breaking space is drawn as a plain space.
    - **A code the face does not have becomes the face's own fallback**, which
      the engine keeps at +0x44 on the font record. We do not know its value, so
      [substitute_missing] leaves the code alone and the caller draws nothing for
      it; see [missing_is_blank].

    The string is UTF-8, but a glyph table is indexed by Unicode code point, so
    it is decoded here rather than treated as bytes. *)
let codes (s : string) : int list =
  let out = ref [] in
  let n = String.length s in
  let i = ref 0 in
  while !i < n do
    let c = Char.code s.[!i] in
    let len, code =
      if c land 0x80 = 0 then (1, c)
      else if c land 0xE0 = 0xC0 then (2, ((c land 0x1F) lsl 6) lor (Char.code s.[!i + 1] land 0x3F))
      else if c land 0xF0 = 0xE0 then
        ( 3,
          ((c land 0x0F) lsl 12)
          lor ((Char.code s.[!i + 1] land 0x3F) lsl 6)
          lor (Char.code s.[!i + 2] land 0x3F) )
      else (1, c)
    in
    out := code :: !out;
    i := !i + len
  done;
  List.rev !out

let substitute_nbsp code = if code = 0xa0 then 0x20 else code

(** Lay out one line. [y] is the top of the line; glyphs keep whatever vertical
    position the atlas gives them. *)
let place_line (m : metrics) (s : string) (y : int) : placed list =
  let rec go pen acc = function
    | [] -> List.rev acc
    | code :: rest -> (
        match Font_data.glyph_of_code m.face code with
        | None -> go pen acc rest
        | Some g ->
            let x = pen + bearing m code in
            let pen' = pen + advance m code in
            go pen' ({ code; glyph = g; x; y; pen = pen' } :: acc) rest)
  in
  go 0 [] (List.map substitute_nbsp (codes s))

(** Lay out several lines, stacked by the style's line height. *)
let place (m : metrics) (lines : string list) : placed list =
  let lh = line_height m in
  let out = ref [] in
  List.iteri
    (fun i line ->
      out := !out @ place_line m line (i * lh))
    lines;
  !out

(** The ink width of one line: the sum of its characters' advances.

    With [advance] being the ink width there is no trailing to trim, so this is a
    plain sum. See the note at the top for why it does not claim to be
    [FUN_004c7650]. *)
let measure (m : metrics) (s : string) : int =
  List.fold_left (fun acc c -> acc + advance m c) 0 (List.map substitute_nbsp (codes s))

(** The height of one line of text.

    Recovered, not inferred: [FUN_004c9030] returns the font record's stored
    height rather than measuring anything. *)
let measure_height (m : metrics) (_s : string) : int = m.face.Font_data.height

(** Whether a face has something to draw for [code].

    The archive's own test for "no glyph here" is an all-zero rectangle -
    [FUN_004c75e0] checks width, x and y together - so that is the test used here,
    along with being outside the face's code range. Both mean the same thing to a
    renderer: there is no rectangle to sample.

    Note that the space is {e not} one of them. It is a real glyph with a real
    1px rectangle, because it is a real character with no ink - and no glyph in any
    of the ten faces uses the all-zero sentinel, so "outside the code range" is in
    practice the only way to be missing. *)
let has_glyph (m : metrics) (code : int) : bool =
  match Font_data.glyph_of_code m.face code with
  | None -> false
  | Some g -> not (g.Font_data.w = 0 && g.Font_data.x = 0 && g.Font_data.y = 0)

(** Greedy word wrap to [max_w] pixels, on spaces.

    The engine has a wrapped-text path - [Tsdl_ttf.render_text_blended_wrapped]
    is the SDL one, and the WET engine's own is reached through the same font
    record - but it has not been decompiled, so this is a plain greedy wrap and is
    labelled as our own rather than as a port. *)
let wrap (m : metrics) (max_w : int) (s : string) : string list =
  let words = String.split_on_char ' ' s in
  let rec go acc line = function
    | [] -> List.rev (String.trim line :: acc)
    | w :: rest ->
        let candidate = if line = "" then w else line ^ " " ^ w in
        if measure m candidate <= max_w || line = "" then go acc candidate rest
        else go (String.trim line :: acc) w rest
  in
  if String.trim s = "" then [ "" ] else go [] "" words

(* ------------------------------------------------------- float messages --- *)

(** The 20px margin the engine keeps between a floating message and the edge of
    the screen. Hardcoded as [0x14] in [Engine_ADD_TEXT_MESSAGE_415120]. *)
let screen_margin = 20

type box = { x0 : int; y0 : int; x1 : int; y1 : int }

(** Where a floating message goes.

    A transcription of the positioning in [Engine_ADD_TEXT_MESSAGE_415120], with
    the two width and height calls resolved to [measure] and [measure_height]:

    1. **Anchor on the box's minimum corner.** [x = min(x0, x1) - width / 2], and
       likewise for y. It is worth being precise about this, because "centre it on
       the box" is the obvious description and it is the wrong one: the original
       takes the *smaller* of each pair of corners and ignores the larger one
       except to establish which is smaller. A box from (300,100) to (500,100)
       therefore anchors at x=300, not at its midpoint of 400, and the message
       lands 100px left of where "centre it on the box" would put it. A test
       asserting the midpoint reading failed, which is how this got written down.

       The division is a truncating shift, so an odd width loses half a pixel -
       [width / 2], not a rounding call. The original does too.
    2. **Keep it on screen.** If the text would reach within [screen_margin] of the
       right edge it is shifted left by the overhang, so it ends exactly on the
       margin. If it starts left of the margin it is shifted right to the margin.
       The near-edge test {e overrides} the far-edge one, exactly as in the
       original, where the second [if] assigns to the same variable the first did.
    3. The vertical rule tests [y] against the bottom margin but *not* [y + height]
       against it, while the horizontal rule tests [x + width]. That asymmetry is in
       the decompilation and is reproduced rather than tidied - and it has a visible
       consequence: a message whose bottom edge runs off the screen is not pulled
       back, because the rule never looks at its bottom edge.

    The original then writes the shift into four fields of the message's rectangle
    and copies two of them over the other two, which is how one text object ends
    up with a consistent box. That copying is a property of its data structure
    rather than of the layout, so this returns the resolved position and the box
    the caller should draw into. *)
let place_message ~screen_w ~screen_h ~text_w ~text_h (b : box) : box =
  let x = min b.x0 b.x1 - (text_w / 2) in
  let y = min b.y0 b.y1 - (text_h / 2) in
  let dx = ref 0 and dy = ref 0 in
  if screen_w - screen_margin <= x + text_w then
    dx := (screen_w - x) - text_w - screen_margin;
  if screen_h - screen_margin <= y then dy := (screen_h - text_h) - y - screen_margin;
  if x < screen_margin then dx := screen_margin - x;
  if y < screen_margin then dy := screen_margin - y;
  { x0 = x + !dx; y0 = y + !dy; x1 = x + !dx + text_w; y1 = y + !dy + text_h }