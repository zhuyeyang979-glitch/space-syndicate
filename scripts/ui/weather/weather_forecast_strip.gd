extends PanelContainer
class_name WeatherForecastStrip

signal region_jump_requested(region_index: int)

const FORECAST_VIEW_MODEL = preload("res://scripts/viewmodels/weather_forecast_view_model.gd")
const MOTION_MODES := ["full", "reduced", "off"]

@onready var _pattern_host: Control = %PatternHost
@onready var _weather_icon: Label = %WeatherIcon
@onready var _weather_title: Label = %WeatherTitle
@onready var _weather_detail: Label = %WeatherDetail
@onready var _phase_badge: Label = %PhaseLabel
@onready var _region_buttons: HFlowContainer = %RegionButtons
@onready var _effect_labels: Array[Label] = [%EffectOne, %EffectTwo, %EffectThree]
@onready var _exploitation_label: Label = %ExploitationLabel
@onready var _counterplay_label: Label = %CounterplayLabel
@onready var _effects_host: Control = get_node("Margin/Content/Effects") as Control
@onready var _hints_host: Control = get_node("Margin/Content/Hints") as Control

var _view_model: Dictionary = {}
var _motion_mode := ""
var _pattern_swatch: WeatherPatternSwatch
var _animation_elapsed := 0.0
var _compact_mode := false
var _render_signature := ""
var _region_signature := ""


class WeatherPatternSwatch:
	extends Control

	var pattern_key := "diagonal"
	var accent := Color("7ED6C4")
	var animation_offset := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		custom_minimum_size = Vector2(38.0, 38.0)

	func configure(next_pattern_key: String, next_accent: Color) -> void:
		if pattern_key == next_pattern_key and accent.is_equal_approx(next_accent):
			return
		pattern_key = next_pattern_key
		accent = next_accent
		queue_redraw()

	func set_animation_offset(next_offset: float) -> void:
		animation_offset = next_offset
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(accent, 0.16), true)
		draw_rect(rect, Color(accent, 0.9), false, 1.5)
		var line_color := Color(accent, 0.72)
		match pattern_key:
			"concentric":
				for radius: float in [6.0, 11.0, 16.0]:
					draw_arc(size * 0.5, radius, 0.0, TAU, 28, line_color, 1.2)
			"dots":
				for x: int in range(6, int(size.x), 9):
					for y: int in range(6, int(size.y), 9):
						draw_circle(Vector2(x, y), 1.7, line_color)
			"facets":
				draw_polyline(PackedVector2Array([Vector2(3, 28), Vector2(13, 6), Vector2(23, 31), Vector2(35, 10)]), line_color, 1.4)
				draw_line(Vector2(3, 28), Vector2(23, 31), line_color, 1.2)
			"crosshatch":
				_draw_diagonal_lines(line_color, 1.0)
				for x: int in range(-24, 48, 9):
					draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), line_color, 1.0)
			"rays":
				for ray: int in range(10):
					var angle := TAU * float(ray) / 10.0 + animation_offset * 0.08
					draw_line(size * 0.5 + Vector2.from_angle(angle) * 5.0, size * 0.5 + Vector2.from_angle(angle) * 17.0, line_color, 1.4)
			_:
				_draw_diagonal_lines(line_color, animation_offset)

	func _draw_diagonal_lines(line_color: Color, offset: float) -> void:
		var shifted := fmod(offset, 10.0)
		for x: int in range(-36, 56, 10):
			draw_line(Vector2(float(x) + shifted, size.y), Vector2(float(x) + size.y + shifted, 0.0), line_color, 1.2)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_pattern_swatch = WeatherPatternSwatch.new()
	_pattern_swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pattern_host.add_child(_pattern_swatch)
	set_motion_mode("off")
	_render_clear_state()


func set_view_model(view_model: Dictionary) -> bool:
	var validator := FORECAST_VIEW_MODEL.new()
	if not validator.validate_view_model(view_model):
		_view_model = {}
		_render_signature = ""
		_region_signature = "__invalid__"
		_clear_children(_region_buttons)
		visible = false
		return false
	_view_model = view_model.duplicate(true)
	visible = true
	var render_signature := _view_model_render_signature(_view_model)
	if render_signature == _render_signature:
		return true
	_render_signature = render_signature
	if (_view_model["events"] as Array).is_empty():
		_render_clear_state()
	else:
		_render_event((_view_model["events"] as Array)[0] as Dictionary)
	return true


func set_compact_mode(compact: bool) -> void:
	if _compact_mode == compact:
		return
	_compact_mode = compact
	custom_minimum_size = Vector2(0.0 if compact else 360.0, 78.0 if compact else 184.0)
	if _effects_host != null:
		_effects_host.visible = not compact
	if _hints_host != null:
		_hints_host.visible = not compact
	if _region_buttons != null:
		_region_buttons.visible = true
	queue_sort()


func set_motion_mode(mode: String) -> bool:
	if not MOTION_MODES.has(mode):
		_motion_mode = "off"
		set_process(false)
		_reset_animation()
		return false
	if _motion_mode == mode:
		return true
	_motion_mode = mode
	set_process(mode == "full")
	if mode != "full":
		_reset_animation()
	return true


func get_motion_mode() -> String:
	return _motion_mode


