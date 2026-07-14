# Agent A Handoff: SS06-09 Region Infrastructure Atomic Lifecycle

## Outcome

SS06-09 is focused-complete. `RegionInfrastructureRuntimeController` now owns a lifecycle-v2, exact-once facility transaction journal for build, upgrade, and repair. Public facility cards are unlocked only when apply, rollback, finalize, checkpoint, save-load, and journal integrity are present. Missing capability remains fail-closed with `facility_rollback_atomicity_unavailable`.

No facility values, card data, economic formulas, UI layout, `main.gd`, Coordinator composition, B/C files, or default player saves were changed.

## State machine

```text
validated request
  -> copy-state apply
  -> applied / committed / rollback_open
       -> rollback -> rolled_back terminal receipt
       -> finalize -> finalized terminal receipt
       -> failure -> remains applied, committed, retryable, checkpoint-blocking
```

Rollback and finalize preflight transaction/receipt kind, owner binding and fingerprint, region/facility/slot/generation, region and controller revision, postimage, and complete preimage. Only then are copied dictionaries swapped into the owner. Rejections leave world state, revisions, receipt sequence, and journal unchanged.

## Modified files

- `scripts/runtime/region_infrastructure_runtime_controller.gd`
- `scripts/runtime/commodity_card_inventory_runtime_controller.gd` (minimal lifecycle boundary only)
- `scenes/runtime/RegionInfrastructureRuntimeController.tscn`
- `tests/region_infrastructure_atomic_lifecycle_v06_test.gd`
- `tests/facility_card_production_unlock_v06_test.gd`
- `scenes/tools/RegionInfrastructureAtomicLifecycleV06Bench.tscn`
- `scripts/tools/region_infrastructure_atomic_lifecycle_v06_bench.gd`
- `docs/region_infrastructure_atomic_lifecycle_v06_contract.md`
- `reports/runtime/region_infrastructure_atomic_lifecycle_v06/validation.md`
- this handoff

`scripts/runtime/commodity_card_effect_runtime_bridge.gd` did not require a change. `scripts/cards/v06/**`, `GameRuntimeCoordinator.*`, and `scripts/main.gd` were not modified.

## Stable APIs

Region owner:

- `apply_facility_action(request)`
- `rollback_facility_action(receipt_or_transaction)`
- `finalize_facility_action(receipt_or_transaction)`
- `facility_rollback_atomic_ready()`
- `facility_action_capabilities()`
- `facility_action_checkpoint_status()`
- `facility_action_lifecycle_snapshot(transaction_id := "")`
- `to_save_data()` / `apply_save_data(data)`

Card source boundary:

- `checkpoint_status()` reports committed effects that still need owner finalization.
- Replaying the same `play_core_card` transaction retries only finalization before returning the terminal replay.
- Successful authoritative fallback finalization closes the frozen Router prepare association without adding a second effect owner.

## Atomicity evidence

- Build rollback removes only the newly built facility and restores region/generation preimage.
- Upgrade rollback restores the exact prior rank record.
- Repair rollback restores exact prior damage.
- Player-state commit failure rolls the owner back and leaves card/assets unchanged.
- If another legitimate owner transaction advances state, rollback reports compensation failure and performs no partial erase.
- Finalize failure preserves committed receipt, rollback window, and retry path; checkpoint remains blocked.
- Finalize success clears preimage, closes rollback, and replays exact-once.
- Pending and terminal journal records survive save-load; malformed snapshots fail before state replacement.
- Legacy v0.6 state-version-1 processed IDs load as closed exact-once guards.

## Focused validation

| Suite | Result |
|---|---|
| Region Infrastructure Atomic Lifecycle | PASS, 70/70 |
| Facility Card Production Unlock | PASS, 60/60 |
| Task-owned parse-load Bench | PASS, 12/12 |

Full command and concurrency evidence: `reports/runtime/region_infrastructure_atomic_lifecycle_v06/validation.md`.

Cross-owner assertion totals printed 620/620, but the Coordinator-loading process also encountered Agent B's active `monster_runtime_controller.gd` parse gap (`_monster_card_dependency_matrix_v06` missing). This is not claimed as clean global acceptance. Final MCP, headed screenshot, composition, and vertical-slice acceptance are delegated to the coordination thread.

## Unique owner graph

```text
CardFlowTransactionServiceV06
  -> CardPlayerStateProductionAdapterV06 (card/cash delta staging)
  -> PlayerManaRuntimeController (six-color assets)
  -> CoreEconomicCardEffectRouterV06
  -> FacilityCardEffectAdapterV06
  -> RegionInfrastructureRuntimeController (only facility mutation owner)
```

The inventory boundary supplies lifecycle fallback because the frozen facility adapter has no finalize API. It does not own facilities and creates no second transaction service.

## Remaining risks / next dependency

1. Agent B and C hot files must parse cleanly before Coordinator and vertical-slice acceptance.
2. The frozen SS06-06 Bench contains an intentionally stale fail-closed facility assertion. Use the SS06-09 Bench as the new oracle; do not reintroduce the defect.
3. The production save coordinator should consume `checkpoint_status()` during VS06-A composition. This sprint exposes the gate but did not modify Coordinator under its frozen boundary.
4. Direct callers that bypass the production inventory boundary can leave an applied facility lifecycle open. Production code should route real facility cards through the single CardFlow path.

## Lessons for other agents

- **Invariant:** owner mutation is not transaction-complete until explicit rollback or explicit `finalized=true` closes the prepare association.
- **Failed approach:** treating method presence, a committed receipt, or an internal finalize attempt as proof that the outer transaction is terminal.
- **Stable API:** `facility_action_checkpoint_status()` plus lifecycle-v2 receipt/save data are the authoritative readiness surface.
- **Test oracle:** compare complete owner save fingerprints before and after every rejected rollback/load; any revision or journal change is a failure.
- **Integration trap:** a frozen adapter may implement rollback but not finalize. Finalizing the owner without clearing the Router association leaves a hidden inflight record.
- **Reusable pattern:** full preflight -> copied next state -> one swap -> terminal receipt; replay reads the journal before current hand/world validation.
- **Stale evidence:** the old `facility_effect_fail_closed_until_atomic_rollback` case describes the pre-SS06-09 defect and must not drive production behavior.
- **Next dependency:** VS06-A production composition must wire the checkpoint participant and prove one real menu-to-table facility transaction after B/C parsing stabilizes.

## Repository state

No `git add -A`, commit, push, merge, reset, clean, or destructive command was used. QA output remains under `user://`.
