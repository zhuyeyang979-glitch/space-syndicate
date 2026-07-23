@tool
extends Node
class_name AiRoutePublicQueryPort

@export var route_network_runtime_controller_path: NodePath
@export var world_session_state_path: NodePath

var _query_count := 0
var _rejected_query_count := 0


func is_ready() -> bool:
	return _route_network() != null and _world() != null \
		and bool(_route_network().public_cached_route_snapshot().get("available", false))


func public_snapshot() -> Dictionary:
	_query_count += 1
	if _route_network() == null or _world() == null:
		_rejected_query_count += 1
		return _unavailable("route_public_dependency_missing")
	var source := _route_network().public_cached_route_snapshot()
	if not bool(source.get("available", false)) or not (source.get("rows", []) is Array):
		_rejected_query_count += 1
		return _unavailable("route_public_cache_unavailable")
	var rows := (source.get("rows", []) as Array).duplicate(true)
	if not TablePresentationPureDataPolicy.is_pure_data(rows):
		_rejected_query_count += 1
		return _unavailable("route_public_rows_invalid")
	var result := {
		"schema_version": 1,
		"available": true,
		"reason_code": "route_public_snapshot_ready",
		"visibility_scope": "public",
		"topology_revision": str(source.get("topology_revision", "")),
		"route_count": rows.size(),
		"rows": rows,
	}
	result["state_revision"] = JSON.stringify([
		"ai_route_public_v1",
		result["topology_revision"],
		rows,
	]).sha256_text()
	return TablePresentationPureDataPolicy.detached_copy(result)


func region_route_summary(district_index: int) -> Dictionary:
	var region_id := _world().region_id_for_district(district_index) if _world() != null else ""
	if region_id.is_empty():
		return {}
	var rows: Array = []
	for row_variant in public_snapshot().get("rows", []) as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var region_ids: Array = row.get("ordered_region_ids", []) if row.get("ordered_region_ids", []) is Array else []
		if str(row.get("source_region_id", "")) == region_id \
				or str(row.get("market_region_id", "")) == region_id \
				or region_ids.has(region_id):
			rows.append(row.duplicate(true))
	return {
		"district_index": district_index,
		"region_id": region_id,
		"legal_route_count": rows.size(),
		"rows": rows,
		"visibility_scope": "public",
	}


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_facility_ids": false,
		"returns_capacity_resource_ids": false,
		"returns_rent_recipients": false,
		"returns_topology_fingerprints": false,
		"refreshes_routes": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _unavailable(reason_code: String) -> Dictionary:
	return {
		"schema_version": 1,
		"available": false,
		"reason_code": reason_code,
		"visibility_scope": "public",
		"topology_revision": "",
		"route_count": 0,
		"rows": [],
		"state_revision": "",
	}


func _route_network() -> RouteNetworkRuntimeController:
	return get_node_or_null(route_network_runtime_controller_path) as RouteNetworkRuntimeController


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState
