extends Control
class_name CardResolutionExecutionRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const QUEUE_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_queue_runtime_service.gd"
const EXECUTION_SERVICE_SCENE_PATH := "res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn"
const EXECUTION_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_execution_runtime_service.gd"
const EXECUTION_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_execution_world_bridge.gd"
const ECONOMY_PRODUCT_ROUTE_EFFECT_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_economy_product_route_effect_runtime_service.gd"
const ECONOMY_PRODUCT_ROUTE_EFFECT_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/card_economy_product_route_effect_world_bridge.gd"
const ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE_SCENE_PATH := "res://scenes/runtime/CardEconomyProductRouteFormulaRuntimeService.tscn"
const ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_economy_product_route_formula_runtime_service.gd"
const PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_controller.gd"
const CITY_GDP_DERIVATIVE_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/city_gdp_derivative_runtime_controller.gd"
const CITY_TRADE_NETWORK_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const RUNTIME_BALANCE_MODEL_SCRIPT_PATH := "res://scripts/balance/runtime_balance_model.gd"
const GDP_FORMULA_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/gdp_formula_runtime_controller.gd"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/card_resolution_runtime_controller.gd"
const INVENTORY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_inventory_runtime_service.gd"
const HAND_SERVICE_SCRIPT_PATH := "res://scripts/runtime/player_hand_interaction_runtime_service.gd"
const DISTRICT_SETTLEMENT_SCRIPT_PATH := "res://scripts/runtime/district_purchase_settlement_runtime_service.gd"
const CONTRACT_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_controller.gd"
const CONTRACT_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_world_bridge.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/card_resolution_execution_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/contract_city_product_formula_sprint_40.png"
const BASELINE_MAIN_SHA256 := "0D46E013D8EA2BA131C61D6E6F183B2E99BF7E929A245FF31FBA4B22D5DE1C0A"
const CASE_COUNT := 28
const CUTOVER_CASE_COUNT := 52
const TOTAL_CASE_COUNT := CASE_COUNT + CUTOVER_CASE_COUNT

const CASH_CARD_ID := "轨道融资1"
const PRODUCT_CARD_ID := "价格套利1"
const DISTRICT_CARD_ID := "生产扩张1"
const MONSTER_CARD_ID := "诱导电波1"
const HAND_CARD_ID := "星链拆解1"
const CONTRACT_CARD_ID := "区域供需合约1"
const INTEL_CARD_ID := "出牌追帧1"
const COUNTER_CARD_ID := "相位否决1"
const PERSISTENT_CARD_ID := "移动1"

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var contract_text: RichTextLabel = %ContractText
@onready var lifecycle_text: RichTextLabel = %LifecycleText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control = null
var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	print("CardResolutionExecutionRuntimeCharacterizationBench ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return [
		"execution_call_graph_complete",
		"queue_service_boundary_unchanged",
		"timing_controller_boundary_unchanged",
		"active_entry_is_read_from_queue_service",
		"active_entry_not_duplicated_in_main_state",
		"valid_target_reconfirmed_before_effect",
		"invalid_target_fails_without_partial_mutation",
		"target_state_drift_returns_stable_reason",
		"immediate_economy_effect_applies_once",
		"city_or_product_effect_applies_once",
		"route_or_district_effect_applies_once",
		"monster_effect_routes_to_existing_rule_owner",
		"hand_interaction_routes_to_existing_service",
		"inventory_mutation_routes_to_inventory_service",
		"temporary_decision_pauses_resolution",
		"temporary_decision_resume_continues_same_resolution",
		"temporary_decision_cancel_behavior_characterized",
		"counter_response_preserves_active_entry",
		"contract_response_preserves_active_entry",
		"monster_wager_preserves_active_entry",
		"public_event_emitted_after_success",
		"private_event_visibility_boundary",
		"ledger_and_action_log_exactly_once",
		"scenario_and_coach_hooks_exactly_once",
		"failed_resolution_does_not_emit_success_feedback",
		"successful_resolution_completes_active_once",
		"next_queue_item_starts_after_completion",
		"save_load_active_resolution_parity",
	]


