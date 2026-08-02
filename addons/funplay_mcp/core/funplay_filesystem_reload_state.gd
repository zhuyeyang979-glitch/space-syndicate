@tool
extends RefCounted

const STATE_COLD := "cold"
const STATE_EDITOR_BOOTING := "editor_booting"
const STATE_INITIAL_SCAN_PENDING := "initial_scan_pending"
const STATE_INITIAL_SCAN_RUNNING := "initial_scan_running"
const STATE_READY := "ready"
const STATE_RELOAD_QUEUED := "reload_queued"
const STATE_RELOAD_RUNNING := "reload_running"
const STATE_FAILED := "failed"
const STATE_STOPPING := "stopping"
const STATE_STOPPED := "stopped"

const DEFAULT_INITIAL_SCAN_TIMEOUT_MSEC := 300000
const DEFAULT_RELOAD_TIMEOUT_MSEC := 60000
const DEFAULT_STOP_TIMEOUT_MSEC := 20000

var _state := STATE_COLD
var _filesystem_generation := 0
var _reload_generation := 0
var _initial_scan_started := false
var _initial_scan_completed := false
var _initial_scan_started_msec := 0
var _initial_ready_since_msec := -1
var _initial_scan_operation_id := ""
var _initial_scan_start_count := 0
var _initial_scan_completion_count := 0
var _first_scan_completion_signal_count := 0
var _first_scan_reload_trigger_count := 0
var _post_initial_scan_reload_deferred_tick_count := 0
var _reload_pending := false
var _pending_operation_id := ""
var _active_operation_id := ""
var _last_error: Dictionary = {}
var _requests: Dictionary = {}
var _operations: Dictionary = {}
var _active_scan_count := 0
var _active_reload_count := 0
var _active_scan_count_max := 0
var _active_reload_count_max := 0
var _duplicate_request_count := 0
var _reload_execution_count := 0
var _initial_scan_timeout_msec := DEFAULT_INITIAL_SCAN_TIMEOUT_MSEC
var _reload_timeout_msec := DEFAULT_RELOAD_TIMEOUT_MSEC
var _stop_timeout_msec := DEFAULT_STOP_TIMEOUT_MSEC
var _stopping_started_msec := 0
var _transitions: Array = []


func configure_timeouts(initial_scan_msec: int, reload_msec: int, stop_msec: int) -> void:
	_initial_scan_timeout_msec = max(1, initial_scan_msec)
	_reload_timeout_msec = max(1, reload_msec)
	_stop_timeout_msec = max(1, stop_msec)


func is_transport_poll_ready(now_msec: int, stability_msec: int) -> bool:
	return (
		_initial_scan_completed
		and _state == STATE_READY
		and _active_scan_count == 0
		and _active_reload_count == 0
		and _initial_ready_since_msec >= 0
		and now_msec - _initial_ready_since_msec >= maxi(0, stability_msec)
	)


func begin_editor_booting(now_msec: int) -> void:
	if _state != STATE_COLD:
		return
	_transition(STATE_EDITOR_BOOTING, "editor_process_started", now_msec)


func observe_editor(
	is_scanning: bool,
	initial_snapshot_ready: bool,
	editor_alive: bool,
	now_msec: int,
	completion_signal: bool = false
) -> Dictionary:
	if _initial_scan_completed and completion_signal:
		_first_scan_completion_signal_count = min(1, _first_scan_completion_signal_count + 1)
	if _state == STATE_STOPPING:
		_check_stop_timeout(now_msec)
		return get_status()
	if _state == STATE_STOPPED:
		return get_status()
	if not editor_alive:
		_fail("editor_process_exited", "Godot editor process exited.", now_msec)
		return get_status()

	if _state == STATE_COLD:
		begin_editor_booting(now_msec)

	if _state == STATE_EDITOR_BOOTING:
		_start_initial_scan(is_scanning, now_msec)

	if _state in [STATE_INITIAL_SCAN_PENDING, STATE_INITIAL_SCAN_RUNNING]:
		if now_msec - _initial_scan_started_msec > _initial_scan_timeout_msec:
			_fail("initial_scan_timeout", "Initial filesystem scan did not complete before timeout.", now_msec)
		elif is_scanning:
			if _state != STATE_INITIAL_SCAN_RUNNING:
				_transition(STATE_INITIAL_SCAN_RUNNING, "editor_filesystem_scan_observed", now_msec, _initial_scan_operation_id)
			_set_active_counts(1, 0)
		elif initial_snapshot_ready:
			_complete_initial_scan(now_msec, completion_signal)
	elif _state == STATE_RELOAD_RUNNING:
		if is_scanning:
			_set_active_counts(1, 1)
			var active_operation: Dictionary = _operations.get(_active_operation_id, {})
			var started_at_msec := int(active_operation.get("started_at_msec", now_msec))
			if now_msec - started_at_msec > _reload_timeout_msec:
				fail_reload(
					_active_operation_id,
					"filesystem_reload_timeout",
					"Filesystem reload did not complete before timeout.",
					now_msec
				)
		else:
			_complete_reload(_active_operation_id, now_msec, "filesystem_scan_completed")
	return get_status()


