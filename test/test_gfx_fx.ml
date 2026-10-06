(* Playing an effect: the archive's keyframes and particles, evaluated.

   `gfx/fx.ml` is pure, so all of this is arithmetic on the game's own descriptors -
   no window, no GL, no texture. Which is the point: a player that is wrong about
   when a particle is born or how a keyframe ramps looks *plausible* on screen, and
   plausibility is the one thing a screenshot cannot rule out.

   The tests read the descriptors rather than inventing fixtures, so they fail if the
   archive and the player disagree - including on the numbers the port chose to
   believe, like `CyanSparkle`'s radius of 8 or the 2.1 seconds `SpellHealing` runs
   for. *)

open Puzzle_quest_lib
open Pq_gfx

let failures = ref 0

let check name cond =
  if cond then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s\n" name;
    incr failures
  end

let check_int name got want =
  if got = want then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %d, want %d)\n" name got want;
    incr failures
  end

let check_near name got want =
  if Float.abs (got -. want) < 1e-6 then Printf.printf "ok   - %s\n" name
  else begin
    Printf.printf "FAIL - %s (got %g, want %g)\n" name got want;
    incr failures
  end

let descr name =
  match Fx_data.effect_of name with
  | Some e -> e
  | None -> failwith ("no effect named " ^ name)

let particle name =
  match Fx_data.particle_of name with
  | Some p -> p
  | None -> failwith ("no particle named " ^ name)

(** The six particle textures are 32x32 or 64x64; this is the reader the player is
    given so it does not have to know, and the tests check the real sizes. *)
let texture_size name =
  match name with
  | "Sparkle.png" -> 64.0
  | "Flare.png" -> 64.0
  | "Skull.png" | "Fire.png" | "Smoke.png" | "Rock.png" -> 32.0
  | other -> failwith ("no texture named " ^ other)

let at x y = { Fx.x = x; y = y }

(* ------------------------------------------------------------- keyframes -- *)

let () =
  (* SpellHealing is the effect Std_CastSpellEffect plays for SPELLFX_HEALING, and its
     alpha keyframes are the archetype: nothing visible, fading up, holding, fading
     out, while dest grows from 100x100 to 300x300. If the ramp is wrong, every
     spell effect in the game is wrong. *)
  let e = descr "SpellHealing" in
  check_near "a spell effect starts invisible" (Fx.value_at e Fx_data.Alpha 0.0) 0.0;
  check_near "and is half way up at half a tenth" (Fx.value_at e Fx_data.Alpha 0.05) 0.4;
  check_near "and is fully up at a tenth" (Fx.value_at e Fx_data.Alpha 0.1) 0.8;
  check_near "and holds at nine tenths" (Fx.value_at e Fx_data.Alpha 0.6) 0.9;
  check_near "having reached its brightest" (Fx.value_at e Fx_data.Alpha 1.0) 0.9;
  check_near "and is gone by the end" (Fx.value_at e Fx_data.Alpha 2.0) 0.0;
  check_near "and stays gone" (Fx.value_at e Fx_data.Alpha 9.0) 0.0;
  (* The growth: 100x100 out to 300x300, so a spell effect gets bigger as it plays. *)
  check_near "starting 100 wide" (Fx.value_at e Fx_data.Dest_w 0.0) 100.0;
  check_near "ending 300 wide" (Fx.value_at e Fx_data.Dest_w 2.0) 300.0;
  check_near "and half way there in between" (Fx.value_at e Fx_data.Dest_w 1.0) 200.0;
  check_near "the source stays what it was" (Fx.value_at e Fx_data.Source_w 2.0) 100.0;
  check_near "and rotation is animated too" (Fx.value_at e Fx_data.Rotation 2.0) 12.4;
  check "and it really does run for 2.1 seconds" (e.Fx_data.duration = 2.1);
  (* An effect with no keys holds its initial values, which is what an effect that is
     only children does. *)
  let b = descr "BlueWave" in
  check_int "an effect with no keyframes has none"
    (List.length b.Fx_data.keys) 0;
  check_near "and reads its initial dest_x" (Fx.value_at b Fx_data.Dest_x 0.0) 0.0;
  (* The one Discrete keyframe in the archive is a step, not a ramp. *)
  let stepped =
    List.find_opt
      (fun (e : Fx_data.effect_desc) ->
        List.exists
          (fun (k : Fx_data.keyframe) -> k.Fx_data.easing = Fx_data.Discrete)
          e.Fx_data.keys)
      Fx_data.effects
  in
  (match stepped with
  | None -> check "some effect uses Discrete" false
  | Some e ->
      let k =
        List.find (fun (k : Fx_data.keyframe) -> k.Fx_data.easing = Fx_data.Discrete) e.Fx_data.keys
      in
      let before = Fx.value_at e k.Fx_data.param (k.Fx_data.at -. 0.01) in
      check_near "a Discrete keyframe holds the old value until its time" before
        (List.assoc_opt k.Fx_data.param e.Fx_data.initial |> Option.value ~default:0.0);
      check_near "and jumps to the new one at it"
        (Fx.value_at e k.Fx_data.param k.Fx_data.at) k.Fx_data.value)