func debug_snapshot() -> Dictionary:
	var region_indices: Array[int] = []
	for child: Node in _region_buttons.get_children():
		if child is Button:
			region_indices.append(int(child.get_meta("region_index", -1)))
	return {
		"visible": visible,
		"state": _view_model.get("state", "invalid"),
		"source_revision": _view_model.get("source_revision", -1),
		"motion_mode": _motion_mode,
		"compact_mode": _compact_mode,
		"animated": is_processing(),
		"region_indices": region_indices,
		"effect_count": _effect_labels.size() if not _view_model.is_empty() else 0,
		"event_count": (_view_model.get("events", []) as Array).size() if _view_model.get("events", []) is Array else 0,
		"other_event_count": maxi(0, (_view_model.get("events", []) as Array).size() - 1) if _view_model.get("events", []) is Array else 0,
		"displayed_detail": _weather_detail.text,
	}


func _process(delta: float) -> void:
	_animation_elapsed += delta
	_pattern_swatch.set_animation_offset(_animation_elapsed * 14.0)
	_weather_icon.modulate.a = 0.88 + sin(_animation_elapsed * 2.4) * 0.12


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and _region_buttons.get_child_count() > 0:
		var first_button := _region_buttons.get_child(0) as Button
		_emit_region_jump(int(first_button.get_meta("region_index", -1)))
		accept_event()


func _render_clear_state() -> void:
	_weather_icon.text = "OK"
	_weather_title.text = "天气平稳"
	_weather_detail.text = "当前没有区域天气事件"
	_phase_badge.text = "CLEAR"
	_phase_badge.modulate = Color("96B8A8")
	_pattern_swatch.configure("dots", Color("65B99A"))
	_sync_region_buttons([])
	for effect_label: Label in _effect_labels:
		effect_label.text = "公开预报暂无影响"
	_exploitation_label.text = "利用：维持当前计划"
	_counterplay_label.text = "应对：无需额外部署"
	tooltip_text = "天气平稳。当前没有区域天气事件。"
	_set_accessibility_name(self, tooltip_text)


func _render_event(event: Dictionary) -> void:
	var accent := Color.from_string(event["accent_hex"], Color.WHITE)
	_weather_icon.text = _icon_text(event["icon_key"])
	_weather_icon.modulate = accent
	_weather_title.text = event["display_name"]
	var other_count := maxi(0, (_view_model.get("events", []) as Array).size() - 1)
	var event_suffix := " · 另有%d个天气" % other_count if other_count > 0 else ""
	_weather_detail.text = "%s · %s · 强度 %d%%%s" % [
		_source_label(event["source_type"]),
		_duration_label(event["remaining_us"]),
		int(round(float(event["intensity"]) * 100.0)),
		event_suffix,
	]
	_phase_badge.text = _phase_label(event["phase"])
	_phase_badge.modulate = accent
	_pattern_swatch.configure(event["pattern_key"], accent)

	_sync_region_buttons(event["regions"] as Array)

	var effects := event["effects"] as Array
	for index: int in range(_effect_labels.size()):
		var effect := effects[index] as Dictionary
		_effect_labels[index].text = "%s\n%s" % [effect["label"], effect["value_text"]]
	_exploitation_label.text = "利用：%s" % event["exploitation_hint"]
	_counterplay_label.text = "应对：%s" % event["counterplay_hint"]
	tooltip_text = event["accessible_text"]
	_set_accessibility_name(self, tooltip_text)


func _sync_region_buttons(regions: Array) -> void:
	var signature_parts: Array[String] = []
	for raw_region: Variant in regions:
		if raw_region is Dictionary:
			var region := raw_region as Dictionary
			signature_parts.append("%d:%s" % [int(region.get("region_index", -1)), str(region.get("label", ""))])
	var signature := "|".join(signature_parts)
	if signature == _region_signature:
		return
	_region_signature = signature
	_clear_children(_region_buttons)
	for raw_region: Variant in regions:
		if not (raw_region is Dictionary):
			continue
		var region := raw_region as Dictionary
		var button := Button.new()
		button.text = str(region.get("label", "区域"))
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = "定位到%s" % button.text
		button.set_meta("region_index", int(region.get("region_index", -1)))
		button.pressed.connect(_emit_region_jump.bind(int(region.get("region_index", -1))))
		_set_accessibility_name(button, button.tooltip_text)
		_region_buttons.add_child(button)


func _view_model_render_signature(view_model: Dictionary) -> String:
	var canonical := view_model.duplicate(true)
	canonical.erase("world_effective_us")
	var events: Array = canonical.get("events", []) if canonical.get("events", []) is Array else []
	for index in range(events.size()):
		if not (events[index] is Dictionary):
			continue
		var event := (events[index] as Dictionary).duplicate(true)
		var remaining_us := int(event.get("remaining_us", 0))
		event["remaining_us"] = int(ceil(float(remaining_us) / 1_000_000.0))
		events[index] = event
	canonical["events"] = events
	return var_to_str(canonical)


func _emit_region_jump(region_index: int) -> void:
	if region_index >= 0:
		region_jump_requested.emit(region_index)


func _reset_animation() -> void:
	_animation_elapsed = 0.0
	if is_instance_valid(_pattern_swatch):
		_pattern_swatch.set_animation_offset(0.0)
	if is_instance_valid(_weather_icon):
		_weather_icon.modulate.a = 1.0


func _clear_children(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _set_accessibility_name(control: Control, value: String) -> void:
	for property: Dictionary in control.get_property_list():
		if property.get("name", "") == "accessibility_name":
			control.set("accessibility_name", value)
			return


func _phase_label(phase: String) -> String:
	match phase:
		"queued": return "待发布"
		"forecast": return "预报中"
		"active": return "生效中"
		"fading": return "消退中"
	return "未知"


func _source_label(source_type: String) -> String:
	match source_type:
		"natural": return "自然天气"
		"monster": return "怪兽诱发"
		"card": return "卡牌诱发"
	return "未知来源"


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
