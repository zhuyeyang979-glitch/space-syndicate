extends RefCounted
class_name UnitCardOwnerForwardingPortV06

const SCHEMA := preload("res://scripts/cards/v06/units/unit_card_runtime_schema_v06.gd")
const REQUIRED_MUTATION_CAPABILITIES := ["revision", "prepare", "commit", "rollback", "finalize", "exact_once", "checkpoint_gate"]
const REQUIRED_OWNER_METHODS := {
	"prepare": "prepare_unit_card_intent_v06",
	"commit": "commit_unit_card_intent_v06",
	"rollback": "rollback_unit_card_intent_v06",
	"finalize": "finalize_unit_card_intent_v06",
}

var _owner: Object
var _domain := ""


func configure(owner: Object, unit_domain: String) -> Dictionary:
	_owner = owner
	_domain = unit_domain
	if _owner == null or not ["monster", "military"].has(_domain):
		return {
			"configured": false,
			"reason_code": "unit_owner_port_configuration_invalid",
			"domain": _domain,
		}
	return {
		"configured": true,
		"domain": _domain,
		"capability_matrix": capability_matrix(),
	}


func domain() -> String:
	return _domain


func capability_matrix() -> Dictionary:
	var declared := _declared_capabilities()
	var matrix := {
		"contract_version": str(declared.get("contract_version", "")),
		"domain": _domain,
		"snapshot": _owner != null and (_owner.has_method("unit_card_snapshot_v06") or _owner.has_method("roster_snapshot") or _owner.has_method("debug_snapshot")),
		"save_load": _owner != null and ((_owner.has_method("unit_card_save_data_v06") and _owner.has_method("apply_unit_card_save_data_v06")) or (_owner.has_method("to_save_data") and _owner.has_method("apply_save_data"))),
		"revision": _declared_true(declared, "revision"),
		"prepare": _declared_true(declared, "prepare") and _has_owner_method("prepare"),
		"commit": _declared_true(declared, "commit") and _has_owner_method("commit"),
		"rollback": _declared_true(declared, "rollback") and _has_owner_method("rollback"),
		"finalize": _declared_true(declared, "finalize") and _has_owner_method("finalize"),
		"exact_once": _declared_true(declared, "exact_once"),
		"checkpoint_gate": _declared_true(declared, "checkpoint_gate") and _owner != null and _owner.has_method("unit_card_checkpoint_status_v06"),
		"privacy_safe_snapshot": _declared_true(declared, "privacy_safe_snapshot"),
		"supported_effect_kinds": _string_array(declared.get("supported_effect_kinds", [])),
		"supported_action_kinds": _string_array(declared.get("supported_action_kinds", [])),
	}
	var missing: Array[String] = []
	for capability in REQUIRED_MUTATION_CAPABILITIES:
		if not bool(matrix.get(capability, false)):
			missing.append(capability)
	matrix["missing_mutation_capabilities"] = missing
	matrix["atomic_mutation_ready"] = (
		str(matrix.get("contract_version", "")) == SCHEMA.CONTRACT_VERSION
		and missing.is_empty()
	)
	if not bool(matrix.get("atomic_mutation_ready", false)):
		matrix["capability_reason"] = "%s_owner_atomic_contract_missing" % _domain
	return matrix


func prepare_intent(intent: Dictionary) -> Dictionary:
	var validation: Dictionary = SCHEMA.validate_intent(intent)
	if not bool(validation.get("valid", false)):
		return SCHEMA.failure_receipt(
			intent,
			str(validation.get("reason_code", "unit_intent_invalid")),
			str((validation.get("player_feedback", {}) as Dictionary).get("reason", "这张牌暂时不能使用。")),
			str((validation.get("player_feedback", {}) as Dictionary).get("next_step", "重新选择卡牌与目标。")),
			validation.get("developer_fields", {}) as Dictionary
		)
	if not _effect_matches_domain(str(intent.get("effect_kind", ""))):
		return SCHEMA.failure_receipt(intent, "unit_owner_domain_mismatch", "这张牌不能由当前单位执行。", "重新选择正确的单位。", {"domain": _domain})
	var matrix := capability_matrix()
	if not bool(matrix.get("atomic_mutation_ready", false)):
		return SCHEMA.failure_receipt(
			intent,
			str(matrix.get("capability_reason", "unit_owner_atomic_contract_missing")),
			"该单位效果正在安全接线中，当前不会消耗卡牌或资产。",
			"请选择其他已可用的卡牌。",
			{"capability_matrix": matrix}
		)
	if not _declared_supports(intent, matrix):
		return SCHEMA.failure_receipt(intent, "%s_owner_action_unsupported" % _domain, "当前单位不支持这个动作。", "选择该单位已解锁的动作。")
	var value_variant: Variant = _owner.call("prepare_unit_card_intent_v06", intent.duplicate(true))
	if not (value_variant is Dictionary):
		return SCHEMA.failure_receipt(intent, "%s_owner_prepare_receipt_invalid" % _domain, "单位状态未能安全预留。", "刷新场景后重试。")
	var receipt: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not bool(receipt.get("prepared", false)):
		return _normalize_failure(intent, receipt, "%s_owner_prepare_rejected" % _domain)
	if not SCHEMA.binding_matches(intent, receipt):
		return SCHEMA.failure_receipt(intent, "%s_owner_prepare_binding_mismatch" % _domain, "单位状态已发生变化。", "刷新场景后重试。", {"owner_receipt": receipt})
	return receipt


