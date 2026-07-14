extends Control
class_name WeatherV1CoreBench

const CONTROLLER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")
const AI_SCENE := preload("res://scenes/runtime/AiRuntimeController.tscn")
const CATALOG := preload("res://resources/weather/weather_definition_catalog_v1.tres")
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/weather_v1_core_bench.png"

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _controller: WeatherRuntimeController
var _bridge: WeatherRuntimeWorldBridge
var _clock: FakeClock
var _world: FakeWorld
var _checks := 0
var _failures: Array[String] = []
var _case_lines: Array[String] = []


class FakeClock:
	extends Node
	var us := 0

	func world_effective_micros() -> int:
		return us

	func restore_micros(value: int) -> Dictionary:
		us = maxi(0, value)
		return {"world_effective_us": us, "world_effective_seconds": float(us) / 1_000_000.0}

	func advance_us(delta: int) -> void:
		us = maxi(0, us + delta)


class FakeWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts: Array = []
	var auto_monsters: Array = []
	var log_lines: Array = []
	var callouts: Array = []
	var players: Array = []
	var selected_district := 0
	var camera_state := {"zoom": 0.5}
	var game_time := 9999.0

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(maxf(0.0, seconds))

	func _district_center(index: int) -> Vector2:
		return Vector2(float(index) * 10.0, 0.0)

	func _log(message: String) -> void:
		log_lines.append(message)

	func _add_action_callout(source: String, title: String, detail: String, accent: Color, world_position: Vector2, duration: float = 5.0) -> void:
		callouts.append({
			"source": source,
			"title": title,
			"detail": detail,
			"accent": accent.to_html(),
			"world_position": world_position,
			"duration": duration,
		})


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_checks = 0
	_failures.clear()
	_case_lines.clear()
	_setup()
	_case_definition_schema()
	_case_world_effective_grace_and_generation()
	_case_lifecycle_boundaries()
	_case_pause_by_clock()
	_case_max_two_and_same_region_queue()
	_case_settlement_stops_natural()
	_case_resolver_limits_and_resistance()
	_case_save_roundtrip_and_atomic_validation()
	_case_privacy_and_bridge_allowlist()
	_case_card_control_paths()
	_case_ai_weather_constant_compatibility()
	_case_single_owner_contract()
	_update_ui()
	_save_screenshot()
	print("WEATHER_V1_CORE_BENCH|status=%s|checks=%d|failures=%d|screenshot=%s|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		SCREENSHOT_PATH,
		JSON.stringify(_failures),
	])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": true,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"check_count": _checks,
		"failure_count": _failures.size(),
		"failed_cases": _failures.duplicate(),
		"screenshot_path": SCREENSHOT_PATH,
		"legacy_characterization_expected_stale": [
			"four_runtime_weather_types_exist",
			"forecast_lead_clamped_60_to_180",
			"zone_count_one_to_five",
			"current_save_shape",
			"game_time_pause_cases",
		],
	}


func _setup() -> void:
	for child in get_children():
		if child is FakeClock or child is FakeWorld or child is WeatherRuntimeController or child is WeatherRuntimeWorldBridge:
			child.queue_free()
	_clock = FakeClock.new()
	_clock.name = "WorldEffectiveClockRuntimeController"
	_world = FakeWorld.new()
	_world.name = "FakeWeatherWorld"
	_world.rng.seed = 6102026
	_world.districts = _fixture_districts()
	_world.auto_monsters = [
		{"district_index": 0, "down": false, "remaining_time": 25.0, "owner": "PRIVATE_OWNER"},
		{"district_index": 1, "down": true, "remaining_time": 25.0, "owner": "PRIVATE_OWNER"},
		{"district_index": 2, "down": false, "remaining_time": 0.0, "owner": "PRIVATE_OWNER"},
	]
	_world.players = [{"cash": 999999, "hand": ["PRIVATE_CARD"], "ai_plan": "PRIVATE_PLAN"}]
	_bridge = BRIDGE_SCENE.instantiate() as WeatherRuntimeWorldBridge
	_controller = CONTROLLER_SCENE.instantiate() as WeatherRuntimeController
	add_child(_clock)
	add_child(_world)
	add_child(_bridge)
	add_child(_controller)
	_bridge.bind_world(_world)
	_controller.set_world_bridge(_bridge)
	_controller.set_world_effective_clock(_clock)
	_controller.configure({"ruleset_id": "v0.6"})
	_expect(bool(_controller.debug_snapshot().get("controller_ready", false)), "controller configures with catalog, bridge, shared rng, and world_effective clock")


