# V0.7.5 Legacy Reachability Audit From Resume

Audit owner: Lane F
Audit scope: static production reachability, legacy retirement, guard/bound-action remnants, placeholder count, and existing MCP/runtime evidence.
Audit mode: read-only. This lane changed no production file and did not start a validation suite.

## Verdict

    CURRENT_TASK_ID=ALPHA_0_5_C2_V075_MONSTER_AUTONOMY_PRIVATE_INSTANT_SKILLS_AND_MILITARY_ASSAULT_MISSIONS_PRODUCTION_CUTOVER
    CURRENT_RULESET_ID=v0.7.5
    CURRENT_CONSTITUTION_ID=space_syndicate.v075.complete
    CURRENT_TASK_STATUS=PARTIAL
    STAGE_B_V076_ALLOWED=false
    STAGE_B_BLOCK_REASON=current V0.7.5 is not GREEN, has no merged PR/tag, and the worktree is not clean

The old Monster and Military controllers are not reachable from the V0.7.5
production scene graph. They are still present as V0.6 semantic inventory,
legacy scenes, and characterization/compatibility references. That is a
retirement follow-up, not evidence of a V0.7.5 dual runtime writer.

The current V0.7.5 implementation does, however, still route military card
selection through the anonymous public batch path. This is visible in the
active runtime and UI (normal_public_batch) and is the forward-compatibility
item recorded as superseded_by_v076_direct_intervention.

## Audit Snapshot

    WORKTREE=C:/Users/zhuye/Documents/New project/space-syndicate-v075-monster-military-combat-bd0af5c
    BRANCH=codex/v075-monster-military-combat-bd0af5c
    HEAD=a4a06b96d39b20a94418c4a1c02c74e6af17b9c6
    HEAD_TREE=d9389222611e8a8dd2afdf6cc8fba8fb6b8d7fbc
    ORIGIN_MAIN=bd0af5c99c5267cdbe7d66c01034f80db4d704fd
    HEAD_AHEAD_OF_ORIGIN_MAIN=40
    REMOTE_BRANCH_EXISTS=false

The counts below are the pre-report git status --porcelain=v1 snapshot.
They include existing work from the coordinator and generated Godot churn;
this audit did not reset, stash, delete, or overwrite any of it.

    TRACKED_MODIFIED_COUNT=73
    UNTRACKED_COUNT=208
    GENERATED_IMPORT_OR_UID_MODIFIED_COUNT=57
    NON_GENERATED_MODIFIED_COUNT=16
    UNTRACKED_UID_COUNT=189
    UNTRACKED_LOG_OR_PNG_COUNT=14
    UNTRACKED_OTHER_COUNT=5

docs/rules/v075_combat_authority_manifest.json explicitly says its status is
frozen_target_authority_manifest_not_runtime_evidence; its
runtime_claims.connected_domain_count is 0. It therefore cannot be used as
proof that the integrated production sample is complete.

## Production Entry Graph

The static V0.7.5 entry path is:

    project.godot:18
      -> scenes/main.tscn:4-16
      -> scenes/runtime/V075RuntimeComposition.tscn:3-29
      -> scripts/v075_runtime/v075_application_flow.gd
      -> scripts/v075_runtime/v075_runtime_owner.gd
      -> scripts/v075/runtime/v075_combat_runtime_owner.gd

Relevant exact references:

| Path | Evidence |
| --- | --- |
| project.godot:18 | run/main_scene="res://scenes/main.tscn" |
| scenes/main.tscn:4 | one V075RuntimeComposition.tscn external resource |
| scenes/main.tscn:5 | one V075SampleGameScreen.tscn external resource |
| scenes/main.tscn:16 | one V075RuntimeComposition instance |
| scenes/runtime/V075RuntimeComposition.tscn:3-7 | flow, ruleset, runtime, combat owner, and telemetry dependencies |
| scenes/runtime/V075RuntimeComposition.tscn:23-25 | one V075CombatRuntimeOwner node/script |

    V075_COMBAT_RUNTIME_OWNER_STATIC_COUNT=1
    V075_OLD_CONTROLLER_REFERENCE_LINES_IN_PRODUCTION_GRAPH=0
    V075_OLD_CONTROLLER_REFERENCE_FILES_IN_PRODUCTION_GRAPH=0
    OLD_MONSTER_CONTROLLER_PRODUCTION_REACHABLE_COUNT=0
    OLD_MILITARY_CONTROLLER_PRODUCTION_REACHABLE_COUNT=0
    LEGACY_MAIN_SCRIPT_PRESENT=false

