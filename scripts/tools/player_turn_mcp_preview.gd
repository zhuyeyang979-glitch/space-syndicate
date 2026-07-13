extends Control
class_name PlayerTurnMcpPreview

signal action_requested(action_id: String)

const FixturesScript = preload("res://scripts/tools/player_turn_mcp_preview_fixtures.gd")

@onready var state_list: ItemList = %PlayerTurnStateList
@onready var current_state_label: Label = %PlayerTurnCurrentStateLabel
@onready var status_label: Label = %PlayerTurnStatusLabel
@onready var selected_card_label: Label = %PlayerTurnSelectedCardLabel
@onready var action_summary_label: Label = %PlayerTurnActionSummaryLabel
@onready var disabled_reason_label: Label = %PlayerTurnDisabledReasonLabel
@onready var public_track: Node = %PublicTrack
@onready var player_board: Node = %PlayerBoard
@onready var selected_card_face: Control = %SelectedCardFace
@onready var right_inspector: Node = %RightInspector
@onready var last_action_label: Label = %PlayerTurnLastActionLabel

var _fixtures: RefCounted
var _current_fixture: Dictionary = {}
var _selected_id := "normal_hand"


func _ready() -> void:
	_fixtures = FixturesScript.new()
	_connect_state_list()
	_connect_component_signals()
	_populate_state_list()
	show_preview_id(_selected_id)


func preview_ids() -> Array[String]:
	if _fixtures == null:
		return []
	var ids_variant: Variant = _fixtures.call("preview_ids")
	var result: Array[String] = []
	if ids_variant is Array:
		for id in ids_variant:
			result.append(str(id))
	return result


func selected_preview_id() -> String:
	return _selected_id


func current_fixture() -> Dictionary:
	return _current_fixture.duplicate(true)


func show_preview_id(id: String) -> void:
	if _fixtures == null:
		return
	var data_variant: Variant = _fixtures.call("fixture", id)
	if not (data_variant is Dictionary):
		return
	var data: Dictionary = (data_variant as Dictionary).duplicate(true)
	_current_fixture = data
	_selected_id = str(data.get("id", id))
	_sync_state_list_selection()
	_apply_fixture(data)


func show_empty_hand() -> void:
	show_preview_id("empty_hand")


func show_normal_hand() -> void:
	show_preview_id("normal_hand")


func show_selected_enabled_card() -> void:
	show_preview_id("selected_enabled_card")


func show_selected_disabled_card() -> void:
	show_preview_id("selected_disabled_card")


func show_hovered_card() -> void:
	show_preview_id("hovered_card")


func show_drag_preview() -> void:
	show_preview_id("drag_preview")


func show_right_inspector_card_detail() -> void:
	show_preview_id("right_inspector_card_detail")


func show_public_track_selection() -> void:
	show_preview_id("public_track_selection")


func show_temporary_decision_pending_hint() -> void:
	show_preview_id("temporary_decision_pending_hint")


func _connect_state_list() -> void:
	if state_list == null:
		return
	var callback := Callable(self, "_on_state_selected")
	if not state_list.item_selected.is_connected(callback):
		state_list.item_selected.connect(callback)


func _connect_component_signals() -> void:
	for node in [player_board, right_inspector]:
		if node == null:
			continue
		if node.has_signal("action_requested"):
			var action_callback := Callable(self, "_on_action_requested")
			if not node.is_connected("action_requested", action_callback):
				node.connect("action_requested", action_callback)
	if player_board != null and player_board.has_signal("card_selected"):
		var card_callback := Callable(self, "_on_card_selected")
		if not player_board.is_connected("card_selected", card_callback):
			player_board.connect("card_selected", card_callback)


func _populate_state_list() -> void:
	if state_list == null or _fixtures == null:
		return
	state_list.clear()
	for id in preview_ids():
		state_list.add_item(str(_fixtures.call("preview_label", id)))
		state_list.set_item_metadata(state_list.item_count - 1, id)


func _sync_state_list_selection() -> void:
	if state_list == null:
		return
	for index in range(state_list.item_count):
		if str(state_list.get_item_metadata(index)) == _selected_id:
			state_list.select(index)
			return


func _apply_fixture(data: Dictionary) -> void:
	var player_state: Dictionary = data.get("player_state", {}) if data.get("player_state", {}) is Dictionary else {}
	var selected_card: Dictionary = data.get("selected_card", {}) if data.get("selected_card", {}) is Dictionary else {}
	var public_entries: Array = data.get("public_track", []) if data.get("public_track", []) is Array else []
	var inspector_context: Dictionary = data.get("inspector", {}) if data.get("inspector", {}) is Dictionary else {}
	if player_board != null and player_board.has_method("set_player_state"):
		player_board.call("set_player_state", player_state)
	if public_track != null and public_track.has_method("set_entries"):
		public_track.call("set_entries", public_entries)
	_apply_selected_card_face(selected_card, str(data.get("hand_focus", "none")))
	_apply_inspector(data, selected_card, inspector_context)
	_apply_labels(data, player_state, selected_card)
	_apply_hand_focus(data)


