extends Control
class_name SpaceSyndicateGameScreen

const TABLE_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/table_snapshot.gd")
const OVERLAY_LAYER_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/overlay_layer_snapshot.gd")
const PLANET_RIGHT_SIDE_LANE_LEFT := 0.635
const PLANET_RIGHT_SIDE_LANE_TOP := 0.145
const PLANET_RIGHT_SIDE_LANE_RIGHT := 0.790
const PLANET_RIGHT_SIDE_LANE_BOTTOM := 0.285
const PLANET_RIGHT_SIDE_LANE_FOCUS_BOTTOM := 0.270
const HAND_HOVER_PREVIEW_LEFT := 0.020
const HAND_HOVER_PREVIEW_TOP := 0.350
const HAND_HOVER_PREVIEW_RIGHT := 0.190
const HAND_HOVER_PREVIEW_BOTTOM := 0.880
const HAND_HOVER_PREVIEW_CARD_MIN_SIZE := Vector2(216, 292)

signal end_turn_requested
signal action_requested(action_id: String)
signal card_selected(card_data: Dictionary)
signal card_hovered(card_data: Dictionary)
signal card_unhovered
signal card_unselected(card_data: Dictionary)
signal card_drag_preview_started(card_data: Dictionary)
signal card_drag_preview_ended(card_data: Dictionary)
signal card_drop_requested(card_data: Dictionary, screen_position: Vector2)

@onready var top_bar: Node = %TopBar
@onready var public_track: Node = get_node_or_null("%PublicTrack")
@onready var card_track: Node = get_node_or_null("%CardTrack")
@onready var first_run_coach: Node = get_node_or_null("%FirstRunCoach")
@onready var scenario_coach: Node = get_node_or_null("%ScenarioCoach")
@onready var track_focus_ribbon: PanelContainer = get_node_or_null("%TrackFocusRibbon") as PanelContainer
@onready var track_focus_label: Label = get_node_or_null("%TrackFocusLabel") as Label
@onready var planet_board: Node = %PlanetBoard
@onready var right_inspector: Node = %RightInspector
@onready var player_board: Node = %PlayerBoard
@onready var visual_event_layer: Node = get_node_or_null("%RuntimeVisualEventLayer")
@onready var overlay_layer: Node = %OverlayLayer
@onready var scenario_coach_host: Control = get_node_or_null("ScenarioCoachHost") as Control
@onready var first_run_coach_host: Control = get_node_or_null("FirstRunCoachHost") as Control
@onready var focus_guide_layer: Node = get_node_or_null("%FocusGuideLayer")
@onready var hand_hover_preview_host: Control = get_node_or_null("%HandHoverPreviewHost") as Control
@onready var hand_hover_preview_panel: PanelContainer = get_node_or_null("%HandHoverPreviewPanel") as PanelContainer
@onready var hand_hover_preview_title: Label = get_node_or_null("%HandHoverPreviewTitle") as Label
@onready var hand_hover_preview_card: Control = get_node_or_null("%HandHoverPreviewCard") as Control

var current_ui_data: Dictionary = {}
var _temporary_track_focus_active := false
var _selected_hand_card_data: Dictionary = {}
var _last_visual_event_key := ""
var _campaign_focus_layout := false
var _last_focus_guide_data: Dictionary = {}

func _ready() -> void:
	_configure_track_focus_ribbon()
	_configure_focus_guide()
	_configure_hand_hover_preview()
	if top_bar.has_signal("end_turn_requested"):
		top_bar.connect("end_turn_requested", Callable(self, "_on_end_turn_requested"))
	if top_bar.has_signal("menu_requested"):
		top_bar.connect("menu_requested", Callable(self, "_on_menu_requested"))
	var track_node := _public_track_node()
	if track_node != null and track_node.has_signal("track_entry_selected"):
		track_node.connect("track_entry_selected", Callable(self, "_on_track_entry_selected"))
	if track_node != null and track_node.has_signal("track_entry_opened"):
		track_node.connect("track_entry_opened", Callable(self, "_on_track_entry_opened"))
	if track_node != null and track_node.has_signal("track_entry_hovered"):
		track_node.connect("track_entry_hovered", Callable(self, "_on_track_entry_hovered"))
	if track_node != null and track_node.has_signal("track_entry_unhovered"):
		track_node.connect("track_entry_unhovered", Callable(self, "_on_track_entry_unhovered"))
	if first_run_coach != null and first_run_coach.has_signal("primary_action_requested"):
		first_run_coach.connect("primary_action_requested", Callable(self, "_on_action_requested"))
	if scenario_coach != null and scenario_coach.has_signal("action_requested"):
		scenario_coach.connect("action_requested", Callable(self, "_on_action_requested"))
	if right_inspector.has_signal("action_requested"):
		right_inspector.connect("action_requested", Callable(self, "_on_action_requested"))
	if player_board.has_signal("card_selected"):
		player_board.connect("card_selected", Callable(self, "_on_card_selected"))
	if player_board.has_signal("card_hovered"):
		player_board.connect("card_hovered", Callable(self, "_on_card_hovered"))
	if player_board.has_signal("card_unhovered"):
		player_board.connect("card_unhovered", Callable(self, "_on_card_unhovered"))
	if player_board.has_signal("card_unselected"):
		player_board.connect("card_unselected", Callable(self, "_on_card_unselected"))
	if player_board.has_signal("card_drag_preview_started"):
		player_board.connect("card_drag_preview_started", Callable(self, "_on_card_drag_preview_started"))
	if player_board.has_signal("card_drag_preview_moved"):
		player_board.connect("card_drag_preview_moved", Callable(self, "_on_card_drag_preview_moved"))
	if player_board.has_signal("card_drag_preview_ended"):
		player_board.connect("card_drag_preview_ended", Callable(self, "_on_card_drag_preview_ended"))
	if player_board.has_signal("card_drag_released"):
		player_board.connect("card_drag_released", Callable(self, "_on_card_drag_released"))
	if player_board.has_signal("action_requested"):
		player_board.connect("action_requested", Callable(self, "_on_action_requested"))
	if player_board.has_signal("track_link_hovered"):
		player_board.connect("track_link_hovered", Callable(self, "_on_track_link_hovered"))
	if player_board.has_signal("track_link_unhovered"):
		player_board.connect("track_link_unhovered", Callable(self, "_on_track_link_unhovered"))
	if overlay_layer.has_signal("side_drawer_action_requested"):
		overlay_layer.connect("side_drawer_action_requested", Callable(self, "_on_side_drawer_action_requested"))
	if overlay_layer.has_signal("temporary_decision_action_requested"):
		overlay_layer.connect("temporary_decision_action_requested", Callable(self, "_on_temporary_decision_action_requested"))
	call_deferred("_sync_runtime_table_focus_order")


