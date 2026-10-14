(* Text layout: the pen rule, line placement, and the ported float-message positioning.

   [Pq_gfx.Font_layout] holds no SDL and no OpenGL, so all of this is arithmetic
   and all of it is testable without a window - which matters more here than
   anywhere else in the graphics front, because the pen rule is the one number
   every glyph position in the project depends on.

   The rule is recovered rather than inferred: [FUN_004c7f80] parses each face's
   XML at runtime into the glyph records (trailing at +0x18, leading at +0x1c,
   both raw attributes), and [FUN_004c7650] and [FUN_004c7720] consume them with
   the same three branches - first character [leading + trailing], middle
   [trailing], last [width - leading], with later glyphs' ink [leading] pixels
   left of the pen. These tests pin the rule against real [System] and [Small]
   numbers, including the places it is not the ink width: a single 'A' in
   [Small] measures 11 with an ink box of 12, and a trailing space is negative.

   [place_message] is a transcription rather than a guess, so its tests are the
   real specification of what the original does: centre on the box, then clamp to
   the screen with a 20px margin, with the near-edge rule overriding the far-edge
   one and the vertical rule testing the opposite edge from the horizontal one. *)

open Pq_gfx
open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let system = Option.get (Font_layout.metrics_of_tag "font_system")
let small = Option.get (Font_layout.metrics_of_tag "font_small")
let message = Option.get (Font_layout.metrics_of_tag "font_msg_white")

let box x0 y0 x1 y1 = { Font_layout.x0; y0; x1; y1 }

(* ------------------------------------------------------------- pen rule -- *)

let test_pen_rule () =
  (* The three branches, on real System numbers: 'n' is width 11, leading 2,
     trailing 9; 'a' is 10/2/8; 'b' is 11/2/9. *)
  let placed = Font_layout.place_line system "nab" 0 in
  check_int "three glyphs are placed" (List.length placed) 3;
  let n = List.nth placed 0 and a = List.nth placed 1 and b = List.nth placed 2 in
  check_int "the first glyph is at the origin" n.Font_layout.x 0;
  check_int "and advances by leading + trailing" n.Font_layout.pen 11;
  check_int "the middle glyph's ink is leading left of the pen" a.Font_layout.x 9;
  check_int "and advances by trailing alone" a.Font_layout.pen 19;
  check_int "the last glyph's ink is also leading left of the pen" b.Font_layout.x 17;
  check_int "and advances by width - leading" b.Font_layout.pen 28;
  (* The overlap the bearing produces: consecutive glyphs share their leading. *)
  check "glyphs overlap by the leading" (n.Font_layout.pen - a.Font_layout.x = 2);
  (* A single character takes the first branch even though it is also the last:
     in Small, 'A' is width 12, leading 2, trailing 9, so the branches would
     give 11 and 10 - and the engine's i==0 test runs first. This is the
     disagreement the old notes read as 25 against 10 on a misread field. *)
  check_int "a single Small 'A' measures its bearings" (Font_layout.measure small "A") 11;
  check "which is not its ink width"
    ((Option.get (Font_data.glyph_of_code small.Font_layout.face 65)).Font_data.w = 12)

let test_resolve () =
  (* The engine's substitution chain: U+00A0 becomes a space, and a code the
     face cannot draw becomes the fallback - '*', 0x2a, at +0x44 on the font
     record. *)
  check_int "U+00A0 resolves to a plain space" (Font_layout.resolve_code system 0xa0) 32;
  check_int "a code below the range becomes the fallback"
    (Font_layout.resolve_code system 31) Font_layout.fallback_code;
  check_int "the fallback is '*'" Font_layout.fallback_code 42;
  check_int "and it measures as itself" (Font_layout.measure system "\x1f")
    (Font_layout.measure system "*");
  (* A code the face has is left alone, sentinel test notwithstanding. *)
  check_int "a real code is unchanged" (Font_layout.resolve_code system 65) 65;
  check_int "the space is taken without a presence test"
    (Font_layout.resolve_code system 32) 32

let test_codes () =
  check "ASCII decodes to one code per byte" (Font_layout.codes "AB" = [ 65; 66 ]);
  (* The glyph tables are indexed by code point up to 8482, so a multi-byte UTF-8
     string has to be decoded rather than walked as bytes. *)
  check "two-byte UTF-8 is one code"
    (Font_layout.codes "\xc3\xa9" = [ 0xe9 ]);
  check "three-byte UTF-8 is one code"
    (Font_layout.codes "\xe2\x82\xac" = [ 0x20ac ]);
  (* FUN_004c7650 substitutes a plain space for U+00A0 before measuring. *)
  check_int "a non-breaking space measures as a space"
    (Font_layout.measure system "\u{00a0}") (Font_layout.measure system " ");
  check "and is drawn as one"
    (Font_layout.codes "\u{00a0}" |> List.map Font_layout.substitute_nbsp = [ 32 ])

