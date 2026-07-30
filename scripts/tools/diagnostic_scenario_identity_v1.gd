extends RefCounted

const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const IDENTITY_ID := "DiagnosticScenarioIdentityV1"
const DIAGNOSTIC_ROLE := "targeted_owner_diagnostic"
const EXPECTED_RULESET_ID := "v0.6"
const EXPECTED_CHALLENGE_DEPTH := 1
const EXPECTED_RUN_SEED := 900626424
const EXPECTED_LOCAL_PLAYER_COUNT := 1
const EXPECTED_AI_PLAYER_COUNT := 3
const FIELDS := [
	"schema_version", "identity_id", "run_id", "repository_head",
	"ruleset_id", "ruleset_fingerprint", "challenge_depth",
	"run_seed_tagged_int64", "session_seed_tagged_int64", "scenario_fingerprint",
	"local_player_count", "ai_player_count", "roster_fingerprint",
	"session_id", "session_generation", "session_plan_fingerprint", "world_revision",
	"runtime_composition_fingerprint", "save_registry_fingerprint",
	"user_data_path_fingerprint", "diagnostic_role", "identity_fingerprint",
]
const FAILURE_FIELDS := [
	"schema_version", "failure_field", "reason_code", "expected_summary",
	"actual_summary", "private_payload_redacted",
]


static func build(source: Dictionary) -> Dictionary:
	var unsealed := {
		"schema_version": 1,
		"identity_id": IDENTITY_ID,
		"run_id": str(source.get("run_id", "")),
		"repository_head": str(source.get("repository_head", "")),
		"ruleset_id": str(source.get("ruleset_id", "")),
		"ruleset_fingerprint": str(source.get("ruleset_fingerprint", "")),
		"challenge_depth": int(source.get("challenge_depth", -1)),
		"run_seed_tagged_int64": tagged_int64(source.get("run_seed", 0)),
		"session_seed_tagged_int64": tagged_int64(source.get("session_seed", 0)),
		"scenario_fingerprint": str(source.get("scenario_fingerprint", "")),
		"local_player_count": int(source.get("local_player_count", -1)),
		"ai_player_count": int(source.get("ai_player_count", -1)),
		"roster_fingerprint": str(source.get("roster_fingerprint", "")),
		"session_id": str(source.get("session_id", "")),
		"session_generation": int(source.get("session_generation", -1)),
		"session_plan_fingerprint": str(source.get("session_plan_fingerprint", "")),
		"world_revision": int(source.get("world_revision", -1)),
		"runtime_composition_fingerprint": str(source.get("runtime_composition_fingerprint", "")),
		"save_registry_fingerprint": str(source.get("save_registry_fingerprint", "")),
		"user_data_path_fingerprint": str(source.get("user_data_path_fingerprint", "")),
		"diagnostic_role": str(source.get("diagnostic_role", DIAGNOSTIC_ROLE)),
	}
	return SEMANTIC_WIRE.sealed_copy(unsealed, "identity_fingerprint")


