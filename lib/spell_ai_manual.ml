(** Hand-ported [ShouldAICastSpell] bodies.

    The mechanical shape (`return Std_AISpellcastingChance(N)`) is generated into
    `lib/spell_ai.ml` by `tools/extract_spell_ai.ps1`. This file holds the ones
    that read the board, and each entry keeps the Lua it came from close enough
    to check against.

    Every hook here ends in either [ai_spellcasting_chance] or a transcription of
    its body. Where a hook does its own percentile arithmetic instead of calling
    the shared helper, that is noted, because it is the sort of thing that gets
    "simplified" into the helper and quietly changes behaviour.

    Two known omissions, both consequences of [CastSpell] not being ported yet:

    - Targeting hooks call `GetRandomGrid_Type` and `SET_INPUT_DATA` to pick a
      target cell. That has no observable effect on the {e decision}, only on
      which cell the spell later hits, so it is left out here. It does consume
      randomness in the original, which shifts later rolls in the same turn.
    - `PERCENTILE_CHANCE_SYNC` is read once per turn into [ai_context] rather than
      per call. Every one of the 130 hooks calls it at most once, so this is
      equivalent; a hook that called it twice would differ. *)

open Spell

(** SBNA / SBNE / SBNF / SBNW: identical apart from the element. Requires five or
    more of that colour on the board, then scales the chance by three per gem.

    ```lua
    local bonus = CountGems(GEM_YELLOW);
    if (bonus < 5) then return 0; end
    return Std_AISpellcastingChance(3*bonus);
    ``` *)
let needs_5_gems_then (count : ai_context -> int) (per_gem : int) (ctx : ai_context) : bool =
  let n = count ctx in
  if n < 5 then false else ai_spellcasting_chance_i ~modifier:(n * per_gem) ctx

let hook_sbna = needs_5_gems_then gyellow 3
let hook_sbne = needs_5_gems_then ggreen 3
let hook_sbnf = needs_5_gems_then gred 3
let hook_sbnw = needs_5_gems_then gblue 3

(** SBRL: no threshold at all, so it is always a candidate. Skulls plus gold,
    five per gem.

    ```lua
    local bonus = CountGems(GEM_SKULL) + CountGems(GEM_GOLD);
    return Std_AISpellcastingChance(bonus*5);
    ``` *)
let hook_sbrl ctx =
  ai_spellcasting_chance_i ~modifier:((gskull ctx + ggold ctx) * 5) ctx

(** SCLI and STHR are byte-identical apart from the multiplier: one requires at
    least one red skull and pays ten per, the other same. Both target a red
    skull cell, which is omitted per the header. *)
let red_skulls_gate ~per (ctx : ai_context) : bool =
  let n = gredskull ctx in
  if n <= 0 then false else ai_spellcasting_chance_i ~modifier:(n * per) ctx

let hook_scli = red_skulls_gate ~per:10
let hook_sthr = red_skulls_gate ~per:10

(** SLIS: twenty per red skull and {e no} threshold, because the `if` that
    selects a target is dead — it is overwritten by an unconditional second
    `GetRandomGrid_Type`. Ported as written rather than as intended: with zero red
    skulls the chance modifier is 0, so it can still be cast.

    ```lua
    local x,y = 3; local y = 1;
    local numRedSkulls = CountGems(GEM_REDSKULL);
    if (numRedSkulls > 0) then
        x,y = GetRandomGrid_Type(GEM_REDSKULL);
    else
        x,y = GetRandomGrid_Type(GEM_SKULL);
    end
    local x,y = GetRandomGrid_Type(GEM_REDSKULL);   -- overwrites the above
    SET_INPUT_DATA(0,x);
    SET_INPUT_DATA(1,y);
    return Std_AISpellcastingChance(numRedSkulls*20);
    ``` *)
let hook_slis ctx = ai_spellcasting_chance_i ~modifier:(gredskull ctx * 20) ctx

(** SCLV, SFBT, SROF and SNWR share a shape: a floor, then a multiple of the
    count. Only the floor and the multiplier differ. *)
let floor_then ?(floor = 0) ~(strict : bool) ~(per : int) (count : ai_context -> int)
    (ctx : ai_context) : bool =
  let n = count ctx in
  let ok = if strict then n <= floor else n < floor in
  if ok then false else ai_spellcasting_chance_i ~modifier:(n * per) ctx

let hook_sclv = floor_then ~floor:10 ~strict:false ~per:2 gyellow
let hook_sfbt = floor_then ~floor:10 ~strict:false ~per:2 gblue
let hook_srof = floor_then ~floor:10 ~strict:false ~per:3 gred
let hook_snwr = floor_then ~floor:5 ~strict:false ~per:4 ggreen

(** SDDI passes a {e float} modifier, `numYellow * 1.5`, and Lua's `>` promotes
    the comparison, so 7 yellow gems really does move the threshold by 10.5 and
    not by a truncated 10. *)
