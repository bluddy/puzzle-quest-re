(* Companion OnStartBattle: the ten hand-ported rule bodies against the
   extracted companion data, the eight-slot party cap on RewardCompanion,
   and the road-battle wiring - combatant skills carried in, pre-battle
   hits riding the log's first event, and the type tags the guards read.

   The hooks only mutate the combatants they are handed and the reward arm
   works on the player value, so unlike test_campaign there is no global
   state to snapshot. The one moving part is a real battle run: EETL's
   sprite resolves to an Undead monster (so NDKH fires before the first
   turn) and ETTR's to a Troll (Large, but not Undead, so it does not). *)

open Puzzle_quest_lib

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let fresh () = Campaign.create_player "Tester" "PWAR" 0 0

let make_hero () = Combat.make_combatant ~cunning:5 ~max_life:100 ~life:80 0 "Hero"

let make_enemy ?(life = 100) ?(fire = 0) () =
  Combat.make_combatant ~max_life:100 ~life
    ~mana:{ Combat.earth = 10; fire = 9; air = 8; water = 7 }
    ~skills:
      {
        Combat.earth = 0;
        fire;
        air = 0;
        water = 0;
        battle = 0;
        morale = 0;
        cunning = 0;
      }
    1 "Foe"

let run_hook ?(rng = fun () -> 100) ?(life = 100) ?(fire = 0) types ids =
  let hero = make_hero () in
  let enemy = make_enemy ~life ~fire () in
  let r =
    Campaign_companion_hooks.apply_start_battle ~rng ~hero ~enemy
      ~enemy_types:types ~companions:ids ()
  in
  (r, hero, enemy)

let activated (r : Campaign_companion_hooks.result) =
  r.Campaign_companion_hooks.activated

let damaged (r : Campaign_companion_hooks.result) =
  r.Campaign_companion_hooks.damaged

(* ------------------------------------------------------------------ *)
(* 1. The extracted data and the rule table agree                      *)
(* ------------------------------------------------------------------ *)

let () =
  let rule_ids = List.map fst Campaign_companion_hooks.rules in
  check "ten rules, one per script" (List.length rule_ids = 10);
  check "ten extracted companions" (List.length Campaign_companions.companions = 10);
  List.iter
    (fun (c : Campaign_companions.companion) ->
      check (c.id ^ " declares OnStartBattle") c.on_start_battle;
      check (c.id ^ " has a hand-ported rule") (List.mem c.id rule_ids);
      check (c.id ^ " name tag resolves")
        (match Text_data.lookup c.name_text with
         | Some t -> t <> c.name_text
         | None -> false);
      check (c.id ^ " description tag resolves")
        (match Text_data.lookup c.desc_text with
         | Some t -> t <> c.desc_text
         | None -> false))
    Campaign_companions.companions;
  List.iter
    (fun id ->
      check (id ^ " is in the extracted data")
        (try (Campaign_companions.companion_by_id id).Campaign_companions.id = id
         with Not_found -> false))
    rule_ids

(* ------------------------------------------------------------------ *)
(* 2. CHECK_TYPE guards: any-of over the monster's type tags           *)
(* ------------------------------------------------------------------ *)

let () =
  let r, _, enemy = run_hook [ "Undead" ] [ "NDKH" ] in
  check "NDKH fires on Undead" (activated r = [ "NDKH" ]);
  check_int "NDKH takes 10" enemy.Combat.life 90;
  check "NDKH reports the hit" (damaged r = [ ("Foe", 10) ]);

  let r, _, enemy = run_hook [ "Large" ] [ "NDKH" ] in
  check "NDKH stays quiet off-type"
    (activated r = [] && damaged r = [] && enemy.Combat.life = 100);

  let r, _, enemy = run_hook [ "Animal" ] [ "NDRO" ] in
  check "NDRO fires on Animal" (activated r = [ "NDRO" ]);
  check_int "NDRO takes 10" enemy.Combat.life 90;
  let r, _, _ = run_hook [ "Evil" ] [ "NDRO" ] in
  check "NDRO stays quiet off-type" (activated r = []);

  let r, hero, enemy = run_hook [ "Large" ] [ "NELI" ] in
  check "NELI fires on Large" (activated r = [ "NELI" ]);
  check_int "NELI adds 10 water resistance"
    (Combat.resistance hero Combat.Water) 10;
  check "NELI does not scratch the enemy" (enemy.Combat.life = 100);

  let r, hero, _ = run_hook [ "Flying" ] [ "NFLI" ] in
  check "NFLI fires on Flying" (activated r = [ "NFLI" ]);
  check_int "NFLI adds 10 air resistance"
    (Combat.resistance hero Combat.Air) 10;

  let r, hero, _ = run_hook [ "Machine" ] [ "NKHA" ] in
  check "NKHA fires on Machine" (activated r = [ "NKHA" ]);
  check_int "NKHA adds 10 battle skill"
    (Combat.skill_in Combat.SBattle hero.Combat.skills) 10;
  let r, hero, _ = run_hook [ "City" ] [ "NKHA" ] in
  check "NKHA fires on City" (activated r = [ "NKHA" ]);
  check_int "City counts too"
    (Combat.skill_in Combat.SBattle hero.Combat.skills) 10;
  let r, hero, _ = run_hook [ "Good" ] [ "NKHA" ] in
  check "NKHA stays quiet on Good"
    (activated r = []
    && Combat.skill_in Combat.SBattle hero.Combat.skills = 0);

  let r, hero, _ = run_hook [ "Good" ] [ "NSER" ] in
  check "NSER fires on Good" (activated r = [ "NSER" ]);
  check_int "NSER adds 10 battle skill"
    (Combat.skill_in Combat.SBattle hero.Combat.skills) 10;
  let r, _, _ = run_hook [ "Animal" ] [ "NSER" ] in
  check "NSER stays quiet off-type" (activated r = []);

  let r, hero, _ = run_hook [ "Minotaur" ] [ "NSUN" ] in
  check "NSUN fires on Minotaur" (activated r = [ "NSUN" ]);
  check_int "NSUN banks 10 hero fire mana" hero.Combat.mana.fire 10;
  let r, hero, _ = run_hook [ "Large" ] [ "NSUN" ] in
  check "NSUN stays quiet off-type"
    (activated r = [] && hero.Combat.mana.fire = 0);

  let r, hero, _ = run_hook [ "Undead" ] [ "NSUS" ] in
  check "NSUS fires on Undead" (activated r = [ "NSUS" ]);
  check_int "NSUS banks 10 hero fire mana" hero.Combat.mana.fire 10;
  let r, hero, _ = run_hook [ "Minotaur" ] [ "NSUS" ] in
  check "NSUS fires on Minotaur" (activated r = [ "NSUS" ]);
  check_int "Minotaur counts too" hero.Combat.mana.fire 10;
  let r, _, _ = run_hook [ "Evil" ] [ "NSUS" ] in
  check "NSUS stays quiet off-type" (activated r = [])

(* ------------------------------------------------------------------ *)
(* 3. NPAT: the roll, then the life guard                             *)
(* ------------------------------------------------------------------ *)

let () =
  let r, _, enemy = run_hook ~rng:(fun () -> 50) [ "Monster" ] [ "NPAT" ] in
  check "NPAT passes on a high roll"
    (activated r = [] && enemy.Combat.life = 100);

  let r, _, enemy = run_hook ~rng:(fun () -> 5) [ "Monster" ] [ "NPAT" ] in
  check "NPAT fires on a low roll" (activated r = [ "NPAT" ]);
  check_int "NPAT takes 25" enemy.Combat.life 75;
  check "NPAT reports the hit" (damaged r = [ ("Foe", 25) ]);

  let r, _, enemy = run_hook ~rng:(fun () -> 5) ~life:25 [ "Monster" ] [ "NPAT" ] in
  check "NPAT spares a 25-life enemy"
    (activated r = [] && enemy.Combat.life = 25);

  let r, _, enemy = run_hook ~rng:(fun () -> 5) ~life:26 [ "Monster" ] [ "NPAT" ] in
  check "NPAT fires when life is 26" (activated r = [ "NPAT" ]);
  check_int "lethal edge leaves 1" enemy.Combat.life 1

(* ------------------------------------------------------------------ *)
(* 4. NWIN: halve the enemy's four banks at fire skill 15              *)
(* ------------------------------------------------------------------ *)

let () =
  let r, _, enemy = run_hook ~fire:15 [ "Monster" ] [ "NWIN" ] in
  check "NWIN fires at fire 15" (activated r = [ "NWIN" ]);
  let m = enemy.Combat.mana in
  check "NWIN halves all four banks"
    (m.Combat.earth = 5 && m.Combat.fire = 4 && m.Combat.air = 4 && m.Combat.water = 3);
  check "NWIN cuts no life" (enemy.Combat.life = 100);

  let r, _, enemy = run_hook ~fire:14 [ "Monster" ] [ "NWIN" ] in
  let m = enemy.Combat.mana in
  check "NWIN stays quiet below 15"
    (activated r = []
    && m.Combat.earth = 10 && m.Combat.fire = 9 && m.Combat.air = 8
    && m.Combat.water = 7)

(* ------------------------------------------------------------------ *)
(* 5. The party list: order, dedup, unknown ids, lethal edge           *)
(* ------------------------------------------------------------------ *)

let () =
  let r, _, enemy = run_hook [ "Undead" ] [ "NDKH"; "NDKH" ] in
  check "a duplicated id fires once" (activated r = [ "NDKH" ]);
  check_int "one hit, not two" enemy.Combat.life 90;

  let r, _, _ = run_hook [ "Undead" ] [ "ZZZZ" ] in
  check "an unknown id is inert" (activated r = []);

  let r, hero, enemy = run_hook [ "Undead"; "Large" ] [ "NDKH"; "NELI" ] in
  check "party order is preserved" (activated r = [ "NDKH"; "NELI" ]);
  check "both payoffs land"
    (enemy.Combat.life = 90 && Combat.resistance hero Combat.Water = 10);

  let r, _, enemy = run_hook ~life:8 [ "Undead" ] [ "NDKH" ] in
  check "a lethal hit clamps at zero and kills"
    (enemy.Combat.life = 0 && enemy.Combat.is_dead && activated r = [ "NDKH" ])

(* ------------------------------------------------------------------ *)
(* 6. Skills carried into combatants, and the type tag helper          *)
(* ------------------------------------------------------------------ *)

let () =
  let p = fresh () in
  let hero = Campaign.player_to_combatant p in
  check "the player's affinities reach the combatant"
    (hero.Combat.skills = Campaign.to_combat_skills p.Campaign.skills
    && hero.Combat.skills.battle = 1);

  let enc = Campaign_encounters.encounter_by_id "ETTR" in
  let foe = Campaign.encounter_to_combatant enc 1 in
  let tro = Campaign_monsters.monster_by_sprite enc.Campaign_encounters.sprite in
  check "the monster's affinities reach the combatant"
    (foe.Combat.skills = Campaign.to_combat_skills tro.Campaign_monsters.skills);
  check_int "Troll battle skill comes through" foe.Combat.skills.battle 10;

  let tro2 = Campaign_monsters.monster_by_id "MTRO" in
  check "monster_type_tags reads the four slots, dropping empties"
    (Campaign.monster_type_tags tro2 = [ "Monster"; "Large"; "Evil" ])

(* ------------------------------------------------------------------ *)
(* 7. RewardCompanion: dedup, and eight slots                         *)
(* ------------------------------------------------------------------ *)

let () =
  let base = fresh () in
  let seven = { base with Campaign.companions = [ "C1"; "C2"; "C3"; "C4"; "C5"; "C6"; "C7" ] } in
  let got = Campaign.apply_quest_effect seven (Campaign.RewardCompanion "NDKH") in
  check_int "the eighth companion lands" (List.length got.Campaign.companions) 8;

  let eight = { seven with Campaign.companions = seven.Campaign.companions @ [ "C8" ] } in
  let full = Campaign.apply_quest_effect eight (Campaign.RewardCompanion "NFLI") in
  check_int "a full party turns the ninth away" (List.length full.Campaign.companions) 8;
  check "the turned-away id never lands" (not (List.mem "NFLI" full.Campaign.companions));

  let dup = { seven with Campaign.companions = "NDKH" :: List.tl seven.Campaign.companions } in
  let same = Campaign.apply_quest_effect dup (Campaign.RewardCompanion "NDKH") in
  check_int "a duplicate grant changes nothing" (List.length same.Campaign.companions) 7;
  check "the duplicate stays a single entry"
    (List.length (List.filter (fun c -> c = "NDKH") same.Campaign.companions) = 1)

(* ------------------------------------------------------------------ *)
(* 8. Wiring: a road battle runs the party's hook before the first turn *)
(* ------------------------------------------------------------------ *)

let () =
  let enc_undead = Campaign_encounters.encounter_by_id "EETL" in
  let mark = Campaign_monsters.monster_by_sprite enc_undead.Campaign_encounters.sprite in
  check "EETL's sprite resolves to an Undead monster"
    (List.mem "Undead" (Campaign.monster_type_tags mark));

  let p = { (fresh ()) with Campaign.companions = [ "NDKH" ] } in
  let b = Campaign.run_encounter_battle p enc_undead in
  check "the pre-battle hit is the log's first event"
    (match Battle.log_of b with
     | Battle.Damage (n, 10) :: _ -> n = mark.Campaign_monsters.name_text
     | _ -> false);
  check "the hero keeps the player's skills through the run"
    (b.Battle.hero.Combat.skills = Campaign.to_combat_skills p.Campaign.skills);

  let enc_large = Campaign_encounters.encounter_by_id "ETTR" in
  let p2 = { (fresh ()) with Campaign.companions = [ "NDKH" ] } in
  let b2 = Campaign.run_encounter_battle p2 enc_large in
  check "off-type, the log opens on the first turn"
    (match Battle.log_of b2 with
     | Battle.Damage _ :: _ -> false
     | ev :: _ -> (match ev with Battle.TurnStart _ -> true | _ -> false)
     | [] -> false)

(* ------------------------------------------------------------------ *)

let () =
  if !failures > 0 then begin
    Printf.printf "%d failure(s)\n" !failures;
    exit 1
  end;
  Printf.printf "all ok\n"
