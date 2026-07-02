extends PanelContainer
class_name SpaceSyndicateNewGameSetupSeatIdentityBoard

@onready var chip_rail: HFlowContainer = %NewGameSetupSeatPublicChipRail
@onready var info_grid: GridContainer = %NewGameSetupSeatInfoGrid


func _ready() -> void:
	set_identity({})


func set_identity(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	info_grid.columns = clampi(int(data.get("columns", info_grid.columns)), 1, 2)
	_render_chips(data.get("chips", []))
	_render_cards(data.get("cards", []))


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_cards(entries_variant: Variant) -> void:
	_clear_children(info_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_info_card(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#e0f2fe"))
	var fill := _dictionary_color(entry, "fill", Color("#0f172a"))
	var chip := PanelContainer.new()
	chip.name = "NewGameSetupSeatPublicChip"
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, fill, 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := Label.new()
	label.name = "NewGameSetupSeatPublicChipLabel"
	label.text = str(entry.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", accent.lightened(0.18))
	margin.add_child(label)


func _add_info_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var card := PanelContainer.new()
	card.name = "NewGameSetupSeatInfoCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 58)
	card.tooltip_text = str(entry.get("tooltip", entry.get("body", "")))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.08), 1, 8))
	info_grid.add_child(card)
	var margin := _margin(7, 5, 7, 5)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	var title := Label.new()
	title.name = "NewGameSetupSeatInfoTitle"
	title.text = str(entry.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", accent.lightened(0.16))
	box.add_child(title)
	var body := Label.new()
	body.name = "NewGameSetupSeatInfoBody"
	body.text = str(entry.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = card.tooltip_text
	body.add_theme_font_size_override("font_size", 9)
	body.add_theme_color_override("font_color", Color("#e5e7eb"))
	box.add_child(body)


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	return fallback


func _card_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
