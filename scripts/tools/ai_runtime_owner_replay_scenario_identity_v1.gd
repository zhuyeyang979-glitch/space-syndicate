extends RefCounted
class_name AiRuntimeOwnerReplayScenarioIdentityV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCALAR := preload("res://scripts/runtime/closed_save_scalar_codec_v1.gd")

const AUTHORIZATION_PATH := "res://scripts/tools/ai_runtime_owner_replay_authorization_v1.json"
const CHARACTERIZATION_PATH := "res://reports/handoffs/alpha04c_ai_runtime_full_state_pre_v3_characterization.json"
const AUTHORITY_MATRIX_PATH := "res://docs/save/alpha04c_ai_save_field_authority_matrix.json"
const REPLAY_ROOT_RELATIVE_PATH := "codex/cold_restore_v3/non-official-alpha04c-ai-runtime-replay-v1"
const CONTRACT_ID := "AiRuntimeOwnerReplayScenarioIdentityV1"
const AUTHORIZATION_ID := "alpha04c-ai-runtime-save-v3-checkpoint-v2-replay-v1"
const RUN_ID_PREFIX := "alpha04c-ai-runtime-replay-v1"
const RUN_ID := "alpha04c-ai-runtime-replay-v1-attempt-1"
const SCENE_PATH := "res://scenes/main.tscn"
const REGISTRY_ID := "v06_save_owner_registry"
const PRODUCTION_RUNTIME_RULESET_ID := "v0.6"
const HIGHEST_TARGET_RULESET_ID := "v0.7.3"
const SCENARIO_IDENTITY_AUTHORITY := "production_runtime_ruleset_id"
const CHALLENGE_DEPTH := 1
const RUN_SEED := 900626424
const LOCAL_PLAYER_COUNT := 1
const AI_PLAYER_COUNT := 3
const OWNER_INDEX := 15
const SECTION_ID := "ai"
const OWNER_ID := "ai_runtime"
const SAVE_SCHEMA_VERSION := 3
const RUNTIME_CHECKPOINT_SCHEMA_VERSION := 2
const NEW_SESSION_CHECKPOINT_SCHEMA_VERSION := 3
const REGISTRY_STATE_VERSION := 3
const CHECKPOINT_STRATEGY := "owner_runtime_checkpoint_v2"
const AUTHORIZATION_FIELDS := [
	"schema_version",
	"contract_id",
	"authorization_id",
	"run_id_prefix",
	"run_id",
	"replay_attempt_count_before",
	"authorized_new_replay_count",
	"replay_attempt_count_after",
	"targeted_owner_capture_diagnostic_count_before",
	"targeted_owner_capture_diagnostic_count_after",
	"characterization_sha256",
	"authority_matrix_sha256",
]
const IDENTITY_FIELDS := [
	"schema_version",
	"contract_id",
	"authorization_id",
	"replay_id",
	"repository_head",
	"scene_path",
	"registry_id",
	"production_runtime_ruleset_id",
	"highest_target_ruleset_id",
	"scenario_identity_authority",
	"highest_target_ruleset_used_as_runtime_identity",
	"challenge_depth",
	"run_seed",
	"local_player_count",
	"ai_player_count",
	"owner_index",
	"section_id",
	"owner_id",
	"ai_save_schema_version",
	"ai_runtime_checkpoint_schema_version",
	"ai_new_session_checkpoint_schema_version",
	"ai_registry_state_version",
	"ai_checkpoint_strategy",
	"f64_codec_id",
	"strict_semantic_wire_required",
	"runtime_state_source",
	"identity_fingerprint",
]


