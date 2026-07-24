# AI Actor Economy Facts Consumer Inventory

## Status

`STATUS=AI_ACTOR_ECONOMY_FACTS_CONSUMER_INVENTORY_FROZEN`

Parent task `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains `ACTIVE`. This inventory covers only actor-private cash, cooldown, and existing private economy training counters. Hand, slots, discard, markets, routes, regions, monsters, military, weather, Victory, and save ownership remain separate boundaries.

## Authority Map

| Fact | Authoritative owner | Visibility | Typed source |
| --- | --- | --- | --- |
| Total ledger cash | `WorldSessionState.players[].cash_cents` | actor-private | `AiActorEconomyFactsQueryPort.actor_training_economy_facts` |
| Pending wager commitment | `MonsterRuntimeController.active_monster_wagers` | actor-private | `MonsterWagerCashCommitmentQueryPort.private_cash_availability_projection` |
| Available cash | Derived total minus wager commitment | actor-private | `AiActorEconomyFactsQueryPort.actor_decision_facts` |
| Action cooldown | `WorldSessionState.players[].action_cooldown`; mutated by `CardCooldownRuntimeController` | actor-private | decision facts |
| Existing income/spend counters | `WorldSessionState.players[]` | actor-private | training economy facts |
| Session identity | `GameSessionRuntimeController` | internal binding | both snapshots |
| Eligible AI identity | `AiActorStatePort` public projection | public authorization input | capability preflight |

The new QueryPort owns none of these values. It stores no cash, wager, cooldown, counter, player, or save state.

## Consumer Classification

| Consumer | Old read | Required meaning | Result | Deferred residue |
| --- | --- | --- | --- | --- |
| `_rival_business_candidates_for_player` | spendable-cash helper | available cash | MIGRATED | none |
| `_auto_rival_business_actions` | spendable-cash helper | available cash | MIGRATED | none |
| `_spendable_cash_units` | direct wager cash query | available cash | MIGRATED | none |
| `_ai_live_route_balance_report` | mutable player economy counters | training counters | MIGRATED | route/monster/Victory facts remain with their domains |
| `_ai_observation_vector` | legacy `cash` mirror | total ledger cash | MIGRATED | hand and other observation domains remain |
| `_record_ai_decision` | observation cash | total ledger baseline | MIGRATED | actor memory remains in `AiActorStatePort` |
| `_finalize_ai_decision_rewards` | legacy `cash` mirror | total ledger delta | MIGRATED | none |
| `_ai_route_hand_inventory` | mutable player cash plus hand | available cash | PARTIALLY_MIGRATED | hand/inventory typed boundary |
| `_ai_card_play_context` | mutable player cash | available cash for explicit cost | MIGRATED | card legality remains with card owners |
| `_ai_card_play_candidates` | mutable cooldown plus slots | action-ready gate | PARTIALLY_MIGRATED | slots/hand typed boundary |
| `_ai_card_buy_candidates` | mutable cooldown and cash plus slots | action-ready and available cash | PARTIALLY_MIGRATED | slots/inventory typed boundary |
| `_ai_counter_response_candidates` | mutable cooldown plus counter hand | action-ready gate | PARTIALLY_MIGRATED | counter-hand typed boundary |
| `_ensure_player_runtime_defaults` | mutable default write | owner mutation, not a query | DEFERRED | move to the formal player/session initializer |

`UNKNOWN_COUNT=0`.

## Rule Parity

- Training uses total ledger cash. An unsettled wager is not a realized training loss.
- Card purchase, explicit card cash cost, and ordinary business affordability use available cash.
- `action_cooldown > 0.0` still blocks play, buy, and counter candidates only.
- Query and page refresh paths consume zero RNG.
- Existing AI personality, candidate scores, ordering, action frequency, business formula, market formula, and learning schema are unchanged.
- Malformed commitment, cash, cooldown, session, or actor identity fails closed.

## Source Delta

| Metric | Before | After |
| --- | ---: | ---: |
| `AiRuntimeController` `players` tokens | 27 | 20 |
| `districts` tokens | 95 | 95 |
| `_call_world` tokens | 42 | 42 |
| Direct `player.get("cash")` reads in the controller | 6 | 0 |
| Direct `action_cooldown` reads in the controller | 3 | 0 |
| New Main routes | 0 | 0 |
| New save sections | 0 | 0 |

Remaining `players` references are primarily hand/inventory access and the deferred runtime-default mutation path. They are not claimed as migrated.