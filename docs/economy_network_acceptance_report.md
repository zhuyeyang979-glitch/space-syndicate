# Economy Network Acceptance Report

## Verdict

**Status: specification draft — not accepted.**

Baseline reviewed: `main@b2441cc`.

This document defines required evidence. It does not claim that production
code, focused tests, layout, smoke, save round-trips or headed runtime checks
have passed.

## Scope

The milestone covers:

- fully random regional ordinary-card supply;
- ambient regional consumption for every active commodity;
- concrete market-demand backlog and recovery;
- automatic market → ambient → warehouse → waste allocation;
- player-facing waste instead of active backpressure;
- market-first openings;
- opt-in actual-flow route presentation;
- transient purchase and forced-decision windows;
- save determinism, exact-once behavior and privacy.

This report is completed only after the Coordinator records real command,
runtime, layout and artifact evidence.

## Non-negotiable ownership gate

| State/rule | Required sole owner | Evidence status |
|---|---|---|
| Production/demand rates, fixed point, market backlog, inventory, waste, Sale Receipts | `CommodityFlowRuntimeController` | Pending |
| Route legality, ID, modes, capacity, arrival | `RouteNetworkRuntimeController` | Pending |
| Facilities, ranks, ownership, integrity, lifecycle | `RegionInfrastructureRuntimeController` | Pending |
| Commodity prices, trends, finance market | `ProductMarketRuntimeController` | Pending |
| Regional ordinary-card listings and purchases | Existing regional supply/CardFlow/DistrictPurchase owner | Pending |
| Forced-decision priority and blocking | `ForcedDecisionRuntimeScheduler` | Pending |
| Transient window presentation | `OverlayLayer` | Pending |

Acceptance fails if `main.gd`, UI, AI or any WorldBridge retains a writable
copy or fallback formula for these domains.

## Focused-test evidence matrix

| Required test | Required proof | Status | Evidence |
|---|---|---|---|
| `region_supply_full_randomization_v06_test.gd` | Same seed same order; different seeds differ; market/factory can appear in either order; no guarantees/phases; UI does not refresh; one-slot refill; AI cannot see future bag | Pending | To be filled |
| `commodity_flow_ambient_consumption_v06_test.gd` | Every live region/all commodities; same/adjacent-land only; no accumulation; no rents/premium; fair deterministic allocation | Pending | To be filled |
| `commodity_flow_market_backlog_v06_test.gd` | Backlog grows without supply/route; steady priority; equal supply holds; excess drains; caps/capacity; damage, pause, destruction and commodity isolation | Pending | To be filled |
| `commodity_flow_warehouse_then_waste_v06_test.gd` | Explicit sale before ambient; storage before waste; inventory excluded from ambient; no duplicate disposition or waste value | Pending | To be filled |
| `market_before_factory_integration_v06_test.gd` | Market and concrete demand precede supply, backlog grows, later automatic supply drains gradually | Pending | To be filled |
| `route_visibility_opt_in_v06_test.gd` | New game hidden; commodity selection reveals actual flows only; close hides immediately; visibility has no economic or AI effect | Pending | To be filled |
| `transient_gameplay_windows_v06_test.gd` | Purchase/bid/wager surfaces appear only on request/timing, do not reserve layout, cannot bypass forced choice, restore focus | Pending | To be filled |
| `commodity_flow_backlog_save_roundtrip_v06_test.gd` | Exact backlog/remainders/revisions; no duplicate tick or Sale Receipt | Pending | To be filled |
| `region_supply_rng_save_roundtrip_v06_test.gd` | Exact rack/bag/RNG/unique state/refill sequence; no reshuffle on load | Pending | To be filled |
| `commodity_flow_public_privacy_v06_test.gd` | Public backlog/flow without supplier identity, private owner, cash, hand or AI plan | Pending | To be filled |

## Completion checklist

Every item remains **Pending** until linked to real evidence.

1. Regional rack has no factory-first or market-after-factory rule. — Pending
2. All rack slots draw from one legal deterministic random pool. — Pending
3. A market card can appear, be bought and support backlog before a factory. —
   Pending
4. Every surviving non-ruin region has low ambient demand for every active
   commodity. — Pending
5. Ambient supply is limited to same region and direct-adjacent land consumer.
   — Pending
6. Concrete market unmet demand accumulates. — Pending
7. Extra supply gradually recovers backlog after steady demand. — Pending
8. Backlog respects market, route, recovery-rate and cap limits. — Pending
9. Fresh surplus attempts matching storage before waste. — Pending
10. Waste creates no cash, GDP, asset, mana or rent. — Pending
11. Ambient consumption never drains warehouse inventory. — Pending
12. Commodity logistics continue automatically without open UI. — Pending
13. Map commodity routes default hidden. — Pending
14. Player selection shows only committed/recent actual flow for one commodity.
    — Pending
