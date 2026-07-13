# City / Trade Network Runtime Ownership Contract

## Sprint 64 status

Sprint 64 completed the hard cutover. `CityTradeNetworkRuntimeController` is the only owner of city/trade-network derived state, route graph/path selection, refresh orchestration, payout-source composition, project sequence, and the city-network save envelope. `CityTradeNetworkWorldBridge` is deliberately non-owning: it captures world facts and applies receipts, but it does not score routes, choose paths, calculate GDP, or hold network state.

The Sprint 63 production baseline was:

- SHA-256: `5FA89D097B6E808435396CCDF72B2FA7A45A6848A4800986F90366849DCD688E`
- 23,639 total lines
- 20,933 nonblank lines
- 1,309 functions
- 142 top-level variables
- 211 constants

The final Sprint 64 result is:

- SHA-256: `B8174D78AA08BE2883E7EA5C7A5568CB8C5ED902D1945BCE0EAE8F7D3AD3CC67`
- 23,174 total lines
- 20,494 nonblank lines
- 1,296 functions
- 141 top-level variables
- 211 constants
- Net deletion: 439 nonblank lines, 13 functions, and 1 top-level variable
- Runtime gate: 68/68 observed and 68/68 aligned

## v0.4 semantic boundary

- A city contains concrete product projects in the `production`, `demand`, and `commerce` directions.
- Shares and control belong to one specific product project, not to a vague city-wide stock.
- The highest contributor controls a project; equal contributions use earliest contribution order, then lower player index.
- Public project state exposes product, direction, level, and GDP. It does not expose controller identity, contribution tables, or exact shares.
- Private project state adds only the viewer's own share, contribution, and controller flag.
- City GDP is distributed to active projects by project level, then to players by project share. Flooring remainder is assigned deterministically so totals remain exact.
- Destroyed districts retain historical city/project records but receive zero project GDP and no realtime payout.

## Observed refresh order

`CityTradeNetworkRuntimeController.refresh_networks()` performs this exact order:

1. Recalculate cross-owner product competition.
2. Rebuild routes for each city demand.
3. Consume `trade_route_damage` in demand-list order.
4. Assemble city facts and delegate GDP arithmetic to `GdpFormulaRuntimeController`.
5. Allocate city GDP to product projects and player shares.
6. Revalidate the permanent city-development supply slot.

Product-market price refresh is intentionally separate. City development and other callers request `_refresh_city_networks()` and then explicitly ask `ProductMarketRuntimeController` to refresh prices when their transaction requires it.

## Current ownership

### CityTradeNetworkRuntimeController

- `city_product_project_sequence` and its deterministic claim order.
- Project normalization plus public/private project snapshot orchestration.
- Active-city and cross-owner competition derivation.
- Supply discovery, shortest-path selection, route cost, disruption, speed, flow, and route-damage ordering.
- Network refresh order and assignment of derived route/GDP state through receipts.
- Project-share versus legacy-owner payout-source composition and city cashflow remainder state.
- Current and legacy-compatible city-network save/load normalization.

### CityTradeNetworkWorldBridge

- Captures pure world facts from real districts, players, time, topology, transport, production, consumption, roles, markets, and elimination state.
- Reuses isolated read snapshots only within one process frame; every network/cashflow receipt and world rebind invalidates the cache.
- Applies network, disruption, and cashflow receipts exactly once.
- Forwards existing public logs, action callouts, and economic events.
- Owns no runtime state, rule constants, route decisions, payout formulas, or save data.

### main.gd

- Retains narrow stable adapters used by existing world callers: active cities, competition, route reads, refresh request, product route reads, destruction disruption request, GDP breakdown request, and cashflow settlement request.
- Captures and applies ordinary world state through `GameRuntimeCoordinator` and the non-owning bridge.
- Does not contain route/path algorithms, refresh algorithms, payout-source assembly, project sequence state, or a fallback network engine.

### Existing owners that must not be absorbed

