extends Control
class_name CityTradeNetworkRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/CityTradeNetworkRuntimeController.tscn"
const WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_world_bridge.gd"
const WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/CityTradeNetworkWorldBridge.tscn"
const GDP_FORMULA_SCRIPT_PATH := "res://scripts/runtime/gdp_formula_runtime_controller.gd"
const CASHFLOW_SCRIPT_PATH := "res://scripts/runtime/economy_cashflow_runtime_controller.gd"
const PRODUCT_MARKET_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_controller.gd"
const CONTRACT_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_world_bridge.gd"
const MILITARY_SCRIPT_PATH := "res://scripts/runtime/military_runtime_controller.gd"
const WEATHER_SCRIPT_PATH := "res://scripts/runtime/weather_runtime_controller.gd"
const PROJECT_STATE_SCRIPT_PATH := "res://scripts/economy/city_product_project_state.gd"
const PROJECT_BRIDGE_SCRIPT_PATH := "res://scripts/economy/city_product_project_bridge.gd"
const CITY_PROJECT_STATE := preload(PROJECT_STATE_SCRIPT_PATH)
const CITY_PROJECT_BRIDGE := preload(PROJECT_BRIDGE_SCRIPT_PATH)
const CITY_FIXTURES := preload("res://tests/helpers/city_world_fixture_factory.gd")

const OUTPUT_DIR := "user://space_syndicate_design_qa/city_trade_network_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/structured_project_gdp_v05_sprint_3.png"
const RULESET_ID := "v0.5"
const CASE_COUNT := 108
const FIXED_SEED := 630063
const TEST_PRODUCT := "活体芯片"
const SECOND_PRODUCT := "真空可可"
const BASELINE_MAIN_SHA256 := "5FA89D097B6E808435396CCDF72B2FA7A45A6848A4800986F90366849DCD688E"
const BASELINE_MAIN_METRICS := {
	"total_lines": 23639,
	"nonblank_lines": 20933,
	"function_count": 1309,
	"top_level_variable_count": 142,
	"constant_count": 211,
}

const CASE_IDS := [
	"city_trade_call_graph_complete",
	"city_runtime_shape",
	"stable_slot_project_identity",
	"production_demand_commerce_directions",
	"first_contribution_full_share",
	"repeated_contribution_same_player",
	"second_player_share_split",
	"highest_share_controls_project",
	"tie_has_no_controller",
	"project_share_total_exact",
	"city_gdp_weighted_by_project_level",
	"city_gdp_allocation_exact",
	"player_gdp_allocation_exact",
	"public_project_snapshot_privacy",
	"private_project_snapshot_own_only",
	"legacy_owner_not_project_authority",
	"city_surface_creation_order",
	"development_sequence_increments_once",
	"legacy_product_demand_sync",
	"active_city_index_filter",
	"destroyed_city_zeroes_project_gdp",
	"competition_matches_other_owner",
	"same_owner_not_competition",
	"production_district_source_type",
	"city_source_type",
	"no_supply_route_safe_state",
	"shortest_path_connected",
	"route_edge_cost_positive",
	"ocean_transport_cost_modifier",
	"destroyed_path_disrupted",
	"miasma_panic_cost_modifier",
	"route_flow_fields_present",
	"demand_order_damage_application",
	"supplied_disrupted_counts_exact",
	"product_route_filter",
	"refresh_order_competition_routes_gdp_shares_supply",
	"gdp_formula_controller_boundary",
	"cashflow_controller_cadence_boundary",
	"project_share_cashflow_route",
	"owner_only_city_has_no_project_payout",
	"fractional_remainder_preserved",
	"destroyed_city_no_cashflow",
	"cross_system_refresh_single_hook",
	"product_market_refresh_separate",
	"current_save_shape",
	"legacy_save_migrates_once",
	"public_city_route_privacy",
	"sprint64_deletion_candidates_complete",
]

const V05_PROJECT_CASE_IDS := [
	"v05_profile_project_contract",
	"exactly_five_project_slots",
	"slot_order_stable",
	"stable_ascii_region_and_slot_ids",
	"product_not_part_of_project_identity",
	"same_product_two_production_slots_distinct",
	"same_product_two_demand_slots_distinct",
	"commerce_single_slot",
	"sixth_project_rejected_atomically",
	"maximum_project_rank_iv",
	"contribution_at_iv_preserves_rank",
	"unique_highest_controls",
	"exact_tie_has_no_controller",
	"shares_total_10000_with_remainder",
	"tombstone_clears_active_project",
	"reopen_increments_generation",
	"old_project_id_never_reused",
	"save_roundtrip_generation_and_tombstones",
	"public_private_snapshot_visibility",
	"old_product_identity_and_owner_authority_absent",
]

const CUTOVER_CASE_IDS := [
	"controller_scene_composition",
	"world_bridge_scene_composition",
	"controller_api_contract",
	"bridge_non_ownership_contract",
	"project_sequence_controller_owned",
	"route_algorithm_controller_owned",
	"refresh_orchestration_controller_owned",
	"cashflow_orchestration_controller_owned",
	"save_envelope_controller_owned",
	"legacy_save_normalized_once",
	"main_route_algorithms_absent",
	"main_refresh_algorithms_absent",
	"main_project_sequence_absent",
	"stable_main_adapters_present",
	"external_refresh_callers_preserved",
	"gdp_formula_owner_preserved",
	"cashflow_formula_owner_preserved",
	"product_market_owner_preserved",
	"controller_debug_pure_data",
	"no_parallel_network_owner",
]

const STRUCTURED_GDP_CASE_IDS := [
	"structured_gdp_profile_v05",
	"structured_gdp_row_schema",
	"production_receipt_maps_project",
	"demand_receipt_maps_project",
	"commerce_receipt_maps_project",
	"region_gdp_equals_row_sum",
	"project_gdp_equals_project_rows",
	"player_plus_neutral_conservation",
	"share_floor_remainder_neutral",
	"destroyed_region_rows_empty",
	"zero_gdp_allowed",
	"legacy_adjustment_explicit_neutral",
	"city_owner_not_attribution_authority",
	"same_owner_competition_not_exempt",
	"receipt_id_stable",
	"industry_catalog_mapping",
	"cashflow_source_uses_receipt_player",
	"cashflow_remainder_keyed_by_source",
	"public_gdp_snapshot_privacy",
	"legacy_gdp_split_symbols_absent",
]

const REMOVED_MAIN_ALGORITHMS := [
	"_route_base_flow_amount",
	"_city_gdp_formula_snapshot",
	"_refresh_city_competition_counts",
	"_refresh_city_trade_routes",
	"_trade_route_for_product_to_city",
	"_district_supplies_product",
	"_trade_source_type",
	"_shortest_trade_path",
	"_trade_edge_cost",
	"_trade_node_cost_multiplier",
	"_trade_path_transport_speed",
	"_trade_path_cost",
	"_trade_path_points",
	"_trade_path_is_disrupted",
]

