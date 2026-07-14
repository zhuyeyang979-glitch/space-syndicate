extends Control

const OUTPUT_DIR := "res://reports/ui/skin_lab"
const CAPTURE_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]
const STATE_CAPTURE_SIZE := Vector2i(1600, 960)
const LAB_STATES: Array[StringName] = [
	&"normal",
	&"hovered",
	&"selected",
	&"disabled",
	&"drop_valid",
	&"resolving",
	&"hidden",
]
const SETTLE_SECONDS := 0.48

@onready var _lab: Control = %CardUISkinLab

var _failure_count := 0
var _capture_count := 0


func _ready() -> void:
	call_deferred("_run_capture_suite")


func _run_capture_suite() -> void:
	_log_event("suite_start", "OK", {
		"scene": "res://scenes/tools/CardUISkinLab.tscn",
		"output_dir": OUTPUT_DIR,
	})
	if not _prepare_output_dir():
		_finish_suite()
		return

	for capture_size in CAPTURE_SIZES:
		await _set_capture_size(capture_size)
		await _capture_viewport(
			"resolution_%dx%d" % [capture_size.x, capture_size.y],
			"card_ui_skin_lab_%dx%d.png" % [capture_size.x, capture_size.y],
			capture_size
		)

	await _set_capture_size(STATE_CAPTURE_SIZE)
	if _lab.has_method("set_lab_state"):
		for state_name in LAB_STATES:
			_lab.call("set_lab_state", state_name)
			_log_event("state_applied", "OK", {"state": state_name})
			await _settle_layout()
			await _capture_viewport(
				"state_%s" % state_name,
				"card_ui_skin_lab_state_%s_1600x960.png" % state_name,
				STATE_CAPTURE_SIZE
			)
	else:
		_log_event("state_capture_skipped", "E_STATE_API_MISSING", {
			"method": "set_lab_state",
			"detail": "主场景未公开状态切换方法，仅生成分辨率截图。",
		})

	if _lab.has_method("get_player_text_leak_report"):
		var leak_variant: Variant = _lab.call("get_player_text_leak_report")
		var leak_report: Dictionary = leak_variant if leak_variant is Dictionary else {}
		var leak_count := int(leak_report.get("leak_count", -1))
		if leak_count != 0:
			_failure_count += 1
		_log_event("player_text_scan", "OK" if leak_count == 0 else "E_PLAYER_TEXT_LEAK", {
			"clean": bool(leak_report.get("clean", false)),
			"leaks": leak_count,
		})
	if _lab.has_method("get_lab_snapshot"):
		var snapshot_variant: Variant = _lab.call("get_lab_snapshot")
		var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
		_log_event("runtime_snapshot", "OK", {
			"cards": int(snapshot.get("card_count", 0)),
			"sceneized": bool(snapshot.get("godot_scene_runtime", false)),
			"state": str(snapshot.get("current_state", "")),
		})

	_finish_suite()


func _prepare_output_dir() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK:
		_failure_count += 1
		_log_event("output_dir_failed", "E_OUTPUT_DIR", {
			"path": OUTPUT_DIR,
			"error": error,
		})
		return false
	_log_event("output_dir_ready", "OK", {"path": OUTPUT_DIR})
	return true


func _set_capture_size(capture_size: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = capture_size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(capture_size)
	await _settle_layout()
	var viewport_size := Vector2i(get_viewport().get_visible_rect().size)
	_log_event("window_ready", "OK", {
		"requested": _size_text(capture_size),
		"window": _size_text(get_window().size),
		"viewport": _size_text(viewport_size),
	})


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture_viewport(case_name: String, file_name: String, expected_size: Vector2i) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		_record_capture_failure(case_name, "E_VIEWPORT_TEXTURE", {"file": file_name})
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		_record_capture_failure(case_name, "E_VIEWPORT_IMAGE", {"file": file_name})
		return

	var actual_size := image.get_size()
	if actual_size != expected_size:
		_failure_count += 1
		_log_event("capture_size_mismatch", "E_CAPTURE_SIZE_MISMATCH", {
			"case": case_name,
			"expected": _size_text(expected_size),
			"actual": _size_text(actual_size),
		})

	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_record_capture_failure(case_name, "E_PNG_SAVE", {
			"file": resource_path,
			"error": save_error,
		})
		return

	_capture_count += 1
	_log_event("capture_saved", "OK", {
		"case": case_name,
		"file": resource_path,
		"image": _size_text(actual_size),
	})


func _record_capture_failure(case_name: String, code: String, fields: Dictionary) -> void:
	_failure_count += 1
	var details := fields.duplicate(true)
	details["case"] = case_name
	_log_event("capture_failed", code, details)


func _finish_suite() -> void:
	var code := "OK" if _failure_count == 0 else "E_CAPTURE_SUITE"
	_log_event("suite_complete", code, {
		"captures": _capture_count,
		"failures": _failure_count,
	})
	set_meta("capture_exit_code", 0 if _failure_count == 0 else 1)
	_log_event("awaiting_mcp_stop", code, {"detail": "截图已完成，等待 Godot MCP 停止项目。"})


func _log_event(event_name: String, code: String, fields: Dictionary = {}) -> void:
	var parts: Array[String] = [
		"SKIN_LAB_CAPTURE",
		"event=%s" % _log_value(event_name),
		"code=%s" % _log_value(code),
	]
	var keys: Array = fields.keys()
	keys.sort()
	for key_variant in keys:
		var key := str(key_variant)
		parts.append("%s=%s" % [key, _log_value(fields.get(key_variant))])
	print("|".join(parts))


func _log_value(value: Variant) -> String:
	return str(value).replace("|", "/").replace("\n", " ").replace("\r", " ")


func _size_text(dimensions: Vector2i) -> String:
	return "%dx%d" % [dimensions.x, dimensions.y]
