extends SceneTree

const HEAD_SHA := "1234567890abcdef1234567890abcdef12345678"
const OTHER_HEAD_SHA := "abcdef1234567890abcdef1234567890abcdef12"
const SCENARIO_FINGERPRINT := "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
const OTHER_SCENARIO_FINGERPRINT := "1111111111111111111111111111111111111111111111111111111111111111"
const TIMEOUT_POLICY_SHA256 := "2222222222222222222222222222222222222222222222222222222222222222"
const QUOTA_LEDGER_SHA256 := "3333333333333333333333333333333333333333333333333333333333333333"
const OTHER_QUOTA_LEDGER_SHA256 := "4444444444444444444444444444444444444444444444444444444444444444"
const LAUNCH_NONCE := "55555555555555555555555555555555"
const OTHER_LAUNCH_NONCE := "66666666666666666666666666666666"
const OFFICIAL_ATTEMPT_1_SHA256 := "80979cf3089e46ebff6025253126b57c1dd4e522cc5f858be8d4f5915ed17458"
const PREVIOUS_QUOTA_LEDGER_SHA256 := "2dba183fe0e354370802d0f886bf40a88b7e1c0b39ddb0df18ee110821e957a1"
const TARGETED_QUOTA_LEDGER_RELATIVE_PATH := \
		"codex/cold_restore_v3/non-official-alpha04c-owner-capture-attestation-12691a8/targeted_owner_capture_quota_ledger.json"

const QUOTA_LEDGER_FIELDS := [
	"schema_version", "ledger_id", "authorization_id", "task_id", "created_at_utc", "run_id",
	"repository_head", "scenario_fingerprint", "authorized_new_diagnostic_count",
	"diagnostic_count_before", "diagnostic_count_after", "diagnostic_count_maximum",
	"previous_ledger_sha256", "role_timeout_policy_sha256",
	"official_attempt_1_claim_sha256", "official_attempt_2_claim_absent",
	"official", "formal", "official_authorization_consumed",
	"orchestrator_script_sha256", "orchestrator_process_id",
	"orchestrator_creation_time_utc_ticks", "claim_nonce", "launch_nonce", "status",
]

const LAUNCH_ATTESTATION_FIELDS := [
	"schema_version", "authorization_id", "claim_fingerprint", "claim_nonce",
	"source_head_sha", "scenario_fingerprint", "run_id", "process_role", "launch_nonce",
	"orchestrator_process_id", "orchestrator_creation_time_utc_ticks",
	"wrapper_process_id", "wrapper_parent_process_id", "wrapper_creation_time_utc_ticks",
	"engine_process_id", "engine_parent_process_id", "engine_creation_time_utc_ticks", "status",
]

var _checks := 0
var _failures: Array[String] = []
var _driver_script: Variant


