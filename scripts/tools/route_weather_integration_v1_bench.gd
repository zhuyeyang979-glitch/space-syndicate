extends Control
class_name RouteWeatherIntegrationV1Bench

const ROUTE_SCENE := preload("res://scenes/runtime/RouteNetworkRuntimeController.tscn")
const WEATHER_SCENE := preload("res://scenes/runtime/WeatherRuntimeController.tscn")
const WEATHER_BRIDGE_SCENE := preload("res://scenes/runtime/WeatherRuntimeWorldBridge.tscn")

@export var auto_run := true

@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: RichTextLabel = %DetailLabel

var _route: RouteNetworkRuntimeController
var _route_bridge: FakeRouteBridge
var _weather: WeatherRuntimeController
var _weather_bridge: WeatherRuntimeWorldBridge
var _clock: FakeClock
var _weather_world: FakeWeatherWorld
var _checks := 0
var _failures: Array[String] = []
var _case_lines: Array[String] = []
var _sequence := 0


class FakeClock:
	extends Node
	var world_us := 0

	func world_effective_micros() -> int:
		return world_us


class FakeWeatherWorld:
	extends Node
	var rng := RandomNumberGenerator.new()
	var districts: Array = []


class FakeRouteBridge:
	extends Node
	var topology: Dictionary = {}
	var camera_state := {"zoom": 0.48, "center": Vector2.ZERO}

	func capture_route_topology() -> Dictionary:
		return topology.duplicate(true)


class ExtremeWeatherProvider:
	extends Node

	func region_effect_snapshot(region_index: int, _context: Dictionary = {}) -> Dictionary:
		return {
			"available": true,
			"region_index": region_index,
			"effects": [{
				"event_id": 9001,
				"definition_id": "test_extreme_weather",
				"route": {
					"generic_multiplier": 0.10,
					"land_multiplier": 1.0,
					"ocean_multiplier": 1.0,
					"air_multiplier": 1.0,
				},
			}],
		}


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_suite")


func run_suite() -> void:
	_checks = 0
	_failures.clear()
	_case_lines.clear()
	_sequence = 0
	_setup()
	_case_ion_air_benefit()
	_case_gravity_sea_penalty()
	_case_spore_generic_penalty()
	_case_unrelated_domain_identity()
	_case_resistance_and_exploitation()
	_case_fade_and_exact_recovery()
	_case_route_floor()
	_case_save_shape_unchanged()
	_case_camera_invariance()
	_case_query_projection_does_not_mutate_cache()
	_case_public_projection_contract()
	_update_ui()
	print("ROUTE_WEATHER_INTEGRATION_V1_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
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
		"case_lines": _case_lines.duplicate(),
	}


func _setup() -> void:
	_clock = FakeClock.new()
	_clock.name = "WorldEffectiveClockRuntimeController"
	_weather_world = FakeWeatherWorld.new()
	_weather_world.rng.seed = 6702026
	_weather_world.districts = [
		{"name": "源区", "destroyed": false, "terrain": "land", "neighbors": [1]},
		{"name": "中继区", "destroyed": false, "terrain": "land", "neighbors": [0, 2]},
		{"name": "市场区", "destroyed": false, "terrain": "land", "neighbors": [1]},
		{"name": "无关区", "destroyed": false, "terrain": "land", "neighbors": []},
	]
	_weather_bridge = WEATHER_BRIDGE_SCENE.instantiate() as WeatherRuntimeWorldBridge
	_weather = WEATHER_SCENE.instantiate() as WeatherRuntimeController
	_route_bridge = FakeRouteBridge.new()
	_route = ROUTE_SCENE.instantiate() as RouteNetworkRuntimeController
	add_child(_clock)
	add_child(_weather_world)
	add_child(_weather_bridge)
	add_child(_weather)
	add_child(_route_bridge)
	add_child(_route)
	_weather_bridge.bind_world(_weather_world)
	_weather.set_world_bridge(_weather_bridge)
	_weather.set_world_effective_clock(_clock)
	_weather.configure({"ruleset_id": "v0.6"})
	_route.set_world_bridge(_route_bridge)
	_route.set_weather_runtime_controller(_weather)
	var configured := _route.configure(_route_profile())
	_expect(bool(configured.get("configured", false)), "route owner configures against the v0.6 profile")


