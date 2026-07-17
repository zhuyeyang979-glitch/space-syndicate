# Card Execution Typed Ports Cutover

Status: **typed ports complete; transition sink still blocked pending its own atomic cutover**

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

## Deliberately not completed here

The card-frame transition sink remains a separate atomic change. `Main` still receives the current frame command array and temporarily calls the coordinator's typed `execute_active_card_resolution` entry. The next sink task must add producer-owned command IDs/revisions/order, persistent applied-command lineage, full 12-kind order tests and removal of the remaining transition switch/wrapper.

The typed ports do not create a second queue, world state, cash owner, card inventory or presentation layout owner.

## Acceptance evidence

- `tests/card_execution_typed_ports_cutover_test.gd`
- `tests/card_resolution_history_runtime_service_test.gd`
- `scenes/tools/CardExecutionTypedPortsBench.tscn`
- `scenes/tools/CardResolutionHistoryRuntimeServiceBench.tscn`
- `tests/main_runtime_composition_test.gd`
- `tools/architecture/check_main_gd_budget.py --json`

The Transition Sink Cutover may now be retried against these typed boundaries, but it must remain red until the command/exact-once gates in its own specification pass.
