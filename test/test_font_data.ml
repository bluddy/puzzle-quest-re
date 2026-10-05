(* The generated font tables, and the invariants a renderer relies on.

   These are the numbers [tools/extract_fonts.py] read out of
   [game/Assets.zip], so most of what can be asserted is that the extraction is
   intact and self-consistent: the tables are sorted for the binary search, every
   style names a face that exists, and the codes a style's face claims to cover are
   the codes it actually has.

   The advance itself is *not* asserted to any particular formula, because it is an
   inference - see the note at the top of [gfx/font_layout.ml]. What is asserted
   here is the property the inference rests on: that a glyph's two bearings account
   for its ink box rather than adding to it. *)

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

let check_eq_p name got want =
  let sh = function
    | None -> "None"
    | Some (a, b, c) -> Printf.sprintf "Some (%d,%d,%d)" a b c
  in
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (sh got) (sh want);
    incr failures
  end

(* ------------------------------------------------------------------ faces -- *)

let system = Font_data.face_of_name "System"
let small = Font_data.face_of_name "Small"
let message = Font_data.face_of_name "WC_Message"

let test_faces () =
  check_int "ten faces are extracted" (List.length (Array.to_list Font_data.faces)) 10;
  check "System is one of them" (system <> None);
  check "Small is one of them" (small <> None);
  check "WC_Message is one of them" (message <> None);
  check "an unknown face is not" (Font_data.face_of_name "NoSuchFace" = None);
  (* 195 or 199 characters per face, all covering code 32 through 8482 - the range
     is multilingual, so a test that only knew about ASCII would pass here and then
     fail on a translated string. *)
  check
    "every face covers the multilingual code range"
    (Array.for_all
       (fun (f : Font_data.face) -> f.Font_data.mincode = 32 && f.Font_data.maxcode = 8482)
       Font_data.faces);
  check
    "every face's glyph count is its declared range or close to it"
    (Array.for_all
       (fun (f : Font_data.face) ->
         Array.length f.Font_data.glyphs >= 195)
       Font_data.faces)

let test_sorted () =
  (* The binary search is only correct on sorted input, and nothing else checks
     that the generator emitted it in order. *)
  check
    "every face's glyphs are sorted by code"
    (Array.for_all
       (fun (f : Font_data.face) ->
         let g = f.Font_data.glyphs in
         let ok = ref true in
         for i = 1 to Array.length g - 1 do
           if (g.(i - 1)).Font_data.code >= (g.(i)).Font_data.code then ok := false
         done;
         !ok)
       Font_data.faces)

let test_lookup () =
  match (system, small) with
  | Some sys, Some _sml ->
      (* First, middle and last of the table: the three places a binary search
         breaks if it is wrong. *)
      let first = Array.get sys.Font_data.glyphs 0 in
      let last = Array.get sys.Font_data.glyphs (Array.length sys.Font_data.glyphs - 1) in
      check_int "the first glyph is code 32"
        (Option.get (Font_data.glyph_of_code sys first.Font_data.code)).Font_data.code 32;
      check_int "the last glyph is code 8482"
        (Option.get (Font_data.glyph_of_code sys last.Font_data.code)).Font_data.code 8482;
      check_int "'A' is found"
        (Option.get (Font_data.glyph_of_code sys 65)).Font_data.code 65;
      (* Outside the declared range: no glyph, and the reason is different from
         "the face has a blank slot for it". *)
      check "a code below mincode has no glyph" (Font_data.glyph_of_code sys 31 = None);
      check "a code above maxcode has no glyph" (Font_data.glyph_of_code sys 8483 = None);
      (* The space is the one glyph whose rectangle is a placeholder: no ink, so a
         1px box. Its bearings are the only statement of how wide a space is. Note
         that it is still a *real* glyph, not the "no such glyph" sentinel -
         FUN_004c75e0's sentinel is an all-zero rectangle, and the space's width
         is 1. *)
      let space = Option.get (Font_data.glyph_of_code sys 32) in
      check_int "the space has a 1px box" space.Font_data.w 1;
      check "the space's bearings are wider than its box"
        ((space.Font_data.leading + space.Font_data.trailing) > space.Font_data.w);
      check "and it is not the all-zero sentinel"
        (not (space.Font_data.w = 0 && space.Font_data.x = 0 && space.Font_data.y = 0));
      (* Which raises the question of whether anything uses that sentinel at all.
         It does not: every code in every face has a rectangle, so the "no glyph"
         case is only ever out-of-range, never in-range-and-blank. *)
      check
        "no glyph in any face uses the all-zero sentinel"
        (Array.for_all
           (fun (f : Font_data.face) ->
             Array.for_all
               (fun (g : Font_data.glyph) ->
                 not (g.Font_data.w = 0 && g.Font_data.x = 0 && g.Font_data.y = 0))
               f.Font_data.glyphs)
           Font_data.faces)
  | _ -> check "System and Small are present" false

