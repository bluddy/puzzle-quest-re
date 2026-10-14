(** Laying out text: where each glyph goes, how wide a string is, and where a
    floating message lands.

    No SDL and no OpenGL, for the reason [Layout] gives - the arithmetic is the
    part worth testing, and it is the part that can be tested without a window.
    The glyph {e rectangles} come from [Font_data]; this module decides what to do
    with them.

    ## The glyph fields and the pen rule are recovered

    The engine reads each face's XML at runtime: [FUN_004c8700] composes the
    [".xml"] and [".png"] paths of a face name and calls [FUN_004c7f80], which
    walks the [FontData] and [Glyph] elements and writes the 32-byte glyph
    records - the raw XML attributes, with no arithmetic on them:

    ```
      +0x00 float  x / texture width   +0x10 word  x
      +0x04 float  y / texture height  +0x12 word  y
      +0x08 float  w / texture width   +0x14 word  width
      +0x0c float  h / texture height  +0x16 word  height
                                       +0x18 dword trailing
                                       +0x1c dword leading
    ```

    Both consumers then walk the string with the same three-branch rule -
    [FUN_004c7650] to measure, [FUN_004c7720] to draw:

    ```
      first character :  pen += leading + trailing,  ink at pen
      middle characters:  pen += trailing,            ink at pen - leading
      last character  :  pen += width - leading,     ink at pen - leading
    ```

    So [measure] is the pen after the last character, which is the right ink
    edge of the last glyph for a multi-character string; a single character
    takes the first branch and measures [leading + trailing], which need not
    equal its ink width ('A' in [Small] is 11 against 12). An earlier round
    read +0x18 as a full advance and got a "25 against 10" disagreement out of
    it; with the parser in view the values are 11 and 10, the single-character
    case unambiguously takes the first branch, and there is no disagreement.

    Two consequences the previous model did not have: consecutive glyphs
    overlap by their [leading] (one or two pixels in the HUD faces), and a
    trailing space contributes [width - leading] - which is negative, since a
    space's box is a 1px placeholder.

    The substitution chain is recovered too: U+00A0 becomes a plain space
    first, then a code the face cannot draw - out of range, or the
    all-zero-rectangle sentinel [FUN_004c75e0] tests - becomes the face's
    fallback character, kept at +0x44 on the font record. [FUN_004c7510]
    writes that field as 0x2a, which is ['*'].

    An earlier round concluded from a string scan that the engine does not
    read these XML files at all. It does: the scan looked for the RVA
    0x12bc60's bytes where the VA 0x52bc60's bytes were, and the parser's
    pushes of the latter are dense in [FUN_004c7f80].

    [FUN_004c9030] reads a string's height straight off the font record rather
    than measuring it, and it is the same number as [FontData/@height].

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

(** U+00A0 becomes a plain space, read out of [FUN_004c7650]. *)
let substitute_nbsp code = if code = 0xa0 then 0x20 else code

(** The fallback character the engine substitutes for a code a face cannot
    draw, recovered: [FUN_004c7510] writes 0x2a - ['*'] - into +0x44 on the
    font record, and both [FUN_004c7650] and [FUN_004c7720] read it back for
    any code out of the face's range or carrying the all-zero sentinel. All
    ten faces ship a glyph for it. *)
let fallback_code = 0x2a

(** The code a character is actually drawn and measured as.

    The engine's chain, in order: U+00A0 becomes a plain space; a space is
    taken as itself without a presence test; anything else the face cannot
    draw - out of [mincode]/[maxcode], or the all-zero-rectangle sentinel -
    becomes [fallback_code]. *)
let resolve_code (m : metrics) (code : int) : int =
  let code = substitute_nbsp code in
  if code = 0x20 then code
  else
    match Font_data.glyph_of_code m.face code with
    | Some g when not (g.Font_data.w = 0 && g.Font_data.x = 0 && g.Font_data.y = 0) -> code
    | _ -> fallback_code

(** How far the pen moves after drawing a glyph, from its position in the
    string - the rule is position-dependent, so there is no single per-code
    advance to expose. Recovered from [FUN_004c7650] and [FUN_004c7720],
    which run the same three branches. *)
let step_at (g : Font_data.glyph) ~(first : bool) ~(last : bool) : int =
  if first then g.Font_data.leading + g.Font_data.trailing
  else if last then g.Font_data.w - g.Font_data.leading
  else g.Font_data.trailing

(** Where a glyph's ink starts, relative to the pen.

    Zero for the string's first character; [leading] subtracted for every
    later one - [FUN_004c7720] subtracts the word at +0x1c before drawing,
    which the parser shows is the XML's [leading]. So consecutive glyphs
    overlap by that much, which is one or two pixels in the HUD faces. *)
let bearing (g : Font_data.glyph) ~(first : bool) : int = if first then 0 else g.Font_data.leading

(** One character placed: where its ink goes, and where the pen goes next. *)
type placed = {
  code : int;
  glyph : Font_data.glyph;
  x : int;  (** left edge of the ink, relative to the string's left edge *)
  y : int;  (** top edge of the ink, relative to the line's top edge *)
  pen : int;  (** pen position after this character *)
}

(** The codes of [s], decoded rather than walked as bytes: a glyph table is
    indexed by Unicode code point, so a multi-byte UTF-8 sequence is one code.

    The engine's substitutions (U+00A0, the fallback character) are applied
    per code by [resolve_code], not here. *)
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

(** Lay out one line. [y] is the top of the line; glyphs keep whatever vertical
    position the atlas gives them.

    A transcription of [FUN_004c7720]'s loop: codes go through [resolve_code],
    the first glyph's ink sits at the pen and every later one [leading] pixels
    left of it, and the pen advances by [step_at]. The placed [code] is the
    resolved one, because that is whose rectangle is being placed. *)
let place_line (m : metrics) (s : string) (y : int) : placed list =
  let chars = List.map (resolve_code m) (codes s) in
  let n = List.length chars in
  let rec go i pen acc = function
    | [] -> List.rev acc
    | code :: rest -> (
        match Font_data.glyph_of_code m.face code with
        | None -> go (i + 1) pen acc rest
        | Some g ->
            let x = pen - bearing g ~first:(i = 0) in
            let pen' = pen + step_at g ~first:(i = 0) ~last:(i = n - 1) in
            go (i + 1) pen' ({ code; glyph = g; x; y; pen = pen' } :: acc) rest)
  in
  go 0 0 [] chars

(** Lay out several lines, stacked by the style's line height. *)
let place (m : metrics) (lines : string list) : placed list =
  let lh = line_height m in
  let out = ref [] in
  List.iteri
    (fun i line ->
      out := !out @ place_line m line (i * lh))
    lines;
  !out

(** The width of one line: the pen position after its last character, which is
    [FUN_004c7650]'s return value.

    For a multi-character string that is the right ink edge of the last glyph,
    since each later glyph's ink starts [leading] short of the pen; for a
    single character it is [leading + trailing], the first branch, which is
    what the engine measures. An empty string is zero. *)
let measure (m : metrics) (s : string) : int =
  let chars = List.map (resolve_code m) (codes s) in
  let n = List.length chars in
  let rec go i pen = function
    | [] -> pen
    | code :: rest -> (
        match Font_data.glyph_of_code m.face code with
        | None -> go (i + 1) pen rest
        | Some g -> go (i + 1) (pen + step_at g ~first:(i = 0) ~last:(i = n - 1)) rest)
  in
  go 0 0 chars

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