The negative reachability assertions are encoded in
tests/v075_application_composition_test.gd:147-159 and
tests/v075_application_composition_test.gd:178-204, but this handoff does
not claim a new test run.

## Legacy Controller Inventory

The following four definition/scene files remain in the repository:

    scripts/runtime/monster_runtime_controller.gd:3       class_name MonsterRuntimeController
    scripts/runtime/military_runtime_controller.gd:3       class_name MilitaryRuntimeController
    scenes/runtime/MonsterRuntimeController.tscn:5-6       legacy scene/script
    scenes/runtime/MilitaryRuntimeController.tscn:5-6       legacy scene/script

The bounded legacy graph has 10 static reference lines in six scene files:

    scenes/runtime/GameRuntimeCoordinator.tscn:38,40,372,387
    scenes/runtime/MonsterCodexPublicSourceService.tscn:7
    scenes/runtime/MonsterWagerResponseSink.tscn:7,9
    scenes/runtime/MonsterWagerCashCommitmentQueryPort.tscn:7
    scenes/runtime/V06SaveOwnerRegistry.tscn:91
    scenes/runtime/CardTargetChoiceResponseSink.tscn:9

    LEGACY_CONTROLLER_DEFINITION_FILE_COUNT=4
    LEGACY_GRAPH_REFERENCE_LINE_COUNT=10
    LEGACY_GRAPH_REFERENCE_FILE_COUNT=6

GameRuntimeCoordinator.tscn is a legacy V0.6 composition and is not an
instance in scenes/main.tscn or V075RuntimeComposition.tscn. The V0.7.5
authority manifest permits legacy semantic reads and pure algorithm
extraction, but forbids a legacy controller instance or fallback. No static
V0.7.5 production path violates that rule at this snapshot.

## Guard, Bound, and Placeholder Audit

Counts are line matches in the active V0.7.5 scope:
scripts/v075, scripts/v075_runtime, scripts/ui/v075, scenes/ui/v075,
scenes/runtime/V075RuntimeComposition.tscn, and scenes/main.tscn.

| Audit item | Count | Exact locations / interpretation |
| --- | ---: | --- |
| executable guard_region / protect_region / guard task definitions | 0 | no active task definition matched |
| guard compatibility/diagnostic token lines | 7 | scripts/v075_runtime/v075_runtime_owner.gd:1678; scripts/v075/ai/v075_combat_ai_adapter.gd:388; scripts/v075/military/v075_military_mission_core.gd:650; scripts/v075/combat/v075_combat_catalog.gd:149; scripts/v075/runtime/v075_combat_runtime_owner.gd:1083; scripts/v075/player/v075_combat_projection_adapter.gd:204; scripts/ui/v075/v075_combat_player_surface.gd:176 |
| bound-action token lines | 26 | seven active files; military contract fields are explicitly false/0, but generic prebinding names remain |
| files containing bound-action tokens | 7 | scripts/v075/military/v075_military_mission_core.gd; scripts/ui/v075/v075_combat_player_surface.gd; scripts/ui/v075/v075_military_mission_panel.gd; scripts/v075_runtime/v075_runtime_owner.gd; scripts/v075/combat/v075_combat_catalog.gd; scripts/v075/monster/v075_monster_source_core.gd; scripts/v075/runtime/v075_combat_runtime_owner.gd |
| files containing prebind / _build_bound_actions | 4 | scripts/v075/ai/v075_combat_ai_adapter.gd; scripts/v075_runtime/v075_runtime_owner.gd; scripts/v075/monster/v075_monster_source_core.gd; scripts/v075/runtime/v075_combat_runtime_owner.gd |
| actual generic special-support placeholder instances | 0 | no active available=false or tactical_support match |
| zero-valued special_support_placeholder_count compatibility fields | 3 | scripts/v075_runtime/v075_runtime_owner.gd:1677; scripts/ui/v075/v075_combat_player_surface.gd:188; scripts/ui/v075/v075_sample_game_screen.gd:409 |
| guard UI controls | 0 | scripts/ui/v075/v075_military_mission_panel.gd:9-14,69-81 exposes only assault region/monster |
| military skill dock controls | 0 | same panel debug contract reports military_skill_dock_count=0 |

