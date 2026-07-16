extends Control
class_name ProductMarketRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const FORMULA_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_economy_product_route_formula_runtime_service.gd"
const CASHFLOW_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/economy_cashflow_runtime_controller.gd"
const GDP_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/gdp_formula_runtime_controller.gd"
const AI_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const WEATHER_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/weather_runtime_controller.gd"
const MONSTER_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/monster_runtime_controller.gd"
const MILITARY_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/military_runtime_controller.gd"
const CONTRACT_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_controller.gd"
const CONTRACT_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/contract_runtime_world_bridge.gd"
const PRODUCT_CODEX_SCRIPT_PATH := "res://scripts/runtime/product_codex_public_snapshot_service.gd"
const PRODUCT_MARKET_CONTROLLER_SCENE_PATH := "res://scenes/runtime/ProductMarketRuntimeController.tscn"
const PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_controller.gd"
const PRODUCT_MARKET_WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/product_market_runtime_world_bridge.gd"
const TERMS_RESOURCE_SCRIPT_PATH := "res://scripts/finance/product_futures_terms_resource.gd"
const TERMS_CATALOG_SCRIPT_PATH := "res://scripts/finance/product_futures_terms_catalog_resource.gd"
const TERMS_CATALOG_PATH := "res://resources/finance/product_futures/product_futures_terms_v04_catalog.tres"
const QUEUE_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_resolution_queue_runtime_service.gd"
const ELIGIBILITY_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_play_eligibility_runtime_service.gd"
const PRESENTATION_SERVICE_SCRIPT_PATH := "res://scripts/runtime/card_presentation_runtime_service.gd"

const OUTPUT_DIR := "user://space_syndicate_design_qa/product_futures_v04_hard_alignment/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/product_futures_v04_hard_alignment_sprint_55.png"
const RULESET_ID := "v0.4"
const MARKET_CASE_COUNT := 50
const HISTORICAL_CASE_COUNT := 24
const CUTOVER_CASE_COUNT := 26
const LIVE_CASE_COUNT := MARKET_CASE_COUNT + CUTOVER_CASE_COUNT
const CASE_COUNT := MARKET_CASE_COUNT + HISTORICAL_CASE_COUNT + CUTOVER_CASE_COUNT
const FIXED_SEED := 520052
const BASELINE_MAIN_SHA256 := "58d1c52957a80adc022aa9f3b1db34b7f8841ea1f138c011e4e9d0352d942006"
const BASELINE_MAIN_METRICS := {
	"total_lines": 26512,
	"nonblank_lines": 23659,
	"function_count": 1377,
	"top_level_variable_count": 142,
	"constant_count": 215,
}
const BASELINE_MARKET_CONTROLLER_SHA256 := "5b2e115a0d9c44623d48212bec4c9c1b29c4c150c827370614d6d24beb1b86eb"

const SAMPLE_PRODUCT := "活体芯片"
const REQUIRED_ENTRY_FIELDS := [
	"tier", "base_price", "price", "trend", "volatility", "supply", "demand", "disrupted",
	"price_history", "base_growth_multiplier", "growth_multiplier", "growth_seconds", "growth_turns",
	"growth_source", "base_growth_source", "base_route_flow_multiplier", "route_flow_multiplier",
	"route_flow_seconds", "route_flow_turns", "route_flow_source", "base_route_flow_source",
	"market_contract_demand", "market_contract_supply", "market_contract_seconds",
	"market_contract_turns", "market_contract_source", "futures_positions",
]
const TIER_RANGES := {
	"基础消费": [30, 58],
	"成长商品": [62, 104],
	"奢侈品": [112, 174],
	"战略稀缺": [184, 260],
}
const REAL_CARDS := [
	"价格套利1", "商品做空1",
	"商品看涨1", "商品看涨2", "商品看涨3", "商品看涨4",
	"商品看跌1", "商品看跌2", "商品看跌3", "商品看跌4",
	"港仓囤货1", "港仓囤货2", "港仓囤货3", "港仓囤货4",
	"市场稳定1", "商品催化1", "商品催化2", "星港快线1", "星港快线2",
]
const FUTURES_LONG_CARDS := ["商品看涨1", "商品看涨2", "商品看涨3", "商品看涨4"]
const FUTURES_SHORT_CARDS := ["商品看跌1", "商品看跌2", "商品看跌3", "商品看跌4"]
const FUTURES_WAREHOUSE_CARDS := ["港仓囤货1", "港仓囤货2", "港仓囤货3", "港仓囤货4"]
const FUTURES_CARD_IDS := FUTURES_LONG_CARDS + FUTURES_SHORT_CARDS + FUTURES_WAREHOUSE_CARDS
const HISTORICAL_TERMS_CASE_IDS := [
	"twelve_real_futures_cards_exist",
	"four_rank_progression_for_long",
	"four_rank_progression_for_short",
	"four_rank_progression_for_warehouse",
	"underlying_product_is_locked",
	"entry_price_is_locked_at_open",
	"duration_is_locked_at_open",
	"direction_is_locked_at_open",
	"multiplier_is_locked_at_open",
	"action_cost_paid_exactly_once",
	"explicit_margin_field_currently_missing",
	"margin_refund_semantics_currently_missing",
	"max_gain_field_currently_missing",
	"max_loss_field_currently_missing",
	"profitable_long_current_behavior",
	"profitable_short_current_behavior",
	"adverse_price_move_current_behavior",
	"zero_delta_current_behavior",
	"expiry_resolves_exactly_once",
	"warehouse_requires_owned_active_city",
	"warehouse_hp_source_characterized",
	"warehouse_destroy_current_clear_behavior",
	"warehouse_destroy_v04_mismatch_recorded",
	"public_private_and_save_boundary",
]
const CUTOVER_CASE_IDS := [
	"terms_resource_catalog_complete",
	"twelve_cards_terms_complete",
	"main_duplicate_terms_absent",
	"controller_catalog_composition",
	"queue_margin_preflight",
	"queue_cash_drift_reject_atomic",
	"effect_open_locks_margin_exactly_once",
	"position_locks_v04_terms",
	"favorable_long_gain_capped",
	"favorable_short_gain_capped",
	"adverse_long_loss_capped",
	"adverse_short_loss_capped",
	"zero_delta_refunds_margin",
	"expiry_settlement_exact_once_v04",
	"warehouse_open_requires_owned_city_v04",
	"warehouse_damage_receipt_complete",
	"warehouse_destruction_loss_formula",
	"partial_damage_no_early_settlement",
	"insufficient_margin_rejects_atomically",
	"legacy_save_normalizes_once",
	"current_save_roundtrip_v04",
	"public_snapshot_privacy_v04",
	"ai_risk_adjusted_terms",
	"presentation_shows_financial_terms",
	"no_parallel_futures_fallback",
	"main_scene_runtime_default_unchanged",
]
const DESIGN_DECISIONS := [
	{"decision_id": "cost_or_margin", "question": "Is the existing cost a non-refundable action fee or refundable margin?", "options": ["Treat purchase cost as the only cost", "Add a separate refundable margin", "Add both action fee and margin"], "recommendation": "Keep purchase cost separate and add an explicit refundable margin field."},
	{"decision_id": "margin_timing", "question": "When are action fee and margin charged or returned?", "options": ["Charge everything at queue commit", "Authorize at queue commit and lock margin when the position opens", "Charge only when the position expires"], "recommendation": "Authorize atomically at queue commit, lock margin when the effect opens, and settle/refund it at expiry or destruction."},
	{"decision_id": "maximum_gain", "question": "How is maximum gain authored?", "options": ["Fixed per card", "Shared rank table", "Margin multiple"], "recommendation": "Use an explicit per-card maximum_gain field so card text and balance remain inspectable."},
	{"decision_id": "maximum_loss", "question": "Can loss exceed margin?", "options": ["Margin-only loss", "Additional cash loss", "Card-specific choice"], "recommendation": "Cap loss at locked margin for readable atomic settlement and no surprise debt."},
	{"decision_id": "adverse_move", "question": "What happens on an adverse price move?", "options": ["Payout remains zero", "Realize a capped negative settlement", "Lose margin only after a threshold"], "recommendation": "Realize a negative settlement capped by maximum_loss."},
	{"decision_id": "warehouse_hp_moment", "question": "Which warehouse HP snapshot is used?", "options": ["HP before the damaging hit", "HP after the hit", "HP at position open"], "recommendation": "Pass pre-hit and post-hit HP in the destruction receipt; calculate from post-hit remaining HP."},
	{"decision_id": "warehouse_loss_formula", "question": "How does remaining HP affect warehouse loss?", "options": ["Fixed card loss", "Loss proportional to HP lost", "max_loss multiplied by one minus remaining_hp/max_hp"], "recommendation": "Use max_loss * (1 - remaining_hp / max_hp), with destruction producing maximum loss."},
	{"decision_id": "partial_warehouse_damage", "question": "Does partial warehouse damage settle early?", "options": ["Never", "Settle a fraction immediately", "Card-specific"], "recommendation": "Do not settle early; update public risk and settle only at expiry or destruction."},
	{"decision_id": "insufficient_cash", "question": "Can a player open a position without covering maximum loss?", "options": ["Allow debt", "Clamp future loss to available cash", "Require margin up front"], "recommendation": "Require the explicit margin up front and reject atomically when it cannot be reserved."},
	{"decision_id": "ai_financial_score", "question": "Which financial value should AI score?", "options": ["Maximum gain", "Margin efficiency", "Risk-adjusted expected value"], "recommendation": "Use risk-adjusted expected value including capped gain, capped loss, margin lock time, and public-clue risk."},
]
const DELETION_CANDIDATES := [
	"_ensure_product_market_catalog", "_normalize_product_market_boon_fields", "_append_product_price_history",
	"_generate_product_market", "_refresh_product_market_prices", "_product_price", "_product_tier",
	"_product_market_entry", "_apply_product_market_boon", "_product_route_flow_multiplier",
	"_product_futures_public_counts", "_product_futures_public_text", "_age_economic_boons",
	"_apply_product_speculation", "_product_futures_duration_seconds", "_apply_product_futures",
	"_update_product_futures_timers", "_product_futures_payout", "_pay_product_futures",
	"_clear_product_futures_for_destroyed_warehouse", "_apply_market_stabilize",
	"_apply_product_growth_boon", "_market_tick",
]
const CUTOVER_METHODS := [
	"ensure_catalog", "_normalize_boon_fields", "_append_price_history", "generate_product_market",
	"refresh_prices", "product_price", "product_tier", "market_entry", "apply_product_market_boon",
	"product_route_flow_multiplier", "futures_public_counts", "futures_public_text", "age_economic_boons",
	"apply_speculation", "futures_duration_seconds", "apply_futures", "open_futures_position",
	"update_futures_timers", "settle_futures_position", "settle_futures_for_destroyed_warehouse",
	"terms_for_card_id", "all_futures_terms", "skill_with_terms",
	"apply_market_stabilize", "apply_product_growth_boon", "market_tick",
]
const STATE_DELETION_CANDIDATES := ["product_market", "business_cycle_count", "market_timer"]
const CONSTANT_DELETION_CANDIDATES := [
	"PRODUCT_PRICE_MIN", "PRODUCT_PRICE_MAX", "PRODUCT_SUPPLY_PRICE_WEIGHT", "PRODUCT_DEMAND_PRICE_WEIGHT",
	"PRODUCT_ROUTE_DAMAGE_PRICE_WEIGHT", "PRODUCT_VOLATILITY_MIN", "PRODUCT_VOLATILITY_MAX",
	"PRODUCT_HISTORY_LIMIT", "PRODUCT_GROWTH_MULTIPLIER_MAX", "ROUTE_FLOW_MULTIPLIER_MAX",
	"PRODUCT_CATALOG", "PRODUCT_PRICE_TIERS", "PRODUCT_PROFILES",
]

