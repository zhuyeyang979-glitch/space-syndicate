extends RefCounted
class_name AnonymousInteractionReceiptSanitizerV06

const ALWAYS_SECRET_KEYS := [
	"true_owner", "hidden_owner", "owner_truth", "ai_metadata", "ai_plan", "ai_private_plan",
	"private_payload", "private_reasoning", "opponent_cash", "opponent_hand", "opponent_discard",
]
const PUBLIC_SECRET_FRAGMENTS := ["hand", "discard", "private_asset", "private_cash", "owner_truth", "hidden_owner", "true_owner", "ai_"]


static func sanitize_public(receipt: Dictionary) -> Dictionary:
	return _sanitize(receipt, "public", "") as Dictionary


static func sanitize_private(receipt: Dictionary, viewer_id: String) -> Dictionary:
	var result := _sanitize(receipt, "private", viewer_id) as Dictionary
	var viewer_private: Dictionary = receipt.get("private_by_viewer", {}) if receipt.get("private_by_viewer", {}) is Dictionary else {}
	if viewer_private.has(viewer_id) and viewer_private.get(viewer_id) is Dictionary:
		result["viewer_private"] = _sanitize(viewer_private.get(viewer_id), "private", viewer_id)
	return result


static func sanitize_developer(receipt: Dictionary) -> Dictionary:
	return receipt.duplicate(true)


static func scan_public_leaks(value: Variant) -> Array[String]:
	var leaks: Array[String] = []
	_scan(value, "$", leaks)
	return leaks


static func _sanitize(value: Variant, scope: String, viewer_id: String) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lower := key.to_lower()
			if ALWAYS_SECRET_KEYS.has(lower) or lower == "private_by_viewer":
				continue
			if scope == "public" and _public_secret_key(lower):
				continue
			if scope == "private" and lower.begins_with("opponent_"):
				continue
			result[key] = _sanitize((value as Dictionary).get(key_variant), scope, viewer_id)
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value:
			result.append(_sanitize(item_variant, scope, viewer_id))
		return result
	return value


static func _public_secret_key(lower: String) -> bool:
	for fragment in PUBLIC_SECRET_FRAGMENTS:
		if lower.contains(fragment):
			return true
	return lower in ["cash", "assets", "inventory", "cards", "private", "developer_fields"]


static func _scan(value: Variant, path: String, leaks: Array[String]) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if ALWAYS_SECRET_KEYS.has(key.to_lower()) or _public_secret_key(key.to_lower()):
				leaks.append("%s.%s" % [path, key])
			_scan((value as Dictionary).get(key_variant), "%s.%s" % [path, key], leaks)
	elif value is Array:
		for index in range((value as Array).size()):
			_scan((value as Array)[index], "%s[%d]" % [path, index], leaks)
