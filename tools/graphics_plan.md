# Graphics plan

Superseded three times, and the current decision is the one this file argued
against. The earlier versions are kept below the current section because the
reasoning that produced them is still what justifies the shape of the result. The
third - bitmap fonts instead of `tsdl-ttf` - was reversed once the assets turned
out to contain the game's own fonts, which is the sort of thing worth checking
before writing a plan down.

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

### Real gem art

`Assets/Assets.xml` is the game's bitmap registry, and it names the gem frames:

| tag | x | y | size |
| --- | --- | --- | --- |
| `img_gem_green` | 0 | 0 | 71x71 |
| `img_gem_red` | 72 | 0 | 71x71 |
| `img_gem_yellow` | 144 | 0 | 71x71 |
| `img_gem_blue` | 216 | 0 | 71x71 |

So the cells are **71x71 on a 72px pitch**, from `Assets/Skin/Skin_Gems_Grid.png`
- not the 64px the placeholder board used. Their order is the engine's element
order Earth, Fire, Air, Water, which is `Board.mana_element`'s order and *not* the
order `Board.gem` lists its constructors in. That transposition is a standing trap
here.

Only those four are named. Skull, gold and the wildcard multipliers are not in
the registry - the engine addresses them by raw coordinates - so `gfx/assets.ml`
marks them **inferred**, read off the sheet by eye, and `frame` returns `None` for
red skull and experience, which could not be identified at all. The caller then
draws a flat colour rather than a guessed sprite, because the wrong sprite is
worse than an obvious placeholder. `test_gfx_assets.exe` pins that distinction
rather than treating recovered and inferred alike.

Two things to know if you touch this:

* **Texture coordinates are normalised 0..1**, so `Gl.push_quad` takes a source
  rectangle in the source image's *pixels* and divides by the texture size. Passing
  pixel values straight through compiles, runs, and draws a black quad, because the
  sampler clamps outside the unit range. That was the whole board going black.
* **PNG decoding is pure OCaml** via `imagelib`, which depends on `decompress`.
  No ImageMagick - deliberately not rails' `imagelib.unix`, which shells out to
  `convert`.

The sheet is not committed. `tools/extract_gfx_assets.ps1` pulls it out of
`Assets.zip` into `assets/gfx/`, which `.gitignore` excludes for the same reason
`game/` is: it is copyrighted material. Without running it the board still works,
on flat colours.

### Text: the game's own bitmap fonts

**Decision: the ten bitmap fonts in `Assets.zip`, rendered directly.**
Superseded the `tsdl-ttf` decision recorded below; the reasoning that produced it
is kept because it is what made the mistake visible.

The argument for `tsdl-ttf` was that the game's strings live in `Standard*Text.xml`
and are translated into five languages, which is font rendering rather than a fixed
glyph set. That was sound, and it never checked what the game already ships:

```
  Assets/Fonts/<Face>.png    ten atlas sheets, 8-bit RGBA
  Assets/Fonts/<Face>.xml    <FontData height numchars mincode maxcode>
                             + one <Glyph code x y width height
                                    leading trailing/> per character
  <Language>/Font.xml        32 *named* fonts: a face, a baseline, a line
                             height and an RGB colour
```

Ten faces, 195-199 glyphs each, codes 32..8482 - so the multilingual concern that
motivated a TTF is already answered, by a wider code range than five languages
need. And the 32 named styles are where the original's coloured text comes from:
`font_xp` is purple, `font_gold` orange, and the seven `font_msg_*` styles are the
float-message palette the damage numbers are drawn in.

So text costs no dependency, no font pipeline and no glyph synthesis, and it is the
original's own typeface. `tsdl-ttf` was installed to try it, found unnecessary, and
**nothing in the tree links it**. What is given up: text can only be set in a face
the game ships, at its own size. Nothing on the battle screen needs otherwise.

`tools/extract_fonts.py` generates `lib/font_data.ml` from the glyph tables and
`English/Font.xml`. The atlases are pulled by `tools/extract_gfx_assets.py` into
`assets/gfx/Fonts/`.

### The advance is inferred, and that is the one soft spot

