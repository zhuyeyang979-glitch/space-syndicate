extends SceneTree

const DRIVER_SCRIPT := preload("res://scripts/tools/commercial_art_review_capture_driver.gd")
const REVIEW_SCENE_PATH := "res://scenes/tools/CommercialArtIntegrationReview.tscn"
const SETTLE_FRAME_COUNT := 4
const SETTLE_SECONDS := 0.16

var _driver: RefCounted
var _capture_viewport: SubViewport
var _review: Control


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_driver = DRIVER_SCRIPT.new()
	var plan_report := _driver.call("plan_validation_report") as Dictionary
	_print_record("plan", {
		"valid": bool(plan_report.get("valid", false)),
		"capture_count": int(plan_report.get("capture_count", 0)),
		"file_names": plan_report.get("file_names", []),
	})
	if not bool(plan_report.get("valid", false)):
		_finish(1, "BLOCKED_BY_INVALID_SCREENSHOT_PLAN", plan_report)
		return
	var lightweight_preflight := _driver.call("lightweight_capture_preflight") as Dictionary
	_print_record("lightweight_preflight", lightweight_preflight)
	if not bool(lightweight_preflight.get("ready", false)):
		var lightweight_reason := str(
			lightweight_preflight.get("primary_reason_code", "lightweight_capture_preflight_failed")
		)
		_finish(
			2,
			"BLOCKED_BY_CAPTURE_PREFLIGHT_%s" % lightweight_reason.to_upper(),
			lightweight_preflight
		)
		return
	var catalog_preflight := _driver.call("catalog_binding_preflight") as Dictionary
	_print_record("catalog_preflight", catalog_preflight)
	if not bool(catalog_preflight.get("ready", false)):
		var catalog_reason := str(catalog_preflight.get("primary_reason_code", "capture_catalog_preflight_failed"))
		var catalog_status := "BLOCKED_BY_UNRESOLVED_PRESENTATION_ASSET_KEYS" \
			if catalog_reason == "unresolved_presentation_asset_keys" \
			else "BLOCKED_BY_CAPTURE_PREFLIGHT_%s" % catalog_reason.to_upper()
		_finish(2, catalog_status, catalog_preflight)
		return
	if not _create_real_review_scene():
		_finish(1, "BLOCKED_BY_REVIEW_SCENE_LOAD_FAILURE", {})
		return
	await _settle_preflight_scene()
	var preflight := _driver.call("capture_preflight", _review) as Dictionary
	_print_record("preflight", preflight)
	if not bool(preflight.get("ready", false)):
		var primary := str(preflight.get("primary_reason_code", "capture_preflight_failed"))
		var status := "BLOCKED_BY_UNRESOLVED_PRESENTATION_ASSET_KEYS" \
			if primary == "unresolved_presentation_asset_keys" \
			else "BLOCKED_BY_CAPTURE_PREFLIGHT_%s" % primary.to_upper()
		await _cleanup()
		_finish(2, status, preflight)
		return
	var output_root := str(_driver.call("output_root_from_arguments", OS.get_cmdline_user_args()))
	var output_report := _driver.call("prepare_output_root", output_root) as Dictionary
	if not bool(output_report.get("valid", false)):
		await _cleanup()
		_finish(1, "BLOCKED_BY_SCREENSHOT_OUTPUT_ROOT", output_report)
		return
	if not _attach_fixed_capture_viewport():
		await _cleanup()
		_finish(1, "BLOCKED_BY_CAPTURE_VIEWPORT_SETUP", {})
		return
	var captures: Array[Dictionary] = []
	var failure_count := 0
	var plan := _driver.call("capture_plan") as Array
	for spec_variant in plan:
		var spec := spec_variant as Dictionary
		var capture_id := str(spec.get("capture_id", ""))
		var file_name := str(spec.get("file_name", ""))
		var viewport_size := spec.get("viewport_size") as Vector2i
		_set_capture_size(viewport_size)
		await process_frame
		if not bool(_review.call("prepare_capture_state", capture_id)):
			failure_count += 1
			captures.append({"valid": false, "reason_code": "capture_state_prepare_failed", "capture_id": capture_id})
			continue
		await process_frame
		if _review.has_method("finalize_capture_layout"):
			_review.call("finalize_capture_layout", capture_id)
		await _settle_rendering()
		var texture := _capture_viewport.get_texture()
		var image: Image = texture.get_image() if texture != null else null
		var output_path := "%s/%s" % [output_root, file_name]
		var result := _driver.call("save_and_validate_capture", image, output_path, viewport_size) as Dictionary
		result["capture_id"] = capture_id
		captures.append(result)
		if not bool(result.get("valid", false)):
			failure_count += 1
		_print_record("capture", result)
	await _cleanup()
	_finish(
		0 if failure_count == 0 and captures.size() == 15 else 1,
		"GREEN" if failure_count == 0 and captures.size() == 15 else "BLOCKED_BY_SCREENSHOT_VALIDATION",
		{
			"output_root": output_root,
			"capture_count": captures.size(),
			"failure_count": failure_count,
			"captures": captures,
		}
	)


func _create_real_review_scene() -> bool:
	var packed := load(REVIEW_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	_review = packed.instantiate() as Control
	if _review == null or not _review.has_method("debug_snapshot") \
			or not _review.has_method("prepare_capture_state"):
		return false
	root.add_child(_review)
	_review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return true


func _attach_fixed_capture_viewport() -> bool:
	if _review == null or not is_instance_valid(_review):
		return false
	if _review.get_parent() != null:
		_review.get_parent().remove_child(_review)
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "CommercialArtCaptureViewport"
	_capture_viewport.size = Vector2i(1920, 1080)
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_capture_viewport.transparent_bg = false
	_capture_viewport.handle_input_locally = true
	root.add_child(_capture_viewport)
	_capture_viewport.add_child(_review)
	_review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return true


func _set_capture_size(viewport_size: Vector2i) -> void:
	_capture_viewport.size = viewport_size
	_review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_review.position = Vector2.ZERO
	_review.size = Vector2(viewport_size)


func _settle_rendering() -> void:
	for _index in range(SETTLE_FRAME_COUNT):
		await process_frame
	await create_timer(SETTLE_SECONDS).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		RenderingServer.force_draw(false, 0.0)
		await process_frame


func _settle_preflight_scene() -> void:
	await process_frame
	await process_frame
	await create_timer(0.05).timeout


func _cleanup() -> void:
	if _capture_viewport != null and is_instance_valid(_capture_viewport):
		_capture_viewport.queue_free()
	elif _review != null and is_instance_valid(_review):
		_review.queue_free()
	await process_frame
	_review = null
	_capture_viewport = null


func _print_record(event_id: String, payload: Dictionary) -> void:
	print("COMMERCIAL_ART_SCREENSHOT_CAPTURE|event=%s|payload=%s" % [event_id, JSON.stringify(payload)])


func _finish(exit_code: int, status: String, details: Dictionary) -> void:
	print("COMMERCIAL_ART_SCREENSHOT_CAPTURE|status=%s|exit_code=%d|details=%s" % [
		status,
		exit_code,
		JSON.stringify(details),
	])
	quit(exit_code)
