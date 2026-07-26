extends RefCounted
class_name PlayerPresentationDTO

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const BUILD_FIELDS := [
	"schema_version",
	"presentation_id",
	"domain_id",
	"semantic_ref",
	"surface_id",
	"locale_id",
	"viewer_scope_id",
	"title_message_token",
	"subtitle_message_token",
	"cost_rows",
	"sections",
	"keywords",
	"art_asset_id",
	"icon_id",
	"color_token_id",
	"visibility_receipt_ref",
]
const FIELDS := BUILD_FIELDS + ["dto_fingerprint"]
const MESSAGE_TOKEN_FIELDS := ["schema_version", "message_id", "arguments"]
const COST_ROW_FIELDS := [
	"schema_version", "cost_kind_id", "emphasis_id", "amounts", "message_token",
]
const SECTION_FIELDS := [
	"schema_version",
	"section_id",
	"sequence_index",
	"message_tokens",
	"keyword_ids",
	"icon_id",
	"color_token_id",
]
const KEYWORD_FIELDS := [
	"schema_version",
	"keyword_id",
	"name_message_id",
	"tooltip_message_id",
	"icon_id",
	"color_token_id",
]
const SECTION_IDS := [
	"timing", "target", "condition", "effect", "duration", "response", "information",
]
const FORBIDDEN_KEYS := [
	"raw_skill",
	"effect_payload",
	"runtime_handler",
	"legality_inference",
	"ai_analysis",
	"cost",
	"price",
	"play_cost",
	"effect",
	"text",
	"description",
	"type",
	"category",
]


static func build(
	unsealed: Dictionary,
	message_schemas: Dictionary,
	cost_schemas: Dictionary
) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "dto_fingerprint")
	var report := validate(sealed, message_schemas, cost_schemas)
	return sealed if bool(report.get("valid", false)) else {}


static func validate(
	value: Variant,
	message_schemas: Dictionary,
	cost_schemas: Dictionary
) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("player_presentation.not_closed_data")
	if WIRE.contains_key_recursive(value, FORBIDDEN_KEYS):
		return WIRE.invalid_result("player_presentation.forbidden_rule_or_alias_field")
	var dto := value as Dictionary
	if not WIRE.exact_fields(dto, FIELDS):
		return WIRE.invalid_result("player_presentation.fields_invalid")
	if dto.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("player_presentation.schema_version_invalid")
	for field in [
		"presentation_id",
		"surface_id",
		"locale_id",
		"viewer_scope_id",
		"art_asset_id",
		"icon_id",
		"color_token_id",
		"visibility_receipt_ref",
	]:
		if not WIRE.is_stable_id(dto.get(field)):
			return WIRE.invalid_result("player_presentation.%s_invalid" % field)
	if not WIRE.DOMAIN_IDS.has(str(dto.get("domain_id", ""))):
		return WIRE.invalid_result("player_presentation.domain_id_unknown")
	var nested_error := WIRE.semantic_definition_ref_error(dto.get("semantic_ref"))
	if not nested_error.is_empty():
		return WIRE.invalid_result("player_presentation.%s" % nested_error)
	for field in ["title_message_token", "subtitle_message_token"]:
		nested_error = _message_token_error(dto.get(field), message_schemas)
		if not nested_error.is_empty():
			return WIRE.invalid_result("player_presentation.%s_%s" % [field, nested_error])
	var costs_error := _cost_rows_error(dto.get("cost_rows"), message_schemas, cost_schemas)
	if not costs_error.is_empty():
		return WIRE.invalid_result("player_presentation.%s" % costs_error)
	var sections_error := _sections_error(dto.get("sections"), message_schemas)
	if not sections_error.is_empty():
		return WIRE.invalid_result("player_presentation.%s" % sections_error)
	var keywords_error := _keywords_error(dto.get("keywords"), message_schemas)
	if not keywords_error.is_empty():
		return WIRE.invalid_result("player_presentation.%s" % keywords_error)
	if not WIRE.is_fingerprint(dto.get("dto_fingerprint")) \
			or str(dto.get("dto_fingerprint", "")) != WIRE.fingerprint(dto, "dto_fingerprint"):
		return WIRE.invalid_result("player_presentation.fingerprint_invalid")
	return WIRE.valid_result()


