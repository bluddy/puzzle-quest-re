(** Hand-ported item scripts.

    [tools/extract_items.ps1] generates the descriptors; the behaviour lives in
    each item's Lua and is ported here, the same split as spells.

    Only the hooks that can be reproduced with machinery the battle loop already
    has are ported. The rest are listed in [known_unported], each with the reason
    it cannot be written honestly. What is still left out is one thing: two
    natives with nothing behind them - `SUBTRACT_XP`, because experience is per
    character in the Lua and one battle total here (IALS), and
    `GET_CHARACTER_ID`, because a combatant carries no registry id (ILBC).

    Four absences used to shape this file and are gone. The board was the
    biggest: `SET_GEM`, `DESTROY_GEM` and the `GetRandomGrid_*` pickers reach
    into the grid from inside a hook, and nine bodies were out on that alone -
    IADO, ITHH, IUHA, ICAR, IDSH, INOB, ICOS, IMGS and ISES's xp half are in
    now, through the three board callbacks [Item.item_context] carries and the
    pickers [Item.get_random_grid] samples the grid with. Then `MISS_TURNS`,
    which lands as the [Missed] pseudo-status and is spent by
    [Battle.spend_missed_turn] between the worn items' start hooks and the
    status effects', so IFZT stuns the other side and ITUT's owner never acts.
    Then `PERCENTILE_CHANCE_SYNC`, which is [Item.item_context.ic_percentile]: a
    draw per call, what the native does, and what the sixteen rolled bodies were
    waiting for - the single-per-event read that made IBSH the standing example
    of an unported hook was a property of the old field, not of the engine. And
    `ADD_TEMP_SKILL`, which writes the skill array under a 999 cap and
    recomputes the ceilings from it ([Engine_ADD_TEMP_SKILL_4839f0]) rather than
    staging anything, so IGPK's gold and xp bodies and IGSH's are ordinary
    skill writes, the same call [Spell_effects] already makes.

    What is ported spans all eight kinds the scripts declare: OnGiveDamage
    51 of 53, OnReceiveDamage 38 of 38, OnReceiveMana 17 of 17, OnReceiveGold
    3 of 3, OnReceiveXP 6 of 6, OnStartTurn 9 of 9, OnMatch4/5 6 of 6 items,
    OnVictory 1 of 1, and the six OnStartBattle payoffs below - 131 of the 133
    declarations, the two above being the rest. The battle loop dispatches the
    six event kinds; both damage chains fold per event.

    Each entry keeps the Lua it came from, since these are short enough to check
    by eye and the thresholds are the whole behaviour. *)

open Combat
open Item

(** IAOM: minus one on a hit of two or more.

    ```lua
    if (damage > 1) then damage = damage - 1; NOTIFY_OF_ACTIVATED_ITEM(); end
    return damage
    ``` *)
let hook_iaom _ctx damage _source _target = if damage > 1 then damage - 1 else damage

(** IAOR: plus two on a hit of three or more. *)
let hook_iaor _ctx damage _source _target = if damage >= 3 then damage + 2 else damage

(** IBOI: plus four once there are eight or more red gems on the board. *)
let hook_iboi ctx damage _source _target =
  if item_red ctx >= 8 then damage + 4 else damage

