extends "res://tests/v076_production_victory_audit_readiness_test.gd"

## Headed observer for the natural production FinalSettlement path.
##
## The inherited Victory gate owns the complete production-main run and its
## exact-once oracle.  This adapter only observes the unique Director signals,
## captures start/mid/end frames, and records their immutable receipt identity.
## It emits no fixture receipt, gameplay command, state injection, or Human
## Green claim.

const EVIDENCE_SCHEMA := "V076ProductionNaturalFinalSettlementHeadedEvidenceV1"
const EVIDENCE_CLASS := "PRODUCTION_NATURAL_AUTOMATION_HEADED"
const CUE_ID := "FINAL_SETTLEMENT"
const CAPTURE_SIZE := Vector2i(1600, 960)

var _capture_root := ""
var _manifest_path := ""
var _headed_capture_path := ""
var _ready_path := ""
var _ack_path := ""
var _probe_nonce := ""
var _expected_client_size := "1600x960"
var _evidence_head := ""
var _capture_configured := false
var _ready_published := false
var _capture_jobs_pending := 0
var _capture_failures: Array[String] = []
var _capture_row: Dictionary = {}
var _frame_records: Array[Dictionary] = []
var _settlement_surface_reveal_requested := false


func _run() -> void:
	_configure_capture()
	call_deferred("_publish_ready_when_window_exists")
	await super._run()


func _on_director_cue_queued(cue: Dictionary) -> void:
	super._on_director_cue_queued(cue)
	if str(cue.get("cue_id", "")) != CUE_ID:
		return
	if not _capture_row.is_empty():
		_capture_failures.append("FINAL_SETTLEMENT queued more than once")
		return
	var receipt_id := str(cue.get("receipt_id", "")).strip_edges()
	if receipt_id.is_empty():
		_capture_failures.append("FINAL_SETTLEMENT queued without receipt identity")
		return
	_capture_row = {
		"cue_id": CUE_ID,
		"receipt_id": receipt_id,
		"queued_cue": _json_safe(cue),
		"finished_cue": {},
		"phases": {},
	}
	# The production test enters through the typed Flow boundary while the
	# commercial shell is still open.  At the terminal edge the existing menu
	# lifecycle owner is responsible for revealing the table again; ask that
	# owner to close its presentation surface before any headed frame is saved.
	# This is presentation-only and does not mutate settlement or gameplay
	# authority.
	if not _settlement_surface_reveal_requested:
		_settlement_surface_reveal_requested = true
		call_deferred("_reveal_settlement_surface_for_capture")
	_capture_jobs_pending += 2
	call_deferred("_capture_after_frames", receipt_id, "start", 2)
	var duration_ms := clampi(int(cue.get("duration_ms", 900)), 80, 2400)
	call_deferred(
		"_capture_after_delay",
		receipt_id,
		"mid",
		maxf(0.05, float(duration_ms) / 2000.0)
	)


func _on_director_cue_finished(cue: Dictionary) -> void:
	super._on_director_cue_finished(cue)
	if str(cue.get("cue_id", "")) != CUE_ID or _capture_row.is_empty():
		return
	if str(_capture_row.get("receipt_id", "")) != str(cue.get("receipt_id", "")):
		_capture_failures.append("FINAL_SETTLEMENT finish identity mismatch")
		return
	_capture_row["finished_cue"] = _json_safe(cue)
	_capture_jobs_pending += 1
	call_deferred(
		"_capture_after_frames",
		str(_capture_row.get("receipt_id", "")),
		"end",
		1
	)


func _capture_after_delay(
	receipt_id: String,
	phase: String,
	delay_seconds: float
) -> void:
	await create_timer(delay_seconds).timeout
	await _save_capture_frame(receipt_id, phase)
	_capture_jobs_pending = maxi(0, _capture_jobs_pending - 1)


func _capture_after_frames(
	receipt_id: String,
	phase: String,
	frame_count: int
) -> void:
	for _frame in range(maxi(1, frame_count)):
		await process_frame
	await RenderingServer.frame_post_draw
	await _save_capture_frame(receipt_id, phase)
	_capture_jobs_pending = maxi(0, _capture_jobs_pending - 1)


