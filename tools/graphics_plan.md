# Graphics plan

Superseded twice, and the current decision is the one this file argued against.
Both earlier versions are kept below the current section because the reasoning
that produced them is still what justifies the shape of the result.

## Decision

**SDL2 (`tsdl`) for the window, input and GL context. `tgls` for OpenGL.**

Verified on this machine before building on it, with `bin/gl_probe.exe`:

```
  ok    SDL_Init(VIDEO)
  ok    window with opengl flag
  ok    GL context (core 3.3 requested)
  info  GL_VERSION  3.3.0 - Build 32.0.101.7092
  info  GL_RENDERER Intel(R) Iris(R) Xe Graphics
  ok    glTexImage2D upload
  ok    shader compile + link
  ok    uniforms
  ok    draw + swap
```

A real hardware 3.3 core context, a shader that compiles and links, a texture
uploaded from a bigarray, and an alpha-blended textured quad reaching the
framebuffer. That is the entire foundation a sprite renderer needs.

### Why OpenGL, and why this is not the SDL3 problem

The first version of this plan said SDL3 was unusable and recommended dropping to
SDL2's own 2D renderer with no OpenGL at all. That was wrong twice over:

* **SDL2 + OpenGL is not blocked.** `tsdl` genuinely has no OpenGL bindings and no
  `SDL_GL_GetProcAddress` — that part was right — but **`tgls` supplies them**:
  "Thin bindings to OpenGL {3,4} and OpenGL ES {2,3} for OCaml", already installed,
  ctypes-based so function loading is handled. The gap was real and already solved.
* **This is not an improvisation.** The same stack runs the *rails* remake, so it
  is a proven one rather than a workaround. `src/engine/utils/opengl.ml`,
  `src/engine/utils/renderer.ml` and `src/engine/mainloop.ml` there are the
  reference for the context attributes, the program setup and the loop.

The `bin/sdl3_probe.ml` path also still works, and stays in the tree. It is simply
no longer the shortest road, because the SDL3 bindings would have needed a
hand-written `SDL3_image` binding anyway — which `imagelib` makes unnecessary here.

## Android: one dependency, two modules

This is the answer to "we'll want OpenGL ES?", and it is better than the ANGLE
scheme proposed in the previous version of this file. **No ANGLE is needed.**

`tgls` ships four backends: `tgl3`, `tgl4`, `tgles2`, `tgles3`. So the GL calls we
write are the same calls on both targets; only the module differs:

| | desktop | Android |
| --- | --- | --- |
| window, input, context | `Tsdl` | `Tsdl` |
| GL | `Tgl3` | `Tgles3` |
| GLSL | `#version 330 core` | `#version 300 es` |

That last row is the entire dialect problem, and it is one line per shader. The
shader *bodies* are otherwise identical between GLSL 330 core and GLSL ES 300 —
same `layout(location=)`, same `in`/`out`, same `texture()` — so the practical
difference is the version directive and, where a shader uses them, the handful of
GL3-only features (so none, so far, for 2D sprites).

Both changes are confined by putting them behind `lib/gfx`:

* `lib/gfx.ml` — the presentation layer: the game's concepts become draw calls.
* `lib/gfx_gl.ml` — the only file naming `Tgl3.`/`Tgles3.`, with the shader header
  chosen at construction.

## Image loading: no hand-written binding needed

Neither `tsdl` nor SDL2 decodes an image, and the game's art is 226 PNGs and 63
JPGs. Earlier versions of this plan said `SDL2_image` would have to be bound by
hand (~8 functions). **It does not have to be**: `imagelib` is already a
dependency here and decodes PNG in pure OCaml (`Image.PNG.ReadPNG`), so there is
no ctypes work and no ImageMagick requirement.

Note the difference from rails, which uses `imagelib.unix` and therefore leans on
ImageMagick for formats OCaml cannot read. We want the pure-OCaml path, because a
second system dependency on a build machine is a cost for no benefit.

The 63 JPGs are all backgrounds (`Skin_Backdrop_*.jpg`, `Cities.jpg`) and none are
needed for a board, so PNG-only is enough to start. JPG can wait for a
deliberate decision rather than blocking the first milestone.

Text still needs a decision: SDL2 has no font rendering, so `SDL2_ttf` or a bitmap
font of our own. Deferred until the board is on screen.

## What to reuse from rails

Three files, and the mapping is direct:

| rails | becomes |
| --- | --- |
| `src/engine/utils/renderer.ml` — `gl_set_attribute context_profile_core / 3 / 3`, `Window.opengl + shown`, `gl_create_context` | the context setup in `lib/gfx_gl.ml` |
| `src/engine/utils/opengl.ml` — shared vertex shader, textured and coloured fragment programs, VAO/VBO scratch quad | the sprite batcher |
| `src/engine/mainloop.ml` — 20Hz tick, 30Hz render, event pump, sleep when ahead | the frame loop |

The main loop is the one to lift almost verbatim. Separating a fixed-rate game tick
from a separately-clocked render is the right structure, and it is already written
and debugged.

One thing **not** to copy: the shaders are `#version 330 core` inline string
literals. They should live in one place with the version line chosen by the
backend, or step two of the Android plan becomes a find-and-replace across the
tree.

## Architecture

```
  lib/gfx.ml        the presentation layer: the game's concepts -> draw calls
  lib/gfx_gl.ml     the only file naming Tgl3./Tgles3. and picking the GLSL header
  lib/gfx_assets.ml  Assets.zip -> textures, via imagelib
  bin/pq_play_gfx.ml the playable window
```

The layer is not scaffolding. The presentation audit already established the
shape of the original's: effects resolved through a **name-keyed asset table**
(`Std_CastSpellEffect`), text messages laid out and clamped to the screen, and
`PLAY_SOUND` de-duplicating a sound already playing. A layer built like that is
closer to the original than a generic engine would be.

Rendering is not being reverse-engineered. The original is Uzzle Quest's own engine
with PHYSFS for its assets; SDL2 and OpenGL are our choice for the port, and the
layer should keep that boundary visible rather than pretend to be a
reconstruction.

## Sequence

| phase | what |
| --- | --- |
| 1 | sprite batcher and window, 8x8 board drawn from live battle state |
| 2 | real gem art from `Assets.zip` via imagelib, board interaction by mouse |
| 3 | text (`SDL2_ttf` or a bitmap font) |
| 4 | `Tgles3` behind `lib/gfx_gl.ml` for Android, one GLSL header switch |

## Earlier versions, and why they changed

**Version 1** (`tools/sdl3_readiness.md`, still current for its measurements):
SDL3 via `sanette/ocaml-sdl3`, hand-binding `SDL3_image`. Correct about the
bindings — 40 of the 42 needed calls bound, four-star project, early and untested —
and the `SDL3_image` gap was real. But it did not know about `tgls`, and it assumed
the choice was between SDL2 and SDL3 rather than SDL2 and OpenGL.

**Version 2**: SDL2 with SDL2's own 2D renderer, no OpenGL, deferring shaders.
Right that GL brings two shader dialects and per-platform function loading; wrong
that the dialects were unavoidable, because `tgls` already binds GLES alongside
GL, and wrong to give up shaders before they were needed — this game has 59
particle descriptors and 48 effect descriptors.

**Version 3** proposed ANGLE to run GLES on the desktop, to avoid two dialects.
Unnecessary: `tgls.tgles3` gives GLES directly on mobile and `tgls.tgl3` gives GL
on desktop, with the version line the only difference. ANGLE would have been a
large dependency bought for nothing.