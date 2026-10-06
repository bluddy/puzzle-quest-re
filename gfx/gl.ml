(** The OpenGL backend: window, context, and a sprite batcher.

    This is the only file in the project that names [Tgl3]. Everything the game
    draws goes through it, which is what keeps the swap to [Tgles3] for Android
    down to one file - see [tools/graphics_plan.md].

    Two details are deliberate and were both learned the hard way from the probe
    in bin/gl_probe.ml:

    - **The GLSL version line is chosen here**, not written into each shader.
      Desktop wants [330 core], Android wants [300 es], and the bodies are
      otherwise identical for 2D work. rails inlines "#version 330 core" in its
      shader strings, which would turn the Android step into a search across the
      tree.
    - **Pixel data is a c-layout char bigarray.** That is tgls's [bigarray] type,
      and it is what glTexImage2D takes. *)

open Tsdl.Sdl

module B = Bigarray

(* ------------------------------------------------------------------ shaders -- *)

(* The only line that differs between desktop GL and GLES. *)
let version_header = "#version 330 core\n"

let common_preamble =
  "layout(location = 0) in vec2 a_position;\n\
   layout(location = 1) in vec2 a_tex_coord;\n"

let vertex_src =
  version_header ^ common_preamble
  ^ "out vec2 v_uv;\n\
     void main() {\n\
     \  gl_Position = vec4(a_position, 0.0, 1.0);\n\
     \  v_uv = a_tex_coord;\n\
     }"

