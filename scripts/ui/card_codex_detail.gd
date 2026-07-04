extends PanelContainer
class_name SpaceSyndicateCardCodexDetail

const CardFaceScene := preload("res://scenes/ui/CardFace.tscn")

@onready var layout_row: HBoxContainer = %CardCodexTcgDetailLayout
@onready var face_column: VBoxContainer = %CardCodexTcgFaceColumn
@onready var card_face_host: CenterContainer = %CardCodexTcgCardFaceHost
@onready var face_note_label: Label = %CardCodexFaceNote
@onready var read_column: VBoxContainer = %CardCodexTcgReadColumn
@onready var summary_panel: PanelContainer = %CardCodexTcgSummaryPanel
@onready var summary_header: HBoxContainer = %CardCodexTcgSummaryHeader
@onready var summary_title: Label = %CardCodexTcgSummaryTitle
@onready var summary_header_chip_rail: HFlowContainer = %CardCodexTcgSummaryHeaderChipRail
@onready var summary_chip_rail: HFlowContainer = %CardCodexTcgSummaryChipRail
@onready var summary_effect_label: Label = %CardCodexTcgSummaryEffect
@onready var read_order_label: Label = %CardCodexTcgReadOrder
@onready var tactical_strip: PanelContainer = %CardCodexTacticalStrip
@onready var tactical_title: Label = %CardCodexTacticalTitle
@onready var tactical_grid: GridContainer = %CardCodexTacticalGrid
@onready var fact_grid: GridContainer = %CardCodexTcgFactGrid
@onready var upgrade_title: Label = %CardCodexUpgradeTitle
@onready var upgrade_ladder: GridContainer = %CardCodexUpgradeLadder
@onready var resolution_host: VBoxContainer = %CardCodexResolutionInfoHost


func _ready() -> void:
	_style_shell()


func set_detail(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.05), 1, 8))
	face_note_label.text = str(data.get("face_note", "重复入手→升级；价格看I级。"))
	face_note_label.tooltip_text = str(data.get("face_note_tooltip", ""))
	_render_card_face(data.get("card_face", {}))
	_render_summary(data.get("summary", {}), accent)
	_render_tactical(data.get("tactical", {}), accent)
	_render_fact_cards(data.get("facts", []))
	upgrade_title.text = str(data.get("upgrade_title", "I→IV 强化"))
	_render_upgrades(data.get("upgrades", []))
	_render_info_card(data.get("resolution", {}))


func _style_shell() -> void:
	layout_row.add_theme_constant_override("separation", 14)
	face_column.add_theme_constant_override("separation", 8)
	read_column.add_theme_constant_override("separation", 10)
	summary_title.custom_minimum_size = Vector2(122, 0)
	summary_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary_title.clip_text = true
	summary_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary_title.add_theme_font_size_override("font_size", 16)
	summary_title.add_theme_color_override("font_color", Color("#f8fafc"))
	face_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	face_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_note_label.add_theme_font_size_override("font_size", 12)
	face_note_label.add_theme_color_override("font_color", Color("#94a3b8"))
	summary_header.add_theme_constant_override("separation", 8)
	summary_header_chip_rail.add_theme_constant_override("h_separation", 5)
	summary_header_chip_rail.add_theme_constant_override("v_separation", 4)
	summary_chip_rail.add_theme_constant_override("h_separation", 5)
	summary_chip_rail.add_theme_constant_override("v_separation", 4)
	summary_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_effect_label.add_theme_font_size_override("font_size", 13)
	summary_effect_label.add_theme_color_override("font_color", Color("#e5e7eb"))
	read_order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	read_order_label.add_theme_font_size_override("font_size", 12)
	tactical_title.add_theme_font_size_override("font_size", 14)
	tactical_title.add_theme_color_override("font_color", Color("#fef3c7"))
	tactical_grid.columns = 3
	tactical_grid.add_theme_constant_override("h_separation", 6)
	tactical_grid.add_theme_constant_override("v_separation", 6)
	fact_grid.columns = 2
	fact_grid.add_theme_constant_override("h_separation", 10)
	fact_grid.add_theme_constant_override("v_separation", 10)
	upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_title.add_theme_font_size_override("font_size", 16)
	upgrade_title.add_theme_color_override("font_color", Color("#fde68a"))
	upgrade_ladder.columns = 4
	upgrade_ladder.add_theme_constant_override("h_separation", 8)
	upgrade_ladder.add_theme_constant_override("v_separation", 8)


