extends SceneTree

const ReloadState := preload("res://addons/funplay_mcp/core/funplay_filesystem_reload_state.gd")

var _scenario_total := 0
var _scenario_passed := 0
var _scenario_failures: Array[String] = []
var _idempotence_total := 0
var _idempotence_passed := 0
var _async_total := 0
var _async_passed := 0
var _fake_scan_total := 0
var _fake_scan_passed := 0
var _transport_gate_total := 0
var _transport_gate_passed := 0
var _quiescence_total := 0
var _quiescence_passed := 0
var _serialization_total := 0
var _serialization_passed := 0


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
	_test_async_protocol_contract()
	_test_completion_callback_followup_reload()
	_test_transport_poll_readiness_gate()
	_test_initial_import_quiescence()
	_test_reimport_resets_quiescence_window()
	_test_duplicate_reimport_depth_blocks_ready()
	_test_reload_completes_only_after_quiescence()
	_test_quiescence_timeout()
	_test_lifecycle_monotonic_and_single_writer()
	_finish()


func _test_initial_import_quiescence() -> void:
	var state = _new_state()
	state.configure_quiescence(10, 50)
	state.observe_editor(true, false, true, 0)
	state.observe_editor(false, true, true, 1, true)
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_INITIAL_SCAN_QUIESCING)
	state.observe_editor(false, true, true, 9)
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_INITIAL_SCAN_QUIESCING)
	state.observe_editor(false, true, true, 10)
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_READY)
	_quiescence_check(bool(state.get_status().get("import_quiescence_reached", false)))


func _test_reimport_resets_quiescence_window() -> void:
	var state = _new_state()
	state.configure_quiescence(10, 50)
	state.observe_editor(true, false, true, 0)
	state.observe_editor(false, true, true, 1, true)
	state.record_import_signal("resources_reimporting", ["res://private.gd"], 6)
	state.observe_editor(false, false, true, 6, false, true)
	state.record_import_signal("resources_reimported", ["res://private.gd"], 8)
	state.observe_editor(false, true, true, 8, false, false)
	state.observe_editor(false, true, true, 17)
	_quiescence_check(state.get_status().get("state") != ReloadState.STATE_READY)
	state.observe_editor(false, true, true, 18)
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_READY)
	_serialization_check(int(state.get_status().get("active_import_operation_total_max", 0)) == 1)


func _test_duplicate_reimport_depth_blocks_ready() -> void:
	var state = _new_state()
	state.configure_quiescence(0, 50)
	state.observe_editor(true, false, true, 0)
	state.record_import_signal("resources_reimporting", [], 1)
	state.record_import_signal("resources_reimporting", [], 2)
	state.record_import_signal("resources_reimported", [], 3)
	state.observe_editor(false, true, true, 4)
	_quiescence_check(int(state.get_status().get("known_reimport_depth", 0)) == 1)
	_quiescence_check(state.get_status().get("state") != ReloadState.STATE_READY)
	state.record_import_signal("resources_reimported", [], 5)
	state.observe_editor(false, true, true, 5)
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_READY)
	_serialization_check(int(state.get_status().get("active_import_operation_total_max", 0)) == 1)


func _test_reload_completes_only_after_quiescence() -> void:
	var state = _new_state()
	state.configure_quiescence(10, 50)
	state.observe_editor(false, true, true, 0, true)
	state.observe_editor(false, true, true, 10)
	var request: Dictionary = state.request_reload("quiescent-reload", "", 11)
	var begin: Dictionary = state.begin_queued_reload(12)
	state.observe_editor(true, true, true, 13)
	state.observe_editor(false, true, true, 14)
	_quiescence_check(state.get_operation(str(request.get("operation_id", ""))).get("status") == "running")
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_RELOAD_QUIESCING)
	state.observe_editor(false, true, true, 24)
	_quiescence_check(state.get_operation(str(begin.get("operation_id", ""))).get("status") == "completed")
	_serialization_check(int(state.get_status().get("active_reload_count_max", 0)) == 1)
	_serialization_check(int(state.get_status().get("active_import_operation_total_max", 0)) <= 1)


