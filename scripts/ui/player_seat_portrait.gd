@tool
class_name PlayerSeatPortrait
extends Control

signal public_seat_hovered(seat_number: int, role_name: String)
signal public_seat_unhovered(seat_number: int)

const STATUS_NORMAL := "normal"
const STATUS_WAITING := "waiting"
const STATUS_PUBLIC_ACTOR := "public_actor"
const STATUS_BANKRUPT := "bankrupt"
const BASE_SEAT_SIZE := Vector2(220.0, 280.0)

const SAFE_PUBLIC_FIELDS := [
	"seat_number",
	"role_name",
	"public_passive_summary",
	"public_status",
	"player_color",
	"is_public_actor",
	"anonymous_action_active",
]

@onready var visual_root: Control = $VisualRoot
@onready var portrait_shadow: Panel = $VisualRoot/PortraitShadow
@onready var portrait_texture: TextureRect = $VisualRoot/PortraitMask/PortraitTexture
@onready var missing_portrait: PanelContainer = $VisualRoot/PortraitMask/MissingPortrait
@onready var orbital_seat_pod: Panel = $VisualRoot/OrbitalSeatPod
@onready var player_color_strip: ColorRect = $VisualRoot/OrbitalSeatPod/PlayerColorStrip
@onready var seat_number_label: Label = $VisualRoot/OrbitalSeatPod/SeatNumber
@onready var public_role_label: Label = $VisualRoot/OrbitalSeatPod/PublicRoleLabel
@onready var public_status_badge: Label = $VisualRoot/OrbitalSeatPod/PublicStatusBadge
@onready var hover_area: Control = $HoverArea

var _seat_number := 1
var _role_name := "未配置角色"
var _public_passive_summary := "公开被动待载入"
var _public_status := STATUS_NORMAL
var _player_color := Color("#38bdf8")
var _is_public_actor := false
var _anonymous_action_active := false
var _is_placeholder := true
var _portrait_source := "missing"
var _actual_png_path := ""
var _source_model := ""
var _render_variant := "front"
var _hovered := false
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_shadow.visible = false
	_connect_hover_signals()
	_apply_visual_state()
	set_process(true)


func apply_public_snapshot(snapshot: Dictionary, texture: Texture2D = null) -> void:
	_seat_number = maxi(1, int(snapshot.get("seat_number", _seat_number)))
	_role_name = str(snapshot.get("role_name", _role_name)).strip_edges()
	if _role_name.is_empty():
		_role_name = "未配置角色"
	_public_passive_summary = str(snapshot.get("public_passive_summary", _public_passive_summary)).strip_edges()
	_public_status = _normalize_status(str(snapshot.get("public_status", STATUS_NORMAL)))
	var color_variant: Variant = snapshot.get("player_color", _player_color)
	if color_variant is Color:
		_player_color = color_variant as Color
	elif color_variant is String and Color.html_is_valid(str(color_variant)):
		_player_color = Color(str(color_variant))
	_is_public_actor = bool(snapshot.get("is_public_actor", false))
	_anonymous_action_active = bool(snapshot.get("anonymous_action_active", false))
	set_portrait_texture(texture)
	_apply_visual_state()


func set_portrait_texture(texture: Texture2D) -> void:
	if not is_node_ready():
		await ready
	_is_placeholder = texture == null or bool(texture.get_meta("role_portrait_is_placeholder", false))
	portrait_texture.texture = null if _is_placeholder else texture
	portrait_texture.visible = not _is_placeholder
	missing_portrait.visible = _is_placeholder


func set_qa_portrait_metadata(metadata: Dictionary) -> void:
	_portrait_source = str(metadata.get("portrait_source", "manifest"))
	_actual_png_path = str(metadata.get("actual_png_path", ""))
	_source_model = str(metadata.get("source_model", ""))
	_render_variant = str(metadata.get("render_variant", "front"))
	_is_placeholder = bool(metadata.get("is_placeholder", _is_placeholder))
	if is_node_ready():
		portrait_texture.visible = not _is_placeholder
		missing_portrait.visible = _is_placeholder


func set_side_orientation(flip_horizontal: bool) -> void:
	if not is_node_ready():
		await ready
	portrait_texture.flip_h = flip_horizontal


func apply_layout_spec(spec: Dictionary) -> void:
	var next_size: Vector2 = spec.get("size", BASE_SEAT_SIZE)
	var next_position: Vector2 = spec.get("position", position)
	size = BASE_SEAT_SIZE
	scale = Vector2(
		next_size.x / BASE_SEAT_SIZE.x,
		next_size.y / BASE_SEAT_SIZE.y
	)
	position = next_position
	set_side_orientation(bool(spec.get("flip_horizontal", false)))


