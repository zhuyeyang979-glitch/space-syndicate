extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const EVIDENCE_ROOT := "res://.godot/cold_restore_attestation_v1"
const ROLES := ["qualification", "producer", "consumer", "validator"]
const FIELDS := [
	"schema_version",
	"run_id",
	"role",
	"repository_head",
	"scenario_fingerprint",
	"official",
	"formal",
	"qualification_completed",
	"qualification_green",
	"product_blocker",
	"queue_count",
	"queue_revision",
	"queue_trigger_actor",
	"queue_trigger_semantic_action_id",
	"queue_trigger_card_semantic_id",
	"queue_trigger_target_fingerprint",
	"save_written",
	"official_count_consumed",
	"product_mutation_count",
	"direct_authority_mutation_count",
	"queue_injection_count",
	"final_reason_code",
	"evidence_fingerprint",
	"child_ready_to_exit",
]


static func completion_path(run_id: String, role: String) -> String:
	return "%s/%s/child/%s.completion.json" % [EVIDENCE_ROOT, run_id, role]


static func result_path(run_id: String, role: String) -> String:
	return "%s/%s/child/%s.result.json" % [EVIDENCE_ROOT, run_id, role]


static func build(source: Dictionary) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"run_id": str(source.get("run_id", "")),
		"role": str(source.get("role", "")),
		"repository_head": str(source.get("repository_head", "")),
		"scenario_fingerprint": str(source.get("scenario_fingerprint", "")),
		"official": bool(source.get("official", false)),
		"formal": bool(source.get("formal", false)),
		"qualification_completed": bool(source.get("qualification_completed", false)),
		"qualification_green": bool(source.get("qualification_green", false)),
		"product_blocker": str(source.get("product_blocker", "")),
		"queue_count": maxi(0, int(source.get("queue_count", 0))),
		"queue_revision": maxi(0, int(source.get("queue_revision", 0))),
		"queue_trigger_actor": str(source.get("queue_trigger_actor", "none")),
		"queue_trigger_semantic_action_id": str(source.get("queue_trigger_semantic_action_id", "")),
		"queue_trigger_card_semantic_id": str(source.get("queue_trigger_card_semantic_id", "")),
		"queue_trigger_target_fingerprint": str(source.get("queue_trigger_target_fingerprint", "")),
		"save_written": bool(source.get("save_written", false)),
		"official_count_consumed": bool(source.get("official_count_consumed", false)),
		"product_mutation_count": maxi(0, int(source.get("product_mutation_count", 0))),
		"direct_authority_mutation_count": maxi(0, int(source.get("direct_authority_mutation_count", 0))),
		"queue_injection_count": maxi(0, int(source.get("queue_injection_count", 0))),
		"final_reason_code": str(source.get("final_reason_code", "")),
		"child_ready_to_exit": bool(source.get("child_ready_to_exit", true)),
	}
	return SEMANTIC_WIRE.sealed_copy(unsealed, "evidence_fingerprint")


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"valid": false, "reason_code": "child_attestation_not_dictionary"}
	var attestation := value as Dictionary
	if attestation.size() != FIELDS.size():
		return {"valid": false, "reason_code": "child_attestation_field_set_invalid"}
	for field_variant in FIELDS:
		if not attestation.has(str(field_variant)):
			return {"valid": false, "reason_code": "child_attestation_field_set_invalid"}
	if int(attestation.get("schema_version", 0)) != SCHEMA_VERSION:
		return {"valid": false, "reason_code": "child_attestation_schema_invalid"}
	if not _safe_run_id(str(attestation.get("run_id", ""))):
		return {"valid": false, "reason_code": "child_attestation_run_id_invalid"}
	if str(attestation.get("role", "")) not in ROLES:
		return {"valid": false, "reason_code": "child_attestation_role_invalid"}
	if not _lower_hex(str(attestation.get("repository_head", "")), 40, 64):
		return {"valid": false, "reason_code": "child_attestation_repository_head_invalid"}
	var scenario_fingerprint := str(attestation.get("scenario_fingerprint", ""))
	if not scenario_fingerprint.is_empty() and not _lower_hex(scenario_fingerprint, 64, 64):
		return {"valid": false, "reason_code": "child_attestation_scenario_fingerprint_invalid"}
	for flag in [
		"official",
		"formal",
		"qualification_completed",
		"qualification_green",
		"save_written",
		"official_count_consumed",
		"child_ready_to_exit",
	]:
		if not (attestation.get(flag) is bool):
			return {"valid": false, "reason_code": "child_attestation_boolean_invalid"}
	for count_field in [
		"queue_count",
		"queue_revision",
		"product_mutation_count",
		"direct_authority_mutation_count",
		"queue_injection_count",
	]:
		if not (attestation.get(count_field) is int) or int(attestation.get(count_field, -1)) < 0:
			return {"valid": false, "reason_code": "child_attestation_integer_invalid"}
	if str(attestation.get("queue_trigger_actor", "")) not in ["local", "ai", "none"]:
		return {"valid": false, "reason_code": "child_attestation_actor_invalid"}
	for text_field in [
		"product_blocker",
		"queue_trigger_semantic_action_id",
		"queue_trigger_card_semantic_id",
		"final_reason_code",
	]:
		if str(attestation.get(text_field, "")).length() > 256:
			return {"valid": false, "reason_code": "child_attestation_text_invalid"}
	var target_fingerprint := str(attestation.get("queue_trigger_target_fingerprint", ""))
	if not target_fingerprint.is_empty() and not _lower_hex(target_fingerprint, 64, 64):
		return {"valid": false, "reason_code": "child_attestation_target_fingerprint_invalid"}
	if not bool(attestation.get("qualification_completed", false)):
		return {"valid": false, "reason_code": "child_attestation_qualification_incomplete"}
	if bool(attestation.get("qualification_green", false)) \
			and not str(attestation.get("product_blocker", "")).is_empty():
		return {"valid": false, "reason_code": "child_attestation_green_blocker_conflict"}
	if not bool(attestation.get("qualification_green", false)) \
			and str(attestation.get("product_blocker", "")).is_empty():
		return {"valid": false, "reason_code": "child_attestation_blocker_missing"}
	if not bool(attestation.get("child_ready_to_exit", false)):
		return {"valid": false, "reason_code": "child_attestation_not_ready_to_exit"}
	var expected_fingerprint := SEMANTIC_WIRE.fingerprint(attestation, "evidence_fingerprint")
	if expected_fingerprint.is_empty() \
			or str(attestation.get("evidence_fingerprint", "")) != expected_fingerprint:
		return {"valid": false, "reason_code": "child_attestation_fingerprint_invalid"}
	return {
		"valid": true,
		"reason_code": "ok",
		"evidence_fingerprint": expected_fingerprint,
	}


