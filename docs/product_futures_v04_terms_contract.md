# Product Futures v0.4 Terms Contract

## Sprint 55 hard alignment

The ten Sprint 54 recommendations are now approved production terms. `ProductFuturesTermsCatalogResource` is the single Inspector-editable source for direction, duration, multiplier, units, warehouse requirement, `action_fee_cash`, `margin_cash`, `maximum_gain`, `maximum_loss`, and formula IDs. Resource load failure is explicit; there is no card-definition or legacy formula fallback.

### Authored v0.4 card matrix

| Cards | Duration | Multiplier | Units | Margin | Maximum gain | Maximum loss |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 商品看涨/看跌 I | 60s | 1.00 | 1 | 120 | 260 | 120 |
| 商品看涨/看跌 II | 75s | 1.45 | 1 | 180 | 420 | 180 |
| 商品看涨/看跌 III | 95s | 2.05 | 1 | 260 | 650 | 260 |
| 商品看涨/看跌 IV | 120s | 2.80 | 1 | 360 | 900 | 360 |
| 港仓囤货 I | 90s | 0.75 | 2 | 180 | 360 | 180 |
| 港仓囤货 II | 105s | 0.90 | 3 | 260 | 560 | 260 |
| 港仓囤货 III | 120s | 1.05 | 5 | 400 | 850 | 400 |
| 港仓囤货 IV | 150s | 1.25 | 8 | 600 | 1200 | 600 |

All twelve cards use `action_fee_cash=0`; their existing `cost` remains purchase price only. Queue commit authorizes action fee + bid + margin without deducting margin. Effect open rechecks funds, deducts `locked_margin`, and atomically appends the position. Expiry computes directional raw P&L, caps gain/loss, returns `locked_margin - loss + gain`, and removes the position exactly once.

Warehouse destruction receives only `max_hp`, `pre_hit_hp`, and `post_hit_hp`. Its loss is `round(maximum_loss * (1 - post_hit_hp / max_hp))`. Partial damage does not settle; destruction with zero post-hit HP realizes maximum loss exactly once. Old saves normalize once with zero locked margin and zero maximum loss, so no retroactive charge occurs.

The Product Market Bench records **100/100**: 24 historical baseline-integrity records and **76/76 live aligned** records, with zero open design decisions.

## Sprint 54 scope

Sprint 54 characterizes the twelve real product-futures cards against rulebook v0.4 section 20. It does not change production settlement, add a second financial engine, or alter `main.gd` or `ProductMarketRuntimeController`.

The authoritative runtime owner remains `ProductMarketRuntimeController`. `CardEconomyProductRouteFormulaRuntimeService` remains the pure arithmetic owner for the currently observed payout formula.

## Current card matrix

| Family | Ranks | Purchase cost | Direction | Duration seconds | Multiplier | Units | Market pressure |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 商品看涨 | I-IV | 4 / 6 / 8 / 10 | up | 60 / 75 / 95 / 120 | 1.00 / 1.45 / 2.05 / 2.80 | 1 | demand 1 / 2 / 3 / 4 |
| 商品看跌 | I-IV | 4 / 6 / 8 / 10 | down | 60 / 75 / 95 / 120 | 1.00 / 1.45 / 2.05 / 2.80 | 1 | supply 1 / 2 / 3 / 4 |
| 港仓囤货 | I-IV | 5 / 7 / 9 / 11 | up | 90 / 105 / 120 / 150 | 0.75 / 0.90 / 1.05 / 1.25 | 2 / 3 / 5 / 8 | demand 2 / 3 / 4 / 5 |

`cost` is the card acquisition price. It is not a play action fee. The current play requirement reports `play_cash_cost=0` for all twelve cards.

## Position fields and ordering

At open, the Controller locks:

1. The underlying product by storing the position under that product's market entry.
2. `baseline_price` from the live product price.
3. `expires_at` from game time plus the authored duration.
4. `direction`, `multiplier`, `units`, and optional `warehouse_district`.
5. Private `owner` and card `source` for later settlement and save/load.

The position does not currently contain a margin, maximum gain, maximum loss, warehouse maximum HP, pre-hit HP, or post-hit HP.

## Current settlement

- Favorable movement pays `favorable price delta * 10 * units * multiplier`.
- Adverse movement pays zero and creates no negative cash settlement.
- Zero movement pays zero.
- Expiry settles and removes the position exactly once.
- A destroyed warehouse removes matching positions exactly once with zero cash delta.
- Private save data retains owner identity. Public market snapshots remove owner identity.

## v0.4 gaps

Rulebook v0.4 requires explicit margin, reference, duration, direction, multiplier, maximum gain, maximum loss, and special settlement terms. Reference, duration, direction, and multiplier are present. Margin and both caps are absent.

Warehouse destruction is detected from district `hp` and accumulated `damage`, but the Controller receives only `district_index` and `source`. It therefore cannot implement the rulebook's card-term and remaining-HP settlement yet.

## Sprint 55 entry gate

Sprint 55 must not begin until the ten decisions in `product_futures_v04_design_decisions.md` are approved. The cutover must then add authored terms, update Queue preflight and settlement atomically, migrate save defaults, update AI risk scoring, and remove any superseded fields in one change. No legacy fallback is permitted.
