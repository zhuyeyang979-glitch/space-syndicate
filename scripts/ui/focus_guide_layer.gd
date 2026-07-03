extends Control
class_name SpaceSyndicateFocusGuideLayer

@onready var guide_panel: PanelContainer = %FocusGuidePanel
@onready var guide_chip: PanelContainer = %FocusGuideChip
@onready var guide_label: Label = %FocusGuideLabel

var _last_signature := ""
var _pulse_focus := false
var _pulse_time := 0.0
var _current_accent := Color("#facc15")
var _current_focus_target := ""
var _current_motion_profile := "static"
var _current_fill_alpha := 0.05
var _chip_base_position := Vector2.ZERO
var _chip_base_scale := Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	if guide_panel != null:
		guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide_panel.add_theme_stylebox_override("panel", _focus_guide_panel_style(Color("#facc15"), 0.05))
	if guide_chip != null:
		guide_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide_chip.add_theme_stylebox_override("panel", _focus_guide_chip_style(Color("#facc15")))
	if guide_label != null:
		guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide_label.add_theme_font_size_override("font_size", 11)
		guide_label.add_theme_color_override("font_color", Color("#fef3c7"))


func show_focus(target_global_rect: Rect2, focus_target: String, scenario_data: Dictionary) -> void:
	if guide_panel == null or guide_label == null:
		return
	if target_global_rect.size.x <= 4.0 or target_global_rect.size.y <= 4.0:
		hide_focus()
		return
	var local_rect := _global_rect_to_local(target_global_rect)
	var padding := _focus_guide_padding(focus_target)
	local_rect = local_rect.grow_individual(padding.x, padding.y, padding.z, padding.w)
	local_rect.position.x = clampf(local_rect.position.x, 4.0, maxf(4.0, size.x - local_rect.size.x - 4.0))
	local_rect.position.y = clampf(local_rect.position.y, 4.0, maxf(4.0, size.y - local_rect.size.y - 4.0))
	var label_text := _focus_guide_label_text(focus_target, scenario_data)
	var pulse_focus := _focus_guide_pulse_enabled(scenario_data)
	var motion_profile := _focus_guide_motion_profile(focus_target, scenario_data)
	var signature := var_to_str([focus_target, label_text, local_rect.position.round(), local_rect.size.round(), pulse_focus, motion_profile])
	if signature == _last_signature:
		return
	_last_signature = signature
	visible = true
	guide_panel.visible = true
	if guide_chip != null:
		guide_chip.visible = true
	guide_panel.position = local_rect.position
	guide_panel.size = local_rect.size
	guide_panel.tooltip_text = str(scenario_data.get("detail", scenario_data.get("goal", "")))
	guide_label.text = label_text
	guide_label.tooltip_text = guide_panel.tooltip_text
	var accent := _focus_guide_accent(focus_target)
	_current_accent = accent
	_current_focus_target = focus_target
	_current_motion_profile = motion_profile
	_current_fill_alpha = _focus_guide_fill_alpha(focus_target)
	_pulse_focus = pulse_focus
	_pulse_time = 0.0
	guide_panel.add_theme_stylebox_override("panel", _focus_guide_panel_style(accent, _current_fill_alpha, _pulse_focus))
	if guide_chip != null:
		var chip_size := _focus_guide_chip_size(label_text, local_rect)
		guide_chip.position = _focus_guide_chip_position(local_rect, chip_size)
		guide_chip.size = chip_size
		guide_chip.tooltip_text = guide_panel.tooltip_text
		guide_chip.scale = Vector2.ONE
		guide_chip.rotation = 0.0
		guide_chip.pivot_offset = chip_size * 0.5
		_chip_base_position = guide_chip.position
		_chip_base_scale = guide_chip.scale
		guide_chip.add_theme_stylebox_override("panel", _focus_guide_chip_style(accent, _pulse_focus))
	guide_label.add_theme_color_override("font_color", accent.lightened(0.42))
	set_process(_pulse_focus or _current_motion_profile != "static")


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if not _pulse_focus and _current_motion_profile == "static":
		set_process(false)
		return
	_pulse_time += maxf(0.0, delta)
	var wave := 0.5 + 0.5 * sin(_pulse_time * TAU * 1.45)
	var accent := _current_accent.lightened(0.08 + wave * 0.18) if _pulse_focus else _current_accent
	var fill_alpha := _current_fill_alpha + (wave * 0.055 if _pulse_focus else 0.0)
	if guide_panel != null:
		var panel_style := _focus_guide_panel_style(accent, fill_alpha, _pulse_focus)
		panel_style.shadow_offset = _focus_guide_shadow_motion_offset(_current_motion_profile, _pulse_time, wave)
		guide_panel.add_theme_stylebox_override("panel", panel_style)
	if guide_chip != null:
		_apply_chip_motion(_current_motion_profile, wave)
		guide_chip.add_theme_stylebox_override("panel", _focus_guide_chip_style(accent, _pulse_focus))
	if guide_label != null:
		guide_label.add_theme_color_override("font_color", accent.lightened(0.46))