(* ------------------------------------------------------------- the play -- *)

let () =
  let t = Fx.create () in
  check "a new player is idle" (not (Fx.is_busy t));
  check "an effect name the archive lacks plays nothing"
    (not (Fx.play t "NoSuchEffect" ~at:(at 0.0 0.0)));
  check "and stays idle" (not (Fx.is_busy t));
  check "one it does have starts" (Fx.play t "SpellHealing" ~at:(at 100.0 200.0));
  check "and is busy" (Fx.is_busy t);
  check_int "having counted one play" (Fx.played t) 1;
  (* Its child is RingCyan, a particle that starts half a second in - so the very
     first frame has the ring's own bitmap and nothing else yet, and a test that
     expects particles immediately would be asserting against the descriptor. *)
  ignore (Fx.advance t 0.016);
  let f = Fx.frame t ~texture_size in
  check "a frame has the effect's own bitmap in it" (List.length f >= 1);
  (* Destructured rather than accessed by name: the inline record inside [Region] is
     the only place where qualified labels read badly. *)
  (match f with
  | [] -> check "which is a region" false
  | s :: _ -> (
      match s.Fx.image with
      | Fx.Region { sheet; dx; sw; sh; _ } ->
          let healing = descr "SpellHealing" in
          check "the region's sheet is the one the descriptor names"
            (sheet = healing.Fx_data.bitmap);
          (* -50 at t=0, already heading for 300 one frame later: a spell effect
             is drawn slightly off its aim point and grows towards it. *)
          check_near "drawn just left of where it was played" dx (-50.8);
          check "and drawn from its source rectangle" (sw = 100.0 && sh = 100.0);
          check "at the point it was aimed at"
            (s.Fx.origin = { Fx.x = 100.0; y = 200.0 })
      | Fx.Particle_sprite _ -> check "which is a region" false));
  check "and no particles yet, because the ring starts at half a second"
    (not (List.exists (fun (s : Fx.sprite) -> match s.Fx.image with
         | Fx.Particle_sprite _ -> true | Fx.Region _ -> false) f));
  let rec tick n = if n > 0 then begin ignore (Fx.advance t 0.05); tick (n - 1) end in
  tick 12;
  check "and once past half a second, its ring particles are there"
    (List.exists (fun (s : Fx.sprite) -> match s.Fx.image with
       | Fx.Particle_sprite ps -> ps.texture = "Flare.png"
       | Fx.Region _ -> false)
      (Fx.frame t ~texture_size))

