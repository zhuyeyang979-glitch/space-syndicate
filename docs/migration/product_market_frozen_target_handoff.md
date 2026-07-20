# Product-Market Frozen Target Handoff

## Boundary

Card effects that mutate ProductMarket now consume a detached target context
derived from `CardResolutionStableTargetEnvelope`. Delayed execution no longer
re-reads the live table product or district focus.

Covered handlers:

- `product_speculation`
- `product_futures`
- `product_contract_boon`
- `market_stabilize`
- `product_growth_boon`
- the market portion of `news_event`

## Contract

`ProductMarketFrozenTargetContext` is a pure-data, transient value. It carries
the public `product_id`, stable `region_id`, catalog bindings, current resolved
district index, and (when required) the warehouse region. It contains no cash,
hand, owner answer, AI plan, Node, Object, Callable, or UI selection reference.
Its fingerprint is checked before the ProductMarket owner mutates state.

New envelope-backed entries use stable IDs and tolerate live district reorder.
Legacy queue entries may use only their already-captured numeric product/region
mirrors; a missing product or region fails closed. Neither path samples
`TableSelectionState` during card execution.

## Warehouse behavior

Warehouse futures resolve the stable region again at execution and then
revalidate that the city is active and owned by the acting player. A failed
authorization does not charge cash, append a warehouse position, or publish a
warehouse clue. New positions retain `warehouse_region_id` alongside the
existing numeric compatibility mirror; old positions are upgraded when the
stable region can be resolved.

ProductMarket's direct non-card API still supports its existing optional target
fallback for callers that intentionally operate on current presentation focus.
The card-effect bridge always supplies a non-empty frozen context, so that
fallback is outside the delayed card execution path.

## Non-goals

This boundary does not change AI planning, military or monster targets, card
rules, selection ownership, save root/section shape, or queue cold restore. It
does not claim full delayed-resolution restore support. The unrelated legacy
warehouse-damage receipt field mismatch remains deferred to the settlement
contract owner.

## Evidence

- Focused gate: `res://tests/card_resolution_product_market_target_envelope_test.gd`
- Existing stable envelope gate remains the authority for first-intent capture
  and queue mirror validation.
- ProductMarket remains the sole market/futures state owner; the new context is
  not saved and is not an additional runtime owner.
