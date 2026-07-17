# Table Presentation Pipeline Audit

Status: **analysis complete**
Audit baseline: `89d541d547a5839de14ecdcf2fede87b357fc905`
Scope: `TABLE PRESENTATION SOURCE / TARGET CUTOVER`

This document freezes the production presentation pipeline before its
scene-first cutover. Line references are against the audit baseline above.
The companion machine-readable record is
`docs/migration/table_presentation_pipeline_audit.json`.

## Executive finding

`TablePresentationRefreshScheduler` already owns cadence, but not a complete
refresh receipt type. It emits a dictionary containing ordered kind strings.
`Main._process` consumes those strings, selects one of four private Main
methods, assembles viewer-sensitive source dictionaries and invokes UI nodes
through dynamic calls.

The cutover cannot safely copy the current source functions into one new
script. The call-graph closure rooted at the six current presentation roots
contains **250 Main methods**:

- `_runtime_table_snapshot_source`: 195 methods;
- `_refresh_live_ui`: 206 methods;
- `_refresh_board`: 15 methods;
- `_refresh_ui`: 247 methods;
- `_refresh_developer_balance_greybox`: 2 methods;
- `_update_victory_control`: 248 methods.

That closure mixes presentation assembly with private-hand authorization,
purchase/card legality helpers, forced decisions, victory-private queries,
monster/map marker construction and gameplay-derived text. Moving the closure
wholesale would create a replacement monolith and would violate the
scene-first policy.

The largest pre-implementation risk is the absence of a viewer-scoped typed
world query. `WorldSessionState` exposes mutable `players` and `districts`,
plus an `internal_snapshot()` containing both full collections
(`scripts/runtime/world_session_state.gd:14-24,87-94`). A new source owner must
not receive those mutable arrays as its public presentation contract. It needs
explicit, read-only, visibility-scoped query ports or existing owner
projections for the exact facts each snapshot consumes.

## Cadence owner: frozen behavior

The production cadence owner is
`scripts/runtime/table_presentation_refresh_scheduler.gd`, composed once at
`GameRuntimeCoordinator/TablePresentationRefreshScheduler` by
`scenes/runtime/GameRuntimeCoordinator.tscn`.

| Order | Kind | Default interval | Current Main target |
|---:|---|---:|---|
| 1 | `live` | 0.18 s | `_refresh_live_ui` |
| 2 | `map` | 0.16 s | `_refresh_board` |
| 3 | `full` | 1.80 s | `_refresh_ui` |
| 4 | `developer` | 1.80 s | `_refresh_developer_balance_greybox` |

Evidence:

- kinds and order: `table_presentation_refresh_scheduler.gd:5-9`;
- intervals: `table_presentation_refresh_scheduler.gd:11-14`;
- ordered emission: `table_presentation_refresh_scheduler.gd:53-65`;
- coordinator pass-through:
  `game_runtime_coordinator.gd:3452-3469`;
- Main consumption in the global-block branch: `main.gd:581-599`;
- Main consumption in the running branch: `main.gd:644-657`.

Frozen timing semantics:

1. Session finished: `Main._process` returns before scheduler advance
   (`main.gd:576-579`).
2. Monster-wager/global-time block: gameplay is blocked, wager and visual cues
   still advance, and cadence receives **real delta** (`main.gd:581-599`).
3. Ordinary pause/menu: after the global-block branch, `time_scale <= 0`
   returns before cadence, so cadence freezes (`main.gd:600-603`).
4. Running: gameplay uses scaled/world delta, but cadence receives the
   original **real delta** at frame end (`main.gd:603-647`).
5. The developer accumulator advances only while its surface is visible;
   hidden time is not accumulated (`table_presentation_refresh_scheduler.gd:61-65`).
6. A large delta emits each kind at most once and restores its interval rather
   than replaying missed periods (`table_presentation_refresh_scheduler.gd:53-65`).
7. `reset_table_cadence()` re-arms live/map/full only; it does not reset the
   developer remaining time (`table_presentation_refresh_scheduler.gd:31-37`).
8. `request_immediate(kind)` sets only that kind's remaining time to zero and
   rejects unknown kinds (`table_presentation_refresh_scheduler.gd:40-47`).
9. On first production advance, live/map/full are due because their initial
   remaining values are zero. Developer is also due if visible.

