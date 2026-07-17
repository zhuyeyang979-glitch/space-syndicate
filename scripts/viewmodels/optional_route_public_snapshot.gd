extends RefCounted
class_name OptionalRoutePublicSnapshot

const REQUIRED_FLOW_FIELDS := [
	"flow_event_id",
	"public_revision",
	"commodity_id",
	"from_region_id",
	"to_region_id",
	"flow_kind",
	"display_label",
	"route_id",
	"transport_modes",
	"delivered_units_band",
	"capacity_limited",
	"congested",
	"last_active_world_effective",
	"activity_state",
	"ambient_one_hop",
	"low_emphasis",
]
const VALID_FLOW_KINDS := [
	"market_sale",
	"warehouse_inbound",
	"warehouse_outbound",
	"ambient_consumption",
]
const VALID_STRENGTH_BANDS := ["trace", "low", "medium", "high", "bulk"]
const VALID_ACTIVITY_STATES := ["current_tick", "recent"]
const VALID_TRANSPORT_MODES := ["direct", "local", "land", "sea", "air"]
const FORBIDDEN_KEYS := [
	"candidate",
	"candidate_id",
	"route_candidate",
	"route_candidates",
	"future_route",
	"planned_route",
	"planned_route_id",
	"commodity_owner",
	"commodity_owner_player_index",
	"supplier",
	"supplier_id",
	"supplier_player_index",
	"owner_player_index",
	"source_installation_id",
	"source_factory_id",
	"demand_installation_id",
	"market_facility_id",
	"inventory_owner",
	"ai_plan",
	"ai_score",
	"score",
	"transaction_fingerprint",
]

var _snapshot: Dictionary = {}


func apply_dictionary(value: Variant) -> RefCounted:
	_snapshot = _normalize(value)
	return self


func to_ui_dictionary() -> Dictionary:
	return _snapshot.duplicate(true)


