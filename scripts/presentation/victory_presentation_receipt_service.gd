@tool
extends Node
class_name VictoryPresentationReceiptService

signal outcome_presentation_ready(receipt: VictoryPresentationStateChangeReceipt)

const SESSION_CHECKPOINT_SCHEMA_VERSION := 1
const SESSION_CHECKPOINT_KEYS := [
	"schema_version",
	"last_state",
	"revision",
	"applied_outcome_ids",
	"retained_outcome_receipts",
	"state_receipt_count",
	"outcome_receipt_count",
]
const RECEIPT_DATA_KEYS := [
	"receipt_id",
	"revision",
	"change_kind",
	"previous_state",
	"state",
	"world_time",
	"public_snapshot",
	"participant_names",
	"public_map_facts",
	"immediate_refresh_mask",
	"visibility_scope",
]

var _victory: VictoryControlRuntimeController
var _world_query: WorldSessionPresentationQuery
var _map_query: TablePublicMapQuery
var _public_log: PublicLogProducerPort
var _last_state := "idle"
var _revision := 0
var _applied_outcome_ids: Dictionary = {}
var _retained_outcome_receipts: Dictionary = {}
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
	_retained_outcome_receipts.clear()
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
	var receipt: VictoryPresentationStateChangeReceipt
	var retained_variant: Variant = _retained_outcome_receipts.get(outcome_id)
	if retained_variant is Dictionary:
		var retained := (retained_variant as Dictionary).duplicate(true)
		var projected_snapshot := VictoryPresentationStateChangeReceipt.project_public_snapshot(public_snapshot)
		if projected_snapshot != retained.get("public_snapshot", {}):
			return null
		receipt = _receipt_from_dictionary(retained)
		if receipt == null:
			return null
	else:
		_revision += 1
		var state := str(public_snapshot.get("state", "resolved"))
		receipt = _receipt("outcome", _last_state, state, public_snapshot, "victory-outcome-%s" % outcome_id.sha256_text().left(16))
		if not receipt.is_valid():
			_revision -= 1
			return null
		_retained_outcome_receipts[outcome_id] = receipt.to_dictionary()
	_applied_outcome_ids[outcome_id] = true
	_last_state = receipt.state
	_outcome_receipt_count += 1
	outcome_presentation_ready.emit(receipt)
	return receipt


func release_outcome_for_retry(receipt: VictoryPresentationStateChangeReceipt) -> bool:
	if receipt == null or not receipt.is_valid():
		return false
	var outcome: Dictionary = receipt.public_snapshot.get("outcome_receipt", {}) \
		if receipt.public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	var outcome_id := str(outcome.get("outcome_id", "")).strip_edges()
	var expected_receipt_id := "victory-outcome-%s" % outcome_id.sha256_text().left(16) \
		if not outcome_id.is_empty() else ""
	if outcome_id.is_empty() or receipt.receipt_id != expected_receipt_id \
			or not _applied_outcome_ids.has(outcome_id) \
			or not _retained_outcome_receipts.has(outcome_id) \
			or _retained_outcome_receipts.get(outcome_id) != receipt.to_dictionary():
		return false
	_applied_outcome_ids.erase(outcome_id)
	_outcome_receipt_count = maxi(0, _outcome_receipt_count - 1)
	_last_state = receipt.previous_state
	return true


func capture_session_checkpoint() -> Dictionary:
	return {
		"schema_version": SESSION_CHECKPOINT_SCHEMA_VERSION,
		"last_state": _last_state,
		"revision": _revision,
		"applied_outcome_ids": _applied_outcome_ids.duplicate(true),
		"retained_outcome_receipts": _retained_outcome_receipts.duplicate(true),
		"state_receipt_count": _state_receipt_count,
		"outcome_receipt_count": _outcome_receipt_count,
	}


