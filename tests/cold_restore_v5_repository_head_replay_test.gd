extends SceneTree

const LAUNCH_CONTEXT := preload(
	"res://scripts/tools/cold_restore_targeted_diagnostic_launch_context_v1.gd"
)
const REPLAY := preload(
	"res://scripts/tools/cold_restore_v5_repository_head_replay.gd"
)
const LEDGER_SHA256 := "b7e6c66852540c2b3066f86cd6e9c9d9454c185c4e8ed17d168c6b0dbf466742"
const LAUNCH_SHA256 := "f79cf007878789d3122b588309b99a27fc3231d897a058b85c7ea789ffe3ed1f"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var ledger_path := _argument_value("--v5-retained-ledger-path=")
	var launch_path := _argument_value("--v5-retained-launch-attestation-path=")
	var replay_root := _argument_value("--v5-replay-root=")
	_expect(FileAccess.file_exists(ledger_path), "retained V5 ledger exists")
	_expect(FileAccess.file_exists(launch_path), "retained V5 launch attestation exists")
	_expect(not replay_root.is_empty() and replay_root.is_absolute_path(), "replay root is isolated and absolute")
	if not _failures.is_empty():
		_finish()
		return
	var ledger_source_before := FileAccess.get_file_as_bytes(ledger_path)
	var launch_source_before := FileAccess.get_file_as_bytes(launch_path)
	_expect(_bytes_sha256(ledger_source_before) == LEDGER_SHA256, "retained V5 ledger SHA-256 is immutable")
	_expect(_bytes_sha256(launch_source_before) == LAUNCH_SHA256, "retained V5 launch SHA-256 is immutable")

	var replay := REPLAY.replay(
		ledger_path, LEDGER_SHA256, launch_path, LAUNCH_SHA256, replay_root
	)
	_expect(bool(replay.get("valid", false)), "retained V5 child-bootstrap replay is green")
	_expect(bool(replay.get("v5_retained_ledger_replay_green", false)), "retained V5 ledger passes")
	_expect(bool(replay.get("v5_child_bootstrap_binding_green", false)), "real child binding path passes")
	_expect(bool(replay.get("v5_repository_head_lineage_green", false)), "repository-head lineage is green")
	_expect(str(replay.get("v5_replay_pre_fix_field", "")) == "repository_head", "pre-fix characterization identifies repository_head")
	_expect(str(replay.get("v5_replay_pre_fix_expected_value_kind", "")) == "canonical_json_null", "pre-fix expected value is canonical JSON null")
	_expect(int(replay.get("binding_check_count", 0)) == 35, "canonical ledger validator executes all 35 checks")
	_expect(int(replay.get("binding_pass_count", 0)) == 35, "canonical ledger validator passes all 35 checks")
	_expect(int(replay.get("binding_failure_count", -1)) == 0, "canonical ledger validator has zero failures")
	for counter in [
		"replay_diagnostic_count_delta",
		"replay_quota_claim_count",
		"replay_session_create_count",
		"replay_owner_capture_count",
		"replay_save_write_count",
		"main_scene_load_count",
		"v6_artifact_create_count",
	]:
		_expect(int(replay.get(counter, -1)) == 0, "%s remains zero" % counter)

	var ledger_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(ledger_path))
	var launch_variant: Variant = JSON.parse_string(FileAccess.get_file_as_string(launch_path))
	_expect(ledger_variant is Dictionary, "retained ledger parses")
	_expect(launch_variant is Dictionary, "retained launch attestation parses")
	if not (ledger_variant is Dictionary) or not (launch_variant is Dictionary):
		_finish()
		return
	var ledger := ledger_variant as Dictionary
	var launch := launch_variant as Dictionary
	var source_context := LAUNCH_CONTEXT.build_replay_source_context(
		ledger, launch, ledger_path, LEDGER_SHA256, launch_path
	)
	_expect(bool(source_context.get("valid", false)), "immutable artifacts reconstruct the exact launch context")
	if not bool(source_context.get("valid", false)):
		_finish()
		return
	var context := source_context.get("context", {}) as Dictionary
	_expect(str(context.get("repository_head", "")) == str(ledger.get("repository_head", "")), "canonical context retains the exact repository HEAD")

	var missing := context.duplicate(true)
	missing.erase("repository_head")
	_expect_repository_head_failure(missing, "missing")
	var null_value := context.duplicate(true)
	null_value["repository_head"] = null
	_expect_repository_head_failure(null_value, "null")
	var empty := context.duplicate(true)
	empty["repository_head"] = ""
	_expect_repository_head_failure(empty, "empty")
	var wrong_type := context.duplicate(true)
	wrong_type["repository_head"] = 42
	_expect_repository_head_failure(wrong_type, "wrong_type")
	var short := context.duplicate(true)
	short["repository_head"] = "a".repeat(39)
	_expect_repository_head_failure(short, "wrong_length")
	var long := context.duplicate(true)
	long["repository_head"] = "a".repeat(41)
	_expect_repository_head_failure(long, "wrong_length")
	var non_hex := context.duplicate(true)
	non_hex["repository_head"] = "a".repeat(39) + "z"
	_expect_repository_head_failure(non_hex, "non_hex")
	var uppercase := context.duplicate(true)
	uppercase["repository_head"] = str(ledger.get("repository_head", "")).to_upper()
	_expect_repository_head_failure(uppercase, "uppercase")
	var wrong_head := context.duplicate(true)
	wrong_head["repository_head"] = "a".repeat(40)
	_expect_repository_head_failure(
		wrong_head, "value_mismatch", {"repository_head": ledger.get("repository_head")}
	)
	var alias_only := context.duplicate(true)
	alias_only.erase("repository_head")
	alias_only["source_head_sha"] = ledger.get("repository_head")
	_expect_repository_head_failure(alias_only, "missing")
	var null_override := context.duplicate(true)
	null_override.merge({"repository_head": null}, true)
	_expect_repository_head_failure(null_override, "null")

	var argument_result := LAUNCH_CONTEXT.argument_list(context)
	_expect(bool(argument_result.get("valid", false)), "GDScript emits arguments from the shared contract")
	var wrong_cli_arguments: Array[String] = []
	for entry in argument_result.get("arguments", []):
		var argument := str(entry)
		wrong_cli_arguments.append(
			argument.replace("--cold-restore-head-sha=", "--cold-restore-repository-head=")
			if argument.begins_with("--cold-restore-head-sha=") else argument
		)
	var wrong_cli := LAUNCH_CONTEXT.parse_cli_argument_list(wrong_cli_arguments)
	_expect(not bool(wrong_cli.get("valid", true)), "wrong CLI argument name fails closed")
	_expect(str(wrong_cli.get("failing_stage", "")) == "child_cli_parser", "wrong CLI name identifies parser stage")

	var launch_head_mismatch := launch.duplicate(true)
	launch_head_mismatch["source_head_sha"] = "a".repeat(40)
	_expect_launch_failure(
		LAUNCH_CONTEXT.validate_launch_attestation(
			context, launch_head_mismatch, "test_launch_attestation"
		),
		"repository_head"
	)
	var launch_authorization_mismatch := launch.duplicate(true)
	launch_authorization_mismatch["authorization_id"] = "wrong-authorization"
	_expect_launch_failure(
		LAUNCH_CONTEXT.validate_launch_attestation(
			context, launch_authorization_mismatch, "test_launch_attestation"
		),
		"authorization_id"
	)
	var launch_scenario_mismatch := launch.duplicate(true)
	launch_scenario_mismatch["scenario_fingerprint"] = "a".repeat(64)
	_expect_launch_failure(
		LAUNCH_CONTEXT.validate_launch_attestation(
			context, launch_scenario_mismatch, "test_launch_attestation"
		),
		"scenario_fingerprint"
	)

	var busy_root := "%s-busy" % replay_root
	var busy_lock := "%s.lock" % busy_root
	_expect(DirAccess.make_dir_absolute(busy_lock) == OK, "busy replay lock fixture is acquired")
	var busy_result := REPLAY.replay(
		ledger_path, LEDGER_SHA256, launch_path, LAUNCH_SHA256, busy_root
	)
	_expect(not bool(busy_result.get("valid", true)) and str(busy_result.get("reason_code", "")) == "replay_in_use", "replay refuses concurrent use")
	_expect(DirAccess.remove_absolute(busy_lock) == OK, "busy replay lock fixture is released")

	_expect(_bytes_sha256(FileAccess.get_file_as_bytes(ledger_path)) == LEDGER_SHA256, "replay never mutates V5 ledger bytes")
	_expect(_bytes_sha256(FileAccess.get_file_as_bytes(launch_path)) == LAUNCH_SHA256, "replay never mutates V5 launch bytes")
	_finish()


