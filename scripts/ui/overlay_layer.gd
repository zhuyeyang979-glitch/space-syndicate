extends CanvasLayer
class_name SpaceSyndicateOverlayLayer

signal side_drawer_action_requested(action_id: String)
signal temporary_decision_action_requested(action_id: String)

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_label: Label = %TooltipLabel
@onready var confirm_panel: PanelContainer = %ConfirmPanel
@onready var confirm_label: Label = %ConfirmLabel
@onready var confirm_chip_row: HFlowContainer = %ConfirmChipRow
@onready var confirm_action_row: GridContainer = %ConfirmActionRow
@onready var confirm_center: CenterContainer = $OverlayRoot/ModalLayer/ConfirmCenter
@onready var monster_wager_decision_panel: Control = %MonsterWagerDecisionPanel
@onready var contract_response_decision_panel: Control = %ContractResponseDecisionPanel
@onready var temporary_choice_decision_panel: Control = %TemporaryChoiceDecisionPanel
@onready var side_drawer_panel: PanelContainer = %SideDrawerPanel
@onready var side_drawer_title: Label = %SideDrawerTitle
@onready var side_drawer_close_button: Button = %SideDrawerCloseButton
@onready var side_drawer_body_scroll: ScrollContainer = %SideDrawerBodyScroll
@onready var side_drawer_summary: Label = %SideDrawerSummary
@onready var side_drawer_section_list: VBoxContainer = %SideDrawerSectionList
@onready var side_drawer_chip_row: HFlowContainer = %SideDrawerChipRow
@onready var side_drawer_action_row: HFlowContainer = %SideDrawerActionRow
@onready var drag_drop_target_panel: PanelContainer = %DragDropTargetPanel
@onready var drag_drop_target_label: Label = %DragDropTargetLabel
@onready var drag_preview_panel: PanelContainer = %DragPreviewPanel
@onready var drag_preview_label: Label = %DragPreviewLabel

const DRAG_PREVIEW_SIZE := Vector2(176.0, 118.0)
const DRAG_PREVIEW_SIDE_GAP := 12.0
const TEMP_DECISION_BODY_LIMIT := 72
const SIDE_DRAWER_SUMMARY_LIMIT := 96
const SIDE_DRAWER_SECTION_BODY_LIMIT := 132
const TEMP_DECISION_SIDE_ANCHOR_LEFT := 0.70
const TEMP_DECISION_SIDE_ANCHOR_TOP := 0.18
const TEMP_DECISION_SIDE_ANCHOR_RIGHT := 0.985
const TEMP_DECISION_SIDE_ANCHOR_BOTTOM := 0.82
const TEMP_DECISION_MONSTER_WAGER := "monster_wager"
const TEMP_DECISION_CONTRACT_RESPONSE := "contract_response"
const TEMP_DECISION_DISCARD := "discard_purchase"
const TEMP_DECISION_MONSTER_TARGET := "monster_target_choice"
const TEMP_DECISION_PLAYER_TARGET := "player_target_choice"


func _ready() -> void:
	_configure_pointer_passthrough_skeleton()
	_dock_confirm_to_planet_side_lane()
	side_drawer_close_button.pressed.connect(hide_side_drawer)
	_connect_specialized_temporary_decision_panels()


func _configure_pointer_passthrough_skeleton() -> void:
	for path in [
		"OverlayRoot",
		"RuntimeSurfaceLayer",
		"OverlayRoot/SideDrawerLayer",
		"OverlayRoot/SideDrawerLayer/OverlayMargin",
		"OverlayRoot/SideDrawerLayer/OverlayMargin/OverlayColumns",
		"OverlayRoot/SideDrawerLayer/OverlayMargin/OverlayColumns/OverlaySpacer",
		"OverlayRoot/TooltipLayer",
		"OverlayRoot/DragPreviewLayer",
		"OverlayRoot/ModalLayer",
		"OverlayRoot/ModalLayer/ConfirmCenter",
	]:
		var node := get_node_or_null(path)
		if node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_tooltip(text: String) -> void:
	tooltip_label.text = text
	tooltip_panel.visible = text.strip_edges() != ""


func hide_tooltip() -> void:
	tooltip_panel.visible = false


func show_confirm(text: String) -> void:
	_dock_confirm_to_planet_side_lane()
	_hide_specialized_temporary_decision_panels()
	confirm_panel.name = "ConfirmPanel"
	confirm_label.text = _short_text(text, TEMP_DECISION_BODY_LIMIT)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_panel.tooltip_text = text
	_set_label_chip_row(confirm_chip_row, [])
	_set_temporary_decision_action_row([])
	confirm_panel.visible = true


func hide_confirm() -> void:
	confirm_panel.visible = false
	confirm_panel.name = "ConfirmPanel"
	_hide_specialized_temporary_decision_panels()


