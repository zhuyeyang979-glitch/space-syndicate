@tool
extends Node
class_name CardResolutionFrameDriver

var _controller: CardResolutionRuntimeController
var _queue: CardResolutionQueueRuntimeService
var _world_session: WorldSessionState
var _eligibility: CardPlayEligibilityRuntimeService
var _transition_sink: Node
var _configured := false
var _tick_count := 0
var _last_trace: Array[String] = []


func configure(
		controller: CardResolutionRuntimeController,
	queue: CardResolutionQueueRuntimeService,
	world_session: WorldSessionState,
	eligibility: CardPlayEligibilityRuntimeService,
	transition_sink: Node
) -> void:
	_controller = controller
	_queue = queue
	_world_session = world_session
	_eligibility = eligibility
	_transition_sink = transition_sink
	_configured = _controller != null and _queue != null and _world_session != null and _eligibility != null and _transition_sink != null


func advance_world(delta: float) -> Dictionary:
	_last_trace = []
	if not _configured:
		return {"handled": false, "reason": "frame_driver_not_configured", "trace": []}
	_last_trace.append("build_facts")
	var commands := _controller.tick(maxf(0.0, delta), facts_snapshot())
	_last_trace.append("controller_tick")
	_tick_count += 1
	for command_variant in commands:
		if command_variant is Dictionary:
			_last_trace.append("command:%s" % str((command_variant as Dictionary).get("transition", "")))
	var sink_variant: Variant = _transition_sink.call("apply_transition_batch", commands)
	var sink_receipt: Dictionary = sink_variant if sink_variant is Dictionary else {"handled": false, "reason": "transition_sink_receipt_invalid"}
	_last_trace.append("sink_applied" if bool(sink_receipt.get("handled", false)) else "sink_rejected")
	return {
		"handled": bool(sink_receipt.get("handled", false)),
		"reason": str(sink_receipt.get("reason", "")),
		"command_count": commands.size(),
		"sink_receipt": sink_receipt,
		"trace": _last_trace.duplicate(),
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
		"transition_sink_ready": _transition_sink != null,
	}
