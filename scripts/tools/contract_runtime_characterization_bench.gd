extends Control
class_name ContractRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const RULESET_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/ruleset_runtime_bridge.gd"
const FORCED_SCHEDULER_SCRIPT_PATH := "res://scripts/runtime/forced_decision_runtime_scheduler.gd"
const AI_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const EXECUTION_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_execution_runtime_service.gd"
const QUEUE_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_queue_runtime_service.gd"
const FORMULA_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_economy_product_route_formula_runtime_service.gd"
const CONTRACT_PANEL_SCRIPT_PATH := "res://scripts/ui/contract_response_decision_panel.gd"
const CONTRACT_CONTROLLER_SCENE_PATH := "res://scenes/runtime/ContractRuntimeController.tscn"
const CONTRACT_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_controller.gd"
const CONTRACT_BRIDGE_SCENE_PATH := "res://scenes/runtime/ContractRuntimeWorldBridge.tscn"
const CONTRACT_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_world_bridge.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const CITY_PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")

const OUTPUT_DIR := "user://space_syndicate_design_qa/contract_runtime_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/contract_runtime_hard_cutover_sprint_51.png"
const RULESET_ID := "v0.4"
const CHARACTERIZATION_CASE_COUNT := 47
const CUTOVER_CASE_COUNT := 15
const CASE_COUNT := CHARACTERIZATION_CASE_COUNT + CUTOVER_CASE_COUNT
const FIXED_SEED := 500050
const BASELINE_MAIN_SHA256 := "214aeb804860d2dffb8833eff0bc0a4098b355178c07fb8e8bd1d80e6221777f"
const BASELINE_MAIN_METRICS := {
	"total_lines": 27969,
	"nonblank_lines": 25039,
	"function_count": 1415,
	"top_level_variable_count": 148,
	"constant_count": 232,
}

const CONTRACT_FAMILIES := [
	"区域供需合约",
	"自动撮合合约",
	"环晶电池专供",
	"双边对冲合约",
	"惩罚性拒签条款",
]

const CASE_IDS := [
	"contract_call_graph_complete",
	"five_real_contract_families_exist",
	"contract_rank_i_to_iv_assets",
	"pending_offer_runtime_shape",
	"contract_ruleset_window_is_five_seconds",
	"valid_source_district",
	"valid_target_district",
	"same_source_target_rejected",
	"destroyed_or_invalid_district_rejected_atomically",
	"selected_product_contract",
	"automatic_product_matching",
	"fixed_product_contract",
	"multi_product_contract",
	"punitive_decline_terms_preserved",
	"card_resolution_creates_pending_offer",
	"response_context_copied_to_offer",
	"active_resolution_released_after_offer_creation",
	"later_cards_continue_while_contract_pending",
	"duplicate_offer_id_rejected",
	"offer_creation_has_no_partial_world_mutation",
	"human_accept_routes_once",
	"human_decline_routes_once",
	"timeout_routes_once",
	"duplicate_response_rejected",
	"response_after_expiry_rejected",
	"forced_decision_priority_preserved",
	"monster_wager_or_counter_preempts_contract",
	"overlay_action_id_compatibility",
	"ai_accept_uses_same_runtime_response_route",
	"ai_decline_uses_same_runtime_response_route",
	"ai_remains_decision_owner_only",
	"player_and_ai_results_have_same_mutation_contract",
	"accept_cash_and_region_effects_exact_once",
	"decline_penalty_caps_and_route_damage_exact_once",
	"timeout_effect_matches_observed_runtime_semantics",
	"formula_service_remains_pure_formula_owner",
	"city_market_and_route_refresh_count_observed",
	"multiple_pending_offers_resolve_independently",
	"current_save_shape",
	"legacy_save_defaults",
	"pending_timer_save_load_parity",
	"public_contract_result_clue",
	"intel_trace_uses_sanitized_result",
	"hidden_owner_not_exposed",
	"private_target_and_private_discard_not_exposed",
	"pure_data_snapshots",
	"sprint51_deletion_candidates_complete",
]

const CUTOVER_CASE_IDS := [
	"controller_scene_composition",
	"controller_api_contract",
	"coordinator_static_composition",
	"state_owner_cutover",
	"endpoint_product_owner_cutover",
	"project_controller_authority",
	"explicit_self_sign_gate",
	"preempted_timer_suspends",
	"nonblocking_card_resolution",
	"exact_once_transaction",
	"world_bridge_non_owning",
	"player_ai_shared_route",
	"save_owner_cutover",
	"pure_public_private_snapshots",
	"main_legacy_contract_absent",
]

const DELETION_CANDIDATES := [
	"_runtime_contract_response_decision_snapshot_source",
	"_valid_contract_source_district",
	"_valid_contract_target_district",
	"_contract_district_short_name",
	"_contract_pair_summary",
	"_contract_pair_ready",
	"_set_selected_contract_source_district",
	"_set_selected_contract_target_district",
	"_active_contract_response_entry_for_player",
	"_pending_contract_offer_index_for_id",
	"_pending_contract_offer_by_id",
	"_pending_contract_offers_for_player",
	"_contract_entry_product_text",
	"_contract_response_public_label",
	"_contract_accept_effect_summary",
	"_contract_decline_effect_summary",
	"_contract_response_result_clue",
	"_respond_to_pending_contract_for_player",
	"_store_pending_contract_result",
	"_contract_limited_products",
	"_apply_contract_region_delta",
	"_grant_contract_cash",
	"_pay_contract_penalty",
	"_apply_contract_accept_route_flow",
	"_enqueue_pending_area_trade_contract",
	"_apply_area_trade_contract",
	"_apply_area_trade_contract_accept",
	"_apply_area_trade_contract_decline",
	"_update_pending_contract_offers",
	"_area_trade_contract_context",
	"_area_trade_contract_product_goal",
	"_area_trade_contract_products",
	"_card_resolution_contract_public_text",
	"_remember_contract_parties_for_player",
	"_traceable_contract_entries",
	"_trace_contract_parties_for_player",
	"_apply_intel_contract_trace",
]

const STATE_DELETION_CANDIDATES := [
	"selected_contract_source_district",
	"selected_contract_target_district",
	"pending_contract_offers",
]

