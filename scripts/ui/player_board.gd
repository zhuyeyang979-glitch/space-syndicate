extends PanelContainer
class_name SpaceSyndicatePlayerBoard

signal card_selected(card_data: Dictionary)
signal card_hovered(card_data: Dictionary)
signal card_unhovered
signal card_unselected(card_data: Dictionary)
signal card_drag_preview_started(card_data: Dictionary, screen_position: Vector2)
signal card_drag_preview_moved(card_data: Dictionary, screen_position: Vector2)
signal card_drag_preview_ended(card_data: Dictionary)
signal card_drag_released(card_data: Dictionary, screen_position: Vector2)
signal action_requested(action_id: String)
signal application_intent_requested(intent: IntelApplicationIntent)
signal player_inspection_requested(player_index: int)

@onready var title_label: Label = %PlayerBoardTitle
@onready var identity_chip: Label = %PlayerIdentityChip
@onready var cash_chip: Label = %PlayerCashChip
@onready var gdp_chip: Label = %PlayerGdpChip
@onready var goal_chip: Label = %PlayerGoalChip
@onready var selected_district_chip: Label = %PlayerSelectedDistrictChip
@onready var primary_action_chip: Label = %PlayerPrimaryActionChip
@onready var progress_path_rail: Container = %PlayerProgressPathRail
@onready var hand_count_chip: Label = %PlayerHandCountChip
@onready var goal_bar: ProgressBar = %PlayerGoalBar
@onready var hand_rack: Control = %HandRack
@onready var action_hint_label: Label = %PlayerActionHint
@onready var main_action_dock: SpaceSyndicateActionDock = %PlayerMainActionDock
@onready var status_lamp_row: Container = %PlayerStatusLampRow
@onready var readiness_chip_row: Container = %PlayerReadinessChipRow
@onready var resource_tableau: PanelContainer = %PlayerResourceTableau
@onready var hand_tableau: PanelContainer = %PlayerHandTableau
@onready var command_tableau: PanelContainer = %PlayerCommandTableau

var hand_cards_signature: String = ""
var status_lamps_signature: String = ""
var readiness_chips_signature: String = ""
var progress_path_signature: String = ""
var runtime_feedback: Dictionary = {}
var _public_player_index := -1
var _owner_identity_text := "未入席"
var _inspected_public_player: Dictionary = {}


func _ready() -> void:
	_configure_pointer_filter_skeleton()
	_configure_chip_defaults()
	_configure_tableau_styles()
	identity_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	identity_chip.focus_mode = Control.FOCUS_ALL
	identity_chip.gui_input.connect(_on_identity_chip_gui_input)
	if hand_rack != null and hand_rack.has_signal("card_hovered"):
		hand_rack.connect("card_hovered", Callable(self, "_on_card_hovered"))
	if hand_rack != null and hand_rack.has_signal("card_unhovered"):
		hand_rack.connect("card_unhovered", Callable(self, "_on_card_unhovered"))
	if hand_rack != null and hand_rack.has_signal("card_unselected"):
		hand_rack.connect("card_unselected", Callable(self, "_on_card_unselected"))
	if hand_rack != null and hand_rack.has_signal("card_selected"):
		hand_rack.connect("card_selected", Callable(self, "_on_card_clicked"))
	if hand_rack != null and hand_rack.has_signal("card_double_selected"):
		hand_rack.connect("card_double_selected", Callable(self, "_on_card_double_clicked"))
	if hand_rack != null and hand_rack.has_signal("card_drag_preview_started"):
		hand_rack.connect("card_drag_preview_started", Callable(self, "_on_card_drag_preview_started"))
	if hand_rack != null and hand_rack.has_signal("card_drag_preview_moved"):
		hand_rack.connect("card_drag_preview_moved", Callable(self, "_on_card_drag_preview_moved"))
	if hand_rack != null and hand_rack.has_signal("card_drag_preview_ended"):
		hand_rack.connect("card_drag_preview_ended", Callable(self, "_on_card_drag_preview_ended"))
	if hand_rack != null and hand_rack.has_signal("card_drag_released"):
		hand_rack.connect("card_drag_released", Callable(self, "_on_card_drag_released"))
	if main_action_dock != null:
		main_action_dock.set_compact_mode(true)
		main_action_dock.action_requested.connect(_on_action_requested)
		main_action_dock.application_intent_requested.connect(_on_application_intent_requested)