func set_public_action_state(is_actor: bool, anonymous_action: bool) -> void:
	_is_public_actor = is_actor
	_anonymous_action_active = anonymous_action
	_apply_visual_state()


func get_public_debug_snapshot() -> Dictionary:
	return {
		"seat_number": _seat_number,
		"role_name": _role_name,
		"public_status": _public_status,
		"public_actor_highlighted": _is_public_actor and not _anonymous_action_active,
		"anonymous_action_suppresses_highlight": _anonymous_action_active,
		"hovered": _hovered,
		"mouse_filter": mouse_filter,
		"portrait_source": _portrait_source,
		"actual_png_path": _actual_png_path,
		"is_placeholder": _is_placeholder,
		"source_model": _source_model,
		"render_variant": _render_variant,
	}


func _process(delta: float) -> void:
	if not is_instance_valid(visual_root):
		return
	_elapsed += delta
	var idle_float := sin(_elapsed * 1.35 + float(_seat_number) * 0.7) * 1.7
	var hover_lift := -5.0 if _hovered else 0.0
	visual_root.position.y = idle_float + hover_lift
	var actor_visible := _is_public_actor and not _anonymous_action_active and _public_status != STATUS_BANKRUPT
	var target_scale := Vector2.ONE * (1.04 if actor_visible else (1.025 if _hovered else 1.0))
	visual_root.scale = visual_root.scale.lerp(target_scale, clampf(delta * 9.0, 0.0, 1.0))
	if actor_visible:
		var pulse := 0.62 + sin(_elapsed * 3.4) * 0.16
		player_color_strip.color = Color(_player_color, pulse)
	else:
		player_color_strip.color = Color(_player_color, 0.78 if _public_status != STATUS_BANKRUPT else 0.10)


func _connect_hover_signals() -> void:
	if hover_area == null:
		return
	if not hover_area.mouse_entered.is_connected(_on_hover_entered):
		hover_area.mouse_entered.connect(_on_hover_entered)
	if not hover_area.mouse_exited.is_connected(_on_hover_exited):
		hover_area.mouse_exited.connect(_on_hover_exited)


func _on_hover_entered() -> void:
	_hovered = true
	tooltip_text = "%s\n%s" % [_role_name, _public_passive_summary]
	public_seat_hovered.emit(_seat_number, _role_name)
	_apply_visual_state()


func _on_hover_exited() -> void:
	_hovered = false
	public_seat_unhovered.emit(_seat_number)
	_apply_visual_state()


func _apply_visual_state() -> void:
	if not is_node_ready():
		return
	seat_number_label.text = "%02d" % _seat_number
	public_role_label.text = _role_name
	var actor_visible := _is_public_actor and not _anonymous_action_active and _public_status != STATUS_BANKRUPT
	var suppress_anonymous_actor_badge := _anonymous_action_active and _public_status == STATUS_PUBLIC_ACTOR
	var status_text := "公开行动" if actor_visible else ("" if suppress_anonymous_actor_badge else _status_label(_public_status))
	public_status_badge.text = status_text
	public_status_badge.visible = not status_text.is_empty()
	var tint := Color.WHITE
	match _public_status:
		STATUS_WAITING:
			tint = Color(0.76, 0.80, 0.86, 1.0)
		STATUS_BANKRUPT:
			tint = Color(0.34, 0.36, 0.40, 0.88)
		_:
			tint = Color.WHITE
	portrait_texture.modulate = tint
	orbital_seat_pod.modulate = Color(0.82, 0.84, 0.88, 0.86) if _public_status == STATUS_BANKRUPT else Color.WHITE
	_update_outline(actor_visible or _hovered)


func _update_outline(enabled: bool) -> void:
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	outline.corner_radius_top_left = 24
	outline.corner_radius_top_right = 24
	outline.corner_radius_bottom_left = 36
	outline.corner_radius_bottom_right = 36
	outline.border_width_left = 2 if enabled else 1
	outline.border_width_top = 2 if enabled else 1
	outline.border_width_right = 2 if enabled else 1
	outline.border_width_bottom = 2 if enabled else 1
	outline.border_color = Color(_player_color, 0.58 if enabled else 0.08)
	outline.shadow_color = Color(_player_color, 0.22 if enabled else 0.04)
	outline.shadow_size = 12 if enabled else 7
	portrait_shadow.add_theme_stylebox_override("panel", outline)


func _normalize_status(value: String) -> String:
	if value in [STATUS_NORMAL, STATUS_WAITING, STATUS_PUBLIC_ACTOR, STATUS_BANKRUPT]:
		return value
	return STATUS_NORMAL


func _status_label(value: String) -> String:
	match value:
		STATUS_WAITING:
			return "等待"
		STATUS_BANKRUPT:
			return "已破产"
		STATUS_PUBLIC_ACTOR:
			return "公开行动"
		_:
			return ""