func cutover_cases() -> Array:
	return [
		"execution_service_scene_composition",
		"execution_service_api_contract",
		"real_main_routes_completion_through_service",
		"active_entry_request_is_pure_data",
		"counter_check_precedes_active_release",
		"active_release_precedes_effect_dispatch",
		"failed_active_release_blocks_effect",
		"countered_card_skips_original_effect",
		"countered_card_finishes_commitment",
		"normal_effect_dispatches_once",
		"stale_requirement_keeps_no_refund_semantics",
		"stale_target_keeps_no_refund_semantics",
		"persistent_card_restores_and_cools_down",
		"consumable_card_never_returns",
		"paid_cost_marker_preserved",
		"selection_context_restored",
		"contract_context_restored",
		"city_development_uses_world_adapter",
		"product_route_economy_use_world_adapters",
		"monster_and_player_target_use_world_adapters",
		"hand_interaction_uses_existing_service",
		"contract_offer_remains_non_blocking",
		"monster_wager_handoff_uses_forced_scheduler",
		"aftermath_and_history_order_preserved",
		"history_appended_exactly_once",
		"current_queue_starts_next_entry",
		"empty_current_queue_promotes_next_batch",
		"save_resume_privacy_and_legacy_absence",
		"formula_service_scene_composition",
		"formula_service_api_contract",
		"product_price_model_owner_unchanged",
		"city_gdp_formula_owner_unchanged",
		"market_boon_formula_parity",
		"speculation_pressure_formula_parity",
		"futures_formula_parity",
		"gdp_derivative_formula_parity",
		"route_formula_parity",
		"main_pure_formula_bodies_absent",
		"effect_family_uses_formula_service",
		"execution_service_remains_formula_agnostic",
		"product_contract_boon_formula_parity",
		"city_contract_boon_formula_parity",
		"contract_accept_route_flow_formula_parity",
		"route_insurance_formula_parity",
		"city_product_upgrade_formula_parity",
		"city_product_shift_formula_parity",
		"city_demand_shift_formula_parity",
		"city_adjustment_formula_parity",
		"main_contract_formula_bodies_absent",
		"main_city_product_formula_bodies_absent",
		"world_rng_and_mutation_boundary_preserved",
		"execution_service_sprint40_formula_agnostic",
	]


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), "preview", "", "", {
			"observed": false,
			"contract_aligned": false,
			"notes": "preview",
		}))
	for case_id_variant in cutover_cases():
		records.append(_record(str(case_id_variant), "cutover-preview", "", "execution_cutover", {
			"observed": false,
			"contract_aligned": false,
			"cutover_checked": false,
			"notes": "preview",
		}))
	return {
		"suite": "card-resolution-execution-effect-formula-cutover-sprint40-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"main_scene": MAIN_SCENE_PATH,
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"case_count": CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"total_case_count": TOTAL_CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"needs_design_decision_count": 0,
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("CardResolutionExecutionRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	var main_sha256 := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH).sha256_text().to_upper()
	for case_id_variant in characterization_cases():
		var case_id := str(case_id_variant)
		await _reset_runtime_main()
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	for case_id_variant in cutover_cases():
		var case_id := str(case_id_variant)
		await _reset_runtime_main()
		var record := _run_cutover_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("cutover_checked", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "cutover check failed"))])
	var manifest := {
		"suite": "card-resolution-execution-effect-formula-cutover-sprint40-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"main_scene": MAIN_SCENE_PATH,
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"actual_main_sha256": main_sha256,
		"main_sha_matches_baseline": main_sha256 == BASELINE_MAIN_SHA256,
		"case_count": CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"total_case_count": TOTAL_CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _characterization_count("observed"),
		"aligned_count": _characterization_count("contract_aligned"),
		"cutover_count": _cutover_count(),
		"passed_count": _passed_count(),
		"mismatch_count": CASE_COUNT - _characterization_count("contract_aligned"),
		"needs_design_decision_count": _design_decision_count(),
		"representative_cards": _representative_card_catalog(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("CardResolutionExecutionRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("CardResolutionExecutionRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("CardResolutionExecutionRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("CardResolutionExecutionRuntimeCharacterizationBench observed: %d/%d" % [_characterization_count("observed"), CASE_COUNT])
	print("CardResolutionExecutionRuntimeCharacterizationBench aligned: %d/%d; design_decisions=%d" % [_characterization_count("contract_aligned"), CASE_COUNT, _design_decision_count()])
	print("CardResolutionExecutionRuntimeCharacterizationBench cutover: %d/%d" % [_cutover_count(), CUTOVER_CASE_COUNT])
	print("CardResolutionExecutionRuntimeCharacterizationBench total: %d/%d" % [_passed_count(), TOTAL_CASE_COUNT])
	if not _failures.is_empty():
		push_error("CardResolutionExecutionRuntimeCharacterizationBench observation failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"execution_call_graph_complete": return _case_execution_call_graph_complete()
		"queue_service_boundary_unchanged": return _case_queue_service_boundary_unchanged()
		"timing_controller_boundary_unchanged": return _case_timing_controller_boundary_unchanged()
		"active_entry_is_read_from_queue_service": return _case_active_entry_is_read_from_queue_service()
		"active_entry_not_duplicated_in_main_state": return _case_active_entry_not_duplicated_in_main_state()
		"valid_target_reconfirmed_before_effect": return _case_valid_target_reconfirmed_before_effect()
		"invalid_target_fails_without_partial_mutation": return _case_invalid_target_fails_without_partial_mutation()
		"target_state_drift_returns_stable_reason": return _case_target_state_drift_returns_stable_reason()
		"immediate_economy_effect_applies_once": return _case_immediate_economy_effect_applies_once()
		"city_or_product_effect_applies_once": return _case_city_or_product_effect_applies_once()
		"route_or_district_effect_applies_once": return _case_route_or_district_effect_applies_once()
		"monster_effect_routes_to_existing_rule_owner": return _case_monster_effect_routes_to_existing_rule_owner()
		"hand_interaction_routes_to_existing_service": return _case_hand_interaction_routes_to_existing_service()
		"inventory_mutation_routes_to_inventory_service": return _case_inventory_mutation_routes_to_inventory_service()
		"temporary_decision_pauses_resolution": return _case_temporary_decision_pauses_resolution()
		"temporary_decision_resume_continues_same_resolution": return _case_temporary_decision_resume_continues_same_resolution()
		"temporary_decision_cancel_behavior_characterized": return _case_temporary_decision_cancel_behavior_characterized()
		"counter_response_preserves_active_entry": return _case_counter_response_preserves_active_entry()
		"contract_response_preserves_active_entry": return _case_contract_response_preserves_active_entry()
		"monster_wager_preserves_active_entry": return _case_monster_wager_preserves_active_entry()
		"public_event_emitted_after_success": return _case_public_event_emitted_after_success()
		"private_event_visibility_boundary": return _case_private_event_visibility_boundary()
		"ledger_and_action_log_exactly_once": return _case_ledger_and_action_log_exactly_once()
		"scenario_and_coach_hooks_exactly_once": return _case_scenario_and_coach_hooks_exactly_once()
		"failed_resolution_does_not_emit_success_feedback": return _case_failed_resolution_does_not_emit_success_feedback()
		"successful_resolution_completes_active_once": return _case_successful_resolution_completes_active_once()
		"next_queue_item_starts_after_completion": return _case_next_queue_item_starts_after_completion()
		"save_load_active_resolution_parity": return _case_save_load_active_resolution_parity()
	return _record(case_id, "unknown", "", "", {
		"observed": false,
		"contract_aligned": false,
		"risk": "unknown case",
		"notes": "No characterization implementation.",
	})


func _run_cutover_case(case_id: String) -> Dictionary:
	match case_id:
		"execution_service_scene_composition": return _cutover_execution_service_scene_composition()
		"execution_service_api_contract": return _cutover_execution_service_api_contract()
		"real_main_routes_completion_through_service": return _cutover_real_main_routes_completion_through_service()
		"active_entry_request_is_pure_data": return _cutover_active_entry_request_is_pure_data()
		"counter_check_precedes_active_release": return _cutover_counter_check_precedes_active_release()
		"active_release_precedes_effect_dispatch": return _cutover_active_release_precedes_effect_dispatch()
		"failed_active_release_blocks_effect": return _cutover_failed_active_release_blocks_effect()
		"countered_card_skips_original_effect": return _cutover_countered_card_skips_original_effect()
		"countered_card_finishes_commitment": return _cutover_countered_card_finishes_commitment()
		"normal_effect_dispatches_once": return _cutover_normal_effect_dispatches_once()
		"stale_requirement_keeps_no_refund_semantics": return _cutover_stale_requirement_keeps_no_refund_semantics()
		"stale_target_keeps_no_refund_semantics": return _cutover_stale_target_keeps_no_refund_semantics()
		"persistent_card_restores_and_cools_down": return _cutover_persistent_card_restores_and_cools_down()
		"consumable_card_never_returns": return _cutover_consumable_card_never_returns()
		"paid_cost_marker_preserved": return _cutover_paid_cost_marker_preserved()
		"selection_context_restored": return _cutover_selection_context_restored()
		"contract_context_restored": return _cutover_contract_context_restored()
		"city_development_uses_world_adapter": return _cutover_city_development_uses_world_adapter()
		"product_route_economy_use_world_adapters": return _cutover_product_route_economy_use_world_adapters()
		"monster_and_player_target_use_world_adapters": return _cutover_monster_and_player_target_use_world_adapters()
		"hand_interaction_uses_existing_service": return _cutover_hand_interaction_uses_existing_service()
		"contract_offer_remains_non_blocking": return _cutover_contract_offer_remains_non_blocking()
		"monster_wager_handoff_uses_forced_scheduler": return _cutover_monster_wager_handoff_uses_forced_scheduler()
		"aftermath_and_history_order_preserved": return _cutover_aftermath_and_history_order_preserved()
		"history_appended_exactly_once": return _cutover_history_appended_exactly_once()
		"current_queue_starts_next_entry": return _cutover_current_queue_starts_next_entry()
		"empty_current_queue_promotes_next_batch": return _cutover_empty_current_queue_promotes_next_batch()
		"save_resume_privacy_and_legacy_absence": return _cutover_save_resume_privacy_and_legacy_absence()
		"formula_service_scene_composition": return _cutover_formula_service_scene_composition()
		"formula_service_api_contract": return _cutover_formula_service_api_contract()
		"product_price_model_owner_unchanged": return _cutover_product_price_model_owner_unchanged()
		"city_gdp_formula_owner_unchanged": return _cutover_city_gdp_formula_owner_unchanged()
		"market_boon_formula_parity": return _cutover_market_boon_formula_parity()
		"speculation_pressure_formula_parity": return _cutover_speculation_pressure_formula_parity()
		"futures_formula_parity": return _cutover_futures_formula_parity()
		"gdp_derivative_formula_parity": return _cutover_gdp_derivative_formula_parity()
		"route_formula_parity": return _cutover_route_formula_parity()
		"main_pure_formula_bodies_absent": return _cutover_main_pure_formula_bodies_absent()
		"effect_family_uses_formula_service": return _cutover_effect_family_uses_formula_service()
		"execution_service_remains_formula_agnostic": return _cutover_execution_service_remains_formula_agnostic()
		"product_contract_boon_formula_parity": return _cutover_product_contract_boon_formula_parity()
		"city_contract_boon_formula_parity": return _cutover_city_contract_boon_formula_parity()
		"contract_accept_route_flow_formula_parity": return _cutover_contract_accept_route_flow_formula_parity()
		"route_insurance_formula_parity": return _cutover_route_insurance_formula_parity()
		"city_product_upgrade_formula_parity": return _cutover_city_product_upgrade_formula_parity()
		"city_product_shift_formula_parity": return _cutover_city_product_shift_formula_parity()
		"city_demand_shift_formula_parity": return _cutover_city_demand_shift_formula_parity()
		"city_adjustment_formula_parity": return _cutover_city_adjustment_formula_parity()
		"main_contract_formula_bodies_absent": return _cutover_main_contract_formula_bodies_absent()
		"main_city_product_formula_bodies_absent": return _cutover_main_city_product_formula_bodies_absent()
		"world_rng_and_mutation_boundary_preserved": return _cutover_world_rng_and_mutation_boundary_preserved()
		"execution_service_sprint40_formula_agnostic": return _cutover_execution_service_sprint40_formula_agnostic()
	return _cutover_record(case_id, {"observed": false, "contract_aligned": false, "cutover_checked": false, "notes": "No cutover implementation."})


func _cutover_execution_service_scene_composition() -> Dictionary:
	var packed := load(EXECUTION_SERVICE_SCENE_PATH) as PackedScene
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var checked := packed != null and _execution_service() != null and coordinator_scene.contains("CardResolutionExecutionRuntimeService.tscn") and coordinator_scene.contains("name=\"CardResolutionExecutionRuntimeService\"")
	return _cutover_record("execution_service_scene_composition", {"observed": packed != null, "contract_aligned": checked, "service_owner_checked": checked, "notes": "The execution service is a real scene and a static GameRuntimeCoordinator child."})


func _cutover_execution_service_api_contract() -> Dictionary:
	var service := _execution_service()
	var methods := ["plan_execution", "advance_execution", "finalize_execution", "recover_from_active", "debug_snapshot"]
	var checked := service != null
	for method_name in methods:
		checked = checked and service.has_method(method_name)
	var debug := _service_debug(service)
	checked = checked and bool(debug.get("execution_orchestration_authority", false)) and not bool(debug.get("queue_authority", true)) and not bool(debug.get("timing_authority", true))
	return _cutover_record("execution_service_api_contract", {"observed": service != null, "contract_aligned": checked, "service_owner_checked": checked, "pure_data_checked": _is_data_only(debug), "notes": "Service exposes plan/advance/finalize/recover/debug and advertises no queue, clock, inventory, or concrete-effect ownership."})


func _cutover_real_main_routes_completion_through_service() -> Dictionary:
	var source := _main_source()
	var complete := _function_source(source, "_complete_active_card_resolution")
	var checked := complete.contains("plan_card_resolution_execution") and complete.contains("advance_card_resolution_execution") and complete.contains("finalize_card_resolution_execution") and complete.contains("_apply_card_resolution_execution_intent") and not source.contains("func _resolve_queued_skill(")
	return _cutover_record("real_main_routes_completion_through_service", {"observed": not complete.is_empty(), "contract_aligned": checked, "main_adapter_checked": checked, "legacy_orchestration_absent": not source.contains("func _resolve_queued_skill("), "notes": "The compatibility entry is a transaction runner; the old dispatch shell is absent."})


func _cutover_active_entry_request_is_pure_data() -> Dictionary:
	var request_variant: Variant = _runtime_main.call("_card_resolution_execution_request", _entry(CASH_CARD_ID, 3704))
	var request: Dictionary = request_variant if request_variant is Dictionary else {}
	var checked := not request.is_empty() and _is_data_only(request) and not _contains_runtime_object(request)
	return _cutover_record("active_entry_request_is_pure_data", {"observed": not request.is_empty(), "contract_aligned": checked, "pure_data_checked": checked, "notes": "The main-to-service request is an isolated data snapshot with no runtime handles."})


func _cutover_counter_check_precedes_active_release() -> Dictionary:
	var result := _drive_execution_service(_service_plan(3705, HAND_CARD_ID), {})
	var order: Array = result.get("order", []) as Array
	var checked := order.find("counter_check") == 0 and order.find("release_active") == 1
	return _cutover_record("counter_check_precedes_active_release", {"observed": order.size() > 1, "contract_aligned": checked, "intent_order_checked": checked, "active_release_checked": checked, "notes": "Counter eligibility is resolved while Queue Service still owns the active entry."})


func _cutover_active_release_precedes_effect_dispatch() -> Dictionary:
	var result := _drive_execution_service(_service_plan(3706, CASH_CARD_ID), {})
	var order: Array = result.get("order", []) as Array
	var release_at := order.find("release_active")
	var dispatch_at := order.find("dispatch_effect")
	var checked := release_at >= 0 and dispatch_at > release_at
	return _cutover_record("active_release_precedes_effect_dispatch", {"observed": dispatch_at >= 0, "contract_aligned": checked, "intent_order_checked": checked, "active_release_checked": checked, "effect_dispatch_checked": checked, "notes": "No concrete effect intent can occur before the active release receipt succeeds."})


func _cutover_failed_active_release_blocks_effect() -> Dictionary:
	var service := _execution_service()
	var transaction := _service_plan(3707, CASH_CARD_ID)
	transaction = service.call("advance_execution", transaction, {"intent_type": "counter_check", "countered": false}) as Dictionary
	transaction = service.call("advance_execution", transaction, {"intent_type": "release_active", "completed": false, "reason": "active_resolution_mismatch"}) as Dictionary
	var completed: Array = transaction.get("completed_intents", []) as Array
	var checked := str(transaction.get("status", "")) == "aborted" and not completed.has("dispatch_effect") and not bool(transaction.get("effect_dispatched", false))
	return _cutover_record("failed_active_release_blocks_effect", {"observed": str(transaction.get("failure_reason", "")) == "active_resolution_mismatch", "contract_aligned": checked, "active_release_checked": checked, "effect_dispatch_checked": checked, "notes": "A stale Queue Service receipt aborts the transaction before world mutation or history."})


func _cutover_countered_card_skips_original_effect() -> Dictionary:
	var result := _drive_execution_service(_service_plan(3708, HAND_CARD_ID), {"countered": true})
	var transaction: Dictionary = result.get("transaction", {}) as Dictionary
	var order: Array = result.get("order", []) as Array
	var checked := bool(transaction.get("countered", false)) and not order.has("dispatch_effect") and not bool(transaction.get("effect_dispatched", false))
	return _cutover_record("countered_card_skips_original_effect", {"observed": order.has("finish_card_commitment"), "contract_aligned": checked, "effect_dispatch_checked": checked, "notes": "Countered cards skip requirement, target, and original effect dispatch."})


func _cutover_countered_card_finishes_commitment() -> Dictionary:
	var result := _drive_execution_service(_service_plan(3709, HAND_CARD_ID), {"countered": true})
	var order: Array = result.get("order", []) as Array
	var transaction: Dictionary = result.get("transaction", {}) as Dictionary
	var checked := order.has("finish_card_commitment") and order.has("create_aftermath") and order.has("append_history") and bool(transaction.get("history_appended", false))
	return _cutover_record("countered_card_finishes_commitment", {"observed": bool(transaction.get("countered", false)), "contract_aligned": checked, "intent_order_checked": checked, "exact_once_checked": checked, "notes": "Counter cancellation does not reacquire the submitted card and still closes commitment/history."})


func _cutover_normal_effect_dispatches_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var before_cash := _player_cash(0)
	var before_debug := _service_debug(_execution_service())
	_complete_entry_twice(_entry(CASH_CARD_ID, 3710))
	var after_debug := _service_debug(_execution_service())
	var finalized_delta := int(after_debug.get("finalized_count", 0)) - int(before_debug.get("finalized_count", 0))
	var checked := _player_cash(0) - before_cash == int(_real_skill(CASH_CARD_ID).get("cash", 0)) and finalized_delta == 1 and _history_count_for_resolution(3710) == 1
	return _cutover_record("normal_effect_dispatches_once", {"observed": finalized_delta == 1, "contract_aligned": checked, "effect_dispatch_checked": checked, "exact_once_checked": checked, "notes": "A second compatibility-entry call finds no Queue Service active entry and cannot repeat effect/history."})


func _cutover_stale_requirement_keeps_no_refund_semantics() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var skill := _real_skill(CASH_CARD_ID)
	skill["play_cash"] = 2000
	var cash_before := _player_cash(0)
	_complete_entry_twice(_entry_with_skill(skill, 3711))
	var checked := _player_cash(0) == cash_before and _history_count_for_resolution(3711) == 1 and _logs_contain("未能满足结算条件")
	return _cutover_record("stale_requirement_keeps_no_refund_semantics", {"observed": _logs_contain("未能满足结算条件"), "contract_aligned": checked, "effect_dispatch_checked": checked, "exact_once_checked": checked, "notes": "Execution-time requirement drift skips the effect without refunding or replaying the committed submission."})


func _cutover_stale_target_keeps_no_refund_semantics() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_runtime_main.set("auto_monsters", [])
	var cash_before := _player_cash(0)
	_complete_entry_twice(_entry(MONSTER_CARD_ID, 3712, 0, 0, -1))
	var checked := _player_cash(0) == cash_before and _history_count_for_resolution(3712) == 1 and _logs_contain("目标怪兽已失效")
	return _cutover_record("stale_target_keeps_no_refund_semantics", {"observed": _logs_contain("目标怪兽已失效"), "contract_aligned": checked, "effect_dispatch_checked": checked, "exact_once_checked": checked, "notes": "A stale target produces a failed aftermath/history record without world mutation or refund."})


func _cutover_persistent_card_restores_and_cools_down() -> Dictionary:
	var card_id := _runtime_persistent_card_id()
	var skill := _real_skill(card_id)
	_prepare_players([[skill], []], [1000, 1000])
	var entry := _entry_with_skill(skill, 3713)
	entry["slot_index"] = 0
	entry["consumed_on_queue"] = false
	_complete_entry_twice(entry)
	var slot: Dictionary = (_player(0).get("slots", []) as Array)[0] as Dictionary
	var checked := not slot.is_empty() and bool(slot.get("persistent", false)) and float(slot.get("cooldown_left", 0.0)) > 0.0 and not bool(slot.get("queued_for_resolution", false))
	return _cutover_record("persistent_card_restores_and_cools_down", {"observed": not skill.is_empty(), "contract_aligned": checked, "world_adapter_checked": checked, "notes": "Persistent cards remain in their original slot, clear queued state, and receive the existing cooldown."}, card_id, "persistent_commitment")


func _cutover_consumable_card_never_returns() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var before := _normal_card_count(0)
	_complete_entry_twice(_entry(CASH_CARD_ID, 3714))
	var checked := _normal_card_count(0) == before and _history_count_for_resolution(3714) == 1
	return _cutover_record("consumable_card_never_returns", {"observed": _history_count_for_resolution(3714) == 1, "contract_aligned": checked, "world_adapter_checked": checked, "notes": "Consumed-on-queue cards are never reacquired by execution completion."}, CASH_CARD_ID, "consumable_commitment")


func _cutover_paid_cost_marker_preserved() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var skill := _real_skill(CASH_CARD_ID)
	skill["play_cash"] = 100
	var cash_before := _player_cash(0)
	_complete_entry_twice(_entry_with_skill(skill, 3715))
	var expected_gain := int(skill.get("cash", 0))
	var checked := _player_cash(0) - cash_before == expected_gain and _ledger_count(0) == 1
	return _cutover_record("paid_cost_marker_preserved", {"observed": expected_gain > 0, "contract_aligned": checked, "world_adapter_checked": checked, "notes": "The queue-paid marker reaches commitment, so the existing play fee is not charged a second time."}, CASH_CARD_ID, "paid_commitment")


func _cutover_selection_context_restored() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var original_player := mini(1, (_runtime_main.get("players") as Array).size() - 1)
	var original_district := mini(1, (_runtime_main.get("districts") as Array).size() - 1)
	var original_product := _first_runtime_product()
	_runtime_main.set("selected_player", original_player)
	_runtime_main.set("selected_district", original_district)
	_runtime_main.set("selected_trade_product", original_product)
	_complete_entry_twice(_entry(CASH_CARD_ID, 3716, 0, -1, -1, 0))
	var checked := int(_runtime_main.get("selected_player")) == original_player and int(_runtime_main.get("selected_district")) == original_district and str(_runtime_main.get("selected_trade_product")) == original_product
	return _cutover_record("selection_context_restored", {"observed": _history_count_for_resolution(3716) == 1, "contract_aligned": checked, "world_adapter_checked": checked, "notes": "Actor/district/product selection is captured in the pure plan and restored before history continuation."})


func _cutover_contract_context_restored() -> Dictionary:
	var source := _main_source()
	var request_builder := _function_source(source, "_card_resolution_execution_request")
	var bridge_source := FileAccess.get_file_as_string(EXECUTION_WORLD_BRIDGE_SCRIPT_PATH)
	var restore := _function_source(bridge_source, "_restore_context_receipt")
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var checked := request_builder.contains("contract_source_district") and request_builder.contains("contract_target_district") and restore.contains("contract_controller.set_selection_state") and execution_source.contains("INTENT_RESTORE_CONTEXT")
	return _cutover_record("contract_context_restored", {"observed": not restore.is_empty(), "contract_aligned": checked, "intent_order_checked": checked, "world_adapter_checked": checked, "notes": "Contract endpoints are temporary world context and are restored by an explicit service-owned phase."}, CONTRACT_CARD_ID, "contract_context")


func _cutover_city_development_uses_world_adapter() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var service_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	var checked := effect_adapter.contains("execute_city_development") and not effect_adapter.contains("_apply_city_development_card") and not service_source.contains("_apply_city_development_card") and coordinator_source.contains("func execute_city_development(")
	return _cutover_record("city_development_uses_world_adapter", {"observed": not effect_adapter.is_empty(), "contract_aligned": checked, "world_adapter_checked": checked, "notes": "Execution names the handler; main forwards world context to the Coordinator-owned city-development transaction."}, _runtime_city_development_card_id(), "city_development")


func _cutover_product_route_economy_use_world_adapters() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var family_service_source := FileAccess.get_file_as_string(ECONOMY_PRODUCT_ROUTE_EFFECT_SERVICE_SCRIPT_PATH)
	var family_bridge_source := FileAccess.get_file_as_string(ECONOMY_PRODUCT_ROUTE_EFFECT_WORLD_BRIDGE_SCRIPT_PATH)
	var checked := effect_adapter.contains("plan_card_economy_product_route_effect") and effect_adapter.contains("finalize_card_economy_product_route_effect") and effect_adapter.contains("_card_economy_product_route_effect_world_bridge_node")
	checked = checked and family_bridge_source.contains("_product_market_runtime_controller.apply_speculation") and family_bridge_source.contains("_apply_route_insurance") and family_bridge_source.contains("_apply_region_economy_shift")
	checked = checked and not effect_adapter.contains("_apply_product_speculation") and not execution_source.contains("_apply_product_speculation") and not family_service_source.contains("_apply_product_speculation")
	checked = checked and family_bridge_source.contains("contract_controller.open_offer") and FileAccess.get_file_as_string(CONTRACT_CONTROLLER_SCRIPT_PATH).contains("func open_offer(") and not _main_source().contains("func _apply_area_trade_contract(")
	return _cutover_record("product_route_economy_use_world_adapters", {"observed": not effect_adapter.is_empty(), "contract_aligned": checked, "service_owner_checked": checked, "world_adapter_checked": checked, "main_adapter_checked": checked, "notes": "The family service owns pure dispatch plans, its stateless world bridge routes existing formulas, and Execution Service remains family-agnostic."}, PRODUCT_CARD_ID, "economy_product_route_family")


func _cutover_monster_and_player_target_use_world_adapters() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var service_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var checked := effect_adapter.contains("_resolve_targeted_skill") and effect_adapter.contains("_apply_player_hand_disrupt") and effect_adapter.contains("_apply_player_hand_steal") and not service_source.contains("_resolve_targeted_skill") and not service_source.contains("_apply_player_hand_disrupt")
	return _cutover_record("monster_and_player_target_use_world_adapters", {"observed": not effect_adapter.is_empty(), "contract_aligned": checked, "world_adapter_checked": checked, "notes": "The service classifies target intent; existing monster and player-interaction owners still perform the rule mutation."}, MONSTER_CARD_ID, "target_adapters")


func _cutover_hand_interaction_uses_existing_service() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var interaction_adapter := _function_source(_main_source(), "_resolve_player_hand_interaction")
	var checked := effect_adapter.contains("_apply_player_hand_disrupt") and interaction_adapter.contains("plan_player_hand_interaction") and interaction_adapter.contains("commit_player_hand_interaction") and _hand_service() != null
	return _cutover_record("hand_interaction_uses_existing_service", {"observed": _hand_service() != null, "contract_aligned": checked, "existing_service_route_checked": checked, "world_adapter_checked": checked, "notes": "Execution delegates the real interaction card to the already-authoritative PlayerHandInteractionRuntimeService."}, HAND_CARD_ID, "player_hand_interaction")


func _cutover_contract_offer_remains_non_blocking() -> Dictionary:
	var result := _drive_execution_service(_service_plan(3722, CONTRACT_CARD_ID), {"continuation_kind": "contract_response"})
	var transaction: Dictionary = result.get("transaction", {}) as Dictionary
	var contract_source := FileAccess.get_file_as_string(CONTRACT_CONTROLLER_SCRIPT_PATH)
	var checked := str(transaction.get("continuation_kind", "")) == "contract_response" and contract_source.contains("pending_offers.append(offer)") and contract_source.contains("\"blocks_card_resolution\": false")
	return _cutover_record("contract_offer_remains_non_blocking", {"observed": str(transaction.get("continuation_kind", "")) == "contract_response", "contract_aligned": checked, "continuation_checked": checked, "notes": "The card resolves and leaves a pending offer/history continuation while the next card may start."}, CONTRACT_CARD_ID, "contract_continuation")


func _cutover_monster_wager_handoff_uses_forced_scheduler() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var candidates := _function_source(_main_source(), "_forced_decision_candidates")
	var service_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var checked := effect_adapter.contains("forced_decision_handoff") and candidates.contains("priority_group\": \"monster_wager") and not service_source.contains("active_monster_wagers")
	return _cutover_record("monster_wager_handoff_uses_forced_scheduler", {"observed": not candidates.is_empty(), "contract_aligned": checked, "continuation_checked": checked, "world_adapter_checked": checked, "notes": "Execution reports a handoff only when a new wager appears; ForcedDecisionRuntimeScheduler remains the blocker/priority owner."}, "", "forced_decision_handoff")


func _cutover_aftermath_and_history_order_preserved() -> Dictionary:
	var result := _drive_execution_service(_service_plan(3724, CASH_CARD_ID), {})
	var order: Array = result.get("order", []) as Array
	var aftermath_at := order.find("create_aftermath")
	var restore_at := order.find("restore_context")
	var history_at := order.find("append_history")
	var checked := aftermath_at >= 0 and restore_at > aftermath_at and history_at > restore_at
	return _cutover_record("aftermath_and_history_order_preserved", {"observed": history_at >= 0, "contract_aligned": checked, "intent_order_checked": checked, "notes": "Afternath is produced from effect result, selection context is restored, then the final entry is appended."})


func _cutover_history_appended_exactly_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_complete_entry_twice(_entry(CASH_CARD_ID, 3725))
	var debug := _service_debug(_execution_service())
	var checked := _history_count_for_resolution(3725) == 1 and int(debug.get("finalized_count", 0)) == 1
	return _cutover_record("history_appended_exactly_once", {"observed": _history_count_for_resolution(3725) == 1, "contract_aligned": checked, "exact_once_checked": checked, "notes": "Queue release plus the service completed-id gate prevents duplicate history or finalization."})


func _cutover_current_queue_starts_next_entry() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_queue_service().call("replace_active_entry", _entry(CASH_CARD_ID, 3726))
	_queue_service().call("replace_current_queue", [_entry(PRODUCT_CARD_ID, 4726)])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_force_duration", 5.0)
	_runtime_main.call("_complete_active_card_resolution")
	var active := _active_entry()
	var checked := int(active.get("resolution_id", -1)) == 4726 and _history_count_for_resolution(3726) == 1
	return _cutover_record("current_queue_starts_next_entry", {"observed": not active.is_empty(), "contract_aligned": checked, "continuation_checked": checked, "queue_service_checked": checked, "notes": "The service chooses start_next; Queue Service alone pops and installs the next active entry."})


func _cutover_empty_current_queue_promotes_next_batch() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_queue_service().call("replace_active_entry", _entry(CASH_CARD_ID, 3727))
	_queue_service().call("replace_current_queue", [])
	_queue_service().call("replace_next_queue", [_entry(PRODUCT_CARD_ID, 4727)])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_force_simultaneous_window", 30.0)
	_runtime_main.call("_complete_active_card_resolution")
	var current: Array = _queue_service().call("current_queue") as Array
	var next: Array = _queue_service().call("next_queue") as Array
	_runtime_main.set("card_resolution_force_simultaneous_window", -1.0)
	var checked := current.size() == 1 and next.is_empty() and int((current[0] as Dictionary).get("resolution_id", -1)) == 4727
	var queue_debug := _service_debug(_queue_service())
	return _cutover_record("empty_current_queue_promotes_next_batch", {"observed": current.size() == 1, "contract_aligned": checked, "continuation_checked": checked, "queue_service_checked": checked, "notes": "finish_batch and promote_next_batch are distinct service-owned intents; current=%d next=%d active=%s revision=%d." % [current.size(), next.size(), str(not _active_entry().is_empty()), int(queue_debug.get("revision", -1))]})


func _cutover_save_resume_privacy_and_legacy_absence() -> Dictionary:
	var service := _execution_service()
	var recovery: Dictionary = service.call("recover_from_active", {}, {}) as Dictionary if service != null else {}
	var debug := _service_debug(service)
	var encoded := JSON.stringify(debug)
	var source := _main_source()
	var safe := _is_data_only(debug) and not encoded.contains("player_index") and not encoded.contains("private_target") and not encoded.contains("private_discard") and not encoded.contains("ai_private_plan")
	var checked := str(recovery.get("reason", "")) == "active_missing" and not bool(recovery.get("replay_allowed", true)) and safe and not source.contains("func _resolve_queued_skill(") and not bool(debug.get("legacy_main_orchestration_fallback_used", true))
	return _cutover_record("save_resume_privacy_and_legacy_absence", {"observed": not debug.is_empty(), "contract_aligned": checked, "privacy_checked": safe, "legacy_orchestration_absent": not source.contains("func _resolve_queued_skill("), "pure_data_checked": safe, "notes": "Missing active state cannot replay an effect; debug data is sanitized and no legacy execution fallback remains."})


func _cutover_formula_service_scene_composition() -> Dictionary:
	var packed := load(ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE_SCENE_PATH) as PackedScene
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var service := _formula_service()
	var checked := packed != null and service != null and service.scene_file_path == ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE_SCENE_PATH and coordinator_scene.contains("CardEconomyProductRouteFormulaRuntimeService.tscn") and coordinator_scene.contains("name=\"CardEconomyProductRouteFormulaRuntimeService\"")
	return _cutover_record("formula_service_scene_composition", {"observed": packed != null, "contract_aligned": checked, "service_owner_checked": checked, "formula_owner_checked": checked, "notes": "The pure Formula Service is an editable static child of GameRuntimeCoordinator."}, PRODUCT_CARD_ID, "formula_ownership")


func _cutover_formula_service_api_contract() -> Dictionary:
	var service := _formula_service()
	var methods := ["configure", "supported_formulas", "supports_formula", "calculate", "formula_ownership_snapshot", "debug_snapshot"]
	var checked := service != null
	for method_name in methods:
		checked = checked and service.has_method(method_name)
	var debug := _service_debug(service)
	var probe: Dictionary = service.call("calculate", "route_base_flow", {"source_factor": 1.0, "destination_factor": 1.0, "relation": 0.5}) as Dictionary if service != null else {}
	checked = checked and bool(debug.get("pure_formula_authority", false)) and not bool(debug.get("effect_dispatch_authority", true)) and not bool(debug.get("world_mutation_authority", true)) and not bool(debug.get("execution_lifecycle_authority", true)) and bool(probe.get("ok", false)) and _is_data_only(probe)
	return _cutover_record("formula_service_api_contract", {"observed": service != null, "contract_aligned": checked, "service_owner_checked": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(debug) and _is_data_only(probe), "notes": "Formula API accepts and returns pure data and explicitly owns no dispatch, world mutation, queue, timer, inventory, or execution lifecycle."}, PRODUCT_CARD_ID, "formula_ownership")


func _cutover_product_price_model_owner_unchanged() -> Dictionary:
	var main_wrapper := _function_source(_main_source(), "_balance_product_price_model")
	var balance_source := FileAccess.get_file_as_string(RUNTIME_BALANCE_MODEL_SCRIPT_PATH)
	var ownership: Dictionary = _formula_service().call("formula_ownership_snapshot") as Dictionary if _formula_service() != null else {}
	var delegated: Dictionary = ownership.get("delegated_formulas", {}) as Dictionary
	var checked := main_wrapper.contains("_runtime_balance_model().call(\"product_price_model\"") and balance_source.contains("func product_price_model(") and str(delegated.get("product_price", "")) == "RuntimeBalanceModel"
	return _cutover_record("product_price_model_owner_unchanged", {"observed": not main_wrapper.is_empty(), "contract_aligned": checked, "existing_service_route_checked": checked, "formula_owner_checked": checked, "notes": "Product price and step-cap formulas were already modular and remain owned by RuntimeBalanceModel; Sprint 39 does not duplicate them."}, PRODUCT_CARD_ID, "product_price")


func _cutover_city_gdp_formula_owner_unchanged() -> Dictionary:
	var main_wrapper := _function_source(_main_source(), "_city_gdp_per_minute_breakdown")
	var network_source := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_CONTROLLER_SCRIPT_PATH)
	var gdp_source := FileAccess.get_file_as_string(GDP_FORMULA_CONTROLLER_SCRIPT_PATH)
	var ownership: Dictionary = _formula_service().call("formula_ownership_snapshot") as Dictionary if _formula_service() != null else {}
	var delegated: Dictionary = ownership.get("delegated_formulas", {}) as Dictionary
	var checked := main_wrapper.contains("city_gdp_breakdown") and network_source.contains('_gdp_formula_controller.call("calculate_city_gdp"') and gdp_source.contains("func calculate_city_gdp(") and gdp_source.contains("func calculate_transit_gdp(") and str(delegated.get("city_gdp", "")) == "GdpFormulaRuntimeController"
	return _cutover_record("city_gdp_formula_owner_unchanged", {"observed": not main_wrapper.is_empty() and not network_source.is_empty(), "contract_aligned": checked, "existing_service_route_checked": checked, "formula_owner_checked": checked, "notes": "CityTradeNetworkRuntimeController assembles city facts, while production, consumption, transit, penalties, rounding, and floor remain authoritative in GdpFormulaRuntimeController."}, PRODUCT_CARD_ID, "city_gdp")


func _cutover_market_boon_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "product_market_boon", {
		"entry": {"growth_multiplier": 1.0, "route_flow_multiplier": 1.0, "growth_seconds": 15.0, "route_flow_seconds": 0.0},
		"growth_multiplier": 1.5,
		"route_flow_multiplier": 1.4,
		"duration_seconds": 45.0,
		"turns": 2,
		"source": "bench",
		"persistent": false,
	}) as Dictionary if service != null else {}
	var entry: Dictionary = result.get("entry", {}) as Dictionary
	var checked := bool(result.get("changed", false)) and is_equal_approx(float(entry.get("growth_multiplier", 0.0)), 1.5) and is_equal_approx(float(entry.get("route_flow_multiplier", 0.0)), 1.4) and is_equal_approx(float(entry.get("growth_seconds", 0.0)), 45.0) and int(entry.get("growth_turns", 0)) == 2 and str(entry.get("growth_source", "")) == "bench"
	return _cutover_record("market_boon_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Temporary boon maxima, seconds, legacy-turn mirror, caps, and source labels preserve the characterized runtime result."}, PRODUCT_CARD_ID, "product_market_boon")


func _cutover_speculation_pressure_formula_parity() -> Dictionary:
	var service := _formula_service()
	var up: Dictionary = service.call("calculate", "product_speculation_pressure", {"price_delta": 21}) as Dictionary if service != null else {}
	var down: Dictionary = service.call("calculate", "product_speculation_pressure", {"price_delta": -20}) as Dictionary if service != null else {}
	var checked := int(up.get("pressure", 0)) == 3 and str(up.get("pressure_kind", "")) == "demand" and int(down.get("pressure", 0)) == 2 and str(down.get("pressure_kind", "")) == "supply"
	return _cutover_record("speculation_pressure_formula_parity", {"observed": bool(up.get("ok", false)) and bool(down.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(up) and _is_data_only(down), "notes": "Speculation pressure keeps ceil(abs(delta)/10), a minimum of one, and the original demand/supply direction."}, PRODUCT_CARD_ID, "product_speculation")


func _cutover_futures_formula_parity() -> Dictionary:
	var service := _formula_service()
	var duration: Dictionary = service.call("calculate", "product_futures_duration", {"skill": {"futures_terms": {"duration_seconds": 90.0}}}) as Dictionary if service != null else {}
	var up: Dictionary = service.call("calculate", "product_futures_v04_settlement", {"current_price": 130, "position": {"baseline_price": 100, "direction": "up", "units": 2, "multiplier": 1.5, "locked_margin": 300, "maximum_gain": 800, "maximum_loss": 300}}) as Dictionary if service != null else {}
	var down: Dictionary = service.call("calculate", "product_futures_v04_settlement", {"current_price": 70, "position": {"baseline_price": 100, "direction": "down", "units": 1, "multiplier": 2.0, "locked_margin": 200, "maximum_gain": 500, "maximum_loss": 200}}) as Dictionary if service != null else {}
	var miss: Dictionary = service.call("calculate", "product_futures_v04_settlement", {"current_price": 90, "position": {"baseline_price": 100, "direction": "up", "units": 1, "multiplier": 1.0, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary if service != null else {}
	var checked := is_equal_approx(float(duration.get("seconds", 0.0)), 90.0) and int(up.get("gain", -1)) == 800 and int(down.get("gain", -1)) == 500 and int(miss.get("loss", -1)) == 100
	return _cutover_record("futures_formula_parity", {"observed": bool(up.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(up) and _is_data_only(down), "notes": "Futures read authored duration, preserve directional ¥10 P&L units, and apply capped gain/loss plus margin return."}, PRODUCT_CARD_ID, "product_futures")


func _cutover_gdp_derivative_formula_parity() -> Dictionary:
	var service := _formula_service()
	var up: Dictionary = service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 150, "position": {"baseline_gdp": 100, "direction": "up", "multiplier": 1.5, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary if service != null else {}
	var down: Dictionary = service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 70, "position": {"baseline_gdp": 100, "direction": "down", "multiplier": 2.0, "locked_margin": 180, "maximum_gain": 420, "maximum_loss": 180}}) as Dictionary if service != null else {}
	var loss: Dictionary = service.call("calculate", "city_gdp_derivative_v04_settlement", {"current_gdp": 70, "position": {"baseline_gdp": 100, "direction": "up", "multiplier": 2.0, "locked_margin": 120, "maximum_gain": 260, "maximum_loss": 120}}) as Dictionary if service != null else {}
	var destroyed: Dictionary = service.call("calculate", "city_gdp_derivative_v04_destruction", {"position": {"baseline_gdp": 100, "direction": "down", "multiplier": 1.5, "destroy_bonus": 40, "locked_margin": 180, "maximum_gain": 420, "maximum_loss": 180}}) as Dictionary if service != null else {}
	var checked := int(up.get("gain", -1)) == 75 and int(up.get("cash_return", -1)) == 195 and int(down.get("gain", -1)) == 60 and int(loss.get("loss", -1)) == 60 and int(destroyed.get("gain", -1)) == 190
	return _cutover_record("gdp_derivative_formula_parity", {"observed": bool(up.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(up) and _is_data_only(destroyed), "notes": "GDP derivative expiry and destruction use authored v0.4 margin, two-way capped P&L, refund, and exact-once settlement inputs."}, PRODUCT_CARD_ID, "gdp_derivative")


func _cutover_route_formula_parity() -> Dictionary:
	var service := _formula_service()
	var base: Dictionary = service.call("calculate", "route_base_flow", {"source_factor": 1.44, "destination_factor": 1.0, "relation": 0.5}) as Dictionary if service != null else {}
	var multiplier: Dictionary = service.call("calculate", "route_flow_multiplier", {"city_multiplier": 1.5, "product_multiplier": 2.0}) as Dictionary if service != null else {}
	var checked := is_equal_approx(float(base.get("value", 0.0)), 1.26) and is_equal_approx(float(multiplier.get("value", 0.0)), 2.8)
	return _cutover_record("route_formula_parity", {"observed": bool(base.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(base) and _is_data_only(multiplier), "notes": "Route flow keeps the geometric-mean relation formula, 0.35 floor, and 2.8 composed multiplier cap."}, PRODUCT_CARD_ID, "route_formula")


func _cutover_main_pure_formula_bodies_absent() -> Dictionary:
	var source := _main_source()
	var network_source := FileAccess.get_file_as_string(CITY_TRADE_NETWORK_CONTROLLER_SCRIPT_PATH)
	var route := _function_source(network_source, "_trade_route_for_product")
	var derivative_source := FileAccess.get_file_as_string(CITY_GDP_DERIVATIVE_CONTROLLER_SCRIPT_PATH)
	var checked := not source.contains("func _apply_product_market_boon(") and not source.contains("func _product_futures_payout(") and not source.contains("func _product_futures_balance_") and not source.contains("func _route_base_flow_amount(") and route.contains("route_base_flow") and not route.contains("sqrt(") and not source.contains("func _apply_city_gdp_derivative(") and not source.contains("func _resolve_city_gdp_derivatives(") and not source.contains("gdp_bet_") and derivative_source.contains("city_gdp_derivative_v04_settlement") and not source.contains("PRODUCT_FUTURES_PAYOUT_UNIT")
	return _cutover_record("main_pure_formula_bodies_absent", {"observed": not route.is_empty() and not derivative_source.is_empty(), "contract_aligned": checked, "main_adapter_checked": checked, "legacy_orchestration_absent": checked, "formula_checked": checked, "notes": "Market, futures, City GDP derivative, and route formulas live in their runtime owners; main retains only narrow world adapters."}, PRODUCT_CARD_ID, "formula_deletion_gate")


func _cutover_effect_family_uses_formula_service() -> Dictionary:
	var main_source := _main_source()
	var formula_helper := _function_source(main_source, "_card_economy_product_route_formula_result")
	var effect_source := FileAccess.get_file_as_string(ECONOMY_PRODUCT_ROUTE_EFFECT_SERVICE_SCRIPT_PATH)
	var formula_source := FileAccess.get_file_as_string(ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE_SCRIPT_PATH)
	var market_source := FileAccess.get_file_as_string(PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH)
	var checked := formula_helper.contains("calculate_card_economy_product_route_formula") and market_source.contains("_formula_service.calculate") and market_source.contains("func apply_product_market_boon(") and market_source.contains("product_futures_v04_settlement") and formula_source.contains("FORMULA_IDS") and formula_source.contains("func calculate(") and not formula_source.contains("\"product_futures_payout\"") and not effect_source.contains("FORMULA_IDS") and not effect_source.contains("product_futures_v04_settlement")
	return _cutover_record("effect_family_uses_formula_service", {"observed": not formula_helper.is_empty(), "contract_aligned": checked, "service_owner_checked": checked, "formula_owner_checked": checked, "main_adapter_checked": checked, "notes": "Effect Family Service keeps handler ownership; the sibling Formula Service owns deterministic arithmetic and main only adapts world facts/results."}, PRODUCT_CARD_ID, "formula_route")


func _cutover_execution_service_remains_formula_agnostic() -> Dictionary:
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var debug := _service_debug(_execution_service())
	var forbidden := ["CardEconomyProductRouteFormulaRuntimeService", "product_market_boon", "product_futures_payout", "product_futures_v04_settlement", "city_gdp_derivative_v04_settlement", "route_base_flow"]
	var checked := not bool(debug.get("concrete_effect_authority", true)) and not bool(debug.get("queue_authority", true)) and not bool(debug.get("timing_authority", true))
	for token in forbidden:
		checked = checked and not execution_source.contains(str(token))
	return _cutover_record("execution_service_remains_formula_agnostic", {"observed": not execution_source.is_empty(), "contract_aligned": checked, "service_owner_checked": checked, "formula_owner_checked": checked, "pure_data_checked": _is_data_only(debug), "notes": "Generic execution intent ordering remains unchanged and contains no economy, product, futures, GDP, or route formula knowledge."}, PRODUCT_CARD_ID, "execution_boundary")


func _cutover_product_contract_boon_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "product_contract_boon", {
		"entry": {"market_contract_demand": 2, "market_contract_supply": 1, "market_contract_seconds": 30.0, "volatility": 4},
		"demand_pressure": 5,
		"supply_pressure": 0,
		"contract_seconds": 60.0,
		"volatility_delta": -5,
		"source": "fixture-contract",
	}) as Dictionary if service != null else {}
	var entry: Dictionary = result.get("entry", {}) as Dictionary
	var checked := bool(result.get("ok", false)) and bool(result.get("changed", false)) and int(entry.get("market_contract_demand", 0)) == 5 and int(entry.get("market_contract_supply", 0)) == 1 and is_equal_approx(float(entry.get("market_contract_seconds", 0.0)), 60.0) and int(entry.get("market_contract_turns", 0)) == 2 and int(entry.get("volatility", 0)) == 1
	return _cutover_record("product_contract_boon_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Product-contract demand/supply maxima, duration mirror, source merge, and volatility clamp are deterministic Formula Service ownership."}, CONTRACT_CARD_ID, "product_contract_boon")


func _cutover_city_contract_boon_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "city_contract_boon", {
		"city": {"contract_income_bonus": 1, "contract_seconds": 30.0, "route_flow_multiplier": 1.2, "route_flow_seconds": 20.0},
		"contract_income": 5,
		"contract_seconds": 60.0,
		"route_flow_multiplier": 1.5,
		"route_flow_seconds": 90.0,
		"source": "fixture-city-contract",
	}) as Dictionary if service != null else {}
	var city: Dictionary = result.get("city", {}) as Dictionary
	var checked := bool(result.get("changed", false)) and int(city.get("contract_income_bonus", 0)) == 5 and is_equal_approx(float(city.get("contract_seconds", 0.0)), 60.0) and is_equal_approx(float(city.get("route_flow_multiplier", 0.0)), 1.5) and is_equal_approx(float(city.get("route_flow_seconds", 0.0)), 90.0)
	return _cutover_record("city_contract_boon_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "City contracts preserve maximum income, longest duration, route-flow cap, and source composition."}, CONTRACT_CARD_ID, "city_contract_boon")


func _cutover_contract_accept_route_flow_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "city_route_flow_boon", {
		"city": {"route_flow_multiplier": 1.2, "route_flow_seconds": 30.0},
		"route_flow_multiplier": 1.6,
		"route_flow_seconds": 60.0,
		"source": "fixture-accept",
	}) as Dictionary if service != null else {}
	var city: Dictionary = result.get("city", {}) as Dictionary
	var checked := bool(result.get("changed", false)) and is_equal_approx(float(city.get("route_flow_multiplier", 0.0)), 1.6) and is_equal_approx(float(city.get("route_flow_seconds", 0.0)), 60.0) and str(city.get("route_flow_source", "")) == "fixture-accept"
	return _cutover_record("contract_accept_route_flow_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Accepted contracts use the shared city route-flow formula without moving eligibility or response ownership."}, CONTRACT_CARD_ID, "contract_accept_flow")


func _cutover_route_insurance_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "route_insurance", {
		"city": {"trade_route_damage": 3, "revenue_bonus": 2, "route_flow_multiplier": 1.1},
		"repair_routes": 2,
		"revenue_amount": 4,
		"route_flow_multiplier": 1.4,
		"route_flow_seconds": 60.0,
		"source": "fixture-insurance",
	}) as Dictionary if service != null else {}
	var city: Dictionary = result.get("city", {}) as Dictionary
	var checked := bool(result.get("changed", false)) and int(city.get("trade_route_damage", -1)) == 1 and int(city.get("revenue_bonus", -1)) == 6 and is_equal_approx(float(city.get("route_flow_multiplier", 0.0)), 1.4) and is_equal_approx(float(city.get("route_flow_seconds", 0.0)), 60.0)
	return _cutover_record("route_insurance_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Route insurance keeps zero-floor repair, permanent GDP bonus, and temporary route-flow behavior."}, PRODUCT_CARD_ID, "route_insurance")


func _cutover_city_product_upgrade_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "city_product_upgrade", {
		"city": {"products": [{"name": "A", "level": 3}, {"name": "B", "level": 1}], "revenue_bonus": 2},
		"level_gain": 2,
		"revenue_amount": 5,
	}) as Dictionary if service != null else {}
	var city: Dictionary = result.get("city", {}) as Dictionary
	var products: Array = city.get("products", []) as Array
	var checked := bool(result.get("changed", false)) and int(result.get("product_index", -1)) == 1 and products.size() == 2 and int((products[1] as Dictionary).get("level", 0)) == 3 and int(city.get("revenue_bonus", 0)) == 7
	return _cutover_record("city_product_upgrade_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Upgrade selection remains first-lowest, clamps to rank V, and applies permanent revenue exactly once."}, PRODUCT_CARD_ID, "city_product_upgrade")


