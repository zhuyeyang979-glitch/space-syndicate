extends RefCounted
class_name ActionResultV1

const SCHEMA_VERSION := 1
const PUBLIC_SCHEMA_ID := "action_result.v1"
const REQUIRED_PUBLIC_FIELDS := [
	"success",
	"failure_code",
	"title",
	"explanation",
	"consequence",
	"suggested_action",
	"focus_target",
	"relevant_cost",
	"relevant_requirement",
	"affected_entity_ids",
]
const OPTIONAL_PUBLIC_FIELDS := [
	"schema_version",
	"action_id",
	"action_family",
	"status",
]
const PUBLIC_FIELD_TYPES := {
	"schema_version": "int",
	"action_id": "string",
	"action_family": "string",
	"status": "string",
	"success": "bool",
	"failure_code": "string",
	"title": "string",
	"explanation": "string",
	"consequence": "string",
	"suggested_action": "string",
	"focus_target": "string",
	"relevant_cost": "string",
	"relevant_requirement": "string",
	"affected_entity_ids": "array[string]",
}
const PUBLIC_TEXT_LIMITS := {
	"title": 128,
	"explanation": 512,
	"consequence": 512,
	"suggested_action": 512,
	"focus_target": 96,
	"relevant_cost": 192,
	"relevant_requirement": 512,
}
const FAILURE_DETAIL_FIELDS := [
	"explanation",
	"consequence",
	"suggested_action",
	"relevant_requirement",
]
const FAILURE_DETAIL_MIN_LENGTH := 8
const NON_SPECIFIC_FAILURE_COPY := [
	"条件不足",
	"不能使用",
	"目标无效",
	"操作失败",
	"发生错误",
	"未知错误",
	"发生未知错误",
	"请重试",
	"稍后重试",
]
const MAX_AFFECTED_ENTITY_IDS := 64
const MAX_PUBLIC_DATA_DEPTH := 16
const REQUEST_FIELDS := [
	"schema_version",
	"action_id",
	"action_family",
	"outcome_code",
	"resolution_id",
	"public_receipt",
	"failure_code",
]
const CARD_GROUP_READY_OUTCOMES := [
	"player_unavailable",
	"queued_entry_missing",
	"group_window_closed",
	"already_ready",
	"ready_rejected",
	"group_ready_committed",
]
const DISTRICT_CARD_PURCHASE_OUTCOMES := [
	"purchase_market_unavailable",
	"purchase_listing_changed",
	"purchase_source_unavailable",
	"purchase_terms_unavailable",
	"purchase_funds_unavailable",
	"purchase_inventory_unavailable",
	"purchase_conflict",
	"purchase_committed",
]
const PUBLIC_FAILURE_CODES := [
	"player_unavailable",
	"queued_entry_missing",
	"group_window_closed",
	"already_ready",
	"ready_rejected",
	"purchase_market_unavailable",
	"purchase_listing_changed",
	"purchase_source_unavailable",
	"purchase_terms_unavailable",
	"purchase_funds_unavailable",
	"purchase_inventory_unavailable",
	"purchase_conflict",
	"unsafe_source",
]
const FORBIDDEN_KEY_TOKENS := [
	"player_index",
	"selected_player",
	"cash",
	"hand",
	"discard",
	"slot",
	"owner",
	"ai_plan",
	"ai_score",
	"ai_weight",
	"weight",
	"authorization",
	"quote_id",
	"quote_fingerprint",
	"private_quote",
	"private_receipt",
	"private_message",
	"developer_message",
]
const PRIVATE_VALUE_SENTINELS := [
	"PRIVATE_SENTINEL",
	"private_sentinel",
	"hidden_owner",
	"owner_player_index",
	"city_guess",
	"ai_private",
	"ai_plan",
	"ai_weight",
	"private_cash",
	"private_hand",
	"authorization",
	"secret",
]


