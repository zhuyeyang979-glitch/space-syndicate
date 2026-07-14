extends RefCounted
class_name CardEffectAdapterSupportV06

const BINDING_KEYS := [
	"transaction_id",
	"actor_id",
	"card_id",
	"card_instance_id",
	"effect_kind",
	"target_hash",
	"payload_hash",
	"intent_hash",
]


static func binding_from(source: Dictionary) -> Dictionary:
	var binding: Dictionary = {}
	for key in BINDING_KEYS:
		binding[key] = str(source.get(key, ""))
	return binding


static func binding_is_complete(source: Dictionary) -> bool:
	for key in BINDING_KEYS:
		if str(source.get(key, "")).strip_edges().is_empty():
			return false
	return true


static func binding_matches(first: Dictionary, second: Dictionary) -> bool:
	for key in BINDING_KEYS:
		if str(first.get(key, "")) != str(second.get(key, "")):
			return false
	return true


static func prepared_receipt(intent: Dictionary, details: Dictionary = {}) -> Dictionary:
	var receipt := binding_from(intent)
	receipt["prepared"] = true
	receipt["committed"] = false
	receipt["reason_code"] = "prepared"
	for key_variant in details.keys():
		receipt[key_variant] = details[key_variant]
	return receipt


static func failure_receipt(source: Dictionary, reason_code: String, stage := "prepare") -> Dictionary:
	var receipt := binding_from(source)
	receipt["prepared"] = false
	receipt["committed"] = false
	receipt["reason_code"] = reason_code
	receipt["failure_stage"] = stage
	return receipt


static func committed_receipt(prepared: Dictionary, owner_receipt: Dictionary) -> Dictionary:
	var receipt := binding_from(prepared)
	var committed := bool(owner_receipt.get("committed", false))
	receipt["prepared"] = true
	receipt["committed"] = committed
	receipt["reason_code"] = "committed" if committed else str(owner_receipt.get("reason", "effect_owner_rejected"))
	receipt["owner_receipt"] = owner_receipt.duplicate(true)
	return receipt


static func fingerprint(value: Variant) -> String:
	return str(hash(JSON.stringify(_canonicalize(value))))


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