`FUN_004c7650` accumulates a string's width from a stored per-glyph advance at
`+0x18`, but adds `+0x1c` for the first character and subtracts it for the last -
and for a single `'A'` in `Small` those branches disagree, 25 against 10. **What
`+0x1c` is, is not recovered**, and it cannot be: the `FontData` attribute names
*are* in the binary, as UTF-16 at `0x0012BC60`, but nothing references them, so the
engine does not parse these files at all and there is no parser to read. The
runtime glyph records are pre-baked by a tool outside this repository.

What the port does instead, and why:

* **`leading + trailing` already equals the ink width** (94% of glyphs), rather than
  adding to it. Summing all three - the reading the attribute names invite - doubles
  the tracking, which is exactly what the first render of the HUD did.
* **The atlas packs cells edge to edge**, one pixel between, so the ink carries no
  baked-in offset to undo.
* The exception is a glyph with no ink: the space, whose 1px rectangle is a
  placeholder while its bearings still add up to a real space. Hence
  `max width (leading + trailing)` - without which "you 60" renders as "you60".

This is recorded as an inference, in `port.advance_is_ink_width` and the open
question `font.advance_field_mapping`, rather than as a recovery.

### Float messages

`gfx/font_layout.place_message` is a transcription of the positioning in
`Engine_ADD_TEXT_MESSAGE_415120`: anchor on the box's **smaller** corner minus half
the width, then clamp into the screen with a hardcoded 20px margin, with the
near-edge rule overriding the far-edge one. The vertical rule tests `y` alone and
never `y + height`, while the horizontal rule tests `x + width` - so a message whose
bottom edge runs off screen is not pulled back. That asymmetry is reproduced, and
pinned by a test, because tidying it would be a silent divergence.

`FUN_004c9950`, the call the float-text entry points make, shows the queue the
original draws into: UTF-16 strings capped at 255 characters, at most 100 queued at
once, colour read from the font record as **B, G, R, A** in that order, and an
optional per-character colour array - which is how it draws one number in two
colours. The port draws text immediately instead, which suits a HUD redrawn every
frame and would not suit a script that queues a message and animates it.

## Decoration: read the registry, do not measure the art

Earlier versions of this plan treated the gem sheet as a special case - one sheet,
four named frames, the rest read off the image by eye - and left the rest of the
screen's art alone. That was the wrong shape once it turned out the registry has
**422 named rectangles across 44 sheets**, covering the whole decoration
vocabulary of the game: the backdrop and its border, the selection glow, the turn
counter plates, button states, dialog furniture.

So `tools/extract_skin_data.py` generates `lib/skin_data.ml` from
`Assets/Assets.xml`, and `gfx/skin.ml` draws a frame by tag:

```ocaml
Skin.draw skin runs "img_border_top" ~place
```

Nothing in the presentation layer carries a rectangle it measured. Three things
came out of the registry that guessing would have got wrong:

- **The window is 1024x768, because the art is cut for it.** The four border
  frames tile that rectangle exactly - top 1024x95, left 19x653, right 21x653,
  bottom 1024x20, with 95 + 653 = 748 and 748 + 20 = 768. `Assets/Screens/Backdrop.xml`
  declares the same 1024x768 menu. A border at any other window size is cropped or
  stretched, and looks merely "off" rather than broken, so `test_skin_data` asserts
  the tiling.
- **The backdrop is a JPEG**, so `imagelib` has to be the `jpeg-codec` fork - see
  the requirements section in the README. Note also that the sheet the registry
  names is `Skin_Backdrop_Standard.jpg`, **not** `Skin_Backdrop_Battle.jpg`, which
  `Assets.xml` never mentions; this repo was extracting the latter until the
  registry was read.
- **Frames carry a destination size as well as a stored size.** The red glows are
  88x88 on disk and 64x64 on screen, so drawing one at its stored size is wrong.

The board's top inset is read from the border frame rather than typed, so the art
and the layout cannot drift apart.

