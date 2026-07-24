@tool
extends Node
class_name AiRuntimeWorldBridge

var _world: Node


func bind_world(world: Node) -> void:
	_world = world


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		push_error("AiRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	return _world.callv(method_name, arguments)


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"generic_get_enabled": false,
		"generic_set_enabled": false,
		"generic_constant_lookup_enabled": false,
		"generic_route_intent_enabled": false,
		"table_selection_state_ready": false,
		"world_session_state_ready": false,
		"rng_service_ready": false,
		"generic_call_remaining": true,
		"owns_ai_state": false,
		"owns_ai_scoring": false,
	}