func _normalize(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	if not bool(source.get("source_bound", false)):
		return {}
	var flow_snapshot := _normalize_flow_snapshot(source.get("public_flow_snapshot", {}))
	var result := {
		"source_bound": true,
		"available": bool(flow_snapshot.get("available", false)),
		"public_flow_snapshot": flow_snapshot,
		"route_geometry_by_route_id": _normalize_geometry(
			source.get("route_geometry_by_route_id", source.get("route_geometry", {})),
			flow_snapshot
		),
		"world_effective_seconds": _normalized_world_seconds(source.get("world_effective_seconds", -1.0)),
	}
	return result


func _normalize_flow_snapshot(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _empty_flow_snapshot()
	var source := value as Dictionary
	if _contains_forbidden_key(source):
		return _empty_flow_snapshot()
	for key_variant in source.keys():
		if not ["available", "public_revision", "selected_commodity_id", "rows"].has(str(key_variant)):
			return _empty_flow_snapshot()
	if not (source.get("available") is bool) \
		or not (source.get("public_revision") is int) \
		or not _is_string(source.get("selected_commodity_id")) \
		or not (source.get("rows") is Array):
		return _empty_flow_snapshot()
	var public_revision := int(source.get("public_revision", -1))
	if public_revision < 0:
		return _empty_flow_snapshot()
	var rows: Array = []
	for row_variant in source.get("rows", []):
		var row := _normalize_flow_row(row_variant, public_revision)
		if not row.is_empty():
			rows.append(row)
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_revision := int(left.get("public_revision", 0))
		var right_revision := int(right.get("public_revision", 0))
		if left_revision != right_revision:
			return left_revision > right_revision
		return str(left.get("flow_event_id", "")) < str(right.get("flow_event_id", ""))
	)
	return {
		"available": bool(source.get("available", false)),
		"public_revision": public_revision,
		"selected_commodity_id": str(source.get("selected_commodity_id", "")).strip_edges(),
		"rows": rows,
	}


func _normalize_flow_row(value: Variant, snapshot_revision: int) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	if _contains_forbidden_key(source):
		return {}
	for field_variant in REQUIRED_FLOW_FIELDS:
		if not source.has(str(field_variant)):
			return {}
	for key_variant in source.keys():
		if not REQUIRED_FLOW_FIELDS.has(str(key_variant)):
			return {}
	for field_name in [
		"flow_event_id",
		"commodity_id",
		"from_region_id",
		"to_region_id",
		"flow_kind",
		"display_label",
		"route_id",
		"delivered_units_band",
		"activity_state",
	]:
		if not _is_string(source.get(field_name)):
			return {}
	if not (source.get("public_revision") is int) \
		or not (source.get("transport_modes") is Array) \
		or not (source.get("capacity_limited") is bool) \
		or not (source.get("congested") is bool) \
		or not (source.get("last_active_world_effective") is int or source.get("last_active_world_effective") is float) \
		or not (source.get("ambient_one_hop") is bool) \
		or not (source.get("low_emphasis") is bool):
		return {}
	var row_revision := int(source.get("public_revision", -1))
	var last_active := float(source.get("last_active_world_effective", -1.0))
	var flow_kind := str(source.get("flow_kind", "")).strip_edges()
	var route_id := str(source.get("route_id", "")).strip_edges()
	var from_region_id := str(source.get("from_region_id", "")).strip_edges()
	var to_region_id := str(source.get("to_region_id", "")).strip_edges()
	var transport_modes := _normalize_transport_modes(source.get("transport_modes", []))
	if str(source.get("flow_event_id", "")).strip_edges().is_empty() \
		or str(source.get("commodity_id", "")).strip_edges().is_empty() \
		or from_region_id.is_empty() \
		or to_region_id.is_empty() \
		or row_revision < 0 \
		or row_revision > snapshot_revision \
		or not is_finite(last_active) \
		or last_active < 0.0 \
		or not VALID_FLOW_KINDS.has(flow_kind) \
		or not VALID_STRENGTH_BANDS.has(str(source.get("delivered_units_band", "")).strip_edges()) \
		or not VALID_ACTIVITY_STATES.has(str(source.get("activity_state", "")).strip_edges()):
		return {}
	if flow_kind == "ambient_consumption":
		if not route_id.is_empty() \
			or not transport_modes.is_empty() \
			or not bool(source.get("ambient_one_hop", false)) \
			or from_region_id == to_region_id:
			return {}
	elif route_id.is_empty() or transport_modes.is_empty():
		return {}
	return {
		"flow_event_id": str(source.get("flow_event_id", "")).strip_edges(),
		"public_revision": row_revision,
		"commodity_id": str(source.get("commodity_id", "")).strip_edges(),
		"from_region_id": from_region_id,
		"to_region_id": to_region_id,
		"flow_kind": flow_kind,
		"display_label": str(source.get("display_label", "")).strip_edges(),
		"route_id": route_id,
		"transport_modes": transport_modes,
		"delivered_units_band": str(source.get("delivered_units_band", "")).strip_edges(),
		"capacity_limited": bool(source.get("capacity_limited", false)),
		"congested": bool(source.get("congested", false)),
		"last_active_world_effective": last_active,
		"activity_state": str(source.get("activity_state", "")).strip_edges(),
		"ambient_one_hop": bool(source.get("ambient_one_hop", false)),
		"low_emphasis": bool(source.get("low_emphasis", false)),
	}


func _normalize_geometry(value: Variant, flow_snapshot: Dictionary) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var actual_route_ids := {}
	for row_variant in flow_snapshot.get("rows", []):
		if not (row_variant is Dictionary):
			continue
		var route_id := str((row_variant as Dictionary).get("route_id", "")).strip_edges()
		if not route_id.is_empty():
			actual_route_ids[route_id] = true
	var result := {}
	var source := value as Dictionary
	for route_id_variant in source.keys():
		var route_id := str(route_id_variant).strip_edges()
		if route_id.is_empty() or not bool(actual_route_ids.get(route_id, false)):
			continue
		var geometry: Variant = _normalize_geometry_entry(source.get(route_id_variant))
		if not geometry.is_empty():
			result[route_id] = geometry
	return result


func _normalize_geometry_entry(value: Variant) -> Variant:
	if value is Array:
		var points: Array[Vector2] = []
		for point_variant in value:
			if not (point_variant is Vector2):
				return {}
			var point := point_variant as Vector2
			if not is_finite(point.x) or not is_finite(point.y):
				return {}
			points.append(point)
			if points.size() > 16:
				return {}
		return points if points.size() >= 2 else {}
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	if _contains_forbidden_key(source):
		return {}
	for key_variant in source.keys():
		if not ["ordered_region_ids", "transport_modes"].has(str(key_variant)):
			return {}
	var ordered_region_ids := _normalize_region_ids(source.get("ordered_region_ids", []))
	if ordered_region_ids.size() < 2:
		return {}
	return {
		"ordered_region_ids": ordered_region_ids,
		"transport_modes": _normalize_transport_modes(source.get("transport_modes", [])),
	}


func _normalize_region_ids(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result: Array = []
	for region_variant in value:
		if not _is_string(region_variant):
			return []
		var region_id := str(region_variant).strip_edges()
		if region_id.is_empty():
			return []
		if result.is_empty() or str(result.back()) != region_id:
			result.append(region_id)
		if result.size() > 9:
			return []
	return result


func _normalize_transport_modes(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result: Array = []
	for mode_variant in value:
		if not _is_string(mode_variant):
			return []
		var mode := str(mode_variant).strip_edges()
		if mode.is_empty() or not VALID_TRANSPORT_MODES.has(mode):
			return []
		if not result.has(mode):
			result.append(mode)
	return result


func _normalized_world_seconds(value: Variant) -> float:
	if not (value is int or value is float):
		return -1.0
	var seconds := float(value)
	return seconds if is_finite(seconds) and seconds >= 0.0 else -1.0


func _empty_flow_snapshot() -> Dictionary:
	return {
		"available": false,
		"public_revision": -1,
		"selected_commodity_id": "",
		"rows": [],
	}


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_KEYS.has(str(key_variant)) \
				or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _is_string(value: Variant) -> bool:
	return value is String or value is StringName
