@tool
extends Node
class_name CardCounterSettlementRuntimeService

var _queue_service: CardResolutionQueueRuntimeService
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility_service: CardPlayEligibilityRuntimeService
var _commitment_service: CardCommitmentRuntimeService
var _history_service: CardResolutionHistoryRuntimeService
var _presentation_port: CardResolutionPresentationPort
var _runtime_coordinator: GameRuntimeCoordinator
var _world_session_state: WorldSessionState
var _settled_targets: Dictionary = {}


func set_dependencies(
	queue_service: CardResolutionQueueRuntimeService,
	eligibility_facts: CardPlayEligibilityWorldBridge,
	eligibility_service: CardPlayEligibilityRuntimeService,
	commitment_service: CardCommitmentRuntimeService,
	history_service: CardResolutionHistoryRuntimeService,
	presentation_port: CardResolutionPresentationPort,
	runtime_coordinator: GameRuntimeCoordinator,
	world_session_state: WorldSessionState
) -> void:
	_queue_service = queue_service
	_eligibility_facts = eligibility_facts
	_eligibility_service = eligibility_service
	_commitment_service = commitment_service
	_history_service = history_service
	_presentation_port = presentation_port
	_runtime_coordinator = runtime_coordinator
	_world_session_state = world_session_state


func resolve_counter(target_entry: Dictionary) -> Dictionary:
	var target_id := int(target_entry.get("resolution_id", target_entry.get("queued_order", -1)))
	var target_key := str(target_id)
	if target_id < 0:
		return _receipt(false, -1, "target_resolution_invalid")
	if _settled_targets.has(target_key):
		return (_settled_targets[target_key] as Dictionary).duplicate(true)
	var counter_entry := _find_counter(target_entry)
	if counter_entry.is_empty():
		var miss := _receipt(false, -1, "no_counter")
		_settled_targets[target_key] = miss
		return miss
	var counter_id := int(counter_entry.get("resolution_id", counter_entry.get("queued_order", -1)))
	var removed := _queue_service.remove_entry_by_id(counter_id)
	if removed.is_empty():
		return _receipt(false, -1, "counter_remove_failed")
	var counter_skill: Dictionary = _dictionary(counter_entry.get("skill", {}))
	var commitment := _commitment_service.finalize_commitment({
		"transaction_id": "counter-commitment:%d" % counter_id,
		"entry": counter_entry,
		"skill": counter_skill,
		"selected_district": int(target_entry.get("selected_district", -1)),
	})
	if not bool(commitment.get("committed", false)):
		return _receipt(false, -1, str(commitment.get("reason", "counter_commitment_failed")))
	var refund := maxi(0, int(counter_skill.get("counter_refund", 0)))
	if refund > 0:
		var player_index := int(counter_entry.get("player_index", -1))
		if _world_session_state != null and player_index >= 0 and player_index < _world_session_state.players.size():
			var players := _world_session_state.players
			(players[player_index] as Dictionary)["cash"] = int((players[player_index] as Dictionary).get("cash", 0)) + refund
			_world_session_state.players = players
	counter_entry["resolved_time"] = _world_session_state.game_time if _world_session_state != null else 0.0
	counter_entry["countered_resolution_id"] = target_id
	counter_entry["aftermath_clue"] = "反制成功：目标卡牌被取消。"
	_history_service.append_resolved(counter_entry)
	_runtime_coordinator.settle_card_mana_reservation(counter_entry, {"resolved": true, "reason": "counter_resolved"})
	_presentation_port.publish_public_event({
		"event_id": "counter:%d" % counter_id,
		"event_kind": "card_counter",
		"resolution_id": counter_id,
		"card_name": str(counter_skill.get("name", "相位否决")),
		"status": "resolved",
		"summary": "目标卡牌被反制；反制者保持隐藏。",
		"district_index": int(target_entry.get("selected_district", -1)),
	})
	var result := _receipt(true, counter_id, "countered")
	result["counter_card_name"] = str(counter_skill.get("name", "相位否决"))
	_settled_targets[target_key] = result
	return result.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {"service_ready": _queue_service != null and _history_service != null, "settled_target_count": _settled_targets.size(), "queue_owner": false, "history_owner": false}


func _find_counter(target_entry: Dictionary) -> Dictionary:
	for entries in [_queue_service.next_queue(), _queue_service.current_queue()]:
		for entry_variant in entries:
			if entry_variant is Dictionary and _can_counter(entry_variant as Dictionary, target_entry):
				return (entry_variant as Dictionary).duplicate(true)
	return {}


func _can_counter(counter_entry: Dictionary, target_entry: Dictionary) -> bool:
	var counter_skill: Dictionary = _dictionary(counter_entry.get("skill", {}))
	var target_skill: Dictionary = _dictionary(target_entry.get("skill", {}))
	if str(counter_skill.get("kind", "")) != "card_counter" or not _eligibility_service.is_counterable_player_interaction(target_skill):
		return false
	var player_index := int(counter_entry.get("player_index", -1))
	var facts := _eligibility_facts.build_facts(player_index, counter_skill)
	var result := _eligibility_service.evaluate_play({"player_index": player_index, "skill": counter_skill, "evaluation_mode": "rule"}, facts)
	return bool(result.get("allowed", false))


func _receipt(countered: bool, counter_id: int, reason: String) -> Dictionary:
	return {"intent_type": "counter_check", "countered": countered, "counter_resolution_id": counter_id, "counter_card_name": "", "reason": reason}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
