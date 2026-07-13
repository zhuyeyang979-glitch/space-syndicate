extends Control
class_name PlanetMapMcpPreview

const FIXTURES_SCRIPT := preload("res://scripts/tools/planet_map_mcp_preview_fixtures.gd")

@onready var state_button_list: VBoxContainer = %PlanetMapStateButtonList
@onready var title_label: Label = %PlanetMapPreviewTitle
@onready var summary_label: Label = %PlanetMapPreviewSummary
@onready var status_label: Label = %PlanetMapPreviewStatus
@onready var planet_board: Node = %PlanetBoard

var _fixtures: RefCounted = FIXTURES_SCRIPT.new()
var _selected_fixture_id := "globe_overview"


func _ready() -> void:
	_connect_static_buttons()
	apply_fixture(_selected_fixture_id)


func preview_ids() -> Array[String]:
	var ids_variant: Variant = _fixtures.call("preview_ids")
	var result: Array[String] = []
	if ids_variant is Array:
		for id in ids_variant:
			result.append(str(id))
	return result


func selected_fixture_id() -> String:
	return _selected_fixture_id


func fixture(id: String) -> Dictionary:
	var data_variant: Variant = _fixtures.call("fixture", id)
	if data_variant is Dictionary:
		return (data_variant as Dictionary).duplicate(true)
	return {}


func current_map_debug_snapshot() -> Dictionary:
	var map_view := _map_view()
	if map_view != null and map_view.has_method("get_sceneization_debug_snapshot"):
		var snapshot_variant: Variant = map_view.call("get_sceneization_debug_snapshot")
		if snapshot_variant is Dictionary:
			return snapshot_variant as Dictionary
	if map_view != null and map_view.has_method("get_projection_debug_snapshot"):
		var projection_variant: Variant = map_view.call("get_projection_debug_snapshot")
		if projection_variant is Dictionary:
			return projection_variant as Dictionary
	return {}


func apply_fixture(id: String) -> bool:
	var data := fixture(id)
	if data.is_empty():
		return false
	_selected_fixture_id = id
	_update_labels(data)
	_apply_planet_board_state(data)
	var map_view := _map_view()
	if map_view == null or not map_view.has_method("set_map"):
		_set_status("PlanetMapView missing")
		return false
	map_view.call(
		"set_map",
		_convert_districts(data.get("districts", [])),
		float(data.get("map_width_m", 1400.0)),
		float(data.get("map_height_m", 950.0)),
		int(data.get("selected", -1)),
		_convert_colors(data.get("palette", [])),
		_convert_vector_entries(data.get("movement_trails", []), ["from", "to"]),
		_convert_color_entries(data.get("action_callouts", []), ["accent", "color"]),
		_convert_vector_entries(_convert_color_entries(data.get("map_event_effects", []), ["color"]), ["from", "to", "position"]),
		_convert_vector_entries(_convert_color_entries(data.get("monster_markers", []), ["color", "secondary", "slot_color"]), ["position"]),
		_convert_vector_entries(_convert_color_entries(data.get("city_markers", []), ["tag_color"]), ["position"]),
		_convert_route_markers(data.get("trade_routes", [])),
		str(data.get("trade_product", "")),
		str(data.get("visual_layer_focus", "all"))
	)
	if map_view.has_method("set_preview_note"):
		map_view.call("set_preview_note", str(data.get("hint", "")))
	if str(data.get("projection", "globe")) == "local" and map_view.has_method("zoom_to_local_projection"):
		map_view.call("zoom_to_local_projection")
	elif map_view.has_method("reset_to_planet_overview"):
		map_view.call("reset_to_planet_overview")
	var focus_index := int(data.get("focus_district", -1))
	if focus_index >= 0 and map_view.has_method("focus_district"):
		map_view.call("focus_district", focus_index)
	_set_status(_fixture_status_text(id, _convert_districts(data.get("districts", [])).size()))
	return true


func _connect_static_buttons() -> void:
	_connect_button(%GlobeOverviewButton, "globe_overview")
	_connect_button(%SelectedDistrictButton, "selected_district")
	_connect_button(%LocalZoomButton, "local_zoom")
	_connect_button(%MonsterMarkersButton, "monster_markers")
	_connect_button(%TradeRoutesButton, "trade_routes")
	_connect_button(%UnderlayGuidesButton, "underlay_guides")
	_connect_button(%EventEffectsButton, "event_effects")
	_connect_button(%RenderCutoverButton, "render_cutover")
	_connect_button(%EmptyMapButton, "empty_map_safe_state")


