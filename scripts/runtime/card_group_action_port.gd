@tool
extends Node
class_name CardGroupActionPort

@export var world_session_state_path: NodePath
@export var queue_service_path: NodePath
@export var resolution_controller_path: NodePath

var _submission_count := 0
var _accepted_count := 0
var _rejected_count := 0
var _ready_apply_count := 0
var _reorder_apply_count := 0


func submit_ready(actor_index: int, resolution_id: int) -> Dictionary:
	_submission_count += 1
	var validation := _validate_actor_entry(actor_index, resolution_id)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_id", "card_group_target_invalid")))
	var controller := _controller()
	if controller == null:
		return _rejected("card_group_controller_missing")
	var facts := _card_group_facts()
	var phase := controller.current_phase(facts)
	if phase not in ["planning", "public_bid", "lock"]:
		return _rejected("card_group_window_closed")
	var ready_players := controller.ready_players
	if bool(ready_players.get(str(actor_index), false)):
		return _rejected("card_group_already_ready")
	var result := controller.set_player_ready(actor_index, true, _active_player_indices())
	if not bool(result.get("changed", false)):
		return _rejected(str(result.get("reason", "card_group_ready_rejected")))
	_accepted_count += 1
	_ready_apply_count += 1
	return {
		"accepted": true,
		"reason_id": "card_group_ready_committed",
		"effect_ref": "card.group.ready.%s" % GameActionCardBindingV1.resolution_ref(resolution_id),
		"authoritative_revision": _queue_revision(),
	}


func submit_reorder(actor_index: int, resolution_id: int, direction: int) -> Dictionary:
	_submission_count += 1
	if direction not in [-1, 1]:
		return _rejected("card_group_reorder_direction_invalid")
	var validation := _validate_actor_entry(actor_index, resolution_id)
	if not bool(validation.get("valid", false)):
		return _rejected(str(validation.get("reason_id", "card_group_target_invalid")))
	var controller := _controller()
	var queue := _queue()
	if controller == null or queue == null:
		return _rejected("card_group_dependency_missing")
	if not controller.submissions_open(_card_group_facts()):
		return _rejected("card_group_window_closed")
	var result := queue.move_within_group(
		resolution_id,
		direction,
		actor_index,
		controller.batch_reference_player,
		_world().players.size()
	)
	if not bool(result.get("moved", false)):
		return _rejected(str(result.get("reason", "card_group_reorder_rejected")))
	_accepted_count += 1
	_reorder_apply_count += 1
	return {
		"accepted": true,
		"reason_id": "card_group_reorder_committed",
		"effect_ref": "card.group.reorder.%s" % GameActionCardBindingV1.resolution_ref(resolution_id),
		"authoritative_revision": maxi(0, int(result.get("revision", _queue_revision()))),
	}


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "card_group_action_port_v1",
		"submission_count": _submission_count,
		"accepted_count": _accepted_count,
		"rejected_count": _rejected_count,
		"ready_apply_count": _ready_apply_count,
		"reorder_apply_count": _reorder_apply_count,
		"scene_owned": true,
		"owns_card_rules": false,
		"owns_queue": false,
		"owns_rng": false,
		"owns_save_state": false,
		"references_main": false,
	}


func _validate_actor_entry(actor_index: int, resolution_id: int) -> Dictionary:
	var world := _world()
	var queue := _queue()
	if world == null or queue == null:
		return {"valid": false, "reason_id": "card_group_dependency_missing"}
	if actor_index < 0 or actor_index >= world.players.size():
		return {"valid": false, "reason_id": "player_unavailable"}
	var player: Dictionary = world.players[actor_index] if world.players[actor_index] is Dictionary else {}
	if bool(player.get("eliminated", false)):
		return {"valid": false, "reason_id": "player_unavailable"}
	var entry := _current_entry_by_id(queue.current_queue(), resolution_id)
	if entry.is_empty() or int(entry.get("player_index", -1)) != actor_index:
		return {"valid": false, "reason_id": "card_group_target_invalid"}
	return {"valid": true, "reason_id": ""}


func _current_entry_by_id(entries: Array, resolution_id: int) -> Dictionary:
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if int(entry.get("resolution_id", entry.get("queued_order", -1))) == resolution_id:
			return entry.duplicate(true)
	return {}


func _card_group_facts() -> Dictionary:
	var controller := _controller()
	var queue := _queue()
	var facts := controller.card_play_fact_snapshot() if controller != null else {}
	var public_queue := queue.public_snapshot() if queue != null else {}
	facts["queue_empty"] = int(public_queue.get("current_count", 0)) <= 0
	facts["active_present"] = bool(public_queue.get("active_present", false))
	return facts


func _active_player_indices() -> Array:
	var result: Array = []
	var world := _world()
	if world == null:
		return result
	for player_index in range(world.players.size()):
		var player: Dictionary = world.players[player_index] if world.players[player_index] is Dictionary else {}
		if not bool(player.get("eliminated", false)):
			result.append(player_index)
	return result


func _queue_revision() -> int:
	var queue := _queue()
	return maxi(0, int(queue.debug_snapshot().get("revision", 0))) if queue != null else 0


func _rejected(reason_id: String) -> Dictionary:
	_rejected_count += 1
	return {
		"accepted": false,
		"reason_id": reason_id if not reason_id.is_empty() else "card_group_action_rejected",
		"effect_ref": "none",
		"authoritative_revision": _queue_revision(),
	}


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _queue() -> CardResolutionQueueRuntimeService:
	return get_node_or_null(queue_service_path) as CardResolutionQueueRuntimeService


func _controller() -> CardResolutionRuntimeController:
	return get_node_or_null(resolution_controller_path) as CardResolutionRuntimeController