func _configure_pointer_filter_skeleton() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	for path in [
		"PlayerRows",
		"PlayerRows/PlayerBoardTitle",
		"PlayerRows/PlayerActionHint",
		"PlayerRows/PlayerBoardBody",
		"PlayerRows/PlayerBoardBody/PlayerResourceTableau",
		"PlayerRows/PlayerBoardBody/PlayerResourceTableau/PlayerResourceRows",
		"PlayerRows/PlayerBoardBody/PlayerHandTableau",
		"PlayerRows/PlayerBoardBody/PlayerHandTableau/PlayerHandRows",
		"PlayerRows/PlayerBoardBody/PlayerHandTableau/PlayerHandRows/PlayerHandHeader",
		"PlayerRows/PlayerBoardBody/PlayerHandTableau/PlayerHandRows/HandRackColumn",
		"PlayerRows/PlayerBoardBody/PlayerCommandTableau",
		"PlayerRows/PlayerBoardBody/PlayerCommandTableau/PlayerCommandRows",
	]:
		var node := get_node_or_null(path)
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if resource_tableau != null:
		resource_tableau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hand_tableau != null:
		hand_tableau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if command_tableau != null:
		command_tableau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hand_rack != null:
		hand_rack.mouse_filter = Control.MOUSE_FILTER_STOP


func set_player_state(data: Dictionary) -> void:
	title_label.text = str(data.get("title", "玩家板｜手牌"))
	action_hint_label.text = str(data.get("hint", "选择手牌或选区，右侧会解释能做什么。"))
	action_hint_label.tooltip_text = action_hint_label.text
	action_hint_label.remove_theme_color_override("font_color")
	runtime_feedback = {}
	set_meta("runtime_feedback", {})
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	var primary_action := _first_text(data, ["primary_action", "primary_action_label", "next_action"], _first_action_label(actions))
	var identity_text := _first_text(data, ["identity", "player", "seat"], "未入席")
	_owner_identity_text = identity_text
	var cash_text := _first_text(data, ["cash_text", "cash", "money"], "¥ --")
	var gdp_text := _first_text(data, ["gdp_text", "gdp"], "--/min")
	var goal_text := _first_text(data, ["goal_text", "goal", "target"], "--")
	var selected_text := _first_text(data, ["selected_district_summary", "selected_district", "selected_region"], "未选区")
	var quick_actions: Array = data.get("quick_actions", data.get("action_summary", [])) if data.get("quick_actions", data.get("action_summary", [])) is Array else []
	var status_lamps: Array = _first_array(data, ["table_state_lamps", "status_lamps", "table_lamps"])
	var readiness_chips: Array = _first_array(data, ["readiness_chips", "action_readiness", "readiness"])
	var progress_path: Array = _first_array(data, ["progress_path", "runtime_path", "path_steps"])
	_set_chip(identity_chip, "本席", identity_text, 118, 14)
	_set_chip(cash_chip, "现金", cash_text, 92, 12)
	_set_chip(gdp_chip, "GDP", gdp_text, 92, 12)
	_set_chip(goal_chip, "目标", goal_text, 108, 14)
	_set_chip(selected_district_chip, "选区", selected_text, 128, 14)
	_set_chip(primary_action_chip, "下一步", primary_action, 122, 14)
	goal_bar.value = clampf(float(data.get("goal_ratio", 0.0)) * 100.0, 0.0, 100.0)
	_set_main_action_dock(quick_actions, actions)
	_set_status_lamps(status_lamps)
	_set_readiness_chips(readiness_chips)
	_set_progress_path(progress_path)
	var cards_variant: Variant = data.get("hand_cards", [])
	var hand_cards: Array = cards_variant if cards_variant is Array else []
	var hand_limit := int(data.get("hand_limit", data.get("max_hand_size", 5)))
	_set_chip(hand_count_chip, "手牌", "%d/%d" % [hand_cards.size(), maxi(1, hand_limit)], 92, 12)
	var next_hand_signature := var_to_str(hand_cards)
	if next_hand_signature != hand_cards_signature:
		hand_cards_signature = next_hand_signature
		set_hand_cards(hand_cards)
	_sync_inspected_identity_chip()


func bind_public_identity(player_index: int) -> void:
	_public_player_index = player_index


func set_inspected_public_player(descriptor: Dictionary) -> void:
	_inspected_public_player = _safe_public_player_descriptor(descriptor)
	set_meta("inspected_player_index", int(_inspected_public_player.get("player_index", -1)))
	_sync_inspected_identity_chip()