Current receipt weakness: the scheduler returns a dictionary with one batch
`revision`, one `advance_count` and an array of kind strings
(`table_presentation_refresh_scheduler.gd:67-74`). There is no typed receipt,
per-kind receipt ID, source revision, viewer scope or consumed lineage yet.

## Current end-to-end pipelines

### Live

```text
Main._process
 -> GameRuntimeCoordinator.advance_presentation_refresh_cadence(real_delta)
 -> TablePresentationRefreshScheduler.advance
 -> Main switches "live"
 -> Main._refresh_live_ui
 -> Main._refresh_bottom_countdown_bar
 -> Main._sync_runtime_game_screen
 -> Main._runtime_table_snapshot_source
 -> GameTableViewModelRuntimeService.compose_table_source
 -> GameScreen.apply_state(Dictionary)
```

Evidence: `main.gd:585-598,644-657,7817-7829,1824-1840` and
`game_table_viewmodel_runtime_service.gd:18-28`.

Although called “live”, it currently rebuilds the same complete table source
used by full refresh. Its only cache is Main's `var_to_str(table_state)`
signature (`main.gd:1835-1840`), so source assembly happens before the cache
check.

### Map

```text
scheduler "map"
 -> Main._refresh_board
 -> Main._set_map_view_data(embedded map)
 -> optionally Main._set_map_view_data(fullscreen map)
 -> PlanetMapView.set_map(...13 arguments...)
 -> set_solar_presentation_snapshot
 -> set_weather_overlay_view_model
```

Evidence: `main.gd:9162-9197`. The Main map source combines raw districts,
visual cue projections, monster markers, viewer-city markers, selected-product
routes, selection state, weather and solar state. The map target is discovered
through `GameScreen.get_embedded_map_view` with a `find_child` fallback
(`main.gd:2147-2156`).

### Full

```text
scheduler/immediate caller "full"
 -> Main._refresh_ui
 -> scheduler.reset_table_cadence
 -> optional menu layout
 -> map refresh
 -> map controls
 -> district supply overlay
 -> bottom countdown
 -> complete GameScreen table snapshot
```

Evidence: `main.gd:7806-7814`. A full refresh therefore also performs a map
apply and re-arms cadence. This ordering is observable and must be frozen in a
trace test before coalescing with same-frame live/map receipts.

### Developer

```text
scheduler "developer"
 -> Main._refresh_developer_balance_greybox
 -> inject GameplayBalanceDiagnosticsRuntimeService into panel
 -> DeveloperBalancePanel.refresh_report(true)
 -> service builds developer report
 -> panel.set_report
```

Evidence: `main.gd:1793-1821` and
`scripts/ui/developer_balance_panel.gd:10-45`. Main also dynamically loads and
mounts the panel when `SPACE_SYNDICATE_DEV_BALANCE` is enabled
(`main.gd:1793-1811`). The developer target is not a production table
dependency and must remain explicitly gated.

### Victory state-change and outcome

The current frame path is:

```text
Main._update_victory_control
 -> read before public state
 -> GameRuntimeCoordinator.advance_victory_control
 -> VictoryControlRuntimeController.advance_world_effective
 -> read after public state
 -> if changed: Main._log + Main._refresh_ui
```

Evidence: `main.gd:4577-4590` and
`game_runtime_coordinator.gd:950-958`.

The outcome path is separate:

```text
GameRuntimeCoordinator._apply_victory_outcome_receipt
 -> VictoryControlWorldBridge.apply_outcome_receipt
 -> dynamic Main._on_victory_outcome_applied
 -> FinalSettlementRuntimeComposition.present
 -> AI outcome-learning finalize
 -> optional Main._log
```

Evidence: `game_runtime_coordinator.gd:1364-1372`,
`victory_control_world_bridge.gd:118-129`, and `main.gd:13926-13948`.

This is not one visibility-safe presentation receipt. The controller already
provides an allowlisted public projection (`victory_control_runtime_controller.gd:310-342`),
but Main still synthesizes the transition by comparing states and the outcome
bridge still sends the internal outcome to Main. Presentation and AI-learning
responsibilities must be split without changing the authoritative victory
advance.

## Main snapshot assembly

Current root assembly:

- `_runtime_table_snapshot_source` delegates normalization to
  `GameTableViewModelRuntimeService`, but Main supplies all facts
  (`main.gd:7824-7851`).