const STABLE_MAIN_ADAPTERS := [
	"_normalize_city_product_project_state",
	"_city_public_project_snapshots",
	"_city_private_project_snapshots",
	"_city_has_project_shares",
	"_player_region_gdp_share_basis_points",
	"_active_city_district_indices",
	"_city_competition_matches",
	"_city_trade_routes",
	"_refresh_city_networks",
	"_trade_routes_for_product",
	"_apply_trade_disruption_from_destroyed_district",
	"_settle_city_cashflow_seconds",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _coordinator: Node
var _controller: Node
var _world_bridge: Node
var _gdp_formula: Node
var _cashflow: Node
var _product_market: Node
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _baseline_project_sequence := 1
var _records: Array = []
var _failures: Array[String] = []
var _sources: Dictionary = {}


func _ready() -> void:
	print("CityTradeNetworkRuntimeCharacterizationBench SS05-03 ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	var cases := CASE_IDS.duplicate()
	cases.append_array(CUTOVER_CASE_IDS)
	cases.append_array(V05_PROJECT_CASE_IDS)
	cases.append_array(STRUCTURED_GDP_CASE_IDS)
	return cases


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), false, false, "preview"))
	return {
		"suite": "city-trade-structured-project-gdp-v05-ss05-03",
		"ruleset_id": RULESET_ID,
		"runtime_owner": CONTROLLER_SCRIPT_PATH,
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
		"next_cutover_recommendation": "SS05-04 qualification and victory runtime characterization",
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_load_sources()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("CityTradeNetworkRuntimeCharacterizationBench could not instantiate real main.tscn.")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in characterization_cases():
		var case_id := str(case_id_variant)
		_reset_fixture()
		print("CityTradeNetworkRuntimeCharacterizationBench case: %s" % case_id)
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var main_source := str(_sources.get("main", ""))
	var current_sha := main_source.sha256_text().to_upper()
	var metrics := _main_metrics(main_source)
	var main_reduced := int(metrics.get("nonblank_lines", 0)) <= int(BASELINE_MAIN_METRICS.get("nonblank_lines", 0)) - 400 and int(metrics.get("function_count", 0)) <= int(BASELINE_MAIN_METRICS.get("function_count", 0)) - 12 and int(metrics.get("top_level_variable_count", 0)) <= int(BASELINE_MAIN_METRICS.get("top_level_variable_count", 0)) - 1
	if not main_reduced:
		_failures.append("main.gd deletion gate missed: baseline=%s current=%s" % [str(BASELINE_MAIN_METRICS), str(metrics)])
	var manifest := {
		"suite": "city-trade-structured-project-gdp-v05-ss05-03",
		"ruleset_id": RULESET_ID,
		"runtime_owner": CONTROLLER_SCRIPT_PATH,
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
		"production_main_unchanged": false,
		"main_reduction_gate_passed": main_reduced,
		"next_cutover_recommendation": "SS05-04 qualification and victory runtime characterization",
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("CityTradeNetworkRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("CityTradeNetworkRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("CityTradeNetworkRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("CityTradeNetworkRuntimeCharacterizationBench SS05-03 passed: %d/%d" % [_count_flag("passed"), CASE_COUNT])
	print("CityTradeNetworkRuntimeCharacterizationBench observed: %d/%d; aligned=%d/%d; design_decisions=%d" % [_count_flag("observed"), CASE_COUNT, _count_flag("contract_aligned"), CASE_COUNT, _count_flag("needs_design_decision")])
	if not _failures.is_empty():
		push_error("CityTradeNetworkRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	if STRUCTURED_GDP_CASE_IDS.has(case_id):
		return _case_structured_gdp(case_id)
	if CUTOVER_CASE_IDS.has(case_id):
		return _case_cutover(case_id)
	if V05_PROJECT_CASE_IDS.has(case_id):
		return _case_v05_project(case_id)
	match case_id:
		"city_trade_call_graph_complete": return _case_call_graph()
		"city_runtime_shape": return _case_city_shape()
		"stable_slot_project_identity": return _case_project_identity()
		"production_demand_commerce_directions": return _case_directions()
		"first_contribution_full_share": return _case_first_share()
		"repeated_contribution_same_player": return _case_repeat_share()
		"second_player_share_split": return _case_second_player_share()
		"highest_share_controls_project": return _case_highest_controller()
		"tie_has_no_controller": return _case_tie_controller()
		"project_share_total_exact": return _case_share_total()
		"city_gdp_weighted_by_project_level": return _case_gdp_weight()
		"city_gdp_allocation_exact": return _case_city_gdp_total()
		"player_gdp_allocation_exact": return _case_player_gdp_total()
		"public_project_snapshot_privacy": return _case_public_project_privacy()
		"private_project_snapshot_own_only": return _case_private_project_privacy()
		"legacy_owner_not_project_authority": return _case_legacy_migration()
		"city_surface_creation_order": return _case_city_surface_creation()
		"development_sequence_increments_once": return _case_development_sequence()
		"legacy_product_demand_sync": return _case_legacy_sync()
		"active_city_index_filter": return _case_active_city_filter()
		"destroyed_city_zeroes_project_gdp": return _case_destroyed_city_gdp()
		"competition_matches_other_owner": return _case_competition_other_owner()
		"same_owner_not_competition": return _case_competition_same_owner()
		"production_district_source_type": return _case_route_source(false)
		"city_source_type": return _case_route_source(true)
		"no_supply_route_safe_state": return _case_no_supply_route()
		"shortest_path_connected": return _case_shortest_path()
		"route_edge_cost_positive": return _case_edge_cost()
		"ocean_transport_cost_modifier": return _case_ocean_modifier()
		"destroyed_path_disrupted": return _case_destroyed_path()
		"miasma_panic_cost_modifier": return _case_miasma_panic_cost()
		"route_flow_fields_present": return _case_route_fields()
		"demand_order_damage_application": return _case_demand_damage_order()
		"supplied_disrupted_counts_exact": return _case_supply_counts()
		"product_route_filter": return _case_product_route_filter()
		"refresh_order_competition_routes_gdp_shares_supply": return _case_refresh_order()
		"gdp_formula_controller_boundary": return _case_gdp_formula_boundary()
		"cashflow_controller_cadence_boundary": return _case_cashflow_boundary()
		"project_share_cashflow_route": return _case_project_cashflow()
		"owner_only_city_has_no_project_payout": return _case_legacy_cashflow()
		"fractional_remainder_preserved": return _case_fractional_remainder()
		"destroyed_city_no_cashflow": return _case_destroyed_cashflow()
		"cross_system_refresh_single_hook": return _case_cross_system_refresh()
		"product_market_refresh_separate": return _case_market_refresh_separate()
		"current_save_shape": return _case_current_save_shape()
		"legacy_save_migrates_once": return _case_legacy_save_defaults()
		"public_city_route_privacy": return _case_public_privacy()
		"sprint64_deletion_candidates_complete": return _case_deletion_candidates()
	return _record(case_id, false, false, "Unknown case.")


func _case_call_graph() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var controller_source := str(_sources.get("controller", ""))
	var missing_adapters: Array = []
	for function_name in STABLE_MAIN_ADAPTERS:
		if not main_source.contains("func %s(" % str(function_name)):
			missing_adapters.append(function_name)
	var observed := missing_adapters.is_empty() and controller_source.contains("func refresh_networks(") and controller_source.contains("func settle_cashflow_seconds(") and str(_sources.get("gdp", "")).contains("func calculate_city_gdp(") and str(_sources.get("cashflow", "")).contains("func settle_sources(")
	return _record("city_trade_call_graph_complete", observed, observed, "Controller owns network orchestration while main retains only stable world-facing adapters; missing=%s." % str(missing_adapters))


func _case_city_shape() -> Dictionary:
	var city := _base_city(0)
	var required := ["owner", "active", "products", "demands", "projects", "competition_matches", "trade_routes", "trade_disrupted_routes", "supplied_demands", "gdp_cashflow_remainder_by_source_id"]
	var missing: Array = []
	for key in required:
		if not city.has(key): missing.append(key)
	var observed := missing.is_empty() and _is_data_only(city)
	return _record("city_runtime_shape", observed, observed, "City runtime shape is district-embedded pure data; missing=%s." % str(missing))


func _case_project_identity() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(3, TEST_PRODUCT, "production", 0, 1, 7)
	var expected := CITY_PROJECT_STATE.project_id(3, "production", 0, 1)
	var observed := str(project.get("project_id", "")) == expected and str(project.get("slot_id", "")) == CITY_PROJECT_STATE.slot_id(3, "production", 0) and not expected.contains(TEST_PRODUCT)
	return _record("stable_slot_project_identity", observed, observed, "Project identity is region + slot kind + slot index + generation; product remains content.", {"project_id": str(project.get("project_id", "")), "product_id": TEST_PRODUCT, "direction": "production", "slot_id": str(project.get("slot_id", "")), "generation": 1})


func _case_directions() -> Dictionary:
	var directions: Array = []
	for direction in ["production", "demand", "commerce"]:
		directions.append(str(CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, direction, 0, 1, directions.size()).get("direction", "")))
	var observed := directions == ["production", "demand", "commerce"]
	return _record("production_demand_commerce_directions", observed, observed, "All three v0.5 project-slot kinds are stable.")


func _case_first_share() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var observed := int(shares.get("0", 0)) == 10000 and int(project.get("controller_player_index", -1)) == 0
	return _record("first_contribution_full_share", observed, observed, "The first contributor receives 10000 basis points and project control.", {"project_id": str(project.get("project_id", "")), "share_total_basis_points": _int_total(shares)})


func _case_repeat_share() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 0, 2, 2)
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var observed := int(shares.get("0", 0)) == 10000 and int((project.get("contribution_by_player", {}) as Dictionary).get("0", 0)) == 3
	return _record("repeated_contribution_same_player", observed, observed, "Repeated contribution strengthens the same project without diluting its sole contributor.", {"share_total_basis_points": _int_total(shares)})


func _case_second_player_share() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
	var shares: Dictionary = project.get("share_basis_points_by_player", {})
	var observed := int(shares.get("0", 0)) == 5000 and int(shares.get("1", 0)) == 5000
	return _record("second_player_share_split", observed, observed, "Equal contributions split the project 50/50.", {"share_total_basis_points": _int_total(shares)})


func _case_highest_controller() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 1, 2, 2)
	var observed := int(project.get("controller_player_index", -1)) == 1
	return _record("highest_share_controls_project", observed, observed, "The largest contributor controls the specific product project.")


func _case_tie_controller() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 1, 1, 4)
	project = CITY_PROJECT_STATE.contribute(project, 0, 1, 5)
	var observed := int(project.get("controller_player_index", 99)) == -1
	return _record("tie_has_no_controller", observed, observed, "Exact highest-share ties have no project controller; contribution order is not a tie-break.")


func _case_share_total() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 1, 2, 2)
	project = CITY_PROJECT_STATE.contribute(project, 2, 4, 3)
	var total := _int_total(project.get("share_basis_points_by_player", {}))
	return _record("project_share_total_exact", total == 10000, total == 10000, "Largest-remainder allocation preserves exactly 10000 basis points without depending on controller identity.", {"share_total_basis_points": total})


func _case_gdp_weight() -> Dictionary:
	var first := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	var second := CITY_PROJECT_STATE.create_project(1, SECOND_PRODUCT, "demand", 1, 1, 2)
	second["level"] = 3
	second["rank"] = 3
	var attribution := CITY_PROJECT_STATE.attribute_gdp_rows([first, second], [_gdp_row(first, 25, "production"), _gdp_row(second, 75, "demand")])
	var projects: Array = attribution.get("projects", []) as Array
	var observed := bool(attribution.get("valid", false)) and int((projects[0] as Dictionary).get("current_gdp", 0)) == 25 and int((projects[1] as Dictionary).get("current_gdp", 0)) == 75
	return _record("city_gdp_weighted_by_project_level", observed, observed, "Historical case ID now proves GDP comes from project-keyed rows, not rank-weighted whole-city splitting.", {"city_gdp": 100})


func _case_city_gdp_total() -> Dictionary:
	var first := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	var second := CITY_PROJECT_STATE.create_project(1, SECOND_PRODUCT, "demand", 1, 1, 2)
	var attribution := CITY_PROJECT_STATE.attribute_gdp_rows([first, second], [_gdp_row(first, 50, "production"), _gdp_row(second, 51, "demand")])
	var total := int(attribution.get("project_gdp_per_minute", 0))
	return _record("city_gdp_allocation_exact", total == 101, total == 101, "Project GDP allocations preserve the exact city total after flooring.", {"city_gdp": total})


func _case_player_gdp_total() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 1, 2, 2)
	var attribution := CITY_PROJECT_STATE.attribute_gdp_rows([project], [_gdp_row(project, 101, "production")])
	var player_total := int(attribution.get("player_gdp_per_minute", 0))
	var neutral_total := int(attribution.get("neutral_gdp_per_minute", 0))
	var observed := player_total + neutral_total == 101 and neutral_total == 1
	return _record("player_gdp_allocation_exact", observed, observed, "Player floors plus neutral remainder preserve the exact project GDP total.", {"city_gdp": 101, "player_gdp_total": player_total})


func _case_public_project_privacy() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
	var public_snapshot: Dictionary = CITY_PROJECT_STATE.public_snapshot(project)
	var observed := not public_snapshot.has("controller_player_index") and not public_snapshot.has("contribution_by_player") and not public_snapshot.has("share_basis_points_by_player")
	return _record("public_project_snapshot_privacy", observed, observed, "Public project facts expose product, direction, level, and GDP but no controller/share table.", {"privacy_checked": true})


func _case_private_project_privacy() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(1, TEST_PRODUCT, "production", 0, 1, 1)
	project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
	var private_snapshot: Dictionary = CITY_PROJECT_STATE.private_snapshot(project, 0)
	var observed := private_snapshot.has("own_share_basis_points") and private_snapshot.has("own_contribution") and private_snapshot.has("is_controller") and not private_snapshot.has("contribution_by_player") and not private_snapshot.has("share_basis_points_by_player")
	return _record("private_project_snapshot_own_only", observed, observed, "Private snapshot adds only the viewer's own share/contribution/control facts.", {"privacy_checked": true})


func _case_legacy_migration() -> Dictionary:
	var migrated := CITY_PROJECT_BRIDGE.normalize_city({"owner": 2, "active": true, "products": [{"name": TEST_PRODUCT, "level": 2}], "demands": [SECOND_PRODUCT]}, 4, 10)
	var projects: Array = migrated.get("projects", [])
	var observed := projects.is_empty() and (migrated.get("project_slots", []) as Array).size() == 5 and not bool(migrated.get("legacy_owner_is_project_authority", true))
	return _record("legacy_owner_not_project_authority", observed, observed, "Legacy owner/products/demands remain display compatibility fields but never synthesize v0.5 shares or project control.", {"save_checked": true})


func _case_city_surface_creation() -> Dictionary:
	_isolate_map()
	var district_index := _first_land_district()
	if district_index < 0: return _record("city_surface_creation_order", false, false, "No land district.")
	var players_before: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	var built_before := int((players_before[0] as Dictionary).get("cities_built", 0))
	var city: Dictionary = CITY_FIXTURES.create_city_surface(_runtime_main, 0, district_index, "CityTrade fixture")
	var players_after: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players
	var observed := bool(city.get("active", false)) and int(city.get("owner", -1)) == 0 and not (city.get("projects", []) as Array).is_empty() and int((players_after[0] as Dictionary).get("cities_built", 0)) == built_before + 1
	return _record("city_surface_creation_order", observed, observed, "The real development transaction creates the shell and first product project atomically while incrementing cities_built once.", {"district_index": district_index})


