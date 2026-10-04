(** An interactive battle in a window: the ASCII runner's counterpart.

    The battle logic is the same [Battle] the headless tools drive, and the human
    still chooses through the same two hooks - this only replaces what was a
    [read_line] with a window and a mouse. Nothing about the recovered rules is
    re-implemented here.

    What is deliberately missing: there is no text yet, because SDL2 has no font
    rendering and [tools/graphics_plan.md] defers that to phase 3. The spell bar is
    therefore a row of coloured buttons in a fixed order, and the console prints
    what each one is. That is a placeholder, not a design.

    No CRT filter, no scanlines. See the note in tools/graphics_plan.md. *)

open Puzzle_quest_lib
open Pq_gfx
(* Not [open Tsdl.Sdl]: it has a [Gl] submodule for context attributes, which would
   shadow [Pq_gfx.Gl]. Only the event module is needed unqualified. *)
module E = Tsdl.Sdl.Event

let window_w = 900 and window_h = 680
let cell = 64
let bar_h = 96

(* ------------------------------------------------------------------ battle -- *)

(** A seeded rng with [Random.int]'s contract: 0 .. n-1.

    1-based would shift every AI percentile comparison and make the extra-turn
    roll unsatisfiable, while still producing plausible-looking fights. *)
let lcg seed =
  let s = ref (seed land 0x3FFFFFFF) in
  fun n ->
    s := ((1103515245 * !s) + 12345) land 0x3FFFFFFF;
    !s mod max 1 n

let skill n =
  { Combat.earth = n; fire = n; air = n; water = n; battle = n; morale = n;
    cunning = n }

let spell_of id = Spell_data.descriptor_of id |> Option.map (fun (d : Spell.descriptor) -> Spell.spell_of_descriptor d ~name:d.id ())

let demo_spells = List.filter_map spell_of [ "SBAC"; "SBAV"; "SBNA"; "SBRA" ]

let fresh_board rng =
  let gems =
    [| Board.Mana Board.Earth; Board.Mana Board.Fire; Board.Mana Board.Water;
       Board.Mana Board.Air |]
  in
  Board.of_array_matrix
    (Array.init Board.default_height (fun _ ->
         Array.init Board.default_width (fun _ -> gems.(rng 4))))

(* ------------------------------------------------------------------- state -- *)

type ui = {
  gl : Gl.context;
  mutable b : Battle.battle option;
  (* Fixed: the window is not resizable, so the board geometry never moves. *)
  layout : Layout.t;
  mutable first_cell : (int * int) option;  (** first half of a pending swap *)
}

let u : ui option ref = ref None

let ui () = match !u with Some x -> x | None -> failwith "ui not created"

let battle () = match (ui ()).b with Some b -> b | None -> failwith "no battle"
let layout () = (ui ()).layout

(* ------------------------------------------------------------------- input -- *)

let ev = E.create ()
let some_ev = Some ev

(** Draw the current frame. Every piece of state the player can act on is on
    screen: the board, whose cells they may swap, and the spell bar, whose buttons
    they may press. *)
let bar_geometry () =
  let n = List.length demo_spells in
  let bw = 120 and gap = 12 and bar_y = window_h - bar_h in
  let x0 = (window_w - (n * bw + ((n - 1) * gap))) / 2 in
  (n, bw, gap, bar_y, x0)

