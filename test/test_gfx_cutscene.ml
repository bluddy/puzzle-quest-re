(* The cutscene descriptors: what tools/extract_cutscenes.py pins from the
   shipped XML, checked without a context - the timeline arithmetic, the
   lookup the scripts use, and the per-language cue layer. The rendering
   itself is proven by the --intro shot (the ESRB slide lands fullscreen);
   this file is the data under it.

   Every bitmap path is checked for existence on disk too, through the
   repository walk-up (dune runs tests inside _build, so game/Assets is
   three parents away, not one) - with a skip note rather than a failure
   when the checkout cannot be found from here. *)

open Pq_gfx
open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let rec repo_root dir depth =
  if depth > 6 then None
  else if Sys.file_exists (Filename.concat dir "game/Assets") then Some dir
  else repo_root (Filename.dirname dir) (depth + 1)

let assets =
  match repo_root (Sys.getcwd ()) 0 with
  | Some r -> Some (Filename.concat r "game/Assets")
  | None ->
    print_endline "  note: game/Assets not reachable from here - bitmap checks skipped";
    None

let () =
  (* The lookup takes the scripts' own paths in any shape. *)
  check "a script path resolves"
    (Cutscene_data.scene_of "CutScenes\\Chap2_Intro.xml" <> None);
  check "a bare name resolves"
    (Cutscene_data.scene_of "Logo_ESRB_10" <> None);
  check "an unknown scene does not"
    (Cutscene_data.scene_of "Chap5_Never" = None);
  check "seventeen of the eighteen shipped scenes have their inner data"
    (List.length Cutscene_data.scenes = 17);

  (* The boot splash: the one scene the executable references (0x4d88f1). *)
  (match Cutscene_data.scene_of "Logo_ESRB_10" with
  | None -> check "the boot splash parses" false
  | Some sc ->
    check "the boot splash parses" true;
    check_int "its wall duration is the descriptor's 18500"
      sc.Cutscene_data.duration 18500;
    check_int "five slides carry the artwork"
      (List.length sc.Cutscene_data.slide.Cutscene_data.bitmaps) 5;
    check_int "eleven displays drive the timeline"
      (List.length sc.Cutscene_data.slide.Cutscene_data.displays) 11;
    check "the timeline starts at zero"
      (match sc.Cutscene_data.slide.Cutscene_data.displays with
      | d :: _ -> d.Cutscene_data.start_ms = 0
      | [] -> false);
    check "and is ordered, each window inside the slide's 16000"
      (let ds = sc.Cutscene_data.slide.Cutscene_data.displays in
       let rec ordered = function
         | a :: (b :: _ as rest) ->
           a.Cutscene_data.start_ms <= b.Cutscene_data.start_ms
           && a.Cutscene_data.start_ms + a.Cutscene_data.dur_ms <= 16000
           && ordered rest
        | [ last ] ->
          last.Cutscene_data.start_ms + last.Cutscene_data.dur_ms <= 16000
        | [] -> true
       in
       ordered ds);
    check "image 0 is the off-screen thumb every black display draws"
      (match
         Cutscene_data.scene_of "Logo_ESRB_10"
       with
      | Some s ->
        (match
           List.find_opt
             (fun p -> p.Cutscene_data.image_id = 0)
             s.Cutscene_data.slide.Cutscene_data.placements
         with
        | Some p -> p.Cutscene_data.y = 770
        | None -> false)
      | None -> false);
    (match assets with
    | None -> ()
    | Some root ->
      let missing =
        List.filter
          (fun p ->
            not (Sys.file_exists (Filename.concat root p)))
          sc.Cutscene_data.slide.Cutscene_data.bitmaps
      in
      check "every slide's JPEG ships" (missing = [])));

  (* The chapter art and its cue layer, in every language. *)
  (match Cutscene_data.scene_of "CutScenes\\Chap1_Intro.xml" with
  | None -> check "Chap1 parses" false
  | Some sc ->
    check "Chap1 parses" true;
    check_int "the chapter runs 30000 ms" sc.Cutscene_data.duration 30000;
    let vx, vy, vw, vh = sc.Cutscene_data.slide.Cutscene_data.viewport in
    check "the viewport is the band the descriptor names"
      ((vx, vy, vw, vh) = (0, 128, 1024, 512));
    check "the subtitle anchor sits under it"
      ((sc.Cutscene_data.textx, sc.Cutscene_data.texty) = (512, 652));
    check "four cues in English"
      (Array.length sc.Cutscene_data.cues.(0) = 4);
    check "four cues in French"
      (Array.length sc.Cutscene_data.cues.(1) = 4);
    check "and they differ - the cue layer really is translated"
      (sc.Cutscene_data.cues.(0).(0).text
      <> sc.Cutscene_data.cues.(1).(0).text);
    check "the voices are per language"
      (sc.Cutscene_data.voice.(0) <> sc.Cutscene_data.voice.(1));
    check "the pan is keyframed on the long display"
      (match sc.Cutscene_data.slide.Cutscene_data.displays with
      | _ :: second :: _ -> List.length second.Cutscene_data.keys = 4
      | _ -> false);

    (* The cue on screen: last line whose time has arrived, live by
       language. *)
    let t0 = Cutscene_screen.current_cue sc 0.0 in
    check "nothing shows before the first cue" (t0 = None);
    let t1 = Cutscene_screen.current_cue sc 1500.0 in
    check "the first line shows once its time comes"
      (match t1 with
      | Some c -> c.Cutscene_data.time_ms = 1000
      | None -> false);
    Text_data.set_language 1;
    let fr = Cutscene_screen.current_cue sc 1500.0 in
    check "switching language switches the live cue"
      (match fr with
      | Some c -> c.Cutscene_data.text = sc.Cutscene_data.cues.(1).(0).text
      | None -> false);
    Text_data.set_language 0);

  (* The key interpolation: alpha ramps, y pans, and a channel the display
     does not key falls back. *)
  let keys : Cutscene_data.key list =
    [
      { Cutscene_data.param = "alpha"; value = 0.0; time = 0 };
      { Cutscene_data.param = "alpha"; value = 1.0; time = 1000 };
      { Cutscene_data.param = "y"; value = -118.0; time = 0 };
      { Cutscene_data.param = "y"; value = 0.0; time = 27000 };
    ]
  in
  let near a b = abs_float (a -. b) < 0.001 in
  check "alpha holds at its first key"
    (near (Cutscene_screen.key_value keys "alpha" (-500.0) 1.0) 0.0);
  check "alpha ramps linearly"
    (near (Cutscene_screen.key_value keys "alpha" 500.0 1.0) 0.5);
  check "alpha holds after its last key"
    (near (Cutscene_screen.key_value keys "alpha" 5000.0 1.0) 1.0);
  check "y pans half the distance at half the time"
    (near (Cutscene_screen.key_value keys "y" 13500.0 0.0) (-59.0));
  check "an unkeyed channel takes the default"
    (near (Cutscene_screen.key_value keys "z" 500.0 0.7) 0.7)

let () =
  if !failures = 0 then print_endline "all cutscene data tests passed"
  else begin
    Printf.printf "%d cutscene data test(s) failed\n" !failures;
    exit 1
  end
