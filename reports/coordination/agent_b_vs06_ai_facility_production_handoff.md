# Agent B VS06-B5b/B6 Handoff — AI Facility Production Wiring

## Outcome

The B5a facility-bootstrap policy is wired to the existing production owners through one injected `AiV06EconomyActionPort`. Normal scheduling and the forced vertical-slice path both call `execute_v06_facility_bootstrap_cycle(force)`. No legacy city build, second owner, or second journal was introduced.

The vertical-slice Bench now reads Stage 5/6/8 evidence from authoritative facility, CommodityFlow, transaction, cash-ledger, and settlement-panel facts. Full-slice acceptance remains owned by the coordination thread.

## Modified files

- `scripts/runtime/game_runtime_coordinator.gd`
- `scripts/tools/tomorrow_playable_vertical_slice_bench.gd`
- `tests/ai_v06_facility_production_port_test.gd`
- `docs/ai_v06_facility_bootstrap_contract.md`
- `reports/coordination/agent_b_vs06_ai_facility_production_handoff.md`

The pre-existing B5a changes in `scripts/runtime/ai_runtime_controller.gd`, `scripts/runtime/ai_v06_economy_action_port.gd`, and `tests/ai_v06_facility_bootstrap_policy_test.gd` remain the policy/port consumer baseline.

## Production APIs

`GameRuntimeCoordinator` is the production delegate for the already-frozen B5a port methods:

- `market_snapshot(actor_id)`
- `purchase_rank_i_facility(actor_id, item_id, transaction_id, expected_market_revision, expected_player_revision, expected_source_revision)`
- `player_snapshot(actor_id)`
- `play_runtime_card(request)`
- `economic_source_snapshot(actor_id)`

The Coordinator injects one `AiV06EconomyActionPort` during configure and every production-player binding refresh. The delegate forwards to:

- canonical rank-I market + `CommodityCardInventoryRuntimeController` for purchase/player/journal truth;
- existing `play_v06_runtime_card` → CardFlow → facility composite effect path;
- `RegionInfrastructureRuntimeController` for facility/slot ownership;
- `CommodityFlowRuntimeController` for permanent production installations;
- the existing Inventory/CardFlow transaction journal for `bootstrap_finalized` and lineage.

The adapter stores no cash, cards, facility, flow, bootstrap marker, or transaction result.

## Target legality and updated product rule

Legal candidates are derived from authoritative region commodity facts, facility industry, allowed lifecycle state, and an unoccupied unique slot. Explicit demand or a remote route is not a construction prerequisite. A focused real-owner fixture confirms a production region with no demand endpoint remains legal.

The Coordinator does not reproduce local GDP logic. A10/CommodityFlow remains authoritative for:

- `local_production_baseline` and `local_market_baseline` absorption;
- remote-route priority and premium;
- unsold accumulator, warehouse, and backpressure behavior;
- Sale Receipt, GDP, and cash settlement.

## Bench changes

- Stage 5 no longer asks legacy `_first_table_player_city_district` for GDP. It uses the actual new Sale Receipt `market_region_id`, then reads `region_gdp_snapshot` for that region.
- Stage 5 records actual `trade_kind`, local sold units, backpressured milliunits, and warehouse stored milliunits. PASS requires only positive authoritative receipt/cash/ledger/GDP evidence, not full capacity sell-through.
- Stage 6 replaces the removed `_auto_expand_rival_syndicates` path with two calls to the same forced bootstrap cycle used by normal AI scheduling.
- Stage 6 counts newly owned facilities, active production installations, owner-view Sale Receipts, AI cash delta, actual trade kinds, local sold units, and queue idle state. Legacy city count/business action metrics are gone.
- Stage 8 locates the real `FinalSettlementBoardPanel` by identity/scene path plus `set_board`, visible-in-tree state, and non-zero geometry. Replay must still leave exactly one panel.

## Focused evidence

Godot 4.7 stable, isolated `APPDATA`/`LOCALAPPDATA`:

1. `godot --headless --path <project> --script res://tests/ai_v06_facility_bootstrap_policy_test.gd`
   - PASS, 40 checks.
2. `godot --headless --path <project> --script res://tests/ai_v06_facility_production_port_test.gd`
   - PASS, 26 checks.
   - Uses the real Coordinator scene and real Inventory/CardFlow/RegionInfrastructure/CommodityFlow owners.
   - The focused fixture opens the Coordinator aggregate `_configured` gate only after asserting the state adapter, inventory, core economic adapter, and public-demand owners are ready; the omitted aggregate dependency is the unrelated Monster world contract.
3. `godot --headless --path <project> --script res://tests/tomorrow_playable_vertical_slice_test.gd -- --parse-only`
   - PASS.
4. `godot --headless --path <project> --script res://tests/final_settlement_board_visibility_truth_v06_test.gd`
   - PASS, 16 checks.

No full vertical slice, MCP/headed run, or default `user://` save was executed. Two initial full-main focused attempts stalled before the first assertion; both owned headless process groups were terminated, the oracle was reduced to the Coordinator scene, and no test process remains.

## Privacy and ownership boundary

The AI public snapshot remains coarse: availability, state/reason, and aggregate attempt/success counts. It does not expose actor, cash, hand, runtime instance, transaction lineage, route/scoring metadata, or raw owner receipts. The five delegate snapshots are AI-private production capabilities and return only pure data required for the action.

## Known risks / coordination acceptance

- A10 must provide the final `trade_kind` and local-baseline receipt fields. The Bench records them verbatim and does not infer missing values.
- The coordination thread must run the full isolated vertical slice after A10 lands to confirm at least one AI receives a positive authoritative local or remote Sale Receipt and cash delta.
- Stage 6 intentionally performs up to two bootstrap cycles so the second AI may proceed after the first seat finalizes; the production policy still finalizes at most one seat per cycle.
- The generic Coordinator delegate methods are private production surfaces by contract; UI code must not expose their player/source payloads.

Suggested coordination command:

`godot --headless --path <project> --script res://tests/tomorrow_playable_vertical_slice_test.gd`

Run only with the established isolated QA save environment after A10 integration.

## Lessons for other agents

- **Invariant:** AI submits actor/item/revisions/region only; all price, card, cash, facility, flow, and finalize truth remains with existing owners.
- **Failed approach:** a full `main.tscn` focused oracle stalled before assertions and left two child process groups; use the Coordinator scene for narrow production-port evidence and reserve full-main execution for the unified gate.
- **Stable API:** the five `AiV06EconomyActionPort` delegate methods above and `execute_v06_facility_bootstrap_cycle(force)` are the frozen consumer boundary.
- **Test oracle:** assert real journal cardinality, cash/card exact-once, one facility, one permanent production installation, source revision/lineage, and replay with before/after owner snapshots.
- **Integration trap:** Coordinator aggregate readiness includes unrelated Monster capability. A narrow fixture must prove every facility-chain owner ready before isolating that aggregate dependency; production must never bypass it.
- **Reusable pattern:** derive persistent policy markers from finalized owner journals instead of creating an AI-local marker store.
- **Stale evidence:** direct-neighbor demand coverage, legacy city counts, `_first_table_player_city_district`, `_auto_expand_rival_syndicates`, and `FinalSettlementBoard`/`MatchRecapPanel` node-name searches are no longer valid acceptance facts.
- **Next dependency:** A10 CommodityFlow local-baseline receipts and the coordination thread's single full-slice acceptance run.
