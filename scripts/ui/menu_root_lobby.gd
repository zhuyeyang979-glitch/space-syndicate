extends PanelContainer
class_name SpaceSyndicateMenuRootLobby

signal action_requested(action_id: String)
signal rules_requested()
signal compendium_requested()

@onready var title_label: Label = %MainMenuLobbyTitle
@onready var status_label: Label = %MainMenuLobbyStatus
@onready var backdrop_art: Control = %MainMenuPlanetBackdrop
@onready var planet_panel: PanelContainer = %MainMenuPlanetMedallion
@onready var planet_art: Control = %MainMenuPlanetArt
@onready var planet_mark_label: Label = %MainMenuPlanetMark
@onready var planet_title_label: Label = %MainMenuPlanetTitle
@onready var planet_hint_label: Label = %MainMenuPlanetHint
@onready var chip_rail: Container = %MainMenuLobbyChipRail
@onready var right_column: VBoxContainer = %MainMenuLobbyRightColumn
@onready var table_line_label: Label = %MainMenuLobbyTableLine
@onready var action_grid: GridContainer = %MainMenuLobbyActionGrid
@onready var utility_rail: HFlowContainer = %MainMenuUtilityRail

const MAIN_MENU_FEATURED_CARD_HEIGHT := 142
const MAIN_MENU_COMMAND_CARD_HEIGHT := 116
const MAIN_MENU_COMMAND_RADIUS := 8

var _buttons_by_id: Dictionary = {}


func _ready() -> void:
	set_lobby({})


func set_lobby(data: Dictionary) -> void:
	_buttons_by_id = {}
	var accent := _dictionary_color(data, "accent", Color("#f59e0b"))
	tooltip_text = str(data.get("tooltip", ""))
	add_theme_stylebox_override("panel", _lobby_panel_style(accent))
	planet_panel.add_theme_stylebox_override("panel", _planet_panel_style(accent))
	_configure_commercial_lobby_layout()
	if backdrop_art != null and backdrop_art.has_method("set_art"):
		backdrop_art.call("set_art", data)
	if planet_art != null and planet_art.has_method("set_art"):
		planet_art.call("set_art", data)
	if planet_art != null:
		planet_art.visible = false
	title_label.text = str(data.get("title", "牌桌大厅"))
	title_label.tooltip_text = str(data.get("title_tooltip", title_label.text))
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	status_label.text = str(data.get("status", ""))
	status_label.tooltip_text = str(data.get("status_tooltip", status_label.text))
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", accent.lightened(0.12))
	planet_mark_label.text = str(data.get("planet_mark", "◎"))
	planet_mark_label.add_theme_font_size_override("font_size", 58)
	planet_mark_label.add_theme_color_override("font_color", accent.lightened(0.08))
	planet_title_label.text = str(data.get("planet_title", "星球赌桌大厅"))
	planet_title_label.add_theme_font_size_override("font_size", 22)
	planet_title_label.add_theme_color_override("font_color", Color("#f8fafc"))
	planet_hint_label.text = str(data.get("planet_hint", ""))
	planet_hint_label.add_theme_font_size_override("font_size", 12)
	planet_hint_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	if chip_rail != null:
		chip_rail.tooltip_text = str(data.get("chip_rail_tooltip", "牌桌状态速览。"))
	table_line_label.text = str(data.get("table_line", "选择你的下一步"))
	table_line_label.tooltip_text = str(data.get("table_tooltip", table_line_label.text))
	table_line_label.add_theme_font_size_override("font_size", 16)
	table_line_label.add_theme_color_override("font_color", Color("#e2e8f0"))
	_render_chips(data.get("chips", []))
	_render_actions(data.get("actions", []), true)
	_render_actions(data.get("utilities", []), false)
	var columns := clampi(int(data.get("columns", 1)), 1, 2)
	action_grid.columns = columns


func _configure_commercial_lobby_layout() -> void:
	if right_column != null:
		right_column.custom_minimum_size = Vector2(430, 0)
		right_column.add_theme_constant_override("separation", 11)
	if action_grid != null:
		action_grid.add_theme_constant_override("h_separation", 10)
		action_grid.add_theme_constant_override("v_separation", 10)
	if utility_rail != null:
		utility_rail.add_theme_constant_override("h_separation", 8)
		utility_rail.add_theme_constant_override("v_separation", 7)
	if chip_rail != null:
		chip_rail.add_theme_constant_override("separation", 7)


func get_load_run_button() -> Button:
	return _buttons_by_id.get("load_run", null) as Button


func get_action_button(action_id: String) -> Button:
	return _buttons_by_id.get(action_id, null) as Button


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_actions(entries_variant: Variant, primary: bool) -> void:
	var parent: Node = action_grid
	if not primary:
		parent = utility_rail
	_clear_children(parent)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			if primary:
				_add_command_card(entry_variant as Dictionary)
			else:
				_add_utility_button(entry_variant as Dictionary)


