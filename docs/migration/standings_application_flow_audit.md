# Standings application-flow audit

Status: `STANDINGS_APPLICATION_FLOW_AUDIT_COMPLETE`

Audit baseline: `3ceda392f949670bcf339961bfa6f0e73152b3a7`

Scope: read-only analysis of the production standings entry, its remaining `Main`
methods, route-refresh side effect, shared helper consumers, existing snapshot and
scoreboard components, and viewer-privacy boundary. This audit changes no
production code or tests.

## Executive finding

The reusable formatter and renderer already exist:

- `GameRuntimeCoordinator/StandingsPublicSnapshotService` formats a supplied
  standings source without reading runtime nodes or recalculating VictoryControl.
- `StandingsScoreboard.tscn` renders the formatted scoreboard and does not mutate
  gameplay.

The remaining ownership defect is the source/application adapter in
`scripts/main.gd`. Opening standings still routes through `Main`, refreshes the
route network as a query side effect, materializes exact facts for every player,
then attempts to redact them. It also treats `TableSelectionState.selected_player`
as the authorized viewer and reveals every seat when the session finishes. Those
two rules conflict with the existing typed viewer authorization and with the v0.6
audit-roster privacy rule.

The next cutover should therefore move only the application handler and source
composition to a scene-owned, typed boundary. It should retain the existing
snapshot service and scoreboard renderer after tightening their source contract.

## Current production flow

```text
MenuModalOverlay.quick_nav_action_requested
  -> ApplicationFlowPort.submit_action("standings")
  -> ApplicationFlowPort.action_requested
  -> Main._on_menu_quick_nav_action_requested
  -> Main._open_standings_menu
  -> Main._standings_public_snapshot
  -> Main._standings_public_source_snapshot
       -> Main._refresh_route_network                 [query side effect]
       -> Main._standing_entries                      [all-seat private materialization]
       -> TableSelectionState.selected_player         [not viewer authorization]
       -> VictoryControl public snapshot
       -> FinalSettlement latest public summary
  -> GameRuntimeCoordinator.compose_standings_snapshot
  -> StandingsPublicSnapshotService.compose
  -> Main._show_menu
  -> Main._populate_standings_summary_cards
  -> Main._add_standings_scoreboard_panel
  -> StandingsScoreboard.set_scoreboard
```

The final-settlement board also emits `standings` through
`ApplicationFlowPort`, so both ordinary quick navigation and post-match navigation
currently converge on the same `Main` path.

## Main method and field inventory

| Symbol | Current responsibility | Classification | Cutover disposition |
| --- | --- | --- | --- |
| `StandingsScoreboardScene` preload | Instantiates the standings renderer | standings-only | Move to scene-owned standings application handler, then delete from `Main`. |
| `_on_menu_quick_nav_action_requested` standings branch | Dispatches the navigation intent | shared application dispatcher | Remove only the standings branch after `ApplicationFlowPort` has a typed standings consumer; do not disturb other pending pages. |
| `_open_standings_menu` | Opens shell and requests standings snapshot | standings-only | Replace with `StandingsApplicationFlowController.open_standings`; delete. |
| `_populate_standings_summary_cards` | Clears preview and mounts scoreboard | standings-only | Move to the application handler; delete. |
| `_add_standings_scoreboard_panel` | Instantiates and applies renderer | standings-only | Move to the application handler; delete. |
| `_standings_public_source_snapshot` | Builds visibility-sensitive source data | standings-only and unsafe | Replace with typed query/source owner; delete, not wrap. |
| `_standings_public_snapshot` | Calls formatter through Coordinator | standings-only | Replace with typed standings query API; delete. |
| `_standing_entries` | Materializes every seat's cash/GDP/intel before redaction | standings-only | Delete after source cutover. It has no non-standings consumer. |
| `_order_entries_by_victory_rank` | Orders both standings and another summary using authoritative ranking | shared | Keep until its other consumer is migrated; do not duplicate it in the new standings owner. Standings should consume VictoryControl's public outcome ordering directly. |

No generic player/economy helper should be copied into the new handler. The
handler must consume typed projections rather than rebuild gameplay facts.

## Existing scene-owned components

### StandingsPublicSnapshotService