let hook_sddi ctx =
  let n = gyellow ctx in
  if n <= 4 then false
  else ai_spellcasting_chance ~modifier:(float_of_int n *. 1.5) ctx

(** SFRZ, SFSK and SSCV gate on the board and then pass a modifier of 0, so once
    the floor is met they cast at most half the time. *)
let floor_then_chance0 ?(floor = 0) ~(strict : bool) (count : ai_context -> int)
    (ctx : ai_context) : bool =
  let n = count ctx in
  let ok = if strict then n <= floor else n < floor in
  if ok then false else ai_spellcasting_chance_i ~modifier:0 ctx

let hook_sfrz = floor_then_chance0 ~floor:4 ~strict:true gred
let hook_sfsk = floor_then_chance0 ~floor:15 ~strict:false (fun c -> ggreen c + gblue c)
let hook_sscv = floor_then_chance0 ~floor:6 ~strict:false ggold

(** SDIV needs eight stars and pays one per star. STHX is the same with green and
    a lower floor. *)
let hook_sdiv = floor_then_chance0 ~floor:8 ~strict:false gstar

let hook_sthx (ctx : ai_context) =
  let n = ggreen ctx in
  if n <= 4 then false else ai_spellcasting_chance_i ~modifier:n ctx

(** SHBT and SWBU: a flat five, upgraded to three per gem once there are eight or
    more. The Lua writes it as `if ... then bonus = n*3` over an initial
    `bonus = 5`. *)
let five_or_three_per (count : ai_context -> int) (ctx : ai_context) : bool =
  let n = count ctx in
  let modifier = if n >= 8 then n * 3 else 5 in
  ai_spellcasting_chance_i ~modifier ctx

let hook_shbt = five_or_three_per gred
let hook_swbu = five_or_three_per gyellow

(** SCTH, SDRR and SSWM all fall back to a modifier of -20 rather than returning 0
    early. That is {e not} a veto, which is the easy thing to assume: -20 puts the
    threshold at 30, so the spell still casts on percentiles 0 through 30. It is a
    heavy penalty rather than a refusal, and reading it as a veto would make
    these three spells fire far less often than the game does.

    SCON is the one that really does veto, with -100, which puts the threshold at
    -50 and so nothing can clear it. *)
let penalised_below ~(floor : int) ~(strict : bool) ~(per : int)
    (count : ai_context -> int) (ctx : ai_context) : bool =
  let n = count ctx in
  let below = if strict then n <= floor else n < floor in
  ai_spellcasting_chance_i ~modifier:(if below then -20 else n * per) ctx

let hook_scth = penalised_below ~floor:8 ~strict:false ~per:5 (fun c -> gred c + ggreen c)
let hook_sdrr = penalised_below ~floor:6 ~strict:true ~per:5 (fun c -> gred c + gyellow c)
let hook_sswm = penalised_below ~floor:5 ~strict:true ~per:3 gyellow

(** SESK counts plain and red skulls together. *)
let hook_sesk ctx =
  let n = gskull ctx + gredskull ctx in
  if n < 4 then false else ai_spellcasting_chance_i ~modifier:(n * 2) ctx

(** SWTD gates on three skulls and then takes its modifier from how much earth
    mana the caster holds. Note the two `if`s are not `elseif`: at 20 or more
    both run and the second wins, so 20+ means 30, not 40. *)
let hook_swtd ctx =
  if gskull ctx < 3 then false
  else begin
    let earth = ctx.ctx_caster.Combat.mana.Combat.earth in
    let modifier = if earth >= 20 then 30 else if earth >= 15 then 10 else 0 in
    ai_spellcasting_chance_i ~modifier ctx
  end

(** SIST and SSGZ (with SBRA) roll their own percentile instead of calling the
    shared helper, so they are transcribed rather than expressed through it.

    SIST subtracts twice the green count from the percentile and applies two
    tiers of board threshold:

    ```lua
    local evaluation = EVALUATE_BOARD();
    local chance = PERCENTILE_CHANCE_SYNC() - numGreen*2;
    if (evaluation < 25 and chance < 75) then return 1; end
    if (evaluation < 30 and chance < 50) then return 1; end
    return 0;
    ``` *)
let hook_sist ctx =
  let n = ggreen ctx in
  if n <= 4 then false
  else begin
    let chance = ctx.ctx_percentile - (n * 2) in
    (ctx.ctx_evaluation < 25 && chance < 75) || (ctx.ctx_evaluation < 30 && chance < 50)
  end

(** SSGZ is the SBRA pattern: the shared threshold logic inlined, with the
    green count added to the percentile and earth mana 15+ subtracting 30 from
    it. *)