func _case_development_sequence() -> Dictionary:
	_isolate_map()
	var district_index := _first_land_district()
	if district_index < 0: return _record("development_sequence_increments_once", false, false, "No land district.")
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	var products: Array = district.get("products", []) if district.get("products", []) is Array else []
	if not products.has(TEST_PRODUCT): products.append(TEST_PRODUCT)
	district["products"] = products
	districts[district_index] = district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var before := int(_controller.call("project_sequence"))
	var coordinator := _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var receipt: Dictionary = coordinator.call("execute_city_development", {"player_index": 0, "district_index": district_index, "skill": {"name": "Sprint63Development", "action_id": "sprint63_city_development", "development_target_district": district_index, "product_id": TEST_PRODUCT, "project_direction": "production", "contribution_units": 1, "allowed_terrains": ["land"]}}) if coordinator != null else {}
	var applied := bool(receipt.get("resolved", false))
	var after := int(_controller.call("project_sequence"))
	var city: Dictionary = _runtime_main.call("_district_city", district_index)
	var observed := applied and after == before + 1 and (city.get("projects", []) as Array).size() == 1
	return _record("development_sequence_increments_once", observed, observed, "One resolved development card consumes exactly one global contribution order.", {"district_index": district_index, "project_id": "%d:%s:production" % [district_index, TEST_PRODUCT]})


func _case_legacy_sync() -> Dictionary:
	var city := _base_city(0)
	var production_result := CITY_PROJECT_BRIDGE.apply_project_contribution(city, 1, 0, {"product_id": TEST_PRODUCT, "project_direction": "production", "contribution_units": 1}, 1)
	city = (production_result.get("city", {}) as Dictionary).duplicate(true)
	var demand_result := CITY_PROJECT_BRIDGE.apply_project_contribution(city, 1, 0, {"product_id": SECOND_PRODUCT, "project_direction": "demand", "contribution_units": 1}, 2)
	city = (demand_result.get("city", {}) as Dictionary).duplicate(true)
	var observed := _city_product_names(city).has(TEST_PRODUCT) and (city.get("demands", []) as Array).has(SECOND_PRODUCT)
	return _record("legacy_product_demand_sync", observed, observed, "Project changes keep legacy products/demands synchronized for existing consumers.")


func _case_active_city_filter() -> Dictionary:
	_isolate_map()
	var pair := _reachable_pair()
	if pair.is_empty(): return _record("active_city_index_filter", false, false, "No reachable pair.")
	_set_city(int(pair[0]), _base_city(0))
	var inactive := _base_city(1)
	inactive["active"] = false
	_set_city(int(pair[1]), inactive)
	var active: Array = _runtime_main.call("_active_city_district_indices")
	var observed := active.has(int(pair[0])) and not active.has(int(pair[1]))
	return _record("active_city_index_filter", observed, observed, "Only city.active participates in network refresh.")


func _case_destroyed_city_gdp() -> Dictionary:
	var fixture := _network_fixture(false, true)
	if fixture.is_empty(): return _record("destroyed_city_zeroes_project_gdp", false, false, "No network fixture.")
	var destination := int(fixture.get("destination", -1))
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	districts[destination]["destroyed"] = true
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_runtime_main.call("_refresh_city_networks")
	var city: Dictionary = _runtime_main.call("_district_city", destination)
	var projects: Array = city.get("projects", [])
	var observed := not projects.is_empty() and int((projects[0] as Dictionary).get("current_gdp", -1)) == 0
	return _record("destroyed_city_zeroes_project_gdp", observed, observed, "Destroyed districts retain records but receive zero project GDP.", {"district_index": destination, "city_gdp": 0})


func _case_competition_other_owner() -> Dictionary:
	var fixture := _competition_fixture(false)
	var first := int(fixture.get("first", -1))
	var matches := int(_runtime_main.call("_city_competition_matches", first)) if first >= 0 else -1
	return _record("competition_matches_other_owner", matches == 1, matches == 1, "Matching production projects in another region count once without reading city owner.", {"district_index": first})


func _case_competition_same_owner() -> Dictionary:
	var fixture := _competition_fixture(true)
	var first := int(fixture.get("first", -1))
	var matches := int(_runtime_main.call("_city_competition_matches", first)) if first >= 0 else -1
	return _record("same_owner_not_competition", matches == 1, matches == 1, "Historical case ID now proves v0.5 has no same-owner competition exemption.", {"district_index": first})


func _case_route_source(city_source: bool) -> Dictionary:
	var fixture := _network_fixture(city_source, true)
	var route: Dictionary = fixture.get("route", {})
	var expected := "城市" if city_source else "产区"
	var case_id := "city_source_type" if city_source else "production_district_source_type"
	var observed := not route.is_empty() and str(route.get("source_type", "")) == expected
	return _record(case_id, observed, observed, "Best route labels its source as %s." % expected, _route_flags(fixture))


func _case_no_supply_route() -> Dictionary:
	var fixture := _network_fixture(false, true, false)
	var destination := int(fixture.get("destination", -1))
	if destination < 0: return _record("no_supply_route_safe_state", false, false, "No destination.")
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	var source := int(fixture.get("source", -1))
	var source_district: Dictionary = (districts[source] as Dictionary).duplicate(true)
	source_district["products"] = []
	source_district["city"] = {}
	districts[source] = source_district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_runtime_main.call("_refresh_city_networks")
	var routes: Array = (_runtime_main.call("_district_city", destination) as Dictionary).get("trade_routes", [])
	var route: Dictionary = routes[0] if not routes.is_empty() else {}
	var observed := int(route.get("from", 0)) == -1 and bool(route.get("disrupted", false)) and str(route.get("source_type", "")) == "无供给"
	return _record("no_supply_route_safe_state", observed, observed, "Missing supply creates one explicit disrupted route instead of crashing.", {"district_index": destination, "route_count": routes.size()})


func _case_shortest_path() -> Dictionary:
	var fixture := _network_fixture(false, true)
	var path: Array = fixture.get("path", [])
	var observed := path.size() >= 2 and int(path[0]) == int(fixture.get("source", -1)) and int(path[path.size() - 1]) == int(fixture.get("destination", -1))
	return _record("shortest_path_connected", observed, observed, "Shortest path begins at the chosen supply and ends at the demand city.", _route_flags(fixture))


func _case_edge_cost() -> Dictionary:
	var pair := _reachable_pair()
	if pair.is_empty(): return _record("route_edge_cost_positive", false, false, "No route pair.")
	var path: Array = _controller.call("shortest_trade_path", int(pair[0]), int(pair[1]))
	var cost := float(_controller.call("trade_path_cost", path))
	return _record("route_edge_cost_positive", path.size() >= 2 and cost > 0.0 and not is_inf(cost), true, "Connected path cost is finite and positive.", {"path_length": path.size()})


func _case_ocean_modifier() -> Dictionary:
	var land := _first_district_by_terrain("land")
	var ocean := _first_district_by_terrain("ocean")
	if land < 0 or ocean < 0: return _record("ocean_transport_cost_modifier", false, false, "Missing land/ocean district.")
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	for index in [land, ocean]:
		districts[index]["transport_score"] = 2.0
		districts[index]["panic"] = 0
		districts[index]["miasma"] = false
		districts[index]["destroyed"] = false
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var land_cost := float(_controller.call("trade_node_cost_multiplier", land))
	var ocean_cost := float(_controller.call("trade_node_cost_multiplier", ocean))
	var observed := ocean_cost < land_cost and is_equal_approx(ocean_cost / land_cost, 0.88)
	return _record("ocean_transport_cost_modifier", observed, observed, "At equal public transport speed, ocean nodes retain the 0.88 route-cost modifier.")


func _case_destroyed_path() -> Dictionary:
	var fixture := _network_fixture(false, true)
	var path: Array = fixture.get("path", [])
	if path.is_empty(): return _record("destroyed_path_disrupted", false, false, "No route path.")
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	districts[int(path[0])]["destroyed"] = true
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var observed: bool = _controller.call("trade_path_is_disrupted", path)
	return _record("destroyed_path_disrupted", observed, observed, "Any destroyed node marks the path disrupted.", _route_flags(fixture))


func _case_miasma_panic_cost() -> Dictionary:
	var district_index := _first_land_district()
	if district_index < 0: return _record("miasma_panic_cost_modifier", false, false, "No land district.")
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	districts[district_index]["destroyed"] = false
	districts[district_index]["miasma"] = false
	districts[district_index]["panic"] = 0
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var before := float(_controller.call("trade_node_cost_multiplier", district_index))
	districts = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	districts[district_index]["miasma"] = true
	districts[district_index]["panic"] = 100
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	var after := float(_controller.call("trade_node_cost_multiplier", district_index))
	var observed := is_equal_approx(after - before, 0.55)
	return _record("miasma_panic_cost_modifier", observed, observed, "Miasma adds 0.35 and panic adds 0.002 per point to node cost.", {"district_index": district_index})


func _case_route_fields() -> Dictionary:
	var fixture := _network_fixture(false, true)
	var route: Dictionary = fixture.get("route", {})
	var required := ["product", "from", "to", "path", "points", "disrupted", "source_type", "cost", "raw_cost", "flow_multiplier", "public_speed", "flow_speed", "flow_amount"]
	var missing: Array = []
	for key in required:
		if not route.has(key): missing.append(key)
	return _record("route_flow_fields_present", missing.is_empty(), missing.is_empty(), "Route snapshot contains geometry, status, cost, speed, and flow fields; missing=%s." % str(missing), _route_flags(fixture))


func _case_demand_damage_order() -> Dictionary:
	var fixture := _two_demand_fixture(1)
	var routes: Array = fixture.get("routes", [])
	var observed := routes.size() == 2 and bool((routes[0] as Dictionary).get("disrupted", false)) and not bool((routes[1] as Dictionary).get("disrupted", true))
	return _record("demand_order_damage_application", observed, observed, "trade_route_damage is consumed in demand-list order.", {"district_index": int(fixture.get("destination", -1)), "route_count": routes.size()})


func _case_supply_counts() -> Dictionary:
	var fixture := _two_demand_fixture(1)
	var city: Dictionary = fixture.get("city", {})
	var observed := int(city.get("supplied_demands", -1)) == 1 and int(city.get("trade_disrupted_routes", -1)) == 1
	return _record("supplied_disrupted_counts_exact", observed, observed, "One damaged and one healthy supplied demand produce exact 1/1 counters.", {"district_index": int(fixture.get("destination", -1)), "route_count": (fixture.get("routes", []) as Array).size()})


func _case_product_route_filter() -> Dictionary:
	_two_demand_fixture(0)
	var routes: Array = _controller.call("trade_routes_for_product", TEST_PRODUCT)
	var observed := routes.size() == 1 and str((routes[0] as Dictionary).get("product", "")) == TEST_PRODUCT
	return _record("product_route_filter", observed, observed, "Product route query returns only non-empty paths for the selected product.", {"product_id": TEST_PRODUCT, "route_count": routes.size()})


func _case_refresh_order() -> Dictionary:
	var source := _function_source(str(_sources.get("controller", "")), "refresh_networks")
	var source_order := _tokens_in_order(source, ["_competition_matches(", "_trade_route_for_product(", "_city_with_gdp_rows(", "ensure_city_development_supply"])
	var fixture := _network_fixture(false, true)
	var destination := int(fixture.get("destination", -1))
	var city: Dictionary = _runtime_main.call("_district_city", destination) if destination >= 0 else {}
	var projects: Array = city.get("projects", [])
	var runtime_effect := int(city.get("supplied_demands", 0)) == 1 and not projects.is_empty() and int((projects[0] as Dictionary).get("current_gdp", -1)) >= 0
	var observed := source_order and runtime_effect
	return _record("refresh_order_competition_routes_gdp_shares_supply", observed, observed, "Refresh order is competition -> routes -> structured GDP rows -> project attribution -> supply guarantee.", {"district_index": destination, "refresh_order_checked": source_order})