The zero counters are useful observability fields, not action implementations.
The 26 bound/prebound matches cannot be called fully removed: in particular,
scripts/v075_runtime/v075_runtime_owner.gd:2088 defines _build_bound_actions,
and its monster/military branches create the prebound combat binding consumed
by the public resolution path. This is a semantic migration item, not an
old-controller reachability finding.

## Current Execution Modes and Forward Compatibility

    CURRENT_MILITARY_EXECUTION_MODE=normal_public_batch
    CURRENT_DIRECT_ATTACK_EXECUTION_MODE=not_implemented_in_v075
    CURRENT_MILITARY_PUBLIC_BATCH_PATH_PRESENT=true
    CURRENT_DIRECT_ACTION_GENERIC_OWNER_PRESENT=false
    SUPERSEDED_BY_V076_DIRECT_INTERVENTION=true
    V075_MILITARY_FINAL_LANE=pending_v076_private_direct_intervention

Evidence for the current military path:

* scripts/ui/v075/v075_sample_game_screen.gd:17 declares
  MILITARY_EXECUTION_MODE := "normal_public_batch".
* scripts/v075_runtime/v075_application_flow.gd:94 accepts queue_card_action.
* scripts/v075_runtime/v075_runtime_owner.gd:952-1035 inserts monster and
  military bindings into the per-player queue.
* scripts/v075_runtime/v075_runtime_owner.gd:1257-1307 resolves the next
  entry through V075PublicActionBatchCore and then dispatches military combat.
* scripts/v075/runtime/v075_public_action_batch_core.gd:12 includes "military"
  in ACTION_DOMAINS.

No new public military queue code was added by this Lane F audit. The existing
path must not be described as the final V0.7.6 contract; it is explicitly
marked for the successor's private direct-action lane.

## Current Region Presentation Audit

    CURRENT_REGION_PARTITION_AUTHORITY=V074MapGenesisCore_plus_V074GeodesicMicrogrid
    CURRENT_REGION_RENDERING_MODE=per_region_polygon_snapshot_with_shared_edge_fallback
    CURRENT_REGION_PRESENTATION_GAP_COUNT=UNMEASURED_AT_CURRENT_INTEGRATED_SHA
    CURRENT_REGION_PRESENTATION_OVERLAP_COUNT=UNMEASURED_AT_CURRENT_INTEGRATED_SHA
    SUPERSEDED_BY_V076_EXACT_PARTITION=true

The authority-side V0.7.4 report
reports/v074/map_genesis/lane_a_validation.json records
gap_or_overlap_map_count=0 over 63 maps and
invalid_ordered_boundary_loop_count=0. It does not establish the requested
2,000-map presentation-pixel gate. The active presentation adapter still
creates districts[].polygon at
scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd:104 and
uses _world_polygon at :863; its shared-edge ordering fallback is at :450-472.
Hit-test cells are indexed from authoritative microcells at :586-630, but
there is no single region-id surface/closed shared mesh in the current V0.7.5
production composition. Therefore this audit does not claim seamless planet
acceptance.

## Existing MCP and Runtime Evidence

This section records evidence already present in the worktree; it does not
run or reinterpret a prohibited suite.

### Detached Lane F evidence

reports/v075/coordination/lane_f_handoff.json reports a detached bench on
branch codex/v075-lane-f-ai-ui-presentation-bd0af5c, role A, port 7576,
Godot 4.7-stable, with:

    changed_script_validation=12/12
    changed_scene_load=4/4
    runtime_error_count=0
    runtime_bridge_ready=true
    push_performed=false
    visual_capture_files_committed=false

That is valid lane-local evidence, not same-SHA main.tscn acceptance for
a4a06b96...; the handoff itself says production cutover, integrated sample,
simulation matrix, PR, merge, and release tag are not claimed.

### Current coordinator evidence

    .codex-final-v075-combat-checkpoint-rollback-test-gd.out.log
      V075_COMBAT_CHECKPOINT_ROLLBACK_TEST|PASS|8/8
    .codex-final-new-mixed-checkpoint-rollback.out.log
      V075_COMBAT_CHECKPOINT_TRANSACTION_ROLLBACK_TEST|status=PASS|passed=25|total=25
    .codex-final-v075-terminal-combat-quiescence-test-gd.out.log
      V075_TERMINAL_COMBAT_QUIESCENCE_TEST|status=PASS|passed=7|total=7
    .codex-final-new-submission-rollback.out.log
      V075_COMBAT_SUBMISSION_ROLLBACK_TEST|status=FAIL|passed=19|total=20

