# CommodityFlow Post-Commit Exact-Once Contract v0.6

## Authority gate

- `mechanic_id`: `commodity_flow_postcommit_exact_once_v06`
- Active rule sources:
  - `docs/tabletop_rulebook_v06.md`, sections 6.4 and 4
  - `docs/rules_v06_runtime_directive.md`, section 3
  - `docs/installed_commodity_continuous_economy_runtime_contract.md`
- Player-facing meaning: one consumed unit can change cash and GDP only once;
  retrying a committed sale cannot append another GDP observation, settle the
  same derivative twice, restart the same public pulse, or duplicate a cash
  history sample.
- Sale and flow owner: `CommodityFlowRuntimeController`.
- Post-commit consumption-lineage owner:
  `CommodityFlowPostCommitReceiptConsumer`.
- World-state owner: `WorldSessionState`.
- Derivative owner: `CityGdpDerivativeRuntimeController`.
- Presentation owner: `VisualCueRuntimeOwner`.
- Privacy: the durable journal is internal/save-only. Public diagnostics expose
  counts, cursor and stage names, never private receipt payload, supplier
  identity, rent recipients or player cash.
- Persistence: the consumer journal is nested inside the existing CommodityFlow
  save section. It is not a second game-save system.

## Production scene

The one production instance is:

```text
GameRuntimeCoordinator
├── CommodityFlowRuntimeController
├── CommodityFlowPostCommitReceiptConsumer
├── CommodityFlowWorldBridge
├── WorldSessionState
├── CityGdpDerivativeRuntimeController
├── VisualCueRuntimeOwner
├── BankruptcyNeutralEstateRuntimeController
├── PlayerManaRuntimeController
├── PublicLogProducerPort
└── TablePresentationRefreshScheduler
```

`CommodityFlowWorldBridge` may capture immutable world facts and atomically
apply validated cash/rent batches. It no longer binds Main and has no dynamic
post-commit callback.

## Frozen order

After cash/rent application and authoritative flow-plan commit, the consumer
preserves the previous observable order:

```text
for each affected district_index, ascending:
    GDP observation/history
    due GDP-derivative settlement
    public district pulse

for each player_index, ascending:
    private cash-history snapshot

bankruptcy checkpoint using bankruptcy:<batch_id>
asset recovery using asset-recovery:<batch_id>

for each non-empty committed batch:
    derive one privacy-safe typed public receipt
    append it once through PublicLogProducerPort
    set the existing LIVE presentation due bit once

finalize batch lineage and return completion receipt
```

An empty Sale Receipt batch advances the post-commit high-watermark with zero
observer work, zero public receipt, zero public-log append and zero presentation
invalidation. Its internal tail cursor advances directly to the terminal value
only to keep save validation deterministic.

The consumer coordinates bankruptcy and asset recovery through their existing
typed owners before terminal finalization. `RuntimeEconomyPort` owns no second
downstream path. Product-market and Victory advancement remain later in the
unchanged simulation order.

The terminal completion receipt is returned only after the consumer finalizes;
it is not broadcast through a synchronous signal. Bankruptcy uses the stable
transaction id `bankruptcy:<batch_id>` and the original settlement time, so the
existing Bankruptcy owner supplies its own exact-once replay boundary. The
public tail emits only an allowlisted `PublicLogReceipt`, then calls
`TablePresentationRefreshScheduler.request_immediate(LIVE_KIND)`. That call
sets the existing cadence owner's due bit; it does not apply UI, create another
scheduler, expose a route/commodity identity or bypass the typed presentation
source/target pipeline.

## Forward recovery

The consumer prepares and validates batch lineage before the cash/flow commit.
A rejected cash batch aborts that zero-progress preparation; once the sale
commits, every failure therefore has a pending or recovery-required record and
cannot silently fall through to a later batch.

Post-commit effects are not rolled back across owners. A committed sale is an
irreversible fact. The consumer therefore persists forward progress:

- stable batch id and sequence;
- canonical batch fingerprint;
- ordered receipt ids;
- affected districts;
- per-district GDP/derivative/pulse progress;
- durable per-target completion acknowledgements for every observer and
  downstream stage;
- per-player cash-snapshot progress;
- one deterministic, privacy-safe public receipt and its target acknowledgement;
- one idempotent LIVE presentation-invalidation acknowledgement;
- terminal receipt and high-watermark.

Each target also has a narrow idempotent boundary. WorldSessionState keeps
private batch-id, sequence and SHA-256 fingerprint bindings outside
player-facing records, derivative cash uses the existing stable position
transaction ids, and VisualCueRuntimeOwner uses a bounded runtime event-id
guard. Bankruptcy keeps its existing persistent transaction journal;
PlayerMana keeps a bounded persistent `advance_once` journal. The consumer
persists a target-completed acknowledgement before advancing its ordered stage,
so a save made in any target-success/caller-interruption window resumes without
restarting GDP, derivative, pulse, player-history, bankruptcy or asset-recovery
work. `PublicLogPresentationOwner` binds receipt identity to its fingerprint,
so the public-log target is also exact-once. The scheduler due bit is
idempotent; a cold-restored pending tail reasserts it without creating another
cadence or applying a target twice.

If a target succeeds but the caller is interrupted before marking progress, a
retry observes the target's idempotent receipt and only completes the caller
journal. Unknown payloads sharing an existing batch id fail closed.

Pending work blocks creation of the next CommodityFlow batch. When a pending
batch is recovered, that call returns the original batch identity and original
flow delta; it does not also create another batch. This preserves the old
batch's bankruptcy and asset-recovery checkpoint.

