extends PanelContainer
class_name SpaceSyndicatePresentationSettingsPanel

signal action_requested(action_id: String)

const CAMPAIGN_ACTION_IDS := [
	"campaign_toggle_teaching_hints",
	"campaign_cycle_animation_intensity",
	"campaign_cycle_font_scale",
	"campaign_toggle_colorblind",
	"campaign_cycle_ui_volume",
	"campaign_cycle_bgm_volume",
	"campaign_reset_progress",
	"campaign_settings_back",
]
const SCENARIO_ACTION_IDS := [
	"scenario_toggle_teaching_hints",
	"scenario_toggle_auto_pause",
	"scenario_cycle_font_scale",
	"scenario_settings_back",
]

@onready var mode_label: Label = %PresentationSettingsModeLabel
@onready var title_label: Label = %PresentationSettingsTitleLabel
@onready var summary_label: Label = %PresentationSettingsSummaryLabel
@onready var campaign_action_grid: HFlowContainer = %CampaignSettingsActionGrid
@onready var scenario_action_grid: HFlowContainer = %ScenarioSettingsActionGrid
@onready var privacy_label: Label = %PresentationSettingsPrivacyLabel

var _mode := "campaign"
var _buttons_by_action_id: Dictionary = {}


func _ready() -> void:
	_buttons_by_action_id = {
		"campaign_toggle_teaching_hints": %CampaignTeachingHintsButton,
		"campaign_cycle_animation_intensity": %CampaignAnimationButton,
		"campaign_cycle_font_scale": %CampaignFontScaleButton,
		"campaign_toggle_colorblind": %CampaignColorblindButton,
		"campaign_cycle_ui_volume": %CampaignUiVolumeButton,
		"campaign_cycle_bgm_volume": %CampaignBgmVolumeButton,
		"campaign_reset_progress": %CampaignResetProgressButton,
		"campaign_settings_back": %CampaignSettingsBackButton,
		"scenario_toggle_teaching_hints": %ScenarioTeachingHintsButton,
		"scenario_toggle_auto_pause": %ScenarioAutoPauseButton,
		"scenario_cycle_font_scale": %ScenarioFontScaleButton,
		"scenario_settings_back": %ScenarioSettingsBackButton,
	}
	for action_id_variant: Variant in _buttons_by_action_id:
		var action_id := str(action_id_variant)
		var button := _buttons_by_action_id[action_id] as Button
		button.set_meta("action_id", action_id)
		button.pressed.connect(_emit_action.bind(action_id))
		_style_button(button, _accent_for_action(action_id), action_id in ["campaign_reset_progress", "campaign_settings_back", "scenario_settings_back"])
	set_settings({})


func set_settings(data: Dictionary) -> void:
	var requested_mode := str(data.get("mode", _mode)).strip_edges().to_lower()
	_mode = requested_mode if requested_mode in ["campaign", "scenario"] else "campaign"
	mode_label.text = str(data.get("mode_label", "战役呈现" if _mode == "campaign" else "剧本辅助"))
	title_label.text = str(data.get("title", "可访问性与教学" if _mode == "campaign" else "试玩剧本辅助"))
	summary_label.text = str(data.get("summary", "在 Inspector 中调整设置快照并检查所有静态操作入口。"))
	privacy_label.text = str(data.get("privacy_text", "设置只改变呈现，不改变牌局规则，也不显示对手私密信息。"))
	campaign_action_grid.visible = _mode == "campaign"
	scenario_action_grid.visible = _mode == "scenario"
	_apply_action_descriptors(data.get("actions", []))


func debug_snapshot() -> Dictionary:
	var rendered: Array = []
	var action_ids: Array = CAMPAIGN_ACTION_IDS if _mode == "campaign" else SCENARIO_ACTION_IDS
	for action_id_variant: Variant in action_ids:
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
		"mode": _mode,
		"title": title_label.text,
		"summary": summary_label.text,
		"privacy_text": privacy_label.text,
		"rendered_actions": rendered,
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
	if action_id.contains("teaching"):
		return Color("#38bdf8")
	if action_id.contains("animation") or action_id.contains("auto_pause"):
		return Color("#facc15")
	if action_id.contains("font"):
		return Color("#a78bfa")
	if action_id.contains("colorblind"):
		return Color("#22d3ee")
	if action_id.contains("volume"):
		return Color("#4ade80")
	if action_id.contains("reset"):
		return Color("#fb7185")
	return Color("#94a3b8")


func _style_button(button: Button, accent: Color, quiet: bool) -> void:
	button.custom_minimum_size = Vector2(176, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))
	button.add_theme_stylebox_override("normal", _button_style(accent, Color("#020617").lerp(accent, 0.08 if quiet else 0.16), 1))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.25), 1))
	button.add_theme_stylebox_override("pressed", _button_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.34), 1))
	button.add_theme_stylebox_override("focus", _button_style(Color("#f8fafc"), Color("#020617").lerp(accent, 0.2), 2))


func _button_style(accent: Color, fill: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style
