extends PanelContainer
class_name SpaceSyndicateRulesQuickReferenceBoard

@onready var title_label: Label = %RulesQuickReferenceTitle
@onready var chip_rail: HFlowContainer = %RulesQuickReferenceChipRail
@onready var kpi_grid: GridContainer = %RulesQuickReferenceKpiGrid
@onready var keyword_title: Label = %RulesQuickReferenceKeywordTitle
@onready var keyword_rail: HFlowContainer = %RulesQuickReferenceKeywordRail
@onready var module_title: Label = %RulesQuickReferenceModuleTitle
@onready var module_grid: GridContainer = %RulesQuickReferenceModuleGrid
@onready var footer_hint: Label = %RulesQuickReferenceFooterHint


func _ready() -> void:
	_style_shell()


func set_board(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#93c5fd"))
	tooltip_text = str(data.get("tooltip", "规则速查板：先看目标、流程、隐私边界和模块卡，再读正文细则。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "规则速查板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "3分钟层的规则页通道；主桌不常驻长规则，完整解释只放在规则页。"))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	module_grid.columns = clampi(int(data.get("module_columns", 4)), 1, 4)
	keyword_title.text = str(data.get("keyword_title", "卡面符号｜看手牌先认这些"))
	module_title.text = str(data.get("module_title", "牌桌模块｜先扫卡，再读正文"))
	footer_hint.text = str(data.get("footer", "规则正文只放在本页；主桌只保留行动短句。"))
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_keyword_legend(data.get("keyword_legend", []))
	_render_modules(data.get("modules", []))


func _style_shell() -> void:
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#dbeafe"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	keyword_title.add_theme_font_size_override("font_size", 12)
	keyword_title.add_theme_color_override("font_color", Color("#bfdbfe"))
	keyword_rail.add_theme_constant_override("h_separation", 6)
	keyword_rail.add_theme_constant_override("v_separation", 5)
	module_title.add_theme_font_size_override("font_size", 12)
	module_title.add_theme_color_override("font_color", Color("#fde68a"))
	module_grid.add_theme_constant_override("h_separation", 8)
	module_grid.add_theme_constant_override("v_separation", 8)
	footer_hint.add_theme_font_size_override("font_size", 10)
	footer_hint.add_theme_color_override("font_color", Color("#94a3b8"))


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_kpis(entries_variant: Variant) -> void:
	_clear_children(kpi_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_kpi_card(entry_variant as Dictionary)


func _render_keyword_legend(entries_variant: Variant) -> void:
	_clear_children(keyword_rail)
	var entries: Array = entries_variant if entries_variant is Array else []
	keyword_title.visible = not entries.is_empty()
	keyword_rail.visible = not entries.is_empty()
	for entry_variant in entries:
		if entry_variant is Dictionary:
			_add_keyword_chip(entry_variant as Dictionary)


func _render_modules(entries_variant: Variant) -> void:
	_clear_children(module_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_module_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#bfdbfe"))
	var chip := PanelContainer.new()
	chip.name = "RulesQuickReferenceChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 12.0 + 24.0, 54.0, 190.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 9, accent.lightened(0.16))
	label.name = "RulesQuickReferenceChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_keyword_chip(entry: Dictionary) -> void:
	var symbol := str(entry.get("symbol", entry.get("text", ""))).strip_edges()
	var label_text := str(entry.get("label", "")).strip_edges()
	var body_text := str(entry.get("body", entry.get("tooltip", ""))).strip_edges()
	if symbol == "" and label_text == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#bfdbfe"))
	var chip := PanelContainer.new()
	chip.name = "RulesQuickReferenceKeywordChip"
	chip.custom_minimum_size = Vector2(128, 42)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.tooltip_text = body_text
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.13), 1, 8))
	keyword_rail.add_child(chip)
	var margin := _margin(8, 5, 8, 5)
	chip.add_child(margin)
	var row := HBoxContainer.new()
	row.name = "RulesQuickReferenceKeywordRow"
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	var glyph := _label(_short_text(symbol, 4), 14, accent.lightened(0.18))
	glyph.name = "RulesQuickReferenceKeywordSymbol"
	glyph.custom_minimum_size = Vector2(28, 0)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.tooltip_text = body_text
	row.add_child(glyph)
	var text_box := VBoxContainer.new()
	text_box.name = "RulesQuickReferenceKeywordText"
	text_box.add_theme_constant_override("separation", 1)
	row.add_child(text_box)
	var title := _label(_short_text(label_text, 8), 9, Color("#f8fafc"))
	title.name = "RulesQuickReferenceKeywordLabel"
	title.tooltip_text = body_text
	text_box.add_child(title)
	var body := _label(_short_text(body_text, 15), 8, Color("#94a3b8"))
	body.name = "RulesQuickReferenceKeywordBody"
	body.tooltip_text = body_text
	text_box.add_child(body)


func _add_kpi_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var card := PanelContainer.new()
	card.name = "RulesQuickReferenceKpiCard"
	card.custom_minimum_size = Vector2(0, 92)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", entry.get("body", "")))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "RulesQuickReferenceKpiTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body_text := str(entry.get("body", ""))
	var body := _label(_short_text(body_text, 34), 10, Color("#f8fafc"))
	body.name = "RulesQuickReferenceKpiBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	box.add_child(body)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 28), 8, Color("#94a3b8"))
	meta.name = "RulesQuickReferenceKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = str(entry.get("tooltip", meta_text))
	box.add_child(meta)


func _add_module_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var body_text := str(entry.get("body", ""))
	var meta_text := str(entry.get("meta", ""))
	var card := PanelContainer.new()
	card.name = "RulesQuickReferenceModuleCard"
	card.custom_minimum_size = Vector2(0, 112)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = "%s\n%s" % [body_text, meta_text]
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.09), 1, 8))
	module_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.16))
	title.name = "RulesQuickReferenceModuleTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := _label(_short_text(body_text, 34), 9, Color("#f8fafc"))
	body.name = "RulesQuickReferenceModuleBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	box.add_child(body)
	var meta := _label(_short_text(meta_text, 28), 8, Color("#94a3b8"))
	meta.name = "RulesQuickReferenceModuleMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = meta_text
	box.add_child(meta)


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
