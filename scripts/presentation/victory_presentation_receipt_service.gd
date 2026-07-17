@tool
extends Node
class_name VictoryPresentationReceiptService

signal outcome_presentation_ready(receipt: VictoryPresentationStateChangeReceipt)

var _victory: VictoryControlRuntimeController
var _world_query: WorldSessionPresentationQuery
var _map_query: TablePublicMapQuery
var _public_log: PublicLogProducerPort
var _last_state := "idle"
var _revision := 0
var _applied_outcome_ids: Dictionary = {}
var _state_receipt_count := 0
var _outcome_receipt_count := 0


func configure(
	victory: VictoryControlRuntimeController,
	world_query: WorldSessionPresentationQuery,
	map_query: TablePublicMapQuery,
	public_log: PublicLogProducerPort
) -> void:
	_victory = victory
	_world_query = world_query
	_map_query = map_query
	_public_log = public_log
	var snapshot := _victory.public_snapshot() if _victory != null else {}
	_last_state = str(snapshot.get("state", "idle"))


func reset_state() -> void:
	_last_state = "idle"
	_revision = 0
	_applied_outcome_ids.clear()
	_state_receipt_count = 0
	_outcome_receipt_count = 0


func capture_advance_result(result: Dictionary) -> VictoryPresentationStateChangeReceipt:
	var public_snapshot: Dictionary = result.get("public_snapshot", {}) if result.get("public_snapshot", {}) is Dictionary else {}
	var next_state := str(public_snapshot.get("state", _last_state))
	if public_snapshot.is_empty() or next_state == _last_state:
		return null
	_revision += 1
	var receipt := _receipt("state_changed", _last_state, next_state, public_snapshot, "victory-state-%d" % _revision)
	if not receipt.is_valid():
		_revision -= 1
		return null
	_last_state = next_state
	_state_receipt_count += 1
	if _public_log != null:
		_public_log.publish(
			&"victory_state_changed",
			&"victory.public.state_changed",
			{"previous_state": receipt.previous_state, "state": next_state},
			_revision,
			_world_time(),
			receipt.receipt_id + "-log"
		)
	return receipt


func capture_outcome(public_snapshot: Dictionary) -> VictoryPresentationStateChangeReceipt:
	var outcome: Dictionary = public_snapshot.get("outcome_receipt", {}) if public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	if outcome_id.is_empty() or _applied_outcome_ids.has(outcome_id):
		return null
	_revision += 1
	var state := str(public_snapshot.get("state", "resolved"))
	var receipt := _receipt("outcome", _last_state, state, public_snapshot, "victory-outcome-%s" % outcome_id.sha256_text().left(16))
	if not receipt.is_valid():
		return null
	_applied_outcome_ids[outcome_id] = true
	_last_state = state
	_outcome_receipt_count += 1
	outcome_presentation_ready.emit(receipt)
	return receipt


func debug_snapshot() -> Dictionary:
	return {
		"configured": _victory != null and _world_query != null and _map_query != null,
		"last_state": _last_state,
		"revision": _revision,
		"state_receipt_count": _state_receipt_count,
		"outcome_receipt_count": _outcome_receipt_count,
		"applied_outcome_count": _applied_outcome_ids.size(),
		"visibility_safe": true,
		"owns_victory_rules": false,
	}


func _receipt(kind: StringName, previous: String, next: String, public_snapshot: Dictionary, receipt_id: String) -> VictoryPresentationStateChangeReceipt:
	var receipt := VictoryPresentationStateChangeReceipt.new()
	receipt.receipt_id = receipt_id
	receipt.revision = _revision
	receipt.change_kind = kind
	receipt.previous_state = previous
	receipt.state = next
	receipt.world_time = _world_time()
	receipt.public_snapshot = VictoryPresentationStateChangeReceipt.project_public_snapshot(public_snapshot)
	receipt.participant_names = VictoryPresentationStateChangeReceipt.project_participant_names(
		_world_query.public_participant_names() if _world_query != null else {}
	)
	receipt.public_map_facts = VictoryPresentationStateChangeReceipt.project_public_map_facts(
		_map_query.public_map_facts() if _map_query != null else {}
	)
	receipt.immediate_refresh_mask = [&"live", &"full"]
	return receipt


func _world_time() -> float:
	var projection := _world_query.public_projection() if _world_query != null else null
	return projection.game_time if projection != null else 0.0


func _state_label(state: String) -> String:
	return {"idle": "等待资格", "qualification": "资格确认", "audit": "公开审计", "resolved": "审计完成"}.get(state, state)
