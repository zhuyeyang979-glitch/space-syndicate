@tool
extends Node
class_name RoleSeatLayerHost

const DEFAULT_SKIN_SCENE_PATH := "res://scenes/ui/player_seat/PlayerSeatPortraitSkin.tscn"
const FALLBACK_SCENE := preload("res://scenes/ui/planet_table/RoleSeatFallback.tscn")
const DEFAULT_SEAT_SIZE := Vector2(112.0, 58.0)
const ALL_SEAT_POSITIONS := [
	&"top", &"left_high", &"left_mid", &"left_low",
	&"right_high", &"right_mid", &"right_low", &"bottom",
]

@export var stage_viewport_path: NodePath
@export var back_seat_layer_path: NodePath
@export var front_seat_layer_path: NodePath
@export var fallback_backdrop_path: NodePath
@export_file("*.tscn") var skin_scene_path := DEFAULT_SKIN_SCENE_PATH

@onready var stage_viewport: Control = get_node_or_null(stage_viewport_path) as Control
@onready var back_seat_layer: Control = get_node_or_null(back_seat_layer_path) as Control
@onready var front_seat_layer: Control = get_node_or_null(front_seat_layer_path) as Control
@onready var fallback_backdrop: Node = get_node_or_null(fallback_backdrop_path)

var _descriptors: Array = []
var _seat_nodes_by_player := {}
var _using_skin_by_player := {}


func _ready() -> void:
	_set_mouse_filter_recursive(back_seat_layer)
	_set_mouse_filter_recursive(front_seat_layer)
	if stage_viewport != null:
		stage_viewport.resized.connect(_layout_seats)


func set_seat_descriptors(value: Array) -> void:
	_descriptors = _validated_descriptors(value)
	_sync_seat_nodes()
	_sync_fallback_decorations()
	_layout_seats()


func seat_descriptors() -> Array:
	return _descriptors.duplicate(true)


