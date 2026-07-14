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
var _outcome_receipt: Dictionary = {}
var _operation_sequence := 0
var _active_operation: Dictionary = {}
var _last_operation: Dictionary = {}
var _world_effective_clock: Node


func set_world_effective_clock(clock: Node) -> void:
	_world_effective_clock = clock


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
	# Session lifecycle remains available to the transitional v0.4 composition,
	# but every save operation below is strict v3/v0.6 and cannot resume v1/v2.
	_configured = _ruleset_id in ["v0.4", "v0.6"] and bool(save_snapshot.get("configured", false))


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
	_outcome_receipt = {}
	if _world_effective_clock != null and _world_effective_clock.has_method("reset_state"):
		_world_effective_clock.call("reset_state")
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
		"outcome_receipt": _outcome_receipt.duplicate(true),
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


func finish_session(result_summary: Dictionary = {}) -> void:
	if _session_state == STATE_IDLE or not _is_data_only(result_summary):
		return
	if _session_state == STATE_FINISHED and not _outcome_receipt.is_empty():
		return
	_outcome_receipt = result_summary.duplicate(true)
	_session_state = STATE_FINISHED
	_save_state = "dirty"
	_dirty_reason = "session_finished"


func is_finished() -> bool:
	return _session_state == STATE_FINISHED


