extends Control
class_name RulesetV05FoundationBench

const PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v05.tres"
const V04_PROFILE_PATH := "res://resources/rules/space_syndicate_ruleset_v04.tres"
const V04_BRIDGE_SCENE_PATH := "res://scenes/runtime/RulesetRuntimeBridge.tscn"
const INDUSTRY_CATALOG_PATH := "res://resources/content/product_industry_catalog_v05.tres"
const V05_CARD_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v05.tres"
const CLOCK_REGISTRY_PATH := "res://resources/rules/clock_domain_registry_v05.tres"
const CONTROLLER_REGISTRY_PATH := "res://resources/rules/controller_state_version_registry_v05.tres"
const HANDSHAKE_SCENE_PATH := "res://scenes/runtime/RulesetSaveHandshakeService.tscn"
const PRODUCT_MARKET_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_controller.gd"
const RULESET_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/ruleset_runtime_bridge.gd"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const EXPECTED_MAIN_SHA256 := "6BD3F293EC2E92AEB81A39C80266314BE6A308D2C03ECD58FD8DB22958CAE699"
const EXPECTED_MAIN_TOTAL_LINES := 22867
const EXPECTED_MAIN_NONBLANK_LINES := 20209
const EXPECTED_MAIN_FUNCTIONS := 1285
const OUTPUT_DIR := "user://space_syndicate_design_qa/ruleset_v05_foundation/"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/ruleset_v05_foundation_sprint_1.png"
const ROUNDTRIP_PATH := "user://space_syndicate_design_qa/test_runs/ruleset_v05_foundation_roundtrip.json"

const CASE_IDS := [
	"profile_loads",
	"profile_identity",
	"profile_timing",
	"victory_depth_table",
	"control_and_capacity_thresholds",
	"card_group_and_priority_bids",
	"domain_parameters",
	"capability_flags",
	"profile_pure_data",
	"production_bridge_v04_unchanged",
	"six_industries_complete",
	"industry_metadata_complete",
	"actual_products_inventoried",
	"products_exactly_once",
	"duplicate_product_rejected",
	"missing_product_rejected",
	"unknown_industry_rejected",
	"no_runtime_industry_inference",
	"v05_card_catalog_loads",
	"v04_card_resources_isolated",
	"colorless_schema_valid",
	"single_industry_schema_valid",
	"dual_industry_schema_valid",
	"either_industry_schema_valid",
	"named_product_schema_valid",
	"three_industry_schema_rejected",
	"unknown_card_industry_rejected",
	"unknown_named_product_rejected",
	"more_than_two_conditions_rejected",
	"negative_requirement_rejected",
	"blocked_cards_excluded_from_release",
	"card_catalog_snapshot_pure",
	"currency_scale_is_100",
	"cents_suffix_payload_valid",
	"unsuffixed_amount_rejected",
	"mixed_currency_units_rejected",
	"float_currency_rejected",
	"half_away_from_zero_rounding",
	"transaction_id_exact_once",
	"currency_conservation",
	"clock_registry_complete",
	"clock_durations_exact",
	"clock_domains_exact",
	"clock_pause_policies_exact",
	"clock_save_restore_uses_remaining",
	"v1_recognized_as_legacy_v04",
	"v1_not_resumable_as_v05",
	"v05_envelope_valid",
	"controller_versions_complete",
	"v05_qa_roundtrip",
	"ruleset_mismatch_rejected",
	"currency_scale_mismatch_rejected",
	"v04_cannot_overwrite_v05",
	"v05_cannot_overwrite_v1",
	"all_foundation_outputs_pure",
	"no_selector_fallback_and_main_unchanged",
]

@export var auto_run: bool = true
var _last_manifest: Dictionary = {}

@onready var summary_label: Label = $Margin/Layout/SummaryLabel
@onready var status_label: Label = $Margin/Layout/StatusLabel
@onready var case_list: RichTextLabel = $Margin/Layout/CaseList
@onready var output_label: Label = $Margin/Layout/OutputLabel


