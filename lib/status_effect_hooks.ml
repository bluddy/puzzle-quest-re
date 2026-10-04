(** Hand-ported status effect scripts.

    [tools/extract_status_effects.ps1] generates the descriptors; the behaviour
    lives in each effect's companion `.lua` in `Assets/StatusEffects/` and is
    ported here. Same split as spells and items: data generated, behaviour by
    hand, and every entry keeps its Lua alongside because these are short enough
    to check by eye and the thresholds are the whole behaviour.

    All seventeen are here. Unlike [Item_hooks], which leaves several items
    unported because they need machinery this port lacks, every one of these
    turned out to need only what the battle loop already has.

    **What is dropped.** The `ADD_EFFECT_TO_CHARACTER` and
    `ADD_ANIMEFFECT_TO_CHARACTER` calls are presentation - a sparkle on a
    character - and are omitted, for the same reason `ADD_LIGHTNING`,
    `ADD_EFFECT_TO_GRID` and `ADD_EFFECT_TO_CHARACTER` are omitted in
    `Spell_effects`.

    **Two scripts whose comments disagree with their code.** Both are transcribed
    as written, because the code is what the game runs:

    - `Vigiled`'s header says "On a Match4/5, gain 5 of each mana". `ManaGain`
      adds **3**. The comment is stale.
    - `Disease`'s header says "-1 every mana each turn" and the code names only
      Air, then subtracts from all four pools. The code is right; the header is
      abbreviating.

    **Two that cancel themselves.** Hidden, Wall of Fire and Wall of Thorns ship
    with `duration = 0`, which [Combat.tick_duration] treats as immortal. Each
    removes itself with [Combat.set_effect_duration] to 1 when its condition
    ends, which is the only thing that ever makes it lapse. So "cancel the
    effect" here means "die on the next tick", not "remove now" - the effect
    still works for the rest of the turn in which it cancelled itself. *)

open Combat

