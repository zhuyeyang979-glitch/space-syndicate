extends Control
class_name RegionInfrastructureRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v06.tres"
const ACTIVE_RULESET_SCENE_PATH := "res://scenes/runtime/RulesetRuntimeBridge.tscn"
const CARD_CATALOG_SCENE_PATH := "res://scenes/runtime/CardRuntimeCatalogService.tscn"
const SAVE_COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_save_runtime_coordinator.gd"
const HANDSHAKE_SCENE_PATH := "res://scenes/runtime/RulesetSaveHandshakeService.tscn"
const V06_CONTROLLER_REGISTRY_PATH := "res://resources/rules/controller_state_version_registry_v06.tres"
const CHARACTERIZATION_REGISTRY_SCRIPT_PATH := "res://scripts/tools/region_infrastructure_characterization_registry.gd"
const MONSTER_SCRIPT_PATH := "res://scripts/runtime/monster_runtime_controller.gd"
const MILITARY_SCRIPT_PATH := "res://scripts/runtime/military_runtime_controller.gd"
const CITY_DEVELOPMENT_SCRIPT_PATH := "res://scripts/runtime/city_development_runtime_controller.gd"
const CITY_TRADE_SCRIPT_PATH := "res://scripts/runtime/city_trade_network_runtime_controller.gd"
const PROJECT_STATE_SCRIPT_PATH := "res://scripts/economy/city_product_project_state.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/region_infrastructure_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/region_infrastructure_characterization_sprint_0.png"
const CASE_COUNT := 68
const FIXED_SEED := 600600

