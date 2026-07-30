extends SceneTree

const DRIVER := preload("res://scripts/tools/cold_restore_vertical_slice_driver.gd")
const CAPTURE_FAILURE := preload("res://scripts/runtime/save_owner_capture_failure_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const DRIVER_PATH := "res://scripts/tools/cold_restore_vertical_slice_driver.gd"
const EXACT_FIELDS := [
	"schema_version", "registry_operation_id", "capture_sequence", "section_index",
	"section_id", "owner_id", "owner_node_path", "owner_script_path", "capture_method",
	"failure_class", "reason_code", "method_missing", "method_exception",
	"result_not_dictionary", "result_empty", "result_not_pure_data", "result_header_invalid",
	"result_version_invalid", "result_ruleset_invalid", "state_version_observed",
	"ruleset_id_observed", "live_state_mutated_during_capture", "private_payload_redacted",
]
const BOOLEAN_FIELDS := [
	"method_missing", "method_exception", "result_not_dictionary", "result_empty",
	"result_not_pure_data", "result_header_invalid", "result_version_invalid",
	"result_ruleset_invalid", "live_state_mutated_during_capture", "private_payload_redacted",
]
const CLASS_FLAG_CASES := [
	["OWNER_METHOD_MISSING", "owner_capture_method_missing", "method_missing"],
	["OWNER_CAPTURE_EXCEPTION", "registry_internal_error", "method_exception"],
	["OWNER_CAPTURE_WRONG_TYPE", "owner_capture_result_not_dictionary", "result_not_dictionary"],
	["OWNER_CAPTURE_EMPTY", "owner_capture_empty", "result_empty"],
	["OWNER_CAPTURE_NOT_PURE_DATA", "owner_capture_not_pure_data", "result_not_pure_data"],
	["OWNER_CAPTURE_HEADER_INVALID", "owner_header_invalid", "result_header_invalid"],
	["OWNER_CAPTURE_VERSION_INVALID", "state_version_mismatch", "result_version_invalid"],
	["OWNER_CAPTURE_RULESET_INVALID", "ruleset_id_mismatch", "result_ruleset_invalid"],
	["OWNER_CAPTURE_MUTATED_RUNTIME", "owner_capture_mutated_runtime", "live_state_mutated_during_capture"],
]
const FORBIDDEN_RAW_PAYLOAD_KEYS := [
	"payload", "raw_payload", "private_payload", "owner_payload", "owner_state",
	"save_data", "sections", "envelope", "hand", "commodity_inventory", "ai_memory",
	"hidden_owner", "future_sequence",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var driver: Object = DRIVER.new()
	_test_source_contract()
	_test_valid_projection(driver)
	_test_missing_field_matrix(driver)
	_test_extra_field_rejection(driver)
	_test_wrong_type_matrix(driver)
	_test_unknown_class_and_reason(driver)
	_test_failure_class_flag_consistency(driver)
	driver.free()
	_finish()


func _test_source_contract() -> void:
	var source := FileAccess.get_file_as_string(DRIVER_PATH)
	var projection_source := _function_source(source, "func _safe_owner_capture_failure(")
	_expect(not projection_source.is_empty(), "driver projection function is discoverable")
	_expect(
		projection_source.contains("CAPTURE_FAILURE.build(source)"),
		"driver projection canonicalizes through SaveOwnerCaptureFailureV1.build"
	)
	_expect(
		projection_source.contains("source.size()") or projection_source.contains("_has_exact_fields"),
		"driver source visibly enforces a closed input field set"
	)
	for forbidden_key in FORBIDDEN_RAW_PAYLOAD_KEYS:
		_expect(
			not projection_source.contains('"%s"' % forbidden_key),
			"driver projection never reads or emits raw key %s" % forbidden_key
		)


func _test_valid_projection(driver: Object) -> void:
	var source := _valid_failure()
	var projected := _project(driver, source)
	_expect(_same_string_set(projected.keys(), EXACT_FIELDS), "valid projection contains exactly 23 fields")
	_expect(projected == source, "valid projection preserves every canonical source field value")
	var source_fingerprint := SEMANTIC_WIRE.fingerprint(source)
	var projected_fingerprint := SEMANTIC_WIRE.fingerprint(projected)
	_expect(not source_fingerprint.is_empty(), "valid source has a canonical fingerprint")
	_expect(
		projected_fingerprint == source_fingerprint,
		"projection preserves the canonical source fingerprint"
	)
	_expect(
		not SEMANTIC_WIRE.contains_key_recursive(projected, FORBIDDEN_RAW_PAYLOAD_KEYS),
		"valid projection contains no raw Owner payload"
	)


func _test_missing_field_matrix(driver: Object) -> void:
	for field_variant in EXACT_FIELDS:
		var field := str(field_variant)
		var malformed := _valid_failure()
		malformed.erase(field)
		_expect(
			_project(driver, malformed).is_empty(),
			"projection rejects input missing required field %s" % field
		)
	var multiple_missing := _valid_failure()
	multiple_missing.erase("method_exception")
	multiple_missing.erase("state_version_observed")
	_expect(_project(driver, multiple_missing).is_empty(), "projection rejects multiple missing fields")


func _test_extra_field_rejection(driver: Object) -> void:
	for extra_field in ["unexpected_field", "raw_payload", "private_payload"]:
		var malformed := _valid_failure()
		malformed[extra_field] = "PRIVATE_SENTINEL_MUST_NOT_SURVIVE"
		_expect(
			_project(driver, malformed).is_empty(),
			"projection rejects extra field %s instead of silently dropping it" % extra_field
		)


func _test_wrong_type_matrix(driver: Object) -> void:
	var wrong_values := {
		"schema_version": "1",
		"registry_operation_id": 7,
		"capture_sequence": 7.0,
		"section_index": "7",
		"section_id": 7,
		"owner_id": false,
		"owner_node_path": [],
		"owner_script_path": {},
		"capture_method": 1,
		"failure_class": 1,
		"reason_code": false,
		"state_version_observed": 2.0,
		"ruleset_id_observed": 6,
	}
	for boolean_field in BOOLEAN_FIELDS:
		wrong_values[boolean_field] = "true"
	for field_variant in EXACT_FIELDS:
		var field := str(field_variant)
		var malformed := _valid_failure()
		malformed[field] = wrong_values.get(field)
		_expect(
			_project(driver, malformed).is_empty(),
			"projection rejects wrong type for %s" % field
		)


func _test_unknown_class_and_reason(driver: Object) -> void:
	var unknown_class := _valid_failure()
	unknown_class["failure_class"] = "OWNER_CAPTURE_TIMEOUT"
	_expect(_project(driver, unknown_class).is_empty(), "projection rejects an unknown failure class")
	var unknown_reason := _valid_failure()
	unknown_reason["reason_code"] = "future_unregistered_capture_reason"
	_expect(_project(driver, unknown_reason).is_empty(), "projection rejects an unknown reason code")


func _test_failure_class_flag_consistency(driver: Object) -> void:
	for case_variant in CLASS_FLAG_CASES:
		var case := case_variant as Array
		var failure_class := str(case[0])
		var reason_code := str(case[1])
		var required_flag := str(case[2])
		var valid := _valid_failure()
		valid["failure_class"] = failure_class
		valid["reason_code"] = reason_code
		for flag_variant in BOOLEAN_FIELDS:
			var flag := str(flag_variant)
			valid[flag] = flag == required_flag or flag == "private_payload_redacted"
		_expect(
			not _project(driver, valid).is_empty(),
			"projection accepts %s only with its matching flag" % failure_class
		)
		var inconsistent := valid.duplicate(true)
		inconsistent[required_flag] = false
		var alternate_flag := "method_missing" if required_flag != "method_missing" else "result_empty"
		inconsistent[alternate_flag] = true
		_expect(
			_project(driver, inconsistent).is_empty(),
			"projection rejects %s with inconsistent diagnostic flags" % failure_class
		)


func _valid_failure() -> Dictionary:
	return {
		"schema_version": CAPTURE_FAILURE.SCHEMA_VERSION,
		"registry_operation_id": "capture-operation-7",
		"capture_sequence": 7,
		"section_index": 7,
		"section_id": str(DRIVER.SAVE_SECTION_ORDER[7]),
		"owner_id": str(DRIVER.SAVE_OWNER_ORDER[7]),
		"owner_node_path": "../../CardInventorySaveOwner",
		"owner_script_path": "res://scripts/runtime/card_inventory_save_owner.gd",
		"capture_method": "to_save_data",
		"failure_class": "OWNER_CAPTURE_VERSION_INVALID",
		"reason_code": "state_version_mismatch",
		"method_missing": false,
		"method_exception": false,
		"result_not_dictionary": false,
		"result_empty": false,
		"result_not_pure_data": false,
		"result_header_invalid": false,
		"result_version_invalid": true,
		"result_ruleset_invalid": false,
		"state_version_observed": 2,
		"ruleset_id_observed": "v0.6",
		"live_state_mutated_during_capture": false,
		"private_payload_redacted": true,
	}


func _project(driver: Object, value: Variant) -> Dictionary:
	var result: Variant = driver.call("_safe_owner_capture_failure", value)
	return result as Dictionary if result is Dictionary else {}


func _function_source(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next_regular := source.find("\nfunc ", start + signature.length())
	var next_static := source.find("\nstatic func ", start + signature.length())
	var end := source.length()
	if next_regular >= 0:
		end = mini(end, next_regular)
	if next_static >= 0:
		end = mini(end, next_static)
	return source.substr(start, end - start)


func _same_string_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	var normalized_left: Array[String] = []
	var normalized_right: Array[String] = []
	for value in left:
		normalized_left.append(str(value))
	for value in right:
		normalized_right.append(str(value))
	normalized_left.sort()
	normalized_right.sort()
	return normalized_left == normalized_right


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("COLD_RESTORE_OWNER_CAPTURE_FAILURE_PROJECTION_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