func _fixture_districts() -> Array:
	return [
		{"name": "曙光港", "destroyed": false, "terrain": "land", "neighbors": [1, 2], "city": {"active": true, "level": 2, "owner": "PRIVATE_CITY"}, "trade_volume_bucket": 3},
		{"name": "晶谷", "destroyed": false, "terrain": "land", "neighbors": [0, 2], "city": {}, "trade_volume_bucket": 1},
		{"name": "夜海", "destroyed": false, "terrain": "ocean", "neighbors": [0, 1, 3], "city": {"active": true, "level": 1}, "trade_volume_bucket": 2},
		{"name": "废墟", "destroyed": true, "terrain": "land", "neighbors": [2], "city": {"active": false}, "trade_volume_bucket": 9},
	]


func _case_definition_schema() -> void:
	var validation := CATALOG.validate_catalog()
	_expect(bool(validation.get("valid", false)), "catalog has exactly six valid data-driven definitions")
	_expect(CATALOG.definition_ids() == ["ion_storm", "gravity_tide", "spore_season", "crystal_dust_storm", "deep_freeze", "solar_flare"], "definition ids preserve v1 contract order")
	for id_variant in CATALOG.definition_ids():
		var definition := CATALOG.definition(str(id_variant))
		_expect(definition != null and definition.is_valid_definition(), "%s guardrail validation passes" % str(id_variant))
		_expect(definition.affected_region_count == 1, "%s first version affects one region" % str(id_variant))
	_case_line("definition_schema")


func _case_world_effective_grace_and_generation() -> void:
	_setup()
	_controller.tick(0.0)
	_expect(not _controller.has_forecast() and _controller.active_zone_count() == 0, "no weather is generated at t=0 during 90s grace")
	_clock.restore_micros(WeatherSystem.START_GRACE_US - 1)
	_controller.tick(0.0)
	_expect(not _controller.has_forecast(), "no weather is generated just before 90s grace boundary")
	_clock.restore_micros(WeatherSystem.START_GRACE_US)
	_controller.tick(0.0)
	var forecast := _controller.forecast_snapshot()
	_expect(not forecast.is_empty(), "natural forecast appears at exact 90s half-open boundary")
	_expect(int(forecast.get("forecast_remaining", 0.0)) >= 29 and int(forecast.get("forecast_remaining", 0.0)) <= 60, "forecast lead is 30-60s")
	var save := _controller.to_save_data()
	var next_us := int(save.get("next_generation_world_us", 0))
	_expect(next_us >= WeatherSystem.START_GRACE_US + WeatherSystem.GENERATION_MIN_US and next_us <= WeatherSystem.START_GRACE_US + WeatherSystem.GENERATION_MAX_US, "next natural generation interval is 90-150s")
	var bridge_debug := _controller.debug_snapshot().get("world_bridge", {}) as Dictionary
	_expect(not bool(bridge_debug.get("reads_game_time", true)), "bridge debug declares reads_game_time=false")
	_case_line("world_effective_grace_generation")


func _case_lifecycle_boundaries() -> void:
	_setup()
	var scheduled := _controller.schedule_forecast("ion_storm", 0, 1, 30.0, 45.0, "bench", false)
	_expect(scheduled, "explicit forecast schedules")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US - 1)
	_controller.tick(0.0)
	_expect(_controller.active_zone_count() == 0, "forecast remains inactive at 29.999999s")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US)
	_controller.tick(0.0)
	_expect(_controller.active_zone_count() == 1, "forecast activates at exact 30s boundary")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US + WeatherSystem.ACTIVE_MIN_US - 1)
	_controller.tick(0.0)
	_expect(str(_controller.active_zones_snapshot()[0].get("phase", "")) == WeatherRuntimeState.PHASE_ACTIVE, "active phase holds until active end exclusive")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US + WeatherSystem.ACTIVE_MIN_US)
	_controller.tick(0.0)
	var fading := _controller.active_zones_snapshot()[0] as Dictionary
	_expect(str(fading.get("phase", "")) == WeatherRuntimeState.PHASE_FADING and is_equal_approx(float(fading.get("intensity", 0.0)), 1.0), "fade begins at exact active end")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US + WeatherSystem.ACTIVE_MIN_US + 5_000_000)
	_controller.tick(0.0)
	var midpoint := _controller.active_zones_snapshot()[0] as Dictionary
	_expect(absf(float(midpoint.get("intensity", 0.0)) - 0.5) < 0.02, "fade intensity is linear at midpoint")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US + WeatherSystem.ACTIVE_MIN_US + WeatherSystem.FADE_US)
	_controller.tick(0.0)
	_expect(_controller.active_zone_count() == 0, "event ends at exact fade end half-open boundary")
	_case_line("lifecycle_boundaries")


