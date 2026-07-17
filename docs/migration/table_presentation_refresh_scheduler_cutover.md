# Table Presentation Refresh Scheduler Cutover

The production `TablePresentationRefreshScheduler` now owns the four real-time cadence accumulators formerly stored in `scripts/main.gd`: live HUD, map, full table, and developer-only refresh timing.

## Authority boundary

- The scheduler receives real delta and returns an ordered `due` receipt.
- It owns no gameplay facts, world clock, save schema, UI nodes, or callbacks.
- A hidden developer surface freezes its own cadence exactly as before.
- Manual full refreshes re-arm live/map/full cadence; save restoration can request only an immediate live refresh.
- Large frame deltas emit each refresh class at most once, preserving the legacy cadence behavior.

The current production consumer remains `scripts/main.gd`, which applies due receipts to its legacy presentation methods. This is intentionally recorded as a `presentation_action_routing` / RuntimeLoop preflight debt. The scheduler never receives a `Main` reference and cannot discover or call the scene root.

## Acceptance

- `res://tests/table_presentation_refresh_scheduler_cutover_test.gd`
- `res://scenes/tools/TablePresentationRefreshSchedulerBench.tscn`
- `res://tests/main_runtime_composition_test.gd`
- Main architecture, UI text, visual snapshot, and smoke check-only gates