const CONSTANT_DELETION_CANDIDATES := [
	"CONTRACT_RESPONSE_PENDING",
	"CONTRACT_RESPONSE_ACCEPTED",
	"CONTRACT_RESPONSE_REJECTED",
	"CONTRACT_RESPONSE_TIMEOUT",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _coordinator: Node
var _ruleset_bridge: Node
var _scheduler: Node
var _card_controller: Node
var _queue_service: Node
var _execution_service: Node
var _formula_service: Node
var _ai_controller: Node
var _contract_controller: ContractRuntimeController
var _contract_bridge: ContractRuntimeWorldBridge
var _product_market_controller: ProductMarketRuntimeController
var _overlay_layer: CanvasLayer
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _baseline_product_market: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []
var _sources: Dictionary = {}


func _ready() -> void:
	print("ContractRuntimeCharacterizationBench Sprint 51 ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return CASE_IDS.duplicate() + CUTOVER_CASE_IDS.duplicate()


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), false, false, "preview"))
	return {
		"suite": "contract-runtime-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"runtime_owner": CONTRACT_CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"passed_count": 0,
		"needs_design_decision_count": 0,
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"baseline_main_metrics": BASELINE_MAIN_METRICS.duplicate(true),
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_load_sources()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("ContractRuntimeCharacterizationBench could not instantiate the real main runtime and required boundaries.")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in characterization_cases():
		var case_id := str(case_id_variant)
		_reset_fixture()
		print("ContractRuntimeCharacterizationBench case: %s" % case_id)
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var main_source := str(_sources.get("main", ""))
	var metrics := _main_metrics(main_source)
	var current_sha := main_source.sha256_text()
	var deletion_gate := int(metrics.get("nonblank_lines", 999999)) <= 24589 and int(metrics.get("function_count", 999999)) <= 1385 and int(metrics.get("top_level_variable_count", 999999)) <= 145 and int(metrics.get("constant_count", 999999)) <= 228
	if not deletion_gate:
		_failures.append("main.gd hard-deletion metrics missed the Sprint 51 ceiling")
	var manifest := {
		"suite": "contract-runtime-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"runtime_owner": CONTRACT_CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _count_flag("observed"),
		"aligned_count": _count_flag("contract_aligned"),
		"passed_count": _count_flag("passed"),
		"needs_design_decision_count": _count_flag("needs_design_decision"),
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"current_main_sha256": current_sha,
		"baseline_main_metrics": BASELINE_MAIN_METRICS.duplicate(true),
		"main_metrics": metrics,
		"historical_sprint50_main_sha256": BASELINE_MAIN_SHA256,
		"main_deletion_gate_passed": deletion_gate,
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("ContractRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("ContractRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("ContractRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("ContractRuntimeCharacterizationBench observed: %d/%d" % [_count_flag("observed"), CASE_COUNT])
	print("ContractRuntimeCharacterizationBench aligned: %d/%d; design_decisions=%d" % [_count_flag("contract_aligned"), CASE_COUNT, _count_flag("needs_design_decision")])
	print("ContractRuntimeCharacterizationBench Sprint 51 cutover: %d/%d passed; main_deletion_gate=%s sha=%s" % [_count_flag("passed"), CASE_COUNT, str(deletion_gate), current_sha])
	if not _failures.is_empty():
		push_error("ContractRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"contract_call_graph_complete": return _case_call_graph()
		"five_real_contract_families_exist": return _case_families()
		"contract_rank_i_to_iv_assets": return _case_rank_assets()
		"pending_offer_runtime_shape": return _case_offer_shape()
		"contract_ruleset_window_is_five_seconds": return _case_window_timing()
		"valid_source_district": return _case_valid_source()
		"valid_target_district": return _case_valid_target()
		"same_source_target_rejected": return _case_same_source_target()
		"destroyed_or_invalid_district_rejected_atomically": return _case_invalid_atomic()
		"selected_product_contract": return _case_product_mode("selected")
		"automatic_product_matching": return _case_product_mode("auto")
		"fixed_product_contract": return _case_product_mode("fixed")
		"multi_product_contract": return _case_product_mode("multi")
		"punitive_decline_terms_preserved": return _case_punitive_terms()
		"card_resolution_creates_pending_offer": return _case_offer_created()
		"response_context_copied_to_offer": return _case_context_copied()
		"active_resolution_released_after_offer_creation": return _case_active_release()
		"later_cards_continue_while_contract_pending": return _case_later_card_continues()
		"duplicate_offer_id_rejected": return _case_duplicate_offer()
		"offer_creation_has_no_partial_world_mutation": return _case_offer_no_world_mutation()
		"human_accept_routes_once": return _case_human_response(true)
		"human_decline_routes_once": return _case_human_response(false)
		"timeout_routes_once": return _case_timeout_once()
		"duplicate_response_rejected": return _case_duplicate_response()
		"response_after_expiry_rejected": return _case_response_after_expiry()
		"forced_decision_priority_preserved": return _case_forced_priority()
		"monster_wager_or_counter_preempts_contract": return _case_preemption_boundary()
		"overlay_action_id_compatibility": return _case_overlay_actions()
		"ai_accept_uses_same_runtime_response_route": return _case_ai_accept()
		"ai_decline_uses_same_runtime_response_route": return _case_ai_decline_route()
		"ai_remains_decision_owner_only": return _case_ai_boundary()
		"player_and_ai_results_have_same_mutation_contract": return _case_player_ai_parity()
		"accept_cash_and_region_effects_exact_once": return _case_accept_exact_once()
		"decline_penalty_caps_and_route_damage_exact_once": return _case_decline_cap_exact_once()
		"timeout_effect_matches_observed_runtime_semantics": return _case_timeout_semantics()
		"formula_service_remains_pure_formula_owner": return _case_formula_boundary()
		"city_market_and_route_refresh_count_observed": return _case_refresh_count()
		"multiple_pending_offers_resolve_independently": return _case_multiple_offers()
		"current_save_shape": return _case_current_save()
		"legacy_save_defaults": return _case_legacy_defaults()
		"pending_timer_save_load_parity": return _case_timer_save_parity()
		"public_contract_result_clue": return _case_public_clue()
		"intel_trace_uses_sanitized_result": return _case_intel_trace()
		"hidden_owner_not_exposed": return _case_hidden_owner()
		"private_target_and_private_discard_not_exposed": return _case_private_payload_boundary()
		"pure_data_snapshots": return _case_pure_snapshots()
		"sprint51_deletion_candidates_complete": return _case_deletion_candidates()
		"controller_scene_composition": return _case_controller_scene_composition()
		"controller_api_contract": return _case_controller_api_contract()
		"coordinator_static_composition": return _case_coordinator_static_composition()
		"state_owner_cutover": return _case_state_owner_cutover()
		"endpoint_product_owner_cutover": return _case_endpoint_product_owner_cutover()
		"project_controller_authority": return _case_project_controller_authority()
		"explicit_self_sign_gate": return _case_explicit_self_sign_gate()
		"preempted_timer_suspends": return _case_preempted_timer_suspends()
		"nonblocking_card_resolution": return _case_nonblocking_card_resolution()
		"exact_once_transaction": return _case_exact_once_transaction()
		"world_bridge_non_owning": return _case_world_bridge_non_owning()
		"player_ai_shared_route": return _case_player_ai_shared_route()
		"save_owner_cutover": return _case_save_owner_cutover()
		"pure_public_private_snapshots": return _case_pure_public_private_snapshots()
		"main_legacy_contract_absent": return _case_main_legacy_contract_absent()
	return _record(case_id, false, false, "Unknown characterization case.")


func _case_call_graph() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var legacy_remaining: Array = []
	for function_name in DELETION_CANDIDATES:
		if main_source.contains("func %s(" % str(function_name)):
			legacy_remaining.append(str(function_name))
	var controller_source := str(_sources.get("contract_controller", ""))
	var controller_graph := ["func plan_offer(", "func commit_offer(", "func plan_response(", "func commit_response(", "func tick(", "func private_response_snapshot(", "func public_snapshot(", "func to_save_data(", "func apply_save_data("]
	var missing_api: Array = []
	for token in controller_graph:
		if not controller_source.contains(str(token)):
			missing_api.append(str(token))
	var observed := legacy_remaining.is_empty() and missing_api.is_empty()
	return _record("contract_call_graph_complete", observed, observed, "All %d Sprint 50 legacy functions are absent; Controller lifecycle API missing=%s, remaining=%s." % [DELETION_CANDIDATES.size(), str(missing_api), str(legacy_remaining)])


func _case_families() -> Dictionary:
	var missing: Array = []
	for family_variant in CONTRACT_FAMILIES:
		var card_id := "%s1" % str(family_variant)
		var skill := _skill(card_id)
		if skill.is_empty() or str(skill.get("kind", "")) != "area_trade_contract":
			missing.append(card_id)
	var observed := missing.is_empty()
	return _record("five_real_contract_families_exist", observed, observed, "Real rank-I contract families found; missing=%s." % str(missing), {"card_id": "、".join(CONTRACT_FAMILIES)})


func _case_rank_assets() -> Dictionary:
	var missing: Array = []
	for family_variant in CONTRACT_FAMILIES:
		for rank in range(1, 5):
			var card_id := "%s%d" % [str(family_variant), rank]
			var skill := _skill(card_id)
			if skill.is_empty() or str(skill.get("name", "")) != card_id or str(skill.get("kind", "")) != "area_trade_contract":
				missing.append(card_id)
	var observed := missing.is_empty()
	return _record("contract_rank_i_to_iv_assets", observed, observed, "All twenty I-IV authored assets exist; missing=%s." % str(missing))


func _case_offer_shape() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50001)
	var offer: Dictionary = opened.get("offer", {})
	var required := ["contract_offer_id", "resolution_id", "player_index", "skill", "contract_source_district", "contract_target_district", "contract_target_owner", "contract_products", "contract_response", "contract_decision_timer", "contract_decision_started_time"]
	var missing: Array = []
	for key_variant in required:
		if not offer.has(str(key_variant)):
			missing.append(str(key_variant))
	var observed := bool(opened.get("opened", false)) and missing.is_empty() and str(offer.get("contract_response", "")) == "pending"
	return _record("pending_offer_runtime_shape", observed, observed, "Observed pending offer fields; missing=%s." % str(missing), _flags_from_opened(opened))


func _case_window_timing() -> Dictionary:
	var seconds := float(_runtime_main.call("_ruleset_timing_seconds", &"contract_window_seconds"))
	var timing: Dictionary = _ruleset_bridge.call("timing_rules") if _ruleset_bridge != null and _ruleset_bridge.has_method("timing_rules") else {}
	var observed := is_equal_approx(seconds, 5.0) and is_equal_approx(float(timing.get("contract_window_seconds", 0.0)), 5.0)
	return _record("contract_ruleset_window_is_five_seconds", observed, observed, "Ruleset bridge and runtime both report %.1f seconds." % seconds, {"timer_before": seconds, "timing_checked": true})


func _case_valid_source() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50002)
	var source_index := int(fixture.get("source", -1))
	var context: Dictionary = fixture.get("context", {})
	var ocean_index := _first_district("ocean", [source_index, int(fixture.get("target", -1))])
	var ocean_valid := _contract_controller.valid_source_district(ocean_index) if ocean_index >= 0 else false
	var observed := str(context.get("error", "")) == "" and _contract_controller.valid_source_district(source_index) and not ocean_valid
	return _record("valid_source_district", observed, observed, "A live land district is valid; ocean is rejected as the production source.", _flags_from_fixture(fixture))


func _case_valid_target() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50003, 1, 2)
	var context: Dictionary = fixture.get("context", {})
	var runtime_owner := int(context.get("target_owner", -1))
	var project_controller := int(fixture.get("target_project_controller", -1))
	var observed := str(context.get("error", "")) == "" and runtime_owner == project_controller and runtime_owner == 2
	var aligned := runtime_owner == project_controller
	return _record("valid_target_district", observed, aligned, "Runtime now authorizes target product-project controller %d independently of city owner 1." % project_controller, _flags_from_fixture(fixture))


func _case_same_source_target() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50004)
	var skill: Dictionary = fixture.get("skill", {})
	var source_index := int(fixture.get("source", -1))
	var context: Dictionary = _contract_controller.offer_context(skill, 0, source_index, source_index, "活体芯片")
	var observed := not str(context.get("error", "")).is_empty() and int(context.get("target_owner", -1)) == -1
	return _record("same_source_target_rejected", observed, observed, "The same source/target district is rejected before an offer exists.", _flags_from_fixture(fixture))


func _case_invalid_atomic() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50005)
	var target_index := int(fixture.get("target", -1))
	var districts: Array = (_runtime_main.get("districts") as Array).duplicate(true)
	districts[target_index]["destroyed"] = true
	_runtime_main.set("districts", districts)
	var players_before := JSON.stringify(_runtime_main.get("players")).sha256_text()
	var districts_before := JSON.stringify(_runtime_main.get("districts")).sha256_text()
	var entry: Dictionary = fixture.get("entry", {})
	var result := _contract_controller.open_offer(fixture.get("skill", {}), entry)
	var observed := not bool(result.get("opened", false)) and _contract_controller.pending_offers_snapshot(true).is_empty() and players_before == JSON.stringify(_runtime_main.get("players")).sha256_text() and districts_before == JSON.stringify(_runtime_main.get("districts")).sha256_text()
	return _record("destroyed_or_invalid_district_rejected_atomically", observed, observed, "Destroyed target rejection leaves players, districts, and pending offers unchanged.", _flags_from_fixture(fixture))


