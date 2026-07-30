extends SceneTree

const DRIVER := preload("res://scripts/tools/cold_restore_vertical_slice_driver.gd")

const HEAD_SHA := "1234567890abcdef1234567890abcdef12345678"
const OTHER_HEAD_SHA := "abcdef1234567890abcdef1234567890abcdef12"
const SCENARIO_FINGERPRINT := "0bccef8426345e2ea1fd8ae7d6187d282d52d44bc73d6fb3d1ed3375dc20b7bf"
const OTHER_SCENARIO_FINGERPRINT := "1111111111111111111111111111111111111111111111111111111111111111"
const TIMEOUT_POLICY_SHA256 := "2222222222222222222222222222222222222222222222222222222222222222"
const ADMISSION_LEDGER_SHA256 := "3333333333333333333333333333333333333333333333333333333333333333"
const LAUNCH_NONCE := "44444444444444444444444444444444"
const OTHER_LAUNCH_NONCE := "55555555555555555555555555555555"
const REHEARSAL_LEDGER_RELATIVE_PATH := \
		"codex/cold_restore_v3/non-official-alpha04c-process-a-rehearsal-v1/process_a_rehearsal_quota_ledger.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run_callable_option_matrix()
	_run_source_authorization_contract()
	var passed := _failures.is_empty()
	print("PROCESS_A_REHEARSAL_LAUNCH_AUTHORIZATION_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)


func _run_callable_option_matrix() -> void:
	var rehearsal := _valid_rehearsal_options()
	_expect_valid(
		rehearsal,
		"non-official Process A rehearsal accepts admission path/SHA and launch path/nonce together"
	)

	var missing_admission_path := rehearsal.duplicate(true)
	missing_admission_path["rehearsal_ledger_path"] = ""
	_expect_invalid(missing_admission_path, "rehearsal rejects a missing admission ledger path")

	var missing_admission_sha := rehearsal.duplicate(true)
	missing_admission_sha["rehearsal_ledger_fingerprint"] = ""
	_expect_invalid(missing_admission_sha, "rehearsal rejects a missing admission ledger SHA-256")

	var malformed_admission_sha := rehearsal.duplicate(true)
	malformed_admission_sha["rehearsal_ledger_fingerprint"] = "not-a-sha256"
	_expect_invalid(malformed_admission_sha, "rehearsal rejects a malformed admission ledger SHA-256")

	var missing_launch_path := rehearsal.duplicate(true)
	missing_launch_path["launch_attestation_path"] = ""
	_expect_invalid(missing_launch_path, "rehearsal rejects a missing launch attestation path")

	var missing_launch_nonce := rehearsal.duplicate(true)
	missing_launch_nonce["launch_nonce"] = ""
	_expect_invalid(missing_launch_nonce, "rehearsal rejects a missing launch nonce")

	var malformed_launch_nonce := rehearsal.duplicate(true)
	malformed_launch_nonce["launch_nonce"] = "xyz"
	_expect_invalid(malformed_launch_nonce, "rehearsal rejects a malformed launch nonce")

	var wrong_run := rehearsal.duplicate(true)
	wrong_run["run_id"] = "alpha04c-process-a-rehearsal-deadbeefdead"
	wrong_run["artifact_root"] = _artifact_root(str(wrong_run["run_id"]))
	_expect_invalid(wrong_run, "rehearsal rejects a run ID that is not derived from HEAD")

	var wrong_head := rehearsal.duplicate(true)
	wrong_head["head_sha"] = OTHER_HEAD_SHA
	_expect_invalid(wrong_head, "rehearsal rejects a HEAD that does not bind the run ID")

	var wrong_scenario := rehearsal.duplicate(true)
	wrong_scenario["scenario_fingerprint"] = OTHER_SCENARIO_FINGERPRINT
	_expect_invalid(wrong_scenario, "rehearsal rejects the wrong fixed scenario fingerprint")

	var rehearsal_with_official_claim := rehearsal.duplicate(true)
	rehearsal_with_official_claim["official_claim_path"] = _absolute_fixture_path("official-claim.json")
	_expect_invalid(rehearsal_with_official_claim, "rehearsal rejects official claim authority")

	var targeted := _valid_targeted_diagnostic_options()
	_expect_invalid(targeted, "targeted diagnostic rejects missing quota and launch authority")

	var targeted_with_admission_path := targeted.duplicate(true)
	targeted_with_admission_path["rehearsal_ledger_path"] = _fixed_admission_ledger_path()
	_expect_invalid(targeted_with_admission_path, "targeted diagnostic rejects a rehearsal admission path")

	var targeted_with_admission_sha := targeted.duplicate(true)
	targeted_with_admission_sha["rehearsal_ledger_fingerprint"] = ADMISSION_LEDGER_SHA256
	_expect_invalid(targeted_with_admission_sha, "targeted diagnostic rejects a rehearsal admission SHA-256")

	var targeted_with_launch_path := targeted.duplicate(true)
	targeted_with_launch_path["launch_attestation_path"] = _absolute_fixture_path("targeted-launch.json")
	_expect_invalid(targeted_with_launch_path, "targeted diagnostic rejects launch attestation authority")

	var targeted_with_launch_nonce := targeted.duplicate(true)
	targeted_with_launch_nonce["launch_nonce"] = LAUNCH_NONCE
	_expect_invalid(targeted_with_launch_nonce, "targeted diagnostic rejects a launch nonce")

	var targeted_with_rehearsal_mode := targeted.duplicate(true)
	targeted_with_rehearsal_mode["process_a_rehearsal"] = true
	_expect_invalid(targeted_with_rehearsal_mode, "targeted diagnostic and rehearsal modes remain mutually exclusive")

	var official := _valid_official_options()
	_expect_valid(official, "official option validation remains accepted with claim and launch authority")

	var official_with_rehearsal := official.duplicate(true)
	official_with_rehearsal["process_a_rehearsal"] = true
	_expect_invalid(official_with_rehearsal, "official execution cannot be relabeled as a rehearsal")

	var official_with_admission := official.duplicate(true)
	official_with_admission["rehearsal_ledger_path"] = _fixed_admission_ledger_path()
	official_with_admission["rehearsal_ledger_fingerprint"] = ADMISSION_LEDGER_SHA256
	_expect_invalid(official_with_admission, "official execution rejects rehearsal admission authority")


func _run_source_authorization_contract() -> void:
	var source := FileAccess.get_file_as_string(
		ProjectSettings.globalize_path("res://scripts/tools/cold_restore_vertical_slice_driver.gd")
	)
	_expect(not source.is_empty(), "driver source is readable")

	var parse_source := _function_source(source, "func _parse_options(")
	_expect(not parse_source.is_empty(), "option parser source is discoverable")
	for required_option in [
		"--cold-restore-rehearsal-ledger-path=",
		"--cold-restore-rehearsal-ledger-fingerprint=",
		"--cold-restore-launch-attestation-path=",
		"--cold-restore-launch-nonce=",
	]:
		_expect(parse_source.contains(required_option), "option parser recognizes %s" % required_option)

	var validation_source := _function_source(source, "static func validate_options(")
	_expect(not validation_source.is_empty(), "static option validation source is discoverable")
	var nonofficial_start := validation_source.find("if non_official_process_a:")
	var rehearsal_start := validation_source.find("if process_a_rehearsal:", nonofficial_start)
	var rehearsal_end := validation_source.find("elif not rehearsal_ledger_path.is_empty()", rehearsal_start)
	var rehearsal_validation := validation_source.substr(
		rehearsal_start,
		rehearsal_end - rehearsal_start
	) if rehearsal_start >= 0 and rehearsal_end > rehearsal_start else ""
	_expect(
		not validation_source.substr(nonofficial_start, maxi(0, rehearsal_start - nonofficial_start)) \
				.contains("or not launch_attestation_path.is_empty()"),
		"non-official validation does not blanket-forbid rehearsal launch attestation authority"
	)
	_expect(
		rehearsal_validation.contains("rehearsal_ledger_path") \
				and rehearsal_validation.contains("rehearsal_ledger_fingerprint"),
		"rehearsal option branch requires admission ledger path and SHA-256"
	)
	_expect(
		rehearsal_validation.contains("launch_attestation_path") \
				and rehearsal_validation.contains("launch_nonce"),
		"rehearsal option branch requires launch attestation path and nonce"
	)
	_expect(
		rehearsal_validation.contains("launch_nonce.length() != 32") \
				and rehearsal_validation.contains("_is_lower_hex(launch_nonce)"),
		"rehearsal option branch validates launch nonce shape"
	)

	var rehearsal_authorization := _function_source(source, "func _authorize_process_a_rehearsal(")
	_expect(not rehearsal_authorization.is_empty(), "rehearsal authorization source is discoverable")
	_expect(
		rehearsal_authorization.contains("_resolve_rehearsal_ledger_path()") \
				and rehearsal_authorization.contains("process_a_rehearsal_ledger_path_mismatch"),
		"rehearsal admission ledger is anchored to the fixed git-common path"
	)
	_expect(
		rehearsal_authorization.contains("ledger_text.sha256_text()") \
				and rehearsal_authorization.contains('options.get("rehearsal_ledger_fingerprint"'),
		"rehearsal admission validates the exact ledger file SHA-256"
	)
	_expect(
		rehearsal_authorization.contains("ProcessARehearsalAdmissionLedgerV2") \
				and rehearsal_authorization.contains('ledger.get("status", "")') \
				and rehearsal_authorization.contains('!= "admitted"'),
		"rehearsal consumes the V2 admission ledger rather than the legacy quota schema"
	)
	_expect(
		rehearsal_authorization.contains('ledger.get("run_id", "")') \
				and rehearsal_authorization.contains('ledger.get("repository_head", "")') \
				and rehearsal_authorization.contains('ledger.get("scenario_fingerprint", "")'),
		"rehearsal admission binds run ID, HEAD, and scenario"
	)
	for diagnostic_identity_field in [
		"diagnostic_launch_attestation_sha256",
		"diagnostic_manifest_sha256",
		"diagnostic_engine_process_id",
		"diagnostic_engine_creation_time_utc_ticks",
	]:
		_expect(
			rehearsal_authorization.contains('ledger.get("%s"' % diagnostic_identity_field),
			"rehearsal admission validates diagnostic identity field %s" % diagnostic_identity_field
		)
	_expect(
		rehearsal_authorization.contains('ledger.get("rehearsal_only"') \
				and rehearsal_authorization.contains('ledger.get("official"') \
				and rehearsal_authorization.contains('ledger.get("formal"'),
		"rehearsal admission rejects official or formal ledger state"
	)
	_expect(
		rehearsal_authorization.contains('options.get("launch_attestation_path"') \
				and rehearsal_authorization.contains("FileAccess.file_exists"),
		"rehearsal authorization reads the launch attestation selected by options"
	)
	_expect(
		rehearsal_authorization.contains("LAUNCH_ATTESTATION_FIELDS") \
				and rehearsal_authorization.contains("_has_exact_fields"),
		"rehearsal launch attestation uses the closed field set"
	)
	_expect(
		rehearsal_authorization.contains("_expected_launch_attestation_path(") \
				and rehearsal_authorization.contains("launch_attestation_path"),
		"rehearsal launch attestation is anchored to the fixed run/role/orchestrator path"
	)
	_expect(
		rehearsal_authorization.contains('attestation.get("launch_nonce", "")') \
				and rehearsal_authorization.contains('options.get("launch_nonce", "")'),
		"rehearsal rejects a launch attestation carrying a missing or wrong nonce"
	)
	_expect(
		rehearsal_authorization.contains('attestation.get("run_id", "")') \
				and rehearsal_authorization.contains('attestation.get("source_head_sha", "")') \
				and rehearsal_authorization.contains('attestation.get("scenario_fingerprint", "")'),
		"rehearsal launch attestation binds run ID, HEAD, and scenario"
	)
	_expect(
		rehearsal_authorization.contains('attestation.get("authorization_id", "")') \
				and rehearsal_authorization.contains("REHEARSAL_AUTHORIZATION_ID"),
		"rehearsal launch attestation cannot substitute official authorization fields"
	)
	_expect(
		rehearsal_authorization.contains("engine_process_id != OS.get_process_id()"),
		"rehearsal rejects a forged engine PID instead of trusting JSON identity"
	)
	_expect(
		rehearsal_authorization.contains("wrapper_parent_process_id == orchestrator_process_id") \
				and rehearsal_authorization.contains("engine_parent_process_id"),
		"rehearsal rejects incorrect wrapper/engine PID parent relationships"
	)
	_expect(
		rehearsal_authorization.contains("wrapper_creation_time_utc_ticks") \
				and rehearsal_authorization.contains("engine_creation_time_utc_ticks") \
				and rehearsal_authorization.contains("_is_positive_decimal"),
		"rehearsal rejects forged or malformed process creation identities"
	)

	var official_authorization := _function_source(source, "func _authorize_official_launch(")
	_expect(not official_authorization.is_empty(), "official launch authorization remains discoverable")
	_expect(
		official_authorization.contains("_resolve_official_claim_path()") \
				and official_authorization.contains("_expected_launch_attestation_path("),
		"official launch remains bound to fixed claim and attestation paths"
	)
	_expect(
		official_authorization.contains('attestation.get("launch_nonce", "")') \
				and official_authorization.contains('options.get("launch_nonce", "")'),
		"official launch nonce binding remains intact"
	)
	_expect(
		official_authorization.contains("engine_process_id != OS.get_process_id()") \
				and official_authorization.contains("process_relation_valid"),
		"official engine PID and parent relationship checks remain intact"
	)
	_expect(
		source.contains("var launch_authorization := await _authorize_official_launch") \
				and source.contains("_authorize_process_a_rehearsal(validation"),
		"official and rehearsal execution keep separate authorization branches"
	)


func _valid_rehearsal_options() -> Dictionary:
	var run_id := "alpha04c-process-a-rehearsal-%s" % HEAD_SHA.left(12)
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
		"targeted_owner_capture_diagnostic": false,
		"process_a_rehearsal": true,
		"rehearsal_ledger_path": _fixed_admission_ledger_path(),
		"rehearsal_ledger_fingerprint": ADMISSION_LEDGER_SHA256,
		"parse_error": "",
	}


