extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const HEARTBEAT_ID := "ColdRestoreRoleProgressHeartbeatV1"
const EVIDENCE_ROOT := "res://.godot/cold_restore_attestation_v1"
const ROLE_IDS := ["targeted_owner_diagnostic", "process_a", "process_b", "process_c"]
const FIELDS := [
	"schema_version", "heartbeat_id", "run_id", "role_id", "repository_head",
	"policy_fingerprint", "heartbeat_sequence", "phase", "world_time",
	"owner_index", "queue_revision", "save_phase", "last_evidence_write_time",
	"semantic_progress_fingerprint", "evidence_fingerprint",
]

var _run_id := ""
var _role_id := ""
var _repository_head := ""
var _policy_fingerprint := ""
var _sequence := 0
var _last_semantic_fingerprint := ""


func initialize(run_id: String, role_id: String, repository_head: String, policy_fingerprint: String) -> Dictionary:
	if not _safe_run_id(run_id) or role_id not in ROLE_IDS \
			or not _lower_hex(repository_head, 40, 64) \
			or not _lower_hex(policy_fingerprint, 64, 64):
		return {"valid": false, "reason_code": "heartbeat_identity_invalid"}
	_run_id = run_id
	_role_id = role_id
	_repository_head = repository_head
	_policy_fingerprint = policy_fingerprint
	_sequence = 0
	_last_semantic_fingerprint = ""
	return {"valid": true, "reason_code": "ok"}


func emit(progress: Dictionary) -> Dictionary:
	if _run_id.is_empty() or not _has_exact_fields(progress, [
		"phase", "world_time", "owner_index", "queue_revision", "save_phase",
	]):
		return {"valid": false, "reason_code": "heartbeat_progress_invalid"}
	for int_field in ["world_time", "owner_index", "queue_revision"]:
		if not (progress.get(int_field) is int) or int(progress.get(int_field, -2)) < (-1 if int_field == "owner_index" else 0):
			return {"valid": false, "reason_code": "heartbeat_progress_invalid"}
	var phase := _safe_token(str(progress.get("phase", "")))
	var save_phase := _safe_token(str(progress.get("save_phase", "")))
	if phase.is_empty() or save_phase.is_empty():
		return {"valid": false, "reason_code": "heartbeat_progress_invalid"}
	var semantic := {
		"phase": phase,
		"world_time": int(progress.get("world_time", 0)),
		"owner_index": int(progress.get("owner_index", -1)),
		"queue_revision": int(progress.get("queue_revision", 0)),
		"save_phase": save_phase,
	}
	var semantic_fingerprint := SEMANTIC_WIRE.fingerprint(semantic)
	if semantic_fingerprint.is_empty():
		return {"valid": false, "reason_code": "heartbeat_semantic_fingerprint_invalid"}
	_sequence += 1
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"heartbeat_id": HEARTBEAT_ID,
		"run_id": _run_id,
		"role_id": _role_id,
		"repository_head": _repository_head,
		"policy_fingerprint": _policy_fingerprint,
		"heartbeat_sequence": _sequence,
		"phase": phase,
		"world_time": int(progress.get("world_time", 0)),
		"owner_index": int(progress.get("owner_index", -1)),
		"queue_revision": int(progress.get("queue_revision", 0)),
		"save_phase": save_phase,
		"last_evidence_write_time": Time.get_ticks_msec(),
		"semantic_progress_fingerprint": semantic_fingerprint,
	}
	var heartbeat := SEMANTIC_WIRE.sealed_copy(unsealed, "evidence_fingerprint")
	if not bool(validation_report(heartbeat, _run_id, _role_id, _repository_head, _policy_fingerprint).get("valid", false)):
		return {"valid": false, "reason_code": "heartbeat_build_invalid"}
	var write := _write_atomic_event(heartbeat)
	if not bool(write.get("valid", false)):
		return write
	write["semantic_progressed"] = semantic_fingerprint != _last_semantic_fingerprint
	write["heartbeat"] = heartbeat
	_last_semantic_fingerprint = semantic_fingerprint
	return write


