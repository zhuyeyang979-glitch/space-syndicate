extends Control
class_name WeatherMapOverlay

const OVERLAY_VIEW_MODEL = preload("res://scripts/viewmodels/weather_map_overlay_view_model.gd")
const MOTION_MODES := ["full", "reduced", "off"]

var _view_model: Dictionary = {}
var _region_layout: Dictionary = {}
var _motion_mode := "off"
var _animation_elapsed := 0.0
var _compact_mode := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_motion_mode("off")


func set_overlay_view_model(view_model: Dictionary) -> bool:
	var validator := OVERLAY_VIEW_MODEL.new()
	if not validator.validate_view_model(view_model):
		_view_model = {}
		visible = false
		queue_redraw()
		return false
	_view_model = view_model.duplicate(true)
	visible = true
	tooltip_text = _public_weather_tooltip()
	queue_redraw()
	return true


func set_compact_mode(compact: bool) -> void:
	_compact_mode = compact
	queue_redraw()


func set_region_layout(normalized_positions: Dictionary) -> bool:
	var next_layout: Dictionary = {}
	for raw_region_index: Variant in normalized_positions.keys():
		if typeof(raw_region_index) != TYPE_INT or int(raw_region_index) < 0:
			return false
		var raw_position: Variant = normalized_positions[raw_region_index]
		if typeof(raw_position) != TYPE_VECTOR2:
			return false
		var position := raw_position as Vector2
		if position.x < 0.0 or position.x > 1.0 or position.y < 0.0 or position.y > 1.0:
			return false
		next_layout[raw_region_index] = position
	_region_layout = next_layout
	queue_redraw()
	return true


func set_motion_mode(mode: String) -> bool:
	if not MOTION_MODES.has(mode):
		_motion_mode = "off"
		set_process(false)
		_animation_elapsed = 0.0
		queue_redraw()
		return false
	_motion_mode = mode
	set_process(mode == "full")
	if mode != "full":
		_animation_elapsed = 0.0
	queue_redraw()
	return true


func get_motion_mode() -> String:
	return _motion_mode


func debug_snapshot() -> Dictionary:
	var region_indices: Array[int] = []
	if _view_model.has("regions"):
		for raw_region: Variant in _view_model["regions"]:
			region_indices.append(int((raw_region as Dictionary)["region_index"]))
	return {
		"visible": visible,
		"state": _view_model.get("state", "invalid"),
		"source_revision": _view_model.get("source_revision", -1),
		"motion_mode": _motion_mode,
		"animated": is_processing(),
		"region_indices": region_indices,
		"layout_count": _region_layout.size(),
		"compact_mode": _compact_mode,
	}


func _process(delta: float) -> void:
	_animation_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _view_model.is_empty():
		return
	var regions := _view_model["regions"] as Array
	for index: int in range(regions.size()):
		var region := regions[index] as Dictionary
		_draw_region_weather(region, _position_for(region["region_index"], index, regions.size()))


func _draw_region_weather(region: Dictionary, center: Vector2) -> void:
	var accent := Color.from_string(region["accent_hex"], Color.WHITE)
	var intensity := float(region["intensity"])
	var stack_offset := Vector2(float(region["stack_index"]) * 18.0, -float(region["stack_index"]) * 12.0)
	center += stack_offset
	var pulse := 0.0
	if _motion_mode == "full":
		pulse = sin(_animation_elapsed * 2.2 + float(region["region_index"])) * 2.5
	var radius := (22.0 + intensity * 5.0 if _compact_mode else 29.0 + intensity * 8.0) + pulse
	var fill_alpha := 0.12 + intensity * 0.18
	if region["phase"] == "queued" or region["phase"] == "forecast":
		fill_alpha = 0.08
	draw_circle(center, radius, Color(accent, fill_alpha))
	draw_arc(center, radius, 0.0, TAU, 42, Color(accent, 0.9), 2.0)
	_draw_pattern(region["pattern_key"], center, radius - 3.0, Color(accent, 0.62))

	var font := ThemeDB.fallback_font
	var icon_text := _icon_text(region["icon_key"])
	var icon_size := 12
	draw_string(font, center + Vector2(-radius, -4.0), icon_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, icon_size, Color(accent, 1.0))
	if _compact_mode:
		draw_string(font, center + Vector2(-38.0, radius + 13.0), _phase_label(region["phase"]), HORIZONTAL_ALIGNMENT_CENTER, 76.0, 10, Color("E7EEF2"))
		return
	var label := "%s · %s" % [region["display_name"], _phase_label(region["phase"])]
	draw_string(font, center + Vector2(-72.0, radius + 17.0), label, HORIZONTAL_ALIGNMENT_CENTER, 144.0, 12, Color("E7EEF2"))
	var remaining := _duration_label(region["remaining_us"])
	draw_string(font, center + Vector2(-54.0, radius + 31.0), remaining, HORIZONTAL_ALIGNMENT_CENTER, 108.0, 11, Color("A9BBC4"))


