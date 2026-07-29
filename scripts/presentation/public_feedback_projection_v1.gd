extends RefCounted
class_name PublicFeedbackProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const TABLE_NAVIGATION := preload("res://scripts/runtime/table_navigation_action_intent.gd")
const INTEL_NAVIGATION := preload("res://scripts/runtime/intel_application_intent.gd")

const SCHEMA_VERSION := 1
const SEVERITY_SUCCESS := "success"
const SEVERITY_WARNING := "warning"
const SEVERITY_FAILURE := "failure"
const SEVERITY_INFORMATIONAL := "informational"
const SEVERITIES := [
	SEVERITY_SUCCESS,
	SEVERITY_WARNING,
	SEVERITY_FAILURE,
	SEVERITY_INFORMATIONAL,
]
const VISIBILITY_PUBLIC := "public"
const VISIBILITY_VIEWER_PRIVATE := "viewer_private"

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"receipt_id",
	"revision",
	"severity",
	"reason_id",
	"message_token",
	"arguments",
	"public_or_viewer_private",
	"history_link",
	"projection_fingerprint",
]
const HISTORY_LINK_FIELDS := ["link_id", "label", "navigation_intent"]
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
		return _invalid("public_feedback_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("public_feedback_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("public_feedback_projection_schema_invalid")
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")) \
			or not WIRE.is_stable_id(projection.get("receipt_id")) \
			or not WIRE.is_nonnegative_integer(projection.get("revision")) \
			or str(projection.get("severity", "")) not in SEVERITIES \
			or not WIRE.is_stable_id(projection.get("reason_id")) \
			or not WIRE.is_stable_id(projection.get("message_token")) \
			or str(projection.get("public_or_viewer_private", "")) \
			not in [VISIBILITY_PUBLIC, VISIBILITY_VIEWER_PRIVATE]:
		return _invalid("public_feedback_projection_identity_invalid")
	if str(projection.get("severity", "")) == SEVERITY_FAILURE \
			and str(projection.get("reason_id", "")) == "none":
		return _invalid("public_feedback_projection_failure_reason_missing")
	var arguments_error := _arguments_error(projection.get("arguments"))
	if not arguments_error.is_empty():
		return _invalid("public_feedback_projection_%s" % arguments_error)
	var history_error := _history_link_error(projection.get("history_link"))
	if not history_error.is_empty():
		return _invalid(history_error)
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("public_feedback_projection_forbidden_field")
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("public_feedback_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _history_link_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "public_feedback_projection_history_link_not_closed"
	var link := value as Dictionary
	if link.is_empty():
		return ""
	if not WIRE.exact_fields(link, HISTORY_LINK_FIELDS) \
			or not WIRE.is_stable_id(link.get("link_id")) \
			or not _display_text(link.get("label"), false, 160):
		return "public_feedback_projection_history_link_invalid"
	var navigation_error := _navigation_intent_error(link.get("navigation_intent"))
	return "public_feedback_projection_history_%s" % navigation_error \
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
