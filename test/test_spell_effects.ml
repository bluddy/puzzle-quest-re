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

let foe ?(mana = zero_mana) ?(life = 100) () = make_combatant ~mana ~life ~max_life:100 1 "foe"

let fx ?(spell = None) ?(percentile = 0) ?(input = None) ?(roll = fun n -> if n <= 0 then 0 else 0 mod n) ~caster ~foe (board : board ref) =
  { Spell.fx_caster = caster
  ; Spell.fx_enemies = [ foe ]
  ; Spell.fx_board = board
  ; Spell.fx_roll = roll
  ; Spell.fx_gold = ref 0
  ; Spell.fx_xp = ref 0
  ; Spell.fx_input = input
  ; Spell.fx_items = None
  ; Spell.fx_enemy_items = None
  ; Spell.fx_flags = Spell.default_multiplier_flags
  ; Spell.fx_spell = spell
  ; Spell.fx_percentile = percentile
  }

(** Runs a ported effect by id. Fails loudly rather than silently skipping: a
    typo in an id should stop the suite, not quietly pass.

    [?spell] supplies the descriptor for the bodies that charge themselves, since
    [HANDLE_SPELL_COST] reads the caster's own costs off it. *)
let rec run ?(spell = None) id ~caster:c ~foe:f (b : board ref) : unit =
  ignore (run_ctx ~spell id ~caster:c ~foe:f b)

and run_ctx ?(spell = None) id ~caster:c ~foe:f (b : board ref) =
  match Spell_effects.effect_of id with
  | None -> failwith ("no ported effect for " ^ id)
  | Some g ->
      let ctx = fx ~spell ~caster:c ~foe:f b in
      g ctx;
      ctx

(** A spell with the given costs, for the self-charging bodies. The values match
    SBSG's descriptor in [lib/spell_data.ml]: 4 Earth and 4 Air, nothing else. *)
let spell_costing ~earth ~fire ~air ~water id =
  Spell.make_spell ~cost_earth:earth ~cost_fire:fire ~cost_air:air ~cost_water:water
    id id

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
  check "SROF leaves the multiplier flag on" (ctx.Spell.fx_flags.wildcard_chance && ctx.Spell.fx_flags.extra_turn_chance && ctx.Spell.fx_flags.damage_multiplier);

  (* A heal cannot exceed max life even when the board is generous. *)
  let c3 = caster ~life:98 () and f3 = foe () in
  run "SCAU" ~caster:c3 ~foe:f3 (ref (board_with Spell.GRed 10));
  check "SCAU does not heal past max life" (c3.life = 100)
(* HANDLE_SPELL_COST: the spells that pay for themselves *)

let () =
  (* SBSG costs 4 Earth and 4 Air. The effect charges exactly that, so the pools
     drop by the cost and [cost_charged] goes true, which is what stops
     [Battle.take_action] charging the caster a second time. *)
  let s = spell_costing ~earth:4 ~fire:0 ~air:4 ~water:0 "SBSG" in
  let c = caster ~mana:{ Combat.earth = 10; fire = 0; air = 10; water = 0 } () in
  let f = foe () in
  let b = ref (board_with Spell.GGreen 0) in
  run ~spell:(Some s) "SBSG" ~caster:c ~foe:f b;
  check "SBSG charges its own 4 Earth" (Combat.mana c Combat.Earth = 6);
  check "and its own 4 Air" (Combat.mana c Combat.Air = 6);
  check "and leaves Fire and Water alone"
    (Combat.mana c Combat.Fire = 0 && Combat.mana c Combat.Water = 0);
  check "and marks the spell charged" s.cost_charged;

  (* The subtraction floors at zero rather than going into debt, which is the
     recovered behaviour of the u & ((int)u < 1) - 1 idiom at 0x40d080. *)
  let s2 = spell_costing ~earth:30 ~fire:0 ~air:0 ~water:0 "X" in
  let c2 = caster ~mana:{ Combat.earth = 5; fire = 0; air = 0; water = 0 } () in
  let ctx = fx ~spell:(Some s2) ~caster:c2 ~foe:(foe ()) (ref (board_with Spell.GGreen 0)) in
  Spell_effects.handle_spell_cost ctx;
  check "a pool smaller than the cost floors at zero, not negative"
    (Combat.mana c2 Combat.Earth = 0);

  (* Without a descriptor there is nothing to charge, which is the case a bare
     effect context in a test is in. *)
  let c3 = caster ~mana:{ Combat.earth = 9; fire = 0; air = 0; water = 0 } () in
  let ctx3 = fx ~caster:c3 ~foe:(foe ()) (ref (board_with Spell.GGreen 0)) in
  Spell_effects.handle_spell_cost ctx3;
  check "with no spell in context nothing is charged" (Combat.mana c3 Combat.Earth = 9)

(* The self-charging bodies each bracket their sweep, so the flag is back on when
   they finish. Leaving it off would suppress bonuses for the rest of the fight. *)
let () =
  let check_bracket id =
    let s = spell_costing ~earth:4 ~fire:0 ~air:4 ~water:0 id in
    let c = caster ~mana:{ Combat.earth = 10; fire = 0; air = 10; water = 0 } () in
    let ctx = run_ctx ~spell:(Some s) id ~caster:c ~foe:(foe ()) (ref (board_with Spell.GGreen 4)) in
    (s.cost_charged, ctx.Spell.fx_flags.wildcard_chance, ctx.Spell.fx_flags.extra_turn_chance)
  in
  let charged, wild, turn = check_bracket "SIST" in
  check "SIST charges itself" charged;
  check "SIST restores the wildcard flag" wild;
  check "SIST restores the extra-turn flag" turn

(* SIST explodes every Earth gem, and an explosion is a 3x3 sweep, so a cluster of
   Earth gems takes their neighbours with it. *)
let () =
  let s = spell_costing ~earth:30 ~fire:0 ~air:0 ~water:0 "SIST" in
  let c = caster ~mana:{ Combat.earth = 40; fire = 0; air = 0; water = 0 } () in
  let f = foe () in
  let cells = Array.make_matrix 8 8 (Mana Fire) in
  (* a 2x2 block of Earth, so the 3x3 sweeps overlap *)
  for i = 0 to 1 do
    cells.(i).(0) <- Mana Earth;
    cells.(i).(1) <- Mana Earth
  done;
  let b = ref (Board.of_array_matrix cells) in
  run ~spell:(Some s) "SIST" ~caster:c ~foe:f b;
  check "SIST removes the Earth gems it exploded" (count_of !b (Mana Earth) = 0);
  (* Four overlapping 3x3 sweeps centred on a 2x2 block of Earth cover exactly the
     3x3 region around that block, so five of the surrounding Fire go with the four
     Earth - not eight, because the sweeps overlap rather than tile. The board
     started with 60 Fire, so 55 remain. *)
  check "SIST also removes the Fire gems caught in the blast"
    (count_of !b (Mana Fire) = 55);
  check "SIST charged the 30 Earth" (Combat.mana c Combat.Earth = 10)

(* SHGO pays out according to the gem it took, and the amounts are not symmetric:
   a red skull is worth five times a plain one. The random cell comes from
   fx_roll, pinned to 0 here so SHGO always takes the top-left cell. *)
let take gem =
  let s = spell_costing ~earth:0 ~fire:0 ~air:0 ~water:0 "SHGO" in
  let c = caster () in
  let f = foe () in
  let cells = Array.make_matrix 8 8 (Mana Earth) in
  cells.(0).(0) <- gem;
  let b = ref (Board.of_array_matrix cells) in
  let ctx = fx ~spell:(Some s) ~roll:(fun _ -> 0) ~caster:c ~foe:f b in
  Spell_effects.effect_shgo ctx;
  (c, f, b)

let () =
  let c1, _, b1 = take (Mana Air) in
  check "SHGO pays 20 Air for an Air gem" (Combat.mana c1 Combat.Air = 20);
  check "SHGO empties the cell it took" (count_of !b1 (Mana Air) = 0);
  let _, f3, _ = take RedSkull in
  check "SHGO deals 100 to a red skull, five times the flat 20" (f3.life = 0);
  let _, f4, _ = take Skull in
  check "SHGO deals 20 to a plain skull" (f4.life = 80)


(* ------------------------------------------------------------------ *)
(* ------------------------------------------------------------------ *)

(* ------------------------------------------------------------------ *)
(* The mana and skill group                                             *)
(* ------------------------------------------------------------------ *)


let () =
  (* Shape 1: the pool becomes damage and is then emptied. SBRF reads Fire, so a
     caster with 20 Fire hits for 20 and is left at zero. *)
  let c = caster ~mana:{ Combat.earth = 0; fire = 20; air = 0; water = 0 } () in
  let f = foe () in
  run "SBRF" ~caster:c ~foe:f (ref (board_with Spell.GGreen 0));
  check "SBRF deals the caster's Fire pool" (f.life = 80);
  check "SBRF then drains that pool" (Combat.mana c Combat.Fire = 0);

  (* The damage is read before the drain, so it is the full pool and not zero. *)
  let c2 = caster ~mana:{ Combat.earth = 15; fire = 0; air = 0; water = 0 } () in
  let f2 = foe () in
  run "SSOB" ~caster:c2 ~foe:f2 (ref (board_with Spell.GGreen 0));
  check "SSOB reads Earth, not Fire, and deals the full pool" (f2.life = 85);

  (* SBRP is the Air body plus Disease on the enemy. Note it is "EDIS" in the Lua,
     i.e. Disease - SBRZ is the one that poisons, with "EPOI". Getting these two
     the wrong way round is easy since they are otherwise the same body. *)
  let c3 = caster ~mana:{ Combat.earth = 0; fire = 0; air = 10; water = 0 } () in
  let f3 = foe () in
  run "SBRP" ~caster:c3 ~foe:f3 (ref (board_with Spell.GGreen 0));
  check "SBRP deals the Air pool" (f3.life = 90);
  check "SBRP diseases the enemy, since EDIS is Disease" (has_status f3 "Disease");
  check "SBRP does not poison" (not (has_status f3 "Poison"));
  check "SBRP does not touch the caster" (c3.effects = []);

  (* SBRZ is the Earth body and it is the one that poisons. *)
  let c4 = caster ~mana:{ Combat.earth = 10; fire = 0; air = 0; water = 0 } () in
  let f4 = foe () in
  run "SBRZ" ~caster:c4 ~foe:f4 (ref (board_with Spell.GGreen 0));
  check "SBRZ deals the Earth pool" (f4.life = 90);
  check "SBRZ poisons the enemy, since EPOI is Poison" (has_status f4 "Poison");

  (* Shape 2: a flat five and an extra turn. *)
  let c4 = caster ~mana:{ Combat.earth = 0; fire = 0; air = 3; water = 0 } () in
  run "SCHA" ~caster:c4 ~foe:(foe ()) (ref (board_with Spell.GGreen 0));
  check "SCHA banks five Air on top of the three it had" (Combat.mana c4 Combat.Air = 8);
  check "SCHA takes an extra turn" (c4.extra_turns = 1);
  check "SCHA respects the ceiling" (Combat.mana c4 Combat.Air <= Combat.max_mana c4 Combat.Air)

let () =
  (* Shape 3: count the gems, destroy them, bank the count as skill. SBNA is Air,
     so a board of six yellow gems is six Air skill and no yellow left. *)
  let c = caster () in
  let b = ref (board_with Spell.GYellow 6) in
  run "SBNA" ~caster:c ~foe:(foe ()) b;
  check "SBNA destroys the Air gems" (count_of !b (Mana Air) = 0);
  check "SBNA banks six Air skill" (Combat.skill_in SAir c.skills = 6);
  check "SBNA leaves the other skills alone"
    (Combat.skill_in SEarth c.skills = 0 && Combat.skill_in SBattle c.skills = 0)

let () =
  (* SBAV empties Earth into Battle skill, draining first so the number cannot be
     counted twice. *)
  let c = caster ~mana:{ Combat.earth = 12; fire = 0; air = 0; water = 0 } () in
  run "SBAV" ~caster:c ~foe:(foe ()) (ref (board_with Spell.GGreen 0));
  check "SBAV banks twelve Battle skill" (Combat.skill_in SBattle c.skills = 12);
  check "SBAV empties the Earth pool" (Combat.mana c Combat.Earth = 0);

  (* SESK takes both skull kinds. *)
  let c2 = caster () in
  let b2 = ref (board_two_kinds ~filler:(Mana Fire) ~a:Skull ~b:RedSkull ~na:2 ~nb:3) in
  run "SESK" ~caster:c2 ~foe:(foe ()) b2;
  check "SESK banks five Battle skill from both skull kinds"
    (Combat.skill_in SBattle c2.skills = 5);
  check "SESK removes both skull kinds"
    (count_of !b2 Skull = 0 && count_of !b2 RedSkull = 0);

  (* SREV doubles existing Battle skill, and is a no-op at zero. *)
  let c3 = caster () in
  run "SREV" ~caster:c3 ~foe:(foe ()) (ref (board_with Spell.GGreen 0));
  check "SREV at zero Battle skill adds nothing" (Combat.skill_in SBattle c3.skills = 0);

  (* SFLV picks a skill by index, and the index follows the engine's order rather
     than the constructor order: 5 is Cunning, not Morale. *)
  let c4 = caster ~mana:{ Combat.earth = 0; fire = 9; air = 0; water = 0 } () in
  let b4 = ref (board_with Spell.GGreen 0) in
  let ctx = fx ~roll:(fun n -> if n >= 7 then 5 else 0) ~caster:c4 ~foe:(foe ()) b4 in
  Spell_effects.effect_sflv ctx;
  check "SFLV draining to index 5 lands on Cunning"
    (Combat.skill_in SCunning c4.skills = 9);
  check "SFLV empties the Fire pool" (Combat.mana c4 Combat.Fire = 0);
  check "SFLV put nothing in Morale" (Combat.skill_in SMorale c4.skills = 0)

let () =
  (* Shape 5: taking the enemy's mana. SFSP heals for exactly what it took. *)
  let e = foe ~mana:{ Combat.earth = 0; fire = 17; air = 0; water = 0 } () in
  let c = caster ~life:50 () in
  run "SFSP" ~caster:c ~foe:e (ref (board_with Spell.GGreen 0));
  check "SFSP heals the caster for the Fire it took" (c.life = 67);
  check "SFSP empties the enemy Fire pool" (Combat.mana e Combat.Fire = 0);

  (* SSWA reads the enemy's Earth without draining it. *)
  let e2 = foe ~mana:{ Combat.earth = 8; fire = 0; air = 0; water = 0 } () in
  ignore (foe ());  run "SSWA" ~caster:c ~foe:e2 (ref (board_with Spell.GGreen 0));
  check "SSWA deals four plus the enemy Earth pool, so 12" (e2.life = 88);
  check "SSWA does not drain it" (Combat.mana e2 Combat.Earth = 8);

  (* SBST takes an extra turn only when the enemy had 10 or more Earth, and that
     test runs before the drain. *)
  let e3 = foe ~mana:{ Combat.earth = 10; fire = 0; air = 0; water = 0 } () in
  let c3 = caster () in
  run "SBST" ~caster:c3 ~foe:e3 (ref (board_with Spell.GGreen 0));
  check "SBST at exactly 10 takes an extra turn" (c3.extra_turns = 1);
  check "SBST empties the enemy Earth pool" (Combat.mana e3 Combat.Earth = 0);
  let e4 = foe ~mana:{ Combat.earth = 9; fire = 0; air = 0; water = 0 } () in
  let c4 = caster () in
  run "SBST" ~caster:c4 ~foe:e4 (ref (board_with Spell.GGreen 0));
  check "SBST at 9 takes no extra turn" (c4.extra_turns = 0);

  (* SCTO takes a flat three from each of the four pools and banks five Earth. *)
  let e5 = foe ~mana:{ Combat.earth = 10; fire = 10; air = 10; water = 10 } () in
  let c5 = caster () in
  run "SCTO" ~caster:c5 ~foe:e5 (ref (board_with Spell.GGreen 0));
  check "SCTO takes three from each enemy pool"
    (Combat.mana e5 Combat.Earth = 7 && Combat.mana e5 Combat.Fire = 7
    && Combat.mana e5 Combat.Air = 7 && Combat.mana e5 Combat.Water = 7);
  check "SCTO banks five Earth" (Combat.mana c5 Combat.Earth = 5);
  (* A drain larger than the pool floors at zero rather than going negative. *)
  let e6 = foe ~mana:{ Combat.earth = 1; fire = 0; air = 0; water = 0 } () in
  run "SCTO" ~caster:(caster ()) ~foe:e6 (ref (board_with Spell.GGreen 0));
  check "SCTO floors a small pool at zero" (Combat.mana e6 Combat.Earth = 0);

  (* SSHO doubles the enemy's Earth and halves its other three. Odd pools lose the
     remainder, because Lua's division truncates. *)
  let e7 = foe ~mana:{ Combat.earth = 10; fire = 9; air = 7; water = 5 } () in
  run "SSHO" ~caster:(caster ()) ~foe:e7 (ref (board_with Spell.GGreen 0));
  check "SSHO doubles the enemy Earth pool" (Combat.mana e7 Combat.Earth = 20);
  check "SSHO halves Fire, truncating 9 to 4" (Combat.mana e7 Combat.Fire = 5);
  check "SSHO halves Air, truncating 7 to 3" (Combat.mana e7 Combat.Air = 4);
  check "SSHO halves Water, truncating 5 to 2" (Combat.mana e7 Combat.Water = 3)

let () =
  (* SSBM doubles the caster's Water pool, but not past the ceiling. The Lua adds the caster's 'current' Water to itself, and only trims the amount when twice it would overshoot - so the pool doubles when there is room and tops out when there is not. *)
  let run_ssbm water =
    let c = caster ~mana:{ Combat.earth = 0; fire = 0; air = 0; water = water } () in
    let e = foe ~mana:{ Combat.earth = 0; fire = 0; air = 10; water = 0 } () in
    run "SSBM" ~caster:c ~foe:e (ref (board_with Spell.GGreen 0));
    (Combat.mana c Combat.Water, Combat.mana e Combat.Air, Combat.max_mana c Combat.Water)
  in
  (* 4 doubles to 8: there is room, so it adds the whole pool. *)
  check "SSBM doubles Water when there is headroom" (let w, _, _ = run_ssbm 4 in w = 8);
  (* 15 would double to 30, past a ceiling of 20, so it adds only the shortfall. *)
  check "SSBM tops Water out at the ceiling when doubling would overshoot"
    (let w, _, m = run_ssbm 15 in w = m && m = 20);
  (* The enemy half is independent of that. *)
  check "SSBM takes half the enemy Air pool, truncating 10 to 5"
    (let _, a, _ = run_ssbm 4 in a = 5)

let () =
  (* Shape 6: the scaled status durations truncate, and the floor is load-bearing.
     SFAV is 8 + Air/6, so five Air adds nothing and six adds one. *)
  let dur_for air =
    let c = caster ~mana:{ Combat.earth = 0; fire = 0; air = air; water = 0 } () in
    let b = ref (board_with Spell.GGreen 0) in
    run "SFAV" ~caster:c ~foe:(foe ()) b;
    List.assoc "Favoreded" c.effects
  in
  check "SFAV at 5 Air is the bare 8, since 5/6 truncates to 0" (dur_for 5 = 8);
  check "SFAV at 6 Air is 9" (dur_for 6 = 9);
  check "SFAV at 12 Air is 10" (dur_for 12 = 10);
  (* The status lands on the caster for SFAV. *)
  let c = caster ~mana:{ Combat.earth = 0; fire = 0; air = 6; water = 0 } () in
  run "SFAV" ~caster:c ~foe:(foe ()) (ref (board_with Spell.GGreen 0));
  check "SFAV buffs the caster" (has_status c "Favoreded");
  (* SHWL is the same shape but debuffs the enemy, and banks four Earth first. *)
  let c2 = caster () in
  let e2 = foe () in
  run "SHWL" ~caster:c2 ~foe:e2 (ref (board_with Spell.GGreen 0));
  check "SHWL fears the enemy, not the caster" (has_status e2 "Fear");
  check "SHWL does not fear the caster" (not (has_status c2 "Fear"));
  check "SHWL banks four Earth" (Combat.mana c2 Combat.Earth = 4)

let () =
  (* SVAM trims an overkill hit down to the enemy's remaining life, and heals for
     exactly what it dealt - which is the whole point of the cap. *)
  let c = caster ~mana:{ Combat.earth = 0; fire = 0; air = 0; water = 0 } ~life:50 () in
  let e = foe ~life:3 () in
  run "SVAM" ~caster:c ~foe:e (ref (board_with Spell.GGreen 0));
  check "SVAM caps the hit at the enemy's remaining life" (e.life = 0);
  check "SVAM heals for the capped amount, so 3" (c.life = 53)

let () =
  (* SLCO raises the ceiling rather than filling the pool, so the gain is
     permanent. It also takes an extra turn. *)
  let c = caster () in
  let before = Combat.max_mana c Combat.Fire in
  run "SLCO" ~caster:c ~foe:(foe ()) (ref (board_with Spell.GGreen 0));
  check "SLCO raises the Fire ceiling by twelve"
    (Combat.max_mana c Combat.Fire = before + 12);
  check "SLCO takes an extra turn" (c.extra_turns = 1);

  (* SEGZ heals then empties all four pools. *)
  let c2 = caster ~mana:{ Combat.earth = 5; fire = 5; air = 5; water = 5 } ~life:50 () in
  run "SEGZ" ~caster:c2 ~foe:(foe ()) (ref (board_with Spell.GGreen 0));
  check "SEGZ heals 25" (c2.life = 75);
  check "SEGZ empties all four pools"
    (Combat.mana c2 Combat.Earth = 0 && Combat.mana c2 Combat.Fire = 0
    && Combat.mana c2 Combat.Air = 0 && Combat.mana c2 Combat.Water = 0);

  (* STAU picks the drained element from the turn's percentile, in four inclusive
     bands, and the bands must not leave a gap at the boundaries. *)
  (* STAU picks the drained element from the turn's percentile, in four bands that
     are inclusive at both ends, and the bands must not leave a gap. Which element
     lost mana is the whole observable effect, so that is what is returned. *)
  let drained_at p =
    let c = caster ~mana:{ Combat.earth = 0; fire = 0; air = 100; water = 0 } () in
    let e = foe ~mana:{ Combat.earth = 10; fire = 10; air = 10; water = 10 } () in
    Spell_effects.effect_stau (fx ~percentile:p ~caster:c ~foe:e (ref (board_with Spell.GGreen 0)));
    (* The damage is 8 + Air/10, and 100/10 is 10, so 18 leaves each pool at either
       10 (untouched) or 10 - 18 floored to 0. Only the chosen pool is drained. *)
    List.find_opt (fun el -> Combat.mana e el = 0)
      [ Combat.Earth; Combat.Fire; Combat.Air; Combat.Water ]
  in
  check "STAU at percentile 0 drains Earth" (drained_at 0 = Some Combat.Earth);
  check "STAU at 25 is still the first band, being inclusive"
    (drained_at 25 = Some Combat.Earth);
  check "STAU at 26 moves to Fire" (drained_at 26 = Some Combat.Fire);
  check "STAU at 50 is still Fire" (drained_at 50 = Some Combat.Fire);
  check "STAU at 51 moves to Air" (drained_at 51 = Some Combat.Air);
  check "STAU at 75 is still Air" (drained_at 75 = Some Combat.Air);
  check "STAU at 76 moves to Water" (drained_at 76 = Some Combat.Water);
  check "STAU at 99 stays on Water" (drained_at 99 = Some Combat.Water)

let () =
  (* SFRZ rewrites Fire as Water and credits the count, so the board keeps its gem
     count and the caster gains the difference in yield. *)
  let c = caster () in
  let b = ref (board_with Spell.GRed 7) in
  run "SFRZ" ~caster:c ~foe:(foe ()) b;
  check "SFRZ rewrites every Fire gem as Water" (count_of !b (Mana Fire) = 0);
  check "SFRZ banks seven Water" (Combat.mana c Combat.Water = 7)


let () =
  (* Coverage, stated rather than guessed. The dispatch table and the id list have
     to agree with each other, and both have to line up with the real spell table -
     a body registered under an id no spell uses would look like progress and be
     nothing. *)
  check "101 of the 130 CastSpell bodies are ported"
    (List.length Spell_effects.effect_of_spell_ids = 101);
  check "and the real spell table resolves exactly that many"
    (List.length (List.filter_map
                    (fun (d : Spell.descriptor) -> Spell_effects.effect_of d.id)
                    Spell_data.spell_descriptors)
    = 101);
  check "every id in the list has a body, so the list is not lying"
    (List.for_all (fun id -> Spell_effects.effect_of id <> None)
       Spell_effects.effect_of_spell_ids);
  check "and every id in the list is a real spell"
    (List.for_all
       (fun id ->
          List.exists (fun (d : Spell.descriptor) -> d.id = id) Spell_data.spell_descriptors)
       Spell_effects.effect_of_spell_ids)


(* The column sweeps and the lightning spells.
   Seven bodies, and the reason ADD_LIGHTNING needs no port: it is a pixel-space
   animation, not a mechanic. See lib/spell_effects.ml. *)
(* A solid board of one kind, so a swept column is obvious. *)
let solid_board () = ref (Board.of_array_matrix (Array.make_matrix 8 8 (Mana Fire)))

let column_count b x =
  let n = ref 0 in
  for y = 0 to (!b).height - 1 do
    if equal_gem (get_gem !b { x; y }) Empty then incr n
  done;
  !n

let () =
  (* SCBO's percentile bands run in the OPPOSITE order to STAU's, and the default
     is load-bearing: the Lua starts at Water and only assigns in the first three
     bands, so anything above 75 falls through to Fire rather than staying Water.
     Getting this backwards is the easiest mistake in the file. *)
  let drained_at p =
    let c =
      caster ~mana:{ Combat.earth = 5; fire = 5; air = 5; water = 5 } ()
    in
    let e = foe ~mana:Combat.zero_mana () in
    Spell_effects.effect_scbo (fx ~percentile:p ~caster:c ~foe:e (ref (board_with Spell.GGreen 0)));
    List.find_opt (fun el -> Combat.mana c el = 0)
      [ Combat.Earth; Combat.Air; Combat.Fire; Combat.Water ]
  in
  check "SCBO at percentile 0 drains Earth" (drained_at 0 = Some Combat.Earth);
  check "SCBO at 25 is still Earth, being inclusive" (drained_at 25 = Some Combat.Earth);
  check "SCBO at 26 drains Air, the second band" (drained_at 26 = Some Combat.Air);
  check "SCBO at 50 is still Air" (drained_at 50 = Some Combat.Air);
  check "SCBO at 51 drains Fire, the third band" (drained_at 51 = Some Combat.Fire);
  check "SCBO at 75 is still Fire" (drained_at 75 = Some Combat.Fire);
  check "SCBO above 75 falls through to Water, not Fire"
    (drained_at 76 = Some Combat.Water && drained_at 99 = Some Combat.Water);

  (* The drained pool becomes damage, read before the drain. *)
  let c2 = caster ~mana:{ Combat.earth = 0; fire = 30; air = 0; water = 0 } () in
  let f2 = foe () in
  Spell_effects.effect_scbo (fx ~percentile:60 ~caster:c2 ~foe:f2 (ref (board_with Spell.GGreen 0)));
  check "SCBO deals the pool it drained" (f2.life = 70);
  check "SCBO emptied the Fire pool" (Combat.mana c2 Combat.Fire = 0)

let () =
  (* SZAP hits every enemy. The model has one, so the loop is a single iteration,
     but the damage is five plus an eighth of the caster's Fire. *)
  let c = caster ~mana:{ Combat.earth = 0; fire = 24; air = 0; water = 0 } () in
  let f = foe () in
  Spell_effects.effect_szap (fx ~caster:c ~foe:f (ref (board_with Spell.GGreen 0)));
  check "SZAP deals 5 plus 24/8, so 8" (f.life = 92)

let () =
  (* SCLI empties exactly the chosen column, and charges itself. *)
  let s = spell_costing ~earth:4 ~fire:0 ~air:4 ~water:0 "SCLI" in
  let c = caster ~mana:{ Combat.earth = 10; fire = 0; air = 10; water = 0 } () in
  let b = solid_board () in
  let ctx =
    fx ~spell:(Some s) ~input:(Some { Board.x = 3; y = 0 })
      ~roll:(fun _ -> 0) ~caster:c ~foe:(foe ()) b
  in
  Spell_effects.effect_scli ctx;
  check "SCLI empties the chosen column" (column_count b 3 = 8);
  check "SCLI leaves its neighbour alone" (column_count b 2 = 0);
  check "SCLI charged its own cost" (Combat.mana c Combat.Earth = 6);
  check "SCLI restored the bonus flags"
    (ctx.Spell.fx_flags.wildcard_chance && ctx.Spell.fx_flags.extra_turn_chance)

let () =
  (* SLIS takes three columns, and pulls the centre in from the edges so picking
     column 0 sweeps 0..2 rather than running off the board. *)
  let s = spell_costing ~earth:0 ~fire:0 ~air:0 ~water:0 "SLIS" in
  let run_slis x =
    let b = solid_board () in
    let ctx = fx ~spell:(Some s) ~input:(Some { Board.x = x; y = 0 }) ~roll:(fun _ -> 0)
                ~caster:(caster ()) ~foe:(foe ()) b
    in
    Spell_effects.effect_slis ctx;
    List.map (column_count b) [ 0; 1; 2; 3; 6; 7 ]
  in
  let swept = run_slis 3 in
  check "SLIS empties three columns for a middle pick"
    (swept = [ 0; 0; 8; 8; 0; 0 ]);
  let edge = run_slis 0 in
  check "SLIS pulls the centre in from the left edge, sweeping 0..2"
    (edge = [ 8; 8; 8; 0; 0; 0 ]);
  let right = run_slis 7 in
  check "SLIS pulls the centre in from the right edge, sweeping 5..7"
    (right = [ 0; 0; 0; 0; 8; 8 ])

let () =
  (* SSUT destroys two DIFFERENT random columns. Which two depends on the draw
     order, and [random_grid] takes two draws whose evaluation order OCaml does
     not specify - so this asserts the structural property rather than naming
     columns: exactly two swept, and they are different. *)
  let s = spell_costing ~earth:0 ~fire:0 ~air:0 ~water:0 "SSUT" in
  (* Always the same x for both draws, so every candidate column is 3 and the retry
     loop has to work for the second one to differ. *)
  let seq = ref [ 3; 3; 3; 3; 5; 5 ] in
  let roll _ = match !seq with [] -> 0 | h :: t -> seq := t; h in
  let b = solid_board () in
  let ctx = fx ~spell:(Some s) ~roll ~input:None ~caster:(caster ()) ~foe:(foe ()) b in
  Spell_effects.effect_ssut ctx;
  let swept = List.init 8 (fun x -> (column_count b x = 8, x)) in
  let emptied = List.length (List.filter fst swept) in
  check "SSUT empties exactly two columns" (emptied = 2);
  check "and they are different columns, so the retry loop worked"
    (List.length (List.map snd (List.filter fst swept)) = 2)

let () =
  (* SFCA detonates four cells, each a 3x3 blast, and charges itself. Four separate
     explosions on a solid board take noticeably more than one. *)
  let s = spell_costing ~earth:0 ~fire:0 ~air:0 ~water:0 "SFCA" in
  (* Four cells, one (x, y) pair per draw since random_grid takes two. *)
  let seq = ref [ 4; 4; 0; 4; 7; 1; 7; 6 ] in
  let roll _ = match !seq with [] -> 0 | h :: t -> seq := t; h in
  let b = solid_board () in
  let ctx = fx ~spell:(Some s) ~roll ~input:None ~caster:(caster ()) ~foe:(foe ()) b in
  Spell_effects.effect_sfca ctx;
  let emptied = ref 0 in
  for y = 0 to 7 do
    for x = 0 to 7 do
      if equal_gem (get_gem !b { x; y }) Empty then incr emptied
    done
  done;
  check "SFCA's four blasts clear more than a single 3x3" (!emptied > 9)

let () =
  (* SMST turns eight cells into Fire. The board starts all Water so every pick is
     accepted, and the roll walks forward through the columns so the eight
     conversions land in eight different places rather than one cell repeatedly -
     a pinned roll would make every retry re-pick the same cell and the try bound
     would absorb the rest, which is the bound working but not what is being
     tested here. *)
  let s = spell_costing ~earth:0 ~fire:0 ~air:0 ~water:0 "SMST" in
  (* Alternates: every even draw is x = 0, every odd draw walks y forward. That is
     eight distinct cells down one column, which is what eight conversions need - a
     plain mod-8 counter gives four repeated pairs instead. *)
  let counter = ref 0 in
  let roll n =
    if n <= 0 then 0
    else
      let k = !counter in
      incr counter;
      if k mod 2 = 0 then 0 else (k / 2) mod 8
  in
  let b = ref (Board.of_array_matrix (Array.make_matrix 8 8 (Mana Water))) in
  let ctx = fx ~spell:(Some s) ~roll ~input:None ~caster:(caster ()) ~foe:(foe ()) b in
  Spell_effects.effect_smst ctx;
  check "SMST converts eight cells to Fire" (count_of !b (Mana Fire) = 8);
  check "SMST leaves the rest of the board alone" (count_of !b (Mana Water) = 56);
  check "SMST restored the bonus flags" ctx.Spell.fx_flags.wildcard_chance
(* ------------------------------------------------------------------ *)
(* The board rewrites, the scatters, and the status sweeps              *)
(* ------------------------------------------------------------------ *)

(** A board holding several kinds at once, which the single-kind [board_with] and
    the two-kind [board_two_kinds] cannot both express. [mixed_board filler spec]
    lays the listed gems down first, in the order given, and fills the rest with
    [filler].

    The filler is always a parameter. Half of this group reads or writes Earth, so
    an Earth filler silently turns "a board with five skulls" into "a board with
    fifty-nine Earth gems", and every count downstream is wrong. *)
let mixed_board (filler : gem) (spec : (gem * int) list) : board =
  let cells = Array.make_matrix 8 8 filler in
  let left = List.map (fun (g, n) -> (g, ref n)) spec in
  for y = 0 to 7 do
    for x = 0 to 7 do
      match List.find_opt (fun (_, r) -> !r > 0) left with
      | Some (g, r) -> cells.(x).(y) <- g; decr r
      | None -> ()
    done
  done;
  Board.of_array_matrix cells

(** A roll that walks the board in row-major order, one cell per {e pair} of draws.

    [random_grid] takes two draws, one per coordinate, so a counter that simply
    returns [k mod 8] gives the pairs (0,1), (2,3), (4,5)... - four distinct
    cells and then a loop. Alternating on the parity of the counter instead makes
    the n-th pair the cell (n mod 8, (n / 8) mod 8), which is 64 distinct cells
    before it repeats.

    That matters for the scatters: they {e set} the cell they pick, and a pinned
    roll keeps re-picking one cell, so the count they were asked for never
    appears. Testing the try bound is worthwhile but it is not what these
    assertions are for. *)
let row_major_roll () =
  let c = ref 0 in
  fun n ->
    if n <= 0 then 0
    else begin
      let k = !c in
      incr c;
      if k mod 2 = 0 then (k / 2) mod 8 else ((k / 2) / 8) mod 8
    end

(** A roll that counts up, so a per-cell [GET_RANDOM_SYNC(0, n)] gives a different
    answer on every cell. [SNWR] is the reason this exists: it rolls a wildcard
    multiplier per converted gem, and a constant roll would make all of them
    identical, which is exactly what the body must {e not} do. *)
let counting_roll () =
  let c = ref 0 in
  fun n -> if n <= 0 then 0 else (let k = !c in incr c; k mod n)

let mana earth fire air water =
  { Combat.earth; fire; air; water }

let () =
  (* SBRA turns every Fire gem into a plain skull, and pays an extra turn at 15
     Fire banked. The threshold is the point: it is the same fifteen that gates
     SSOA on Air, and getting it wrong by one changes a turn. *)
  let b = ref (board_with Spell.GRed 5) in
  run "SBRA" ~caster:(caster ()) ~foe:(foe ()) b;
  check "SBRA rewrites Fire as plain skulls" (count_of !b Skull = 5);
  check "SBRA leaves no Fire gems" (count_of !b (Mana Fire) = 0);
  let c = caster ~mana:(mana 0 15 0 0) () in
  run "SBRA" ~caster:c ~foe:(foe ()) (ref (board_with Spell.GRed 5));
  check "SBRA takes an extra turn at 15 Fire" (c.extra_turns = 1);
  let c2 = caster ~mana:(mana 0 14 0 0) () in
  run "SBRA" ~caster:c2 ~foe:(foe ()) (ref (board_with Spell.GRed 5));
  check "SBRA takes none at 14" (c2.extra_turns = 0)

let () =
  (* SBUR and SEVA are the two one-line gem swaps, in opposite directions. Both
     are worth a test because the id order is the trap: Earth is 1 and Fire is 2
     on the board, which is not the character element order. *)
  let b = ref (board_with Spell.GGreen 5) in
  run "SBUR" ~caster:(caster ()) ~foe:(foe ()) b;
  check "SBUR rewrites Earth as Fire" (count_of !b (Mana Fire) = 64);
  check "SBUR leaves no Earth gems" (count_of !b (Mana Earth) = 0);
  let b2 = ref (board_with Spell.GYellow 5) in
  run "SEVA" ~caster:(caster ()) ~foe:(foe ()) b2;
  check "SEVA rewrites Air as Water" (count_of !b2 (Mana Water) = 5);
  check "SEVA leaves no Air gems" (count_of !b2 (Mana Air) = 0)

let () =
  (* SSOA is two sequential rewrites rather than one union, which is load-bearing:
     a Water gem becomes Air on the first pass and is then {e not} caught by the
     Earth pass, because the Lua runs two [if]s in order over the same cell. Doing
     it as a single union would also give Air here, so the assertions below cannot
     tell the two apart - they pin the outcome, not the order, and the order is
     argued in the body's comment. *)
  let b = ref (mixed_board (Mana Fire) [ (Mana Earth, 3); (Mana Water, 4) ]) in
  run "SSOA" ~caster:(caster ()) ~foe:(foe ()) b;
  check "SSOA rewrites both Earth and Water as Air" (count_of !b (Mana Air) = 7);
  check "SSOA leaves neither Earth nor Water" (count_of !b (Mana Earth) = 0 && count_of !b (Mana Water) = 0);
  check "SSOA leaves the Fire filler alone" (count_of !b (Mana Fire) = 57)

let () =
  (* SBRL turns three different kinds into one: both skull kinds and gold all
     become Earth. The board keeps its 64 gems - this is a rewrite, not a delete,
     and the distinction is the whole point of the spell. *)
  let b =
    ref (mixed_board (Mana Fire)
           [ Skull, 2; RedSkull, 3; Gold, 4 ])
  in
  run "SBRL" ~caster:(caster ()) ~foe:(foe ()) b;
  check "SBRL rewrites both skull kinds and gold as Earth" (count_of !b (Mana Earth) = 9);
  check "SBRL leaves no skulls, red skulls or gold"
    (count_of !b Skull = 0 && count_of !b RedSkull = 0 && count_of !b Gold = 0);
  check "SBRL kept the Fire filler, so it rewrote rather than deleted"
    (count_of !b (Mana Fire) = 55)

let () =
  (* SCON and SPRO are the same body keyed on whatever the player aimed at, rather
     than on a fixed gem. Both need an input cell, and both are no-ops without one,
     so the None case is asserted too. *)
  let aimed (g : gem) =
    let b = ref (mixed_board (Mana Fire) [ (g, 6) ]) in
    b
  in
  let b = aimed (Mana Water) in
  Spell_effects.effect_scon
    (fx ~input:(Some { Board.x = 0; y = 0 }) ~roll:(fun _ -> 0)
       ~caster:(caster ()) ~foe:(foe ()) b);
  check "SCON rewrites the aimed kind as Fire everywhere" (count_of !b (Mana Fire) = 64);
  check "SCON emptied the kind it aimed at" (count_of !b (Mana Water) = 0);
  let b2 = aimed (Mana Water) in
  Spell_effects.effect_spro
    (fx ~input:(Some { Board.x = 0; y = 0 }) ~roll:(fun _ -> 0)
       ~caster:(caster ()) ~foe:(foe ()) b2);
  check "SPRO rewrites the aimed kind as experience" (count_of !b2 Experience = 6);
  check "SPRO emptied the kind it aimed at" (count_of !b2 (Mana Water) = 0)

let () =
  (* SNWR turns every Earth gem into a wildcard whose multiplier is rolled
     {e per cell}. That is the assertion worth having: a single roll for the whole
     board would still produce 64 wildcards, and would pass every count-based check
     here. *)
  let b = ref (board_with Spell.GGreen 5) in
  Spell_effects.effect_snwr
    (fx ~roll:(counting_roll ()) ~caster:(caster ()) ~foe:(foe ()) b);
  check "SNWR rewrites every Earth gem as a wildcard" (count_of !b (Mana Earth) = 0);
  let multipliers = ref [] in
  for y = 0 to 7 do
    for x = 0 to 7 do
      match get_gem !b { x; y } with
      | Wildcard k -> multipliers := k :: !multipliers
      | _ -> ()
    done
  done;
  check "SNWR made five wildcards, one per Earth gem" (List.length !multipliers = 5);
  check "SNWR rolls the multiplier per cell, not once for the board"
    (List.length (List.sort_uniq compare !multipliers) = 5);
  check "and every multiplier is in the 2..8 band the Lua indexes"
    (List.for_all (fun k -> k >= 2 && k <= 8) !multipliers)

let () =
  (* SCHM and SRFC are one body over a different gem: delete every gem of a kind
     and heal the caster for the count. The caster starts hurt so the healing is
     visible, and healing cannot exceed max life - [add_life] clamps. *)
  let c = caster ~life:50 () in
  let b = ref (mixed_board (Mana Fire) [ Skull, 3; RedSkull, 2 ]) in
  run "SCHM" ~caster:c ~foe:(foe ()) b;
  check "SCHM deletes both skull kinds" (count_of !b Skull = 0 && count_of !b RedSkull = 0);
  check "SCHM heals for the five it removed" (c.life = 55);
  let c2 = caster ~life:98 () in
  run "SRFC" ~caster:c2 ~foe:(foe ()) (ref (mixed_board (Mana Fire) [ Gold, 4 ]));
  check "SRFC deletes every gold gem" true;
  check "SRFC heals for the four gold it removed, clamped at max life" (c2.life = 100)

let () =
  (* SDBR scatters plain skulls: a third of the caster's Fire, capped at ten. It
     {e sets} cells rather than adding gems, and avoids cells that already hold
     either skull so it cannot stack - so the count is checked against a board
     with no skulls on it at all, where every pick is accepted. *)
  let c = caster ~mana:(mana 0 30 0 0) () in
  let b = ref (board_with Spell.GGreen 0) in
  Spell_effects.effect_sdbr
    (fx ~roll:(row_major_roll ()) ~caster:c ~foe:(foe ()) b);
  check "SDBR scatters a third of 30 Fire, capped at ten" (count_of !b Skull = 10);
  let c2 = caster ~mana:(mana 0 15 0 0) () in
  let b2 = ref (board_with Spell.GGreen 0) in
  Spell_effects.effect_sdbr
    (fx ~roll:(row_major_roll ()) ~caster:c2 ~foe:(foe ()) b2);
  check "SDBR at 15 Fire scatters five" (count_of !b2 Skull = 5)

let () =
  (* SGOW is five plus an eighth of the caster's Air, as yellow gems. It is one of
     the bodies that suppresses the multiplier effects while it works, so the flag
     has to be back on afterwards - asserted, since a suppressed flag would
     silently disarm every later match. *)
  let c = caster ~mana:(mana 0 0 24 0) () in
  let b = ref (board_with Spell.GRed 0) in
  let ctx =
    fx ~roll:(row_major_roll ()) ~caster:c ~foe:(foe ()) b
  in
  Spell_effects.effect_sgow ctx;
  check "SGOW scatters five plus a third of 24 Air, so eight" (count_of !b (Mana Air) = 8);
  check "SGOW restored the bonus flags" ctx.Spell.fx_flags.wildcard_chance

let () =
  (* SDGZ deals half the enemy's remaining life and then adds one skull per five
     points of that damage, capped at ten. The damage figure is the {e uncapped}
     one, so a foe too weak to be worth five points adds nothing - which is the
     case worth asserting, because an implementation that capped first would add a
     skull here. *)
  let f = foe ~life:20 () in
  let b = ref (board_with Spell.GGreen 0) in
  Spell_effects.effect_sdgz
    (fx ~roll:(row_major_roll ()) ~caster:(caster ()) ~foe:f b);
  check "SDGZ deals half of 20 life" (f.life = 10);
  check "SDGZ adds one skull per five damage, so two" (count_of !b Skull = 2);
  let f2 = foe ~life:3 () in
  let b2 = ref (board_with Spell.GGreen 0) in
  Spell_effects.effect_sdgz
    (fx ~roll:(row_major_roll ()) ~caster:(caster ()) ~foe:f2 b2);
  check "SDGZ against a foe on 3 life deals 1 and adds no skull"
    (f2.life = 2 && count_of !b2 Skull = 0)

let () =
  (* SKLO doubles the experience gems already on the board. The count is taken up
     front and the new gems avoid existing ones, so they land in distinct cells -
     asserted as a count of 10 from an original 5. *)
  let b = ref (mixed_board (Mana Fire) [ Experience, 5 ]) in
  Spell_effects.effect_sklo
    (fx ~roll:(row_major_roll ()) ~caster:(caster ()) ~foe:(foe ()) b);
  check "SKLO doubles the experience gems" (count_of !b Experience = 10)

let () =
  (* SWTD converts a fifth of the caster's Earth pool worth of plain skulls into
     red skulls, picking only cells that actually hold a skull. Three skulls and
     fifteen Earth is exactly three conversions. *)
  let c = caster ~mana:(mana 15 0 0 0) () in
  let b = ref (mixed_board (Mana Fire) [ Skull, 3 ]) in
  Spell_effects.effect_swtd
    (fx ~roll:(row_major_roll ()) ~caster:c ~foe:(foe ()) b);
  check "SWTD converts a fifth of 15 Earth, so three skulls" (count_of !b RedSkull = 3);
  check "SWTD leaves no plain skulls behind" (count_of !b Skull = 0)

let () =
  (* SCOU wipes the caster's statuses and nothing else; SCLM wipes both sides.
     Both then pay an extra turn at ten Water banked. *)
  let c = caster ~mana:(mana 0 0 0 10) () and f = foe () in
  c.effects <- [ ("Hidden", 3) ];
  f.effects <- [ ("Fear", 2) ];
  run "SCOU" ~caster:c ~foe:f (ref (board_with Spell.GGreen 0));
  check "SCOU clears the caster's statuses" (c.effects = []);
  check "SCOU leaves the enemy alone" (f.effects = [ ("Fear", 2) ]);
  check "SCOU takes an extra turn at 10 Water" (c.extra_turns = 1);
  let c2 = caster ~mana:(mana 0 0 0 9) () and f2 = foe () in
  c2.effects <- [ ("Hidden", 3) ];
  run "SCOU" ~caster:c2 ~foe:f2 (ref (board_with Spell.GGreen 0));
  check "SCOU takes none at 9 Water" (c2.extra_turns = 0);
  let c3 = caster ~mana:(mana 0 0 0 10) () and f3 = foe () in
  c3.effects <- [ ("Hidden", 3) ];
  f3.effects <- [ ("Fear", 2) ];
  run "SCLM" ~caster:c3 ~foe:f3 (ref (board_with Spell.GGreen 0));
  check "SCLM clears both sides" (c3.effects = [] && f3.effects = []);
  check "SCLM takes an extra turn at 10 Water" (c3.extra_turns = 1)

let () =
  (* SHSI is a transfer, not a copy: the enemy is drained by exactly what the
     caster receives. Asserting both halves is the only way to tell it from a
     duplication, and the cap is the other half worth pinning. *)
  let c = caster () and f = foe ~mana:(mana 0 20 0 0) () in
  run "SHSI" ~caster:c ~foe:f (ref (board_with Spell.GGreen 0));
  check "SHSI moves eight Fire to the caster" (Combat.mana c Fire = 8);
  check "SHSI drains the enemy by the same eight" (Combat.mana f Fire = 12);
  let c2 = caster () and f2 = foe ~mana:(mana 0 3 0 0) () in
  run "SHSI" ~caster:c2 ~foe:f2 (ref (board_with Spell.GGreen 0));
  check "SHSI takes only what the enemy has" (Combat.mana c2 Fire = 3 && Combat.mana f2 Fire = 0)

let () =
  (* SWBU is three missed turns plus one per eight Air gems, and it deletes those
     Air gems in the same breath. Sixteen Air gems is five turns. *)
  let f = foe () in
  let b = ref (board_with Spell.GYellow 16) in
  run "SWBU" ~caster:(caster ()) ~foe:f b;
  check "SWBU deletes the Air gems it counted" (count_of !b (Mana Air) = 0);
  check "SWBU misses three turns plus one per eight Air, so five"
    (f.effects = [ ("Missed", 5) ])

let () =
  (* SSTO destroys every Earth gem with the multiplier effects suppressed, so it
     pays out no Earth-to-mana conversion. Asserted negatively too: an earlier
     reading had it also making the enemy miss two turns, and it does not. *)
  let f = foe () in
  let b = ref (board_with Spell.GGreen 5) in
  let ctx = fx ~roll:(fun _ -> 0) ~caster:(caster ()) ~foe:f b in
  Spell_effects.effect_ssto ctx;
  check "SSTO destroys every Earth gem" (count_of !b (Mana Earth) = 0);
  check "SSTO restored the bonus flags" ctx.Spell.fx_flags.wildcard_chance;
  check "SSTO applies no status to the enemy" (f.effects = [])

let () =
  if !failures = 0 then print_endline "All spell effect tests passed."
  else begin
    Printf.printf "%d spell effect test(s) failed.\n" !failures;
    exit 1
  end

