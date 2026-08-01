extends RefCounted

const BINDING_CONTRACT_PATH := "res://scripts/tools/cold_restore_targeted_ledger_binding_contract_v1.json"
const AUTHORIZATION_CONTRACT_PATH := "res://scripts/tools/cold_restore_authorization_contract_v1.json"
const GENERIC_REASON := "targeted_owner_capture_ledger_binding_invalid"
const MAXIMUM_EXACT_JSON_INTEGER := 9007199254740991.0


static func validate_ledger_file(ledger_path: String, options: Dictionary) -> Dictionary:
	if ledger_path.is_empty() or not FileAccess.file_exists(ledger_path):
		return _terminal_failure([], "ledger_file", "ledger_missing", "string", "missing")
	return validate_ledger_text(FileAccess.get_file_as_string(ledger_path), options)


static func validate_ledger_text(ledger_text: String, options: Dictionary) -> Dictionary:
	var contract := _read_json_dictionary(BINDING_CONTRACT_PATH)
	var authorization_contract := _read_json_dictionary(AUTHORIZATION_CONTRACT_PATH)
	var contract_check := _validate_contract(contract, authorization_contract)
	if not bool(contract_check.get("valid", false)):
		return _terminal_failure(
			[],
			"binding_contract",
			str(contract_check.get("reason_code", "binding_contract_invalid")),
			"dictionary",
			"invalid"
		)

	var rows: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(ledger_text)
	if not (parsed is Dictionary):
		return _terminal_failure(rows, "ledger_json", "ledger_json_invalid", "dictionary", _type_name(parsed))
	var ledger := parsed as Dictionary
	var required_fields := _string_array(contract.get("required_fields", []))
	var field_set_valid := _has_exact_fields(ledger, required_fields)
	rows.append(_row(
		"field_set",
		"",
		"",
		"required_fields",
		"exact_field_set",
		"exact_field_set" if field_set_valid else "different_field_set",
		_safe_fingerprint(required_fields),
		_safe_fingerprint(_sorted_dictionary_keys(ledger)),
		"none",
		"exact_set",
		field_set_valid,
		"" if field_set_valid else "ledger_field_set_invalid"
	))
	if not field_set_valid:
		return _finish(rows)

	var expected_fingerprint := str(options.get("targeted_diagnostic_ledger_fingerprint", "")).to_lower()
	var actual_fingerprint := ledger_text.sha256_text().to_lower()
	var fingerprint_valid := _is_lower_hex_length(expected_fingerprint, 64) \
			and actual_fingerprint == expected_fingerprint
	rows.append(_row(
		"ledger_sha256",
		"",
		"targeted_diagnostic_ledger_fingerprint",
		"",
		"lower_sha256",
		"lower_sha256",
		_safe_fingerprint(expected_fingerprint),
		_safe_fingerprint(actual_fingerprint),
		"lowercase",
		"exact",
		fingerprint_valid,
		"" if fingerprint_valid else "ledger_sha256_mismatch"
	))
	if not fingerprint_valid:
		return _finish(rows)
	var authorization_entry := _targeted_authorization_entry_for_id(
		authorization_contract,
		str(ledger.get("authorization_id", ""))
	)
	if authorization_entry.is_empty():
		return _terminal_failure(
			rows, "authorization_id", "authorization_id_mismatch", "string", "string"
		)

	var field_order := _string_array(contract.get("field_order", []))
	var field_types := contract.get("field_types", {}) as Dictionary
	var authorization_bindings := contract.get(
		"exact_values_from_authorization_contract", {}
	) as Dictionary
	var option_bindings := contract.get("option_bindings", {}) as Dictionary
	var exact_literals := contract.get("exact_literals", {}) as Dictionary
	var authorization_overrides := contract.get(
		"authorization_override_fields", {}
	) as Dictionary
	var validation_rules := contract.get("validation_rules", {}) as Dictionary
	var failure_reasons := contract.get("failure_reason_by_field", {}) as Dictionary

	for field in field_order:
		var value: Variant = ledger.get(field)
		var expected_type := str(field_types.get(field, ""))
		var actual_type := _type_name(value)
		var type_valid := _matches_wire_type(value, expected_type)
		var expected_value: Variant = null
		var option_field := ""
		var contract_field := ""
		var comparison_kind := "shape"
		if exact_literals.has(field):
			expected_value = exact_literals.get(field)
			contract_field = "exact_literals.%s" % field
			comparison_kind = "literal_exact"
		if authorization_bindings.has(field):
			contract_field = str(authorization_bindings.get(field, ""))
			expected_value = _resolve_dotted_value(
				authorization_contract if contract_field.contains(".") else authorization_entry,
				contract_field
			)
			comparison_kind = "authorization_contract_exact"
		elif option_bindings.has(field):
			option_field = str(option_bindings.get(field, ""))
			expected_value = options.get(option_field)
			comparison_kind = "option_exact"
		if authorization_overrides.has(field):
			var override_field := str(authorization_overrides.get(field, ""))
			if authorization_entry.has(override_field):
				expected_value = authorization_entry.get(override_field)
				contract_field = override_field
				comparison_kind = "authorization_contract_override"
		var comparison_valid := type_valid
		if comparison_valid and comparison_kind != "shape":
			comparison_valid = _wire_values_equal(value, expected_value, expected_type)
		var rule_id := str(validation_rules.get(field, "none"))
		var rule_valid := comparison_valid and _passes_validation_rule(value, rule_id)
		var passed := type_valid and comparison_valid and rule_valid
		var field_reason := ""
		if not type_valid:
			field_reason = "%s_type_invalid" % field
		elif not comparison_valid:
			field_reason = str(failure_reasons.get(field, "%s_value_mismatch" % field))
		elif not rule_valid:
			field_reason = str(failure_reasons.get(field, "%s_shape_invalid" % field))
		rows.append(_row(
			field,
			field,
			option_field,
			contract_field,
			expected_type,
			actual_type,
			_safe_fingerprint(expected_value if comparison_kind != "shape" else expected_type),
			_safe_fingerprint(value),
			rule_id,
			comparison_kind,
			passed,
			field_reason
		))
		if not passed:
			return _finish(rows)

	for rule_variant in contract.get("cross_field_rules", []):
		if not (rule_variant is Dictionary):
			return _terminal_failure(rows, "cross_field_rules", "cross_field_rule_invalid", "dictionary", _type_name(rule_variant))
		var rule := rule_variant as Dictionary
		var left_field := str(rule.get("left_field", ""))
		var right_field := str(rule.get("right_field", ""))
		var passed := str(ledger.get(left_field, "")) != str(ledger.get(right_field, ""))
		rows.append(_row(
			str(rule.get("rule_id", "cross_field_rule")),
			left_field,
			"",
			right_field,
			"different_values",
			"different_values" if passed else "equal_values",
			_safe_fingerprint("different_values"),
			_safe_fingerprint([ledger.get(left_field), ledger.get(right_field)]),
			"none",
			"not_equal",
			passed,
			"" if passed else str(rule.get("failure_reason", "cross_field_rule_failed"))
		))
		if not passed:
			return _finish(rows)
	return _finish(rows)


