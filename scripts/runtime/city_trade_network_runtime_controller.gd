@tool
extends Node
class_name CityTradeNetworkRuntimeController

const RETIRED_BY := "SS06-03"


func configure(_profile_snapshot: Dictionary) -> Dictionary:
	return {"configured": false, "retired": true, "reason": "replaced_by_route_network_runtime_controller"}


func reset_state() -> void:
	pass


func to_save_data() -> Dictionary:
	return {"retired": true, "retired_by": RETIRED_BY, "replacement": "RouteNetworkRuntimeController"}


func apply_save_data(_data: Dictionary) -> Dictionary:
	return {"applied": false, "retired": true, "reason": "legacy_city_trade_state_not_supported"}


func debug_snapshot(_viewer_index := -1) -> Dictionary:
	return {
		"controller_ready": false,
		"controller_authoritative": false,
		"retired": true,
		"retired_by": RETIRED_BY,
		"replacement": "RouteNetworkRuntimeController",
		"owns_route_topology": false,
		"owns_project_state": false,
		"owns_cashflow": false,
	}
