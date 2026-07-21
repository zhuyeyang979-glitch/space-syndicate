# District Supply Action Port Cutover

The district rack action chain is now scene owned by `DistrictSupplyActionPort` under the production `GameRuntimeCoordinator`.

The port coordinates, but does not own, the existing authoritative owners:

- `RegionSupplyRuntimeController`: rack contents, refill and revision.
- `CardMarketPricingRuntimeController`: five-second quote and authorization.
- `DistrictPurchaseRuntimeController`: window and pending private discard.
- `DistrictPurchaseSettlementRuntimeService` and `CardInventoryRuntimeService`: cash/inventory settlement.
- `WorldSessionState`: committed player state.
- `TableCardSupplyPresentationState`: open rack and preview selection.

Human double-click, drawer preview/quote/purchase, private discard responses, and
AI purchase now enter the same typed port. Human intents cannot mark themselves
as AI or anonymous: a human purchase must consume the already locked quote.
The trusted AI entry verifies the seat, session and forced-decision state and
uses the same bounded exact-once journal. Its implicit request identity is
bound to the current authoritative simulation step, session and AI seat;
replaying the same decision cannot debit cash or refill the rack twice, while
reusing the identity for different purchase facts is rejected as a collision.

The port resolves the numeric district through the authoritative
`WorldSessionState.region_id`, uses the current rack listing's `price_cash`,
and accepts only cards that are actually present in the unified random rack.
There is no separate facility side market. A successful purchase atomically
settles inventory/cash, commits exactly one slot refill, and clears only the
matching private discard decision.

The typed receipt is viewer-private. Its public projection omits actor, card,
quote, price, hand pressure and detailed failure reason. Finished sessions
cannot create new quotes or purchases.

Removed from `scripts/main.gd`: rack open/close, preview, quote selection, purchase window creation, purchase settlement orchestration, claim, discard confirm/cancel, and drawer signal handling. Main no longer connects map double-click or drawer actions.

Focused evidence:

- `district_supply_action_port_cutover_test.gd`
- `DistrictSupplyActionPortBench.tscn`
- `card_flow_region_supply_purchase_v06_test.gd`
- `region_supply_full_randomization_v06_test.gd`

Several broad legacy fixtures still invoke the physically removed Main
methods. They must be migrated to the typed port; no compatibility methods may
be restored.