func _case_product_mode(mode: String) -> Dictionary:
	var card_id := "区域供需合约1"
	match mode:
		"auto": card_id = "自动撮合合约1"
		"fixed": card_id = "环晶电池专供1"
		"multi": card_id = "双边对冲合约1"
	var fixture := _contract_fixture(card_id, 50010 + ["selected", "auto", "fixed", "multi"].find(mode))
	var products: Array = (fixture.get("context", {}) as Dictionary).get("products", [])
	var observed := false
	match mode:
		"selected": observed = products.size() == 1 and str(products[0]) == "活体芯片"
		"auto": observed = not products.is_empty() and str(products[0]) == "真空可可"
		"fixed": observed = products.size() == 1 and str(products[0]) == "环晶电池"
		"multi": observed = products.size() >= 2 and products.has("活体芯片") and products.has("真空可可")
	var case_id: String = str({"selected":"selected_product_contract", "auto":"automatic_product_matching", "fixed":"fixed_product_contract", "multi":"multi_product_contract"}.get(mode, "selected_product_contract"))
	return _record(case_id, observed, observed, "%s mode selected %s in stable order." % [mode, str(products)], _flags_from_fixture(fixture).merged({"product_count": products.size()}, true))


func _case_punitive_terms() -> Dictionary:
	var skill := _skill("惩罚性拒签条款1")
	var penalty := int(skill.get("decline_cash_penalty", 0))
	var route_damage := int(skill.get("decline_route_damage", 0))
	var observed := str(skill.get("kind", "")) == "area_trade_contract" and penalty >= 180 and route_damage >= 2
	return _record("punitive_decline_terms_preserved", observed, observed, "Rank-I punitive terms remain cash penalty %d and route damage %d." % [penalty, route_damage], {"card_id": "惩罚性拒签条款1", "route_damage_delta": route_damage})


func _case_offer_created() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50101)
	var observed := bool(opened.get("opened", false)) and _contract_controller.pending_offers_snapshot(true).size() == 1
	return _record("card_resolution_creates_pending_offer", observed, observed, "The real contract handler creates one pending offer after public-card effect dispatch.", _flags_from_opened(opened))


func _case_context_copied() -> Dictionary:
	var opened := _open_offer("双边对冲合约1", 50102)
	var fixture: Dictionary = opened.get("fixture", {})
	var offer: Dictionary = opened.get("offer", {})
	var entry: Dictionary = fixture.get("entry", {})
	var observed := int(offer.get("contract_source_district", -1)) == int(entry.get("contract_source_district", -2)) and int(offer.get("contract_target_district", -1)) == int(entry.get("contract_target_district", -2)) and (offer.get("contract_products", []) as Array) == (entry.get("contract_products", []) as Array) and int(offer.get("contract_target_owner", -1)) == int(entry.get("contract_target_owner", -2))
	return _record("response_context_copied_to_offer", observed, observed, "Source, target, products, target owner, skill, and resolution id are copied into an independent offer.", _flags_from_opened(opened))


func _case_active_release() -> Dictionary:
	var execution_source := str(_sources.get("execution", ""))
	var contract_source := str(_sources.get("contract_controller", ""))
	var release_before_dispatch := _tokens_in_order(execution_source, ["INTENT_RELEASE_ACTIVE", "INTENT_DISPATCH_EFFECT"])
	var independent_offer := contract_source.contains("pending_offers.append(offer)")
	var fixture := _contract_fixture("区域供需合约1", 50103)
	var transaction: Dictionary = _execution_service.call("plan_execution", {"active_entry": fixture.get("entry", {}), "skill": fixture.get("skill", {}), "target_kind": "district"})
	var observed := release_before_dispatch and independent_offer and str(transaction.get("handler_id", "")) == "area_trade_contract"
	return _record("active_resolution_released_after_offer_creation", observed, observed, "Execution's release-active intent precedes effect dispatch; the contract then owns an independent pending copy.", _flags_from_fixture(fixture).merged({"execution_boundary_checked": true}, true))


func _case_later_card_continues() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50104)
	_card_controller.call("begin_group_window", 30.0, 2, 12)
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	var player: Dictionary = (players[2] as Dictionary).duplicate(true)
	player["slots"] = [_skill("轨道融资1")]
	player["cash"] = 5000
	players[2] = player
	_runtime_main.set("players", players)
	_runtime_main.set("selected_player", 2)
	var queued := bool(_runtime_main.call("_queue_skill_resolution", 2, 0, -1))
	var current_queue_count := (_queue_service.call("current_queue") as Array).size()
	var next_queue_count := (_queue_service.call("next_queue") as Array).size()
	var active_present := not (_queue_service.call("active_entry") as Dictionary).is_empty()
	var queue_count := current_queue_count + next_queue_count + (1 if active_present else 0)
	var pending_count := _contract_controller.pending_offers_snapshot(true).size()
	var observed := bool(opened.get("opened", false)) and pending_count == 1 and queue_count >= 0
	var aligned := queued
	var notes := "The ordinary-card submission route was measured while one private offer remained pending: accepted=%s, current_queue=%d, next_queue=%d, active=%s." % [str(queued), current_queue_count, next_queue_count, str(active_present)]
	return _record("later_cards_continue_while_contract_pending", observed, aligned, notes, _flags_from_opened(opened).merged({
		"execution_boundary_checked": true,
		"needs_design_decision": not aligned,
		"risk": "A pending private contract currently prevents or rejects the later ordinary-card submission route." if not aligned else "",
	}, true))


func _case_duplicate_offer() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50105)
	var first := bool(_contract_controller.open_offer(fixture.get("skill", {}), fixture.get("entry", {})).get("opened", false))
	var second := bool(_contract_controller.open_offer(fixture.get("skill", {}), fixture.get("entry", {})).get("opened", false))
	var observed := first and second and _contract_controller.pending_offers_snapshot(true).size() == 1
	return _record("duplicate_offer_id_rejected", observed, observed, "Re-enqueueing the same resolution id is idempotent and does not create a second offer.", _flags_from_fixture(fixture))


func _case_offer_no_world_mutation() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50106)
	var players_before := JSON.stringify(_runtime_main.get("players")).sha256_text()
	var districts_before := JSON.stringify(_runtime_main.get("districts")).sha256_text()
	var opened := bool(_contract_controller.open_offer(fixture.get("skill", {}), fixture.get("entry", {})).get("opened", false))
	var observed := opened and players_before == JSON.stringify(_runtime_main.get("players")).sha256_text() and districts_before == JSON.stringify(_runtime_main.get("districts")).sha256_text()
	return _record("offer_creation_has_no_partial_world_mutation", observed, observed, "Opening the response window mutates only offer/log state, not cash, city, product, or route state.", _flags_from_fixture(fixture))


func _case_human_response(accept: bool) -> Dictionary:
	var card_id := "区域供需合约1" if accept else "区域供需合约2"
	var opened := _open_offer(card_id, 50201 if accept else 50202)
	var target_owner := int(opened.get("target_owner", -1))
	var offer_id := int(opened.get("offer_id", -1))
	var before := _contract_world_metrics(opened)
	var first := bool(_contract_controller.respond_to_offer(target_owner, offer_id, accept, false).get("committed", false))
	var after_first := _contract_world_metrics(opened)
	var second := bool(_contract_controller.respond_to_offer(target_owner, offer_id, accept, false).get("committed", false))
	var after_second := _contract_world_metrics(opened)
	var expected_response := "accepted" if accept else "rejected"
	var stored: Dictionary = _runtime_main.call("_card_resolution_entry_by_id", offer_id)
	var observed := first and not second and str(stored.get("contract_response", "")) == expected_response and after_first == after_second and before != after_first
	var case_id := "human_accept_routes_once" if accept else "human_decline_routes_once"
	return _record(case_id, observed, observed, "Human %s resolves through the shared responder exactly once." % expected_response, _metric_flags(opened, before, after_first))


func _case_timeout_once() -> Dictionary:
	var opened := _open_offer("区域供需合约2", 50203)
	var before := _contract_world_metrics(opened)
	_contract_controller.tick_visible_offer(5.1, "contract_response_%d" % int(opened.get("offer_id", -1)))
	var after_first := _contract_world_metrics(opened)
	_contract_controller.tick_visible_offer(5.1, "contract_response_%d" % int(opened.get("offer_id", -1)))
	var after_second := _contract_world_metrics(opened)
	var stored: Dictionary = _runtime_main.call("_card_resolution_entry_by_id", int(opened.get("offer_id", -1)))
	var observed := _contract_controller.pending_offers_snapshot(true).is_empty() and str(stored.get("contract_response", "")) == "timeout" and after_first == after_second and before != after_first
	return _record("timeout_routes_once", observed, observed, "Timer expiry removes one offer, applies timeout rejection once, and stores one history result.", _metric_flags(opened, before, after_first).merged({"timer_before": 5.0, "timer_after": 0.0, "timing_checked": true}, true))


func _case_duplicate_response() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50204)
	var target_owner := int(opened.get("target_owner", -1))
	var offer_id := int(opened.get("offer_id", -1))
	var first := bool(_contract_controller.respond_to_offer(target_owner, offer_id, true, false).get("committed", false))
	var after_first := _contract_world_metrics(opened)
	var second := bool(_contract_controller.respond_to_offer(target_owner, offer_id, false, false).get("committed", false))
	var observed := first and not second and after_first == _contract_world_metrics(opened)
	return _record("duplicate_response_rejected", observed, observed, "A settled offer id cannot be accepted or rejected again.", _flags_from_opened(opened))


func _case_response_after_expiry() -> Dictionary:
	var opened := _open_offer("区域供需合约2", 50205)
	_contract_controller.tick_visible_offer(6.0, "contract_response_%d" % int(opened.get("offer_id", -1)))
	var after_timeout := _contract_world_metrics(opened)
	var accepted := bool(_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), int(opened.get("offer_id", -1)), true, false).get("committed", false))
	var observed := not accepted and after_timeout == _contract_world_metrics(opened)
	return _record("response_after_expiry_rejected", observed, observed, "A response after timeout is rejected without reversing or repeating timeout effects.", _flags_from_opened(opened))


func _case_forced_priority() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50206)
	var counter_entry := {"resolution_id": 88001, "queued_order": 88001, "player_index": 2, "skill": _skill("相位否决1")}
	_queue_service.call("replace_active_entry", counter_entry)
	_card_controller.call("begin_counter", 5.0)
	_runtime_main.call("_sync_forced_decision_runtime")
	var active: Dictionary = _coordinator.call("active_forced_decision", int(opened.get("target_owner", -1)))
	var timer_before := _offer_timer(int(opened.get("offer_id", -1)))
	_coordinator.call("tick_contract_runtime", 1.0)
	var timer_after := _offer_timer(int(opened.get("offer_id", -1)))
	var observed := str(active.get("priority_group", "")) == "counter_response" and is_equal_approx(timer_after, timer_before)
	var aligned := is_equal_approx(timer_after, timer_before)
	return _record("forced_decision_priority_preserved", observed, aligned, "Counter preempts the private contract and its hidden timer remains %.1f→%.1f." % [timer_before, timer_after], _flags_from_opened(opened).merged({"timer_before": timer_before, "timer_after": timer_after, "forced_decision_checked": true, "timing_checked": true}, true))


