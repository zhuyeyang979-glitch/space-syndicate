extends Control
class_name MonsterWeatherIntegrationV1Bench

const MONSTER_SCENE := preload("res://scenes/runtime/MonsterRuntimeController.tscn")
const MONSTER_BRIDGE_SCENE := preload("res://scenes/runtime/MonsterRuntimeWorldBridge.tscn")
const WEATHER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const WEATHER_BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")
const CARD_CATALOG_SCENE := preload("res://scenes/runtime/CardRuntimeCatalogService.tscn")
const WEATHER_CATALOG := preload("res://resources/weather/weather_definition_catalog_v1.tres")
const FAMILY_TRAITS := preload("res://resources/monsters/monster_family_weather_traits_v1.tres")

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _clock: FakeClock
var _world: FakeWorld
var _weather: WeatherRuntimeController
var _monster: MonsterRuntimeController
var _checks := 0
var _failures: Array[String] = []
var _case_lines: Array[String] = []


class FakeClock:
	extends Node
	var world_us := 0

	func world_effective_micros() -> int:
		return world_us

	func restore_micros(value: int) -> Dictionary:
		world_us = maxi(0, value)
		return {"world_effective_us": world_us}


class FakeWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts: Array = []
	var players: Array = []
	var game_time := 0.0
	var selected_player := 0
	var selected_district := 0
	var logs: Array[String] = []
	var last_advance_speed := 0.0

	func _duration_short_text(seconds: float) -> String:
		return "%d秒" % ceili(maxf(0.0, seconds))

	func _district_center(index: int) -> Vector2:
		return Vector2(float(index) * 100.0, 0.0)

	func _log(message: String) -> void:
		logs.append(message)

	func _add_action_callout(_source: String, _title: String, _detail: String, _accent: Color, _world_position: Vector2, _duration: float = 5.0) -> void:
		pass

	func _district_city(index: int) -> Dictionary:
		if index < 0 or index >= districts.size():
			return {}
		return (districts[index] as Dictionary).get("city", {}) as Dictionary

	func _city_is_active(city: Dictionary) -> bool:
		return bool(city.get("active", false))

	func _city_product_names(city: Dictionary) -> Array:
		return (city.get("products", []) as Array).duplicate()

	func _city_demand_names(city: Dictionary) -> Array:
		return (city.get("demands", []) as Array).duplicate()

	func _city_warehouse_stockpile_pressure(_city: Dictionary) -> int:
		return 0

	func _entity_distance_to_district(_entity: Dictionary, _district_index: int) -> float:
		return 0.0

	func _weight_part_total(parts: Dictionary) -> int:
		var total := 0
		for value_variant in parts.values():
			total += int(value_variant)
		return total

	func _probability_text(weight: int, total: int) -> String:
		return "%d%%" % roundi(float(weight) * 100.0 / float(maxi(1, total)))

	func _entity_has_linear_motion(entity: Dictionary) -> bool:
		return entity.has("linear_move_target_position") and float(entity.get("linear_move_speed_mps", 0.0)) > 0.0

	func _advance_entity_linear_motion(entity: Dictionary, delta_seconds: float) -> Dictionary:
		last_advance_speed = float(entity.get("linear_move_speed_mps", 0.0))
		var before: Vector2 = entity.get("world_position", Vector2.ZERO)
		var after := before + Vector2(last_advance_speed * maxf(0.0, delta_seconds), 0.0)
		entity["world_position"] = after
		return {
			"moved": before.distance_to(after),
			"arrived": false,
			"before": before,
			"after": after,
			"target": entity.get("linear_move_target_position", after),
			"target_district": int(entity.get("linear_move_target_district", 0)),
			"source": str(entity.get("linear_move_source", "bench")),
			"mode": str(entity.get("linear_move_mode", "walk")),
			"arrival_action": str(entity.get("linear_move_arrival_action", "")),
		}

	func _entity_world_position(entity: Dictionary) -> Vector2:
		return entity.get("world_position", Vector2.ZERO)


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_checks = 0
	_failures.clear()
	_case_lines.clear()
	_setup()
	_case_traits_are_explicit_and_stable()
	_case_matching_and_nonmatching_tags()
	_case_fade_and_end_restore_exact_baseline()
	_case_movement_derives_speed_without_persisting_it()
	_case_armor_is_per_hit_before_consumable_armor()
	_case_target_preference_is_private()
	_case_down_expired_and_save_shape()
	_update_ui()
	print("MONSTER_WEATHER_INTEGRATION_V1_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
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
	}


