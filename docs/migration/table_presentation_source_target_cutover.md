# Table Presentation Source / Target Cutover

Status: **TABLE_PRESENTATION_SOURCE_TARGET_CUTOVER_GREEN**

This atomic cutover removes table, map, developer and victory-presentation
refresh ownership from `Main` without creating `RuntimeLoop`. The production
frame entry remains `Main._process`, but it now delegates presentation with a
single high-level call to `GameRuntimeCoordinator.advance_table_presentation`.

## Production ownership

- Cadence remains exclusively owned by
  `TablePresentationRefreshScheduler`; it only emits ordered typed receipts.
- `TablePresentationSourceOwner` composes minimal live, full, map and
  developer snapshots from scene-owned query services.
- Planet dimensions are now authoritative in the existing
  `WorldSessionState`; its public geometry projection is saved/restored and
  consumed directly. Main's two geometry fields and polygon-bound inference
  are deleted, so map presentation and card-market policy share one truth.
- `TablePresentationRefreshPort` validates sequence, kind, viewer and
  authorization revision, builds only the requested snapshot, and applies it
  exactly once to an explicit typed target.
- `GameScreen` owns typed live/full application. `PlanetBoard` owns typed map
  application. `DeveloperBalancePresentationTarget` is developer-only and
  remains unavailable unless both a debug build and the explicit environment
  gate are present.
- Victory changes are emitted as allowlisted
  `VictoryPresentationStateChangeReceipt` values and are consumed in the
  deterministic order public log -> immediate live/full refresh -> normal
  frame-end cadence.
- Viewer-private feedback is stored by `ViewerPrivateFeedbackOwner` and is
  included only in the authorized viewer's full snapshot. It is never routed
  to the public log or live/public snapshots.

## Exact-once and privacy

The refresh port records receipt sequence, source revision, target revision,
snapshot-build count, cache hits, target-apply count, duplicate count and
stale count. Focused tests prove one receipt produces one relevant snapshot
and one relevant target application, while unrelated snapshots and targets
remain at zero. Duplicate receipts are rejected and stale receipts are
ignored.

Snapshot values are recursively pure-data and carry a viewer index plus an
authorization revision. Public projections exclude opponent cash, hand,
discard, hidden owners, anonymous true actors, AI plans, learning metadata and
private targeting. The independent privacy review reports zero violations.
Developer diagnostics never enter a production target without the explicit
debug gate.

## Main deletion

The cutover physically deletes the four former refresh targets and their
snapshot-construction chain:

- `_refresh_live_ui`
- `_refresh_board`
- `_refresh_ui`
- `_refresh_developer_balance_greybox`
- `_runtime_table_snapshot_source`
- all former live/full/map/card-track/current-player snapshot assembly helpers
- the old public-log wrapper and legacy free-text public-log adapter
- victory before/after comparison and its log/refresh side effects

`Main._update_victory_control` is now an authority-preserving wrapper around
`GameRuntimeCoordinator.advance_victory_control`; it does not inspect or
present the receipt. `Main._process` does not inspect presentation receipt
kinds, build snapshots, call UI targets, write public logs or choose visibility.

## Main budget

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Physical lines | 14,116 | 13,243 | -873 |
| Nonblank lines | 12,280 | 11,490 | -790 |
| Methods | 856 | 822 | -34 |
| Top-level variables | 76 | 66 | -10 |
| Top-level preloads | 15 | 15 | 0 |
| External Main caller files | 102 | 102 | 0 |
| External Main caller occurrences | 1,598 | 1,597 | -1 |

The architecture budget gate passes; no Main caller, preload, fallback or
replacement monolith was added.

## Validation

Green focused evidence:

- query ports and closed player-facing public-log localization: 65/65
- source/target: 20/20
- production viewmodel parity, malicious visibility injection, localized table
  phase and contract callback-negative gate: 106/106
- world-session geometry owner/save roundtrip: 11/11
- scheduler trace: 8/8
- Godot MCP `TablePresentationSourceTargetBench`: 45/45, no runtime errors
- Main architecture gate: 58 checks
- Main runtime composition: pass
- Godot script scan: 306 scripts, zero errors
- UI text smoke: pass
- visual snapshot: pass
- smoke `--check-only`: pass
- Main budget gate: pass

The Godot MCP runtime also mounted the real production `GameScreen` and
`GameRuntimeCoordinator` composition at 1600x960. The clean capture is
`res://docs/ui_qa/table_presentation/table_presentation_production.png`; it
contains no QA controls, debug paths, private opponent data or missing-resource
markers.

The broad layout test remains red on unrelated historical campaign, economy,
owner-count and monster fixtures. Presentation-specific obsolete assertions
were migrated; no compatibility route was restored.

The isolated full smoke is not claimed green. The historical player-table
fixture now consumes `TablePresentationViewModelQuery.compose_table_state`.
The latest post-cutover run reached `player table ui checks` and remained
CPU-active while the pre-existing Monster typed-world-port debt repeatedly
failed to route `_auto_monster_color`; the owned run was stopped after the
timeout audit. Other broad-suite debts include the retired
`_capture_run_state` fixture and an old AI military-command fixture. These are
not reasons to restore a Main compatibility route.

The final parity gate also proves two production details that were absent from
the first Bench pass: public card-resolution visual events are consumed once
through `CardResolutionPresentationPort`, and contract presentation is composed
through the injected typed `CardPresentationRuntimeService` rather than a Main
callback.

The contract world bridge also has no residual presentation callback: its dead
`_pulse_district` and `_add_action_callout` calls were removed after their Main
targets were retired. Gameplay world calls in that bridge remain explicitly
tracked as typed-world-port debt and were not changed by this cutover.

The public card visual boundary is closed rather than text-filtered:
`public_owner_label` requires `public_owner_revealed`, `target_label` requires
`public_target_revealed`, and caller-supplied `summary`, `aftermath_clue`,
`localization_key` and `public_values` cannot cross the port. The port derives
the localization key and formatting values from the allowlisted event kind and
status; `VisualEventLayer` renders fixed product copy only.

The public log likewise never displays its localization key. The active
contract, military, monster, market, weather and victory-state keys map to a
closed Chinese copy table; unknown keys display “公开局势已更新”. PlayerBoard
table-state lamps use the existing closed phase mapping, so `resolving` appears
as “结算”.

## Next boundary

The third RuntimeLoop preflight is green for presentation. The next atomic
task is **AUTHORITATIVE_RUNTIME_LOOP_CUTOVER**. Existing typed world-bridge
debt remains recorded and must not be mistaken for presentation ownership.
