# Region Infrastructure Atomic Lifecycle v0.6 Contract

## Ownership

`RegionInfrastructureRuntimeController` is the single owner of the public facility roster, stable slot mapping, slot generations, region damage, and facility action lifecycle journal. `CardFlowTransactionServiceV06` owns card/player-state staging. `PlayerManaRuntimeController` remains the only six-color asset owner.

No card adapter, UI, bridge, or transaction wrapper may maintain a second facility roster or compensating facility formula.

## Facility action state machine

```text
request
  -> full validation
  -> copy-state apply
  -> applied (committed=true, rollback_open=true)
       -> rollback -> rolled_back (terminal)
       -> finalize -> finalized (terminal)
       -> failed rollback/finalize -> remains applied
```

`applied` is an authoritative committed owner fact. A failed player-state commit must request rollback. A successful player-state commit must request finalize. Neither failure is allowed to erase the original committed receipt or close the rollback window.

The same `transaction_id` and binding replay the existing receipt. A different intent under the same ID fails with `facility_action_transaction_binding_mismatch`.

## Atomic mutation

Before rollback or finalize, the controller validates:

- transaction and receipt kind;
- owner binding and binding fingerprint;
- region, facility, slot, generation, region revision, and controller revision;
- complete `facility_before`, `region_before`, slot mapping, and generation preimage;
- current state still matching the committed postimage.

Only after all checks pass does it build copied dictionaries for regions, facilities, slot mappings, generations, receipts, and lifecycle records. State is replaced through one swap. Any rejection leaves world state, revision, receipt sequence, and journal byte-for-byte unchanged.

Build rollback removes the new facility and restores the prior region and generation. Upgrade rollback restores the previous facility record. Repair rollback restores the exact previous damage. Revisions remain monotonic and terminal receipts are exact-once.

## Finalization and checkpoint

`finalize_facility_action()` closes the rollback window only when the owner returns `finalized=true`. The preimage is then cleared. A later rollback returns `facility_action_rollback_closed` without changing the facility.

`facility_action_checkpoint_status()` blocks normal checkpoints while any facility action is `applied`, or while journal integrity is invalid. Open records are nevertheless serialized so controlled recovery and QA round-trips can inspect and retry them. The outer commodity-card controller also blocks checkpoint while a committed core-card result lacks explicit owner finalization.

Replaying the same public card action retries only finalization. It does not re-read the now-empty hand slot and does not repeat card, asset, cash, or facility mutation.

## Public API

- `apply_facility_action(request: Dictionary) -> Dictionary`
- `rollback_facility_action(receipt_or_transaction: Variant) -> Dictionary`
- `finalize_facility_action(receipt_or_transaction: Variant) -> Dictionary`
- `facility_rollback_atomic_ready() -> bool`
- `facility_action_capabilities() -> Dictionary`
- `facility_action_checkpoint_status() -> Dictionary`
- `facility_action_lifecycle_snapshot(transaction_id := "") -> Dictionary`
- `to_save_data() -> Dictionary`
- `apply_save_data(data: Dictionary) -> Dictionary`

String transaction IDs remain accepted by rollback/finalize for the frozen facility adapter. Production routing must obtain that ID from the CardFlow prepare association; arbitrary UI callers are not authorized mutation owners.

## Save/load

State version remains v0.6 envelope version `1`; facility lifecycle schema is independently versioned as `2`. Saves include:

- owner roster and region state;
- slot mappings derived and validated from the roster;
- slot generations and tombstones;
- transaction receipts;
- full pending/terminal lifecycle records;
- binding fingerprints, preimage/postimage, rollback state, and receipt sequence.

Load validates the complete candidate state before replacing live state. Missing preimages, mismatched journals, invalid slot mappings, damaged bindings, regressed receipt sequences, and unrecoverable open associations fail closed with zero side effects.

Legacy v0.6 state-version-1 snapshots without lifecycle-v2 data load their processed transaction IDs as closed exact-once guards. They cannot reopen historical rollback windows.

## Production facility-card gate

`CommodityCardInventoryRuntimeController` permits `build_upgrade_or_repair_facility` only when the owner exposes apply, rollback, finalize, checkpoint, and measured readiness. Missing capabilities retain `facility_rollback_atomicity_unavailable` and change no player or owner state.

The production route is:

```text
CardFlow reserve
-> facility adapter prepare
-> RegionInfrastructure apply
-> player card/asset commit
-> owner finalize
-> CardFlow terminal receipt
```

If player commit fails, the same association routes rollback. If rollback fails because another legitimate owner transaction advanced the state, CardFlow reports `effect_compensation_failed`; it must not claim success or fabricate compensation.

## Frozen behavior

This sprint does not change facility HP, rank limits, unique slots, terrain rules, card costs, six-color asset values, card data, commodity algorithms, or economic formulas.