func _case_preemption_boundary() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50207)
	var candidates: Array = _runtime_main.call("_forced_decision_candidates")
	var contract_candidate := _candidate_by_kind(candidates, "contract_response")
	var priority: Array = (_scheduler.call("debug_snapshot") as Dictionary).get("priority_order", [])
	var observed := priority == ["monster_wager", "counter_response", "contract_response", "other_choice", "public_bid"] and not contract_candidate.is_empty()
	var aligned := not bool(contract_candidate.get("blocks_card_resolution", true))
	return _record("monster_wager_or_counter_preempts_contract", observed, aligned, "Priority order remains authoritative with public_bid last; contract candidates report blocks_card_resolution=%s." % str(contract_candidate.get("blocks_card_resolution", null)), _flags_from_opened(opened).merged({"forced_decision_checked": true}, true))


func _case_overlay_actions() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50208)
	var target_owner := int(opened.get("target_owner", -1))
	_runtime_main.set("selected_player", target_owner)
	var snapshot: Dictionary = _contract_controller.private_response_snapshot(target_owner)
	var ids: Array = []
	for action_variant in snapshot.get("actions", []):
		if action_variant is Dictionary:
			ids.append(str((action_variant as Dictionary).get("id", "")))
	var offer_id := int(opened.get("offer_id", -1))
	var panel := _overlay_layer.find_child("ContractResponseDecisionPanel", true, false) if _overlay_layer != null else null
	var observed := ids == ["contract_accept_%d" % offer_id, "contract_reject_%d" % offer_id] and panel != null
	return _record("overlay_action_id_compatibility", observed, observed, "Overlay keeps stable accept/reject action ids and the editable ContractResponseDecisionPanel.", _flags_from_opened(opened).merged({"privacy_checked": true}, true))


func _case_ai_accept() -> Dictionary:
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	players[1]["is_ai"] = true
	_runtime_main.set("players", players)
	var opened := _open_offer("惩罚性拒签条款1", 50301)
	var responses := int(_ai_controller.call("_update_ai_contract_responses", true))
	var stored: Dictionary = _runtime_main.call("_card_resolution_entry_by_id", int(opened.get("offer_id", -1)))
	var observed := responses == 1 and _contract_controller.pending_offers_snapshot(true).is_empty() and str(stored.get("contract_response", "")) == "accepted"
	return _record("ai_accept_uses_same_runtime_response_route", observed, observed, "The punitive real card is accepted by AI through the same ContractRuntimeController route used by human actions.", _flags_from_opened(opened).merged({"ai_route_checked": true}, true))


func _case_ai_decline_route() -> Dictionary:
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	players[1]["is_ai"] = true
	_runtime_main.set("players", players)
	var opened := _open_offer("区域供需合约1", 50302)
	var ai_source := str(_sources.get("ai", ""))
	var shared_route := _function_source(ai_source, "_respond_to_pending_contract_for_player").contains("_contract_runtime_controller.respond_to_offer")
	var declined := bool(_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), int(opened.get("offer_id", -1)), false, false).get("committed", false))
	var stored: Dictionary = _runtime_main.call("_card_resolution_entry_by_id", int(opened.get("offer_id", -1)))
	var observed := shared_route and declined and str(stored.get("contract_response", "")) == "rejected"
	return _record("ai_decline_uses_same_runtime_response_route", observed, observed, "AI response selection delegates mutation to the same accept/reject runtime route.", _flags_from_opened(opened).merged({"ai_route_checked": true}, true))


func _case_ai_boundary() -> Dictionary:
	var ai_source := str(_sources.get("ai", ""))
	var controller_source := str(_sources.get("contract_controller", ""))
	var bridge_source := str(_sources.get("contract_bridge", ""))
	var observed := ai_source.contains("func _ai_contract_response_candidates(") and ai_source.contains("func _update_ai_contract_responses(") and not ai_source.contains("func _apply_accept(") and controller_source.contains("func respond_to_offer(") and bridge_source.contains("func _apply_accept(")
	return _record("ai_remains_decision_owner_only", observed, observed, "AI owns candidate scoring and choice; ContractRuntimeController and its non-owning WorldBridge own response commit and world mutation.", {"ai_route_checked": true})


func _case_player_ai_parity() -> Dictionary:
	var human := _acceptance_metrics(false, 50303)
	_reset_fixture()
	var ai := _acceptance_metrics(true, 50304)
	var comparable_keys := ["cash_delta", "production_delta", "demand_delta", "transport_delta", "route_flow_delta", "route_damage_delta"]
	var same := true
	for key_variant in comparable_keys:
		same = same and human.get(str(key_variant)) == ai.get(str(key_variant))
	var observed := bool(human.get("resolved", false)) and bool(ai.get("resolved", false)) and same
	return _record("player_and_ai_results_have_same_mutation_contract", observed, observed, "Human and AI flags do not change the shared contract mutation envelope: %s." % str(human), human.merged({"ai_route_checked": true}, true))


func _case_accept_exact_once() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50401)
	var before := _contract_world_metrics(opened)
	var target_owner := int(opened.get("target_owner", -1))
	var offer_id := int(opened.get("offer_id", -1))
	var first := bool(_contract_controller.respond_to_offer(target_owner, offer_id, true, false).get("committed", false))
	var after := _contract_world_metrics(opened)
	var second := bool(_contract_controller.respond_to_offer(target_owner, offer_id, true, false).get("committed", false))
	var expected_cash := int((opened.get("fixture", {}) as Dictionary).get("skill", {}).get("accept_cash", 0))
	var cash_delta := int(after.get("cash", 0)) - int(before.get("cash", 0))
	var observed := first and not second and cash_delta == expected_cash and after == _contract_world_metrics(opened)
	return _record("accept_cash_and_region_effects_exact_once", observed, observed, "Accept cash and region effects commit exactly once.", _metric_flags(opened, before, after))


func _case_decline_cap_exact_once() -> Dictionary:
	var opened := _open_offer("惩罚性拒签条款1", 50402)
	var target_owner := int(opened.get("target_owner", -1))
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	players[target_owner]["cash"] = 50
	_runtime_main.set("players", players)
	var before := _contract_world_metrics(opened)
	var first := bool(_contract_controller.respond_to_offer(target_owner, int(opened.get("offer_id", -1)), false, false).get("committed", false))
	var after := _contract_world_metrics(opened)
	var second := bool(_contract_controller.respond_to_offer(target_owner, int(opened.get("offer_id", -1)), false, false).get("committed", false))
	var skill: Dictionary = (opened.get("fixture", {}) as Dictionary).get("skill", {})
	var observed := first and not second and int(after.get("cash", 0)) == 0 and int(before.get("cash", 0)) == 50 and int(after.get("route_damage", 0)) - int(before.get("route_damage", 0)) == int(skill.get("decline_route_damage", 0)) and after == _contract_world_metrics(opened)
	return _record("decline_penalty_caps_and_route_damage_exact_once", observed, observed, "Penalty is capped at available cash and route damage commits once.", _metric_flags(opened, before, after))


func _case_timeout_semantics() -> Dictionary:
	var decline := _rejection_metrics(false, 50403)
	_reset_fixture()
	var timeout := _rejection_metrics(true, 50404)
	var same := true
	for key_variant in ["cash_delta", "production_delta", "demand_delta", "transport_delta", "route_flow_delta", "route_damage_delta"]:
		same = same and decline.get(str(key_variant)) == timeout.get(str(key_variant))
	var observed := bool(decline.get("resolved", false)) and bool(timeout.get("resolved", false)) and same and str(timeout.get("response_kind", "")) == "timeout"
	return _record("timeout_effect_matches_observed_runtime_semantics", observed, observed, "Timeout uses the same rejection mutation envelope and stores a distinct timeout response label.", timeout.merged({"timing_checked": true}, true))


func _case_formula_boundary() -> Dictionary:
	var formula_source := str(_sources.get("formula", ""))
	var main_source := str(_sources.get("main", ""))
	var debug: Dictionary = _formula_service.call("debug_snapshot")
	var observed := formula_source.contains("func _city_contract_boon(") and formula_source.contains("func _product_contract_boon(") and main_source.contains("_card_economy_product_route_formula_result") and bool(debug.get("pure_formula_authority", false)) and not bool(debug.get("world_mutation_authority", true)) and _is_data_only(debug)
	return _record("formula_service_remains_pure_formula_owner", observed, observed, "Existing deterministic contract formulas remain pure and do not acquire offer lifecycle or world mutation.", {"formula_service_checked": true, "pure_data_checked": true})


func _case_refresh_count() -> Dictionary:
	var bridge_source := str(_sources.get("contract_bridge", ""))
	var accept_source := _function_source(bridge_source, "_apply_accept")
	var decline_source := _function_source(bridge_source, "_apply_decline")
	var accept_city := accept_source.count("_refresh_city_networks")
	var accept_market := accept_source.count("_product_market_runtime_controller.refresh_prices()")
	var decline_city := decline_source.count("_refresh_city_networks")
	var decline_market := decline_source.count("_product_market_runtime_controller.refresh_prices()")
	var observed := accept_city == 1 and accept_market == 1 and decline_city == 1 and decline_market == 1
	return _record("city_market_and_route_refresh_count_observed", observed, observed, "Accept and reject each request one city-network refresh and one market refresh after mutation.", {"formula_service_checked": true})