static func sanitize_request(source: Dictionary) -> Dictionary:
	if source.is_empty() or not _is_public_value(source):
		return {}
	for required_field in ["schema_version", "action_id", "action_family"]:
		if not source.has(required_field):
			return {}
	if not (source.get("schema_version") is int) or int(source.get("schema_version")) != SCHEMA_VERSION:
		return {}
	if not (source.get("action_id") is String or source.get("action_id") is StringName):
		return {}
	if not (source.get("action_family") is String or source.get("action_family") is StringName):
		return {}
	var action_id := str(source.get("action_id"))
	var action_family := str(source.get("action_family"))
	if action_id == "card_group_ready" and action_family == "card_resolution":
		return _sanitize_card_group_ready_request(source)
	if action_id == "district_card_purchase" and action_family == "card_market":
		return _sanitize_district_card_purchase_request(source)
	return {}


static func _sanitize_card_group_ready_request(source: Dictionary) -> Dictionary:
	for key_variant in source.keys():
		if not ["schema_version", "action_id", "action_family", "outcome_code", "resolution_id"].has(str(key_variant)):
			return {}
	if not source.has("outcome_code"):
		return {}
	if not (source.get("outcome_code") is String or source.get("outcome_code") is StringName):
		return {}
	var outcome_code := str(source.get("outcome_code"))
	if not CARD_GROUP_READY_OUTCOMES.has(outcome_code):
		return {}
	if source.has("resolution_id") and not (source.get("resolution_id") is int):
		return {}
	var resolution_id := int(source.get("resolution_id", -1))
	if resolution_id < -1:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"action_id": "card_group_ready",
		"action_family": "card_resolution",
		"outcome_code": outcome_code,
		"resolution_id": resolution_id,
	}


static func _sanitize_district_card_purchase_request(source: Dictionary) -> Dictionary:
	for key_variant in source.keys():
		if not ["schema_version", "action_id", "action_family", "public_receipt", "failure_code"].has(str(key_variant)):
			return {}
	var has_receipt := source.has("public_receipt")
	var has_failure := source.has("failure_code")
	if has_receipt == has_failure:
		return {}
	if has_receipt:
		if not (source.get("public_receipt") is Dictionary):
			return {}
		var receipt: Dictionary = source.get("public_receipt", {})
		if receipt.size() != 3 or not receipt.has("event_code") or not receipt.has("district_index") or not receipt.has("price_cash"):
			return {}
		if not (receipt.get("event_code") is String or receipt.get("event_code") is StringName) or str(receipt.get("event_code")) != "anonymous_purchase_committed":
			return {}
		if not (receipt.get("district_index") is int) or int(receipt.get("district_index")) < 0:
			return {}
		if not (receipt.get("price_cash") is int) or int(receipt.get("price_cash")) < 0:
			return {}
		return {
			"schema_version": SCHEMA_VERSION,
			"action_id": "district_card_purchase",
			"action_family": "card_market",
			"outcome_code": "purchase_committed",
			"district_index": int(receipt.get("district_index")),
			"price_cash": int(receipt.get("price_cash")),
		}
	if not (source.get("failure_code") is String or source.get("failure_code") is StringName):
		return {}
	var owner_failure_code := str(source.get("failure_code", "")).strip_edges()
	if owner_failure_code.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"action_id": "district_card_purchase",
		"action_family": "card_market",
		"outcome_code": _district_purchase_public_failure_code(owner_failure_code),
		"district_index": -1,
	}


static func sanitize_public_result(source: Dictionary) -> Dictionary:
	return presenter_snapshot(source)


static func validate_public_result(source: Dictionary) -> bool:
	return not presenter_snapshot(source).is_empty()


