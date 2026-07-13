@tool
extends Control
class_name SpaceSyndicatePlanetMapEventEffect

var _kind := "impact"
var _from_position := Vector2.ZERO
var _to_position := Vector2.ZERO
var _position := Vector2.ZERO
var _accent := Color("#fbbf24")
var _label := ""
var _motion_family := ""
var _effect_layer := ""
var _card_style := ""
var _radius_px := 28.0
var _life := 1.0
var _duration := 1.0
var _effect_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("mcp_sceneized_component", "PlanetMapEventEffect")


func configure(data: Dictionary) -> void:
	_kind = str(data.get("kind", "impact"))
	_from_position = _as_vector2(data.get("from_position", Vector2.ZERO))
	_to_position = _as_vector2(data.get("to_position", _from_position))
	_position = _as_vector2(data.get("screen_position", _to_position))
	_accent = Color(str(data.get("accent", "#fbbf24")))
	_label = str(data.get("label", ""))
	_motion_family = str(data.get("motion_family", ""))
	_effect_layer = str(data.get("effect_layer", ""))
	_card_style = str(data.get("card_style", ""))
	_radius_px = maxf(10.0, float(data.get("radius_px", 28.0)))
	_duration = maxf(0.01, float(data.get("duration", 1.0)))
	_life = clampf(float(data.get("life", _duration)), 0.0, _duration)
	_effect_index = int(data.get("effect_index", -1))
	name = "PlanetMapEventEffect_%s_%02d" % [_kind, max(0, _effect_index)]
	set_process(not Engine.is_editor_hint())
	queue_redraw()


func debug_snapshot() -> Dictionary:
	return {
		"kind": "map_event_effect",
		"effect_kind": _kind,
		"label": _label,
		"motion_family": _motion_family,
		"effect_layer": _effect_layer,
	}


func _process(delta: float) -> void:
	if _life <= 0.0:
		visible = false
		set_process(false)
		return
	_life = maxf(0.0, _life - delta)
	queue_redraw()


func _draw() -> void:
	var alpha := clampf(_life / maxf(0.01, _duration), 0.0, 1.0)
	if alpha <= 0.0:
		return
	var progress := 1.0 - alpha
	if _kind == "laser" or _kind == "beam":
		_draw_beam(alpha, progress)
	elif _kind == "melee":
		_draw_melee(alpha, progress)
	else:
		_draw_local(alpha, progress)
	_draw_label(alpha)


func _draw_beam(alpha: float, progress: float) -> void:
	if _from_position.distance_to(_to_position) <= 1.0:
		_draw_local(alpha, progress)
		return
	var glow := _accent
	glow.a = 0.14 + alpha * 0.28
	var core := _accent.lightened(0.28)
	core.a = 0.50 + alpha * 0.42
	var hot := Color("#f8fafc")
	hot.a = 0.40 + alpha * 0.42
	var width := 3.0 + alpha * 4.5
	draw_line(_from_position, _to_position, glow, width + 9.0, true)
	draw_line(_from_position, _to_position, core, width, true)
	draw_line(_from_position, _to_position, hot, maxf(1.2, width * 0.34), true)
	_draw_arrow_head(_from_position, _to_position, core, alpha, 0.9)
	var spark_pos := _from_position.lerp(_to_position, clampf(0.12 + progress * 0.86, 0.0, 1.0))
	draw_circle(spark_pos, 4.0 + alpha * 5.0, hot)
	_draw_burst(_to_position, alpha, progress, 1.0)


func _draw_melee(alpha: float, progress: float) -> void:
	var angle := (_to_position - _from_position).angle()
	var sweep := _accent.lightened(0.10)
	sweep.a = 0.28 + alpha * 0.46
	var sweep_radius := clampf(_radius_px * (0.62 + progress * 0.52), 18.0, 48.0)
	draw_arc(_to_position, sweep_radius, angle - 1.05, angle + 1.05, 28, sweep, 4.0 + alpha * 2.0, true)
	var trace := _accent
	trace.a = 0.16 + alpha * 0.26
	draw_line(_from_position, _to_position, trace, 1.2 + alpha * 1.6, true)
	_draw_burst(_to_position, alpha, progress, 0.82)


