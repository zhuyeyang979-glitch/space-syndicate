extends "res://tests/v076_alpha07_card_table_flow_readiness_test.gd"

## Headed evidence adapter for the existing production-main Card-table sentinel.
##
## This script inherits the complete natural gameplay driver instead of copying
## or replacing its oracle.  It only observes the unique production Animation
## Director signals and saves one start/mid/end frame set for the three
## non-terminal card-table cue contracts reached by that driver.  The terminal
## FINAL_SETTLEMENT contract is captured by the independent natural Victory
## driver; the wrapper joins both headed receipts without pretending they came
## from one run.  This adapter never emits a fixture receipt or gameplay command.

const EVIDENCE_SCHEMA := "V076ProductionNaturalCardTableHeadedEvidenceV1"
const EVIDENCE_CLASS := "PRODUCTION_NATURAL_AUTOMATION_HEADED"
const TARGET_CUE_IDS := [
	"CARD_SELECT",
	"CARD_PLAY_PUBLIC",
	"CARD_RESOLUTION_FOCUS",
]
const EXPECTED_RECEIPT_KIND := {
	"CARD_SELECT": "card_selection_receipt",
	"CARD_PLAY_PUBLIC": "public_card_play_receipt",
	"CARD_RESOLUTION_FOCUS": "public_resolution_receipt",
}
const EXPECTED_SCHEMA := {
	"CARD_SELECT": "V076AuthorizedPresentationInputEnvelopeV1",
	"CARD_PLAY_PUBLIC": "V076PublicCardPlayPresentationEnvelopeV1",
	"CARD_RESOLUTION_FOCUS": "V076PublicCardResolutionPresentationEnvelopeV1",
}
const EXPECTED_CONSUMER := {
	"CARD_SELECT": "AUTHORIZED_PRESENTATION_INPUT",
	"CARD_PLAY_PUBLIC": "AUTHORIZED_PUBLIC_PROJECTION",
	"CARD_RESOLUTION_FOCUS": "AUTHORIZED_PUBLIC_PROJECTION",
}
const FIXTURE_CONSUMER := "PRESENTATION_FIXTURE"
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
var _capture_by_cue: Dictionary = {}
var _frame_records: Array[Dictionary] = []


func _run() -> void:
	_configure_capture()
	call_deferred("_publish_ready_when_window_exists")
	await super._run()


func _on_director_cue_queued(cue: Dictionary) -> void:
	super._on_director_cue_queued(cue)
	var cue_id := str(cue.get("cue_id", ""))
	if cue_id not in TARGET_CUE_IDS or _capture_by_cue.has(cue_id):
		return
	var receipt_id := str(cue.get("receipt_id", "")).strip_edges()
	if receipt_id.is_empty():
		_capture_failures.append("%s queued without receipt identity" % cue_id)
		return
	_capture_by_cue[cue_id] = {
		"cue_id": cue_id,
		"receipt_id": receipt_id,
		"queued_cue": _json_safe(cue),
		"finished_cue": {},
		"phases": {},
	}
	_capture_jobs_pending += 2
	call_deferred("_capture_after_frames", cue_id, receipt_id, "start", 1)
	var duration_ms := clampi(int(cue.get("duration_ms", 240)), 80, 1600)
	call_deferred(
		"_capture_after_delay",
		cue_id,
		receipt_id,
		"mid",
		maxf(0.05, float(duration_ms) / 2000.0)
	)


func _on_director_cue_finished(cue: Dictionary) -> void:
	super._on_director_cue_finished(cue)
	var cue_id := str(cue.get("cue_id", ""))
	if cue_id not in TARGET_CUE_IDS or not _capture_by_cue.has(cue_id):
		return
	var row := (_capture_by_cue.get(cue_id, {}) as Dictionary).duplicate(true)
	if str(row.get("receipt_id", "")) != str(cue.get("receipt_id", "")):
		return
	row["finished_cue"] = _json_safe(cue)
	_capture_by_cue[cue_id] = row
	_capture_jobs_pending += 1
	call_deferred(
		"_capture_after_frames",
		cue_id,
		str(row.get("receipt_id", "")),
		"end",
		1
	)