(* Sprites: sample the sheet, tint, and throw away near-transparent texels so a
   sprite in an atlas does not show its neighbours' edges. *)
let textured_frag_src =
  version_header
  ^ "uniform sampler2D tex;\n\
     uniform vec4 u_color_mod;\n\
     in vec2 v_uv;\n\
     out vec4 FragColor;\n\
     void main() {\n\
     \  vec4 c = texture(tex, v_uv);\n\
     \  if (c.a < 0.02) discard;\n\
     \  FragColor = c * u_color_mod;\n\
     }"

(* Solid fills: the board background, selection highlights, bars. *)
let colour_frag_src =
  version_header
  ^ "uniform vec4 u_color;\n\
     out vec4 FragColor;\n\
     void main() { FragColor = u_color; }"

(* ------------------------------------------------------------------ helpers -- *)

let get_int f =
  let a = B.(Array1.create int32 c_layout 1) in
  f a;
  Int32.to_int a.{0}

let get_string len f =
  let a = B.(Array1.create char c_layout len) in
  f a;
  Tgl3.Gl.string_of_bigarray a

let compile_shader src typ =
  let sid = Tgl3.Gl.create_shader typ in
  Tgl3.Gl.shader_source sid src;
  Tgl3.Gl.compile_shader sid;
  if get_int (Tgl3.Gl.get_shaderiv sid Tgl3.Gl.compile_status) = Tgl3.Gl.true_ then
    Ok sid
  else
    let len = get_int (Tgl3.Gl.get_shaderiv sid Tgl3.Gl.info_log_length) in
    let log = get_string len (Tgl3.Gl.get_shader_info_log sid len None) in
    Tgl3.Gl.delete_shader sid;
    Error log

let create_program vs_src fs_src =
  let vs = match compile_shader vs_src Tgl3.Gl.vertex_shader with Ok s -> s | Error e -> failwith e in
  let fs = match compile_shader fs_src Tgl3.Gl.fragment_shader with Ok s -> s | Error e -> failwith e in
  let p = Tgl3.Gl.create_program () in
  Tgl3.Gl.attach_shader p vs;
  Tgl3.Gl.attach_shader p fs;
  Tgl3.Gl.link_program p;
  if get_int (Tgl3.Gl.get_programiv p Tgl3.Gl.link_status) = Tgl3.Gl.true_ then p
  else
    let len = get_int (Tgl3.Gl.get_programiv p Tgl3.Gl.info_log_length) in
    failwith (get_string len (Tgl3.Gl.get_program_info_log p len None))

(* ------------------------------------------------------------------- types -- *)

type texture = int  (** A GL texture name. *)

type context = {
  w : Tsdl.Sdl.window;
  mutable width : int;
  mutable height : int;
  gl : Tsdl.Sdl.gl_context;
  prog_textured : int;
  prog_colour : int;
  loc_tex : int;
  loc_tex_mod : int;
  loc_colour : int;
  vao : int;
  vbo : int;
  mutable buf : (float, B.float32_elt) Tsdl.Sdl.bigarray;
  mutable n_verts : int;
}

let max_quads = 8192

(** Create the window, the GL context and the two programs.

    Requests a core profile 3.3 context, which is what the shaders are written
    against. *)
let create ~title ~width ~height : context =
  init Init.video |> Result.get_ok;
  gl_set_attribute Gl.context_profile_mask Gl.context_profile_core |> Result.get_ok;
  gl_set_attribute Gl.context_major_version 3 |> Result.get_ok;
  gl_set_attribute Gl.context_minor_version 3 |> Result.get_ok;
  let w =
    create_window title ~w:width ~h:height Window.(opengl + shown)
    |> Result.get_ok
  in
  let gl = gl_create_context w |> Result.get_ok in
  let prog_textured = create_program vertex_src textured_frag_src in
  let prog_colour = create_program vertex_src colour_frag_src in
  let vao = get_int (Tgl3.Gl.gen_vertex_arrays 1) in
  let vbo = get_int (Tgl3.Gl.gen_buffers 1) in
  Tgl3.Gl.bind_vertex_array vao;
  Tgl3.Gl.bind_buffer Tgl3.Gl.array_buffer vbo;
  let loc a p = Tgl3.Gl.get_uniform_location p a in
  {
    w;
    width;
    height;
    gl;
    prog_textured;
    prog_colour;
    loc_tex = loc "tex" prog_textured;
    loc_tex_mod = loc "u_color_mod" prog_textured;
    loc_colour = loc "u_color" prog_colour;
    vao;
    vbo;
    buf = B.(Array1.create float32 c_layout (max_quads * 4 * 4));
    n_verts = 0;
  }

(* ----------------------------------------------------------------- textures -- *)

(** Upload 8-bit RGBA pixels as a texture.

    [data] is a c-layout char bigarray of [w * h * 4] bytes, row-major, which is
    what imagelib hands back. *)
let texture_of_rgba ?(filter = `Nearest) ~(w : int) ~(h : int) data =
  let t = get_int (Tgl3.Gl.gen_textures 1) in
  Tgl3.Gl.bind_texture Tgl3.Gl.texture_2d t;
  let filt = match filter with `Nearest -> Tgl3.Gl.nearest | `Linear -> Tgl3.Gl.linear in
  Tgl3.Gl.tex_parameteri Tgl3.Gl.texture_2d Tgl3.Gl.texture_min_filter filt;
  Tgl3.Gl.tex_parameteri Tgl3.Gl.texture_2d Tgl3.Gl.texture_mag_filter filt;
  Tgl3.Gl.tex_parameteri Tgl3.Gl.texture_2d Tgl3.Gl.texture_wrap_s
    Tgl3.Gl.clamp_to_edge;
  Tgl3.Gl.tex_parameteri Tgl3.Gl.texture_2d Tgl3.Gl.texture_wrap_t
    Tgl3.Gl.clamp_to_edge;
  Tgl3.Gl.tex_image2d Tgl3.Gl.texture_2d 0 Tgl3.Gl.rgba8 w h 0 Tgl3.Gl.rgba
    Tgl3.Gl.unsigned_byte (`Data data);
  t

(** Upload an RGBA bigarray of [w * h * 4] bytes. *)
let texture_of_bigarray ~(w : int) ~(h : int) (data : (char, B.int8_unsigned_elt) Tsdl.Sdl.bigarray) =
  texture_of_rgba ~filter:`Linear ~w ~h data

let destroy_texture (t : texture) =
  (* tgls takes a uint32 bigarray for the array forms, so a single-element one. *)
  let a = B.(Array1.create int32 c_layout 1) in
  a.{0} <- Int32.of_int t;
  Tgl3.Gl.delete_textures 1 a

(* ------------------------------------------------------------------- batch -- *)

(* Quads accumulate into one interleaved buffer (x, y, u, v) and upload once per
   frame. Consecutive quads sharing a texture are drawn as a single run, so a board
   drawn gem by gem is one draw call per gem run rather than one per gem - and when
   the real atlas lands, a whole row of same-sheet gems collapses into one. *)

(** One batched draw.

    [clip] is a scissor rectangle in window pixels, or [None] for the whole
    window. It lives on the run rather than being toggled around [push_quad]
    because **the batcher does not draw when you push** - vertices accumulate and
    [submit] issues every draw at the end of the frame. A scissor set before
    pushing the gems and cleared straight after is therefore still set when
    [submit] runs, and clips everything in the frame; a scissor set and cleared
    before [submit] clips nothing at all. State has to travel with the run that
    wants it. *)
type run = {
  first : int;
  count : int;
  tex : texture option;
  colour : Layout.colour;
  clip : Layout.rect option;
}

let buf_set v i x = v.{i} <- x

(** Append one quad. Returns the index of its first vertex, which the caller needs
    to record the run it belongs to.

    [uv] is a rectangle in the source image's own {e pixel} coordinates and is
    normalised here, because GL texture coordinates run 0..1 across the whole
    texture. Passing pixel values straight through compiles, runs, and draws
    nothing at all - the sampler clamps outside 0..1 and the quad comes out black.
    [tex_size] is the source image's dimensions; pass (0, 0) for a solid quad,
    which has no texture and ignores it. *)
let push_quad ?(tex_size = (0, 0)) (win : context) (dst : Layout.rect)
    (uv : Layout.rect option) (col : Layout.colour) : int =
  if win.n_verts + 6 > max_quads * 4 then failwith "Pq_gfx: sprite batch overflow";
  let v = win.buf in
  let n = win.n_verts in
  (* Pixel space to clip space, flipping y because window space grows downwards
     and clip space grows upwards. *)
  let cx x = (float_of_int x /. float_of_int win.width) *. 2.0 -. 1.0 in
  let cy y = 1.0 -. (float_of_int y /. float_of_int win.height) *. 2.0 in
  let x0 = cx dst.x and x1 = cx (dst.x + dst.w) in
  let y0 = cy dst.y and y1 = cy (dst.y + dst.h) in
  let tw, th = tex_size in
  let nx v = if tw > 0 then float_of_int v /. float_of_int tw else 0.0 in
  let ny v = if th > 0 then float_of_int v /. float_of_int th else 0.0 in
  let u0, v0, u1, v1 =
    match uv with
    | None -> (0.0, 0.0, 0.0, 0.0)
    | Some r -> (nx r.x, ny r.y, nx (r.x + r.w), ny (r.y + r.h))
  in
  let emit i px py pu pv =
    let o = (n + i) * 4 in
    buf_set v o px;
    buf_set v (o + 1) py;
    buf_set v (o + 2) pu;
    buf_set v (o + 3) pv
  in
  (* Two triangles. *)
  emit 0 x0 y0 u0 v0;
  emit 1 x1 y0 u1 v0;
  emit 2 x0 y1 u0 v1;
  emit 3 x0 y1 u0 v1;
  emit 4 x1 y0 u1 v0;
  emit 5 x1 y1 u1 v1;
  ignore col;
  win.n_verts <- n + 6;
  n

(** Colours go to the uniform, not the vertex buffer, so they are held per run. *)
let begin_frame (win : context) =
  win.n_verts <- 0;
  Tgl3.Gl.viewport 0 0 win.width win.height;
  Tgl3.Gl.clear_color 0.07 0.07 0.10 1.0;
  Tgl3.Gl.clear Tgl3.Gl.color_buffer_bit;
  Tgl3.Gl.enable Tgl3.Gl.blend;
  Tgl3.Gl.blend_func Tgl3.Gl.src_alpha Tgl3.Gl.one_minus_src_alpha

(** Confine one run's drawing to a rectangle, in window pixels.

    The scissor is applied inside [submit], per run, which is why it is a field of
    [run] rather than a pair of calls around the pushes.

    The framebuffer is flipped ([dump_png] exists because of it), so scissor
    coordinates are bottom-up, unlike everything else here. Getting that wrong
    clips the wrong end of the board, which looks like a rendering bug rather than
    a coordinate one. Used to keep gems that drop in from above the top row inside
    the board instead of painting over the title art. *)
let clip_rect (win : context) (rect : Layout.rect) =
  Tgl3.Gl.enable Tgl3.Gl.scissor_test;
  Tgl3.Gl.scissor rect.Layout.x (win.height - rect.Layout.y - rect.Layout.h) rect.Layout.w
    rect.Layout.h

let submit (win : context) (runs : run list) =
  if win.n_verts = 0 then ()
  else begin
    Tgl3.Gl.bind_vertex_array win.vao;
    Tgl3.Gl.bind_buffer Tgl3.Gl.array_buffer win.vbo;
    Tgl3.Gl.buffer_data Tgl3.Gl.array_buffer
      (Tgl3.Gl.bigarray_byte_size win.buf)
      (Some win.buf) Tgl3.Gl.dynamic_draw;
    let stride = 4 * 4 in
    Tgl3.Gl.enable_vertex_attrib_array 0;
    Tgl3.Gl.vertex_attrib_pointer 0 2 Tgl3.Gl.float false stride (`Offset 0);
    Tgl3.Gl.enable_vertex_attrib_array 1;
    Tgl3.Gl.vertex_attrib_pointer 1 2 Tgl3.Gl.float false stride (`Offset 8);
    (* Set the run's colour and draw it in the SAME pass. Doing all the uniform
       sets first and then all the draws looks equivalent and is not: by the time
       the first draw happens every uniform already holds the {e last} run's value,
       so the whole frame comes out one colour. That bug shipped a board that was
       entirely the final button's blue. *)
    List.iter
      (fun (r : run) ->
        let c = (r : run).colour in
        let cr = float_of_int c.Layout.r /. 255.0 in
        let cg = float_of_int c.Layout.g /. 255.0 in
        let cb = float_of_int c.Layout.b /. 255.0 in
        let ca = float_of_int c.Layout.a /. 255.0 in
        (* The run's scissor, if it has one. Applied here rather than at push time
           because this is where the drawing actually happens. *)
        (match r.clip with
        | None -> Tgl3.Gl.disable Tgl3.Gl.scissor_test
        | Some rect -> clip_rect win rect);
        (match r.tex with
        | Some t ->
            Tgl3.Gl.use_program win.prog_textured;
            Tgl3.Gl.active_texture Tgl3.Gl.texture0;
            Tgl3.Gl.bind_texture Tgl3.Gl.texture_2d t;
            if win.loc_tex >= 0 then Tgl3.Gl.uniform1i win.loc_tex 0;
            if win.loc_tex_mod >= 0 then
              Tgl3.Gl.uniform4f win.loc_tex_mod cr cg cb ca
        | None ->
            Tgl3.Gl.use_program win.prog_colour;
            if win.loc_colour >= 0 then
              Tgl3.Gl.uniform4f win.loc_colour cr cg cb ca);
        Tgl3.Gl.draw_arrays Tgl3.Gl.triangles r.first r.count)
      runs;
    win.n_verts <- 0
  end

let present (win : context) =
  Tgl3.Gl.flush ();
  gl_swap_window win.w

let destroy (win : context) =
  Tsdl.Sdl.destroy_window win.w;
  quit ()

(** Read the framebuffer back as 8-bit RGBA, top row first.

    glReadPixels returns rows bottom-to-top, so this flips while copying -
    otherwise every screenshot is upside down, which is the kind of thing that
    wastes an afternoon. Used by [bin/pq_play_gfx.ml --shot] to diagnose what was
    actually drawn, rather than guessing from a description of it. *)
let read_frame_rgba ~(width : int) ~(height : int) : (char, B.int8_unsigned_elt) Tsdl.Sdl.bigarray =
  let raw = B.(Array1.create char c_layout (width * height * 4)) in
  Tgl3.Gl.finish ();
  Tgl3.Gl.read_pixels 0 0 width height Tgl3.Gl.rgba Tgl3.Gl.unsigned_byte
    (`Data raw);
  let out = B.(Array1.create char c_layout (width * height * 4)) in
  let row = width * 4 in
  for y = 0 to height - 1 do
    let src = (height - 1 - y) * row in
    let dst = y * row in
    for i = 0 to row - 1 do
      out.{dst + i} <- raw.{src + i}
    done
  done;
  out

let gl_string which = match Tgl3.Gl.get_string which with Some s -> s | None -> "?"

let renderer_name () = gl_string Tgl3.Gl.renderer
let gl_version () = gl_string Tgl3.Gl.version