Production RuntimeLoop checks this pending fence before lifecycle, world-clock,
command, AI, timer, weather, monster or presentation work. A recovery-only frame
uses zero world delta. Success or failure returns immediately; only the
following frame may resume the unchanged normal order.

## Save and legacy load

New CommodityFlow saves include `postcommit_consumer`. Save preflight validates
the complete journal before live mutation. An explicit empty, truncated or
non-Dictionary section is malformed. With no pending record, the consumer
watermark must equal CommodityFlow `batch_sequence`; with a pending record, its
sequence must equal CommodityFlow and the completed watermark must be exactly
one behind. Pending batches restore with their exact progress and resume through
the early recovery fence.

The production `V06SaveOwnerRegistry` binding calls
`CommodityFlowRuntimeController.preflight_save_data`. That method creates a
fresh detached CommodityFlow owner and a fresh detached post-commit consumer,
applies and recaptures only on that probe, and returns the normalized candidate.
It never applies to the live owner or its scene-injected sibling and therefore
does not disguise rollback as preflight. The formal 19-section registry test
proves valid finalized and pending candidates, every cross-section rejection,
all 19 owner preflights, and zero live owner/consumer mutation.

The matching WorldSession target cursors travel through the formal
`SessionEnvelopeSaveOwner` / `WorldSessionEnvelopeCodec` path, not only through
an internal checkpoint. The codec accepts the older v0.6 envelope shape and
normalizes missing cursors to empty dictionaries. New-session application clears
the cursors because CommodityFlow batch numbering restarts from one. A cursor
ahead of a pending batch, or a same-sequence target binding with a different
batch id/fingerprint, is a cross-owner mismatch and fails closed; it is never
treated as an idempotent replay. Consumer-ahead bankruptcy or PlayerMana
lineage also fails closed after a torn cross-owner restore. Before any owner
apply, `V06SaveOwnerRegistry` runs the pure-data
`CommodityFlowPostCommitRestoreDependencyContract` across CommodityFlow,
Session, Bankruptcy and PlayerMana sections. It rejects finalized-consumer
ahead, target-ahead, fingerprint collision and invalid pending
caller-acknowledgement windows with zero live mutation.

The typed public receipt is durable inside the bounded consumer journal.
`PublicLogPresentationOwner` remains a transient projection rather than a
twentieth transactional Save Owner. A pending tail can rehydrate a missing
public-log binding from that durable receipt, but this Phase 1A cutover does not
claim that the complete finalized player-facing log history survives a cold
restore. Full presentation-history owner coverage belongs to the later Alpha
0.2 save/resume program; no second save system or compatibility Main path is
introduced here.

A v0.6 CommodityFlow save made before this cutover has no post-commit section.
Its saved `batch_sequence` becomes the explicit completed high-watermark because
the historical path invoked its callback synchronously before save. This is a
one-way compatibility read identified only by the canonical marker
`legacy_flow_batches_assumed_synchronously_completed`; any other non-empty
legacy marker is rejected. No Main callback is restored.

The durable journal retains at most 128 finalized records and, only while work
is pending, one additional pending record. `128 finalized + 1 pending` is a
valid recovery shape; terminal finalization immediately prunes the oldest
finalized record back to 128. A save containing 129 finalized records and no
pending batch is invalid and is rejected without changing live state.

## Failure policy

- Missing production consumer: flow fails closed before a new cash/flow commit.
- Target failure: the committed batch remains pending and later simulation
  phases do not run.
- Public-log failure or collision: the batch remains pending before presentation
  invalidation and finalization.
- Presentation invalidation failure: the batch remains pending after the public
  log acknowledgement and retries only the idempotent due bit.
- Fingerprint collision or invalid save: reject with zero new observer effects.
- Pending/recovery records are never pruned.
- Finalized records are bounded; an evicted old replay is rejected instead of
  being executed again.

Weather economic telemetry and FlowLoss signals remain non-authoritative
telemetry/presentation-adjacent emissions that occur once on the initial flow
commit. The durable exact-once claim in this contract covers the GDP/history,
derivative, district pulse, cash-snapshot, bankruptcy and asset-recovery chain
named above. Cash/rent batch
application retains its existing WorldBridge guard; persisting that bridge's
own crash-window lineage is a separate boundary.

## Acceptance evidence

- `res://tests/commodity_flow_postcommit_exact_once_test.gd`
- `res://tests/commodity_flow_postcommit_recovery_integration_test.gd`
- `res://tests/commodity_flow_postcommit_formal_envelope_test.gd`
- `res://tests/commodity_flow_postcommit_downstream_checkpoint_test.gd`
- `res://tests/commodity_flow_postcommit_restore_dependency_contract_test.gd`
- `res://tests/commodity_flow_postcommit_registry_preflight_test.gd`
- `res://tests/public_log_presentation_owner_save_test.gd`
- `res://tests/commodity_flow_backlog_save_roundtrip_v06_test.gd`
- `res://tests/v06_save_owner_registry_test.gd`
- `res://tests/table_presentation_query_ports_cutover_test.gd`
- `res://scenes/tools/CommodityFlowPostCommitExactOnceBench.tscn`
- `res://tests/main_runtime_composition_test.gd`
- `res://tests/main_gd_architecture_gate_test.gd`
- `res://tests/bankruptcy_neutral_estate_save_owner_transaction_test.gd`
- `res://tests/player_mana_save_owner_transaction_test.gd`
