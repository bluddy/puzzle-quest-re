(* Which sound a battle event plays.

   The cascade rule is the part worth pinning: it is **recovered** from
   `Sub_47ae80.c`, and it is the sort of detail that is invisible until it is
   missing - a port that made a noise on every match would be wrong in a way no
   screenshot or log would show. *)

open Pq_gfx
open Puzzle_quest_lib

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

let joined e = String.concat "," (Sound_map.of_event e)

(** A match result with nothing in it. [Sound_map] only ever looks at the cascade
    step, so the contents do not matter - but a `MatchResolved` event cannot be
    built without one, and a real one would drag a board along with it. *)
let no_match : Board.match_result =
  {
    gems_cleared = [];
    air_mana = 0;
    earth_mana = 0;
    fire_mana = 0;
    water_mana = 0;
    gold = 0;
    xp = 0;
    damage = 0;
    extra_turn = false;
    wildcards_created = [];
    heroic_effort = false;
    runs = [];
  }

(* ---------------------------------------------------------------- cascade -- *)

let test_cascade_is_silent_at_first () =
  (* `switch (counter) { case 0: case 1: goto skip; ... }` with the counter
     incremented *before* the switch. [Battle.MatchResolved] carries that
     post-increment counter, which starts at 1 for the first step - so in practice
     only step 1 is silent, and it is silent because the counter landed in the
     `case 1` arm. This is the part that is easy to "fix" by accident: a port that
     gave the first match a noise would pass every other test here. *)
  check "step 1 is silent" (Sound_map.cascade 1 = None);
  check "step 0 is silent too" (Sound_map.cascade 0 = None);
  check "and there is no step that plays nothing after that"
    (Sound_map.cascade 2 <> None)

let test_cascade_climbs () =
  (* The counter is the switch subject, so `case 2: snd_cascade1` means the
     *second* step plays the *first* sound. The off-by-one is in the recovered
     code, not in the transcription. *)
  check_str "step 2 plays cascade1" (Option.get (Sound_map.cascade 2)) "snd_cascade1";
  check_str "step 3 plays cascade2" (Option.get (Sound_map.cascade 3)) "snd_cascade2";
  check_str "step 4 plays cascade3" (Option.get (Sound_map.cascade 4)) "snd_cascade3";
  (* Step 5 is the one that fires Heroic Effort, so this is the boundary worth
     being sure about: cascade4, not cascade5. *)
  check_str "step 5 plays cascade4" (Option.get (Sound_map.cascade 5)) "snd_cascade4";
  check_str "step 6 plays cascade5" (Option.get (Sound_map.cascade 6)) "snd_cascade5";
  (* `default:` catches everything past the last case, so a very long chain keeps
     making the same noise rather than running off the end of a table. *)
  check_str "step 7 plays cascade6" (Option.get (Sound_map.cascade 7)) "snd_cascade6";
  check_str "step 40 still plays cascade6" (Option.get (Sound_map.cascade 40))
    "snd_cascade6"

let test_match_event () =
  (* The event carries the step, so a two-step cascade makes exactly one noise. *)
  check_str "a first-step match is silent"
    (joined (Battle.MatchResolved (1, no_match))) "";
  check_str "a second-step match plays"
    (joined (Battle.MatchResolved (2, no_match))) "snd_cascade1";
  check_str "a third-step match climbs"
    (joined (Battle.MatchResolved (3, no_match))) "snd_cascade2"

(* ------------------------------------------------------------ the others -- *)

let test_plain_events () =
  check_str "damage" (joined (Battle.Damage ("foe", 5))) "snd_damage";
  check_str "extra turn" (joined (Battle.ExtraTurn "you")) "snd_extraturn";
  check_str "gold" (joined (Battle.GoldGained ("you", 1))) "snd_gold";
  check_str "xp" (joined (Battle.XpGained ("you", 1))) "snd_xp";
  check_str "a held spell" (joined (Battle.SpellHeld "you")) "snd_resistspell";
  check_str "the hero's turn" (joined (Battle.TurnStart (0, Battle.Hero, "you")))
    "snd_newturn";
  check_str "the foe's turn" (joined (Battle.TurnStart (1, Battle.Enemy, "foe")))
    "snd_enemyturn"

let test_heroic_effort_plays_two () =
  (* Voice first, then the effect - both, in that order, from the same function. *)
  check_str "heroic effort plays the voice then the effect"
    (joined (Battle.HeroicEffort "you"))
    "snd_voice_heroiceffort,snd_heroiceffort"

