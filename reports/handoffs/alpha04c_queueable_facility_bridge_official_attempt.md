# Alpha 0.4-C Queueable Facility Bridge Handoff

This is the current authoritative record for the queueable-facility task. The
earlier pre-attestation wrapper failure is superseded by the trusted attempt
below.

```text
STATUS=ALPHA_0_4_C_P0_QUEUEABLE_FACILITY_ACTION_BRIDGE_AND_COLD_RESTORE_CLOSURE_PARTIAL
SOURCE_PR=77
SOURCE_HEAD=a55b938f41402be2f3eb510300c483de5ae09458
EFFECTIVE_BASE_SHA=fce3edffd96ffc2eb4b110d5a27dfe203fd2c06d
TESTED_SOURCE_HEAD=ca3b7cf4222a6145bed81606fc4f04b7076ae0d9
IMPLEMENTATION_COMMIT=ca3b7cf4222a6145bed81606fc4f04b7076ae0d9
OFFICIAL_COLD_RESTORE_VERTICAL_SLICE_COUNT=1
OFFICIAL_FAILURE_CLASS=HARNESS_TIMEOUT
OFFICIAL_FAILURE_CODE=producer_child_process_timeout
MERGE_TO_MAIN_ALLOWED=false
PR77_DRAFT=true
```

## Production result

V0.6 facility cards now follow one production route:

```text
GameActionOfferV1
-> GameActionIntentV1
-> TablePlayerActionApplicationFlowController
-> CardPlaySubmissionRuntimeController
-> capability-bound FacilityCardQueueAdapterV06
-> CardResolutionQueueRuntimeService
-> CardResolutionExecutionRuntimeService
-> RegionInfrastructureRuntimeController
```

Submission reserves the activation assets, moves the exact card instance into
committed escrow, freezes the target, and appends one saveable Queue entry.
Only a later authorized resolution step calls the existing facility authority.
The direct facility-card resolution route count is zero and the facility Queue
submission route count is one.

Delivery recovery is fail closed. An unresolved post-commit delivery is kept as
`delivery_recovery_pending`; a retry must use the same request and fingerprint.
A forged rollback receipt cannot release Queue, reservation, or escrow.
`consumed_finalized` is terminal and idempotent. These changes add no Main
responsibility, Save section, RNG owner/draw point, AI policy, or facility value
change.

## Trusted qualification

The one non-official qualification ran from clean, pushed
`ca3b7cf4222a6145bed81606fc4f04b7076ae0d9` with depth 1, seed
`900626424`, one local player, and three AI players.

```text
child_completion_attestation_green=true
parent_exit_attestation_green=true
wrapper_exit_attestation_green=true
product_queue_qualification_green=true
commodity_action_count=1
normal_card_purchase_count=51
facility_action_count=1
sale_receipt_count=1
ai_action_count=3
ai_state_fingerprint_changed=true
queue_trigger_actor=local
queue_trigger_semantic_action_id=card.play
queue_trigger_card_semantic_id=facility.factory.energy.rank_1
queue_trigger_target_fingerprint=fd8d673849aad872ef5c85bcefda9ac2c3423d2d55b0d1f041de8a2e96d38357
queue_count=1
queue_revision=6
card_resolution_advance_after_trigger=0
world_advance_after_trigger=0
rng_draw_after_trigger=0
rejected_offer_count=0
save_written=false
task_owned_process_count_after=0
```

This proves a real production facility card survives the submission call in the
authoritative Queue without direct facility mutation or Queue injection.

## Official attempt

The fixed claim at
`<git-common-dir>/codex/cold_restore_v3/official-alpha04c-depth1-seed900626424/official_claim_ledger.json`
was created exactly once and permanently records the `0 -> 1` transition.
It binds run `alpha04c-facility-bridge-ca3b7cf4`, the tested HEAD, and scenario
fingerprint
`0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf`.

Process A launched with a valid capability-bound launch attestation. At the
60-second parent timeout it wrote a 624,083-byte V0.6 Save file with SHA-256
`658e956eb68a51294ca2254759119e78f5c4ba69ee1be7444b1114446496255c`.
The write occurred at the timeout boundary, before Process A could publish its
child completion attestation or allowlisted manifest. The parent therefore
terminated the wrapper and recorded:

```text
observed_exit=true
timed_out=true
terminated_by_parent=true
child_attestation_found=false
child_attestation_valid=false
task_owned_process_count_after=0
wrapper_reason_code=child_process_timeout
```

The file's existence is diagnostic evidence only. It is not an accepted
Process A Save, and no cold-restore claim is made from it. Process B and Process
C did not start. The official chain must not be retried without a new explicit
authorization.

## Verification

Focused suites remained green:

```text
APPLICATION_FLOW=63/63
FACILITY_PRODUCTION_FAULT_PARITY=110/110
ESCROW=54/54
MANA_RESERVATION=109/109
RESTORE_DEPENDENCY=146/146
DIRECT_FACILITY_CLOSURE=170/170
PRODUCTION_REGISTRY=52/52
SAVE_REGISTRY=12/12
SAVE_ENVELOPE=62/62
ROUTE_MILITARY_DEPENDENCY=54/54
HISTORY_SAVE=58/58
SESSION_ENVELOPE=110/110
FORK_PARITY=14/14
FACILITY_ADOPTER=16/16
AI_ACTION_SPINE=14/14
AI_PRODUCTION_PORT=33/33
CLAIM_TO_SALE=20/20
TRANSITION_FAULT=61/61
FINAL_SETTLEMENT_PRIVACY=31/31
SMOKE_CHECK_ONLY=PASS
GODOT_MCP_SCRIPT_ERRORS=0
GODOT_MCP_RUNTIME_ERRORS=0
TASK_OWNED_GODOT_PROCESS_COUNT_AFTER=0
```

A mistaken `-- --check-only` invocation began the legacy Smoke body and was
terminated after it exceeded 60 seconds. It did not complete and did not alter
Formal or official counts. The corrected engine `--check-only` run passed.
No third Formal FullRun or completed full Smoke was run.

Godot MCP opened the real `main.tscn`, confirmed one production instance each
of the Queue, execution, facility adapter, and application-flow services,
observed a real facility rack transition between available and sunlight-blocked
states, found zero console errors, and stopped cleanly. The accelerated visual
session reached Final Settlement before an MCP-only hand submission could be
captured; the trusted qualification is the authoritative nonempty-Queue proof.

## Delivery boundary

The queueable facility bridge and trusted qualification are ready on the remote
bridge branch, but Alpha 0.4-C remains PARTIAL. PR #77 stays Draft and must not
merge to main until a newly authorized chain proves Process A completion,
Process B restore/continuation, Generation 2 Save, Process C restore,
FinalSettlement exact-once, and terminal quiescence.

The next exact task is:

`ALPHA_0_4_C_OFFICIAL_PROCESS_A_60S_TIMEOUT_DIAGNOSIS_AND_REAUTHORIZED_COLD_CHAIN`

V0.7 runtime implementation remains deferred until Alpha 0.4-C is genuinely
GREEN.