15. Wager, public bid and regional purchase surfaces are not permanent table
    panels. — Pending
16. Transient surfaces appear only on explicit request or correct gameplay
    timing. — Pending
17. Surface close/completion frees layout and restores legal focus. — Pending
18. Rack, bag/RNG, backlog, inventory, waste, public flow summaries and
    exact-once state save and restore. — Pending
19. Public/AI/UI projections do not leak supplier identity or private
    planning. — Pending
20. All focused tests pass. — Pending
21. Full layout and smoke suites show no new regression. — Pending
22. `main.gd` gains no economy or UI owner responsibility. — Pending
23. Required rule and architecture documents are current and mutually
    consistent. — Pending

## Required runtime and layout evidence

The Coordinator must fill:

| Evidence | Required result | Status |
|---|---|---|
| Godot version | Supported project version | Pending |
| Focused economy suites | All required cases pass | Pending |
| Focused supply/UI suites | All required cases pass | Pending |
| Full layout gate at 1280×720 | No modal stacking or primary-button obstruction | Pending |
| UI text/source guard | No retired player-facing vocabulary | Pending |
| Full smoke | No new regression | Pending |
| Production scene/MCP run | No script/runtime error; clean stop | Pending |
| Save round-trip | Exact state and no duplicate transaction | Pending |
| Privacy scan | No forbidden private keys/identities | Pending |
| `main.gd` ownership delta | No new authority/formula/UI construction | Pending |
| `git diff --check` | Clean | Pending |

## Required quantitative evidence

Record at least:

- two seeds demonstrating different regional rack sequences;
- one repeated seed demonstrating byte-equivalent rack and refill order;
- one market-first run showing backlog at three timestamps: growth, partial
  recovery and zero;
- steady demand, recovery request, actual delivery, facility capacity and route
  capacity for the same recovery interval;
- fresh production disposition proving:
  `market + ambient + stored + wasted = produced`;
- unchanged warehouse inventory during an ambient-only interval;
- zero cash/GDP/rent rows for waste;
- a save/load comparison of backlog, inventory, cumulative waste, rack slots,
  bag/RNG state and receipt sequence;
- a hidden-versus-visible route-view comparison with identical economy hashes;
- a 1280×720 capture for idle table, regional rack, wager and public-bid timing.

## Player-copy gate

Allowed player-facing concepts:

- 区域基础消费
- 市场正常需求
- 市场待满足需求
- 市场追赶消费
- 已售出
- 已入库
- 浪费产能
- 查看商路
- 隐藏商路
- 区域牌架
- 牌序竞价

Forbidden player-facing terms:

- backpressure
- milliunits
- recovery basis points
- sink
- source-to-demand pair
- backlog revision
- route candidate
- world bridge
- controller
- owner
- snapshot
- raw state enum

## Known stale assertions at baseline

These paths were identified by the document scan and require update or
historical-only classification by their owners before final acceptance:

| Path | Baseline stale assertion |
|---|---|
| `docs/tabletop_rulebook_v06.md` | Isolated factory/market baseline, local self-sale and continuous backpressure |
| `docs/rules_v06_runtime_directive.md` | Continuous unmatched production becomes backpressure |
| `docs/rules_v06_development_plan.md` | The active cutover table still names backpressure as a route/warehouse target |
| `docs/roguelike_economic_viability_v06_contract.md` | Refers to the old local weak-GDP behavior and district demand assumptions |
| `scripts/tools/full_run_quality_driver.gd` and `tests/full_run_quality_driver_contract_test.gd` | Wait for a canonical factory/market pair |
| `scripts/tools/tomorrow_playable_vertical_slice_bench.gd` | Accepts old `local_*` trade kinds and `backpressured_milliunits` metrics |
| `docs/development_log.md` | Historical backpressure/local-baseline statements; must remain clearly historical only |

Active code/tests also contain old tokens and are implementation work, not
evidence of this document-stage commit:

- `scripts/runtime/commodity_flow_runtime_controller.gd`;
- `scripts/runtime/commodity_flow_world_bridge.gd`;
- `scenes/runtime/CommodityFlowRuntimeController.tscn`;
- `tests/commodity_flow_local_baseline_demand_v06_test.gd`;
- `scripts/tools/installed_commodity_continuous_economy_characterization_bench.gd`;
- vertical-slice and layout assertions that accept `local_*` trade kinds or
  `backpressured_milliunits`.

## Acceptance sign-off template

```text
Coordinator:
Integrated commit:
Ruleset/data terms commit:
Focused tests:
Layout/smoke:
Godot/MCP production run:
Save determinism:
Privacy:
main.gd ownership delta:
Known waivers:
Final verdict: ACCEPTED / REJECTED
```

Until every required row has evidence and the final verdict is explicitly
recorded as `ACCEPTED`, this report remains a specification draft.
