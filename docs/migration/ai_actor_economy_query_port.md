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
  cities whose authoritative owner is the actor.
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

This boundary does not claim the market or route query cutover is complete.
`AiRuntimeController` still has broad market and district consumers that must
move to `AiMarketPublicQueryPort`, `AiRoutePublicQueryPort`, and actor-scoped
region facts before the generic bridge can be deleted.

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
public futures redaction, detached pure data, zero world mutation, and zero RNG
consumption.
