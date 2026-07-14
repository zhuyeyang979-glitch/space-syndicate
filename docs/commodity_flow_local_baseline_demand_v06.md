# CommodityFlow Local Baseline Demand v0.6

## Ownership

`CommodityFlowRuntimeController` remains the only owner of continuous commodity allocation and Sale Receipts. Local baseline demand is part of that same flow plan; it is not a second market, route, cashflow system, or transaction journal.

## Three-Layer Allocation

Each fixed-point tick is allocated in this order:

1. **Remote route:** existing factory-to-market matching, route capacity, distance premium, rent, and proportional many-to-many allocation run unchanged.
2. **Local production baseline:** only production milliunits left after remote matching are eligible.
3. **Local market baseline:** only demand milliunits left after remote matching are eligible.

The usage maps are merged before warehouse and backpressure processing. One supply or demand milliunit can therefore enter only one bucket.

## Authored Terms

The runtime scene exposes Inspector-editable terms:

| Field | Default | Meaning |
|---|---:|---|
| `local_production_absorption_units_per_minute` | 1 | Absolute local factory absorption ceiling. |
| `local_production_absorption_rate_cap_basis_points` | 1000 | Local production may absorb at most 10% of that installation's effective rate. |
| `local_market_turnover_units_per_minute` | 1 | Absolute local market turnover ceiling. |
| `local_production_baseline_value_basis_points` | 1000 | Local factory sale value, 10% of the current commodity base price. |
| `local_market_baseline_value_basis_points` | 500 | Local market turnover value, 5% of the current commodity base price. |

The production budget is `min(absolute ceiling, 10% of effective installed production)`. Fixed-point budget remainders are namespaced inside the authoritative rate-remainder state, preventing per-tick rounding loss.

Remote receipts retain the existing full base value plus the unchanged distance premium. No remote price, rent, capacity, or route formula is modified.

## Receipt Contract

All three layers produce authoritative Sale Receipts.

- `trade_kind=remote_route` retains the existing factory, market, route, rent, and distance lineage.
- `trade_kind=local_production_baseline` uses the production region for both endpoints, `demand_kind=public_local`, an empty route and market, and no rent.
- `trade_kind=local_market_baseline` uses the market region for both endpoints, `supply_kind=public_local`, an empty route and factory, and no rent.

A player-owned local facility receives the exact `owner_net_cash` recorded by its receipt. A neutral/public market uses `commodity_owner=-1`, `economic_owner_kind=public_local`, and `owner_net_cash=0`: it contributes region GDP but cannot create player cash or rent. `CommodityFlowWorldBridge` accepts only that exact neutral shape and rejects forged neutral cash.

## Backpressure And Persistence

Local production does not absorb all unused capacity. Remaining output continues through existing warehouse routing and then backpressure. The controller persists `backpressured_milliunits_by_source` as authoritative blocked-output accounting; it is not inventory and cannot be resold. Warehouses therefore retain their economic purpose.

Save data records the baseline terms, fixed-point budget remainders, receipt sequence, recent receipts, and per-source cumulative backpressure. Loading a save authored with different baseline terms fails closed without state mutation. Older v0.6 snapshots that predate these fields use the active scene defaults; newly written snapshots always include the explicit schema.

## Privacy

Public receipt projection continues to remove commodity owner, private installation IDs, observer intents, and rent recipients. The new receipt fields contain only trade classification, public region lineage, and value terms. No UI or player-facing text is added by this cutover.

## Future Card Modifier Contract

The future card that increases local self-consumption must use `one_time_effect_kind=local_baseline_modifier` and these machine fields:

- `local_production_absorption_delta_units_per_minute`
- `local_market_turnover_delta_units_per_minute`
- `local_baseline_modifier_seconds`

It must use the existing `prepare_card_effect_batch` / `commit_card_effect_batch` / `rollback_card_effect_batch` / `finalize_card_effect_batch` lifecycle, with expiry and save/load owned by `CommodityFlowRuntimeController`. A10 deliberately does not invent the card's values or hard caps. Until A11 authors those terms and implements the complete lifecycle, capability reports `available=false` and prepare fails with `local_baseline_modifier_terms_not_authored` before mutation.
