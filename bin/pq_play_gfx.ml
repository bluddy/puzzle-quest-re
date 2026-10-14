(** An interactive battle in a window: the ASCII runner's counterpart.

    The battle logic is the same [Battle] the headless tools drive, and the human
    still chooses through the same two hooks - this only replaces what was a
    [read_line] with a window and a mouse. Nothing about the recovered rules is
    re-implemented here.

    The whole front now lives in [Pq_gfx.Battle_screen], which the world map
    also hosts so quest, callback and road fights are played rather than
    bannered; this executable is the standalone driver over it. *)

let () = Pq_gfx.Battle_screen.standalone ()
