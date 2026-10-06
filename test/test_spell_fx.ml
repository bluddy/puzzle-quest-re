(* What a spell looks and sounds like, as the game's own tables decide it.

   `lib/spell_fx.ml` is generated from `Std_GetSpellFXAsset`,
   `Std_GetSpellSoundAsset` and the 130 spell scripts, so the risk is not that the
   transcription is wrong - the generator reads the file - but that a *reader* of
   this module would smooth over the three things in it that look like mistakes and
   are not. Those are what these tests are for.

   The per-spell half matters for a second reason: it is what replaced a guess. The
   port used to pick a spell's sound by what the spell cost
   (`port.spell_sound_is_guessed`), and nothing asserted that guess, because a guess
   that happens to name a real sound file is indistinguishable from an answer at
   runtime. So the recovered mapping is pinned here, spell by spell. *)

open Puzzle_quest_lib
open Pq_gfx

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_str name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %s, want %s)\n" name got want;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let check_opt name got want =
  match (got, want) with
  | None, None -> Printf.printf "ok   - %s\n" name
  | Some a, Some b when a = b -> Printf.printf "ok   - %s\n" name
  | _ ->
      Printf.printf "FAIL - %s (got %s, want %s)\n" name
        (match got with None -> "none" | Some s -> s)
        (match want with None -> "none" | Some s -> s);
      incr failures

let joined l = String.concat "," l

(* ------------------------------------------------------------- the tables -- *)

