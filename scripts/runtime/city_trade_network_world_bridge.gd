@tool
extends Node
class_name CityTradeNetworkWorldBridge

var _world: Node


func bind_world(world: Node) -> void:
	_world = world


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": false,
		"world_bound": _world != null and is_instance_valid(_world),
		"retired": true,
		"replacement": "RouteNetworkWorldBridge",
		"owns_runtime_state": false,
		"owns_rules": false,
	}