static func _message_token_error(value: Variant, message_schemas: Dictionary) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "message_token_not_closed_data"
	var token := value as Dictionary
	if not WIRE.exact_fields(token, MESSAGE_TOKEN_FIELDS):
		return "message_token_fields_invalid"
	if token.get("schema_version") != SCHEMA_VERSION \
			or not WIRE.is_stable_id(token.get("message_id")):
		return "message_token_identity_invalid"
	var payload_error := WIRE.closed_payload_error(
		token.get("arguments"), str(token.get("message_id", "")), message_schemas
	)
	return "message_token_%s" % payload_error if not payload_error.is_empty() else ""


static func _cost_rows_error(
	value: Variant,
	message_schemas: Dictionary,
	cost_schemas: Dictionary
) -> String:
	if not (value is Array):
		return "cost_rows_not_array"
	var cost_kind_ids: Array[String] = []
	for row_variant in value as Array:
		if not (row_variant is Dictionary) or not WIRE.is_closed_data(row_variant):
			return "cost_row_not_closed_data"
		var row := row_variant as Dictionary
		if not WIRE.exact_fields(row, COST_ROW_FIELDS):
			return "cost_row_fields_invalid"
		if row.get("schema_version") != SCHEMA_VERSION:
			return "cost_row_schema_version_invalid"
		for field in ["cost_kind_id", "emphasis_id"]:
			if not WIRE.is_stable_id(row.get(field)):
				return "cost_row_%s_invalid" % field
		var cost_kind_id := str(row.get("cost_kind_id", ""))
		if cost_kind_ids.has(cost_kind_id):
			return "cost_row_duplicate"
		cost_kind_ids.append(cost_kind_id)
		var payload_error := WIRE.closed_payload_error(
			row.get("amounts"), cost_kind_id, cost_schemas
		)
		if not payload_error.is_empty():
			return "cost_row_%s" % payload_error
		var token_error := _message_token_error(row.get("message_token"), message_schemas)
		if not token_error.is_empty():
			return "cost_row_%s" % token_error
	return ""

static func _sections_error(value: Variant, message_schemas: Dictionary) -> String:
	if not (value is Array):
		return "sections_not_array"
	var section_ids: Array[String] = []
	for index in range((value as Array).size()):
		var section_variant: Variant = (value as Array)[index]
		if not (section_variant is Dictionary) or not WIRE.is_closed_data(section_variant):
			return "section_not_closed_data"
		var section := section_variant as Dictionary
		if not WIRE.exact_fields(section, SECTION_FIELDS):
			return "section_fields_invalid"
		if section.get("schema_version") != SCHEMA_VERSION \
				or section.get("sequence_index") != index:
			return "section_schema_or_sequence_invalid"
		var section_id := str(section.get("section_id", ""))
		if not SECTION_IDS.has(section_id) or section_ids.has(section_id):
			return "section_id_invalid_or_duplicate"
		section_ids.append(section_id)
		for field in ["icon_id", "color_token_id"]:
			if not WIRE.is_stable_id(section.get(field)):
				return "section_%s_invalid" % field
		if WIRE.stable_id_array_error(section.get("keyword_ids"), true) != "":
			return "section_keyword_ids_invalid"
		if not (section.get("message_tokens") is Array):
			return "section_message_tokens_not_array"
		for token_variant in section.get("message_tokens") as Array:
			var token_error := _message_token_error(token_variant, message_schemas)
			if not token_error.is_empty():
				return "section_%s" % token_error
	return ""


static func _keywords_error(value: Variant, message_schemas: Dictionary) -> String:
	if not (value is Array):
		return "keywords_not_array"
	var keyword_ids: Array[String] = []
	for keyword_variant in value as Array:
		if not (keyword_variant is Dictionary) or not WIRE.is_closed_data(keyword_variant):
			return "keyword_not_closed_data"
		var keyword := keyword_variant as Dictionary
		if not WIRE.exact_fields(keyword, KEYWORD_FIELDS):
			return "keyword_fields_invalid"
		if keyword.get("schema_version") != SCHEMA_VERSION:
			return "keyword_schema_version_invalid"
		for field in [
			"keyword_id", "name_message_id", "tooltip_message_id", "icon_id", "color_token_id",
		]:
			if not WIRE.is_stable_id(keyword.get(field)):
				return "keyword_%s_invalid" % field
		var keyword_id := str(keyword.get("keyword_id", ""))
		if keyword_ids.has(keyword_id):
			return "keyword_duplicate"
		keyword_ids.append(keyword_id)
		for message_field in ["name_message_id", "tooltip_message_id"]:
			var message_id := str(keyword.get(message_field, ""))
			if not message_schemas.has(message_id):
				return "keyword_message_schema_unknown"
	return ""