func _setup() -> void:
	_clock = FakeClock.new()
	_world = FakeWorld.new()
	_world.rng.seed = 7102026
	_world.districts = [
		{"name": "Alpha", "destroyed": false, "miasma": false, "products": [], "demands": [], "city": {"active": false}},
		{"name": "Beta", "destroyed": false, "miasma": false, "products": [], "demands": [], "city": {"active": false}},
	]
	var weather_bridge := WEATHER_BRIDGE_SCENE.instantiate() as WeatherRuntimeWorldBridge
	var monster_bridge := MONSTER_BRIDGE_SCENE.instantiate() as MonsterRuntimeWorldBridge
	var catalog_service := CARD_CATALOG_SCENE.instantiate() as CardRuntimeCatalogService
	_weather = WEATHER_SCENE.instantiate() as WeatherRuntimeController
	_monster = MONSTER_SCENE.instantiate() as MonsterRuntimeController
	add_child(_clock)
	add_child(_world)
	add_child(weather_bridge)
	add_child(monster_bridge)
	add_child(catalog_service)
	add_child(_weather)
	add_child(_monster)
	weather_bridge.bind_world(_world)
	monster_bridge.bind_world(_world)
	_weather.set_world_bridge(weather_bridge)
	_weather.set_world_effective_clock(_clock)
	_weather.configure({"ruleset_id": "v0.6"})
	_weather.set_new_forecasts_allowed(false)
	_monster.set_world_bridge(monster_bridge)
	_monster.set_card_runtime_catalog_service(catalog_service)
	_monster.set_weather_runtime_controller(_weather)
	_monster.configure({"ruleset_id": "v0.4"})
	_expect(bool(_weather.debug_snapshot().get("controller_ready", false)), "real WeatherRuntimeController is ready")
	_expect(bool(_monster.debug_snapshot().get("controller_ready", false)), "real MonsterRuntimeController is ready")


func _case_traits_are_explicit_and_stable() -> void:
	_expect(FAMILY_TRAITS.validation_errors().is_empty(), "family weather traits resource validates")
	_expect(FAMILY_TRAITS.catalog_index_to_family_id.size() == 8, "all eight catalog families have stable index mappings")
	var all_tags: Array = []
	for family_id_variant in FAMILY_TRAITS.catalog_index_to_family_id:
		for tag_variant in FAMILY_TRAITS.tags_for_family(str(family_id_variant)):
			if not all_tags.has(tag_variant):
				all_tags.append(tag_variant)
	for required_tag in ["electromagnetic", "biological", "crystal", "cold", "energy"]:
		_expect(all_tags.has(required_tag), "trait vocabulary includes %s" % required_tag)
	_expect(FAMILY_TRAITS.tags_for_actor("", 2).has("electromagnetic"), "catalog index fallback resolves stable family tags")
	_expect(FAMILY_TRAITS.tags_for_actor("", 99).is_empty(), "unknown index fails closed without display-name inference")
	var display_name_only := _actor("", 99, 0)
	display_name_only["name"] = "流星哨兵"
	_expect((_monster.call("_monster_weather_tags", display_name_only) as Array).is_empty(), "controller never infers weather tags from a localized display name")
	_case_line("traits")


func _case_matching_and_nonmatching_tags() -> void:
	var cases := [
		{"weather": "ion_storm", "matching": _actor("meteor_sentinel", 2, 0), "nonmatching": _actor("spore_tide_emperor", 0, 0), "field": "speed_multiplier"},
		{"weather": "spore_season", "matching": _actor("spore_tide_emperor", 0, 0), "nonmatching": _actor("prism_blade_colossus", 3, 0), "field": "preference_multiplier"},
		{"weather": "crystal_dust_storm", "matching": _actor("prism_blade_colossus", 3, 0), "nonmatching": _actor("flame_ring_proto_star", 5, 0), "field": "armor_multiplier"},
		{"weather": "deep_freeze", "matching": _actor("blue_edge_knight", 6, 0), "nonmatching": _actor("spore_tide_emperor", 0, 0), "field": "speed_multiplier"},
		{"weather": "solar_flare", "matching": _actor("flame_ring_proto_star", 5, 0), "nonmatching": _actor("prism_blade_colossus", 3, 0), "field": "speed_multiplier"},
	]
	for row_variant in cases:
		var row := row_variant as Dictionary
		_activate_weather(str(row.weather), 0)
		var matching := _effect(row.matching, 0)
		var nonmatching := _effect(row.nonmatching, 0)
		var field := str(row.field)
		_expect(bool(matching.get("active", false)) and float(matching.get(field, 1.0)) > 1.0, "%s benefits its matching family tag" % str(row.weather))
		_expect(not bool(nonmatching.get("active", true)) and is_equal_approx(float(nonmatching.get(field, 1.0)), 1.0), "%s leaves a nonmatching family unchanged" % str(row.weather))
		_expect(float(matching.get("speed_multiplier", 1.0)) <= 1.30, "%s keeps monster speed at or below 1.30" % str(row.weather))
	_activate_weather("gravity_tide", 0)
	var gravity := _effect(_actor("meteor_sentinel", 2, 0), 0)
	_expect(not bool(gravity.get("active", true)) and _identity_monster_effect(gravity), "gravity tide adds no unrequested monster family benefit")
	_case_line("tag_matrix")


