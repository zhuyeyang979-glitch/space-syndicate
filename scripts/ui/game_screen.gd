extends Control
class_name SpaceSyndicateGameScreen

const TABLE_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/table_snapshot.gd")
const OVERLAY_LAYER_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/overlay_layer_snapshot.gd")

signal end_turn_requested
signal action_requested(action_id: String)
signal card_selected(card_data: Dictionary)
signal card_hovered(card_data: Dictionary)
signal card_unhovered
signal card_drag_preview_started(card_data: Dictionary)
signal card_drag_preview_ended(card_data: Dictionary)
signal card_drop_requested(card_data: Dictionary, screen_position: Vector2)

@onready var top_bar: Node = %TopBar
@onready var public_track: Node = get_node_or_null("%PublicTrack")
@onready var card_track: Node = get_node_or_null("%CardTrack")
@onready var first_run_coach: Node = get_node_or_null("%FirstRunCoach")
@onready var scenario_coach: Node = get_node_or_null("%ScenarioCoach")
@onready var planet_board: Node = %PlanetBoard
@onready var right_inspector: Node = %RightInspector
@onready var player_board: Node = %PlayerBoard
@onready var overlay_layer: Node = %OverlayLayer

var current_ui_data: Dictionary = {}

func _ready() -> void:
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


func apply_state(data: Dictionary) -> void:
	var ui_data: Dictionary = TABLE_SNAPSHOT_SCRIPT.new().apply_dictionary(data).to_ui_dictionary()
	current_ui_data = ui_data
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
	_sync_temporary_decision_overlay(ui_data.get("temporary_decision", {}))


func attach_runtime_map(map_node: Control) -> void:
	if planet_board != null and planet_board.has_method("attach_runtime_map"):
		planet_board.call("attach_runtime_map", map_node)


func get_overlay_host() -> Node:
	return overlay_layer


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


func _on_track_link_unhovered(_action_id: String) -> void:
	_set_public_track_hover("")


func _set_public_track_hover(action_id: String) -> void:
	var track_node := _public_track_node()
	if track_node != null and track_node.has_method("set_hovered_track_action"):
		track_node.call("set_hovered_track_action", action_id)


func _on_track_entry_hovered(entry: Dictionary) -> void:
	_set_player_board_track_hover(_track_hover_action(entry))


func _on_track_entry_unhovered(_entry: Dictionary) -> void:
	_set_player_board_track_hover("")


func _set_player_board_track_hover(action_id: String) -> void:
	if player_board != null and player_board.has_method("set_hovered_track_action"):
		player_board.call("set_hovered_track_action", action_id)


func _on_side_drawer_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _on_temporary_decision_action_requested(action_id: String) -> void:
	action_requested.emit(action_id)


func _on_card_selected(card_data: Dictionary) -> void:
	if right_inspector.has_method("show_card"):
		right_inspector.call("show_card", card_data)
	card_selected.emit(card_data)


func _on_card_hovered(card_data: Dictionary) -> void:
	if right_inspector.has_method("show_card") and not card_data.is_empty():
		right_inspector.call("show_card", card_data)
	card_hovered.emit(card_data)


func _on_card_unhovered() -> void:
	_restore_right_inspector_context()
	card_unhovered.emit()


func _on_track_entry_selected(entry: Dictionary) -> void:
	if right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(entry))
	var action_id := str(entry.get("select_action", "")).strip_edges()
	if action_id != "":
		action_requested.emit(action_id)


func _on_track_entry_opened(entry: Dictionary) -> void:
	if right_inspector.has_method("set_context"):
		right_inspector.call("set_context", _track_entry_inspector_context(entry))
	var action_id := str(entry.get("open_action", "")).strip_edges()
	if action_id != "":
		action_requested.emit(action_id)


func _on_card_drag_preview_started(card_data: Dictionary, screen_position: Vector2) -> void:
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