func hide_focus() -> void:
	_last_signature = ""
	visible = false
	_pulse_focus = false
	_pulse_time = 0.0
	_current_motion_profile = "static"
	set_process(false)
	if guide_panel != null:
		guide_panel.visible = false
	if guide_chip != null:
		guide_chip.visible = false
		guide_chip.scale = Vector2.ONE
		guide_chip.rotation = 0.0
	if guide_label != null:
		guide_label.text = ""


func get_focus_debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"pulse_focus": _pulse_focus,
		"focus_target": _current_focus_target,
		"motion_profile": _current_motion_profile,
		"label": guide_label.text if guide_label != null else "",
	}


func _global_rect_to_local(global_rect: Rect2) -> Rect2:
	var root_rect := get_global_rect()
	return Rect2(global_rect.position - root_rect.position, global_rect.size)


func _focus_guide_padding(focus_target: String) -> Vector4:
	match focus_target:
		"public_track", "top_bar":
			return Vector4(3, 3, 3, 3)
		"player_hand":
			return Vector4(8, 4, 8, 8)
		"bid_board", "action_dock":
			return Vector4(6, 4, 6, 6)
		"planet", "route_layer":
			return Vector4(5, 5, 5, 5)
		_:
			return Vector4(5, 5, 5, 5)


func _focus_guide_label_text(focus_target: String, scenario_data: Dictionary) -> String:
	var phase_label := str(scenario_data.get("phase_label", "")).strip_edges()
	var primary: Dictionary = scenario_data.get("primary_action", {}) if scenario_data.get("primary_action", {}) is Dictionary else {}
	var action_label := str(primary.get("label", "")).strip_edges()
	var target_label := _focus_target_short_label(focus_target)
	var shortest := str(scenario_data.get("shortest_action_text", "")).strip_edges()
	if _focus_guide_pulse_enabled(scenario_data) and shortest != "":
		return _short_focus_guide_text("｜".join(["最短", target_label, shortest]))
	var pieces: Array[String] = ["看这里"]
	if target_label != "":
		pieces.append(target_label)
	if phase_label != "":
		pieces.append(phase_label)
	if action_label != "" and action_label != "定位下一步":
		pieces.append(action_label)
	return _short_focus_guide_text("｜".join(pieces))


func _focus_target_short_label(focus_target: String) -> String:
	match focus_target:
		"planet", "route_layer":
			return "星球"
		"player_hand":
			return "手牌"
		"action_dock":
			return "行动区"
		"bid_board":
			return "竞价"
		"public_track":
			return "牌轨"
		"right_inspector":
			return "右侧详情"
		"district_supply":
			return "牌架"
		"private_decision":
			return "私密选择"
		"contract_prompt":
			return "合约窗口"
		"economy_overview":
			return "经济入口"
		"intel_dossier":
			return "线索入口"
		"standings":
			return "局势入口"
		"settlement":
			return "结算入口"
		"top_bar":
			return "顶部目标"
		"scenario_coach":
			return "目标卡"
		_:
			return "当前区域"


func _short_focus_guide_text(text: String) -> String:
	var value := text.replace("\n", " ").strip_edges()
	if value.length() <= 28:
		return value
	return "%s..." % value.left(25)


func _focus_guide_accent(focus_target: String) -> Color:
	match focus_target:
		"planet", "route_layer":
			return Color("#facc15")
		"player_hand":
			return Color("#fb7185")
		"action_dock", "bid_board":
			return Color("#c084fc")
		"public_track":
			return Color("#93c5fd")
		"right_inspector", "economy_overview", "intel_dossier", "standings", "settlement":
			return Color("#38bdf8")
		"district_supply":
			return Color("#22c55e")
		"private_decision", "contract_prompt":
			return Color("#f97316")
		_:
			return Color("#facc15")


