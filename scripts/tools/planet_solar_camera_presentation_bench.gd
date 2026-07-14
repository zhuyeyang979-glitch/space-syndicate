extends Control
class_name PlanetSolarCameraPresentationBench

const SOLAR_SCENE := preload("res://scenes/runtime/SolarAvailabilityRuntimeService.tscn")
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/planet_solar_camera_presentation_v06.png"

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var preview: Control = %PlanetMapMcpPreview
@onready var status_label: Label = %SolarCameraBenchStatus

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_bench")


func run_bench() -> void:
	await get_tree().process_frame
	var applied := preview != null and bool(preview.call("apply_fixture", "selected_district"))
	await get_tree().process_frame
	var map_view := preview.find_child("PlanetMapView", true, false) as Control if preview != null else null
	var controller := map_view.get_node_or_null("PlanetSolarCameraController") if map_view != null else null
	_expect(applied and map_view != null and controller != null, "real PlanetMapView owns the controller")
	if map_view != null and controller != null:
		controller.call("set_auto_advance_enabled", false)
		controller.call("set_motion_mode", "off")
		var solar := SOLAR_SCENE.instantiate()
		add_child(solar)
		solar.call("configure", {})
		var snapshot: Dictionary = solar.call("public_presentation_snapshot", 24_000_000)
		_expect(snapshot.keys().size() == 3 and bool(map_view.call("set_solar_presentation_snapshot", snapshot)), "strict public snapshot injects into the scene")
		controller.call("advance_presentation", 3.0)
		var camera: Dictionary = map_view.call("solar_presentation_camera_snapshot")
		var state: Dictionary = controller.call("debug_snapshot")
		var button := controller.get_node_or_null("ReturnToSunButton") as Button
		_expect(str(state.get("state", "")) == "FOLLOWING" and int(camera.get("center_turn_ppm", -1)) == 200_000, "three-second off-motion path faces the public sun and follows")
		_expect(button != null and button.visible and button.text == "☀" and not button.tooltip_text.is_empty(), "compact scene-owned return control is visible")
		controller.call("set_motion_mode", "full")
		controller.call("set_auto_advance_enabled", true)
		status_label.text = "☀ 日照镜头｜3秒待机 → 平滑对准 → 持续跟随｜显式归位 0.48"
		status_label.tooltip_text = "镜头只消费公开太阳经度；缩放、选区与市场规则保持隔离。"
		solar.queue_free()
	var passed := _failures.is_empty()
	print("PLANET_SOLAR_CAMERA_PRESENTATION_BENCH|status=%s|checks=%d|failures=%d|screenshot=%s" % ["PASS" if passed else "FAIL", _checks, _failures.size(), SCREENSHOT_PATH])
	if not passed:
		push_error("PlanetSolarCameraPresentationBench failed: %s" % JSON.stringify(_failures))
	if auto_quit_after_suite:
		await get_tree().create_timer(0.2).timeout
		get_tree().quit(0 if passed else 1)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