static func characterize_legacy_v4_mismatch(
	ledger_text: String,
	expected_fingerprint: String
) -> Dictionary:
	if ledger_text.sha256_text().to_lower() != expected_fingerprint.to_lower():
		return {
			"valid": false,
			"reason_code": GENERIC_REASON,
			"failing_field": "ledger_sha256",
			"field_reason": "ledger_sha256_mismatch",
			"expected_type": "lower_sha256",
			"actual_type": "lower_sha256",
		}
	var parsed: Variant = JSON.parse_string(ledger_text)
	if not (parsed is Dictionary):
		return {
			"valid": false,
			"reason_code": GENERIC_REASON,
			"failing_field": "ledger_json",
			"field_reason": "ledger_json_invalid",
			"expected_type": "dictionary",
			"actual_type": _type_name(parsed),
		}
	var ledger := parsed as Dictionary
	if typeof(ledger.get("schema_version")) != TYPE_INT:
		return {
			"valid": false,
			"reason_code": GENERIC_REASON,
			"failing_field": "schema_version",
			"field_reason": "godot_json_integer_materialized_as_float",
			"expected_type": "int",
			"actual_type": _type_name(ledger.get("schema_version")),
			"safe_expected_fingerprint": _safe_fingerprint("int"),
			"safe_actual_fingerprint": _safe_fingerprint(_type_name(ledger.get("schema_version"))),
		}
	return {"valid": true, "reason_code": "ok", "failing_field": "", "field_reason": ""}


