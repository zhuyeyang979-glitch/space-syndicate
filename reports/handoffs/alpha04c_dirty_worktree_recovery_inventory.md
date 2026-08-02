# Alpha 0.4-C dirty-worktree recovery inventory

- Task: `ALPHA_0_4_C_DIRTY_WORKTREE_RECOVERY_OFFICIAL_COLD_RESTORE_AND_DELIVERY`
- Worktree: `E:/SpaceSyndicateWorkspace/worktrees/alpha04c-save-resume-cold-restore-5b8601b`
- Branch: `codex/alpha04c-save-resume-cold-restore-5b8601b`
- Observed HEAD: `27c4fc6c9e39824f4804bc13c9e8f7f3937ea2cc`
- Starting delta: 40 tracked modifications and 30 untracked files.
- Ambiguous or unrelated overlap: none found.

The machine-readable inventory in `alpha04c_dirty_worktree_recovery_inventory.json` records the required purpose, evidence, commit group, safety, generation source, owner, and notes for every one of the 70 starting paths.

After this starting snapshot, the two inventory files themselves and three new
Godot scan sidecars appeared. The current 75-path accounting is therefore
`A14/B21/C3/D1/E5/F31/G0`. The three post-snapshot sidecars are:

- `scripts/tools/restore_dependency_preflight_bench.gd.uid`
- `tests/alpha04c_route_military_queue_restore_dependency_test.gd.uid`
- `tests/v06_save_file_fault_matrix_test.gd.uid`

They are preserved in place and excluded from staging with the original F set.

## Classification summary

| Category | Count | Disposition |
| --- | ---: | --- |
| A — verified production implementation | 14 | Commit in owner/registry or production-slot/codec groups after short gates. |
| B — verified owner, registry, harness, or regression test | 21 | Commit in the focused-test group after short gates. |
| C — verified save contract/documentation | 1 | Commit with the contract/recovery documentation group. |
| D — cold-restore driver in progress | 1 | Commit as an explicitly PARTIAL checkpoint before further qualification probes. |
| E — required Godot scene/resource | 5 | Commit with its owning implementation/test group. |
| F — generated runtime artifact, do not commit | 28 | Preserve in place, exclude from staging, and do not delete. |
| G — ambiguous or unrelated | 0 | No blocking overlap found. |

## Tracked implementation and evidence paths

### A — verified production implementation

- `scripts/runtime/commodity_flow_runtime_controller.gd`
- `scripts/runtime/game_runtime_coordinator.gd`
- `scripts/runtime/game_save_runtime_coordinator.gd`
- `scripts/runtime/game_session_runtime_controller.gd`
- `scripts/runtime/menu_lifecycle_application_flow_controller.gd`
- `scripts/runtime/player_organization_runtime_controller.gd`
- `scripts/runtime/ruleset_save_attestation_owner.gd`
- `scripts/runtime/ruleset_save_handshake_service.gd`
- `scripts/runtime/save_restore_runtime_barrier.gd`
- `scripts/runtime/save_resume_application_flow_controller.gd`
- `scripts/runtime/save_resume_intent_v06.gd`
- `scripts/runtime/save_resume_receipt_v06.gd`
- `scripts/runtime/v06_save_owner_registry.gd`
- `scripts/ui/pause_menu_summary_board.gd`

### B — verified tests and safety harnesses

- `reports/ui/production_acceptance/run_production_acceptance.ps1`
- `scripts/tools/game_session_save_ownership_bench.gd`
- `scripts/tools/save_resume_application_flow_bench.gd`
- `scripts/tools/tomorrow_playable_vertical_slice_bench.gd`
- `scripts/tools/v06_save_envelope_runtime_bench.gd`
- `scripts/tools/v06_save_owner_registry_bench.gd`
- `tests/alpha04_player_card_dock_production_capture.gd`
- `tests/alpha04c_mana_organization_victory_strict_preflight_test.gd`
- `tests/e_1280_economy_topbar_capture.gd`
- `tests/e_1280_table_readability_capture.gd`
- `tests/game_session_save_characterization_test.gd`
- `tests/layout_scene_smoke_test.gd`
- `tests/main_runtime_composition_test.gd`
- `tests/production_ui_minimal_capture.gd`
- `tests/v06_save_envelope_runtime_test.gd`
- `tests/v06_save_owner_registry_test.gd`
- `tests/weather_lifecycle_production_capture.gd`
- `tools/invoke_godot_test_failure_detection_self_test.ps1`
- `tools/invoke_godot_test_self_test.ps1`
- `tools/repository_safety_baseline.ps1`
- `tests/alpha04c_production_registry_transaction_test.gd`

### C — verified contract/documentation

- `docs/v06_save_envelope_runtime_contract.md`

### D — cold-restore driver in progress

- `scripts/tools/cold_restore_vertical_slice_driver.gd`

### E — required Godot scenes/resources

- `scenes/runtime/GameRuntimeCoordinator.tscn`
- `scenes/runtime/GameSessionRuntimeController.tscn`
- `scenes/runtime/V06SaveOwnerRegistry.tscn`
- `scenes/ui/PauseMenuSummaryBoard.tscn`
- `tests/alpha04c_production_registry_transaction_test.gd.uid`

## Generated sidecars excluded from every commit

The following 28 `.gd.uid` files were generated while Godot scanned pre-existing scripts. Their source scripts were not newly added by this recovery delta, so they are preserved but excluded:

- `scripts/tools/ai_business_action_transaction_boundary_bench.gd.uid`
- `scripts/tools/ai_business_action_transaction_fake_weather.gd.uid`
- `scripts/tools/ai_business_cost_fail_once_public_log_port.gd.uid`
- `scripts/tools/alpha01_manifest_runtime_activation_bench.gd.uid`
- `scripts/tools/alpha04c_monster_bankruptcy_save_preflight_bench.gd.uid`
- `scripts/tools/save_owner_strict_preflight_bench.gd.uid`
- `tests/ai_business_action_transaction_boundary_test.gd.uid`
- `tests/ai_business_cost_formal_four_player_test.gd.uid`
- `tests/ai_card_play_context_reuse_performance_parity_test.gd.uid`
- `tests/ai_city_guess_candidate_performance_parity_test.gd.uid`
- `tests/ai_saturated_route_plan_learning_cache_parity_test.gd.uid`
- `tests/alpha01_content_manifest_test.gd.uid`
- `tests/alpha01_manifest_runtime_activation_test.gd.uid`
- `tests/alpha01_product_art_manifest_test.gd.uid`
- `tests/alpha01_selected_role_consumer_test.gd.uid`
- `tests/alpha04_claim_to_sale_integration_test.gd.uid`
- `tests/alpha04_dock_legacy_planner_parity_test.gd.uid`
- `tests/alpha04_player_card_dock_production_capture.gd.uid`
- `tests/alpha04c_mana_organization_victory_strict_preflight_test.gd.uid`
- `tests/card_inventory_receive_plan_batch_parity_test.gd.uid`
- `tests/commodity_flow_postcommit_registry_preflight_test.gd.uid`
- `tests/district_supply_purchase_projection_receipt_test.gd.uid`
- `tests/full_run_facility_acquisition_policy_test.gd.uid`
- `tests/full_run_observation_window_policy_test.gd.uid`
- `tests/full_run_progress_budget_policy_test.gd.uid`
- `tests/full_run_progress_checkpoint_privacy_test.gd.uid`
- `tests/gameplay_balance_diagnostics_card_route_index_session_start_test.gd.uid`
- `tests/monster_save_owner_transaction_test.gd.uid`

No file was deleted, reset, stashed, or overwritten during recovery classification.
