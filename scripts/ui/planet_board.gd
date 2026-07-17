extends PanelContainer
class_name SpaceSyndicatePlanetBoard

@onready var title_label: Label = %PlanetTitle
@onready var hint_label: Label = %PlanetHint
@onready var weather_forecast_strip: Control = %WeatherForecastStrip
@onready var stage_viewport: Control = %PlanetStageViewport
@onready var map_host: Control = %MapHost
@onready var embedded_map_view: Control = get_node_or_null("%PlanetMapView") as Control
@onready var playtest_flow_compass: PanelContainer = %PlaytestFlowCompass
@onready var playtest_flow_compass_title: Label = %PlaytestFlowCompassTitle
@onready var playtest_flow_compass_step_rail: HFlowContainer = %PlaytestFlowCompassStepRail
@onready var playtest_flow_compass_next_label: Label = %PlaytestFlowCompassNextLabel
@onready var left_space_rail: PanelContainer = %PlanetLeftSpaceRail
@onready var right_space_rail: PanelContainer = %PlanetRightSpaceRail
@onready var left_rail_stack: VBoxContainer = %LeftRailStack
@onready var right_rail_stack: VBoxContainer = %RightRailStack
@onready var left_rail_title: Label = %LeftRailTitle
@onready var right_rail_title: Label = %RightRailTitle
@onready var left_rail_fallback: Label = %LeftRailText
@onready var right_rail_fallback: Label = %RightRailText

const STAGE_STAR_COUNT := 54
const STAGE_ORBIT_LANE_COUNT := 5
const STAGE_EDGE_TICK_COUNT := 14
const SIDE_RAIL_GAP := 8.0
const SIDE_RAIL_MIN_WIDTH := 120.0
const SIDE_RAIL_MAX_WIDTH := 216.0
const SIDE_RAIL_MAX_HEIGHT := 310.0
const PLANET_TABLE_SAFE_CORE_RATIO := 0.64
const SIDE_RAIL_LEFT_Y_RATIO := 0.10
const SIDE_RAIL_RIGHT_Y_RATIO := 0.46
const SIDE_RAIL_MIN_STAGGER_PIXELS := 34.0
const DEFAULT_FLOW_STEPS := ["点区", "首召", "建城", "买牌", "出牌", "牌轨", "经济", "路线"]

var left_rail_signature: String = ""
var right_rail_signature: String = ""
var right_rail_suppressed := false
var _map_presentation_target_revision := 0
var _map_presentation_target_count := 0
var _presentation_authorized_viewer_index := -1
var _presentation_authorization_revision := 0
var _fullscreen_map_target: SpaceSyndicatePlanetMapView


func _ready() -> void:
	_style_board()
	if weather_forecast_strip != null:
		if weather_forecast_strip.has_method("set_compact_mode"):
			weather_forecast_strip.call("set_compact_mode", true)
		if weather_forecast_strip.has_signal("region_jump_requested"):
			weather_forecast_strip.connect("region_jump_requested", Callable(self, "_on_weather_region_jump_requested"))
	_configure_pointer_passthrough_layers()
	if map_host != null:
		map_host.clip_contents = false
		map_host.mouse_filter = Control.MOUSE_FILTER_PASS
	if stage_viewport != null:
		stage_viewport.clip_contents = false
		stage_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_fit_square_stage")
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_SORT_CHILDREN:
		call_deferred("_fit_square_stage")
		queue_redraw()


func set_board_state(data: Dictionary) -> void:
	var right_rail_data: Dictionary = _right_rail_source(data)
	right_rail_suppressed = bool(right_rail_data.get("hidden", right_rail_data.get("suppressed", false)))
	title_label.text = str(data.get("title", "星球牌桌"))
	hint_label.text = str(data.get("hint", "轨道外圈显示公开局势。"))
	hint_label.add_theme_font_size_override("font_size", 10)
	_set_space_rail(
		left_rail_stack,
		left_rail_title,
		left_rail_fallback,
		_left_rail_source(data),
		true
	)
	_set_space_rail(
		right_rail_stack,
		right_rail_title,
		right_rail_fallback,
		right_rail_data,
		false
	)
	_set_weather_strip(data.get("weather", {}))
	_set_flow_compass(data.get("flow_compass", {}))
	_configure_pointer_passthrough_layers()
	call_deferred("_fit_square_stage")