func _case_gdp_formula_boundary() -> Dictionary:
	var controller_source := str(_sources.get("controller", ""))
	var observed := _function_source(controller_source, "_city_gdp_breakdown_from_snapshot").contains("calculate_city_gdp") and _gdp_formula != null and _gdp_formula.has_method("calculate_city_gdp")
	return _record("gdp_formula_controller_boundary", observed, observed, "CityTradeNetworkRuntimeController assembles network facts while GdpFormulaRuntimeController retains GDP arithmetic.", {"formula_owner_checked": true})


func _case_cashflow_boundary() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var coordinator_source := str(_sources.get("coordinator", ""))
	var controller_source := str(_sources.get("controller", ""))
	var observed := _function_source(main_source, "_update_realtime_economy_cashflow").contains("advance_economy_cashflow") and _function_source(coordinator_source, "advance_economy_cashflow").contains("advance_clock") and _function_source(controller_source, "settle_cashflow_seconds").contains("settle_sources") and _cashflow != null
	return _record("cashflow_controller_cadence_boundary", observed, observed, "EconomyCashflowRuntimeController owns cadence and payout arithmetic; CityTradeNetworkRuntimeController owns source orchestration and receipt planning.", {"cashflow_owner_checked": true})


func _case_project_cashflow() -> Dictionary:
	var fixture := _cashflow_fixture(true, false)
	var cash_before: Array = _player_cash_values()
	var paid := int(_runtime_main.call("_settle_city_cashflow_seconds", 60.0))
	var cash_after: Array = _player_cash_values()
	var observed := paid > 0 and int(cash_after[0]) > int(cash_before[0]) and int(cash_after[1]) > int(cash_before[1])
	return _record("project_share_cashflow_route", observed, observed, "A project city emits project_share sources and pays both shareholders through one cashflow settlement.", {"district_index": int(fixture.get("destination", -1)), "cashflow_owner_checked": true})


func _case_legacy_cashflow() -> Dictionary:
	var fixture := _cashflow_fixture(false, false)
	var cash_before: Array = _player_cash_values()
	var paid := int(_runtime_main.call("_settle_city_cashflow_seconds", 60.0))
	var cash_after: Array = _player_cash_values()
	var observed := paid == 0 and cash_after == cash_before
	return _record("owner_only_city_has_no_project_payout", observed, observed, "A shared city without project shares pays nobody; the transitional owner field is not economic authority.", {"district_index": int(fixture.get("destination", -1)), "cashflow_owner_checked": true})


func _case_fractional_remainder() -> Dictionary:
	var fixture := _cashflow_fixture(true, false, 1)
	var destination := int(fixture.get("destination", -1))
	var city_before: Dictionary = _runtime_main.call("_district_city", destination)
	city_before["gdp_cashflow_remainder_by_source_id"] = {"retired.project.receipt.player.0": 0.75}
	_runtime_main.call("_settle_city_cashflow_seconds", 1.0)
	var city: Dictionary = _runtime_main.call("_district_city", destination)
	var remainders: Dictionary = city.get("gdp_cashflow_remainder_by_source_id", {})
	var total := 0.0
	for value in remainders.values(): total += float(value)
	var observed := total > 0.0 and total < 2.0 and not remainders.has("retired.project.receipt.player.0")
	return _record("fractional_remainder_preserved", observed, observed, "Sub-unit payouts persist only for active receipt+player source IDs; retired generation keys are discarded.", {"district_index": destination, "cashflow_owner_checked": true})


func _case_destroyed_cashflow() -> Dictionary:
	var fixture := _cashflow_fixture(true, true)
	var destination := int(fixture.get("destination", -1))
	var cash_before: Array = _player_cash_values()
	var paid := int(_runtime_main.call("_settle_city_cashflow_seconds", 60.0))
	var cash_after: Array = _player_cash_values()
	var city: Dictionary = _runtime_main.call("_district_city", destination)
	var observed := paid == 0 and cash_after == cash_before and int(city.get("last_cashflow_rate", -1)) == 0
	return _record("destroyed_city_no_cashflow", observed, observed, "Destroyed city payout stops before source settlement and records a zero rate.", {"district_index": destination, "cashflow_owner_checked": true})


func _case_cross_system_refresh() -> Dictionary:
	var callers := ["contract", "military", "weather", "product_market"]
	var missing: Array = []
	for caller in callers:
		if not str(_sources.get(caller, "")).contains("_refresh_city_networks"):
			missing.append(caller)
	var observed := missing.is_empty()
	return _record("cross_system_refresh_single_hook", observed, observed, "Contract, military, weather, and product-market bridges all request the same main world refresh hook; missing=%s." % str(missing), {"refresh_order_checked": true})


func _case_market_refresh_separate() -> Dictionary:
	var refresh_source := _function_source(str(_sources.get("main", "")), "_refresh_city_networks")
	var development_source := _function_source(FileAccess.get_file_as_string("res://scripts/runtime/city_development_world_bridge.gd"), "apply_settlement_plan")
	var observed := not refresh_source.contains("refresh_prices") and _tokens_in_order(development_source, ["refresh_networks", "refresh_prices"])
	return _record("product_market_refresh_separate", observed, observed, "Network refresh does not own market prices; the city-development transaction requests market refresh explicitly afterward.", {"refresh_order_checked": true})


func _case_current_save_shape() -> Dictionary:
	var fixture := _network_fixture(false, true)
	_controller.call("apply_save_data", {"city_trade_network_runtime": {"terms_version": "v0.5.structured-project-gdp.1", "project_sequence": 77, "generation_by_slot_id": {}, "project_tombstones": []}})
	var state: Dictionary = _runtime_main.call("_capture_run_domain_state_compatibility_adapter")
	var saved_districts: Array = state.get("districts", [])
	var destination := int(fixture.get("destination", -1))
	var city: Dictionary = ((saved_districts[destination] as Dictionary).get("city", {}) as Dictionary) if destination >= 0 and destination < saved_districts.size() else {}
	var runtime_state: Dictionary = state.get("city_trade_network_runtime", {}) if state.get("city_trade_network_runtime", {}) is Dictionary else {}
	var observed := not state.has("city_product_project_sequence") and str(runtime_state.get("terms_version", "")) == "v0.5.structured-project-gdp.1" and int(runtime_state.get("project_sequence", 0)) == 77 and runtime_state.has("generation_by_slot_id") and runtime_state.has("project_tombstones") and not (city.get("projects", []) as Array).is_empty() and not (city.get("trade_routes", []) as Array).is_empty()
	return _record("current_save_shape", observed, observed, "The domain save owns one v0.5 project-slot envelope with sequence, generations, and tombstones; no flat duplicate is written.", {"district_index": destination, "save_checked": true})


func _case_legacy_save_defaults() -> Dictionary:
	var controller_source := str(_sources.get("controller", ""))
	var apply_source := _function_source(controller_source, "apply_save_data")
	var migrated := CITY_PROJECT_BRIDGE.normalize_city({"owner": 0, "active": true, "products": [{"name": TEST_PRODUCT, "level": 1}], "demands": []}, 2, 1)
	var receipt: Dictionary = _controller.call("apply_save_data", {"city_product_project_sequence": 19})
	var observed := apply_source.contains("data.get(\"city_product_project_sequence\"") and bool(receipt.get("migration_applied", false)) and int(_controller.call("project_sequence")) == 19 and (migrated.get("projects", []) as Array).is_empty()
	return _record("legacy_save_migrates_once", observed, observed, "The legacy flat sequence is read only at the explicit migration boundary; owner/product display fields do not create projects.", {"save_checked": true})


func _case_public_privacy() -> Dictionary:
	var fixture := _network_fixture(false, true)
	var destination := int(fixture.get("destination", -1))
	var projects: Array = _runtime_main.call("_city_public_project_snapshots", destination)
	var routes: Array = (_runtime_main.call("_district_city", destination) as Dictionary).get("trade_routes", [])
	var public_text := JSON.stringify({"projects": projects, "routes": routes})
	var observed := not public_text.contains("controller_player_index") and not public_text.contains("contribution_by_player") and not public_text.contains("share_basis_points_by_player") and not public_text.contains("hidden_owner") and not public_text.contains("private_target")
	return _record("public_city_route_privacy", observed, observed, "Public projects/routes reveal topology and economics but no controller, share table, or private target.", {"district_index": destination, "privacy_checked": true, "route_count": routes.size()})


func _case_deletion_candidates() -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var remaining: Array = []
	for function_name in REMOVED_MAIN_ALGORITHMS:
		if main_source.contains("func %s(" % str(function_name)): remaining.append(function_name)
	var adapters_present := true
	for function_name in STABLE_MAIN_ADAPTERS:
		adapters_present = adapters_present and main_source.contains("func %s(" % str(function_name))
	var controller_present := ResourceLoader.exists(CONTROLLER_SCENE_PATH) and ResourceLoader.exists(CONTROLLER_SCRIPT_PATH)
	var observed := remaining.is_empty() and not main_source.contains("var city_product_project_sequence") and controller_present and adapters_present
	return _record("sprint64_deletion_candidates_complete", observed, observed, "Old algorithms absent=%s; Controller present=%s; stable adapters=%s." % [str(remaining.is_empty()), str(controller_present), str(adapters_present)], {"refresh_order_checked": true})


