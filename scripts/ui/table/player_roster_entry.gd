@tool
extends Button
class_name SpaceSyndicatePlayerRosterEntry

signal player_inspection_requested(player_id: String)

@onready var accent_strip: ColorRect = %AccentStrip
@onready var avatar_panel: PanelContainer = $EntryMargin/EntryRow/AvatarPanel
@onready var avatar_glyph: Label = %AvatarGlyph
@onready var display_name_label: Label = %DisplayName
@onready var role_status_label: Label = %RoleStatus
@onready var badges: VBoxContainer = $EntryMargin/EntryRow/Badges
@onready var local_badge: Label = %LocalBadge
@onready var state_badge: Label = %StateBadge

var _player: Dictionary = {}
var _row_signature := ""
var _inspected := false
var _update_count := 0
var _activation_count := 0
var _last_input_kind := "none"
var _compact_mode := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)
	gui_input.connect(_record_input_kind)
	_refresh_style()


func apply_player(row: Dictionary) -> bool:
	var next_signature := _player_signature(row)
	if next_signature.is_empty():
		return false
	if next_signature == _row_signature:
		return true
	_player = row.duplicate(true)
	_row_signature = next_signature
	_inspected = bool(_player.get("is_inspected", false))
	_update_count += 1
	_render_player()
	return true


func player_id() -> String:
	return str(_player.get("player_id", ""))


func public_order_index() -> int:
	return int(_player.get("public_order_index", -1))


func set_inspected_visual(value: bool) -> void:
	if _inspected == value:
		return
	_inspected = value
	_render_state_badge()
	_refresh_style()


func set_compact_mode(value: bool) -> void:
	if _compact_mode == value and is_node_ready():
		return
	_compact_mode = value
	custom_minimum_size = Vector2(80, 54) if _compact_mode else Vector2(168, 58)
	if not is_node_ready():
		return
	avatar_panel.custom_minimum_size = Vector2(24, 24) if _compact_mode else Vector2(32, 32)
	avatar_glyph.add_theme_font_size_override("font_size", 12 if _compact_mode else 15)
	display_name_label.add_theme_font_size_override("font_size", 10 if _compact_mode else 12)
	role_status_label.add_theme_font_size_override("font_size", 7 if _compact_mode else 9)
	local_badge.add_theme_font_size_override("font_size", 8 if _compact_mode else 9)
	state_badge.add_theme_font_size_override("font_size", 8 if _compact_mode else 9)
	badges.custom_minimum_size.x = 10 if _compact_mode else 26
	_render_player()


func focus_for_accessibility() -> void:
	grab_focus()


func debug_snapshot() -> Dictionary:
	return {
		"player_id": player_id(),
		"public_order_index": public_order_index(),
		"is_local_player": bool(_player.get("is_local_player", false)),
		"is_eliminated": bool(_player.get("is_eliminated", false)),
		"is_inspected": _inspected,
		"submission_lock_public_state": str(
			_player.get("submission_lock_public_state", "")
		),
		"row_signature": _row_signature,
		"update_count": _update_count,
		"activation_count": _activation_count,
		"last_input_kind": _last_input_kind,
		"compact_mode": _compact_mode,
		"minimum_width": custom_minimum_size.x,
		"rendered_width": size.x,
		"focus_mode_all": focus_mode == Control.FOCUS_ALL,
		"direct_gameplay_mutation_count": 0,
		"rng_draw_count": 0,
		"private_fact_read_count": 0,
	}


func _render_player() -> void:
	var display_name := str(_player.get("display_name", ""))
	var role_name := str(_player.get("role_display_name", ""))
	var public_status := str(_player.get("public_status", ""))
	var accent := _accent_color(str(_player.get("accent", "")))
	display_name_label.text = display_name
	role_status_label.text = "%s·%s" % [
		role_name,
		_status_short_label(public_status) if _compact_mode else _status_label(public_status),
	]
	avatar_glyph.text = display_name.substr(0, 1) if not display_name.is_empty() else "?"
	avatar_glyph.tooltip_text = str(_player.get("avatar_key", ""))
	accent_strip.color = accent
	local_badge.visible = bool(_player.get("is_local_player", false))
	local_badge.text = "我" if _compact_mode else "本地"
	_render_state_badge()
	tooltip_text = "%s｜%s｜%s%s" % [
		display_name,
		role_name,
		_status_label(public_status),
		"｜本地玩家" if bool(_player.get("is_local_player", false)) else "",
	]
	_set_accessibility_name("%s，%s，%s" % [
		display_name,
		role_name,
		_status_label(public_status),
	])
	_refresh_style()


