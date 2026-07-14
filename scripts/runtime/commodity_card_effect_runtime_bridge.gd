@tool
extends Node
class_name CommodityCardEffectRuntimeBridge

const ADAPTER_SCRIPT := preload("res://scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd")

var _delegate: Object
var _flow_controller: Node
var _infrastructure_controller: Node
var _actor_player_indices: Dictionary = {}
var _rollback_count := 0
var _last_rollback_reason := ""


func configure(
	flow_controller: Node,
	infrastructure_controller: Node,
	actor_player_indices: Dictionary
) -> Dictionary:
	_flow_controller = flow_controller
	_infrastructure_controller = infrastructure_controller
	_actor_player_indices = actor_player_indices.duplicate(true)
	_delegate = ADAPTER_SCRIPT.new()
	var result_variant: Variant = _delegate.call(
		"configure",
		_flow_controller,
		_infrastructure_controller,
		_actor_player_indices
	)
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {
		"configured": false,
		"actor_count": 0,
	}


func prepare_effect(intent: Dictionary) -> Dictionary:
	if _delegate == null or not _delegate.has_method("prepare_effect"):
		return _failure(intent, "commodity_effect_delegate_unavailable")
	var result_variant: Variant = _delegate.call("prepare_effect", intent.duplicate(true))
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else _failure(intent, "commodity_effect_prepare_invalid")


func commit_effect(prepared: Dictionary) -> Dictionary:
	if _delegate == null or not _delegate.has_method("commit_effect"):
		return _failure(prepared, "commodity_effect_delegate_unavailable")
	var result_variant: Variant = _delegate.call("commit_effect", prepared.duplicate(true))
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else _failure(prepared, "commodity_effect_commit_invalid")


func abort_prepared_effect(prepared: Dictionary) -> void:
	if _delegate != null and _delegate.has_method("abort_prepared_effect"):
		_delegate.call("abort_prepared_effect", prepared.duplicate(true))


func rollback_effect(receipt: Dictionary) -> Dictionary:
	_rollback_count += 1
	if _flow_controller == null or not _flow_controller.has_method("rollback_commodity_installation"):
		_last_rollback_reason = "commodity_installation_rollback_unavailable"
		return {"rolled_back": false, "reason": _last_rollback_reason}
	var transaction_id := str(receipt.get("transaction_id", "")).strip_edges()
	var result_variant: Variant = _flow_controller.call("rollback_commodity_installation", transaction_id)
	var result: Dictionary = (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {
		"rolled_back": false,
		"reason": "commodity_installation_rollback_invalid",
	}
	_last_rollback_reason = str(result.get("reason", ""))
	return result


func finalize_effect(receipt: Dictionary) -> Dictionary:
	if _flow_controller == null or not _flow_controller.has_method("finalize_commodity_installation"):
		return {"finalized": false, "reason_code": "commodity_installation_finalize_unavailable"}
	var owner_receipt: Dictionary = receipt.get("owner_receipt", {}) if receipt.get("owner_receipt", {}) is Dictionary else {}
	if owner_receipt.is_empty():
		return {"finalized": false, "reason_code": "commodity_installation_receipt_missing"}
	var result_variant: Variant = _flow_controller.call("finalize_commodity_installation", owner_receipt.duplicate(true))
	return (result_variant as Dictionary).duplicate(true) if result_variant is Dictionary else {
		"finalized": false,
		"reason_code": "commodity_installation_finalize_invalid",
	}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": _delegate != null and _flow_controller != null and _infrastructure_controller != null,
		"delegate_script": "res://scripts/cards/v06/effects/commodity_card_effect_adapter_v06.gd",
		"actor_count": _actor_player_indices.size(),
		"rollback_count": _rollback_count,
		"last_rollback_reason": _last_rollback_reason,
	}


func _failure(source: Dictionary, reason: String) -> Dictionary:
	return {
		"prepared": false,
		"committed": false,
		"reason_code": reason,
		"transaction_id": str(source.get("transaction_id", "")),
		"actor_id": str(source.get("actor_id", "")),
		"card_id": str(source.get("card_id", "")),
		"card_instance_id": str(source.get("card_instance_id", "")),
		"effect_kind": str(source.get("effect_kind", "")),
		"target_hash": str(source.get("target_hash", "")),
		"payload_hash": str(source.get("payload_hash", "")),
		"intent_hash": str(source.get("intent_hash", "")),
	}