One deliberate omission: `img_timer_0..5`, the hourglass. It belongs to the timed
minigames, and there is nothing on a battle screen for it to count, so guessing a
place for it would be decoration for its own sake.

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
  gfx/layout.ml      board geometry and gem colours - no SDL, no GL, pure
  gfx/input.ml       what a click means, given which prompt is open - also pure
  gfx/gl.ml          the only file naming Tgl3./Tgles3., picks the GLSL header
  gfx/png.ml         PNG -> RGBA bigarray, shared by assets and fonts
  gfx/assets.ml      Assets.zip -> textures, via imagelib
  gfx/font_layout.ml glyph advances, measuring, wrapping, float-message placement
  gfx/font.ml        a font atlas -> one texture, one batched run per line
  gfx/skin.ml        decoration by registry tag: backdrop, border, glow, plates
  bin/pq_play_gfx.ml the playable window
```

The layer is not scaffolding. The presentation audit already established the
shape of the original's: effects resolved through a **name-keyed asset table**
(`Std_CastSpellEffect`), text messages laid out and clamped to the screen, and
`PLAY_SOUND` de-duplicating a sound already playing. A layer built like that is
closer to the original than a generic engine would be.

### Why input handling is a pure module

`gfx/input.ml` interprets a click given which prompt is open, with no SDL in it.
That is not tidiness. The first version of the windowed front end had the spell
prompt read clicks directly, and when a click was not on a spell button it simply
asked again - so a player could not decline a spell, never reached the swap
prompt, and no swap was ever possible. It presented as "clicks are not registered"
while the clicks were arriving perfectly well.

There was no way to catch that headlessly, because the logic was tangled into the
event loop. Extracting it lets `test_gfx_input.exe` assert that a board click
*e declines* the spell, that a bar click during a swap *ends the turn*, and that a
non-adjacent click reselects rather than dead-ending - which is the right call for
a click-based UI, as opposed to the original's drag.

The drawing and the click handling also take the bar geometry from one place now.
They used to compute it separately, which is exactly how you end up with a button
that is drawn but not clickable.

### Do not port the CRT shader from rails

`rails` renders at 320x200 and upscales through `shaders/crt-hyllian.glsl`,
`vga-1080p.glsl` and friends. **That is wrong here and must not be copied.**

Railroad Tycoon is a DOS game, and scanlines and aperture grille are a period
reference to how the hardware of the day actually displayed. Puzzle Quest is from
2008 and postdates the CRT era entirely — the original's own presentation is flat,
clean 2D, and that is what we are reproducing. Applying a CRT filter would be
adding an anachronism the original never had.

So: no CRT, no scanlines, no vignette, no fake-horizontal-blur. Sprites are drawn
at their natural aspect with clean edges. If a raster effect is ever wanted, it
should be one the original demonstrably had — and the presentation audit found
none of the dropped calls was doing anything of the kind.

The transferable parts of rails are the plumbing — context setup, sprite batcher,
fixed-timestep loop — not its art direction.

Rendering is not being reverse-engineered. The original is Uzzle Quest's own engine
with PHYSFS for its assets; SDL2 and OpenGL are our choice for the port, and the
layer should keep that boundary visible rather than pretend to be a
reconstruction.

## Sequence

`pq_play_gfx.exe --shot FILE` renders one frame and writes it as a PPM, which is
how the two bugs below were found rather than guessed at. It reads the
framebuffer *before* presenting, because after a swap the default framebuffer is
undefined - reading it afterwards returns all zeroes and looks like a black screen
rather than a measurement mistake.

| phase | what |
| --- | --- |
| 1 | sprite batcher and window, 8x8 board drawn from live battle state |
| 2 | real gem art from `Assets.zip` via imagelib, board interaction by mouse |
| 3 | text - **done**, in the game's own bitmap fonts, with a HUD |
| 3b | decoration - **done**: the registry as data, the backdrop and border at 1024x768 |
| 4 | `Tgles3` behind `lib/gfx_gl.ml` for Android, one GLSL header switch |

Phase 3 needed no new dependency, which was not obvious when it was written down as
a font pipeline. Phase 3b needed `imagelib` pinned to a fork, because the backdrop
is a JPEG - so "no new dependency" was true of the text and not of the decoration.

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