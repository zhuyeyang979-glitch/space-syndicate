extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AUTHORIZATION_CONTRACT := preload("res://scripts/tools/cold_restore_authorization_contract_v1.gd")

const SCHEMA_VERSION := 1
const TIMELINE_ID := "ProcessAPhaseTimelineV1"
const ROLE := "producer"
const PHASE_IDS := [
	"child_bootstrap",
	"scene_loaded",
	"session_started",
	"real_commodity_claim_complete",
	"real_normal_card_purchase_complete",
	"real_facility_economy_complete",
	"first_sale_receipt_complete",
	"ai_nondefault_state_complete",
	"queue_entry_committed",
	"restore_barrier_entered",
	"save_intent_submitted",
	"save_capture_complete",
	"envelope_encode_complete",
	"atomic_write_complete",
	"save_readback_complete",
	"allowlisted_manifest_complete",
	"child_completion_attestation_complete",
	"runtime_cleanup_complete",
	"quit_requested",
]
const FIELDS := [
	"schema_version",
	"timeline_id",
	"run_id",
	"role",
	"repository_head",
	"scenario_fingerprint",
	"official",
	"process_start_monotonic_ms",
	"snapshot_sequence",
	"phase_rows",
	"current_phase",
	"last_completed_phase",
	"last_progress_monotonic_ms",
	"save_file_exists",
	"save_file_bytes",
	"save_file_sha256",
	"child_completion_written",
	"allowlisted_manifest_written",
	"quit_requested",
	"timeline_fingerprint",
]
const PHASE_ROW_FIELDS := [
	"phase_id",
	"entered_monotonic_ms",
	"completed_monotonic_ms",
	"duration_ms",
	"success",
	"reason_code",
	"evidence_fingerprint",
]

var _timeline: Dictionary = {}
var _event_root := ""


static func stable_path(run_id: String) -> String:
	var root := AUTHORIZATION_CONTRACT.evidence_run_root(run_id)
	return "" if root.is_empty() else "%s/diagnostics/producer.phase_timeline.json" % root


static func event_root(run_id: String) -> String:
	var root := AUTHORIZATION_CONTRACT.evidence_run_root(run_id)
	return "" if root.is_empty() else "%s/diagnostics/producer.phase_timeline.events" % root


func initialize(
		run_id: String,
		repository_head: String,
		scenario_fingerprint: String,
		official: bool,
		process_start_monotonic_ms: int
) -> Dictionary:
	if not _timeline.is_empty():
		return {"valid": false, "reason_code": "phase_timeline_already_initialized"}
	if not _safe_run_id(run_id):
		return {"valid": false, "reason_code": "phase_timeline_run_id_invalid"}
	if not _lower_hex(repository_head, 40, 64):
		return {"valid": false, "reason_code": "phase_timeline_repository_head_invalid"}
	if not _lower_hex(scenario_fingerprint, 64, 64):
		return {"valid": false, "reason_code": "phase_timeline_scenario_fingerprint_invalid"}
	if process_start_monotonic_ms < 0:
		return {"valid": false, "reason_code": "phase_timeline_process_start_invalid"}
	_event_root = event_root(run_id)
	_timeline = {
		"schema_version": SCHEMA_VERSION,
		"timeline_id": TIMELINE_ID,
		"run_id": run_id,
		"role": ROLE,
		"repository_head": repository_head,
		"scenario_fingerprint": scenario_fingerprint,
		"official": official,
		"process_start_monotonic_ms": process_start_monotonic_ms,
		"snapshot_sequence": 0,
		"phase_rows": [],
		"current_phase": "",
		"last_completed_phase": "",
		"last_progress_monotonic_ms": process_start_monotonic_ms,
		"save_file_exists": false,
		"save_file_bytes": 0,
		"save_file_sha256": "",
		"child_completion_written": false,
		"allowlisted_manifest_written": false,
		"quit_requested": false,
		"timeline_fingerprint": "",
	}
	return enter_phase(PHASE_IDS[0])


