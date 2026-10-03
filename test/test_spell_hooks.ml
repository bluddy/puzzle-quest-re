(* The spell AI hooks that decide without reading the board.

   These are the hand-written hooks in [lib/spell_ai_manual.ml] that work from
   the caster's and enemy's mana pools, the damage taken so far, the active status
   effects, and - for SDUP - the two sides' item slots. They are in their own file
   because they need a combatant that can be part way down and already carrying a
   status, which the fixtures in [test_spell.ml] do not otherwise want.

   The board in the context is left at its default and is irrelevant, so what
   varies between assertions is always the pools, the life, or the effects. Every
   one of these hooks reads the percentile or the evaluation or both, so both are
   spelled out in each assertion.

   Expectations come from the Lua in [Assets/Spells/*.lua], not from the port,
   which is why several read as counter-intuitive. A positive modifier *raises*
   the percentile a spell needs; it does not make the spell happen sooner. Only
   the sign of the resulting comparison matters. Assertions are kept to one line
   each so a mistake in the arithmetic is visible rather than buried in
   indentation. *)

open Puzzle_quest_lib
open Combat

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let hero ?(mana = Combat.zero_mana) ?(life = 100) ?(max_life = 100) ?(effects = []) () =
  Combat.make_combatant ~mana ~life ~max_life ~effects 0 "hero"

let ctx ?(evaluation = 0) ?(percentile = 0) ?(caster = hero ()) ?(enemy = hero ())
    ?(board = Board.of_array_matrix (Array.make_matrix 8 8 Board.Skull))
    ?(items = None) ?(enemy_items = None) () =
  { Spell.ctx_caster = caster
  ; Spell.ctx_enemy = enemy
  ; Spell.ctx_enemies = [ enemy ]
  ; Spell.ctx_board = board
  ; Spell.ctx_evaluation = evaluation
  ; Spell.ctx_percentile = percentile
  ; Spell.ctx_roll = (fun _ -> 0)
  ; Spell.ctx_items = items
  ; Spell.ctx_enemy_items = enemy_items
  }

(* The four pool fields are always written in full. A record expression has to
   name every field, so building a pool means starting from [zero_mana] and
   updating it; and [open Board] alongside [open Combat] puts "fire" and "air" in
   scope twice over, so the update is written with the module qualified. *)
let with_earth (m : Combat.mana) n = { m with Combat.earth = n }
let with_fire (m : Combat.mana) n = { m with Combat.fire = n }
let with_air (m : Combat.mana) n = { m with Combat.air = n }
let with_water (m : Combat.mana) n = { m with Combat.water = n }

let earth n = hero ~mana:(with_earth zero_mana n) ()
let fire n = hero ~mana:(with_fire zero_mana n) ()
let air n = hero ~mana:(with_air zero_mana n) ()
let hurt n = hero ~life:(100 - n) ~max_life:100 ()
let affected l = hero ~effects:l ()
let with_pools e f a w =
  let m = with_earth zero_mana e in
  let m = with_fire m f in
  let m = with_air m a in
  hero ~mana:(with_water m w) ()

(* ------------------------------------------------------------------ *)
(* Mana-only hooks                                                      *)
(* ------------------------------------------------------------------ *)

(* SBAV and SFLV subtract ten with no floor, so a small pool gives a negative
   modifier rather than a veto. The modifier shifts the percentile the spell
   needs, so a pool of 100 needs a percentile of 140, which no 0..99 roll ever
   reaches. A full pool makes SBAV certain, not impossible. *)
let () =
  check "SBAV with a full pool fires on any roll"
    (Spell_ai_manual.hook_sbav (ctx ~caster:(with_pools 100 100 100 100) ~percentile:99 ()));
  check "SBAV with an empty pool fires on a percentile of 40"
    (Spell_ai_manual.hook_sbav (ctx ~caster:(hero ()) ~percentile:40 ()));
  check "SBAV with an empty pool does not fire on 41"
    (not (Spell_ai_manual.hook_sbav (ctx ~caster:(hero ()) ~percentile:41 ())));
  check "SFLV reads Fire, so a full Earth pool does not help it"
    (Spell_ai_manual.hook_sflv (ctx ~caster:(earth 100) ~percentile:99 ())
     = Spell_ai_manual.hook_sflv (ctx ~caster:(hero ()) ~percentile:99 ()))

(* SCBO averages with Lua's truncating division: a total of 33 is 8 and clears
   the floor of 8, while 31 is 7 and does not. *)
let () =
  check "SCBO accepts a total of 33, which truncates to 8"
    (Spell_ai_manual.hook_scbo (ctx ~caster:(earth 33) ~percentile:0 ()));
  check "SCBO rejects a total of 31, which truncates to 7"
    (not (Spell_ai_manual.hook_scbo (ctx ~caster:(earth 31) ~percentile:0 ())));
  check "SCBO counts all four pools, not just Earth"
    (Spell_ai_manual.hook_scbo (ctx ~caster:(with_pools 8 8 8 8) ~percentile:0 ()))

(* SCTO tests "more than ten", so exactly ten qualifies and eleven does not. *)
let () =
  check "SCTO allows exactly ten"
    (Spell_ai_manual.hook_scto (ctx ~caster:(earth 10) ~percentile:0 ()));
  check "SCTO rejects eleven"
    (not (Spell_ai_manual.hook_scto (ctx ~caster:(earth 11) ~percentile:0 ())))

(* SBST has a discontinuity. The enemy at five or under gives the pool minus ten,
   and at six gives three times the pool, so the modifier jumps from -5 to 18 and
   the percentile that qualifies falls from 45 to 68. *)
let () =
  check "SBST with the enemy at 5 fires on a percentile of 45"
    (Spell_ai_manual.hook_sbst (ctx ~enemy:(earth 5) ~percentile:45 ()));
  check "SBST with the enemy at 5 does not fire on 46"
    (not (Spell_ai_manual.hook_sbst (ctx ~enemy:(earth 5) ~percentile:46 ())));
  check "SBST with the enemy at 6 fires on a percentile of 68"
    (Spell_ai_manual.hook_sbst (ctx ~enemy:(earth 6) ~percentile:68 ()));
  check "SBST with the enemy at 6 does not fire on 69"
    (not (Spell_ai_manual.hook_sbst (ctx ~enemy:(earth 6) ~percentile:69 ())))

(* SMBU vetoes when the enemy totals ten or under whatever the roll, because the
   Lua returns -50 there and anything at or below zero is a veto. *)
let () =
  check "SMBU vetoes at exactly 10, which is the inclusive boundary"
    (not (Spell_ai_manual.hook_smbu (ctx ~enemy:(earth 10) ~percentile:99 ())));
  check "SMBU fires at 11"
    (Spell_ai_manual.hook_smbu (ctx ~enemy:(earth 11) ~percentile:0 ()));
  check "SMBU sums all four pools"
    (not (Spell_ai_manual.hook_smbu (ctx ~enemy:(with_pools 3 3 3 1) ~percentile:99 ())))

(* SSSW casts only from behind. Equal totals are not "ahead", so it proceeds and
   then asks with a modifier of zero. *)
let () =
  check "SSSW refuses when the caster is ahead"
    (not (Spell_ai_manual.hook_sssw (ctx ~caster:(earth 20) ~enemy:(earth 10) ())));
  check "SSSW fires when behind"
    (Spell_ai_manual.hook_sssw (ctx ~caster:(earth 10) ~enemy:(earth 20) ~percentile:0 ()));
  check "SSSW fires when level, since equal is not ahead"
    (Spell_ai_manual.hook_sssw (ctx ~caster:(earth 10) ~enemy:(earth 10) ~percentile:0 ()))

(* SSBM reads three pools on two combatants and all four clauses can fire at once,
   so each assertion below holds the other three still. A caster with no Water is
   charged 10 and cancels the enemy's bonus exactly. *)
let () =
  let plain = with_pools 0 0 0 10 in
  let poor = with_pools 0 0 0 0 in
  let rich = with_pools 0 0 0 25 in
  let enemy_air n = with_pools 0 0 n 0 in
  check "SSBM pays 10 when the enemy holds more than 10 Air, and only 10"
    (Spell_ai_manual.hook_ssbm (ctx ~caster:plain ~enemy:(enemy_air 12) ~percentile:60 ()));
  check "SSBM charges 10 when the enemy holds under 5 Air, so it needs only 40"
    (Spell_ai_manual.hook_ssbm (ctx ~caster:plain ~enemy:(enemy_air 4) ~percentile:40 ()));
  check "and does not fire at 41 in that case"
    (not (Spell_ai_manual.hook_ssbm (ctx ~caster:plain ~enemy:(enemy_air 4) ~percentile:41 ())));
  check "SSBM charges 10 when the caster has no Water, cancelling the bonus"
    (not (Spell_ai_manual.hook_ssbm (ctx ~caster:poor ~enemy:(enemy_air 12) ~percentile:60 ())));
  check "SSBM charges 10 when the caster has over 20 Water"
    (not (Spell_ai_manual.hook_ssbm (ctx ~caster:rich ~enemy:(enemy_air 12) ~percentile:60 ())));
  check "SSBM charges 10 when the enemy has under 5 Air"
    (not (Spell_ai_manual.hook_ssbm (ctx ~caster:plain ~enemy:(enemy_air 4) ~percentile:60 ())))

(* SSHO is three flat bonuses of ten for the enemy sitting above five in any of
   three pools. *)
let () =
  check "SSHO pays 30 when the enemy is rich in all three"
    (Spell_ai_manual.hook_ssho (ctx ~enemy:(with_pools 0 9 9 9) ~percentile:80 ()));
  check "SSHO pays nothing when the enemy is below five in all three"
    (Spell_ai_manual.hook_ssho (ctx ~enemy:(with_pools 0 1 1 1) ~percentile:50 ()))

(* ------------------------------------------------------------------ *)
(* Life hooks                                                           *)
(* ------------------------------------------------------------------ *)

(* SRGN is the only hook that is a bare comparison: four points of damage, no
   percentile and no evaluation gate at all. *)
let () =
  check "SRGN fires at 4 damage" (Spell_ai_manual.hook_srgn (ctx ~caster:(hurt 4) ()));
  check "SRGN does not fire at 3"
    (not (Spell_ai_manual.hook_srgn (ctx ~caster:(hurt 3) ())));
  check "SRGN ignores a board scoring 99"
    (Spell_ai_manual.hook_srgn (ctx ~caster:(hurt 4) ~percentile:99 ~evaluation:99 ()))

(* SGEM vetoes when life is within five of full, so it needs six damage. *)
let () =
  check "SGEM fires at 6 damage"
    (Spell_ai_manual.hook_sgem (ctx ~caster:(hurt 6) ~percentile:50 ()));
  check "SGEM vetoes at 5"
    (not (Spell_ai_manual.hook_sgem (ctx ~caster:(hurt 5) ~percentile:50 ())))

(* SEGZ grades the modifier in three bands: under 10 damage costs 20, over 30 pays
   50, and the gap between pays nothing. *)
let () =
  check "SEGZ with 5 damage lost fires on a percentile of 30"
    (Spell_ai_manual.hook_segz (ctx ~caster:(hurt 5) ~percentile:30 ()));
  check "SEGZ with 5 damage lost does not fire on 31"
    (not (Spell_ai_manual.hook_segz (ctx ~caster:(hurt 5) ~percentile:31 ())));
  check "SEGZ with 40 damage lost fires on a percentile of 99"
    (Spell_ai_manual.hook_segz (ctx ~caster:(hurt 40) ~percentile:99 ()));
  check "SEGZ in the middle band still needs only 50"
    (Spell_ai_manual.hook_segz (ctx ~caster:(hurt 20) ~percentile:50 ()))

(* SDGZ is the enemy's life less twenty as the modifier, so a nearly dead enemy
   makes the spell more attractive. It is deliberately not vetoed at zero damage,
   and at 21 life the modifier is +1, which needs a percentile of 51. *)
let () =
  check "SDGZ against a foe on 20 life needs a percentile of 50"
    (Spell_ai_manual.hook_sdgz (ctx ~enemy:(hero ~life:20 ()) ~percentile:50 ()));
  check "SDGZ against a foe on 21 life still fires at 50, because it gains a point"
    (Spell_ai_manual.hook_sdgz (ctx ~enemy:(hero ~life:21 ()) ~percentile:50 ()));
  check "SDGZ against a foe on 21 life does not fire at 52"
    (not (Spell_ai_manual.hook_sdgz (ctx ~enemy:(hero ~life:21 ()) ~percentile:52 ())));
  check "SDGZ against an undamaged foe needs a percentile of 80"
    (Spell_ai_manual.hook_sdgz (ctx ~enemy:(hero ~life:100 ()) ~percentile:80 ()))

(* ------------------------------------------------------------------ *)
(* Status-effect gates                                                  *)
(* ------------------------------------------------------------------ *)

(* The names below are the StatusEffects file names. They are not the
   STATUS_EFFECT_ constants with the prefix stripped: the game appends a
   participle to most of them, so HASTE is the file "Hasted" and WALLOFFIRE is
   "WallOfFired". *)
let () =
  check "SCHL refuses when the caster is already Challenged"
    (not (Spell_ai_manual.hook_schl (ctx ~caster:(affected [ ("Challenged", 3) ]) ())));
  check "SCHL fires when it is not, and needs a percentile of 50"
    (Spell_ai_manual.hook_schl (ctx ~caster:(affected [ ("Enraged", 3) ]) ~percentile:50 ()));
  check "SENR refuses when already Enraged"
    (not (Spell_ai_manual.hook_senr (ctx ~caster:(affected [ ("Enraged", 3) ]) ())));
  check "SENR fires when it is not"
    (Spell_ai_manual.hook_senr (ctx ~caster:(affected [ ("Hidden", 3) ]) ~percentile:50 ()));
  check "SHAS refuses when already Hasted"
    (not (Spell_ai_manual.hook_shas (ctx ~caster:(affected [ ("Hasted", 3) ]) ())));
  check "SHID refuses when already Hidden"
    (not (Spell_ai_manual.hook_shid (ctx ~caster:(affected [ ("Hidden", 3) ]) ())));
  check "an unrelated effect does not block SHID"
    (Spell_ai_manual.hook_shid (ctx ~caster:(affected [ ("Poison", 3) ]) ~percentile:50 ()))

(* SCOU reads GET_NUM_STATUS_EFFECTS rather than a named effect, so any effect at
   all is enough to trigger its -50. *)
let () =
  check "SCOU fires on an empty caster at a percentile of 50"
    (Spell_ai_manual.hook_scou (ctx ~caster:(hero ()) ~percentile:50 ()));
  check "SCOU refuses when carrying anything, however little"
    (not (Spell_ai_manual.hook_scou (ctx ~caster:(affected [ ("Poison", 2) ]) ~percentile:99 ())))

(* SWOF vetoes on the wall already being up, then grades the caster's Fire at a
   single step: 20 above fourteen, nothing at or below it. *)
let () =
  check "SWOF refuses when the wall is already up"
    (not (Spell_ai_manual.hook_swof (ctx ~caster:(affected [ ("WallOfFired", 3) ]) ())));
  check "SWOF rewards Fire of 15"
    (Spell_ai_manual.hook_swof (ctx ~caster:(fire 15) ~percentile:70 ()));
  check "SWOF gives nothing at exactly 14"
    (Spell_ai_manual.hook_swof (ctx ~caster:(fire 14) ~percentile:50 ()))

(* SSBL returns -10 outright when Singing Blades is up, which is a veto rather
   than a small penalty, and otherwise asks with a positive 25. *)
let () =
  check "SSBL refuses when Singing Blades is up"
    (not (Spell_ai_manual.hook_ssbl (ctx ~caster:(affected [ ("SingingBladesed", 3) ]) ())));
  check "SSBL fires otherwise, and needs only a percentile of 25"
    (Spell_ai_manual.hook_ssbl (ctx ~caster:(hero ()) ~percentile:25 ()))

(* SHWL subtracts 40 from the percentile before the usual 50 gate, so a Frightened
   enemy makes the roll have to be *higher*, from 50 to 90. It is a penalty on both
   sides of the comparison, which is easy to read backwards. *)
let () =
  let scared = affected [ ("Fear", 3) ] in
  check "SHWL needs a percentile of 90 against a Frightened foe"
    (Spell_ai_manual.hook_shwl (ctx ~enemy:scared ~percentile:90 ()));
  check "SHWL does not fire at 89 against one"
    (not (Spell_ai_manual.hook_shwl (ctx ~enemy:scared ~percentile:89 ())));
  check "SHWL needs only 50 against an ordinary foe"
    (Spell_ai_manual.hook_shwl (ctx ~enemy:(hero ()) ~percentile:50 ()));
  check "SHWL does not fire at 49 against an ordinary foe"
    (not (Spell_ai_manual.hook_shwl (ctx ~enemy:(hero ()) ~percentile:49 ())))

(* SSPT is the same idea with a smaller penalty, but applied to the modifier:
   Blinding a Blinded enemy lowers the threshold from 50 to 35. *)
let () =
  let blinded = affected [ ("Blinded", 2) ] in
  check "SSPT needs 35 against a Blinded foe"
    (Spell_ai_manual.hook_sspt (ctx ~enemy:blinded ~percentile:35 ()));
  check "SSPT does not fire at 36 against one"
    (not (Spell_ai_manual.hook_sspt (ctx ~enemy:blinded ~percentile:36 ())));
  check "SSPT needs 50 against an ordinary foe"
    (Spell_ai_manual.hook_sspt (ctx ~enemy:(hero ()) ~percentile:50 ()))

(* ------------------------------------------------------------------ *)
(* The evaluate-then-percentile family                                 *)
(* ------------------------------------------------------------------ *)

(* SSPF is the simplest gate in the game and the only one with no evaluation
   check: a percentile of 15 or more is the whole test, so a board worth 99 still
   lets it through. *)
let () =
  check "SSPF fires on a board scoring 99 at percentile 15"
    (Spell_ai_manual.hook_sspf (ctx ~percentile:15 ~evaluation:99 ()));
  check "SSPF does not fire at 14"
    (not (Spell_ai_manual.hook_sspf (ctx ~percentile:14 ())))

(* The family vetoes on a percentile below 50 and on an evaluation above 30, in
   that order, so a good board rejects regardless of the roll. *)
let () =
  check "SRBI fires at a percentile of exactly 50"
    (Spell_ai_manual.hook_srbi (ctx ~percentile:50 ()));
  check "SRBI does not fire at 49"
    (not (Spell_ai_manual.hook_srbi (ctx ~percentile:49 ())));
  check "SRBI rejects a board scoring 31 even on the best roll"
    (not (Spell_ai_manual.hook_srbi (ctx ~percentile:99 ~evaluation:31 ())));
  check "SRBI accepts a board scoring exactly 30"
    (Spell_ai_manual.hook_srbi (ctx ~percentile:50 ~evaluation:30 ()))

(* STAU uses >= against the evaluation, so it rejects a board scoring exactly 30
   where SRBI, which uses >, accepts it. That one character is the whole
   difference between the two hooks. *)
let () =
  check "STAU rejects an evaluation of exactly 30"
    (not (Spell_ai_manual.hook_stau (ctx ~evaluation:30 ~enemy:(earth 40) ~percentile:50 ())));
  check "STAU accepts 29"
    (Spell_ai_manual.hook_stau (ctx ~evaluation:29 ~enemy:(earth 40) ~percentile:50 ()));
  check "STAU vetoes when the enemy totals under 20"
    (not (Spell_ai_manual.hook_stau (ctx ~enemy:(earth 8) ~percentile:99 ())))

(* STHU and SVAM bias the evaluation rather than the percentile, so they want a
   good board rather than a bad one, the opposite of the family above. SVAM is
   STHU shifted down by a sixth of the caster's Fire pool. *)
let () =
  check "STHU fires on a good board with a friendly roll"
    (Spell_ai_manual.hook_sthu (ctx ~evaluation:10 ~percentile:70 ()));
  check "STHU refuses on a poor board even with a friendly roll"
    (not (Spell_ai_manual.hook_sthu (ctx ~evaluation:40 ~percentile:70 ())));
  check "SVAM fires on an evaluation of 31 when the caster has banked Fire"
    (Spell_ai_manual.hook_svam (ctx ~caster:(fire 24) ~evaluation:31 ~percentile:74 ()));
  check "SVAM refuses the same board with no Fire banked, since nothing shifts it"
    (not (Spell_ai_manual.hook_svam (ctx ~caster:(hero ()) ~evaluation:31 ~percentile:74 ())))

(* SPET and SWEB add a third of a pool to the percentile, and Lua's integer
   division truncates, so 2 Earth adds nothing and 3 adds one. *)
let () =
  let bare = Spell_ai_manual.hook_spet (ctx ~caster:(hero ()) ~percentile:49 ()) in
  let two = Spell_ai_manual.hook_spet (ctx ~caster:(earth 2) ~percentile:49 ()) in
  let three = Spell_ai_manual.hook_spet (ctx ~caster:(earth 3) ~percentile:49 ()) in
  check "SPET with 2 Earth does not gain the extra point" (two = bare);
  check "SPET with 3 Earth gains one point and fires at 49" three

(* SSWP sums Air mana over the enemy side. With one enemy that is the one pool, and
   six is the floor. *)
let () =
  check "SSWP vetoes when the enemy has 4 Air"
    (not (Spell_ai_manual.hook_sswp (ctx ~enemy:(air 4) ~percentile:99 ())));
  check "SSWP fires when the enemy has 6 Air"
    (Spell_ai_manual.hook_sswp (ctx ~enemy:(air 6) ~percentile:50 ()))

(* SBUR, SSTO and SSOA count gems on the board, so they need a board built for
   the purpose. SBRA additionally reads the caster's own Fire pool. *)
let board_of n kind =
  let left = ref n in
  let filler = if kind = Spell.GGreen then Board.Mana Fire else Board.Mana Earth in
  Board.of_array_matrix
    (Array.init 8 (fun _ ->
         Array.init 8 (fun _ ->
             if !left > 0 then begin
               decr left;
               Spell.gem_of_kind kind
             end
             else filler)))

let () =
  let with_board b = ctx ~board:b ~percentile:50 () in
  check "SBUR vetoes with only seven green gems"
    (not (Spell_ai_manual.hook_sbur (with_board (board_of 7 Spell.GGreen))));
  check "SBUR fires with eight"
    (Spell_ai_manual.hook_sbur (with_board (board_of 8 Spell.GGreen)));
  check "SSTO vetoes with only five green gems"
    (not (Spell_ai_manual.hook_ssto (with_board (board_of 5 Spell.GGreen))));
  check "SSTO fires with six"
    (Spell_ai_manual.hook_ssto (with_board (board_of 6 Spell.GGreen)));
  check "SSOA vetoes with only seven gems across Earth and Water"
    (not (Spell_ai_manual.hook_ssoa (with_board (board_of 7 Spell.GGreen))));
  check "SSOA fires with eight"
    (Spell_ai_manual.hook_ssoa (with_board (board_of 8 Spell.GGreen)));
  check "SBRA vetoes with only five red gems"
    (not (Spell_ai_manual.hook_sbra (with_board (board_of 5 Spell.GRed))));
  check "SBRA fires with six red and no Fire banked"
    (Spell_ai_manual.hook_sbra (with_board (board_of 6 Spell.GRed)));
  check "SBRA is suppressed by 15 Fire banked, which costs it 30"
    (not (Spell_ai_manual.hook_sbra (ctx ~caster:(fire 15) ~board:(board_of 6 Spell.GRed) ())))

(* ------------------------------------------------------------------ *)
(* SDUP: the one hook that reads items                                  *)
(* ------------------------------------------------------------------ *)

(* SDUP is the only AI hook that calls GET_ITEM, and the earlier count of "twelve
   hooks read GET_ITEM" was wrong: it counted calls rather than scripts, and SDUP
   is the only spell script that mentions it at all.

   It casts only when some slot differs between the two sides and the enemy's is
   not empty. The bonus is then 50, or -100 when nothing is worth copying, and a
   -100 modifier needs a percentile at or below -50, which no roll can be, so that
   branch is an unconditional veto rather than merely unlikely. Worth pinning
   down: rewriting it as a plain veto would behave identically today but would
   quietly diverge if the percentile's range ever changed. *)
let () =
  let carrier = Item.new_loadout () in
  ignore (Item.equip carrier (Option.get (Item_hooks.item_of_id "IALS")));
  let bare = Item.new_loadout () in
  let same = ctx ~items:(Some carrier) ~enemy_items:(Some carrier) ~percentile:0 () in
  let enemy_only = ctx ~items:(Some bare) ~enemy_items:(Some carrier) ~percentile:0 () in
  let none = ctx ~items:(Some carrier) ~enemy_items:(Some bare) ~percentile:99 () in
  check "SDUP is unconditionally false when both sides hold the same item"
    (not (Spell_ai_manual.hook_sdup same));
  check "SDUP is unconditionally false when the enemy holds nothing"
    (not (Spell_ai_manual.hook_sdup none));
  check "SDUP fires when the enemy holds something the caster does not"
    (Spell_ai_manual.hook_sdup enemy_only)

(* ------------------------------------------------------------------ *)
(* The last two, and the two this file used to call unobtainable              *)
(* ------------------------------------------------------------------ *)

(** A board whose rows are given as skull counts, so [EvaluateRows]'s row scoring
    can be driven directly. Plain skulls count one and red skulls five.

    [of_array_matrix] reads [matrix.(y).(x)], so the writes are row-major too.
    Writing [cells.(x).(y)] puts the whole row down column zero instead, which
    looks almost right and scores every row as empty. *)
let rows_board (rows : (int * int) list) : Board.board =
  let cells = Array.make_matrix 8 8 Board.Empty in
  List.iteri
    (fun y (plain, red) ->
      let placed = ref 0 in
      for x = 0 to 7 do
        if !placed < plain then begin
          cells.(y).(x) <- Board.Skull;
          incr placed
        end
        else if !placed < plain + red then begin
          cells.(y).(x) <- Board.RedSkull;
          incr placed
        end
      done)
    rows;
  Board.of_array_matrix cells

let () =
  (* SCHG's EvaluateRows scores the best row and returns -20 below four skulls,
     five per skull above. Both directions matter: the hook vetoes when
     [chance < 50 - rowValue], so a crowded row makes the spell *easier* and a
     sparse one makes it much harder. *)
  check "EvaluateRows returns -20 on an empty board"
    (Spell_ai_manual.evaluate_rows_value (rows_board []) = -20);
  check "and -20 just under four skulls"
    (Spell_ai_manual.evaluate_rows_value (rows_board [ (3, 0) ]) = -20);
  check "four skulls is the first row that scores"
    (Spell_ai_manual.evaluate_rows_value (rows_board [ (4, 0) ]) = 20);
  check "a red skull counts five, so one red beats four plain"
    (Spell_ai_manual.evaluate_rows_value (rows_board [ (0, 1) ]) = 25);
  check "and the best row wins, not the first"
    (Spell_ai_manual.evaluate_rows_value (rows_board [ (2, 0); (5, 0) ]) = 25)

(** Both hooks are asked through one helper each, so the percentile and the
    evaluation are named once instead of at every call site. Nesting
    [hook (ctx ...)] inside [not] three deep is where the missing paren in this
    file went.

    The thresholds follow [ai_spellcasting_chance], which casts when
    [percentile <= 50 + modifier] - so a positive modifier makes a spell
    {e easier}, not harder. SCHG does its own arithmetic and lands on
    [percentile >= 50 - rowValue] instead. *)
let schg rows ~percentile ~evaluation =
  Spell_ai_manual.hook_schg (ctx ~board:(rows_board rows) ~percentile ~evaluation ())

let () =
  (* Four skulls score 20, so the gate is percentile 30. *)
  check "SCHG needs percentile 30 on a four-skull row"
    (not (schg [ (4, 0) ] ~percentile:29 ~evaluation:0));
  check "and fires at 30" (schg [ (4, 0) ] ~percentile:30 ~evaluation:0);
  check "SCHG on an empty board needs 70, the -20 branch"
    (not (schg [] ~percentile:69 ~evaluation:0));
  check "and fires there at 70" (schg [] ~percentile:70 ~evaluation:0);
  check "SCHG still refuses a good board, as every evaluate hook does"
    (not (schg [ (8, 0) ] ~percentile:0 ~evaluation:31))

let sfba rows percentile =
  Spell_ai_manual.hook_sfba (ctx ~board:(rows_board rows) ~percentile ())

let () =
  (* SFBA wants a skull on the board, and pays a flat 20 for a red one - which by
     [ai_spellcasting_chance] moves the threshold from 50 to 70. The [else] is the
     part to read twice: a board with only plain skulls pays nothing at all rather
     than something smaller, because the 20 is only added on the first search
     succeeding. *)
  check "SFBA refuses a board with no skulls" (not (sfba [] 0));
  check "SFBA pays 20 for a red skull, so the threshold is 70"
    (sfba [ (0, 1) ] 70);
  check "and not at 71" (not (sfba [ (0, 1) ] 71));
  check "SFBA pays nothing extra for a plain skull, so it needs 50"
    (sfba [ (4, 0) ] 50);
  check "and not at 51" (not (sfba [ (4, 0) ] 51))

let () =
  if !failures = 0 then print_endline "All spell hook tests passed."
  else begin
    Printf.printf "%d spell hook test(s) failed.\n" !failures;
    exit 1
  end
