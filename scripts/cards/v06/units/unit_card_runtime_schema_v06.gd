extends RefCounted
class_name UnitCardRuntimeSchemaV06

const CONTRACT_VERSION := "v0.6"
const BINDING_KEYS := [
	"transaction_id",
	"actor_id",
	"card_id",
	"card_instance_id",
	"effect_kind",
	"action_kind",
	"target_hash",
	"payload_hash",
	"intent_hash",
	"unit_intent_fingerprint",
]

const EFFECT_ACTIONS := {
	"deploy_or_upgrade_monster": ["deploy_or_upgrade_monster"],
	"monster_lure_once": ["monster_lure"],
	"monster_bound_action": ["monster_move", "monster_attack", "monster_guard", "monster_area_suppress"],
	"deploy_or_upgrade_military": ["deploy_or_upgrade_military"],
	"military_reusable_command": ["military_move", "military_guard", "military_attack_monster", "military_suppress_region"],
}


static func supported_effect_kinds() -> Array[String]:
	var result: Array[String] = []
	for effect_kind_variant in EFFECT_ACTIONS.keys():
		result.append(str(effect_kind_variant))
	result.sort()
	return result


static func make_intent(
	transaction_id: String,
	actor_id: String,
	card_id: String,
	card_instance_id: String,
	effect_kind: String,
	action_kind: String,
	expected_owner_revision: int,
	target_context: Dictionary,
	effect_fields: Dictionary,
	visibility_context: Dictionary = {}
) -> Dictionary:
	var target_copy := target_context.duplicate(true)
	var fields_copy := effect_fields.duplicate(true)
	var target_hash := fingerprint(target_copy)
	var payload_hash := fingerprint(fields_copy)
	var outer_identity := {
		"contract_version": CONTRACT_VERSION,
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": card_instance_id,
		"effect_kind": effect_kind,
		"target_hash": target_hash,
		"payload_hash": payload_hash,
	}
	var outer_intent_hash := fingerprint(outer_identity)
	var result := {
		"contract_version": CONTRACT_VERSION,
		"transaction_id": transaction_id,
		"actor_id": actor_id,
		"card_id": card_id,
		"card_instance_id": card_instance_id,
		"effect_kind": effect_kind,
		"action_kind": action_kind,
		"expected_owner_revision": expected_owner_revision,
		"target_context": target_copy,
		"effect_fields": fields_copy,
		"visibility_context": visibility_context.duplicate(true),
		"target_hash": target_hash,
		"payload_hash": payload_hash,
		"intent_hash": outer_intent_hash,
	}
	result["unit_intent_fingerprint"] = unit_intent_fingerprint(result)
	return result


static func normalize_card_flow_intent(raw_intent: Dictionary, expected_owner_revision: int, action_kind: String) -> Dictionary:
	var result := raw_intent.duplicate(true)
	result["contract_version"] = CONTRACT_VERSION
	result["action_kind"] = action_kind
	result["expected_owner_revision"] = expected_owner_revision
	result["effect_fields"] = (raw_intent.get("effect_payload", {}) as Dictionary).duplicate(true) if raw_intent.get("effect_payload", {}) is Dictionary else {}
	result["unit_intent_fingerprint"] = unit_intent_fingerprint(result)
	return result


