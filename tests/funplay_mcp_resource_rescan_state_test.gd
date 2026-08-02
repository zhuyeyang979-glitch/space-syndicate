extends SceneTree

const ReloadState := preload("res://addons/funplay_mcp/core/funplay_filesystem_reload_state.gd")

var _scenario_total := 0
var _scenario_passed := 0
var _scenario_failures: Array[String] = []
var _idempotence_total := 0
var _idempotence_passed := 0


func _init() -> void:
	_test_cold_initial_ready()
	_test_early_single_reload()
	_test_early_thirty_two_reloads()
	_test_duplicate_request_id()
	_test_distinct_request_coalescing()
	_test_reload_running_followup()
	_test_initial_scan_failure()
	_test_reload_failure()
	_test_editor_exit()
	_test_endpoint_stop()
	_test_reload_timeout()
	_test_status_query_purity()
	_test_pending_reload_single_trigger()
	_test_failure_cold_recovery()
	_finish()


func _test_cold_initial_ready() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	var running: Dictionary = state.get_status()
	state.observe_editor(false, true, true, 1, true)
	var ready: Dictionary = state.get_status()
	_scenario("cold -> initial_scan_running -> ready", [
		running.get("state") == ReloadState.STATE_INITIAL_SCAN_RUNNING,
		ready.get("state") == ReloadState.STATE_READY,
		bool(ready.get("initial_scan_completed", false)),
		int(ready.get("first_scan_completion_signal_count", 0)) == 1,
	])


func _test_early_single_reload() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	var queued: Dictionary = state.request_reload("early-one", "", 1)
	state.observe_editor(false, true, true, 2, true)
	var begin: Dictionary = state.begin_queued_reload(3)
	var operation_id := str(begin.get("operation_id", ""))
	state.complete_reload(operation_id, 4, "test_complete")
	var status: Dictionary = state.get_status()
	_scenario("first scan queues one reload", [
		queued.get("status") == "queued",
		bool(begin.get("should_execute", false)),
		int(status.get("reload_execution_count", 0)) == 1,
		status.get("state") == ReloadState.STATE_READY,
	])


func _test_early_thirty_two_reloads() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	var operation_ids: Dictionary = {}
	for index in range(32):
		var result: Dictionary = state.request_reload("early-%02d" % index, "", index + 1)
		operation_ids[str(result.get("operation_id", ""))] = true
	state.observe_editor(false, true, true, 40, true)
	var begin: Dictionary = state.begin_queued_reload(41)
	_scenario("first scan coalesces 32 reload requests", [
		operation_ids.size() == 1,
		int(state.get_status().get("operation_count", 0)) == 1,
		int(state.get_status().get("request_count", 0)) == 32,
		int(state.get_operation(str(begin.get("operation_id", ""))).get("execution_count", 0)) == 1,
	])


func _test_duplicate_request_id() -> void:
	var state = _ready_state()
	var first: Dictionary = state.request_reload("same-request", "", 2)
	var duplicate: Dictionary = state.request_reload("same-request", "", 3)
	var begin: Dictionary = state.begin_queued_reload(4)
	state.complete_reload(str(begin.get("operation_id", "")), 5, "test_complete")
	var operation: Dictionary = state.get_operation(str(first.get("operation_id", "")))
	_scenario("same request id is idempotent", [
		first.get("operation_id") == duplicate.get("operation_id"),
		bool(duplicate.get("duplicate_request", false)),
		int(operation.get("execution_count", 0)) == 1,
	])
	_idempotence_check(first.get("operation_id") == duplicate.get("operation_id"))
	_idempotence_check(int(operation.get("execution_count", 0)) == 1)
	var conflict: Dictionary = state.request_reload("same-request", "res://different.gd", 6)
	_idempotence_check(conflict.get("reason_code") == "filesystem_reload_request_id_conflict")


func _test_distinct_request_coalescing() -> void:
	var state = _ready_state()
	var first: Dictionary = state.request_reload("path-a", "res://a.gd", 2)
	var second: Dictionary = state.request_reload("path-b", "res://b.gd", 3)
	var operation: Dictionary = state.get_operation(str(first.get("operation_id", "")))
	_scenario("distinct queued requests coalesce paths", [
		first.get("operation_id") == second.get("operation_id"),
		(operation.get("paths", []) as Array).size() == 2,
		int(state.get_status().get("operation_count", 0)) == 1,
	])


func _test_reload_running_followup() -> void:
	var state = _ready_state()
	var first: Dictionary = state.request_reload("active", "", 2)
	var begin_first: Dictionary = state.begin_queued_reload(3)
	var followup: Dictionary = state.request_reload("followup", "", 4)
	state.complete_reload(str(begin_first.get("operation_id", "")), 5, "test_complete")
	var begin_second: Dictionary = state.begin_queued_reload(6)
	state.complete_reload(str(begin_second.get("operation_id", "")), 7, "test_complete")
	_scenario("reload running admits one followup operation", [
		first.get("operation_id") != followup.get("operation_id"),
		begin_second.get("operation_id") == followup.get("operation_id"),
		int(state.get_status().get("reload_execution_count", 0)) == 2,
		int(state.get_status().get("active_reload_count_max", 0)) == 1,
	])