func _expect_repository_head_failure(
	fixture: Dictionary,
	expected_reason: String,
	expected: Dictionary = {}
) -> void:
	var report := LAUNCH_CONTEXT.validate_context(fixture, expected, "repository_head_test")
	_expect(not bool(report.get("valid", true)), "%s fixture is rejected" % expected_reason)
	_expect(str(report.get("reason_code", "")) == "targeted_owner_capture_launch_context_invalid", "%s uses typed launch-context reason" % expected_reason)
	_expect(str(report.get("failing_stage", "")) == "repository_head_test", "%s identifies the exact stage" % expected_reason)
	_expect(str(report.get("failing_field", "")) == "repository_head", "%s identifies repository_head" % expected_reason)
	_expect(str(report.get("field_reason", "")) == expected_reason, "%s is the exact field reason" % expected_reason)
	_expect(_is_lower_sha256(str(report.get("safe_expected_fingerprint", ""))) and _is_lower_sha256(str(report.get("safe_actual_fingerprint", ""))), "%s emits safe fingerprints" % expected_reason)
	var raw_value: Variant = fixture.get("repository_head") if fixture.has("repository_head") else null
	var raw_json := JSON.stringify(raw_value) if raw_value is String and not str(raw_value).is_empty() else ""
	_expect(raw_json.is_empty() or not JSON.stringify(report).contains(raw_json), "%s does not expose the supplied HEAD" % expected_reason)