static func validation_report(
	value: Variant,
	expected_run_id: String = "",
	expected_repository_head: String = "",
	expected_scenario_fingerprint: String = ""
) -> Dictionary:
	if not (value is Dictionary):
		return _rejected("identity", "diagnostic_identity_not_dictionary", "dictionary", type_string(typeof(value)))
	var identity := value as Dictionary
	if not _has_exact_fields(identity, FIELDS):
		return _rejected("field_set", "diagnostic_identity_field_set_invalid", str(FIELDS.size()), str(identity.size()))
	if not (identity.get("schema_version") is int) or int(identity.get("schema_version", 0)) != 1:
		return _rejected("schema_version", "diagnostic_identity_schema_invalid", "1", _safe_summary(identity.get("schema_version")))
	if str(identity.get("identity_id", "")) != IDENTITY_ID:
		return _rejected("identity_id", "diagnostic_identity_id_mismatch", IDENTITY_ID, _safe_summary(identity.get("identity_id")))
	var run_id := str(identity.get("run_id", ""))
	if not _safe_run_id(run_id) or (not expected_run_id.is_empty() and run_id != expected_run_id):
		return _rejected("run_id", "diagnostic_identity_run_id_mismatch", _safe_summary(expected_run_id), _safe_summary(run_id))
	var head := str(identity.get("repository_head", ""))
	if not _lower_hex(head, 40, 64) or (not expected_repository_head.is_empty() and head != expected_repository_head):
		return _rejected("repository_head", "diagnostic_identity_repository_head_mismatch", _safe_summary(expected_repository_head), _safe_summary(head))
	if str(identity.get("ruleset_id", "")) != EXPECTED_RULESET_ID:
		return _rejected("ruleset_id", "diagnostic_identity_ruleset_id_mismatch", EXPECTED_RULESET_ID, _safe_summary(identity.get("ruleset_id")))
	for field in [
		"ruleset_fingerprint", "scenario_fingerprint", "roster_fingerprint",
		"session_plan_fingerprint", "runtime_composition_fingerprint",
		"save_registry_fingerprint", "user_data_path_fingerprint",
	]:
		if not _lower_hex(str(identity.get(field, "")), 64, 64):
			return _rejected(field, "diagnostic_identity_%s_invalid" % field, "sha256", _safe_summary(identity.get(field)))
	if not expected_scenario_fingerprint.is_empty() \
			and str(identity.get("scenario_fingerprint", "")) != expected_scenario_fingerprint:
		return _rejected("scenario_fingerprint", "diagnostic_identity_scenario_fingerprint_mismatch", _safe_summary(expected_scenario_fingerprint), _safe_summary(identity.get("scenario_fingerprint")))
	for field_and_expected in [
		["challenge_depth", EXPECTED_CHALLENGE_DEPTH],
		["local_player_count", EXPECTED_LOCAL_PLAYER_COUNT],
		["ai_player_count", EXPECTED_AI_PLAYER_COUNT],
	]:
		var field := str(field_and_expected[0])
		var expected := int(field_and_expected[1])
		if not (identity.get(field) is int) or int(identity.get(field, -1)) != expected:
			return _rejected(field, "diagnostic_identity_%s_mismatch" % field, str(expected), _safe_summary(identity.get(field)))
	if not _valid_tagged_int64(identity.get("run_seed_tagged_int64"), EXPECTED_RUN_SEED):
		return _rejected("run_seed_tagged_int64", "diagnostic_identity_run_seed_mismatch", str(EXPECTED_RUN_SEED), _safe_summary(identity.get("run_seed_tagged_int64")))
	if not _valid_tagged_int64(identity.get("session_seed_tagged_int64")):
		return _rejected("session_seed_tagged_int64", "diagnostic_identity_session_seed_invalid", "tagged_int64", _safe_summary(identity.get("session_seed_tagged_int64")))
	if str(identity.get("session_id", "")).is_empty():
		return _rejected("session_id", "diagnostic_identity_session_id_invalid", "nonempty", "empty")
	if not (identity.get("session_generation") is int) or int(identity.get("session_generation", -1)) < 1:
		return _rejected("session_generation", "diagnostic_identity_session_generation_invalid", ">=1", _safe_summary(identity.get("session_generation")))
	if not (identity.get("world_revision") is int) or int(identity.get("world_revision", -1)) < 0:
		return _rejected("world_revision", "diagnostic_identity_world_revision_invalid", ">=0", _safe_summary(identity.get("world_revision")))
	if str(identity.get("diagnostic_role", "")) != DIAGNOSTIC_ROLE:
		return _rejected("diagnostic_role", "diagnostic_identity_role_mismatch", DIAGNOSTIC_ROLE, _safe_summary(identity.get("diagnostic_role")))
	var expected_fingerprint := SEMANTIC_WIRE.fingerprint(identity, "identity_fingerprint")
	if expected_fingerprint.is_empty() or str(identity.get("identity_fingerprint", "")) != expected_fingerprint:
		return _rejected("identity_fingerprint", "diagnostic_identity_fingerprint_invalid", "self_consistent", _safe_summary(identity.get("identity_fingerprint")))
	return {"valid": true, "reason_code": "ok", "failure": {}}


static func tagged_int64(value: Variant) -> Dictionary:
	return {"$codec": "Int64", "value": str(int(value))}


static func _valid_tagged_int64(value: Variant, expected: Variant = null) -> bool:
	if not (value is Dictionary):
		return false
	var tagged := value as Dictionary
	if not _has_exact_fields(tagged, ["$codec", "value"]) \
			or str(tagged.get("$codec", "")) != "Int64" \
			or not (tagged.get("value") is String) \
			or not str(tagged.get("value", "")).is_valid_int():
		return false
	return expected == null or str(tagged.get("value", "")) == str(int(expected))


static func _rejected(field: String, reason: String, expected: String, actual: String) -> Dictionary:
	return {
		"valid": false,
		"reason_code": reason,
		"failure": {
			"schema_version": 1,
			"failure_field": field,
			"reason_code": reason,
			"expected_summary": expected.left(96),
			"actual_summary": actual.left(96),
			"private_payload_redacted": true,
		},
	}


static func valid_failure(value: Variant) -> bool:
	if not (value is Dictionary) or not _has_exact_fields(value as Dictionary, FAILURE_FIELDS):
		return false
	var failure := value as Dictionary
	return failure.get("schema_version") is int \
			and int(failure.get("schema_version", 0)) == 1 \
			and not str(failure.get("failure_field", "")).is_empty() \
			and str(failure.get("reason_code", "")).begins_with("diagnostic_") \
			and str(failure.get("expected_summary", "")).length() <= 96 \
			and str(failure.get("actual_summary", "")).length() <= 96 \
			and failure.get("private_payload_redacted") is bool \
			and bool(failure.get("private_payload_redacted", false))


static func _safe_summary(value: Variant) -> String:
	var text := str(value)
	if _lower_hex(text, 64, 64):
		return text.left(12)
	if value is Dictionary:
		return "dictionary:%d" % (value as Dictionary).size()
	if value is Array:
		return "array:%d" % (value as Array).size()
	return text.left(96)


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _safe_run_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-".contains(value.substr(index, 1)):
			return false
	return true


static func _lower_hex(value: String, minimum: int, maximum: int) -> bool:
	if value.length() < minimum or value.length() > maximum:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true
