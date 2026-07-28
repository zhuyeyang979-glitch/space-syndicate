@tool
extends PanelContainer
class_name SpaceSyndicatePlayerRoster

signal player_inspection_requested(player_index: int)

const PROJECTION_FIELDS: Array[String] = [
	"schema_version",
	"source_revision",
	"viewer_index",
	"authorization_revision",
	"visibility_scope",
	"players",
]
const PLAYER_FIELDS: Array[String] = [
	"player_index",
	"public_order_index",
	"public_player_name",
	"role_name",
	"player_color",
	"is_local_player",
	"public_status",
	"is_publicly_active",
	"public_activity_is_anonymous",
]
@onready var roster_grid: GridContainer = %RosterGrid
@onready var roster_count_label: Label = %RosterCountLabel

var _buttons: Array[Button] = []
var _player_indices: Array[int] = []
var _selected_player_index := -1
var _viewer_index := -1
var _authorization_revision := 0
var _source_revision := -1
var _apply_count := 0
var _reject_count := 0
var _duplicate_count := 0
var _stale_count := 0
var _last_signature := ""
var _last_selection_receipt_revision := -1
var _selection_receipt_apply_count := 0
var _selection_receipt_reject_count := 0


func apply_projection(projection: Dictionary) -> bool:
	if not _valid_projection(projection):
		_reject_count += 1
		return false
	var next_revision := int(projection.get("source_revision", -1))
	if _source_revision >= 0 and next_revision < _source_revision:
		_stale_count += 1
		return false
	var signature := JSON.stringify({
		"viewer_index": projection.get("viewer_index", -1),
		"authorization_revision": projection.get("authorization_revision", 0),
		"visibility_scope": projection.get("visibility_scope", ""),
		"players": projection.get("players", []),
	})
	if signature == _last_signature:
		_source_revision = next_revision
		_duplicate_count += 1
		return true
	var players := (projection.get("players", []) as Array).duplicate(true)
	players.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("public_order_index", -1)) < int(right.get("public_order_index", -1))
	)
	var next_player_indices: Array[int] = []
	for player_variant in players:
		next_player_indices.append(int((player_variant as Dictionary).get("player_index", -1)))
	_viewer_index = int(projection.get("viewer_index", -1))
	_authorization_revision = int(projection.get("authorization_revision", 0))
	_source_revision = next_revision
	_last_signature = signature
	if _selected_player_index not in next_player_indices:
		_selected_player_index = _viewer_index
	_render(players)
	_apply_count += 1
	return true


func request_player_inspection(player_index: int) -> bool:
	if player_index not in _player_indices:
		return false
	_restore_committed_selection()
	player_inspection_requested.emit(player_index)
	return true


func bind_viewer(viewer_index: int, authorization_revision: int) -> void:
	if viewer_index == _viewer_index and authorization_revision == _authorization_revision:
		return
	clear_roster()
	_viewer_index = viewer_index
	_authorization_revision = authorization_revision


func apply_selection_receipt(receipt: TableSelectionReceipt) -> bool:
	if receipt == null \
			or not receipt.accepted \
			or not receipt.applied \
			or receipt.selection_kind != TableSelectionIntent.KIND_INSPECT_PLAYER \
			or receipt.viewer_index != _viewer_index \
			or receipt.inspected_player_index not in _player_indices \
			or receipt.selection_revision_after < 0 \
			or receipt.selection_revision_after <= _last_selection_receipt_revision:
		_selection_receipt_reject_count += 1
		return false
	_last_selection_receipt_revision = receipt.selection_revision_after
	_selection_receipt_apply_count += 1
	_select_player(receipt.inspected_player_index, false)
	return true


func clear_roster() -> void:
	_clear_children(roster_grid)
	_buttons.clear()
	_player_indices.clear()
	_selected_player_index = -1
	_viewer_index = -1
	_authorization_revision = 0
	_source_revision = -1
	_last_signature = ""
	_last_selection_receipt_revision = -1
	roster_grid.columns = 1
	roster_count_label.text = "等待公开席位"


func debug_snapshot() -> Dictionary:
	return {
		"apply_count": _apply_count,
		"reject_count": _reject_count,
		"duplicate_count": _duplicate_count,
		"stale_count": _stale_count,
		"source_revision": _source_revision,
		"viewer_index": _viewer_index,
		"authorization_revision": _authorization_revision,
		"roster_side": "left",
		"columns": roster_grid.columns,
		"player_count": _player_indices.size(),
		"public_order": _player_indices.duplicate(),
		"selected_player_index": _selected_player_index,
		"focus_links_valid": _focus_links_valid(),
		"viewer_marker_count": _viewer_marker_count(),
		"last_selection_receipt_revision": _last_selection_receipt_revision,
		"selection_receipt_apply_count": _selection_receipt_apply_count,
		"selection_receipt_reject_count": _selection_receipt_reject_count,
		"reads_private_state": false,
		"mutates_gameplay": false,
	}