func apply_state(data: Dictionary) -> void:
	var ui_data: Dictionary = TABLE_SNAPSHOT_SCRIPT.new().apply_dictionary(data).to_ui_dictionary()
	current_ui_data = ui_data
	_sync_campaign_focus_layout(bool(ui_data.get("campaign_focus_mode", false)), ui_data)
	if top_bar.has_method("set_state"):
		top_bar.call("set_state", ui_data.get("top_bar", {}))
	var track_node := _public_track_node()
	if track_node != null and track_node.has_method("set_entries"):
		var track_entries: Variant = ui_data.get("card_track", [])
		track_node.call("set_entries", track_entries if track_entries is Array else [])
	if first_run_coach != null and first_run_coach.has_method("set_coach"):
		first_run_coach.call("set_coach", ui_data.get("first_run_coach", {}) if ui_data.get("first_run_coach", {}) is Dictionary else {})
	if scenario_coach != null and scenario_coach.has_method("set_coach"):
		scenario_coach.call("set_coach", ui_data.get("scenario_coach", {}) if ui_data.get("scenario_coach", {}) is Dictionary else {})
	if planet_board.has_method("set_board_state"):
		planet_board.call("set_board_state", ui_data.get("planet", {}))
	if right_inspector.has_method("set_context"):
		var inspector: Dictionary = ui_data.get("right_inspector", {}) if ui_data.get("right_inspector", {}) is Dictionary else {}
		right_inspector.call("set_context", inspector)
	if player_board.has_method("set_player_state"):
		player_board.call("set_player_state", ui_data.get("player_board", {}))
	_sync_visual_events(ui_data)
	if not _temporary_track_focus_active:
		_sync_selected_track_focus_from_state()
	_sync_temporary_decision_overlay(ui_data.get("temporary_decision", {}))
	_sync_focus_guide(ui_data)
	call_deferred("_sync_focus_guide_from_current_state")
	call_deferred("_sync_runtime_table_focus_order")


func _sync_campaign_focus_layout(enabled: bool, ui_data: Dictionary) -> void:
	_campaign_focus_layout = enabled
	if right_inspector is Control:
		var inspector := right_inspector as Control
		inspector.custom_minimum_size = Vector2(226, 0) if enabled else Vector2(292, 0)
	if scenario_coach_host != null:
		scenario_coach_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if enabled:
			_set_overlay_anchor_rect(scenario_coach_host, PLANET_RIGHT_SIDE_LANE_LEFT, PLANET_RIGHT_SIDE_LANE_TOP, PLANET_RIGHT_SIDE_LANE_RIGHT, PLANET_RIGHT_SIDE_LANE_FOCUS_BOTTOM)
		else:
			_set_overlay_anchor_rect(scenario_coach_host, PLANET_RIGHT_SIDE_LANE_LEFT, PLANET_RIGHT_SIDE_LANE_TOP, PLANET_RIGHT_SIDE_LANE_RIGHT, PLANET_RIGHT_SIDE_LANE_BOTTOM)
	if first_run_coach_host != null:
		first_run_coach_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scenario_data: Dictionary = ui_data.get("scenario_coach", {}) if ui_data.get("scenario_coach", {}) is Dictionary else {}
	if track_focus_ribbon != null and enabled and str(scenario_data.get("focus_target", "")) != "public_track":
		track_focus_ribbon.custom_minimum_size = Vector2(0, 18)
	elif track_focus_ribbon != null:
		track_focus_ribbon.custom_minimum_size = Vector2(0, 24)


func _set_overlay_anchor_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func attach_runtime_map(map_node: Control) -> void:
	if planet_board != null and planet_board.has_method("attach_runtime_map"):
		planet_board.call("attach_runtime_map", map_node)
	call_deferred("_sync_runtime_table_focus_order")


