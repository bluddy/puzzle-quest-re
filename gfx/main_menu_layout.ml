(* MainMenu.xml, transcribed: the screen's own geometry for the port's menu
   stage. The original draws no static background - the fullscreen
   <Icon name="icon_fx" graphic="img_mainmenufx"> is a UserGraphic behind a
   Lua callback (callback_mainmenufx), an animated water/ember effect the
   port has no native for, so the front paints the standard backdrop in its
   place (port.cutscene_shell); everything else here is the shipped file's
   own numbers, read at x/y/width/height as written.

   Buttons keep the XML's ids because they are the handler's vocabulary:
   21 New Quest, 22 Continue Quest, 1 Single Player, 2/4 Multiplayer,
   7 Settings, 5/6 High Scores, 0 Quit, 10 Buy Now, 100/101 the window
   chrome the port's fullscreen window has no use for and does not draw. *)

type button = {
  id : int;  (** the XML id - what the click handler switches on *)
  x : int;
  y : int;
  w : int;
  h : int;
  label_tag : string;  (** resolved through Text_data at draw, live *)
}

let buttons : button list =
  [
    { id = 21; x = 660; y = 180; w = 300; h = 50; label_tag = "[NEWQUEST]" };
    { id = 22; x = 660; y = 230; w = 300; h = 50;
      label_tag = "[CONTINUEQUEST]" };
    { id = 1; x = 660; y = 300; w = 300; h = 50;
      label_tag = "[SINGLEPLAYER]" };
    { id = 2; x = 660; y = 350; w = 300; h = 50;
      label_tag = "[MULTIPLAYER1]" };
    { id = 4; x = 660; y = 400; w = 300; h = 50;
      label_tag = "[MULTIPLAYER2]" };
    { id = 7; x = 660; y = 470; w = 300; h = 50; label_tag = "[SETTINGS]" };
    { id = 5; x = 660; y = 540; w = 300; h = 50;
      label_tag = "[BATTLEHISCORES]" };
    { id = 6; x = 660; y = 590; w = 300; h = 50; label_tag = "[MPHISCORES]" };
    { id = 0; x = 660; y = 670; w = 300; h = 50; label_tag = "[QUIT]" };
    (* [BUYNOW] (id 10, bottom-left) is demo-era storefront cruft - the
       Steam build ships it but it links nowhere a full game needs, so the
       port drops the button (port.cutscene_shell, on review). *)
  ]

(** str_title, str_version, str_copyright - the three Strings the menu
    carries besides the buttons, as (tag, x, y, w, justify) with justify
    as the XML's own: center / left / center. *)
let title = ("[MAINMENU]", 610, 110, 400, "center")
let version = ("[VERSION]", 30, 728, 300, "left")
let copyright = ("[COPYRIGHT]", 660, 728, 300, "center")

let button_at (mx : int) (my : int) : button option =
  List.find_opt
    (fun b ->
      mx >= b.x && mx < b.x + b.w && my >= b.y && my < b.y + b.h)
    buttons