func _ready() -> void:
	if auto_run:
		call_deferred("run_foundation_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func foundation_cases() -> Array:
	return CASE_IDS.duplicate()


func build_foundation_manifest_preview() -> Dictionary:
	var records: Array[Dictionary] = []
	for case_id_variant in CASE_IDS:
		records.append(_record(str(case_id_variant), _scope_for_case(str(case_id_variant)), false, "preview"))
	return {
		"suite_id": "ruleset_v05_foundation",
		"ruleset_id": "v0.5",
		"record_count": records.size(),
		"records": records,
	}


func run_foundation_suite() -> void:
	status_label.text = "Running SS05-01 foundation checks..."
	var records := _evaluate_cases()
	var passed_count := 0
	for record in records:
		if bool(record.get("passed", false)):
			passed_count += 1
	_last_manifest = {
		"suite_id": "ruleset_v05_foundation",
		"ruleset_id": "v0.5",
		"profile_schema_version": 1,
		"record_count": records.size(),
		"passed_count": passed_count,
		"failed_count": records.size() - passed_count,
		"production_runtime_ruleset": "v0.4",
		"records": records,
	}
	_update_ui(records, passed_count)
	_write_outputs(_last_manifest)
	await get_tree().process_frame
	_capture_screenshot()
	print("RulesetV05FoundationBench: %d/%d passed" % [passed_count, records.size()])
	print("RulesetV05FoundationBench manifest: %smanifest.json" % OUTPUT_DIR)
	print("RulesetV05FoundationBench report: %sreport.md" % OUTPUT_DIR)
	if passed_count != records.size() or records.size() != 56:
		push_error("RulesetV05FoundationBench failed: %d/%d" % [passed_count, records.size()])


func debug_snapshot() -> Dictionary:
	return _last_manifest.duplicate(true)


func _evaluate_cases() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var profile: Resource = load(PROFILE_PATH)
	var profile_validation: Dictionary = RulesetV05Validator.validate(profile)
	var profile_snapshot: Dictionary = profile.debug_snapshot() if profile != null and profile.has_method("debug_snapshot") else {}
	var timing: Dictionary = profile_snapshot.get("timing", {})
	var card_group: Dictionary = profile_snapshot.get("card_group", {})
	var capabilities: Dictionary = profile_snapshot.get("capabilities", {})
	var validation: Dictionary = profile_snapshot.get("validation", {})
	records.append(_record("profile_loads", "profile", profile != null and bool(profile_validation.get("valid", false)), str(profile_validation.get("errors", []))))
	records.append(_record("profile_identity", "profile", profile_snapshot.get("identity", {}) == {"ruleset_id": "v0.5", "profile_schema_version": 1, "currency_scale": 100}, "v0.5/schema 1/scale 100"))
	records.append(_record("profile_timing", "profile", int(timing.get("qualification_seconds", 0)) == 10 and int(timing.get("audit_seconds", 0)) == 120 and int(timing.get("audit_failure_cooldown_seconds", 0)) == 30, "10/120/30"))
	records.append(_record("victory_depth_table", "profile", validation.get("victory_depth_table", {}) == RulesetV05Validator.EXPECTED_DEPTH_TABLE, "six victory depths"))
	records.append(_record("control_and_capacity_thresholds", "profile", int(validation.get("region_control_threshold_bp", 0)) == 3000 and validation.get("industry_capacity_thresholds", []) == [15, 40, 80, 140], "3000 bp and 15/40/80/140"))
	records.append(_record("card_group_and_priority_bids", "profile", int(card_group.get("group_seconds", 0)) == 8 and int(card_group.get("organize_seconds", 0)) == 6 and int(card_group.get("lock_seconds", 0)) == 2 and int(card_group.get("tutorial_group_card_limit", 0)) == 1 and int(card_group.get("standard_group_card_limit", 0)) == 2 and card_group.get("priority_bid_options_cents", []) == [0, 5000, 10000], "8/6/2 and 0/50/100"))
	var domain_parameters_ok := int(timing.get("purchase_window_seconds", 0)) == 12 and int(timing.get("contract_response_seconds", 0)) == 8 and int(timing.get("monster_wager_seconds", 0)) == 8 and int(timing.get("battle_limit_standard", 0)) == 45 and int(timing.get("weather_forecast_seconds", 0)) == 90 and int(timing.get("financial_distress_seconds", 0)) == 20
	records.append(_record("domain_parameters", "profile", domain_parameters_ok, "purchase, contract, monster, weather, distress"))
	var capabilities_ok := bool(capabilities.get("realtime_income_enabled", false)) and not bool(capabilities.get("direct_city_build_allowed", true)) and not bool(capabilities.get("private_plan_enabled", true)) and not bool(capabilities.get("end_turn_enabled", true)) and not bool(capabilities.get("player_pipeline_building_enabled", true)) and not bool(capabilities.get("standard_market_noise_enabled", true))
	records.append(_record("capability_flags", "profile", capabilities_ok, "v0.5 capability lock"))
	records.append(_record("profile_pure_data", "profile", _is_pure_data(profile_snapshot), "profile snapshot contains no runtime objects"))
	var bridge_scene: PackedScene = load(V04_BRIDGE_SCENE_PATH)
	var bridge: Node = bridge_scene.instantiate() if bridge_scene != null else null
	var active_profile: Dictionary = bridge.active_profile() if bridge != null else {}
	var bridge_source := _read_text(RULESET_BRIDGE_SCRIPT_PATH)
	var bridge_ok := str(active_profile.get("ruleset_id", "")) == "v0.4" and bridge_source.contains("space_syndicate_ruleset_v04.tres") and not bridge_source.contains("space_syndicate_ruleset_v05.tres")
	records.append(_record("production_bridge_v04_unchanged", "profile", bridge_ok, str(active_profile.get("ruleset_id", "missing")), true))
	if bridge != null:
		bridge.free()

	var product_catalog: ProductIndustryCatalogResource = load(INDUSTRY_CATALOG_PATH)
	var actual_products := _runtime_product_ids()
	var product_validation: Dictionary = product_catalog.validation_snapshot(actual_products) if product_catalog != null else {"valid": false}
	records.append(_record("six_industries_complete", "industry", product_catalog != null and product_catalog.industry_ids() == ["life", "energy", "industry", "technology", "commerce", "shipping"], "six stable industry ids"))
	var metadata_ok := true
	if product_catalog != null:
		for definition in product_catalog.industries:
			metadata_ok = metadata_ok and not definition.display_name.is_empty() and not definition.icon_key.is_empty() and not definition.color_key.is_empty() and not definition.gameplay_summary.is_empty()
	else:
		metadata_ok = false
	records.append(_record("industry_metadata_complete", "industry", metadata_ok, "name/icon/color/summary"))
	records.append(_record("actual_products_inventoried", "industry", actual_products.size() == 46 and product_catalog != null and product_catalog.product_ids().size() == 46, "46 runtime products"))
	records.append(_record("products_exactly_once", "industry", bool(product_validation.get("valid", false)) and int(product_validation.get("product_count", 0)) == 46, str(product_validation.get("errors", []))))
	var duplicate_catalog := _copy_product_catalog(product_catalog)
	if duplicate_catalog != null and not duplicate_catalog.products.is_empty():
		duplicate_catalog.products.append(duplicate_catalog.products[0])
	var duplicate_result: Dictionary = duplicate_catalog.validation_snapshot(actual_products) if duplicate_catalog != null else {"valid": true}
	records.append(_record("duplicate_product_rejected", "industry", not bool(duplicate_result.get("valid", true)) and not duplicate_result.get("duplicate_products", []).is_empty(), "duplicate fails closed"))
	var missing_catalog := _copy_product_catalog(product_catalog, 1)
	var missing_result: Dictionary = missing_catalog.validation_snapshot(actual_products) if missing_catalog != null else {"valid": true}
	records.append(_record("missing_product_rejected", "industry", not bool(missing_result.get("valid", true)) and not missing_result.get("missing_products", []).is_empty(), "missing fails closed"))
	var unknown_catalog := _copy_product_catalog(product_catalog)
	if unknown_catalog != null:
		var unknown_entry := ProductIndustryEntryResource.new()
		unknown_entry.product_id = "qa_unknown_product"
		unknown_entry.display_name = "QA Unknown"
		unknown_entry.industry_id = "unknown_industry"
		unknown_entry.icon_key = "qa.unknown"
		unknown_catalog.products.append(unknown_entry)
	var unknown_result: Dictionary = unknown_catalog.validation_snapshot() if unknown_catalog != null else {"valid": true}
	records.append(_record("unknown_industry_rejected", "industry", not bool(unknown_result.get("valid", true)) and not unknown_result.get("unknown_industry_products", []).is_empty(), "unknown industry fails closed"))
	var explicit_mapping_ok := product_catalog != null
	if product_catalog != null:
		for product_id in actual_products:
			explicit_mapping_ok = explicit_mapping_ok and not product_catalog.industry_for_product(product_id).is_empty()
	records.append(_record("no_runtime_industry_inference", "industry", explicit_mapping_ok and not _read_text("res://scripts/content/product_industry_catalog_resource.gd").contains("display_name.to_lower"), "explicit product_id mapping only"))

	var card_catalog: CardRuntimeCatalogV05Resource = load(V05_CARD_CATALOG_PATH)
	var card_catalog_result: Dictionary = CardRuntimeCatalogV05Validator.validate_catalog(card_catalog, product_catalog)
	records.append(_record("v05_card_catalog_loads", "card_schema", card_catalog != null and bool(card_catalog_result.get("valid", false)), str(card_catalog_result.get("errors", []))))
	var v05_card_source := _read_text(V05_CARD_CATALOG_PATH)
	records.append(_record("v04_card_resources_isolated", "card_schema", not v05_card_source.contains("families/") and not v05_card_source.contains("card_runtime_catalog_v04"), "no v0.4 Resource references"))
	records.append(_record("colorless_schema_valid", "card_schema", _requirement_case_valid("colorless", [], 0, "", 0, product_catalog), "colorless"))
	records.append(_record("single_industry_schema_valid", "card_schema", _requirement_case_valid("single_industry", ["life"], 1, "", 0, product_catalog), "single industry"))
	records.append(_record("dual_industry_schema_valid", "card_schema", _requirement_case_valid("dual_industry", ["industry", "life"], 1, "", 0, product_catalog), "dual industry"))
	records.append(_record("either_industry_schema_valid", "card_schema", _requirement_case_valid("either_industry", ["technology", "commerce"], 2, "", 0, product_catalog), "either industry"))
	records.append(_record("named_product_schema_valid", "card_schema", _requirement_case_valid("named_product", [], 0, "星露莓", 15, product_catalog), "named product replaces generic charge"))
	records.append(_record("three_industry_schema_rejected", "card_schema", not _requirement_case_valid("dual_industry", ["life", "energy", "industry"], 1, "", 0, product_catalog), "v0.5 rejects three industries"))
	records.append(_record("unknown_card_industry_rejected", "card_schema", not _requirement_case_valid("single_industry", ["void"], 1, "", 0, product_catalog), "unknown industry"))
	records.append(_record("unknown_named_product_rejected", "card_schema", not _requirement_case_valid("named_product", [], 0, "不存在商品", 15, product_catalog), "unknown product"))
	records.append(_record("more_than_two_conditions_rejected", "card_schema", not _card_with_requirement_count_valid(3, product_catalog), "maximum two main conditions"))
	records.append(_record("negative_requirement_rejected", "card_schema", not _requirement_case_valid("single_industry", ["life"], -1, "", 0, product_catalog), "negative requirement"))
	var blocked_excluded := card_catalog != null and card_catalog.release_ready_card_ids.is_empty() and card_catalog.public_pool_card_ids.is_empty()
	if card_catalog != null:
		for card in card_catalog.cards:
			blocked_excluded = blocked_excluded and card.migration_status == "blocked" and not card.release_ready and not card.public_pool and not card.blocking_reason.is_empty()
	records.append(_record("blocked_cards_excluded_from_release", "card_schema", blocked_excluded, "%d blocked migration candidates" % (card_catalog.cards.size() if card_catalog != null else 0)))
	records.append(_record("card_catalog_snapshot_pure", "card_schema", card_catalog != null and _is_pure_data(card_catalog.debug_snapshot()), "no Resource leaks"))

	records.append(_record("currency_scale_is_100", "currency", CurrencyAmountWireV05.CURRENCY_SCALE == 100, "integer cents"))
	var valid_wire := {"transaction_id": "qa-valid", "currency_scale": 100, "available_cents": 10000, "escrow_cents": 0, "ledger_delta_cents": 0}
	records.append(_record("cents_suffix_payload_valid", "currency", bool(CurrencyAmountWireV05.validate_payload(valid_wire).get("valid", false)), "all monetary fields use _cents"))
	records.append(_record("unsuffixed_amount_rejected", "currency", not bool(CurrencyAmountWireV05.validate_payload({"transaction_id": "qa-legacy", "cash": 10}).get("valid", true)), "legacy field rejected"))
	records.append(_record("mixed_currency_units_rejected", "currency", not bool(CurrencyAmountWireV05.validate_payload({"transaction_id": "qa-mixed", "cash": 10, "cash_cents": 1000}).get("valid", true)), "mixed scale rejected"))
	records.append(_record("float_currency_rejected", "currency", not bool(CurrencyAmountWireV05.validate_payload({"transaction_id": "qa-float", "amount_cents": 10.5}).get("valid", true)), "float rejected"))
	var rounding_ok := CurrencyAmountWireV05.round_ratio_to_cents(5, 2) == 3 and CurrencyAmountWireV05.round_ratio_to_cents(-5, 2) == -3 and CurrencyAmountWireV05.round_ratio_to_cents(4, 2) == 2
	records.append(_record("half_away_from_zero_rounding", "currency", rounding_ok, "positive and negative midpoint"))
	var exact_once_ok := bool(CurrencyAmountWireV05.validate_exact_once([{"transaction_id": "a"}, {"transaction_id": "b"}]).get("valid", false)) and not bool(CurrencyAmountWireV05.validate_exact_once([{"transaction_id": "a"}, {"transaction_id": "a"}]).get("valid", true))
	records.append(_record("transaction_id_exact_once", "currency", exact_once_ok, "duplicate IDs rejected"))
	var conservation := {"transaction_id": "qa-conservation", "currency_scale": 100, "available_before_cents": 10000, "escrow_before_cents": 2000, "available_after_cents": 8500, "escrow_after_cents": 2500, "ledger_delta_cents": -1000}
	records.append(_record("currency_conservation", "currency", bool(CurrencyAmountWireV05.validate_conservation(conservation).get("valid", false)), "available + escrow + ledger delta"))

	var clock_registry: ClockDomainRegistryResource = load(CLOCK_REGISTRY_PATH)
	var clock_validation: Dictionary = clock_registry.validation_snapshot() if clock_registry != null else {"valid": false}
	var expected_durations := {"victory_qualification": 10, "public_audit": 120, "audit_failure_cooldown": 30, "card_group": 8, "card_organize": 6, "card_lock": 2, "district_purchase": 12, "contract_response": 8, "monster_wager": 8, "standard_monster_battle": 45, "weather_forecast": 90, "weather_duration": 90, "financial_distress": 20, "intel_live_shares": 60}
	records.append(_record("clock_registry_complete", "clock", clock_registry != null and bool(clock_validation.get("valid", false)) and int(clock_validation.get("timer_count", 0)) == 14, str(clock_validation.get("errors", []))))
	var durations_ok := true
	var domains_ok := true
	var pause_ok := true
	var restore_ok := true
	for timer_id_variant in expected_durations.keys():
		var timer_id := str(timer_id_variant)
		var timer: Dictionary = clock_registry.timer_snapshot(timer_id) if clock_registry != null else {}
		durations_ok = durations_ok and int(timer.get("duration_seconds", 0)) == int(expected_durations[timer_id_variant])
		domains_ok = domains_ok and ["world_effective", "interaction_effective", "forced_ui_realtime", "battle_effective"].has(str(timer.get("clock_domain", "")))
		pause_ok = pause_ok and str(timer.get("menu_pause_behavior", "")) == "pause" and str(timer.get("readonly_pause_behavior", "")) == "pause"
		restore_ok = restore_ok and str(timer.get("save_restore_behavior", "")).begins_with("remaining") or str(timer.get("save_restore_behavior", "")) == "phase_and_remaining"
	records.append(_record("clock_durations_exact", "clock", durations_ok, "14 approved durations"))
	var domain_specific_ok := clock_registry != null and str(clock_registry.timer_snapshot("monster_wager").get("clock_domain", "")) == "forced_ui_realtime" and str(clock_registry.timer_snapshot("standard_monster_battle").get("clock_domain", "")) == "battle_effective" and str(clock_registry.timer_snapshot("card_group").get("clock_domain", "")) == "interaction_effective"
	records.append(_record("clock_domains_exact", "clock", domains_ok and domain_specific_ok, "world/interaction/forced UI/battle"))
	var policy_specific_ok := clock_registry != null and str(clock_registry.timer_snapshot("monster_wager").get("monster_wager_freeze_behavior", "")) == "advances" and str(clock_registry.timer_snapshot("contract_response").get("forced_decision_behavior", "")) == "scheduler_priority"
	records.append(_record("clock_pause_policies_exact", "clock", pause_ok and policy_specific_ok, "menu/read-only/forced/wager policies"))
	records.append(_record("clock_save_restore_uses_remaining", "clock", restore_ok, "remaining effective time only"))

	var handshake_scene: PackedScene = load(HANDSHAKE_SCENE_PATH)
	var handshake: RulesetSaveHandshakeService = handshake_scene.instantiate() if handshake_scene != null else null
	var legacy_envelope := {"save_version": 1, "players": []}
	var legacy_inspection: Dictionary = handshake.inspect_envelope(legacy_envelope, "v0.5") if handshake != null else {}
	records.append(_record("v1_recognized_as_legacy_v04", "save", bool(legacy_inspection.get("recognized", false)) and str(legacy_inspection.get("classification", "")) == "legacy_v04", "version 1 without ruleset_id"))
	records.append(_record("v1_not_resumable_as_v05", "save", not bool(legacy_inspection.get("can_resume", true)) and bool(legacy_inspection.get("requires_backup", false)), "new v0.5 session required"))
	var v05_envelope: Dictionary = handshake.compose_v05_envelope({"session_id": "qa-v05"}, {"qa": {"ready": true}}) if handshake != null else {}
	var v05_validation: Dictionary = handshake.validate_v05_envelope(v05_envelope) if handshake != null else {}
	records.append(_record("v05_envelope_valid", "save", bool(v05_validation.get("valid", false)), str(v05_validation.get("errors", []))))
	var controller_registry: ControllerStateVersionRegistryResource = load(CONTROLLER_REGISTRY_PATH)
	var controller_validation: Dictionary = controller_registry.validation_snapshot() if controller_registry != null else {"valid": false}
	records.append(_record("controller_versions_complete", "save", bool(controller_validation.get("valid", false)) and controller_registry.required_versions().size() == 19 and v05_envelope.get("controller_state_versions", {}) == controller_registry.required_versions(), "19 future domain versions"))
	records.append(_record("v05_qa_roundtrip", "save", _qa_roundtrip(v05_envelope, handshake), ROUNDTRIP_PATH))
	var wrong_ruleset := v05_envelope.duplicate(true)
	wrong_ruleset["ruleset_id"] = "v0.6"
	records.append(_record("ruleset_mismatch_rejected", "save", not bool(handshake.validate_v05_envelope(wrong_ruleset).get("valid", true)), "unknown ruleset rejected"))
	var wrong_scale := v05_envelope.duplicate(true)
	wrong_scale["currency_scale"] = 1
	records.append(_record("currency_scale_mismatch_rejected", "save", not bool(handshake.validate_v05_envelope(wrong_scale).get("valid", true)), "wrong scale rejected"))
	var v04_header := {"save_version": 1}
	var v05_header := {"save_version": 2, "ruleset_id": "v0.5"}
	records.append(_record("v04_cannot_overwrite_v05", "save", not bool(handshake.write_authorization(v05_header, v04_header).get("allowed", true)), "downgrade overwrite rejected"))
	records.append(_record("v05_cannot_overwrite_v1", "save", not bool(handshake.write_authorization(v04_header, v05_header).get("allowed", true)), "legacy overwrite rejected"))
	var all_outputs_pure := _is_pure_data(profile_snapshot) and product_catalog != null and _is_pure_data(product_catalog.debug_snapshot()) and card_catalog != null and _is_pure_data(card_catalog.debug_snapshot()) and clock_registry != null and _is_pure_data(clock_registry.debug_snapshot()) and handshake != null and _is_pure_data(handshake.debug_snapshot()) and _is_pure_data(v05_envelope)
	records.append(_record("all_foundation_outputs_pure", "system", all_outputs_pure, "Dictionary/Array/scalars only"))
	var main_metrics := _main_metrics()
	var no_selector := bridge_ok and handshake != null and bool(handshake.debug_snapshot().get("passive_only", false)) and not bool(handshake.debug_snapshot().get("production_save_path_owned", true))
	var main_unchanged := str(main_metrics.get("sha256", "")) == EXPECTED_MAIN_SHA256 and int(main_metrics.get("total_lines", 0)) == EXPECTED_MAIN_TOTAL_LINES and int(main_metrics.get("nonblank_lines", 0)) == EXPECTED_MAIN_NONBLANK_LINES and int(main_metrics.get("functions", 0)) == EXPECTED_MAIN_FUNCTIONS
	records.append(_record("no_selector_fallback_and_main_unchanged", "system", no_selector and main_unchanged, JSON.stringify(main_metrics), true))
	if handshake != null:
		handshake.free()
	return records


func _record(case_id: String, scope: String, passed: bool, notes: String, production_v04_unchanged: bool = false) -> Dictionary:
	return {
		"case_id": case_id,
		"scope": scope,
		"ruleset_id": "v0.5",
		"schema_version": 1,
		"valid": passed,
		"pure_data_checked": scope in ["profile", "industry", "card_schema", "currency", "clock", "save", "system"],
		"production_v04_unchanged": production_v04_unchanged,
		"passed": passed,
		"notes": notes,
	}


func _scope_for_case(case_id: String) -> String:
	var index := CASE_IDS.find(case_id)
	if index < 10:
		return "profile"
	if index < 18:
		return "industry"
	if index < 32:
		return "card_schema"
	if index < 40:
		return "currency"
	if index < 45:
		return "clock"
	if index < 55:
		return "save"
	return "system"


func _runtime_product_ids() -> Array[String]:
	var result: Array[String] = []
	var market_script: Script = load(PRODUCT_MARKET_SCRIPT_PATH)
	if market_script == null:
		return result
	for product_variant in market_script.get("PRODUCT_CATALOG"):
		result.append(str(product_variant))
	return result


func _copy_product_catalog(source: ProductIndustryCatalogResource, product_start_index: int = 0) -> ProductIndustryCatalogResource:
	if source == null:
		return null
	var copy := ProductIndustryCatalogResource.new()
	copy.schema_version = source.schema_version
	for definition in source.industries:
		copy.industries.append(definition)
	for index in range(product_start_index, source.products.size()):
		copy.products.append(source.products[index])
	return copy


func _requirement_case_valid(kind: String, industry_ids: Array[String], capacity: int, product_id: String, product_gdp: int, industry_catalog: ProductIndustryCatalogResource) -> bool:
	var requirement := CardPlayRequirementV05Resource.new()
	requirement.requirement_kind = kind
	requirement.industry_ids = industry_ids
	requirement.required_capacity = capacity
	requirement.product_id = product_id
	requirement.required_product_gdp = product_gdp
	var card := CardRuntimeRankV05Resource.new()
	card.card_id = "qa_%s" % kind
	card.family_id = "qa"
	card.rank = 1
	card.migration_status = "draft"
	card.requirements.append(requirement)
	return bool(CardRuntimeCatalogV05Validator.validate_card(card, industry_catalog).get("valid", false))


func _card_with_requirement_count_valid(count: int, industry_catalog: ProductIndustryCatalogResource) -> bool:
	var card := CardRuntimeRankV05Resource.new()
	card.card_id = "qa_condition_count"
	card.family_id = "qa"
	card.rank = 1
	card.migration_status = "draft"
	for index in count:
		var requirement := CardPlayRequirementV05Resource.new()
		requirement.requirement_kind = "single_industry"
		requirement.industry_ids = ["life"]
		requirement.required_capacity = index % 4 + 1
		card.requirements.append(requirement)
	return bool(CardRuntimeCatalogV05Validator.validate_card(card, industry_catalog).get("valid", false))


func _qa_roundtrip(envelope: Dictionary, handshake: RulesetSaveHandshakeService) -> bool:
	if handshake == null:
		return false
	var absolute_dir := ProjectSettings.globalize_path(ROUNDTRIP_PATH.get_base_dir())
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file := FileAccess.open(ROUNDTRIP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(envelope, "\t", false))
	file.close()
	var read_file := FileAccess.open(ROUNDTRIP_PATH, FileAccess.READ)
	if read_file == null:
		return false
	var parsed: Variant = JSON.parse_string(read_file.get_as_text())
	read_file.close()
	var valid := parsed is Dictionary and bool(handshake.validate_v05_envelope(parsed).get("valid", false))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUNDTRIP_PATH))
	return valid


