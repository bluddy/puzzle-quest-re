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

(** Hooks by spell id. The generated table in [Spell_ai] covers the mechanical
    shape; these are the ones that read the board. *)
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
  | _ -> None

(** The ids this file covers, for the coverage test and for the report the
    extractor prints. *)
let manual_hook_of_spell_ids =
  [ "SBNA"; "SBNE"; "SBNF"; "SBNW"; "SBRL"; "SCLI"; "STHR"; "SLIS"; "SCLV"
  ; "SFBT"; "SROF"; "SNWR"; "SDDI"; "SFRZ"; "SFSK"; "SSCV"; "SDIV"; "STHX"
  ; "SHBT"; "SWBU"; "SCTH"; "SDRR"; "SSWM"; "SESK"; "SWTD"; "SIST"; "SSGZ"
  ; "SCON" ]