extends Node
class_name RuntimeCardPort

var _frame_driver: CardResolutionFrameDriver
var _cooldowns: CardCooldownRuntimeController
var _scheduler: ForcedDecisionRuntimeScheduler


func bind_dependencies(
	frame_driver: CardResolutionFrameDriver,
	cooldowns: CardCooldownRuntimeController,
	scheduler: ForcedDecisionRuntimeScheduler
) -> void:
	_frame_driver = frame_driver
	_cooldowns = cooldowns
	_scheduler = scheduler


func is_ready() -> bool:
	return is_instance_valid(_frame_driver) and is_instance_valid(_cooldowns) \
		and is_instance_valid(_scheduler)


func advance_card_resolution_frame(delta_seconds: float) -> Dictionary:
	return _frame_driver.advance_world(delta_seconds) if _frame_driver != null else {
		"handled": false,
		"reason": "card_resolution_frame_driver_unavailable",
	}


func advance_card_cooldowns(delta_seconds: float) -> Dictionary:
	return _cooldowns.advance_world(delta_seconds) if _cooldowns != null else {
		"advanced": false,
		"reason": "card_cooldown_controller_unavailable",
	}


func debug_snapshot() -> Dictionary:
	return {"port_kind": "card", "ready": is_ready(), "operation_count": 2, "owns_card_state": false}
