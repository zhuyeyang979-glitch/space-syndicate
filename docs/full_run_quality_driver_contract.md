# FullRunQualityDriver Contract

## Purpose

`FullRunQualityDriver` is the honest fixed-seed full-match and resume-regression harness.
It drives the real `res://scenes/main.tscn` through public UI action IDs, observes only
authoritative public/viewer-safe snapshots and never manufactures a terminal result.

One process executes one seed. Twenty separate successful runs are required before an
aggregate twenty-seed claim may be published.

This document defines the target acceptance for the regional-supply, ambient-consumption,
market-backlog, warehouse/waste, optional-route and transient-window round. It does not
claim that the baseline driver already covers every target assertion.

## Current v2 boundary

The current driver:

- loads the real Main scene and scene-owned `GameRuntimeCoordinator`;
- uses the recommended four-seat setup with three AI opponents;
- seeds the existing gameplay RNG from the audited 20-seed list;
- submits actions through RuntimeGameScreen, DistrictSupplyDrawer and PlanetMapView signals;
- observes authoritative clocks, viewer-scoped forced decisions, Victory and final settlement;
- emits NDJSON containing only public/aggregate fields;
- uses bounded test-only acceleration without adding a production speed control.

Fresh-run preflight requires a valid 19-binding registry and all runtime composition ports,
but does not pretend incomplete resume support is complete. At `main@b2441cc` the registry
reports 8 transactional / 10 unsupported bindings; capture correctly fails closed with
`restore_capability_incomplete`.

The round is not complete until resume preflight reaches 19/19 and the driver performs a
real save, fresh-world restore and continued settlement.

## Required run stages

For each seed, the target driver must record these stages without directly ticking child owners:

1. `capability_preflight`
2. `new_session_started`
3. `region_supply_observed`
4. `market_before_factory_opening`
5. `backlog_accumulating`
6. `supply_connected`
7. `backlog_recovering`
8. `warehouse_then_waste_observed`
9. `save_checkpoint_written`
10. `fresh_world_restored`
11. `post_restore_no_duplicate_settlement`
12. `victory_resolved`
13. `final_settlement_presented`

The harness may choose equivalent legal player actions for a seed. It may not force card
identity, inject stock, set backlog, mutate facility capacity, draw a future bag card, edit
cash/GDP or call a settlement method directly.

## Round-specific assertions

### Regional supply

- Same seed produces the same exposed rack sequence and refresh lineage.
- Different audited seeds produce different sequences across the suite.
- At least one seed demonstrates a market card before a factory card.
- At least one seed demonstrates a factory card before a market card.
- Opening/closing/hovering/scrolling the rack does not change supply revision.
- Buying one slot refills only that slot.
- Save/restore preserves all rack slots, bag cursor, unique-card claims and refresh sequence.
- Driver output never contains the future bag order.

### Commodity flow

- A surviving non-ruined region has low “区域基础消费” for every active commodity without a market.
- Only same-region and directly adjacent land-region ambient delivery is observed.
- Unmet ambient consumption does not appear as saved debt.
- A concrete market demand accumulates “市场待满足需求” with no supply or no legal route.
- Supply equal to normal demand holds backlog; extra legal supply reduces it gradually.
- Recovery stays within market, route, recovery-rate and backlog-cap limits.
- Warehouse stock can serve explicit market demand but is not drained by “区域基础消费”.
- Fresh surplus enters a legal same-color warehouse before becoming “浪费产能”.
- One unit cannot be sold, stored and wasted in the same lineage.

### Optional route presentation

- A new run reports `selected_trade_product_id=""` and no visible commodity route.
- Full-map mode does not implicitly enable routes.
- Selecting one commodity reveals only current/recent actual flow for that commodity.
- Closing the route view hides every commodity line immediately.
- Toggling or switching presentation leaves economic fingerprints unchanged.
- AI inputs contain no local route-visibility preference.

### Transient windows

- Region rack is absent from layout until explicit open.
- Single-click region selection does not open it.
- Public preview does not create a quote; explicit purchase intent creates a 5-second
  `world_effective` quote.
- Full “牌序竞价” is visible only during `public_bid`.
- Monster wager, counter, contract, full-hand and target windows appear only when their
  authoritative decision exists.
- `ForcedDecisionRuntimeScheduler` exposes at most one actionable decision surface.
- Back cannot bypass a forced decision or open pause behind it.
- Resolution closes the surface, removes it from layout and restores legal focus.