static func _validate_contract(contract: Dictionary, authorization_contract: Dictionary) -> Dictionary:
	if int(contract.get("schema_version", 0)) != 1 \
			or str(contract.get("contract_id", "")) != "ColdRestoreTargetedLedgerBindingContractV1" \
			or str(contract.get("authorization_entry_resolution", "")) != "ledger_authorization_id":
		return {"valid": false, "reason_code": "binding_contract_identity_invalid"}
	if int(authorization_contract.get("schema_version", 0)) != 1 \
			or str(authorization_contract.get("contract_id", "")) != "ColdRestoreAuthorizationContractV1":
		return {"valid": false, "reason_code": "authorization_contract_identity_invalid"}
	var order := _string_array(contract.get("field_order", []))
	var required := _string_array(contract.get("required_fields", []))
	if order.is_empty() or order != required:
		return {"valid": false, "reason_code": "binding_contract_field_order_invalid"}
	for field in order:
		if not (contract.get("field_types", {}) as Dictionary).has(field) \
				or not (contract.get("failure_reason_by_field", {}) as Dictionary).has(field):
			return {"valid": false, "reason_code": "binding_contract_field_metadata_missing"}
	return {"valid": true, "reason_code": "ok"}


static func _matches_wire_type(value: Variant, expected_type: String) -> bool:
	match expected_type:
		"string", "decimal_string":
			return value is String
		"boolean":
			return value is bool
		"json_integer_number":
			if value is int:
				return abs(float(value)) <= MAXIMUM_EXACT_JSON_INTEGER
			if value is float:
				var number := float(value)
				return is_finite(number) and floor(number) == number \
					and abs(number) <= MAXIMUM_EXACT_JSON_INTEGER
	return false


static func _wire_values_equal(actual: Variant, expected: Variant, expected_type: String) -> bool:
	if expected_type == "json_integer_number":
		return _matches_wire_type(actual, expected_type) \
			and _matches_wire_type(expected, expected_type) \
			and int(actual) == int(expected)
	return actual == expected


static func _passes_validation_rule(value: Variant, rule_id: String) -> bool:
	var text := str(value)
	match rule_id:
		"none":
			return true
		"utc_timestamp":
			var regex := RegEx.new()
			return regex.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{1,7})?Z$") == OK \
				and regex.search(text) != null \
				and Time.get_unix_time_from_datetime_string(text) > 0
		"safe_run_id":
			return _matches_regex(text, "^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$")
		"lower_hex_40":
			return _is_lower_hex_length(text, 40)
		"lower_sha256":
			return _is_lower_hex_length(text, 64)
		"lower_hex_32":
			return _is_lower_hex_length(text, 32)
		"portable_absolute_path":
			return _is_portable_absolute_path(text)
		"positive_integer":
			return _matches_wire_type(value, "json_integer_number") and int(value) > 0
		"positive_decimal_19":
			return _is_positive_decimal(text)
	return false


