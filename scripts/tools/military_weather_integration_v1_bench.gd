extends Control
class_name MilitaryWeatherIntegrationV1Bench

const MILITARY_SCENE := preload("res://scenes/runtime/MilitaryRuntimeController.tscn")
const BRIDGE_SCENE := preload("res://scenes/runtime/MilitaryRuntimeWorldBridge.tscn")
const WORLD_SESSION_SCENE := preload("res://scenes/runtime/WorldSessionState.tscn")
const WEATHER_CATALOG := preload("res://resources/weather/weather_definition_catalog_v1.tres")
const CARD_CATALOG := preload("res://resources/cards/runtime/card_runtime_catalog_v04.tres")
const FIGHTER_FAMILY := preload("res://resources/cards/runtime/families/056_制空战斗机.tres")
const BOMBER_FAMILY := preload("res://resources/cards/runtime/families/057_轨道轰炸机.tres")
const TANK_FAMILY := preload("res://resources/cards/runtime/families/058_重装坦克.tres")
const MISSILE_FAMILY := preload("res://resources/cards/runtime/families/059_导弹阵地.tres")
const SUBMARINE_FAMILY := preload("res://resources/cards/runtime/families/060_潜航舰队.tres")
const WARSHIP_FAMILY := preload("res://resources/cards/runtime/families/061_星海战舰.tres")

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _controller: MilitaryRuntimeController
var _bridge: MilitaryRuntimeWorldBridge
var _weather: FakeWeather
var _world: FakeWorld
var _world_session: WorldSessionState
var _checks := 0
var _failures: Array[String] = []
var _case_lines: Array[String] = []


class FakeWeather:
	extends WeatherRuntimeController
	var catalog: Resource
	var definition_id := ""
	var phase := WeatherRuntimeState.PHASE_ENDED
	var intensity := 0.0
	var affected_region := 0
	var last_context: Dictionary = {}

	func set_case(next_definition_id: String, next_phase: String, next_intensity: float, region_index: int = 0) -> void:
		definition_id = next_definition_id
		phase = next_phase
		intensity = clampf(next_intensity, 0.0, 1.0)
		affected_region = region_index

	func region_effect_snapshot(region_index: int, context: Dictionary = {}) -> Dictionary:
		last_context = context.duplicate(true)
		if catalog == null or region_index != affected_region or phase == WeatherRuntimeState.PHASE_ENDED or intensity <= 0.0:
			return {"available": true, "region_index": region_index, "effects": []}
		var definition: WeatherDefinition = catalog.call("definition", definition_id)
		var effect := WeatherEffectResolver.new().resolve(definition, phase, intensity, context)
		return {"available": true, "region_index": region_index, "effects": [effect]}