static func validate_intent(intent: Dictionary) -> Dictionary:
	if str(intent.get("contract_version", "")) != CONTRACT_VERSION:
		return validation_failure("unit_contract_version_mismatch", "当前单位牌合同版本不兼容。", "刷新牌面后重试。")
	for key in BINDING_KEYS:
		if str(intent.get(key, "")).strip_edges().is_empty():
			return validation_failure("unit_intent_binding_missing", "这张牌的结算信息不完整。", "重新选择卡牌与目标。", {"missing_key": key})
	var effect_kind := str(intent.get("effect_kind", ""))
	var action_kind := str(intent.get("action_kind", ""))
	if not EFFECT_ACTIONS.has(effect_kind):
		return validation_failure("unit_effect_kind_unsupported", "该单位牌效果尚未接入。", "请选择其他卡牌。", {"effect_kind": effect_kind})
	var allowed_actions: Array = EFFECT_ACTIONS.get(effect_kind, [])
	if not allowed_actions.has(action_kind):
		return validation_failure("unit_action_kind_mismatch", "这张牌不能执行所选动作。", "重新选择合法动作。", {"effect_kind": effect_kind, "action_kind": action_kind})
	var revision_variant: Variant = intent.get("expected_owner_revision")
	if not (revision_variant is int or revision_variant is float) or int(revision_variant) < 0:
		return validation_failure("unit_owner_revision_missing", "单位状态已无法确认。", "刷新场景后重试。")
	var target_variant: Variant = intent.get("target_context")
	var fields_variant: Variant = intent.get("effect_fields")
	if not (target_variant is Dictionary) or not (fields_variant is Dictionary):
		return validation_failure("unit_intent_fields_invalid", "这张牌的目标或效果信息无效。", "重新选择卡牌与目标。")
	var target: Dictionary = target_variant
	var fields: Dictionary = fields_variant
	if target.has("valid") and not bool(target.get("valid", false)):
		return validation_failure("unit_target_invalid", "所选目标当前无效。", "请选择仍在场的合法目标。")
	if str(fields.get("effect_kind", effect_kind)) != effect_kind or str(fields.get("action_kind", action_kind)) != action_kind:
		return validation_failure("unit_effect_fields_binding_mismatch", "牌面动作与结算动作不一致。", "刷新牌面后重试。")
	if str(intent.get("target_hash", "")) != fingerprint(target):
		return validation_failure("unit_target_fingerprint_mismatch", "目标状态已发生变化。", "重新选择目标。")
	if str(intent.get("payload_hash", "")) != fingerprint(fields):
		return validation_failure("unit_payload_fingerprint_mismatch", "牌面效果已发生变化。", "刷新牌面后重试。")
	if str(intent.get("unit_intent_fingerprint", "")).is_empty():
		return validation_failure("unit_intent_fingerprint_missing", "结算请求缺少单位状态绑定。", "刷新场景后重试。")
	if str(intent.get("unit_intent_fingerprint", "")) != unit_intent_fingerprint(intent):
		return validation_failure("unit_intent_fingerprint_mismatch", "结算请求已过期。", "重新打出这张牌。")
	var semantic_result := _validate_semantics(effect_kind, action_kind, target, fields)
	if not bool(semantic_result.get("valid", false)):
		return semantic_result
	return {
		"valid": true,
		"reason_code": "unit_intent_valid",
		"effect_kind": effect_kind,
		"action_kind": action_kind,
		"binding": binding_from(intent),
	}


