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
- **A test's `~rng` must be a stateful LCG, never a constant function of
  the bound.** `fun n -> k mod n` hands the battle AI the same roll for
  every call of a given size, and any reroll-until-nonzero loop in the
  AI then spins forever (this hung test_campaign for fifteen minutes);
  copy the capture tests' shape - a `ref` advanced on every call.
- **Modules with several record types sharing field names need annotated
  lambdas.** `campaign_runes.ml` defines id/name_text/code on base,
  modifier and power runes at once, so `List.find (fun r -> r.id = id)
  base_runes` binds r at the *last* declared type and then rejects the
  list - write `(fun (r : base_rune) -> r.id = id)` (or, outside the
  module, `(fun (r : Campaign_runes.base_rune) -> ...)`).
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

## Windows file locks (learned the hard way)

- **A file can be held by a memory-mapped section** (dune's cache, an
  editor, a previous failed write). Symptoms: the edit tool fails with
  `FileSystem.writeFile`, Python `open(path, 'w')` raises
  `OSError: [Errno 22] Invalid argument`, .NET `WriteAllText` raises
  "user-mapped section open". Fix: write a sibling `NAME.new` file and
  `Move-Item -Force` it over the target — rename does not need the
  target's data handle. `tools/extract_quests.py` already writes its
  output that way.

## Project conventions

- No Lua: every Lua callback in the original game is ported to OCaml —
  `Campaign.execute_callback` applies the extracted `callback_effects`
  (state writes, grants, nested conversations, `QUEST_COMPLETE`) and then
  runs the body's fight when it has one (`callback_battles_table` in
  `lib/campaign_quests.ml`).
- **Location actions:** `Campaign.query_actions` (first match), `execute_action`, `complete_action`, `enter_location` apply the extracted guarded effect groups against the live quest state; `Campaign.pending_messages` queues `ShowMessage` boxes (popped via `take_pending_message`, callback fired through `execute_callback`). Both pending queues are global: drain before asserting on them in tests. Travel arrival must call `Campaign.advance_travel_with_events` (not bare `advance_travel`): it runs `enter_location` on `AtNode`. The map front hosts queued dialogue/messages/battle banners in `gfx/conv_window.ml` (shared with `pq_conv_gfx`); when the hosted dialog drains, the driver calls `complete_action`. **Companions:** `player.companions` is the traveling party (≤ 8) and `recruited_companions` is everyone ever granted; `add_companion` joins only at the companion's home (`Campaign.companion_home cid` + `current_city`) and `remove_companion` is free anywhere and keeps the roster. OnStartBattle hooks and battle dispatch follow the party (`p.companions`), not the roster. **Capture UI:** a won road battle runs `Campaign.capture_offer` (dungeon built, 3+ wins, not already held, sprite resolves) and, on Some, `pq_map_gfx` opens the minigame through `capture_begin` - two-click swap via `Capture.play`, [CANCEL] gives up, one more click on Won/Lost runs `capture_finish`; `gfx/capture_layout.ml` is the window geometry; travel freezes while it is up. **Capture surfaces:** callback wins carry `cb_capture_offer` (computed in `execute_callback` via `callback_capture_offer`), `conv_window` parks it on the banner, and the map takes it with `Conv_window.take_capture_offer` right after handing the click over; the city's Pets tab (`capture_candidates` / `pet_rows`, `fill2` for `[PETS_DETAILS]`) clicks straight into the minigame, and the conv step freezes while it is up. **After `Battle.run`, read wins through `Battle.hero_won`, never `is_dead`:** `sweep_deaths` clears that flag every pass (faithful FUN_00464870, pinned by test_combat), so `is_dead` is false even for a kill - every post-run read that used it scored real fights as losses.
- **Runes:** `lib/campaign_runes.ml` is generated (`tools/extract_runes.py`, three registries + the 150-name table); `player.runes` holds collected ids and fresh heroes start with the three gifted ones; `forge_rune` computes the spec from the modifier's own description (base' = data x data_mult + data_add, power' likewise rounded nearest, difficulty stacking both diff fields). Forged items mint through `forge_item` (id "R" ^ base ^ modifier ^ power, one copy per triple); `loadout_of_equipment` resolves minted ids via `runtime_rune_item`, and `Campaign.resolve_item` rebuilds a mint from its id on load. JXXX's wired hooks are OnGiveDamage (bases 0/1/9) and the per-item OnStartBattle payoffs (`Item_hooks.rune_start_payoffs`); the reflect, full-pool, percentile and skill/resist/victory bodies stay quiet. The city's **Forge** tab picks a triple from the held runes (click fills/clears a slot; `Campaign.forge_band` buckets the difficulty for the `[FORGEITEMS_TARGET*]` line) and the centred `City_layout.forge_btn` forges; clicking the rune node you stand on opens the [RUNEKEEPER] popup (`Campaign.runekeeper_encounter`), whose win claims via `claim_rune`. **Mounts:** `player.mount` is the chosen ride - a `captives` member whose monster record has `mount = 1` - set with `Campaign.set_mount` (one at a time; a non-captive, a non-mount or a missing id refuses). `travel_time` divides the distance by `mounted_speed` (1.0 on foot, then 1.5 slow / 2.0 average / 2.5 fast from `mount_speed`) and `begin_travel` takes the player first - pass `ui.player` or the test's player. `equipment.mount` stays the panel's item slot. **Combat:** `mount_skill_bonus` reads the registry (`addstat + ((level - 1) / addlevel) * addperlevel`, `mount_stat` = `Combat.skill_of_index`, 0-based) as a delta onto the combatant only - never `player.skills` - where `level` is the mount's TRAINING level (`mount_levels`, default 1), not the rider's; `mount_spell_ids` prepends the mount's spell to all three hero spell lists (`spells_of_ids` dedups). **Training:** `training_challenge`/`train_mount` fight the mount's own kind at the next level against the clock's turn budget (three turns a "second" - the auto-AI needs the slack), a success writes `mount_levels`, and `mount_avoids` rolls `mount_avoid_chance` (+10%/level, cap 50%) at departure; the city's Training tab drives the confirm flow.
- Generated files (`lib/campaign_quests.ml`, `lib/campaign_conversations.ml`,
  etc.) are produced by scripts in `tools/` — edit the generator, not the
  output.
- Tests print `ok - name` / `FAIL - name` and exit 1 on failure; follow that
  style in `test/`.
