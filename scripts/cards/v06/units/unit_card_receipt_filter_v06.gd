extends RefCounted
class_name UnitCardReceiptFilterV06

const PUBLIC_ROOT_KEYS := [
	"receipt_version",
	"public_event_id",
	"prepared",
	"committed",
	"rolled_back",
	"finalized",
	"idempotent_replay",
	"effect_kind",
	"action_kind",
	"outcome",
	"anonymous",
	"unit_public_id",
	"unit_name",
	"unit_rank",
	"target_public",
	"public_changes",
	"player_feedback",
	"owner_revealed",
	"revealed_owner_label",
]
const PRIVATE_ROOT_KEYS := [
	"card_instance_id",
	"bound_unit_uid",
	"command_instance_id",
	"asset_debit",
	"cooldown_seconds",
	"private_target",
	"own_cash_after",
	"own_hand_after",
	"own_unit_state",
]
const PUBLIC_FORBIDDEN_TOKENS := [
	"actor_id",
	"transaction_id",
	"card_instance_id",
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"private_owner",
	"owner_player_index",
	"player_index",
	"lure_owner",
	"owner_clue",
	"bound_monster_uid",
	"bound_military_uid",
	"bound_unit_uid",
	"source_slot",
	"asset_debit",
	"cash",
	"hand",
	"inventory",
	"ai_plan",
	"ai_private",
	"raw_error",
	"raw_owner_receipt",
	"owner_receipt",
	"reason_code",
	"revision",
	"fingerprint",
	"intent_hash",
	"target_hash",
	"payload_hash",
	"developer_fields",
	"private_fields",
]


static func public_view(receipt: Dictionary) -> Dictionary:
	var source := receipt.duplicate(true)
	var public_fields: Dictionary = source.get("public_fields", {}) if source.get("public_fields", {}) is Dictionary else {}
	var merged := source.duplicate(true)
	for key_variant in public_fields.keys():
		merged[str(key_variant)] = public_fields[key_variant]
	var result: Dictionary = {}
	for key in PUBLIC_ROOT_KEYS:
		if merged.has(key):
			result[key] = _sanitize_public_value(merged[key])
	result["receipt_version"] = str(result.get("receipt_version", "v0.6"))
	result["anonymous"] = true
	if not bool(result.get("owner_revealed", false)):
		result.erase("revealed_owner_label")
	return result


static func private_view(receipt: Dictionary, viewer_actor_id: String) -> Dictionary:
	var result := public_view(receipt)
	if viewer_actor_id.is_empty() or viewer_actor_id != str(receipt.get("actor_id", "")):
		return result
	var private_fields: Dictionary = receipt.get("private_fields", {}) if receipt.get("private_fields", {}) is Dictionary else {}
	var own: Dictionary = {}
	for key in PRIVATE_ROOT_KEYS:
		if private_fields.has(key):
			own[key] = _sanitize_private_value(private_fields[key])
	if not own.is_empty():
		result["private"] = own
	return result


static func developer_view(receipt: Dictionary) -> Dictionary:
	return receipt.duplicate(true)


static func public_leak_scan(public_receipt: Dictionary) -> Dictionary:
	var leaks: Array[String] = []
	_scan_forbidden(public_receipt, "$", leaks)
	return {
		"leak_count": leaks.size(),
		"leaks": leaks,
		"safe": leaks.is_empty(),
	}


static func _scan_forbidden(value: Variant, path: String, leaks: Array[String]) -> void:
	if value is Dictionary:
		var source: Dictionary = value
		for key_variant in source.keys():
			var key := str(key_variant)
			var key_lower := key.to_lower()
			if key_lower == "owner" or key_lower == "owner_id" or key_lower == "owner_index" or key_lower.contains("private"):
				leaks.append("%s.%s" % [path, key])
				_scan_forbidden(source[key_variant], "%s.%s" % [path, key], leaks)
				continue
			for forbidden in PUBLIC_FORBIDDEN_TOKENS:
				if key_lower == forbidden or key_lower.contains(forbidden):
					leaks.append("%s.%s" % [path, key])
					break
			_scan_forbidden(source[key_variant], "%s.%s" % [path, key], leaks)
	elif value is Array:
		var index := 0
		for item_variant in value:
			_scan_forbidden(item_variant, "%s[%d]" % [path, index], leaks)
			index += 1


static func _sanitize_public_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var source: Dictionary = value
		for key_variant in source.keys():
			var key := str(key_variant)
			if _public_key_forbidden(key):
				continue
			result[key] = _sanitize_public_value(source[key_variant])
		return result
	if value is Array:
		var result_array: Array = []
		for item_variant in value:
			result_array.append(_sanitize_public_value(item_variant))
		return result_array
	return value


static func _sanitize_private_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var source: Dictionary = value
		for key_variant in source.keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			if lowered.contains("opponent") or lowered.contains("rival") or lowered.contains("ai_plan") or lowered.contains("raw_error") or lowered.contains("raw_owner"):
				continue
			result[key] = _sanitize_private_value(source[key_variant])
		return result
	if value is Array:
		var result_array: Array = []
		for item_variant in value:
			result_array.append(_sanitize_private_value(item_variant))
		return result_array
	return value


static func _public_key_forbidden(key: String) -> bool:
	var lowered := key.to_lower()
	if lowered == "owner" or lowered == "owner_id" or lowered == "owner_index" or lowered.contains("private"):
		return true
	for forbidden in PUBLIC_FORBIDDEN_TOKENS:
		if lowered == forbidden or lowered.contains(forbidden):
			return true
	return false
