extends PanelContainer
class_name SpaceSyndicateNewGameSetupLobby

@onready var title_label: Label = %NewGameSetupLobbyTitle
@onready var chip_rail: HFlowContainer = %NewGameSetupLobbyChipRail
@onready var flow_track: GridContainer = %NewGameSetupFlowTrack
@onready var readiness_rail: HFlowContainer = %NewGameSetupReadinessRail


func _ready() -> void:
	set_lobby({})


func set_lobby(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.07), 1, 8))
	title_label.text = str(data.get("title", "开桌流程"))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color("#dbeafe"))
	flow_track.columns = clampi(int(data.get("columns", flow_track.columns)), 1, 5)
	_render_lobby_chips(data.get("chips", []))
	_render_flow_steps(data.get("steps", []))
	_render_readiness_badges(data.get("readiness", []))


func _render_lobby_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_lobby_chip(entry_variant as Dictionary)


func _render_flow_steps(entries_variant: Variant) -> void:
	_clear_children(flow_track)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_flow_step(entry_variant as Dictionary)


func _render_readiness_badges(entries_variant: Variant) -> void:
	_clear_children(readiness_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_status_badge(entry_variant as Dictionary)


func _add_lobby_chip(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#bfdbfe"))
	var chip := PanelContainer.new()
	chip.name = "NewGameSetupLobbyChip"
	chip.custom_minimum_size = Vector2(84, 0)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.16), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := Label.new()
	label.name = "NewGameSetupLobbyChipLabel"
	label.text = str(entry.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = chip.tooltip_text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", accent.lightened(0.16))
	margin.add_child(label)


func _add_flow_step(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var card := PanelContainer.new()
	card.name = "NewGameSetupFlowStepCard"
	card.custom_minimum_size = Vector2(0, 88)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = str(entry.get("tooltip", ""))
	card.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	flow_track.add_child(card)
	var margin := _margin(10, 8, 10, 8)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := Label.new()
	title.name = "NewGameSetupFlowStepTitle"
	title.text = str(entry.get("title", ""))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", accent.lightened(0.16))
	box.add_child(title)
	var body := Label.new()
	body.name = "NewGameSetupFlowStepBody"
	body.text = str(entry.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.tooltip_text = card.tooltip_text
	body.add_theme_font_size_override("font_size", 10)
	body.add_theme_color_override("font_color", Color("#e5e7eb"))
	box.add_child(body)


func _add_status_badge(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var fill := _dictionary_color(entry, "fill", Color("#0f172a"))
	var badge := PanelContainer.new()
	badge.name = "NewGameSetupReadinessBadge"
	badge.tooltip_text = str(entry.get("tooltip", ""))
	badge.add_theme_stylebox_override("panel", _card_style(accent, fill, 1, 8))
	readiness_rail.add_child(badge)
	var margin := _margin(7, 2, 7, 2)
	badge.add_child(margin)
	var label := Label.new()
	label.name = "NewGameSetupReadinessBadgeLabel"
	label.text = str(entry.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.tooltip_text = badge.tooltip_text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", accent.lightened(0.18))
	margin.add_child(label)


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
