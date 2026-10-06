#!/usr/bin/env python3
"""Generate lib/spell_fx.ml from the game's own spell-effect tables.

Two Lua tables in `Assets/Scripts/StandardUtilityScripts.lua` decide what every
spell in the game looks and sounds like, and neither was transcribed until now:

    Std_GetSpellFXAsset     SPELLFX_* -> an Assets/Effects/<name>.xml to play
    Std_GetSpellSoundAsset  SPELLFX_* -> a sound tag to play

Both are plain if/elseif chains - twenty-one and twenty-two entries - so there is
nothing to reverse, only something to copy. Copying them by hand would be the one
thing this project's discipline exists to prevent: the sound half in particular
replaces a *guess* the port was making from a spell's mana cost
(`port.spell_sound_is_guessed`), and a guess that silently becomes a fact is worse
than a guess that stays labelled.

Three details in the source are load-bearing and easy to smooth over:

  * `SPELLFX_HURLGOBLIN` maps to the same asset as `SPELLFX_FIREBALL`. That is
    copy-paste in the file, not a fact about hurling goblins, and it is kept.
  * `SPELLFX_DEFAULT` has no entry in either table. `Std_CastSpellEffect` special-cases
    it: it plays `snd_spellnature` and adds `Spell0` and `Spell1` to the caster.
    `SPELLFX_DEFAULTGFXONLY` is the same two effects with no sound. So `cast_sound_of`
    is not `sound_of` - it is what `Std_CastSpellEffect` actually does.
  * The four `Std_*SpellEffect` helpers take the constant as an argument, so which
    effect a spell gets is decided by the spell's own script, not by the spell XML.
    Each of the 130 scripts under `Assets/Spells` is read for its calls, and the
    calls are kept in order: `SBAC` really does put `SPELLFX_WAR` on a grid cell and
    `SPELLFX_DEFAULTGFXONLY` on its caster.

    python tools/extract_spell_fx.py
    python tools/extract_spell_fx.py --check     # verify the committed file is current
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import zipfile

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT = REPO / "lib" / "spell_fx.ml"
SCRIPTS = "Assets/Scripts/StandardUtilityScripts.lua"
SPELL_DIR = "Assets/Spells/"

# `if (typ == SPELLFX_X) then ... spellfx = "Y";` - one per entry, with arbitrary
# blank lines between the parts, which the file has a lot of.
ENTRY_RE = re.compile(
    r'(?:if|elseif)\s*\(\s*typ\s*==\s*(SPELLFX_[A-Z_]+)\s*\)\s*then\s*'
    r'spellfx\s*=\s*"([^"]*)"',
    re.S,
)

# The effect helpers, as they are called from a spell's script. The grid form is
# `(x,y,typ,useSound)`, so the cell is dynamic and is left to the spell body; what is
# recoverable here is which effect each call asks for.
CALL_RE = re.compile(
    r'Std_(Cast|Caster|Enemy|Grid)SpellEffect\s*\(([^;]*?)\)\s*;',
    re.S,
)
CONST_RE = re.compile(r'(SPELLFX_[A-Z_]+)')

# `Std_CastSpellEffect(src, SPELLFX_DEFAULT, name)` and friends, keyed by the helper
# they call. `src` is the caster for all four; only Grid aims somewhere else.
TARGET_OF = {
    "Cast": "Caster",
    "Caster": "Caster",
    "Enemy": "Enemy",
    "Grid": "Grid",
}


# Sub-words that appear inside a constant with no underscore to mark them:
# SPELLFX_DEFAULTSOUNDONLY and SPELLFX_DEFAULTGFXONLY are one run of capitals each.
# Without this they arrive as `Defaultsoundonly`, which is not a name anybody would
# have chosen and which reads as a typo rather than as the game's constant.
SUBWORDS = ("SOUND", "GFX", "ONLY")


def split_run(chunk: str) -> list[str]:
    """DEFAULTSOUNDONLY -> DEFAULT, SOUND, ONLY."""
    parts = [chunk]
    for word in SUBWORDS:
        out = []
        for p in parts:
            if p == word:
                out.append(p)
                continue
            i = p.find(word)
            while i > 0:
                out.extend([p[:i], word])
                p = p[i + len(word):]
                i = p.find(word)
            out.append(p)
        parts = out
    return [p for p in parts if p]


def ocaml_name(constant: str) -> str:
    """SPELLFX_SPARKLE -> Sparkle, SPELLFX_DEFAULTGFXONLY -> Default_gfx_only."""
    body = constant[len("SPELLFX_"):].lower()
    words: list[str] = []
    for chunk in body.split("_"):
        words.extend(split_run(chunk.upper()))
    return "_".join(w.capitalize() for w in words)


def parse_table(lua: str, fn_name: str) -> list[tuple[str, str]]:
    """One table's entries, in the order the file has them."""
    start = lua.index(f"function {fn_name}")
    end = lua.index("\nend", start)
    return ENTRY_RE.findall(lua[start:end])


