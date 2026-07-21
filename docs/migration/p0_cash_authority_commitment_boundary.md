# P0 cash authority and wager-commitment boundary

Status: `PRODUCTION_CUTOVER_GREEN`

Rule authority gate: `GREEN`

## Production ownership

- `WorldSessionState.players[*].cash_cents` is the exact cash truth.
- `WorldSessionState.players[*].cash` is the existing whole-unit mirror.
- `WorldSessionState.players[*].v06_transaction_ledger` remains the only saved
  exact-once ledger used by this boundary. No second balance, journal, snapshot,
  or save section was added.
- `MonsterRuntimeController` remains the monster-wager commitment owner.
- `MonsterWagerCashCommitmentQueryPort` remains the private read/authorization
  boundary that combines the two owners. It stores no state.
- `PlayerCashMutationPort` is the sole typed commit boundary for product-market,
  city-GDP-derivative, and role monster-upgrade cash changes. Production composes
  exactly one instance beside the existing `WorldSessionState`.

`PlayerCashMutationPort` writes a copied player record back to
`WorldSessionState.players` only after transaction identity validation,
`SimulationMutationAuthority` authorization, unresolved-wager commitment
authorization, and exact-cents preimage comparison. It then records the
deterministic mutation. If audit recording fails, the copied player postimage is
rolled back. This is the authorized atomic commit, not a second cash owner.

## Retired Main paths

The following production methods were physically deleted with no wrapper or
fallback:

- `Main._commit_product_market_cash_delta`
- `Main._commit_city_gdp_derivative_cash_delta`
- `Main._apply_role_monster_upgrade_cash`

The product-market and city-GDP world bridges no longer use dynamic Main cash
callbacks or post-hoc cents reconciliation. Monster role-upgrade rewards no
longer call Main and read their public role-card fact from `WorldSessionState`.

## Typed commit semantics

The port exposes three purpose-specific entry points:

1. `commit_product_market_cash_delta(...)`
2. `commit_city_gdp_derivative_cash_delta(...)`
3. `commit_role_monster_upgrade_cash(...)`

A first commit:

1. validates stable identity and authored counter classification;
2. checks the existing player ledger for an exact replay or conflicting reuse;
3. requires an active `SimulationMutationAuthority` step;
4. authorizes debits against cash minus all unresolved wager commitments;
5. compares the exact-cents preimage again immediately before apply;
6. rejects overflow and negative postimages;
7. updates cents, whole-unit mirror, counters, private history, and private
   economic events in one copied record;
8. appends one receipt to the existing v0.6 ledger;
9. atomically replaces the player record and records the deterministic mutation.

An identical retry returns the stored receipt with zero side effects. Reusing a
transaction ID with different immutable terms fails closed. The market `cycle`
is retained on the first committed private audit event, but is excluded from the
immutable command fingerprint so a later-cycle retry remains an exact replay.
Save/load replay uses the same existing ledger and does not repeat cash,
counters, history, or events.

## Stable transaction identities

- Product futures open: `product-futures:<player>:<position_id>:open`
- Product futures settlement: `product-futures:<player>:<position_id>:<reason>`
- Product card immediate income:
  `<card-resolution-id>:product-market-cash`
- City GDP derivative open/settlement:
  `city-gdp:<player>:<position_id>:<phase>`
- Role monster-upgrade reward:
  `monster:<monster_uid>:rank.<new_rank>:role-cash`

No timestamp, frame number, UI state, player name, or random value participates
in transaction identity. Position sequences roll back when opening debit fails.

## Simulation-authority truth

All first cash mutations require `SimulationMutationAuthority` authorization and
produce a deterministic mutation audit record. Direct calls outside an active
simulation step fail closed.

Player/card-originated product income and monster-upgrade reward already enter
through the existing card command/transition execution path, so their path is:

`RuntimeCommandPipeline -> RuntimeSimulationStep ->
SimulationMutationAuthority -> PlayerCashMutationPort`.

Timer-driven product-futures and city-GDP settlements are existing ordered
simulation-phase operations. They are not synthetic player commands and this
cutover did not invent a second command type. They still execute only within
`RuntimeSimulationStep` and can commit only while mutation authority is active.

## Privacy and formula boundaries

- No cash, commitment, ledger, or authority diagnostic was added to a public
  snapshot.
- The port and query port remain internal runtime nodes.
- Existing product, GDP, wager, and role reward amounts/formulas are unchanged.
- Wager settlement continues to consume its own frozen participant postimage;
  it was not re-owned by this boundary.
- Commodity-flow atomic sale-receipt batches remain their existing separate P0
  boundary.

## Main budget

| Metric | Before integration | After integration | Delta |
|---|---:|---:|---:|
| Physical lines | 6741 | 6641 | -100 |
| Nonblank lines | 5690 | 5596 | -94 |
| Methods | 486 | 483 | -3 |
| Top-level variables | 47 | 47 | 0 |
| Constants | 64 | 64 | 0 |

`check_main_gd_budget.py --json` reports `ok: true`; external Main caller files
remain 102 and production reference files did not increase.

## Validation evidence

- `player_cash_mutation_port_test.gd`: `39/39 PASS`
- `monster_wager_cash_commitment_query_port_cutover_test.gd`: `33/33 PASS`
- `card_resolution_product_market_target_envelope_test.gd`: `18 PASS`
- `monster_card_resolution_actor_propagation_test.gd`: `28/28 PASS`
- `CityGdpDerivativeRuntimeBench`: `40/40 PASS`
- `world_session_state_cutover_test.gd`: `44/44 PASS`
- `monster_cross_owner_upgrade_v06_test.gd`: `24 PASS`
- `product_market_owner_smoke_fixture_test.gd`: `15 PASS`
- `main_gd_architecture_gate_test.gd`: `202 PASS`
- `main_runtime_composition_test.gd`: `PASS`
- `smoke_test.gd --check-only`: exit `0`
- Godot 4.7 MCP `PlayerCashMutationPortBench.tscn`: `11/11 PASS`
- Static negative gate: all three retired Main symbols have zero production hits.
- Cross-cycle exact-once coverage: product, GDP derivative, role reward, and
  save/load retry all preserve the first committed audit event.
- `git diff --check`: `PASS`

Godot reports repository-wide pre-existing warnings during import; this cutover
adds no parse error, runtime error, missing-access error, or orphan connection.
The retired broad full-smoke fixture still names the removed Main role-reward
method and must be migrated independently; this cutover does not restore it.

The product-futures, GDP-derivative, role-upgrade, speculation, and legacy
product-contract callers currently perform a synchronous cash-first mutation
followed by their domain postimage. No reachable post-cash branch explicitly
returns failure, so this does not block the cash-owner cutover. A future change
that makes any post-cash step fallible must first add a composite transaction or
compensation boundary and post-cash fault-injection coverage.