func _sync_inspected_identity_chip() -> void:
	var inspected_index := int(_inspected_public_player.get("player_index", -1))
	if inspected_index < 0 or inspected_index == _public_player_index:
		_set_chip(identity_chip, "本席", _owner_identity_text, 118, 14)
		return
	var public_name := str(_inspected_public_player.get("public_player_name", "玩家%d" % (inspected_index + 1)))
	var role_name := str(_inspected_public_player.get("role_name", "公开角色"))
	_set_chip(identity_chip, "查看", public_name, 118, 14)
	identity_chip.tooltip_text = "公开玩家：%s｜%s。现金、手牌与私人情报仍属于本席。" % [public_name, role_name]


func _safe_public_player_descriptor(source: Dictionary) -> Dictionary:
	return {
		"player_index": int(source.get("player_index", -1)),
		"public_player_name": str(source.get("public_player_name", "")),
		"role_name": str(source.get("role_name", "")),
		"player_color": source.get("player_color", Color.WHITE),
		"public_status": str(source.get("public_status", "waiting")),
		"is_local_player": bool(source.get("is_local_player", false)),
	}


func _on_identity_chip_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and _public_player_index >= 0:
		player_inspection_requested.emit(_public_player_index)


func set_hand_cards(cards: Array) -> void:
	if hand_rack == null or not hand_rack.has_method("set_cards"):
		return
	hand_rack.call("set_cards", cards)


func set_runtime_feedback(data: Dictionary) -> void:
	runtime_feedback = data.duplicate(true)
	set_meta("runtime_feedback", runtime_feedback.duplicate(true))
	if runtime_feedback.is_empty():
		return
	var state := str(runtime_feedback.get("state", "info")).strip_edges()
	var label := str(runtime_feedback.get("label", runtime_feedback.get("text", ""))).strip_edges()
	var detail := str(runtime_feedback.get("detail", runtime_feedback.get("tooltip", ""))).strip_edges()
	if label == "":
		label = "已更新玩家行动状态"
	action_hint_label.text = label
	action_hint_label.tooltip_text = detail if detail != "" else label
	action_hint_label.add_theme_color_override("font_color", _runtime_feedback_color(state))


func get_runtime_feedback_snapshot() -> Dictionary:
	return runtime_feedback.duplicate(true)


func _on_card_clicked(card_data: Dictionary) -> void:
	card_selected.emit(card_data)


func _on_card_double_clicked(card_data: Dictionary) -> void:
	card_selected.emit(card_data)
	var action_id := _first_enabled_card_action_id(card_data)
	if action_id != "":
		action_requested.emit(action_id)


func _on_card_hovered(card_data: Dictionary) -> void:
	card_hovered.emit(card_data)


func _on_card_unhovered() -> void:
	card_unhovered.emit()


func _on_card_unselected(card_data: Dictionary) -> void:
	card_unselected.emit(card_data)


func _on_card_drag_preview_started(card_data: Dictionary, screen_position: Vector2) -> void:
	card_drag_preview_started.emit(card_data, screen_position)


func _on_card_drag_preview_moved(card_data: Dictionary, screen_position: Vector2) -> void:
	card_drag_preview_moved.emit(card_data, screen_position)


func _on_card_drag_preview_ended(card_data: Dictionary) -> void:
	card_drag_preview_ended.emit(card_data)


func _on_card_drag_released(card_data: Dictionary, screen_position: Vector2) -> void:
	card_drag_released.emit(card_data, screen_position)


func _on_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _on_application_intent_requested(intent: IntelApplicationIntent) -> void:
	if intent != null and intent.is_valid():
		application_intent_requested.emit(intent)


func _first_enabled_card_action_id(card_data: Dictionary) -> String:
	var actions: Array = card_data.get("actions", []) if card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		if bool(action.get("disabled", false)):
			continue
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id != "":
			return action_id
	return ""


func _set_main_action_dock(quick_actions: Array, actions: Array) -> void:
	if main_action_dock == null:
		return
	main_action_dock.set_dock({
		"quick_actions": quick_actions,
		"actions": actions,
	})


func _set_status_lamps(entries: Array) -> void:
	var normalized := entries
	if normalized.is_empty():
		normalized = [{"text": "桌态", "state": "空闲", "active": false, "tooltip": "当前没有紧急桌面状态。"}]
	var next_signature := var_to_str(normalized)
	if next_signature == status_lamps_signature:
		return
	status_lamps_signature = next_signature
	_clear_row(status_lamp_row)
	_add_status_chip(status_lamp_row, _summary_status_entry(normalized, "桌态"), "PlayerStatusLampChip")


