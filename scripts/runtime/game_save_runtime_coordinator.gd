@tool
extends Node
class_name GameSaveRuntimeCoordinator

const CURRENT_SAVE_VERSION := 3
const RULESET_ID := "v0.6"
const CURRENCY_SCALE := 100
const DEFAULT_SAVE_PATH := "user://saves/v06/current_run.save"
const PRODUCTION_SAVE_PATH := DEFAULT_SAVE_PATH
const QA_SAVE_ROOT := "user://test_runs/"
const FORMAT_ID := "space_syndicate_json"
const QA_FAILURE_STAGES := ["before_temp_write", "after_temp_write", "after_readback", "before_replace", "after_destination_swap", "backup_failure", "directory_failure"]

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
var _last_readback_validation_reason := ""
var _last_readback_fingerprint_match := true
var _last_readback_mismatch_sections: Array[String] = []
var _last_readback_mismatch_fields: Dictionary = {}
var _last_readback_first_mismatch: Dictionary = {}


func _ready() -> void:
	configure()


func configure(configured_save_version: int = CURRENT_SAVE_VERSION, configured_default_save_path: String = DEFAULT_SAVE_PATH) -> void:
	_save_version = configured_save_version
	var configured_path := configured_default_save_path.strip_edges()
	_default_save_path = _qa_default_save_path_override if not _qa_default_save_path_override.is_empty() else configured_path
	var explicit_path_valid := _is_allowed_save_path(_default_save_path)
	_configured = _save_version == CURRENT_SAVE_VERSION and explicit_path_valid and _handshake_api_ready()


func set_qa_default_save_path_override(path: String) -> bool:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		_qa_default_save_path_override = ""
		_default_save_path = PRODUCTION_SAVE_PATH
		return true
	if not _is_qa_save_path(normalized):
		return false
	_qa_default_save_path_override = normalized
	_default_save_path = normalized
	return true


func clear_qa_default_save_path_override() -> void:
	_qa_default_save_path_override = ""
	_default_save_path = PRODUCTION_SAVE_PATH


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
	if not _is_allowed_save_path(resolved_path):
		return {"allowed": false, "reason_code": "save_path_not_allowed"}
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("write_authorization"):
		return {"allowed": false, "reason_code": "save_handshake_unavailable"}
	var existing := _existing_authorization_header(resolved_path)
	var value_variant: Variant = handshake.call("write_authorization", existing, envelope, options)
	var authorization: Dictionary = (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}
	var qa_failure_stage := str(options.get("qa_failure_stage", ""))
	if _is_qa_save_path(resolved_path) and QA_FAILURE_STAGES.has(qa_failure_stage):
		authorization["qa_failure_stage"] = qa_failure_stage
	return authorization


