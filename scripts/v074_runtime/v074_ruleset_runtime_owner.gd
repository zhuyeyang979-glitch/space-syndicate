extends Node
class_name V074RulesetRuntimeOwner

const RULESET_ID := "v0.7.4"
const CONSTITUTION_ID := "space_syndicate.v074.complete"
const SAMPLE_MODE_ID := "NEW_V074_GAME"
const SAMPLE_BUILD_ID := "alpha_0_5_c2.v074.roguelike_warehouse.v1"
const SAVE_DISABLED_NOTICE := "V0.7.4样品暂不支持中途保存"
const MIN_PLAYER_COUNT := 3
const MAX_PLAYER_COUNT := 8
const CURRENT_REGION_COUNT_MIN := 6
const CURRENT_REGION_COUNT_MAX := 30
const CONSTITUTIONAL_REGION_COUNT_HARD_MAX := "none"
const GEOGRAPHY_COMPLEXITIES := ["SIMPLE", "STANDARD", "COMPLEX"]
const LAND_OCEAN_PROFILES := ["CONTINENTAL", "BALANCED", "ARCHIPELAGO"]

signal ruleset_activated(identity: Dictionary)
signal persistence_request_rejected(receipt: Dictionary)

var _activation_count := 0
var _save_request_count := 0
var _load_request_count := 0
var _last_session_id := ""


func activate_for_new_game(
	session_id: String,
	player_count: int,
	local_human_count: int = 1,
	map_request: Dictionary = {}
) -> Dictionary:
	var receipt := validate_new_game_request({
		"mode_id": SAMPLE_MODE_ID,
		"session_id": session_id,
		"player_count": player_count,
		"local_human_count": local_human_count,
		"ai_player_count": player_count - local_human_count,
		"map_request": map_request,
	})
	if not bool(receipt.get("accepted", false)):
		return receipt
	_activation_count += 1
	_last_session_id = session_id
	var identity := identity_snapshot()
	ruleset_activated.emit(identity)
	return {
		"accepted": true,
		"reason_code": "v074_new_game_ruleset_activated",
		"identity": identity,
		"map_request": (receipt.get("map_request", {}) as Dictionary).duplicate(true),
	}


func validate_new_game_request(request: Dictionary) -> Dictionary:
	var mode_id := str(request.get("mode_id", ""))
	var session_id := str(request.get("session_id", "")).strip_edges()
	var player_count := int(request.get("player_count", 0))
	var local_human_count := int(request.get("local_human_count", 0))
	var ai_player_count := int(request.get("ai_player_count", -1))
	if mode_id != SAMPLE_MODE_ID:
		return _rejection("v074_new_game_only")
	if session_id.is_empty():
		return _rejection("session_id_required")
	if player_count < MIN_PLAYER_COUNT or player_count > MAX_PLAYER_COUNT:
		return _rejection("player_count_out_of_range")
	if local_human_count != 1:
		return _rejection("exactly_one_local_human_required")
	if ai_player_count != player_count - local_human_count:
		return _rejection("ai_player_count_mismatch")
	var normalized_map := normalize_map_request(
		request.get("map_request", {}) as Dictionary
	)
	if not bool(normalized_map.get("accepted", false)):
		return _rejection(str(normalized_map.get(
			"reason_code",
			"map_genesis_request_invalid"
		)))
	return {
		"accepted": true,
		"reason_code": "v074_new_game_request_valid",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"map_request": (normalized_map.get("request", {}) as Dictionary).duplicate(true),
	}


