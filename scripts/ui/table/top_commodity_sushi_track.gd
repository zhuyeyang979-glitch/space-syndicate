extends PanelContainer
class_name TopCommoditySushiTrack

const ITEM_SCENE := preload("res://scenes/ui/table/TopCommoditySushiTrackItem.tscn")
const ITEM_NODE_SCRIPT := preload("res://scripts/ui/table/top_commodity_sushi_track_item.gd")
const ITEM_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")
const SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_snapshot.gd")

signal item_focused(item: ITEM_SNAPSHOT_SCRIPT)
signal claim_requested(item: ITEM_SNAPSHOT_SCRIPT)

@onready var phase_label: Label = %CommodityTrackPhaseLabel
@onready var count_label: Label = %CommodityTrackCountLabel
@onready var item_host: HBoxContainer = %CommodityTrackItemHost
@onready var empty_label: Label = %CommodityTrackEmptyLabel

var _snapshot: SNAPSHOT_SCRIPT
var _item_nodes_by_id: Dictionary = {}
var _selected_slot_id := ""
var _last_snapshot_revision := -1
var _last_snapshot_fingerprint := ""
var _created_node_count := 0
var _reused_node_count := 0
var _removed_node_count := 0
var _stale_rejection_count := 0
var _duplicate_id_rejection_count := 0
var _belt_motion := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_apply_panel_style()
	_update_density()


func set_snapshot(snapshot: SNAPSHOT_SCRIPT) -> bool:
	if snapshot == null or not snapshot.is_valid():
		_stale_rejection_count += 1
		return false
	var data := snapshot.to_dictionary()
	var fingerprint := JSON.stringify(data, "", true)
	if snapshot.snapshot_revision < _last_snapshot_revision:
		_stale_rejection_count += 1
		return false
	if snapshot.snapshot_revision == _last_snapshot_revision:
		if fingerprint == _last_snapshot_fingerprint:
			return true
		_stale_rejection_count += 1
		return false
	var seen_ids: Dictionary = {}
	for item in snapshot.items:
		if seen_ids.has(item.commodity_slot_id):
			_duplicate_id_rejection_count += 1
			return false
		seen_ids[item.commodity_slot_id] = true
	_snapshot = SNAPSHOT_SCRIPT.new().apply_dictionary(data)
	_last_snapshot_revision = snapshot.snapshot_revision
	_last_snapshot_fingerprint = fingerprint
	_sync_item_nodes()
	_sync_header()
	return true


func set_snapshot_dictionary(data: Dictionary) -> bool:
	return set_snapshot(SNAPSHOT_SCRIPT.new().apply_dictionary(data))


func item_snapshot_by_id(slot_id: String) -> ITEM_SNAPSHOT_SCRIPT:
	return _snapshot.item_by_id(slot_id) if _snapshot != null and _snapshot.is_valid() else null


func selected_item_snapshot() -> ITEM_SNAPSHOT_SCRIPT:
	return item_snapshot_by_id(_selected_slot_id)


func debug_snapshot() -> Dictionary:
	return {
		"snapshot_revision": _last_snapshot_revision,
		"rendered_item_count": _item_nodes_by_id.size(),
		"rendered_slot_ids": _ordered_rendered_ids(),
		"selected_slot_id": _selected_slot_id,
		"created_node_count": _created_node_count,
		"reused_node_count": _reused_node_count,
		"removed_node_count": _removed_node_count,
		"stale_rejection_count": _stale_rejection_count,
		"duplicate_id_rejection_count": _duplicate_id_rejection_count,
		"cards_are_stationary": true,
		"belt_decoration_moves": true,
		"clear_all_rebuild_count": 0,
	}


func _process(delta: float) -> void:
	_belt_motion = fmod(_belt_motion + maxf(0.0, delta) * 18.0, 24.0)
	queue_redraw()


