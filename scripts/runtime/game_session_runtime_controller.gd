@tool
extends Node
class_name GameSessionRuntimeController

const STATE_IDLE := "idle"
const STATE_STARTING := "starting"
const STATE_RUNNING := "running"
const STATE_PAUSED := "paused"
const STATE_LOADING := "loading"
const STATE_FINISHED := "finished"
const STATE_ERROR := "error"

var _configured := false
var _ruleset_id := ""
var _session_state := STATE_IDLE
var _session_id := ""
var _scenario_id := ""
var _seed := 0
var _setup_summary: Dictionary = {}
var _save_state := "clean"
var _dirty_reason := ""


func configure(ruleset_snapshot: Dictionary, save_config: Dictionary = {}) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	var save_node := _save_coordinator_node()
	if save_node != null and save_node.has_method("configure"):
		if save_config.is_empty():
			save_node.call("configure")
		else:
			var current_version := int(save_node.call("save_version")) if save_node.has_method("save_version") else 0
			var current_path := str(save_node.call("default_save_path")) if save_node.has_method("default_save_path") else ""
			save_node.call("configure", int(save_config.get("save_version", current_version)), str(save_config.get("default_save_path", current_path)))
	var save_snapshot := _save_operation_snapshot()
	_configured = _ruleset_id == "v0.4" and bool(save_snapshot.get("configured", false))


