extends SceneTree

const CaptureFailure := preload("res://scripts/runtime/save_owner_capture_failure_v1.gd")

const EXACT_FIELDS: Array[String] = [
	"schema_version",
	"registry_operation_id",
	"capture_sequence",
	"section_index",
	"section_id",
	"owner_id",
	"owner_node_path",
	"owner_script_path",
	"capture_method",
	"failure_class",
	"reason_code",
	"method_missing",
	"method_exception",
	"result_not_dictionary",
	"result_empty",
	"result_not_pure_data",
	"result_header_invalid",
	"result_version_invalid",
	"result_ruleset_invalid",
	"state_version_observed",
	"ruleset_id_observed",
	"live_state_mutated_during_capture",
	"private_payload_redacted",
]

const CLOSED_FAILURE_CLASSES: Array[String] = [
	"OWNER_NODE_MISSING",
	"OWNER_METHOD_MISSING",
	"OWNER_CAPTURE_EXCEPTION",
	"OWNER_CAPTURE_WRONG_TYPE",
	"OWNER_CAPTURE_EMPTY",
	"OWNER_CAPTURE_NOT_PURE_DATA",
	"OWNER_CAPTURE_HEADER_INVALID",
	"OWNER_CAPTURE_VERSION_INVALID",
	"OWNER_CAPTURE_RULESET_INVALID",
	"OWNER_CAPTURE_MUTATED_RUNTIME",
	"REGISTRY_INTERNAL_ERROR",
]