func _render_state_badge() -> void:
	if state_badge == null:
		return
	if bool(_player.get("is_eliminated", false)):
		state_badge.text = "离" if _compact_mode else "已离场"
		state_badge.add_theme_color_override("font_color", Color("#fda4af"))
	elif _inspected:
		state_badge.text = "查" if _compact_mode else "查看中"
		state_badge.add_theme_color_override("font_color", Color("#67e8f9"))
	else:
		var lock_state := str(_player.get("submission_lock_public_state", ""))
		state_badge.text = _lock_short_label(lock_state) if _compact_mode \
			else _lock_label(lock_state)
		state_badge.add_theme_color_override("font_color", Color("#94a3b8"))


func _refresh_style() -> void:
	if not is_node_ready():
		return
	var accent := _accent_color(str(_player.get("accent", "")))
	var eliminated := bool(_player.get("is_eliminated", false))
	add_theme_stylebox_override("normal", _style(accent, _inspected, eliminated, false))
	add_theme_stylebox_override("hover", _style(accent, true, eliminated, false))
	add_theme_stylebox_override("pressed", _style(accent, true, eliminated, true))
	add_theme_stylebox_override("focus", _style(accent, true, eliminated, false))
	modulate = Color(1.0, 1.0, 1.0, 0.64 if eliminated else 1.0)


func _style(accent: Color, highlighted: bool, eliminated: bool, pressed_state: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var strength := 0.07
	if highlighted:
		strength = 0.16
	if pressed_state:
		strength = 0.23
	style.bg_color = Color("#06101f").lerp(accent, strength)
	style.border_color = Color("#334155") if eliminated else (
		accent.lightened(0.18) if highlighted else Color("#334155").lerp(accent, 0.38)
	)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(7)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 2.0 if _compact_mode else 4.0)
	return style


func _on_pressed() -> void:
	var identity := player_id()
	if identity.is_empty():
		return
	_activation_count += 1
	player_inspection_requested.emit(identity)


func _record_input_kind(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_last_input_kind = "mouse"
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_last_input_kind = "gamepad"
	elif event is InputEventAction and (event as InputEventAction).pressed:
		_last_input_kind = "gamepad"
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_last_input_kind = "keyboard"


func _player_signature(row: Dictionary) -> String:
	var canonical := JSON.stringify(row, "", true, true)
	return canonical.sha256_text() if not canonical.is_empty() else ""


func _status_label(status: String) -> String:
	return {
		"active": "行动中",
		"ready": "已就绪",
		"waiting": "等待中",
		"eliminated": "已离场",
		"disconnected": "已断开",
	}.get(status, status.replace("_", " "))


func _status_short_label(status: String) -> String:
	return {
		"active": "行",
		"ready": "备",
		"waiting": "候",
		"eliminated": "离",
		"disconnected": "断",
	}.get(status, "态")


func _lock_label(state: String) -> String:
	return {
		"unlocked": "可行动",
		"locked": "已锁定",
		"submitted": "已提交",
		"waiting": "等待中",
	}.get(state, state.replace("_", " "))


func _lock_short_label(state: String) -> String:
	return {
		"unlocked": "行",
		"locked": "锁",
		"submitted": "交",
		"waiting": "候",
	}.get(state, "态")


func _accent_color(value: String) -> Color:
	var normalized := value.strip_edges()
	if Color.html_is_valid(normalized):
		return Color(normalized)
	return {
		"cyan": Color("#22d3ee"),
		"blue": Color("#60a5fa"),
		"violet": Color("#a78bfa"),
		"amber": Color("#fbbf24"),
		"rose": Color("#fb7185"),
		"emerald": Color("#34d399"),
	}.get(normalized.to_lower(), Color("#94a3b8"))


func _set_accessibility_name(value: String) -> void:
	for property in get_property_list():
		if property.get("name", "") == "accessibility_name":
			set("accessibility_name", value)
			return
