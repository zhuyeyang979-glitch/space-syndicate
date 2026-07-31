extends SceneTree

const BINDING_VALIDATOR := preload(
	"res://scripts/tools/cold_restore_targeted_ledger_binding_validator_v1.gd"
)


func _init() -> void:
	var arguments := _parse_arguments(OS.get_cmdline_user_args())
	var engine_arguments := _parse_arguments(OS.get_cmdline_args())
	for key in arguments.keys():
		if str(arguments.get(key, "")).is_empty():
			arguments[key] = engine_arguments.get(key, "")
	var source_path := str(arguments.get("source_ledger", ""))
	var replay_root := str(arguments.get("replay_root", ""))
	var expected_sha256 := str(arguments.get("expected_sha256", "")).to_lower()
	var matrix_output := str(arguments.get("matrix_output", ""))
	if source_path.is_empty() or replay_root.is_empty() or expected_sha256.is_empty():
		_finish(_failure("replay_arguments_invalid"))
		return
	if not FileAccess.file_exists(source_path):
		_finish(_failure("retained_ledger_missing"))
		return
	var source_text := FileAccess.get_file_as_string(source_path)
	if source_text.sha256_text().to_lower() != expected_sha256:
		_finish(_failure("retained_ledger_sha256_mismatch"))
		return
	if DirAccess.make_dir_recursive_absolute(replay_root) != OK:
		_finish(_failure("replay_root_create_failed"))
		return
	var copy_path := replay_root.path_join("retained-v4-ledger.copy.json")
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	var target := FileAccess.open(copy_path, FileAccess.WRITE)
	if target == null:
		_finish(_failure("replay_copy_open_failed"))
		return
	target.store_buffer(source_bytes)
	target.flush()
	target.close()
	var copy_text := FileAccess.get_file_as_string(copy_path)
	if copy_text.sha256_text().to_lower() != expected_sha256:
		_finish(_failure("replay_copy_sha256_mismatch"))
		return
	var parsed: Variant = JSON.parse_string(copy_text)
	if not (parsed is Dictionary):
		_finish(_failure("retained_ledger_json_invalid"))
		return
	var ledger := parsed as Dictionary
	var options := {
		"run_id": str(ledger.get("run_id", "")),
		"head_sha": str(ledger.get("repository_head", "")),
		"scenario_fingerprint": str(ledger.get("scenario_fingerprint", "")),
		"timeout_policy_fingerprint": str(ledger.get("role_timeout_policy_sha256", "")),
		"launch_nonce": str(ledger.get("launch_nonce", "")),
		"targeted_diagnostic_ledger_fingerprint": expected_sha256,
	}
	var legacy := BINDING_VALIDATOR.characterize_legacy_v4_mismatch(
		copy_text,
		expected_sha256
	)
	var canonical := BINDING_VALIDATOR.validate_ledger_text(copy_text, options)
	var result := {
		"schema_version": 1,
		"replay_id": "ColdRestoreTargetedLedgerReplayV1",
		"targeted_ledger_replay_mode": true,
		"legacy_reason_code": str(legacy.get("reason_code", "")),
		"legacy_failing_field": str(legacy.get("failing_field", "")),
		"legacy_field_reason": str(legacy.get("field_reason", "")),
		"canonical_valid": bool(canonical.get("valid", false)),
		"canonical_reason_code": str(canonical.get("reason_code", "")),
		"canonical_failing_field": str(canonical.get("failing_field", "")),
		"canonical_field_reason": str(canonical.get("field_reason", "")),
		"binding_check_count": int(canonical.get("check_count", 0)),
		"binding_pass_count": int(canonical.get("pass_count", 0)),
		"binding_failure_count": int(canonical.get("failure_count", 0)),
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_session_create_count": 0,
		"replay_save_write_count": 0,
		"replay_owner_capture_count": 0,
	}
	if not matrix_output.is_empty():
		var matrix_write := _write_matrix_report(matrix_output, legacy, canonical)
		if not bool(matrix_write.get("valid", false)):
			_finish(_failure(str(matrix_write.get("reason_code", "matrix_write_failed"))))
			return
	_finish(result)


