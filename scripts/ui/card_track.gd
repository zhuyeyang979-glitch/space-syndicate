extends PanelContainer
class_name SpaceSyndicateCardTrack

signal track_entry_selected(entry: Dictionary)
signal track_entry_opened(entry: Dictionary)
signal track_entry_hovered(entry: Dictionary)
signal track_entry_unhovered(entry: Dictionary)

const SLOT_HEIGHT := 34.0
const SLOT_MIN_WIDTH := 146.0
const SLOT_MAX_WIDTH := 208.0
const EMPTY_TRACK_ENTRY := {
	"label": "牌轨空闲",
	"slot": "--",
	"state": "等待",
	"owner_hint": "待猜",
	"accent": Color("#64748b"),
	"tooltip": "当前没有正在结算的公开牌。",
}

@onready var card_track_row: HBoxContainer = %CardTrackRow

var _entries_signature := ""
var _hovered_track_action := ""


func _ready() -> void:
	card_track_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_stylebox_override("panel", _track_style())


func set_entries(entries: Array) -> void:
	var display_entries := entries.duplicate(true)
	if display_entries.is_empty():
		display_entries = [EMPTY_TRACK_ENTRY]
	var next_signature := var_to_str(display_entries)
	if next_signature == _entries_signature:
		return
	_entries_signature = next_signature
	_clear_children()
	for index in range(display_entries.size()):
		var entry_variant: Variant = display_entries[index]
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		_add_track_slot(entry, index)
	_sync_track_width()


func _add_track_slot(entry: Dictionary, index: int) -> void:
	var accent := _entry_color(entry)
	var is_event := str(entry.get("kind", "")).strip_edges().to_lower() == "event"
	var selected := bool(entry.get("selected", entry.get("focused", false)))
	var hover_action := _entry_hover_action(entry)
	var hovered := hover_action != "" and hover_action == _hovered_track_action
	var active := bool(entry.get("active", false)) or selected or hovered
	var slot_panel := PanelContainer.new()
	slot_panel.name = "PublicTrackSlot"
	slot_panel.custom_minimum_size = Vector2(_slot_width(entry), SLOT_HEIGHT)
	slot_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	slot_panel.tooltip_text = str(entry.get("tooltip", ""))
	slot_panel.set_meta("accent", accent)
	slot_panel.set_meta("base_active", bool(entry.get("active", false)))
	slot_panel.set_meta("selected", selected)
	slot_panel.set_meta("hover_action", hover_action)
	slot_panel.add_theme_stylebox_override("panel", _slot_style(accent, active, selected, hovered))
	slot_panel.gui_input.connect(Callable(self, "_on_track_slot_gui_input").bind(entry.duplicate(true)))
	slot_panel.mouse_entered.connect(func() -> void:
		track_entry_hovered.emit(entry.duplicate(true))
	)
	slot_panel.mouse_exited.connect(func() -> void:
		track_entry_unhovered.emit(entry.duplicate(true))
	)
	card_track_row.add_child(slot_panel)
	if selected:
		var selected_marker := Node.new()
		selected_marker.name = "PublicTrackSlotSelected"
		slot_panel.add_child(selected_marker)
	if hovered:
		var hover_marker := Node.new()
		hover_marker.name = "PublicTrackSlotHover"
		slot_panel.add_child(hover_marker)
	if is_event:
		var event_marker := Node.new()
		event_marker.name = "CardResolutionTimelineEventSlot"
		slot_panel.add_child(event_marker)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	slot_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "PublicTrackSlotStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 0)
	margin.add_child(stack)

	var row := HBoxContainer.new()
	row.name = "PublicTrackSlotRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	stack.add_child(row)

	var pip := ColorRect.new()
	pip.name = "PublicTrackStatePip"
	pip.custom_minimum_size = Vector2(4, 18)
	pip.color = accent
	row.add_child(pip)

	var slot_label := Label.new()
	slot_label.name = "PublicTrackSlotIndex"
	slot_label.custom_minimum_size = Vector2(30, 0)
	slot_label.text = str(entry.get("slot", "#%d" % (index + 1)))
	slot_label.tooltip_text = slot_panel.tooltip_text
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(slot_label)

	var label := Label.new()
	label.name = "PublicTrackSlotLabel"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = _entry_text(entry)
	label.tooltip_text = slot_panel.tooltip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)

	var meta_label := Label.new()
	meta_label.name = "PublicTrackSlotMeta"
	meta_label.custom_minimum_size = Vector2(52, 0)
	meta_label.text = _entry_meta(entry)
	meta_label.tooltip_text = slot_panel.tooltip_text
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(meta_label)

	var badges := _entry_badges(entry)
	if is_event and badges.is_empty():
		badges.append("只读")
	if not badges.is_empty():
		var badge_row := HBoxContainer.new()
		badge_row.name = "PublicTrackBadgeRow"
		badge_row.add_theme_constant_override("separation", 3)
		stack.add_child(badge_row)
		for badge_text in badges.slice(0, 2):
			var badge_label := Label.new()
			badge_label.name = "TimelineEventReadOnlyBadge" if is_event else "PublicTrackBadge"
			badge_label.text = _short_text(str(badge_text), 7)
			badge_label.tooltip_text = slot_panel.tooltip_text
			badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			badge_label.add_theme_font_size_override("font_size", 7)
			badge_label.add_theme_color_override("font_color", accent.lightened(0.32))
			badge_row.add_child(badge_label)


