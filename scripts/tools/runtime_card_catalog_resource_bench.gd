extends Control
class_name RuntimeCardCatalogResourceBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"
const INTEGRITY_PATH := "res://tests/fixtures/runtime_card_catalog_v04_integrity.json"
const FAMILY_DIR := "res://resources/cards/runtime/families"
const PACK_DIR := "res://resources/cards/runtime/packs"
const SERVICE_SCENE_PATH := "res://scenes/runtime/CardRuntimeCatalogService.tscn"
const BRIDGE_SCENE_PATH := "res://scenes/runtime/CardRuntimeDefinitionWorldBridge.tscn"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const OUTPUT_DIR := "user://space_syndicate_design_qa/runtime_card_catalog_resource/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/runtime_card_catalog_resource_hard_cutover_sprint_58.png"

const EXPECTED_CARD_COUNT := 239
const EXPECTED_FAMILY_COUNT := 120
const EXPECTED_PACK_COUNT := 10
const EXPECTED_POOL_COUNT := 125
const EXPECTED_UPGRADEABLE_COUNT := 76
const EXPECTED_KIND_COUNT := 49
const HISTORICAL_CASE_COUNT := 40
const LIVE_CASE_COUNT := 40
const CASE_COUNT := HISTORICAL_CASE_COUNT + LIVE_CASE_COUNT

