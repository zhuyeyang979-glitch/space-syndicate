extends PanelContainer
class_name SpaceSyndicateCardCodexBrowser

signal filter_selected(filter_id: String)
signal page_step_requested(delta: int)
signal card_preview_requested(card_name: String)
signal card_detail_requested(card_name: String)

const CardArtViewScript := preload("res://scripts/card_art_view.gd")

@onready var category_rail: PanelContainer = %CardCodexCategoryRail
@onready var category_legend: Label = %CardCodexCategoryLegend
@onready var category_chip_row: HFlowContainer = %CardCodexCategoryChipRow
@onready var nav_row: HBoxContainer = %CardCodexThumbnailNavRow
@onready var previous_button: Button = %CardCodexThumbnailPreviousButton
@onready var page_label: Label = %CardCodexThumbnailPageLabel
@onready var next_button: Button = %CardCodexThumbnailNextButton
@onready var grid: GridContainer = %CardCodexThumbnailGrid
@onready var preview_host: VBoxContainer = %CardCodexHoverPreviewHost


func _ready() -> void:
	_style_shell()
	previous_button.pressed.connect(func() -> void:
		page_step_requested.emit(-1)
	)
	next_button.pressed.connect(func() -> void:
		page_step_requested.emit(1)
	)


func set_browser(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.06), 1, 8))
	category_legend.text = str(data.get("legend", "牌型筛选"))
	category_legend.tooltip_text = str(data.get("legend_tooltip", "点筹码只看这一类牌；悬停卡牌看预览，双击进入详情。"))
	grid.columns = clampi(int(data.get("columns", 3)), 1, 6)
	previous_button.text = str(data.get("previous_text", "缩略图上一页"))
	previous_button.disabled = bool(data.get("previous_disabled", false))
	next_button.text = str(data.get("next_text", "缩略图下一页"))
	next_button.disabled = bool(data.get("next_disabled", false))
	page_label.text = str(data.get("page_text", ""))
	_render_filters(data.get("filters", []))
	_render_cards(data.get("cards", []))
	set_preview(data.get("preview", {}))


func set_preview(data_variant: Variant) -> void:
	_clear_children(preview_host)
	if not (data_variant is Dictionary):
		return
	var data := data_variant as Dictionary
	var title_text := str(data.get("title", ""))
	var body_text := str(data.get("body", ""))
	if title_text.strip_edges() == "" and body_text.strip_edges() == "":
		return
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	var preview_panel := PanelContainer.new()
	preview_panel.name = "CardCodexHoverPreview"
	preview_panel.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.13), 1, 8))
	preview_host.add_child(preview_panel)
	var margin := _margin(10, 8, 10, 8)
	preview_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var title := Label.new()
	title.name = "CardCodexHoverPreviewTitle"
	title.custom_minimum_size = Vector2(176, 0)
	title.text = title_text
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", accent.lightened(0.2))
	row.add_child(title)
	var body := Label.new()
	body.name = "CardCodexHoverPreviewBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Color("#dbeafe"))
	row.add_child(body)


func _render_filters(entries_variant: Variant) -> void:
	_clear_children(category_chip_row)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_filter(entry_variant as Dictionary)


func _add_filter(entry: Dictionary) -> void:
	var filter_id := str(entry.get("id", ""))
	var button := Button.new()
	button.name = "CardCodexCategoryChip"
	button.text = str(entry.get("text", filter_id))
	button.tooltip_text = str(entry.get("tooltip", button.text))
	button.toggle_mode = true
	button.button_pressed = bool(entry.get("active", false))
	button.disabled = bool(entry.get("disabled", false))
	button.custom_minimum_size = Vector2(86, 28)
	_style_button(button, _dictionary_color(entry, "accent", Color("#93c5fd")))
	if filter_id != "":
		button.pressed.connect(func() -> void:
			filter_selected.emit(filter_id)
		)
	category_chip_row.add_child(button)


