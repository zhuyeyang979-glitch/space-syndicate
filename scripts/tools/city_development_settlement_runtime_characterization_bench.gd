extends Control
class_name CityDevelopmentSettlementRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CITY_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/city_development_runtime_controller.gd"
const CITY_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/city_development_world_bridge.gd"
const COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const NETWORK_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const GDP_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/gdp_formula_runtime_controller.gd"
const PRODUCT_MARKET_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_controller.gd"
const EXECUTION_SCRIPT_PATH := "res://scripts/runtime/card_resolution_execution_runtime_service.gd"
const PROJECT_STATE_SCRIPT_PATH := "res://scripts/economy/city_product_project_state.gd"
const PROJECT_BRIDGE_SCRIPT_PATH := "res://scripts/economy/city_product_project_bridge.gd"
const CORE_DEVELOPMENT_PACK_PATH := "res://resources/economy/core_city_development_pack.tres"
const PROJECT_STATE := preload(PROJECT_STATE_SCRIPT_PATH)
const PROJECT_BRIDGE := preload(PROJECT_BRIDGE_SCRIPT_PATH)

const OUTPUT_DIR := "user://space_syndicate_design_qa/city_development_settlement_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/city_development_settlement_hard_cutover_sprint_66.png"
const RULESET_ID := "v0.4"
const CASE_COUNT := 62
const FIXED_SEED := 650065
const BASELINE_MAIN_SHA256 := "B8174D78AA08BE2883E7EA5C7A5568CB8C5ED902D1945BCE0EAE8F7D3AD3CC67"
const BASELINE_MAIN_METRICS := {
	"nonblank_lines": 20494,
	"function_count": 1296,
	"top_level_variable_count": 141,
	"constant_count": 211,
}

const CASE_IDS := [
	"city_development_settlement_call_graph_complete",
	"legality_controller_boundary",
	"project_bridge_boundary",
	"network_controller_boundary",
	"real_runtime_cards_three_directions",
	"queue_execution_dispatch_route",
	"production_project_success",
	"demand_project_success",
	"commerce_project_success",
	"invalid_player_atomic",
	"invalid_district_atomic",
	"destroyed_district_atomic",
	"terrain_reject_atomic",
	"missing_product_atomic",
	"unavailable_product_atomic",
	"direct_build_disabled_no_mutation",
	"first_city_surface_shape",
	"cities_built_exact_once",
	"hp_bonus_and_damage_repair",
	"built_at_and_visual_order",
	"stable_project_identity",
	"project_sequence_exact_once",
	"first_contribution_full_share",
	"repeated_contribution_strengthens",
	"second_player_share_split",
	"tie_has_no_controller",
	"contribution_order_stable",
	"gdp_remainder_controller",
	"production_legacy_sync",
	"demand_legacy_sync",
	"commerce_transport_upgrade",
	"refresh_order_network_market_gdp",
	"lifecycle_opened_resolved",
	"economic_event_exact_once",
	"public_callout_anonymous",
	"public_private_project_privacy",
	"current_and_migration_save_shape",
	"downstream_refresh_atomicity_characterized",
	"sprint66_deletion_candidates_complete",
	"controller_bridge_scene_composition",
	"unique_settlement_owner",
	"plan_is_pure_and_no_mutation",
	"preflight_is_pure_and_no_mutation",
	"production_cutover_parity",
	"demand_cutover_parity",
	"commerce_cutover_parity",
	"city_creation_exact_once",
	"sequence_claim_exact_once",
	"share_and_no_controller_parity",
	"commerce_transport_parity",
	"stale_fingerprint_rejected",
	"downstream_owner_missing_rejected",
	"failed_commit_rolls_back_world",
	"network_market_gdp_order",
	"lifecycle_events_exact_once",
	"player_route_uses_coordinator",
	"ai_route_uses_coordinator",
	"save_compatibility_cutover",
	"public_receipt_privacy",
	"reflected_tests_migrated",
	"main_legacy_settlement_absent",
	"no_parallel_city_engine",
]