func apply_map_presentation(snapshot: MapPresentationSnapshot) -> int:
	if snapshot == null or not snapshot.is_valid() \
		or snapshot.viewer_index != _presentation_authorized_viewer_index \
		or snapshot.authorization_revision != _presentation_authorization_revision:
		return _map_presentation_target_revision
	var target := get_embedded_map_view() as SpaceSyndicatePlanetMapView
	if target == null:
		return _map_presentation_target_revision
	_apply_map_snapshot_to_target(target, snapshot)
	if _fullscreen_map_target != null and _fullscreen_map_target != target:
		_apply_map_snapshot_to_target(_fullscreen_map_target, snapshot)
	set_weather_presentation(snapshot.weather_forecast, snapshot.weather_overlay, snapshot.motion_mode)
	_map_presentation_target_revision += 1
	_map_presentation_target_count += 1
	return _map_presentation_target_revision


func bind_fullscreen_map_target(target: SpaceSyndicatePlanetMapView) -> void:
	_fullscreen_map_target = target


func _apply_map_snapshot_to_target(target: SpaceSyndicatePlanetMapView, snapshot: MapPresentationSnapshot) -> void:
	target.set_map(
		snapshot.districts,
		snapshot.width_m,
		snapshot.height_m,
		snapshot.selected_district,
		snapshot.palette,
		snapshot.movement_trails,
		snapshot.action_callouts,
		snapshot.map_event_effects,
		snapshot.unit_markers,
		snapshot.city_markers,
		snapshot.route_markers,
		snapshot.selected_trade_product,
		snapshot.selected_map_layer_focus
	)
	target.set_solar_presentation_snapshot(snapshot.solar_presentation)
	target.set_weather_overlay_view_model(snapshot.weather_overlay)
	target.set_weather_overlay_motion_mode(snapshot.motion_mode)
	target.set_solar_camera_motion_mode(snapshot.motion_mode)


func bind_presentation_viewer(viewer_index: int, authorization_revision: int) -> void:
	_presentation_authorized_viewer_index = viewer_index
	_presentation_authorization_revision = authorization_revision


func map_presentation_target_debug_snapshot() -> Dictionary:
	return {
		"target_revision": _map_presentation_target_revision,
		"apply_count": _map_presentation_target_count,
		"mouse_filter": mouse_filter,
		"authorized_viewer_index": _presentation_authorized_viewer_index,
		"authorization_revision": _presentation_authorization_revision,
		"fullscreen_target_bound": _fullscreen_map_target != null,
		"owns_gameplay_state": false,
	}


func _draw() -> void:
	_draw_stage_space()


func attach_runtime_map(map_node: Control) -> void:
	if map_node == null or map_host == null:
		return
	for child in map_host.get_children():
		if child is Control and child != map_node and (child.name == "PlanetMapView" or (child as Control).has_method("set_map")):
			(child as Control).visible = false
	var current_parent := map_node.get_parent()
	if current_parent != null:
		current_parent.remove_child(map_node)
	if map_node.name == "" or map_node.name == "Control":
		map_node.name = "RuntimeMapView"
	map_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_node.focus_mode = Control.FOCUS_ALL
	map_node.mouse_filter = Control.MOUSE_FILTER_STOP
	map_node.set_meta("runtime_focus_kind", "planet_map")
	map_node.clip_contents = false
	map_node.visible = true
	map_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_host.add_child(map_node)
	embedded_map_view = map_node
	map_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_square_stage()


func _configure_pointer_passthrough_layers() -> void:
	for node in [
		playtest_flow_compass,
		left_space_rail,
		right_space_rail,
	]:
		_set_mouse_filter_recursive(node, Control.MOUSE_FILTER_IGNORE)


func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node == null:
		return
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


func get_runtime_map_focus_control() -> Control:
	if map_host == null:
		return null
	for child in map_host.get_children():
		if child is Control and (child as Control).has_method("focus_district"):
			return child as Control
	return map_host