func _render_cards(entries_variant: Variant) -> void:
	_clear_children(grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_card(entry_variant as Dictionary)


func _add_card(entry: Dictionary) -> void:
	var card_name := str(entry.get("card_name", ""))
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var selected := bool(entry.get("selected", false))
	var panel := PanelContainer.new()
	panel.name = "CardCodexThumbnailCard"
	panel.custom_minimum_size = Vector2(146, 204)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = str(entry.get("tooltip", ""))
	panel.add_theme_stylebox_override("panel", _card_style(Color("#fef3c7") if selected else accent, Color("#0b1120").lerp(accent, 0.14), 2 if selected else 1, 8))
	panel.mouse_entered.connect(func() -> void:
		if card_name != "":
			card_preview_requested.emit(card_name)
	)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		_on_card_input(event, card_name)
	)
	grid.add_child(panel)
	var margin := _margin(7, 7, 7, 7)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := _label(str(entry.get("title", card_name)), 10, Color("#f8fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.tooltip_text = str(entry.get("title_tooltip", title.text))
	box.add_child(title)
	var art := PanelContainer.new()
	art.name = "CardCodexThumbnailArt"
	art.custom_minimum_size = Vector2(0, 76)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.set_meta("card_codex_thumbnail_uses_shared_art_view", true)
	art.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.20), 1, 8))
	box.add_child(art)
	var art_margin := _margin(6, 4, 6, 4)
	art.add_child(art_margin)
	var art_view := CardArtViewScript.new() as Control
	art_view.name = "CardCodexThumbnailArtView"
	art_view.custom_minimum_size = Vector2(0, 66)
	art_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_view.set_meta("card_codex_thumbnail_visual_theme", "shared-card-art-night-patrol-frame")
	art_margin.add_child(art_view)
	if art_view.has_method("set_card"):
		art_view.call(
			"set_card",
			str(entry.get("display_name", entry.get("title_tooltip", card_name))),
			str(entry.get("kind", "")),
			str(entry.get("route", entry.get("art_text", ""))),
			accent,
			maxi(1, int(entry.get("rank_number", 1))),
			true,
			str(entry.get("card_art_stats", entry.get("card_stats", "")))
		)
	_render_chips(box, entry.get("chips", []))
	var route := _label(str(entry.get("route", "")), 8, accent.lightened(0.18))
	route.name = "CardCodexThumbnailRouteBand"
	route.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route.autowrap_mode = TextServer.AUTOWRAP_OFF
	route.clip_text = true
	route.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	route.tooltip_text = str(entry.get("route_tooltip", ""))
	box.add_child(route)
	var effect := _label(str(entry.get("effect", "")), 8, Color("#dbeafe"))
	effect.name = "CardCodexThumbnailEffectLine"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_OFF
	effect.clip_text = true
	effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect.tooltip_text = str(entry.get("effect_tooltip", ""))
	box.add_child(effect)
	var hint := _label(str(entry.get("hint", "悬停预览｜双击详情")), 8, Color("#94a3b8"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _render_chips(parent: Container, entries_variant: Variant) -> void:
	var rail := HFlowContainer.new()
	rail.name = "CardCodexThumbnailChipRail"
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.tooltip_text = "缩略图速读：价格、等级、门槛和目标。"
	rail.add_theme_constant_override("h_separation", 3)
	rail.add_theme_constant_override("v_separation", 2)
	parent.add_child(rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(rail, entry_variant as Dictionary)


func _add_chip(parent: Container, entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var chip := PanelContainer.new()
	chip.name = "CardCodexThumbnailChip"
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	parent.add_child(chip)
	var margin := _margin(5, 1, 5, 1)
	chip.add_child(margin)
	var label := _label(text, 8, _dictionary_color(entry, "fg", accent.lightened(0.18)))
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _on_card_input(event: InputEvent, card_name: String) -> void:
	if card_name == "" or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click:
		card_detail_requested.emit(card_name)
	else:
		card_preview_requested.emit(card_name)
	accept_event()


func _style_shell() -> void:
	category_legend.add_theme_font_size_override("font_size", 10)
	category_legend.add_theme_color_override("font_color", Color("#fde68a"))
	page_label.add_theme_font_size_override("font_size", 12)
	page_label.add_theme_color_override("font_color", Color("#bfdbfe"))
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_button(previous_button, Color("#93c5fd"))
	_style_button(next_button, Color("#93c5fd"))


func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _card_style(accent, Color("#0b1220").lerp(accent, 0.10), 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), Color("#0b1220").lerp(accent, 0.18), 1, 8))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.24), 1, 8))
	button.add_theme_stylebox_override("disabled", _card_style(Color("#334155"), Color("#020617"), 1, 8))
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))


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


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