func _public_weather_tooltip() -> String:
	var lines := PackedStringArray()
	for region_variant in _view_model.get("regions", []):
		if not (region_variant is Dictionary):
			continue
		var region := region_variant as Dictionary
		lines.append("%s｜%s｜剩余 %s" % [
			str(region.get("display_name", "天气事件")),
			_phase_label(str(region.get("phase", ""))),
			_duration_label(int(region.get("remaining_us", 0))),
		])
	return "；".join(lines)


func _draw_pattern(pattern_key: String, center: Vector2, radius: float, color: Color) -> void:
	var phase_offset := fmod(_animation_elapsed * 12.0, 8.0) if _motion_mode == "full" else 0.0
	match pattern_key:
		"concentric":
			for ring_scale: float in [0.34, 0.58, 0.82]:
				draw_arc(center, radius * ring_scale, 0.0, TAU, 32, color, 1.0)
		"dots":
			for angle_index: int in range(10):
				var angle := TAU * float(angle_index) / 10.0
				draw_circle(center + Vector2.from_angle(angle) * radius * 0.58, 1.8, color)
		"facets":
			var points := PackedVector2Array()
			for point_index: int in range(6):
				points.append(center + Vector2.from_angle(TAU * float(point_index) / 6.0) * radius * 0.68)
			points.append(points[0])
			draw_polyline(points, color, 1.2)
			draw_line(points[0], points[3], color, 1.0)
			draw_line(points[1], points[4], color, 1.0)
		"crosshatch":
			for line_index: int in range(-2, 3):
				var offset := float(line_index) * radius * 0.28
				draw_line(center + Vector2(-radius * 0.7, offset), center + Vector2(radius * 0.7, offset), color, 1.0)
				draw_line(center + Vector2(offset, -radius * 0.7), center + Vector2(offset, radius * 0.7), color, 1.0)
		"rays":
			for ray_index: int in range(12):
				var angle := TAU * float(ray_index) / 12.0 + phase_offset * 0.01
				draw_line(center + Vector2.from_angle(angle) * radius * 0.28, center + Vector2.from_angle(angle) * radius * 0.76, color, 1.2)
		_:
			for line_index: int in range(-3, 4):
				var offset := float(line_index) * 8.0 + phase_offset
				draw_line(center + Vector2(-radius * 0.62, offset), center + Vector2(radius * 0.62, offset - radius * 0.7), color, 1.1)


func _position_for(region_index: int, item_index: int, item_count: int) -> Vector2:
	if _region_layout.has(region_index):
		var normalized := _region_layout[region_index] as Vector2
		var center := Vector2(normalized.x * size.x, normalized.y * size.y)
		var horizontal_margin := 42.0 if _compact_mode else 76.0
		var top_margin := 34.0 if _compact_mode else 42.0
		var bottom_margin := 48.0 if _compact_mode else 70.0
		return Vector2(
			clampf(center.x, horizontal_margin, maxf(horizontal_margin, size.x - horizontal_margin)),
			clampf(center.y, top_margin, maxf(top_margin, size.y - bottom_margin))
		)
	var columns := maxi(1, mini(4, item_count))
	var rows := maxi(1, int(ceil(float(item_count) / float(columns))))
	var column := item_index % columns
	var row := int(item_index / columns)
	return Vector2(
		(float(column) + 0.5) * size.x / float(columns),
		(float(row) + 0.45) * size.y / float(rows)
	)


func _phase_label(phase: String) -> String:
	match phase:
		"queued": return "待发布"
		"forecast": return "预报"
		"active": return "生效"
		"fading": return "消退"
	return "未知"


func _icon_text(icon_key: String) -> String:
	match icon_key:
		"ion_bolt": return "ION"
		"gravity_wave": return "G"
		"spore": return "SPORE"
		"crystal": return "CRY"
		"snowflake": return "ICE"
		"solar": return "SOL"
	return "WX"


func _duration_label(remaining_us: int) -> String:
	var total_seconds := int(ceil(float(remaining_us) / 1_000_000.0))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	if minutes > 0:
		return "%d:%02d" % [minutes, seconds]
	return "%d秒" % seconds