func get_embedded_map_view() -> Control:
	if embedded_map_view != null:
		return embedded_map_view
	if map_host == null:
		return null
	for child in map_host.get_children():
		if child is Control and child.name == "PlanetMapView":
			embedded_map_view = child as Control
			return embedded_map_view
	return null


func _fit_square_stage() -> void:
	if stage_viewport == null or map_host == null:
		return
	var available := stage_viewport.size
	if available.x <= 1.0 or available.y <= 1.0:
		return
	var max_square := maxf(1.0, minf(available.x, available.y))
	var min_square := minf(220.0, max_square)
	var square_side := max_square
	var map_rect := Rect2(
		Vector2(floor((available.x - square_side) * 0.5), floor((available.y - square_side) * 0.5)),
		Vector2(square_side, square_side)
	)
	map_host.position = map_rect.position
	map_host.size = map_rect.size
	map_host.custom_minimum_size = Vector2(min_square, min_square)
	_layout_flow_compass(map_rect, available)
	_layout_space_rail(left_space_rail, true, map_rect, available)
	_layout_space_rail(right_space_rail, false, map_rect, available)


func _layout_flow_compass(map_rect: Rect2, _available: Vector2) -> void:
	if playtest_flow_compass == null:
		return
	playtest_flow_compass.visible = true
	var compass_width := clampf(map_rect.position.x - SIDE_RAIL_GAP * 2.0, 158.0, 218.0)
	var compass_height := 60.0
	var x := map_rect.position.x - compass_width - SIDE_RAIL_GAP
	if x < 8.0:
		x = map_rect.position.x + 10.0
	var y := map_rect.position.y + 8.0
	playtest_flow_compass.position = Vector2(x, y)
	playtest_flow_compass.size = Vector2(compass_width, compass_height)


func _layout_space_rail(rail: PanelContainer, left_side: bool, map_rect: Rect2, available: Vector2) -> void:
	if rail == null:
		return
	if not left_side:
		rail.set_meta("planet_side_lane_suppressed_for_resolution", right_rail_suppressed)
	if not left_side and right_rail_suppressed:
		rail.visible = false
		return
	var side_space := map_rect.position.x - SIDE_RAIL_GAP if left_side else available.x - map_rect.end.x - SIDE_RAIL_GAP
	if side_space < SIDE_RAIL_MIN_WIDTH or map_rect.size.y < 190.0:
		rail.visible = false
		return
	rail.visible = true
	var rail_width := clampf(side_space, SIDE_RAIL_MIN_WIDTH, SIDE_RAIL_MAX_WIDTH)
	var entry_count := _visible_rail_entry_count(left_side)
	var rail_max_height := minf(SIDE_RAIL_MAX_HEIGHT, map_rect.size.y * 0.56)
	var rail_min_height := minf(154.0, rail_max_height)
	var rail_height := clampf(64.0 + float(entry_count) * 44.0, rail_min_height, rail_max_height)
	var x := map_rect.position.x - SIDE_RAIL_GAP - rail_width if left_side else map_rect.end.x + SIDE_RAIL_GAP
	var lane_ratio := SIDE_RAIL_LEFT_Y_RATIO if left_side else SIDE_RAIL_RIGHT_Y_RATIO
	var y := map_rect.position.y + clampf(
		map_rect.size.y * lane_ratio,
		SIDE_RAIL_GAP,
		maxf(SIDE_RAIL_GAP, map_rect.size.y - rail_height - SIDE_RAIL_GAP)
	)
	if not left_side:
		var left_bottom := map_rect.position.y + map_rect.size.y * SIDE_RAIL_LEFT_Y_RATIO + SIDE_RAIL_MIN_STAGGER_PIXELS
		y = maxf(y, left_bottom)
	rail.position = Vector2(x, y)
	rail.size = Vector2(rail_width, rail_height)
	rail.custom_minimum_size = Vector2(SIDE_RAIL_MIN_WIDTH, 0)
	rail.set_meta("planet_side_lane_skeleton", {
		"side": "left" if left_side else "right",
		"safe_core_ratio": PLANET_TABLE_SAFE_CORE_RATIO,
		"stagger_pixels": SIDE_RAIL_MIN_STAGGER_PIXELS,
	})


