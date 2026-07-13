extends Control
class_name SpaceSyndicateCardTrackMcpPreview

const FixturesScript = preload("res://scripts/tools/card_track_mcp_preview_fixtures.gd")

@onready var fixture_list: ItemList = %CardTrackFixtureList
@onready var summary_label: Label = %CardTrackPreviewSummaryLabel
@onready var status_label: Label = %CardTrackPreviewStatusLabel
@onready var action_label: Label = %CardTrackPreviewActionLabel
@onready var card_track: Node = %CardTrack

var _fixtures: RefCounted = FixturesScript.new()
var _selected_fixture_id := "empty_track"
var _selected_entries: Array = []
var _opened_entries: Array = []
var _hovered_entries: Array = []


func _ready() -> void:
	_connect_fixture_list()
	_connect_card_track()
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


func current_track_snapshot() -> Array:
	var result: Array = []
	if card_track == null:
		return result
	var row := card_track.find_child("CardTrackRow", true, false)
	if row == null:
		return result
	for child in row.get_children():
		if not (child is Control):
			continue
		var slot := child as Control
		var entry: Dictionary = slot.call("track_entry") if slot.has_method("track_entry") else {}
		result.append({
			"name": slot.name,
			"label": _label_text(slot, "PublicTrackSlotLabel"),
			"meta": _label_text(slot, "PublicTrackSlotMeta"),
			"entry": entry,
			"selected_marker": slot.find_child("PublicTrackSlotSelected", false, false) != null,
			"hover_marker": slot.find_child("PublicTrackSlotHover", false, false) != null,
			"event_marker": slot.find_child("CardResolutionTimelineEventSlot", false, false) != null,
			"size": [slot.size.x, slot.size.y],
		})
	return result


func apply_fixture(id: String) -> bool:
	var data := fixture(id)
	if data.is_empty():
		return false
	_selected_fixture_id = str(data.get("id", id))
	_sync_fixture_list_selection()
	_selected_entries.clear()
	_opened_entries.clear()
	_hovered_entries.clear()
	if card_track != null and card_track.has_method("set_entries"):
		var entries: Array = data.get("entries", []) if data.get("entries", []) is Array else []
		card_track.call("set_entries", entries)
	if card_track != null and card_track.has_method("set_hovered_track_action"):
		card_track.call("set_hovered_track_action", str(data.get("hover_action", "")))
	_update_labels(data)
	return true


func selected_entry_actions() -> Array:
	var result: Array = []
	for entry_variant in _selected_entries:
		var entry: Dictionary = entry_variant if entry_variant is Dictionary else {}
		result.append(str(entry.get("select_action", "")))
	return result


func _connect_fixture_list() -> void:
	if fixture_list == null:
		return
	var callback := Callable(self, "_on_fixture_selected")
	if not fixture_list.item_selected.is_connected(callback):
		fixture_list.item_selected.connect(callback)


func _connect_card_track() -> void:
	if card_track == null:
		return
	if card_track.has_signal("track_entry_selected"):
		var selected_callback := Callable(self, "_on_track_entry_selected")
		if not card_track.is_connected("track_entry_selected", selected_callback):
			card_track.connect("track_entry_selected", selected_callback)
	if card_track.has_signal("track_entry_opened"):
		var opened_callback := Callable(self, "_on_track_entry_opened")
		if not card_track.is_connected("track_entry_opened", opened_callback):
			card_track.connect("track_entry_opened", opened_callback)
	if card_track.has_signal("track_entry_hovered"):
		var hovered_callback := Callable(self, "_on_track_entry_hovered")
		if not card_track.is_connected("track_entry_hovered", hovered_callback):
			card_track.connect("track_entry_hovered", hovered_callback)


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
	var entries: Array = data.get("entries", []) if data.get("entries", []) is Array else []
	if summary_label != null:
		summary_label.text = "%s\nid: %s  entries: %d  hover: %s" % [
			str(data.get("description", "")),
			str(data.get("id", "")),
			entries.size(),
			str(data.get("hover_action", "")),
		]
	if status_label != null:
		status_label.text = "Fixture: %s" % str(data.get("label", data.get("id", "")))
	if action_label != null:
		action_label.text = "Selected: %d | Opened: %d | Hovered: %d" % [_selected_entries.size(), _opened_entries.size(), _hovered_entries.size()]


func _label_text(node: Node, child_name: String) -> String:
	var label := node.find_child(child_name, true, false) as Label
	return label.text if label != null else ""


func _on_fixture_selected(index: int) -> void:
	if fixture_list == null or index < 0 or index >= fixture_list.item_count:
		return
	apply_fixture(str(fixture_list.get_item_metadata(index)))


func _on_track_entry_selected(entry: Dictionary) -> void:
	_selected_entries.append(entry.duplicate(true))
	if action_label != null:
		action_label.text = "Selected action: %s" % str(entry.get("select_action", ""))


func _on_track_entry_opened(entry: Dictionary) -> void:
	_opened_entries.append(entry.duplicate(true))
	if action_label != null:
		action_label.text = "Opened action: %s" % str(entry.get("open_action", ""))


func _on_track_entry_hovered(entry: Dictionary) -> void:
	_hovered_entries.append(entry.duplicate(true))
	if action_label != null:
		action_label.text = "Hovered: %s" % str(entry.get("label", ""))
