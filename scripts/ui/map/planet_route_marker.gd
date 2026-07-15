@tool
extends PanelContainer
class_name SpaceSyndicatePlanetRouteMarker

@onready var product_label: Label = %RouteMarkerProductLabel
@onready var status_label: Label = %RouteMarkerStatusLabel
@onready var length_label: Label = %RouteMarkerLengthLabel

var _compact_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("mcp_sceneized_component", "PlanetRouteMarker")


func configure(data: Dictionary) -> void:
	_compact_mode = bool(data.get("compact", false))
	var target_size := Vector2(88, 26) if _compact_mode else Vector2(120, 50)
	custom_minimum_size = target_size
	name = "PlanetRouteMarker_%s" % str(data.get("product", "route"))
	if product_label != null:
		var route_count := int(data.get("route_count", 1))
		product_label.text = "%s ×%d" % [str(data.get("product", "通用商品")), route_count] if _compact_mode and route_count > 1 else str(data.get("product", "通用商品"))
		product_label.add_theme_font_size_override("font_size", 10 if _compact_mode else 12)
	if status_label != null:
		status_label.text = "运输受阻" if bool(data.get("disrupted", false)) else "商路畅通"
		status_label.visible = not _compact_mode
	if length_label != null:
		length_label.text = "路径节点 %d" % int(data.get("point_count", 0))
		length_label.visible = not _compact_mode
	tooltip_text = "%s｜%s｜%d 条路线｜代表路径 %d 个节点；放大查看每条路线标牌。" % [
		str(data.get("product", "通用商品")),
		"运输受阻" if bool(data.get("disrupted", false)) else "商路畅通",
		int(data.get("route_count", 1)),
		int(data.get("point_count", 0)),
	]
	_refresh_style(Color(str(data.get("accent", "#38bdf8"))), bool(data.get("disrupted", false)), _compact_mode)
	update_minimum_size()
	reset_size()
	size = target_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - target_size * 0.5


func debug_snapshot() -> Dictionary:
	return {
		"kind": "route",
		"product": product_label.text if product_label != null else "",
		"compact": _compact_mode,
	}


func _refresh_style(accent: Color, disrupted: bool, compact: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#111827", 0.72 if compact else 0.82)
	style.border_color = Color("#f97316") if disrupted else accent
	style.set_border_width_all(1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 5 if compact else 7
	style.content_margin_right = 5 if compact else 7
	style.content_margin_top = 3 if compact else 5
	style.content_margin_bottom = 3 if compact else 5
	add_theme_stylebox_override("panel", style)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