- `_runtime_top_bar_snapshot_source` builds table state, clock, player identity,
  viewer cash/GDP, victory goal, selected district and weather
  (`main.gd:7867-7884`).
- `_runtime_player_board_snapshot_source` builds viewer-private hand-board
  context, infrastructure, actions, bids and progression
  (`main.gd:7908-7931`).
- `_runtime_temporary_decision_snapshot_source` routes private forced decisions
  (`main.gd:7934-7952`).
- `_runtime_card_viewmodel_source` and `_runtime_hand_card_fact_sources` build
  current-viewer hand and public-track inputs (`main.gd:8561-8602`).
- `_runtime_card_track_model_source` joins history/current/queues, public events,
  group phase and decision state (`main.gd:8605-8628`).
- `_runtime_selected_district_snapshot_source` builds viewer-scoped region and
  public-facility detail (`main.gd:8665-8745`).
- `_runtime_planet_snapshot_source` builds rails, weather and flow compass
  (`main.gd:8762-8787`).
- `_runtime_public_log_snapshot` slices Main's log and runs final-settlement
  sanitization (`main.gd:9002-9013`).
- `_set_map_view_data` builds and applies the map payload directly
  (`main.gd:9170-9197`).

`GameTableViewModelRuntimeService` is a useful existing normalizer, but not yet
the source owner: `compose_table_source` consumes the Main-built source and its
debug statement `legacy_main_snapshot_assembly_active = false` is inaccurate
for the current production chain (`game_table_viewmodel_runtime_service.gd:18-28,91-107`).

## Current targets

| Target | Current API | Problem to cut over |
|---|---|---|
| GameScreen | `apply_state(Dictionary)` at `game_screen.gd:131-162` | One untyped full-table dictionary; live/full are not separated. |
| PlanetBoard | `set_board_state(Dictionary)` at `planet_board.gd:65-88` | Receives only table rail state; map data bypasses it. |
| PlanetMapView | `set_map(...)` at `planet_map_view.gd:118-150` | Thirteen-argument legacy target plus separate solar/weather calls. |
| DeveloperBalancePanel | `set_diagnostics_service`, `refresh_report` at `developer_balance_panel.gd:38-45` | UI pulls from a service instead of accepting a gated typed snapshot. |
| Bottom countdown | Main direct `set_state`/widget mutation at `main.gd:9135-9159` | Still Main-owned target logic. |
| Public log | Main `_log` and `log_lines` at `main.gd:406,14260-14264` | No scene-owned exact-once log owner/consumer. |

All target calls are currently dynamic (`has_method`/`call`). There is no
typed refresh target interface and no target apply receipt.

## Immediate refresh callers

Main's direct full-refresh callers, grouped by purpose, are:

- frame cadence: `_process`;
- card-owner guess: `_guess_card_resolution_owner_for_player`;
- map toolbar and route/product selection:
  `_on_map_control_toolbar_action_requested`, `_toggle_selected_trade_route`,
  `_cycle_trade_product`;
- victory: `_update_victory_control`;
- menu/session/setup: `_close_menu`, `_load_run_from_menu`,
  `_apply_run_domain_state_compatibility_adapter`, `_save_settings`, `_new_game`,
  `_toggle_pause`, `_set_configured_player_count`,
  `_set_configured_ai_player_count`, `_set_configured_roguelike_depth`,
  `_set_configured_role_for_player`,
  `_set_configured_starter_monster_for_player`;
- selection/intel: `_mark_selected_city_guess`, `_select_player`,
  `_select_district`, `_cycle_district`;
- regional supply: `_preview_district_card`,
  `_select_district_card_for_quote`, `_close_district_supply_overlay`,
  `_open_district_supply_from_map`, `_preview_v06_facility_card`,
  `_on_district_supply_action_requested`, `_claim_district_card`,
  `_cycle_selected_district_card`, `_cancel_discard_purchase`,
  `_confirm_discard_purchase`, `_buy_selected_skill`,
  `_buy_card_for_player_from_district`;
- target decisions: `_begin_target_monster_choice`,
  `_begin_target_player_choice`, `_cancel_pending_target_choice`,
  `_cancel_pending_player_target_choice`, `_choose_pending_target_monster`,
  `_choose_pending_target_player`;
- card group: `_move_card_within_group`,
  `_set_selected_player_card_group_ready`.

