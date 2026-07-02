extends PanelContainer
class_name SpaceSyndicateIntelDossierBoard

@onready var header: HBoxContainer = %IntelDossierBoardHeader
@onready var title_label: Label = %IntelDossierBoardTitle
@onready var chip_rail: HFlowContainer = %IntelDossierBoardChipRail
@onready var kpi_grid: GridContainer = %IntelDossierKpiGrid
@onready var clue_grid: GridContainer = %IntelDossierClueGrid


func _ready() -> void:
	_style_shell()


func set_dossier(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#c084fc"))
	tooltip_text = str(data.get("tooltip", "情报侦探板：整理城市嫌疑、匿名牌、怪兽资金和公开城市线索，不扫描对手现金、手牌或真实资产。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "情报侦探板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "先扫线索类别，再决定标注城市、猜卡牌归属或跳到图鉴查证。"))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	clue_grid.columns = clampi(int(data.get("clue_columns", 3)), 1, 3)
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_clues(data.get("clues", []))


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 8)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#ede9fe"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	clue_grid.add_theme_constant_override("h_separation", 10)
	clue_grid.add_theme_constant_override("v_separation", 10)


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
			_add_kpi(entry_variant as Dictionary)


func _render_clues(entries_variant: Variant) -> void:
	_clear_children(clue_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_clue_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#c4b5fd"))
	var chip := PanelContainer.new()
	chip.name = "IntelDossierBoardChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 7.2 + 18.0, 40.0, 180.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 20), 9, accent.lightened(0.12))
	label.name = "IntelDossierBoardChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#c084fc"))
	var card := PanelContainer.new()
	card.name = "IntelDossierKpiCard"
	card.custom_minimum_size = Vector2(0, 86)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "IntelDossierKpiTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var value_text := str(entry.get("value", ""))
	var value := _label(_short_text(value_text, 24), 18, Color("#f8fafc"))
	value.name = "IntelDossierKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.tooltip_text = value_text
	box.add_child(value)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 32), 9, Color("#94a3b8"))
	meta.name = "IntelDossierKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.tooltip_text = str(entry.get("tooltip", meta_text))
	box.add_child(meta)


func _add_clue_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#a78bfa"))
	var card := PanelContainer.new()
	card.name = "IntelDossierClueCard"
	card.custom_minimum_size = Vector2(0, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	clue_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.18))
	title.name = "IntelDossierClueTitle"
	title.tooltip_text = card.tooltip_text
	box.add_child(title)
	var lines_variant: Variant = entry.get("lines", [])
	var lines := lines_variant as Array if lines_variant is Array else []
	if lines.is_empty():
		lines = ["暂无可读线索"]
	var line_limit := clampi(int(entry.get("line_limit", 4)), 1, 6)
	for i in range(mini(line_limit, lines.size())):
		var line := str(lines[i])
		var label := _label("• %s" % _short_text(line, 48), 9, Color("#cbd5e1"))
		label.name = "IntelDossierClueLine"
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.tooltip_text = line
		box.add_child(label)


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
