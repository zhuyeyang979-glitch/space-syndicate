extends PanelContainer
class_name SpaceSyndicateBidBoard

signal action_requested(action_id: String)
signal track_link_hovered(action_id: String)
signal track_link_unhovered(action_id: String)

@onready var title_label: Label = %BidBoardTitle
@onready var phase_label: Label = %BidBoardPhase
@onready var chip_row: HFlowContainer = %BidBoardChipRow
@onready var track_link_row: HFlowContainer = %BidBoardTrackLinkRow
@onready var action_row: HFlowContainer = %BidBoardActionRow
@onready var status_label: Label = %BidBoardStatus

var bid_signature := ""
var _hovered_track_action := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style(Color("#f59e0b"), false))


func set_bid_state(data: Dictionary) -> void:
	var next_signature := var_to_str(data)
	if next_signature == bid_signature:
		return
	bid_signature = next_signature
	visible = bool(data.get("visible", true))
	title_label.text = str(data.get("title", "牌桌竞价"))
	phase_label.text = _short_text(str(data.get("phase", "待报价")), 12)
	phase_label.tooltip_text = str(data.get("phase_tooltip", data.get("status", "")))
	var status_text := str(data.get("status", "下一张牌可报价。"))
	var track_links: Array = data.get("track_links", []) if data.get("track_links", []) is Array else []
	var track_text := _track_link_text(track_links)
	status_label.text = _short_text(status_text if status_text != "" else track_text, 38)
	status_label.tooltip_text = "\n".join([track_text, str(data.get("status_tooltip", status_text))]).strip_edges()
	var accent := _entry_color(data, Color("#f59e0b"))
	add_theme_stylebox_override("panel", _panel_style(accent, bool(data.get("active", false))))
	var chips: Array = data.get("chips", []) if data.get("chips", []) is Array else []
	var actions: Array = data.get("actions", []) if data.get("actions", []) is Array else []
	_render_chips(chips)
	_render_track_links(track_links)
	_render_actions(actions)


func _render_chips(chips: Array) -> void:
	_clear_row(chip_row)
	if chips.is_empty():
		_add_chip({"label": "我的", "state": "¥0", "active": false, "accent": Color("#fde68a"), "tooltip": "当前没有报价。"})
		_add_chip({"label": "最高", "state": "¥0", "active": false, "accent": Color("#f59e0b"), "tooltip": "当前没有参拍牌。"})
		return
	for chip_variant in chips:
		var chip: Dictionary = chip_variant if chip_variant is Dictionary else {"text": str(chip_variant)}
		_add_chip(chip)


func _render_actions(actions: Array) -> void:
	_clear_row(action_row)
	if actions.is_empty():
		_add_action({"id": "bid_none", "label": "锁定", "disabled": true, "tooltip": "当前不能改报价。"})
		return
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		_add_action(action)


func _render_track_links(entries: Array) -> void:
	_clear_row(track_link_row)
	track_link_row.visible = not entries.is_empty()
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		_add_track_link(entry)


func _add_chip(entry: Dictionary) -> void:
	var active := bool(entry.get("active", false))
	var accent := _entry_color(entry, Color("#94a3b8"))
	var chip := PanelContainer.new()
	chip.name = "BidBoardChip"
	chip.tooltip_text = str(entry.get("tooltip", ""))
	chip.custom_minimum_size = Vector2(58, 19)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _chip_style(accent, active))
	var label := Label.new()
	label.name = "BidBoardChipLabel"
	label.text = _short_text(_entry_status_text(entry), int(entry.get("max_chars", 9)))
	label.tooltip_text = chip.tooltip_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#cbd5e1"))
	chip.add_child(label)
	chip_row.add_child(chip)


func _add_track_link(entry: Dictionary) -> void:
	var action_id := str(entry.get("id", entry.get("action_id", ""))).strip_edges()
	var selected := bool(entry.get("selected", entry.get("focused", false)))
	var hovered := action_id != "" and action_id == _hovered_track_action
	var active := bool(entry.get("active", false)) or selected or hovered
	var accent := _entry_color(entry, Color("#38bdf8"))
	var button := Button.new()
	button.name = "BidBoardTrackLinkButton"
	button.text = _short_text(_entry_status_text(entry), int(entry.get("max_chars", 13)))
	button.disabled = action_id == ""
	button.tooltip_text = str(entry.get("tooltip", "单击选中顶部牌轨中的对应牌槽。"))
	button.custom_minimum_size = Vector2(72, 20)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("action_id", action_id)
	button.set_meta("accent", accent)
	button.set_meta("base_active", bool(entry.get("active", false)))
	button.set_meta("selected", selected)
	button.add_theme_stylebox_override("normal", _track_link_style(accent, active, selected, button.disabled, hovered))
	button.add_theme_stylebox_override("hover", _track_link_style(accent.lightened(0.10), true, selected, button.disabled, true))
	button.add_theme_stylebox_override("pressed", _track_link_style(accent.lightened(0.18), true, true, button.disabled, true))
	button.add_theme_stylebox_override("disabled", _track_link_style(accent, active, selected, true, hovered))
	button.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#cbd5e1"))
	button.add_theme_font_size_override("font_size", 8)
	if hovered:
		var hover_marker := Node.new()
		hover_marker.name = "BidBoardTrackLinkHover"
		button.add_child(hover_marker)
	if action_id != "":
		button.pressed.connect(func() -> void:
			action_requested.emit(action_id)
		)
		button.mouse_entered.connect(func() -> void:
			track_link_hovered.emit(action_id)
		)
		button.focus_entered.connect(func() -> void:
			track_link_hovered.emit(action_id)
		)
		button.mouse_exited.connect(func() -> void:
			track_link_unhovered.emit(action_id)
		)
		button.focus_exited.connect(func() -> void:
			track_link_unhovered.emit(action_id)
		)
	track_link_row.add_child(button)