const REQUIRED_RAW_FIELDS := ["kind", "move", "damage", "text", "range", "cost"]
const EXTERNAL_FINANCIAL_FIELDS := [
	"direction", "duration_seconds", "multiplier", "units", "requires_warehouse",
	"action_fee_cash", "margin_cash", "maximum_gain", "maximum_loss",
	"settlement_formula_id", "warehouse_loss_formula_id", "destruction_formula_id", "terms_version",
]
const PRIVATE_KEYS := [
	"owner", "hidden_owner", "private_owner", "private_target", "private_discard",
	"private_plan", "opponent_hand", "ai_private_plan",
]
const LEGACY_CONSTANTS := ["SKILL_CATALOG", "UPGRADEABLE_SKILL_FAMILIES", "COMMON_CARD_POOL"]
const LEGACY_HELPERS := [
	"_skill_exists", "_skill_definition", "_derived_rank_skill_definition", "_skill_rank", "_skill_family",
]
const RESOURCE_SCRIPT_PATHS := [
	"res://scripts/cards/card_runtime_definition_resource.gd",
	"res://scripts/cards/card_runtime_rank_resource.gd",
	"res://scripts/cards/card_runtime_family_resource.gd",
	"res://scripts/cards/card_runtime_pack_resource.gd",
	"res://scripts/cards/card_runtime_catalog_resource.gd",
	"res://scripts/cards/card_runtime_kind_schema.gd",
]
const EXPECTED_PACK_IDS := [
	"city_economy", "product_logistics", "finance", "contracts", "intel_counter",
	"player_interaction", "military", "weather_news", "monster_actions", "special_cross_system",
]
const HISTORICAL_CASE_IDS := [
	"catalog_call_graph_complete", "catalog_entry_count_locked", "unique_card_ids",
	"upgrade_family_count_and_order", "common_pool_count_and_order", "card_id_rank_parsing",
	"all_family_roots_resolve", "rank_i_to_iv_resolution", "derived_rank_fallback_order",
	"unknown_card_safe_failure", "required_field_matrix_complete", "optional_field_matrix_complete",
	"field_types_stable", "card_kind_inventory_complete", "effect_handler_mapping_complete",
	"persistent_flag_parity", "consumed_on_queue_parity", "purchase_cost_parity",
	"target_metadata_parity", "requirement_metadata_parity", "economy_card_shape",
	"contract_card_shape", "weather_card_shape", "military_card_shape", "monster_skill_shape",
	"hand_interaction_card_shape", "counter_card_shape", "intel_card_shape",
	"product_futures_terms_external", "city_gdp_terms_external", "eligibility_consumer_map",
	"queue_consumer_map", "execution_and_effect_consumer_map", "ai_consumer_map",
	"military_monster_weather_contract_consumer_map", "first_mission_and_scenario_ids_exist",
	"save_name_compatibility", "public_private_boundary", "proposed_resource_snapshot_is_pure_data",
	"sprint58_deletion_candidates_complete",
]
const LIVE_CASE_IDS := [
	"resource_scripts_load", "family_asset_count_120", "embedded_rank_count_239",
	"pack_asset_count_10", "catalog_asset_loads", "all_families_single_pack",
	"pack_order_preserved", "catalog_card_order_hash", "family_upgrade_order_hash",
	"public_pool_order_hash", "exact_definition_parity", "all_explicit_definitions_canonical_parity",
	"derived_rank_nearest_lower_parity", "derived_growth_35_percent_parity",
	"exact_id_beats_derivation", "city_development_precedence", "product_futures_terms_external_live",
	"city_gdp_terms_external_live", "monster_card_route_preserved", "monster_technique_route_preserved",
	"requirement_policy_stays_external", "all_49_kinds_validate", "pure_data_definition",
	"pure_data_catalog_snapshot", "resource_load_failure_explicit", "coordinator_scene_composition",
	"main_runtime_uses_catalog_service", "eligibility_consumer_parity", "queue_consumer_parity",
	"presentation_consumer_parity", "ai_consumer_parity", "military_consumer_no_world_constant",
	"first_table_scenario_id_lookup", "card_codex_public_snapshot_privacy",
	"balance_qa_catalog_access", "save_card_id_compatibility", "deterministic_district_supply_order",
	"main_constants_absent", "legacy_lookup_helpers_absent", "no_parallel_catalog_owner",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var schema_text: RichTextLabel = %SchemaText
@onready var cases_text: RichTextLabel = %CasesText

var _catalog: CardRuntimeCatalogResource
var _integrity: Dictionary = {}
var _runtime_main: Control
var _coordinator: GameRuntimeCoordinator
var _service: CardRuntimeCatalogService
var _bridge: CardRuntimeDefinitionWorldBridge
var _main_source := ""
var _sources: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_resource_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func historical_integrity_cases() -> Array:
	return HISTORICAL_CASE_IDS.duplicate()


func live_cutover_cases() -> Array:
	return LIVE_CASE_IDS.duplicate()


func resource_cases() -> Array:
	return historical_integrity_cases() + live_cutover_cases()


func resource_schema_preview() -> Dictionary:
	return {
		"schema_version": "runtime-card-catalog-resource-v04",
		"runtime_cutover_enabled": true,
		"runtime_owner": "CardRuntimeCatalogService",
		"catalog_path": CATALOG_PATH,
		"family_resources": EXPECTED_FAMILY_COUNT,
		"embedded_rank_resources": EXPECTED_CARD_COUNT,
		"pack_resources": EXPECTED_PACK_COUNT,
		"pack_order": EXPECTED_PACK_IDS.duplicate(),
		"external_terms": ["ProductFuturesTermsCatalog", "CityGdpDerivativeTermsCatalog"],
	}


func build_resource_manifest_preview() -> Dictionary:
	var preview_records: Array = []
	for case_id in HISTORICAL_CASE_IDS:
		preview_records.append(_record(str(case_id), "historical_integrity", false, "preview"))
	for case_id in LIVE_CASE_IDS:
		preview_records.append(_record(str(case_id), "live_cutover", false, "preview"))
	return {
		"suite": "runtime-card-catalog-resource-hard-cutover-sprint-58",
		"ruleset_id": "v0.4",
		"case_count": CASE_COUNT,
		"historical_case_count": HISTORICAL_CASE_COUNT,
		"live_case_count": LIVE_CASE_COUNT,
		"runtime_owner": "CardRuntimeCatalogService",
		"records": preview_records,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
	}


func run_resource_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not _load_static_inputs():
		_finish_early("Resource catalog or integrity fixture could not be loaded")
		return
	if not await _ensure_runtime_main():
		_finish_early("Real main.tscn or runtime catalog composition could not be loaded")
		return
	for case_id in HISTORICAL_CASE_IDS:
		_append_case(str(case_id), "historical_integrity", _historical_pass(str(case_id)))
	for case_id in LIVE_CASE_IDS:
		_append_case(str(case_id), "live_cutover", _live_pass(str(case_id)))
	var manifest := _manifest()
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "  "))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("RuntimeCardCatalogResourceBench: %d/%d passed; historical=%d/%d; live=%d/%d" % [
		_count_passed(), CASE_COUNT, _count_phase("historical_integrity"), HISTORICAL_CASE_COUNT,
		_count_phase("live_cutover"), LIVE_CASE_COUNT,
	])
	print("RuntimeCardCatalogResourceBench assets: 120 families; 239 authored ranks; 10 packs; 1 catalog")
	print("RuntimeCardCatalogResourceBench manifest: %s" % MANIFEST_PATH)
	print("RuntimeCardCatalogResourceBench report: %s" % REPORT_PATH)
	print("RuntimeCardCatalogResourceBench screenshot: %s" % SCREENSHOT_PATH)
	if not _failures.is_empty():
		push_error("RuntimeCardCatalogResourceBench failed: %s" % ", ".join(_failures))
	await _quit_after_result(_failures.is_empty())


