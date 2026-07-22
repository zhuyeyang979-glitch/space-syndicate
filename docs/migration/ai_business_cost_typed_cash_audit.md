# AI business cost typed-cash audit

Status: production validation complete.

## Frozen behavior

- `price_pump` cost: 90 cash units / 9000 cents.
- chance: unchanged at 76 percent.
- maximum actions per cycle: unchanged at 2.
- market action draw: unchanged 8-18.
- candidate scores, weighted selection, AI learning metadata, market formula,
  cycle cadence and RNG draw order remain unchanged.
- committed monster-wager funds are unavailable to ordinary spending.

## Authority map

| State or decision | Sole authority |
|---|---|
| AI candidate and action decision | `AiRuntimeController` |
| AI policy cost | `AiPolicyProfileResource` |
| cash balance | `WorldSessionState` |
| ordinary-spend availability | `MonsterWagerCashCommitmentQueryPort` |
| canonical cash mutation and existing lineage | `PlayerCashMutationPort` |
| market pressure / prices / market RNG plan | `ProductMarketRuntimeController` |
| simulation mutation authorization | `SimulationMutationAuthority` |
| typed coordination | `AiBusinessCostCashPort` (stores no balance) |

## Go decision

The market participant prerequisite supplies side-effect-free prepare,
reversible commit, rollback and non-reentrant finalize. The existing cash port
already supplies canonical cents, whole-unit mirror, economic history, spend
counters, mutation audit and the player transaction ledger. Therefore the
typed cutover can be implemented without a second state owner or partial-state
window.

The final implementation adds a synchronous market-finalization seal before
cash commit. The real `main.tscn` four-player gate proves that ProductMarket's
cycle callback runs inside `RuntimeSimulationStep`, and covers success,
same-step duplicate, unresolved-wager rejection and human capability rejection.
Matching completed requests replay across later steps/cycles; evicted cache
entries reconstruct the first reserved/available-cash facts from the single
WorldSessionState transaction ledger.

The final seal also preflights the typed public-clue and public-log targets.
Their anonymous event identity is derived only from already-public facts, and
player-facing log rows omit internal receipt IDs. A fault-injected missing
target leaves only the presentation tail pending: the economic action still
counts toward the AI cycle cap, ProductMarket retries the missing destination
in stable order during tick/finish/save maintenance, and new-session checkpoint
capture fails closed until the tail drains. Cash, market mutation and RNG are
never replayed. Typed requests additionally bind the 90-unit cost-policy
fingerprint, so a cost drift is rejected before mutation.

`FULL_RUN_RESUME_CLAIM=false` remains unchanged.
