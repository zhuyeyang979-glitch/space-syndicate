@tool
extends Node
class_name RoleSeatLayerHost

signal player_inspection_requested(player_index: int)

const DEFAULT_SKIN_SCENE_PATH := "res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn"
const FALLBACK_SCENE := preload("res://scenes/ui/planet_table/RoleSeatFallback.tscn")
const DEFAULT_SEAT_SIZE := Vector2(132.0, 92.0)
const ORBIT_DECORATION_POSITIONS := [
	&"top", &"left_high", &"left_mid", &"left_low",
	&"right_high", &"right_mid", &"right_low", &"bottom",
]
const LEFT_COLUMN_POSITIONS := [&"left_high", &"left_mid_high", &"left_mid_low", &"left_low"]
const RIGHT_COLUMN_POSITIONS := [&"right_high", &"right_mid_high", &"right_mid_low", &"right_low"]
const SIDE_SEAT_POSITIONS := [
	&"left_low", &"right_low", &"left_mid_low", &"right_mid_low",
	&"left_mid_high", &"right_mid_high", &"left_high", &"right_high",
]
const COLUMN_GAP := 8.0
const ROW_GAP := 6.0
const EDGE_MARGIN := 8.0

@export var stage_viewport_path: NodePath
@export var map_host_path: NodePath
@export var map_view_path: NodePath
@export var back_seat_layer_path: NodePath
@export var front_seat_layer_path: NodePath
@export var fallback_backdrop_path: NodePath
@export_file("*.tscn") var skin_scene_path := DEFAULT_SKIN_SCENE_PATH

@onready var stage_viewport: Control = get_node_or_null(stage_viewport_path) as Control
@onready var map_host: Control = get_node_or_null(map_host_path) as Control
@onready var map_view: Control = get_node_or_null(map_view_path) as Control
@onready var back_seat_layer: Control = get_node_or_null(back_seat_layer_path) as Control
@onready var front_seat_layer: Control = get_node_or_null(front_seat_layer_path) as Control
@onready var fallback_backdrop: Node = get_node_or_null(fallback_backdrop_path)

var _descriptors: Array = []
var _seat_nodes_by_player := {}
var _using_skin_by_player := {}
var _inspected_player_index := -1


func _ready() -> void:
	_set_mouse_filter_recursive(back_seat_layer)
	_set_mouse_filter_recursive(front_seat_layer)
	if stage_viewport != null:
		stage_viewport.resized.connect(request_layout)
	if map_host != null:
		map_host.resized.connect(request_layout)


func set_seat_descriptors(value: Array) -> void:
	_descriptors = _validated_descriptors(value)
	_sync_seat_nodes()
	_sync_fallback_decorations()
	_layout_seats()
	_sync_inspection_state()


func seat_descriptors() -> Array:
	return _descriptors.duplicate(true)


func request_layout() -> void:
	_layout_seats()


func set_inspected_player_index(player_index: int) -> void:
	_inspected_player_index = player_index
	_sync_inspection_state()


func inspected_player_index() -> int:
	return _inspected_player_index


func focus_player(player_index: int) -> void:
	var node := _seat_nodes_by_player.get(player_index) as Control
	if node != null and node.focus_mode != Control.FOCUS_NONE:
		node.grab_focus()


func set_map_visual_target(value: Control) -> void:
	map_view = value
	request_layout()