func _focus_guide_fill_alpha(focus_target: String) -> float:
	match focus_target:
		"planet", "route_layer":
			return 0.045
		"player_hand", "public_track":
			return 0.075
		_:
			return 0.09


func _focus_guide_pulse_enabled(scenario_data: Dictionary) -> bool:
	return bool(scenario_data.get("pulse_focus", false)) or str(scenario_data.get("stuck_state", "")).strip_edges() == "strong"


func _focus_guide_motion_profile(focus_target: String, scenario_data: Dictionary) -> String:
	var explicit := str(scenario_data.get("motion_profile", "")).strip_edges()
	if explicit != "":
		return explicit
	match focus_target:
		"planet", "route_layer":
			return "orbit"
		"player_hand":
			return "lift"
		"public_track":
			return "scan"
		"action_dock", "bid_board", "right_inspector", "economy_overview", "intel_dossier", "standings", "settlement":
			return "tap"
		"district_supply", "private_decision", "contract_prompt":
			return "double_tap"
	return "static"


func _focus_guide_shadow_motion_offset(motion_profile: String, elapsed: float, wave: float) -> Vector2:
	match motion_profile:
		"orbit":
			return Vector2(cos(elapsed * TAU * 0.72), sin(elapsed * TAU * 0.72)) * 2.4
		"lift":
			return Vector2(0.0, -2.0 - wave * 2.2)
		"scan":
			return Vector2((wave - 0.5) * 7.0, 0.0)
		"tap", "double_tap":
			return Vector2.ZERO
	return Vector2.ZERO


func _apply_chip_motion(motion_profile: String, wave: float) -> void:
	if guide_chip == null:
		return
	guide_chip.position = _chip_base_position
	guide_chip.scale = _chip_base_scale
	guide_chip.rotation = 0.0
	match motion_profile:
		"orbit":
			var angle := _pulse_time * TAU * 0.72
			guide_chip.position = _chip_base_position + Vector2(cos(angle), sin(angle)) * 3.0
			guide_chip.scale = _chip_base_scale * (1.0 + wave * 0.018)
		"lift":
			guide_chip.position = _chip_base_position + Vector2(0.0, -5.0 * wave)
			guide_chip.scale = _chip_base_scale * (1.0 + wave * 0.025)
		"scan":
			guide_chip.position = _chip_base_position + Vector2((wave - 0.5) * 12.0, 0.0)
		"tap":
			guide_chip.scale = _chip_base_scale * (1.0 + wave * 0.045)
		"double_tap":
			var double_wave := 0.5 + 0.5 * sin(_pulse_time * TAU * 2.90)
			guide_chip.scale = _chip_base_scale * (1.0 + double_wave * 0.055)


func _focus_guide_chip_size(label_text: String, local_rect: Rect2) -> Vector2:
	var width := clampf(118.0 + float(label_text.length()) * 8.2, 154.0, minf(292.0, maxf(160.0, local_rect.size.x)))
	return Vector2(width, 26.0)


func _focus_guide_chip_position(local_rect: Rect2, chip_size: Vector2) -> Vector2:
	var x := clampf(local_rect.position.x, 4.0, maxf(4.0, size.x - chip_size.x - 4.0))
	var y := local_rect.position.y - chip_size.y - 4.0
	if y < 4.0:
		y = local_rect.position.y + 6.0
	return Vector2(x, clampf(y, 4.0, maxf(4.0, size.y - chip_size.y - 4.0)))


func _focus_guide_panel_style(accent: Color, fill_alpha: float, urgent: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill := Color("#020617").lerp(accent, 0.11)
	fill.a = fill_alpha
	style.bg_color = fill
	style.border_color = accent.lightened(0.24)
	style.set_border_width_all(3 if urgent else 2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.40 if urgent else 0.28)
	style.shadow_size = 13 if urgent else 8
	style.shadow_offset = Vector2.ZERO
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


func _focus_guide_chip_style(accent: Color, urgent: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill := Color("#020617").lerp(accent, 0.20)
	fill.a = 0.92
	style.bg_color = fill
	style.border_color = accent.lightened(0.18)
	style.set_border_width_all(2 if urgent else 1)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.30) if urgent else Color(0, 0, 0, 0.30)
	style.shadow_size = 7 if urgent else 4
	style.shadow_offset = Vector2.ZERO
	return style
