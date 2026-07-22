extends RefCounted
class_name GlobalSupplyDemandCardEffectAdapterV06

const SUPPORT := preload("res://scripts/cards/v06/effects/card_effect_adapter_support_v06.gd")
const EFFECT_TARGETS := {
	"global_order_budget": "global_matching_goods",
	"global_supply_spawn": "global_matching_factories",
}

var _owner: Object
var _actor_player_indices: Dictionary = {}


func configure(owner: Object, actor_player_indices: Dictionary) -> Dictionary:
	_owner = owner
	_actor_player_indices = _normalized_actor_map(actor_player_indices)
	var configured := (
		_owner != null
		and _owner.has_method("candidate_snapshot_metadata")
		and _owner.has_method("preview_batch")
		and _owner.has_method("commit_batch")
		and _owner.has_method("finalize_batch")
		and not _actor_player_indices.is_empty()
	)
	return {"configured": configured, "actor_count": _actor_player_indices.size()}


func prepare_effect(intent: Dictionary) -> Dictionary:
	var error := _intent_error(intent)
	if not error.is_empty():
		return SUPPORT.failure_receipt(intent, error)
	var actor_id := str(intent.get("actor_id", ""))
	var target: Dictionary = intent.get("target_context", {}) as Dictionary
	var metadata: Dictionary = _owner.call("candidate_snapshot_metadata")
	var expected_revision := int(target.get("candidate_snapshot_revision", -1))
	if expected_revision != int(metadata.get("revision", -2)):
		return SUPPORT.failure_receipt(intent, "candidate_snapshot_revision_changed")
	var request := SUPPORT.binding_from(intent)
	request["binding"] = SUPPORT.binding_from(intent)
	request["actor_player_index"] = int(_actor_player_indices.get(actor_id, -1))
	request["effect_payload"] = (intent.get("effect_payload", {}) as Dictionary).duplicate(true)
	request["expected_candidate_snapshot_revision"] = expected_revision
	var plan_variant: Variant = _owner.call("preview_batch", request)
	if not (plan_variant is Dictionary):
		return SUPPORT.failure_receipt(intent, "supply_demand_preview_invalid")
	var plan: Dictionary = plan_variant
	if not bool(plan.get("ready", false)):
		var failure := SUPPORT.failure_receipt(intent, str(plan.get("reason_code", "supply_demand_preview_rejected")))
		failure["owner_plan"] = plan.duplicate(true)
		return failure
	return SUPPORT.prepared_receipt(intent, {
		"adapter_kind": "global_supply_demand_v06",
		"owner_plan": plan.duplicate(true),
		"prepared_token": str(plan.get("plan_hash", "")),
	})


func abort_prepared_effect(prepared: Dictionary) -> Dictionary:
	var transaction_id := str(prepared.get("transaction_id", ""))
	var prepared_token := str(prepared.get("prepared_token", ""))
	var plan: Dictionary = prepared.get("owner_plan", {}) if prepared.get("owner_plan", {}) is Dictionary else {}
	var binding: Dictionary = plan.get("binding", {}) if plan.get("binding", {}) is Dictionary else {}
	var valid := (
		bool(prepared.get("prepared", false))
		and SUPPORT.binding_is_complete(prepared)
		and not plan.is_empty()
		and SUPPORT.binding_matches(binding, prepared)
		and not prepared_token.is_empty()
		and prepared_token == str(plan.get("plan_hash", ""))
	)
	return {
		"aborted": valid,
		"reason_code": "supply_demand_preview_aborted" if valid else "supply_demand_preview_abort_binding_invalid",
		"transaction_id": transaction_id,
		"prepared_token": prepared_token,
	}


func commit_effect(prepared: Dictionary) -> Dictionary:
	if not bool(prepared.get("prepared", false)) or not SUPPORT.binding_is_complete(prepared):
		return SUPPORT.failure_receipt(prepared, "prepared_receipt_invalid", "commit")
	var plan: Dictionary = prepared.get("owner_plan", {}) if prepared.get("owner_plan", {}) is Dictionary else {}
	var binding: Dictionary = plan.get("binding", {}) if plan.get("binding", {}) is Dictionary else {}
	if plan.is_empty() or not SUPPORT.binding_matches(binding, prepared) or str(prepared.get("prepared_token", "")) != str(plan.get("plan_hash", "")):
		return SUPPORT.failure_receipt(prepared, "prepared_receipt_mismatch", "commit")
	var owner_variant: Variant = _owner.call("commit_batch", plan.duplicate(true))
	if not (owner_variant is Dictionary):
		return SUPPORT.failure_receipt(prepared, "supply_demand_owner_receipt_invalid", "commit")
	return SUPPORT.committed_receipt(prepared, owner_variant as Dictionary)


func rollback_effect(receipt: Dictionary) -> Dictionary:
	if _owner == null or not _owner.has_method("rollback_batch"):
		return {"rolled_back": false, "committed": false, "reason_code": "supply_demand_owner_unavailable"}
	var owner_receipt: Dictionary = receipt.get("owner_receipt", {}) if receipt.get("owner_receipt", {}) is Dictionary else {}
	if owner_receipt.is_empty() or not SUPPORT.binding_is_complete(receipt):
		return {"rolled_back": false, "committed": false, "reason_code": "effect_receipt_invalid"}
	return _owner.call("rollback_batch", owner_receipt.duplicate(true)) as Dictionary


func finalize_effect(receipt: Dictionary) -> Dictionary:
	if _owner == null or not _owner.has_method("finalize_batch"):
		return {"finalized": false, "committed": false, "reason_code": "supply_demand_owner_unavailable"}
	var owner_receipt: Dictionary = receipt.get("owner_receipt", {}) if receipt.get("owner_receipt", {}) is Dictionary else {}
	if owner_receipt.is_empty() or not SUPPORT.binding_is_complete(receipt):
		return {"finalized": false, "committed": false, "reason_code": "effect_receipt_invalid"}
	var result_variant: Variant = _owner.call("finalize_batch", owner_receipt.duplicate(true))
	if not (result_variant is Dictionary):
		return {"finalized": false, "committed": true, "reason_code": "supply_demand_finalize_receipt_invalid"}
	var result: Dictionary = (result_variant as Dictionary).duplicate(true)
	result["committed"] = bool(result.get("committed", true))
	return result


func _intent_error(intent: Dictionary) -> String:
	if _owner == null:
		return "supply_demand_owner_unavailable"
	if not SUPPORT.binding_is_complete(intent):
		return "effect_binding_incomplete"
	var actor_id := str(intent.get("actor_id", ""))
	if not _actor_player_indices.has(actor_id):
		return "actor_mapping_missing"
	var effect_kind := str(intent.get("effect_kind", ""))
	if not EFFECT_TARGETS.has(effect_kind):
		return "effect_kind_mismatch"
	var target: Dictionary = intent.get("target_context", {}) if intent.get("target_context", {}) is Dictionary else {}
	if not bool(target.get("valid", false)) or str(target.get("target_kind", "")) != str(EFFECT_TARGETS[effect_kind]):
		return "target_kind_mismatch"
	return ""


func _normalized_actor_map(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for actor_variant in source.keys():
		var actor_id := str(actor_variant).strip_edges()
		var player_index := int(source[actor_variant])
		if not actor_id.is_empty() and player_index >= 0:
			result[actor_id] = player_index
	return result
