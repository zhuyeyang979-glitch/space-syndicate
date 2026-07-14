# SS05-05 Industry Capacity And Card Group Runtime Contract

## Ownership

- `IndustryCapacityRuntimeService` is the only owner of the derived six-industry capacity snapshot.
- `IndustryCapacityWorldBridge` only reads private project GDP facts from `CityTradeNetworkRuntimeController`.
- `CardPlayEligibilityRuntimeService` is the only owner of card requirement interpretation and reservation selection.
- `CardResolutionQueueRuntimeService` is the only owner of cumulative capacity reservations, submission lock, group release, fixed priority bids, and the public wager-pool receipt.
- `CardResolutionRuntimeController` is the only owner of the 8/6/2 clock and all-seats-ready early lock.
- UI surfaces only render snapshots and emit stable actions.

## Capacity

Attributable GDP per minute is grouped through `product_industry_catalog_v05.tres`; runtime code must not infer an industry from a product name or color.

| Attributable GDP/min | Capacity |
| --- | ---: |
| below 15 | 0 |
| 15-39 | 1 |
| 40-79 | 2 |
| 80-139 | 3 |
| 140 or above | 4 |

Cards in one unresolved group reserve capacity cumulatively. The reservation uses the snapshot selected at submission and survives later GDP drift. It is released exactly once only after the whole group leaves current, active, and next queues.

## Card Window And Priority Bid

- Total window: 8 seconds.
- Organize phase: first 6 seconds.
- Lock phase: final 2 seconds.
- Tutorial limit: 1 card per player group.
- Standard limit: 2 cards per player group.
- Priority bids: exactly 0, 5,000, or 10,000 cents.
- Equal bids are legal and keep the rotating clockwise tie-break.
- Every locked group bid enters one `public_wager_pool_receipt`; no bid is paid to a previous group.
- All active seats may mark ready during organize; readiness locks immediately without changing the ordering rule.

## Compatibility Boundary

The global production ruleset bridge, v0.4 card catalog, and save envelope remain active during SS05-05. The migrated card-window domain reads the approved v0.5 profile directly. Existing v0.4 cards without authored v0.5 requirements are treated as explicit colorless compatibility content. Blocked v0.5 cards remain excluded from release-ready pools; no industry requirement is guessed.

## Deletion Gate

Production code must not retain 30/25/5 constants, 3/4 group limits, arbitrary positive bids, positive-bid uniqueness, previous-group transfers, or a parallel capacity engine.
