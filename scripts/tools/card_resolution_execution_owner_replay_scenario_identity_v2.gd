extends RefCounted
class_name CardResolutionExecutionOwnerReplayScenarioIdentityV2

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const PROJECTION := preload("res://scripts/tools/execution_authoritative_restore_projection_v1.gd")

const AUTHORIZATION_PATH := "res://scripts/tools/card_resolution_execution_owner_replay_authorization_v2.json"
const REPLAY_ROOT_RELATIVE_PATH := "codex/cold_restore_v3/non-official-alpha04c-card-resolution-execution-replay-v2-authoritative-parity"
const CONTRACT_ID := "CardResolutionExecutionOwnerReplayScenarioIdentityV2"
const AUTHORIZATION_ID := "alpha04c-card-resolution-execution-replay-v2-authoritative-parity"
const RUN_ID_PREFIX := "alpha04c-card-resolution-execution-replay-v2-authoritative-parity"
const RUN_ID := "alpha04c-card-resolution-execution-replay-v2-authoritative-parity-attempt-2"
const SCENE_PATH := "res://scenes/main.tscn"
const REGISTRY_ID := "v06_save_owner_registry"
const PRODUCTION_RUNTIME_RULESET_ID := "v0.6"
const HIGHEST_TARGET_RULESET_ID := "v0.7.3"
const SCENARIO_IDENTITY_AUTHORITY := "production_runtime_ruleset_id"
const CHALLENGE_DEPTH := 1
const RUN_SEED := 900626424
const LOCAL_PLAYER_COUNT := 1
const AI_PLAYER_COUNT := 3
const OWNER_INDEX := 13
const SECTION_ID := "card_resolution_execution"
const OWNER_ID := "card_resolution_execution"
const SAVE_SCHEMA_VERSION := 4
const EXECUTION_WIRE_VERSION := 1
const TRANSITION_STATE_WIRE_VERSION := 2
const REGISTRY_STATE_VERSION := 2
const CHECKPOINT_STRATEGY := "registry_managed_checkpoint"
const AUTHORITY_SOURCE := "save_v4_and_typed_authoritative_queries"
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
	"replay_v1_child_sha256",
	"replay_v1_parent_sha256",
	"replay_v1_claim_sha256",
	"replay_v1_consumed_admission_sha256",
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
	"execution_save_schema_version",
	"execution_wire_version",
	"transition_state_wire_version",
	"execution_registry_state_version",
	"execution_checkpoint_strategy",
	"restore_projection_schema_version",
	"restore_parity_authority_source",
	"debug_snapshot_used_as_restore_authority",
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
			or str(value.get("contract_id", "")) != "CardResolutionExecutionOwnerReplayAuthorizationV2" \
			or str(value.get("authorization_id", "")) != AUTHORIZATION_ID \
			or str(value.get("run_id_prefix", "")) != RUN_ID_PREFIX \
			or str(value.get("run_id", "")) != RUN_ID \
			or not _json_integer_equals(value.get("replay_attempt_count_before"), 1) \
			or not _json_integer_equals(value.get("authorized_new_replay_count"), 1) \
			or not _json_integer_equals(value.get("replay_attempt_count_after"), 2) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_before"), 7) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_after"), 7):
		return {}
	for field in [
		"replay_v1_child_sha256",
		"replay_v1_parent_sha256",
		"replay_v1_claim_sha256",
		"replay_v1_consumed_admission_sha256",
	]:
		if not _lower_hex(str(value.get(field, "")), 64):
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
		"execution_save_schema_version": source.get("execution_save_schema_version", -1),
		"execution_wire_version": source.get("execution_wire_version", -1),
		"transition_state_wire_version": source.get("transition_state_wire_version", -1),
		"execution_registry_state_version": source.get("execution_registry_state_version", -1),
		"execution_checkpoint_strategy": source.get("execution_checkpoint_strategy", ""),
		"restore_projection_schema_version": PROJECTION.PROJECTION_SCHEMA_VERSION,
		"restore_parity_authority_source": AUTHORITY_SOURCE,
		"debug_snapshot_used_as_restore_authority": false,
	}
	return WIRE.sealed_copy(unsealed, "identity_fingerprint")


static func validation_report(value: Variant, expected_repository_head := "") -> Dictionary:
	var auth := authorization()
	if auth.is_empty():
		return _rejected("execution_replay_v2_authorization_invalid")
	if not (value is Dictionary):
		return _rejected("execution_replay_v2_scenario_identity_not_dictionary")
	var identity := value as Dictionary
	if not _has_exact_fields(identity, IDENTITY_FIELDS) \
			or not WIRE.is_closed_data(identity) \
			or not _identity_scalar_types_are_exact(identity) \
			or int(identity.get("schema_version")) != 1 \
			or str(identity.get("contract_id")) != CONTRACT_ID \
			or str(identity.get("authorization_id")) != str(auth.get("authorization_id")) \
			or str(identity.get("replay_id")) != str(auth.get("run_id")) \
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
			or int(identity.get("execution_save_schema_version")) != SAVE_SCHEMA_VERSION \
			or int(identity.get("execution_wire_version")) != EXECUTION_WIRE_VERSION \
			or int(identity.get("transition_state_wire_version")) != TRANSITION_STATE_WIRE_VERSION \
			or int(identity.get("execution_registry_state_version")) != REGISTRY_STATE_VERSION \
			or str(identity.get("execution_checkpoint_strategy")) != CHECKPOINT_STRATEGY \
			or int(identity.get("restore_projection_schema_version")) != PROJECTION.PROJECTION_SCHEMA_VERSION \
			or str(identity.get("restore_parity_authority_source")) != AUTHORITY_SOURCE \
			or bool(identity.get("debug_snapshot_used_as_restore_authority")) \
			or str(identity.get("identity_fingerprint")) != WIRE.fingerprint(identity, "identity_fingerprint"):
		return _rejected("execution_replay_v2_scenario_identity_invalid")
	return {"valid": true, "reason_code": "execution_replay_v2_scenario_identity_valid"}


static func authorized_replay_root() -> String:
	var common_dir := _git_common_dir()
	return "" if common_dir.is_empty() else _normalize_absolute_path(common_dir.path_join(REPLAY_ROOT_RELATIVE_PATH))


static func _identity_scalar_types_are_exact(identity: Dictionary) -> bool:
	for field in [
		"contract_id", "authorization_id", "replay_id", "repository_head", "scene_path",
		"registry_id", "production_runtime_ruleset_id", "highest_target_ruleset_id",
		"scenario_identity_authority", "section_id", "owner_id",
		"execution_checkpoint_strategy", "restore_parity_authority_source", "identity_fingerprint",
	]:
		if not (identity.get(field) is String):
			return false
	for field in [
		"schema_version", "challenge_depth", "run_seed", "local_player_count", "ai_player_count",
		"owner_index", "execution_save_schema_version", "execution_wire_version",
		"transition_state_wire_version", "execution_registry_state_version", "restore_projection_schema_version",
	]:
		if not (identity.get(field) is int):
			return false
	return identity.get("highest_target_ruleset_used_as_runtime_identity") is bool \
			and identity.get("debug_snapshot_used_as_restore_authority") is bool


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant: Variant in fields:
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