func get_overlay_host() -> Node:
	return overlay_layer


func get_visual_event_snapshot() -> Dictionary:
	if visual_event_layer != null and visual_event_layer.has_method("get_visual_event_snapshot"):
		return visual_event_layer.call("get_visual_event_snapshot") as Dictionary
	return {}


func runtime_focus_order_snapshot() -> Array:
	var controls := _runtime_table_focus_controls()
	var result: Array = []
	for index in range(controls.size()):
		var control: Control = controls[index]
		result.append({
			"name": control.name,
			"label": str(control.get_meta("runtime_focus_label", "")),
			"index": int(control.get_meta("runtime_focus_order_index", index)),
			"focus_mode": control.focus_mode,
			"focus_next": str(control.focus_next),
			"focus_previous": str(control.focus_previous),
			"visible": control.is_visible_in_tree(),
		})
	return result


func _sync_runtime_table_focus_order() -> void:
	var controls := _runtime_table_focus_controls()
	if controls.is_empty():
		return
	for index in range(controls.size()):
		var control: Control = controls[index]
		var next_control: Control = controls[wrapi(index + 1, 0, controls.size())]
		var previous_control: Control = controls[wrapi(index - 1, 0, controls.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next_control)
		control.focus_previous = control.get_path_to(previous_control)
		control.set_meta("runtime_focus_order_index", index)
		control.set_meta("runtime_focus_kind", "table_focus_ring")


func _runtime_table_focus_controls() -> Array[Control]:
	var result: Array[Control] = []
	_append_runtime_focus_control(result, top_bar as Control, "顶部状态")
	_append_runtime_focus_control(result, _public_track_node() as Control, "牌轨")
	_append_runtime_focus_control(result, _runtime_map_focus_control(), "星球地图")
	_append_runtime_focus_control(result, right_inspector as Control, "右侧详情")
	_append_runtime_focus_control(result, _first_visible_control(["DistrictSupplyDrawer", "SideDrawerPanel"]), "区域牌架")
	_append_runtime_focus_control(result, _first_visible_control(["HandRack", "PlayerHandTableau", "PlayerBoard"]), "手牌")
	_append_runtime_focus_control(result, _first_visible_control(["PlayerMainActionDock", "PlayerCommandTableau", "PlayerBoard"]), "当前行动")
	_append_runtime_focus_control(result, _first_visible_control(["PlayerBidBoard", "PlayerCommandTableau"]), "竞价")
	return result


func _runtime_map_focus_control() -> Control:
	if planet_board != null and planet_board.has_method("get_runtime_map_focus_control"):
		var runtime_map: Variant = planet_board.call("get_runtime_map_focus_control")
		if runtime_map is Control and (runtime_map as Control).is_visible_in_tree():
			return runtime_map as Control
	return _first_visible_control(["MapHost", "PlanetStageViewport", "PlanetBoard"])


func _append_runtime_focus_control(result: Array[Control], control: Control, label: String) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	for existing in result:
		if existing == control:
			return
	control.set_meta("runtime_focus_label", label)
	result.append(control)


func _sync_visual_events(ui_data: Dictionary) -> void:
	if visual_event_layer == null or not visual_event_layer.has_method("set_visual_events"):
		return
	var key := str(ui_data.get("visual_event_key", ""))
	var events: Array = ui_data.get("visual_events", []) if ui_data.get("visual_events", []) is Array else []
	if key == "" or events.is_empty():
		return
	if key == _last_visual_event_key:
		return
	_last_visual_event_key = key
	visual_event_layer.call("set_visual_events", events, false)


func _public_track_node() -> Node:
	return public_track if public_track != null else card_track


func _on_end_turn_requested() -> void:
	end_turn_requested.emit()


func _on_menu_requested() -> void:
	action_requested.emit("menu")


func _on_action_requested(action_id: String) -> void:
	if _should_open_detail_drawer(action_id):
		_open_detail_drawer(action_id)
	action_requested.emit(action_id)


func _on_track_link_hovered(action_id: String) -> void:
	_set_public_track_hover(action_id)
	_show_track_action_hover_preview(action_id)


func _on_track_link_unhovered(_action_id: String) -> void:
	_set_public_track_hover("")
	_temporary_track_focus_active = false
	_restore_right_inspector_context()
	_sync_selected_track_focus_from_state()


func _set_public_track_hover(action_id: String) -> void:
	var track_node := _public_track_node()
	if track_node != null and track_node.has_method("set_hovered_track_action"):
		track_node.call("set_hovered_track_action", action_id)


func _on_track_entry_hovered(entry: Dictionary) -> void:
	_set_player_board_track_hover(_track_hover_action(entry))
	_show_track_entry_hover_preview(entry)
	_show_track_focus_for_entry(entry, "牌轨对照", true)


func _on_track_entry_unhovered(_entry: Dictionary) -> void:
	_set_player_board_track_hover("")
	_temporary_track_focus_active = false
	_restore_right_inspector_context()
	_sync_selected_track_focus_from_state()


func _set_player_board_track_hover(action_id: String) -> void:
	if player_board != null and player_board.has_method("set_hovered_track_action"):
		player_board.call("set_hovered_track_action", action_id)


func _show_track_entry_hover_preview(entry: Dictionary) -> void:
	if entry.is_empty() or right_inspector == null or not right_inspector.has_method("set_context"):
		return
	right_inspector.call("set_context", _track_entry_inspector_context(entry))


func _show_track_action_hover_preview(action_id: String) -> void:
	var entry := _track_entry_for_action(action_id)
	if entry.is_empty():
		_show_track_focus_for_action(action_id, true)
		return
	_show_track_entry_hover_preview(entry)
	_show_track_focus_for_entry(entry, "竞价对照", true)


func _on_side_drawer_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _on_temporary_decision_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or event == null:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if _should_ignore_quick_action_hotkey():
		return
	var quick_index := _quick_action_index_for_key(key_event)
	if quick_index < 0:
		return
	var action_id := _quick_action_id_at(quick_index)
	if action_id == "":
		return
	accept_event()
	_on_action_requested(action_id)


func _should_ignore_quick_action_hotkey() -> bool:
	if not is_visible_in_tree():
		return true
	var focused := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focused is LineEdit or focused is TextEdit:
		return true
	var decision: Dictionary = current_ui_data.get("temporary_decision", {}) if current_ui_data.get("temporary_decision", {}) is Dictionary else {}
	return not decision.is_empty()


func _quick_action_index_for_key(event: InputEventKey) -> int:
	var code := int(event.unicode)
	if code >= 49 and code <= 52:
		return code - 49
	return -1


func _quick_action_id_at(index: int) -> String:
	var player_data: Dictionary = current_ui_data.get("player_board", {}) if current_ui_data.get("player_board", {}) is Dictionary else {}
	var quick_actions: Array = player_data.get("quick_actions", []) if player_data.get("quick_actions", []) is Array else []
	if index < 0 or index >= quick_actions.size():
		return ""
	var action: Dictionary = quick_actions[index] if quick_actions[index] is Dictionary else {}
	if bool(action.get("disabled", false)) or not bool(action.get("active", false)):
		return ""
	return str(action.get("id", "")).strip_edges()


func _on_card_selected(card_data: Dictionary) -> void:
	_selected_hand_card_data = card_data.duplicate(true)
	if right_inspector.has_method("show_card"):
		right_inspector.call("show_card", card_data)
	card_selected.emit(card_data)


func _on_card_hovered(card_data: Dictionary) -> void:
	_show_hand_hover_preview(card_data)
	if right_inspector.has_method("show_card") and not card_data.is_empty():
		right_inspector.call("show_card", card_data)
	card_hovered.emit(card_data)


func _on_card_unhovered() -> void:
	_hide_hand_hover_preview()
	if not _selected_hand_card_data.is_empty() and right_inspector.has_method("show_card"):
		right_inspector.call("show_card", _selected_hand_card_data)
	else:
		_restore_right_inspector_context()
	card_unhovered.emit()


func _on_card_unselected(card_data: Dictionary) -> void:
	_selected_hand_card_data = {}
	_restore_right_inspector_context()
	card_unselected.emit(card_data)


func _on_track_entry_selected(entry: Dictionary) -> void:
	if right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(entry))
	_show_track_focus_for_entry(entry, "已选牌轨", false)
	var action_id := str(entry.get("select_action", "")).strip_edges()
	if action_id != "":
		action_requested.emit(action_id)