func _set_readiness_chips(entries: Array) -> void:
	var normalized := entries
	if normalized.is_empty():
		normalized = [{"text": "先选区", "active": false, "tooltip": "先选择星球区域，再使用桌面行动。"}]
	var next_signature := var_to_str(normalized)
	if next_signature == readiness_chips_signature:
		return
	readiness_chips_signature = next_signature
	_clear_row(readiness_chip_row)
	if _has_cluster_chips(normalized):
		var added := 0
		for entry_variant in normalized:
			var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
			if not bool(entry.get("cluster", false)):
				continue
			_add_status_chip(readiness_chip_row, entry, "PlayerReadinessChip")
			added += 1
			if added >= 4:
				break
		if added > 0:
			return
	_add_status_chip(readiness_chip_row, _summary_status_entry(normalized, "就绪"), "PlayerReadinessChip")


func _set_progress_path(entries: Array) -> void:
	var normalized := entries
	if normalized.is_empty():
		normalized = [
			{"text": "点区", "state": "开始", "active": false, "accent": Color("#38bdf8"), "tip": "先点星球区域。"},
			{"text": "首召", "state": "待", "active": false, "accent": Color("#fb7185"), "tip": "打出起始怪兽，打开附近区域牌架。"},
			{"text": "建城", "state": "待", "active": false, "accent": Color("#22c55e"), "tip": "城市按秒产生GDP现金流。"},
			{"text": "买牌", "state": "待", "active": false, "accent": Color("#f59e0b"), "tip": "从怪兽所在区或邻区买牌。"},
			{"text": "出牌", "state": "待", "active": false, "accent": Color("#c084fc"), "tip": "满足条件后打出卡牌。"},
		]
	var next_signature := var_to_str(normalized)
	if next_signature == progress_path_signature:
		return
	progress_path_signature = next_signature
	_clear_row(progress_path_rail)
	var current_marked := false
	var added := 0
	for entry_variant in normalized:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		var done := bool(entry.get("done", entry.get("active", false)))
		var current := bool(entry.get("current", false))
		if not current_marked and not done:
			current = true
			current_marked = true
		elif current:
			current_marked = true
		_add_progress_path_chip(progress_path_rail, entry, done, current)
		added += 1
		if added >= 5:
			break


func _add_progress_path_chip(row: Container, entry: Dictionary, done: bool, current: bool) -> void:
	var accent := _entry_color(entry, Color("#94a3b8"))
	var chip := PanelContainer.new()
	chip.name = "PlayerProgressPathChip"
	chip.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	chip.custom_minimum_size = Vector2(38, 20)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _progress_path_chip_style(accent, done, current))
	var label := Label.new()
	label.name = "PlayerProgressPathChipLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("#f8fafc") if done or current else Color("#94a3b8"))
	var marker := "✓" if done else ("▶" if current else "·")
	var text := str(entry.get("text", entry.get("label", "路径"))).strip_edges()
	if text == "":
		text = "路径"
	label.text = "%s%s" % [marker, _short_chip_text(text, 4)]
	label.tooltip_text = chip.tooltip_text
	chip.add_child(label)
	row.add_child(chip)


func _progress_path_chip_style(accent: Color, done: bool, current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill_weight := 0.24 if done else (0.18 if current else 0.07)
	style.bg_color = Color("#020617").lerp(accent, fill_weight)
	style.border_color = accent if done or current else Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 4.0)
	style.set_content_margin(SIDE_RIGHT, 4.0)
	style.set_content_margin(SIDE_TOP, 1.0)
	style.set_content_margin(SIDE_BOTTOM, 1.0)
	return style


func _has_cluster_chips(entries: Array) -> bool:
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		if bool(entry.get("cluster", false)):
			return true
	return false


func _add_status_chip(row: Container, entry: Dictionary, node_name: String) -> void:
	var active := bool(entry.get("active", false))
	var accent := _entry_color(entry, Color("#94a3b8"))
	var clustered := bool(entry.get("cluster", false))
	var chip := PanelContainer.new()
	chip.name = node_name
	chip.tooltip_text = str(entry.get("tooltip", entry.get("tip", "")))
	chip.custom_minimum_size = Vector2(26 if clustered else 0, 20)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _status_chip_style(accent, active))
	var label := Label.new()
	label.name = "%sLabel" % node_name
	label.custom_minimum_size = Vector2.ZERO
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = _short_chip_text(_entry_status_text(entry), int(entry.get("max_chars", 7 if clustered else 16)))
	label.tooltip_text = chip.tooltip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8 if clustered else 9)
	label.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#cbd5e1"))
	chip.add_child(label)
	row.add_child(chip)


