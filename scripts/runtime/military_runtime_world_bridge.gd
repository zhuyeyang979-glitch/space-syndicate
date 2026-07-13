@tool
extends Node
class_name MilitaryRuntimeWorldBridge

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


func read_world_constant(constant_name: StringName, default_value: Variant = null) -> Variant:
	if not has_world():
		return default_value
	var world_script := _world.get_script() as Script
	if world_script == null:
		return default_value
	return world_script.get_script_constant_map().get(str(constant_name), default_value)


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		_failed_world_call_count += 1
		push_error("MilitaryRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	_world_call_count += 1
	return _world.callv(method_name, arguments)


func forward_runtime_event(event: Dictionary) -> void:
	if not _is_pure_data(event):
		push_error("Military runtime event rejected because it is not pure data.")
		return
	runtime_event_forwarded.emit(event.duplicate(true))
	if has_world() and _world.has_method("_on_military_runtime_event"):
		_world.call("_on_military_runtime_event", event.duplicate(true))


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"owns_military_state": false,
		"owns_military_rules": false,
		"owns_card_inventory": false,
		"owns_monster_health": false,
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
