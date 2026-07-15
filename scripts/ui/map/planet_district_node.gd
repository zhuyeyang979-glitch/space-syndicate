@tool
extends PanelContainer
class_name SpaceSyndicatePlanetDistrictNode

signal district_pressed(index: int)

@onready var name_label: Label = %DistrictNameLabel
@onready var meta_label: Label = %DistrictMetaLabel
@onready var product_label: Label = %DistrictProductLabel
@onready var state_label: Label = %DistrictStateLabel

var _region_index := -1
var _compact_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	set_meta("mcp_sceneized_component", "PlanetDistrictNode")


func configure(data: Dictionary) -> void:
	_region_index = int(data.get("index", -1))
	var is_selected := bool(data.get("selected", false))
	_compact_mode = bool(data.get("compact", false)) and not is_selected
	var target_size := Vector2(92, 28) if _compact_mode else Vector2(128, 58)
	custom_minimum_size = target_size
	name = "PlanetDistrictNode_%02d" % max(0, _region_index)
	if name_label != null:
		name_label.text = str(data.get("name", "未命名区域"))
		name_label.add_theme_font_size_override("font_size", 11 if _compact_mode else 12)
	if meta_label != null:
		var terrain := _terrain_label(str(data.get("terrain", "地表区")))
		var hp := int(data.get("hp", 0))
		var panic := int(data.get("panic", 0))
		meta_label.text = "%s｜共享生命 %d｜警戒 %d%%" % [terrain, hp, panic]
		meta_label.visible = not _compact_mode
	if product_label != null:
		product_label.text = _joined_strings(data.get("products", []))
		product_label.visible = not _compact_mode
	if state_label != null:
		state_label.text = "当前选区" if is_selected else "区域节点"
		state_label.visible = not _compact_mode
	tooltip_text = "%s｜%s｜共享生命 %d｜警戒 %d%%｜产出 %s" % [
		str(data.get("name", "未命名区域")),
		_terrain_label(str(data.get("terrain", "地表区"))),
		int(data.get("hp", 0)),
		int(data.get("panic", 0)),
		_joined_strings(data.get("products", [])),
	]
	_refresh_style(Color(str(data.get("accent", "#38bdf8"))), is_selected, _compact_mode)
	# Hidden rows stop contributing to the container minimum only after their
	# visibility changes, so apply the compact rect after updating all children.
	update_minimum_size()
	reset_size()
	size = target_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - target_size * 0.5


func _terrain_label(terrain_id: String) -> String:
	return str({
		"land": "陆地",
		"ocean": "海洋",
		"sea": "海洋",
		"coast": "海岸",
		"city": "城区",
	}.get(terrain_id.to_lower(), terrain_id))


func debug_snapshot() -> Dictionary:
	return {
		"index": _region_index,
		"name": name_label.text if name_label != null else "",
		"kind": "district",
		"compact": _compact_mode,
	}


func _refresh_style(accent: Color, is_selected: bool, compact: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a", 0.72 if compact else 0.82)
	style.border_color = accent.lightened(0.2) if is_selected else Color("#334155", 0.88)
	style.set_border_width_all(2 if is_selected else 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6 if compact else 8
	style.content_margin_right = 6 if compact else 8
	style.content_margin_top = 3 if compact else 6
	style.content_margin_bottom = 3 if compact else 6
	add_theme_stylebox_override("panel", style)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			district_pressed.emit(_region_index)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO


func _joined_strings(value: Variant) -> String:
	var result := PackedStringArray()
	if value is Array:
		for item in value:
			result.append(str(item))
	return " / ".join(result)
