@tool
extends RefCounted
class_name AuthorizedCardPlayerFaceLocalizationSourceV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const SOURCE_OWNER_ID := "card_player_face_public_localization_source"
const VISIBILITY_SCOPE_ID := "public_codex"
const LEGACY_PROJECTION_SCOPE_ID := "public"
const LOCALE_ID := "zh_hans"
const ACCEPTED_REASON_ID := "card_player_face_public_localization.accepted"
const VERIFIED_REASON_ID := "card_player_face_public_localization.verified"

const ISSUE_RESULT_FIELDS := [
	"accepted",
	"reason_id",
	"localization_source",
	"authorization_receipt",
	"bundle_fingerprint",
]
const LOCALIZATION_SOURCE_BUILD_FIELDS := [
	"schema_version",
	"source_binding",
	"semantic_binding",
	"structural_message_ids",
	"authored_message_ids",
	"target_message_rows",
	"condition_message_rows",
	"effect_step_message_rows",
	"keyword_rows",
	"authored_keyword_rows",
	"taxonomy",
	"presentation_tokens",
]
const LOCALIZATION_SOURCE_FIELDS := LOCALIZATION_SOURCE_BUILD_FIELDS + [
	"source_manifest_fingerprint",
]
const SOURCE_BINDING_FIELDS := [
	"source_id",
	"source_revision",
	"source_catalog_id",
	"source_catalog_fingerprint",
	"source_record_fingerprint",
	"card_id",
	"family_id",
	"rank",
	"locale_id",
	"visibility_scope_id",
]
const SEMANTIC_BINDING_FIELDS := [
	"semantic_schema_version",
	"source_definition_fingerprint",
	"semantic_fingerprint",
]
const STRUCTURAL_MESSAGE_FIELDS := [
	"name",
	"family_name",
	"acquisition_cost",
	"activation_cost",
	"timing",
	"duration",
	"counterability",
	"information_scope",
]
const AUTHORED_MESSAGE_FIELDS := [
	"name",
	"family_name",
	"rank_label",
	"category_label",
	"industry_label",
	"authored_cost_summary",
	"timing_summary",
	"target_summary",
	"short_effect_summary",
	"effect_detail",
	"duration_summary",
	"information_scope_summary",
	"next_step_summary",
]
const TARGET_MESSAGE_ROW_FIELDS := ["target_id", "message_id"]
const CONDITION_MESSAGE_ROW_FIELDS := ["condition_id", "message_id"]
const EFFECT_MESSAGE_ROW_FIELDS := [
	"order",
	"op_id",
	"summary_message_id",
	"detail_message_id",
]
const KEYWORD_ROW_FIELDS := [
	"keyword_id",
	"label_message_id",
	"tooltip_message_id",
	"icon_token_id",
	"color_token_id",
]
const AUTHORED_KEYWORD_ROW_FIELDS := [
	"keyword_id",
	"label_message_id",
	"tooltip_message_id",
]
const TAXONOMY_FIELDS := [
	"category_id",
	"industry_id",
	"category_label_ref",
	"industry_label_ref",
]
const PRESENTATION_TOKEN_FIELDS := [
	"category_icon_token_id",
	"category_color_token_id",
	"industry_color_token_id",
	"illustration_key",
	"fallback_illustration_token_id",
]
const RECEIPT_BUILD_FIELDS := [
	"schema_version",
	"receipt_id",
	"owner_id",
	"visibility_scope_id",
	"source_id",
	"source_revision",
	"source_fingerprint",
	"semantic_fingerprint",
]
const RECEIPT_FIELDS := RECEIPT_BUILD_FIELDS + ["receipt_fingerprint"]

