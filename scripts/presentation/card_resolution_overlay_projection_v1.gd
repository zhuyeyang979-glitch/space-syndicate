extends RefCounted
class_name CardResolutionOverlayProjectionV1

const SCHEMA_VERSION := 1
const MODE_V06_LEGACY := "V06_LEGACY_RESOLUTION"
const MODE_V07_UNINTERRUPTED := "V07_UNINTERRUPTED_BATCH"
const MODES := [MODE_V06_LEGACY, MODE_V07_UNINTERRUPTED]
const PHASE_IDS := ["idle", "planning", "public_bid", "lock", "counter", "reveal", "resolving", "aftermath"]
const GAMEPLAY_INPUT_MODES := ["NONE", "V06_COUNTER_RESPONSE"]
const FIELDS := [
	"schema_version",
	"resolution_runtime_mode",
	"source_revision",
	"visible",
	"phase_id",
	"resolution_id",
	"remaining_milliseconds",
	"title",
	"status_text",
	"body_text",
	"card_kind",
	"card_tags",
	"accent_hex",
	"rank",
	"art_stats",
	"illustration_key",
	"badge_labels",
	"counter_response_visible",
	"gameplay_input_mode",
	"visibility_scope",
	"projection_fingerprint",
]
const UNSEALED_FIELDS := [
	"schema_version",
	"resolution_runtime_mode",
	"source_revision",
	"visible",
	"phase_id",
	"resolution_id",
	"remaining_milliseconds",
	"title",
	"status_text",
	"body_text",
	"card_kind",
	"card_tags",
	"accent_hex",
	"rank",
	"art_stats",
	"illustration_key",
	"badge_labels",
	"counter_response_visible",
	"gameplay_input_mode",
	"visibility_scope",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not SemanticWireV1.is_closed_data(unsealed) \
			or not SemanticWireV1.exact_fields(unsealed, UNSEALED_FIELDS):
		return {}
	var sealed := SemanticWireV1.sealed_copy(unsealed, "projection_fingerprint")
	return sealed if bool(validation_report(sealed).get("valid", false)) else {}


static func validation_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not SemanticWireV1.is_closed_data(value):
		return SemanticWireV1.invalid_result("card_resolution_overlay_not_closed_data")
	var projection := value as Dictionary
	if not SemanticWireV1.exact_fields(projection, FIELDS):
		return SemanticWireV1.invalid_result("card_resolution_overlay_fields_invalid")
	if projection.get("schema_version") != SCHEMA_VERSION \
			or str(projection.get("resolution_runtime_mode", "")) not in MODES \
			or not SemanticWireV1.is_nonnegative_integer(projection.get("source_revision")) \
			or not (projection.get("visible") is bool) \
			or str(projection.get("phase_id", "")) not in PHASE_IDS \
			or not (projection.get("resolution_id") is int) \
			or int(projection.get("resolution_id", -2)) < -1 \
			or not SemanticWireV1.is_nonnegative_integer(projection.get("remaining_milliseconds")) \
			or not (projection.get("rank") is int) \
			or int(projection.get("rank", 0)) < 0 \
			or int(projection.get("rank", 0)) > 4 \
			or not (projection.get("counter_response_visible") is bool) \
			or str(projection.get("gameplay_input_mode", "")) not in GAMEPLAY_INPUT_MODES \
			or str(projection.get("visibility_scope", "")) != "public":
		return SemanticWireV1.invalid_result("card_resolution_overlay_shape_invalid")
	for field in ["title", "status_text", "body_text", "card_kind", "card_tags", "accent_hex", "art_stats", "illustration_key"]:
		if not (projection.get(field) is String):
			return SemanticWireV1.invalid_result("card_resolution_overlay_text_invalid")
	if not Color.html_is_valid(str(projection.get("accent_hex", ""))):
		return SemanticWireV1.invalid_result("card_resolution_overlay_accent_invalid")
	if not (projection.get("badge_labels") is Array):
		return SemanticWireV1.invalid_result("card_resolution_overlay_badges_invalid")
	for badge_variant in projection.get("badge_labels", []) as Array:
		if not (badge_variant is String) or str(badge_variant).strip_edges().is_empty():
			return SemanticWireV1.invalid_result("card_resolution_overlay_badge_invalid")
	var mode := str(projection.get("resolution_runtime_mode", ""))
	var phase := str(projection.get("phase_id", ""))
	var counter_visible := bool(projection.get("counter_response_visible", false))
	var input_mode := str(projection.get("gameplay_input_mode", "NONE"))
	if counter_visible != (mode == MODE_V06_LEGACY and phase == "counter") \
			or (counter_visible and input_mode != "V06_COUNTER_RESPONSE") \
			or (not counter_visible and input_mode != "NONE"):
		return SemanticWireV1.invalid_result("card_resolution_overlay_mode_phase_mismatch")
	if not bool(projection.get("visible", false)) \
			and (phase != "idle" or int(projection.get("resolution_id", -1)) != -1 \
				or int(projection.get("remaining_milliseconds", 0)) != 0):
		return SemanticWireV1.invalid_result("card_resolution_overlay_closed_state_invalid")
	if not SemanticWireV1.is_fingerprint(projection.get("projection_fingerprint")) \
			or str(projection.get("projection_fingerprint", "")) \
				!= SemanticWireV1.fingerprint(projection, "projection_fingerprint"):
		return SemanticWireV1.invalid_result("card_resolution_overlay_fingerprint_invalid")
	return SemanticWireV1.valid_result()


static func detached_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) \
		if bool(validation_report(value).get("valid", false)) else {}
