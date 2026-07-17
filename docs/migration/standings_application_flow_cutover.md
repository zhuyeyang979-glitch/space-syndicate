# Standings application-flow cutover

Status: `MAIN_STANDINGS_APPLICATION_FLOW_EXTRACTION_GREEN`

## Production path

```text
MenuOverlay / FinalSettlement
  -> ApplicationFlowPort.submit_action("standings")
  -> ApplicationFlowPort.standings_requested
  -> StandingsApplicationFlowController.open_standings
  -> StandingsPublicQueryPort.snapshot_for_authorized_viewer
  -> StandingsPublicSnapshotService.compose
  -> MenuOverlay + StandingsScoreboard
```

The production composition is explicit in `scenes/main.tscn`. Neither the
controller nor query port discovers `Main`, uses `current_scene`, accepts a
Callable, or owns gameplay state.

## Visibility boundary

- Viewer identity comes only from `LocalViewerAuthorization` through
  `TablePresentationQueryPorts`.
- Public seat identity and eliminated state come from
  `WorldSessionPublicProjection`.
- Exact local-player cash comes only from the authorized self-only
  `WorldSessionPrivateProjection`.
- Local Top-N GDP and controlled-region progress come from VictoryControl's
  private self projection after viewer authorization.
- Opponent progress remains hidden unless VictoryControl publishes an audit
  entry. Opponent hand, hand count, discard, cash, private intelligence and AI
  plans never enter the query source.
- Session finish is not a disclosure grant. Final text is consumed only from
  `FinalSettlementRuntimeComposition.latest_public_summary()` after a public
  outcome exists.

## Read-only guarantee

Opening standings does not call route refresh, selection mutation, RNG, save,
public log write, session pause or any gameplay command. It only reads detached
projections and mounts presentation nodes. The focused test fingerprints the
world-player array before and after the query and verifies equality.

## Deleted Main ownership

- `StandingsScoreboardScene`
- `_open_standings_menu`
- `_populate_standings_summary_cards`
- `_add_standings_scoreboard_panel`
- `_standings_public_source_snapshot`
- `_standings_public_snapshot`
- `_standing_entries`
- the generic quick-navigation standings branch
- dead catalog-return standings branches

`_order_entries_by_victory_rank` remains as a shared legacy helper and was not
copied into the new owner.

## Main budget

Task baseline: 13,081 physical lines, 11,350 nonblank lines, 812 methods,
108 constants, 13 preloads, 66 top-level variables.

After cutover: 12,961 physical lines, 11,242 nonblank lines, 806 methods,
107 constants, 12 preloads, 66 top-level variables.

The change removes 120 physical lines, 108 nonblank lines, six methods, one
constant and one preload without adding a Main field or fallback.