func write_validated_envelope(path: String, envelope: Dictionary, authorization: Dictionary) -> Dictionary:
	var resolved_path := resolved_save_path(path)
	if not _configured:
		return _receipt("write", false, "save_coordinator_unconfigured", ERR_UNCONFIGURED, resolved_path)
	if not _is_allowed_save_path(resolved_path):
		return _receipt("write", false, "save_path_not_allowed", ERR_INVALID_PARAMETER, resolved_path)
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
	var failure_stage := str(authorization.get("qa_failure_stage", ""))
	if failure_stage == "directory_failure":
		return _receipt("write", false, "qa_injected_directory_failure", ERR_CANT_CREATE, resolved_path, write_id, fingerprint)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return _receipt("write", false, "save_directory_create_failed", directory_error, resolved_path, write_id, fingerprint)
	var suffix := _safe_suffix(write_id)
	var temp_path := "%s.tmp-%s" % [resolved_path, suffix]
	var swap_path := "%s.swap-%s" % [resolved_path, suffix]
	_cleanup_file(temp_path)
	if FileAccess.file_exists(swap_path):
		return _receipt("write", false, "stale_atomic_swap_present", ERR_ALREADY_EXISTS, resolved_path, write_id, fingerprint)
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
	_last_readback_validation_reason = str(temp_validation.get("reason_code", "temporary_document_parse_failed"))
	_last_readback_fingerprint_match = str(temp_validation.get("fingerprint", "")) == fingerprint
	_last_readback_mismatch_sections = _mismatched_section_fingerprints(envelope, temp_read.get("document", {}) as Dictionary, handshake)
	_last_readback_mismatch_fields = _mismatched_section_fields(envelope, temp_read.get("document", {}) as Dictionary, handshake, _last_readback_mismatch_sections)
	_last_readback_first_mismatch = _first_canonical_mismatch(envelope, temp_read.get("document", {}) as Dictionary, handshake)
	if not bool(temp_read.get("parsed", false)) or not bool(temp_validation.get("valid", false)) or str(temp_validation.get("fingerprint", "")) != fingerprint:
		_cleanup_file(temp_path)
		return _receipt("write", false, "temporary_readback_validation_failed", ERR_INVALID_DATA, resolved_path, write_id, fingerprint)
	if failure_stage == "after_readback":
		_cleanup_file(temp_path)
		return _receipt("write", false, "qa_injected_after_readback", ERR_INVALID_DATA, resolved_path, write_id, fingerprint)
	var backup_path := ""
	var backup_created := false
	if FileAccess.file_exists(resolved_path) and bool(authorization.get("requires_backup", false)):
		if failure_stage == "backup_failure":
			_cleanup_file(temp_path)
			return _receipt("write", false, "qa_injected_backup_failure", ERR_CANT_CREATE, resolved_path, write_id, fingerprint)
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
	if not _is_allowed_save_path(resolved_path):
		return _read_result(false, "save_path_not_allowed", ERR_INVALID_PARAMETER, resolved_path)
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
	elif source is String and _is_allowed_save_path(str(source)):
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


func public_slot_summary(path: String = "") -> Dictionary:
	var resolved_path := resolved_save_path(path)
	var empty := {
		"slot_state": "empty",
		"backup_available": false,
		"saved_at_unix": 0,
		"world_time_seconds": 0,
		"seat_count": 0,
		"ruleset_id": "",
		"mission_title": "",
		"session_state": "idle",
	}
	if not _is_allowed_save_path(resolved_path):
		empty["slot_state"] = "unavailable"
		return empty
	empty["backup_available"] = _backup_available(resolved_path)
	if not FileAccess.file_exists(resolved_path):
		return empty
	var result := read_and_validate(resolved_path)
	if not bool(result.get("ok", false)):
		empty["slot_state"] = "corrupt" if str(result.get("classification", "")) == "corrupt" else "unavailable"
		return empty
	var envelope: Dictionary = result.get("envelope", {}) if result.get("envelope", {}) is Dictionary else {}
	var metadata := _public_metadata_from_envelope(envelope)
	if metadata.is_empty():
		empty["slot_state"] = "corrupt"
		return empty
	metadata["slot_state"] = "ready"
	metadata["backup_available"] = _backup_available(resolved_path)
	metadata["saved_at_unix"] = int(FileAccess.get_modified_time(resolved_path))
	return metadata


func extract_section(envelope: Dictionary, section_id: String) -> Variant:
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	var value: Variant = sections.get(section_id)
	return value.duplicate(true) if value is Dictionary or value is Array else value


func build_save_summary(payload: Dictionary, _scoring_rules: Dictionary) -> Dictionary:
	var validation := validate_envelope(payload)
	var summary := _public_metadata_from_envelope(payload) if bool(validation.get("valid", false)) else {}
	summary["valid"] = bool(validation.get("valid", false))
	return summary