func _case_multiple_offers() -> Dictionary:
	var first := _open_offer("区域供需合约1", 50405)
	var second := _open_offer("区域供需合约2", 50406, false)
	var before_count := _contract_controller.pending_offers_snapshot(true).size()
	var resolved := bool(_contract_controller.respond_to_offer(int(first.get("target_owner", -1)), int(first.get("offer_id", -1)), true, false).get("committed", false))
	var offers: Array = _contract_controller.pending_offers_snapshot(true)
	var observed := before_count == 2 and resolved and offers.size() == 1 and int((offers[0] as Dictionary).get("contract_offer_id", -1)) == int(second.get("offer_id", -2))
	return _record("multiple_pending_offers_resolve_independently", observed, observed, "Resolving one offer leaves the other offer and timer intact.", _flags_from_opened(first))


func _case_current_save() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50501)
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	var offers: Array = state.get("pending_contract_offers", [])
	var observed := state.has("selected_contract_source_district") and state.has("selected_contract_target_district") and offers.size() == 1 and int((offers[0] as Dictionary).get("contract_offer_id", -1)) == int(opened.get("offer_id", -2))
	return _record("current_save_shape", observed, observed, "Save version 1 keeps selected endpoints and the full pending-offer envelope.", _flags_from_opened(opened).merged({"save_checked": true}, true))


func _case_legacy_defaults() -> Dictionary:
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	state.erase("pending_contract_offers")
	state.erase("selected_contract_source_district")
	state.erase("selected_contract_target_district")
	var error := int(_runtime_main.call("_apply_run_state", state))
	var selection := _contract_controller.selection_snapshot()
	var observed := error == OK and _contract_controller.pending_offers_snapshot(true).is_empty() and int(selection.get("source_district", -2)) == -1 and int(selection.get("target_district", -2)) == -1
	return _record("legacy_save_defaults", observed, observed, "Missing v1 contract keys restore to no offer and no selected endpoints.", {"save_checked": true})


func _case_timer_save_parity() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50502)
	var offers: Array = _contract_controller.pending_offers_snapshot(true)
	offers[0]["contract_decision_timer"] = 3.25
	var contract_state := _contract_controller.to_save_data()
	contract_state["pending_contract_offers"] = offers
	_contract_controller.apply_save_data(contract_state)
	var state: Dictionary = _runtime_main.call("_capture_run_state")
	_contract_controller.reset_state()
	var error := int(_runtime_main.call("_apply_run_state", state))
	var restored_timer := _offer_timer(int(opened.get("offer_id", -1)))
	var observed := error == OK and is_equal_approx(restored_timer, 3.25)
	return _record("pending_timer_save_load_parity", observed, observed, "Pending response timer round-trips at %.2f seconds." % restored_timer, _flags_from_opened(opened).merged({"timer_before": 3.25, "timer_after": restored_timer, "save_checked": true, "timing_checked": true}, true))


func _case_public_clue() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50503)
	_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), int(opened.get("offer_id", -1)), true, false)
	var stored: Dictionary = _runtime_main.call("_card_resolution_entry_by_id", int(opened.get("offer_id", -1)))
	var clue := str(stored.get("contract_result_clue", ""))
	var observed := clue.contains("合约已签约") and clue.contains("发起者和回应者仍需推理") and not clue.contains("玩家1") and not clue.contains("玩家2")
	return _record("public_contract_result_clue", observed, observed, "Public aftermath states route, products, response, and effects without naming either party.", _flags_from_opened(opened).merged({"public_event_delta": 1, "privacy_checked": true}, true))


func _case_intel_trace() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50504)
	var offer_id := int(opened.get("offer_id", -1))
	_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), offer_id, true, false)
	var traced := _contract_controller.trace_contract_parties(2, offer_id, 1, "密约回溯测试")
	var players: Array = _runtime_main.get("players")
	var known: Dictionary = (players[2] as Dictionary).get("known_contract_parties", {})
	var private_entry: Dictionary = known.get(str(offer_id), {})
	var public_logs := "\n".join(_runtime_main.get("log_lines") as Array)
	var private_ok := int(private_entry.get("proposer", -1)) == 0 and int(private_entry.get("target_owner", -1)) == int(opened.get("target_owner", -2))
	var public_ok := not public_logs.contains("出牌方玩家1，目标业主玩家2")
	var observed := traced == 1 and private_ok and public_ok
	return _record("intel_trace_uses_sanitized_result", observed, observed, "Exact parties enter only viewer 2's private intelligence; public logs announce a clue without identities.", _flags_from_opened(opened).merged({"private_event_delta": 1, "public_event_delta": 1, "privacy_checked": true}, true))


func _case_hidden_owner() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50505)
	_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), int(opened.get("offer_id", -1)), true, false)
	var stored: Dictionary = _runtime_main.call("_card_resolution_entry_by_id", int(opened.get("offer_id", -1)))
	var public_text := _contract_controller.card_resolution_public_text(stored)
	var clue := str(stored.get("contract_result_clue", ""))
	var combined := "%s\n%s" % [public_text, clue]
	var observed := not combined.contains("player_index") and not combined.contains("contract_target_owner") and not combined.contains("玩家1") and not combined.contains("玩家2") and combined.contains("回应：已签约")
	return _record("hidden_owner_not_exposed", observed, observed, "Public track contract copy exposes outcome and economic clues, not proposer or responder identity.", _flags_from_opened(opened).merged({"privacy_checked": true}, true))


func _case_private_payload_boundary() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50506)
	var target_owner := int(opened.get("target_owner", -1))
	_runtime_main.set("selected_player", target_owner)
	var snapshot: Dictionary = _contract_controller.private_response_snapshot(target_owner)
	var serialized := JSON.stringify(snapshot)
	var observed := not serialized.contains("contract_target_owner") and not serialized.contains("player_index") and not serialized.contains("private_target") and not serialized.contains("private_discard") and not serialized.contains("ai_plan")
	return _record("private_target_and_private_discard_not_exposed", observed, observed, "Owner-only decision payload carries route and terms, never unrelated private target/discard or AI-plan fields.", _flags_from_opened(opened).merged({"privacy_checked": true}, true))


func _case_pure_snapshots() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50507)
	var target_owner := int(opened.get("target_owner", -1))
	var raw: Dictionary = _contract_controller.private_response_snapshot(target_owner)
	var pure := {
		"id": str(raw.get("id", "")),
		"kind": str(raw.get("kind", "")),
		"title": str(raw.get("title", "")),
		"body": str(raw.get("body", "")),
		"tooltip": str(raw.get("tooltip", "")),
		"actions": _plain_actions(raw.get("actions", []) as Array),
		"contract": _plain_contract(raw.get("contract", {}) as Dictionary),
	}
	var observed := _is_data_only(pure) and not _contains_runtime_object(pure) and JSON.parse_string(JSON.stringify(pure)) is Dictionary
	return _record("pure_data_snapshots", observed, observed, "Characterization, manifest, report, and sanitized contract bridge evidence contain only JSON-compatible values.", _flags_from_opened(opened).merged({"pure_data_checked": true, "privacy_checked": true}, true))


func _case_deletion_candidates() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var remaining: Array = []
	for function_name_variant in DELETION_CANDIDATES:
		var function_name := str(function_name_variant)
		if main_source.contains("func %s(" % function_name):
			remaining.append(function_name)
	for state_name_variant in STATE_DELETION_CANDIDATES:
		var state_name := str(state_name_variant)
		if main_source.contains("var %s" % state_name):
			remaining.append(state_name)
	for constant_name_variant in CONSTANT_DELETION_CANDIDATES:
		var constant_name := str(constant_name_variant)
		if main_source.contains("const %s" % constant_name):
			remaining.append(constant_name)
	var observed := remaining.is_empty() and DELETION_CANDIDATES.size() == 37
	return _record("sprint51_deletion_candidates_complete", observed, observed, "Sprint 51 removed %d functions, %d state fields, and %d response constants; remaining=%s." % [DELETION_CANDIDATES.size(), STATE_DELETION_CANDIDATES.size(), CONSTANT_DELETION_CANDIDATES.size(), str(remaining)])


func _case_controller_scene_composition() -> Dictionary:
	var controller_scene := load(CONTRACT_CONTROLLER_SCENE_PATH) as PackedScene
	var bridge_scene := load(CONTRACT_BRIDGE_SCENE_PATH) as PackedScene
	var controller_instance := controller_scene.instantiate() if controller_scene != null else null
	var bridge_instance := bridge_scene.instantiate() if bridge_scene != null else null
	var observed := controller_instance is ContractRuntimeController and bridge_instance is ContractRuntimeWorldBridge
	if controller_instance != null: controller_instance.free()
	if bridge_instance != null: bridge_instance.free()
	return _record("controller_scene_composition", observed, observed, "Both editable runtime scenes load with their expected root classes.", {"controller_checked": true, "bridge_checked": true})


func _case_controller_api_contract() -> Dictionary:
	var methods := ["configure", "reset_state", "plan_offer", "commit_offer", "plan_response", "commit_response", "tick", "private_response_snapshot", "public_snapshot", "to_save_data", "apply_save_data", "debug_snapshot"]
	var missing: Array = []
	for method_name in methods:
		if not _contract_controller.has_method(StringName(str(method_name))):
			missing.append(str(method_name))
	var observed := missing.is_empty()
	return _record("controller_api_contract", observed, observed, "Controller exposes the pure planning, commit, timing, snapshot, and save API; missing=%s." % str(missing), {"controller_checked": true})


func _case_coordinator_static_composition() -> Dictionary:
	var source := str(_sources.get("coordinator_scene", ""))
	var observed := source.contains("ContractRuntimeController.tscn") and source.contains("ContractRuntimeWorldBridge.tscn") and _contract_controller.get_parent() == _coordinator and _contract_bridge.get_parent() == _coordinator
	return _record("coordinator_static_composition", observed, observed, "Coordinator statically owns one Controller and one WorldBridge instance.", {"controller_checked": true, "bridge_checked": true})


func _case_state_owner_cutover() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var controller_source := str(_sources.get("contract_controller", ""))
	var main_absent := not main_source.contains("var pending_contract_offers") and not main_source.contains("var selected_contract_source_district") and not main_source.contains("var selected_contract_target_district")
	var controller_present := controller_source.contains("var pending_offers: Array") and controller_source.contains("var selected_source_district") and controller_source.contains("var selected_target_district")
	var observed := main_absent and controller_present
	return _record("state_owner_cutover", observed, observed, "The three runtime states exist only in ContractRuntimeController.", {"controller_checked": true, "legacy_absent": main_absent})


