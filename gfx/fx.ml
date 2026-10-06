(** Playing an effect: the game's own keyframes and particles, evaluated in OCaml.

    `Fx_data` is the archive's descriptors as data. This is the part that turns them
    into positions, and it is deliberately pure - no GL, no SDL - so the timing can
    be asserted rather than watched. It is the same split as `Anim`, and for the same
    reason: everything that can be wrong about a cascade is geometry and arithmetic,
    and geometry and arithmetic are testable without a window.

    The reading of the descriptors is ours in three places, and each is a decision
    rather than a recovery, because the engine's particle code has not been read:

    - **`radius` and `size`.** `radius` is read as a percentage of the effect's own
      draw box (a spell effect's is 100x100, and `CyanSparkle`'s radius of 8 is 8% of
      that), and `size` as a multiple of the particle texture. The numbers land on
      sensible pixels - a 64x64 sparkle at size 0.4 is 26px - which is the only
      evidence offered for the reading.
    - **`Animate method`.** `linear` ramps from the previous value to this one across
      the gap since the previous keyframe on the same parameter; `discrete`, which
      appears once in 266 keyframes, jumps at its own time.
    - **`Animate time`** is seconds from the effect's start, and a keyframe past the
      effect's duration still counts, because three descriptors do that.

    Not interpreted at all: `shape_steps` (2 in seven particles), the planar `planes`
    codes and `AnimPosition`. A particle from a Ring - the one `SpellHealing` uses -
    is therefore emitted at its origin rather than around a ring, which is wrong in a
    way that is visible, and is recorded in the evidence database rather than papered
    over. Reading the engine's particle code would settle it. *)

open Puzzle_quest_lib

type point = { x : float; y : float }

(** What a sprite draws. A [Region] is a rectangle of a registry sheet, which is how
    an effect draws its own bitmap; a [Particle_sprite] is one of the six standalone
    particle textures, drawn centred and scaled. *)
type image =
  | Region of {
      sheet : string;
      sx : float;
      sy : float;
      sw : float;
      sh : float;
      dx : float;
      dy : float;
      dw : float;
      dh : float;
    }
  | Particle_sprite of { texture : string; x : float; y : float; size : float }

type sprite = {
  image : image;
  origin : point;
  (** Where the effect was played. Every position is relative to it, so a caller can
      draw a frame without knowing where anything was aimed. *)
  colour : Fx_data.colour;
  alpha : float;
  rotation : float;
  blend : Fx_data.blend;
}

type t = {
  rng : Random.State.t;
  mutable now : float;
  mutable live : live list;
  mutable running : running list;
  mutable played : int;
}

and running = {
  e : Fx_data.effect_desc;
  origin : point;
  offset : point;
  started : float;
  mutable spawned : bool list;  (** per child: has it been started yet *)
  mutable emitted : int;  (** particles this emitter has let out so far *)
  mutable next_release : float;  (** when the next batch of particles goes *)
}

and live = {
  p : Fx_data.particle;
  origin : point;
  born : float;
  vx : float;
  vy : float;
}

let create ?(seed = 7) () : t =
  { rng = Random.State.make [| seed |]; now = 0.0; live = []; running = []; played = 0 }

let now t = t.now
let is_busy t = t.running <> [] || t.live <> []
let played t = t.played

(* --------------------------------------------------------------- keyframes -- *)

let param_default _ = 0.0

let initial_of (e : Fx_data.effect_desc) : (Fx_data.param * float) list =
  e.Fx_data.initial

(** Every parameter's value at [at] seconds into an effect.

    Walks that parameter's keyframes in time order, carrying the previous value and
    the time it was set. The first keyframe ramps from the initial value, so an
    effect that animates alpha from 0 to 0.8 over its first tenth of a second does
    that whether or not the 0 was written down - and in these files it always is. *)
let value_at (e : Fx_data.effect_desc) (p : Fx_data.param) (at : float) : float =
  let initial =
    match List.assoc_opt p e.Fx_data.initial with
    | Some v -> v
    | None -> param_default p
  in
  let keys = List.filter (fun (k : Fx_data.keyframe) -> k.Fx_data.param = p) e.Fx_data.keys in
  (* Walks the parameter's keyframes carrying the last value actually reached, and
     ramps from there towards the *next* one - which is the part that is easy to get
     wrong. Stopping at the first keyframe in the future instead means an effect
     only ever changes value on the frame its keyframe lands, and animates in jumps.
     Every spell effect in the archive has a single keyframe per parameter, so that
     error shows up as "nothing animates smoothly" rather than as anything obviously
     wrong. *)
  let rec go prev_value prev_t = function
    | [] -> prev_value
    | (k : Fx_data.keyframe) :: rest ->
        if k.Fx_data.at <= at then go k.Fx_data.value k.Fx_data.at rest
        else
          let span = k.Fx_data.at -. prev_t in
          if span <= 0.0 then k.Fx_data.value
          else
            match k.Fx_data.easing with
            | Fx_data.Discrete -> if at >= k.Fx_data.at then k.Fx_data.value else prev_value
            | Fx_data.Linear ->
                let f = min 1.0 ((at -. prev_t) /. span) in
                prev_value +. ((k.Fx_data.value -. prev_value) *. f)
  in
  go initial 0.0 keys

let colour_at (e : Fx_data.effect_desc) (at : float) =
  let c v = max 0.0 (min 1.0 v) in
  {
    Fx_data.r = c (value_at e Fx_data.Colour_r at);
    g = c (value_at e Fx_data.Colour_g at);
    b = c (value_at e Fx_data.Colour_b at);
    a = c (value_at e Fx_data.Alpha at);
  }

(* ------------------------------------------------------------------ play -- *)

let rand (t : t) centre spread =
  if spread <= 0.0 then centre
  else centre +. ((Random.State.float t.rng (2.0 *. spread)) -. spread)

(** A descriptor by name, from either directory.

    The two are not cleanly separated in the shipped assets, and both cases are real
    rather than typos: `Std_CastSpellEffect`'s default case adds `Spell0` and
    `Spell1`, which are *particles*, through the effect API; and `SpellGood` lists a
    child of `type="particle"` named `BlueExplosion`, which is an *effect*. So a name
    is resolved against both, and a name in neither is still a silent no-op. *)
let descriptor_of (name : string) : Fx_data.effect_desc option =
  match Fx_data.effect_of name with
  | Some e -> Some e
  | None -> (
      match Fx_data.particle_of name with
      | None -> None
      | Some p ->
          Some
            {
              Fx_data.name = name;
              bitmap = "";
              duration = 0.0;
              children =
                [
                  {
                    Fx_data.name = p.Fx_data.name;
                    kind = Fx_data.Particle;
                    at = 0.0;
                    duration = 0.0;
                    x = 0.0;
                    y = 0.0;
                  };
                ];
              initial = [];
              keys = [];
            })

(** Start an effect at a point. An unknown name plays nothing.

    A name the archive does not have is a silent no-op rather than an error, for the
    same reason the audio mixer is: a presentation layer that raises because an asset
    is missing stops the battle, which is a far worse outcome than a missing sparkle. *)
let play (t : t) (name : string) ~(at : point) : bool =
  match descriptor_of name with
  | None -> false
  | Some e ->
      t.running <-
        {
          e;
          origin = at;
          offset = { x = 0.0; y = 0.0 };
          started = t.now;
          spawned = List.map (fun _ -> false) e.Fx_data.children;
          emitted = 0;
          next_release = t.now;
        }
        :: t.running;
      t.played <- t.played + 1;
      true

(** Play an effect by its `Spell_fx` constant's asset name, if the spell asks for one.

    This is the seam between the two generated modules: the spell's script named a
    `SPELLFX_*`, the constant names the effect asset, and the asset is one of the 48
    descriptors here. What is missing is the *cell* for a grid effect - the game takes
    it from the spell body, so a caller with a cell to offer can play it directly. *)
let play_for_fx (t : t) (spell_id : string) ~(at : point) : bool =
  let calls = Spell_fx.calls_of_spell spell_id in
  let assets =
    List.filter_map
      (fun (c : Spell_fx.call) ->
        if c.Spell_fx.target = Spell_fx.Grid then None
        else Spell_fx.asset_of c.Spell_fx.fx)
      calls
  in
  match (calls, assets) with
  (* A spell with no script at all plays nothing. Falling back to the default
     caster effects here would mean every unknown spell id flashed a sparkle, which
     is the sort of default that hides a lookup that has stopped working. *)
  | [], _ -> false
  (* The Default and Default_Gfx_Only cases: the helper adds Spell0 and Spell1
     itself rather than going through its table. *)
  | _, [] ->
      List.fold_left (fun any a -> play t a ~at || any) false
        Spell_fx.default_caster_effects
  | _, assets -> List.fold_left (fun any a -> play t a ~at || any) false assets

(* --------------------------------------------------------------- advance -- *)

(** One release of a particle emitter: 
elease particles, up to max alive. *)
let emit (t : t) (p : Fx_data.particle) ~(x : float) ~(y : float) : int =
  let alive =
    List.length (List.filter (fun (l : live) -> l.p.Fx_data.name = p.Fx_data.name) t.live)
  in
  let n = min p.Fx_data.release (max 0 (p.Fx_data.max - alive)) in
  for _ = 1 to n do
    t.live <-
      {
        p;
        origin =
          { x = x +. rand t 0.0 p.Fx_data.position_var;
            y = y +. rand t 0.0 p.Fx_data.position_var };
        born = t.now;
        vx = rand t p.Fx_data.velocity.Fx_data.x p.Fx_data.velocity_var;
        vy = rand t p.Fx_data.velocity.Fx_data.y p.Fx_data.velocity_var;
      }
      :: t.live
  done;
  n

(** Start the children whose time has come, and release from the particle ones again.

    The two are separate because the descriptors distinguish them: a Child names a
    duration and starts once, while a particle keeps releasing on its interval
    until it has let out 	otal of them - and 	otal absent means it never stops,
    which is the difference between a spark burst and a bonfire. *)
let pump (t : t) (r : running) =
  List.iteri
    (fun i (c : Fx_data.child) ->
      let started = List.nth r.spawned i in
      let child_x = r.origin.x +. r.offset.x +. c.Fx_data.x in
      let child_y = r.origin.y +. r.offset.y +. c.Fx_data.y in
      match c.Fx_data.kind with
      | Fx_data.Effect ->
          if (not started) && t.now -. r.started >= c.Fx_data.at then begin
            r.spawned <- List.mapi (fun j b -> if j = i then true else b) r.spawned;
            ignore (play t c.Fx_data.name ~at:{ x = child_x; y = child_y })
          end
      | Fx_data.Particle ->
          (* `type="particle"` names an emitter, but SpellGood's child says
             `particle` and names an effect, so this goes through the same
             either-directory lookup as [play]. *)
          if not started then begin
            if t.now -. r.started >= c.Fx_data.at then begin
              r.spawned <- List.mapi (fun j b -> if j = i then true else b) r.spawned;
              r.next_release <- t.now;
              match Fx_data.particle_of c.Fx_data.name with
              | None -> ()
              | Some p -> r.emitted <- r.emitted + emit t p ~x:child_x ~y:child_y
            end
          end
          else if t.now >= r.next_release then
            match Fx_data.particle_of c.Fx_data.name with
            | None -> ()
            | Some p ->
                let cap = match p.Fx_data.total with Some n -> n | None -> max_int in
                if r.emitted < cap then begin
                  let n = emit t p ~x:child_x ~y:child_y in
                  r.emitted <- r.emitted + n;
                  if n > 0 then r.next_release <- t.now +. p.Fx_data.interval
                end)
    r.e.Fx_data.children

(** Advance the clock, emitting and integrating. Returns whether the frame changed. *)
let advance (t : t) (dt : float) : bool =
  t.now <- t.now +. dt;
  List.iter (fun (r : running) -> pump t r) t.running;
  (* Gravity then motion, per particle, for the frame. y grows downwards here as it
     does everywhere else, and a particle that dies this frame moves only as far as
     it has left to live - otherwise a frame that overshoots a short-lived particle
     throws it across the screen. *)
  t.live <-
    List.map
      (fun (l : live) ->
        let dt' = max 0.0 (min dt (l.p.Fx_data.life -. (t.now -. l.born))) in
        let vx = l.vx +. (l.p.Fx_data.gravity.Fx_data.x *. dt') in
        let vy = l.vy +. (l.p.Fx_data.gravity.Fx_data.y *. dt') in
        { l with
          vx;
          vy;
          origin = { x = l.origin.x +. (vx *. dt'); y = l.origin.y +. (vy *. dt') } })
      t.live;
  t.live <-
    List.filter (fun (l : live) -> t.now -. l.born < l.p.Fx_data.life) t.live;
  (* An effect ends when its own duration is up, whatever else it spawned. *)
  t.running <-
    List.filter (fun (r : running) -> t.now -. r.started < r.e.Fx_data.duration) t.running;
  true

(* ----------------------------------------------------------------- frame -- *)

(** A live particle's size and colour at [t], from its start and its end.

    The `start` fraction is the point in the particle's life at which its own
    animation begins: before it, the particle holds its starting size and colour;
    after, it interpolates to the ending ones. It is not a delay before it appears. *)
let particle_at (l : live) (t : float) (size_of_texture : string -> float) =
  let age = t -. l.born in
  let p = l.p in
  let span = if p.Fx_data.life <= 0.0 then 1.0 else p.Fx_data.life in
  let f =
    let u = (age -. (span *. p.Fx_data.start)) /. max 1e-6 (span *. (1.0 -. p.Fx_data.start)) in
    max 0.0 (min 1.0 u)
  in
  let lerp a b = a +. ((b -. a) *. f) in
  let size = lerp p.Fx_data.size p.Fx_data.to_size in
  let tex = size_of_texture p.Fx_data.texture in
  let colour =
    {
      Fx_data.r = lerp p.Fx_data.colour.Fx_data.r p.Fx_data.to_colour.Fx_data.r;
      g = lerp p.Fx_data.colour.Fx_data.g p.Fx_data.to_colour.Fx_data.g;
      b = lerp p.Fx_data.colour.Fx_data.b p.Fx_data.to_colour.Fx_data.b;
      a = lerp p.Fx_data.colour.Fx_data.a p.Fx_data.to_colour.Fx_data.a;
    }
  in
  (size *. tex, colour)

let frame (t : t) ~(texture_size : string -> float) : sprite list =
  let effect_sprites =
    List.concat_map
      (fun (r : running) ->
        let at = t.now -. r.started in
        if r.e.Fx_data.bitmap = "" then []
        else
          let colour = colour_at r.e at in
          [
            {
              image =
                Region
                  {
                    sheet = r.e.Fx_data.bitmap;
                    sx = value_at r.e Fx_data.Source_x at;
                    sy = value_at r.e Fx_data.Source_y at;
                    sw = max 1.0 (value_at r.e Fx_data.Source_w at);
                    sh = max 1.0 (value_at r.e Fx_data.Source_h at);
                    dx = value_at r.e Fx_data.Dest_x at +. r.offset.x;
                    dy = value_at r.e Fx_data.Dest_y at +. r.offset.y;
                    dw = max 1.0 (value_at r.e Fx_data.Dest_w at);
                    dh = max 1.0 (value_at r.e Fx_data.Dest_h at);
                  };
              origin = r.origin;
              colour;
              alpha = colour.Fx_data.a;
              rotation = value_at r.e Fx_data.Rotation at;
              blend = Fx_data.Alpha_blend;
            };
          ])
      t.running
  in
  let particle_sprites =
    List.concat_map
      (fun (l : live) ->
        let size, colour = particle_at l t.now texture_size in
        if size <= 0.0 || colour.Fx_data.a <= 0.0 then []
        else
          [
            {
              image =
                Particle_sprite
                  { texture = l.p.Fx_data.texture; x = l.origin.x; y = l.origin.y; size };
              origin = { x = 0.0; y = 0.0 };
              colour;
              alpha = colour.Fx_data.a;
              rotation = 0.0;
              blend = l.p.Fx_data.blend;
            };
          ])
      t.live
  in
  (* Particles over effects: a sparkle in front of the ring it comes out of, which is
     what reads as depth. Both are additive or alpha-blended anyway. *)
  effect_sprites @ particle_sprites