func _render_card_face(entry_variant: Variant) -> void:
	_clear_children(card_face_host)
	if not (entry_variant is Dictionary):
		card_face_host.visible = false
		return
	var entry := entry_variant as Dictionary
	card_face_host.visible = not entry.is_empty()
	if entry.is_empty():
		return
	var face := CardFaceScene.instantiate() as Control
	if face == null:
		return
	face.name = "CardCodexSceneCardFace"
	face.custom_minimum_size = Vector2(
		float(entry.get("minimum_width", 230.0)),
		float(entry.get("minimum_height", 300.0))
	)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_face_host.add_child(face)
	if face.has_method("set_card_data"):
		face.call("set_card_data", entry)


func _render_summary(entry_variant: Variant, fallback_accent: Color) -> void:
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	var accent := _dictionary_color(entry, "accent", fallback_accent)
	summary_panel.tooltip_text = str(entry.get("tooltip", "像读桌游/TCG卡牌一样：先看费用、等级、门槛、目标和去向，再看核心效果。"))
	summary_panel.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	summary_title.text = str(entry.get("title", "扫牌顺序"))
	summary_title.tooltip_text = str(entry.get("title_tooltip", "卡牌详情页先扫摘要，不需要先读完整规则。"))
	_render_chips(summary_header_chip_rail, entry.get("header_chips", []), "CardCodexTcgSummaryChip", 11)
	_render_chips(summary_chip_rail, entry.get("chips", []), "CardCodexTcgSummaryChip", 11)
	summary_effect_label.text = str(entry.get("effect", ""))
	summary_effect_label.tooltip_text = str(entry.get("effect_tooltip", ""))
	read_order_label.text = str(entry.get("read_order", "读法：费用 → 门槛 → 目标 → 去向 → 效果 → I-IV升级"))
	read_order_label.add_theme_color_override("font_color", accent.lightened(0.18))


func _render_tactical(entry_variant: Variant, fallback_accent: Color) -> void:
	_clear_children(tactical_grid)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	var accent := _dictionary_color(entry, "accent", fallback_accent)
	tactical_strip.tooltip_text = str(entry.get("tooltip", "牌桌用途条：从玩家决策角度读这张牌，不显示隐藏信息。"))
	tactical_strip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	tactical_title.text = str(entry.get("title", "牌桌用途｜先看这三格"))
	tactical_title.tooltip_text = str(entry.get("title_tooltip", "像读桌游卡一样，先判断拿牌时机、配合路线和公开线索。"))
	var entries_variant: Variant = entry.get("entries", [])
	if not (entries_variant is Array):
		return
	for card_variant in entries_variant:
		if card_variant is Dictionary:
			_add_tactical_card(card_variant as Dictionary)


func _render_fact_cards(entries_variant: Variant) -> void:
	_clear_children(fact_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_info_card(fact_grid, entry_variant as Dictionary, "CardCodexTcgFactCard")


func _render_upgrades(entries_variant: Variant) -> void:
	_clear_children(upgrade_ladder)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_upgrade_card(entry_variant as Dictionary)


func _render_info_card(entry_variant: Variant) -> void:
	_clear_children(resolution_host)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	if entry.is_empty():
		return
	_add_info_card(resolution_host, entry, "CardCodexResolutionInfoCard")


func _render_chips(parent: Container, entries_variant: Variant, chip_name: String, font_size: int) -> void:
	_clear_children(parent)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(parent, entry_variant as Dictionary, chip_name, font_size)


func _add_chip(parent: Container, entry: Dictionary, chip_name: String, font_size: int) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var fg := _dictionary_color(entry, "fg", accent.lightened(0.16))
	var bg := _dictionary_color(entry, "bg", Color("#020617").lerp(accent, 0.16))
	var chip_width := clampf(float(text.length()) * float(font_size) * 0.70 + 18.0, 34.0, 178.0)
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.custom_minimum_size = Vector2(chip_width, 26)
	chip.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	chip.add_theme_stylebox_override("panel", _card_style(accent, bg, 1, 8))
	parent.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 18), font_size, fg)
	label.name = "CardCodexTcgSummaryChipLabel"
	label.custom_minimum_size = Vector2(maxf(1.0, chip_width - 14.0), 0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_tactical_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var card := PanelContainer.new()
	card.name = "CardCodexTacticalCard"
	card.custom_minimum_size = Vector2(0, 88)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.12), 1, 8))
	tactical_grid.add_child(card)
	var margin := _margin(8, 6, 8, 6)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var tick := ColorRect.new()
	tick.name = "CardCodexTacticalColorTick"
	tick.color = accent.lightened(0.12)
	tick.custom_minimum_size = Vector2(0, 3)
	box.add_child(tick)
	var title := _label(str(entry.get("title", "")), 11, accent.lightened(0.18))
	title.name = "CardCodexTacticalCardTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title)
	var body_text := str(entry.get("body", ""))
	var body := _label(_short_text(body_text, 56), 10, Color("#e5e7eb"))
	body.name = "CardCodexTacticalCardBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = body_text
	box.add_child(body)