func _main_metrics() -> Dictionary:
	var source := _read_text(MAIN_SCRIPT_PATH)
	var lines := source.split("\n", true)
	if not lines.is_empty() and lines[lines.size() - 1].is_empty():
		lines.remove_at(lines.size() - 1)
	var total_lines := lines.size()
	var nonblank_lines := 0
	var functions := 0
	for line in lines:
		if not line.strip_edges().is_empty():
			nonblank_lines += 1
		if line.begins_with("func "):
			functions += 1
	return {
		"sha256": _file_sha256(MAIN_SCRIPT_PATH),
		"total_lines": total_lines,
		"nonblank_lines": nonblank_lines,
		"functions": functions,
	}


func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	file.close()
	return context.finish().hex_encode().to_upper()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


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


func _update_ui(records: Array[Dictionary], passed_count: int) -> void:
	summary_label.text = "SS05-01 Foundation  %d / %d" % [passed_count, records.size()]
	status_label.text = "PASS" if passed_count == records.size() and records.size() == 56 else "REVIEW REQUIRED"
	status_label.modulate = Color("7ddf9b") if passed_count == records.size() and records.size() == 56 else Color("ff8f83")
	var lines: Array[String] = []
	for record in records:
		lines.append("[color=%s]%s[/color]  %s  [color=#8da0b8]%s[/color]" % ["#7ddf9b" if bool(record.passed) else "#ff8f83", "PASS" if bool(record.passed) else "FAIL", str(record.case_id), str(record.scope)])
	case_list.text = "\n".join(lines)
	output_label.text = "%smanifest.json  |  report.md" % OUTPUT_DIR


func _write_outputs(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manifest_file := FileAccess.open("%smanifest.json" % OUTPUT_DIR, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string(JSON.stringify(manifest, "\t", false))
		manifest_file.close()
	var report_lines: Array[String] = [
		"# Ruleset v0.5 Foundation Bench",
		"",
		"- Result: %d/%d passed" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"- Production runtime: v0.4 (unchanged)",
		"- v0.5 role: inactive data, authoring, wire, clock, and save-handshake foundation",
		"",
		"| Case | Scope | Result | Notes |",
		"| --- | --- | --- | --- |",
	]
	for record in manifest.get("records", []):
		report_lines.append("| %s | %s | %s | %s |" % [str(record.case_id), str(record.scope), "PASS" if bool(record.passed) else "FAIL", str(record.notes).replace("|", "\\|")])
	var report_file := FileAccess.open("%sreport.md" % OUTPUT_DIR, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string("\n".join(report_lines))
		report_file.close()


func _capture_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var result := image.save_png(SCREENSHOT_PATH)
	if result != OK:
		push_warning("RulesetV05FoundationBench screenshot failed: %s" % error_string(result))