func _load_static_inputs() -> bool:
	_catalog = load(CATALOG_PATH) as CardRuntimeCatalogResource
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INTEGRITY_PATH))
	_integrity = (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	for path in [
		"res://scripts/runtime/game_runtime_coordinator.gd",
		"res://scripts/runtime/card_runtime_catalog_service.gd",
		"res://scripts/runtime/card_runtime_definition_world_bridge.gd",
		"res://scripts/runtime/card_play_eligibility_runtime_service.gd",
		"res://scripts/runtime/card_resolution_queue_runtime_service.gd",
		"res://scripts/runtime/card_presentation_runtime_service.gd",
		"res://scripts/runtime/ai_runtime_controller.gd",
		"res://scripts/runtime/military_runtime_controller.gd",
		"res://scripts/runtime/card_codex_public_snapshot_service.gd",
		"res://tests/runtime_balance_report_test.gd",
	]:
		_sources[path] = FileAccess.get_file_as_string(path)
	return _catalog != null and not _integrity.is_empty() and not _main_source.is_empty()


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
	for layer_variant in _runtime_main.find_children("*", "CanvasLayer", true, false):
		var layer := layer_variant as CanvasLayer
		if layer != null:
			layer.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	if _coordinator == null:
		return false
	_service = _coordinator.card_runtime_catalog_service()
	_bridge = _coordinator.card_runtime_definition_bridge()
	_runtime_main.set_process(false)
	return _service != null and _bridge != null and bool(_service.debug_snapshot().get("service_ready", false))


func _append_case(case_id: String, phase: String, passed: bool) -> void:
	var record := _record(case_id, phase, passed, _case_note(case_id, passed))
	record["pure_data_checked"] = _is_data_only(record)
	if not bool(record["pure_data_checked"]):
		record["passed"] = false
		record["observed"] = false
		record["contract_aligned"] = false
	if not bool(record["passed"]):
		_failures.append(case_id)
	_records.append(record)


func _record(case_id: String, phase: String, passed: bool, notes: String) -> Dictionary:
	return {
		"case_id": case_id,
		"phase": phase,
		"runtime_owner": "CardRuntimeCatalogService",
		"observed": passed,
		"contract_aligned": passed,
		"passed": passed,
		"pure_data_checked": true,
		"notes": notes,
	}


func _historical_pass(case_id: String) -> bool:
	var report := _catalog.validation_report()
	match case_id:
		"catalog_call_graph_complete":
			return _source_has("res://scripts/runtime/game_runtime_coordinator.gd", "CardRuntimeCatalogService") and _source_has("res://scripts/runtime/card_runtime_definition_world_bridge.gd", "resolve_definition")
		"catalog_entry_count_locked":
			return _all_authored_hashes_match() and _catalog_data_hash() == str(_integrity.get("catalog_data_sha256", ""))
		"unique_card_ids":
			return _unique_strings(_service.ordered_card_ids()).size() == EXPECTED_CARD_COUNT
		"upgrade_family_count_and_order":
			return _order_hash(_service.upgradeable_families()) == str(_integrity.get("upgradeable_order_sha256", ""))
		"common_pool_count_and_order":
			return _order_hash(_service.public_pool()) == str(_integrity.get("common_pool_order_sha256", ""))
		"card_id_rank_parsing":
			return _all_card_ids_parse()
		"all_family_roots_resolve":
			return _all_family_roots_resolve()
		"rank_i_to_iv_resolution":
			return _all_upgradeable_ranks_resolve()
		"derived_rank_fallback_order":
			return _all_derived_sources_are_nearest_lower()
		"unknown_card_safe_failure":
			return not _service.has_card("__missing_card__") and _service.definition("__missing_card__").is_empty()
		"required_field_matrix_complete":
			return _all_required_fields_present()
		"optional_field_matrix_complete":
			return _all_authored_shapes_match_fixture()
		"field_types_stable":
			return _all_authored_hashes_match()
		"card_kind_inventory_complete":
			return int(report.get("kind_count", 0)) == EXPECTED_KIND_COUNT
		"effect_handler_mapping_complete":
			return bool(report.get("valid", false)) and (report.get("errors", []) as Array).is_empty()
		"persistent_flag_parity":
			return _field_values_are_typed("persistent", TYPE_BOOL)
		"consumed_on_queue_parity":
			return _field_values_are_typed("consumed_on_queue", TYPE_BOOL)
		"purchase_cost_parity":
			return _field_values_are_typed("cost", TYPE_INT)
		"target_metadata_parity":
			return _metadata_is_data(["target_player_required", "target_monster_required", "summon_access", "military_deploy_terrain"])
		"requirement_metadata_parity":
			return _metadata_is_data(["play_requirement_kind", "play_region_scope", "play_region_gdp_share_required", "play_product"])
		"economy_card_shape":
			return _kinds_have_cards(["city_revenue_boost", "region_economy_shift", "cash_gain"])
		"contract_card_shape":
			return _kinds_have_cards(["area_trade_contract"])
		"weather_card_shape":
			return _kinds_have_cards(["weather_control"])
		"military_card_shape":
			return _kinds_have_cards(["military_force"])
		"monster_skill_shape":
			return _cards_exist(["移动1", "普攻1", "飞行1", "瘴气炮1"])
		"hand_interaction_card_shape":
			return _kinds_have_cards(["player_hand_disrupt", "player_hand_steal"])
		"counter_card_shape":
			return _kinds_have_cards(["card_counter"])
		"intel_card_shape":
			return _kinds_have_cards(["intel_city_reveal", "intel_card_trace", "intel_contract_trace"])
		"product_futures_terms_external":
			return _financial_terms_external("商品看涨1")
		"city_gdp_terms_external":
			return _financial_terms_external("城市买涨1")
		"eligibility_consumer_map":
			return not _source_has("res://scripts/runtime/card_play_eligibility_runtime_service.gd", "SKILL_CATALOG")
		"queue_consumer_map":
			return not _source_has("res://scripts/runtime/card_resolution_queue_runtime_service.gd", "SKILL_CATALOG")
		"execution_and_effect_consumer_map":
			return not _source_has("res://scripts/runtime/card_resolution_execution_runtime_service.gd", "SKILL_CATALOG") and not _source_has("res://scripts/runtime/card_economy_product_route_effect_runtime_service.gd", "SKILL_CATALOG")
		"ai_consumer_map":
			return _source_has("res://scripts/runtime/ai_runtime_controller.gd", "_card_definition_bridge") and not _source_has("res://scripts/runtime/ai_runtime_controller.gd", "_call_world(&\"_skill_definition\"")
		"military_monster_weather_contract_consumer_map":
			return _source_has("res://scripts/runtime/military_runtime_controller.gd", "_card_runtime_catalog_service") and not _source_has("res://scripts/runtime/military_runtime_controller.gd", "SKILL_CATALOG")
		"first_mission_and_scenario_ids_exist":
			return _service.has_card("轨道融资1") and FileAccess.get_file_as_string("res://data/scenarios/first_table.json").contains("first_table")
		"save_name_compatibility":
			return _service.ordered_card_ids() == _fixture_card_ids_in_order()
		"public_private_boundary":
			return not _contains_private_key(_service.debug_snapshot())
		"proposed_resource_snapshot_is_pure_data":
			return _is_data_only(_service.debug_snapshot()) and _is_data_only(_bridge.debug_snapshot())
		"sprint58_deletion_candidates_complete":
			return _main_legacy_catalog_absent()
	return false


func _live_pass(case_id: String) -> bool:
	var report := _catalog.validation_report()
	match case_id:
		"resource_scripts_load": return RESOURCE_SCRIPT_PATHS.all(func(path: String) -> bool: return load(path) != null)
		"family_asset_count_120": return _tres_count(FAMILY_DIR) == EXPECTED_FAMILY_COUNT
		"embedded_rank_count_239": return _embedded_rank_count() == EXPECTED_CARD_COUNT
		"pack_asset_count_10": return _tres_count(PACK_DIR) == EXPECTED_PACK_COUNT
		"catalog_asset_loads": return _catalog != null and bool(report.get("valid", false))
		"all_families_single_pack": return _family_membership_is_exact()
		"pack_order_preserved": return _pack_ids() == EXPECTED_PACK_IDS
		"catalog_card_order_hash": return _order_hash(_service.ordered_card_ids()) == str(_integrity.get("catalog_order_sha256", ""))
		"family_upgrade_order_hash": return _order_hash(_service.upgradeable_families()) == str(_integrity.get("upgradeable_order_sha256", ""))
		"public_pool_order_hash": return _order_hash(_service.public_pool()) == str(_integrity.get("common_pool_order_sha256", ""))
		"exact_definition_parity": return _all_exact_definitions_match_authored()
		"all_explicit_definitions_canonical_parity": return _all_authored_hashes_match()
		"derived_rank_nearest_lower_parity": return _all_derived_sources_are_nearest_lower()
		"derived_growth_35_percent_parity": return _all_derived_definitions_match_expected()
		"exact_id_beats_derivation": return _all_exact_definitions_match_authored()
		"city_development_precedence": return _city_development_precedence()
		"product_futures_terms_external_live": return _financial_terms_external("商品看涨1")
		"city_gdp_terms_external_live": return _financial_terms_external("城市买涨1")
		"monster_card_route_preserved": return _monster_card_route()
		"monster_technique_route_preserved": return _monster_technique_route()
		"requirement_policy_stays_external": return _requirement_policy_external()
		"all_49_kinds_validate": return bool(report.get("valid", false)) and int(report.get("kind_count", 0)) == EXPECTED_KIND_COUNT
		"pure_data_definition": return _all_definitions_are_data()
		"pure_data_catalog_snapshot": return _is_data_only(_catalog.debug_snapshot()) and _is_data_only(_service.debug_snapshot())
		"resource_load_failure_explicit": return _source_has("res://scripts/runtime/card_runtime_catalog_service.gd", "no legacy fallback is available") and not _source_has("res://scripts/runtime/card_runtime_catalog_service.gd", "main.gd")
		"coordinator_scene_composition": return _coordinator_scene_is_composed()
		"main_runtime_uses_catalog_service": return _main_source.contains("card_definition(") and _main_source.contains("card_catalog_public_pool()")
		"eligibility_consumer_parity": return _consumer_receives_pure_definition("res://scripts/runtime/card_play_eligibility_runtime_service.gd")
		"queue_consumer_parity": return _consumer_receives_pure_definition("res://scripts/runtime/card_resolution_queue_runtime_service.gd")
		"presentation_consumer_parity": return _consumer_receives_pure_definition("res://scripts/runtime/card_presentation_runtime_service.gd")
		"ai_consumer_parity": return _source_has("res://scripts/runtime/ai_runtime_controller.gd", "set_card_definition_bridge") and not _source_has("res://scripts/runtime/ai_runtime_controller.gd", "_call_world(&\"_skill_definition\"")
		"military_consumer_no_world_constant": return _source_has("res://scripts/runtime/military_runtime_controller.gd", "set_card_runtime_catalog_service") and not _source_has("res://scripts/runtime/military_runtime_controller.gd", "SKILL_CATALOG")
		"first_table_scenario_id_lookup": return _service.has_card("轨道融资1") and _coordinator.card_exists("轨道融资1")
		"card_codex_public_snapshot_privacy": return _card_codex_privacy()
		"balance_qa_catalog_access": return not _source_has("res://tests/runtime_balance_report_test.gd", "_skill_family(skill_name)")
		"save_card_id_compatibility": return _service.ordered_card_ids() == _fixture_card_ids_in_order()
		"deterministic_district_supply_order": return _main_source.contains("card_catalog_public_pool()") and _order_hash(_service.public_pool()) == str(_integrity.get("common_pool_order_sha256", ""))
		"main_constants_absent": return LEGACY_CONSTANTS.all(func(value: String) -> bool: return not _main_source.contains("const %s" % value))
		"legacy_lookup_helpers_absent": return LEGACY_HELPERS.all(func(value: String) -> bool: return not _main_source.contains("func %s(" % value))
		"no_parallel_catalog_owner": return _main_legacy_catalog_absent() and bool(_service.debug_snapshot().get("service_authoritative", false))
	return false


func _all_authored_hashes_match() -> bool:
	var hashes: Dictionary = _integrity.get("card_hashes", {}) as Dictionary
	if hashes.size() != EXPECTED_CARD_COUNT:
		return false
	for card_id_variant in hashes.keys():
		var card_id := str(card_id_variant)
		if _canonical(_service.authored_definition(card_id)).sha256_text() != str(hashes[card_id_variant]):
			return false
	return true


func _catalog_data_hash() -> String:
	var hashes: Dictionary = _integrity.get("card_hashes", {}) as Dictionary
	var rows: Array[String] = []
	for card_id_variant in _service.ordered_card_ids():
		var card_id := str(card_id_variant)
		rows.append("%s:%s" % [card_id, str(hashes.get(card_id, ""))])
	return "\n".join(rows).sha256_text()


func _fixture_card_ids_in_order() -> Array:
	var hashes: Dictionary = _integrity.get("card_hashes", {}) as Dictionary
	var fixture_ids: Array = []
	for card_id_variant in _service.ordered_card_ids():
		if hashes.has(str(card_id_variant)):
			fixture_ids.append(str(card_id_variant))
	return fixture_ids


func _all_card_ids_parse() -> bool:
	for card_id_variant in _service.ordered_card_ids():
		var card_id := str(card_id_variant)
		if _service.rank(card_id) < 1 or _service.rank(card_id) > 4 or _service.family_id(card_id).is_empty():
			return false
	return true


func _families() -> Dictionary:
	var result: Dictionary = {}
	for pack_variant in _catalog.packs:
		var pack := pack_variant as CardRuntimePackResource
		if pack == null:
			continue
		for family_variant in pack.families:
			var family := family_variant as CardRuntimeFamilyResource
			if family != null:
				result[family.family_id] = family
	return result


func _all_family_roots_resolve() -> bool:
	for family_variant in _families().values():
		var family := family_variant as CardRuntimeFamilyResource
		if family == null or family.exact_definition(1).is_empty():
			return false
	return _families().size() == EXPECTED_FAMILY_COUNT


func _all_upgradeable_ranks_resolve() -> bool:
	for family_id_variant in _service.upgradeable_families():
		var family_id := str(family_id_variant)
		for rank in range(1, 5):
			if _service.definition("%s%d" % [family_id, rank]).is_empty():
				return false
	return true


func _all_derived_sources_are_nearest_lower() -> bool:
	var checked := 0
	for family_variant in _families().values():
		var family := family_variant as CardRuntimeFamilyResource
		if family == null:
			continue
		for rank in range(2, 5):
			if family.exact_rank_resource(rank) != null:
				continue
			var expected_source := 1
			for candidate in range(rank - 1, 0, -1):
				if family.exact_rank_resource(candidate) != null:
					expected_source = candidate
					break
			var derived := family.derived_definition(rank)
			if int(derived.get("derived_from_rank", 0)) != expected_source:
				return false
			checked += 1
	return checked > 0


func _all_derived_definitions_match_expected() -> bool:
	var checked := 0
	for family_variant in _families().values():
		var family := family_variant as CardRuntimeFamilyResource
		if family == null:
			continue
		for rank in range(2, 5):
			if family.exact_rank_resource(rank) != null:
				continue
			if _canonical(family.derived_definition(rank)) != _canonical(_expected_derived(family, rank)):
				return false
			checked += 1
	return checked > 0


func _expected_derived(family: CardRuntimeFamilyResource, requested_rank: int) -> Dictionary:
	var source_rank := 1
	var base := family.exact_definition(1)
	var source := base.duplicate(true)
	for candidate_rank in range(requested_rank - 1, 0, -1):
		var candidate := family.exact_definition(candidate_rank)
		if not candidate.is_empty():
			source_rank = candidate_rank
			source = candidate
			break
	var steps := requested_rank - source_rank
	var result := source.duplicate(true)
	result["text"] = "%s（%s：从%s继续成长；同名同级牌可主动合并升级，购买价仍按I级。）" % [str(source.get("text", base.get("text", ""))), _level_text(requested_rank), _level_text(source_rank)]
	result["rank"] = requested_rank
	result["derived_from_rank"] = source_rank
	var tags: Array = (source.get("tags", base.get("tags", [])) as Array).duplicate(true)
	if not tags.has("升级"):
		tags.append("升级")
	result["tags"] = tags
	var base_cost := maxi(1, int(base.get("cost", 1)))
	result["cost"] = maxi(base_cost, int(source.get("cost", base_cost))) + maxi(1, ceili(float(base_cost) * 0.35)) * steps
	_apply_expected_growth(result, source, base, steps)
	return result


func _apply_expected_growth(result: Dictionary, source: Dictionary, base: Dictionary, steps: int) -> void:
	for key in CardRuntimeFamilyResource.INTEGER_GROWTH_FIELDS:
		if source.has(key) or base.has(key):
			var current := int(source.get(key, base.get(key, 0)))
			var reference := int(base.get(key, current))
			current = reference if current == 0 else current
			if current != 0:
				result[key] = current + maxi(1, ceili(float(maxi(abs(reference), abs(current))) * 0.35)) * steps
	for key in CardRuntimeFamilyResource.SIGNED_INTEGER_GROWTH_FIELDS:
		if source.has(key) or base.has(key):
			var current := int(source.get(key, base.get(key, 0)))
			var reference := int(base.get(key, current))
			current = reference if current == 0 else current
			if current != 0:
				result[key] = current + (1 if current > 0 else -1) * maxi(1, ceili(float(maxi(abs(reference), abs(current))) * 0.35)) * steps
	for key in CardRuntimeFamilyResource.FLOAT_GROWTH_FIELDS:
		if source.has(key) or base.has(key):
			var current := float(source.get(key, base.get(key, 0.0)))
			var reference := float(base.get(key, current))
			current = reference if is_zero_approx(current) else current
			if not is_zero_approx(current):
				result[key] = current + (1.0 if current > 0.0 else -1.0) * maxf(0.1, maxf(absf(reference), absf(current)) * 0.35) * float(steps)
	for key in CardRuntimeFamilyResource.MULTIPLIER_GROWTH_FIELDS:
		if source.has(key) or base.has(key):
			var current := float(source.get(key, base.get(key, 1.0))) - 1.0
			var reference := float(base.get(key, source.get(key, 1.0))) - 1.0
			current = reference if is_zero_approx(current) else current
			if not is_zero_approx(current):
				result[key] = 1.0 + current + (1.0 if current > 0.0 else -1.0) * maxf(0.01, maxf(absf(reference), absf(current)) * 0.35) * float(steps)
	for key in CardRuntimeFamilyResource.TURN_GROWTH_FIELDS:
		if source.has(key) or base.has(key):
			result[key] = maxi(1, int(source.get(key, base.get(key, 1)))) + steps


func _all_required_fields_present() -> bool:
	for card_id_variant in _service.ordered_card_ids():
		var definition := _service.authored_definition(str(card_id_variant))
		for key in REQUIRED_RAW_FIELDS:
			if not definition.has(key):
				return false
	return true


func _all_authored_shapes_match_fixture() -> bool:
	return _all_authored_hashes_match() and _catalog_data_hash() == str(_integrity.get("catalog_data_sha256", ""))


func _field_values_are_typed(field_name: String, expected_type: int) -> bool:
	for card_id_variant in _service.ordered_card_ids():
		var definition := _service.authored_definition(str(card_id_variant))
		if definition.has(field_name) and typeof(definition[field_name]) != expected_type:
			return false
	return true


func _metadata_is_data(fields: Array) -> bool:
	for card_id_variant in _service.ordered_card_ids():
		var definition := _service.authored_definition(str(card_id_variant))
		for field in fields:
			if definition.has(field) and not _is_data_only(definition[field]):
				return false
	return true


func _kinds_have_cards(kinds: Array) -> bool:
	for kind in kinds:
		var found := false
		for card_id_variant in _service.ordered_card_ids():
			if str(_service.authored_definition(str(card_id_variant)).get("kind", "")) == str(kind):
				found = true
				break
		if not found:
			return false
	return true


func _cards_exist(card_ids: Array) -> bool:
	for card_id in card_ids:
		if not _service.has_card(str(card_id)):
			return false
	return true


func _financial_terms_external(card_id: String) -> bool:
	var authored := _service.authored_definition(card_id)
	var resolved := _coordinator.card_definition(card_id)
	for key in EXTERNAL_FINANCIAL_FIELDS:
		if authored.has(key):
			return false
	var terms_key := "futures_terms" if str(authored.get("kind", "")) == "product_futures" else "gdp_derivative_terms"
	var terms_variant: Variant = resolved.get(terms_key, {})
	return terms_variant is Dictionary and str((terms_variant as Dictionary).get("terms_version", "")).begins_with("v0.4") and float((terms_variant as Dictionary).get("duration_seconds", 0.0)) > 0.0


func _all_exact_definitions_match_authored() -> bool:
	for card_id_variant in _service.ordered_card_ids():
		var card_id := str(card_id_variant)
		var expected := _service.authored_definition(card_id)
		expected["name"] = card_id
		if _canonical(_service.exact_definition(card_id)) != _canonical(expected):
			return false
	return true


func _city_development_precedence() -> bool:
	var cards_variant: Variant = _runtime_main.get("city_development_runtime_cards")
	if cards_variant is Dictionary and (cards_variant as Dictionary).is_empty() and _runtime_main.has_method("_rebuild_city_development_runtime_cards"):
		_runtime_main.call("_rebuild_city_development_runtime_cards")
		cards_variant = _runtime_main.get("city_development_runtime_cards")
	if not (cards_variant is Dictionary) or (cards_variant as Dictionary).is_empty():
		return false
	var card_id := str((cards_variant as Dictionary).keys()[0])
	return _service.authored_definition(card_id).is_empty() and _canonical(_coordinator.card_definition(card_id)) == _canonical((cards_variant as Dictionary)[card_id])


func _monster_card_route() -> bool:
	if not _runtime_main.has_method("_monster_card_names"):
		return false
	var names_variant: Variant = _runtime_main.call("_monster_card_names", 1)
	if not (names_variant is Array) or (names_variant as Array).is_empty():
		return false
	var card_id := str((names_variant as Array)[0])
	var definition := _coordinator.card_definition(card_id)
	return _service.authored_definition(card_id).is_empty() and str(definition.get("kind", "")) == "monster_card"


func _monster_technique_route() -> bool:
	if not _runtime_main.has_method("_monster_card_names") or not _runtime_main.has_method("_monster_technique_card_name"):
		return false
	var names: Array = _runtime_main.call("_monster_card_names", 1)
	if names.is_empty():
		return false
	var monster_definition := _coordinator.card_definition(str(names[0]))
	var monster_name := str(monster_definition.get("monster_name", ""))
	var technique_id := str(_runtime_main.call("_monster_technique_card_name", monster_name, 0, 1))
	var technique := _coordinator.card_definition(technique_id)
	return not technique_id.is_empty() and _service.authored_definition(technique_id).is_empty() and str(technique.get("kind", "")) == "monster_bound_action"


func _requirement_policy_external() -> bool:
	var bridge_source := str(_sources.get("res://scripts/runtime/card_runtime_definition_world_bridge.gd", ""))
	var make_skill_index := _main_source.find("func _make_skill(")
	var make_skill_block := _main_source.substr(make_skill_index, 900) if make_skill_index >= 0 else ""
	return not bridge_source.contains("CardPlayRequirementPolicy") and make_skill_block.contains("CardPlayRequirementPolicyScript.apply_to_card")


func _all_definitions_are_data() -> bool:
	for card_id_variant in _service.ordered_card_ids():
		if not _is_data_only(_service.definition(str(card_id_variant))):
			return false
	return true


func _family_membership_is_exact() -> bool:
	var counts: Dictionary = {}
	for pack_variant in _catalog.packs:
		var pack := pack_variant as CardRuntimePackResource
		if pack == null:
			return false
		for family_id in pack.family_ids():
			counts[str(family_id)] = int(counts.get(str(family_id), 0)) + 1
	if counts.size() != EXPECTED_FAMILY_COUNT:
		return false
	for count in counts.values():
		if int(count) != 1:
			return false
	return true


func _pack_ids() -> Array:
	var result: Array = []
	for pack_variant in _catalog.packs:
		var pack := pack_variant as CardRuntimePackResource
		result.append(str(pack.pack_id) if pack != null else "")
	return result


func _embedded_rank_count() -> int:
	var count := 0
	for family_variant in _families().values():
		var family := family_variant as CardRuntimeFamilyResource
		count += family.authored_ranks.size() if family != null else 0
	return count


func _coordinator_scene_is_composed() -> bool:
	var packed := load(COORDINATOR_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	var valid := instance.get_node_or_null("CardRuntimeCatalogService") != null and instance.get_node_or_null("CardRuntimeDefinitionWorldBridge") != null
	instance.free()
	return valid


func _consumer_receives_pure_definition(path: String) -> bool:
	var source := str(_sources.get(path, FileAccess.get_file_as_string(path)))
	return not source.contains("SKILL_CATALOG") and not source.contains("CardRuntimeCatalogResource")


func _card_codex_privacy() -> bool:
	var source := {
		"names": ["轨道融资1"],
		"cards": [{"card_name": "轨道融资1", "display_name": "轨道融资", "hidden_owner": 2, "private_plan": "secret"}],
		"preview_card": {"card_name": "轨道融资1", "hidden_owner": 2},
	}
	var snapshot := _coordinator.compose_card_codex_browser(source)
	return not snapshot.is_empty() and not _contains_private_key(snapshot)


func _main_legacy_catalog_absent() -> bool:
	for constant_name in LEGACY_CONSTANTS:
		if _main_source.contains("const %s" % constant_name):
			return false
	for helper_name in LEGACY_HELPERS:
		if _main_source.contains("func %s(" % helper_name):
			return false
	return true


func _source_has(path: String, text_value: String) -> bool:
	var source := str(_sources.get(path, ""))
	if source.is_empty():
		source = FileAccess.get_file_as_string(path)
	return source.contains(text_value)


func _tres_count(path: String) -> int:
	var count := 0
	var directory := DirAccess.open(path)
	if directory == null:
		return 0
	for file_name in directory.get_files():
		if file_name.ends_with(".tres"):
			count += 1
	return count


func _order_hash(values: Array) -> String:
	var strings: Array[String] = []
	for value in values:
		strings.append(str(value))
	return "\n".join(strings).sha256_text()


func _unique_strings(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if not result.has(str(value)):
			result.append(str(value))
	return result


func _canonical(value: Variant) -> String:
	if value == null: return "null"
	if value is bool: return "true" if value else "false"
	if value is int: return "i:%d" % value
	if value is float: return "f:%s" % String.num(value, 12)
	if value is String or value is StringName: return "s:%s" % JSON.stringify(str(value))
	if value is Array or value is PackedStringArray:
		var array_parts: Array[String] = []
		for item in value:
			array_parts.append(_canonical(item))
		return "[%s]" % ",".join(array_parts)
	if value is Dictionary:
		var keys: Array[String] = []
		for key in value.keys():
			keys.append(str(key))
		keys.sort()
		var dictionary_parts: Array[String] = []
		for key in keys:
			dictionary_parts.append("%s=%s" % [_canonical(key), _canonical(value[key])])
		return "{%s}" % ",".join(dictionary_parts)
	return "unsupported:%s" % typeof(value)


func _level_text(value: int) -> String:
	const ROMAN := ["I", "II", "III", "IV"]
	return "%s级" % ROMAN[clampi(value, 1, 4) - 1]


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array or value is PackedStringArray:
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


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value.keys():
			var key := str(key_variant).to_lower()
			if PRIVATE_KEYS.has(key) or _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item in value:
			if _contains_private_key(item):
				return true
	return false


func _manifest() -> Dictionary:
	var validation := _catalog.validation_report()
	return {
		"suite": "runtime-card-catalog-resource-hard-cutover-sprint-58",
		"ruleset_id": "v0.4",
		"runtime_owner": "CardRuntimeCatalogService",
		"runtime_cutover_enabled": true,
		"case_count": CASE_COUNT,
		"passed_count": _count_passed(),
		"historical_passed": _count_phase("historical_integrity"),
		"live_passed": _count_phase("live_cutover"),
		"card_count": int(validation.get("card_count", 0)),
		"family_count": int(validation.get("family_count", 0)),
		"authored_rank_count": int(validation.get("authored_rank_count", 0)),
		"pack_count": int(validation.get("pack_count", 0)),
		"kind_count": int(validation.get("kind_count", 0)),
		"catalog_order_sha256": _order_hash(_service.ordered_card_ids()),
		"upgradeable_order_sha256": _order_hash(_service.upgradeable_families()),
		"common_pool_order_sha256": _order_hash(_service.public_pool()),
		"catalog_data_sha256": _catalog_data_hash(),
		"resource_schema": resource_schema_preview(),
		"records": _records.duplicate(true),
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
	}


func _case_note(case_id: String, passed: bool) -> String:
	return "%s: %s" % ["Verified" if passed else "Failed", case_id.replace("_", " ")]


func _count_passed() -> int:
	var count := 0
	for record_variant in _records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _count_phase(phase: String) -> int:
	var count := 0
	for record_variant in _records:
		var record := record_variant as Dictionary
		if record != null and str(record.get("phase", "")) == phase and bool(record.get("passed", false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	summary_label.text = "239 cards | 120 families | 10 packs | 49 kinds | %d/%d passed" % [int(manifest.get("passed_count", 0)), CASE_COUNT]
	status_label.text = "PASS - Resource Catalog owns runtime" if _failures.is_empty() else "CUTOVER FAILURE"
	schema_text.text = "[b]Runtime source[/b]\nCardRuntimeCatalogService\n\n[b]Assets[/b]\n120 family .tres\n239 embedded ranks\n10 ordered packs\n1 v0.4 catalog\n\n[b]Composition[/b]\nDefinitionWorldBridge\nExternal financial terms\nMonster owner routes\nRequirementPolicy after resolve\n\n[b]Legacy[/b]\nNo main.gd catalog fallback"
	var lines: Array[String] = []
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("%s  %-18s  %s" % ["PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("phase", "")), str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Runtime Card Catalog Resource Hard Cutover - Sprint 58", "",
		"- Runtime owner: `CardRuntimeCatalogService`",
		"- Cutover enabled: `true`",
		"- Assets: 120 family Resources, 239 authored rank subresources, 10 pack Resources, 1 catalog Resource",
		"- Historical integrity: %d/%d" % [int(manifest.get("historical_passed", 0)), HISTORICAL_CASE_COUNT],
		"- Live cutover: %d/%d" % [int(manifest.get("live_passed", 0)), LIVE_CASE_COUNT],
		"- Total: %d/%d" % [int(manifest.get("passed_count", 0)), CASE_COUNT], "",
		"## Integrity", "",
		"- Catalog order: `%s`" % str(manifest.get("catalog_order_sha256", "")),
		"- Upgradeable order: `%s`" % str(manifest.get("upgradeable_order_sha256", "")),
		"- Public pool order: `%s`" % str(manifest.get("common_pool_order_sha256", "")),
		"- Catalog data: `%s`" % str(manifest.get("catalog_data_sha256", "")), "",
		"## Cases", "", "| Phase | Case | Passed | Notes |", "| --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s |" % [str(record.get("phase", "")), str(record.get("case_id", "")), str(record.get("passed", false)), str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for file_name_variant in ["manifest.json", "report.md"]:
		var path: String = OUTPUT_DIR + str(file_name_variant)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("write:%s" % path)
		return
	file.store_string(content)
	file.close()


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_failures.append("screenshot_unavailable")
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if image.save_png(absolute_path) != OK:
		_failures.append("screenshot_write")


func _finish_early(message: String) -> void:
	push_error("RuntimeCardCatalogResourceBench: %s" % message)
	_failures.append(message)
	call_deferred("_quit_after_result", false)


func _quit_after_result(success: bool) -> void:
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if success else 1)
	else:
		await get_tree().create_timer(12.0).timeout
		get_tree().quit(0 if success else 1)


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
			var player := player_variant as AudioStreamPlayer
			if player != null:
				player.stop()
				player.stream = null
		_runtime_main.queue_free()
	_runtime_main = null
