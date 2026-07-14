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
	_case_weather_semantic_matrix()
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
	var expected_names := {
		"ion_storm": "离子风暴",
		"gravity_tide": "引力潮",
		"spore_season": "孢子季",
		"crystal_dust_storm": "晶尘暴",
		"deep_freeze": "极寒期",
		"solar_flare": "太阳耀斑",
	}
	var required_fields := [
		"id",
		"display_name",
		"description",
		"category",
		"forecast_duration",
		"active_duration",
		"fade_duration",
		"affected_region_count",
		"product_tags",
		"product_price_growth_multiplier",
		"production_multiplier",
		"demand_multiplier",
		"route_efficiency_multiplier",
		"land_movement_multiplier",
		"ocean_movement_multiplier",
		"air_movement_multiplier",
		"ranged_effect_multiplier",
		"knockback_multiplier",
		"region_damage_per_second",
		"monster_preference_tags",
		"monster_speed_multiplier",
		"monster_armor_multiplier",
		"intel_effect_multiplier",
		"counterplay_hint",
		"exploitation_hint",
	]
	for id_variant in CATALOG.definition_ids():
		var type_id := str(id_variant)
		var definition := CATALOG.definition(type_id)
		_expect(definition != null and definition.is_valid_definition(), "%s guardrail validation passes" % type_id)
		_expect(definition.affected_region_count == 1, "%s first version affects one region" % type_id)
		_expect(definition.display_name == str(expected_names.get(type_id, "")), "%s Chinese display name matches user contract" % type_id)
		var payload := definition.to_dictionary()
		for field_name in required_fields:
			_expect(payload.has(str(field_name)), "%s exposes required field %s" % [type_id, str(field_name)])
		for tag_variant in definition.product_tags:
			_expect(str(tag_variant).begins_with("weather_"), "%s product tag uses canonical weather_* catalog vocabulary" % type_id)
		for tag_variant in definition.monster_preference_tags:
			_expect(not str(tag_variant).begins_with("weather_"), "%s monster tag remains separate from product vocabulary" % type_id)
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
	_clock.restore_micros(int(round(CATALOG.definition("gravity_tide").forecast_duration * 1_000_000.0)))
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


