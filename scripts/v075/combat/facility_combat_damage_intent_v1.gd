extends RefCounted
class_name FacilityCombatDamageIntentV1

const SCHEMA_VERSION := 1
const CONTRACT_ID := "FacilityCombatDamageIntentV1"
const RULESET_ID := "v0.7.5"
const DAMAGE_KINDS := [
	"military_region_assault",
	"monster_ground_trample",
	"monster_basic_attack",
	"monster_private_skill",
]
const FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"source_effect_id",
	"target_facility_id",
	"expected_generation",
	"damage_amount",
	"damage_kind",
	"combat_receipt_id",
	"intent_fingerprint",
]
const FORBIDDEN_PRIVATE_FIELDS := [
	"warehouse_stock",
	"private_stock",
	"inventory",
	"inventory_items",
	"private_logistics",
	"logistics_plan",
	"future_production",
	"owner_assets",
]


static func build(
	source_effect_id: String,
	target_facility_id: String,
	expected_generation: int,
	damage_amount: int,
	damage_kind: String,
	combat_receipt_id: String
) -> Dictionary:
	var intent := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"source_effect_id": source_effect_id,
		"target_facility_id": target_facility_id,
		"expected_generation": expected_generation,
		"damage_amount": damage_amount,
		"damage_kind": damage_kind,
		"combat_receipt_id": combat_receipt_id,
		"intent_fingerprint": "",
	}
	intent["intent_fingerprint"] = _fingerprint_without(
		intent, "intent_fingerprint"
	)
	return intent if bool(validation_report(intent).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("facility_combat_damage_intent_not_closed_data")
		return _report(errors)
	var intent := value as Dictionary
	if not _exact_fields(intent, FIELDS):
		errors.append("facility_combat_damage_intent_fields_invalid")
		return _report(errors)
	if int(intent.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("facility_combat_damage_intent_schema_invalid")
	if str(intent.get("contract_id", "")) != CONTRACT_ID:
		errors.append("facility_combat_damage_intent_contract_invalid")
	if str(intent.get("ruleset_id", "")) != RULESET_ID:
		errors.append("facility_combat_damage_intent_ruleset_invalid")
	for field in [
		"source_effect_id",
		"target_facility_id",
		"combat_receipt_id",
	]:
		if not _stable_id(intent.get(field)):
			errors.append("facility_combat_damage_intent_%s_invalid" % field)
	if not _positive_integer(intent.get("expected_generation")):
		errors.append("facility_combat_damage_intent_generation_invalid")
	if not _positive_integer(intent.get("damage_amount")):
		errors.append("facility_combat_damage_intent_amount_invalid")
	if str(intent.get("damage_kind", "")) not in DAMAGE_KINDS:
		errors.append("facility_combat_damage_intent_kind_invalid")
	if _contains_forbidden_field(intent):
		errors.append("facility_combat_damage_intent_private_field_present")
	var fingerprint := str(intent.get("intent_fingerprint", ""))
	if not _fingerprint_valid(fingerprint) 			or fingerprint != _fingerprint_without(intent, "intent_fingerprint"):
		errors.append("facility_combat_damage_intent_fingerprint_invalid")
	return _report(errors)


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) 		if bool(validation_report(value).get("valid", false)) else {}


static func required_fields() -> Array:
	return FIELDS.duplicate()


static func _report(errors: Array[String]) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors.duplicate(),
		"reason_code": (
			"facility_combat_damage_intent_valid"
			if errors.is_empty()
			else errors[0]
		),
	}


static func _contains_forbidden_field(value: Variant) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_field(item_variant):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in FORBIDDEN_PRIVATE_FIELDS:
				return true
			if _contains_forbidden_field((value as Dictionary).get(key_variant)):
				return true
	return false


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _stable_id(value: Variant) -> bool:
	if not (value is String or value is StringName):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160 or text.strip_edges() != text:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) 			or (code >= 65 and code <= 90) 			or (code >= 97 and code <= 122) 			or code in [45, 46, 58, 95]
		if not allowed:
			return false
	return true


static func _positive_integer(value: Variant) -> bool:
	return value is int and int(value) > 0


static func _fingerprint_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _fingerprint_without(
	value: Dictionary, excluded_field: String
) -> String:
	var copy := value.duplicate(true)
	copy.erase(excluded_field)
	return _canonical(copy).sha256_text()


static func _canonical(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if bool(value) else "false"
	if value is int:
		return str(value)
	if value is float:
		return str(float(value))
	if value is String or value is StringName:
		return JSON.stringify(str(value))
	if value is Array:
		var rows: Array[String] = []
		for item_variant in value as Array:
			rows.append(_canonical(item_variant))
		return "[%s]" % ",".join(rows)
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var pairs: Array[String] = []
		for key in keys:
			pairs.append(
				"%s:%s" % [
					JSON.stringify(key),
					_canonical((value as Dictionary).get(key)),
				]
			)
		return "{%s}" % ",".join(pairs)
	return "<invalid>"


static func _closed_data(value: Variant, depth: int = 0) -> bool:
	if depth > 48:
		return false
	if value == null or value is bool or value is int 			or value is String or value is StringName:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Array:
		for item_variant in value as Array:
			if not _closed_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName):
				return false
			if not _closed_data(
				(value as Dictionary).get(key_variant), depth + 1
			):
				return false
		return true
	return false