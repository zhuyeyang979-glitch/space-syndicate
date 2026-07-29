extends RefCounted
class_name RegionSupplyPopupProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const TABLE_NAVIGATION := preload("res://scripts/runtime/table_navigation_action_intent.gd")
const INTEL_NAVIGATION := preload("res://scripts/runtime/intel_application_intent.gd")

const SCHEMA_VERSION := 1
const MAX_ARGUMENT_STRING_LENGTH := 1000
const FORBIDDEN_ARGUMENT_KEYS := [
	"raw",
	"raw_payload",
	"payload",
	"cash",
	"cash_cents",
	"inventory",
	"commodity_inventory",
	"private_target",
	"private_target_id",
]

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"region_id",
	"region_index",
	"display_name",
	"source_revision",
	"rack_revision",
	"public_status",
	"availability",
	"monster_price_pressure",
	"facility_slots",
	"rack_cards",
	"requirements",
	"allowed_actions",
	"allowed_navigation_intents",
	"projection_fingerprint",
]
const AVAILABILITY_FIELDS := ["state_id", "reason_id", "reason_text"]
const FACILITY_SLOT_FIELDS := [
	"slot_id", "display_name", "public_status", "is_occupied", "detail_context_id",
]
const RACK_CARD_FIELDS := [
	"rack_card_id",
	"card_semantic_id",
	"display_name",
	"illustration_key",
	"costs",
	"availability",
	"detail_context_id",
	"source_revision",
	"rack_revision",
]
const COST_FIELDS := ["cost_id", "resource_id", "amount_units", "display_token"]
const REQUIREMENT_FIELDS := [
	"requirement_id", "satisfied", "reason_id", "message_token", "arguments",
]
const TABLE_NAVIGATION_FIELDS := [
	"request_id", "action_kind", "source_surface", "target_card_name",
]
const INTEL_NAVIGATION_FIELDS := [
	"kind", "focused_history_entry_id", "focused_region_id",
]
const ALLOWED_ACTION_IDS := [
	ACTION_INTENT.ACTION_DISTRICT_SELECT,
	ACTION_INTENT.ACTION_DISTRICT_SUPPLY_OPEN,
	ACTION_INTENT.ACTION_DISTRICT_SUPPLY_CLOSE,
	ACTION_INTENT.ACTION_DISTRICT_SUPPLY_QUOTE,
	ACTION_INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE,
	ACTION_INTENT.ACTION_PLAYER_STRATEGY_OPEN_SUPPLY,
]
const FORBIDDEN_KEYS := [
	"cash",
	"exact_gdp_private_data",
	"normal_hand",
	"hand",
	"private_hand",
	"commodity_inventory",
	"bound_actions",
	"ai_plan",
	"hidden_owner",
	"hidden_lead",
	"private_target",
	"future_submission",
	"future_rack",
	"future_track_sequence",
	"rng_state",
	"node",
	"object",
	"resource",
	"callable",
	"node_path",
	"nodepath",
	"method",
	"method_name",
	"callback",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or unsealed.has("projection_fingerprint"):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "projection_fingerprint")
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}