func enter_phase(phase_id: String) -> Dictionary:
	if _timeline.is_empty():
		return {"valid": false, "reason_code": "phase_timeline_not_initialized"}
	var rows: Array = _timeline.get("phase_rows", [])
	if not rows.is_empty():
		var last_row := rows[-1] as Dictionary
		if str(last_row.get("phase_id", "")) == phase_id \
				and int(last_row.get("completed_monotonic_ms", 0)) == 0:
			return {"valid": true, "reason_code": "idempotent", "snapshot": snapshot()}
	if not str(_timeline.get("current_phase", "")).is_empty():
		return {"valid": false, "reason_code": "phase_timeline_previous_phase_incomplete"}
	var expected_index := rows.size()
	if expected_index >= PHASE_IDS.size() or PHASE_IDS[expected_index] != phase_id:
		return {"valid": false, "reason_code": "phase_timeline_phase_order_invalid"}
	var now := Time.get_ticks_msec()
	rows.append({
		"phase_id": phase_id,
		"entered_monotonic_ms": now,
		"completed_monotonic_ms": 0,
		"duration_ms": 0,
		"success": false,
		"reason_code": "in_progress",
		"evidence_fingerprint": "",
	})
	_timeline["phase_rows"] = rows
	_timeline["current_phase"] = phase_id
	_timeline["last_progress_monotonic_ms"] = now
	return _persist_snapshot()


func complete_phase(
		phase_id: String,
		success := true,
		reason_code := "ok",
		evidence: Dictionary = {}
) -> Dictionary:
	if _timeline.is_empty():
		return {"valid": false, "reason_code": "phase_timeline_not_initialized"}
	var rows: Array = _timeline.get("phase_rows", [])
	if rows.is_empty():
		return {"valid": false, "reason_code": "phase_timeline_phase_missing"}
	var last_row := rows[-1] as Dictionary
	if str(last_row.get("phase_id", "")) != phase_id:
		return {"valid": false, "reason_code": "phase_timeline_phase_mismatch"}
	if int(last_row.get("completed_monotonic_ms", 0)) > 0:
		var expected_evidence := _evidence_fingerprint(evidence)
		var idempotent := bool(last_row.get("success", false)) == success \
				and str(last_row.get("reason_code", "")) == reason_code \
				and str(last_row.get("evidence_fingerprint", "")) == expected_evidence
		return {
			"valid": idempotent,
			"reason_code": "idempotent" if idempotent else "phase_timeline_completed_phase_mutation",
			"snapshot": snapshot(),
		}
	if str(_timeline.get("current_phase", "")) != phase_id:
		return {"valid": false, "reason_code": "phase_timeline_current_phase_mismatch"}
	if reason_code.is_empty() or reason_code.length() > 128:
		return {"valid": false, "reason_code": "phase_timeline_reason_code_invalid"}
	var now := maxi(Time.get_ticks_msec(), int(last_row.get("entered_monotonic_ms", 0)))
	last_row["completed_monotonic_ms"] = now
	last_row["duration_ms"] = now - int(last_row.get("entered_monotonic_ms", now))
	last_row["success"] = success
	last_row["reason_code"] = reason_code
	last_row["evidence_fingerprint"] = _evidence_fingerprint(evidence)
	rows[-1] = last_row
	_timeline["phase_rows"] = rows
	_timeline["current_phase"] = ""
	_timeline["last_completed_phase"] = phase_id
	_timeline["last_progress_monotonic_ms"] = now
	return _persist_snapshot()


