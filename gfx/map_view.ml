(** Where the world map sits in the window, and how a click finds a node.

    The map is Assets/Map.xml: four rows and columns of 512-pixel segments,
    a 2048 square, and every city, waypoint and ruin carries an x/y in that
    space (lib/campaign_map.ml). The window is the game's own 1024x768, so
    the square is fitted at the smaller of the two axis scales and centred -
    for this window that is 3/8 scale and an origin of (128, 0).

    The fit is a choice. No asset says what viewport the original drew its
    map in; what the assets say is the map's size and the nodes'
    coordinates, and a fit that shows the whole square with nothing
    off-screen is the reading that needs no invented panning -
    port.map_screen_mapping.

    Pure: no SDL, no GL, no window - which is the only reason it can be
    tested without a display. *)
open Puzzle_quest_lib

(** The full map, in world pixels. *)
let world = 2048

(** One segment's edge; [segments_side] of them a side, per Assets/Map.xml. *)
let segment_px = 512
let segments_side = 4

(** Screen pixels per world pixel: the smaller axis fit, so the whole square
    is on screen. *)
let scale =
  let sw = float_of_int Layout.game_screen_w /. float_of_int world in
  let sh = float_of_int Layout.game_screen_h /. float_of_int world in
  if sw < sh then sw else sh

(** The fitted square: its edge length on screen and top-left corner. *)
let drawn = int_of_float (float_of_int world *. scale)
let origin_x = (Layout.game_screen_w - drawn) / 2
let origin_y = (Layout.game_screen_h - drawn) / 2

let rect : Layout.rect = { Layout.x = origin_x; y = origin_y; w = drawn; h = drawn }

(** One segment's rectangle on screen; its texture covers it whole. *)
let segment_rect (row : int) (col : int) : Layout.rect =
  let s = int_of_float (float_of_int segment_px *. scale +. 0.5) in
  { Layout.x = origin_x + (col * s); y = origin_y + (row * s); w = s; h = s }

(** A world position where it is drawn, rounded to the nearest pixel. *)
let world_to_screen (x : int) (y : int) : int * int =
  ( origin_x + int_of_float ((float_of_int x *. scale) +. 0.5),
    origin_y + int_of_float ((float_of_int y *. scale) +. 0.5) )

(** The world pixel under a window position; [None] off the map. Rounding is
    the same half-up the drawing does, so the two agree at every point the
    map itself names. *)
let screen_to_world (sx : int) (sy : int) : (int * int) option =
  let fx = float_of_int (sx - origin_x) /. scale in
  let fy = float_of_int (sy - origin_y) /. scale in
  if fx < 0.0 || fy < 0.0 || fx >= float_of_int world || fy >= float_of_int world
  then None
  else Some (int_of_float (fx +. 0.5), int_of_float (fy +. 0.5))

(** How close a click has to be to a node to pick it, in screen pixels. At
    3/8 scale that is 43 world pixels: generous next to the spacing of the
    nodes, deliberately, because a click that means "this node" should not
    have to be pixel-true. The comparison is in screen space, against the
    node's drawn position, so rounding can never make a node unhittable
    where the window draws it. *)
let hit_radius = 16

(** The node a click lands on: the closest {e visible} one inside
    [hit_radius], or [None]. Cities, waypoints and ruins alike - they are
    all points on this map, and the hidden ones are invisible to the mouse
    as well as to the eye. *)
let hit_node (mx : int) (my : int) : string option =
  let best = ref None in
  Hashtbl.iter
    (fun id (n : Campaign.map_node) ->
      if n.visible then begin
        let sx, sy = world_to_screen n.x n.y in
        let d2 = ((sx - mx) * (sx - mx)) + ((sy - my) * (sy - my)) in
        if d2 <= hit_radius * hit_radius then
          match !best with
          | Some (bd, _) when bd <= d2 -> ()
          | _ -> best := Some (d2, id)
      end)
    Campaign.map_nodes;
  match !best with Some (_, id) -> Some id | None -> None
