# Card Inventory v4 pre-edit characterization

STATUS=PRE_EDIT_CHARACTERIZATION_COMPLETE

The characterization runs the real V0.6 `main.tscn` composition with the real
`CardInventorySaveOwner` and all three child owners. The state includes a real
four-seat session and a pending-discard District Purchase window. It calls only
the in-memory Save and runtime-checkpoint capture methods; it does not invoke
the Registry writer or a fixed Save slot.

## Strict closed-data defects

| Payload | Leaves | Non-closed | Types |
| --- | ---: | ---: | --- |
| Card Inventory persistent Save v3 | 2137 | 456 | 456 float |
| Card Inventory runtime checkpoint v1 | 2343 | 503 | 502 float, 1 int key |
| Commodity persistent child | 679 | 132 | 132 float |
| Commodity runtime child | 686 | 132 | 132 float |
| Product Market persistent child | 1421 | 323 | 323 float |
| Product Market runtime child | 1570 | 369 | 369 float |
| District Purchase persistent child | 37 | 1 | 1 float |
| District Purchase runtime child | 82 | 2 | 1 float, 1 int key |

The Inspector emits every leaf as a redacted path, Variant type, source child,
source capture method, finite/safe-integer flags, structural fingerprint, and
reason code. Dynamic product, card, transaction, and player identifiers remain
hashed. No Object, Node, Resource, Callable, or RID entered any captured
payload.

The required defects are present:

- `$.children.district_purchase.windows_by_player.<non_string_key:int>`
- `$.product_market.product_market.<redacted>.growth_multiplier`
- `$.product_market.market_timer`

The nontrivial pending-discard profile also exposes
`district_purchase.pending_payload.opened_at` as a raw float. Static consumer
audit found no reader of this field. It is presentation-only metadata, not
authoritative purchase state; that classification is passed explicitly to the
Inspector rather than inferred from its Variant type.

## V7 preservation

V7 remains `7/19` with `card_inventory` at owner index 7 and reason
`owner_checkpoint_not_pure_data`. The quota ledger hash remains
`607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826` and
failure phase 0024 remains
`eba66bdf8edc55071b862a6b1c9d1ab8073d130335408bcf76be9c373538b778`.
No V8 authorization, full Owner Audit, Process A, Formal run, or Save-file write
was performed.