func _on_track_entry_opened(entry: Dictionary) -> void:
	if right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(entry))
	_show_track_focus_for_entry(entry, "打开牌轨", false)
	var action_id := str(entry.get("open_action", "")).strip_edges()
	if action_id != "":
		action_requested.emit(action_id)


func _on_card_drag_preview_started(card_data: Dictionary, screen_position: Vector2) -> void:
	_hide_hand_hover_preview()
	_show_card_drag_feedback(card_data, screen_position)
	card_drag_preview_started.emit(card_data)


func _on_card_drag_preview_moved(card_data: Dictionary, screen_position: Vector2) -> void:
	_show_card_drag_feedback(card_data, screen_position)


func _on_card_drag_preview_ended(card_data: Dictionary) -> void:
	if overlay_layer != null and overlay_layer.has_method("hide_drag_preview"):
		overlay_layer.call("hide_drag_preview")
	card_drag_preview_ended.emit(card_data)


func _on_card_drag_released(card_data: Dictionary, screen_position: Vector2) -> void:
	if _card_drop_zone_contains(screen_position) and _card_can_drop_on_map(card_data):
		card_drop_requested.emit(card_data, screen_position)


func _show_card_drag_feedback(card_data: Dictionary, screen_position: Vector2) -> void:
	if overlay_layer == null or not overlay_layer.has_method("show_drag_preview"):
		return
	var over_map := _card_drop_zone_contains(screen_position)
	var valid_drop := over_map and _card_can_drop_on_map(card_data)
	overlay_layer.call(
		"show_drag_preview",
		_drag_preview_text(card_data, over_map, valid_drop),
		screen_position + Vector2(14, -28),
		_drag_drop_hint(screen_position, over_map, valid_drop, card_data)
	)