func _parse_arguments(arguments: PackedStringArray) -> Dictionary:
	var result := {
		"source_ledger": "",
		"replay_root": "",
		"expected_sha256": "",
		"matrix_output": "",
	}
	for argument_variant in arguments:
		var argument := str(argument_variant)
		if argument.begins_with("--v4-retained-ledger-path="):
			result["source_ledger"] = argument.trim_prefix("--v4-retained-ledger-path=")
		elif argument.begins_with("--v4-replay-root="):
			result["replay_root"] = argument.trim_prefix("--v4-replay-root=")
		elif argument.begins_with("--v4-retained-ledger-sha256="):
			result["expected_sha256"] = argument.trim_prefix("--v4-retained-ledger-sha256=")
		elif argument.begins_with("--v4-matrix-output="):
			result["matrix_output"] = argument.trim_prefix("--v4-matrix-output=")
	return result


func _write_matrix_report(path: String, legacy: Dictionary, canonical: Dictionary) -> Dictionary:
	if path.is_empty() or not path.is_absolute_path():
		return {"valid": false, "reason_code": "matrix_output_path_invalid"}
	var parent := path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent) != OK:
		return {"valid": false, "reason_code": "matrix_output_parent_failed"}
	var report := {
		"schema_version": 1,
		"matrix_id": "Alpha04CV4LedgerBindingMatrixV1",
		"run_id": "alpha04c-owner-capture-diagnostic-v4-importchain-407cbb4501cf",
		"ledger_sha256": "154ceedf4032404d4c7d355fbd775991e20d29299f6e05e3a8c8e70c64be208c",
		"pre_fix_reason_code": str(legacy.get("reason_code", "")),
		"first_ledger_binding_mismatch_field": str(legacy.get("failing_field", "")),
		"first_ledger_binding_mismatch_reason": str(legacy.get("field_reason", "")),
		"pre_fix_expected_type": str(legacy.get("expected_type", "")),
		"pre_fix_actual_type": str(legacy.get("actual_type", "")),
		"post_fix_valid": bool(canonical.get("valid", false)),
		"ledger_binding_check_count": int(canonical.get("check_count", 0)),
		"ledger_binding_pass_count": int(canonical.get("pass_count", 0)),
		"ledger_binding_failure_count": int(canonical.get("failure_count", 0)),
		"private_payload_exposure_count": 0,
		"field_rows": canonical.get("field_rows", []),
	}
	var temporary_path := "%s.tmp" % path
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"valid": false, "reason_code": "matrix_output_open_failed"}
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.flush()
	file.close()
	var readback: Variant = JSON.parse_string(FileAccess.get_file_as_string(temporary_path))
	if not (readback is Dictionary) or int((readback as Dictionary).get("ledger_binding_check_count", 0)) != 35:
		DirAccess.remove_absolute(temporary_path)
		return {"valid": false, "reason_code": "matrix_output_readback_failed"}
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return {"valid": false, "reason_code": "matrix_output_replace_failed"}
	if DirAccess.rename_absolute(temporary_path, path) != OK:
		return {"valid": false, "reason_code": "matrix_output_replace_failed"}
	return {"valid": true, "reason_code": "ok"}


func _failure(reason_code: String) -> Dictionary:
	return {
		"schema_version": 1,
		"replay_id": "ColdRestoreTargetedLedgerReplayV1",
		"targeted_ledger_replay_mode": true,
		"canonical_valid": false,
		"canonical_reason_code": reason_code,
		"binding_check_count": 0,
		"binding_pass_count": 0,
		"binding_failure_count": 1,
		"replay_diagnostic_count_delta": 0,
		"replay_quota_claim_count": 0,
		"replay_session_create_count": 0,
		"replay_save_write_count": 0,
		"replay_owner_capture_count": 0,
	}


func _finish(result: Dictionary) -> void:
	print("COLD_RESTORE_TARGETED_LEDGER_REPLAY|%s" % JSON.stringify(result))
	quit(0 if bool(result.get("canonical_valid", false)) else 1)