(** Every element, in the board's order rather than [element]'s. Disease and
    Paladin's Aura name all four pools one at a time; this is the list they mean. *)
let all_pools = [ Earth; Fire; Air; Water ]

(** [SUBTRACT_MANA_<E>(idx, n)] floors the pool at zero rather than going
    negative. [Combat.subtract_mana] does not clamp, because the general native
    allows a negative pool - see the test "mana can go negative, as the original
    allows" - so the floor these scripts rely on is applied here.

    That distinction is the whole reason this helper exists rather than calling
    [Combat.subtract_mana] directly. *)
let drain (c : combatant) (e : element) (n : int) : unit =
  if n <= 0 then () else subtract_mana c e (min n (mana c e))

(** [ADD_MANA_<E>(idx, n)] stops at the element's ceiling, which
    [Combat.credit_mana] already does. *)
let give (c : combatant) (e : element) (n : int) : unit = ignore (credit_mana c e n)

(** [GET_LIFE(idx)] and [GET_MAX_LIFE(idx)]. *)
let life (c : combatant) = c.life
let max_life (c : combatant) = c.max_life

(** [GET_STATUS_EFFECT_INDEX(idx, id)] - 1-based, where 0 means "not present".
    [Combat.has_status] is the same test without the index. *)
let has (c : combatant) (id : string) = has_status c id

(* ------------------------------------------------------------------ *)
(* OnStartTurn - five scripts                                            *)
(* ------------------------------------------------------------------ *)

(** Blinded: no spells at all this turn.

    ```lua
    local function OnStartTurn(characterIdx,turnNumber)
        DISALLOW_SPELLS_THIS_TURN();
    ```

    The native takes no character argument, so it applies to whoever the turn
    belongs to - which in this model is [ctx.ef_caster], the combatant the start
    of whose turn we are in.

    This is a latch, not a duration. [Combat.run_start_of_turn_effects] clears
    the battle's flag immediately before running the hooks, so a character that
    was blinded last turn can cast this one. *)
let hook_ebli = set_start_turn no_hooks (fun ctx _turn ->
    ctx.ef_battle.spells_disallowed <- true)

(** Disease: one off every pool, per turn.

    ```lua
    local numGems; -- not present
    SUBTRACT_MANA_AIR(characterIdx,1);
    SUBTRACT_MANA_EARTH(characterIdx,1);
    SUBTRACT_MANA_FIRE(characterIdx,1);
    SUBTRACT_MANA_WATER(characterIdx,1);
    ```

    The header says "-1 every mana each turn" and then the code names Air first,
    which reads like Air only. It is all four. Stacks 4, so four copies drain
    four a turn. *)
let hook_edis = set_start_turn no_hooks (fun ctx _turn ->
    List.iter (fun e -> drain ctx.ef_caster e 1) all_pools)

(** Poison: one life, per turn, and only while there is life to lose.

    ```lua
    if (GET_LIFE(characterIdx) > 0) then
        SUBTRACT_LIFE(characterIdx,1,characterIdx);
    ```

    The guard matters at the end of a fight: a character on 0 life does not go
    to -1, so a defeated monster's poison cannot tick it further negative. *)
let hook_epoi = set_start_turn no_hooks (fun ctx _turn ->
    let c = ctx.ef_caster in
    if life c > 0 then c.life <- life c - 1)

(** Paladin's Aura: two of each pool, per turn.

    ```lua
    ADD_MANA_AIR(characterIdx,2); ADD_MANA_EARTH(characterIdx,2);
    ADD_MANA_FIRE(characterIdx,2); ADD_MANA_WATER(characterIdx,2);
    ```

    [give] goes through [credit_mana], so a pool already at its ceiling gains
    nothing. Against the default ceiling of 20 that only matters once a pool is
    nearly full. *)
let hook_epau = set_start_turn no_hooks (fun ctx _turn ->
    List.iter (fun e -> give ctx.ef_caster e 2) all_pools)

(** Fire Bombed: five damage to an enemy, once the caster has 12 Fire.

    ```lua
    if (GET_MANA_FIRE(characterIdx) >= 12) then
        local idxEnemy = GET_ENEMY(characterIdx,0);
        Std_InflictDamage(5,idxEnemy);
    ```

    [Std_InflictDamage] hits the first enemy only, which in a one-on-one battle
    is all of them. Stacks 4, so four copies deal twenty.

    This is the one start-turn hook that needs [ctx.ef_enemies], which is the
    reason the context carries it. *)
let hook_efbo = set_start_turn no_hooks (fun ctx _turn ->
    if Combat.mana ctx.ef_caster Fire >= 12 then
      List.iter (fun e -> e.life <- max 0 (life e - 5)) ctx.ef_enemies)

(* ------------------------------------------------------------------ *)
(* OnExtraTurn - one script                                             *)
(* ------------------------------------------------------------------ *)

(** Hasted: four damage to the enemies whenever its owner gets an extra turn.

    ```lua
    local function OnExtraTurn(characterIdx)
        Std_InflictDamage(4,characterIdx);
    ```

    Read carefully: the argument is [idxCaster], and [Std_InflictDamage] deals to
    the *enemy of* its first argument. So this damages the Hasted character's
    enemies, not the Hasted character. It is the mirror of Fire Bombed, which
    passes [idxEnemy] explicitly for the same effect.

    [Combat.run_extra_turn_effects] is called once per banked extra turn, which
    is where the "+4 damage to your enemies" in the header comes from. *)
let hook_ehas = set_extra_turn no_hooks (fun ctx ->
    List.iter (fun e -> e.life <- max 0 (life e - 4)) ctx.ef_enemies)

(* ------------------------------------------------------------------ *)
(* OnGiveDamage - four scripts                                          *)
(* ------------------------------------------------------------------ *)

(** Challenged: half again as much damage, but only when {e both} sides carry it.

    ```lua
    if (HAS_STATUS_EFFECT(sourceIdx,STATUS_EFFECT_CHALLENGED) and
        HAS_STATUS_EFFECT(targetIdx,STATUS_EFFECT_CHALLENGED)) then
        damage = damage + (damage/2);
    end
    return damage;
    ```

    The bonus is symmetric and needs both characters, which is why the give-damage
    hook is handed the defender as well as the caster. A lone Challenged does
    nothing at all.

    [damage/2] is Lua division, so an odd hit loses its remainder: 5 becomes 7,
    not 8. *)
let hook_echa = set_give_damage no_hooks (fun ctx damage ->
    match ctx.ef_target with
    | Some t when has ctx.ef_caster "ECHA" && has t "ECHA" -> damage + (damage / 2)
    | _ -> damage)

(** Hand of Powered: two extra on everything.

    ```lua
    local function OnGiveDamage(damage,sourceIdx,targetIdx)
        return damage + 2;
    end
    ```

    Stacks 2, so two copies make it plus four. *)
let hook_ehop = set_give_damage no_hooks (fun _ctx damage -> damage + 2)

(** Hidden: double damage, until the owner is hit.

    ```lua
    local function OnGiveDamage(damage,sourceIdx,targetIdx)
        ADD_EFFECT_TO_CHARACTER(sourceIdx,"CyanSparkle");
        return damage * 2;
    end
    ```

    The cancellation is in [ehid_recv] - being hit is what ends it, not dealing
    damage. The two are combined into one [hooks] record in [hooks_of], since
    Hidden is the only script with both. *)
let ehid_give (_ctx : status_context) (damage : int) : int = damage * 2

(** Singing Blades: four off every one of the {e target's} pools when it hits.

    ```lua
    local mana = GET_MANA_EARTH(targetIdx);
    mana = mana-4; if (mana < 0) then mana = 0; end
    SET_MANA_EARTH(targetIdx,mana);
    -- ... and the same for Fire, Air and Water
    return damage;
    ```

    It is a read, a floor at zero and a write, repeated four times, and it acts on
    [targetIdx] - the character being hit, not the one swinging. [drain] is that
    read-modify-write; the [SET_MANA] ceiling clamp is a no-op here because the
    value only ever goes down. *)
let hook_esbl = set_give_damage no_hooks (fun ctx damage ->
    (match ctx.ef_target with
    | Some t -> List.iter (fun e -> drain t e 4) all_pools
    | None -> ());
    damage)

(* ------------------------------------------------------------------ *)
(* OnReceiveDamage - four scripts                                       *)
(* ------------------------------------------------------------------ *)

(** Fire Shielded: one off anything bigger than one.

    ```lua
    if (damage > 1) then damage = damage - 1; end
    return damage;
    ```

    [> 1] and not [>= 1], so a hit of exactly one is not reduced to nothing. *)
let hook_efsh = set_receive_damage no_hooks (fun _ctx damage ->
    if damage > 1 then damage - 1 else damage)

(** Hidden's other half: being hit ends it.

    ```lua
    local function OnReceiveDamage(damage,sourceIdx,targetIdx)
        local idx = GET_STATUS_EFFECT_INDEX(targetIdx,STATUS_EFFECT_HIDDEN);
        SET_STATUS_EFFECT_DURATION(targetIdx,idx,1);
        return damage;
    end
    ```

    This is why [set_effect_duration] sets 1 rather than removing the entry: the
    owner keeps doubling damage until the next tick, then it lapses. Note it does
    not reapply a duration - it overwrites whatever was left, so a Hidden applied
    an instant before being hit still dies on the following tick. *)
let ehid_recv (ctx : status_context) (damage : int) : int =
  set_effect_duration ctx.ef_caster "EHID" 1;
  damage

(** Wall of Fire and Wall of Thorns: damage comes out of a mana pool instead of
    life, and the wall falls when the pool runs out.

    ```lua
    local red_mana = GET_MANA_FIRE(targetIdx);
    local mana_damage = damage;
    damage = 0;
    if (red_mana - mana_damage <= 0) then
        damage = mana_damage - red_mana;
        mana_damage = red_mana;
        local idx = GET_STATUS_EFFECT_INDEX(targetIdx,STATUS_EFFECT_WALLOFFIRE);
        SET_STATUS_EFFECT_DURATION(targetIdx,idx,1);
    end
    if (mana_damage > 0) then SUBTRACT_MANA_FIRE(targetIdx,mana_damage); end
    return damage;
    ```

    Read the shape rather than the individual lines: the whole of the damage is
    absorbed, and only the part that does not fit in the pool comes back out as
    life. So 10 damage into 4 Fire deals **6** and ends the wall.

    The comparison is `<= 0`, not `< 0`, so a hit that exactly empties the pool
    also breaks the wall and deals 0. A wall with 0 mana absorbs the first point
    of anything and dies doing it.

    [<] and [>] matter on the overflow: `mana_damage - red_mana` is the excess,
    and [red_mana] is what gets drained. *)
let wall_of ~(pool : element) ~(id : string) (ctx : status_context) (damage : int) : int =
  let c = ctx.ef_caster in
  let held = Combat.mana c pool in
  if held - damage <= 0 then begin
    (* The wall breaks. Whatever does not fit comes off life, and the effect is
       scheduled to lapse. *)
    let overflow = damage - held in
    set_effect_duration c id 1;
    drain c pool held;
    overflow
  end
  else begin
    drain c pool damage;
    0
  end

let ewof_recv = wall_of ~pool:Fire ~id:"EWOF"
let ewot_recv = wall_of ~pool:Earth ~id:"EWOT"

(** The walls' other half, and it is easy to miss because the file lists
    [OnReceiveDamage] before [OnStartTurn] and the start-turn one is what keeps
    the wall fed:

    ```lua
    local function OnStartTurn(characterIdx,turnNumber)
        SUBTRACT_MANA_FIRE(characterIdx,2);
        if (GET_MANA_FIRE(characterIdx) <= 0) then
            local idx = GET_STATUS_EFFECT_INDEX(characterIdx,STATUS_EFFECT_WALLOFFIRE);
            SET_STATUS_EFFECT_DURATION(characterIdx,idx,1);
        end
    end
    ```

    So the wall costs its owner two Fire a turn to stand there, and falls when
    the pool empties. `<= 0` again, so draining the last two breaks it - and it
    breaks on the turn the pool empties, not the turn after.

    Without this a wall is free to stand on indefinitely, which is exactly what
    happened the first time this was written. *)
let wall_bleed ~(pool : element) ~(id : string) (ctx : status_context) (_turn : int) : unit =
  let c = ctx.ef_caster in
  drain c pool 2;
  if Combat.mana c pool <= 0 then set_effect_duration c id 1

let ewof_start = wall_bleed ~pool:Fire ~id:"EWOF"
let ewot_start = wall_bleed ~pool:Earth ~id:"EWOT"

(* ------------------------------------------------------------------ *)
(* OnQuerySkill - two scripts                                           *)
(* ------------------------------------------------------------------ *)

(** Enraged: Battle skill gains the caster's Fire pool.

    ```lua
    if (skillIdx == SKILL_BATTLE) then
        value = value + GET_MANA_FIRE(characterIdx);
    end
    return value;
    ```

    So it is Battle {e plus} Fire, not Battle doubled and not Fire raised. It
    reads the pool directly rather than going through the skill fold, so it does
    not compound with itself and does not see Fear's halving. *)
let hook_eenr =
  set_query_skill no_hooks (fun ctx k value ->
    if k = SBattle then value + Combat.mana ctx.ef_caster Fire else value)

(** Fear: every skill halved.

    ```lua
    local function OnQuerySkill(value,characterIdx,skillIdx)
        return value/2;
    end
    ```

    It ignores [skillIdx] entirely, so this is all seven skills and not just
    Battle. [Combat.skill_of] only routes the four elemental reads through the
    fold, which is why a Fear halves a character's Battle skill in the extra-turn
    roll but says nothing about the other three elements' reads - those do not go
    through [query_skill] yet. See the note in COMBAT_FLOW.md. *)
let hook_efea = set_query_skill no_hooks (fun _ctx _k value -> value / 2)

(* ------------------------------------------------------------------ *)
(* OnReceiveXP - one script                                             *)
(* ------------------------------------------------------------------ *)

(** Favored: each point of experience is a coin flip for one point of healing.

    ```lua
    local amt_heal = 0;
    for i = 1,value do
        if (PERCENTILE_CHANCE_SYNC() <= 50) then amt_heal = amt_heal + 1; end
    end
    if (amt_heal > 0) then ADD_LIFE(characterIdx,amt_heal); end
    return value;
    ```

    **A fresh roll per point.** That is the whole behaviour and it is why the
    context carries a roll function rather than reusing the battle's one
    percentile: 10 experience is ten independent 50% rolls, which averages five
    healing, not one roll of "50% of 10".

    `<= 50` on a 0..99 draw is 51 chances in 100, so the expected value is
    slightly above half. Faithful rather than corrected.

    The header's "1XP = 50% chance of Healing" describes this correctly.

    The XP is returned unchanged, so the battle total still gets all of it; only
    the healing is extra. *)
let hook_efav = set_receive_xp no_hooks (fun ctx value ->
    let healed = ref 0 in
    for _ = 1 to value do
      if ctx.ef_roll 100 <= 50 then incr healed
    done;
    if !healed > 0 then begin
      (* [add_life] clamps at max, so a full character banks nothing. *)
      let c = ctx.ef_caster in
      let room = max 0 (max_life c - life c) in
      c.life <- life c + min room !healed
    end;
    value)

(* ------------------------------------------------------------------ *)
(* OnMatch4 / OnMatch5 - one script, two hooks                          *)
(* ------------------------------------------------------------------ *)

(** Vigiled: three of each pool on a 4-run or a 5-run.

    ```lua
    local function ManaGain(characterIdx)
        ADD_MANA_AIR(characterIdx,3); ADD_MANA_EARTH(characterIdx,3);
        ADD_MANA_FIRE(characterIdx,3); ADD_MANA_WATER(characterIdx,3);
    end
    local function OnMatch4(characterIdx) ManaGain(characterIdx); end
    local function OnMatch5(characterIdx) ManaGain(characterIdx); end
    ```

    **Three, not five.** The header says "gain 5 of each mana" and the code adds
    3. The header is stale; this is transcribed as the code reads. Both hooks are
    the same body, which is why they are built from one function.

    Returns nothing in the Lua, and these hooks are typed [unit] to match - see
    the note on [Combat.run_match_effects]. *)
let vigiled_gain (ctx : status_context) : unit =
  List.iter (fun e -> give ctx.ef_caster e 3) all_pools

(* Both hooks are the same body, so [hooks_of] installs the same function twice
   rather than building two near-identical records. *)

(* ------------------------------------------------------------------ *)
(* Assembly                                                            *)
(* ------------------------------------------------------------------ *)

(** The hooks for one id, or [None] for an id with no script. Every one of the
    seventeen has one; [None] exists so a future id with no port is visible
    rather than silently inert. *)
let hooks_of (id : string) : hooks option =
  match id with
  | "EBLI" -> Some hook_ebli
  | "ECHA" -> Some hook_echa
  | "EDIS" -> Some hook_edis
  | "EENR" -> Some hook_eenr
  | "EFAV" -> Some hook_efav
  | "EFBO" -> Some hook_efbo
  | "EFEA" -> Some hook_efea
  | "EFSH" -> Some hook_efsh
  | "EHAS" -> Some hook_ehas
  | "EHID" ->
      (* Hidden is the only script with both a give-damage and a
         receive-damage hook. *)
      Some
        { no_hooks with
          on_give_damage = Some ehid_give
        ; on_receive_damage = Some ehid_recv }
  | "EHOP" -> Some hook_ehop
  | "EPAU" -> Some hook_epau
  | "EPOI" -> Some hook_epoi
  | "ESBL" -> Some hook_esbl
  | "EVIG" ->
      Some
        { no_hooks with
          on_match4 = Some vigiled_gain
        ; on_match5 = Some vigiled_gain }
  | "EWOF" ->
      Some
        { no_hooks with
          on_start_turn = Some ewof_start
        ; on_receive_damage = Some ewof_recv }
  | "EWOT" ->
      Some
        { no_hooks with
          on_start_turn = Some ewot_start
        ; on_receive_damage = Some ewot_recv }
  | _ -> None

(** The generated table with the ported bodies attached. This is what a battle
    should be given; [Status_effect_data.descriptors] on its own is inert data. *)
let descriptors : effect_def list =
  List.map
    (fun (d : effect_def) ->
      match hooks_of d.id with
      | Some h -> { d with hooks = h }
      | None -> d)
    Status_effect_data.descriptors

(** Ids with a descriptor but no ported body, so a gap can be measured rather
    than assumed. Empty: all seventeen are ported. *)
let known_unported : string list =
  List.filter_map
    (fun (d : effect_def) -> if hooks_of d.id = None then Some d.id else None)
    Status_effect_data.descriptors