func update_save_file(save_path: String) -> Dictionary:
	if _timeline.is_empty():
		return {"valid": false, "reason_code": "phase_timeline_not_initialized"}
	var exists := FileAccess.file_exists(save_path)
	var byte_count := 0
	var sha256 := ""
	if exists:
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file == null:
			return {"valid": false, "reason_code": "phase_timeline_save_read_failed"}
		byte_count = file.get_length()
		file.close()
		sha256 = FileAccess.get_sha256(save_path).to_lower()
		if byte_count <= 0 or not _lower_hex(sha256, 64, 64):
			return {"valid": false, "reason_code": "phase_timeline_save_fingerprint_invalid"}
	_timeline["save_file_exists"] = exists
	_timeline["save_file_bytes"] = byte_count
	_timeline["save_file_sha256"] = sha256
	_timeline["last_progress_monotonic_ms"] = Time.get_ticks_msec()
	return _persist_snapshot()


func mark_allowlisted_manifest_written() -> Dictionary:
	return _mark_boolean("allowlisted_manifest_written")


func mark_child_completion_written() -> Dictionary:
	return _mark_boolean("child_completion_written")


func mark_quit_requested() -> Dictionary:
	var result := _mark_boolean("quit_requested")
	if bool(result.get("valid", false)):
		_timeline["quit_requested"] = true
	return result


func snapshot() -> Dictionary:
	return _timeline.duplicate(true)


