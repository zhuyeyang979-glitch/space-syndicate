extends RefCounted
class_name AnonymousInteractionOwnerForwardingPortV06

const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")
const REQUIRED_METHODS := {
	"snapshot": "anonymous_interaction_snapshot_v06",
	"prepare": "prepare_anonymous_interaction_v06",
	"commit": "commit_anonymous_interaction_v06",
	"rollback": "rollback_anonymous_interaction_v06",
	"finalize": "finalize_anonymous_interaction_v06",
	"checkpoint": "anonymous_interaction_checkpoint_status_v06",
}

var _owner: Object
var _domain := ""


func configure(owner: Object, domain: String) -> Dictionary:
	_owner = owner
	_domain = domain.strip_edges()
	return {"configured": not _domain.is_empty(), "domain": _domain, "capability_matrix": capability_matrix()}


func capability_matrix() -> Dictionary:
	var declared: Dictionary = {}
	if _owner != null and _owner.has_method("anonymous_interaction_runtime_capabilities_v06"):
		var value_variant: Variant = _owner.call("anonymous_interaction_runtime_capabilities_v06", _domain)
		if value_variant is Dictionary:
			declared = (value_variant as Dictionary).duplicate(true)
	var result := {"domain": _domain}
	for key_variant in REQUIRED_METHODS.keys():
		var key := str(key_variant)
		result[key] = bool(declared.get(key, false)) and _owner != null and _owner.has_method(str(REQUIRED_METHODS[key]))
	for key in ["revision", "exact_once", "save_load", "privacy_safe_snapshot", "atomic_mutation_ready"]:
		result[key] = bool(declared.get(key, false))
	result["supported_effect_kinds"] = _string_array(declared.get("supported_effect_kinds", []))
	result["production_ready"] = true
	for key in ["snapshot", "prepare", "commit", "rollback", "finalize", "checkpoint", "revision", "exact_once", "save_load", "privacy_safe_snapshot", "atomic_mutation_ready"]:
		if not bool(result.get(key, false)):
			result["production_ready"] = false
	result["reason_code"] = "owner_capabilities_ready" if bool(result["production_ready"]) else "interaction_owner_atomic_contract_missing"
	return result


func prepare_intent(intent: Dictionary) -> Dictionary:
	var validation := SCHEMA.validate_intent(intent)
	if not bool(validation.get("valid", false)):
		return _validation_failure(intent, validation)
	if str(validation.get("route_domain", "")) != _domain:
		return SCHEMA.failure_receipt(intent, "interaction_owner_domain_mismatch", "这张牌不能由当前互动 owner 处理。", "重新选择卡牌。")
	var matrix := capability_matrix()
	if not bool(matrix.get("production_ready", false)):
		return SCHEMA.failure_receipt(intent, str(matrix.get("reason_code", "interaction_owner_atomic_contract_missing")), "该互动效果正在安全接线中，当前不会消耗卡牌或资产。", "请选择其他已可用的卡牌。", {"capability_matrix": matrix})
	if not (matrix.get("supported_effect_kinds", []) as Array).has(str(intent.get("effect_kind", ""))):
		return SCHEMA.failure_receipt(intent, "interaction_owner_effect_unsupported", "当前 owner 不支持这个互动效果。", "请选择其他卡牌。")
	return _forward("prepare", intent, "prepared")


func commit_intent(prepared: Dictionary) -> Dictionary:
	return _forward("commit", prepared, "committed")


func rollback_intent(receipt: Dictionary) -> Dictionary:
	return _forward("rollback", receipt, "rolled_back")


func finalize_intent(receipt: Dictionary) -> Dictionary:
	return _forward("finalize", receipt, "finalized")


func checkpoint_status() -> Dictionary:
	var matrix := capability_matrix()
	if not bool(matrix.get("checkpoint", false)):
		return {"can_checkpoint": false, "reason_code": "interaction_owner_checkpoint_unavailable", "domain": _domain}
	var value_variant: Variant = _owner.call(str(REQUIRED_METHODS["checkpoint"]), _domain)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"can_checkpoint": false, "reason_code": "interaction_owner_checkpoint_receipt_invalid", "domain": _domain}


func safe_snapshot() -> Dictionary:
	var matrix := capability_matrix()
	if not bool(matrix.get("snapshot", false)) or not bool(matrix.get("privacy_safe_snapshot", false)):
		return {"available": false, "reason_code": "interaction_owner_privacy_snapshot_unavailable", "domain": _domain}
	var value_variant: Variant = _owner.call(str(REQUIRED_METHODS["snapshot"]), _domain)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"available": false, "reason_code": "interaction_owner_snapshot_invalid", "domain": _domain}


func _forward(stage: String, source: Dictionary, success_key: String) -> Dictionary:
	var matrix := capability_matrix()
	if not bool(matrix.get("production_ready", false)):
		return SCHEMA.failure_receipt(source, "interaction_owner_atomic_contract_missing", "互动效果无法安全完成。", "请选择其他卡牌。", {"capability_matrix": matrix})
	var value_variant: Variant = _owner.call(str(REQUIRED_METHODS[stage]), source.duplicate(true))
	if not (value_variant is Dictionary):
		return SCHEMA.failure_receipt(source, "interaction_owner_%s_receipt_invalid" % stage, "互动效果没有返回有效结果。", "刷新场景后重试。")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not SCHEMA.binding_matches(source, result):
		return SCHEMA.failure_receipt(source, "interaction_owner_%s_binding_mismatch" % stage, "互动状态已发生变化。", "刷新场景后重试。", {"owner_receipt": result})
	if not bool(result.get(success_key, false)) and str(result.get("reason_code", "")).is_empty():
		result["reason_code"] = "interaction_owner_%s_failed" % stage
	return result


func _validation_failure(intent: Dictionary, validation: Dictionary) -> Dictionary:
	var feedback: Dictionary = validation.get("player_feedback", {}) if validation.get("player_feedback", {}) is Dictionary else {}
	return SCHEMA.failure_receipt(intent, str(validation.get("reason_code", "interaction_intent_invalid")), str(feedback.get("reason", "互动请求无效。")), str(feedback.get("next_step", "重新选择卡牌与目标。")), validation.get("developer_fields", {}) as Dictionary)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value:
			result.append(str(item_variant))
	result.sort()
	return result
