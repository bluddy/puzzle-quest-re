(** Which sound a battle event plays.

    Pure, and no SDL in it, for the reason [Font_layout] gives: this is arithmetic
    and string matching, and it is the part worth testing.

    The cascade rule is **recovered**, from `Sub_47ae80.c`. The C casts are elided
    below for a reason worth knowing: a C pointer cast ends in a star followed by a
    close-paren, and that exact pair is what closes an OCaml comment - so a cast
    pasted in verbatim ends the docstring half way through the quote.

    ```c
    counter = read_dword(param_1 + 0x3c8) + 1;   // the per-swap cascade counter
    write_dword(param_1 + 0x3c8, counter);
    switch (counter) {
      case 0:
      case 1: goto skip;                          // the first two steps are silent
      case 2: pwVar5 = L"snd_cascade1"; break;
      case 3: pwVar5 = L"snd_cascade2"; break;
      case 4: pwVar5 = L"snd_cascade3"; break;
      case 5: pwVar5 = L"snd_cascade4"; break;
      case 6: pwVar5 = L"snd_cascade5"; break;
      default: pwVar5 = L"snd_cascade6";         // and seven or more keeps this one
    }
    Engine_PLAY_SOUND_4b38a0(pwVar5);
    ```

    So a match does not make a noise: the *first* cascade step is silent, the
    second plays `snd_cascade1`, and a long chain climbs to `snd_cascade6` and
    stays there. That is the sort of detail that is invisible until it is missing -
    a battle where every match clicks.

    **Heroic effort plays two sounds**, and the order is in the same function: the
    voice line first, then the effect.

    ```c
    Engine_PLAY_SOUND_4b38a0(L"snd_voice_heroiceffort");
    Engine_PLAY_SOUND_4b38a0(L"snd_heroiceffort");
    ```

    Which is why [of_event] returns a *list*. Most events play one sound; this one
    plays two, and a mapping that could only express one would have to silently
    drop the voice - or the effect, which is the one carrying the information.

    The element sounds are named for the element (`snd_earth`, `snd_air`,
    `snd_fire`, `snd_water`) and `ManaGained` carries the element id, so a mana
    message and its sound agree. The ids are the board's, not [Battle]'s: 1 Earth,
    2 Fire, 3 Water, 4 Air. *)

open Puzzle_quest_lib

(** The sound for one cascade step, or [None] when that step is silent.

    [step] is the per-swap cascade counter as the engine counts it, starting at 1
    for the first step - which is what `Battle.MatchResolved` carries. *)
let cascade (step : int) : string option =
  if step < 2 then None else Some (Printf.sprintf "snd_cascade%d" (min 6 (step - 1)))

(** The element a mana gain was in, by the engine's ids. *)
let element_sound (element_id : int) : string option =
  match element_id with
  | 1 -> Some "snd_earth"
  | 2 -> Some "snd_fire"
  | 3 -> Some "snd_water"
  | 4 -> Some "snd_air"
  | _ -> None

(** The sounds an event plays, in order. Empty for an event that is silent.

    The spell sounds are chosen by the spell's id rather than by anything the event
    carries, because `SpellCast` only names the spell. Which of the six spell sounds
    a given spell uses is a property of the spell table and is not recovered; see
    the note in [spell_sound]. *)
let of_event (e : Battle.event) : string list =
  match e with
  | Battle.MatchResolved (step, _) -> ( match cascade step with Some s -> [ s ] | None -> [])
  | Battle.Damage _ -> [ "snd_damage" ]
  | Battle.ManaGained (_, element, _) -> (
      match element_sound element with Some s -> [ s ] | None -> [])
  | Battle.GoldGained _ -> [ "snd_gold" ]
  | Battle.XpGained _ -> [ "snd_xp" ]
  | Battle.ExtraTurn _ -> [ "snd_extraturn" ]
  | Battle.HeroicEffort _ -> [ "snd_voice_heroiceffort"; "snd_heroiceffort" ]
  | Battle.SpellHeld _ -> [ "snd_resistspell" ]
  | Battle.TurnStart (_, Battle.Hero, _) -> [ "snd_newturn" ]
  | Battle.TurnStart (_, Battle.Enemy, _) -> [ "snd_enemyturn" ]
  | Battle.BattleEnd Battle.HeroVictory -> [ "snd_voice_victory"; "snd_victory" ]
  | Battle.BattleEnd Battle.EnemyVictory -> [ "snd_voice_defeat"; "snd_defeat" ]
  (* A spell cast is handled by [with_spell], which is given the spell itself; a
     swap, a banked turn, a size turn, a refill, a mana burn and a turn ending all
     pass without a sound. Mana burn is the interesting one: the archive has no
     sound tagged for it, so there is nothing to play even if we wanted to. *)
  | Battle.SpellCast _ -> []
  | _ -> []

(** The sound a spell cast plays.

    **This is a guess, and it is labelled as one in the evidence database.** The
    registry names six spell sounds - nature, buff, debuff, fire, heal, alter - and
    which one a given spell uses is decided by the spell's own effect, which is not
    recovered. Rather than pretend otherwise, this picks by what the spell costs: a
    spell that spends mana is doing something, and `SpellFire` is the game's fire
    sound. Every tag it returns is a real one, so nothing can come out as a
    wrong-file-but-plausible-noise; the risk is a mismatched *category*, which is
    the lesser one.

    A caller with the real mapping should replace this. It is one function. *)
let spell_sound (s : Spell.spell) : string list =
  let spends =
    s.Spell.cost_earth + s.Spell.cost_fire + s.Spell.cost_air + s.Spell.cost_water
  in
  if spends <= 0 then [ "snd_aispell" ] else [ "snd_spellfire" ]

(** The sounds for an event, given the spell that was cast when it was one.

    [of_event] deliberately says nothing about a `SpellCast`: the event carries the
    spell's {e id} and nothing else, and the sound depends on what the spell does
    rather than what it is called. So the caller - which has the spell - supplies
    it, and a caller that does not have it simply gets no sound for the cast. *)
let with_spell (e : Battle.event) (spell : Spell.spell option) : string list =
  match (e, spell) with
  | Battle.SpellCast _, Some s -> spell_sound s
  | _ -> of_event e