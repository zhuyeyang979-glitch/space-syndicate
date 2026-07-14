# Bankruptcy Neutral Estate Runtime Contract (v0.6)

`BankruptcyNeutralEstateRuntimeController` is the only bankruptcy checkpoint owner. `GameRuntimeCoordinator` invokes it after a committed CommodityFlow Sale Receipt batch and before asset recovery or Victory. `Main` no longer evaluates cash thresholds or mutates bankruptcy state.

## Rule boundary

- Exact `cash_cents < 0` enters bankruptcy; `cash_cents == 0` remains active.
- Only active-production warehouse rent may authorize an atomic negative cash result. One-shot/passive forced supply is capped by CommodityFlow and is rejected fail-closed by the world bridge if it would cross zero.
- The estate transaction clears ordinary hand slots and unsold warehouse/pending-supply goods, removes military units, orphans monsters, and transfers player facilities to `neutral`. Monster rank/HP/timers and facility rank/shared-region HP are unchanged.
- Neutral-facility rent is journaled by Sale Receipt identity and credited exactly once to the next monster public wager pool.
- After finalization, one remaining active player requests the existing Victory owner’s `last_survivor` outcome once.

## Atomic lifecycle

The controller owns the transaction journal and routes pure-data `prepare`, `commit`, `rollback`, and `finalize` requests through a non-owning WorldBridge. Participants are the production card-player adapter, CommodityFlow, Military, Monster, and Region Infrastructure owners. Each participant captures a private preimage and validates its authoritative revision/fingerprint before commit. Any prepare/commit failure rolls completed participants back in reverse order; route facts refresh only after commit or rollback.

The public receipt has exactly three top-level fields:

```text
player_indices
estate_counts
reason
```

It never contains exact cash, card/product identities, owner truth, discard details, or AI plans. Private preimages remain inside owner journals and are discarded at finalize. Save registration is intentionally deferred to the v3 owner registry phase.

## Developer evidence

`BankruptcyNeutralEstateRuntimeBench.tscn` composes the real Coordinator and owners. Its focused cases cover negative/zero cash, five-owner estate mutation, cross-owner rollback, exact-once replay, neutral rent, active/passive negative-cash gates, last-survivor sequencing, and the receipt allowlist. Final acceptance remains Supervisor-owned.
