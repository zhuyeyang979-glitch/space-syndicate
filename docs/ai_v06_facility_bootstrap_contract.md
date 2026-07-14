# AI v0.6 Facility Bootstrap Contract

Status: B5a focused consumer contract; production Coordinator wiring is deferred to B5b/A after A6 freezes its APIs.

## Purpose and ownership

`AiRuntimeController` may decide that an AI seat needs its first rank-I facility. It never owns or mutates cash, cards, market listings, facilities, economic sources, transaction journals, or queues.

The only mutation path is:

```text
AiRuntimeController
  -> AiV06EconomyActionPort
  -> production Coordinator adapter (B5b/A)
  -> canonical Inventory/CardFlow owners
  -> RegionInfrastructure / CommodityFlow owners
```

The port is a pure-data forwarding boundary. Holding a delegate reference is not business-state ownership. Missing capability, malformed response, stale revision, or non-pure data fails closed.

## Required port surface

```gdscript
market_snapshot(actor_id: String) -> Dictionary

purchase_rank_i_facility(
    actor_id: String,
    item_id: String,
    transaction_id: String,
    expected_market_revision: int,
    expected_player_revision: int,
    expected_source_revision: int
) -> Dictionary

player_snapshot(actor_id: String) -> Dictionary

play_runtime_card(request: Dictionary) -> Dictionary

economic_source_snapshot(actor_id: String) -> Dictionary
```

Every response must be recursively pure data and contain:

- `available: bool`;
- `revision: int >= 0`;
- non-empty `reason_code: String`.

The port rejects Objects, Callables, missing fields, negative revisions, empty reasons, and unavailable methods.

## Normalized snapshots

### Market

```gdscript
{
    "available": true,
    "revision": 7,
    "reason_code": "...",
    "listing": {
        "canonical": true,
        "bootstrap_eligible": true,
        "item_id": "...",
        "card_id": "facility....rank_1",
        "category_id": "facility",
        "rank": 1,
        "effect_kind": "build_upgrade_or_repair_facility",
        "purchase_cash": 4,
        "target_region_id": "region.alpha",
        "legal_region_ids": ["region.alpha"]
    }
}
```

`purchase_cash` is read only for eligibility. AI must not echo price or card payload to the purchase owner.

### Private player snapshot

```gdscript
{
    "available": true,
    "revision": 12,
    "reason_code": "...",
    "cash": 20,
    "cards": [{
        "slot_index": 0,
        "runtime_instance_id": "...",
        "card_id": "facility....rank_1",
        "category_id": "facility",
        "rank": 1,
        "effect_kind": "build_upgrade_or_repair_facility",
        "bootstrap_eligible": true
    }]
}
```

This snapshot is AI-private. It is never returned by the controller's public-safe snapshot.

### Economic source

```gdscript
{
    "available": true,
    "revision": 3,
    "reason_code": "...",
    "has_source": false,
    "bootstrap_finalized": false,
    "target_region_id": "",
    "legal_region_ids": ["region.alpha"]
}
```

`bootstrap_finalized` is authoritative and remains true after the one-time bootstrap transaction, even if the built facility is later damaged or destroyed. Rebuilding belongs to a future policy, not another bootstrap purchase.

## Candidate policy

A candidate exists only when all of these hold:

1. the controller, world bridge, Monster starter owner, and economy port are available;
2. the seat is a live AI seat;
3. `MonsterRuntimeController.monster_starter_state_snapshot_v06(actor_id)` is authoritative and reports `summoned` with a positive UID;
4. economic source reports neither `has_source` nor `bootstrap_finalized`;
5. an authoritative player snapshot is available;
6. the canonical listing or source snapshot supplies a production-authoritative `target_region_id` or ordered `legal_region_ids` candidate;
7. the hand already contains a normalized bootstrap-eligible rank-I facility, or the market exposes a canonical one;
8. when purchase is required, authoritative cash covers `purchase_cash`;
9. normal mode respects the seat action cooldown. `force=true` bypasses only this scheduling gate.

The internal candidate is field-driven and may contain `policy_kind`, `action_kind`, actor, item, target region, and expected revisions. Target selection prefers the canonical listing, then the source snapshot, and preserves the production-provided order. The AI never guesses an industry from a card name, scans legacy `card_choices`, or selects the lexicographically first map region. If no authoritative target candidate exists, it fails before purchase. The candidate never contains raw owner snapshots, a card payload, an owner receipt, or a caller-selected price. Internal candidate/scoring data is not public API.

