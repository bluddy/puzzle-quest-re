(** A seeded generator with [Random.int]'s contract.

    Every seeded tool in this project wants the same thing - a reproducible rng
    whose values land in 0..n-1 - and each of them had its own copy of an LCG.
    That is where a real bug came from, so it lives here once.

    **The low bits of this generator are unusable, and that is not a detail.** The
    state is masked to 2^30 and stepped with a multiplier that is 5 mod 8, so
    `state mod 4` cycles 0, 1, 2, 3 with period four, exactly. Asking for a board
    of mana gems produced vertical stripes: every row the same four-colour
    pattern, because each row started at the same point in that cycle.

    The fix is the standard one - draw from the high bits - and it is easy to
    undo by accident, so [test_rng.ml] asserts that small ranges actually vary. *)

type t = { mutable state : int32 }

let create seed = { state = Int32.of_int seed }

(* Masks and constants as written in most references for this generator. *)
let modulus = 0x3FFFFFFFl
let multiplier = 1103515245l
let increment = 12345l

(** Advance the state and return it. *)
let raw (g : t) : int32 =
  g.state <-
    Int32.logand (Int32.add (Int32.mul g.state multiplier) increment) modulus;
  g.state

(** A value in 0 .. n-1, matching [Random.int].

    The shift is the whole point: bits 16 and up vary well, bits 0 and 1 do not.
    Taking the remainder of the shifted state also keeps this correct for an [n]
    that is not a power of two. *)
let int (g : t) n : int =
  if n <= 1 then 0
  else Int32.to_int (Int32.rem (Int32.shift_right_logical (raw g) 16) (Int32.of_int n))

(** A float in [0, 1). *)
let float (g : t) : float =
  let bits = Int32.shift_right_logical (raw g) 8 in
  Int32.to_float bits /. 4294967296.0

(** [n] values in 0 .. range-1, which is how a board or a roster is filled. *)
let list (g : t) ~length ~range : int list =
  List.init length (fun _ -> int g range)