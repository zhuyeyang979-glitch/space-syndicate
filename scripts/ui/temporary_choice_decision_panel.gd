extends PanelContainer
class_name SpaceSyndicateTemporaryChoiceDecisionPanel

signal action_requested(action_id: String)

@onready var title_label: Label = %TemporaryChoiceTitleLabel
@onready var mode_label: Label = %TemporaryChoiceModeLabel
@onready var summary_label: Label = %TemporaryChoiceSummaryLabel
@onready var context_label: Label = %TemporaryChoiceContextLabel
@onready var privacy_label: Label = %TemporaryChoicePrivacyLabel
@onready var chip_row: HFlowContainer = %TemporaryChoiceChipRow
@onready var action_grid: GridContainer = %TemporaryChoiceActionGrid


func _ready() -> void:
	visible = false


func set_decision(data: Dictionary) -> void:
	var choice: Dictionary = data.get("choice", {}) if data.get("choice", {}) is Dictionary else {}
	if choice.is_empty() and data.get("details", {}) is Dictionary:
		choice = data.get("details", {}) as Dictionary
	var kind := str(data.get("kind", ""))
	var accent := _entry_color(data, _default_accent(kind))
	name = "TemporaryChoiceDecisionPanel"
	tooltip_text = str(data.get("tooltip", data.get("body", "")))
	add_theme_stylebox_override("panel", _panel_style(accent, Color("#020617").lerp(accent, 0.12), 2, 10))
	title_label.text = _short_text(str(data.get("title", "临时决策")), 24)
	title_label.tooltip_text = tooltip_text
	mode_label.text = _short_text(str(choice.get("mode_label", _kind_label(kind))), 14)
	mode_label.add_theme_color_override("font_color", accent.lightened(0.18))
	summary_label.text = _short_text(str(choice.get("summary", data.get("body", ""))), 104)
	summary_label.tooltip_text = str(choice.get("summary", data.get("body", "")))
	context_label.text = _short_text(_context_text(choice), 88)
	context_label.tooltip_text = _context_text(choice)
	context_label.visible = context_label.text.strip_edges() != ""
	privacy_label.text = _short_text(str(choice.get("privacy", choice.get("public_after", data.get("body", "")))), 104)
	privacy_label.tooltip_text = str(choice.get("privacy", choice.get("public_after", data.get("body", ""))))
	privacy_label.visible = privacy_label.text.strip_edges() != ""
	_set_chip_row(data.get("chips", []))
	_set_action_grid(data.get("actions", []))
	visible = true


func _context_text(choice: Dictionary) -> String:
	var parts: Array[String] = []
	var card := str(choice.get("card", "")).strip_edges()
	if card != "":
		parts.append("卡牌｜%s" % card)
	var context := str(choice.get("context", "")).strip_edges()
	if context != "":
		parts.append(context)
	var public_after := str(choice.get("public_after", "")).strip_edges()
	if public_after != "":
		parts.append("公开线索｜%s" % public_after)
	return "  ".join(parts)


func _set_chip_row(entries_variant: Variant) -> void:
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		var label := Label.new()
		label.name = "TemporaryChoiceDecisionChip"
		label.text = _short_text(str(entry.get("text", entry.get("label", ""))), 14)
		label.tooltip_text = str(entry.get("tooltip", ""))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", _entry_color(entry, Color("#cbd5e1")).lightened(0.12))
		if label.text.strip_edges() != "":
			chip_row.add_child(label)


func _set_action_grid(entries_variant: Variant) -> void:
	for child in action_grid.get_children():
		action_grid.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	action_grid.visible = not entries.is_empty()
	action_grid.columns = clampi(entries.size(), 1, 2)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"id": str(entry_variant), "label": str(entry_variant)}
		var action_id := str(entry.get("id", "")).strip_edges()
		var button := Button.new()
		button.name = "TemporaryChoiceActionButton"
		button.text = _short_text(str(entry.get("label", entry.get("text", "选择"))), 12)
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.disabled = action_id == "" or bool(entry.get("disabled", false))
		button.custom_minimum_size = Vector2(132, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			action_requested.emit(action_id)
		)
		action_grid.add_child(button)


func _kind_label(kind: String) -> String:
	match kind:
		"discard_purchase":
			return "私密换购"
		"monster_target_choice":
			return "怪兽目标"
		"player_target_choice":
			return "玩家目标"
	return "临时决策"


func _default_accent(kind: String) -> Color:
	match kind:
		"discard_purchase":
			return Color("#a78bfa")
		"monster_target_choice":
			return Color("#fb7185")
		"player_target_choice":
			return Color("#60a5fa")
	return Color("#facc15")


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", entry.get("color", fallback))
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if limit <= 0 or text.length() <= limit:
		return text
	return "%s…" % text.substr(0, maxi(1, limit - 1))


func _panel_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
