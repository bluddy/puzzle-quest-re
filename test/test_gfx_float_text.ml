(* Floating text: which events become messages, and when they expire.

   The placement itself is ported and tested in test_gfx_font_layout, so what is
   pinned here is the part that is {e ours}: the mapping from a battle event to a
   message, and the lifetime arithmetic.

   The mapping matters more than it looks. It is the boundary where a headless
   battle - which has no spell scripts running ADD_TEXT_MESSAGE - decides what a
   player sees. Getting it wrong is silent: a battle still plays, it just shows the
   wrong things. So the events that produce nothing are asserted as deliberately,
   not left to chance. *)

open Pq_gfx
open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_str name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name got want;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

(* ---------------------------------------------------------------- mapping -- *)

let showing e = match Float_text.of_event e with Some _ -> true | None -> false

let test_every_tag_resolves () =
  (* Every font tag this module can produce must name a real font.

     Worth a test of its own because the failure is invisible: a tag that does not
     resolve makes [Float_text.draw] return no runs, the battle plays perfectly,
     and no message ever appears. A typo in one of these strings is exactly that -
     which is how the first render of this feature came out with 32 messages live
     and nothing on screen. *)
  let produced =
    List.filter_map
      (fun e -> match Float_text.of_event e with Some (_, f, _) -> Some f | None -> None)
      [ Battle.Damage ("foe", 1); Battle.ManaGained ("you", 1, 1);
        Battle.ExtraTurn "you"; Battle.HeroicEffort "you"; Battle.ManaBurn;
        Battle.SpellCast ("you", "SBRA"); Battle.Death "foe";
        Battle.BattleEnd Battle.HeroVictory; Battle.BattleEnd Battle.EnemyVictory ]
  in
  List.iter
    (fun tag ->
      check ("the " ^ tag ^ " tag names a real font")
        (Font_layout.metrics_of_tag tag <> None))
    produced;
  (* And they must all be the message face, since that is what the palette is. *)
  check "they are all the same face"
    (List.for_all
       (fun tag ->
         match Font_layout.metrics_of_tag tag with
         | Some m -> m.Font_layout.face.Font_data.name = "WC_Message"
         | None -> false)
       produced)

let test_damage () =
  match Float_text.of_event (Battle.Damage ("foe", 17)) with
  | Some (text, font, subject) ->
      check_str "damage reads as a loss" text "-17";
      check_str "and is red" font "font_msg_red";
      check "and is about the foe" (subject = Float_text.Foe)
  | None -> check "damage produces a message" false

let test_mana () =
  match Float_text.of_event (Battle.ManaGained ("you", 1, 8)) with
  | Some (text, font, subject) ->
      check_str "mana gained reads as a gain" text "+8";
      check_str "and is green" font "font_msg_green";
      check "and is about the hero" (subject = Float_text.Hero)
  | None -> check "mana gained produces a message" false

