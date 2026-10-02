(** A headless battle simulator.

    Plays a complete seeded fight and prints the trace, so the rules in
    [Battle] can be watched rather than only asserted. There is no Lua and no
    asset loading: the board is generated, so the same seed always produces the
    same fight. *)

open Puzzle_quest_lib
open Board
open Combat
open Battle

(** A linear congruential generator, so a seed is a seed rather than a snapshot
    of [Random]'s global state. Without this, running two battles in one process
    would give different results for the same number, which makes a printed trace
    impossible to reproduce. *)
let lcg seed =
  let s = ref (seed land 0x3FFFFFFF) in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

let gem_char = function
  | Skull -> 'S'
  | RedSkull -> 'R'
  | Gold -> 'G'
  | Experience -> 'X'
  | Mana Earth -> 'E'
  | Mana Fire -> 'F'
  | Mana Air -> 'A'
  | Mana Water -> 'W'
  | Wildcard _ -> '*'
  | Empty -> '.'

let show_board (b : board) =
  for y = 0 to b.height - 1 do
    print_string "    ";
    for x = 0 to b.width - 1 do
      print_char (gem_char (get_gem b { x; y }))
    done;
    print_newline ()
  done

(** A board with no starting matches, so the fight starts from a legal position
    rather than resolving one the player never made. Four mana elements stepping
    by one per row: horizontally adjacent cells always differ and no swap lines
    up three of a kind. *)
let fresh_board (rng : int -> int) : board =
  let e = [| Mana Fire; Mana Water; Mana Air; Mana Earth |] in
  refill_board ~rng
    (of_array_matrix
       (Array.init 8 (fun y -> Array.init 8 (fun x -> e.((x + y) mod 4)))))

(** A handful of skulls, so a fight actually ends. Enough to matter over 200
    turns without turning the board into one giant run. *)
let seed_skulls (b : board) (rng : int -> int) : board =
  let b = ref b in
  for _ = 1 to 6 do
    let x = rng 8 and y = 3 + rng 5 in
    b := set_gem { x; y } (if rng 4 = 0 then RedSkull else Skull) !b
  done;
  !b

let show_combatant (label : string) (c : combatant) =
  Printf.printf
    "  %-5s %-8s life %3d/%-3d  cunning %-3d  mana E%-3d F%-3d A%-3d W%-3d  skill E%-3d F%-3d A%-3d W%-3d\n"
    label c.name c.life c.max_life c.cunning c.mana.earth c.mana.fire c.mana.air
    c.mana.water c.skills.earth c.skills.fire c.skills.air c.skills.water

let usage () =
  Printf.eprintf "Usage: pq_battle [options]\n";
  Printf.eprintf "\n";
  Printf.eprintf "Plays a seeded headless battle and prints the trace.\n";
  Printf.eprintf "\n";
  Printf.eprintf "Options:\n";
  Printf.eprintf "  --seed N          RNG seed (default 1). Same seed, same fight.\n";
  Printf.eprintf "  --turns N         Turn cap before a stalemate (default 200)\n";
  Printf.eprintf "  --difficulty N    0 easy, 1 normal, 2+ hard (default 1)\n";
  Printf.eprintf "  --hero-life N     Hero life (default 60)\n";
  Printf.eprintf "  --foe-life N      Enemy life (default 60)\n";
  Printf.eprintf "  --hero-skill N    Hero skill in every element (default 0)\n";
  Printf.eprintf "  --foe-skill N     Enemy skill in every element (default 0). Skill drives\n";
  Printf.eprintf "                    mana yield, so a foe at 0 can only ever afford the\n";
  Printf.eprintf "                    cheapest spell and the two choosers look identical.\n";
  Printf.eprintf "  --trace           Print every event (default: summary only)\n";
  Printf.eprintf "  --board           Print the final board\n";
  Printf.eprintf "  --spell-ai P      Spell chooser: faithful (the original's) or ranked\n";
  Printf.eprintf "                    (default: %s)\n" (Spell.string_of_spell_policy (Spell.get_spell_policy ()));
  Printf.eprintf "  --spells N        Give the foe N spells of mixed quality, so the\n";
  Printf.eprintf "                    choosers can be compared (default 0)\n";
  exit 1

(** Spells handed to the foe so the two choosers can be compared.

    Real ids from the game's own table, in the game's own order, which the
    original's first-affordable picker walks. What is missing is the effect
    bodies, so casting one does nothing here; that is enough to compare the
    choosers, which both read only the descriptor, and not enough to say which
    spell is stronger.

    SBAV, SBNA, SBAC and SBRA are the four the extraction flagged as cheapest
    first, and SBAC additionally keeps the turn if the caster has 15+ fire, so
    the roster exercises both turn rules. *)
let demo_spell_ids = [ "SBAV"; "SBNA"; "SBAC"; "SBRA" ]

let demo_spells =
  List.filter_map
    (fun id -> Spell_data.descriptor_of id)
    demo_spell_ids
  |> List.map (fun (d : Spell.descriptor) -> Spell.spell_of_descriptor d ~name:d.id ())
  |> List.map (fun (s : Spell.spell) -> s)

