@tool
extends PanelContainer
class_name SpaceSyndicatePlayerRosterPanel

signal player_inspection_requested(player_id: String)

const PROJECTION_SERVICE := preload(
	"res://scripts/presentation/public_player_roster_projection_service.gd"
)
const ENTRY_SCENE := preload("res://scenes/ui/table/PlayerRosterEntry.tscn")

@onready var player_count_label: Label = %PlayerCount
@onready var empty_state: Label = %EmptyState
@onready var columns: HBoxContainer = %RosterColumns
@onready var left_column: VBoxContainer = %LeftColumn
@onready var right_column: VBoxContainer = %RightColumn

var _service: PublicPlayerRosterProjectionService = PROJECTION_SERVICE.new()
var _entry_by_player_id: Dictionary = {}
var _ordered_player_ids: Array[String] = []
var _column_count := 1
var _render_count := 0
var _node_create_count := 0
var _node_reuse_count := 0
var _node_retire_count := 0
var _last_rendered_signature := ""
var _active_inspection_player_id := ""


func _ready() -> void:
	right_column.visible = false
	empty_state.visible = true
	_update_header()


func bind_viewer(viewer_index: int, authorization_revision: int) -> bool:
	var previous_viewer := _service.bound_viewer_index()
	var previous_authorization := _service.bound_authorization_revision()
	var accepted := _service.bind_viewer(viewer_index, authorization_revision)
	if not accepted:
		clear_projection()
		return false
	if previous_viewer != viewer_index or previous_authorization != authorization_revision:
		clear_projection(false)
	return true


func apply_projection(value: Dictionary) -> bool:
	if not _service.apply_roster_projection(value):
		return false
	var signature := _service.roster_signature()
	if signature == _last_rendered_signature:
		return true
	_last_rendered_signature = signature
	_render_roster(_service.roster_players())
	return true


func clear_projection(clear_service := true) -> void:
	if clear_service:
		_service.clear_roster()
	_last_rendered_signature = ""
	_active_inspection_player_id = ""
	_ordered_player_ids.clear()
	for node_variant in _entry_by_player_id.values():
		var node := node_variant as Node
		if is_instance_valid(node):
			node.queue_free()
	_entry_by_player_id.clear()
	_column_count = 1
	right_column.visible = false
	empty_state.visible = true
	_update_header()


func set_active_inspection_player_id(player_id: String) -> void:
	_active_inspection_player_id = player_id
	for identity in _entry_by_player_id.keys():
		var entry := _entry_by_player_id.get(identity) as SpaceSyndicatePlayerRosterEntry
		if is_instance_valid(entry):
			entry.set_inspected_visual(str(identity) == player_id)


func focus_first_entry() -> bool:
	if _ordered_player_ids.is_empty():
		return false
	var entry := _entry_by_player_id.get(_ordered_player_ids[0]) \
		as SpaceSyndicatePlayerRosterEntry
	if not is_instance_valid(entry):
		return false
	entry.focus_for_accessibility()
	return true


func entry_for_player_id(player_id: String) -> SpaceSyndicatePlayerRosterEntry:
	return _entry_by_player_id.get(player_id) as SpaceSyndicatePlayerRosterEntry


func ordered_player_ids() -> Array[String]:
	return _ordered_player_ids.duplicate()


func debug_snapshot() -> Dictionary:
	var order_indices: Array[int] = []
	var node_instance_ids: Array[int] = []
	var column_assignments: Array[int] = []
	var local_marker_count := 0
	var inspected_marker_count := 0
	var rendered_widths: Array[float] = []
	for index in range(_ordered_player_ids.size()):
		var player_id := _ordered_player_ids[index]
		var entry := _entry_by_player_id.get(player_id) as SpaceSyndicatePlayerRosterEntry
		if not is_instance_valid(entry):
			continue
		var entry_debug := entry.debug_snapshot()
		order_indices.append(int(entry_debug.get("public_order_index", -1)))
		node_instance_ids.append(entry.get_instance_id())
		rendered_widths.append(entry.size.x)
		column_assignments.append(index % 2 if _column_count == 2 else 0)
		local_marker_count += 1 if bool(entry_debug.get("is_local_player", false)) else 0
		inspected_marker_count += 1 if bool(entry_debug.get("is_inspected", false)) else 0
	var service_debug := _service.debug_snapshot()
	return {
		"viewer_index": int(service_debug.get("viewer_index", -1)),
		"authorization_revision": int(service_debug.get("authorization_revision", 0)),
		"source_revision": int(service_debug.get("roster_source_revision", -1)),
		"projection_signature": _last_rendered_signature,
		"player_count": _ordered_player_ids.size(),
		"column_count": _column_count,
		"ordered_player_ids": _ordered_player_ids.duplicate(),
		"public_order_indices": order_indices,
		"column_assignments": column_assignments,
		"node_instance_ids": node_instance_ids,
		"rendered_entry_widths": rendered_widths,
		"maximum_entry_width": rendered_widths.max() if not rendered_widths.is_empty() else 0.0,
		"panel_minimum_width": custom_minimum_size.x,
		"panel_rendered_width": size.x,
		"compact_entry_count": _ordered_player_ids.size() if _column_count == 2 else 0,
		"local_marker_count": local_marker_count,
		"inspected_marker_count": inspected_marker_count,
		"active_inspection_player_id": _active_inspection_player_id,
		"render_count": _render_count,
		"node_create_count": _node_create_count,
		"node_reuse_count": _node_reuse_count,
		"node_retire_count": _node_retire_count,
		"duplicate_projection_count": int(service_debug.get("duplicate_count", 0)),
		"stale_projection_count": int(service_debug.get("stale_count", 0)),
		"conflict_projection_count": int(service_debug.get("conflict_count", 0)),
		"rotates_for_local_viewer": false,
		"direct_gameplay_mutation_count": 0,
		"rng_draw_count": 0,
		"private_fact_read_count": 0,
	}


