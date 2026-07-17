# Public Match Receipt Contract v0.6

This document defines a pure-data safety foundation. It is not connected to production owners, save data, AI behavior, or final settlement yet.

## Envelope

`PublicMatchReceiptEnvelopePolicyV06` accepts exactly these fields:

- `schema_version`
- `receipt_id`
- `sequence`
- `world_effective_us`
- `turn_marker`
- `event_kind`
- `public_outcome_code`
- `typed_deltas`
- `source_receipt_ids`

Receipt IDs use the `pub.` namespace. The policy returns a canonical detached copy, sorts source receipt IDs, rejects duplicate or self-referential sources, and accepts only fixed event and outcome enums.

Typed deltas are integer aggregates only:

- GDP per minute
- controlled regions
- route income
- weather value
- monster damage avoided
- military spend
- inference reward

There is no free-form narrative field and no exact cash field.

## Privacy Boundary

The policy recursively rejects player, seat, actor, profile, card identity, target, bid, weight, score, reason, candidate, plan, learning, owner, hand, discard, cash, private fingerprint, runtime object, and unknown fields.

The current contract cannot attribute an observation to a particular AI. It only supports match-level public evidence.

## Observable Tendencies

`ObservableStrategyTelemetryService` reduces verified receipts into six fixed anonymous totals:

1. `city_growth`（由 `public_facility_committed` 等公开设施结果驱动）
2. `finance_speculation`
3. `direct_interaction`
4. `monster_pressure`
5. `contract_route`
6. `intelligence_supply`

The reducer is exact-once by immutable `receipt_id` and deterministic by `sequence`. A conflicting ID or sequence fails closed. Capacity overflow rejects the new receipt, retains all accepted history, and marks `evidence_incomplete`.

## Current Limit

Both classes extend `RefCounted`. They have no Node, world bridge, persistence, network, or production composition API. A later owner-approved integration must supply sanitized public receipts; this block does not make AI personalities publicly visible and does not prove settlement evidence.