func commit_intent(prepared: Dictionary) -> Dictionary:
	return _forward_terminal_stage("commit", "commit_unit_card_intent_v06", prepared, "committed")


func rollback_intent(receipt: Dictionary) -> Dictionary:
	return _forward_terminal_stage("rollback", "rollback_unit_card_intent_v06", receipt, "rolled_back")


func finalize_intent(receipt: Dictionary) -> Dictionary:
	return _forward_terminal_stage("finalize", "finalize_unit_card_intent_v06", receipt, "finalized")


func checkpoint_status() -> Dictionary:
	var matrix := capability_matrix()
	if not bool(matrix.get("checkpoint_gate", false)):
		return {
			"can_checkpoint": false,
			"reason_code": "%s_owner_checkpoint_gate_missing" % _domain,
			"domain": _domain,
			"inflight_count": -1,
		}
	var value_variant: Variant = _owner.call("unit_card_checkpoint_status_v06", _domain)
	if not (value_variant is Dictionary):
		return {
			"can_checkpoint": false,
			"reason_code": "%s_owner_checkpoint_receipt_invalid" % _domain,
			"domain": _domain,
			"inflight_count": -1,
		}
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	result["domain"] = _domain
	return result


func safe_snapshot() -> Dictionary:
	var matrix := capability_matrix()
	if not bool(matrix.get("privacy_safe_snapshot", false)) or _owner == null or not _owner.has_method("unit_card_snapshot_v06"):
		return {
			"available": false,
			"reason_code": "%s_owner_privacy_safe_snapshot_missing" % _domain,
			"domain": _domain,
		}
	var value_variant: Variant = _owner.call("unit_card_snapshot_v06", _domain)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {"available": false, "reason_code": "%s_owner_snapshot_invalid" % _domain, "domain": _domain}


func _forward_terminal_stage(stage: String, method_name: String, source: Dictionary, success_key: String) -> Dictionary:
	var matrix := capability_matrix()
	if not bool(matrix.get(stage, false)) or _owner == null or not _owner.has_method(method_name):
		return SCHEMA.failure_receipt(source, "%s_owner_%s_unavailable" % [_domain, stage], "单位效果无法安全完成。", "请稍后重试或选择其他卡牌。", {"capability_matrix": matrix})
	var value_variant: Variant = _owner.call(method_name, source.duplicate(true))
	if not (value_variant is Dictionary):
		return SCHEMA.failure_receipt(source, "%s_owner_%s_receipt_invalid" % [_domain, stage], "单位效果没有返回有效结果。", "刷新场景后重试。")
	var result: Dictionary = (value_variant as Dictionary).duplicate(true)
	if not SCHEMA.binding_matches(source, result):
		return SCHEMA.failure_receipt(source, "%s_owner_%s_binding_mismatch" % [_domain, stage], "单位状态已发生变化。", "刷新场景后重试。", {"owner_receipt": result})
	if not bool(result.get(success_key, false)):
		result[success_key] = false
		if str(result.get("reason_code", "")).is_empty():
			result["reason_code"] = "%s_owner_%s_failed" % [_domain, stage]
	return result


func _declared_capabilities() -> Dictionary:
	if _owner == null or not _owner.has_method("unit_card_runtime_capabilities_v06"):
		return {}
	var value_variant: Variant = _owner.call("unit_card_runtime_capabilities_v06", _domain)
	return (value_variant as Dictionary).duplicate(true) if value_variant is Dictionary else {}


func _declared_true(declared: Dictionary, key: String) -> bool:
	return bool(declared.get(key, false))


func _has_owner_method(capability: String) -> bool:
	return _owner != null and _owner.has_method(str(REQUIRED_OWNER_METHODS.get(capability, "")))


func _declared_supports(intent: Dictionary, matrix: Dictionary) -> bool:
	var effects: Array = matrix.get("supported_effect_kinds", [])
	var actions: Array = matrix.get("supported_action_kinds", [])
	return effects.has(str(intent.get("effect_kind", ""))) and actions.has(str(intent.get("action_kind", "")))


func _effect_matches_domain(effect_kind: String) -> bool:
	if _domain == "monster":
		return effect_kind.begins_with("monster_") or effect_kind == "deploy_or_upgrade_monster"
	if _domain == "military":
		return effect_kind.begins_with("military_") or effect_kind == "deploy_or_upgrade_military"
	return false


func _normalize_failure(source: Dictionary, owner_receipt: Dictionary, fallback_reason: String) -> Dictionary:
	var result := SCHEMA.failure_receipt(
		source,
		str(owner_receipt.get("reason_code", fallback_reason)),
		str((owner_receipt.get("player_feedback", {}) as Dictionary).get("reason", "单位状态未能安全预留。")),
		str((owner_receipt.get("player_feedback", {}) as Dictionary).get("next_step", "刷新场景后重试。")),
		{"owner_receipt": owner_receipt.duplicate(true)}
	)
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value:
			result.append(str(item_variant))
	result.sort()
	return result