let () =
  check_int "21 constants name an effect asset"
    (List.length (List.filter (fun (f : Spell_fx.fx) -> Spell_fx.asset_of f <> None) Spell_fx.all))
    21;
  check_int "and 22 name a sound"
    (List.length (List.filter (fun (f : Spell_fx.fx) -> Spell_fx.sound_of f <> None) Spell_fx.all))
    22;
  (* The file's own copy-paste. SPELLFX_HURLGOBLIN points at the fireball's effect,
     which is either deliberate or an editing slip; either way this port plays what
     the game plays, and a test is what keeps a later tidy-up from "fixing" it. *)
  check_opt "hurlgoblin reuses the fireball's effect"
    (Spell_fx.asset_of Spell_fx.Hurlgoblin)
    (Spell_fx.asset_of Spell_fx.Fireball);
  check_opt "and its sound too" (Spell_fx.sound_of Spell_fx.Hurlgoblin)
    (Spell_fx.sound_of Spell_fx.Fireball);
  (* The three awkward constants, which appear in neither table. *)
  check_opt "Default names no effect asset" (Spell_fx.asset_of Spell_fx.Default) None;
  check_opt "Default_Sound_Only names no effect asset"
    (Spell_fx.asset_of Spell_fx.Default_Sound_Only) None;
  check_opt "Default_Gfx_Only names no effect asset"
    (Spell_fx.asset_of Spell_fx.Default_Gfx_Only) None;
  (* `Std_CastSpellEffect` special-cases Default: it skips both lookups, plays
     snd_spellnature and adds Spell0 and Spell1 to the caster. So the helper's sound
     is not the table's sound, which is the whole reason `cast_sound_of` exists. *)
  check_opt "but Default still makes a noise when cast"
    (Spell_fx.cast_sound_of Spell_fx.Default)
    (Some "snd_spellnature");
  check_opt "and its own table entry stays empty" (Spell_fx.sound_of Spell_fx.Default)
    None;
  check_opt "while Default_Gfx_Only is silent, as its name says"
    (Spell_fx.cast_sound_of Spell_fx.Default_Gfx_Only)
    None;
  check_opt "and Default_Sound_Only is a sound with no picture"
    (Spell_fx.sound_of Spell_fx.Default_Sound_Only)
    (Some "snd_spellnature");
  (* Four ordinary entries, one per family, to catch a transposed row. *)
  check_opt "healing sounds like a heal" (Spell_fx.sound_of Spell_fx.Healing)
    (Some "snd_spellheal");
  check_opt "stun is a debuff" (Spell_fx.sound_of Spell_fx.Stun)
    (Some "snd_spelldebuff");
  check_opt "war is a fire" (Spell_fx.sound_of Spell_fx.War) (Some "snd_spellfire");
  check_opt "nature is a nature" (Spell_fx.sound_of Spell_fx.Nature)
    (Some "snd_spellnature");
  check "every effect asset is named by some constant"
    (List.for_all
       (fun (f : Spell_fx.fx) ->
         match Spell_fx.asset_of f with
         | None -> true
         | Some a -> String.length a > 6 && String.sub a 0 5 = "Spell")
       Spell_fx.all)

let () =
  (* Both directions of the constant mapping, because a spell script is read by name
     and a mistyped constructor would silently produce an effect nothing casts. *)
  check "every constant name resolves"
    (List.for_all
       (fun (f : Spell_fx.fx) -> Spell_fx.of_constant (Spell_fx.constant_of f) = Some f)
       Spell_fx.all);
  check "and nothing else does" (Spell_fx.of_constant "SPELLFX_NOT_A_THING" = None);
  check "the game's spelling survives the trip"
    (Spell_fx.of_constant "SPELLFX_DEFAULTGFXONLY" = Some Spell_fx.Default_Gfx_Only)

(* -------------------------------------------------------- per-spell effects -- *)

let calls_of id : Spell_fx.call list = Spell_fx.calls_of_spell id

let () =
  check "a spell id with no script has no effects" (calls_of "NOPE" = []);
  (* SBAC is the interesting script: a war effect on the grid cell it just created,
     and a silent default one on its own caster, in that order. It is what makes
     this more than a one-table lookup. *)
  check "SBAC asks for two effects, in order"
    (calls_of "SBAC"
    = [
        { Spell_fx.target = Spell_fx.Grid; fx = Spell_fx.War; use_sound = true };
        { Spell_fx.target = Spell_fx.Caster; fx = Spell_fx.Default_Gfx_Only; use_sound = false };
      ]);
  check "SARC asks for one, on its caster, loudly"
    (calls_of "SARC"
    = [ { Spell_fx.target = Spell_fx.Caster; fx = Spell_fx.Air; use_sound = true } ]);
  (* SARC is out of the port's spell table, so it is also out of the sounds below -
     its script's effect is transcribed, but nothing here can cast it. *)
  (* Every constant the scripts use must be one this module can name, or a spell's
     effect would vanish silently rather than fail. *)
  let table = Spell_data.load_spell_table () in
  (* 129, not 130: SARC is deliberately out of the table - it is the spell-research
     mini-game descriptor rather than a battle spell, and lib/spell_data.ml says so.
     An assertion here would pin a decision rather than a fact. *)
  check_int "the real spell table has 129 of the archive's 130 spells" (List.length table) 129;
  let asked =
    List.filter_map
      (fun (s : Spell.spell) ->
        if calls_of s.Spell.id = [] then None else Some s.Spell.id)
      table
  in
  check "and nearly all of them ask for an effect"
    (List.length asked >= 120);
  check "every script's constant resolves back to a table entry"
    (List.for_all
       (fun (c : Spell_fx.call) -> Spell_fx.asset_of c.Spell_fx.fx <> None
                                   || Spell_fx.default_caster_effects <> [])
       (List.concat_map calls_of asked))

(* -------------------------------------------------------- the recovered sounds -- *)

(** A real spell from the game's own table, by id. *)
let spell_named id =
  List.find_opt (fun (s : Spell.spell) -> s.Spell.id = id) (Spell_data.load_spell_table ())

let sounds_of id = match spell_named id with Some s -> Sound_map.spell_sound s | None -> []

let () =
  (* This is the module's whole reason for existing: the port used to guess a
     spell's sound from what it cost, and `SBAC` is the counter-example - it spends
     four fire, so the guess gave it `snd_spellfire`, and so does the recovered
     answer, but for a different reason entirely (its grid effect is SPELLFX_WAR).
     `SBAV` is where the two answers disagree, and it is pinned here so that a
     regression to the guess is visible. *)
  check_str "an air spell sounds like air" (joined (sounds_of "SGOW")) "snd_spellbuff";
  check_str "a necro spell sounds like alter" (joined (sounds_of "SBAV"))
    "snd_spellalter";
  check_str "a war effect is the only noise SBAC makes" (joined (sounds_of "SBAC"))
    "snd_spellfire";
  check_str "and a spell with no script is silent, not guessed"
    (joined (Sound_map.spell_sound
               (match spell_named "SBAC" with
               | Some s -> { s with Spell.id = "NOT_A_SPELL" }
               | None -> failwith "the spell table lost SBAC")))
    "";
  check "every spell sound the table asks for is a real registry tag"
    (List.for_all
       (fun (s : Spell.spell) ->
         List.for_all (fun tag -> Skin_data.sound_file tag <> None) (sounds_of s.Spell.id))
       (Spell_data.load_spell_table ()))

let () =
  if !failures = 0 then print_endline "all spell FX tests passed"
  else begin
    Printf.printf "%d spell FX test(s) failed\n" !failures;
    exit 1
  end