func _case_ion_air_benefit() -> void:
	_set_route_topology("air")
	_clear_weather()
	var baseline := _first_route()
	_set_active_weather("ion_storm", 0)
	var affected := _first_route()
	_expect(_base_capacity(affected) == _base_capacity(baseline), "ion storm keeps the cached base bottleneck intact")
	_expect(str(affected.get("route_id", "")) == str(baseline.get("route_id", "")) and affected.get("ordered_legs", []) == baseline.get("ordered_legs", []), "weather projection preserves route identity and topology")
	_expect(_effective_capacity(affected) == 118 and is_equal_approx(float(affected.get("route_efficiency_multiplier", 0.0)), 1.18), "ion storm raises air-route capacity by 18 percent")
	_expect(_all_resources_match_multiplier(affected, 1.18), "ion storm scales every air-route capacity resource")
	_expect(str(affected.get("route_efficiency_explanation", "")).contains("ion_storm:air:+18%"), "ion air benefit has a public explanation code")
	_case_line("ion_air_benefit")


func _case_gravity_sea_penalty() -> void:
	_set_route_topology("sea")
	_set_active_weather("gravity_tide", 0)
	var affected := _first_route()
	_expect(_effective_capacity(affected) == 75 and is_equal_approx(float(affected.get("route_efficiency_multiplier", 0.0)), 0.75), "gravity tide reduces sea-route capacity to 75 percent")
	_expect((affected.get("mode_tags", []) as Array).has("sea") and not (affected.get("mode_tags", []) as Array).has("ocean"), "the canonical route mode remains sea outside the weather boundary")
	_expect(str(affected.get("route_efficiency_explanation", "")).contains("gravity_tide:ocean:-25%"), "sea is normalized to ocean only at the weather boundary")
	_case_line("gravity_sea_penalty")


func _case_spore_generic_penalty() -> void:
	_set_route_topology("land")
	_set_active_weather("spore_season", 0)
	var affected := _first_route()
	_expect(_effective_capacity(affected) == 92 and is_equal_approx(float(affected.get("route_efficiency_multiplier", 0.0)), 0.92), "spore season applies its slight generic route penalty")
	_expect(_all_resources_match_multiplier(affected, 0.92), "generic weather pressure scales every capacity resource before bottleneck recomputation")
	_case_line("spore_generic_penalty")


func _case_unrelated_domain_identity() -> void:
	_set_route_topology("land")
	_clear_weather()
	var baseline := _first_route()
	_set_active_weather("ion_storm", 0)
	var unrelated := _first_route()
	_expect(unrelated == baseline, "ion storm leaves an unrelated land route byte-equivalent to baseline")
	_set_active_weather("gravity_tide", 3)
	var unrelated_region := _first_route()
	_expect(unrelated_region == baseline, "weather outside the route leaves the candidate unchanged")
	_case_line("unrelated_domain_identity")


func _case_resistance_and_exploitation() -> void:
	_set_route_topology("air", 0.50, 1.0)
	_set_active_weather("ion_storm", 0)
	var resistant := _first_route()
	_expect(_effective_capacity(resistant) == 109 and is_equal_approx(float(resistant.get("route_efficiency_multiplier", 0.0)), 1.09), "50 percent route resistance halves the positive ion benefit")
	_set_route_topology("air", 0.0, 2.0)
	_set_active_weather("ion_storm", 0)
	var exploited := _first_route()
	_expect(_effective_capacity(exploited) == 136 and is_equal_approx(float(exploited.get("route_efficiency_multiplier", 0.0)), 1.36), "weather exploitation doubles only the positive air-route delta")
	_set_route_topology("sea", 0.50, 3.0)
	_set_active_weather("gravity_tide", 0)
	var resisted_penalty := _first_route()
	_expect(_effective_capacity(resisted_penalty) == 87, "resistance softens a route penalty while exploitation does not amplify it")
	_case_line("resistance_exploitation")


