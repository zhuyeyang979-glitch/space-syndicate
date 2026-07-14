@tool
extends Node
class_name GameSaveRuntimeCoordinator

const CURRENT_SAVE_VERSION := 3
const RULESET_ID := "v0.6"
const CURRENCY_SCALE := 100
const DEFAULT_SAVE_PATH := ""
const QA_SAVE_ROOT := "user://test_runs/"
const FORMAT_ID := "space_syndicate_json"
const QA_FAILURE_STAGES := ["before_temp_write", "after_temp_write", "after_readback", "before_replace", "after_destination_swap"]

var _save_version := CURRENT_SAVE_VERSION
var _default_save_path := DEFAULT_SAVE_PATH
var _qa_default_save_path_override := ""
var _configured := false
var _last_operation := "idle"
var _last_operation_state := "clean"
var _last_reason_code := "idle"
var _last_error_code: int = OK
var _last_path := ""
var _operation_sequence := 0


func _ready() -> void:
	configure()


func configure(configured_save_version: int = CURRENT_SAVE_VERSION, configured_default_save_path: String = DEFAULT_SAVE_PATH) -> void:
	_save_version = configured_save_version
	var configured_path := configured_default_save_path.strip_edges()
	_default_save_path = _qa_default_save_path_override if not _qa_default_save_path_override.is_empty() else configured_path
	var explicit_path_valid := _default_save_path.is_empty() or _is_qa_save_path(_default_save_path)
	_configured = _save_version == CURRENT_SAVE_VERSION and explicit_path_valid and _handshake_api_ready()


func set_qa_default_save_path_override(path: String) -> bool:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		_qa_default_save_path_override = ""
		_default_save_path = ""
		return true
	if not _is_qa_save_path(normalized):
		return false
	_qa_default_save_path_override = normalized
	_default_save_path = normalized
	return true


func clear_qa_default_save_path_override() -> void:
	_qa_default_save_path_override = ""
	_default_save_path = ""


func save_version() -> int:
	return _save_version


func default_save_path() -> String:
	return _default_save_path


func resolved_save_path(path: String = "") -> String:
	return _default_save_path if path.strip_edges().is_empty() else path.strip_edges()


func validate_envelope(envelope: Dictionary) -> Dictionary:
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("validate_envelope"):
		return {"valid": false, "reason_code": "save_handshake_unavailable", "errors": ["save_handshake_unavailable"]}
	var result_variant: Variant = handshake.call("validate_envelope", envelope)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {"valid": false, "reason_code": "save_validation_invalid", "errors": ["save_validation_invalid"]}


func write_authorization(path: String, envelope: Dictionary, options: Dictionary = {}) -> Dictionary:
	var resolved_path := resolved_save_path(path)
	if not _is_qa_save_path(resolved_path):
		return {"allowed": false, "reason_code": "explicit_qa_save_path_required"}
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("write_authorization"):
		return {"allowed": false, "reason_code": "save_handshake_unavailable"}
	var existing := _existing_authorization_header(resolved_path)
	var value_variant: Variant = handshake.call("write_authorization", existing, envelope, options)
	var authorization: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	var qa_failure_stage := str(options.get("qa_failure_stage", ""))
	if QA_FAILURE_STAGES.has(qa_failure_stage):
		authorization["qa_failure_stage"] = qa_failure_stage
	return authorization