static func matches_viewer_authorization(
	value: Variant,
	viewer_index: int,
	authorization_revision: int
) -> bool:
	return viewer_index >= 0 and authorization_revision > 0 \
		and bool(validation_report(value).get("valid", false)) \
		and int((value as Dictionary).get("viewer_index", -1)) == viewer_index \
		and int((value as Dictionary).get("authorization_revision", 0)) \
		== authorization_revision


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("region_supply_popup_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("region_supply_popup_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("region_supply_popup_projection_schema_invalid")
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")) \
			or not WIRE.is_stable_id(projection.get("region_id")) \
			or not WIRE.is_nonnegative_integer(projection.get("region_index")) \
			or not _display_text(projection.get("display_name"), false, 160) \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")) \
			or not WIRE.is_nonnegative_integer(projection.get("rack_revision")) \
			or not WIRE.is_stable_id(projection.get("public_status")) \
			or not WIRE.is_safe_integer(projection.get("monster_price_pressure")):
		return _invalid("region_supply_popup_projection_identity_invalid")
	for field in ["facility_slots", "rack_cards", "requirements", "allowed_actions", "allowed_navigation_intents"]:
		if not (projection.get(field) is Array):
			return _invalid("region_supply_popup_projection_collection_invalid")
	var availability_error := _availability_error(projection.get("availability"))
	if not availability_error.is_empty():
		return _invalid(availability_error)
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("region_supply_popup_projection_forbidden_field")
	var slot_ids: Array[String] = []
	for slot_variant in projection.get("facility_slots") as Array:
		var slot_error := _facility_slot_error(slot_variant)
		if not slot_error.is_empty():
			return _invalid(slot_error)
		var slot_id := str((slot_variant as Dictionary).get("slot_id", ""))
		if slot_ids.has(slot_id):
			return _invalid("region_supply_popup_projection_facility_slot_duplicate")
		slot_ids.append(slot_id)
	var rack_ids: Array[String] = []
	for card_variant in projection.get("rack_cards") as Array:
		var card_error := _rack_card_error(
			card_variant,
			int(projection.get("source_revision", -1)),
			int(projection.get("rack_revision", -1))
		)
		if not card_error.is_empty():
			return _invalid(card_error)
		var rack_id := str((card_variant as Dictionary).get("rack_card_id", ""))
		if rack_ids.has(rack_id):
			return _invalid("region_supply_popup_projection_rack_card_duplicate")
		rack_ids.append(rack_id)
	var requirement_ids: Array[String] = []
	for requirement_variant in projection.get("requirements") as Array:
		var requirement_error := _requirement_error(requirement_variant)
		if not requirement_error.is_empty():
			return _invalid(requirement_error)
		var requirement_id := str((requirement_variant as Dictionary).get("requirement_id", ""))
		if requirement_ids.has(requirement_id):
			return _invalid("region_supply_popup_projection_requirement_duplicate")
		requirement_ids.append(requirement_id)
	var offer_fingerprints: Array[String] = []
	for offer_variant in projection.get("allowed_actions") as Array:
		var offer_error := _offer_error(offer_variant, int(projection.get("source_revision", -1)))
		if not offer_error.is_empty():
			return _invalid(offer_error)
		var offer_fingerprint := str((offer_variant as Dictionary).get("offer_fingerprint", ""))
		if offer_fingerprints.has(offer_fingerprint):
			return _invalid("region_supply_popup_projection_action_duplicate")
		offer_fingerprints.append(offer_fingerprint)
	for intent_variant in projection.get("allowed_navigation_intents") as Array:
		var navigation_error := _navigation_intent_error(intent_variant)
		if not navigation_error.is_empty():
			return _invalid(navigation_error)
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("region_supply_popup_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _availability_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "region_supply_popup_projection_availability_not_closed"
	var availability := value as Dictionary
	if not WIRE.exact_fields(availability, AVAILABILITY_FIELDS) \
			or str(availability.get("state_id", "")) not in ["available", "disabled"] \
			or not WIRE.is_stable_id(availability.get("reason_id")) \
			or not _display_text(availability.get("reason_text"), true, 500):
		return "region_supply_popup_projection_availability_invalid"
	if str(availability.get("state_id", "")) == "available" \
			and str(availability.get("reason_id", "")) != "none":
		return "region_supply_popup_projection_available_reason_invalid"
	if str(availability.get("state_id", "")) == "disabled" \
			and str(availability.get("reason_id", "")) == "none":
		return "region_supply_popup_projection_disabled_reason_missing"
	return ""


static func _facility_slot_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "region_supply_popup_projection_facility_slot_not_closed"
	var slot := value as Dictionary
	if not WIRE.exact_fields(slot, FACILITY_SLOT_FIELDS) \
			or not WIRE.is_stable_id(slot.get("slot_id")) \
			or not _display_text(slot.get("display_name"), true, 160) \
			or not WIRE.is_stable_id(slot.get("public_status")) \
			or not (slot.get("is_occupied") is bool) \
			or not WIRE.is_stable_id(slot.get("detail_context_id")):
		return "region_supply_popup_projection_facility_slot_invalid"
	return ""


static func _rack_card_error(value: Variant, source_revision: int, rack_revision: int) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "region_supply_popup_projection_rack_card_not_closed"
	var card := value as Dictionary
	if not WIRE.exact_fields(card, RACK_CARD_FIELDS) \
			or not WIRE.is_stable_id(card.get("rack_card_id")) \
			or not WIRE.is_stable_id(card.get("card_semantic_id")) \
			or not _display_text(card.get("display_name"), false, 160) \
			or not _display_text(card.get("illustration_key"), false, 160) \
			or not (card.get("costs") is Array) \
			or not WIRE.is_stable_id(card.get("detail_context_id")) \
			or int(card.get("source_revision", -1)) != source_revision \
			or int(card.get("rack_revision", -1)) != rack_revision:
		return "region_supply_popup_projection_rack_card_invalid"
	var availability_error := _availability_error(card.get("availability"))
	if not availability_error.is_empty():
		return availability_error.replace("projection_availability", "projection_rack_card_availability")
	var cost_ids: Array[String] = []
	for cost_variant in card.get("costs") as Array:
		var cost_error := _cost_error(cost_variant)
		if not cost_error.is_empty():
			return cost_error
		var cost_id := str((cost_variant as Dictionary).get("cost_id", ""))
		if cost_ids.has(cost_id):
			return "region_supply_popup_projection_rack_card_cost_duplicate"
		cost_ids.append(cost_id)
	return ""


static func _cost_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "region_supply_popup_projection_cost_not_closed"
	var cost := value as Dictionary
	if not WIRE.exact_fields(cost, COST_FIELDS) \
			or not WIRE.is_stable_id(cost.get("cost_id")) \
			or not WIRE.is_stable_id(cost.get("resource_id")) \
			or not WIRE.is_nonnegative_integer(cost.get("amount_units")) \
			or not WIRE.is_stable_id(cost.get("display_token")):
		return "region_supply_popup_projection_cost_invalid"
	return ""


static func _requirement_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "region_supply_popup_projection_requirement_not_closed"
	var requirement := value as Dictionary
	if not WIRE.exact_fields(requirement, REQUIREMENT_FIELDS) \
			or not WIRE.is_stable_id(requirement.get("requirement_id")) \
			or not (requirement.get("satisfied") is bool) \
			or not WIRE.is_stable_id(requirement.get("reason_id")) \
			or not WIRE.is_stable_id(requirement.get("message_token")):
		return "region_supply_popup_projection_requirement_invalid"
	var arguments_error := _arguments_error(requirement.get("arguments"))
	return "region_supply_popup_projection_requirement_%s" % arguments_error \
		if not arguments_error.is_empty() else ""


static func _offer_error(value: Variant, source_revision: int) -> String:
	if not bool(OFFER.validation_report(value).get("valid", false)):
		return "region_supply_popup_projection_action_invalid"
	var offer := value as Dictionary
	if int(offer.get("source_revision", -1)) != source_revision:
		return "region_supply_popup_projection_action_revision_mismatch"
	if str(offer.get("semantic_action_id", "")) not in ALLOWED_ACTION_IDS:
		return "region_supply_popup_projection_action_kind_invalid"
	return ""


static func _navigation_intent_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "region_supply_popup_projection_navigation_not_closed"
	var data := value as Dictionary
	if WIRE.exact_fields(data, TABLE_NAVIGATION_FIELDS):
		var intent := TABLE_NAVIGATION.from_dictionary(data)
		return "" if intent != null \
			and bool(intent.validation_report().get("valid", false)) \
			else "region_supply_popup_projection_table_navigation_invalid"
	if WIRE.exact_fields(data, INTEL_NAVIGATION_FIELDS):
		return "" if INTEL_NAVIGATION.from_dictionary(data) != null \
			else "region_supply_popup_projection_intel_navigation_invalid"
	return "region_supply_popup_projection_navigation_fields_invalid"


static func _arguments_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "arguments_not_closed"
	for key_variant in (value as Dictionary).keys():
		if not WIRE.is_stable_id(key_variant):
			return "arguments_key_invalid"
		if str(key_variant) in FORBIDDEN_ARGUMENT_KEYS:
			return "arguments_key_forbidden"
		var argument: Variant = (value as Dictionary).get(key_variant)
		if not (argument is String or argument is bool or WIRE.is_safe_integer(argument)):
			return "arguments_value_invalid"
		if argument is String and str(argument).length() > MAX_ARGUMENT_STRING_LENGTH:
			return "arguments_string_too_long"
	return ""


static func _display_text(value: Variant, allow_empty: bool, max_length: int) -> bool:
	return value is String and (allow_empty or not str(value).is_empty()) \
		and str(value).length() <= max_length


static func _invalid(reason_id: String) -> Dictionary:
	return WIRE.invalid_result(reason_id)