func request_reload(request_id: String, path: String, now_msec: int) -> Dictionary:
	var normalized_request_id := request_id.strip_edges()
	if normalized_request_id == "":
		return {
			"ok": false,
			"reason_code": "mcp_request_id_required",
		}
	if _requests.has(normalized_request_id):
		var existing_request: Dictionary = _requests[normalized_request_id]
		if str(existing_request.get("path", "")) != path.strip_edges():
			return {
				"ok": false,
				"request_id": normalized_request_id,
				"operation_id": str(existing_request.get("operation_id", "")),
				"reason_code": "mcp_request_id_collision",
				"state": _state,
			}
		_duplicate_request_count += 1
		return _request_result(normalized_request_id, true)
	if _state == STATE_FAILED:
		return {
			"ok": false,
			"request_id": normalized_request_id,
			"reason_code": str(_last_error.get("reason_code", "filesystem_reload_state_failed")),
			"state": _state,
		}
	if _state in [STATE_STOPPING, STATE_STOPPED]:
		return {
			"ok": false,
			"request_id": normalized_request_id,
			"reason_code": "filesystem_reload_stopping" if _state == STATE_STOPPING else "filesystem_reload_stopped",
			"state": _state,
		}

	var operation_id := ""
	match _state:
		STATE_READY:
			operation_id = _create_operation("queued", now_msec)
			_pending_operation_id = operation_id
			_reload_pending = true
			_transition(STATE_RELOAD_QUEUED, "reload_request_queued", now_msec, operation_id)
		STATE_RELOAD_RUNNING:
			if _pending_operation_id == "":
				_pending_operation_id = _create_operation("queued", now_msec)
			operation_id = _pending_operation_id
			_reload_pending = true
		STATE_RELOAD_QUEUED, STATE_INITIAL_SCAN_PENDING, STATE_INITIAL_SCAN_RUNNING, STATE_EDITOR_BOOTING, STATE_COLD:
			if _pending_operation_id == "":
				_pending_operation_id = _create_operation("queued", now_msec)
			operation_id = _pending_operation_id
			_reload_pending = true
			if _state in [STATE_INITIAL_SCAN_PENDING, STATE_INITIAL_SCAN_RUNNING, STATE_EDITOR_BOOTING, STATE_COLD]:
				var early_operation: Dictionary = _operations[operation_id]
				early_operation["queued_during_initial_scan"] = true
				_operations[operation_id] = early_operation
			if not (_state in [STATE_INITIAL_SCAN_PENDING, STATE_INITIAL_SCAN_RUNNING, STATE_EDITOR_BOOTING, STATE_COLD]):
				_transition(STATE_RELOAD_QUEUED, "reload_request_queued", now_msec, operation_id)
		_:
			return {
				"ok": false,
				"request_id": normalized_request_id,
				"reason_code": "filesystem_reload_invalid_state",
				"state": _state,
			}

	_attach_request(operation_id, normalized_request_id, path)
	var result := _request_result(normalized_request_id, false)
	result["should_execute"] = false
	return result


func begin_queued_reload(now_msec: int) -> Dictionary:
	if _state != STATE_RELOAD_QUEUED or _pending_operation_id == "":
		return {
			"ok": false,
			"reason_code": "filesystem_reload_not_queued",
			"state": _state,
		}
	var operation_id := _pending_operation_id
	_pending_operation_id = ""
	_reload_pending = false
	_begin_reload(operation_id, now_msec)
	return {
		"ok": true,
		"operation_id": operation_id,
		"should_execute": true,
		"state": _state,
	}


