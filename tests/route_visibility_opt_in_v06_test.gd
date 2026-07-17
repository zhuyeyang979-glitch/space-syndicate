extends SceneTree

const MAP_SCENE := preload("res://scenes/ui/PlanetMapView.tscn")
const SERVICE_SCENE := preload("res://scenes/runtime/OptionalRoutePresentationRuntimeService.tscn")
const TOOLBAR_SCENE := preload("res://scenes/ui/map/PlanetMapControlToolbar.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var service := SERVICE_SCENE.instantiate()
	_expect(service != null and service.scene_file_path == "res://scenes/runtime/OptionalRoutePresentationRuntimeService.tscn", "optional route service is sceneized")
	if service != null:
		root.add_child(service)
		_expect(not bool(service.get("route_view_enabled")) and str(service.get("selected_trade_product_id")).is_empty(), "new service defaults hidden with no selected product")
		service.queue_free()

	var embedded := MAP_SCENE.instantiate() as Control
	var fullscreen := MAP_SCENE.instantiate() as Control
	_expect(embedded != null and fullscreen != null, "embedded and fullscreen map scenes instantiate")
	if embedded == null or fullscreen == null:
		_finish()
		return
	root.add_child(embedded)
	root.add_child(fullscreen)
	embedded.size = Vector2(620, 700)
	fullscreen.size = Vector2(620, 700)
	fullscreen.position = Vector2(640, 0)
	await process_frame

	var actual_flows := _public_flow_snapshot()
	var legacy_candidates := [_legacy_candidate("晶雾")]
	var districts := _districts()
	var route_geometry := _route_geometry()
	embedded.call("set_optional_route_public_geometry", route_geometry)
	fullscreen.call("set_optional_route_public_geometry", route_geometry)
	embedded.call("set_optional_route_public_snapshot", actual_flows, 100.0)
	fullscreen.call("set_optional_route_public_snapshot", actual_flows, 100.0)
	embedded.call("set_map", districts, 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e"), Color("#f59e0b")], [], [], [], [], [], legacy_candidates, "晶雾", "all")
	fullscreen.call("set_map", districts, 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e"), Color("#f59e0b")], [], [], [], [], [], legacy_candidates, "晶雾", "all")
	_expect(_visible_route_count(embedded) == 0, "new run ignores legacy auto-selected product and shows zero routes")
	_expect(_visible_route_count(fullscreen) == 0, "fullscreen mode also remains hidden by default")

	var toolbar := TOOLBAR_SCENE.instantiate() as Control
	root.add_child(toolbar)
	await process_frame
	var legacy_actions: Array[String] = []
	var local_route_selections: Array[String] = []
	toolbar.connect("control_action_requested", func(action_id: String, _payload: Dictionary) -> void:
		legacy_actions.append(action_id)
	)
	toolbar.connect("optional_route_selection_changed", func(product_id: String) -> void:
		local_route_selections.append(product_id)
	)
	toolbar.call("set_controls", {
		"layers": [{"id": "all", "label": "全"}, {"id": "route", "label": "⇄"}],
		"selected_layer_id": "all",
		"trade": {"options": [{"id": "", "label": "隐藏商路"}, {"id": "晶雾", "label": "晶雾"}]},
	})
	toolbar.call("_on_trade_product_selected", 1)
	_expect(legacy_actions.is_empty() and local_route_selections == ["晶雾"], "toolbar route selection stays local and emits no legacy gameplay product mutation")
	var refreshed_districts := _districts()
	(refreshed_districts[1] as Dictionary)["center"] = Vector2(330, 440)
	(refreshed_districts[2] as Dictionary)["center"] = Vector2(500, 410)
	embedded.call("set_map", refreshed_districts, 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e"), Color("#f59e0b")], [], [], [], [], [], legacy_candidates, "", "all")
	var embedded_snapshot := _route_snapshot(embedded)
	var full_snapshot := _route_snapshot(fullscreen)
	_expect(int(embedded_snapshot.get("visible_route_count", -1)) == 3, "selecting a commodity reveals only its current/recent actual flows")
	_expect(int(full_snapshot.get("visible_route_count", -1)) == 3, "fullscreen uses the same opt-in actual-flow gate")
	var visible_markers: Array = embedded.get("trade_route_markers")
	_expect(_contains_flow_event(visible_markers, "sale-001") and _contains_flow_event(visible_markers, "local-sale-001") and _contains_flow_event(visible_markers, "ambient-001"), "cross-region, same-region, and ambient actual events are visible")
	_expect(not _contains_route_id(visible_markers, "candidate:future") and not _contains_flow_event(visible_markers, "expired-001"), "future candidates and expired flows stay hidden")
	var ambient := _flow_marker(visible_markers, "ambient-001")
	var ambient_points: Array = ambient.get("points", []) if ambient.get("points", []) is Array else []
	_expect(bool(ambient.get("low_emphasis", false)) and ambient_points.size() == 2 and ambient_points[0] == Vector2(330, 440) and ambient_points[1] == Vector2(500, 410) and not bool(ambient.get("show_marker", true)), "adjacent ambient flow is one-hop, low emphasis, and uses the incoming map snapshot")
	embedded.call("set_map", districts, 1400.0, 950.0, -1, [Color("#38bdf8"), Color("#22c55e"), Color("#f59e0b")], [], [], [], [], [], legacy_candidates, "", "all")
	_expect(_visible_route_count(embedded) == 3 and str(embedded.get("trade_product")) == "晶雾", "ordinary map refresh preserves the player's local route opt-in")

	var malformed_wrapper := actual_flows.duplicate(true)
	malformed_wrapper["available"] = "false"
	embedded.call("set_optional_route_public_snapshot", malformed_wrapper, 100.0)
	_expect(_visible_route_count(embedded) == 0, "wrongly typed public wrapper fields fail closed")
	var malformed_row_snapshot := actual_flows.duplicate(true)
	var malformed_rows: Array = malformed_row_snapshot.get("rows", [])
	(malformed_rows[0] as Dictionary)["capacity_limited"] = "false"
	malformed_row_snapshot["rows"] = [malformed_rows[0]]
	embedded.call("set_optional_route_public_snapshot", malformed_row_snapshot, 100.0)
	_expect(_visible_route_count(embedded) == 0, "wrongly typed public row fields fail closed")
	embedded.call("set_optional_route_public_snapshot", actual_flows, 100.0)

	var economy_before := {
		"cash": [1000, 1000, 1000],
		"receipt_revision": 44,
		"warehouse_revision": 12,
		"ai_route_plan_hash": "private-unchanged",
	}
	var fingerprint_before := var_to_str(economy_before)
	embedded.call("set_optional_route_selection", "氦藻")
	_expect(_visible_route_count(embedded) == 1 and str(embedded.get("trade_product")) == "氦藻", "switching product changes presentation filter only")
	embedded.call("hide_optional_route_presentation")
	_expect(_visible_route_count(embedded) == 0 and str(embedded.get("trade_product")).is_empty(), "closing hides every route immediately")
	_expect(var_to_str(economy_before) == fingerprint_before, "hidden and visible presentation paths leave economic fingerprint unchanged")

	var public_markers := _public_marker_projection(visible_markers)
	_expect(not _contains_key_recursive(public_markers, "supplier_player_index") and not _contains_key_recursive(public_markers, "candidate_id"), "public route projection excludes supplier identity and candidate metadata")
	var local_state: Dictionary = embedded_snapshot.get("local_state", {}) if embedded_snapshot.get("local_state", {}) is Dictionary else {}
	_expect(bool(local_state.get("saved_with_economy", true)) == false and bool(local_state.get("affects_ai", true)) == false, "local visibility state is excluded from economy save and AI")

	embedded.queue_free()
	fullscreen.queue_free()
	toolbar.queue_free()
	await process_frame
	_finish()


func _public_flow_snapshot() -> Dictionary:
	return {
		"available": true,
		"public_revision": 8,
		"selected_commodity_id": "",
		"rows": [
			_flow("sale-001", "晶雾", "route:sale", "region.a", "region.c", "high", "market_sale", 99.5, 5, "current_tick"),
			_flow("local-sale-001", "晶雾", "route:local", "region.a", "region.a", "low", "market_sale", 99.0, 5, "current_tick"),
			_flow("ambient-001", "晶雾", "", "region.b", "region.c", "trace", "ambient_consumption", 98.0, 6, "recent", {"ambient_one_hop": true, "transport_modes": [], "low_emphasis": true}),
			_flow("warehouse-001", "氦藻", "route:warehouse", "region.a", "region.b", "medium", "warehouse_inbound", 97.0, 7, "recent", {"capacity_limited": true}),
			_flow("expired-001", "晶雾", "route:expired", "region.a", "region.b", "medium", "market_sale", 70.0, 8, "expired"),
			_legacy_candidate("晶雾"),
		],
	}


func _flow(event_id: String, commodity_id: String, route_id: String, from_id: String, to_id: String, band: String, kind: String, last_active: float, revision: int, activity_state: String, extras: Dictionary = {}) -> Dictionary:
	var result := {
		"flow_event_id": event_id,
		"public_revision": revision,
		"commodity_id": commodity_id,
		"from_region_id": from_id,
		"to_region_id": to_id,
		"flow_kind": kind,
		"display_label": "%s → %s" % [from_id, to_id],
		"route_id": route_id,
		"transport_modes": ["land"],
		"delivered_units_band": band,
		"capacity_limited": false,
		"congested": false,
		"last_active_world_effective": last_active,
		"activity_state": activity_state,
		"ambient_one_hop": false,
		"low_emphasis": false,
	}
	result.merge(extras, true)
	return result


func _districts() -> Array:
	return [
		{"region_id": "region.a", "name": "A", "center": Vector2(140, 220)},
		{"region_id": "region.b", "name": "B", "center": Vector2(300, 420)},
		{"region_id": "region.c", "name": "C", "center": Vector2(470, 390)},
	]


func _route_geometry() -> Dictionary:
	return {
		"route:sale": [Vector2(140, 220), Vector2(320, 180), Vector2(490, 260)],
		"route:local": [Vector2(140, 220), Vector2(185, 175), Vector2(225, 220)],
		"route:warehouse": [Vector2(160, 250), Vector2(310, 410)],
		"route:expired": [Vector2(160, 250), Vector2(310, 410)],
	}


func _legacy_candidate(product_id: String) -> Dictionary:
	return {
		"candidate_id": "future-candidate",
		"route_id": "candidate:future",
		"product": product_id,
		"points": [Vector2(40, 40), Vector2(580, 620)],
		"planned_route_id": "private-plan",
	}


func _route_snapshot(map_view: Control) -> Dictionary:
	var value: Variant = map_view.call("optional_route_presentation_snapshot")
	return value if value is Dictionary else {}


func _visible_route_count(map_view: Control) -> int:
	return int(_route_snapshot(map_view).get("visible_route_count", -1))


func _contains_flow_event(markers: Array, event_id: String) -> bool:
	return not _flow_marker(markers, event_id).is_empty()


func _flow_marker(markers: Array, event_id: String) -> Dictionary:
	for marker_variant in markers:
		if marker_variant is Dictionary and str((marker_variant as Dictionary).get("flow_event_id", "")) == event_id:
			return marker_variant as Dictionary
	return {}


func _contains_route_id(markers: Array, route_id: String) -> bool:
	for marker_variant in markers:
		if marker_variant is Dictionary and str((marker_variant as Dictionary).get("route_id", "")) == route_id:
			return true
	return false


func _public_marker_projection(markers: Array) -> Array:
	var result: Array = []
	for marker_variant in markers:
		if marker_variant is Dictionary:
			result.append((marker_variant as Dictionary).duplicate(true))
	return result


func _contains_key_recursive(value: Variant, searched_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == searched_key or _contains_key_recursive((value as Dictionary).get(key_variant), searched_key):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_key_recursive(item_variant, searched_key):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ROUTE_VISIBILITY_OPT_IN_V06_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("ROUTE_VISIBILITY_OPT_IN_V06_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
