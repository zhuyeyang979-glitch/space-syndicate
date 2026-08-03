extends Node
class_name V073RulesetRuntimeOwner

const RULESET_ID := "v0.7.3"
const CONSTITUTION_ID := "space_syndicate.v073.complete"
const SAMPLE_MODE_ID := "NEW_V073_GAME"
const SAMPLE_BUILD_ID := "alpha_0_5_b.v073.playable_sample.v1"
const SAVE_DISABLED_NOTICE := "V0.7.3样品暂不支持中途保存"
const MIN_PLAYER_COUNT := 3
const MAX_PLAYER_COUNT := 8

signal ruleset_activated(identity: Dictionary)
signal persistence_request_rejected(receipt: Dictionary)

var _activation_count := 0
var _save_request_count := 0
var _load_request_count := 0
var _last_session_id := ""


func activate_for_new_game(session_id: String, player_count: int, local_human_count: int = 1) -> Dictionary:
	var receipt := validate_new_game_request({
		"mode_id": SAMPLE_MODE_ID,
		"session_id": session_id,
		"player_count": player_count,
		"local_human_count": local_human_count,
		"ai_player_count": player_count - local_human_count,
	})
	if not bool(receipt.get("accepted", false)):
		return receipt
	_activation_count += 1
	_last_session_id = session_id
	var identity := identity_snapshot()
	ruleset_activated.emit(identity)
	return {
		"accepted": true,
		"reason_code": "v073_new_game_ruleset_activated",
		"identity": identity,
	}


func validate_new_game_request(request: Dictionary) -> Dictionary:
	var mode_id := str(request.get("mode_id", ""))
	var session_id := str(request.get("session_id", "")).strip_edges()
	var player_count := int(request.get("player_count", 0))
	var local_human_count := int(request.get("local_human_count", 0))
	var ai_player_count := int(request.get("ai_player_count", -1))
	if mode_id != SAMPLE_MODE_ID:
		return _rejection("v073_new_game_only")
	if session_id.is_empty():
		return _rejection("session_id_required")
	if player_count < MIN_PLAYER_COUNT or player_count > MAX_PLAYER_COUNT:
		return _rejection("player_count_out_of_range")
	if local_human_count != 1:
		return _rejection("exactly_one_local_human_required")
	if ai_player_count != player_count - local_human_count:
		return _rejection("ai_player_count_mismatch")
	return {
		"accepted": true,
		"reason_code": "v073_new_game_request_valid",
		"ruleset_id": RULESET_ID,
		"sample_mode_id": SAMPLE_MODE_ID,
	}


func request_save(request_id: String) -> Dictionary:
	_save_request_count += 1
	return _reject_persistence(request_id, "save", "v073_sample_save_disabled")


func request_load(request_id: String) -> Dictionary:
	_load_request_count += 1
	return _reject_persistence(request_id, "load", "v073_sample_continue_disabled")


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
		"activation_count": _activation_count,
		"last_session_id": _last_session_id,
	}


func capability_snapshot() -> Dictionary:
	return {
		"new_game": {"enabled": true, "mode_id": SAMPLE_MODE_ID},
		"pause_resume_in_memory": {"enabled": true},
		"save_to_disk": {
			"enabled": false,
			"reason_code": "v073_sample_save_disabled",
			"notice": SAVE_DISABLED_NOTICE,
		},
		"continue_from_disk": {
			"enabled": false,
			"reason_code": "v073_sample_continue_disabled",
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
		"v073_v06_save_apply_count": 0,
		"v073_save_dual_write_count": 0,
		"gameplay_mutation_count": 0,
	}


func _reject_persistence(request_id: String, operation: String, reason_code: String) -> Dictionary:
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