func operation_snapshot() -> Dictionary:
	return {
		"configured": _configured,
		"format": FORMAT_ID,
		"save_version": _save_version,
		"ruleset_id": RULESET_ID,
		"currency_scale": CURRENCY_SCALE,
		"default_save_path": _default_save_path,
		"explicit_path_required": false,
		"production_save_path": PRODUCTION_SAVE_PATH,
		"production_single_slot": true,
		"qa_save_path_override_active": not _qa_default_save_path_override.is_empty(),
		"qa_save_root": QA_SAVE_ROOT,
		"last_operation": _last_operation,
		"operation_state": _last_operation_state,
		"last_reason_code": _last_reason_code,
		"last_error_code": _last_error_code,
		"last_path": _last_path,
		"operation_sequence": _operation_sequence,
		"last_readback_validation_reason": _last_readback_validation_reason,
		"last_readback_fingerprint_match": _last_readback_fingerprint_match,
		"last_readback_mismatch_sections": _last_readback_mismatch_sections.duplicate(),
		"last_readback_mismatch_fields": _last_readback_mismatch_fields.duplicate(true),
		"last_readback_first_mismatch": _last_readback_first_mismatch.duplicate(true),
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


func _mismatched_section_fingerprints(original: Dictionary, parsed: Dictionary, handshake: Node) -> Array[String]:
	var result: Array[String] = []
	if handshake == null or not handshake.has_method("canonical_json"):
		return result
	var original_sections: Dictionary = original.get("sections", {}) if original.get("sections", {}) is Dictionary else {}
	var parsed_sections: Dictionary = parsed.get("sections", {}) if parsed.get("sections", {}) is Dictionary else {}
	var section_ids: Array = original_sections.keys()
	section_ids.sort()
	for section_id_variant in section_ids:
		var section_id := str(section_id_variant)
		if str(handshake.call("canonical_json", original_sections.get(section_id_variant))) \
				!= str(handshake.call("canonical_json", parsed_sections.get(section_id))):
			result.append(section_id)
	return result


func _mismatched_section_fields(original: Dictionary, parsed: Dictionary, handshake: Node, section_ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	if handshake == null or not handshake.has_method("canonical_json"):
		return result
	var original_sections: Dictionary = original.get("sections", {}) if original.get("sections", {}) is Dictionary else {}
	var parsed_sections: Dictionary = parsed.get("sections", {}) if parsed.get("sections", {}) is Dictionary else {}
	for section_id in section_ids:
		var original_wrapper: Dictionary = original_sections.get(section_id, {}) if original_sections.get(section_id, {}) is Dictionary else {}
		var parsed_wrapper: Dictionary = parsed_sections.get(section_id, {}) if parsed_sections.get(section_id, {}) is Dictionary else {}
		var original_state: Dictionary = original_wrapper.get("owner_state", {}) if original_wrapper.get("owner_state", {}) is Dictionary else {}
		var parsed_state: Dictionary = parsed_wrapper.get("owner_state", {}) if parsed_wrapper.get("owner_state", {}) is Dictionary else {}
		var mismatches: Array[String] = []
		var field_names: Array = original_state.keys()
		field_names.sort()
		for field_variant in field_names:
			var field := str(field_variant)
			if str(handshake.call("canonical_json", original_state.get(field_variant))) \
					!= str(handshake.call("canonical_json", parsed_state.get(field))):
				var original_field: Variant = original_state.get(field_variant)
				var parsed_field: Variant = parsed_state.get(field)
				if original_field is Dictionary and parsed_field is Dictionary:
					var child_names: Array = (original_field as Dictionary).keys()
					child_names.sort()
					for child_variant in child_names:
						var child := str(child_variant)
						if str(handshake.call("canonical_json", (original_field as Dictionary).get(child_variant))) \
								!= str(handshake.call("canonical_json", (parsed_field as Dictionary).get(child))):
							mismatches.append("%s.%s" % [field, child])
				else:
					mismatches.append(field)
		result[section_id] = mismatches
	return result


func _first_canonical_mismatch(left: Variant, right: Variant, handshake: Node, path := "root", depth := 0) -> Dictionary:
	if handshake == null or not handshake.has_method("canonical_json") \
			or str(handshake.call("canonical_json", left)) == str(handshake.call("canonical_json", right)):
		return {}
	if depth < 20 and left is Dictionary and right is Dictionary:
		var left_dictionary := left as Dictionary
		var right_dictionary := right as Dictionary
		var keys: Array[String] = []
		for key_variant in left_dictionary.keys():
			var key := str(key_variant)
			if not keys.has(key):
				keys.append(key)
		for key_variant in right_dictionary.keys():
			var key := str(key_variant)
			if not keys.has(key):
				keys.append(key)
		keys.sort()
		for key in keys:
			var child := _first_canonical_mismatch(left_dictionary.get(key), right_dictionary.get(key), handshake, "%s.%s" % [path, key], depth + 1)
			if not child.is_empty():
				return child
	if depth < 20 and left is Array and right is Array:
		var size := maxi((left as Array).size(), (right as Array).size())
		for index in range(size):
			var left_item: Variant = (left as Array)[index] if index < (left as Array).size() else null
			var right_item: Variant = (right as Array)[index] if index < (right as Array).size() else null
			var child := _first_canonical_mismatch(left_item, right_item, handshake, "%s[%d]" % [path, index], depth + 1)
			if not child.is_empty():
				return child
	return {
		"path": path,
		"left_type": type_string(typeof(left)),
		"right_type": type_string(typeof(right)),
		"left_scalar": _safe_scalar_diagnostic(left),
		"right_scalar": _safe_scalar_diagnostic(right),
	}


func _safe_scalar_diagnostic(value: Variant) -> String:
	if value == null or value is bool or value is int or value is float:
		return str(value)
	if value is String or value is StringName:
		return "string:%d:%s" % [str(value).length(), str(value).sha256_text().substr(0, 12)]
	return type_string(typeof(value))


func _safe_suffix(value: String) -> String:
	var result := ""
	for character in value:
		result += character if character.is_valid_identifier() or character.is_valid_int() or character in ["-", "."] else "_"
	return result.substr(0, 96)


func _is_qa_save_path(path: String) -> bool:
	return path.begins_with(QA_SAVE_ROOT) and path.ends_with(".save") and not path.contains("..") and not path.contains("\\")


func _is_allowed_save_path(path: String) -> bool:
	return path == PRODUCTION_SAVE_PATH or _is_qa_save_path(path)


func _public_metadata_from_envelope(envelope: Dictionary) -> Dictionary:
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections", {}) is Dictionary else {}
	var session_wrapper: Dictionary = sections.get("session", {}) if sections.get("session", {}) is Dictionary else {}
	var handshake := _handshake_node()
	if handshake == null or not handshake.has_method("decode_codec_value"):
		return {}
	var decoded_variant: Variant = handshake.call("decode_codec_value", session_wrapper.get("owner_state"))
	var decoded: Dictionary = decoded_variant if decoded_variant is Dictionary else {}
	if not bool(decoded.get("ok", false)) or not (decoded.get("value") is Dictionary):
		return {}
	var session_state := decoded.get("value", {}) as Dictionary
	var runtime_state: Dictionary = session_state.get("game_session_runtime", {}) \
		if session_state.get("game_session_runtime", {}) is Dictionary else {}
	var world_state: Dictionary = session_state.get("world_session_state", {}) \
		if session_state.get("world_session_state", {}) is Dictionary else {}
	var setup: Dictionary = runtime_state.get("setup", {}) if runtime_state.get("setup", {}) is Dictionary else {}
	var players: Array = world_state.get("players", []) if world_state.get("players", []) is Array else []
	var title := _safe_public_summary_title(str(setup.get("mission_title", setup.get("scenario_title", ""))))
	return {
		"slot_state": "ready",
		"backup_available": false,
		"saved_at_unix": 0,
		"world_time_seconds": maxi(0, int(round(float(runtime_state.get("world_effective_us", 0)) / 1_000_000.0))),
		"seat_count": players.size(),
		"ruleset_id": str(runtime_state.get("ruleset_id", envelope.get("ruleset_id", ""))),
		"mission_title": title,
		"session_state": str(runtime_state.get("session_state", "idle")),
	}


func _safe_public_summary_title(value: String) -> String:
	var normalized := value.strip_edges()
	if normalized.is_empty() or normalized.length() > 96 or normalized.contains("|") or normalized.contains("｜"):
		return ""
	for index in range(normalized.length()):
		var code := normalized.unicode_at(index)
		if code < 32 or code == 127:
			return ""
	return normalized


func _backup_available(path: String) -> bool:
	if path.is_empty():
		return false
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null:
		return false
	var prefix := "%s.backup-" % path.get_file()
	for file_name in directory.get_files():
		if str(file_name).begins_with(prefix) and str(file_name).ends_with(".save"):
			return true
	return false


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
