extends RefCounted
class_name AnonymousInteractionRuntimeSchemaV06

const SCHEMA_VERSION := "0.6"
const BINDING_KEYS := [
	"transaction_id",
	"actor_id",
	"card_id",
	"card_instance_id",
	"effect_kind",
	"target_kind",
	"target_hash",
	"payload_hash",
	"intent_hash",
]


static func validate_intent(intent: Dictionary) -> Dictionary:
	if str(intent.get("schema_version", "")) != SCHEMA_VERSION:
		return _invalid("interaction_schema_version_invalid", "互动请求版本无效。", "刷新对局后重试。")
	for key in ["transaction_id", "actor_id", "card_id", "card_instance_id", "effect_kind", "target_kind", "target_hash", "payload_hash", "intent_hash"]:
		if str(intent.get(key, "")).strip_edges().is_empty():
			return _invalid("interaction_intent_field_missing", "互动请求不完整。", "重新选择卡牌与目标。", {"field": key})
	if int(intent.get("target_revision", -1)) < 0:
		return _invalid("interaction_target_revision_invalid", "目标状态已经失效。", "刷新目标后重试。")
	if not (intent.get("effect_payload", {}) is Dictionary):
		return _invalid("interaction_payload_invalid", "互动效果数据无效。", "重新选择卡牌。")
	if not (intent.get("target_player_ids", []) is Array):
		return _invalid("interaction_targets_invalid", "互动目标无效。", "重新选择目标玩家。")
	var domain := route_domain(intent)
	if domain.is_empty():
		return _invalid("interaction_effect_fields_unsupported", "这张牌暂时不能由互动系统处理。", "请选择其他卡牌。")
	var targets := _string_array(intent.get("target_player_ids", []))
	if domain == "direct_player":
		if targets.is_empty():
			return _invalid("interaction_target_player_missing", "请选择一名目标玩家。", "重新选择目标玩家。")
		if targets.has(str(intent.get("actor_id", ""))):
			return _invalid("interaction_self_target_forbidden", "这张互动牌不能以自己为目标。", "选择另一名玩家。")
		var payload: Dictionary = intent.get("effect_payload", {})
		if not bool(payload.get("direct_player_interaction", false)):
			return _invalid("interaction_direct_flag_missing", "该效果不是直接玩家互动。", "请选择合法互动牌。")
	if domain == "counter_response":
		var payload: Dictionary = intent.get("effect_payload", {})
		if str(intent.get("effect_kind", "")) != "card_counter" \
		or str(intent.get("target_kind", "")) != "incoming_direct_player_interaction" \
		or str(payload.get("target_scope", "")) != "direct_player_interaction" \
		or int(payload.get("response_depth", 0)) != 1:
			return _invalid("counter_scope_invalid", "相位否决只能响应直接玩家互动。", "请选择正在生效的玩家互动牌。")
	return {"valid": true, "reason_code": "intent_valid", "route_domain": domain}


static func route_domain(intent: Dictionary) -> String:
	var effect_kind := str(intent.get("effect_kind", ""))
	var target_kind := str(intent.get("target_kind", ""))
	var payload: Dictionary = intent.get("effect_payload", {}) if intent.get("effect_payload", {}) is Dictionary else {}
	if effect_kind == "card_counter" \
	and target_kind == "incoming_direct_player_interaction" \
	and str(payload.get("target_scope", "")) == "direct_player_interaction":
		return "counter_response"
	if effect_kind.begins_with("contract_") or str(payload.get("interaction_domain", "")) == "contract":
		return "contract"
	if effect_kind.begins_with("intel_") or str(payload.get("interaction_domain", "")) == "intel":
		return "intel"
	if bool(payload.get("direct_player_interaction", false)) \
	and (effect_kind.begins_with("player_") or target_kind.begins_with("opponent_")):
		return "direct_player"
	return ""


static func validate_prepared_receipt(receipt: Dictionary) -> Dictionary:
	return _validate_stage_receipt(receipt, "prepared")


static func validate_commit_receipt(receipt: Dictionary) -> Dictionary:
	return _validate_stage_receipt(receipt, "committed")


static func validate_rollback_receipt(receipt: Dictionary) -> Dictionary:
	return _validate_stage_receipt(receipt, "rolled_back")


static func validate_finalize_receipt(receipt: Dictionary) -> Dictionary:
	return _validate_stage_receipt(receipt, "finalized")


static func binding_from(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in BINDING_KEYS:
		result[key] = source.get(key, "")
	return result


static func binding_matches(expected: Dictionary, actual: Dictionary) -> bool:
	for key in BINDING_KEYS:
		if str(expected.get(key, "")) != str(actual.get(key, "")):
			return false
	return true


static func stage_receipt(source: Dictionary, stage: String, success: bool, reason_code: String, details: Dictionary = {}) -> Dictionary:
	var result := binding_from(source)
	result["schema_version"] = SCHEMA_VERSION
	result["prepared"] = stage == "prepared" and success
	result["committed"] = stage == "committed" and success
	result["rolled_back"] = stage == "rolled_back" and success
	result["finalized"] = stage == "finalized" and success
	result["reason_code"] = reason_code
	result["route_domain"] = str(source.get("route_domain", route_domain(source)))
	for key_variant in details.keys():
		result[key_variant] = details.get(key_variant)
	return result


static func failure_receipt(source: Dictionary, reason_code: String, reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	return stage_receipt(source, "failed", false, reason_code, {
		"player_feedback": {"reason": reason, "next_step": next_step},
		"developer_fields": developer_fields.duplicate(true),
	})


static func canonical_hash(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(JSON.stringify(_canonicalize(value)).to_utf8_buffer())
	return context.finish().hex_encode()


static func _validate_stage_receipt(receipt: Dictionary, success_key: String) -> Dictionary:
	if str(receipt.get("schema_version", "")) != SCHEMA_VERSION:
		return {"valid": false, "reason_code": "interaction_receipt_schema_invalid"}
	for key in BINDING_KEYS:
		if str(receipt.get(key, "")).strip_edges().is_empty():
			return {"valid": false, "reason_code": "interaction_receipt_binding_missing", "field": key}
	if not receipt.has(success_key) or not (receipt.get(success_key) is bool):
		return {"valid": false, "reason_code": "interaction_receipt_stage_invalid", "field": success_key}
	return {"valid": true, "reason_code": "receipt_valid", "stage": success_key}


static func _invalid(reason_code: String, reason: String, next_step: String, developer_fields: Dictionary = {}) -> Dictionary:
	return {
		"valid": false,
		"reason_code": reason_code,
		"player_feedback": {"reason": reason, "next_step": next_step},
		"developer_fields": developer_fields.duplicate(true),
	}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value:
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	result.sort()
	return result


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value:
			result.append(_canonicalize(item_variant))
		return result
	return value