func _summary_status_entry(entries: Array, prefix: String) -> Dictionary:
	var parts: Array[String] = []
	var tooltips: Array[String] = []
	var active := false
	var accent := Color("#94a3b8")
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		if bool(entry.get("active", false)):
			active = true
			accent = _entry_color(entry, accent)
		var entry_text := _entry_status_text(entry)
		if entry_text.strip_edges() != "" and parts.size() < 2:
			parts.append(entry_text)
		var tooltip := str(entry.get("tooltip", entry.get("tip", ""))).strip_edges()
		if tooltip != "":
			tooltips.append("%s: %s" % [entry_text, tooltip])
	if parts.is_empty():
		parts.append("空闲")
	var summary := " / ".join(parts)
	var summary_text := summary
	if prefix.strip_edges() != "" and not summary.to_lower().begins_with(prefix.to_lower()):
		summary_text = "%s %s" % [prefix, summary]
	return {
		"text": summary_text,
		"active": active,
		"accent": accent,
		"tooltip": "\n".join(tooltips),
	}


func _entry_status_text(entry: Dictionary) -> String:
	var text := str(entry.get("label", "")).strip_edges()
	if text == "":
		text = str(entry.get("text", "")).strip_edges()
	var state := str(entry.get("state", "")).strip_edges()
	if text == "":
		text = "状态"
	if state == "":
		return text
	return "%s %s" % [text, state]


func _status_chip_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.24 if active else 0.10)
	style.border_color = accent if active else Color("#475569")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 5.0)
	style.set_content_margin(SIDE_RIGHT, 5.0)
	style.set_content_margin(SIDE_TOP, 1.0)
	style.set_content_margin(SIDE_BOTTOM, 1.0)
	return style


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", fallback)
	if value is Color:
		return value
	if value is String:
		var color_text := str(value)
		if color_text.begins_with("#"):
			return Color(color_text)
	return fallback


func _first_action_label(actions: Array) -> String:
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if not bool(action.get("disabled", false)):
			var label := str(action.get("label", ""))
			if label.strip_edges() != "":
				return label
	return "查看详情"


func _first_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key in keys:
		if data.has(key):
			var value := str(data.get(key, ""))
			if value.strip_edges() != "":
				return value
	return fallback


func _first_array(data: Dictionary, keys: Array) -> Array:
	for key in keys:
		if data.has(key):
			var value: Variant = data.get(key)
			if value is Array:
				return value
	return []


func _configure_chip_defaults() -> void:
	for chip in [identity_chip, cash_chip, gdp_chip, goal_chip, selected_district_chip, primary_action_chip, hand_count_chip]:
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _configure_tableau_styles() -> void:
	if resource_tableau != null:
		resource_tableau.add_theme_stylebox_override("panel", _tableau_style(Color("#facc15"), 0.08))
	if hand_tableau != null:
		hand_tableau.add_theme_stylebox_override("panel", _tableau_style(Color("#38bdf8"), 0.06))
	if command_tableau != null:
		command_tableau.add_theme_stylebox_override("panel", _tableau_style(Color("#22c55e"), 0.07))


func _clear_row(row: Container) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _set_chip(label: Label, prefix: String, value: String, width: float, max_characters: int) -> void:
	label.custom_minimum_size = Vector2(width, 22)
	label.text = "%s %s" % [prefix, _short_chip_text(value, max_characters)]
	label.tooltip_text = "%s: %s" % [prefix, value]
	var accent := _chip_accent(prefix)
	label.add_theme_stylebox_override("normal", _chip_style(accent))
	label.add_theme_color_override("font_color", accent.lightened(0.28))
	label.add_theme_font_size_override("font_size", 10)


func _short_chip_text(value: String, max_characters: int) -> String:
	if value.length() <= max_characters:
		return value
	return value.left(maxi(1, max_characters - 1)) + "..."


func _chip_accent(prefix: String) -> Color:
	match prefix:
		"现金":
			return Color("#facc15")
		"GDP":
			return Color("#38bdf8")
		"目标":
			return Color("#4ade80")
		"选区":
			return Color("#fde68a")
		"下一步":
			return Color("#c084fc")
		"手牌":
			return Color("#f472b6")
	return Color("#cbd5e1")


func _chip_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.12)
	style.border_color = Color("#334155").lerp(accent, 0.52)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 6.0)
	style.set_content_margin(SIDE_RIGHT, 6.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _runtime_feedback_color(state: String) -> Color:
	match state:
		"pending":
			return Color("#fde68a")
		"resolved":
			return Color("#86efac")
		"blocked":
			return Color("#fca5a5")
		"temporary_decision":
			return Color("#c084fc")
	return Color("#bfdbfe")


func _tableau_style(accent: Color, fill_weight: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, fill_weight)
	style.border_color = Color("#334155").lerp(accent, 0.36)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 6.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	return style
