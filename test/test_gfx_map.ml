(* The map screen's geometry: where the 2048 square sits in the game's own
   window, and how a click finds a node. The module under test is pure on
   purpose - no SDL, no display - so the numbers are asserted here rather
   than eyeballed in a window. *)

open Puzzle_quest_lib
open Pq_gfx

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_eq name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let () =
  (* The fit: 2048 into 1024x768 is 3/8, so the map is a 768 square centred
     horizontally with no room to centre vertically. *)
  check_eq "the fitted map is 768 square" Map_view.drawn 768;
  check_eq "centred with the origin at the top" Map_view.origin_x 128;
  check_eq "and flush with the top edge" Map_view.origin_y 0;
  check "the rect agrees"
    (Map_view.rect = { Layout.x = 128; y = 0; w = 768; h = 768 });
  check "a segment is 192 square"
    (Map_view.segment_rect 1 1 = { Layout.x = 320; y = 192; w = 192; h = 192 });
  check "the last segment lands on the map's far corner"
    (let r = Map_view.segment_rect 3 3 in
     r.Layout.x + r.Layout.w = 128 + 768 && r.Layout.y + r.Layout.h = 768)

let () =
  (* The two directions of the mapping, at points the scale keeps exact. *)
  check "the world corner draws at the rect corner"
    (Map_view.world_to_screen 0 0 = (128, 0));
  check "the world middle draws at the map's middle"
    (Map_view.world_to_screen 1024 1024 = (512, 384));
  check "the drawn corner reads back as the world corner"
    (Map_view.screen_to_world 128 0 = Some (0, 0));
  check "the middle reads back"
    (Map_view.screen_to_world 512 384 = Some (1024, 1024));
  check "left of the map is nowhere"
    (Map_view.screen_to_world 127 100 = None);
  check "the map's right edge is outside it"
    (Map_view.screen_to_world 896 100 = None);
  check "below the map is nowhere"
    (Map_view.screen_to_world 500 768 = None)

let () =
  (* Clicking: a node is always hittable where it is drawn, a hidden node
     not at all, and the radius is the only tolerance. CBAR ships visible at
     (1418, 934), the seed city. *)
  let cbar_sx, cbar_sy = Map_view.world_to_screen 1418 934 in
  check "CBAR is hit where it is drawn"
    (Map_view.hit_node cbar_sx cbar_sy = Some "CBAR");
  let d2_to_others sx sy =
    Hashtbl.fold
      (fun id (n : Campaign.map_node) acc ->
        if id = "CBAR" || not n.visible then acc
        else
          let x, y = Map_view.world_to_screen n.x n.y in
          min acc (((x - sx) * (x - sx)) + ((y - sy) * (y - sy))))
      Campaign.map_nodes max_int
  in
  check "no other node crowds CBAR inside the radius"
    (d2_to_others cbar_sx cbar_sy
     > Map_view.hit_radius * Map_view.hit_radius);
  let was = Campaign.node_visible "CBAR" in
  Campaign.set_location_visible "CBAR" false;
  check "a hidden node cannot be hit"
    (Map_view.hit_node cbar_sx cbar_sy = None);
  Campaign.set_location_visible "CBAR" was;
  check "it is hit again once shown"
    (Map_view.hit_node cbar_sx cbar_sy = Some "CBAR");
  (* Somewhere the nodes are not: scan for a point clear of every one of
     them, geometrically, then check the picker agrees it is nothing. *)
  let min_d2 sx sy =
    Hashtbl.fold
      (fun _ (n : Campaign.map_node) acc ->
        if not n.visible then acc
        else
          let x, y = Map_view.world_to_screen n.x n.y in
          min acc (((x - sx) * (x - sx)) + ((y - sy) * (y - sy))))
      Campaign.map_nodes max_int
  in
  let clear = ref None in
  let sx = ref Map_view.origin_x in
  while !clear = None && !sx <= Map_view.origin_x + Map_view.drawn do
    let sy = ref Map_view.origin_y in
    while !clear = None && !sy <= Map_view.origin_y + Map_view.drawn do
      if min_d2 !sx !sy > Map_view.hit_radius * Map_view.hit_radius then
        clear := Some (!sx, !sy);
      sy := !sy + 16
    done;
    sx := !sx + 16
  done;
  match !clear with
  | Some (x, y) ->
      check "a point geometrically clear of every node hits nothing"
        (Map_view.hit_node x y = None)
  | None ->
      check "a point geometrically clear of every node hits nothing" false

let () =
  if !failures = 0 then print_endline "all map view tests passed"
  else begin
    Printf.printf "%d map view test(s) failed\n" !failures;
    exit 1
  end
