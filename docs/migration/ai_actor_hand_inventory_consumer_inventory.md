# AI Actor Hand Inventory Consumer Inventory

## Status

`STATUS=AI_ACTOR_HAND_INVENTORY_CONSUMER_INVENTORY_FROZEN`

Parent task `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains `ACTIVE`. This inventory covers only an AI actor's own private ordinary hand projection. It does not migrate rival hands, card mutations, public market supply, card-resolution queues, AI memory, city inference, districts, save ownership, or the deferred session-default writer.

## Authority Map

| Fact | Authoritative owner | Visibility | Typed source |
| --- | --- | --- | --- |
| Physical hand slots and runtime card rows | `WorldSessionState.players[].slots` | actor-private | `AiActorHandInventoryQueryPort.actor_hand_snapshot` |
| Ordinary hand limit and discardability policy | `CardInventoryRuntimeService` | internal rule projection | same snapshot |
| AI seat and elimination eligibility | `AiActorStatePort` public projection | public authorization input | capability preflight |
| Session identity | `GameSessionRuntimeController` | internal binding | snapshot identity |
| Card family and rank lookup | `CardRuntimeCatalogService` through the existing definition bridge | public catalog | AI scoring consumer |

`AiActorHandInventoryQueryPort` owns none of these values. It stores no hand, discard, card, RNG, player, session, or save state.

## Consumer Cutover

| Consumer | Previous read | Typed use | Result |
| --- | --- | --- | --- |
| `_ai_actor_private_receive_pressure` | `players[player_index]` plus Main hand-count helper | counted size and hand limit | MIGRATED |
| `_ai_observation_vector` | mutable player slots | counted size | MIGRATED |
| `_ai_route_hand_inventory` | mutable player slots | detached stable slot rows | MIGRATED |
| `_ai_card_play_candidates` | mutable player slots | detached stable slot rows | MIGRATED |
| `_ai_card_buy_candidates` | mutable player slots plus Main family helper | count, limit, discardable slots, card rows | MIGRATED |
| `_ai_counter_response_candidates` | mutable player slots | detached stable slot rows | MIGRATED |
| `_ai_queue_counter_response_candidate` | mutable player slot re-read | stable slot revalidation | MIGRATED |
| `_ai_discard_keep_value` | mutable player slot read | detached card row | MIGRATED |
| `_ai_discard_slot_for_purchase` | DistrictSupply private discard query | typed discardable slot indices | MIGRATED |

`UNKNOWN_COUNT=0`.

## Preserved Semantics

- Slot indices are never compacted; holes remain explicit rows.
- Play and counter candidates still exclude queued, cooldown-positive, and lock-positive cards.
- Route inventory still excludes queued and locked cards without adding a new cooldown rule.
- Discardability still excludes hand-limit-exempt, queued, and locked cards.
- Explicit `counts_toward_hand_limit` metadata overrides the legacy kind fallback through `CardInventoryRuntimeService`.
- The QueryPort contains no copy of the hand-limit exemption catalog.
- The first equal-value discard slot still wins.
- Family upgrade scoring still uses the existing card catalog.
- Query, render, and validation consume zero RNG and do not mark save state dirty.
- Malformed hand storage, malformed timing, impure payloads, forged capability, human seats, eliminated seats, and stale session identity fail closed.

## Explicitly Deferred

- `ROUTE_HAND_COOLDOWN_PARITY`
- `LIVE_AI_STABLE_TIE_BREAK`
- `AI_HAND_SAVE_DIRTY_CORRECTION`
- Existing DistrictSupply private-query read mutation
- `_ensure_player_runtime_defaults` session-default mutation ownership
- Remaining district, route, market, monster, military, weather, Victory, and presentation facts

These are independent boundaries. No behavior change for them is claimed here.

## Source Delta

| Metric | Before | After |
| --- | ---: | ---: |
| `AiRuntimeController` `players` tokens | 20 | 12 |
| `districts` tokens | 95 | 95 |
| `_call_world` tokens | 42 | 40 |
| Direct AI own-hand reads in the frozen consumer set | 8 | 0 |
| AI `PLAYER_HAND_LIMIT` Main proxy tokens | 3 | 0 |
| New Main callers | 0 | 0 |
| New save sections | 0 | 0 |

The remaining two true `players[index]` accesses are the deferred session-default mutation loop. They are not disguised as queries and are not claimed as migrated.
