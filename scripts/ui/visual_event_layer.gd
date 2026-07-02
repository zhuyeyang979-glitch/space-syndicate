extends Control
class_name VisualEventLayer

const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/visual_event_snapshot.gd")
const MAX_LABELS := 32

@export var reduced_motion := false

var _events: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func set_visual_events(events: Array, reduced_motion_override: bool = false) -> void:
	reduced_motion = reduced_motion_override
	_events = SNAPSHOT_SCRIPT.normalize_events(events)
	for index in range(_events.size()):
		var event: Dictionary = _events[index]
		event["reduced_motion"] = reduced_motion or bool(event.get("reduced_motion", false))
		_events[index] = event
	while _events.size() > MAX_LABELS:
		_events.pop_front()
	_sync_event_labels()
	queue_redraw()


func set_events(events: Array) -> void:
	set_visual_events(events, reduced_motion)


func add_visual_event(event_data: Dictionary) -> void:
	_events.append(SNAPSHOT_SCRIPT.normalize_event(event_data))
	while _events.size() > MAX_LABELS:
		_events.pop_front()
	_sync_event_labels()
	queue_redraw()


func clear_events() -> void:
	_events.clear()
	for child in get_children():
		child.queue_free()
	queue_redraw()


func get_visual_event_snapshot() -> Dictionary:
	return {
		"reduced_motion": reduced_motion,
		"max_events": MAX_LABELS,
		"events": _events.duplicate(true),
		"event_classes": SNAPSHOT_SCRIPT.event_classes(_events),
	}


func _draw() -> void:
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		_draw_visual_event(event)


func _draw_visual_event(event: Dictionary) -> void:
	var event_type := str(event.get("type", "target_arrow"))
	var event_class := str(event.get("event_class", event_type))
	var from_point: Vector2 = event.get("from", Vector2.ZERO)
	var to_point: Vector2 = event.get("to", from_point)
	var at_point: Vector2 = event.get("at", from_point.lerp(to_point, 0.5))
	var progress := clampf(float(event.get("progress", 1.0)), 0.0, 1.0)
	var event_color := _event_color(event_class, bool(event.get("valid", true)))
	if reduced_motion:
		progress = 1.0
	match event_class:
		"card_play":
			var card_point := from_point.lerp(to_point, progress)
			draw_line(from_point, to_point, Color(event_color.r, event_color.g, event_color.b, 0.35), 4.0)
			draw_rect(Rect2(card_point - Vector2(34, 48), Vector2(68, 96)), Color(event_color.r, event_color.g, event_color.b, 0.22), true)
			draw_rect(Rect2(card_point - Vector2(34, 48), Vector2(68, 96)), event_color, false, 3.0)
		"target_arrow":
			_draw_arrow(from_point, to_point, event_color)
		"card_reveal":
			draw_circle(at_point, 44.0, Color(event_color.r, event_color.g, event_color.b, 0.20))
			draw_circle(at_point, 23.0, Color(event_color.r, event_color.g, event_color.b, 0.48))
		"monster_spawn":
			draw_circle(at_point, 58.0, Color(event_color.r, event_color.g, event_color.b, 0.18))
			draw_circle(at_point, 22.0, event_color)
		"monster_move":
			draw_line(from_point, to_point, Color(event_color.r, event_color.g, event_color.b, 0.65), 5.0)
			draw_circle(to_point, 18.0, Color(event_color.r, event_color.g, event_color.b, 0.36))
		"monster_attack":
			draw_line(from_point, to_point, event_color, 7.0)
			draw_circle(to_point, 42.0, Color(event_color.r, event_color.g, event_color.b, 0.22))
		"city_damage":
			draw_rect(Rect2(at_point - Vector2(54, 38), Vector2(108, 76)), Color(event_color.r, event_color.g, event_color.b, 0.18), true)
			draw_rect(Rect2(at_point - Vector2(54, 38), Vector2(108, 76)), event_color, false, 3.0)
			draw_line(at_point + Vector2(-26, -25), at_point + Vector2(-4, 4), event_color, 3.0)
			draw_line(at_point + Vector2(8, -18), at_point + Vector2(24, 22), event_color, 3.0)
		"route_damage":
			draw_line(from_point, to_point, event_color, 3.0)
			for i in range(4):
				var spark := from_point.lerp(to_point, float(i + 1) / 5.0)
				draw_circle(spark, 6.0, event_color)
		"military_fire":
			draw_line(from_point, to_point, event_color, 2.0)
			draw_circle(to_point, 12.0, event_color)
		"cash_gain", "gdp_delta":
			draw_circle(at_point, 18.0, Color(event_color.r, event_color.g, event_color.b, 0.28))
		"final_countdown":
			draw_circle(at_point, 64.0, Color(event_color.r, event_color.g, event_color.b, 0.18))
			draw_circle(at_point, 36.0, Color(event_color.r, event_color.g, event_color.b, 0.32))
		_:
			draw_circle(at_point, 18.0, event_color)


func _draw_arrow(from_point: Vector2, to_point: Vector2, event_color: Color) -> void:
	draw_line(from_point, to_point, event_color, 4.0)
	var direction := (to_point - from_point).normalized()
	if direction.length() <= 0.01:
		direction = Vector2.RIGHT
	var normal := Vector2(-direction.y, direction.x)
	var head_a := to_point - direction * 22.0 + normal * 10.0
	var head_b := to_point - direction * 22.0 - normal * 10.0
	draw_line(to_point, head_a, event_color, 4.0)
	draw_line(to_point, head_b, event_color, 4.0)


func _sync_event_labels() -> void:
	for child in get_children():
		child.queue_free()
	for event_variant in _events:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		var label_text := str(event.get("label", "")).strip_edges()
		if label_text == "":
			continue
		var label := Label.new()
		label.name = "VisualEventLabel_%s" % str(event.get("event_class", "event"))
		label.text = label_text
		label.add_theme_font_size_override("font_size", 14)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.modulate = _event_color(str(event.get("event_class", "")), bool(event.get("valid", true)))
		label.custom_minimum_size = Vector2(150, 26)
		var at_point: Vector2 = event.get("at", event.get("to", Vector2.ZERO))
		label.position = at_point + Vector2(-75, -46)
		add_child(label)


func _event_color(event_class: String, valid: bool) -> Color:
	if not valid or event_class.contains("invalid"):
		return Color("#fb7185")
	match event_class:
		"card_play", "card_reveal", "target_arrow":
			return Color("#facc15")
		"monster_spawn", "monster_move", "monster_attack":
			return Color("#e879f9")
		"city_damage", "route_damage":
			return Color("#fb7185")
		"cash_gain":
			return Color("#34d399")
		"gdp_delta":
			return Color("#38bdf8")
		"military_fire":
			return Color("#93c5fd")
		"final_countdown":
			return Color("#f59e0b")
	return Color("#e2e8f0")
