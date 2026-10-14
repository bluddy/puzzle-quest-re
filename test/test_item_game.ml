(* The forge skill game's engine: the recovered rules image made playable
   (Rules_ItemGame.png), plus the three numbers that are port choices
   (port.item_game_numbers in docs/reverse/evidence.yml).

   What is under test, in the rule set's own order:
   - a Hammer matches only hammers and scores a point when destroyed;
   - a run of 4 destroys its own row or column ("4-OF-A-KIND: Destroys a row
     or column"), which is how a hammer that will not line up still dies;
   - a run of 5 destroys every gem of its type as well ("all gems of matching
     type and a row or column") - a five-hammer line therefore sweeps a
     sixth hammer off the far corner;
   - a cascade [depth] deep spawns a random hammer ("HEROIC EFFORT: Creates
     a random Hammer & Anvil on the board"); [heroic_depth] itself is the
     recovered threshold, [HEROICEFFORT_TEXT]'s "5 or more series", and the
     tests reach the spawn by lowering [depth] rather than by building a
     five-step cascade;
   - any destruction resets the board ("Each time one or more of them are
     destroyed, the board will reset"), back to the full hammer budget;
   - no legal move is defeat ("You lose if there are no moves left" - the
     second half of that line is clipped in the shipped art).

   Boards are built from a diagonal filler pattern (every row a rotation of
   four elements, so no run exists anywhere) with the interesting cells set
   on top, the way test_board's fixtures do. *)

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

(* A deterministic stateful LCG, never a constant function of the bound -
   the shuffle and the hammer seeding both roll per cell, and a constant
   would deal the same cell forever (AGENTS.md). *)
let seed_state = ref 0

let seed n =
  seed_state := (!seed_state * 75 + 74) mod 65537;
  if n <= 0 then 0 else !seed_state mod n

let g_of_char = function
  | 'E' -> Board.Mana Board.Earth
  | 'F' -> Board.Mana Board.Fire
  | 'Y' -> Board.Mana Board.Air
  | 'B' -> Board.Mana Board.Water
  | 'S' -> Board.Skull
  | 'R' -> Board.RedSkull
  | 'O' -> Board.Gold
  | 'X' -> Board.Experience
  | 'H' -> Board.Hammer
  | _ -> Board.Empty

let of_rows (rows : string list) : Board.board =
  Board.of_array_matrix
    (Array.of_list
       (List.map
          (fun row ->
            Array.of_list (List.map g_of_char (List.of_seq (String.to_seq row))))
          rows))

(* A board with no run anywhere: each row a rotation of the four mana
   elements, so neither axis ever reaches three. *)
let filler () : Board.board =
  let e = [| 'E'; 'F'; 'Y'; 'B' |] in
  of_rows
    (List.init 8 (fun y -> String.init 8 (fun x -> e.((x + y) mod 4))))

let set (x : int) (y : int) (g : Board.gem) (b : Board.board) : Board.board =
  Board.set_gem { Board.x = x; y } g b

let swap (ax, ay) (bx, by) : Board.swap =
  { Board.from_pos = { Board.x = ax; y = ay };
    Board.to_pos = { Board.x = bx; y = by } }

(* ------------------------------------------------------------------ *)
(* The recovered numbers and the port choices                          *)
(* ------------------------------------------------------------------ *)

let () =
  check_int "heroic effort is the recovered cascade depth" Item_game.heroic_depth 5;
  check_int "a board carries four hammers (port choice)"
    Item_game.hammers_per_board 4;
  check_int "band 0 asks 3 points (port choice)"
    (Item_game.target_for_band 0) 3;
  check_int "band 1 asks 5" (Item_game.target_for_band 1) 5;
  check_int "the gifted triple's band asks 5"
    (Item_game.target_for_band (Campaign.forge_band 100)) 5;
  check_int "band 9 fills the 21-icon meter exactly"
    (Item_game.target_for_band 9) 21;
  check_int "and the band clamps past Godlike"
    (Item_game.target_for_band 99) 21;
  ()

(* ------------------------------------------------------------------ *)
(* Opening a game                                                      *)
(* ------------------------------------------------------------------ *)

let () =
  let g = Item_game.create ~rng:seed ~target:5 () in
  check_int "a fresh game carries the hammer budget"
    (Item_game.hammers_on_board g.Item_game.board)
    Item_game.hammers_per_board;
  check "a fresh game is playing" (g.Item_game.status = Item_game.Playing);
  check_int "a fresh game scores nothing" g.Item_game.score 0;
  check_int "the target is the one asked for" g.Item_game.target 5;
  let g1 = Item_game.create ~rng:seed ~target:0 () in
  check_int "a target below 1 clamps up" g1.Item_game.target 1;
  check "a fresh board's hammers never open on a line"
    (Board.find_matches g.Item_game.board
     |> List.for_all (fun (_, gem) -> gem <> Board.Hammer));
  ()

(* ------------------------------------------------------------------ *)
(* Destroying hammers: matching them, and the line that sweeps them    *)
(* ------------------------------------------------------------------ *)

(* Three hammers: two in column 0, the third a swap away at (1,2) - moving
   it to (0,2) completes the column. *)
let hammer_trio () =
  filler ()
  |> set 0 0 Board.Hammer
  |> set 0 1 Board.Hammer
  |> set 1 2 Board.Hammer

let () =
  (* Target 3: three points is the game. *)
  let g = Item_game.of_board ~rng:seed ~target:3 (hammer_trio ()) in
  check "the trio board is playable"
    (Board.is_valid_swap g.Item_game.board { Board.x = 1; y = 2 }
       { Board.x = 0; y = 2 });
  (match Item_game.play g (swap (1, 2) (0, 2)) with
  | None -> check "matching three hammers scores three" false
  | Some g' ->
      check_int "matching three hammers scores three" g'.Item_game.score 3;
      check "and the target ends the game won"
        (g'.Item_game.status = Item_game.Won);
      check_int "a won game leaves the board as the cascade left it"
        (Item_game.hammers_on_board g'.Item_game.board) 0);
  (* Target 5: three points is not enough, so the board resets. *)
  let g = Item_game.of_board ~rng:seed ~target:5 (hammer_trio ()) in
  (match Item_game.play g (swap (1, 2) (0, 2)) with
  | None -> check "a partial score resets the board" false
  | Some g' ->
      check_int "a partial score keeps the points" g'.Item_game.score 3;
      check "and keeps playing" (g'.Item_game.status = Item_game.Playing);
      check_int "the reset deals a fresh hammer budget"
        (Item_game.hammers_on_board g'.Item_game.board)
        Item_game.hammers_per_board);
  ()

(* A four-run of fire in column 0 with a hammer at the column's foot: the
   line rule drags the hammer down with the run even though the hammer is
   nowhere near the match. *)
let () =
  let b =
    filler ()
    |> set 0 0 (Board.Mana Board.Fire)
    |> set 0 1 (Board.Mana Board.Fire)
    |> set 0 2 (Board.Mana Board.Fire)
    |> set 1 0 Board.Skull
    |> set 1 3 (Board.Mana Board.Fire)
    |> set 0 7 Board.Hammer
  in
  let g = Item_game.of_board ~rng:seed ~target:9 b in
  check "the line board is playable"
    (Board.is_valid_swap g.Item_game.board { Board.x = 1; y = 3 }
       { Board.x = 0; y = 3 });
  (match Item_game.play g (swap (1, 3) (0, 3)) with
  | None -> check "a 4-of-a-kind destroys its column, hammer included" false
  | Some g' ->
      check_int "a 4-of-a-kind destroys its column, hammer included"
        g'.Item_game.score 1;
      check_int "the partial score resets the board"
        (Item_game.hammers_on_board g'.Item_game.board)
        Item_game.hammers_per_board);
  ()

(* A five-hammer line: the type sweep takes the sixth hammer on the far
   corner, and the line takes the rest of its column. *)
let () =
  let b =
    filler ()
    |> set 0 0 Board.Hammer
    |> set 0 1 Board.Hammer
    |> set 0 2 Board.Hammer
    |> set 0 3 Board.Hammer
    |> set 1 4 Board.Hammer
    |> set 7 7 Board.Hammer
  in
  let g = Item_game.of_board ~rng:seed ~target:99 b in
  (match Item_game.play g (swap (1, 4) (0, 4)) with
  | None -> check "a 5-of-a-kind sweeps every hammer" false
  | Some g' ->
      (* five in the line + the far-corner sweep = six points; the line's
         own extras are not hammers because the column's foot is filler *)
      check_int "a 5-of-a-kind sweeps every hammer" g'.Item_game.score 6);
  ()

(* ------------------------------------------------------------------ *)
(* Heroic effort, the dead board, and the guards                      *)
(* ------------------------------------------------------------------ *)

let () =
  (* Depth 1 turns every scoring cascade heroic, so one mana match is
     enough to reach the spawn without a five-step board. Two fire gems in
     row 0 with the third one a swap away below: swapping (2,1) up completes
     the run and costs no hammer. *)
  let b =
    filler ()
    |> set 0 0 (Board.Mana Board.Fire)
    |> set 1 0 (Board.Mana Board.Fire)
    |> set 2 1 (Board.Mana Board.Fire)
  in
  let g = Item_game.of_board ~rng:seed ~target:9 b in
  check "the heroic board starts hammerless"
    (Item_game.hammers_on_board g.Item_game.board = 0);
  (match Item_game.play ~depth:1 g (swap (2, 1) (2, 0)) with
  | None -> check "a deep cascade spawns a hammer" false
  | Some g' ->
      check_int "a deep cascade spawns a hammer"
        (Item_game.hammers_on_board g'.Item_game.board) 1;
      check "the spawn keeps the game playing"
        (g'.Item_game.status = Item_game.Playing));
  (* A genuinely dead board: the four elements in stripes that shift two
     per row. A two-colour checkerboard is the obvious wrong answer - a
     single swap turns one column into a three-run - while this pattern has
     no swap that makes three on either axis. *)
  let dead =
    of_rows
      (List.init 8 (fun y ->
           String.init 8 (fun x ->
               match (x + (2 * y)) mod 4 with
               | 0 -> 'E'
               | 1 -> 'F'
               | 2 -> 'Y'
               | _ -> 'B')))
  in
  let g = Item_game.of_board ~rng:seed ~target:9 dead in
  check "a board with no legal move opens lost"
    (g.Item_game.status = Item_game.Lost);
  check "and refuses a swap"
    (Item_game.play g (swap (0, 0) (1, 0)) = None);
  (* Guards: an illegal swap and a finished game both answer None. *)
  let g = Item_game.of_board ~rng:seed ~target:9 (hammer_trio ()) in
  check "a swap that makes no match is refused"
    (Item_game.play g (swap (5, 5) (5, 6)) = None);
  check "a finished game refuses a move"
    (Item_game.play { g with Item_game.status = Item_game.Won }
       (swap (1, 2) (0, 2))
    = None);
  ()

(* ------------------------------------------------------------------ *)
(* The greedy driver terminates                                        *)
(* ------------------------------------------------------------------ *)

let () =
  let g = Item_game.auto_play (Item_game.create ~rng:seed ~target:3 ()) in
  check "auto_play returns (the reset cannot loop it forever)"
    (match g.Item_game.status with
    | Item_game.Playing | Item_game.Won | Item_game.Lost -> true);
  check "a settled game never scores negative" (g.Item_game.score >= 0);
  check "a settled game is not still playing"
    (g.Item_game.status <> Item_game.Playing)

let () =
  if !failures = 0 then print_endline "all item game tests passed"
  else begin
    Printf.printf "%d item game test(s) failed\n" !failures;
    exit 1
  end