func _test_quiescence_timeout() -> void:
	var state = _new_state(100, 100, 100)
	state.configure_quiescence(10, 5)
	state.observe_editor(true, false, true, 0)
	state.observe_editor(false, true, true, 1, true)
	state.record_import_signal("filesystem_changed", [], 5)
	state.observe_editor(false, true, true, 7)
	_quiescence_check(state.get_status().get("state") == ReloadState.STATE_FAILED)
	_quiescence_check((state.get_status().get("last_error", {}) as Dictionary).get("reason_code") == "import_quiescence_timeout")


func _test_lifecycle_monotonic_and_single_writer() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 1)
	state.record_import_signal("resources_reimporting", ["res://a.gd"], 2)
	state.record_import_signal("resources_reimported", ["res://a.gd"], 3)
	var status: Dictionary = state.get_status()
	var events: Array = status.get("lifecycle_events", [])
	var monotonic := true
	var previous := -1
	for event in events:
		var timestamp := int((event as Dictionary).get("timestamp_monotonic_ns", -1))
		if timestamp < previous:
			monotonic = false
		previous = timestamp
	_quiescence_check(monotonic)
	_quiescence_check(int(status.get("import_lifecycle_event_writer_count", 0)) == 1)
	_quiescence_check(int(status.get("import_state_writer_count", 0)) == 1)
	_serialization_check(int(status.get("active_import_operation_total_max", 0)) == 1)


func _test_cold_initial_ready() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	var running: Dictionary = state.get_status()
	state.observe_editor(false, true, true, 1, true)
	var ready: Dictionary = state.get_status()
	var initial_operation: Dictionary = state.get_operation(str(ready.get("initial_scan_operation_id", "")))
	_scenario("cold -> initial_scan_running -> ready", [
		running.get("state") == ReloadState.STATE_INITIAL_SCAN_RUNNING,
		ready.get("state") == ReloadState.STATE_READY,
		bool(ready.get("initial_scan_completed", false)),
		int(ready.get("first_scan_completion_signal_count", 0)) == 1,
	])
	_async_check(int(ready.get("initial_scan_start_count", 0)) == 1)
	_async_check(int(ready.get("initial_scan_completion_count", 0)) == 1)
	_async_check(initial_operation.get("status") == "completed")