func _drag_preview_text(card_data: Dictionary, over_map: bool = false, valid_drop: bool = false) -> String:
	var name_text := str(card_data.get("name", "手牌")).strip_edges()
	var type_text := str(card_data.get("type", card_data.get("category", ""))).strip_edges()
	var cost_text := str(card_data.get("cost", card_data.get("price", ""))).strip_edges()
	var pieces: Array[String] = [name_text]
	if type_text != "":
		pieces.append(type_text)
	if cost_text != "":
		pieces.append("费用 %s" % cost_text)
	pieces.append(_card_drop_feedback_label(card_data, over_map, valid_drop))
	return "\n".join(pieces)


func _restore_right_inspector_context() -> void:
	if right_inspector == null or not right_inspector.has_method("set_context"):
		return
	var inspector: Dictionary = current_ui_data.get("right_inspector", {}) if current_ui_data.get("right_inspector", {}) is Dictionary else {}
	right_inspector.call("set_context", inspector)


func _track_entry_inspector_context(entry: Dictionary) -> Dictionary:
	var requirements: Array = entry.get("requirements", []) if entry.get("requirements", []) is Array else []
	var actions: Array = entry.get("actions", []) if entry.get("actions", []) is Array else []
	var deep_links: Array = entry.get("deep_links", []) if entry.get("deep_links", []) is Array else []
	var badges: Array = entry.get("badges", []) if entry.get("badges", []) is Array else []
	var chips: Array = [
		{"text": "槽 %s" % str(entry.get("slot", "--"))},
		{"text": str(entry.get("state", "等待"))},
		{"text": "归属:%s" % str(entry.get("owner_hint", "匿名"))},
	]
	var cost_text := str(entry.get("cost", "")).strip_edges()
	if cost_text != "":
		chips.append({"text": "报价%s" % cost_text})
	for badge_variant in badges:
		var badge_text := str(badge_variant).strip_edges()
		if badge_text != "":
			chips.append({"text": badge_text})
		if chips.size() >= 6:
			break
	var logs: Array = []
	var current_logs: Variant = current_ui_data.get("logs", [])
	if current_logs is Array:
		logs = current_logs
	return {
		"title": str(entry.get("title", "牌轨详情")),
		"why": str(entry.get("why", entry.get("tooltip", "看状态、报价、归属和余波线索来推理来源。"))),
		"district": {
			"id": str(entry.get("id", "")),
			"title": str(entry.get("label", "公共牌槽")),
			"summary": str(entry.get("summary", entry.get("tooltip", ""))),
			"detail": str(entry.get("detail", entry.get("tooltip", ""))),
			"full_detail": str(entry.get("full_detail", entry.get("tooltip", ""))),
			"chips": chips,
		},
		"requirements": requirements,
		"actions": actions,
		"deep_links": deep_links,
		"logs": logs,
	}


func _track_hover_action(entry: Dictionary) -> String:
	var action_id := str(entry.get("select_action", "")).strip_edges()
	if action_id != "":
		return action_id
	var resolution_id := int(entry.get("resolution_id", -1))
	return "track_select_%d" % resolution_id if resolution_id >= 0 else ""


func _configure_track_focus_ribbon() -> void:
	if track_focus_ribbon == null:
		return
	track_focus_ribbon.visible = false
	track_focus_ribbon.add_theme_stylebox_override("panel", _track_focus_style())
	if track_focus_label != null:
		track_focus_label.add_theme_font_size_override("font_size", 10)
		track_focus_label.add_theme_color_override("font_color", Color("#fde68a"))


func _configure_focus_guide() -> void:
	if focus_guide_layer != null:
		if focus_guide_layer is Control:
			(focus_guide_layer as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if focus_guide_layer.has_method("hide_focus"):
			focus_guide_layer.call("hide_focus")


func _configure_hand_hover_preview() -> void:
	if hand_hover_preview_host == null:
		return
	_set_overlay_anchor_rect(
		hand_hover_preview_host,
		HAND_HOVER_PREVIEW_LEFT,
		HAND_HOVER_PREVIEW_TOP,
		HAND_HOVER_PREVIEW_RIGHT,
		HAND_HOVER_PREVIEW_BOTTOM
	)
	_set_mouse_filter_recursive(hand_hover_preview_host, Control.MOUSE_FILTER_IGNORE)
	hand_hover_preview_host.visible = false
	if hand_hover_preview_panel != null:
		hand_hover_preview_panel.add_theme_stylebox_override("panel", _hand_hover_preview_style())
	if hand_hover_preview_title != null:
		hand_hover_preview_title.add_theme_font_size_override("font_size", 11)
		hand_hover_preview_title.add_theme_color_override("font_color", Color("#fde68a"))
	if hand_hover_preview_card != null:
		hand_hover_preview_card.custom_minimum_size = HAND_HOVER_PREVIEW_CARD_MIN_SIZE
		hand_hover_preview_card.set_meta("hand_hover_readable_preview", true)


func _set_mouse_filter_recursive(node: Node, filter: int) -> void:
	if node is Control:
		(node as Control).mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)


