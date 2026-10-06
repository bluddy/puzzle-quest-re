(** Floating text: the numbers that appear over a character as things happen.

    The engine already says what happened - `Battle.event` has 21 variants of it,
    and `Battle.on_event` hands them over as they occur rather than in a batch at
    the end of the turn. This turns the ones a player needs to see into text, in
    the game's own message fonts, positioned by the recovered rule.

    Two things here are a port and one is a choice, and they are worth separating:

    - **Positioning is a port.** [Font_layout.place_message] is a transcription of
      the float-text positioning in `Engine_ADD_TEXT_MESSAGE_415120`, down to the
      20px margin and the near-edge rule overriding the far-edge one.
    - **Which message an event produces is a choice.** The engine's float text is
      driven by spell scripts calling `ADD_TEXT_MESSAGE`, and a headless battle has
      no scripts running - the effects are inlined. So the mapping from a damage
      event to a red number is ours. It is not recovered, and it is not claimed to
      be.
    - **The colours are recovered.** The seven `font_msg_*` styles in
      `<Language>/Font.xml` are exactly a message palette, and `FUN_004c9950`
      shows the default colour coming from the font record rather than from the
      caller - so naming the font names the colour, as [Font] already does.

    The subject is carried alongside the text because a message has to know *whose*
    it is: damage to the foe belongs over the foe. Which side of the board that
    is comes from the caller, since only the caller knows where anything is drawn. *)

open Puzzle_quest_lib

(** Who a message is about, so the caller can put it on the right side. *)
type subject = Hero | Foe | Both

(** How a subject becomes a position. Only the caller knows where anything is
    drawn, so this is supplied rather than computed. *)
type anchor_of = subject -> Font_layout.box

(** A message waiting to be drawn. *)
type message = {
  text : string;
  (** The `font_msg_*` tag, so the font supplies its own colour. *)
  font : string;
  subject : subject;
  anchor : Font_layout.box;
  born : float;
  life : float;
}

type t = { mutable live : message list; mutable depth : int }

let create () : t = { live = []; depth = 0 }

(** How long a message stays up, in seconds. Long enough to read a three-digit
    number, short enough that a cascade does not leave a wall of them. *)
let default_life = 1.1

(* ------------------------------------------------------------ the mapping -- *)