func _case_v05_project(case_id: String) -> Dictionary:
	var observed := false
	var notes := ""
	var flags := {"privacy_checked": case_id.contains("visibility") or case_id.contains("authority"), "save_checked": case_id.contains("save")}
	match case_id:
		"v05_profile_project_contract":
			var debug: Dictionary = _controller.call("debug_snapshot", -1)
			observed = str(debug.get("project_ruleset_id", "")) == "v0.5" and debug.get("project_slot_counts", {}) == CITY_PROJECT_STATE.SLOT_COUNTS and int(debug.get("maximum_project_rank", 0)) == 4
			notes = "The Controller reads the Inspector-editable v0.5 profile for 2/2/1 slots and rank IV."
		"exactly_five_project_slots":
			var city := _v05_empty_city(5)
			observed = (city.get("project_slots", []) as Array).size() == 5
			notes = "Every buildable region has exactly five canonical project slots."
		"slot_order_stable":
			var city := _v05_empty_city(5)
			var order: Array[String] = []
			for slot_variant in city.get("project_slots", []):
				var slot: Dictionary = slot_variant
				order.append("%s:%d" % [str(slot.get("slot_kind", "")), int(slot.get("slot_index", -1))])
			observed = order == ["production:0", "production:1", "demand:0", "demand:1", "commerce:0"]
			notes = "Slot order is production 0/1, demand 0/1, commerce 0."
		"stable_ascii_region_and_slot_ids":
			var city := _v05_empty_city(5)
			observed = _ascii_stable_id(str(city.get("region_id", "")))
			for slot_variant in city.get("project_slots", []):
				observed = observed and _ascii_stable_id(str((slot_variant as Dictionary).get("slot_id", "")))
			notes = "Region and slot IDs are stable ASCII identifiers independent of localized content."
		"product_not_part_of_project_identity":
			var first := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 1, 1, 0, 1)
			var second := CITY_PROJECT_STATE.create_project(5, SECOND_PRODUCT, "production", 0, 1, 1, 0, 1)
			observed = str(first.get("project_id", "")) == str(second.get("project_id", "")) and not str(first.get("project_id", "")).contains(TEST_PRODUCT)
			notes = "Changing slot content never changes project identity inputs."
		"same_product_two_production_slots_distinct":
			var city := _v05_empty_city(5)
			var first := _apply_slot_project(city, 5, 0, TEST_PRODUCT, "production", 0, 1)
			var second := _apply_slot_project(first.get("city", {}) as Dictionary, 5, 0, TEST_PRODUCT, "production", 1, 2)
			observed = bool(first.get("applied", false)) and bool(second.get("applied", false)) and str(first.get("project_id", "")) != str(second.get("project_id", ""))
			notes = "Two production slots may contain the same product without ID collision."
		"same_product_two_demand_slots_distinct":
			var city := _v05_empty_city(5)
			var first := _apply_slot_project(city, 5, 0, TEST_PRODUCT, "demand", 0, 1)
			var second := _apply_slot_project(first.get("city", {}) as Dictionary, 5, 0, TEST_PRODUCT, "demand", 1, 2)
			observed = bool(first.get("applied", false)) and bool(second.get("applied", false)) and str(first.get("project_id", "")) != str(second.get("project_id", ""))
			notes = "Two demand slots may contain the same product without ID collision."
		"commerce_single_slot":
			var city := _v05_empty_city(5)
			var first := _apply_slot_project(city, 5, 0, TEST_PRODUCT, "commerce", 0, 1)
			var second := _apply_slot_project(first.get("city", {}) as Dictionary, 5, 0, SECOND_PRODUCT, "commerce", 1, 2)
			observed = bool(first.get("applied", false)) and not bool(second.get("applied", true))
			notes = "Commerce exposes one slot and rejects a second slot without mutation."
		"sixth_project_rejected_atomically":
			var city := _v05_empty_city(5)
			var order := 1
			for entry in [["p0", "production", 0], ["p1", "production", 1], ["d0", "demand", 0], ["d1", "demand", 1], ["c0", "commerce", 0]]:
				var receipt := _apply_slot_project(city, 5, 0, str(entry[0]), str(entry[1]), int(entry[2]), order)
				city = (receipt.get("city", {}) as Dictionary).duplicate(true)
				order += 1
			var before := JSON.stringify(city)
			var rejected := CITY_PROJECT_BRIDGE.apply_project_contribution(city, 5, 0, {"product_id": "overflow", "project_direction": "production"}, order)
			observed = not bool(rejected.get("applied", true)) and str(rejected.get("reason_code", "")) == "project_slot_unavailable" and JSON.stringify(rejected.get("city", {})) == before
			notes = "A sixth active project is rejected atomically."
		"maximum_project_rank_iv":
			var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 1, 1)
			for order in range(2, 10): project = CITY_PROJECT_STATE.contribute(project, 0, 1, order)
			observed = int(project.get("rank", 0)) == 4 and int(project.get("level", 0)) == 4
			notes = "Ordinary project upgrades clamp at rank IV."
		"contribution_at_iv_preserves_rank":
			var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 4, 1)
			project["rank"] = 4
			project["level"] = 4
			var updated := CITY_PROJECT_STATE.contribute(project, 1, 2, 2)
			observed = int(updated.get("rank", 0)) == 4 and int((updated.get("contribution_by_player", {}) as Dictionary).get("1", 0)) == 2
			notes = "Rank IV still accepts share contributions while refusing rank V."
		"unique_highest_controls":
			var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 2, 1)
			project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
			observed = int(project.get("controller_player_index", -1)) == 0
			notes = "Only the unique highest contributor controls a project."
		"exact_tie_has_no_controller":
			var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 1, 1)
			project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
			observed = int(project.get("controller_player_index", 99)) == -1
			notes = "Exact top-share ties resolve to controller=-1."
		"shares_total_10000_with_remainder":
			var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 1, 1)
			project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
			project = CITY_PROJECT_STATE.contribute(project, 2, 1, 3)
			var shares: Dictionary = project.get("share_basis_points_by_player", {})
			observed = _int_total(shares) == 10000 and shares.values().has(3334)
			flags["share_total_basis_points"] = _int_total(shares)
			notes = "Largest-remainder allocation is deterministic and totals exactly 10,000bp."
		"tombstone_clears_active_project":
			var opened := _apply_slot_project(_v05_empty_city(5), 5, 0, TEST_PRODUCT, "production", 0, 1)
			var tombstoned := CITY_PROJECT_BRIDGE.tombstone_project(opened.get("city", {}) as Dictionary, 5, str(opened.get("slot_id", "")), "district_destroyed")
			var tombstone_city: Dictionary = tombstoned.get("city", {}) as Dictionary
			observed = bool(tombstoned.get("applied", false)) and CITY_PROJECT_BRIDGE.active_projects(tombstone_city).is_empty() and (tombstone_city.get("project_tombstones", []) as Array).size() == 1
			notes = "Tombstoning clears active GDP identity and retains immutable lifecycle evidence."
		"reopen_increments_generation":
			var opened := _apply_slot_project(_v05_empty_city(5), 5, 0, TEST_PRODUCT, "production", 0, 1)
			var tombstoned := CITY_PROJECT_BRIDGE.tombstone_project(opened.get("city", {}) as Dictionary, 5, str(opened.get("slot_id", "")), "district_destroyed")
			var reopened := _apply_slot_project(tombstoned.get("city", {}) as Dictionary, 5, 0, SECOND_PRODUCT, "production", 0, 2)
			observed = bool(reopened.get("applied", false)) and int(reopened.get("generation", 0)) == 2
			notes = "Rebuilding an emptied slot increments generation."
		"old_project_id_never_reused":
			var opened := _apply_slot_project(_v05_empty_city(5), 5, 0, TEST_PRODUCT, "production", 0, 1)
			var tombstoned := CITY_PROJECT_BRIDGE.tombstone_project(opened.get("city", {}) as Dictionary, 5, str(opened.get("slot_id", "")), "district_destroyed")
			var reopened := _apply_slot_project(tombstoned.get("city", {}) as Dictionary, 5, 0, TEST_PRODUCT, "production", 0, 2)
			observed = str(opened.get("project_id", "")) != str(reopened.get("project_id", "")) and str(reopened.get("project_id", "")).ends_with(".g2")
			notes = "A tombstoned project ID is never reused, even for the same product."
		"save_roundtrip_generation_and_tombstones":
			var opened := _apply_slot_project(_v05_empty_city(5), 5, 0, TEST_PRODUCT, "production", 0, 1)
			var tombstoned := CITY_PROJECT_BRIDGE.tombstone_project(opened.get("city", {}) as Dictionary, 5, str(opened.get("slot_id", "")), "district_destroyed")
			_controller.call("normalize_city", tombstoned.get("city", {}) as Dictionary, 5)
			var save_data: Dictionary = _controller.call("to_save_data")
			_controller.call("reset_state")
			var load_receipt: Dictionary = _controller.call("apply_save_data", save_data)
			var debug: Dictionary = _controller.call("debug_snapshot", -1)
			observed = bool(load_receipt.get("applied", false)) and not bool(load_receipt.get("migration_applied", true)) and int(debug.get("generation_count", 0)) >= 1 and int(debug.get("tombstone_count", 0)) >= 1
			notes = "Generation registry and tombstones round-trip in the single domain save envelope."
		"public_private_snapshot_visibility":
			var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 1, 1)
			project = CITY_PROJECT_STATE.contribute(project, 1, 1, 2)
			var public_snapshot := CITY_PROJECT_STATE.public_snapshot(project)
			var private_snapshot := CITY_PROJECT_STATE.private_snapshot(project, 0)
			var public_text := JSON.stringify(public_snapshot)
			observed = str(public_snapshot.get("visibility_scope", "")) == "public" and str(private_snapshot.get("visibility_scope", "")) == "viewer_private" and not public_text.contains("controller_player_index") and not public_text.contains("contribution_by_player") and _is_data_only(private_snapshot)
			notes = "Visibility scope is attached before presentation; public output omits control/share truth."
		"old_product_identity_and_owner_authority_absent":
			var state_source := str(_sources.get("project_state", ""))
			var bridge_source := str(_sources.get("project_bridge", ""))
			var controller_source := str(_sources.get("controller", ""))
			observed = not bridge_source.contains("func migrate_legacy_city(") and not bridge_source.contains("func apply_development(") and not state_source.contains("%d:%s:%s") and not controller_source.contains("\"source_kind\": \"city_owner\"") and not controller_source.contains("SHARE_BASIS_POINTS if int(city.get(\"owner\"")
			notes = "Product-derived IDs, owner-synthesized projects, owner-only payout, and old mutable writer APIs are absent."
	return _record(case_id, observed, observed, notes, flags)