static func presenter_snapshot(source: Dictionary) -> Dictionary:
	if source.is_empty() or not _is_public_value(source):
		return {}
	var allowed_fields := public_field_schema()
	if source.size() != allowed_fields.size():
		return {}
	for key_variant in source.keys():
		if not allowed_fields.has(str(key_variant)):
			return {}
	for field_variant in allowed_fields:
		if not source.has(str(field_variant)):
			return {}
	if not (source.get("schema_version") is int) or int(source.get("schema_version")) != SCHEMA_VERSION:
		return {}
	if not (source.get("action_id") is String or source.get("action_id") is StringName):
		return {}
	if not (source.get("action_family") is String or source.get("action_family") is StringName):
		return {}
	var action_id := str(source.get("action_id"))
	var action_family := str(source.get("action_family"))
	if not _is_public_token(action_id, 96) or not _is_public_token(action_family, 96):
		return {}
	if not (source.get("success") is bool):
		return {}
	var success := bool(source.get("success", false))
	if not (source.get("failure_code") is String or source.get("failure_code") is StringName):
		return {}
	var failure_code := str(source.get("failure_code", ""))
	if success == (failure_code != ""):
		return {}
	if not success and not _is_public_token(failure_code, 96):
		return {}
	if not (source.get("status") is String or source.get("status") is StringName):
		return {}
	var status := str(source.get("status", ""))
	if status != ("committed" if success else "rejected"):
		return {}
	for field_variant in PUBLIC_TEXT_LIMITS.keys():
		var field := str(field_variant)
		if not _is_public_text(source.get(field), int(PUBLIC_TEXT_LIMITS.get(field, 512))):
			return {}
	if not _is_public_token(str(source.get("focus_target")), int(PUBLIC_TEXT_LIMITS.get("focus_target", 96))):
		return {}
	if not success and not _has_concrete_failure_copy(source):
		return {}
	var affected_variant: Variant = source.get("affected_entity_ids", [])
	if not affected_variant is Array:
		return {}
	if (affected_variant as Array).size() > MAX_AFFECTED_ENTITY_IDS:
		return {}
	var affected: Array = []
	var seen_entity_ids := {}
	for entity_variant in affected_variant as Array:
		if not (entity_variant is String or entity_variant is StringName):
			return {}
		var entity_id := str(entity_variant).strip_edges()
		if not _is_public_entity_id(entity_id) or seen_entity_ids.has(entity_id):
			return {}
		seen_entity_ids[entity_id] = true
		affected.append(entity_id)
	var result := {}
	for field_variant in allowed_fields:
		var field := str(field_variant)
		if PUBLIC_TEXT_LIMITS.has(field) or ["action_id", "action_family", "status", "failure_code"].has(field):
			result[field] = str(source[field]).strip_edges()
		else:
			result[field] = source[field]
	result["affected_entity_ids"] = affected
	return result


static func public_field_schema() -> Array:
	return (OPTIONAL_PUBLIC_FIELDS + REQUIRED_PUBLIC_FIELDS).duplicate()


static func public_schema_snapshot() -> Dictionary:
	var fields := public_field_schema()
	return {
		"schema_id": PUBLIC_SCHEMA_ID,
		"schema_version": SCHEMA_VERSION,
		"fields": fields.duplicate(),
		"required_fields": fields.duplicate(),
		"core_fields": REQUIRED_PUBLIC_FIELDS.duplicate(),
		"envelope_fields": OPTIONAL_PUBLIC_FIELDS.duplicate(),
		"field_types": PUBLIC_FIELD_TYPES.duplicate(true),
		"text_limits": PUBLIC_TEXT_LIMITS.duplicate(true),
		"allow_additional_fields": false,
		"failure_detail_fields": FAILURE_DETAIL_FIELDS.duplicate(),
		"failure_detail_min_length": FAILURE_DETAIL_MIN_LENGTH,
		"max_affected_entity_ids": MAX_AFFECTED_ENTITY_IDS,
	}