func restore_session_checkpoint(checkpoint: Dictionary) -> bool:
	if not TablePresentationPureDataPolicy.is_pure_data(checkpoint) \
			or not _has_exact_keys(checkpoint, SESSION_CHECKPOINT_KEYS) \
			or typeof(checkpoint.get("schema_version")) != TYPE_INT \
			or int(checkpoint.get("schema_version", 0)) != SESSION_CHECKPOINT_SCHEMA_VERSION \
			or not (checkpoint.get("last_state") is String) \
			or typeof(checkpoint.get("revision")) != TYPE_INT \
			or int(checkpoint.get("revision", -1)) < 0 \
			or not (checkpoint.get("applied_outcome_ids") is Dictionary) \
			or not (checkpoint.get("retained_outcome_receipts") is Dictionary) \
			or typeof(checkpoint.get("state_receipt_count")) != TYPE_INT \
			or int(checkpoint.get("state_receipt_count", -1)) < 0 \
			or typeof(checkpoint.get("outcome_receipt_count")) != TYPE_INT \
			or int(checkpoint.get("outcome_receipt_count", -1)) < 0:
		return false
	var retained_source := checkpoint.get("retained_outcome_receipts", {}) as Dictionary
	var retained_normalized: Dictionary = {}
	for outcome_id_variant in retained_source.keys():
		var outcome_id := str(outcome_id_variant).strip_edges()
		var receipt_data_variant: Variant = retained_source.get(outcome_id_variant)
		if outcome_id.is_empty() or outcome_id != str(outcome_id_variant) \
				or not (receipt_data_variant is Dictionary):
			return false
		var receipt_data := (receipt_data_variant as Dictionary).duplicate(true)
		var receipt := _receipt_from_dictionary(receipt_data)
		if receipt == null or receipt.change_kind != &"outcome" \
				or receipt.revision > int(checkpoint.get("revision", 0)) \
				or _outcome_id(receipt.public_snapshot) != outcome_id \
				or receipt.receipt_id != "victory-outcome-%s" % outcome_id.sha256_text().left(16):
			return false
		retained_normalized[outcome_id] = receipt.to_dictionary()
	var applied_source := checkpoint.get("applied_outcome_ids", {}) as Dictionary
	var applied_normalized: Dictionary = {}
	for outcome_id_variant in applied_source.keys():
		var outcome_id := str(outcome_id_variant).strip_edges()
		if outcome_id.is_empty() or outcome_id != str(outcome_id_variant) \
				or typeof(applied_source.get(outcome_id_variant)) != TYPE_BOOL \
				or not bool(applied_source.get(outcome_id_variant)) \
				or not retained_normalized.has(outcome_id):
			return false
		applied_normalized[outcome_id] = true
	if int(checkpoint.get("outcome_receipt_count", 0)) != applied_normalized.size():
		return false
	_last_state = str(checkpoint.get("last_state", "idle"))
	_revision = int(checkpoint.get("revision", 0))
	_applied_outcome_ids = applied_normalized
	_retained_outcome_receipts = retained_normalized
	_state_receipt_count = int(checkpoint.get("state_receipt_count", 0))
	_outcome_receipt_count = int(checkpoint.get("outcome_receipt_count", 0))
	return true


func debug_snapshot() -> Dictionary:
	return {
		"configured": _victory != null and _world_query != null and _map_query != null,
		"last_state": _last_state,
		"revision": _revision,
		"state_receipt_count": _state_receipt_count,
		"outcome_receipt_count": _outcome_receipt_count,
		"applied_outcome_count": _applied_outcome_ids.size(),
		"retained_outcome_receipt_count": _retained_outcome_receipts.size(),
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


func _receipt_from_dictionary(data: Dictionary) -> VictoryPresentationStateChangeReceipt:
	if not TablePresentationPureDataPolicy.is_pure_data(data) \
			or not _has_exact_keys(data, RECEIPT_DATA_KEYS) \
			or typeof(data.get("revision")) != TYPE_INT \
			or int(data.get("revision", -1)) < 0 \
			or not (data.get("world_time") is int or data.get("world_time") is float) \
			or not is_finite(float(data.get("world_time", -1.0))) \
			or float(data.get("world_time", -1.0)) < 0.0 \
			or not (data.get("public_snapshot") is Dictionary) \
			or not (data.get("participant_names") is Dictionary) \
			or not (data.get("public_map_facts") is Dictionary) \
			or not (data.get("immediate_refresh_mask") is Array) \
			or str(data.get("visibility_scope", "")) != "public":
		return null
	var refresh_mask: Array[StringName] = []
	for value_variant in data.get("immediate_refresh_mask", []):
		if not (value_variant is String or value_variant is StringName) \
				or str(value_variant).strip_edges().is_empty():
			return null
		refresh_mask.append(StringName(str(value_variant)))
	var receipt := VictoryPresentationStateChangeReceipt.new()
	receipt.receipt_id = str(data.get("receipt_id", ""))
	receipt.revision = int(data.get("revision", 0))
	receipt.change_kind = StringName(str(data.get("change_kind", "")))
	receipt.previous_state = str(data.get("previous_state", "idle"))
	receipt.state = str(data.get("state", "idle"))
	receipt.world_time = float(data.get("world_time", 0.0))
	receipt.public_snapshot = (data.get("public_snapshot", {}) as Dictionary).duplicate(true)
	receipt.participant_names = (data.get("participant_names", {}) as Dictionary).duplicate(true)
	receipt.public_map_facts = (data.get("public_map_facts", {}) as Dictionary).duplicate(true)
	receipt.immediate_refresh_mask = refresh_mask
	return receipt if receipt.is_valid() and receipt.to_dictionary() == data else null


func _outcome_id(public_snapshot: Dictionary) -> String:
	var outcome: Dictionary = public_snapshot.get("outcome_receipt", {}) \
		if public_snapshot.get("outcome_receipt", {}) is Dictionary else {}
	return str(outcome.get("outcome_id", "")).strip_edges()


func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true


func _state_label(state: String) -> String:
	return {"idle": "等待资格", "qualification": "资格确认", "audit": "公开审计", "resolved": "审计完成"}.get(state, state)