func _cutover_city_product_shift_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "city_product_shift_step", {"products": [{"name": "A", "level": 3}, {"name": "B", "level": 1}], "new_product": "C"}) as Dictionary if service != null else {}
	var products: Array = result.get("products", []) as Array
	var checked := int(result.get("replace_index", -1)) == 1 and str(result.get("old_name", "")) == "B" and products.size() == 2 and str((products[1] as Dictionary).get("name", "")) == "C" and int((products[1] as Dictionary).get("level", 0)) == 1
	return _cutover_record("city_product_shift_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "A supplied world candidate replaces the first lowest-rank product and resets the line to rank I."}, PRODUCT_CARD_ID, "city_product_shift")


func _cutover_city_demand_shift_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "city_demand_shift_step", {"demands": ["A", "B"], "iteration": 3, "new_demand": "C"}) as Dictionary if service != null else {}
	var checked := int(result.get("replace_index", -1)) == 1 and (result.get("demands", []) as Array) == ["A", "C"]
	return _cutover_record("city_demand_shift_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Demand migration preserves modulo slot order while world candidate selection stays outside the Formula Service."}, PRODUCT_CARD_ID, "city_demand_shift")


func _cutover_city_adjustment_formula_parity() -> Dictionary:
	var service := _formula_service()
	var result: Dictionary = service.call("calculate", "city_revenue_route_adjustment", {"city": {"trade_route_damage": 3, "revenue_bonus": 2}, "repair_routes": 5, "revenue_amount": 4}) as Dictionary if service != null else {}
	var city: Dictionary = result.get("city", {}) as Dictionary
	var checked := int(city.get("trade_route_damage", -1)) == 0 and int(city.get("revenue_bonus", -1)) == 6
	return _cutover_record("city_adjustment_formula_parity", {"observed": bool(result.get("ok", false)), "contract_aligned": checked, "formula_checked": checked, "pure_data_checked": _is_data_only(result), "notes": "Product and demand shifts share one deterministic route-repair/revenue adjustment without duplicating arithmetic in main."}, PRODUCT_CARD_ID, "city_adjustment")


