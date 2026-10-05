(* The bitmap registry, and the decorations cut from it.

   `lib/skin_data.ml` is `Assets/Assets.xml` - the engine's own asset registry -
   turned into data, so that a renderer names a tag rather than carrying a
   rectangle it measured by eye.

   The interesting assertions here are the ones that could *fail* if the art and
   the code ever disagree. A border that tiles to the screen exactly is the kind
   of fact that looks right in a screenshot at any scale and is still wrong, so it
   is asserted rather than admired. *)

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

(* The screen the art is drawn for. Compared against [Layout.game_screen_w] in *)
(* test_gfx_layout, which is where that constant lives; kept literal here so this*)
(* suite needs no graphics library and stays a pure check on the registry. *)
let screen_w = 1024
and screen_h = 768

let frame tag =
  match Skin_data.frame_of_tag tag with
  | Some f -> f
  | None -> failwith ("no frame tagged " ^ tag)

(* ------------------------------------------------------------ the registry -- *)

let test_shape () =
  check_int "44 sheets" (List.length (Array.to_list Skin_data.sheets)) 44;
  check_int "422 named frames" (Array.length Skin_data.frames) 422;
  (* Tags are the vocabulary the whole presentation layer addresses decoration by,
     so a duplicate would make one of them unreachable. *)
  check "tags are unique"
    (let seen = Hashtbl.create 512 in
     Array.for_all
       (fun (f : Skin_data.frame) ->
         if Hashtbl.mem seen f.Skin_data.tag then false
         else begin
           Hashtbl.add seen f.Skin_data.tag ();
           true
         end)
       Skin_data.frames);
  (* Every frame must name a sheet that exists, or drawing it silently does
     nothing - which is the failure mode this module exists to prevent. *)
  check "every frame names a sheet the registry declares"
    (Array.for_all
       (fun (f : Skin_data.frame) -> Skin_data.sheet_of_tag f.Skin_data.sheet <> None)
       Skin_data.frames)

let test_paths () =
  (* The registry spells paths with backslashes and no extension. Both are
     normalised on the way in, because the decoder needs the extension and the zip
     needs the forward slash. *)
  let gems = Skin_data.sheet_of_tag "bmp_skin_gemsgrid" in
  check "the gem sheet is found by tag" (gems <> None);
  check "and its path is normalised"
    (match gems with
    | Some s ->
        s.Skin_data.file = "Assets/Skin/Skin_Gems_Grid"
        && not (String.contains s.Skin_data.file '\\')
    | None -> false)

(* ------------------------------------------------- the frames we depend on -- *)

let test_gem_frames () =
  (* These four are the only gem frames the registry names; the rest of the gems
     are addressed by the engine by raw coordinates and are inferred. Asserted
     because `gfx/assets.ml` now *looks them up* rather than hardcoding them, and
     a lookup that silently returned the wrong rectangle would draw the wrong gem
     on every mana colour at once. *)
  let green = frame "img_gem_green" in
  check_int "img_gem_green is at 0,0" (green.Skin_data.x + green.Skin_data.y) 0;
  check_int "and is 71 square" (green.Skin_data.w * 2) 142;
  check_int "img_gem_red is one cell along" (frame "img_gem_red").Skin_data.x 72;
  check_int "img_gem_yellow is two" (frame "img_gem_yellow").Skin_data.x 144;
  check_int "img_gem_blue is three" (frame "img_gem_blue").Skin_data.x 216;
  check "they are all on the gem sheet"
    (List.for_all
       (fun t -> (frame t).Skin_data.sheet = "bmp_skin_gemsgrid")
       [ "img_gem_green"; "img_gem_red"; "img_gem_yellow"; "img_gem_blue" ]);
  (* Skull, red skull, gold, experience and the wildcards are *not* in the
     registry. If a future version of the game adds them, these fail and the
     inferred frames in gfx/assets.ml can be retired. *)
  check "the other gems really are un-named"
    (List.for_all
       (fun t -> Skin_data.frame_of_tag t = None)
       [ "img_gem_skull"; "img_gem_gold"; "img_gem_xp"; "img_gem_red_skull" ])