const VERIFIED_REPORT_FIELDS := [
	"accepted",
	"reason_id",
	"projection_source",
	"localization_binding",
	"taxonomy",
	"presentation_tokens",
	"presentation_copy",
	"authorization_receipt",
	"bundle_fingerprint",
]
const LOCALIZATION_BINDING_FIELDS := [
	"source_id",
	"source_revision",
	"source_fingerprint",
	"semantic_fingerprint",
]
const LEGACY_PROJECTION_SOURCE_FIELDS := [
	"schema_version",
	"source_id",
	"card_id",
	"semantic_fingerprint",
	"authorization_scope_id",
	"authorization_revision",
	"authorized",
	"message_ids",
	"target_message_rows",
	"condition_message_rows",
	"effect_step_message_rows",
	"keyword_rows",
]
const PRESENTATION_COPY_FIELDS := [
	"name",
	"family_name",
	"category_label",
	"industry_label",
	"acquisition_cost",
	"activation_cost",
	"timing",
	"targets",
	"conditions",
	"effect_steps",
	"duration",
	"counterability",
	"information_scope",
	"keywords",
	"short_effect",
	"full_effect",
]
const PRESENTATION_COPY_TEXT_FIELDS := [
	"name",
	"family_name",
	"category_label",
	"industry_label",
	"acquisition_cost",
	"activation_cost",
	"timing",
	"duration",
	"counterability",
	"information_scope",
	"short_effect",
	"full_effect",
]
const PRESENTATION_COPY_ARRAY_FIELDS := [
	"targets",
	"conditions",
	"effect_steps",
	"keywords",
]

const FORBIDDEN_VALUE_CHANNEL_KEYS := [
	"owner",
	"hidden_owner",
	"true_owner",
	"player_index",
	"hand",
	"opponent_hand",
	"exact_cash",
	"private_plan",
	"ai_score",
	"ai_value",
	"route_plan",
	"future_bag",
	"rng_state",
	"save_payload",
	"developer",
	"effect_payload",
	"method_name",
	"script_path",
]


static func seal_localization_source(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, LOCALIZATION_SOURCE_BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "source_manifest_fingerprint")
	return sealed if bool(validate_localization_source(sealed).get("valid", false)) else {}


static func build_receipt(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, RECEIPT_BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "receipt_fingerprint")
	return sealed if bool(validate_receipt(sealed).get("valid", false)) else {}


static func build_issue_result(
	localization_source: Dictionary,
	authorization_receipt: Dictionary
) -> Dictionary:
	if not bool(validate_localization_source(localization_source).get("valid", false)) \
			or not bool(validate_receipt(authorization_receipt).get("valid", false)):
		return {}
	var unsealed := {
		"accepted": true,
		"reason_id": ACCEPTED_REASON_ID,
		"localization_source": localization_source.duplicate(true),
		"authorization_receipt": authorization_receipt.duplicate(true),
	}
	var sealed := WIRE.sealed_copy(unsealed, "bundle_fingerprint")
	return sealed if bool(validate_issue_result(sealed).get("valid", false)) else {}


