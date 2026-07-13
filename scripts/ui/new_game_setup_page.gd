extends PanelContainer
class_name SpaceSyndicateNewGameSetupPage

const SeatCardScene := preload("res://scenes/ui/NewGameSetupSeatCard.tscn")

signal action_requested(action_id: String)

@onready var summary_chip_rail: HFlowContainer = %NewGameSetupSummaryChipRail
@onready var lobby: Control = %NewGameSetupLobbyPanel
@onready var option_board: Control = %NewGameSetupOptionBoard
@onready var seat_title: Label = %NewGameSetupSeatTitle
@onready var seat_scroll: ScrollContainer = %NewGameSetupSeatScroll
@onready var seat_grid: GridContainer = %NewGameSetupSeatGrid
@onready var hint_label: Label = %NewGameSetupHintLabel
@onready var recommended_button: Button = %FirstRunRecommendedSetupButton
@onready var start_button: Button = %NewGameSetupStartButton
@onready var back_button: Button = %NewGameSetupBackButton
@onready var return_table_button: Button = %NewGameSetupReturnTableButton


func _ready() -> void:
	set_meta("new_game_setup_page", true)
	if option_board.has_signal("option_selected"):
		option_board.connect("option_selected", _on_option_selected)
	recommended_button.pressed.connect(_emit_action.bind("setup_recommended"))
	start_button.pressed.connect(_emit_action.bind("setup_start"))
	back_button.pressed.connect(_emit_action.bind("setup_back"))
	return_table_button.pressed.connect(_emit_action.bind("setup_return_table"))
	_style_button(recommended_button, Color("#facc15"), true)
	_style_button(start_button, Color("#22c55e"), true)
	_style_button(back_button, Color("#38bdf8"), false)
	_style_button(return_table_button, Color("#22c55e"), false)
	set_page({})


func set_page(data: Dictionary) -> void:
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", "开局准备：确认席位、AI、挑战、公开角色和独立首召怪兽。"))
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.04), 1, 8))
	_render_summary_chips(data.get("summary_chips", []))
	var lobby_snapshot: Variant = data.get("lobby", {})
	if lobby_snapshot is Dictionary and lobby.has_method("set_lobby"):
		lobby.call("set_lobby", lobby_snapshot)
	var option_snapshot: Variant = data.get("options", {})
	if option_snapshot is Dictionary and option_board.has_method("set_options"):
		option_board.call("set_options", option_snapshot)
	seat_title.text = str(data.get("seat_title", "座位卡｜公开角色 + 独立首召怪兽"))
	seat_grid.columns = clampi(int(data.get("seat_columns", 1)), 1, 2)
	seat_scroll.custom_minimum_size.y = maxf(260.0, float(data.get("seat_scroll_height", 360.0)))
	_render_seats(data.get("seats", []))
	hint_label.text = str(data.get("hint", "角色公开；首召匿名。先进桌召怪兽，再围绕怪兽附近买牌。"))
	return_table_button.visible = bool(data.get("can_return_table", false))
	start_button.disabled = bool(data.get("start_disabled", false))
	start_button.tooltip_text = str(data.get("start_tooltip", "按当前配置开始本局。"))


func _render_summary_chips(entries_variant: Variant) -> void:
	_clear_children(summary_chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_summary_chip(entry_variant as Dictionary)


func _render_seats(entries_variant: Variant) -> void:
	_clear_children(seat_grid)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_seat(entry_variant as Dictionary)


func _add_summary_chip(entry: Dictionary) -> void:
	var text := str(entry.get("text", "")).strip_edges()
	if text == "":
		return
	var accent := _dictionary_color(entry, "accent", Color("#bfdbfe"))
	var fill := _dictionary_color(entry, "fill", Color("#0f172a"))
	var chip := PanelContainer.new()
	chip.name = "NewGameSetupSummaryChip"
	chip.tooltip_text = str(entry.get("tooltip", text))
	chip.set_meta("setup_summary_chips", true)
	chip.add_theme_stylebox_override("panel", _card_style(accent, fill, 1, 8))
	summary_chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := Label.new()
	label.name = "NewGameSetupSummaryChipLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", accent.lightened(0.16))
	margin.add_child(label)


func _add_seat(entry: Dictionary) -> void:
	var seat := SeatCardScene.instantiate() as Control
	if seat == null:
		return
	seat.name = "NewGameSetupSeatCard"
	if seat.has_signal("role_step_requested"):
		seat.connect("role_step_requested", _on_role_step_requested)
	if seat.has_signal("role_random_requested"):
		seat.connect("role_random_requested", _on_role_random_requested)
	if seat.has_signal("monster_step_requested"):
		seat.connect("monster_step_requested", _on_monster_step_requested)
	seat_grid.add_child(seat)
	if seat.has_method("set_seat"):
		seat.call("set_seat", entry)


func _on_option_selected(option_id: String, value: int) -> void:
	match option_id:
		"player_count", "ai_count", "challenge_depth":
			action_requested.emit("setup_%s_%d" % [option_id, value])


func _on_role_step_requested(player_index: int, step: int) -> void:
	action_requested.emit("setup_role_step_%d_%d" % [player_index, step])


func _on_role_random_requested(player_index: int) -> void:
	action_requested.emit("setup_role_random_%d" % player_index)


func _on_monster_step_requested(player_index: int, step: int) -> void:
	action_requested.emit("setup_monster_step_%d_%d" % [player_index, step])


func _emit_action(action_id: String) -> void:
	if action_id.strip_edges() != "":
		action_requested.emit(action_id)


func _style_button(button: Button, accent: Color, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 11 if primary else 10)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_stylebox_override("normal", _card_style(accent, Color("#020617").lerp(accent, 0.24 if primary else 0.14), 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.34), 1, 8))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.42), 1, 8))


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _dictionary_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = data.get(key, fallback)
	return value as Color if value is Color else fallback


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