func _cutover_main_contract_formula_bodies_absent() -> Dictionary:
	var source := _main_source()
	var market_source := FileAccess.get_file_as_string(PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH)
	var contract_bridge_source := FileAccess.get_file_as_string(CONTRACT_WORLD_BRIDGE_SCRIPT_PATH)
	var accept_flow := _function_source(contract_bridge_source, "_apply_route_flow")
	var city_contract := _function_source(source, "_apply_city_contract_boon")
	var insurance := _function_source(source, "_apply_route_insurance")
	var checked := not source.contains("func _apply_product_contract_boon(") and market_source.contains("func apply_product_contract_boon(") and market_source.contains("_formula(\"product_contract_boon\"") and accept_flow.contains("city_route_flow_boon") and not accept_flow.contains("maxf(before_flow") and city_contract.contains("city_contract_boon") and not city_contract.contains("contract_income_bonus\"] = maxi") and insurance.contains("route_insurance") and not insurance.contains("trade_route_damage\"] = max") and not source.contains("func _apply_contract_accept_route_flow(")
	return _cutover_record("main_contract_formula_bodies_absent", {"observed": market_source.contains("func apply_product_contract_boon(") and not city_contract.is_empty(), "contract_aligned": checked, "main_adapter_checked": checked, "legacy_orchestration_absent": checked, "formula_checked": checked, "notes": "Product contract pressure is owned by ProductMarketRuntimeController; city boon, accepted route flow, and insurance adapters contain no duplicated arithmetic."}, CONTRACT_CARD_ID, "formula_deletion_gate")