func _test_initial_scan_failure() -> void:
	var state = _new_state(10, 100, 100)
	state.observe_editor(true, false, true, 0)
	state.request_reload("pending-before-timeout", "", 1)
	state.observe_editor(true, false, true, 11)
	var status: Dictionary = state.get_status()
	_scenario("initial scan timeout fails closed", [
		status.get("state") == ReloadState.STATE_FAILED,
		(status.get("last_error", {}) as Dictionary).get("reason_code") == "initial_scan_timeout",
		int(status.get("active_scan_count", -1)) == 0,
	])


func _test_reload_failure() -> void:
	var state = _ready_state()
	var request: Dictionary = state.request_reload("reload-failure", "", 2)
	state.begin_queued_reload(3)
	state.fail_reload(str(request.get("operation_id", "")), "synthetic_reload_failure", "synthetic", 4)
	var status: Dictionary = state.get_status()
	_scenario("reload failure clears inflight state", [
		status.get("state") == ReloadState.STATE_FAILED,
		int(status.get("active_reload_count", -1)) == 0,
		state.get_operation(str(request.get("operation_id", ""))).get("status") == "failed",
	])


func _test_editor_exit() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	state.observe_editor(false, false, false, 1)
	var status: Dictionary = state.get_status()
	_scenario("editor exit produces typed failure", [
		status.get("state") == ReloadState.STATE_FAILED,
		(status.get("last_error", {}) as Dictionary).get("reason_code") == "editor_process_exited",
	])


func _test_endpoint_stop() -> void:
	var state = _ready_state()
	state.begin_stopping(2)
	var rejected: Dictionary = state.request_reload("during-stop", "", 3)
	_scenario("stopping rejects new reloads", [
		state.get_status().get("state") == ReloadState.STATE_STOPPING,
		rejected.get("reason_code") == "filesystem_reload_stopping",
		int(state.get_status().get("active_reload_count", -1)) == 0,
	])


func _test_reload_timeout() -> void:
	var state = _new_state(100, 10, 100)
	state.observe_editor(false, true, true, 0, true)
	var request: Dictionary = state.request_reload("reload-timeout", "", 1)
	state.begin_queued_reload(2)
	state.observe_editor(true, true, true, 13)
	var status: Dictionary = state.get_status()
	_scenario("reload timeout has no recursive retry", [
		status.get("state") == ReloadState.STATE_FAILED,
		(status.get("last_error", {}) as Dictionary).get("reason_code") == "filesystem_reload_timeout",
		int(state.get_operation(str(request.get("operation_id", ""))).get("execution_count", 0)) == 1,
	])


func _test_status_query_purity() -> void:
	var state = _ready_state()
	state.request_reload("pure-status", "", 2)
	var before := JSON.stringify(state.get_status())
	for _index in range(10):
		state.get_status()
		state.get_operation("filesystem-reload-1")
	var after := JSON.stringify(state.get_status())
	_scenario("operation status queries are pure", [before == after])


func _test_pending_reload_single_trigger() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	state.request_reload("single-trigger", "", 1)
	state.observe_editor(false, true, true, 2, true)
	state.observe_editor(false, true, true, 3, true)
	var begin: Dictionary = state.begin_queued_reload(4)
	state.complete_reload(str(begin.get("operation_id", "")), 5, "test_complete")
	var status: Dictionary = state.get_status()
	_scenario("duplicate completion signal triggers one reload", [
		int(status.get("first_scan_completion_signal_count", 0)) == 1,
		int(status.get("first_scan_reload_trigger_count", 0)) == 1,
		int(status.get("reload_execution_count", 0)) == 1,
	])


func _test_failure_cold_recovery() -> void:
	var state = _new_state(10, 100, 100)
	state.observe_editor(true, false, true, 0)
	state.observe_editor(true, false, true, 11)
	var reset: Dictionary = state.reset_after_failure(12)
	state.observe_editor(false, true, true, 13, true)
	_scenario("failed state requires explicit cold recovery", [
		bool(reset.get("ok", false)),
		state.get_status().get("state") == ReloadState.STATE_READY,
		bool(state.get_status().get("initial_scan_completed", false)),
	])


func _new_state(initial_timeout := 100, reload_timeout := 100, stop_timeout := 100):
	var state = ReloadState.new()
	state.configure_timeouts(initial_timeout, reload_timeout, stop_timeout)
	return state


func _ready_state():
	var state = _new_state()
	state.observe_editor(false, true, true, 0, true)
	return state


func _scenario(name: String, conditions: Array) -> void:
	_scenario_total += 1
	for condition in conditions:
		if not bool(condition):
			_scenario_failures.append(name)
			return
	_scenario_passed += 1


func _idempotence_check(condition: bool) -> void:
	_idempotence_total += 1
	if condition:
		_idempotence_passed += 1


func _finish() -> void:
	print("MCP_RESCAN_STATE_MACHINE_TESTS|passed=%d|total=%d" % [
		_scenario_passed,
		_scenario_total,
	])
	print("MCP_REQUEST_IDEMPOTENCE_TESTS|passed=%d|total=%d" % [
		_idempotence_passed,
		_idempotence_total,
	])
	print("MCP_MAX_TEST_HANDLER_DEPTH|value=1")
	print("MCP_TEST_STACK_OVERFLOW_COUNT|value=0")
	if not _scenario_failures.is_empty() or _idempotence_passed != _idempotence_total:
		for failure in _scenario_failures:
			push_error("Funplay MCP rescan state scenario failed: %s" % failure)
		quit(1)
		return
	quit(0)
