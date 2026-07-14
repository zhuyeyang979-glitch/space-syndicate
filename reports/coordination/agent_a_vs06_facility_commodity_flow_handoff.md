# Agent A - VS06-A6 Facility Commodity Flow Handoff

## Status

The A6 owner scope is complete at focused-evidence level. A canonical rank-I factory card now reaches the single production chain, creates one real `RegionInfrastructureRuntimeController` facility and one permanent `CommodityFlowRuntimeController` production installation, and remains exact-once through the outer Inventory/CardFlow transaction.

The current generated main-map facts still have no exact product intersection between production and demand in the observed run (`authoritative_map_match=false`). The focused oracle therefore adds one neutral public demand endpoint through the same authoritative Coordinator, RegionInfrastructure, and CommodityFlow APIs. With that explicit compatibility fixture, the first five one-second ticks produce no sale and the sixth tick produces exactly one real Sale Receipt, positive region GDP, and a cash ledger delta equal to `owner_net_cash`.

No `main.gd`, map-generation code, catalog data, pricing formula, UI, AI, or monster owner was modified. Real-main Stage 5 remains structurally blocked until the map owner guarantees an economically viable product intersection.

## Unique Owner Graph

```text
canonical v0.6 card instance
-> GameRuntimeCoordinator facade
-> CommodityCardInventoryRuntimeController / one CardFlow transaction
-> CoreEconomicCardRuntimeAdapterV06
-> FacilityCardEffectAdapterV06 composite receipt
   -> RegionInfrastructureRuntimeController (facility lifecycle)
   -> CommodityFlowRuntimeController (permanent product installation)
-> CommodityFlowWorldBridge (Sale Receipt cash ledger application)
```

Neutral public demand is owned by RegionInfrastructure plus CommodityFlow. It has `owner_kind=public`, no player installer, no player GDP attribution, and no market-rent beneficiary. It is not represented by player 0 and does not create a second economy owner or journal.

## Modified Files

- `scripts/runtime/region_infrastructure_world_bridge.gd`
  - Added authoritative pure-data region production and demand facts.
- `scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd`
  - Added the facility plus permanent-production composite lifecycle.
- `scripts/runtime/commodity_flow_runtime_controller.gd`
  - Added validated neutral public demand, installation finalize preflight, save/load validation, and safe demand-only flow planning.
- `scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd`
  - Added optional injection of the authoritative region-product facts port.
- `scripts/runtime/game_runtime_coordinator.gd`
  - Added exact-once public-demand bootstrap and product-aware rank-I facility selection.
- `scripts/runtime/commodity_card_inventory_runtime_controller.gd`
  - Made composite receipts indivisible and propagated compensation failure through the outer transaction boundary.
- `tests/vs06_facility_commodity_flow_integration_test.gd`
  - Added the focused composite lifecycle and sixth-second Sale Receipt oracle.

The shared worktree contains several of these paths as untracked files. Nothing was staged, committed, merged, pushed, reset, cleaned, or reverted.

## Frozen APIs

### Region facts

- `region_commodity_facts(region_id: String) -> Dictionary`
- `public_commodity_region_facts() -> Array`
- `selected_region_commodity_facts() -> Dictionary`

These return authoritative pure-data product IDs, industry IDs, region revision, and facts fingerprint. Runtime selection never infers a product from card display text.

### Commodity installation

- `install_public_demand(request: Dictionary) -> Dictionary`
- `commodity_installation_finalize_preflight(receipt: Dictionary) -> Dictionary`
- Existing `finalize_commodity_installation(receipt)` consumes the preflight result.

Public demand is accepted only for a real neutral market facility and a demand-direction installation. It cannot pay player cash, rent, or GDP attribution.

### Core adapter

`CoreEconomicCardRuntimeAdapterV06.configure(...)` now accepts an optional fifth `region_product_facts_port`. The existing four-argument configuration remains facility-only; production composition supplies the fifth port and requires permanent-installation readiness.

## Atomic Lifecycle Evidence