func _case_fade_and_exact_recovery() -> void:
	_set_route_topology("land")
	_clear_weather()
	var baseline := _first_route()
	_set_active_weather("spore_season", 0)
	var active := _first_route()
	_clock.world_us = 50_000_000
	_weather.tick(0.0)
	var fading := _first_route()
	_clock.world_us = 55_000_000
	_weather.tick(0.0)
	var ended := _first_route()
	_expect(_effective_capacity(active) == 92 and _effective_capacity(fading) == 96, "fade linearly restores route efficiency over the final ten seconds")
	_expect(ended == baseline, "the exact fade boundary restores the complete baseline route projection")
	_case_line("fade_exact_recovery")


func _case_route_floor() -> void:
	_set_route_topology("land")
	var extreme := ExtremeWeatherProvider.new()
	add_child(extreme)
	_route.set_weather_runtime_controller(extreme)
	var floored := _first_route()
	_expect(_effective_capacity(floored) == 40 and is_equal_approx(float(floored.get("route_efficiency_multiplier", 0.0)), 0.40), "route weather projection enforces the 40 percent safety floor")
	_expect(_all_resources_match_multiplier(floored, 0.40), "the safety floor applies to every capacity resource")
	_route.set_weather_runtime_controller(_weather)
	extreme.queue_free()
	_case_line("route_floor")


func _case_save_shape_unchanged() -> void:
	_set_route_topology("air")
	_clear_weather()
	var before := _route.to_save_data()
	_set_active_weather("ion_storm", 0)
	_first_route()
	var during := _route.to_save_data()
	var forbidden := ["weather", "intensity", "route_efficiency", "camera", "player", "cash", "hand"]
	var save_text := JSON.stringify(during).to_lower()
	_expect(during == before, "query-time weather projection does not change the Route save payload")
	for token in forbidden:
		_expect(not save_text.contains(token), "route save shape excludes %s" % token)
	_case_line("save_shape_unchanged")


func _case_camera_invariance() -> void:
	_set_route_topology("sea")
	_set_active_weather("gravity_tide", 0)
	var before := _first_route()
	_route_bridge.camera_state = {"zoom": 8.0, "center": Vector2(9999.0, -4444.0), "projection": "flat"}
	var after := _first_route()
	_expect(after == before, "camera zoom, center, and projection do not alter weather route efficiency")
	_case_line("camera_invariance")


func _case_query_projection_does_not_mutate_cache() -> void:
	_set_route_topology("air")
	_clear_weather()
	var baseline := _first_route()
	var debug_before := _route.debug_snapshot()
	_set_active_weather("ion_storm", 0)
	var first := _first_route()
	var second := _first_route()
	_clear_weather()
	var restored := _first_route()
	var debug_after := _route.debug_snapshot()
	_expect(first == second, "repeated weather projections are deterministic")
	_expect(restored == baseline, "clearing weather cannot leave permanent route damage or benefit")
	_expect(int(debug_after.get("rebuild_count", -1)) == int(debug_before.get("rebuild_count", -2)), "weather queries never rebuild or mutate cached topology")
	_case_line("query_projection_no_cache_mutation")


func _case_public_projection_contract() -> void:
	_set_route_topology("air")
	_set_active_weather("ion_storm", 0)
	var route := _first_route()
	var added_keys := [
		"base_bottleneck_units_per_minute",
		"bottleneck_units_per_minute",
		"route_efficiency_multiplier",
		"route_efficiency_explanation",
	]
	for key in added_keys:
		_expect(route.has(key), "route projection exposes public field %s" % key)
	var explanation := str(route.get("route_efficiency_explanation", "")).to_lower()
	for token in ["owner", "player", "cash", "hand", "discard", "ai_", "camera", "target_plan"]:
		_expect(not explanation.contains(token), "route weather explanation excludes private token %s" % token)
	_expect(bool(_route.debug_snapshot().get("weather_projection_query_time_only", false)), "route debug contract declares query-time-only weather projection")
	_case_line("public_projection_contract")


