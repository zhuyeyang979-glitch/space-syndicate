extends RefCounted

const LAUNCH_CONTEXT := preload(
	"res://scripts/tools/cold_restore_targeted_diagnostic_launch_context_v1.gd"
)
const LEDGER_VALIDATOR := preload(
	"res://scripts/tools/cold_restore_targeted_ledger_binding_validator_v1.gd"
)


static func replay(
	source_ledger_path: String,
	expected_ledger_sha256: String,
	source_launch_attestation_path: String,
	expected_launch_attestation_sha256: String,
	replay_root: String
) -> Dictionary:
	var lock_path := "%s.lock" % replay_root
	var parent := replay_root.get_base_dir()
	if replay_root.is_empty() or not replay_root.is_absolute_path() \
			or source_ledger_path.is_empty() or source_launch_attestation_path.is_empty():
		return _failure("replay_arguments_invalid")
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return _failure("replay_parent_create_failed")
	if DirAccess.make_dir_absolute(lock_path) != OK:
		return _failure("replay_in_use")
	var result := _replay_locked(
		source_ledger_path,
		expected_ledger_sha256,
		source_launch_attestation_path,
		expected_launch_attestation_sha256,
		replay_root
	)
	if DirAccess.remove_absolute(lock_path) != OK:
		return _failure("replay_lock_release_failed")
	return result


