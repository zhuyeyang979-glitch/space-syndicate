extends Control

const OUTPUT_DIR := "res://reports/art/card_style_keys"
const CAPTURE_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]
const TARGET_CARD_ID := "commodity.ring_crystal_battery.rank_1"
const SETTLE_SECONDS := 0.48

@onready var _lab: Control = get_node("CardUISkinLab") as Control

var _failure_count := 0
var _capture_count := 0


func _ready() -> void:
	call_deferred("_run_capture_suite")


func _run_capture_suite() -> void:
	_log_event("suite_start", "OK", {
		"scene": "res://scenes/tools/CardArtStyleKeyCapture.tscn",
		"card": TARGET_CARD_ID,
		"output_dir": OUTPUT_DIR,
	})
	if not _prepare_output_dir():
		_finish_suite()
		return

	if _lab.has_method("set_lab_state"):
		_lab.call("set_lab_state", "normal")
	await _settle_layout()
	_prepare_three_context_review()
	await _settle_layout()
	_validate_three_context_review()

	for capture_size in CAPTURE_SIZES:
		await _set_capture_size(capture_size)
		await _capture_viewport(
			"style_key_%dx%d" % [capture_size.x, capture_size.y],
			"ring_crystal_battery_style_key_%dx%d.png" % [capture_size.x, capture_size.y],
			capture_size
		)

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

	_finish_suite()


func _prepare_three_context_review() -> void:
	var inspector_card := _lab.find_child("InspectorCardFace", true, false) as Control
	var settlement_stage := _lab.find_child("CardSettlementStage", true, false) as Control
	if inspector_card == null or settlement_stage == null:
		_failure_count += 1
		_log_event("context_prepare", "E_CONTEXT_NODE_MISSING")
		return
	var review_variant: Variant = inspector_card.call("get_card_data") if inspector_card.has_method("get_card_data") else {}
	var review_card: Dictionary = review_variant if review_variant is Dictionary else {}
	if str(review_card.get("id", "")) != TARGET_CARD_ID:
		_failure_count += 1
		_log_event("context_prepare", "E_TARGET_CARD_MISMATCH", {"actual": str(review_card.get("id", ""))})
		return
	settlement_stage.call("set_card_view_model", review_card)
	_log_event("context_prepare", "OK", {"contexts": "hand/settlement/inspector"})


func _validate_three_context_review() -> void:
	var context_cards := {
		"hand": _find_hand_target_card(),
		"settlement": _lab.find_child("SettlementCardFace", true, false) as Control,
		"inspector": _lab.find_child("InspectorCardFace", true, false) as Control,
	}
	for context_variant in context_cards.keys():
		var context_name := str(context_variant)
		var card := context_cards[context_variant] as Control
		var active := card != null and bool(card.get_meta("authored_illustration_active", false))
		if not active:
			_failure_count += 1
		var card_size := Vector2i(card.size) if card != null else Vector2i.ZERO
		_log_event("context_art", "OK" if active else "E_AUTHORED_ART_INACTIVE", {
			"context": context_name,
			"active": active,
			"size": _size_text(card_size),
		})


func _find_hand_target_card() -> Control:
	var hand_rack := _lab.find_child("HandRack", true, false) as Control
	if hand_rack == null:
		return null
	for child in hand_rack.get_children():
		if not (child is Control) or not child.has_method("get_card_data"):
			continue
		var card_variant: Variant = child.call("get_card_data")
		var card_data: Dictionary = card_variant if card_variant is Dictionary else {}
		if str(card_data.get("id", "")) == TARGET_CARD_ID:
			return child as Control
	return null


func _prepare_output_dir() -> bool:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if error != OK:
		_failure_count += 1
		_log_event("output_dir_failed", "E_OUTPUT_DIR", {"path": OUTPUT_DIR, "error": error})
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
	var save_error := image.save_png(ProjectSettings.globalize_path(resource_path))
	if save_error != OK:
		_record_capture_failure(case_name, "E_PNG_SAVE", {"file": resource_path, "error": save_error})
		return
	_capture_count += 1
	_log_event("capture_saved", "OK", {"case": case_name, "file": resource_path, "image": _size_text(actual_size)})


func _record_capture_failure(case_name: String, code: String, fields: Dictionary) -> void:
	_failure_count += 1
	var details := fields.duplicate(true)
	details["case"] = case_name
	_log_event("capture_failed", code, details)


func _finish_suite() -> void:
	var code := "OK" if _failure_count == 0 else "E_CAPTURE_SUITE"
	_log_event("suite_complete", code, {"captures": _capture_count, "failures": _failure_count})
	set_meta("capture_exit_code", 0 if _failure_count == 0 else 1)
	_log_event("awaiting_mcp_stop", code, {"detail": "风格钥匙截图已完成，等待 Godot MCP 停止项目。"})


func _log_event(event_name: String, code: String, fields: Dictionary = {}) -> void:
	var parts: Array[String] = [
		"CARD_ART_STYLE_KEY_CAPTURE",
		"event=%s" % _log_value(event_name),
		"code=%s" % _log_value(code),
	]
	var keys: Array = fields.keys()
	keys.sort()
	for key_variant in keys:
		parts.append("%s=%s" % [str(key_variant), _log_value(fields.get(key_variant))])
	print("|".join(parts))


func _log_value(value: Variant) -> String:
	return str(value).replace("|", "/").replace("\n", " ").replace("\r", " ")


func _size_text(dimensions: Vector2i) -> String:
	return "%dx%d" % [dimensions.x, dimensions.y]
