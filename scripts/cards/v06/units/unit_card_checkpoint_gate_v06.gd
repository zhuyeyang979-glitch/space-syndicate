extends RefCounted
class_name UnitCardCheckpointGateV06

var _router: Object
var _participants: Array[Object] = []


func configure(router: Object, participants: Array) -> Dictionary:
	_router = router
	_participants.clear()
	for participant_variant in participants:
		if participant_variant is Object:
			_participants.append(participant_variant as Object)
	return {
		"configured": _router != null and _router.has_method("checkpoint_status"),
		"participant_count": _participants.size(),
		"status": checkpoint_status(),
	}


func checkpoint_status() -> Dictionary:
	if _router == null or not _router.has_method("checkpoint_status"):
		return {"can_checkpoint": false, "reason_code": "unit_checkpoint_router_missing", "participants": []}
	var router_variant: Variant = _router.call("checkpoint_status")
	if not (router_variant is Dictionary):
		return {"can_checkpoint": false, "reason_code": "unit_checkpoint_router_receipt_invalid", "participants": []}
	var router_status: Dictionary = (router_variant as Dictionary).duplicate(true)
	var participant_statuses: Array = []
	var ready := bool(router_status.get("can_checkpoint", false))
	for participant in _participants:
		var participant_status := {"can_checkpoint": false, "reason_code": "unit_checkpoint_participant_gate_missing"}
		if participant.has_method("checkpoint_status"):
			var value_variant: Variant = participant.call("checkpoint_status")
			if value_variant is Dictionary:
				participant_status = (value_variant as Dictionary).duplicate(true)
		participant_statuses.append(participant_status)
		ready = ready and bool(participant_status.get("can_checkpoint", false))
	return {
		"can_checkpoint": ready,
		"reason_code": "unit_checkpoint_ready" if ready else "unit_checkpoint_inflight_or_owner_unsafe",
		"router": router_status,
		"participants": participant_statuses,
	}


func require_checkpoint_ready() -> Dictionary:
	var status := checkpoint_status()
	if bool(status.get("can_checkpoint", false)):
		return {"allowed": true, "reason_code": "unit_checkpoint_ready"}
	return {
		"allowed": false,
		"reason_code": "unit_checkpoint_inflight_or_owner_unsafe",
		"player_feedback": {
			"reason": "仍有单位牌动作正在结算。",
			"next_step": "等待当前动作完成或安全撤销后再保存。",
		},
		"developer_fields": status,
	}
