open Puzzle_quest_lib.Board

let assert_eq msg expected actual =
  if expected <> actual then begin
    Printf.eprintf "FAIL: %s (expected %s, got %s)\n" msg
      (string_of_bool (expected = actual))
      (string_of_bool false);
    exit 1
  end

(** Creates a base 8x8 board with zero initial matches:
    Adjacent cells in X differ by 1 mod 4, in Y by 2 mod 4. *)
let non_matching_board () =
  let matrix =
    Array.init 8 (fun y ->
      Array.init 8 (fun x ->
        let elem =
          match (x + y * 2) mod 4 with
          | 0 -> Air
          | 1 -> Earth
          | 2 -> Fire
          | _ -> Water
        in
        Mana elem))
  in
  of_array_matrix matrix

let test_3_match () =
  Printf.printf "Running test_3_match...\n";
  let b = non_matching_board () in
  (* Place 3 Skulls at row 0, cols 1..3 purely functionally *)
  let b =
    b
    |> set_gem { x = 1; y = 0 } Skull
    |> set_gem { x = 2; y = 0 } Skull
    |> set_gem { x = 3; y = 0 } Skull
  in
  let matches = find_matches b in
  assert_eq "Should find exactly 1 match" 1 (List.length matches);
  let res = resolve_matches b in
  match res with
  | None -> failwith "Expected match result"
  | Some (_, r) ->
      assert_eq "Damage should be 3 for 3 skulls" 3 r.damage;
      assert_eq "No extra turn for 3-match" false r.extra_turn;
      Printf.printf "  [PASS] test_3_match passed!\n"

let test_4_match_extra_turn () =
  Printf.printf "Running test_4_match_extra_turn...\n";
  let b = non_matching_board () in
  (* Row of 4 Gold coins at row 2, cols 1..4 *)
  let b =
    b
    |> set_gem { x = 1; y = 2 } Gold
    |> set_gem { x = 2; y = 2 } Gold
    |> set_gem { x = 3; y = 2 } Gold
    |> set_gem { x = 4; y = 2 } Gold
  in
  let res = resolve_matches b in
  match res with
  | None -> failwith "Expected match result"
  | Some (_, r) ->
      assert_eq "Gold collected should be 4" 4 r.gold;
      assert_eq "Extra turn should be true for 4-match" true r.extra_turn;
      Printf.printf "  [PASS] test_4_match_extra_turn passed!\n"

let test_5_match_wildcard () =
  Printf.printf "Running test_5_match_wildcard...\n";
  let b = ref (non_matching_board ()) in
  (* Row of 5 Experience stars at row 4, cols 1..5 *)
  for x = 1 to 5 do
    b := set_gem { x; y = 4 } Experience !b
  done;

  let res = resolve_matches !b in
  match res with
  | None -> failwith "Expected match result"
  | Some (b_after, r) ->
      assert_eq "XP collected should be 5" 5 r.xp;
      assert_eq "Extra turn should be true for 5-match" true r.extra_turn;
      assert_eq "Should create 1 wildcard" 1 (List.length r.wildcards_created);
      let wildcard_pos, mult = List.hd r.wildcards_created in
      assert_eq "Wildcard pos x should be 3" 3 wildcard_pos.x;
      assert_eq "Wildcard mult should be 5" 5 mult;
      assert_eq "Wildcard placed on board" (Wildcard 5) (get_gem b_after wildcard_pos);
      Printf.printf "  [PASS] test_5_match_wildcard passed!\n"

let test_valid_and_invalid_swap () =
  Printf.printf "Running test_valid_and_invalid_swap...\n";
  let b = non_matching_board () in
  (* Setup a near-match on row 3:
     Cols: [0: Air, 1: Fire, 2: Fire, 3: Water, 4: Air]
     Row 4, Col 3: Fire
     Swapping (3, 3) with (3, 4) brings Fire up to form Fire at 1, 2, 3! *)
  let b =
    b
    |> set_gem { x = 0; y = 3 } (Mana Air)
    |> set_gem { x = 1; y = 3 } (Mana Fire)
    |> set_gem { x = 2; y = 3 } (Mana Fire)
    |> set_gem { x = 3; y = 3 } (Mana Water)
    |> set_gem { x = 4; y = 3 } (Mana Air)
    |> set_gem { x = 3; y = 4 } (Mana Fire)
  in

  let valid = is_valid_swap b { x = 3; y = 3 } { x = 3; y = 4 } in
  assert_eq "Swap should be valid" true valid;

  (* Swapping (0, 0) with (1, 0) creates no match *)
  let invalid = is_valid_swap b { x = 0; y = 0 } { x = 1; y = 0 } in
  assert_eq "Swap should be invalid" false invalid;
  Printf.printf "  [PASS] test_valid_and_invalid_swap passed!\n"

let test_gravity () =
  Printf.printf "Running test_gravity...\n";
  let b = non_matching_board () in
  (* Clear bottom two cells of column 0 and put Skull at row 5 *)
  let b =
    b
    |> set_gem { x = 0; y = 7 } Empty
    |> set_gem { x = 0; y = 6 } Empty
    |> set_gem { x = 0; y = 5 } Skull
  in
  let b_dropped = apply_gravity b in
  assert_eq "Bottom cell (0, 7) should now have Skull" Skull (get_gem b_dropped { x = 0; y = 7 });
  assert_eq "Top cell (0, 0) should now be Empty" Empty (get_gem b_dropped { x = 0; y = 0 });
  assert_eq "Top cell (0, 1) should now be Empty" Empty (get_gem b_dropped { x = 0; y = 1 });
  Printf.printf "  [PASS] test_gravity passed!\n"

let test_mana_burn () =
  Printf.printf "Running test_mana_burn...\n";
  (* A board with 7 distinct gem types distributed via (x*2 + y*3) mod 7,
     guaranteeing 0 pre-existing matches and 0 legal moves *)
  let matrix =
    Array.init 8 (fun y ->
      Array.init 8 (fun x ->
        match (x * 2 + y * 3) mod 7 with
        | 0 -> Mana Air
        | 1 -> Mana Earth
        | 2 -> Mana Fire
        | 3 -> Mana Water
        | 4 -> Skull
        | 5 -> Gold
        | _ -> Experience))
  in
  let b = of_array_matrix matrix in
  let moves = find_all_legal_moves b in
  assert_eq "Board with pattern should have 0 moves" 0 (List.length moves);
  assert_eq "Should trigger Mana Burn" true (is_mana_burn b);
  Printf.printf "  [PASS] test_mana_burn passed!\n"

let () =
  Printf.printf "=== PUZZLE QUEST MATCH-3 SIMULATION ENGINE TESTS ===\n\n";
  test_3_match ();
  test_4_match_extra_turn ();
  test_5_match_wildcard ();
  test_valid_and_invalid_swap ();
  test_gravity ();
  test_mana_burn ();
  Printf.printf "\nALL TESTS PASSED SUCCESSFULLY!\n"
