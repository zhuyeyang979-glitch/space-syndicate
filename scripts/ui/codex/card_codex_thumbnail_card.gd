extends PanelContainer
class_name SpaceSyndicateCardCodexThumbnailCard

signal preview_requested(card_name: String)
signal detail_requested(card_name: String)

@onready var title_label: Label = %CardCodexThumbnailTitle
@onready var art_panel: PanelContainer = %CardCodexThumbnailArt
@onready var art_view: Control = %CardCodexThumbnailArtView
@onready var chip_rail: HFlowContainer = %CardCodexThumbnailChipRail
@onready var route_label: Label = %CardCodexThumbnailRouteBand
@onready var effect_label: Label = %CardCodexThumbnailEffectLine
@onready var hint_label: Label = %CardCodexThumbnailHint

var _card_name := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func set_card(data: Dictionary) -> void:
	_card_name = str(data.get("card_name", ""))
	var accent := _dictionary_color(data, "accent", Color("#94a3b8"))
	var selected := bool(data.get("selected", false))
	custom_minimum_size = Vector2(168, 236)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _card_style(Color("#fef3c7") if selected else accent, Color("#0b1120").lerp(accent, 0.14), 2 if selected else 1, 8))
	title_label.text = str(data.get("title", _card_name))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	art_panel.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.20), 1, 8))
	art_panel.set_meta("card_codex_thumbnail_uses_shared_art_view", true)
	if art_view != null:
		art_view.set_meta("card_codex_thumbnail_visual_theme", "shared-card-art-night-patrol-frame")
		if art_view.has_method("set_card"):
			art_view.call(
				"set_card",
				str(data.get("display_name", data.get("title_tooltip", _card_name))),
				str(data.get("kind", "")),
				str(data.get("route", data.get("art_text", ""))),
				accent,
				maxi(1, int(data.get("rank_number", 1))),
				true,
				str(data.get("card_art_stats", data.get("card_stats", "")))
			)
	_render_chips(data.get("chips", []))
	route_label.text = str(data.get("route", ""))
	route_label.add_theme_color_override("font_color", accent.lightened(0.18))
	route_label.tooltip_text = str(data.get("route_tooltip", ""))
	effect_label.text = str(data.get("effect", ""))
	effect_label.tooltip_text = str(data.get("effect_tooltip", ""))
	hint_label.text = str(data.get("hint", "Hover preview | double-click detail"))


func card_name() -> String:
	return _card_name


func simulate_preview_for_test() -> void:
	_emit_preview()


func simulate_detail_for_test() -> void:
	if _card_name != "":
		detail_requested.emit(_card_name)


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _add_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", ""))
	if text.strip_edges() == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var chip := PanelContainer.new()
	chip.name = "CardCodexThumbnailChip"
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	chip.add_child(margin)
	var label := Label.new()
	label.name = "CardCodexThumbnailChipLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", _dictionary_color(entry, "fg", accent.lightened(0.18)))
	label.tooltip_text = chip.tooltip_text
	margin.add_child(label)


func _on_mouse_entered() -> void:
	_emit_preview()


func _on_gui_input(event: InputEvent) -> void:
	if _card_name == "" or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click:
		detail_requested.emit(_card_name)
	else:
		_emit_preview()
	accept_event()


func _emit_preview() -> void:
	if _card_name != "":
		preview_requested.emit(_card_name)


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
	if value is String:
		var text_value := str(value)
		if text_value.begins_with("#"):
			return Color(text_value)
	return fallback


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
