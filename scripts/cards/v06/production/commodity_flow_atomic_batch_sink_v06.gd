extends RefCounted
class_name CommodityFlowAtomicBatchSinkV06

const RULESET_ID := "v0.6"

var _commodity_flow_owner: Object


func configure(commodity_flow_owner: Object) -> Dictionary:
	_commodity_flow_owner = commodity_flow_owner
	var configured := (
		_commodity_flow_owner != null
		and _commodity_flow_owner.has_method("prepare_card_effect_batch")
		and _commodity_flow_owner.has_method("commit_card_effect_batch")
		and _commodity_flow_owner.has_method("rollback_card_effect_batch")
	)
	if not configured:
		_commodity_flow_owner = null
	return {
		"configured": configured,
		"reason_code": "configured" if configured else "commodity_flow_batch_api_missing",
	}


func prepare_batch(plan: Dictionary) -> Dictionary:
	if _commodity_flow_owner == null:
		return _failure(plan, "commodity_flow_owner_unavailable", "prepare")
	var result: Variant = _commodity_flow_owner.call("prepare_card_effect_batch", plan.duplicate(true))
	if not (result is Dictionary):
		return _failure(plan, "commodity_flow_prepare_receipt_invalid", "prepare")
	return (result as Dictionary).duplicate(true)


func commit_batch(prepared: Dictionary) -> Dictionary:
	if _commodity_flow_owner == null:
		return _failure(prepared, "commodity_flow_owner_unavailable", "commit")
	var result: Variant = _commodity_flow_owner.call("commit_card_effect_batch", prepared.duplicate(true))
	if not (result is Dictionary):
		return _failure(prepared, "commodity_flow_commit_receipt_invalid", "commit")
	return (result as Dictionary).duplicate(true)


func rollback_batch(receipt: Dictionary) -> Dictionary:
	if _commodity_flow_owner == null:
		return {
			"rolled_back": false,
			"committed": false,
			"transaction_id": str(receipt.get("transaction_id", "")),
			"reason_code": "commodity_flow_owner_unavailable",
		}
	var result: Variant = _commodity_flow_owner.call("rollback_card_effect_batch", receipt.duplicate(true))
	if not (result is Dictionary):
		return {
			"rolled_back": false,
			"committed": false,
			"transaction_id": str(receipt.get("transaction_id", "")),
			"reason_code": "commodity_flow_rollback_receipt_invalid",
		}
	return (result as Dictionary).duplicate(true)


func debug_snapshot() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"runtime_owner": "CommodityFlowRuntimeController",
		"adapter_role": "atomic_one_time_supply_demand_batch_sink",
		"configured": _commodity_flow_owner != null,
		"owns_commodity_state": false,
		"owns_sale_receipts": false,
		"owns_cash_gdp_rent_or_assets": false,
		"rollback_boundary": "pending_before_real_flow_tick_only",
	}


func _failure(source: Dictionary, reason_code: String, stage: String) -> Dictionary:
	return {
		"transaction_id": str(source.get("transaction_id", "")),
		"intent_hash": str(source.get("intent_hash", "")),
		"plan_hash": str(source.get("plan_hash", "")),
		"prepared": false,
		"committed": false,
		"rolled_back": false,
		"stage": stage,
		"reason_code": reason_code,
	}