let test_border_tiles_the_screen () =
  (* The strongest fact in this file. The four border frames are cut from a sheet
     at 1024x768 and they tile it exactly:

         top     1024x95  at (0, 0)
         left      19x653 at (0, 95)
         right     21x653 at (1003, 95)
         bottom  1024x20  at (0, 748)

     95 + 653 = 748, and 748 + 20 = 768. The left and right edges are 19 + 21 = 40
     apart from the top's width, hence 1003.

     This is what makes the window size a fact rather than a preference, so it is
     worth asserting: a border drawn to the wrong window is cropped or stretched,
     and looks merely "off" rather than broken. *)
  let top = frame "img_border_top" and bottom = frame "img_border_bottom" in
  let left = frame "img_border_left" and right = frame "img_border_right" in
  check_int "the top border spans the screen"
    top.Skin_data.dest_w screen_w;
  check_int "and starts at the top left"
    (top.Skin_data.x + top.Skin_data.y) 0;
  check_int "the left border starts below the top one"
    left.Skin_data.y top.Skin_data.h;
  check_int "and runs down to the bottom one"
    (left.Skin_data.y + left.Skin_data.h) bottom.Skin_data.y;
  check_int "and the bottom border closes it"
    (bottom.Skin_data.y + bottom.Skin_data.h) screen_h;
  check_int "the left border is flush to the left edge" left.Skin_data.x 0;
  check_int "and the right one closes the width"
    (right.Skin_data.x + right.Skin_data.w) screen_w;
  (* The right border's left edge is the screen less its own width - which is the
     arithmetic that makes the frame close. The two side borders are only 19 and
     21 wide: together that is the frame's *thickness*, not its width, and
     checking it against the top border's 1024 would be meaningless. *)
  check_int "the right border butts against the top border's width"
    right.Skin_data.x (top.Skin_data.w - right.Skin_data.w);
  (* The backdrop is the whole screen, so it is what the window size comes from. *)
  let backdrop = frame "img_backdrop" in
  check_int "the backdrop is as wide as the window"
    backdrop.Skin_data.dest_w screen_w;
  check_int "and as tall" backdrop.Skin_data.dest_h screen_h;
  (* The top panel is the same height as the top border, which is why the board is
     inset by that much and not by a typed number. *)
  check_int "the top panel is as tall as the top border"
    (frame "img_toppanel").Skin_data.dest_h top.Skin_data.h

let test_selection_glow () =
  (* Wider than a board cell and half as tall, so it is a lozenge drawn across the
     cell rather than a box around it - which is why the selection fell back to a
     flat overlay before this was known. *)
  let sel = frame "img_selglow" in
  check "the selection glow is wider than a gem" (sel.Skin_data.dest_w > 71);
  check "and shorter than one" (sel.Skin_data.dest_h < 71);
  check "it is drawn at its stored size" (sel.Skin_data.dest_w = sel.Skin_data.w)

let test_draw_scale () =
  (* The destination size is not decoration: several frames are stored larger than
     they are drawn, and drawing one at its stored size would be wrong. The red
     glows are 88x88 on disk for 64x64 on screen. *)
  let glow = frame "img_redglow_00" in
  check "a glow is stored larger than it is drawn"
    (glow.Skin_data.w > glow.Skin_data.dest_w);
  let n, d = Skin_data.draw_scale glow in
  (* 64/88 reduces to 8/11. The scale is a fraction rather than a raw pair so that a
     caller scaling by it does not have to reduce it first. *)
  check_int "the scale is 64/88 reduced" n 8;
  check_int "over the stored size" d 11;
  check "and it really is the ratio asked for"
    ((n * glow.Skin_data.w) = (d * glow.Skin_data.dest_w));
  check "in lowest terms"
    (let rec gcd a b = if b = 0 then a else gcd b (a mod b) in
     gcd n d = 1);
  (* A frame drawn at its stored size has no scale to speak of. *)
  let green = frame "img_gem_green" in
  check_int "an unscaled frame scales by 1" (fst (Skin_data.draw_scale green)) 1;
  check_int "and 1" (snd (Skin_data.draw_scale green)) 1

let test_frames_on () =
  let gems = Skin_data.frames_on "bmp_skin_gemsgrid" in
  check "the gem sheet has frames of its own" (Array.length gems > 4);
  check "and they all belong to it"
    (Array.for_all (fun (f : Skin_data.frame) -> f.Skin_data.sheet = "bmp_skin_gemsgrid") gems);
  check "and a sheet with none comes back empty"
    (Array.length (Skin_data.frames_on "no_such_sheet") = 0)

let () =
  test_shape ();
  test_paths ();
  test_gem_frames ();
  test_border_tiles_the_screen ();
  test_selection_glow ();
  test_draw_scale ();
  test_frames_on ();
  if !failures = 0 then print_endline "all skin data tests passed"
  else begin
    Printf.printf "%d skin data test(s) failed\n" !failures;
    exit 1
  end