static func _finish(rows: Array[Dictionary]) -> Dictionary:
	var pass_count := 0
	var first_failure: Dictionary = {}
	for row in rows:
		if bool(row.get("passed", false)):
			pass_count += 1
		elif first_failure.is_empty():
			first_failure = row
	var valid := first_failure.is_empty()
	return {
		"valid": valid,
		"reason_code": "ok" if valid else GENERIC_REASON,
		"failing_field": "" if valid else str(first_failure.get("field_id", "unknown")),
		"field_reason": "" if valid else str(first_failure.get("failure_reason", "binding_failed")),
		"expected_type": "" if valid else str(first_failure.get("expected_type", "")),
		"actual_type": "" if valid else str(first_failure.get("actual_type", "")),
		"safe_expected_fingerprint": "" if valid else str(first_failure.get("expected_value_fingerprint", "")),
		"safe_actual_fingerprint": "" if valid else str(first_failure.get("actual_value_fingerprint", "")),
		"check_count": rows.size(),
		"pass_count": pass_count,
		"failure_count": rows.size() - pass_count,
		"field_rows": rows,
	}


static func _terminal_failure(
	rows: Array[Dictionary],
	field_id: String,
	field_reason: String,
	expected_type: String,
	actual_type: String
) -> Dictionary:
	rows.append(_row(
		field_id, field_id, "", "", expected_type, actual_type,
		_safe_fingerprint(expected_type), _safe_fingerprint(actual_type),
		"none", "shape", false, field_reason
	))
	return _finish(rows)


static func _row(
	field_id: String,
	ledger_field: String,
	option_field: String,
	contract_field: String,
	expected_type: String,
	actual_type: String,
	expected_fingerprint: String,
	actual_fingerprint: String,
	normalization_rule: String,
	comparison_kind: String,
	passed: bool,
	failure_reason: String
) -> Dictionary:
	return {
		"field_id": field_id,
		"ledger_field": ledger_field,
		"option_field": option_field,
		"contract_field": contract_field,
		"expected_type": expected_type,
		"actual_type": actual_type,
		"expected_value_fingerprint": expected_fingerprint,
		"actual_value_fingerprint": actual_fingerprint,
		"normalization_rule": normalization_rule,
		"comparison_kind": comparison_kind,
		"passed": passed,
		"failure_reason": failure_reason,
	}


static func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func _resolve_dotted_value(root: Dictionary, dotted_path: String) -> Variant:
	var current: Variant = root
	for segment in dotted_path.split(".", false):
		if not (current is Dictionary) or not (current as Dictionary).has(segment):
			return null
		current = (current as Dictionary).get(segment)
	return current


static func _targeted_authorization_entry_for_id(
	authorization_contract: Dictionary,
	authorization_id: String
) -> Dictionary:
	for key_variant in authorization_contract.keys():
		var key := str(key_variant)
		var value: Variant = authorization_contract.get(key)
		if key.begins_with("targeted_owner_capture_diagnostic_") \
				and value is Dictionary \
				and str((value as Dictionary).get("authorization_id", "")) == authorization_id:
			return (value as Dictionary).duplicate(true)
	return {}


static func _has_exact_fields(value: Dictionary, expected_fields: Array[String]) -> bool:
	if value.size() != expected_fields.size():
		return false
	for field in expected_fields:
		if not value.has(field):
			return false
	return true


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result


static func _sorted_dictionary_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in value.keys():
		result.append(str(key))
	result.sort()
	return result


static func _safe_fingerprint(value: Variant) -> String:
	return JSON.stringify(value).sha256_text().to_lower()


static func _type_name(value: Variant) -> String:
	return type_string(typeof(value)).to_lower()


static func _is_lower_hex_length(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _is_positive_decimal(value: String) -> bool:
	if value.is_empty() or value.length() > 19 or value.begins_with("0"):
		return false
	for index in range(value.length()):
		if not "0123456789".contains(value.substr(index, 1)):
			return false
	return true


static func _is_portable_absolute_path(value: String) -> bool:
	if value.is_empty():
		return false
	return value.replace("\\", "/").is_absolute_path()


static func _matches_regex(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(value) != null