class FakeWorld:
	extends Node
	var districts := [
		{"name": "测试陆区", "terrain": "land", "destroyed": false, "center": Vector2.ZERO},
		{"name": "测试海区", "terrain": "ocean", "destroyed": false, "center": Vector2(400.0, 0.0)},
	]
	var last_advance_speed := 0.0

	func _current_balance_region_radius_m() -> float:
		return 180.0

	func _entity_has_linear_motion(entity: Dictionary) -> bool:
		return entity.has("linear_move_target_position") and float(entity.get("linear_move_speed_mps", 0.0)) > 0.0

	func _advance_entity_linear_motion(entity: Dictionary, _delta: float) -> Dictionary:
		last_advance_speed = float(entity.get("linear_move_speed_mps", 0.0))
		return {"moved": last_advance_speed, "arrived": false}

	func _entity_world_position(entity: Dictionary) -> Vector2:
		return entity.get("world_position", Vector2.ZERO)

	func _nearest_district_to(_position: Vector2) -> int:
		return 0

	func _district_center(index: int) -> Vector2:
		return (districts[index] as Dictionary).get("center", Vector2.ZERO) if index >= 0 and index < districts.size() else Vector2.ZERO

	func _duration_short_text(seconds: float) -> String:
		return "%.1fs" % seconds

	func _meters_text(distance: float) -> String:
		return "%.1fm" % distance


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_checks = 0
	_failures.clear()
	_case_lines.clear()
	_setup()
	_case_machine_traits()
	_case_gravity_tide()
	_case_crystal_dust()
	_case_ion_storm()
	_case_deep_freeze()
	_case_resistance_and_exploitation()
	_case_fade_end_and_transient_motion()
	_case_save_shape_and_privacy()
	_update_ui()
	print("MILITARY_WEATHER_INTEGRATION_V1_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	if auto_run and DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _failures.is_empty() else 1)


func debug_snapshot() -> Dictionary:
	return {
		"bench_complete": true,
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"check_count": _checks,
		"failure_count": _failures.size(),
		"failed_cases": _failures.duplicate(),
	}


func _setup() -> void:
	_world = FakeWorld.new()
	_world_session = WORLD_SESSION_SCENE.instantiate() as WorldSessionState
	_bridge = BRIDGE_SCENE.instantiate() as MilitaryRuntimeWorldBridge
	_controller = MILITARY_SCENE.instantiate() as MilitaryRuntimeController
	_weather = FakeWeather.new()
	_weather.catalog = WEATHER_CATALOG
	add_child(_world)
	add_child(_world_session)
	add_child(_bridge)
	add_child(_weather)
	add_child(_controller)
	_world_session.districts = _world.districts.duplicate(true)
	_bridge.bind_world(_world)
	_bridge.set_world_session_state(_world_session)
	_controller.set_world_bridge(_bridge)
	_controller.set_weather_runtime_controller(_weather)


func _case_machine_traits() -> void:
	var catalog_validation := CARD_CATALOG.validation_report()
	var fighter := _definition(FIGHTER_FAMILY)
	var bomber := _definition(BOMBER_FAMILY)
	var tank := _definition(TANK_FAMILY)
	var missile := _definition(MISSILE_FAMILY)
	var submarine := _definition(SUBMARINE_FAMILY)
	var warship := _definition(WARSHIP_FAMILY)
	_expect(_traits(fighter).has("flying") and str(fighter.get("military_domain", "")) == "air", "fighter has explicit machine flying/air identity")
	_expect(_traits(bomber).has("flying") and _traits(bomber).has("ranged") and _traits(bomber).has("orbital"), "orbital bomber declares explicit flying, ranged and orbital traits")
	_expect(_traits(tank).has("heavy") and str(tank.get("military_domain", "")) == "land", "tank declares explicit heavy-land identity")
	_expect(_traits(missile).has("ranged") and _traits(warship).has("ranged"), "long-range military families declare ranged machine traits")
	_expect(str(submarine.get("military_domain", "")) == "sea" and _traits(submarine).has("submerged"), "submarine reuses sea domain and submerged machine trait")
	_expect(bool(catalog_validation.get("valid", false)), "military trait additions preserve the authoritative card catalog schema")
	_case_lines.append("machine traits")


func _case_gravity_tide() -> void:
	_weather.set_case("gravity_tide", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var tank := _unit_from(TANK_FAMILY)
	var light_land := tank.duplicate(true)
	light_land["movement_traits"] = ["land"]
	var submarine := _unit_from(SUBMARINE_FAMILY)
	var bomber := _unit_from(BOMBER_FAMILY)
	var knockback_unit := {"military_domain": "land", "movement_traits": ["land", "knockback"]}
	var tank_effect := _controller.military_weather_effect_snapshot(tank, 0)
	var light_effect := _controller.military_weather_effect_snapshot(light_land, 0)
	var sea_effect := _controller.military_weather_effect_snapshot(submarine, 0)
	var orbital_effect := _controller.military_weather_effect_snapshot(bomber, 0)
	var knockback_effect := _controller.military_weather_effect_snapshot(knockback_unit, 0)
	var land_target_speed := _controller.unit_movement_speed_mps(tank, 0, 220.0)
	var ocean_target_speed := _controller.unit_movement_speed_mps(tank, 1, 220.0)
	_expect(_near(float(tank_effect.get("movement_multiplier", 1.0)), 0.80), "gravity tide slows explicit heavy land units")
	_expect(_near(float(light_effect.get("movement_multiplier", 1.0)), 1.0), "gravity tide does not infer heavy identity from display text")
	_expect(_near(float(sea_effect.get("movement_multiplier", 1.0)), 0.75), "gravity tide slows sea units through normalized ocean domain")
	_expect(_near(float(orbital_effect.get("orbital_effect_multiplier", 1.0)), 1.20) and _near(float(orbital_effect.get("command_range_multiplier", 1.0)), 1.20), "gravity tide boosts orbital command range/effect")
	_expect(_near(float(knockback_effect.get("knockback_multiplier", 1.0)), 1.25) and _near(_controller.effective_knockback(knockback_unit, 0, 100.0), 125.0), "gravity tide boosts explicit knockback effects")
	_expect(ocean_target_speed < land_target_speed, "weather lookup preserves the existing target-terrain movement model")
	_case_lines.append("gravity tide")


func _case_crystal_dust() -> void:
	_weather.set_case("crystal_dust_storm", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var missile := _unit_from(MISSILE_FAMILY)
	var tank := _unit_from(TANK_FAMILY)
	var ranged := _controller.military_weather_effect_snapshot(missile, 0)
	var non_ranged := _controller.military_weather_effect_snapshot(tank, 0)
	_expect(_near(float(ranged.get("ranged_effect_multiplier", 1.0)), 0.82), "crystal dust applies its bounded ranged penalty")
	_expect(_near(_controller.effective_command_range(missile, 0, 1000.0), 820.0), "ranged weather modifier reaches command range")
	_expect(_near(float(non_ranged.get("ranged_effect_multiplier", 1.0)), 1.0), "crystal dust does not penalize a non-ranged unit")
	_expect(float(ranged.get("ranged_effect_multiplier", 0.0)) >= 0.70, "military ranged penalty remains within the 30 percent floor")
	_case_lines.append("crystal dust")


func _case_ion_storm() -> void:
	_weather.set_case("ion_storm", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var fighter := _unit_from(FIGHTER_FAMILY)
	var tank := _unit_from(TANK_FAMILY)
	var air := _controller.military_weather_effect_snapshot(fighter, 0)
	var land := _controller.military_weather_effect_snapshot(tank, 0)
	_expect(_near(float(air.get("movement_multiplier", 1.0)), 1.18), "ion storm boosts air movement")
	_expect(_near(float(air.get("flying_risk_multiplier", 1.0)), 1.20), "ion storm exposes flying risk for explicit flying units")
	_expect(_near(float(land.get("movement_multiplier", 1.0)), 1.0) and _near(float(land.get("flying_risk_multiplier", 1.0)), 1.0), "ion storm does not grant air effects to land units")
	_case_lines.append("ion storm")


func _case_deep_freeze() -> void:
	_weather.set_case("deep_freeze", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var tank := _unit_from(TANK_FAMILY)
	var submarine := _unit_from(SUBMARINE_FAMILY)
	var land := _controller.military_weather_effect_snapshot(tank, 0)
	var sea := _controller.military_weather_effect_snapshot(submarine, 0)
	_expect(_near(float(land.get("movement_multiplier", 1.0)), 0.70), "deep freeze slows land movement by at most 30 percent")
	_expect(float(land.get("movement_multiplier", 0.0)) >= 0.40, "military movement never falls below the safety floor")
	_expect(_near(float(sea.get("movement_multiplier", 1.0)), 1.0), "deep freeze land modifier does not leak into sea identity")
	_case_lines.append("deep freeze")


func _case_resistance_and_exploitation() -> void:
	_weather.set_case("ion_storm", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var resistant := _unit_from(FIGHTER_FAMILY)
	resistant["weather_resistance"] = 0.5
	var resistant_effect := _controller.military_weather_effect_snapshot(resistant, 0)
	_expect(_near(float(resistant_effect.get("movement_multiplier", 1.0)), 1.09) and _near(float(resistant_effect.get("flying_risk_multiplier", 1.0)), 1.10), "weather resistance damps both positive and harmful deltas")
	var exploited := _unit_from(FIGHTER_FAMILY)
	exploited["weather_exploitation_multiplier"] = 2.0
	var exploited_effect := _controller.military_weather_effect_snapshot(exploited, 0)
	_expect(_near(float(exploited_effect.get("movement_multiplier", 1.0)), 1.36), "weather exploitation amplifies a true air-mobility benefit")
	_expect(_near(float(exploited_effect.get("flying_risk_multiplier", 1.0)), 1.20), "weather exploitation never amplifies flying risk")
	_weather.set_case("crystal_dust_storm", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var exploited_missile := _unit_from(MISSILE_FAMILY)
	exploited_missile["weather_exploitation_multiplier"] = 3.0
	_expect(_near(float(_controller.military_weather_effect_snapshot(exploited_missile, 0).get("ranged_effect_multiplier", 1.0)), 0.82), "weather exploitation never amplifies a ranged penalty")
	_case_lines.append("resistance/exploitation")


func _case_fade_end_and_transient_motion() -> void:
	var fighter := _unit_from(FIGHTER_FAMILY)
	fighter.merge({
		"uid": 1,
		"position": 0,
		"world_position": Vector2.ZERO,
		"hp": 5,
		"remaining_time": 30.0,
		"cooldown_left": 0.0,
		"linear_move_target_position": Vector2(400.0, 0.0),
		"linear_move_speed_mps": 100.0,
	}, true)
	_controller.replace_runtime_state([fighter], 2)
	_weather.set_case("ion_storm", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	_controller.call("_update_units", 0.25)
	var active_seen := _world.last_advance_speed
	var after_active := (_controller.to_save_data().get("military_units", []) as Array)[0] as Dictionary
	_expect(_near(active_seen, 118.0), "movement tick consumes the active air multiplier")
	_expect(_near(float(after_active.get("linear_move_speed_mps", 0.0)), 100.0), "movement tick restores the persisted baseline speed immediately")
	_weather.set_case("ion_storm", WeatherRuntimeState.PHASE_FADING, 0.5)
	_controller.call("_update_units", 0.25)
	_expect(_near(_world.last_advance_speed, 109.0), "fade intensity smoothly returns movement toward baseline")
	_weather.set_case("ion_storm", WeatherRuntimeState.PHASE_ENDED, 0.0)
	_controller.call("_update_units", 0.25)
	_expect(_near(_world.last_advance_speed, 100.0), "weather expiry restores movement baseline without cleanup state")
	_case_lines.append("fade/end")


func _case_save_shape_and_privacy() -> void:
	var saved := _controller.to_save_data()
	_expect(_sorted_keys(saved) == ["military_units", "next_military_unit_uid"], "weather integration does not change military save top-level shape")
	var saved_units: Array = saved.get("military_units", []) if saved.get("military_units", []) is Array else []
	var saved_unit: Dictionary = saved_units[0] if not saved_units.is_empty() and saved_units[0] is Dictionary else {}
	var derived_keys := ["weather_effect", "weather_multiplier", "weather_movement_multiplier", "effective_weather_speed", "weather_phase"]
	_expect(derived_keys.all(func(key: String) -> bool: return not saved_unit.has(key)), "weather-derived values are absent from persisted military units")
	_weather.set_case("gravity_tide", WeatherRuntimeState.PHASE_ACTIVE, 1.0)
	var private_probe := _unit_from(BOMBER_FAMILY)
	private_probe.merge({"owner": "PRIVATE_OWNER", "cash": 999999, "hand": ["PRIVATE_CARD"], "ai_plan": "PRIVATE_PLAN"}, true)
	var public_effect := _controller.military_weather_effect_snapshot(private_probe, 0)
	var allowed := ["affected", "air_movement_multiplier", "available", "command_range_multiplier", "effect_count", "explanation_codes", "flying_risk_multiplier", "knockback_multiplier", "land_movement_multiplier", "movement_multiplier", "ocean_movement_multiplier", "orbital_effect_multiplier", "ranged_effect_multiplier", "region_index"]
	allowed.sort()
	_expect(_sorted_keys(public_effect) == allowed, "military weather projection uses a strict public multiplier allowlist")
	_expect(_sorted_keys(_weather.last_context) == ["movement_domain", "unit_tags", "weather_exploitation_multiplier", "weather_resistance"], "military sends only machine traits and intervention multipliers to WeatherRuntimeController")
	_expect(not JSON.stringify(public_effect).contains("PRIVATE_"), "military weather projection contains no private owner, cash, hand or AI values")
	var source := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	_expect(source.contains("set_weather_runtime_controller") and source.contains("region_effect_snapshot") and source.contains("effective_command_range"), "production owner uses the narrow WeatherRuntimeController API")
	_expect(not source.contains("if unit_type_label(unit_or_skill) ==") and not source.contains("if str(unit_or_skill.get(\"name\""), "weather classification never matches localized unit names")
	_case_lines.append("save/privacy")


func _definition(family: Resource) -> Dictionary:
	return family.call("definition", 1) as Dictionary


func _unit_from(family: Resource) -> Dictionary:
	return _definition(family).duplicate(true)


func _traits(definition: Dictionary) -> Array:
	return definition.get("movement_traits", []) as Array if definition.get("movement_traits", []) is Array else []


func _sorted_keys(value: Dictionary) -> Array:
	var result: Array = []
	for key in value.keys():
		result.append(str(key))
	result.sort()
	return result


func _near(actual: float, expected: float, epsilon: float = 0.001) -> bool:
	return absf(actual - expected) <= epsilon


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _update_ui() -> void:
	if summary_label != null:
		summary_label.text = "Military Weather v1 | %s | %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	if detail_label != null:
		detail_label.text = "[b]Machine-trait integration[/b]\n%s\n\n[b]Failures[/b]\n%s" % ["\n".join(_case_lines), "None" if _failures.is_empty() else "\n".join(_failures)]