let draw () =
  let b = battle () in
  let lay = layout () in
  Gl.begin_frame (ui ()).gl;
  (* Each quad is emitted with the colour that run will be drawn with, so the run
     list and the vertex buffer stay in step. *)
  let runs = ref [] in
  let emit dst col =
    let first = Gl.push_quad (ui ()).gl dst None col in
    runs := !runs @ [ { Gl.first; count = 6; tex = None; colour = col } ]
  in
  let _, _, _, bar_y, x0 = bar_geometry () in
  emit { Layout.x = 0; y = bar_y; w = window_w; h = bar_h } (Layout.rgb 20 22 30);
  for y = 0 to lay.Layout.rows - 1 do
    for x = 0 to lay.Layout.cols - 1 do
      let g = Board.get_gem b.Battle.board { Board.x = x; y } in
      emit (Layout.cell_rect lay x y) (Layout.gem_colour g)
    done
  done;
  (* The pending first half of a swap, inset so it reads as a selection. *)
  (match (ui ()).first_cell with
  | None -> ()
  | Some (x, y) ->
      let r = Layout.cell_rect lay x y in
      emit
        { Layout.x = r.Layout.x + 4; y = r.Layout.y + 4;
          w = r.Layout.w - 8; h = r.Layout.h - 8 }
        (Layout.rgba 255 255 255 80));
  let n, bw, gap, _, _ = bar_geometry () in
  List.iteri
    (fun i (s : Spell.spell) ->
      let affordable = Spell.can_cast b.Battle.hero s in
      emit
        { Layout.x = x0 + (i * (bw + gap)); y = bar_y + 20; w = bw; h = bar_h - 40 }
        (if affordable then Layout.rgb 70 120 200 else Layout.rgb 50 54 66))
    demo_spells;
  ignore n;
  Gl.submit (ui ()).gl !runs;
  Gl.present (ui ()).gl

(** Block until the player clicks. Returns [x, y].

    Quitting is handled here rather than plumbed through: the original also treats
    the window close as the end of the fight. *)
let rec wait_click () =
  draw ();
  if Tsdl.Sdl.poll_event some_ev then begin
    let t = E.get ev E.typ in
    if t = E.quit then exit 0
    else if t = E.mouse_button_down then
      (E.get ev E.mouse_button_x, E.get ev E.mouse_button_y)
    else wait_click ()
  end
  else begin
    Tsdl.Sdl.delay 16l;
    wait_click ()
  end

(* ------------------------------------------------------------------- hooks -- *)

let bar_button_at mx my =
  let n, bw, gap, bar_y, x0 = bar_geometry () in
  if my < bar_y then None
  else
    let i = (mx - x0) / (bw + gap) in
    if i < 0 || i >= n then None
    else if mx - x0 - (i * (bw + gap)) > bw then None
    else Some i

let choose_spell spells : Spell.spell option =
  (* Only affordable, off-cooldown spells are live, so anything offered is a legal
     cast. Spell.is_castable is the engine's own affordability test, the same one
     the AI path uses. *)
  let usable =
    List.filter (Spell.can_cast (battle ()).Battle.hero) spells
  in
  Printf.printf "\n  your turn - spell bar buttons, left to right:\n";
  List.iteri
    (fun i (s : Spell.spell) -> Printf.printf "    %d) %s\n" (i + 1) s.Spell.id)
    usable;
  if usable = [] then
    print_string "    (nothing affordable - click two adjacent gems)\n";
  flush stdout;
  let rec ask () =
    let mx, my = wait_click () in
    match bar_button_at mx my with
    | Some i when i < List.length usable ->
        let s : Spell.spell = List.nth usable i in
        Printf.printf "  cast %s\n" s.Spell.id;
        flush stdout;
        Some s
    | _ -> ask ()
  in
  ask ()

