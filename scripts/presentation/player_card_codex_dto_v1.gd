extends RefCounted
class_name PlayerCardCodexDTOv1

const PLAYER_FACE_DTO := preload("res://scripts/presentation/player_face_dto_v1.gd")

const SCHEMA_VERSION := 1
const PROJECTION_ID := "card_codex.public"

const ROOT_FIELDS := [
	"schema_version",
	"projection_id",
	"semantic_binding",
	"localization_binding",
	"detail_face",
	"taxonomy",
	"presentation_tokens",
	"presentation_copy",
	"dto_fingerprint",
]
const UNSEALED_ROOT_FIELDS := [
	"schema_version",
	"projection_id",
	"semantic_binding",
	"localization_binding",
	"detail_face",
	"taxonomy",
	"presentation_tokens",
	"presentation_copy",
]
const SEMANTIC_BINDING_FIELDS := [
	"source_catalog_id",
	"source_definition_fingerprint",
	"semantic_fingerprint",
]
const LOCALIZATION_BINDING_FIELDS := [
	"source_id",
	"source_revision",
	"source_fingerprint",
	"semantic_fingerprint",
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
const PRESENTATION_TEXT_FIELDS := [
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
const PRESENTATION_ARRAY_FIELDS := [
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
	"rival_hand",
	"opponent_hand",
	"exact_cash",
	"private_plan",
	"ai_score",
	"ai_value",
	"route_plan",
	"future_bag",
	"rng_state",
	"save_payload",
	"machine",
	"player",
	"developer",
	"effect_payload",
	"skill",
	"method_name",
	"script_path",
]


static func seal(unsealed_dto: Dictionary) -> Dictionary:
	if not PLAYER_FACE_DTO.is_detached_pure_data(unsealed_dto) \
			or not _has_exact_fields(unsealed_dto, UNSEALED_ROOT_FIELDS):
		return {}
	var dto := unsealed_dto.duplicate(true)
	dto["dto_fingerprint"] = fingerprint_value(dto)
	return dto if bool(validate(dto).get("valid", false)) else {}


static func seal_catalog_owned(unsealed_dto: Dictionary) -> Dictionary:
	if not PLAYER_FACE_DTO.is_detached_pure_data(unsealed_dto) \
			or not _has_exact_fields(unsealed_dto, UNSEALED_ROOT_FIELDS) \
			or _contains_forbidden_key(unsealed_dto) \
			or unsealed_dto.get("schema_version") != SCHEMA_VERSION \
			or str(unsealed_dto.get("projection_id", "")) != PROJECTION_ID:
		return {}
	if not _semantic_binding_error(unsealed_dto.get(
		"semantic_binding"
	)).is_empty() or not _localization_binding_error(unsealed_dto.get(
		"localization_binding"
	)).is_empty():
		return {}
	var semantic_binding := unsealed_dto.get("semantic_binding") as Dictionary
	var localization_binding := unsealed_dto.get("localization_binding") as Dictionary
	if str(semantic_binding.get("semantic_fingerprint", "")) \
			!= str(localization_binding.get("semantic_fingerprint", "")):
		return {}
	var detail_value: Variant = unsealed_dto.get("detail_face")
	if not (detail_value is Dictionary):
		return {}
	var detail_face := detail_value as Dictionary
	if not bool(PLAYER_FACE_DTO.validate(detail_face).get("valid", false)) \
			or str(detail_face.get("surface_id", "")) != "detail":
		return {}
	if not _taxonomy_error(unsealed_dto.get("taxonomy")).is_empty() \
			or not _presentation_tokens_error(unsealed_dto.get(
				"presentation_tokens"
			)).is_empty() \
			or not _presentation_copy_error(
				unsealed_dto.get("presentation_copy"),
				detail_face
			).is_empty():
		return {}
	var dto := unsealed_dto.duplicate(true)
	dto["dto_fingerprint"] = fingerprint_value(dto)
	return dto if PLAYER_FACE_DTO.is_fingerprint(str(dto.get(
		"dto_fingerprint",
		""
	))) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) \
			or not PLAYER_FACE_DTO.is_detached_pure_data(value):
		return _invalid("player_card_codex_dto.not_detached_pure_data")
	var dto := value as Dictionary
	if _contains_forbidden_key(dto):
		return _invalid("player_card_codex_dto.forbidden_value_channel")
	if not _has_exact_fields(dto, ROOT_FIELDS):
		return _invalid("player_card_codex_dto.root_fields_invalid")
	if dto.get("schema_version") != SCHEMA_VERSION:
		return _invalid("player_card_codex_dto.schema_version_invalid")
	if str(dto.get("projection_id", "")) != PROJECTION_ID:
		return _invalid("player_card_codex_dto.projection_id_invalid")

	var semantic_binding_error := _semantic_binding_error(
		dto.get("semantic_binding")
	)
	if not semantic_binding_error.is_empty():
		return _invalid(semantic_binding_error)
	var localization_binding_error := _localization_binding_error(
		dto.get("localization_binding")
	)
	if not localization_binding_error.is_empty():
		return _invalid(localization_binding_error)
	var semantic_binding := dto.get("semantic_binding") as Dictionary
	var localization_binding := dto.get("localization_binding") as Dictionary
	if str(semantic_binding.get("semantic_fingerprint", "")) \
			!= str(localization_binding.get("semantic_fingerprint", "")):
		return _invalid("player_card_codex_dto.semantic_binding_mismatch")

	var detail_face_value: Variant = dto.get("detail_face")
	if not (detail_face_value is Dictionary):
		return _invalid("player_card_codex_dto.detail_face_invalid")
	var detail_face := detail_face_value as Dictionary
	var detail_report := PLAYER_FACE_DTO.validate(detail_face)
	if not bool(detail_report.get("valid", false)):
		return _invalid("player_card_codex_dto.detail_face_invalid")
	if str(detail_face.get("surface_id", "")) != "detail":
		return _invalid("player_card_codex_dto.detail_surface_invalid")

	var taxonomy_error := _taxonomy_error(dto.get("taxonomy"))
	if not taxonomy_error.is_empty():
		return _invalid(taxonomy_error)
	var token_error := _presentation_tokens_error(
		dto.get("presentation_tokens")
	)
	if not token_error.is_empty():
		return _invalid(token_error)
	var copy_error := _presentation_copy_error(
		dto.get("presentation_copy"), detail_face
	)
	if not copy_error.is_empty():
		return _invalid(copy_error)

	var fingerprint := str(dto.get("dto_fingerprint", ""))
	if not PLAYER_FACE_DTO.is_fingerprint(fingerprint) \
			or fingerprint != fingerprint_value(dto, "dto_fingerprint"):
		return _invalid("player_card_codex_dto.fingerprint_invalid")
	return {
		"valid": true,
		"reason_id": "player_card_codex_dto.valid",
	}


static func fingerprint_value(value: Variant, omitted_field := "") -> String:
	if not PLAYER_FACE_DTO.is_detached_pure_data(value):
		return ""
	var fingerprint_input: Variant = value.duplicate(true) \
		if value is Dictionary or value is Array else value
	if not omitted_field.is_empty() and fingerprint_input is Dictionary:
		(fingerprint_input as Dictionary).erase(omitted_field)
	return PLAYER_FACE_DTO.fingerprint_value(fingerprint_input)


static func _semantic_binding_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "player_card_codex_dto.semantic_binding_invalid"
	var binding := value as Dictionary
	if not _has_exact_fields(binding, SEMANTIC_BINDING_FIELDS):
		return "player_card_codex_dto.semantic_binding_fields_invalid"
	if not _is_stable_id(binding.get("source_catalog_id")):
		return "player_card_codex_dto.source_catalog_id_invalid"
	for field in [
		"source_definition_fingerprint",
		"semantic_fingerprint",
	]:
		if not PLAYER_FACE_DTO.is_fingerprint(str(binding.get(field, ""))):
			return "player_card_codex_dto.%s_invalid" % field
	return ""


static func _localization_binding_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "player_card_codex_dto.localization_binding_invalid"
	var binding := value as Dictionary
	if not _has_exact_fields(binding, LOCALIZATION_BINDING_FIELDS):
		return "player_card_codex_dto.localization_binding_fields_invalid"
	if not _is_stable_id(binding.get("source_id")):
		return "player_card_codex_dto.localization_source_id_invalid"
	if not (binding.get("source_revision") is int) \
			or int(binding.get("source_revision", 0)) < 1 \
			or int(binding.get("source_revision", 0)) \
				> PLAYER_FACE_DTO.MAX_SAFE_INTEGER:
		return "player_card_codex_dto.localization_source_revision_invalid"
	for field in ["source_fingerprint", "semantic_fingerprint"]:
		if not PLAYER_FACE_DTO.is_fingerprint(str(binding.get(field, ""))):
			return "player_card_codex_dto.localization_%s_invalid" % field
	return ""


static func _taxonomy_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "player_card_codex_dto.taxonomy_invalid"
	var taxonomy := value as Dictionary
	if not _has_exact_fields(taxonomy, TAXONOMY_FIELDS):
		return "player_card_codex_dto.taxonomy_fields_invalid"
	for field in TAXONOMY_FIELDS:
		if not _is_stable_id(taxonomy.get(field)):
			return "player_card_codex_dto.taxonomy_%s_invalid" % field
	return ""


static func _presentation_tokens_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "player_card_codex_dto.presentation_tokens_invalid"
	var tokens := value as Dictionary
	if not _has_exact_fields(tokens, PRESENTATION_TOKEN_FIELDS):
		return "player_card_codex_dto.presentation_token_fields_invalid"
	for field in [
		"category_icon_token_id",
		"category_color_token_id",
		"industry_color_token_id",
		"fallback_illustration_token_id",
	]:
		if not _is_stable_id(tokens.get(field)):
			return "player_card_codex_dto.%s_invalid" % field
	var illustration_key_value: Variant = tokens.get("illustration_key")
	if not (illustration_key_value is String):
		return "player_card_codex_dto.illustration_key_invalid"
	var illustration_key := str(illustration_key_value)
	if not illustration_key.is_empty() \
			and not PLAYER_FACE_DTO.is_stable_id(illustration_key):
		return "player_card_codex_dto.illustration_key_invalid"
	return ""


static func _presentation_copy_error(
	value: Variant,
	detail_face: Dictionary
) -> String:
	if not (value is Dictionary):
		return "player_card_codex_dto.presentation_copy_invalid"
	var presentation_copy := value as Dictionary
	if not _has_exact_fields(presentation_copy, PRESENTATION_COPY_FIELDS):
		return "player_card_codex_dto.presentation_copy_fields_invalid"
	for field in PRESENTATION_TEXT_FIELDS:
		var text_value: Variant = presentation_copy.get(field)
		if not (text_value is String) or str(text_value).strip_edges().is_empty():
			return "player_card_codex_dto.presentation_%s_invalid" % field
	for field in PRESENTATION_ARRAY_FIELDS:
		var array_error := _ordered_text_array_error(
			presentation_copy.get(field)
		)
		if not array_error.is_empty():
			return "player_card_codex_dto.presentation_%s_%s" % [
				field,
				array_error,
			]
		var source_rows_value: Variant = detail_face.get(field)
		if not (source_rows_value is Array) \
				or (presentation_copy.get(field) as Array).size() \
					!= (source_rows_value as Array).size():
			return "player_card_codex_dto.presentation_%s_count_mismatch" % field
	return ""


static func _ordered_text_array_error(value: Variant) -> String:
	if not (value is Array):
		return "not_array"
	for item in value as Array:
		if not (item is String) or str(item).strip_edges().is_empty():
			return "item_invalid"
	return ""


static func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			if FORBIDDEN_VALUE_CHANNEL_KEYS.has(key) \
					or _contains_forbidden_key(
						(value as Dictionary).get(key_variant)
					):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_forbidden_key(item):
				return true
	return false


static func _has_exact_fields(source: Dictionary, expected_fields: Array) -> bool:
	if source.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not source.has(str(field_variant)):
			return false
	return true


static func _is_stable_id(value: Variant) -> bool:
	return value is String and PLAYER_FACE_DTO.is_stable_id(value as String)


static func _invalid(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}
