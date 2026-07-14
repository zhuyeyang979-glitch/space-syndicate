extends Control

const OUTPUT_DIR := "res://reports/ui/card_visual_polish_v01"
const CAPTURE_SIZE := Vector2i(1600, 960)
const SETTLE_SECONDS := 0.8

@onready var _lab: Control = %CardUISkinLab

var _capture_count := 0
var _failure_count := 0


func _ready() -> void:
	call_deferred("_run_diagnostic")


func _run_diagnostic() -> void:
	_log_event("suite_start", "OK", {"phase": "before_fix", "scene": "res://scenes/tools/CardVisualPolishDiagnosticCapture.tscn"})
	if not _prepare_output_dir():
		_finish()
		return
	await _set_capture_size(CAPTURE_SIZE)
	_lab.call("set_lab_state", "disabled")
	await _settle_layout()
	_log_card_geometry("direct_disabled")
	await _capture("diagnostic_disabled_direct_1600x960.png", "direct_disabled")

	await _run_historical_capture_sequence()
	_log_card_geometry("historical_sequence")
	await _capture("before_disabled_1600x960.png", "historical_sequence")

	_set_dynamic_card_shadow_size(0)
	await _settle_layout()
	_log_card_geometry("shadow_zero")
	await _capture("diagnostic_disabled_shadow_zero_1600x960.png", "shadow_zero")

	_lab.call("set_lab_state", "disabled")
	await _settle_layout()
	var previous_modulates := _set_card_modulate_white()
	await _settle_layout()
	_log_card_geometry("modulate_white")
	await _capture("diagnostic_disabled_modulate_white_1600x960.png", "modulate_white")
	_restore_card_modulates(previous_modulates)
	_finish()


func _run_historical_capture_sequence() -> void:
	for capture_size in [Vector2i(1280, 720), Vector2i(1600, 960), Vector2i(1920, 1080)]:
		_lab.call("set_lab_state", "normal")
		await _set_capture_size(capture_size)
	await _set_capture_size(CAPTURE_SIZE)
	_lab.call("set_lab_state", "hovered")
	await _settle_layout()
	_lab.call("set_lab_state", "disabled")
	await _settle_layout()
	_log_event("historical_sequence", "OK", {"detail": "normal at three sizes, then hovered, then disabled"})


func _set_dynamic_card_shadow_size(value: int) -> void:
	for card in _card_controls():
		var frame := card.get_node_or_null("CardFrame") as PanelContainer
		if frame == null:
			continue
		var current := frame.get_theme_stylebox("panel") as StyleBoxFlat
		if current == null:
			continue
		var probe_style := current.duplicate() as StyleBoxFlat
		probe_style.shadow_size = value
		probe_style.shadow_offset = Vector2.ZERO
		frame.add_theme_stylebox_override("panel", probe_style)
	_log_event("probe_apply", "OK", {"probe": "dynamic_card_shadow", "shadow_size": value})


func _set_card_modulate_white() -> Dictionary:
	var previous := {}
	for card in _card_controls():
		previous[card.get_instance_id()] = card.modulate
		card.modulate = Color.WHITE
	_log_event("probe_apply", "OK", {"probe": "card_modulate", "value": "white"})
	return previous


func _restore_card_modulates(previous: Dictionary) -> void:
	for card in _card_controls():
		var instance_id := card.get_instance_id()
		if previous.has(instance_id):
			card.modulate = previous[instance_id]


func _card_controls() -> Array[Control]:
	var result: Array[Control] = []
	var hand_rack := _lab.find_child("HandRack", true, false) as Control
	if hand_rack != null:
		for child in hand_rack.get_children():
			if child is Control and child.has_method("get_card_data"):
				result.append(child as Control)
	var inspector := _lab.find_child("InspectorCardFace", true, false) as Control
	if inspector != null:
		result.append(inspector)
	return result


func _log_card_geometry(probe: String) -> void:
	for card in _card_controls():
		var data_variant: Variant = card.call("get_card_data") if card.has_method("get_card_data") else {}
		var data: Dictionary = data_variant if data_variant is Dictionary else {}
		var frame := card.get_node_or_null("CardFrame") as PanelContainer
		var style := frame.get_theme_stylebox("panel") as StyleBoxFlat if frame != null else null
		_log_event("card_geometry", "OK", {
			"probe": probe,
			"card": str(data.get("id", data.get("name", card.name))),
			"node": str(card.get_path()),
			"position": _vector_text(card.position),
			"size": _vector_text(card.size),
			"scale": _vector_text(card.scale),
			"rotation": "%.4f" % card.rotation,
			"modulate": card.modulate.to_html(true),
			"clip": card.clip_contents,
			"frame_clip": frame.clip_contents if frame != null else false,
			"shadow_size": style.shadow_size if style != null else -1,
			"shadow_offset": _vector_text(style.shadow_offset) if style != null else "missing",
		})


func _prepare_output_dir() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if error != OK:
		_failure_count += 1
		_log_event("output_dir", "E_OUTPUT_DIR", {"error": error})
		return false
	_log_event("output_dir", "OK", {"path": OUTPUT_DIR})
	return true


func _set_capture_size(capture_size: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = capture_size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(capture_size)
	await _settle_layout()
	_log_event("window_ready", "OK", {"window": _size_text(get_window().size)})


func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw


func _capture(file_name: String, probe: String) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_failure_count += 1
		_log_event("capture", "E_IMAGE", {"probe": probe})
		return
	var resource_path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(resource_path))
	if error != OK:
		_failure_count += 1
		_log_event("capture", "E_SAVE", {"probe": probe, "error": error})
		return
	_capture_count += 1
	_log_event("capture", "OK", {"probe": probe, "file": resource_path, "size": _size_text(image.get_size())})


func _finish() -> void:
	var code := "OK" if _failure_count == 0 else "E_DIAGNOSTIC"
	_log_event("suite_complete", code, {"captures": _capture_count, "failures": _failure_count})
	set_meta("capture_exit_code", 0 if _failure_count == 0 else 1)
	_log_event("awaiting_mcp_stop", code, {"detail": "诊断完成，等待 Godot MCP 停止项目。"})


func _log_event(event_name: String, code: String, fields: Dictionary = {}) -> void:
	var parts: Array[String] = ["CARD_VISUAL_POLISH_DIAGNOSTIC", "event=%s" % _log_value(event_name), "code=%s" % _log_value(code)]
	var keys: Array = fields.keys()
	keys.sort()
	for key_variant in keys:
		parts.append("%s=%s" % [str(key_variant), _log_value(fields.get(key_variant))])
	print("|".join(parts))


func _log_value(value: Variant) -> String:
	return str(value).replace("|", "/").replace("\n", " ").replace("\r", " ")


func _size_text(value: Vector2i) -> String:
	return "%dx%d" % [value.x, value.y]


func _vector_text(value: Vector2) -> String:
	return "%.2fx%.2f" % [value.x, value.y]
