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