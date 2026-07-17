# Card Resolution Transition Sink Cutover

Status: **cut over**

## Result

`CardResolutionFrameDriver` now sends each deterministic frame batch directly
to the unique scene-owned `CardResolutionTransitionSink`. The driver returns a
high-level receipt to `GameRuntimeCoordinator`; neither the coordinator nor
`Main` receives the command array.

The sink supports exactly these twelve transition kinds:

1. `show_active`
2. `begin_counter`
3. `complete_active`
4. `start_next`
5. `show_group_window`
6. `enter_public_bid`
7. `enter_lock`
8. `all_ready_public_bid`
9. `all_ready_lock`
10. `all_ready_lock_batch`
11. `lock_batch`
12. `hide_overlay`

Gameplay mutations route only through the typed execution port. Public visual
state routes only through `CardResolutionPresentationPort`; the sink does not
discover a UI node or `Main`.

## Ordering and exact-once lineage

The producer attaches a schema version, transition kind, phase, batch
revision, contiguous order index, deterministic command ID, payload
fingerprint, window sequence and privacy-safe resolution identity. A whole
batch is validated before its first side effect.

Applied command lineage is bounded to 256 entries and is included in the
controller checkpoint. The registered `card_resolution_execution` save owner
atomically captures and restores that checkpoint together with completed
identities, full resumable in-flight transactions and pending settlement
records. Save schema v3 binds each pending settlement to its resolution ID,
execution ID, outcome fields and deterministic fingerprint. The registry uses
the live owner's pure
`preflight_save_data` path, so preflight retains the bound controller instead
of validating a detached duplicate that has lost its sibling reference. Exact
ID/fingerprint replay is a no-op success; structurally invalid, duplicate,
reordered, stale or cursor-mismatched checkpoint input fails closed before
either state owner mutates.

This proves the `card_resolution_execution` section contract and its atomic
preflight/apply/rollback round trip. It does **not** claim that a complete v0.6
run can currently be resumed: seven unrelated save sections remain
unsupported and the global save envelope correctly stays fail-closed until
their owners are migrated.

The producer test freezes sixteen complete ordered traces, including the empty
trace and the large-delta multi-phase trace. Fault injection covers failure
before dispatch, after the handler but before lineage finalization, during
history append and during the final mana settlement. Save/load resumes only the
unfinished intent: it never releases the card, dispatches the effect or writes
history twice. Corrupt duplicate/reordered intents, contradictory flags,
forged settlement bindings and receipts for another execution all fail closed.
Legacy v1 data migrates to a canonical empty transition checkpoint instead of
inheriting the live controller's command lineage.

## Removed Main path

The following Main methods are physically deleted:

- `_apply_card_resolution_controller_transition`
- `_complete_active_card_resolution`
- `_start_next_card_resolution`
- `_lock_card_resolution_batch`
- `_finish_card_resolution_batch`
- `_promote_next_card_resolution_batch`
- `_announce_card_counter_response_window`
- `_begin_card_counter_response_window`
- `_clear_queued_card_flag`
- `_reset_card_resolution_batch_state`
- `_card_resolution_execution_request`

`Main._process` performs one high-level coordinator advance and contains no
transition loop or switch. This is not the final RuntimeLoop cutover.

## Privacy

Public transition receipts are allowlisted. They exclude player-private cash,
hand/discard state, target-player bindings, hidden owner identities, private AI
plans, learning metadata and decision samples. The sink never publishes its
internal execution receipt to the player-facing port.

## Evidence

- `tests/card_resolution_transition_command_lineage_test.gd`: 245 checks
- `tests/card_resolution_transition_sink_cutover_test.gd`: 70 checks
- `tests/card_resolution_transition_gameplay_fault_injection_test.gd`: 61 checks
- `tests/card_resolution_transition_persistence_registry_test.gd`: 12 checks
- `tests/card_resolution_runtime_controller_test.gd`: 26 checks
- `tests/card_execution_typed_ports_cutover_test.gd`: 42 checks
- `tests/main_gd_architecture_gate_test.gd`: 45 checks
- `tests/main_runtime_composition_test.gd`: pass
- `tests/v06_save_owner_registry_test.gd`: 10 checks
- `scenes/tools/CardResolutionTransitionSinkBench.tscn`: 7 checks

`ui_text_smoke_test.gd`, `visual_snapshot.gd`, and
`smoke_test.gd --check-only` pass. The legacy full-smoke fixture is not a valid
oracle for this cutover yet: `_summon_starting_monsters_for_smoke` and later
sections still call the physically retired `Main._use_skill` /
`Main._queue_skill_resolution` entry points. It therefore stops before the
new transition section is reached. The old layout/AI fixtures contain the same
class of stale Main assertions. No compatibility fallback was restored; those
fixtures must be migrated to `CardPlaySubmissionRuntimeController` in their
own test-migration change.

## Next boundary

The next task is **Table Presentation Source/Target Cutover**. It will replace
the remaining Main-owned table/map presentation receipt consumption. It must
not alter these command, execution, exact-once or save owners.