## Save checkpoint contract

The save checkpoint must use:

- production `V06SaveOwnerRegistry`;
- strict v3 envelope/handshake;
- `GameSaveRuntimeCoordinator` atomic transport;
- an isolated `user://test_runs/full_run_quality/<head>/<seed>/` path;
- a fresh Main instance for restore.

Before save and immediately after restore, the driver compares viewer-safe fingerprints for:

- exposed region rack and supply revision;
- market backlog and backlog revision;
- warehouse quantities;
- cumulative waste;
- recent public flow summary;
- session clocks and gameplay RNG continuation identity.

It then advances exactly one normal production tick path and proves:

- no extra backlog tick was applied during restore;
- no Sale Receipt replayed;
- no rack reshuffled;
- no warehouse quantity duplicated or disappeared;
- no cumulative waste changed without new production;
- quote validity follows restored `world_effective` expiry.

## 1280×720 and complete-run presentation gate

At least one headed acceptance run at `1280×720` must capture:

- clean main table with routes hidden and no persistent rack/bid/wager panels;
- explicitly opened region rack with primary controls unobscured;
- `public_bid` with only one full bid window;
- one forced decision with no overlapping actionable modal;
- one selected-product route view showing actual flow;
- post-close table with restored focus and no layout residue;
- final settlement board.

The driver itself remains headless-safe. Headed screenshots are coordinator-owned acceptance
evidence and do not change gameplay or seed order.

## Output and privacy

Console output is NDJSON only. Heartbeats and the final summary may include:

- seed, stage, elapsed public time and aggregate progress;
- registry counts and resume readiness;
- aggregate backlog/warehouse/waste deltas without supplier identity;
- active decision kind, priority group and public blocking flags;
- visible-route count for the locally selected commodity;
- settlement state and aggregate invalid-action/non-finite counters.

They never include:

- raw save envelopes or section payloads;
- future supply-bag order;
- card inventories or discard contents;
- exact participant balances;
- hidden ownership or supplier identity;
- AI plans, weights, learning data or private route plans;
- private quote bindings or transaction fingerprints.

## Forbidden shortcuts

The driver may not:

- use retired Main save snapshots;
- call child-owner tick methods directly;
- set cash, GDP, backlog, inventory, waste, timers or terminal state;
- bypass route legality or capacity;
- force a specific rack card outside normal seeded draws;
- keep route visibility on to make logistics run;
- open a presentation surface to advance its underlying economy;
- call settlement presentation before the authoritative outcome exists.

## Invocation

Single-seed preflight:

```powershell
& tools/invoke_godot_test.ps1 `
  -TestScript res://scripts/tools/full_run_quality_driver.gd `
  -TestArgument @('--', '--preflight-only', '--seed-index', '0', '--max-wall-seconds', '30') `
  -TimeoutSeconds 60
```

The fixed list remains under algorithm label
`space-syndicate-full-run-quality-v1:sha256-positive31`.

## Focused gate list

The implementation round requires all of:

1. `tests/region_supply_full_randomization_v06_test.gd`
2. `tests/commodity_flow_ambient_consumption_v06_test.gd`
3. `tests/commodity_flow_market_backlog_v06_test.gd`
4. `tests/commodity_flow_warehouse_then_waste_v06_test.gd`
5. `tests/market_before_factory_integration_v06_test.gd`
6. `tests/route_visibility_opt_in_v06_test.gd`
7. `tests/transient_gameplay_windows_v06_test.gd`
8. `tests/commodity_flow_backlog_save_roundtrip_v06_test.gd`
9. `tests/region_supply_rng_save_roundtrip_v06_test.gd`
10. `tests/commodity_flow_public_privacy_v06_test.gd`

## Completion evidence

The round may be marked complete only when:

- the production registry is 19/19 transactional;
- all ten focused tests named by the round pass;
- every required full-run stage is observed or an exact seed-specific failure is reported;
- save/restore continuation passes with zero duplicate demand, receipt or draw;
- `1280×720` layout evidence shows no persistent or stacked gameplay windows;
- full layout and full smoke have no new regression;
- twenty independent seed summaries are aggregated without private data.

Historical `2026-07-15` v2 contract/preflight runs remain useful baseline evidence, but they do
not satisfy this expanded round until the target save and surface stages are implemented.
