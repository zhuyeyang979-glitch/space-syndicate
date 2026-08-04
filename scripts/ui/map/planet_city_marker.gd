@tool
extends PanelContainer
class_name SpaceSyndicatePlanetCityMarker

const COMPACT_SIZE := Vector2(30.0, 30.0)
const DETAIL_SIZE := Vector2(86.0, 46.0)

@onready var tag_label: Label = %CityMarkerTagLabel
@onready var detail_rows: VBoxContainer = %CityMarkerDetailRows
@onready var level_label: Label = %CityMarkerLevelLabel
@onready var product_label: Label = %CityMarkerProductLabel

var _compact := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_meta("mcp_sceneized_component", "PlanetCityMarker")


func configure(data: Dictionary) -> void:
	_compact = bool(data.get("compact", true))
	var marker_size := COMPACT_SIZE if _compact else DETAIL_SIZE
	custom_minimum_size = marker_size
	size = marker_size
	position = _as_vector2(data.get("screen_position", Vector2.ZERO)) - marker_size * 0.5
	name = "PlanetCityMarker_%s" % str(data.get("tag", "city"))
	var tag_text := str(data.get("tag", "C"))
	var level := maxi(1, int(data.get("level", 1)))
	var products := _joined_strings(data.get("products", []))
	if tag_label != null:
		tag_label.text = tag_text.left(2)
	if detail_rows != null:
		detail_rows.visible = not _compact
	if level_label != null:
		level_label.text = "L%d" % level
	if product_label != null:
		product_label.text = _short_text(products, 10)
	tooltip_text = "%s · L%d\n%s" % [tag_text, level, products]
	_refresh_style(Color(str(data.get("accent", "#38bdf8"))), bool(data.get("active", true)))


func debug_snapshot() -> Dictionary:
	return {
		"kind": "city",
		"tag": tag_label.text if tag_label != null else "",
		"compact": _compact,
		"detail_visible": detail_rows.visible if detail_rows != null else false,
	}


func _refresh_style(accent: Color, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#082f49", 0.88) if active else Color("#1e293b", 0.80)
	style.border_color = accent if active else Color("#64748b", 0.72)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	var margin := 3.0 if _compact else 5.0
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
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


func _joined_strings(value: Variant) -> String:
	var result := PackedStringArray()
	if value is Array:
		for item in value:
			result.append(str(item))
	return " / ".join(result)


func _short_text(value: String, max_chars: int) -> String:
	if value.length() <= max_chars:
		return value
	return value.substr(0, maxi(0, max_chars - 3)) + "..."