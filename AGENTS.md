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
- **Location actions:** `Campaign.query_actions` (first match), `execute_action`, `complete_action`, `enter_location` apply the extracted guarded effect groups against the live quest state. Group and query keys carry the companion gate too: the extractor parses `QUEST_HERO_HAS_COMPANION_SELECTED` from the open if-headers into `(companion id, present)` pairs (else-arm flips the single test) and `companion_ok` checks them against `player.companions` at apply time - `enter_location` folds the groups BEFORE the remove rules so the gates read the party the arrival started with (Q3S0/QS00 remove inside the armed body); the same conjunction rides the other three tables too: `conversations_begin` pairs (OnBegin queues only when the gate holds - Q0Q8/Q3Q6, NKHA), `callback_effects` rows (`execute_callback` folds them under the gate, accumulator re-read per row - 12 sites), and `battle_actions` (the stage action fights only with its companion along, the else arm's NOCOMP box comes from the groups - 15 rows, e.g. QA00/NDKH, QU00/NSUN); every row additionally carries `var_test` / `item_test` slots (the header's script-var and `QUEST_HERO_HAS_ITEM` conjunctions, checked against `player.quest_vars` by `var_test_ok`/`script_var_get` and the traveling inventory by `item_test_ok`/`has_item_tag`; `quest_vars` is keyed per quest and cleared on accept) and a `clause` list pinning out the sibling arms of the row's own if/elseif chain - a clause re-checks a predecessor's key (stages, locs, side, companion, vars, items) and the row applies only when NO clause fires. **Clause snapshot rule:** clauses evaluate against the chain's ENTRY snapshot (the fold-start player, advanced past a fired row), never the live accumulator - an arm's own SetQuestState or remove_companion must not unblock a sibling (Q1G3/Q0Q0 post one box and advance; the elseif questState==2 turn-in waits for the next call, as the single-entry Lua if requires), while a later chain still re-tests a state an earlier chain wrote; `cond_ok` therefore takes `(p, snap)` with the live accumulator for the row's own header and `snap` for its clauses; group rows also carry a terminates flag - a bare `return;` at the site's own nesting level in the Lua body (only Q2Q7's OnCompleteAction ships one) - and the folds in `apply_loc_groups`/`apply_complete_groups`/`quest_turn_in` stop after applying such a row; `Campaign.pending_messages` queues `ShowMessage` boxes (popped via `take_pending_message`, callback fired through `execute_callback`). Both pending queues are global: drain before asserting on them in tests. Travel arrival must call `Campaign.advance_travel_with_events` (not bare `advance_travel`): it runs `enter_location` on `AtNode`. The map front hosts queued dialogue/messages/battle banners in `gfx/conv_window.ml` (shared with `pq_conv_gfx`); when the hosted dialog drains, the driver calls `complete_action`. **Companions:** `player.companions` is the traveling party (≤ 8) and `recruited_companions` is everyone ever granted; `add_companion` joins only at the companion's home (`Campaign.companion_home cid` + `current_city`) and `remove_companion` is free anywhere and keeps the roster. The two callback-site removals (Q3Q5 CallbackConvE takes NDKH, QU02 CallbackConvB takes NSUN - `q.remove_companion_on_callbacks`) fire inside `execute_callback` before the effects fold; arrival rules (Q3S0, QS00) run through `enter_location`. OnStartBattle hooks and battle dispatch follow the party (`p.companions`), not the roster. **Capture UI:** a won road battle runs `Campaign.capture_offer` (dungeon built, 3+ wins, not already held, sprite resolves) and, on Some, `pq_map_gfx` opens the minigame through `capture_begin` - two-click swap via `Capture.play`, [CANCEL] gives up, one more click on Won/Lost runs `capture_finish`; `gfx/capture_layout.ml` is the window geometry; travel freezes while it is up. **Capture surfaces:** callback wins carry `cb_capture_offer` (computed in `execute_callback` via `callback_capture_offer`), `conv_window` parks it on the banner, and the map takes it with `Conv_window.take_capture_offer` right after handing the click over; the city's Pets tab (`capture_candidates` / `pet_rows`, `fill2` for `[PETS_DETAILS]`) clicks straight into the minigame, and the conv step freezes while it is up. **After `Battle.run`, read wins through `Battle.hero_won`, never `is_dead`:** `sweep_deaths` clears that flag every pass (faithful FUN_00464870, pinned by test_combat), so `is_dead` is false even for a kill - every post-run read that used it scored real fights as losses.
- **Item hooks:** `lib/item_hooks.ml` holds the hand-ported bodies (each keeps its Lua), grouped by the shape they share - `plus_at 3 1` means `if damage >= 3 then damage + 1`, and the id list lives in the family's comment because the thresholds are the behaviour. `event_hooks` is the id table `hooks_of_id` folds into a runtime item; damage rides `hook_of` (OnGiveDamage, 50/53) and `hook_receive_of` (OnReceiveDamage, 38/38 - IAOM is a *receive* body, and three damage bodies share a name with an event one, so those are suffixed rather than left to shadow order). `Battle` dispatches the six event kinds at `receive_mana` / `receive_gold` / `receive_xp` / `start_turn_item_hooks` / `match_item_hooks` / `victory_item_hooks`; a body reaches natives through the `ic_*` callbacks on `Item.item_context` (bound to `ic_self` and to the battle) rather than through `Combat`, so a mana credit re-enters the fold the way `ADD_MANA` does, and `ic_apply_status` takes the combatant because every script that calls it passes the target. `ic_percentile` is a **draw-per-call closure** - `PERCENTILE_CHANCE_SYNC` draws per call, so a body that never asks costs no roll; never turn it back into an `int`, which forced one phantom draw per damage event and shifted every seeded fight. The grid is written through `ic_set_gem` / `ic_destroy_gem` / `ic_multipliers` and read from the snapshot the context was built over; `Item.get_random_grid` is the `GetRandomGrid_*` family, **x drawn before y explicitly** because a record literal lets the compiler choose the order. Per-character hook state (IDSH, INOB) lives in `Combat.combatant.item_state` as `(id, float)` - float because IDSH's counter is `damage / 8`. Four ids remain in `known_unported` as `(id, reason)` - IALS, ILBC, IFZT, ITUT - and `test_item.ml` pins the declare tables as literals so a script that gains or loses a hook fails the suite. Every capped mana credit inside a fight runs that fold: `Combat.credit_mana` dispatches through `Combat.mana_credit_hook`, which `Battle.create` installs and guards by **physical** membership in its own roster (every fight has a hero at id 0, so an id check would fold a foreign combatant), and the fold banks through `Combat.bank_mana` - the clamp with no hook - so dispatcher and fold cannot chase each other; the uncapped start-battle payoffs stay outside. `MISS_TURNS` is spent by `Battle.spend_missed_turn`, placed **after** the worn items' `OnStartTurn` and **before** the status start hooks: that is what makes ITUT's "Owner never takes a turn" true, and the only placement that survives `run_start_of_turn_effects`, which drops any id without a descriptor - including the `Missed` pseudo-status. A skipped turn advances `turns_elapsed`, emits `MissedTurn`, still runs the outcome check, and ticks neither cooldowns nor durations. `known_unported` is down to two ids (IALS, ILBC), both natives with nothing to port.
- **Mana ceilings:** `Combat.caps_for skills` is the recovered formula - `25 + (skill + 1) / 2` per element, read out of the character constructor at `0x4661f0` - and `make_combatant` derives `max_mana` from the `skills` it is given unless one is passed explicitly, so never hand a flat cap to a combatant that carries skills. `default_mana_limit` is now the zero-skill base (25), not a chosen 20; tests compare against the name, which is why it kept it. The unread half is the effective-skill query (a vtable slot over raw skill, level and element - `quest.base_value_from_level`), so the port uses the raw skill and a loaded save must not be clamped against the derived cap.
- **Runes:** `lib/campaign_runes.ml` is generated (`tools/extract_runes.py`, three registries + the 150-name table); `player.runes` holds collected ids and fresh heroes start with the three gifted ones; `forge_rune` computes the spec from the modifier's own description (base' = data x data_mult + data_add, power' likewise rounded nearest, difficulty stacking both diff fields). Forged items mint through `forge_item` (id "R" ^ base ^ modifier ^ power, one copy per triple); `loadout_of_equipment` resolves minted ids via `runtime_rune_item`, and `Campaign.resolve_item` rebuilds a mint from its id on load. JXXX's wired hooks are OnGiveDamage (bases 0/1/9) and the per-item OnStartBattle payoffs (`Item_hooks.rune_start_payoffs`); the reflect, full-pool, percentile and skill/resist/victory bodies stay quiet. The city's **Forge** tab picks a triple from the held runes (click fills/clears a slot; `Campaign.forge_band` buckets the difficulty for the `[FORGEITEMS_TARGET*]` line) and the centred `City_layout.forge_btn` forges; clicking the rune node you stand on opens the [RUNEKEEPER] popup (`Campaign.runekeeper_encounter`), whose win claims via `claim_rune`. **Mounts:** `player.mount` is the chosen ride - a `captives` member whose monster record has `mount = 1` - set with `Campaign.set_mount` (one at a time; a non-captive, a non-mount or a missing id refuses). `travel_time` divides the distance by `mounted_speed` (1.0 on foot, then 1.5 slow / 2.0 average / 2.5 fast from `mount_speed`) and `begin_travel` takes the player first - pass `ui.player` or the test's player. `equipment.mount` stays the panel's item slot. **Combat:** `mount_skill_bonus` reads the registry (`addstat + ((level - 1) / addlevel) * addperlevel`, `mount_stat` = `Combat.skill_of_index`, 0-based) as a delta onto the combatant only - never `player.skills` - where `level` is the mount's TRAINING level (`mount_levels`, default 1), not the rider's; `mount_spell_ids` prepends the mount's spell to all three hero spell lists (`spells_of_ids` dedups). **Training:** `training_challenge`/`train_mount` fight the mount's own kind at the next level against the clock's turn budget (three turns a "second" - the auto-AI needs the slack), a success writes `mount_levels`, and `mount_avoids` rolls `mount_avoid_chance` (+10%/level, cap 50%) at departure; the city's Training tab drives the confirm flow.
- Generated files (`lib/campaign_quests.ml`, `lib/campaign_conversations.ml`,
  etc.) are produced by scripts in `tools/` — edit the generator, not the
  output.
- Tests print `ok - name` / `FAIL - name` and exit 1 on failure; follow that
  style in `test/`.