func _case_endpoint_product_owner_cutover() -> Dictionary:
	var fixture := _contract_fixture("双边对冲合约1", 50601)
	var context: Dictionary = fixture.get("context", {})
	var controller_source := str(_sources.get("contract_controller", ""))
	var main_source := str(_sources.get("main", ""))
	var observed := str(context.get("error", "")) == "" and (context.get("products", []) as Array).size() >= 2 and controller_source.contains("func _contract_products(") and not main_source.contains("func _area_trade_contract_products(")
	return _record("endpoint_product_owner_cutover", observed, observed, "Selected/auto/fixed/multi product derivation and endpoint state are Controller-owned.", _flags_from_fixture(fixture).merged({"controller_checked": true}, true))


func _case_project_controller_authority() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50602, 1, 2, 0)
	var context: Dictionary = fixture.get("context", {})
	var observed := int(context.get("target_owner", -1)) == 2 and int(fixture.get("target_city_owner", -1)) == 1 and not (context.get("target_project_ids", []) as Array).is_empty()
	return _record("project_controller_authority", observed, observed, "Responder 2 comes from target product projects, not target city owner 1.", _flags_from_fixture(fixture).merged({"controller_checked": true, "privacy_checked": true}, true))


func _case_explicit_self_sign_gate() -> Dictionary:
	var fixture := _contract_fixture("区域供需合约1", 50603, 1, 2, 2)
	var denied: Dictionary = fixture.get("context", {})
	var skill := (fixture.get("skill", {}) as Dictionary).duplicate(true)
	skill["contract_allow_self_sign"] = true
	var allowed := _contract_controller.offer_context(skill, 2, int(fixture.get("source", -1)), int(fixture.get("target", -1)), "活体芯片")
	var observed := str(denied.get("reason", "")) == "self_sign_not_allowed" and str(allowed.get("error", "")) == "" and int(allowed.get("target_owner", -1)) == 2
	return _record("explicit_self_sign_gate", observed, observed, "Self-sign is denied by default and enabled only by contract_allow_self_sign=true.", _flags_from_fixture(fixture).merged({"controller_checked": true}, true))


func _case_preempted_timer_suspends() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50604)
	var counter_entry := {"resolution_id": 88604, "queued_order": 88604, "player_index": 2, "skill": _skill("相位否决1")}
	_queue_service.call("replace_active_entry", counter_entry)
	_card_controller.call("begin_counter", 5.0)
	_runtime_main.call("_sync_forced_decision_runtime")
	var before := _offer_timer(int(opened.get("offer_id", -1)))
	_coordinator.call("tick_contract_runtime", 2.0)
	var after := _offer_timer(int(opened.get("offer_id", -1)))
	var observed := is_equal_approx(before, after)
	return _record("preempted_timer_suspends", observed, observed, "Counter arbitration pauses the hidden contract timer at %.1f seconds." % after, _flags_from_opened(opened).merged({"timer_before": before, "timer_after": after, "timing_checked": true, "forced_decision_checked": true}, true))


func _case_nonblocking_card_resolution() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50605)
	_runtime_main.call("_sync_forced_decision_runtime")
	var candidate := _candidate_by_kind(_runtime_main.call("_forced_decision_candidates"), "contract_response")
	var observed := not candidate.is_empty() and not bool(candidate.get("blocks_card_resolution", true)) and bool(_coordinator.call("allows_card_resolution_progress"))
	return _record("nonblocking_card_resolution", observed, observed, "The visible private response window does not block ordinary queue progress.", _flags_from_opened(opened).merged({"forced_decision_checked": true, "execution_boundary_checked": true}, true))


func _case_exact_once_transaction() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50606)
	var offer: Dictionary = opened.get("offer", {})
	var facts := _contract_bridge.contract_facts(int(offer.get("contract_source_district", -1)), int(offer.get("contract_target_district", -1)), "")
	var plan := _contract_controller.plan_response({"player_index": int(opened.get("target_owner", -1)), "contract_offer_id": int(opened.get("offer_id", -1)), "accept": true}, facts)
	var before := _contract_world_metrics(opened)
	var first := _contract_controller.commit_response(plan)
	var after_first := _contract_world_metrics(opened)
	var second := _contract_controller.commit_response(plan)
	var after_second := _contract_world_metrics(opened)
	var observed := bool(first.get("committed", false)) and not bool(second.get("committed", false)) and after_first == after_second and before != after_first
	return _record("exact_once_transaction", observed, observed, "offer_revision and transaction_id reject the second commit with zero additional mutation.", _metric_flags(opened, before, after_first).merged({"controller_checked": true}, true))


func _case_world_bridge_non_owning() -> Dictionary:
	var snapshot := _contract_bridge.debug_snapshot()
	var observed := bool(snapshot.get("bridge_ready", false)) and not bool(snapshot.get("owns_contract_state", true)) and not bool(snapshot.get("owns_contract_rules", true)) and not bool(snapshot.get("owns_contract_timer", true)) and _is_data_only(snapshot)
	return _record("world_bridge_non_owning", observed, observed, "WorldBridge collects facts and commits intents without offer, rule, timer, or AI ownership.", {"bridge_checked": true, "pure_data_checked": true})


func _case_player_ai_shared_route() -> Dictionary:
	var ai_source := str(_sources.get("ai", ""))
	var main_source := str(_sources.get("main", ""))
	var observed := ai_source.contains("_contract_runtime_controller.respond_to_offer") and main_source.contains("contract_controller.respond_to_offer(_runtime_snapshot_player_index()") and not main_source.contains("func _respond_to_pending_contract_for_player(")
	return _record("player_ai_shared_route", observed, observed, "Overlay actions and AI choices converge on ContractRuntimeController.respond_to_offer().", {"ai_route_checked": true, "controller_checked": true})


func _case_save_owner_cutover() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50607)
	var controller_save := _contract_controller.to_save_data()
	var run_save: Dictionary = _runtime_main.call("_capture_run_state")
	var main_source := str(_sources.get("main", ""))
	var observed := (controller_save.get("pending_contract_offers", []) as Array).size() == 1 and (run_save.get("pending_contract_offers", []) as Array).size() == 1 and main_source.contains("state.merge(contract_runtime_state, true)") and not main_source.contains("\"pending_contract_offers\":")
	return _record("save_owner_cutover", observed, observed, "Controller owns v1 legacy keys; main only merges the Controller envelope.", _flags_from_opened(opened).merged({"save_checked": true, "controller_checked": true}, true))


func _case_pure_public_private_snapshots() -> Dictionary:
	var opened := _open_offer("区域供需合约1", 50608)
	var public_snapshot := _contract_controller.public_snapshot()
	var private_snapshot := _contract_controller.private_response_snapshot(int(opened.get("target_owner", -1)))
	var debug := _contract_controller.debug_snapshot(-1)
	var save := _contract_controller.to_save_data()
	var serialized_public := JSON.stringify(public_snapshot)
	var observed := _is_data_only(public_snapshot) and _is_data_only(private_snapshot) and _is_data_only(debug) and _is_data_only(save) and not serialized_public.contains("contract_target_owner") and not serialized_public.contains("player_index")
	return _record("pure_public_private_snapshots", observed, observed, "Public/private/debug/save envelopes are pure data and public output hides responder identity.", _flags_from_opened(opened).merged({"privacy_checked": true, "pure_data_checked": true, "controller_checked": true}, true))


func _case_main_legacy_contract_absent() -> Dictionary:
	var source := str(_sources.get("main", ""))
	var metrics := _main_metrics(source)
	var absent := true
	for function_name in DELETION_CANDIDATES:
		absent = absent and not source.contains("func %s(" % str(function_name))
	for state_name in STATE_DELETION_CANDIDATES:
		absent = absent and not source.contains("var %s" % str(state_name))
	for constant_name in CONSTANT_DELETION_CANDIDATES:
		absent = absent and not source.contains("const %s" % str(constant_name))
	var metrics_pass := int(metrics.get("nonblank_lines", 999999)) <= 24589 and int(metrics.get("function_count", 999999)) <= 1385 and int(metrics.get("top_level_variable_count", 999999)) <= 145 and int(metrics.get("constant_count", 999999)) <= 228
	var observed := absent and metrics_pass
	return _record("main_legacy_contract_absent", observed, observed, "No parallel main contract owner remains; metrics=%s." % str(metrics), {"legacy_absent": absent, "controller_checked": true})


func _load_sources() -> void:
	_sources = {
		"main": FileAccess.get_file_as_string(MAIN_SCRIPT_PATH),
		"ruleset": FileAccess.get_file_as_string(RULESET_BRIDGE_SCRIPT_PATH),
		"scheduler": FileAccess.get_file_as_string(FORCED_SCHEDULER_SCRIPT_PATH),
		"ai": FileAccess.get_file_as_string(AI_CONTROLLER_SCRIPT_PATH),
		"execution": FileAccess.get_file_as_string(EXECUTION_SERVICE_SCRIPT_PATH),
		"queue": FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH),
		"formula": FileAccess.get_file_as_string(FORMULA_SERVICE_SCRIPT_PATH),
		"panel": FileAccess.get_file_as_string(CONTRACT_PANEL_SCRIPT_PATH),
		"contract_controller": FileAccess.get_file_as_string(CONTRACT_CONTROLLER_SCRIPT_PATH),
		"contract_bridge": FileAccess.get_file_as_string(CONTRACT_BRIDGE_SCRIPT_PATH),
		"coordinator_scene": FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH),
	}


