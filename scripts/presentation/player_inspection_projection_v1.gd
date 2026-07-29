extends RefCounted
class_name PlayerInspectionProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const TABLE_NAVIGATION := preload("res://scripts/runtime/table_navigation_action_intent.gd")
const INTEL_NAVIGATION := preload("res://scripts/runtime/intel_application_intent.gd")

const SCHEMA_VERSION := 1

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"source_revision",
	"player_id",
	"display_name",
	"role_display_name",
	"avatar_key",
	"accent",
	"public_status",
	"public_assets_summary",
	"public_facilities_summary",
	"public_military_summary",
	"public_monster_summary",
	"public_history_links",
	"allowed_navigation_intents",
	"projection_fingerprint",
]
const HISTORY_LINK_FIELDS := ["history_entry_id", "label", "navigation_intent"]
const TABLE_NAVIGATION_FIELDS := [
	"request_id", "action_kind", "source_surface", "target_card_name",
]
const INTEL_NAVIGATION_FIELDS := [
	"kind", "focused_history_entry_id", "focused_region_id",
]
const FORBIDDEN_KEYS := [
	"cash",
	"cash_cents",
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
		return _invalid("player_inspection_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("player_inspection_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("player_inspection_projection_schema_invalid")
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")) \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")) \
			or not WIRE.is_stable_id(projection.get("player_id")):
		return _invalid("player_inspection_projection_binding_invalid")
	for field in [
		"display_name", "role_display_name", "avatar_key", "accent", "public_status",
	]:
		if not _display_text(projection.get(field), false, 160):
			return _invalid("player_inspection_projection_identity_text_invalid")
	for field in [
		"public_assets_summary", "public_facilities_summary",
		"public_military_summary", "public_monster_summary",
	]:
		if not _display_text(projection.get(field), true, 1000):
			return _invalid("player_inspection_projection_summary_invalid")
	if not (projection.get("public_history_links") is Array) \
			or not (projection.get("allowed_navigation_intents") is Array):
		return _invalid("player_inspection_projection_links_invalid")
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("player_inspection_projection_forbidden_field")
	var history_ids: Array[String] = []
	for link_variant in projection.get("public_history_links") as Array:
		var link_error := _history_link_error(link_variant)
		if not link_error.is_empty():
			return _invalid(link_error)
		var history_id := str((link_variant as Dictionary).get("history_entry_id", ""))
		if history_ids.has(history_id):
			return _invalid("player_inspection_projection_history_link_duplicate")
		history_ids.append(history_id)
	for intent_variant in projection.get("allowed_navigation_intents") as Array:
		var navigation_error := _navigation_intent_error(intent_variant)
		if not navigation_error.is_empty():
			return _invalid(navigation_error)
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("player_inspection_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _history_link_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "player_inspection_projection_history_link_not_closed"
	var link := value as Dictionary
	if not WIRE.exact_fields(link, HISTORY_LINK_FIELDS) \
			or not WIRE.is_ascii_reference(link.get("history_entry_id")) \
			or not _display_text(link.get("label"), false, 160):
		return "player_inspection_projection_history_link_invalid"
	var navigation_error := _navigation_intent_error(link.get("navigation_intent"))
	return "player_inspection_projection_history_%s" % navigation_error \
		if not navigation_error.is_empty() else ""


static func _navigation_intent_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "navigation_intent_not_closed"
	var data := value as Dictionary
	if WIRE.exact_fields(data, TABLE_NAVIGATION_FIELDS):
		var intent := TABLE_NAVIGATION.from_dictionary(data)
		return "" if intent != null \
			and bool(intent.validation_report().get("valid", false)) \
			else "navigation_intent_table_invalid"
	if WIRE.exact_fields(data, INTEL_NAVIGATION_FIELDS):
		return "" if INTEL_NAVIGATION.from_dictionary(data) != null \
			else "navigation_intent_intel_invalid"
	return "navigation_intent_fields_invalid"


static func _display_text(value: Variant, allow_empty: bool, max_length: int) -> bool:
	return value is String and (allow_empty or not str(value).is_empty()) \
		and str(value).length() <= max_length


static func _invalid(reason_id: String) -> Dictionary:
	return WIRE.invalid_result(reason_id)