func _visible_rail_entry_count(left_side: bool) -> int:
	var stack := left_rail_stack if left_side else right_rail_stack
	if stack == null:
		return 3
	var count := 0
	var prefix := "PlanetLeftRailEntry" if left_side else "PlanetRightRailEntry"
	for child in stack.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return maxi(3, count)


func _style_board() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#38bdf8"), Color("#020617"), 1, 6))
	if left_space_rail != null:
		var left_fill := Color("#020617").lerp(Color("#38bdf8"), 0.05)
		left_fill.a = 0.78
		left_space_rail.add_theme_stylebox_override("panel", _panel_style(Color("#334155"), left_fill, 1, 6))
	if right_space_rail != null:
		var right_fill := Color("#020617").lerp(Color("#f59e0b"), 0.05)
		right_fill.a = 0.78
		right_space_rail.add_theme_stylebox_override("panel", _panel_style(Color("#334155"), right_fill, 1, 6))
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color("#94a3b8"))
	for label in [left_rail_title, right_rail_title]:
		if label != null:
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", Color("#f8fafc"))
	for stack in [left_rail_stack, right_rail_stack]:
		if stack != null:
			stack.add_theme_constant_override("separation", 3)
			var margin := stack.get_parent() as MarginContainer
			if margin != null:
				margin.add_theme_constant_override("margin_left", 6)
				margin.add_theme_constant_override("margin_top", 5)
				margin.add_theme_constant_override("margin_right", 6)
				margin.add_theme_constant_override("margin_bottom", 5)
	for label in [left_rail_fallback, right_rail_fallback]:
		if label != null:
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", Color("#cbd5e1"))
	if playtest_flow_compass != null:
		playtest_flow_compass.add_theme_stylebox_override("panel", _panel_style(Color("#facc15"), Color("#020617").lerp(Color("#facc15"), 0.10), 1, 6))
	if playtest_flow_compass_title != null:
		playtest_flow_compass_title.add_theme_font_size_override("font_size", 10)
		playtest_flow_compass_title.add_theme_color_override("font_color", Color("#fde68a"))
	if playtest_flow_compass_next_label != null:
		playtest_flow_compass_next_label.add_theme_font_size_override("font_size", 9)
		playtest_flow_compass_next_label.add_theme_color_override("font_color", Color("#fde68a"))
		playtest_flow_compass_next_label.clip_text = true


func _left_rail_source(data: Dictionary) -> Dictionary:
	var source := _first_rail_dictionary(data, ["left_rail", "public_intel_rail", "surface_rail"])
	if not source.is_empty():
		return source
	return {
		"title": "轨道情报",
		"entries": _first_rail_entries(data, ["left_entries", "public_intel", "surface_entries"], [
			{"label": "星区", "value": "未扫描", "active": false, "accent": Color("#38bdf8"), "tooltip": "开局后显示公开星区数量。"},
			{"label": "选区", "value": "未选区", "active": false, "accent": Color("#facc15"), "tooltip": "点选中央星球区域后显示当前选区。"},
			{"label": "牌架", "value": "待查看", "active": false, "accent": Color("#c084fc"), "tooltip": "当前选区的公开牌架状态。"},
		]),
	}


func _right_rail_source(data: Dictionary) -> Dictionary:
	var source := _first_rail_dictionary(data, ["right_rail", "outer_pressure_rail", "space_rail"])
	if not source.is_empty():
		return source
	return {
		"title": "外围宇宙",
		"entries": _first_rail_entries(data, ["right_entries", "outer_pressure", "space_entries"], [
			{"label": "怪兽", "value": "0", "active": false, "accent": Color("#fb7185"), "tooltip": "公开怪兽压力。"},
			{"label": "天气", "value": "平稳", "active": false, "accent": Color("#38bdf8"), "tooltip": "公开天气预报与当前天气。"},
			{"label": "牌轨", "value": "空闲", "active": false, "accent": Color("#f59e0b"), "tooltip": "公共牌轨和竞价节奏。"},
		]),
	}