static func authorization() -> Dictionary:
	if not FileAccess.file_exists(AUTHORIZATION_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTHORIZATION_PATH))
	if not (parsed is Dictionary):
		return {}
	var value := parsed as Dictionary
	if not _has_exact_fields(value, AUTHORIZATION_FIELDS) \
			or not _json_integer_equals(value.get("schema_version"), 1) \
			or str(value.get("contract_id", "")) != "AiRuntimeOwnerReplayAuthorizationV1" \
			or str(value.get("authorization_id", "")) != AUTHORIZATION_ID \
			or str(value.get("run_id_prefix", "")) != RUN_ID_PREFIX \
			or str(value.get("run_id", "")) != RUN_ID \
			or not _json_integer_equals(value.get("replay_attempt_count_before"), 0) \
			or not _json_integer_equals(value.get("authorized_new_replay_count"), 1) \
			or not _json_integer_equals(value.get("replay_attempt_count_after"), 1) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_before"), 7) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_after"), 7) \
			or not _lower_hex(str(value.get("characterization_sha256", "")), 64) \
			or not _lower_hex(str(value.get("authority_matrix_sha256", "")), 64):
		return {}
	if FileAccess.get_sha256(CHARACTERIZATION_PATH).to_lower() \
			!= str(value.get("characterization_sha256", "")) \
			or FileAccess.get_sha256(AUTHORITY_MATRIX_PATH).to_lower() \
			!= str(value.get("authority_matrix_sha256", "")):
		return {}
	return value.duplicate(true)


static func build(source: Dictionary) -> Dictionary:
	var auth := authorization()
	if auth.is_empty():
		return {}
	var unsealed := {
		"schema_version": 1,
		"contract_id": CONTRACT_ID,
		"authorization_id": auth.get("authorization_id", ""),
		"replay_id": source.get("replay_id", ""),
		"repository_head": source.get("repository_head", ""),
		"scene_path": source.get("scene_path", ""),
		"registry_id": source.get("registry_id", ""),
		"production_runtime_ruleset_id": source.get("production_runtime_ruleset_id", ""),
		"highest_target_ruleset_id": source.get("highest_target_ruleset_id", ""),
		"scenario_identity_authority": SCENARIO_IDENTITY_AUTHORITY,
		"highest_target_ruleset_used_as_runtime_identity": false,
		"challenge_depth": source.get("challenge_depth", -1),
		"run_seed": source.get("run_seed", 0),
		"local_player_count": source.get("local_player_count", -1),
		"ai_player_count": source.get("ai_player_count", -1),
		"owner_index": source.get("owner_index", -1),
		"section_id": source.get("section_id", ""),
		"owner_id": source.get("owner_id", ""),
		"ai_save_schema_version": source.get("ai_save_schema_version", -1),
		"ai_runtime_checkpoint_schema_version": source.get("ai_runtime_checkpoint_schema_version", -1),
		"ai_new_session_checkpoint_schema_version": source.get("ai_new_session_checkpoint_schema_version", -1),
		"ai_registry_state_version": source.get("ai_registry_state_version", -1),
		"ai_checkpoint_strategy": source.get("ai_checkpoint_strategy", ""),
		"f64_codec_id": SCALAR.F64_CODEC_ID,
		"strict_semantic_wire_required": true,
		"runtime_state_source": "production_runtime_loop_only",
	}
	return WIRE.sealed_copy(unsealed, "identity_fingerprint")


static func validation_report(value: Variant, expected_repository_head := "") -> Dictionary:
	var auth := authorization()
	if auth.is_empty():
		return _rejected("ai_runtime_replay_authorization_invalid")
	if not (value is Dictionary):
		return _rejected("ai_runtime_replay_scenario_identity_not_dictionary")
	var identity := value as Dictionary
	if not _has_exact_fields(identity, IDENTITY_FIELDS) \
			or not WIRE.is_closed_data(identity) \
			or not _identity_scalar_types_are_exact(identity) \
			or int(identity.get("schema_version")) != 1 \
			or str(identity.get("contract_id")) != CONTRACT_ID \
			or str(identity.get("authorization_id")) != AUTHORIZATION_ID \
			or str(identity.get("replay_id")) != RUN_ID \
			or not _lower_hex(str(identity.get("repository_head")), 40) \
			or (not expected_repository_head.is_empty() and str(identity.get("repository_head")) != expected_repository_head) \
			or str(identity.get("scene_path")) != SCENE_PATH \
			or str(identity.get("registry_id")) != REGISTRY_ID \
			or str(identity.get("production_runtime_ruleset_id")) != PRODUCTION_RUNTIME_RULESET_ID \
			or str(identity.get("highest_target_ruleset_id")) != HIGHEST_TARGET_RULESET_ID \
			or str(identity.get("scenario_identity_authority")) != SCENARIO_IDENTITY_AUTHORITY \
			or bool(identity.get("highest_target_ruleset_used_as_runtime_identity")) \
			or int(identity.get("challenge_depth")) != CHALLENGE_DEPTH \
			or int(identity.get("run_seed")) != RUN_SEED \
			or int(identity.get("local_player_count")) != LOCAL_PLAYER_COUNT \
			or int(identity.get("ai_player_count")) != AI_PLAYER_COUNT \
			or int(identity.get("owner_index")) != OWNER_INDEX \
			or str(identity.get("section_id")) != SECTION_ID \
			or str(identity.get("owner_id")) != OWNER_ID \
			or int(identity.get("ai_save_schema_version")) != SAVE_SCHEMA_VERSION \
			or int(identity.get("ai_runtime_checkpoint_schema_version")) != RUNTIME_CHECKPOINT_SCHEMA_VERSION \
			or int(identity.get("ai_new_session_checkpoint_schema_version")) != NEW_SESSION_CHECKPOINT_SCHEMA_VERSION \
			or int(identity.get("ai_registry_state_version")) != REGISTRY_STATE_VERSION \
			or str(identity.get("ai_checkpoint_strategy")) != CHECKPOINT_STRATEGY \
			or str(identity.get("f64_codec_id")) != SCALAR.F64_CODEC_ID \
			or not bool(identity.get("strict_semantic_wire_required")) \
			or str(identity.get("runtime_state_source")) != "production_runtime_loop_only" \
			or str(identity.get("identity_fingerprint")) != WIRE.fingerprint(identity, "identity_fingerprint"):
		return _rejected("ai_runtime_replay_scenario_identity_invalid")
	return {"valid": true, "reason_code": "ai_runtime_replay_scenario_identity_valid"}