Map-only immediate callers are `_set_map_layer_focus`,
`_on_map_control_toolbar_action_requested`, `_open_fullscreen_map`,
`_close_fullscreen_map`, `_toggle_selected_trade_route` and
`_cycle_trade_product` (`main.gd:2567,2631,4598,4605,9425,9444`).

The save compatibility adapter is the only current direct use of
`GameRuntimeCoordinator.request_immediate_presentation_refresh(&"live")`
(`main.gd:6586`), but it later calls `_refresh_ui` synchronously at line 6635,
so it currently schedules a later live refresh **and** performs an immediate
full refresh.

These calls require a typed invalidation/immediate request. Retaining each
Main call and adding a port request would create dual refresh.

## Domain-to-Main presentation dependencies

Production dynamic callers found by the call graph:

- `ContractRuntimeWorldBridge.refresh_ui` calls Main `_refresh_ui`
  (`contract_runtime_world_bridge.gd:303-305`), and its log API calls Main
  `_log` (`:308-310`).
- `MilitaryRuntimeController` calls Main `_refresh_ui` after deploy and command
  (`military_runtime_controller.gd:633,750`) and sends logs through its world
  bridge.
- `MonsterRuntimeController._refresh_ui` calls its Main-bound world bridge
  (`monster_runtime_controller.gd:5405-5406`); many monster actions call that
  helper.
- `AiRuntimeController._refresh_ui` delegates to the monster controller
  (`ai_runtime_controller.gd:1003-1004`), so it indirectly reaches Main.
- `MonsterRuntimeController`, `MilitaryRuntimeController`, and
  `WeatherRuntimeController` also send log messages through Main `_log`.

The root binding is established when Main calls
`GameRuntimeCoordinator.bind_ai_world(self)` (`main.gd:1669-1676`), which then
binds monster, military, weather, contract and victory world bridges to Main
(`game_runtime_coordinator.gd:520-590`). This task need not complete all typed
world-port migration, but every presentation refresh/log call must leave that
generic bridge and use a narrow typed request/consumer.

## Signals, dynamic discovery, and compatibility

- `scenes/main.tscn:69` connects
  `FinalSettlementRuntimeComposition.public_log_entry_requested` directly to
  Main `_log`. This is the production `.tscn` presentation-to-Main connection.
- GameScreen action signals connect dynamically to Main in
  `_bind_runtime_game_screen` (`main.gd:1756-1773`). They are input/action
  routing, not refresh targets, and should not be accidentally marked cut over
  by this task.
- Map selection signals connect dynamically to Main at
  `main.gd:2134-2139` and fullscreen equivalents at `2484-2490`; they are input
  routing, not refresh application.
- GameScreen/map/developer refresh targets are discovered by
  `get_node_or_null`, `find_child`, `has_method`, `call`, and Callable-based
  signal wiring. No production presentation lookup through
  `get_tree().current_scene` or `/root/Main` was found at the audit baseline.
- Stale tests still invoke Main `_refresh_ui` and
  `_runtime_table_snapshot_source`: `tests/human_normal_table_playability_v06_test.gd`,
  `tests/layout_scene_smoke_test.gd`, and `tests/smoke_test.gd`. These are test
  migration debt, not justification for a Main fallback.
- `GameTableViewModelRuntimeService.debug_snapshot()` currently reports
  `legacy_main_snapshot_assembly_active = false` despite the active Main source
  closure. The assertion is dead/misleading compatibility metadata and should
  be corrected when the new source is real.

## Ownership classification

| Concern | Current owner | Classification | Cutover target |
|---|---|---|---|
| cadence accumulators | TablePresentationRefreshScheduler | already scene-owned | retain; add typed receipt/trace only |
| receipt switch/application | Main._process | Main blocker | TablePresentationRefreshPort |
| live/full snapshot source | Main 250-method closure | Main blocker | TablePresentationSourceOwner over typed query ports |
| map snapshot source | Main._set_map_view_data helpers | Main blocker | minimum MapPresentationSnapshot source |
| GameScreen target | Main dynamic call | Main blocker | typed GameScreen live/full target |
| PlanetBoard/map target | Main dynamic calls | Main blocker | typed Planet target |
| developer data and target | diagnostics owner + Main mounting/pull | split | gated developer source/target |
| public log | Main.log_lines/_log | Main blocker | scene-owned typed exact-once public log target |
| victory authority | VictoryControlRuntimeController | already scene-owned | retain |
| victory presentation transition | Main before/after comparison | Main blocker | visibility-safe state-change receipt |
| final settlement presentation | scene composition reached through Main callback | split | scene-owned victory presentation consumer |
| GameScreen/map input actions | Main action routing | out of this cutover | leave for presentation_action_routing |
| stale Main test calls | old tests | dead compatibility | migrate tests; never restore methods |

