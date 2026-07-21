extends CanvasLayer
class_name SpaceSyndicateOverlayLayer

const FOCUS_TOOLS := preload("res://scripts/ui/focus_tools.gd")

signal side_drawer_action_requested(action_id: String)
signal temporary_decision_action_requested(action_id: String)
signal public_bid_action_requested(action_id: String)
signal public_bid_track_link_hovered(action_id: String)
signal public_bid_track_link_unhovered(action_id: String)
signal map_layer_focus_requested(layer_id: String)

@onready var tooltip_panel: PanelContainer = %TooltipPanel
@onready var tooltip_label: Label = %TooltipLabel
@onready var confirm_panel: PanelContainer = %ConfirmPanel
@onready var confirm_label: Label = %ConfirmLabel
@onready var confirm_chip_row: HFlowContainer = %ConfirmChipRow
@onready var confirm_action_row: GridContainer = %ConfirmActionRow
@onready var confirm_center: CenterContainer = $OverlayRoot/ModalLayer/ConfirmCenter
@onready var monster_wager_decision_panel: Control = %MonsterWagerDecisionPanel
@onready var temporary_choice_decision_panel: Control = %TemporaryChoiceDecisionPanel
@onready var public_bid_decision_panel: Control = %PublicBidDecisionPanel
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
@onready var district_supply_drawer: Control = %DistrictSupplySideDrawerOverlay
@onready var map_control_toolbar: PlanetMapControlToolbar = get_node_or_null(
	"RuntimeSurfaceLayer/FullscreenMapOverlay/FullscreenMapMargin/FullscreenMapRows/FullscreenMapToolbar/FullscreenMapActionHost/PlanetMapControlToolbar"
) as PlanetMapControlToolbar
@onready var fullscreen_map_layer_hud_label: Label = get_node_or_null(
	"RuntimeSurfaceLayer/FullscreenMapOverlay/FullscreenMapMargin/FullscreenMapRows/FullscreenMapReadingHud/FullscreenMapHudMargin/FullscreenMapLayerHud/FullscreenMapLayerChip/ChipMargin/FullscreenMapLayerHudLabel"
) as Label
@onready var fullscreen_planet_map_view: SpaceSyndicatePlanetMapView = get_node_or_null(
	"RuntimeSurfaceLayer/FullscreenMapOverlay/FullscreenMapMargin/FullscreenMapRows/FullscreenMapHost/FullscreenPlanetMapView"
) as SpaceSyndicatePlanetMapView

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
const TEMP_DECISION_DISCARD := "discard_purchase"
const TEMP_DECISION_MONSTER_TARGET := "monster_target_choice"
const TEMP_DECISION_PLAYER_TARGET := "player_target_choice"
const REAL_TEMPORARY_DECISION_KINDS := [
	TEMP_DECISION_MONSTER_WAGER,
	"counter_response",
	TEMP_DECISION_DISCARD,
	TEMP_DECISION_MONSTER_TARGET,
	TEMP_DECISION_PLAYER_TARGET,
]
const SURFACE_CONFIRM := "confirm"
const SURFACE_SIDE_DRAWER := "side_drawer"
const SURFACE_DISTRICT_SUPPLY := "district_supply"
const SURFACE_ROUTE_VIEW := "route_view"

var _surface_stack: Array[Dictionary] = []
var _surface_context_revision := 0
var _active_forced_surface_id := ""
var _forced_focus_restore_path := ""
var _district_supply_presentation_apply_count := 0
var _district_supply_presentation_reject_count := 0
var _last_district_supply_visibility_scope := "closed"


func _ready() -> void:
	add_to_group("optional_route_overlay")
	set_process_input(true)
	_configure_pointer_passthrough_skeleton()
	_dock_confirm_to_planet_side_lane()
	side_drawer_close_button.pressed.connect(hide_side_drawer)
	_connect_specialized_temporary_decision_panels()
	_connect_public_bid_panel()
	if map_control_toolbar != null and not map_control_toolbar.map_layer_focus_requested.is_connected(_on_map_layer_focus_requested):
		map_control_toolbar.map_layer_focus_requested.connect(_on_map_layer_focus_requested)
	if district_supply_drawer != null and not district_supply_drawer.visibility_changed.is_connected(_on_district_supply_visibility_changed):
		district_supply_drawer.visibility_changed.connect(_on_district_supply_visibility_changed)


func _input(event: InputEvent) -> void:
	if event == null or not _is_back_event(event):
		return
	if handle_back_request():
		get_viewport().set_input_as_handled()


