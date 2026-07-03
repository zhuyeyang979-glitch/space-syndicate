extends PanelContainer
class_name SpaceSyndicateCampaignBriefing

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal action_requested(action_id: String)

@onready var title_label: Label = %CampaignBriefingTitle
@onready var subtitle_label: Label = %CampaignBriefingSubtitle
@onready var meta_label: Label = %CampaignBriefingMeta
@onready var quick_card_row: HFlowContainer = %CampaignBriefingQuickCardRow
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
	_render_quick_cards(data.get("quick_cards", []))
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


func _render_quick_cards(value: Variant) -> void:
	_clear_children(quick_card_row)
	var cards: Array = value if value is Array else []
	quick_card_row.visible = not cards.is_empty()
	for card_variant in cards:
		if card_variant is Dictionary:
			_add_quick_card(card_variant as Dictionary)


func _add_quick_card(card: Dictionary) -> void:
	var accent := _quick_card_accent(str(card.get("kind", "")))
	var panel := PanelContainer.new()
	panel.name = "CampaignBriefingQuickCard"
	panel.custom_minimum_size = Vector2(224, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = "%s｜%s" % [str(card.get("title", "")), str(card.get("detail", ""))]
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	quick_card_row.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var kicker := _label(str(card.get("kicker", "摘要")), 10, accent.lightened(0.20))
	kicker.tooltip_text = panel.tooltip_text
	box.add_child(kicker)
	var title := _label(_short_text(str(card.get("title", "")), 18), 13, Color("#f8fafc"))
	title.tooltip_text = panel.tooltip_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var detail := _label(_short_text(str(card.get("detail", "")), 18), 10, Color("#cbd5e1"))
	detail.tooltip_text = panel.tooltip_text
	box.add_child(detail)


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


func _quick_card_accent(kind: String) -> Color:
	match kind:
		"goal":
			return Color("#facc15")
		"action":
			return Color("#38bdf8")
		"reward":
			return Color("#22c55e")
	return Color("#94a3b8")


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


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
