extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const COMPLETION_ID := "ProcessARehearsalCompletionV1"
const EVIDENCE_ROOT := "res://.godot/cold_restore_attestation_v1"
const FIELDS := [
	"schema_version", "completion_id", "run_id", "repository_head",
	"scenario_fingerprint", "rehearsal_only", "official", "formal",
	"official_attempt_claim_created", "official_authorization_consumed",
	"authorization_fingerprint", "timeout_policy_fingerprint", "restore_barrier_entered",
	"restore_barrier_quiet", "restore_barrier_released",
	"save_owner_capture_count", "save_section_count", "save_preflight_count",
	"capture_operation_sequence", "captured_sections_fingerprint",
	"readback_sections_fingerprint",
	"save_capture_world_delta", "save_capture_rng_delta", "save_capture_public_log_delta",
	"envelope_encode_green", "atomic_write_green", "save_readback_green",
	"save_capture_fingerprint", "save_readback_fingerprint",
	"save_fingerprint_parity", "save_file_bytes", "save_file_sha256",
	"queue_entry_count", "evidence_fingerprint",
]


static func stable_path(run_id: String) -> String:
	return "%s/%s/diagnostics/process_a.rehearsal_completion.json" % [EVIDENCE_ROOT, run_id]


static func build(source: Dictionary) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"completion_id": COMPLETION_ID,
		"run_id": str(source.get("run_id", "")),
		"repository_head": str(source.get("repository_head", "")),
		"scenario_fingerprint": str(source.get("scenario_fingerprint", "")),
		"rehearsal_only": true,
		"official": false,
		"formal": false,
		"official_attempt_claim_created": false,
		"official_authorization_consumed": false,
		"authorization_fingerprint": str(source.get("authorization_fingerprint", "")),
		"timeout_policy_fingerprint": str(source.get("timeout_policy_fingerprint", "")),
		"restore_barrier_entered": bool(source.get("restore_barrier_entered", false)),
		"restore_barrier_quiet": bool(source.get("restore_barrier_quiet", false)),
		"restore_barrier_released": bool(source.get("restore_barrier_released", false)),
		"save_owner_capture_count": int(source.get("save_owner_capture_count", 0)),
		"save_section_count": int(source.get("save_section_count", 0)),
		"save_preflight_count": int(source.get("save_preflight_count", 0)),
		"capture_operation_sequence": int(source.get("capture_operation_sequence", 0)),
		"captured_sections_fingerprint": str(source.get("captured_sections_fingerprint", "")),
		"readback_sections_fingerprint": str(source.get("readback_sections_fingerprint", "")),
		"save_capture_world_delta": int(source.get("save_capture_world_delta", -1)),
		"save_capture_rng_delta": int(source.get("save_capture_rng_delta", -1)),
		"save_capture_public_log_delta": int(source.get("save_capture_public_log_delta", -1)),
		"envelope_encode_green": bool(source.get("envelope_encode_green", false)),
		"atomic_write_green": bool(source.get("atomic_write_green", false)),
		"save_readback_green": bool(source.get("save_readback_green", false)),
		"save_capture_fingerprint": str(source.get("save_capture_fingerprint", "")),
		"save_readback_fingerprint": str(source.get("save_readback_fingerprint", "")),
		"save_fingerprint_parity": bool(source.get("save_fingerprint_parity", false)),
		"save_file_bytes": int(source.get("save_file_bytes", 0)),
		"save_file_sha256": str(source.get("save_file_sha256", "")),
		"queue_entry_count": int(source.get("queue_entry_count", 0)),
	}
	return SEMANTIC_WIRE.sealed_copy(unsealed, "evidence_fingerprint")


