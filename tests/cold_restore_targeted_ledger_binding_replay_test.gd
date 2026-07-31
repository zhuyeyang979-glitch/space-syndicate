extends SceneTree

const VALIDATOR := preload(
	"res://scripts/tools/cold_restore_targeted_ledger_binding_validator_v1.gd"
)
const RETAINED_LEDGER_SHA256 := "154ceedf4032404d4c7d355fbd775991e20d29299f6e05e3a8c8e70c64be208c"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var retained_path := _argument_value("--v4-retained-ledger-path=")
	_expect(FileAccess.file_exists(retained_path), "retained V4 ledger bytes exist")
	var retained_text := FileAccess.get_file_as_string(retained_path)
	_expect(retained_text.sha256_text().to_lower() == RETAINED_LEDGER_SHA256, "retained V4 ledger SHA-256 is immutable")
	var parsed: Variant = JSON.parse_string(retained_text)
	_expect(parsed is Dictionary, "retained V4 ledger parses as a dictionary")
	if not (parsed is Dictionary):
		_finish()
		return
	var retained := parsed as Dictionary
	var options := _options_for(retained, RETAINED_LEDGER_SHA256)
	var legacy := VALIDATOR.characterize_legacy_v4_mismatch(
		retained_text,
		RETAINED_LEDGER_SHA256
	)
	_expect(not bool(legacy.get("valid", true)), "legacy validator characterization reproduces rejection")
	_expect(str(legacy.get("reason_code", "")) == "targeted_owner_capture_ledger_binding_invalid", "legacy public reason remains generic")
	_expect(str(legacy.get("failing_field", "")) == "schema_version", "legacy first mismatch is schema_version")
	_expect(str(legacy.get("field_reason", "")) == "godot_json_integer_materialized_as_float", "legacy first mismatch explains JSON number materialization")
	_expect(str(legacy.get("actual_type", "")) == "float", "legacy parsed schema type is float")

	var canonical := VALIDATOR.validate_ledger_text(retained_text, options)
	_expect_valid(canonical, "retained V4 ledger passes the canonical child binding validator")
	_expect(int(canonical.get("check_count", 0)) == 35, "canonical binding executes 35 ordered checks")
	_expect(int(canonical.get("pass_count", 0)) == 35, "canonical binding passes all 35 checks")
	_expect(int(canonical.get("failure_count", -1)) == 0, "canonical binding has zero failures")
	_expect(not JSON.stringify(canonical).contains(str(retained.get("claim_nonce", ""))), "binding result never exposes claim nonce")
	_expect(not JSON.stringify(canonical).contains(str(retained.get("bootstrap_admission_path", ""))), "binding result never exposes local evidence path")

	_expect_corruption(retained, options, "schema_version", 5, "schema_version")
	_expect_corruption(retained, options, "authorization_id", "wrong-authorization", "authorization_id")
	_expect_corruption(retained, options, "run_id", "wrong-run", "run_id")
	_expect_corruption(retained, options, "repository_head", "0".repeat(40), "repository_head")
	_expect_corruption(retained, options, "scenario_fingerprint", "1".repeat(64), "scenario_fingerprint")
	for field in [
		"authorized_new_diagnostic_count",
		"diagnostic_count_before",
		"diagnostic_count_after",
		"diagnostic_count_maximum",
	]:
		_expect_corruption(retained, options, field, 99, field)
	_expect_corruption(retained, options, "bootstrap_admission_path", "relative/path.json", "bootstrap_admission_path")
	_expect_corruption(retained, options, "prequota_attestation_path", "relative/path.json", "prequota_attestation_path")
	_expect_corruption(retained, options, "role_timeout_policy_sha256", "2".repeat(64), "role_timeout_policy_sha256")
	_expect_corruption(retained, options, "official_attempt_1_claim_sha256", "3".repeat(64), "official_attempt_1_claim_sha256")
	_expect_corruption(retained, options, "official", true, "official")
	_expect_corruption(retained, options, "formal", true, "formal")
	_expect_corruption(retained, options, "official_authorization_consumed", true, "official_authorization_consumed")
	_expect_corruption(retained, options, "orchestrator_process_id", 4.5, "orchestrator_process_id")
	_expect_corruption(retained, options, "orchestrator_creation_time_utc_ticks", "0", "orchestrator_creation_time_utc_ticks")
	_expect_corruption(retained, options, "claim_nonce", "z".repeat(32), "claim_nonce")
	_expect_corruption(retained, options, "launch_nonce", "4".repeat(32), "launch_nonce")
	_expect_corruption(retained, options, "status", "available", "status")

	var nonce_collision := retained.duplicate(true)
	nonce_collision["claim_nonce"] = nonce_collision["launch_nonce"]
	_expect_fixture_failure(nonce_collision, options, "claim_nonce_differs_from_launch_nonce", "nonce collision is rejected")

	var missing_field := retained.duplicate(true)
	missing_field.erase("status")
	_expect_fixture_failure(missing_field, options, "field_set", "truncated ledger field set is rejected")

	var unicode_paths := retained.duplicate(true)
	unicode_paths["bootstrap_admission_path"] = "C:\\V4 回放 空格\\bootstrap.admission.json"
	unicode_paths["prequota_attestation_path"] = "C:\\V4 回放 空格\\prequota.json"
	_expect_fixture_valid(unicode_paths, options, "Windows Chinese and spaced absolute paths are accepted")

	var posix_paths := retained.duplicate(true)
	posix_paths["bootstrap_admission_path"] = "/tmp/v4 replay/bootstrap.admission.json"
	posix_paths["prequota_attestation_path"] = "/tmp/v4 replay/prequota.json"
	_expect_fixture_valid(posix_paths, options, "POSIX absolute paths are accepted")

	var maximum_safe_integer := retained.duplicate(true)
	maximum_safe_integer["orchestrator_process_id"] = 9007199254740991.0
	_expect_fixture_valid(maximum_safe_integer, options, "maximum JSON-safe integer is accepted")
	var unsafe_integer := retained.duplicate(true)
	unsafe_integer["orchestrator_process_id"] = 9007199254740992.0
	_expect_fixture_failure(unsafe_integer, options, "orchestrator_process_id", "unsafe JSON integer is rejected")

	var maximum_ticks := retained.duplicate(true)
	maximum_ticks["orchestrator_creation_time_utc_ticks"] = "9".repeat(19)
	_expect_fixture_valid(maximum_ticks, options, "19-digit Int64-like ticks remain a decimal string")
	var oversized_ticks := retained.duplicate(true)
	oversized_ticks["orchestrator_creation_time_utc_ticks"] = "1" + "0".repeat(19)
	_expect_fixture_failure(oversized_ticks, options, "orchestrator_creation_time_utc_ticks", "20-digit ticks are rejected")

	var wrong_sha_options := options.duplicate(true)
	wrong_sha_options["targeted_diagnostic_ledger_fingerprint"] = "0".repeat(64)
	var wrong_sha := VALIDATOR.validate_ledger_text(retained_text, wrong_sha_options)
	_expect_failure(wrong_sha, "ledger_sha256", "ledger SHA mismatch is rejected before field binding")

	_finish()


