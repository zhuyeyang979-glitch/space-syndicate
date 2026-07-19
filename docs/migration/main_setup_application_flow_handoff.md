# Setup session-start cutover handoff

## Implemented

- Dedicated `setup_requested` signal; setup emits no generic application action.
- One scene-owned setup draft with typed commands, stale-revision checks and
  exact-once collision handling.
- Read-only setup query with zero live RNG use.
- Deterministic `SessionStartPlan` from a detached `RunRngService` checkpoint;
  world geometry is delegated to the pure `SessionStartWorldPlanBuilder`.
- Both initial ProductMarket refreshes and the initial Weather forecast are
  built from detached RNG in the plan. Their complete draw sequence is part of
  `rng_terminal_cursor`; runtime apply performs no unplanned draw.
- Atomic start transaction with complete preflight, complete checkpoints,
  fixed apply order, reverse rollback, active-session isolation and
  `GameSessionRuntimeController` as the final business owner.
- Random AI roles resolve once, without replacement and in seat order. Starter
  monsters remain explicit, repeatable, and independent from roles.
- Main setup/new-game state and routes are physically removed.

## Transaction contract

1. Validate request, draft revision, active-session revision and catalogs.
2. Build a pure plan without mutating live RNG or runtime owners.
3. Preflight RNG, world, runtime domains and GameSession.
4. Acquire the RuntimeLoop barrier and capture every checkpoint.
5. Apply WorldSession, then runtime domains, then GameSession.
6. Commit the detached RNG cursor.
7. Release commit-only public log, visual, weather and presentation effects.
8. On any business failure, restore GameSession, runtime owners, WorldSession
   and RNG in reverse order before releasing the barrier.

Focused fault injection covers failure after checkpoints, world apply, runtime
apply, GameSession apply, RNG commit, and inside runtime composition after
infrastructure initialization. Every apply-stage failure restores the old
active session, RNG cursor, GameSession lifecycle, all runtime checkpoints and
card-supply presentation focus. Pre-apply failure crosses no Owner apply and
all failures release the RuntimeLoop barrier without publishing commit-only
side effects.

`commit_new_session_side_effects` now contains only presentation, public-log,
callout and derived-cache publication. Its checked receipt records zero RNG
draws and zero ProductMarket/Weather authority mutation. Weather and final
market state apply under the transaction barrier and participate in reverse
rollback before GameSession commits.

Every `SessionStartReceipt` receives the input request ID explicitly. Invalid,
missing-dependency, stale-draft, stale-session, collision, concurrent and
idempotently replayed failures retain that identity even before an operation
becomes active.

## Evidence

- `setup_session_start_transaction_cutover_test.gd`: 133/133 PASS.
- `session_envelope_save_owner_test.gd`: 93/93 PASS after migrating the formal
  four-player setup to the transaction.
- `full_run_quality_driver_contract_test.gd`: PASS after replacing the retired
  Main setup API with the formal transaction.
- `smoke_test.gd --check-only`: PASS.
- `main_gd_architecture_gate_test.gd`: PASS, 134 checks.
- `main_runtime_composition_test.gd`: PASS.
- Formal `main.tscn` short headless run: ExitCode 0, no script errors or
  warnings.

## Main budget

| Metric | Before | After |
| --- | ---: | ---: |
| Physical lines | 10,170 | 8,886 |
| Nonblank lines | 8,754 | 7,623 |
| Methods | 665 | 594 |
| Fields | 65 | 54 |
| Constants | 102 | 68 |
| Preloads | 9 | 8 |

## Explicitly not claimed

- `FULL_RUN_RESUME_CLAIM=false`.
- No setup save section was added.
- General gameplay action routing and remaining Main presentation glue are not
  part of this cutover.
- Historical layout and vertical-slice fixtures that intentionally encode the
  retired Main setup API require separate oracle migration; no compatibility
  wrapper is provided.
