# Card Economy / Product / Route Effect Runtime Contract

## Sprint 38 boundary

`CardEconomyProductRouteEffectRuntimeService` is the single pure-data dispatch owner for these seventeen handlers:

- Economy: `cash_gain`, `city_revenue_boost`, `city_gdp_derivative`.
- Product: `market_stabilize`, `product_speculation`, `product_futures`, `product_contract_boon`, `product_growth_boon`, `city_product_upgrade`, `city_product_shift`, `city_demand_shift`.
- Route: `area_trade_contract`, `route_insurance`, `route_flow_boon`, `route_sabotage`, `region_economy_shift`, `city_contract_boon`.

The service owns handler registration, family classification, pure effect plans, stable result envelopes, and the `area_trade_contract` continuation classification. It stores no active card or world state.

## Adjacent owners

- `CardResolutionExecutionRuntimeService` still owns active-card lifecycle ordering and exactly-once completion. It has no card-family table or concrete effect methods.
- `CardResolutionQueueRuntimeService` still owns current, active, and next queues.
- `CardResolutionRuntimeController` still owns the active 8/6/2 timing and response windows.
- Existing `_apply_*` functions still own concrete cash, market, futures, GDP, city, product, route, contract, logging, visual, and privacy mutations.
- `CardEconomyProductRouteFormulaRuntimeService` owns characterized deterministic market-boon, speculation, futures, GDP-derivative, and route arithmetic. Product price and city GDP remain in their already modular owners.
- `CardEconomyProductRouteEffectWorldBridge` is stateless. It applies a service plan to those existing functions and returns a pure receipt.

## Data contract

`plan_effect(request)` accepts only Dictionary, Array, String/StringName, Number, and Bool values. The plan contains a handler id, family id, resolution id, continuation classification, and a copied effect payload. It never contains a Node, Callable, Object, or Resource.

`finalize_effect(plan, receipt)` returns the existing `dispatch_effect` result shape: `dispatched`, `resolved`, `reason`, `handler_id`, `family_id`, and `continuation_kind`.

Public/debug snapshots contain the supported handler registry and aggregate counters only. They do not expose player indexes, targets, hands, private discards, AI plans, or anonymous actor identity.

## Preserved semantics

- No price, payout, GDP, duration, route, contract, target, AI, or privacy formula changed in Sprint 38.
- `area_trade_contract` remains a non-blocking contract-response continuation.
- Failed effects keep the existing no-refund commitment behavior owned by Execution Service.
- The bridge dispatches each supported plan once; Execution Service remains the exactly-once lifecycle gate.
- Missing service or bridge state fails closed. There is no legacy family-dispatch fallback in `main.gd`.

## Sprint 38 evidence

- Focused service test verifies the exact seventeen-handler registry, pure plans/debug output, all bridge routes, and the narrow ownership flags.
- `CardResolutionExecutionRuntimeCharacterizationBench` remains 28/28 observed, 28/28 aligned, and 28/28 cutover after the family routing change.
- `main.gd::_apply_card_resolution_effect_request()` calls Coordinator plan/finalize APIs and contains none of the seventeen concrete family branches.

## Sprint 39 formula result

The product-market boon, speculation pressure, futures, GDP-derivative, and route-factor formulas have moved to the sibling pure Formula Service. Compatible world function names remain as fact/result adapters, but their arithmetic bodies and the futures payout-unit constant are absent from `main.gd`.

The long-lived Bench now passes 28/28 observed, 28/28 aligned, and 40/40 cutover. Actual world mutation, ledgers, public clues, and visuals remain in existing owners. Execution Service did not gain formula knowledge.

The next deletion gate should characterize contract and city-product mutation arithmetic before moving it. Do not expand Execution Service or recreate queue/timer state in either service.
