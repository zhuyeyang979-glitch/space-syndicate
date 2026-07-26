@tool
extends RefCounted
class_name PlayerFaceDTOv1

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9007199254740991

const SURFACE_IDS := ["market", "hand", "detail"]
const EMPHASIS_IDS := ["primary", "secondary", "reference", "complete"]
const ARG_TYPE_IDS := [
	"integer",
	"number",
	"boolean",
	"stable_id",
	"cash",
	"asset_units",
	"seconds",
	"milliseconds",
	"count",
	"rate",
]

const ROOT_FIELDS := [
	"schema_version",
	"card_id",
	"family_id",
	"rank",
	"name_ref",
	"family_name_ref",
	"surface_id",
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
	"dto_fingerprint",
]
const UNSEALED_ROOT_FIELDS := [
	"schema_version",
	"card_id",
	"family_id",
	"rank",
	"name_ref",
	"family_name_ref",
	"surface_id",
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
]

const ASSET_COST_FIELDS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
	"generic",
]

const SURFACE_PROFILES := {
	"market": {
		"surface_id": "market",
		"profile_id": "market_acquisition",
		"section_order": [
			"acquisition_cost",
			"effect_steps",
			"targets",
			"activation_cost",
			"keywords",
			"timing",
			"conditions",
			"duration",
			"counterability",
			"information_scope",
		],
		"emphasis_by_section": {
			"acquisition_cost": "primary",
			"activation_cost": "secondary",
			"timing": "reference",
			"targets": "secondary",
			"conditions": "reference",
			"effect_steps": "primary",
			"duration": "reference",
			"counterability": "reference",
			"information_scope": "reference",
			"keywords": "secondary",
		},
	},
	"hand": {
		"surface_id": "hand",
		"profile_id": "hand_activation",
		"section_order": [
			"activation_cost",
			"targets",
			"effect_steps",
			"keywords",
			"timing",
			"conditions",
			"duration",
			"counterability",
			"information_scope",
			"acquisition_cost",
		],
		"emphasis_by_section": {
			"acquisition_cost": "reference",
			"activation_cost": "primary",
			"timing": "secondary",
			"targets": "primary",
			"conditions": "secondary",
			"effect_steps": "primary",
			"duration": "secondary",
			"counterability": "secondary",
			"information_scope": "reference",
			"keywords": "secondary",
		},
	},
	"detail": {
		"surface_id": "detail",
		"profile_id": "detail_complete",
		"section_order": [
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
		],
		"emphasis_by_section": {
			"acquisition_cost": "complete",
			"activation_cost": "complete",
			"timing": "complete",
			"targets": "complete",
			"conditions": "complete",
			"effect_steps": "complete",
			"duration": "complete",
			"counterability": "complete",
			"information_scope": "complete",
			"keywords": "complete",
		},
	},
}


static func seal(unsealed_dto: Dictionary) -> Dictionary:
	if not is_detached_pure_data(unsealed_dto):
		return {}
	if not _has_exact_fields(unsealed_dto, UNSEALED_ROOT_FIELDS):
		return {}
	var dto := unsealed_dto.duplicate(true)
	dto["dto_fingerprint"] = fingerprint_value(dto)
	var report := validate(dto)
	return dto if bool(report.get("valid", false)) else {}


static func seal_catalog_owned(unsealed_dto: Dictionary) -> Dictionary:
	if not is_detached_pure_data(unsealed_dto) \
			or not _has_exact_fields(unsealed_dto, UNSEALED_ROOT_FIELDS) \
			or unsealed_dto.get("schema_version") != SCHEMA_VERSION \
			or not is_stable_id(str(unsealed_dto.get("card_id", ""))) \
			or not is_stable_id(str(unsealed_dto.get("family_id", ""))) \
			or int(unsealed_dto.get("rank", 0)) < 1 \
			or int(unsealed_dto.get("rank", 0)) > 4 \
			or not SURFACE_IDS.has(str(unsealed_dto.get("surface_id", ""))):
		return {}
	var dto := unsealed_dto.duplicate(true)
	dto["dto_fingerprint"] = fingerprint_value(dto)
	return dto if is_fingerprint(str(dto.get("dto_fingerprint", ""))) else {}