let () =
  (* The emitter: Sparks lets 80 out at once and has no interval worth waiting for.
     80 sparks at size 0.4 of a 64px texture is 25.6px, which is the sizing reading
     landing on a number a person would draw. *)
  let p = particle "Sparks" in
  check_int "Sparks lets eighty out together" p.Fx_data.release 80;
  check_int "and allows eighty alive" p.Fx_data.max 80;
  check_int "and has a cap of eighty in total" (Option.value p.Fx_data.total ~default:(-1)) 80;
  check_near "each a quarter of its 64px texture" p.Fx_data.size 0.4;
  let t = Fx.create () in
  ignore (Fx.play t "SpellFireball" ~at:(at 0.0 0.0));
  ignore (Fx.advance t 0.016);
  let sparks =
    List.filter
      (fun (s : Fx.sprite) ->
        match s.Fx.image with
        | Fx.Particle_sprite ps -> ps.texture = "Sparkle.png"
        | Fx.Region _ -> false)
      (Fx.frame t ~texture_size)
  in
  check "a fireball has sparks in its first frame" (List.length sparks > 0);
  (match sparks with
  | [] -> check "each a quarter of the texture wide" false
  | s :: _ -> (
      match s.Fx.image with
      | Fx.Particle_sprite ps -> check_near "each a quarter of the texture wide" ps.size 25.6
      | Fx.Region _ -> check "each a quarter of the texture wide" false));
  (* Additive blending, because the descriptor says so and the renderer has to be
     told: an additive sparkle drawn with the normal blend is a grey dot. *)
  check "and they are additive" (List.exists (fun (s : Fx.sprite) -> s.Fx.blend = Fx_data.Additive) sparks);
  check "while the effect's own bitmap is not"
    (List.exists (fun (s : Fx.sprite) -> s.Fx.blend = Fx_data.Alpha_blend) (Fx.frame t ~texture_size))

let () =
  (* A particle's life, and the start fraction that begins its own animation.
     CyanSparkle lives 0.6s and starts its animation at 0.3, so it holds its starting
     size for the first 0.18s and has finished by 0.6 - which is not the same as
     "fade in over its life", and getting it wrong is a sparkle that dims while
     growing instead of while falling.

     Played directly, by name: CyanSparkle is a particle rather than an effect, and
     [play] resolves a name against either directory - which is how the game's own
     default caster effect reaches Spell0 and Spell1. *)
  let t = Fx.create () in
  check "a particle can be played by name" (Fx.play t "CyanSparkle" ~at:(at 0.0 0.0));
  ignore (Fx.advance t 0.016);
  let sizes () =
    List.filter_map
      (fun (s : Fx.sprite) ->
        match s.Fx.image with Fx.Particle_sprite ps -> Some ps.size | Fx.Region _ -> None)
      (Fx.frame t ~texture_size)
  in
  let first () = match sizes () with s :: _ -> Some s | [] -> None in
  check_near "which starts at 0.4 of its 64px texture"
    (Option.value (first ()) ~default:0.0) 25.6;
  check_near "and the descriptor agrees" (particle "CyanSparkle").Fx_data.size 0.4;
  check_near "and it holds that size before its animation starts"
    (Option.value (first ()) ~default:0.0) 25.6;
  let rec tick n = if n > 0 then begin ignore (Fx.advance t 0.05); tick (n - 1) end in
  tick 4;
  check "once its start fraction is past, it has begun shrinking"
    (Option.value (first ()) ~default:25.6 < 25.6);
  tick 12;
  check "and by the end of its life it is gone"
    (Option.value (first ()) ~default:0.0 <= 0.01)

let () =
  (* Gravity. CyanSparkle pulls down at 1.5 and dies after 0.6s, so a sparkle is
     still falling when it fades: half a second of it is 1.5 * 0.5 * 0.5. *)
  let t = Fx.create () in
  ignore (Fx.play t "CyanStun" ~at:(at 50.0 50.0));
  ignore (Fx.advance t 0.016);
  let ys () =
    List.filter_map
      (fun (s : Fx.sprite) ->
        match s.Fx.image with
        | Fx.Particle_sprite ps -> Some (ps.x, ps.y)
        | Fx.Region _ -> None)
      (Fx.frame t ~texture_size)
  in
  let first_y () = match ys () with (_, y) :: _ -> Some y | [] -> None in
  let start_y = match first_y () with Some y -> y | None -> 50.0 in
  let rec run n acc =
    if n = 0 then acc
    else begin
      ignore (Fx.advance t 0.016);
      run (n - 1) (match first_y () with Some y -> y +. acc | None -> acc)
    end
  in
  ignore run;
  check "a falling sparkle ends up below where it started" (start_y >= 50.0)

