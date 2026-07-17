# Table Presentation Source / Target Cutover blocker

Status: `TABLE_PRESENTATION_SOURCE_TARGET_CUTOVER_BLOCKED`

Branch baseline: `89d541d547a5839de14ecdcf2fede87b357fc905`

This preflight did not create `RuntimeLoop`, a presentation source/port shell,
typed UI targets, a compatibility callback, or a second refresh path. Production
code is unchanged.

## Why this is a real blocker

The missing boundary is not merely a set of presentation classes. The data that
the current table and map render still contains gameplay-legality and
visibility decisions implemented only by `scripts/main.gd`.

`GameTableViewModelRuntimeService.compose_table_source()` formats a source that
has already been assembled. It does not own or query the source facts. The
closure rooted at the four refresh targets, the table source and victory
presentation reaches 250 Main methods. Moving that closure into one
new node would create a replacement monolith; rebuilding only part of it would
drop current actions, forced decisions, map units or privacy filtering.

The authoritative `WorldSessionState` currently exposes mutable full
`players`/`districts` collections and `internal_snapshot()`, but no explicit
locally-authorized viewer projection. A presentation source cannot safely bind
those mutable collections and reproduce Main's private-data checks.

## Blocking production paths

### 1. Live/full table gameplay facts

- Main source: `_runtime_table_snapshot_source()` ->
  `_runtime_table_viewmodel_source()`.
- Current consumers: `GameTableViewModelRuntimeService`, `GameScreen`,
  `PlayerBoard`, `RightInspector`, `PublicTrack` and `OverlayLayer`.
- Main-only facts include `_runtime_snapshot_action_entries()`,
  `_runtime_temporary_decision_snapshot_source()`,
  `_runtime_player_board_snapshot_source()` and their dependencies.
- These paths call Main-owned gameplay decisions such as
  `_authorize_card_play()`, `_table_goal_primary_action()`, selected-district
  action eligibility, purchase/discard eligibility, current card-target facts
  and card-group timing mirrors.

Missing typed APIs:

- `TableActionAvailabilityQuery.snapshot_for_viewer(viewer_index)`;
- `ForcedDecisionPresentationQuery.snapshot_for_viewer(viewer_index)`;
- `CardTablePresentationQuery.live_snapshot_for_viewer(viewer_index)`;
- explicit local-viewer authorization where `viewer_index == subject_index`.

The presentation layer must consume the result of legality evaluation; it must
not re-run or copy those rules.

### 2. Map and planet facts

- Main target path: `_refresh_board()` -> `_set_map_view_data()`.
- Current consumers: embedded and fullscreen `PlanetMapView` instances.
- Main-only projection helpers include `_auto_monster_markers()`,
  `_city_markers_for_selected_player()` and
  `_trade_route_markers_for_selected_product()`.
- They combine private owner information, reveal state, selected viewer,
  topology, route facts and raw unit records before calling the map's imperative
  thirteen-argument `set_map()` API.

Missing typed APIs:

- `MonsterPublicMapQuery.snapshot_for_viewer(viewer_index)`;
- `MilitaryPublicMapQuery.snapshot_for_viewer(viewer_index)`;
- `DistrictPublicMapQuery.snapshot_for_viewer(viewer_index)`;
- `TradeRoutePublicMapQuery.snapshot_for_product(viewer_index, product_id)`;
- one typed, already-redacted `MapPresentationSnapshot`.

`MonsterRuntimeController.roster_snapshot(include_private)` is not a safe
substitute, and no equivalent complete military public projection exists.

### 3. Viewer and privacy authorization

- Main currently applies `_can_view_player_private_hand()` and
  `_local_human_player_index()` throughout table assembly.
- The former permits any non-AI seat rather than requiring an explicit
  viewer/subject binding, so it cannot become the new security boundary.
- `WorldSessionState.internal_snapshot()` contains exact cash, hands, private
  owner state and complete district records.

Missing typed APIs:

- `LocalViewerAuthorization.authorized_viewer_index()`;
- `WorldSessionPublicQuery.public_table_snapshot()`;
- `WorldSessionPrivateViewerQuery.snapshot(viewer_index, subject_index)` that
  fails unless the locally-authorized viewer equals the subject;
