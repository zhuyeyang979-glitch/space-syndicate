@tool
extends Node
class_name CardEconomyProductRouteEffectRuntimeService

const SERVICE_ID := "card_economy_product_route_effect_runtime_v1"
const HANDLER_FAMILIES := {
	"city_gdp_derivative": "economy",
	"market_stabilize": "product",
	"news_event": "economy",
	"product_speculation": "product",
	"product_futures": "product",
	"product_contract_boon": "product",
	"product_growth_boon": "product",
}

var _configured := false
var _ruleset_id := ""
var _planned_count := 0
var _finalized_count := 0
var _rejected_count := 0


func configure(config: Dictionary = {}) -> void:
	_ruleset_id = str(config.get("ruleset_id", "v0.4"))
	_configured = _ruleset_id == "v0.4"


func reset_state() -> void:
	_planned_count = 0
	_finalized_count = 0
	_rejected_count = 0


func capture_runtime_checkpoint() -> Dictionary:
	return {"schema_version": 1, "planned_count": _planned_count, "finalized_count": _finalized_count, "rejected_count": _rejected_count}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1:
		return {"restored": false, "reason_code": "card_economy_effect_checkpoint_invalid"}
	_planned_count = int(checkpoint.get("planned_count", 0))
	_finalized_count = int(checkpoint.get("finalized_count", 0))
	_rejected_count = int(checkpoint.get("rejected_count", 0))
	return {"restored": true, "reason_code": "card_economy_effect_checkpoint_restored"}


func supports_handler(handler_id: String) -> bool:
	return HANDLER_FAMILIES.has(handler_id)


func family_for_handler(handler_id: String) -> String:
	return str(HANDLER_FAMILIES.get(handler_id, ""))


func supported_handlers() -> Array:
	var handlers: Array = HANDLER_FAMILIES.keys()
	handlers.sort()
	return handlers


func plan_effect(request: Dictionary) -> Dictionary:
	if not _is_data_only(request):
		return _rejection("request_not_data_only")
	var handler_id := str(request.get("handler_id", ""))
	if not supports_handler(handler_id):
		return {
			"status": "unsupported",
			"ready": false,
			"supported": false,
			"reason": "handler_not_owned",
			"handler_id": handler_id,
		}
	var entry := _dictionary(request.get("active_entry", {}))
	var skill := _dictionary(request.get("skill", {}))
	var player_index := int(entry.get("player_index", request.get("player_index", -1)))
	if not _configured:
		return _rejection("service_not_configured", handler_id)
	if entry.is_empty() or skill.is_empty() or player_index < 0:
		return _rejection("effect_context_missing", handler_id)
	var skill_kind := str(skill.get("kind", ""))
	if skill_kind != handler_id:
		return _rejection("handler_skill_mismatch", handler_id)
	_planned_count += 1
	return {
		"status": "ready",
		"ready": true,
		"supported": true,
		"service_id": SERVICE_ID,
		"handler_id": handler_id,
		"family_id": family_for_handler(handler_id),
		"operation_id": handler_id,
		"resolution_id": int(entry.get("resolution_id", entry.get("queued_order", -1))),
		"continuation_kind": "normal",
		"effect_payload": {
			"player_index": player_index,
			"active_entry": entry,
			"skill": skill,
		},
	}


func finalize_effect(plan: Dictionary, receipt: Dictionary) -> Dictionary:
	if not _is_data_only(plan) or not _is_data_only(receipt):
		return _finalize_rejection("effect_result_not_data_only")
	if str(plan.get("status", "")) != "ready" or not bool(plan.get("supported", false)):
		return _finalize_rejection("effect_plan_not_ready")
	var handler_id := str(plan.get("handler_id", ""))
	if str(receipt.get("handler_id", handler_id)) != handler_id:
		return _finalize_rejection("effect_receipt_mismatch", handler_id)
	if not bool(receipt.get("dispatched", false)):
		return _finalize_rejection(str(receipt.get("reason", "effect_not_dispatched")), handler_id)
	var resolved := bool(receipt.get("resolved", false))
	_finalized_count += 1
	var result := {
		"intent_type": "dispatch_effect",
		"dispatched": true,
		"resolved": resolved,
		"reason": "resolved" if resolved else str(receipt.get("reason", "effect_not_resolved")),
		"handler_id": handler_id,
		"family_id": str(plan.get("family_id", family_for_handler(handler_id))),
		"continuation_kind": str(plan.get("continuation_kind", "normal")),
	}
	if receipt.get("public_receipt", {}) is Dictionary and not (receipt.get("public_receipt", {}) as Dictionary).is_empty():
		result["public_receipt"] = (receipt.get("public_receipt", {}) as Dictionary).duplicate(true)
	return result


func debug_snapshot() -> Dictionary:
	var family_counts := {"economy": 0, "product": 0, "route": 0}
	for family_variant in HANDLER_FAMILIES.values():
		var family_id := str(family_variant)
		family_counts[family_id] = int(family_counts.get(family_id, 0)) + 1
	return {
		"service_id": SERVICE_ID,
		"ruleset_id": _ruleset_id,
		"service_ready": _configured,
		"service_authoritative": _configured,
		"effect_family_dispatch_authority": true,
		"concrete_world_mutation_authority": false,
		"execution_lifecycle_authority": false,
		"queue_authority": false,
		"timing_authority": false,
		"inventory_authority": false,
		"supported_handlers": supported_handlers(),
		"family_counts": family_counts,
		"planned_count": _planned_count,
		"finalized_count": _finalized_count,
		"rejected_count": _rejected_count,
	}


func _rejection(reason: String, handler_id: String = "") -> Dictionary:
	_rejected_count += 1
	return {
		"status": "rejected",
		"ready": false,
		"supported": supports_handler(handler_id),
		"reason": reason,
		"handler_id": handler_id,
	}


func _finalize_rejection(reason: String, handler_id: String = "") -> Dictionary:
	_rejected_count += 1
	return {
		"intent_type": "dispatch_effect",
		"dispatched": false,
		"resolved": false,
		"reason": reason,
		"handler_id": handler_id,
		"continuation_kind": "normal",
	}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	return false