func layout_debug_snapshot() -> Dictionary:
	var seats: Array = []
	for descriptor_variant in _descriptors:
		var descriptor: Dictionary = descriptor_variant
		var player_index := int(descriptor.get("player_index", -1))
		var node := _seat_nodes_by_player.get(player_index) as Control
		if node == null:
			continue
		seats.append({
			"player_index": player_index,
			"seat_position": descriptor.get("seat_position", &""),
			"depth_group": descriptor.get("depth_group", &""),
			"portrait_variant": descriptor.get("portrait_variant", &""),
			"mirror_h": bool(descriptor.get("mirror_h", false)),
			"is_local_player": bool(descriptor.get("is_local_player", false)),
			"rect": Rect2(node.position, node.size),
			"global_rect": node.get_global_rect(),
			"using_skin": bool(_using_skin_by_player.get(player_index, false)),
			"mouse_filter": node.mouse_filter,
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
	instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(instance)


func _retire_node(node: Control) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _move_to_depth_layer(node: Control, depth_group: StringName) -> void:
	var target := back_seat_layer if depth_group == &"back" else front_seat_layer
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
	var seat_position := StringName(descriptor.get("seat_position", &"bottom"))
	var public_status := StringName(descriptor.get("public_status", &"waiting"))
	var is_public_actor := bool(descriptor.get("is_publicly_active", false))
	var anonymous_action := bool(descriptor.get("public_activity_is_anonymous", false))
	return {
		"seat_index": int(descriptor.get("player_index", -1)),
		"player_display_name": str(descriptor.get("public_player_name", "玩家")),
		"public_role_name": str(descriptor.get("role_name", "外星辛迪加")),
		"player_color": descriptor.get("player_color", Color.WHITE),
		"is_local_player": bool(descriptor.get("is_local_player", false)),
		"is_publicly_active": is_public_actor and not anonymous_action,
		"is_bankrupt": public_status == &"eliminated",
		"is_disconnected": public_status == &"disconnected",
		"public_status": _skin_public_status(public_status, is_public_actor, anonymous_action),
		"inward_direction": _skin_inward_direction(seat_position),
		"depth_class": _skin_depth_class(StringName(descriptor.get("depth_group", &"front")), seat_position),
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
	if str(seat_position).begins_with("left_"):
		return "left"
	if str(seat_position).begins_with("right_"):
		return "right"
	return "front"


func _skin_depth_class(depth_group: StringName, seat_position: StringName) -> String:
	if depth_group == &"back":
		return "far"
	if seat_position == &"bottom":
		return "near"
	return "mid"


func _sync_fallback_decorations() -> void:
	if fallback_backdrop == null or not fallback_backdrop.has_method("set_seat_decoration_visibility"):
		return
	var visibility := {}
	for seat_position in ALL_SEAT_POSITIONS:
		visibility[str(seat_position)] = false
	for descriptor_variant in _descriptors:
		var descriptor: Dictionary = descriptor_variant
		var player_index := int(descriptor.get("player_index", -1))
		var seat_position := str(descriptor.get("seat_position", ""))
		if seat_position != "":
			visibility[seat_position] = not bool(_using_skin_by_player.get(player_index, false))
	fallback_backdrop.call("set_seat_decoration_visibility", visibility)


func _layout_seats() -> void:
	if stage_viewport == null or stage_viewport.size.x <= 1.0 or stage_viewport.size.y <= 1.0:
		return
	var stage_size := stage_viewport.size
	for descriptor_variant in _descriptors:
		var descriptor: Dictionary = descriptor_variant
		var node := _seat_nodes_by_player.get(int(descriptor.get("player_index", -1))) as Control
		if node == null:
			continue
		var visual_size := node.get_combined_minimum_size()
		if visual_size.x <= 1.0 or visual_size.y <= 1.0:
			visual_size = DEFAULT_SEAT_SIZE
		node.size = visual_size
		node.pivot_offset = Vector2(visual_size.x * 0.5, visual_size.y)
		var anchor := _seat_anchor(StringName(descriptor.get("seat_position", &"bottom")), stage_size)
		var position := anchor - Vector2(visual_size.x * 0.5, visual_size.y)
		position.x = clampf(position.x, 8.0, maxf(8.0, stage_size.x - visual_size.x - 8.0))
		position.y = clampf(position.y, 8.0, maxf(8.0, stage_size.y - visual_size.y - 8.0))
		node.position = position.round()


func _seat_anchor(seat_position: StringName, viewport_size: Vector2) -> Vector2:
	match seat_position:
		&"top":
			return Vector2(viewport_size.x * 0.50, viewport_size.y * 0.21)
		&"left_high":
			return Vector2(viewport_size.x * 0.14, viewport_size.y * 0.31)
		&"left_mid":
			return Vector2(viewport_size.x * 0.11, viewport_size.y * 0.53)
		&"left_low":
			return Vector2(viewport_size.x * 0.16, viewport_size.y * 0.76)
		&"right_high":
			return Vector2(viewport_size.x * 0.86, viewport_size.y * 0.31)
		&"right_mid":
			return Vector2(viewport_size.x * 0.89, viewport_size.y * 0.53)
		&"right_low":
			return Vector2(viewport_size.x * 0.84, viewport_size.y * 0.76)
		_:
			return Vector2(viewport_size.x * 0.50, viewport_size.y * 0.95)


func _validated_descriptors(value: Array) -> Array:
	var result: Array = []
	var seen := {}
	for descriptor_variant in value:
		if not (descriptor_variant is Dictionary):
			continue
		var descriptor: Dictionary = descriptor_variant
		var player_index := int(descriptor.get("player_index", -1))
		if player_index < 0 or seen.has(player_index):
			continue
		seen[player_index] = true
		result.append(descriptor.duplicate(true))
	return result.slice(0, 8)


func _set_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_filter_recursive(child)


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