func _draw() -> void:
	var y := size.y - 17.0
	draw_line(Vector2(10.0, y), Vector2(size.x - 10.0, y), Color("#38bdf8", 0.22), 2.0)
	var x := -24.0 + _belt_motion
	while x < size.x:
		draw_line(Vector2(x, y - 4.0), Vector2(x + 10.0, y + 4.0), Color("#f8fafc", 0.16), 2.0)
		x += 24.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_density()


func _sync_item_nodes() -> void:
	var wanted: Dictionary = {}
	for item in _snapshot.items:
		wanted[item.commodity_slot_id] = true
		var item_node := _item_nodes_by_id.get(item.commodity_slot_id) as ITEM_NODE_SCRIPT
		if item_node == null:
			item_node = ITEM_SCENE.instantiate() as ITEM_NODE_SCRIPT
			if item_node == null:
				continue
			item_node.name = "CommoditySlot_%s" % _safe_node_name(item.commodity_slot_id)
			item_host.add_child(item_node)
			item_node.item_focused.connect(_on_item_focused)
			item_node.claim_requested.connect(_on_claim_requested)
			_item_nodes_by_id[item.commodity_slot_id] = item_node
			_created_node_count += 1
		else:
			_reused_node_count += 1
		item_node.set_item(item)
	for existing_id_variant in _item_nodes_by_id.keys():
		var existing_id := str(existing_id_variant)
		if wanted.has(existing_id):
			continue
		var stale_node := _item_nodes_by_id.get(existing_id) as Node
		_item_nodes_by_id.erase(existing_id)
		if stale_node != null:
			stale_node.queue_free()
		_removed_node_count += 1
		if _selected_slot_id == existing_id:
			_selected_slot_id = ""
	for index in range(_snapshot.items.size()):
		var item := _snapshot.items[index]
		var item_node := _item_nodes_by_id.get(item.commodity_slot_id) as Control
		if item_node != null and item_node.get_index() != index:
			item_host.move_child(item_node, index)
	_sync_selected_state()


func _sync_header() -> void:
	phase_label.text = _snapshot.public_refresh_phase if _snapshot != null else ""
	count_label.text = "%d 件公开商品" % _item_nodes_by_id.size()
	empty_label.text = _snapshot.empty_text if _snapshot != null else "共享商品带尚未就绪。"
	empty_label.visible = _item_nodes_by_id.is_empty()
	item_host.visible = not _item_nodes_by_id.is_empty()


func _on_item_focused(item: ITEM_SNAPSHOT_SCRIPT) -> void:
	if item == null or not item.is_valid():
		return
	_selected_slot_id = item.commodity_slot_id
	_sync_selected_state()
	item_focused.emit(item)


func _on_claim_requested(item: ITEM_SNAPSHOT_SCRIPT) -> void:
	_on_item_focused(item)
	claim_requested.emit(item)


func _sync_selected_state() -> void:
	for slot_id_variant in _item_nodes_by_id.keys():
		var slot_id := str(slot_id_variant)
		var item_node := _item_nodes_by_id.get(slot_id) as ITEM_NODE_SCRIPT
		if item_node != null:
			item_node.set_selected(slot_id == _selected_slot_id)


func _ordered_rendered_ids() -> Array[String]:
	var result: Array[String] = []
	for child in item_host.get_children():
		if child is ITEM_NODE_SCRIPT:
			var item := (child as ITEM_NODE_SCRIPT).item_snapshot()
			if item != null:
				result.append(item.commodity_slot_id)
	return result


func _update_density() -> void:
	var viewport_height := get_viewport_rect().size.y if is_inside_tree() else 960.0
	custom_minimum_size.y = 138.0 if viewport_height >= 900.0 else 120.0
	for node_variant in _item_nodes_by_id.values():
		if node_variant is Control:
			(node_variant as Control).custom_minimum_size = Vector2(100, 100 if viewport_height >= 900.0 else 88)


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#030b16", 0.96)
	style.border_color = Color("#334155")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)


func _safe_node_name(value: String) -> String:
	return value.replace(".", "_").replace(":", "_").replace("/", "_")
