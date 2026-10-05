(** Reading an image file into pixels.

    Shared by [Assets], [Skin] and [Font], which between them read every image
    this project draws. It lives in its own module because the only thing they
    have in common is the decode, and [Assets.load_rgba] grew a sheet-size
    assertion that is about the gem sheet specifically, not about images.

    Named for the formats rather than for the general case. Both are read in pure
    OCaml by [imagelib] - PNG through its own decoder, JPEG through `ImageLib.JPG`
    - so there is no ImageMagick and no native image library, which is the same
    reason rails' `imagelib.unix` is deliberately not used here: it shells out to
    `convert`, and a second system dependency on a build machine buys nothing.

    **JPEG matters more than it looks.** The game's backdrop is a JPEG
    (`Skin_Backdrop_Standard.jpg`), and it is the one decoration that cannot be
    substituted - a battle screen without it is a black rectangle. An earlier
    version of the graphics plan deferred JPEG on the grounds that the 63 of them
    are backgrounds and none were needed for a board; true, and it left the one
    image the screen is mostly made of unreadable.

    Calling this module [Image] would shadow the [Image] alias that imagelib
    exports, which is its own kind of confusing inside a file whose job is calling
    [Image.read_rgba]. *)

module B = Bigarray

type rgba = (char, B.int8_unsigned_elt) Tsdl.Sdl.bigarray

(** Call [f] with the format extension in whichever spelling this build of
    imagelib accepts.

    This is fussier than it looks, and it is a portability hazard worth writing
    down. `ImageLib.openfile` and `ImageLib.size` both dispatch on
    `List.mem (lowercase ext) ImagePNG.extensions` and do nothing else - no
    stripping, no normalising - and the two builds of imagelib disagree about what
    is in those lists:

    - the opam release lists them **without** a dot: `["png"]`
    - the `jpeg-codec` fork this project pins lists them **with** one: `[".png"]`

    So `"png"` works against the release and raises `Not_yet_implemented "png"`
    against the fork, while `"jpg"` raises against the release because the fork is
    what wires JPEG into `openfile` at all. An extension that neither build accepts
    fails at {e runtime}, on the first image decoded, which is the worst place to
    find out - and it fails as an exception rather than a compile error, so nothing
    catches it until a window is open.

    Hence the fallback. It costs one extra attempt per image and buys independence
    from which build is installed, which matters because the pin is recorded in
    opam's state rather than in this repository. *)
let try_both ext f =
  let attempt e = try Some (f e) with Image.Not_yet_implemented _ -> None in
  match attempt ("." ^ ext) with Some v -> v | None ->
  match attempt ext with
  | Some v -> v
  | None ->
      failwith (Printf.sprintf "Png.load_rgba: imagelib does not handle '%s'" ext)

let size_of ext (reader : unit -> ImageUtil.chunk_reader) : int * int =
  try_both ext (fun e -> ImageLib.size ~extension:e (reader ()))

let parse (ext : string) (reader : unit -> ImageUtil.chunk_reader) : Image.image =
  try_both ext (fun e -> ImageLib.openfile ~extension:e (reader ()))

let extension_of (path : string) : string =
  let n = String.length path in
  let ends s = n >= String.length s && String.sub path (n - String.length s) (String.length s) = s in
  if ends ".jpg" || ends ".jpeg" then "jpg" else "png"

(** Decode an image into a c-layout char bigarray of RGBA bytes, top row first.

    That is the shape tgls wants for [glTexImage2D], so nothing is repacked
    between decoding and upload. The format comes from the extension, which is why
    [extension_of] is exposed rather than hardcoded: it is the one place that has
    to agree with imagelib. *)
let load_rgba (path : string) : rgba * int * int =
  let ext = extension_of path in
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let bytes = Bytes.create len in
  really_input ic bytes 0 len;
  close_in ic;
  let reader () = ImageUtil.chunk_reader_of_string (Bytes.unsafe_to_string bytes) in
  let w, h = size_of ext reader in
  let img = parse ext reader in
  let out = B.(Array1.create char c_layout (w * h * 4)) in
  let set i r g b a =
    out.{i} <- Char.chr (r land 0xFF);
    out.{i + 1} <- Char.chr (g land 0xFF);
    out.{i + 2} <- Char.chr (b land 0xFF);
    out.{i + 3} <- Char.chr (a land 0xFF)
  in
  (* [Image.read_rgba img x y f] calls [f] with the pixel's r, g, b, a - the
     coordinates go in, four channel values come back. The callback's own type is
     [int -> int -> int -> int -> 'a], so a lambda taking six arguments silently
     half-applies instead of failing, which is why this is spelled as an explicit
     double loop. *)
  for y = 0 to h - 1 do
    for x = 0 to w - 1 do
      Image.read_rgba img x y (fun r g b a ->
          set (((y * w) + x) * 4) r g b a)
    done
  done;
  (out, w, h)