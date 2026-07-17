# Card Transition Cutover QA Review

Status: **`CARD_RESOLUTION_TRANSITION_SINK_CUTOVER_BLOCKED`**

- Branch: `codex/scene-first-remove-main-gd`
- Reviewed HEAD: `dfcd841e51a2ae72d319a4aea2cb44bbe3f18922`
- Review mode: analysis-only; no production or test assertion changes
- Full smoke: intentionally not run because the production writer stopped before creating a cutover

## Safety result

The blocked attempt left no half-installed production path:

- no tracked change exists under `scripts/`, `scenes/`, or `tests/`;
- no `CardResolutionTransitionSink`, typed transition command, or typed transition receipt exists;
- no `RuntimeLoop` exists;
- no second card-frame tick or transition application path exists;
- `Main._process` remains the only card-frame entry and still contains the one legacy command loop;
- `GameRuntimeCoordinator` composition was not changed;
- the only task-owned additions are analysis documents.

Unrelated untracked Godot-generated `.uid` files were present before this review and were not edited or staged.

## Blocking production chain

```text
Main._process
  -> GameRuntimeCoordinator.advance_card_resolution_frame
  -> CardResolutionFrameDriver.advance_world
  -> CardResolutionRuntimeController.tick
  -> Array[Dictionary]
  -> Main iterates the array
  -> Main._apply_card_resolution_controller_transition
  -> complete_active
  -> Main._complete_active_card_resolution
  -> CardResolutionExecutionRuntimeService plan/advance/finalize
  -> Main._apply_card_resolution_execution_intent
  -> CardResolutionExecutionWorldBridge.apply_intent(Main, transaction)
  -> dynamic Main call/get/set/node lookup
```

The blocker is specifically `complete_active`. It cannot move behind a valid sink while the bridge requires Main and while the execution receipts, presentation effects, history and concrete effect routing lack narrow typed owners.

## Command and lineage audit

`CardResolutionRuntimeController` currently emits 12 frame-transition kinds:

1. `show_active`
2. `begin_counter`
3. `complete_active`
4. `start_next`
5. `show_group_window`
6. `enter_public_bid`
7. `enter_lock`
8. `all_ready_public_bid`
9. `all_ready_lock`
10. `all_ready_lock_batch`
11. `lock_batch`
12. `hide_overlay`

Every frame command is still a `Dictionary`. `_command()` guarantees only `transition` and `phase`, plus optional `stage`, `remaining`, or `window_phase`. It does not provide a deterministic command ID, frame/batch revision, order index, resolution ID, visibility scope, or mutation/presentation flags. `CardResolutionFrameDriver._tick_count` is diagnostic and is not attached to a command.

The nested execution service declares 13 intent kinds: `counter_check`, `release_active`, `finish_presentation`, `revalidate_requirement`, `revalidate_target`, `dispatch_effect`, `finish_card_commitment`, `create_aftermath`, `restore_context`, `append_history`, `start_next`, `finish_batch`, and `promote_next_batch`. Its in-flight/completed guard is memory-only; it is not a persisted applied-command lineage. Bridge receipts generally identify only `intent_type` and do not provide a complete persistent exact-once envelope.

## Dynamic Main dependency count

A literal source scan of `card_resolution_execution_world_bridge.gd` found **35 dynamic invocation sites**, not 31:

- `world.call(...)`: 27 sites, 21 unique method-name strings;
- `world.get(...)`: 1 site;
- `world.set(...)`: 5 sites;
- `world.get_node_or_null(...)`: 2 sites.

The five unique dynamically accessed Main properties are `last_card_resolution_player_index`, `card_resolution_auction_open`, `card_resolution_timer`, `card_resolution_counter_window_active`, and `card_resolution_counter_timer`. The two hard-coded lookups target `MonsterRuntimeController` and `ContractRuntimeController` below `GameRuntimeCoordinator`.

The boundary review's `31` value is therefore not the literal invocation-site count and should be corrected before it is used as an acceptance oracle. The mapper audit's `27 + 1 + 5 + 2 = 35` breakdown matches the current source.

Additional live Main callbacks remain:

- `AiRuntimeController._queue_skill_resolution()` calls `_call_world(&"_queue_skill_resolution", ...)`;
- Main action records store two `Callable(self, "_use_skill")` callbacks;
- `CardResolutionExecutionWorldBridge` dynamically calls Main's effect, commitment, history, queue, presentation and logging helpers.

## Godot 4.7 MCP evidence

Godot MCP reported `4.7.stable.official.5b4e0cb0f` and recognized the correct project root.

1. `res://scenes/tools/CardResolutionFrameDriverBench.tscn`
   - result: **PASS 7/7**;
   - confirms the existing scene-owned frame driver loads and its focused behavior runs;
   - no script error occurred; existing repository warnings remain.

2. `res://scenes/tools/CardResolutionExecutionRuntimeCharacterizationBench.tscn`
   - the scene and project scripts loaded far enough to run the characterization suite;
   - runtime stopped on a real missing-access error:

```text
Invalid call. Nonexistent function '_add_action_callout (via call)'
CardResolutionExecutionWorldBridge._target_receipt:152
-> Main._apply_card_resolution_execution_intent
-> Main._complete_active_card_resolution
```

This is direct runtime evidence that the dynamic Main adapter is already stale. It is not safe to wrap it behind a new transition sink or label the current execution bridge reusable.

Both MCP runs were explicitly stopped. No background Godot run remains from this review.

## Low-cost gates

- `python tools/architecture/check_main_gd_budget.py --json`: **PASS**, no failures.
- Current Main budget: physical `15126`, nonblank `13212`, methods `894`, variables `79`, constants `111`, preloads `15`.
- External Main callers: `1624` occurrences across `102` files; production reference files remain `3`.
- `tests/main_gd_architecture_gate_test.gd`: **PASS 43/43** under isolated `APPDATA`.
- Negative source scan: no RuntimeLoop, transition sink, typed transition contract, second card tick, or second transition apply path.

These passes only prove that the blocked attempt did not worsen the architecture. They do not make the legacy card transition path acceptable.

## Required next atomic cutover

Before retrying the transition sink, perform **`CARD_EXECUTION_TYPED_PORTS_CUTOVER`** with no Main callback or fallback. At minimum it must provide:

1. typed requirement and target revalidation APIs;
2. typed counter/queue/batch lifecycle APIs;
3. a field-driven effect router bound to existing domain owners;
4. typed commitment, mana/cooldown, history and aftermath APIs;
5. a scene-owned resolved-card-history owner with save/replay lineage;
6. a visibility-safe `CardResolutionPresentationPort`;
7. a shared typed human/AI submission API replacing `_queue_skill_resolution` and `Callable(self, "_use_skill")`;
8. producer-owned deterministic command IDs, revisions and order indexes.

After those dependencies are scene-owned, rerun this sink cutover and require zero Main references, zero duplicate commands, persisted exact-once lineage, and a passing execution characterization bench.

## QA verdict

`CARD_RESOLUTION_TRANSITION_SINK_CUTOVER_BLOCKED`

The writer's decision to stop without a partial sink was correct. Full smoke comparison was not useful because production did not change; the focused MCP run already exposes the exact missing-access defect in the legacy execution adapter.