(** The two arities a damage body has here. The three that came first take the
    Lua's four arguments in full; the ported families take only what they read
    - the context and the damage - and these wrappers put them back into the
    record's shape so the lookup tables stay one line per id. *)
let give (f : item_context -> int -> int) :
    (item_context -> int -> int -> int -> int) option =
  Some (fun ctx damage _source _target -> f ctx damage)

let give4 (f : item_context -> int -> int -> int -> int) :
    (item_context -> int -> int -> int -> int) option = Some f

let receive (f : item_context -> int -> int) :
    (item_context -> int -> int -> int -> int) option =
  Some (fun ctx damage _source _target -> f ctx damage)

let receive4 (f : item_context -> int -> int -> int -> int) :
    (item_context -> int -> int -> int -> int) option = Some f

(* ------------------------------------------------------------------ *)
(* OnGiveDamage                                                        *)
(* ------------------------------------------------------------------ *)

(** 47 of the 53 scripts that declare OnGiveDamage are ported. Most of them
    are one of a handful of shapes, so each shape is written once with its
    threshold as an argument and its id list in the comment - the threshold is
    the behaviour, and the scripts disagree about it (`>=` here, `>` there,
    and two bodies with no test at all).

    Every body takes (ctx, damage, sourceIdx, targetIdx) in the Lua's order.
    The port has no character indices: a body that wants the wearer reads
    [ic_self] and one that wants the other side reads [other_side], which is
    what [GET_ENEMY(sourceIdx, 0)] means for a one-on-one fight. The
    [ADD_EFFECT_TO_*] sparkle calls in most of these scripts are presentation
    and are dropped with [NOTIFY_OF_ACTIVATED_ITEM], which has no log event. *)

(** `if (damage >= t) then damage = damage + n`: IDAX +1, IGIM +4, ILAN +1,
    IMCL +3, IHRA +2, ISES +1, ISST +1. *)
let plus_at (t : int) (n : int) _ctx (damage : int) : int =
  if damage >= t then damage + n else damage

(** `if (damage > t) then damage = damage + n`: ITWH `> 2` +3, ITWS `> 1` +2. *)
let plus_above (t : int) (n : int) _ctx (damage : int) : int =
  if damage > t then damage + n else damage

(** `damage = damage + n` with no test at all: IFMO +1, ITSA +1, IIFI +2. *)
let bump (n : int) _ctx (damage : int) : int = damage + n

let hook_idax = plus_at 3 1
let hook_igim = plus_at 3 4
let hook_ilan = plus_at 3 1
let hook_imcl = plus_at 3 3
let hook_ihra = plus_at 3 2
let hook_ises = plus_at 3 1
let hook_isst_damage = plus_at 3 1
let hook_itwh = plus_above 2 3
let hook_itws = plus_above 1 2
(* Three of the damage bodies share a name with an event body further down -
   IFMO and ISST also carry OnReceiveMana, IDKH also carries OnReceiveDamage -
   and both lookup tables are written after everything else, so the damage
   halves are suffixed rather than left to depend on which definition wins. *)
let hook_ifmo_damage = bump 1
let hook_itsa = bump 1
let hook_iifi = bump 2

(* The three that write the grid. [ic_set_gem] and [ic_destroy_gem] are the
   battle's board behind the context, so a write survives the hook; the pick
   the Lua draws first is [get_random_grid], which samples the grid the context
   was built over. *)

(** IADO: +1 from three up, then every red skull off the grid with the
    multiplier flags down - [SetMultiplierEffects(false)] before the sweep and
    [true] after, GridUtilities.lua's own wrapper around the three
    SET_*_ENABLED calls. The sweep reads the grid the context started with. *)
let hook_iado ctx (damage : int) : int =
  if damage < 3 then damage
  else begin
    ctx.ic_multipliers false;
    destroy_all ctx Board.RedSkull;
    ctx.ic_multipliers true;
    damage + 1
  end

(** ITHH: +2 from three up, and one blue gem turned yellow at a cell
    [GetRandomGrid_Type(GEM_BLUE)] picked - a rejection sample, so the cell it
    comes back with is blue unless a thousand tries ran out, which the body
    re-checks before it writes. GEM_BLUE is Water, GEM_YELLOW is Air. *)
let hook_ithh ctx (damage : int) : int =
  if damage < 3 then damage
  else begin
    (match get_random_grid ctx (Of_type (Board.Mana Water)) with
    | Some p -> (
        match ctx.ic_board with
        | Some g when Board.get_gem g p = Board.Mana Water ->
            ctx.ic_set_gem p (Board.Mana Air)
        | _ -> ())
    | None -> ());
    damage + 2
  end

(** IUHA: +5 from three up, and a red gem turned into a skull the same way. *)
let hook_iuha ctx (damage : int) : int =
  if damage < 3 then damage
  else begin
    (match get_random_grid ctx (Of_type (Board.Mana Fire)) with
    | Some p -> (
        match ctx.ic_board with
        | Some g when Board.get_gem g p = Board.Mana Fire -> ctx.ic_set_gem p Board.Skull
        | _ -> ())
    | None -> ());
    damage + 5
  end

(** `damage + GET_MANA_<E>(sourceIdx)/k` behind `damage >= 3`. IBNS reads the
    Fire *skill* rather than the pool and divides it by three; IFWS the fire
    pool by eight; IHLA air by seven; ITEN water by three; ITWP earth by
    three; IUHL earth by seven. Lua's [/] truncates, so the pool is divided as
    an integer. *)
let plus_pool_over (t : int) (e : element) (k : int) ctx (damage : int) : int =
  if damage >= t then damage + (Combat.mana ctx.ic_self e) / k else damage

let hook_ibns ctx damage =
  if damage >= 3 then damage + (skill_in SFire ctx.ic_self.skills) / 3 else damage

let hook_ifws = plus_pool_over 3 Fire 8
let hook_ihla = plus_pool_over 3 Air 7
let hook_iten = plus_pool_over 3 Water 3
let hook_itwp = plus_pool_over 3 Earth 3
let hook_iuhl = plus_pool_over 3 Earth 7

(** ITWM: half of the largest pool, from a hit above one. The Lua's if/elseif
    chain compares all four with >=, so a tie pays the same amount whichever
    branch takes it. *)
let hook_itwm ctx (damage : int) : int =
  if damage <= 1 then damage
  else
    let largest = List.fold_left max min_int (List.map (fun e -> Combat.mana ctx.ic_self e) all_elements) in
    damage + largest / 2

(** `damage + CountGems(GEM_<C>)/2` from three up: IFBL counts blue, IVBL red.
    [count_gems] is the board as the item scripts see it - the whole grid, not
    what is left after the match under way. *)
let plus_gems_over (kind : gem_kind) (k : int) ctx (damage : int) : int =
  if damage >= 3 then damage + (count_gems kind ctx) / k else damage

let hook_ifbl = plus_gems_over GBlue 2
let hook_ivbl = plus_gems_over GRed 2

(** IBST: +4 for each reserve of the wearer's four that sits at its ceiling. *)
let hook_ibst ctx (damage : int) : int =
  if damage < 3 then damage
  else
    damage
    + (4 * List.length (List.filter (fun e -> Combat.mana_at_limit ctx.ic_self e) all_elements))

(** IRKT: times one and a half for each full reserve, up to four times. Lua
    keeps the running product as a float and the engine truncates the return
    once, so the multiply happens in float here too rather than once per
    pool - five doubled-and-a-halfed twice is 11, not 10. *)
let hook_irkt ctx (damage : int) : int =
  let times =
    List.length (List.filter (fun e -> Combat.mana_at_limit ctx.ic_self e) all_elements)
  in
  let d = ref (float_of_int damage) in
  for _ = 1 to times do
    d := !d *. 1.5
  done;
  int_of_float !d

(** IHOF: +5 on a hit of three or more with twenty water in hand. *)
let hook_ihof ctx (damage : int) : int =
  if damage >= 3 && Combat.mana ctx.ic_self Water >= 20 then damage + 5 else damage

(** IHAL: double the damage against a foe under a quarter of its max life. The
    Lua divides the max life first, so the comparison is against the truncated
    quarter. *)
let hook_ihal ctx (damage : int) : int =
  let foe = other_side ctx in
  if Combat.life foe < Combat.max_life foe / 4 then damage * 2 else damage

(** IEBW: +1 plus a point per eight levels of the wearer. The battle carries
    the hero's level and no other, so an enemy-worn copy - which the campaign
    never makes - reads [None] and adds the flat one. *)
let hook_iebw ctx (damage : int) : int =
  if damage < 3 then damage
  else damage + 1 + (match ctx.ic_level with Some l -> l / 8 | None -> 0)

(* Mana moved by a damage event, which is the second big family. *)

(** ICBO: +1 damage and one air, from three up. The Lua's sparkle names an
    undefined [characterIdx], so half of that body never ran even in the
    original. *)
let hook_icbo ctx (damage : int) : int =
  if damage >= 3 then begin
    ctx.ic_credit_mana Air 1;
    damage + 1
  end
  else damage

(** IELB: two air and two earth from a hit of two or more, damage untouched.
    ILBW: three air from three up. ISPC: two fire from five up. IWLC: a third
    of the damage into earth, on every hit. *)
let hook_ielb ctx (damage : int) : int =
  if damage >= 2 then begin
    ctx.ic_credit_mana Air 2;
    ctx.ic_credit_mana Earth 2
  end;
  damage

let hook_ilbw ctx (damage : int) : int =
  if damage >= 3 then ctx.ic_credit_mana Air 3;
  damage

let hook_ispc ctx (damage : int) : int =
  if damage >= 5 then ctx.ic_credit_mana Fire 2;
  damage

let hook_iwlc ctx (damage : int) : int =
  let n = damage / 3 in
  if n > 0 then ctx.ic_credit_mana Earth n;
  damage

(** The drains: mana taken off the other side and credited to the wearer.
    IDCW takes two air and adds three damage; IHCL takes a third of the damage
    as fire *and* air and gives both back; IORM takes two fire and changes
    nothing else; IWBL takes up to five of the target's fire and credits the
    same number as water. *)
let hook_idcw ctx (damage : int) : int =
  if damage < 3 then damage
  else begin
    Combat.spend_mana (other_side ctx) Air 2;
    ctx.ic_credit_mana Air 2;
    damage + 3
  end

let hook_ihcl ctx (damage : int) : int =
  if damage < 3 then damage
  else begin
    let amt = damage / 3 in
    let foe = other_side ctx in
    Combat.spend_mana foe Fire amt;
    Combat.spend_mana foe Air amt;
    ctx.ic_credit_mana Fire amt;
    ctx.ic_credit_mana Air amt;
    damage
  end

let hook_iorm ctx (damage : int) : int =
  if damage >= 3 then Combat.spend_mana (other_side ctx) Fire 2;
  damage

let hook_iwbl ctx (damage : int) : int =
  if damage < 3 then damage
  else begin
    let foe = other_side ctx in
    let red = min 5 (Combat.mana foe Fire) in
    if red > 0 then begin
      Combat.spend_mana foe Fire red;
      ctx.ic_credit_mana Water red
    end;
    damage
  end

(* Turns, life and levels. *)

(** IMAX: an extra turn from a hit of five or more. IGAX is the same thing
    behind a coin flip, below. *)
let hook_imax ctx (damage : int) : int =
  if damage >= 5 then ctx.ic_extra_turn ();
  damage

(** ISTA: [Std_Healing(2, sourceIdx)] from four up - two points of life on the
    wearer. *)
let hook_ista ctx (damage : int) : int =
  if damage >= 4 then ctx.ic_heal 2;
  damage

(** IGKR: a point of max life and a point of life per four damage, ceiling
    first, the way the IWL* walls do it. *)
let hook_igkr ctx (damage : int) : int =
  if damage < 4 then damage
  else begin
    let n = damage / 4 in
    let self = ctx.ic_self in
    self.max_life <- self.max_life + n;
    self.life <- self.life + n;
    damage
  end

(* The percentile bodies. [ic_percentile] is [PERCENTILE_CHANCE_SYNC] as a
   draw-per-call closure, so a roll is spent only where the Lua spends one -
   and two of these worn together get two rolls each, which the single-draw
   reading that kept them unported would have denied them. *)

(** IDCL: twelve extra damage on a hit above one, one roll in twenty. *)
let hook_idcl ctx (damage : int) : int =
  if ctx.ic_percentile () <= 20 && damage > 1 then damage + 12 else damage

(** IFZT: from two up, and a roll at or under the wearer's own water pool, two
    turns stunned on the target - [MISS_TURNS(targetIdx, 2)], which the loop
    spends as [Missed]. The stun message and sound go with every other
    notification this file drops. *)
let hook_ifzt ctx (damage : int) : int =
  if damage >= 2 && ctx.ic_percentile () <= Combat.mana ctx.ic_self Water then
    ctx.ic_miss_turns (other_side ctx) 2;
  damage

(** IGAX: an extra turn on a hit of five or more, one roll in two. *)
let hook_igax ctx (damage : int) : int =
  if damage >= 5 && ctx.ic_percentile () <= 50 then ctx.ic_extra_turn ();
  damage

(** IGMA: one roll in four drains the target's whole fire pool. *)
let hook_igma ctx (damage : int) : int =
  if damage >= 3 && ctx.ic_percentile () <= 25 then begin
    let foe = other_side ctx in
    Combat.spend_mana foe Fire (Combat.mana foe Fire)
  end;
  damage

(** The poison family: a flat add on the damage, and then a roll that lands
    Poison (EPOI) on the target. IFNG adds four from six up and rolls at 25%;
    IHST adds six from two up and ISTG two, both at 80%. The two ifs are
    independent in the Lua, so the roll happens whatever the damage was. *)
let hook_poisoned ~(at : int) ~(add : int) ~(pct : int) ctx (damage : int) : int =
  let damage = if damage >= at then damage + add else damage in
  if ctx.ic_percentile () <= pct then ctx.ic_apply_status (other_side ctx) "EPOI";
  damage

let hook_ifng = hook_poisoned ~at:6 ~add:4 ~pct:25
let hook_ihst = hook_poisoned ~at:2 ~add:6 ~pct:80
let hook_istg = hook_poisoned ~at:2 ~add:2 ~pct:80

(** IZCL: +1 on every hit, and one roll in two lands Disease (STATUS_EFFECT_DISEASE). *)
let hook_izcl ctx (damage : int) : int =
  if ctx.ic_percentile () <= 50 then ctx.ic_apply_status (other_side ctx) "EDIS";
  damage + 1

(* ------------------------------------------------------------------ *)
(* OnReceiveDamage                                                     *)
(* ------------------------------------------------------------------ *)

(** 35 of the 38 scripts that declare OnReceiveDamage are ported, and 34 of
    those are the same two shapes: the minus-one arm and whatever gates it.
    [hook_iaom] above is the ungated one. *)

(** `if (damage > 1) then damage = damage - 1`, which is IDKA, IDKH, IFPA,
    IFPB and IFPH. *)
let minus_one _ctx (damage : int) : int = if damage > 1 then damage - 1 else damage

(** The same minus-one behind `PERCENTILE_CHANCE_SYNC() <= pct`: IBSH 10,
    ILEA / ILEB / ILEH 25, ICMA / ICMB / ICMH 50, IGTW / ISCA / ISCB / ISCH
    75. IBSH is the one that was left unported as the standing example of what
    a per-call roll meant for a port - the context draws one now. *)
let minus_one_at (pct : int) ctx (damage : int) : int =
  if ctx.ic_percentile () <= pct then minus_one ctx damage else damage

let hook_idkh_damage = minus_one
let hook_idka = minus_one
let hook_ifpa = minus_one
let hook_ifpb = minus_one
let hook_ifph = minus_one
let hook_ibsh = minus_one_at 10
let hook_ilea = minus_one_at 25
let hook_ileb = minus_one_at 25
let hook_ileh = minus_one_at 25
let hook_icma = minus_one_at 50
let hook_icmb = minus_one_at 50
let hook_icmh = minus_one_at 50
let hook_igtw = minus_one_at 75
let hook_isca = minus_one_at 75
let hook_iscb = minus_one_at 75
let hook_isch = minus_one_at 75

(** IGTA and IGTI are the same arm with a bigger cut at the same 75%: four
    points off above four, three off above three. *)
let hook_igta ctx (damage : int) : int =
  if ctx.ic_percentile () <= 75 && damage > 4 then damage - 4 else damage

let hook_igti ctx (damage : int) : int =
  if ctx.ic_percentile () <= 75 && damage > 3 then damage - 3 else damage

(** IGTS is the same arm at 75% again: two points off above two. *)
let hook_igts ctx (damage : int) : int =
  if ctx.ic_percentile () <= 75 && damage > 2 then damage - 2 else damage

(** IDSC: nothing gets through a hit of two or less. *)
let hook_idsc _ctx (damage : int) : int = if damage <= 2 then 0 else damage

(** IIMH: one roll in twenty at two or more turns the hit into a single point. *)
let hook_iimh ctx (damage : int) : int =
  if damage >= 2 && ctx.ic_percentile () < 20 then 1 else damage

(** IRSA: five points off a hit of ten or more. *)
let hook_irsa _ctx (damage : int) : int = if damage >= 10 then damage - 5 else damage

(** IELP: one roll in eighty turns a hit above one into one point less and
    credits two earth. IISK: the same minus-one, unconditionally, plus one
    earth whatever the damage was. *)
let hook_ielp ctx (damage : int) : int =
  if ctx.ic_percentile () <= 80 && damage > 1 then begin
    ctx.ic_credit_mana Earth 2;
    damage - 1
  end
  else damage

let hook_iisk ctx (damage : int) : int =
  ctx.ic_credit_mana Earth 1;
  minus_one ctx damage

(** IROS: half the damage, rounded down, back as earth and fire - and no
    change to the damage itself. ISPS: one of each element from three up.
    ISSA: a quarter of the damage in each, from four up. *)
let hook_iros ctx (damage : int) : int =
  let n = damage / 2 in
  if n >= 1 then begin
    ctx.ic_credit_mana Earth n;
    ctx.ic_credit_mana Fire n
  end;
  damage

let hook_isps ctx (damage : int) : int =
  if damage >= 3 then
    List.iter (fun e -> ctx.ic_credit_mana e 1) all_elements;
  damage

let hook_issa ctx (damage : int) : int =
  if damage >= 4 then begin
    let n = damage / 4 in
    List.iter (fun e -> ctx.ic_credit_mana e n) all_elements
  end;
  damage

(** IHCR: +1 air resistance from a hit of five - the same straight write the
    companion pass and ICSA make, and nothing reads resistances back yet. *)
let hook_ihcr ctx (damage : int) : int =
  if damage >= 5 then Combat.add_resistance ctx.ic_self Air 1;
  damage

(** IIAM: two experience from a hit of two or more, through the xp hook. *)
let hook_iiam ctx (damage : int) : int =
  if damage >= 2 then ctx.ic_credit_xp 2;
  damage

(** IGSH: a point of Battle skill from a hit of two or more. ADD_TEMP_SKILL is
    not staged - [Engine_ADD_TEMP_SKILL] writes the skill array under a 999
    cap and recomputes the elemental mana ceilings from it - and [Spell_effects]
    already models it as the same straight add this makes. *)
let hook_igsh ctx (damage : int) : int =
  if damage >= 2 then
    ctx.ic_self.skills <- Combat.add_skill SBattle 1 ctx.ic_self.skills;
  damage

(** The reflect family - IMAR, IMHE and IMSH are the same body three times:
    a hit above one costs the attacker one point of life. The Lua guards on
    [sourceIdx ~= targetIdx] and then reads both characters' map positions for
    a lightning effect; a battle here is two different combatants, so the guard
    is always true, and the lightning is presentation. [ic_inflict_damage]
    already means "damage the other side", which for a receive hook is the
    attacker. *)
let hook_reflect ctx (damage : int) : int =
  if damage > 1 then ctx.ic_inflict_damage 1;
  damage

let hook_imar = hook_reflect
let hook_imhe = hook_reflect
let hook_imsh = hook_reflect

(** ISCL: a hit of two or more strips two of each element from the attacker. *)
let hook_iscl ctx (damage : int) : int =
  if damage >= 2 then
    List.iter (fun e -> Combat.spend_mana (other_side ctx) e 2) all_elements;
  damage

(* The three receive bodies that write the grid. *)

(** ICAR: the ordinary minus-one, and - only where it bit - a red gem grown at
    a cell [GetRandomGrid_Isolated(GEM_RED)] picked: not red itself, with no
    red neighbour, and not empty by the time the write lands. *)
let hook_icar ctx (damage : int) : int =
  if damage > 1 then begin
    (match get_random_grid ctx (Isolated [ Board.Mana Fire ]) with
    | Some p -> (
        match ctx.ic_board with
        | Some g when Board.get_gem g p <> Board.Empty -> ctx.ic_set_gem p (Board.Mana Fire)
        | _ -> ())
    | None -> ());
    damage - 1
  end
  else damage

(** IDSH: a red skull per eight points of damage, up to three since the wearer's
    last turn - [IDSH_numSkulls] in the Lua, which is a table keyed by character
    and reset from this item's own [OnStartTurn]. The count is [damage / 8] in
    Lua and therefore a fraction: it accumulates fractionally, the cap test reads
    it fractionally, and the loop over it runs for every whole number in it, which
    is what [int_of_float] gives. The cell it writes has to be none of skull, red
    skull or empty, and is re-checked because a thousand failed tries would hand
    back the last draw anyway. *)
let hook_idsh ctx (damage : int) : int =
  let self = ctx.ic_self in
  let count = item_state_get self "IDSH" in
  let num = float_of_int damage /. 8.0 in
  let num = if num +. count > 3.0 then 3.0 -. count else num in
  item_state_set self "IDSH" (count +. num);
  if num > 0.0 && damage >= 8 then begin
    for _ = 1 to int_of_float num do
      match get_random_grid ctx (Not [ Board.Skull; Board.RedSkull; Board.Empty ]) with
      | Some p -> (
          match ctx.ic_board with
          | Some g when Board.get_gem g p <> Board.Empty -> ctx.ic_set_gem p Board.RedSkull
          | _ -> ())
      | None -> ()
    done
  end;
  damage

(** INOB: two red skulls at twelve or more, capped at two since the last turn,
    behind the same per-character counter. The Lua's inner loop runs [amt] times
    with no emptiness check - [GetRandomGrid_Not3] already excludes empty - and
    gives up after a thousand tries, which is the loop unwound here. *)
let hook_inob ctx (damage : int) : int =
  let self = ctx.ic_self in
  let count = item_state_get self "INOB" in
  let num = if damage >= 12 then 2.0 else 0.0 in
  let num = if num +. count > 2.0 then 2.0 -. count else num in
  item_state_set self "INOB" (count +. num);
  if num > 0.0 then begin
    for _ = 1 to int_of_float num do
      match get_random_grid ctx (Not [ Board.Skull; Board.RedSkull; Board.Empty ]) with
      | Some p -> ctx.ic_set_gem p Board.RedSkull
      | None -> ()
    done
  end;
  damage

(* ------------------------------------------------------------------ *)
(* OnReceiveMana                                                       *)
(* ------------------------------------------------------------------ *)

(** The seventeen scripts that declare OnReceiveMana, all portable: five are
    pure value transforms, eight credit a second pool or bank gold through a
    callback the battle binds, two add a resistance straight onto their own
    combatant, and two deal damage to the {e other} side.

    MANA_YELLOW/BLUE/RED/GREEN are Air/Water/Fire/Earth - the game's colour
    names, and the same mapping [gem_kind_of_board] pins. StandardConstants.lua
    gives the raw mana ids too, and the four IRO* rings are the only bodies that
    compare against the number rather than the name:
    MANA_GREEN = 0 (Earth), MANA_RED = 1 (Fire), MANA_YELLOW = 2 (Air),
    MANA_BLUE = 3 (Water) - which is also [Combat.skill_of_index]'s order and
    [Battle.element_index]'s. The rings are written with the element rather than
    the number, so the index never has to be trusted twice. Lua's [/] truncates
    toward zero for these values the same way OCaml's integer division does,
    which is what makes [value / 2] a transcription. *)

(** IBFH: half of a red credit, rounded down, into Earth. *)
let hook_ibfh ctx (value : int) (e : element) : int =
  if e = Fire then begin
    let extra = value / 2 in
    if extra > 0 then ctx.ic_credit_mana Earth extra
  end;
  value

(** IDKH: +2 on green. *)
let hook_idkh _ctx (value : int) (e : element) : int = if e = Earth then value + 2 else value

(** IFMO: double red. *)
let hook_ifmo _ctx (value : int) (e : element) : int = if e = Fire then value * 2 else value

(** IJAC: +2 on blue. *)
let hook_ijac _ctx (value : int) (e : element) : int = if e = Water then value + 2 else value

(** IJAH: 2 damage to the other side on a blue credit of two or more. *)
let hook_ijah ctx (value : int) (e : element) : int =
  if e = Water && value >= 2 then ctx.ic_inflict_damage 2;
  value

(** IJOB: one each of Air, Earth and Water on a red credit of two or more. *)
let hook_ijob ctx (value : int) (e : element) : int =
  if e = Fire && value >= 2 then begin
    ctx.ic_credit_mana Air 1;
    ctx.ic_credit_mana Earth 1;
    ctx.ic_credit_mana Water 1
  end;
  value

(** IJOH: +1 Fire resistance on a red credit of three or more. *)
let hook_ijoh ctx (value : int) (e : element) : int =
  if e = Fire && value >= 3 then Combat.add_resistance ctx.ic_self Fire 1;
  value

(** IMOA: double blue. *)
let hook_imoa _ctx (value : int) (e : element) : int = if e = Water then value * 2 else value

(** IRKA: 3 gold on a blue credit - through the gold hook, so a Ruby Ring worn
    alongside it would triple that too, as the natives would. *)
let hook_irka ctx (value : int) (e : element) : int =
  if e = Water then ctx.ic_credit_gold 3;
  value

(** The four IRO* rings: a third of a credit in {e one} element, rounded down,
    into {e another} - "3 Green Mana gives 1 yellow" is IROA's own description,
    and the trigger element is not the one that gets paid. That re-enters the
    mana fold, because [Combat]'s ADD_MANA native would fire OnReceiveMana
    again, and the four of them together form a cycle (Fire pays Earth, Earth
    pays Air, Air pays Water, Water pays Fire). It terminates anyway: every hop
    divides by three, so the offer reaches zero after finitely many turns round
    the ring, with the value hooks that add flat amounts (+2 green from IDKH,
    +1 from IJOB) unable to outpace a division by three. *)
let hook_ring ~(trigger : element) ~(credit : element) ctx (value : int)
    (e : element) : int =
  if e = trigger then begin
    let extra = value / 3 in
    if extra > 0 then ctx.ic_credit_mana credit extra
  end;
  value

let hook_iroa = hook_ring ~trigger:Earth ~credit:Air
let hook_iroe = hook_ring ~trigger:Fire ~credit:Earth
let hook_irof = hook_ring ~trigger:Water ~credit:Fire
let hook_irow = hook_ring ~trigger:Air ~credit:Water

(** ISOA: +1 Air resistance on an air credit of three or more. *)
let hook_isoa ctx (value : int) (e : element) : int =
  if e = Air && value >= 3 then Combat.add_resistance ctx.ic_self Air 1;
  value

(** ISST: +1 on green. *)
let hook_isst _ctx (value : int) (e : element) : int = if e = Earth then value + 1 else value

(** ISTL: 1-10 damage to the other side on a red credit of three or more.
    [GET_RANDOM_SYNC(1,10)] is inclusive at both ends, so the 0-based
    [ic_roll 10] is shifted up one. *)
let hook_istl ctx (value : int) (e : element) : int =
  if e = Fire && value >= 3 then ctx.ic_inflict_damage (1 + ctx.ic_roll 10);
  value

(** IWHP: 1 damage to the other side on an air credit. *)
let hook_iwhp ctx (value : int) (e : element) : int =
  if e = Air then ctx.ic_inflict_damage 1;
  value

(* ------------------------------------------------------------------ *)
(* OnReceiveGold / OnReceiveXP                                         *)
(* ------------------------------------------------------------------ *)

(** IRBR: triple the gold. *)
let hook_irbr _ctx (value : int) : int = value * 3

(** IXHD: an extra turn on any gold. The [EXTRATURN] text message has no log
    event of its own; the turn itself lands on the turn manager. *)
let hook_ixhd ctx (value : int) : int =
  ctx.ic_extra_turn ();
  value

(** IALR: a third of the xp, rounded down, into each of the four pools. *)
let hook_ialr ctx (value : int) : int =
  if value >= 3 then begin
    let mana = value / 3 in
    ctx.ic_credit_mana Air mana;
    ctx.ic_credit_mana Earth mana;
    ctx.ic_credit_mana Fire mana;
    ctx.ic_credit_mana Water mana
  end;
  value

(** IAOB: the whole xp again, as Fire. *)
let hook_iaob ctx (value : int) : int =
  ctx.ic_credit_mana Fire value;
  value

(** IMSE: double the xp. *)
let hook_imse _ctx (value : int) : int = value * 2

(** ISKT: +2 Earth on any xp. *)
let hook_iskt ctx (value : int) : int =
  ctx.ic_credit_mana Earth 2;
  value

(** IGPK: whatever gold or xp arrives is converted into the same number of
    points in one randomly chosen skill - [GET_RANDOM_SYNC(0,6)] over the
    seven, which [skill_of_index] already numbers the engine's way. The xp
    half returns zero, so the experience is consumed rather than banked, which
    is the whole of its difference from the gold half. The [IS_GAME_OVER]
    guards are dropped with the text messages: these hooks only run while a
    fight is in progress, which is exactly when that native is false. *)
let hook_igpk ctx (value : int) : int =
  let k = skill_of_index (ctx.ic_roll 7) in
  ctx.ic_self.skills <- Combat.add_skill k value ctx.ic_self.skills;
  value

let hook_igpk_xp ctx (value : int) : int =
  ignore (hook_igpk ctx value);
  0

(** ISES's xp half: one roll in two grows a skull out of a cell
    [GetRandomGrid_Isolated2(GEM_SKULL, GEM_STAR)] picked. The body re-checks
    the cell after the pick, as the Lua does - the picker hands back its last
    draw when a thousand tries fail, and that draw can be a star or a skull. *)
let hook_ises_xp ctx (value : int) : int =
  if ctx.ic_percentile () <= 50 then
    (match get_random_grid ctx (Isolated [ Board.Skull; Board.Experience ]) with
    | Some p -> (
        match ctx.ic_board with
        | Some g
          when Board.get_gem g p <> Board.Experience && Board.get_gem g p <> Board.Skull
          ->
            ctx.ic_set_gem p Board.Skull
        | _ -> ())
    | None -> ());
  value

(* ------------------------------------------------------------------ *)
(* OnStartTurn                                                         *)
(* ------------------------------------------------------------------ *)

(** IEGM: every full reserve pays +2 into all four pools. [GET_MAX_MANA_*] is
    the ceiling on the combatant, which is what makes this - and the other
    start-turn bodies below - portable now that ceilings exist. *)
let hook_iegm ctx (_turn : int) : unit =
  let self = ctx.ic_self in
  let full e = Combat.mana self e >= Combat.max_mana self e in
  let num_full = List.length (List.filter full [ Air; Earth; Fire; Water ]) in
  if num_full > 0 then
    let n = num_full * 2 in
    List.iter (fun e -> ctx.ic_credit_mana e n) [ Air; Earth; Fire; Water ]

(** ISDO: +1 Water while the pool is not full. *)
let hook_isdo ctx (_turn : int) : unit =
  let self = ctx.ic_self in
  if Combat.mana self Water < Combat.max_mana self Water then ctx.ic_credit_mana Water 1

(** The three troll rings: a little life each turn while the Water pool sits at
    or above its threshold and there is life to heal. [ITRG] and [ITRU] clamp
    the amount themselves in Lua; [ITRI] does not, because ADD_LIFE already
    stops at the ceiling - which is the one reading all three share. *)
let hook_troll_ring (need : int) (amount : int) ctx (_turn : int) : unit =
  let self = ctx.ic_self in
  if
    self.life > 0 && self.life < self.max_life
    && Combat.mana self Water >= need
  then ctx.ic_heal amount

let hook_itrg = hook_troll_ring 9 2
let hook_itri = hook_troll_ring 6 1
let hook_itru = hook_troll_ring 12 3

(** ICOS: a skull at a cell [GetRandomGrid_Isolated2(5,15)] picked, from the
    second turn and on a roll under fifty. The two raw ids are skull and red
    skull - 5 and 15, which both candidate orderings for the gem ids agree on -
    and "isolated" means the cell is neither and has neither beside it. *)
let hook_icos ctx (turn : int) : unit =
  if turn > 1 && ctx.ic_percentile () < 50 then
    match get_random_grid ctx (Isolated [ Board.Skull; Board.RedSkull ]) with
    | Some p -> ctx.ic_set_gem p Board.Skull
    | None -> ()

(** IDSH's and INOB's whole [OnStartTurn]: the reset of the counter their
    damage halves accumulate since the wearer's last turn. The key is the item
    id, so the two never touch each other's. *)
let hook_reset_counter (key : string) ctx (_turn : int) : unit =
  item_state_set ctx.ic_self key 0.0

(** ITUT: [MISS_TURNS(characterIdx,1)] on the wearer's own turn start - the
    whole of "Owner never takes a turn", because [Battle.spend_missed_turn]
    runs immediately after these hooks and spends it before anything happens. *)
let hook_itut ctx (_turn : int) : unit = ctx.ic_miss_turns ctx.ic_self 1

let hook_idsh_start = hook_reset_counter "IDSH"
let hook_inob_start = hook_reset_counter "INOB"

(* ------------------------------------------------------------------ *)
(* OnMatch4 / OnMatch5 / OnVictory                                     *)
(* ------------------------------------------------------------------ *)

(** ICSA: +2 (match4) or +5 (match5) to all four resistances. The resistance
    slots exist on the combatant - the companion pass and [SSAN] write them the
    same way - even though nothing recovered reads them back yet. *)
let hook_icsa (n : int) ctx : unit =
  List.iter (fun e -> Combat.add_resistance ctx.ic_self e n) [ Air; Earth; Fire; Water ]

(** IRKK: +5 to all four pools on either event - its match5 body is a call to
    its own match4. *)
let hook_irkk ctx : unit = List.iter (fun e -> ctx.ic_credit_mana e 5) [ Air; Earth; Fire; Water ]

(** ISRI: clear every status effect. *)
let hook_isri ctx : unit = ctx.ic_self.effects <- []

(** IWBC: +1 Water resistance. *)
let hook_iwbc ctx : unit = Combat.add_resistance ctx.ic_self Water 1

(** IUSI: 15 healing on a five-match. *)
let hook_iusi ctx : unit = ctx.ic_heal 15

(** IMGS: [DestroyAllGems(GEM_STAR, ...)] on either event - every experience
    star off the grid, empties left for the cascade's own refill to fill. *)
let hook_imgs ctx : unit = destroy_all ctx Board.Experience

(** IHTR: +50 xp on victory, through the xp hook so the rest of the loadout
    sees it the way any other experience would. *)
let hook_ihtr ctx : unit = ctx.ic_credit_xp 50

(** [SET_ITEM(idx, n, id)`, the other half of SDUP's item duplication: copies the
    item id out of the enemy into one of the caster's slots, displacing whatever
    was there.

    Lives here rather than in [Item] because it needs [Item_data] to turn an id
    back into an item, and [Item_data] depends on [Item]. That dependency is the
    reason [Item.get_item_slot] can read a slot but not write one. *)
let set_item_slot (l : loadout) (n : int) (id : string) : Item.item option =
  match Item_data.descriptor_of id with
  | None -> None
  | Some d -> Item.equip_at l n (make_item d)

(** The item in a slot, as [GET_ITEM] reports it: the id, or [""] when empty. *)
let get_item_slot (l : loadout) (n : int) : string = Option.value (Item.get_item_slot l n) ~default:""

(** SDUP's item duplication, which is the only place in the whole asset set that
    reads [GET_ITEM] or calls [SET_ITEM].

    ```lua
    local idxEnemy = GET_ENEMY(idxCaster,0);
    if (GET_ITEM(idxEnemy,0) ~= GET_ITEM(idxCaster,0) and GET_ITEM(idxEnemy,0) ~= "") then
      legalList[legalListSize] = 0; legalListSize = legalListSize + 1;
    end
    -- ...same for slots 1, 2 and 3...
    if (legalListSize > 0) then
      local myChoice = GET_RANDOM_SYNC(0,legalListSize-1);
      local myItem = legalList[myChoice];
      SET_ITEM(idxCaster,myItem,GET_ITEM(idxEnemy,myItem));
    end
    ```

    So it builds the list of slots where the enemy has something the caster does
    not, then picks one at random. Returns the slot it copied into, or [None] when
    there was nothing worth copying.

    Written here rather than alongside SDUP's hook so the [GET_ITEM] and [SET_ITEM]
    halves are live and tested rather than dead code awaiting the spell's port. *)
let duplicate_item ~(caster : loadout) ~(enemy : loadout) ~(roll : int -> int) =
  let candidates =
    List.filter_map
      (fun n ->
        let theirs = Item.get_item_slot enemy n in
        let ours = Item.get_item_slot caster n in
        (* The Lua tests `~= ""` and `~=` against the caster's own slot. *)
        if theirs <> ours && theirs <> Some "" then Some (n, theirs) else None)
      [ 0; 1; 2; 3 ]
  in
  match candidates with
  | [] -> None
  | _ ->
      let n, id = List.nth candidates (roll (List.length candidates)) in
      ignore (set_item_slot caster n (Option.value id ~default:""));
      Some n


let hook_of = function
  | "IADO" -> give hook_iado
  | "IAOR" -> give4 hook_iaor
  | "IBOI" -> give4 hook_iboi
  | "IBNS" -> give hook_ibns
  | "IBST" -> give hook_ibst
  | "ICBO" -> give hook_icbo
  | "IDAX" -> give hook_idax
  | "IDCL" -> give hook_idcl
  | "IDCW" -> give hook_idcw
  | "IEBW" -> give hook_iebw
  | "IELB" -> give hook_ielb
  | "IFBL" -> give hook_ifbl
  | "IFMO" -> give hook_ifmo_damage
  | "IFNG" -> give hook_ifng
  | "IFWS" -> give hook_ifws
  | "IGAX" -> give hook_igax
  | "IGIM" -> give hook_igim
  | "IGKR" -> give hook_igkr
  | "IGMA" -> give hook_igma
  | "IHAL" -> give hook_ihal
  | "IHCL" -> give hook_ihcl
  | "IHLA" -> give hook_ihla
  | "IHOF" -> give hook_ihof
  | "IHRA" -> give hook_ihra
  | "IHST" -> give hook_ihst
  | "IFZT" -> give hook_ifzt
  | "IIFI" -> give hook_iifi
  | "ITHH" -> give hook_ithh
  | "IUHA" -> give hook_iuha
  | "ILAN" -> give hook_ilan
  | "ILBW" -> give hook_ilbw
  | "IMAX" -> give hook_imax
  | "IMCL" -> give hook_imcl
  | "IORM" -> give hook_iorm
  | "IRKT" -> give hook_irkt
  | "ISES" -> give hook_ises
  | "ISPC" -> give hook_ispc
  | "ISST" -> give hook_isst_damage
  | "ISTA" -> give hook_ista
  | "ISTG" -> give hook_istg
  | "ITEN" -> give hook_iten
  | "ITSA" -> give hook_itsa
  | "ITWH" -> give hook_itwh
  | "ITWM" -> give hook_itwm
  | "ITWP" -> give hook_itwp
  | "ITWS" -> give hook_itws
  | "IUHL" -> give hook_iuhl
  | "IVBL" -> give hook_ivbl
  | "IWBL" -> give hook_iwbl
  | "IWLC" -> give hook_iwlc
  | "IZCL" -> give hook_izcl
  | _ -> None

(** The ported [OnReceiveDamage] hooks by item id: all 38 scripts that
    declare it. IAOM is here rather than above because its Lua declares the
    body under OnReceiveDamage - "`sourceIdx` = attacker, `targetIdx` = me" -
    and an earlier version installed it as OnGiveDamage, which made the Armor
    of Minogoth subtract from the hits it dealt instead of the hits it took.
    The three that are not ported are in [known_unported]. *)
let hook_receive_of = function
  | "IAOM" -> give4 hook_iaom
  | "ICAR" -> receive hook_icar
  | "IBSH" -> receive hook_ibsh
  | "ICMA" -> receive hook_icma
  | "ICMB" -> receive hook_icmb
  | "ICMH" -> receive hook_icmh
  | "IDKA" -> receive hook_idka
  | "IDKH" -> receive hook_idkh_damage
  | "IDSC" -> receive hook_idsc
  | "IDSH" -> receive hook_idsh
  | "IELP" -> receive hook_ielp
  | "IFPA" -> receive hook_ifpa
  | "IFPB" -> receive hook_ifpb
  | "IFPH" -> receive hook_ifph
  | "IGSH" -> receive hook_igsh
  | "IGTA" -> receive hook_igta
  | "IGTI" -> receive hook_igti
  | "IGTS" -> receive hook_igts
  | "IGTW" -> receive hook_igtw
  | "IHCR" -> receive hook_ihcr
  | "IIAM" -> receive hook_iiam
  | "IIMH" -> receive hook_iimh
  | "IISK" -> receive hook_iisk
  | "ILEA" -> receive hook_ilea
  | "ILEB" -> receive hook_ileb
  | "ILEH" -> receive hook_ileh
  | "IMAR" -> receive hook_imar
  | "IMHE" -> receive hook_imhe
  | "IMSH" -> receive hook_imsh
  | "INOB" -> receive hook_inob
  | "IROS" -> receive hook_iros
  | "IRSA" -> receive hook_irsa
  | "ISCA" -> receive hook_isca
  | "ISCB" -> receive hook_iscb
  | "ISCH" -> receive hook_isch
  | "ISCL" -> receive hook_iscl
  | "ISPS" -> receive hook_isps
  | "ISSA" -> receive hook_issa
  | _ -> None

(** The ported event hooks by item id: one row per id that declares any of the
    six kinds the battle loop dispatches, with only the fields it implements
    filled in. Damage is merged in separately by [hooks_of_id], which is why the
    three damage entries above are not repeated here.

    Two ids declare more than one kind - IGPK gold and xp, and the five items
    that hook both match sizes - so this is a table of records rather than one
    lookup per kind. *)
let event_hooks : (string * Item.hooks) list =
  [
    (* OnReceiveMana: all seventeen. *)
    ("IBFH", { no_hooks with on_receive_mana = Some hook_ibfh });
    ("IDKH", { no_hooks with on_receive_mana = Some hook_idkh });
    ("IFMO", { no_hooks with on_receive_mana = Some hook_ifmo });
    ("IJAC", { no_hooks with on_receive_mana = Some hook_ijac });
    ("IJAH", { no_hooks with on_receive_mana = Some hook_ijah });
    ("IJOB", { no_hooks with on_receive_mana = Some hook_ijob });
    ("IJOH", { no_hooks with on_receive_mana = Some hook_ijoh });
    ("IMOA", { no_hooks with on_receive_mana = Some hook_imoa });
    ("IRKA", { no_hooks with on_receive_mana = Some hook_irka });
    ("IROA", { no_hooks with on_receive_mana = Some hook_iroa });
    ("IROE", { no_hooks with on_receive_mana = Some hook_iroe });
    ("IROF", { no_hooks with on_receive_mana = Some hook_irof });
    ("IROW", { no_hooks with on_receive_mana = Some hook_irow });
    ("ISOA", { no_hooks with on_receive_mana = Some hook_isoa });
    ("ISST", { no_hooks with on_receive_mana = Some hook_isst });
    ("ISTL", { no_hooks with on_receive_mana = Some hook_istl });
    ("IWHP", { no_hooks with on_receive_mana = Some hook_iwhp });
    (* OnReceiveGold: all three. IGPK declares gold and xp together. *)
    ("IRBR", { no_hooks with on_receive_gold = Some hook_irbr });
    ("IXHD", { no_hooks with on_receive_gold = Some hook_ixhd });
    ( "IGPK",
      { no_hooks with
        on_receive_gold = Some hook_igpk;
        on_receive_xp = Some hook_igpk_xp } );
    (* OnReceiveXP: all six; ISES writes the grid. *)
    ("IALR", { no_hooks with on_receive_xp = Some hook_ialr });
    ("IAOB", { no_hooks with on_receive_xp = Some hook_iaob });
    ("IMSE", { no_hooks with on_receive_xp = Some hook_imse });
    ("ISKT", { no_hooks with on_receive_xp = Some hook_iskt });
    ("ISES", { no_hooks with on_receive_xp = Some hook_ises_xp });
    (* OnStartTurn: all nine. IDSH and INOB are here for the counter reset their
       damage halves need. *)
    ("IEGM", { no_hooks with on_start_turn = Some hook_iegm });
    ("ISDO", { no_hooks with on_start_turn = Some hook_isdo });
    ("ITRG", { no_hooks with on_start_turn = Some hook_itrg });
    ("ITRI", { no_hooks with on_start_turn = Some hook_itri });
    ("ITRU", { no_hooks with on_start_turn = Some hook_itru });
    ("ICOS", { no_hooks with on_start_turn = Some hook_icos });
    ("IDSH", { no_hooks with on_start_turn = Some hook_idsh_start });
    ("INOB", { no_hooks with on_start_turn = Some hook_inob_start });
    ("ITUT", { no_hooks with on_start_turn = Some hook_itut });
    (* OnMatch4 / OnMatch5: all six items. *)
    ( "ICSA",
      { no_hooks with
        on_match4 = Some (fun ctx -> hook_icsa 2 ctx);
        on_match5 = Some (fun ctx -> hook_icsa 5 ctx) } );
    ( "IRKK",
      { no_hooks with on_match4 = Some hook_irkk; on_match5 = Some hook_irkk } );
    ( "ISRI",
      { no_hooks with on_match4 = Some hook_isri; on_match5 = Some hook_isri } );
    ( "IWBC",
      { no_hooks with on_match4 = Some hook_iwbc; on_match5 = Some hook_iwbc } );
    ("IUSI", { no_hooks with on_match5 = Some hook_iusi });
    ( "IMGS",
      { no_hooks with on_match4 = Some hook_imgs; on_match5 = Some hook_imgs } );
    (* OnVictory: the only one. *)
    ("IHTR", { no_hooks with on_victory = Some hook_ihtr });
  ]

(** The whole hook record for an id: the damage hooks if they are ported, plus
    whatever event hooks the table above carries. An id in neither is inert. *)
let hooks_of_id (id : string) : Item.hooks =
  let base =
    { no_hooks with on_give_damage = hook_of id; on_receive_damage = hook_receive_of id }
  in
  match List.assoc_opt id event_hooks with
  | None -> base
  | Some e ->
      { base with
        on_receive_mana = e.on_receive_mana;
        on_receive_gold = e.on_receive_gold;
        on_receive_xp = e.on_receive_xp;
        on_start_turn = e.on_start_turn;
        on_match4 = e.on_match4;
        on_match5 = e.on_match5;
        on_victory = e.on_victory }


let unported_damage : string list = [ "IALS"; "ILBC" ]

(** The same for [OnReceiveDamage]: all 38 scripts that declare it are ported
    through [hook_receive_of] - the board writes stopped being a blocker once
    the context could write the grid. *)
let unported_receive_damage : string list = []


let known_unported : (string * string) list =
  [
    ( "IALS",
      "OnGiveDamage: SUBTRACT_XP(targetIdx, damage*2) - experience is per character in the Lua and one battle total here" );
    ( "ILBC",
      "OnGiveDamage: GET_CHARACTER_ID(targetIdx) compared against the registry ids MLIC and MARK, and a combatant carries no registry id" );
  ]

(** Builds a runtime item for [id] from the generated descriptors. Returns [None]
    if the id is not in the table. An item with no ported hook still comes back,
    as an inert item, so an unported item is worn but does nothing rather than
    not existing. *)
let item_of_id (id : string) : item option =
  match Item_data.descriptor_of id with
  | None -> None
  | Some d -> Some (make_item ~hooks:(hooks_of_id id) d)

(** OnStartBattle, hand-ported from the six scripts that declare it - the
    bodies behind the [on_start_battle] flag the descriptor table carries.

    IDHE and IFLH top up a mana bank ([ADD_MANA_WATER(characterIdx,10)],
    [ADD_MANA_FIRE(characterIdx,8)]); the four IWL* walls raise the ceiling
    and the pool together ([ADD_MAX_LIFE] then [ADD_LIFE], the order the
    scripts use: ceiling first, so the life rise is measured against the new
    one). Everything is silent - [NOTIFY_OF_ACTIVATED_ITEM] has no log event
    of its own - and the mana credit is uncapped, the same reading
    [Campaign_companion_hooks]'s ManaBonus already makes.

    The rune JXXX declares OnStartBattle too: its body reads the equipped
    rune's power code and data at fire time, so its payoffs are per-item
    data rather than a fixed table entry - [rune_start_payoffs] below,
    registered by [Campaign] when an item is forged or rebuilt from a
    save. The six fixed items stay static. *)
type start_payoff =
  | AddMana of Combat.element * int
  | AddLife of int
  | AddMaxLife of int

(* The forge's minted rune items: JXXX's OnStartBattle reads the power
   code - 0-3 credit POWERDATA of that mana pool, 4 raises max life and
   life - so the payoffs carry per-item data, registered at forge/load
   time. An id absent from the table falls through to the six fixed
   entries below. *)
let rune_start_payoffs : (string, start_payoff list) Hashtbl.t =
  Hashtbl.create 32

let start_payoffs_of (id : string) : start_payoff list =
  match Hashtbl.find_opt rune_start_payoffs id with
  | Some ps -> ps
  | None -> (
      match id with
      | "IDHE" -> [ AddMana (Combat.Water, 10) ]
      | "IFLH" -> [ AddMana (Combat.Fire, 8) ]
      | "IWLB" -> [ AddMaxLife 100; AddLife 100 ]
      | "IWLM" -> [ AddMaxLife 200; AddLife 200 ]
      | "IWLR" -> [ AddMaxLife 20; AddLife 20 ]
      | "IWLS" -> [ AddMaxLife 50; AddLife 50 ]
      | _ -> [])

let apply_start_payoff (who : Combat.combatant) (p : start_payoff) : unit =
  match p with
  | AddMana (e, n) -> who.mana <- Combat.add_mana e n who.mana
  | AddLife n -> who.life <- who.life + n
  | AddMaxLife n -> who.max_life <- who.max_life + n

(** Fires every equipped item's start hook on its owner, in the loadout's fixed
    slot order ([Item.equipped]), returning the ids that had a body to run.
    Mirrors the companion pass in [Campaign.open_battle]: unknown items and
    items without the hook are inert. *)
let apply_start_battle (who : Combat.combatant) (l : loadout) : string list =
  List.fold_left
    (fun fired i ->
      match start_payoffs_of (item_id i) with
      | [] -> fired
      | payoffs ->
          List.iter (apply_start_payoff who) payoffs;
          fired @ [ item_id i ])
    [] (equipped l)
