(* The rune registries and the forge arithmetic: the tables out of
   Assets/Runes/Runes.xml, the claim gates, the gifted starting runes, and
   the computation the modifier descriptions pin verbatim - UMAS "Adds +2
   to Base Rune ability", UCHA "Adds -1 to Base Rune ability and adds
   +150% to Power Rune ability" - plus the save round-trip. *)

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

let spec base modifier power runes =
  Campaign.forge_rune { (fresh ()) with Campaign.runes = runes }
    ~base ~modifier ~power

let spec_of base modifier power runes =
  match spec base modifier power runes with
  | Some s -> s
  | None -> failwith (Printf.sprintf "no forge spec for %s+%s+%s" base modifier power)

(* ------------------------------------------------------------------ *)
(* 1. The tables                                                      *)
(* ------------------------------------------------------------------ *)

let () =
  check_int "15 base runes ship" (List.length Campaign_runes.base_runes) 15;
  check_int "10 modifier runes ship" (List.length Campaign_runes.modifier_runes) 10;
  check_int "13 power runes ship" (List.length Campaign_runes.power_runes) 13;
  check_int "the 150 (base, modifier) names ship"
    (List.length Campaign_runes.forged_names) 150;
  check "the name table covers the full base x modifier grid"
    (List.length Campaign_runes.forged_names
    = List.length Campaign_runes.base_runes
      * List.length Campaign_runes.modifier_runes);
  check "every forged name pairs a real base and a real modifier"
    (List.for_all
       (fun n ->
         List.exists
           (fun (b : Campaign_runes.base_rune) ->
             b.Campaign_runes.id = n.Campaign_runes.base)
           Campaign_runes.base_runes
         && List.exists
              (fun (m : Campaign_runes.modifier_rune) ->
                m.Campaign_runes.id = n.Campaign_runes.modifier)
              Campaign_runes.modifier_runes)
       Campaign_runes.forged_names);
  check "rune ids are unique across the three registries"
    (let all =
       List.map (fun r -> Campaign_runes.Base_rune r) Campaign_runes.base_runes
       @ List.map
           (fun r -> Campaign_runes.Modifier_rune r)
           Campaign_runes.modifier_runes
       @ List.map
           (fun r -> Campaign_runes.Power_rune r)
           Campaign_runes.power_runes
     in
     let ids = List.map Campaign_runes.rune_id all in
     List.length ids = List.length (List.sort_uniq compare ids));
  check "base codes - JXXX's switch keys - are unique"
    (let cs =
       List.map
         (fun (r : Campaign_runes.base_rune) -> r.Campaign_runes.code)
         Campaign_runes.base_runes
     in
     List.length cs = List.length (List.sort_uniq compare cs));
  check "the UAXE+UMAS pair forges the Hatchet"
    (Campaign_runes.forged_name_of "UAXE" "UMAS"
    = Some
        { Campaign_runes.base = "UAXE"; modifier = "UMAS";
          name_text = "[RUNE_UAXE_UMAS_NAME]"; icon = 89 }
    && Text_data.text "[RUNE_UAXE_UMAS_NAME]" = "Hatchet")

(* ------------------------------------------------------------------ *)
(* 2. The gifted runes and the claim gates                            *)
(* ------------------------------------------------------------------ *)

let () =
  check "a fresh hero holds the three gifted runes"
    ((fresh ()).Campaign.runes = [ "UDAG"; "UCRA"; "UFIR" ]);
  check "the gifted runes sit nowhere and guard nothing"
    (List.for_all
       (fun id ->
         match Campaign_runes.rune_by_id id with
         | Some k ->
             Campaign_runes.rune_location k = ""
             && Campaign_runes.rune_guard k = ""
         | None -> false)
       [ "UDAG"; "UCRA"; "UFIR" ]);
  let p = { (fresh ()) with Campaign.current_city = Some "WSGK" } in
  check "standing at a rune's node with it unheld makes it claimable"
    (Campaign.rune_claimable p "USWO");
  (match Campaign.claim_rune p "USWO" with
  | Some q ->
      check "claiming adds the rune"
        (q.Campaign.runes = [ "USWO"; "UDAG"; "UCRA"; "UFIR" ]);
      check "a held rune is not claimable again"
        (not (Campaign.rune_claimable q "USWO"))
  | None -> check "claiming adds the rune" false);
  check "a world rune elsewhere is not claimable"
    (not (Campaign.rune_claimable (fresh ()) "USWO"));
  check "the gifted runes are never claimable"
    (not (Campaign.rune_claimable { p with Campaign.runes = [] } "UDAG"));
  check "an unknown rune is not claimable"
    (not (Campaign.rune_claimable p "ZZZZ"))

(* ------------------------------------------------------------------ *)
(* 3. The forge arithmetic, as the descriptions state it              *)
(* ------------------------------------------------------------------ *)

let () =
  let s =
    spec_of "UDAG" "UCRA" "UFIR" [ "UDAG"; "UCRA"; "UFIR" ]
  in
  check "the gifted triple forges the basic item"
    (s.Campaign.name_text = "[RUNE_UDAG_UCRA_NAME]"
    && s.Campaign.icon = 51
    && s.Campaign.position = "weapon");
  check_int "the basic modifier adds nothing to the base" s.Campaign.base_data 1;
  check_int "nor to the power" s.Campaign.power_data 2;
  check_int "the basic difficulty is the base's own" s.Campaign.difficulty 100;

  let s2 = spec_of "UAXE" "UMAS" "UTRO" [ "UAXE"; "UMAS"; "UTRO" ] in
  check "UMAS keeps the base's name and slot"
    (s2.Campaign.name_text = "[RUNE_UAXE_UMAS_NAME]"
    && s2.Campaign.position = "weapon");
  check_int "UMAS adds +2 to the base ability (its own words)" s2.Campaign.base_data 5;
  check_int "UMAS leaves the power alone" s2.Campaign.power_data 8;
  check_int "and scales the difficulty by 1.2" s2.Campaign.difficulty 240;

  let s3 = spec_of "UDAG" "UCHA" "UGRE" [ "UDAG"; "UCHA"; "UGRE" ] in
  check_int "UCHA adds -1 to the base ability" s3.Campaign.base_data 0;
  check_int "and +150% to the power (20 -> 50)" s3.Campaign.power_data 50;
  check_int "with the difficulty doubled" s3.Campaign.difficulty 200;

  let s4 = spec_of "USHI" "UELV" "UFIR" [ "USHI"; "UELV"; "UFIR" ] in
  check_int "a fractional power rounds to nearest (2 x 1.75 = 3.5 -> 4)"
    s4.Campaign.power_data 4;

  let s5 = spec_of "UDAG" "UGOD" "ULIF" [ "UDAG"; "UGOD"; "ULIF" ] in
  check_int "UGOD adds +3 to the base ability" s5.Campaign.base_data 4;
  check_int "and doubles the power" s5.Campaign.power_data 40;
  check_int "its diff_add stacks before the x3 (100+50)x3" s5.Campaign.difficulty 450;

  check "the forge refuses runes the hero does not hold"
    (spec "UAXE" "UMAS" "UTRO" [ "UDAG"; "UCRA"; "UFIR" ] = None);
  check "the forge refuses an unknown rune"
    (spec "ZZZZ" "UCRA" "UFIR" [ "ZZZZ"; "UCRA"; "UFIR" ] = None)

(* ------------------------------------------------------------------ *)
(* 4. Save / load round-trip, and the pre-rune default                *)
(* ------------------------------------------------------------------ *)

let () =
  let path = Filename.temp_file "pq_runes_test" ".json" in
  let sp = { (fresh ()) with Campaign.runes = [ "UDAG"; "USWO"; "UFIR" ] } in
  let save = Campaign_save.create_save_data sp [] "CGAL" 0 in
  Campaign_save.save_to_file path save;
  let loaded = Campaign_save.load_from_file path in
  let p2, _, _, _, _, _ = Campaign_save.apply_save loaded in
  Sys.remove path;
  check "load restores the runes"
    (p2.Campaign.runes = [ "UDAG"; "USWO"; "UFIR" ]);

  (* A save written before runes existed: the key is absent and the list
     starts empty - the gifted runes ride with a fresh hero, not a load. *)
  let stripped =
    match Campaign_save.save_campaign_to_json save with
    | `Assoc fs ->
        `Assoc
          (List.map
             (fun (k, v) ->
               if k = "player" then
                 (k,
                  match v with
                  | `Assoc pfs ->
                      `Assoc (List.filter (fun (n, _) -> n <> "runes") pfs)
                  | other -> other)
               else (k, v))
             fs)
    | other -> other
  in
  let old = Campaign_save.save_campaign_of_json stripped in
  let p3, _, _, _, _, _ = Campaign_save.apply_save old in
  check "an old save loads no runes" (p3.Campaign.runes = [])

let () =
  if !failures = 0 then print_endline "all rune tests passed"
  else begin
    Printf.printf "%d rune test(s) failed\n" !failures;
    exit 1
  end
