@tool
extends Node
class_name WeatherRuntimeWorldBridge

signal runtime_event_forwarded(event: Dictionary)

var _world: Node
var _world_call_count := 0
var _failed_world_call_count := 0


func bind_world(world: Node) -> void:
	_world = world


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


func shared_rng() -> RandomNumberGenerator:
	if not has_world():
		return null
	var value: Variant = _world.get("rng")
	return value as RandomNumberGenerator if value is RandomNumberGenerator else null


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
		"owns_weather_state": false,
		"owns_weather_rules": false,
		"owns_shared_rng": false,
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