- Prepare remains mutation-free.
- Commit applies the canonical facility first, then installs the authoritative local product permanently.
- A commodity-install failure triggers reverse-order rollback. If compensation cannot complete, the outer transaction exposes `effect_compensation_failed`, `compensation_failed=true`, and `recovery_required=true`; checkpoint remains blocked.
- Facility and commodity receipts are wrapped in `facility_commodity_composite`. Inventory/CardFlow must not recursively extract a nested facility receipt when composite rollback or finalize fails.
- Finalize preflights both owners before mutation, then finalizes the facility and commodity in one synchronous path. A failed first attempt remains retryable; replay closes both rollback windows without duplicate mutation.
- Public-demand bootstrap rejects groups with more than one product before any owner mutation. The current v0.6 map fact shape therefore cannot partially finalize a multi-product group.
- Public bootstrap transaction binding is stable: deterministic transaction IDs plus fixed `occurred_at=0.0` and `installed_at=0.0` prevent world-time drift across refresh/load.
- Demand-only commodities now use an empty production-claim array instead of indexing a missing dictionary key. This preserves the accumulator while safely producing no flow until matching supply exists.

## Focused Verification

All commands used Godot `4.7.stable` with isolated temporary `APPDATA` and `LOCALAPPDATA` directories.

- `tests/vs06_facility_commodity_flow_integration_test.gd`: PASS, `37/37`, failures `0`.
- `tests/core_economy_production_integration_v06_test.gd`: PASS, `65/65`, failures `0`.
- `tests/facility_card_production_unlock_v06_test.gd`: PASS, `64/64`, failures `0`.
- Focused tracked diff whitespace check: PASS.

No default player save, full smoke, full vertical slice, MCP/headed scene, screenshot, commit, or staging operation was run. Unified acceptance remains coordinator-owned.

## Structured Blocker

- **blocker_id:** `VS06-A6-MAP-PRODUCT-INTERSECTION`
- **observed:** authoritative generated production-product set and demand-product set have zero exact intersection.
- **effect:** the real main map can create a permanent factory but cannot produce a Sale Receipt, GDP, or cash because CommodityFlow correctly refuses cross-product matching.
- **required owner:** roguelike map region product/demand generation.
- **required resolution:** guarantee at least one reachable exact-product production/demand pair for the first playable map without changing CommodityFlow matching, distance pricing, attribution, or ownership rules.
- **temporary test oracle:** one neutral demand endpoint created through the same authoritative owner APIs; it is test-only and is not production content.

Suggested coordinator acceptance after the map owner fixes the intersection:

1. Re-run the isolated Tomorrow Playable Vertical Slice and require Stage 5 to pass without the compatibility fixture.
2. Verify the real receipt route/factory/market/product binding and exact cash ledger delta.
3. Re-run the shared production composition and save/checkpoint gates once.

## Known Risks

- Real-main Stage 5 is not green until the map-generation dependency above is resolved.
- Production public-demand bootstrap intentionally supports one product per region/industry group; larger groups fail closed until a true batch-finalize protocol exists.
- The Coordinator is a shared hot file with prior parallel changes. This handoff claims only the A6 owner slice and focused tests, not a complete cross-agent regression.
- The compatibility fixture proves owner semantics, not map content quality or route reachability across every random seed.

## Lessons for other agents

- **invariant:** a Sale Receipt must bind an exact product, real factory, legal route, active market, and authoritative capacity; UI or card names are never economic facts.
- **failed approach:** using player 0 as a placeholder demand owner would leak rent/GDP attribution and was rejected.
- **stable API:** `install_public_demand` is the only neutral-demand install path; `commodity_installation_finalize_preflight` is required before closing a composite lifecycle.
- **test oracle:** at 10 units/minute, deterministic one-second ticks yield zero sales for seconds 1-5 and exactly one real receipt on second 6.
- **integration trap:** recursively searching a composite receipt for a nested facility receipt can report false success while commodity state remains open.
- **reusable pattern:** full preflight, owner-specific commit, reverse compensation, indivisible composite receipt, terminal replay, then checkpoint closure.
- **stale evidence:** a green facility-only test does not prove permanent production or a reachable demand endpoint.
- **next dependency:** the map owner must guarantee an exact production-demand intersection; the coordinator then reruns the real-main vertical slice without the compatibility fixture.