func normalize_map_request(source: Dictionary) -> Dictionary:
	var region_count := int(source.get("region_count", 16))
	var complexity := str(
		source.get("geography_complexity", "STANDARD")
	).to_upper()
	var land_ocean_profile := str(
		source.get("land_ocean_profile", "BALANCED")
	).to_upper()
	if region_count < CURRENT_REGION_COUNT_MIN 			or region_count > CURRENT_REGION_COUNT_MAX:
		return {"accepted": false, "reason_code": "region_count_out_of_supported_range"}
	if not GEOGRAPHY_COMPLEXITIES.has(complexity):
		return {"accepted": false, "reason_code": "geography_complexity_invalid"}
	if not LAND_OCEAN_PROFILES.has(land_ocean_profile):
		return {"accepted": false, "reason_code": "land_ocean_profile_invalid"}
	return {
		"accepted": true,
		"reason_code": "map_genesis_request_valid",
		"request": {
			"schema_version": 1,
			"ruleset_id": RULESET_ID,
			"map_seed": int(source.get("map_seed", source.get("seed", 900626424))),
			"region_count": region_count,
			"geography_complexity": complexity,
			"land_ocean_profile": land_ocean_profile,
		},
	}


func request_save(request_id: String) -> Dictionary:
	_save_request_count += 1
	return _reject_persistence(request_id, "save", "v074_sample_save_disabled")


func request_load(request_id: String) -> Dictionary:
	_load_request_count += 1
	return _reject_persistence(request_id, "load", "v074_sample_continue_disabled")


func identity_snapshot() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"constitution_id": CONSTITUTION_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
		"sample_build_id": SAMPLE_BUILD_ID,
		"current_production_runtime_ruleset": RULESET_ID,
		"new_game_only": true,
		"save_enabled": false,
		"continue_enabled": false,
		"save_notice": SAVE_DISABLED_NOTICE,
		"region_count_fixed": false,
		"current_supported_region_count_min": CURRENT_REGION_COUNT_MIN,
		"current_supported_region_count_max": CURRENT_REGION_COUNT_MAX,
		"constitutional_region_count_hard_max": CONSTITUTIONAL_REGION_COUNT_HARD_MAX,
		"activation_count": _activation_count,
		"last_session_id": _last_session_id,
	}


func capability_snapshot() -> Dictionary:
	return {
		"new_game": {
			"enabled": true,
			"mode_id": SAMPLE_MODE_ID,
			"map_settings": {
				"region_count": {
					"minimum": CURRENT_REGION_COUNT_MIN,
					"maximum": CURRENT_REGION_COUNT_MAX,
					"constitutional_hard_max": CONSTITUTIONAL_REGION_COUNT_HARD_MAX,
				},
				"geography_complexities": GEOGRAPHY_COMPLEXITIES.duplicate(),
				"land_ocean_profiles": LAND_OCEAN_PROFILES.duplicate(),
			},
		},
		"pause_resume_in_memory": {"enabled": true},
		"save_to_disk": {
			"enabled": false,
			"reason_code": "v074_sample_save_disabled",
			"notice": SAVE_DISABLED_NOTICE,
		},
		"continue_from_disk": {
			"enabled": false,
			"reason_code": "v074_sample_continue_disabled",
			"notice": SAVE_DISABLED_NOTICE,
		},
		"v06_save_apply_allowed": false,
		"v06_save_write_allowed": false,
		"save_dual_write_allowed": false,
	}


func debug_snapshot() -> Dictionary:
	return {
		"identity": identity_snapshot(),
		"capabilities": capability_snapshot(),
		"save_request_count": _save_request_count,
		"load_request_count": _load_request_count,
		"v06_save_file_delete_count": 0,
		"v06_save_file_overwrite_count": 0,
		"v074_v06_save_apply_count": 0,
		"v074_save_dual_write_count": 0,
		"gameplay_mutation_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
	}


func _reject_persistence(
	request_id: String,
	operation: String,
	reason_code: String
) -> Dictionary:
	var receipt := {
		"accepted": false,
		"request_id": request_id,
		"operation": operation,
		"reason_code": reason_code,
		"notice": SAVE_DISABLED_NOTICE,
		"file_access_count": 0,
	}
	persistence_request_rejected.emit(receipt)
	return receipt


func _rejection(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"ruleset_id": RULESET_ID,
	}