func _show_hand_hover_preview(card_data: Dictionary) -> void:
	if hand_hover_preview_host == null or hand_hover_preview_card == null or card_data.is_empty():
		_hide_hand_hover_preview()
		return
	var display_data := card_data.duplicate(true)
	display_data["presentation"] = "inspector_full"
	display_data["detail_policy"] = "hover_readable_preview"
	display_data["summary"] = _hand_hover_preview_effect_text(card_data)
	if hand_hover_preview_card.has_method("set_card_data"):
		hand_hover_preview_card.call("set_card_data", display_data)
	if hand_hover_preview_title != null:
		hand_hover_preview_title.text = _hand_hover_preview_title(card_data)
		hand_hover_preview_title.tooltip_text = _hand_hover_preview_detail(card_data)
	hand_hover_preview_host.visible = true
	hand_hover_preview_host.set_meta("runtime_focus_kind", "hand_hover_readable_preview")
	hand_hover_preview_host.set_meta("hand_hover_card_name", str(card_data.get("name", "")))
	hand_hover_preview_host.set_meta("hand_hover_preview_policy", "left-side-readable-card")


func _hide_hand_hover_preview() -> void:
	if hand_hover_preview_host == null:
		return
	hand_hover_preview_host.visible = false
	hand_hover_preview_host.set_meta("hand_hover_card_name", "")


func get_hand_hover_preview_snapshot() -> Dictionary:
	if hand_hover_preview_host == null:
		return {"visible": false}
	var rect := hand_hover_preview_host.get_global_rect()
	return {
		"visible": hand_hover_preview_host.visible,
		"card_name": str(hand_hover_preview_host.get_meta("hand_hover_card_name", "")),
		"policy": str(hand_hover_preview_host.get_meta("hand_hover_preview_policy", "")),
		"rect": rect,
		"anchor_left": HAND_HOVER_PREVIEW_LEFT,
		"anchor_right": HAND_HOVER_PREVIEW_RIGHT,
		"card_min_size": HAND_HOVER_PREVIEW_CARD_MIN_SIZE,
	}


func _hand_hover_preview_title(card_data: Dictionary) -> String:
	var name_text := str(card_data.get("name", "手牌")).strip_edges()
	var type_text := str(card_data.get("type", card_data.get("category", ""))).strip_edges()
	var rank_text := str(card_data.get("rank", card_data.get("stats", ""))).strip_edges()
	var pieces: Array[String] = []
	if type_text != "":
		pieces.append(type_text)
	if rank_text != "":
		pieces.append(rank_text)
	pieces.append(name_text if name_text != "" else "手牌")
	var text := "｜".join(pieces)
	return text if text.length() <= 24 else "%s..." % text.left(21)


func _hand_hover_preview_effect_text(card_data: Dictionary) -> String:
	for key in ["summary", "short_effect", "effect", "text", "description"]:
		var value := str(card_data.get(key, "")).replace("\n", " ").strip_edges()
		if value != "":
			return value
	return "查看右侧详情或双击使用。"


func _hand_hover_preview_detail(card_data: Dictionary) -> String:
	var effect := _hand_hover_preview_effect_text(card_data)
	var target := str(card_data.get("target", card_data.get("target_type", ""))).strip_edges()
	var requirement := str(card_data.get("requirement", card_data.get("play_requirement", card_data.get("condition", "")))).strip_edges()
	var lines: Array[String] = [effect]
	if target != "":
		lines.append("目标：%s" % target)
	if requirement != "":
		lines.append("条件：%s" % requirement)
	return "\n".join(lines)