func set_hovered_track_action(action_id: String) -> void:
	var normalized := action_id.strip_edges()
	if normalized == _hovered_track_action:
		return
	_hovered_track_action = normalized
	_sync_hovered_track_links()


func _sync_hovered_track_links() -> void:
	for child in track_link_row.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var action_id := str(button.get_meta("action_id", "")).strip_edges()
		var hovered := _hovered_track_action != "" and action_id == _hovered_track_action
		var selected := bool(button.get_meta("selected", false))
		var base_active := bool(button.get_meta("base_active", false))
		var accent_variant: Variant = button.get_meta("accent", Color("#38bdf8"))
		var accent := Color("#38bdf8")
		if accent_variant is Color:
			accent = accent_variant
		var active := base_active or selected or hovered
		button.add_theme_stylebox_override("normal", _track_link_style(accent, active, selected, button.disabled, hovered))
		button.add_theme_stylebox_override("hover", _track_link_style(accent.lightened(0.10), true, selected, button.disabled, true))
		button.add_theme_stylebox_override("pressed", _track_link_style(accent.lightened(0.18), true, true, button.disabled, true))
		button.add_theme_stylebox_override("disabled", _track_link_style(accent, active, selected, true, hovered))
		button.add_theme_color_override("font_color", Color("#f8fafc") if active else Color("#cbd5e1"))
		_sync_marker(button, "BidBoardTrackLinkHover", hovered)


func _sync_marker(parent: Node, marker_name: String, enabled: bool) -> void:
	var existing := parent.find_child(marker_name, false, false)
	if enabled and existing == null:
		var marker := Node.new()
		marker.name = marker_name
		parent.add_child(marker)
	elif not enabled and existing != null:
		parent.remove_child(existing)
		existing.queue_free()


func _add_action(entry: Dictionary) -> void:
	var action_id := str(entry.get("id", entry.get("label", "bid_none")))
	var disabled := bool(entry.get("disabled", false))
	var accent := _entry_color(entry, Color("#fde68a"))
	var button := Button.new()
	button.name = "BidBoardActionButton"
	button.text = _short_text(str(entry.get("label", action_id)), 6)
	button.disabled = disabled
	button.tooltip_text = str(entry.get("tooltip", ""))
	button.custom_minimum_size = Vector2(44, 22)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _action_style(accent, disabled))
	button.add_theme_stylebox_override("hover", _action_style(accent, false))
	button.add_theme_stylebox_override("pressed", _action_style(accent.lightened(0.10), false))
	button.add_theme_stylebox_override("disabled", _action_style(accent, true))
	button.add_theme_color_override("font_color", Color("#f8fafc") if not disabled else Color("#94a3b8"))
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(func() -> void:
		action_requested.emit(action_id)
	)
	action_row.add_child(button)


func _clear_row(row: Container) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _entry_status_text(entry: Dictionary) -> String:
	var label := str(entry.get("label", entry.get("text", ""))).strip_edges()
	var state := str(entry.get("state", entry.get("value", ""))).strip_edges()
	if label == "":
		label = "状态"
	if state == "":
		return label
	return "%s %s" % [label, state]


func _track_link_text(entries: Array) -> String:
	var pieces: Array[String] = []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		var text := _entry_status_text(entry)
		if text.strip_edges() != "":
			pieces.append(text)
	return "｜".join(pieces)


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", fallback)
	if value is Color:
		return value
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _panel_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.12 if active else 0.07)
	style.border_color = Color("#334155").lerp(accent, 0.52 if active else 0.34)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin(SIDE_LEFT, 6.0)
	style.set_content_margin(SIDE_RIGHT, 6.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


func _chip_style(accent: Color, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.25 if active else 0.10)
	style.border_color = accent if active else Color("#475569").lerp(accent, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 4.0)
	style.set_content_margin(SIDE_RIGHT, 4.0)
	style.set_content_margin(SIDE_TOP, 1.0)
	style.set_content_margin(SIDE_BOTTOM, 1.0)
	return style


func _track_link_style(accent: Color, active: bool, selected: bool, disabled: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill_weight := 0.08
	if active:
		fill_weight = 0.20
	if hovered:
		fill_weight = 0.30
	if selected:
		fill_weight = 0.32
	if disabled:
		fill_weight *= 0.45
	style.bg_color = Color("#020617").lerp(accent, fill_weight)
	style.border_color = accent.lightened(0.20) if hovered else (accent if selected else Color("#475569").lerp(accent, 0.42 if active else 0.24))
	style.set_border_width_all(2 if selected or hovered else 1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 4.0)
	style.set_content_margin(SIDE_RIGHT, 4.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _action_style(accent: Color, disabled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0f172a").lerp(accent, 0.12 if disabled else 0.28)
	style.border_color = Color("#475569") if disabled else accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 5.0)
	style.set_content_margin(SIDE_RIGHT, 5.0)
	style.set_content_margin(SIDE_TOP, 3.0)
	style.set_content_margin(SIDE_BOTTOM, 3.0)
	return style


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= limit:
		return text
	return "%s..." % text.left(maxi(1, limit - 3))
