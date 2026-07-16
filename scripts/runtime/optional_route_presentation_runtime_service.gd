@tool
extends Node
class_name OptionalRoutePresentationRuntimeService

signal presentation_state_changed(snapshot: Dictionary)

const FLOW_KIND_MARKET_SALE := "market_sale"
const FLOW_KIND_WAREHOUSE_INBOUND := "warehouse_inbound"
const FLOW_KIND_WAREHOUSE_OUTBOUND := "warehouse_outbound"
const FLOW_KIND_AMBIENT_CONSUMPTION := "ambient_consumption"
const VALID_FLOW_KINDS := [
	FLOW_KIND_MARKET_SALE,
	FLOW_KIND_WAREHOUSE_INBOUND,
	FLOW_KIND_WAREHOUSE_OUTBOUND,
	FLOW_KIND_AMBIENT_CONSUMPTION,
]
const VALID_STRENGTH_BANDS := ["trace", "low", "medium", "high", "bulk"]
const VALID_ACTIVITY_STATES := ["current_tick", "recent"]
const REQUIRED_SNAPSHOT_FIELDS := [
	"available",
	"public_revision",
	"selected_commodity_id",
	"rows",
]
const ALLOWED_SNAPSHOT_FIELDS := REQUIRED_SNAPSHOT_FIELDS
const REQUIRED_PUBLIC_FIELDS := [
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
const ALLOWED_PUBLIC_FIELDS := REQUIRED_PUBLIC_FIELDS
const FORBIDDEN_PUBLIC_KEYS := [
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

var route_view_enabled := false
var selected_trade_product_id := ""
var _state_revision := 0
var _compose_count := 0
var _last_input_count := 0
var _last_visible_count := 0
var _last_rejected_count := 0
var _last_public_revision := -1
var _last_snapshot_available := false


func reset_for_new_run() -> void:
	hide_routes()


func select_product(product_id: String) -> bool:
	var normalized := product_id.strip_edges()
	if normalized.is_empty():
		hide_routes()
		return false
	if route_view_enabled and selected_trade_product_id == normalized:
		return true
	route_view_enabled = true
	selected_trade_product_id = normalized
	_state_revision += 1
	presentation_state_changed.emit(local_state_snapshot())
	return true


func hide_routes() -> void:
	if not route_view_enabled and selected_trade_product_id.is_empty():
		return
	route_view_enabled = false
	selected_trade_product_id = ""
	_state_revision += 1
	presentation_state_changed.emit(local_state_snapshot())


func compose_visible_snapshot(public_flow_snapshot: Dictionary, _world_effective_seconds := -1.0) -> Array:
	_compose_count += 1
	_last_input_count = 0
	_last_visible_count = 0
	_last_rejected_count = 0
	_last_public_revision = -1
	_last_snapshot_available = false
	if not route_view_enabled or selected_trade_product_id.is_empty():
		return []
	if not _public_flow_snapshot_valid(public_flow_snapshot):
		_last_rejected_count = 1
		return []
	_last_snapshot_available = bool(public_flow_snapshot.get("available", false))
	_last_public_revision = int(public_flow_snapshot.get("public_revision", -1))
	var snapshot_product := str(public_flow_snapshot.get("selected_commodity_id", "")).strip_edges()
	if not snapshot_product.is_empty() and snapshot_product != selected_trade_product_id:
		return []
	var public_flow_summaries: Array = public_flow_snapshot.get("rows", [])
	_last_input_count = public_flow_summaries.size()
	var visible: Array = []
	for summary_variant in public_flow_summaries:
		if not (summary_variant is Dictionary):
			_last_rejected_count += 1
			continue
		var summary := summary_variant as Dictionary
		if not _public_flow_summary_valid(summary, _last_public_revision):
			_last_rejected_count += 1
			continue
		if str(summary.get("commodity_id", "")) != selected_trade_product_id:
			continue
		visible.append(_to_map_marker(summary))
	visible.sort_custom(_visible_flow_precedes)
	_last_visible_count = visible.size()
	return visible


func compose_visible_routes(public_flow_summaries: Array, world_effective_seconds := -1.0) -> Array:
	var public_revision := 0
	for summary_variant in public_flow_summaries:
		if summary_variant is Dictionary:
			public_revision = maxi(public_revision, int((summary_variant as Dictionary).get("public_revision", 0)))
	return compose_visible_snapshot({
		"available": true,
		"public_revision": public_revision,
		"selected_commodity_id": "",
		"rows": public_flow_summaries,
	}, world_effective_seconds)


func local_state_snapshot() -> Dictionary:
	return {
		"route_view_enabled": route_view_enabled,
		"selected_trade_product_id": selected_trade_product_id,
		"state_revision": _state_revision,
		"status_text": "%s｜仅显示当前或近期真实流量" % selected_trade_product_id if route_view_enabled else "商路已隐藏",
		"saved_with_economy": false,
		"affects_ai": false,
		"affects_economy": false,
	}


func debug_snapshot() -> Dictionary:
	return {
		"component": "OptionalRoutePresentationRuntimeService",
		"sceneized": scene_file_path == "res://scenes/runtime/OptionalRoutePresentationRuntimeService.tscn",
		"route_view_enabled": route_view_enabled,
		"selected_trade_product_id": selected_trade_product_id,
		"state_revision": _state_revision,
		"compose_count": _compose_count,
		"last_input_count": _last_input_count,
		"last_visible_count": _last_visible_count,
		"last_rejected_count": _last_rejected_count,
		"last_public_revision": _last_public_revision,
		"last_snapshot_available": _last_snapshot_available,
		"owns_goods": false,
		"owns_routes": false,
		"owns_receipts": false,
		"owns_warehouse_inventory": false,
		"owns_ai_state": false,
		"saved_with_economy": false,
	}


func _public_flow_snapshot_valid(snapshot: Dictionary) -> bool:
	if not _is_presentation_data(snapshot):
		return false
	if not _has_exact_allowed_fields(snapshot, REQUIRED_SNAPSHOT_FIELDS, ALLOWED_SNAPSHOT_FIELDS):
		return false
	if not (snapshot.get("available") is bool) or not bool(snapshot.get("available", false)):
		return false
	if not (snapshot.get("public_revision") is int):
		return false
	if int(snapshot.get("public_revision", -1)) < 0:
		return false
	if not _is_string_value(snapshot.get("selected_commodity_id")):
		return false
	if not (snapshot.get("rows", null) is Array):
		return false
	return true


func _public_flow_summary_valid(summary: Dictionary, snapshot_revision: int) -> bool:
	if not _is_presentation_data(summary) or _contains_forbidden_key(summary):
		return false
	if not _has_exact_allowed_fields(summary, REQUIRED_PUBLIC_FIELDS, ALLOWED_PUBLIC_FIELDS):
		return false
	if not _public_flow_field_types_valid(summary):
		return false
	var flow_event_id := str(summary.get("flow_event_id", "")).strip_edges()
	var commodity_id := str(summary.get("commodity_id", "")).strip_edges()
	var route_id := str(summary.get("route_id", "")).strip_edges()
	var from_region_id := str(summary.get("from_region_id", "")).strip_edges()
	var to_region_id := str(summary.get("to_region_id", "")).strip_edges()
	var flow_kind := str(summary.get("flow_kind", "")).strip_edges()
	var strength := str(summary.get("delivered_units_band", "")).strip_edges()
	var activity_state := str(summary.get("activity_state", "")).strip_edges()
	if flow_event_id.is_empty() or commodity_id.is_empty():
		return false
	if from_region_id.is_empty() or to_region_id.is_empty():
		return false
	if not VALID_FLOW_KINDS.has(flow_kind) or not VALID_STRENGTH_BANDS.has(strength) or not VALID_ACTIVITY_STATES.has(activity_state):
		return false
	var row_revision := int(summary.get("public_revision", -1))
	if row_revision < 0 or row_revision > snapshot_revision:
		return false
	var modes := _normalized_string_array(summary.get("transport_modes", []))
	if flow_kind == FLOW_KIND_AMBIENT_CONSUMPTION:
		if from_region_id == to_region_id \
			or not route_id.is_empty() \
			or not modes.is_empty() \
			or not bool(summary.get("ambient_one_hop", false)):
			return false
	elif route_id.is_empty() or modes.is_empty():
		return false
	var last_active := float(summary.get("last_active_world_effective", -1.0))
	if not is_finite(last_active) or last_active < 0.0:
		return false
	return true


func _to_map_marker(summary: Dictionary) -> Dictionary:
	var flow_kind := str(summary.get("flow_kind", FLOW_KIND_MARKET_SALE))
	var strength := str(summary.get("delivered_units_band", "weak"))
	var capacity_limited := bool(summary.get("capacity_limited", false))
	var congested := bool(summary.get("congested", false))
	return {
		"flow_event_id": str(summary.get("flow_event_id", "")),
		"public_revision": int(summary.get("public_revision", 0)),
		"product": str(summary.get("commodity_id", "")),
		"display_label": str(summary.get("display_label", "")),
		"route_id": str(summary.get("route_id", "")),
		"from_region_id": str(summary.get("from_region_id", "")),
		"to_region_id": str(summary.get("to_region_id", "")),
		"direction": "forward",
		"points": [],
		"transport_modes": _normalized_string_array(summary.get("transport_modes", [])),
		"flow_kind": flow_kind,
		"delivered_units_band": strength,
		"strength": _presentation_strength(strength),
		"capacity_limited": capacity_limited,
		"congested": congested,
		"disrupted": capacity_limited or congested,
		"low_emphasis": bool(summary.get("low_emphasis", false)) or flow_kind == FLOW_KIND_AMBIENT_CONSUMPTION,
		"show_marker": flow_kind != FLOW_KIND_AMBIENT_CONSUMPTION,
		"last_active_world_effective": float(summary.get("last_active_world_effective", 0.0)),
		"activity_state": str(summary.get("activity_state", "")),
	}


func _visible_flow_precedes(left_variant: Variant, right_variant: Variant) -> bool:
	var left: Dictionary = left_variant if left_variant is Dictionary else {}
	var right: Dictionary = right_variant if right_variant is Dictionary else {}
	var left_strength := _strength_rank(str(left.get("strength", "weak")))
	var right_strength := _strength_rank(str(right.get("strength", "weak")))
	if left_strength != right_strength:
		return left_strength > right_strength
	var left_time := float(left.get("last_active_world_effective", 0.0))
	var right_time := float(right.get("last_active_world_effective", 0.0))
	if not is_equal_approx(left_time, right_time):
		return left_time > right_time
	return str(left.get("flow_event_id", "")) < str(right.get("flow_event_id", ""))


func _strength_rank(band: String) -> int:
	match band:
		"strong":
			return 3
		"medium":
			return 2
	return 1


func _presentation_strength(band: String) -> String:
	match band:
		"bulk", "high":
			return "strong"
		"medium":
			return "medium"
	return "weak"


func _has_exact_allowed_fields(value: Dictionary, required_fields: Array, allowed_fields: Array) -> bool:
	for field_variant in required_fields:
		if not value.has(str(field_variant)):
			return false
	for key_variant in value.keys():
		if not allowed_fields.has(str(key_variant)):
			return false
	return true


func _public_flow_field_types_valid(summary: Dictionary) -> bool:
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
		if not _is_string_value(summary.get(field_name)):
			return false
	if not (summary.get("public_revision") is int):
		return false
	if not (summary.get("last_active_world_effective") is int or summary.get("last_active_world_effective") is float):
		return false
	for field_name in ["capacity_limited", "congested", "ambient_one_hop", "low_emphasis"]:
		if not (summary.get(field_name) is bool):
			return false
	var transport_modes: Variant = summary.get("transport_modes")
	if not (transport_modes is Array):
		return false
	for mode_variant in transport_modes as Array:
		if not _is_string_value(mode_variant) or str(mode_variant).strip_edges().is_empty():
			return false
	return true


func _is_string_value(value: Variant) -> bool:
	return value is String or value is StringName


func _normalized_string_array(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item_variant in value:
		var item := str(item_variant).strip_edges()
		if not item.is_empty() and not result.has(item):
			result.append(item)
	result.sort()
	return result


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				return true
			if _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _is_presentation_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Vector2 or value is Vector2i or value is Color:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_presentation_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName):
				return false
			if not _is_presentation_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false
