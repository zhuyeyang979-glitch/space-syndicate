@tool
extends Node
class_name CardCommitmentRuntimeService

const DEFAULT_ACTION_COOLDOWN := 1.2

var _world_session_state: WorldSessionState
var _cooldown_controller: CardCooldownRuntimeController
var _weather_telemetry: WeatherTelemetryRuntimeService
var _eligibility_facts: CardPlayEligibilityWorldBridge
var _eligibility_service: CardPlayEligibilityRuntimeService
var _completed: Dictionary = {}
var _revision := 0


func set_dependencies(
	world_session_state: WorldSessionState,
	cooldown_controller: CardCooldownRuntimeController,
	weather_telemetry: WeatherTelemetryRuntimeService,
	eligibility_facts: CardPlayEligibilityWorldBridge,
	eligibility_service: CardPlayEligibilityRuntimeService
) -> void:
	_world_session_state = world_session_state
	_cooldown_controller = cooldown_controller
	_weather_telemetry = weather_telemetry
	_eligibility_facts = eligibility_facts
	_eligibility_service = eligibility_service


func finalize_commitment(request: Dictionary) -> Dictionary:
	var entry: Dictionary = _dictionary(request.get("entry", {}))
	var skill: Dictionary = _dictionary(request.get("skill", entry.get("skill", {})))
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var transaction_id := str(request.get("transaction_id", "card-commitment:%d" % resolution_id))
	if resolution_id < 0 or transaction_id.is_empty():
		return _receipt(false, "commitment_binding_invalid", resolution_id)
	if _completed.has(transaction_id):
		return (_completed[transaction_id] as Dictionary).duplicate(true)
	var player_index := int(entry.get("player_index", -1))
	if _world_session_state == null or player_index < 0 or player_index >= _world_session_state.players.size() or skill.is_empty():
		return _receipt(false, "commitment_context_missing", resolution_id)
	var players := _world_session_state.players
	var player: Dictionary = players[player_index]
	if not bool(entry.get("play_cost_paid_on_queue", skill.get("_play_cost_paid_on_queue", false))):
		var cost := _cash_cost(player_index, skill, _entry_context(entry))
		if int(player.get("cash", 0)) < cost:
			return _receipt(false, "commitment_cash_unavailable", resolution_id)
		player["cash"] = int(player.get("cash", 0)) - cost
	var consumed_on_queue := bool(entry.get("consumed_on_queue", false))
	var slot_index := int(entry.get("slot_index", -1))
	if not consumed_on_queue and slot_index >= 0:
		var slots: Array = player.get("slots", []) if player.get("slots", []) is Array else []
		if slot_index < slots.size() and slots[slot_index] is Dictionary:
			if bool(skill.get("persistent", false)):
				_cooldown_controller.arm_persistent_card(
					player_index,
					slot_index,
					str(skill.get("runtime_instance_id", "")),
					float(skill.get("cooldown", 8.0))
				)
			else:
				slots[slot_index] = null
				player["slots"] = slots
	players[player_index] = player
	_world_session_state.players = players
	_cooldown_controller.arm_player_action(player_index, float(request.get("action_cooldown", DEFAULT_ACTION_COOLDOWN)))
	var response_region := int(skill.get("target_district", request.get("selected_district", -1)))
	if response_region >= 0 and _weather_telemetry != null:
		var category := "build_after_forecast" if str(skill.get("kind", "")) in ["public_facility", "city_development", "city_product_upgrade", "city_product_shift"] else "play_after_forecast"
		_weather_telemetry.record_public_response(response_region, category)
	_revision += 1
	var result := _receipt(true, "committed", resolution_id)
	result["transaction_id"] = transaction_id
	result["revision"] = _revision
	_completed[transaction_id] = result
	return result.duplicate(true)


func to_save_data() -> Dictionary:
	return {"schema_version": 1, "revision": _revision, "completed": _completed.duplicate(true)}


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != 1 or not (data.get("completed", {}) is Dictionary):
		return {"applied": false, "reason": "commitment_save_invalid"}
	_completed = (data.get("completed", {}) as Dictionary).duplicate(true)
	_revision = maxi(0, int(data.get("revision", 0)))
	return {"applied": true, "completed_count": _completed.size()}


func debug_snapshot() -> Dictionary:
	return {"service_ready": _world_session_state != null and _cooldown_controller != null, "completed_count": _completed.size(), "revision": _revision, "cash_owner": false, "inventory_owner": false}


func _cash_cost(player_index: int, skill: Dictionary, context: Dictionary) -> int:
	if _eligibility_facts == null or _eligibility_service == null:
		return maxi(0, int(skill.get("play_cash_cost", 0)))
	var facts := _eligibility_facts.build_facts(player_index, skill, context)
	var result := _eligibility_service.evaluate_play({"player_index": player_index, "skill": skill, "evaluation_mode": "catalog"}, facts)
	return maxi(0, int(result.get("cash_cost", 0)))


func _entry_context(entry: Dictionary) -> Dictionary:
	return {
		"selected_district": int(entry.get("selected_district", -1)),
		"selected_trade_product": str(entry.get("selected_trade_product", "")),
		"contract_source_district": int(entry.get("contract_source_district", -1)),
		"contract_target_district": int(entry.get("contract_target_district", -1)),
		"play_requirement_district": int(entry.get("play_requirement_district", -1)),
	}


func _receipt(committed: bool, reason: String, resolution_id: int) -> Dictionary:
	return {"intent_type": "finish_card_commitment", "committed": committed, "reason": reason, "resolution_id": resolution_id}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