func _first_rail_dictionary(data: Dictionary, keys: Array) -> Dictionary:
	for key in keys:
		if not data.has(key):
			continue
		var value: Variant = data.get(key)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _first_rail_entries(data: Dictionary, keys: Array, fallback: Array) -> Array:
	for key in keys:
		if not data.has(key):
			continue
		var value: Variant = data.get(key)
		if value is Array:
			return value
	return fallback


func _set_space_rail(stack: VBoxContainer, title: Label, fallback: Label, rail_data: Dictionary, left_side: bool) -> void:
	if stack == null:
		return
	var entries: Array = rail_data.get("entries", rail_data.get("items", [])) if rail_data.get("entries", rail_data.get("items", [])) is Array else []
	if entries.is_empty():
		entries = _left_rail_source({}).get("entries", []) if left_side else _right_rail_source({}).get("entries", [])
	var title_text := str(rail_data.get("title", "轨道情报" if left_side else "外围宇宙"))
	var next_signature := var_to_str([title_text, entries])
	if left_side:
		if next_signature == left_rail_signature:
			return
		left_rail_signature = next_signature
	else:
		if next_signature == right_rail_signature:
			return
		right_rail_signature = next_signature
	if title != null:
		title.text = title_text
	if fallback != null:
		fallback.visible = false
	_clear_rail_entries(stack)
	var limit := mini(entries.size(), 4)
	for index in range(limit):
		var entry: Dictionary = entries[index] if entries[index] is Dictionary else {"label": str(entries[index])}
		_add_rail_entry(stack, entry, left_side, index)
	call_deferred("_fit_square_stage")


func _set_weather_strip(data_variant: Variant) -> void:
	var data: Dictionary = data_variant if data_variant is Dictionary else {}
	if weather_forecast_strip != null:
		weather_forecast_strip.tooltip_text = str(data.get("tooltip", "公开天气预报将在开局保护期后出现。"))


func set_weather_presentation(forecast_view_model: Dictionary, overlay_view_model: Dictionary, motion_mode: String) -> void:
	if weather_forecast_strip != null:
		if weather_forecast_strip.has_method("set_view_model"):
			weather_forecast_strip.call("set_view_model", forecast_view_model)
		if weather_forecast_strip.has_method("set_motion_mode"):
			weather_forecast_strip.call("set_motion_mode", motion_mode)
	var map_view := _active_map_view()
	if map_view != null:
		if map_view.has_method("set_weather_overlay_view_model"):
			map_view.call("set_weather_overlay_view_model", overlay_view_model)
		if map_view.has_method("set_weather_overlay_motion_mode"):
			map_view.call("set_weather_overlay_motion_mode", motion_mode)


func _on_weather_region_jump_requested(region_index: int) -> void:
	var map_view := _active_map_view()
	if map_view != null and map_view.has_method("focus_weather_region"):
		map_view.call("focus_weather_region", region_index)


func _active_map_view() -> Control:
	if map_host != null:
		for child in map_host.get_children():
			if child is Control and (child as Control).visible and (child as Control).has_method("set_map"):
				return child as Control
	return get_embedded_map_view()


func _set_flow_compass(data_variant: Variant) -> void:
	var data: Dictionary = data_variant if data_variant is Dictionary else {}
	playtest_flow_compass_title.text = str(data.get("title", "试玩 罗盘"))
	var steps := _flow_compass_entries(data)
	_clear_compass_steps()
	for step_variant in steps:
		if step_variant is Dictionary:
			_add_flow_compass_chip(playtest_flow_compass_step_rail, step_variant as Dictionary, data)
	if playtest_flow_compass_next_label != null:
		playtest_flow_compass_next_label.text = _flow_compass_next_text(data, steps)
		playtest_flow_compass_next_label.tooltip_text = str(data.get("tooltip", "第一局只要顺着这条小轨走到“选路线”。"))