static func validation_report(
	value: Variant,
	expected_run_id: String = "",
	expected_role_id: String = "",
	expected_repository_head: String = "",
	expected_policy_fingerprint: String = ""
) -> Dictionary:
	if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, FIELDS):
		return {"valid": false, "reason_code": "heartbeat_field_set_invalid"}
	var heartbeat := value as Dictionary
	if not (heartbeat.get("schema_version") is int) or int(heartbeat.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(heartbeat.get("heartbeat_id", "")) != HEARTBEAT_ID \
			or not _safe_run_id(str(heartbeat.get("run_id", ""))) \
			or str(heartbeat.get("role_id", "")) not in ROLE_IDS \
			or not _lower_hex(str(heartbeat.get("repository_head", "")), 40, 64) \
			or not _lower_hex(str(heartbeat.get("policy_fingerprint", "")), 64, 64):
		return {"valid": false, "reason_code": "heartbeat_header_invalid"}
	if (not expected_run_id.is_empty() and str(heartbeat.get("run_id", "")) != expected_run_id) \
			or (not expected_role_id.is_empty() and str(heartbeat.get("role_id", "")) != expected_role_id) \
			or (not expected_repository_head.is_empty() and str(heartbeat.get("repository_head", "")) != expected_repository_head) \
			or (not expected_policy_fingerprint.is_empty() and str(heartbeat.get("policy_fingerprint", "")) != expected_policy_fingerprint):
		return {"valid": false, "reason_code": "heartbeat_identity_mismatch"}
	for int_field in ["heartbeat_sequence", "world_time", "owner_index", "queue_revision", "last_evidence_write_time"]:
		if not (heartbeat.get(int_field) is int):
			return {"valid": false, "reason_code": "heartbeat_integer_invalid"}
	if int(heartbeat.get("heartbeat_sequence", 0)) < 1 \
			or int(heartbeat.get("world_time", -1)) < 0 \
			or int(heartbeat.get("owner_index", -2)) < -1 \
			or int(heartbeat.get("queue_revision", -1)) < 0 \
			or int(heartbeat.get("last_evidence_write_time", -1)) < 0:
		return {"valid": false, "reason_code": "heartbeat_integer_invalid"}
	var semantic := {
		"phase": str(heartbeat.get("phase", "")),
		"world_time": int(heartbeat.get("world_time", 0)),
		"owner_index": int(heartbeat.get("owner_index", -1)),
		"queue_revision": int(heartbeat.get("queue_revision", 0)),
		"save_phase": str(heartbeat.get("save_phase", "")),
	}
	if str(heartbeat.get("semantic_progress_fingerprint", "")) != SEMANTIC_WIRE.fingerprint(semantic) \
			or str(heartbeat.get("evidence_fingerprint", "")) != SEMANTIC_WIRE.fingerprint(heartbeat, "evidence_fingerprint"):
		return {"valid": false, "reason_code": "heartbeat_fingerprint_invalid"}
	return {"valid": true, "reason_code": "ok"}


func _write_atomic_event(heartbeat: Dictionary) -> Dictionary:
	var path := "%s/%s/diagnostics/%s.heartbeat.events/%04d.snapshot.json" % [
		EVIDENCE_ROOT, _run_id, _role_id, _sequence,
	]
	var absolute := ProjectSettings.globalize_path(path)
	var temp := "%s.tmp.%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(absolute) or FileAccess.file_exists(temp):
		return {"valid": false, "reason_code": "heartbeat_evidence_collision"}
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"valid": false, "reason_code": "heartbeat_directory_failed"}
	var canonical := SEMANTIC_WIRE.canonical_json(heartbeat)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return {"valid": false, "reason_code": "heartbeat_write_failed"}
	file.store_string(canonical)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temp) != canonical:
		DirAccess.remove_absolute(temp)
		return {"valid": false, "reason_code": "heartbeat_readback_failed"}
	if DirAccess.rename_absolute(temp, absolute) != OK:
		DirAccess.remove_absolute(temp)
		return {"valid": false, "reason_code": "heartbeat_atomic_replace_failed"}
	return {"valid": true, "reason_code": "ok", "path": path, "sha256": canonical.sha256_text().to_lower()}


static func _safe_token(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	var result := ""
	for index in range(normalized.length()):
		var character := normalized.substr(index, 1)
		if "abcdefghijklmnopqrstuvwxyz0123456789_".contains(character):
			result += character
		elif not result.ends_with("_"):
			result += "_"
	return result.trim_prefix("_").trim_suffix("_").left(96)


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _safe_run_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(value.substr(index, 1)):
			return false
	return true


static func _lower_hex(value: String, minimum: int, maximum: int) -> bool:
	if value.length() < minimum or value.length() > maximum:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
