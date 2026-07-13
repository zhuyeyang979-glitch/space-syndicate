extends PanelContainer
class_name SpaceSyndicateScenarioPauseActionsPanel

signal action_requested(action_id: String)

const ACTION_IDS := [
	"scenario_pause_restart",
	"scenario_pause_choose",
	"scenario_pause_log",
	"scenario_pause_replay",
	"scenario_pause_settings",
]

@onready var mode_label: Label = %ScenarioPauseModeLabel
@onready var title_label: Label = %ScenarioPauseTitleLabel
@onready var detail_label: Label = %ScenarioPauseDetailLabel
@onready var action_row: HFlowContainer = %ScenarioPauseActionRow

var _buttons_by_action_id: Dictionary = {}


func _ready() -> void:
	_buttons_by_action_id = {
		"scenario_pause_restart": %ScenarioPauseRestartButton,
		"scenario_pause_choose": %ScenarioPauseChooseButton,
		"scenario_pause_log": %ScenarioPauseLogButton,
		"scenario_pause_replay": %ScenarioPauseReplayButton,
		"scenario_pause_settings": %ScenarioPauseSettingsButton,
	}
	for action_id_variant: Variant in _buttons_by_action_id:
		var action_id := str(action_id_variant)
		var button := _buttons_by_action_id[action_id] as Button
		button.set_meta("action_id", action_id)
		button.pressed.connect(_emit_action.bind(action_id))
		_style_button(button, _accent_for_action(action_id), action_id == "scenario_pause_restart")
	set_pause_actions({})


func set_pause_actions(data: Dictionary) -> void:
	var in_campaign := bool(data.get("in_campaign", false))
	mode_label.text = str(data.get("mode_label", "战役关卡" if in_campaign else "试玩剧本"))
	title_label.text = str(data.get("title", "新手战役" if in_campaign else "试玩剧本"))
	detail_label.text = str(data.get("detail", "当前关卡可重开、返回选择页、查看日志或复盘。"))
	_apply_action_descriptors(data.get("actions", []))


func debug_snapshot() -> Dictionary:
	var rendered: Array = []
	for action_id_variant: Variant in ACTION_IDS:
		var action_id := str(action_id_variant)
		var button := _buttons_by_action_id.get(action_id) as Button
		if button != null:
			rendered.append({
				"id": action_id,
				"label": button.text,
				"tooltip": button.tooltip_text,
				"disabled": button.disabled,
				"visible": button.visible,
			})
	return {
		"mode_label": mode_label.text,
		"title": title_label.text,
		"detail": detail_label.text,
		"rendered_actions": rendered,
		"action_row_visible": action_row.visible,
	}


func _apply_action_descriptors(entries_variant: Variant) -> void:
	if not (entries_variant is Array):
		return
	for entry_variant: Variant in entries_variant:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var action_id := str(entry.get("id", "")).strip_edges()
		var button := _buttons_by_action_id.get(action_id) as Button
		if button == null:
			continue
		button.text = str(entry.get("label", button.text))
		button.tooltip_text = str(entry.get("tooltip", button.tooltip_text))
		button.disabled = bool(entry.get("disabled", false))
		button.visible = bool(entry.get("visible", true))


func _emit_action(action_id: String) -> void:
	var button := _buttons_by_action_id.get(action_id) as Button
	if button != null and button.visible and not button.disabled:
		action_requested.emit(action_id)


func _accent_for_action(action_id: String) -> Color:
	match action_id:
		"scenario_pause_restart":
			return Color("#facc15")
		"scenario_pause_choose":
			return Color("#38bdf8")
		"scenario_pause_log":
			return Color("#a78bfa")
		"scenario_pause_replay":
			return Color("#f59e0b")
	return Color("#22d3ee")


func _style_button(button: Button, accent: Color, primary: bool) -> void:
	button.custom_minimum_size = Vector2(150, 38)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))
	button.add_theme_stylebox_override("normal", _button_style(accent, Color("#020617").lerp(accent, 0.22 if primary else 0.12), 1))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.3), 1))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.38), 1))
	button.add_theme_stylebox_override("focus", _button_style(Color("#f8fafc"), Color("#020617").lerp(accent, 0.22), 2))


func _button_style(accent: Color, fill: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style
