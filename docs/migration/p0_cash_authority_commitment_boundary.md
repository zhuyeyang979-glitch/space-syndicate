# P0 cash authority and wager-commitment boundary

Status: `PORT_READY_FOR_INTEGRATION`

Rule authority gate: `GREEN`

## Frozen ownership

- `WorldSessionState.players[*].cash_cents` is the exact cash truth.
- `WorldSessionState.players[*].cash` is the existing whole-unit mirror.
- `WorldSessionState.players[*].v06_transaction_ledger` remains the only saved
  exact-once ledger used by this boundary. No save section was added.
- `MonsterRuntimeController` remains the unresolved monster-wager commitment
  owner.
- `MonsterWagerCashCommitmentQueryPort` remains the private read/authorization
  boundary that combines the two owners. It stores neither state.
- `PlayerCashMutationPort` is a stateless typed mutation boundary. It prepares
  one copied player record and atomically replaces that record through
  `WorldSessionState.players`; it owns no balance, journal, wager, formula, or
  presentation state.

## Current write-path inventory

| Path | Current mutation | Commitment behavior | Classification |
|---|---|---|---|
| `Main._commit_product_market_cash_delta` | writes whole-unit `cash`; bridge reconciles cents afterward | bridge pre-authorizes debits | unsafe transitional path: Main mutation plus split authorization/commit |
| `Main._commit_city_gdp_derivative_cash_delta` | writes whole-unit `cash`; bridge reconciles cents afterward | bridge pre-authorizes debits | unsafe transitional path: Main mutation plus split authorization/commit |
| `Main._apply_role_monster_upgrade_cash` | writes `cash` and income counters directly | positive income, so no debit guard | unsafe transitional path: cents mirror may drift and retry has no exact-once key |
| `MonsterRuntimeController` wager settlement | applies the settlement owner's frozen participant postimage | consumes its own frozen commitments | legitimate wager-owner path; not migrated by this task |
| `CommodityFlowWorldBridge.apply_sale_receipt_batch` | applies an atomic batch to copied players and existing v0.6 ledger | pre-authorizes negative deltas | separate P0 sale-receipt boundary; not migrated by this task |
| Card/district settlement services | prepare copied player postimages | existing commitment query is injected | existing transaction boundaries; not migrated by this task |

The three Main paths above are the integration target. They are not modified in
this worktree because `scripts/main.gd`, `GameRuntimeCoordinator` and production
composition are integration-only hot files.

## New typed API

`PlayerCashMutationPort` exposes three purpose-specific entry points:

1. `commit_product_market_cash_delta(...)`
2. `commit_city_gdp_derivative_cash_delta(...)`
3. `commit_role_monster_upgrade_cash(...)`

Every call requires a stable transaction ID. A first commit:

1. validates identity and authored counter classification;
2. detects a prior transaction in the player's existing v0.6 ledger;
3. for debits, authorizes against current cash minus all unresolved wager
   commitments;
4. compares the authorized exact-cents preimage again immediately before apply;
5. rejects overflow and negative postimages;
6. updates `cash_cents`, `cash`, existing income counters, private history and
   private economic events in one copied record;
7. appends one exact-once receipt to the existing v0.6 ledger;
8. atomically replaces the player record through `WorldSessionState`.

An identical retry returns the stored receipt with zero side effects. Reusing a
transaction ID with different terms fails closed.

## Transaction identity required from production owners

- Product futures open: `product-futures:<player>:<position_id>:open`.
- Product futures settlement: `product-futures:<player>:<position_id>:<reason>`.
- Product card immediate income: the existing card-resolution transaction ID
  plus a `product-market-cash` suffix.
- City GDP derivative open/settlement: the existing position ID and lifecycle
  phase.
- Role monster-upgrade reward: monster UID plus resulting rank and the role cash
  suffix.

No timestamp, frame number, UI state, player name, or random value may be used
as transaction identity.

## Scope and remaining integration

The production scene does not yet instantiate this port. The cutover request is
`docs/integration_requests/P0-CASH-AUTHORITY-COMMITMENT-BOUNDARY.json`.

Until that request is integrated, the three Main methods remain the active
production path and this task must not be described as a completed production
cutover. The new focused test and real Bench prove the replacement boundary
itself, including exact cents, wager-reserved funds, negative-balance rejection,
market/GDP classification, role reward exact-once, and save/load replay.
