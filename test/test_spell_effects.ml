(* The ported CastSpell bodies.

   These are the effect scripts in lib/spell_effects.ml, tested against boards
   built for the purpose. The point of most of them is which gem kind they read,
   so each assertion builds a board with a known number of one kind and checks
   the consequence: the damage dealt, the gems removed, the gems rewritten, or the
   status applied.

   Expectations come from the Lua in Assets/Spells/*.lua, not from the port. The
   gem ids there are the board's own order (1 Earth, 2 Fire, 3 Water, 4 Air,
   5 Skull, 15 Red Skull), which is the reverse of the character element order for
   the last two; [Spell.gem_of_kind] is the existing translation and these tests
   lean on it rather than restating the mapping.

   Boards are held in a [ref] throughout. That is not incidental: [Board] is an
   immutable value and an effect edits it through the reference in its context, so
   a test that kept a plain copy and inspected that would silently see the
   original board and pass or fail for the wrong reason. *)

open Puzzle_quest_lib
open Board
open Combat

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let caster ?(mana = zero_mana) ?(life = 100) () =
  make_combatant ~mana ~life ~max_life:100 0 "caster"

let foe ?(life = 100) () = make_combatant ~life ~max_life:100 1 "foe"

let fx ~caster ~foe (board : board ref) =
  { Spell.fx_caster = caster
  ; Spell.fx_enemies = [ foe ]
  ; Spell.fx_board = board
  ; Spell.fx_roll = (fun n -> if n <= 0 then 0 else 0 mod n)
  ; Spell.fx_gold = ref 0
  ; Spell.fx_xp = ref 0
  ; Spell.fx_input = None
  ; Spell.fx_items = None
  ; Spell.fx_enemy_items = None
  ; Spell.fx_multipliers = ref true
  }

(** Runs a ported effect by id. Fails loudly rather than silently skipping: a
    typo in an id should stop the suite, not quietly pass. *)
let rec run id ~caster:c ~foe:f (b : board ref) : unit =
  ignore (run_ctx id ~caster:c ~foe:f b)

and run_ctx id ~caster:c ~foe:f (b : board ref) =
  match Spell_effects.effect_of id with
  | None -> failwith ("no ported effect for " ^ id)
  | Some g ->
      let ctx = fx ~caster:c ~foe:f b in
      g ctx;
      ctx

(** A board holding exactly [n] gems of one kind, the rest a kind none of the
    bodies under test reads. Counting runs across the whole board rather than per
    row, which is what [CountGems] does. *)
let board_with (kind : Spell.gem_kind) (n : int) : board =
  let filler = if kind = Spell.GGreen then Mana Fire else Mana Earth in
  let left = ref n in
  Board.of_array_matrix
    (Array.init 8 (fun _ ->
         Array.init 8 (fun _ ->
             if !left > 0 then begin
               decr left;
               Spell.gem_of_kind kind
             end
             else filler)))

(** A board holding two kinds at once, which no single-kind helper can express.
    [na] of kind [a] on row 0 and [nb] of kind [b] on row 1, rest [filler].

    The filler is a parameter rather than fixed because two of the bodies rewrite
    Earth, so a board built with Earth as filler has 64 Earth gems rather than the
    intended handful and every count downstream is wrong. *)
let board_two_kinds ~(filler : gem) ~(a : gem) ~(b : gem) ~(na : int) ~(nb : int) : board =
  let cells = Array.make_matrix 8 8 filler in
  for i = 0 to na - 1 do
    cells.(i).(0) <- a
  done;
  for i = 0 to nb - 1 do
    cells.(i).(1) <- b
  done;
  Board.of_array_matrix cells

let count_of (b : board) (g : gem) : int =
  let n = ref 0 in
  for y = 0 to b.height - 1 do
    for x = 0 to b.width - 1 do
      if equal_gem (get_gem b { x; y }) g then incr n
    done
  done;
  !n

let empties_of (b : board) : int = count_of b Empty

(* ------------------------------------------------------------------ *)
(* Counting gems and dealing damage                                     *)
(* ------------------------------------------------------------------ *)

let () =
  (* SDDI is three plus every Air gem, and does not remove them. Three is the
     floor, so an empty board still deals three. *)
  check "SDDI has a ported body" (Spell_effects.effect_of "SDDI" <> None);
  let c = caster () and f = foe () in
  let b = ref (board_with Spell.GYellow 0) in
  run "SDDI" ~caster:c ~foe:f b;
  check "SDDI deals 3 on an empty board" (f.life = 97);
  let c2 = caster () and f2 = foe () in
  let b2 = ref (board_with Spell.GYellow 5) in
  run "SDDI" ~caster:c2 ~foe:f2 b2;
  check "SDDI deals 3 plus the Air count, so 8" (f2.life = 92);
  check "SDDI leaves the Air gems on the board" (count_of !b2 (Mana Air) = 5)

(* The count-delete-damage shape: deal the count and empty that kind. Air is SCLV,
   Water SFBT, Fire SROF. *)
let count_delete_damage id kind =
  let c = caster () and f = foe () in
  let b = ref (board_with kind 6) in
  run id ~caster:c ~foe:f b;
  (100 - f.life, count_of !b (Spell.gem_of_kind kind))

let () =
  check "SCLV deals 6 and removes every Air gem"
    (count_delete_damage "SCLV" Spell.GYellow = (6, 0));
  check "SFBT deals 6 and removes every Water gem"
    (count_delete_damage "SFBT" Spell.GBlue = (6, 0));
  check "SROF deals 6 and removes every Fire gem"
    (count_delete_damage "SROF" Spell.GRed = (6, 0));
  (* With nothing to count the Lua gates the damage on amt > 0, so zero damage is
     dealt rather than a damage call carrying zero. *)
  let c = caster () and f = foe () in
  run "SROF" ~caster:c ~foe:f (ref (board_with Spell.GRed 0));
  check "SROF deals nothing when there are no Fire gems" (f.life = 100)

let () =
  (* STHX is four plus both kinds of skull. Red skulls are a distinct gem id and
     are counted separately, so they contribute the same as plain skulls here. *)
  let c = caster () and f = foe () in
  run "STHX" ~caster:c ~foe:f (ref (board_with Spell.GSkull 5));
  let plain = 100 - f.life in
  let c2 = caster () and f2 = foe () in
  run "STHX" ~caster:c2 ~foe:f2 (ref (board_with Spell.GRedSkull 5));
  let red = 100 - f2.life in
  check "STHX is 4 plus plain skulls, so 9" (plain = 9);
  check "STHX counts red skulls too, so also 9" (red = 9);
  (* Both kinds together add up, which is what the two CountGems calls are for. *)
  let mixed = ref (board_two_kinds ~filler:(Mana Earth) ~a:Skull ~b:RedSkull ~na:2 ~nb:3) in
  let c3 = caster () and f3 = foe () in
  run "STHX" ~caster:c3 ~foe:f3 mixed;
  check "STHX adds both kinds, so 4 + 2 + 3 = 9" (100 - f3.life = 9)

(* ------------------------------------------------------------------ *)
(* Removing gems                                                         *)
(* ------------------------------------------------------------------ *)

let destroyed id kind =
  let c = caster () and f = foe () in
  let b = ref (board_with kind 9) in
  run id ~caster:c ~foe:f b;
  count_of !b (Spell.gem_of_kind kind)

let () =
  check "SDIV removes every experience gem" (destroyed "SDIV" Spell.GStar = 0);
  check "SEPO removes every Earth gem" (destroyed "SEPO" Spell.GGreen = 0);
  check "SSCV removes every gold gem" (destroyed "SSCV" Spell.GGold = 0);
  check "SWHI removes every Air gem" (destroyed "SWHI" Spell.GYellow = 0);
  (* They are destroyed rather than converted, so the board is left short by
     exactly the number removed. *)
  let c = caster () and f = foe () in
  let b = ref (board_with Spell.GStar 9) in
  run "SDIV" ~caster:c ~foe:f b;
  check "SDIV leaves 9 empty cells rather than refilling them" (empties_of !b = 9)

(* ------------------------------------------------------------------ *)
(* Rewriting gems                                                        *)
(* ------------------------------------------------------------------ *)

let () =
  (* SDRR turns Fire and Air into skulls and touches nothing else. *)
  let c = caster () and f = foe () in
  let b = ref (board_two_kinds ~filler:(Mana Earth) ~a:(Mana Fire) ~b:(Mana Air) ~na:4 ~nb:4) in
  run "SDRR" ~caster:c ~foe:f b;
  check "SDRR leaves no Fire gems" (count_of !b (Mana Fire) = 0);
  check "SDRR leaves no Air gems" (count_of !b (Mana Air) = 0);
  check "SDRR produced 8 skulls" (count_of !b Skull = 8);
  check "SDRR left the 56 Earth gems alone" (count_of !b (Mana Earth) = 56);

  (* SFSK turns Earth into skulls and Water into red skulls, so both kinds of skull
     end up on the board. *)
  let c2 = caster () and f2 = foe () in
  let b2 =
    ref (board_two_kinds ~filler:(Mana Fire) ~a:(Mana Earth) ~b:(Mana Water) ~na:4 ~nb:4)
  in
  run "SFSK" ~caster:c2 ~foe:f2 b2;
  check "SFSK produced 4 plain skulls" (count_of !b2 Skull = 4);
  check "SFSK produced 4 red skulls" (count_of !b2 RedSkull = 4);
  check "SFSK left the 56 Fire gems alone" (count_of !b2 (Mana Fire) = 56)

(* ------------------------------------------------------------------ *)
(* Status effects                                                        *)
(* ------------------------------------------------------------------ *)

let () =
  (* The three self-buffs pass a duration of 0, which has to mean indefinite
     rather than "no effect" - the effects plainly persist in the original. *)
  let empty = board_with Spell.GGreen 0 in
  let c = caster () and f = foe () in
  run "SHID" ~caster:c ~foe:f (ref empty);
  check "SHID applies Hidden to the caster" (has_status c "Hidden");
  let c2 = caster () and f2 = foe () in
  run "SWOF" ~caster:c2 ~foe:f2 (ref empty);
  check "SWOF applies WallOfFired to the caster" (has_status c2 "WallOfFired");
  let c3 = caster () and f3 = foe () in
  run "SWOT" ~caster:c3 ~foe:f3 (ref empty);
  check "SWOT applies WallOfThornsed to the caster" (has_status c3 "WallOfThornsed");
  check "none of the three touched the enemy" (f3.effects = []);

  (* SHOP carries a real duration of six. *)
  let c4 = caster () and f4 = foe () in
  run "SHOP" ~caster:c4 ~foe:f4 (ref empty);
  check "SHOP applies HandOfPowered to the caster" (has_status c4 "HandOfPowered");
  check "SHOP uses the script's duration of 6"
    (List.assoc_opt "HandOfPowered" c4.effects = Some 6);

  (* SFBM is the one debuff, and it lands on the enemy rather than the caster. *)
  let c5 = caster () and f5 = foe () in
  run "SFBM" ~caster:c5 ~foe:f5 (ref empty);
  check "SFBM debuffs the enemy, not the caster" (has_status f5 "FireBombed");
  check "SFBM leaves the caster clean" (c5.effects = [])

(* ------------------------------------------------------------------ *)
(* Healing and the multiplier bracket                                    *)
(* ------------------------------------------------------------------ *)

let () =
  (* SCAU is the only body that heals, and it heals for one point per Fire gem. *)
  let c = caster ~life:50 () and f = foe () in
  run "SCAU" ~caster:c ~foe:f (ref (board_with Spell.GRed 4));
  check "SCAU heals for the Fire count, so 4" (c.life = 54);
  check "SCAU does not touch the enemy" (f.life = 100);

  (* The bracketing bodies restore the flag they turned off, so a spell that
     suppresses bonuses mid-sweep does not leave them off for the rest of the
     battle. *)
  let c2 = caster () and f2 = foe () in
  let b2 = ref (board_with Spell.GRed 3) in
  let ctx = run_ctx "SROF" ~caster:c2 ~foe:f2 b2 in
  check "SROF leaves the multiplier flag on" !(ctx.Spell.fx_multipliers);

  (* A heal cannot exceed max life even when the board is generous. *)
  let c3 = caster ~life:98 () and f3 = foe () in
  run "SCAU" ~caster:c3 ~foe:f3 (ref (board_with Spell.GRed 10));
  check "SCAU does not heal past max life" (c3.life = 100)

let () =
  if !failures = 0 then print_endline "All spell effect tests passed."
  else begin
    Printf.printf "%d spell effect test(s) failed.\n" !failures;
    exit 1
  end