## Transaction flow

1. Read source and player revisions.
2. Prefer an already-owned bootstrap-eligible rank-I facility card. This prevents a prior successful purchase followed by a failed play from becoming a second charge.
3. If absent, read the canonical market listing, require an authoritative legal target, and submit a deterministic purchase transaction bound to actor, item, and all expected revisions.
4. After purchase, discard the old player snapshot and read the authoritative player snapshot again.
5. Locate the purchased card by canonical card ID and require its stable `runtime_instance_id` and slot.
6. Submit `play_runtime_card()` with only actor, slot, runtime instance, region, transaction ID, and expected player/source revisions.
7. Count success only when the shared owner returns both `committed=true` and terminal finalization.
8. Read `economic_source_snapshot()` on later ticks. A finalized marker prevents repeat bootstrap; no local AI journal is created.

Purchase and play transaction IDs are deterministic hashes of their immutable bindings. Retrying an unchanged binding reuses the same transaction ID; changed authoritative revisions require a newly evaluated candidate.

## Scheduling

`_update_ai_decisions()` calls `execute_v06_facility_bootstrap_cycle(false)` at the existing card-decision timer. If one facility finalizes, the legacy card decision pass is skipped for that timer event. The bootstrap loop stops after the first successful seat, allowing another AI seat to proceed on a later timer event.

Focused/vertical-slice code must call the same `execute_v06_facility_bootstrap_cycle(true)` action. It must not restore `_auto_expand_rival_syndicates`, write `district.city`, or construct a direct facility mutation.

## Public and private data

`execute_v06_facility_bootstrap_cycle()` and `ai_v06_facility_bootstrap_public_snapshot()` contain only port availability, coarse state/reason, and aggregate action counts. Exact candidate rejection reasons remain internal so an opponent cannot infer whether an AI lacks cash, a card, a starter, or a source. The public-safe surfaces exclude:

- actor IDs and hidden ownership;
- transaction IDs;
- cash, hand, slot, or card-instance data;
- AI scores, routes, plans, pressure, and training metadata;
- raw owner receipts or errors.

The focused test independently scans this snapshot for forbidden private keys.

## B5b production adapter requirements

The future adapter must normalize, not duplicate, these production owners:

- market: Coordinator canonical rank-I facility market facade;
- purchase: existing Inventory/CardFlow market transaction;
- player: authoritative production player snapshot;
- play: existing `play_v06_runtime_card` facade;
- source: A6's authoritative facility/CommodityFlow source projection, including persistent `bootstrap_finalized` lineage and legal target candidates for an already-owned bootstrap card.

The listing/source adapter must derive `target_region_id` or ordered `legal_region_ids` from production region commodity/industry facts. In particular, it must exclude targets that would fail `region_production_product_industry_mismatch`. If A6 cannot yet expose those candidates, B5b must leave the action fail-closed; the AI controller will not fall back to arbitrary map order.

The adapter must revalidate expected market, player, and source revisions immediately before delegation. It may not trust an AI-supplied price, card body, effect kind, owner receipt, or finalized flag.

## B5b production wiring status

The Coordinator now implements the five delegate capabilities and injects one `AiV06EconomyActionPort` into `AiRuntimeController`. The delegate owns no player, card, market, facility, flow, or bootstrap state. It derives:

- player/card/cash state from `CommodityCardInventoryRuntimeController` and its production player-state adapter;
- market revisions and purchase exact-once results from the existing CardFlow journal;
- facility ownership from `RegionInfrastructureRuntimeController`;
- production installations from `CommodityFlowRuntimeController`;
- `bootstrap_finalized` and lineage from finalized `play_card` records in the existing Inventory/CardFlow transaction journal.

Legal target candidates require an authoritative production product whose industry matches the facility card, an allowed region lifecycle state, and an unoccupied unique facility slot. An explicit demand endpoint or remote route is not a construction prerequisite. CommodityFlow remains the sole owner of local absorption, local GDP, remote-route preference, warehouse storage, and backpressure. Current authoritative trade kinds include `local_production_baseline`, `local_market_baseline`, and remote-route kinds; the AI adapter neither computes nor fabricates them.

The vertical-slice oracle accepts any authoritative positive-income trade kind. It records the actual `trade_kind`, local sold units, backpressured milliunits, and warehouse stored milliunits, but does not require all production capacity to sell.
