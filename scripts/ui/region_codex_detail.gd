extends PanelContainer
class_name SpaceSyndicateRegionCodexDetail

@onready var header: HBoxContainer = %RegionCodexTileHeader
@onready var icon_label: Label = %RegionCodexTileIcon
@onready var title_label: Label = %RegionCodexTileTitle
@onready var subtitle_label: Label = %RegionCodexTileSubtitle
@onready var chip_rail: HFlowContainer = %RegionCodexTileChipRail
@onready var kpi_grid: GridContainer = %RegionCodexTileKpiGrid
@onready var clue_grid: GridContainer = %RegionCodexActionClueGrid


func _ready() -> void:
	_style_shell()


func set_region(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", "区域地块板：像读桌游地图板块一样，先扫HP、城市、供需、商路、牌架和公开线索。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	icon_label.text = str(data.get("icon", "⬡"))
	icon_label.tooltip_text = str(data.get("icon_tooltip", "地块符号：⬡陆地/≈海域/▣城市/✕废墟。"))
	icon_label.add_theme_color_override("font_color", accent.lightened(0.10))
	title_label.text = str(data.get("title", "区域"))
	subtitle_label.text = str(data.get("subtitle", "区域地块板"))
	subtitle_label.add_theme_color_override("font_color", accent.lightened(0.18))
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_clues(data.get("clues", []))


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 10)
	icon_label.custom_minimum_size = Vector2(34, 34)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 12)
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.columns = 4
	kpi_grid.add_theme_constant_override("h_separation", 7)
	kpi_grid.add_theme_constant_override("v_separation", 7)
	clue_grid.columns = 3
	clue_grid.add_theme_constant_override("h_separation", 7)
	clue_grid.add_theme_constant_override("v_separation", 7)


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
			_add_clue(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var fg := _dictionary_color(entry, "fg", accent.lightened(0.18))
	var bg := _dictionary_color(entry, "bg", Color("#020617"))
	var chip_width := clampf(float(text.length()) * 7.2 + 18.0, 34.0, 150.0)
	var chip := PanelContainer.new()
	chip.name = "RegionCodexTileChip"
	chip.custom_minimum_size = Vector2(chip_width, 26)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, bg, 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 11, fg)
	label.name = "RegionCodexTileChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var card := PanelContainer.new()
	card.name = "RegionCodexTileKpiCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 86)
	card.tooltip_text = str(entry.get("tooltip", "%s｜%s｜%s" % [entry.get("title", ""), entry.get("value", ""), entry.get("meta", "")]))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(9, 7, 9, 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	box.add_child(_label(str(entry.get("title", "")), 12, accent.lightened(0.18)))
	var value_text := str(entry.get("value", ""))
	var value := _label(_short_text(value_text, 34), 12, Color("#f8fafc"))
	value.name = "RegionCodexTileKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.tooltip_text = value_text
	box.add_child(value)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 42), 11, Color("#94a3b8"))
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = meta_text
	box.add_child(meta)


func _add_clue(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var card := PanelContainer.new()
	card.name = "RegionCodexClueCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 96)
	card.tooltip_text = str(entry.get("tooltip", entry.get("body", "")))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	clue_grid.add_child(card)
	var margin := _margin(9, 8, 9, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 13, accent.lightened(0.14))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title)
	var body_text := str(entry.get("body", ""))
	var body := _label(_short_text(body_text, 82), 12, Color("#e5e7eb"))
	body.name = "RegionCodexClueBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = card.tooltip_text
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
