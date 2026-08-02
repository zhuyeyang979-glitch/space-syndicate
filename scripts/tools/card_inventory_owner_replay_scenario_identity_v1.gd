extends RefCounted
class_name CardInventoryOwnerReplayScenarioIdentityV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AUTHORIZATION_PATH := "res://scripts/tools/card_inventory_owner_replay_authorization_v1.json"
const REPLAY_ROOT_RELATIVE_PATH := "codex/cold_restore_v3/non-official-alpha04c-card-inventory-replay-v2-scenario-identity"
const CONTRACT_ID := "CardInventoryOwnerReplayScenarioIdentityV1"
const AUTHORIZATION_ID := "alpha04c-v7-card-inventory-save-v4-checkpoint-v2-replay-v2-scenario-identity"
const RUN_ID_PREFIX := "alpha04c-v7-card-inventory-replay-v2-scenario-identity"
const RUN_ID := "alpha04c-v7-card-inventory-replay-v2-scenario-identity-attempt-2"
const SCENE_PATH := "res://scenes/main.tscn"
const REGISTRY_ID := "v06_save_owner_registry"
const PRODUCTION_RUNTIME_RULESET_ID := "v0.6"
const HIGHEST_TARGET_RULESET_ID := "v0.7.3"
const SCENARIO_IDENTITY_AUTHORITY := "production_runtime_ruleset_id"
const CHALLENGE_DEPTH := 1
const RUN_SEED := 900626424
const LOCAL_PLAYER_COUNT := 1
const AI_PLAYER_COUNT := 3
const OWNER_INDEX := 7
const SECTION_ID := "card_inventory"
const OWNER_ID := "card_inventory"
const SAVE_SCHEMA_VERSION := 4
const CHECKPOINT_SCHEMA_VERSION := 2
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
	"card_inventory_save_schema_version",
	"card_inventory_checkpoint_schema_version",
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
			or str(value.get("contract_id", "")) != "CardInventoryOwnerReplayAuthorizationV1" \
			or str(value.get("authorization_id", "")) != AUTHORIZATION_ID \
			or str(value.get("run_id_prefix", "")) != RUN_ID_PREFIX \
			or str(value.get("run_id", "")) != RUN_ID \
			or not _json_integer_equals(value.get("replay_attempt_count_before"), 1) \
			or not _json_integer_equals(value.get("authorized_new_replay_count"), 1) \
			or not _json_integer_equals(value.get("replay_attempt_count_after"), 2) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_before"), 7) \
			or not _json_integer_equals(value.get("targeted_owner_capture_diagnostic_count_after"), 7):
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
		"card_inventory_save_schema_version": source.get("card_inventory_save_schema_version", -1),
		"card_inventory_checkpoint_schema_version": source.get("card_inventory_checkpoint_schema_version", -1),
	}
	return WIRE.sealed_copy(unsealed, "identity_fingerprint")


static func authorized_replay_root() -> String:
	var common_dir := _git_common_dir()
	return "" if common_dir.is_empty() else _normalize_absolute_path(
		common_dir.path_join(REPLAY_ROOT_RELATIVE_PATH)
	)


static func validation_report(value: Variant, expected_repository_head: String = "") -> Dictionary:
	var auth := authorization()
	if auth.is_empty():
		return _rejected("replay_authorization_invalid")
	if not (value is Dictionary):
		return _rejected("replay_scenario_identity_not_dictionary")
	var identity := value as Dictionary
	if not _has_exact_fields(identity, IDENTITY_FIELDS) \
			or not WIRE.is_closed_data(identity) \
			or not (identity.get("schema_version") is int) \
			or int(identity.get("schema_version", 0)) != 1 \
			or not _identity_scalar_types_are_exact(identity) \
			or str(identity.get("contract_id", "")) != CONTRACT_ID \
			or str(identity.get("authorization_id", "")) != str(auth.get("authorization_id", "")) \
			or str(identity.get("replay_id", "")) != str(auth.get("run_id", "")) \
			or not _lower_hex(str(identity.get("repository_head", "")), 40) \
			or (not expected_repository_head.is_empty() and str(identity.get("repository_head", "")) != expected_repository_head) \
			or str(identity.get("scene_path", "")) != SCENE_PATH \
			or str(identity.get("registry_id", "")) != REGISTRY_ID \
			or str(identity.get("production_runtime_ruleset_id", "")) != PRODUCTION_RUNTIME_RULESET_ID \
			or str(identity.get("highest_target_ruleset_id", "")) != HIGHEST_TARGET_RULESET_ID \
			or str(identity.get("scenario_identity_authority", "")) != SCENARIO_IDENTITY_AUTHORITY \
			or not (identity.get("highest_target_ruleset_used_as_runtime_identity") is bool) \
			or bool(identity.get("highest_target_ruleset_used_as_runtime_identity", true)) \
			or int(identity.get("challenge_depth", -1)) != CHALLENGE_DEPTH \
			or int(identity.get("run_seed", 0)) != RUN_SEED \
			or int(identity.get("local_player_count", -1)) != LOCAL_PLAYER_COUNT \
			or int(identity.get("ai_player_count", -1)) != AI_PLAYER_COUNT \
			or int(identity.get("owner_index", -1)) != OWNER_INDEX \
			or str(identity.get("section_id", "")) != SECTION_ID \
			or str(identity.get("owner_id", "")) != OWNER_ID \
			or int(identity.get("card_inventory_save_schema_version", -1)) != SAVE_SCHEMA_VERSION \
			or int(identity.get("card_inventory_checkpoint_schema_version", -1)) != CHECKPOINT_SCHEMA_VERSION \
			or str(identity.get("identity_fingerprint", "")) != WIRE.fingerprint(identity, "identity_fingerprint"):
		return _rejected("replay_scenario_identity_invalid")
	return {"valid": true, "reason_code": "replay_scenario_identity_valid"}


static func _identity_scalar_types_are_exact(identity: Dictionary) -> bool:
	for field in [
		"contract_id",
		"authorization_id",
		"replay_id",
		"repository_head",
		"scene_path",
		"registry_id",
		"production_runtime_ruleset_id",
		"highest_target_ruleset_id",
		"scenario_identity_authority",
		"section_id",
		"owner_id",
		"identity_fingerprint",
	]:
		if not (identity.get(field) is String):
			return false
	for field in [
		"schema_version",
		"challenge_depth",
		"run_seed",
		"local_player_count",
		"ai_player_count",
		"owner_index",
		"card_inventory_save_schema_version",
		"card_inventory_checkpoint_schema_version",
	]:
		if not (identity.get(field) is int):
			return false
	return identity.get("highest_target_ruleset_used_as_runtime_identity") is bool


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


static func _safe_token(value: String, maximum_length: int) -> bool:
	if value.is_empty() or value.length() > maximum_length:
		return false
	for index in range(value.length()):
		if not "abcdefghijklmnopqrstuvwxyz0123456789-_.".contains(value.substr(index, 1)):
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
