@tool
extends Control
class_name PlanetSolarCameraController

const STATE_UNAVAILABLE := "UNAVAILABLE"
const STATE_IDLE_WAIT := "IDLE_WAIT"
const STATE_ALIGNING := "ALIGNING"
const STATE_FOLLOWING := "FOLLOWING"
const IDLE_SECONDS := 3.0
const ALIGN_SECONDS := 0.8
const EXPECTED_PERIOD_US := 120_000_000
const TURN_PPM := 1_000_000
const PUBLIC_PRESENTATION_KEYS := ["world_effective_us", "rotation_period_us", "sun_turn_ppm"]
const SNAP_MOTION_MODES := ["reduced", "off"]

@export_enum("full", "reduced", "off") var motion_mode := "full"
@export var auto_advance := true

@onready var return_button: Button = get_node_or_null("ReturnToSunButton") as Button

var _map_view: Control
var _solar_snapshot: Dictionary = {}
var _state := STATE_UNAVAILABLE
var _idle_elapsed := 0.0
var _align_elapsed := 0.0
var _alignment_start_turn_ppm := 0
var _last_interaction_kind := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if return_button != null and not return_button.pressed.is_connected(request_return_to_sun):
		return_button.pressed.connect(request_return_to_sun)
	bind_map_view(get_parent() as Control)
	set_process(auto_advance and not Engine.is_editor_hint())
	_sync_button()


func bind_map_view(map_view: Control) -> void:
	if _map_view != null and is_instance_valid(_map_view) and _map_view.has_signal("camera_presentation_interacted"):
		var previous := Callable(self, "_on_camera_interacted")
		if _map_view.is_connected("camera_presentation_interacted", previous):
			_map_view.disconnect("camera_presentation_interacted", previous)
	_map_view = map_view
	if _map_view != null and _map_view.has_signal("camera_presentation_interacted"):
		var callback := Callable(self, "_on_camera_interacted")
		if not _map_view.is_connected("camera_presentation_interacted", callback):
			_map_view.connect("camera_presentation_interacted", callback)
	_sync_button()


func set_auto_advance_enabled(enabled: bool) -> void:
	auto_advance = enabled
	set_process(auto_advance and not Engine.is_editor_hint())


func set_motion_mode(next_mode: String) -> void:
	motion_mode = next_mode if next_mode in ["full", "reduced", "off"] else "full"


func apply_public_solar_snapshot(snapshot: Dictionary) -> bool:
	if not _valid_public_snapshot(snapshot):
		_solar_snapshot = {}
		_state = STATE_UNAVAILABLE
		_idle_elapsed = 0.0
		_align_elapsed = 0.0
		_sync_button()
		return false
	_solar_snapshot = snapshot.duplicate(true)
	if _state == STATE_UNAVAILABLE:
		_state = STATE_IDLE_WAIT
		_idle_elapsed = 0.0
		_align_elapsed = 0.0
	elif _state == STATE_FOLLOWING:
		_apply_following_camera()
	_sync_button()
	return true


func advance_presentation(delta_seconds: float) -> void:
	if _state == STATE_UNAVAILABLE or not is_finite(delta_seconds) or delta_seconds < 0.0:
		return
	var remaining := delta_seconds
	var guard := 0
	while guard < 4:
		guard += 1
		match _state:
			STATE_IDLE_WAIT:
				var idle_needed := maxf(0.0, IDLE_SECONDS - _idle_elapsed)
				var idle_step := minf(remaining, idle_needed)
				_idle_elapsed += idle_step
				remaining -= idle_step
				if _idle_elapsed >= IDLE_SECONDS:
					_begin_alignment()
				if remaining <= 0.0:
					return
			STATE_ALIGNING:
				var align_needed := maxf(0.0, ALIGN_SECONDS - _align_elapsed)
				var align_step := minf(remaining, align_needed)
				_align_elapsed += align_step
				remaining -= align_step
				_apply_alignment_camera()
				if _align_elapsed >= ALIGN_SECONDS:
					_state = STATE_FOLLOWING
					_apply_following_camera()
				if remaining <= 0.0:
					return
			STATE_FOLLOWING:
				_apply_following_camera()
				return
			_:
				return


