# Ruleset v0.5 Migration Foundation Contract

Status: frozen for SS05-00
Recorded: 2026-07-14
Player rules authority: `docs/tabletop_rulebook_v05.md`

## Scope

This contract freezes repository recovery, branch topology, money units, clock
domains, and cross-domain receipts before any v0.5 gameplay cutover. It does
not activate v0.5, alter the v0.4 production bridge, or authorize parallel
runtime owners.

## Recoverable Baseline

- The current intentional v0.4 runtime state is captured by one commit and the
  annotated tag `v0.4-runtime-baseline`.
- The tag is valid only after a local clone from that tag imports in Godot 4.7
  and passes the focused composition and layout gates.
- Player saves, `user://` QA output, `.godot/`, local MCP screenshots, generated
  report import sidecars, credentials, and unregistered third-party files are
  excluded.
- The player save is audited only by metadata and SHA-256. Automated QA must
  continue to use `user://space_syndicate_design_qa/test_runs/`.
- A tag that cannot reconstruct the project from an empty directory is not a
  baseline and must not be advertised as one.

## Git Cutover Topology

- v0.4 is preserved by the immutable baseline tag and the existing release
  branch.
- v0.5 work proceeds on `rules/v05-runtime-integration`, which is explicitly a
  non-release integration branch until all v0.5 gates pass.
- After the first semantic hard cutover, the integration branch is not required
  to remain a complete v0.4 build. Recovery uses the baseline tag, not a runtime
  feature flag.
- No `main.tscn` runtime selector, automatic v0.4 fallback, dual mutation owner,
  or long-lived compatibility wrapper may be added.
- Each domain cutover contains the new owner, callers, save adapter, tests, and
  deletion of the old write path in the same commit.
- The final release operation promotes the already cut-over integration branch;
  it must not accumulate a second mass-deletion event.

## CurrencyAmount Wire Protocol

- `currency_scale` is `100`; one game currency unit is 100 integer cents.
- Every new v0.5 wire, receipt, snapshot, and save field uses a `_cents` suffix:
  `available_cents`, `escrow_cents`, `bid_cents`, `stake_cents`,
  `ledger_delta_cents`, and equivalent domain-specific names.
- Unsuffixed v0.4 `cash`, `bid`, and `amount` fields may be read only inside the
  versioned save migration boundary. New code must not reinterpret them.
- Every monetary mutation carries `transaction_id`, `currency_scale`, source and
  destination ledger IDs, pre/post balances, and the exact delta.
- Available and escrow balances are distinct. Public totals may expose their sum
  only where the rules explicitly allow it.
- Percentage calculations use integer/fixed-point arithmetic with the approved
  half-away-from-zero rule. Stable transaction/player ordering owns any remainder.
- Mixed-unit payloads fail validation. They never receive an inferred scale.
- Every commit path is exact-once and must prove ledger conservation.

## Clock Domains

`world_effective` advances only while the authoritative world simulation is
allowed to advance. `interaction_effective` advances while its interaction owns
the active surface and is not pre-empted. `forced_ui_realtime` ignores the world
freeze created by its own forced window, but still obeys explicit session pause
and application suspension. `battle_effective` advances only during the active
battle phase.

| Timer | Duration | Clock domain | Menu/read-only | Higher forced decision | Monster wager freeze | Save/load |
| --- | ---: | --- | --- | --- | --- | --- |
| victory qualification | 10s | `world_effective` | pause | pause | pause | remaining + candidate set |
| public audit | 120s | `world_effective` | pause | pause | pause | remaining + fixed entrants |
| audit failure cooldown | 30s | `world_effective` | pause | pause | pause | remaining |
| card group | 8s | `interaction_effective` | pause | pause/resume | pause/resume | phase + remaining |
| card organize | 6s | `interaction_effective` | pause | pause/resume | pause/resume | remaining + submissions |
| card lock | 2s | `interaction_effective` | pause | pause/resume | pause/resume | remaining + locked order |
| district purchase | 12s | `interaction_effective` | pause | pause/resume | pause/resume | remaining + locked price context |
| contract response | 8s | `interaction_effective` | pause | scheduler priority | pause/resume | remaining + responder |
| counter response | profile value | `interaction_effective` | pause | scheduler priority | pause/resume | remaining + response context |
| monster wager | 8s | `forced_ui_realtime` | pause | highest forced owner | advances | remaining + escrow receipts |
| standard monster battle | 45s | `battle_effective` | pause | pause | betting prelude excluded | remaining + damage totals |
| weather forecast | 90s | `world_effective` | pause | pause | pause | remaining + sequence |
| weather duration | 90s | `world_effective` | pause | pause | pause | remaining + active zones |
| financial distress | 20s | `world_effective` | pause | pause | pause | remaining + sell entitlement |
| intel live shares | 60s | `world_effective` | pause | pause | pause | remaining + last-known snapshot |

All timers save remaining effective time and domain state. No controller may
reconstruct a deadline from wall-clock time after load. UI may format time but
must not own or decrement it.

## Cross-Domain Ownership

### Public bid pool and monster wager

- `CardResolutionQueueRuntimeService` is the only producer of
  `public_wager_pool_receipt` from the v0.5 0/50/100 priority bids.
- The receipt contains a stable receipt ID, batch ID, total delta in cents, and
  ledger revision. It contains no card owner or private target.
- `MonsterRuntimeController` consumes the receipt exactly once. It does not
  recalculate card bids or own the Queue ledger.
- Live wager integration therefore depends on SS05-05. A core wager state model
  may be tested earlier only with injected immutable receipts.

### Financial distress and elimination

- `FinancialDistressRuntimeController` owns crisis entry, 20-second effective
  time, restrictions, recovery, and the once-per-crisis emergency-sale entitlement.
- It emits `elimination_requested`; it does not mutate Queue, Military, Monster,
  Finance, CityTrade, or project shares directly.
- `EndStateSettlement` orders domain receipts. Each domain controller remains
  the only owner of its own mutation.
- Elimination is committed only after every receipt succeeds; retrying the same
  settlement transaction is idempotent.

### Contract damage state

- Temporary endpoint damage uses `delivery_blocked` or `effect_suspended`.
- Contract `expires_at` continues to advance while delivery is blocked.
- Project destruction creates a permanent tombstone and follows the separate
  project-generation lifecycle contract.
- The ambiguous state name `paused` must not be used where it could imply that
  contract duration stops.

## Deferred Product Decision

The v0.5 player rules define an emergency sale at 50% of purchase price but do
not define the acquisition basis of a merged/upgraded card entity. Until a
product decision selects cumulative paid basis, latest-copy basis, base-family
basis, or another explicit rule, implementation of emergency-sale valuation is
blocked. This blocks SS05-10, not SS05-01 schema work. Runtime must not silently
choose a basis from current catalog price.

## Hard Cutover Evidence

Every hard-cutover work order records:

- `main.gd` before/after SHA-256, total/nonblank lines, functions, variables, and constants;
- forbidden legacy symbols and a source scan proving they are absent;
- the permitted adapter surface and its maximum LOC;
- focused behavior, save, privacy, exact-once, and pure-data gates;
- 3-, 4-, and 8-seat cases where the domain is seat-sensitive;
- 2- through 7-AI cycles where the domain is AI-sensitive;
- a Godot 4.7 parse/runtime check with zero new errors.

Adapters may collect world facts and apply stable receipts. They may not keep a
second formula, score, mutation path, or test-only production fallback.