func write_validated_envelope(path: String, envelope: Dictionary, authorization: Dictionary) -> Dictionary:
	var resolved_path := resolved_save_path(path)
	if not _configured:
		return _receipt("write", false, "save_coordinator_unconfigured", ERR_UNCONFIGURED, resolved_path)
	if not _is_qa_save_path(resolved_path):
		return _receipt("write", false, "explicit_qa_save_path_required", ERR_INVALID_PARAMETER, resolved_path)
	var validation := validate_envelope(envelope)
	if not bool(validation.get("valid", false)):
		return _receipt("write", false, str(validation.get("reason_code", "envelope_invalid")), ERR_INVALID_DATA, resolved_path)
	var handshake := _handshake_node()
	var existing := _existing_authorization_header(resolved_path)
	if handshake == null or not handshake.has_method("authorization_matches") or not bool(handshake.call("authorization_matches", existing, envelope, authorization)):
		return _receipt("write", false, "write_authorization_invalid", ERR_UNAUTHORIZED, resolved_path)
	var write_id := str(envelope.get("write_id", ""))
	var fingerprint := str(validation.get("fingerprint", ""))
	if bool(authorization.get("idempotent", false)):
		var idempotent_receipt := _receipt("write", true, "idempotent_replay", OK, resolved_path, write_id, fingerprint)
		idempotent_receipt["idempotent"] = true
		return idempotent_receipt
	var absolute_path := ProjectSettings.globalize_path(resolved_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return _receipt("write", false, "save_directory_create_failed", directory_error, resolved_path, write_id, fingerprint)
	var suffix := _safe_suffix(write_id)
	var temp_path := "%s.tmp-%s" % [resolved_path, suffix]
	var swap_path := "%s.swap-%s" % [resolved_path, suffix]
	_cleanup_file(temp_path)
	if FileAccess.file_exists(swap_path):
		return _receipt("write", false, "stale_atomic_swap_present", ERR_ALREADY_EXISTS, resolved_path, write_id, fingerprint)
	var failure_stage := str(authorization.get("qa_failure_stage", ""))
	if failure_stage == "before_temp_write":
		return _receipt("write", false, "qa_injected_before_temp_write", ERR_CANT_CREATE, resolved_path, write_id, fingerprint)
	var canonical := str(handshake.call("canonical_json", envelope))
	var temp_error := _write_text_file(temp_path, canonical)
	if temp_error != OK:
		_cleanup_file(temp_path)
		return _receipt("write", false, "temporary_write_failed", temp_error, resolved_path, write_id, fingerprint)
	if failure_stage == "after_temp_write":
		_cleanup_file(temp_path)
		return _receipt("write", false, "qa_injected_after_temp_write", ERR_CANT_CREATE, resolved_path, write_id, fingerprint)
	var temp_read := _read_document(temp_path)
	var temp_validation: Dictionary = validate_envelope(temp_read.get("document", {}) as Dictionary) if bool(temp_read.get("parsed", false)) else {}
	if not bool(temp_read.get("parsed", false)) or not bool(temp_validation.get("valid", false)) or str(temp_validation.get("fingerprint", "")) != fingerprint:
		_cleanup_file(temp_path)
		return _receipt("write", false, "temporary_readback_validation_failed", ERR_INVALID_DATA, resolved_path, write_id, fingerprint)
	if failure_stage == "after_readback":
		_cleanup_file(temp_path)
		return _receipt("write", false, "qa_injected_after_readback", ERR_INVALID_DATA, resolved_path, write_id, fingerprint)
	var backup_path := ""
	var backup_created := false
	if FileAccess.file_exists(resolved_path) and bool(authorization.get("requires_backup", false)):
		backup_path = "%s.backup-%s.save" % [resolved_path, str(authorization.get("existing_fingerprint", "unknown")).substr(0, 16)]
		var backup_result := _ensure_backup(resolved_path, backup_path)
		if not bool(backup_result.get("ok", false)):
			_cleanup_file(temp_path)
			return _receipt("write", false, "legacy_backup_failed", int(backup_result.get("error_code", ERR_CANT_CREATE)), resolved_path, write_id, fingerprint)
		backup_created = bool(backup_result.get("created", false))
	if failure_stage == "before_replace":
		_cleanup_file(temp_path)
		return _receipt("write", false, "qa_injected_before_replace", ERR_CANT_CREATE, resolved_path, write_id, fingerprint)
	var replace_result := _atomic_replace(temp_path, resolved_path, swap_path, failure_stage)
	if not bool(replace_result.get("ok", false)):
		_cleanup_file(temp_path)
		return _receipt("write", false, str(replace_result.get("reason_code", "atomic_replace_failed")), int(replace_result.get("error_code", ERR_CANT_CREATE)), resolved_path, write_id, fingerprint)
	var final_read := _read_document(resolved_path)
	var final_validation: Dictionary = validate_envelope(final_read.get("document", {}) as Dictionary) if bool(final_read.get("parsed", false)) else {}
	if not bool(final_validation.get("valid", false)) or str(final_validation.get("fingerprint", "")) != fingerprint:
		_cleanup_file(resolved_path)
		if bool(replace_result.get("had_destination", false)) and FileAccess.file_exists(swap_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(swap_path), ProjectSettings.globalize_path(resolved_path))
		return _receipt("write", false, "post_replace_validation_failed", ERR_INVALID_DATA, resolved_path, write_id, fingerprint)
	if FileAccess.file_exists(swap_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(swap_path))
	var receipt := _receipt("write", true, "written", OK, resolved_path, write_id, fingerprint)
	receipt["idempotent"] = false
	receipt["backup_created"] = backup_created
	receipt["backup_path"] = backup_path
	return receipt


func read_and_validate(path: String) -> Dictionary:
	var resolved_path := resolved_save_path(path)
	if not _configured:
		return _read_result(false, "save_coordinator_unconfigured", ERR_UNCONFIGURED, resolved_path)
	if not _is_qa_save_path(resolved_path):
		return _read_result(false, "explicit_qa_save_path_required", ERR_INVALID_PARAMETER, resolved_path)
	if not FileAccess.file_exists(resolved_path):
		return _read_result(false, "save_not_found", ERR_FILE_NOT_FOUND, resolved_path)
	var raw := _read_document(resolved_path)
	if not bool(raw.get("parsed", false)):
		var corrupt_result := _read_result(false, "save_corrupt_or_truncated", ERR_INVALID_DATA, resolved_path)
		corrupt_result["classification"] = "corrupt"
		corrupt_result["requires_backup"] = true
		return corrupt_result
	var document: Dictionary = raw.get("document", {})
	var handshake := _handshake_node()
	var inspection: Dictionary = handshake.call("inspect_envelope", document, RULESET_ID) as Dictionary
	if not bool(inspection.get("can_resume", false)):
		var rejected := _read_result(false, str(inspection.get("reason_code", "resume_rejected")), ERR_INVALID_DATA, resolved_path)
		rejected["classification"] = str(inspection.get("classification", "unknown"))
		rejected["requires_backup"] = bool(inspection.get("requires_backup", true))
		return rejected
	var validation := validate_envelope(document)
	if not bool(validation.get("valid", false)):
		return _read_result(false, str(validation.get("reason_code", "envelope_invalid")), ERR_INVALID_DATA, resolved_path)
	var result := _read_result(true, "read_validated", OK, resolved_path)
	result["envelope"] = document.duplicate(true)
	result["fingerprint"] = str(validation.get("fingerprint", ""))
	result["classification"] = "v06"
	result["requires_backup"] = false
	return result


func inspect_legacy(source: Variant) -> Dictionary:
	var document: Dictionary = {}
	if source is Dictionary:
		document = (source as Dictionary).duplicate(true)
	elif source is String and _is_qa_save_path(str(source)):
		var read_result := _read_document(str(source))
		if bool(read_result.get("parsed", false)):
			document = (read_result.get("document", {}) as Dictionary).duplicate(true)
	if document.is_empty():
		return {"recognized": false, "classification": "corrupt", "can_resume": false, "requires_backup": true, "reason_code": "legacy_inspection_unavailable"}
	var handshake := _handshake_node()
	return (handshake.call("inspect_legacy", document) as Dictionary).duplicate(true)


func public_operation_receipt(receipt: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["operation", "ok", "reason_code", "error_code", "save_version", "ruleset_id", "write_id", "fingerprint", "idempotent", "backup_created"]:
		if receipt.has(key):
			result[key] = receipt[key]
	return result


# Legacy callers remain parse-compatible but cannot bypass the v3 handshake or
# write authorization. C16b should call the narrow v3 API directly.
func compose_save_payload(_session_payload: Dictionary, candidate: Dictionary) -> Dictionary:
	return candidate.duplicate(true) if bool(validate_envelope(candidate).get("valid", false)) else {}


func validate_save_payload(payload: Dictionary) -> Dictionary:
	return validate_envelope(payload)


func normalize_save_payload(payload: Dictionary) -> Dictionary:
	return payload.duplicate(true) if bool(validate_envelope(payload).get("valid", false)) else {}


func write_save(path: String, _payload: Dictionary) -> Dictionary:
	return _receipt("write", false, "write_authorization_required", ERR_UNAUTHORIZED, resolved_save_path(path))


func read_save(path: String = "") -> Dictionary:
	return read_and_validate(resolved_save_path(path))


func has_valid_save(path: String = "") -> bool:
	return bool(read_and_validate(resolved_save_path(path)).get("ok", false))


func extract_section(envelope: Dictionary, section_id: String) -> Variant:
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	var value: Variant = sections.get(section_id)
	return value.duplicate(true) if value is Dictionary or value is Array else value


func build_save_summary(payload: Dictionary, _scoring_rules: Dictionary) -> Dictionary:
	var validation := validate_envelope(payload)
	return {
		"valid": bool(validation.get("valid", false)),
		"save_version": CURRENT_SAVE_VERSION,
		"ruleset_id": RULESET_ID,
		"section_count": (payload.get("sections", {}) as Dictionary).size() if payload.get("sections", {}) is Dictionary else 0,
	}


func operation_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"format": FORMAT_ID,
		"save_version": _save_version,
		"ruleset_id": RULESET_ID,
		"currency_scale": CURRENCY_SCALE,
		"default_save_path": _default_save_path,
		"explicit_path_required": _default_save_path.is_empty(),
		"qa_save_path_override_active": not _qa_default_save_path_override.is_empty(),
		"qa_save_root": QA_SAVE_ROOT,
		"last_operation": _last_operation,
		"operation_state": _last_operation_state,
		"last_reason_code": _last_reason_code,
		"last_error_code": _last_error_code,
		"last_path": _last_path,
		"operation_sequence": _operation_sequence,
		"captures_business_state": false,
	}


func debug_snapshot() -> Dictionary:
	return operation_snapshot()


func _atomic_replace(temp_path: String, destination_path: String, swap_path: String, failure_stage: String) -> Dictionary:
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var destination_absolute := ProjectSettings.globalize_path(destination_path)
	var swap_absolute := ProjectSettings.globalize_path(swap_path)
	var had_destination := FileAccess.file_exists(destination_path)
	if had_destination:
		var park_error := DirAccess.rename_absolute(destination_absolute, swap_absolute)
		if park_error != OK:
			return {"ok": false, "reason_code": "atomic_park_existing_failed", "error_code": park_error}
		if failure_stage == "after_destination_swap":
			var restore_error := DirAccess.rename_absolute(swap_absolute, destination_absolute)
			return {"ok": false, "reason_code": "qa_injected_after_destination_swap" if restore_error == OK else "atomic_restore_failed", "error_code": ERR_CANT_CREATE if restore_error == OK else restore_error}
	var install_error := DirAccess.rename_absolute(temp_absolute, destination_absolute)
	if install_error != OK:
		if had_destination and FileAccess.file_exists(swap_path):
			DirAccess.rename_absolute(swap_absolute, destination_absolute)
		return {"ok": false, "reason_code": "atomic_install_failed", "error_code": install_error}
	return {"ok": true, "reason_code": "atomic_replace_complete", "error_code": OK, "had_destination": had_destination}


func _ensure_backup(source_path: String, backup_path: String) -> Dictionary:
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	if FileAccess.file_exists(backup_path):
		return {"ok": FileAccess.get_file_as_bytes(backup_path) == source_bytes, "created": false, "error_code": OK if FileAccess.get_file_as_bytes(backup_path) == source_bytes else ERR_ALREADY_EXISTS}
	var backup_temp := "%s.tmp" % backup_path
	_cleanup_file(backup_temp)
	var file := FileAccess.open(backup_temp, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "created": false, "error_code": FileAccess.get_open_error()}
	file.store_buffer(source_bytes)
	file.flush()
	file.close()
	if FileAccess.get_file_as_bytes(backup_temp) != source_bytes:
		_cleanup_file(backup_temp)
		return {"ok": false, "created": false, "error_code": ERR_INVALID_DATA}
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_temp), ProjectSettings.globalize_path(backup_path))
	if rename_error != OK:
		_cleanup_file(backup_temp)
		return {"ok": false, "created": false, "error_code": rename_error}
	return {"ok": true, "created": true, "error_code": OK}