let () =
  let seed = ref 1 in
  let max_turns = ref 200 in
  let difficulty = ref 1 in
  let hero_life = ref 60 in
  let foe_life = ref 60 in
  let hero_skill = ref 0 in
  let foe_skill = ref 0 in
  let trace = ref false in
  let show_final = ref false in
  let spell_count = ref 0 in
  let args = Array.to_list Sys.argv in
  let rec parse = function
    | [] -> ()
    | "--seed" :: n :: rest ->
        seed := int_of_string n;
        parse rest
    | "--turns" :: n :: rest ->
        max_turns := int_of_string n;
        parse rest
    | "--difficulty" :: n :: rest ->
        difficulty := int_of_string n;
        parse rest
    | "--hero-life" :: n :: rest ->
        hero_life := int_of_string n;
        parse rest
    | "--foe-life" :: n :: rest ->
        foe_life := int_of_string n;
        parse rest
    | "--hero-skill" :: n :: rest ->
        hero_skill := int_of_string n;
        parse rest
    | "--foe-skill" :: n :: rest ->
        foe_skill := int_of_string n;
        parse rest
    | "--trace" :: rest ->
        trace := true;
        parse rest
    | "--board" :: rest ->
        show_final := true;
        parse rest
    | "--spell-ai" :: p :: rest ->
        (match p with
        | "faithful" -> Spell.set_spell_policy Spell.Faithful
        | "ranked" -> Spell.set_spell_policy Spell.Ranked
        | _ ->
            Printf.eprintf "pq_battle: --spell-ai must be 'faithful' or 'ranked'\n\n";
            usage ());
        parse rest
    | "--spells" :: n :: rest ->
        spell_count := int_of_string n;
        parse rest
    | a :: _ ->
        Printf.eprintf "pq_battle: unexpected argument %s\n\n" a;
        usage ()
  in
  parse (List.tl args);
  let rng = lcg !seed in
  let skill n = { earth = n; fire = n; air = n; water = n } in
  let hero =
    make_combatant ~cunning:5 ~max_life:!hero_life ~life:!hero_life
      ~skills:(skill !hero_skill) 0 "hero"
  in
  let foe =
    make_combatant ~cunning:3 ~max_life:!foe_life ~life:!foe_life
      ~skills:(skill !foe_skill) 1 "foe"
  in
  (* The demo roster is built in increasing quality, so the faithful chooser
     locks onto the first entry and never uses the rest, while the ranked one
     climbs as mana allows. That contrast is the point of the flag. *)
  let foe_spells =
    let n = min !spell_count (List.length demo_spells) in
    let rec take acc = function
      | _ when List.length acc >= n -> List.rev acc
      | [] -> List.rev acc
      | s :: rest -> take (s :: acc) rest
    in
    take [] demo_spells
  in
  let rules =
    { default_rules with max_turns = !max_turns; difficulty = !difficulty }
  in
  let b =
    create ~rng ~rules ~enemy_spells:foe_spells
      (seed_skulls (fresh_board rng) rng) hero foe
  in
  Printf.printf "seed %d  difficulty %d  cap %d turns  spell-ai %s\n\n" !seed !difficulty
    !max_turns (Spell.string_of_spell_policy (Spell.get_spell_policy ()));
  show_combatant "hero" hero;
  show_combatant "foe" foe;
  print_newline ();
  let done_b = run b in
  if !trace then begin
    print_endline "---- trace ----";
    List.iter (fun e -> print_endline (format_event e)) (log_of done_b);
    print_newline ()
  end;
  let events = log_of done_b in
  let count pred = List.length (List.filter pred events) in
  let damage_total who =
    List.fold_left
      (fun acc -> function Damage (n, amount) when n = who -> acc + amount | _ -> acc)
      0 events
  in
  let turns_of side =
    count (function TurnStart (_, s, _) -> s = side | _ -> false)
  in
  Printf.printf "---- summary ----\n";
  Printf.printf "  result        %s\n"
    (match done_b.winner with Some o -> format_event (BattleEnd o) | None -> "unfinished");
  Printf.printf "  turns         %d of %d\n" done_b.turns_elapsed !max_turns;
  Printf.printf "  hero turns    %d   foe turns %d\n" (turns_of Hero) (turns_of Enemy);
  Printf.printf "  damage dealt  hero %d, foe %d\n" (damage_total "foe") (damage_total "hero");
  Printf.printf "  mana burns    %d\n" done_b.mana_burns;
  Printf.printf "  banked turns  %d stat, %d size\n"
    (count (function BankedTurn _ -> true | _ -> false))
    (count (function SizeTurn _ -> true | _ -> false));
  Printf.printf "  gold %d  xp %d" done_b.gold done_b.xp;
  if foe_spells <> [] then begin
    let casts =
      List.filter_map
        (function SpellCast (_, id) -> Some id | _ -> None) events
    in
    print_newline ();
    List.iter
      (fun (s : Spell.spell) ->
        let n = List.length (List.filter (fun i -> i = s.Spell.id) casts) in
        Printf.printf "  %-6s cost %-3d  %-22s cast %d\n" s.Spell.id
          (Spell.total_cost s) (Spell.string_of_turn_cost s.Spell.turn_cost) n)
      foe_spells
  end;
  (match done_b.winner with
  | Some Draw -> print_endline "  (mutual destruction)"
  | _ -> ());
  print_newline ();
  show_combatant "hero" done_b.hero;
  show_combatant "foe" done_b.enemy;
  if !show_final then begin
    print_newline ();
    show_board done_b.board
  end
