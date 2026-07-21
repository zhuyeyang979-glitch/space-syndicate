# Monster Wager Cash Commitment Query Port Cutover

## Outcome

Monster wagers continue to be commitments rather than early cash debits. While
any unresolved wager exists, every ordinary negative-cash production path now
uses one private, scene-owned query boundary before it may spend cash:

```text
WorldSessionState cash
        +
MonsterRuntimeController unresolved wager commitments
        ↓
MonsterWagerCashCommitmentQueryPort
        ↓
available cash / debit authorization
```

The port owns no cash, wager, journal, save section, or public snapshot. It is
composed once at
`GameRuntimeCoordinator/MonsterWagerCashCommitmentQueryPort` and injected into
the existing card, market, derivative, contract, interaction, commodity,
purchase and AI consumers.

## Frozen rule

- Confirming a wager does not debit cash.
- Its opening-cash stake is immediately unavailable to ordinary spending.
- New income remains available and never changes the frozen stake.
- Multiple unresolved commitments add together.
- Malformed or unavailable commitment facts fail closed.
- Only `MonsterRuntimeController` final settlement may consume the commitment
  it owns; ordinary consumers have no exclusion API.

## Currency mirror hardening

The v0.6 state contains exact `cash_cents` plus a transitional whole-unit
`cash` mirror. Several existing legacy unit writers have not yet been retired.
`WorldSessionState.private_player_cash_snapshot()` is now the sole
normalization query: coherent cents keep their fractional remainder, while a
whole-unit drift is reconciled before wager authorization or settlement so
stale cents cannot resurrect spent money.

Existing unit-only callbacks are followed by the typed
`reconcile_private_player_cash_after_unit_mutation()` owner hook. Runtime
consumers that already own a composite postimage write both fields together.
The query port remains read-only.

## Covered ordinary debit paths

- v0.6 region/card purchases through `CardPlayerStateProductionAdapterV06`;
- legacy queued-card play cost and financial margin;
- final card commitment cost;
- commodity futures and city-GDP derivatives;
- contract penalties;
- player-hand disruption penalties;
- legacy district purchase settlement while it remains composed;
- active commodity/storage debt batches;
- AI anonymous business spending;
- monster-owner damage already using the same reserved-cash rule.

Income, refunds and awards remain legal, but their two currency fields are kept
coherent so a later cents-based economy batch cannot erase or duplicate them.

## Privacy

The port exposes only actor-scoped private runtime data. No presentation source,
public log, map snapshot or player-facing viewmodel consumes reserved cents,
opening cash, commitment fingerprints or rival cash. The public wager receipt
continues to expose only the already-approved wager clues.

## Evidence

- `tests/monster_wager_cash_commitment_query_port_cutover_test.gd`
- `scenes/tools/MonsterWagerCashCommitmentQueryPortBench.tscn`
- `tests/monster_wager_settlement_owner_cutover_test.gd`
- `tests/monster_wager_response_cutover_test.gd`
- `tests/card_player_state_production_adapter_v06_test.gd`
- `tests/card_execution_typed_ports_cutover_test.gd`
- `tests/commodity_flow_atomic_batch_sink_v06_test.gd`
- `tests/main_runtime_composition_test.gd`
- `tests/main_gd_architecture_gate_test.gd`

## Next boundary

This cutover does **not** create the authoritative 60-second battle phase. The
next atomic task is `MONSTER_BATTLE_LIFECYCLE_OWNER_CUTOVER`: separate the
15-second real-time forced choice from the world-effective battle timer, lock
the combat roster, accumulate valid damage, save/restore the phase and settle
exactly once at battle end.