let green_and_earth ctx =
  let evaluation = ctx.ctx_evaluation in
  let num_green = ggreen ctx in
  let chance =
    ctx.ctx_percentile + num_green
    + if ctx.ctx_caster.Combat.mana.Combat.earth >= 15 then -30 else 30
  in
  if chance < 50 then false
  else if evaluation > 30 then false
  else if num_green < 6 then false
  else true

let hook_ssgz ctx =
  (* The count gate comes after the percentile tests in the Lua, but both have to
     pass anyway, so testing it first is the same decision. *)
  if ggreen ctx < 6 then false else green_and_earth ctx

(** SCON: requires a strict majority of one gem type, and only pays out once
    there are more than eleven of them. Otherwise the modifier is -100, which
    never clears the percentile bar. The `else return 0` when nothing is a
    majority is the tie case, and note the Lua uses strict `>` throughout so a
    two-way tie falls through to it. *)
let hook_scon ctx =
  let counts =
    [ (gyellow ctx, "yellow"); (ggreen ctx, "green"); (gblue ctx, "blue");
      (gstar ctx, "star"); (ggold ctx, "gold") ]
  in
  let strict_max c = List.for_all (fun (other, _) -> c > other) counts in
  match List.find_opt (fun (c, _) -> strict_max c) counts with
  | None -> false
  | Some (num, _) ->
      let modifier = if num > 11 then num * 3 else -100 in
      ai_spellcasting_chance_i ~modifier ctx

(** ------------------------------------------------------------------ *)
(** The mana-and-life group.

    These hooks read no board and no items: they are arithmetic over the
    caster's pools, the enemy's pools, and the damage taken so far. Most are one
    line of Lua, so each is transcribed rather than abstracted, because the
    interesting part is exactly which field is read and against what constant. *)

(** SBAV, SFLV: the caster's own pool minus ten, so it stops asking once the pool
    is under ten. Note this is a subtraction with no floor, so a small pool gives
    a negative modifier, which lowers the cast threshold rather than vetoing.
    ```lua
    return Std_AISpellcastingChance(GET_MANA_EARTH(idxCaster)-10);
    ``` *)
let hook_sbav ctx =
  ai_spellcasting_chance_i ~modifier:(mana_of ctx.ctx_caster Combat.Earth - 10) ctx

let hook_sflv ctx =
  ai_spellcasting_chance_i ~modifier:(mana_of ctx.ctx_caster Combat.Fire - 10) ctx