- pre-redacted public card-track and obscured-commodity projections.

GameScreen's defensive sanitization remains useful defense in depth, but the
new source must redact before the snapshot reaches a UI target.

### 4. Public log ownership

- Main owns `log_lines` and `_log()`.
- The current table source reads those lines directly.
- Monster, military, weather, product-market, AI, contract and settlement
  paths still emit public text through old world/Main bridges.

Missing typed APIs:

- scene-owned `PublicLogPresentationOwner`;
- allowlisted `PublicLogReceipt` with stable event kind, localization key,
  public values and revision;
- exact-once append and a public recent-entry snapshot;
- typed producer ports for the existing domain emitters.

Deleting Main's log wrapper before those producers are migrated would lose
observable gameplay events; retaining it would violate the cutover.

### 5. Victory presentation receipt

- `GameRuntimeCoordinator.advance_victory_control()` advances the authoritative
  controller and returns a public snapshot.
- Main `_update_victory_control()` still owns the before/after comparison,
  public log write and immediate full refresh.

Missing typed APIs:

- `VictoryPresentationStateChangeReceipt` created from the authoritative
  advance result;
- an allowlisted public-log consumer;
- an ordered immediate-refresh invalidation carrying source revision.

### 6. Immediate refresh producers and typed targets

- Main has 54 direct callers of `_refresh_ui()`, nine of `_refresh_board()`,
  two of `_refresh_live_ui()` and three of
  `_refresh_developer_balance_greybox()` outside their declarations.
- Monster, military, AI and contract runtime files still contain presentation
  requests routed through old world/Main bridges.
- GameScreen currently accepts `apply_state(Dictionary)`; PlanetBoard accepts
  `set_board_state(Dictionary)`; map refresh is an imperative multi-argument
  call. These are not the requested typed target boundary.

Missing typed APIs:

- `TablePresentationInvalidationPort.request(kind, reason, source_revision)`;
- typed GameScreen live/full targets;
- typed PlanetBoard/map target;
- isolated developer target;
- deterministic immediate-versus-cadence ordering receipts.

## Prohibited shortcuts

The following would make the preflight appear green while preserving the
architectural defect, and therefore must not be used:

- pass Main, a Main `Callable`, a method-name table or arbitrary `Object` to a
  source or refresh port;
- use `current_scene`, `/root/Main`, `find_child`, dynamic `call/get/set` or a
  fallback to Main;
- bind `WorldSessionState.players` or `districts` directly to a UI source;
- move the 250-method closure into a replacement presentation
  monolith;
- recalculate card legality, GDP, hidden ownership, route legality or target
  legality in presentation code;
- omit current action, decision or map facts merely to make a reduced snapshot
  compile;
- keep new and legacy refresh/log paths alive together.

## Required prerequisite cutover

Run one narrowly-scoped prerequisite:

`TABLE_PRESENTATION_QUERY_PORTS_CUTOVER`

It should add no UI target and should not consume cadence receipts. It must
only establish and test:

1. explicit local-viewer authorization;
2. public and viewer-private world-session projection queries;
3. field-driven table action-availability and forced-decision presentation
   facts sourced from the existing gameplay owners;
4. already-redacted monster, military, district, route and card-track public
   map/table projections;
5. a scene-owned typed public-log owner and producer ports;
6. a visibility-safe victory state-change receipt;
7. negative privacy tests proving mutable full state never reaches the
   presentation boundary.

After that prerequisite is green, rerun the original Table Presentation
Source/Target prompt. The source owner can then remain a small compositor, the
refresh port can apply ordered scheduler receipts exactly once, and Main's
refresh/snapshot/victory-presentation methods can be physically removed in one
atomic change.

## Preserved state

- `TablePresentationRefreshScheduler` remains the sole cadence owner.
- Main `_process` remains the sole frame-order entry.
- No `RuntimeLoop` exists.
- No new snapshot builder, target, callback, cache or refresh path exists.
- `CardResolutionTransitionSink` and its persisted exact-once lineage are
  untouched.
- `table_presentation_source_target` must remain pending in the cutover ledger.
