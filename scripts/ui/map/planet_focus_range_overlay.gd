@tool
extends Control
class_name SpaceSyndicatePlanetFocusRangeOverlay

var _payload := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetFocusRangeOverlay")


func configure(data: Dictionary) -> void:
	_payload = data.duplicate(true)
	name = "PlanetFocusRangeOverlay"
	visible = true
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "focus_range_overlay",
		"selected_district": int(_payload.get("selected_district", -1)),
		"focus_target_district": int(_payload.get("focus_target_district", -1)),
		"sceneized": true,
	}


func _draw() -> void:
	var selected_visible := bool(_payload.get("selected_visible", false))
	var selected_position := _as_vector2(_payload.get("selected_position", Vector2(-1.0, -1.0)))
	var selected_index := int(_payload.get("selected_district", -1))
	if selected_visible and selected_index >= 0:
		_draw_range_ring(selected_position, 42.0, Color("#facc15", 0.34), "当前选区")
	var focus_active := bool(_payload.get("focus_beacon_active", false))
	var focus_alpha := clampf(float(_payload.get("focus_beacon_alpha", 0.0)), 0.0, 1.0)
	if focus_active and selected_position.x >= 0.0 and selected_position.y >= 0.0:
		_draw_focus_pulse(selected_position, focus_alpha)


func _draw_range_ring(center: Vector2, radius: float, color: Color, label: String) -> void:
	var soft := color
	soft.a *= 0.22
	draw_circle(center, radius, soft)
	draw_arc(center, radius, 0.0, TAU, 48, color, 1.6, true)
	draw_arc(center, radius * 0.62, 0.0, TAU, 40, Color(color.r, color.g, color.b, color.a * 0.58), 0.9, true)
	if label != "":
		var font := get_theme_default_font()
		draw_string(font, center + Vector2(-42.0, -radius - 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 10, Color("#fef3c7", color.a))


func _draw_focus_pulse(center: Vector2, alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5)
	var accent := Color("#facc15")
	accent.a = alpha
	var soft := Color("#facc15")
	soft.a = alpha * 0.18
	draw_circle(center, 20.0 + pulse * 8.0, soft)
	draw_arc(center, 17.0 + pulse * 5.0, 0.0, TAU, 44, accent, 2.2, true)
	draw_arc(center, 7.0, 0.0, TAU, 24, Color("#fef3c7", alpha), 1.2, true)


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2.ZERO
