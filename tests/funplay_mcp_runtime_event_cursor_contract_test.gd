extends SceneTree

const RUNTIME_BRIDGE_SCRIPT := preload(
	"res://addons/funplay_mcp/runtime/funplay_mcp_runtime_bridge.gd"
)
const CORE_TOOLS_SCRIPT := preload(
	"res://addons/funplay_mcp/core/funplay_core_tools.gd"
)

var _failure_count: int = 0


func _init() -> void:
	call_deferred("_run_contract")


func _run_contract() -> void:
	_test_empty_and_ready_witness()
	_test_contiguous_cursor()
	_test_overflow_is_fail_closed()
	_test_cursor_validation()
	_test_stream_restart_is_detected()
	_test_legacy_snapshot_is_unproven()
	_test_client_truncation_is_unproven()
	if _failure_count == 0:
		print("FUNPLAY_MCP_RUNTIME_EVENT_CURSOR_CONTRACT|status=PASS|checks=33")
		quit(0)
		return
	print(
		"FUNPLAY_MCP_RUNTIME_EVENT_CURSOR_CONTRACT|status=FAIL|failures=%d" %
		_failure_count
	)
	quit(1)


func _test_empty_and_ready_witness() -> void:
	var bridge = _new_bridge()
	var stream_id := _stream_id(bridge)
	var empty := _snapshot(bridge, stream_id, 0)
	_expect(bool(empty.get("event_sequence_complete", false)), "zero-event cursor is complete")
	_expect(int(empty.get("source_event_count", -1)) == 0, "zero-event source count")
	bridge.call("_add_runtime_event", "ready", "Runtime bridge ready.", {})
	var ready := _snapshot(bridge, stream_id, 0)
	_expect(bool(ready.get("success", false)), "ready cursor succeeds")
	_expect(int(ready.get("event_sequence_first", -1)) == 1, "ready sequence starts at one")
	_expect(str((ready.get("events", []) as Array)[0].get("stream_id", "")) == stream_id, "ready carries stream id")
	_expect(str((ready.get("events", []) as Array)[0].get("kind", "")) == "ready", "ready witness is retained")
	bridge.free()


func _test_contiguous_cursor() -> void:
	var bridge = _new_bridge()
	var stream_id := _stream_id(bridge)
	for index in range(5):
		bridge.call("_add_runtime_event", "fixture", "event-%d" % index, {"index": index})
	var first := _snapshot(bridge, stream_id, 0)
	_expect(bool(first.get("event_sequence_complete", false)), "initial cursor is contiguous")
	var next := _snapshot(bridge, stream_id, 3)
	_expect(bool(next.get("success", false)), "incremental cursor succeeds")
	_expect(int(next.get("source_event_count", -1)) == 2, "incremental cursor returns only new events")
	_expect(int(next.get("event_sequence_first", -1)) == 4, "incremental cursor starts after cursor")
	_expect(int(next.get("event_sequence_last", -1)) == 5, "incremental cursor ends at newest event")
	_expect(int(next.get("event_sequence_gap_count", -1)) == 0, "incremental cursor has no gap")
	bridge.free()


func _test_overflow_is_fail_closed() -> void:
	var bridge = _new_bridge()
	var stream_id := _stream_id(bridge)
	for index in range(101):
		bridge.call("_add_runtime_event", "fixture", "event-%d" % index, {})
	var overflow := _snapshot(bridge, stream_id, 0)
	_expect(not bool(overflow.get("success", true)), "overflow cursor fails closed")
	_expect(str(overflow.get("error_code", "")) == "RUNTIME_EVENT_EVENTS_DROPPED", "overflow error code")
	_expect(int(overflow.get("event_sequence_gap_count", -1)) == 1, "overflow reports one dropped sequence")
	_expect(bool(overflow.get("event_window_saturated", false)), "overflow reports saturated ring")
	_expect(bool(overflow.get("event_window_overflowed", false)), "overflow reports eviction")
	_expect(int(overflow.get("buffered_event_count", -1)) == 100, "overflow retains only ring capacity")
	var recovered := _snapshot(bridge, stream_id, 1)
	_expect(bool(recovered.get("success", false)), "cursor at oldest retained boundary succeeds")
	_expect(int(recovered.get("event_sequence_first", -1)) == 2, "retained boundary starts at sequence two")
	bridge.free()


