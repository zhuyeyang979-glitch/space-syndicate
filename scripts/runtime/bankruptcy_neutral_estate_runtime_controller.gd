@tool
extends Node
class_name BankruptcyNeutralEstateRuntimeController

const RULESET_ID := "v0.6"
const LIFECYCLE_VERSION := 1
const SAVE_STATE_VERSION := 1
const ESTATE_COUNT_KEYS := [
	"hand_cards_removed",
	"goods_removed",
	"military_units_removed",
	"monsters_orphaned",
	"facilities_neutralized",
]
const SAVE_KEYS := ["state_version", "ruleset_id", "journal", "neutral_rent_journal", "last_public_receipt", "last_survivor_transaction_id"]
const JOURNAL_RECORD_KEYS := ["state", "reason_code", "player_indices", "estate_counts", "lifecycle_token", "occurred_at", "public_receipt"]
const JOURNAL_STATES := ["prepared", "committed", "finalized", "rolled_back"]
const PUBLIC_RECEIPT_KEYS := ["player_indices", "estate_counts", "reason"]

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


func to_save_data() -> Dictionary:
	return {
		"state_version": SAVE_STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"journal": _journal.duplicate(true),
		"neutral_rent_journal": _neutral_rent_journal.duplicate(true),
		"last_public_receipt": _last_public_receipt.duplicate(true),
		"last_survivor_transaction_id": _last_survivor_transaction_id,
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var prepared := _prepare_save_data(data)
	if not bool(prepared.get("valid", false)):
		return {"applied": false, "reason": str(prepared.get("reason", "bankruptcy_save_invalid"))}
	_journal = (prepared.get("journal", {}) as Dictionary).duplicate(true)
	_neutral_rent_journal = (prepared.get("neutral_rent_journal", {}) as Dictionary).duplicate(true)
	_last_public_receipt = (prepared.get("last_public_receipt", {}) as Dictionary).duplicate(true)
	_last_survivor_transaction_id = str(prepared.get("last_survivor_transaction_id", ""))
	return {
		"applied": true,
		"reason": "",
		"state_version": SAVE_STATE_VERSION,
		"transaction_count": _journal.size(),
		"neutral_rent_receipt_count": _neutral_rent_journal.size(),
	}


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


func _prepare_save_data(data: Dictionary) -> Dictionary:
	if not _is_pure_data(data) or not _keys_allowed(data, SAVE_KEYS):
		return {"valid": false, "reason": "bankruptcy_save_not_allowlisted"}
	if int(data.get("state_version", -1)) != SAVE_STATE_VERSION or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"valid": false, "reason": "bankruptcy_save_header_invalid"}
	if not (data.get("journal", {}) is Dictionary) or not (data.get("neutral_rent_journal", {}) is Dictionary) or not (data.get("last_public_receipt", {}) is Dictionary):
		return {"valid": false, "reason": "bankruptcy_save_shape_invalid"}
	var normalized_journal := _normalized_journal(data.get("journal", {}) as Dictionary)
	if not bool(normalized_journal.get("valid", false)):
		return normalized_journal
	var normalized_rent := _normalized_rent_journal(data.get("neutral_rent_journal", {}) as Dictionary)
	if not bool(normalized_rent.get("valid", false)):
		return normalized_rent
	var normalized_public := _normalized_public_receipt(data.get("last_public_receipt", {}) as Dictionary, true)
	if not bool(normalized_public.get("valid", false)):
		return normalized_public
	var journal: Dictionary = normalized_journal.get("value", {})
	var last_survivor_id := str(data.get("last_survivor_transaction_id", "")).strip_edges()
	if not last_survivor_id.is_empty():
		var survivor_record: Dictionary = journal.get(last_survivor_id, {}) if journal.get(last_survivor_id, {}) is Dictionary else {}
		if survivor_record.is_empty() or str(survivor_record.get("state", "")) != "finalized":
			return {"valid": false, "reason": "bankruptcy_last_survivor_reference_invalid"}
	return {
		"valid": true,
		"journal": journal,
		"neutral_rent_journal": normalized_rent.get("value", {}),
		"last_public_receipt": normalized_public.get("value", {}),
		"last_survivor_transaction_id": last_survivor_id,
	}