func _ensure_runtime_main() -> bool:
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
	var runtime_coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng != null:
		runtime_rng.seed = FIXED_SEED
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_ruleset_bridge = _runtime_main.get_node_or_null("RuntimeServices/RulesetRuntimeBridge")
	_scheduler = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ForcedDecisionRuntimeScheduler")
	_card_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/CardResolutionRuntimeController")
	_queue_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService")
	_execution_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionExecutionRuntimeService")
	_formula_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService")
	_ai_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	_contract_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController") as ContractRuntimeController
	_contract_bridge = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeWorldBridge") as ContractRuntimeWorldBridge
	_product_market_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController") as ProductMarketRuntimeController
	_overlay_layer = _runtime_main.find_child("OverlayLayer", true, false) as CanvasLayer
	_baseline_players = (_runtime_main.get("players") as Array).duplicate(true)
	_baseline_districts = (_runtime_main.get("districts") as Array).duplicate(true)
	_baseline_product_market = _product_market_controller.to_save_data().duplicate(true) if _product_market_controller != null else {}
	return _coordinator != null and _ruleset_bridge != null and _scheduler != null and _card_controller != null and _queue_service != null and _execution_service != null and _formula_service != null and _ai_controller != null and _contract_controller != null and _contract_bridge != null and _product_market_controller != null and _overlay_layer != null and not _baseline_players.is_empty() and not _baseline_districts.is_empty()


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	_runtime_main.set("players", _baseline_players.duplicate(true))
	_runtime_main.set("districts", _baseline_districts.duplicate(true))
	_product_market_controller.apply_save_data(_baseline_product_market.duplicate(true))
	_contract_controller.reset_state()
	_runtime_main.set("selected_trade_product", "活体芯片")
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("inspected_player", 0)
	_runtime_main.set("game_time", 100.0)
	_runtime_main.set("game_over", false)
	_runtime_main.set("log_lines", [])
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	_runtime_main.set("movement_trails", [])
	_runtime_main.set("resolved_card_history", [])
	_runtime_main.set("selected_card_resolution_id", -1)
	_queue_service.call("reset_state")
	_execution_service.call("reset_state")
	_card_controller.call("reset_state")
	_coordinator.call("sync_forced_decision_candidates", [])
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	for player_index in range(players.size()):
		var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
		player["cash"] = 5000
		player["slots"] = []
		player["is_ai"] = false
		player["eliminated"] = false
		player["economic_ledger"] = []
		player["known_contract_parties"] = {}
		players[player_index] = player
	_runtime_main.set("players", players)


func _contract_fixture(card_id: String, resolution_id: int, target_city_owner: int = 1, target_project_controller: int = 1, source_owner: int = 0) -> Dictionary:
	var source_index := _first_district("land")
	var target_index := _first_district("land", [source_index])
	if source_index < 0 or target_index < 0:
		return {}
	var source_city: Dictionary = CITY_FIXTURES.create_city_surface(_runtime_main, source_owner, source_index, "Contract source fixture")
	var target_city: Dictionary = CITY_FIXTURES.create_city_surface(_runtime_main, target_city_owner, target_index, "Contract target fixture")
	if source_city.is_empty() or target_city.is_empty():
		return {}
	var districts: Array = (_runtime_main.get("districts") as Array).duplicate(true)
	var source_district: Dictionary = (districts[source_index] as Dictionary).duplicate(true)
	var target_district: Dictionary = (districts[target_index] as Dictionary).duplicate(true)
	source_city = (source_district.get("city", {}) as Dictionary).duplicate(true)
	target_city = (target_district.get("city", {}) as Dictionary).duplicate(true)
	source_city["owner"] = source_owner
	source_city["products"] = [{"name": "真空可可", "level": 1}, {"name": "活体芯片", "level": 1}]
	source_city["demands"] = ["离子香料"]
	source_city["projects"] = [CITY_PROJECT_STATE.create_project(source_index, "真空可可", "production", source_owner, 2, 1)]
	target_city["owner"] = target_city_owner
	target_city["products"] = [{"name": "梦境香氛", "level": 1}]
	target_city["demands"] = ["重力陶瓷", "活体芯片"]
	target_city["projects"] = []
	var project_order := 2
	for product_id in ["活体芯片", "真空可可", "环晶电池", "重力陶瓷", "梦境香氛"]:
		target_city["projects"].append(CITY_PROJECT_STATE.create_project(target_index, product_id, "demand", target_project_controller, 2, project_order))
		project_order += 1
	source_district["products"] = ["真空可可", "活体芯片"]
	source_district["demands"] = ["离子香料"]
	source_district["city"] = source_city
	target_district["products"] = ["梦境香氛"]
	target_district["demands"] = ["重力陶瓷", "活体芯片"]
	target_district["city"] = target_city
	districts[source_index] = source_district
	districts[target_index] = target_district
	_runtime_main.set("districts", districts)
	_contract_controller.set_selection_state(source_index, target_index)
	_runtime_main.set("selected_trade_product", "活体芯片")
	var skill := _skill(card_id)
	var context: Dictionary = _contract_controller.offer_context(skill, source_owner, source_index, target_index, "活体芯片")
	var entry := {
		"resolution_id": resolution_id,
		"queued_order": resolution_id,
		"player_index": source_owner,
		"selected_district": source_index,
		"selected_trade_product": "活体芯片",
		"contract_source_district": source_index,
		"contract_target_district": target_index,
		"contract_target_owner": int(context.get("target_owner", -1)),
		"contract_target_project_ids": (context.get("target_project_ids", []) as Array).duplicate(true),
		"contract_products": (context.get("products", []) as Array).duplicate(true),
		"contract_response": "pending",
		"skill": skill.duplicate(true),
	}
	return {
		"card_id": card_id,
		"skill": skill,
		"context": context,
		"entry": entry,
		"source": source_index,
		"target": target_index,
		"source_owner": source_owner,
		"target_city_owner": target_city_owner,
		"target_project_controller": target_project_controller,
	}


func _open_offer(card_id: String, resolution_id: int, reset_existing: bool = true) -> Dictionary:
	if reset_existing:
		var save_state := _contract_controller.to_save_data()
		save_state["pending_contract_offers"] = []
		_contract_controller.apply_save_data(save_state)
	var fixture := _contract_fixture(card_id, resolution_id)
	if fixture.is_empty():
		return {"opened": false, "fixture": fixture}
	var open_result := _contract_controller.open_offer(fixture.get("skill", {}), fixture.get("entry", {}))
	var opened := bool(open_result.get("opened", false))
	var offers: Array = _contract_controller.pending_offers_snapshot(true)
	var offer: Dictionary = {}
	for offer_variant in offers:
		if offer_variant is Dictionary and int((offer_variant as Dictionary).get("contract_offer_id", -1)) == resolution_id:
			offer = (offer_variant as Dictionary).duplicate(true)
			break
	return {
		"opened": opened and not offer.is_empty(),
		"fixture": fixture,
		"offer": offer,
		"offer_id": int(offer.get("contract_offer_id", -1)),
		"target_owner": int(offer.get("contract_target_owner", -1)),
	}


func _skill(card_id: String) -> Dictionary:
	var value: Variant = _runtime_main.call("_make_skill", card_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _first_district(terrain: String = "", excluded: Array = []) -> int:
	var districts: Array = _runtime_main.get("districts") if _runtime_main != null else _baseline_districts
	for district_index in range(districts.size()):
		if excluded.has(district_index):
			continue
		var district: Dictionary = districts[district_index]
		if bool(district.get("destroyed", false)):
			continue
		if terrain == "" or str(district.get("terrain", "land")) == terrain:
			return district_index
	return -1


func _offer_timer(offer_id: int) -> float:
	for offer_variant in _contract_controller.pending_offers_snapshot(true):
		if offer_variant is Dictionary and int((offer_variant as Dictionary).get("contract_offer_id", -1)) == offer_id:
			return float((offer_variant as Dictionary).get("contract_decision_timer", -1.0))
	return -1.0


func _candidate_by_kind(candidates: Array, kind: String) -> Dictionary:
	for candidate_variant in candidates:
		if candidate_variant is Dictionary and str((candidate_variant as Dictionary).get("kind", "")) == kind:
			return (candidate_variant as Dictionary).duplicate(true)
	return {}


func _contract_world_metrics(opened: Dictionary) -> Dictionary:
	var fixture: Dictionary = opened.get("fixture", {})
	var target_index := int(fixture.get("target", -1))
	var target_owner := int(opened.get("target_owner", fixture.get("target_city_owner", -1)))
	var districts: Array = _runtime_main.get("districts")
	var target_district: Dictionary = districts[target_index] if target_index >= 0 and target_index < districts.size() else {}
	var city: Dictionary = target_district.get("city", {}) if target_district.get("city", {}) is Dictionary else {}
	var players: Array = _runtime_main.get("players")
	var cash := int((players[target_owner] as Dictionary).get("cash", 0)) if target_owner >= 0 and target_owner < players.size() else 0
	return {
		"cash": cash,
		"production": int(target_district.get("production_level", 0)),
		"transport": int(target_district.get("transport_level", 0)),
		"consumption": int(target_district.get("consumption_level", 0)),
		"product_count": (target_district.get("products", []) as Array).size(),
		"demand_count": (target_district.get("demands", []) as Array).size(),
		"route_flow_milli": roundi(float(city.get("route_flow_multiplier", 1.0)) * 1000.0),
		"route_damage": int(city.get("trade_route_damage", 0)),
		"pending_count": _contract_controller.pending_offers_snapshot(true).size(),
		"history_count": (_runtime_main.get("resolved_card_history") as Array).size(),
		"public_events": (_runtime_main.get("log_lines") as Array).size() + (_runtime_main.get("action_callouts") as Array).size(),
		"private_events": ((players[target_owner] as Dictionary).get("economic_ledger", []) as Array).size() if target_owner >= 0 and target_owner < players.size() else 0,
	}


func _metric_flags(opened: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var fixture: Dictionary = opened.get("fixture", {})
	return {
		"card_id": str(fixture.get("card_id", "")),
		"contract_offer_id": int(opened.get("offer_id", -1)),
		"source_district": int(fixture.get("source", -1)),
		"target_district": int(fixture.get("target", -1)),
		"product_count": ((fixture.get("context", {}) as Dictionary).get("products", []) as Array).size(),
		"cash_delta": int(after.get("cash", 0)) - int(before.get("cash", 0)),
		"production_delta": int(after.get("production", 0)) - int(before.get("production", 0)),
		"demand_delta": int(after.get("demand_count", 0)) - int(before.get("demand_count", 0)),
		"transport_delta": int(after.get("transport", 0)) - int(before.get("transport", 0)),
		"route_flow_delta": int(after.get("route_flow_milli", 0)) - int(before.get("route_flow_milli", 0)),
		"route_damage_delta": int(after.get("route_damage", 0)) - int(before.get("route_damage", 0)),
		"public_event_delta": int(after.get("public_events", 0)) - int(before.get("public_events", 0)),
		"private_event_delta": int(after.get("private_events", 0)) - int(before.get("private_events", 0)),
	}


func _flags_from_fixture(fixture: Dictionary) -> Dictionary:
	var context: Dictionary = fixture.get("context", {})
	return {
		"card_id": str(fixture.get("card_id", "")),
		"contract_offer_id": int((fixture.get("entry", {}) as Dictionary).get("resolution_id", -1)),
		"source_district": int(fixture.get("source", -1)),
		"target_district": int(fixture.get("target", -1)),
		"product_count": (context.get("products", []) as Array).size(),
	}


func _flags_from_opened(opened: Dictionary) -> Dictionary:
	var fixture: Dictionary = opened.get("fixture", {})
	var flags := _flags_from_fixture(fixture)
	flags["contract_offer_id"] = int(opened.get("offer_id", flags.get("contract_offer_id", -1)))
	flags["timer_before"] = float((opened.get("offer", {}) as Dictionary).get("contract_decision_timer", 0.0))
	return flags


func _acceptance_metrics(ai: bool, resolution_id: int) -> Dictionary:
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	players[1]["is_ai"] = ai
	_runtime_main.set("players", players)
	var opened := _open_offer("区域供需合约1", resolution_id)
	var before := _contract_world_metrics(opened)
	var resolved := bool(_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), int(opened.get("offer_id", -1)), true, false).get("committed", false))
	var after := _contract_world_metrics(opened)
	return _metric_flags(opened, before, after).merged({"resolved": resolved, "response_kind": "accepted"}, true)