func layout_debug_snapshot() -> Dictionary:
	var seats: Array = []
	for descriptor_variant in _descriptors:
		var descriptor: Dictionary = descriptor_variant
		var player_index := int(descriptor.get("player_index", -1))
		var node := _seat_nodes_by_player.get(player_index) as Control
		if node == null:
			continue
		seats.append({
			"seat_index": int(descriptor.get("seat_index", -1)),
			"player_index": player_index,
			"seat_position": descriptor.get("seat_position", &""),
			"depth_group": descriptor.get("depth_group", &""),
			"portrait_variant": descriptor.get("portrait_variant", &""),
			"mirror_h": bool(descriptor.get("mirror_h", false)),
			"is_local_player": bool(descriptor.get("is_local_player", false)),
			"rect": Rect2(node.position, node.size),
			"display_rect": Rect2(node.position, node.size * node.scale),
			"global_rect": node.get_global_rect(),
			"column": _seat_column(StringName(descriptor.get("seat_position", &"bottom"))),
			"column_row": _seat_column_row(StringName(descriptor.get("seat_position", &"bottom"))),
			"presentation_scale": node.scale.x,
			"visual_scale": float(descriptor.get("visual_scale", 1.0)),
			"resolved_inward_direction": _skin_inward_direction(StringName(descriptor.get("seat_position", &"bottom"))),
			"render_layer": node.get_parent().name if node.get_parent() != null else &"",
			"using_skin": bool(_using_skin_by_player.get(player_index, false)),
			"mouse_filter": node.mouse_filter,
			"inspected": player_index == _inspected_player_index,
		})
	return {
		"seat_count": seats.size(),
		"host_rect": stage_viewport.get_rect() if stage_viewport != null else Rect2(),
		"host_global_rect": stage_viewport.get_global_rect() if stage_viewport != null else Rect2(),
		"skin_resource_exists": ResourceLoader.exists(skin_scene_path),
		"fallback_decoration_visibility": fallback_backdrop.call("seat_decoration_visibility_snapshot") if fallback_backdrop != null and fallback_backdrop.has_method("seat_decoration_visibility_snapshot") else {},
		"seats": seats,
	}


func _sync_seat_nodes() -> void:
	var wanted := {}
	for descriptor_variant in _descriptors:
		var descriptor: Dictionary = descriptor_variant
		var player_index := int(descriptor.get("player_index", -1))
		wanted[player_index] = true
		var node := _seat_nodes_by_player.get(player_index) as Control
		var currently_using_skin := bool(_using_skin_by_player.get(player_index, false))
		if node == null or (not currently_using_skin and ResourceLoader.exists(skin_scene_path)):
			_replace_seat_node(player_index, node, descriptor)
			node = _seat_nodes_by_player.get(player_index) as Control
			currently_using_skin = bool(_using_skin_by_player.get(player_index, false))
		if node != null:
			_move_to_depth_layer(node, StringName(descriptor.get("depth_group", &"front")))
			if currently_using_skin:
				var applied := _apply_skin_descriptor(node, descriptor)
				if not applied:
					_replace_with_fallback(player_index, node, descriptor)
			else:
				_apply_fallback_descriptor(node, descriptor)
	for player_index_variant in _seat_nodes_by_player.keys():
		var player_index := int(player_index_variant)
		if wanted.has(player_index):
			continue
		var stale := _seat_nodes_by_player.get(player_index) as Control
		if stale != null:
			stale.queue_free()
		_seat_nodes_by_player.erase(player_index)
		_using_skin_by_player.erase(player_index)


func _replace_seat_node(player_index: int, previous: Control, descriptor: Dictionary) -> void:
	_retire_node(previous)
	var skin := _instantiate_skin(descriptor)
	if skin != null:
		_seat_nodes_by_player[player_index] = skin
		_using_skin_by_player[player_index] = true
		return
	var fallback := _instantiate_fallback(descriptor)
	_seat_nodes_by_player[player_index] = fallback
	_using_skin_by_player[player_index] = false


func _replace_with_fallback(player_index: int, previous: Control, descriptor: Dictionary) -> void:
	_retire_node(previous)
	var fallback := _instantiate_fallback(descriptor)
	_seat_nodes_by_player[player_index] = fallback
	_using_skin_by_player[player_index] = false
	if fallback != null:
		_move_to_depth_layer(fallback, StringName(descriptor.get("depth_group", &"front")))
		_apply_fallback_descriptor(fallback, descriptor)


