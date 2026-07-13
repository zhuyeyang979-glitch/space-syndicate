extends Control
class_name SpaceSyndicateCardResolutionTrackMcpPreview

const FixturesScript = preload("res://scripts/tools/card_resolution_track_mcp_preview_fixtures.gd")

@onready var fixture_list: ItemList = %CardResolutionTrackFixtureList
@onready var summary_label: Label = %CardResolutionTrackPreviewSummaryLabel
@onready var status_label: Label = %CardResolutionTrackPreviewStatusLabel
@onready var action_label: Label = %CardResolutionTrackPreviewActionLabel
@onready var card_resolution_track: Node = %CardResolutionTrack

var _fixtures: RefCounted = FixturesScript.new()
var _selected_fixture_id := "empty_track"
var _selected_slots: Array = []
var _track_actions: Array[String] = []


func _ready() -> void:
	_connect_fixture_list()
	_connect_card_resolution_track()
	_populate_fixture_list()
	apply_fixture(_selected_fixture_id)


func preview_ids() -> Array[String]:
	var ids_variant: Variant = _fixtures.call("preview_ids")
	var result: Array[String] = []
	if ids_variant is Array:
		for id in ids_variant:
			result.append(str(id))
	return result


func selected_fixture_id() -> String:
	return _selected_fixture_id


func fixture(id: String) -> Dictionary:
	var data_variant: Variant = _fixtures.call("fixture", id)
	return (data_variant as Dictionary).duplicate(true) if data_variant is Dictionary else {}


func apply_fixture(id: String) -> bool:
	var data := fixture(id)
	if data.is_empty():
		return false
	_selected_fixture_id = str(data.get("id", id))
	_selected_slots.clear()
	_track_actions.clear()
	_sync_fixture_list_selection()
	if card_resolution_track != null and card_resolution_track.has_method("set_track_state"):
		var state: Dictionary = data.get("track_state", {}) if data.get("track_state", {}) is Dictionary else {}
		card_resolution_track.call("set_track_state", state)
	_update_labels(data)
	return true


func current_track_debug_snapshot() -> Dictionary:
	if card_resolution_track != null and card_resolution_track.has_method("get_debug_snapshot"):
		var snapshot_variant: Variant = card_resolution_track.call("get_debug_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func current_track_node_text() -> String:
	return _node_text(card_resolution_track)


func selected_slot_ids() -> Array:
	return _selected_slots.duplicate(true)


func emitted_track_actions() -> Array[String]:
	return _track_actions.duplicate()


func _connect_fixture_list() -> void:
	if fixture_list == null:
		return
	var callback := Callable(self, "_on_fixture_selected")
	if not fixture_list.item_selected.is_connected(callback):
		fixture_list.item_selected.connect(callback)


func _connect_card_resolution_track() -> void:
	if card_resolution_track == null:
		return
	if card_resolution_track.has_signal("card_slot_selected"):
		var slot_callback := Callable(self, "_on_card_slot_selected")
		if not card_resolution_track.is_connected("card_slot_selected", slot_callback):
			card_resolution_track.connect("card_slot_selected", slot_callback)
	if card_resolution_track.has_signal("track_action_requested"):
		var action_callback := Callable(self, "_on_track_action_requested")
		if not card_resolution_track.is_connected("track_action_requested", action_callback):
			card_resolution_track.connect("track_action_requested", action_callback)
	if card_resolution_track.has_signal("track_entry_selected"):
		var selected_callback := Callable(self, "_on_track_entry_selected")
		if not card_resolution_track.is_connected("track_entry_selected", selected_callback):
			card_resolution_track.connect("track_entry_selected", selected_callback)


func _populate_fixture_list() -> void:
	if fixture_list == null:
		return
	fixture_list.clear()
	for id in preview_ids():
		fixture_list.add_item(str(_fixtures.call("preview_label", id)))
		fixture_list.set_item_metadata(fixture_list.item_count - 1, id)
	_sync_fixture_list_selection()


func _sync_fixture_list_selection() -> void:
	if fixture_list == null:
		return
	for index in range(fixture_list.item_count):
		if str(fixture_list.get_item_metadata(index)) == _selected_fixture_id:
			fixture_list.select(index)
			return


func _update_labels(data: Dictionary) -> void:
	var state: Dictionary = data.get("track_state", {}) if data.get("track_state", {}) is Dictionary else {}
	var entries: Array = state.get("entries", []) if state.get("entries", []) is Array else []
	if summary_label != null:
		summary_label.text = "%s\nid: %s  phase: %s  entries: %d" % [
			str(data.get("description", "")),
			str(data.get("id", "")),
			str(state.get("phase", "")),
			entries.size(),
		]
	if status_label != null:
		status_label.text = "Fixture: %s" % str(data.get("label", data.get("id", "")))
	_update_action_label()


func _update_action_label() -> void:
	if action_label != null:
		action_label.text = "Selected slots: %d | Actions: %d" % [_selected_slots.size(), _track_actions.size()]


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	_collect_node_text(node, parts)
	return "\n".join(parts)


func _collect_node_text(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	elif node is Control:
		var tooltip := (node as Control).tooltip_text.strip_edges()
		if tooltip != "":
			parts.append(tooltip)
	for child in node.get_children():
		_collect_node_text(child, parts)


func _on_fixture_selected(index: int) -> void:
	if fixture_list == null or index < 0 or index >= fixture_list.item_count:
		return
	apply_fixture(str(fixture_list.get_item_metadata(index)))


func _on_card_slot_selected(slot_id: String) -> void:
	_selected_slots.append(slot_id)
	_update_action_label()


func _on_track_action_requested(action_id: String) -> void:
	_track_actions.append(action_id)
	_update_action_label()


func _on_track_entry_selected(_entry: Dictionary) -> void:
	_update_action_label()
