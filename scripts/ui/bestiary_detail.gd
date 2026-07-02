extends PanelContainer
class_name SpaceSyndicateBestiaryDetail

const MonsterArtViewScript := preload("res://scripts/monster_art_view.gd")

@onready var header: HBoxContainer = %BestiaryMonsterHeader
@onready var art_slot: PanelContainer = %BestiaryMonsterArtSlot
@onready var art_host: CenterContainer = %BestiaryMonsterArtHost
@onready var title_label: Label = %BestiaryMonsterTitle
@onready var subtitle_label: Label = %BestiaryMonsterSubtitle
@onready var chip_rail: HFlowContainer = %BestiaryMonsterChipRail
@onready var kpi_grid: GridContainer = %BestiaryMonsterKpiGrid
@onready var action_title_label: Label = %BestiaryMonsterActionBoardTitle
@onready var action_grid: GridContainer = %BestiaryMonsterActionGrid


func _ready() -> void:
	_style_shell()


func set_monster(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#fb7185"))
	tooltip_text = str(data.get("tooltip", "怪兽档案板：先看画像、HP、速度、偏好、生态位和行动概率。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	art_slot.add_theme_stylebox_override("panel", _card_style(accent, Color("#0b1120").lerp(accent, 0.16), 1, 8))
	title_label.text = str(data.get("title", "怪兽单位档案"))
	subtitle_label.text = _short_text(str(data.get("subtitle", "自动怪兽。")), 96)
	subtitle_label.tooltip_text = str(data.get("subtitle", "自动怪兽。"))
	subtitle_label.add_theme_color_override("font_color", accent.lightened(0.18))
	action_title_label.text = str(data.get("action_title", "行动概率板｜I级/IV级｜开局/破坏后"))
	action_title_label.tooltip_text = str(data.get("action_tooltip", "怪兽仍会自动行动；召唤者只能用绑定技能牌做一次性指令。"))
	_render_art(data.get("art", {}), accent)
	_render_chips(data.get("chips", []))
	_render_kpis(data.get("kpis", []))
	_render_actions(data.get("actions", []), accent)


func _style_shell() -> void:
	header.add_theme_constant_override("separation", 12)
	art_slot.custom_minimum_size = Vector2(278, 218)
	art_slot.clip_contents = true
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 11)
	chip_rail.add_theme_constant_override("h_separation", 4)
	chip_rail.add_theme_constant_override("v_separation", 4)
	kpi_grid.columns = 4
	kpi_grid.add_theme_constant_override("h_separation", 7)
	kpi_grid.add_theme_constant_override("v_separation", 7)
	action_title_label.add_theme_font_size_override("font_size", 13)
	action_title_label.add_theme_color_override("font_color", Color("#fef3c7"))
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 7)
	action_grid.add_theme_constant_override("v_separation", 7)


func _render_art(art_variant: Variant, fallback_accent: Color) -> void:
	_clear_children(art_host)
	var art := art_variant as Dictionary if art_variant is Dictionary else {}
	var profile_variant: Variant = art.get("profile", {})
	var profile := profile_variant as Dictionary if profile_variant is Dictionary else {}
	if not profile.has("accent"):
		profile["accent"] = fallback_accent
	var art_view = MonsterArtViewScript.new()
	art_view.name = "BestiaryMonsterArtView"
	art_view.custom_minimum_size = Vector2(258, 198)
	art_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_view.set_monster(
		str(art.get("name", "怪兽")),
		str(art.get("style", "自动怪兽。")),
		int(art.get("hp", 0)),
		int(art.get("armor", 0)),
		str(art.get("move_text", "")),
		profile,
		true
	)
	art_host.add_child(art_view)


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


func _render_actions(entries_variant: Variant, fallback_accent: Color) -> void:
	_clear_children(action_grid)
	if not (entries_variant is Array):
		return
	var action_index := 0
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_action(entry_variant as Dictionary, action_index, fallback_accent)
			action_index += 1


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#fecdd3"))
	var fg := _dictionary_color(entry, "fg", accent.lightened(0.18))
	var bg := _dictionary_color(entry, "bg", Color("#020617").lerp(accent, 0.20))
	var chip_width := clampf(float(text.length()) * 7.2 + 18.0, 36.0, 170.0)
	var chip := PanelContainer.new()
	chip.name = "BestiaryMonsterChip"
	chip.custom_minimum_size = Vector2(chip_width, 22)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, bg, 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := _label(_short_text(text, 20), 9, fg)
	label.name = "BestiaryMonsterChipLabel"
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _add_kpi(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#fb923c"))
	var card := PanelContainer.new()
	card.name = "BestiaryMonsterKpiCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 82)
	card.tooltip_text = str(entry.get("tooltip", "%s｜%s｜%s" % [entry.get("title", ""), entry.get("value", ""), entry.get("meta", "")]))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	kpi_grid.add_child(card)
	var margin := _margin(9, 7, 9, 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	box.add_child(_label(str(entry.get("title", "")), 10, accent.lightened(0.18)))
	var value_text := str(entry.get("value", ""))
	var value := _label(_short_text(value_text, 38), 12, Color("#f8fafc"))
	value.name = "BestiaryMonsterKpiValue"
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.tooltip_text = value_text
	box.add_child(value)
	var meta_text := str(entry.get("meta", ""))
	var meta := _label(_short_text(meta_text, 42), 9, Color("#94a3b8"))
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.tooltip_text = meta_text
	box.add_child(meta)


func _add_action(entry: Dictionary, action_index: int, fallback_accent: Color) -> void:
	var accent := _dictionary_color(entry, "accent", fallback_accent.lerp(Color("#fde68a"), clampf(float(action_index) / 7.0, 0.0, 0.45)))
	var card := PanelContainer.new()
	card.name = "BestiaryMonsterActionCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 108)
	card.tooltip_text = str(entry.get("tooltip", entry.get("body", "")))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	action_grid.add_child(card)
	var margin := _margin(9, 7, 9, 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)
	var index_label := _label(str(entry.get("index", "%02d" % (action_index + 1))), 10, accent.lightened(0.18))
	index_label.name = "BestiaryMonsterActionIndex"
	row.add_child(index_label)
	var name_text := str(entry.get("name", "行动"))
	var name_label := _label(_short_text(name_text, 24), 11, Color("#f8fafc"))
	name_label.name = "BestiaryMonsterActionName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.tooltip_text = name_text
	row.add_child(name_label)
	var tags_text := str(entry.get("tags", "基础"))
	var tags := _label(_short_text(tags_text, 18), 8, accent.lightened(0.14))
	tags.tooltip_text = tags_text
	row.add_child(tags)
	var probability_text := str(entry.get("probability", "I --/--｜IV --/--"))
	var probability := _label(probability_text, 10, Color("#fde68a"))
	probability.name = "BestiaryMonsterActionProbability"
	probability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probability.tooltip_text = str(entry.get("probability_tooltip", probability_text))
	box.add_child(probability)
	var facts_text := str(entry.get("facts", "贴近/移动"))
	var facts := _label(_short_text(facts_text, 72), 9, Color("#cbd5e1"))
	facts.name = "BestiaryMonsterActionFacts"
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.tooltip_text = facts_text
	box.add_child(facts)
	var body_text := str(entry.get("body", ""))
	if body_text != "":
		var body := _label(_short_text(body_text, 72), 9, Color("#e5e7eb"))
		body.name = "BestiaryMonsterActionBody"
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