(** SDST, SFBO, SFSH: twice the caster's Fire pool. Three spells, one body. *)
let hook_sdst ctx =
  ai_spellcasting_chance_i ~modifier:(2 * mana_of ctx.ctx_caster Combat.Fire) ctx

let hook_sfbo = hook_sdst
let hook_sfsh = hook_sdst

(** SSOB: three times Earth, the largest of the "more mana, more likely" hooks.
    SSOS: twice Air. *)
let hook_ssob ctx =
  ai_spellcasting_chance_i ~modifier:(3 * mana_of ctx.ctx_caster Combat.Earth) ctx

let hook_ssos ctx =
  ai_spellcasting_chance_i ~modifier:(2 * mana_of ctx.ctx_caster Combat.Air) ctx

(** SCBO: the mean of all four pools, vetoed below eight, then twice the mean.
    The Lua averages as `(a+b+c+d)/4`, which truncates, so a total of 33 gives
    8 rather than 8.25. *)
let hook_scbo ctx =
  let c = ctx.ctx_caster in
  let total = mana_of c Combat.Earth + mana_of c Combat.Fire + mana_of c Combat.Air + mana_of c Combat.Water in
  let avg = total / 4 in
  if avg < 8 then false else ai_spellcasting_chance_i ~modifier:(avg * 2) ctx

(** SCTO: strictly "more than ten", so a pool of exactly ten still qualifies.
    ```lua
    if (GET_MANA_EARTH(idxCaster) > 10) then return 0; end
    return Std_AISpellcastingChance(0);
    ``` *)
let hook_scto ctx =
  if mana_of ctx.ctx_caster Combat.Earth > 10 then false
  else ai_spellcasting_chance_i ~modifier:0 ctx

(** STRM: a hard floor of ten, then a modifier that starts at -20 and rises by
    two per mana, crossing zero at exactly twenty. *)
let hook_strm ctx =
  let m = mana_of ctx.ctx_caster Combat.Earth in
  if m < 10 then false
  else ai_spellcasting_chance_i ~modifier:(-40 + (2 * m)) ctx

(** SBST: reads the {e enemy}'s Earth pool, not the caster's, and applies a
    discontinuity. Over five it triples; at five or under it subtracts ten, so the
    modifier jumps from -10 to 18 between 5 and 6. *)
let hook_sbst ctx =
  let bonus = mana_of ctx.ctx_enemy Earth in
  let bonus = if bonus > 5 then bonus * 3 else bonus - 10 in
  ai_spellcasting_chance_i ~modifier:bonus ctx

(** SSWA: the enemy's Earth pool is a hard floor of seven and then also the
    modifier, so a large enemy pool makes it near-certain. *)
let hook_sswa ctx =
  let green = mana_of ctx.ctx_enemy Earth in
  if green < 7 then false else ai_spellcasting_chance_i ~modifier:green ctx

(** SFSP: both sides gate on fixed numbers, then the modifier combines the
    caster's damage taken with the enemy's Fire pool. Note the `- 30`, which can
    drive the modifier well below zero at the boundary the veto just admitted. *)
let hook_sfsp ctx =
  let my_damage = max_life_of ctx.ctx_caster - life_of ctx.ctx_caster in
  let red_mana = mana_of ctx.ctx_enemy Fire in
  if my_damage < 20 || red_mana < 8 then false
  else ai_spellcasting_chance_i ~modifier:(my_damage + (5 * red_mana) - 30) ctx

(** SMBU: sums the {e enemy}'s four pools. At ten or under it returns -50
    outright rather than calling the helper, which is the one place the negative
    returns appear. See [ai_spellcasting_chance] on why a negative veto is still
    a veto. *)
let hook_smbu ctx =
  let e = ctx.ctx_enemy in
  let total = mana_of e Combat.Earth + mana_of e Combat.Fire + mana_of e Combat.Air + mana_of e Combat.Water in
  if total <= 10 then false
  else ai_spellcasting_chance_i ~modifier:((total - 10) * 2) ctx

(** SSSW: does the mirror of SMBU, comparing both totals rather than one of them,
    and vetoing when the caster is {e ahead}. Casting when behind is the point of
    the spell. *)
let hook_sssw ctx =
  let total c = mana_of c Combat.Earth + mana_of c Combat.Fire + mana_of c Combat.Air + mana_of c Combat.Water in
  let mine = total ctx.ctx_caster in
  let theirs = total ctx.ctx_enemy in
  if mine > theirs then false
  else ai_spellcasting_chance_i ~modifier:(2 * (theirs - mine)) ctx

(** SSBM: reads three pools on two combatants, and its last two clauses pull in
    opposite directions. Water above twenty on the caster is penalised as well as
    Water below four, because the spell wants a mid-range pool. *)
let hook_ssbm ctx =
  let e = ctx.ctx_enemy in
  let c = ctx.ctx_caster in
  let modifier = ref 0 in
  if mana_of e Combat.Air > 10 then modifier := !modifier + 10;
  if mana_of e Combat.Air < 5 then modifier := !modifier - 10;
  if mana_of c Combat.Water < 4 then modifier := !modifier - 10;
  if mana_of c Combat.Water > 20 then modifier := !modifier - 10;
  ai_spellcasting_chance_i ~modifier:!modifier ctx

(** SSHO: three flat bonuses of ten for the enemy sitting above five in any of
    three pools. Purely a function of what the enemy has banked. *)
let hook_ssho ctx =
  let e = ctx.ctx_enemy in
  let modifier = ref 0 in
  if mana_of e Combat.Fire > 5 then modifier := !modifier + 10;
  if mana_of e Combat.Air > 5 then modifier := !modifier + 10;
  if mana_of e Combat.Water > 5 then modifier := !modifier + 10;
  ai_spellcasting_chance_i ~modifier:!modifier ctx

(** SEGZ and SGEM: the same "how hurt am I" idea with different thresholds and
    different shapes. SEGZ grades the modifier; SGEM only vetoes and then asks
    with a modifier of zero. *)
let hook_segz ctx =
  let diff = max_life_of ctx.ctx_caster - life_of ctx.ctx_caster in
  let bonus = if diff < 10 then -20 else if diff > 30 then 50 else 0 in
  ai_spellcasting_chance_i ~modifier:bonus ctx

let hook_sgem ctx =
  if life_of ctx.ctx_caster >= max_life_of ctx.ctx_caster - 5 then false
  else ai_spellcasting_chance_i ~modifier:0 ctx

(** SDGZ: the enemy's missing life is the modifier, so a nearly dead enemy makes
    the spell more attractive. It is deliberately not vetoed at zero. *)
let hook_sdgz ctx =
  ai_spellcasting_chance_i ~modifier:(life_of ctx.ctx_enemy - 20) ctx

(** SRGN: the only hook that is a bare comparison with no helper call, returning
    1 or 0 directly. Four points of damage is the whole test. *)
let hook_srgn ctx =
  max_life_of ctx.ctx_caster - life_of ctx.ctx_caster >= 4

(** SCOU: one flat -50 if the caster is carrying anything at all. This reads
    [GET_NUM_STATUS_EFFECTS], so it counts stacks of all kinds rather than
    testing a named effect. *)
let hook_scou ctx =
  let bonus = if num_status_effects ctx.ctx_caster > 0 then -50 else 0 in
  ai_spellcasting_chance_i ~modifier:bonus ctx

(** The status-effect gates.

    These veto on a named status effect, then ask with a modifier of zero through
    [ai_spellcasting_chance]. So they cast on at most half the turns that reach
    them, and never on a board scoring over 30.

    Only three hooks are this shape. SENR and SHID look like members but are not:
    their Lua calls [EVALUATE_BOARD] and [PERCENTILE_CHANCE_SYNC] first, so they
    belong to the evaluate family below with a status check bolted on the front.
    SWOF and SSPT also read a status, but as a modifier rather than a veto, and
    are kept here for that reason. *)

(** SCHL and SHAS: the caster must not already carry the effect, since the spell
    applies it and applying it twice would be wasted. SHWL and SSPT are
    different: they veto or discount when the {e enemy} has it, because those
    spells answer an enemy's status rather than cause it. *)
let veto_if_caster_has ~(name : string) (ctx : ai_context) : bool =
  if has_status ctx.ctx_caster name then false
  else ai_spellcasting_chance_i ~modifier:0 ctx

let hook_schl = veto_if_caster_has ~name:"Challenged"
let hook_shas = veto_if_caster_has ~name:"Hasted"

(** SHWL: Fearing a Frightened enemy is heavily discouraged. The Lua subtracts 40
    from the percentile and then tests the usual [chance < 50] veto, so Fear makes
    the roll have to be *higher*, not lower: it needs a percentile of 90 rather
    than 50. Getting this backwards is easy - it reads like a bonus but is a
    penalty on both sides of the comparison.

    SSPT is the same idea with a smaller penalty: Blinding a Blinded enemy costs
    15 off the {e modifier}, which lowers the threshold from 50 to 35. *)
let hook_shwl ctx =
  let chance = if has_status ctx.ctx_enemy "Fear" then ctx.ctx_percentile - 40 else ctx.ctx_percentile in
  chance >= 50 && ctx.ctx_evaluation <= 30

let hook_sspt ctx =
  ai_spellcasting_chance_i ~modifier:(if has_status ctx.ctx_enemy "Blinded" then -15 else 0) ctx

(** SWOF: vetoes on the caster already having the wall, then grades the caster's
    own Fire pool at a single step: 20 above fourteen, nothing at or below it. *)
let hook_swof ctx =
  if has_status ctx.ctx_caster "WallOfFired" then false
  else ai_spellcasting_chance_i
           ~modifier:(if mana_of ctx.ctx_caster Combat.Fire > 14 then 20 else 0) ctx

(** SSBL: the odd one out among the status gates. It returns -10 outright when
    the caster has Singing Blades, rather than vetoing with 0, and otherwise asks
    with a positive modifier of 25. *)
let hook_ssbl ctx =
  if has_status ctx.ctx_caster "SingingBladesed" then false
  else ai_spellcasting_chance_i ~modifier:25 ctx

(** SCTO's siblings SSTL, SCHV and SCLE are pure constant modifiers and used to be
    duplicated here, because the generator's pattern required a non-negative
    literal and so skipped all three. It now accepts a sign and generates them,
    which is why they are absent from this file. Keep it that way: a second copy
    of a generated hook would silently shadow it and drift the moment either side
    changed. *)

(** The evaluate-then-percentile family.

    Nineteen hooks share one skeleton: read [EVALUATE_BOARD] and
    [PERCENTILE_CHANCE_SYNC], adjust the percentile, veto if it drops below 50,
    veto if the board is worth more than 30, then optionally check something
    specific. Writing them as one helper with the adjustments passed in keeps
    the shared part identical, which is the part that is easy to get subtly
    wrong in a dozen near-copies.

    The order matters and is preserved: the percentile gate is tested {e before}
    the evaluation gate in all of these, and the specific check after both. *)

(** [chance < 50] vetoes, [evaluation > 30] vetoes. [adjust] may lower the
    percentile, which makes the spell harder to justify. *)
let evaluate_gate ~(adjust : ai_context -> int -> int)
    ~(specific : ai_context -> int -> bool) (ctx : ai_context) : bool =
  let chance = adjust ctx ctx.ctx_percentile in
  if chance < 50 then false
  else if ctx.ctx_evaluation > 30 then false
  else specific ctx chance

(** No adjustment and no extra condition: the plain "cast it if the turn is
    mediocre and the percentile is friendly" shape. SRBI is this verbatim. *)
let hook_srbi ctx = evaluate_gate ~adjust:(fun _ p -> p) ~specific:(fun _ _ -> true) ctx

(** SENR and SHID put a status check in front of the shared gates, and it is
    checked {e first}, before the percentile is even read. Both read the
    evaluation and the percentile, so they are the evaluate family with a veto
    bolted on rather than one of the modifier-zero gates. *)
let veto_first_then_gate ~(name : string) (ctx : ai_context) : bool =
  if has_status ctx.ctx_caster name then false
  else evaluate_gate ~adjust:(fun _ p -> p) ~specific:(fun _ _ -> true) ctx

let hook_senr = veto_first_then_gate ~name:"Enraged"
let hook_shid = veto_first_then_gate ~name:"Hidden"

(** SCHM and SRFC are the same shape with different gem kinds. Both count a gem
    over the whole board, veto if the count is four or under, veto if the caster is
    nearly undamaged, and then add 25 per damage quarter. The divisions by 2 and
    by 4 truncate, matching Lua. The count floor is four in both, so it is a
    literal rather than a parameter. *)
let gems_and_damage ~(gem : gem_kind) (ctx : ai_context) : bool =
  let n = count_gems gem ctx in
  if n <= 4 then false
  else if life_of ctx.ctx_caster >= max_life_of ctx.ctx_caster - 8 then false
  else
    let bonus =
      if life_of ctx.ctx_caster < max_life_of ctx.ctx_caster / 2 then 25 else 0
      + if life_of ctx.ctx_caster < max_life_of ctx.ctx_caster / 4 then 25 else 0
    in
    evaluate_gate ~adjust:(fun _ p -> p + n + bonus) ~specific:(fun _ _ -> true) ctx

(** SRFC counts gold. SCHM counts skulls, accepting both the plain and the red
    variant (gem ids 5 and 15) in a single pass, so it cannot use [gem]. *)
let hook_srfc = gems_and_damage ~gem:GGold

(** The skull counter has to accept two gem kinds, so it is spelled out rather
    than reusing [count_gems]. *)
let hook_schm ctx =
  let n = (count_gems GSkull ctx) + (count_gems GRedSkull ctx) in
  if n <= 4 then false
  else if life_of ctx.ctx_caster >= max_life_of ctx.ctx_caster - 8 then false
  else
    let bonus =
      if life_of ctx.ctx_caster < max_life_of ctx.ctx_caster / 2 then 25 else 0
      + if life_of ctx.ctx_caster < max_life_of ctx.ctx_caster / 4 then 25 else 0
    in
    evaluate_gate ~adjust:(fun _ p -> p + n + bonus) ~specific:(fun _ _ -> true) ctx

(** SBUR, SBRA and SSTO count a single gem id and grade the percentile by it, with
    a floor on the count. SBUR wants eight green (gem id 1, which is Earth),
    SSTO wants six green, SBRA wants six red (gem id 2, Fire). The Lua tests the
    count after the percentile and evaluation gates; here it is tested first
    because all three clauses are pure and a conjunction is order-independent.
    The order is noted only so nobody goes looking for a side effect. *)
let colour_gate ~(gem : gem_kind) ~(min_gems : int) (ctx : ai_context) : bool =
  let n = count_gems gem ctx in
  if n < min_gems then false
  else evaluate_gate ~adjust:(fun _ p -> p + n) ~specific:(fun _ _ -> true) ctx

let hook_sbur = colour_gate ~gem:GGreen ~min_gems:8
let hook_ssto = colour_gate ~gem:GGreen ~min_gems:6

(** SBRA is [colour_gate] plus one extra clause: the caster's own Fire pool either
    rewards or suppresses it, and the suppression is large enough to matter. The
    Fire check happens before the count check in the Lua. *)
let hook_sbra ctx =
  let n = count_gems GRed ctx in
  let chance =
    ctx.ctx_percentile
    + n
    + if mana_of ctx.ctx_caster Combat.Fire >= 15 then -30 else 30
  in
  if chance < 50 then false
  else if ctx.ctx_evaluation > 30 then false
  else if n < 6 then false
  else true

(** SSOA counts earth and water gems together. The Lua uses the symbolic
    [GEM_EARTH] and [GEM_WATER], which are gem ids 1 and 3; a cell counts once even
    if it could match both. Eight in total is required. *)
let hook_ssoa ctx =
  let n = (count_gems GGreen ctx) + (count_gems GBlue ctx) in
  if n < 8 then false
  else evaluate_gate ~adjust:(fun _ p -> p + n) ~specific:(fun _ _ -> true) ctx

(** SPET and SWEB nudge the percentile up by a third of a pool. Lua's `/` on two
    integers truncates, so the fraction is lost before it is added. *)
let mana_thirds ~(elem : Combat.element) (ctx : ai_context) : bool =
  evaluate_gate
    ~adjust:(fun c p -> p + (mana_of c.ctx_caster elem / 3))
    ~specific:(fun _ _ -> true) ctx

let hook_spet = mana_thirds ~elem:Combat.Earth
let hook_sweb = mana_thirds ~elem:Combat.Air

(** SSPF is the simplest gate in the game and the only one with no evaluation
    check at all: it reads the percentile, asks for 15, and returns 1. *)
let hook_sspf ctx = ctx.ctx_percentile >= 15

(** STAU: the enemy's total mana is the only condition, and there are two bands.
    Below 20 always no; below 30 the percentile has to be at least 75. Note this
    uses `>=` against the evaluation where the others use `>`, so a board
    scoring exactly 30 passes here. *)
let hook_stau ctx =
  let e = ctx.ctx_enemy in
  let total = mana_of e Combat.Earth + mana_of e Combat.Fire + mana_of e Combat.Air + mana_of e Combat.Water in
  let chance = ctx.ctx_percentile in
  if chance < 50 then false
  else if ctx.ctx_evaluation >= 30 then false
  else if total < 20 then false
  else if total < 30 && chance < 75 then false
  else true

(** SSWP sums the enemy side's Air mana, but over {e all} enemies rather than the
    first. The single-enemy battle model makes that one iteration, but the loop is
    kept because the original has it. *)
let hook_sswp ctx =
  let amt_air =
    List.fold_left (fun acc e -> acc + mana_of e Combat.Air) 0 ctx.ctx_enemies
  in
  if amt_air < 6 then false
  else if ctx.ctx_percentile < 50 - amt_air then false
  else if ctx.ctx_evaluation > 30 then false
  else true

(** SVAM and SZAP bias the {e evaluation} rather than the percentile, which makes
    them the mirror of the family above: they want a {e good} board, not a bad
    one. Both subtract a fraction of the caster's Fire pool, divided by 6 and 5
    respectively, and then require the board to be worth 28 or 32. *)
let evaluation_bias ~(divisor : int) ~(low : int) ~(high : int) ~(chance_cut : int)
    (ctx : ai_context) : bool =
  let fire = mana_of ctx.ctx_caster Combat.Fire in
  let evaluation = ctx.ctx_evaluation - (fire / divisor) in
  if evaluation < low && ctx.ctx_percentile < chance_cut then true
  else if evaluation < high && ctx.ctx_percentile < 33 then true
  else false

let hook_svam = evaluation_bias ~divisor:6 ~low:28 ~high:32 ~chance_cut:75
let hook_szap = evaluation_bias ~divisor:5 ~low:28 ~high:32 ~chance_cut:75

(** STHU is the same biased-evaluation shape with no mana term at all: a good
    board under 25 plus a friendly percentile, or under 30 with a percentile
    under 33. *)
let hook_sthu ctx =
  if ctx.ctx_evaluation < 25 && ctx.ctx_percentile < 75 then true
  else if ctx.ctx_evaluation < 30 && ctx.ctx_percentile < 33 then true
  else false

(** SDUP: the one hook that reads items.

    SDUP is the only AI hook that calls [GET_ITEM], and the earlier count of
    "twelve hooks read GET_ITEM" was wrong: it came from counting calls rather
    than scripts, and SDUP is the only spell script that mentions it at all.

    It compares the enemy's and the caster's four slots pairwise and casts only
    if some slot differs and the enemy's is not empty, which is the AI deciding
    the duplicate is worth taking. The `or` chain is over the four slots, and the
    inner `and` means "different from mine, and I actually have one".

    ```lua
    if (  (GET_ITEM(idxEnemy,0) ~= GET_ITEM(idxCaster,0) and GET_ITEM(idxEnemy,0) ~= "")
        or ... slot 1 ...
        or ... slot 2 ...
        or ... slot 3 ...) then bonus = 50; end
    return Std_AISpellcastingChance(bonus);
    ```

    The bonus is 50 or -100. A -100 modifier means the percentile has to be at or
    below -50, which no 0..99 roll ever is, so the "no worthwhile copy" branch is
    an unconditional veto rather than merely a very unlikely cast. *)
let hook_sdup ctx =
  let worthwhile = ref false in
  for n = 0 to 3 do
    let theirs = Option.value (Item.loadout_for ctx.ctx_enemy_items n) ~default:"" in
    let mine = ctx_get_item ctx n in
    if theirs <> mine && theirs <> "" then worthwhile := true
  done;
  ai_spellcasting_chance_i ~modifier:(if !worthwhile then 50 else -100) ctx

(** Hooks by spell id. The generated table in [Spell_ai] covers the mechanical
    shape; these are the ones that read the board, the pools, or the items. *)

let manual_hook_of = function
  | "SBNA" -> Some hook_sbna
  | "SBNE" -> Some hook_sbne
  | "SBNF" -> Some hook_sbnf
  | "SBNW" -> Some hook_sbnw
  | "SBRL" -> Some hook_sbrl
  | "SCLI" -> Some hook_scli
  | "STHR" -> Some hook_sthr
  | "SLIS" -> Some hook_slis
  | "SCLV" -> Some hook_sclv
  | "SFBT" -> Some hook_sfbt
  | "SROF" -> Some hook_srof
  | "SNWR" -> Some hook_snwr
  | "SDDI" -> Some hook_sddi
  | "SFRZ" -> Some hook_sfrz
  | "SFSK" -> Some hook_sfsk
  | "SSCV" -> Some hook_sscv
  | "SDIV" -> Some hook_sdiv
  | "STHX" -> Some hook_sthx
  | "SHBT" -> Some hook_shbt
  | "SWBU" -> Some hook_swbu
  | "SCTH" -> Some hook_scth
  | "SDRR" -> Some hook_sdrr
  | "SSWM" -> Some hook_sswm
  | "SESK" -> Some hook_sesk
  | "SWTD" -> Some hook_swtd
  | "SIST" -> Some hook_sist
  | "SSGZ" -> Some hook_ssgz
  | "SCON" -> Some hook_scon
  (* Mana and life. *)
  | "SBAV" -> Some hook_sbav
  | "SFLV" -> Some hook_sflv
  | "SDST" -> Some hook_sdst
  | "SFBO" -> Some hook_sfbo
  | "SFSH" -> Some hook_sfsh
  | "SSOB" -> Some hook_ssob
  | "SSOS" -> Some hook_ssos
  | "SCBO" -> Some hook_scbo
  | "SCTO" -> Some hook_scto
  | "STRM" -> Some hook_strm
  | "SBST" -> Some hook_sbst
  | "SSWA" -> Some hook_sswa
  | "SFSP" -> Some hook_sfsp
  | "SMBU" -> Some hook_smbu
  | "SSSW" -> Some hook_sssw
  | "SSBM" -> Some hook_ssbm
  | "SSHO" -> Some hook_ssho
  | "SEGZ" -> Some hook_segz
  | "SGEM" -> Some hook_sgem
  | "SDGZ" -> Some hook_sdgz
  | "SRGN" -> Some hook_srgn
  | "SCOU" -> Some hook_scou
  (* Status-effect gates. *)
  | "SCHL" -> Some hook_schl
  | "SENR" -> Some hook_senr
  | "SHAS" -> Some hook_shas
  | "SHID" -> Some hook_shid
  | "SHWL" -> Some hook_shwl
  | "SSPT" -> Some hook_sspt
  | "SWOF" -> Some hook_swof
  | "SSBL" -> Some hook_ssbl
  (* Evaluate-then-percentile. *)
  | "SRBI" -> Some hook_srbi
  | "SRFC" -> Some hook_srfc
  | "SCHM" -> Some hook_schm
  | "SBUR" -> Some hook_sbur
  | "SSTO" -> Some hook_ssto
  | "SBRA" -> Some hook_sbra
  | "SSOA" -> Some hook_ssoa
  | "SPET" -> Some hook_spet
  | "SWEB" -> Some hook_sweb
  | "SSPF" -> Some hook_sspf
  | "STAU" -> Some hook_stau
  | "SSWP" -> Some hook_sswp
  | "SVAM" -> Some hook_svam
  | "SZAP" -> Some hook_szap
  | "STHU" -> Some hook_sthu
  (* Items. *)
  | "SDUP" -> Some hook_sdup
  | _ -> None

(** The ids this file covers, for the coverage test and for the report the
    extractor prints.

    SCHG and SFBA are deliberately absent. SCHG calls [EvaluateRows], a Lua helper
    whose body has not been transcribed; guessing it would put a fabricated
    scoring function in the middle of the AI's decision. SFBA calls
    [GetRandomGrid_Type] and then [SET_INPUT_DATA], which mutates the spell's
    target cell, and the cell it picks is not observable until [CastSpell] lands. *)
let manual_hook_of_spell_ids =
  [ "SBNA"; "SBNE"; "SBNF"; "SBNW"; "SBRL"; "SCLI"; "STHR"; "SLIS"; "SCLV"
  ; "SFBT"; "SROF"; "SNWR"; "SDDI"; "SFRZ"; "SFSK"; "SSCV"; "SDIV"; "STHX"
  ; "SHBT"; "SWBU"; "SCTH"; "SDRR"; "SSWM"; "SESK"; "SWTD"; "SIST"; "SSGZ"
  ; "SCON"
  ; "SBAV"; "SFLV"; "SDST"; "SFBO"; "SFSH"; "SSOB"; "SSOS"; "SCBO"; "SCTO"
  ; "STRM"; "SBST"; "SSWA"; "SFSP"; "SMBU"; "SSSW"; "SSBM"; "SSHO"; "SEGZ"
  ; "SGEM"; "SDGZ"; "SRGN"; "SCOU"
  ; "SCHL"; "SENR"; "SHAS"; "SHID"; "SHWL"; "SSPT"; "SWOF"; "SSBL"
  ; "SRBI"; "SRFC"; "SCHM"; "SBUR"; "SSTO"; "SBRA"; "SSOA"; "SPET"; "SWEB"
  ; "SSPF"; "STAU"; "SSWP"; "SVAM"; "SZAP"; "STHU"
  ; "SDUP" ]