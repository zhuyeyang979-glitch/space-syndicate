@tool
extends Node
class_name WeatherRuntimeWorldBridge

signal runtime_event_forwarded(event: Dictionary)

var _world: Node
var _rng_service: RunRngService
var _world_call_count := 0
var _failed_world_call_count := 0
var _weather_region_fact_read_count := 0
var _monster_public_count_capability_available := false


func bind_world(world: Node) -> void:
	_world = world


func set_rng_service(service: RunRngService) -> void:
	_rng_service = service


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func read_world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	if not has_world():
		return default_value
	var value: Variant = _world.get(property_name)
	return default_value if value == null else value


func write_world_value(property_name: StringName, value: Variant) -> bool:
	if not has_world():
		return false
	_world.set(property_name, value)
	return true


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		_failed_world_call_count += 1
		push_error("WeatherRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	_world_call_count += 1
	return _world.callv(method_name, arguments)


func shared_rng() -> RunRngService:
	return _rng_service


func districts_public_snapshot() -> Array:
	if not has_world():
		return []
	var value: Variant = _world.get("districts")
	var result: Array = []
	if not (value is Array):
		return result
	for index in range((value as Array).size()):
		var district := (value as Array)[index] as Dictionary
		if district == null:
			continue
		result.append({
			"index": index,
			"name": str(district.get("name", "区域%d" % index)),
			"destroyed": bool(district.get("destroyed", false)),
			"terrain": str(district.get("terrain", "land")),
			"neighbors": _integer_array(district.get("neighbors", [])),
		})
	return result


func region_facts_for_weather(region_history: Dictionary = {}) -> Array:
	_weather_region_fact_read_count += 1
	var districts := districts_public_snapshot()
	if districts.is_empty():
		return []
	var live_monster_counts := _live_monster_counts_by_region()
	var result: Array = []
	for district_variant in districts:
		var district := district_variant as Dictionary
		var index := int(district.get("index", -1))
		var city := _public_city_value(index)
		var neighbors: Array = district.get("neighbors", []) if district.get("neighbors", []) is Array else []
		result.append({
			"index": index,
			"destroyed": bool(district.get("destroyed", false)),
			"has_active_city": bool(city.get("present", false)) and bool(city.get("active", true)),
			"active_route_count": maxi(0, neighbors.size()),
			"live_monster_count": int(live_monster_counts.get(index, 0)),
			"trade_volume_bucket": _trade_volume_bucket(index),
			"last_weather_sequence": int(region_history.get(str(index), 0)),
		})
	return result


func forward_runtime_event(event: Dictionary) -> void:
	if not _is_pure_data(event):
		push_error("Weather runtime event rejected because it is not pure data.")
		return
	runtime_event_forwarded.emit(event.duplicate(true))
	if has_world() and _world.has_method("_on_weather_runtime_event"):
		_world.call("_on_weather_runtime_event", event.duplicate(true))


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"shared_rng_available": shared_rng() != null,
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"weather_region_fact_read_count": _weather_region_fact_read_count,
		"monster_public_count_capability_available": _monster_public_count_capability_available,
		"owns_weather_state": false,
		"owns_weather_rules": false,
		"owns_shared_rng": false,
		"reads_game_time": false,
		"reads_selected_district": false,
		"reads_private_player_state": false,
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true


func _integer_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var number := int(item)
			if number >= 0 and not result.has(number):
				result.append(number)
	return result


func _district_value(index: int) -> Dictionary:
	if not has_world():
		return {}
	var value: Variant = _world.get("districts")
	if not (value is Array) or index < 0 or index >= (value as Array).size():
		return {}
	var district := (value as Array)[index] as Dictionary
	return district if district != null else {}


func _public_city_value(index: int) -> Dictionary:
	var district := _district_value(index)
	var city_variant: Variant = district.get("city", {})
	if not (city_variant is Dictionary):
		return {"present": false, "active": false}
	var city := city_variant as Dictionary
	return {
		"present": not city.is_empty(),
		"active": bool(city.get("active", true)) and not bool(city.get("destroyed", false)),
		"level": maxi(0, int(city.get("level", 0))),
	}


func _trade_volume_bucket(index: int) -> int:
	var district := _district_value(index)
	if district.has("public_trade_volume_bucket"):
		return maxi(0, int(district.get("public_trade_volume_bucket", 0)))
	if district.has("trade_volume_bucket"):
		return maxi(0, int(district.get("trade_volume_bucket", 0)))
	if district.has("route_load_bucket"):
		return maxi(0, int(district.get("route_load_bucket", 0)))
	return 0


func _live_monster_counts_by_region() -> Dictionary:
	var result := {}
	if not has_world():
		return result
	_monster_public_count_capability_available = _world.has_method("weather_public_live_monster_counts_by_region")
	if not _monster_public_count_capability_available:
		return result
	var value: Variant = _world.call("weather_public_live_monster_counts_by_region")
	if not (value is Dictionary):
		return result
	for key in (value as Dictionary):
		var index := int(key)
		if index < 0:
			continue
		result[index] = maxi(0, int((value as Dictionary).get(key, 0)))
	return result