func _existing_authorization_header(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var read_result := _read_document(path)
	if bool(read_result.get("parsed", false)):
		return (read_result.get("document", {}) as Dictionary).duplicate(true)
	return {
		"save_version": -1,
		"ruleset_id": "corrupt",
		"raw_fingerprint": _raw_file_fingerprint(path),
	}


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"parsed": false, "error_code": FileAccess.get_open_error(), "document": {}}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK or not (parser.data is Dictionary):
		return {"parsed": false, "error_code": ERR_PARSE_ERROR, "document": {}}
	return {"parsed": true, "error_code": OK, "document": (parser.data as Dictionary).duplicate(true)}


func _write_text_file(path: String, text: String) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	return OK


func _raw_file_fingerprint(path: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()


func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _receipt(operation: String, ok: bool, reason_code: String, error_code: int, path: String, write_id: String = "", fingerprint: String = "") -> Dictionary:
	_record_operation(operation, ok, reason_code, error_code, path)
	return {
		"operation": operation,
		"ok": ok,
		"reason_code": reason_code,
		"error_code": error_code,
		"path": path,
		"save_version": CURRENT_SAVE_VERSION,
		"ruleset_id": RULESET_ID,
		"write_id": write_id,
		"fingerprint": fingerprint,
	}


func _read_result(ok: bool, reason_code: String, error_code: int, path: String) -> Dictionary:
	_record_operation("read", ok, reason_code, error_code, path)
	return {
		"operation": "read",
		"ok": ok,
		"reason_code": reason_code,
		"error_code": error_code,
		"path": path,
		"save_version": CURRENT_SAVE_VERSION,
		"ruleset_id": RULESET_ID,
	}


func _record_operation(operation: String, ok: bool, reason_code: String, error_code: int, path: String) -> void:
	_operation_sequence += 1
	_last_operation = operation
	_last_operation_state = "clean" if ok else "failed"
	_last_reason_code = reason_code
	_last_error_code = error_code
	_last_path = path


func _safe_suffix(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.is_valid_identifier() or character.is_valid_int() or character in ["-", "."] else "_"
	return result.substr(0, 96)


func _is_qa_save_path(path: String) -> bool:
	return path.begins_with(QA_SAVE_ROOT) and path.ends_with(".save") and not path.contains("..") and not path.contains("\\")


func _handshake_api_ready() -> bool:
	var handshake := _handshake_node()
	return handshake != null \
		and handshake.has_method("validate_envelope") \
		and handshake.has_method("write_authorization") \
		and handshake.has_method("authorization_matches") \
		and handshake.has_method("inspect_envelope") \
		and handshake.has_method("canonical_json")


func _handshake_node() -> Node:
	return get_node_or_null("RulesetSaveHandshakeService")
