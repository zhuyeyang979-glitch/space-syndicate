# Table Presentation Source / Target preflight after Query Ports

Status: `NO_GO`

Baseline: `5b5b11ef123962553ca34c2483f57a32e392f3f0`

Production code changed by this preflight: no.

## Eliminated blockers

`TablePresentationQueryPorts` now supplies the previously missing local-viewer
authorization, public and viewer-private world facts, viewer action/card-track
facts, owner-safe map markers, exact-once public log storage and visibility-safe
Victory presentation receipts. Main no longer owns map marker truth or Victory
presentation comparisons/outcome callbacks.

## Remaining ROOT_ONLY blockers

### World map geometry

`Main.map_width_m` and `Main.map_height_m` are still the only authoritative
runtime map bounds. `_set_map_view_data()` requires them, and gameplay/world
bridges also consume them. The source/target cutover cannot move or duplicate
these facts into a presentation owner.

Required prerequisite:

```gdscript
func public_map_geometry_projection() -> WorldMapGeometryProjection
```

The projection must come from a scene-owned topology/session owner and contain
`width_m`, `height_m`, and `revision`.

### Monster wager viewer presentation

`Main._runtime_monster_wager_decision_snapshot_source()` still calls private
Monster wager helpers. The public `active_wagers_snapshot()` exposes raw wager
state and is not an acceptable presentation source.

Required prerequisite:

```gdscript
func monster_wager_presentation_for_viewer(viewer_index: int) -> MonsterWagerPresentationProjection
```

It must allowlist public matchup/pool/timer facts and only the authorized
viewer's decision/actions.

## Frozen cadence and current consumers

Scheduler order remains `live -> map -> full -> developer`, at
`0.18 / 0.16 / 1.8 / 1.8` seconds. Main `_process()` still consumes the due
array in both global-block and running branches and dispatches the four legacy
refresh roots. It remains the unique frame entry; no RuntimeLoop or second
scheduler exists.

## Required Source/Port/Target surface after prerequisites

- SourceOwner: `build_live_snapshot`, `build_full_snapshot`,
  `build_map_snapshot`, `build_developer_snapshot`.
- RefreshPort: `apply_ordered_refresh_receipts`,
  `request_immediate_refresh`, `apply_victory_receipt`.
- Targets: `apply_live_presentation`, `apply_full_presentation`,
  `apply_map_presentation`, `apply_developer_presentation`.

All arguments and results must be typed snapshots/receipts. No Main, mutable
world collections, arbitrary Object, Callable, method-name string, current
scene lookup, or fallback path is permitted.

## Decision

Do not create production `TablePresentationSourceOwner` or
`TablePresentationRefreshPort` yet. First cut over the two narrow projections
above, then rerun this preflight. Everything else that remains in Main is
either normal Source/Target migration work or unrelated action routing.