func _save_capture_frame(receipt_id: String, phase: String) -> void:
	if not _capture_configured:
		_capture_failures.append("capture is not configured for %s" % phase)
		return
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_capture_failures.append("empty headed frame for %s" % phase)
		return
	var path := "%s/%s.png" % [_capture_root, phase]
	var save_error := image.save_png(path)
	if save_error != OK:
		_capture_failures.append("PNG save failed for %s" % phase)
		return
	var frame_record := {
		"cue_id": CUE_ID,
		"receipt_id": receipt_id,
		"phase": phase,
		"path": _project_relative(path),
		"captured_wall_msec": Time.get_ticks_msec(),
		"width": image.get_width(),
		"height": image.get_height(),
		"byte_length": FileAccess.get_file_as_bytes(path).size(),
		"sha256": FileAccess.get_sha256(path),
		"menu_overlay_visible": _menu_overlay_visible(),
		"settlement_overlay_visible": _settlement_overlay_visible(),
	}
	if bool(frame_record.get("menu_overlay_visible", true)):
		_capture_failures.append("commercial menu remained visible for %s" % phase)
	if not bool(frame_record.get("settlement_overlay_visible", false)):
		_capture_failures.append("settlement overlay was not visible for %s" % phase)
	_frame_records.append(frame_record.duplicate(true))
	var phases := (_capture_row.get("phases", {}) as Dictionary).duplicate(true)
	phases[phase] = frame_record.duplicate(true)
	_capture_row["phases"] = phases


func _finish() -> void:
	var capture_deadline := Time.get_ticks_msec() + 12000
	while _capture_jobs_pending > 0 and Time.get_ticks_msec() < capture_deadline:
		await process_frame
	if _capture_jobs_pending > 0:
		_capture_failures.append(
			"%d capture jobs did not settle" % _capture_jobs_pending
		)
	var phases := _capture_row.get("phases", {}) as Dictionary
	for phase in ["start", "mid", "end"]:
		var frame := phases.get(phase, {}) as Dictionary
		if not (
			int(frame.get("width", 0)) == CAPTURE_SIZE.x
			and int(frame.get("height", 0)) == CAPTURE_SIZE.y
			and int(frame.get("byte_length", 0)) > 0
			and str(frame.get("sha256", "")).length() == 64
		):
			_capture_failures.append("%s headed frame is invalid" % phase)
	var receipt_id := str(_capture_row.get("receipt_id", ""))
	var queued_cue := _capture_row.get("queued_cue", {}) as Dictionary
	var finished_cue := _capture_row.get("finished_cue", {}) as Dictionary
	if (
		receipt_id.is_empty()
		or str(queued_cue.get("cue_id", "")) != CUE_ID
		or str(queued_cue.get("receipt_id", "")) != receipt_id
		or str(finished_cue.get("cue_id", "")) != CUE_ID
		or str(finished_cue.get("receipt_id", "")) != receipt_id
	):
		_capture_failures.append("FINAL_SETTLEMENT queued/finished identity is invalid")
	if _final_director_queued.size() != 1 or _final_director_finished.size() != 1:
		_capture_failures.append("inherited unique Director parity is not 1/1")
	var queue_guard := _final_guard_at_queue.get(receipt_id, {}) as Dictionary
	var finish_guard := _final_guard_at_finish.get(receipt_id, {}) as Dictionary
	if queue_guard.is_empty() or finish_guard.is_empty():
		_capture_failures.append("inherited authority guards are missing")
	await _complete_headed_probe()
	var status := "PASS" if (
		_capture_failures.is_empty() and _failures.is_empty()
	) else "FAIL"
	var manifest := {
		"schema": EVIDENCE_SCHEMA,
		"status": status,
		"evidence_class": EVIDENCE_CLASS,
		"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		"evidence_head": _evidence_head,
		"test_script": (
			"res://tests/v076_production_natural_final_settlement_headed_capture.gd"
		),
		"inherited_natural_driver": (
			"res://tests/v076_production_victory_audit_readiness_test.gd"
		),
		"production_main_scene": "res://scenes/main.tscn",
		"headed": DisplayServer.get_name() != "headless",
		"capture_size": {"width": root.size.x, "height": root.size.y},
		"natural_gameplay_automation": true,
		"fixture_receipt_count": 0,
		"presentation_fixture": false,
		"human_executed": false,
		"human_confirmed": false,
		"human_green": false,
		"production_green": false,
		"commercial_m1_green": false,
		"step13_status": "PENDING",
		"step14_status": "PENDING",
		"step15_status": "PENDING",
		"target_cue_ids": [CUE_ID],
		"cue_records": [{
			"cue_id": CUE_ID,
			"receipt_id": receipt_id,
			"receipt_kind": "final_settlement_receipt",
			"production_schema": "V076FinalSettlementPresentationEnvelopeV1",
			"production_consumer": "AUTHORIZED_SETTLEMENT_PROJECTION",
			"production_aggregate_parity": (
				_final_director_queued.size() == 1
				and _final_director_finished.size() == 1
			),
			"fixture_counter_zero": true,
			"lineage_green": not receipt_id.is_empty(),
			"capture_identity_green": (
				str(queued_cue.get("receipt_id", "")) == receipt_id
				and str(finished_cue.get("receipt_id", "")) == receipt_id
			),
			"frames_green": _capture_failures.is_empty(),
			"queued_cue": queued_cue,
			"finished_cue": finished_cue,
			"frames": _json_safe(phases),
			"authority_guard_at_queue": _json_safe(queue_guard),
			"authority_guard_at_finish": _json_safe(finish_guard),
		}],
		"frame_count": _frame_records.size(),
		"frames": _json_safe(_frame_records),
		"inherited_check_count": _checks,
		"inherited_failures": _failures.duplicate(),
		"capture_failures": _capture_failures.duplicate(),
		"headed_client_capture_path": _project_relative(_headed_capture_path),
	}
	if not _write_json(_manifest_path, manifest):
		_capture_failures.append("manifest write failed")
		status = "FAIL"
	if not _capture_failures.is_empty():
		_failures.append_array(_capture_failures)
	print((
		"V076_PRODUCTION_NATURAL_FINAL_SETTLEMENT_HEADED_CAPTURE"
		+ "|status=%s|evidence_class=%s|natural_gameplay_automation=true"
		+ "|fixture_receipt_count=0|human_green=false|step13_15=pending"
		+ "|cue_count=1|frame_count=%d|capture_failures=%s|manifest=%s"
	) % [
		status,
		EVIDENCE_CLASS,
		_frame_records.size(),
		JSON.stringify(_capture_failures),
		_manifest_path,
	])
	await super._finish()


