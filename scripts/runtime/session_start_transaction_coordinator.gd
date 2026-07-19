extends Node
class_name SessionStartTransactionCoordinator

signal session_start_finished(receipt: SessionStartReceipt)

@export var draft_service_path: NodePath
@export var plan_builder_path: NodePath
@export var runtime_coordinator_path: NodePath
@export var world_session_state_path: NodePath
@export var game_session_path: NodePath
@export var run_rng_service_path: NodePath
@export var runtime_loop_path: NodePath

var _operation_state := "idle"
var _active_request_id := ""
var _operation_sequence := 0
var _receipts_by_request: Dictionary = {}
var _fingerprints_by_request: Dictionary = {}
var _test_fault_stage := ""


func start_session(request: SessionStartRequest) -> SessionStartReceipt:
	var input_request_id := request.request_id if request != null else ""
	if request == null or not request.is_valid():
		return _finish(_receipt(input_request_id, false, false, "session_start_request_invalid", "request_validation"))
	var request_fingerprint := request.fingerprint().sha256_text()
	if _fingerprints_by_request.has(request.request_id):
		if str(_fingerprints_by_request.get(request.request_id, "")) != request_fingerprint:
			return _finish(_receipt(request.request_id, false, false, "session_start_request_collision", "exact_once"))
		var replay := SessionStartReceipt.from_dictionary(_receipts_by_request.get(request.request_id, {}))
		replay.request_id = request.request_id
		replay.idempotent = true
		return _finish(replay, false)
	if not _active_request_id.is_empty():
		var busy := _receipt(request.request_id, false, false, "session_start_in_progress", "concurrency")
		busy.in_progress = true
		return _finish(busy, false)
	if not _dependencies_ready():
		return _record_terminal(request, request_fingerprint, _receipt(request.request_id, false, false, "session_start_dependencies_unavailable", "dependencies"))
	var draft := _draft_service().draft_snapshot()
	if request.expected_draft_revision != int(draft.get("draft_revision", -1)) or JSON.stringify(request.setup_draft) != JSON.stringify(draft):
		return _record_terminal(request, request_fingerprint, _receipt(request.request_id, false, false, "session_start_draft_revision_stale", "draft_preflight"))
	if request.expected_active_session_revision != _game_session().session_start_revision():
		return _record_terminal(request, request_fingerprint, _receipt(request.request_id, false, false, "active_session_revision_stale", "session_preflight"))
	_active_request_id = request.request_id
	_operation_sequence += 1
	_operation_state = "planning"
	var trace: Array[String] = ["planning"]
	var rng_checkpoint := _run_rng().capture_plan_checkpoint()
	var plan_result := _plan_builder().build_plan(request, rng_checkpoint)
	if not bool(plan_result.get("ok", false)):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(plan_result.get("reason_code", "session_start_plan_failed")), "planning", trace))
	var plan := plan_result.get("plan") as SessionStartPlan
	if plan == null or not plan.is_valid():
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, "session_start_plan_invalid", "planning", trace))
	_operation_state = "preflighting"
	trace.append("preflight:rng")
	var rng_preflight := _run_rng().preflight_plan_commit(plan.rng_checkpoint, plan.rng_terminal_cursor)
	if not bool(rng_preflight.get("accepted", false)):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(rng_preflight.get("reason_code", "session_start_rng_stale")), "rng_preflight", trace, plan.plan_fingerprint))
	trace.append("preflight:world")
	var world_preflight := _world_session().preflight_new_session(plan.to_dictionary())
	if not bool(world_preflight.get("accepted", false)):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(world_preflight.get("reason_code", "session_start_world_preflight_failed")), "world_preflight", trace, plan.plan_fingerprint))
	trace.append("preflight:runtime")
	var runtime_preflight := _runtime_coordinator().preflight_new_session_plan(plan.to_dictionary())
	if not bool(runtime_preflight.get("accepted", false)):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(runtime_preflight.get("reason_code", "session_start_runtime_preflight_failed")), "runtime_preflight", trace, plan.plan_fingerprint))
	trace.append("preflight:session")
	var session_preflight := _game_session().preflight_new_session(plan.session_summary, request.expected_active_session_revision)
	if not bool(session_preflight.get("accepted", false)):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(session_preflight.get("reason_code", "session_start_session_preflight_failed")), "session_preflight", trace, plan.plan_fingerprint))
	if _fault("before_barrier"):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, "session_start_fault_before_barrier", "before_barrier", trace, plan.plan_fingerprint))
	var barrier := _runtime_loop().acquire_session_start_barrier(request.request_id)
	if not bool(barrier.get("acquired", false)):
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(barrier.get("reason_code", "session_start_barrier_busy")), "barrier", trace, plan.plan_fingerprint))
	trace.append("barrier:acquired")
	_operation_state = "checkpointing"
	trace.append("checkpoint:rng")
	var checkpoints := {"rng": rng_checkpoint.duplicate(true)}
	trace.append("checkpoint:world")
	checkpoints["world"] = _world_session().capture_runtime_checkpoint()
	trace.append("checkpoint:runtime")
	var runtime_checkpoint := _runtime_coordinator().capture_new_session_checkpoint()
	if not bool(runtime_checkpoint.get("captured", false)):
		_runtime_loop().release_session_start_barrier(request.request_id)
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, str(runtime_checkpoint.get("reason_code", "session_start_runtime_checkpoint_failed")), "runtime_checkpoint", trace, plan.plan_fingerprint))
	checkpoints["runtime"] = runtime_checkpoint
	trace.append("checkpoint:session")
	checkpoints["session"] = _game_session().capture_new_session_checkpoint()
	if _fault("after_checkpoints"):
		_runtime_loop().release_session_start_barrier(request.request_id)
		return _record_and_release(request, request_fingerprint, _receipt(request.request_id, false, false, "session_start_fault_after_checkpoints", "after_checkpoints", trace, plan.plan_fingerprint))
	_operation_state = "applying"
	trace.append("apply:world")
	var world_apply := _world_session().apply_new_session_plan(plan.to_dictionary())
	var world_fault := _fault("after_world_apply")
	if not bool(world_apply.get("applied", false)) or world_fault:
		var world_reason := "session_start_fault_after_world_apply" if world_fault else str(world_apply.get("reason_code", "session_start_world_apply_failed"))
		return _rollback_failure(request, request_fingerprint, plan, checkpoints, trace, "world_apply", world_reason)
	trace.append("apply:runtime")
	var runtime_apply := _runtime_coordinator().apply_new_session_plan(plan.to_dictionary())
	var runtime_fault := _fault("after_runtime_apply")
	if not bool(runtime_apply.get("applied", false)) or runtime_fault:
		var runtime_reason := "session_start_fault_after_runtime_apply" if runtime_fault else str(runtime_apply.get("reason_code", "session_start_runtime_apply_failed"))
		return _rollback_failure(request, request_fingerprint, plan, checkpoints, trace, "runtime_apply", runtime_reason)
	trace.append("apply:game_session:last")
	var session_apply := _game_session().apply_new_session_plan(plan.session_summary, request.expected_active_session_revision)
	var session_fault := _fault("after_game_session_apply")
	if not bool(session_apply.get("applied", false)) or session_fault:
		var session_reason := "session_start_fault_after_game_session_apply" if session_fault else str(session_apply.get("reason_code", "session_start_game_session_apply_failed"))
		return _rollback_failure(request, request_fingerprint, plan, checkpoints, trace, "game_session_apply", session_reason)
	trace.append("commit:rng")
	var rng_commit := _run_rng().commit_plan_state(plan.rng_checkpoint, plan.rng_terminal_cursor)
	var rng_fault := _fault("after_rng_commit")
	if not bool(rng_commit.get("committed", false)) or rng_fault:
		var rng_reason := "session_start_fault_after_rng_commit" if rng_fault else str(rng_commit.get("reason_code", "session_start_rng_commit_failed"))
		return _rollback_failure(request, request_fingerprint, plan, checkpoints, trace, "rng_commit", rng_reason)
	trace.append("commit:side_effects")
	var side_effect_receipt := _runtime_coordinator().commit_new_session_side_effects(plan.to_dictionary())
	if not bool(side_effect_receipt.get("committed", false)):
		return _rollback_failure(request, request_fingerprint, plan, checkpoints, trace, "commit_side_effects", str(side_effect_receipt.get("reason_code", "session_start_commit_side_effects_failed")))
	_runtime_loop().release_session_start_barrier(request.request_id)
	trace.append("barrier:released")
	_operation_state = "succeeded"
	var success := _receipt(request.request_id, true, true, "session_start_committed", "", trace, plan.plan_fingerprint)
	success.details = {"player_count": plan.player_count, "district_count": plan.districts.size(), "session_revision": _game_session().session_start_revision(), "commit_only": side_effect_receipt.duplicate(true)}
	return _record_and_release(request, request_fingerprint, success)


func set_test_fault_stage(stage: String) -> void:
	_test_fault_stage = stage.strip_edges()


func operation_snapshot() -> Dictionary:
	return {
		"operation_state": _operation_state,
		"active_request_id": _active_request_id,
		"operation_sequence": _operation_sequence,
		"terminal_request_count": _receipts_by_request.size(),
		"owns_gameplay_state": false,
		"owns_rng": false,
		"references_main": false,
	}


func _rollback_failure(request: SessionStartRequest, fingerprint: String, plan: SessionStartPlan, checkpoints: Dictionary, trace: Array[String], stage: String, reason: String) -> SessionStartReceipt:
	_operation_state = "rolling_back"
	trace.append("rollback:session")
	var session_restore := _game_session().rollback_new_session_checkpoint(checkpoints.get("session", {}))
	trace.append("rollback:runtime")
	var runtime_restore := _runtime_coordinator().rollback_new_session_checkpoint(checkpoints.get("runtime", {}))
	trace.append("rollback:world")
	var world_restore := _world_session().restore_runtime_checkpoint(checkpoints.get("world", {}))
	trace.append("rollback:rng")
	var rng_restore := _run_rng().restore_plan_checkpoint(checkpoints.get("rng", {}))
	_runtime_loop().release_session_start_barrier(request.request_id)
	trace.append("barrier:released")
	var rollback_complete := bool(session_restore.get("restored", false)) and bool(runtime_restore.get("restored", false)) and bool(world_restore.get("applied", false)) and bool(rng_restore.get("restored", false))
	_operation_state = "failed"
	var failed := _receipt(request.request_id, false, false, reason, stage, trace, plan.plan_fingerprint)
	failed.rollback_complete = rollback_complete
	failed.details = {"session": session_restore, "runtime": runtime_restore, "world": world_restore, "rng": rng_restore}
	return _record_and_release(request, fingerprint, failed)


func _record_terminal(request: SessionStartRequest, fingerprint: String, receipt: SessionStartReceipt) -> SessionStartReceipt:
	_fingerprints_by_request[request.request_id] = fingerprint
	_receipts_by_request[request.request_id] = receipt.to_dictionary()
	return _finish(receipt)


func _record_and_release(request: SessionStartRequest, fingerprint: String, receipt: SessionStartReceipt) -> SessionStartReceipt:
	_active_request_id = ""
	if _operation_state not in ["succeeded", "failed"]:
		_operation_state = "failed" if not receipt.applied else "succeeded"
	return _record_terminal(request, fingerprint, receipt)


func _finish(receipt: SessionStartReceipt, should_emit := true) -> SessionStartReceipt:
	receipt.operation_sequence = _operation_sequence
	if should_emit:
		session_start_finished.emit(receipt)
	return receipt


func _receipt(request_id: String, accepted: bool, applied: bool, reason: String, stage: String, trace: Array[String] = [], plan_fingerprint := "") -> SessionStartReceipt:
	var receipt := SessionStartReceipt.new()
	receipt.accepted = accepted
	receipt.applied = applied
	receipt.reason_code = reason
	receipt.request_id = request_id
	receipt.plan_fingerprint = plan_fingerprint
	receipt.failing_stage = stage
	receipt.trace = trace.duplicate()
	return receipt


func _dependencies_ready() -> bool:
	return _draft_service() != null and _plan_builder() != null and _runtime_coordinator() != null and _world_session() != null and _game_session() != null and _run_rng() != null and _runtime_loop() != null


func _fault(stage: String) -> bool:
	return not _test_fault_stage.is_empty() and _test_fault_stage == stage


func _draft_service() -> NewGameSetupDraftService:
	return get_node_or_null(draft_service_path) as NewGameSetupDraftService


func _plan_builder() -> SessionStartPlanBuilder:
	return get_node_or_null(plan_builder_path) as SessionStartPlanBuilder


func _runtime_coordinator() -> GameRuntimeCoordinator:
	return get_node_or_null(runtime_coordinator_path) as GameRuntimeCoordinator


func _world_session() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_path) as GameSessionRuntimeController


func _run_rng() -> RunRngService:
	return get_node_or_null(run_rng_service_path) as RunRngService


func _runtime_loop() -> RuntimeLoop:
	return get_node_or_null(runtime_loop_path) as RuntimeLoop