func record_post_initial_scan_reload_deferred_tick(now_msec: int) -> void:
	if _state != STATE_RELOAD_QUEUED:
		return
	_post_initial_scan_reload_deferred_tick_count += 1
	_transition(STATE_RELOAD_QUEUED, "post_initial_scan_reload_deferred_tick", now_msec, _pending_operation_id)


func complete_reload(operation_id: String, now_msec: int, completion_reason: String) -> Dictionary:
	_complete_reload(operation_id, now_msec, completion_reason)
	return get_operation(operation_id)


func fail_reload(operation_id: String, reason_code: String, message: String, now_msec: int) -> Dictionary:
	if _operations.has(operation_id):
		var operation: Dictionary = _operations[operation_id]
		operation["status"] = "failed"
		operation["completed_at_msec"] = now_msec
		operation["completion_reason"] = reason_code
		_operations[operation_id] = operation
	_fail(reason_code, message, now_msec)
	return get_operation(operation_id)


func begin_stopping(now_msec: int) -> void:
	_transition(STATE_STOPPING, "stop_requested", now_msec)
	_stopping_started_msec = now_msec
	_terminalize_operation(_initial_scan_operation_id, "cancelled", "filesystem_reload_stopping", now_msec)
	_terminalize_operation(_pending_operation_id, "cancelled", "filesystem_reload_stopping", now_msec)
	_terminalize_operation(_active_operation_id, "cancelled", "filesystem_reload_stopping", now_msec)
	_reload_pending = false
	_pending_operation_id = ""
	_active_operation_id = ""
	_set_active_counts(0, 0)


func complete_stopping(now_msec: int) -> void:
	if _state != STATE_STOPPING:
		return
	_transition(STATE_STOPPED, "stop_completed", now_msec)


func reset_after_failure(now_msec: int) -> Dictionary:
	if _state != STATE_FAILED:
		return {
			"ok": false,
			"reason_code": "filesystem_reload_reset_requires_failed_state",
			"state": _state,
		}
	_transition(STATE_COLD, "explicit_cold_recovery", now_msec)
	_filesystem_generation = 0
	_reload_generation = 0
	_initial_scan_started = false
	_initial_scan_completed = false
	_initial_scan_started_msec = now_msec
	_initial_ready_since_msec = -1
	_initial_scan_operation_id = ""
	_initial_scan_start_count = 0
	_initial_scan_completion_count = 0
	_first_scan_completion_signal_count = 0
	_first_scan_reload_trigger_count = 0
	_post_initial_scan_reload_deferred_tick_count = 0
	_reload_pending = false
	_pending_operation_id = ""
	_active_operation_id = ""
	_last_error = {}
	_requests.clear()
	_operations.clear()
	_active_scan_count_max = 0
	_active_reload_count_max = 0
	_duplicate_request_count = 0
	_reload_execution_count = 0
	_set_active_counts(0, 0)
	return {"ok": true, "state": _state}


func get_status() -> Dictionary:
	return {
		"state": _state,
		"filesystem_generation": _filesystem_generation,
		"reload_generation": _reload_generation,
		"initial_scan_started": _initial_scan_started,
		"initial_scan_completed": _initial_scan_completed,
		"initial_ready_since_msec": _initial_ready_since_msec,
		"initial_scan_operation_id": _initial_scan_operation_id,
		"initial_scan_start_count": _initial_scan_start_count,
		"initial_scan_completion_count": _initial_scan_completion_count,
		"reload_pending": _reload_pending,
		"reload_running": _state == STATE_RELOAD_RUNNING,
		"pending_operation_id": _pending_operation_id,
		"active_operation_id": _active_operation_id,
		"last_error": _last_error.duplicate(true),
		"first_scan_completion_signal_count": _first_scan_completion_signal_count,
		"first_scan_reload_trigger_count": _first_scan_reload_trigger_count,
		"post_initial_scan_reload_deferred_tick_count": _post_initial_scan_reload_deferred_tick_count,
		"active_scan_count": _active_scan_count,
		"active_reload_count": _active_reload_count,
		"active_scan_count_max": _active_scan_count_max,
		"active_reload_count_max": _active_reload_count_max,
		"duplicate_request_count": _duplicate_request_count,
		"reload_execution_count": _reload_execution_count,
		"request_count": _requests.size(),
		"operation_count": _operations.size(),
		"initial_scan_timeout_msec": _initial_scan_timeout_msec,
		"reload_timeout_msec": _reload_timeout_msec,
		"stop_timeout_msec": _stop_timeout_msec,
		"state_writer_count": 1,
		"transitions": _transitions.duplicate(true),
	}