(* ---------------------------------------------------------------- measure -- *)

let test_measure () =
  check_int "an empty string is zero wide" (Font_layout.measure system "") 0;
  check_int "one character is the first branch" (Font_layout.measure system "n") 11;
  check_int "three characters are the three branches"
    (Font_layout.measure system "nab") 28;
  (* A trailing space takes the last branch, whose width - leading is negative
     for every face: the box is a 1px placeholder. The engine does it anyway. *)
  check_int "a trailing space goes negative" (Font_layout.measure system "n ") 10;
  (* Measure must agree with the rightmost edge of what place_line produces, or
     centring would be off by however much the two disagree. The first branch's
     leading + trailing is what breaks the equality for a single character, so
     this is a multi-character string - where measure is the last ink edge. *)
  let placed = Font_layout.place_line system "nab" 0 in
  let right =
    List.fold_left (fun acc (p : Font_layout.placed) -> max acc (p.Font_layout.x + p.Font_layout.glyph.Font_data.w)) 0 placed
  in
  check_int "measure agrees with the placed ink"
    (Font_layout.measure system "nab") right

let test_height () =
  (* Recovered, not inferred: FUN_004c9030 reads the font record's stored height,
     which is the same number as FontData/@height. *)
  check_int "a line is as tall as the face says"
    (Font_layout.measure_height system "anything")
    system.Font_layout.face.Font_data.height;
  check_int "and the face's height is FontData's"
    (Font_layout.measure_height message "x") 43;
  check "a line's height does not depend on its contents"
    (Font_layout.measure_height small "" = Font_layout.measure_height small "hello")

let test_has_glyph () =
  (* The engine's own test for "no glyph": an all-zero rectangle, or a code outside
     the face's range. The space is neither - it is a real character with no ink,
     which is a different thing and has a 1px rectangle. *)
  check "the space has a glyph, being a real character with no ink"
    (Font_layout.has_glyph system 32);
  check "a real glyph has one" (Font_layout.has_glyph system 65);
  check "a code below the range does not" (not (Font_layout.has_glyph system 31));
  check "a code above the range does not" (not (Font_layout.has_glyph system 8483))

(* -------------------------------------------------------------- placement -- *)

let test_place_line () =
  let placed = Font_layout.place_line system "nn" 0 in
  check_int "two glyphs are placed" (List.length placed) 2;
  let first = List.nth placed 0 and second = List.nth placed 1 in
  check_int "the first glyph is at the origin" first.Font_layout.x 0;
  (* Overlapping, not abutting: the second's ink starts [leading] pixels left of
     the pen the first left behind, which is the draw-side bearing. A gap or a
     flush abutment would both fail this. *)
  check_int "the second overlaps the first by its leading"
    second.Font_layout.x (first.Font_layout.pen - second.Font_layout.glyph.Font_data.leading);
  check_int "and the pair measures as the pen says" (Font_layout.measure system "nn")
    second.Font_layout.pen;
  (* The y passed in is the top of the line, and the atlas' own vertical placement
     is kept rather than recomputed from a baseline. *)
  let moved = Font_layout.place_line system "n" 40 in
  check_int "the line's y is the y it was given"
    (List.hd moved).Font_layout.y 40;
  check_int "and the glyph rect is carried through"
    (List.hd moved).Font_layout.glyph.Font_data.y
    (Option.get (Font_data.glyph_of_code system.Font_layout.face 110)).Font_data.y;
  (* A missing code is placed as the fallback, not skipped: the original draws
     '*' where the face has nothing, so the port places '*'s rectangle. *)
  let fb = Font_layout.place_line system "\x1f" 0 in
  check_int "a missing code still places one glyph" (List.length fb) 1;
  check_int "as the fallback's code" (List.hd fb).Font_layout.code 42;
  check_int "with the fallback's rectangle"
    (List.hd fb).Font_layout.glyph.Font_data.x
    (Option.get (Font_data.glyph_of_code system.Font_layout.face 42)).Font_data.x

let test_multi_line () =
  let lh = Font_layout.line_height system in
  check_int "lines stack by the line height" lh 16;
  let placed = Font_layout.place system [ "a"; "b" ] in
  let ys = List.map (fun (p : Font_layout.placed) -> p.Font_layout.y) placed in
  check "the second line is one line lower"
    (match ys with [ y1; y2 ] -> y2 = y1 + lh | _ -> false)