static func write_completion(attestation: Dictionary) -> Dictionary:
	var validation := validation_report(attestation)
	if not bool(validation.get("valid", false)):
		return validation
	return _write_atomic_json(
		completion_path(str(attestation.get("run_id", "")), str(attestation.get("role", ""))),
		attestation
	)


static func write_result(run_id: String, role: String, result: Dictionary) -> Dictionary:
	if not _safe_run_id(run_id) or role not in ROLES or not SEMANTIC_WIRE.is_closed_data(result):
		return {"valid": false, "reason_code": "child_result_invalid"}
	return _write_atomic_json(result_path(run_id, role), result)


static func _write_atomic_json(path: String, value: Dictionary) -> Dictionary:
	var canonical := SEMANTIC_WIRE.canonical_json(value)
	if canonical.is_empty():
		return {"valid": false, "reason_code": "child_evidence_serialization_failed"}
	var absolute_path := ProjectSettings.globalize_path(path)
	var temp_path := "%s.tmp.%d" % [absolute_path, OS.get_process_id()]
	if FileAccess.file_exists(absolute_path) or FileAccess.file_exists(temp_path):
		return {"valid": false, "reason_code": "child_evidence_collision"}
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if directory_error != OK:
		return {"valid": false, "reason_code": "child_evidence_directory_failed"}
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"valid": false, "reason_code": "child_attestation_write_failed"}
	file.store_string(canonical)
	file.flush()
	file.close()
	var temp_readback := _read_text(temp_path)
	if temp_readback != canonical:
		_remove_if_present(temp_path)
		return {
			"valid": false,
			"reason_code": "child_attestation_readback_failed",
			"expected_length": canonical.length(),
			"actual_length": temp_readback.length(),
			"open_error": FileAccess.get_open_error(),
		}
	var parsed_temp: Variant = JSON.parse_string(temp_readback)
	var normalized_temp: Variant = _normalize_json_value(parsed_temp)
	var parsed_canonical := SEMANTIC_WIRE.canonical_json(normalized_temp) \
		if parsed_temp is Dictionary else ""
	if not (parsed_temp is Dictionary) or parsed_canonical != canonical:
		_remove_if_present(temp_path)
		return {
			"valid": false,
			"reason_code": "child_attestation_readback_failed",
			"expected_length": canonical.length(),
			"actual_length": parsed_canonical.length(),
			"parsed_type": typeof(parsed_temp),
		}
	var rename_error := DirAccess.rename_absolute(temp_path, absolute_path)
	if rename_error != OK:
		_remove_if_present(temp_path)
		return {"valid": false, "reason_code": "child_attestation_atomic_replace_failed"}
	var final_readback := _read_text(absolute_path)
	if final_readback != canonical:
		return {"valid": false, "reason_code": "child_attestation_final_readback_failed"}
	return {
		"valid": true,
		"reason_code": "ok",
		"path": path,
		"sha256": canonical.sha256_text().to_lower(),
	}


static func _remove_if_present(absolute_path: String) -> void:
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


static func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


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
		var character := value.substr(index, 1)
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(character):
			return false
	return true


static func _lower_hex(value: String, minimum_length: int, maximum_length: int) -> bool:
	if value.length() < minimum_length or value.length() > maximum_length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