func _expect_launch_failure(report: Dictionary, expected_field: String) -> void:
	_expect(not bool(report.get("valid", true)), "%s launch mismatch is rejected" % expected_field)
	_expect(str(report.get("reason_code", "")) == "targeted_owner_capture_launch_context_invalid", "%s launch mismatch uses typed reason" % expected_field)
	_expect(str(report.get("failing_stage", "")) == "test_launch_attestation", "%s launch mismatch identifies stage" % expected_field)
	_expect(str(report.get("failing_field", "")) == expected_field, "%s launch mismatch identifies field" % expected_field)
	_expect(str(report.get("field_reason", "")) == "value_mismatch", "%s launch mismatch is exact" % expected_field)


func _argument_value(prefix: String) -> String:
	for arguments in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for argument_variant in arguments:
			var argument := str(argument_variant)
			if argument.begins_with(prefix):
				return argument.trim_prefix(prefix)
	return ""


func _bytes_sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(bytes) != OK:
		return ""
	return hashing.finish().hex_encode().to_lower()


func _is_lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("COLD_RESTORE_V5_REPOSITORY_HEAD_REPLAY_TEST|status=%s|checks=%d|failures=%d|diagnostic_count_delta=0|quota_claim_count=0|session_create_count=0|owner_capture_count=0|save_write_count=0|details=%s" % [
		"PASS" if passed else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if passed else 1)