func handle_back_request() -> bool:
	if tooltip_panel != null and tooltip_panel.visible:
		hide_tooltip()
		return true
	var top := _top_surface_entry()
	if not top.is_empty():
		if bool(top.get("forced", false)):
			return true
		if bool(top.get("dismissible", false)):
			_dismiss_surface(str(top.get("surface_id", "")))
			return true
	if _active_forced_surface_id != "":
		return true
	if district_supply_drawer != null and district_supply_drawer.visible:
		_request_district_supply_close()
		return true
	return false


func presentation_fullscreen_planet_target() -> SpaceSyndicatePlanetMapView:
	return fullscreen_planet_map_view


func _on_map_layer_focus_requested(layer_id: String) -> void:
	map_layer_focus_requested.emit(layer_id)


func set_selected_map_layer_focus(layer_id: String) -> void:
	if map_control_toolbar != null:
		map_control_toolbar.set_selected_map_layer_focus(layer_id)
		var status := map_control_toolbar.selected_map_layer_status()
		if fullscreen_map_layer_hud_label != null:
			fullscreen_map_layer_hud_label.text = str(status.get("text", "图层:全图"))
			fullscreen_map_layer_hud_label.tooltip_text = str(status.get("tooltip", "当前全屏地图图层。"))


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
	if forced_surface_active():
		return
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
	_push_surface(SURFACE_CONFIRM, "confirmation", confirm_panel, null, true, false, "show_confirm")


func hide_confirm(restore_focus := true) -> void:
	confirm_panel.visible = false
	confirm_panel.name = "ConfirmPanel"
	_hide_specialized_temporary_decision_panels()
	var removed_forced := false
	if _active_forced_surface_id != "" and _active_forced_surface_id != "forced:public_bid":
		_remove_surface(_active_forced_surface_id, restore_focus)
		_active_forced_surface_id = ""
		removed_forced = true
	_remove_surface(SURFACE_CONFIRM, restore_focus)
	if removed_forced and restore_focus:
		_forced_focus_restore_path = ""


func show_temporary_decision(data: Dictionary) -> void:
	if data.is_empty():
		hide_confirm()
		return
	var kind := str(data.get("kind", "")).strip_edges()
	if not REAL_TEMPORARY_DECISION_KINDS.has(kind):
		hide_confirm()
		return
	hide_public_bid(false)
	_dock_confirm_to_planet_side_lane()
	_hide_specialized_temporary_decision_panels()
	if kind == TEMP_DECISION_MONSTER_WAGER and _show_specialized_temporary_decision(monster_wager_decision_panel, data):
		confirm_panel.visible = false
		_activate_forced_surface(data, monster_wager_decision_panel)
		return
	if [TEMP_DECISION_DISCARD, TEMP_DECISION_MONSTER_TARGET, TEMP_DECISION_PLAYER_TARGET].has(kind) and _show_specialized_temporary_decision(temporary_choice_decision_panel, data):
		confirm_panel.visible = false
		_activate_forced_surface(data, temporary_choice_decision_panel)
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
	_activate_forced_surface(data, confirm_panel)


func show_public_bid(data: Dictionary) -> bool:
	if str(data.get("phase_id", "")).strip_edges() != "public_bid":
		hide_public_bid()
		return false
	hide_confirm(false)
	_dock_confirm_to_planet_side_lane()
	var snapshot := data.duplicate(true)
	snapshot["visible"] = true
	snapshot["title"] = "牌序竞价"
	if public_bid_decision_panel == null or not public_bid_decision_panel.has_method("set_bid_state"):
		return false
	public_bid_decision_panel.call("set_bid_state", snapshot)
	public_bid_decision_panel.visible = true
	_activate_forced_surface({
		"id": "public_bid",
		"kind": "public_bid",
		"opened_by_action_id": "card_resolution_public_bid",
	}, public_bid_decision_panel)
	return true


func hide_public_bid(restore_focus := true) -> void:
	if public_bid_decision_panel != null:
		if public_bid_decision_panel.has_method("set_bid_state"):
			public_bid_decision_panel.call("set_bid_state", {"visible": false})
		public_bid_decision_panel.visible = false
	var surface_id := "forced:public_bid"
	if _active_forced_surface_id == surface_id:
		_active_forced_surface_id = ""
	_remove_surface(surface_id, restore_focus)
	if restore_focus:
		_forced_focus_restore_path = ""


func public_bid_visible() -> bool:
	return public_bid_decision_panel != null and public_bid_decision_panel.visible