func _case_pause_by_clock() -> void:
	_setup()
	_controller.schedule_forecast("gravity_tide", 0, 1, 30.0, 45.0, "bench", false)
	var before := _controller.forecast_snapshot()
	_world.game_time = 1_000_000.0
	for _i in range(4):
		_controller.tick(10.0)
	_expect(_controller.forecast_snapshot() == before, "weather is frozen when world_effective clock does not advance, regardless of delta/game_time")
	_clock.restore_micros(30_000_000)
	_controller.tick(0.0)
	_expect(_controller.active_zone_count() == 1, "weather advances only when world_effective clock advances")
	_case_line("pause_by_clock")


func _case_max_two_and_same_region_queue() -> void:
	_setup()
	_expect(_controller.schedule_forecast("ion_storm", 0, 1, 30.0, 45.0, "bench", false), "first region event schedules")
	_expect(_controller.schedule_forecast("deep_freeze", 1, 1, 30.0, 45.0, "bench", false), "second region event schedules")
	_expect(not _controller.schedule_forecast("solar_flare", 2, 1, 30.0, 45.0, "bench", false), "third unended event is rejected by max2 cap")
	_setup()
	_expect(_controller.schedule_forecast("ion_storm", 0, 1, 30.0, 45.0, "bench", false), "same-region first schedules")
	_expect(_controller.schedule_forecast("solar_flare", 0, 1, 30.0, 45.0, "bench", false), "same-region second enters queue")
	var events: Array = _controller.public_snapshot().get("events", []) as Array
	_expect(events.size() == 2 and str((events[1] as Dictionary).get("phase", "")) == WeatherRuntimeState.PHASE_QUEUED, "same-region conflict is queued")
	_clock.restore_micros(WeatherSystem.FORECAST_LEAD_MIN_US + WeatherSystem.ACTIVE_MIN_US + WeatherSystem.FADE_US)
	_controller.tick(0.0)
	events = _controller.public_snapshot().get("events", []) as Array
	_expect(events.size() == 1 and str((events[0] as Dictionary).get("phase", "")) == WeatherRuntimeState.PHASE_FORECAST, "queued same-region event starts forecast after prior event fully ends")
	_case_line("max_two_same_region_queue")


func _case_settlement_stops_natural() -> void:
	_setup()
	_controller.set_new_forecasts_allowed(false)
	_clock.restore_micros(200_000_000)
	_controller.tick(0.0)
	_expect(not _controller.has_forecast() and _controller.active_zone_count() == 0, "settlement stop blocks new natural forecasts")
	_expect(_controller.schedule_forecast("solar_flare", 0, 1, 30.0, 45.0, "bench", false), "explicit schedule still has an explicit API path")
	_expect(_source_types_are_public_safe(_controller.public_snapshot()), "explicit schedule exposes only natural/card/monster source types")
	_case_line("settlement_stop")