(** The message an event produces, if it is one worth showing.

    Returns the text, the `font_msg_*` tag, and who it is about. [None] means the
    event is bookkeeping - a turn starting, a swap being made - and the log says
    it but the player does not need to read it.

    The element colours are the one inference in here. `Board.Mana`'s order is the
    board's, and the game's own colours for the four elements are already in
    `Layout.gem_colour`; the message palette has no blue, so water takes cyan,
    which is the colour the original's float text uses for it. *)
let of_event (e : Battle.event) : (string * string * subject) option =
  match e with
  | Battle.Damage (_, n) -> Some (Printf.sprintf "-%d" n, "font_msg_red", Foe)
  | Battle.ManaGained (_, _, n) ->
      Some (Printf.sprintf "+%d" n, "font_msg_green", Hero)
  | Battle.ExtraTurn _ -> Some ("Extra Turn", "font_msg_yellow", Both)
  | Battle.HeroicEffort _ -> Some ("Heroic Effort!", "font_msg_orange", Both)
  | Battle.ManaBurn -> Some ("Mana Burn", "font_msg_cyan", Both)
  | Battle.SpellCast (_, id) -> Some (id, "font_msg_white", Both)
  | Battle.Death name -> Some (name ^ " falls", "font_msg_red", Both)
  | Battle.BattleEnd Battle.HeroVictory -> Some ("Victory", "font_msg_green", Both)
  | Battle.BattleEnd Battle.EnemyVictory -> Some ("Defeat", "font_msg_red", Both)
  (* Everything else is a turn boundary, a swap, a banked turn, gold, XP or a
       refill: all of it is in the log for the tools that want it, and none of it
       is something a player needs watching for. *)
  | _ -> None

(* --------------------------------------------------------------- lifetime -- *)

(** How many messages will stack at one anchor.

    The original's stack is bounded: the decompilation reads
    `(list_end - list_start) / 0x3c` as *the number of 60-unit slots in the
    message stack*, used to find the last entry's base offset - and
    `FUN_004c9950` caps the draw queue at 100 strings in fixed-size slots. So this
    is a ring, not a list that grows.

    Which is exactly what an unbounded stack gets wrong here: one cascade emits
    mana events faster than they expire, the column grows past the bottom of the
    screen, and the messages that matter - a damage number - are pushed off it by
    a run of "+1"s. Capping it and letting the newest take the oldest slot keeps
    what a player is looking at on screen. *)
let stack_step = 26
let max_stack = 8

let say (t : t) ?(life = default_life) ?(font = "font_msg_white") ~subject
    ~(anchor : Font_layout.box) (text : string) (now : float) =
  let m = { text; font; subject; anchor; born = now; life } in
  if t.depth < max_stack then begin
    (* Each new message goes below the ones already there. *)
    let placed =
      { anchor with
        Font_layout.y0 = anchor.Font_layout.y0 + (t.depth * stack_step);
        y1 = anchor.Font_layout.y1 + (t.depth * stack_step) }
    in
    t.depth <- t.depth + 1;
    t.live <- { m with anchor = placed } :: t.live
  end
  else begin
    (* At the cap: the stack is a ring, so the new message takes the slot the
       oldest one was in - at the top, which is the position that is about to be
       least visible anyway. *)
    let oldest = List.rev t.live in
    (match oldest with
    | [] -> ()
    | _ :: rest ->
        let kept = List.rev rest in
        t.live <- m :: kept;
        t.depth <- max_stack)
  end

(** Add the message for an event, if it has one. *)
let say_event (t : t) (e : Battle.event) ~(anchor_of : anchor_of) (now : float) : bool =
  match of_event e with
  | None -> false
  | Some (text, font, subject) ->
      say t ~font ~subject ~anchor:(anchor_of subject) text now;
      true

(** Drop the messages whose time is up, and restack what remains.

    The stack depth is recomputed rather than decremented, because the messages
    expire in age order but not necessarily in the order they were stacked, and a
    depth that drifts is a stack that slowly walks off the top of the screen. *)
let tick (t : t) (now : float) =
  t.live <- List.filter (fun m -> now -. m.born < m.life) t.live;
  t.depth <- List.length t.live

let clear (t : t) =
  t.live <- [];
  t.depth <- 0

let count (t : t) = List.length t.live

(** Oldest first, so a newer message draws on top of an older one rather than
    being covered by it. The list is newest-first internally, because dropping
    expired messages off the front is the common case and that is O(n) either
    way - but the drawing order is what this fixes. *)
let ordered (t : t) = List.rev t.live

(* ---------------------------------------------------------------- drawing -- *)

(** Draw every live message, placed by the recovered rule.

    The anchor was resolved when the message was made, by [say_event]'s
    [anchor_of], so nothing here needs to know where characters are - which is
    what keeps this module free of the board's geometry.

    [metrics_of] resolves a `font_msg_*` tag. A tag with no atlas simply draws
    nothing, so a missing font degrades to no text rather than to an exception in
    the middle of a battle. *)
let draw (win : Gl.context) (fonts : Font.t) (t : t) ~(screen_w : int)
    ~(screen_h : int) ~(metrics_of : string -> Font_layout.metrics option)
    : Gl.run list =
  List.concat_map
    (fun (m : message) ->
      match metrics_of m.font with
      | None -> []
      | Some mm ->
          let w = Font_layout.measure mm m.text in
          let h = Font_layout.measure_height mm m.text in
          let placed =
            Font_layout.place_message ~screen_w ~screen_h ~text_w:w ~text_h:h
              m.anchor
          in
          Font.draw win fonts mm m.text ~x:placed.Font_layout.x0
            ~y:placed.Font_layout.y0)
    (ordered t)