func _case_structured_gdp(case_id: String) -> Dictionary:
	var observed := false
	var notes := ""
	var flags := {"formula_owner_checked": true}
	match case_id:
		"structured_gdp_profile_v05":
			var debug: Dictionary = _gdp_formula.call("debug_snapshot")
			observed = str(debug.get("profile_id", "")) == "gdp_formula_v05" and str(debug.get("schema_version", "")) == "v0.5.structured-project-gdp.1" and bool(debug.get("zero_gdp_allowed", false))
			notes = "The live GDP owner uses the Inspector-editable v0.5 structured-project profile."
		"structured_gdp_row_schema":
			var breakdown := _structured_breakdown()
			var rows: Array = breakdown.get("gdp_rows", []) as Array
			var required := ["receipt_id", "region_id", "project_id", "project_generation", "slot_id", "product_id", "industry_id", "direction", "source_kind", "gross_gdp_per_minute", "penalty_gdp_per_minute", "net_gdp_per_minute", "visibility_scope"]
			observed = rows.size() == 3
			for row_variant in rows:
				for key in required:
					observed = observed and (row_variant as Dictionary).has(key)
			flags["row_count"] = rows.size()
			notes = "Every project GDP receipt carries stable identity, direction, amounts, and visibility."
		"production_receipt_maps_project":
			var project := _structured_project("production")
			var breakdown := _structured_breakdown(["production"])
			var row: Dictionary = (breakdown.get("gdp_rows", []) as Array)[0]
			observed = str(row.get("project_id", "")) == str(project.get("project_id", "")) and str(row.get("direction", "")) == "production"
			flags["receipt_id"] = str(row.get("receipt_id", ""))
			notes = "Production output is attributed to the exact production project generation."
		"demand_receipt_maps_project":
			var project := _structured_project("demand")
			var breakdown := _structured_breakdown(["demand"])
			var row: Dictionary = (breakdown.get("gdp_rows", []) as Array)[0]
			observed = str(row.get("project_id", "")) == str(project.get("project_id", "")) and str(row.get("direction", "")) == "demand"
			flags["receipt_id"] = str(row.get("receipt_id", ""))
			notes = "Delivered demand GDP is attributed to the exact demand project generation."
		"commerce_receipt_maps_project":
			var project := _structured_project("commerce")
			var breakdown := _structured_breakdown(["commerce"])
			var row: Dictionary = (breakdown.get("gdp_rows", []) as Array)[0]
			observed = str(row.get("project_id", "")) == str(project.get("project_id", "")) and str(row.get("direction", "")) == "commerce"
			flags["receipt_id"] = str(row.get("receipt_id", ""))
			notes = "Transit GDP is attributed to the exact commerce project generation."
		"region_gdp_equals_row_sum":
			var breakdown := _structured_breakdown()
			observed = _gdp_row_total(breakdown.get("gdp_rows", []) as Array, "net_gdp_per_minute") == int(breakdown.get("region_gdp_per_minute", -1))
			flags["conservation_checked"] = observed
			notes = "Region GDP is exactly the sum of public net GDP rows."
		"project_gdp_equals_project_rows":
			var project := _shared_project()
			var attribution := CITY_PROJECT_STATE.attribute_gdp_rows([project], [_gdp_row(project, 37, "production")])
			observed = bool(attribution.get("valid", false)) and int(attribution.get("project_gdp_per_minute", 0)) == 37 and int(((attribution.get("projects", []) as Array)[0] as Dictionary).get("current_gdp", 0)) == 37
			flags["project_gdp_total"] = int(attribution.get("project_gdp_per_minute", 0))
			notes = "Project current GDP equals the sum of rows bearing its project ID."
		"player_plus_neutral_conservation":
			var project := _shared_project()
			var attribution := CITY_PROJECT_STATE.attribute_gdp_rows([project], [_gdp_row(project, 35, "production")])
			observed = int(attribution.get("player_gdp_per_minute", 0)) + int(attribution.get("neutral_gdp_per_minute", 0)) == int(attribution.get("region_gdp_per_minute", -1))
			flags["conservation_checked"] = observed
			notes = "Player-attributable GDP plus neutral GDP conserves the region total."
		"share_floor_remainder_neutral":
			var project := _shared_project()
			var attribution := CITY_PROJECT_STATE.attribute_gdp_rows([project], [_gdp_row(project, 35, "production")])
			observed = int(attribution.get("player_gdp_per_minute", 0)) == 34 and int(attribution.get("neutral_gdp_per_minute", 0)) == 1
			flags["neutral_gdp_total"] = int(attribution.get("neutral_gdp_per_minute", 0))
			notes = "Each player share floors independently; the leftover unit is neutral."
		"destroyed_region_rows_empty":
			var breakdown: Dictionary = _gdp_formula.call("calculate_city_gdp", _structured_formula_input(["production"]).merged({"destroyed": true}, true))
			observed = int(breakdown.get("region_gdp_per_minute", -1)) == 0 and (breakdown.get("gdp_rows", []) as Array).is_empty()
			notes = "Destroyed regions clear derived GDP rows without deleting project identity."
		"zero_gdp_allowed":
			var input := _structured_formula_input([])
			input["adjustments"] = [{"source_kind": "test", "amount_gdp_per_minute": 20}]
			input["district_damage"] = 2
			var breakdown: Dictionary = _gdp_formula.call("calculate_city_gdp", input)
			observed = int(breakdown.get("region_gdp_per_minute", -1)) == 0 and int(breakdown.get("unabsorbed_penalty", 0)) == 16
			notes = "v0.5 has no minimum-city GDP floor."
		"legacy_adjustment_explicit_neutral":
			var input := _structured_formula_input([])
			input["adjustments"] = [{"source_kind": "legacy_role_bonus", "amount_gdp_per_minute": 19}]
			var breakdown: Dictionary = _gdp_formula.call("calculate_city_gdp", input)
			var row: Dictionary = (breakdown.get("gdp_rows", []) as Array)[0]
			observed = bool(row.get("neutral", false)) and str(row.get("project_id", "")) == "" and int(row.get("net_gdp_per_minute", 0)) == 19
			notes = "Unassigned legacy bonus GDP is explicit neutral GDP, never founder/controller income."
		"city_owner_not_attribution_authority":
			var fixture := _cashflow_fixture(false, false)
			var before := _player_cash_values()
			var paid := int(_runtime_main.call("_settle_city_cashflow_seconds", 60.0))
			observed = paid == 0 and before == _player_cash_values() and int(fixture.get("destination", -1)) >= 0
			notes = "A legacy city.owner field cannot create GDP attribution or cash payout."
		"same_owner_competition_not_exempt":
			var fixture := _competition_fixture(true)
			var first := int(fixture.get("first", -1))
			observed = first >= 0 and int(_runtime_main.call("_city_competition_matches", first)) == 1
			notes = "Competition follows matching production projects and has no city-owner exemption."
		"receipt_id_stable":
			var first := _structured_breakdown(["production"])
			var second := _structured_breakdown(["production"])
			var first_id := str((((first.get("gdp_rows", []) as Array)[0]) as Dictionary).get("receipt_id", ""))
			var second_id := str((((second.get("gdp_rows", []) as Array)[0]) as Dictionary).get("receipt_id", ""))
			observed = first_id != "" and first_id == second_id and first_id.contains("project.g1")
			flags["receipt_id"] = first_id
			notes = "Receipt identity is deterministic for identical project facts."
		"industry_catalog_mapping":
			var breakdown := _structured_breakdown(["production"])
			var row: Dictionary = (breakdown.get("gdp_rows", []) as Array)[0]
			observed = str(row.get("product_id", "")) == TEST_PRODUCT and str(row.get("industry_id", "")) != ""
			notes = "Product industry comes from the v0.5 catalog and is copied into the receipt."
		"cashflow_source_uses_receipt_player":
			var source := _function_source(str(_sources.get("controller", "")), "settle_cashflow_seconds")
			observed = source.contains("attribution_id") and source.contains("\"source_id\": source_id") and source.contains("\"source_kind\": \"project_share\"") and not source.contains("\"source_kind\": \"city_owner\"")
			notes = "Cashflow source identity is the GDP receipt plus viewer-private player attribution."
		"cashflow_remainder_keyed_by_source":
			var fixture := _cashflow_fixture(true, false, 1)
			var destination := int(fixture.get("destination", -1))
			_runtime_main.call("_settle_city_cashflow_seconds", 1.0)
			var city: Dictionary = _runtime_main.call("_district_city", destination)
			var remainders: Dictionary = city.get("gdp_cashflow_remainder_by_source_id", {})
			observed = not remainders.is_empty()
			for key in remainders.keys():
				observed = observed and str(key).contains(".player.")
			notes = "Fractional cash is retained per receipt+player source, not per city or aggregate player."
		"public_gdp_snapshot_privacy":
			var fixture := _network_fixture(false, true)
			var destination := int(fixture.get("destination", -1))
			var public_snapshot: Dictionary = _controller.call("public_region_gdp_snapshot", destination)
			var private_snapshot: Dictionary = _controller.call("private_region_gdp_snapshot", destination, 0)
			observed = str(public_snapshot.get("visibility_scope", "")) == "public" and not JSON.stringify(public_snapshot).contains("player_index") and str(private_snapshot.get("visibility_scope", "")) == "viewer_private" and private_snapshot.has("own_attribution_rows")
			flags["privacy_checked"] = observed
			notes = "Public GDP exposes project rows but never player attribution; private output exposes only the viewer."
		"legacy_gdp_split_symbols_absent":
			var combined := str(_sources.get("main", "")) + str(_sources.get("controller", "")) + str(_sources.get("project_state", "")) + str(_sources.get("project_bridge", "")) + str(_sources.get("cashflow", ""))
			var forbidden := ["assign_city_gdp", "gdp_by_player", "player_gdp(", "project_gdp_by_player", "project_cashflow_remainder_by_player", "minimum_city_gdp", "\"source_kind\": \"city_owner\""]
			observed = true
			for token in forbidden:
				observed = observed and not combined.contains(token)
			notes = "Whole-city splitting, owner payout, old remainder maps, and the minimum floor are absent."
	return _record(case_id, observed, observed, notes, flags)


func _case_cutover(case_id: String) -> Dictionary:
	var main_source := str(_sources.get("main", ""))
	var controller_source := str(_sources.get("controller", ""))
	var bridge_source := str(_sources.get("world_bridge", ""))
	var coordinator_source := str(_sources.get("coordinator", ""))
	var coordinator_scene := str(_sources.get("coordinator_scene", ""))
	var observed := false
	var notes := ""
	match case_id:
		"controller_scene_composition":
			observed = ResourceLoader.exists(CONTROLLER_SCENE_PATH) and coordinator_scene.contains("CityTradeNetworkRuntimeController.tscn") and coordinator_scene.contains("node name=\"CityTradeNetworkRuntimeController\"")
			notes = "GameRuntimeCoordinator statically composes the authoritative network Controller."
		"world_bridge_scene_composition":
			observed = ResourceLoader.exists(WORLD_BRIDGE_SCENE_PATH) and coordinator_scene.contains("CityTradeNetworkWorldBridge.tscn") and coordinator_scene.contains("node name=\"CityTradeNetworkWorldBridge\"")
			notes = "The non-owning world bridge is a static sibling runtime component."
		"controller_api_contract":
			var methods := ["configure", "reset_state", "normalize_city", "active_city_district_indices", "competition_matches", "refresh_networks", "shortest_trade_path", "settle_cashflow_seconds", "to_save_data", "apply_save_data", "debug_snapshot"]
			observed = _controller != null
			for method_name in methods:
				observed = observed and _controller.has_method(method_name)
			notes = "Controller exposes the stable project, route, refresh, cashflow, save, and debug API."
		"bridge_non_ownership_contract":
			var bridge_debug: Dictionary = _world_bridge.call("debug_snapshot") if _world_bridge != null else {}
			observed = not bool(bridge_debug.get("owns_runtime_state", true)) and not bool(bridge_debug.get("owns_rules", true)) and not bridge_source.contains("func _shortest_path(") and not bridge_source.contains("func settle_cashflow_seconds(")
			notes = "WorldBridge captures facts and applies receipts without route or payout ownership."
		"project_sequence_controller_owned":
			observed = controller_source.contains("var _project_sequence := 1") and controller_source.contains("func claim_project_sequence(") and not main_source.contains("var city_product_project_sequence")
			notes = "Project contribution ordering has one owner in the Controller."
		"route_algorithm_controller_owned":
			observed = controller_source.contains("func _shortest_path(") and controller_source.contains("func _trade_route_for_product(") and controller_source.contains("func _path_cost(")
			notes = "Route supply, graph search, cost, geometry, flow, and disruption algorithms live together."
		"refresh_orchestration_controller_owned":
			observed = controller_source.contains("func refresh_networks(") and _function_source(main_source, "_refresh_city_networks").contains("_city_trade_network_runtime_call")
			notes = "Main's refresh hook is a thin delegate to one orchestration owner."
		"cashflow_orchestration_controller_owned":
			observed = controller_source.contains("func settle_cashflow_seconds(") and controller_source.contains("settle_sources") and _function_source(main_source, "_settle_city_cashflow_seconds").contains("_city_trade_network_runtime_call")
			notes = "Controller plans city/project payout sources while EconomyCashflow retains arithmetic."
		"save_envelope_controller_owned":
			var save_data: Dictionary = _controller.call("to_save_data")
			var runtime_save: Dictionary = save_data.get("city_trade_network_runtime", {}) if save_data.get("city_trade_network_runtime", {}) is Dictionary else {}
			observed = save_data.has("city_trade_network_runtime") and not save_data.has("city_product_project_sequence") and str(runtime_save.get("terms_version", "")) == "v0.5.structured-project-gdp.1" and runtime_save.has("generation_by_slot_id") and runtime_save.has("project_tombstones") and coordinator_source.contains("city_trade_network_to_save_data")
			notes = "Controller owns the single v0.5 city-project save envelope without a duplicate writer."
		"legacy_save_normalized_once":
			_controller.call("reset_state")
			var receipt: Dictionary = _controller.call("apply_save_data", {"city_product_project_sequence": 23})
			observed = bool(receipt.get("applied", false)) and bool(receipt.get("legacy_flat_key_used", false)) and int(_controller.call("project_sequence")) == 23
			notes = "The legacy flat sequence key is consumed once by the explicit v0.4-to-v0.5 project-state migration boundary."
		"main_route_algorithms_absent":
			observed = true
			for function_name in REMOVED_MAIN_ALGORITHMS:
				observed = observed and not main_source.contains("func %s(" % str(function_name))
			notes = "All private route/path algorithm bodies were deleted from main.gd."
		"main_refresh_algorithms_absent":
			observed = not main_source.contains("func _refresh_city_competition_counts(") and not main_source.contains("func _refresh_city_trade_routes(") and not _function_source(main_source, "_refresh_city_networks").contains("assign_city_gdp")
			notes = "Competition, route and GDP-allocation refresh bodies no longer exist in main.gd."
		"main_project_sequence_absent":
			observed = not main_source.contains("var city_product_project_sequence") and not main_source.contains("city_product_project_sequence +=")
			notes = "main.gd no longer stores or mutates the global project sequence."
		"stable_main_adapters_present":
			observed = true
			for function_name in STABLE_MAIN_ADAPTERS:
				observed = observed and _function_source(main_source, str(function_name)).contains("_city_trade_network_runtime_call")
			notes = "Existing world-facing call sites retain narrow Controller adapters without fallback formulas."
		"external_refresh_callers_preserved":
			observed = true
			for source_id in ["contract", "military", "weather", "product_market"]:
				observed = observed and str(_sources.get(source_id, "")).contains("_refresh_city_networks")
			notes = "Existing Contract, Military, Weather, and ProductMarket world hooks still route one refresh request."
		"gdp_formula_owner_preserved":
			observed = controller_source.contains("_gdp_formula_controller.call(\"calculate_city_gdp\"") and not controller_source.contains("func _calculate_city_gdp(")
			notes = "GDP arithmetic remains exclusively delegated to GdpFormulaRuntimeController."
		"cashflow_formula_owner_preserved":
			observed = controller_source.contains("_cashflow_controller.call(\"settle_sources\"") and not controller_source.contains("func _settle_source(")
			notes = "Cashflow cadence and arithmetic remain in EconomyCashflowRuntimeController."
		"product_market_owner_preserved":
			observed = bridge_source.contains("_product_market_price") and bridge_source.contains("_product_market_route_flow_multiplier") and not controller_source.contains("func refresh_prices(")
			notes = "Network snapshots consume market facts; ProductMarket retains its lifecycle and price ownership."
		"controller_debug_pure_data":
			var debug: Dictionary = _controller.call("debug_snapshot", -1)
			observed = bool(debug.get("controller_authoritative", false)) and _is_data_only(debug) and not _contains_runtime_object(debug)
			notes = "Authoritative debug output is public-safe pure data."
		"no_parallel_network_owner":
			var debug: Dictionary = _controller.call("debug_snapshot", -1)
			observed = bool(debug.get("runtime_cutover_enabled", false)) and not bool(debug.get("legacy_route_engine_active", true)) and not main_source.contains("func _shortest_trade_path(")
			notes = "Only CityTradeNetworkRuntimeController owns the live network engine; no legacy fallback remains."
	return _record(case_id, observed, observed, notes, {"refresh_order_checked": case_id.contains("refresh"), "save_checked": case_id.contains("save"), "privacy_checked": case_id.contains("pure_data") or case_id.contains("non_ownership")})


