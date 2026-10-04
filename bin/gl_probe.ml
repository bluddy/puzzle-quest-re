(* Does the SDL2 + OpenGL stack work here?

   The third probe, and it exists because "tsdl has no GL bindings" was true and
   also beside the point: [tgls] supplies them, binding OpenGL 3 and 4 {e and}
   OpenGL ES 2 and 3, so one dependency covers desktop and Android alike. That is
   why the graphics front is not blocked on SDL3's immature bindings.

   Each of these fails independently and silently, so each is checked:

     1. SDL2 opens a window with an OpenGL context (core profile, 3.3 requested);
     2. the driver reports what it actually gave us - a software rasteriser will
        happily accept a "3.3 core" context and then be miserable;
     3. a shader compiles and links, which is what breaks first on a driver more
        forgiving than the spec;
     4. a textured, alpha-blended quad reaches the framebuffer.

   The shape follows src/engine/utils/opengl.ml in the rails project, which is
   where this stack comes from.

     dune exec bin/gl_probe.exe
 *)

open Tsdl.Sdl

let get_exn = function Ok x -> x | Error (`Msg e) -> failwith e

module BA = Bigarray

let get_int f =
  let a = BA.(Array1.create int32 c_layout 1) in
  f a;
  Int32.to_int a.{0}

let get_string len f =
  let a = BA.(Array1.create char c_layout len) in
  f a;
  Tgl3.Gl.string_of_bigarray a

let die stage detail =
  Printf.printf "  FAIL  %s: %s\n" stage detail;
  exit 1

(* [die] above is unit-returning as far as the type system is concerned, which
   warns where it is used in tail position of an [if]. This is the same function
   with a polymorphic return, so the compiler knows it never comes back. *)
let fail stage detail : 'a =
  Printf.printf "  FAIL  %s: %s\n" stage detail;
  exit 1

(* The smallest useful shader: one textured quad, tinted, alpha blended. This is
   the shape every sprite in the game will use. The version directive is the one
   thing that differs between desktop GL and GLES, which is why it is the only
   part that will move behind lib/gfx when Android arrives. *)
let vert_src =
  {|#version 330 core
layout(location = 0) in vec2 a_position;
layout(location = 1) in vec2 a_tex_coord;
out vec2 v_uv;
void main() {
  gl_Position = vec4(a_position, 0.0, 1.0);
  v_uv = a_tex_coord;
}|}

let frag_src =
  {|#version 330 core
uniform sampler2D tex;
uniform vec4 u_color_mod;
in vec2 v_uv;
out vec4 FragColor;
void main() {
  vec4 c = texture(tex, v_uv);
  if (c.a < 0.01) discard;
  FragColor = c * u_color_mod;
}|}

let compile_shader src typ =
  let sid = Tgl3.Gl.create_shader typ in
  Tgl3.Gl.shader_source sid src;
  Tgl3.Gl.compile_shader sid;
  if get_int (Tgl3.Gl.get_shaderiv sid Tgl3.Gl.compile_status) = Tgl3.Gl.true_
  then Ok sid
  else
    let len = get_int (Tgl3.Gl.get_shaderiv sid Tgl3.Gl.info_log_length) in
    let log = get_string len (Tgl3.Gl.get_shader_info_log sid len None) in
    Tgl3.Gl.delete_shader sid;
    Error log

let gl_str which = match Tgl3.Gl.get_string which with Some s -> s | None -> "?"

(* A 2x2 RGBA checkerboard as raw bytes, which is how tgls hands pixel data to
   glTexImage2D: a c-layout char bigarray, four bytes per pixel, row-major. *)
let checkerboard () =
  let px = BA.(Array1.create char c_layout (2 * 2 * 4)) in
  let put i r g b =
    px.{i + 0} <- Char.chr r;
    px.{i + 1} <- Char.chr g;
    px.{i + 2} <- Char.chr b;
    px.{i + 3} <- Char.chr 255
  in
  put 0 255 0 0;
  put 4 0 255 0;
  put 8 0 0 255;
  put 12 255 255 255;
  px

let () =
  Printf.printf "probing SDL2 + OpenGL via tgls\n";
  init Init.video |> Result.map (fun () -> ()) |> get_exn;
  Printf.printf "  ok    SDL_Init(VIDEO)\n";
  gl_set_attribute Gl.context_profile_mask Gl.context_profile_core |> get_exn;
  gl_set_attribute Gl.context_major_version 3 |> get_exn;
  gl_set_attribute Gl.context_minor_version 3 |> get_exn;
  let width = 320 and height = 240 in
  let window =
    create_window "gl probe" ~w:width ~h:height Window.(opengl + shown)
    |> get_exn
  in
  Printf.printf "  ok    window with opengl flag\n";
  let _ctx = gl_create_context window |> get_exn in
  Printf.printf "  ok    GL context (core 3.3 requested)\n";
  Printf.printf "  info  GL_VERSION  %s\n" (gl_str Tgl3.Gl.version);
  Printf.printf "  info  GL_RENDERER %s\n" (gl_str Tgl3.Gl.renderer);
  gl_swap_window window;

  (* --- texture upload --- *)
  let tex = get_int (Tgl3.Gl.gen_textures 1) in
  Tgl3.Gl.bind_texture Tgl3.Gl.texture_2d tex;
  Tgl3.Gl.tex_parameteri Tgl3.Gl.texture_2d Tgl3.Gl.texture_min_filter
    Tgl3.Gl.nearest;
  Tgl3.Gl.tex_parameteri Tgl3.Gl.texture_2d Tgl3.Gl.texture_mag_filter
    Tgl3.Gl.nearest;
  (* The eight fixed glTexImage2D arguments, then the pixels. Pixels go over as
     a c-layout char bigarray, which is what tgls calls [bigarray]. *)
  Tgl3.Gl.tex_image2d Tgl3.Gl.texture_2d 0 Tgl3.Gl.rgba8 2 2 0 Tgl3.Gl.rgba
    Tgl3.Gl.unsigned_byte (`Data (checkerboard ()));
  Printf.printf "  ok    glTexImage2D upload\n";

  (* --- program --- *)
  let vs =
    match compile_shader vert_src Tgl3.Gl.vertex_shader with
    | Ok s -> s
    | Error e -> die "vertex shader" e
  in
  let fs =
    match compile_shader frag_src Tgl3.Gl.fragment_shader with
    | Ok s -> s
    | Error e -> die "fragment shader" e
  in
  let prog = Tgl3.Gl.create_program () in
  Tgl3.Gl.attach_shader prog vs;
  Tgl3.Gl.attach_shader prog fs;
  Tgl3.Gl.link_program prog;
  if get_int (Tgl3.Gl.get_programiv prog Tgl3.Gl.link_status) = Tgl3.Gl.true_ then
    Printf.printf "  ok    shader compile + link\n"
  else begin
    let len = get_int (Tgl3.Gl.get_programiv prog Tgl3.Gl.info_log_length) in
    fail "link" (get_string len (Tgl3.Gl.get_program_info_log prog len None))
  end;
  Tgl3.Gl.use_program prog;

  (* --- geometry: one quad, position + uv interleaved --- *)
  let vao = get_int (Tgl3.Gl.gen_vertex_arrays 1) in
  let vbo = get_int (Tgl3.Gl.gen_buffers 1) in
  Tgl3.Gl.bind_vertex_array vao;
  Tgl3.Gl.bind_buffer Tgl3.Gl.array_buffer vbo;
  let verts = BA.(Array1.create float32 c_layout (4 * 4)) in
  let put i x y u v =
    verts.{i} <- x;
    verts.{i + 1} <- y;
    verts.{i + 2} <- u;
    verts.{i + 3} <- v
  in
  put 0 (-0.8) (-0.8) 0. 0.;
  put 4 0.8 (-0.8) 1. 0.;
  put 8 (-0.8) 0.8 0. 1.;
  put 12 0.8 0.8 1. 1.;
  (* tgls takes the bigarray itself; the byte size is passed separately. *)
  Tgl3.Gl.buffer_data Tgl3.Gl.array_buffer
    (Tgl3.Gl.bigarray_byte_size verts)
    (Some verts) Tgl3.Gl.static_draw;
  let stride = 4 * 4 in
  Tgl3.Gl.enable_vertex_attrib_array 0;
  Tgl3.Gl.vertex_attrib_pointer 0 2 Tgl3.Gl.float false stride (`Offset 0);
  Tgl3.Gl.enable_vertex_attrib_array 1;
  Tgl3.Gl.vertex_attrib_pointer 1 2 Tgl3.Gl.float false stride (`Offset 8);

  (* --- draw --- *)
  Tgl3.Gl.viewport 0 0 width height;
  Tgl3.Gl.clear_color 0.10 0.10 0.15 1.0;
  Tgl3.Gl.clear Tgl3.Gl.color_buffer_bit;
  Tgl3.Gl.enable Tgl3.Gl.blend;
  Tgl3.Gl.blend_func Tgl3.Gl.src_alpha Tgl3.Gl.one_minus_src_alpha;
  Tgl3.Gl.active_texture Tgl3.Gl.texture0;
  Tgl3.Gl.bind_texture Tgl3.Gl.texture_2d tex;
  (* get_uniform_location returns a plain int here, -1 when the name is absent. *)
  let loc_tex = Tgl3.Gl.get_uniform_location prog "tex" in
  let loc_mod = Tgl3.Gl.get_uniform_location prog "u_color_mod" in
  if loc_tex < 0 || loc_mod < 0 then
    Printf.printf "  warn  uniform not found (tex=%d mod=%d)\n" loc_tex loc_mod
  else begin
    Tgl3.Gl.uniform1i loc_tex 0;
    Tgl3.Gl.uniform4f loc_mod 1. 1. 1. 1.;
    Printf.printf "  ok    uniforms\n"
  end;
  Tgl3.Gl.draw_arrays Tgl3.Gl.triangles 0 3;
  Tgl3.Gl.flush ();
  gl_swap_window window;
  Printf.printf "  ok    draw + swap\n";
  destroy_window window;
  quit ();
  Printf.printf "\nSDL2 + OpenGL works.\n"