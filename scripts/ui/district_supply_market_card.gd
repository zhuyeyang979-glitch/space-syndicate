extends PanelContainer
class_name SpaceSyndicateDistrictSupplyMarketCard

signal card_hovered(card_name: String)
signal card_preview_requested(card_name: String)
signal card_activated(card_name: String)

@onready var title_label: Label = %DistrictSupplyMarketCardTitle
@onready var rank_label: Label = %DistrictSupplyMarketCardRank
@onready var art_host: PanelContainer = %DistrictSupplyMarketCardArtHost
@onready var art_view: Control = %DistrictSupplyMarketCardArtView
@onready var chip_rail: HFlowContainer = %DistrictSupplyMarketCardChipRail
@onready var micro_chip_rail: HFlowContainer = %DistrictSupplyMarketCardMicroChipRail
@onready var route_label: Label = %DistrictSupplyMarketCardRoute
@onready var fact_label: Label = %DistrictSupplyMarketCardFactLine
@onready var state_band: HBoxContainer = %DistrictSupplyMarketCardStateBand
@onready var state_signal: ColorRect = %DistrictSupplyMarketCardStateSignal
@onready var state_label: Label = %DistrictSupplyMarketCardStateLabel
@onready var color_tick: ColorRect = %DistrictSupplyMarketCardColorTick

var _card_name := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	set_meta("runtime_focus_kind", "district_supply_market_card")
	mouse_entered.connect(_emit_hover)
	focus_entered.connect(_emit_hover)
	set_card({})


func set_card(data: Dictionary) -> void:
	_card_name = str(data.get("card_name", ""))
	var accent := _dictionary_color(data, "accent", Color("#94a3b8"))
	var theme_color := _dictionary_color(data, "theme_color", accent)
	var selected := bool(data.get("selected", false))
	var actionable := bool(data.get("actionable", true))
	tooltip_text = str(data.get("tooltip", ""))
	title_label.text = str(data.get("title", _card_name))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	title_label.add_theme_color_override("font_color", _dictionary_color(data, "title_color", Color("#f8fafc") if actionable else Color("#cbd5e1")))
	rank_label.text = str(data.get("rank", "I"))
	rank_label.tooltip_text = str(data.get("rank_tooltip", "Card rank."))
	rank_label.add_theme_color_override("font_color", theme_color.lightened(0.2))
	_render_market_art(data, theme_color, accent)
	route_label.text = str(data.get("route", ""))
	route_label.tooltip_text = str(data.get("route_tooltip", route_label.text))
	route_label.add_theme_color_override("font_color", theme_color.lightened(0.18))
	fact_label.text = str(data.get("facts", ""))
	fact_label.tooltip_text = str(data.get("facts_tooltip", fact_label.text))
	state_label.text = str(data.get("state_text", ""))
	state_label.tooltip_text = str(data.get("state_tooltip", ""))
	state_label.add_theme_color_override("font_color", accent)
	state_signal.color = accent
	state_band.tooltip_text = state_label.tooltip_text
	color_tick.color = accent
	_render_chips(chip_rail, data.get("chips", []), "DistrictSupplyMarketCardChip", 8, 5)
	_render_chips(micro_chip_rail, data.get("micro_chips", []), "DistrictSupplyMarketCardMicroChip", 7, 4)
	var border := accent.lightened(0.12) if selected else theme_color
	var fill := Color("#020617").lerp(theme_color, 0.16 if selected else 0.08)
	add_theme_stylebox_override("panel", _card_style(border, fill, 2 if selected else 1, 8))
	modulate = Color(1, 1, 1, 1) if actionable else Color(0.82, 0.88, 1.0, 0.82)


func get_card_name() -> String:
	return _card_name


func _render_market_art(data: Dictionary, theme_color: Color, _accent: Color) -> void:
	if art_host != null:
		art_host.set_meta("district_supply_market_uses_shared_card_art", true)
		art_host.add_theme_stylebox_override("panel", _card_style(theme_color, Color("#020617").lerp(theme_color, 0.18), 1, 8))
	if art_view == null or not art_view.has_method("set_card"):
		return
	art_view.set_meta("district_supply_market_visual_theme", "shared-card-art-market-cell")
	var rank_number := _rank_number(str(data.get("rank_number", data.get("rank", "I"))))
	art_view.call(
		"set_card",
		str(data.get("display_name", data.get("title_tooltip", _card_name))),
		str(data.get("kind", "")),
		str(data.get("route", data.get("art_text", ""))),
		theme_color,
		rank_number,
		true,
		str(data.get("card_art_stats", data.get("card_stats", data.get("facts", ""))))
	)
	art_view.modulate = Color(1, 1, 1, 1) if bool(data.get("actionable", true)) else Color(0.76, 0.82, 1.0, 0.74)


func _rank_number(rank_text: String) -> int:
	match rank_text.strip_edges().to_upper():
		"I":
			return 1
		"II":
			return 2
		"III":
			return 3
		"IV":
			return 4
	return maxi(1, int(rank_text))


func _gui_input(event: InputEvent) -> void:
	if _card_name == "":
		return
	if event != null and event.is_action_pressed("ui_accept"):
		_activate_from_confirm()
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.double_click:
			card_activated.emit(_card_name)
		else:
			card_preview_requested.emit(_card_name)
		accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			_activate_from_confirm()
			accept_event()


func _activate_from_confirm() -> void:
	card_activated.emit(_card_name)


func _emit_hover() -> void:
	if _card_name != "":
		card_hovered.emit(_card_name)


func _render_chips(parent: Container, entries_variant: Variant, chip_name: String, font_size: int, gap: int) -> void:
	_clear_children(parent)
	parent.add_theme_constant_override("h_separation", gap)
	parent.add_theme_constant_override("v_separation", maxi(2, gap - 2))
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(parent, entry_variant as Dictionary, chip_name, font_size)


func _add_chip(parent: Container, entry: Dictionary, chip_name: String, font_size: int) -> void:
	var text := str(entry.get("text", ""))
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var fg := _dictionary_color(entry, "fg", accent.lightened(0.16))
	var bg := _dictionary_color(entry, "bg", Color("#020617").lerp(accent, 0.22))
	var chip_width := clampf(float(text.length()) * float(font_size) * 0.72 + 12.0, 22.0, 92.0)
	var chip := PanelContainer.new()
	chip.name = chip_name
	chip.custom_minimum_size = Vector2(chip_width, 18)
	chip.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	chip.add_theme_stylebox_override("panel", _card_style(accent, bg, 1, 6))
	parent.add_child(chip)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 2)
	chip.add_child(margin)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(maxf(1.0, chip_width - 10.0), 0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", fg)
	margin.add_child(label)


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
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