func _set_route_topology(mode: String, resistance := 0.0, exploitation := 1.0) -> void:
	var facility_type := {"land": "road", "sea": "port", "air": "spaceport"}.get(mode, "road") as String
	var terrain := "ocean" if mode == "sea" else "land"
	var regions := [
		_region("source", 0, terrain, ["middle"], resistance, exploitation),
		_region("middle", 1, terrain, ["source", "market"]),
		_region("market", 2, terrain, ["middle"]),
	]
	var facilities := [
		_facility("%s-source" % facility_type, "source", facility_type),
		_facility("%s-middle" % facility_type, "middle", facility_type),
		_facility("%s-market" % facility_type, "market", facility_type),
	]
	_route_bridge.topology = {
		"ruleset_id": "v0.6",
		"regions": regions,
		"facilities": facilities,
		"topology_revision": "%s-r%.2f-e%.2f" % [mode, resistance, exploitation],
	}
	_route.refresh_routes(true)


func _set_active_weather(type_id: String, region_index: int) -> void:
	_sequence += 1
	_clock.world_us = 0
	_weather.replace_runtime_state({}, [{
		"id": _sequence,
		"type": type_id,
		"definition_id": type_id,
		"districts": [region_index],
		"region_indices": [region_index],
		"phase": WeatherRuntimeState.PHASE_ACTIVE,
		"started_at": 0.0,
		"duration": 45.0,
		"ends_at": 45.0,
	}], _sequence)


func _clear_weather() -> void:
	_sequence += 1
	_clock.world_us = 0
	_weather.replace_runtime_state({}, [], _sequence)


func _first_route() -> Dictionary:
	var routes := _route.route_candidates_for_regions("fixture_commodity", "source", "market")
	return (routes[0] as Dictionary).duplicate(true) if not routes.is_empty() else {}


func _route_profile() -> Dictionary:
	return {
		"identity": {"ruleset_id": "v0.6"},
		"infrastructure": {
			"transport_throughput_by_rank": {"I": 100, "II": 150, "III": 225, "IV": 325},
			"transport_speed_multiplier_by_rank": {"I": 1.0, "II": 1.1, "III": 1.2, "IV": 1.3},
		},
		"capabilities": {
			"continuous_commodity_flow_enabled": true,
			"legacy_project_slots_enabled": false,
		},
	}


func _region(region_id: String, legacy_index: int, terrain: String, neighbors: Array, resistance := 0.0, exploitation := 1.0) -> Dictionary:
	return {
		"region_id": region_id,
		"legacy_index": legacy_index,
		"terrain_id": terrain,
		"neighbor_region_ids": neighbors.duplicate(),
		"integrity_basis_points": 10000,
		"lifecycle_state": "active",
		"legacy_city_active": true,
		"weather_resistance": resistance,
		"weather_exploitation_multiplier": exploitation,
	}


func _facility(facility_id: String, region_id: String, facility_type: String) -> Dictionary:
	return {
		"facility_id": facility_id,
		"region_id": region_id,
		"facility_type": facility_type,
		"owner_player_index": 0,
		"rank": 1,
		"active": true,
	}


func _base_capacity(route: Dictionary) -> int:
	return int(route.get("base_bottleneck_units_per_minute", -1))


func _effective_capacity(route: Dictionary) -> int:
	return int(route.get("bottleneck_units_per_minute", -1))


func _all_resources_match_multiplier(route: Dictionary, multiplier: float) -> bool:
	var resources: Array = route.get("capacity_resources", []) if route.get("capacity_resources", []) is Array else []
	if resources.is_empty():
		return false
	for resource_variant in resources:
		if not (resource_variant is Dictionary):
			return false
		var resource := resource_variant as Dictionary
		var base := int(resource.get("base_capacity_units_per_minute", -1))
		var effective := int(resource.get("capacity_units_per_minute", -1))
		if base < 0 or effective != int(floor(float(base) * multiplier)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _case_line(case_id: String) -> void:
	_case_lines.append("%s: %s" % [case_id, "PASS" if _failures.is_empty() else "CHECK"])


func _update_ui() -> void:
	if summary_label != null:
		summary_label.text = "Route Weather v1 | %s | %d checks" % ["PASS" if _failures.is_empty() else "FAIL", _checks]
	if detail_label != null:
		detail_label.text = "[b]Query-time projection[/b]\n%s\n\n[b]Failures[/b]\n%s" % [
			"\n".join(_case_lines),
			"None" if _failures.is_empty() else "\n".join(_failures),
		]