const FORBIDDEN_PRIVATE_KEYS: Array[String] = [
	"payload",
	"private_payload",
	"owner_state",
	"save_data",
	"sections",
	"envelope",
	"hand",
	"commodity_inventory",
	"ai_memory",
	"hidden_owner",
	"future_sequence",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_schema_and_exact_field_set()
	_test_closed_failure_classes()
	_test_closed_reason_codes()
	_test_sanitization_and_defaults()
	_test_forced_redaction_and_private_key_exclusion()
	_finish()


func _test_schema_and_exact_field_set() -> void:
	_expect(CaptureFailure.SCHEMA_VERSION == 1, "contract schema constant is pinned to version 1")
	var failure: Dictionary = CaptureFailure.build({
		"schema_version": 999,
		"registry_operation_id": "capture-operation-17",
		"capture_sequence": 17,
		"section_index": 8,
		"section_id": "card_inventory",
		"owner_id": "card_inventory_save_owner",
		"owner_node_path": "/root/Main/GameRuntimeCoordinator/CardInventorySaveOwner",
		"owner_script_path": "res://scripts/runtime/card_inventory_save_owner.gd",
		"capture_method": "to_save_data",
		"failure_class": "OWNER_CAPTURE_VERSION_INVALID",
		"reason_code": "state_version_mismatch",
		"method_missing": true,
		"method_exception": true,
		"result_not_dictionary": true,
		"result_empty": true,
		"result_not_pure_data": true,
		"result_header_invalid": true,
		"result_version_invalid": true,
		"result_ruleset_invalid": true,
		"state_version_observed": 2,
		"ruleset_id_observed": "v0.6",
		"live_state_mutated_during_capture": true,
		"private_payload_redacted": false,
	})
	_expect(_same_string_set(failure.keys(), EXACT_FIELDS), "build returns exactly the SaveOwnerCaptureFailureV1 field set")
	_expect(int(failure.get("schema_version", 0)) == 1, "caller input cannot override the schema version")
	_expect(str(failure.get("registry_operation_id", "")) == "capture-operation-17" and int(failure.get("capture_sequence", -1)) == 17, "operation identity and capture sequence are preserved")
	_expect(int(failure.get("section_index", -1)) == 8 and str(failure.get("section_id", "")) == "card_inventory", "section identity is preserved")
	_expect(str(failure.get("owner_id", "")) == "card_inventory_save_owner", "owner identity is preserved")
	_expect(str(failure.get("owner_node_path", "")).ends_with("/CardInventorySaveOwner") and str(failure.get("owner_script_path", "")).ends_with("card_inventory_save_owner.gd"), "bounded owner paths are preserved")
	_expect(str(failure.get("capture_method", "")) == "to_save_data", "capture method is preserved")
	_expect(str(failure.get("failure_class", "")) == "OWNER_CAPTURE_VERSION_INVALID" and str(failure.get("reason_code", "")) == "state_version_mismatch", "typed failure class and reason are preserved")
	for flag in [
		"method_missing",
		"method_exception",
		"result_not_dictionary",
		"result_empty",
		"result_not_pure_data",
		"result_header_invalid",
		"result_version_invalid",
		"result_ruleset_invalid",
		"live_state_mutated_during_capture",
	]:
		_expect(bool(failure.get(flag, false)), "%s preserves a true diagnostic flag" % flag)
	_expect(int(failure.get("state_version_observed", -1)) == 2 and str(failure.get("ruleset_id_observed", "")) == "v0.6", "observed header metadata is preserved")
	_expect(bool(failure.get("private_payload_redacted", false)), "redaction is always asserted")


func _test_closed_failure_classes() -> void:
	_expect(_same_string_set(CaptureFailure.FAILURE_CLASSES, CLOSED_FAILURE_CLASSES), "failure classes are the exact frozen closed set")
	_expect(CaptureFailure.FAILURE_CLASSES.size() == CLOSED_FAILURE_CLASSES.size(), "the closed failure class set contains no duplicates")
	for failure_class in CLOSED_FAILURE_CLASSES:
		var failure: Dictionary = CaptureFailure.build({"failure_class": failure_class})
		_expect(str(failure.get("failure_class", "")) == failure_class, "closed failure class %s is accepted unchanged" % failure_class)
	for invalid_class in ["", "owner_node_missing", "OWNER_CAPTURE_TIMEOUT", "REGISTRY_INTERNAL_ERROR ", 7]:
		var sanitized: Dictionary = CaptureFailure.build({"failure_class": invalid_class})
		_expect(str(sanitized.get("failure_class", "")) == "REGISTRY_INTERNAL_ERROR", "out-of-contract failure class %s fails closed" % str(invalid_class))


func _test_closed_reason_codes() -> void:
	var unique_reasons: Dictionary = {}
	var shape_valid := true
	for reason_variant in CaptureFailure.REASON_CODES:
		var reason := str(reason_variant)
		unique_reasons[reason] = true
		shape_valid = shape_valid and reason == reason.to_lower() and reason.length() <= 128
	_expect(unique_reasons.size() == CaptureFailure.REASON_CODES.size(), "closed Owner reason allowlist contains no duplicates")
	_expect(shape_valid, "every allowlisted Owner reason is a bounded lowercase token")
	_expect(CaptureFailure.sanitize_reason_code("card_inventory_v2_invalid") == "card_inventory_v2_invalid", "known production Owner reason survives unchanged")
	_expect(CaptureFailure.sanitize_reason_code("future_private_identity_900626424") == "registry_internal_error", "unknown lower-snake values fail closed without public disclosure")
	var classification_sets := CaptureFailure.NOT_PURE_REASON_CODES + CaptureFailure.HEADER_REASON_CODES \
			+ CaptureFailure.VERSION_REASON_CODES + CaptureFailure.RULESET_REASON_CODES \
			+ CaptureFailure.MUTATION_REASON_CODES
	var classification_closed := true
	for reason_variant in classification_sets:
		classification_closed = classification_closed and CaptureFailure.is_reason_code(str(reason_variant))
	_expect(classification_closed, "typed classification tables are strict subsets of the closed reason allowlist")


func _test_sanitization_and_defaults() -> void:
	var defaults: Dictionary = CaptureFailure.build({})
	var expected_defaults := {
		"schema_version": 1,
		"registry_operation_id": "",
		"capture_sequence": 0,
		"section_index": 0,
		"section_id": "",
		"owner_id": "",
		"owner_node_path": "",
		"owner_script_path": "",
		"capture_method": "",
		"failure_class": "REGISTRY_INTERNAL_ERROR",
		"reason_code": "registry_internal_error",
		"method_missing": false,
		"method_exception": false,
		"result_not_dictionary": false,
		"result_empty": false,
		"result_not_pure_data": false,
		"result_header_invalid": false,
		"result_version_invalid": false,
		"result_ruleset_invalid": false,
		"state_version_observed": -1,
		"ruleset_id_observed": "",
		"live_state_mutated_during_capture": false,
		"private_payload_redacted": true,
	}
	_expect(defaults == expected_defaults, "omitted fields receive the complete deterministic defaults")
	var sanitized: Dictionary = CaptureFailure.build({
		"registry_operation_id": 42,
		"capture_sequence": -42,
		"section_index": -9,
		"section_id": StringName("routes"),
		"owner_id": 73,
		"reason_code": StringName("capture_rejected"),
		"method_missing": 1,
		"method_exception": 0,
		"state_version_observed": "7",
		"ruleset_id_observed": StringName("v0.6"),
	})
	_expect(str(sanitized.get("registry_operation_id", "")) == "" and str(sanitized.get("section_id", "")) == "routes" and str(sanitized.get("owner_id", "")) == "", "non-string identities are rejected while bounded typed identifiers remain")
	_expect(int(sanitized.get("capture_sequence", -1)) == 0 and int(sanitized.get("section_index", -1)) == 0, "negative sequence and section indexes clamp to zero")
	_expect(str(sanitized.get("reason_code", "")) == "capture_rejected" and int(sanitized.get("state_version_observed", 0)) == -1 and str(sanitized.get("ruleset_id_observed", "")) == "v0.6", "reason is bounded while malformed observed integers fail closed")
	_expect(not bool(sanitized.get("method_missing", true)) and not bool(sanitized.get("method_exception", true)), "non-boolean diagnostic flags fail closed")


func _test_forced_redaction_and_private_key_exclusion() -> void:
	var hostile_source := {
		"failure_class": "OWNER_CAPTURE_EMPTY",
		"reason_code": "owner_capture_empty",
		"private_payload_redacted": false,
		"payload": {"cash": 999999, "cards": ["PRIVATE_PAYLOAD_SENTINEL"]},
		"private_payload": "PRIVATE_PAYLOAD_SENTINEL",
		"owner_state": {"hand": ["PRIVATE_PAYLOAD_SENTINEL"]},
		"save_data": {"ai_memory": "PRIVATE_PAYLOAD_SENTINEL"},
		"sections": {"card_inventory": "PRIVATE_PAYLOAD_SENTINEL"},
		"envelope": {"hidden_owner": "PRIVATE_PAYLOAD_SENTINEL"},
		"hand": ["PRIVATE_PAYLOAD_SENTINEL"],
		"commodity_inventory": ["PRIVATE_PAYLOAD_SENTINEL"],
		"ai_memory": "PRIVATE_PAYLOAD_SENTINEL",
		"hidden_owner": "PRIVATE_PAYLOAD_SENTINEL",
		"future_sequence": 999999,
	}
	var failure: Dictionary = CaptureFailure.build(hostile_source)
	_expect(bool(failure.get("private_payload_redacted", false)), "caller cannot disable private payload redaction")
	_expect(_same_string_set(failure.keys(), EXACT_FIELDS), "hostile extra fields cannot expand the public failure shape")
	for forbidden_key in FORBIDDEN_PRIVATE_KEYS:
		_expect(not failure.has(forbidden_key), "failure evidence excludes private key %s" % forbidden_key)
	var serialized := JSON.stringify(failure)
	_expect(not serialized.contains("PRIVATE_PAYLOAD_SENTINEL") and not serialized.contains("999999"), "private payload values never survive serialization")
	var hostile_strings: Dictionary = CaptureFailure.build({
		"registry_operation_id": "PRIVATE PAYLOAD SENTINEL",
		"section_id": "PRIVATE/PAYLOAD/SENTINEL",
		"owner_id": "PRIVATE PAYLOAD SENTINEL",
		"reason_code": "PRIVATE_PAYLOAD_SENTINEL",
		"ruleset_id_observed": "PRIVATE_PAYLOAD_SENTINEL",
	})
	var hostile_strings_serialized := JSON.stringify(hostile_strings)
	_expect(not hostile_strings_serialized.contains("PRIVATE_PAYLOAD_SENTINEL") \
			and str(hostile_strings.get("reason_code", "")) == "registry_internal_error" \
			and str(hostile_strings.get("ruleset_id_observed", "")) == "", "private values embedded in allowed string fields are rejected by bounded token contracts")


func _same_string_set(left: Array, right: Array) -> bool:
	var left_strings: Array[String] = []
	var right_strings: Array[String] = []
	for value in left:
		left_strings.append(str(value))
	for value in right:
		right_strings.append(str(value))
	left_strings.sort()
	right_strings.sort()
	return left_strings == right_strings


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error("SAVE_OWNER_CAPTURE_FAILURE_V1: %s" % failure)
	print("SAVE_OWNER_CAPTURE_FAILURE_V1_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())