func _add_info_card(parent: Container, entry: Dictionary, node_name: String) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var card := PanelContainer.new()
	card.name = node_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", entry.get("meta", "")))
	card.set_meta("card_codex_patterned_attribute", true)
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	parent.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var tick := ColorRect.new()
	tick.name = "CardCodexAttributeColorTick"
	tick.color = accent.lightened(0.12)
	tick.custom_minimum_size = Vector2(0, 3)
	box.add_child(tick)
	var title := _label(str(entry.get("title", "")), 13, accent.lightened(0.18))
	title.name = "%sTitle" % node_name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body := _label(str(entry.get("body", "")), 12, Color("#e5e7eb"))
	body.name = "%sBody" % node_name
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = str(entry.get("body_tooltip", body.text))
	box.add_child(body)
	var meta_text := str(entry.get("meta", ""))
	if meta_text != "":
		var meta := _label(meta_text, 10, Color("#94a3b8"))
		meta.name = "%sMeta" % node_name
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(meta)


func _add_upgrade_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#facc15"))
	var panel := PanelContainer.new()
	panel.name = "CardCodexUpgradeStepCard"
	panel.custom_minimum_size = Vector2(0, 136)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = str(entry.get("tooltip", ""))
	panel.set_meta("card_codex_upgrade_ladder_step", true)
	panel.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, float(entry.get("fill_weight", 0.10))), 1, 8))
	upgrade_ladder.add_child(panel)
	var margin := _margin(9, 8, 9, 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.name = "CardCodexUpgradeStepHeader"
	header.add_theme_constant_override("separation", 4)
	box.add_child(header)
	var roman := _label(str(entry.get("roman", "")), 14, Color("#f8fafc"))
	roman.name = "CardCodexUpgradeRomanLevel"
	roman.custom_minimum_size = Vector2(42, 0)
	roman.autowrap_mode = TextServer.AUTOWRAP_OFF
	roman.clip_text = true
	roman.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	roman.tooltip_text = "卡牌等级使用罗马数字。"
	header.add_child(roman)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var price := _label(str(entry.get("price", "")), 12, Color("#fef3c7"))
	price.name = "CardCodexUpgradePrice"
	price.custom_minimum_size = Vector2(46, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.autowrap_mode = TextServer.AUTOWRAP_OFF
	price.clip_text = true
	price.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	price.tooltip_text = str(entry.get("price_tooltip", "购买仍按该系列I级价格体系展示；重复获得会自动合成升级。"))
	header.add_child(price)
	var band := _label(str(entry.get("band", "")), 11, accent.lightened(0.18))
	band.name = "CardCodexUpgradeBudgetBand"
	band.autowrap_mode = TextServer.AUTOWRAP_OFF
	band.clip_text = true
	band.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(band)
	var body := _label(_short_text(str(entry.get("body", "")), 72), 11, Color("#e5e7eb"))
	body.name = "CardCodexUpgradeStepBody"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = str(entry.get("body_tooltip", entry.get("body", "")))
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
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	style.shadow_size = 4
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
