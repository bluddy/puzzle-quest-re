# Graphics plan

Written before the first renderer, because the choice of graphics API is the
decision everything else in this area hangs off — and because the obvious answer
("use OpenGL, and OpenGL ES on Android") turns out to be two pieces of work rather
than one.

## Decision

**SDL2, through `tsdl`, using SDL2's own 2D renderer. No OpenGL code yet.**

Verified working on this machine before committing to it, with `bin/sdl2_probe.ml`:

```
  ok    SDL_Init(VIDEO)
  ok    SDL_CreateRenderer (accelerated)
  ok    clear + fill + present
  ok    event pump
  ok    teardown + SDL_Quit
```

`accelerated` is the point. SDL2's renderer picks the backend per platform —
OpenGL on desktop, Direct3D on Windows where it prefers it, and **OpenGL ES 2.0 on
Android** — so the same drawing code is the same code on both targets, and we never
name a graphics API at all.

## Why not OpenGL directly

`tsdl` binds the SDL2 C API. It does **not** bind OpenGL: there is no
`glGenTextures`, no shader entry point, no VAO binding, and no
`SDL_GL_GetProcAddress`. Writing GL on top of `tsdl` therefore means supplying the
whole GL layer ourselves, and that is where the cost lives:

* **Two shader dialects.** Desktop GL and GLES do not accept the same source.
  `#version 120` is not valid GLSL ES; `#version 100` is not valid desktop GLSL.
  Maintaining both is the bulk of the ongoing work.
* **Per-platform function loading.** Anything above GL 1.1 has to come from
  `SDL_GL_GetProcAddress`, which needs a C stub (gcc *is* reachable here through
  opam's `conf-mingw-w64-gcc-x86_64`, so this is possible, just not free).
* **Capability differences** to guard, per driver and per GLES version.

None of that is hard. It is just not free, and it buys nothing until something
needs a custom shader.

## When we will want GL, and how to keep one dialect

This game has a lot of effect content — 59 particle descriptors under
`Assets/Particles/`, 48 under `Assets/Effects/` — so custom shading will earn its
keep eventually. SDL2's 2D renderer cannot do custom shaders, and that is the
whole of what it cannot do.

When that day comes, the answer to "do we want OpenGL ES?" is **yes — and we should
target it on desktop too, rather than maintaining GL on desktop and GLES on
mobile.** That is one shader dialect, one code path, one target.

The enabler is ANGLE, which presents GLES on top of the desktop's D3D. Complete
`libEGL.dll` + `libGLESv2.dll` pairs already exist on this machine (VS Code, Steam
CEF, DaVinci Resolve, Vortex), which proves the path is viable — but like the SDL3
DLL, those belong to other programs and should be **vendored**, not borrowed. ANGLE
is a few megabytes.

So the sequence is:

| phase | what | cost |
| --- | --- | --- |
| 1 | SDL2 renderer, sprites, board on screen | none beyond bindings |
| 2 | bind `SDL2_image` for PNG/JPG (see below) | ~8 functions |
| 3 | GLES 2.0 + ANGLE + `SDL_GL_GetProcAddress` stub, one dialect, first real shader | a C stub and a loader |

## What still has to be bound by hand

Neither `tsdl` nor SDL2 itself decodes an image, and the game's art is **226 PNGs
and 63 JPGs**. So:

* **`SDL2_image`** — `IMG_Init`, `IMG_Quit`, `IMG_Load`, `IMG_Load_IO`,
  `IMG_LoadTexture`, `IMG_GetError` and friends. Roughly eight functions via
  `ctypes`, the same approach the SDL3 bindings use. `SDL2_image.dll` ships with
  the SDL2 development install already on this box.
* **`SDL2_ttf`** — for text. SDL2 has no font rendering, and the UI strings live in
  `Standard*Text.xml`. Or a bitmap font of our own; defer until the board is up.

## Architecture

Same reasoning as the SDL3 plan, and the reason has not changed:

```
  lib/gfx.ml          the presentation layer: the game's concepts -> draw calls
  lib/gfx_sdl2.ml     the only file that names Tsdl.*
  bin/pq_play_gfx.ml  the playable window
```

The layer is not scaffolding. The presentation audit already established the
shape of the original's: effects resolved through a **name-keyed asset table**
(`Std_CastSpellEffect`), text messages laid out and clamped to the screen, and
`PLAY_SOUND` de-duplicating a sound that is already playing. A layer built like
that is closer to the original than a generic engine would be, and it means a
future move — GLES, another backend, another binding — touches one file.

Rendering is not being reverse-engineered. The original is Uzzle Quest's own
engine with PHYSFS for its assets; SDL2 is our choice for the port, and the layer
should keep that boundary visible rather than pretend to be a reconstruction.

## On giving up SDL3

The SDL3 path was working, and is still here: `bin/sdl3_probe.ml` passes and
`tools/sdl3_readiness.md` records what was verified. Two reasons this moved.

1. **Android**, which was the deciding factor. SDL2's Android support is mature
   and `tsdl` exists; the SDL3 bindings are four-star, self-described early and
   untested, and have no Android story we could rely on.
2. **SDL3_image is not in those bindings**, so SDL3 would have needed a
   hand-written image binding anyway — which was true of SDL2 and is eight
   functions either way.

The trade is real and worth stating: SDL2 is in maintenance mode, so this is a bet
on the older-but-settled API. If SDL3's bindings mature, or if the effect work
turns out to want SDL3's newer renderer, the `lib/gfx.ml` boundary is what makes
that change cheap.