func _case_weather_semantic_matrix() -> void:
	var resolver := WeatherEffectResolver.new()
	var ion_energy := _resolve(resolver, "ion_storm", {"product_tags": ["weather_energy"], "movement_domain": "air", "monster_tags": ["electromagnetic"], "unit_tags": ["flying"], "intel_domain": "range"})
	var ion_food := _resolve(resolver, "ion_storm", {"product_tags": ["weather_food"], "movement_domain": "land", "monster_tags": ["biological"], "intel_domain": "duration"})
	_expect(_economy(ion_energy, "price_growth_multiplier") > 1.0, "ion storm raises energy price growth")
	_expect(_route(ion_energy, "air_multiplier") > 1.0, "ion storm improves air route context")
	_expect(is_equal_approx(_route(ion_food, "land_multiplier"), 1.0), "ion storm does not harm non-air movement")
	_expect(_monster(ion_energy, "speed_multiplier") > 1.0 and is_equal_approx(_monster(ion_food, "speed_multiplier"), 1.0), "ion storm speeds only electromagnetic monsters")
	_expect(_military(ion_energy, "flying_risk_multiplier") > 1.0, "ion storm exposes flying risk as a separate military signal")
	_expect(is_equal_approx(_intel(ion_energy, "range_multiplier"), 1.0) and is_equal_approx(_intel(ion_energy, "duration_multiplier"), 1.0), "ion storm has no unrequested intel penalty")

	var gravity_ocean := _resolve(resolver, "gravity_tide", {"movement_domain": "sea"})
	var gravity_heavy_land := _resolve(resolver, "gravity_tide", {"movement_domain": "land", "unit_tags": ["heavy"]})
	var gravity_light_land := _resolve(resolver, "gravity_tide", {"movement_domain": "land", "unit_tags": ["light"]})
	var gravity_force := _resolve(resolver, "gravity_tide", {"unit_tags": ["knockback", "orbital"]})
	_expect(_route(gravity_ocean, "ocean_multiplier") < 1.0 and _route(gravity_ocean, "ocean_multiplier") >= WeatherEffectResolver.ROUTE_FLOOR, "gravity tide slows ocean efficiency within floor")
	_expect(_route(gravity_heavy_land, "land_multiplier") < 1.0 and is_equal_approx(_route(gravity_light_land, "land_multiplier"), 1.0), "gravity tide slows only heavy land movement")
	_expect(_military(gravity_force, "knockback_multiplier") > 1.0 and _military(gravity_force, "orbital_multiplier") > 1.0, "gravity tide boosts knockback and orbital effects")

	var spore_bio := _resolve(resolver, "spore_season", {"product_tags": ["weather_biological"], "monster_tags": ["biological"], "route_mode": "land"})
	var spore_crystal := _resolve(resolver, "spore_season", {"product_tags": ["weather_crystal"], "monster_tags": ["crystal"]})
	_expect(_economy(spore_bio, "production_multiplier") > 1.0 and _economy(spore_bio, "demand_multiplier") > 1.0, "spore season boosts matching bio production and demand")
	_expect(_monster(spore_bio, "preference_multiplier") > 1.0 and _monster(spore_bio, "target_score_multiplier") > 1.0, "spore season outputs structured biological monster preference")
	_expect(_route(spore_bio, "generic_multiplier") < 1.0, "spore season applies small route drag in route context")
	_expect(is_equal_approx(_economy(spore_crystal, "production_multiplier"), 1.0) and is_equal_approx(_monster(spore_crystal, "preference_multiplier"), 1.0), "spore season leaves non-matching crystal economy/monsters unchanged")

	var crystal := _resolve(resolver, "crystal_dust_storm", {"product_tags": ["weather_crystal"], "monster_tags": ["crystal"], "unit_tags": ["ranged"]})
	var crystal_nonmatch := _resolve(resolver, "crystal_dust_storm", {"product_tags": ["weather_food"], "monster_tags": ["cold"], "unit_tags": ["melee"]})
	_expect(_economy(crystal, "production_multiplier") > 1.0 and is_equal_approx(_economy(crystal_nonmatch, "production_multiplier"), 1.0), "crystal dust boosts only crystal production")
	_expect(_monster(crystal, "armor_multiplier") > 1.0 and is_equal_approx(_monster(crystal_nonmatch, "armor_multiplier"), 1.0), "crystal dust boosts only crystal monster armor")
	_expect(_military(crystal, "ranged_multiplier") < 1.0 and _military(crystal, "ranged_multiplier") >= WeatherEffectResolver.MILITARY_FLOOR, "crystal dust weakens ranged effects within floor")
	var damage := crystal.get("damage", {}) as Dictionary
	_expect(float(damage.get("per_second", 0.0)) > 0.0 and bool(damage.get("nonlethal", false)) and bool(damage.get("capped", false)) and str(damage.get("policy", "")) == "nonlethal_capped", "crystal dust damage is light, nonlethal and capped")

	var freeze := _resolve(resolver, "deep_freeze", {"product_tags": ["weather_food"], "movement_domain": "land", "monster_tags": ["cold"], "context_tags": ["city", "maintenance"]})
	var freeze_nonmatch := _resolve(resolver, "deep_freeze", {"product_tags": ["weather_crystal"], "movement_domain": "air", "monster_tags": ["crystal"]})
	_expect(_economy(freeze, "demand_multiplier") > 1.0 and _economy(freeze, "maintenance_multiplier") > 1.0, "deep freeze raises food/energy demand and maintenance")
	_expect(_route(freeze, "land_multiplier") < 1.0 and is_equal_approx(_route(freeze_nonmatch, "air_multiplier"), 1.0), "deep freeze slows land but not air movement")
	_expect(_monster(freeze, "speed_multiplier") > 1.0 and _monster(freeze, "armor_multiplier") > 1.0 and is_equal_approx(_monster(freeze_nonmatch, "speed_multiplier"), 1.0), "deep freeze boosts only cold monsters")

	var flare := CATALOG.definition("solar_flare")
	var flare_energy := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_energy"], "monster_tags": ["electromagnetic"], "intel_domain": "duration"})
	var flare_electronic := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_electronic"], "intel_domain": "duration"})
	var flare_range := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"intel_domain": "range"})
	_expect(_economy(flare_energy, "price_growth_multiplier") > 1.0, "solar flare raises energy price growth")
	_expect(_economy(flare_electronic, "production_multiplier") < 1.0, "solar flare deterministically lowers electronic production")
	_expect(_intel(flare_energy, "duration_multiplier") < 1.0 and is_equal_approx(_intel(flare_range, "range_multiplier"), 1.0), "solar flare uses deterministic intel duration penalty rather than random failure")
	_expect(_monster(flare_energy, "speed_multiplier") > 1.0 and _monster(flare_energy, "preference_multiplier") > 1.0, "solar flare boosts electromagnetic/energy monster action")

	var resistant_positive := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_energy"], "weather_resistance": 0.5})
	_expect(_economy(resistant_positive, "price_growth_multiplier") > 1.0 and _economy(resistant_positive, "price_growth_multiplier") < _economy(flare_energy, "price_growth_multiplier"), "weather resistance mitigates positive deltas")
	var resistant_negative := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_electronic"], "weather_resistance": 0.5})
	_expect(_economy(resistant_negative, "production_multiplier") < 1.0 and _economy(resistant_negative, "production_multiplier") > _economy(flare_electronic, "production_multiplier"), "weather resistance mitigates negative deltas")
	var crystal_resisted := resolver.resolve(CATALOG.definition("crystal_dust_storm"), WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_crystal"], "weather_resistance": 0.5})
	_expect(float((crystal_resisted.get("damage", {}) as Dictionary).get("per_second", 0.0)) < float(damage.get("per_second", 0.0)), "weather resistance reduces damage")
	var exploited_positive := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_energy"], "weather_exploitation_multiplier": 2.0})
	var exploited_ion := resolver.resolve(CATALOG.definition("ion_storm"), WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_energy"], "movement_domain": "air", "unit_tags": ["flying"], "weather_exploitation_multiplier": 2.0})
	var exploited_negative := resolver.resolve(flare, WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_electronic"], "weather_exploitation_multiplier": 2.0})
	var exploited_freeze := resolver.resolve(CATALOG.definition("deep_freeze"), WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_food"], "context_tags": ["city", "maintenance"], "weather_exploitation_multiplier": 2.0})
	var exploited_damage := resolver.resolve(CATALOG.definition("crystal_dust_storm"), WeatherRuntimeState.PHASE_ACTIVE, 1.0, {"product_tags": ["weather_crystal"], "weather_exploitation_multiplier": 2.0})
	_expect(_economy(exploited_positive, "price_growth_multiplier") > _economy(flare_energy, "price_growth_multiplier"), "weather exploitation amplifies positive deltas")
	_expect(_economy(exploited_ion, "price_growth_multiplier") > _economy(ion_energy, "price_growth_multiplier") and _route(exploited_ion, "air_multiplier") > _route(ion_energy, "air_multiplier"), "weather exploitation amplifies ion energy and air benefits")
	_expect(is_equal_approx(_military(exploited_ion, "flying_risk_multiplier"), _military(ion_energy, "flying_risk_multiplier")), "weather exploitation does not amplify harmful flying risk")
	_expect(is_equal_approx(_economy(exploited_freeze, "maintenance_multiplier"), _economy(freeze, "maintenance_multiplier")), "weather exploitation does not amplify harmful maintenance")
	_expect(is_equal_approx(_economy(exploited_negative, "production_multiplier"), _economy(flare_electronic, "production_multiplier")), "weather exploitation does not amplify negative deltas")
	_expect(is_equal_approx(float((exploited_damage.get("damage", {}) as Dictionary).get("per_second", 0.0)), float(damage.get("per_second", 0.0))), "weather exploitation does not amplify damage")
	var no_substring := _resolve(resolver, "solar_flare", {"product_tags": ["太阳耀斑"], "monster_tags": ["太阳耀斑"], "route_mode": "", "intel_domain": "range"})
	_expect(_effect_is_identity_except_metadata(no_substring), "resolver never applies effects from weather-name substring tags")
	_case_line("weather_semantic_matrix")


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
	_expect(str((types.get("gravity_tide", {}) as Dictionary).get("label", "")) == "引力潮" and str((types.get("crystal_dust_storm", {}) as Dictionary).get("label", "")) == "晶尘暴" and str((types.get("deep_freeze", {}) as Dictionary).get("label", "")) == "极寒期", "AI weather constant keeps exact canonical Chinese labels")
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


func _resolve(resolver: WeatherEffectResolver, type_id: String, context: Dictionary) -> Dictionary:
	return resolver.resolve(CATALOG.definition(type_id), WeatherRuntimeState.PHASE_ACTIVE, 1.0, context)


func _economy(effect: Dictionary, key: String) -> float:
	return float((effect.get("economy", {}) as Dictionary).get(key, 1.0))


func _route(effect: Dictionary, key: String) -> float:
	return float((effect.get("route", {}) as Dictionary).get(key, 1.0))


func _monster(effect: Dictionary, key: String) -> float:
	return float((effect.get("monster", {}) as Dictionary).get(key, 1.0))


func _military(effect: Dictionary, key: String) -> float:
	return float((effect.get("military", {}) as Dictionary).get(key, 1.0))


func _intel(effect: Dictionary, key: String) -> float:
	return float((effect.get("intel", {}) as Dictionary).get(key, 1.0))


func _effect_is_identity_except_metadata(effect: Dictionary) -> bool:
	if not is_equal_approx(_economy(effect, "price_growth_multiplier"), 1.0):
		return false
	if not is_equal_approx(_economy(effect, "production_multiplier"), 1.0):
		return false
	if not is_equal_approx(_economy(effect, "demand_multiplier"), 1.0):
		return false
	if not is_equal_approx(_route(effect, "generic_multiplier"), 1.0):
		return false
	if not is_equal_approx(_route(effect, "land_multiplier"), 1.0):
		return false
	if not is_equal_approx(_route(effect, "ocean_multiplier"), 1.0):
		return false
	if not is_equal_approx(_route(effect, "air_multiplier"), 1.0):
		return false
	if not is_equal_approx(_monster(effect, "preference_multiplier"), 1.0):
		return false
	if not is_equal_approx(_monster(effect, "speed_multiplier"), 1.0):
		return false
	if not is_equal_approx(_monster(effect, "armor_multiplier"), 1.0):
		return false
	if not is_equal_approx(_military(effect, "ranged_multiplier"), 1.0):
		return false
	if not is_equal_approx(_intel(effect, "duration_multiplier"), 1.0):
		return false
	if not is_equal_approx(_intel(effect, "range_multiplier"), 1.0):
		return false
	return is_equal_approx(float((effect.get("damage", {}) as Dictionary).get("per_second", 0.0)), 0.0)


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