The failed submission test reports the downstream asset/DBG ownership rollback
case. It is a current real blocker for the atomic production cutover.

reports/balance/v075_combat_simulation_report.json and its Markdown mirror
are also current worktree evidence:

    acceptance_status=PARTIAL
    required_formal_match_count=2000
    total_match_count=5
    COMBAT_SIMULATION_DEADLOCK_COUNT=0
    COMBAT_INVALID_TARGET_COUNT=0
    COMBAT_DUPLICATE_EFFECT_COUNT=0
    COMBAT_HIDDEN_INFO_VIOLATION_COUNT=0
    COMBAT_RUNTIME_ERROR_COUNT=78
    FINAL_SETTLEMENT_COUNT=5
    MONSTER_CARD_PURCHASE_COUNT=12
    MONSTER_CARD_RESHUFFLE_COUNT=3
    MONSTER_DEPLOY_COUNT=0
    MONSTER_REFRESH_COUNT=0
    MONSTER_UPGRADE_COUNT=0
    MONSTER_REPLACE_COUNT=0
    MONSTER_AUTONOMY_TARGET_COUNT=0
    MONSTER_TRAMPLE_REGION_RECEIPT_COUNT=0
    MONSTER_PRIVATE_SKILL_REQUEST_COUNT=0
    MONSTER_PRIVATE_SKILL_USE_COUNT=0
    MILITARY_CARD_PURCHASE_COUNT=10
    MILITARY_CARD_RESHUFFLE_COUNT=4
    MILITARY_REGION_ASSAULT_COUNT=0
    MILITARY_MONSTER_ASSAULT_COUNT=0
    MILITARY_WITHDRAW_COUNT=0
    FACILITY_COMBAT_DAMAGE_COUNT=0
    direct_state_injection_count=0
    opponent_private_facts_read_count=0
    private_warehouse_stock_read_count=0

The simulation root-cause fields record six
monster_card_prebind_phase_invalid rejections after one preview acceptance;
four military cards reached hand, but legal/affordable/available military
options and queued military actions were all zero. This is why the report is
not a GREEN combat candidate even though the safety counters are zero.

No current same-SHA integrated MCP probe result with
MCP_COMMIT_SHA_MATCH=true is present in this worktree. The MCP probe source
exists at tests/v075_mcp_production_probe.gd, but source existence is not a
run result.

## Real Blockers and Non-Blockers

### Real blockers

1. Natural combat reachability is incomplete: the current simulation has no
   monster deployment, autonomy, movement, trample, skill, military assault,
   or facility combat effects, and records 78 runtime errors.
2. The cross-owner submission rollback gate is 19/20 and fails its asset/DBG
   rollback assertion.
3. A same-SHA production MCP run through main.tscn, full positive combat
   coverage, and final production acceptance are not evidenced.
4. The amended direction is not yet reflected in the active military path:
   military selection is still public-batch/prebound. It must remain marked
   pending_v076_private_direct_intervention and must not be expanded as a
   final contract.
5. The current per-region polygon presentation has no integrated 2,000-map
   pixel gap/overlap proof and is not the V0.7.6 exact shared-topology model.

### Not blockers for legacy reachability

* Old controller static files and V0.6 references exist, but their V0.7.5
  production reachable count is 0.
* No active guard_region or protect_region task definition was found.
* Runtime/UI placeholder values are explicitly zero; the three matching lines
  are DTO/debug compatibility fields, not visible tactical support actions.
* Existing focused lane-local MCP reports with zero runtime errors do not
  substitute for the missing integrated same-SHA proof.

## Handoff Flags

    LANE_F_OWNED_FILE_COUNT=1
    LANE_F_PRODUCTION_FILES_EDITED=0
    PR77_MODIFIED_BY_THIS_AUDIT=false
    ALPHA04C_RELIABILITY_TRACK_FROZEN=true
    V076_STARTED=false
    CURRENT_TASK_NO_RESET=true
    CURRENT_TASK_NEW_USER_FILES_PRESERVED=true
    CURRENT_TASK_FINAL_STATUS=PARTIAL

The coordinator may continue V0.7.5 work in the preserved branch/worktree.
The queued successor remains:

    QUEUED_SUCCESSOR_TASK=ALPHA_0_5_C3_V076_EXACT_SPHERICAL_PARTITION_AND_PRIVATE_DIRECT_COMBAT_INTERVENTION_LANE
    SUCCESSOR_START_ALLOWED=false

