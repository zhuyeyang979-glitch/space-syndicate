# Card Economy / Product / Route Formula Runtime Contract

## Sprint 39-40 ownership

`CardEconomyProductRouteFormulaRuntimeService` owns deterministic, pure-data arithmetic used by economy, product, futures, GDP-derivative, and route card effects. It does not read Nodes, mutate the world, dispatch card effects, advance the queue, own clocks, or write inventory.

The existing owners remain authoritative where the formula was already modular:

- Product price and price-step cap: `RuntimeBalanceModel`.
- Product flow-speed model: `RuntimeBalanceModel`.
- City GDP production, demand, transit, penalties, and floor: `GdpFormulaRuntimeController`.
- Card handler registration and result envelopes: `CardEconomyProductRouteEffectRuntimeService`.
- Concrete world mutation and feedback: existing world-rule functions reached through `CardEconomyProductRouteEffectWorldBridge`.
- Generic execution lifecycle: `CardResolutionExecutionRuntimeService`.

## Characterized pure formulas

The Formula Service owns:

1. Temporary and persistent product-market boon multiplier/cap/source merging.
2. Product speculation pressure: `max(1, ceil(abs(price_delta) / 10))`, routed to demand for non-negative deltas and supply for negative deltas.
3. Futures duration: explicit seconds or legacy turns at 30 seconds, with a 5-second minimum.
4. Futures payout: favorable price delta × 10 × units × multiplier, rounded to an integer.
5. Futures projected payout used by balance reporting, sharing the same payout unit.
6. GDP derivative duration: explicit seconds or legacy turns at 30 seconds, with a 1-second minimum.
7. GDP derivative expiry payout: favorable GDP delta × multiplier, rounded to an integer.
8. GDP derivative destruction payout: down-position baseline × multiplier plus destroy bonus.
9. Route base flow: geometric mean of production/consumption factors multiplied by the clamped public supply relation, floored at 0.35.
10. City/product route-flow multiplier composition, clamped to 1.0-2.8.
11. Stable boon-source merging without duplicate source labels.
12. Product-contract demand/supply maxima, legacy duration mirror, source merge, and volatility clamp.
13. City-contract income/duration maxima composed with the shared route-flow boon.
14. Automatic order/supply and ordinary city route-flow maxima, duration, source, and zero-floor route repair.
15. Route insurance repair, permanent revenue adjustment, and temporary route-flow boon.
16. City product upgrade using the first lowest-level slot, rank-V cap, and permanent revenue bonus.
17. City product shift of a supplied candidate into the first lowest-level slot, resetting it to rank I.
18. City demand shift of a supplied candidate using the existing modulo slot order.
19. Shared city revenue and route-repair adjustment used after product/demand transformations.

## Sprint 40 RNG and mutation boundary

The Formula Service never chooses a product or demand. `main.gd` still builds the exclusion list and calls `_economy_candidate_product()` in the original loop order, preserving the same selected-product preference, local catalog preference, and RNG consumption. Each supplied candidate is then transformed by one pure formula step.

Eligibility, owner checks, selected district/product state, panic, cash, product-market refresh, route-network refresh, public callouts, private ledgers, and logs remain world-adapter responsibilities. `CardResolutionExecutionRuntimeService` receives no formula identifiers, card-family branches, city snapshots, or world mutation authority.

## Mutation order

`main.gd` remains a world adapter:

1. Read public/runtime facts from districts, cities, products, and active card context.
2. Send a pure `Dictionary` to `GameRuntimeCoordinator.calculate_card_economy_product_route_formula()`.
3. Validate the pure result.
4. Apply the returned entry/scalar to the existing world state exactly once.
5. Continue existing private ledger, public clue, visual callout, and refresh hooks.

No formula result may contain a `Node`, `Callable`, `Object`, or `Resource`. No private owner, private target, private discard, or AI plan is added to public snapshots or QA reports.

## Deletion gate

Sprints 39 and 40 remove the characterized arithmetic bodies from `main.gd` while preserving compatibility wrappers and function signatures used by save/tests/reflection. The following must remain absent from `CardResolutionExecutionRuntimeService`:

- Product price, market boon, futures, GDP derivative, or route arithmetic.
- Concrete `_apply_*` card handlers.
- World references or mutation callbacks.

Sprint 40 additionally deletes the contract-boon, city product/demand slot, insurance, and shared city-adjustment arithmetic from `main.gd`. Future formula-family migrations should extend the Formula Service or add a sibling domain formula owner. They must not widen the generic Execution Service.
