@tool
extends Node
class_name BankruptcyNeutralEstateRuntimeController

const RULESET_ID := "v0.6"
const LIFECYCLE_VERSION := 1
const ESTATE_COUNT_KEYS := [
	"hand_cards_removed",
	"goods_removed",
	"military_units_removed",
	"monsters_orphaned",
	"facilities_neutralized",
]

var _configured := false
var _world_bridge: Node
var _journal: Dictionary = {}
var _neutral_rent_journal: Dictionary = {}
var _last_public_receipt: Dictionary = {}
var _last_survivor_transaction_id := ""


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func configure(ruleset_snapshot: Dictionary) -> Dictionary:
	var identity: Dictionary = ruleset_snapshot.get("identity", ruleset_snapshot) if ruleset_snapshot.get("identity", ruleset_snapshot) is Dictionary else {}
	_configured = str(identity.get("ruleset_id", ruleset_snapshot.get("ruleset_id", ""))) == RULESET_ID \
		and _world_bridge != null \
		and _world_bridge.has_method("capture_bankruptcy_candidates") \
		and _world_bridge.has_method("bankruptcy_estate_stage")
	return {
		"configured": _configured,
		"reason_code": "bankruptcy_neutral_estate_ready" if _configured else "bankruptcy_neutral_estate_dependencies_missing",
		"lifecycle_version": LIFECYCLE_VERSION,
	}


func reset_state() -> void:
	_journal.clear()
	_neutral_rent_journal.clear()
	_last_public_receipt.clear()
	_last_survivor_transaction_id = ""


func settle_checkpoint(request: Dictionary) -> Dictionary:
	var prepared := prepare_checkpoint(request)
	if not bool(prepared.get("prepared", false)):
		return prepared
	if bool(prepared.get("terminal", false)):
		return prepared
	var committed := commit_checkpoint(prepared)
	if not bool(committed.get("committed", false)):
		return committed
	return finalize_checkpoint(committed)


func prepare_checkpoint(request: Dictionary) -> Dictionary:
	if not _configured or _world_bridge == null:
		return _failure("bankruptcy_neutral_estate_not_ready")
	if not _is_pure_data(request):
		return _failure("bankruptcy_checkpoint_not_pure_data")
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if transaction_id.is_empty():
		return _failure("bankruptcy_transaction_id_missing")
	var reason_code := str(request.get("reason_code", "atomic_settlement")).strip_edges()
	if reason_code.is_empty():
		reason_code = "atomic_settlement"
	if _journal.has(transaction_id):
		return _lifecycle_replay(transaction_id)
	var candidates_variant: Variant = _world_bridge.call("capture_bankruptcy_candidates")
	if not (candidates_variant is Array):
		return _failure("bankruptcy_candidates_invalid")
	var player_indices: Array = []
	for candidate_variant in candidates_variant as Array:
		if not (candidate_variant is Dictionary):
			return _failure("bankruptcy_candidate_invalid")
		var candidate: Dictionary = candidate_variant
		if bool(candidate.get("eliminated", false)):
			continue
		if int(candidate.get("exact_cash_cents", 0)) < 0:
			player_indices.append(int(candidate.get("player_index", -1)))
	player_indices.sort()
	if player_indices.is_empty():
		var empty_public := _public_receipt([], _zero_estate_counts(), "no_bankruptcy")
		_journal[transaction_id] = {
			"state": "finalized",
			"reason_code": "no_bankruptcy",
			"player_indices": [],
			"estate_counts": _zero_estate_counts(),
			"public_receipt": empty_public,
		}
		_last_public_receipt = empty_public.duplicate(true)
		return {
			"prepared": true,
			"committed": true,
			"finalized": true,
			"terminal": true,
			"duplicate": false,
			"reason_code": "no_bankruptcy",
			"public_receipt": empty_public,
		}
	var lifecycle_request := {
		"transaction_id": transaction_id,
		"player_indices": player_indices.duplicate(),
		"reason_code": reason_code,
		"occurred_at": maxf(0.0, float(request.get("occurred_at", 0.0))),
	}
	var prepare_variant: Variant = _world_bridge.call("bankruptcy_estate_stage", "prepare", lifecycle_request)
	var prepare_result: Dictionary = (prepare_variant as Dictionary).duplicate(true) if prepare_variant is Dictionary else {}
	if not bool(prepare_result.get("prepared", false)):
		return _failure(str(prepare_result.get("reason_code", "bankruptcy_participant_prepare_failed")))
	var counts := _estate_counts(prepare_result.get("estate_counts", {}))
	var token := _lifecycle_token(transaction_id, player_indices, reason_code)
	_journal[transaction_id] = {
		"state": "prepared",
		"reason_code": reason_code,
		"player_indices": player_indices.duplicate(),
		"estate_counts": counts.duplicate(true),
		"lifecycle_token": token,
		"occurred_at": float(lifecycle_request.get("occurred_at", 0.0)),
	}
	return {
		"prepared": true,
		"committed": false,
		"finalized": false,
		"terminal": false,
		"duplicate": false,
		"reason_code": "bankruptcy_estate_prepared",
		"transaction_id": transaction_id,
		"lifecycle_token": token,
	}