func to_save_data() -> Dictionary:
	if _world_effective_clock == null or not _world_effective_clock.has_method("world_effective_micros"):
		return {}
	return {
		"game_session_runtime": {
			"schema_version": 1,
			"ruleset_id": _ruleset_id,
			"session_state": _session_state,
			"session_id": _session_id,
			"scenario_id": _scenario_id,
			"seed": _seed,
			"setup": _setup_summary.duplicate(true),
			"outcome_receipt": _outcome_receipt.duplicate(true),
			"world_effective_us": int(_world_effective_clock.call("world_effective_micros")),
		}
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var payload: Dictionary = data.get("game_session_runtime", data) if data.get("game_session_runtime", data) is Dictionary else {}
	if payload.is_empty():
		return {"applied": true, "legacy_default": true, "session_state": _session_state}
	if not _is_data_only(payload) or int(payload.get("schema_version", 0)) != 1:
		return {"applied": false, "reason": "session_save_invalid"}
	var restored_state := str(payload.get("session_state", STATE_RUNNING))
	if restored_state not in [STATE_IDLE, STATE_STARTING, STATE_RUNNING, STATE_PAUSED, STATE_LOADING, STATE_FINISHED, STATE_ERROR]:
		return {"applied": false, "reason": "session_state_invalid"}
	var has_world_clock := payload.has("world_effective_us")
	if has_world_clock and not (payload.get("world_effective_us") is int):
		return {"applied": false, "reason": "world_effective_clock_invalid"}
	var restored_world_us := int(payload.get("world_effective_us", -1))
	if has_world_clock and (restored_world_us < 0 or _world_effective_clock == null or not _world_effective_clock.has_method("restore_micros")):
		return {"applied": false, "reason": "world_effective_clock_invalid"}
	if not (payload.get("ruleset_id", _ruleset_id) is String) \
			or not (payload.get("session_id", _session_id) is String) \
			or not (payload.get("scenario_id", _scenario_id) is String) \
			or not (payload.get("seed", _seed) is int) \
			or not (payload.get("setup", {}) is Dictionary) \
			or not (payload.get("outcome_receipt", {}) is Dictionary):
		return {"applied": false, "reason": "session_payload_invalid"}
	var next_session_id := str(payload.get("session_id", _session_id))
	var next_scenario_id := str(payload.get("scenario_id", _scenario_id))
	var next_seed := int(payload.get("seed", _seed))
	var next_setup := (payload.get("setup", {}) as Dictionary).duplicate(true) if payload.get("setup", {}) is Dictionary else {}
	var next_outcome := (payload.get("outcome_receipt", {}) as Dictionary).duplicate(true) if payload.get("outcome_receipt", {}) is Dictionary else {}
	if payload.has("world_effective_us"):
		_world_effective_clock.call("restore_micros", restored_world_us)
	_session_state = restored_state
	_session_id = next_session_id
	_scenario_id = next_scenario_id
	_seed = next_seed
	_setup_summary = next_setup
	_outcome_receipt = next_outcome
	_save_state = "clean"
	_dirty_reason = ""
	return {"applied": true, "legacy_default": false, "session_state": _session_state}


func request_save(path: String, envelope: Dictionary, authorization: Dictionary = {}) -> Dictionary:
	var save_node := _save_coordinator_node()
	if not _configured or save_node == null:
		_save_state = "failed"
		return _error_result(ERR_UNCONFIGURED, path, "save_coordinator_unavailable")
	_begin_operation("write", str(envelope.get("write_id", "")), path)
	_save_state = "saving"
	var validation_variant: Variant = save_node.call("validate_envelope", envelope) if save_node.has_method("validate_envelope") else {}
	var validation: Dictionary = validation_variant if validation_variant is Dictionary else {}
	if not bool(validation.get("valid", false)):
		_save_state = "failed"
		var invalid := _error_result(ERR_INVALID_DATA, path, str(validation.get("reason_code", "v3_envelope_required")))
		_finish_operation(invalid)
		return invalid
	if authorization.is_empty() or not save_node.has_method("write_validated_envelope"):
		_save_state = "failed"
		var unauthorized := _error_result(ERR_UNAUTHORIZED, path, "write_authorization_required")
		_finish_operation(unauthorized)
		return unauthorized
	var result_variant: Variant = save_node.call("write_validated_envelope", path, envelope, authorization)
	var result: Dictionary = result_variant if result_variant is Dictionary else _error_result(ERR_CANT_CREATE, path, "save_write_invalid")
	if bool(result.get("ok", false)):
		_save_state = "clean"
		_dirty_reason = ""
	else:
		_save_state = "failed"
	_finish_operation(result)
	return result.duplicate(true)


func request_load(path: String = "") -> Dictionary:
	var save_node := _save_coordinator_node()
	if not _configured or save_node == null:
		_session_state = STATE_ERROR
		_save_state = "failed"
		return _error_result(ERR_UNCONFIGURED, path, "save_coordinator_unavailable")
	_begin_operation("read", "", path)
	_session_state = STATE_LOADING
	_save_state = "loading"
	var result_variant: Variant = save_node.call("read_and_validate", path) if save_node.has_method("read_and_validate") else {}
	var result: Dictionary = result_variant if result_variant is Dictionary else _error_result(ERR_INVALID_DATA, path, "save_read_invalid")
	if not bool(result.get("ok", false)):
		_session_state = STATE_ERROR
		_save_state = "failed"
	_finish_operation(result)
	return result.duplicate(true)


func complete_load(error_code: int) -> void:
	if error_code == OK:
		if _session_state != STATE_FINISHED:
			_session_state = STATE_RUNNING
		_save_state = "clean"
		_dirty_reason = ""
		return
	_session_state = STATE_ERROR
	_save_state = "failed"


func read_save(path: String = "") -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("read_and_validate"):
		return _error_result(ERR_UNCONFIGURED, path, "save_coordinator_unavailable")
	var result_variant: Variant = save_node.call("read_and_validate", path)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else _error_result(ERR_INVALID_DATA, path, "save_read_invalid")


func has_valid_save(path: String = "") -> bool:
	return bool(read_save(path).get("ok", false))


func compose_run_save_payload(domain_sections: Dictionary) -> Dictionary:
	var save_node := _save_coordinator_node()
	if save_node == null or not save_node.has_method("compose_save_payload"):
		return {}
	var payload_variant: Variant = save_node.call("compose_save_payload", {}, domain_sections)
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
	_outcome_receipt = {}
	_save_state = "clean"
	_dirty_reason = ""
	_active_operation = {}
	_last_operation = {}
	if _world_effective_clock != null and _world_effective_clock.has_method("reset_state"):
		_world_effective_clock.call("reset_state")


func debug_snapshot() -> Dictionary:
	return {
		"session_ready": _configured,
		"session_authoritative": _configured,
		"session": session_summary(),
		"save_operation": _save_operation_snapshot(),
		"operation_lifecycle": operation_lifecycle_snapshot(),
		"dirty_reason": _dirty_reason,
		"world_effective_clock_bound": _world_effective_clock != null and _world_effective_clock.has_method("world_effective_micros"),
	}


func operation_lifecycle_snapshot() -> Dictionary:
	return {
		"operation_sequence": _operation_sequence,
		"active": _active_operation.duplicate(true),
		"last": _last_operation.duplicate(true),
		"captures_business_state": false,
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


func _error_result(error_code: int, path: String, reason_code: String = "session_operation_failed") -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"reason_code": reason_code,
		"path": path,
	}


func _begin_operation(kind: String, operation_id: String, path: String) -> void:
	_operation_sequence += 1
	_active_operation = {
		"sequence": _operation_sequence,
		"kind": kind,
		"operation_id": operation_id,
		"path": path,
		"state": "inflight",
	}


func _finish_operation(result: Dictionary) -> void:
	_last_operation = _active_operation.duplicate(true)
	_last_operation["state"] = "complete" if bool(result.get("ok", false)) else "failed"
	_last_operation["reason_code"] = str(result.get("reason_code", "operation_complete"))
	_active_operation = {}


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