func _hand_hover_preview_style() -> StyleBoxFlat:
	var accent := Color("#f59e0b")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#020617").lerp(accent, 0.10)
	style.border_color = Color("#334155").lerp(accent, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _sync_focus_guide_from_current_state() -> void:
	if current_ui_data.is_empty():
		_hide_focus_guide()
		return
	_sync_focus_guide(current_ui_data)


func _sync_focus_guide(ui_data: Dictionary) -> void:
	var focus_data := _focus_guide_source_data(ui_data)
	if focus_data.is_empty():
		_hide_focus_guide()
		return
	var focus_target := str(focus_data.get("focus_target", "")).strip_edges()
	if focus_target == "":
		_hide_focus_guide()
		return
	var target_control := _focus_target_control(focus_target)
	if target_control == null or not target_control.is_visible_in_tree():
		_hide_focus_guide()
		return
	var target_rect := _focus_target_rect(target_control, focus_target)
	if target_rect.size.x <= 4.0 or target_rect.size.y <= 4.0:
		_hide_focus_guide()
		return
	_show_focus_guide(target_rect, focus_target, focus_data)


func _focus_guide_source_data(ui_data: Dictionary) -> Dictionary:
	var scenario_data: Dictionary = ui_data.get("scenario_coach", {}) if ui_data.get("scenario_coach", {}) is Dictionary else {}
	if _focus_guide_source_is_active(scenario_data):
		return scenario_data
	var first_run_data: Dictionary = ui_data.get("first_run_coach", {}) if ui_data.get("first_run_coach", {}) is Dictionary else {}
	if _focus_guide_source_is_active(first_run_data):
		return first_run_data
	return {}


func _focus_guide_source_is_active(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if not bool(data.get("visible", false)):
		return false
	if bool(data.get("collapsed", false)):
		return false
	return str(data.get("focus_target", "")).strip_edges() != ""


func _show_focus_guide(target_global_rect: Rect2, focus_target: String, scenario_data: Dictionary) -> void:
	if focus_guide_layer == null or not focus_guide_layer.has_method("show_focus"):
		return
	var next_signature := var_to_str([
		focus_target,
		target_global_rect.position.round(),
		target_global_rect.size.round(),
		scenario_data.get("phase_id", ""),
		scenario_data.get("stuck_state", ""),
		scenario_data.get("pulse_focus", false),
		scenario_data.get("shortest_action_text", ""),
	])
	if next_signature == str(_last_focus_guide_data.get("signature", "")):
		return
	_last_focus_guide_data = {"signature": next_signature, "target": focus_target}
	focus_guide_layer.call("show_focus", target_global_rect, focus_target, scenario_data)


func _hide_focus_guide() -> void:
	_last_focus_guide_data = {}
	if focus_guide_layer != null and focus_guide_layer.has_method("hide_focus"):
		focus_guide_layer.call("hide_focus")


func _focus_target_control(focus_target: String) -> Control:
	match focus_target:
		"planet", "route_layer":
			return _runtime_map_focus_control()
		"player_hand":
			return _first_visible_control(["HandRack", "PlayerHandTableau", "PlayerBoard"])
		"action_dock":
			return _first_visible_control(["PlayerMainActionDock", "PlayerCommandTableau", "PlayerBoard"])
		"bid_board":
			return _first_visible_control(["PlayerBidBoard", "PlayerCommandTableau"])
		"public_track":
			return _public_track_node() as Control
		"right_inspector", "economy_overview", "intel_dossier", "standings", "settlement":
			return right_inspector as Control
		"district_supply":
			return _first_visible_control(["DistrictSupplyDrawer", "SideDrawerPanel", "RightInspector", "PlanetStageViewport"])
		"private_decision", "contract_prompt":
			return _first_visible_control(["TemporaryDecisionPanel", "ConfirmPanel", "ModalLayer", "OverlayLayer"])
		"top_bar":
			return top_bar as Control
		"scenario_coach":
			return scenario_coach_host if scenario_coach_host != null else scenario_coach as Control
		_:
			return _first_visible_control(["RightInspector", "PlanetBoard"])


func _first_visible_control(names: Array[String]) -> Control:
	for node_name in names:
		var node := find_child(node_name, true, false)
		if node is Control and (node as Control).is_visible_in_tree():
			return node as Control
	return null


func _focus_target_rect(control: Control, focus_target: String) -> Rect2:
	var rect := control.get_global_rect()
	if focus_target == "planet" or focus_target == "route_layer":
		var map_control := _first_visible_control(["MapHost"])
		if map_control != null:
			rect = map_control.get_global_rect()
	if focus_target == "player_hand":
		var hand_control := _first_visible_control(["HandRack"])
		if hand_control != null:
			rect = hand_control.get_global_rect()
	return rect


func _sync_selected_track_focus_from_state() -> void:
	var selected_entry := _selected_track_entry()
	if selected_entry.is_empty():
		_clear_track_focus_ribbon()
		return
	_show_track_focus_for_entry(selected_entry, "已选牌轨", false)


func _selected_track_entry() -> Dictionary:
	var entries: Array = current_ui_data.get("card_track", []) if current_ui_data.get("card_track", []) is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		if bool(entry.get("selected", entry.get("focused", false))):
			return entry
	return {}


func _track_entry_for_action(action_id: String) -> Dictionary:
	var normalized := action_id.strip_edges()
	if normalized == "":
		return {}
	var entries: Array = current_ui_data.get("card_track", []) if current_ui_data.get("card_track", []) is Array else []
	for entry_variant in entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		if _track_entry_matches_action(entry, normalized):
			return entry
	return {}


func _track_entry_matches_action(entry: Dictionary, action_id: String) -> bool:
	for key in ["select_action", "open_action"]:
		if str(entry.get(key, "")).strip_edges() == action_id:
			return true
	if _track_hover_action(entry) == action_id:
		return true
	var actions: Array = entry.get("actions", []) if entry.get("actions", []) is Array else []
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if str(action.get("id", action.get("action_id", ""))).strip_edges() == action_id:
			return true
	return false


func _show_track_focus_for_entry(entry: Dictionary, prefix: String, temporary: bool) -> void:
	if track_focus_ribbon == null or track_focus_label == null:
		return
	_temporary_track_focus_active = temporary
	track_focus_label.text = _track_focus_text(entry, prefix)
	track_focus_label.tooltip_text = str(entry.get("tooltip", entry.get("detail", "")))
	track_focus_ribbon.visible = true


func _show_track_focus_for_action(action_id: String, temporary: bool) -> void:
	if track_focus_ribbon == null or track_focus_label == null:
		return
	_temporary_track_focus_active = temporary
	track_focus_label.text = _short_track_focus_text("竞价对照｜%s" % action_id)
	track_focus_label.tooltip_text = "该竞价指针正在对照顶部公开牌轨。"
	track_focus_ribbon.visible = true


func _clear_track_focus_ribbon() -> void:
	_temporary_track_focus_active = false
	if track_focus_ribbon != null:
		track_focus_ribbon.visible = false
	if track_focus_label != null:
		track_focus_label.text = ""
		track_focus_label.tooltip_text = ""


func _track_focus_text(entry: Dictionary, prefix: String) -> String:
	var pieces: Array[String] = []
	var slot := str(entry.get("slot", "")).strip_edges()
	var label := str(entry.get("label", entry.get("title", "公共牌"))).strip_edges()
	if slot != "" and label != "":
		pieces.append("%s %s" % [slot, label])
	elif label != "":
		pieces.append(label)
	var state := str(entry.get("state", "")).strip_edges()
	if state != "":
		pieces.append(state)
	var owner_hint := str(entry.get("owner_hint", "")).strip_edges()
	if owner_hint != "":
		pieces.append("归属:%s" % owner_hint)
	var cost := str(entry.get("cost", "")).strip_edges()
	if cost != "":
		pieces.append("报价%s" % cost)
	if pieces.is_empty():
		pieces.append("公共牌槽")
	return _short_track_focus_text("%s｜%s" % [prefix, "｜".join(pieces)])


func _short_track_focus_text(text: String) -> String:
	var value := text.replace("\n", " ").strip_edges()
	if value.length() <= 58:
		return value
	return "%s..." % value.left(55)


func _track_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var accent := Color("#f59e0b")
	style.bg_color = Color("#020617").lerp(accent, 0.12)
	style.border_color = Color("#334155").lerp(accent, 0.56)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 2.0)
	style.set_content_margin(SIDE_BOTTOM, 2.0)
	return style


func _should_open_detail_drawer(action_id: String) -> bool:
	return action_id.begins_with("codex") or action_id.begins_with("detail") or action_id == "inspect"


func _open_detail_drawer(action_id: String) -> void:
	if overlay_layer == null or not overlay_layer.has_method("show_side_drawer"):
		return
	var inspector: Dictionary = current_ui_data.get("right_inspector", {}) if current_ui_data.get("right_inspector", {}) is Dictionary else {}
	var drawer: Dictionary = OVERLAY_LAYER_SNAPSHOT_SCRIPT.new().apply_side_drawer(action_id, inspector).to_side_drawer_dictionary()
	overlay_layer.call("show_side_drawer", drawer)


func _sync_temporary_decision_overlay(value: Variant) -> void:
	if overlay_layer == null:
		return
	var decision: Dictionary = value if value is Dictionary else {}
	if decision.is_empty():
		if overlay_layer.has_method("hide_confirm"):
			overlay_layer.call("hide_confirm")
		return
	if overlay_layer.has_method("show_temporary_decision"):
		overlay_layer.call("show_temporary_decision", decision)


func _card_drop_zone_contains(screen_position: Vector2) -> bool:
	return _control_contains_screen_position(_map_drop_control(), screen_position)


func _control_contains_screen_position(control: Control, screen_position: Vector2) -> bool:
	return control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(screen_position)


func _drag_drop_hint(_screen_position: Vector2, over_map: bool, valid_drop: bool, card_data: Dictionary) -> Dictionary:
	var drop_control := _map_drop_control()
	if drop_control == null:
		return {}
	var label := _card_drop_feedback_label(card_data, over_map, valid_drop)
	return {
		"target_rect": drop_control.get_global_rect(),
		"valid": valid_drop,
		"label": label,
		"tooltip": _card_drop_feedback_tooltip(card_data, over_map, valid_drop),
	}


func _card_can_drop_on_map(card_data: Dictionary) -> bool:
	if card_data.has("drop_enabled"):
		return bool(card_data.get("drop_enabled", false))
	if card_data.has("actionable"):
		return bool(card_data.get("actionable", false))
	var actions: Array = card_data.get("actions", []) if card_data.get("actions", []) is Array else []
	for action_variant in actions:
		if not (action_variant is Dictionary):
			continue
		var action: Dictionary = action_variant
		var action_id := str(action.get("id", ""))
		if action_id.begins_with("play_"):
			return not bool(action.get("disabled", false))
	return true


func _card_drop_feedback_label(card_data: Dictionary, over_map: bool, valid_drop: bool) -> String:
	if not over_map:
		return "拖到星球地图"
	if valid_drop:
		var explicit := str(card_data.get("drop_label", "")).strip_edges()
		return explicit if explicit != "" else "松开出牌"
	var blocked_label := str(card_data.get("drop_label", "")).strip_edges()
	if blocked_label != "":
		return blocked_label
	var state_text := str(card_data.get("play_state", card_data.get("target", ""))).strip_edges()
	if state_text != "":
		return "不能出：%s" % _short_drag_text(state_text, 8)
	return "暂不可出牌"


func _card_drop_feedback_tooltip(card_data: Dictionary, over_map: bool, valid_drop: bool) -> String:
	if not over_map:
		return "把手牌释放到星球地图区域来打出。"
	if valid_drop:
		var detail := str(card_data.get("why", card_data.get("tooltip", ""))).strip_edges()
		return detail if detail != "" else "松开后按当前卡牌目标流程打出。"
	var reason := str(card_data.get("block_reason", card_data.get("why", card_data.get("tooltip", "")))).strip_edges()
	return reason if reason != "" else "这张牌当前不满足出牌条件。"


func _short_drag_text(value: String, max_length: int) -> String:
	var text := value.replace("\n", " ").strip_edges()
	if text.length() <= max_length:
		return text
	return "%s..." % text.substr(0, max(0, max_length - 3))


func _map_host_control() -> Control:
	if planet_board == null:
		return null
	return planet_board.find_child("MapHost", true, false) as Control


func _map_drop_control() -> Control:
	var map_host := _map_host_control()
	if map_host == null:
		return null
	for child in map_host.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			return child as Control
	return map_host