static func validate_issue_result(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("authorized_player_face_localization.bundle_not_closed_data")
	var bundle := value as Dictionary
	if not WIRE.exact_fields(bundle, ISSUE_RESULT_FIELDS):
		return _invalid("authorized_player_face_localization.bundle_fields_invalid")
	if bundle.get("accepted") != true \
			or str(bundle.get("reason_id", "")) != ACCEPTED_REASON_ID:
		return _invalid("authorized_player_face_localization.bundle_status_invalid")
	var source_report := validate_localization_source(bundle.get("localization_source"))
	if not bool(source_report.get("valid", false)):
		return source_report
	var receipt_report := validate_receipt(bundle.get("authorization_receipt"))
	if not bool(receipt_report.get("valid", false)):
		return receipt_report
	var source := bundle.get("localization_source") as Dictionary
	var source_binding := source.get("source_binding") as Dictionary
	var semantic_binding := source.get("semantic_binding") as Dictionary
	var receipt := bundle.get("authorization_receipt") as Dictionary
	if str(receipt.get("source_id", "")) != str(source_binding.get("source_id", "")) \
			or int(receipt.get("source_revision", 0)) != int(source_binding.get("source_revision", -1)) \
			or str(receipt.get("source_fingerprint", "")) != str(source.get("source_manifest_fingerprint", "")) \
			or str(receipt.get("semantic_fingerprint", "")) != str(semantic_binding.get("semantic_fingerprint", "")):
		return _invalid("authorized_player_face_localization.receipt_binding_mismatch")
	if not WIRE.is_fingerprint(bundle.get("bundle_fingerprint")) \
			or str(bundle.get("bundle_fingerprint", "")) != WIRE.fingerprint(bundle, "bundle_fingerprint"):
		return _invalid("authorized_player_face_localization.bundle_fingerprint_invalid")
	return WIRE.valid_result()


static func validate_localization_source(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("authorized_player_face_localization.source_not_closed_data")
	var source := value as Dictionary
	if not WIRE.exact_fields(source, LOCALIZATION_SOURCE_FIELDS):
		return _invalid("authorized_player_face_localization.source_fields_invalid")
	if source.get("schema_version") != SCHEMA_VERSION:
		return _invalid("authorized_player_face_localization.source_schema_invalid")
	if WIRE.contains_key_recursive(source, FORBIDDEN_VALUE_CHANNEL_KEYS):
		return _invalid("authorized_player_face_localization.value_channel_forbidden")
	var binding_error := _source_binding_error(source.get("source_binding"))
	if not binding_error.is_empty():
		return _invalid(binding_error)
	var semantic_error := _semantic_binding_error(source.get("semantic_binding"))
	if not semantic_error.is_empty():
		return _invalid(semantic_error)
	var message_error := _message_dictionary_error(
		source.get("structural_message_ids"),
		STRUCTURAL_MESSAGE_FIELDS,
		"structural"
	)
	if not message_error.is_empty():
		return _invalid(message_error)
	message_error = _message_dictionary_error(
		source.get("authored_message_ids"),
		AUTHORED_MESSAGE_FIELDS,
		"authored"
	)
	if not message_error.is_empty():
		return _invalid(message_error)
	var rows_error := _target_rows_error(source.get("target_message_rows"))
	if not rows_error.is_empty():
		return _invalid(rows_error)
	rows_error = _condition_rows_error(source.get("condition_message_rows"))
	if not rows_error.is_empty():
		return _invalid(rows_error)
	rows_error = _effect_rows_error(source.get("effect_step_message_rows"))
	if not rows_error.is_empty():
		return _invalid(rows_error)
	rows_error = _keyword_rows_error(source.get("keyword_rows"), KEYWORD_ROW_FIELDS, 16)
	if not rows_error.is_empty():
		return _invalid(rows_error)
	rows_error = _keyword_rows_error(
		source.get("authored_keyword_rows"),
		AUTHORED_KEYWORD_ROW_FIELDS,
		16
	)
	if not rows_error.is_empty():
		return _invalid(rows_error)
	var taxonomy_error := _taxonomy_error(source.get("taxonomy"))
	if not taxonomy_error.is_empty():
		return _invalid(taxonomy_error)
	var token_error := _presentation_tokens_error(source.get("presentation_tokens"))
	if not token_error.is_empty():
		return _invalid(token_error)
	if not WIRE.is_fingerprint(source.get("source_manifest_fingerprint")) \
			or str(source.get("source_manifest_fingerprint", "")) != WIRE.fingerprint(source, "source_manifest_fingerprint"):
		return _invalid("authorized_player_face_localization.source_fingerprint_invalid")
	return WIRE.valid_result()


static func validate_receipt(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("authorized_player_face_localization.receipt_not_closed_data")
	var receipt := value as Dictionary
	if not WIRE.exact_fields(receipt, RECEIPT_FIELDS):
		return _invalid("authorized_player_face_localization.receipt_fields_invalid")
	if receipt.get("schema_version") != SCHEMA_VERSION:
		return _invalid("authorized_player_face_localization.receipt_schema_invalid")
	if not WIRE.is_stable_id(receipt.get("receipt_id")) \
			or str(receipt.get("owner_id", "")) != SOURCE_OWNER_ID \
			or str(receipt.get("visibility_scope_id", "")) != VISIBILITY_SCOPE_ID \
			or not WIRE.is_stable_id(receipt.get("source_id")) \
			or not WIRE.is_positive_integer(receipt.get("source_revision")):
		return _invalid("authorized_player_face_localization.receipt_authority_invalid")
	for field_id in ["source_fingerprint", "semantic_fingerprint", "receipt_fingerprint"]:
		if not WIRE.is_fingerprint(receipt.get(field_id)):
			return _invalid("authorized_player_face_localization.receipt_fingerprint_invalid")
	if str(receipt.get("receipt_fingerprint", "")) != WIRE.fingerprint(receipt, "receipt_fingerprint"):
		return _invalid("authorized_player_face_localization.receipt_fingerprint_mismatch")
	return WIRE.valid_result()


static func build_verified_report(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, VERIFIED_REPORT_FIELDS):
		return {}
	return unsealed.duplicate(true) \
		if bool(validate_verified_report(unsealed).get("valid", false)) else {}


static func validate_verified_report(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return _invalid("authorized_player_face_localization.verified_not_closed_data")
	var report := value as Dictionary
	if not WIRE.exact_fields(report, VERIFIED_REPORT_FIELDS):
		return _invalid("authorized_player_face_localization.verified_fields_invalid")
	if report.get("accepted") != true \
			or str(report.get("reason_id", "")) != VERIFIED_REASON_ID:
		return _invalid("authorized_player_face_localization.verified_status_invalid")
	var projection_error := _legacy_projection_source_error(report.get("projection_source"))
	if not projection_error.is_empty():
		return _invalid(projection_error)
	var binding_error := _localization_binding_error(report.get("localization_binding"))
	if not binding_error.is_empty():
		return _invalid(binding_error)
	var taxonomy_error := _taxonomy_error(report.get("taxonomy"))
	if not taxonomy_error.is_empty():
		return _invalid(taxonomy_error)
	var tokens_error := _presentation_tokens_error(report.get("presentation_tokens"))
	if not tokens_error.is_empty():
		return _invalid(tokens_error)
	var copy_error := _presentation_copy_error(report.get("presentation_copy"))
	if not copy_error.is_empty():
		return _invalid(copy_error)
	var receipt_report := validate_receipt(report.get("authorization_receipt"))
	if not bool(receipt_report.get("valid", false)):
		return receipt_report
	if not WIRE.is_fingerprint(report.get("bundle_fingerprint")):
		return _invalid("authorized_player_face_localization.verified_bundle_fingerprint_invalid")
	var projection := report.get("projection_source") as Dictionary
	var binding := report.get("localization_binding") as Dictionary
	if str(projection.get("source_id", "")) != str(binding.get("source_id", "")) \
			or int(projection.get("authorization_revision", 0)) != int(binding.get("source_revision", -1)) \
			or str(projection.get("semantic_fingerprint", "")) != str(binding.get("semantic_fingerprint", "")):
		return _invalid("authorized_player_face_localization.verified_binding_mismatch")
	var copy := report.get("presentation_copy") as Dictionary
	for field_pair in [
		["target_message_rows", "targets"],
		["condition_message_rows", "conditions"],
		["effect_step_message_rows", "effect_steps"],
		["keyword_rows", "keywords"],
	]:
		if (projection.get(str(field_pair[0]), []) as Array).size() \
				!= (copy.get(str(field_pair[1]), []) as Array).size():
			return _invalid(
				"authorized_player_face_localization.verified_copy_count_mismatch"
			)
	return WIRE.valid_result()


static func _source_binding_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.source_binding_invalid"
	var binding := value as Dictionary
	if not WIRE.exact_fields(binding, SOURCE_BINDING_FIELDS):
		return "authorized_player_face_localization.source_binding_fields_invalid"
	for field_id in ["source_id", "source_catalog_id", "card_id", "family_id", "locale_id"]:
		if not WIRE.is_stable_id(binding.get(field_id)):
			return "authorized_player_face_localization.source_binding_identity_invalid"
	if str(binding.get("locale_id", "")) != LOCALE_ID \
			or str(binding.get("visibility_scope_id", "")) != VISIBILITY_SCOPE_ID:
		return "authorized_player_face_localization.source_binding_scope_invalid"
	if not WIRE.is_positive_integer(binding.get("source_revision")) \
			or not WIRE.is_positive_integer(binding.get("rank")) \
			or int(binding.get("rank", 0)) > 4:
		return "authorized_player_face_localization.source_binding_revision_invalid"
	if str(binding.get("card_id", "")) != "%s.rank_%d" % [
		str(binding.get("family_id", "")),
		int(binding.get("rank", 0)),
	]:
		return "authorized_player_face_localization.source_binding_rank_invalid"
	for field_id in ["source_catalog_fingerprint", "source_record_fingerprint"]:
		if not WIRE.is_fingerprint(binding.get(field_id)):
			return "authorized_player_face_localization.source_binding_fingerprint_invalid"
	return ""


static func _semantic_binding_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.semantic_binding_invalid"
	var binding := value as Dictionary
	if not WIRE.exact_fields(binding, SEMANTIC_BINDING_FIELDS) \
			or binding.get("semantic_schema_version") != SCHEMA_VERSION:
		return "authorized_player_face_localization.semantic_binding_fields_invalid"
	for field_id in ["source_definition_fingerprint", "semantic_fingerprint"]:
		if not WIRE.is_fingerprint(binding.get(field_id)):
			return "authorized_player_face_localization.semantic_binding_fingerprint_invalid"
	return ""


static func _message_dictionary_error(
	value: Variant,
	expected_fields: Array,
	prefix: String
) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.%s_messages_invalid" % prefix
	var messages := value as Dictionary
	if not WIRE.exact_fields(messages, expected_fields):
		return "authorized_player_face_localization.%s_message_fields_invalid" % prefix
	for field_variant in expected_fields:
		if not WIRE.is_stable_id(messages.get(str(field_variant))):
			return "authorized_player_face_localization.%s_message_id_invalid" % prefix
	return ""


static func _target_rows_error(value: Variant) -> String:
	if not (value is Array) or (value as Array).size() != 1:
		return "authorized_player_face_localization.target_rows_invalid"
	var row_variant: Variant = (value as Array)[0]
	if not (row_variant is Dictionary) or not WIRE.is_closed_data(row_variant):
		return "authorized_player_face_localization.target_row_invalid"
	var row := row_variant as Dictionary
	if not WIRE.exact_fields(row, TARGET_MESSAGE_ROW_FIELDS) \
			or not WIRE.is_stable_id(row.get("target_id")) \
			or not WIRE.is_stable_id(row.get("message_id")):
		return "authorized_player_face_localization.target_row_fields_invalid"
	return ""


static func _condition_rows_error(value: Variant) -> String:
	if not (value is Array):
		return "authorized_player_face_localization.condition_rows_invalid"
	var seen: Dictionary = {}
	for row_variant in value as Array:
		if not (row_variant is Dictionary) or not WIRE.is_closed_data(row_variant):
			return "authorized_player_face_localization.condition_row_invalid"
		var row := row_variant as Dictionary
		if not WIRE.exact_fields(row, CONDITION_MESSAGE_ROW_FIELDS) \
				or not WIRE.is_stable_id(row.get("condition_id")) \
				or not WIRE.is_stable_id(row.get("message_id")):
			return "authorized_player_face_localization.condition_row_fields_invalid"
		var condition_id := str(row.get("condition_id", ""))
		if seen.has(condition_id):
			return "authorized_player_face_localization.condition_row_duplicate"
		seen[condition_id] = true
	return ""


static func _effect_rows_error(value: Variant) -> String:
	if not (value is Array) or (value as Array).is_empty():
		return "authorized_player_face_localization.effect_rows_invalid"
	var expected_order := 1
	for row_variant in value as Array:
		if not (row_variant is Dictionary) or not WIRE.is_closed_data(row_variant):
			return "authorized_player_face_localization.effect_row_invalid"
		var row := row_variant as Dictionary
		if not WIRE.exact_fields(row, EFFECT_MESSAGE_ROW_FIELDS) \
				or row.get("order") != expected_order \
				or not WIRE.is_stable_id(row.get("op_id")) \
				or not WIRE.is_stable_id(row.get("summary_message_id")) \
				or not WIRE.is_stable_id(row.get("detail_message_id")):
			return "authorized_player_face_localization.effect_row_fields_invalid"
		expected_order += 1
	return ""


static func _keyword_rows_error(
	value: Variant,
	expected_fields: Array,
	maximum_count: int
) -> String:
	if not (value is Array) or (value as Array).is_empty() \
			or (value as Array).size() > maximum_count:
		return "authorized_player_face_localization.keyword_rows_invalid"
	var seen: Dictionary = {}
	for row_variant in value as Array:
		if not (row_variant is Dictionary) or not WIRE.is_closed_data(row_variant):
			return "authorized_player_face_localization.keyword_row_invalid"
		var row := row_variant as Dictionary
		if not WIRE.exact_fields(row, expected_fields):
			return "authorized_player_face_localization.keyword_row_fields_invalid"
		for field_variant in expected_fields:
			if not WIRE.is_stable_id(row.get(str(field_variant))):
				return "authorized_player_face_localization.keyword_row_identifier_invalid"
		var keyword_id := str(row.get("keyword_id", ""))
		if seen.has(keyword_id):
			return "authorized_player_face_localization.keyword_row_duplicate"
		seen[keyword_id] = true
	return ""


static func _taxonomy_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.taxonomy_invalid"
	var taxonomy := value as Dictionary
	if not WIRE.exact_fields(taxonomy, TAXONOMY_FIELDS):
		return "authorized_player_face_localization.taxonomy_fields_invalid"
	for field_id in TAXONOMY_FIELDS:
		if not WIRE.is_stable_id(taxonomy.get(field_id)):
			return "authorized_player_face_localization.taxonomy_identifier_invalid"
	return ""


static func _presentation_tokens_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.presentation_tokens_invalid"
	var tokens := value as Dictionary
	if not WIRE.exact_fields(tokens, PRESENTATION_TOKEN_FIELDS):
		return "authorized_player_face_localization.presentation_token_fields_invalid"
	for field_id in [
		"category_icon_token_id",
		"category_color_token_id",
		"industry_color_token_id",
		"fallback_illustration_token_id",
	]:
		if not WIRE.is_stable_id(tokens.get(field_id)):
			return "authorized_player_face_localization.presentation_token_invalid"
	if not (tokens.get("illustration_key") is String):
		return "authorized_player_face_localization.illustration_key_invalid"
	var illustration_key := str(tokens.get("illustration_key", ""))
	if not illustration_key.is_empty() and not WIRE.is_stable_id(illustration_key):
		return "authorized_player_face_localization.illustration_key_invalid"
	return ""


static func _legacy_projection_source_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.projection_source_invalid"
	var source := value as Dictionary
	if not WIRE.exact_fields(source, LEGACY_PROJECTION_SOURCE_FIELDS):
		return "authorized_player_face_localization.projection_source_fields_invalid"
	if source.get("schema_version") != SCHEMA_VERSION \
			or source.get("authorized") != true \
			or str(source.get("authorization_scope_id", "")) != LEGACY_PROJECTION_SCOPE_ID \
			or not WIRE.is_positive_integer(source.get("authorization_revision")):
		return "authorized_player_face_localization.projection_source_authority_invalid"
	for field_id in ["source_id", "card_id"]:
		if not WIRE.is_stable_id(source.get(field_id)):
			return "authorized_player_face_localization.projection_source_identity_invalid"
	if not WIRE.is_fingerprint(source.get("semantic_fingerprint")):
		return "authorized_player_face_localization.projection_source_semantic_invalid"
	var message_error := _message_dictionary_error(
		source.get("message_ids"),
		STRUCTURAL_MESSAGE_FIELDS,
		"projection"
	)
	if not message_error.is_empty():
		return message_error
	var rows_error := _target_rows_error(source.get("target_message_rows"))
	if not rows_error.is_empty():
		return rows_error
	rows_error = _condition_rows_error(source.get("condition_message_rows"))
	if not rows_error.is_empty():
		return rows_error
	rows_error = _effect_rows_error(source.get("effect_step_message_rows"))
	if not rows_error.is_empty():
		return rows_error
	return _keyword_rows_error(source.get("keyword_rows"), KEYWORD_ROW_FIELDS, 16)


static func _localization_binding_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.localization_binding_invalid"
	var binding := value as Dictionary
	if not WIRE.exact_fields(binding, LOCALIZATION_BINDING_FIELDS) \
			or not WIRE.is_stable_id(binding.get("source_id")) \
			or not WIRE.is_positive_integer(binding.get("source_revision")):
		return "authorized_player_face_localization.localization_binding_fields_invalid"
	for field_id in ["source_fingerprint", "semantic_fingerprint"]:
		if not WIRE.is_fingerprint(binding.get(field_id)):
			return "authorized_player_face_localization.localization_binding_fingerprint_invalid"
	return ""


static func _presentation_copy_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "authorized_player_face_localization.presentation_copy_invalid"
	var copy := value as Dictionary
	if not WIRE.exact_fields(copy, PRESENTATION_COPY_FIELDS):
		return "authorized_player_face_localization.presentation_copy_fields_invalid"
	for field_id in PRESENTATION_COPY_TEXT_FIELDS:
		if not (copy.get(field_id) is String) or str(copy.get(field_id, "")).strip_edges().is_empty():
			return "authorized_player_face_localization.presentation_copy_text_invalid"
	for field_id in PRESENTATION_COPY_ARRAY_FIELDS:
		var rows_value: Variant = copy.get(field_id)
		if not (rows_value is Array):
			return "authorized_player_face_localization.presentation_copy_array_invalid"
		for row_variant in rows_value as Array:
			if not (row_variant is String) \
					or str(row_variant).strip_edges().is_empty():
				return "authorized_player_face_localization.presentation_copy_array_item_invalid"
	return ""


static func _invalid(reason_id: String) -> Dictionary:
	return WIRE.invalid_result(reason_id)