func _init() -> void:
	var source := FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://scripts/tools/cold_restore_vertical_slice_driver.gd")
	)
	_run_source_authorization_contract(source)
	if source.contains("func _authorize_targeted_owner_capture_diagnostic("):
		_driver_script = ResourceLoader.load(
			"res://scripts/tools/cold_restore_vertical_slice_driver.gd",
			"GDScript",
			ResourceLoader.CACHE_MODE_IGNORE
		)
		var callable := _script_declares_method(_driver_script, "validate_options")
		_expect(callable, "Driver compiles and exposes validate_options for the callable matrix")
		if callable:
			_run_callable_option_matrix()
	else:
		_expect(false, "callable option matrix waits for targeted launch authorization implementation")
	var passed := _failures.is_empty()
	print("TARGETED_OWNER_DIAGNOSTIC_LAUNCH_AUTHORIZATION_TEST|status=%s|checks=%d|failures=%d|diagnostic_run=false|rehearsal_run=false|official_run=false|formal_run=false|smoke_run=false|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)


func _run_callable_option_matrix() -> void:
	var targeted := _valid_targeted_options()
	_expect_targeted_valid(
		targeted,
		"targeted diagnostic requires quota path/SHA and launch path/nonce together"
	)

	var missing_quota_path := targeted.duplicate(true)
	missing_quota_path["targeted_diagnostic_ledger_path"] = ""
	_expect_invalid(missing_quota_path, "targeted diagnostic rejects a missing quota ledger path")

	var missing_quota_sha := targeted.duplicate(true)
	missing_quota_sha["targeted_diagnostic_ledger_fingerprint"] = ""
	_expect_invalid(missing_quota_sha, "targeted diagnostic rejects a missing quota raw SHA-256")

	var malformed_quota_sha := targeted.duplicate(true)
	malformed_quota_sha["targeted_diagnostic_ledger_fingerprint"] = "not-a-sha256"
	_expect_invalid(malformed_quota_sha, "targeted diagnostic rejects a malformed quota raw SHA-256")

	var missing_launch_path := targeted.duplicate(true)
	missing_launch_path["launch_attestation_path"] = ""
	_expect_invalid(missing_launch_path, "targeted diagnostic rejects a missing launch attestation path")

	var missing_launch_nonce := targeted.duplicate(true)
	missing_launch_nonce["launch_nonce"] = ""
	_expect_invalid(missing_launch_nonce, "targeted diagnostic rejects a missing launch nonce")

	var malformed_launch_nonce := targeted.duplicate(true)
	malformed_launch_nonce["launch_nonce"] = "xyz"
	_expect_invalid(malformed_launch_nonce, "targeted diagnostic rejects a malformed launch nonce")

	var wrong_run := targeted.duplicate(true)
	wrong_run["run_id"] = "alpha04c-owner-capture-diagnostic-deadbeefdead"
	wrong_run["artifact_root"] = _artifact_root(str(wrong_run["run_id"]))
	_expect_invalid(wrong_run, "targeted diagnostic rejects a run ID not derived from HEAD")

	var wrong_head := targeted.duplicate(true)
	wrong_head["head_sha"] = OTHER_HEAD_SHA
	_expect_invalid(wrong_head, "targeted diagnostic rejects a HEAD not bound to the run ID")

	var wrong_scenario := targeted.duplicate(true)
	wrong_scenario["scenario_fingerprint"] = OTHER_SCENARIO_FINGERPRINT
	_expect_invalid(wrong_scenario, "targeted diagnostic rejects a scenario collision")

	var official_authority := targeted.duplicate(true)
	official_authority["official_claim_path"] = _absolute_fixture_path("official-claim.json")
	_expect_invalid(official_authority, "targeted diagnostic cannot receive official claim authority")

	var rehearsal_authority := targeted.duplicate(true)
	rehearsal_authority["rehearsal_ledger_path"] = _absolute_fixture_path("rehearsal-ledger.json")
	rehearsal_authority["rehearsal_ledger_fingerprint"] = OTHER_QUOTA_LEDGER_SHA256
	_expect_invalid(rehearsal_authority, "targeted diagnostic cannot receive rehearsal authority")


func _run_source_authorization_contract(source: String) -> void:
	_expect(not source.is_empty(), "driver source is readable")

	var parse_source := _function_source(source, "func _parse_options(")
	_expect(not parse_source.is_empty(), "option parser source is discoverable")
	_expect_contains_all(parse_source, [
		'"targeted_diagnostic_ledger_path": ""',
		'"targeted_diagnostic_ledger_fingerprint": ""',
		"--cold-restore-targeted-diagnostic-ledger-path=",
		"--cold-restore-targeted-diagnostic-ledger-fingerprint=",
		"--cold-restore-launch-attestation-path=",
		"--cold-restore-launch-nonce=",
	], "option parser accepts the quota and launch authorization quartet")

	var validation_source := _function_source(source, "static func validate_options(")
	_expect(not validation_source.is_empty(), "static option validation source is discoverable")
	_expect_contains_all(validation_source, [
		"targeted_diagnostic_ledger_path",
		"targeted_diagnostic_ledger_fingerprint",
		"launch_attestation_path",
		"launch_nonce",
		"_is_lower_sha256",
		"_is_lower_hex",
	], "targeted option validation requires typed quota and launch authority")
	_expect(
		not validation_source.contains("targeted_owner_capture_launch_authority_forbidden"),
		"targeted option validation no longer blanket-forbids launch authority"
	)
	_expect(
		validation_source.contains("targeted_owner_capture_authorization_invalid"),
		"targeted option validation exposes one closed authorization failure code"
	)

	var authorization_source := _function_source(source, "func _authorize_targeted_owner_capture_diagnostic(")
	_expect(not authorization_source.is_empty(), "targeted diagnostic authorization source is discoverable")
	_expect_contains_all(authorization_source, [
		"_resolve_targeted_diagnostic_ledger_path()",
		"ledger_path.to_lower() != expected_path.to_lower()",
		"FileAccess.file_exists",
		"JSON.parse_string",
		"_has_exact_fields",
	], "authorization reads only the fixed git-common quota ledger with a closed field set")
	var quota_fields_source := _constant_source(source, "const TARGETED_DIAGNOSTIC_LEDGER_FIELDS := [")
	_expect_contains_all(quota_fields_source, QUOTA_LEDGER_FIELDS, "Driver declares the exact quota ledger field set")
	_expect_contains_all(authorization_source, [
		"ledger_text.sha256_text()",
		'targeted_diagnostic_ledger_fingerprint',
	], "authorization binds the exact quota ledger bytes to the supplied raw SHA-256")
	_expect_contains_all(authorization_source, [
		"Alpha04C.TargetedOwnerCaptureDiagnosticQuotaLedgerV2",
		"TARGETED_DIAGNOSTIC_AUTHORIZATION_ID",
		"ALPHA_0_4_C_OWNER_CAPTURE_ATTESTATION_CURSOR_PERSISTENCE_AND_PROCESS_A_REHEARSAL",
		"consumed",
	], "authorization validates quota schema, identity, task, and consumed status")
	_expect(
		source.contains('const TARGETED_DIAGNOSTIC_AUTHORIZATION_ID := "alpha04c-targeted-owner-capture-diagnostic-v2"'),
		"targeted diagnostic authorization ID is immutable"
	)
	_expect_contains_all(authorization_source, [
		'ledger.get("run_id"',
		'ledger.get("repository_head"',
		'ledger.get("scenario_fingerprint"',
		'ledger.get("role_timeout_policy_sha256"',
		'options.get("run_id"',
		'options.get("scenario_fingerprint"',
		'options.get("timeout_policy_fingerprint"',
	], "quota is bound to the requested run, HEAD, scenario, and timeout policy")
	_expect_contains_all(authorization_source, [
		'int(ledger.get("authorized_new_diagnostic_count", 0)) != 1',
		'int(ledger.get("diagnostic_count_before", -1)) != 1',
		'int(ledger.get("diagnostic_count_after", 0)) != 2',
		'int(ledger.get("diagnostic_count_maximum", 0)) != 2',
		"previous_ledger_sha256",
		PREVIOUS_QUOTA_LEDGER_SHA256,
	], "quota enforces the authorized 1 and historical 1-to-2 count boundary")
	_expect_contains_all(authorization_source, [
		"official_attempt_1_claim_sha256",
		OFFICIAL_ATTEMPT_1_SHA256,
		"official_attempt_2_claim_absent",
		"official_authorization_consumed",
		"TYPE_BOOL",
	], "quota strictly preserves Attempt 1 and forbids Attempt 2, official, and Formal authority")
	_expect_contains_all(authorization_source, [
		"claim_nonce",
		"launch_nonce",
		"orchestrator_process_id",
		"orchestrator_creation_time_utc_ticks",
		"_is_positive_decimal",
	], "quota binds distinct nonces and the orchestrator process identity")

	_expect_contains_all(authorization_source, [
		"LAUNCH_ATTESTATION_FIELDS",
		"_expected_launch_attestation_path(",
		"launch_attestation_path",
		"authorization_id",
		"claim_fingerprint",
		"claim_nonce",
		"launch_nonce",
	], "launch attestation is fixed-path, closed-schema, and quota-authorized")
	_expect_contains_all(authorization_source, LAUNCH_ATTESTATION_FIELDS, "authorization validates every launch attestation field")
	_expect_contains_all(authorization_source, [
		'attestation.get("claim_fingerprint"',
		"ledger_fingerprint",
		'attestation.get("source_head_sha"',
		'attestation.get("scenario_fingerprint"',
		'attestation.get("run_id"',
		'attestation.get("process_role"',
		'attestation.get("launch_nonce"',
	], "launch authorization binds quota raw SHA, nonce, run, HEAD, scenario, and producer role")
	_expect_contains_all(authorization_source, [
		"wrapper_process_id",
		"wrapper_parent_process_id",
		"wrapper_creation_time_utc_ticks",
		"engine_process_id",
		"engine_parent_process_id",
		"engine_creation_time_utc_ticks",
		"engine_process_id != OS.get_process_id()",
		"process_relation_valid",
	], "launch authorization binds wrapper and engine PID, parent, and creation identities")

	var entry_source := _function_source(source, "func _run_entry(")
	_expect_contains_all(entry_source, [
		"_authorize_targeted_owner_capture_diagnostic(validation",
		"targeted_owner_capture_unauthorized",
		"quit(2)",
	], "targeted diagnostic authorization runs before product setup")
	var authorization_position := entry_source.find("_authorize_targeted_owner_capture_diagnostic(validation")
	var role_position := entry_source.find("await _run_role(")
	_expect(
		authorization_position >= 0 and role_position > authorization_position,
		"targeted diagnostic cannot enter the product path before launch authorization"
	)

	var producer_source := _function_source(source, "func _run_producer(")
	var targeted_terminal_position := producer_source.find('return _fail(base, "targeted_owner_capture_diagnostic_complete"')
	var save_position := producer_source.find("var save_barrier_operation_id")
	_expect(
		targeted_terminal_position >= 0 and save_position > targeted_terminal_position,
		"targeted diagnostic terminates before Save Intent and production Save"
	)
	_expect_contains_all(source, [
		'"targeted_owner_capture_diagnostic_writes_save": false',
		'"targeted_owner_capture_diagnostic_touches_official_claim": false',
	], "public contract forbids Save and official claim mutation")


func _valid_targeted_options() -> Dictionary:
	var run_id := "alpha04c-owner-capture-diagnostic-%s" % HEAD_SHA.left(12)
	return {
		"run_id": run_id,
		"process_role": "producer",
		"head_sha": HEAD_SHA,
		"artifact_root": _artifact_root(run_id),
		"official_claim_path": "",
		"launch_attestation_path": _absolute_fixture_path("producer.authorized.json"),
		"launch_nonce": LAUNCH_NONCE,
		"expected_queue_resolution_id": 0,
		"expected_queue_stable_target_fingerprint": "",
		"scenario_fingerprint": SCENARIO_FINGERPRINT,
		"timeout_policy_fingerprint": TIMEOUT_POLICY_SHA256,
		"non_official_process_a": true,
		"targeted_owner_capture_diagnostic": true,
		"process_a_rehearsal": false,
		"targeted_diagnostic_ledger_path": _fixed_quota_ledger_path(),
		"targeted_diagnostic_ledger_fingerprint": QUOTA_LEDGER_SHA256,
		"rehearsal_ledger_path": "",
		"rehearsal_ledger_fingerprint": "",
		"parse_error": "",
	}


func _expect_targeted_valid(options: Dictionary, message: String) -> void:
	var report_variant: Variant = _driver_script.call("validate_options", options)
	var report: Dictionary = report_variant if report_variant is Dictionary else {}
	_expect(
		bool(report.get("valid", false)),
		"%s (reason=%s)" % [message, str(report.get("reason_code", "missing"))]
	)
	if not bool(report.get("valid", false)):
		return
	_expect(not bool(report.get("official", true)), "targeted diagnostic remains nonofficial")
	_expect(not bool(report.get("official_count_consumed", true)), "targeted diagnostic cannot consume official authority")
	_expect(
		str(report.get("targeted_diagnostic_ledger_path", "")) == str(options["targeted_diagnostic_ledger_path"]),
		"validated options preserve the fixed quota ledger path"
	)
	_expect(
		str(report.get("targeted_diagnostic_ledger_fingerprint", "")) == QUOTA_LEDGER_SHA256,
		"validated options preserve the quota raw SHA-256"
	)
	_expect(str(report.get("launch_nonce", "")) == LAUNCH_NONCE, "validated options preserve the launch nonce")


func _expect_invalid(options: Dictionary, message: String) -> void:
	var report_variant: Variant = _driver_script.call("validate_options", options)
	var report: Dictionary = report_variant if report_variant is Dictionary else {}
	_expect(
		not bool(report.get("valid", false)),
		"%s (actual reason=%s)" % [message, str(report.get("reason_code", "missing"))]
	)


func _script_declares_method(script: Variant, method_name: String) -> bool:
	if script == null or not script.has_method("get_script_method_list"):
		return false
	for method_variant in script.call("get_script_method_list"):
		if method_variant is Dictionary and str((method_variant as Dictionary).get("name", "")) == method_name:
			return true
	return false


func _expect_contains_all(haystack: String, needles: Array, message: String) -> void:
	var missing: Array[String] = []
	for needle_variant in needles:
		var needle := str(needle_variant)
		if not haystack.contains(needle):
			missing.append(needle)
	_expect(missing.is_empty(), "%s (missing=%s)" % [message, JSON.stringify(missing)])


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _artifact_root(run_id: String) -> String:
	return "user://test_runs/alpha04c/%s/evidence" % run_id


func _absolute_fixture_path(file_name: String) -> String:
	return ProjectSettings.globalize_path(
		"user://targeted_owner_diagnostic_launch_authorization/%s" % file_name
	)


func _fixed_quota_ledger_path() -> String:
	var common_dir := _resolve_git_common_dir()
	return common_dir.path_join(TARGETED_QUOTA_LEDGER_RELATIVE_PATH).simplify_path()


func _resolve_git_common_dir() -> String:
	var project_root := ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path()
	var git_marker := project_root.path_join(".git")
	if DirAccess.dir_exists_absolute(git_marker):
		return git_marker
	var marker_text := FileAccess.get_file_as_string(git_marker).strip_edges()
	if not marker_text.begins_with("gitdir:"):
		return ""
	var git_dir := marker_text.trim_prefix("gitdir:").strip_edges()
	if not git_dir.is_absolute_path():
		git_dir = project_root.path_join(git_dir)
	git_dir = git_dir.replace("\\", "/").simplify_path()
	var common_marker := git_dir.path_join("commondir")
	if not FileAccess.file_exists(common_marker):
		return git_dir
	var common_dir := FileAccess.get_file_as_string(common_marker).strip_edges()
	if not common_dir.is_absolute_path():
		common_dir = git_dir.path_join(common_dir)
	return common_dir.replace("\\", "/").simplify_path()


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


func _constant_source(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var end := source.find("\n]", start + signature.length())
	if end < 0:
		return ""
	return source.substr(start, end + 2 - start)
