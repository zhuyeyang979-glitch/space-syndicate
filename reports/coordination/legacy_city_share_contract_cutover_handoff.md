# Legacy City Share Contract Cutover Handoff

## Scope

This handoff covers the Contract consumer migration only. It does not claim the
repository-wide legacy surface is fully removed while the root-owned
`scripts/main.gd` producer still emits the retired project-binding field.

Baseline: `fa7ca46ede14c9149ca4d94827b4003134bd98fe`

## Result

- `ContractRuntimeWorldBridge` no longer reads `district.city.projects`.
- Contract facts now consume
  `VictoryControlRuntimeController.region_control_snapshot()` through the existing
  `VictoryControlWorldBridge`.
- An offer binds the authoritative target region id, control revision, and
  controller player index.
- A response fails closed when region identity, control revision, or controller
  changes.
- Contract save schema is now version 3.
- Non-empty unversioned saves and schema versions below 3 are rejected; no legacy
  project ownership is inferred or migrated.
- `scripts/runtime` contains zero retired Contract project-binding field tokens.
- `GameRuntimeCoordinator` injects the existing Victory controller and world bridge;
  no second control owner was created.

## Tests

- `res://tests/contract_region_control_authority_v06_test.gd`: PASS 15/15.
- `res://tests/legacy_city_share_surface_negative_v06_test.gd`: PASS 14/14.
- `git diff --check` on the owned files: PASS.
- Active production negative scan over runtime/UI/viewmodels/runtime scenes/UI
  scenes/resources/localization: zero retired city/project-share signal tokens.

The Contract focused test exits successfully but the shared project currently logs
three unrelated parse errors from embedded `class_name` declarations in
`resources/content/product_industry_catalog_v05.tres`. The focused Contract
assertions all pass; the resource is outside this task boundary.

## Godot MCP evidence

- Endpoint: Supervisor role `8765`.
- Scene: `res://scenes/runtime/ContractRuntimeController.tscn`.
- Godot: 4.7 stable.
- Enter play mode: success.
- Contract controller script errors: 0.
- Contract world bridge script errors: 0.
- Console error lines for the focused scene: 0.
- Exit play mode: success; final play state false.
- MCP lease released.

## Remaining integration work

- Root owner must remove the retired field from `scripts/main.gd:16597`.
- If the repository-wide negative gate includes `scripts/tools`, the stale
  Contract characterization Bench references at lines 939 and 1173 must be
  migrated or archived as legacy evidence.
- No commit or push was made.
