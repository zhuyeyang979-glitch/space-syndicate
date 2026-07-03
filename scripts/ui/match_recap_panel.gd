extends PanelContainer
class_name SpaceSyndicateMatchRecapPanel

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal action_requested(action_id: String)

@onready var title_label: Label = %MatchRecapTitle
@onready var summary_card_row: HFlowContainer = %MatchRecapSummaryCardRow
@onready var economy_card_row: HFlowContainer = %MatchRecapEconomyCardRow
@onready var learned_box: VBoxContainer = %MatchRecapLearned
@onready var action_box: VBoxContainer = %MatchRecapActions
@onready var suggestion_box: VBoxContainer = %MatchRecapSuggestions
@onready var checkpoint_row: HFlowContainer = %MatchRecapCheckpointRow
@onready var secondary_row: HFlowContainer = %MatchRecapSecondaryRow


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#a78bfa")))


func set_recap(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "本关复盘"))
	_render_summary_cards(data.get("summary_cards", []))
	_render_economy_cards(data.get("economy_cards", []))
	_render_list(learned_box, data.get("learned", []), "学到")
	_render_list(action_box, data.get("key_actions", []), "行动")
	_render_list(suggestion_box, data.get("suggestions", []), "建议")
	_render_actions(checkpoint_row, data.get("checkpoint_actions", []))
	_render_actions(secondary_row, data.get("secondary_actions", []))
	call_deferred("_focus_default_action")


func _render_summary_cards(value: Variant) -> void:
	_clear_children(summary_card_row)
	var entries: Array = value if value is Array else []
	for card_variant in entries:
		if card_variant is Dictionary:
			_add_summary_card(summary_card_row, card_variant as Dictionary)


func _render_economy_cards(value: Variant) -> void:
	_clear_children(economy_card_row)
	var entries: Array = value if value is Array else []
	for card_variant in entries:
		if card_variant is Dictionary:
			_add_economy_card(economy_card_row, card_variant as Dictionary)


func _add_economy_card(parent: HFlowContainer, card: Dictionary) -> void:
	var kind := str(card.get("kind", "economy"))
	var accent := _economy_card_accent(kind)
	var panel := PanelContainer.new()
	panel.name = "MatchRecapEconomyCard"
	panel.custom_minimum_size = Vector2(154, 82)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	_add_label(stack, str(card.get("kicker", "经济")), 9, accent, 1)
	_add_label(stack, str(card.get("title", "看现金流")), 12, Color("#f8fafc"), 2)
	_add_label(stack, str(card.get("detail", "复盘收益与风险。")), 9, Color("#cbd5e1"), 2)


func _add_summary_card(parent: HFlowContainer, card: Dictionary) -> void:
	var kind := str(card.get("kind", "recap"))
	var accent := _summary_card_accent(kind)
	var panel := PanelContainer.new()
	panel.name = "MatchRecapSummaryCard"
	panel.custom_minimum_size = Vector2(168, 104)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	_add_label(stack, str(card.get("kicker", "复盘")), 10, accent, 1)
	_add_label(stack, str(card.get("title", "继续观察牌桌")), 13, Color("#f8fafc"), 2)
	_add_label(stack, str(card.get("detail", "需要时再打开完整日志。")), 10, Color("#cbd5e1"), 2)


func _render_list(parent: VBoxContainer, value: Variant, prefix: String) -> void:
	_clear_children(parent)
	var entries: Array = value if value is Array else []
	if entries.is_empty():
		entries.append("继续观察牌桌")
	for entry in entries:
		var label := Label.new()
		label.text = "%s｜%s" % [prefix, str(entry)]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color("#e9d5ff"))
		parent.add_child(label)


func _render_actions(parent: HFlowContainer, value: Variant) -> void:
	_clear_children(parent)
	var actions: Array = value if value is Array else []
	for action_variant in actions:
		if action_variant is Dictionary:
			var action: Dictionary = action_variant
			var button := Button.new()
			button.text = str(action.get("label", "动作"))
			FOCUS_TOOLS.prepare_button(button, str(action.get("id", "")), "MatchRecapActionButton")
			button.pressed.connect(_emit_action.bind(str(action.get("id", ""))))
			parent.add_child(button)


func _add_label(parent: VBoxContainer, text: String, font_size: int, color: Color, max_lines: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = max_lines
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _focus_default_action() -> void:
	FOCUS_TOOLS.focus_first_enabled(self)


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


func _summary_card_accent(kind: String) -> Color:
	match kind:
		"action":
			return Color("#38bdf8")
		"learned":
			return Color("#a78bfa")
		"next":
			return Color("#facc15")
		"replay":
			return Color("#4ade80")
		_:
			return Color("#cbd5e1")


func _economy_card_accent(kind: String) -> Color:
	match kind:
		"cash":
			return Color("#facc15")
		"gdp":
			return Color("#4ade80")
		"spend":
			return Color("#38bdf8")
		"pressure":
			return Color("#fb7185")
		_:
			return Color("#a78bfa")


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
