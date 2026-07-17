# Card Execution Typed Ports Cutover

Status: **complete; transition sink cut over with persisted exact-once lineage**

Branch: `codex/scene-first-remove-main-gd`

## Purpose

This prerequisite removes the dynamic `Main` dependency from card execution before the card-frame transition sink is retried. It does not install a transition sink and does not claim that the 12 frame-transition commands have moved out of `Main`.

## Production owners

`GameRuntimeCoordinator.tscn` now composes exactly one instance of each narrow owner:

- `CardPlaySubmissionRuntimeController`: common human/AI admission API and target-choice handoff;
- `CardResolutionExecutionWorldBridge`: historical scene name retained, but implementation is now a typed execution port with no `Main` reference;
- `CardEffectRuntimeRouter`: field/kind-driven dispatch to existing monster, military, weather, contract, hand-interaction, economy and intel owners;
- `CardCounterSettlementRuntimeService`: typed counter lookup and settlement boundary;
- `CardCommitmentRuntimeService`: one-shot/persistent commitment, cooldown and play-cost finalization;
- `CardResolutionHistoryRuntimeService`: exact-once resolved-history owner with save/load and public/private projections;
- `CardResolutionPresentationPort`: allowlisted public card event and overlay projection;
- `CardIntelRuntimeService`: private intel mutation through typed session/history/contract dependencies.

`TableSelectionState` additionally owns `selected_card_resolution_id`.

## Removed dynamic Main boundary

The baseline execution bridge contained 35 literal dynamic access sites:

| access | before | after |
|---|---:|---:|
| `world.call(...)` | 27 | 0 |
| `world.get(...)` | 1 | 0 |
| `world.set(...)` | 5 | 0 |
| `world.get_node_or_null(...)` | 2 | 0 |
| total | 35 | 0 |

The new execution port receives typed dependencies during coordinator composition and never receives, discovers or reflects `Main`.

## Submission boundary

Human hand activation calls `GameRuntimeCoordinator.request_hand_card_play`. Human target-choice completion and AI decisions call `GameRuntimeCoordinator.submit_card_play`. Both APIs delegate to the same production `CardPlaySubmissionRuntimeController` instance.

The legacy `Main._use_skill` and `Main._queue_skill_resolution` methods were physically deleted. AI no longer calls the former world callback.

## Cost and failure semantics

This cutover freezes the following current rule:

1. **Submission is commitment.** A one-shot card is removed when its anonymous queue submission commits.
2. **Play cash is paid on queue admission.** The queue entry records `play_cost_paid_on_queue=true`.
3. Countered cards and cards whose requirement or target later becomes invalid are not returned.
4. Final commitment never charges queue-paid cash a second time.
5. Persistent cards remain in their slot and receive their normal cooldown during final commitment.

This is Rule A plus the queue-payment interpretation of Rule B: the player pays for reserving and revealing the action, not only for a successful world effect. It preserves anonymous queue fairness and prevents risk-free speculative submissions.

## Privacy boundary

Resolved history has three explicit views:

- internal authoritative history;
- public history with allowlisted card/result fields only;
- viewer history, which adds private binding fields only for that card's own player.

The production card track consumes the viewer projection instead of raw history. Public presentation strips player index, slot, cash, hand/discard, hidden owner and AI policy metadata. Ownership appears only after an explicit public reveal label exists.

## Transition sink completion

The follow-up transition change adds one scene-owned `CardResolutionTransitionSink` between the frame driver and the typed execution/presentation ports. `Main` no longer receives a command array, switches on transition kinds, or drives completion. All twelve command kinds carry deterministic command IDs, batch revisions, contiguous order indices and payload fingerprints. Applied lineage is bounded, saved, restored and checked before replay.

The typed ports and transition sink do not create a second queue, world state, cash owner, card inventory or presentation layout owner. The production table remains the temporary visual target; moving that source/target boundary is the next independent cutover.

## Acceptance evidence

- `tests/card_execution_typed_ports_cutover_test.gd`
- `tests/card_resolution_history_runtime_service_test.gd`
- `scenes/tools/CardExecutionTypedPortsBench.tscn`
- `scenes/tools/CardResolutionHistoryRuntimeServiceBench.tscn`
- `tests/main_runtime_composition_test.gd`
- `tests/card_resolution_transition_command_lineage_test.gd`
- `tests/card_resolution_transition_sink_cutover_test.gd`
- `tests/card_resolution_transition_gameplay_fault_injection_test.gd`
- `tests/card_resolution_transition_persistence_registry_test.gd`
- `scenes/tools/CardResolutionTransitionSinkBench.tscn`
- `tools/architecture/check_main_gd_budget.py --json`

The next task is `Table Presentation Source/Target Cutover`. It must consume the public presentation port without restoring a Main callback or changing card execution ownership.