func get_operation(operation_id: String) -> Dictionary:
	if not _operations.has(operation_id):
		return {}
	return (_operations[operation_id] as Dictionary).duplicate(true)


func get_request_result(request_id: String) -> Dictionary:
	return _request_result(request_id, false)


func _start_initial_scan(is_scanning: bool, now_msec: int) -> void:
	if _initial_scan_started:
		return
	_initial_scan_started = true
	_initial_scan_started_msec = now_msec
	_initial_scan_start_count += 1
	_filesystem_generation = 1
	_initial_scan_operation_id = "filesystem-initial-scan-1"
	_operations[_initial_scan_operation_id] = {
		"operation_id": _initial_scan_operation_id,
		"operation_type": "initial_scan",
		"status": "running" if is_scanning else "pending",
		"created_at_msec": now_msec,
		"started_at_msec": now_msec,
		"completed_at_msec": 0,
		"completion_reason": "",
		"execution_count": 1,
		"request_ids": [],
		"paths": [],
	}
	_transition(
		STATE_INITIAL_SCAN_RUNNING if is_scanning else STATE_INITIAL_SCAN_PENDING,
		"initial_scan_observed",
		now_msec,
		_initial_scan_operation_id
	)
	_set_active_counts(1 if is_scanning else 0, 0)


func _complete_initial_scan(now_msec: int, completion_signal: bool) -> void:
	if _initial_scan_completed:
		return
	_initial_scan_completed = true
	_initial_ready_since_msec = now_msec
	_initial_scan_completion_count += 1
	if completion_signal:
		_first_scan_completion_signal_count = min(1, _first_scan_completion_signal_count + 1)
	if _operations.has(_initial_scan_operation_id):
		var operation: Dictionary = _operations[_initial_scan_operation_id]
		operation["status"] = "completed"
		operation["completed_at_msec"] = now_msec
		operation["completion_reason"] = "filesystem_completion_signal" if completion_signal else "filesystem_snapshot_ready"
		_operations[_initial_scan_operation_id] = operation
	_set_active_counts(0, 0)
	if _reload_pending:
		_transition(STATE_RELOAD_QUEUED, "initial_scan_completed_with_reload_queued", now_msec, _pending_operation_id)
	else:
		_transition(STATE_READY, "initial_scan_completed", now_msec, _initial_scan_operation_id)


func _create_operation(status: String, now_msec: int) -> String:
	_reload_generation += 1
	var operation_id := "filesystem-reload-%d" % _reload_generation
	_operations[operation_id] = {
		"operation_id": operation_id,
		"operation_type": "reload",
		"status": status,
		"created_at_msec": now_msec,
		"started_at_msec": 0,
		"completed_at_msec": 0,
		"completion_reason": "",
		"execution_count": 0,
		"queued_during_initial_scan": false,
		"request_ids": [],
		"paths": [],
	}
	return operation_id


func _attach_request(operation_id: String, request_id: String, path: String) -> void:
	var operation: Dictionary = _operations.get(operation_id, {})
	var request_ids: Array = operation.get("request_ids", [])
	request_ids.append(request_id)
	operation["request_ids"] = request_ids
	var normalized_path := path.strip_edges()
	if normalized_path != "":
		var paths: Array = operation.get("paths", [])
		if not paths.has(normalized_path):
			paths.append(normalized_path)
		operation["paths"] = paths
	_operations[operation_id] = operation
	_requests[request_id] = {
		"request_id": request_id,
		"operation_id": operation_id,
		"path": normalized_path,
	}


func _begin_reload(operation_id: String, now_msec: int) -> void:
	var operation: Dictionary = _operations.get(operation_id, {})
	operation["status"] = "running"
	operation["started_at_msec"] = now_msec
	operation["execution_count"] = int(operation.get("execution_count", 0)) + 1
	operation["filesystem_generation"] = _filesystem_generation + 1
	_operations[operation_id] = operation
	_active_operation_id = operation_id
	_transition(STATE_RELOAD_RUNNING, "reload_execution_started", now_msec, operation_id)
	_filesystem_generation += 1
	_reload_execution_count += 1
	if bool(operation.get("queued_during_initial_scan", false)):
		_first_scan_reload_trigger_count = min(1, _first_scan_reload_trigger_count + 1)
	_set_active_counts(1, 1)