func _flow_compass_entries(data: Dictionary) -> Array:
	var raw_steps: Array = data.get("steps", DEFAULT_FLOW_STEPS) if data.get("steps", []) is Array else DEFAULT_FLOW_STEPS
	var entries: Array = []
	var first_unfinished := -1
	for index in range(raw_steps.size()):
		var entry := _flow_compass_entry(raw_steps[index], index)
		if first_unfinished < 0 and not bool(entry.get("done", false)):
			first_unfinished = index
		entries.append(entry)
	var explicit_current := int(data.get("current_index", -1))
	var has_current := false
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if explicit_current == index:
			entry["current"] = true
		has_current = has_current or bool(entry.get("current", false))
		entries[index] = entry
	if not has_current and first_unfinished >= 0 and first_unfinished < entries.size():
		var current_entry: Dictionary = entries[first_unfinished]
		current_entry["current"] = true
		entries[first_unfinished] = current_entry
	return entries


func _flow_compass_entry(value: Variant, index: int) -> Dictionary:
	var entry: Dictionary = value.duplicate(true) if value is Dictionary else {"label": str(value)}
	var fallback_labels := DEFAULT_FLOW_STEPS
	var label := str(entry.get("label", entry.get("text", fallback_labels[index] if index < fallback_labels.size() else "步骤"))).strip_edges()
	if label == "":
		label = fallback_labels[index] if index < fallback_labels.size() else "步骤"
	entry["label"] = _short_text(label, 4)
	entry["done"] = bool(entry.get("done", entry.get("active", false)))
	entry["current"] = bool(entry.get("current", false)) and not bool(entry.get("done", false))
	entry["accent"] = _entry_color(entry, _flow_step_fallback_accent(index))
	entry["tooltip"] = str(entry.get("tooltip", entry.get("tip", "试玩步骤：%s" % label)))
	return entry


func _add_flow_compass_chip(parent: Container, entry: Dictionary, data: Dictionary) -> void:
	var accent: Color = entry.get("accent", Color("#facc15")) as Color
	var done := bool(entry.get("done", false))
	var current := bool(entry.get("current", false))
	var prefix := "✓" if done else ("▶" if current else "□")
	var fg := Color("#e0f2fe") if done else (accent.lightened(0.20) if current else Color("#94a3b8"))
	var bg := Color("#064e3b") if done else Color("#020617").lerp(accent, 0.28 if current else 0.10)
	var chip := PanelContainer.new()
	chip.name = "PlaytestFlowCompassStepChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.tooltip_text = str(entry.get("tooltip", data.get("tooltip", "试玩步骤")))
	chip.add_theme_stylebox_override("panel", _panel_style(accent if current or done else Color("#334155"), bg, 1, 5))
	parent.add_child(chip)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 1)
	chip.add_child(margin)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%s%s" % [prefix, str(entry.get("label", "步骤"))]
	label.tooltip_text = chip.tooltip_text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", fg)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	margin.add_child(label)


func _flow_compass_next_text(data: Dictionary, steps: Array) -> String:
	var explicit := str(data.get("next_text", data.get("next", ""))).strip_edges()
	if explicit != "":
		return _short_text(explicit, 18)
	for step_variant in steps:
		if not (step_variant is Dictionary):
			continue
		var entry: Dictionary = step_variant
		if bool(entry.get("current", false)) or not bool(entry.get("done", false)):
			return "下一步：%s" % str(entry.get("label", "行动"))
	return "下一步：冲终局"


func _flow_step_fallback_accent(index: int) -> Color:
	match index:
		0:
			return Color("#38bdf8")
		1:
			return Color("#fb7185")
		2:
			return Color("#4ade80")
		3:
			return Color("#facc15")
		4:
			return Color("#c084fc")
		5:
			return Color("#f59e0b")
		6:
			return Color("#38bdf8")
		7:
			return Color("#22c55e")
		_:
			return Color("#94a3b8")


func _clear_compass_steps() -> void:
	for child in playtest_flow_compass_step_rail.get_children():
		playtest_flow_compass_step_rail.remove_child(child)
		child.queue_free()


func _clear_rail_entries(stack: VBoxContainer) -> void:
	for child in stack.get_children():
		if child.name.begins_with("PlanetLeftRailEntry") or child.name.begins_with("PlanetRightRailEntry"):
			stack.remove_child(child)
			child.queue_free()


