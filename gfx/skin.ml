(** The screen's decoration, addressed by the tags the game itself uses.

    Every coordinate here comes from `Skin_data`, which is
    `Assets/Assets.xml` - the engine's own bitmap registry - rather than from
    anything measured by eye. That matters more for decoration than it does for
    gems: a border is a rectangle cut to fit a 1024x768 screen exactly, and an
    eyeballed one is visibly wrong in a way a slightly-off gem is not.

    What the registry gives is a [frame]: a rectangle in a sheet, plus the size it
    is meant to be *drawn* at. Those differ - the red glow frames are 88x88 on
    disk and 64x64 on screen - so [draw_rect] applies the scale rather than
    ignoring it, which is the whole reason the destination size is in the table.

    Nothing here is required. A missing sheet costs its decoration and nothing
    else: the board still draws, the HUD still reads, and the border is simply
    absent. That is deliberate, because the art is copyrighted and not committed,
    so a fresh checkout has none of it. *)

open Puzzle_quest_lib

type t = {
  gl : Gl.context;
  (* Sheet tag -> its texture and pixel size. Only the sheets something asked for
     get loaded. *)
  sheets : (string, sheet) Hashtbl.t;
}

and sheet = { texture : Gl.texture; tex_w : int; tex_h : int }

(** The tags whose geometry the layout itself depends on.

    Named here rather than in the caller because they are not decoration choices:
    the board's top inset {e is} the border's height, so if the art changes and
    these tags stop matching anything the layout quietly falls back to
    [default_top_inset] instead of insetting by a stale number. *)
let frame_tag_top = "img_border_top"
let frame_tag_backdrop = "img_backdrop"
let default_top_inset = 95

(** Where the sheets were extracted to, overridable like [Font.face_dir]. *)
let dir () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p -> p
  | _ -> "assets/gfx"

(** The file for a sheet tag, extension included.

    The registry stores the path without deciding on a decoder, and the extension
    is what [Png] dispatches on, so it is reattached here from what actually
    exists rather than assumed - a JPG read as a PNG is a hard error, not a
    fallback. *)
let sheet_path (tag : string) : string option =
  match Skin_data.sheet_of_tag tag with
  | None -> None
  | Some s ->
      let base = Filename.concat (dir ()) (Filename.basename s.Skin_data.file) in
      let jpg = base ^ ".jpg" and png = base ^ ".png" in
      if Sys.file_exists jpg then Some jpg
      else if Sys.file_exists png then Some png
      else None

(** Load the given sheets, reporting any that are absent.

    Takes the sheet {e tags}, not frames: the registry groups frames by sheet and
    a caller asking for `img_border_top` and `img_border_left` should not decode
    the backdrop twice.

    This always succeeds. The result is a [t] whether or not anything loaded,
    because "the decoration is absent" is not a different kind of screen - it is
    the same screen with some [draw] calls returning false. Returning an option
    would push that check onto every call site instead of keeping it in one
    place, and would make the missing-art case a second code path through the
    renderer. *)
let create ~(gl : Gl.context) ~(sheets : string list) : t =
  let loaded = Hashtbl.create 8 in
  List.iter
    (fun tag ->
      if not (Hashtbl.mem loaded tag) then
        match sheet_path tag with
        | None ->
            Printf.printf "  no sheet %s in %s - that decoration will be absent\n"
              tag (dir ())
        | Some path -> (
            try
              let px, w, h = Png.load_rgba path in
              Hashtbl.replace loaded tag
                { texture = Gl.texture_of_bigarray ~w ~h px; tex_w = w; tex_h = h }
            with e ->
              Printf.printf "  skin sheet %s failed to load: %s\n" path
                (Printexc.to_string e)))
    sheets;
  if Hashtbl.length loaded = 0 then
    Printf.printf "  no decoration sheets in %s - run tools/extract_gfx_assets.py\n"
      (dir ());
  { gl; sheets = loaded }

(** Where a frame goes on screen, given the rectangle it should occupy.

    [place] is where the frame is drawn and [w] x [h] the space available; the
    destination size from the registry decides the result, and [place] only
    decides where. Frames whose destination size is missing fall back to the
    stored size, which is what the registry means by omitting it. *)
let draw_rect (f : Skin_data.frame) ~(place : Layout.rect) : Layout.rect =
  { place with w = f.Skin_data.dest_w; h = f.Skin_data.dest_h }

(** The source rectangle for a frame, in the sheet's own pixels. *)
let uv (f : Skin_data.frame) : Layout.rect =
  { Layout.x = f.Skin_data.x; y = f.Skin_data.y; w = f.Skin_data.w; h = f.Skin_data.h }

let sheet_of (t : t) (tag : string) : sheet option = Hashtbl.find_opt t.sheets tag

(** A sheet's texture and size, or nothing if that sheet was not loaded.

    For drawing something a descriptor names rather than a decoration tag: the spell
    effects give a sheet tag (`bmp_skin_battlemisc`) and a rectangle in its own
    pixels, so the caller needs the texture *and* the sheet's dimensions to turn
    that rectangle into texture coordinates. *)
let sheet_texture (t : t) (tag : string) : (Gl.texture * int * int) option =
  match Hashtbl.find_opt t.sheets tag with
  | Some s -> Some (s.texture, s.tex_w, s.tex_h)
  | None -> None

(** Draw a named frame into [place], appending to the frame's run list.

    Returns [None] when the tag is unknown or its sheet was not loaded, so a
    missing decoration is a no-op rather than a black rectangle. *)
let draw (t : t) (runs : Gl.run list ref) ?(colour = Layout.rgba 255 255 255 255)
    (tag : string) ~(place : Layout.rect) : bool =
  match Skin_data.frame_of_tag tag with
  | None -> false
  | Some f -> (
      match sheet_of t f.Skin_data.sheet with
      | None -> false
      | Some s ->
          let dst = draw_rect f ~place in
          let first =
            Gl.push_quad ~tex_size:(s.tex_w, s.tex_h) t.gl dst (Some (uv f)) colour
          in
          runs := !runs @ [ { Gl.first; count = 6; tex = Some s.texture; colour; clip = None; blend = None } ];
          true)

(** Draw a named frame centred in [place] horizontally and vertically. *)
let draw_centred_in (t : t) (runs : Gl.run list ref) ?colour tag ~place : bool =
  match Skin_data.frame_of_tag tag with
  | None -> false
  | Some f ->
      let w = f.Skin_data.dest_w and h = f.Skin_data.dest_h in
      draw t runs ?colour tag
        ~place:{ place with x = place.Layout.x + ((place.Layout.w - w) / 2);
                 y = place.Layout.y + ((place.Layout.h - h) / 2) }

(** A frame's drawn size, or [None] if the tag is unknown.

    Useful for geometry that should follow the art rather than a number someone
    typed: the top inset is the border's own height, so if the art ever changes
    the layout follows it. *)
let frame_size (tag : string) : (int * int) option =
  match Skin_data.frame_of_tag tag with
  | None -> None
  | Some f -> Some (f.Skin_data.dest_w, f.Skin_data.dest_h)

(** How tall the top of the screen furniture is, in pixels.

    Taken from the border and top-panel frames, which are both 95px - so this is
    read from the registry rather than assumed, and falls back to 95 if the art
    is missing. The board is inset by it, which is the difference between the
    board sitting under the panel and sitting below it. *)
let top_inset () : int =
  match frame_size frame_tag_top with
  | Some (_, h) -> h
  | None -> default_top_inset

let destroy (t : t) =
  Hashtbl.iter (fun _ (s : sheet) -> Gl.destroy_texture s.texture) t.sheets