func forced_surface_active() -> bool:
	return not _active_forced_surface_id.is_empty()


func _connect_specialized_temporary_decision_panels() -> void:
	for panel in [monster_wager_decision_panel, temporary_choice_decision_panel]:
		if panel != null and panel.has_signal("action_requested"):
			panel.connect("action_requested", Callable(self, "_on_specialized_temporary_decision_action_requested"))


func _connect_public_bid_panel() -> void:
	if public_bid_decision_panel == null:
		return
	if public_bid_decision_panel.has_signal("action_requested"):
		public_bid_decision_panel.connect("action_requested", Callable(self, "_on_public_bid_action_requested"))
	if public_bid_decision_panel.has_signal("track_link_hovered"):
		public_bid_decision_panel.connect("track_link_hovered", Callable(self, "_on_public_bid_track_link_hovered"))
	if public_bid_decision_panel.has_signal("track_link_unhovered"):
		public_bid_decision_panel.connect("track_link_unhovered", Callable(self, "_on_public_bid_track_link_unhovered"))


func _on_public_bid_action_requested(action_id: String) -> void:
	public_bid_action_requested.emit(action_id)


func _on_public_bid_track_link_hovered(action_id: String) -> void:
	public_bid_track_link_hovered.emit(action_id)


func _on_public_bid_track_link_unhovered(action_id: String) -> void:
	public_bid_track_link_unhovered.emit(action_id)


func _on_specialized_temporary_decision_action_requested(action_id: String) -> void:
	temporary_decision_action_requested.emit(action_id)


func _show_specialized_temporary_decision(panel: Control, data: Dictionary) -> bool:
	if panel == null or not panel.has_method("set_decision"):
		return false
	panel.call("set_decision", data)
	panel.visible = true
	return true


func _hide_specialized_temporary_decision_panels() -> void:
	for panel in [monster_wager_decision_panel, temporary_choice_decision_panel]:
		if panel != null:
			panel.visible = false


func show_side_drawer(data: Dictionary) -> bool:
	if forced_surface_active():
		return false
	side_drawer_title.text = _short_text(str(data.get("title", "详情抽屉")), 18)
	var sections: Array = data.get("sections", []) if data.get("sections", []) is Array else []
	side_drawer_summary.text = _short_text(str(data.get("body", data.get("summary", ""))), SIDE_DRAWER_SUMMARY_LIMIT)
	side_drawer_summary.visible = side_drawer_summary.text.strip_edges() != "" and sections.is_empty()
	_set_side_drawer_sections(sections)
	_set_label_chip_row(side_drawer_chip_row, data.get("chips", []))
	_set_side_drawer_action_row(data.get("actions", data.get("links", [])))
	side_drawer_panel.visible = true
	_push_surface(SURFACE_SIDE_DRAWER, "player_opened", side_drawer_panel, null, true, false, str(data.get("opened_by_action_id", "side_drawer")))
	if side_drawer_body_scroll != null:
		side_drawer_body_scroll.scroll_vertical = 0
	return true


func hide_side_drawer() -> void:
	side_drawer_panel.visible = false
	_remove_surface(SURFACE_SIDE_DRAWER, true)


func activate_optional_route_view(opener: Control = null) -> bool:
	if forced_surface_active():
		return false
	_push_surface(SURFACE_ROUTE_VIEW, "player_opened", null, opener, true, false, "optional_route_presentation_open")
	return true


func deactivate_optional_route_view(restore_focus := true) -> void:
	_remove_surface(SURFACE_ROUTE_VIEW, restore_focus)


func apply_district_supply_presentation(
	surface: Dictionary,
	viewer_index: int,
	authorization_revision: int
) -> bool:
	var drawer := district_supply_drawer as SpaceSyndicateDistrictSupplyDrawer
	if drawer == null:
		_district_supply_presentation_reject_count += 1
		return false
	if int(surface.get("viewer_index", -1)) != viewer_index \
			or int(surface.get("authorization_revision", 0)) != authorization_revision \
			or (str(surface.get("visibility_scope", "closed")) == "viewer_private" \
				and int(surface.get("subject_player_index", -1)) != viewer_index):
		_clear_district_supply_presentation(drawer)
		_district_supply_presentation_reject_count += 1
		return false
	var should_show := bool(surface.get("visible", false))
	var snapshot: Dictionary = surface.get("snapshot", {}) if surface.get("snapshot", {}) is Dictionary else {}
	if not should_show:
		_clear_district_supply_presentation(drawer)
		_district_supply_presentation_apply_count += 1
		return true
	if forced_surface_active() or snapshot.is_empty():
		_district_supply_presentation_reject_count += 1
		return false
	drawer.set_supply(snapshot)
	drawer.visible = true
	_last_district_supply_visibility_scope = str(surface.get("visibility_scope", "public"))
	_district_supply_presentation_apply_count += 1
	return true