func _test_cursor_validation() -> void:
	var bridge = _new_bridge()
	var stream_id := _stream_id(bridge)
	bridge.call("_add_runtime_event", "fixture", "event", {})
	var missing_stream := bridge.call("_runtime_event_snapshot", {"since_sequence": 0}) as Dictionary
	_expect(str(missing_stream.get("error_code", "")) == "RUNTIME_EVENT_STREAM_ID_REQUIRED", "cursor requires stream id")
	var negative := bridge.call("_runtime_event_snapshot", {"stream_id": stream_id, "since_sequence": -1}) as Dictionary
	_expect(str(negative.get("error_code", "")) == "RUNTIME_EVENT_CURSOR_INVALID", "negative cursor rejected")
	var ahead := bridge.call("_runtime_event_snapshot", {"stream_id": stream_id, "since_sequence": 2}) as Dictionary
	_expect(str(ahead.get("error_code", "")) == "RUNTIME_EVENT_CURSOR_AHEAD", "future cursor rejected")
	bridge.free()


func _test_stream_restart_is_detected() -> void:
	var first_bridge = _new_bridge()
	var second_bridge = _new_bridge()
	var first_stream := _stream_id(first_bridge)
	var second_stream := _stream_id(second_bridge)
	_expect(first_stream != second_stream, "new bridge receives a new stream id")
	var changed := first_bridge.call(
		"_runtime_event_snapshot",
		{"stream_id": second_stream, "since_sequence": 0}
	) as Dictionary
	_expect(str(changed.get("error_code", "")) == "RUNTIME_EVENT_STREAM_CHANGED", "stale stream rejected")
	first_bridge.free()
	second_bridge.free()


func _test_legacy_snapshot_is_unproven() -> void:
	var bridge = _new_bridge()
	bridge.call("_add_runtime_event", "fixture", "event", {})
	var snapshot := bridge.call("_runtime_event_snapshot", {}) as Dictionary
	_expect(str(snapshot.get("event_sequence_mode", "")) == "snapshot_only", "legacy mode is explicit")
	_expect(not bool(snapshot.get("event_sequence_complete", true)), "legacy snapshot is not complete evidence")
	_expect(str(snapshot.get("continuity_status", "")) == "SNAPSHOT_ONLY", "legacy continuity status")
	bridge.free()


func _test_client_truncation_is_unproven() -> void:
	var core_tools = CORE_TOOLS_SCRIPT.new(null, null)
	var prepared := core_tools.call(
		"_prepare_runtime_event_window",
		{
			"events": [
				{"event_sequence": 1},
				{"event_sequence": 2},
				{"event_sequence": 3},
			],
			"event_sequence_complete": true,
		},
		2
	) as Dictionary
	_expect(int(prepared.get("source_event_count", -1)) == 3, "client window retains source count")
	_expect(int(prepared.get("returned_event_count", -1)) == 2, "client window reports returned count")
	_expect(bool(prepared.get("client_truncated", false)), "client window reports truncation")
	_expect(not bool(prepared.get("event_evidence_complete", true)), "client truncation is unproven")


func _new_bridge():
	var bridge = RUNTIME_BRIDGE_SCRIPT.new()
	bridge.call("_ensure_event_stream_id")
	return bridge


func _stream_id(bridge) -> String:
	var cursor := bridge.call("_runtime_event_cursor_snapshot") as Dictionary
	return str(cursor.get("stream_id", ""))


func _snapshot(bridge, stream_id: String, since_sequence: int) -> Dictionary:
	return bridge.call(
		"_runtime_event_snapshot",
		{"stream_id": stream_id, "since_sequence": since_sequence}
	) as Dictionary


func _expect(condition: bool, label: String) -> void:
	if condition:
		return
	_failure_count += 1
	push_error("FUNPLAY_MCP_RUNTIME_EVENT_CURSOR_CONTRACT|failure=%s" % label)
