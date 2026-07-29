@tool
extends Node
class_name SaveRestoreRuntimeBarrier

const CHECKPOINT_SCHEMA_VERSION := 1
const QUIET_COUNTER_FIELDS := [
	"rng_draw_invocation_count",
	"public_log_entry_count",
	"public_log_revision",
	"private_feedback_revision",
	"notification_count",
	"human_action_submission_count",
	"ai_action_submission_count",
	"economic_reward_count",
	"presentation_revision",
]

@export var game_session_path: NodePath
@export var runtime_loop_path: NodePath
@export var world_clock_path: NodePath
@export var presentation_query_ports_path: NodePath
@export var presentation_scheduler_path: NodePath
@export var presentation_refresh_port_path: NodePath
@export var coordinator_path: NodePath

var _active_operation_id := ""
var _active_checkpoint: Dictionary = {}
var _barrier_enter_count := 0
var _barrier_commit_count := 0
var _barrier_rollback_count := 0
var _quiet_rejection_count := 0
var _last_quiet_deltas: Dictionary = {}


func capture_global_checkpoint(operation_id: String) -> Dictionary:
	var normalized := operation_id.strip_edges()
	if normalized.is_empty() or not _active_operation_id.is_empty():
		return {"accepted": false, "reason_code": "restore_global_checkpoint_busy"}
	var loop := _runtime_loop()
	var clock := _world_clock()
	var queries := _presentation_queries()
	var scheduler := _presentation_scheduler()
	var refresh_port := _presentation_refresh_port()
	var coordinator := _coordinator()
	var session := _game_session()
	if loop == null or clock == null or queries == null or scheduler == null \
			or refresh_port == null or coordinator == null or session == null:
		return {"accepted": false, "reason_code": "restore_global_checkpoint_dependency_missing"}
	var checkpoint := {
		"schema_version": CHECKPOINT_SCHEMA_VERSION,
		"operation_id": normalized,
		"runtime_loop": _call_dictionary(loop, "capture_runtime_checkpoint"),
		"world_clock": _call_dictionary(clock, "capture_runtime_checkpoint"),
		"presentation_queries": _call_dictionary(queries, "capture_runtime_checkpoint"),
		"presentation_scheduler": _call_dictionary(scheduler, "capture_runtime_checkpoint"),
		"presentation_refresh_port": _call_dictionary(refresh_port, "capture_runtime_checkpoint"),
		"coordinator": _call_dictionary(coordinator, "capture_save_restore_runtime_checkpoint"),
		"session_barrier": _call_dictionary(session, "restore_barrier_snapshot"),
		"safety_observation": _call_dictionary(coordinator, "save_restore_safety_observation"),
	}
	for key in ["runtime_loop", "world_clock", "presentation_queries", "presentation_scheduler", "presentation_refresh_port", "coordinator", "session_barrier", "safety_observation"]:
		if (checkpoint.get(key, {}) as Dictionary).is_empty():
			return {"accepted": false, "reason_code": "restore_global_checkpoint_capture_failed", "failing_checkpoint": key}
	return {
		"accepted": true,
		"reason_code": "restore_global_checkpoint_captured",
		"checkpoint": checkpoint,
	}


func enter_restore_barrier(operation_id: String, checkpoint: Dictionary) -> Dictionary:
	var normalized := operation_id.strip_edges()
	if normalized.is_empty() or not _active_operation_id.is_empty():
		return {"acquired": false, "reason_code": "restore_barrier_busy"}
	if int(checkpoint.get("schema_version", 0)) != CHECKPOINT_SCHEMA_VERSION \
			or str(checkpoint.get("operation_id", "")) != normalized:
		return {"acquired": false, "reason_code": "restore_global_checkpoint_invalid"}
	var loop_receipt := _call_dictionary(_runtime_loop(), "acquire_restore_barrier", [normalized])
	if not bool(loop_receipt.get("acquired", false)):
		return {"acquired": false, "reason_code": str(loop_receipt.get("reason_code", "runtime_loop_barrier_failed"))}
	var session_receipt := _call_dictionary(_game_session(), "enter_restore_barrier", [normalized])
	if not bool(session_receipt.get("acquired", false)):
		_call_dictionary(_runtime_loop(), "release_restore_barrier", [normalized])
		return {"acquired": false, "reason_code": str(session_receipt.get("reason_code", "session_restore_barrier_failed"))}
	_active_operation_id = normalized
	_active_checkpoint = checkpoint.duplicate(true)
	_barrier_enter_count += 1
	return {
		"acquired": true,
		"reason_code": "restore_barrier_acquired",
		"runtime_loop_advance": false,
		"ai_tick_enabled": false,
		"player_gameplay_input_enabled": false,
		"card_resolution_advance": false,
		"world_effective_time_advance": false,
		"presentation_mutation_suppressed": true,
	}


func verify_restore_quiet(operation_id: String) -> Dictionary:
	if _active_operation_id != operation_id.strip_edges():
		return {"accepted": false, "reason_code": "restore_barrier_not_owned", "deltas": {}}
	var before: Dictionary = _active_checkpoint.get("safety_observation", {}) \
		if _active_checkpoint.get("safety_observation", {}) is Dictionary else {}
	var after := _call_dictionary(_coordinator(), "save_restore_safety_observation")
	var deltas: Dictionary = {}
	var quiet := true
	for field in QUIET_COUNTER_FIELDS:
		var delta := int(after.get(field, 0)) - int(before.get(field, 0))
		deltas[field] = delta
		quiet = quiet and delta == 0
	_last_quiet_deltas = deltas.duplicate(true)
	if not quiet:
		_quiet_rejection_count += 1
	return {
		"accepted": quiet,
		"reason_code": "restore_quiet_window_valid" if quiet else "restore_quiet_window_violated",
		"deltas": deltas,
	}


