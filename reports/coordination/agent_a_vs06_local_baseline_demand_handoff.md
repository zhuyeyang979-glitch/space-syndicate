# Agent A VS06-A10 Handoff

## Status

VS06-A10 CommodityFlow Local Baseline Demand is complete and frozen at focused-test scope.

- A10 focused gate: `PASS | checks=50 | failures=0`
- A6 facility-to-flow gate: `PASS | checks=37 | failures=0`
- CommodityFlow atomic batch sink: `PASS | checks=51 | failures=0`
- Godot: `4.7.stable.official.5b4e0cb0f`
- Full slice, MCP, headed playtest, default `user://`, commit, push, and merge: not run

## Modified Files

- `scripts/runtime/commodity_flow_runtime_controller.gd`
- `scripts/runtime/commodity_flow_world_bridge.gd`
- `scenes/runtime/CommodityFlowRuntimeController.tscn`
- `tests/commodity_flow_local_baseline_demand_v06_test.gd`
- `docs/commodity_flow_local_baseline_demand_v06.md`
- `reports/coordination/agent_a_vs06_local_baseline_demand_handoff.md`

No `main.gd`, Coordinator, AI, map policy, catalog, pricing formula, UI, or card asset was changed.

## Implemented Runtime Semantics

The authoritative flow planner now settles three disjoint buckets in order:

1. existing remote factory-to-market route allocation;
2. capped local production absorption from remaining supply;
3. capped local market turnover from remaining demand.

Remote matching consumes both claim sides before either local layer runs. Local production defaults to the smaller of `1 unit/min` and `10%` of effective installed production. Local market turnover defaults to `1 unit/min`. Values are `1000bp` and `500bp`; remote route value and distance pricing are unchanged.

High-rate isolated production does not disappear: after one minute at 10 units/min, one unit settles locally and 9,000 milliunits remain in persisted backpressure accounting. Adding a legal remote market releases that capacity and produces ten remote receipts with no local double count.

## Receipt And Cash Boundary

- Player factory baseline: local Sale Receipt, exact GDP and owner cash, no route/market/rent.
- Player market baseline: local Sale Receipt, exact GDP and market-owner cash, no route/factory/rent.
- Neutral public market baseline: positive region GDP, `owner_net_cash=0`, no player cash and no rent.
- The production world bridge accepts only the exact neutral receipt shape and rejects a forged neutral cash delta.
- Existing public receipt sanitization remains active.

## Persistence And Exact-Once Evidence

New saves include baseline terms, fixed-point budget remainders, receipt sequence, recent receipts, and `backpressured_milliunits_by_source`. Save/load resumes the one-unit-per-minute budget, creates a new receipt ID exactly once, preserves cumulative backpressure, and fails closed on a terms mismatch with before/after state equality.

## Public APIs And Configuration

Existing APIs remain unchanged. New read-only capability:

- `local_baseline_modifier_capability_snapshot() -> Dictionary`

Inspector configuration is stored on `CommodityFlowRuntimeController.tscn`:

- `local_production_absorption_units_per_minute=1`
- `local_production_absorption_rate_cap_basis_points=1000`
- `local_market_turnover_units_per_minute=1`
- `local_production_baseline_value_basis_points=1000`
- `local_market_baseline_value_basis_points=500`

## A11 Dependency: Local Self-Consumption Card

The requested formal card is not authored in A10. `local_baseline_modifier_capability_snapshot()` reserves its three machine fields and the single-owner lifecycle. `prepare_card_effect_batch()` currently rejects `one_time_effect_kind=local_baseline_modifier` with `local_baseline_modifier_terms_not_authored` before any journal or state mutation.

A11 must author card values and hard caps, then implement prepare/commit/rollback/finalize, expiry recovery, exact-once replay, and save/load inside this same owner. It must not create a second modifier service or infer effects from card names.

## Commands

All tests ran with isolated temporary `APPDATA` and `LOCALAPPDATA`:

```powershell
godot --headless --path . --script res://tests/commodity_flow_local_baseline_demand_v06_test.gd
godot --headless --path . --script res://tests/vs06_facility_commodity_flow_integration_test.gd
godot --headless --path . --script res://tests/commodity_flow_atomic_batch_sink_v06_test.gd
```

## Known Limits

- Persisted backpressure is blocked-output accounting, not resellable inventory. Actual storage remains owned by the existing warehouse path.
- A6 still reports that generated real-main map facts may have no exact production/demand intersection. A10 makes isolated facilities economically alive without weakening exact-product remote matching.
- Unified vertical-slice and headed acceptance remain coordination-owned.

## Lessons for other agents

- **Invariant:** Remote allocation must consume both supply and demand before either local fallback can see the claim.
- **Failed approach:** Treating local demand as an unlimited sink would erase warehouse and route value and hide map-economy defects.
- **Stable API:** Existing Sale Receipt, flow-plan, save/load, and card-effect batch APIs remain authoritative; the new modifier capability is read-only and fail-closed.
- **Test oracle:** A 10-units/min isolated factory produces one local receipt plus 9,000 backpressured milliunits after 60 seconds; the same factory with matching remote demand produces ten remote receipts and no local receipts.
- **Integration trap:** A neutral market receipt may contribute GDP but must not pass through the normal player-cash branch.
- **Reusable pattern:** Remote-first usage maps, capped residual budgets, merged usage, then warehouse/backpressure prevents double allocation.
- **Stale evidence:** A positive local receipt alone does not prove capacity is bounded or that unsold production survives save/load.
- **Next dependency:** A11 authors the local self-consumption card terms and completes the modifier lifecycle in this owner; coordination reruns the vertical slice afterward.