let test_battle_end_plays_two () =
  (* Same shape: the voice line, then the sting. *)
  check_str "victory" (joined (Battle.BattleEnd Battle.HeroVictory))
    "snd_voice_victory,snd_victory";
  check_str "defeat" (joined (Battle.BattleEnd Battle.EnemyVictory))
    "snd_voice_defeat,snd_defeat"

let test_element_sounds () =
  (* The ids are the board's: 1 Earth, 2 Fire, 3 Water, 4 Air - which is the
     transposition that has bitten this port in mana, status effects and the AI. *)
  check_str "earth" (Option.get (Sound_map.element_sound 1)) "snd_earth";
  check_str "fire" (Option.get (Sound_map.element_sound 2)) "snd_fire";
  check_str "water" (Option.get (Sound_map.element_sound 3)) "snd_water";
  check_str "air" (Option.get (Sound_map.element_sound 4)) "snd_air";
  check "an id that is not an element has no sound" (Sound_map.element_sound 0 = None);
  check_str "and a fire mana gain says so"
    (joined (Battle.ManaGained ("you", 2, 3))) "snd_fire";
  check "an out-of-range element is silent"
    (joined (Battle.ManaGained ("you", 9, 3)) = "")

let test_quiet_events () =
  (* These make no sound in the original, and a port that adds some would be
     inventing behaviour. *)
  List.iter
    (fun (name, e) -> check (name ^ " is silent") (Sound_map.of_event e = []))
    [ ("a swap", Battle.Swap (0, 0, Ai.Horizontal));
      ("a banked turn", Battle.BankedTurn "you");
      ("a size turn", Battle.SizeTurn "you");
      ("a refill", Battle.Refilled);
      ("a mana burn", Battle.ManaBurn);
      ("a turn ending", Battle.TurnEnd 1);
      ("a stalemate", Battle.BattleEnd Battle.Stalemate);
      (* Mana burn deserves the note: the archive has no sound tagged for it, so
         there is nothing to play even if the mapping wanted to. *)
      ("a mana burn, which has no tag at all", Battle.ManaBurn) ]

let test_every_tag_exists () =
  (* The mapping may only name tags the registry has. A typo here is silent in the
     same way a missing atlas was: the battle runs and simply makes no noise. *)
  let tags = ref [] in
  List.iter
    (fun e -> List.iter (fun s -> tags := s :: !tags) (Sound_map.of_event e))
    [ Battle.Damage ("x", 1); Battle.ManaGained ("x", 1, 1);
      Battle.ManaGained ("x", 2, 1); Battle.ManaGained ("x", 3, 1);
      Battle.ManaGained ("x", 4, 1); Battle.GoldGained ("x", 1);
      Battle.XpGained ("x", 1); Battle.ExtraTurn "x"; Battle.HeroicEffort "x";
      Battle.SpellHeld "x"; Battle.TurnStart (0, Battle.Hero, "x");
      Battle.TurnStart (0, Battle.Enemy, "x"); Battle.BattleEnd Battle.HeroVictory;
      Battle.BattleEnd Battle.EnemyVictory; Battle.MatchResolved (2, no_match) ];
  List.iter
    (fun step ->
      match Sound_map.cascade step with
      | Some s -> tags := s :: !tags
      | None -> ())
    [ 2; 3; 4; 5; 6; 7; 8 ];
  check "the mapping produced some tags" (!tags <> []);
  List.iter
    (fun tag ->
      check ("the registry knows " ^ tag) (Skin_data.sound_of_tag tag <> None))
    !tags;
  (* And every one of those tags must actually have audio behind it, not just be
     declared - which is how the music tags would fail. *)
  List.iter
    (fun tag ->
      check (tag ^ " has a file") (Skin_data.sound_file tag <> None))
    (List.sort_uniq String.compare !tags)

let () =
  test_cascade_is_silent_at_first ();
  test_cascade_climbs ();
  test_match_event ();
  test_plain_events ();
  test_heroic_effort_plays_two ();
  test_battle_end_plays_two ();
  test_element_sounds ();
  test_quiet_events ();
  test_every_tag_exists ();
  if !failures = 0 then print_endline "all sound map tests passed"
  else begin
    Printf.printf "%d sound map test(s) failed\n" !failures;
    exit 1
  end