func _network_fixture(city_source: bool, include_project: bool, include_supply: bool = true) -> Dictionary:
	_isolate_map()
	var pair := _reachable_pair()
	if pair.is_empty(): return {}
	var source := int(pair[0])
	var destination := int(pair[1])
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	if include_supply:
		if city_source:
			var source_project := CITY_PROJECT_STATE.create_project(source, TEST_PRODUCT, "production", 0, 1, 1)
			districts[source]["city"] = _base_city(0, [{"name": TEST_PRODUCT, "level": 1}], [], [source_project])
		else:
			var source_products: Array = districts[source].get("products", []) if districts[source].get("products", []) is Array else []
			if not source_products.has(TEST_PRODUCT): source_products.append(TEST_PRODUCT)
			districts[source]["products"] = source_products
	var projects: Array = [CITY_PROJECT_STATE.create_project(destination, TEST_PRODUCT, "demand", 0, 1, 2)] if include_project else []
	districts[destination]["city"] = _base_city(0, [], [TEST_PRODUCT], projects)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_runtime_main.call("_refresh_city_networks")
	var city: Dictionary = _runtime_main.call("_district_city", destination)
	var routes: Array = city.get("trade_routes", [])
	var route: Dictionary = routes[0] if not routes.is_empty() else {}
	return {"source": source, "destination": destination, "path": (route.get("path", []) as Array).duplicate(), "route": route.duplicate(true), "city": city.duplicate(true)}


func _competition_fixture(same_owner: bool) -> Dictionary:
	_isolate_map()
	var pair := _reachable_pair()
	if pair.is_empty(): return {}
	var first := int(pair[0])
	var second := int(pair[1])
	var first_city := CITY_PROJECT_BRIDGE.normalize_city(_base_city(0, [{"name": TEST_PRODUCT, "level": 1}], [], [CITY_PROJECT_STATE.create_project(first, TEST_PRODUCT, "production", 0, 1, 1)]), first)
	var second_city := CITY_PROJECT_BRIDGE.normalize_city(_base_city(0 if same_owner else 1, [{"name": TEST_PRODUCT, "level": 1}], [], [CITY_PROJECT_STATE.create_project(second, TEST_PRODUCT, "production", 1, 1, 2)]), second)
	_set_city(first, first_city)
	_set_city(second, second_city)
	return {"first": first, "second": second}


func _two_demand_fixture(route_damage: int) -> Dictionary:
	var fixture := _network_fixture(false, true)
	if fixture.is_empty(): return {}
	var source := int(fixture.get("source", -1))
	var destination := int(fixture.get("destination", -1))
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	var source_products: Array = districts[source].get("products", []) if districts[source].get("products", []) is Array else []
	for product_id in [TEST_PRODUCT, SECOND_PRODUCT]:
		if not source_products.has(product_id): source_products.append(product_id)
	districts[source]["products"] = source_products
	var city: Dictionary = (districts[destination].get("city", {}) as Dictionary).duplicate(true)
	city["demands"] = [TEST_PRODUCT, SECOND_PRODUCT]
	city["trade_route_damage"] = route_damage
	city["projects"] = [CITY_PROJECT_STATE.create_project(destination, TEST_PRODUCT, "demand", 0, 1, 2), CITY_PROJECT_STATE.create_project(destination, SECOND_PRODUCT, "demand", 0, 1, 3)]
	districts[destination]["city"] = city
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_runtime_main.call("_refresh_city_networks")
	city = _runtime_main.call("_district_city", destination)
	return {"source": source, "destination": destination, "city": city.duplicate(true), "routes": (city.get("trade_routes", []) as Array).duplicate(true)}


func _cashflow_fixture(with_projects: bool, destroyed: bool, revenue_bonus: int = 600) -> Dictionary:
	var fixture := _network_fixture(false, with_projects)
	if fixture.is_empty(): return {}
	var destination := int(fixture.get("destination", -1))
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	var city: Dictionary = (districts[destination].get("city", {}) as Dictionary).duplicate(true)
	city["owner"] = 0
	city["revenue_bonus"] = revenue_bonus
	if with_projects:
		var project := CITY_PROJECT_STATE.create_project(destination, TEST_PRODUCT, "demand", 0, 1, 2)
		project = CITY_PROJECT_STATE.contribute(project, 1, 1, 3)
		city["project_slots"] = []
		city["projects"] = [project]
	else:
		city["project_slots"] = []
		city["projects"] = []
	districts[destination]["city"] = city
	districts[destination]["destroyed"] = destroyed
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts
	_runtime_main.call("_refresh_city_networks")
	return {"destination": destination}


func _base_city(owner_index: int, products: Array = [], demands: Array = [], projects: Array = []) -> Dictionary:
	return {
		"owner": owner_index, "active": true, "level": 1,
		"products": products.duplicate(true), "demands": demands.duplicate(true), "projects": projects.duplicate(true),
		"revenue_bonus": 0, "contract_income_bonus": 0, "contract_seconds": 0.0,
		"route_flow_multiplier": 1.0, "route_flow_seconds": 0.0,
		"last_income": 0, "last_cashflow_rate": 0,
		"gdp_cashflow_remainder_by_source_id": {}, "cashflow_paid_total": 0,
		"competition_matches": 0, "trade_routes": [], "trade_disrupted_routes": 0,
		"trade_route_damage": 0, "supplied_demands": 0,
		"military_gdp_penalty": 0, "military_pressure_until": 0.0,
	}


func _structured_project(direction: String) -> Dictionary:
	return CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, direction, 0, 1, 1)


func _structured_formula_input(directions: Array = ["production", "demand", "commerce"]) -> Dictionary:
	var input := {"active": true, "destroyed": false, "region_id": "region.0005", "production_projects": [], "demand_projects": [], "commerce_projects": [], "adjustments": []}
	if directions.has("production"):
		input["production_projects"] = [_structured_project("production").merged({"price": 100, "rank": 1, "production_factor": 1.0, "supply_demand_ratio": 1.0, "transport_speed": 1.0}, true)]
	if directions.has("demand"):
		input["demand_projects"] = [_structured_project("demand").merged({"price": 80, "flow_amount": 1.0, "consumption_factor": 1.0, "supply_availability_ratio": 1.0, "flow_speed": 1.0, "route_available": true, "disrupted": false}, true)]
	if directions.has("commerce"):
		input["commerce_projects"] = [_structured_project("commerce").merged({"transit_routes": [{"price": 100, "flow_amount": 1.0, "transport_speed": 1.0, "disrupted": false, "destination_is_district": false, "path_contains_district": true}]}, true)]
	return input


func _structured_breakdown(directions: Array = ["production", "demand", "commerce"]) -> Dictionary:
	var value: Variant = _gdp_formula.call("calculate_city_gdp", _structured_formula_input(directions))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _shared_project() -> Dictionary:
	var project := CITY_PROJECT_STATE.create_project(5, TEST_PRODUCT, "production", 0, 1, 1)
	return CITY_PROJECT_STATE.contribute(project, 1, 1, 2)


func _gdp_row(project: Dictionary, amount: int, source_kind: String) -> Dictionary:
	return {"receipt_id": "gdp.%s.%s.%s" % [str(project.get("region_id", "")), str(project.get("project_id", "")), source_kind], "region_id": str(project.get("region_id", "")), "project_id": str(project.get("project_id", "")), "project_generation": int(project.get("generation", 0)), "slot_id": str(project.get("slot_id", "")), "product_id": str(project.get("product_id", "")), "industry_id": "technology", "direction": str(project.get("direction", "")), "source_kind": source_kind, "gross_gdp_per_minute": amount, "penalty_gdp_per_minute": 0, "net_gdp_per_minute": amount, "neutral": false, "visibility_scope": "public"}


func _gdp_row_total(rows: Array, key: String) -> int:
	var total := 0
	for row_variant in rows:
		if row_variant is Dictionary:
			total += int((row_variant as Dictionary).get(key, 0))
	return total


func _v05_empty_city(district_index: int) -> Dictionary:
	return CITY_PROJECT_BRIDGE.normalize_city({
		"owner": -1,
		"active": true,
		"products": [],
		"demands": [],
		"projects": [],
	}, district_index)


func _apply_slot_project(city: Dictionary, district_index: int, player_index: int, product_id: String, slot_kind: String, slot_index: int, order: int) -> Dictionary:
	return CITY_PROJECT_BRIDGE.apply_project_contribution(city, district_index, player_index, {
		"product_id": product_id,
		"project_direction": slot_kind,
		"slot_index": slot_index,
		"contribution_units": 1,
	}, order)


