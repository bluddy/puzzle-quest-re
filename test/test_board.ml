open Puzzle_quest_lib.Board

let assert_eq msg expected actual =
  if expected <> actual then begin
    Printf.eprintf "FAIL: %s (expected %s, got %s)\n" msg
      (string_of_bool (expected = actual))
      (string_of_bool false);
    exit 1
  end

(** Creates a base 8x8 grid with zero initial matches:
    Adjacent cells in X differ by 1 mod 4, in Y by 2 mod 4. *)
let non_matching_grid () =
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

let test_3_match () =
  Printf.printf "Running test_3_match...\n";
  let grid = non_matching_grid () in
  (* Place 3 Skulls at row 0, cols 1..3 *)
  grid.(0).(1) <- Skull;
  grid.(0).(2) <- Skull;
  grid.(0).(3) <- Skull;

  let b = create_board grid in
  let matches = find_matches b in
  assert_eq "Should find exactly 1 match" 1 (List.length matches);
  let res = resolve_matches b in
  match res with
  | None -> failwith "Expected match result"
  | Some r ->
      assert_eq "Damage should be 3 for 3 skulls" 3 r.damage;
      assert_eq "No extra turn for 3-match" false r.extra_turn;
      Printf.printf "  [PASS] test_3_match passed!\n"

let test_4_match_extra_turn () =
  Printf.printf "Running test_4_match_extra_turn...\n";
  let grid = non_matching_grid () in
  (* Row of 4 Gold coins at row 2, cols 1..4 *)
  grid.(2).(1) <- Gold;
  grid.(2).(2) <- Gold;
  grid.(2).(3) <- Gold;
  grid.(2).(4) <- Gold;

  let b = create_board grid in
  let res = resolve_matches b in
  match res with
  | None -> failwith "Expected match result"
  | Some r ->
      assert_eq "Gold collected should be 4" 4 r.gold;
      assert_eq "Extra turn should be true for 4-match" true r.extra_turn;
      Printf.printf "  [PASS] test_4_match_extra_turn passed!\n"

let test_5_match_wildcard () =
  Printf.printf "Running test_5_match_wildcard...\n";
  let grid = non_matching_grid () in
  (* Row of 5 Experience stars at row 4, cols 1..5 *)
  for x = 1 to 5 do grid.(4).(x) <- Experience done;

  let b = create_board grid in
  let res = resolve_matches b in
  match res with
  | None -> failwith "Expected match result"
  | Some r ->
      assert_eq "XP collected should be 5" 5 r.xp;
      assert_eq "Extra turn should be true for 5-match" true r.extra_turn;
      assert_eq "Should create 1 wildcard" 1 (List.length r.wildcards_created);
      let wildcard_pos, mult = List.hd r.wildcards_created in
      assert_eq "Wildcard pos x should be 3" 3 wildcard_pos.x;
      assert_eq "Wildcard mult should be 5" 5 mult;
      Printf.printf "  [PASS] test_5_match_wildcard passed!\n"

let test_valid_and_invalid_swap () =
  Printf.printf "Running test_valid_and_invalid_swap...\n";
  let grid = non_matching_grid () in
  (* Setup a near-match on row 3:
     Cols: [0: Air, 1: Fire, 2: Fire, 3: Water, 4: Air]
     Row 4, Col 3: Fire
     Swapping (3, 3) with (3, 4) brings Fire up to form Fire at 1, 2, 3! *)
  grid.(3).(0) <- Mana Air;
  grid.(3).(1) <- Mana Fire;
  grid.(3).(2) <- Mana Fire;
  grid.(3).(3) <- Mana Water;
  grid.(3).(4) <- Mana Air;
  grid.(4).(3) <- Mana Fire;

  let b = create_board grid in
  let valid = is_valid_swap b { x = 3; y = 3 } { x = 3; y = 4 } in
  assert_eq "Swap should be valid" true valid;

  (* Swapping (0, 0) with (1, 0) creates no match *)
  let invalid = is_valid_swap b { x = 0; y = 0 } { x = 1; y = 0 } in
  assert_eq "Swap should be invalid" false invalid;
  Printf.printf "  [PASS] test_valid_and_invalid_swap passed!\n"

let test_gravity () =
  Printf.printf "Running test_gravity...\n";
  let grid = non_matching_grid () in
  (* Clear bottom two cells of column 0 *)
  grid.(7).(0) <- Empty;
  grid.(6).(0) <- Empty;
  grid.(5).(0) <- Skull;

  let b = create_board grid in
  apply_gravity b;
  assert_eq "Bottom cell (0, 7) should now have Skull" Skull b.grid.(7).(0);
  assert_eq "Top cell (0, 0) should now be Empty" Empty b.grid.(0).(0);
  assert_eq "Top cell (0, 1) should now be Empty" Empty b.grid.(1).(0);
  Printf.printf "  [PASS] test_gravity passed!\n"

let () =
  Printf.printf "=== PUZZLE QUEST MATCH-3 SIMULATION ENGINE TESTS ===\n\n";
  test_3_match ();
  test_4_match_extra_turn ();
  test_5_match_wildcard ();
  test_valid_and_invalid_swap ();
  test_gravity ();
  Printf.printf "\nALL TESTS PASSED SUCCESSFULLY!\n"
