# Public Product Selection Catalog Audit

## Scope

This boundary publishes the stable public commodity type order needed by later typed selection and card-target envelopes. It does not claim, price, trade, route, execute cards, mutate the market, or change the sushi track.

## Authority

- `ProductMarketRuntimeController.PRODUCT_CATALOG` is the only authoritative public order and contains 46 opaque product IDs.
- `ProductIndustryCatalogResource` contains metadata but has a different order and cannot author public indices.
- `commodity_id` is a domain alias for the same product ID.
- `commodity_card_id` identifies a commodity card tier.
- `commodity_slot_id` identifies one sushi-track slot instance.
- Sushi child order and `slot_index` are presentation order, never product-catalog identity.

`ProductMarketRuntimeController.public_product_selection_catalog_source()` reads only the immutable catalog and public profile category. It never calls `ensure_catalog()` and never reads or changes prices, supply, demand, futures, routes, claims, or market revision.

## Session And Source Envelope

Every snapshot carries `session_id`, `session_revision`, `source_owner_id`, and `source_ready`. The exact product `source_owner_id` is `ProductMarketRuntimeController.PRODUCT_CATALOG`. Active identity comes from the explicitly composed, read-only `GameSessionRuntimeController`; pre-session identity is deterministically empty with revision `0` and `source_ready=false`.

Changing sessions while retaining the same authoritative 46-item order changes session identity but not ordering revision or fingerprint. Region and product snapshots may be combined only when both session fields match.

## Entry Contract

Each entry contains exactly:

- `product_id`
- `public_index`
- `public_name`
- `selectable`
- `disabled_reason`
- `public_category`

`product_id` remains the opaque authority even though its current value equals the Chinese display name. Display text is never parsed back into identity.

## Revisions

`ordering_revision` and `ordering_fingerprint` use only ordered rows of:

```text
product_id, public_index, selectable
```

They use distinct domain/version tags. `data_revision` uses only the exact entry allowlist. Price, supply, demand, market cycle, futures, weather, sushi-slot state, selection, timestamp, and RNG are excluded.

Session identity and source metadata are also excluded from ordering and data revisions.

## Fail-Closed Rules

Pre-session output is a deterministic unavailable empty snapshot. Active-session composition fails closed for a missing or malformed session identity, missing owner, malformed or non-pure source, an entry count other than 46, blank or duplicate IDs, malformed profile/category metadata, noncontiguous indices, unexpected fields, invalid primitive metadata, or invalid hashes. The optional public category may be absent, but an included value must be a string primitive. Integer and Boolean metadata require exact primitive types.

No source may derive product order from dictionaries, resource order, button text, sushi slots, card IDs, or UI children.

## Non-Effects

- Query-triggered commodity claims: `0`
- Commodity slot/product identity confusion: `0`
- ProductMarket mutation: `0`
- RNG delta: `0`
- Save-section delta: `0`
- Main fallback: `0`

Behavioral isolation covers two sushi slots sharing one test product ID, slot reorder and hover-equivalent changes, and slot entry/exit and claimability changes. Across all states the query still returns the same 46 authoritative products and unchanged ordering identity, with zero claim submission.
