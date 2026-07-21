# Conditional Order and Supply Ownership (v0.6)

## Status

The former target-player consent feature is retired in v0.6. There is no
standalone runtime controller, world bridge, overlay panel, forced decision,
or save section for that legacy flow.

## Current ownership

Conditional orders and supply effects are automatic. Their legality and result
remain with the existing typed owners:

- card submission and resolution own commitment and exactly-once lifecycle;
- commodity flow owns supply, demand, inventory, receipts, and waste;
- route network owns route legality, capacity, and travel facts;
- product market owns prices and market state;
- region infrastructure owns installed facilities and district integrity.

No effect may ask another player to sign, decline, or time out an order. A
failed automatic check produces the ordinary resolved failure receipt, with no
new queue entry, private responder, or persisted pending decision.

## Visibility and persistence

Public presentation may show an automatic order's legal public outcome. It
must not disclose a hidden owner, private economic facts, AI reasoning, or a
fictional responder. Save/load persists only the existing owner state and card
resolution lineage; it creates no separate order-consent payload.

## Migration rule

New cards that alter supply or demand must use existing field-driven automatic
economy operations. They must not reintroduce a target-player approval flow or
parallel order owner.