let test_wrap () =
  (* Greedy, on spaces, and ours rather than the engine's - the WET wrapped-text
     path has not been decompiled, so this is stated as our own rule rather than
     dressed up as a port. *)
  let one = Font_layout.wrap small 400 "alpha beta gamma" in
  check_int "short text is one line" (List.length one) 1;
  let many = Font_layout.wrap small 60 "alpha beta gamma delta" in
  check "long text wraps" (List.length many > 1);
  check "and no wrapped line exceeds the width"
    (List.for_all (fun l -> Font_layout.measure small l <= 60) many);
  (* A single word longer than the limit must still be emitted, or the text
     disappears rather than overflowing. *)
  let long_word = Font_layout.wrap small 10 "unbelievably" in
  check_int "an over-long word is kept whole" (List.length long_word) 1;
  check_int "and is not dropped" (Font_layout.measure small (List.hd long_word))
    (Font_layout.measure small "unbelievably")

(* ------------------------------------------------------- float messages --- *)

let test_message_anchoring () =
  (* The original anchors on the box's *smaller* corner, not its midpoint: it takes
     min(x0, x1) and subtracts half the width. So a box from 300 to 500 anchors at
     300 and the message lands at 250, which is 100px left of where "centre it on
     the box" would put it. A test asserting the midpoint reading failed, which is
     how this got pinned down. *)
  let at = Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:20
      (box 300 100 500 100)
  in
  check_int "anchored on the box's left edge" at.Font_layout.x0 250;
  check "not on its midpoint" (at.Font_layout.x0 <> 350);
  (* A box given corner-first lands in the same place, since the min of the pair is
     the same either way. *)
  let flipped =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:20
      (box 500 100 300 100)
  in
  check_int "a flipped box lands in the same place" flipped.Font_layout.x0 250;
  (* And vertically, on the smaller of the two y corners. *)
  check_int "anchored on the box's top edge"
    (Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:20
       (box 300 100 300 160))
      .Font_layout.y0 90

let test_message_odd_width () =
  (* The division is a truncating shift, so an odd width loses half a pixel. This
     is the original's behaviour and is reproduced rather than rounded away. *)
  let odd = Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:101
      ~text_h:20 (box 300 100 300 100)
  in
  check_int "an odd width truncates rather than rounds"
    odd.Font_layout.x0 (300 - 50)

let test_message_clamp () =
  (* Right edge: if the text would come within 20px of the edge it is pushed left
     by the overhang, so it ends exactly on the margin. *)
  let right =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:20
      (box 780 200 780 200)
  in
  check_int "the text is its own width" (right.Font_layout.x1 - right.Font_layout.x0) 100;
  check_int "and is clamped to 20px from the right edge" right.Font_layout.x1
    (800 - 20);
  check_int "having been pushed left by the overhang" right.Font_layout.x0 680;
  (* Left edge, and it *overrides* the right-edge shift: the second test in the
     original assigns to the variable the first one set, so a box far off both
     sides snaps to the left margin. *)
  let left =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:20
      (box (-500) 200 (-500) 200)
  in
  check_int "the left edge lands on the margin" left.Font_layout.x0 20;
  check_int "and the near-edge rule wins" left.Font_layout.x1 120;
  check_int "the margin is 20" Font_layout.screen_margin 20;
  (* Nothing to do: comfortably inside. *)
  let inside =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:20
      (box 300 200 300 200)
  in
  check_int "text inside the screen is not moved" inside.Font_layout.x0 250

let test_message_vertical_asymmetry () =
  (* The horizontal rule tests [x + width] against the margin; the vertical rule
     tests [y] alone and never looks at [y + height]. So a message sitting near the
     bottom is left to overflow: y=570 on a 600px screen is below the 580 threshold
     the rule tests, so nothing moves it, and its bottom edge runs off by 10px.
     A symmetric rule would have pulled it back. Reproduced as found, and this is
     the asymmetry's visible consequence rather than a subtlety. *)
  let low =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:40
      (box 300 590 300 590)
  in
  check_int "a message near the bottom is not pulled back" low.Font_layout.y0 570;
  check "so its bottom edge leaves the screen"
    (low.Font_layout.y1 > 600);
  (* The horizontal rule, by contrast, does correct for the overflow - which is what
     makes the pair inconsistent rather than merely different. *)
  let wide =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:40
      (box 780 590 780 590)
  in
  check_int "while the horizontal rule does correct" wide.Font_layout.x1 (800 - 20);
  (* A message whose *top* is past the threshold is moved, so it is not that the
     vertical rule never fires. *)
  let very_low =
    Font_layout.place_message ~screen_w:800 ~screen_h:600 ~text_w:100 ~text_h:40
      (box 300 700 300 700)
  in
  check "a message wholly below the margin is moved"
    (very_low.Font_layout.y0 < 700)

let () =
  test_pen_rule ();
  test_resolve ();
  test_codes ();
  test_measure ();
  test_height ();
  test_has_glyph ();
  test_place_line ();
  test_multi_line ();
  test_wrap ();
  test_message_anchoring ();
  test_message_odd_width ();
  test_message_clamp ();
  test_message_vertical_asymmetry ();
  if !failures = 0 then print_endline "all font layout tests passed"
  else begin
    Printf.printf "%d font layout test(s) failed\n" !failures;
    exit 1
  end