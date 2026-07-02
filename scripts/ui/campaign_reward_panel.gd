extends PanelContainer
class_name SpaceSyndicateCampaignRewardPanel

signal action_requested(action_id: String)

@onready var title_label: Label = %CampaignRewardTitle
@onready var badge_label: Label = %CampaignRewardBadge
@onready var stats_row: HFlowContainer = %CampaignRewardStatsRow
@onready var unlock_box: VBoxContainer = %CampaignRewardUnlockBox
@onready var primary_button: Button = %CampaignRewardPrimaryButton
@onready var secondary_row: HFlowContainer = %CampaignRewardSecondaryRow

var _primary_action_id := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#22c55e")))
	primary_button.pressed.connect(_emit_primary)


func set_reward(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "关卡完成"))
	badge_label.text = "徽章｜%s" % str(data.get("badge", "完成"))
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
	_render_secondary(data.get("secondary_actions", []))


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
	style.set_corner_radius_all(10)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
