# Alpha 0.4-C Queueable Facility Bridge Handoff

> Historical pre-attestation record only. The later trusted
> `ChildCompletionAttestationV1` / `ParentExitAttestationV1` repair established
> that this wrapper failure started no Process A, wrote no Save, and created no
> official ledger. Current authority is
> `reports/handoffs/alpha04c_save_resume_current.json`: official count remains
> `0` and the conditional authorization is unconsumed. The values below preserve
> what the old wrapper reported; they must not be used as current gate evidence.

```text
STATUS=ALPHA_0_4_C_P0_QUEUEABLE_FACILITY_ACTION_BRIDGE_AND_COLD_RESTORE_CLOSURE_PARTIAL
SOURCE_PR=77
SOURCE_HEAD=a55b938f41402be2f3eb510300c483de5ae09458
EFFECTIVE_BASE_SHA=a55b938f41402be2f3eb510300c483de5ae09458
IMPLEMENTATION_COMMIT=4796c1e1d77c844baf12245dfa449b7c585c5de4
OFFICIAL_ATTEMPT_HEAD=ab6f6d8ceed92824b864dc54be628ffd3c262b59
HISTORICAL_UNTRUSTED_WRAPPER_REPORTED_COUNT=1
CURRENT_OFFICIAL_COLD_RESTORE_VERTICAL_SLICE_COUNT=0
OFFICIAL_COLD_RESTORE_FAILURE_CLASS=HARNESS_FAILURE
OFFICIAL_FAILURE_CODE=driver_contract_preflight_process_failed
MERGE_TO_MAIN_ALLOWED=false
PR77_DRAFT=true
```

## Production result

V0.6 facility cards now follow the one production route:

```text
GameActionOfferV1 -> GameActionIntentV1
-> TablePlayerActionApplicationFlowController
-> capability-bound FacilityCardQueueAdapterV06
-> CardResolutionQueueRuntimeService
-> CardResolutionExecutionRuntimeService
-> RegionInfrastructureRuntimeController
```

Submission reserves mana, moves the exact card instance to committed escrow,
binds the target, and creates a saveable Queue entry. The next authorized card
resolution phase applies the existing facility owner command. There is no
caller-facing Coordinator submit facade and no legacy direct fallback.

Focused tests proved Queue schema, escrow and mana rollback, mixed-Queue
selection, execution retry restore, exact-once history, AI/human shared routing,
and direct-path closure. Save remains the existing 19-section v3/v0.6 envelope;
Main, RNG ownership/draw points, AI policy, and gameplay values are unchanged.

## Qualification

The non-official qualification used depth 1, seed 900626424, one local player,
and three AI players. It completed with:

```text
commodity_action_count=1
normal_card_purchase_count=51
facility_action_count=1
sale_receipt_count=1
ai_action_count=3
ai_state_fingerprint_changed=true
queue_trigger_actor=local
queue_trigger_semantic_action_id=card.play
queue_trigger_card_semantic_id=facility.factory.energy.rank_1
queue_count=1
card_resolution_advance_after_trigger=0
world_advance_after_trigger=0
rng_draw_after_trigger=0
save_written=false
success=true
```

## Official attempt

The one authorized invocation was made from a clean, pushed
`ab6f6d8ceed92824b864dc54be628ffd3c262b59`. The driver contract preflight
printed one valid schema-v4 contract with `execution_ready=true`; the
orchestrator then rejected its wrapper/engine exit-code assertion with
`driver_contract_preflight_process_failed`.

Process A, B, and C did not start. No Save was written, the shared official
claim ledger was not created, and task-owned Godot process count returned to
zero. The invocation is nevertheless treated as the consumed official attempt.
Readiness is latched false and the chain must not be retried without a new
explicit authorization.

The next blocker boundary is
`ALPHA_0_4_C_OFFICIAL_PREFLIGHT_WRAPPER_EXIT_ATTESTATION_REPAIR`. PR #77 remains
Draft and may not merge. After a newly authorized cold-restore chain is green,
the planned product boundary remains
`ALPHA_0_5_A_V07_COMPLETE_CONSTITUTION_AND_THREE_WING_SEMANTIC_KERNEL`.

## Deferred commodity direction

```text
CURRENT_TASK_INTERRUPTED=false
NEW_RULE_DIRECTION_RECORDED=true
RUNTIME_CUTOVER_PERFORMED=false
SHARED_COMMODITY_TRACK_PLANNED=true
PUBLIC_STANCES_HIDDEN_WEIGHTS_PLANNED=true
FIXED_HIDDEN_LEAD_ORDER_PLANNED=true
ALTERNATING_REVERSE_MACRO_ROUNDS_PLANNED=true
SEPARATE_COMMODITY_HAND_PLANNED=true
COMPLETE_MACRO_ROUND_END_GATE_PLANNED=true
NEXT_IMPLEMENTATION_PHASE=PHASE_A_RULE_AND_SEMANTIC_FREEZE
```

The candidate V0.7 direction remains a shared, partially visible commodity
track with 180-second cycles, public revealed stances, hidden 3/6-point weights,
a fixed hidden snake lead order, separate five-slot commodity inventory, linear
level 1-4 accumulation, and end validation only at a complete macro-round
boundary. This task made no runtime rule, Save schema, or production cutover for
that direction. The main conflicts to resolve later are the current shared
normal/commodity hand limit, current supply/track visibility model, immediate
end transition, and the absence of the proposed macro-round lead-order owner.