static func binding_from(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in BINDING_KEYS:
		result[key] = str(source.get(key, ""))
	result["expected_owner_revision"] = int(source.get("expected_owner_revision", -1))
	return result


static func binding_matches(first: Dictionary, second: Dictionary) -> bool:
	for key in BINDING_KEYS:
		if str(first.get(key, "")) != str(second.get(key, "")):
			return false
	return int(first.get("expected_owner_revision", -1)) == int(second.get("expected_owner_revision", -1))


static func failure_receipt(source: Dictionary, reason_code: String, player_reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	var receipt := binding_from(source)
	receipt.merge({
		"prepared": false,
		"committed": false,
		"rolled_back": false,
		"finalized": false,
		"reason_code": reason_code,
		"player_feedback": {
			"reason": player_reason,
			"next_step": next_step,
		},
		"developer_fields": developer_fields.duplicate(true),
	}, true)
	return receipt


static func validation_failure(reason_code: String, player_reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	return {
		"valid": false,
		"reason_code": reason_code,
		"player_feedback": {
			"reason": player_reason,
			"next_step": next_step,
		},
		"developer_fields": developer_fields.duplicate(true),
	}


static func fingerprint(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


static func unit_intent_fingerprint(intent: Dictionary) -> String:
	return fingerprint({
		"contract_version": CONTRACT_VERSION,
		"transaction_id": str(intent.get("transaction_id", "")),
		"actor_id": str(intent.get("actor_id", "")),
		"card_id": str(intent.get("card_id", "")),
		"card_instance_id": str(intent.get("card_instance_id", "")),
		"effect_kind": str(intent.get("effect_kind", "")),
		"action_kind": str(intent.get("action_kind", "")),
		"expected_owner_revision": int(intent.get("expected_owner_revision", -1)),
		"target_hash": str(intent.get("target_hash", "")),
		"payload_hash": str(intent.get("payload_hash", "")),
		"outer_intent_hash": str(intent.get("intent_hash", "")),
	})


static func _validate_semantics(effect_kind: String, action_kind: String, target: Dictionary, fields: Dictionary) -> Dictionary:
	match effect_kind:
		"deploy_or_upgrade_monster":
			if not _has_region_or_unit(target):
				return validation_failure("monster_deploy_target_missing", "请选择部署区域或自己的同族怪兽。", "选择一个合法区域或怪兽。")
			if str(fields.get("monster_family_id", "")).is_empty() or not _valid_rank(fields.get("card_rank")):
				return validation_failure("monster_profile_missing", "怪兽档案不完整。", "刷新牌面后重试。")
		"monster_lure_once":
			if not _positive_id(target, "unit_uid") or str(target.get("target_region_id", "")).is_empty():
				return validation_failure("monster_lure_target_missing", "诱导需要一只怪兽和一个区域。", "重新选择怪兽与目的区域。")
			if str(fields.get("consumption_policy", "")) != "next_autonomous_move_once":
				return validation_failure("monster_lure_policy_unsupported", "该诱导方式尚未接入。", "请选择一次性诱导牌。")
		"monster_bound_action":
			if not _positive_id(target, "unit_uid") or str(fields.get("skill_profile_id", "")).is_empty() or str(fields.get("bound_action_instance_id", "")).is_empty():
				return validation_failure("monster_bound_action_binding_missing", "固定技能未绑定到有效怪兽。", "重新选择该怪兽的固定技能。")
			var monster_target_result := _validate_action_target(action_kind, target)
			if not bool(monster_target_result.get("valid", false)):
				return monster_target_result
		"deploy_or_upgrade_military":
			if not _has_region_or_unit(target):
				return validation_failure("military_deploy_target_missing", "请选择部署区域或自己的同族军队。", "选择一个合法区域或军队。")
			if str(fields.get("military_family_id", "")).is_empty() or not _valid_rank(fields.get("card_rank")):
				return validation_failure("military_profile_missing", "军队档案不完整。", "刷新牌面后重试。")
		"military_reusable_command":
			if not _positive_id(target, "unit_uid") or str(fields.get("command_instance_id", "")).is_empty():
				return validation_failure("military_command_binding_missing", "军令未绑定到有效军队。", "重新选择该军队的军令。")
			if not bool(fields.get("persistent", false)):
				return validation_failure("military_command_not_reusable", "该军令不是可回收军令。", "请选择已绑定的可回收军令。")
			var military_target_result := _validate_action_target(action_kind, target)
			if not bool(military_target_result.get("valid", false)):
				return military_target_result
	return {"valid": true, "reason_code": "unit_semantics_valid"}


static func _validate_action_target(action_kind: String, target: Dictionary) -> Dictionary:
	match action_kind:
		"monster_move", "monster_area_suppress", "military_move", "military_guard", "military_suppress_region":
			if str(target.get("target_region_id", "")).is_empty():
				return validation_failure("unit_region_target_missing", "这个动作需要一个区域目标。", "请选择区域。")
		"monster_attack", "military_attack_monster":
			if not _positive_id(target, "target_monster_uid"):
				return validation_failure("unit_monster_target_missing", "这个动作需要一只怪兽目标。", "请选择仍在场的怪兽。")
		"monster_guard":
			pass
	return {"valid": true, "reason_code": "unit_action_target_valid"}


static func _has_region_or_unit(target: Dictionary) -> bool:
	return not str(target.get("region_id", "")).is_empty() or _positive_id(target, "unit_uid")


static func _positive_id(source: Dictionary, key: String) -> bool:
	var value: Variant = source.get(key)
	return (value is int or value is float) and int(value) > 0


static func _valid_rank(value: Variant) -> bool:
	return (value is int or value is float) and int(value) >= 1 and int(value) <= 4


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array = source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var normalized: Dictionary = {}
		for key_variant in keys:
			normalized[str(key_variant)] = _canonicalize(source[key_variant])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item_variant in value:
			normalized_array.append(_canonicalize(item_variant))
		return normalized_array
	return value
