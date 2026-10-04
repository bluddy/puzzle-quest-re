(* Does SDL3 actually work on this machine?

   Everything about the graphics front rests on three things that can each fail
   quietly, so this checks them in order and says which one broke:

     1. ctypes-foreign finds libffi and can dlopen the DLL at all;
     2. SDL_Init succeeds, and reports which SDL3 version answered - the bindings
        are generated against 3.4.12, so a much older DLL would bind calls that
        are not there;
     3. a window and a renderer can actually be created and a frame presented.

   Run it with the library pointed at a real SDL3 build, for example:

     $env:SDL3_LIBRARY="C:\\Program Files (x86)\\Steam\\SDL3.dll"
     dune exec bin/sdl3_probe.exe
 *)

(* [open Sdl3] brings [Sdl3.Sdl] into scope as [Sdl], which is the flat
   namespace: SDL_Init is [Sdl.init] and the renderer functions are
   [Sdl.Renderer.*]. The other entry point, [Sdl3.Categories], is the same
   functions grouped by which SDL header they came from. *)
open Sdl3

let go = Result.get_ok

let die what e =
  Printf.printf "  FAIL  %s: %s\n" what e;
  exit 1

let () =
  Printf.printf "probing SDL3\n";
  (match Sdl.init Sdl.init_video with
  | Error (`Msg e) -> die "SDL_Init" e
  | Ok () -> Printf.printf "  ok    SDL_Init\n");
  Printf.printf "  ok    SDL version %d (bindings target 3.4.12)\n"
    (Sdl.Version.get ());
  match Sdl.create_window_and_renderer "sdl3 probe" 320 240 Sdl.window_resizable with
  | Error (`Msg e) -> die "SDL_CreateWindowAndRenderer" e
  | Ok (_window, renderer) ->
      Printf.printf "  ok    SDL_CreateWindowAndRenderer\n";
      Sdl.Renderer.set_logical_presentation renderer 320 240
        Sdl.logical_presentation_letterbox
      |> go;
      Sdl.Renderer.set_draw_color_float renderer 0.10 0.20 0.40
        Sdl.alpha_opaque_float
      |> go;
      Sdl.Renderer.clear renderer |> go;
      Sdl.Renderer.present renderer |> go;
      Printf.printf "  ok    clear + present\n";
      Sdl.quit ();
      Printf.printf "  ok    SDL_Quit\n";
  Printf.printf "\nSDL3 works.\n"