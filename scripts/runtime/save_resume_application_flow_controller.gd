@tool
extends Node
class_name SaveResumeApplicationFlowController

## Scene-owned local save/resume application flow. It submits typed intents to
## one high-level runtime gateway and projects only a closed player-safe status.
## It never captures, parses, stores, or applies a raw save envelope.

signal public_state_changed(snapshot: Dictionary)
signal receipt_ready(receipt: SaveResumeReceiptV06)

const HIGH_LEVEL_GATEWAY_METHOD := &"submit_save_resume_intent"

@export var runtime_gateway_path: NodePath
@export var inspect_on_ready := false

var _operation_sequence := 0
var _inspect_count := 0
var _save_count := 0
var _resume_count := 0
var _rejection_count := 0
var _busy := false
var _active_operation: StringName = &""
var _last_public_snapshot := SaveResumeReceiptV06.unavailable_public_snapshot()


func _ready() -> void:
	if inspect_on_ready and not Engine.is_editor_hint():
		call_deferred("inspect_slot", &"root_menu")


func inspect_slot(source_surface: StringName = &"root_menu") -> SaveResumeReceiptV06:
	_inspect_count += 1
	return submit_intent(SaveResumeIntentV06.inspect(_next_request_id(), source_surface))


func request_save_game(source_surface: StringName = &"pause_menu") -> SaveResumeReceiptV06:
	_save_count += 1
	return submit_intent(SaveResumeIntentV06.save(_next_request_id(), source_surface))


func request_resume_game(source_surface: StringName = &"root_menu") -> SaveResumeReceiptV06:
	_resume_count += 1
	return submit_intent(SaveResumeIntentV06.resume(_next_request_id(), source_surface))


func submit_intent(intent: SaveResumeIntentV06) -> SaveResumeReceiptV06:
	if intent == null or not intent.is_valid():
		_rejection_count += 1
		return _publish_terminal_receipt(SaveResumeReceiptV06.rejected(intent, "intent_invalid"))
	if _busy:
		_rejection_count += 1
		var busy_receipt := SaveResumeReceiptV06.rejected(intent, "operation_in_progress")
		receipt_ready.emit(busy_receipt)
		return busy_receipt
	_busy = true
	_active_operation = intent.operation
	_publish_public_snapshot(SaveResumeReceiptV06.busy_public_snapshot(_active_operation))
	var gateway := _runtime_gateway()
	var receipt: SaveResumeReceiptV06
	if gateway == null or not gateway.has_method(HIGH_LEVEL_GATEWAY_METHOD):
		receipt = SaveResumeReceiptV06.rejected(intent, "save_resume_gateway_unavailable")
	else:
		var detached_intent := intent.detached_copy()
		var result: Variant = gateway.call(HIGH_LEVEL_GATEWAY_METHOD, detached_intent)
		receipt = SaveResumeReceiptV06.from_gateway_result(intent, result)
		if not receipt.accepted:
			_rejection_count += 1
	_busy = false
	_active_operation = &""
	return _publish_terminal_receipt(receipt)


func public_snapshot() -> Dictionary:
	return _last_public_snapshot.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "save_resume_application_flow_controller_v06",
		"mechanic_id": SaveSlotPolicyV06.MECHANIC_ID,
		"slot_descriptor": SaveSlotPolicyV06.production_slot_descriptor(),
		"runtime_gateway_ready": _runtime_gateway() != null \
			and _runtime_gateway().has_method(HIGH_LEVEL_GATEWAY_METHOD),
		"busy": _busy,
		"active_operation": String(_active_operation),
		"operation_sequence": _operation_sequence,
		"inspect_count": _inspect_count,
		"save_count": _save_count,
		"resume_count": _resume_count,
		"rejection_count": _rejection_count,
		"public_snapshot": public_snapshot(),
		"owns_gameplay_state": false,
		"owns_save_data": false,
		"owns_raw_envelope": false,
		"owns_file_io": false,
		"owns_rng": false,
		"parses_raw_envelope": false,
		"references_main": false,
	}


func _next_request_id() -> String:
	_operation_sequence += 1
	return "save-resume:%d" % _operation_sequence


func _publish_terminal_receipt(receipt: SaveResumeReceiptV06) -> SaveResumeReceiptV06:
	_publish_public_snapshot(receipt.public_snapshot())
	receipt_ready.emit(receipt)
	return receipt


func _publish_public_snapshot(snapshot: Dictionary) -> void:
	_last_public_snapshot = snapshot.duplicate(true)
	public_state_changed.emit(_last_public_snapshot.duplicate(true))


func _runtime_gateway() -> Node:
	return get_node_or_null(runtime_gateway_path) if not runtime_gateway_path.is_empty() else null
