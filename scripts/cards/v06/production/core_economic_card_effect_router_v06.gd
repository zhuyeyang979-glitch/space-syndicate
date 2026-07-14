extends RefCounted
class_name CoreEconomicCardEffectRouterV06

const SUPPORTED_EFFECT_KINDS := [
	"install_commodity_rate",
	"build_upgrade_or_repair_facility",
	"global_order_budget",
	"global_supply_spawn",
	"install_organization_upgrade",
]

var _handlers_by_effect_kind: Dictionary = {}
var _prepared_effect_kind_by_transaction: Dictionary = {}
var _finalization_results_by_transaction: Dictionary = {}


func configure(handlers_by_effect_kind: Dictionary) -> Dictionary:
	_handlers_by_effect_kind.clear()
	_prepared_effect_kind_by_transaction.clear()
	_finalization_results_by_transaction.clear()
	for effect_kind in SUPPORTED_EFFECT_KINDS:
		var handler_variant: Variant = handlers_by_effect_kind.get(effect_kind)
		if handler_variant is Object:
			var handler := handler_variant as Object
			if handler.has_method("prepare_effect") and handler.has_method("commit_effect"):
				_handlers_by_effect_kind[effect_kind] = handler
	return {
		"configured": not _handlers_by_effect_kind.is_empty(),
		"supported_effect_kinds": _handlers_by_effect_kind.keys(),
	}


func prepare_effect(intent: Dictionary) -> Dictionary:
	var effect_kind := str(intent.get("effect_kind", ""))
	var handler := _handler(effect_kind)
	if handler == null:
		return _failure(intent, "effect_owner_unavailable")
	var value_variant: Variant = handler.call("prepare_effect", intent.duplicate(true))
	if not (value_variant is Dictionary):
		return _failure(intent, "effect_prepare_failed")
	var prepared := (value_variant as Dictionary).duplicate(true)
	if bool(prepared.get("prepared", false)):
		var transaction_id := str(prepared.get("transaction_id", intent.get("transaction_id", "")))
		if not transaction_id.is_empty():
			_prepared_effect_kind_by_transaction[transaction_id] = effect_kind
	return prepared


