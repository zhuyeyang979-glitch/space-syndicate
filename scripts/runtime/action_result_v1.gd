extends RefCounted
class_name ActionResultV1

const SCHEMA_VERSION := 1
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
	if source.is_empty() or not _is_public_value(source):
		return {}
	var allowed_fields := REQUIRED_PUBLIC_FIELDS + OPTIONAL_PUBLIC_FIELDS
	for key_variant in source.keys():
		if not allowed_fields.has(str(key_variant)):
			return {}
	for field_variant in REQUIRED_PUBLIC_FIELDS:
		if not source.has(str(field_variant)):
			return {}
	for field_variant in OPTIONAL_PUBLIC_FIELDS:
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
	if not ((action_id == "card_group_ready" and action_family == "card_resolution") or (action_id == "district_card_purchase" and action_family == "card_market")):
		return {}
	if not (source.get("success") is bool):
		return {}
	var success := bool(source.get("success", false))
	if not (source.get("failure_code") is String or source.get("failure_code") is StringName):
		return {}
	var failure_code := str(source.get("failure_code", ""))
	if success == (failure_code != ""):
		return {}
	if not success and not PUBLIC_FAILURE_CODES.has(failure_code):
		return {}
	if not (source.get("status") is String or source.get("status") is StringName):
		return {}
	var status := str(source.get("status", ""))
	if status != ("committed" if success else "rejected"):
		return {}
	for field_variant in ["title", "explanation", "consequence", "suggested_action", "focus_target", "relevant_cost", "relevant_requirement"]:
		if not (source.get(str(field_variant)) is String or source.get(str(field_variant)) is StringName):
			return {}
		if str(source.get(str(field_variant), "")).strip_edges() == "":
			return {}
	var affected_variant: Variant = source.get("affected_entity_ids", [])
	if not affected_variant is Array:
		return {}
	var affected: Array = []
	for entity_variant in affected_variant as Array:
		if not (entity_variant is String or entity_variant is StringName):
			return {}
		var entity_id := str(entity_variant)
		var expected_prefix := "resolution:" if action_id == "card_group_ready" else "district:"
		var suffix := entity_id.trim_prefix(expected_prefix)
		if not entity_id.begins_with(expected_prefix) or not suffix.is_valid_int() or int(suffix) < 0:
			return {}
		affected.append(entity_id)
	var result := {}
	for field_variant in OPTIONAL_PUBLIC_FIELDS + REQUIRED_PUBLIC_FIELDS:
		var field := str(field_variant)
		if source.has(field):
			result[field] = source[field]
	result["affected_entity_ids"] = affected
	return result


static func public_field_schema() -> Array:
	return (OPTIONAL_PUBLIC_FIELDS + REQUIRED_PUBLIC_FIELDS).duplicate()


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


static func _is_public_value(value: Variant) -> bool:
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
			var key := str(key_variant).to_lower()
			for token_variant in FORBIDDEN_KEY_TOKENS:
				if key.contains(str(token_variant)) and key != "price_cash":
					return false
			if not _is_public_value(key_variant) or not _is_public_value(value[key_variant]):
				return false
		return true
	elif value is Array:
		for item_variant in value:
			if not _is_public_value(item_variant):
				return false
		return true
	elif value is Object or value is Callable:
		return false
	return false