Production path:
`GameRuntimeCoordinator/StandingsPublicSnapshotService`.

Useful properties:

- does not read runtime nodes;
- does not calculate region control or Top-N GDP;
- does not sort final rankings;
- does not evaluate private truth;
- already differentiates audit-public rows, viewer-private rows, and hidden rows.

Required tightening:

- stop accepting an unconstrained, caller-authored source dictionary as the
  public security boundary;
- accept a typed/validated standings source projection, or make the Coordinator
  construct that projection from typed query ports;
- treat `can_view_private` as an authorization result, never as caller policy;
- accept audit economic facts only when VictoryControl marks the row
  `cash_visibility == "public_audit"` and includes its player index in
  `audit_revealed_player_indices`.

### StandingsScoreboard

Production path: `scenes/ui/StandingsScoreboard.tscn` with
`scripts/ui/standings_scoreboard.gd`.

It is a presentation-only renderer. It can remain. The future handler should
instantiate it and pass the already visibility-safe scoreboard projection. The
renderer must not become a query client or inspect world state.

### Existing typed viewer query boundary

`TablePresentationQueryPorts` already exposes:

- `authorized_viewer_index()`;
- `can_view_private_subject(viewer_index, subject_index)`;
- `public_world_projection()`;
- `private_world_projection(viewer_index, subject_index)`.

`LocalViewerAuthorization` authorizes exactly one local human and only allows
that viewer to inspect the same subject index. `WorldSessionPresentationQuery`
allowlists public player identity/status separately from viewer-private cash,
hand and discard information. The standings cutover must consume this boundary;
it must not derive authorization from table selection.

## Viewer-privacy defects in the current source adapter

1. **Selection is used as authorization.**
   `TableSelectionState.selected_player` selects the subject and supplies the
   viewer index to VictoryControl. A UI selection is not an authorization grant.

2. **End-of-session is used as a disclosure switch.**
   `can_view_private := session_finished || player_index == selected_player`
   reveals all seat rows when the run ends. Current rules only reveal the
   authoritative audit roster's allowed economic facts; non-roster seats remain
   private.

3. **Private data is collected before redaction.**
   `_standing_entries()` reads every player's cash, GDP, income and intel into a
   full array. A presentation source should never receive secrets it does not
   need.

4. **The selected row reads mutable world state directly.**
   Exact selected cash and derived metrics are read from `WorldSessionState` and
   Main helpers. Exact own data must come through the authorized private
   projection; an opponent selection must remain public-only.

5. **Visibility is inferred instead of carried.**
   The source uses `game_over`, field presence and locally-authored
   `can_view_private`. Future source rows must carry an allowlisted visibility
   scope produced by the authoritative query port.

6. **Final ranking must remain authoritative.**
   The public outcome receipt already contains public ranking order and only
   includes exact cash for authoritatively revealed audit players. The standings
   source must not re-rank from private cash or reconstruct outcome facts.

Allowed public facts include player index/name, eliminated status, public
VictoryControl state/rule/countdowns, audit roster and allowlisted audit entries,
and public outcome receipt. Viewer-private facts are limited to the authorized
local player's own projection. Opponent hand, hand count, discard, cash, intel,
hidden ownership, anonymous actor truth and AI planning remain forbidden.

## `_refresh_route_network` audit

`_refresh_route_network()` delegates to the authoritative route controller's
`refresh_routes`, so it is not a harmless presentation calculation.

| Main call site | Context | Decision |
| --- | --- | --- |
| around line 1295 | gameplay/economic-boon ageing | Retain until that domain is migrated. |
| line 2872 | standings source open | Remove in the standings cutover. A read-only page must not mutate or refresh the world. |
| around line 2957 | economy dashboard source open | Existing separate debt; outside this cutover. |
| around line 3127 | intel dossier source open | Existing separate debt; outside this cutover. |
| around line 6448 | lifecycle/restore path | Retain until its owning lifecycle domain is migrated. |

The helper itself cannot be deleted in the standings cutover because it has
non-standings consumers. The new standings query must consume already-authoritative
VictoryControl/public route-derived projections. If freshness is insufficient,
the simulation/domain cadence must refresh routes before publishing its revision;
opening a page must never do so.

