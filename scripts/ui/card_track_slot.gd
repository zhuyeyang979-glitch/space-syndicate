extends PanelContainer
class_name SpaceSyndicateCardTrackSlot

signal entry_selected(entry: Dictionary)
signal entry_opened(entry: Dictionary)
signal entry_hovered(entry: Dictionary)
signal entry_unhovered(entry: Dictionary)

const DEFAULT_ACCENT := Color("#38bdf8")

@onready var stack: VBoxContainer = %PublicTrackSlotStack
@onready var row: HBoxContainer = %PublicTrackSlotRow
@onready var pip: ColorRect = %PublicTrackStatePip
@onready var slot_index_label: Label = %PublicTrackSlotIndex
@onready var label: Label = %PublicTrackSlotLabel
@onready var meta_label: Label = %PublicTrackSlotMeta
@onready var badge_row: HBoxContainer = %PublicTrackBadgeRow

var _entry: Dictionary = {}
var _accent := DEFAULT_ACCENT
var _selected := false
var _base_active := false
var _hovered := false
var _hover_action := ""
var _disabled := false
var _is_event := false
var _compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_connect_focus_and_hover()


func configure(entry: Dictionary, index: int, options: Dictionary = {}) -> void:
	_entry = entry.duplicate(true)
	_accent = _entry_color(_entry)
	_selected = bool(_entry.get("selected", _entry.get("focused", false)))
	_base_active = bool(_entry.get("active", false))
	_hover_action = _entry_hover_action(_entry)
	_hovered = str(options.get("hovered_action", "")).strip_edges() != "" and _hover_action == str(options.get("hovered_action", "")).strip_edges()
	_disabled = bool(_entry.get("disabled", false))
	_is_event = str(_entry.get("kind", "")).strip_edges().to_lower() == "event"
	_compact = bool(options.get("compact", false))
	name = "PublicTrackSlot" if index == 0 else "PublicTrackSlot_%02d" % (index + 1)
	custom_minimum_size = Vector2(float(options.get("slot_width", 146.0)), float(options.get("slot_height", 34.0)))
	tooltip_text = str(_entry.get("tooltip", ""))
	set_meta("accent", _accent)
	set_meta("base_active", _base_active)
	set_meta("selected", _selected)
	set_meta("hover_action", _hover_action)
	set_meta("runtime_focus_kind", "public_track_slot")
	if pip != null:
		pip.color = _accent
	if slot_index_label != null:
		slot_index_label.text = str(_entry.get("slot", "#%d" % (index + 1)))
		slot_index_label.tooltip_text = tooltip_text
	if label != null:
		label.text = _entry_text(_entry)
		label.tooltip_text = tooltip_text
	if meta_label != null:
		meta_label.text = _entry_meta(_entry)
		meta_label.tooltip_text = tooltip_text
	_sync_badges()
	_refresh_visual_state()


func track_entry() -> Dictionary:
	return _entry.duplicate(true)


func hover_action() -> String:
	return _hover_action


func set_hovered_visual(hovered: bool) -> void:
	if _hovered == hovered:
		return
	_hovered = hovered
	_refresh_visual_state()


func is_event_slot() -> bool:
	return _is_event


func is_selected_slot() -> bool:
	return _selected