func _instantiate_skin(descriptor: Dictionary) -> Control:
	if not ResourceLoader.exists(skin_scene_path):
		return null
	var resource := ResourceLoader.load(skin_scene_path)
	if not (resource is PackedScene):
		return null
	var raw_instance := (resource as PackedScene).instantiate()
	if not (raw_instance is Control):
		if raw_instance != null:
			raw_instance.free()
		return null
	var instance := raw_instance as Control
	if not instance.has_method("apply_public_view_model"):
		_retire_node(instance)
		return null
	_prepare_node(instance, descriptor)
	_move_to_depth_layer(instance, StringName(descriptor.get("depth_group", &"front")))
	if not _apply_skin_descriptor(instance, descriptor):
		_retire_node(instance)
		return null
	return instance


func _instantiate_fallback(descriptor: Dictionary) -> Control:
	var instance := FALLBACK_SCENE.instantiate() as Control
	if instance == null:
		return null
	_prepare_node(instance, descriptor)
	_move_to_depth_layer(instance, StringName(descriptor.get("depth_group", &"front")))
	_apply_fallback_descriptor(instance, descriptor)
	return instance


func _prepare_node(instance: Control, descriptor: Dictionary) -> void:
	instance.name = "PlayerSeat_%d" % int(descriptor.get("player_index", 0))
	_set_mouse_filter_recursive(instance)
	instance.mouse_filter = Control.MOUSE_FILTER_STOP
	instance.focus_mode = Control.FOCUS_ALL
	var player_index := int(descriptor.get("player_index", -1))
	instance.gui_input.connect(_on_seat_gui_input.bind(player_index))
	instance.mouse_entered.connect(_on_seat_mouse_entered.bind(instance))
	instance.mouse_exited.connect(_on_seat_mouse_exited.bind(instance))


func _retire_node(node: Control) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _move_to_depth_layer(node: Control, _depth_group: StringName) -> void:
	# Circular front/back depth no longer applies once all seats live beside the
	# globe. Keeping every card above the map prevents valid seats disappearing
	# behind the oversized 720px planet presentation surface.
	var target := front_seat_layer
	if node.get_parent() != target:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		target.add_child(node)


func _apply_fallback_descriptor(node: Control, descriptor: Dictionary) -> void:
	node.set_meta("seat_descriptor", descriptor.duplicate(true))
	node.tooltip_text = "%s｜%s" % [
		str(descriptor.get("public_player_name", "玩家")),
		str(descriptor.get("role_name", "外星辛迪加")),
	]
	if node.has_method("set_seat_descriptor"):
		node.call("set_seat_descriptor", descriptor.duplicate(true))
	elif _has_property(node, &"mirror_h"):
		node.set("mirror_h", bool(descriptor.get("mirror_h", false)))


func _apply_skin_descriptor(node: Control, descriptor: Dictionary) -> bool:
	if node == null or not node.has_method("apply_public_view_model"):
		return false
	node.set_meta("seat_descriptor", descriptor.duplicate(true))
	node.tooltip_text = "%s｜%s" % [
		str(descriptor.get("public_player_name", "玩家")),
		str(descriptor.get("role_name", "外星辛迪加")),
	]
	var result: Variant = node.call("apply_public_view_model", _skin_view_model(descriptor))
	return bool(result) and (not node.has_method("skin_available") or bool(node.call("skin_available")))


func _skin_view_model(descriptor: Dictionary) -> Dictionary:
	var seat_position := StringName(descriptor.get("seat_position", &"left_low"))
	var public_status := StringName(descriptor.get("public_status", &"waiting"))
	var is_public_actor := bool(descriptor.get("is_publicly_active", false))
	var anonymous_action := bool(descriptor.get("public_activity_is_anonymous", false))
	return {
		"seat_index": int(descriptor.get("seat_index", -1)),
		"player_display_name": str(descriptor.get("public_player_name", "玩家")),
		"public_role_name": str(descriptor.get("role_name", "外星辛迪加")),
		"player_color": descriptor.get("player_color", Color.WHITE),
		"is_local_player": bool(descriptor.get("is_local_player", false)),
		"is_publicly_active": is_public_actor and not anonymous_action,
		"is_bankrupt": public_status == &"eliminated",
		"is_disconnected": public_status == &"disconnected",
		"public_status": _skin_public_status(public_status, is_public_actor, anonymous_action),
		"inward_direction": _skin_inward_direction(seat_position),
		"depth_class": "near" if bool(descriptor.get("is_local_player", false)) else "mid",
		"anonymous_action_active": anonymous_action,
	}


