# Reverse-engineering evidence

`evidence.yml` is the record of what the port in `lib/` actually rests on: every
claim, the decompilation or asset it came from, how sure we are, and which files
depend on it.

It exists because that information used to be scattered and unlinked. A claim
lived in a source comment, the supporting decompilation sat in
`docs/decompiled/` under an ad-hoc name, and the confidence sat in a
hand-written table at the bottom of a markdown file. Nothing joined them, so
nothing could be queried and nothing could be checked.

Two bugs in this port would have been caught by the file existing:

- **Status effects were keyed by their Lua table name** rather than their XML id,
  in the spell layer and in seven AI hooks. `STATUS_EFFECT_HIDDEN` is a string
  alias for `"EHID"`. The wrong claim lived in a comment; the constants that
  contradict it lived in `game/Assets.zip`. With no descriptor table in place it
  was invisible; the moment one existed, all seventeen effects were inert.
- **The status effect expiry rule was inverted**, and two tests asserted the
  wrong behaviour. A confident claim with no evidence attached is what let that
  harden.

## Running it

```sh
python -m pip install -r requirements.txt
python tools/validate_evidence.py            # errors only
python tools/validate_evidence.py --report   # counts and risk lists
```

Exits non-zero on any problem, so it drops into CI or a pre-commit hook as-is.

`--report` prints the number that matters most right now: how many presentation
calls the port drops on an **unproven** assumption. Those are the ones that would
have to be reversed anyway to render the game, so auditing them is not a detour.

## Finding a consumer in the binary

`tools/scan_field_refs.py` answers "what reads this struct offset?" directly,
which the decompilation in `docs/decompiled/` cannot: every function dumped there
that touches the multiplier flags only ever *writes* them, so `+0x392` looked
consumerless until the binary was scanned.

```sh
python tools/scan_field_refs.py 0x390 0x391 0x392
python tools/scan_field_refs.py 0x392 --context 20
python tools/scan_field_refs.py --coverage-only      # map stats, no queries
```

It reports reads and writes separately, because a field that is written but never
read is a real finding rather than a gap.

### It walks the code, it does not sweep it

A linear sweep of `.text` is not good enough. x86 has no reliable framing: once a
sweep steps into a jump table or an embedded string it desynchronises, and every
instruction after that point is decoded at the wrong alignment. A sweep can
report "no references" for an offset that is read dozens of times, and the result
is indistinguishable from a real answer.

So the tool does recursive descent from function entry points, and iterates to a
fixed point, because a function that reaches a region is itself often only
reachable from elsewhere. Seeds, in order of how much they contribute:

| seed | count | note |
| --- | --- | --- |
| `int3` padding | 5,855 | MSVC pads each function to 16 bytes with `0xCC`, so the byte after a run of `0xCC` is a function start. The main source. |
| `jmp` targets | 3,173 | tail calls |
| `vtable` runs | 999 | null-terminated runs of `.text` pointers in `.rdata`/`.data` |
| `decompiled` | 149 | addresses already recovered into `docs/decompiled/` |
| `export` | 70 | all PHYSFS - this image exports nothing of its own |
| `call` targets | 217 | harvested during the walk |
| `iat`, entrypoint | 1 | |

Two things this image does **not** have, both of which I assumed before checking:
an exception directory (`.pdata`/`.xdata` are absent, since 32-bit MSVC uses SEH
rather than unwind tables), so there are no authoritative function boundaries;
and useful exports - the `Engine_*` / `Lua_*` names in `docs/decompiled/` came
from Ghidra, not from the export table, and several are **wrong**
(`0x4839f0` is named `Engine_ADD_TEMP_SKILL` but is `SET_MAX_MANA`).

### Coverage, and what is missing

```
functions found : 10,464
.text           : 1,150,976 bytes
covered         :   954,645  (82.9%)
```

Of the uncovered 196,331 bytes, ~80,000 is not code at all: `int3` padding,
`switch` jump tables, and mixed data. So **89.1% of all non-padding bytes are
instructions the walk reached.** The remaining ~116,000 bytes of genuinely missed
code is in 1,524 ranges, 390 of them over 60 bytes, and the large ones start with
`push -1` - the SEH prologue. They are exception landing pads, which are reached
through scope tables rather than ordinary control flow; closing them means
parsing `__except_handler3` scope records, and nothing so far has needed it.

The tool prints this breakdown every run, so a negative answer always comes with
its own denominator. A "no references" result is only as good as that number.

### Two traps in reading a hit

- **Stack displacements look like struct fields.** `fild dword ptr [esp + 0x390]`
  is a local variable. Read the base register before believing a hit.
- **Check the access has the shape the field should have.** The mana ceiling is
  four ints indexed by element, so it must appear as `[base + reg*4 + 0x84]`.
  A scalar store to `+0x84` is some other class entirely.

That shape filter is what makes a common offset tractable. `+0x84` returns 244
references across unrelated classes, but only **three** functions touch it in
element-indexed form, and all three turn out to be known mana functions. For a
busy offset, filter on shape before reading anything.

## Schema

### `claims`

A claim is something about the original that the port depends on.

| Field | Meaning |
| :--- | :--- |
| `id` | unique, dotted, `area.topic` |
| `area` | `board` `mana` `combat` `spells` `status_effects` `items` `ai` `score` `ui` `render` `save` |
| `verdict` | `mechanic` — wrong if you get it wrong. `presentation` — cosmetic |
| `status` | `recovered` read out of the binary or assets · `inferred` reasoned, not read · `assumed` our choice, no evidence · `refuted` evidence says otherwise · `open` not known |
| `confidence` | `high` `medium` `low` |
| `audited` | presentation only: was the call actually decompiled? |
| `source_pass` | which body of work established it, so a stale claim is visible |
| `summary` | the claim, in a sentence or two |
| `evidence[]` | `kind` + `ref`, optionally `fn` `addr` `quote` `note` |
| `affects[]` | globs over the port that depend on it |
| `notes` | traps, contradictions, things that look wrong but are not |

`status: refuted` is load-bearing: keep the claim even after it is disproved, so
nobody re-derives it. A database with zero refuted claims usually means nobody
looked hard enough.

### `evidence[].ref`

A repo-relative path, and it is checked. Paths inside the game assets are cited as
`game/Assets.zip!Assets/...` and the validator looks inside the zip.

### `open_questions`

Things we do not know, each with `why_it_matters` and `would_be_settled_by`.
Kept apart from claims because an open question is not yet a claim, and promoting
one without evidence is how the file stops being trustworthy.

### `port_decisions`

Choices we made, not facts about the game. Deliberately a separate list: changing
our mind about a decision must not look like new evidence about the original.

## Adding a claim

1. Write the claim, then go find the evidence for it. Not the other way round —
   the inverted expiry rule started as a plausible reading and hardened into a
   comment.
2. Cite the file. If you cannot cite one, the status is `assumed` or `open`, and
   that is a useful thing to have written down.
3. Record what would refute it. If you cannot think of an observation that would
   disprove it, the claim is probably too vague.
4. `python tools/validate_evidence.py --report` and check the risk lists went down
   rather than up.