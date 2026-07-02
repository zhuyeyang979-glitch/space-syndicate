extends PanelContainer
class_name SpaceSyndicateTutorialQuickStartBoard

@onready var title_label: Label = %TutorialQuickStartTitle
@onready var chip_rail: HFlowContainer = %TutorialQuickStartChipRail
@onready var step_grid: GridContainer = %TutorialQuickStartStepGrid
@onready var trap_title: Label = %TutorialQuickStartTrapTitle
@onready var trap_grid: GridContainer = %TutorialQuickStartTrapGrid
@onready var footer_hint: Label = %TutorialQuickStartFooterHint


func _ready() -> void:
	_style_shell()


func set_board(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", "第一局试玩任务板：先做步骤卡，再回到牌桌。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "试玩速成板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "像电子桌游任务板一样，按步骤完成第一局的开场动作。"))
	step_grid.columns = clampi(int(data.get("step_columns", 4)), 1, 4)
	trap_grid.columns = clampi(int(data.get("trap_columns", 3)), 1, 3)
	trap_title.text = str(data.get("trap_title", "卡点急救｜先排这四件事"))
	footer_hint.text = str(data.get("footer", "完整细则进游戏规则；这一页只帮你把第一局跑起来。"))
	_render_chips(data.get("chips", []))
	_render_steps(data.get("steps", []))
	_render_traps(data.get("traps", []))


func _style_shell() -> void:
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#dbeafe"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	step_grid.add_theme_constant_override("h_separation", 8)
	step_grid.add_theme_constant_override("v_separation", 8)
	trap_title.add_theme_font_size_override("font_size", 12)
	trap_title.add_theme_color_override("font_color", Color("#fde68a"))
	trap_grid.add_theme_constant_override("h_separation", 8)
	trap_grid.add_theme_constant_override("v_separation", 8)
	footer_hint.add_theme_font_size_override("font_size", 10)
	footer_hint.add_theme_color_override("font_color", Color("#94a3b8"))


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_steps(entries_variant: Variant) -> void:
	_clear_children(step_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_step_card(entry_variant as Dictionary)


func _render_traps(entries_variant: Variant) -> void:
	_clear_children(trap_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_trap_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#bfdbfe"))
	var chip := PanelContainer.new()
	chip.name = "TutorialQuickStartChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 12.0 + 24.0, 54.0, 180.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 9, accent.lightened(0.16))
	label.name = "TutorialQuickStartChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_step_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var body_text := str(entry.get("body", ""))
	var meta_text := str(entry.get("meta", ""))
	var card := PanelContainer.new()
	card.name = "TutorialQuickStartStepCard"
	card.custom_minimum_size = Vector2(0, 118)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s\n%s" % [body_text, meta_text]
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	step_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.16))
	title.name = "TutorialQuickStartStepTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := _label(_short_text(body_text, 34), 10, Color("#f8fafc"))
	body.name = "TutorialQuickStartStepBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	box.add_child(body)
	var meta := _label(_short_text(meta_text, 28), 9, Color("#94a3b8"))
	meta.name = "TutorialQuickStartStepMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = meta_text
	box.add_child(meta)


func _add_trap_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var body_text := str(entry.get("body", ""))
	var card := PanelContainer.new()
	card.name = "TutorialQuickStartTrapCard"
	card.custom_minimum_size = Vector2(0, 92)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = body_text
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	trap_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.16))
	title.name = "TutorialQuickStartTrapCardTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := _label(_short_text(body_text, 42), 9, Color("#cbd5e1"))
	body.name = "TutorialQuickStartTrapCardBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	box.add_child(body)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	return fallback


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit:
		return value
	return value.substr(0, max(0, limit - 1)) + "…"


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
