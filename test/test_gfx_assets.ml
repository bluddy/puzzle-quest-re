(* The gem frame table.

   The four mana gems come from named tags in the game's own bitmap registry and
   are recovered. Skull and gold are read off the sheet and are inferred. The test
   pins both halves of that distinction rather than treating them alike, because
   "we guessed this one" is exactly the distinction that gets lost.

   No image is decoded here: this is arithmetic over the frame table, so it needs
   neither the sheet nor a display. *)

open Pq_gfx
open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_opt name got want =
  let sh = function
    | None -> "None"
    | Some (x, y, w, h) -> Printf.sprintf "(%d,%d %dx%d)" x y w h
  in
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name (sh got) (sh want);
    incr failures
  end

let at x y = Some (x, y, Assets.cell, Assets.cell)

let () =
  (* The four recovered frames, at the coordinates Assets.xml gives. Cells are
     71x71 on a 72px pitch - not the 64px the placeholder board used, and worth
     pinning because it is the sort of number that looks fine either way. *)
  check "cells are 71px" (Assets.cell = 71);
  check "on a 72px pitch" (Assets.pitch = 72);
  let r g =
    match Assets.frame g with
    | Some r -> Some (r.Layout.x, r.Layout.y, r.Layout.w, r.Layout.h)
    | None -> None
  in
  check_opt "Earth is img_gem_green at 0,0"
    (r (Board.Mana Board.Earth)) (at 0 0);
  check_opt "Fire is img_gem_red at 72,0"
    (r (Board.Mana Board.Fire)) (at 72 0);
  check_opt "Air is img_gem_yellow at 144,0"
    (r (Board.Mana Board.Air)) (at 144 0);
  check_opt "Water is img_gem_blue at 216,0"
    (r (Board.Mana Board.Water)) (at 216 0);
  (* Row-major in the engine's element order Earth, Fire, Air, Water - which is
     [Board.mana_element]'s order and NOT the order [Board.gem] lists its
     constructors in. That transposition is a standing trap in this port. *)
  check "the four frames are distinct"
    (List.length
       (List.sort_uniq compare
          (List.map
             (fun e -> r (Board.Mana e))
             [ Board.Earth; Board.Fire; Board.Air; Board.Water ]))
     = 4);
  check "Earth's frame comes before Fire's, Air's before Water's"
    (let g e = match Assets.frame (Board.Mana e) with Some f -> f.Layout.x | None -> -1 in
     g Board.Earth < g Board.Fire && g Board.Air < g Board.Water)

let () =
  (* Provenance is the point of this file. *)
  let at x y = Some (x, y, Assets.cell, Assets.cell) in
  let r g =
    match Assets.frame g with
    | Some f -> Some (f.Layout.x, f.Layout.y, f.Layout.w, f.Layout.h)
    | None -> None
  in
  let named g =
    match Assets.provenance_of g with Some (Assets.Named _) -> true | _ -> false
  in
  List.iter
    (fun g -> check (Printf.sprintf "%s is a named frame" (Layout.gem_letter g)) (named g))
    [ Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Air;
      Board.Mana Board.Water ];
  List.iter
    (fun g ->
      check
        (Printf.sprintf "%s is inferred, not named" (Layout.gem_letter g))
        (match Assets.provenance_of g with
        | Some Assets.Inferred -> true
        | _ -> false))
    [ Board.Skull; Board.Gold; Board.Experience; Board.Wildcard 4 ];
  (* Unidentified frames must be absent, so the caller falls back to a flat colour
     rather than drawing a sprite that might be something else entirely.
     [Board.Experience] used to be on this list and no longer is: it is the purple
     star at 360,0, corroborated by [Spell.GStar] being documented as "the purple
     star, id 7". *)
  List.iter
    (fun g ->
      check
        (Printf.sprintf "%s has no frame yet" (Layout.gem_letter g))
        (Assets.frame g = None))
    [ Board.Empty ];
  (* This sheet contains no red skull. Rows 4 and 5 look like red skulls but are
     the plain skull with a "+5" multiplier and a red halo painted over it, so
     there is only one skull sprite here and RedSkull's art lives elsewhere.
     Leaving it [None] is the honest answer; guessing would be worse. *)
  check "X has no frame in this sheet" (Assets.frame Board.RedSkull = None);
  check "and RedSkull is absent, not merely inferred"
    (Assets.provenance_of Board.RedSkull = None);
  check "the experience gem has a frame" (Assets.frame Board.Experience <> None);
  check_opt "experience is the purple star at 360,0"
    (r Board.Experience) (at 360 0);
  (* Row 0 is exactly seven cells of seven - green, red, yellow, blue, skull,
     purple star, gold. All placed, and all in distinct columns, or one gem would
     silently render as another. *)
  let row0 =
    [ Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Air;
      Board.Mana Board.Water; Board.Skull; Board.Experience; Board.Gold ]
  in
  let cols =
    List.filter_map
      (fun g -> match Assets.frame g with Some f -> Some f.Layout.x | None -> None)
      row0
  in
  check "all seven row 0 gems are placed" (List.length cols = 7);
  check "and occupy distinct columns"
    (List.length (List.sort_uniq compare cols) = 7);
  check "a wildcard outside 2..8 has no frame" (Assets.frame (Board.Wildcard 9) = None);
  check "a 1x wildcard has no frame" (Assets.frame (Board.Wildcard 1) = None);
  (* Wildcards 2..8 are the seven multiplier badges on row 1. *)
  check "wildcards 2..8 all have frames"
    (List.for_all (fun n -> Assets.frame (Board.Wildcard n) <> None)
       [ 2; 3; 4; 5; 6; 7; 8 ]);
  check "the seven wildcard frames are distinct"
    (List.length
       (List.sort_uniq compare
          (List.filter_map
             (fun n -> match Assets.frame (Board.Wildcard n) with
                       | Some r -> Some (r.Layout.x, r.Layout.y)
                       | None -> None)
             [ 2; 3; 4; 5; 6; 7; 8 ]))
     = 7);
  check "wildcard frames all sit on row 1"
    (List.for_all
       (fun n ->
         match Assets.frame (Board.Wildcard n) with
         | Some r -> r.Layout.y = Assets.pitch
         | None -> false)
       [ 2; 3; 4; 5; 6; 7; 8 ])

let () =
  (* Every frame has to fit inside the sheet, or the sampler clamps and the gem
     renders as a smear of its edge. *)
  let fits g =
    match Assets.frame g with
    | None -> true
    | Some r ->
        r.Layout.x >= 0 && r.Layout.y >= 0
        && r.Layout.x + r.Layout.w <= Assets.sheet_width
        && r.Layout.y + r.Layout.h <= Assets.sheet_height
  in
  let every =
    [ Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Air;
      Board.Mana Board.Water; Board.Skull; Board.Gold; Board.Wildcard 2;
      Board.Wildcard 8 ]
  in
  check "every identified frame fits inside the 512x512 sheet"
    (List.for_all fits every);
  check "the sheet is 512 wide" (Assets.sheet_width = 512);
  check "and 512 tall" (Assets.sheet_height = 512)

let () =
  if !failures = 0 then print_endline "all gfx assets tests passed"
  else begin
    Printf.printf "%d gfx assets test(s) failed\n" !failures;
    exit 1
  end