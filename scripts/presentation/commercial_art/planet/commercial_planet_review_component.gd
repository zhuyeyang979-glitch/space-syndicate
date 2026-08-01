@tool
extends SubViewportContainer
class_name CommercialPlanetReviewComponent

const ZOOM_MIN := 0.72
const ZOOM_MAX := 1.85
const ZOOM_STEP := 0.08
const DEFAULT_ZOOM := 1.0
const BASE_CAMERA_DISTANCE := 5.15
const ZOOM_SMOOTHING := 11.0
const DRAG_RADIANS_PER_PIXEL := 0.006
const MARKER_FACING_THRESHOLD := 0.08

@onready var _planet_viewport: SubViewport = %PlanetViewport
@onready var _camera: Camera3D = %PlanetCamera
@onready var _planet_root: Node3D = %PlanetRoot
@onready var _planet_body: MeshInstance3D = %OpaquePlanetBody
@onready var _cloud_shell: MeshInstance3D = %CloudShell
@onready var _front_marker: Node3D = %FrontSurfaceMarker
@onready var _back_marker: Node3D = %BackSurfaceMarker
@onready var _front_facility: Node3D = %FrontFacilityProxy
@onready var _back_facility: Node3D = %BackFacilityProxy

var _target_zoom := DEFAULT_ZOOM
var _current_zoom := DEFAULT_ZOOM
var _yaw := 0.0
var _pitch := -0.08
var _dragging := false
var _last_pointer_position := Vector2.ZERO
var _sun_direction_world := Vector3(0.96, -0.12, -0.18).normalized()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	set_process(true)
	set_process_input(true)
	resized.connect(_sync_viewport_size)
	_sync_viewport_size()
	_apply_camera()
	_update_surface_marker_visibility()
	set_meta("commercial_art_component", "opaque_planet_v1")
	set_meta("presentation_only", true)


func _process(delta: float) -> void:
	var blend := 1.0 - exp(-ZOOM_SMOOTHING * maxf(delta, 0.0))
	_current_zoom = lerpf(_current_zoom, _target_zoom, blend)
	if absf(_current_zoom - _target_zoom) < 0.0001:
		_current_zoom = _target_zoom
	_apply_camera()
	_update_surface_marker_visibility()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by_steps(1)
			accept_event()
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by_steps(-1)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed
			_last_pointer_position = mouse_event.position
			if _dragging:
				grab_focus()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta_pixels := motion.position - _last_pointer_position
		_last_pointer_position = motion.position
		_yaw -= delta_pixels.x * DRAG_RADIANS_PER_PIXEL
		_pitch = clampf(_pitch - delta_pixels.y * DRAG_RADIANS_PER_PIXEL, -1.05, 1.05)
		accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		set_target_zoom(_target_zoom * magnify.factor)
		accept_event()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode in [KEY_EQUAL, KEY_KP_ADD]:
				zoom_by_steps(1)
				accept_event()
			elif key_event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
				zoom_by_steps(-1)
				accept_event()
			elif key_event.keycode in [KEY_HOME, KEY_R]:
				reset_view()
				accept_event()
	elif event is InputEventJoypadButton:
		var joy_event := event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == JOY_BUTTON_DPAD_UP:
			zoom_by_steps(1)
			accept_event()
		elif joy_event.pressed and joy_event.button_index == JOY_BUTTON_DPAD_DOWN:
			zoom_by_steps(-1)
			accept_event()
		elif joy_event.pressed and joy_event.button_index == JOY_BUTTON_RIGHT_STICK:
			reset_view()
			accept_event()


func zoom_by_steps(step_count: int) -> void:
	set_target_zoom(_target_zoom + float(step_count) * ZOOM_STEP)


func set_target_zoom(value: float) -> void:
	_target_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)


func set_zoom_immediate(value: float) -> void:
	_target_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_current_zoom = _target_zoom
	_apply_camera()


func reset_view() -> void:
	_target_zoom = DEFAULT_ZOOM
	_yaw = 0.0
	_pitch = -0.08


func set_sun_direction_world(direction: Vector3) -> void:
	if direction.length_squared() <= 0.0001:
		return
	_sun_direction_world = direction.normalized()
	for mesh_instance: MeshInstance3D in [_planet_body, _cloud_shell]:
		if mesh_instance == null:
			continue
		var material := mesh_instance.get_active_material(0) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("sun_direction_world", _sun_direction_world)


func set_solar_turn_normalized(turn: float) -> void:
	var angle := fposmod(turn, 1.0) * TAU
	set_sun_direction_world(Vector3(sin(angle), -0.18, -cos(angle)))


func debug_snapshot() -> Dictionary:
	var front_visible := 1 if _front_marker != null and _front_marker.visible else 0
	var back_visible := 1 if _back_marker != null and _back_marker.visible else 0
	var front_facility_visible := 1 if _front_facility != null and _front_facility.visible else 0
	var back_facility_visible := 1 if _back_facility != null and _back_facility.visible else 0
	return {
		"component_id": "commercial.planet.review.v1",
		"presentation_only": true,
		"zoom_min": ZOOM_MIN,
		"zoom_max": ZOOM_MAX,
		"zoom_step": ZOOM_STEP,
		"current_zoom": _current_zoom,
		"target_zoom": _target_zoom,
		"planet_alpha": 1.0,
		"planet_opaque": true,
		"back_face_culling": true,
		"depth_test": true,
		"day_brightness": 1.0,
		"night_brightness": 0.50,
		"sun_direction_world": _sun_direction_world,
		"frontside_region_marker_visible_count": front_visible,
		"backside_region_marker_visible_count": back_visible,
		"frontside_facility_visible_count": front_facility_visible,
		"backside_facility_visible_count": back_facility_visible,
		"outer_orbit_decoration_count": 0,
		"camera_state_persisted": false,
	}


func _sync_viewport_size() -> void:
	if _planet_viewport == null:
		return
	if stretch:
		return
	var logical_size := size
	if logical_size.x < 1.0 or logical_size.y < 1.0:
		logical_size = Vector2(960.0, 640.0)
	_planet_viewport.size = Vector2i(maxi(1, int(logical_size.x)), maxi(1, int(logical_size.y)))


func _apply_camera() -> void:
	if _camera == null or _planet_root == null:
		return
	_planet_root.rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, BASE_CAMERA_DISTANCE / maxf(_current_zoom, ZOOM_MIN))
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _update_surface_marker_visibility() -> void:
	if _camera == null:
		return
	for surface_item: Node3D in [_front_marker, _back_marker, _front_facility, _back_facility]:
		if surface_item == null:
			continue
		var radial_normal := surface_item.global_position.normalized()
		var direction_to_camera := (_camera.global_position - surface_item.global_position).normalized()
		surface_item.visible = radial_normal.dot(direction_to_camera) > MARKER_FACING_THRESHOLD
