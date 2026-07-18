@tool
class_name PlayerSeatPortraitSkin
extends Control

signal skin_availability_changed(available: bool)

const RolePortraitCatalogScript := preload("res://scripts/presentation/role_portrait_catalog.gd")
const STATUS_NORMAL := "normal"
const STATUS_WAITING := "waiting"
const STATUS_PUBLIC_ACTOR := "public_actor"
const STATUS_BANKRUPT := "bankrupt"
const STATUS_DISCONNECTED := "disconnected"
const SAFE_PUBLIC_FIELDS := [
	"seat_index",
	"player_display_name",
	"public_role_name",
	"player_color",
	"is_local_player",
	"is_publicly_active",
	"is_bankrupt",
	"is_disconnected",
	"public_status",
	"inward_direction",
	"depth_class",
	"anonymous_action_active",
]

@export var show_public_labels := true

@onready var visual_root: Control = $VisualRoot
@onready var portrait_back_glow: Panel = $VisualRoot/PortraitBackGlow
@onready var portrait_shadow: Panel = $VisualRoot/PortraitShadow
@onready var portrait_clip: Panel = $VisualRoot/PortraitClip
@onready var portrait_texture: TextureRect = $VisualRoot/PortraitClip/PortraitTexture
@onready var seat_pod_back: Panel = $VisualRoot/SeatPodBack
@onready var seat_pod_front: Panel = $VisualRoot/SeatPodFront
@onready var player_color_strip: ColorRect = $VisualRoot/SeatPodFront/PlayerColorStrip
@onready var role_badge: Label = $VisualRoot/SeatPodFront/RoleBadge
@onready var public_status_badge: Label = $VisualRoot/SeatPodFront/PublicStatusBadge
@onready var name_plate: Label = $VisualRoot/SeatPodFront/NamePlate

var _catalog
var _seat_index := -1
var _player_display_name := ""
var _public_role_name := ""
var _public_status := STATUS_NORMAL
var _player_color := Color("#38bdf8")
var _is_local_player := false
var _is_publicly_active := false
var _anonymous_action_active := false
var _inward_direction := "front"
var _depth_class := "mid"
var _skin_available := false
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_descendant_mouse_filter(self)
	_catalog = RolePortraitCatalogScript.new()
	visible = false
	set_process(true)


func apply_public_view_model(view_model: Dictionary) -> bool:
	_seat_index = int(view_model.get("seat_index", _seat_index))
	_player_display_name = str(view_model.get("player_display_name", "")).strip_edges()
	_public_role_name = str(view_model.get("public_role_name", "")).strip_edges()
	var color_value: Variant = view_model.get("player_color", _player_color)
	if color_value is Color:
		_player_color = color_value as Color
	elif color_value is String and Color.html_is_valid(str(color_value)):
		_player_color = Color(str(color_value))
	_is_local_player = bool(view_model.get("is_local_player", false))
	_is_publicly_active = bool(view_model.get("is_publicly_active", false))
	_anonymous_action_active = bool(view_model.get("anonymous_action_active", false))
	_inward_direction = _normalized_direction(str(view_model.get("inward_direction", "front")))
	_depth_class = _normalized_depth(str(view_model.get("depth_class", "mid")))
	_public_status = _status_from_view_model(view_model)
	var texture := _catalog.portrait_texture_or_null(_public_role_name, _portrait_view()) as Texture2D
	_set_skin_available(texture != null)
	if not _skin_available:
		return false
	portrait_texture.texture = texture
	portrait_texture.flip_h = _inward_direction == "right"
	_apply_visual_state()
	return true


func set_host_hovered(hovered: bool) -> void:
	if not _skin_available:
		return
	var target_scale := 1.025 if hovered else 1.0
	visual_root.scale = Vector2.ONE * target_scale


func skin_available() -> bool:
	return _skin_available


func public_debug_snapshot() -> Dictionary:
	return {
		"available": _skin_available,
		"seat_index": _seat_index,
		"public_role_name": _public_role_name,
		"public_status": _public_status,
		"portrait_view": _portrait_view(),
		"flip_horizontal": portrait_texture.flip_h if is_instance_valid(portrait_texture) else false,
		"depth_class": _depth_class,
		"public_actor_highlighted": _is_publicly_active and not _anonymous_action_active,
		"anonymous_action_suppresses_highlight": _anonymous_action_active,
		"mouse_filter": mouse_filter,
		"owns_layout": false,
		"owns_player_mapping": false,
		"owns_input": false,
	}


func accepted_public_fields() -> PackedStringArray:
	return PackedStringArray(SAFE_PUBLIC_FIELDS)


