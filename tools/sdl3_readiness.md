# SDL3 readiness: what was checked, and what is missing

Written before any renderer code, because the graphics front has three ways to
fail quietly and each needed checking rather than assuming.

## The bindings

`sanette/ocaml-sdl3` — opam name `sdl3`, **not on the opam repository**, so it is
consumed as a pinned git dependency:

```sh
opam pin add sdl3 https://github.com/sanette/ocaml-sdl3.git
opam install sdl3
```

It builds bindings for **1209 functions** by parsing the SDL headers, and every
module has a real `.mli` carrying the SDL documentation and the OCaml signature.
`lib/bound_functions.csv` in that repo lists all of them with the SDL version each
was introduced in, which is what makes the completeness question answerable
instead of a guess.

Access is through two namespaces, and they are not the same thing:

* `Sdl3.Categories.Render` and friends — the same functions grouped by SDL header.
* `Sdl3.Sdl` — the flat namespace, reached as `Sdl` after `open Sdl3`. This is the
  idiomatic one and what the examples use.

### How complete, for this game

Checked against the 42 SDL3 calls a board renderer needs, taken from
`bound_functions.csv` rather than from memory:

| | count |
| --- | --- |
| bound | **40** |
| missing | 2 |

The two gaps are both avoidable:

* `SDL_QueryTexture` — not needed; the texture cache knows its own sizes because
  it created them from a surface it just decoded.
* `SDL_RenderTextureTinted` — not needed; `SDL_SetTextureColorMod` covers the one
  case we have (tinting a sprite sheet entry).

`Video`, `Render`, `Surface`, `Keyboard` and `Mouse` are all well covered, which
is the whole of what a match-3 board needs.

### Honest warnings, from the author

The README is blunt and the warnings are worth carrying forward rather than
quoting once:

* "Warning! early stage of developpment!" and "don't expect all of them to work".
* "Very few have been tested yet ... use at your own risk! Core dumped possible."
* "Overall organization may change. Many signatures should be improved."
* 4 stars, 81 commits. `Sdl3_types.ml` has **no** `.mli`, so the types behind
  every signature are opaque.

That is why nothing above should touch the bindings directly. See
[the architecture note](#architecture) below.

## The runtime, verified

`bin/sdl3_probe.ml` checks the three failure points in order and says which broke.
It was run on this machine and passed:

```
  ok    SDL_Init
  ok    SDL version 3005000 (bindings target 3.4.12)
  ok    SDL_CreateWindowAndRenderer
  ok    clear + present
  ok    SDL_Quit
```

The bindings **dlopen the DLL at runtime**, so the path comes from the
`SDL3_LIBRARY` environment variable (see `load.ml` in the binding). `SDL3.dll`,
`SDL3_image.dll` and `SDL3_ttf.dll` from a Steam install were used.

The reported version is **3.5.0**, which is newer than the 3.4.12 the bindings were
generated from. SDL3 only adds within a major version, so calls covered by the
bindings exist; the author's own guidance is that anything at or below 3.4.12
works.

Two things follow from "dlopen at runtime" and are worth deciding on purpose
rather than by accident:

* **Do not depend on another game's DLL.** A Steam copy can be updated, moved or
  removed without notice. Vendoring the official `SDL3-3.4.16-win32-x64` release
  next to the executable is a few megabytes and makes the build reproducible.
* `SDL3.dll` has to be findable at run time. Beside the built executable is more
  robust than depending on an environment variable being set.

## The gap: nothing can decode a PNG

SDL3 core has no image decoder, and these bindings are SDL3 core only — there is
no `SDL3_image` module, and nothing in `bound_functions.csv` mentions PNG or IMG.

That matters because the game's art is:

| format | files | size |
| --- | --- | --- |
| PNG | 226 | 19.0 MB |
| JPG | 63 | 7.7 MB |
| XML | 3482 | 12.9 MB (data, not images) |
| WAV | 83 | 8.4 MB |
| Lua | 537 | 1.3 MB |

So: **plain PNG and JPG**, no exotic container and nothing to reverse-engineer.
Which is good news, and the bad news is that SDL3 cannot read either.

### Recommendation: bind `SDL3_image`, do not write a codec

`SDL3_image` is a small C library and only a handful of its entry points matter
here:

```
IMG_Init, IMG_Quit, IMG_Load, IMG_Load_IO, IMG_LoadTexture,
IMG_LoadTexture_IO, IMG_GetError, IMG_SetLoadSize
```

That is roughly **eight** bound functions, against roughly **1500** lines of
OCaml for a PNG decoder and rather more for JPEG. `SDL3_image.dll` is already
installed here, so the same `ctypes`-plus-`dlopen` approach the SDL3 bindings use
applies directly.

Worth noting that the original did have its own decoders — the binary loads PNG
for the portrait embedded in a `.pqhero`, and JPEG for the battle backdrop — so
*something* has to decode these files. We are choosing not to reproduce it.

### Text needs a decision too

SDL3 core has no text rendering either; `SDL_ttf` is a separate library and is not
bound here. The game's UI text lives in `Standard*Text.xml`. Options are a
`SDL3_ttf` binding, a bitmap font of our own, or neither for now — deferred until
the board is on screen.

## Architecture

The bindings are young and their layout may change, so the amount of code that
touches them should be as small as it can be while still drawing the game:

```
  lib/gfx.ml        the presentation layer: the game's concepts -> draw calls
  lib/gfx_sdl3.ml   the only file that names Sdl3.*  (and Sdl3_image)
  bin/pq_play_gfx.ml  the playable window
```

Two reasons for the layer rather than calls at the call sites:

1. **Containment.** If a binding moves, or the project outgrows these bindings,
   it is one file. The alternative is `Sdl3.` appearing across the presentation
   code.
2. **The presentation semantics are already recovered.** The audit established
   that the original resolves effects through a *name-keyed asset table*
   (`Std_CastSpellEffect`), that text messages are laid out and clamped to the
   screen, and that `PLAY_SOUND` de-duplicates an already-playing sound. That is a
   specific design, and a layer shaped like it is closer to the original than a
   generic engine would be.

Rendering itself is not being reverse-engineered. The original is Uzzle Quest's
own engine with PHYSFS for assets; SDL3 is our choice for the port, and the layer
should make that boundary obvious rather than pretend to be a reconstruction.