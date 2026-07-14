# Agent C — VS06-C9 Full Map Direct Trade Coverage Handoff

## Outcome

PASS. The map policy now requires every initial district's sole production product to have an exact demand in a direct neighbor. `viable` is true only at `10000` coverage basis points. Depth-I seed `60610`, including `region.002`, passed the real-main focused oracle.

## Files

- `scripts/runtime/roguelike_economic_viability_policy.gd`
- `scripts/main.gd` — only the existing map-policy request and atomic demand-patch application block
- `tests/roguelike_economic_viability_policy_test.gd`
- `docs/roguelike_economic_viability_v06_contract.md`
- this handoff

## Public API and behavior

- `RoguelikeEconomicViabilityPolicy.normalize(request) -> Dictionary`
- `RoguelikeEconomicViabilityPolicy.audit(request) -> Dictionary`
- `main._roguelike_economic_viability_dev_snapshot() -> Dictionary` remains dev-only.

The policy uses deterministic minimum-cost full bipartite assignment, preserves already-covered maps, restores redundant duplicate-product patches, and returns `full_direct_coverage_assignment_unavailable` with zero mutations when a complete legal assignment cannot be proven. Main validates the entire patch set before applying any demand slot.

Audit evidence now includes `source_count`, `covered_source_count`, `coverage_ratio_bp`, `assignments`, `changed_destination_indices`, `matching_flow`, and `matching_cost`.

## Minimal verification

Godot `4.7.stable.official`, isolated `APPDATA`/`LOCALAPPDATA`:

`Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/roguelike_economic_viability_policy_test.gd`

Result: `ROGUELIKE_ECONOMIC_VIABILITY_TEST|status=PASS|checks=927|failures=0`.

The gate covered 64 deterministic shapes, no-op maps, greedy-trap rearrangement, no-perfect-matching fail-closed, duplicate-product sharing, two-region/mixed terrain, input immutability, real `main.tscn` depth-I seed `60610`, explicit `region.002` direct coverage, and RegionInfrastructure fact equality.

Per task boundary, no full vertical slice, MCP, headed run, or default player save was used. The coordination thread still owns the final CommodityFlow sale/GDP/cash slice.

## Known risk / next integration

This proves initial map viability and authoritative map/RegionInfrastructure fact alignment. It does not itself prove a subsequent facility creates a CommodityFlow sale; the central slice must still exercise A6's production owner and ledger using the generated `region.002` demand chain.

## Lessons for other agents

- **Invariant:** every source region, not a selected/preferred region, needs a direct neighbor with the exact production product as demand.
- **Failed approach:** repairing only region zero, or greedily overwriting demands source by source, can leave another source uncovered or undo an earlier repair.
- **Stable API:** consume `normalize`/`audit` pure-data results and the dev-only audit; the map remains the sole state owner.
- **Test oracle:** require `covered_source_count == source_count`, `coverage_ratio_bp == 10000`, one valid assignment row per source, and RegionInfrastructure facts equal to normalized map facts.
- **Integration trap:** policy success is not a CommodityFlow receipt; do not replace the sale owner or pay cash directly from map generation.
- **Reusable pattern:** deterministic min-cost global assignment plus validate-all/apply-all patching prevents order dependence and partial map writes.
- **Stale evidence:** C8's `preferred_source_match`/region-zero-only PASS is compatibility evidence, not the C9 production gate.
- **Next dependency:** coordination should rerun the full vertical slice and verify the region where Stage4 actually builds produces sale receipt, GDP, and cash through A6's authoritative owner chain.