def parse_calls(lua: str, cast_sound: dict[str, str]) -> list[tuple[str, str, bool]]:
    """A spell script's effect calls, in order, as (target, constant, sound)."""
    calls = []
    for kind, args in CALL_RE.findall(lua):
        m = CONST_RE.search(args)
        if m is None:
            continue
        if kind == "Grid":
            # Only the grid form takes the flag, and it compares it `== 1`, so a
            # truthy non-1 is silent. Transcribed as the comparison, not as truthiness.
            parts = [p.strip() for p in args.split(",")]
            use_sound = len(parts) >= 4 and parts[3] == "1"
        else:
            # The caster forms take no flag: they play whatever their own table says.
            use_sound = cast_sound.get(m.group(1), "") != ""
        calls.append((TARGET_OF[kind], m.group(1), use_sound))
    return calls


def render(constants: list[str], fx: list[tuple[str, str]], snd: list[tuple[str, str]],
           casts: list[tuple[str, list[tuple[str, str, bool]]]]) -> str:
    out = []
    w = out.append
    w("(* Generated by tools/extract_spell_fx.py from")
    w("   Assets/Scripts/StandardUtilityScripts.lua and Assets/Spells/*.lua.")
    w("   Do not edit by hand; re-run the extractor. *)")
    w("")
    w("(** Which effect and sound a spell plays, as the game's own scripts decide it.")
    w("")
    w("    Every spell asks for its effect through one of four `Std_*SpellEffect`")
    w("    helpers, and each helper resolves the `SPELLFX_*` constant it is given")
    w("    through the two tables below. So the constant a spell passes *is* the")
    w("    presentation - which means this is data, transcribed rather than chosen.")
    w("")
    w("    [Default] and [Default_gfx_only] are the awkward ones. Neither appears in")
    w("    either table: `Std_CastSpellEffect` special-cases them, adding `Spell0` and")
    w("    `Spell1` to the caster, and playing `snd_spellnature` only for [Default].")
    w("    That is why there is a [cast_sound_of] as well as a [sound_of] - the first")
    w("    is what the helper does, the second is only what its table says. *)")
    w("")
    w("type fx =")
    for c in constants:
        w(f"  | {ocaml_name(c)}")
    w("")
    w("let all = [")
    for c in constants:
        w(f"  {ocaml_name(c)};")
    w("]")
    w("")
    w("(** The name a spell script writes, from the name this module uses. *)")
    w("let constant_of = function")
    for c in constants:
        w(f'  | {ocaml_name(c)} -> "SPELLFX_{c[len("SPELLFX_"):]}"')
    w("")
    w("let of_constant = function")
    for c in constants:
        w(f'  | "SPELLFX_{c[len("SPELLFX_"):]}" -> Some {ocaml_name(c)}')
    w('  | _ -> None')
    w("")
    w("(** The effect asset `Std_GetSpellFXAsset` names, if any.")
    w("")
    w("    Empty in the source means no effect, and that is [None] here rather than")
    w("    [Some \"\"]: a caller that forgets to test the string would draw a blank")
    w("    sprite and call it a spell effect. *)")
    w("let asset_of = function")
    for c in constants:
        name = ocaml_name(c)
        entry = dict(fx).get(c)
        w(f'  | {name} -> ' + (f'Some "{entry}"' if entry else "None"))
    w("")
    w("(** The sound tag `Std_GetSpellSoundAsset` names, if any. *)")
    w("let sound_of = function")
    for c in constants:
        name = ocaml_name(c)
        entry = dict(snd).get(c)
        w(f'  | {name} -> ' + (f'Some "{entry}"' if entry else "None"))
    w("")
    w("(** What `Std_CastSpellEffect` plays for a cast, which is not [sound_of].")
    w("")
    w("    [Default] is the special case: the helper skips the lookup entirely, plays")
    w("    `snd_spellnature` and adds Spell0 and Spell1 to the caster. [Default_gfx_only]")
    w("    is the same two effects with no sound, which is what its name means and")
    w("    which `Std_CastSpellEffect` spells out as a separate branch. *)")
    w("let cast_sound_of = function")
    for c in constants:
        name = ocaml_name(c)
        entry = dict(snd).get(c)
        if c == "SPELLFX_DEFAULT":
            w(f'  | {name} -> Some "snd_spellnature"')
        elif entry:
            w(f'  | {name} -> Some "{entry}"')
        else:
            w(f'  | {name} -> None')
    w("")
    w("(** The two effects `Std_CastSpellEffect` adds to the caster for [Default] and")
    w("    [Default_gfx_only]. The helper names them literally; they are assets too. *)")
    w("let default_caster_effects = [ \"Spell0\"; \"Spell1\" ]")
    w("")
    w("type target = Caster | Enemy | Grid")
    w("")
    w("type call = {")
    w("  target : target;  (** which end of the fight the helper aimed at *)")
    w("  fx : fx;")
    w("  use_sound : bool;")
    w("  (** The grid form compares its fourth argument `== 1`, so a truthy non-1 is")
    w("      silent. Transcribed as the comparison the file makes rather than as")
    w("      truthiness. *)")
    w("}")
    w("")
    w("(** Every effect call in one spell's script, in the order the script makes them.")
    w("")
    w("    A spell can ask for more than one: `SBAC` puts a war effect on the grid cell")
    w("    it just created and a default one on its own caster. Which *cell* is not")
    w("    here - that comes from the spell body, which is where the game gets it. *)")
    w("let calls_of_spell (id : string) : call list =")
    w("  match id with")
    for spell_id, calls in casts:
        parts = "; ".join(
            "{ target = %s; fx = %s; use_sound = %s }"
            % (t, ocaml_name(c), "true" if s else "false")
            for t, c, s in calls
        )
        w(f'  | "{spell_id}" -> [ {parts} ]')
    w("  | _ -> []")
    w("")
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--archive", type=pathlib.Path,
                    default=REPO / "game" / "Assets.zip",
                    help="path to Assets.zip")
    ap.add_argument("--out", type=pathlib.Path, default=OUT)
    ap.add_argument("--check", action="store_true",
                    help="verify the committed file is what the archive says")
    args = ap.parse_args()

    try:
        zf = zipfile.ZipFile(args.archive)
        lua = zf.read(SCRIPTS).decode("utf-8", "replace")
    except (OSError, KeyError, zipfile.BadZipFile) as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    fx = parse_table(lua, "Std_GetSpellFXAsset")
    snd = parse_table(lua, "Std_GetSpellSoundAsset")
    if not fx or not snd:
        print("error: the tables parsed empty", file=sys.stderr)
        return 1

    # Every constant either table mentions, in file order, plus the three the tables
    # never mention but the helpers accept.
    ordered: list[str] = []
    for c, _ in fx:
        if c not in ordered:
            ordered.append(c)
    for c, _ in snd:
        if c not in ordered:
            ordered.append(c)
    for c in ("SPELLFX_DEFAULT", "SPELLFX_DEFAULTGFXONLY"):
        if c not in ordered:
            ordered.append(c)

    cast_sound = dict(snd)
    cast_sound["SPELLFX_DEFAULT"] = "snd_spellnature"  # the helper's own special case

    casts: list[tuple[str, list[tuple[str, str, bool]]]] = []
    silent = 0
    for name in sorted(n for n in zf.namelist()
                       if n.startswith(SPELL_DIR) and n.endswith(".lua")):
        spell_id = name[len(SPELL_DIR):-len(".lua")]
        calls = parse_calls(zf.read(name).decode("utf-8", "replace"), cast_sound)
        if calls:
            casts.append((spell_id, calls))
        else:
            silent += 1

    text = render(ordered, fx, snd, casts)

    print(f"  {len(fx)} effect assets, {len(snd)} sound tags, {len(ordered)} constants")
    print(f"  {len(casts)} of {len(casts) + silent} spell scripts ask for an effect")

    if args.check:
        if not args.out.is_file():
            print(f"error: {args.out} missing", file=sys.stderr)
            return 1
        if args.out.read_text(encoding="utf-8") != text:
            print(f"error: {args.out} is stale, re-run tools/extract_spell_fx.py",
                  file=sys.stderr)
            return 1
        print("  up to date")
        return 0

    args.out.write_text(text, encoding="utf-8")
    print(f"  wrote {args.out} ({len(text):,d} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())