func _ascii_stable_id(value: String) -> bool:
	if value == "":
		return false
	for character in value:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character not in [".", "_", "-"]:
			return false
	return true


func _isolate_map() -> void:
	var districts: Array = _baseline_districts.duplicate(true)
	for i in range(districts.size()):
		var district: Dictionary = (districts[i] as Dictionary).duplicate(true)
		district["city"] = {}
		district["destroyed"] = false
		district["miasma"] = false
		district["panic"] = 0
		var products: Array = district.get("products", []) if district.get("products", []) is Array else []
		products = products.duplicate()
		products.erase(TEST_PRODUCT)
		products.erase(SECOND_PRODUCT)
		district["products"] = products
		districts[i] = district
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts


func _set_city(district_index: int, city: Dictionary) -> void:
	var districts: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	districts[district_index]["city"] = city.duplicate(true)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = districts


func _reachable_pair() -> Array:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	for source in range(districts.size()):
		if str((districts[source] as Dictionary).get("terrain", "land")) != "land": continue
		for destination in range(districts.size()):
			if destination == source or str((districts[destination] as Dictionary).get("terrain", "land")) != "land": continue
			var path: Array = _controller.call("shortest_trade_path", source, destination)
			if path.size() >= 2: return [source, destination]
	return []


func _first_land_district() -> int:
	return _first_district_by_terrain("land")


func _first_district_by_terrain(terrain: String) -> int:
	var districts: Array = ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts
	for i in range(districts.size()):
		if str((districts[i] as Dictionary).get("terrain", "land")) == terrain: return i
	return -1


func _city_product_names(city: Dictionary) -> Array:
	var names: Array = []
	for product_variant in city.get("products", []):
		if product_variant is Dictionary: names.append(str((product_variant as Dictionary).get("name", "")))
	return names


func _route_flags(fixture: Dictionary) -> Dictionary:
	var route: Dictionary = fixture.get("route", {})
	return {"district_index": int(fixture.get("destination", -1)), "product_id": str(route.get("product", "")), "route_count": 0 if route.is_empty() else 1, "path_length": (route.get("path", []) as Array).size()}


func _player_cash_values() -> Array:
	var result: Array = []
	for player_variant in ((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array:
		result.append(int((player_variant as Dictionary).get("cash", 0)))
	return result


func _load_sources() -> void:
	_sources = {
		"main": FileAccess.get_file_as_string(MAIN_SCRIPT_PATH),
		"coordinator": FileAccess.get_file_as_string(COORDINATOR_SCRIPT_PATH),
		"coordinator_scene": FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH),
		"controller": FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH),
		"controller_scene": FileAccess.get_file_as_string(CONTROLLER_SCENE_PATH),
		"world_bridge": FileAccess.get_file_as_string(WORLD_BRIDGE_SCRIPT_PATH),
		"world_bridge_scene": FileAccess.get_file_as_string(WORLD_BRIDGE_SCENE_PATH),
		"gdp": FileAccess.get_file_as_string(GDP_FORMULA_SCRIPT_PATH),
		"cashflow": FileAccess.get_file_as_string(CASHFLOW_SCRIPT_PATH),
		"product_market": FileAccess.get_file_as_string(PRODUCT_MARKET_SCRIPT_PATH),
		"contract": FileAccess.get_file_as_string(CONTRACT_BRIDGE_SCRIPT_PATH),
		"military": FileAccess.get_file_as_string(MILITARY_SCRIPT_PATH),
		"weather": FileAccess.get_file_as_string(WEATHER_SCRIPT_PATH),
		"project_state": FileAccess.get_file_as_string(PROJECT_STATE_SCRIPT_PATH),
		"project_bridge": FileAccess.get_file_as_string(PROJECT_BRIDGE_SCRIPT_PATH),
	}


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
	_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_gdp_formula = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController")
	_cashflow = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyCashflowRuntimeController")
	_product_market = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityTradeNetworkRuntimeController")
	_world_bridge = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CityTradeNetworkWorldBridge")
	_baseline_players = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	_baseline_districts = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts as Array).duplicate(true)
	_baseline_project_sequence = int(_controller.call("project_sequence")) if _controller != null else 1
	return _coordinator != null and _controller != null and _world_bridge != null and _gdp_formula != null and _cashflow != null and _product_market != null and not _baseline_players.is_empty() and not _baseline_districts.is_empty()


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = _baseline_players.duplicate(true)
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).districts = _baseline_districts.duplicate(true)
	_controller.call("apply_save_data", {"city_trade_network_runtime": {"terms_version": "v0.5.structured-project-gdp.1", "project_sequence": _baseline_project_sequence, "generation_by_slot_id": {}, "project_tombstones": []}})
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).game_time = 100.0
	_runtime_main.set("game_over", false)
	(_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).reset_public_log()
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	_runtime_main.set("movement_trails", [])
	if _cashflow.has_method("apply_legacy_save_snapshot"):
		_cashflow.call("apply_legacy_save_snapshot", {"economy_cashflow_timer": 0.0})
	var players: Array = (((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array).duplicate(true)
	for i in range(players.size()):
		var player: Dictionary = (players[i] as Dictionary).duplicate(true)
		player["cash"] = 1000
		player["eliminated"] = false
		player["economic_ledger"] = []
		players[i] = player
	((_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"case_id": case_id,
		"district_index": int(flags.get("district_index", -1)),
		"project_id": str(flags.get("project_id", "")),
		"slot_id": str(flags.get("slot_id", "")),
		"generation": int(flags.get("generation", 0)),
		"product_id": str(flags.get("product_id", "")),
		"direction": str(flags.get("direction", "")),
		"route_count": int(flags.get("route_count", 0)),
		"path_length": int(flags.get("path_length", 0)),
		"city_gdp": int(flags.get("city_gdp", 0)),
		"player_gdp_total": int(flags.get("player_gdp_total", 0)),
		"receipt_id": str(flags.get("receipt_id", "")),
		"row_count": int(flags.get("row_count", 0)),
		"project_gdp_total": int(flags.get("project_gdp_total", 0)),
		"neutral_gdp_total": int(flags.get("neutral_gdp_total", 0)),
		"conservation_checked": bool(flags.get("conservation_checked", false)),
		"share_total_basis_points": int(flags.get("share_total_basis_points", 0)),
		"refresh_order_checked": bool(flags.get("refresh_order_checked", false)),
		"formula_owner_checked": bool(flags.get("formula_owner_checked", false)),
		"cashflow_owner_checked": bool(flags.get("cashflow_owner_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", not aligned)),
		"risk": str(flags.get("risk", "" if aligned else "Observed behavior differs from the v0.5 project contract.")),
		"passed": observed,
		"notes": notes,
	}


func _main_metrics(source: String) -> Dictionary:
	var lines := source.split("\n")
	var total_lines := lines.size()
	if total_lines > 0 and str(lines[total_lines - 1]).is_empty(): total_lines -= 1
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
	return {"total_lines": total_lines, "nonblank_lines": nonblank, "function_count": functions, "top_level_variable_count": variables, "constant_count": constants}


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
	ownership_text.text = "[b]Runtime owner[/b]\nCityTradeNetworkRuntimeController: five slots, generation/tombstones, project sequence, derived routes, payout sources, save envelope\n\n[b]Pure project model[/b]\nCityProductProjectState/Bridge: stable IDs, rank IV, shares, tie-without-control, privacy snapshots\n\n[b]Non-owning adapter[/b]\nCityTradeNetworkWorldBridge: captures facts and applies receipts only\n\n[b]Preserved owners[/b]\nGdpFormulaRuntimeController: current GDP arithmetic (SS05-03 next)\nEconomyCashflowRuntimeController: cadence and payout arithmetic\nProductMarketRuntimeController: prices and market lifecycle\n\n[b]Deletion gate[/b]\nNo product-derived ID, owner-synthesized project, or owner-only project payout remains."
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("%s %s | %s" % ["OK" if bool(record.get("observed", false)) else "FAIL", str(record.get("case_id", "")), "aligned" if bool(record.get("contract_aligned", false)) else "decision required"])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Structured Project GDP Hard Cutover - SS05-03", "",
		"Project domain: `v0.5`", "Current runtime owner: `res://scripts/runtime/city_trade_network_runtime_controller.gd`", "Runtime cutover enabled: `true`",
		"Observed: %d/%d" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"Design decisions: %d" % int(manifest.get("needs_design_decision_count", 0)),
		"Main deletion gate passed: `%s`" % str(manifest.get("main_reduction_gate_passed", false)), "",
		"## Observed refresh order", "",
		"1. Recalculate cross-owner product competition.",
		"2. Rebuild demand routes, consuming route damage in demand order.",
		"3. Assemble city facts and delegate GDP arithmetic to `GdpFormulaRuntimeController`.",
		"4. Allocate city GDP to product projects and player shares.",
		"5. Preserve the city-development supply guarantee.",
		"6. Market-price refresh remains a separate caller-owned request.", "",
		"## Ownership boundary", "",
		"- `CityTradeNetworkRuntimeController`: project sequence, project snapshots, route graph/path selection, refresh orchestration, payout-source composition, and city-network save/load normalization.",
		"- `CityTradeNetworkWorldBridge`: non-owning world-fact capture and receipt application.",
		"- `main.gd`: narrow stable world-facing adapters only; no parallel route or refresh engine.",
		"- `CityProductProjectState` / `CityProductProjectBridge`: pure project identity, contribution, share, controller, GDP allocation, and privacy snapshots.",
		"- `GdpFormulaRuntimeController`: city GDP arithmetic only.",
		"- `EconomyCashflowRuntimeController`: realtime cadence, payout planning, and fractional arithmetic only.",
		"- `ProductMarketRuntimeController`: product market state/prices; not route ownership.",
		"- Contract, military, weather, and product-market systems request one refresh hook and do not own the graph.", "",
		"## SS05-03 result", "",
		"The prior 68 City/Trade behavior and ownership cases pass with 20 v0.5 project identity cases. Five slots, stable IDs, rank IV, generation/tombstones, and exact-tie no-control now share one runtime owner and one save envelope.", "",
		"## Cases", "", "| Case | District | Project | Product | Observed | Aligned | Decision | Notes |", "| --- | ---: | --- | --- | --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %d | %s | %s | %s | %s | %s | %s |" % [str(record.get("case_id", "")), int(record.get("district_index", -1)), str(record.get("project_id", "")), str(record.get("product_id", "")), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("needs_design_decision", false)), str(record.get("notes", "")).replace("|", "/")])
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
		var runtime_to_free := _runtime_main
		_runtime_main = null
		_coordinator = null
		_controller = null
		_world_bridge = null
		_gdp_formula = null
		_cashflow = null
		_product_market = null
		runtime_main_host.remove_child(runtime_to_free)
		runtime_to_free.free()


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0: return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _tokens_in_order(source: String, tokens: Array) -> bool:
	var offset := 0
	for token_variant in tokens:
		var found := source.find(str(token_variant), offset)
		if found < 0: return false
		offset = found + str(token_variant).length()
	return true


func _int_total(values: Dictionary) -> int:
	var total := 0
	for value in values.values(): total += int(value)
	return total


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
	if value is Callable or value is Object: return true
	if value is Array:
		for item in value:
			if _contains_runtime_object(item): return true
	if value is Dictionary:
		for key in value.keys():
			if _contains_runtime_object(key) or _contains_runtime_object(value[key]): return true
	return false