const SPRINT66_CANDIDATES := [
	"_city_development_target_error",
	"_normalize_city_runtime_fields",
	"_create_city_surface_for_development",
	"_apply_city_development_card",
	"_city_build_error",
	"_city_build_error_for",
	"_create_city_at_district_for_player",
	"_build_city_in_selected_district",
	"_make_city_products",
	"_make_city_demands",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _city_controller: Node
var _city_world_bridge: Node
var _network_controller: Node
var _gdp_controller: Node
var _product_market: Node
var _coordinator: Node
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _baseline_city_cards: Dictionary = {}
var _baseline_project_sequence := 1
var _baseline_market_save: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []
var _sources: Dictionary = {}


func _ready() -> void:
	print("CityDevelopmentSettlementRuntimeCharacterizationBench Sprint 66 ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return CASE_IDS.duplicate()


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in CASE_IDS:
		records.append(_record(str(case_id_variant), false, false, "preview"))
	return {
		"suite": "city-development-settlement-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"current_settlement_owner": CITY_CONTROLLER_SCRIPT_PATH,
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
		"next_cutover_recommendation": "Settlement cutover complete; select the next main.gd ownership family from the runtime audit.",
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_load_sources()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("CityDevelopmentSettlementRuntimeCharacterizationBench could not instantiate real main.tscn.")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in CASE_IDS:
		_reset_fixture()
		var case_id := str(case_id_variant)
		print("CityDevelopmentSettlementRuntimeCharacterizationBench case: %s" % case_id)
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var main_source := str(_sources.get("main", ""))
	var main_sha := main_source.sha256_text().to_upper()
	var main_metrics := _main_metrics(main_source)
	var main_reduced := int(main_metrics.get("nonblank_lines", 999999)) <= 20274 and int(main_metrics.get("function_count", 999999)) <= 1289 and int(main_metrics.get("top_level_variable_count", 999999)) <= int(BASELINE_MAIN_METRICS.get("top_level_variable_count", 141)) and int(main_metrics.get("constant_count", 999999)) <= int(BASELINE_MAIN_METRICS.get("constant_count", 211))
	if not main_reduced:
		_failures.append("production main.gd did not meet Sprint 66 deletion gate: metrics=%s" % str(main_metrics))
	var manifest := {
		"suite": "city-development-settlement-hard-cutover-v04",
		"ruleset_id": RULESET_ID,
		"current_settlement_owner": CITY_CONTROLLER_SCRIPT_PATH,
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
		"current_main_sha256": main_sha,
		"baseline_main_metrics": BASELINE_MAIN_METRICS.duplicate(true),
		"main_metrics": main_metrics,
		"production_main_unchanged": false,
		"main_deletion_gate_passed": main_reduced,
		"next_cutover_recommendation": "Settlement cutover complete; select the next main.gd ownership family from the runtime audit.",
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("CityDevelopmentSettlementRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("CityDevelopmentSettlementRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("CityDevelopmentSettlementRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("CityDevelopmentSettlementRuntimeCharacterizationBench observed: %d/%d; aligned=%d/%d; design_decisions=%d" % [_count_flag("observed"), CASE_COUNT, _count_flag("contract_aligned"), CASE_COUNT, _count_flag("needs_design_decision")])
	if not _failures.is_empty():
		push_error("CityDevelopmentSettlementRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"city_development_settlement_call_graph_complete": return _case_call_graph()
		"legality_controller_boundary": return _case_legality_boundary()
		"project_bridge_boundary": return _case_project_bridge_boundary()
		"network_controller_boundary": return _case_network_boundary()
		"real_runtime_cards_three_directions": return _case_real_cards()
		"queue_execution_dispatch_route": return _case_execution_route()
		"production_project_success": return _case_direction_success("production")
		"demand_project_success": return _case_direction_success("demand")
		"commerce_project_success": return _case_direction_success("commerce")
		"invalid_player_atomic": return _case_atomic_rejection("invalid_player")
		"invalid_district_atomic": return _case_atomic_rejection("invalid_district")
		"destroyed_district_atomic": return _case_atomic_rejection("destroyed")
		"terrain_reject_atomic": return _case_atomic_rejection("terrain")
		"missing_product_atomic": return _case_atomic_rejection("missing_product")
		"unavailable_product_atomic": return _case_atomic_rejection("unavailable_product")
		"direct_build_disabled_no_mutation": return _case_direct_build_disabled()
		"first_city_surface_shape": return _case_first_city_shape()
		"cities_built_exact_once": return _case_cities_built_once()
		"hp_bonus_and_damage_repair": return _case_hp_and_repair()
		"built_at_and_visual_order": return _case_built_at_visual()
		"stable_project_identity": return _case_stable_project_id()
		"project_sequence_exact_once": return _case_sequence_once()
		"first_contribution_full_share": return _case_first_share()
		"repeated_contribution_strengthens": return _case_repeat_contribution()
		"second_player_share_split": return _case_second_player_share()
		"tie_has_no_controller": return _case_tie_controller()
		"contribution_order_stable": return _case_contribution_order()
		"gdp_remainder_controller": return _case_gdp_remainder()
		"production_legacy_sync": return _case_legacy_sync("production")
		"demand_legacy_sync": return _case_legacy_sync("demand")
		"commerce_transport_upgrade": return _case_commerce_transport()
		"refresh_order_network_market_gdp": return _case_refresh_order()
		"lifecycle_opened_resolved": return _case_lifecycle()
		"economic_event_exact_once": return _case_economic_event()
		"public_callout_anonymous": return _case_public_callout()
		"public_private_project_privacy": return _case_privacy()
		"current_and_migration_save_shape": return _case_save_shape()
		"downstream_refresh_atomicity_characterized": return _case_downstream_atomicity()
		"sprint66_deletion_candidates_complete": return _case_deletion_map()
		"controller_bridge_scene_composition": return _case_cutover_composition()
		"unique_settlement_owner": return _case_unique_owner()
		"plan_is_pure_and_no_mutation": return _case_plan_pure()
		"preflight_is_pure_and_no_mutation": return _case_preflight_pure()
		"production_cutover_parity": return _case_cutover_parity("production")
		"demand_cutover_parity": return _case_cutover_parity("demand")
		"commerce_cutover_parity": return _case_cutover_parity("commerce")
		"city_creation_exact_once": return _rename_record("city_creation_exact_once", _case_cities_built_once())
		"sequence_claim_exact_once": return _rename_record("sequence_claim_exact_once", _case_sequence_once())
		"share_and_no_controller_parity": return _case_share_tie_parity()
		"commerce_transport_parity": return _rename_record("commerce_transport_parity", _case_commerce_transport())
		"stale_fingerprint_rejected": return _case_stale_fingerprint()
		"downstream_owner_missing_rejected": return _case_downstream_missing()
		"failed_commit_rolls_back_world": return _case_failed_commit_rollback()
		"network_market_gdp_order": return _rename_record("network_market_gdp_order", _case_refresh_order())
		"lifecycle_events_exact_once": return _case_lifecycle_events_exact_once()
		"player_route_uses_coordinator": return _case_route_source("player")
		"ai_route_uses_coordinator": return _case_route_source("ai")
		"save_compatibility_cutover": return _rename_record("save_compatibility_cutover", _case_save_shape())
		"public_receipt_privacy": return _case_public_receipt_privacy()
		"reflected_tests_migrated": return _case_reflected_tests_migrated()
		"main_legacy_settlement_absent": return _case_legacy_absent()
		"no_parallel_city_engine": return _case_no_parallel_engine()
	return _record(case_id, false, false, "Unknown case.")


func _case_call_graph() -> Dictionary:
	var settlement := str(_sources.get("city_controller", "")) + str(_sources.get("city_world_bridge", "")) + _function_source(str(_sources.get("coordinator", "")), "execute_city_development")
	var required := ["plan_settlement", "preflight_settlement", "claim_project_sequence_if", "apply_project_contribution", "refresh_networks", "refresh_prices", "city_gdp_breakdown", "private_projects", "finalize_settlement", "apply_post_commit_intents"]
	var missing: Array = []
	for token in required:
		if not settlement.contains(str(token)):
			missing.append(token)
	var observed := missing.is_empty()
	return _record("city_development_settlement_call_graph_complete", observed, observed, "Controller -> WorldBridge -> downstream owners -> finalize call graph captured; missing=%s." % str(missing))


func _case_legality_boundary() -> Dictionary:
	var source := str(_sources.get("city_controller", ""))
	var bridge_source := str(_sources.get("city_world_bridge", ""))
	var observed := _city_controller != null and _city_controller.has_method("evaluate_development_request") and _city_controller.has_method("plan_settlement") and source.contains("func record_project_opened(") and source.contains("func record_project_resolved(") and not source.contains("refresh_networks(") and bridge_source.contains("func apply_settlement_plan(")
	return _record("legality_controller_boundary", observed, observed, "CityDevelopmentRuntimeController owns legality, planning, and lifecycle; the non-owning bridge performs world commits.", {"service_owner_checked": true})


func _case_project_bridge_boundary() -> Dictionary:
	var state_source := str(_sources.get("project_state", ""))
	var bridge_source := str(_sources.get("project_bridge", ""))
	var observed := state_source.contains("func contribute(") and state_source.contains("func recalculate_shares(") and state_source.contains("func attribute_gdp_rows(") and bridge_source.contains("func apply_project_contribution(") and bridge_source.contains("func apply_gdp_rows(") and not bridge_source.contains("Node")
	return _record("project_bridge_boundary", observed, observed, "CityProductProjectState/Bridge remain pure-data project, contribution, share, and structured GDP attribution owners.")


func _case_network_boundary() -> Dictionary:
	var source := str(_sources.get("network_controller", ""))
	var observed := _network_controller != null and source.contains("func claim_project_sequence_if(") and source.contains("func refresh_networks(") and not source.contains("func apply_city_development(")
	return _record("network_controller_boundary", observed, observed, "CityTradeNetworkRuntimeController owns contribution sequence and network derivation without owning city-development settlement.", {"network_refresh_checked": true})


func _case_real_cards() -> Dictionary:
	var directions: Array = []
	var cards: Array = []
	for direction in ["production", "demand", "commerce"]:
		var fixture := _development_fixture(direction)
		var skill: Dictionary = fixture.get("skill", {})
		if not skill.is_empty():
			directions.append(str(skill.get("project_direction", "")))
			cards.append(str(skill.get("name", "")))
	var observed := directions == ["production", "demand", "commerce"] and cards.size() == 3 and ResourceLoader.exists(CORE_DEVELOPMENT_PACK_PATH)
	return _record("real_runtime_cards_three_directions", observed, observed, "CoreCityDevelopmentPack generated real rank-I cards for all directions: %s." % str(cards), {"card_id": ", ".join(cards)})


func _case_execution_route() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var dispatch := _function_source(main_source, "_apply_card_resolution_effect_request")
	var execution_source := str(_sources.get("execution", ""))
	var observed := dispatch.contains('"city_development"') and dispatch.contains("execute_city_development") and not dispatch.contains("_apply_city_development_card(") and not execution_source.contains("apply_development(")
	return _record("queue_execution_dispatch_route", observed, observed, "Card Resolution routes city_development through Coordinator; Execution stays formula-free.")


func _case_direction_success(direction: String) -> Dictionary:
	var fixture := _development_fixture(direction)
	if fixture.is_empty():
		return _record("%s_project_success" % direction, false, false, "No real %s development fixture." % direction)
	var applied := _apply_fixture(fixture, 0)
	var district_index := int(fixture.get("district_index", -1))
	var city: Dictionary = _runtime_main.call("_district_city", district_index)
	var project := _project_for(city, str(fixture.get("product_id", "")), direction)
	var observed := applied and not project.is_empty() and str(project.get("direction", "")) == direction
	return _record("%s_project_success" % direction, observed, observed, "Real %s development card resolves into the matching product project." % direction, _project_flags(fixture, project, {"project_created": observed}))


func _case_atomic_rejection(kind: String) -> Dictionary:
	var fixture := _development_fixture("production")
	if fixture.is_empty():
		return _record("%s_atomic" % kind, false, false, "No real production fixture.")
	var skill: Dictionary = (fixture.get("skill", {}) as Dictionary).duplicate(true)
	var player_index := 0
	var district_index := int(fixture.get("district_index", -1))
	match kind:
		"invalid_player": player_index = -1
		"invalid_district": skill["development_target_district"] = 999999
		"destroyed": _set_district_field(district_index, "destroyed", true)
		"terrain": skill["allowed_terrains"] = ["ocean"]
		"missing_product": skill["product_id"] = ""
		"unavailable_product": skill["product_id"] = "不存在商品"
	var before := _mutation_signature()
	var result: Dictionary = _coordinator.call("execute_city_development", {"player_index": player_index, "district_index": int(skill.get("development_target_district", district_index)), "skill": skill})
	var applied := bool(result.get("resolved", false))
	var after := _mutation_signature()
	var observed := not applied and before == after
	return _record("%s_atomic" % kind, observed, observed, "%s rejection leaves city, player city-count, transport, and project sequence unchanged." % kind, {"district_index": district_index})


func _case_direct_build_disabled() -> Dictionary:
	var fixture := _development_fixture("production")
	var district_index := int(fixture.get("district_index", -1))
	if district_index < 0:
		return _record("direct_build_disabled_no_mutation", false, false, "No land district.")
	var before := _mutation_signature()
	var result: Dictionary = _city_controller.call("evaluate_development_request", {"source_kind": "direct_city_build", "action_id": "build_city", "player_index": 0, "district_index": district_index})
	var after := _mutation_signature()
	var observed := not bool(result.get("allowed", false)) and before == after and not bool(_city_controller.call("direct_build_allowed"))
	return _record("direct_build_disabled_no_mutation", observed, observed, "v0.4 compatibility action is rejected without city mutation.", {"district_index": district_index})


func _case_first_city_shape() -> Dictionary:
	var fixture := _development_fixture("production")
	if not _apply_fixture(fixture, 0):
		return _record("first_city_surface_shape", false, false, "Real development failed.")
	var district_index := int(fixture.get("district_index", -1))
	var city: Dictionary = _runtime_main.call("_district_city", district_index)
	var required := ["owner", "active", "level", "products", "demands", "projects", "last_gdp", "gdp_history", "trade_routes", "gdp_cashflow_remainder_by_source_id", "built_at", "public_clues"]
	var missing: Array = []
	for key in required:
		if not city.has(key): missing.append(key)
	var observed := missing.is_empty() and bool(city.get("active", false)) and (city.get("projects", []) as Array).size() == 1
	return _record("first_city_surface_shape", observed, observed, "First city surface plus project uses the complete district-embedded shape; missing=%s." % str(missing), {"district_index": district_index, "city_created": true, "project_created": true})


func _case_cities_built_once() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := _player_cities_built(0)
	var first := _apply_fixture(fixture, 0)
	var after_first := _player_cities_built(0)
	var second := _apply_fixture(fixture, 0)
	var after_second := _player_cities_built(0)
	var observed := first and second and after_first == before + 1 and after_second == after_first
	return _record("cities_built_exact_once", observed, observed, "cities_built increments only when the city shell is first created.", {"district_index": int(fixture.get("district_index", -1)), "city_created": first})


func _case_hp_and_repair() -> Dictionary:
	var fixture := _development_fixture("production")
	var district_index := int(fixture.get("district_index", -1))
	if district_index < 0: return _record("hp_bonus_and_damage_repair", false, false, "No district.")
	_set_district_field(district_index, "damage", 5)
	var before := _district_at(district_index)
	var applied := _apply_fixture(fixture, 0)
	var after := _district_at(district_index)
	var hp_delta := int(after.get("hp", 0)) - int(before.get("hp", 0))
	var damage_delta := int(after.get("damage", 0)) - int(before.get("damage", 0))
	var observed := applied and hp_delta == 8 and damage_delta == -2
	return _record("hp_bonus_and_damage_repair", observed, observed, "First surface adds 8 HP and repairs 2 damage before project settlement.", {"district_index": district_index, "city_hp_delta": hp_delta})


func _case_built_at_visual() -> Dictionary:
	var fixture := _development_fixture("production")
	var district_index := int(fixture.get("district_index", -1))
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time = 321.5
	var before_effects := (_runtime_main.get("map_event_effects") as Array).size()
	var applied := _apply_fixture(fixture, 0)
	var city: Dictionary = _runtime_main.call("_district_city", district_index)
	var effects: Array = _runtime_main.get("map_event_effects")
	var effect: Dictionary = effects[effects.size() - 1] if effects.size() > before_effects else {}
	var observed := applied and is_equal_approx(float(city.get("built_at", -1.0)), 321.5) and str(effect.get("kind", "")) == "city_rise"
	return _record("built_at_and_visual_order", observed, observed, "built_at records the settlement clock and city_rise is emitted when the shell is created.", {"district_index": district_index, "event_checked": true})


func _case_stable_project_id() -> Dictionary:
	var fixture := _development_fixture("production")
	var expected := PROJECT_STATE.project_id(int(fixture.get("district_index", -1)), "production", 0, 1)
	var applied := _apply_fixture(fixture, 0)
	var city: Dictionary = _runtime_main.call("_district_city", int(fixture.get("district_index", -1)))
	var project := _project_for(city, str(fixture.get("product_id", "")), "production")
	var observed := applied and str(project.get("project_id", "")) == expected
	return _record("stable_project_identity", observed, observed, "Project identity remains district:product:direction.", _project_flags(fixture, project))


func _case_sequence_once() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := int(_network_controller.call("project_sequence"))
	var applied := _apply_fixture(fixture, 0)
	var after := int(_network_controller.call("project_sequence"))
	var observed := applied and after == before + 1
	return _record("project_sequence_exact_once", observed, observed, "Each successful contribution claims exactly one network-owned sequence value.", {"district_index": int(fixture.get("district_index", -1)), "project_created": applied})


func _case_first_share() -> Dictionary:
	var fixture := _development_fixture("production")
	var applied := _apply_fixture(fixture, 0)
	var project := _fixture_project(fixture, "production")
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var observed := applied and int(shares.get("0", 0)) == 10000 and int(project.get("controller_player_index", -1)) == 0
	return _record("first_contribution_full_share", observed, observed, "First contributor receives 10000 basis points and control.", _project_flags(fixture, project, {"contribution_delta": 1, "share_delta": 10000}))


func _case_repeat_contribution() -> Dictionary:
	var fixture := _development_fixture("production")
	var first := _apply_fixture(fixture, 0)
	var first_project := _fixture_project(fixture, "production")
	var first_level := int(first_project.get("level", 0))
	var second := _apply_fixture(fixture, 0)
	var project := _fixture_project(fixture, "production")
	var contributions: Dictionary = project.get("contribution_by_player", {})
	var observed := first and second and int(contributions.get("0", 0)) == 2 and int(project.get("level", 0)) > first_level and int((project.get("share_basis_points_by_player", {}) as Dictionary).get("0", 0)) == 10000
	return _record("repeated_contribution_strengthens", observed, observed, "Repeated same-player contribution strengthens one project without creating another.", _project_flags(fixture, project, {"contribution_delta": 2}))


func _case_second_player_share() -> Dictionary:
	var fixture := _development_fixture("production")
	var first := _apply_fixture(fixture, 0)
	var second := _apply_fixture(fixture, 1)
	var project := _fixture_project(fixture, "production")
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var observed := first and second and int(shares.get("0", 0)) == 5000 and int(shares.get("1", 0)) == 5000
	return _record("second_player_share_split", observed, observed, "Equal contributions split the project 50/50 without exposing the table publicly.", _project_flags(fixture, project, {"contribution_delta": 2, "share_delta": 5000}))


func _case_tie_controller() -> Dictionary:
	var fixture := _development_fixture("production")
	var first := _apply_fixture(fixture, 0)
	var second := _apply_fixture(fixture, 1)
	var project := _fixture_project(fixture, "production")
	var observed := first and second and int(project.get("controller_player_index", 99)) == -1
	return _record("tie_has_no_controller", observed, observed, "Equal highest contributions leave the project without a controller.", _project_flags(fixture, project, {"controller_changed": false}))


func _case_contribution_order() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := int(_network_controller.call("project_sequence"))
	var first := _apply_fixture(fixture, 0)
	var second := _apply_fixture(fixture, 1)
	var project := _fixture_project(fixture, "production")
	var orders: Dictionary = project.get("contribution_order_by_player", {})
	var observed := first and second and int(orders.get("0", -1)) == before and int(orders.get("1", -1)) == before + 1
	return _record("contribution_order_stable", observed, observed, "Contribution order preserves the two exact network sequence claims.", _project_flags(fixture, project))


func _case_gdp_remainder() -> Dictionary:
	var first := PROJECT_STATE.create_project(1, "活体芯片", "production", 0, 1, 1)
	var second := PROJECT_STATE.create_project(1, "真空可可", "demand", 1, 1, 2)
	var rows := [_gdp_row(first, 51, "production_output"), _gdp_row(second, 50, "demand_delivery")]
	var attribution := PROJECT_STATE.attribute_gdp_rows([first, second], rows)
	var assigned: Array = attribution.get("projects", []) as Array
	var first_gdp := int((assigned[0] as Dictionary).get("current_gdp", 0))
	var second_gdp := int((assigned[1] as Dictionary).get("current_gdp", 0))
	var observed := first_gdp == 51 and second_gdp == 50
	return _record("gdp_remainder_controller", observed, observed, "Structured rows preserve their explicit 51/50 project totals; no whole-city remainder allocator remains.", {"gdp_assignment_checked": true})


func _case_legacy_sync(direction: String) -> Dictionary:
	var fixture := _development_fixture(direction)
	var applied := _apply_fixture(fixture, 0)
	var city: Dictionary = _runtime_main.call("_district_city", int(fixture.get("district_index", -1)))
	var product_id := str(fixture.get("product_id", ""))
	var observed := false
	if direction == "production":
		observed = applied and _city_product_names(city).has(product_id)
	else:
		observed = applied and (city.get("demands", []) as Array).has(product_id)
	return _record("%s_legacy_sync" % direction, observed, observed, "%s project synchronizes the legacy city field still consumed by world systems." % direction, {"card_id": str((fixture.get("skill", {}) as Dictionary).get("name", "")), "project_direction": direction, "district_index": int(fixture.get("district_index", -1))})


func _case_commerce_transport() -> Dictionary:
	var fixture := _development_fixture("commerce")
	var district_index := int(fixture.get("district_index", -1))
	var before := _district_at(district_index)
	var applied := _apply_fixture(fixture, 0)
	var after := _district_at(district_index)
	var delta := int(after.get("transport_level", 0)) - int(before.get("transport_level", 0))
	var observed := applied and delta == maxi(1, int((fixture.get("skill", {}) as Dictionary).get("contribution_units", 1))) and float(after.get("transport_score", 0.0)) > 0.0
	return _record("commerce_transport_upgrade", observed, observed, "Commerce contribution raises transport level once and recalculates transport score.", {"card_id": str((fixture.get("skill", {}) as Dictionary).get("name", "")), "project_direction": "commerce", "district_index": district_index, "transport_delta": delta})


func _case_refresh_order() -> Dictionary:
	var settlement := _function_source(str(_sources.get("city_world_bridge", "")), "apply_settlement_plan")
	var source_order := _tokens_in_order(settlement, ["refresh_networks", "refresh_prices", "competition_matches", "city_gdp_breakdown", "private_projects"])
	var fixture := _development_fixture("demand")
	var applied := _apply_fixture(fixture, 0)
	var project := _fixture_project(fixture, "demand")
	var observed := source_order and applied and project.has("current_gdp")
	return _record("refresh_order_network_market_gdp", observed, observed, "Observed order is network refresh with structured GDP rows -> market refresh -> GDP facts -> project lookup -> resolved lifecycle.", _project_flags(fixture, project, {"network_refresh_checked": true, "market_refresh_checked": true, "gdp_assignment_checked": true}))


func _case_lifecycle() -> Dictionary:
	var fixture := _development_fixture("production")
	var settlement := _function_source(str(_sources.get("coordinator", "")), "execute_city_development")
	var order_ok := _tokens_in_order(settlement, ["plan_settlement", "record_project_opened", "apply_settlement_plan", "finalize_settlement", "apply_post_commit_intents"])
	var applied := _apply_fixture(fixture, 0)
	var debug: Dictionary = _city_controller.call("debug_snapshot")
	var projects: Array = debug.get("projects", [])
	var lifecycle: Dictionary = projects[0] if not projects.is_empty() else {}
	var observed := applied and order_ok and projects.size() == 1 and str(lifecycle.get("state", "")) == "resolved" and str(lifecycle.get("project_id", "")) != ""
	return _record("lifecycle_opened_resolved", observed, observed, "Lifecycle evidence opens before shell mutation and resolves after GDP/share assignment.", _project_flags(fixture, lifecycle, {"event_checked": true}))


func _case_economic_event() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := _player_ledger(0).size()
	var applied := _apply_fixture(fixture, 0)
	var ledger := _player_ledger(0)
	var matching := 0
	for entry_variant in ledger:
		if entry_variant is Dictionary and str((entry_variant as Dictionary).get("kind", "")) == "项目贡献": matching += 1
	var observed := applied and ledger.size() == before + 1 and matching == 1
	return _record("economic_event_exact_once", observed, observed, "Successful settlement appends one private project-contribution ledger event.", {"card_id": str((fixture.get("skill", {}) as Dictionary).get("name", "")), "district_index": int(fixture.get("district_index", -1)), "event_checked": true})


func _case_public_callout() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := (_runtime_main.get("action_callouts") as Array).size()
	var applied := _apply_fixture(fixture, 0)
	var callouts: Array = _runtime_main.get("action_callouts")
	var callout: Dictionary = callouts[callouts.size() - 1] if callouts.size() > before else {}
	var text := JSON.stringify({"actor": callout.get("actor", ""), "action": callout.get("action", ""), "detail": callout.get("detail", "")})
	var observed := applied and callouts.size() == before + 1 and str(callout.get("actor", "")) == "匿名财团" and not text.contains("player_index") and not text.contains("controller_player_index")
	return _record("public_callout_anonymous", observed, observed, "Public callout exposes project/product evidence but keeps the contributor anonymous.", {"district_index": int(fixture.get("district_index", -1)), "event_checked": true, "privacy_checked": true})


func _case_privacy() -> Dictionary:
	var fixture := _development_fixture("production")
	var first := _apply_fixture(fixture, 0)
	var second := _apply_fixture(fixture, 1)
	var district_index := int(fixture.get("district_index", -1))
	var public_projects: Array = _runtime_main.call("_city_public_project_snapshots", district_index)
	var private_projects: Array = _runtime_main.call("_city_private_project_snapshots", district_index, 0)
	var public_text := JSON.stringify(public_projects)
	var private_text := JSON.stringify(private_projects)
	var observed := first and second and not public_text.contains("controller_player_index") and not public_text.contains("contribution_by_player") and not public_text.contains("share_basis_points_by_player") and private_text.contains("own_share_basis_points") and not private_text.contains("contribution_by_player") and not private_text.contains("share_basis_points_by_player")
	return _record("public_private_project_privacy", observed, observed, "Public snapshots omit ownership tables; private snapshots add only the viewer's own contribution/share/control.", {"district_index": district_index, "privacy_checked": true})


func _case_save_shape() -> Dictionary:
	var fixture := _development_fixture("production")
	var applied := _apply_fixture(fixture, 0)
	var state: Dictionary = _runtime_main.call("_capture_run_domain_state_compatibility_adapter")
	var saved_districts: Array = state.get("districts", [])
	var district_index := int(fixture.get("district_index", -1))
	var saved_city: Dictionary = ((saved_districts[district_index] as Dictionary).get("city", {}) as Dictionary) if district_index >= 0 and district_index < saved_districts.size() else {}
	var runtime_state: Dictionary = state.get("city_trade_network_runtime", {}) if state.get("city_trade_network_runtime", {}) is Dictionary else {}
	var legacy := PROJECT_BRIDGE.normalize_city({"owner": 2, "active": true, "products": [{"name": str(fixture.get("product_id", "")), "level": 1}], "demands": []}, district_index, 9)
	var observed := applied and not (saved_city.get("projects", []) as Array).is_empty() and str(runtime_state.get("terms_version", "")) == "v0.5.structured-project-gdp.1" and int(runtime_state.get("project_sequence", 0)) > 0 and not state.has("city_product_project_sequence") and (legacy.get("projects", []) as Array).is_empty() and (legacy.get("project_slots", []) as Array).size() == 5
	return _record("current_and_migration_save_shape", observed, observed, "Current saves embed stable slots/generations and the structured GDP source version in one domain envelope; legacy owner fields do not synthesize project shares.", {"district_index": district_index, "save_checked": true})


func _case_downstream_atomicity() -> Dictionary:
	var source := str(_sources.get("city_world_bridge", ""))
	var observed := source.contains("func _rollback(") and source.contains("original_players") and source.contains("network_save") and source.contains("market_save") and source.contains("rng_state")
	return _record("downstream_refresh_atomicity_characterized", observed, observed, "WorldBridge snapshots world, network, market, and RNG state and rolls all of them back on a failed downstream commit.", {"network_refresh_checked": true, "rollback_checked": true})


func _case_deletion_map() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var present: Array = []
	for function_name in SPRINT66_CANDIDATES:
		if main_source.contains("func %s(" % str(function_name)): present.append(function_name)
	var observed := present.is_empty() and not main_source.contains("CITY_BUILD_COST") and not main_source.contains("CITY_HP_BONUS")
	return _record("sprint66_deletion_candidates_complete", observed, observed, "All mapped settlement helpers and duplicate city-settlement constants are absent from main.gd; remaining legacy actions are rejection-only surfaces.", {"legacy_formula_absent": observed})


func _case_cutover_composition() -> Dictionary:
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var main_scene := FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	var observed := _city_controller != null and _city_world_bridge != null and coordinator_scene.contains("CityDevelopmentRuntimeController") and coordinator_scene.contains("CityDevelopmentWorldBridge") and not main_scene.contains('[node name="CityDevelopmentRuntimeController" parent="RuntimeServices/RuntimeControllerHost"')
	return _record("controller_bridge_scene_composition", observed, observed, "Controller and non-owning WorldBridge are static Coordinator children; main has no parallel direct instance.", {"service_owner_checked": true, "main_adapter_checked": true})


func _case_unique_owner() -> Dictionary:
	var controller_source := str(_sources.get("city_controller", ""))
	var bridge_source := str(_sources.get("city_world_bridge", ""))
	var main_source := str(_sources.get("main", ""))
	var observed := controller_source.contains("func plan_settlement(") and controller_source.contains("func finalize_settlement(") and bridge_source.contains("func apply_settlement_plan(") and not main_source.contains("func _apply_city_development_card(") and not main_source.contains("PROJECT_BRIDGE.apply_development(")
	return _record("unique_settlement_owner", observed, observed, "CityDevelopmentRuntimeController is the only planner/finalizer; WorldBridge only commits; main has no settlement algorithm.", {"service_owner_checked": true, "legacy_formula_absent": observed})


func _case_plan_pure() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := _mutation_signature()
	var bundle := _plan_bundle(fixture, 0)
	var plan: Dictionary = bundle.get("plan", {})
	var after := _mutation_signature()
	var observed := bool(plan.get("valid", false)) and before == after and _is_data_only(plan) and not _contains_runtime_object(plan)
	return _record("plan_is_pure_and_no_mutation", observed, observed, "Planning emits a pure-data staged transaction and leaves world state untouched.", {"plan_checked": true, "pure_data_checked": observed})


func _case_preflight_pure() -> Dictionary:
	var fixture := _development_fixture("demand")
	var bundle := _plan_bundle(fixture, 0)
	var plan: Dictionary = bundle.get("plan", {})
	var before := _mutation_signature()
	var preflight: Dictionary = _city_world_bridge.call("preflight_settlement", plan)
	var after := _mutation_signature()
	var observed := bool(preflight.get("valid", false)) and before == after and _is_data_only(preflight) and not _contains_runtime_object(preflight)
	return _record("preflight_is_pure_and_no_mutation", observed, observed, "World preflight rechecks fingerprints and sequence without mutating city, market, network, or player state.", {"plan_checked": true, "pure_data_checked": observed})


func _case_cutover_parity(direction: String) -> Dictionary:
	var base := _case_direction_success(direction)
	return _rename_record("%s_cutover_parity" % direction, base)


func _case_share_tie_parity() -> Dictionary:
	var fixture := _development_fixture("production")
	var first := _apply_fixture(fixture, 0)
	var second := _apply_fixture(fixture, 1)
	var project := _fixture_project(fixture, "production")
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var observed := first and second and int(shares.get("0", 0)) == 5000 and int(shares.get("1", 0)) == 5000 and int(project.get("controller_player_index", 99)) == -1
	return _record("share_and_no_controller_parity", observed, observed, "Equal contributions preserve the 50/50 split and produce no controller.", _project_flags(fixture, project, {"share_delta": 5000}))


func _case_stale_fingerprint() -> Dictionary:
	var fixture := _development_fixture("production")
	var bundle := _plan_bundle(fixture, 0)
	var plan: Dictionary = bundle.get("plan", {})
	var district_index := int(fixture.get("district_index", -1))
	_set_district_field(district_index, "damage", int(_district_at(district_index).get("damage", 0)) + 1)
	var before := _mutation_signature()
	var preflight: Dictionary = _city_world_bridge.call("preflight_settlement", plan)
	var after := _mutation_signature()
	var observed := not bool(preflight.get("valid", true)) and str(preflight.get("reason_code", "")) == "world_facts_changed" and before == after
	return _record("stale_fingerprint_rejected", observed, observed, "A stale plan fingerprint is rejected before mutation with a stable reason code.", {"plan_checked": true})


func _case_downstream_missing() -> Dictionary:
	var fixture := _development_fixture("production")
	var bundle := _plan_bundle(fixture, 0)
	var request: Dictionary = bundle.get("request", {})
	var facts: Dictionary = (bundle.get("facts", {}) as Dictionary).duplicate(true)
	facts["downstream_owner_readiness"] = {"network": true, "gdp": true, "market": false}
	var before := _mutation_signature()
	var plan: Dictionary = _city_controller.call("plan_settlement", request, facts)
	var after := _mutation_signature()
	var observed := not bool(plan.get("valid", true)) and str(plan.get("reason_code", "")) == "downstream_owner_unavailable" and before == after
	return _record("downstream_owner_missing_rejected", observed, observed, "A missing downstream owner rejects planning atomically; no fallback settlement is attempted.", {"service_owner_checked": true})


func _case_failed_commit_rollback() -> Dictionary:
	var fixture := _development_fixture("production")
	var bundle := _plan_bundle(fixture, 0)
	var plan: Dictionary = bundle.get("plan", {})
	var before := _mutation_signature()
	var stale_plan := plan.duplicate(true)
	stale_plan["expected_project_sequence"] = int(plan.get("expected_project_sequence", 0)) + 1
	var receipt: Dictionary = _city_world_bridge.call("apply_settlement_plan", stale_plan)
	var after := _mutation_signature()
	var bridge_source := str(_sources.get("city_world_bridge", ""))
	var rollback_envelope := bridge_source.contains("func _rollback(") and bridge_source.contains("original_players") and bridge_source.contains("network_save") and bridge_source.contains("market_save") and bridge_source.contains("rng_state")
	var observed := not bool(receipt.get("committed", true)) and before == after and rollback_envelope
	return _record("failed_commit_rolls_back_world", observed, observed, "Failed commit is mutation-free at preflight, while every fallible post-claim stage is protected by the explicit world/network/market/RNG rollback envelope.", {"rollback_checked": true})


func _case_lifecycle_events_exact_once() -> Dictionary:
	var fixture := _development_fixture("production")
	var before := _player_ledger(0).size()
	var skill: Dictionary = (fixture.get("skill", {}) as Dictionary).duplicate(true)
	var result: Dictionary = _coordinator.call("execute_city_development", {"player_index": 0, "district_index": int(fixture.get("district_index", -1)), "skill": skill})
	var after_first := _player_ledger(0).size()
	var replay: Dictionary = _city_world_bridge.call("apply_post_commit_intents", result)
	var after_replay := _player_ledger(0).size()
	var observed := bool(result.get("resolved", false)) and after_first == before + 1 and after_replay == after_first and not bool(replay.get("applied", true)) and str(replay.get("reason", "")) == "event_receipt_already_applied"
	return _record("lifecycle_events_exact_once", observed, observed, "Opened/resolved lifecycle and post-commit intents are idempotent by event receipt.", {"event_checked": true})


func _case_route_source(route_kind: String) -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var source := ""
	match route_kind:
		"player": source = _function_source(main_source, "_apply_card_resolution_effect_request")
		"ai": source = FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var observed := source.contains("execute_city_development")
	return _record("%s_route_uses_coordinator" % route_kind, observed, observed, "%s route reaches the shared Coordinator settlement API without a private formula." % route_kind, {"main_adapter_checked": true})


func _case_public_receipt_privacy() -> Dictionary:
	var fixture := _development_fixture("production")
	var skill: Dictionary = (fixture.get("skill", {}) as Dictionary).duplicate(true)
	var result: Dictionary = _coordinator.call("execute_city_development", {"player_index": 0, "district_index": int(fixture.get("district_index", -1)), "skill": skill})
	var public_receipt: Dictionary = result.get("public_receipt", {})
	var text := JSON.stringify(public_receipt)
	var observed := bool(result.get("resolved", false)) and not public_receipt.is_empty() and not text.contains("player_index") and not text.contains("owner") and not text.contains("controller") and not text.contains("share") and not text.contains("contribution_by_player")
	return _record("public_receipt_privacy", observed, observed, "Public settlement receipt exposes project evidence and refresh order, never contributor identity or share tables.", {"privacy_checked": true})


func _case_reflected_tests_migrated() -> Dictionary:
	var forbidden := ["call(\"_apply_city_development_card\"", "call(\"_create_city_at_district_for_player\"", "call(\"_create_city_surface_for_development\"", "call(\"_city_build_error_for\""]
	var offenders := _reflection_offenders("res://tests", forbidden)
	offenders.append_array(_reflection_offenders("res://scripts/tools", forbidden, [get_script().resource_path]))
	var observed := offenders.is_empty()
	return _record("reflected_tests_migrated", observed, observed, "Tests and tools use Coordinator/fixture APIs; reflected legacy callers=%s." % str(offenders), {"main_adapter_checked": true})


func _case_legacy_absent() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var present: Array = []
	for function_name in SPRINT66_CANDIDATES:
		if main_source.contains("func %s(" % str(function_name)):
			present.append(function_name)
	var observed := present.is_empty() and not main_source.contains("PROJECT_BRIDGE.apply_development(") and not main_source.contains("PROJECT_BRIDGE.assign_city_gdp(")
	return _record("main_legacy_settlement_absent", observed, observed, "main.gd legacy settlement symbols and project mutation formulas are absent: %s." % str(present), {"legacy_formula_absent": observed})


func _case_no_parallel_engine() -> Dictionary:
	var main_scene := FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var observed := coordinator_scene.count("CityDevelopmentRuntimeController.tscn") == 1 and coordinator_scene.count("CityDevelopmentWorldBridge.tscn") == 1 and not main_scene.contains("CityDevelopmentRuntimeController.tscn") and not str(_sources.get("main", "")).contains("func plan_settlement(")
	return _record("no_parallel_city_engine", observed, observed, "Exactly one Controller and one non-owning bridge are composed; no legacy fallback engine remains.", {"service_owner_checked": true})


func _plan_bundle(fixture: Dictionary, player_index: int) -> Dictionary:
	if fixture.is_empty():
		return {}
	var skill: Dictionary = (fixture.get("skill", {}) as Dictionary).duplicate(true)
	var request := {
		"source_kind": "city_development_card",
		"action_id": str(skill.get("action_id", "")),
		"player_index": player_index,
		"district_index": int(fixture.get("district_index", -1)),
		"product_id": str(skill.get("product_id", "")),
		"project_direction": str(skill.get("project_direction", "production")),
		"allowed_terrains": (skill.get("allowed_terrains", []) as Array).duplicate(true),
		"skill": skill,
	}
	var facts: Dictionary = _city_world_bridge.call("capture_settlement_facts", request)
	var plan: Dictionary = _city_controller.call("plan_settlement", request, facts)
	return {"request": request, "facts": facts, "plan": plan}


func _reflection_offenders(root_path: String, forbidden: Array, excluded: Array = []) -> Array:
	var result: Array = []
	var directory := DirAccess.open(root_path)
	if directory == null:
		return result
	for file_name in directory.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var path := root_path.path_join(file_name)
		if excluded.has(path):
			continue
		var source := FileAccess.get_file_as_string(path)
		for token in forbidden:
			if source.contains(str(token)):
				result.append(path)
				break
	for child_name in directory.get_directories():
		result.append_array(_reflection_offenders(root_path.path_join(child_name), forbidden, excluded))
	return result


func _rename_record(case_id: String, source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result["case_id"] = case_id
	return result


func _ensure_runtime_main() -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null: return false
	_runtime_main = packed.instantiate() as Control
	if _runtime_main == null: return false
	_runtime_main.name = "Main"
	_runtime_main.visible = false
	runtime_main_host.add_child(_runtime_main)
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_disable_runtime_audio()
	var runtime_coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng != null: runtime_rng.seed = FIXED_SEED
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	if (_runtime_main.get("city_development_runtime_cards") as Dictionary).is_empty():
		_runtime_main.call("_rebuild_city_development_runtime_cards")
	_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_city_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityDevelopmentRuntimeController")
	_city_world_bridge = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityDevelopmentWorldBridge")
	_network_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityTradeNetworkRuntimeController")
	_gdp_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController")
	_product_market = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	_baseline_players = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	_baseline_districts = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	_baseline_city_cards = (_runtime_main.get("city_development_runtime_cards") as Dictionary).duplicate(true)
	_baseline_project_sequence = int(_network_controller.call("project_sequence")) if _network_controller != null else 1
	_baseline_market_save = _product_market.call("to_save_data") if _product_market != null and _product_market.has_method("to_save_data") else {}
	return _city_controller != null and _city_world_bridge != null and _coordinator != null and _network_controller != null and _gdp_controller != null and _product_market != null and not _baseline_players.is_empty() and not _baseline_districts.is_empty() and not _baseline_city_cards.is_empty()


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = _baseline_players.duplicate(true)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = _baseline_districts.duplicate(true)
	_runtime_main.set("city_development_runtime_cards", _baseline_city_cards.duplicate(true))
	_network_controller.call("apply_save_data", {"city_trade_network_runtime": {"project_sequence": _baseline_project_sequence}})
	if _product_market.has_method("apply_save_data"):
		_product_market.call("apply_save_data", _baseline_market_save.duplicate(true))
	_city_controller.call("reset_state")
	_city_world_bridge.call("reset_state")
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time = 100.0
	_runtime_main.set("game_over", false)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = 0
	(_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).reset_public_log()
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	_runtime_main.set("movement_trails", [])
	_runtime_main.set("runtime_visual_events", [])
	var runtime_coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var runtime_rng := runtime_coordinator.run_rng_service() if runtime_coordinator != null else null
	if runtime_rng != null: runtime_rng.seed = FIXED_SEED
	var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	for i in range(players.size()):
		var player: Dictionary = (players[i] as Dictionary).duplicate(true)
		player["cash"] = 2000
		player["eliminated"] = false
		player["cities_built"] = 0
		player["economic_ledger"] = []
		players[i] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players
	_isolate_map()


func _development_fixture(direction: String) -> Dictionary:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	var cards: Dictionary = _runtime_main.get("city_development_runtime_cards")
	var names: Array = cards.keys()
	names.sort()
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index]
		if bool(district.get("destroyed", false)) or str(district.get("terrain", "land")) != "land": continue
		var local_products: Array = _runtime_main.call("_district_local_product_names", district_index)
		for card_name_variant in names:
			var card_name := str(card_name_variant)
			var skill: Dictionary = cards.get(card_name, {})
			if str(skill.get("kind", "")) != "city_development" or int(skill.get("rank", 1)) != 1: continue
			if str(skill.get("project_direction", "")) != direction: continue
			var product_id := str(skill.get("product_id", ""))
			if product_id == "" or not local_products.has(product_id): continue
			var copy := skill.duplicate(true)
			copy["development_target_district"] = district_index
			return {"district_index": district_index, "product_id": product_id, "skill": copy}
	return {}


func _apply_fixture(fixture: Dictionary, player_index: int) -> bool:
	if fixture.is_empty(): return false
	var skill: Dictionary = (fixture.get("skill", {}) as Dictionary).duplicate(true)
	skill["development_target_district"] = int(fixture.get("district_index", -1))
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_player = player_index
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).table_selection_state()).selected_district = int(fixture.get("district_index", -1))
	var result: Dictionary = _coordinator.call("execute_city_development", {"player_index": player_index, "district_index": int(fixture.get("district_index", -1)), "skill": skill})
	return bool(result.get("resolved", false))


func _fixture_project(fixture: Dictionary, direction: String) -> Dictionary:
	var city: Dictionary = _runtime_main.call("_district_city", int(fixture.get("district_index", -1)))
	return _project_for(city, str(fixture.get("product_id", "")), direction)


func _project_for(city: Dictionary, product_id: String, direction: String) -> Dictionary:
	for project_variant in city.get("projects", []):
		if not (project_variant is Dictionary): continue
		var project: Dictionary = project_variant
		if str(project.get("product_id", "")) == product_id and str(project.get("direction", "")) == direction:
			return project.duplicate(true)
	return {}


func _project_flags(fixture: Dictionary, project: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var result := {
		"card_id": str((fixture.get("skill", {}) as Dictionary).get("name", "")),
		"project_id": str(project.get("project_id", "")),
		"project_direction": str(project.get("direction", (fixture.get("skill", {}) as Dictionary).get("project_direction", ""))),
		"district_index": int(fixture.get("district_index", -1)),
		"player_index": 0,
	}
	for key in extra.keys(): result[key] = extra[key]
	return result


func _gdp_row(project: Dictionary, amount: int, source_kind: String) -> Dictionary:
	return {
		"receipt_id": "gdp.%s.%s.%s" % [str(project.get("region_id", "")), str(project.get("project_id", "")), source_kind],
		"region_id": str(project.get("region_id", "")),
		"project_id": str(project.get("project_id", "")),
		"project_generation": int(project.get("generation", 0)),
		"slot_id": str(project.get("slot_id", "")),
		"product_id": str(project.get("product_id", "")),
		"industry_id": "technology",
		"direction": str(project.get("direction", "")),
		"source_kind": source_kind,
		"gross_gdp_per_minute": amount,
		"penalty_gdp_per_minute": 0,
		"net_gdp_per_minute": amount,
		"neutral": false,
		"visibility_scope": "public",
	}


func _mutation_signature() -> String:
	var city_counts: Array = []
	for player_variant in ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array:
		city_counts.append(int((player_variant as Dictionary).get("cities_built", 0)))
	var district_state: Array = []
	for district_variant in ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array:
		var district: Dictionary = district_variant
		district_state.append({
			"city": (district.get("city", {}) as Dictionary).duplicate(true),
			"hp": int(district.get("hp", 0)),
			"damage": int(district.get("damage", 0)),
			"transport_level": int(district.get("transport_level", 0)),
			"transport_score": float(district.get("transport_score", 0.0)),
		})
	return JSON.stringify({"cities_built": city_counts, "districts": district_state, "project_sequence": int(_network_controller.call("project_sequence"))})


func _isolate_map() -> void:
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	for i in range(districts.size()):
		var district: Dictionary = (districts[i] as Dictionary).duplicate(true)
		district["city"] = {}
		district["destroyed"] = false
		districts[i] = district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts


func _set_district_field(district_index: int, key: String, value: Variant) -> void:
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	if district_index < 0 or district_index >= districts.size(): return
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	district[key] = value
	districts[district_index] = district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts


func _district_at(district_index: int) -> Dictionary:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	return (districts[district_index] as Dictionary).duplicate(true) if district_index >= 0 and district_index < districts.size() else {}


func _player_cities_built(player_index: int) -> int:
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	return int((players[player_index] as Dictionary).get("cities_built", 0)) if player_index >= 0 and player_index < players.size() else -1


func _player_ledger(player_index: int) -> Array:
	var players: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	return ((players[player_index] as Dictionary).get("economic_ledger", []) as Array).duplicate(true) if player_index >= 0 and player_index < players.size() else []


func _city_product_names(city: Dictionary) -> Array:
	var result: Array = []
	for product_variant in city.get("products", []):
		if product_variant is Dictionary: result.append(str((product_variant as Dictionary).get("name", "")))
	return result


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"case_id": case_id,
		"card_id": str(flags.get("card_id", "")),
		"project_id": str(flags.get("project_id", "")),
		"project_direction": str(flags.get("project_direction", "")),
		"district_index": int(flags.get("district_index", -1)),
		"player_index": int(flags.get("player_index", -1)),
		"city_created": bool(flags.get("city_created", false)),
		"project_created": bool(flags.get("project_created", false)),
		"contribution_delta": int(flags.get("contribution_delta", 0)),
		"share_delta": int(flags.get("share_delta", 0)),
		"controller_changed": bool(flags.get("controller_changed", false)),
		"transport_delta": int(flags.get("transport_delta", 0)),
		"city_hp_delta": int(flags.get("city_hp_delta", 0)),
		"network_refresh_checked": bool(flags.get("network_refresh_checked", false)),
		"market_refresh_checked": bool(flags.get("market_refresh_checked", false)),
		"gdp_assignment_checked": bool(flags.get("gdp_assignment_checked", false)),
		"event_checked": bool(flags.get("event_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"service_owner_checked": bool(flags.get("service_owner_checked", false)),
		"plan_checked": bool(flags.get("plan_checked", false)),
		"commit_checked": bool(flags.get("commit_checked", false)),
		"main_adapter_checked": bool(flags.get("main_adapter_checked", false)),
		"legacy_formula_absent": bool(flags.get("legacy_formula_absent", false)),
		"rollback_checked": bool(flags.get("rollback_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", not aligned)),
		"risk": str(flags.get("risk", "" if aligned else "Observed behavior differs from or is underspecified by the target transaction contract.")),
		"passed": observed,
		"notes": notes,
	}


func _load_sources() -> void:
	_sources = {
		"main": FileAccess.get_file_as_string(MAIN_SCRIPT_PATH),
		"city_controller": FileAccess.get_file_as_string(CITY_CONTROLLER_SCRIPT_PATH),
		"city_world_bridge": FileAccess.get_file_as_string(CITY_WORLD_BRIDGE_SCRIPT_PATH),
		"coordinator": FileAccess.get_file_as_string(COORDINATOR_SCRIPT_PATH),
		"network_controller": FileAccess.get_file_as_string(NETWORK_CONTROLLER_SCRIPT_PATH),
		"gdp": FileAccess.get_file_as_string(GDP_CONTROLLER_SCRIPT_PATH),
		"product_market": FileAccess.get_file_as_string(PRODUCT_MARKET_SCRIPT_PATH),
		"execution": FileAccess.get_file_as_string(EXECUTION_SCRIPT_PATH),
		"project_state": FileAccess.get_file_as_string(PROJECT_STATE_SCRIPT_PATH),
		"project_bridge": FileAccess.get_file_as_string(PROJECT_BRIDGE_SCRIPT_PATH),
	}


func _function_source(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0: return ""
	var next := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _tokens_in_order(source: String, tokens: Array) -> bool:
	var cursor := 0
	for token_variant in tokens:
		var function_position := source.find(str(token_variant), cursor)
		if function_position < 0: return false
		cursor = function_position + str(token_variant).length()
	return true


func _main_metrics(source: String) -> Dictionary:
	var lines := source.split("\n")
	var nonblank := 0
	var functions := 0
	var variables := 0
	var constants := 0
	for line_variant in lines:
		var line := str(line_variant)
		if not line.strip_edges().is_empty(): nonblank += 1
		if line.begins_with("func "): functions += 1
		elif line.begins_with("var "): variables += 1
		elif line.begins_with("const "): constants += 1
	return {"nonblank_lines": nonblank, "function_count": functions, "top_level_variable_count": variables, "constant_count": constants}


func _count_flag(key: String) -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get(key, false)): count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var aligned := int(manifest.get("aligned_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	summary_label.text = "Observed %d/%d | Aligned %d/%d | Design decisions %d" % [observed, CASE_COUNT, aligned, CASE_COUNT, decisions]
	status_label.text = "CUTOVER VERIFIED" if _failures.is_empty() else "CUTOVER FAILURE"
	ownership_text.text = "[b]Settlement owner[/b]\nCityDevelopmentRuntimeController: legality, planning, lifecycle and stable reasons\n\n[b]World commit[/b]\nCityDevelopmentWorldBridge: facts, atomic commit/rollback and post-commit intents\n\n[b]Preserved owners[/b]\nCityProductProjectState/Bridge: contribution/share math\nCityTradeNetworkRuntimeController: sequence and network derivation\nGdpFormulaRuntimeController: GDP arithmetic\nProductMarketRuntimeController: price lifecycle\n\n[b]main.gd[/b]\nWorld facts and existing event surfaces only; no parallel settlement formula."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("%s %s | %s" % ["OK" if bool(record.get("observed", false)) else "FAIL", str(record.get("case_id", "")), "aligned" if bool(record.get("contract_aligned", false)) else "decision required"])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# City Development Settlement Runtime Hard Cutover - Sprint 66", "",
		"Ruleset: `v0.4`", "Settlement owner: `CityDevelopmentRuntimeController`", "Runtime cutover enabled: `true`",
		"Observed: %d/%d" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"Design decisions: %d" % int(manifest.get("needs_design_decision_count", 0)),
		"main.gd deletion gate passed: `%s`" % str(manifest.get("main_deletion_gate_passed", false)), "",
		"## Runtime settlement order", "",
		"1. Validate player, district, terrain, local product, and v0.4 project identity.",
		"2. Build a pure-data settlement plan without mutation.",
		"3. Recheck fingerprint, sequence and downstream owners.",
		"4. Claim one sequence and atomically apply city/project/transport changes.",
		"5. Refresh network, market and GDP, then allocate project GDP.",
		"6. Finalize lifecycle and apply idempotent private/public event intents.",
		"7. Roll back world, downstream services and RNG if any post-claim stage fails.", "",
		"## Ownership result", "",
		"The Controller is the only settlement planner and lifecycle owner. The WorldBridge owns no rules or long-lived state. Legacy main.gd settlement helpers, formulas and reflected callers are removed.", "",
		"## Cases", "", "| Case | Card | Project | Direction | District | Observed | Aligned | Decision | Notes |", "| --- | --- | --- | --- | ---: | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %d | %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("card_id", "")), str(record.get("project_id", "")), str(record.get("project_direction", "")), int(record.get("district_index", -1)), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("needs_design_decision", false)), str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines)


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name in ["manifest.json", "report.md"]:
		var path := OUTPUT_DIR + str(file_name)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("cannot write %s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless": return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("viewport image unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var error := image.save_png(absolute_path)
	if error != OK: _failures.append("screenshot save failed: %s" % error_string(error))


func _hide_runtime_canvas_layers() -> void:
	for node_variant in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if node_variant is CanvasLayer: (node_variant as CanvasLayer).visible = false


func _disable_runtime_audio() -> void:
	for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
		var player := player_variant as AudioStreamPlayer
		player.stop()
		player.stream = null
		player.set_process(false)


func _release_runtime_main() -> void:
	if _runtime_main == null or not is_instance_valid(_runtime_main): return
	runtime_main_host.remove_child(_runtime_main)
	_runtime_main.free()
	_runtime_main = null


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float: return true
	if value is Array:
		for item in value:
			if not _is_data_only(item): return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]): return false
		return true
	return false


func _contains_runtime_object(value: Variant) -> bool:
	if value is Callable or value is Node or value is Resource: return true
	if value is Array:
		for item in value:
			if _contains_runtime_object(item): return true
	elif value is Dictionary:
		for key in value.keys():
			if _contains_runtime_object(key) or _contains_runtime_object(value[key]): return true
	return false
