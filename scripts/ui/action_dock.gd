extends PanelContainer
class_name SpaceSyndicateActionDock

signal action_requested(action_id: String)

@onready var title_label: Label = %ActionTitle
@onready var quick_action_row: HFlowContainer = %ActionDockQuickActionRow
@onready var action_row: HFlowContainer = %ActionRow

var quick_actions_signature: String = ""
var actions_signature: String = ""
var compact_mode := false
var dense_mode := false


func _ready() -> void:
	add_theme_stylebox_override("panel", _dock_panel_style())


func set_compact_mode(enabled: bool) -> void:
	compact_mode = enabled
	dense_mode = false if enabled else dense_mode
	if title_label != null:
		title_label.visible = not compact_mode
	if quick_action_row != null:
		quick_action_row.custom_minimum_size = Vector2(0, 34 if compact_mode else 34)
	custom_minimum_size = Vector2(280, 84) if compact_mode else Vector2(280, 38)


func set_dense_mode(enabled: bool) -> void:
	dense_mode = enabled
	if enabled:
		compact_mode = false
	if title_label != null:
		title_label.visible = not dense_mode and not compact_mode
	if quick_action_row != null:
		quick_action_row.visible = false if dense_mode else quick_action_row.visible
		quick_action_row.custom_minimum_size = Vector2.ZERO if dense_mode else Vector2(0, 34)
	custom_minimum_size = Vector2(280, 42) if dense_mode else (Vector2(280, 84) if compact_mode else Vector2(280, 38))


func set_dock(data: Dictionary) -> void:
	var quick_actions: Array = data.get("quick_actions", []) if data.get("quick_actions", []) is Array else []
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	set_quick_actions(quick_actions)
	set_actions(actions)


func set_quick_actions(actions: Array) -> void:
	var next_signature := var_to_str(actions)
	if next_signature == quick_actions_signature:
		return
	quick_actions_signature = next_signature
	quick_action_row.visible = true
	_clear_row(quick_action_row)
	if actions.is_empty():
		_add_quick_action_button("rack", "牌架", "未选", false, "先选择区域查看发展牌架。", "1")
		_add_quick_action_button("buy", "买牌", "--", false, "进入可购买窗口后再买牌。", "2")
		_add_quick_action_button("play", "出牌", "--", false, "当前没有可直接打出的手牌。", "3")
		return
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		var active := bool(action.get("active", not bool(action.get("disabled", false))))
		var action_id := str(action.get("id", action.get("label", "action")))
		_add_quick_action_button(
			action_id,
			_player_action_label(action, "快捷操作", "quick action"),
			str(action.get("state", "ready" if active else "waiting")),
			active,
			str(action.get("tooltip", "")),
			str(action.get("shortcut", action.get("hotkey", "")))
		)


func set_actions(actions: Array) -> void:
	var next_signature := var_to_str(actions)
	if next_signature == actions_signature:
		return
	actions_signature = next_signature
	_clear_row(action_row)
	if actions.is_empty():
		_add_action_button("none", "暂无行动", true, "选择区域或手牌后显示当前行动。")
		return
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		var action_id := str(action.get("id", action.get("label", "")))
		_add_action_button(
			action_id,
			_player_action_label(action, "执行操作", "action"),
			bool(action.get("disabled", false)),
			str(action.get("tooltip", ""))
		)


func _player_action_label(action: Dictionary, safe_fallback: String, context: String) -> String:
	var player_label := str(action.get("label", "")).strip_edges()
	if player_label != "":
		return player_label
	var action_id := str(action.get("id", "")).strip_edges()
	push_warning("ActionDock %s '%s' is missing a localized player label; using '%s'." % [context, action_id if action_id != "" else "<missing-id>", safe_fallback])
	return safe_fallback


