# CardFlow RegionSupply Purchase Contract v0.6

## Purpose

Regional rack purchases use the existing CardFlow transaction owner. This
contract replaces the temporary coordinator-managed sequence without creating a
second rack, inventory, cash, quote, or transaction owner.

## Owners

- `RegionSupplyRuntimeController` remains the only owner of public rack slots,
  deterministic bags, RNG state, unique-card claims, and slot refill lifecycle.
- `CommodityCardInventoryRuntimeController` remains the terminal operation and
  save/checkpoint owner for CardFlow.
- `CardFlowTransactionServiceV06` remains the only purchase transaction policy
  that reserves player state, validates quotes, receives/merges cards, and
  debits cash.
- The injected RegionSupply port is non-owning. CardFlow reads only
  `public_rack_snapshot()` and calls the owner's
  `prepare/commit/rollback/finalize_slot_refill()` lifecycle.

CardFlow never stores rack slots, bag order, RNG state, or future listings.

## Production API

The inventory controller exposes:

```gdscript
set_region_supply_source_port(source_port)

purchase_region_supply_card(
    actor_id,
    region_id,
    slot_index,
    source_item_id,
    card_id,
    expected_player_revision,
    expected_supply_revision,
    transaction_id,
    quote_request
)
```

`quote_request` must bind:

- `quote_id`
- `quote_fingerprint`
- `player_index`
- `district_index`
- `source_region_id`
- `slot_index`
- `source_item_id`
- `card_id`
- `supply_revision`

The quote authority remains responsible for the locked final cash price and
expiry. CardFlow additionally binds the quote to the current public RegionSupply
slot before any owner commit.

## Atomic Order

1. Gate transaction replay/collision.
2. Reserve the authoritative player revision.
3. Read and bind the current public rack listing.
4. Authorize the locked quote.
5. Plan the existing hand receive/automatic merge policy and cash debit.
6. Prepare the player mutation.
7. Prepare RegionSupply selected-slot refill.
8. Commit RegionSupply selected-slot refill.
9. Commit player state.
10. If player commit fails, roll RegionSupply back exactly.
11. If both commits succeed, finalize RegionSupply.

Only the selected slot is refilled. Other slots and future bag order are never
read or copied by CardFlow.

## Failure and Recovery

- Wrong actor, player revision, region, slot, item, card, supply revision,
  quote, fingerprint, or transaction binding fails with zero committed effects.
- A successful RegionSupply rollback after player-state failure returns a
  compensated failure; no cash or card is committed.
- A failed rollback returns `region_supply_compensation_failed`,
  `compensation_failed=true`, and `recovery_required=true`. It never reports a
  fabricated rollback.
- A finalize failure preserves `committed=true`, blocks checkpoints with
  `region_supply_purchase_finalization_pending`, and records the source receipt
  in the existing terminal operation.
- Replaying the same transaction retries only RegionSupply finalization. It does
  not repeat the cash debit, card receive/merge, or slot refill.
- Save/load restores the terminal operation and player state. RegionSupply
  restores its own pending lifecycle through its existing save owner; replay
  resumes finalization.

## Privacy

The private operation result may include the current player's resulting state,
the purchased `card_id`, and developer-only lifecycle receipts.

The public receipt contains only:

- an anonymous purchase event code;
- the public source region;
- the public slot index.

It contains no buyer identity, purchased card, locked price, cash balance,
hand, quote fingerprint, bag order, RNG state, or future listing.

## Acceptance Evidence

- `tests/card_flow_region_supply_purchase_v06_test.gd`
  - success and selected-slot-only refill;
  - binding failures and transaction collision;
  - player commit failure with exact rollback;
  - rollback failure recovery state;
  - finalize failure and idempotent retry;
  - pending finalization save/load recovery;
  - public receipt privacy.
- `scenes/tools/CardFlowRegionSupplyPurchaseV06Bench.tscn`
  - production coordinator, production inventory/state adapter, real
    RegionSupply owner, real quote authority, and real catalog.

The coordinator integration step should bind the composed RegionSupply owner to
the inventory controller and forward this API. It should then delete the
temporary coordinator-managed purchase transaction instead of retaining both
paths.