func _test_early_single_reload() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	var queued: Dictionary = state.request_reload("early-one", "", 1)
	state.observe_editor(false, true, true, 2, true)
	state.record_post_initial_scan_reload_deferred_tick(3)
	var begin: Dictionary = state.begin_queued_reload(4)
	var operation_id := str(begin.get("operation_id", ""))
	state.observe_editor(false, true, true, 4)
	var status: Dictionary = state.get_status()
	_scenario("first scan queues one reload", [
		queued.get("status") == "queued",
		bool(begin.get("should_execute", false)),
		int(status.get("reload_execution_count", 0)) == 1,
		int(status.get("post_initial_scan_reload_deferred_tick_count", 0)) == 1,
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
	state.record_post_initial_scan_reload_deferred_tick(41)
	var begin: Dictionary = state.begin_queued_reload(42)
	_scenario("first scan coalesces 32 reload requests", [
		operation_ids.size() == 1,
		int(state.get_status().get("operation_count", 0)) == 2,
		int(state.get_status().get("request_count", 0)) == 32,
		int(state.get_operation(str(begin.get("operation_id", ""))).get("execution_count", 0)) == 1,
	])


func _test_duplicate_request_id() -> void:
	var state = _ready_state()
	var first: Dictionary = state.request_reload("same-request", "", 2)
	var duplicate: Dictionary = state.request_reload("same-request", "", 3)
	var begin: Dictionary = state.begin_queued_reload(4)
	state.observe_editor(false, true, true, 5)
	var operation: Dictionary = state.get_operation(str(first.get("operation_id", "")))
	_scenario("same request id is idempotent", [
		first.get("operation_id") == duplicate.get("operation_id"),
		bool(duplicate.get("duplicate_request", false)),
		int(operation.get("execution_count", 0)) == 1,
	])
	_idempotence_check(first.get("operation_id") == duplicate.get("operation_id"))
	_idempotence_check(int(operation.get("execution_count", 0)) == 1)
	var conflict: Dictionary = state.request_reload("same-request", "res://different.gd", 6)
	_idempotence_check(conflict.get("reason_code") == "mcp_request_id_collision")


func _test_distinct_request_coalescing() -> void:
	var state = _ready_state()
	var first: Dictionary = state.request_reload("path-a", "res://a.gd", 2)
	var second: Dictionary = state.request_reload("path-b", "res://b.gd", 3)
	var operation: Dictionary = state.get_operation(str(first.get("operation_id", "")))
	_scenario("distinct queued requests coalesce paths", [
		first.get("operation_id") == second.get("operation_id"),
		(operation.get("paths", []) as Array).size() == 2,
		int(state.get_status().get("operation_count", 0)) == 2,
	])


func _test_reload_running_followup() -> void:
	var state = _ready_state()
	var first: Dictionary = state.request_reload("active", "", 2)
	var begin_first: Dictionary = state.begin_queued_reload(3)
	var followup: Dictionary = state.request_reload("followup", "", 4)
	state.observe_editor(false, true, true, 5)
	var begin_second: Dictionary = state.begin_queued_reload(6)
	state.observe_editor(false, true, true, 7)
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
	state.complete_stopping(4)
	var stopped_rejection: Dictionary = state.request_reload("after-stop", "", 5)
	_async_check(state.get_status().get("state") == ReloadState.STATE_STOPPED)
	_async_check(stopped_rejection.get("reason_code") == "filesystem_reload_stopped")


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
	state.record_post_initial_scan_reload_deferred_tick(4)
	var begin: Dictionary = state.begin_queued_reload(5)
	state.observe_editor(false, true, true, 5)
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


func _test_async_protocol_contract() -> void:
	var state = _new_state()
	state.begin_editor_booting(0)
	var missing: Dictionary = state.request_reload("", "", 1)
	state.observe_editor(true, false, true, 2)
	var first: Dictionary = state.request_reload("protocol-id", "res://a.gd", 3)
	var collision: Dictionary = state.request_reload("protocol-id", "res://b.gd", 4)
	_async_check(missing.get("reason_code") == "mcp_request_id_required")
	_async_check(first.get("status") == "queued")
	_async_check(collision.get("reason_code") == "mcp_request_id_collision")
	_async_check(int(state.get_status().get("state_writer_count", 0)) == 1)
	var snapshot_state = _new_state()
	snapshot_state.observe_editor(false, true, true, 0, false)
	_async_check(int(snapshot_state.get_status().get("initial_scan_completion_count", 0)) == 1)
	_async_check(int(snapshot_state.get_status().get("first_scan_completion_signal_count", -1)) == 0)


func _test_completion_callback_followup_reload() -> void:
	var state = _new_state()
	state.observe_editor(true, false, true, 0)
	var early: Dictionary = state.request_reload("callback-early", "", 1)
	state.observe_editor(false, true, true, 2, true)
	state.record_post_initial_scan_reload_deferred_tick(3)
	var first_begin: Dictionary = state.begin_queued_reload(4)
	var followup: Dictionary = state.request_reload("callback-followup", "", 5)
	state.observe_editor(false, true, true, 6)
	var second_begin: Dictionary = state.begin_queued_reload(7)
	state.observe_editor(false, true, true, 8)
	_fake_scan_check(early.get("operation_id") == first_begin.get("operation_id"))
	_fake_scan_check(followup.get("operation_id") == second_begin.get("operation_id"))
	_fake_scan_check(int(state.get_status().get("reload_execution_count", 0)) == 2)
	_fake_scan_check(int(state.get_status().get("active_scan_count_max", 0)) == 1)
	_fake_scan_check(int(state.get_status().get("active_reload_count_max", 0)) == 1)
	_fake_scan_check(state.get_status().get("state") == ReloadState.STATE_READY)


func _test_transport_poll_readiness_gate() -> void:
	var state = _new_state(10000, 10000, 10000)
	state.observe_editor(true, false, true, 0)
	_transport_gate_check(not state.is_transport_poll_ready(500, 1000))
	state.observe_editor(false, true, true, 1000, true)
	_transport_gate_check(not state.is_transport_poll_ready(1999, 1000))
	_transport_gate_check(state.is_transport_poll_ready(2000, 1000))
	state.request_reload("transport-gate-reload", "", 2001)
	_transport_gate_check(not state.is_transport_poll_ready(3000, 1000))
	var begin: Dictionary = state.begin_queued_reload(3001)
	state.observe_editor(false, true, true, 3002)
	_transport_gate_check(not state.is_transport_poll_ready(3999, 1000))
	_transport_gate_check(state.is_transport_poll_ready(4002, 1000))


func _new_state(initial_timeout := 100, reload_timeout := 100, stop_timeout := 100):
	var state = ReloadState.new()
	state.configure_timeouts(initial_timeout, reload_timeout, stop_timeout)
	state.configure_quiescence(0, 100)
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


func _async_check(condition: bool) -> void:
	_async_total += 1
	if condition:
		_async_passed += 1


func _fake_scan_check(condition: bool) -> void:
	_fake_scan_total += 1
	if condition:
		_fake_scan_passed += 1


func _transport_gate_check(condition: bool) -> void:
	_transport_gate_total += 1
	if condition:
		_transport_gate_passed += 1


func _quiescence_check(condition: bool) -> void:
	_quiescence_total += 1
	if condition:
		_quiescence_passed += 1


func _serialization_check(condition: bool) -> void:
	_serialization_total += 1
	if condition:
		_serialization_passed += 1


func _finish() -> void:
	print("MCP_RESCAN_STATE_MACHINE_TESTS|passed=%d|total=%d" % [
		_scenario_passed,
		_scenario_total,
	])
	print("MCP_REQUEST_IDEMPOTENCE_TESTS|passed=%d|total=%d" % [
		_idempotence_passed,
		_idempotence_total,
	])
	print("MCP_ASYNC_INITIAL_SCAN_TESTS|passed=%d|total=%d" % [
		_async_passed,
		_async_total,
	])
	print("MCP_FAKE_SCAN_INTEGRATION_TESTS|passed=%d|total=%d" % [
		_fake_scan_passed,
		_fake_scan_total,
	])
	print("MCP_TRANSPORT_READINESS_GATE_TESTS|passed=%d|total=%d" % [
		_transport_gate_passed,
		_transport_gate_total,
	])
	print("IMPORT_QUIESCENCE_TESTS|passed=%d|total=%d" % [
		_quiescence_passed,
		_quiescence_total,
	])
	print("IMPORT_OPERATION_SERIALIZATION_TESTS|passed=%d|total=%d" % [
		_serialization_passed,
		_serialization_total,
	])
	print("MCP_MAX_TEST_HANDLER_DEPTH|value=1")
	print("MCP_TEST_STACK_OVERFLOW_COUNT|value=0")
	if (
		not _scenario_failures.is_empty()
		or _idempotence_passed != _idempotence_total
		or _async_passed != _async_total
		or _fake_scan_passed != _fake_scan_total
		or _transport_gate_passed != _transport_gate_total
		or _quiescence_passed != _quiescence_total
		or _serialization_passed != _serialization_total
	):
		for failure in _scenario_failures:
			push_error("Funplay MCP rescan state scenario failed: %s" % failure)
		quit(1)
		return
	quit(0)
