# AI business cost typed-cash cutover

Status: production cutover validated; GitHub delivery pending.

## Frozen product behavior

- Anonymous AI market-pressure chance remains **76%**.
- The per-cycle cap remains **2** actions.
- Each successful action costs **90 cash units / 9000 cents**.
- The market participant still draws one action delta in **8–18** and one
  noise value for each of the 46 products: **47 RunRngService draws** total.
- `route_sabotage` remains a scored candidate but fails closed because no
  reversible route-side-effect owner is approved in this boundary.

## Production ownership

```text
AiRuntimeController
  -> typed AiBusinessCostDebitRequest
  -> ProductMarketRuntimeController prepare/commit
  -> AiBusinessCostCashPort
  -> MonsterWagerCashCommitmentQueryPort
  -> PlayerCashMutationPort
  -> SimulationMutationAuthority
  -> WorldSessionState
  -> ProductMarketRuntimeController rollback or finalize
```

`WorldSessionState` remains the only cash owner.
`MonsterRuntimeController` remains the only unresolved-wager commitment owner.
`AiBusinessCostCashPort` stores only a 256-entry, session-scoped detached
receipt cache. Its durable replay check delegates to the existing player
transaction ledger in `WorldSessionState`; it owns no save section.

## Atomic lifecycle

1. AI freezes action kind, product, public region, cycle, session, step, market
   fingerprint, cash-cost policy fingerprint and cash-availability fingerprint.
2. The cash port proves the actor is an active AI and that 9000 cents are
   currently available after unresolved wager commitments.
3. ProductMarket prepares without live market or RNG mutation.
4. ProductMarket commits a reversible market/RNG postimage.
5. ProductMarket seals finalization by validating the live postimage, RNG
   terminal cursor and both typed public destinations before any cash can
   commit. The sealed token keeps rollback open but removes the post-cash
   compare-and-swap or ordinary publication-availability failure path.
6. PlayerCashMutationPort re-authorizes the exact availability fingerprint and
   atomically writes `cash_cents`, whole-unit `cash`, business spend, cash
   history, economic ledger, transaction lineage and mutation audit.
7. Cash rejection rolls ProductMarket and RunRngService back synchronously.
8. Cash success consumes the sealed token, finalizes the market participant,
   appends the allowlisted region clue and publishes one typed detailed public
   log receipt. Both destinations use the same anonymous hashed public event
   identity; a transient post-seal publication fault remains in a bounded
   `finalizing` state. The ProductMarket owner drains those pending public-only
   receipts in stable journal order at the start of its next runtime tick,
   before session finish, and before save serialization. It retries only the
   missing destination and never replays cash, market or RNG. An economically
   committed action counts toward the AI's per-cycle cap even while this
   presentation-only tail is pending. ProductMarket save data stays unavailable
   until the tail drains, and the new-session checkpoint coordinator rejects an
   empty/blocked ProductMarket checkpoint rather than accepting a corrupt
   rollback preimage.

There is no deferred step, Main fallback, duplicate cash owner or duplicate
market path. Cross-owner finalization has no mutable CAS after cash commit;
direct single-owner callers retain their original finalization CAS guard.

## Exact-once

- Same request ID and fingerprint returns a detached idempotent receipt.
- Same request ID with another action, product, region, cost or binding is a
  collision.
- New requests bind session, session revision, market cycle, simulation step,
  cash-cost policy revision and cash availability and fail closed when any is
  stale.
- An already-completed matching request replays its first receipt after later
  simulation steps or market cycles within the same session.
- After the 256-entry port cache evicts a receipt, the single cash-owner ledger
  reconstructs the replay result, including the original reserved and
  available cash facts, before a second debit can occur.
- If a market participant has been newly committed but the cash owner reports
  a replay or rejection, that tentative market/RNG change is rolled back.

## Privacy

The cash request and receipt are actor-private. No public projection contains
player index, exact cash, available cash, reserved wager cash, fingerprints,
AI plan, score, samples or transaction lineage. Player-facing callouts are
formatted only from ProductMarket's allowlisted public receipt. The market
owner also restores the existing public inference behavior through one typed
region clue and one exact-once public-log receipt; neither contains cash.
The public log owner retains its receipt identity privately for deduplication,
but removes `receipt_id` from every player-facing entry projection.

## Formal runtime proof

`ai_business_cost_formal_four_player_test.gd` loads the real `main.tscn`, starts
one human plus three AI through `SessionStartTransaction`, and lets the unique
`RuntimeLoop` trigger the real ProductMarket cycle. It covers successful debit,
same-step duplicate intent, a real unresolved monster-wager commitment, human
capability rejection, typed public logging and public-clue persistence.

## Main retirement

Physically removed in the same cutover:

- five business policy/effect constants;
- three business world-constant exports;
- `_pay_rival_business_cost`;
- `_apply_rival_price_pump`;
- `_apply_rival_business_action`;
- `_set_city_public_clue` after its only consumer was removed;
- AiRuntimeController's dynamic Main action dispatch and post-hoc cash
  reconciliation.

The inherited Main caller baseline drift remains 103 current files versus the
recorded budget of 102; this cutover adds zero production or test Main caller
files and does not alter that historical baseline.

`FULL_RUN_RESUME_CLAIM=false`.
