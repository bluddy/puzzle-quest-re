(** The gem sheet, and the frames cut out of it.

    The frames come from `Assets/Assets.xml`, which is the game's own bitmap
    registry and names them:

    | tag               | x   | y   | size  |
    | ----------------- | --- | --- | ----- |
    | img_gem_green     |   0 |   0 | 71x71 |
    | img_gem_red       |  72 |   0 | 71x71 |
    | img_gem_yellow    | 144 |   0 | 71x71 |
    | img_gem_blue      | 216 |   0 | 71x71 |
    | img_gem_scroll    |  72 | 216 | 71x71 |

    So the cells are 71x71 on a 72px pitch - **not** the 64px the placeholder
    board happened to use, and worth stating because it is the kind of number
    that silently looks fine.

    **What is recovered and what is not.** Only those four mana gems are named in
    the registry. Skull, red skull, gold, experience and the wildcard multipliers
    are {e not}: the engine addresses them by raw coordinates, so their positions
    here are read off the sheet by eye and are marked inferred. [frame] returns
    [None] where no frame could be identified at all, and the caller falls back to
    a flat colour rather than drawing the wrong sprite.

    Row 0 is the base gems, and it is seven cells of seven, in this order:

    | cell | sprite            | gem                      |
    | ---- | ----------------- | ------------------------ |
    | 0    | green orb         | [Board.Mana Board.Earth] |
    | 1    | red orb           | [Board.Mana Board.Fire]  |
    | 2    | yellow orb        | [Board.Mana Board.Air]   |
    | 3    | blue orb          | [Board.Mana Board.Water] |
    | 4    | bone skull        | [Board.Skull]            |
    | 5    | purple star       | [Board.Experience]       |
    | 6    | gold coins        | [Board.Gold]             |

    Two of those deserve their reasoning kept, because the obvious reading is
    wrong for one of them.

    **The purple star is experience**, not a wildcard or a mana gem. That is
    corroborated rather than eyeballed: [Spell.GStar] is documented in
    [lib/spell.ml] as "the purple star, id 7 on the board", and the only
    star-shaped sprite in row 0 is a purple one. So the position is still
    inferred, but the identification is not.

    **Row 0 cell 4 is the plain skull, and there is no red skull in this sheet.**
    Cell 4 looks like a red skull - bone with glowing red eyes and a red mark on
    the forehead - which is exactly why it is worth saying. Rows 4 and 5 hold
    five more skulls that are visibly the {e same} sprite with "+5" and a red halo
    drawn over them. Those are the skull {e multiplier} overlays the game paints
    when a skull gem gains bonus power, not a distinct gem kind. So the sheet
    contains one skull, and [Board.RedSkull] has no frame here at all: its art, if
    it is drawn as a sprite, lives in another skin file.

    The colour-to-element mapping is also an inference, though a well-supported
    one: the sheet's row order is green, red, yellow, blue, which is the engine's
    own element order Earth, Fire, Air, Water - the same order as
    [Board.mana_element] and not the order [Board.gem] lists its constructors in.
    That transposition is a standing trap in this port. *)

open Puzzle_quest_lib

module B = Bigarray

let sheet_width = 512
let sheet_height = 512
let cell = 71
let pitch = 72

(** Read a PNG into a c-layout char bigarray of RGBA bytes, top row first.

    This is the shape tgls wants for glTexImage2D, so nothing is repacked
    between decoding and upload.

    [imagelib] decodes PNG in pure OCaml (it depends on [decompress]), so there is
    no ImageMagick requirement - unlike rails, which uses [imagelib.unix] and
    shells out to `convert` for formats OCaml cannot read. *)
let load_rgba (path : string) : (char, B.int8_unsigned_elt) Tsdl.Sdl.bigarray * int * int =
  let ic = open_in_bin path in
  let len = in_channel_length ic in
  let bytes = Bytes.create len in
  really_input ic bytes 0 len;
  close_in ic;
  let reader () = ImageUtil.chunk_reader_of_string (Bytes.unsafe_to_string bytes) in
  let w, h = ImageLib.size ~extension:"png" (reader ()) in
  if w <> sheet_width || h <> sheet_height then
    failwith
      (Printf.sprintf "gfx/assets: expected a %dx%d gem sheet, got %dx%d (%s)"
         sheet_width sheet_height w h path);
  let img = ImageLib.openfile ~extension:"png" (reader ()) in
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

(* Where each frame lives in the sheet. See the table above for the four named
   ones; the rest are read off the image and are inferred. *)
type provenance =
  | Named of string  (** a tag in Assets.xml - recovered *)
  | Inferred  (** read off the sheet by eye *)

let frame_rect : Board.gem -> (Layout.rect * provenance) option = function
  | Board.Mana Board.Earth -> Some ({ Layout.x = 0; y = 0; w = cell; h = cell }, Named "img_gem_green")
  | Board.Mana Board.Fire -> Some ({ Layout.x = 72; y = 0; w = cell; h = cell }, Named "img_gem_red")
  | Board.Mana Board.Air -> Some ({ Layout.x = 144; y = 0; w = cell; h = cell }, Named "img_gem_yellow")
  | Board.Mana Board.Water -> Some ({ Layout.x = 216; y = 0; w = cell; h = cell }, Named "img_gem_blue")
  | Board.Skull -> Some ({ Layout.x = 288; y = 0; w = cell; h = cell }, Inferred)
  (* The purple star, row 0 cell 5. See the module comment: identified as
     experience by [Spell.GStar], positioned by eye. *)
  | Board.Experience -> Some ({ Layout.x = 360; y = 0; w = cell; h = cell }, Inferred)
  | Board.Gold -> Some ({ Layout.x = 432; y = 0; w = cell; h = cell }, Inferred)
  (* Row 1 holds seven multiplier badges, x2 through x8, which is exactly the
     range [Board.Wildcard] carries. *)
  | Board.Wildcard n when n >= 2 && n <= 8 ->
      Some
        ( { Layout.x = (n - 2) * pitch; y = pitch; w = cell; h = cell },
          Inferred )
  (* No red skull in this sheet: the only skull sprite here is the plain one, and
     the red-glowing skulls on rows 4 and 5 are that same sprite with a "+5"
     multiplier overlay. See the module comment before adding a guess here. *)
  | Board.RedSkull -> None
  | Board.Wildcard _ -> None
  | Board.Empty -> None

(** The source region for a gem, or [None] where no frame was identified. *)
let frame (g : Board.gem) : Layout.rect option =
  match frame_rect g with Some (r, _) -> Some r | None -> None

let provenance_of (g : Board.gem) : provenance option =
  match frame_rect g with Some (_, p) -> Some p | None -> None

(** How many of a gem kind's frames are recovered rather than inferred, for the
    startup line. *)
let named_count =
  List.length
    (List.filter_map
       (fun g ->
         match frame_rect g with
         | Some (_, Named _) -> Some g
         | _ -> None)
       [ Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Air;
         Board.Mana Board.Water; Board.Skull; Board.RedSkull; Board.Gold;
         Board.Experience; Board.Wildcard 4 ])

(** Default sheet location, overridable so a test or a packager can point
    elsewhere. *)
let sheet_path () =
  match Sys.getenv_opt "PQ_GFX_ASSETS" with
  | Some p when Sys.file_exists p -> p
  | _ -> "assets/gfx/Skin_Gems_Grid.png"