## Shared helper consumer audit

| Helper | Non-standings consumers exist | Standings cutover rule |
| --- | --- | --- |
| `_victory_player_candidate` | yes | Do not move/copy; consume VictoryControl public/private projection. |
| `_victory_control_public_snapshot` | yes | Keep current shared callers; new standings source should call the typed Coordinator/query port directly. |
| `_victory_dynamic_rule` | yes | Do not copy; use `victory_rule` in the public VictoryControl snapshot. |
| `_runtime_session_finished` | yes | Do not use it as a visibility rule. Handler may use session lifecycle only for menu continuation state. |
| `_player_active_city_count` | yes | Do not copy; standings does not need this legacy auxiliary metric for win authority. |
| `_player_gdp_per_minute` | yes | Do not copy; use authoritative Top-N/public audit facts and own typed projection. |
| `_player_intel_display_summary` | yes | Do not place opponent intel in standings. Own private summary needs a dedicated allowlisted query or should be omitted. |
| `_victory_control_status_text` | yes | Formatting can remain in the formatter or move to typed public presentation data; do not read Main. |
| `_economy_card_aftermath_entries` | yes | Do not call from standings source; obtain a public event count from a typed public history query, or omit the decorative KPI until available. |
| `_economy_monster_cash_clue_entries` | yes | Same as above. Never expose supplier/owner truth. |
| `_menu_available_content_width` | yes | Ask `MenuOverlay.available_content_width()` inside the scene-owned application handler; this is layout data, not world state. |
| `_order_entries_by_victory_rank` | yes | Keep for other legacy page; standings consumes the authoritative public outcome order. |

## Recommended atomic cutover

1. Add a typed `standings_requested` signal (or an equivalently narrow route) to
   `ApplicationFlowPort`, and connect it directly to a scene-owned
   `StandingsApplicationFlowController`.
2. Compose that controller explicitly in `scenes/main.tscn` with NodePaths to
   `MenuOverlay` and `GameRuntimeCoordinator`. Do not inject `Main`.
3. Add a typed Coordinator/query API such as
   `standings_presentation_snapshot_for_authorized_viewer(width)` that:
   - obtains the viewer only from `TablePresentationQueryPorts`;
   - enumerates seats from `WorldSessionPublicProjection`;
   - obtains private data only for the authorized viewer/subject pair;
   - consumes VictoryControl's public audit/outcome projection;
   - accepts final public summary only from the existing final-settlement public
     composition;
   - returns pure detached data.
4. Tighten or wrap `StandingsPublicSnapshotService` with a typed source contract.
   Do not add gameplay calculations to it.
5. Let the application handler present the menu shell, instantiate
   `StandingsScoreboard`, and apply the safe snapshot.
6. Delete the seven standings-specific Main methods, `_standing_entries`, the
   standings preload, the generic action branch, and the corresponding scene
   connection to Main. Do not leave a fallback.
7. Prove the old and new paths cannot both execute.

## Required negative gates for implementation

- no standings action signal targets `Main`;
- no standings production script references `Main`, `/root/Main`,
  `current_scene`, `Callable`, or method-name strings;
- opening standings does not call `refresh_routes` and does not change any world
  revision/fingerprint;
- table selection cannot grant private visibility;
- session finish cannot reveal a non-audit opponent;
- only the authorized local viewer receives own private standings facts;
- public audit cash is shown only with authoritative visibility markers;
- no opponent hand, hand count, discard, intel, hidden owner, anonymous actor or
  AI metadata appears in source, formatter output, renderer nodes or tooltips;
- source and result are pure detached data with no `Node`, `Object`, `Resource`
  or `Callable`;
- one navigation request creates one shell and one scoreboard;
- no new/legacy dual route and no Main fallback;
- `scripts/main.gd` line/method/preload/reference budgets monotonically decrease.

## Cutover readiness

The standings flow is ready for a narrow scene-first cutover. There is no need to
rewrite the scoreboard or VictoryControl. The blocking requirement is to establish
a typed, authorization-aware source projection before deleting the Main adapter.
The separate economy and intel page calls to `_refresh_route_network` remain
recorded debt and must not be pulled into this standings-only change.
