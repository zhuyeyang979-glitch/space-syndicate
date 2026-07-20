# Public Track UI Oracle Retirement

## Scope

This test-only migration aligns the table UI oracles with the active production composition. `GameScreen` now owns one `TopCommoditySushiTrack` and no active `PublicTrack`; no production script or scene is changed.

## Component Boundaries

`TopCommoditySushiTrack` is the wide, persistent public commodity surface. It renders authoritative commodity slots, public commodity focus, claim intent, and snapshot state. Its stable regions are the header, belt viewport, item host, and empty state, and its minimum height remains at least 150 pixels.

`CardResolutionTrack` remains a separate temporary card-resolution surface. Its history, active resolution, queue, next queue, auction response, privacy hint, and empty-state lanes remain covered by the UI tests. It is not restored as the top persistent table rail.

## Negative Guarantees

- Active `GameScreen` node named `PublicTrack`: 0
- Active `GameScreen.tscn` references to `PublicTrack.tscn`: 0
- Active `GameScreen` node named `TopCommoditySushiTrack`: 1
- Active `GameScreen.tscn` references to `TopCommoditySushiTrack.tscn`: 1
- Production files changed: 0
- Production scenes changed: 0
- Main files changed: 0

## Legacy Debt

`res://scenes/ui/PublicTrack.tscn` remains as a historical wrapper scene. This migration does not audit all remaining consumers and does not claim that the file can be deleted. Physical removal requires a separate zero-reference audit.