func _skin_public_status(status: StringName, active: bool, anonymous_action: bool) -> String:
	if status == &"eliminated":
		return "bankrupt"
	if status == &"disconnected":
		return "disconnected"
	if active and not anonymous_action:
		return "public_actor"
	if status in [&"waiting", &"ready"]:
		return "waiting"
	return "normal"


func _skin_inward_direction(seat_position: StringName) -> String:
	if seat_position in LEFT_COLUMN_POSITIONS:
		return "left"
	return "right"


func _sync_fallback_decorations() -> void:
	if fallback_backdrop == null or not fallback_backdrop.has_method("set_seat_decoration_visibility"):
		return
	var visibility := {}
	for seat_position in ORBIT_DECORATION_POSITIONS:
		visibility[str(seat_position)] = false
	# Side-column cards provide the fallback themselves. The old orbit pips would
	# otherwise leave a second, circular seat presentation around the globe.
	fallback_backdrop.call("set_seat_decoration_visibility", visibility)


func _layout_seats() -> void:
	if stage_viewport == null or stage_viewport.size.x <= 1.0 or stage_viewport.size.y <= 1.0:
		return
	var stage_size := stage_viewport.size
	var map_rect := _map_visual_rect(stage_size)
	_layout_column(_column_descriptors(&"left"), &"left", stage_size, map_rect)
	_layout_column(_column_descriptors(&"right"), &"right", stage_size, map_rect)


func _layout_column(descriptors: Array, column: StringName, stage_size: Vector2, map_rect: Rect2) -> void:
	if descriptors.is_empty():
		return
	var side_width := map_rect.position.x - COLUMN_GAP - EDGE_MARGIN if column == &"left" else stage_size.x - map_rect.end.x - COLUMN_GAP - EDGE_MARGIN
	var row_space := stage_size.y - EDGE_MARGIN * 2.0 - ROW_GAP * float(maxi(0, descriptors.size() - 1))
	var scale_weight := 0.0
	var max_multiplier := 1.0
	for descriptor_variant in descriptors:
		var multiplier := _descriptor_scale_multiplier(descriptor_variant as Dictionary)
		scale_weight += multiplier
		max_multiplier = maxf(max_multiplier, multiplier)
	var horizontal_scale := side_width / (DEFAULT_SEAT_SIZE.x * max_multiplier)
	var vertical_scale := row_space / (DEFAULT_SEAT_SIZE.y * scale_weight)
	var scale_factor := minf(1.0, minf(horizontal_scale, vertical_scale))
	scale_factor = maxf(0.1, scale_factor)
	var column_height := DEFAULT_SEAT_SIZE.y * scale_factor * scale_weight + ROW_GAP * float(maxi(0, descriptors.size() - 1))
	var start_y := maxf(EDGE_MARGIN, (stage_size.y - column_height) * 0.5)
	var y := start_y
	for row in range(descriptors.size()):
		var descriptor: Dictionary = descriptors[row]
		var node := _seat_nodes_by_player.get(int(descriptor.get("player_index", -1))) as Control
		if node == null:
			continue
		var node_scale := scale_factor * _descriptor_scale_multiplier(descriptor)
		var display_size := DEFAULT_SEAT_SIZE * node_scale
		var x := map_rect.position.x - COLUMN_GAP - display_size.x if column == &"left" else map_rect.end.x + COLUMN_GAP
		x = clampf(x, EDGE_MARGIN, maxf(EDGE_MARGIN, stage_size.x - display_size.x - EDGE_MARGIN))
		node.size = DEFAULT_SEAT_SIZE
		node.scale = Vector2.ONE * node_scale
		node.pivot_offset = Vector2.ZERO
		node.position = Vector2(x, y).round()
		y += display_size.y + ROW_GAP