func _valid_targeted_diagnostic_options() -> Dictionary:
	var run_id := "alpha04c-owner-capture-diagnostic-%s" % HEAD_SHA.left(12)
	return {
		"run_id": run_id,
		"process_role": "producer",
		"head_sha": HEAD_SHA,
		"artifact_root": _artifact_root(run_id),
		"official_claim_path": "",
		"launch_attestation_path": "",
		"launch_nonce": "",
		"expected_queue_resolution_id": 0,
		"expected_queue_stable_target_fingerprint": "",
		"scenario_fingerprint": SCENARIO_FINGERPRINT,
		"timeout_policy_fingerprint": TIMEOUT_POLICY_SHA256,
		"non_official_process_a": true,
		"targeted_owner_capture_diagnostic": true,
		"process_a_rehearsal": false,
		"rehearsal_ledger_path": "",
		"rehearsal_ledger_fingerprint": "",
		"parse_error": "",
	}


func _valid_official_options() -> Dictionary:
	var run_id := "alpha04c-official-option-control"
	return {
		"run_id": run_id,
		"process_role": "producer",
		"head_sha": HEAD_SHA,
		"artifact_root": _artifact_root(run_id),
		"official_claim_path": _absolute_fixture_path("official-claim.json"),
		"launch_attestation_path": _absolute_fixture_path("official-launch.json"),
		"launch_nonce": OTHER_LAUNCH_NONCE,
		"expected_queue_resolution_id": 0,
		"expected_queue_stable_target_fingerprint": "",
		"scenario_fingerprint": SCENARIO_FINGERPRINT,
		"timeout_policy_fingerprint": TIMEOUT_POLICY_SHA256,
		"non_official_process_a": false,
		"targeted_owner_capture_diagnostic": false,
		"process_a_rehearsal": false,
		"rehearsal_ledger_path": "",
		"rehearsal_ledger_fingerprint": "",
		"parse_error": "",
	}


func _expect_valid(options: Dictionary, message: String) -> void:
	var report: Dictionary = DRIVER.validate_options(options)
	_expect(
		bool(report.get("valid", false)),
		"%s (reason=%s)" % [message, str(report.get("reason_code", "missing"))]
	)


func _expect_invalid(options: Dictionary, message: String) -> void:
	var report: Dictionary = DRIVER.validate_options(options)
	_expect(
		not bool(report.get("valid", false)),
		"%s (unexpected reason=%s)" % [message, str(report.get("reason_code", "missing"))]
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _artifact_root(run_id: String) -> String:
	return "user://test_runs/alpha04c/%s/evidence" % run_id


func _absolute_fixture_path(file_name: String) -> String:
	return ProjectSettings.globalize_path("user://process_a_rehearsal_launch_authorization/%s" % file_name)


func _fixed_admission_ledger_path() -> String:
	var common_dir := _resolve_git_common_dir()
	return common_dir.path_join(REHEARSAL_LEDGER_RELATIVE_PATH).simplify_path()


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
