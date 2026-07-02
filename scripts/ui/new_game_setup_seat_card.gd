extends PanelContainer
class_name SpaceSyndicateNewGameSetupSeatCard

const CardFaceScene := preload("res://scenes/ui/CardFace.tscn")

signal role_step_requested(player_index: int, step: int)
signal role_random_requested(player_index: int)
signal monster_step_requested(player_index: int, step: int)

@onready var chip_rail: HFlowContainer = %NewGameSetupSeatChipRail
@onready var identity_board: Control = %NewGameSetupSeatIdentityBoard
@onready var passive_label: Label = %NewGameSetupSeatPassiveLabel
@onready var previous_role_button: Button = %NewGameSetupPreviousRoleButton
@onready var role_name_label: Label = %NewGameSetupRoleNameLabel
@onready var next_role_button: Button = %NewGameSetupNextRoleButton
@onready var random_role_button: Button = %NewGameSetupRandomRoleButton
@onready var previous_monster_button: Button = %NewGameSetupPreviousMonsterButton
@onready var monster_name_label: Label = %NewGameSetupMonsterNameLabel
@onready var next_monster_button: Button = %NewGameSetupNextMonsterButton
@onready var card_host: HBoxContainer = %NewGameSetupSeatCardHost
@onready var starter_note_label: Label = %NewGameSetupSeatStarterNote

var _player_index := 0


func _ready() -> void:
	previous_role_button.pressed.connect(_on_previous_role_pressed)
	next_role_button.pressed.connect(_on_next_role_pressed)
	random_role_button.pressed.connect(_on_random_role_pressed)
	previous_monster_button.pressed.connect(_on_previous_monster_pressed)
	next_monster_button.pressed.connect(_on_next_monster_pressed)
	_style_button(previous_role_button, Color("#c084fc"))
	_style_button(next_role_button, Color("#c084fc"))
	_style_button(random_role_button, Color("#a78bfa"))
	_style_button(previous_monster_button, Color("#fb7185"))
	_style_button(next_monster_button, Color("#fb7185"))
	set_seat({})


func set_seat(data: Dictionary) -> void:
	_player_index = int(data.get("player_index", _player_index))
	var accent := _dictionary_color(data, "accent", Color("#38bdf8"))
	tooltip_text = str(data.get("tooltip", "座位卡：公开角色 + 匿名首召怪兽。"))
	set_meta("setup_seat_card", true)
	add_theme_stylebox_override("panel", _card_style(accent, Color("#020617").lerp(accent, 0.10), 1, 8))
	_render_chips(data.get("chips", []))
	var identity_data: Variant = data.get("identity", {})
	if identity_data is Dictionary and identity_board.has_method("set_identity"):
		identity_board.call("set_identity", identity_data)
	passive_label.text = str(data.get("passive_text", "角色被动：待选择"))
	passive_label.tooltip_text = str(data.get("passive_tooltip", passive_label.text))
	role_name_label.text = "当前：%s" % str(data.get("role_label", "外星辛迪加"))
	random_role_button.visible = bool(data.get("show_random_role", false))
	random_role_button.button_pressed = bool(data.get("role_random", false))
	monster_name_label.text = "起始怪兽：%s" % str(data.get("monster_label", "怪兽"))
	starter_note_label.text = str(data.get("starter_note", ""))
	starter_note_label.tooltip_text = starter_note_label.text
	_render_card_faces(data.get("card_faces", []))


func _render_chips(entries_variant: Variant) -> void:
	_clear_children(chip_rail)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_chip(entry_variant as Dictionary)


func _render_card_faces(entries_variant: Variant) -> void:
	_clear_children(card_host)
	if not (entries_variant is Array):
		return
	for entry_variant in entries_variant:
		if entry_variant is Dictionary:
			_add_card_face(entry_variant as Dictionary)


func _add_card_face(entry: Dictionary) -> void:
	var face := CardFaceScene.instantiate() as Control
	if face == null:
		return
	face.name = "NewGameSetupSeatSceneCardFace"
	face.custom_minimum_size = Vector2(
		float(entry.get("minimum_width", 150.0)),
		float(entry.get("minimum_height", 180.0))
	)
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_host.add_child(face)
	if face.has_method("set_card_data"):
		face.call("set_card_data", entry)


func _add_chip(entry: Dictionary) -> void:
	var accent := _dictionary_color(entry, "accent", Color("#e0f2fe"))
	var fill := _dictionary_color(entry, "fill", Color("#0f172a"))
	var chip := PanelContainer.new()
	chip.name = "NewGameSetupSeatChip"
	chip.custom_minimum_size = Vector2(46, 18)
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.set_meta("setup_seat_chips", true)
	chip.add_theme_stylebox_override("panel", _card_style(accent, fill, 1, 8))
	chip_rail.add_child(chip)
	var margin := _margin(7, 2, 7, 2)
	chip.add_child(margin)
	var label := Label.new()
	label.name = "NewGameSetupSeatChipLabel"
	label.custom_minimum_size = Vector2(32, 0)
	label.text = str(entry.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.tooltip_text = chip.tooltip_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", accent.lightened(0.18))
	margin.add_child(label)


func _style_button(button: Button, accent: Color) -> void:
	button.tooltip_text = button.tooltip_text if not button.tooltip_text.is_empty() else button.text
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#f8fafc"))
	button.add_theme_stylebox_override("normal", _card_style(accent.darkened(0.1), Color("#020617").lerp(accent, 0.20), 1, 8))
	button.add_theme_stylebox_override("hover", _card_style(accent.lightened(0.18), Color("#020617").lerp(accent, 0.30), 1, 8))
	button.add_theme_stylebox_override("pressed", _card_style(accent.lightened(0.28), Color("#020617").lerp(accent, 0.38), 1, 8))


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


func _on_previous_role_pressed() -> void:
	role_step_requested.emit(_player_index, -1)


func _on_next_role_pressed() -> void:
	role_step_requested.emit(_player_index, 1)


func _on_random_role_pressed() -> void:
	role_random_requested.emit(_player_index)


func _on_previous_monster_pressed() -> void:
	monster_step_requested.emit(_player_index, -1)


func _on_next_monster_pressed() -> void:
	monster_step_requested.emit(_player_index, 1)