func _render_roster(players: Array) -> void:
	var ordered: Array[Dictionary] = []
	for player_variant in players:
		if player_variant is Dictionary:
			ordered.append((player_variant as Dictionary).duplicate(true))
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("public_order_index", -1)) \
			< int(right.get("public_order_index", -1))
	)
	_column_count = 2 if ordered.size() >= 5 else 1
	right_column.visible = _column_count == 2
	columns.add_theme_constant_override("separation", 6 if _column_count == 2 else 0)
	var desired_ids: Array[String] = []
	for index in range(ordered.size()):
		var row := ordered[index]
		var player_id := str(row.get("player_id", ""))
		if player_id.is_empty():
			continue
		desired_ids.append(player_id)
		var entry := _entry_by_player_id.get(player_id) \
			as SpaceSyndicatePlayerRosterEntry
		if not is_instance_valid(entry):
			entry = ENTRY_SCENE.instantiate() as SpaceSyndicatePlayerRosterEntry
			entry.name = "RosterEntry_%s" % player_id.replace(".", "_").replace("-", "_")
			entry.player_inspection_requested.connect(_on_entry_inspection_requested)
			_entry_by_player_id[player_id] = entry
			_node_create_count += 1
		else:
			_node_reuse_count += 1
		var target_column := right_column \
			if _column_count == 2 and index % 2 == 1 else left_column
		if entry.get_parent() != target_column:
			if entry.get_parent() == null:
				target_column.add_child(entry)
			else:
				entry.reparent(target_column, false)
		var column_position := int(index / _column_count)
		target_column.move_child(entry, mini(column_position, target_column.get_child_count() - 1))
		entry.set_compact_mode(_column_count == 2)
		entry.apply_player(row)
		if not _active_inspection_player_id.is_empty():
			entry.set_inspected_visual(player_id == _active_inspection_player_id)
	var retired: Array[String] = []
	for identity_variant in _entry_by_player_id.keys():
		var identity := str(identity_variant)
		if desired_ids.has(identity):
			continue
		var retired_entry := _entry_by_player_id.get(identity) as Node
		if is_instance_valid(retired_entry):
			retired_entry.queue_free()
		retired.append(identity)
		_node_retire_count += 1
	for identity in retired:
		_entry_by_player_id.erase(identity)
	_ordered_player_ids = desired_ids
	empty_state.visible = desired_ids.is_empty()
	_render_count += 1
	_update_header()
	_configure_focus_neighbors()


func _configure_focus_neighbors() -> void:
	var entries: Array[SpaceSyndicatePlayerRosterEntry] = []
	for player_id in _ordered_player_ids:
		var entry := _entry_by_player_id.get(player_id) \
			as SpaceSyndicatePlayerRosterEntry
		if is_instance_valid(entry):
			entries.append(entry)
	for index in range(entries.size()):
		var entry := entries[index]
		var previous := entries[wrapi(index - 1, 0, entries.size())]
		var next := entries[wrapi(index + 1, 0, entries.size())]
		entry.focus_previous = entry.get_path_to(previous)
		entry.focus_next = entry.get_path_to(next)
		var column := index % _column_count
		var row := int(index / _column_count)
		var left_index := row * _column_count + maxi(0, column - 1)
		var right_index := row * _column_count + mini(_column_count - 1, column + 1)
		var top_index := index - _column_count
		var bottom_index := index + _column_count
		entry.focus_neighbor_left = entry.get_path_to(entries[mini(left_index, entries.size() - 1)])
		entry.focus_neighbor_right = entry.get_path_to(entries[mini(right_index, entries.size() - 1)])
		entry.focus_neighbor_top = entry.get_path_to(
			entries[top_index] if top_index >= 0 else entry
		)
		entry.focus_neighbor_bottom = entry.get_path_to(
			entries[bottom_index] if bottom_index < entries.size() else entry
		)


func _update_header() -> void:
	if player_count_label != null:
		player_count_label.text = "%d 位" % _ordered_player_ids.size()


func _on_entry_inspection_requested(player_id: String) -> void:
	player_inspection_requested.emit(player_id)
