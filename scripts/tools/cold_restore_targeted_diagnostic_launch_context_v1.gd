extends RefCounted

const CONTRACT_PATH := "res://scripts/tools/cold_restore_targeted_diagnostic_launch_context_v1.json"
const GENERIC_REASON := "targeted_owner_capture_launch_context_invalid"
const MAXIMUM_EXACT_JSON_INTEGER := 9007199254740991.0


static func contract_path() -> String:
	return CONTRACT_PATH


static func read_contract() -> Dictionary:
	if not FileAccess.file_exists(CONTRACT_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not (parsed is Dictionary):
		return {}
	var contract := (parsed as Dictionary).duplicate(true)
	return contract if _contract_valid(contract) else {}


static func parse_cli_argument(argument: String) -> Dictionary:
	var contract := read_contract()
	if contract.is_empty():
		return _failure(
			"child_cli_parser", "binding_contract", "invalid_contract", "valid_contract", contract
		)
	var mappings := contract.get("cli_argument_names", {}) as Dictionary
	var option_names := contract.get("gdscript_option_names", {}) as Dictionary
	for field_variant in contract.get("required_fields", []):
		var field := str(field_variant)
		if not mappings.has(field) or mappings.get(field) == null:
			continue
		var prefix := str(mappings.get(field, ""))
		if not prefix.is_empty() and argument.begins_with(prefix):
			return {
				"valid": true,
				"recognized": true,
				"context_field": field,
				"option_name": str(option_names.get(field, "")),
				"value": argument.trim_prefix(prefix),
			}
	return {"valid": true, "recognized": false}


static func parse_cli_argument_list(arguments: Array[String]) -> Dictionary:
	var contract := read_contract()
	if contract.is_empty():
		return _failure(
			"child_cli_parser", "binding_contract", "invalid_contract", "valid_contract", contract
		)
	var mode_arguments := _string_array(contract.get("mode_arguments", []))
	var options: Dictionary = {}
	for argument in arguments:
		if argument in mode_arguments:
			continue
		var parsed := parse_cli_argument(argument)
		if not bool(parsed.get("valid", false)):
			return parsed
		if not bool(parsed.get("recognized", false)):
			return _failure(
				"child_cli_parser", "cli_argument", "unknown_argument", "contract_cli_name", argument
			)
		var option_name := str(parsed.get("option_name", ""))
		if option_name.is_empty():
			return _failure(
				"child_cli_parser", str(parsed.get("context_field", "")),
				"missing_option_mapping", "gdscript_option_name", null
			)
		if options.has(option_name):
			return _failure(
				"child_cli_parser", str(parsed.get("context_field", "")),
				"duplicate", "single_argument", parsed.get("value")
			)
		options[option_name] = parsed.get("value")
	return {"valid": true, "reason_code": "ok", "options": options}


static func build_child_context(options: Dictionary, ledger: Dictionary) -> Dictionary:
	var contract := read_contract()
	if contract.is_empty():
		return _failure(
			"child_context_builder", "binding_contract", "invalid_contract", "valid_contract", contract
		)
	var context: Dictionary = {}
	var sources := contract.get("field_sources", {}) as Dictionary
	var ledger_names := contract.get("ledger_field_names", {}) as Dictionary
	var option_names := contract.get("gdscript_option_names", {}) as Dictionary
	var runtime_identity := contract.get("runtime_identity", {}) as Dictionary
	var fixed_values := contract.get("fixed_values", {}) as Dictionary
	for field_variant in contract.get("required_fields", []):
		var field := str(field_variant)
		var source := str(sources.get(field, ""))
		if source.begins_with("contract.runtime_identity."):
			if runtime_identity.has(field):
				context[field] = runtime_identity.get(field)
		elif source.begins_with("contract.fixed_values."):
			if fixed_values.has(field):
				context[field] = fixed_values.get(field)
		elif source.begins_with("quota_ledger."):
			var ledger_field := str(ledger_names.get(field, ""))
			if not ledger_field.is_empty() and ledger.has(ledger_field):
				context[field] = ledger.get(ledger_field)
		elif source.begins_with("child_cli."):
			var option_name := str(option_names.get(field, ""))
			if not option_name.is_empty() and options.has(option_name):
				context[field] = options.get(option_name)
	var expected := _ledger_expected_bindings(ledger, contract)
	var report := validate_context(context, expected, "child_context_builder")
	if not bool(report.get("valid", false)):
		return report
	return {"valid": true, "reason_code": "ok", "context": context}


static func build_replay_source_context(
	ledger: Dictionary,
	launch_attestation: Dictionary,
	quota_ledger_path: String,
	quota_ledger_sha256: String,
	launch_attestation_path: String
) -> Dictionary:
	var contract := read_contract()
	if contract.is_empty():
		return _failure(
			"retained_v5_replay_builder", "binding_contract", "invalid_contract", "valid_contract", contract
		)
	var option_names := contract.get("gdscript_option_names", {}) as Dictionary
	var options: Dictionary = {}
	var replay_values := {
		"run_id": launch_attestation.get("run_id"),
		"repository_head": launch_attestation.get("source_head_sha"),
		"scenario_fingerprint": launch_attestation.get("scenario_fingerprint"),
		"quota_ledger_path": quota_ledger_path,
		"quota_ledger_sha256": quota_ledger_sha256,
		"launch_attestation_path": launch_attestation_path,
		"launch_nonce": launch_attestation.get("launch_nonce"),
		"role_timeout_policy_sha256": ledger.get("role_timeout_policy_sha256"),
	}
	for field in replay_values:
		var option_name := str(option_names.get(field, ""))
		if not option_name.is_empty():
			options[option_name] = replay_values.get(field)
	var built := build_child_context(options, ledger)
	if not bool(built.get("valid", false)):
		return built
	var context := built.get("context", {}) as Dictionary
	var attestation_report := validate_launch_attestation(
		context, launch_attestation, "retained_v5_launch_attestation"
	)
	if not bool(attestation_report.get("valid", false)):
		return attestation_report
	return {"valid": true, "reason_code": "ok", "context": context}


static func validate_context(
	context: Dictionary,
	expected_bindings: Dictionary = {},
	stage: String = "launch_context_validation"
) -> Dictionary:
	var contract := read_contract()
	if contract.is_empty():
		return _failure(stage, "binding_contract", "invalid_contract", "valid_contract", contract)
	var required := _string_array(contract.get("required_fields", []))
	var field_types := contract.get("field_types", {}) as Dictionary
	var rules := contract.get("validation_rules", {}) as Dictionary
	for field in required:
		if not context.has(field):
			return _failure(
				stage, field, "missing", expected_bindings.get(field, "required"), "__missing__"
			)
		var value: Variant = context.get(field)
		var shape_failure := _shape_failure(
			value, str(field_types.get(field, "")), str(rules.get(field, ""))
		)
		if not shape_failure.is_empty():
			return _failure(
				stage, field, shape_failure,
				expected_bindings.get(field, field_types.get(field)), value
			)
	if not _has_exact_fields(context, required):
		return _failure(stage, "field_set", "unexpected_field", required, _sorted_keys(context))

	var built_in_expected := {
		"schema_version": (contract.get("runtime_identity", {}) as Dictionary).get("schema_version"),
		"context_id": (contract.get("runtime_identity", {}) as Dictionary).get("context_id"),
		"challenge_depth": (contract.get("fixed_values", {}) as Dictionary).get("challenge_depth"),
		"run_seed": (contract.get("fixed_values", {}) as Dictionary).get("run_seed"),
		"local_player_count": (contract.get("fixed_values", {}) as Dictionary).get("local_player_count"),
		"ai_player_count": (contract.get("fixed_values", {}) as Dictionary).get("ai_player_count"),
	}
	for field_variant in built_in_expected.keys() + expected_bindings.keys():
		var field := str(field_variant)
		var expected: Variant = expected_bindings.get(field) \
				if expected_bindings.has(field) else built_in_expected.get(field)
		var actual: Variant = context.get(field)
		if not _wire_values_equal(actual, expected):
			return _failure(stage, field, "value_mismatch", expected, actual)
	return {
		"valid": true,
		"reason_code": "ok",
		"failing_stage": "",
		"failing_field": "",
		"field_reason": "",
		"safe_expected_fingerprint": "",
		"safe_actual_fingerprint": "",
	}


static func validate_launch_attestation(
	context: Dictionary,
	attestation: Dictionary,
	stage: String = "launch_attestation_binding"
) -> Dictionary:
	var context_report := validate_context(context, {}, stage)
	if not bool(context_report.get("valid", false)):
		return context_report
	var contract := read_contract()
	var mappings := contract.get("launch_attestation_field_names", {}) as Dictionary
	for context_field_variant in mappings.keys():
		var context_field := str(context_field_variant)
		var attestation_field := str(mappings.get(context_field, ""))
		if attestation_field.is_empty() or not attestation.has(attestation_field):
			return _failure(
				stage, context_field, "missing", context.get(context_field), "__missing__"
			)
		var expected: Variant = context.get(context_field)
		var actual: Variant = attestation.get(attestation_field)
		if actual == null:
			return _failure(stage, context_field, "null", expected, actual)
		if not _wire_values_equal(actual, expected):
			return _failure(stage, context_field, "value_mismatch", expected, actual)
	return {"valid": true, "reason_code": "ok"}


static func argument_list(context: Dictionary) -> Dictionary:
	var report := validate_context(context, {}, "gdscript_cli_publisher")
	if not bool(report.get("valid", false)):
		return report
	var contract := read_contract()
	var result: Array[String] = _string_array(contract.get("mode_arguments", []))
	var mappings := contract.get("cli_argument_names", {}) as Dictionary
	for field_variant in contract.get("required_fields", []):
		var field := str(field_variant)
		if not mappings.has(field) or mappings.get(field) == null:
			continue
		result.append("%s%s" % [str(mappings.get(field, "")), str(context.get(field))])
	return {"valid": true, "reason_code": "ok", "arguments": result}


static func canonical_context_field_for_ledger_field(ledger_field: String) -> String:
	var contract := read_contract()
	return str((contract.get("canonical_binding_names", {}) as Dictionary).get(ledger_field, ""))


static func quota_ledger_sha256(context: Dictionary) -> String:
	return str(context.get("quota_ledger_sha256", ""))


static func _ledger_expected_bindings(ledger: Dictionary, contract: Dictionary) -> Dictionary:
	var expected: Dictionary = {}
	var ledger_names := contract.get("ledger_field_names", {}) as Dictionary
	for context_field_variant in ledger_names.keys():
		var context_field := str(context_field_variant)
		var ledger_field := str(ledger_names.get(context_field, ""))
		if not ledger_field.is_empty() and ledger.has(ledger_field):
			expected[context_field] = ledger.get(ledger_field)
	return expected


static func _contract_valid(contract: Dictionary) -> bool:
	if int(contract.get("schema_version", 0)) != 1 \
			or str(contract.get("context_id", "")) != "ColdRestoreTargetedDiagnosticLaunchContextV1":
		return false
	var repository_rule := contract.get("repository_head", {}) as Dictionary
	if not bool(repository_rule.get("required", false)) \
			or bool(repository_rule.get("nullable", true)) \
			or bool(repository_rule.get("empty_allowed", true)) \
			or bool(repository_rule.get("implicit_fallback_allowed", true)) \
			or bool(repository_rule.get("source_head_sha_alias_allowed", true)) \
			or int(repository_rule.get("length", 0)) != 40:
		return false
	var required := _string_array(contract.get("required_fields", []))
	if required.is_empty():
		return false
	for field in required:
		for map_name in ["field_types", "validation_rules", "field_sources", "failure_reason_by_field"]:
			if not (contract.get(map_name, {}) as Dictionary).has(field):
				return false
	return true


static func _shape_failure(value: Variant, expected_type: String, rule: String) -> String:
	if value == null:
		return "null"
	if expected_type in ["string", "decimal_string"]:
		if not (value is String or value is StringName):
			return "wrong_type"
		if str(value).is_empty():
			return "empty"
	elif expected_type == "json_integer_number":
		if not _is_json_integer(value):
			return "wrong_type"
	else:
		return "wrong_type"

	var text := str(value)
	match rule:
		"lower_hex_40":
			return _lower_hex_failure(text, 40)
		"lower_sha256":
			return _lower_hex_failure(text, 64)
		"lower_hex_32":
			return _lower_hex_failure(text, 32)
		"safe_identifier":
			return "" if _matches_regex(text, "^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$") else "invalid_format"
		"safe_run_id":
			return "" if _matches_regex(text, "^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$") else "invalid_format"
		"absolute_path":
			return "" if text.replace("\\", "/").is_absolute_path() else "invalid_path"
		"positive_integer":
			return "" if _is_json_integer(value) and int(value) > 0 else "out_of_range"
		"positive_decimal_19":
			return "" if _matches_regex(text, "^[1-9][0-9]{0,18}$") else "invalid_format"
	return "invalid_rule"


static func _lower_hex_failure(value: String, expected_length: int) -> String:
	if value.length() != expected_length:
		return "wrong_length"
	if not _matches_regex(value, "^[0-9A-Fa-f]{%d}$" % expected_length):
		return "non_hex"
	if _matches_regex(value, ".*[A-F].*"):
		return "uppercase"
	return ""


static func _failure(
	stage: String,
	field: String,
	field_reason: String,
	expected: Variant,
	actual: Variant
) -> Dictionary:
	return {
		"valid": false,
		"reason_code": GENERIC_REASON,
		"failing_stage": stage.left(64),
		"failing_field": field.left(64),
		"field_reason": field_reason.left(64),
		"safe_expected_fingerprint": _safe_fingerprint(expected),
		"safe_actual_fingerprint": _safe_fingerprint(actual),
	}


static func _wire_values_equal(actual: Variant, expected: Variant) -> bool:
	if _is_json_integer(actual) and _is_json_integer(expected):
		return int(actual) == int(expected)
	return actual == expected


static func _is_json_integer(value: Variant) -> bool:
	if value is int:
		return abs(float(value)) <= MAXIMUM_EXACT_JSON_INTEGER
	if value is float:
		var number := float(value)
		return is_finite(number) and floor(number) == number \
				and abs(number) <= MAXIMUM_EXACT_JSON_INTEGER
	return false


static func _has_exact_fields(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for field in expected:
		if not value.has(field):
			return false
	return true


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result


static func _sorted_keys(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in value.keys():
		result.append(str(key))
	result.sort()
	return result


static func _safe_fingerprint(value: Variant) -> String:
	return JSON.stringify(value).sha256_text().to_lower()


static func _matches_regex(value: String, pattern: String) -> bool:
	var regex := RegEx.new()
	return regex.compile(pattern) == OK and regex.search(value) != null