func request_return_to_sun() -> void:
	if _solar_snapshot.is_empty() or not _map_ready():
		return
	_map_view.call("apply_solar_presentation_camera_turn", _sun_turn_ppm(), false, false)
	_state = STATE_FOLLOWING
	_idle_elapsed = IDLE_SECONDS
	_align_elapsed = ALIGN_SECONDS
	_sync_button()


func debug_snapshot() -> Dictionary:
	return {
		"component": "PlanetSolarCameraController",
		"state": _state,
		"idle_elapsed": _idle_elapsed,
		"alignment_elapsed": _align_elapsed,
		"idle_seconds": IDLE_SECONDS,
		"alignment_seconds": ALIGN_SECONDS,
		"motion_mode": motion_mode,
		"snapshot_available": not _solar_snapshot.is_empty(),
		"sun_turn_ppm": _sun_turn_ppm() if not _solar_snapshot.is_empty() else -1,
		"last_interaction_kind": _last_interaction_kind,
		"map_bound": _map_ready(),
		"consumes_public_snapshot_only": true,
		"holds_runtime_coordinator": false,
		"holds_market_authority": false,
		"holds_world_bridge": false,
		"owns_save_state": false,
	}


func _process(delta: float) -> void:
	if auto_advance:
		advance_presentation(delta)


func _begin_alignment() -> void:
	_alignment_start_turn_ppm = _camera_turn_ppm()
	_align_elapsed = 0.0
	if SNAP_MOTION_MODES.has(motion_mode):
		_apply_following_camera()
		_state = STATE_FOLLOWING
		_align_elapsed = ALIGN_SECONDS
	else:
		_state = STATE_ALIGNING


func _apply_alignment_camera() -> void:
	if not _map_ready():
		return
	var progress := clampf(_align_elapsed / ALIGN_SECONDS, 0.0, 1.0)
	var smooth := progress * progress * (3.0 - 2.0 * progress)
	var delta_ppm := posmod(_sun_turn_ppm() - _alignment_start_turn_ppm + TURN_PPM / 2, TURN_PPM) - TURN_PPM / 2
	var turn_ppm := posmod(_alignment_start_turn_ppm + int(round(float(delta_ppm) * smooth)), TURN_PPM)
	_map_view.call("apply_solar_presentation_camera_turn", turn_ppm, true, true)


func _apply_following_camera() -> void:
	if _map_ready():
		_map_view.call("apply_solar_presentation_camera_turn", _sun_turn_ppm(), true, true)


func _on_camera_interacted(kind: String) -> void:
	_last_interaction_kind = kind
	if _solar_snapshot.is_empty():
		_state = STATE_UNAVAILABLE
		return
	_state = STATE_IDLE_WAIT
	_idle_elapsed = 0.0
	_align_elapsed = 0.0


func _camera_turn_ppm() -> int:
	if not _map_ready() or not _map_view.has_method("solar_presentation_camera_snapshot"):
		return 0
	var snapshot_variant: Variant = _map_view.call("solar_presentation_camera_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	return posmod(int(snapshot.get("center_turn_ppm", 0)), TURN_PPM)


func _sun_turn_ppm() -> int:
	return posmod(int(_solar_snapshot.get("sun_turn_ppm", 0)), TURN_PPM)


func _map_ready() -> bool:
	return _map_view != null and is_instance_valid(_map_view) and _map_view.has_method("apply_solar_presentation_camera_turn")


func _valid_public_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.size() != PUBLIC_PRESENTATION_KEYS.size():
		return false
	for key in PUBLIC_PRESENTATION_KEYS:
		if not snapshot.has(key):
			return false
	if not (snapshot.get("world_effective_us") is int) or int(snapshot.get("world_effective_us", -1)) < 0:
		return false
	if not (snapshot.get("rotation_period_us") is int) or int(snapshot.get("rotation_period_us", -1)) != EXPECTED_PERIOD_US:
		return false
	if not (snapshot.get("sun_turn_ppm") is int):
		return false
	var sun_turn_ppm := int(snapshot.get("sun_turn_ppm", -1))
	return sun_turn_ppm >= 0 and sun_turn_ppm < TURN_PPM


func _sync_button() -> void:
	if return_button == null:
		return
	return_button.disabled = _solar_snapshot.is_empty() or not _map_ready()
	return_button.tooltip_text = "回到当前受光面，并恢复星球全景缩放"