func clear_district_supply_presentation() -> void:
	var drawer := district_supply_drawer as SpaceSyndicateDistrictSupplyDrawer
	if drawer != null:
		_clear_district_supply_presentation(drawer)


func district_supply_presentation_target_snapshot() -> Dictionary:
	return {
		"apply_count": _district_supply_presentation_apply_count,
		"reject_count": _district_supply_presentation_reject_count,
		"last_visibility_scope": _last_district_supply_visibility_scope,
		"visible": district_supply_drawer.visible if district_supply_drawer != null else false,
		"owns_gameplay_state": false,
		"owns_purchase_quote": false,
		"references_main": false,
	}


func _clear_district_supply_presentation(drawer: SpaceSyndicateDistrictSupplyDrawer) -> void:
	drawer.clear_supply()
	drawer.visible = false
	_last_district_supply_visibility_scope = "closed"


func transient_surface_stack_snapshot() -> Dictionary:
	var entries: Array = []
	for entry in _surface_stack:
		var safe := (entry as Dictionary).duplicate(true)
		safe.erase("control")
		entries.append(safe)
	return {
		"stack_depth": entries.size(),
		"entries": entries,
		"active_forced_surface_id": _active_forced_surface_id,
		"public_bid_visible": public_bid_visible(),
		"side_drawer_visible": side_drawer_panel.visible if side_drawer_panel != null else false,
		"district_supply_visible": district_supply_drawer.visible if district_supply_drawer != null else false,
	}


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


func _is_back_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
	return event.is_action_pressed("ui_cancel") \
		or (event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE)


func _activate_forced_surface(data: Dictionary, control: Control) -> void:
	var decision_id := str(data.get("id", data.get("kind", "decision"))).strip_edges()
	if decision_id.is_empty():
		decision_id = "decision"
	var surface_id := "forced:%s" % decision_id
	if _forced_focus_restore_path.is_empty():
		_forced_focus_restore_path = _forced_restore_path_candidate()
	_close_player_opened_surfaces_for_forced()
	if _active_forced_surface_id != "" and _active_forced_surface_id != surface_id:
		_remove_surface(_active_forced_surface_id, false)
	_active_forced_surface_id = surface_id
	_push_surface(
		surface_id,
		str(data.get("kind", "forced_decision")),
		control,
		null,
		false,
		true,
		str(data.get("opened_by_action_id", decision_id)),
		_forced_focus_restore_path
	)


func _push_surface(
	surface_id: String,
	surface_kind: String,
	control: Control,
	opener: Control,
	dismissible: bool,
	forced: bool,
	opened_by_action_id: String,
	focus_restore_path_override := ""
) -> void:
	if surface_id.is_empty():
		return
	for index in range(_surface_stack.size() - 1, -1, -1):
		var existing: Dictionary = _surface_stack[index]
		if str(existing.get("surface_id", "")) != surface_id:
			continue
		existing["surface_kind"] = surface_kind
		existing["control"] = control
		existing["dismissible"] = dismissible
		existing["forced"] = forced
		existing["context_revision"] = _surface_context_revision
		_surface_stack[index] = existing
		var focused := _current_focus_control()
		if control != null and (focused == null or (focused != control and not control.is_ancestor_of(focused))):
			call_deferred("_focus_surface", control)
		return
	_surface_context_revision += 1
	var restore_control := opener if opener != null else _current_focus_control()
	var restore_path := focus_restore_path_override
	if restore_path.is_empty():
		restore_path = str(restore_control.get_path()) if restore_control != null and restore_control.is_inside_tree() else ""
	_surface_stack.append({
		"surface_id": surface_id,
		"surface_kind": surface_kind,
		"focus_restore_path": restore_path,
		"opened_by_action_id": opened_by_action_id,
		"context_revision": _surface_context_revision,
		"dismissible": dismissible,
		"forced": forced,
		"control": control,
	})
	if control != null:
		call_deferred("_focus_surface", control)