func _process(delta: float) -> void:
	if not _skin_available or not is_instance_valid(visual_root):
		return
	_elapsed += delta
	var idle_float := sin(_elapsed * 1.25 + float(maxi(_seat_index, 0)) * 0.43) * 1.5
	visual_root.position.y = idle_float
	var actor_visible := _is_publicly_active and not _anonymous_action_active and _public_status != STATUS_BANKRUPT
	var target_scale := Vector2.ONE * (1.04 if actor_visible else 1.0)
	visual_root.scale = visual_root.scale.lerp(target_scale, clampf(delta * 8.0, 0.0, 1.0))
	var pulse := 0.70 + sin(_elapsed * 3.2) * 0.14 if actor_visible else 0.76
	player_color_strip.color = Color(_player_color, pulse if _public_status != STATUS_BANKRUPT else 0.08)


func _apply_visual_state() -> void:
	role_badge.visible = show_public_labels
	name_plate.visible = show_public_labels
	public_status_badge.visible = show_public_labels and not _status_label().is_empty()
	role_badge.text = _public_role_name
	name_plate.text = _player_display_name
	public_status_badge.text = _status_label()
	_apply_compact_direction_layout()
	var tint := Color.WHITE
	match _public_status:
		STATUS_WAITING:
			tint = Color(0.74, 0.79, 0.86, 1.0)
		STATUS_BANKRUPT:
			tint = Color(0.30, 0.32, 0.36, 0.86)
		STATUS_DISCONNECTED:
			tint = Color(0.52, 0.57, 0.62, 0.90)
	portrait_texture.modulate = tint
	seat_pod_back.modulate = tint
	seat_pod_front.modulate = tint
	_apply_depth_style()
	_update_glow()


func _apply_depth_style() -> void:
	match _depth_class:
		"far":
			visual_root.modulate = Color(0.82, 0.86, 0.92, 1.0)
		"near":
			visual_root.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_:
			visual_root.modulate = Color(0.92, 0.95, 1.0, 1.0)


func _apply_compact_direction_layout() -> void:
	var portrait_on_right := _inward_direction == "right"
	portrait_clip.position.x = 76.0 if portrait_on_right else 4.0
	portrait_shadow.position.x = 74.0 if portrait_on_right else 2.0
	portrait_back_glow.position.x = 72.0 if portrait_on_right else 0.0
	var text_left := 5.0 if portrait_on_right else 58.0
	var text_right := 74.0 if portrait_on_right else 127.0
	for label in [role_badge, name_plate, public_status_badge]:
		label.position.x = text_left
		label.size.x = text_right - text_left


func _update_glow() -> void:
	var actor_visible := _is_publicly_active and not _anonymous_action_active and _public_status != STATUS_BANKRUPT
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(_player_color, 0.10 if actor_visible else 0.035)
	glow.set_corner_radius_all(8)
	glow.shadow_color = Color(_player_color, 0.36 if actor_visible else 0.10)
	glow.shadow_size = 20 if actor_visible else 10
	portrait_back_glow.add_theme_stylebox_override("panel", glow)
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	shadow.set_corner_radius_all(7)
	shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	shadow.shadow_size = 12
	shadow.border_width_left = 1
	shadow.border_width_top = 1
	shadow.border_width_right = 1
	shadow.border_width_bottom = 1
	shadow.border_color = Color(_player_color, 0.84 if actor_visible else 0.26)
	portrait_shadow.add_theme_stylebox_override("panel", shadow)


func _set_skin_available(next_available: bool) -> void:
	if _skin_available == next_available:
		visible = next_available
		return
	_skin_available = next_available
	visible = next_available
	skin_availability_changed.emit(next_available)


func _status_from_view_model(view_model: Dictionary) -> String:
	if bool(view_model.get("is_bankrupt", false)):
		return STATUS_BANKRUPT
	if bool(view_model.get("is_disconnected", false)):
		return STATUS_DISCONNECTED
	var value := str(view_model.get("public_status", STATUS_NORMAL))
	return value if value in [STATUS_NORMAL, STATUS_WAITING, STATUS_PUBLIC_ACTOR, STATUS_BANKRUPT, STATUS_DISCONNECTED] else STATUS_NORMAL


func _status_label() -> String:
	if _anonymous_action_active and _public_status == STATUS_PUBLIC_ACTOR:
		return ""
	match _public_status:
		STATUS_WAITING:
			return "等待"
		STATUS_PUBLIC_ACTOR:
			return "公开行动" if not _anonymous_action_active else ""
		STATUS_BANKRUPT:
			return "已破产"
		STATUS_DISCONNECTED:
			return "离线"
		_:
			return ""


func _portrait_view() -> String:
	return "front" if _inward_direction == "front" else "side_inward"


func _normalized_direction(value: String) -> String:
	return value if value in ["front", "left", "right"] else "front"


func _normalized_depth(value: String) -> String:
	return value if value in ["near", "mid", "far"] else "mid"


func _set_descendant_mouse_filter(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_descendant_mouse_filter(child)
