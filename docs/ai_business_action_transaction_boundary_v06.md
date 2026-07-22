# AI business-action transaction boundary v0.6

Status: active production participant consumed by
`P0-AI-BUSINESS-COST-TYPED-CASH-CUTOVER`.

## Scope and authority

This boundary covers the existing AI `price_pump` market-pressure effect only. It does not change its 8–18 action roll, pressure conversion, market formula, product refresh order, AI policy, cash cost, public copy, or business cadence.

- `ProductMarketRuntimeController` remains the only owner of prices, temporary pressure, history and market refresh state.
- `RunRngService` remains the only authoritative random source.
- `AiBusinessCostCashPort` is the only typed coordinator of the AI cost. This market participant owns no cash, wager commitment, player record, UI state or save section.
- `route_sabotage` is explicitly rejected with `ai_business_route_sabotage_not_owned`; its route mutation cannot be made atomic by the market owner.

## Lifecycle

The market owner exposes one narrow, session-scoped participant:

1. `prepare_ai_business_market_pressure(request)` validates a pure-data allowlist, bounded transaction identity, explicit source revision, SHA-256 market fingerprint, authorized public region and product. It freezes the current supply/demand/disruption/weather facts and plans one action draw plus the ordinary product refresh against detached `RunRngService` cursors. Live market state, live RNG, bridge diagnostics and telemetry are unchanged.
2. `commit_ai_business_market_pressure(prepared)` uses market-preimage, frozen-source-facts and RNG-checkpoint compare-and-swap checks. It silently commits the 47 planned draws and the complete market postimage exactly once, then opens a rollback window. No irreversible RNG observer signal or telemetry is published.
3. `seal_ai_business_market_pressure_finalization(committed)` verifies the
   postimage, terminal RNG cursor, typed region-clue target and typed public-log
   target before cash commit, then returns an opaque finalization token while
   the rollback window remains open.
4. The typed cash coordinator attempts the authorized cash debit.
5. On cash rejection, `rollback_ai_business_market_pressure(sealed)` restores
   the complete market preimage and exact RNG checkpoint. No telemetry or
   public receipt is emitted.
6. On cash success, `finalize_ai_business_market_pressure(sealed)` consumes the
   already-validated token, claims a non-reentrant `finalizing` state, publishes
   buffered market/weather telemetry once, closes the rollback window and
   returns a visibility-safe public receipt. If an injected transient target
   outage occurs after the seal, the bounded journal retains which destination
   succeeded. The ProductMarket tick owns a bounded, stable-order maintenance
   drain; the same drain runs before session finish and save serialization. It
   retries only the missing publication, never cash, market mutation or RNG.
   The already-committed action remains a successful AI action for cycle-cap
   accounting while this presentation-only tail is pending.

A commit-side postimage failure performs internal compensation of both the RNG and market before returning failure. A rollback/finalize compare-and-swap failure marks the participant `recovery_required` and blocks new work rather than guessing at partial recovery.

## Determinism and parity

The existing and transactional paths share `_build_market_refresh_plan` and `_market_entry_with_external_pressure`; no second price formula or refresh implementation exists. The planner calls the scene-owned `RuntimeBalanceModel` directly, so prepare does not call a fake/legacy Main formula through `ProductMarketRuntimeWorldBridge`.

- Action roll: one authoritative detached integer draw in `[8, 18]`.
- Pressure: `max(1, ceil(action_roll / 10))`, unchanged.
- Refresh: one noise draw for every current catalog product (46 at this revision), in catalog order.
- Total transaction draw count: 47.
- The finalized market state and terminal RNG cursor must equal the existing direct action + refresh path for the same starting state and seed.

## Exact-once, save and privacy

The bounded journal has a 256-entry cap and is session-scoped:

- same transaction ID + same request fingerprint replays the first lifecycle receipt;
- same transaction ID + different fingerprint is rejected;
- stale market or RNG state is rejected before mutation;
- changed supply, demand, disruption or weather facts reject the prepared plan before mutation;
- lifecycle replay requires the opaque prepared token before returning any stored receipt;
- only terminal records may be evicted;
- a committed rollback window makes save preflight fail closed;
- save/checkpoint restore is rejected while that rollback window is open;
- terminal records release full market preimages, RNG cursors and telemetry batches;
- the journal is not persisted and adds no save field or save owner.

This is deliberately a synchronous participant, not a durable distributed
transaction. Its lifecycle methods contain no `await` or deferred callback.
The active `AiBusinessCostCashPort` integration executes private cash context
→ prepare → commit → finalization seal → cash → rollback/finalize in one call
stack. `ai_business_market_pressure_save_preflight()` is currently a
participant API; the global save coordinator has not yet been wired to it, so
no cross-frame or crash-recovery guarantee is claimed.

The public receipt is an explicit allowlist containing only an anonymous hashed public event ID, event kind, action kind, product, public region, pressure, before/after price, price delta, market revision, localization key and public visibility scope. It contains no player index, cash, wager commitment, AI plan/reason/score, decision sample, request fingerprint, RNG state, internal transaction token or hidden ownership. The player-facing public-log projection removes its internal exact-once receipt ID entirely.

## Active typed-cash integration

`AiRuntimeController` calls this lifecycle in the order shown above and uses an
opaque Coordinator-issued capability for `AiBusinessCostCashPort`. It does not
yield between lifecycle steps, reimplement pressure, call
`apply_external_pressure` separately, emit feedback before finalization, or
retain a Main fallback. AI decision telemetry and public feedback are recorded
only after both the market participant and typed cash debit succeed.
The finalized allowlisted receipt also restores the pre-cutover persistent
region clue and detailed public market log through typed scene-owned owners;
neither projection contains the paying AI or any private cash fact.

Production composition contains one cash port. The retired Main cost, price
pump and business-action dispatch methods are physically absent.
