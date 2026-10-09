(* The conversation screen's geometry: where the dialogue box sits, where
   the portrait goes, how lines wrap, and where the choice buttons sit.
   Pure decision-making with no SDL, which is the only reason it can be
   tested at all. *)

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
  (* The conversation panel: 1024x768 window, dialogue box centered,
     portrait on the left, text on the right, choices at the bottom. *)
  check "the panel is the full conversation area"
    (Conversation_layout.panel_x = 0 && Conversation_layout.panel_y = 128
     && Conversation_layout.panel_w = 1024 && Conversation_layout.panel_h = 512);
  check "portrait sits on the left"
    (Conversation_layout.portrait_x = 50 && Conversation_layout.portrait_y = 150
     && Conversation_layout.portrait_w = 256 && Conversation_layout.portrait_h = 384);
  check "dialogue box to the right of portrait"
    (Conversation_layout.dialogue_x = 330 && Conversation_layout.dialogue_y = 150
     && Conversation_layout.dialogue_w = 660 && Conversation_layout.dialogue_h = 300);
  check "name label above the dialogue"
    (Conversation_layout.speaker_x = 100 && Conversation_layout.speaker_y = 100);
  check "line height is 24px"
    (Conversation_layout._line_height = 24);
  check "max 12 lines visible"
    (Conversation_layout._max_visible_lines = 12);
  check "skip button in top right"
    (Conversation_layout.skip_btn.Layout.x = 884 && Conversation_layout.skip_btn.Layout.y = 562
     && Conversation_layout.skip_btn.Layout.w = 128 && Conversation_layout.skip_btn.Layout.h = 35);
  check "location text at top center"
    (Conversation_layout.location_y = -60);
  check "help text at bottom"
    (Conversation_layout.help_y = 540);
  check "hit radius is 16 pixels"
    (Conversation_layout.hit_radius = 16);;

let () =
  (* Test hit testing for clickable areas *)
  check "click inside portrait area is a hit"
    (Conversation_layout.hit 100 200 = `Portrait);
  check "click on dialogue area is a hit"
    (Conversation_layout.hit 400 200 = `Dialogue);
  check "click on choice button area is a hit"
    (Conversation_layout.hit 200 450 = `Choice 0);
  check "click on second choice is a hit"
    (Conversation_layout.hit 200 480 = `Choice 1);
  check "click outside any interactive area is a miss"
    (Conversation_layout.hit 0 0 = `Miss);
  check "click on skip button is a skip"
    (Conversation_layout.hit 900 570 = `Skip)

let () =
  if !failures = 0 then print_endline "all conversation layout tests passed"
  else begin
    Printf.printf "%d conversation layout test(s) failed\n" !failures;
    exit 1
  end