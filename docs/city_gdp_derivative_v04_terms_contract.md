# City GDP Derivative v0.4 Terms Contract

## Runtime ownership

- `CityGdpDerivativeTermsCatalogResource` is the single authored source for the twelve city long, city short, and disaster-insurance cards.
- `CardResolutionQueueRuntimeService` authorizes action fee, bid, and margin. It does not deduct or lock derivative margin.
- `CityGdpDerivativeRuntimeController` owns position state, effect-open margin locking, GDP reference locking, expiry, city-destruction settlement, exact-once removal, and save normalization.
- `CardEconomyProductRouteFormulaRuntimeService` owns pure settlement arithmetic only.
- `CityGdpDerivativeRuntimeWorldBridge` exposes city/GDP/cash facts and routes committed cash, public clue, and presentation intents. It owns no financial decision or formula.
- `main.gd` retains narrow world mutation and presentation adapters. It does not store positions or calculate payout.

## Funding order

1. Eligibility and Queue read the same `gdp_derivative_terms` snapshot.
2. Queue confirms available cash for action fee, bid, and margin without deducting margin.
3. On effect open, the Controller rechecks cash against the authored margin.
4. Margin deduction, GDP reference lock, terms lock, and position creation commit atomically.
5. Cash drift produces `financial_margin_insufficient` or `cash_insufficient` without a position or partial deduction.

## Settlement

- `directional_delta = current_gdp - baseline_gdp` for longs and the inverse for shorts/insurance.
- `raw_pnl = round(directional_delta * multiplier)`.
- Gain is clamped to `maximum_gain`.
- Loss is clamped to `min(maximum_loss, locked_margin)`.
- Settlement returns `locked_margin - loss + gain`.
- Zero delta returns all margin.
- City destruction uses the authored destruction formula: longs take capped loss; shorts and insurance use baseline GDP plus the authored destroy bonus, capped by `maximum_gain`.
- Every committed expiry or destruction receipt removes the position immediately. A second settlement cannot pay it again.

## Save and privacy

- Current saves store `positions_by_district`, position identity, locked terms, locked margin, formula ids, and sequence in `city_gdp_derivative_runtime`.
- Legacy city-embedded `gdp_derivatives` are extracted once during load and erased from city dictionaries.
- Legacy positions normalize with `locked_margin=0` and `maximum_loss=0`; current authored `maximum_gain` is applied, with no retroactive margin charge.
- Public snapshots expose district counts, direction counts, insurance counts, and public settlement totals. They never expose owner, player index, private targets, hands, or AI plans.

## Deletion gate

`main.gd` must not contain `gdp_bet_*`, `_apply_city_gdp_derivative`, `_pay_city_gdp_derivative`, `_resolve_city_gdp_derivatives`, or the old positive-only payout formula ids. The 40-case `CityGdpDerivativeRuntimeBench` is the long-lived ownership gate.