static func authorized_replay_root() -> String:
	var common_dir := _git_common_dir()
	return "" if common_dir.is_empty() else _normalize_absolute_path(
		common_dir.path_join(REPLAY_ROOT_RELATIVE_PATH)
	)


static func _identity_scalar_types_are_exact(identity: Dictionary) -> bool:
	for field in [
		"contract_id", "authorization_id", "replay_id", "repository_head",
		"scene_path", "registry_id", "production_runtime_ruleset_id",
		"highest_target_ruleset_id", "scenario_identity_authority", "section_id",
		"owner_id", "ai_checkpoint_strategy", "f64_codec_id",
		"runtime_state_source", "identity_fingerprint",
	]:
		if not (identity.get(field) is String):
			return false
	for field in [
		"schema_version", "challenge_depth", "run_seed", "local_player_count",
		"ai_player_count", "owner_index", "ai_save_schema_version",
		"ai_runtime_checkpoint_schema_version", "ai_new_session_checkpoint_schema_version",
		"ai_registry_state_version",
	]:
		if not (identity.get(field) is int):
			return false
	return identity.get("highest_target_ruleset_used_as_runtime_identity") is bool \
			and identity.get("strict_semantic_wire_required") is bool


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _json_integer_equals(value: Variant, expected: int) -> bool:
	return (value is int and int(value) == expected) \
			or (value is float and is_finite(float(value)) and float(value) == float(expected))


static func _git_common_dir() -> String:
	var project_root := _normalize_absolute_path(ProjectSettings.globalize_path("res://"))
	if project_root.is_empty():
		return ""
	var git_marker := project_root.path_join(".git")
	if DirAccess.dir_exists_absolute(git_marker):
		return git_marker
	if not FileAccess.file_exists(git_marker):
		return ""
	var marker_text := FileAccess.get_file_as_string(git_marker).strip_edges()
	if not marker_text.begins_with("gitdir:"):
		return ""
	var git_dir := marker_text.trim_prefix("gitdir:").strip_edges()
	if not git_dir.is_absolute_path():
		git_dir = project_root.path_join(git_dir)
	git_dir = _normalize_absolute_path(git_dir)
	var common_file := git_dir.path_join("commondir")
	if not FileAccess.file_exists(common_file):
		return git_dir
	var common_dir := FileAccess.get_file_as_string(common_file).strip_edges()
	if not common_dir.is_absolute_path():
		common_dir = git_dir.path_join(common_dir)
	return _normalize_absolute_path(common_dir)


static func _normalize_absolute_path(value: String) -> String:
	if value.is_empty() or not value.is_absolute_path():
		return ""
	return value.replace("\\", "/").simplify_path().trim_suffix("/")


static func _rejected(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