let test_set_pieces () =
  let tag_of e = match Float_text.of_event e with Some (_, f, _) -> f | None -> "none" in
  check_str "an extra turn is announced" (tag_of (Battle.ExtraTurn "you"))
    "font_msg_yellow";
  check_str "heroic effort is announced" (tag_of (Battle.HeroicEffort "you"))
    "font_msg_orange";
  check_str "a mana burn is announced" (tag_of (Battle.ManaBurn))
    "font_msg_cyan";
  check_str "a cast spell names itself" (tag_of (Battle.SpellCast ("you", "SBRA")))
    "font_msg_white";
  check_str "victory is green" (tag_of (Battle.BattleEnd Battle.HeroVictory))
    "font_msg_green";
  check_str "defeat is red" (tag_of (Battle.BattleEnd Battle.EnemyVictory))
    "font_msg_red";
  (* A stalemate has no message: there is no text for it, and inventing one would
     be a claim about the original's wording that nothing supports. *)
  check "a stalemate says nothing" (not (showing (Battle.BattleEnd Battle.Stalemate)))

let test_quiet_events () =
  (* These are the ones that must stay quiet. Each is in the log because a tool
     wants it, not because a player needs to read it - and a turn boundary that
     flashed a message every turn would be unreadable anyway. *)
  List.iter
    (fun (name, e) -> check (name ^ " is not shown") (not (showing e)))
    [ ("a turn starting", Battle.TurnStart (0, Battle.Hero, "you"));
      ("a swap", Battle.Swap (0, 0, Ai.Horizontal));
      ("a banked turn", Battle.BankedTurn "you");
      ("a size turn", Battle.SizeTurn "you");
      ("gold", Battle.GoldGained ("you", 5));
      ("xp", Battle.XpGained ("you", 5));
      ("a held spell", Battle.SpellHeld "you");
      ("a refill", Battle.Refilled);
      ("a turn ending", Battle.TurnEnd 1) ]

(* -------------------------------------------------------------- lifetime -- *)

(* A one-pixel box, which is what a point anchor wants: [place_message] takes the box's
   smaller corner and centres the text on it. A {e value} rather than a function so
   that call sites can pun `~anchor` - see the note in [test_stack_is_bounded]. *)
let anchor = { Font_layout.x0 = 100; y0 = 0; x1 = 100; y1 = 0 }

let test_lifetime () =
  let t = Float_text.create () in
  check "a new system has nothing live" (Float_text.count t = 0);
  Float_text.say t ~subject:Float_text.Both ~anchor "5" 0.0;
  check_int "saying one makes one live" (Float_text.count t) 1;
  (* Still there just before it expires... *)
  Float_text.tick t (Float_text.default_life -. 0.01);
  check_int "and it survives until its time is up" (Float_text.count t) 1;
  (* ...and gone just after, which is the boundary that matters. *)
  Float_text.tick t Float_text.default_life;
  check_int "and expires exactly at its lifetime" (Float_text.count t) 0

let test_many () =
  (* A cascade emits several events in quick succession, so messages accumulate
     and have to expire independently rather than all at once. *)
  let t = Float_text.create () in
  List.iter
    (fun i -> Float_text.say t ~subject:Float_text.Foe ~anchor (string_of_int i) 0.0)
    [ 1; 2; 3 ];
  check_int "three messages can be live at once" (Float_text.count t) 3;
  Float_text.tick t Float_text.default_life;
  check "and all expire together when they share a birth time"
    (Float_text.count t = 0)

let test_ordering () =
  (* Newest drawn last, so a burst reads as a sequence rather than as one message
     hidden behind another. *)
  let t = Float_text.create () in
  Float_text.say t ~subject:Float_text.Both ~anchor "first" 0.0;
  Float_text.say t ~subject:Float_text.Both ~anchor "second" 0.0;
  let texts = List.map (fun (m : Float_text.message) -> m.Float_text.text) (Float_text.ordered t) in
  check_str "oldest first" (String.concat "," texts) "first,second"

let test_say_event () =
  (* The bridge from the engine: an event either becomes a message or does not. *)
  let t = Float_text.create () in
  let anchor_of _ = anchor in
  check "a damage event is accepted"
    (Float_text.say_event t (Battle.Damage ("foe", 3)) ~anchor_of 0.0);
  check_int "and leaves one message live" (Float_text.count t) 1;
  check "a turn boundary is declined"
    (not (Float_text.say_event t (Battle.TurnEnd 2) ~anchor_of 0.0));
  check_int "and adds nothing" (Float_text.count t) 1;
  Float_text.clear t;
  check "clearing empties it" (Float_text.count t = 0)

let test_stacking () =
  (* Two messages at the same anchor must not land on the same line. The original's
     stack is a linked list with a parent pointer and the second caller of a pair
     sits below the first; what matters visually is only that they do not overlap. *)
  let t = Float_text.create () in
  Float_text.say t ~subject:Float_text.Both ~anchor "first" 0.0;
  Float_text.say t ~subject:Float_text.Both ~anchor "second" 0.0;
  let ys =
    List.map (fun (m : Float_text.message) -> m.Float_text.anchor.Font_layout.y0)
      (Float_text.ordered t)
  in
  check "stacked messages are on different lines" (List.length ys = 2 && List.hd ys <> List.nth ys 1);
  check "the second is below the first by one step"
    (List.nth ys 1 = List.hd ys + Float_text.stack_step)

let test_stack_is_bounded () =
  (* One cascade emits mana events faster than they expire, so the stack has to be
     bounded or a column of "+1"s walks off the bottom of the screen and takes the
     damage number with it. The original bounds it too, as a fixed ring of 60-unit
     slots, so this is not a compromise. *)
  let t = Float_text.create () in
  let say_one i =
    Float_text.say t ~subject:Float_text.Foe ~anchor (string_of_int i) 0.0
  in
  for i = 1 to 40 do
    say_one i
  done;
  check_int "the stack never exceeds its bound" (Float_text.count t) Float_text.max_stack;
  (* At the cap the newest arrives and the oldest is the one that goes, which is
     what keeps what the player is looking at on screen. *)
  let texts = List.map (fun (m : Float_text.message) -> m.text) (Float_text.ordered t) in
  check "the newest message is present" (List.mem "40" texts);
  check "and the oldest has been dropped" (not (List.mem "1" texts))

let test_stack_depth_resets () =
  (* Depth is recomputed on expiry, not decremented: messages do not necessarily
     expire in the order they were stacked, and a drifting depth is a stack that
     slowly walks up the screen.

     The partial expiry has to be built deliberately - messages born at the same
     instant expire together, so three messages all born at t=0 would leave the
     depth at three and prove nothing. *)
  let top_y t =
    (* [live] is newest-first, [ordered] is oldest-first - and this wants the
       newest, since that is the message that just took a slot. *)
    let m = List.hd t.Float_text.live in
    m.anchor.Font_layout.y0
  in
  let t = Float_text.create () in
  Float_text.say t ~subject:Float_text.Both ~anchor "old" 0.0;
  Float_text.say t ~subject:Float_text.Both ~anchor "new" 0.5;
  check_int "two are stacked" (Float_text.count t) 2;
  check "the second is one step down" (top_y t = Float_text.stack_step);
  (* Just after the first expires and before the second does. *)
  Float_text.tick t (0.5 +. Float_text.default_life -. 0.01);
  check_int "only the older one has gone" (Float_text.count t) 1;
  Float_text.say t ~subject:Float_text.Both ~anchor "newest" 0.0;
  check "so the next message takes the freed slot, not a new one"
    (top_y t = Float_text.stack_step);
  (* And when the stack empties the depth goes back to the anchor. *)
  Float_text.tick t (0.5 +. Float_text.default_life +. 0.01);
  check "the stack empties" (Float_text.count t = 0);
  Float_text.say t ~subject:Float_text.Both ~anchor "after" 0.0;
  check "and the next message starts at the anchor again" (top_y t = 0)

let () =
  test_every_tag_resolves ();
  test_damage ();
  test_mana ();
  test_set_pieces ();
  test_quiet_events ();
  test_lifetime ();
  test_many ();
  test_ordering ();
  test_stacking ();
  test_stack_is_bounded ();
  test_stack_depth_resets ();
  test_say_event ();
  if !failures = 0 then print_endline "all float text tests passed"
  else begin
    Printf.printf "%d float text test(s) failed\n" !failures;
    exit 1
  end