# Legacy Standings public snapshot handoff

## Scope

- Updated `StandingsPublicSnapshotService` and its focused QA surface.
- Removed the presentation dependency on
  `economic_assets.project_positions` and all player-facing project-count copy.
- Did not modify `main.gd`, Victory, Contract, campaign/first-table, art, or seat
  files.

## Current contract

- Public audit seats show authoritative Top-N commodity GDP, controlled-region
  count, and authorized exact cash ledger.
- Other v0.6 economic assets remain private.
- A viewer-owned `own_economic_assets` payload may be summarized from current
  fields only: facilities, installations, commodity inventory, color GDP,
  units, contracts, and financial positions.
- Rival private assets and forged public asset envelopes are ignored.

## Regression gates

- Focused service test rejects retired project-position copy.
- The cutover Bench source gate requires the production service to contain no
  `project_positions`, `项目份额`, or exact legacy `"economic_assets"` envelope
  dependency.
- Rival v0.6 asset fixtures do not enter output.

## Validation

- Godot 4.7 isolated focused test:
  `godot --headless --path . --script res://tests/standings_public_snapshot_service_test.gd`
  -> `STANDINGS PUBLIC SNAPSHOT SERVICE PASS`.
- Godot 4.7 isolated Bench:
  `godot --headless --path . res://scenes/tools/StandingsPublicSnapshotCutoverBench.tscn`
  -> `20/20`, real open `38ms`.
- Godot MCP endpoint `8765`:
  opened the real `res://scenes/tools/StandingsPublicSnapshotCutoverBench.tscn`,
  entered custom play mode, and stopped it cleanly. Project-wide script scan
  reported `186` checked scripts and `0` errors.
- Broad `layout_scene_smoke_test.gd` was also attempted. Its Standings checks
  passed, but the suite exited non-zero because of pre-existing concurrent
  Contract type, retired CityDevelopment characterization, first-table, monster,
  and gameplay interaction failures outside this task's ownership.
- `git diff --check` passes for all owned files.
