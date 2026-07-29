extends RefCounted
class_name CurrentActionContextProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const TABLE_NAVIGATION := preload("res://scripts/runtime/table_navigation_action_intent.gd")
const INTEL_NAVIGATION := preload("res://scripts/runtime/intel_application_intent.gd")

const SCHEMA_VERSION := 1

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"context_id",
	"source_revision",
	"title",
	"summary",
	"reason_id",
	"reason_text",
	"costs",
	"requirements",
	"consequences",
	"game_action_offers",
	"navigation_intents",
	"projection_fingerprint",
]
const COST_FIELDS := ["cost_id", "resource_id", "amount_units", "display_token"]
const REQUIREMENT_FIELDS := [
	"requirement_id", "satisfied", "reason_id", "message_token", "arguments",
]
const CONSEQUENCE_FIELDS := ["consequence_id", "message_token", "arguments"]
const TABLE_NAVIGATION_FIELDS := [
	"request_id", "action_kind", "source_surface", "target_card_name",
]
const INTEL_NAVIGATION_FIELDS := [
	"kind", "focused_history_entry_id", "focused_region_id",
]
const FORBIDDEN_KEYS := [
	"cash",
	"exact_gdp_private_data",
	"normal_hand",
	"hand",
	"private_hand",
	"commodity_inventory",
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
		return _invalid("current_action_context_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("current_action_context_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("current_action_context_projection_schema_invalid")
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")) \
			or not WIRE.is_stable_id(projection.get("context_id")) \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")) \
			or not _display_text(projection.get("title"), false, 160) \
			or not _display_text(projection.get("summary"), true, 1000) \
			or not WIRE.is_stable_id(projection.get("reason_id")) \
			or not _display_text(projection.get("reason_text"), true, 1000):
		return _invalid("current_action_context_projection_identity_invalid")
	for field in ["costs", "requirements", "consequences", "game_action_offers", "navigation_intents"]:
		if not (projection.get(field) is Array):
			return _invalid("current_action_context_projection_collection_invalid")
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("current_action_context_projection_forbidden_field")
	var cost_ids: Array[String] = []
	for cost_variant in projection.get("costs") as Array:
		var cost_error := _cost_error(cost_variant)
		if not cost_error.is_empty():
			return _invalid(cost_error)
		var cost_id := str((cost_variant as Dictionary).get("cost_id", ""))
		if cost_ids.has(cost_id):
			return _invalid("current_action_context_projection_cost_duplicate")
		cost_ids.append(cost_id)
	var requirement_ids: Array[String] = []
	for requirement_variant in projection.get("requirements") as Array:
		var requirement_error := _requirement_error(requirement_variant)
		if not requirement_error.is_empty():
			return _invalid(requirement_error)
		var requirement_id := str((requirement_variant as Dictionary).get("requirement_id", ""))
		if requirement_ids.has(requirement_id):
			return _invalid("current_action_context_projection_requirement_duplicate")
		requirement_ids.append(requirement_id)
	var consequence_ids: Array[String] = []
	for consequence_variant in projection.get("consequences") as Array:
		var consequence_error := _consequence_error(consequence_variant)
		if not consequence_error.is_empty():
			return _invalid(consequence_error)
		var consequence_id := str((consequence_variant as Dictionary).get("consequence_id", ""))
		if consequence_ids.has(consequence_id):
			return _invalid("current_action_context_projection_consequence_duplicate")
		consequence_ids.append(consequence_id)
	var offer_fingerprints: Array[String] = []
	for offer_variant in projection.get("game_action_offers") as Array:
		var offer_error := _offer_error(offer_variant, int(projection.get("source_revision", -1)))
		if not offer_error.is_empty():
			return _invalid(offer_error)
		var offer_fingerprint := str((offer_variant as Dictionary).get("offer_fingerprint", ""))
		if offer_fingerprints.has(offer_fingerprint):
			return _invalid("current_action_context_projection_offer_duplicate")
		offer_fingerprints.append(offer_fingerprint)
	for intent_variant in projection.get("navigation_intents") as Array:
		var navigation_error := _navigation_intent_error(intent_variant)
		if not navigation_error.is_empty():
			return _invalid(navigation_error)
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("current_action_context_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _cost_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "current_action_context_projection_cost_not_closed"
	var cost := value as Dictionary
	if not WIRE.exact_fields(cost, COST_FIELDS) \
			or not WIRE.is_stable_id(cost.get("cost_id")) \
			or not WIRE.is_stable_id(cost.get("resource_id")) \
			or not WIRE.is_nonnegative_integer(cost.get("amount_units")) \
			or not WIRE.is_stable_id(cost.get("display_token")):
		return "current_action_context_projection_cost_invalid"
	return ""


static func _requirement_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "current_action_context_projection_requirement_not_closed"
	var requirement := value as Dictionary
	if not WIRE.exact_fields(requirement, REQUIREMENT_FIELDS) \
			or not WIRE.is_stable_id(requirement.get("requirement_id")) \
			or not (requirement.get("satisfied") is bool) \
			or not WIRE.is_stable_id(requirement.get("reason_id")) \
			or not WIRE.is_stable_id(requirement.get("message_token")):
		return "current_action_context_projection_requirement_invalid"
	var arguments_error := _arguments_error(requirement.get("arguments"))
	return "current_action_context_projection_requirement_%s" % arguments_error \
		if not arguments_error.is_empty() else ""


static func _consequence_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "current_action_context_projection_consequence_not_closed"
	var consequence := value as Dictionary
	if not WIRE.exact_fields(consequence, CONSEQUENCE_FIELDS) \
			or not WIRE.is_stable_id(consequence.get("consequence_id")) \
			or not WIRE.is_stable_id(consequence.get("message_token")):
		return "current_action_context_projection_consequence_invalid"
	var arguments_error := _arguments_error(consequence.get("arguments"))
	return "current_action_context_projection_consequence_%s" % arguments_error \
		if not arguments_error.is_empty() else ""


static func _offer_error(value: Variant, source_revision: int) -> String:
	if not bool(OFFER.validation_report(value).get("valid", false)):
		return "current_action_context_projection_offer_invalid"
	var offer := value as Dictionary
	if int(offer.get("source_revision", -1)) != source_revision:
		return "current_action_context_projection_offer_revision_mismatch"
	if str(offer.get("semantic_action_id", "")) == ACTION_INTENT.ACTION_CARD_PLAY:
		return "current_action_context_projection_card_play_forbidden"
	return ""


static func _navigation_intent_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "current_action_context_projection_navigation_not_closed"
	var data := value as Dictionary
	if WIRE.exact_fields(data, TABLE_NAVIGATION_FIELDS):
		var intent := TABLE_NAVIGATION.from_dictionary(data)
		return "" if intent != null \
			and bool(intent.validation_report().get("valid", false)) \
			else "current_action_context_projection_table_navigation_invalid"
	if WIRE.exact_fields(data, INTEL_NAVIGATION_FIELDS):
		return "" if INTEL_NAVIGATION.from_dictionary(data) != null \
			else "current_action_context_projection_intel_navigation_invalid"
	return "current_action_context_projection_navigation_fields_invalid"


static func _arguments_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "arguments_not_closed"
	for key_variant in (value as Dictionary).keys():
		if not WIRE.is_stable_id(key_variant):
			return "arguments_key_invalid"
		var argument: Variant = (value as Dictionary).get(key_variant)
		if not (argument is String or argument is bool or WIRE.is_safe_integer(argument)):
			return "arguments_value_invalid"
	return ""


static func _display_text(value: Variant, allow_empty: bool, max_length: int) -> bool:
	return value is String and (allow_empty or not str(value).is_empty()) \
		and str(value).length() <= max_length


static func _invalid(reason_id: String) -> Dictionary:
	return WIRE.invalid_result(reason_id)
