# Alpha 0.4-C card-market allocator ownership

Status: frozen and implemented on the Alpha 0.4-C task branch.

Source head: `12691a8bc7ad2c5a9f4c175c95a8c214ea346a74`

Runtime ruleset: `v0.6`. Save envelope: `v3`. Save section count: `19`.

The machine-readable authority is
[`alpha04c_card_market_allocator_ownership.json`](alpha04c_card_market_allocator_ownership.json).

| Identity | Sole generator | Persistence | Restore rule |
| --- | --- | --- | --- |
| Market quote | `CardMarketPricingRuntimeController` | `card_inventory.district_purchase.district_purchase_runtime.next_quote_sequence` | Restore the exact positive next sequence before allocation. Missing v2 cursor fails closed with `allocator_cursor_missing_requires_backup`. |
| Normal-card listing | `RegionSupplyRuntimeController` | `region_supply.refill_sequence` plus slot revisions | Restore the allocator and rack lineage together before refill. |
| District-purchase transaction | `DistrictSupplyActionPort` | Deterministic `district-purchase:<quote_id>`; materialized journals remain saved | Derive from the authoritative restored quote ID. There is no second transaction cursor. |

Expired quote bodies may be omitted because they are no longer live gameplay
state. The consumed quote identity space may not be omitted: otherwise restore
could allocate an ID used before the Save. Card-inventory v3 therefore persists
the allocator high-water mark independently of active quote payloads.

Focused fork tests prove identical next quote, listing, and transaction IDs
after restore, with zero reuse of an omitted expired quote ID. This changes no
price, expiry rule, listing rule, RNG draw point, Queue behavior, or gameplay
value.
