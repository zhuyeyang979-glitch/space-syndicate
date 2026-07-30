extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CAPTURE_FAILURE := preload("res://scripts/runtime/save_owner_capture_failure_v1.gd")

const SCHEMA_VERSION := 1
const EVIDENCE_ROOT := "res://.godot/cold_restore_attestation_v1"
const ROLES := ["qualification", "producer", "consumer", "validator"]
const TARGETED_OWNER_CAPTURE_SCENARIO_FINGERPRINT := "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
const TARGETED_OWNER_CAPTURE_PHASES := [
	"session_started",
	"real_commodity_claim_complete",
	"real_normal_card_purchase_complete",
	"real_facility_economy_complete",
	"first_sale_receipt_complete",
	"ai_nondefault_state_complete",
	"queue_entry_committed",
	"restore_barrier_entered",
]
const SAVE_SECTION_ORDER := [
	"ruleset", "region_infrastructure", "region_supply", "commodity_flow",
	"routes", "player_mana", "commodity_belt_visibility", "card_inventory",
	"player_organization", "monsters", "military", "weather",
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
	"ai", "bankruptcy_neutral_estate", "victory_control", "session",
]
const SAVE_OWNER_ORDER := [
	"ruleset_runtime", "public_facility_region", "region_supply", "commodity_flow",
	"route_network", "player_mana", "commodity_belt_visibility", "card_inventory",
	"player_organization", "monster_runtime", "military_runtime", "weather_runtime",
	"card_resolution_queue", "card_resolution_execution", "card_resolution_history",
	"ai_runtime", "bankruptcy_neutral_estate", "victory_control", "game_session",
]
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
const OWNER_CAPTURE_DIAGNOSTIC_FIELDS := [
	"schema_version", "diagnostic_id", "run_id", "repository_head",
	"scenario_fingerprint", "official", "formal", "challenge_depth", "seed",
	"local_player_count", "ai_player_count", "ai_action_count", "ai_state_digest_changed",
	"audit_count", "phase_audits",
	"first_phase_with_capture_failure", "first_failure", "safety_green",
	"save_file_exists", "official_claim_path_present",
]
const OWNER_CAPTURE_AUDIT_FIELDS := [
	"phase_id", "captured", "section_count", "section_results", "first_failure",
	"world_fingerprint_match", "safety_observation_match", "world_advance_delta",
	"rng_draw_delta", "public_log_delta", "private_feedback_delta",
	"sale_receipt_delta", "human_action_delta", "ai_action_delta",
	"notification_delta", "safety_green",
]
const OWNER_CAPTURE_SECTION_RESULT_FIELDS := [
	"section_id", "owner_id", "captured", "reason_code", "state_version",
	"payload_fingerprint",
]
const OWNER_CAPTURE_FAILURE_FIELDS := [
	"schema_version", "registry_operation_id", "capture_sequence", "section_index",
	"section_id", "owner_id", "failure_class", "reason_code", "result_empty",
	"result_not_dictionary", "result_not_pure_data", "result_header_invalid",
	"result_version_invalid", "result_ruleset_invalid", "state_version_observed",
	"ruleset_id_observed", "live_state_mutated_during_capture",
	"private_payload_redacted",
]


static func completion_path(run_id: String, role: String) -> String:
	return "%s/%s/child/%s.completion.json" % [EVIDENCE_ROOT, run_id, role]


static func result_path(run_id: String, role: String) -> String:
	return "%s/%s/child/%s.result.json" % [EVIDENCE_ROOT, run_id, role]


static func diagnostic_path(run_id: String, diagnostic_id: String) -> String:
	return "%s/%s/diagnostics/%s.json" % [EVIDENCE_ROOT, run_id, diagnostic_id]


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


static func write_owner_capture_diagnostic(run_id: String, result: Dictionary) -> Dictionary:
	if not _targeted_owner_capture_run_id(run_id) or not _valid_owner_capture_diagnostic(result):
		return {"valid": false, "reason_code": "child_diagnostic_invalid"}
	return _write_atomic_json(diagnostic_path(run_id, "owner_capture_audit"), result)


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


static func _safe_artifact_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if not "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			return false
	return true