const CASE_IDS := [
	"v06_profile_loads", "v06_profile_identity", "facility_hp_contributions", "dynamic_victory_rules",
	"card_window_30_20_5_5", "ordinary_group_limit_one", "commodity_rank_rates", "commodity_belt_rules",
	"six_mana_rules", "monster_and_wager_rules", "player_and_ai_acceptance_range", "legacy_projects_disabled",
	"profile_snapshot_pure", "production_ruleset_bridge_still_v04", "production_card_catalog_still_v04", "production_save_version_still_v1",
	"schema_registry_complete", "schema_fields_complete", "schema_rejects_runtime_objects", "v06_profile_has_no_heat_state",
	"v06_schemas_have_no_heat_fields", "legacy_heat_sources_cataloged", "legacy_heat_deletion_gate_recorded", "main_sha_unchanged",
	"v1_recognized_legacy_v04", "v2_recognized_v05", "v1_cannot_resume_v06", "v2_cannot_resume_v06",
	"v06_envelope_valid", "v06_requires_new_session", "v06_controller_versions_complete", "v06_qa_roundtrip",
	"v04_cannot_overwrite_v06", "v05_cannot_overwrite_v06", "v06_cannot_overwrite_legacy", "unknown_save_rejected",
	"real_main_instantiates", "game_runtime_coordinator_present", "legacy_district_shape", "legacy_hp_is_authored",
	"legacy_damage_is_separate", "legacy_destroyed_flag", "legacy_city_state_shape", "five_project_slots_present",
	"project_shares_present", "legacy_route_damage_present", "legacy_warehouse_state_present", "district_damage_call_graph",
	"repair_call_graph", "build_call_graph", "upgrade_call_graph", "monster_damage_route",
	"military_damage_route", "non_unit_direct_damage_present", "global_barrage_direct_damage_present", "route_damage_writer_present",
	"area_derived_hp_present", "damage_order_observed", "destruction_order_observed", "warehouse_settlement_hook_present",
	"city_trade_refresh_hook_present", "product_market_refresh_hook_present", "current_save_keys_observed", "public_snapshot_boundary_observed",
	"privacy_boundary_observed", "characterization_payload_pure", "ss06_01_deletion_candidates_complete", "main_deletion_budget_recorded",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _coordinator: Node
var _baseline_districts: Array = []
var _records: Array = []
var _failures: Array[String] = []
var _sources: Dictionary = {}
var _profile: Resource
var _handshake: RulesetSaveHandshakeService


func _ready() -> void:
	print("RegionInfrastructureRuntimeCharacterizationBench SS06-00 ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
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
		"suite": "region-infrastructure-characterization-ss06-00",
		"ruleset_id": "v0.6",
		"runtime_cutover_enabled": false,
		"production_ruleset_id": "v0.4",
		"case_count": CASE_COUNT,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"main_baseline": RegionInfrastructureCharacterizationRegistry.MAIN_BASELINE.duplicate(true),
		"ss06_01_deletion_gate": RegionInfrastructureCharacterizationRegistry.SS06_01_DELETION_GATE.duplicate(true),
		"legacy_heat_deletion_gate": RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_DELETION_GATE.duplicate(true),
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_load_sources()
	_profile = load(PROFILE_PATH)
	var handshake_scene := load(HANDSHAKE_SCENE_PATH) as PackedScene
	_handshake = handshake_scene.instantiate() as RulesetSaveHandshakeService if handshake_scene != null else null
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("RegionInfrastructureRuntimeCharacterizationBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in CASE_IDS:
		var case_id := str(case_id_variant)
		var record := _evaluate_case(case_id)
		record["pure_data_checked"] = _is_pure_data(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var main_metrics := _main_metrics()
	var manifest := {
		"suite": "region-infrastructure-characterization-ss06-00",
		"ruleset_id": "v0.6",
		"runtime_cutover_enabled": false,
		"production_ruleset_id": "v0.4",
		"case_count": CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _count_flag("observed"),
		"aligned_count": _count_flag("contract_aligned"),
		"passed_count": _count_flag("passed"),
		"needs_design_decision_count": _count_flag("needs_design_decision"),
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"main_baseline": RegionInfrastructureCharacterizationRegistry.MAIN_BASELINE.duplicate(true),
		"main_metrics": main_metrics,
		"production_main_unchanged": str(main_metrics.get("sha256", "")) == str(RegionInfrastructureCharacterizationRegistry.MAIN_BASELINE.get("sha256", "")),
		"ss06_01_deletion_gate": RegionInfrastructureCharacterizationRegistry.SS06_01_DELETION_GATE.duplicate(true),
		"legacy_heat_deletion_gate": RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_DELETION_GATE.duplicate(true),
		"legacy_heat_ownership": RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_OWNERSHIP.duplicate(true),
		"deletion_candidates": RegionInfrastructureCharacterizationRegistry.MAIN_DELETION_CANDIDATES.duplicate(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("RegionInfrastructureRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("RegionInfrastructureRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("RegionInfrastructureRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("RegionInfrastructureRuntimeCharacterizationBench observed: %d/%d aligned=%d/%d passed=%d/%d" % [_count_flag("observed"), CASE_COUNT, _count_flag("contract_aligned"), CASE_COUNT, _count_flag("passed"), CASE_COUNT])
	if not _failures.is_empty():
		push_error("RegionInfrastructureRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _evaluate_case(case_id: String) -> Dictionary:
	var profile_snapshot: Dictionary = _profile.debug_snapshot() if _profile != null and _profile.has_method("debug_snapshot") else {}
	var profile_validation: Dictionary = RulesetV06Validator.validate(_profile)
	var infrastructure: Dictionary = profile_snapshot.get("infrastructure", {})
	var victory: Dictionary = profile_snapshot.get("victory", {})
	var card_group: Dictionary = profile_snapshot.get("card_group", {})
	var card_inventory: Dictionary = profile_snapshot.get("card_inventory", {})
	var commodity: Dictionary = profile_snapshot.get("commodity", {})
	var mana: Dictionary = profile_snapshot.get("mana", {})
	var monster: Dictionary = profile_snapshot.get("monster", {})
	var capabilities: Dictionary = profile_snapshot.get("capabilities", {})
	var main_source := str(_sources.get("main", ""))
	var first_district := _first_district()
	var first_city := _first_city()
	match case_id:
		"v06_profile_loads": return _record(case_id, _profile != null and bool(profile_validation.get("valid", false)), true, str(profile_validation.get("errors", [])))
		"v06_profile_identity": return _record(case_id, str(profile_snapshot.get("identity", {}).get("ruleset_id", "")) == "v0.6" and int(profile_snapshot.get("identity", {}).get("currency_scale", 0)) == 100, true, "Inspector profile is v0.6 schema 1 with integer cents.")
		"facility_hp_contributions": return _record(case_id, infrastructure.get("facility_hp_contribution_by_rank", {}) == {"I": 100, "II": 200, "III": 300, "IV": 400}, true, "Shared max HP contribution table is explicit.")
		"dynamic_victory_rules": return _record(case_id, int(victory.get("region_control_threshold_bp", 0)) == 3000 and int(victory.get("dynamic_victory_coverage_bp", 0)) == 4000 and int(victory.get("gdp_per_required_region_per_minute", 0)) == 36, true, "30% unique control, 40% coverage, 36 GDP/min per required region.")
		"card_window_30_20_5_5": return _record(case_id, int(card_group.get("group_seconds", 0)) == 30 and int(card_group.get("planning_seconds", 0)) == 20 and int(card_group.get("public_bid_seconds", 0)) == 5 and int(card_group.get("lock_seconds", 0)) == 5 and int(card_group.get("opening_extended_windows", 0)) == 3 and int(card_group.get("opening_group_seconds", 0)) == 45 and int(card_group.get("opening_planning_seconds", 0)) == 35, true, "v0.6 uses 30/20/5/5, with 45/35/5/5 for sequences 0-2.")
		"ordinary_group_limit_one": return _record(case_id, int(card_group.get("ordinary_card_limit", 0)) == 1 and int(card_group.get("maximum_with_explicit_capability", 0)) == 3, true, "v0.6 permits one ordinary card by default and at most three through an authoritative capability.")
		"commodity_rank_rates": return _record(case_id, card_inventory.get("commodity_rate_by_rank", {}) == {"I": 10, "II": 20, "III": 40, "IV": 80}, true, "Commodity rates are units/minute.")
		"commodity_belt_rules": return _record(case_id, int(commodity.get("commodity_belt_refresh_seconds", 0)) == 5 and int(commodity.get("leading_tier_minimum_visible_cards", 0)) == 3, true, "Five-second tier refresh and three-card leading minimum.")
		"six_mana_rules": return _record(case_id, int(mana.get("observation_window_seconds", 0)) == 30 and int(mana.get("per_color_maximum", 0)) == 100 and int(mana.get("gdp_per_minute_divisor", 0)) == 100, true, "Six private mana pools consume 30-second receipt observations.")
		"monster_and_wager_rules": return _record(case_id, int(monster.get("battle_limit_seconds", 0)) == 60 and int(monster.get("upgrade_delay_extension_seconds", 0)) == 60 and int(monster.get("wager_seconds", 0)) == 8 and int(monster.get("wager_standard_rate_bp", 0)) == 500, true, "Sixty-second battle, +60 upgrade delay, eight-second wager, standard 5% ante.")
		"player_and_ai_acceptance_range": return _record(case_id, int(profile_snapshot.get("validation", {}).get("minimum_player_count", 0)) == 3 and int(profile_snapshot.get("validation", {}).get("maximum_player_count", 0)) == 8 and int(profile_snapshot.get("validation", {}).get("minimum_ai_count_for_acceptance", 0)) == 2 and int(profile_snapshot.get("validation", {}).get("maximum_ai_count_for_acceptance", 0)) == 7, true, "Release acceptance includes 3/4/8 players and 2-7 AI.")
		"legacy_projects_disabled": return _record(case_id, not bool(capabilities.get("legacy_project_slots_enabled", true)) and not bool(capabilities.get("industry_capacity_reservations_enabled", true)), true, "v0.5 project and capacity ownership is retired by the authored v0.6 profile.")
		"profile_snapshot_pure": return _record(case_id, _is_pure_data(profile_snapshot), true, "No Resource or runtime object leaks from profile snapshots.")
		"production_ruleset_bridge_still_v04": return _record(case_id, str(_sources.get("active_ruleset_scene", "")).contains("space_syndicate_ruleset_v04.tres") and not str(_sources.get("active_ruleset_scene", "")).contains("space_syndicate_ruleset_v06.tres"), true, "Production bridge remains v0.4 during foundation work.")
		"production_card_catalog_still_v04": return _record(case_id, str(_sources.get("card_catalog_scene", "")).contains("card_runtime_catalog_v04.tres") and not str(_sources.get("card_catalog_scene", "")).contains("v06"), true, "Production card catalog remains v0.4.")
		"production_save_version_still_v1": return _record(case_id, str(_sources.get("save", "")).contains("const CURRENT_SAVE_VERSION := 1") and not main_source.contains("compose_v06_envelope"), true, "Passive handshake does not own production save writes.")
		"schema_registry_complete": return _record(case_id, RulesetV06SchemaRegistry.schema_ids().size() == 7, true, "Seven v0.6 wire schemas are frozen.")
		"schema_fields_complete": return _record(case_id, _schemas_have_required_fields(), true, "Region, Facility, Installation, Route, SaleReceipt, Mana, and Belt schemas declare required fields.")
		"schema_rejects_runtime_objects": return _record(case_id, not bool(RulesetV06SchemaRegistry.validate_payload("region", {"region_id": "qa", "node": self}).get("valid", true)), true, "Runtime objects fail closed.")
		"v06_profile_has_no_heat_state": return _record(case_id, not _contains_legacy_heat_terms(profile_snapshot), true, "The v0.6 profile has no heat or panic capability/state.")
		"v06_schemas_have_no_heat_fields": return _record(case_id, not _contains_legacy_heat_terms(RulesetV06SchemaRegistry.debug_snapshot()), true, "No v0.6 wire/save schema carries heat or panic.")
		"legacy_heat_sources_cataloged": return _record(case_id, RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_OWNERSHIP.size() >= 6 and _legacy_heat_card_resource_count() > 0 and main_source.contains("panic"), false, "Legacy v0.4 heat remains in runtime, presentation, cards, and fixtures and is explicitly inventoried for deletion.")
		"legacy_heat_deletion_gate_recorded": return _record(case_id, not bool(RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_DELETION_GATE.get("v06_heat_state_allowed", true)) and not bool(RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_DELETION_GATE.get("player_visible_heat_label_allowed", true)) and bool(RegionInfrastructureCharacterizationRegistry.LEGACY_HEAT_DELETION_GATE.get("delete_with_region_cutover", false)), true, "SS06-01 must remove the state, scoring, direct damage, player text, and legacy card semantics together.")
		"main_sha_unchanged": return _record(case_id, _main_metrics().get("sha256", "") == RegionInfrastructureCharacterizationRegistry.MAIN_BASELINE.get("sha256", ""), true, "SS06-00 adds no algorithm to main.gd.")
		"v1_recognized_legacy_v04": return _save_case(case_id)
		"v2_recognized_v05": return _save_case(case_id)
		"v1_cannot_resume_v06": return _save_case(case_id)
		"v2_cannot_resume_v06": return _save_case(case_id)
		"v06_envelope_valid": return _save_case(case_id)
		"v06_requires_new_session": return _save_case(case_id)
		"v06_controller_versions_complete": return _save_case(case_id)
		"v06_qa_roundtrip": return _save_case(case_id)
		"v04_cannot_overwrite_v06": return _save_case(case_id)
		"v05_cannot_overwrite_v06": return _save_case(case_id)
		"v06_cannot_overwrite_legacy": return _save_case(case_id)
		"unknown_save_rejected": return _save_case(case_id)
		"real_main_instantiates": return _record(case_id, _runtime_main != null and _runtime_main.scene_file_path == MAIN_SCENE_PATH and not _baseline_districts.is_empty(), false, "Real main.tscn supplies the characterization world.")
		"game_runtime_coordinator_present": return _record(case_id, _coordinator != null and _coordinator.scene_file_path == COORDINATOR_SCENE_PATH, false, "Real GameRuntimeCoordinator is present; no v0.6 infrastructure owner exists yet.")
		"legacy_district_shape": return _record(case_id, _has_keys(first_district, ["hp", "damage", "destroyed", "city"]), false, "Legacy district embeds HP, damage, destruction, and city state.")
		"legacy_hp_is_authored": return _record(case_id, int(first_district.get("hp", 0)) > 0, false, "Legacy max HP is an authored district scalar.")
		"legacy_damage_is_separate": return _record(case_id, first_district.has("damage") and int(first_district.get("damage", -1)) >= 0, false, "Legacy damage is a second independently writable scalar.")
		"legacy_destroyed_flag": return _record(case_id, first_district.has("destroyed") and first_district.get("destroyed") is bool, false, "Legacy destroyed flag is stored directly.")
		"legacy_city_state_shape": return _record(case_id, first_district.get("city", null) is Dictionary and _source_contains_all(str(_sources.get("city_development", "")), ["\"active\": true", "\"products\": []", "\"demands\": []"]), false, "Legacy district embeds a city dictionary; the existing city factory owns active/products/demands fields.")
		"five_project_slots_present": return _record(case_id, _source_contains_all(str(_sources.get("city_development", "")), ["production", "demand", "commerce", "project_slots"]), false, "Five project slots remain v0.5 migration evidence.")
		"project_shares_present": return _record(case_id, main_source.contains("_city_has_project_shares") and _source_contains_all(str(_sources.get("project_state", "")), ["contribution_by_player", "share_basis_points_by_player", "controller_player_index"]), false, "The v0.5 project state still owns contribution-derived basis-point shares and control.")
		"legacy_route_damage_present": return _record(case_id, main_source.contains("trade_route_damage") and str(_sources.get("city_trade", "")).contains("trade_route_damage"), false, "Abstract route damage remains a writable legacy field.")
		"legacy_warehouse_state_present": return _record(case_id, main_source.contains("warehouse_stockpile") and main_source.contains("settle_destroyed_warehouse"), false, "Warehouse state is still embedded in city/project surfaces.")
		"district_damage_call_graph": return _record(case_id, _source_contains_all(_function_source(main_source, "_damage_district"), ["d[\"damage\"] += amount", "d[\"destroyed\"] = true", "_refresh_city_networks()"]), false, "One main function owns mutation, lifecycle, settlement, and refresh.")
		"repair_call_graph": return _record(case_id, _function_source(main_source, "_repair_district").contains("d[\"damage\"] -= repaired"), false, "main.gd directly mutates legacy repair state.")
		"build_call_graph": return _record(case_id, main_source.contains("_evaluate_city_development_request") and str(_sources.get("city_development", "")).contains("plan_settlement"), false, "v0.5 build routing exists but targets project/city state.")
		"upgrade_call_graph": return _record(case_id, _source_contains_all(str(_sources.get("project_state", "")), ["static func contribute", "current_rank + 1", "MAX_PROJECT_RANK"]) and main_source.contains("_rebuild_city_development_runtime_cards"), false, "Project contributions still advance rank while main rebuilds the legacy development-card supply.")
		"monster_damage_route": return _record(case_id, _source_contains_all(str(_sources.get("monster", "")), ["func _damage_district", "_world_call(&\"_damage_district\""]), false, "Monster is a valid future damage requester but currently calls main mutation.")
		"military_damage_route": return _record(case_id, _source_contains_all(str(_sources.get("military", "")), ["_world_call(&\"_damage_district\"", "_world_call(&\"_repair_district\""]), false, "Military requests legacy main damage and repair callbacks.")
		"non_unit_direct_damage_present": return _record(case_id, main_source.contains("_damage_district(index, 1, \"%s") and main_source.contains("func _apply_global_barrage"), false, "Non-unit direct HP paths must be retired in SS06-01.")
		"global_barrage_direct_damage_present": return _record(case_id, _function_source(main_source, "_apply_global_barrage").contains("_damage_district("), false, "Global barrage violates v0.6 unit-only damage ownership.")
		"route_damage_writer_present": return _record(case_id, main_source.count("trade_route_damage\"] =") > 0, false, "main.gd still directly writes abstract route damage.")
		"area_derived_hp_present": return _record(case_id, _function_source(main_source, "_generate_roguelike_districts").contains("ceil(area_m2 / 26000.0)"), false, "Legacy HP derives from map area rather than active facilities.")
		"damage_order_observed": return _record(case_id, _tokens_in_order(_function_source(main_source, "_damage_district"), ["d[\"damage\"] += amount", "d[\"last_damage_source\"]", "d[\"panic\"]", "if d[\"damage\"] >= d[\"hp\"]"]), false, "Damage, metadata, panic, then destruction check.")
		"destruction_order_observed": return _record(case_id, _tokens_in_order(_function_source(main_source, "_damage_district"), ["d[\"destroyed\"] = true", "_apply_trade_disruption_from_destroyed_district", "_product_market_settle_destroyed_warehouse", "city[\"active\"] = false", "_refresh_city_networks()"]), false, "Legacy destruction ordering is frozen for migration receipts.")
		"warehouse_settlement_hook_present": return _record(case_id, _function_source(main_source, "_damage_district").contains("_product_market_settle_destroyed_warehouse"), false, "Warehouse settlement consumes legacy destruction inside main.")
		"city_trade_refresh_hook_present": return _record(case_id, _source_contains_all(_function_source(main_source, "_damage_district"), ["_apply_trade_disruption_from_destroyed_district", "_refresh_city_networks"]), false, "Trade refresh is coupled to main lifecycle mutation.")
		"product_market_refresh_hook_present": return _record(case_id, _function_source(main_source, "_damage_district").contains("_product_market_settle_destroyed_warehouse"), false, "Product market settlement is a post-lifecycle consumer candidate.")
		"current_save_keys_observed": return _record(case_id, _source_contains_all(str(_sources.get("save", "")) + main_source, ["districts", "cities"]), false, "Legacy save persists district/city envelopes rather than v0.6 facilities and damage_taken.")
		"public_snapshot_boundary_observed": return _record(case_id, main_source.contains("_runtime_selected_district_snapshot_source") and main_source.contains("hp_now"), false, "Public surface derives legacy hp_now from hp-damage.")
		"privacy_boundary_observed": return _record(case_id, not RulesetV06SchemaRegistry.schema_snapshot("commodity_sale_receipt").get("required", []).has("owner_name") and RulesetV06SchemaRegistry.schema_snapshot("commodity_belt_visibility").get("forbidden", []).has("ai_private_plan"), true, "v0.6 schemas prevent private plan and human-readable owner leakage.")
		"characterization_payload_pure": return _record(case_id, _is_pure_data(_legacy_shape_summary(first_district, first_city)) and _is_pure_data(RegionInfrastructureCharacterizationRegistry.debug_snapshot()), true, "The report uses a sanitized shape summary; Vector2/Color world values never enter the manifest.")
		"ss06_01_deletion_candidates_complete": return _record(case_id, _existing_deletion_candidate_count(main_source) >= 20 and RegionInfrastructureCharacterizationRegistry.deletion_candidate_count() >= 24, true, "At least 24 named candidates are frozen; no wrapper farm is permitted.")
		"main_deletion_budget_recorded": return _record(case_id, int(RegionInfrastructureCharacterizationRegistry.SS06_01_DELETION_GATE.get("minimum_nonblank_lines_removed", 0)) >= 700 and int(RegionInfrastructureCharacterizationRegistry.SS06_01_DELETION_GATE.get("minimum_functions_removed", 0)) >= 24 and int(RegionInfrastructureCharacterizationRegistry.SS06_01_DELETION_GATE.get("maximum_region_infrastructure_adapter_lines", 999)) <= 180, true, "SS06-01 must hard-cut over and delete old ownership in one commit.")
	return _record(case_id, false, false, "Unknown case")


func _save_case(case_id: String) -> Dictionary:
	if _handshake == null:
		return _record(case_id, false, true, "Handshake scene missing")
	var v1 := {"save_version": 1, "players": []}
	var v2 := _handshake.compose_v05_envelope({"session_id": "qa-v05"}, {"qa": true})
	var v3 := _handshake.compose_v06_envelope({"session_id": "qa-v06", "new_session": true}, {"qa": true})
	match case_id:
		"v1_recognized_legacy_v04":
			var result := _handshake.inspect_envelope(v1, "v0.6")
			return _record(case_id, bool(result.get("recognized", false)) and str(result.get("classification", "")) == "legacy_v04", true, str(result))
		"v2_recognized_v05":
			var result := _handshake.inspect_envelope(v2, "v0.6")
			return _record(case_id, bool(result.get("recognized", false)) and str(result.get("classification", "")) == "v05", true, str(result))
		"v1_cannot_resume_v06":
			var result := _handshake.inspect_envelope(v1, "v0.6")
			return _record(case_id, not bool(result.get("can_resume", true)) and bool(result.get("requires_backup", false)), true, str(result.get("reason", "")))
		"v2_cannot_resume_v06":
			var result := _handshake.inspect_envelope(v2, "v0.6")
			return _record(case_id, not bool(result.get("can_resume", true)) and bool(result.get("requires_backup", false)), true, str(result.get("reason", "")))
		"v06_envelope_valid": return _record(case_id, bool(_handshake.validate_v06_envelope(v3).get("valid", false)), true, str(_handshake.validate_v06_envelope(v3).get("errors", [])))
		"v06_requires_new_session": return _record(case_id, str(v3.get("migration_policy", "")) == "new_session_only" and bool(v3.get("session", {}).get("new_session", false)), true, "No project/facility inference from old sessions.")
		"v06_controller_versions_complete":
			var registry := load(V06_CONTROLLER_REGISTRY_PATH) as ControllerStateVersionRegistryResource
			return _record(case_id, registry != null and bool(registry.validation_snapshot().get("valid", false)) and registry.required_versions().size() == 16, true, "Sixteen future domain state versions are explicit.")
		"v06_qa_roundtrip":
			var parsed: Variant = JSON.parse_string(JSON.stringify(v3))
			return _record(case_id, parsed is Dictionary and bool(_handshake.validate_v06_envelope(parsed).get("valid", false)), true, "Pure JSON round-trip.")
		"v04_cannot_overwrite_v06": return _record(case_id, not bool(_handshake.write_authorization({"save_version": 3, "ruleset_id": "v0.6"}, {"save_version": 1}).get("allowed", true)), true, "v0.4 downgrade is rejected.")
		"v05_cannot_overwrite_v06": return _record(case_id, not bool(_handshake.write_authorization({"save_version": 3, "ruleset_id": "v0.6"}, {"save_version": 2, "ruleset_id": "v0.5"}).get("allowed", true)), true, "v0.5 cannot overwrite v0.6.")
		"v06_cannot_overwrite_legacy": return _record(case_id, not bool(_handshake.write_authorization({"save_version": 1}, {"save_version": 3, "ruleset_id": "v0.6"}).get("allowed", true)), true, "v0.6 cannot overwrite legacy player saves.")
		"unknown_save_rejected": return _record(case_id, not bool(_handshake.inspect_envelope({"save_version": 99, "ruleset_id": "future"}, "v0.6").get("recognized", true)), true, "Unknown envelope fails closed.")
	return _record(case_id, false, true, "Unknown save case")


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
	_disable_runtime_audio()
	var runtime_rng := _runtime_main.get("rng") as RandomNumberGenerator
	if runtime_rng != null:
		runtime_rng.seed = FIXED_SEED
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_baseline_districts = (_runtime_main.get("districts") as Array).duplicate(true)
	return _coordinator != null and not _baseline_districts.is_empty()


func _first_district() -> Dictionary:
	for district_variant in _baseline_districts:
		if district_variant is Dictionary:
			return (district_variant as Dictionary).duplicate(true)
	return {}


func _first_city() -> Dictionary:
	for district_variant in _baseline_districts:
		if district_variant is Dictionary and (district_variant as Dictionary).get("city", null) is Dictionary:
			var city: Dictionary = (district_variant as Dictionary).get("city", {})
			if not city.is_empty():
				return city.duplicate(true)
	return {}


func _load_sources() -> void:
	_sources = {
		"main": FileAccess.get_file_as_string(MAIN_SCRIPT_PATH),
		"active_ruleset_scene": FileAccess.get_file_as_string(ACTIVE_RULESET_SCENE_PATH),
		"card_catalog_scene": FileAccess.get_file_as_string(CARD_CATALOG_SCENE_PATH),
		"save": FileAccess.get_file_as_string(SAVE_COORDINATOR_SCRIPT_PATH),
		"coordinator_scene": FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH),
		"monster": FileAccess.get_file_as_string(MONSTER_SCRIPT_PATH),
		"military": FileAccess.get_file_as_string(MILITARY_SCRIPT_PATH),
		"city_development": FileAccess.get_file_as_string(CITY_DEVELOPMENT_SCRIPT_PATH),
		"city_trade": FileAccess.get_file_as_string(CITY_TRADE_SCRIPT_PATH),
		"project_state": FileAccess.get_file_as_string(PROJECT_STATE_SCRIPT_PATH),
	}


func _legacy_shape_summary(district: Dictionary, city: Dictionary) -> Dictionary:
	return {
		"district_present": not district.is_empty(),
		"has_hp": district.has("hp"),
		"has_damage": district.has("damage"),
		"has_destroyed": district.has("destroyed"),
		"has_city_dictionary": district.get("city", null) is Dictionary,
		"city_present": not city.is_empty(),
		"city_active": bool(city.get("active", false)) if not city.is_empty() else false,
		"project_slot_count": int((city.get("project_slots", []) as Array).size()) if city.get("project_slots", []) is Array else 0,
	}


func _schemas_have_required_fields() -> bool:
	for schema_id in RulesetV06SchemaRegistry.schema_ids():
		var schema := RulesetV06SchemaRegistry.schema_snapshot(schema_id)
		if (schema.get("required", []) as Array).is_empty() or (schema.get("types", {}) as Dictionary).is_empty():
			return false
	return true


func _existing_deletion_candidate_count(source: String) -> int:
	var count := 0
	for symbol_variant in RegionInfrastructureCharacterizationRegistry.MAIN_DELETION_CANDIDATES:
		if source.contains("func %s(" % str(symbol_variant)):
			count += 1
	return count


func _record(case_id: String, observed: bool, aligned: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"scope": _case_scope(case_id),
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": false,
		"main_symbol_count": RegionInfrastructureCharacterizationRegistry.deletion_candidate_count(),
		"deletion_owner": "SS06-01 RegionInfrastructureRuntimeController",
		"pure_data_checked": false,
		"passed": false,
		"risk": "high" if not aligned and _case_scope(case_id) == "legacy_runtime" else "low",
		"notes": notes,
	}


func _case_scope(case_id: String) -> String:
	var index := CASE_IDS.find(case_id)
	if index < 24:
		return "foundation"
	if index < 36:
		return "save_handshake"
	return "legacy_runtime"


func _contains_legacy_heat_terms(value: Variant) -> bool:
	var serialized := JSON.stringify(value).to_lower()
	return serialized.contains("\"heat") or serialized.contains("panic") or serialized.contains("热度")


func _legacy_heat_card_resource_count() -> int:
	var count := 0
	var dir := DirAccess.open("res://resources/cards/runtime/families")
	if dir == null:
		return count
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var source := FileAccess.get_file_as_string("res://resources/cards/runtime/families/%s" % file_name)
			if source.contains("热度") or source.contains("\"news_category\": \"heat\"") or source.contains("\"panic\""):
				count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


func _has_keys(value: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		if not value.has(str(key_variant)):
			return false
	return true


func _source_contains_all(source: String, tokens: Array) -> bool:
	for token_variant in tokens:
		if not source.contains(str(token_variant)):
			return false
	return true


func _tokens_in_order(source: String, tokens: Array) -> bool:
	var cursor := 0
	for token_variant in tokens:
		var found := source.find(str(token_variant), cursor)
		if found < 0:
			return false
		cursor = found + str(token_variant).length()
	return true


func _function_source(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _main_metrics() -> Dictionary:
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var lines := source.split("\n", true)
	if not lines.is_empty() and lines[-1].is_empty():
		lines.remove_at(lines.size() - 1)
	var nonblank := 0
	var functions := 0
	for line in lines:
		if not line.strip_edges().is_empty():
			nonblank += 1
		if line.begins_with("func "):
			functions += 1
	return {"sha256": source.sha256_text().to_upper(), "total_lines": lines.size(), "nonblank_lines": nonblank, "function_count": functions}


func _count_flag(field: String) -> int:
	var count := 0
	for record_variant in _records:
		if bool((record_variant as Dictionary).get(field, false)):
			count += 1
	return count


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _is_pure_data(value[key]):
				return false
		return true
	return false


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# SS06-00 Region Infrastructure Characterization",
		"",
		"- Observed: %d/%d" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"- Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"- Production cutover active: no",
		"- main.gd unchanged: %s" % str(manifest.get("production_main_unchanged", false)),
		"- SS06-01 deletion gate: >=700 nonblank lines, >=24 functions, <=180 adapter lines",
		"",
		"| Case | Scope | Observed | Aligned | Notes |",
		"| --- | --- | --- | --- | --- |",
	]
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("scope", "")), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "SS06-00  %d / %d observed" % [int(manifest.get("observed_count", 0)), CASE_COUNT]
	status_label.text = "BASELINE FROZEN" if _failures.is_empty() else "REVIEW REQUIRED"
	status_label.modulate = Color("7ddf9b") if _failures.is_empty() else Color("ff8f83")
	ownership_text.text = "[b]Current owner[/b]\nmain.gd legacy hp/damage/destroyed\n\n[b]Next atomic owner[/b]\nRegionInfrastructureRuntimeController\n\n[b]Deletion gate[/b]\n>=700 nonblank lines\n>=24 functions\n<=180 main adapter lines\nNo parallel fallback"
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("[color=%s]%s[/color]  %s" % ["#7ddf9b" if bool(record.get("passed", false)) else "#ff8f83", "OBS" if bool(record.get("observed", false)) else "FAIL", str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


func _hide_runtime_canvas_layers() -> void:
	if _runtime_main == null:
		return
	for node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false


func _disable_runtime_audio() -> void:
	if _runtime_main == null:
		return
	for node in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()


func _release_runtime_main() -> void:
	if _handshake != null:
		_handshake.free()
		_handshake = null
	if _runtime_main != null:
		_runtime_main.queue_free()
		_runtime_main = null
	_coordinator = null
	_baseline_districts.clear()
	_profile = null
	_sources.clear()