func _case_resolver_limits_and_resistance() -> void:
	var resolver := WeatherEffectResolver.new()
	var freeze := CATALOG.definition("deep_freeze")
	var freeze_effect := resolver.resolve(freeze, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"weather_resistance": 0.5, "weather_exploitation_multiplier": 3.0})
	_expect(float((freeze_effect.get("route", {}) as Dictionary).get("speed_multiplier", 0.0)) >= WeatherEffectResolver.ROUTE_FLOOR, "route multiplier respects 0.40 floor")
	_expect(float((freeze_effect.get("military", {}) as Dictionary).get("effect_multiplier", 0.0)) >= WeatherEffectResolver.MILITARY_FLOOR, "military multiplier respects 0.70 floor")
	_expect(float((freeze_effect.get("route", {}) as Dictionary).get("speed_multiplier", 0.0)) > freeze.route_multiplier, "weather resistance mitigates negative route effects")
	var flare := CATALOG.definition("solar_flare")
	var base := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"weather_exploitation_multiplier": 1.0})
	var exploited := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"weather_exploitation_multiplier": 2.0})
	_expect(float((exploited.get("economy", {}) as Dictionary).get("multiplier", 0.0)) > float((base.get("economy", {}) as Dictionary).get("multiplier", 0.0)), "weather exploitation amplifies positive economy effects")
	_expect(float((exploited.get("intel", {}) as Dictionary).get("effect_multiplier", 0.0)) == float((base.get("intel", {}) as Dictionary).get("effect_multiplier", 0.0)), "weather exploitation does not amplify negative intel effects")
	var crystal := resolver.resolve(CATALOG.definition("crystal_dust_storm"), WeatherRuntimeState.PHASE_ACTIVE, 1.0, {})
	var damage := crystal.get("damage", {}) as Dictionary
	_expect(bool(damage.get("nonlethal", false)) and bool(damage.get("capped", false)) and str(damage.get("policy", "")) == "nonlethal_capped", "crystal dust damage policy is explicitly nonlethal and capped")
	_case_line("resolver_limits")


func _case_save_roundtrip_and_atomic_validation() -> void:
	_setup()
	_clock.restore_micros(90_000_000)
	_controller.tick(0.0)
	var saved := _controller.to_save_data()
	var second_controller := CONTROLLER_SCENE.instantiate() as WeatherRuntimeController
	add_child(second_controller)
	second_controller.set_world_bridge(_bridge)
	second_controller.set_world_effective_clock(_clock)
	second_controller.configure({"ruleset_id": "v0.6"})
	var receipt := second_controller.apply_save_data(saved)
	_expect(bool(receipt.get("applied", false)) and second_controller.to_save_data().get("sequence") == saved.get("sequence"), "schema v2 weather save roundtrips through the existing owner")
	var before := second_controller.to_save_data()
	var bad := {
		"schema_version": WeatherRuntimeState.SCHEMA_VERSION,
		"events": [{"bad": true}],
		"queue": [],
		"next_generation_world_us": 90_000_000,
		"sequence": 1,
		"history": [],
		"region_history": {},
		"telemetry": {},
	}
	var bad_receipt := second_controller.apply_save_data(bad)
	_expect(not bool(bad_receipt.get("applied", true)) and second_controller.to_save_data() == before, "malformed schema v2 payload fails closed without partial state pollution")
	var legacy_receipt := second_controller.apply_save_data({"weather_forecast": {"id": 1}, "active_weather_zones": [{"id": 2}], "weather_sequence": 5})
	_expect(bool(legacy_receipt.get("applied", false)) and bool(legacy_receipt.get("fail_closed", false)) and second_controller.active_zone_count() == 0, "legacy v1 flat weather shape migrates conservatively by clearing runtime weather")
	second_controller.queue_free()
	_case_line("save_roundtrip_atomic")


func _case_privacy_and_bridge_allowlist() -> void:
	_setup()
	_clock.restore_micros(WeatherSystem.START_GRACE_US)
	_controller.tick(0.0)
	var before_facts := _bridge.region_facts_for_weather({})
	var before_public := JSON.stringify(_controller.public_snapshot()).to_lower()
	_world.players = [{"cash": 123456, "hand": ["PRIVATE_CARD"], "discard": ["PRIVATE_DISCARD"], "city_guesses": {"secret": "PRIVATE_CITY"}, "ai_plan": "PRIVATE_AI"}]
	_world.selected_district = 2
	_world.camera_state = {"zoom": 9.0, "center": "PRIVATE_CAMERA"}
	var after_facts := _bridge.region_facts_for_weather({})
	var after_public := JSON.stringify(_controller.public_snapshot()).to_lower()
	_expect(before_facts == after_facts, "weather region facts are invariant to player cash/hand/guesses/AI/camera/selection")
	_expect(_all_monster_counts_zero(before_facts) and not bool(_bridge.debug_snapshot().get("monster_public_count_capability_available", true)), "raw auto_monsters are not consumed when no narrow public monster-count API is available")
	_expect(before_public == after_public, "public weather snapshot is invariant to private world mutations")
	for sentinel in ["cash", "hand", "discard", "owner", "ai_plan", "private", "selected_district", "camera", "rng"]:
		_expect(not before_public.contains(sentinel), "public snapshot omits private token %s" % sentinel)
	_case_line("privacy_bridge_allowlist")