func _complete_reload(operation_id: String, now_msec: int, completion_reason: String) -> void:
	if operation_id == "" or not _operations.has(operation_id):
		return
	var operation: Dictionary = _operations[operation_id]
	if str(operation.get("status", "")) == "completed":
		return
	operation["status"] = "completed"
	operation["completed_at_msec"] = now_msec
	operation["completion_reason"] = completion_reason
	_operations[operation_id] = operation
	_active_operation_id = ""
	_transition(
		STATE_RELOAD_QUEUED if _reload_pending and _pending_operation_id != "" else STATE_READY,
		"reload_execution_completed",
		now_msec,
		operation_id
	)
	_set_active_counts(0, 0)


func _request_result(request_id: String, duplicate: bool) -> Dictionary:
	if not _requests.has(request_id):
		return {
			"ok": false,
			"request_id": request_id,
			"reason_code": "filesystem_reload_request_unknown",
			"state": _state,
		}
	var request: Dictionary = _requests[request_id]
	var operation_id := str(request.get("operation_id", ""))
	var operation := get_operation(operation_id)
	return {
		"ok": true,
		"request_id": request_id,
		"operation_id": operation_id,
		"status": str(operation.get("status", "")),
		"completion_reason": str(operation.get("completion_reason", "")),
		"duplicate_request": duplicate,
		"state": _state,
		"filesystem_generation": _filesystem_generation,
	}


func _set_active_counts(scan_count: int, reload_count: int) -> void:
	_active_scan_count = maxi(0, scan_count)
	_active_reload_count = maxi(0, reload_count)
	_active_scan_count_max = max(_active_scan_count_max, _active_scan_count)
	_active_reload_count_max = max(_active_reload_count_max, _active_reload_count)


func _check_stop_timeout(now_msec: int) -> void:
	if _stopping_started_msec <= 0:
		return
	if now_msec - _stopping_started_msec > _stop_timeout_msec and _last_error.is_empty():
		_fail(
			"filesystem_reload_stop_timeout",
			"Filesystem reload owner did not stop before timeout.",
			now_msec
		)


func _fail(reason_code: String, message: String, now_msec: int) -> void:
	if _last_error.is_empty():
		_last_error = {
			"reason_code": reason_code,
			"message": message,
			"failed_at_msec": now_msec,
		}
	_terminalize_operation(_initial_scan_operation_id, "failed", reason_code, now_msec)
	if _pending_operation_id != "" and _operations.has(_pending_operation_id):
		var pending: Dictionary = _operations[_pending_operation_id]
		pending["status"] = "failed"
		pending["completed_at_msec"] = now_msec
		pending["completion_reason"] = reason_code
		_operations[_pending_operation_id] = pending
	if _active_operation_id != "" and _operations.has(_active_operation_id):
		var active: Dictionary = _operations[_active_operation_id]
		active["status"] = "failed"
		active["completed_at_msec"] = now_msec
		active["completion_reason"] = reason_code
		_operations[_active_operation_id] = active
	_transition(STATE_FAILED, reason_code, now_msec, _active_operation_id if _active_operation_id != "" else _pending_operation_id)
	_reload_pending = false
	_pending_operation_id = ""
	_active_operation_id = ""
	_set_active_counts(0, 0)


func _terminalize_operation(
	operation_id: String,
	status: String,
	reason_code: String,
	now_msec: int
) -> void:
	if operation_id == "" or not _operations.has(operation_id):
		return
	var operation: Dictionary = _operations[operation_id]
	if str(operation.get("status", "")) in ["completed", "failed", "cancelled"]:
		return
	operation["status"] = status
	operation["completed_at_msec"] = now_msec
	operation["completion_reason"] = reason_code
	_operations[operation_id] = operation


func _transition(
	to_state: String,
	reason_code: String,
	now_msec: int,
	operation_id: String = ""
) -> void:
	var from_state := _state
	_state = to_state
	_transitions.append({
		"from_state": from_state,
		"to_state": to_state,
		"generation": _filesystem_generation,
		"operation_id": operation_id,
		"reason_code": reason_code,
		"at_msec": now_msec,
	})
