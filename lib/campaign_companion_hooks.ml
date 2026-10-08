(* OnStartBattle for the ten party companions, hand-ported from
   game/Assets/Assets/Companions/*.lua. Each script declares a single hook
   that runs when the battle opens; the scripts differ only in their guard
   and their payoff, so they are held here as a rule table:

     OnEnemyType  CHECK_TYPE(other, ...), any-of
     OnChance     PERCENTILE_CHANCE_SYNC() < pct, plus the script's own
                  follow-up guard on the enemy's life
     OnEnemyFire  GET_SKILL(other, SKILL_FIRE) >= n

   ...over five payoffs: SUBTRACT_LIFE on the enemy, a resistance or skill
   bump on the hero, a mana bonus on the hero, or the halved enemy bank
   (NWIN's four SET_MANA_* writes).

   The element names come from the engine's own: MANA_BLUE is Water and
   MANA_YELLOW is Air, the mapping the spell-effect recon already pinned
   down (lib/spell_effects.ml). IS_MONSTER(other) is always true here -
   road and quest enemies are monsters by construction - so it is not
   modelled as a check. PERCENTILE_CHANCE_SYNC is the shared engine roll,
   which in a battle is the battle's own rng.

   Activations return as data ([result]) rather than a log write: the
   [SPELL_EFFECT_DAMAGE2] line and its snd_redskull sound have no log event
   of their own, so the caller rides each hit on the existing [Damage]
   event, where the float-text layer already reads damage from. *)

open Combat

type payoff =
  | Hit of int  (** SUBTRACT_LIFE on the enemy *)
  | Resist of element * int  (** ADD_TEMP_RESISTANCE on the hero *)
  | SkillBonus of skill * int  (** ADD_TEMP_SKILL on the hero *)
  | ManaBonus of element * int  (** ADD_MANA_<E> on the hero *)
  | HalveEnemyMana  (** NWIN: SET_MANA_* the enemy's four banks to half *)

type rule =
  | OnEnemyType of string list * payoff
  | OnChance of int * payoff  (** roll pct, then Hit's life guard *)
  | OnEnemyFire of int * payoff

(* The ten scripts, read body by body. NDKH/NDRO/NPAT damage the enemy;
   NELI/NFLI resistances, NKHA/NSER the battle skill, NSUN/NSUS hero fire
   mana, NWIN the enemy bank. *)
let rules : (string * rule) list =
  [
    ("NDKH", OnEnemyType ([ "Undead" ], Hit 10));
    ("NDRO", OnEnemyType ([ "Animal" ], Hit 10));
    ("NELI", OnEnemyType ([ "Large" ], Resist (Water, 10)));
    ("NFLI", OnEnemyType ([ "Flying" ], Resist (Air, 10)));
    ("NKHA", OnEnemyType ([ "Machine"; "City" ], SkillBonus (SBattle, 10)));
    ("NSER", OnEnemyType ([ "Good" ], SkillBonus (SBattle, 10)));
    ("NSUN", OnEnemyType ([ "Minotaur" ], ManaBonus (Fire, 10)));
    ("NSUS", OnEnemyType ([ "Undead"; "Minotaur" ], ManaBonus (Fire, 10)));
    ("NPAT", OnChance (20, Hit 25));
    ("NWIN", OnEnemyFire (15, HalveEnemyMana));
  ]

type result = {
  activated : string list;  (** companions whose effect fired, party order *)
  damaged : (string * int) list;  (** target name and damage, per hit *)
}

let apply_effect ~hero ~enemy eff : (string * int) list =
  match eff with
  | Hit amt ->
      enemy.life <- max 0 (enemy.life - amt);
      if enemy.life < 1 then enemy.is_dead <- true;
      [ (enemy.name, amt) ]
  | Resist (e, n) ->
      add_resistance hero e n;
      []
  | SkillBonus (s, n) ->
      hero.skills <- add_skill s n hero.skills;
      []
  | ManaBonus (e, n) ->
      hero.mana <- add_mana e n hero.mana;
      []
  | HalveEnemyMana ->
      let m = enemy.mana in
      enemy.mana <-
        {
          earth = m.earth / 2;
          fire = m.fire / 2;
          air = m.air / 2;
          water = m.water / 2;
        };
      []

let apply_one ~rng ~hero ~enemy ~enemy_types id : bool * (string * int) list =
  match List.assoc_opt id rules with
  | None -> (false, [])
  | Some rule -> (
      let fire eff = (true, apply_effect ~hero ~enemy eff) in
      match rule with
      | OnEnemyType (types, eff) ->
          if List.exists (fun t -> List.mem t enemy_types) types then fire eff
          else (false, [])
      | OnChance (pct, eff) -> (
          match eff with
          | Hit amt ->
              if rng () < pct && enemy.life > amt then fire eff else (false, [])
          | _ -> if rng () < pct then fire eff else (false, []))
      | OnEnemyFire (n, eff) ->
          if skill_in SFire enemy.skills >= n then fire eff else (false, []))

(* Fire each party companion once, in party order - the [seen] pass keeps a
   duplicated id from running twice. Unknown ids are inert. *)
let apply_start_battle ?(rng = fun () -> 100) ~hero ~enemy ~enemy_types
    ~companions () : result =
  let seen = ref [] in
  List.fold_left
    (fun (act, dmg) id ->
      if List.mem id !seen then (act, dmg)
      else begin
        seen := id :: !seen;
        let fired, d = apply_one ~rng ~hero ~enemy ~enemy_types id in
        ((if fired then act @ [ id ] else act), dmg @ d)
      end)
    ([], []) companions
  |> fun (activated, damaged) -> { activated; damaged }