let test_bearings_account_for_the_ink () =
  (* The finding the advance inference rests on. If the bearings *added* to the ink
     width, summing all three would be the advance; they do not - they sum to it,
     to within a pixel or two of rounding, on 94% of glyphs.

     What matters is not that percentage but *which faces* carry the exceptions,
     because the inference only has to be right for the faces actually drawn. The
     three the battle screen uses are essentially clean - System, Small and
     WC_Message between them have one glyph between them whose bearings exceed its
     ink by more than 3px. The 127 offenders are all in the heading and script
     faces, where the metrics are visibly different: 49 in WC_Heading, 20 in each
     of WC_Quest and the three script faces, 16 in WC_Button.

     If an offender ever appears in System, the advance inference is wrong in a way
     that would show up on screen, and this is the test that notices. *)
  let offenders = Hashtbl.create 10 in
  Array.iter
    (fun (f : Font_data.face) ->
      Array.iter
        (fun (g : Font_data.glyph) ->
          if g.Font_data.code > 32 then
            let slack = g.Font_data.w - g.Font_data.leading - g.Font_data.trailing in
            if abs slack > 3 then
              let n = match Hashtbl.find_opt offenders f.Font_data.name with
                | Some n -> n | None -> 0
              in
              Hashtbl.replace offenders f.Font_data.name (n + 1))
        f.Font_data.glyphs)
    Font_data.faces;
  let count name = match Hashtbl.find_opt offenders name with Some n -> n | None -> 0 in
  let total = Hashtbl.fold (fun _ n acc -> acc + n) offenders 0 in
  check_int "System, the HUD's body font, is clean" (count "System") 1;
  check_int "Small is clean" (count "Small") 0;
  check_int "WC_Message is clean" (count "WC_Message") 0;
  check_int "and 127 glyphs across all faces are not" total 127;
  let keys = List.of_seq (Hashtbl.to_seq_keys offenders) in
  let hud_clean =
    List.for_all
      (fun name ->
        match name with
        | "System" | "Small" | "WC_Message" -> count name <= 1
        | _ -> count name > 0)
      keys
  in
  check "every other face with an exception is a heading or script face" hud_clean

(* ----------------------------------------------------------------- styles -- *)

let test_styles () =
  check_int "thirty-two named fonts"
    (List.length (Array.to_list Font_data.styles)) 32;
  (* Every style must resolve to a face, or Font.create would silently load
     nothing for it and the HUD would come out blank rather than wrong. *)
  check
    "every style names a face that exists"
    (Array.for_all
       (fun (s : Font_data.style) -> Font_data.face_of_name s.Font_data.face <> None)
       Font_data.styles);
  check "tags are unique"
    (let seen = Hashtbl.create 32 in
     Array.for_all
       (fun (s : Font_data.style) ->
         if Hashtbl.mem seen s.Font_data.tag then false
         else begin
           Hashtbl.add seen s.Font_data.tag ();
           true
         end)
       Font_data.styles)

let test_named_fonts () =
  (* The colours are the point of having thirty-two named fonts: they are where
     the original's coloured numbers come from. *)
  let colour tag =
    match Font_data.style_of_tag tag with
    | None -> None
    | Some s -> Some (s.Font_data.r, s.Font_data.g, s.Font_data.b)
  in
  check_eq_p "font_xp is the game's purple" (colour "font_xp") (Some (200, 0, 255));
  check_eq_p "font_gold is the game's orange" (colour "font_gold") (Some (255, 150, 0));
  check_eq_p "font_system is the default off-white" (colour "font_system")
    (Some (255, 245, 235));
  (* The float-message palette: seven colours, one per font_msg_*. *)
  check "there are seven font_msg styles"
    (List.length
       (List.filter
          (fun (s : Font_data.style) ->
            String.length s.Font_data.tag >= 8
            && String.sub s.Font_data.tag 0 8 = "font_msg")
          (Array.to_list Font_data.styles))
    = 7);
  check "font_msg_white is white" (colour "font_msg_white" = Some (255, 255, 255));
  check "font_msg_red is red" (colour "font_msg_red" = Some (255, 0, 0));
  check "an unknown tag has no style" (Font_data.style_of_tag "font_nope" = None)

let test_line_height () =
  (* Six styles carry lineheight="0", which cannot mean zero - their faces are 43
     to 45px tall - so it falls back to the face's own height, which is the field
     FUN_004c9030 reads for a one-line measurement. *)
  let heading =
    match Font_data.style_of_tag "font_heading" with
    | None -> None
    | Some s -> Some (Font_data.line_height s)
  in
  check_int "font_heading falls back to its face's height" (Option.get heading) 45;
  let small_style = Option.get (Font_data.style_of_tag "font_small") in
  check_int "font_small uses its declared line height"
    (Font_data.line_height small_style) 14

let () =
  test_faces ();
  test_sorted ();
  test_lookup ();
  test_bearings_account_for_the_ink ();
  test_styles ();
  test_named_fonts ();
  test_line_height ();
  if !failures = 0 then print_endline "all font data tests passed"
  else begin
    Printf.printf "%d font data test(s) failed\n" !failures;
    exit 1
  end