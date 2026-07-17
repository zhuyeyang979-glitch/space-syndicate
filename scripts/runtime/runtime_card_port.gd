extends Node
class_name RuntimeCardPort

var _frame_driver: CardResolutionFrameDriver
var _contract: ContractRuntimeController
var _cooldowns: CardCooldownRuntimeController
var _scheduler: ForcedDecisionRuntimeScheduler


func bind_dependencies(
	frame_driver: CardResolutionFrameDriver,
	contract: ContractRuntimeController,
	cooldowns: CardCooldownRuntimeController,
	scheduler: ForcedDecisionRuntimeScheduler
) -> void:
	_frame_driver = frame_driver
	_contract = contract
	_cooldowns = cooldowns
	_scheduler = scheduler


func is_ready() -> bool:
	return is_instance_valid(_frame_driver) and is_instance_valid(_contract) \
		and is_instance_valid(_cooldowns) and is_instance_valid(_scheduler)


func advance_card_resolution_frame(delta_seconds: float) -> Dictionary:
	return _frame_driver.advance_world(delta_seconds) if _frame_driver != null else {
		"handled": false,
		"reason": "card_resolution_frame_driver_unavailable",
	}


func tick_contract_runtime(delta_seconds: float) -> Dictionary:
	if _contract == null or _scheduler == null:
		return {"ticked": false, "reason": "contract_runtime_unavailable"}
	var candidates: Array = _scheduler.debug_snapshot().get("candidates", [])
	var active_id := str((candidates[0] as Dictionary).get("id", "")) if not candidates.is_empty() and candidates[0] is Dictionary else ""
	return _contract.tick_visible_offer(delta_seconds, active_id).duplicate(true)


func advance_card_cooldowns(delta_seconds: float) -> Dictionary:
	return _cooldowns.advance_world(delta_seconds) if _cooldowns != null else {
		"advanced": false,
		"reason": "card_cooldown_controller_unavailable",
	}


func debug_snapshot() -> Dictionary:
	return {"port_kind": "card", "ready": is_ready(), "operation_count": 3, "owns_card_state": false}