func show_temporary_decision(data: Dictionary) -> void:
	if data.is_empty():
		hide_confirm()
		return
	_dock_confirm_to_planet_side_lane()
	_hide_specialized_temporary_decision_panels()
	var kind := str(data.get("kind", ""))
	if kind == TEMP_DECISION_MONSTER_WAGER and _show_specialized_temporary_decision(monster_wager_decision_panel, data):
		confirm_panel.visible = false
		return
	if kind == TEMP_DECISION_CONTRACT_RESPONSE and _show_specialized_temporary_decision(contract_response_decision_panel, data):
		confirm_panel.visible = false
		return
	if [TEMP_DECISION_DISCARD, TEMP_DECISION_MONSTER_TARGET, TEMP_DECISION_PLAYER_TARGET].has(kind) and _show_specialized_temporary_decision(temporary_choice_decision_panel, data):
		confirm_panel.visible = false
		return
	var title := str(data.get("title", "临时决策")).strip_edges()
	var body := str(data.get("body", data.get("summary", ""))).strip_edges()
	confirm_panel.name = "TemporaryDecisionModal"
	confirm_panel.tooltip_text = str(data.get("tooltip", body))
	var visible_body := _short_text(body, TEMP_DECISION_BODY_LIMIT)
	confirm_label.text = "%s\n%s" % [title, visible_body] if visible_body != "" else title
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	confirm_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	confirm_label.tooltip_text = confirm_panel.tooltip_text
	_set_label_chip_row(confirm_chip_row, data.get("chips", []))
	_set_temporary_decision_action_row(data.get("actions", []))
	confirm_panel.add_theme_stylebox_override("panel", _panel_style(_entry_color(data, Color("#facc15")), Color("#020617").lerp(_entry_color(data, Color("#facc15")), 0.12), 2, 10))
	confirm_panel.visible = true


func _connect_specialized_temporary_decision_panels() -> void:
	for panel in [monster_wager_decision_panel, contract_response_decision_panel, temporary_choice_decision_panel]:
		if panel != null and panel.has_signal("action_requested"):
			panel.connect("action_requested", Callable(self, "_on_specialized_temporary_decision_action_requested"))


func _on_specialized_temporary_decision_action_requested(action_id: String) -> void:
	temporary_decision_action_requested.emit(action_id)


func _show_specialized_temporary_decision(panel: Control, data: Dictionary) -> bool:
	if panel == null or not panel.has_method("set_decision"):
		return false
	panel.call("set_decision", data)
	panel.visible = true
	return true


func _hide_specialized_temporary_decision_panels() -> void:
	for panel in [monster_wager_decision_panel, contract_response_decision_panel, temporary_choice_decision_panel]:
		if panel != null:
			panel.visible = false


func show_side_drawer(data: Dictionary) -> void:
	side_drawer_title.text = _short_text(str(data.get("title", "详情抽屉")), 18)
	var sections: Array = data.get("sections", []) if data.get("sections", []) is Array else []
	side_drawer_summary.text = _short_text(str(data.get("body", data.get("summary", ""))), SIDE_DRAWER_SUMMARY_LIMIT)
	side_drawer_summary.visible = side_drawer_summary.text.strip_edges() != "" and sections.is_empty()
	_set_side_drawer_sections(sections)
	_set_label_chip_row(side_drawer_chip_row, data.get("chips", []))
	_set_side_drawer_action_row(data.get("actions", data.get("links", [])))
	side_drawer_panel.visible = true
	if side_drawer_body_scroll != null:
		side_drawer_body_scroll.scroll_vertical = 0


func hide_side_drawer() -> void:
	side_drawer_panel.visible = false


func show_drag_preview(text: String, screen_position: Vector2 = Vector2.ZERO, drop_hint: Dictionary = {}) -> void:
	drag_preview_label.text = text
	drag_preview_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	drag_preview_label.clip_text = true
	drag_preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	drag_preview_panel.custom_minimum_size = DRAG_PREVIEW_SIZE
	drag_preview_panel.size = DRAG_PREVIEW_SIZE
	drag_preview_label.custom_minimum_size = Vector2(DRAG_PREVIEW_SIZE.x - 22.0, 0.0)
	drag_preview_panel.position = _drag_preview_position(drag_preview_panel, screen_position, drop_hint)
	_apply_drag_preview_style(drop_hint)
	_show_drag_drop_target_hint(drop_hint)
	drag_preview_panel.visible = text.strip_edges() != ""