func _apply_selected_card_face(card: Dictionary, hand_focus: String) -> void:
	if selected_card_face == null:
		return
	selected_card_face.visible = not card.is_empty()
	if card.is_empty():
		return
	var display_data := card.duplicate(true)
	display_data["presentation"] = "inspector_full"
	if selected_card_face.has_method("set_card_data"):
		selected_card_face.call("set_card_data", display_data)
	if selected_card_face.has_method("set_interaction_state"):
		selected_card_face.call("set_interaction_state", {
			"hovered": hand_focus == "hovered",
			"selected": hand_focus in ["selected", "drag_invalid"],
			"dragging": hand_focus == "drag_invalid",
			"drop_valid": hand_focus != "drag_invalid",
			"drop_invalid": hand_focus == "drag_invalid",
		})


func _apply_inspector(data: Dictionary, selected_card: Dictionary, fallback_context: Dictionary) -> void:
	if right_inspector == null:
		return
	if str(data.get("inspector_mode", "context")) == "card" and not selected_card.is_empty() and right_inspector.has_method("show_card"):
		right_inspector.call("show_card", selected_card)
	elif right_inspector.has_method("set_context"):
		right_inspector.call("set_context", fallback_context)


func _apply_labels(data: Dictionary, player_state: Dictionary, selected_card: Dictionary) -> void:
	if current_state_label != null:
		current_state_label.text = "State: %s" % str(data.get("label", data.get("id", "")))
	if status_label != null:
		status_label.text = str(data.get("status", ""))
	if selected_card_label != null:
		selected_card_label.text = "Selected: %s" % (str(selected_card.get("name", "-")) if not selected_card.is_empty() else "-")
	if action_summary_label != null:
		action_summary_label.text = _action_summary(player_state, selected_card)
	if disabled_reason_label != null:
		var disabled_reason := str(data.get("disabled_reason", selected_card.get("disabled_reason", ""))).strip_edges()
		disabled_reason_label.visible = disabled_reason != ""
		disabled_reason_label.text = "Disabled: %s" % disabled_reason if disabled_reason != "" else ""


func _apply_hand_focus(data: Dictionary) -> void:
	var hand_rack := _hand_rack()
	if hand_rack == null:
		return
	if hand_rack.has_method("clear_dragged_card"):
		hand_rack.call("clear_dragged_card")
	if hand_rack.has_method("set_hovered_card"):
		hand_rack.call("set_hovered_card", null)
	var focus := str(data.get("hand_focus", "none"))
	var selected_card_id := str(data.get("selected_card_id", ""))
	if focus == "none" or selected_card_id == "":
		return
	var card := _hand_card_by_id(selected_card_id)
	if card == null:
		return
	match focus:
		"hovered":
			if hand_rack.has_method("set_hovered_card"):
				hand_rack.call("set_hovered_card", card)
		"drag_invalid":
			if hand_rack.has_method("set_dragged_card"):
				hand_rack.call("set_dragged_card", card, false)
		_:
			if hand_rack.has_method("set_selected_card"):
				hand_rack.call("set_selected_card", card)


func _hand_rack() -> Node:
	if player_board == null:
		return null
	return player_board.find_child("HandRack", true, false)


func _hand_card_by_id(card_id: String) -> Control:
	var hand_rack := _hand_rack()
	if hand_rack == null:
		return null
	for child in hand_rack.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if control.has_method("get_card_data"):
			var data_variant: Variant = control.call("get_card_data")
			var data: Dictionary = data_variant if data_variant is Dictionary else {}
			if str(data.get("id", data.get("card_id", ""))) == card_id:
				return control
	return null


func _action_summary(player_state: Dictionary, selected_card: Dictionary) -> String:
	var actions: Array = []
	if not selected_card.is_empty() and selected_card.get("actions", []) is Array:
		actions = selected_card.get("actions", [])
	elif player_state.get("actions", []) is Array:
		actions = player_state.get("actions", [])
	var enabled := 0
	var disabled := 0
	var first_enabled := "-"
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if bool(action.get("disabled", false)):
			disabled += 1
		else:
			enabled += 1
			if first_enabled == "-":
				first_enabled = str(action.get("label", action.get("id", "-")))
	return "Actions: %d enabled / %d disabled | Next: %s" % [enabled, disabled, first_enabled]


func _on_state_selected(index: int) -> void:
	if state_list == null or index < 0 or index >= state_list.item_count:
		return
	show_preview_id(str(state_list.get_item_metadata(index)))


func _on_card_selected(card_data: Dictionary) -> void:
	var updated := _current_fixture.duplicate(true)
	updated["selected_card"] = card_data.duplicate(true)
	updated["selected_card_id"] = str(card_data.get("id", card_data.get("card_id", "")))
	updated["hand_focus"] = "selected"
	_current_fixture = updated
	_apply_selected_card_face(card_data, "selected")
	if right_inspector != null and right_inspector.has_method("show_card"):
		right_inspector.call("show_card", card_data)
	_apply_labels(updated, updated.get("player_state", {}), card_data)


func _on_action_requested(action_id: String) -> void:
	if last_action_label != null:
		last_action_label.text = "Last action: %s" % action_id
	action_requested.emit(action_id)
