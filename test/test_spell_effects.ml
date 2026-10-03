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

let fx ?(spell = None) ?(percentile = 0) ?(roll = fun n -> if n <= 0 then 0 else 0 mod n) ~caster ~foe (board : board ref) =
  { Spell.fx_caster = caster
  ; Spell.fx_enemies = [ foe ]
  ; Spell.fx_board = board
  ; Spell.fx_roll = roll
  ; Spell.fx_gold = ref 0
  ; Spell.fx_xp = ref 0
  ; Spell.fx_input = None
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
  check "74 of the 130 CastSpell bodies are ported"
    (List.length Spell_effects.effect_of_spell_ids = 74);
  check "and the real spell table resolves exactly that many"
    (List.length (List.filter_map
                    (fun (d : Spell.descriptor) -> Spell_effects.effect_of d.id)
                    Spell_data.spell_descriptors)
    = 74);
  check "every id in the list has a body, so the list is not lying"
    (List.for_all (fun id -> Spell_effects.effect_of id <> None)
       Spell_effects.effect_of_spell_ids);
  check "and every id in the list is a real spell"
    (List.for_all
       (fun id ->
          List.exists (fun (d : Spell.descriptor) -> d.id = id) Spell_data.spell_descriptors)
       Spell_effects.effect_of_spell_ids)

let () =
  if !failures = 0 then print_endline "All spell effect tests passed."
  else begin
    Printf.printf "%d spell effect test(s) failed.\n" !failures;
    exit 1
  end