static func _valid_owner_capture_diagnostic(value: Dictionary) -> bool:
	if not SEMANTIC_WIRE.is_closed_data(value) \
			or not _has_exact_fields(value, OWNER_CAPTURE_DIAGNOSTIC_FIELDS) \
			or typeof(value.get("schema_version")) != TYPE_INT \
			or int(value.get("schema_version", 0)) != 1 \
			or str(value.get("diagnostic_id", "")) != "TargetedOwnerCaptureDiagnosticV1" \
			or not _targeted_owner_capture_run_id(str(value.get("run_id", ""))) \
			or not _lower_hex(str(value.get("repository_head", "")), 40, 64) \
			or str(value.get("scenario_fingerprint", "")) != TARGETED_OWNER_CAPTURE_SCENARIO_FINGERPRINT \
			or not (value.get("official") is bool) or bool(value.get("official", true)) \
			or not (value.get("formal") is bool) or bool(value.get("formal", true)) \
			or not (value.get("safety_green") is bool) or not bool(value.get("safety_green", false)) \
			or not (value.get("save_file_exists") is bool) or bool(value.get("save_file_exists", true)) \
			or not (value.get("official_claim_path_present") is bool) or bool(value.get("official_claim_path_present", true)):
		return false
	if str(value.get("run_id", "")) != "alpha04c-owner-capture-diagnostic-%s" \
			% str(value.get("repository_head", "")).left(12):
		return false
	if typeof(value.get("challenge_depth")) != TYPE_INT or int(value.get("challenge_depth", -1)) != 1 \
			or typeof(value.get("seed")) != TYPE_INT or int(value.get("seed", -1)) != 900626424 \
			or typeof(value.get("local_player_count")) != TYPE_INT or int(value.get("local_player_count", -1)) != 1 \
			or typeof(value.get("ai_player_count")) != TYPE_INT or int(value.get("ai_player_count", -1)) != 3 \
			or typeof(value.get("ai_action_count")) != TYPE_INT or int(value.get("ai_action_count", 0)) < 1 \
			or not (value.get("ai_state_digest_changed") is bool) or not bool(value.get("ai_state_digest_changed", false)) \
			or typeof(value.get("audit_count")) != TYPE_INT or int(value.get("audit_count", -1)) != TARGETED_OWNER_CAPTURE_PHASES.size():
		return false
	var audits: Array = value.get("phase_audits", []) if value.get("phase_audits", []) is Array else []
	if audits.size() != TARGETED_OWNER_CAPTURE_PHASES.size():
		return false
	var observed_first_failure: Dictionary = {}
	var observed_first_phase := "none"
	for audit_index in range(audits.size()):
		var audit_variant: Variant = audits[audit_index]
		if not (audit_variant is Dictionary):
			return false
		var audit := audit_variant as Dictionary
		if str(audit.get("phase_id", "")) != str(TARGETED_OWNER_CAPTURE_PHASES[audit_index]) \
				or not _valid_owner_capture_audit(audit):
			return false
		var audit_failure: Dictionary = audit.get("first_failure", {}) \
				if audit.get("first_failure", {}) is Dictionary else {}
		if observed_first_failure.is_empty() and not audit_failure.is_empty():
			observed_first_failure = audit_failure.duplicate(true)
			observed_first_phase = str(audit.get("phase_id", ""))
	var first_failure: Dictionary = value.get("first_failure", {}) \
			if value.get("first_failure", {}) is Dictionary else {}
	return (first_failure.is_empty() or _valid_owner_capture_failure(first_failure)) \
			and first_failure == observed_first_failure \
			and str(value.get("first_phase_with_capture_failure", "")) == observed_first_phase


