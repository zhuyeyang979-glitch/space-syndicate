# Table Presentation Source / Target Cutover Handoff

Status: **TABLE_PRESENTATION_SOURCE_TARGET_CUTOVER_GREEN**

Branch: `codex/scene-first-remove-main-gd`
Base SHA: `5b5b11ef123962553ca34c2483f57a32e392f3f0`
Commit/push: intentionally not performed by the implementation agent

## Production result

- `TablePresentationRefreshScheduler` remains cadence-only.
- `TablePresentationSourceOwner` builds scoped live/full/map/developer
  snapshots through the scene-owned `TablePresentationViewModelQuery`.
- `TablePresentationRefreshPort` consumes ordered receipts and applies each
  relevant target exactly once.
- GameScreen, PlanetBoard/map, developer target, public log and victory receipt
  use typed scene-owned paths; Main is not a presentation fallback.
- Public card-resolution visual events are read from
  `CardResolutionPresentationPort` and consumed once by the presentation
  source. Later live/full refreshes do not replay the event.
- Card visual events reject arbitrary caller text: owner labels require
  `public_owner_revealed`, target labels require `public_target_revealed`, and
  caller `summary`/`aftermath_clue`/localization/public-values payloads cannot
  enter `VisualEventLayer`. Fixed labels come from a closed event-kind/status
  localization table.
- Contract resolution presentation uses the injected
  `CardPresentationRuntimeService`; the former Main presentation source,
  snapshot and stage-visual callbacks are deleted.
- The five obsolete contract-to-Main calls for `_pulse_district` and
  `_add_action_callout` are deleted. Contract card styling/history remains on
  `CardPresentationRuntimeService`, while public card resolution visuals remain
  on the typed `CardResolutionPresentationPort` path.
- The same typed map snapshot is applied to embedded and fullscreen map views.
- `PublicLogPresentationOwner` translates the six active production keys
  (contract, military, monster, market, weather and victory state change) with
  a closed Chinese copy table. Unknown/bench keys use “公开局势已更新”; raw
  `public.*`, `victory.*` and state enums are never rendered as player text.
- PlayerBoard table-state lamps use the existing closed phase labels, so
  `resolving` renders as “结算” rather than an internal enum.
- All five active decision categories are represented through owner-backed,
  viewer-scoped fixtures: monster wager, contract response, discard purchase,
  monster target and player target.
- `RuntimeLoop` was not created. `Main._process` remains the unique frame entry
  and calls only the coordinator's high-level presentation advance.

## Final evidence

- `table_presentation_viewmodel_parity_test.gd`: PASS 106/106, including
  malicious owner/target/cash sentinel injection
- `table_presentation_source_target_cutover_test.gd`: PASS 20/20
- `table_presentation_query_ports_cutover_test.gd`: PASS 65/65, including all
  six production public-log keys, safe unknown-key fallback and raw-key/enum
  negative assertions
- `table_presentation_refresh_scheduler_trace_test.gd`: PASS 8/8
- `table_presentation_refresh_scheduler_cutover_test.gd`: PASS 21 checks
- `main_gd_architecture_gate_test.gd`: PASS 58 checks
- `main_runtime_composition_test.gd`: PASS
- `ui_text_smoke_test.gd`: PASS
- `visual_snapshot.gd`: PASS
- `smoke_test.gd --check-only`: PASS
- Godot 4.7 MCP `TablePresentationSourceTargetBench.tscn`: PASS 45/45
- MCP runtime errors: none; reported messages are existing script warnings
- production capture: 1600x960 at
  `docs/ui_qa/table_presentation/table_presentation_production.png`

The refreshed production capture visibly shows “桌态 结算” and localized
victory copy; it contains no `public.*`, `victory.*` or `resolving` player text.

Main budget is green: 13,243 physical lines, 11,490 nonblank lines, 822
methods, 66 top-level variables, 15 preloads, and no budget failures.

## Broad-suite status

The full smoke suite is not claimed green. The removed Main table-snapshot
fixture was migrated to the typed ViewModelQuery. The latest isolated run then
reached `player table ui checks` and remained active while the pre-existing
Monster typed-world-port debt repeatedly failed to route
`_auto_monster_color`. Other broad-suite baseline debts include the retired
`_capture_run_state` fixture and an old AI military-command fixture. No Main
compatibility path was restored. The layout suite still contains unrelated
historical campaign/economy/owner assertions and is reported as baseline debt.

The historical `ContractRuntimeCharacterizationBench.tscn` was also invoked
after the five dead presentation calls were removed. It exits before its
contract cases because its old harness can no longer instantiate the retired
real-Main runtime (`could not instantiate the real main runtime and required
boundaries`). The production coordinator/contract path is covered by the green
106/106 parity gate; the characterization harness was not given a Main fallback.

## RuntimeLoop preflight

The third preflight is **RUNTIME_LOOP_PREFLIGHT_GREEN**. Presentation and
victory-presentation root-only blockers are removed; no RuntimeLoop or double
frame path exists. The next boundary is
`AUTHORITATIVE_RUNTIME_LOOP_CUTOVER`.