func begin_session(setup_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(setup_snapshot):
		_session_state = STATE_ERROR
		_save_state = "failed"
		return session_summary()
	_session_state = STATE_STARTING
	_session_id = str(setup_snapshot.get("session_id", "session_%d" % Time.get_ticks_msec()))
	_scenario_id = str(setup_snapshot.get("scenario_id", ""))
	_seed = int(setup_snapshot.get("seed", 0))
	_setup_summary = _safe_setup_summary(setup_snapshot)
	_save_state = "dirty"
	_dirty_reason = "new_session"
	_session_state = STATE_RUNNING
	return session_summary()


func session_state() -> String:
	return _session_state


func session_summary() -> Dictionary:
	return {
		"session_state": _session_state,
		"session_id": _session_id,
		"scenario_id": _scenario_id,
		"ruleset_id": _ruleset_id,
		"seed": _seed,
		"setup": _setup_summary.duplicate(true),
		"save_state": _save_state,
		"dirty": _save_state == "dirty",
	}


func mark_dirty(reason: String = "runtime_change") -> void:
	if _session_state not in [STATE_RUNNING, STATE_PAUSED]:
		return
	_save_state = "dirty"
	_dirty_reason = reason.strip_edges()


func pause_session() -> void:
	if _session_state == STATE_RUNNING:
		_session_state = STATE_PAUSED


func resume_session() -> void:
	if _session_state == STATE_PAUSED:
		_session_state = STATE_RUNNING


func finish_session(_result_summary: Dictionary = {}) -> void:
	if _session_state != STATE_IDLE:
		_session_state = STATE_FINISHED


func request_save(path: String, domain_sections: Dictionary) -> Dictionary:
	var save_node := _save_coordinator_node()
	if not _configured or save_node == null:
		_save_state = "failed"
		return _error_result(ERR_UNCONFIGURED, path)
	_save_state = "saving"
	var payload_variant: Variant = save_node.call("compose_save_payload", session_summary(), domain_sections)
	var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
	if payload.is_empty():
		_save_state = "failed"
		return _error_result(ERR_INVALID_DATA, path)
	var result_variant: Variant = save_node.call("write_save", path, payload)
	var result: Dictionary = result_variant if result_variant is Dictionary else _error_result(ERR_CANT_CREATE, path)
	if bool(result.get("ok", false)):
		_save_state = "clean"
		_dirty_reason = ""
	else:
		_save_state = "failed"
	return result.duplicate(true)


func request_load(path: String = "") -> Dictionary:
	var save_node := _save_coordinator_node()
	if not _configured or save_node == null:
		_session_state = STATE_ERROR
		_save_state = "failed"
		return _error_result(ERR_UNCONFIGURED, path)
	_session_state = STATE_LOADING
	_save_state = "loading"
	var result_variant: Variant = save_node.call("read_save", path)
	var result: Dictionary = result_variant if result_variant is Dictionary else _error_result(ERR_INVALID_DATA, path)
	if not bool(result.get("ok", false)):
		_session_state = STATE_ERROR
		_save_state = "failed"
	return result.duplicate(true)


func complete_load(error_code: int) -> void:
	if error_code == OK:
		_session_state = STATE_RUNNING
		_save_state = "clean"
		_dirty_reason = ""
		return
	_session_state = STATE_ERROR
	_save_state = "failed"


func read_save(path: String = "") -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("read_save"):
		return _error_result(ERR_UNCONFIGURED, path)
	var result_variant: Variant = save_node.call("read_save", path)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else _error_result(ERR_INVALID_DATA, path)


func has_valid_save(path: String = "") -> bool:
	return bool(read_save(path).get("ok", false))


func compose_run_save_payload(domain_sections: Dictionary) -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("compose_save_payload"):
		return {}
	var payload_variant: Variant = save_node.call("compose_save_payload", session_summary(), domain_sections)
	return (payload_variant as Dictionary).duplicate(true) if payload_variant is Dictionary else {}


func normalize_run_save_payload(payload: Dictionary) -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("normalize_save_payload"):
		return {}
	var normalized_variant: Variant = save_node.call("normalize_save_payload", payload)
	return (normalized_variant as Dictionary).duplicate(true) if normalized_variant is Dictionary else {}


func validate_run_save_payload(payload: Dictionary) -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("validate_save_payload"):
		return {"valid": false, "error_code": ERR_UNCONFIGURED, "reason": "save coordinator unavailable"}
	var result_variant: Variant = save_node.call("validate_save_payload", payload)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {}


func build_run_save_summary(payload: Dictionary, scoring_rules: Dictionary) -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("build_save_summary"):
		return {}
	var summary_variant: Variant = save_node.call("build_save_summary", payload, scoring_rules)
	return (summary_variant as Dictionary).duplicate(true) if summary_variant is Dictionary else {}


func save_version() -> int:
	return int(_save_operation_snapshot().get("save_version", 0))


func default_save_path() -> String:
	return str(_save_operation_snapshot().get("default_save_path", ""))


func reset_state() -> void:
	_session_state = STATE_IDLE
	_session_id = ""
	_scenario_id = ""
	_seed = 0
	_setup_summary = {}
	_save_state = "clean"
	_dirty_reason = ""


func debug_snapshot() -> Dictionary:
	return {
		"session_ready": _configured,
		"session_authoritative": _configured,
		"session": session_summary(),
		"save_operation": _save_operation_snapshot(),
		"dirty_reason": _dirty_reason,
	}


func _save_coordinator_node() -> Node:
	return get_node_or_null("GameSaveRuntimeCoordinator")


func _save_operation_snapshot() -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node != null and save_node.has_method("operation_snapshot"):
		var snapshot_variant: Variant = save_node.call("operation_snapshot")
		if snapshot_variant is Dictionary:
			return (snapshot_variant as Dictionary).duplicate(true)
	return {}


func _safe_setup_summary(setup_snapshot: Dictionary) -> Dictionary:
	return {
		"player_count": int(setup_snapshot.get("player_count", 0)),
		"ai_player_count": int(setup_snapshot.get("ai_player_count", 0)),
		"difficulty": str(setup_snapshot.get("difficulty", "")),
		"mission_title": str(setup_snapshot.get("mission_title", "")),
	}


func _error_result(error_code: int, path: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"path": path,
		"exists": false,
		"payload": {},
	}


func _is_data_only(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT or value is Callable:
		return false
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
	elif value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
	return true