func commit_effect(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _prepared_effect_kind_by_transaction.has(transaction_id):
		return _failure(prepared, "effect_owner_unavailable")
	var effect_kind := str(_prepared_effect_kind_by_transaction.get(transaction_id, ""))
	var reported_effect_kind := str(prepared.get("effect_kind", ""))
	if not reported_effect_kind.is_empty() and reported_effect_kind != effect_kind:
		return _failure(prepared, "effect_commit_binding_mismatch")
	var handler := _handler(effect_kind)
	if handler == null:
		return _failure(prepared, "effect_owner_unavailable")
	var value_variant: Variant = handler.call("commit_effect", prepared.duplicate(true))
	if not (value_variant is Dictionary):
		return _failure(prepared, "effect_commit_failed")
	return (value_variant as Dictionary).duplicate(true)


func abort_prepared_effect(prepared: Dictionary) -> void:
	var transaction_id := str(prepared.get("transaction_id", ""))
	if not _prepared_effect_kind_by_transaction.has(transaction_id):
		return
	var effect_kind := str(_prepared_effect_kind_by_transaction.get(transaction_id, ""))
	var reported_effect_kind := str(prepared.get("effect_kind", ""))
	if not reported_effect_kind.is_empty() and reported_effect_kind != effect_kind:
		return
	var handler := _handler(effect_kind)
	if handler != null and handler.has_method("abort_prepared_effect"):
		handler.call("abort_prepared_effect", prepared.duplicate(true))
	_prepared_effect_kind_by_transaction.erase(transaction_id)


func rollback_effect(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", ""))
	if _finalization_results_by_transaction.has(transaction_id):
		var finalized_result: Dictionary = (_finalization_results_by_transaction.get(transaction_id, {}) as Dictionary).duplicate(true)
		return {
			"rolled_back": false,
			"committed": true,
			"finalized": bool(finalized_result.get("finalized", false)),
			"reason_code": "effect_rollback_closed",
			"transaction_id": transaction_id,
			"effect_kind": str(finalized_result.get("effect_kind", receipt.get("effect_kind", ""))),
		}
	if not _prepared_effect_kind_by_transaction.has(transaction_id):
		return {
			"rolled_back": false,
			"committed": false,
			"reason_code": "effect_rollback_unavailable",
			"transaction_id": transaction_id,
		}
	var effect_kind := str(_prepared_effect_kind_by_transaction.get(transaction_id, ""))
	var receipt_effect_kind := str(receipt.get("effect_kind", ""))
	if not receipt_effect_kind.is_empty() and receipt_effect_kind != effect_kind:
		return {
			"rolled_back": false,
			"committed": true,
			"reason_code": "effect_rollback_binding_mismatch",
			"transaction_id": transaction_id,
			"effect_kind": effect_kind,
		}
	var handler := _handler(effect_kind)
	if handler == null or not handler.has_method("rollback_effect"):
		return {
			"rolled_back": false,
			"committed": false,
			"reason_code": "effect_rollback_unavailable",
			"transaction_id": transaction_id,
		}
	var value_variant: Variant = handler.call("rollback_effect", receipt.duplicate(true))
	if not (value_variant is Dictionary):
		return {
			"rolled_back": false,
			"committed": true,
			"reason_code": "effect_rollback_failed",
			"transaction_id": transaction_id,
			"effect_kind": effect_kind,
		}
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	result["transaction_id"] = transaction_id
	result["effect_kind"] = effect_kind
	if bool(result.get("rolled_back", false)):
		_prepared_effect_kind_by_transaction.erase(transaction_id)
	return result


func finalize_effect(receipt: Dictionary) -> Dictionary:
	var transaction_id := str(receipt.get("transaction_id", ""))
	if _finalization_results_by_transaction.has(transaction_id):
		var replay: Dictionary = (_finalization_results_by_transaction.get(transaction_id, {}) as Dictionary).duplicate(true)
		replay["idempotent_replay"] = true
		return replay
	if not _prepared_effect_kind_by_transaction.has(transaction_id):
		return {
			"router_finalized": false,
			"owner_finalize_supported": false,
			"finalized": false,
			"finalization_failed": true,
			"reason_code": "effect_finalize_transaction_missing",
			"transaction_id": transaction_id,
			"effect_kind": str(receipt.get("effect_kind", "")),
		}
	var effect_kind := str(_prepared_effect_kind_by_transaction.get(transaction_id, ""))
	var receipt_effect_kind := str(receipt.get("effect_kind", ""))
	if not receipt_effect_kind.is_empty() and receipt_effect_kind != effect_kind:
		return {
			"router_finalized": false,
			"owner_finalize_supported": false,
			"finalized": false,
			"finalization_failed": true,
			"reason_code": "effect_finalize_binding_mismatch",
			"transaction_id": transaction_id,
			"effect_kind": effect_kind,
		}
	var handler := _handler(effect_kind)
	var result := {
		"router_finalized": false,
		"owner_finalize_supported": false,
		"finalized": false,
		"finalization_failed": true,
		"reason_code": "effect_owner_finalize_unavailable",
		"transaction_id": transaction_id,
		"effect_kind": effect_kind,
	}
	if handler != null and handler.has_method("finalize_effect"):
		result["owner_finalize_supported"] = true
		var value_variant: Variant = handler.call("finalize_effect", receipt.duplicate(true))
		if value_variant is Dictionary:
			var owner_result: Dictionary = (value_variant as Dictionary).duplicate(true)
			var owner_finalized := bool(owner_result.get("finalized", false))
			result["finalized"] = owner_finalized
			result["finalization_failed"] = not owner_finalized
			result["reason_code"] = str(owner_result.get("reason_code", "effect_finalized" if owner_finalized else "effect_finalize_failed"))
			result["owner_result"] = owner_result
			result["router_finalized"] = owner_finalized
		else:
			result["finalization_failed"] = true
			result["reason_code"] = "effect_finalize_receipt_invalid"
	if bool(result.get("finalized", false)):
		_prepared_effect_kind_by_transaction.erase(transaction_id)
		_finalization_results_by_transaction[transaction_id] = result.duplicate(true)
	return result.duplicate(true)


func configured_effect_kinds() -> Array[String]:
	var result: Array[String] = []
	for effect_kind_variant in _handlers_by_effect_kind.keys():
		result.append(str(effect_kind_variant))
	result.sort()
	return result


func debug_snapshot() -> Dictionary:
	return {
		"configured_effect_kinds": configured_effect_kinds(),
		"pending_transaction_count": _prepared_effect_kind_by_transaction.size(),
		"finalized_transaction_count": _finalization_results_by_transaction.size(),
	}


func _handler(effect_kind: String) -> Object:
	var value: Variant = _handlers_by_effect_kind.get(effect_kind)
	return value as Object if value is Object else null


func _failure(source: Dictionary, reason_code: String) -> Dictionary:
	return {
		"prepared": false,
		"committed": false,
		"reason_code": reason_code,
		"transaction_id": str(source.get("transaction_id", "")),
		"actor_id": str(source.get("actor_id", "")),
		"card_id": str(source.get("card_id", "")),
		"card_instance_id": str(source.get("card_instance_id", "")),
		"effect_kind": str(source.get("effect_kind", "")),
		"target_hash": str(source.get("target_hash", "")),
		"payload_hash": str(source.get("payload_hash", "")),
		"intent_hash": str(source.get("intent_hash", "")),
	}