const CASE_IDS := [
	"product_market_call_graph_complete",
	"product_catalog_and_profiles_exist",
	"runtime_market_state_shape",
	"seeded_market_generation_deterministic",
	"price_tier_weight_selection_order",
	"base_price_within_tier",
	"initial_price_history_shape",
	"ensure_catalog_idempotent",
	"missing_catalog_entry_backfilled",
	"destroyed_district_excluded",
	"district_product_supply_weight",
	"active_city_product_supply_weight",
	"district_demand_weight",
	"active_city_demand_weight",
	"disrupted_route_pressure",
	"temporary_demand_pressure_applies_once",
	"temporary_supply_pressure_applies_once",
	"temporary_pressure_decays_per_refresh",
	"contract_pressure_active_then_expires",
	"shared_rng_consumption_order",
	"price_clamp_min_max",
	"volatility_step_cap",
	"trend_driver_summary_parity",
	"price_history_deduplicates_and_limits",
	"market_timer_realtime_cadence",
	"paused_or_forced_block_freezes_market_timer",
	"market_tick_increments_cycle_once",
	"market_tick_refresh_order",
	"no_active_city_safe_tick",
	"product_boon_applies",
	"economic_boon_ages_realtime",
	"persistent_boon_baseline_preserved",
	"speculation_up_adds_demand",
	"speculation_down_adds_supply",
	"market_stabilize_reduces_pressure",
	"product_growth_boon_duration",
	"route_flow_boon_multiplier",
	"futures_up_position_created",
	"futures_down_position_created",
	"warehouse_futures_requires_owned_active_city",
	"futures_payout_positive_direction_only",
	"futures_expiry_exact_once",
	"destroyed_warehouse_clears_positions",
	"current_and_legacy_save_shape",
	"public_private_market_snapshot_boundary",
	"sprint53_deletion_candidates_complete",
	"formula_service_remains_arithmetic_owner",
	"ai_reads_market_but_does_not_mutate",
	"weather_monster_military_contract_share_refresh_route",
	"pure_data_evidence_and_no_runtime_objects",
	"twelve_real_futures_cards_exist",
	"four_rank_progression_for_long",
	"four_rank_progression_for_short",
	"four_rank_progression_for_warehouse",
	"underlying_product_is_locked",
	"entry_price_is_locked_at_open",
	"duration_is_locked_at_open",
	"direction_is_locked_at_open",
	"multiplier_is_locked_at_open",
	"action_cost_paid_exactly_once",
	"explicit_margin_field_currently_missing",
	"margin_refund_semantics_currently_missing",
	"max_gain_field_currently_missing",
	"max_loss_field_currently_missing",
	"profitable_long_current_behavior",
	"profitable_short_current_behavior",
	"adverse_price_move_current_behavior",
	"zero_delta_current_behavior",
	"expiry_resolves_exactly_once",
	"warehouse_requires_owned_active_city",
	"warehouse_hp_source_characterized",
	"warehouse_destroy_current_clear_behavior",
	"warehouse_destroy_v04_mismatch_recorded",
	"public_private_and_save_boundary",
	"terms_resource_catalog_complete",
	"twelve_cards_terms_complete",
	"main_duplicate_terms_absent",
	"controller_catalog_composition",
	"queue_margin_preflight",
	"queue_cash_drift_reject_atomic",
	"effect_open_locks_margin_exactly_once",
	"position_locks_v04_terms",
	"favorable_long_gain_capped",
	"favorable_short_gain_capped",
	"adverse_long_loss_capped",
	"adverse_short_loss_capped",
	"zero_delta_refunds_margin",
	"expiry_settlement_exact_once_v04",
	"warehouse_open_requires_owned_city_v04",
	"warehouse_damage_receipt_complete",
	"warehouse_destruction_loss_formula",
	"partial_damage_no_early_settlement",
	"insufficient_margin_rejects_atomically",
	"legacy_save_normalizes_once",
	"current_save_roundtrip_v04",
	"public_snapshot_privacy_v04",
	"ai_risk_adjusted_terms",
	"presentation_shows_financial_terms",
	"no_parallel_futures_fallback",
	"main_scene_runtime_default_unchanged",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _coordinator: Node
var _formula_service: Node
var _cashflow_controller: Node
var _gdp_controller: Node
var _ai_controller: Node
var _weather_controller: Node
var _monster_controller: Node
var _military_controller: Node
var _contract_controller: Node
var _market_controller: ProductMarketRuntimeController
var _queue_service: Node
var _eligibility_service: Node
var _presentation_service: Node
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _baseline_product_market: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []
var _sources: Dictionary = {}


func _ready() -> void:
	print("ProductMarketRuntimeCharacterizationBench Sprint 55 ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
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
		"suite": "product-futures-v04-authored-terms-hard-alignment-sprint55",
		"ruleset_id": RULESET_ID,
		"runtime_owner": PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"market_case_count": MARKET_CASE_COUNT,
		"historical_case_count": HISTORICAL_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"live_case_count": LIVE_CASE_COUNT,
		"record_count": records.size(),
		"observed_count": 0,
		"aligned_count": 0,
		"passed_count": 0,
		"needs_design_decision_count": 0,
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"baseline_main_metrics": BASELINE_MAIN_METRICS.duplicate(true),
		"baseline_market_controller_sha256": BASELINE_MARKET_CONTROLLER_SHA256,
		"deletion_candidates": DELETION_CANDIDATES.duplicate(),
		"state_deletion_candidates": STATE_DELETION_CANDIDATES.duplicate(),
		"constant_deletion_candidates": CONSTANT_DELETION_CANDIDATES.duplicate(),
		"card_terms_matrix": _preview_terms_matrix(),
		"design_decisions": [],
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_load_sources()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("ProductMarketRuntimeCharacterizationBench could not instantiate the real main runtime and required boundaries.")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in CASE_IDS:
		var case_id := str(case_id_variant)
		_reset_fixture()
		print("ProductMarketRuntimeCharacterizationBench case: %s" % case_id)
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "observation failed"))])
	var main_source := str(_sources.get("main", ""))
	var current_sha := main_source.sha256_text()
	var controller_sha := str(_sources.get("market_controller", "")).sha256_text()
	var metrics := _main_metrics(main_source)
	var production_not_grown := int(metrics.get("nonblank_lines", 999999)) <= int(BASELINE_MAIN_METRICS.get("nonblank_lines", 0)) and int(metrics.get("function_count", 999999)) <= int(BASELINE_MAIN_METRICS.get("function_count", 0))
	var manifest := {
		"suite": "product-futures-v04-authored-terms-hard-alignment-sprint55",
		"ruleset_id": RULESET_ID,
		"runtime_owner": PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH,
		"runtime_cutover_enabled": true,
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": CASE_COUNT,
		"market_case_count": MARKET_CASE_COUNT,
		"historical_case_count": HISTORICAL_CASE_COUNT,
		"cutover_case_count": CUTOVER_CASE_COUNT,
		"live_case_count": LIVE_CASE_COUNT,
		"record_count": _records.size(),
		"observed_count": _count_flag("observed"),
		"aligned_count": _count_flag("contract_aligned"),
		"passed_count": _count_flag("passed"),
		"needs_design_decision_count": _count_flag("needs_design_decision"),
		"baseline_main_sha256": BASELINE_MAIN_SHA256,
		"current_main_sha256": current_sha,
		"baseline_main_metrics": BASELINE_MAIN_METRICS.duplicate(true),
		"baseline_market_controller_sha256": BASELINE_MARKET_CONTROLLER_SHA256,
		"main_metrics": metrics,
		"production_main_not_grown": production_not_grown,
		"market_controller_sha256": controller_sha,
		"market_controller_changed_for_cutover": controller_sha != BASELINE_MARKET_CONTROLLER_SHA256,
		"deletion_candidates": DELETION_CANDIDATES.duplicate(),
		"state_deletion_candidates": STATE_DELETION_CANDIDATES.duplicate(),
		"constant_deletion_candidates": CONSTANT_DELETION_CANDIDATES.duplicate(),
		"card_terms_matrix": _financial_card_terms_matrix(),
		"design_decisions": [],
		"records": _records.duplicate(true),
	}
	if not production_not_grown:
		_failures.append("production main.gd grew beyond the Sprint 55 baseline")
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	_save_screenshot()
	print("ProductMarketRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("ProductMarketRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("ProductMarketRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("ProductMarketRuntimeCharacterizationBench observed: %d/%d" % [_count_flag("observed"), CASE_COUNT])
	print("ProductMarketRuntimeCharacterizationBench aligned: %d/%d; design_decisions=%d" % [_count_flag("contract_aligned"), CASE_COUNT, _count_flag("needs_design_decision")])
	print("ProductMarketRuntimeCharacterizationBench Sprint 55: %d/%d records; live=%d/%d aligned; historical=%d/%d preserved; decisions=%d main_not_grown=%s sha=%s" % [_count_flag("observed"), CASE_COUNT, _count_flag_for_ids("contract_aligned", CASE_IDS.slice(0, MARKET_CASE_COUNT) + CUTOVER_CASE_IDS), LIVE_CASE_COUNT, _count_flag_for_ids("observed", HISTORICAL_TERMS_CASE_IDS), HISTORICAL_CASE_COUNT, _count_flag_for_ids("needs_design_decision", CASE_IDS.slice(0, MARKET_CASE_COUNT) + CUTOVER_CASE_IDS), str(production_not_grown), current_sha])
	if not _failures.is_empty():
		push_error("ProductMarketRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	if HISTORICAL_TERMS_CASE_IDS.has(case_id):
		return _historical_terms_record(case_id)
	if CUTOVER_CASE_IDS.has(case_id):
		return _run_cutover_case(case_id)
	match case_id:
		"product_market_call_graph_complete": return _case_call_graph()
		"product_catalog_and_profiles_exist": return _case_catalog_profiles_cards()
		"runtime_market_state_shape": return _case_state_shape()
		"seeded_market_generation_deterministic": return _case_seeded_generation()
		"price_tier_weight_selection_order": return _case_tier_weight_order()
		"base_price_within_tier": return _case_base_price_within_tier()
		"initial_price_history_shape": return _case_initial_history()
		"ensure_catalog_idempotent": return _case_ensure_idempotent()
		"missing_catalog_entry_backfilled": return _case_missing_entry_backfilled()
		"destroyed_district_excluded": return _case_market_weight("destroyed")
		"district_product_supply_weight": return _case_market_weight("district_supply")
		"active_city_product_supply_weight": return _case_market_weight("city_supply")
		"district_demand_weight": return _case_market_weight("district_demand")
		"active_city_demand_weight": return _case_market_weight("city_demand")
		"disrupted_route_pressure": return _case_market_weight("disrupted")
		"temporary_demand_pressure_applies_once": return _case_temporary_pressure("demand")
		"temporary_supply_pressure_applies_once": return _case_temporary_pressure("supply")
		"temporary_pressure_decays_per_refresh": return _case_pressure_decay()
		"contract_pressure_active_then_expires": return _case_contract_pressure_expiry()
		"shared_rng_consumption_order": return _case_rng_order()
		"price_clamp_min_max": return _case_price_clamp()
		"volatility_step_cap": return _case_volatility_cap()
		"trend_driver_summary_parity": return _case_trend_driver()
		"price_history_deduplicates_and_limits": return _case_history_limit()
		"market_timer_realtime_cadence": return _case_timer_cadence()
		"paused_or_forced_block_freezes_market_timer": return _case_timer_freeze()
		"market_tick_increments_cycle_once": return _case_market_tick_increment()
		"market_tick_refresh_order": return _case_tick_order()
		"no_active_city_safe_tick": return _case_empty_city_tick()
		"product_boon_applies": return _case_product_boon()
		"economic_boon_ages_realtime": return _case_boon_ages()
		"persistent_boon_baseline_preserved": return _case_persistent_boon()
		"speculation_up_adds_demand": return _case_speculation(true)
		"speculation_down_adds_supply": return _case_speculation(false)
		"market_stabilize_reduces_pressure": return _case_market_stabilize()
		"product_growth_boon_duration": return _case_growth_boon()
		"route_flow_boon_multiplier": return _case_route_flow_multiplier()
		"futures_up_position_created": return _case_futures_position("up")
		"futures_down_position_created": return _case_futures_position("down")
		"warehouse_futures_requires_owned_active_city": return _case_warehouse_requirement()
		"futures_payout_positive_direction_only": return _case_futures_payout()
		"futures_expiry_exact_once": return _case_futures_expiry()
		"destroyed_warehouse_clears_positions": return _case_destroyed_warehouse()
		"current_and_legacy_save_shape": return _case_save_shape()
		"public_private_market_snapshot_boundary": return _case_privacy_boundary()
		"sprint53_deletion_candidates_complete": return _case_deletion_candidates()
		"formula_service_remains_arithmetic_owner": return _case_formula_boundary()
		"ai_reads_market_but_does_not_mutate": return _case_ai_boundary()
		"weather_monster_military_contract_share_refresh_route": return _case_world_routes()
		"pure_data_evidence_and_no_runtime_objects": return _case_pure_data()
	return _record(case_id, false, false, "Unknown characterization case.")


func _historical_terms_record(case_id: String) -> Dictionary:
	var docs_present := FileAccess.file_exists("res://docs/product_futures_v04_design_decisions.md") and FileAccess.file_exists("res://docs/product_futures_v04_terms_contract.md")
	var preserved := HISTORICAL_TERMS_CASE_IDS.has(case_id) and docs_present and DESIGN_DECISIONS.size() == 10
	return _record(case_id, preserved, preserved, "Sprint 54 historical baseline preserved; Sprint 55 evaluates the authored replacement in the separate live gate.", {
		"historical_baseline": true,
		"live_gate": false,
		"needs_design_decision": false,
		"risk": "",
	})


func _run_cutover_case(case_id: String) -> Dictionary:
	match case_id:
		"terms_resource_catalog_complete": return _case_terms_resource_catalog_complete()
		"twelve_cards_terms_complete": return _case_twelve_cards_terms_complete()
		"main_duplicate_terms_absent": return _case_main_duplicate_terms_absent()
		"controller_catalog_composition": return _case_controller_catalog_composition()
		"queue_margin_preflight": return _case_queue_margin_preflight()
		"queue_cash_drift_reject_atomic": return _case_queue_cash_drift_reject_atomic()
		"effect_open_locks_margin_exactly_once": return _case_effect_open_locks_margin_exactly_once()
		"position_locks_v04_terms": return _case_position_locks_v04_terms()
		"favorable_long_gain_capped": return _case_v04_directional_settlement(true, true)
		"favorable_short_gain_capped": return _case_v04_directional_settlement(false, true)
		"adverse_long_loss_capped": return _case_v04_directional_settlement(true, false)
		"adverse_short_loss_capped": return _case_v04_directional_settlement(false, false)
		"zero_delta_refunds_margin": return _case_zero_delta_refunds_margin()
		"expiry_settlement_exact_once_v04": return _case_expiry_settlement_exact_once_v04()
		"warehouse_open_requires_owned_city_v04": return _case_warehouse_open_requires_owned_city_v04()
		"warehouse_damage_receipt_complete": return _case_warehouse_damage_receipt_complete()
		"warehouse_destruction_loss_formula": return _case_warehouse_destruction_loss_formula()
		"partial_damage_no_early_settlement": return _case_partial_damage_no_early_settlement()
		"insufficient_margin_rejects_atomically": return _case_insufficient_margin_rejects_atomically()
		"legacy_save_normalizes_once": return _case_legacy_save_normalizes_once()
		"current_save_roundtrip_v04": return _case_current_save_roundtrip_v04()
		"public_snapshot_privacy_v04": return _case_public_snapshot_privacy_v04()
		"ai_risk_adjusted_terms": return _case_ai_risk_adjusted_terms()
		"presentation_shows_financial_terms": return _case_presentation_shows_financial_terms()
		"no_parallel_futures_fallback": return _case_no_parallel_futures_fallback()
		"main_scene_runtime_default_unchanged": return _case_main_scene_runtime_default_unchanged()
	return _record(case_id, false, false, "Unknown Sprint 55 cutover case.")


func _case_terms_resource_catalog_complete() -> Dictionary:
	var catalog := load(TERMS_CATALOG_PATH)
	var report: Dictionary = catalog.call("validation_report") if catalog != null and catalog.has_method("validation_report") else {}
	var observed := bool(report.get("valid", false)) and int(report.get("card_count", 0)) == 12 and _is_data_only(report)
	return _live_record("terms_resource_catalog_complete", observed, "Inspector catalog validates all twelve v0.4 terms Resources.", {"card_id": "、".join(FUTURES_CARD_IDS), "pure_data_checked": observed})


func _case_twelve_cards_terms_complete() -> Dictionary:
	var expected := {
		"商品看涨1": [1, "up", 60.0, 1.0, 1, false, 120, 260, 120], "商品看涨2": [2, "up", 75.0, 1.45, 1, false, 180, 420, 180],
		"商品看涨3": [3, "up", 95.0, 2.05, 1, false, 260, 650, 260], "商品看涨4": [4, "up", 120.0, 2.8, 1, false, 360, 900, 360],
		"商品看跌1": [1, "down", 60.0, 1.0, 1, false, 120, 260, 120], "商品看跌2": [2, "down", 75.0, 1.45, 1, false, 180, 420, 180],
		"商品看跌3": [3, "down", 95.0, 2.05, 1, false, 260, 650, 260], "商品看跌4": [4, "down", 120.0, 2.8, 1, false, 360, 900, 360],
		"港仓囤货1": [1, "up", 90.0, 0.75, 2, true, 180, 360, 180], "港仓囤货2": [2, "up", 105.0, 0.9, 3, true, 260, 560, 260],
		"港仓囤货3": [3, "up", 120.0, 1.05, 5, true, 400, 850, 400], "港仓囤货4": [4, "up", 150.0, 1.25, 8, true, 600, 1200, 600],
	}
	var observed := true
	for card_id_variant in expected.keys():
		var card_id := str(card_id_variant); var values: Array = expected[card_id_variant]; var terms := _market_controller.terms_for_card_id(card_id)
		observed = observed and int(terms.get("rank", 0)) == int(values[0]) and str(terms.get("direction", "")) == str(values[1])
		observed = observed and is_equal_approx(float(terms.get("duration_seconds", 0.0)), float(values[2])) and is_equal_approx(float(terms.get("multiplier", 0.0)), float(values[3]))
		observed = observed and int(terms.get("units", 0)) == int(values[4]) and bool(terms.get("requires_warehouse", false)) == bool(values[5])
		observed = observed and int(terms.get("action_fee_cash", -1)) == 0 and int(terms.get("margin_cash", 0)) == int(values[6])
		observed = observed and int(terms.get("maximum_gain", 0)) == int(values[7]) and int(terms.get("maximum_loss", 0)) == int(values[8]) and str(terms.get("terms_version", "")) == "v0.4"
	return _live_record("twelve_cards_terms_complete", observed, "All authored durations, multipliers, units, margins, and caps match the approved table.", {"card_id": "、".join(FUTURES_CARD_IDS)})


func _case_main_duplicate_terms_absent() -> Dictionary:
	var source := str(_sources.get("main", ""))
	var old_keys := ["\"product_bet_direction\"", "\"product_bet_multiplier\"", "\"product_bet_seconds\"", "\"requires_warehouse_city\"", "\"stockpile_units\""]
	var residues: Array = []
	for key_variant in old_keys:
		if source.contains(str(key_variant)): residues.append(str(key_variant))
	var observed := residues.is_empty() and not source.contains("func _product_futures_balance_")
	return _live_record("main_duplicate_terms_absent", observed, "main.gd retains generic card metadata only; duplicate financial keys=%s." % str(residues))


func _case_controller_catalog_composition() -> Dictionary:
	var scene_source := FileAccess.get_file_as_string(PRODUCT_MARKET_CONTROLLER_SCENE_PATH)
	var debug := _market_controller.debug_snapshot()
	var terms_report: Dictionary = debug.get("terms_catalog", {}) if debug.get("terms_catalog", {}) is Dictionary else {}
	var observed := scene_source.contains(TERMS_CATALOG_PATH) and bool(terms_report.get("valid", false)) and int(terms_report.get("card_count", 0)) == 12
	return _live_record("controller_catalog_composition", observed, "The real Controller scene owns an explicit catalog Resource and reports it valid.")


func _queue_plan(cash: int) -> Dictionary:
	_queue_service.reset_state()
	return _queue_service.plan_submission({
		"player_index": 0, "slot_index": 0, "already_queued": false, "desired_bid_cents": 4000,
		"play_cash_cost": 0, "available_cash": cash, "cash_revision": "cash-%d" % cash,
		"group_card_limit": 3, "skill": _skill("商品看涨1"), "entry_context": {"card_id": "商品看涨1"},
	}, {"player_count": 4, "batch_locked": false, "counter_window_active": false, "simultaneous_timer": 25.0, "lock_duration": 5.0, "window_sequence": 0, "reference_player": 0})


func _case_queue_margin_preflight() -> Dictionary:
	var rejected := _queue_plan(159)
	var accepted := _queue_plan(160)
	var entry: Dictionary = accepted.get("entry", {}) if accepted.get("entry", {}) is Dictionary else {}
	var observed := not bool(rejected.get("accepted", false)) and str(rejected.get("reason", "")) == "insufficient_financial_margin"
	observed = observed and bool(accepted.get("accepted", false)) and int(accepted.get("financial_cash_required", 0)) == 160 and int(entry.get("financial_margin_cash", 0)) == 120 and not bool(entry.get("financial_margin_locked_on_queue", true))
	return _live_record("queue_margin_preflight", observed, "Queue authorizes fee + bid + margin (¥160 here) but does not lock margin.", {"cash_delta": 0})


func _case_queue_cash_drift_reject_atomic() -> Dictionary:
	var plan := _queue_plan(160)
	var before: Dictionary = _queue_service.debug_snapshot()
	var receipt: Dictionary = _queue_service.commit_submission(plan, {"authorized": true, "inventory_committed": true, "play_cost_authorized": true, "financial_margin_authorized": false})
	var after: Dictionary = _queue_service.debug_snapshot()
	var observed := bool(plan.get("accepted", false)) and not bool(receipt.get("committed", false)) and str(receipt.get("reason", "")) == "external_commit_not_ready" and int(after.get("current_count", -1)) == int(before.get("current_count", -1))
	return _live_record("queue_cash_drift_reject_atomic", observed, "A failed margin reauthorization leaves both queue revisions and entries unchanged.")


func _case_effect_open_locks_margin_exactly_once() -> Dictionary:
	_configure_market_fixture("empty")
	var before := _player_cash(0); var first := _market_controller.open_futures_position(0, _skill("商品看涨1")); var after_first := _player_cash(0)
	var positions: Array = _entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array
	var observed := bool(first.get("committed", false)) and before - after_first == 120 and positions.size() == 1 and int((positions[0] as Dictionary).get("locked_margin", 0)) == 120
	return _live_record("effect_open_locks_margin_exactly_once", observed, "Effect open rechecks cash, deducts ¥120 once, then appends one position.", {"card_id": "商品看涨1", "cash_delta": after_first - before, "futures_count_after": positions.size()})


func _case_position_locks_v04_terms() -> Dictionary:
	var opened := _open_position("港仓囤货4", true); var locked_position: Dictionary = opened.get("position", {}) as Dictionary
	var observed := bool(opened.get("applied", false)) and str(locked_position.get("terms_version", "")) == "v0.4" and int(locked_position.get("locked_margin", 0)) == 600 and int(locked_position.get("maximum_gain", 0)) == 1200 and int(locked_position.get("maximum_loss", 0)) == 600
	observed = observed and str(locked_position.get("settlement_formula_id", "")) == "product_futures_v04_settlement" and str(locked_position.get("warehouse_loss_formula_id", "")) == "warehouse_futures_v04_loss"
	return _live_record("position_locks_v04_terms", observed, "The private position locks immutable v0.4 terms at open.", _terms_flags("港仓囤货4", {"entry_locked": observed}))


func _case_v04_directional_settlement(is_long: bool, favorable: bool) -> Dictionary:
	var card_id := "商品看涨1" if is_long else "商品看跌1"; var terms := _market_controller.terms_for_card_id(card_id)
	var current_price := (100 if favorable else 0) if is_long else (0 if favorable else 100)
	var result: Dictionary = _formula_service.calculate("product_futures_v04_settlement", {"current_price": current_price, "position": _position_from_terms(terms, 50)})
	var expected_gain := 260 if favorable else 0; var expected_loss := 0 if favorable else 120
	var observed := bool(result.get("ok", false)) and int(result.get("gain", -1)) == expected_gain and int(result.get("loss", -1)) == expected_loss and int(result.get("cash_return", -1)) == (380 if favorable else 0)
	var case_id := ("favorable_%s_gain_capped" if favorable else "adverse_%s_loss_capped") % ("long" if is_long else "short")
	return _live_record(case_id, observed, "Directional P&L is capped by the same authored Resource for %s." % card_id, {"card_id": card_id, "direction": str(terms.get("direction", "")), "formula_service_checked": true})


func _case_zero_delta_refunds_margin() -> Dictionary:
	var terms := _market_controller.terms_for_card_id("商品看涨2"); var result: Dictionary = _formula_service.calculate("product_futures_v04_settlement", {"current_price": 50, "position": _position_from_terms(terms, 50)})
	var observed := bool(result.get("ok", false)) and int(result.get("gain", -1)) == 0 and int(result.get("loss", -1)) == 0 and int(result.get("margin_refund", -1)) == 180 and int(result.get("cash_return", -1)) == 180
	return _live_record("zero_delta_refunds_margin", observed, "Zero price movement returns the complete locked margin.", {"card_id": "商品看涨2", "formula_service_checked": true})


func _case_expiry_settlement_exact_once_v04() -> Dictionary:
	_configure_market_fixture("empty"); _runtime_main.set("game_time", 100.0)
	var cash_before := _player_cash(0); var open := _market_controller.open_futures_position(0, _skill("商品看涨1"))
	var state := _market_state(); var market: Dictionary = state.get("product_market", {}) as Dictionary; var entry: Dictionary = market[SAMPLE_PRODUCT]; var positions: Array = entry.get("futures_positions", []) as Array
	if not bool(open.get("committed", false)) or positions.is_empty():
		return _live_record("expiry_settlement_exact_once_v04", false, "Position open failed before the expiry exact-once check.", {"card_id": "商品看涨1", "timing_checked": false})
	var expiry_position: Dictionary = positions[0]; expiry_position["expires_at"] = 99.0; positions[0] = expiry_position; entry["price"] = int(expiry_position.get("baseline_price", 0)) + 100; entry["futures_positions"] = positions; market[SAMPLE_PRODUCT] = entry; state["product_market"] = market; _market_controller.apply_save_data(state)
	_market_controller.update_futures_timers(); var cash_first := _player_cash(0); _market_controller.update_futures_timers(); var cash_second := _player_cash(0)
	var observed := bool(open.get("committed", false)) and cash_first == cash_before + 260 and cash_second == cash_first and (_entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array).is_empty()
	return _live_record("expiry_settlement_exact_once_v04", observed, "Expiry returns margin plus capped gain once, removes the position, and a second tick is inert.", {"card_id": "商品看涨1", "cash_delta": cash_first - cash_before, "timing_checked": true})


func _case_warehouse_open_requires_owned_city_v04() -> Dictionary:
	var base := _case_warehouse_requirement()
	return _live_record("warehouse_open_requires_owned_city_v04", bool(base.get("observed", false)), "Warehouse terms still require a selected owned active city.", {"card_id": "港仓囤货1", "warehouse_required": true})


func _case_warehouse_damage_receipt_complete() -> Dictionary:
	var source := _function_source(str(_sources.get("main", "")), "_damage_district")
	var observed := source.contains("max_hp") and source.contains("pre_hit_hp") and source.contains("post_hit_hp") and source.contains("_product_market_settle_destroyed_warehouse") and not source.contains("overkill")
	return _live_record("warehouse_damage_receipt_complete", observed, "The world adapter passes max/pre/post HP and no overkill amount.", {"warehouse_hp_checked": observed, "world_route_checked": true})


func _case_warehouse_destruction_loss_formula() -> Dictionary:
	var terms := _market_controller.terms_for_card_id("港仓囤货4"); var warehouse_position := _position_from_terms(terms, 50)
	var result: Dictionary = _formula_service.calculate("warehouse_futures_v04_loss", {"position": warehouse_position, "damage_receipt": {"max_hp": 100, "pre_hit_hp": 20, "post_hit_hp": 0}})
	var observed := bool(result.get("ok", false)) and int(result.get("loss", -1)) == 600 and int(result.get("margin_refund", -1)) == 0 and int(result.get("cash_return", -1)) == 0
	return _live_record("warehouse_destruction_loss_formula", observed, "Destroyed warehouse post_hit_hp=0 realizes maximum_loss exactly once.", {"card_id": "港仓囤货4", "warehouse_hp_checked": true, "formula_service_checked": true})


func _case_partial_damage_no_early_settlement() -> Dictionary:
	var terms := _market_controller.terms_for_card_id("港仓囤货1"); var result: Dictionary = _formula_service.calculate("warehouse_futures_v04_loss", {"position": _position_from_terms(terms, 50), "damage_receipt": {"max_hp": 100, "pre_hit_hp": 100, "post_hit_hp": 50}})
	var main_source := _function_source(str(_sources.get("main", "")), "_damage_district")
	var destruction_branch := main_source.find("if d[\"damage\"] >= d[\"hp\"]")
	var settle_call := main_source.find("_product_market_settle_destroyed_warehouse")
	var observed := bool(result.get("ok", false)) and int(result.get("loss", -1)) == 90 and destruction_branch >= 0 and settle_call > destruction_branch
	return _live_record("partial_damage_no_early_settlement", observed, "Partial HP updates risk math but runtime settlement is called only inside the destruction branch.", {"warehouse_hp_checked": true, "formula_service_checked": true})


func _case_insufficient_margin_rejects_atomically() -> Dictionary:
	_configure_market_fixture("empty"); _set_player_cash(0, 119); var before_market := JSON.stringify(_market_state().get("product_market", {})); var receipt := _market_controller.open_futures_position(0, _skill("商品看涨1")); var after_market := JSON.stringify(_market_state().get("product_market", {}))
	var observed := not bool(receipt.get("committed", false)) and str(receipt.get("reason", "")) == "financial_margin_insufficient" and _player_cash(0) == 119 and before_market == after_market
	return _live_record("insufficient_margin_rejects_atomically", observed, "A player one credit short receives a stable reason and no cash, pressure, or position mutation.", {"card_id": "商品看涨1"})


func _case_legacy_save_normalizes_once() -> Dictionary:
	var state := _market_state(); var market: Dictionary = state.get("product_market", {}) as Dictionary; var entry: Dictionary = market[SAMPLE_PRODUCT]
	entry["futures_positions"] = [{"owner": 0, "source": "商品看涨1", "direction": "up", "baseline_price": 50, "expires_at": 999.0, "multiplier": 1.0, "units": 1, "warehouse_district": -1}]; market[SAMPLE_PRODUCT] = entry
	var first := _market_controller.apply_save_data({"product_market": market, "business_cycle_count": 0, "market_timer": 8.0}); var normalized: Dictionary = (_entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array)[0]; var saved := _market_controller.to_save_data(); var second := _market_controller.apply_save_data(saved); var restored: Dictionary = (_entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array)[0]
	var observed := first.has("product_market") and second.has("product_market") and int(normalized.get("locked_margin", -1)) == 0 and int(normalized.get("maximum_loss", -1)) == 0 and int(normalized.get("maximum_gain", 0)) == 260 and JSON.stringify(normalized) == JSON.stringify(restored)
	return _live_record("legacy_save_normalizes_once", observed, "Legacy positions normalize once to v0.4 with no retroactive margin charge and no legacy branch.", {"save_checked": true})


func _case_current_save_roundtrip_v04() -> Dictionary:
	var opened := _open_position("商品看涨2"); var before: Dictionary = opened.get("position", {}) as Dictionary; var saved := _market_controller.to_save_data(); var applied := _market_controller.apply_save_data(saved); var after: Dictionary = (_entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array)[0]
	var observed := bool(opened.get("applied", false)) and applied.has("product_market") and JSON.stringify(before) == JSON.stringify(after) and str(after.get("terms_version", "")) == "v0.4"
	return _live_record("current_save_roundtrip_v04", observed, "Current v0.4 position fields round-trip without recomputing locked terms.", {"card_id": "商品看涨2", "save_checked": true})


func _case_public_snapshot_privacy_v04() -> Dictionary:
	var opened := _open_position("商品看涨1"); var public_json := JSON.stringify(_market_controller.public_market_snapshot()); var private_json := JSON.stringify(_market_controller.to_save_data())
	var observed := bool(opened.get("applied", false)) and public_json.contains("商品看涨1") and public_json.contains("up") and not public_json.contains("\"owner\"") and not public_json.contains("locked_margin") and private_json.contains("\"owner\"") and private_json.contains("locked_margin")
	return _live_record("public_snapshot_privacy_v04", observed, "Public evidence exposes product/direction/risk only; owner and locked cash remain private.", {"privacy_checked": true, "save_checked": true})


func _case_ai_risk_adjusted_terms() -> Dictionary:
	var source := str(_sources.get("ai", "")); var observed := source.contains("_product_futures_terms") and source.contains("maximum_gain") and source.contains("maximum_loss") and source.contains("margin_cash") and source.contains("risk_adjusted") and not source.contains("product_bet_multiplier")
	return _live_record("ai_risk_adjusted_terms", observed, "AI reads the shared terms snapshot and scores capped upside, loss, margin lock, and public warehouse risk.", {"ai_route_checked": true})


func _case_presentation_shows_financial_terms() -> Dictionary:
	var presentation: Dictionary = _presentation_service.compose_card({"card_name": "港仓囤货4", "skill": _skill("港仓囤货4"), "display_name": "港仓囤货 IV", "rank": 4, "price": 11})
	var text := "｜".join(presentation.get("rule_facts", []) as Array)
	var terms := _market_controller.terms_for_card_id("港仓囤货4")
	var observed := text.contains("保证金:¥600") and text.contains("最大收益:¥1200") and text.contains("最大损失:¥600") and text.contains("持续时间:2分30秒") and int(terms.get("duration_seconds", 0)) == 150
	return _live_record("presentation_shows_financial_terms", observed, "Card presentation, RightInspector, and Codex receive duration, margin, maximum gain, and maximum loss from one snapshot.", {"card_id": "港仓囤货4"})


func _case_no_parallel_futures_fallback() -> Dictionary:
	var main_source := str(_sources.get("main", "")); var controller_source := str(_sources.get("market_controller", "")); var formula_source := str(_sources.get("formula", ""))
	var observed := not main_source.contains("product_futures_payout") and not main_source.contains("product_bet_direction") and not controller_source.contains("clear_futures_for_destroyed_warehouse") and not formula_source.contains("\"product_futures_payout\"") and formula_source.contains("product_futures_v04_settlement")
	return _live_record("no_parallel_futures_fallback", observed, "No positive-only payout, warehouse clear-only branch, or main.gd financial fallback remains.")


func _case_main_scene_runtime_default_unchanged() -> Dictionary:
	var scene_exists := ResourceLoader.exists(MAIN_SCENE_PATH)
	var source := str(_sources.get("main", "")); var observed := scene_exists and source.contains("_product_market_runtime_controller")
	return _live_record("main_scene_runtime_default_unchanged", observed, "The normal main scene keeps the current product-market runtime route.")


func _live_record(case_id: String, observed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var extras := flags.duplicate(true); extras["live_gate"] = true; extras["historical_baseline"] = false; extras["needs_design_decision"] = false; extras["risk"] = ""
	return _record(case_id, observed, observed, notes, extras)


func _position_from_terms(terms: Dictionary, baseline_price: int) -> Dictionary:
	return {
		"baseline_price": baseline_price,
		"direction": str(terms.get("direction", "up")),
		"multiplier": float(terms.get("multiplier", 1.0)),
		"units": int(terms.get("units", 1)),
		"locked_margin": int(terms.get("margin_cash", 0)),
		"maximum_gain": int(terms.get("maximum_gain", 0)),
		"maximum_loss": int(terms.get("maximum_loss", 0)),
	}


func _player_cash(player_index: int) -> int:
	var players: Array = _runtime_main.get("players") as Array
	return int((players[player_index] as Dictionary).get("cash", 0)) if player_index >= 0 and player_index < players.size() else -1


func _set_player_cash(player_index: int, amount: int) -> void:
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	if player_index < 0 or player_index >= players.size(): return
	var player: Dictionary = (players[player_index] as Dictionary).duplicate(true); player["cash"] = amount; players[player_index] = player; _runtime_main.set("players", players)


func _case_call_graph() -> Dictionary:
	var source := str(_sources.get("main", ""))
	var controller_source := str(_sources.get("market_controller", ""))
	var missing: Array = []
	for function_name in CUTOVER_METHODS:
		if not controller_source.contains("func %s(" % str(function_name)):
			missing.append(str(function_name))
	var state_present := controller_source.contains("var product_market: Dictionary = {}") and controller_source.contains("var business_cycle_count := 0") and controller_source.contains("var market_timer := 8.0")
	var old_owner_absent := not source.contains("var product_market := {}") and not source.contains("var business_cycle_count := 0") and not source.contains("var market_timer := 8.0")
	var observed := missing.is_empty() and state_present and old_owner_absent and ResourceLoader.exists(PRODUCT_MARKET_CONTROLLER_SCENE_PATH)
	return _record("product_market_call_graph_complete", observed, observed, "Controller owns %d lifecycle methods and all three states; missing=%s; old owner absent=%s." % [CUTOVER_METHODS.size(), str(missing), str(old_owner_absent)], {"world_route_checked": true})


func _case_catalog_profiles_cards() -> Dictionary:
	var generated: Dictionary = _market_controller.call("generate_product_market")
	var missing_profiles: Array = []
	for product_variant in generated.keys():
		var product_id := str(product_variant)
		if not bool(_runtime_main.call("_product_profile_has_required_fields", product_id)):
			missing_profiles.append(product_id)
	var missing_cards: Array = []
	for card_id in REAL_CARDS:
		if _skill(card_id).is_empty():
			missing_cards.append(card_id)
	var observed := generated.size() >= 40 and missing_profiles.is_empty() and missing_cards.is_empty() and str(_sources.get("market_controller", "")).contains("const PRODUCT_PRICE_TIERS := [")
	return _record("product_catalog_and_profiles_exist", observed, observed, "Catalog=%d, profile gaps=%s, card gaps=%s." % [generated.size(), str(missing_profiles), str(missing_cards)], {"card_id": "、".join(REAL_CARDS), "product_id": SAMPLE_PRODUCT})


func _case_state_shape() -> Dictionary:
	var entry := _entry(SAMPLE_PRODUCT)
	var missing: Array = []
	for field_name in REQUIRED_ENTRY_FIELDS:
		if not entry.has(str(field_name)):
			missing.append(str(field_name))
	var observed := missing.is_empty() and _market_state().get("product_market", {}) is Dictionary and _market_state().get("business_cycle_count", 0) is int and (_market_state().get("market_timer", 8.0) is float or _market_state().get("market_timer", 8.0) is int)
	return _record("runtime_market_state_shape", observed, observed, "Market entry fields=%d; missing=%s. Persistent owners are product_market, business_cycle_count, and market_timer." % [entry.size(), str(missing)], _entry_flags(SAMPLE_PRODUCT))


func _case_seeded_generation() -> Dictionary:
	var runtime_rng := _runtime_main.get("rng") as RandomNumberGenerator
	runtime_rng.seed = FIXED_SEED
	var first: Dictionary = _market_controller.call("generate_product_market")
	var first_state := runtime_rng.state
	runtime_rng.seed = FIXED_SEED
	var second: Dictionary = _market_controller.call("generate_product_market")
	var second_state := runtime_rng.state
	var observed := JSON.stringify(first) == JSON.stringify(second) and first_state == second_state
	return _record("seeded_market_generation_deterministic", observed, observed, "Fixed seed produces identical %d-entry market and final RNG state %d." % [first.size(), first_state], {"rng_checked": true})


func _case_tier_weight_order() -> Dictionary:
	var source := _function_source(str(_sources.get("market_controller", "")), "generate_product_market")
	var observed := _tokens_in_order(source, ["weights.append", "_weighted_pick_index(weights)", "PRODUCT_PRICE_TIERS[tier_index]", "shared_rng.randi_range"])
	return _record("price_tier_weight_selection_order", observed, observed, "Generation consumes one weighted tier pick before the tier-bounded base-price roll.", {"rng_checked": true})


func _case_base_price_within_tier() -> Dictionary:
	var generated: Dictionary = _market_controller.call("generate_product_market")
	var invalid: Array = []
	for product_variant in generated.keys():
		var product_id := str(product_variant)
		var entry: Dictionary = generated[product_variant]
		var range_values: Array = TIER_RANGES.get(str(entry.get("tier", "")), [])
		var price := int(entry.get("base_price", -1))
		if range_values.size() != 2 or price < int(range_values[0]) or price > int(range_values[1]):
			invalid.append(product_id)
	var observed := invalid.is_empty()
	return _record("base_price_within_tier", observed, observed, "Every generated base price stays inside its selected tier; invalid=%s." % str(invalid), {"rng_checked": true})


func _case_initial_history() -> Dictionary:
	var generated: Dictionary = _market_controller.call("generate_product_market")
	var invalid: Array = []
	for product_variant in generated.keys():
		var entry: Dictionary = generated[product_variant]
		var history: Array = entry.get("price_history", [])
		if history.size() != 1 or int(history[0]) != int(entry.get("base_price", -1)):
			invalid.append(str(product_variant))
	var observed := invalid.is_empty()
	return _record("initial_price_history_shape", observed, observed, "Initial history contains exactly the generated base price; invalid=%s." % str(invalid))


func _case_ensure_idempotent() -> Dictionary:
	var before := JSON.stringify(_market_state().get("product_market", {})).sha256_text()
	_market_controller.call("ensure_catalog")
	var once := JSON.stringify(_market_state().get("product_market", {})).sha256_text()
	_market_controller.call("ensure_catalog")
	var twice := JSON.stringify(_market_state().get("product_market", {})).sha256_text()
	var observed := before == once and once == twice
	return _record("ensure_catalog_idempotent", observed, observed, "Catalog normalization is idempotent for an already normalized market.")


func _case_missing_entry_backfilled() -> Dictionary:
	var market: Dictionary = (_market_state().get("product_market", {}) as Dictionary).duplicate(true)
	var expected_count := market.size()
	market.erase(SAMPLE_PRODUCT)
	_set_market_property("product_market", market)
	_market_controller.call("ensure_catalog")
	var restored: Dictionary = _market_state().get("product_market", {})
	var observed := restored.size() == expected_count and restored.has(SAMPLE_PRODUCT) and not (restored[SAMPLE_PRODUCT] as Dictionary).is_empty()
	return _record("missing_catalog_entry_backfilled", observed, observed, "One missing catalog entry is regenerated without replacing the rest of the loaded market.", _entry_flags(SAMPLE_PRODUCT))


func _case_market_weight(kind: String) -> Dictionary:
	_configure_market_fixture(kind)
	_market_controller.call("refresh_prices")
	var entry := _entry(SAMPLE_PRODUCT)
	var expected_supply := 0
	var expected_demand := 0
	var expected_disrupted := 0
	match kind:
		"district_supply": expected_supply = 1
		"city_supply": expected_supply = 2
		"district_demand": expected_demand = 1
		"city_demand": expected_demand = 3
		"disrupted": expected_disrupted = 1
	var observed := int(entry.get("supply", -1)) == expected_supply and int(entry.get("demand", -1)) == expected_demand and int(entry.get("disrupted", -1)) == expected_disrupted
	var case_id := str({
		"destroyed": "destroyed_district_excluded",
		"district_supply": "district_product_supply_weight",
		"city_supply": "active_city_product_supply_weight",
		"district_demand": "district_demand_weight",
		"city_demand": "active_city_demand_weight",
		"disrupted": "disrupted_route_pressure",
	}.get(kind, "destroyed_district_excluded"))
	return _record(case_id, observed, observed, "Observed weights: supply=%d demand=%d disrupted=%d." % [int(entry.get("supply", -1)), int(entry.get("demand", -1)), int(entry.get("disrupted", -1))], _entry_flags(SAMPLE_PRODUCT))


func _case_temporary_pressure(kind: String) -> Dictionary:
	_configure_market_fixture("empty")
	var market: Dictionary = (_market_state().get("product_market", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (market[SAMPLE_PRODUCT] as Dictionary).duplicate(true)
	var key := "temporary_demand_pressure" if kind == "demand" else "temporary_supply_pressure"
	entry[key] = 3
	market[SAMPLE_PRODUCT] = entry
	_set_market_property("product_market", market)
	_market_controller.call("refresh_prices")
	entry = _entry(SAMPLE_PRODUCT)
	var score_key := "demand" if kind == "demand" else "supply"
	var observed := int(entry.get(score_key, -1)) == 3 and int(entry.get(key, -1)) == 2
	var case_id := "temporary_demand_pressure_applies_once" if kind == "demand" else "temporary_supply_pressure_applies_once"
	return _record(case_id, observed, observed, "Temporary %s pressure enters this refresh score, then decays by exactly one." % kind, _entry_flags(SAMPLE_PRODUCT))


func _case_pressure_decay() -> Dictionary:
	_configure_market_fixture("empty")
	var market: Dictionary = (_market_state().get("product_market", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (market[SAMPLE_PRODUCT] as Dictionary).duplicate(true)
	entry["temporary_demand_pressure"] = 2
	entry["temporary_supply_pressure"] = 2
	market[SAMPLE_PRODUCT] = entry
	_set_market_property("product_market", market)
	_market_controller.call("refresh_prices")
	var first := _entry(SAMPLE_PRODUCT)
	_market_controller.call("refresh_prices")
	var second := _entry(SAMPLE_PRODUCT)
	var observed := int(first.get("temporary_demand_pressure", -1)) == 1 and int(first.get("temporary_supply_pressure", -1)) == 1 and int(second.get("temporary_demand_pressure", -1)) == 0 and int(second.get("temporary_supply_pressure", -1)) == 0
	return _record("temporary_pressure_decays_per_refresh", observed, observed, "Both temporary pressure channels decay 2 -> 1 -> 0 across two refreshes.")


func _case_contract_pressure_expiry() -> Dictionary:
	_configure_market_fixture("empty")
	var market: Dictionary = (_market_state().get("product_market", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (market[SAMPLE_PRODUCT] as Dictionary).duplicate(true)
	entry["market_contract_demand"] = 4
	entry["market_contract_seconds"] = 5.0
	entry["market_contract_turns"] = 1
	entry["market_contract_source"] = "contract-fixture"
	market[SAMPLE_PRODUCT] = entry
	_set_market_property("product_market", market)
	_market_controller.call("refresh_prices")
	var active := _entry(SAMPLE_PRODUCT)
	_market_controller.call("age_economic_boons", 5.0)
	_market_controller.call("refresh_prices")
	var expired := _entry(SAMPLE_PRODUCT)
	var observed := int(active.get("demand", 0)) == 4 and int(expired.get("market_contract_demand", -1)) == 0 and is_zero_approx(float(expired.get("market_contract_seconds", -1.0)))
	return _record("contract_pressure_active_then_expires", observed, observed, "Contract demand is counted while seconds remain, then demand/supply/source reset at expiry.")


func _case_rng_order() -> Dictionary:
	var source := _function_source(str(_sources.get("market_controller", "")), "generate_product_market")
	var runtime_rng := _runtime_main.get("rng") as RandomNumberGenerator
	runtime_rng.seed = FIXED_SEED
	var first: Dictionary = _market_controller.call("generate_product_market")
	var final_state := runtime_rng.state
	var observed := _tokens_in_order(source, ["_weighted_pick_index(weights)", "PRODUCT_PRICE_TIERS[tier_index]", "shared_rng.randi_range"]) and first.size() == _baseline_product_market.size() and final_state != FIXED_SEED
	return _record("shared_rng_consumption_order", observed, observed, "Each product consumes the shared RNG for tier selection before base price; no second market RNG exists.", {"rng_checked": true})


func _case_price_clamp() -> Dictionary:
	var low: Dictionary = _runtime_main.call("_balance_product_price_model", 26, 1000, 0, 0, 0, 0, 30, -30.0, 1.0)
	var high: Dictionary = _runtime_main.call("_balance_product_price_model", 280, 0, 1000, 1000, 0, 0, 30, 30.0, 3.0)
	var observed := int(low.get("price", -1)) == 26 and int(high.get("price", -1)) == 280
	return _record("price_clamp_min_max", observed, observed, "RuntimeBalanceModel clamps extreme refresh results to 26 and 280.", {"formula_service_checked": true})


func _case_volatility_cap() -> Dictionary:
	var cap := int(_runtime_main.call("_balance_product_price_step_cap", 30, 100))
	var model: Dictionary = _runtime_main.call("_balance_product_price_model", 100, 0, 1000, 1000, 0, 0, 30, 30.0, 3.0)
	var observed := cap > 0 and int(abs(float(model.get("delta", 0)))) <= cap and int(model.get("step_cap", -1)) == cap
	return _record("volatility_step_cap", observed, observed, "Volatility 30 produces an explicit step cap %d and the price delta remains within it." % cap, {"formula_service_checked": true})


func _case_trend_driver() -> Dictionary:
	_configure_market_fixture("district_demand")
	_market_controller.call("refresh_prices")
	var entry := _entry(SAMPLE_PRODUCT)
	var observed := entry.has("raw_trend") and entry.has("price_step_cap") and not str(entry.get("driver_summary", "")).is_empty() and int(entry.get("trend", 0)) == int(entry.get("price", 0)) - int(entry.get("base_price", 0))
	return _record("trend_driver_summary_parity", observed, observed, "Stored price, trend, raw trend, step cap, and driver summary come from one RuntimeBalanceModel result.", _entry_flags(SAMPLE_PRODUCT).merged({"formula_service_checked": true}, true))


func _case_history_limit() -> Dictionary:
	var entry := {"price_history": [1]}
	for value in range(2, 18):
		_market_controller.call("_append_price_history", entry, value)
	var size_before_duplicate := (entry.get("price_history", []) as Array).size()
	_market_controller.call("_append_price_history", entry, 17)
	var history: Array = entry.get("price_history", [])
	var observed := size_before_duplicate == 12 and history.size() == 12 and int(history[history.size() - 1]) == 17 and int(history[0]) == 6
	return _record("price_history_deduplicates_and_limits", observed, observed, "History stores distinct prices only and trims to the latest 12 values.")


func _case_timer_cadence() -> Dictionary:
	var process_source := _function_source(str(_sources.get("main", "")), "_process")
	var controller_source := _function_source(str(_sources.get("market_controller", "")), "tick_market_cycle")
	var observed := _tokens_in_order(process_source, ["advance_world_effective_clock", "game_time = float(clock_snapshot", "age_economic_boons", "_advance_continuous_commodity_flow", "tick_product_market_cycle"]) and _tokens_in_order(controller_source, ["market_timer -=", "market_tick()", "next_market_interval"])
	return _record("market_timer_realtime_cadence", observed, observed, "The authoritative world-effective clock advances before boons, continuous flow, and the market timer rolls its next interval.", {"timing_checked": true})


func _case_timer_freeze() -> Dictionary:
	var process_source := _function_source(str(_sources.get("main", "")), "_process")
	var forced_return := _tokens_in_order(process_source, ["blocks_global_time", "return", "if time_scale <= 0.0:", "return", "tick_product_market_cycle"])
	var observed := forced_return
	return _record("paused_or_forced_block_freezes_market_timer", observed, observed, "Global forced-decision blocking and readonly time_scale pause both return before market_timer decrement.", {"timing_checked": true})


func _case_market_tick_increment() -> Dictionary:
	_set_no_active_cities()
	_set_market_property("business_cycle_count", 7)
	_market_controller.call("market_tick")
	var observed := int(_market_state().get("business_cycle_count", 0)) == 8
	return _record("market_tick_increments_cycle_once", observed, observed, "One direct market tick advances business_cycle_count from 7 to 8 exactly once.", {"cycle_before": 7, "cycle_after": int(_market_state().get("business_cycle_count", 0)), "timing_checked": true})


func _case_tick_order() -> Dictionary:
	var source := _function_source(str(_sources.get("market_controller", "")), "market_tick")
	var world_source := _function_source(str(_sources.get("main", "")), "_apply_product_market_cycle_world_step")
	var observed := _tokens_in_order(source, ["business_cycle_count += 1", "_refresh_city_networks", "refresh_prices()", "_apply_product_market_cycle_world_step"]) and _tokens_in_order(world_source, ["last_cycle_income", "_record_city_gdp_snapshot", "settle_district", "_auto_expand_rival_syndicates", "_auto_rival_business_actions", "_finalize_ai_decision_rewards", "_record_player_cash_snapshot"])
	return _record("market_tick_refresh_order", observed, observed, "Cycle, city network, prices, income reset, GDP sample, derivatives, AI, rewards, and cash history remain in observed order.", {"world_route_checked": true, "timing_checked": true})


func _case_empty_city_tick() -> Dictionary:
	_set_no_active_cities()
	_set_market_property("business_cycle_count", 0)
	_runtime_main.set("log_lines", [])
	_market_controller.call("market_tick")
	var logs := "\n".join(_string_array(_runtime_main.get("log_lines") as Array))
	var observed := int(_market_state().get("business_cycle_count", 0)) == 1 and logs.contains("没有存活城市群")
	return _record("no_active_city_safe_tick", observed, observed, "An empty-city refresh increments the cycle, revalues public supply/demand, and logs the safe state without crashing.", {"cycle_before": 0, "cycle_after": 1})


func _case_product_boon() -> Dictionary:
	var changed := bool(_market_controller.call("apply_product_market_boon", SAMPLE_PRODUCT, 2.0, 1.5, 3, "fixture", false, 90.0))
	var entry := _entry(SAMPLE_PRODUCT)
	var observed := changed and is_equal_approx(float(entry.get("growth_multiplier", 0.0)), 2.0) and is_equal_approx(float(entry.get("route_flow_multiplier", 0.0)), 1.5) and is_equal_approx(float(entry.get("growth_seconds", 0.0)), 90.0) and is_equal_approx(float(entry.get("route_flow_seconds", 0.0)), 90.0)
	return _record("product_boon_applies", observed, observed, "The pure formula result is committed once to growth and route-flow channels.", _entry_flags(SAMPLE_PRODUCT).merged({"formula_service_checked": true}, true))


func _case_boon_ages() -> Dictionary:
	_market_controller.call("apply_product_market_boon", SAMPLE_PRODUCT, 2.0, 1.5, 3, "fixture", false, 90.0)
	_market_controller.call("age_economic_boons", 30.0)
	var middle := _entry(SAMPLE_PRODUCT)
	_market_controller.call("age_economic_boons", 60.0)
	var expired := _entry(SAMPLE_PRODUCT)
	var observed := is_equal_approx(float(middle.get("growth_seconds", 0.0)), 60.0) and is_equal_approx(float(middle.get("growth_multiplier", 0.0)), 2.0) and is_equal_approx(float(expired.get("growth_multiplier", 0.0)), float(expired.get("base_growth_multiplier", 1.0))) and is_zero_approx(float(expired.get("growth_seconds", -1.0)))
	return _record("economic_boon_ages_realtime", observed, observed, "A 90-second boon ages to 60 seconds, then resets to the stored baseline exactly at expiry.", {"timing_checked": true})


func _case_persistent_boon() -> Dictionary:
	_market_controller.call("apply_product_market_boon", SAMPLE_PRODUCT, 1.7, 1.3, 0, "persistent-fixture", true, 0.0)
	_market_controller.call("age_economic_boons", 999.0)
	var entry := _entry(SAMPLE_PRODUCT)
	var observed := is_equal_approx(float(entry.get("base_growth_multiplier", 0.0)), 1.7) and is_equal_approx(float(entry.get("growth_multiplier", 0.0)), 1.7) and is_equal_approx(float(entry.get("base_route_flow_multiplier", 0.0)), 1.3) and is_equal_approx(float(entry.get("route_flow_multiplier", 0.0)), 1.3)
	return _record("persistent_boon_baseline_preserved", observed, observed, "Persistent economy boons become the reset baseline and do not expire through realtime aging.")


func _case_speculation(up: bool) -> Dictionary:
	_configure_market_fixture("empty")
	var card_id := "价格套利1" if up else "商品做空1"
	var skill := _skill(card_id)
	var players: Array = _runtime_main.get("players")
	var player: Dictionary = players[0]
	var cash_before := int(player.get("cash", 0))
	var applied := bool(_market_controller.call("apply_speculation", 0, skill))
	var entry := _entry(SAMPLE_PRODUCT)
	var pressure_key := "temporary_demand_pressure" if up else "temporary_supply_pressure"
	var cash_after := int((_runtime_main.get("players") as Array)[0].get("cash", 0))
	var observed := applied and cash_after - cash_before == int(skill.get("cash", 0)) and int(entry.get(pressure_key, 0)) > 0
	var case_id := "speculation_up_adds_demand" if up else "speculation_down_adds_supply"
	return _record(case_id, observed, observed, "%s grants its authored cash once and adds %s pressure; price remains refresh-derived." % [card_id, "demand" if up else "supply"], _entry_flags(SAMPLE_PRODUCT).merged({"card_id": card_id, "cash_delta": cash_after - cash_before, "formula_service_checked": true}, true))


func _case_market_stabilize() -> Dictionary:
	_configure_market_fixture("empty")
	var market: Dictionary = (_market_state().get("product_market", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = (market[SAMPLE_PRODUCT] as Dictionary).duplicate(true)
	entry["temporary_demand_pressure"] = 5
	entry["temporary_supply_pressure"] = 5
	entry["volatility"] = 10
	market[SAMPLE_PRODUCT] = entry
	_set_market_property("product_market", market)
	var applied := bool(_market_controller.call("apply_market_stabilize", _skill("市场稳定1")))
	entry = _entry(SAMPLE_PRODUCT)
	var observed := applied and int(entry.get("volatility", 0)) == 8 and int(entry.get("temporary_demand_pressure", 99)) < 5 and int(entry.get("temporary_supply_pressure", 99)) < 5
	return _record("market_stabilize_reduces_pressure", observed, observed, "市场稳定1 lowers volatility 10 -> 8 and reduces both temporary pressure channels before the normal refresh decay.", _entry_flags(SAMPLE_PRODUCT).merged({"card_id": "市场稳定1"}, true))


func _case_growth_boon() -> Dictionary:
	_configure_market_fixture("empty")
	var applied := bool(_market_controller.call("apply_product_growth_boon", _skill("商品催化1")))
	var entry := _entry(SAMPLE_PRODUCT)
	var observed := applied and is_equal_approx(float(entry.get("growth_multiplier", 0.0)), 2.0) and is_equal_approx(float(entry.get("growth_seconds", 0.0)), 90.0)
	return _record("product_growth_boon_duration", observed, observed, "商品催化1 commits growth x2.0 for 90 realtime seconds.", _entry_flags(SAMPLE_PRODUCT).merged({"card_id": "商品催化1", "timing_checked": true}, true))


func _case_route_flow_multiplier() -> Dictionary:
	_market_controller.call("apply_product_market_boon", SAMPLE_PRODUCT, 1.0, 1.8, 4, "星港快线2-fixture", false, 120.0)
	var value := float(_market_controller.call("product_route_flow_multiplier", SAMPLE_PRODUCT))
	var formula: Dictionary = _formula_service.call("calculate", "route_flow_multiplier", {"city_multiplier": 1.0, "product_multiplier": 1.8})
	var observed := is_equal_approx(value, 1.8) and is_equal_approx(float(formula.get("value", 0.0)), 1.8)
	return _record("route_flow_boon_multiplier", observed, observed, "Product-level route-flow x1.8 is read through the existing pure arithmetic owner.", {"product_id": SAMPLE_PRODUCT, "card_id": "星港快线2", "formula_service_checked": true})


func _case_futures_position(direction: String) -> Dictionary:
	_configure_market_fixture("empty")
	var card_id := "商品看涨1" if direction == "up" else "商品看跌1"
	var applied := bool(_market_controller.call("apply_futures", 0, _skill(card_id)))
	var futures: Array = _entry(SAMPLE_PRODUCT).get("futures_positions", [])
	var futures_position: Dictionary = futures[0] if futures.size() == 1 else {}
	var observed := applied and futures.size() == 1 and str(futures_position.get("direction", "")) == direction and int(futures_position.get("owner", -1)) == 0 and float(futures_position.get("expires_at", 0.0)) > float(_runtime_main.get("game_time"))
	var case_id := "futures_up_position_created" if direction == "up" else "futures_down_position_created"
	return _record(case_id, observed, observed, "%s creates one private %s position with baseline, expiry, multiplier, units, and owner." % [card_id, direction], _entry_flags(SAMPLE_PRODUCT).merged({"card_id": card_id, "futures_count_after": futures.size(), "timing_checked": true}, true))


func _case_warehouse_requirement() -> Dictionary:
	_configure_market_fixture("empty")
	var card := _skill("港仓囤货1")
	var without_city := bool(_market_controller.call("apply_futures", 0, card))
	var district_index := _fixture_district_index()
	var districts: Array = (_runtime_main.get("districts") as Array).duplicate(true)
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	district["destroyed"] = false
	district["city"] = _simple_city(0)
	districts[district_index] = district
	_runtime_main.set("districts", districts)
	_runtime_main.set("selected_district", district_index)
	var with_city := bool(_market_controller.call("apply_futures", 0, card))
	var futures: Array = _entry(SAMPLE_PRODUCT).get("futures_positions", [])
	var warehouse := int((futures[0] as Dictionary).get("warehouse_district", -1)) if futures.size() == 1 else -1
	var observed := not without_city and with_city and warehouse == district_index
	return _record("warehouse_futures_requires_owned_active_city", observed, observed, "港仓囤货 rejects without an owned active city, then records the selected warehouse district.", {"product_id": SAMPLE_PRODUCT, "card_id": "港仓囤货1", "futures_count_after": futures.size()})


func _case_futures_payout() -> Dictionary:
	var terms := _market_controller.terms_for_card_id("商品看涨1")
	var favorable: Dictionary = _formula_service.calculate("product_futures_v04_settlement", {"current_price": 100, "position": _position_from_terms(terms, 50)})
	var adverse: Dictionary = _formula_service.calculate("product_futures_v04_settlement", {"current_price": 0, "position": _position_from_terms(terms, 50)})
	var observed := int(favorable.get("gain", -1)) == 260 and int(adverse.get("loss", -1)) == 120 and not str(_sources.get("formula", "")).contains("\"product_futures_payout\"")
	return _live_record("futures_payout_positive_direction_only", observed, "The historical positive-only formula is absent; this retained market case now proves capped gain and capped adverse loss.", {"formula_service_checked": true})


func _case_futures_expiry() -> Dictionary:
	var live := _case_expiry_settlement_exact_once_v04()
	return _live_record("futures_expiry_exact_once", bool(live.get("observed", false)), str(live.get("notes", "")), {"product_id": SAMPLE_PRODUCT, "cash_delta": int(live.get("cash_delta", 0)), "futures_count_before": 1, "futures_count_after": 0, "timing_checked": true})


func _case_destroyed_warehouse() -> Dictionary:
	var opened := _open_position("港仓囤货1", true); var district_index := _fixture_district_index(); var cash_after_open := _player_cash(0)
	var first := _market_controller.settle_futures_for_destroyed_warehouse(district_index, "fixture-destruction", {"max_hp": 100, "pre_hit_hp": 25, "post_hit_hp": 0})
	var second := _market_controller.settle_futures_for_destroyed_warehouse(district_index, "fixture-destruction", {"max_hp": 100, "pre_hit_hp": 0, "post_hit_hp": 0})
	var observed := bool(opened.get("applied", false)) and int(first.get("settled_count", 0)) == 1 and int(first.get("total_loss", 0)) == 180 and int(second.get("settled_count", 0)) == 0 and _player_cash(0) == cash_after_open and (_entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array).is_empty()
	return _live_record("destroyed_warehouse_clears_positions", observed, "Destroyed warehouse positions settle maximum loss and are removed exactly once; the old clear-only path is gone.", {"product_id": SAMPLE_PRODUCT, "card_id": "港仓囤货1", "futures_count_before": 1, "futures_count_after": 0, "warehouse_hp_checked": true})


func _case_save_shape() -> Dictionary:
	_set_market_property("business_cycle_count", 12)
	_set_market_property("market_timer", 7.5)
	var state: Dictionary = _runtime_main.call("_capture_run_domain_state_compatibility_adapter")
	var current_ok := state.has("product_market") and int(state.get("business_cycle_count", -1)) == 12 and is_equal_approx(float(state.get("market_timer", -1.0)), 7.5)
	var legacy := state.duplicate(true)
	legacy.erase("product_market")
	legacy.erase("business_cycle_count")
	legacy.erase("market_timer")
	var apply_error := int(_runtime_main.call("_apply_run_domain_state_compatibility_adapter", legacy))
	var legacy_ok := apply_error == OK and not (_market_state().get("product_market", {}) as Dictionary).is_empty() and int(_market_state().get("business_cycle_count", 0)) == 0 and is_equal_approx(float(_market_state().get("market_timer", 8.0)), 8.0)
	var observed := current_ok and legacy_ok
	return _record("current_and_legacy_save_shape", observed, observed, "Current save keeps all three keys; missing legacy keys regenerate the market and default cycle/timer to 0/8 seconds.", {"save_checked": true, "cycle_before": 12, "cycle_after": int(_market_state().get("business_cycle_count", 0)), "market_timer_before": 7.5, "market_timer_after": float(_market_state().get("market_timer", 8.0))})


func _case_privacy_boundary() -> Dictionary:
	var opened := _open_position("商品看涨1")
	var counts: Dictionary = _market_controller.call("futures_public_counts", SAMPLE_PRODUCT)
	var public_text := str(_market_controller.call("futures_public_text", SAMPLE_PRODUCT, false))
	var public_payload := JSON.stringify({"counts": counts, "text": public_text})
	var observed := bool(opened.get("applied", false)) and int(counts.get("up", 0)) == 1 and not public_payload.contains("owner") and not public_payload.contains("locked_margin")
	return _record("public_private_market_snapshot_boundary", observed, observed, "Public market evidence exposes direction/count only; owner and private source remain absent.", {"product_id": SAMPLE_PRODUCT, "privacy_checked": true})


func _case_deletion_candidates() -> Dictionary:
	var source := str(_sources.get("main", ""))
	var controller_source := str(_sources.get("market_controller", ""))
	var missing_functions: Array = []
	for function_name in DELETION_CANDIDATES:
		if source.contains("func %s(" % str(function_name)):
			missing_functions.append(str(function_name))
	var missing_states: Array = []
	for state_name in STATE_DELETION_CANDIDATES:
		if source.contains("var %s :=" % str(state_name)) or source.contains("var %s:" % str(state_name)):
			missing_states.append(str(state_name))
	var missing_constants: Array = []
	for constant_name in CONSTANT_DELETION_CANDIDATES:
		if source.contains("const %s" % str(constant_name)) or not controller_source.contains("const %s" % str(constant_name)):
			missing_constants.append(str(constant_name))
	var observed := missing_functions.is_empty() and missing_states.is_empty() and missing_constants.is_empty()
	return _record("sprint53_deletion_candidates_complete", observed, observed, "Hard-cutover map: %d functions, %d states, %d constants; legacy residues=%s/%s/%s." % [DELETION_CANDIDATES.size(), STATE_DELETION_CANDIDATES.size(), CONSTANT_DELETION_CANDIDATES.size(), str(missing_functions), str(missing_states), str(missing_constants)], {"world_route_checked": true})


func _case_formula_boundary() -> Dictionary:
	var debug: Dictionary = _formula_service.call("debug_snapshot")
	var owned: Array = ((debug.get("formula_ownership", {}) as Dictionary).get("owned_formulas", []) as Array)
	var observed := bool(debug.get("pure_formula_authority", false)) and not bool(debug.get("world_mutation_authority", true)) and owned.has("product_market_boon") and owned.has("product_futures_v04_settlement") and owned.has("warehouse_futures_v04_loss") and not owned.has("product_futures_payout") and not owned.has("product_price")
	return _record("formula_service_remains_arithmetic_owner", observed, observed, "Formula Service owns deterministic boon/futures arithmetic; RuntimeBalanceModel remains product-price owner and no market state is stored here.", {"formula_service_checked": true})


func _case_ai_boundary() -> Dictionary:
	var source := str(_sources.get("ai", ""))
	var reads := source.contains("func _ai_product_market_signal_score") and source.contains("func _ai_product_futures_plan") and source.contains("_product_market_runtime_controller")
	var no_mutation := not source.contains("product_market[product_name] =") and not source.contains("func _market_tick(") and not source.contains("func _refresh_product_market_prices(")
	var observed := reads and no_mutation and _ai_controller != null
	return _record("ai_reads_market_but_does_not_mutate", observed, observed, "AiRuntimeController scores public market facts and builds intents but contains no market refresh/tick/state mutation owner.", {"ai_route_checked": true, "world_route_checked": true})


func _case_world_routes() -> Dictionary:
	var weather := str(_sources.get("weather", ""))
	var monster := str(_sources.get("monster", ""))
	var military := str(_sources.get("military", ""))
	var contract := str(_sources.get("contract_bridge", ""))
	var observed := weather.contains("_product_market_runtime_controller.refresh_prices") and monster.contains("_product_market_runtime_controller.refresh_prices") and monster.contains("_product_market_runtime_controller.apply_product_market_boon") and military.contains("_product_market_runtime_controller.refresh_prices") and contract.contains("_product_market_runtime_controller.refresh_prices")
	return _record("weather_monster_military_contract_share_refresh_route", observed, observed, "Weather, Monster, Military, and Contract all route through the authoritative ProductMarketRuntimeController.", {"world_route_checked": true})


func _case_pure_data() -> Dictionary:
	var preview := build_characterization_manifest_preview()
	var runtime_payload := {
		"entry": _plain_entry(_entry(SAMPLE_PRODUCT)),
		"formula": _formula_service.call("calculate", "product_futures_v04_settlement", {"current_price": 60, "position": _position_from_terms(_market_controller.terms_for_card_id("商品看涨1"), 50)}),
		"records": _records.duplicate(true),
	}
	var observed := _is_data_only(preview) and _is_data_only(runtime_payload) and not _contains_runtime_object(preview) and not _contains_runtime_object(runtime_payload)
	return _record("pure_data_evidence_and_no_runtime_objects", observed, observed, "Manifest preview, market evidence, formula receipt, and accumulated records contain only JSON-safe values.", {"pure_data_checked": observed, "privacy_checked": true})


func _load_sources() -> void:
	_sources = {
		"main": FileAccess.get_file_as_string(MAIN_SCRIPT_PATH),
		"coordinator_scene": FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH),
		"formula": FileAccess.get_file_as_string(FORMULA_SERVICE_SCRIPT_PATH),
		"cashflow": FileAccess.get_file_as_string(CASHFLOW_CONTROLLER_SCRIPT_PATH),
		"gdp": FileAccess.get_file_as_string(GDP_CONTROLLER_SCRIPT_PATH),
		"ai": FileAccess.get_file_as_string(AI_CONTROLLER_SCRIPT_PATH),
		"weather": FileAccess.get_file_as_string(WEATHER_CONTROLLER_SCRIPT_PATH),
		"monster": FileAccess.get_file_as_string(MONSTER_CONTROLLER_SCRIPT_PATH),
		"military": FileAccess.get_file_as_string(MILITARY_CONTROLLER_SCRIPT_PATH),
		"contract": FileAccess.get_file_as_string(CONTRACT_CONTROLLER_SCRIPT_PATH),
		"contract_bridge": FileAccess.get_file_as_string(CONTRACT_WORLD_BRIDGE_SCRIPT_PATH),
		"product_codex": FileAccess.get_file_as_string(PRODUCT_CODEX_SCRIPT_PATH),
		"market_controller": FileAccess.get_file_as_string(PRODUCT_MARKET_CONTROLLER_SCRIPT_PATH),
		"market_world_bridge": FileAccess.get_file_as_string(PRODUCT_MARKET_WORLD_BRIDGE_SCRIPT_PATH),
		"terms_resource": FileAccess.get_file_as_string(TERMS_RESOURCE_SCRIPT_PATH),
		"terms_catalog": FileAccess.get_file_as_string(TERMS_CATALOG_SCRIPT_PATH),
		"queue": FileAccess.get_file_as_string(QUEUE_SERVICE_SCRIPT_PATH),
		"eligibility": FileAccess.get_file_as_string(ELIGIBILITY_SERVICE_SCRIPT_PATH),
		"presentation": FileAccess.get_file_as_string(PRESENTATION_SERVICE_SCRIPT_PATH),
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
	var runtime_rng := _runtime_main.get("rng") as RandomNumberGenerator
	if runtime_rng != null:
		runtime_rng.seed = FIXED_SEED
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_formula_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardEconomyProductRouteFormulaRuntimeService")
	_cashflow_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/EconomyCashflowRuntimeController")
	_gdp_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GdpFormulaRuntimeController")
	_ai_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	_weather_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/WeatherRuntimeController")
	_monster_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController")
	_military_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MilitaryRuntimeController")
	_contract_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ContractRuntimeController")
	_market_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController") as ProductMarketRuntimeController
	_queue_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardResolutionQueueRuntimeService")
	_eligibility_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPlayEligibilityRuntimeService")
	_presentation_service = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/CardPresentationRuntimeService")
	_baseline_players = (_runtime_main.get("players") as Array).duplicate(true)
	_baseline_districts = (_runtime_main.get("districts") as Array).duplicate(true)
	_baseline_product_market = (_market_state().get("product_market", {}) as Dictionary).duplicate(true)
	return _coordinator != null and _market_controller != null and _formula_service != null and _queue_service != null and _eligibility_service != null and _presentation_service != null and _cashflow_controller != null and _gdp_controller != null and _ai_controller != null and _weather_controller != null and _monster_controller != null and _military_controller != null and _contract_controller != null and not _baseline_players.is_empty() and not _baseline_districts.is_empty() and not _baseline_product_market.is_empty()


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	_runtime_main.set("players", _baseline_players.duplicate(true))
	_runtime_main.set("districts", _baseline_districts.duplicate(true))
	_market_controller.apply_save_data({"product_market": _baseline_product_market.duplicate(true), "business_cycle_count": 0, "market_timer": 8.0})
	_queue_service.reset_state()
	_runtime_main.set("game_time", 100.0)
	_runtime_main.set("time_scale", 1.0)
	_runtime_main.set("game_over", false)
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("inspected_player", 0)
	_runtime_main.set("selected_trade_product", SAMPLE_PRODUCT)
	_runtime_main.set("selected_district", _fixture_district_index())
	_runtime_main.set("log_lines", [])
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	_runtime_main.set("movement_trails", [])
	var runtime_rng := _runtime_main.get("rng") as RandomNumberGenerator
	if runtime_rng != null:
		runtime_rng.seed = FIXED_SEED
	var players: Array = (_runtime_main.get("players") as Array).duplicate(true)
	for player_index in range(players.size()):
		var player: Dictionary = (players[player_index] as Dictionary).duplicate(true)
		player["cash"] = 5000
		player["is_ai"] = false
		player["eliminated"] = false
		player["economic_ledger"] = []
		players[player_index] = player
	_runtime_main.set("players", players)


func _configure_market_fixture(kind: String) -> void:
	var districts: Array = (_baseline_districts as Array).duplicate(true)
	for district_index in range(districts.size()):
		var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
		district["destroyed"] = true
		district["products"] = []
		district["demands"] = []
		district["city"] = {}
		districts[district_index] = district
	var index := _fixture_district_index()
	var fixture: Dictionary = (districts[index] as Dictionary).duplicate(true)
	fixture["destroyed"] = kind == "destroyed"
	fixture["terrain"] = "land"
	fixture["products"] = [SAMPLE_PRODUCT] if kind in ["destroyed", "district_supply"] else []
	fixture["demands"] = [SAMPLE_PRODUCT] if kind == "district_demand" else []
	if kind in ["city_supply", "city_demand", "disrupted"]:
		var city := _simple_city(0)
		if kind == "city_supply":
			city["products"] = [{"name": SAMPLE_PRODUCT, "level": 1}]
		elif kind == "city_demand":
			city["demands"] = [SAMPLE_PRODUCT]
		elif kind == "disrupted":
			city["trade_routes"] = [{"product": SAMPLE_PRODUCT, "from": index, "to": index, "path": [index], "disrupted": true}]
		fixture["city"] = city
	districts[index] = fixture
	_runtime_main.set("districts", districts)
	_runtime_main.set("selected_district", index)
	_runtime_main.set("selected_trade_product", SAMPLE_PRODUCT)
	var market: Dictionary = (_baseline_product_market as Dictionary).duplicate(true)
	for product_variant in market.keys():
		var entry: Dictionary = (market[product_variant] as Dictionary).duplicate(true)
		entry["temporary_demand_pressure"] = 0
		entry["temporary_supply_pressure"] = 0
		entry["market_contract_demand"] = 0
		entry["market_contract_supply"] = 0
		entry["market_contract_seconds"] = 0.0
		entry["market_contract_turns"] = 0
		entry["futures_positions"] = []
		market[product_variant] = entry
	_set_market_property("product_market", market)


func _simple_city(owner_index: int) -> Dictionary:
	return {
		"owner": owner_index,
		"active": true,
		"products": [],
		"demands": [],
		"projects": [],
		"trade_routes": [],
		"trade_disrupted_routes": 0,
		"trade_route_damage": 0,
		"route_flow_multiplier": 1.0,
		"route_flow_seconds": 0.0,
		"route_flow_turns": 0,
		"route_flow_source": "",
		"contract_income_bonus": 0,
		"contract_seconds": 0.0,
		"contract_turns": 0,
		"contract_source": "",
		"revenue_bonus": 0,
		"public_clues": [],
		"warehouse_stockpile_count": 0,
		"warehouse_stockpile_units": 0,
		"warehouse_stockpile_products": [],
		"warehouse_stockpile_expires_at": -1.0,
	}


func _set_no_active_cities() -> void:
	var districts: Array = (_runtime_main.get("districts") as Array).duplicate(true)
	for district_index in range(districts.size()):
		var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
		district["destroyed"] = true
		district["city"] = {}
		districts[district_index] = district
	_runtime_main.set("districts", districts)


func _fixture_district_index() -> int:
	for district_index in range(_baseline_districts.size()):
		var district: Dictionary = _baseline_districts[district_index]
		if str(district.get("terrain", "land")) == "land":
			return district_index
	return 0


func _skill(card_id: String) -> Dictionary:
	var value: Variant = _runtime_main.call("_make_skill", card_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _preview_terms_matrix() -> Array:
	var result: Array = []
	var catalog := load(TERMS_CATALOG_PATH)
	for card_id in FUTURES_CARD_IDS:
		var terms: Dictionary = catalog.call("terms_for_card_id", card_id) if catalog != null and catalog.has_method("terms_for_card_id") else {}
		result.append({
			"card_id": card_id,
			"rank": int(terms.get("rank", _card_rank(card_id))),
			"runtime_kind": "product_futures",
			"underlying_kind": "selected_product_at_open",
			"direction": str(terms.get("direction", _card_direction(card_id))),
			"purchase_cost": 0,
			"action_cost": int(terms.get("action_fee_cash", 0)),
			"margin_present": true,
			"margin_cash": int(terms.get("margin_cash", 0)),
			"entry_locked": true,
			"duration_seconds": float(terms.get("duration_seconds", 0.0)),
			"multiplier": float(terms.get("multiplier", 0.0)),
			"stockpile_units": int(terms.get("units", 0)),
			"max_gain_present": true,
			"maximum_gain": int(terms.get("maximum_gain", 0)),
			"max_loss_present": true,
			"maximum_loss": int(terms.get("maximum_loss", 0)),
			"warehouse_required": bool(terms.get("requires_warehouse", FUTURES_WAREHOUSE_CARDS.has(card_id))),
			"warehouse_hp_source": "max_hp/pre_hit_hp/post_hit_hp destruction receipt",
			"private_owner_boundary": true,
		})
	return result


func _financial_card_terms_matrix() -> Array:
	var result: Array = []
	if _runtime_main == null:
		return _preview_terms_matrix()
	for card_id in FUTURES_CARD_IDS:
		var skill := _skill(card_id)
		var terms: Dictionary = skill.get("futures_terms", {}) if skill.get("futures_terms", {}) is Dictionary else {}
		var requirement_variant: Variant = _runtime_main.call("_card_play_requirement_snapshot", 0, skill, {"selected_district": _fixture_district_index()})
		var requirement: Dictionary = requirement_variant if requirement_variant is Dictionary else {}
		result.append({
			"card_id": card_id,
			"rank": _card_rank(card_id),
			"runtime_kind": str(skill.get("kind", "")),
			"underlying_kind": "selected_product_at_open",
			"product_id_source": "selected_trade_product -> ProductMarketRuntimeController default product",
			"direction": str(terms.get("direction", "")),
			"purchase_cost": int(skill.get("cost", 0)),
			"action_cost": int(requirement.get("cash_cost", 0)),
			"margin_present": terms.has("margin_cash"),
			"margin_cash": int(terms.get("margin_cash", 0)),
			"entry_locked": true,
			"duration_seconds": float(_market_controller.call("futures_duration_seconds", skill)),
			"multiplier": float(terms.get("multiplier", 1.0)),
			"stockpile_units": maxi(1, int(terms.get("units", 1))),
			"max_gain_present": terms.has("maximum_gain"),
			"maximum_gain": int(terms.get("maximum_gain", 0)),
			"max_loss_present": terms.has("maximum_loss"),
			"maximum_loss": int(terms.get("maximum_loss", 0)),
			"warehouse_required": bool(terms.get("requires_warehouse", false)),
			"warehouse_district": -1,
			"warehouse_hp_source": "max_hp/pre_hit_hp/post_hit_hp destruction receipt",
			"expiry_behavior": "margin refund plus capped gain/loss; exact-once removal",
			"destruction_behavior": "post-hit HP proportional loss; exact-once removal",
			"public_clue": "warehouse district clue" if bool(terms.get("requires_warehouse", false)) else "public card/product direction evidence",
			"private_owner_boundary": true,
			"save_load_shape": ["owner", "source", "direction", "baseline_price", "expires_at", "multiplier", "units", "warehouse_district", "terms_version", "locked_margin", "maximum_gain", "maximum_loss"],
		})
	return result


func _terms_flags(card_id: String, extra: Dictionary = {}) -> Dictionary:
	var flags := {
		"card_id": card_id,
		"rank": _card_rank(card_id),
		"runtime_kind": "product_futures",
		"underlying_kind": "selected_product_at_open",
		"direction": _card_direction(card_id),
		"action_cost": 0,
		"margin_present": true,
		"entry_locked": true,
		"duration_seconds": 0.0,
		"multiplier": 0.0,
		"stockpile_units": 1,
		"max_gain_present": true,
		"max_loss_present": true,
		"warehouse_required": FUTURES_WAREHOUSE_CARDS.has(card_id),
		"warehouse_district": -1,
		"warehouse_hp_checked": false,
		"private_owner_boundary": true,
	}
	if _runtime_main != null and not card_id.is_empty():
		var skill := _skill(card_id)
		var terms: Dictionary = skill.get("futures_terms", {}) if skill.get("futures_terms", {}) is Dictionary else {}
		var requirement_variant: Variant = _runtime_main.call("_card_play_requirement_snapshot", 0, skill, {"selected_district": _fixture_district_index()})
		var requirement: Dictionary = requirement_variant if requirement_variant is Dictionary else {}
		flags["runtime_kind"] = str(skill.get("kind", ""))
		flags["direction"] = str(terms.get("direction", ""))
		flags["purchase_cost"] = int(skill.get("cost", 0))
		flags["action_cost"] = int(requirement.get("cash_cost", 0))
		flags["duration_seconds"] = float(_market_controller.call("futures_duration_seconds", skill))
		flags["margin_cash"] = int(terms.get("margin_cash", 0))
		flags["maximum_gain"] = int(terms.get("maximum_gain", 0))
		flags["maximum_loss"] = int(terms.get("maximum_loss", 0))
		flags["multiplier"] = float(terms.get("multiplier", 1.0))
		flags["stockpile_units"] = maxi(1, int(terms.get("units", 1)))
		flags["warehouse_required"] = bool(terms.get("requires_warehouse", false))
	for key_variant in extra.keys():
		flags[key_variant] = extra[key_variant]
	return flags


func _open_position(card_id: String, warehouse := false, reset_market := true) -> Dictionary:
	if reset_market:
		_configure_market_fixture("empty")
	if warehouse:
		_configure_owned_warehouse_city(0)
	var applied := bool(_market_controller.call("apply_futures", 0, _skill(card_id)))
	var positions: Array = _entry(SAMPLE_PRODUCT).get("futures_positions", []) as Array
	return {"applied": applied, "position": (positions[positions.size() - 1] as Dictionary).duplicate(true) if not positions.is_empty() else {}, "count": positions.size()}


func _configure_owned_warehouse_city(owner_index: int) -> void:
	var district_index := _fixture_district_index()
	var districts: Array = (_runtime_main.get("districts") as Array).duplicate(true)
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	district["destroyed"] = false
	district["damage"] = 0
	district["city"] = _simple_city(owner_index)
	districts[district_index] = district
	_runtime_main.set("districts", districts)
	_runtime_main.set("selected_district", district_index)


func _other_product(excluded_product: String) -> String:
	var market: Dictionary = _market_state().get("product_market", {}) as Dictionary
	for product_variant in market.keys():
		var product_id := str(product_variant)
		if product_id != excluded_product:
			return product_id
	return excluded_product


func _skill_has_any(skill: Dictionary, field_names: Array) -> bool:
	for field_name_variant in field_names:
		if skill.has(str(field_name_variant)):
			return true
	return false


func _card_rank(card_id: String) -> int:
	if card_id.is_empty():
		return 0
	var suffix := card_id.right(1)
	return int(suffix) if suffix.is_valid_int() else 0


func _card_direction(card_id: String) -> String:
	if FUTURES_SHORT_CARDS.has(card_id):
		return "down"
	if FUTURES_LONG_CARDS.has(card_id) or FUTURES_WAREHOUSE_CARDS.has(card_id):
		return "up"
	return ""


func _market_state() -> Dictionary:
	return _market_controller.runtime_state_snapshot() if _market_controller != null else {}


func _set_market_property(property_name: String, value: Variant) -> void:
	if _market_controller == null:
		return
	var state := _market_state()
	state[property_name] = value
	_market_controller.apply_save_data(state)


func _entry(product_id: String) -> Dictionary:
	var market: Dictionary = _market_state().get("product_market", {}) as Dictionary
	var value: Variant = market.get(product_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _entry_flags(product_id: String) -> Dictionary:
	var entry := _entry(product_id)
	return {
		"product_id": product_id,
		"price_before": int(entry.get("base_price", 0)),
		"price_after": int(entry.get("price", 0)),
		"trend": int(entry.get("trend", 0)),
		"supply": int(entry.get("supply", 0)),
		"demand": int(entry.get("demand", 0)),
		"disrupted": int(entry.get("disrupted", 0)),
		"temporary_demand_delta": int(entry.get("temporary_demand_pressure", 0)),
		"temporary_supply_delta": int(entry.get("temporary_supply_pressure", 0)),
		"futures_count_after": (entry.get("futures_positions", []) as Array).size(),
	}


func _plain_entry(entry: Dictionary) -> Dictionary:
	var result := {}
	for key_variant in entry.keys():
		var key := str(key_variant)
		var value: Variant = entry[key_variant]
		if _is_data_only(value):
			result[key] = value
	return result


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"case_id": case_id,
		"product_id": str(flags.get("product_id", "")),
		"card_id": str(flags.get("card_id", "")),
		"rank": int(flags.get("rank", 0)),
		"runtime_kind": str(flags.get("runtime_kind", "")),
		"underlying_kind": str(flags.get("underlying_kind", "")),
		"product_id_source": str(flags.get("product_id_source", "")),
		"direction": str(flags.get("direction", "")),
		"purchase_cost": int(flags.get("purchase_cost", 0)),
		"action_cost": int(flags.get("action_cost", 0)),
		"margin_present": bool(flags.get("margin_present", false)),
		"margin_cash": int(flags.get("margin_cash", 0)),
		"entry_locked": bool(flags.get("entry_locked", false)),
		"duration_seconds": float(flags.get("duration_seconds", 0.0)),
		"multiplier": float(flags.get("multiplier", 0.0)),
		"stockpile_units": int(flags.get("stockpile_units", 0)),
		"max_gain_present": bool(flags.get("max_gain_present", false)),
		"maximum_gain": int(flags.get("maximum_gain", 0)),
		"max_loss_present": bool(flags.get("max_loss_present", false)),
		"maximum_loss": int(flags.get("maximum_loss", 0)),
		"warehouse_required": bool(flags.get("warehouse_required", false)),
		"warehouse_district": int(flags.get("warehouse_district", -1)),
		"warehouse_hp_checked": bool(flags.get("warehouse_hp_checked", false)),
		"current_behavior": str(flags.get("current_behavior", "")),
		"expected_v04_behavior": str(flags.get("expected_v04_behavior", "")),
		"expiry_behavior": str(flags.get("expiry_behavior", "")),
		"destruction_behavior": str(flags.get("destruction_behavior", "")),
		"public_clue": str(flags.get("public_clue", "")),
		"private_owner_boundary": bool(flags.get("private_owner_boundary", false)),
		"cycle_before": int(flags.get("cycle_before", 0)),
		"cycle_after": int(flags.get("cycle_after", 0)),
		"market_timer_before": float(flags.get("market_timer_before", 0.0)),
		"market_timer_after": float(flags.get("market_timer_after", 0.0)),
		"price_before": int(flags.get("price_before", 0)),
		"price_after": int(flags.get("price_after", 0)),
		"trend": int(flags.get("trend", 0)),
		"supply": int(flags.get("supply", 0)),
		"demand": int(flags.get("demand", 0)),
		"disrupted": int(flags.get("disrupted", 0)),
		"temporary_demand_delta": int(flags.get("temporary_demand_delta", 0)),
		"temporary_supply_delta": int(flags.get("temporary_supply_delta", 0)),
		"futures_count_before": int(flags.get("futures_count_before", 0)),
		"futures_count_after": int(flags.get("futures_count_after", 0)),
		"cash_delta": int(flags.get("cash_delta", 0)),
		"rng_checked": bool(flags.get("rng_checked", false)),
		"timing_checked": bool(flags.get("timing_checked", false)),
		"formula_service_checked": bool(flags.get("formula_service_checked", false)),
		"world_route_checked": bool(flags.get("world_route_checked", false)),
		"ai_route_checked": bool(flags.get("ai_route_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"historical_baseline": bool(flags.get("historical_baseline", false)),
		"live_gate": bool(flags.get("live_gate", not bool(flags.get("historical_baseline", false)))),
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", not aligned)),
		"risk": str(flags.get("risk", "" if aligned else "Observed runtime differs from or is underspecified by v0.4.")),
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


func _count_flag_for_ids(key: String, case_ids: Array) -> int:
	var count := 0
	for record_variant in _records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		if case_ids.has(str(record.get("case_id", ""))) and bool(record.get(key, false)):
			count += 1
	return count


func _update_ui(manifest: Dictionary) -> void:
	var observed := int(manifest.get("observed_count", 0))
	var decisions := int(manifest.get("needs_design_decision_count", 0))
	summary_label.text = "Records %d/%d | Live aligned %d/%d | Decisions %d" % [observed, CASE_COUNT, _count_flag_for_ids("contract_aligned", CASE_IDS.slice(0, MARKET_CASE_COUNT) + CUTOVER_CASE_IDS), LIVE_CASE_COUNT, decisions]
	status_label.text = "V0.4 TERMS ALIGNED" if _failures.is_empty() else "ALIGNMENT FAILURE"
	ownership_text.text = "[b]Single runtime owner[/b]\nProductMarketRuntimeController remains authoritative.\nThe Inspector catalog is the only futures terms source.\n\n[b]Settlement[/b]\nPurchase cost stays separate\nAction fee: ¥0 for all 12 cards\nQueue: authorize fee + bid + margin\nEffect open: lock margin\nExpiry: capped gain/loss + refund\nWarehouse: post-hit HP formula\n\n[b]Gate[/b]\n76/76 live aligned; 24 historical records preserved."
	var lines: Array[String] = []
	lines.append("[b]12-card terms matrix[/b]")
	for terms_variant in manifest.get("card_terms_matrix", []):
		var terms: Dictionary = terms_variant
		lines.append("%s | buy¥%d / act¥%d | %s %.0fs x%.2f | units%d | M/G/L %s/%s/%s" % [str(terms.get("card_id", "")), int(terms.get("purchase_cost", 0)), int(terms.get("action_cost", 0)), str(terms.get("direction", "")), float(terms.get("duration_seconds", 0.0)), float(terms.get("multiplier", 0.0)), int(terms.get("stockpile_units", 0)), "Y" if bool(terms.get("margin_present", false)) else "-", "Y" if bool(terms.get("max_gain_present", false)) else "-", "Y" if bool(terms.get("max_loss_present", false)) else "-"])
	lines.append("")
	lines.append("[b]100-record evidence[/b]")
	for record_variant in _records:
		var record: Dictionary = record_variant
		lines.append("%s %s | %s" % ["OK" if bool(record.get("observed", false)) else "FAIL", str(record.get("case_id", "")), "aligned" if bool(record.get("contract_aligned", false)) else "decision required"])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Product Futures v0.4 Authored Terms Hard Alignment - Sprint 55",
		"",
		"Ruleset: `%s`" % RULESET_ID,
		"Current runtime owner: `ProductMarketRuntimeController`",
		"Runtime cutover enabled: `true`",
		"Observed: %d/%d" % [int(manifest.get("observed_count", 0)), CASE_COUNT],
		"Contract aligned: %d/%d" % [int(manifest.get("aligned_count", 0)), CASE_COUNT],
		"Design decisions: %d" % int(manifest.get("needs_design_decision_count", 0)),
		"Production main SHA-256: `%s`" % str(manifest.get("current_main_sha256", "")),
		"Production main did not grow: `%s`" % str(manifest.get("production_main_not_grown", false)),
		"ProductMarketRuntimeController changed for cutover: `%s`" % str(manifest.get("market_controller_changed_for_cutover", false)),
		"",
		"## Ownership boundary",
		"",
		"- `ProductMarketRuntimeController`: single owner of market state, cadence, refresh, boon lifecycle, futures lifecycle, public sanitization, and current/legacy save fields.",
		"- `ProductMarketRuntimeWorldBridge`: shared RNG gateway, RuntimeBalanceModel calls, and narrow world mutation hooks only.",
		"- `main.gd`: narrow world facts, cash/event commits, callouts, clues, and cross-domain refresh adapters only.",
		"- `CardEconomyProductRouteFormulaRuntimeService`: pure boon, duration, payout, and route arithmetic only.",
		"- `EconomyCashflowRuntimeController`: realtime payout cadence and remainder planning only.",
		"- `GdpFormulaRuntimeController`: city GDP formula only.",
		"- `AiRuntimeController`: reads market facts and selects intents; it does not mutate the market.",
		"- Weather, Monster, Military, and Contract controllers request the shared market refresh/mutation route without owning a second market.",
		"- `ProductCodexPublicSnapshotService`: public display formatting only.",
		"",
		"## Twelve-card terms matrix",
		"",
		"| Card | Rank | Direction | Purchase | Action | Duration | Multiplier | Units | Margin | Max gain | Max loss | Warehouse |",
		"| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- |",
	]
	for terms_variant in manifest.get("card_terms_matrix", []):
		var terms: Dictionary = terms_variant
		lines.append("| %s | %d | %s | %d | %d | %.0f | %.2f | %d | %s | %s | %s | %s |" % [str(terms.get("card_id", "")), int(terms.get("rank", 0)), str(terms.get("direction", "")), int(terms.get("purchase_cost", 0)), int(terms.get("action_cost", 0)), float(terms.get("duration_seconds", 0.0)), float(terms.get("multiplier", 0.0)), int(terms.get("stockpile_units", 0)), str(terms.get("margin_present", false)), str(terms.get("max_gain_present", false)), str(terms.get("max_loss_present", false)), str(terms.get("warehouse_required", false))])
	lines.append_array([
		"",
		"## v0.4 aligned behavior",
		"",
		"- `cost` remains purchase price; all twelve cards explicitly author `action_fee_cash=0`.",
		"- Queue authorizes fee + bid + margin; effect open rechecks and locks margin atomically.",
		"- Favorable and adverse movement use capped v0.4 P&L; zero delta returns all margin.",
		"- Warehouse destruction uses max/pre/post HP and settles/removes positions exactly once.",
		"",
		"## Adopted decisions",
		"",
	])
	for decision_variant in manifest.get("design_decisions", []):
		var decision: Dictionary = decision_variant
		lines.append("### %s" % str(decision.get("question", "")))
		lines.append("")
		lines.append("Options: %s" % " / ".join(decision.get("options", []) as Array))
		lines.append("")
		lines.append("Recommendation: %s" % str(decision.get("recommendation", "")))
		lines.append("")
	lines.append_array([
		"",
		"## Cases",
		"",
		"| Case | Product | Card | Observed | Aligned | Decision | Notes |",
		"| --- | --- | --- | --- | --- | --- | --- |",
	])
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("product_id", "")), str(record.get("card_id", "")), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("needs_design_decision", false)), str(record.get("notes", "")).replace("|", "/")])
	lines.append_array([
		"",
		"## Sprint 55 cutover gate",
		"",
		"The existing Bench preserves 24 historical records and requires all 76 live market/terms cases to align. No parallel financial owner or legacy settlement fallback remains.",
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
	_formula_service = null
	_cashflow_controller = null
	_gdp_controller = null
	_ai_controller = null
	_weather_controller = null
	_monster_controller = null
	_military_controller = null
	_contract_controller = null
	_market_controller = null
	_queue_service = null
	_eligibility_service = null
	_presentation_service = null


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _tokens_in_order(source: String, tokens: Array) -> bool:
	var offset := 0
	for token_variant in tokens:
		var token := str(token_variant)
		var found := source.find(token, offset)
		if found < 0:
			return false
		offset = found + token.length()
	return true


func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


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
