(** CLI tool for inspecting and manipulating Puzzle Quest saves (.pqhero) *)

open Puzzle_quest_lib

let print_hero_info (save : Save_file.save_file) =
  let h = save.header in
  let hero = save.hero in
  let attrs = hero.attributes in
  let mana = hero.mana in
  Printf.printf "========================================================\n";
  Printf.printf "  PUZZLE QUEST HERO SAVE INSPECTOR (.pqhero)\n";
  Printf.printf "========================================================\n\n";
  Printf.printf "[Header Summary]\n";
  Printf.printf "  App:             %s\n" h.app_name;
  Printf.printf "  Summary:         %s\n" h.hero_summary;
  Printf.printf "  Gold Summary:    %s\n" h.gold_summary;
  Printf.printf "  Record Summary:  %s\n" h.record_summary;
  Printf.printf "  Header Size:     %d bytes\n" h.header_size;
  Printf.printf "  Portrait PNG:    %d bytes\n" h.png_size;
  Printf.printf "  Decrypted CRC:   0x%04x\n" save.decrypted_crc;
  Printf.printf "  Encrypted CRC:   0x%04x\n\n" save.encrypted_crc;

  Printf.printf "[Hero Profile]\n";
  Printf.printf "  Name:            %s\n" hero.name;
  Printf.printf "  Class Code:      %s\n" hero.class_id;
  Printf.printf "  Portrait Path:   %s\n" hero.portrait_path;
  Printf.printf "  Level:           %d\n" hero.level;
  Printf.printf "  Experience (XP): %d\n" hero.xp;
  Printf.printf "  Hit Points (HP): %d / %d\n" hero.cur_life hero.max_life;
  Printf.printf "  Gold Reserves:   %d\n\n" hero.gold;

  Printf.printf "[Core Attributes]\n";
  Printf.printf "  Earth Mastery:   %d\n" attrs.earth;
  Printf.printf "  Fire Mastery:    %d\n" attrs.fire;
  Printf.printf "  Water Mastery:   %d\n" attrs.water;
  Printf.printf "  Air Mastery:     %d\n" attrs.air;
  Printf.printf "  Battle Skill:    %d\n" attrs.battle;
  Printf.printf "  Morale Skill:    %d\n" attrs.morale;
  Printf.printf "  Cunning Skill:   %d\n\n" attrs.cunning;

  Printf.printf "[Mana Reserves]\n";
  Printf.printf "  Air: %-3d  Earth: %-3d  Fire: %-3d  Water: %-3d\n\n"
    mana.air mana.earth mana.fire mana.water;

  Printf.printf "[Spells Inventory (%d total)]\n" (List.length hero.spells);
  List.iter
    (fun (s : Save_file.spell_entry) ->
      let status =
        if s.equipped then "EQUIPPED"
        else if s.learned then "Learned"
        else Printf.sprintf "Locked (Requires Level %d)" s.level_req
      in
      Printf.printf "  - %-4s : %s\n" s.code status)
    hero.spells;
  Printf.printf "\n"

let extract_png (save : Save_file.save_file) (outfile : string) =
  let oc = open_out_bin outfile in
  output_bytes oc save.png_image;
  close_out oc;
  Printf.printf "Extracted %d bytes portrait PNG to %s\n"
    (Bytes.length save.png_image) outfile

let dump_payload (save : Save_file.save_file) (outfile : string) =
  let oc = open_out_bin outfile in
  output_bytes oc save.hero.raw_payload;
  close_out oc;
  Printf.printf "Dumped %d bytes decrypted binary payload to %s\n"
    (Bytes.length save.hero.raw_payload) outfile

let run_board_sim () =
  Printf.printf "========================================================\n";
  Printf.printf "  PUZZLE QUEST MATCH-3 ENGINE SIMULATION\n";
  Printf.printf "========================================================\n\n";
  Random.self_init ();
  let empty_board = Board.create_board [] in
  let b = Board.refill_board empty_board in
  Printf.printf "Initial random board:\n";
  Board.print_board b;
  let b_stable, init_cascades = Board.cascade_step b in
  if init_cascades <> [] then begin
    Printf.printf "\nSettled initial matches (%d cascade rounds). Stable board:\n"
      (List.length init_cascades);
    Board.print_board b_stable
  end;

  let moves = Board.find_all_legal_moves b_stable in
  Printf.printf "\nFound %d legal moves on board:\n" (List.length moves);
  List.iteri
    (fun i (m : Board.swap) ->
      if i < 8 then
        Printf.printf "  [%d] Swap (%d, %d) <-> (%d, %d)\n" i m.from_pos.x
          m.from_pos.y m.to_pos.x m.to_pos.y)
    moves;
  if List.length moves > 8 then
    Printf.printf "  ... and %d more\n" (List.length moves - 8);

  if Board.is_mana_burn b_stable then
    Printf.printf "\nMANA BURN! No moves available! Both players lose all stored mana & board reshuffles.\n"
  else
    match moves with
    | [] -> ()
    | first_move :: _ ->
        Printf.printf "\nExecuting Move: Swap (%d, %d) <-> (%d, %d)\n"
          first_move.from_pos.x first_move.from_pos.y first_move.to_pos.x
          first_move.to_pos.y;
        let b_swapped = Board.swap_gems b_stable first_move.from_pos first_move.to_pos in
        let b_after, cascades = Board.cascade_step b_swapped in
        Printf.printf "Move resolved in %d cascade step(s)!\n" (List.length cascades);
        List.iteri
          (fun idx (res : Board.match_result) ->
            Printf.printf
              "  Cascade #%d: Mana [Air:+%d, Earth:+%d, Fire:+%d, Water:+%d], Gold:+%d, XP:+%d, Damage:%d, ExtraTurn:%b, Wildcards:%d\n"
              (idx + 1) res.air_mana res.earth_mana res.fire_mana res.water_mana
              res.gold res.xp res.damage res.extra_turn
              (List.length res.wildcards_created))
          cascades;
        Printf.printf "\nBoard state after turn:\n";
        Board.print_board b_after

let usage () =
  Printf.eprintf "Usage: pq_save_tool <command> [options] [save_file.pqhero]\n";
  Printf.eprintf "Commands:\n";
  Printf.eprintf "  info <file.pqhero>                    Show hero stats & details\n";
  Printf.eprintf "  extract-png <file.pqhero> -o <out.png> Export embedded 256x256 portrait\n";
  Printf.eprintf "  dump-payload <file.pqhero> -o <out.bin> Export decrypted binary payload\n";
  Printf.eprintf "  board-sim                             Simulate a live match-3 battle board\n";
  exit 1

let () =
  let args = Array.to_list Sys.argv in
  match args with
  | _ :: "board-sim" :: _ -> run_board_sim ()
  | _ :: "info" :: filename :: _ ->
      let save = Save_file.load_save_file filename in
      print_hero_info save
  | _ :: "extract-png" :: filename :: "-o" :: outfile :: _ ->
      let save = Save_file.load_save_file filename in
      extract_png save outfile
  | _ :: "dump-payload" :: filename :: "-o" :: outfile :: _ ->
      let save = Save_file.load_save_file filename in
      dump_payload save outfile
  | _ :: filename :: _ when Filename.check_suffix filename ".pqhero" ->
      let save = Save_file.load_save_file filename in
      print_hero_info save
  | _ -> usage ()