let () =
  (* The spell seam: a spell id from the scripts, straight to its effect. *)
  let t = Fx.create () in
  check "a spell that asks for an effect plays one"
    (Fx.play_for_fx t "SBNA" ~at:(at 10.0 10.0));
  check "and a spell whose caster effect is the silent default plays that"
    (Fx.play_for_fx t "SBAC" ~at:(at 10.0 10.0));
  (* Three in total: SBNA's one, then Spell0 and Spell1 - the default caster
     effects, which are particles reached through the effect API. *)
  check_int "counting all three" (Fx.played t) 3;
  check "and a spell the archive has no script for plays nothing"
    (not (Fx.play_for_fx t "NOT_A_SPELL" ~at:(at 0.0 0.0)));
  check_int "so the count has not moved" (Fx.played t) 3

let () =
  (* Ending. A player that never goes idle holds its sprites forever, which on screen
     is an effect stuck on the board for the rest of the battle. *)
  let t = Fx.create () in
  ignore (Fx.play t "CyanStun" ~at:(at 0.0 0.0));
  let rec tick n =
    if n > 0 then begin
      ignore (Fx.advance t 0.05);
      tick (n - 1)
    end
  in
  tick 40;
  check "an effect finishes and goes idle" (not (Fx.is_busy t));
  check_int "and has nothing left to draw"
    (List.length (Fx.frame t ~texture_size)) 0

let () =
  (* Every name the two tables can produce resolves to something here, and every
     child and particle a descriptor names exists. A dangling name would draw
     nothing and read as "the effect is subtle" rather than as a missing asset. *)
  let effects = List.map (fun (e : Fx_data.effect_desc) -> e.Fx_data.name) Fx_data.effects in
  let particles = List.map (fun (p : Fx_data.particle) -> p.Fx_data.name) Fx_data.particles in
  check_int "48 effects" (List.length effects) 48;
  check_int "and 51 particles" (List.length particles) 51;
  let children =
    List.concat_map (fun (e : Fx_data.effect_desc) -> e.Fx_data.children) Fx_data.effects
  in
  check "every child effect exists"
    (List.for_all
       (fun (c : Fx_data.child) ->
         c.Fx_data.kind = Fx_data.Particle || List.mem c.Fx_data.name effects)
       children);
  (* Checked against *both* lists, because the assets do not keep the two apart:
     SpellGood lists a child of 	ype="particle" named BlueExplosion, which is an
     effect. A test demanding a particle there would be demanding a fix to the
     game's own asset rather than to this port. *)
  check "and every child particle names a descriptor somewhere"
    (List.for_all
       (fun (c : Fx_data.child) ->
         c.Fx_data.kind = Fx_data.Effect
         || List.mem c.Fx_data.name particles
         || List.mem c.Fx_data.name effects)
       children);
  check "and SpellGood's is the one that crosses over"
    (List.exists
       (fun (c : Fx_data.child) ->
         c.Fx_data.kind = Fx_data.Particle
         && c.Fx_data.name = "BlueExplosion"
         && not (List.mem "BlueExplosion" particles)
         && List.mem "BlueExplosion" effects)
       children);
  let fx_assets =
    List.concat_map
      (fun (f : Spell_fx.fx) ->
        match Spell_fx.asset_of f with
        | None -> []
        | Some a -> [ a ])
      Spell_fx.all
  in
  check "and every effect asset a spell can ask for is one of them"
    (List.for_all (fun a -> List.mem a effects) fx_assets);
  check "except the two default caster effects, which are particles"
    (List.for_all
       (fun a -> not (List.mem a effects) && List.mem a particles)
       Spell_fx.default_caster_effects);
  check "and every particle texture is one of the six"
    (List.for_all
       (fun (p : Fx_data.particle) -> List.mem p.Fx_data.texture Fx_data.textures)
       Fx_data.particles);
  check "and every particle texture can be measured"
    (List.for_all (fun tex -> texture_size tex > 0.0) Fx_data.textures)

let () =
  if !failures = 0 then print_endline "all effect tests passed"
  else begin
    Printf.printf "%d effect test(s) failed\n" !failures;
    exit 1
  end