func commit_checkpoint(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", "")).strip_edges()
	var record: Dictionary = _journal.get(transaction_id, {}) if _journal.get(transaction_id, {}) is Dictionary else {}
	if record.is_empty():
		return _failure("bankruptcy_transaction_missing")
	if str(record.get("state", "")) in ["committed", "finalized"]:
		return _lifecycle_replay(transaction_id)
	if str(record.get("state", "")) != "prepared" or str(prepared.get("lifecycle_token", "")) != str(record.get("lifecycle_token", "")):
		return _failure("bankruptcy_prepared_token_invalid")
	var lifecycle_request := _record_request(transaction_id, record)
	var commit_variant: Variant = _world_bridge.call("bankruptcy_estate_stage", "commit", lifecycle_request)
	var commit_result: Dictionary = (commit_variant as Dictionary).duplicate(true) if commit_variant is Dictionary else {}
	if not bool(commit_result.get("committed", false)):
		_world_bridge.call("bankruptcy_estate_stage", "rollback", lifecycle_request)
		record["state"] = "rolled_back"
		record["reason_code"] = str(commit_result.get("reason_code", "bankruptcy_participant_commit_failed"))
		_journal[transaction_id] = record
		return _failure(str(record.get("reason_code", "bankruptcy_participant_commit_failed")))
	record["state"] = "committed"
	record["estate_counts"] = _estate_counts(commit_result.get("estate_counts", record.get("estate_counts", {})))
	_journal[transaction_id] = record
	return {
		"prepared": true,
		"committed": true,
		"finalized": false,
		"terminal": false,
		"duplicate": false,
		"reason_code": "bankruptcy_estate_committed",
		"transaction_id": transaction_id,
		"lifecycle_token": str(record.get("lifecycle_token", "")),
	}


func rollback_checkpoint(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	var record: Dictionary = _journal.get(transaction_id, {}) if _journal.get(transaction_id, {}) is Dictionary else {}
	if record.is_empty():
		return _failure("bankruptcy_transaction_missing")
	if str(record.get("state", "")) == "rolled_back":
		return {"rolled_back": true, "duplicate": true, "reason_code": "bankruptcy_estate_rollback_replay"}
	if str(record.get("state", "")) == "finalized":
		return _failure("bankruptcy_estate_already_finalized")
	var rollback_variant: Variant = _world_bridge.call("bankruptcy_estate_stage", "rollback", _record_request(transaction_id, record))
	var rollback_result: Dictionary = (rollback_variant as Dictionary).duplicate(true) if rollback_variant is Dictionary else {}
	if not bool(rollback_result.get("rolled_back", false)):
		return _failure(str(rollback_result.get("reason_code", "bankruptcy_participant_rollback_failed")))
	record["state"] = "rolled_back"
	_journal[transaction_id] = record
	return {"rolled_back": true, "duplicate": false, "reason_code": "bankruptcy_estate_rolled_back"}


func finalize_checkpoint(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	var record: Dictionary = _journal.get(transaction_id, {}) if _journal.get(transaction_id, {}) is Dictionary else {}
	if record.is_empty():
		return _failure("bankruptcy_transaction_missing")
	if str(record.get("state", "")) == "finalized":
		return _lifecycle_replay(transaction_id)
	if str(record.get("state", "")) != "committed" or str(receipt.get("lifecycle_token", "")) != str(record.get("lifecycle_token", "")):
		return _failure("bankruptcy_commit_receipt_invalid")
	var lifecycle_request := _record_request(transaction_id, record)
	var finalize_variant: Variant = _world_bridge.call("bankruptcy_estate_stage", "finalize", lifecycle_request)
	var finalize_result: Dictionary = (finalize_variant as Dictionary).duplicate(true) if finalize_variant is Dictionary else {}
	if not bool(finalize_result.get("finalized", false)):
		return _failure(str(finalize_result.get("reason_code", "bankruptcy_participant_finalize_failed")))
	var public_receipt := _public_receipt(
		record.get("player_indices", []),
		_estate_counts(finalize_result.get("estate_counts", record.get("estate_counts", {}))),
		str(record.get("reason_code", "atomic_settlement"))
	)
	record["state"] = "finalized"
	record["public_receipt"] = public_receipt.duplicate(true)
	_journal[transaction_id] = record
	_last_public_receipt = public_receipt.duplicate(true)
	var active_variant: Variant = _world_bridge.call("active_player_indices") if _world_bridge.has_method("active_player_indices") else []
	var active_players: Array = (active_variant as Array).duplicate() if active_variant is Array else []
	if active_players.size() == 1 and _last_survivor_transaction_id.is_empty() and _world_bridge.has_method("request_last_survivor_victory"):
		var victory_variant: Variant = _world_bridge.call("request_last_survivor_victory")
		var victory_result: Dictionary = (victory_variant as Dictionary).duplicate(true) if victory_variant is Dictionary else {}
		if bool(victory_result.get("requested", false)):
			_last_survivor_transaction_id = transaction_id
	return {
		"prepared": true,
		"committed": true,
		"finalized": true,
		"terminal": true,
		"duplicate": false,
		"reason_code": "bankruptcy_estate_finalized",
		"public_receipt": public_receipt,
	}


func credit_neutral_estate_rent(batch_id: String, rent_rows: Array) -> Dictionary:
	if not _configured or _world_bridge == null or not _world_bridge.has_method("credit_public_wager_pool"):
		return {"credited": false, "reason_code": "neutral_rent_sink_unavailable"}
	var normalized_batch := batch_id.strip_edges()
	if normalized_batch.is_empty():
		return {"credited": false, "reason_code": "neutral_rent_batch_id_missing"}
	var pending_ids: Array[String] = []
	var amount := 0
	for row_variant in rent_rows:
		if not (row_variant is Dictionary):
			return {"credited": false, "reason_code": "neutral_rent_row_invalid"}
		var row: Dictionary = row_variant
		var receipt_id := str(row.get("receipt_id", "")).strip_edges()
		var row_amount := int(row.get("amount", -1))
		if receipt_id.is_empty() or row_amount < 0:
			return {"credited": false, "reason_code": "neutral_rent_row_invalid"}
		if _neutral_rent_journal.has(receipt_id):
			continue
		pending_ids.append(receipt_id)
		amount += row_amount
	if pending_ids.is_empty():
		return {"credited": true, "duplicate": true, "credited_amount": 0, "reason_code": "neutral_rent_replay"}
	var credit_variant: Variant = _world_bridge.call("credit_public_wager_pool", amount)
	var credit_result: Dictionary = (credit_variant as Dictionary).duplicate(true) if credit_variant is Dictionary else {}
	if not bool(credit_result.get("credited", false)):
		return {"credited": false, "reason_code": str(credit_result.get("reason_code", "neutral_rent_credit_failed"))}
	for receipt_id in pending_ids:
		_neutral_rent_journal[receipt_id] = normalized_batch
	return {"credited": true, "duplicate": false, "credited_amount": amount, "reason_code": "neutral_rent_credited"}


func public_receipt() -> Dictionary:
	return _last_public_receipt.duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured and _world_bridge != null,
		"controller_authoritative": true,
		"runtime_owner": "BankruptcyNeutralEstateRuntimeController",
		"lifecycle_version": LIFECYCLE_VERSION,
		"transaction_count": _journal.size(),
		"prepared_count": _journal_state_count("prepared"),
		"committed_count": _journal_state_count("committed"),
		"rolled_back_count": _journal_state_count("rolled_back"),
		"finalized_count": _journal_state_count("finalized"),
		"neutral_rent_receipt_count": _neutral_rent_journal.size(),
		"last_survivor_requested": not _last_survivor_transaction_id.is_empty(),
		"public_receipt": public_receipt(),
	}


func _record_request(transaction_id: String, record: Dictionary) -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"player_indices": (record.get("player_indices", []) as Array).duplicate() if record.get("player_indices", []) is Array else [],
		"reason_code": str(record.get("reason_code", "atomic_settlement")),
		"occurred_at": float(record.get("occurred_at", 0.0)),
	}


func _lifecycle_replay(transaction_id: String) -> Dictionary:
	var record: Dictionary = _journal.get(transaction_id, {}) if _journal.get(transaction_id, {}) is Dictionary else {}
	var state := str(record.get("state", ""))
	if state == "finalized":
		return {
			"prepared": true,
			"committed": true,
			"finalized": true,
			"terminal": true,
			"duplicate": true,
			"reason_code": "bankruptcy_estate_replay",
			"public_receipt": (record.get("public_receipt", {}) as Dictionary).duplicate(true) if record.get("public_receipt", {}) is Dictionary else {},
		}
	return {
		"prepared": state in ["prepared", "committed"],
		"committed": state == "committed",
		"finalized": false,
		"terminal": state == "rolled_back",
		"duplicate": true,
		"reason_code": "bankruptcy_estate_%s_replay" % state,
		"transaction_id": transaction_id,
		"lifecycle_token": str(record.get("lifecycle_token", "")),
	}


func _public_receipt(player_indices_variant: Variant, counts: Dictionary, reason_code: String) -> Dictionary:
	var player_indices: Array = (player_indices_variant as Array).duplicate() if player_indices_variant is Array else []
	player_indices.sort()
	return {
		"player_indices": player_indices,
		"estate_counts": _estate_counts(counts),
		"reason": reason_code,
	}


func _estate_counts(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	var result := _zero_estate_counts()
	for key in ESTATE_COUNT_KEYS:
		result[key] = maxi(0, int(source.get(key, 0)))
	return result


func _zero_estate_counts() -> Dictionary:
	var result: Dictionary = {}
	for key in ESTATE_COUNT_KEYS:
		result[key] = 0
	return result


func _lifecycle_token(transaction_id: String, player_indices: Array, reason_code: String) -> String:
	return JSON.stringify({"transaction_id": transaction_id, "player_indices": player_indices, "reason_code": reason_code}).sha256_text()


func _journal_state_count(state: String) -> int:
	var count := 0
	for record_variant in _journal.values():
		if record_variant is Dictionary and str((record_variant as Dictionary).get("state", "")) == state:
			count += 1
	return count


func _failure(reason_code: String) -> Dictionary:
	return {
		"prepared": false,
		"committed": false,
		"finalized": false,
		"terminal": true,
		"duplicate": false,
		"reason_code": reason_code,
	}


func _is_pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for entry in value as Array:
				if not _is_pure_data(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key in (value as Dictionary).keys():
				if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
					return false
			return true
	return false