static func validation_report(
	value: Variant,
	expected_run_id: String = "",
	expected_repository_head: String = "",
	expected_scenario_fingerprint: String = "",
	expected_authorization_fingerprint: String = "",
	expected_timeout_policy_fingerprint: String = ""
) -> Dictionary:
	if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, FIELDS):
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_field_set_invalid"}
	var completion := value as Dictionary
	if not (completion.get("schema_version") is int) \
			or int(completion.get("schema_version", 0)) != SCHEMA_VERSION \
			or str(completion.get("completion_id", "")) != COMPLETION_ID \
			or not _safe_run_id(str(completion.get("run_id", ""))) \
			or not _lower_hex(str(completion.get("repository_head", "")), 40, 64) \
			or not _lower_hex(str(completion.get("scenario_fingerprint", "")), 64, 64) \
			or not _lower_hex(str(completion.get("authorization_fingerprint", "")), 64, 64) \
			or not _lower_hex(str(completion.get("timeout_policy_fingerprint", "")), 64, 64):
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_identity_invalid"}
	if (not expected_run_id.is_empty() and str(completion.get("run_id", "")) != expected_run_id) \
			or (not expected_repository_head.is_empty() and str(completion.get("repository_head", "")) != expected_repository_head) \
			or (not expected_scenario_fingerprint.is_empty() and str(completion.get("scenario_fingerprint", "")) != expected_scenario_fingerprint) \
			or (not expected_authorization_fingerprint.is_empty() and str(completion.get("authorization_fingerprint", "")) != expected_authorization_fingerprint) \
			or (not expected_timeout_policy_fingerprint.is_empty() and str(completion.get("timeout_policy_fingerprint", "")) != expected_timeout_policy_fingerprint):
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_binding_invalid"}
	for flag in [
		"rehearsal_only", "official", "formal", "official_attempt_claim_created",
		"official_authorization_consumed", "restore_barrier_entered",
		"restore_barrier_quiet", "restore_barrier_released", "envelope_encode_green",
		"atomic_write_green", "save_readback_green", "save_fingerprint_parity",
	]:
		if not (completion.get(flag) is bool):
			return {"valid": false, "reason_code": "process_a_rehearsal_completion_boolean_invalid"}
	if not bool(completion.get("rehearsal_only", false)) \
			or bool(completion.get("official", true)) \
			or bool(completion.get("formal", true)) \
			or bool(completion.get("official_attempt_claim_created", true)) \
			or bool(completion.get("official_authorization_consumed", true)):
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_authority_invalid"}
	for count_field in [
		"save_owner_capture_count", "save_section_count", "save_preflight_count",
		"capture_operation_sequence", "save_file_bytes", "queue_entry_count",
	]:
		if not (completion.get(count_field) is int) or int(completion.get(count_field, -1)) < 0:
			return {"valid": false, "reason_code": "process_a_rehearsal_completion_count_invalid"}
	for delta_field in [
		"save_capture_world_delta", "save_capture_rng_delta", "save_capture_public_log_delta",
	]:
		if not (completion.get(delta_field) is int) or int(completion.get(delta_field, 1)) != 0:
			return {"valid": false, "reason_code": "process_a_rehearsal_completion_capture_delta_invalid"}
	var capture_fingerprint := str(completion.get("save_capture_fingerprint", ""))
	var readback_fingerprint := str(completion.get("save_readback_fingerprint", ""))
	var captured_sections_fingerprint := str(completion.get("captured_sections_fingerprint", ""))
	var readback_sections_fingerprint := str(completion.get("readback_sections_fingerprint", ""))
	if not bool(completion.get("restore_barrier_entered", false)) \
			or not bool(completion.get("restore_barrier_quiet", false)) \
			or not bool(completion.get("restore_barrier_released", false)) \
			or int(completion.get("save_owner_capture_count", 0)) != 19 \
			or int(completion.get("save_section_count", 0)) != 19 \
			or int(completion.get("save_preflight_count", 0)) != 19 \
			or int(completion.get("capture_operation_sequence", 0)) <= 0 \
			or not _lower_hex(captured_sections_fingerprint, 64, 64) \
			or readback_sections_fingerprint != captured_sections_fingerprint \
			or not bool(completion.get("envelope_encode_green", false)) \
			or not bool(completion.get("atomic_write_green", false)) \
			or not bool(completion.get("save_readback_green", false)) \
			or not bool(completion.get("save_fingerprint_parity", false)) \
			or not _lower_hex(capture_fingerprint, 64, 64) \
			or readback_fingerprint != capture_fingerprint \
			or int(completion.get("save_file_bytes", 0)) <= 0 \
			or not _lower_hex(str(completion.get("save_file_sha256", "")), 64, 64) \
			or int(completion.get("queue_entry_count", 0)) != 1:
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_not_green"}
	var evidence_fingerprint := SEMANTIC_WIRE.fingerprint(completion, "evidence_fingerprint")
	if evidence_fingerprint.is_empty() \
			or str(completion.get("evidence_fingerprint", "")) != evidence_fingerprint:
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_fingerprint_invalid"}
	return {"valid": true, "reason_code": "ok", "fingerprint": evidence_fingerprint}


static func write_atomic(run_id: String, completion: Dictionary) -> Dictionary:
	var report := validation_report(completion, run_id)
	if not bool(report.get("valid", false)):
		return report
	var path := stable_path(run_id)
	var absolute := ProjectSettings.globalize_path(path)
	var temp := "%s.tmp.%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(absolute) or FileAccess.file_exists(temp):
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_collision"}
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_directory_failed"}
	var canonical := SEMANTIC_WIRE.canonical_json(completion)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_write_failed"}
	file.store_string(canonical)
	file.flush()
	file.close()
	if FileAccess.get_file_as_string(temp) != canonical:
		DirAccess.remove_absolute(temp)
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_readback_failed"}
	if DirAccess.rename_absolute(temp, absolute) != OK:
		DirAccess.remove_absolute(temp)
		return {"valid": false, "reason_code": "process_a_rehearsal_completion_atomic_replace_failed"}
	return {"valid": true, "reason_code": "ok", "path": path, "sha256": canonical.sha256_text().to_lower()}


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
