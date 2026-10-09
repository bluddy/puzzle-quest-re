# AGENTS.md — project rules for working on this codebase

## OCaml syntax rules (learned the hard way)

- **A toplevel `let _ = ...` (or `let () = ...`) expression block cannot end
  with a semicolon.** A trailing `;` at the toplevel makes the parser demand
  another expression, causing a confusing `Syntax error` reported at the very
  *end* of the file (e.g. `line 905, characters 0-0`) far from the actual
  mistake.
- **Habit: always write toplevel tests as `let () = ... in ()`** (or structure
  bodies so no top-level statement ends in `;`). This form cannot accept a
  stray trailing semicolon, so the mistake becomes impossible.
  - Right: `let () = check "x" cond in ()`
  - Wrong: `let _ = check "x" cond;`

### Debugging tip
A syntax error reported at EOF almost always means an unclosed bracket, an
unterminated string/comment, or a trailing semicolon in a preceding toplevel
`let`. Scan upward from the last top-level `let` before giving up.

### Type errors (learned the hard way)

- **`open Campaign` shadows `None`.** `Campaign.quest_effect` defines its own
  `| None` constructor (campaign.ml), so in any file with `open Campaign` an
  *un-annotated* `None` resolves to `quest_effect`, not `'a option`. Symptoms:
  `expected (string * quest_effect) list` from `t = None`, or
  `There is no constructor "Some" within type "quest_effect"` from a
  function whose first branch (`[] -> None`) committed to `quest_effect`.
  Fix: annotate the expected type (`... : image option`), use
  `Option.is_none t`, or qualify (`Option.None`). Record fields and
  assignments typed `'a option` still pick the right `None` automatically.
- **Combatant fields are unqualified.** After `b.Battle.enemy`, write
  `b.Battle.enemy.is_dead` / `b.Battle.name` — `.Battle.is_dead` is a
  non-existent field; type-directed disambiguation already resolves
  `is_dead`/`name` from the sub-expression's type.

## Build / test

- Build: `opam exec -- dune build --display=quiet`
- Test: `opam exec -- dune runtest --force`
- Shell is PowerShell 5.1: use `;` not `&&`; avoid `ls -la`; use `dir` /
  `Get-ChildItem`. Redirect all output with `*>&1 | Out-File ...` when a
  command's stderr matters (dune writes errors to stderr).

## Project conventions

- No Lua: every Lua callback in the original game is ported to an optional
  OCaml function (see `Campaign.execute_callback` and the
  `callback_battles_table` in `lib/campaign_quests.ml`).
- Generated files (`lib/campaign_quests.ml`, `lib/campaign_conversations.ml`,
  etc.) are produced by scripts in `tools/` — edit the generator, not the
  output.
- Tests print `ok - name` / `FAIL - name` and exit 1 on failure; follow that
  style in `test/`.
