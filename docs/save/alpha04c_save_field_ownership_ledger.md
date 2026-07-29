# Alpha 0.4-C v0.6 save-field ownership ledger

Status: frozen before production implementation  
Base: `5b8601bb417c24b611884f107314f3ac286aa9ff`  
Runtime ruleset: `v0.6`

The machine-readable authority is
[`alpha04c_save_field_ownership_ledger.json`](alpha04c_save_field_ownership_ledger.json).
This document records the decisions that prevent two restore owners from
mutating the same gameplay fact.

## Hard gates

| Gate | Frozen value |
| --- | ---: |
| Required sections | 19 |
| Duplicate authoritative fields | 0 |
| Unowned required fields | 0 |
| Facts with multiple mutable owners | 0 |
| Ruleset mutable save fields | 0 |

Every transactional owner exposes equivalent `to_save_data`,
`preflight_save_data`, `apply_save_data`, `capture_runtime_checkpoint`, and
`restore_runtime_checkpoint` operations. Capture and preflight are detached,
finite, exact-key and mutation-free. Apply is an exact replacement. A rollback
checkpoint contains the complete pre-operation owner state, including local
diagnostic counters when those counters are needed to prove exact rollback even
though they are not persisted in the player save.

## Section ownership

| Order | Section | Sole mutable authority | Saved authority | Restore role |
| ---: | --- | --- | --- | --- |
| 1 | `ruleset` | none; immutable runtime resources | profile/content/balance fingerprints only | Phase 0/1 attestation |
| 2 | `region_infrastructure` | `RegionInfrastructureRuntimeController` | regions, facilities, generations, tombstones, exact-once lineage | Phase 5 authoritative |
| 3 | `region_supply` | `RegionSupplyRuntimeController` | racks, deterministic bags/cursors, quotes and transaction lineage | Phase 5 authoritative |
| 4 | `commodity_flow` | `CommodityFlowRuntimeController` | installations, remainders, backlog, warehouse/waste, Sale Receipts | Phase 5 authoritative |
| 5 | `routes` | no independent topology; `RouteNetworkRuntimeController` owns derived cache | semantic/topology/rebuild attestation | Phase 6 rebuild |
| 6 | `player_mana` | `PlayerManaRuntimeController` | six-color pools, recovery remainders, reservations and journals | Phase 5 authoritative |
| 7 | `commodity_belt_visibility` | no second ACL; card inventory owns item ACL | item-ID set and ACL fingerprint | Phase 6 attestation |
| 8 | `card_inventory` | `CardInventorySaveOwner` transactionally coordinates existing non-World card owners | belt/market items, journals, terminal operations, pending discard, locks/CAS metadata | Phase 5 authoritative |
| 9 | `player_organization` | `PlayerOrganizationRuntimeController` | organization assets, bindings and journal | Phase 5 authoritative |
| 10 | `monsters` | `MonsterRuntimeController` | monsters, wagers, timers, card lifecycle and lineage | Phase 5 authoritative |
| 11 | `military` | `MilitaryRuntimeController` | units, next UID, cooldown/duration and bankruptcy journal | Phase 5 authoritative |
| 12 | `weather` | `WeatherRuntimeController` | event/forecast queue, generation cursor and history | Phase 5 authoritative |
| 13 | `card_resolution_queue` | `CardResolutionQueueRuntimeService` | current/next/active queue, sequences and stable target bindings | Phase 5 authoritative |
| 14 | `card_resolution_execution` | `CardResolutionExecutionRuntimeService` | active execution, continuation and exact-once settlement lineage | Phase 5 authoritative |
| 15 | `card_resolution_history` | `CardResolutionHistoryRuntimeService` | public resolved history and retained resolution IDs | Phase 5 authoritative |
| 16 | `ai` | `AiRuntimeController` | AI profile/memory, decision timers, enabled state and policy attestation | Phase 5 late authoritative |
| 17 | `bankruptcy_neutral_estate` | `BankruptcyNeutralEstateRuntimeController` | estate/rent journal and terminal transaction identity | Phase 5 late authoritative |
| 18 | `victory_control` | `VictoryControlRuntimeController` | qualification, audit, outcome and exact-once sequence | Phase 5 late authoritative |
| 19 | `session` | `SessionEnvelopeSaveOwner` coordinating existing session/world/RNG/private-tail owners | identity, roster, geometry, player slots/cash, clock, shared RNG, private annotations | Phase 4 foundation + Phase 7 tail |

## Duplicate-field rulings

1. Player `slots` and card instances stay authoritative in
   `WorldSessionState`, persisted only by `session`. `card_inventory` persists
   transaction metadata and commodity belt/market state (including the existing
   `ProductMarketRuntimeController` continuation), never another player slot
   array. This uses the existing section rather than inventing a twentieth one.
2. `ai_profile` and `ai_memory` are authoritative only in `ai`. The current
   World runtime may host those values for the actor port, but the new World
   save codec omits them and creates empty foundation placeholders before the
   AI owner applies.
3. Commodity belt items, including their `visible_actor_ids`, are authoritative
   in `card_inventory`. `commodity_belt_visibility` validates an item-ID set and
   ACL fingerprint and cannot apply a second ACL.
4. Region/facility topology is authoritative in `region_infrastructure`.
   `routes` saves no topology copy and rebuilds its cache after infrastructure
   and weather are restored.
5. A resolution ID is pending only in `card_resolution_queue`, active only by
   reference in execution, and completed only in history. Inventory holds only
   a consistency flag/reference, never a queue-entry copy.
6. Military owns unit `owner` and `region` foreign keys; player and region
   owners supply the referenced primary keys but do not store unit copies.
7. `victory_control` owns the outcome receipt. `session` stores terminal
   lifecycle plus an outcome fingerprint/reference, not a second mutable
   outcome.
8. `session` owns the sole shared gameplay RNG continuation. Region supply may
   persist an already-materialized deterministic bag cursor, never the shared
   RNG object or a competing global cursor.

## Privacy boundary

The authorized file contains state required for exact resume, including local
player and AI-private facts. UI and public receipts receive only an allowlist:
mission title, player count, world time, save time, ruleset and session state.
Raw envelopes, section payloads, fingerprints, opponent hands/cash, future bag
order, AI memory and private annotations are never projected to player-facing
surfaces.

## Failure boundary

All 19 normalized plans must pass before the restore barrier mutates anything.
All owner and global checkpoints must then succeed before Phase 4. A failure in
any later phase stops the plan and restores every touched owner in reverse
topological order, followed by session foundation, clock/RNG, capability and
barrier state. No render-frame wait is part of dependency resolution.