func _draw_local(alpha: float, progress: float) -> void:
	var ring := _accent
	ring.a = 0.22 + alpha * 0.48
	var fill := _accent
	fill.a = 0.08 + alpha * 0.18
	draw_circle(_position, _radius_px * (0.30 + progress * 0.18), fill)
	match _kind:
		"repair", "shield":
			draw_arc(_position, _radius_px * (0.64 + progress * 0.32), 0.0, TAU, 40, ring, 2.4, true)
			draw_line(_position + Vector2(-8.0, 0.0), _position + Vector2(8.0, 0.0), Color("#dcfce7", alpha), 2.0, true)
			draw_line(_position + Vector2(0.0, -8.0), _position + Vector2(0.0, 8.0), Color("#dcfce7", alpha), 2.0, true)
		"stomp", "impact":
			draw_arc(_position, _radius_px * (0.72 + progress * 0.95), 0.0, TAU, 46, ring, 3.0 + alpha * 2.0, true)
			for i in range(5):
				var angle := TAU * float(i) / 5.0 + progress * 0.7
				var start := _position + Vector2(cos(angle), sin(angle)) * _radius_px * 0.30
				var end := _position + Vector2(cos(angle), sin(angle)) * _radius_px * (0.72 + progress * 0.35)
				draw_line(start, end, ring, 1.8, true)
		"weather", "storm", "miasma":
			for i in range(3):
				var radius := _radius_px * (0.46 + float(i) * 0.20 + progress * 0.18)
				draw_arc(_position, radius, -0.55 + progress, PI * 1.4 + progress, 34, ring, 1.5 + alpha, true)
		_:
			draw_arc(_position, _radius_px * (0.70 + progress * 0.70), 0.0, TAU, 48, ring, 2.2 + alpha * 1.4, true)
	_draw_card_style(alpha, progress)


func _draw_card_style(alpha: float, progress: float) -> void:
	if _card_style == "":
		return
	var glyph := _accent.lightened(0.22)
	glyph.a = 0.42 + alpha * 0.38
	match _card_style:
		"finance", "contract":
			for i in range(3):
				var x := (float(i) - 1.0) * 6.0
				var h := 8.0 + float(i) * 4.0
				draw_line(_position + Vector2(x, 8.0), _position + Vector2(x, 8.0 - h), glyph, 1.8, true)
			draw_line(_position + Vector2(-14.0, 9.0), _position + Vector2(14.0, 9.0), glyph, 1.4, true)
		"route", "movement":
			for i in range(2):
				var y := (float(i) - 0.5) * 7.0
				draw_line(_position + Vector2(-14.0, y), _position + Vector2(10.0, y), glyph, 1.7, true)
				_draw_arrow_head(_position + Vector2(2.0, y), _position + Vector2(14.0, y), glyph, alpha, 0.46)
		_:
			draw_arc(_position, _radius_px * (0.30 + progress * 0.10), 0.0, TAU, 32, glyph, 1.6, true)


func _draw_burst(pos: Vector2, alpha: float, progress: float, strength: float) -> void:
	var burst := _accent
	burst.a = 0.22 + alpha * 0.42
	var radius := _radius_px * strength * (0.42 + progress * 0.70)
	draw_arc(pos, radius, 0.0, TAU, 32, burst, 2.0 + alpha * 2.0, true)
	for i in range(6):
		var angle := TAU * float(i) / 6.0 + progress * 0.8
		var inner := pos + Vector2(cos(angle), sin(angle)) * radius * 0.52
		var outer := pos + Vector2(cos(angle), sin(angle)) * radius
		draw_line(inner, outer, burst, 1.4 + alpha, true)


func _draw_label(alpha: float) -> void:
	if _label == "":
		return
	var font := get_theme_default_font()
	var label_color := _accent.lightened(0.12)
	label_color.a = clampf(0.28 + alpha * 0.66, 0.0, 1.0)
	draw_string(font, _position + Vector2(9.0, -20.0), _short_text(_label, 12), HORIZONTAL_ALIGNMENT_LEFT, 96.0, 11, label_color)


func _draw_arrow_head(from_screen: Vector2, to_screen: Vector2, color: Color, alpha: float, size_scale: float) -> void:
	var offset := to_screen - from_screen
	if offset.length() <= 1.0:
		return
	var forward := offset.normalized()
	var normal := Vector2(-forward.y, forward.x)
	var size_px := 10.0 * size_scale
	var head_color := color
	head_color.a = minf(1.0, 0.34 + alpha * 0.55)
	draw_colored_polygon(PackedVector2Array([
		to_screen,
		to_screen - forward * size_px + normal * size_px * 0.44,
		to_screen - forward * size_px - normal * size_px * 0.44,
	]), head_color)


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