func _expect_corruption(
	retained: Dictionary,
	options: Dictionary,
	field: String,
	value: Variant,
	expected_failure: String
) -> void:
	var fixture := retained.duplicate(true)
	fixture[field] = value
	_expect_fixture_failure(fixture, options, expected_failure, "%s corruption is rejected" % field)


func _expect_fixture_valid(fixture: Dictionary, options: Dictionary, message: String) -> void:
	var text := JSON.stringify(fixture)
	var fixture_options := options.duplicate(true)
	fixture_options["targeted_diagnostic_ledger_fingerprint"] = text.sha256_text().to_lower()
	_expect_valid(VALIDATOR.validate_ledger_text(text, fixture_options), message)


func _expect_fixture_failure(
	fixture: Dictionary,
	options: Dictionary,
	expected_failure: String,
	message: String
) -> void:
	var text := JSON.stringify(fixture)
	var fixture_options := options.duplicate(true)
	fixture_options["targeted_diagnostic_ledger_fingerprint"] = text.sha256_text().to_lower()
	_expect_failure(VALIDATOR.validate_ledger_text(text, fixture_options), expected_failure, message)


func _expect_valid(result: Dictionary, message: String) -> void:
	_expect(bool(result.get("valid", false)), "%s (reason=%s field=%s)" % [
		message,
		str(result.get("field_reason", result.get("reason_code", "missing"))),
		str(result.get("failing_field", "missing")),
	])


func _expect_failure(result: Dictionary, expected_field: String, message: String) -> void:
	_expect(not bool(result.get("valid", true)), "%s returns invalid" % message)
	_expect(str(result.get("reason_code", "")) == "targeted_owner_capture_ledger_binding_invalid", "%s preserves generic public reason" % message)
	_expect(str(result.get("failing_field", "")) == expected_field, "%s reports exact field (actual=%s)" % [
		message,
		str(result.get("failing_field", "missing")),
	])


func _options_for(ledger: Dictionary, fingerprint: String) -> Dictionary:
	return {
		"run_id": str(ledger.get("run_id", "")),
		"head_sha": str(ledger.get("repository_head", "")),
		"scenario_fingerprint": str(ledger.get("scenario_fingerprint", "")),
		"timeout_policy_fingerprint": str(ledger.get("role_timeout_policy_sha256", "")),
		"launch_nonce": str(ledger.get("launch_nonce", "")),
		"targeted_diagnostic_ledger_fingerprint": fingerprint,
	}


func _argument_value(prefix: String) -> String:
	for arguments in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for argument_variant in arguments:
			var argument := str(argument_variant)
			if argument.begins_with(prefix):
				return argument.trim_prefix(prefix)
	return ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("COLD_RESTORE_TARGETED_LEDGER_BINDING_REPLAY_TEST|status=%s|checks=%d|failures=%d|diagnostic_count_delta=0|quota_claim_count=0|session_create_count=0|save_write_count=0|owner_capture_count=0|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
