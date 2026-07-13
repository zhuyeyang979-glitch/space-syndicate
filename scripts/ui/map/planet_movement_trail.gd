@tool
extends Control
class_name SpaceSyndicatePlanetMovementTrail

var _from_position := Vector2.ZERO
var _to_position := Vector2.ZERO
var _accent := Color("#38bdf8")
var _label := ""
var _style := "movement"
var _life := 1.0
var _duration := 1.0
var _trail_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetMovementTrail")


func configure(data: Dictionary) -> void:
	_from_position = _as_vector2(data.get("from_position", Vector2.ZERO))
	_to_position = _as_vector2(data.get("to_position", Vector2.ZERO))
	_accent = Color(str(data.get("accent", "#38bdf8")))
	_label = str(data.get("label", ""))
	_style = str(data.get("style", "movement"))
	_duration = maxf(0.01, float(data.get("duration", 1.0)))
	_life = clampf(float(data.get("life", _duration)), 0.0, _duration)
	_trail_index = int(data.get("trail_index", -1))
	name = "PlanetMovementTrail_%02d" % max(0, _trail_index)
	set_process(not Engine.is_editor_hint())
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "movement_trail",
		"label": _label,
		"style": _style,
		"trail_index": _trail_index,
	}


func _process(delta: float) -> void:
	if _life <= 0.0:
		visible = false
		set_process(false)
		return
	_life = maxf(0.0, _life - delta)
	queue_redraw()


func _draw() -> void:
	if _from_position.distance_to(_to_position) <= 1.0:
		return
	var alpha := clampf(_life / maxf(0.01, _duration), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var card_ingress := _style == "card_ingress"
	var color := _accent
	color.a = 0.14 + alpha * 0.38 if card_ingress else 0.25 + alpha * 0.65
	var width := 0.9 + alpha * 1.4 if card_ingress else 1.5 + alpha * 2.5
	draw_line(_from_position, _to_position, color, width, true)
	_draw_arrow_head(_from_position, _to_position, color, alpha, 0.58 if card_ingress else 1.0)
	draw_circle(_to_position, (2.5 + alpha * 2.5) if card_ingress else (4.0 + alpha * 4.0), color)
	if _label != "":
		var font := get_theme_default_font()
		var label_color := color
		label_color.a = minf(1.0, color.a + 0.1)
		draw_string(font, _to_position + Vector2(7.0, -7.0), _short_text(_label, 14), HORIZONTAL_ALIGNMENT_LEFT, 96.0, 11, label_color)


func _draw_arrow_head(from_screen: Vector2, to_screen: Vector2, color: Color, alpha: float, size_scale: float) -> void:
	var offset := to_screen - from_screen
	if offset.length() <= 1.0:
		return
	var forward := offset.normalized()
	var normal := Vector2(-forward.y, forward.x)
	var size_px := 9.0 * size_scale
	var head_color := color
	head_color.a = minf(1.0, 0.34 + alpha * 0.55)
	var points := PackedVector2Array([
		to_screen,
		to_screen - forward * size_px + normal * size_px * 0.44,
		to_screen - forward * size_px - normal * size_px * 0.44,
	])
	draw_colored_polygon(points, head_color)


func _short_text(text: String, max_characters: int) -> String:
	if text.length() <= max_characters:
		return text
	return text.left(maxi(1, max_characters - 1)) + "..."


func _as_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	if value is Dictionary:
		var dict := value as Dictionary
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	return Vector2.ZERO
