extends RefCounted
class_name V074MapTargetBindingV1

const Wire := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.4"
const BINDING_ID := "v074.map_target_binding.v1"
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const INDUSTRY_IDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const ACTION_MODES := ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"]
const SOURCE_SURFACES := ["planet_map", "target_rail"]
const BINDING_FIELDS := [
	"schema_version",
	"binding_contract_id",
	"binding_id",
	"ruleset_id",
	"card_instance_id",
	"card_definition_id",
	"target_region_id",
	"target_slot_id",
	"facility_type",
	"industry_id",
	"facility_action_mode",
	"target_revision",
	"target_slot_generation",
	"expected_facility_id",
	"expected_facility_generation",
	"expected_owner_id",
	"expected_rank",
	"expected_damage_revision",
	"asset_cost",
	"source_surface",
	"selection_revision",
	"binding_fingerprint",
]
const PRIVATE_KEYS := [
	"warehouse_stock",
	"warehouse_inventory",
	"inventory_by_commodity",
	"private_logistics",
	"private_logistics_plan",
	"future_transport_plan",
	"future_action",
	"ai_plan",
	"ai_score",
	"opponent_hand",
	"hidden_lead_order",
]


static func from_legal_option(
	card_instance_id: String,
	card_definition_id: String,
	option: Dictionary,
	source_surface: String,
	selection_revision: int
) -> Dictionary:
	if not Wire.is_stable_id(card_instance_id) 			or not Wire.is_stable_id(card_definition_id) 			or source_surface not in SOURCE_SURFACES 			or selection_revision < 0:
		return {}
	if option.has("legal") and not bool(option.get("legal", false)):
		return {}
	var region_id := str(option.get(
		"target_region_id",
		option.get("region_id", "")
	))
	var slot_id := str(option.get(
		"target_slot_id",
		option.get("slot_id", "")
	))
	var facility_type := str(option.get("facility_type", ""))
	var industry_id := str(option.get("industry_id", ""))
	var action_mode := str(option.get(
		"facility_action_mode",
		option.get("action_mode", "")
	))
	if not Wire.is_stable_id(region_id) 			or not Wire.is_ascii_reference(slot_id) 			or facility_type not in FACILITY_TYPES 			or industry_id not in INDUSTRY_IDS 			or action_mode not in ACTION_MODES:
		return {}
	var identity_input := "%s|%s|%s|%s|%s|%d" % [
		card_instance_id,
		slot_id,
		facility_type,
		industry_id,
		action_mode,
		selection_revision,
	]
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"binding_contract_id": BINDING_ID,
		"binding_id": "binding.v074.%s" % identity_input.sha256_text().substr(0, 24),
		"ruleset_id": RULESET_ID,
		"card_instance_id": card_instance_id,
		"card_definition_id": card_definition_id,
		"target_region_id": region_id,
		"target_slot_id": slot_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"facility_action_mode": action_mode,
		"target_revision": _integer(option, ["target_revision", "region_revision"], 0),
		"target_slot_generation": _integer(option, ["target_slot_generation", "slot_generation"], 0),
		"expected_facility_id": _text(option, ["expected_facility_id", "facility_id"]),
		"expected_facility_generation": _integer(
			option,
			["expected_facility_generation", "facility_generation"],
			0
		),
		"expected_owner_id": _text(option, ["expected_owner_id", "owner_id"]),
		"expected_rank": _integer(option, ["expected_rank", "rank"], 0),
		"expected_damage_revision": _integer(
			option,
			["expected_damage_revision", "damage_revision"],
			0
		),
		"asset_cost": maxi(0, _integer(
			option,
			["asset_cost", "primary_asset_cost"],
			0
		)),
		"source_surface": source_surface,
		"selection_revision": selection_revision,
	}
	var binding := Wire.sealed_copy(unsealed, "binding_fingerprint")
	return binding if bool(validation_report(binding).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not Wire.is_closed_data(value):
		return _invalid("binding_not_closed_data")
	var binding := value as Dictionary
	if not Wire.exact_fields(binding, BINDING_FIELDS):
		return _invalid("binding_fields_invalid")
	if int(binding.get("schema_version", 0)) != SCHEMA_VERSION 			or str(binding.get("binding_contract_id", "")) != BINDING_ID 			or str(binding.get("ruleset_id", "")) != RULESET_ID:
		return _invalid("binding_identity_invalid")
	for field in ["binding_id", "card_instance_id", "card_definition_id", "target_region_id"]:
		if not Wire.is_stable_id(binding.get(field)):
			return _invalid("%s_invalid" % field)
	if not Wire.is_ascii_reference(binding.get("target_slot_id")):
		return _invalid("target_slot_id_invalid")
	if str(binding.get("facility_type", "")) not in FACILITY_TYPES:
		return _invalid("facility_type_invalid")
	if str(binding.get("industry_id", "")) not in INDUSTRY_IDS:
		return _invalid("industry_id_invalid")
	if str(binding.get("facility_action_mode", "")) not in ACTION_MODES:
		return _invalid("facility_action_mode_invalid")
	if str(binding.get("source_surface", "")) not in SOURCE_SURFACES:
		return _invalid("source_surface_invalid")
	for field in [
		"target_revision",
		"target_slot_generation",
		"expected_facility_generation",
		"expected_rank",
		"expected_damage_revision",
		"asset_cost",
		"selection_revision",
	]:
		if not Wire.is_nonnegative_integer(binding.get(field)):
			return _invalid("%s_invalid" % field)
	for field in ["expected_facility_id", "expected_owner_id"]:
		var field_value := str(binding.get(field, ""))
		if not field_value.is_empty() and not Wire.is_ascii_reference(field_value):
			return _invalid("%s_invalid" % field)
	if Wire.contains_key_recursive(binding, PRIVATE_KEYS):
		return _invalid("binding_private_field_detected")
	var fingerprint := str(binding.get("binding_fingerprint", ""))
	if not Wire.is_fingerprint(fingerprint) 			or fingerprint != Wire.fingerprint(binding, "binding_fingerprint"):
		return _invalid("binding_fingerprint_invalid")
	return {"valid": true, "reason_code": "none"}


static func to_card_queue_intent(binding: Dictionary) -> Dictionary:
	if not bool(validation_report(binding).get("valid", false)):
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"intent_kind": "card.queue",
		"card_instance_id": str(binding.get("card_instance_id", "")),
		"target_slot_id": str(binding.get("target_slot_id", "")),
		"target_binding": binding.duplicate(true),
	}


static func same_slot_identity(left: Dictionary, right: Dictionary) -> bool:
	if not bool(validation_report(left).get("valid", false)) 			or not bool(validation_report(right).get("valid", false)):
		return false
	for field in [
		"target_region_id",
		"target_slot_id",
		"facility_type",
		"industry_id",
		"facility_action_mode",
	]:
		if left.get(field) != right.get(field):
			return false
	return true


static func _text(source: Dictionary, fields: Array) -> String:
	for field_variant in fields:
		var field := str(field_variant)
		if source.has(field):
			return str(source.get(field, ""))
	return ""


static func _integer(source: Dictionary, fields: Array, fallback: int) -> int:
	for field_variant in fields:
		var field := str(field_variant)
		if source.has(field):
			var value: Variant = source.get(field)
			if value is int or value is float:
				return int(value)
	return fallback


static func _invalid(reason_code: String) -> Dictionary:
	return {"valid": false, "reason_code": reason_code}