func _add_rail_entry(stack: VBoxContainer, entry: Dictionary, left_side: bool, index: int) -> void:
	var accent := _entry_color(entry, Color("#38bdf8") if left_side else Color("#f59e0b"))
	var active := bool(entry.get("active", false))
	var panel := PanelContainer.new()
	panel.name = ("PlanetLeftRailEntry%d" if left_side else "PlanetRightRailEntry%d") % index
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(0, 26)
	panel.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	panel.add_theme_stylebox_override("panel", _rail_entry_style(accent, active))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 1)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "PlanetRailEntryRows"
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 0)
	margin.add_child(rows)
	var label := Label.new()
	label.name = "PlanetRailEntryLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _short_text(str(entry.get("label", entry.get("text", "情报"))), 8)
	label.tooltip_text = panel.tooltip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#cbd5e1"))
	rows.add_child(label)
	var value := Label.new()
	value.name = "PlanetRailEntryValue"
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.text = _short_text(_entry_value_text(entry), 12)
	value.tooltip_text = panel.tooltip_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.add_theme_font_size_override("font_size", 10)
	value.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#e2e8f0"))
	rows.add_child(value)
	stack.add_child(panel)


func _entry_value_text(entry: Dictionary) -> String:
	for key in ["value", "state", "summary", "count"]:
		if not entry.has(key):
			continue
		var value := str(entry.get(key, "")).strip_edges()
		if value != "":
			return value
	return str(entry.get("label", entry.get("text", "--")))


func _rail_entry_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.20 if active else 0.08)
	style.border_color = accent if active else Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", entry.get("color", fallback))
	if value is Color:
		return value
	if value is String:
		var text := str(value)
		if text.begins_with("#"):
			return Color(text)
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))


func _draw_stage_space() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("#020617"), true)
	_draw_stage_orbit_lanes(rect)
	for i in range(STAGE_STAR_COUNT):
		var star_position := rect.position + Vector2(
			fposmod(float(i * 113 + 31), maxf(1.0, rect.size.x)),
			fposmod(float(i * 67 + 19), maxf(1.0, rect.size.y))
		)
		var star := Color("#e0f2fe")
		star.a = 0.16 + float((i * 7) % 6) * 0.05
		draw_circle(star_position, 0.7 + float(i % 3) * 0.24, star)


func _draw_stage_orbit_lanes(rect: Rect2) -> void:
	var map_rect := Rect2(rect.get_center() - Vector2.ONE * minf(rect.size.x, rect.size.y) * 0.42, Vector2.ONE * minf(rect.size.x, rect.size.y) * 0.84)
	if map_host != null and is_instance_valid(map_host) and map_host.size.x > 1.0 and map_host.size.y > 1.0:
		map_rect = Rect2(map_host.position, map_host.size)
	var center := map_rect.get_center()
	var base_radius := maxf(map_rect.size.x, map_rect.size.y) * 0.50
	for lane in range(STAGE_ORBIT_LANE_COUNT):
		var orbit := Color("#38bdf8") if lane % 2 == 0 else Color("#f59e0b")
		orbit.a = 0.055 + float(lane) * 0.013
		draw_arc(center, base_radius + 20.0 + float(lane) * 26.0, -0.12 * PI, 1.12 * PI, 120, orbit, 1.0, true)
	var tick_color := Color("#f8fafc")
	for i in range(STAGE_EDGE_TICK_COUNT):
		var side_left := i % 2 == 0
		var ratio := float(i) / maxf(1.0, float(STAGE_EDGE_TICK_COUNT - 1))
		var y := lerpf(map_rect.position.y + 18.0, map_rect.end.y - 18.0, ratio)
		var x := map_rect.position.x - 28.0 if side_left else map_rect.end.x + 28.0
		if x < rect.position.x + 8.0 or x > rect.end.x - 8.0:
			continue
		tick_color.a = 0.12 + float((i * 3) % 5) * 0.035
		var tick_start := Vector2(x - 8.0, y) if side_left else Vector2(x, y)
		var tick_end := Vector2(x, y) if side_left else Vector2(x + 8.0, y)
		draw_line(tick_start, tick_end, tick_color, 1.0, true)
		if i % 4 == 0:
			var beacon := Color("#facc15")
			beacon.a = 0.20
			draw_circle(Vector2(x, y), 2.0, beacon)


func _panel_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
