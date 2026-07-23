# AI Actor Economy Query Port

## Boundary

`AiActorEconomyQueryPort` is a scene-owned, read-only composition boundary. It
is not a cash, city, warehouse, futures, AI-state, RNG, or save owner.

The production composition root issues one opaque
`AiActorEconomyCapability` per current AI seat and none for human seats. A
capability authorizes only the matching actor index and is rotated when the
authoritative player roster is replaced.

## Authority

- `WorldSessionState.private_player_cash_snapshot()` supplies the actor's exact
  signed cash total.
- `MonsterWagerCashCommitmentQueryPort` supplies wager-reserved and spendable
  cash. Negative totals remain exact while spendable cash fails closed at zero.
- `WorldSessionState.private_player_city_economy_snapshot()` supplies only
  cities whose authoritative owner is the actor, plus that actor's allowlisted
  income, spend, and build-progress counters.
- `ProductMarketRuntimeController.private_futures_positions_snapshot()`
  supplies only positions owned by the actor.

The public market projection continues to expose anonymous product-level
futures pressure, but redacts owner, position ID, source card, locked margin,
warehouse identity, and internal settlement formulas. Anonymous city warehouse
product/count/unit clues remain public through `AiRegionKnowledgeQueryPort`;
hidden owner and private storage lineage do not.

## Consumer Cutover

AI observation, learning baselines/rewards, route-hand affordability, card-play
affordability, card-purchase affordability, and generic spendable-cash checks
no longer read cash from a whole player record. Spending decisions use
wager-aware available cash; learning observations use exact signed total cash.

The remaining runtime-diagnostic progress consumer now reads the same
actor-private economy summary, and direct player interaction reads hand size
from `AiCardHandQueryPort`. `AiRuntimeController` no longer has a `players`
property, reads `players[index]`, writes the player collection, or supplies
runtime compatibility defaults. New-session plans initialize those zero-value
economy counters before the world owner applies the roster.

Market and route public queries are now cut over separately. Broad district
consumers still must move to actor-scoped region facts before the generic
bridge can be deleted.

## Persistence

No save section, schema, owner, or journal was added. Cash, world state, wager
commitments, and futures remain persisted by their existing domain owners.
`FULL_RUN_RESUME_CLAIM` remains false.

## Evidence

- `tests/ai_actor_economy_query_port_test.gd`
- `tests/ai_city_inference_typed_ports_cutover_test.gd`
- `tests/monster_wager_cash_commitment_query_port_cutover_test.gd`
- `tests/ai_card_hand_query_port_test.gd`
- `tests/ai_business_cost_typed_cash_cutover_test.gd`
- `tests/ai_business_action_transaction_boundary_test.gd`
- `tests/ai_card_phase_counter_owner_test.gd`
- `tests/main_runtime_composition_test.gd`

The focused contract proves actor isolation, forged/stale/human rejection,
signed cash, wager-aware available cash, own-city and own-futures filtering,
actor-only progress counters, public futures redaction, detached pure data,
zero world mutation, zero RNG consumption, and zero whole-player access from
the AI controller.
