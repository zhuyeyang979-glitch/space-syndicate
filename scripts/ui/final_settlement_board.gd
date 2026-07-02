extends PanelContainer
class_name SpaceSyndicateFinalSettlementBoard

signal action_requested(action_id: String)

@onready var title_label: Label = %FinalSettlementBoardTitle
@onready var chip_rail: HFlowContainer = %FinalSettlementHeaderChipRail
@onready var kpi_grid: GridContainer = %FinalSettlementKpiGrid
@onready var money_title: Label = %FinalSettlementMoneySourceTitle
@onready var money_grid: GridContainer = %FinalSettlementMoneySourcePanel
@onready var event_panel: PanelContainer = %FinalSettlementEventPanel
@onready var event_title: Label = %FinalSettlementEventTitle
@onready var event_line_box: VBoxContainer = %FinalSettlementEventLineBox
@onready var rank_title: Label = %FinalSettlementRankTrackTitle
@onready var rank_grid: GridContainer = %FinalSettlementRankTrack
@onready var action_title: Label = %FinalSettlementAfterActionTitle
@onready var action_grid: GridContainer = %FinalSettlementAfterActionGrid


func _ready() -> void:
	_style_shell()


func set_board(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#facc15"))
	tooltip_text = str(data.get("tooltip", "终局复盘板：先看胜者、钱源、地图和关键影响，再打开详细排名或经济总览。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	title_label.text = str(data.get("title", "终局速览｜赛后记分板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "像桌游电子版的赛后板：先扫最终排名，再决定查经济或再开一桌。"))
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	money_grid.columns = clampi(int(data.get("money_columns", 4)), 1, 4)
	rank_grid.columns = clampi(int(data.get("rank_columns", 4)), 1, 4)
	action_grid.columns = clampi(int(data.get("action_columns", 3)), 1, 3)
	money_title.text = str(data.get("money_title", "胜因拆解｜资金来源"))
	event_title.text = str(data.get("event_title", "公开事件｜牌轨与地图"))
	rank_title.text = str(data.get("rank_title", "排名轨｜结算资金"))
	action_title.text = str(data.get("action_title", "赛后入口｜查原因或再开一桌"))
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_money_sources(data.get("money_sources", []))
	_render_events(data.get("event_lines", []))
	_render_ranks(data.get("ranks", []))
	_render_actions(data.get("actions", []))


func _style_shell() -> void:
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color("#fef3c7"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	money_title.add_theme_font_size_override("font_size", 13)
	money_title.add_theme_color_override("font_color", Color("#bbf7d0"))
	rank_title.add_theme_font_size_override("font_size", 13)
	rank_title.add_theme_color_override("font_color", Color("#dbeafe"))
	action_title.add_theme_font_size_override("font_size", 13)
	action_title.add_theme_color_override("font_color", Color("#fde68a"))
	event_title.add_theme_font_size_override("font_size", 12)
	event_title.add_theme_color_override("font_color", Color("#bfdbfe"))
	event_panel.add_theme_stylebox_override("panel", _card_style(Color("#38bdf8"), Color("#020617").lerp(Color("#38bdf8"), 0.08), 1, 8))


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


func _render_money_sources(entries_variant: Variant) -> void:
	_clear_children(money_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_money_source(entry_variant as Dictionary)


func _render_events(entries_variant: Variant) -> void:
	_clear_children(event_line_box)
	var lines := entries_variant as Array if entries_variant is Array else []
	if lines.is_empty():
		lines = ["本局没有可复盘的公开事件。"]
	for line_variant in lines:
		var label := _label("• %s" % str(line_variant), 9, Color("#cbd5e1"))
		label.name = "FinalSettlementEventLine"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_line_box.add_child(label)


func _render_ranks(entries_variant: Variant) -> void:
	_clear_children(rank_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_rank_card(entry_variant as Dictionary)


func _render_actions(entries_variant: Variant) -> void:
	_clear_children(action_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_action_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var chip := PanelContainer.new()
	chip.name = "FinalSettlementHeaderChip"
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.20), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), 9, accent.lightened(0.16))
	label.name = "FinalSettlementHeaderChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var card := PanelContainer.new()
	card.name = "FinalSettlementKpiCard"
	card.custom_minimum_size = Vector2(0, 118)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", entry.get("meta", "")))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "FinalSettlementKpiTitle"
	box.add_child(title)
	var body := _label(_short_text(str(entry.get("body", "")), 68), 10, Color("#f8fafc"))
	body.name = "FinalSettlementKpiBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = str(entry.get("body", ""))
	box.add_child(body)
	var meta := _label(_short_text(str(entry.get("meta", "")), 52), 8, Color("#94a3b8"))
	meta.name = "FinalSettlementKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = str(entry.get("tooltip", entry.get("meta", "")))
	box.add_child(meta)


func _add_money_source(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var card := PanelContainer.new()
	card.name = "FinalSettlementMoneySourceCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 132)
	card.tooltip_text = str(entry.get("tooltip", "资金来源只使用公开/终局结算数据：基础资金、公开角色加成、现金、存活城市、情报结算和累计收支。"))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.09), 1, 8))
	money_grid.add_child(card)
	var margin := _margin(9, 8, 9, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var header := _label(str(entry.get("title", "")), 11, accent.lightened(0.14))
	header.name = "FinalSettlementMoneySourceCardTitle"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(header)
	var start_line := _label(str(entry.get("start_line", "")), 8, Color("#fde68a"))
	start_line.name = "FinalSettlementStartingCashLine"
	start_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(start_line)
	for line_variant in _entry_lines(entry, ["settlement_line", "income_line", "status_line"]):
		var line := _label(str(line_variant), 8, Color("#cbd5e1"))
		line.name = "FinalSettlementMoneySourceLine"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)


func _add_rank_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var card := PanelContainer.new()
	card.name = "FinalSettlementRankCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 118)
	card.tooltip_text = str(entry.get("tooltip", "终局排名：现金 + 存活城市清算 + 情报现金。"))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	rank_grid.add_child(card)
	var margin := _margin(9, 7, 9, 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.16))
	title.name = "FinalSettlementRankCardTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var score := _label(str(entry.get("score", "")), 18, Color("#f8fafc"))
	score.name = "FinalSettlementRankScore"
	box.add_child(score)
	for line_variant in _entry_lines(entry, ["stats", "income", "identity"]):
		var line := _label(str(line_variant), 8, Color("#cbd5e1"))
		line.name = "FinalSettlementRankPrivacyLine" if str(line_variant).contains("电脑对手") else "FinalSettlementRankLine"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)


func _add_action_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#67e8f9"))
	var button := Button.new()
	button.name = "FinalSettlementAfterActionButton"
	button.text = str(entry.get("title", "行动"))
	button.tooltip_text = str(entry.get("body", ""))
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_stylebox_override("normal", _card_style(accent, Color("#020617").lerp(accent, 0.11), 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.22), 1, 8))
	button.pressed.connect(Callable(self, "_on_action_pressed").bind(str(entry.get("id", ""))))
	action_grid.add_child(button)


func _on_action_pressed(action_id: String) -> void:
	if action_id.strip_edges() == "":
		return
	action_requested.emit(action_id)


func _entry_lines(entry: Dictionary, keys: Array) -> Array:
	var lines := []
	for key_variant in keys:
		var text := str(entry.get(String(key_variant), "")).strip_edges()
		if text != "":
			lines.append(text)
	return lines


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
