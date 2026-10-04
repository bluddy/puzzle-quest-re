(** An interactive Puzzle Quest battle: you against the recovered AI.

    The port's own runner (bin/pq_battle.ml) plays both sides. This drives the
    same [Battle] with a human on the hero's turns, through the two optional hooks
    in [Battle.player]. Everything after the choice - cost charge, cooldown tick,
    keeps-turn test, effect body, cascade, damage chain - is the recovered code
    path, so what you are fighting here is the engine the decompilation describes.

    Two ways to play a turn, and both are the real thing:

    - cast by number, from the list of spells you can currently afford;
    - swap by typing two adjacent coordinates, e.g. [c3 c4]. The pair is checked
      with the same legality test the AI's move generator uses, so an illegal
      swap is rejected rather than quietly becoming a no-op.

    Casting a spell that ends your turn skips the swap, because in the original a
    spell that consumes the turn means no swap happens that turn either.

    Usage:
      opam exec -- dune exec bin/pq_play.exe -- [--foe SPELL]... [options]

    Options are the same as bin/pq_battle.ml, so a seed reproduces a fight:

      --seed N --turns N --difficulty N --foe-life N --hero-life N
      --spell ID   (repeatable; the foe's roster)
      --list       (print the spell ids you could use and exit)
 *)

open Puzzle_quest_lib

(* ---------------------------------------------------------------- display -- *)

let gem_char = function
  | Board.Skull -> 'S'
  | Board.RedSkull -> 'R'
  | Board.Gold -> 'G'
  | Board.Experience -> 'X'
  | Board.Mana Board.Earth -> 'E'
  | Board.Mana Board.Fire -> 'F'
  | Board.Mana Board.Air -> 'A'
  | Board.Mana Board.Water -> 'W'
  | Board.Wildcard n -> [| '2'; '3'; '4'; '5'; '6'; '7'; '8' |].(n - 2)
  | Board.Empty -> '.'

(** Rows print top-down as 0..7, matching how the board is stored: row 0 is the
    top row. The AI's own coordinates are shifted by one, which is noted in
    [Battle.play_move]; this view is deliberately unshifted. *)
let show_board (b : Board.board) =
  Printf.printf "    ";
  for x = 0 to Board.default_width - 1 do
    Printf.printf "%d" x
  done;
  Printf.printf "\n";
  for y = 0 to Board.default_height - 1 do
    Printf.printf " %d  " y;
    for x = 0 to Board.default_width - 1 do
      Printf.printf "%c" (gem_char (Board.get_gem b { Board.x = x; y }))
    done;
    Printf.printf "\n"
  done

let pool_str (m : Combat.mana) =
  Printf.sprintf "E%-3d F%-3d W%-3d A%-3d" m.Combat.earth m.Combat.fire
    m.Combat.water m.Combat.air

let cost_str (s : Spell.spell) =
  Printf.sprintf "E%-3d F%-3d W%-3d A%-3d" s.Spell.cost_earth s.Spell.cost_fire
    s.Spell.cost_water s.Spell.cost_air

let show_combatant label (c : Combat.combatant) =
  let dead = if c.Combat.is_dead then "  (dead)" else "" in
  Printf.printf "  %-5s life %3d/%-3d  mana %s%s\n" label c.Combat.life
    c.Combat.max_life (pool_str c.Combat.mana) dead;
  let s = c.Combat.skills in
  Printf.printf "        skill E%d F%d W%d A%d  battle %d morale %d cunning %d\n"
    s.Combat.earth s.Combat.fire s.Combat.water s.Combat.air s.Combat.battle
    s.Combat.morale s.Combat.cunning;
  (match c.Combat.effects with
  | [] -> ()
  | effs ->
      Printf.printf "        status: %s\n"
        (String.concat ", "
           (List.map (fun ((id, n) : string * int) -> Printf.sprintf "%s(%d)" id n) effs)))

(* ------------------------------------------------------------------- input -- *)

let bref : Battle.battle option ref = ref None
let current () = match !bref with Some b -> b | None -> failwith "battle not started"

let prompt fmt =
  Printf.ksprintf
    (fun s ->
      Printf.printf "%s" s;
      flush stdout;
      (* A closed stdin (piped input, or a test harness) ends the battle rather
         than looping forever on end-of-file. *)
      try read_line () with End_of_file -> exit 0)
    fmt

(* Quitting has to actually stop the battle loop, not just decline a turn: the
   loop in [Battle.run] is driven by [winner] and the turn cap, so there is no
   way to signal "stop" through the turn hooks themselves. Raising is the honest
   way out, and it is caught around [Battle.run] below. *)
exception Quit

(** Trims an input line.

    The BOM strip is not paranoia: a UTF-8 BOM arriving on stdin - which is what
    PowerShell's pipeline does, among others - would otherwise make the first
    keystroke of a session unrecognisable and the line look like garbage. *)
let clean (s : string) =
  let s = if String.length s >= 3 && String.sub s 0 3 = "\xef\xbb\xbf" then String.sub s 3 (String.length s - 3) else s in
  String.trim s

(** Parses "b3" into (1, 3). Coordinates are column letter a-h then row digit. *)
let parse_coord (s : string) : (int * int) option =
  if String.length s <> 2 then None
  else
    let c = Char.lowercase_ascii s.[0] and r = s.[1] in
    if c >= 'a' && c <= 'h' && r >= '0' && r <= '7' then
      Some ((Char.code c - Char.code 'a'), Char.code r - Char.code '0')
    else None

let swap_list () = Board.find_all_legal_moves (current ()).board

let describe_swap (m : Board.swap) =
  let col x = Char.escaped (Char.chr (Char.code 'a' + x)) in
  Printf.sprintf "%s%d-%s%d" (col m.Board.from_pos.x) m.Board.from_pos.y
    (col m.Board.to_pos.x) m.Board.to_pos.y

(** Prints any battle events produced since the last call, so the feed advances
    live instead of only at the end. [log_of] is newest-last, so the count of
    already-printed events indexes straight into it. *)
let printed = ref 0
let flush_events () =
  let evs = Battle.log_of (current ()) in
  let n = List.length evs in
  if n > !printed then (
    let fresh = List.filteri (fun i _ -> i >= !printed) evs in
    List.iter
      (fun e ->
        let line = Battle.format_event e in
        if line <> "" then Printf.printf "    | %s\n" line)
      fresh;
    printed := n)

let spell_line (i : int) (s : Spell.spell) =
  let turn =
    match s.Spell.turn_cost with
    | Spell.EndsTurn -> "ends turn"
    | Spell.KeepsTurn -> "keeps turn"
    | Spell.EndsTurnAfterEffect -> "ends turn after effect"
    | Spell.KeepsTurnIfMana (e, n) ->
        Printf.sprintf "keeps turn if %s %d+" (Spell.string_of_element e) n
  in
  let cd = if s.Spell.cooldown > 0 then Printf.sprintf " cd%d" s.Spell.cooldown else "" in
  Printf.sprintf "  %2d) %-5s %-22s cost %s  (%s%s)\n" i s.Spell.id
    s.Spell.name (cost_str s) turn cd

(* ------------------------------------------------------------------ player -- *)

let choose_spell (spells : Spell.spell list) : Spell.spell option =
  flush_events ();
  show_board (current ()).Battle.board;
  show_combatant "hero" (current ()).Battle.hero;
  show_combatant "foe" (current ()).Battle.enemy;
  print_newline ();
  let usable = List.filter (Spell.can_cast ~spells_disallowed:false (current ()).Battle.hero) spells in
  if usable <> [] then begin
    print_string "  spells you can cast:\n";
    List.iteri (fun i (s : Spell.spell) -> print_string (spell_line (i + 1) s)) usable
  end
  else print_string "  no spell is affordable right now\n";
  Printf.printf "  %d legal swap%s\n\n" (List.length (swap_list ()))
    (if List.length (swap_list ()) = 1 then "" else "s");
  flush_events ();
  let rec ask () =
    let answer = prompt "  cast [n] | swap [a1 b2] | pass [p] | quit [q] > " in
    let answer = clean answer in
    if answer = "q" || answer = "Q" then raise Quit
    else if answer = "p" || answer = "P" || answer = "" then None
    else if answer = "s" || answer = "S" then None
    else
      match int_of_string_opt answer with
      | None ->
          Printf.printf "  %s is not one of the choices\n" answer;
          ask ()
      | Some n -> (
          match List.nth_opt usable (n - 1) with
          | Some s ->
              flush_events ();
              Some s
          | None ->
              Printf.printf "  no spell numbered %d\n" n;
              ask ())
  in
  ask ()

let choose_swap (legal : Board.swap list) : Board.swap option =
  flush_events ();
  let show_legal () =
    let moves = Board.find_all_legal_moves (current ()).Battle.board in
    Printf.printf "  %d legal swap%s:\n    " (List.length moves)
      (if List.length moves = 1 then "" else "s");
    List.iteri
      (fun i m ->
        if i > 0 then print_string " ";
        print_string (describe_swap m))
      moves;
    print_newline ()
  in
  let rec ask () =
    let answer =
      prompt "  swap two adjacent squares [c3 d3] | list [l] | pass [p] | quit [q] > "
    in
    let answer = clean answer in
    if answer = "q" || answer = "Q" then raise Quit
    else if answer = "p" || answer = "P" || answer = "" then None
    else if answer = "l" || answer = "L" then (
      show_legal ();
      ask ())
    else
      match String.split_on_char ' ' answer with
      | [ a; b ] -> (
          match (parse_coord a, parse_coord b) with
          | Some (x1, y1), Some (x2, y2) ->
              let p1 = { Board.x = x1; y = y1 } and p2 = { Board.x = x2; y = y2 } in
              let adjacent = abs (x1 - x2) + abs (y1 - y2) = 1 in
              if not adjacent then (
                Printf.printf "  %s and %s are not adjacent\n" a b;
                ask ())
              else if not (Board.is_valid_swap (current ()).Battle.board p1 p2) then (
                Printf.printf "  swapping %s and %s makes no match\n" a b;
                ask ())
              else Some { Board.from_pos = p1; Board.to_pos = p2 }
          | _ ->
              Printf.printf "  coordinates look like a1..h7, e.g. [c3 d3]\n";
              ask ())
      | _ ->
          print_string "  give two squares, e.g. [c3 d3]\n";
          ask ()
  in
  ignore legal;
  ask ()

(* -------------------------------------------------------------------- main -- *)

(** A seeded rng with the same contract as [Random.int]: [0 .. n-1].

    Returning [1 .. n] instead would be silently wrong rather than obviously
    broken. [PERCENTILE_CHANCE_SYNC] is 0..99 and the AI hooks compare it against
    thresholds, so an off-by-one shifts every spell's decision; and the extra
    turn tests [roll 100 < gained], which a 1-based roll can never satisfy for
    [gained] = 1. *)
let lcg seed =
  let s = ref (seed land 0x3FFFFFFF) in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

let fresh_board (rng : int -> int) : Board.board =
  let gems =
    [| Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Water;
       Board.Mana Board.Air |]
  in
  Board.of_array_matrix
    (Array.init Board.default_height (fun _ ->
         Array.init Board.default_width (fun _ -> gems.(rng 4))))

(** Seeds a few skulls so the board has something to chew on from turn one,
    matching what a real fight looks like. *)
let seed_skulls (b : Board.board) (rng : int -> int) : Board.board =
  let b = ref b in
  for _ = 1 to 6 do
    let x = rng Board.default_width and y = rng Board.default_height in
    b := Board.set_gem { Board.x = x; y } Board.Skull !b
  done;
  !b

let skill n =
  { Combat.earth = n; fire = n; air = n; water = n; battle = n; morale = n;
    cunning = n }

let usage () =
  print_string
    "pq_play: an interactive Puzzle Quest battle.\n\n\
    \  --seed N         rng seed (repeatable)\n\
    \  --turns N        stalemate cap\n\
    \  --difficulty N0-4  the foe's AI difficulty\n\
    \  --hero-life N / --foe-life N\n\
    \  --hero-mana N    starting mana in every element\n\
    \  --spell ID       give the foe a spell; repeatable\n\
    \  --list           list spell ids and exit\n\n"

let () =
  let seed = ref 7 in
  let max_turns = ref 200 in
  let difficulty = ref 2 in
  let hero_life = ref 60 in
  let foe_life = ref 60 in
  let hero_mana = ref 0 in
  let foe_spells = ref [] in
  let args = Array.to_list Sys.argv in
  let rec parse = function
    | [] -> ()
    | "--seed" :: n :: r ->
        seed := int_of_string n;
        parse r
    | "--turns" :: n :: r ->
        max_turns := int_of_string n;
        parse r
    | "--difficulty" :: n :: r ->
        difficulty := int_of_string n;
        parse r
    | "--hero-life" :: n :: r ->
        hero_life := int_of_string n;
        parse r
    | "--foe-life" :: n :: r ->
        foe_life := int_of_string n;
        parse r
    | "--hero-mana" :: n :: r ->
        hero_mana := int_of_string n;
        parse r
    | "--spell" :: id :: r ->
        foe_spells := id :: !foe_spells;
        parse r
    | "--list" :: r ->
        ignore (parse r);
        List.iter
          (fun (sp : Spell.spell) ->
            Printf.printf "  %-5s %-24s cost E%d F%d W%d A%d  cd%d\n" sp.Spell.id
              sp.Spell.name sp.Spell.cost_earth sp.Spell.cost_fire
              sp.Spell.cost_water sp.Spell.cost_air sp.Spell.cooldown)
          (Spell_data.load_spell_table ());
        exit 0
    | a :: _ ->
        Printf.eprintf "pq_play: unexpected argument %s\n\n" a;
        usage ();
        exit 2
  in
  parse (List.tl args);

  let rng = lcg !seed in
  let roster =
    List.rev_map
      (fun id ->
        match Spell_data.descriptor_of id with
        | Some d -> Some (Spell.spell_of_descriptor d ~name:d.id ())
        | None ->
            Printf.eprintf "pq_play: unknown spell %s\n" id;
            None)
      !foe_spells
    |> List.filter_map (fun x -> x)
  in
  let mana =
    { Combat.earth = !hero_mana; fire = !hero_mana; air = !hero_mana; water = !hero_mana }
  in
  let hero =
    Combat.make_combatant ~cunning:5 ~max_life:!hero_life ~life:!hero_life
      ~mana ~skills:(skill 3) 0 "you"
  in
  let foe =
    Combat.make_combatant ~cunning:3 ~max_life:!foe_life ~life:!foe_life
      ~mana:(if !hero_mana = 0 then Combat.zero_mana else mana)
      ~skills:(skill 3) 1 "foe"
  in
  let rules =
    { Battle.default_rules with
      max_turns = !max_turns;
      difficulty = !difficulty;
      player = Some { choose_spell; choose_swap } }
  in
  let b =
    Battle.create ~rng ~rules ~enemy_spells:roster
      (seed_skulls (fresh_board rng) rng)
      hero foe
  in
  bref := Some b;
  print_string
    "Puzzle Quest - interactive battle. `p` passes your turn, `q` quits.\n\n";
  Printf.printf "seed %d   difficulty %d   cap %d turns\n\n" !seed !difficulty
    !max_turns;
  let quit = ref false in
  let finished =
    try Battle.run b with Quit -> quit := true; b
  in
  print_newline ();
  flush_events ();
  if !quit then begin
    print_string "\n  Quit.\n\n";
    Printf.printf "  turns %d   mana burns %d\n\n" finished.Battle.turns_elapsed
      finished.Battle.mana_burns;
    exit 0
  end;
  (match finished.Battle.winner with
  | Some Battle.HeroVictory -> print_string "\n  You win.\n"
  | Some Battle.EnemyVictory -> print_string "\n  You lose.\n"
  | Some Battle.Draw -> print_string "\n  Mutual destruction.\n"
  | Some Battle.Stalemate ->
      Printf.printf "\n  Stalemate after %d turns.\n" finished.Battle.turns_elapsed
  | None -> print_string "\n  Battle ended with no outcome recorded.\n");
  Printf.printf "  turns %d   mana burns %d   gold %d   xp %d\n\n"
    finished.Battle.turns_elapsed finished.Battle.mana_burns
    finished.Battle.gold finished.Battle.xp