extends PanelContainer
class_name SpaceSyndicateScenarioCoach

signal action_requested(action_id: String)

@onready var expanded_panel: Control = %ScenarioCoachExpanded
@onready var collapsed_panel: Control = %ScenarioCoachCollapsed
@onready var title_label: Label = %ScenarioCoachTitle
@onready var phase_label: Label = %ScenarioCoachPhase
@onready var progress_label: Label = %ScenarioCoachProgress
@onready var goal_label: Label = %ScenarioCoachGoal
@onready var primary_button: Button = %ScenarioCoachPrimaryButton
@onready var secondary_row: HFlowContainer = %ScenarioCoachSecondaryRow
@onready var collapsed_button: Button = %ScenarioCoachCollapsedButton

var _primary_action_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#22d3ee")))
	primary_button.pressed.connect(_emit_primary)
	collapsed_button.pressed.connect(_emit_action.bind("scenario_reopen_coach"))


func set_coach(data: Dictionary) -> void:
	visible = bool(data.get("visible", true))
	if not visible:
		return
	var collapsed := bool(data.get("collapsed", false))
	expanded_panel.visible = not collapsed
	collapsed_panel.visible = collapsed
	if collapsed:
		collapsed_button.text = "剧本目标｜%s" % str(data.get("progress_text", "完成"))
		return
	title_label.text = str(data.get("title", "试玩剧本"))
	phase_label.text = str(data.get("phase_label", "目标"))
	progress_label.text = str(data.get("progress_text", "1/1"))
	goal_label.text = str(data.get("goal", "完成当前目标。"))
	goal_label.tooltip_text = str(data.get("detail", goal_label.text))
	var font_scale := clampf(float(data.get("font_scale_percent", 100)) / 100.0, 0.85, 1.30)
	title_label.add_theme_font_size_override("font_size", int(round(13.0 * font_scale)))
	phase_label.add_theme_font_size_override("font_size", int(round(12.0 * font_scale)))
	progress_label.add_theme_font_size_override("font_size", int(round(11.0 * font_scale)))
	goal_label.add_theme_font_size_override("font_size", int(round(11.0 * font_scale)))
	var action: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_primary_action_id = str(action.get("id", ""))
	primary_button.text = str(action.get("label", "下一步"))
	primary_button.tooltip_text = str(action.get("tooltip", ""))
	primary_button.disabled = bool(action.get("disabled", false)) or _primary_action_id == ""
	_render_secondary(data.get("secondary_actions", []))


func _render_secondary(value: Variant) -> void:
	for child in secondary_row.get_children():
		secondary_row.remove_child(child)
		child.queue_free()
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var button := Button.new()
		button.text = str(action.get("label", "动作"))
		button.custom_minimum_size = Vector2(58, 24)
		button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
		secondary_row.add_child(button)


func _emit_primary() -> void:
	_emit_action(_primary_action_id)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.10)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_TOP, 6)
	style.set_content_margin(SIDE_RIGHT, 8)
	style.set_content_margin(SIDE_BOTTOM, 6)
	return style