func _valid_projection(projection: Dictionary) -> bool:
	if not PlayerVisibleSurfacePolicy.is_safe_closed_data(projection) \
			or not PlayerVisibleSurfacePolicy.exact_fields(projection, PROJECTION_FIELDS) \
			or int(projection.get("schema_version", 0)) != 1 \
			or int(projection.get("source_revision", -1)) < 0 \
			or int(projection.get("viewer_index", -1)) < 0 \
			or int(projection.get("viewer_index", -1)) != _viewer_index \
			or int(projection.get("authorization_revision", 0)) <= 0 \
			or int(projection.get("authorization_revision", 0)) != _authorization_revision \
			or str(projection.get("visibility_scope", "")) != "viewer_scoped_public" \
			or not (projection.get("players", []) is Array):
		return false
	var players := projection.get("players", []) as Array
	if players.size() < 3 or players.size() > 8:
		return false
	var player_indices: Array[int] = []
	var public_orders: Array[int] = []
	var local_count := 0
	for player_variant in players:
		if not (player_variant is Dictionary):
			return false
		var player := player_variant as Dictionary
		if not PlayerVisibleSurfacePolicy.exact_fields(player, PLAYER_FIELDS):
			return false
		var player_index := int(player.get("player_index", -1))
		var order_index := int(player.get("public_order_index", -1))
		if player_index < 0 or order_index < 0 \
				or player_index in player_indices or order_index in public_orders:
			return false
		player_indices.append(player_index)
		public_orders.append(order_index)
		if bool(player.get("is_local_player", false)):
			local_count += 1
			if player_index != int(projection.get("viewer_index", -1)):
				return false
	return local_count == 1


func _render(players: Array) -> void:
	_clear_children(roster_grid)
	_buttons.clear()
	_player_indices.clear()
	roster_grid.columns = 1 if players.size() <= 4 else 2
	for player_variant in players:
		var player := player_variant as Dictionary
		var player_index := int(player.get("player_index", -1))
		var button := Button.new()
		button.name = "RosterPlayer_%d" % player_index
		button.custom_minimum_size = Vector2(122, 54)
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = true
		button.set_meta("public_player_index", player_index)
		button.set_meta("public_order_index", int(player.get("public_order_index", -1)))
		button.set_meta("is_viewer", bool(player.get("is_local_player", false)))
		button.text = "%s%s\n%s · %s" % [
			PlayerVisibleSurfacePolicy.safe_text(player.get("public_player_name"), "玩家", 24),
			"（你）" if bool(player.get("is_local_player", false)) else "",
			PlayerVisibleSurfacePolicy.safe_text(player.get("role_name"), "外星辛迪加", 18),
			_status_label(str(player.get("public_status", "waiting"))),
		]
		button.tooltip_text = "查看 %s 的公开信息" % str(player.get("public_player_name", "玩家"))
		var accent := _as_color(player.get("player_color", Color("#94a3b8")))
		button.add_theme_color_override("font_color", accent.lightened(0.25))
		if bool(player.get("is_local_player", false)):
			button.self_modulate = Color(0.82, 0.95, 1.0, 1.0)
		button.button_pressed = player_index == _selected_player_index
		button.pressed.connect(_on_player_pressed.bind(player_index))
		roster_grid.add_child(button)
		_buttons.append(button)
		_player_indices.append(player_index)
	_configure_focus_links()
	roster_count_label.text = "%d 席｜%s" % [players.size(), "一列" if roster_grid.columns == 1 else "两列"]


func _on_player_pressed(player_index: int) -> void:
	request_player_inspection(player_index)


func _select_player(player_index: int, emit_request: bool) -> void:
	_selected_player_index = player_index
	for button in _buttons:
		button.button_pressed = int(button.get_meta("public_player_index", -1)) == player_index
	if emit_request:
		player_inspection_requested.emit(player_index)


func _restore_committed_selection() -> void:
	for button in _buttons:
		button.button_pressed = int(button.get_meta("public_player_index", -1)) == _selected_player_index


func _configure_focus_links() -> void:
	if _buttons.is_empty():
		return
	var columns := maxi(1, roster_grid.columns)
	var last_index := _buttons.size() - 1
	for index in range(_buttons.size()):
		var button := _buttons[index]
		var column := index % columns
		var top_index := index - columns if index >= columns else index
		var bottom_index := index + columns if index + columns <= last_index else index
		var left_index := index - 1 if column > 0 else index
		var right_index := index + 1 if column + 1 < columns and index + 1 <= last_index else index
		button.focus_neighbor_top = button.get_path_to(_buttons[top_index])
		button.focus_neighbor_bottom = button.get_path_to(_buttons[bottom_index])
		button.focus_neighbor_left = button.get_path_to(_buttons[left_index])
		button.focus_neighbor_right = button.get_path_to(_buttons[right_index])
		button.focus_next = button.get_path_to(_buttons[(index + 1) % _buttons.size()])
		button.focus_previous = button.get_path_to(_buttons[wrapi(index - 1, 0, _buttons.size())])


func _focus_links_valid() -> bool:
	if _buttons.is_empty() or _buttons.size() != _player_indices.size():
		return false
	for button in _buttons:
		if button.focus_mode != Control.FOCUS_ALL:
			return false
		if _buttons.size() > 1 and (button.focus_next.is_empty() or button.focus_previous.is_empty()):
			return false
	return true


func _viewer_marker_count() -> int:
	var count := 0
	for button in _buttons:
		if bool(button.get_meta("is_viewer", false)):
			count += 1
	return count


func _status_label(status: String) -> String:
	return str({
		"ready": "已就绪",
		"waiting": "等待",
		"active": "公开行动",
		"eliminated": "已离场",
		"disconnected": "暂离",
	}.get(status.strip_edges().to_lower(), "等待"))


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value as Color
	if value is String and Color.html_is_valid(str(value)):
		return Color(str(value))
	return Color("#94a3b8")


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