func _on_track_slot_gui_input(event: InputEvent, entry: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		if mouse_event.double_click:
			track_entry_opened.emit(entry.duplicate(true))
		else:
			track_entry_selected.emit(entry.duplicate(true))
		accept_event()


func set_hovered_track_action(action_id: String) -> void:
	var normalized := action_id.strip_edges()
	if normalized == _hovered_track_action:
		return
	_hovered_track_action = normalized
	_sync_hovered_track_slots()


func _sync_hovered_track_slots() -> void:
	for child in card_track_row.get_children():
		if not (child is PanelContainer):
			continue
		var slot_panel := child as PanelContainer
		var hover_action := str(slot_panel.get_meta("hover_action", "")).strip_edges()
		var hovered := _hovered_track_action != "" and hover_action == _hovered_track_action
		var selected := bool(slot_panel.get_meta("selected", false))
		var base_active := bool(slot_panel.get_meta("base_active", false))
		var accent_variant: Variant = slot_panel.get_meta("accent", Color("#38bdf8"))
		var accent := Color("#38bdf8")
		if accent_variant is Color:
			accent = accent_variant
		slot_panel.add_theme_stylebox_override("panel", _slot_style(accent, base_active or selected or hovered, selected, hovered))
		_sync_marker(slot_panel, "PublicTrackSlotHover", hovered)


func _sync_marker(slot_panel: Node, marker_name: String, enabled: bool) -> void:
	var existing := slot_panel.find_child(marker_name, false, false)
	if enabled and existing == null:
		var marker := Node.new()
		marker.name = marker_name
		slot_panel.add_child(marker)
	elif not enabled and existing != null:
		slot_panel.remove_child(existing)
		existing.queue_free()


func _clear_children() -> void:
	card_track_row.custom_minimum_size = Vector2.ZERO
	for child in card_track_row.get_children():
		card_track_row.remove_child(child)
		child.queue_free()


func _sync_track_width() -> void:
	var total_width := 0.0
	var slot_count := 0
	for child in card_track_row.get_children():
		if child is Control:
			var control := child as Control
			total_width += maxf(control.custom_minimum_size.x, control.get_combined_minimum_size().x)
			slot_count += 1
	if slot_count > 1:
		total_width += float(slot_count - 1) * float(card_track_row.get_theme_constant("separation"))
	card_track_row.custom_minimum_size = Vector2(total_width, SLOT_HEIGHT)


func _entry_text(entry: Dictionary) -> String:
	return _short_text(str(entry.get("label", "公共牌")), 12)


func _entry_meta(entry: Dictionary) -> String:
	var cost := str(entry.get("cost", "")).strip_edges()
	var owner_hint := str(entry.get("owner_hint", "")).strip_edges()
	var state := str(entry.get("state", "等待")).strip_edges()
	var pieces: Array[String] = []
	if cost != "":
		pieces.append(cost)
	if owner_hint != "":
		pieces.append(owner_hint)
	if pieces.is_empty():
		pieces.append(state)
	return _short_text("｜".join(pieces), 8)


func _entry_badges(entry: Dictionary) -> Array:
	var badges: Array = entry.get("badges", []) if entry.get("badges", []) is Array else []
	var result: Array = []
	for badge_variant in badges:
		var text := str(badge_variant).strip_edges()
		if text != "":
			result.append(text)
	return result


func _entry_color(entry: Dictionary) -> Color:
	var accent_variant: Variant = entry.get("accent", Color("#38bdf8"))
	if accent_variant is Color:
		return accent_variant
	if accent_variant is String:
		var accent_text := String(accent_variant).strip_edges()
		if accent_text.begins_with("#"):
			return Color(accent_text)
	return Color("#38bdf8")


func _entry_hover_action(entry: Dictionary) -> String:
	var action := str(entry.get("select_action", "")).strip_edges()
	if action != "":
		return action
	var resolution_id := int(entry.get("resolution_id", -1))
	return "track_select_%d" % resolution_id if resolution_id >= 0 else ""


func _slot_width(entry: Dictionary) -> float:
	var label_width := float(_entry_text(entry).length() * 9 + _entry_meta(entry).length() * 7 + 66)
	return clampf(label_width, SLOT_MIN_WIDTH, SLOT_MAX_WIDTH)


func _track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.72)
	style.border_color = Color(0.24, 0.38, 0.52, 0.38)
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


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