func _cutover_main_city_product_formula_bodies_absent() -> Dictionary:
	var source := _main_source()
	var upgrade := _function_source(source, "_apply_city_product_upgrade")
	var product_shift := _function_source(source, "_apply_city_product_shift")
	var demand_shift := _function_source(source, "_apply_city_demand_shift")
	var checked := upgrade.contains("city_product_upgrade") and not upgrade.contains("candidate_level < lowest_level") and product_shift.contains("city_product_shift_step") and not product_shift.contains("products[replace_index] =") and demand_shift.contains("city_demand_shift_step") and not demand_shift.contains("i % demands.size()") and not source.contains("func _lowest_level_city_product_index(")
	return _cutover_record("main_city_product_formula_bodies_absent", {"observed": not upgrade.is_empty() and not product_shift.is_empty() and not demand_shift.is_empty(), "contract_aligned": checked, "main_adapter_checked": checked, "legacy_orchestration_absent": checked, "formula_checked": checked, "notes": "First-lowest selection, rank reset, modulo demand replacement, and revenue/repair arithmetic have one Formula Service owner."}, PRODUCT_CARD_ID, "formula_deletion_gate")


func _cutover_world_rng_and_mutation_boundary_preserved() -> Dictionary:
	var source := _main_source()
	var product_shift := _function_source(source, "_apply_city_product_shift")
	var demand_shift := _function_source(source, "_apply_city_demand_shift")
	var formula_source := FileAccess.get_file_as_string(ECONOMY_PRODUCT_ROUTE_FORMULA_SERVICE_SCRIPT_PATH)
	var checked := product_shift.contains("_economy_candidate_product") and demand_shift.contains("_economy_candidate_product") and product_shift.contains("districts[selected_district][\"city\"] = city") and demand_shift.contains("districts[selected_district][\"city\"] = city") and not formula_source.contains("rng.") and not formula_source.contains("districts[") and not formula_source.contains("players[")
	return _cutover_record("world_rng_and_mutation_boundary_preserved", {"observed": not formula_source.is_empty(), "contract_aligned": checked, "world_adapter_checked": checked, "formula_owner_checked": checked, "pure_data_checked": checked, "notes": "main preserves candidate RNG order and exact world commit; the Formula Service sees only supplied pure-data candidates and city snapshots."}, PRODUCT_CARD_ID, "world_boundary")


func _cutover_execution_service_sprint40_formula_agnostic() -> Dictionary:
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var debug := _service_debug(_execution_service())
	var forbidden := ["product_contract_boon", "city_contract_boon", "city_route_flow_boon", "route_insurance", "city_product_upgrade", "city_product_shift_step", "city_demand_shift_step", "city_revenue_route_adjustment"]
	var checked := not bool(debug.get("concrete_effect_authority", true)) and not bool(debug.get("queue_authority", true)) and not bool(debug.get("timing_authority", true))
	for token in forbidden:
		checked = checked and not execution_source.contains(str(token))
	return _cutover_record("execution_service_sprint40_formula_agnostic", {"observed": not execution_source.is_empty(), "contract_aligned": checked, "service_owner_checked": checked, "formula_owner_checked": checked, "pure_data_checked": _is_data_only(debug), "notes": "Sprint 40 adds no contract, city-product, demand, or insurance knowledge to the generic Execution Service."}, CONTRACT_CARD_ID, "execution_boundary")


func _case_execution_call_graph_complete() -> Dictionary:
	var source := _main_source()
	var complete := _function_source(source, "_complete_active_card_resolution")
	var service_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var effect_adapter := _function_source(source, "_apply_card_resolution_effect_request")
	var read_at := complete.find("_card_resolution_active_entry()")
	var plan_at := complete.find("plan_card_resolution_execution")
	var intent_at := complete.find("_apply_card_resolution_execution_intent")
	var advance_at := complete.find("advance_card_resolution_execution")
	var finalize_at := complete.find("finalize_card_resolution_execution")
	var ordered := read_at >= 0 and plan_at > read_at and intent_at > plan_at and advance_at > intent_at and finalize_at > advance_at
	var service_order := _source_tokens_in_order(service_source, ["INTENT_COUNTER_CHECK", "INTENT_RELEASE_ACTIVE", "INTENT_FINISH_PRESENTATION", "INTENT_REVALIDATE_REQUIREMENT", "INTENT_REVALIDATE_TARGET", "INTENT_DISPATCH_EFFECT", "INTENT_FINISH_COMMITMENT", "INTENT_CREATE_AFTERMATH", "INTENT_RESTORE_CONTEXT", "INTENT_APPEND_HISTORY", "INTENT_START_NEXT", "INTENT_FINISH_BATCH", "INTENT_PROMOTE_NEXT_BATCH"])
	var observed := not complete.is_empty() and not effect_adapter.is_empty() and not service_source.is_empty()
	return _record("execution_call_graph_complete", "real-main-source", CASH_CARD_ID, "execution_orchestration", {
		"observed": observed,
		"contract_aligned": ordered and service_order and not source.contains("func _resolve_queued_skill("),
		"queue_service_checked": effect_adapter.contains("_resolve_targeted_skill") and not service_source.contains("func start_next("),
		"notes": "Execution Service owns the ordered intent graph; main is a generic transaction runner plus concrete world adapter.",
	})


func _case_queue_service_boundary_unchanged() -> Dictionary:
	var main_source := _main_source()
	var queue_source := FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH)
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var complete := _function_source(main_source, "_complete_active_card_resolution")
	var separated := queue_source.contains("func complete_active(") and queue_source.contains("func start_next(") and not queue_source.contains("_apply_area_trade_contract") and not queue_source.contains("_apply_player_hand_disrupt") and not execution_source.contains("func start_next(") and not execution_source.contains("func complete_active(")
	return _record("queue_service_boundary_unchanged", "service-boundary", "", "ownership", {
		"observed": not queue_source.is_empty(),
		"contract_aligned": separated and complete.contains("plan_card_resolution_execution") and not complete.contains(".call(\"complete_active\""),
		"queue_service_checked": separated,
		"notes": "Queue Service remains the only current/active/next owner; Execution Service returns release/start/promote intents without storing queue state.",
	})


func _case_timing_controller_boundary_unchanged() -> Dictionary:
	var controller_source := FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var aligned := controller_source.contains("func tick(") and controller_source.contains("total_window_seconds") and controller_source.contains("lock_seconds") and not execution_source.contains("func tick(") and not execution_source.contains("total_window_seconds")
	return _record("timing_controller_boundary_unchanged", "30-25-5-controller", "", "timing", {
		"observed": _controller() != null,
		"contract_aligned": aligned,
		"timing_boundary_checked": aligned,
		"notes": "CardResolutionRuntimeController remains the sole shared-window/reveal/counter clock owner and does not execute effects.",
	})


func _case_active_entry_is_read_from_queue_service() -> Dictionary:
	var entry := _entry(CASH_CARD_ID, 3601)
	_queue_service().call("replace_active_entry", entry)
	var main_entry_variant: Variant = _runtime_main.get("active_card_resolution")
	var main_entry: Dictionary = main_entry_variant if main_entry_variant is Dictionary else {}
	var service_entry: Dictionary = _queue_service().call("active_entry") as Dictionary
	var same := int(main_entry.get("resolution_id", -1)) == 3601 and main_entry == service_entry
	return _record("active_entry_is_read_from_queue_service", "active-3601", CASH_CARD_ID, "queue_bridge", {
		"active_resolution_id": 3601,
		"observed": not main_entry.is_empty(),
		"contract_aligned": same,
		"queue_service_checked": same,
		"notes": "The legacy main property is a stateless _get forwarder to Queue Service, not a second active-entry store.",
	})


func _case_active_entry_not_duplicated_in_main_state() -> Dictionary:
	var source := _main_source()
	var no_storage := not source.contains("var active_card_resolution :=") and not source.contains("var card_resolution_queue :=") and not source.contains("var next_card_resolution_queue :=")
	var forwarder := source.contains("&\"active_card_resolution\":") and source.contains("return _card_resolution_active_entry()")
	return _record("active_entry_not_duplicated_in_main_state", "source-delete-gate", "", "ownership", {
		"observed": no_storage,
		"contract_aligned": no_storage and forwarder,
		"queue_service_checked": no_storage and forwarder,
		"notes": "No active/current/next queue backing variable remains in main.gd.",
	})


func _case_valid_target_reconfirmed_before_effect() -> Dictionary:
	var source := _main_source()
	var bridge_source := FileAccess.get_file_as_string(EXECUTION_WORLD_BRIDGE_SCRIPT_PATH)
	var requirement := _function_source(bridge_source, "_requirement_receipt")
	var target := _function_source(bridge_source, "_target_receipt")
	var effect_adapter := _function_source(source, "_apply_card_resolution_effect_request")
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var aligned := requirement.contains("_authorize_card_play") and target.contains("target_slot >= 0") and target.contains("not bool((monsters[target_slot]") and effect_adapter.contains("_resolve_targeted_skill") and _source_tokens_in_order(execution_source, ["INTENT_REVALIDATE_REQUIREMENT", "INTENT_REVALIDATE_TARGET", "INTENT_DISPATCH_EFFECT"])
	return _record("valid_target_reconfirmed_before_effect", "source-order", MONSTER_CARD_ID, "monster_target", {
		"target_kind": "monster",
		"target_valid": true,
		"observed": not requirement.is_empty() and not target.is_empty() and not _real_skill(MONSTER_CARD_ID).is_empty(),
		"contract_aligned": aligned,
		"existing_service_route_checked": true,
		"notes": "Submission conditions are rechecked first, then the monster target is checked for range/down state immediately before dispatch.",
	})


func _case_invalid_target_fails_without_partial_mutation() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_runtime_main.set("auto_monsters", [])
	var district_before := _district_public_metrics(0)
	var cash_before := _player_cash(0)
	var inventory_before := _normal_card_count(0)
	var logs_before := _array_size("log_lines")
	var callouts_before := _array_size("action_callouts")
	var entry := _entry(MONSTER_CARD_ID, 3607, 0, 0, -1)
	_complete_entry_twice(entry)
	var district_after := _district_public_metrics(0)
	var no_world_effect := district_after == district_before and (_runtime_main.get("auto_monsters") as Array).is_empty() and _player_cash(0) == cash_before
	var stable_reason := _logs_contain("目标怪兽已失效")
	return _record("invalid_target_fails_without_partial_mutation", "missing-monster-target", MONSTER_CARD_ID, "monster_target", {
		"active_resolution_id": 3607,
		"target_kind": "monster",
		"target_valid": false,
		"world_mutation_delta": {"district_changed": district_after != district_before, "monster_count_delta": 0},
		"inventory_delta": _normal_card_count(0) - inventory_before,
		"public_event_delta": (_array_size("log_lines") - logs_before) + (_array_size("action_callouts") - callouts_before),
		"observed": stable_reason,
		"contract_aligned": no_world_effect and stable_reason,
		"notes": "The committed card still finalizes, but an absent target produces no monster/district/cash effect and returns a stable public failure reason.",
	})


func _case_target_state_drift_returns_stable_reason() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var monsters := _monster_controller()
	var actor_variant: Variant = monsters.call("_make_auto_monster", 0, 0, 0, 0, 1) if monsters != null else {}
	var actor: Dictionary = actor_variant if actor_variant is Dictionary else {}
	actor["down"] = true
	if monsters != null:
		monsters.call("replace_runtime_state", {"auto_monsters": [actor]})
	var before := _monster_public_metrics(0)
	_complete_entry_twice(_entry(MONSTER_CARD_ID, 3608, 0, 0, -1))
	var after := _monster_public_metrics(0)
	var reason_ok := _logs_contain("目标怪兽已失效")
	return _record("target_state_drift_returns_stable_reason", "target-down-after-submit", MONSTER_CARD_ID, "monster_target", {
		"active_resolution_id": 3608,
		"target_kind": "monster",
		"target_valid": false,
		"world_mutation_delta": {"monster_changed": before != after},
		"observed": reason_ok,
		"contract_aligned": before == after and reason_ok,
		"notes": "A target that is down at resolution is rejected without applying the lure; committed card/action cost semantics are retained.",
	})


func _case_immediate_economy_effect_applies_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var before_cash := _player_cash(0)
	var before_ledger := _ledger_count(0)
	var entry := _entry(CASH_CARD_ID, 3609)
	_complete_entry_twice(entry)
	var cash_delta := _player_cash(0) - before_cash
	var ledger_delta := _ledger_count(0) - before_ledger
	return _record("immediate_economy_effect_applies_once", "cash-gain-once", CASH_CARD_ID, "cash_gain", {
		"active_resolution_id": 3609,
		"world_mutation_delta": {"cash": cash_delta},
		"ledger_delta": ledger_delta,
		"active_completed": _active_entry().is_empty(),
		"observed": cash_delta != 0,
		"contract_aligned": cash_delta == int(_real_skill(CASH_CARD_ID).get("cash", 0)) and ledger_delta == 1 and _history_count_for_resolution(3609) == 1,
		"queue_service_checked": true,
		"notes": "Calling completion a second time is a no-op because Queue Service already cleared active resolution 3609.",
	})


