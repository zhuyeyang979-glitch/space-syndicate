# Player Mana And Card Commitment Runtime Contract (SS06-04)

## Terms And Ownership

- Player-facing term: `六色资产`.
- Stable runtime owner: `PlayerManaRuntimeController`.
- Stable color IDs: `life`, `energy`, `industry`, `technology`, `commerce`, `shipping`.
- Asset balances and reservations are viewer-private. Public snapshots expose no amount or payer identity.
- `CommodityFlowRuntimeController` owns commodity movement and sale/GDP receipts. It only publishes recovery observations; it does not own asset balances.
- `CardPlayEligibilityRuntimeService` reports whether current assets can cover a card cost. It does not choose or reserve a generic-color payment.
- `PlayerManaRuntimeController` is the only owner of generic-color allocation, reservation, consumption, release, and asset save data.
- `CardResolutionQueueRuntimeService` stores an external asset authorization receipt only. It owns no asset balance or payment formula.

## Recovery

For each player and color:

```text
asset recovery per second = owned commodity GDP/min of that color / 100
```

- Recovery uses milliasset fixed-point accumulation so fractional time and GDP are not lost.
- Each color is capped at 100 assets.
- Assets do not decay naturally.
- Sale receipts are observed before recovery for the same world tick.
- Warehouse rent is a cash transfer and never creates a second GDP or asset-recovery event.

## Card Commitment

1. Eligibility reads a private availability snapshot and returns a stable reason code.
2. Queue produces a pure submission plan without mutating assets.
3. PlayerMana plans fixed-color payment first, then generic payment.
4. Generic payment uses an explicit valid allocation when supplied; otherwise it uses highest available balance with stable color-order tie-break.
5. Queue commit requires an external authorization receipt and stores only the reservation ID and sanitized debit summary.
6. A resolved effect consumes the reservation exactly once.
7. Failed, countered, skipped, or rejected execution releases the reservation exactly once.
8. Commodity cards with an empty asset cost remain free to acquire and play.

## v0.6 Window

- Total: 8 seconds.
- Organize: first 6 seconds.
- Lock: final 2 seconds.
- Standard maximum: 3 cards per player per window.
- Ordering: rotating seat priority, then the player's locked group order.
- v0.5 industry-capacity reservations, priority bids, cash escrow, and public monster-wager-pool receipts are retired and have no runtime owner.

## Save And Privacy

- Save data contains fixed-point pools, recovery remainders, live reservations, terminal receipts, state version, and ruleset ID.
- Terminal receipts make consume/release idempotent across replay and save/load.
- All snapshots, requests, receipts, manifests, and reports are pure data.
- Public output must not expose asset balances, reservation details, card owner, hidden target, private discard, or AI private plan.
