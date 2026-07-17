# `main.gd` scene-first migration plan

Status: active architecture authority for the
`codex/scene-first-remove-main-gd` worktree.

Baseline commit: `689c77af4867e2f85fc1edf356e1f7abb295bc7a`.

The existing responsibility inventory remains authoritative. The generated
`main_gd_production_call_graph.json` adds concrete callers, dynamic method
strings, scene connections and `_process` edges; it does not create a second
classification.

## Hard gates

- `tools/architecture/check_main_gd_budget.py` rejects any increase in Main
  lines, methods, fields, constants, preloads or external callers.
- `docs/migration/main_gd_cutover_ledger.json` is updated in every atomic
  domain cutover.
- `RuntimeAuthorityAuditBench.tscn` proves the duplicate owner/tick/signal/
  snapshot/save-writer/mutation detector fails closed.
- No production commit may add a Main wrapper, service locator, dynamic
  fallback or second production path.

## Dependency order

1. Run RNG, table selection state, run world state, topology and authoritative
   clocks.
2. Runtime loop and deterministic controller tick ordering.
3. Typed query/command ports replacing root-bound WorldBridges.
4. Card commitment, execution and world-mutation routing.
5. New-game setup, public role catalog and session-start transaction.
6. v0.6 save-owner restore transaction.
7. Table presentation, stable action routing and menus.
8. Audio, diagnostics and final compatibility-surface deletion.
9. Root composition cutover and physical deletion of `scripts/main.gd`.

## First atomic cutover: complete

The first production cutover is `RunRngService`:

- `RunRngService.tscn` is a real child of `GameRuntimeCoordinator.tscn`;
- the service exclusively owns the gameplay RNG state and deterministic draw
  API;
- AI, monster, weather and product-market bridges receive the typed service
  directly from the composition root;
- Main's `rng` field and `_ai_runtime_rng_gateway` are physically deleted;
- deterministic QA drivers seed the service instead of reading a Main
  property;
- the negative gate proves the old field and gateway are absent and that one
  scene-owned service is composed.

Current Main reduction from the frozen baseline: one top-level field and one
method removed, with no replacement compatibility property.

## Second atomic cutover: complete

`TableSelectionState` is now a real scene owner:

- `TableSelectionState.tscn` is composed exactly once under
  `GameRuntimeCoordinator.tscn`;
- it owns selected/inspected player, selected district and selected trade
  product with typed properties, one revision and atomic restore/save APIs;
- AI, monster, military, product-market, contract, card eligibility,
  card-resolution, infrastructure, economy-effect and balance-diagnostics
  bridges receive the same typed instance from the coordinator;
- every active test and characterization Bench that previously used
  `Main.get/set("selected_*")` now addresses the scene owner;
- Main's four top-level selection fields are physically deleted, with no
  compatibility property, dynamic fallback or second state node;
- the Godot 4.7 MCP production Bench proves all ten bridges share the same
  instance and the privacy projection contains no player-private state.

Current Main reduction from the previous committed cutover: four top-level
fields removed, two physical lines removed, and 144 external Main caller
occurrences removed. No Main method, constant, preload or caller count
increased.

## Third atomic cutover: complete

`WorldSessionState` is now the production owner of the live player records,
district records and current session time:

- `WorldSessionState.tscn` is composed exactly once under
  `GameRuntimeCoordinator.tscn`;
- Main's `players`, `districts` and `game_time` fields are physically deleted;
- active runtime bridges receive the same typed owner from the coordinator and
  fail closed for these fields if that owner is missing;
- the v0.6 production player-state adapter and commodity-card inventory no
  longer bind Main as their state source;
- active tests, visual drivers and characterization Benches no longer use
  dynamic `Main.get/set("players|districts|game_time")`;
- the state owner provides deterministic reset, replacement, time advance and
  save/restore APIs while keeping debug output limited to counts and time;
- topology generation, runtime tick ordering, economy formulas, AI policy and
  UI state remain outside this owner.

Current Main reduction from the previous committed cutover: three top-level
fields and three physical lines removed. External Main caller occurrences fell
from 2,165 to 1,652, with no method, constant, preload or caller-file increase.

### Card execution and transition sink: complete

The dynamic card execution boundary now uses scene-owned typed ports. The
former execution bridge's 35 `Main` call/get/set/node-lookup sites are zero;
human and AI submissions share one `CardPlaySubmissionRuntimeController`; and
history, commitment, counter, intel, effect routing and public presentation
have narrow owners. `Main._use_skill` and `Main._queue_skill_resolution` are
physically deleted.

The separate Card Resolution Transition Sink now consumes all twelve frame
commands inside the runtime composition. Producer command lineage is
deterministic and persisted, all sixteen complete order traces are frozen, and
failure injection proves retries across dispatch, history and final settlement
do not double-apply. Schema-v3 restore rejects forged bindings, contradictory
intent progress and live-lineage contamination from legacy saves. Main's frame-command
switch and `_complete_active_card_resolution` wrapper are physically deleted.
This is a section-level persistence guarantee; the complete v0.6 envelope
remains fail-closed while seven unrelated registry sections are unsupported.
See `docs/migration/card_resolution_transition_sink_cutover.md`.

## Table Presentation Source/Target cutover: complete

The query-port prerequisite and the source/target cutover are both complete.
Viewer authorization, public/current-player private queries, map redaction,
typed public logging and Victory presentation receipts live below the
scene-owned presentation composition. `TablePresentationSourceOwner` builds
minimal typed snapshots; `TablePresentationRefreshPort` applies ordered
scheduler receipts exactly once to typed GameScreen, PlanetBoard and gated
developer targets. Main no longer owns the public log, snapshot assembly,
refresh receipt dispatch or Victory presentation comparison.
World geometry is now configured, projected and saved by the existing
`WorldSessionState`; Main's duplicate width/height fields are deleted.

The third RuntimeLoop preflight is **GREEN**. No production RuntimeLoop or
second frame path has been created. The next recommended production cutover is
**AUTHORITATIVE_RUNTIME_LOOP_CUTOVER**. `presentation_action_routing` remains a
separate pending domain and must not be marked complete by this cutover.

## Completion rule

A ledger domain becomes `cut_over` only when its Main fields, methods,
constants, preloads, wrappers and dynamic callbacks are physically deleted and
the negative scan reports zero references for that domain. A reference Bench
or a new owner without old-path deletion is not completion.