- `CityProductProjectState` / `CityProductProjectBridge`: pure project identity, contribution, share, controller, GDP allocation, legacy normalization, and privacy snapshots.
- `GdpFormulaRuntimeController`: city GDP arithmetic and breakdown text.
- `EconomyCashflowRuntimeController`: one-second cadence, per-minute conversion, fractional remainder arithmetic, and payout planning.
- `ProductMarketRuntimeController`: product price/market lifecycle.
- Contract, military, weather, and product-market controllers: their own mutations and policies; they only request a city-network refresh.
- AI: intent selection only.

## Route contract

- One demand creates one route record.
- No supply creates an explicit `disrupted=true`, `from=-1`, `source_type=无供给` record.
- Valid routes expose product, source/destination, path/points, source type, raw/effective cost, public speed, flow multiplier, flow speed, and flow amount.
- A city source is labeled `城市`; a regional product source is labeled `产区`.
- Path cost uses edge distance and average node multipliers. Ocean nodes retain a `0.88` modifier before transport speed. Destroyed nodes add `4.0`, miasma adds `0.35`, and panic adds `0.002` per point.
- Any destroyed path node marks the route disrupted.
- `trade_route_damage` disrupts otherwise valid routes in demand-list order; leftover damage remains in the disrupted count.

## Save and privacy contract

- Current save version remains unchanged.
- `districts` include embedded city projects and derived route state.
- `city_product_project_sequence` is saved separately.
- Missing legacy sequence keeps the compatibility default; legacy city products/demands normalize into project records when read.
- Public project/route snapshots must not expose controller identity, contribution/share tables, hidden owner, private targets, private discard, or AI plans.

## Reference-driven presentation and authoring boundary

The Mindustry, shapez.io, OpenLoco, and Widelands references do not reopen runtime ownership. They may inform legal/illegal preview color, endpoint snapping, route direction, segment undo vocabulary, throughput diagnostics, and editor graph authoring, subject to these rules:

- Ruleset v0.4 routes remain automatically derived from production, demand, topology, transport, market, and damage facts. There is no free manual pipeline-build action.
- `Line2D` or `Curve2D` may render public route snapshots but may not own capacity, cost, flow, product inventory, disruption, player identity, GDP, or save state.
- `AStar2D` may replace the internal path helper only after deterministic parity for costs, source selection, tie-breaks, destroyed nodes, and save/public output.
- `GraphEdit` is permitted only for editor/QA topology authoring. Every connection must pass project validation before a versioned pure Resource is written.
- A future manual infrastructure rule must extend this controller's committed graph ownership after a versioned rules decision; a parallel `PipelineGraph` runtime engine is forbidden.

The presentation, navigation, deletion, and optional future-construction roadmap is `docs/navigation_trade_network_reference_adoption_plan.md`.

## Sprint 64 deletion gate result

The cutover deleted the mapped `main.gd` implementations in the same change. The following ownership is absent from `main.gd`:

- Project sequence state.
- Route-base-flow helper and route graph/path/cost/disruption algorithms.
- Supply-source discovery and source classification.
- Competition and route rebuild algorithms.
- Network refresh sequencing and payout-source assembly.
- Direct destruction-disruption and city-cashflow mutation bodies.

Stable world-facing adapters remain only where existing gameplay callers require them; reflective tests were migrated to the Controller API instead of preserving obsolete wrappers.

The following owners remain intentionally separate:

- `CityProductProjectState` / `CityProductProjectBridge`: project identity, shares, allocation, normalization, and privacy projections.
- `GdpFormulaRuntimeController`: GDP arithmetic and breakdown presentation data.
- `EconomyCashflowRuntimeController`: cadence, fractional remainder arithmetic, and payout plans.
- `ProductMarketRuntimeController`: market state, prices, and financial positions.
- Contract, military, weather, monster, AI, Queue, Execution, and card-effect services: their existing domain ownership.

There is no parallel route engine, source-level fallback, or second city-network save owner.

The First Table compatibility path now recognizes v0.4 AI participation through private project-share snapshots instead of relying only on the retired city-wide owner field. It can also acknowledge a real resolved AI card already visible on the anonymous public track. Neither path exposes owner identity or AI private plans.
