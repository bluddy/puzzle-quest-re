#!/usr/bin/env python3
"""Generate lib/fx_data.ml from the game's effect and particle descriptors.

The 48 files under `Assets/Effects` and the 51 under `Assets/Particles` are the
game's whole visual-effects vocabulary, and they are data rather than code - which
is why this is an extractor and not a parser to write by hand:

  <Effect name bitmap type duration>                  a named effect, `oneshot`
      <Child name type time duration x y position>   a child effect or particle
      <Initialize parameter value>                   a parameter's initial value
      <Animate parameter value time method>          a keyframe, linear or discrete

  <Particle name texture radius lifetime>             an emitter of sprites
      <Number max release interval life total>        how many, how often, how long
      <Graphics blend size r g b a>                  how a particle starts out
      <Animation size r g b a start>                 where each particle gets to
      <Position/Velocity x y z var>                  where it starts, where it goes
      <Gravity x y z> <Forces> <Shape steps>

`ADD_ANIMEFFECT_TO_GRID` names one of the `<Effect>` files and
`Std_GetSpellFXAsset` decides which, so with this file and `lib/spell_fx.ml` a
spell's effect is addressable end to end. What is left is a player, not a guess.
It is also the timing table the cascade animation had to invent: `SpellHealing`
runs for 2.1 seconds because the descriptor says so.

Four things in the shipped assets are handled rather than smoothed over:

  * `Assets/Particles/NewRuin.xml` is **not well-formed XML** - its `<Number>` tag
    carries a stray digit, `total="4"0/>`. The game loads it anyway, so this repairs
    that one token and says so on stderr on every run. A silently repaired asset
    would be worse than a broken one.
  * `Number.life` is written `.6` in two files rather than `0.6`.
  * One `Initialize` (`SpellFireballSmall`'s rotation) carries a `time` and a
    `method`, which makes it a keyframe wearing the wrong tag name. It is treated as
    one, because that is what the attributes mean.
  * `Number.total` is absent in 16 of 51 particles, and absent is not zero: without
    it the emitter runs until the effect ends.

Nothing here is *interpreted*. `Shape steps` (2 in seven files), the planar
`planes` codes and `AnimPosition` (the five Rings) are transcribed verbatim,
including by the files that use them, because they belong to the engine's particle
code and this project has not read it. A port that guessed at them would be
indistinguishable from one that had.

    python tools/extract_fx_data.py
    python tools/extract_fx_data.py --check     # verify the committed file is current
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT = REPO / "lib" / "fx_data.ml"
EFFECTS = "Assets/Effects/"
PARTICLES = "Assets/Particles/"

# The parameters an effect may set, and the constructor each becomes. `source_*` is
# the effect's own rectangle and `dest_*` the one it draws into; the spell effects
# set a 100x100 source and animate dest out to 300x300, so a spell effect grows
# while it plays rather than being drawn at a fixed size.
PARAMS = [
    ("alpha", "Alpha"),
    ("color_r", "Colour_r"),
    ("color_g", "Colour_g"),
    ("color_b", "Colour_b"),
    ("dest_x", "Dest_x"),
    ("dest_y", "Dest_y"),
    ("dest_w", "Dest_w"),
    ("dest_h", "Dest_h"),
    ("rotation", "Rotation"),
    ("source_x", "Source_x"),
    ("source_y", "Source_y"),
    ("source_w", "Source_w"),
    ("source_h", "Source_h"),
]
PARAM_OF = dict(PARAMS)

# `total="4"0/>` - the stray digit that makes NewRuin.xml invalid XML.
BROKEN_TAG_RE = re.compile(r'="([^"]*)"(\d+)(?=\s*/?>)')


def repair(text: str) -> str:
    return BROKEN_TAG_RE.sub(r'="\1"', text)


def num(value: str | None, default: float | None = None) -> float | None:
    """`0.05`, `.6` and `-1.5` are all numbers in these files."""
    return default if value is None else float(value)


def F(x: float) -> str:
    """An OCaml float literal.

    `%g` prints 1.0 as `1`, which is an int, so every float gets a decimal point
    whether it has a fraction or not.
    """
    t = f"{float(x):g}"
    return t if ("." in t or "e" in t) else t + ".0"


def effect_of(root: ET.Element) -> dict:
    children = []
    for el in root.findall("Child"):
        children.append({
            "name": el.get("name"),
            "kind": "Effect" if el.get("type") == "effect" else "Particle",
            "at": num(el.get("time"), 0.0),
            "duration": num(el.get("duration"), 0.0),
            "x": num(el.get("x"), 0.0),
            "y": num(el.get("y"), 0.0),
        })

    initial, keys = [], []
    for el in root.iter():
        if el.tag not in ("Initialize", "Animate"):
            continue
        p = PARAM_OF.get(el.get("parameter"))
        if p is None:
            continue
        value = num(el.get("value"), 0.0)
        at = num(el.get("time"))
        # `discrete` appears once in 266 keyframes. It is a step rather than a ramp,
        # and it is recorded rather than treated as linear.
        easing = "Discrete" if (el.get("method") or "linear") == "discrete" else "Linear"
        if el.tag == "Initialize" and at is None:
            initial.append((p, value))
        else:
            keys.append((at if at is not None else 0.0, p, value, easing))
    keys.sort(key=lambda k: k[0])

    return {
        "name": root.get("name"),
        # The sheet the effect draws its own bitmap from, and the rectangle of it -
        # an empty bitmap means the effect is only children and keyframes.
        "bitmap": root.get("bitmap") or "",
        "duration": num(root.get("duration"), 0.0),
        "children": children,
        "initial": initial,
        "keys": keys,
    }


def vec3(el: ET.Element | None) -> tuple[float, float, float]:
    if el is None:
        return (0.0, 0.0, 0.0)
    return (num(el.get("x"), 0.0), num(el.get("y"), 0.0), num(el.get("z"), 0.0))


def particle_of(root: ET.Element) -> dict:
    number = root.find("Number")
    graphics = root.find("Graphics")
    animation = root.find("Animation")
    position = root.find("Position")
    velocity = root.find("Velocity")
    forces = root.find("Forces")
    shape = root.find("Shape")
    anim_position = root.find("AnimPosition")

    rgba = lambda el: [num(el.get(c), 0.0) for c in "rgba"]  # noqa: E731

    return {
        "name": root.get("name"),
        "texture": root.get("texture"),
        "radius": num(root.get("radius"), 0.0),
        # Milliseconds, unlike every duration in these two directories.
        "lifetime": int(num(root.get("lifetime"), 0.0)),
        "max": int(num(number.get("max"), 0.0)),
        "release": int(num(number.get("release"), 0.0)),
        "interval": num(number.get("interval"), 0.0),
        "life": num(number.get("life"), 0.0),
        "total": (int(num(number.get("total"), 0.0))
                  if number.get("total") is not None else None),
        "blend": graphics.get("blend") or "alpha",
        "size": num(graphics.get("size"), 0.0),
        "colour": rgba(graphics),
        "to_size": num(animation.get("size"), 0.0),
        "to_colour": rgba(animation),
        "start": num(animation.get("start"), 0.0),
        "position": vec3(position),
        "position_var": num(position.get("var"), 0.0),
        "position_planar": position.get("planar"),
        "position_planes": position.get("planes"),
        "position_perimeter": position.get("perimeter"),
        "velocity": vec3(velocity),
        "velocity_var": num(velocity.get("var"), 0.0),
        "velocity_planar": velocity.get("planar"),
        "velocity_planes": velocity.get("planes"),
        "gravity": vec3(root.find("Gravity")),
        "anim_position": vec3(anim_position) if anim_position is not None else None,
        "anim_position_var": (num(anim_position.get("var"), 0.0)
                              if anim_position is not None else None),
        "anim_position_start": (num(anim_position.get("start"), 0.0)
                                if anim_position is not None else None),
        "anim_position_end": (num(anim_position.get("end"), 0.0)
                              if anim_position is not None else None),
        "air_resistance": (forces.get("airresistance") or "off"),
        "wind": (forces.get("wind") or "off"),
        "shape_steps": int(num(shape.get("steps"), 1.0)),
    }


def render(effects: list[dict], particles: list[dict]) -> str:
    w: list[str] = []
    a = w.append

    a("(* Generated by tools/extract_fx_data.py from Assets/Effects/*.xml and")
    a("   Assets/Particles/*.xml. Do not edit by hand; re-run the extractor. *)")
    a("")
    a("(** The game's effects and particles, as data.")
    a("")
    a("    An effect is a named bundle: a duration, some children (other effects or")
    a("    particle emitters), a set of initial parameters, and timed keyframes on")
    a("    those parameters. A particle is an emitter of textured sprites with a")
    a("    lifetime, a spawn schedule, and a start and end size and colour.")
    a("")
    a("    This is the file [ADD_ANIMEFFECT_TO_GRID] names one entry of, and the")
    a("    timing table the cascade animation had to invent: [SpellHealing] runs for")
    a("    2.1 seconds because the descriptor says so.")
    a("")
    a("    Nothing in it is interpreted. [shape_steps], the planar [planes] codes and")
    a("    [anim_position] are transcribed as they are written, because they belong")
    a("    to the engine's particle code and this project has not read it. *)")
    a("")
    a("type param =")
    for _, name in PARAMS:
        a(f"  | {name}")
    a("")
    a("type easing = Linear | Discrete")
    a("")
    a("type keyframe = {")
    a("  at : float;  (** seconds from the effect's start *)")
    a("  param : param;")
    a("  value : float;")
    a("  easing : easing;")
    a("}")
    a("")
    a("type child_kind = Effect | Particle")
    a("")
    a("type child = {")
    a("  name : string;")
    a("  kind : child_kind;")
    a("  at : float;  (** seconds after the effect starts that this child begins *)")
    a("  duration : float;  (** the child's own duration, not the parent's *)")
    a("  x : float;")
    a("  y : float;")
    a("}")
    a("")
    a("(* Not [effect], which is a keyword in OCaml 5: it is what the algebraic")
    a("   effects extension spells. *)")
    a("type effect_desc = {")
    a("  name : string;")
    a("  bitmap : string;")
    a("  (* The sheet this effect draws its own bitmap from - bmp_skin_battlemisc")
    a("     for most of them - and empty for the ones that are only children and")
    a("     keyframes. The rectangle of it is the source_* parameters. *)")
    a("  duration : float;")
    a("  children : child list;")
    a("  initial : (param * float) list;")
    a("  keys : keyframe list;")
    a("}")
    a("")
    a("type colour = { r : float; g : float; b : float; a : float }")
    a("")
    a("type blend = Additive | Alpha_blend")
    a("")
    a("type vec3 = { x : float; y : float; z : float }")
    a("")
    a("type particle = {")
    a("  name : string;")
    a("  texture : string;")
    a("  radius : float;")
    a("  lifetime : int;  (** milliseconds, unlike every duration in these files *)")
    a("  max : int;  (** how many may be alive at once *)")
    a("  release : int;  (** how many are let out together *)")
    a("  interval : float;  (** seconds between releases *)")
    a("  life : float;  (** seconds one particle lives *)")
    a("  total : int option;")
    a("  (** A cap on the whole emission, absent in 16 of 51 files. Absent is not")
    a("      zero: without it the emitter runs until the effect ends. *)")
    a("  blend : blend;")
    a("  size : float;")
    a("  colour : colour;")
    a("  to_size : float;")
    a("  to_colour : colour;")
    a("  start : float;")
    a("  (** The fraction of a particle's life at which it begins its own animation;")
    a("      [colour] and [to_colour] are its ends, not two frames of a sprite. *)")
    a("  position : vec3;")
    a("  position_var : float;")
    a("  position_planar : string option;")
    a("  position_planes : string option;")
    a("  position_perimeter : string option;")
    a("  velocity : vec3;")
    a("  velocity_var : float;")
    a("  velocity_planar : string option;")
    a("  velocity_planes : string option;")
    a("  gravity : vec3;")
    a("  anim_position : vec3 option;")
    a("  anim_position_var : float option;")
    a("  anim_position_start : float option;")
    a("  anim_position_end : float option;")
    a("  air_resistance : bool;")
    a("  wind : bool;")
    a("  shape_steps : int;")
    a("  (** 2 in seven files. Not interpreted: see the note at the top. *)")
    a("}")
    a("")

    # ------------------------------------------------------------- effects --
    a("let effects =")
    a("  [")
    for e in effects:
        a(f'    {{ name = "{e["name"]}"; bitmap = "{e["bitmap"]}";')
        a(f'      duration = {F(e["duration"])}; children =')
        if not e["children"]:
            a("      [];")
        else:
            a("      [")
            for c in e["children"]:
                a(f'        {{ name = "{c["name"]}"; kind = {c["kind"]}; '
                  f'at = {F(c["at"])}; duration = {F(c["duration"])}; '
                  f'x = {F(c["x"])}; y = {F(c["y"])} }};')
            a("      ];")
        if e["initial"]:
            pairs = " ".join(f"({p}, {F(v)});" for p, v in e["initial"])
            a(f'      initial = [ {pairs} ];')
        else:
            a("      initial = [];")
        if e["keys"]:
            a("      keys =")
            a("        [")
            for at, p, v, m in e["keys"]:
                a(f"          {{ at = {F(at)}; param = {p}; value = {F(v)}; "
                  f"easing = {m} }};")
            a("        ];")
        else:
            a("      keys = [];")
        a("    };")
    a("  ]")
    a("")

    # ----------------------------------------------------------- particles --
    a("let particles =")
    a("  [")
    for p in particles:
        a(f'    {{ name = "{p["name"]}"; texture = "{p["texture"]}";')
        a(f'      radius = {F(p["radius"])}; lifetime = {p["lifetime"]};')
        a(f'      max = {p["max"]}; release = {p["release"]};')
        a(f'      interval = {F(p["interval"])}; life = {F(p["life"])};')
        total = "None" if p["total"] is None else f'Some {p["total"]}'
        a(f"      total = {total};")
        a(f'      blend = {"Additive" if p["blend"] == "additive" else "Alpha_blend"}; '
          f'size = {F(p["size"])};')
        r, g, bl, al = p["colour"]
        a(f"      colour = {{ r = {F(r)}; g = {F(g)}; b = {F(bl)}; a = {F(al)} }};")
        a(f'      to_size = {F(p["to_size"])};')
        tr, tg, tb, ta = p["to_colour"]
        a(f"      to_colour = {{ r = {F(tr)}; g = {F(tg)}; b = {F(tb)}; a = {F(ta)} }};")
        a(f'      start = {F(p["start"])};')
        x, y, z = p["position"]
        a(f"      position = {{ x = {F(x)}; y = {F(y)}; z = {F(z)} }};")
        a(f'      position_var = {F(p["position_var"])};')
        for field in ("position_planar", "position_planes", "position_perimeter",
                      "velocity_planar", "velocity_planes"):
            v = p[field]
            a(f"      {field} = " + (f'Some "{v}"' if v else "None") + ";")
        vx, vy, vz = p["velocity"]
        a(f"      velocity = {{ x = {F(vx)}; y = {F(vy)}; z = {F(vz)} }};")
        a(f'      velocity_var = {F(p["velocity_var"])};')
        gx, gy, gz = p["gravity"]
        a(f"      gravity = {{ x = {F(gx)}; y = {F(gy)}; z = {F(gz)} }};")
        ap = p["anim_position"]
        if ap is None:
            a("      anim_position = None;")
        else:
            a("      anim_position = Some { x = %s; y = %s; z = %s };"
              % (F(ap[0]), F(ap[1]), F(ap[2])))
        for field in ("anim_position_var", "anim_position_start", "anim_position_end"):
            v = p[field]
            a(f"      {field} = " + ("None" if v is None else f"Some {F(v)}") + ";")
        a(f'      air_resistance = {str(p["air_resistance"] == "on").lower()};')
        a(f'      wind = {str(p["wind"] == "on").lower()};')
        a(f'      shape_steps = {p["shape_steps"]} }};')
    a("  ]")
    a("")

    a("(** The named effect, if the archive has one. *)")
    a("let effect_of name =")
    a("  try Some (List.find (fun (e : effect_desc) -> e.name = name) effects)")
    a("  with Not_found -> None")
    a("")
    a("let particle_of name =")
    a("  try Some (List.find (fun (p : particle) -> p.name = name) particles)")
    a("  with Not_found -> None")
    a("")

    a("(** Every particle texture in the archive.")
    a("")
    a("    Six files, 32x32 or 64x64, and none of them a registry frame - so they are")
    a("    loaded whole rather than cut up out of a sheet. [Particle.radius] is the")
    a("    other half of the sizing story, and it is why. *)")
    a("let textures =")
    seen: list[str] = []
    for p in particles:
        if p["texture"] not in seen:
            seen.append(p["texture"])
    a("  [")
    for t in seen:
        a(f'    "{t}";')
    a("  ]")
    a("")
    return "\n".join(w) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--archive", type=pathlib.Path,
                    default=REPO / "game" / "Assets.zip")
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    try:
        zf = zipfile.ZipFile(args.archive)
    except (OSError, zipfile.BadZipFile) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    effects: list[dict] = []
    particles: list[dict] = []
    repaired: list[str] = []
    for name in sorted(zf.namelist()):
        if not name.endswith(".xml"):
            continue
        if name.startswith(EFFECTS) or name.startswith(PARTICLES):
            raw = zf.read(name).decode("utf-8", "replace")
            if BROKEN_TAG_RE.search(raw):
                repaired.append(name)
            root = ET.fromstring(repair(raw))
            if name.startswith(EFFECTS):
                effects.append(effect_of(root))
            else:
                particles.append(particle_of(root))

    if not effects or not particles:
        print("error: the descriptors parsed empty", file=sys.stderr)
        return 1

    text = render(effects, particles)

    print(f"  {len(effects)} effects, {len(particles)} particles")
    print(f"  {sum(len(e['keys']) for e in effects)} keyframes, "
          f"{sum(len(e['children']) for e in effects)} child references")
    if repaired:
        print(f"  repaired malformed XML in: {', '.join(repaired)}", file=sys.stderr)

    if args.check:
        if not args.out.is_file():
            print(f"error: {args.out} missing", file=sys.stderr)
            return 1
        if args.out.read_text(encoding="utf-8") != text:
            print(f"error: {args.out} is stale, re-run tools/extract_fx_data.py",
                  file=sys.stderr)
            return 1
        print("  up to date")
        return 0

    args.out.write_text(text, encoding="utf-8")
    print(f"  wrote {args.out} ({len(text):,d} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())