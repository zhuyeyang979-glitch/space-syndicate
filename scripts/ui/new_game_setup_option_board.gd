extends PanelContainer
class_name SpaceSyndicateNewGameSetupOptionBoard

signal option_selected(option_id: String, value: int)

@onready var title_label: Label = %NewGameSetupOptionBoardTitle
@onready var option_grid: GridContainer = %NewGameSetupOptionGrid


func _ready() -> void:
	set_options({})


func set_options(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#facc15"))
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "开局参数｜先定桌面规模"))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color("#fef3c7"))
	option_grid.columns = clampi(int(data.get("columns", option_grid.columns)), 1, 3)
	_render_cards(data.get("cards", []))


func _render_cards(entries_variant: Variant) -> void:
	_clear_children(option_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_option_card(entry_variant as Dictionary)


func _add_option_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var card := PanelContainer.new()
	card.name = "NewGameSetupOptionCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 112)
	card.tooltip_text = str(entry.get("detail", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	option_grid.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var title := Label.new()
	title.name = "NewGameSetupOptionCardTitle"
	title.text = str(entry.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", accent.lightened(0.16))
	box.add_child(title)
	var detail := Label.new()
	detail.name = "NewGameSetupOptionCardDetail"
	detail.text = str(entry.get("detail", ""))
	detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.tooltip_text = card.tooltip_text
	detail.add_theme_font_size_override("font_size", 9)
	detail.add_theme_color_override("font_color", Color("#e5e7eb"))
	box.add_child(detail)
	var rail := HFlowContainer.new()
	rail.name = "NewGameSetupOptionButtonRail"
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_theme_constant_override("h_separation", 5)
	rail.add_theme_constant_override("v_separation", 4)
	box.add_child(rail)
	var options: Variant = entry.get("options", [])
	if not (options is Array):
		return
	for option_variant in options:
		if option_variant is Dictionary:
			_add_option_button(rail, option_variant as Dictionary, accent)


func _add_option_button(parent: Container, entry: Dictionary, accent: Color) -> void:
	var button := Button.new()
	button.name = "NewGameSetupOptionButton"
	button.text = str(entry.get("text", ""))
	button.toggle_mode = true
	button.button_pressed = bool(entry.get("pressed", false))
	button.tooltip_text = str(entry.get("tooltip", ""))
	_style_button(button, accent, button.button_pressed)
	var option_id := str(entry.get("id", ""))
	var value := int(entry.get("value", 0))
	if option_id != "":
		button.pressed.connect(_emit_option_selected.bind(option_id, value))
	parent.add_child(button)


func _emit_option_selected(option_id: String, value: int) -> void:
	option_selected.emit(option_id, value)


func _style_button(button: Button, accent: Color, active: bool) -> void:
	var fill := Color("#0b1220").lerp(accent, 0.20 if active else 0.09)
	button.add_theme_stylebox_override("normal", _card_style(accent, fill, 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.14), fill.lightened(0.08), 1, 8))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.24), fill.darkened(0.08), 1, 8))
	button.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#dbeafe"))


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
