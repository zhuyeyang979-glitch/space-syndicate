extends PanelContainer
class_name SpaceSyndicateEconomyDashboard

@onready var header: HBoxContainer = %EconomyDashboardHeader
@onready var title_label: Label = %EconomyDashboardTitle
@onready var chip_rail: HFlowContainer = %EconomyDashboardChipRail
@onready var kpi_grid: GridContainer = %EconomyDashboardKpiGrid
@onready var decision_rail: HFlowContainer = %EconomyDashboardDecisionRail
@onready var lane_grid: GridContainer = %EconomyDashboardLaneGrid


func _ready() -> void:
	_style_shell()


func set_dashboard(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#4ade80"))
	tooltip_text = str(data.get("tooltip", "经济仪表板：看三件事：钱从哪座城来、哪种商品变热、公开线索指向哪里。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "经济仪表板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "先看现金流、商品、城市、线索四块；细节用悬停查看。"))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	lane_grid.columns = clampi(int(data.get("lane_columns", 3)), 1, 3)
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_decisions(data.get("decisions", []))
	_render_lanes(data.get("lanes", []))


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 8)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#dcfce7"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	decision_rail.add_theme_constant_override("h_separation", 10)
	decision_rail.add_theme_constant_override("v_separation", 8)
	lane_grid.add_theme_constant_override("h_separation", 10)
	lane_grid.add_theme_constant_override("v_separation", 10)


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


func _render_decisions(entries_variant: Variant) -> void:
	_clear_children(decision_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_decision(entry_variant as Dictionary)


func _render_lanes(entries_variant: Variant) -> void:
	_clear_children(lane_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_lane(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#86efac"))
	var chip := PanelContainer.new()
	chip.name = "EconomyDashboardChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 7.2 + 18.0, 40.0, 170.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 20), 9, accent.lightened(0.12))
	label.name = "EconomyDashboardChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#4ade80"))
	var card := PanelContainer.new()
	card.name = "EconomyDashboardKpiCard"
	card.custom_minimum_size = Vector2(0, 88)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.11), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "EconomyDashboardKpiTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var value_text := str(entry.get("value", ""))
	var value := _label(_short_text(value_text, 24), 20, Color("#f8fafc"))
	value.name = "EconomyDashboardKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.tooltip_text = value_text
	box.add_child(value)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 32), 9, Color("#94a3b8"))
	meta.name = "EconomyDashboardKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.tooltip_text = str(entry.get("tooltip", meta_text))
	box.add_child(meta)


func _add_decision(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#a78bfa"))
	var card := PanelContainer.new()
	card.name = "EconomyDashboardDecisionCard"
	card.custom_minimum_size = Vector2(220, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", "下一步经济决策：从公开信息选择一条路线。"))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.13), 1, 10))
	decision_rail.add_child(card)
	var margin := _margin(10, 7, 10, 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 12, accent.lightened(0.18))
	title.name = "EconomyDashboardDecisionTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.tooltip_text = card.tooltip_text
	box.add_child(title)
	var body_text := str(entry.get("body", ""))
	var body := _label(_short_text(body_text, 48), 10, Color("#e2e8f0"))
	body.name = "EconomyDashboardDecisionBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.clip_text = true
	body.tooltip_text = body_text
	box.add_child(body)
	var keyword_text := str(entry.get("keyword", ""))
	if keyword_text.strip_edges() != "":
		var keyword := _label(_short_text(keyword_text, 42), 9, Color("#94a3b8"))
		keyword.name = "EconomyDashboardDecisionKeyword"
		keyword.autowrap_mode = TextServer.AUTOWRAP_OFF
		keyword.clip_text = true
		keyword.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		keyword.tooltip_text = keyword_text
		box.add_child(keyword)


func _add_lane(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var card := PanelContainer.new()
	card.name = "EconomyDashboardListCard"
	card.custom_minimum_size = Vector2(0, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	lane_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.18))
	title.name = "EconomyDashboardListTitle"
	title.tooltip_text = card.tooltip_text
	box.add_child(title)
	var lines_variant: Variant = entry.get("lines", [])
	var lines := lines_variant as Array if lines_variant is Array else []
	if lines.is_empty():
		lines = ["暂无可读项"]
	for i in range(mini(4, lines.size())):
		var line := str(lines[i])
		var label := _label("• %s" % _short_text(line, 48), 9, Color("#cbd5e1"))
		label.name = "EconomyDashboardListLine"
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
