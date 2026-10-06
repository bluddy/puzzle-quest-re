(** Sound: the mixer, and the registry's sound tags made audible.

    [PLAY_SOUND] in the original is small and worth quoting, because one line of it
    is a behaviour rather than a detail - see [play].

    Chunks are loaded **lazily**, by tag, the first time a sound is asked for.
    The archive holds 83 of them and a battle uses perhaps a dozen; decoding all of
    them up front would cost time and memory for sounds that never fire. The
    registry says which tags exist and which have audio behind them
    ([Skin_data.sound_file]), so a tag with no file is answered without touching the
    disk.

    Every failure here is **silent by design**. A machine with no audio device, a
    checkout with no sounds extracted, a tag the registry does not have - none of
    them should stop a battle, and none of them should print once per event. The one
    exception is the first failure of a given kind, which is reported once so a
    missing sound bank is discoverable rather than merely absent. *)

open Puzzle_quest_lib

type t = {
  mutable chunks : (string, Tsdl_mixer.Mixer.chunk) Hashtbl.t;
  mutable live : (string, int) Hashtbl.t;  (** tag -> the channel it is on *)
  mutable available : bool;
  mutable reported : bool;
  (** How many sounds have actually been started.

      Not decoration. Whether this build has a working audio path is otherwise
      invisible - there is no error, the battle plays, and the only symptom is
      silence, which is indistinguishable from a correct quiet moment. A counter
      the screenshot harness can print turns "is it wired up" into a question with
      an answer. *)
  mutable played : int;
}

let channels = 8

let create () : t =
  let t =
    { chunks = Hashtbl.create 32; live = Hashtbl.create 16; available = false;
      reported = false; played = 0 }
  in
  (* [Init.empty] asks for no decoders: the bank is WAV only, and asking for Ogg or
     MP3 support would be asking for libraries this build does not use. *)
  (match Tsdl_mixer.Mixer.init Tsdl_mixer.Mixer.Init.empty with
  | Error _ -> ()
  | Ok _ -> (
      match
        Tsdl_mixer.Mixer.open_audio Tsdl_mixer.Mixer.default_frequency
          Tsdl_mixer.Mixer.default_format Tsdl_mixer.Mixer.default_channels 1024
      with
      | Error _ -> ()
      | Ok () ->
          ignore (Tsdl_mixer.Mixer.allocate_channels channels);
          t.available <- true));
  if not t.available && not t.reported then begin
    Printf.printf "  no audio device - the battle runs silently\n";
    t.reported <- true
  end;
  t

let dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p -> p
  | _ -> "assets/gfx"

(** Play a sound by its registry tag, or do nothing.

    **The de-duplication is recovered.** `Engine_PLAY_SOUND_4b38a0` looks the name up
    in a map under a global manager and calls a virtual play method, but only if that
    entry is not already the active one. Both hazards are in the quote below - a C
    pointer cast ends in a star followed by a close-paren, and a dereference starts
    with the two characters that open a comment; OCaml comments nest, so either one
    pasted in verbatim breaks the docstring.

    ```c
    entry = FUN_004b28c0(local_4, &param_1);        // name -> entry
    if ((deref entry) != read_dword(iVar1 + 8) && ...) {
      // ...call the entry's play method through its vtable at +0x28
    }
    ```

    So a sound already sounding is not restarted. That matters more than it sounds:
    a cascade emits several `ManaGained` events in quick succession, and without the
    rule every one of them would cut the previous gain off and restart it, which is
    a click rather than a sound.

    Note the asymmetry that is *not* modelled: the original compares against one
    "currently active" entry globally, so two different sounds never overlap from
    this path. Here each tag tracks its own channel, so a cascade's cascade sound and
    a damage sound can sound together. That is closer to what the game sounds like
    and it is a deliberate divergence, recorded as such.
*)
let play (t : t) (tag : string) : bool =
  if not t.available then false
  else
    let path =
      match Skin_data.sound_file tag with
      | None -> None
      | Some rel -> Some (Filename.concat (dir ()) rel)
    in
    match path with
    | None -> false
    | Some path ->
        (* Already sounding: leave it alone, which is the recovered rule. *)
        (match Hashtbl.find_opt t.live tag with
        | Some ch when Tsdl_mixer.Mixer.playing (Some ch) -> true
        | Some ch ->
            Hashtbl.remove t.live tag;
            ignore (Tsdl_mixer.Mixer.halt_channel ch);
            false
        | None -> false)
        |> fun already ->
        if already then true
        else
          let chunk =
            match Hashtbl.find_opt t.chunks tag with
            | Some c -> Some c
            | None ->
                if not (Sys.file_exists path) then None
                else (
                  match Tsdl_mixer.Mixer.load_wav path with
                  | Error _ -> None
                  | Ok c ->
                      Hashtbl.replace t.chunks tag c;
                      Some c)
          in
          match chunk with
          | None -> false
          | Some c ->
              (* A round-robin channel: the mixer picks, and a sound on a busy
                 channel is cut rather than queued, which is what a cascade of short
                 effects wants. *)
              let ch = (Hashtbl.length t.live + 1) mod channels in
              (match Tsdl_mixer.Mixer.play_channel ch c 0 with
              | Error _ -> false
              | Ok _ ->
                  Hashtbl.replace t.live tag ch;
                  t.played <- t.played + 1;
                  true)

(** Play several tags in order, as [HeroicEffort] does: the voice, then the
    effect.

    Every tag is attempted, not just up to the first that worked. [List.exists]
    short-circuits, which is exactly wrong here for two reasons that both look like
    silence rather than like a bug: the voice *does* sound, so the effect after it
    never does; and [play] returns [true] for a tag that is already sounding (the
    recovered de-duplication rule), so a repeated tag swallows the rest of the list.

    Returns whether any of them sounded, which is what a caller reporting "played"
    should mean. *)
let play_all (t : t) (tags : string list) : bool =
  List.fold_left (fun any tag -> play t tag || any) false tags

let destroy (t : t) =
  if t.available then begin
    Hashtbl.iter (fun _ c -> Tsdl_mixer.Mixer.free_chunk c) t.chunks;
    Tsdl_mixer.Mixer.close_audio ()
  end