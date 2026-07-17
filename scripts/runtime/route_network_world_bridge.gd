@tool
extends Node
class_name RouteNetworkWorldBridge

var _world: Node
var _world_session_state: WorldSessionState
var _region_infrastructure_controller: Node
var _capture_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func world_session_state() -> WorldSessionState:
	return _world_session_state


func set_region_infrastructure_controller(controller: Node) -> void:
	_region_infrastructure_controller = controller


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func capture_route_topology() -> Dictionary:
	if _region_infrastructure_controller == null:
		return {}
	_capture_count += 1
	var regions: Array = _region_infrastructure_controller.call("regions_snapshot") if _region_infrastructure_controller.has_method("regions_snapshot") else []
	var facilities: Array = _region_infrastructure_controller.call("facilities_snapshot", false) if _region_infrastructure_controller.has_method("facilities_snapshot") else []
	var legacy_by_index: Dictionary = {}
	if _world_session_state != null:
		var districts_variant: Variant = _world_session_state.districts
		if districts_variant is Array:
			for legacy_index in range((districts_variant as Array).size()):
				var district: Dictionary = (districts_variant as Array)[legacy_index] if (districts_variant as Array)[legacy_index] is Dictionary else {}
				var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
				legacy_by_index[legacy_index] = {
					"terrain_id": str(district.get("terrain_id", district.get("terrain", "land"))),
					"legacy_city_active": not city.is_empty() and not bool(city.get("destroyed", false)),
				}
	var prepared_regions: Array = []
	for region_variant in regions:
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = (region_variant as Dictionary).duplicate(true)
		var legacy_index := int(region.get("legacy_index", -1))
		var legacy: Dictionary = legacy_by_index.get(legacy_index, {}) if legacy_by_index.get(legacy_index, {}) is Dictionary else {}
		if str(region.get("terrain_id", "unknown")) == "unknown" and not legacy.is_empty():
			region["terrain_id"] = str(legacy.get("terrain_id", "land"))
		region["legacy_city_active"] = bool(legacy.get("legacy_city_active", false))
		prepared_regions.append(region)
	prepared_regions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("region_id", "")) < str(right.get("region_id", "")))
	var topology_basis := {"regions": prepared_regions, "facilities": facilities}
	return {
		"ruleset_id": "v0.6",
		"regions": prepared_regions,
		"facilities": facilities.duplicate(true),
		"topology_revision": JSON.stringify(topology_basis).sha256_text(),
	}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _region_infrastructure_controller != null,
		"world_bound": has_world(),
		"world_session_state_ready": _world_session_state != null,
		"capture_count": _capture_count,
		"bridge_role": "region_and_facility_facts_for_route_derivation",
		"owns_runtime_state": false,
		"owns_route_rules": false,
		"owns_goods": false,
		"owns_cash": false,
		"pure_data": true,
	}