func _add_command_card(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#38bdf8"))
	var featured := bool(entry.get("featured", false))
	var panel := PanelContainer.new()
	panel.name = "MainMenuCommandCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, MAIN_MENU_FEATURED_CARD_HEIGHT if featured else MAIN_MENU_COMMAND_CARD_HEIGHT)
	panel.tooltip_text = str(entry.get("tooltip", entry.get("detail", "")))
	panel.add_theme_stylebox_override("panel", _command_card_style(accent, featured, false))
	action_grid.add_child(panel)
	var margin := _margin(14, 10, 14, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	var header := HBoxContainer.new()
	header.name = "MainMenuCommandHeader"
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var index_label := Label.new()
	index_label.name = "MainMenuCommandIndex"
	var raw_kicker := str(entry.get("kicker", "主命令"))
	index_label.text = _command_index_text(raw_kicker, action_grid.get_child_count())
	index_label.tooltip_text = panel.tooltip_text
	index_label.custom_minimum_size = Vector2(34, 0)
	index_label.add_theme_font_size_override("font_size", 10)
	index_label.add_theme_color_override("font_color", accent.lightened(0.24))
	header.add_child(index_label)
	var kicker := Label.new()
	kicker.name = "MainMenuCommandKicker"
	kicker.text = _command_kicker_text(raw_kicker)
	kicker.tooltip_text = panel.tooltip_text
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.add_theme_font_size_override("font_size", 10)
	kicker.add_theme_color_override("font_color", accent.lightened(0.20))
	header.add_child(kicker)
	var button := _action_button(entry, accent, true)
	button.custom_minimum_size = Vector2(0, 56 if featured else 46)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(button)
	var meta := Label.new()
	meta.name = "MainMenuCommandDetail"
	meta.text = str(entry.get("detail", ""))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_theme_font_size_override("font_size", 12 if featured else 11)
	meta.add_theme_color_override("font_color", Color("#cbd5e1"))
	box.add_child(meta)


func _command_index_text(kicker: String, fallback_index: int) -> String:
	var parts := kicker.split("｜", false, 1)
	if parts.size() > 1 and str(parts[0]).strip_edges() != "":
		return str(parts[0]).strip_edges()
	return "%02d" % fallback_index


func _command_kicker_text(kicker: String) -> String:
	var parts := kicker.split("｜", false, 1)
	if parts.size() > 1 and str(parts[1]).strip_edges() != "":
		return str(parts[1]).strip_edges()
	return kicker


func _add_utility_button(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#93c5fd"))
	var button := _action_button(entry, accent, false)
	button.name = "MainMenuUtilityButton"
	button.custom_minimum_size = Vector2(124, 32)
	utility_rail.add_child(button)


func _action_button(entry: Dictionary, accent: Color, primary: bool) -> Button:
	var button := Button.new()
	var action_id := str(entry.get("id", ""))
	button.text = str(entry.get("label", action_id))
	button.tooltip_text = str(entry.get("tooltip", entry.get("detail", button.text)))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if primary else Control.SIZE_SHRINK_BEGIN
	button.disabled = bool(entry.get("disabled", false))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(button, accent, primary and not button.disabled)
	if action_id != "":
		_buttons_by_id[action_id] = button
		if action_id == "rules":
			button.pressed.connect(_emit_rules)
		elif action_id == "compendium":
			button.pressed.connect(_emit_compendium)
		else:
			button.pressed.connect(_emit_action.bind(action_id))
	return button


func _add_chip(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#94a3b8"))
	var chip := PanelContainer.new()
	chip.name = "MainMenuLobbyChip"
	chip.custom_minimum_size = Vector2(168, 30)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.14), 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(10, 4, 10, 4)
	chip.add_child(margin)
	var label := Label.new()
	label.text = str(entry.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.tooltip_text = chip.tooltip_text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", accent.lightened(0.16))
	margin.add_child(label)


func _emit_action(action_id: String) -> void:
	action_requested.emit(action_id)


func _emit_rules() -> void:
	rules_requested.emit()


func _emit_compendium() -> void:
	compendium_requested.emit()


func _style_button(button: Button, accent: Color, active: bool) -> void:
	var fill := Color("#0b1220").lerp(accent, 0.18 if active else 0.08)
	button.add_theme_stylebox_override("normal", _card_style(accent, fill, 1, 6))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.15), fill.lightened(0.10), 1, 6))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.25), fill.darkened(0.08), 1, 6))
	button.add_theme_stylebox_override("disabled", _card_style(Color("#475569"), Color("#0f172a"), 1, 6))
	button.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#cbd5e1"))
	button.add_theme_color_override("font_disabled_color", Color("#64748b"))
	button.add_theme_font_size_override("font_size", 15 if active else 12)


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


func _command_card_style(accent: Color, featured: bool, hover: bool) -> StyleBoxFlat:
	var fill := Color("#07111f").lerp(accent, 0.18 if featured else 0.11)
	if hover:
		fill = fill.lightened(0.08)
	var style := _card_style(accent.lightened(0.08 if featured else 0.0), fill, 1, MAIN_MENU_COMMAND_RADIUS)
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _lobby_panel_style(accent: Color) -> StyleBoxFlat:
	var style := _card_style(accent.darkened(0.20), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _planet_panel_style(accent: Color) -> StyleBoxFlat:
	var style := _card_style(accent.lightened(0.08), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