func _case_card_control_paths() -> void:
	_setup()
	_expect(not _controller.apply_weather_control({"weather_type": "ion_storm"}), "deprecated single-argument weather control fails closed without selected_district")
	_expect(_controller.apply_weather_control_at({"weather_type": "ion_storm", "weather_forecast_lead_seconds": 30.0, "weather_duration_seconds": 45.0}, 0), "explicit target weather control schedules through v1 API")
	_expect(_source_types_are_public_safe(_controller.public_snapshot()), "card control exposes only canonical source_type values")
	_case_line("card_control_paths")


func _case_ai_weather_constant_compatibility() -> void:
	var ai := AI_SCENE.instantiate()
	add_child(ai)
	var types: Dictionary = ai.get("WEATHER_TYPES") as Dictionary
	var ids := types.keys()
	ids.sort()
	var expected := ["crystal_dust_storm", "deep_freeze", "gravity_tide", "ion_storm", "solar_flare", "spore_season"]
	_expect(ids == expected, "real AiRuntimeController can still read WeatherRuntimeController.WEATHER_TYPES six-id compatibility shape")
	_expect(str((types.get("ion_storm", {}) as Dictionary).get("label", "")) == "离子风暴", "AI weather constant exposes public labels without effect-number authority")
	ai.queue_free()
	_case_line("ai_weather_constant_compatibility")


func _case_single_owner_contract() -> void:
	_setup()
	var system := WeatherSystem.new()
	var resolver := WeatherEffectResolver.new()
	var state := WeatherRuntimeState.new()
	var debug := _controller.debug_snapshot()
	_expect(not system.has_method("to_save_data") and not resolver.has_method("to_save_data") and not state.has_method("to_save_data"), "pure weather services expose no save API")
	_expect(bool(debug.get("single_save_owner", false)) and str(debug.get("runtime_owner", "")) == "WeatherRuntimeController", "WeatherRuntimeController remains the only weather save/state owner")
	_expect(not bool(debug.get("reads_game_time", true)) and not bool(debug.get("reads_selected_district", true)), "controller debug declares no game_time or selected_district dependency")
	_case_line("single_owner")


func _source_types_are_public_safe(snapshot: Dictionary) -> bool:
	var allowed := ["natural", "monster", "card"]
	var events: Array = snapshot.get("events", []) as Array
	for event_variant in events:
		if event_variant is Dictionary and not allowed.has(str((event_variant as Dictionary).get("source_type", ""))):
			return false
	var forecast: Dictionary = snapshot.get("forecast", {}) as Dictionary
	if forecast is Dictionary and not (forecast as Dictionary).is_empty() and not allowed.has(str((forecast as Dictionary).get("source_type", ""))):
		return false
	var active: Array = snapshot.get("active_zones", []) as Array
	for event_variant in active:
		if event_variant is Dictionary and not allowed.has(str((event_variant as Dictionary).get("source_type", ""))):
			return false
	return not JSON.stringify(snapshot).contains("manual") and not JSON.stringify(snapshot).contains("legacy")


func _all_monster_counts_zero(facts: Array) -> bool:
	for fact_variant in facts:
		if fact_variant is Dictionary and int((fact_variant as Dictionary).get("live_monster_count", -1)) != 0:
			return false
	return true


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("WEATHER V1 CORE: %s" % label)


func _case_line(label: String) -> void:
	_case_lines.append("%s: %s" % [label, "PASS" if _failures.is_empty() else "see failures"])


func _update_ui() -> void:
	if summary_label != null:
		summary_label.text = "Weather v1 Core %s — %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	if detail_label != null:
		detail_label.text = "\n".join(_case_lines + _failures)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	var absolute_path := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	image.save_png(absolute_path)
