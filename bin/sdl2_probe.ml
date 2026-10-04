(* Does SDL2 actually work on this machine?

   The companion to bin/sdl3_probe.ml, written for the same reason: before
   building a renderer on a windowing library, prove it initialises, opens a
   window, creates a renderer and presents a frame on this box. Each can fail on
   its own - a missing DLL, no video subsystem, no usable renderer driver - and
   none is obvious until it is.

   It asks for an accelerated renderer and says so if it has to fall back to the
   software one, because "I asked for OpenGL" and "I got a CPU blitter" are very
   different outcomes and SDL will quietly give you the latter.

     dune exec bin/sdl2_probe.exe
 *)

open Tsdl.Sdl

let go = Result.get_ok

let die what e =
  Printf.printf "  FAIL  %s: %s\n" what e;
  exit 1

(** Open a window and draw a few frames into it. *)
let probe w kind r =
  Printf.printf "  ok    SDL_CreateRenderer (%s)\n" kind;
  set_render_draw_color r 40 60 120 255 |> go;
  render_clear r |> go;
  render_fill_rect r (Some (Rect.create ~x:20 ~y:20 ~w:120 ~h:80)) |> go;
  render_present r;
  Printf.printf "  ok    clear + fill + present\n";
  (* Pump a few frames so a crash on the event path shows up here rather than in
     the real front end. *)
  for _ = 1 to 3 do
    ignore (poll_event None);
    render_present r;
    delay 16l
  done;
  Printf.printf "  ok    event pump\n";
  destroy_renderer r;
  destroy_window w;
  quit ();
  Printf.printf "  ok    teardown + SDL_Quit\n"

let () =
  Printf.printf "probing SDL2\n";
  (match init Init.video with
  | Error (`Msg e) -> die "SDL_Init(VIDEO)" e
  | Ok () -> Printf.printf "  ok    SDL_Init(VIDEO)\n");
  match create_window "sdl2 probe" ~w:320 ~h:240 Window.shown with
  | Error (`Msg e) -> die "SDL_CreateWindow" e
  | Ok w ->
      (match create_renderer ~flags:Renderer.accelerated w with
      | Error (`Msg e) ->
          (* Not fatal. Fall back so the probe still proves the pipeline, but say
             so plainly rather than reporting a pass. *)
          Printf.printf "  note  accelerated renderer unavailable: %s\n" e;
          (match create_renderer w with
          | Error (`Msg e2) -> die "SDL_CreateRenderer" e2
          | Ok r -> probe w "software" r)
      | Ok r -> probe w "accelerated" r)