static func _district_purchase_public_failure_code(owner_failure_code: String) -> String:
	var normalized := owner_failure_code.strip_edges().to_lower()
	if normalized.contains("cash") or normalized.contains("fund"):
		return "purchase_funds_unavailable"
	if normalized.contains("quote") or normalized.contains("price") or normalized.contains("authorization"):
		return "purchase_terms_unavailable"
	if normalized.contains("inventory") or normalized.contains("hand_limit") or normalized.contains("incoming_card") or normalized.contains("merge"):
		return "purchase_inventory_unavailable"
	if normalized.contains("listing_changed") or normalized.contains("revision_changed") or normalized.contains("owned_by_other_listing"):
		return "purchase_listing_changed"
	if normalized.contains("source_item") or normalized.contains("listing_source"):
		return "purchase_source_unavailable"
	if normalized.contains("runtime_not_ready") or normalized.contains("catalog_unavailable") or normalized.contains("player_unavailable") or normalized.contains("player_binding_unavailable") or normalized.contains("controller_not_ready"):
		return "purchase_market_unavailable"
	return "purchase_conflict"


static func _is_public_text(value: Variant, max_length: int) -> bool:
	if not (value is String or value is StringName):
		return false
	var text := str(value).strip_edges()
	return not text.is_empty() and text.length() <= max_length


static func _is_public_token(value: String, max_length: int) -> bool:
	var token := value.strip_edges()
	if token.is_empty() or token.length() > max_length:
		return false
	for index in range(token.length()):
		if not "abcdefghijklmnopqrstuvwxyz0123456789_.:-".contains(token.substr(index, 1)):
			return false
	return true


static func _is_public_entity_id(entity_id: String) -> bool:
	if not _is_public_token(entity_id, 128) or not entity_id.contains(":"):
		return false
	var lowered := entity_id.to_lower()
	for private_token in ["cash", "hand", "owner", "ai_weight", "weight"]:
		if lowered.contains(str(private_token)):
			return false
	return _is_public_value(entity_id)


static func _has_concrete_failure_copy(source: Dictionary) -> bool:
	for field_variant in FAILURE_DETAIL_FIELDS:
		var detail := str(source.get(str(field_variant), ""))
		if _normalize_failure_copy(detail).length() < FAILURE_DETAIL_MIN_LENGTH or _is_non_specific_failure_copy(detail):
			return false
	return true


static func _is_non_specific_failure_copy(value: String) -> bool:
	var normalized := _normalize_failure_copy(value)
	var retry_suffixes := ["请重试", "重试", "请稍后重试", "稍后重试"]
	for phrase_variant in NON_SPECIFIC_FAILURE_COPY:
		var phrase := _normalize_failure_copy(str(phrase_variant))
		if normalized == phrase:
			return true
		for suffix_variant in retry_suffixes:
			if normalized == phrase + str(suffix_variant):
				return true
	return false


static func _normalize_failure_copy(value: String) -> String:
	var normalized := value.strip_edges().to_lower()
	for character in [" ", "\t", "\r", "\n", "。", ".", "！", "!", "？", "?", "，", ",", "；", ";", "：", ":", "、"]:
		normalized = normalized.replace(str(character), "")
	return normalized


static func _is_public_value(value: Variant) -> bool:
	return _is_public_value_at_depth(value, 0)


static func _is_public_value_at_depth(value: Variant, depth: int) -> bool:
	if depth > MAX_PUBLIC_DATA_DEPTH:
		return false
	if value == null or value is bool or value is int or value is float:
		return true
	if value is String or value is StringName:
		var text := str(value)
		for sentinel_variant in PRIVATE_VALUE_SENTINELS:
			if text.findn(str(sentinel_variant)) >= 0:
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not (key_variant is String or key_variant is StringName):
				return false
			var key := str(key_variant).to_lower()
			for token_variant in FORBIDDEN_KEY_TOKENS:
				if key.contains(str(token_variant)) and key != "price_cash":
					return false
			if not _is_public_value_at_depth(key_variant, depth + 1) or not _is_public_value_at_depth(value[key_variant], depth + 1):
				return false
		return true
	elif value is Array:
		for item_variant in value:
			if not _is_public_value_at_depth(item_variant, depth + 1):
				return false
		return true
	elif value is Object or value is Callable:
		return false
	return false