static func validate(dto: Dictionary) -> Dictionary:
	if not is_detached_pure_data(dto):
		return _invalid("dto_not_detached_pure_data")
	if not _has_exact_fields(dto, ROOT_FIELDS):
		return _invalid("dto_root_fields_invalid")
	if not (dto.get("schema_version") is int) or int(dto.get("schema_version")) != SCHEMA_VERSION:
		return _invalid("dto_schema_version_invalid")
	if not is_stable_id(str(dto.get("card_id", ""))):
		return _invalid("dto_card_id_invalid")
	if not is_stable_id(str(dto.get("family_id", ""))):
		return _invalid("dto_family_id_invalid")
	if not (dto.get("rank") is int) or int(dto.get("rank")) < 1 or int(dto.get("rank")) > 4:
		return _invalid("dto_rank_invalid")
	var identity_ref_error := _identity_message_ref_error(dto.get("name_ref"), "card_id", str(dto.get("card_id", "")))
	if not identity_ref_error.is_empty():
		return _invalid("dto_name_ref_%s" % identity_ref_error)
	identity_ref_error = _identity_message_ref_error(dto.get("family_name_ref"), "family_id", str(dto.get("family_id", "")))
	if not identity_ref_error.is_empty():
		return _invalid("dto_family_name_ref_%s" % identity_ref_error)
	if not SURFACE_IDS.has(str(dto.get("surface_id", ""))):
		return _invalid("dto_surface_id_invalid")

	var nested_error := _acquisition_cost_error(dto.get("acquisition_cost"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _activation_cost_error(dto.get("activation_cost"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _timing_error(dto.get("timing"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _targets_error(dto.get("targets"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _conditions_error(dto.get("conditions"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _effect_steps_error(dto.get("effect_steps"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _duration_error(dto.get("duration"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _counterability_error(dto.get("counterability"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _information_scope_error(dto.get("information_scope"))
	if not nested_error.is_empty():
		return _invalid(nested_error)
	nested_error = _keywords_error(dto.get("keywords"))
	if not nested_error.is_empty():
		return _invalid(nested_error)

	var fingerprint := str(dto.get("dto_fingerprint", ""))
	if not is_fingerprint(fingerprint):
		return _invalid("dto_fingerprint_invalid")
	var fingerprint_input := dto.duplicate(true)
	fingerprint_input.erase("dto_fingerprint")
	if fingerprint != fingerprint_value(fingerprint_input):
		return _invalid("dto_fingerprint_mismatch")
	return {"valid": true, "reason_id": "player_face_dto.valid"}


static func surface_profile(surface_id: String) -> Dictionary:
	if not SURFACE_PROFILES.has(surface_id):
		return {}
	return (SURFACE_PROFILES[surface_id] as Dictionary).duplicate(true)


static func emphasis_for(surface_id: String, section_id: String) -> String:
	var profile := surface_profile(surface_id)
	var emphasis: Dictionary = profile.get("emphasis_by_section", {}) as Dictionary
	return str(emphasis.get(section_id, ""))


static func fingerprint_value(value: Variant) -> String:
	if not is_detached_pure_data(value):
		return ""
	var canonical: Variant = _canonicalize(value)
	return JSON.stringify(canonical).sha256_text().to_lower()


static func is_detached_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Array:
		for item in value as Array:
			if not is_detached_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String):
				return false
			if not is_detached_pure_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


static func is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 160 or value.begins_with(".") or value.ends_with(".") or value.contains(".."):
		return false
	for index in range(value.length()):
		var character := value[index]
		var code := character.unicode_at(0)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if index == 0 and not lower:
			return false
		if not lower and not digit and character != "." and character != "_" and character != "-":
			return false
	return true


static func is_fingerprint(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		var code := character.unicode_at(0)
		var digit := code >= 48 and code <= 57
		var lower_hex := code >= 97 and code <= 102
		if not digit and not lower_hex:
			return false
	return true


static func _acquisition_cost_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "dto_acquisition_cost_invalid"
	var cost: Dictionary = value
	if not _has_exact_fields(cost, ["acquisition_kind", "purchase_cash", "message_ref", "emphasis_id"]):
		return "dto_acquisition_cost_fields_invalid"
	if not is_stable_id(str(cost.get("acquisition_kind", ""))):
		return "dto_acquisition_kind_invalid"
	if not _is_nonnegative_safe_integer(cost.get("purchase_cash")):
		return "dto_purchase_cash_invalid"
	var message_error := _message_ref_error(cost.get("message_ref"))
	if not message_error.is_empty():
		return "dto_acquisition_%s" % message_error
	if not EMPHASIS_IDS.has(str(cost.get("emphasis_id", ""))):
		return "dto_acquisition_emphasis_invalid"
	return ""


static func _activation_cost_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "dto_activation_cost_invalid"
	var cost: Dictionary = value
	if not _has_exact_fields(cost, ["asset_cost", "message_ref", "emphasis_id"]):
		return "dto_activation_cost_fields_invalid"
	var asset_value: Variant = cost.get("asset_cost")
	if not (asset_value is Dictionary):
		return "dto_asset_cost_invalid"
	var asset_cost: Dictionary = asset_value
	if not _has_exact_fields(asset_cost, ASSET_COST_FIELDS):
		return "dto_asset_cost_fields_invalid"
	for asset_id in ASSET_COST_FIELDS:
		if not _is_nonnegative_safe_integer(asset_cost.get(asset_id)):
			return "dto_asset_cost_value_invalid"
	var message_error := _message_ref_error(cost.get("message_ref"))
	if not message_error.is_empty():
		return "dto_activation_%s" % message_error
	if not EMPHASIS_IDS.has(str(cost.get("emphasis_id", ""))):
		return "dto_activation_emphasis_invalid"
	return ""


static func _timing_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "dto_timing_invalid"
	var timing: Dictionary = value
	if not _has_exact_fields(timing, ["timing_id", "message_ref", "emphasis_id"]):
		return "dto_timing_fields_invalid"
	if not is_stable_id(str(timing.get("timing_id", ""))):
		return "dto_timing_id_invalid"
	var message_error := _message_ref_error(timing.get("message_ref"))
	if not message_error.is_empty():
		return "dto_timing_%s" % message_error
	if not EMPHASIS_IDS.has(str(timing.get("emphasis_id", ""))):
		return "dto_timing_emphasis_invalid"
	return ""


static func _targets_error(value: Variant) -> String:
	if not (value is Array) or (value as Array).is_empty():
		return "dto_targets_invalid"
	var seen: Dictionary = {}
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			return "dto_target_row_invalid"
		var row: Dictionary = row_variant
		if not _has_exact_fields(row, ["target_id", "selection_id", "cardinality_id", "filter_ids", "message_ref", "emphasis_id"]):
			return "dto_target_fields_invalid"
		for field_id in ["target_id", "selection_id", "cardinality_id"]:
			if not is_stable_id(str(row.get(field_id, ""))):
				return "dto_target_identifier_invalid"
		var filter_ids_value: Variant = row.get("filter_ids")
		if not (filter_ids_value is Array) or (filter_ids_value as Array).is_empty():
			return "dto_target_filter_ids_invalid"
		var seen_filters: Dictionary = {}
		for filter_variant in filter_ids_value as Array:
			var filter_id := str(filter_variant)
			if not (filter_variant is String) or not is_stable_id(filter_id) or seen_filters.has(filter_id):
				return "dto_target_filter_ids_invalid"
			seen_filters[filter_id] = true
		var target_id := str(row.get("target_id", ""))
		if seen.has(target_id):
			return "dto_target_duplicate"
		seen[target_id] = true
		var message_error := _message_ref_error(row.get("message_ref"))
		if not message_error.is_empty():
			return "dto_target_%s" % message_error
		if not EMPHASIS_IDS.has(str(row.get("emphasis_id", ""))):
			return "dto_target_emphasis_invalid"
	return ""


static func _conditions_error(value: Variant) -> String:
	if not (value is Array):
		return "dto_conditions_invalid"
	var seen: Dictionary = {}
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			return "dto_condition_row_invalid"
		var row: Dictionary = row_variant
		if not _has_exact_fields(row, ["condition_id", "source_id", "message_ref", "emphasis_id"]):
			return "dto_condition_fields_invalid"
		if not is_stable_id(str(row.get("condition_id", ""))) or not is_stable_id(str(row.get("source_id", ""))):
			return "dto_condition_identifier_invalid"
		var condition_id := str(row.get("condition_id", ""))
		if seen.has(condition_id):
			return "dto_condition_duplicate"
		seen[condition_id] = true
		var message_error := _message_ref_error(row.get("message_ref"))
		if not message_error.is_empty():
			return "dto_condition_%s" % message_error
		if not EMPHASIS_IDS.has(str(row.get("emphasis_id", ""))):
			return "dto_condition_emphasis_invalid"
	return ""


static func _effect_steps_error(value: Variant) -> String:
	if not (value is Array) or (value as Array).is_empty():
		return "dto_effect_steps_invalid"
	var seen_steps: Dictionary = {}
	var expected_order := 1
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			return "dto_effect_step_row_invalid"
		var row: Dictionary = row_variant
		if not _has_exact_fields(row, ["order", "step_id", "op_id", "target_id", "parameters", "summary_ref", "detail_ref", "emphasis_id"]):
			return "dto_effect_step_fields_invalid"
		if not (row.get("order") is int) or int(row.get("order")) != expected_order:
			return "dto_effect_step_order_invalid"
		expected_order += 1
		for field_id in ["step_id", "op_id", "target_id"]:
			if not is_stable_id(str(row.get(field_id, ""))):
				return "dto_effect_step_identifier_invalid"
		var step_id := str(row.get("step_id", ""))
		if seen_steps.has(step_id):
			return "dto_effect_step_duplicate"
		seen_steps[step_id] = true
		var parameters_error := _typed_args_error(row.get("parameters"))
		if not parameters_error.is_empty():
			return "dto_effect_step_parameters_invalid"
		var summary_error := _message_ref_error(row.get("summary_ref"))
		var detail_error := _message_ref_error(row.get("detail_ref"))
		if not summary_error.is_empty() or not detail_error.is_empty():
			return "dto_effect_step_message_ref_invalid"
		if not EMPHASIS_IDS.has(str(row.get("emphasis_id", ""))):
			return "dto_effect_step_emphasis_invalid"
	return ""


static func _duration_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "dto_duration_invalid"
	var duration: Dictionary = value
	if not _has_exact_fields(duration, ["duration_id", "components", "message_ref", "emphasis_id"]):
		return "dto_duration_fields_invalid"
	if not is_stable_id(str(duration.get("duration_id", ""))):
		return "dto_duration_id_invalid"
	var components_value: Variant = duration.get("components")
	if not (components_value is Array):
		return "dto_duration_components_invalid"
	for component_variant in components_value as Array:
		if not (component_variant is Dictionary):
			return "dto_duration_component_invalid"
		var component: Dictionary = component_variant
		if not _has_exact_fields(component, ["step_id", "parameter_id", "type_id", "value"]):
			return "dto_duration_component_fields_invalid"
		if not is_stable_id(str(component.get("step_id", ""))) or not is_stable_id(str(component.get("parameter_id", ""))):
			return "dto_duration_component_identifier_invalid"
		var typed_error := _typed_value_error(str(component.get("type_id", "")), component.get("value"))
		if not typed_error.is_empty():
			return "dto_duration_component_value_invalid"
	var message_error := _message_ref_error(duration.get("message_ref"))
	if not message_error.is_empty():
		return "dto_duration_%s" % message_error
	if not EMPHASIS_IDS.has(str(duration.get("emphasis_id", ""))):
		return "dto_duration_emphasis_invalid"
	return ""


static func _counterability_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "dto_counterability_invalid"
	var counterability: Dictionary = value
	if not _has_exact_fields(counterability, ["response_id", "parameters", "message_ref", "emphasis_id"]):
		return "dto_counterability_fields_invalid"
	if not is_stable_id(str(counterability.get("response_id", ""))):
		return "dto_response_id_invalid"
	if not _typed_args_error(counterability.get("parameters")).is_empty():
		return "dto_counterability_parameters_invalid"
	var message_error := _message_ref_error(counterability.get("message_ref"))
	if not message_error.is_empty():
		return "dto_counterability_%s" % message_error
	if not EMPHASIS_IDS.has(str(counterability.get("emphasis_id", ""))):
		return "dto_counterability_emphasis_invalid"
	return ""


static func _information_scope_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "dto_information_scope_invalid"
	var information_scope: Dictionary = value
	if not _has_exact_fields(information_scope, ["policy_id", "scope_rows", "message_ref", "emphasis_id"]):
		return "dto_information_scope_fields_invalid"
	if not is_stable_id(str(information_scope.get("policy_id", ""))):
		return "dto_information_policy_id_invalid"
	var rows_value: Variant = information_scope.get("scope_rows")
	if not (rows_value is Array) or (rows_value as Array).is_empty():
		return "dto_information_scope_rows_invalid"
	var seen: Dictionary = {}
	for row_variant in rows_value as Array:
		if not (row_variant is Dictionary):
			return "dto_information_scope_row_invalid"
		var row: Dictionary = row_variant
		if not _has_exact_fields(row, ["scope_id", "value_id"]):
			return "dto_information_scope_row_fields_invalid"
		if not is_stable_id(str(row.get("scope_id", ""))) or not is_stable_id(str(row.get("value_id", ""))):
			return "dto_information_scope_identifier_invalid"
		var scope_id := str(row.get("scope_id", ""))
		if seen.has(scope_id):
			return "dto_information_scope_duplicate"
		seen[scope_id] = true
	var message_error := _message_ref_error(information_scope.get("message_ref"))
	if not message_error.is_empty():
		return "dto_information_scope_%s" % message_error
	if not EMPHASIS_IDS.has(str(information_scope.get("emphasis_id", ""))):
		return "dto_information_scope_emphasis_invalid"
	return ""


static func _keywords_error(value: Variant) -> String:
	if not (value is Array) or (value as Array).is_empty():
		return "dto_keywords_invalid"
	var seen: Dictionary = {}
	for row_variant in value as Array:
		if not (row_variant is Dictionary):
			return "dto_keyword_row_invalid"
		var row: Dictionary = row_variant
		if not _has_exact_fields(row, ["keyword_id", "label_ref", "tooltip_ref", "icon_token_id", "color_token_id"]):
			return "dto_keyword_fields_invalid"
		for field_id in ["keyword_id", "icon_token_id", "color_token_id"]:
			if not is_stable_id(str(row.get(field_id, ""))):
				return "dto_keyword_identifier_invalid"
		var keyword_id := str(row.get("keyword_id", ""))
		if seen.has(keyword_id):
			return "dto_keyword_duplicate"
		seen[keyword_id] = true
		if not _message_ref_error(row.get("label_ref")).is_empty() or not _message_ref_error(row.get("tooltip_ref")).is_empty():
			return "dto_keyword_message_ref_invalid"
	return ""


static func _message_ref_error(value: Variant) -> String:
	if not (value is Dictionary):
		return "message_ref_invalid"
	var message_ref: Dictionary = value
	if not _has_exact_fields(message_ref, ["message_id", "args"]):
		return "message_ref_fields_invalid"
	if not is_stable_id(str(message_ref.get("message_id", ""))):
		return "message_id_invalid"
	if not _typed_args_error(message_ref.get("args")).is_empty():
		return "message_args_invalid"
	return ""


static func _identity_message_ref_error(value: Variant, binding_arg_id: String, expected_id: String) -> String:
	var message_error := _message_ref_error(value)
	if not message_error.is_empty():
		return message_error
	var message_ref: Dictionary = value
	var args: Array = message_ref.get("args", []) as Array
	if args.size() != 1:
		return "binding_arg_count_invalid"
	var binding: Dictionary = args[0] as Dictionary
	if str(binding.get("arg_id", "")) != binding_arg_id \
			or str(binding.get("type_id", "")) != "stable_id" \
			or str(binding.get("value", "")) != expected_id:
		return "binding_invalid"
	return ""


static func _typed_args_error(value: Variant) -> String:
	if not (value is Array):
		return "typed_args_not_array"
	var seen: Dictionary = {}
	for arg_variant in value as Array:
		if not (arg_variant is Dictionary):
			return "typed_arg_invalid"
		var arg: Dictionary = arg_variant
		if not _has_exact_fields(arg, ["arg_id", "type_id", "value"]):
			return "typed_arg_fields_invalid"
		var arg_id := str(arg.get("arg_id", ""))
		if not is_stable_id(arg_id) or seen.has(arg_id):
			return "typed_arg_id_invalid"
		seen[arg_id] = true
		if not _typed_value_error(str(arg.get("type_id", "")), arg.get("value")).is_empty():
			return "typed_arg_value_invalid"
	return ""


static func _typed_value_error(type_id: String, value: Variant) -> String:
	if not ARG_TYPE_IDS.has(type_id):
		return "typed_value_type_id_invalid"
	match type_id:
		"boolean":
			return "" if value is bool else "typed_value_boolean_invalid"
		"stable_id":
			return "" if value is String and is_stable_id(str(value)) else "typed_value_stable_id_invalid"
		"number":
			return "" if (value is int or value is float) and is_finite(float(value)) else "typed_value_number_invalid"
		_:
			return "" if _is_safe_integer(value) else "typed_value_integer_invalid"


static func _is_nonnegative_safe_integer(value: Variant) -> bool:
	return _is_safe_integer(value) and int(value) >= 0


static func _is_safe_integer(value: Variant) -> bool:
	return value is int and absi(int(value)) <= MAX_SAFE_INTEGER


static func _has_exact_fields(source: Dictionary, expected_fields: Array) -> bool:
	if source.size() != expected_fields.size():
		return false
	for field_variant in expected_fields:
		if not source.has(str(field_variant)):
			return false
	return true


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var source: Dictionary = value
		var keys: Array[String] = []
		for key_variant in source.keys():
			keys.append(str(key_variant))
		keys.sort()
		var normalized: Dictionary = {}
		for key in keys:
			normalized[key] = _canonicalize(source.get(key))
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item in value as Array:
			normalized_array.append(_canonicalize(item))
		return normalized_array
	return value


static func _invalid(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}
