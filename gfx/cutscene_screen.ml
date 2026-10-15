(* The cutscene player: the slideshow timeline, its viewport clip, and the
   timed subtitle lines - the whole of the outer/inner XML pair that
   tools/extract_cutscenes.py turns into [Cutscene_data].

   The model follows the shipped descriptors exactly:

   - The scene runs for [scene.duration] wall milliseconds; the front feeds
     [step] its frame [dt] the same way it feeds [Conv_window.step], so a
     headless harness can drive it too.
   - Every Display whose [start, start+dur) window covers the clock draws its
     placement, in document order (later displays layer over earlier ones -
     how Chap1's fade-to-black sits over the pan). Keys interpolate linearly
     against the display's own start: "alpha" tints the quad's colour, "y"
     offsets the image's placement - Chap1's slow pan is exactly that. With
     no keys the image shows at full alpha, unmoved - the logo slides are
     hard cuts.
   - The viewport from the descriptor clips every image run (the chapter art
     is 1024x630 inside a 0,128,1024x512 band, so without the scissor it
     would spill over the subtitles at texty=652). Image id 0 of the logo
     slides is a placed off-screen thumb: its displays draw nothing and the
     frame reads black, which is what the slideshow comments call them.
   - The current cue - the last whose time has passed, in the CURRENT
     language - draws centred under the band, wrapped to the screen; the
     logo slides have none. The voice path and snd_cutscene are recorded in
     the data but unwired: the port's asset extraction ships no cutscene
     audio (port.cutscene_shell).

   Any click or Escape skips, a port choice - the original's cutscene
   manager is an opaque singleton (0x4aa0d0) and the shipped descriptors
   carry no on-screen skip affordance. *)

open Puzzle_quest_lib
open Cutscene_data

type t = {
  scene : scene;
  images : (int * (Gl.texture * int * int)) list;
      (** slideshow bitmap index -> the loaded art *)
  mutable elapsed : float;  (** seconds since create *)
  mutable finished : bool;
}

let load_slide (scene : scene) : (int * (Gl.texture * int * int)) list =
  List.filter_map
    (fun (i, path) ->
      if path = "" then None
      else Option.map (fun img -> (i, img)) (Conv_window.load_conv_image path))
    (List.mapi (fun i path -> (i, path)) scene.slide.bitmaps)

let create (scene : scene) : t =
  { scene; images = load_slide scene; elapsed = 0.0; finished = false }

let step (t : t) (dt : float) : unit =
  if not t.finished then begin
    t.elapsed <- t.elapsed +. dt;
    if t.elapsed *. 1000.0 >= float_of_int t.scene.duration then
      t.finished <- true
  end

let finished (t : t) : bool = t.finished

let skip (t : t) : unit = t.finished <- true

(** Linear interpolation of one key channel against the display-local clock:
    the value holds before the first key and after the last, and ramps
    linearly in between. [default] when the display keys nothing. *)
let key_value (keys : key list) (param : string) (local_ms : float)
    (default : float) : float =
  match List.filter (fun k -> k.param = param) keys with
  | [] -> default
  | first :: _ as ks ->
    let last = List.fold_left (fun _ b -> b) first ks in
    if local_ms <= float_of_int first.time then first.value
    else if local_ms >= float_of_int last.time then last.value
    else
      let rec bracket prev = function
        | [] -> last.value
        | b :: rest ->
          let tb = float_of_int b.time in
          if local_ms <= tb then begin
            let ta = float_of_int prev.time in
            if tb <= ta then b.value
            else
              prev.value
              +. ((b.value -. prev.value)
                 *. ((local_ms -. ta) /. (tb -. ta)))
          end
          else bracket b rest
      in
      match ks with
      | f :: rest -> bracket f rest
      | [] -> default

let placement_of (scene : scene) (image_id : int) : placement option =
  List.find_opt (fun p -> p.image_id = image_id) scene.slide.placements

(** The cue on screen now: the last line whose time has arrived, in the
    current language - switched live, like every other string. *)
let current_cue (scene : scene) (now_ms : float) : cue option =
  let lang = !Text_data.language in
  let lang =
    if lang >= 0 && lang < Array.length scene.cues then lang else 0
  in
  let acc = ref None in
  Array.iter
    (fun c -> if float_of_int c.time_ms <= now_ms then acc := Some c)
    scene.cues.(lang);
  !acc

let draw (rs : Gl.run list ref) (gl : Gl.context) (fonts : Font.t option)
    (system : Font_layout.metrics option) (t : t) : unit =
  if not t.finished then begin
    let scene = t.scene in
    let now_ms = t.elapsed *. 1000.0 in
    let vx, vy, vw, vh = scene.slide.viewport in
    let clip = Some { Layout.x = vx; y = vy; w = vw; h = vh } in
    let colour_of a =
      let al = int_of_float (255.0 *. max 0.0 (min 1.0 a)) in
      Layout.rgba 255 255 255 al
    in
    List.iter
      (fun d ->
        let start = float_of_int d.start_ms in
        let stop = start +. float_of_int d.dur_ms in
        if now_ms >= start && now_ms < stop then begin
          let local = now_ms -. start in
          match placement_of scene d.image with
          | None -> ()
          | Some p ->
            (match List.assoc_opt p.bitmap t.images with
            | None -> ()
            | Some (tex, iw, ih) ->
              let alpha = key_value d.keys "alpha" local 1.0 in
              let dy = int_of_float (key_value d.keys "y" local 0.0) in
              let dst =
                {
                  Layout.x = vx + p.x;
                  y = vy + p.y + dy;
                  w = p.w;
                  h = p.h;
                }
              in
              let first =
                Gl.push_quad ~tex_size:(iw, ih) gl dst
                  (Some { Layout.x = 0; y = 0; w = iw; h = ih })
                  (colour_of alpha)
              in
              rs :=
                !rs
                @ [
                    {
                      Gl.first;
                      count = 6;
                      tex = Some tex;
                      colour = colour_of alpha;
                      clip;
                      blend = None;
                    };
                  ])
        end)
      scene.slide.displays;
    (* Subtitles under the band, centred on textx and wrapped to the screen
       the dialogue box wraps to - drawn after the images so the fading art
       can never cover the line. *)
    match (current_cue scene now_ms, fonts, system) with
    | Some cue, Some ff, Some m ->
      if cue.text <> "" then begin
        let lines =
          Conv_window.wrap_lines
            (fun s -> Font_layout.measure m s)
            (1024 - 32)
            cue.text
        in
        List.iteri
          (fun i line ->
            let w = Font_layout.measure m line in
            rs :=
              !rs
              @ Font.draw gl ff m ~colour:(Layout.rgb 240 240 240) line
                  ~x:(scene.textx - (w / 2))
                  ~y:(scene.texty + (i * 20)))
          lines
      end
    | _ -> ()
  end