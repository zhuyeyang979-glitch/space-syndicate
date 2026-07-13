extends PanelContainer
class_name SpaceSyndicateStandingsScoreboard

const BANKRUPT_BADGE_NODE_NAME := "StandingsBankruptBadge"

@onready var header: HBoxContainer = %StandingsScoreboardHeader
@onready var title_label: Label = %StandingsScoreboardTitle
@onready var chip_rail: HFlowContainer = %StandingsScoreboardChipRail
@onready var overview_grid: GridContainer = %StandingsOverviewGrid
@onready var kpi_grid: GridContainer = %StandingsRaceKpiGrid
@onready var score_grid: GridContainer = %StandingsPlayerScoreGrid
@onready var hint_label: Label = %StandingsScoreboardReadHint


func _ready() -> void:
	_style_shell()


func set_scoreboard(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#facc15"))
	tooltip_text = str(data.get("tooltip", "桌游式局势记分板：先看目标、倒计时、自己的可见估值和对手隐私牌。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "局势记分板"))
	title_label.tooltip_text = str(data.get("title_tooltip", "进行中只显示当前玩家可见资金；对手现金、手牌和真实资产仍靠推理。"))
	overview_grid.columns = clampi(int(data.get("overview_columns", 3)), 1, 3)
	kpi_grid.columns = clampi(int(data.get("kpi_columns", 4)), 1, 4)
	score_grid.columns = clampi(int(data.get("seat_columns", 4)), 1, 4)
	hint_label.text = str(data.get("hint", "读法：自己的牌看精确钱；对手牌看公开线索。想知道钱从哪里来，继续看经济总览和情报档案。"))
	_render_chips(data.get("chips", []))
	_render_overview_cards(data.get("overview_cards", []))
	_render_kpis(data.get("kpis", []))
	_render_seats(data.get("seats", []))


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 8)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#fef3c7"))
	chip_rail.add_theme_constant_override("h_separation", 5)
	chip_rail.add_theme_constant_override("v_separation", 3)
	overview_grid.add_theme_constant_override("h_separation", 8)
	overview_grid.add_theme_constant_override("v_separation", 8)
	kpi_grid.add_theme_constant_override("h_separation", 8)
	kpi_grid.add_theme_constant_override("v_separation", 8)
	score_grid.add_theme_constant_override("h_separation", 8)
	score_grid.add_theme_constant_override("v_separation", 8)
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color("#fde68a"))


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_overview_cards(entries_variant: Variant) -> void:
	_clear_children(overview_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_overview_card(entry_variant as Dictionary)


func _render_kpis(entries_variant: Variant) -> void:
	_clear_children(kpi_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_kpi(entry_variant as Dictionary)


func _add_overview_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var card := PanelContainer.new()
	card.name = "StandingsOverviewCard"
	card.custom_minimum_size = Vector2(0, 74)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	overview_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var title := _label(str(entry.get("title", "")), 10, accent.lightened(0.16))
	title.name = "StandingsOverviewTitle"
	box.add_child(title)
	var body := _label(str(entry.get("body", "")), 10, Color("#e2e8f0"))
	body.name = "StandingsOverviewBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = card.tooltip_text
	box.add_child(body)


func _render_seats(entries_variant: Variant) -> void:
	_clear_children(score_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_score_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#fef3c7"))
	var chip := PanelContainer.new()
	chip.name = "StandingsScoreboardChip"
	chip.custom_minimum_size = Vector2(clampf(float(text.length()) * 7.2 + 18.0, 40.0, 180.0), 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 20), 9, accent.lightened(0.12))
	label.name = "StandingsScoreboardChipLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var card := PanelContainer.new()
	card.name = "StandingsRaceKpiCard"
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
	title.name = "StandingsRaceKpiTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(title)
	var value_text := str(entry.get("value", ""))
	var value := _label(_short_text(value_text, 24), 17, Color("#f8fafc"))
	value.name = "StandingsRaceKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.clip_text = true
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.tooltip_text = value_text
	box.add_child(value)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 32), 9, Color("#94a3b8"))
	meta.name = "StandingsRaceKpiMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.tooltip_text = str(entry.get("tooltip", meta_text))
	box.add_child(meta)


func _add_score_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var eliminated := bool(entry.get("eliminated", false))
	var card := PanelContainer.new()
	card.name = "StandingsPlayerScoreCard"
	card.custom_minimum_size = Vector2(0, 126)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", "破产出局是公开状态；对手历史手牌、弃牌和私密计划仍不公开。" if eliminated else "座位记分牌。"))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	score_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var header_row := HBoxContainer.new()
	header_row.name = "StandingsPlayerScoreHeader"
	header_row.add_theme_constant_override("separation", 5)
	box.add_child(header_row)
	var name_label := _label(str(entry.get("name", "席位")), 11, Color("#f8fafc"))
	name_label.name = "StandingsPlayerScoreName"
	header_row.add_child(name_label)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)
	var rank_label := _label(str(entry.get("rank", "")), 11, accent.lightened(0.18))
	rank_label.name = "StandingsPlayerScoreRank"
	rank_label.tooltip_text = str(entry.get("rank_tooltip", "进行中对手名次不等于真实排名，只是座位/可见信息展示。"))
	header_row.add_child(rank_label)
	var score := _label(str(entry.get("score", "")), 18, _dictionary_color(entry, "score_color", Color("#fef3c7")))
	score.name = "StandingsPlayerScoreValue"
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	score.clip_text = true
	score.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	score.tooltip_text = str(entry.get("score_tooltip", "记分。"))
	box.add_child(score)
	var rail := HFlowContainer.new()
	rail.name = "StandingsPlayerScoreChipRail"
	rail.add_theme_constant_override("h_separation", 4)
	rail.add_theme_constant_override("v_separation", 3)
	box.add_child(rail)
	var chips_variant: Variant = entry.get("chips", [])
	var chips := chips_variant as Array if chips_variant is Array else []
	for chip_variant in chips:
		if chip_variant is Dictionary:
			_add_score_chip(rail, chip_variant as Dictionary)
	var meta := _label(str(entry.get("meta", "")), 9, Color("#cbd5e1"))
	meta.name = "StandingsPlayerScoreMeta"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta)


func _add_score_chip(parent: Container, entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var chip := PanelContainer.new()
	chip.name = str(entry.get("name", BANKRUPT_BADGE_NODE_NAME if bool(entry.get("bankrupt", false)) else "StandingsPlayerScoreChip"))
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.25), 1, 5))
	parent.add_child(chip)
	var margin := _margin(5, 1, 5, 1)
	chip.add_child(margin)
	var label := _label(_short_text(text, 14), 8, accent.lightened(0.16))
	label.name = "%sLabel" % chip.name
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


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