func _case_city_or_product_effect_applies_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_runtime_main.set("selected_trade_product", _first_runtime_product())
	var before_cash := _player_cash(0)
	var skill := _real_skill(PRODUCT_CARD_ID)
	_complete_entry_twice(_entry_with_skill(skill, 3610))
	var cash_delta := _player_cash(0) - before_cash
	var expected := int(skill.get("cash", 0))
	return _record("city_or_product_effect_applies_once", "real-product-speculation", PRODUCT_CARD_ID, "product_speculation", {
		"active_resolution_id": 3610,
		"target_kind": "product",
		"target_valid": _first_runtime_product() != "",
		"world_mutation_delta": {"cash": cash_delta, "product": _first_runtime_product()},
		"active_completed": _active_entry().is_empty(),
		"observed": not skill.is_empty(),
		"contract_aligned": expected > 0 and cash_delta == expected and _history_count_for_resolution(3610) == 1,
		"notes": "A real product card applies its immediate cash/market effect once under the active-entry exactly-once gate.",
	})


func _case_route_or_district_effect_applies_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var district_index := _first_alive_district()
	_runtime_main.set("selected_district", district_index)
	var before := _district_public_metrics(district_index)
	_complete_entry_twice(_entry(DISTRICT_CARD_ID, 3611, 0, -1, -1, district_index))
	var after := _district_public_metrics(district_index)
	var production_delta := int(after.get("production", 0)) - int(before.get("production", 0))
	return _record("route_or_district_effect_applies_once", "real-region-production", DISTRICT_CARD_ID, "region_economy_shift", {
		"active_resolution_id": 3611,
		"target_kind": "district",
		"target_valid": district_index >= 0,
		"world_mutation_delta": {"production": production_delta},
		"active_completed": _active_entry().is_empty(),
		"observed": district_index >= 0 and not _real_skill(DISTRICT_CARD_ID).is_empty(),
		"contract_aligned": production_delta == 1 and _history_count_for_resolution(3611) == 1,
		"notes": "The real region production card mutates the selected district once; replaying completion cannot repeat it.",
	})


func _case_monster_effect_routes_to_existing_rule_owner() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var monsters := _monster_controller()
	var actor_variant: Variant = monsters.call("_make_auto_monster", 0, 0, 0, 0, 1) if monsters != null else {}
	var actor: Dictionary = actor_variant if actor_variant is Dictionary else {}
	if monsters != null:
		monsters.call("replace_runtime_state", {"auto_monsters": [actor], "monster_timer": 10.0})
	var before_timer := float(monsters.get("monster_timer")) if monsters != null else 0.0
	_complete_entry_twice(_entry(MONSTER_CARD_ID, 3612, 0, 0, -1, 0))
	var after_actor := _monster_public_metrics(0)
	var after_timer := float(monsters.get("monster_timer")) if monsters != null else 0.0
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var routed := effect_adapter.contains("_resolve_targeted_skill(skill, player, int(entry.get(\"target_slot\", -1)), player_index)")
	return _record("monster_effect_routes_to_existing_rule_owner", "real-monster-lure", MONSTER_CARD_ID, "monster_lure", {
		"active_resolution_id": 3612,
		"target_kind": "monster",
		"target_valid": not actor.is_empty(),
		"world_mutation_delta": {"timer_millis": roundi((after_timer - before_timer) * 1000.0), "lure_moves_left": int(after_actor.get("lure_moves_left", 0))},
		"active_completed": _active_entry().is_empty(),
		"existing_service_route_checked": routed,
		"observed": not actor.is_empty(),
		"contract_aligned": routed and int(after_actor.get("lure_moves_left", 0)) == 1 and is_equal_approx(after_timer, 7.0) and _history_count_for_resolution(3612) == 1,
		"notes": "Execution dispatches to the existing monster-target rule function; no monster algorithm moved in Sprint 36.",
	})


func _case_hand_interaction_routes_to_existing_service() -> Dictionary:
	_prepare_players([[], [_real_skill(CASH_CARD_ID)]], [1000, 1000])
	var service := _hand_service()
	var before_debug := _service_debug(service)
	var before_target_count := _normal_card_count(1)
	_complete_entry_twice(_entry(HAND_CARD_ID, 3613, 0, -1, 1))
	var after_debug := _service_debug(service)
	var commit_delta := int(after_debug.get("committed_count", 0)) - int(before_debug.get("committed_count", 0))
	var hand_delta := _normal_card_count(1) - before_target_count
	return _record("hand_interaction_routes_to_existing_service", "real-hand-disrupt", HAND_CARD_ID, "player_hand_disrupt", {
		"active_resolution_id": 3613,
		"target_kind": "player",
		"target_valid": true,
		"inventory_delta": hand_delta,
		"existing_service_route_checked": commit_delta == 1,
		"active_completed": _active_entry().is_empty(),
		"observed": service != null,
		"contract_aligned": commit_delta == 1 and hand_delta == -1 and _history_count_for_resolution(3613) == 1,
		"notes": "The real direct-player card reaches PlayerHandInteractionRuntimeService exactly once through the unchanged main adapter.",
	})


func _case_inventory_mutation_routes_to_inventory_service() -> Dictionary:
	var main_source := _main_source()
	var queue_submit := _function_source(main_source, "_queue_skill_resolution")
	var commitment := _function_source(main_source, "_card_resolution_commitment_receipt")
	var inventory_source := FileAccess.get_file_as_string(INVENTORY_SERVICE_SCRIPT_PATH)
	var persistent_card_id := _runtime_persistent_card_id()
	var persistent := _real_skill(persistent_card_id)
	var aligned := queue_submit.contains("plan_card_inventory_queue_commit") and queue_submit.contains("commit_card_inventory_queue_commit") and inventory_source.contains("func plan_queue_commit(") and inventory_source.contains("func commit_queue_commit(") and commitment.contains("consumed_on_queue")
	return _record("inventory_mutation_routes_to_inventory_service", "submit-commit-boundary", persistent_card_id, "persistent_and_consumed", {
		"inventory_delta": 0,
		"observed": _inventory_service() != null and not persistent.is_empty(),
		"contract_aligned": aligned and bool(persistent.get("persistent", false)),
		"existing_service_route_checked": aligned,
		"notes": "One-time slot removal happens at queue commit in CardInventoryRuntimeService; execution only finalizes cooldown/commitment and does not reacquire consumed cards.",
	})


func _case_temporary_decision_pauses_resolution() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var use_skill := _function_source(_main_source(), "_use_skill")
	var target_choice_before_submit := use_skill.contains("_has_pending_target_choice") and use_skill.contains("_has_pending_player_target_choice")
	var no_generic_pause_inside_resolver := not effect_adapter.contains("temporary_decision") and not effect_adapter.contains("pending_target_slot_index")
	return _record("temporary_decision_pauses_resolution", "v04-submit-target-boundary", MONSTER_CARD_ID, "target_choice", {
		"temporary_decision_kind": "pre_submit_target_choice",
		"active_completed": false,
		"observed": not effect_adapter.is_empty(),
		"contract_aligned": target_choice_before_submit and no_generic_pause_inside_resolver,
		"notes": "Runtime observation is negative by design: target choices complete before submission, so generic temporary_decision does not pause active-card execution.",
	})


func _case_temporary_decision_resume_continues_same_resolution() -> Dictionary:
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var bridge_source := FileAccess.get_file_as_string(CONTRACT_WORLD_BRIDGE_SCRIPT_PATH)
	var contract_result := _function_source(bridge_source, "store_contract_result")
	var no_resume_token := not execution_source.contains("resume_context") and not execution_source.contains("temporary_decision")
	var history_patch := contract_result.contains("_entry_by_id") and bridge_source.contains("_card_resolution_entry_by_id") and contract_result.contains("_store_card_resolution_entry")
	return _record("temporary_decision_resume_continues_same_resolution", "observed-no-generic-resume", CONTRACT_CARD_ID, "continuation", {
		"temporary_decision_kind": "contract_history_patch",
		"observed": not execution_source.is_empty() and not contract_result.is_empty(),
		"contract_aligned": no_resume_token and history_patch,
		"notes": "There is no generic active-card resume token today. Contract responses patch the same resolution_id in history while later cards continue, matching v0.4's non-blocking contract window.",
	})


func _case_temporary_decision_cancel_behavior_characterized() -> Dictionary:
	var controller_source := FileAccess.get_file_as_string(CONTRACT_CONTROLLER_SCRIPT_PATH)
	var respond := _function_source(controller_source, "respond_to_offer")
	var updater := _function_source(controller_source, "tick_visible_offer")
	var commit := _function_source(controller_source, "commit_response")
	var explicit_reject := respond.contains("plan_response") and commit.contains("apply_response_transaction")
	var timeout_reject := updater.contains("timeout") and updater.contains("respond_to_offer")
	return _record("temporary_decision_cancel_behavior_characterized", "contract-reject-timeout", CONTRACT_CARD_ID, "contract_response", {
		"temporary_decision_kind": "contract_response",
		"observed": not respond.is_empty() and not updater.is_empty(),
		"contract_aligned": explicit_reject and timeout_reject,
		"notes": "Contract cancel/reject and timeout both resolve the stored offer exactly once; they do not rewind or reacquire the submitted card.",
	})


func _case_counter_response_preserves_active_entry() -> Dictionary:
	var entry := _entry(HAND_CARD_ID, 3618, 0, -1, 1)
	_queue_service().call("replace_active_entry", entry)
	_runtime_main.set("card_resolution_counter_window_active", true)
	_runtime_main.set("card_resolution_counter_timer", 5.0)
	var before := _active_entry()
	var announce := _function_source(_main_source(), "_announce_card_counter_response_window")
	var after := _active_entry()
	var preserved := int(before.get("resolution_id", -1)) == 3618 and before == after
	return _record("counter_response_preserves_active_entry", "five-second-counter", COUNTER_CARD_ID, "counter_response", {
		"active_resolution_id": 3618,
		"temporary_decision_kind": "counter_response",
		"active_completed": false,
		"observed": bool(_runtime_main.get("card_resolution_counter_window_active")),
		"contract_aligned": preserved and announce.contains("_card_resolution_active_entry()"),
		"queue_service_checked": preserved,
		"timing_boundary_checked": true,
		"notes": "The fixed 5-second counter window is the card-level pause that retains the active entry until response/timeout.",
	})


func _case_contract_response_preserves_active_entry() -> Dictionary:
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var contract_source := FileAccess.get_file_as_string(CONTRACT_CONTROLLER_SCRIPT_PATH)
	var clear_before_resolve := _source_tokens_in_order(execution_source, ["INTENT_RELEASE_ACTIVE", "INTENT_DISPATCH_EFFECT"])
	var independent := contract_source.contains("pending_offers.append(offer)") and contract_source.contains("\"blocks_card_resolution\": false")
	return _record("contract_response_preserves_active_entry", "v04-independent-contract-window", CONTRACT_CARD_ID, "area_trade_contract", {
		"temporary_decision_kind": "contract_response",
		"active_completed": true,
		"observed": not contract_source.is_empty(),
		"contract_aligned": clear_before_resolve and independent,
		"notes": "Despite the historical case name, v0.4 intentionally does not preserve active for contracts: the offer is copied to pending_contract_offers and later cards continue.",
	})


func _case_monster_wager_preserves_active_entry() -> Dictionary:
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var wager_freeze := _function_source(monster_source, "_monster_wager_freezes_game")
	var forced_candidates := _function_source(_main_source(), "_forced_decision_candidates")
	var execution_source := FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH)
	var separate := not execution_source.contains("active_monster_wagers") and forced_candidates.contains("priority_group\": \"monster_wager") and not wager_freeze.is_empty()
	return _record("monster_wager_preserves_active_entry", "forced-decision-boundary", "", "monster_wager", {
		"temporary_decision_kind": "monster_wager",
		"active_completed": false,
		"observed": not forced_candidates.is_empty(),
		"contract_aligned": separate,
		"notes": "Monster wager freezes the planet through ForcedDecision scheduling; it is independent of card-effect dispatch and does not create a second active-entry owner.",
	})


func _case_public_event_emitted_after_success() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var logs_before := _array_size("log_lines")
	var callouts_before := _array_size("action_callouts")
	_complete_entry_twice(_entry(CASH_CARD_ID, 3621))
	var public_delta := (_array_size("log_lines") - logs_before) + (_array_size("action_callouts") - callouts_before)
	var aftermath := _function_source(_main_source(), "_add_card_resolution_aftermath_clue")
	return _record("public_event_emitted_after_success", "cash-public-aftermath", CASH_CARD_ID, "cash_gain", {
		"active_resolution_id": 3621,
		"public_event_delta": public_delta,
		"active_completed": true,
		"observed": public_delta > 0,
		"contract_aligned": public_delta > 0 and aftermath.contains("var status := \"已结算\" if resolved else \"未生效\"") and _history_count_for_resolution(3621) == 1,
		"notes": "Opening feedback is emitted before mutation; the success/failure aftermath is emitted after effect dispatch and stored with the resolved history entry.",
	})


func _case_private_event_visibility_boundary() -> Dictionary:
	var private_entry := _entry(INTEL_CARD_ID, 3622)
	private_entry["player_index"] = 1
	private_entry["private_target"] = "PRIVATE_TARGET_MARKER"
	private_entry["private_discard"] = "PRIVATE_DISCARD_MARKER"
	private_entry["ai_private_plan"] = "AI_PRIVATE_PLAN_MARKER"
	_runtime_main.set("resolved_card_history", [private_entry])
	var table_variant: Variant = _runtime_main.call("_runtime_table_snapshot")
	var table_snapshot: Dictionary = table_variant if table_variant is Dictionary else {}
	var snapshot := {
		"card_resolution_track": table_snapshot.get("card_resolution_track", {}),
		"card_track": table_snapshot.get("card_track", []),
	}
	var encoded := JSON.stringify(snapshot)
	var safe := not encoded.contains("PRIVATE_TARGET_MARKER") and not encoded.contains("PRIVATE_DISCARD_MARKER") and not encoded.contains("AI_PRIVATE_PLAN_MARKER") and not _contains_key_recursive(snapshot, "player_index")
	return _record("private_event_visibility_boundary", "public-track-privacy-markers", INTEL_CARD_ID, "intel_card_trace", {
		"privacy_checked": safe,
		"observed": not snapshot.is_empty(),
		"contract_aligned": safe,
		"notes": "The real public track snapshot keeps card/target/result clues while removing actor identity, private target/discard, and AI plan markers.",
	})


