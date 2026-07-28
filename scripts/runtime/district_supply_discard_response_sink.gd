@tool
extends Node
class_name DistrictSupplyDiscardResponseSink

signal receipt_ready(receipt: DistrictSupplyActionReceipt)

var _action_port: DistrictSupplyActionPort
var _consume_count := 0
var _applied_count := 0
var _rejected_count := 0


func configure(action_port: DistrictSupplyActionPort) -> bool:
	_action_port = action_port
	return _action_port != null


func consume_authorized_response(request: ForcedDecisionResponseRequest) -> DistrictSupplyActionReceipt:
	if request == null or str(request.decision_kind) != "discard_purchase":
		return null
	_consume_count += 1
	if _action_port == null or not bool(request.validation_report().get("valid", false)):
		_rejected_count += 1
		return null
	var action_kind := DistrictSupplyActionIntent.KIND_DISCARD_CANCEL
	var discard_slot := -1
	if request.option_id != "discard_purchase_cancel":
		if not request.option_id.begins_with("discard_purchase_"):
			_rejected_count += 1
			return null
		var slot_text := request.option_id.trim_prefix("discard_purchase_")
		if not slot_text.is_valid_int() or int(slot_text) < 0:
			_rejected_count += 1
			return null
		action_kind = DistrictSupplyActionIntent.KIND_DISCARD_CONFIRM
		discard_slot = int(slot_text)
	var intent := DistrictSupplyActionIntent.new()
	intent.request_id = "forced-discard-adapter:%s" % request.request_id
	intent.action_kind = action_kind
	intent.actor_player_index = request.authorized_player_index
	intent.authorization_revision = request.authorization_revision
	intent.session_id = request.session_id
	intent.session_revision = request.session_revision
	intent.discard_slot = discard_slot
	intent.source_surface = &"forced_decision"
	intent.request_revision = request.request_revision
	var receipt := _action_port.submit_intent(intent)
	if receipt != null and receipt.accepted and receipt.applied:
		_applied_count += 1
	else:
		_rejected_count += 1
	receipt_ready.emit(receipt)
	return receipt


func debug_snapshot() -> Dictionary:
	return {
		"configured": _action_port != null,
		"consume_count": _consume_count,
		"applied_count": _applied_count,
		"rejected_count": _rejected_count,
		"decision_kind": "discard_purchase",
		"typed_requests_only": true,
		"owns_gameplay_state": false,
		"owns_rng": false,
		"references_main": false,
	}
