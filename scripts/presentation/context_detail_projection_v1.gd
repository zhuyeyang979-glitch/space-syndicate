extends RefCounted
class_name ContextDetailProjectionV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
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
const KIND_NORMAL_CARD := "normal_card"
const KIND_COMMODITY_CARD := "commodity_card"
const KIND_PUBLIC_TRACK := "public_track"
const KIND_REGION_FACILITY := "region_facility"
const KIND_COMMODITY_SOURCE := "commodity_source"
const KIND_PUBLIC_EVENT := "public_event"
const CONTEXT_KINDS := [
	KIND_NORMAL_CARD,
	KIND_COMMODITY_CARD,
	KIND_PUBLIC_TRACK,
	KIND_REGION_FACILITY,
	KIND_COMMODITY_SOURCE,
	KIND_PUBLIC_EVENT,
]
const VISIBILITY_SCOPES := ["public", "viewer_private"]

const FIELDS := [
	"schema_version",
	"viewer_index",
	"authorization_revision",
	"source_revision",
	"context_id",
	"context_kind",
	"visibility_scope",
	"title",
	"subtitle",
	"content",
	"navigation_intents",
	"projection_fingerprint",
]
const NORMAL_CARD_CONTENT_FIELDS := [
	"card_instance_id",
	"card_semantic_id",
	"display_name",
	"illustration_key",
	"timing_text",
	"target_text",
	"effect_text",
	"duration_text",
	"visibility_text",
	"keyword_tokens",
	"disabled_reason_id",
	"disabled_reason_text",
]
const COMMODITY_CARD_CONTENT_FIELDS := [
	"commodity_card_instance_id",
	"card_semantic_id",
	"commodity_id",
	"display_name",
	"illustration_key",
	"level",
	"base_units",
	"target_text",
	"effect_text",
	"source_text",
	"disabled_reason_id",
	"disabled_reason_text",
]
const PUBLIC_TRACK_CARD_CONTENT_FIELDS := [
	"resolution_id",
	"card_semantic_id",
	"display_name",
	"illustration_key",
	"public_status",
	"summary",
	"detail",
	"keyword_tokens",
]
const REGION_FACILITY_CONTENT_FIELDS := [
	"facility_id",
	"region_id",
	"display_name",
	"illustration_key",
	"public_status",
	"summary",
	"detail",
]
const PUBLIC_COMMODITY_SOURCE_CONTENT_FIELDS := [
	"source_id",
	"commodity_id",
	"display_name",
	"illustration_key",
	"public_status",
	"summary",
	"detail",
]
const PUBLIC_EVENT_CONTENT_FIELDS := [
	"receipt_id",
	"reason_id",
	"message_token",
	"arguments",
	"summary",
	"detail",
	"history_link",
]
const HISTORY_LINK_FIELDS := ["link_id", "label", "navigation_intent"]
const TABLE_NAVIGATION_FIELDS := [
	"request_id", "action_kind", "source_surface", "target_card_name",
]
const INTEL_NAVIGATION_FIELDS := [
	"kind", "focused_history_entry_id", "focused_region_id",
]
const FORBIDDEN_KEYS := [
	"raw",
	"raw_payload",
	"payload",
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
		return _invalid("context_detail_projection_not_closed_data")
	var projection := value as Dictionary
	if not WIRE.exact_fields(projection, FIELDS):
		return _invalid("context_detail_projection_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION:
		return _invalid("context_detail_projection_schema_invalid")
	var context_kind := str(projection.get("context_kind", ""))
	var visibility_scope := str(projection.get("visibility_scope", ""))
	if not WIRE.is_nonnegative_integer(projection.get("viewer_index")) \
			or not WIRE.is_positive_integer(projection.get("authorization_revision")) \
			or not WIRE.is_nonnegative_integer(projection.get("source_revision")) \
			or not WIRE.is_stable_id(projection.get("context_id")) \
			or context_kind not in CONTEXT_KINDS \
			or visibility_scope not in VISIBILITY_SCOPES \
			or not _display_text(projection.get("title"), false, 160) \
			or not _display_text(projection.get("subtitle"), true, 320) \
			or not (projection.get("navigation_intents") is Array):
		return _invalid("context_detail_projection_identity_invalid")
	if context_kind in [
		KIND_PUBLIC_TRACK,
		KIND_REGION_FACILITY,
		KIND_COMMODITY_SOURCE,
	] and visibility_scope != "public":
		return _invalid("context_detail_projection_public_scope_invalid")
	if context_kind in [KIND_NORMAL_CARD, KIND_COMMODITY_CARD] \
			and visibility_scope != "viewer_private":
		return _invalid("context_detail_projection_private_card_scope_invalid")
	if WIRE.contains_key_recursive(projection, FORBIDDEN_KEYS):
		return _invalid("context_detail_projection_forbidden_field")
	var content_error := _content_error(context_kind, projection.get("content"))
	if not content_error.is_empty():
		return _invalid(content_error)
	for intent_variant in projection.get("navigation_intents") as Array:
		var navigation_error := _navigation_intent_error(intent_variant)
		if not navigation_error.is_empty():
			return _invalid(navigation_error)
	if not WIRE.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
			!= WIRE.fingerprint(projection, "projection_fingerprint"):
		return _invalid("context_detail_projection_fingerprint_invalid")
	return WIRE.valid_result()


static func _content_error(context_kind: String, value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "context_detail_projection_content_not_closed"
	match context_kind:
		KIND_NORMAL_CARD:
			return _normal_card_error(value as Dictionary)
		KIND_COMMODITY_CARD:
			return _commodity_card_error(value as Dictionary)
		KIND_PUBLIC_TRACK:
			return _public_track_card_error(value as Dictionary)
		KIND_REGION_FACILITY:
			return _region_facility_error(value as Dictionary)
		KIND_COMMODITY_SOURCE:
			return _public_commodity_source_error(value as Dictionary)
		KIND_PUBLIC_EVENT:
			return _public_event_error(value as Dictionary)
	return "context_detail_projection_context_kind_invalid"


static func _normal_card_error(content: Dictionary) -> String:
	if not WIRE.exact_fields(content, NORMAL_CARD_CONTENT_FIELDS) \
			or not WIRE.is_stable_id(content.get("card_instance_id")) \
			or not WIRE.is_stable_id(content.get("card_semantic_id")) \
			or not _display_text(content.get("display_name"), false, 160) \
			or not _display_text(content.get("illustration_key"), false, 160) \
			or not _display_text(content.get("timing_text"), true, 1000) \
			or not _display_text(content.get("target_text"), true, 1000) \
			or not _display_text(content.get("effect_text"), true, 4000) \
			or not _display_text(content.get("duration_text"), true, 1000) \
			or not _display_text(content.get("visibility_text"), true, 1000) \
			or WIRE.stable_id_array_error(content.get("keyword_tokens"), true, false) != "" \
			or not WIRE.is_stable_id(content.get("disabled_reason_id")) \
			or not _display_text(content.get("disabled_reason_text"), true, 1000):
		return "context_detail_projection_normal_card_invalid"
	return ""


static func _commodity_card_error(content: Dictionary) -> String:
	if not WIRE.exact_fields(content, COMMODITY_CARD_CONTENT_FIELDS) \
			or not WIRE.is_stable_id(content.get("commodity_card_instance_id")) \
			or not WIRE.is_stable_id(content.get("card_semantic_id")) \
			or not WIRE.is_stable_id(content.get("commodity_id")) \
			or not _display_text(content.get("display_name"), false, 160) \
			or not _display_text(content.get("illustration_key"), false, 160) \
			or not WIRE.is_positive_integer(content.get("level")) \
			or not WIRE.is_positive_integer(content.get("base_units")) \
			or not _display_text(content.get("target_text"), true, 1000) \
			or not _display_text(content.get("effect_text"), true, 4000) \
			or not _display_text(content.get("source_text"), true, 1000) \
			or not WIRE.is_stable_id(content.get("disabled_reason_id")) \
			or not _display_text(content.get("disabled_reason_text"), true, 1000):
		return "context_detail_projection_commodity_card_invalid"
	return ""


static func _public_track_card_error(content: Dictionary) -> String:
	if not WIRE.exact_fields(content, PUBLIC_TRACK_CARD_CONTENT_FIELDS) \
			or not WIRE.is_stable_id(content.get("resolution_id")) \
			or not WIRE.is_stable_id(content.get("card_semantic_id")) \
			or not _display_text(content.get("display_name"), false, 160) \
			or not _display_text(content.get("illustration_key"), false, 160) \
			or not WIRE.is_stable_id(content.get("public_status")) \
			or not _display_text(content.get("summary"), true, 1000) \
			or not _display_text(content.get("detail"), true, 4000) \
			or WIRE.stable_id_array_error(content.get("keyword_tokens"), true, false) != "":
		return "context_detail_projection_public_track_card_invalid"
	return ""


static func _region_facility_error(content: Dictionary) -> String:
	if not WIRE.exact_fields(content, REGION_FACILITY_CONTENT_FIELDS) \
			or not WIRE.is_stable_id(content.get("facility_id")) \
			or not WIRE.is_stable_id(content.get("region_id")) \
			or not _display_text(content.get("display_name"), false, 160) \
			or not _display_text(content.get("illustration_key"), false, 160) \
			or not WIRE.is_stable_id(content.get("public_status")) \
			or not _display_text(content.get("summary"), true, 1000) \
			or not _display_text(content.get("detail"), true, 4000):
		return "context_detail_projection_region_facility_invalid"
	return ""


static func _public_commodity_source_error(content: Dictionary) -> String:
	if not WIRE.exact_fields(content, PUBLIC_COMMODITY_SOURCE_CONTENT_FIELDS) \
			or not WIRE.is_stable_id(content.get("source_id")) \
			or not WIRE.is_stable_id(content.get("commodity_id")) \
			or not _display_text(content.get("display_name"), false, 160) \
			or not _display_text(content.get("illustration_key"), false, 160) \
			or not WIRE.is_stable_id(content.get("public_status")) \
			or not _display_text(content.get("summary"), true, 1000) \
			or not _display_text(content.get("detail"), true, 4000):
		return "context_detail_projection_public_commodity_source_invalid"
	return ""


static func _public_event_error(content: Dictionary) -> String:
	if not WIRE.exact_fields(content, PUBLIC_EVENT_CONTENT_FIELDS) \
			or not WIRE.is_stable_id(content.get("receipt_id")) \
			or not WIRE.is_stable_id(content.get("reason_id")) \
			or not WIRE.is_stable_id(content.get("message_token")) \
			or not _display_text(content.get("summary"), true, 1000) \
			or not _display_text(content.get("detail"), true, 4000):
		return "context_detail_projection_public_event_invalid"
	var arguments_error := _arguments_error(content.get("arguments"))
	if not arguments_error.is_empty():
		return "context_detail_projection_public_event_%s" % arguments_error
	var history_error := _history_link_error(content.get("history_link"))
	return "context_detail_projection_public_event_%s" % history_error \
		if not history_error.is_empty() else ""


static func _history_link_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "history_link_not_closed"
	var link := value as Dictionary
	if link.is_empty():
		return ""
	if not WIRE.exact_fields(link, HISTORY_LINK_FIELDS) \
			or not WIRE.is_stable_id(link.get("link_id")) \
			or not _display_text(link.get("label"), false, 160):
		return "history_link_invalid"
	var navigation_error := _navigation_intent_error(link.get("navigation_intent"))
	return "history_%s" % navigation_error if not navigation_error.is_empty() else ""


static func _navigation_intent_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "context_detail_projection_navigation_not_closed"
	var data := value as Dictionary
	if WIRE.exact_fields(data, TABLE_NAVIGATION_FIELDS):
		var intent := TABLE_NAVIGATION.from_dictionary(data)
		return "" if intent != null \
			and bool(intent.validation_report().get("valid", false)) \
			else "context_detail_projection_table_navigation_invalid"
	if WIRE.exact_fields(data, INTEL_NAVIGATION_FIELDS):
		return "" if INTEL_NAVIGATION.from_dictionary(data) != null \
			else "context_detail_projection_intel_navigation_invalid"
	return "context_detail_projection_navigation_fields_invalid"


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