let choose_swap (_legal : Board.swap list) : Board.swap option =
  let lay = layout () in
  Printf.printf "  swap: click a gem, then an adjacent one\n";
  flush stdout;
  (ui ()).first_cell <- None;
  let rec ask () =
    let mx, my = wait_click () in
    match bar_button_at mx my with
    | Some _ ->
        Printf.printf "  (that is the spell bar - press q to quit)\n";
        flush stdout;
        ask ()
    | None -> (
        match Layout.hit lay mx my with
        | None -> ask ()
        | Some (x, y) -> (
            match (ui ()).first_cell with
            | None ->
                (ui ()).first_cell <- Some (x, y);
                ask ()
            | Some (px, py) ->
                let adjacent = abs (px - x) + abs (py - y) = 1 in
                if not adjacent then (
                  Printf.printf "  not adjacent\n";
                  flush stdout;
                  (ui ()).first_cell <- None;
                  ask ())
                else
                  let p1 = { Board.x = px; y = py } and p2 = { Board.x = x; y } in
                  if not (Board.is_valid_swap (battle ()).Battle.board p1 p2) then (
                    Printf.printf "  that swap makes no match\n";
                    flush stdout;
                    (ui ()).first_cell <- None;
                    ask ())
                  else begin
                    (ui ()).first_cell <- None;
                    Printf.printf "  swap (%d,%d)-(%d,%d)\n" px py x y;
                    flush stdout;
                    Some { Board.from_pos = p1; Board.to_pos = p2 }
                  end))
  in
  ask ()

(* -------------------------------------------------------------------- main -- *)

let () =
  let args = Array.to_list Sys.argv in
  let seed = ref 7 and diff = ref 2 in
  let rec parse = function
    | [] -> ()
    | "--seed" :: n :: r ->
        seed := int_of_string n;
        parse r
    | "--difficulty" :: n :: r ->
        diff := int_of_string n;
        parse r
    | _ :: r -> parse r
  in
  parse (List.tl args);
  let rng = lcg !seed in
  let mana =
    { Combat.earth = 14; fire = 14; air = 14; water = 14 }
  in
  let hero =
    Combat.make_combatant ~cunning:5 ~max_life:60 ~life:60 ~mana
      ~skills:(skill 4) 0 "you"
  in
  let foe =
    Combat.make_combatant ~cunning:3 ~max_life:60 ~life:60
      ~skills:(skill 4) 1 "foe"
  in
  let gl = Gl.create ~title:"Puzzle Quest" ~width:window_w ~height:window_h in
  Printf.printf "renderer: %s\n  GL: %s\n" (Gl.renderer_name ()) (Gl.gl_version ());
  flush stdout;
  let lay =
    Layout.create ~cell ~cols:Board.default_width ~rows:Board.default_height
      ~window_w ~window_h
  in
  u := Some { gl; b = None; layout = lay; first_cell = None };
  let rules =
    { Battle.default_rules with
      difficulty = !diff;
      player = Some { Battle.choose_spell; choose_swap } }
  in
  let b =
    Battle.create ~rng ~rules ~hero_spells:demo_spells ~enemy_spells:demo_spells
      (fresh_board rng) hero foe
  in
  (ui ()).b <- Some b;
  Printf.printf "  cell %dpx, board at (%d,%d)\n" cell lay.Layout.origin_x
    lay.Layout.origin_y;
  Printf.printf
    "  hero life %d/%d   click a gem then an adjacent one to swap\n\n"
    hero.Combat.life hero.Combat.max_life;
  flush stdout;
  let finished = Battle.run b in
  draw ();
  print_newline ();
  (match finished.Battle.winner with
  | Some Battle.HeroVictory -> print_string "  You win.\n"
  | Some Battle.EnemyVictory -> print_string "  You lose.\n"
  | Some Battle.Draw -> print_string "  Mutual destruction.\n"
  | Some Battle.Stalemate -> print_string "  Stalemate.\n"
  | None -> print_string "  No outcome recorded.\n");
  Printf.printf "  %d turns, %d mana burns\n" finished.Battle.turns_elapsed
    finished.Battle.mana_burns;
  flush stdout;
  (* Leave the final frame up rather than closing on it. *)
  let rec linger () =
    draw ();
    if Tsdl.Sdl.poll_event some_ev then
      if E.get ev E.typ = E.quit then ()
      else linger ()
    else begin
      Tsdl.Sdl.delay 16l;
      linger ()
    end
  in
  linger ();
  Gl.destroy gl