func _connect_button(button: Button, fixture_id: String) -> void:
	if button == null:
		return
	var callback := func() -> void:
		apply_fixture(fixture_id)
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _map_view() -> Control:
	if planet_board != null and planet_board.has_method("get_embedded_map_view"):
		var embedded_variant: Variant = planet_board.call("get_embedded_map_view")
		if embedded_variant is Control:
			return embedded_variant as Control
	if planet_board != null:
		return planet_board.find_child("PlanetMapView", true, false) as Control
	return null


func _apply_planet_board_state(data: Dictionary) -> void:
	if planet_board == null or not planet_board.has_method("set_board_state"):
		return
	planet_board.call("set_board_state", {
		"title": "星球地图 QA",
		"hint": str(data.get("hint", "")),
		"left_rail": {
			"title": "地表情报",
			"entries": [
				{"label": "Fixture", "value": str(data.get("id", "")), "tone": "info"},
				{"label": "Selected", "value": str(data.get("selected", -1)), "tone": "warning"},
				{"label": "Projection", "value": str(data.get("projection", "globe")), "tone": "success"},
			],
		},
		"right_rail": {
			"title": "可编辑层",
			"entries": [
				{"label": "District", "value": "scene", "tone": "info"},
				{"label": "Routes", "value": "scene", "tone": "info"},
				{"label": "Monsters", "value": "scene", "tone": "warning"},
			],
		},
		"flow_compass": {
			"title": "Map QA",
			"steps": ["总览", "选区", "局部", "怪兽", "商路", "底层", "事件", "切换"],
			"active_index": max(0, preview_ids().find(str(data.get("id", "")))),
			"next": "检查中心星球是否可见",
		},
	})


func _update_labels(data: Dictionary) -> void:
	if title_label != null:
		title_label.text = str(data.get("title", data.get("id", "")))
	if summary_label != null:
		summary_label.text = "%s\nid: %s  projection: %s  selected: %s" % [
			str(data.get("hint", "")),
			str(data.get("id", "")),
			str(data.get("projection", "")),
			str(data.get("selected", "")),
		]


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _fixture_status_text(id: String, region_count: int) -> String:
	var snapshot := current_map_debug_snapshot()
	if snapshot.is_empty():
		return "Fixture: %s | districts: %d" % [id, region_count]
	return "Fixture: %s | districts: %d | cutover:%s legacy:%s scale:%s | underlay globe:%s orbit:%s focus:%s | nodes poly:%d d:%d seg:%d trail:%d event:%d call:%d city:%d monster:%d route:%d select:%d" % [
		id,
		region_count,
		str(snapshot.get("sceneized_visual_cutover_enabled", false)),
		str(snapshot.get("legacy_draw_fallback_used", false)),
		str(snapshot.get("scale_hint_sceneized", false)),
		str(snapshot.get("globe_backdrop_sceneized", false)),
		str(snapshot.get("orbit_guide_sceneized", false)),
		str(snapshot.get("focus_range_overlay_sceneized", false)),
		int(snapshot.get("district_polygon_count", 0)),
		int(snapshot.get("district_node_count", 0)),
		int(snapshot.get("route_segment_count", 0)),
		int(snapshot.get("movement_trail_count", 0)),
		int(snapshot.get("map_event_effect_count", 0)),
		int(snapshot.get("action_callout_count", 0)),
		int(snapshot.get("city_marker_count", 0)),
		int(snapshot.get("monster_token_count", 0)),
		int(snapshot.get("route_marker_count", 0)),
		int(snapshot.get("selection_marker_count", 0)),
	]


func _convert_districts(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		entry["center"] = _array_to_vector2(entry.get("center", [0, 0]))
		entry["polygon"] = _point_array(entry.get("polygon", []))
		result.append(entry)
	return result


func _convert_route_markers(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for route_variant in source:
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		route["points"] = _point_array(route.get("points", []))
		result.append(route)
	return result


func _convert_vector_entries(source: Variant, fields: Array) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		for field_variant in fields:
			var field := str(field_variant)
			if entry.has(field):
				entry[field] = _array_to_vector2(entry.get(field, [0, 0]))
		result.append(entry)
	return result


func _convert_color_entries(source: Variant, fields: Array) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for entry_variant in source:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = (entry_variant as Dictionary).duplicate(true)
		for field_variant in fields:
			var field := str(field_variant)
			if entry.has(field):
				entry[field] = Color(str(entry.get(field, "#ffffff")))
		result.append(entry)
	return result


func _convert_colors(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for value in source:
		result.append(Color(str(value)))
	return result


func _point_array(source: Variant) -> Array:
	var result: Array = []
	if not (source is Array):
		return result
	for value in source:
		result.append(_array_to_vector2(value))
	return result


func _array_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO
