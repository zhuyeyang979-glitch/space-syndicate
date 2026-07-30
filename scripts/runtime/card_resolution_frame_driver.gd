@tool
extends Node
class_name CardResolutionFrameDriver

const FacilityBinding := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")

var _controller: CardResolutionRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _world_session: WorldSessionState
var _eligibility: CardPlayEligibilityRuntimeService
var _command_pipeline: RuntimeCommandPipeline
var _execution: CardResolutionExecutionRuntimeService
var _configured := false
var _tick_count := 0
var _last_trace: Array[String] = []


func configure(
		controller: CardResolutionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
		world_session: WorldSessionState,
		eligibility: CardPlayEligibilityRuntimeService,
		command_pipeline: RuntimeCommandPipeline,
		execution: CardResolutionExecutionRuntimeService = null
) -> void:
	_controller = controller
	_queue = queue
	_world_session = world_session
	_eligibility = eligibility
	_command_pipeline = command_pipeline
	_execution = execution
	_configured = _controller != null and _queue != null and _world_session != null and _eligibility != null \
		and _command_pipeline != null and _command_pipeline.is_ready()


func advance_world(delta: float) -> Dictionary:
	_last_trace = []
	if not _configured:
		return {"handled": false, "reason": "frame_driver_not_configured", "trace": []}
	var immediate_before := immediate_transition_snapshot()
	_last_trace.append("build_facts")
	var commands := _controller.tick(maxf(0.0, delta), facts_snapshot())
	_last_trace.append("controller_tick")
	_tick_count += 1
	for command_variant in commands:
		if command_variant is Dictionary:
			_last_trace.append("command:%s" % str((command_variant as Dictionary).get("transition", "")))
	var sink_receipt := _command_pipeline.dispatch_card_transition_batch(commands)
	_last_trace.append("command_pipeline_applied" if bool(sink_receipt.get("handled", false)) else "command_pipeline_rejected")
	var result := {
		"handled": bool(sink_receipt.get("handled", false)),
		"reason": str(sink_receipt.get("reason", "")),
		"command_count": commands.size(),
		"sink_receipt": sink_receipt,
		"trace": _last_trace.duplicate(),
	}
	if bool(immediate_before.get("pending", false)):
		result["frame_disposition_id"] = "command_only_facility_resolution"
		result["consumes_command_frame"] = true
		result["facility_resolution_id"] = int(immediate_before.get("resolution_id", -1))
	return result


func immediate_transition_snapshot() -> Dictionary:
	if not _configured or _queue == null:
		return {"pending": false, "reason_code": "frame_driver_not_configured"}
	if _execution != null:
		var execution_pending := _execution.immediate_facility_resolution_snapshot()
		if bool(execution_pending.get("pending", false)):
			return execution_pending.duplicate(true)
		if str(execution_pending.get("reason_code", "")) == "facility_execution_collision":
			return {
				"pending": true,
				"reason_code": "facility_execution_collision",
				"resolution_id": -1,
				"stage_id": "execution_collision",
			}
	var active := _queue.active_entry()
	if not active.is_empty():
		return _immediate_facility_entry(active, "active")
	var current := _queue.current_queue()
	if not current.is_empty() and current[0] is Dictionary:
		return _immediate_facility_entry(current[0] as Dictionary, "queued")
	return {"pending": false, "reason_code": "immediate_facility_queue_shape_unavailable"}


func _immediate_facility_entry(entry: Dictionary, stage_id: String) -> Dictionary:
	var binding: Dictionary = entry.get("v06_facility_action", {}) \
		if entry.get("v06_facility_action", {}) is Dictionary else {}
	if not bool(FacilityBinding.validation_report(binding).get("valid", false)):
		return {"pending": false, "reason_code": "immediate_facility_binding_invalid"}
	var resolution_id := int(entry.get("resolution_id", -1))
	if resolution_id <= 0 or resolution_id != int(binding.get("resolution_id", -2)):
		return {"pending": false, "reason_code": "immediate_facility_resolution_mismatch"}
	return {
		"pending": true,
		"reason_code": "immediate_facility_pending",
		"resolution_id": resolution_id,
		"stage_id": stage_id,
	}


func facts_snapshot() -> Dictionary:
	if _queue == null or _world_session == null:
		return {}
	var active := _queue.active_entry()
	var skill: Dictionary = active.get("skill", {}) if active.get("skill", {}) is Dictionary else {}
	var target_status := _eligibility.target_status({"skill": skill}, {
		"player_count": _world_session.players.size(),
		"monster_count": 0,
	}) if _eligibility != null and not skill.is_empty() else {}
	var active_player_indices: Array = []
	for player_index in range(_world_session.players.size()):
		var player: Dictionary = _world_session.players[player_index] if _world_session.players[player_index] is Dictionary else {}
		if not bool(player.get("eliminated", false)):
			active_player_indices.append(player_index)
	var immediate := immediate_transition_snapshot()
	return {
		"queue_empty": _queue.current_queue().is_empty(),
		"active_present": not active.is_empty(),
		"active_counterable": not bool(target_status.get("is_counter", false))
			and bool(target_status.get("counterable_player_interaction", false))
			and not bool(active.get("countered", false)),
		"active_id": str(active.get("resolution_id", active.get("queued_order", ""))),
		"lock_duration": _controller.lock_seconds if _controller != null else 0.0,
		"public_bid_duration": _controller.public_bid_seconds if _controller != null else 0.0,
		"counter_duration": _controller.counter_seconds if _controller != null else 0.0,
		"active_player_indices": active_player_indices,
		"immediate_facility_pending": bool(immediate.get("pending", false)),
		"immediate_facility_resolution_id": int(immediate.get("resolution_id", -1)),
		"immediate_facility_stage_id": str(immediate.get("stage_id", "")),
	}


func debug_snapshot() -> Dictionary:
	return {
		"driver_authoritative": _configured,
		"tick_count": _tick_count,
		"last_trace": _last_trace.duplicate(),
		"owns_queue": false,
		"owns_timing": false,
		"owns_effects": false,
		"owns_presentation": false,
		"returns_commands_to_main": false,
		"command_pipeline_ready": _command_pipeline != null and _command_pipeline.is_ready(),
	}