func _case_fade_and_end_restore_exact_baseline() -> void:
	_activate_weather("ion_storm", 0)
	var actor := _actor("meteor_sentinel", 2, 0)
	var active_speed := float(_effect(actor, 0).get("speed_multiplier", 1.0))
	var event := (_weather.public_snapshot().get("active_zones", []) as Array)[0] as Dictionary
	var active_end := int(event.get("active_ends_at_world_us", 0))
	var fade_end := int(event.get("fade_ends_at_world_us", 0))
	_clock.restore_micros(active_end + 5_000_000)
	_weather.tick(0.0)
	var fade_speed := float(_effect(actor, 0).get("speed_multiplier", 1.0))
	_expect(fade_speed > 1.0 and fade_speed < active_speed, "fade linearly reduces the matching speed benefit")
	_clock.restore_micros(fade_end)
	_weather.tick(0.0)
	_expect(_identity_monster_effect(_effect(actor, 0)), "weather end restores exact identity multipliers")
	_case_line("fade_end")


func _case_movement_derives_speed_without_persisting_it() -> void:
	_activate_weather("ion_storm", 0)
	var actor := _actor("meteor_sentinel", 2, 0)
	actor["linear_move_speed_mps"] = 10.0
	actor["linear_move_target_position"] = Vector2(100.0, 0.0)
	actor["linear_move_target_district"] = 1
	actor["linear_move_source"] = "bench"
	actor["linear_move_mode"] = "fly"
	_monster.call("_advance_entity_linear_motion", actor, 1.0)
	_expect(_world.last_advance_speed > 10.0 and _world.last_advance_speed <= 13.0, "active matching weather changes effective movement speed within cap")
	_expect(is_equal_approx(float(actor.get("linear_move_speed_mps", 0.0)), 10.0), "weather movement leaves immutable baseline speed untouched")
	_weather.reset_state()
	actor["world_position"] = Vector2.ZERO
	_monster.call("_advance_entity_linear_motion", actor, 1.0)
	_expect(is_equal_approx(_world.last_advance_speed, 10.0), "movement returns to exact baseline after weather ends")
	_case_line("movement")


func _case_armor_is_per_hit_before_consumable_armor() -> void:
	_activate_weather("crystal_dust_storm", 0)
	var actor := _actor("prism_blade_colossus", 3, 0)
	actor["hp"] = 20
	actor["max_hp"] = 20
	actor["armor"] = 2
	_monster.auto_monsters = [actor]
	_world.logs.clear()
	var hp_damage := int(_monster.call("_auto_monster_take_damage", 0, 6, "bench", -1))
	var after := _monster.auto_monsters[0] as Dictionary
	_expect(hp_damage == 3 and int(after.get("hp", 0)) == 17, "derived weather armor reduces the hit before consumable armor")
	_expect(int(after.get("armor", -1)) == 0, "only the existing two consumable armor points are spent")
	_expect(not after.has("weather_armor") and not after.has("weather_armor_multiplier"), "derived weather armor is never written to actor state")
	_expect(_world.logs.size() >= 2 and _world.logs[0].contains("天气适应") and _world.logs[1].contains("护甲抵消"), "damage log proves weather armor resolves before consumable armor")
	_weather.reset_state()
	var clear_actor := _actor("prism_blade_colossus", 3, 0)
	clear_actor["hp"] = 20
	clear_actor["max_hp"] = 20
	clear_actor["armor"] = 2
	_monster.auto_monsters = [clear_actor]
	_expect(int(_monster.call("_auto_monster_take_damage", 0, 6, "bench", -1)) == 4, "weather end restores exact baseline armor resolution")
	_case_line("armor")