func post_restore_rebind(operation_id: String) -> Dictionary:
	if _active_operation_id != operation_id.strip_edges():
		return {"applied": false, "reason_code": "restore_barrier_not_owned"}
	var quiet := verify_restore_quiet(operation_id)
	if not bool(quiet.get("accepted", false)):
		return {"applied": false, "reason_code": str(quiet.get("reason_code", "restore_quiet_window_violated")), "quiet_deltas": quiet.get("deltas", {})}
	return _call_dictionary(_coordinator(), "post_restore_rebind_after_save")


func commit_restore_barrier(operation_id: String) -> Dictionary:
	var normalized := operation_id.strip_edges()
	if _active_operation_id != normalized:
		return {"committed": false, "reason_code": "restore_barrier_not_owned"}
	var session_receipt := _call_dictionary(_game_session(), "commit_restore_barrier", [normalized])
	if not bool(session_receipt.get("committed", false)):
		return {"committed": false, "reason_code": str(session_receipt.get("reason_code", "session_restore_barrier_commit_failed"))}
	var loop_receipt := _call_dictionary(_runtime_loop(), "release_restore_barrier", [normalized])
	if not bool(loop_receipt.get("released", false)):
		return {"committed": false, "reason_code": str(loop_receipt.get("reason_code", "runtime_loop_restore_barrier_release_failed"))}
	_active_operation_id = ""
	_active_checkpoint.clear()
	_barrier_commit_count += 1
	return {"committed": true, "reason_code": "restore_barrier_committed"}


func rollback_restore_barrier(operation_id: String) -> Dictionary:
	var normalized := operation_id.strip_edges()
	if _active_operation_id != normalized:
		return {"applied": false, "reason_code": "restore_barrier_not_owned", "failures": []}
	var failures: Array[String] = []
	var session_receipt := _call_dictionary(_game_session(), "abort_restore_barrier", [normalized])
	if not bool(session_receipt.get("aborted", false)):
		failures.append("game_session_barrier")
	var loop_release := _call_dictionary(_runtime_loop(), "release_restore_barrier", [normalized])
	if not bool(loop_release.get("released", false)):
		failures.append("runtime_loop_barrier")
	var restores := [
		["presentation_queries", _presentation_queries(), "restore_runtime_checkpoint"],
		["presentation_scheduler", _presentation_scheduler(), "restore_runtime_checkpoint"],
		["presentation_refresh_port", _presentation_refresh_port(), "restore_runtime_checkpoint"],
		["world_clock", _world_clock(), "restore_runtime_checkpoint"],
		["coordinator", _coordinator(), "restore_save_restore_runtime_checkpoint"],
		["runtime_loop", _runtime_loop(), "restore_runtime_checkpoint"],
	]
	for row in restores:
		var key := str(row[0])
		var receipt := _call_dictionary(row[1] as Node, str(row[2]), [(_active_checkpoint.get(key, {}) as Dictionary).duplicate(true)])
		if not bool(receipt.get("applied", false)):
			failures.append(key)
	_active_operation_id = ""
	_active_checkpoint.clear()
	_barrier_rollback_count += 1
	return {
		"applied": failures.is_empty(),
		"reason_code": "restore_barrier_rolled_back" if failures.is_empty() else "restore_barrier_rollback_incomplete",
		"failures": failures,
	}


func debug_snapshot() -> Dictionary:
	return {
		"barrier_ready": _game_session() != null and _runtime_loop() != null and _coordinator() != null,
		"active": not _active_operation_id.is_empty(),
		"enter_count": _barrier_enter_count,
		"commit_count": _barrier_commit_count,
		"rollback_count": _barrier_rollback_count,
		"quiet_rejection_count": _quiet_rejection_count,
		"last_quiet_deltas": _last_quiet_deltas.duplicate(true),
		"runtime_loop_advance_while_active": false,
		"ai_tick_enabled_while_active": false,
		"player_gameplay_input_enabled_while_active": false,
		"card_resolution_advance_while_active": false,
		"world_effective_time_advance_while_active": false,
		"presentation_mutation_suppressed_while_active": true,
	}


func _call_dictionary(target: Node, method: String, args: Array = []) -> Dictionary:
	if target == null or not target.has_method(method):
		return {}
	var value: Variant = target.callv(method, args)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _game_session() -> Node:
	return get_node_or_null(game_session_path)


func _runtime_loop() -> Node:
	return get_node_or_null(runtime_loop_path)


func _world_clock() -> Node:
	return get_node_or_null(world_clock_path)


func _presentation_queries() -> Node:
	return get_node_or_null(presentation_query_ports_path)


func _presentation_scheduler() -> Node:
	return get_node_or_null(presentation_scheduler_path)


func _presentation_refresh_port() -> Node:
	return get_node_or_null(presentation_refresh_port_path)


func _coordinator() -> Node:
	return get_node_or_null(coordinator_path)