static func _replay_locked(
	source_ledger_path: String,
	expected_ledger_sha256: String,
	source_launch_attestation_path: String,
	expected_launch_attestation_sha256: String,
	replay_root: String
) -> Dictionary:
	if not FileAccess.file_exists(source_ledger_path) \
			or not FileAccess.file_exists(source_launch_attestation_path):
		return _failure("retained_v5_artifact_missing")
	var source_ledger_bytes := FileAccess.get_file_as_bytes(source_ledger_path)
	var source_launch_bytes := FileAccess.get_file_as_bytes(source_launch_attestation_path)
	if _bytes_sha256(source_ledger_bytes) != expected_ledger_sha256.to_lower():
		return _failure("retained_v5_ledger_sha256_mismatch")
	if _bytes_sha256(source_launch_bytes) != expected_launch_attestation_sha256.to_lower():
		return _failure("retained_v5_launch_attestation_sha256_mismatch")
	if DirAccess.make_dir_recursive_absolute(replay_root) != OK:
		return _failure("replay_root_create_failed")
	var ledger_copy_path := replay_root.path_join("retained-v5-ledger.copy.json")
	var launch_copy_path := replay_root.path_join("retained-v5-launch-attestation.copy.json")
	if not _write_copy(ledger_copy_path, source_ledger_bytes) \
			or not _write_copy(launch_copy_path, source_launch_bytes):
		return _failure("retained_v5_copy_write_failed")
	if _bytes_sha256(FileAccess.get_file_as_bytes(ledger_copy_path)) \
			!= expected_ledger_sha256.to_lower() \
			or _bytes_sha256(FileAccess.get_file_as_bytes(launch_copy_path)) \
			!= expected_launch_attestation_sha256.to_lower():
		return _failure("retained_v5_copy_sha256_mismatch")

	var ledger_text := FileAccess.get_file_as_string(ledger_copy_path)
	var launch_text := FileAccess.get_file_as_string(launch_copy_path)
	var ledger_variant: Variant = JSON.parse_string(ledger_text)
	var launch_variant: Variant = JSON.parse_string(launch_text)
	if not (ledger_variant is Dictionary) or not (launch_variant is Dictionary):
		return _failure("retained_v5_json_invalid")
	var ledger := ledger_variant as Dictionary
	var launch_attestation := launch_variant as Dictionary
	var source_context := LAUNCH_CONTEXT.build_replay_source_context(
		ledger,
		launch_attestation,
		ledger_copy_path,
		expected_ledger_sha256.to_lower(),
		launch_copy_path
	)
	if not bool(source_context.get("valid", false)):
		return _failure_from_report(source_context)
	var canonical_context := source_context.get("context", {}) as Dictionary
	var arguments_result := LAUNCH_CONTEXT.argument_list(canonical_context)
	if not bool(arguments_result.get("valid", false)):
		return _failure_from_report(arguments_result)
	var arguments: Array[String] = []
	for entry in arguments_result.get("arguments", []):
		arguments.append(str(entry))
	var parsed_result := LAUNCH_CONTEXT.parse_cli_argument_list(arguments)
	if not bool(parsed_result.get("valid", false)):
		return _failure_from_report(parsed_result)
	var parsed_options := (parsed_result.get("options", {}) as Dictionary).duplicate(true)

	# This is the exact V5 defect characterization: validate_options projected a new
	# dictionary without the parsed head_sha before invoking the ledger validator.
	var pre_fix_options := parsed_options.duplicate(true)
	pre_fix_options.erase("head_sha")
	var pre_fix := LEDGER_VALIDATOR.validate_ledger_text(ledger_text, pre_fix_options)
	var pre_fix_green := not bool(pre_fix.get("valid", true)) \
			and str(pre_fix.get("failing_field", "")) == "repository_head" \
			and str(pre_fix.get("safe_expected_fingerprint", "")) \
				== JSON.stringify(null).sha256_text().to_lower()
	if not pre_fix_green:
		return _failure("v5_pre_fix_characterization_failed")

	var rebuilt := LAUNCH_CONTEXT.build_child_context(parsed_options, ledger)
	if not bool(rebuilt.get("valid", false)):
		return _failure_from_report(rebuilt)
	var replay_context := rebuilt.get("context", {}) as Dictionary
	var launch_report := LAUNCH_CONTEXT.validate_launch_attestation(
		replay_context, launch_attestation, "retained_v5_launch_attestation"
	)
	if not bool(launch_report.get("valid", false)):
		return _failure_from_report(launch_report)
	var canonical := LEDGER_VALIDATOR.validate_ledger_text_with_launch_context(
		ledger_text, replay_context
	)
	if not bool(canonical.get("valid", false)):
		return _failure_from_report(canonical)
	if _bytes_sha256(FileAccess.get_file_as_bytes(source_ledger_path)) \
			!= expected_ledger_sha256.to_lower() \
			or _bytes_sha256(FileAccess.get_file_as_bytes(source_launch_attestation_path)) \
			!= expected_launch_attestation_sha256.to_lower():
		return _failure("retained_v5_source_mutated")
	return {
		"schema_version": 1,
		"replay_id": "ColdRestoreV5RepositoryHeadReplayV1",
		"targeted_diagnostic_v5_replay_mode": true,
		"valid": true,
		"reason_code": "ok",
		"v5_ledger_bytes_retained": true,
		"v5_launch_attestation_bytes_retained": true,
		"v5_replay_pre_fix_field": "repository_head",
		"v5_replay_pre_fix_expected_value_kind": "canonical_json_null",
		"v5_replay_pre_fix_safe_expected_fingerprint": str(
			pre_fix.get("safe_expected_fingerprint", "")
		),
		"v5_retained_ledger_replay_green": true,
		"v5_child_bootstrap_binding_green": true,
		"v5_repository_head_lineage_green": true,
		"binding_check_count": int(canonical.get("check_count", 0)),
		"binding_pass_count": int(canonical.get("pass_count", 0)),
		"binding_failure_count": int(canonical.get("failure_count", 0)),
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_session_create_count": 0,
		"replay_owner_capture_count": 0,
		"replay_save_write_count": 0,
		"main_scene_load_count": 0,
		"v6_artifact_create_count": 0,
	}


static func _write_copy(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	file.close()
	return true


static func _bytes_sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(bytes) != OK:
		return ""
	return hashing.finish().hex_encode().to_lower()


static func _failure_from_report(report: Dictionary) -> Dictionary:
	var result := _failure(str(report.get("reason_code", "replay_validation_failed")))
	for field in [
		"failing_stage", "failing_field", "field_reason",
		"safe_expected_fingerprint", "safe_actual_fingerprint",
	]:
		result[field] = str(report.get(field, ""))
	return result


static func _failure(reason_code: String) -> Dictionary:
	return {
		"schema_version": 1,
		"replay_id": "ColdRestoreV5RepositoryHeadReplayV1",
		"targeted_diagnostic_v5_replay_mode": true,
		"valid": false,
		"reason_code": reason_code.left(96),
		"v5_retained_ledger_replay_green": false,
		"v5_child_bootstrap_binding_green": false,
		"v5_repository_head_lineage_green": false,
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_session_create_count": 0,
		"replay_owner_capture_count": 0,
		"replay_save_write_count": 0,
		"main_scene_load_count": 0,
		"v6_artifact_create_count": 0,
	}