func _remove_surface(surface_id: String, restore_focus: bool) -> void:
	if surface_id.is_empty():
		return
	for index in range(_surface_stack.size() - 1, -1, -1):
		var entry: Dictionary = _surface_stack[index]
		if str(entry.get("surface_id", "")) != surface_id:
			continue
		_surface_stack.remove_at(index)
		var control: Control = entry.get("control", null) as Control
		_release_surface_focus(control)
		if restore_focus:
			_restore_surface_focus(str(entry.get("focus_restore_path", "")))
		return


func _top_surface_entry() -> Dictionary:
	if _surface_stack.is_empty():
		return {}
	return (_surface_stack[_surface_stack.size() - 1] as Dictionary).duplicate(true)


func _dismiss_surface(surface_id: String) -> void:
	match surface_id:
		SURFACE_CONFIRM:
			hide_confirm()
		SURFACE_SIDE_DRAWER:
			hide_side_drawer()
		SURFACE_DISTRICT_SUPPLY:
			_request_district_supply_close()
		SURFACE_ROUTE_VIEW:
			get_tree().call_group("optional_route_presentation_views", "hide_optional_route_presentation")
			get_tree().call_group("optional_route_presentation_toolbars", "sync_optional_route_hidden")
			deactivate_optional_route_view()
		_:
			_remove_surface(surface_id, true)


func _focus_surface(control: Control) -> void:
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree():
		return
	FOCUS_TOOLS.focus_first_enabled(control)


func _current_focus_control() -> Control:
	if get_viewport() == null:
		return null
	return get_viewport().gui_get_focus_owner()


func _forced_restore_path_candidate() -> String:
	for index in range(_surface_stack.size() - 1, -1, -1):
		var entry: Dictionary = _surface_stack[index]
		if bool(entry.get("forced", false)):
			continue
		var restore_path := str(entry.get("focus_restore_path", ""))
		if not restore_path.is_empty():
			return restore_path
	var focused := _current_focus_control()
	return str(focused.get_path()) if focused != null and focused.is_inside_tree() else ""


func _close_player_opened_surfaces_for_forced() -> void:
	if confirm_panel != null and confirm_panel.visible and confirm_panel.name == "ConfirmPanel":
		confirm_panel.visible = false
		_remove_surface(SURFACE_CONFIRM, false)
	if side_drawer_panel != null and side_drawer_panel.visible:
		side_drawer_panel.visible = false
		_remove_surface(SURFACE_SIDE_DRAWER, false)
	if district_supply_drawer != null and district_supply_drawer.visible:
		_remove_surface(SURFACE_DISTRICT_SUPPLY, false)
		_request_district_supply_close()
	if _surface_stack.any(func(entry: Dictionary) -> bool: return str(entry.get("surface_id", "")) == SURFACE_ROUTE_VIEW):
		get_tree().call_group("optional_route_presentation_views", "hide_optional_route_presentation")
		get_tree().call_group("optional_route_presentation_toolbars", "sync_optional_route_hidden")
		_remove_surface(SURFACE_ROUTE_VIEW, false)


func _release_surface_focus(control: Control) -> void:
	if control == null:
		return
	var focused := _current_focus_control()
	if focused == null:
		return
	if focused == control or control.is_ancestor_of(focused):
		focused.release_focus()


func _restore_surface_focus(path: String) -> void:
	if path.is_empty():
		return
	var target := get_node_or_null(NodePath(path)) as Control
	if target != null and target.is_inside_tree() and target.is_visible_in_tree() and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
		return
	var parent_path := path.get_base_dir()
	while not parent_path.is_empty() and parent_path != "." and parent_path != "/":
		var parent := get_node_or_null(NodePath(parent_path))
		if parent != null and parent.is_inside_tree():
			var fallback := FOCUS_TOOLS.focus_first_enabled(parent)
			if fallback != null:
				return
		parent_path = parent_path.get_base_dir()


func _on_district_supply_visibility_changed() -> void:
	if district_supply_drawer == null:
		return
	if district_supply_drawer.visible:
		if forced_surface_active():
			_request_district_supply_close()
			return
		_push_surface(SURFACE_DISTRICT_SUPPLY, "player_opened", district_supply_drawer, null, true, false, "open_district_supply")
	else:
		_remove_surface(SURFACE_DISTRICT_SUPPLY, true)


func _request_district_supply_close() -> void:
	if district_supply_drawer == null:
		_remove_surface(SURFACE_DISTRICT_SUPPLY, true)
		return
	if district_supply_drawer.has_signal("supply_action_requested"):
		district_supply_drawer.emit_signal("supply_action_requested", "district_supply_close", {})
	else:
		district_supply_drawer.visible = false