func _configure_capture() -> void:
	_capture_root = _absolute_path(_argument_value("--evidence-root", ""))
	_manifest_path = "%s/manifest.json" % _capture_root
	_headed_capture_path = _absolute_path(_argument_value(
		"--headed-capture-output", "%s/headed_client.png" % _capture_root
	))
	_ready_path = _absolute_path(_argument_value("--window-probe-ready", ""))
	_ack_path = _absolute_path(_argument_value("--window-probe-ack", ""))
	_probe_nonce = _argument_value("--probe-nonce", "")
	_expected_client_size = _argument_value(
		"--expected-client-size", "1600x960"
	)
	_evidence_head = _argument_value("--evidence-head", "")
	if _capture_root.is_empty():
		_capture_failures.append("--evidence-root is required")
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(_capture_root)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_capture_failures.append("cannot create evidence root")
		return
	_capture_configured = true


func _reveal_settlement_surface_for_capture() -> void:
	var controller := root.get_node_or_null(
		"Main/CommercialMenuLifecycleApplicationFlowController"
	)
	if controller == null or not controller.has_method("close_to_table"):
		_capture_failures.append("production menu lifecycle owner is unavailable")
		return
	var close_result: Variant = controller.call("close_to_table")
	# The production lifecycle owner currently returns bool.  Accept only a
	# successful bool (or an explicitly successful typed dictionary wrapper) so
	# a mismatched return type cannot be mistaken for a valid table reveal.
	var close_succeeded := false
	if typeof(close_result) == TYPE_BOOL:
		close_succeeded = bool(close_result)
	elif close_result is Dictionary:
		var result := close_result as Dictionary
		if result.has("accepted"):
			close_succeeded = bool(result.get("accepted", false))
		elif result.has("ok"):
			close_succeeded = bool(result.get("ok", false))
	if not close_succeeded:
		_capture_failures.append("production menu lifecycle did not close the shell")
	if _menu_overlay_visible():
		_capture_failures.append("production commercial menu remained visible after close")