static func _valid_owner_capture_audit(audit: Dictionary) -> bool:
	if not _has_exact_fields(audit, OWNER_CAPTURE_AUDIT_FIELDS):
		return false
	for flag in ["captured", "world_fingerprint_match", "safety_observation_match", "safety_green"]:
		if not (audit.get(flag) is bool):
			return false
	for count_field in [
		"section_count", "world_advance_delta", "rng_draw_delta", "public_log_delta",
		"private_feedback_delta", "sale_receipt_delta", "human_action_delta",
		"ai_action_delta", "notification_delta",
	]:
		if typeof(audit.get(count_field)) != TYPE_INT:
			return false
	var results: Array = audit.get("section_results", []) if audit.get("section_results", []) is Array else []
	if int(audit.get("section_count", -1)) < 0 or int(audit.get("section_count", -1)) > SAVE_SECTION_ORDER.size() \
			or results.size() > SAVE_SECTION_ORDER.size():
		return false
	for result_index in range(results.size()):
		var result_variant: Variant = results[result_index]
		if not (result_variant is Dictionary) or not _has_exact_fields(result_variant as Dictionary, OWNER_CAPTURE_SECTION_RESULT_FIELDS):
			return false
		var result := result_variant as Dictionary
		if not (result.get("captured") is bool) or typeof(result.get("state_version")) != TYPE_INT \
				or str(result.get("section_id", "")) != str(SAVE_SECTION_ORDER[result_index]) \
				or str(result.get("owner_id", "")) != str(SAVE_OWNER_ORDER[result_index]) \
				or not CAPTURE_FAILURE.is_reason_code(str(result.get("reason_code", ""))):
			return false
		var fingerprint := str(result.get("payload_fingerprint", ""))
		if (bool(result.get("captured", false)) and not _lower_hex(fingerprint, 64, 64)) \
				or (not fingerprint.is_empty() and not _lower_hex(fingerprint, 64, 64)):
			return false
	var failure: Dictionary = audit.get("first_failure", {}) if audit.get("first_failure", {}) is Dictionary else {}
	if bool(audit.get("captured", false)):
		return int(audit.get("section_count", -1)) == SAVE_SECTION_ORDER.size() \
				and results.size() == SAVE_SECTION_ORDER.size() \
				and failure.is_empty() \
				and _all_section_results_captured(results)
	if failure.is_empty() or not _valid_owner_capture_failure(failure):
		return false
	var failure_index := int(failure.get("section_index", -1))
	if failure_index < 0 or failure_index >= SAVE_SECTION_ORDER.size() \
			or str(failure.get("section_id", "")) != str(SAVE_SECTION_ORDER[failure_index]) \
			or str(failure.get("owner_id", "")) != str(SAVE_OWNER_ORDER[failure_index]):
		return false
	var successful_count := int(audit.get("section_count", -1))
	if successful_count == SAVE_SECTION_ORDER.size():
		return results.size() == SAVE_SECTION_ORDER.size() and _all_section_results_captured(results)
	return results.size() == successful_count + 1 \
			and failure_index == successful_count \
			and _section_result_prefix_valid(results, successful_count, failure)


static func _valid_owner_capture_failure(failure: Dictionary) -> bool:
	if not _has_exact_fields(failure, OWNER_CAPTURE_FAILURE_FIELDS) \
			or typeof(failure.get("schema_version")) != TYPE_INT \
			or int(failure.get("schema_version", 0)) != 1 \
			or not CAPTURE_FAILURE.is_failure_class(str(failure.get("failure_class", ""))) \
			or not CAPTURE_FAILURE.is_reason_code(str(failure.get("reason_code", ""))) \
			or not bool(failure.get("private_payload_redacted", false)):
		return false
	for flag in [
		"result_empty", "result_not_dictionary", "result_not_pure_data",
		"result_header_invalid", "result_version_invalid", "result_ruleset_invalid",
		"live_state_mutated_during_capture", "private_payload_redacted",
	]:
		if not (failure.get(flag) is bool):
			return false
	for count_field in ["capture_sequence", "section_index", "state_version_observed"]:
		if typeof(failure.get(count_field)) != TYPE_INT:
			return false
	return true


static func _all_section_results_captured(results: Array) -> bool:
	for result_variant in results:
		if not bool((result_variant as Dictionary).get("captured", false)):
			return false
	return true


static func _section_result_prefix_valid(results: Array, successful_count: int, failure: Dictionary) -> bool:
	for result_index in range(results.size()):
		var result := results[result_index] as Dictionary
		if result_index < successful_count:
			if not bool(result.get("captured", false)):
				return false
		else:
			if bool(result.get("captured", true)) \
					or str(result.get("section_id", "")) != str(failure.get("section_id", "")) \
					or str(result.get("owner_id", "")) != str(failure.get("owner_id", "")) \
					or str(result.get("reason_code", "")) != str(failure.get("reason_code", "")):
				return false
	return true


static func _has_exact_fields(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for field_variant in expected:
		if not value.has(str(field_variant)):
			return false
	return true


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


static func _targeted_owner_capture_run_id(value: String) -> bool:
	const PREFIX := "alpha04c-owner-capture-diagnostic-"
	if not value.begins_with(PREFIX):
		return false
	var suffix := value.trim_prefix(PREFIX)
	return suffix.length() == 12 \
			and _lower_hex(suffix, suffix.length(), suffix.length())


static func _lower_hex(value: String, minimum_length: int, maximum_length: int) -> bool:
	if value.length() < minimum_length or value.length() > maximum_length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
