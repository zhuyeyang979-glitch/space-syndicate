# Alpha 0.4-C allocator cursor ownership

Status: ownership frozen; implementation complete

Source head: `12691a8bc7ad2c5a9f4c175c95a8c214ea346a74`

Runtime ruleset: `v0.6`

The machine-readable authority for this decision is
[`alpha04c_allocator_cursor_ownership.json`](alpha04c_allocator_cursor_ownership.json).
This ledger records which runtime owns each identity cursor, which identities are
derived without a cursor, and how restore must preserve the consumed identity
space. It does not add a twentieth Save section or change the v3 envelope.

## Hard invariants

- `EXPIRED_QUOTE_PAYLOAD_MAY_BE_OMITTED=true`.
- `ALLOCATOR_CURSOR_MUST_BE_PERSISTED=true`.
- A missing cursor is never silently defaulted.
- Restore may not reuse an identity consumed before the Save, even when the
  corresponding expired object is intentionally omitted.
- Each mutable cursor has exactly one authoritative runtime owner.
- Purchase transaction and purchased-card instance IDs are deterministic
  derivations, not independent allocators.

## Cursor ownership

| Cursor | Sole authority | Runtime field | Current Save field | Status | Minimum |
| --- | --- | --- | --- | --- | ---: |
| Market quote sequence | `CardMarketPricingRuntimeController` | `_next_quote_sequence` | `card_inventory.district_purchase.district_purchase_runtime.next_quote_sequence` in v3 | persisted | 1 |
| Region listing/refill sequence | `RegionSupplyRuntimeController` | `_refill_sequence` | `region_supply.refill_sequence` | persisted | 0 |
| Resolution execution sequence | `CardResolutionExecutionRuntimeService` | `_transaction_sequence` | `card_resolution_execution.transaction_sequence` | persisted | 0 |
| Player-state reservation sequence | `CardPlayerStateProductionAdapterV06` | `_next_reservation_sequence` | `card_inventory.commodity_card_inventory.state_port.next_reservation_sequence` | persisted | 1 |

`RegionSupplyRuntimeController` also owns
`region_supply.slot_revisions_by_region`. Listing `item_id` values use the
refill sequence, while supply revisions use the per-slot revision. Current
racks and pending/terminal transaction lineage remain in the same
`region_supply` section. No other controller may allocate either identity.

## Quote cursor repair

`CardMarketPricingRuntimeController` generates IDs in the form
`market-quote-<world_us>-<sequence>`. Its runtime checkpoint already includes
`_next_quote_sequence`, but the formal `card_inventory` v2 payload only stores
quotes still referenced by district-purchase sessions. Ordinary expired quote
payloads may therefore be omitted even when one of them consumed the greatest
sequence seen before the Save.

The target repair keeps the same 19 Save sections and places the cursor at:

```text
card_inventory.district_purchase.district_purchase_runtime.next_quote_sequence
```

The intended version boundary is:

| Contract | Current | Target |
| --- | ---: | ---: |
| `card_inventory` section | 2 | 3 |
| `district_purchase_runtime` payload | 2 | 3 |
| top-level Save envelope | 3 | 3 |

The target value must be a pure-data integer of at least `1` and must be
greater than every market-quote sequence retained in a session or referenced
by a persisted journal. Apply restores it before any new quote allocation.
Repeated apply must not advance it, and rollback restores the exact prior
cursor.

### Fail-closed v2 policy

A v2 `card_inventory` payload has no authoritative quote cursor. The value
cannot be reconstructed exactly from retained quotes or journals because a
higher ordinary expired quote may have been omitted. Consequently, v2 may not
default the cursor to `1` and may not infer it from the greatest retained ID.
When exact continuation is required, restore rejects the payload without
mutation using:

```text
allocator_cursor_missing_requires_backup
```

This is a `requires_backup` compatibility boundary, not a migration to an
approximate cursor.

## Deterministic identities

District purchases do not own a transaction counter. `DistrictSupplyActionPort`
derives the transaction ID exactly as:

```text
district-purchase:<quote_id>
```

`CardFlowTransactionServiceV06` then derives a purchased normal-card instance
from the authoritative listing item ID and that transaction ID:

```text
region-supply:<listing_item_id>:<district_purchase_transaction_id>
```

Existing card instances remain authoritative in the `session` owner's player
slots. The `card_inventory` and `region_supply` journals retain transaction
lineage, but neither creates a second purchase-transaction or card-instance
allocator. Preserving the quote cursor and Region Supply cursor is therefore
what preserves the future transaction and card-instance identity chain.

## Restore validation

The quote cursor repair must reject, with zero mutation:

- a missing cursor in the target version;
- a non-integer or negative cursor;
- a value below `1`;
- a value that is not greater than a retained quote sequence;
- a value that is not greater than a quote sequence referenced by a journal;
- a payload whose section or child version does not match the strict contract.

The already-persisted owners retain their existing strict checks:

- Region Supply restores `refill_sequence`, slot revisions, racks, bags, and
  transaction lineage together.
- Resolution execution rejects a sequence that precedes a retained execution
  record.
- Player-state reservations require a positive next sequence and repeated apply
  must not allocate or advance it.

## Fork acceptance

The decisive quote test retains a lower-sequence pending quote, allocates a
higher ordinary quote, lets the higher quote expire, and omits that expired
payload from the Save. Restored and uninterrupted forks must then produce:

1. the same next quote ID and quote fingerprint;
2. the same next Region Supply listing ID and supply revision;
3. the same `district-purchase:<quote_id>` transaction ID;
4. the same purchased-card `runtime_instance_id`;
5. the same next execution and player-state reservation IDs;
6. zero reused expired IDs;
7. exact cursor parity after rollback and repeated apply.

These checks prove identity continuation. Retaining an expired quote body is
not required; retaining the allocator's consumed namespace is.
