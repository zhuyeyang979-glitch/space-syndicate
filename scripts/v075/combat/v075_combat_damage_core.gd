extends RefCounted
class_name V075CombatDamageCore

const FacilityDamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)

const RULESET_ID := "v0.7.5"
const FACILITY_BATCH_CONTRACT_ID := "FacilityCombatDamageIntentBatchV1"
const MONSTER_DAMAGE_CONTRACT_ID := "MonsterCombatDamageIntentV1"
const FACILITY_ALLOCATION_FIELDS := [
	"target_facility_id",
	"expected_generation",
	"damage_amount",
]
const MONSTER_DAMAGE_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"source_effect_id",
	"target_monster_source_instance_id",
	"expected_source_generation",
	"observed_source_revision",
	"damage_amount",
	"damage_kind",
	"public_target_region_id",
	"combat_receipt_id",
	"intent_fingerprint",
]


static func build_facility_damage_batch(
	source_effect_id: String,
	combat_receipt_id: String,
	damage_kind: String,
	allocations: Array
) -> Dictionary:
	var intents: Array = []
	var seen_targets := {}
	var total_damage := 0
	for allocation_variant in allocations:
		if not (allocation_variant is Dictionary):
			return _facility_failure(
				"facility_damage_allocation_not_dictionary",
				combat_receipt_id
			)
		var allocation := allocation_variant as Dictionary
		if not _exact_fields(allocation, FACILITY_ALLOCATION_FIELDS):
			return _facility_failure(
				"facility_damage_allocation_fields_invalid",
				combat_receipt_id
			)
		var target_id := str(allocation.get("target_facility_id", ""))
		if seen_targets.has(target_id):
			return _facility_failure(
				"facility_damage_allocation_duplicate_target",
				combat_receipt_id
			)
		var intent := FacilityDamageIntent.build(
			source_effect_id,
			target_id,
			int(allocation.get("expected_generation", -1)),
			int(allocation.get("damage_amount", 0)),
			damage_kind,
			combat_receipt_id
		)
		if intent.is_empty():
			return _facility_failure(
				"facility_damage_intent_invalid",
				combat_receipt_id
			)
		seen_targets[target_id] = true
		total_damage += int(allocation.get("damage_amount", 0))
		intents.append(intent)
	if intents.is_empty():
		return _facility_failure(
			"facility_damage_allocation_empty",
			combat_receipt_id
		)
	return {
		"accepted": true,
		"contract_id": FACILITY_BATCH_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"reason_code": "facility_damage_intents_built",
		"combat_receipt_id": combat_receipt_id,
		"intents": intents,
		"intent_count": intents.size(),
		"total_damage": total_damage,
		"direct_facility_write_count": 0,
		"facility_state_payload_count": 0,
		"private_field_count": 0,
	}


static func build_monster_damage_intent(
	source_effect_id: String,
	target_monster_source_instance_id: String,
	expected_source_generation: int,
	observed_source_revision: int,
	damage_amount: int,
	public_target_region_id: String,
	combat_receipt_id: String
) -> Dictionary:
	var intent := {
		"schema_version": 1,
		"contract_id": MONSTER_DAMAGE_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"source_effect_id": source_effect_id,
		"target_monster_source_instance_id": (
			target_monster_source_instance_id
		),
		"expected_source_generation": expected_source_generation,
		"observed_source_revision": observed_source_revision,
		"damage_amount": damage_amount,
		"damage_kind": "military_monster_assault",
		"public_target_region_id": public_target_region_id,
		"combat_receipt_id": combat_receipt_id,
		"intent_fingerprint": "",
	}
	intent["intent_fingerprint"] = _fingerprint_without(
		intent, "intent_fingerprint"
	)
	return intent 		if bool(monster_damage_validation_report(intent).get("valid", false)) 		else {}


static func monster_damage_validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("monster_damage_intent_not_closed_data")
		return _report(errors, "monster_damage_intent_valid")
	var intent := value as Dictionary
	if not _exact_fields(intent, MONSTER_DAMAGE_FIELDS):
		errors.append("monster_damage_intent_fields_invalid")
		return _report(errors, "monster_damage_intent_valid")
	if int(intent.get("schema_version", -1)) != 1:
		errors.append("monster_damage_intent_schema_invalid")
	if str(intent.get("contract_id", "")) != MONSTER_DAMAGE_CONTRACT_ID:
		errors.append("monster_damage_intent_contract_invalid")
	if str(intent.get("ruleset_id", "")) != RULESET_ID:
		errors.append("monster_damage_intent_ruleset_invalid")
	for field in [
		"source_effect_id",
		"target_monster_source_instance_id",
		"public_target_region_id",
		"combat_receipt_id",
	]:
		if not _stable_id(intent.get(field)):
			errors.append("monster_damage_intent_%s_invalid" % field)
	if not _positive_integer(intent.get("expected_source_generation")):
		errors.append("monster_damage_intent_generation_invalid")
	if not _nonnegative_integer(intent.get("observed_source_revision")):
		errors.append("monster_damage_intent_revision_invalid")
	if not _positive_integer(intent.get("damage_amount")):
		errors.append("monster_damage_intent_amount_invalid")
	if str(intent.get("damage_kind", "")) != "military_monster_assault":
		errors.append("monster_damage_intent_kind_invalid")
	var fingerprint := str(intent.get("intent_fingerprint", ""))
	if not _fingerprint_valid(fingerprint) 			or fingerprint != _fingerprint_without(intent, "intent_fingerprint"):
		errors.append("monster_damage_intent_fingerprint_invalid")
	return _report(errors, "monster_damage_intent_valid")


static func contract_report() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"facility_damage_contract_id": FacilityDamageIntent.CONTRACT_ID,
		"facility_damage_required_fields": (
			FacilityDamageIntent.required_fields()
		),
		"direct_facility_write_count": 0,
		"direct_monster_write_count": 0,
		"private_warehouse_reader_count": 0,
		"typed_facility_damage_port": true,
	}


static func _facility_failure(
	reason_code: String, combat_receipt_id: String
) -> Dictionary:
	return {
		"accepted": false,
		"contract_id": FACILITY_BATCH_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"reason_code": reason_code,
		"combat_receipt_id": combat_receipt_id,
		"intents": [],
		"intent_count": 0,
		"total_damage": 0,
		"direct_facility_write_count": 0,
		"facility_state_payload_count": 0,
		"private_field_count": 0,
	}


static func _report(
	errors: Array[String], success_reason: String
) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors.duplicate(),
		"reason_code": success_reason if errors.is_empty() else errors[0],
	}


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


static func _nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


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