static func validation_report(
		value: Variant,
		expected_run_id := "",
		expected_repository_head := ""
) -> Dictionary:
	var normalized_value: Variant = _normalize_json_value(value)
	if not (normalized_value is Dictionary):
		return {"valid": false, "reason_code": "phase_timeline_not_dictionary"}
	var timeline := normalized_value as Dictionary
	if not _has_exact_fields(timeline, FIELDS):
		return {"valid": false, "reason_code": "phase_timeline_field_set_invalid"}
	if int(timeline.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(timeline.get("timeline_id", "")) != TIMELINE_ID:
		return {"valid": false, "reason_code": "phase_timeline_schema_invalid"}
	var run_id := str(timeline.get("run_id", ""))
	if not _safe_run_id(run_id):
		return {"valid": false, "reason_code": "phase_timeline_run_id_invalid"}
	if not expected_run_id.is_empty() and run_id != expected_run_id:
		return {"valid": false, "reason_code": "phase_timeline_run_id_mismatch"}
	var repository_head := str(timeline.get("repository_head", ""))
	if not _lower_hex(repository_head, 40, 64):
		return {"valid": false, "reason_code": "phase_timeline_repository_head_invalid"}
	if not expected_repository_head.is_empty() and repository_head != expected_repository_head:
		return {"valid": false, "reason_code": "phase_timeline_repository_head_mismatch"}
	if str(timeline.get("role", "")) != ROLE \
			or not _lower_hex(str(timeline.get("scenario_fingerprint", "")), 64, 64):
		return {"valid": false, "reason_code": "phase_timeline_identity_invalid"}
	for bool_field in ["official", "save_file_exists", "child_completion_written", "allowlisted_manifest_written", "quit_requested"]:
		if not (timeline.get(bool_field) is bool):
			return {"valid": false, "reason_code": "phase_timeline_boolean_invalid"}
	for int_field in ["process_start_monotonic_ms", "snapshot_sequence", "last_progress_monotonic_ms", "save_file_bytes"]:
		if not (timeline.get(int_field) is int) or int(timeline.get(int_field, -1)) < 0:
			return {"valid": false, "reason_code": "phase_timeline_integer_invalid"}
	if int(timeline.get("snapshot_sequence", 0)) <= 0:
		return {"valid": false, "reason_code": "phase_timeline_sequence_invalid"}
	var save_exists := bool(timeline.get("save_file_exists", false))
	var save_bytes := int(timeline.get("save_file_bytes", 0))
	var save_sha := str(timeline.get("save_file_sha256", ""))
	if save_exists != (save_bytes > 0 and _lower_hex(save_sha, 64, 64)):
		return {"valid": false, "reason_code": "phase_timeline_save_state_invalid"}
	var rows_variant: Variant = timeline.get("phase_rows", [])
	if not (rows_variant is Array):
		return {"valid": false, "reason_code": "phase_timeline_rows_invalid"}
	var rows := rows_variant as Array
	if rows.is_empty() or rows.size() > PHASE_IDS.size():
		return {"valid": false, "reason_code": "phase_timeline_rows_invalid"}
	var last_completed := ""
	var incomplete_count := 0
	var previous_entered := int(timeline.get("process_start_monotonic_ms", 0))
	for index in range(rows.size()):
		if not (rows[index] is Dictionary):
			return {"valid": false, "reason_code": "phase_timeline_row_invalid"}
		var row := rows[index] as Dictionary
		if not _has_exact_fields(row, PHASE_ROW_FIELDS) or str(row.get("phase_id", "")) != PHASE_IDS[index]:
			return {"valid": false, "reason_code": "phase_timeline_phase_order_invalid"}
		var entered := int(row.get("entered_monotonic_ms", -1))
		var completed := int(row.get("completed_monotonic_ms", -1))
		var duration := int(row.get("duration_ms", -1))
		if entered < previous_entered or completed < 0 or duration < 0:
			return {"valid": false, "reason_code": "phase_timeline_monotonicity_invalid"}
		if completed == 0:
			incomplete_count += 1
			if index != rows.size() - 1 or duration != 0 or str(row.get("reason_code", "")) != "in_progress":
				return {"valid": false, "reason_code": "phase_timeline_incomplete_row_invalid"}
		else:
			if completed < entered or duration != completed - entered:
				return {"valid": false, "reason_code": "phase_timeline_duration_invalid"}
			if str(row.get("reason_code", "")).is_empty():
				return {"valid": false, "reason_code": "phase_timeline_reason_code_invalid"}
			var row_fingerprint := str(row.get("evidence_fingerprint", ""))
			if not row_fingerprint.is_empty() and not _lower_hex(row_fingerprint, 64, 64):
				return {"valid": false, "reason_code": "phase_timeline_evidence_fingerprint_invalid"}
			last_completed = str(row.get("phase_id", ""))
			previous_entered = completed
	if incomplete_count > 1:
		return {"valid": false, "reason_code": "phase_timeline_incomplete_row_invalid"}
	var expected_current := str((rows[-1] as Dictionary).get("phase_id", "")) \
			if int((rows[-1] as Dictionary).get("completed_monotonic_ms", 0)) == 0 else ""
	if str(timeline.get("current_phase", "")) != expected_current \
			or str(timeline.get("last_completed_phase", "")) != last_completed:
		return {"valid": false, "reason_code": "phase_timeline_cursor_invalid"}
	var expected_fingerprint := SEMANTIC_WIRE.fingerprint(timeline, "timeline_fingerprint")
	if expected_fingerprint.is_empty() or str(timeline.get("timeline_fingerprint", "")) != expected_fingerprint:
		return {"valid": false, "reason_code": "phase_timeline_fingerprint_invalid"}
	return {"valid": true, "reason_code": "ok", "fingerprint": expected_fingerprint}


static func transition_report(previous: Variant, current: Variant) -> Dictionary:
	var previous_report := validation_report(previous)
	if not bool(previous_report.get("valid", false)):
		return previous_report
	var previous_timeline := previous as Dictionary
	var current_report := validation_report(
		current,
		str(previous_timeline.get("run_id", "")),
		str(previous_timeline.get("repository_head", ""))
	)
	if not bool(current_report.get("valid", false)):
		return current_report
	var current_timeline := current as Dictionary
	if str(current_timeline.get("scenario_fingerprint", "")) != str(previous_timeline.get("scenario_fingerprint", "")) \
			or bool(current_timeline.get("official", false)) != bool(previous_timeline.get("official", false)):
		return {"valid": false, "reason_code": "phase_timeline_identity_mutation"}
	if int(current_timeline.get("snapshot_sequence", 0)) <= int(previous_timeline.get("snapshot_sequence", 0)):
		return {"valid": false, "reason_code": "phase_timeline_sequence_not_advanced"}
	var previous_rows := previous_timeline.get("phase_rows", []) as Array
	var current_rows := current_timeline.get("phase_rows", []) as Array
	if current_rows.size() < previous_rows.size():
		return {"valid": false, "reason_code": "phase_timeline_truncated"}
	for index in range(previous_rows.size() - 1):
		if SEMANTIC_WIRE.canonical_json(previous_rows[index]) != SEMANTIC_WIRE.canonical_json(current_rows[index]):
			return {"valid": false, "reason_code": "phase_timeline_completed_row_mutation"}
	for flag in ["save_file_exists", "child_completion_written", "allowlisted_manifest_written", "quit_requested"]:
		if bool(previous_timeline.get(flag, false)) and not bool(current_timeline.get(flag, false)):
			return {"valid": false, "reason_code": "phase_timeline_flag_regressed"}
	if int(current_timeline.get("last_progress_monotonic_ms", 0)) < int(previous_timeline.get("last_progress_monotonic_ms", 0)):
		return {"valid": false, "reason_code": "phase_timeline_progress_regressed"}
	return {"valid": true, "reason_code": "ok"}


func _mark_boolean(field: String) -> Dictionary:
	if _timeline.is_empty() or field not in ["child_completion_written", "allowlisted_manifest_written", "quit_requested"]:
		return {"valid": false, "reason_code": "phase_timeline_flag_invalid"}
	if bool(_timeline.get(field, false)):
		return {"valid": true, "reason_code": "idempotent", "snapshot": snapshot()}
	_timeline[field] = true
	_timeline["last_progress_monotonic_ms"] = Time.get_ticks_msec()
	return _persist_snapshot()


func _persist_snapshot() -> Dictionary:
	var sequence := int(_timeline.get("snapshot_sequence", 0)) + 1
	_timeline["snapshot_sequence"] = sequence
	var unsealed := _timeline.duplicate(true)
	unsealed.erase("timeline_fingerprint")
	_timeline = SEMANTIC_WIRE.sealed_copy(unsealed, "timeline_fingerprint")
	var validation := validation_report(_timeline)
	if not bool(validation.get("valid", false)):
		return validation
	var absolute_root := ProjectSettings.globalize_path(_event_root)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	if directory_error != OK:
		return {"valid": false, "reason_code": "phase_timeline_directory_failed"}
	var event_path := "%s/%06d.snapshot.json" % [absolute_root, sequence]
	var temp_path := "%s.tmp.%d" % [event_path, OS.get_process_id()]
	if FileAccess.file_exists(event_path) or FileAccess.file_exists(temp_path):
		return {"valid": false, "reason_code": "phase_timeline_event_collision"}
	var canonical := SEMANTIC_WIRE.canonical_json(_timeline)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"valid": false, "reason_code": "phase_timeline_event_write_failed"}
	file.store_string(canonical)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temp_path) != canonical:
		_remove_if_present(temp_path)
		return {"valid": false, "reason_code": "phase_timeline_event_readback_failed"}
	var rename_error := DirAccess.rename_absolute(temp_path, event_path)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return {"valid": false, "reason_code": "phase_timeline_event_atomic_install_failed"}
	return {
		"valid": true,
		"reason_code": "ok",
		"event_path": event_path,
		"snapshot": snapshot(),
	}


static func _evidence_fingerprint(evidence: Dictionary) -> String:
	return "" if evidence.is_empty() else SEMANTIC_WIRE.fingerprint(evidence)


static func _has_exact_fields(value: Dictionary, expected_fields: Array) -> bool:
	if value.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _normalize_json_value(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	if value is Array:
		var normalized_array: Array = []
		for item in value as Array:
			normalized_array.append(_normalize_json_value(item))
		return normalized_array
	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			normalized_dictionary[str(key_variant)] = _normalize_json_value(
				(value as Dictionary).get(key_variant)
			)
		return normalized_dictionary
	return value


static func _safe_run_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(value.substr(index, 1)):
			return false
	return true


static func _lower_hex(value: String, minimum_length: int, maximum_length: int) -> bool:
	if value.length() < minimum_length or value.length() > maximum_length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