func _capture_after_delay(
	cue_id: String,
	receipt_id: String,
	phase: String,
	delay_seconds: float
) -> void:
	await create_timer(delay_seconds).timeout
	await _save_capture_frame(cue_id, receipt_id, phase)
	_capture_jobs_pending = maxi(0, _capture_jobs_pending - 1)


func _capture_after_frames(
	cue_id: String,
	receipt_id: String,
	phase: String,
	frame_count: int
) -> void:
	for _frame in range(maxi(1, frame_count)):
		await process_frame
	await RenderingServer.frame_post_draw
	await _save_capture_frame(cue_id, receipt_id, phase)
	_capture_jobs_pending = maxi(0, _capture_jobs_pending - 1)


func _save_capture_frame(
	cue_id: String,
	receipt_id: String,
	phase: String
) -> void:
	if not _capture_configured:
		_capture_failures.append("capture is not configured for %s/%s" % [
			cue_id,
			phase,
		])
		return
	var cue_directory := "%s/%s" % [
		_capture_root,
		cue_id.to_lower(),
	]
	var directory_error := DirAccess.make_dir_recursive_absolute(cue_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_capture_failures.append("cannot create %s" % cue_directory)
		return
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_capture_failures.append("empty headed frame for %s/%s" % [
			cue_id,
			phase,
		])
		return
	var path := "%s/%s.png" % [cue_directory, phase]
	var save_error := image.save_png(path)
	if save_error != OK:
		_capture_failures.append("PNG save failed for %s/%s" % [
			cue_id,
			phase,
		])
		return
	var frame_record := {
		"cue_id": cue_id,
		"receipt_id": receipt_id,
		"phase": phase,
		"path": _project_relative(path),
		"captured_wall_msec": Time.get_ticks_msec(),
		"width": image.get_width(),
		"height": image.get_height(),
		"byte_length": FileAccess.get_file_as_bytes(path).size(),
		"sha256": FileAccess.get_sha256(path),
	}
	_frame_records.append(frame_record.duplicate(true))
	var row := (_capture_by_cue.get(cue_id, {}) as Dictionary).duplicate(true)
	var phases := (row.get("phases", {}) as Dictionary).duplicate(true)
	phases[phase] = frame_record.duplicate(true)
	row["phases"] = phases
	_capture_by_cue[cue_id] = row


func _finish() -> void:
	var capture_deadline := Time.get_ticks_msec() + 12000
	while _capture_jobs_pending > 0 and Time.get_ticks_msec() < capture_deadline:
		await process_frame
	if _capture_jobs_pending > 0:
		_capture_failures.append(
			"%d capture jobs did not settle" % _capture_jobs_pending
		)
	var bridge := _card_table_debug()
	var cue_counts := bridge.get("cue_counts", {}) as Dictionary
	var cue_evidence := bridge.get("cue_evidence", {}) as Dictionary
	var cue_records: Array[Dictionary] = []
	for cue_id_variant in TARGET_CUE_IDS:
		var cue_id := str(cue_id_variant)
		var count_row := cue_counts.get(cue_id, {}) as Dictionary
		var evidence_row := cue_evidence.get(cue_id, {}) as Dictionary
		var capture_row := _capture_by_cue.get(cue_id, {}) as Dictionary
		var phases := capture_row.get("phases", {}) as Dictionary
		var source_count := int(count_row.get("production_source_count", -1))
		var aggregate_parity := (
			source_count > 0
			and source_count == int(count_row.get(
				"production_queued_count", -2
			))
			and source_count == int(count_row.get(
				"production_surface_started_count", -2
			))
			and source_count == int(count_row.get(
				"production_surface_finished_count", -2
			))
			and source_count == int(count_row.get(
				"production_finished_count", -2
			))
		)
		var fixture_zero := true
		for fixture_field in [
			"fixture_source_count",
			"fixture_queued_count",
			"fixture_surface_started_count",
			"fixture_surface_finished_count",
			"fixture_finished_count",
		]:
			fixture_zero = (
				fixture_zero and int(count_row.get(fixture_field, -1)) == 0
			)
		var envelope := evidence_row.get("envelope", {}) as Dictionary
		var lineage_green := (
			str(evidence_row.get("consumer_class", ""))
				== str(EXPECTED_CONSUMER.get(cue_id, ""))
			and str(envelope.get("schema", ""))
				== str(EXPECTED_SCHEMA.get(cue_id, ""))
			and str(envelope.get("receipt_kind", ""))
				== str(EXPECTED_RECEIPT_KIND.get(cue_id, ""))
			and str(envelope.get("cue_id", "")) == cue_id
			and str(envelope.get("fixture_class", "")) != FIXTURE_CONSUMER
			and not bool(envelope.get("fixture_sealed", false))
		)
		var frames_green := true
		var frame_hashes := {}
		for phase in ["start", "mid", "end"]:
			var frame := phases.get(phase, {}) as Dictionary
			var frame_sha256 := str(frame.get("sha256", ""))
			if frame_sha256.length() == 64:
				frame_hashes[frame_sha256] = true
			frames_green = (
				frames_green
				and int(frame.get("width", 0)) == CAPTURE_SIZE.x
				and int(frame.get("height", 0)) == CAPTURE_SIZE.y
				and int(frame.get("byte_length", 0)) > 0
				and frame_sha256.length() == 64
			)
		frames_green = frames_green and frame_hashes.size() >= 2
		var receipt_id := str(capture_row.get("receipt_id", ""))
		var evidence_receipt_id := str(evidence_row.get("receipt_id", ""))
		var capture_identity_green := (
			not receipt_id.is_empty()
			and str((capture_row.get("queued_cue", {}) as Dictionary).get(
				"cue_id", ""
			)) == cue_id
			and not (capture_row.get("finished_cue", {}) as Dictionary).is_empty()
			and (
				evidence_receipt_id == receipt_id
				or source_count > 1
			)
		)
		if not aggregate_parity:
			_capture_failures.append("%s production aggregate parity failed" % cue_id)
		if not fixture_zero:
			_capture_failures.append("%s fixture counters are not zero" % cue_id)
		if not lineage_green:
			_capture_failures.append("%s production lineage failed" % cue_id)
		if not frames_green:
			_capture_failures.append("%s start/mid/end frame set is incomplete" % cue_id)
		if not capture_identity_green:
			_capture_failures.append("%s capture receipt identity failed" % cue_id)
		cue_records.append({
			"cue_id": cue_id,
			"receipt_id": receipt_id,
			"receipt_kind": EXPECTED_RECEIPT_KIND.get(cue_id, ""),
			"production_schema": EXPECTED_SCHEMA.get(cue_id, ""),
			"production_consumer": EXPECTED_CONSUMER.get(cue_id, ""),
			"production_aggregate_parity": aggregate_parity,
			"fixture_counter_zero": fixture_zero,
			"lineage_green": lineage_green,
			"capture_identity_green": capture_identity_green,
			"frames_green": frames_green,
			"counts": _json_safe(count_row),
			"bridge_evidence": _json_safe(evidence_row),
			"queued_cue": capture_row.get("queued_cue", {}),
			"finished_cue": capture_row.get("finished_cue", {}),
			"frames": _json_safe(phases),
		})
	var zero_mutation := (
		int(bridge.get("animation_gameplay_mutation_count", -1)) == 0
		and int(bridge.get("animation_rng_draw_delta", -1)) == 0
		and int(bridge.get("animation_authority_sequence_delta", -1)) == 0
		and int(bridge.get("animation_card_zone_mutation_count", -1)) == 0
	)
	if not zero_mutation:
		_capture_failures.append("presentation mutation counters are not zero")
	if not bool(bridge.get("exact_once", false)):
		_capture_failures.append("production Card-table bridge is not exact-once")
	if not _failures.is_empty():
		_capture_failures.append("inherited production-main sentinel failed")
	await _complete_headed_probe()
	var status := "PASS" if _capture_failures.is_empty() else "FAIL"
	var manifest := {
		"schema": EVIDENCE_SCHEMA,
		"status": status,
		"evidence_class": EVIDENCE_CLASS,
		"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		"evidence_head": _evidence_head,
		"test_script": (
			"res://tests/v076_production_natural_card_table_headed_capture.gd"
		),
		"inherited_natural_driver": (
			"res://tests/v076_alpha07_card_table_flow_readiness_test.gd"
		),
		"production_main_scene": "res://scenes/main.tscn",
		"headed": DisplayServer.get_name() != "headless",
		"capture_size": {
			"width": root.size.x,
			"height": root.size.y,
		},
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
		"target_cue_ids": TARGET_CUE_IDS.duplicate(),
		"driver_scope": "CARD_TABLE_NON_TERMINAL_CUES",
		"final_settlement_driver_required": true,
		"final_settlement_driver": (
			"res://tests/v076_production_natural_final_settlement_headed_capture.gd"
		),
		"cue_records": cue_records,
		"frame_count": _frame_records.size(),
		"frames": _json_safe(_frame_records),
		"bridge_exact_once": bool(bridge.get("exact_once", false)),
		"zero_mutation": zero_mutation,
		"bridge_snapshot": _json_safe(bridge),
		"headed_client_capture_path": _project_relative(
			_headed_capture_path
		),
		"showcase_fixture_boundary": {
			"separate_fixture_manifest": (
				"reports/presentation/commercial_m1/"
				+ "showcase_capture_manifest.json"
			),
			"fixture_class": "PRESENTATION_FIXTURE",
			"may_support_production_natural_claim": false,
		},
		"inherited_check_count": _checks,
		"inherited_failures": _failures.duplicate(),
		"capture_failures": _capture_failures.duplicate(),
	}
	if not _write_json(_manifest_path, manifest):
		_capture_failures.append("manifest write failed")
		status = "FAIL"
	print((
		"V076_PRODUCTION_NATURAL_CARD_TABLE_HEADED_CAPTURE"
		+ "|status=%s|evidence_class=%s|natural_gameplay_automation=true"
		+ "|fixture_receipt_count=0|human_green=false|step13_15=pending"
		+ "|cue_count=%d|frame_count=%d|capture_failures=%s|manifest=%s"
	) % [
		status,
		EVIDENCE_CLASS,
		cue_records.size(),
		_frame_records.size(),
		JSON.stringify(_capture_failures),
		_manifest_path,
	])
	await super._finish()


func _configure_capture() -> void:
	_capture_root = _absolute_path(_argument_value("--evidence-root", ""))
	_manifest_path = "%s/manifest.json" % _capture_root
	_headed_capture_path = _absolute_path(_argument_value(
		"--headed-capture-output",
		"%s/headed_client.png" % _capture_root
	))
	_ready_path = _absolute_path(_argument_value("--window-probe-ready", ""))
	_ack_path = _absolute_path(_argument_value("--window-probe-ack", ""))
	_probe_nonce = _argument_value("--probe-nonce", "")
	_expected_client_size = _argument_value(
		"--expected-client-size",
		"1600x960"
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


func _publish_ready_when_window_exists() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while (
		(_screen == null or not is_instance_valid(_screen))
		and Time.get_ticks_msec() < deadline
	):
		await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		_capture_failures.append("headed display server is required")
		return
	if _ready_path.is_empty() or _ack_path.is_empty():
		_capture_failures.append("headed window handshake paths are required")
		return
	var native_hwnd := int(DisplayServer.window_get_native_handle(
		DisplayServer.WINDOW_HANDLE
	))
	var ready_payload := {
		"schema": "space_syndicate.v076.production_natural_card_table_ready.v1",
		"status": "PASS",
		"process_id": OS.get_process_id(),
		"expected_client_size": _expected_client_size,
		"probe_nonce": _probe_nonce,
		"capture_path": _headed_capture_path,
		"native_hwnd_decimal": native_hwnd,
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
	var directory_error := DirAccess.make_dir_recursive_absolute(
		path.get_base_dir()
	)
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
			return {
				"r": color.r,
				"g": color.g,
				"b": color.b,
				"a": color.a,
			}
		_:
			return value
