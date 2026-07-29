extends Node
class_name RuntimeCommandPhaseCoordinator

var _lifecycle: RuntimeLifecyclePort
var _card: RuntimeCardPort


func bind_ports(lifecycle: RuntimeLifecyclePort, card: RuntimeCardPort) -> void:
	_lifecycle = lifecycle
	_card = card


func is_ready() -> bool:
	return _lifecycle != null and _lifecycle.is_ready() and _card != null and _card.is_ready()


func immediate_facility_resolution_pending() -> Dictionary:
	return _card.immediate_facility_resolution_pending() if _card != null else {
		"pending": false,
		"reason_code": "runtime_card_port_missing",
	}


func advance_active(context: RuntimePhaseFrameContext) -> void:
	context.enter_phase(&"command")
	context.append_step(&"card_resolution_gate")
	var card_receipt := {"handled": false, "reason": "card_resolution_progress_blocked"}
	if _lifecycle.allows_card_resolution_progress():
		context.append_step(&"advance_card_resolution_frame")
		card_receipt = _card.advance_card_resolution_frame(context.world_delta)
	if bool(card_receipt.get("consumes_command_frame", false)):
		context.world_delta = 0.0
		context.stopped_reason = &"facility_resolution_command_only"
		context.append_step(&"facility_resolution_command_only")
		context.command_phase_consumes_frame = true
		context.command_phase_receipt = {
			"advanced": bool(card_receipt.get("handled", false)),
			"consumes_command_frame": true,
			"card_receipt": card_receipt.duplicate(true),
		}
		return
	context.append_step(&"advance_card_cooldowns")
	_card.advance_card_cooldowns(context.world_delta)
	context.command_phase_consumes_frame = false
	context.command_phase_receipt = {
		"advanced": bool(card_receipt.get("handled", false)),
		"consumes_command_frame": false,
		"card_receipt": card_receipt.duplicate(true),
	}


func debug_snapshot() -> Dictionary:
	return {"ready": is_ready(), "operation_count": 1, "owns_world_state": false}
