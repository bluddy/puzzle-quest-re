(** Conversation UI layout geometry.

    The conversation screen is built from the [ConversationMenu] XML:
    a 1024x768 window with a conversation background (512px high) centered
    vertically, side panel decorations, a skip button, location text,
    help text, and the main dialogue area.

    Pure: no SDL, no GL - just geometry. Testable without a display. *)

open Puzzle_quest_lib

(** Where the conversation panel sits on screen. *)
let panel_x = 0
let panel_y = 128
let panel_w = 1024
let panel_h = 512

(** The main dialogue text box. *)
let text_x = 100
let text_y = 150
let text_w = 824
let text_h = 300

(** The character portrait area (left side of dialogue). *)
let portrait_x = 50
let portrait_y = 150
let portrait_w = 256
let portrait_h = 384

(** The dialogue text box (to the right of the portrait). *)
let dialogue_x = 330
let dialogue_y = 150
let dialogue_w = 660
let dialogue_h = 300

(** Maximum lines of text visible at once. *)
let _max_visible_lines = 12

(** Line height for dialogue text. *)
let _line_height = 24

(** The skip button (top right). *)
let skip_btn : Layout.rect = { Layout.x = 884; y = 562; w = 128; h = 35 }

(** The location string (top center). *)
let location_y = -60

(** Help text (bottom). *)
let help_y = 540

(** The "skip" key for gamepad. *)
let gp_skip_x = 850
let gp_skip_y = 542
let gp_skip_w = 160
let gp_skip_h = 35

(** Where the speaker name is drawn. *)
let speaker_x = 100
let speaker_y = 100

(** How close a click must be to a node to pick it, in screen pixels.
    At 3/8 scale that is 43 world pixels: generous next to the spacing of
    the nodes, deliberately, because a click that means "this node" should
    not have to be pixel-true. The comparison happens in screen space,
    against the node's drawn position, so rounding cannot make a node
    unhittable where the window draws it. *)
let hit_radius = 16

(** A hit target in the conversation screen. *)
type hit =
  | Portrait
  | Dialogue
  | Choice of int
  | Skip
  | Miss

let in_rect (r : Layout.rect) (mx : int) (my : int) : bool =
  mx >= r.Layout.x && mx < r.Layout.x + r.Layout.w
  && my >= r.Layout.y && my < r.Layout.y + r.Layout.h

(** Which part of the conversation screen a click lands on. *)
let hit (mx : int) (my : int) =
  if in_rect { Layout.x = 50; y = 150; w = 256; h = 384 } mx my then `Portrait
  else if in_rect { Layout.x = 330; y = 150; w = 660; h = 300 } mx my then `Dialogue
  else if my >= 400 && my < 500 then begin
    if mx >= 200 && mx < 800 then `Choice ((my - 400) / 40)
    else `Miss
  end
  else if in_rect { Layout.x = 884; y = 562; w = 128; h = 35 } mx my then `Skip
  else `Miss

(** Build the visible segment of a conversation for display. *)
let build_visible
    (conversation: Conversation.t)
    (_scroll: int)
    : (string * string) list =
  let lines = conversation.Conversation.lines in
  let total = List.length lines in
  let _max_vis = 12 in
  let _start = max 0 (total - 12) in
  let visible =
    List.map (fun l -> (conversation.Conversation.speaker_name, l.Conversation.text))
      (List.take 12 (List.drop 0 lines))
  in
  visible

(** Convert a conversation to a list of (speaker, text) pairs for display. *)
let to_display_list (c: Conversation.t) : (string * string) list =
  List.map (fun l -> (c.Conversation.speaker_name, l.Conversation.text)) c.Conversation.lines