extends PanelContainer
class_name SpaceSyndicateScenarioCoach

signal action_requested(action_id: String)

@onready var expanded_panel: Control = %ScenarioCoachExpanded
@onready var collapsed_panel: Control = %ScenarioCoachCollapsed
@onready var title_label: Label = %ScenarioCoachTitle
@onready var phase_label: Label = %ScenarioCoachPhase
@onready var progress_label: Label = %ScenarioCoachProgress
@onready var goal_label: Label = %ScenarioCoachGoal
@onready var help_label: Label = %ScenarioCoachHelp
@onready var primary_button: Button = %ScenarioCoachPrimaryButton
@onready var secondary_row: HFlowContainer = %ScenarioCoachSecondaryRow
@onready var collapsed_button: Button = %ScenarioCoachCollapsedButton

var _primary_action_id := ""
var _secondary_action_ids: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#22d3ee")))
	primary_button.pressed.connect(_emit_primary)
	collapsed_button.pressed.connect(_emit_action.bind("scenario_reopen_coach"))


func set_coach(data: Dictionary) -> void:
	visible = bool(data.get("visible", true))
	if not visible:
		return
	var compact := bool(data.get("campaign_focus_mode", data.get("compact", false)))
	custom_minimum_size = Vector2(220, 0) if compact else Vector2.ZERO
	var collapsed := bool(data.get("collapsed", false))
	expanded_panel.visible = not collapsed
	collapsed_panel.visible = collapsed
	if collapsed:
		collapsed_button.text = "剧本目标｜%s" % str(data.get("progress_text", "完成"))
		return
	title_label.text = _short_text(str(data.get("title", "试玩剧本")), 18 if compact else 32)
	phase_label.visible = not compact
	phase_label.text = str(data.get("phase_label", "目标"))
	progress_label.text = str(data.get("progress_text", "1/1"))
	goal_label.text = _short_text(str(data.get("goal", "完成当前目标。")), 16 if compact else 34)
	goal_label.tooltip_text = str(data.get("detail", goal_label.text))
	help_label.visible = bool(data.get("help_visible", false)) and not compact
	help_label.text = "卡住了吗？%s" % str(data.get("help_text", "看高亮区域，完成当前目标。"))
	help_label.tooltip_text = str(data.get("help_text", ""))
	var font_scale := clampf(float(data.get("font_scale_percent", 100)) / 100.0, 0.85, 1.30)
	title_label.add_theme_font_size_override("font_size", int(round(13.0 * font_scale)))
	phase_label.add_theme_font_size_override("font_size", int(round(12.0 * font_scale)))
	progress_label.add_theme_font_size_override("font_size", int(round(11.0 * font_scale)))
	goal_label.add_theme_font_size_override("font_size", int(round(11.0 * font_scale)))
	help_label.add_theme_font_size_override("font_size", int(round(11.0 * font_scale)))
	var action: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_primary_action_id = str(action.get("id", ""))
	primary_button.text = str(action.get("label", "下一步"))
	primary_button.tooltip_text = str(action.get("tooltip", ""))
	primary_button.disabled = bool(action.get("disabled", false)) or _primary_action_id == ""
	primary_button.custom_minimum_size = Vector2(74, 26) if compact else Vector2(88, 28)
	_render_secondary([] if compact else data.get("secondary_actions", []))


func _render_secondary(value: Variant) -> void:
	for child in secondary_row.get_children():
		secondary_row.remove_child(child)
		child.queue_free()
	_secondary_action_ids.clear()
	var actions: Array = value if value is Array else []
	secondary_row.visible = not actions.is_empty()
	if actions.is_empty():
		return
	var utility_menu := MenuButton.new()
	utility_menu.name = "ScenarioCoachUtilityMenu"
	utility_menu.text = "工具"
	utility_menu.tooltip_text = "收起、提示、定位和重开等辅助操作。主要行动仍在上方按钮。"
	utility_menu.custom_minimum_size = Vector2(56, 22)
	utility_menu.add_theme_font_size_override("font_size", 10)
	utility_menu.add_theme_stylebox_override("normal", _utility_button_style(false))
	utility_menu.add_theme_stylebox_override("hover", _utility_button_style(true))
	utility_menu.add_theme_stylebox_override("pressed", _utility_button_style(true))
	var popup := utility_menu.get_popup()
	popup.clear()
	var menu_id := 0
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id == "":
			continue
		popup.add_item(str(action.get("label", "动作")), menu_id)
		_secondary_action_ids[menu_id] = action_id
		menu_id += 1
	if _secondary_action_ids.is_empty():
		utility_menu.queue_free()
		secondary_row.visible = false
		return
	popup.id_pressed.connect(_on_secondary_menu_id_pressed)
	secondary_row.add_child(utility_menu)


func _on_secondary_menu_id_pressed(menu_id: int) -> void:
	_emit_action(str(_secondary_action_ids.get(menu_id, "")))


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


func _utility_button_style(hovered: bool) -> StyleBoxFlat:
	var accent := Color("#22d3ee")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.18 if hovered else 0.08)
	style.border_color = Color("#334155").lerp(accent, 0.34 if hovered else 0.20)
	style.set_border_width_all(1)
	style.set_corner_radius_all(999)
	style.set_content_margin(SIDE_LEFT, 8)
	style.set_content_margin(SIDE_TOP, 2)
	style.set_content_margin(SIDE_RIGHT, 8)
	style.set_content_margin(SIDE_BOTTOM, 2)
	return style


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))