func _normalized_journal(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var transaction_ids: Array = source.keys()
	transaction_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for transaction_id_variant in transaction_ids:
		if not (transaction_id_variant is String or transaction_id_variant is StringName):
			return {"valid": false, "reason": "bankruptcy_transaction_id_invalid"}
		var transaction_id := str(transaction_id_variant).strip_edges()
		var record_variant: Variant = source.get(transaction_id_variant)
		if transaction_id.is_empty() or not (record_variant is Dictionary):
			return {"valid": false, "reason": "bankruptcy_journal_record_invalid"}
		var record := record_variant as Dictionary
		if not _keys_allowed(record, JOURNAL_RECORD_KEYS):
			return {"valid": false, "reason": "bankruptcy_journal_record_not_allowlisted"}
		var state := str(record.get("state", ""))
		var reason_code := str(record.get("reason_code", "")).strip_edges()
		var player_indices := _normalized_player_indices(record.get("player_indices", []))
		if not JOURNAL_STATES.has(state) or reason_code.is_empty() or not bool(player_indices.get("valid", false)):
			return {"valid": false, "reason": "bankruptcy_journal_record_fields_invalid"}
		var lifecycle_token := str(record.get("lifecycle_token", ""))
		if state in ["prepared", "committed"] and lifecycle_token.is_empty():
			return {"valid": false, "reason": "bankruptcy_lifecycle_token_missing"}
		var public_receipt := _normalized_public_receipt(record.get("public_receipt", {}) as Dictionary if record.get("public_receipt", {}) is Dictionary else {}, true)
		if not bool(public_receipt.get("valid", false)):
			return public_receipt
		var normalized_record := {
			"state": state,
			"reason_code": reason_code,
			"player_indices": player_indices.get("value", []),
			"estate_counts": _estate_counts(record.get("estate_counts", {})),
			"lifecycle_token": lifecycle_token,
			"occurred_at": maxf(0.0, float(record.get("occurred_at", 0.0))),
		}
		var public_value: Dictionary = public_receipt.get("value", {})
		if not public_value.is_empty():
			normalized_record["public_receipt"] = public_value
		result[transaction_id] = normalized_record
	return {"valid": true, "value": result}


func _normalized_rent_journal(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var receipt_ids: Array = source.keys()
	receipt_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
	for receipt_id_variant in receipt_ids:
		if not (receipt_id_variant is String or receipt_id_variant is StringName):
			return {"valid": false, "reason": "bankruptcy_rent_receipt_id_invalid"}
		var receipt_id := str(receipt_id_variant).strip_edges()
		var batch_id := str(source.get(receipt_id_variant, "")).strip_edges()
		if receipt_id.is_empty() or batch_id.is_empty():
			return {"valid": false, "reason": "bankruptcy_rent_journal_invalid"}
		result[receipt_id] = batch_id
	return {"valid": true, "value": result}


func _normalized_public_receipt(source: Dictionary, allow_empty: bool) -> Dictionary:
	if source.is_empty() and allow_empty:
		return {"valid": true, "value": {}}
	if not _keys_allowed(source, PUBLIC_RECEIPT_KEYS):
		return {"valid": false, "reason": "bankruptcy_public_receipt_not_allowlisted"}
	var player_indices := _normalized_player_indices(source.get("player_indices", []))
	var reason := str(source.get("reason", "")).strip_edges()
	if not bool(player_indices.get("valid", false)) or reason.is_empty():
		return {"valid": false, "reason": "bankruptcy_public_receipt_invalid"}
	return {
		"valid": true,
		"value": {
			"player_indices": player_indices.get("value", []),
			"estate_counts": _estate_counts(source.get("estate_counts", {})),
			"reason": reason,
		},
	}


func _normalized_player_indices(value: Variant) -> Dictionary:
	if not (value is Array):
		return {"valid": false}
	var result: Array[int] = []
	for index_variant in value as Array:
		if not (index_variant is int) or int(index_variant) < 0 or result.has(int(index_variant)):
			return {"valid": false}
		result.append(int(index_variant))
	result.sort()
	return {"valid": true, "value": result}


func _keys_allowed(source: Dictionary, allowed: Array) -> bool:
	for key_variant in source.keys():
		if not (key_variant is String or key_variant is StringName) or not allowed.has(str(key_variant)):
			return false
	return true


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