func _dock_confirm_to_planet_side_lane() -> void:
	if confirm_center == null:
		return
	confirm_center.anchor_left = TEMP_DECISION_SIDE_ANCHOR_LEFT
	confirm_center.anchor_top = TEMP_DECISION_SIDE_ANCHOR_TOP
	confirm_center.anchor_right = TEMP_DECISION_SIDE_ANCHOR_RIGHT
	confirm_center.anchor_bottom = TEMP_DECISION_SIDE_ANCHOR_BOTTOM
	confirm_center.offset_left = 0.0
	confirm_center.offset_top = 0.0
	confirm_center.offset_right = 0.0
	confirm_center.offset_bottom = 0.0


func hide_drag_preview() -> void:
	drag_preview_panel.visible = false
	hide_drag_drop_target_hint()


func hide_drag_drop_target_hint() -> void:
	drag_drop_target_panel.visible = false


func _show_drag_drop_target_hint(data: Dictionary) -> void:
	if data.is_empty():
		hide_drag_drop_target_hint()
		return
	var rect_variant: Variant = data.get("target_rect", Rect2())
	var target_rect: Rect2 = rect_variant if rect_variant is Rect2 else Rect2()
	if target_rect.size.x <= 2.0 or target_rect.size.y <= 2.0:
		hide_drag_drop_target_hint()
		return
	var valid := bool(data.get("valid", false))
	var accent := Color("#22c55e") if valid else Color("#fb7185")
	drag_drop_target_panel.position = target_rect.position
	drag_drop_target_panel.size = target_rect.size
	drag_drop_target_panel.custom_minimum_size = target_rect.size
	drag_drop_target_panel.tooltip_text = str(data.get("tooltip", data.get("label", "")))
	drag_drop_target_label.text = _short_text(str(data.get("label", "松开出牌" if valid else "拖到星球地图")), 18)
	drag_drop_target_label.tooltip_text = drag_drop_target_panel.tooltip_text
	drag_drop_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	drag_drop_target_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	drag_drop_target_label.add_theme_color_override("font_color", accent.lightened(0.25))
	var fill := Color("#020617").lerp(accent, 0.16)
	fill.a = 0.14 if valid else 0.08
	drag_drop_target_panel.add_theme_stylebox_override("panel", _panel_style(accent, fill, 3 if valid else 2, 8))
	drag_drop_target_panel.visible = true


func _apply_drag_preview_style(drop_hint: Dictionary) -> void:
	var valid := bool(drop_hint.get("valid", false))
	var accent := Color("#22c55e") if valid else Color("#f59e0b")
	if not drop_hint.is_empty() and not valid:
		accent = Color("#fb7185")
	var fill := Color("#020617").lerp(accent, 0.12)
	fill.a = 0.92
	drag_preview_panel.add_theme_stylebox_override("panel", _panel_style(accent, fill, 2, 8))
	drag_preview_label.add_theme_color_override("font_color", Color("#e2e8f0"))


func _clamped_overlay_position(panel: Control, desired_position: Vector2) -> Vector2:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var panel_size := panel.size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = panel.custom_minimum_size
	return Vector2(
		clampf(desired_position.x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0)),
		clampf(desired_position.y, 8.0, maxf(8.0, viewport_size.y - panel_size.y - 8.0))
	)


func _drag_preview_position(panel: Control, desired_position: Vector2, drop_hint: Dictionary) -> Vector2:
	if not _should_dock_invalid_drag_preview(drop_hint):
		return _clamped_overlay_position(panel, desired_position)
	var rect_variant: Variant = drop_hint.get("target_rect", Rect2())
	var target_rect: Rect2 = rect_variant if rect_variant is Rect2 else Rect2()
	return _side_lane_drag_preview_position(panel, desired_position, target_rect)


func _should_dock_invalid_drag_preview(drop_hint: Dictionary) -> bool:
	if drop_hint.is_empty() or bool(drop_hint.get("valid", false)):
		return false
	var label := str(drop_hint.get("label", "")).strip_edges()
	if label == "" or label.contains("拖到星球地图"):
		return false
	var rect_variant: Variant = drop_hint.get("target_rect", Rect2())
	var target_rect: Rect2 = rect_variant if rect_variant is Rect2 else Rect2()
	return target_rect.size.x > 2.0 and target_rect.size.y > 2.0


func _side_lane_drag_preview_position(panel: Control, desired_position: Vector2, target_rect: Rect2) -> Vector2:
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var panel_size := panel.size
	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = panel.custom_minimum_size
	var right_x := target_rect.position.x + target_rect.size.x + DRAG_PREVIEW_SIDE_GAP
	var left_x := target_rect.position.x - panel_size.x - DRAG_PREVIEW_SIDE_GAP
	var x := right_x
	if x + panel_size.x > viewport_size.x - 8.0 and left_x >= 8.0:
		x = left_x
	x = clampf(x, 8.0, maxf(8.0, viewport_size.x - panel_size.x - 8.0))
	var y := desired_position.y - panel_size.y * 0.5
	var min_y := maxf(8.0, target_rect.position.y + DRAG_PREVIEW_SIDE_GAP)
	var max_y := minf(maxf(8.0, viewport_size.y - panel_size.y - 8.0), target_rect.position.y + target_rect.size.y - panel_size.y - DRAG_PREVIEW_SIDE_GAP)
	if max_y < min_y:
		max_y = min_y
	y = clampf(y, min_y, max_y)
	return Vector2(x, y)


