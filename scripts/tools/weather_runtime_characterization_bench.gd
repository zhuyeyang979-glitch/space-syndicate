extends Control
class_name WeatherRuntimeCharacterizationBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const CONTROLLER_SCENE_PATH := "res://scenes/runtime/WeatherRuntimeController.tscn"
const CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/weather_runtime_controller.gd"
const WORLD_BRIDGE_SCENE_PATH := "res://scenes/runtime/WeatherRuntimeWorldBridge.tscn"
const WORLD_BRIDGE_SCRIPT_PATH := "res://scripts/runtime/weather_runtime_world_bridge.gd"
const COORDINATOR_SCENE_PATH := "res://scenes/runtime/GameRuntimeCoordinator.tscn"
const COORDINATOR_SCRIPT_PATH := "res://scripts/runtime/game_runtime_coordinator.gd"
const AI_CONTROLLER_SCRIPT_PATH := "res://scripts/runtime/ai_runtime_controller.gd"
const ENVIRONMENT_BALANCE_MODEL_PATH := "res://scripts/balance/environment_balance_model.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/weather_runtime_characterization/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/weather_runtime_hard_cutover_sprint_49.png"
const RULESET_ID := "v0.6"
const CASE_COUNT := 53
const FIXED_SEED := 490049
const SPRINT_48_MAIN_SHA256 := "f75b217e85da2e4f5300b900290457d41e4c031ec3c6b7cefe996e6a354a103a"
const SPRINT_48_MAIN_METRICS := {
	"total_lines": 28353,
	"nonblank_lines": 25380,
	"function_count": 1436,
	"top_level_variable_count": 154,
	"constant_count": 238,
}
const WEATHER_TYPES := ["ion_storm", "gravity_tide", "spore_season", "crystal_dust_storm", "deep_freeze", "solar_flare"]
const WEATHER_CONTROL_PAYLOADS := [
	{"weather_type": "ion_storm", "source_type": "card"},
	{"weather_type": "gravity_tide", "source_type": "card"},
	{"weather_type": "spore_season", "source_type": "card"},
	{"weather_type": "crystal_dust_storm", "source_type": "card"},
	{"weather_type": "deep_freeze", "source_type": "card"},
	{"weather_type": "solar_flare", "source_type": "card"},
]
const LEGACY_FUNCTIONS := [
	"_weather_template", "_weather_label", "_weather_color", "_weather_zone_count_for_planet",
	"_weather_district_names", "_weather_pick_districts", "_weather_preview_districts",
	"_schedule_weather_forecast", "_schedule_next_weather_forecast", "_activate_weather_forecast",
	"_update_weather_system", "_weather_entries_for_district", "_district_weather_multiplier",
	"_district_weather_summary", "_weather_status_text", "_apply_weather_control",
	"_runtime_planet_weather_short_text", "_weather_active_ui_text", "_weather_forecast_ui_text",
	"_weather_impact_ui_text", "_refresh_weather_forecast_strip",
]
const REQUIRED_CONTROLLER_API := [
	"configure", "set_world_effective_clock", "set_new_forecasts_allowed", "reset_state", "tick", "template", "label", "color", "weather_type_ids",
	"zone_count_for_planet", "pick_districts", "preview_districts", "schedule_forecast",
	"schedule_next_forecast", "activate_forecast", "apply_weather_control_at", "entries_for_district",
	"district_multiplier", "district_summary", "status_text", "active_ui_text", "forecast_ui_text",
	"impact_ui_text", "planet_short_text", "public_snapshot", "to_save_data", "apply_save_data",
	"debug_snapshot",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var cases_text: RichTextLabel = %CasesText

var _runtime_main: Control
var _runtime_coordinator: Node
var _weather_controller: WeatherRuntimeController
var _weather_bridge: WeatherRuntimeWorldBridge
var _monster_controller: MonsterRuntimeController
var _ai_controller: AiRuntimeController
var _product_market_controller: ProductMarketRuntimeController
var _baseline_players: Array = []
var _baseline_districts: Array = []
var _baseline_product_market: Dictionary = {}
var _records: Array = []
var _failures: Array[String] = []
var _main_source := ""
var _controller_source := ""
var _bridge_source := ""
var _coordinator_source := ""
var _coordinator_scene_source := ""
var _ai_source := ""
var _environment_balance_source := ""


func _ready() -> void:
	print("WeatherRuntimeCharacterizationBench Sprint 49 ready: auto_run=%s editor_hint=%s" % [auto_run, Engine.is_editor_hint()])
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_characterization_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func characterization_cases() -> Array:
	return [
		"weather_call_graph_complete",
		"six_data_driven_weather_types_exist",
		"weather_control_dispatch_exists",
		"runtime_state_shape",
		"initial_forecast_created",
		"forecast_lead_clamped_30_to_60",
		"active_duration_45_to_90_and_fade_10",
		"single_region_event_and_max_two_unended",
		"destroyed_districts_excluded",
		"neighbor_first_zone_selection",
		"seeded_fallback_selection",
		"shared_rng_consumption_order",
		"explicit_card_weather_control_schedules",
		"forced_forecast_keeps_public_warning",
		"invalid_anchor_rejects_atomically",
		"unknown_type_falls_back_safely",
		"sequence_increments_once",
		"activation_occurs_at_starts_at",
		"activation_sets_started_and_ends_at",
		"activation_clears_forecast",
		"activation_schedules_next_forecast",
		"queued_weather_respects_max_two_unended",
		"expiration_removes_only_expired",
		"expiration_refreshes_world_once",
		"production_multiplier_applies",
		"transport_multiplier_applies",
		"consumption_multiplier_applies",
		"ocean_transport_override",
		"overlapping_multipliers_compose",
		"city_network_refresh_routes_once",
		"product_market_refresh_routes_once",
		"normal_realtime_tick_continues",
		"monster_wager_freezes_weather",
		"readonly_pause_freezes_weather",
		"ai_weather_intent_uses_same_route",
		"card_resolution_weather_dispatch",
		"current_save_shape",
		"legacy_save_defaults",
		"public_forecast_privacy",
		"sprint49_deletion_candidates_complete",
		"controller_scene_composition",
		"controller_api_contract",
		"coordinator_static_composition",
		"state_owner_cutover",
		"shared_rng_owner_cutover",
		"lifecycle_owner_cutover",
		"multiplier_owner_cutover",
		"card_rewrite_owner_cutover",
		"save_owner_cutover",
		"ai_controller_binding",
		"pure_debug_snapshot",
		"main_legacy_weather_absent",
		"no_parallel_weather_owner",
	]


func build_characterization_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in characterization_cases():
		records.append(_record(str(case_id_variant), false, false, "preview"))
	return {
		"suite": "weather-runtime-hard-cutover-v04",
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
		"sprint48_main_sha256": SPRINT_48_MAIN_SHA256,
		"sprint48_main_metrics": SPRINT_48_MAIN_METRICS.duplicate(true),
		"records": records,
	}


func run_characterization_suite() -> void:
	_records.clear()
	_failures.clear()
	_load_sources()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("WeatherRuntimeCharacterizationBench could not instantiate the real main runtime and weather controller.")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in characterization_cases():
		var case_id := str(case_id_variant)
		_reset_fixture()
		print("WeatherRuntimeCharacterizationBench case: %s" % case_id)
		var record := _run_case(case_id)
		record["pure_data_checked"] = _is_data_only(record) and not _contains_runtime_object(record)
		record["passed"] = bool(record.get("observed", false)) and bool(record.get("contract_aligned", false)) and bool(record.get("pure_data_checked", false))
		_records.append(record)
		if not bool(record.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(record.get("notes", "gate failed"))])
	var metrics := _main_metrics()
	var manifest := {
		"suite": "weather-runtime-hard-cutover-v04",
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
		"sprint48_main_sha256": SPRINT_48_MAIN_SHA256,
		"current_main_sha256": _main_source.sha256_text(),
		"sprint48_main_metrics": SPRINT_48_MAIN_METRICS.duplicate(true),
		"main_metrics": metrics,
		"main_nonblank_lines_removed": int(SPRINT_48_MAIN_METRICS["nonblank_lines"]) - int(metrics.get("nonblank_lines", 0)),
		"main_functions_removed": int(SPRINT_48_MAIN_METRICS["function_count"]) - int(metrics.get("function_count", 0)),
		"main_variables_removed": int(SPRINT_48_MAIN_METRICS["top_level_variable_count"]) - int(metrics.get("top_level_variable_count", 0)),
		"main_constants_removed": int(SPRINT_48_MAIN_METRICS["constant_count"]) - int(metrics.get("constant_count", 0)),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("WeatherRuntimeCharacterizationBench manifest: %s" % MANIFEST_PATH)
	print("WeatherRuntimeCharacterizationBench report: %s" % REPORT_PATH)
	print("WeatherRuntimeCharacterizationBench screenshot: %s" % SCREENSHOT_PATH)
	print("WeatherRuntimeCharacterizationBench passed: %d/%d" % [_count_flag("passed"), CASE_COUNT])
	print("WeatherRuntimeCharacterizationBench main delta: nonblank=-%d functions=-%d variables=-%d constants=-%d sha=%s" % [
		int(manifest["main_nonblank_lines_removed"]), int(manifest["main_functions_removed"]),
		int(manifest["main_variables_removed"]), int(manifest["main_constants_removed"]),
		str(manifest["current_main_sha256"]),
	])
	if not _failures.is_empty():
		push_error("WeatherRuntimeCharacterizationBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		for _frame in range(4):
			await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_characterization_suite()


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"weather_call_graph_complete": return _case_call_graph()
		"six_data_driven_weather_types_exist": return _case_weather_types()
		"weather_control_dispatch_exists": return _case_weather_cards()
		"runtime_state_shape": return _case_state_shape()
		"initial_forecast_created": return _case_initial_forecast()
		"forecast_lead_clamped_30_to_60": return _case_lead_clamp()
		"active_duration_45_to_90_and_fade_10": return _case_natural_duration()
		"single_region_event_and_max_two_unended": return _case_zone_count()
		"destroyed_districts_excluded": return _case_destroyed_exclusion()
		"neighbor_first_zone_selection": return _case_neighbor_first()
		"seeded_fallback_selection": return _case_seeded_fallback()
		"shared_rng_consumption_order": return _case_rng_order()
		"explicit_card_weather_control_schedules": return _case_forced_rewrite()
		"forced_forecast_keeps_public_warning": return _case_public_warning()
		"invalid_anchor_rejects_atomically": return _case_invalid_anchor()
		"unknown_type_falls_back_safely": return _case_unknown_type()
		"sequence_increments_once": return _case_sequence()
		"activation_occurs_at_starts_at": return _case_activation_boundary()
		"activation_sets_started_and_ends_at": return _case_activation_times()
		"activation_clears_forecast": return _case_activation_replaces_forecast()
		"activation_schedules_next_forecast": return _case_next_forecast()
		"queued_weather_respects_max_two_unended": return _case_overlapping_zones()
		"expiration_removes_only_expired": return _case_expiration_removal()
		"expiration_refreshes_world_once": return _case_expiration_refresh()
		"production_multiplier_applies": return _case_multiplier("production_multiplier", "spore_season", 1.18)
		"transport_multiplier_applies": return _case_multiplier("transport_multiplier", "spore_season", 0.92)
		"consumption_multiplier_applies": return _case_multiplier("consumption_multiplier", "spore_season", 1.15)
		"ocean_transport_override": return _case_ocean_override()
		"overlapping_multipliers_compose": return _case_multiplier_composition()
		"city_network_refresh_routes_once": return _case_activation_refresh("city")
		"product_market_refresh_routes_once": return _case_activation_refresh("market")
		"normal_realtime_tick_continues": return _case_realtime_tick()
		"monster_wager_freezes_weather": return _case_wager_freeze()
		"readonly_pause_freezes_weather": return _case_pause_freeze()
		"ai_weather_intent_uses_same_route": return _case_ai_route()
		"card_resolution_weather_dispatch": return _case_card_resolution_route()
		"current_save_shape": return _case_save_shape()
		"legacy_save_defaults": return _case_legacy_save()
		"public_forecast_privacy": return _case_privacy()
		"sprint49_deletion_candidates_complete": return _case_deletion_candidates()
		"controller_scene_composition": return _case_controller_scene()
		"controller_api_contract": return _case_controller_api()
		"coordinator_static_composition": return _case_coordinator_composition()
		"state_owner_cutover": return _case_state_owner()
		"shared_rng_owner_cutover": return _case_rng_owner()
		"lifecycle_owner_cutover": return _case_lifecycle_owner()
		"multiplier_owner_cutover": return _case_multiplier_owner()
		"card_rewrite_owner_cutover": return _case_card_rewrite_owner()
		"save_owner_cutover": return _case_save_owner()
		"ai_controller_binding": return _case_ai_binding()
		"pure_debug_snapshot": return _case_pure_debug()
		"main_legacy_weather_absent": return _case_main_absent()
		"no_parallel_weather_owner": return _case_no_parallel_owner()
	return _record(case_id, false, false, "Unknown weather runtime case.")


func _case_call_graph() -> Dictionary:
	var controller_api_ready := true
	for method_variant in ["set_world_effective_clock", "set_new_forecasts_allowed", "tick", "apply_weather_control_at", "public_snapshot", "to_save_data", "apply_save_data", "debug_snapshot"]:
		controller_api_ready = controller_api_ready and _weather_controller.has_method(StringName(str(method_variant)))
	var coordinator_api_ready := true
	for method_variant in ["weather_runtime_controller", "weather_runtime_call", "weather_to_save_data", "apply_weather_save_data", "tick_weather"]:
		coordinator_api_ready = coordinator_api_ready and _runtime_coordinator.has_method(StringName(str(method_variant)))
	var controller_debug := _weather_controller.debug_snapshot()
	var bridge_debug := _weather_bridge.debug_snapshot()
	var observed: bool = controller_api_ready \
		and coordinator_api_ready \
		and _runtime_coordinator.call("weather_runtime_controller") == _weather_controller \
		and bool(controller_debug.get("controller_authoritative", false)) \
		and not bool(controller_debug.get("parallel_legacy_owner", true)) \
		and not bool(bridge_debug.get("owns_weather_state", true)) \
		and not bool(bridge_debug.get("owns_weather_rules", true)) \
		and _coordinator_scene_source.count("[node name=\"WeatherRuntimeController\"") == 1 \
		and _coordinator_scene_source.count("[node name=\"WeatherRuntimeWorldBridge\"") == 1
	return _record("weather_call_graph_complete", observed, observed, "Coordinator exposes the narrow weather API and binds the sole authoritative WeatherRuntimeController to a non-owning WorldBridge.")


func _case_weather_types() -> Dictionary:
	var labels: Array[String] = []
	var observed := true
	for type_id in WEATHER_TYPES:
		var weather_template := _weather_controller.template(type_id)
		observed = observed \
			and weather_template.has("id") \
			and weather_template.has("effects") \
			and int(weather_template.get("affected_region_count", -1)) == 1
		labels.append(str(weather_template.get("display_name", weather_template.get("label", ""))))
	var type_ids := _weather_controller.weather_type_ids()
	observed = observed and type_ids.size() == 6 and type_ids == WEATHER_TYPES
	return _record("six_data_driven_weather_types_exist", observed, observed, "The authoritative Controller exposes six data-driven Weather v1 templates: %s." % ", ".join(labels), {"weather_type": "six-types", "multiplier_checked": true})


func _case_weather_cards() -> Dictionary:
	var observed := true
	var anchor := _first_alive_district()
	for payload_variant in WEATHER_CONTROL_PAYLOADS:
		var payload: Dictionary = (payload_variant as Dictionary).duplicate(true)
		_weather_controller.reset_state()
		var applied := _weather_controller.apply_weather_control_at(payload, anchor)
		var forecast := _weather_controller.forecast_snapshot()
		observed = observed and applied and str(forecast.get("source_type", "")) == "card" and str(forecast.get("type", "")) == str(payload.get("weather_type", ""))
	return _record("weather_control_dispatch_exists", observed, observed, "Explicit v1 weather-control payloads schedule card-sourced public events without the retired selected-district wrapper.", {"weather_type": "card-source"})


func _case_state_shape() -> Dictionary:
	var scheduled := _weather_controller.schedule_forecast("ion_storm", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	var forecast := _weather_controller.forecast_snapshot()
	var required := ["id", "definition_id", "type", "region_indices", "created_at_world_us", "forecast_starts_at_world_us", "active_starts_at_world_us", "active_ends_at_world_us", "fade_ends_at_world_us", "source_type"]
	var observed := scheduled and _weather_controller.sequence_value() == 1 and _weather_controller.active_zone_count() == 0
	for key in required:
		observed = observed and forecast.has(key)
	return _record("runtime_state_shape", observed, observed, "Forecast, active events and sequence now live in the Controller with the characterized Weather v1 shape.", _weather_flags(forecast))


func _case_initial_forecast() -> Dictionary:
	var scheduled := _weather_controller.schedule_next_forecast(false)
	var forecast := _weather_controller.forecast_snapshot()
	var observed := scheduled and not forecast.is_empty() and int(forecast.get("id", 0)) == 1
	return _record("initial_forecast_created", observed, observed, "A clean Controller schedules one public forecast.", _weather_flags(forecast, {"timing_checked": true}))


func _case_lead_clamp() -> Dictionary:
	var anchor := _first_alive_district()
	_weather_controller.schedule_forecast("ion_storm", anchor, 1, 1.0, 45.0, "low", false)
	var low := _weather_controller.forecast_snapshot()
	_weather_controller.reset_state()
	_weather_controller.schedule_forecast("ion_storm", anchor, 1, 999.0, 45.0, "high", false)
	var high := _weather_controller.forecast_snapshot()
	var low_lead := float(int(low.get("active_starts_at_world_us", 0)) - int(low.get("forecast_starts_at_world_us", 0))) / 1_000_000.0
	var high_lead := float(int(high.get("active_starts_at_world_us", 0)) - int(high.get("forecast_starts_at_world_us", 0))) / 1_000_000.0
	var observed := is_equal_approx(low_lead, 30.0) and is_equal_approx(high_lead, 60.0)
	return _record("forecast_lead_clamped_30_to_60", observed, observed, "Forecast lead remains clamped to 30-60 world-effective seconds.", {"timing_checked": true})


func _case_natural_duration() -> Dictionary:
	_weather_controller.schedule_forecast("ion_storm", _first_alive_district(), 1, 1.0, 1.0, "test", false)
	var forecast := _weather_controller.forecast_snapshot()
	var active_duration := float(int(forecast.get("active_ends_at_world_us", 0)) - int(forecast.get("active_starts_at_world_us", 0))) / 1_000_000.0
	var fade_duration := float(int(forecast.get("fade_ends_at_world_us", 0)) - int(forecast.get("active_ends_at_world_us", 0))) / 1_000_000.0
	var observed := active_duration >= 45.0 and active_duration <= 90.0 and is_equal_approx(fade_duration, 10.0)
	return _record("active_duration_45_to_90_and_fade_10", observed, observed, "Weather v1 active duration clamps to 45-90 seconds and fade lasts exactly 10 seconds.", _weather_flags(forecast, {"timing_checked": true}))


func _case_zone_count() -> Dictionary:
	var anchor := _first_alive_district()
	var first := _weather_controller.schedule_forecast("ion_storm", anchor, 1, 30.0, 45.0, "one", false)
	var second_anchor := _district_with_neighbor()
	var second := _weather_controller.schedule_forecast("gravity_tide", second_anchor, 1, 30.0, 45.0, "two", false)
	var third := _weather_controller.schedule_forecast("spore_season", anchor, 1, 30.0, 45.0, "three", false)
	var events := _weather_controller.public_snapshot().get("events", []) as Array
	var single_region_events := true
	for event_variant in events:
		var event: Dictionary = event_variant as Dictionary
		single_region_events = single_region_events and (event.get("region_indices", []) as Array).size() == 1
	var observed := first and second and not third and events.size() == 2 and single_region_events and _weather_controller.zone_count_for_planet() == 1
	return _record("single_region_event_and_max_two_unended", observed, observed, "Weather v1 keeps one region per event and rejects a third unended event.", {"active_zone_count": events.size(), "district_count": 1})


func _case_destroyed_exclusion() -> Dictionary:
	var districts := _baseline_districts.duplicate(true)
	var destroyed := int(_alive_indices().back())
	(districts[destroyed] as Dictionary)["destroyed"] = true
	_runtime_main.set("districts", districts)
	var picked := _weather_controller.pick_districts(_first_alive_district(), 5)
	var observed := not picked.has(destroyed)
	return _record("destroyed_districts_excluded", observed, observed, "Destroyed districts remain excluded from weather zones.", {"district_count": picked.size()})


func _case_neighbor_first() -> Dictionary:
	var anchor := _district_with_neighbor()
	var districts: Array = _runtime_main.get("districts")
	var preview := _weather_controller.preview_districts(anchor, mini(3, districts.size()))
	var neighbors: Array = (districts[anchor] as Dictionary).get("neighbors", [])
	var observed := preview.size() >= 2 and int(preview[0]) == anchor and neighbors.has(int(preview[1]))
	return _record("neighbor_first_zone_selection", observed, observed, "BFS still fills valid neighboring districts before fallback selection.", {"district_count": preview.size()})


func _case_seeded_fallback() -> Dictionary:
	_rng().seed = FIXED_SEED
	var first := _weather_controller.pick_districts(-1, 4)
	_rng().seed = FIXED_SEED
	var second := _weather_controller.pick_districts(-1, 4)
	var observed := first == second and not first.is_empty()
	return _record("seeded_fallback_selection", observed, observed, "Invalid anchors use deterministic shared-RNG fallback under a fixed seed.", {"rng_checked": true, "district_count": first.size()})


func _case_rng_order() -> Dictionary:
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = FIXED_SEED
	var type_index := expected_rng.randi_range(0, WEATHER_TYPES.size() - 1)
	var alive := _alive_indices()
	var anchor := int(alive[expected_rng.randi_range(0, alive.size() - 1)])
	var lead := expected_rng.randf_range(30.0, 60.0)
	var duration := expected_rng.randf_range(45.0, 90.0)
	_weather_controller.schedule_next_forecast(false)
	var forecast := _weather_controller.forecast_snapshot()
	var districts: Array = forecast.get("districts", [])
	var lead_seconds := float(int(forecast.get("active_starts_at_world_us", 0)) - int(forecast.get("forecast_starts_at_world_us", 0))) / 1_000_000.0
	var active_seconds := float(int(forecast.get("active_ends_at_world_us", 0)) - int(forecast.get("active_starts_at_world_us", 0))) / 1_000_000.0
	var observed := str(forecast.get("type", "")) == str(WEATHER_TYPES[type_index]) and not districts.is_empty() and int(districts[0]) == anchor and is_equal_approx(lead_seconds, lead) and is_equal_approx(active_seconds, duration)
	return _record("shared_rng_consumption_order", observed, observed, "Scheduling consumes the same shared RNG in type, anchor, lead, duration order.", _weather_flags(forecast, {"rng_checked": true, "timing_checked": true}))


func _case_forced_rewrite() -> Dictionary:
	var anchor := _first_alive_district()
	var applied := _weather_controller.apply_weather_control_at({"weather_type": "gravity_tide"}, anchor)
	var forecast := _weather_controller.forecast_snapshot()
	var observed := applied and str(forecast.get("type", "")) == "gravity_tide" and str(forecast.get("source_type", "")) == "card" and int(forecast.get("id", 0)) == 1
	return _record("explicit_card_weather_control_schedules", observed, observed, "Weather-card effects use the explicit target API and schedule a card-sourced Weather v1 event.", _weather_flags(forecast, {"sequence_delta": 1}))


func _case_public_warning() -> Dictionary:
	var applied := _weather_controller.apply_weather_control_at({"weather_type": "ion_storm"}, _first_alive_district())
	var forecast := _weather_controller.forecast_snapshot()
	var ui_text := _weather_controller.forecast_ui_text()
	var observed := applied and ui_text.contains("卡牌干预") and not ui_text.contains("player_index") and int(forecast.get("active_starts_at_world_us", 0)) > int(forecast.get("forecast_starts_at_world_us", 0))
	return _record("forced_forecast_keeps_public_warning", observed, observed, "The warning remains public while the acting player stays anonymous.", _weather_flags(forecast, {"privacy_checked": true, "timing_checked": true}))


func _case_invalid_anchor() -> Dictionary:
	_weather_controller.schedule_forecast("ion_storm", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	var before := _weather_controller.forecast_snapshot()
	var applied := _weather_controller.apply_weather_control_at({"weather_type": "gravity_tide"}, -1)
	var observed := not applied and _weather_controller.forecast_snapshot() == before and _weather_controller.sequence_value() == 1
	return _record("invalid_anchor_rejects_atomically", observed, observed, "Invalid player card anchors reject without mutating weather state.")


func _case_unknown_type() -> Dictionary:
	var scheduled := _weather_controller.schedule_forecast("unknown_weather", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	var forecast := _weather_controller.forecast_snapshot()
	var observed := scheduled and str(forecast.get("type", "")) == "ion_storm"
	return _record("unknown_type_falls_back_safely", observed, observed, "Unknown ids preserve the first-definition Weather v1 compatibility fallback.", _weather_flags(forecast))


func _case_sequence() -> Dictionary:
	var anchor := _first_alive_district()
	_weather_controller.schedule_forecast("ion_storm", anchor, 1, 30.0, 45.0, "one", false)
	var first := _weather_controller.sequence_value()
	_weather_controller.schedule_forecast("gravity_tide", anchor, 1, 30.0, 45.0, "two", true)
	var second := _weather_controller.sequence_value()
	var observed := first == 1 and second == 2 and int(_weather_controller.forecast_snapshot().get("id", 0)) == 2
	return _record("sequence_increments_once", observed, observed, "Each accepted forecast increments sequence exactly once.", {"sequence_delta": second})


func _case_activation_boundary() -> Dictionary:
	_restore_world_seconds(0.0)
	_weather_controller.schedule_forecast("ion_storm", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	_restore_world_seconds(29.9)
	_weather_controller.tick(0.1)
	var before := _weather_controller.active_zone_count()
	_restore_world_seconds(30.0)
	_weather_controller.tick(0.1)
	var observed := before == 0 and _weather_controller.active_zone_count() == 1
	return _record("activation_occurs_at_starts_at", observed, observed, "Activation occurs at, not before, starts_at.", {"timing_checked": true, "active_zone_count": _weather_controller.active_zone_count()})


func _case_activation_times() -> Dictionary:
	_restore_world_seconds(10.0)
	_weather_controller.schedule_forecast("ion_storm", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	_restore_world_seconds(40.0)
	_weather_controller.tick(0.0)
	var active := _weather_controller.active_zones_snapshot()
	var entry: Dictionary = active[0] if not active.is_empty() else {}
	var observed := int(entry.get("active_starts_at_world_us", -1)) == 40_000_000 and int(entry.get("active_ends_at_world_us", -1)) == 85_000_000 and int(entry.get("fade_ends_at_world_us", -1)) == 95_000_000
	return _record("activation_sets_started_and_ends_at", observed, observed, "Activation stamps current time and current time plus duration.", _weather_flags(entry, {"active_zone_count": active.size(), "timing_checked": true}))


func _case_activation_replaces_forecast() -> Dictionary:
	_restore_world_seconds(0.0)
	_weather_controller.schedule_forecast("gravity_tide", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	var old_id := int(_weather_controller.forecast_snapshot().get("id", 0))
	_restore_world_seconds(30.0)
	_weather_controller.tick(0.0)
	var active := _weather_controller.active_zones_snapshot()
	var next := _weather_controller.forecast_snapshot()
	var observed := active.size() == 1 and int((active[0] as Dictionary).get("id", 0)) == old_id and next.is_empty()
	return _record("activation_clears_forecast", observed, observed, "Activated state clears the legacy forecast projection and leaves lifecycle ownership in the Weather v1 event roster.", _weather_flags(next, {"active_zone_count": active.size()}))


func _case_next_forecast() -> Dictionary:
	_restore_world_seconds(90.0)
	_weather_controller.schedule_forecast("gravity_tide", _first_alive_district(), 1, 30.0, 45.0, "test", false)
	var old_id := int(_weather_controller.forecast_snapshot().get("id", 0))
	_restore_world_seconds(120.0)
	_weather_controller.tick(0.0)
	var next := _weather_controller.forecast_snapshot()
	var observed := _weather_controller.active_zone_count() == 1 and (next.is_empty() or int(next.get("id", 0)) > old_id)
	return _record("activation_schedules_next_forecast", observed, observed, "Weather v1 no longer requires an immediate legacy replacement forecast; natural generation is clock-gated and max-two bounded.", _weather_flags(next, {"active_zone_count": 1, "timing_checked": true}))


func _case_overlapping_zones() -> Dictionary:
	var district_index := _first_alive_district()
	var first := _weather_controller.schedule_forecast("ion_storm", district_index, 1, 30.0, 45.0, "one", false)
	var second := _weather_controller.schedule_forecast("gravity_tide", district_index, 1, 30.0, 45.0, "two", false)
	var third := _weather_controller.schedule_forecast("spore_season", district_index, 1, 30.0, 45.0, "three", false)
	var public_events := _weather_controller.public_snapshot().get("events", []) as Array
	var observed := first and second and not third and public_events.size() == 2
	return _record("queued_weather_respects_max_two_unended", observed, observed, "Weather v1 allows at most two unended events; same-region followups wait in the owner queue.", {"active_zone_count": public_events.size()})


func _case_expiration_removal() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.replace_runtime_state({"id": 3, "type": "gravity_tide", "districts": [district_index], "starts_at": 100.0, "duration": 45.0}, [_active_entry(1, "ion_storm", [district_index], 5.0), _active_entry(2, "gravity_tide", [district_index], 15.0)], 3)
	_restore_world_seconds(10.0)
	_weather_controller.tick(0.0)
	var remaining := _weather_controller.active_zones_snapshot()
	var observed := remaining.size() == 1 and int((remaining[0] as Dictionary).get("id", 0)) == 2
	return _record("expiration_removes_only_expired", observed, observed, "Expiry removes only elapsed entries from the Controller roster.", {"active_zone_count": remaining.size(), "timing_checked": true})


func _case_expiration_refresh() -> Dictionary:
	var tick_source := _function_source(_controller_source, "tick")
	var observed := tick_source.contains("if expired:") and tick_source.count("_refresh_weather_dependents()") == 1
	return _record("expiration_refreshes_world_once", observed, observed, "A batch of expired zones routes one city/market refresh pair.", {"world_refresh_checked": true})


func _case_multiplier(key: String, weather_type: String, expected: float) -> Dictionary:
	var district_index := _first_district_by_terrain("land")
	_weather_controller.replace_runtime_state({}, [_active_entry(1, weather_type, [district_index], 200.0)], 1)
	var value := _weather_controller.district_multiplier(district_index, key, 1.0)
	var observed := is_equal_approx(value, expected)
	return _record("%s_applies" % key.trim_suffix("_multiplier"), observed, observed, "%s remains %.2f." % [key, expected], {"weather_type": weather_type, "active_zone_count": 1, "multiplier_checked": true})


func _case_ocean_override() -> Dictionary:
	var ocean := _first_district_by_terrain("ocean")
	_weather_controller.replace_runtime_state({}, [_active_entry(1, "gravity_tide", [ocean], 200.0)], 1)
	var observed := is_equal_approx(_weather_controller.district_multiplier(ocean, "transport_multiplier", 1.0), 1.26)
	return _record("ocean_transport_override", observed, observed, "Gravity tide preserves the 1.26 ocean transport override.", {"weather_type": "gravity_tide", "active_zone_count": 1, "multiplier_checked": true})


func _case_multiplier_composition() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.replace_runtime_state({}, [_active_entry(1, "spore_season", [district_index], 200.0), _active_entry(2, "deep_freeze", [district_index], 200.0)], 2)
	var observed := not is_equal_approx(_weather_controller.district_multiplier(district_index, "production_multiplier", 1.0), 1.0)
	return _record("overlapping_multipliers_compose", observed, observed, "Overlapping multipliers still compose multiplicatively.", {"active_zone_count": 2, "multiplier_checked": true})


func _case_activation_refresh(kind: String) -> Dictionary:
	var case_id := "city_network_refresh_routes_once" if kind == "city" else "product_market_refresh_routes_once"
	if kind == "city":
		var route_network: Node = _runtime_coordinator.call("route_network_runtime_controller") as Node
		if route_network == null or not route_network.has_method("debug_snapshot"):
			return _record(case_id, false, false, "Weather activation requires the authoritative RouteNetworkRuntimeController observation surface.", {"world_refresh_checked": true})
		var before := route_network.call("debug_snapshot") as Dictionary
		var district_index := _first_alive_district()
		_weather_controller.replace_runtime_state({"id": 1, "type": "ion_storm", "districts": [district_index], "created_at": 0.0, "starts_at": 0.0, "duration": 45.0, "source": "test", "forced": false}, [], 1)
		var activated := _weather_controller.activate_forecast()
		var after := route_network.call("debug_snapshot") as Dictionary
		var refresh_delta := int(after.get("refresh_count", 0)) - int(before.get("refresh_count", 0))
		var observed: bool = activated and refresh_delta == 1 and _weather_controller.active_zone_count() == 1
		return _record(case_id, observed, observed, "Weather activation invokes RouteNetworkRuntimeController.refresh_routes exactly once.", {"world_refresh_checked": true})
	var source := _function_source(_controller_source, "activate_forecast")
	var helper := _function_source(_controller_source, "_refresh_weather_dependents")
	var token := "_product_market_runtime_controller.refresh_prices()"
	var observed := source.count("_refresh_weather_dependents()") == 1 and helper.count(token) == 1
	return _record(case_id, observed, observed, "Activation routes exactly one %s refresh through the WorldBridge." % kind, {"world_refresh_checked": true})


func _case_realtime_tick() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.replace_runtime_state({"id": 1, "type": "ion_storm", "districts": [district_index], "created_at": 0.0, "starts_at": 0.5, "duration": 45.0, "source": "test", "forced": false}, [], 1)
	_runtime_main.call("_process", 0.5)
	var observed := float(_runtime_main.get("game_time")) >= 0.5 and _weather_controller.active_zone_count() == 1
	return _record("normal_realtime_tick_continues", observed, observed, "Normal main._process advances the Controller through Coordinator.tick_weather.", {"timing_checked": true, "active_zone_count": _weather_controller.active_zone_count()})


func _case_wager_freeze() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.replace_runtime_state({"id": 1, "type": "ion_storm", "districts": [district_index], "created_at": 0.0, "starts_at": 0.5, "duration": 45.0, "source": "test", "forced": false}, [], 1)
	_monster_controller.active_monster_wagers = [{"wager_id": 99, "resolved": false, "remaining_seconds": 20.0, "seconds_total": 20.0, "competitors": []}]
	_runtime_main.call("_process", 0.5)
	var observed := is_zero_approx(float(_runtime_main.get("game_time"))) and _weather_controller.active_zone_count() == 0
	return _record("monster_wager_freezes_weather", observed, observed, "The existing forced-decision boundary still freezes weather time.", {"timing_checked": true})


func _case_pause_freeze() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.replace_runtime_state({"id": 1, "type": "ion_storm", "districts": [district_index], "created_at": 0.0, "starts_at": 0.5, "duration": 45.0, "source": "test", "forced": false}, [], 1)
	_runtime_main.set("time_scale", 0.0)
	_runtime_main.call("_process", 1.0)
	var observed := is_zero_approx(float(_runtime_main.get("game_time"))) and _weather_controller.active_zone_count() == 0
	return _record("readonly_pause_freezes_weather", observed, observed, "Readonly pause still freezes the weather clock.", {"timing_checked": true})


func _case_ai_route() -> Dictionary:
	var effect_source := _function_source(_main_source, "_apply_card_resolution_effect_request")
	var observed := _ai_source.contains("func _ai_weather_control_plan(") and _ai_source.contains("_weather_runtime_controller.preview_districts") and effect_source.contains("apply_weather_control_at")
	return _record("ai_weather_intent_uses_same_route", observed, observed, "AI owns intent selection only and commits through the same explicit-target Controller route.", {"privacy_checked": true})


func _case_card_resolution_route() -> Dictionary:
	var source := _function_source(_main_source, "_apply_card_resolution_effect_request")
	var observed := source.contains("\"weather_control\":") and source.contains("apply_weather_control_at")
	return _record("card_resolution_weather_dispatch", observed, observed, "Card Resolution dispatches weather_control through WeatherRuntimeController's explicit-target API.")


func _case_save_shape() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.schedule_forecast("ion_storm", district_index, 1, 30.0, 45.0, "save", false)
	var captured := _runtime_coordinator.call("weather_to_save_data") as Dictionary
	var cleared_receipt := _runtime_coordinator.call("apply_weather_save_data", {}) as Dictionary
	var cleared := _runtime_coordinator.call("weather_to_save_data") as Dictionary
	var restore_receipt := _runtime_coordinator.call("apply_weather_save_data", captured) as Dictionary
	var restored := _runtime_coordinator.call("weather_to_save_data") as Dictionary
	var observed: bool = int(captured.get("schema_version", -1)) == 2 \
		and (captured.get("events", []) as Array).size() == 1 \
		and bool(cleared_receipt.get("applied", false)) \
		and (cleared.get("events", []) as Array).is_empty() \
		and (cleared.get("queue", []) as Array).is_empty() \
		and int(cleared.get("sequence", -1)) == 0 \
		and bool(restore_receipt.get("applied", false)) \
		and restored == captured
	return _record("current_save_shape", observed, observed, "Coordinator captures, clears, and exactly restores the v2 Weather owner envelope without a Main-wide snapshot.", {"save_checked": true})


func _case_legacy_save() -> Dictionary:
	_weather_controller.replace_runtime_state({"id": 99}, [{"id": 98}], 99)
	var receipt: Dictionary = _runtime_coordinator.call("apply_weather_save_data", {})
	var observed := bool(receipt.get("applied", false)) and not _weather_controller.has_forecast() and _weather_controller.active_zone_count() == 0 and _weather_controller.sequence_value() == 0
	return _record("legacy_save_defaults", observed, observed, "Missing legacy weather keys restore the established empty defaults.", {"save_checked": true})


func _case_privacy() -> Dictionary:
	var applied := _weather_controller.apply_weather_control_at({"weather_type": "solar_flare"}, _first_alive_district())
	var public_snapshot := _weather_controller.public_snapshot()
	var public_text := JSON.stringify(public_snapshot).to_lower()
	var observed := applied and not _contains_any(public_text, ["owner", "player_index", "private", "ai_plan"])
	return _record("public_forecast_privacy", observed, observed, "Public weather snapshot exposes warning facts without actor identity or private plan data.", {"privacy_checked": true})


func _case_deletion_candidates() -> Dictionary:
	var missing: Array[String] = []
	for function_name in LEGACY_FUNCTIONS:
		if not _main_source.contains("func %s(" % function_name):
			continue
		missing.append(function_name)
	var legacy_state_tokens := ["var weather_forecast :=", "var active_weather_zones :=", "var weather_sequence :=", "const WEATHER_FORECAST_LEAD_MIN_SECONDS", "const WEATHER_FORECAST_LEAD_MAX_SECONDS", "const WEATHER_DURATION_MIN_SECONDS", "const WEATHER_DURATION_MAX_SECONDS", "const WEATHER_ZONE_MAX", "const WEATHER_TYPES"]
	for token in legacy_state_tokens:
		if _main_source.contains(token):
			missing.append(token)
	var observed := missing.is_empty() and _environment_balance_source.contains("func weather_state_effect_model(")
	return _record("sprint49_deletion_candidates_complete", observed, observed, "All characterized main weather owners are deleted; EnvironmentBalanceModel remains QA-only. leftovers=%s" % str(missing), {"save_checked": true, "privacy_checked": true})


func _case_controller_scene() -> Dictionary:
	var packed := load(CONTROLLER_SCENE_PATH) as PackedScene
	var instance := packed.instantiate() if packed != null else null
	var observed := instance is WeatherRuntimeController and str(instance.name) == "WeatherRuntimeController"
	if instance != null:
		instance.free()
	return _record("controller_scene_composition", observed, observed, "WeatherRuntimeController is a real editor-openable .tscn.")


func _case_controller_api() -> Dictionary:
	var missing: Array[String] = []
	for method_name in REQUIRED_CONTROLLER_API:
		if not _weather_controller.has_method(method_name):
			missing.append(method_name)
	var observed := missing.is_empty()
	return _record("controller_api_contract", observed, observed, "Controller exposes the complete lifecycle, multiplier, presentation and save API. missing=%s" % str(missing))


func _case_coordinator_composition() -> Dictionary:
	var observed := _runtime_coordinator.get_node_or_null("WeatherRuntimeController") == _weather_controller and _runtime_coordinator.get_node_or_null("WeatherRuntimeWorldBridge") == _weather_bridge and _coordinator_scene_source.contains("WeatherRuntimeController.tscn") and _coordinator_scene_source.contains("WeatherRuntimeWorldBridge.tscn")
	return _record("coordinator_static_composition", observed, observed, "Controller and WorldBridge are static GameRuntimeCoordinator children.")


func _case_state_owner() -> Dictionary:
	var observed := _controller_source.contains("var weather_forecast: Dictionary") and _controller_source.contains("var active_weather_zones: Array") and _controller_source.contains("var weather_sequence") and not _main_source.contains("var weather_forecast :=") and not _main_source.contains("var active_weather_zones :=")
	return _record("state_owner_cutover", observed, observed, "All three weather runtime states have one owner: WeatherRuntimeController.")


func _case_rng_owner() -> Dictionary:
	var bridge_snapshot := _weather_bridge.debug_snapshot()
	var observed := bool(bridge_snapshot.get("shared_rng_available", false)) and _bridge_source.contains("func shared_rng()") and not _controller_source.contains("RandomNumberGenerator.new") and not _controller_source.contains("randomize()")
	return _record("shared_rng_owner_cutover", observed, observed, "Controller consumes main's shared RNG through the narrow bridge and creates no second RNG.", {"rng_checked": true})


func _case_lifecycle_owner() -> Dictionary:
	var observed := _controller_source.contains("func schedule_forecast(") and _controller_source.contains("func schedule_next_forecast(") and _controller_source.contains("func activate_forecast(") and _controller_source.contains("func tick(") and not _main_source.contains("func _update_weather_system(")
	return _record("lifecycle_owner_cutover", observed, observed, "Forecast, activation, overlap and expiry lifecycle ownership is cut over.", {"timing_checked": true})


func _case_multiplier_owner() -> Dictionary:
	var observed := _controller_source.contains("func district_multiplier(") and _main_source.contains("weather_runtime_controller.district_multiplier") and not _main_source.contains("func _district_weather_multiplier(")
	return _record("multiplier_owner_cutover", observed, observed, "Production, transport, consumption and ocean multiplier lookup has one owner.", {"multiplier_checked": true})


func _case_card_rewrite_owner() -> Dictionary:
	var observed := _controller_source.contains("func apply_weather_control_at(") and _function_source(_main_source, "_apply_card_resolution_effect_request").contains("apply_weather_control_at") and not _main_source.contains("func _apply_weather_control(")
	return _record("card_rewrite_owner_cutover", observed, observed, "Weather-card scheduling is committed by the Controller without a parallel main algorithm.")


func _case_save_owner() -> Dictionary:
	var district_index := _first_alive_district()
	_weather_controller.schedule_forecast("solar_flare", district_index, 1, 30.0, 45.0, "save-owner", true)
	var coordinator_capture := _runtime_coordinator.call("weather_to_save_data") as Dictionary
	var controller_capture := _weather_controller.to_save_data()
	var replacement := coordinator_capture.duplicate(true)
	replacement["sequence"] = int(replacement.get("sequence", 0)) + 1
	var apply_receipt := _runtime_coordinator.call("apply_weather_save_data", replacement) as Dictionary
	var owner_debug := _weather_controller.debug_snapshot()
	var bridge_debug := _weather_bridge.debug_snapshot()
	var observed: bool = coordinator_capture == controller_capture \
		and bool(apply_receipt.get("applied", false)) \
		and _weather_controller.to_save_data() == replacement \
		and str(owner_debug.get("runtime_owner", "")) == "WeatherRuntimeController" \
		and bool(owner_debug.get("controller_authoritative", false)) \
		and not bool(owner_debug.get("parallel_legacy_owner", true)) \
		and not bool(bridge_debug.get("owns_weather_state", true)) \
		and not bool(bridge_debug.get("owns_weather_rules", true))
	return _record("save_owner_cutover", observed, observed, "Coordinator save/apply delegates to the same authoritative WeatherRuntimeController while the WorldBridge remains non-owning.", {"save_checked": true})


func _case_ai_binding() -> Dictionary:
	var ai_snapshot := _ai_controller.debug_snapshot()
	var observed := bool(ai_snapshot.get("weather_controller_bound", false)) and _coordinator_source.contains("set_weather_runtime_controller") and _ai_source.contains("_weather_runtime_controller.preview_districts")
	return _record("ai_controller_binding", observed, observed, "AI remains decision owner and reads weather facts from the authoritative Controller.", {"privacy_checked": true})


func _case_pure_debug() -> Dictionary:
	var debug := _weather_controller.debug_snapshot()
	var observed := _is_data_only(debug) and not _contains_runtime_object(debug) and not JSON.stringify(debug).to_lower().contains("source")
	return _record("pure_debug_snapshot", observed, observed, "Weather debug/public snapshots are pure data and omit private source identity.", {"privacy_checked": true})


func _case_main_absent() -> Dictionary:
	var leftovers: Array[String] = []
	for function_name in LEGACY_FUNCTIONS:
		if _main_source.contains("func %s(" % function_name):
			leftovers.append(function_name)
	var metrics := _main_metrics()
	var observed := leftovers.is_empty() and int(metrics.get("nonblank_lines", 0)) <= 25039 and int(metrics.get("function_count", 0)) <= 1415 and int(metrics.get("top_level_variable_count", 0)) <= 148 and int(metrics.get("constant_count", 0)) <= 232
	return _record("main_legacy_weather_absent", observed, observed, "main.gd removed 341 nonblank lines, 21 functions, 6 top-level variables and 6 constants from the Sprint 48 baseline. leftovers=%s" % str(leftovers))


func _case_no_parallel_owner() -> Dictionary:
	var count := _coordinator_scene_source.count("[node name=\"WeatherRuntimeController\"")
	var observed := count == 1 and bool(_weather_controller.debug_snapshot().get("controller_authoritative", false)) and not bool(_weather_controller.debug_snapshot().get("parallel_legacy_owner", true)) and not _main_source.contains("func _schedule_weather_forecast(")
	return _record("no_parallel_weather_owner", observed, observed, "Exactly one production weather Controller exists; QA balance models remain non-authoritative.")


func _load_sources() -> void:
	_main_source = FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	_controller_source = FileAccess.get_file_as_string(CONTROLLER_SCRIPT_PATH)
	_bridge_source = FileAccess.get_file_as_string(WORLD_BRIDGE_SCRIPT_PATH)
	_coordinator_source = FileAccess.get_file_as_string(COORDINATOR_SCRIPT_PATH)
	_coordinator_scene_source = FileAccess.get_file_as_string(COORDINATOR_SCENE_PATH)
	_ai_source = FileAccess.get_file_as_string(AI_CONTROLLER_SCRIPT_PATH)
	_environment_balance_source = FileAccess.get_file_as_string(ENVIRONMENT_BALANCE_MODEL_PATH)


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
	_runtime_coordinator = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_weather_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/WeatherRuntimeController") as WeatherRuntimeController
	_weather_bridge = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/WeatherRuntimeWorldBridge") as WeatherRuntimeWorldBridge
	_monster_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/MonsterRuntimeController") as MonsterRuntimeController
	_ai_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController") as AiRuntimeController
	_product_market_controller = _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController") as ProductMarketRuntimeController
	if _runtime_coordinator == null or _weather_controller == null or _weather_bridge == null or _monster_controller == null or _ai_controller == null or _product_market_controller == null:
		return false
	_rng().seed = FIXED_SEED
	_runtime_main.call("_new_game")
	_hide_runtime_canvas_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	_runtime_main.set_process(false)
	_baseline_players = (_runtime_main.get("players") as Array).duplicate(true)
	_baseline_districts = (_runtime_main.get("districts") as Array).duplicate(true)
	_baseline_product_market = _product_market_controller.to_save_data().duplicate(true)
	return not _baseline_players.is_empty() and not _baseline_districts.is_empty() and bool(_weather_controller.debug_snapshot().get("controller_ready", false))


func _reset_fixture() -> void:
	_runtime_main.set_process(false)
	_runtime_main.set("players", _baseline_players.duplicate(true))
	_runtime_main.set("districts", _baseline_districts.duplicate(true))
	_product_market_controller.apply_save_data(_baseline_product_market.duplicate(true))
	_runtime_main.set("game_time", 0.0)
	_runtime_main.set("time_scale", 1.0)
	_runtime_main.set("game_over", false)
	_runtime_main.set("selected_player", 0)
	_runtime_main.set("selected_district", _first_alive_district())
	_runtime_main.set("log_lines", [])
	_runtime_main.set("action_callouts", [])
	_runtime_main.set("map_event_effects", [])
	_weather_controller.reset_state()
	_monster_controller.active_monster_wagers = []
	_rng().seed = FIXED_SEED
	if _runtime_coordinator.has_method("sync_forced_decision_candidates"):
		_runtime_coordinator.call("sync_forced_decision_candidates", [])


func _hide_runtime_canvas_layers() -> void:
	for node in _runtime_main.find_children("*", "CanvasLayer", true, false):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		for player_variant in _runtime_main.find_children("*", "AudioStreamPlayer", true, false):
			var audio := player_variant as AudioStreamPlayer
			if audio != null:
				audio.stop()
				audio.stream = null
		_runtime_main.queue_free()
	_runtime_main = null
	_runtime_coordinator = null
	_weather_controller = null
	_weather_bridge = null
	_monster_controller = null
	_ai_controller = null


func _rng() -> RandomNumberGenerator:
	return _runtime_main.get("rng") as RandomNumberGenerator


func _restore_world_seconds(seconds: float) -> Dictionary:
	if _runtime_coordinator != null and _runtime_coordinator.has_method("restore_world_effective_seconds"):
		var value: Variant = _runtime_coordinator.call("restore_world_effective_seconds", seconds)
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}
	_runtime_main.set("game_time", seconds)
	return {"world_effective_seconds": seconds}


func _alive_indices() -> Array:
	var result: Array = []
	var districts: Array = _runtime_main.get("districts")
	for index in range(districts.size()):
		if not bool((districts[index] as Dictionary).get("destroyed", false)):
			result.append(index)
	return result


func _first_alive_district() -> int:
	var alive := _alive_indices()
	return int(alive[0]) if not alive.is_empty() else -1


func _first_district_by_terrain(terrain: String) -> int:
	var districts: Array = _runtime_main.get("districts")
	for index in range(districts.size()):
		var district := districts[index] as Dictionary
		if not bool(district.get("destroyed", false)) and str(district.get("terrain", "land")) == terrain:
			return index
	return _first_alive_district()


func _district_with_neighbor() -> int:
	var districts: Array = _runtime_main.get("districts")
	for index in _alive_indices():
		if not ((districts[int(index)] as Dictionary).get("neighbors", []) as Array).is_empty():
			return int(index)
	return _first_alive_district()


func _active_entry(id: int, weather_type: String, district_ids: Array, ends_at: float) -> Dictionary:
	return {"id": id, "type": weather_type, "districts": district_ids.duplicate(), "created_at": 0.0, "starts_at": 0.0, "started_at": 0.0, "duration": ends_at, "ends_at": ends_at, "source": "test", "forced": false}


func _weather_flags(entry: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var flags := {"weather_type": str(entry.get("type", "")), "forecast_present": not entry.is_empty(), "active_zone_count": 0, "district_count": (entry.get("districts", []) as Array).size() if entry.get("districts", []) is Array else 0, "sequence_delta": int(entry.get("id", 0))}
	flags.merge(overrides, true)
	return flags


func _contains_any(text: String, tokens: Array) -> bool:
	for token in tokens:
		if text.contains(str(token).to_lower()):
			return true
	return false


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 5)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _record(case_id: String, observed: bool, aligned: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"case_id": case_id,
		"weather_type": str(flags.get("weather_type", "")),
		"forecast_present": bool(flags.get("forecast_present", false)),
		"active_zone_count": int(flags.get("active_zone_count", 0)),
		"district_count": int(flags.get("district_count", 0)),
		"sequence_delta": int(flags.get("sequence_delta", 0)),
		"rng_checked": bool(flags.get("rng_checked", false)),
		"timing_checked": bool(flags.get("timing_checked", false)),
		"multiplier_checked": bool(flags.get("multiplier_checked", false)),
		"world_refresh_checked": bool(flags.get("world_refresh_checked", false)),
		"save_checked": bool(flags.get("save_checked", false)),
		"privacy_checked": bool(flags.get("privacy_checked", false)),
		"pure_data_checked": true,
		"observed": observed,
		"contract_aligned": aligned,
		"needs_design_decision": bool(flags.get("needs_design_decision", false)),
		"risk": str(flags.get("risk", "" if aligned else "Weather runtime behavior differs from the v0.4 contract.")),
		"passed": observed and aligned,
		"notes": notes,
	}


func _main_metrics() -> Dictionary:
	var lines := _main_source.split("\n")
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
	var passed := int(manifest.get("passed_count", 0))
	summary_label.text = "Hard Cutover %d/%d | main -%d lines / -%d funcs" % [passed, CASE_COUNT, int(manifest.get("main_nonblank_lines_removed", 0)), int(manifest.get("main_functions_removed", 0))]
	status_label.text = "PASS" if _failures.is_empty() else "HARD CUTOVER FAILURE"
	ownership_text.text = "[b]Authoritative owner[/b]\nWeatherRuntimeController\n\n[b]World boundary[/b]\nWeatherRuntimeWorldBridge: shared RNG + existing world facts/mutations only\n\n[b]Consumers[/b]\nAI: intent selection\nGDP/Market: multipliers\nGameScreen: public snapshot\nmain.gd: narrow routing only"
	var lines: Array[String] = []
	for record_variant in _records:
		var record := record_variant as Dictionary
		lines.append("%s %s" % ["OK" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))])
	cases_text.text = "\n".join(lines)


func _markdown_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Weather Runtime Hard Cutover - Sprint 49", "", "Ruleset: `%s`" % RULESET_ID,
		"Runtime owner: `%s`" % CONTROLLER_SCRIPT_PATH,
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), CASE_COUNT],
		"main.gd delta: -%d nonblank lines, -%d functions, -%d variables, -%d constants" % [int(manifest.get("main_nonblank_lines_removed", 0)), int(manifest.get("main_functions_removed", 0)), int(manifest.get("main_variables_removed", 0)), int(manifest.get("main_constants_removed", 0))],
		"", "## Ownership", "",
		"- `WeatherRuntimeController`: forecast, active zones, sequence, shared-RNG selection, activation/expiry, multipliers, card rewrites and save data.",
		"- `WeatherRuntimeWorldBridge`: reads the existing shared RNG and routes existing world refresh/log/callout methods; it owns no weather state or rules.",
		"- `AiRuntimeController`: weather intent and target selection only.",
		"- `main.gd`: time routing, existing card-resolution dispatch and v1 save envelope only.",
		"- `EnvironmentBalanceModel`: Inspector/QA sampling only.",
		"", "The v0.4 text mentions possible monster movement or financial-risk weather effects. The current four production templates modify production, transport, consumption and ocean transport only; Sprint 49 preserves that characterized scope.",
		"", "## Cases", "", "| Case | Observed | Aligned | Notes |", "| --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("observed", false)), str(record.get("contract_aligned", false)), str(record.get("notes", "")).replace("|", "/")])
	return "\n".join(lines) + "\n"


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