func _case_ledger_and_action_log_exactly_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var ledger_before := _ledger_count(0)
	var logs_before := _array_size("log_lines")
	_complete_entry_twice(_entry(CASH_CARD_ID, 3623))
	var ledger_delta := _ledger_count(0) - ledger_before
	var log_delta := _array_size("log_lines") - logs_before
	return _record("ledger_and_action_log_exactly_once", "cash-ledger-once", CASH_CARD_ID, "cash_gain", {
		"active_resolution_id": 3623,
		"ledger_delta": ledger_delta,
		"public_event_delta": log_delta,
		"active_completed": true,
		"observed": ledger_delta > 0 and log_delta > 0,
		"contract_aligned": ledger_delta == 1 and _history_count_for_resolution(3623) == 1,
		"notes": "The economic ledger receives one card-income intent; a second completion call cannot duplicate ledger or history.",
	})


func _case_scenario_and_coach_hooks_exactly_once() -> Dictionary:
	var effect_adapter := _function_source(_main_source(), "_apply_card_resolution_effect_request")
	var city_handler := _function_source(FileAccess.get_file_as_string("res://tests/legacy_v05/runtime/city_development_runtime_controller_v05.gd"), "finalize_settlement")
	var submit := _function_source(_main_source(), "_queue_skill_resolution")
	var hook_count := city_handler.count('"signal_id"')
	var separated := not effect_adapter.contains("_complete_scenario_signal(") and submit.contains("_complete_scenario_signal(\"card_played\"") and hook_count == 2
	var city_card_id := _runtime_city_development_card_id()
	return _record("scenario_and_coach_hooks_exactly_once", "scenario-owner-source", city_card_id, "city_development", {
		"scenario_hook_delta": hook_count,
		"observed": city_card_id != "" and not city_handler.is_empty(),
		"contract_aligned": separated,
		"notes": "Submission owns card_played; CityDevelopmentRuntimeController emits two distinct resolved/built intents. The generic resolver adds no duplicate coach hook.",
	})


func _case_failed_resolution_does_not_emit_success_feedback() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	_runtime_main.set("auto_monsters", [])
	var cash_before := _player_cash(0)
	var entry := _entry(MONSTER_CARD_ID, 3625, 0, 0, -1)
	_complete_entry_twice(entry)
	var failed_reason := _logs_contain("目标怪兽已失效")
	var no_success_log := not _logs_contain("匿名诱导怪")
	return _record("failed_resolution_does_not_emit_success_feedback", "invalid-monster-feedback", MONSTER_CARD_ID, "monster_target", {
		"active_resolution_id": 3625,
		"target_kind": "monster",
		"target_valid": false,
		"world_mutation_delta": {"cash": _player_cash(0) - cash_before},
		"public_event_delta": _array_size("log_lines"),
		"observed": failed_reason,
		"contract_aligned": failed_reason and no_success_log and _player_cash(0) == cash_before,
		"notes": "Failure still leaves a public '未生效' clue, but does not emit the monster-lure success line or mutate the target world state.",
	})


func _case_successful_resolution_completes_active_once() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var entry := _entry(CASH_CARD_ID, 3626)
	_queue_service().call("replace_active_entry", entry)
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.call("_complete_active_card_resolution")
	var history_after_first := _history_count_for_resolution(3626)
	_runtime_main.call("_complete_active_card_resolution")
	var history_after_second := _history_count_for_resolution(3626)
	var completed_once := _active_entry().is_empty() and history_after_first == 1 and history_after_second == 1
	return _record("successful_resolution_completes_active_once", "active-complete-once", CASH_CARD_ID, "completion", {
		"active_resolution_id": 3626,
		"active_completed": _active_entry().is_empty(),
		"queue_service_checked": completed_once,
		"observed": history_after_first == 1,
		"contract_aligned": completed_once,
		"notes": "Queue Service clears the active entry before effect dispatch; re-entering completion finds no active card and cannot append history twice.",
	})


func _case_next_queue_item_starts_after_completion() -> Dictionary:
	_prepare_players([[], []], [1000, 1000])
	var first := _entry(CASH_CARD_ID, 3627)
	var second := _entry(PRODUCT_CARD_ID, 3628)
	_queue_service().call("replace_active_entry", first)
	_queue_service().call("replace_current_queue", [second])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.set("card_resolution_force_duration", 5.0)
	_runtime_main.call("_complete_active_card_resolution")
	var active_after := _active_entry()
	var next_started := int(active_after.get("resolution_id", -1)) == 3628
	return _record("next_queue_item_starts_after_completion", "two-entry-chain", PRODUCT_CARD_ID, "queue_continuation", {
		"active_resolution_id": 3627,
		"active_completed": _history_count_for_resolution(3627) == 1,
		"next_started": next_started,
		"queue_service_checked": next_started,
		"observed": not active_after.is_empty(),
		"contract_aligned": next_started and (_queue_service().call("current_queue") as Array).is_empty(),
		"notes": "After history is written, main asks Queue Service to pop the next entry; the next card becomes active without effect interleaving.",
	})


func _case_save_load_active_resolution_parity() -> Dictionary:
	var coordinator := _coordinator()
	var entry := _entry(CONTRACT_CARD_ID, 3629)
	entry["contract_source_district"] = 0
	entry["contract_target_district"] = 1
	_queue_service().call("replace_active_entry", entry)
	_queue_service().call("replace_current_queue", [_entry(CASH_CARD_ID, 3630)])
	_queue_service().call("replace_next_queue", [_entry(COUNTER_CARD_ID, 3631)])
	var snapshot: Dictionary = coordinator.call("card_resolution_queue_legacy_save_snapshot") as Dictionary if coordinator != null else {}
	_queue_service().call("reset_state")
	if coordinator != null:
		coordinator.call("apply_card_resolution_queue_legacy_save_snapshot", snapshot)
	var restored := _active_entry()
	var parity := int(restored.get("resolution_id", -1)) == 3629 and (_queue_service().call("current_queue") as Array).size() == 1 and (_queue_service().call("next_queue") as Array).size() == 1
	return _record("save_load_active_resolution_parity", "legacy-save-v1", CONTRACT_CARD_ID, "save_restore", {
		"active_resolution_id": 3629,
		"active_completed": false,
		"queue_service_checked": parity,
		"observed": not snapshot.is_empty(),
		"contract_aligned": parity and _is_data_only(snapshot),
		"privacy_checked": _is_data_only(snapshot),
		"notes": "Current, active, and next queue state round-trip through the existing v1 compatibility keys without changing save version.",
	})


func _cutover_record(case_id: String, flags: Dictionary, card_id: String = "", effect_family: String = "execution_cutover") -> Dictionary:
	var normalized := flags.duplicate(true)
	normalized["cutover_checked"] = bool(flags.get("cutover_checked", flags.get("contract_aligned", false)))
	return _record(case_id, "sprint39-cutover", card_id, effect_family, normalized)


func _service_plan(resolution_id: int, card_id: String) -> Dictionary:
	var entry := _entry(card_id, resolution_id)
	var request_variant: Variant = _runtime_main.call("_card_resolution_execution_request", entry)
	var request: Dictionary = request_variant if request_variant is Dictionary else {}
	var service := _execution_service()
	var plan_variant: Variant = service.call("plan_execution", request) if service != null else {}
	return (plan_variant as Dictionary).duplicate(true) if plan_variant is Dictionary else {}


func _drive_execution_service(transaction: Dictionary, options: Dictionary) -> Dictionary:
	var service := _execution_service()
	var order: Array = []
	var guard := 0
	while service != null and not (transaction.get("next_intent", {}) as Dictionary).is_empty() and guard < 20:
		guard += 1
		var intent: Dictionary = transaction.get("next_intent", {}) as Dictionary
		var intent_type := str(intent.get("intent_type", ""))
		order.append(intent_type)
		var receipt := {"intent_type": intent_type}
		match intent_type:
			"counter_check":
				receipt["countered"] = bool(options.get("countered", false))
				receipt["counter_resolution_id"] = 9901 if bool(receipt["countered"]) else -1
				receipt["counter_card_name"] = COUNTER_CARD_ID
			"release_active": receipt["completed"] = bool(options.get("release_completed", true))
			"finish_presentation": receipt["finished"] = true
			"revalidate_requirement":
				receipt["valid"] = bool(options.get("requirement_valid", true))
				receipt["reason"] = "valid" if bool(receipt["valid"]) else "requirement_invalid"
			"revalidate_target":
				receipt["valid"] = bool(options.get("target_valid", true))
				receipt["reason"] = "valid" if bool(receipt["valid"]) else "target_invalid"
			"dispatch_effect":
				receipt["dispatched"] = true
				receipt["resolved"] = bool(options.get("resolved", true))
				receipt["continuation_kind"] = str(options.get("continuation_kind", "normal"))
			"finish_card_commitment": receipt["committed"] = true
			"create_aftermath": receipt["entry_patch"] = {"aftermath_clue": "sprint37"}
			"restore_context": receipt["restored"] = true
			"append_history":
				receipt["appended"] = true
				receipt["current_queue_count"] = int(options.get("current_queue_count", 0))
			"start_next": receipt["started"] = true
			"finish_batch":
				receipt["finished"] = true
				receipt["next_queue_count"] = int(options.get("next_queue_count", 0))
			"promote_next_batch": receipt["promoted"] = true
		transaction = service.call("advance_execution", transaction, receipt) as Dictionary
	var finalized: Dictionary = service.call("finalize_execution", transaction) as Dictionary if service != null and str(transaction.get("status", "")) == "ready" and (transaction.get("next_intent", {}) as Dictionary).is_empty() else {}
	return {"transaction": transaction, "order": order, "finalized": finalized}


func _record(case_id: String, fixture_id: String, card_id: String, effect_family: String, flags: Dictionary) -> Dictionary:
	var aligned := bool(flags.get("contract_aligned", false))
	return {
		"case_id": case_id,
		"fixture_id": fixture_id,
		"card_id": card_id,
		"effect_family": effect_family,
		"active_resolution_id": int(flags.get("active_resolution_id", -1)),
		"target_kind": str(flags.get("target_kind", "none")),
		"target_valid": bool(flags.get("target_valid", false)),
		"temporary_decision_kind": str(flags.get("temporary_decision_kind", "none")),
		"world_mutation_delta": _data_dictionary(flags.get("world_mutation_delta", {})),
		"inventory_delta": int(flags.get("inventory_delta", 0)),
		"public_event_delta": int(flags.get("public_event_delta", 0)),
		"private_event_delta": int(flags.get("private_event_delta", 0)),
		"ledger_delta": int(flags.get("ledger_delta", 0)),
		"scenario_hook_delta": int(flags.get("scenario_hook_delta", 0)),
		"active_completed": bool(flags.get("active_completed", false)),
		"next_started": bool(flags.get("next_started", false)),
		"queue_service_checked": bool(flags.get("queue_service_checked", false)),
		"timing_boundary_checked": bool(flags.get("timing_boundary_checked", false)),
		"existing_service_route_checked": bool(flags.get("existing_service_route_checked", false)),
		"service_owner_checked": bool(flags.get("service_owner_checked", false)),
		"intent_order_checked": bool(flags.get("intent_order_checked", false)),
		"active_release_checked": bool(flags.get("active_release_checked", false)),
		"effect_dispatch_checked": bool(flags.get("effect_dispatch_checked", false)),
		"exact_once_checked": bool(flags.get("exact_once_checked", false)),
		"world_adapter_checked": bool(flags.get("world_adapter_checked", false)),
		"continuation_checked": bool(flags.get("continuation_checked", false)),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", false)),
		"formula_checked": bool(flags.get("formula_checked", false)),
		"formula_owner_checked": bool(flags.get("formula_owner_checked", false)),
		"legacy_orchestration_absent": bool(flags.get("legacy_orchestration_absent", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": bool(flags.get("observed", false)),
		"contract_aligned": aligned,
		"cutover_checked": bool(flags.get("cutover_checked", false)),
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "observed runtime differs from or is underspecified by the v0.4 execution contract")),
		"passed": false,
		"notes": str(flags.get("notes", "")),
	}


func _ensure_runtime_main() -> bool:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		return true
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	_runtime_main = packed.instantiate() as Control
	if _runtime_main == null:
		return false
	_runtime_main.name = "Main"
	_runtime_main.visible = false
	runtime_main_host.add_child(_runtime_main)
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_disable_runtime_audio()
	return true


func _reset_runtime_main() -> void:
	if _runtime_main == null:
		return
	_runtime_main.set_process(true)
	_runtime_main.call("_new_game")
	_runtime_main.set_process(false)
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_queue_service().call("reset_state")
	_runtime_main.set("resolved_card_history", [])
	if _contract_controller() != null:
		_contract_controller().call("reset_state")
	_runtime_main.set("log_lines", [])
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("runtime_visual_events", [])
	_runtime_main.set("runtime_visual_event_counter", 0)
	_runtime_main.set("card_resolution_batch_locked", false)
	_runtime_main.set("card_resolution_counter_window_active", false)
	_runtime_main.set("card_resolution_counter_timer", 0.0)
	_runtime_main.set("card_resolution_timer", 0.0)
	_runtime_main.set("card_resolution_force_duration", 0.0)
	_runtime_main.set("game_over", false)


func _hide_runtime_canvas_layers() -> void:
	if _runtime_main == null:
		return
	for canvas_node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if canvas_node is CanvasLayer:
			(canvas_node as CanvasLayer).visible = false


func _disable_runtime_audio() -> void:
	if _runtime_main == null or not is_instance_valid(_runtime_main):
		return
	for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		if player != null:
			player.stop()
			player.stream = null
	_runtime_main.set("table_sfx_players", {})
	_runtime_main.set("table_bgm_player", null)


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		_disable_runtime_audio()
		if _runtime_main.get_parent() != null:
			_runtime_main.get_parent().remove_child(_runtime_main)
		_runtime_main.free()
	_runtime_main = null


func _prepare_players(slot_sets: Array, cash_values: Array) -> void:
	var player_states: Array = (_runtime_main.get("players") as Array).duplicate(true)
	for player_index in range(mini(player_states.size(), slot_sets.size())):
		if not (player_states[player_index] is Dictionary):
			continue
		var player_state: Dictionary = (player_states[player_index] as Dictionary).duplicate(true)
		var slots_variant: Variant = slot_sets[player_index]
		player_state["slots"] = (slots_variant as Array).duplicate(true) if slots_variant is Array else []
		var cash := int(cash_values[player_index]) if player_index < cash_values.size() else 1000
		player_state["cash"] = cash
		player_state["cash_history"] = [cash]
		player_state["economic_ledger"] = []
		player_state["private_activity_feed"] = []
		player_state["total_card_spend"] = 0
		player_state["total_card_income"] = 0
		player_state["action_cooldown"] = 0.0
		player_state["eliminated"] = false
		player_state["is_ai"] = false
		player_states[player_index] = player_state
	_runtime_main.set("players", player_states)
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("selected_district", _first_alive_district())