func _descriptor_scale_multiplier(descriptor: Dictionary) -> float:
	return clampf(float(descriptor.get("visual_scale", 1.0)), 1.0, 1.10)


func _column_descriptors(column: StringName) -> Array:
	var ordered_positions := LEFT_COLUMN_POSITIONS if column == &"left" else RIGHT_COLUMN_POSITIONS
	var result: Array = []
	for seat_position in ordered_positions:
		for descriptor_variant in _descriptors:
			var descriptor: Dictionary = descriptor_variant
			if StringName(descriptor.get("seat_position", &"")) == seat_position:
				result.append(descriptor)
	return result


func _seat_column(seat_position: StringName) -> StringName:
	return &"left" if seat_position in LEFT_COLUMN_POSITIONS else &"right"


func _seat_column_row(seat_position: StringName) -> int:
	var positions := LEFT_COLUMN_POSITIONS if seat_position in LEFT_COLUMN_POSITIONS else RIGHT_COLUMN_POSITIONS
	return positions.find(seat_position)


func _map_visual_rect(stage_size: Vector2) -> Rect2:
	if map_view != null and is_instance_valid(map_view) and map_view.visible:
		return Rect2(map_view.global_position - stage_viewport.global_position, map_view.size * map_view.scale)
	if map_host != null:
		return Rect2(map_host.position, map_host.size)
	return Rect2(stage_size * 0.25, stage_size * 0.5)


func _validated_descriptors(value: Array) -> Array:
	var result: Array = []
	var seen_players := {}
	var seen_positions := {}
	for descriptor_variant in value:
		if not (descriptor_variant is Dictionary):
			continue
		var descriptor: Dictionary = descriptor_variant
		var player_index := int(descriptor.get("player_index", -1))
		var seat_position := StringName(descriptor.get("seat_position", &""))
		if player_index < 0 or seen_players.has(player_index) \
				or seat_position not in SIDE_SEAT_POSITIONS or seen_positions.has(seat_position):
			continue
		seen_players[player_index] = true
		seen_positions[seat_position] = true
		result.append(descriptor.duplicate(true))
	return result.slice(0, 8)


func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)


func _on_seat_gui_input(event: InputEvent, player_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		player_inspection_requested.emit(player_index)
		get_viewport().set_input_as_handled()
		return
	var action_event := event as InputEventAction
	if action_event != null and action_event.action == &"ui_accept" and action_event.pressed:
		player_inspection_requested.emit(player_index)
		get_viewport().set_input_as_handled()
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode in [KEY_ENTER, KEY_SPACE]:
		player_inspection_requested.emit(player_index)
		get_viewport().set_input_as_handled()


func _on_seat_mouse_entered(node: Control) -> void:
	if node != null and node.has_method("set_host_hovered"):
		node.call("set_host_hovered", true)


func _on_seat_mouse_exited(node: Control) -> void:
	if node != null and node.has_method("set_host_hovered"):
		node.call("set_host_hovered", false)


func _sync_inspection_state() -> void:
	for player_index_variant in _seat_nodes_by_player.keys():
		var player_index := int(player_index_variant)
		var node := _seat_nodes_by_player.get(player_index) as Control
		if node == null:
			continue
		node.set_meta("inspected_player", player_index == _inspected_player_index)
		var outline := node.get_node_or_null("InspectionOutline") as Panel
		if outline == null:
			outline = Panel.new()
			outline.name = "InspectionOutline"
			outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			outline.z_index = 20
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			style.border_color = Color("#f8fafc")
			style.set_border_width_all(2)
			style.set_corner_radius_all(8)
			style.shadow_color = Color(0.22, 0.83, 0.96, 0.72)
			style.shadow_size = 7
			outline.add_theme_stylebox_override("panel", style)
			node.add_child(outline)
			outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		outline.visible = player_index == _inspected_player_index


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