func set_selected_visual(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	set_meta("selected", _selected)
	_refresh_visual_state()


func debug_press(double_click: bool = false) -> void:
	if _disabled:
		return
	if double_click:
		entry_opened.emit(track_entry())
	else:
		entry_selected.emit(track_entry())


func _on_gui_input_signal(event: InputEvent) -> void:
	if _disabled:
		return
	if event != null and event.is_action_pressed("ui_accept"):
		entry_selected.emit(track_entry())
		accept_event()
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		if mouse_event.double_click:
			entry_opened.emit(track_entry())
		else:
			entry_selected.emit(track_entry())
		accept_event()


func _connect_focus_and_hover() -> void:
	var input_callback := Callable(self, "_on_gui_input_signal")
	if not gui_input.is_connected(input_callback):
		gui_input.connect(input_callback)
	var entered_callback := Callable(self, "_on_hover_entered")
	if not mouse_entered.is_connected(entered_callback):
		mouse_entered.connect(entered_callback)
	var exited_callback := Callable(self, "_on_hover_exited")
	if not mouse_exited.is_connected(exited_callback):
		mouse_exited.connect(exited_callback)
	var focus_entered_callback := Callable(self, "_on_focus_entered")
	if not focus_entered.is_connected(focus_entered_callback):
		focus_entered.connect(focus_entered_callback)
	var focus_exited_callback := Callable(self, "_on_focus_exited")
	if not focus_exited.is_connected(focus_exited_callback):
		focus_exited.connect(focus_exited_callback)


func _on_hover_entered() -> void:
	entry_hovered.emit(track_entry())


func _on_hover_exited() -> void:
	entry_unhovered.emit(track_entry())


func _on_focus_entered() -> void:
	entry_hovered.emit(track_entry())


func _on_focus_exited() -> void:
	entry_unhovered.emit(track_entry())


func _sync_badges() -> void:
	if badge_row == null:
		return
	for child in badge_row.get_children():
		badge_row.remove_child(child)
		child.queue_free()
	if _compact:
		badge_row.visible = false
		return
	var badges := _entry_badges(_entry)
	if _is_event and badges.is_empty():
		badges.append("只读")
	badge_row.visible = not badges.is_empty()
	for badge_text in badges.slice(0, 2):
		var badge_label := Label.new()
		badge_label.name = "TimelineEventReadOnlyBadge" if _is_event else "PublicTrackBadge"
		badge_label.text = _short_text(str(badge_text), 7)
		badge_label.tooltip_text = tooltip_text
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		badge_label.add_theme_font_size_override("font_size", 7)
		badge_label.add_theme_color_override("font_color", _accent.lightened(0.32))
		badge_row.add_child(badge_label)


func _refresh_visual_state() -> void:
	var active := _base_active or _selected or _hovered
	add_theme_stylebox_override("panel", _slot_style(_accent, active, _selected, _hovered))
	_sync_marker("PublicTrackSlotSelected", _selected)
	_sync_marker("PublicTrackSlotHover", _hovered)
	_sync_marker("CardResolutionTimelineEventSlot", _is_event)


func _sync_marker(marker_name: String, enabled: bool) -> void:
	var existing := find_child(marker_name, false, false)
	if enabled and existing == null:
		var marker := Control.new()
		marker.name = marker_name
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(marker)
	elif enabled and existing is CanvasItem:
		(existing as CanvasItem).visible = true
	elif not enabled and existing != null:
		remove_child(existing)
		existing.queue_free()


func _entry_text(entry: Dictionary) -> String:
	return _short_text(str(entry.get("label", "公共牌")), 12)


func _entry_meta(entry: Dictionary) -> String:
	var cost := str(entry.get("cost", "")).strip_edges()
	var owner_hint := _public_owner_hint(entry)
	var state := str(entry.get("state", "等待")).strip_edges()
	var pieces: Array[String] = []
	if cost != "":
		pieces.append(cost)
	if owner_hint != "":
		pieces.append(owner_hint)
	if pieces.is_empty():
		pieces.append(state)
	return _short_text("｜".join(pieces), 8)


func _public_owner_hint(entry: Dictionary) -> String:
	var owner_hint := str(entry.get("owner_hint", "")).strip_edges()
	if owner_hint == "":
		return ""
	match owner_hint:
		"匿名", "unknown", "Unknown", "UNKNOWN", "未公开":
			return "未知"
	return owner_hint


func _entry_badges(entry: Dictionary) -> Array:
	var badges: Array = entry.get("badges", []) if entry.get("badges", []) is Array else []
	var result: Array = []
	for badge_variant in badges:
		var text := str(badge_variant).strip_edges()
		if text != "":
			result.append(text)
	return result


func _entry_color(entry: Dictionary) -> Color:
	var accent_variant: Variant = entry.get("accent", DEFAULT_ACCENT)
	if accent_variant is Color:
		return accent_variant
	if accent_variant is String:
		var accent_text := String(accent_variant).strip_edges()
		if accent_text.begins_with("#"):
			return Color(accent_text)
	return DEFAULT_ACCENT


func _entry_hover_action(entry: Dictionary) -> String:
	for key in ["hover_action", "select_action"]:
		var action := str(entry.get(key, "")).strip_edges()
		if action != "":
			return action
	var resolution_id := int(entry.get("resolution_id", -1))
	return "track_select_%d" % resolution_id if resolution_id >= 0 else ""


func _slot_style(accent: Color, active: bool, selected: bool = false, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill_weight := 0.0
	if active:
		fill_weight = 0.08
	if hovered:
		fill_weight = 0.20
	if selected:
		fill_weight = 0.16
	style.bg_color = Color(0.08, 0.11, 0.16, 0.86).lerp(accent, fill_weight)
	style.border_color = accent.lightened(0.42) if hovered else (accent.lightened(0.30) if selected else (accent.lightened(0.18) if active else Color(accent.r, accent.g, accent.b, 0.42)))
	var border_width := 2 if selected or hovered else 1
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _short_text(text: String, max_length: int) -> String:
	var value := text.strip_edges()
	if value.length() <= max_length:
		return value
	return "%s…" % value.substr(0, maxi(1, max_length - 1))