func _case_target_preference_is_private() -> void:
	_activate_weather("spore_season", 1)
	var actor := _actor("spore_tide_emperor", 0, 0)
	_monster.auto_monsters = [actor]
	var dry_weight := int(_monster.call("_auto_monster_target_weight", actor, 0))
	var weather_weight := int(_monster.call("_auto_monster_target_weight", actor, 1))
	_expect(weather_weight > dry_weight, "matching weather privately increases target preference")
	var public_active := _monster.region_attraction_public_snapshot_v06(1)
	_weather.reset_state()
	_expect(int(_monster.call("_auto_monster_target_weight", actor, 1)) == dry_weight, "weather end restores exact baseline target weight")
	var public_clear := _monster.region_attraction_public_snapshot_v06(1)
	_expect(public_active == public_clear, "public attraction projection is invariant to private weather score")
	var public_text := JSON.stringify(public_active).to_lower()
	for forbidden in ["weather", "weight", "target_plan", "owner", "player", "%", "+"]:
		_expect(not public_text.contains(forbidden), "public attraction omits private token %s" % forbidden)
	_case_line("target_privacy")


func _case_down_expired_and_save_shape() -> void:
	_activate_weather("solar_flare", 0)
	var live := _actor("flame_ring_proto_star", 5, 0)
	var down := live.duplicate(true)
	down["down"] = true
	var expired := live.duplicate(true)
	expired["remaining_time"] = 0.0
	_expect(bool(_effect(live, 0).get("active", false)), "live matching monster receives weather benefit")
	_expect(_identity_monster_effect(_effect(down, 0)), "down monster receives no weather benefit")
	_expect(_identity_monster_effect(_effect(expired, 0)), "expired monster receives no weather benefit")
	_monster.auto_monsters = [live]
	var before := _monster.to_save_data()
	_effect(live, 0)
	_monster.call("_auto_monster_target_weight", live, 0)
	var after := _monster.to_save_data()
	_expect(before == after, "weather queries leave monster save payload byte-equivalent")
	var save_text := JSON.stringify(after).to_lower()
	_expect(not save_text.contains("weather_armor") and not save_text.contains("weather_speed") and not save_text.contains("weather_target"), "monster save shape contains no weather-derived state")
	_case_line("down_expired_save")


func _activate_weather(type_id: String, region_index: int) -> void:
	_weather.reset_state()
	_clock.restore_micros(0)
	var definition := WEATHER_CATALOG.definition(type_id)
	_expect(definition != null, "%s definition is available" % type_id)
	if definition == null:
		return
	_expect(_weather.schedule_forecast(type_id, region_index, 1, definition.forecast_duration, definition.active_duration, "bench", false), "%s forecast schedules" % type_id)
	_expect(_weather.activate_forecast(), "%s forecast activates" % type_id)


func _actor(family_id: String, catalog_index: int, region_index: int) -> Dictionary:
	return {
		"uid": catalog_index + 1,
		"slot": 0,
		"catalog_index": catalog_index,
		"monster_family_id": family_id,
		"name": "Bench Monster",
		"hp": 20,
		"max_hp": 20,
		"remaining_time": 60.0,
		"position": region_index,
		"world_position": _world._district_center(region_index),
		"down": false,
		"armor": 0,
		"resource_focus": [],
		"owner": -1,
		"owner_revealed": false,
	}


func _effect(actor: Dictionary, region_index: int) -> Dictionary:
	return _monster.call("_monster_weather_effect", actor, region_index) as Dictionary


func _identity_monster_effect(effect: Dictionary) -> bool:
	return is_equal_approx(float(effect.get("preference_multiplier", 1.0)), 1.0) \
		and is_equal_approx(float(effect.get("speed_multiplier", 1.0)), 1.0) \
		and is_equal_approx(float(effect.get("armor_multiplier", 1.0)), 1.0)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("MONSTER WEATHER V1: %s" % label)


func _case_line(label: String) -> void:
	_case_lines.append("%s: %s" % [label, "PASS" if _failures.is_empty() else "see failures"])


func _update_ui() -> void:
	if summary_label != null:
		summary_label.text = "Monster Weather v1 %s — %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	if detail_label != null:
		detail_label.text = "\n".join(_case_lines + _failures)
