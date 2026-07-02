extends PanelContainer
class_name SpaceSyndicateCampaignBriefing

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal action_requested(action_id: String)

@onready var title_label: Label = %CampaignBriefingTitle
@onready var subtitle_label: Label = %CampaignBriefingSubtitle
@onready var meta_label: Label = %CampaignBriefingMeta
@onready var briefing_label: Label = %CampaignBriefingText
@onready var objective_box: VBoxContainer = %CampaignBriefingObjectives
@onready var allowed_box: VBoxContainer = %CampaignBriefingAllowed
@onready var teaches_box: VBoxContainer = %CampaignBriefingTeaches
@onready var reward_label: Label = %CampaignBriefingReward
@onready var primary_button: Button = %CampaignBriefingPrimaryButton
@onready var secondary_row: HFlowContainer = %CampaignBriefingSecondaryRow

var _primary_action_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#38bdf8")))
	FOCUS_TOOLS.prepare_button(primary_button)
	primary_button.pressed.connect(_emit_primary)


func set_briefing(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "关卡说明"))
	subtitle_label.text = str(data.get("subtitle", ""))
	meta_label.text = "%s｜%s" % [str(data.get("estimated_time", "约5分钟")), str(data.get("difficulty", "intro"))]
	briefing_label.text = str(data.get("briefing", ""))
	reward_label.text = "奖励｜%s" % str(data.get("reward_text", "完成奖励"))
	_render_list(objective_box, data.get("objectives", []), "目标")
	_render_list(allowed_box, data.get("allowed_actions", []), "允许")
	_render_list(teaches_box, data.get("teaches", []), "学会")
	var primary: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_primary_action_id = str(primary.get("id", ""))
	primary_button.text = str(primary.get("label", "开始"))
	primary_button.disabled = bool(primary.get("disabled", false)) or _primary_action_id == ""
	_render_secondary(data.get("secondary_actions", []))
	call_deferred("_focus_default_action")


func _render_list(parent: VBoxContainer, value: Variant, prefix: String) -> void:
	_clear_children(parent)
	var entries: Array = value if value is Array else []
	for i in range(entries.size()):
		var label := Label.new()
		label.text = "%s %d｜%s" % [prefix, i + 1, str(entries[i])]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#dbeafe"))
		parent.add_child(label)


func _render_secondary(value: Variant) -> void:
	_clear_children(secondary_row)
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			var button := Button.new()
			button.text = str(action.get("label", "动作"))
			FOCUS_TOOLS.prepare_button(button, str(action.get("id", "")), "CampaignBriefingSecondaryButton")
			button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
			secondary_row.add_child(button)


func _focus_default_action() -> void:
	FOCUS_TOOLS.focus_first_enabled(self, primary_button)


func _emit_primary() -> void:
	_emit_action(_primary_action_id)


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.09)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