## Minimum typed APIs

The following is the smallest safe boundary; names may follow repository
conventions, but capability must remain narrow.

### Source queries

```gdscript
func build_live_snapshot(viewer: TablePresentationViewerContext, source_revision: int) -> TableLivePresentationSnapshot
func build_full_snapshot(viewer: TablePresentationViewerContext, source_revision: int) -> TableFullPresentationSnapshot
func build_map_snapshot(viewer: TablePresentationViewerContext, source_revision: int) -> MapPresentationSnapshot
func build_developer_snapshot(source_revision: int) -> DeveloperBalancePresentationSnapshot
```

The source owner must be explicitly bound to read-only typed services. At
minimum it needs:

- viewer identity/authorization query;
- public player/table query plus current-viewer private projection;
- public region query plus viewer-private marks;
- card queue/history public projection and current-viewer hand projection;
- forced-decision viewer projection;
- victory public projection;
- weather, solar, visual-cue, monster, military, route and infrastructure
  public projections;
- table selection snapshot.

It must not accept `WorldSessionState.players`, `districts`,
`internal_snapshot()`, Main, arbitrary Object, Callable or method names.

### Refresh receipt and port

```gdscript
func advance_table_presentation(real_delta: float, frame_state: TablePresentationFrameState) -> TablePresentationApplyBatchReceipt
func apply_ordered_refresh_receipts(receipts: Array[TablePresentationRefreshReceipt]) -> TablePresentationApplyBatchReceipt
func request_refresh(request: TablePresentationInvalidationRequest) -> TablePresentationRequestReceipt
```

Each refresh receipt needs at least kind, ordered sequence, scheduler revision,
source revision, viewer scope and a deterministic receipt ID. The port owns
duplicate/stale rejection and build/apply diagnostics, not cadence.

### Targets

```gdscript
func apply_live_presentation(snapshot: TableLivePresentationSnapshot) -> TablePresentationTargetReceipt
func apply_full_presentation(snapshot: TableFullPresentationSnapshot) -> TablePresentationTargetReceipt
func apply_map_presentation(snapshot: MapPresentationSnapshot) -> TablePresentationTargetReceipt
func apply_developer_presentation(snapshot: DeveloperBalancePresentationSnapshot) -> TablePresentationTargetReceipt
```

Targets must be explicitly composed and bound. No target lookup, method-name
string, `call`, `find_child` or Main fallback belongs in the refresh port.

### Victory and public log

```gdscript
func advance_victory_and_collect_presentation(delta: float) -> VictoryPresentationStateChangeReceipt
func append_public_event(event: PublicLogPresentationEvent) -> PublicLogApplyReceipt
func apply_victory_presentation(receipt: VictoryPresentationStateChangeReceipt) -> TablePresentationApplyBatchReceipt
```

The victory receipt should carry a transition revision, allowlisted public
state, optional localization event, immediate refresh mask and public outcome
reference. AI learning must consume the authoritative internal outcome through
its own non-presentation path, not via the public UI receipt.

## Go/no-go conditions for the writer

The production cutover is unsafe if any of the following remain:

1. The source owner is handed mutable full `players`/`districts` or copies the
   250-method closure.
2. Any domain controller still calls Main `_refresh_ui` or `_log`.
3. Main still switches scheduler kinds or builds any target snapshot.
4. GameScreen/map/developer target application remains dynamic through Main.
5. Victory presentation still depends on before/after comparison in Main or
   `VictoryControlWorldBridge -> Main._on_victory_outcome_applied`.
6. Final-settlement public log remains connected to Main `_log`.
7. Old and new refresh requests both execute.

If a viewer-scoped typed query cannot be established without moving gameplay
helpers, the correct outcome is
`TABLE_PRESENTATION_SOURCE_TARGET_CUTOVER_BLOCKED`, with that missing query
listed as the next prerequisite. A Main callback or replacement monolith is
not an acceptable workaround.
