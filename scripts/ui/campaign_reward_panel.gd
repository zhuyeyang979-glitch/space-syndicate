extends PanelContainer
class_name SpaceSyndicateCampaignRewardPanel

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal action_requested(action_id: String)

@onready var title_label: Label = %CampaignRewardTitle
@onready var badge_label: Label = %CampaignRewardBadge
@onready var summary_card_row: HFlowContainer = %CampaignRewardSummaryCardRow
@onready var stats_row: HFlowContainer = %CampaignRewardStatsRow
@onready var unlock_box: VBoxContainer = %CampaignRewardUnlockBox
@onready var primary_button: Button = %CampaignRewardPrimaryButton
@onready var secondary_row: HFlowContainer = %CampaignRewardSecondaryRow

var _primary_action_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#22c55e")))
	FOCUS_TOOLS.prepare_button(primary_button)
	primary_button.pressed.connect(_emit_primary)


func set_reward(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "关卡完成"))
	badge_label.text = "徽章｜%s" % str(data.get("badge", "完成"))
	_render_summary_cards(data.get("summary_cards", []))
	_render_stats([
		str(data.get("score_text", "")),
		str(data.get("time_text", "")),
		str(data.get("objective_text", "")),
		str(data.get("errors_text", "")),
		str(data.get("hints_text", "")),
	])
	_render_unlocks(data.get("unlocks", []))
	var primary: Dictionary = data.get("primary_action", {}) if data.get("primary_action", {}) is Dictionary else {}
	_primary_action_id = str(primary.get("id", ""))
	primary_button.text = str(primary.get("label", "下一关"))
	primary_button.disabled = bool(primary.get("disabled", false)) or _primary_action_id == ""
	_render_secondary(data.get("secondary_actions", []))
	call_deferred("_focus_default_action")


func _render_stats(entries: Array) -> void:
	_clear_children(stats_row)
	for entry in entries:
		var text := str(entry).strip_edges()
		if text == "":
			continue
		var label := Label.new()
		label.text = text
		label.custom_minimum_size = Vector2(112, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#dcfce7"))
		stats_row.add_child(label)


func _render_summary_cards(value: Variant) -> void:
	_clear_children(summary_card_row)
	var cards: Array = value if value is Array else []
	summary_card_row.visible = not cards.is_empty()
	for card_variant in cards:
		if card_variant is Dictionary:
			_add_summary_card(card_variant as Dictionary)


func _add_summary_card(card: Dictionary) -> void:
	var accent := _summary_card_accent(str(card.get("kind", "")))
	var panel := PanelContainer.new()
	panel.name = "CampaignRewardSummaryCard"
	panel.custom_minimum_size = Vector2(156, 76)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = "%s｜%s" % [str(card.get("title", "")), str(card.get("detail", ""))]
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	summary_card_row.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var kicker := _label(str(card.get("kicker", "结算")), 10, accent.lightened(0.18))
	kicker.tooltip_text = panel.tooltip_text
	box.add_child(kicker)
	var title := _label(_short_text(str(card.get("title", "")), 14), 13, Color("#f8fafc"))
	title.tooltip_text = panel.tooltip_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var detail := _label(_short_text(str(card.get("detail", "")), 14), 10, Color("#d1fae5"))
	detail.tooltip_text = panel.tooltip_text
	box.add_child(detail)


func _render_unlocks(value: Variant) -> void:
	_clear_children(unlock_box)
	var unlocks: Array = value if value is Array else []
	if unlocks.is_empty():
		unlocks.append("继续战役")
	for unlock in unlocks:
		var label := Label.new()
		label.text = "解锁｜%s" % str(unlock)
		label.add_theme_color_override("font_color", Color("#fde68a"))
		unlock_box.add_child(label)


func _render_secondary(value: Variant) -> void:
	_clear_children(secondary_row)
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			var button := Button.new()
			button.text = str(action.get("label", "动作"))
			FOCUS_TOOLS.prepare_button(button, str(action.get("id", "")), "CampaignRewardSecondaryButton")
			button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
			secondary_row.add_child(button)


func _summary_card_accent(kind: String) -> Color:
	match kind:
		"score":
			return Color("#facc15")
		"objective":
			return Color("#38bdf8")
		"unlock":
			return Color("#22c55e")
		"next":
			return Color("#c084fc")
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
	style.bg_color = Color("#020617").lerp(accent, 0.10)
	style.border_color = accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
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
