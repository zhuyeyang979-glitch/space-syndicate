# V0.7.2 To V0.7.3 Amendment

```text
AMENDMENT_DOCUMENT_ID=space_syndicate.v073.amendment_from_v072
FROM_RULESET_ID=v0.7.2
TO_RULESET_ID=v0.7.3
STATUS=approved_and_frozen
STRUCTURAL_AMENDMENT_COUNT=5
```

This amendment records the user's final facility-contention decision. It does
not rewrite V0.7.2. The V0.7.2 constitution, Markdown companion, balance
defaults, amendment, and precedence record remain byte-identical historical
authority.

```text
USER_REJECTS_RESOLUTION_ORDER_AUCTION=true
USER_REJECTS_INITIATIVE_CASH_BIDDING=true
USER_APPROVES_FIXED_ROUND_ROBIN_RESOLUTION=true
USER_APPROVES_PREBOUND_FACILITY_CONTENTION=true
USER_APPROVES_FACILITY_BUILD_FIZZLE_ON_SLOT_CONTENTION=true
```

## V073-C1: Auction Rejected

V0.7.3 closes resolution order against initiative auctions and cash bidding.
There is no auction Core or Owner, bid intent, reservation, Receipt, Save
field, UI surface, or AI bid policy. Historical proposals have no runtime
authority.

Target rule: `v073.resolution.auction_rejected`

## V073-C2: Fixed Hidden Round Robin

At batch lock, the authoritative `frozen_hidden_lead_order` becomes the one
`frozen_batch_turn_order`. The global queue visits local action indices 0
through 4 and, within each layer, visits players in that frozen order. Cash
and all gameplay resources have zero order-modifier authority.

Target rule: `v073.resolution.fixed_hidden_round_robin`

## V073-C3: Unique Slots And Prebound Modes

Facility slot identity is the closed tuple `region_id + facility_type +
industry_id`. Every submitted facility card binds its exact slot and selects
one mode: `BUILD_NEW`, `UPGRADE_OWN`, or `REPAIR_OWN`. Mode and target are
immutable after lock; inapplicable fields use explicit closed `none` values.

Target rule: `v073.facility.prebound_unique_slot_modes`

## V073-C4: Revalidation Without Conversion

The authoritative Region Infrastructure Owner revalidates the locked slot,
facility, generation, owner, rank, damage, and mode. UI and stale projections
cannot decide final legality. BUILD does not become UPGRADE or REPAIR, and no
mode may retarget during resolution.

Target rule: `v073.facility.authoritative_revalidation_no_conversion`

## V073-C5: Contention Fizzle

When an earlier action occupies a slot targeted by a later BUILD, the later
action uses `FIZZLE_FULL_ASSET_REFUND`. Its reservation is released, its card
enters discard, and its action slot is not returned. Starter cards follow the
same rule with a zero-value asset release. Public history explains the cause
without identifying either owner. Save/Restore preserves order, target, mode,
cursor, and exact-once Fizzle effects.

Target rule: `v073.facility.contention_fizzle_privacy_and_persistence`

## Inherited Sample Values

Profile `V073_STARTER_FREE_FIXED_ORDER_CONTENTION` retains the V0.7.2 sample
values:

- Initial assets per color: 0
- Starter asset cost: 0
- Standard L1 asset cost: 1
- Normal/commodity ratio: 6000/4000 basis points
- Intervention cap: 1200 basis points
- Asset refresh cap: 3 per color per batch
- Hand maintenance timeout: 8 seconds
- Lead tenure/color cycle: 1/6 completed batches
- Track scroll/local visible slots: 5 seconds/5 cards

It adds fixed hidden round robin, required facility mode, and contention
Fizzle as structural settings. `INITIATIVE_BID_MODE=retired` and
`INITIATIVE_BID_MAX_CASH=not_applicable`; neither is a runtime auction
parameter.

## Migration And Runtime Boundary

V0.7.2 detached Saves cannot silently resume as V0.7.3. V0.6 Saves also fail
closed and retain their backup requirement. An explicit test-only offline
migration is the only allowed conversion path.

```text
V07_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0
V071_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0
V072_HISTORICAL_CONSTITUTION_CONTENT_CHANGE_COUNT=0
V072_SAVE_TO_V073_DIRECT_RESUME=false
V06_SAVE_TO_V073_DIRECT_RESUME=false
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
HIGHEST_TARGET_RULESET=V0.7.3
FULL_V0_7_3_RUNTIME_CUTOVER=false
V073_PRODUCTION_CONNECTION_COUNT=0
V073_V06_MUTATION_COUNT=0
V073_DUAL_WRITE_COUNT=0
HUMAN_FUN_PROVEN=false
HUMAN_TEST_REQUIRED=true
```

Fresh 3-, 4-, 6-, and 8-player deterministic simulation remains required.
The suggested facility BUILD Fizzle range is 3% to 15%, but an auction may not
be introduced to force that range. Human play must determine whether the
contention frequency, local ordering, mode choice, and anonymous feedback are
understandable and fun.