func _clear_row(row: Container) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _add_quick_action_button(action_id: String, label_text: String, state_text: String, active: bool, tooltip: String, shortcut_text: String = "") -> void:
	var button := Button.new()
	button.name = "MainActionDockButton"
	var shortcut := _short_text(shortcut_text.strip_edges(), 3)
	var label_limit := 5 if shortcut != "" else 6
	var label_prefix := "%s " % shortcut if shortcut != "" else ""
	button.text = "%s%s\n%s" % [label_prefix, _short_text(label_text, label_limit), _quick_action_state_text(state_text)]
	button.disabled = not active
	button.tooltip_text = _quick_action_tooltip(tooltip, shortcut)
	button.set_meta("quick_action_id", action_id)
	button.set_meta("quick_action_shortcut", shortcut)
	button.custom_minimum_size = Vector2(60 if compact_mode else 64, 34 if compact_mode else 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _quick_action_style(active, action_id))
	button.add_theme_stylebox_override("hover", _quick_action_style(true, action_id))
	button.add_theme_stylebox_override("pressed", _quick_action_style(true, action_id))
	button.add_theme_stylebox_override("disabled", _quick_action_style(false, action_id))
	button.add_theme_color_override("font_color", _action_accent(action_id).lightened(0.28) if active else Color("#cbd5e1"))
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(func() -> void:
		action_requested.emit(action_id)
	)
	quick_action_row.add_child(button)


func _quick_action_tooltip(tooltip: String, shortcut: String) -> String:
	var text := tooltip.strip_edges()
	if shortcut == "":
		return text
	var prefix := "快捷键 %s" % shortcut
	if text == "":
		return prefix
	return "%s｜%s" % [prefix, text]


func _add_action_button(action_id: String, label_text: String, disabled: bool, tooltip: String) -> void:
	var button := Button.new()
	button.name = "PlayerActionButton"
	button.text = _short_text(label_text, 12 if dense_mode else 16)
	button.disabled = disabled
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 26 if dense_mode else (34 if compact_mode else 30))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _primary_action_style(disabled))
	button.add_theme_stylebox_override("hover", _primary_action_style(false))
	button.add_theme_stylebox_override("pressed", _primary_action_style(false))
	button.add_theme_stylebox_override("disabled", _primary_action_style(true))
	button.add_theme_color_override("font_color", Color("#f8fafc") if not disabled else Color("#94a3b8"))
	button.add_theme_font_size_override("font_size", 10 if dense_mode else (12 if compact_mode else 11))
	button.pressed.connect(func() -> void:
		action_requested.emit(action_id)
	)
	action_row.add_child(button)


func _quick_action_state_text(value: String) -> String:
	var text := value.strip_edges()
	var normalized := text.to_lower()
	match normalized:
		"ready":
			return "就绪"
		"blocked", "locked", "waiting", "select", "empty":
			return "--"
		"browse":
			return "可看"
	return _short_text(text, 5)


func _quick_action_style(active: bool, action_id: String) -> StyleBoxFlat:
	var accent := _action_accent(action_id)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.30 if active else 0.12)
	style.border_color = accent if active else Color("#475569").lerp(accent, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 5.0)
	style.set_content_margin(SIDE_RIGHT, 5.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _primary_action_style(disabled: bool) -> StyleBoxFlat:
	var accent := Color("#60a5fa") if disabled else Color("#93c5fd")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1e293b") if disabled else Color("#334155")
	style.border_color = Color("#64748b") if disabled else accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 5.0)
	style.set_content_margin(SIDE_BOTTOM, 5.0)
	return style


func _dock_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(Color("#22c55e"), 0.07)
	style.border_color = Color("#334155").lerp(Color("#22c55e"), 0.38)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 6.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	return style


func _action_accent(action_id: String) -> Color:
	var normalized := action_id.to_lower()
	if normalized.contains("build") or normalized.contains("city") or normalized.contains("建"):
		return Color("#22c55e")
	if normalized.contains("rack") or normalized.contains("market") or normalized.contains("牌架"):
		return Color("#38bdf8")
	if normalized.contains("buy") or normalized.contains("purchase") or normalized.contains("买"):
		return Color("#facc15")
	if normalized.contains("play") or normalized.contains("card") or normalized.contains("出"):
		return Color("#c084fc")
	return Color("#94a3b8")


func _short_text(value: String, limit: int) -> String:
	if value.length() <= limit:
		return value
	return "%s…" % value.left(maxi(1, limit - 1))