func _menu_overlay_visible() -> bool:
	var overlay := root.get_node_or_null(
		"Main/V075GameScreen/OverlayLayer/CommercialShellSurfaceLayer/MenuModalOverlay"
	) as Control
	return overlay != null and overlay.visible


func _settlement_overlay_visible() -> bool:
	var overlay := root.get_node_or_null(
		"Main/V075GameScreen/OverlayLayer/SettlementOverlay"
	) as Control
	return overlay != null and overlay.visible


func _publish_ready_when_window_exists() -> void:
	for _frame in range(5):
		await process_frame
	if DisplayServer.get_name() == "headless":
		_capture_failures.append("headed display server is required")
		return
	if _ready_path.is_empty() or _ack_path.is_empty():
		_capture_failures.append("headed window handshake paths are required")
		return
	var ready_payload := {
		"schema": "space_syndicate.v076.production_natural_final_ready.v1",
		"status": "PASS",
		"process_id": OS.get_process_id(),
		"expected_client_size": _expected_client_size,
		"probe_nonce": _probe_nonce,
		"capture_path": _headed_capture_path,
		"native_hwnd_decimal": int(DisplayServer.window_get_native_handle(
			DisplayServer.WINDOW_HANDLE
		)),
		"evidence_class": EVIDENCE_CLASS,
		"natural_gameplay_automation": true,
		"fixture_receipt_count": 0,
		"human_green": false,
	}
	_ready_published = _write_json(_ready_path, ready_payload)
	if not _ready_published:
		_capture_failures.append("headed ready payload write failed")


func _complete_headed_probe() -> void:
	if not _ready_published:
		_capture_failures.append("headed ready payload was not published")
		return
	var deadline := Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(_ack_path) and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	if not FileAccess.file_exists(_ack_path):
		_capture_failures.append("headed probe acknowledgement is missing")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_ack_path))
	if not (parsed is Dictionary):
		_capture_failures.append("headed probe acknowledgement is invalid")
		return
	var ack := parsed as Dictionary
	if (
		str(ack.get("status", "")) != "PASS"
		or int(ack.get("process_id", 0)) != OS.get_process_id()
		or int(ack.get("client_width", 0)) != CAPTURE_SIZE.x
		or int(ack.get("client_height", 0)) != CAPTURE_SIZE.y
		or str(ack.get("probe_nonce", "")) != _probe_nonce
	):
		_capture_failures.append("headed probe acknowledgement does not match")


func _argument_value(prefix: String, fallback: String) -> String:
	# The bounded runner appends probe arguments to the full Godot command line;
	# get_cmdline_user_args() omits them on this Godot build.
	for argument_variant in OS.get_cmdline_args():
		var argument := str(argument_variant)
		if argument.begins_with("%s=" % prefix):
			return argument.substr(prefix.length() + 1)
	return fallback


func _absolute_path(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path.replace("\\", "/")


func _project_relative(path: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/")
	var normalized := path.replace("\\", "/")
	if normalized.begins_with(project_root):
		return normalized.substr(project_root.length()).trim_prefix("/")
	return normalized


func _write_json(path: String, value: Variant) -> bool:
	if path.is_empty():
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var temporary_path := "%s.tmp-%d" % [path, OS.get_process_id()]
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_json_safe(value), "  "))
	file.store_string("\n")
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temporary_path, path) == OK


func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key_variant in (value as Dictionary).keys():
				result[str(key_variant)] = _json_safe(
					(value as Dictionary).get(key_variant)
				)
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in value as Array:
				result.append(_json_safe(item))
			return result
		TYPE_RECT2:
			var rect := value as Rect2
			return {
				"x": rect.position.x,
				"y": rect.position.y,
				"width": rect.size.x,
				"height": rect.size.y,
			}
		TYPE_VECTOR2:
			var point := value as Vector2
			return {"x": point.x, "y": point.y}
		TYPE_VECTOR2I:
			var point := value as Vector2i
			return {"x": point.x, "y": point.y}
		TYPE_COLOR:
			var color := value as Color
			return {"r": color.r, "g": color.g, "b": color.b, "a": color.a}
		_:
			return value