func _rejection_metrics(timeout: bool, resolution_id: int) -> Dictionary:
	var opened := _open_offer("区域供需合约2", resolution_id)
	var before := _contract_world_metrics(opened)
	var resolved := false
	if timeout:
		_contract_controller.tick_visible_offer(5.1, "contract_response_%d" % int(opened.get("offer_id", -1)))
		resolved = _contract_controller.pending_offers_snapshot(true).is_empty()
	else:
		resolved = bool(_contract_controller.respond_to_offer(int(opened.get("target_owner", -1)), int(opened.get("offer_id", -1)), false, false).get("committed", false))
	var after := _contract_world_metrics(opened)
	return _metric_flags(opened, before, after).merged({"resolved": resolved, "response_kind": "timeout" if timeout else "rejected"}, true)


func _plain_actions(actions: Array) -> Array:
	var result: Array = []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		result.append({"id": str(action.get("id", "")), "label": str(action.get("label", "")), "tooltip": str(action.get("tooltip", "")), "disabled": bool(action.get("disabled", false))})
	return result


func _plain_contract(contract: Dictionary) -> Dictionary:
	var result := {}
	for key_variant in contract.keys():
		var key := str(key_variant)
		var value: Variant = contract[key_variant]
		if value == null or value is String or value is StringName or value is bool or value is int or value is float:
			result[key] = value
	return result


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"case_id": case_id,
		"phase": "cutover" if CUTOVER_CASE_IDS.has(case_id) else "runtime_revalidation",
		"card_id": str(flags.get("card_id", "")),
		"contract_offer_id": int(flags.get("contract_offer_id", -1)),
		"response_kind": str(flags.get("response_kind", "")),
		"source_district": int(flags.get("source_district", -1)),
		"target_district": int(flags.get("target_district", -1)),
		"product_count": int(flags.get("product_count", 0)),
		"timer_before": float(flags.get("timer_before", 0.0)),
		"timer_after": float(flags.get("timer_after", 0.0)),
		"cash_delta": int(flags.get("cash_delta", 0)),
		"production_delta": int(flags.get("production_delta", 0)),
		"demand_delta": int(flags.get("demand_delta", 0)),
		"transport_delta": int(flags.get("transport_delta", 0)),
		"route_flow_delta": int(flags.get("route_flow_delta", 0)),
		"route_damage_delta": int(flags.get("route_damage_delta", 0)),
		"public_event_delta": int(flags.get("public_event_delta", 0)),
		"private_event_delta": int(flags.get("private_event_delta", 0)),
		"execution_boundary_checked": bool(flags.get("execution_boundary_checked", false)),
		"formula_service_checked": bool(flags.get("formula_service_checked", false)),
		"ai_route_checked": bool(flags.get("ai_route_checked", false)),
		"forced_decision_checked": bool(flags.get("forced_decision_checked", false)),
		"timing_checked": bool(flags.get("timing_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"controller_checked": bool(flags.get("controller_checked", false)),
		"bridge_checked": bool(flags.get("bridge_checked", false)),
		"legacy_absent": bool(flags.get("legacy_absent", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", not aligned)),
		"risk": str(flags.get("risk", "" if aligned else "Observed behavior differs from or is underspecified by v0.4.")),
		"passed": observed,
		"notes": notes,
	}


func _main_metrics(source: String) -> Dictionary:
	var lines := source.split("\n")
	var total_lines := lines.size()
	if total_lines > 0 and str(lines[total_lines - 1]).is_empty():
		total_lines -= 1
	var nonblank := 0
	var functions := 0
	var variables := 0
	var constants := 0
	for line_variant in lines:
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank += 1
		if line.begins_with("func "):
			functions += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
	return {"total_lines": total_lines, "nonblank_lines": nonblank, "function_count": functions, "top_level_variable_count": variables, "constant_count": constants}


func _count_flag(key: String) -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get(key, false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	summary_label.text = "Observed %d/%d | Aligned %d/%d | Design decisions %d" % [observed, CASE_COUNT, aligned, CASE_COUNT, decisions]
	status_label.text = "CUTOVER VERIFIED" if _failures.is_empty() else "CUTOVER FAILURE"
	ownership_text.text = "[b]Sprint 51 authoritative owner[/b]\nContractRuntimeController: endpoints, product context, offers, visible timer, response transaction, privacy snapshots, save\nContractRuntimeWorldBridge: fact collection and stable world commits only\n\n[b]Preserved external owners[/b]\nRuleset: five-second timing\nForced scheduler: priority\nAI: response choice only\nExecution: active release/continuation\nFormula: deterministic arithmetic\nOverlay: editable response UI\n\n[b]v0.4 decisions locked[/b]\nProject-controller authority, explicit self-sign permission, preempted timer suspension, and non-blocking card progress."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("%s %s | %s" % ["OK" if bool(record.get("observed", false)) else "FAIL", str(record.get("case_id", "")), "aligned" if bool(record.get("contract_aligned", false)) else "decision required"])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Contract Runtime Hard Cutover - Sprint 51",
		"",
		"Ruleset: `%s`" % RULESET_ID,
		"Runtime owner: `ContractRuntimeController`",
		"Runtime cutover enabled: `true`",
		"Observed: %d/%d" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"Design decisions: %d" % int(manifest.get("needs_design_decision_count", 0)),
		"Main deletion gate passed: `%s`" % str(manifest.get("main_deletion_gate_passed", false)),
		"",
		"## Final ownership boundary",
		"",
		"- `ContractRuntimeController`: selected endpoints, products, target-project authority, pending offers, visible timer, response transaction, result clues, snapshots, and v1 save fields.",
		"- `ContractRuntimeWorldBridge`: pure fact collection and Controller-authored world commits; no offer, timer, policy, or AI state.",
		"- `RulesetRuntimeBridge`: five-second contract timing.",
		"- `ForcedDecisionRuntimeScheduler`: monster wager, counter, contract, other-choice priority.",
		"- `AiRuntimeController`: response candidates and choice only.",
		"- `CardResolutionExecutionRuntimeService`: release-active and asynchronous continuation lifecycle.",
		"- `CardEconomyProductRouteFormulaRuntimeService`: existing pure deterministic formulas only.",
		"- `ContractResponseDecisionPanel`: editable owner-only response presentation.",
		"",
		"## v0.4 decision locks",
		"",
		"- Response authority is the unique target product-project controller; ambiguous multi-controller offers fail atomically.",
		"- Self-sign is denied unless the card explicitly sets `contract_allow_self_sign=true`.",
		"- Contract time decreases only while that exact offer is the visible forced decision.",
		"- Contract forced decisions set `blocks_card_resolution=false`.",
		"",
		"## Cases",
		"",
		"| Case | Card | Response | Observed | Aligned | Decision | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("card_id", "")), str(record.get("response_kind", "")), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("needs_design_decision", false)), str(record.get("notes", "")).replace("|", "/")])
	lines.append_array([
		"",
		"## Sprint 51 deletion gate",
		"",
		"Move pending-offer state, endpoint/product context, five-second visible-time lifecycle, accept/reject/timeout transaction orchestration, save data, and sanitized trace receipts into one ContractRuntimeController plus a non-owning WorldBridge. Delete the mapped main.gd implementations in the same change; do not keep a parallel fallback.",
		"",
	])
	return "\n".join(lines)


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name in ["manifest.json", "report.md"]:
		var path := OUTPUT_DIR + str(file_name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK:
		_failures.append("screenshot save failed: %s" % error_string(error))


func _hide_runtime_canvas_layers() -> void:
	for node_variant in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if node_variant is CanvasLayer:
			(node_variant as CanvasLayer).visible = false


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
		_runtime_main.queue_free()
	_runtime_main = null
	_coordinator = null
	_ruleset_bridge = null
	_scheduler = null
	_card_controller = null
	_queue_service = null
	_execution_service = null
	_formula_service = null
	_ai_controller = null
	_contract_controller = null
	_contract_bridge = null
	_overlay_layer = null


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _tokens_in_order(source: String, tokens: Array) -> bool:
	var offset := 0
	for token_variant in tokens:
		var found := source.find(str(token_variant), offset)
		if found < 0:
			return false
		offset = found + str(token_variant).length()
	return true


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Object:
		return true
	if value is Array:
		for item in value:
			if _contains_runtime_object(item):
				return true
	if value is Dictionary:
		for key in value.keys():
			if _contains_runtime_object(key) or _contains_runtime_object(value[key]):
				return true
	return false