func _set_label_chip_row(row: HFlowContainer, entries_variant: Variant) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"text": str(entry_variant)}
		var label := _drawer_chip_label(entry)
		if label.text.strip_edges() != "":
			row.add_child(label)


func _set_side_drawer_sections(entries_variant: Variant) -> void:
	for child in side_drawer_section_list.get_children():
		side_drawer_section_list.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	side_drawer_section_list.visible = not entries.is_empty()
	for index in range(entries.size()):
		var entry: Dictionary = entries[index] if entries[index] is Dictionary else {"body": str(entries[index])}
		var body := str(entry.get("body", entry.get("text", ""))).strip_edges()
		if body == "":
			continue
		side_drawer_section_list.add_child(_drawer_section_card(entry, index))


func _drawer_section_card(entry: Dictionary, index: int) -> PanelContainer:
	var accent := _entry_color(entry, Color("#38bdf8") if index % 2 == 0 else Color("#f59e0b"))
	var panel := PanelContainer.new()
	panel.name = "SideDrawerSectionCard%d" % (index + 1)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.tooltip_text = str(entry.get("tooltip", ""))
	panel.add_theme_stylebox_override("panel", _panel_style(accent, Color("#020617").lerp(accent, 0.08), 1, 6))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "SideDrawerSectionRows"
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)
	var title_text := str(entry.get("title", entry.get("label", ""))).strip_edges()
	if title_text != "":
		var title := Label.new()
		title.name = "SideDrawerSectionTitle"
		title.text = title_text
		title.tooltip_text = panel.tooltip_text
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size", 11)
		title.add_theme_color_override("font_color", accent.lightened(0.18))
		rows.add_child(title)
	var body := Label.new()
	body.name = "SideDrawerSectionBody"
	body.text = _short_text(str(entry.get("body", entry.get("text", ""))).strip_edges(), SIDE_DRAWER_SECTION_BODY_LIMIT)
	body.tooltip_text = panel.tooltip_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("#e2e8f0"))
	rows.add_child(body)
	return panel


func _drawer_chip_label(entry: Dictionary) -> Label:
	var label := Label.new()
	label.name = "SideDrawerChip"
	label.text = _short_text(str(entry.get("text", entry.get("label", ""))), 14)
	label.tooltip_text = str(entry.get("tooltip", ""))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", _entry_color(entry, Color("#cbd5e1")).lightened(0.12))
	return label


func _set_side_drawer_action_row(entries_variant: Variant) -> void:
	for child in side_drawer_action_row.get_children():
		side_drawer_action_row.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"id": str(entry_variant), "label": str(entry_variant)}
		var action_id := str(entry.get("id", ""))
		var button := Button.new()
		button.name = "SideDrawerActionButton"
		button.text = _short_text(str(entry.get("label", entry.get("text", "打开"))), 12)
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.disabled = action_id.strip_edges() == ""
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			side_drawer_action_requested.emit(action_id)
		)
		side_drawer_action_row.add_child(button)


func _set_temporary_decision_action_row(entries_variant: Variant) -> void:
	for child in confirm_action_row.get_children():
		confirm_action_row.remove_child(child)
		child.queue_free()
	var entries: Array = entries_variant if entries_variant is Array else []
	confirm_action_row.visible = not entries.is_empty()
	confirm_action_row.columns = clampi(entries.size(), 1, 2)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {"id": str(entry_variant), "label": str(entry_variant)}
		var action_id := str(entry.get("id", ""))
		var button := Button.new()
		button.name = "TemporaryDecisionActionButton"
		button.text = _short_text(str(entry.get("label", entry.get("text", "选择"))), 12)
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.disabled = action_id.strip_edges() == "" or bool(entry.get("disabled", false))
		button.custom_minimum_size = Vector2(142, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			temporary_decision_action_requested.emit(action_id)
		)
		confirm_action_row.add_child(button)


func _entry_color(entry: Dictionary, fallback: Color) -> Color:
	var value: Variant = entry.get("accent", entry.get("color", fallback))
	if value is Color:
		return value as Color
	if value is String and str(value).begins_with("#"):
		return Color(str(value))
	return fallback


func _short_text(value: String, limit: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if limit <= 0 or text.length() <= limit:
		return text
	return "%s…" % text.substr(0, maxi(1, limit - 1))


func _panel_style(accent: Color, fill: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