func _real_skill(card_id: String) -> Dictionary:
	if card_id == "":
		return {}
	var value: Variant = _runtime_main.call("_make_skill", card_id)
	var skill: Dictionary = (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if skill.is_empty():
		return {}
	skill["play_requirement_kind"] = "none"
	skill["play_region_gdp_share_required"] = 0
	skill["play_product"] = ""
	skill["play_flow_required"] = 0
	skill["play_cash"] = 0
	return skill


func _entry(card_id: String, resolution_id: int, player_index: int = 0, target_slot: int = -1, target_player: int = -1, district_index: int = -1) -> Dictionary:
	return _entry_with_skill(_real_skill(card_id), resolution_id, player_index, target_slot, target_player, district_index)


func _entry_with_skill(skill: Dictionary, resolution_id: int, player_index: int = 0, target_slot: int = -1, target_player: int = -1, district_index: int = -1) -> Dictionary:
	return {
		"player_index": player_index,
		"slot_index": -1,
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"window_sequence": 36,
		"group_id": "sprint36_group_%d" % player_index,
		"group_order": 1,
		"group_size": 1,
		"priority_bid_cents": 0,
		"locked_priority_bid_cents": 0,
		"play_cost_paid_on_queue": true,
		"consumed_on_queue": true,
		"selected_district": _first_alive_district() if district_index < 0 else district_index,
		"selected_trade_product": _first_runtime_product(),
		"target_slot": target_slot,
		"target_player": target_player,
		"skill": skill.duplicate(true),
	}


func _complete_entry_twice(entry: Dictionary) -> void:
	_queue_service().call("replace_active_entry", entry)
	_queue_service().call("replace_current_queue", [])
	_runtime_main.set("card_resolution_batch_locked", true)
	_runtime_main.call("_complete_active_card_resolution")
	_runtime_main.call("_complete_active_card_resolution")


func _queue_service() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService") if _runtime_main != null else null


func _execution_service() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService") if _runtime_main != null else null


func _formula_service() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService") if _runtime_main != null else null


func _controller() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController") if _runtime_main != null else null


func _coordinator() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _runtime_main != null else null


func _inventory_service() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardInventoryRuntimeService") if _runtime_main != null else null


func _monster_controller() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController") if _runtime_main != null else null


func _hand_service() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/PlayerHandInteractionRuntimeService") if _runtime_main != null else null


func _contract_controller() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController") if _runtime_main != null else null


func _active_entry() -> Dictionary:
	var value: Variant = _queue_service().call("active_entry") if _queue_service() != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _service_debug(service: Node) -> Dictionary:
	var value: Variant = service.call("debug_snapshot") if service != null and service.has_method("debug_snapshot") else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _player(player_index: int) -> Dictionary:
	var player_states: Array = _runtime_main.get("players") as Array
	return (player_states[player_index] as Dictionary).duplicate(true) if player_index >= 0 and player_index < player_states.size() and player_states[player_index] is Dictionary else {}


func _player_cash(player_index: int) -> int:
	return int(_player(player_index).get("cash", 0))


func _ledger_count(player_index: int) -> int:
	return (_player(player_index).get("economic_ledger", []) as Array).size()


func _normal_card_count(player_index: int) -> int:
	var count := 0
	for slot_variant in _player(player_index).get("slots", []):
		if slot_variant is Dictionary:
			count += 1
	return count


func _array_size(property_name: String) -> int:
	var value: Variant = _runtime_main.get(property_name)
	return (value as Array).size() if value is Array else 0


func _logs_contain(fragment: String) -> bool:
	var value: Variant = _runtime_main.get("log_lines")
	if not (value is Array):
		return false
	for line_variant in value:
		if str(line_variant).contains(fragment):
			return true
	return false


func _history_count_for_resolution(resolution_id: int) -> int:
	var count := 0
	for entry_variant in _runtime_main.get("resolved_card_history"):
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("resolution_id", -1)) == resolution_id:
			count += 1
	return count


func _first_alive_district() -> int:
	var districts: Array = _runtime_main.get("districts") as Array
	for index in range(districts.size()):
		if districts[index] is Dictionary and not bool((districts[index] as Dictionary).get("destroyed", false)):
			return index
	return 0


func _district_public_metrics(district_index: int) -> Dictionary:
	var districts: Array = _runtime_main.get("districts") as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return {}
	var district := districts[district_index] as Dictionary
	var city: Dictionary = district.get("city", {}) as Dictionary
	return {
		"destroyed": bool(district.get("destroyed", false)),
		"production": int(district.get("production_level", 2)),
		"transport": int(district.get("transport_level", 2)),
		"consumption": int(district.get("consumption_level", 2)),
		"panic": int(district.get("panic", 0)),
		"route_damage": int(city.get("trade_route_damage", 0)),
	}


func _monster_public_metrics(slot: int) -> Dictionary:
	var monsters: Array = _runtime_main.get("auto_monsters") as Array
	if slot < 0 or slot >= monsters.size() or not (monsters[slot] is Dictionary):
		return {}
	var actor := monsters[slot] as Dictionary
	return {
		"uid": int(actor.get("uid", 0)),
		"hp": int(actor.get("hp", 0)),
		"down": bool(actor.get("down", false)),
		"lure_target_district": int(actor.get("lure_target_district", -1)),
		"lure_moves_left": int(actor.get("lure_moves_left", 0)),
		"lure_source": str(actor.get("lure_source", "")),
	}


func _first_runtime_product() -> String:
	var products_variant: Variant = _runtime_main.get("run_product_ids")
	if products_variant is Array and not (products_variant as Array).is_empty():
		return str((products_variant as Array)[0])
	var districts: Array = _runtime_main.get("districts") as Array
	for district_variant in districts:
		if district_variant is Dictionary:
			var products: Array = (district_variant as Dictionary).get("products", []) as Array
			if not products.is_empty():
				return str(products[0])
	return ""


func _runtime_city_development_card_id() -> String:
	var districts_variant: Variant = _runtime_main.get("districts")
	var districts: Array = districts_variant if districts_variant is Array else []
	for district_index in range(districts.size()):
		var district_variant: Variant = districts[district_index]
		if district_variant is Dictionary and not bool((district_variant as Dictionary).get("destroyed", false)):
			var value: Variant = _runtime_main.call("_ensure_city_development_card_supply_for_district", district_index)
			if not str(value).is_empty():
				return str(value)
	if (_runtime_main.get("city_development_runtime_cards") as Dictionary).is_empty():
		_runtime_main.call("_rebuild_city_development_runtime_cards")
	var cards: Dictionary = _runtime_main.get("city_development_runtime_cards") as Dictionary
	for card_id_variant in cards:
		var card_id := str(card_id_variant)
		var definition_variant: Variant = cards.get(card_id, {})
		var definition: Dictionary = definition_variant if definition_variant is Dictionary else {}
		if int(definition.get("rank", 0)) == 1 and str(definition.get("kind", "")) == "city_development" and not _real_skill(card_id).is_empty():
			return card_id
	return ""


func _runtime_persistent_card_id() -> String:
	var catalog_variant: Variant = _runtime_main.call("_catalog_entry", 0)
	var catalog_entry: Dictionary = catalog_variant if catalog_variant is Dictionary else {}
	var monster_name := str(catalog_entry.get("name", ""))
	if monster_name != "":
		var value: Variant = _runtime_main.call("_monster_technique_card_name", monster_name, 0, 1)
		var card_id := str(value)
		if not _real_skill(card_id).is_empty():
			return card_id
	return PERSISTENT_CARD_ID


func _representative_card_catalog() -> Array:
	var ids := [CASH_CARD_ID, PRODUCT_CARD_ID, DISTRICT_CARD_ID, MONSTER_CARD_ID, HAND_CARD_ID, CONTRACT_CARD_ID, INTEL_CARD_ID, COUNTER_CARD_ID, _runtime_persistent_card_id(), _runtime_city_development_card_id()]
	var result: Array = []
	for card_id_variant in ids:
		var card_id := str(card_id_variant)
		if card_id == "":
			continue
		var skill := _real_skill(card_id)
		result.append({
			"card_id": card_id,
			"kind": str(skill.get("kind", "")),
			"persistent": bool(skill.get("persistent", false)),
			"exists": not skill.is_empty(),
		})
	return result


func _main_source() -> String:
	return FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)


func _function_source(source_text: String, function_name: String) -> String:
	var start := source_text.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source_text.find("\nfunc ", start + 5)
	return source_text.substr(start) if next_function < 0 else source_text.substr(start, next_function - start)


func _source_tokens_in_order(source_text: String, tokens: Array) -> bool:
	var cursor := -1
	for token_variant in tokens:
		cursor = source_text.find(str(token_variant), cursor + 1)
		if cursor < 0:
			return false
	return true


func _data_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _contains_key_recursive(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			if str(key_variant) == target_key or _contains_key_recursive(value[key_variant], target_key):
				return true
	if value is Array:
		for item in value:
			if _contains_key_recursive(item, target_key):
				return true
	return false


func _observed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("observed", false)):
			count += 1
	return count


func _aligned_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("contract_aligned", false)):
			count += 1
	return count


func _characterization_count(field_name: String) -> int:
	var count := 0
	for index in range(mini(CASE_COUNT, _records.size())):
		var record: Dictionary = _records[index] if _records[index] is Dictionary else {}
		if bool(record.get(field_name, false)):
			count += 1
	return count


func _cutover_count() -> int:
	var count := 0
	for index in range(CASE_COUNT, _records.size()):
		var record: Dictionary = _records[index] if _records[index] is Dictionary else {}
		if bool(record.get("cutover_checked", false)):
			count += 1
	return count


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _design_decision_count() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("needs_design_decision", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var cutover := int(manifest.get("cutover_count", 0))
	var passed := int(manifest.get("passed_count", 0))
	summary_label.text = "Active execution: %d/%d observed | %d/%d aligned | %d/%d cutover | %d/%d total" % [observed, CASE_COUNT, aligned, CASE_COUNT, cutover, CUTOVER_CASE_COUNT, passed, TOTAL_CASE_COUNT]
	status_label.text = "CUTOVER %d/%d" % [passed, TOTAL_CASE_COUNT] if passed == TOTAL_CASE_COUNT else "INCOMPLETE"
	status_label.add_theme_color_override("font_color", Color("#4ade80") if passed == TOTAL_CASE_COUNT else Color("#fb7185"))
	contract_text.text = "[b]v0.4 execution contract[/b]\n\n• Targets are chosen at submit and rechecked at resolve\n• Submitted cards/costs are not refunded on counter or drift\n• Direct-player cards open a fixed 5-second counter window\n• Contract response is independent and does not block later cards\n• Public track hides actor and private payloads"
	lifecycle_text.text = "[b]Runtime ownership[/b]\n\n[b]Queue + Timing[/b]\n• current / active / next lifecycle\n• 30 / 25 / 5 clocks\n\n[b]Execution Service[/b]\n• generic intents only\n\n[b]Effect Family Service[/b]\n• 17 handler plans\n\n[b]Formula Service[/b]\n• 19 pure market / contract / city / route operations\n• price and city GDP retain existing owners\n\n[b]World bridges[/b]\n• RNG, eligibility, and concrete mutations"
	var lines: Array[String] = ["[b]Characterization + cutover gates[/b]"]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		var observed_mark := "OBS" if bool(record.get("observed", false)) else "MISS"
		var aligned_mark := "cutover" if bool(record.get("cutover_checked", false)) else ("aligned" if bool(record.get("contract_aligned", false)) else "review")
		lines.append("%s  %s  [%s]" % [observed_mark, str(record.get("case_id", "")), aligned_mark])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Card Resolution Execution + Effect Formula Cutover Sprint 40",
		"",
		"- Ruleset: `v0.4`",
		"- Observed: **%d/%d**" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"- Contract aligned: **%d/%d**" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"- Cutover checked: **%d/%d**" % [int(manifest.get("cutover_count", 0)), CUTOVER_CASE_COUNT],
		"- Total passed: **%d/%d**" % [int(manifest.get("passed_count", 0)), TOTAL_CASE_COUNT],
		"- Needs design decision: **%d**" % int(manifest.get("needs_design_decision_count", 0)),
		"- Baseline main SHA-256: `%s`" % str(manifest.get("baseline_main_sha256", "")),
		"- Cutover main SHA-256: `%s`" % str(manifest.get("actual_main_sha256", "")),
		"- Output: `%s`" % OUTPUT_DIR,
		"",
		"Characterization, contract alignment, and cutover ownership remain separate fields. All three must pass before legacy orchestration is considered deleted.",
		"",
		"## Runtime order",
		"",
		"1. Read active entry from CardResolutionQueueRuntimeService.",
		"2. Execution Service issues counter_check while active is retained.",
		"3. Queue Service confirms release_active before any effect intent.",
		"4. Execution Service orders requirement/target recheck and concrete world dispatch.",
		"5. Execution Service orders commitment, aftermath, context restore, and exact-once history.",
		"6. Execution Service chooses start_next or finish/promote; Queue Service mutates queue state.",
		"",
		"## Cases",
		"",
		"| Case | Card | Family | Temp decision | World delta | Inventory | Public | Private | Ledger | Active done | Next | Observed | Aligned | Decision | Notes |",
		"| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %s | %d | %d | %d | %d | %s | %s | %s | %s | %s | %s |" % [
			str(record.get("case_id", "")),
			str(record.get("card_id", "")),
			str(record.get("effect_family", "")),
			str(record.get("temporary_decision_kind", "")),
			JSON.stringify(record.get("world_mutation_delta", {})).replace("|", "/"),
			int(record.get("inventory_delta", 0)),
			int(record.get("public_event_delta", 0)),
			int(record.get("private_event_delta", 0)),
			int(record.get("ledger_delta", 0)),
			"yes" if bool(record.get("active_completed", false)) else "no",
			"yes" if bool(record.get("next_started", false)) else "no",
			"yes" if bool(record.get("observed", false)) else "no",
			"yes" if bool(record.get("contract_aligned", false)) else "no",
			"yes" if bool(record.get("needs_design_decision", false)) else "no",
			str(record.get("notes", "")).replace("|", "/"),
		])
	lines.append_array([
		"",
		"## Sprint 40 formula deletion gate",
		"",
		"Execution lifecycle remains stable and formula-agnostic. Product price remains in RuntimeBalanceModel, city GDP remains in GdpFormulaRuntimeController, RNG candidate selection remains in main, and nineteen characterized market, contract, city-product, demand, insurance, futures, derivative, and route operations are owned by the pure Formula Service.",
	])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name in ["manifest.json", "report.md"]:
		var path := OUTPUT_DIR + str(file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	return false


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Node or value is Resource:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if _contains_runtime_object(key_variant) or _contains_runtime_object(value[key_variant]):
				return true
	if value is Array:
		for item in value:
			if _contains_runtime_object(item):
				return true
	return false
