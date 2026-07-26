extends RefCounted
class_name SemanticWireV1

const SCHEMA_VERSION := 1
const MAX_SAFE_INTEGER := 9007199254740991
const DOMAIN_IDS := [
	"card",
	"role",
	"monster",
	"monster_behavior",
	"military_unit",
	"weather",
	"product",
	"facility",
	"victory",
]
const PARAMETER_KIND_IDS := [
	"stable_id",
	"safe_integer",
	"nonnegative_integer",
	"positive_integer",
	"boolean",
	"fingerprint",
	"stable_id_array",
	"sorted_stable_id_array",
]

const SEMANTIC_DEFINITION_REF_FIELDS := [
	"schema_version",
	"domain_id",
	"definition_id",
	"definition_revision",
	"semantic_schema_version",
	"semantic_fingerprint",
]
const ENTITY_REF_FIELDS := [
	"schema_version",
	"entity_type_id",
	"entity_id",
	"revision",
]
const LEGALITY_PROOF_REF_FIELDS := [
	"schema_version",
	"status_id",
	"rules_revision",
	"world_revision",
	"source_revision",
	"proof_fingerprint",
]
const CONDITION_PROOF_REF_FIELDS := [
	"schema_version",
	"condition_binding_id",
	"condition_id",
	"rules_revision",
	"world_revision",
	"proof_fingerprint",
]
const RESOLVED_TARGET_BINDING_FIELDS := [
	"schema_version",
	"target_binding_id",
	"target_id",
	"selection_revision",
	"entity_refs",
	"revalidation_policy_id",
]
const PARAMETER_SCHEMA_DESCRIPTOR_FIELDS := [
	"required_fields",
	"optional_fields",
	"field_kinds",
]


static func valid_result() -> Dictionary:
	return {"valid": true, "reason_id": "none"}


static func invalid_result(reason_id: String) -> Dictionary:
	return {"valid": false, "reason_id": reason_id}


static func is_closed_data(value: Variant) -> bool:
	if value is String or value is bool:
		return true
	if value is int:
		return is_safe_integer(value)
	if value is Array:
		for item in value as Array:
			if not is_closed_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String):
				return false
			if not is_closed_data((value as Dictionary).get(key_variant)):
				return false
		return true
	return false


static func detached_copy(value: Variant) -> Variant:
	if not is_closed_data(value):
		return {}
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func is_safe_integer(value: Variant) -> bool:
	return value is int \
		and int(value) >= -MAX_SAFE_INTEGER \
		and int(value) <= MAX_SAFE_INTEGER


static func is_nonnegative_integer(value: Variant) -> bool:
	return is_safe_integer(value) and int(value) >= 0


static func is_positive_integer(value: Variant) -> bool:
	return is_safe_integer(value) and int(value) > 0


static func is_stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := value as String
	if text.is_empty() or text.length() > 160:
		return false
	var previous_was_separator := false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code == 46 or code == 95 or code == 45
		if index == 0 and not lower:
			return false
		if not lower and not digit and not separator:
			return false
		if separator and previous_was_separator:
			return false
		previous_was_separator = separator
	return not previous_was_separator


static func is_fingerprint(value: Variant) -> bool:
	if not (value is String) or (value as String).length() != 64:
		return false
	for index in range((value as String).length()):
		var code := (value as String).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func is_ascii_reference(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := value as String
	if text.is_empty() or text.length() > 512:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code < 32 or code > 126:
			return false
	return true


static func exact_fields(
	value: Dictionary,
	required_fields: Array,
	optional_fields: Array = []
) -> bool:
	for key_variant in value.keys():
		var key := str(key_variant)
		if not required_fields.has(key) and not optional_fields.has(key):
			return false
	for field_variant in required_fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func stable_id_array_error(
	value: Variant,
	allow_empty := true,
	require_sorted := false
) -> String:
	if not (value is Array):
		return "not_array"
	var values: Array[String] = []
	for item in value as Array:
		if not is_stable_id(item):
			return "id_invalid"
		var item_id := str(item)
		if values.has(item_id):
			return "duplicate"
		values.append(item_id)
	if not allow_empty and values.is_empty():
		return "empty"
	if require_sorted:
		var sorted_values := values.duplicate()
		sorted_values.sort()
		if values != sorted_values:
			return "not_sorted"
	return ""


static func positive_integer_array_error(value: Variant, allow_empty := false) -> String:
	if not (value is Array):
		return "not_array"
	var seen: Array[int] = []
	for item in value as Array:
		if not is_positive_integer(item):
			return "integer_invalid"
		if seen.has(int(item)):
			return "duplicate"
		seen.append(int(item))
	if not allow_empty and seen.is_empty():
		return "empty"
	var sorted_values := seen.duplicate()
	sorted_values.sort()
	return "" if seen == sorted_values else "not_sorted"


static func canonical_json(value: Variant) -> String:
	if not is_closed_data(value):
		return ""
	if value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var array_parts: Array[String] = []
		for item in value as Array:
			array_parts.append(canonical_json(item))
		return "[" + ",".join(array_parts) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(JSON.stringify(key) + ":" + canonical_json(source.get(key)))
	return "{" + ",".join(members) + "}"


static func fingerprint(value: Variant, omitted_field := "") -> String:
	if not is_closed_data(value):
		return ""
	var fingerprint_input: Variant = detached_copy(value)
	if not omitted_field.is_empty() and fingerprint_input is Dictionary:
		(fingerprint_input as Dictionary).erase(omitted_field)
	var canonical := canonical_json(fingerprint_input)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func sealed_copy(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if not is_closed_data(unsealed) or unsealed.has(fingerprint_field):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed[fingerprint_field] = fingerprint(sealed)
	return sealed


static func contains_key_recursive(value: Variant, forbidden_keys: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).strip_edges().to_lower()
			if forbidden_keys.has(key):
				return true
			if contains_key_recursive((value as Dictionary).get(key_variant), forbidden_keys):
				return true
	elif value is Array:
		for item in value as Array:
			if contains_key_recursive(item, forbidden_keys):
				return true
	return false


static func semantic_definition_ref_error(value: Variant) -> String:
	if not (value is Dictionary) or not is_closed_data(value):
		return "semantic_ref_not_closed_data"
	var ref := value as Dictionary
	if not exact_fields(ref, SEMANTIC_DEFINITION_REF_FIELDS):
		return "semantic_ref_fields_invalid"
	if ref.get("schema_version") != SCHEMA_VERSION:
		return "semantic_ref_schema_version_invalid"
	if not DOMAIN_IDS.has(str(ref.get("domain_id", ""))) \
			or not is_stable_id(ref.get("definition_id")):
		return "semantic_ref_identity_invalid"
	if not is_positive_integer(ref.get("definition_revision")) \
			or not is_positive_integer(ref.get("semantic_schema_version")):
		return "semantic_ref_revision_invalid"
	if not is_fingerprint(ref.get("semantic_fingerprint")):
		return "semantic_ref_fingerprint_invalid"
	return ""


static func entity_ref_error(value: Variant) -> String:
	if not (value is Dictionary) or not is_closed_data(value):
		return "entity_ref_not_closed_data"
	var ref := value as Dictionary
	if not exact_fields(ref, ENTITY_REF_FIELDS):
		return "entity_ref_fields_invalid"
	if ref.get("schema_version") != SCHEMA_VERSION:
		return "entity_ref_schema_version_invalid"
	if not is_stable_id(ref.get("entity_type_id")) or not is_stable_id(ref.get("entity_id")):
		return "entity_ref_identity_invalid"
	if not is_nonnegative_integer(ref.get("revision")):
		return "entity_ref_revision_invalid"
	return ""


static func legality_proof_ref_error(value: Variant) -> String:
	if not (value is Dictionary) or not is_closed_data(value):
		return "legality_proof_not_closed_data"
	var proof := value as Dictionary
	if not exact_fields(proof, LEGALITY_PROOF_REF_FIELDS):
		return "legality_proof_fields_invalid"
	if proof.get("schema_version") != SCHEMA_VERSION:
		return "legality_proof_schema_version_invalid"
	if str(proof.get("status_id", "")) != "legal":
		return "legality_proof_status_invalid"
	for field in ["rules_revision", "world_revision", "source_revision"]:
		if not is_nonnegative_integer(proof.get(field)):
			return "legality_proof_revision_invalid"
	if not is_fingerprint(proof.get("proof_fingerprint")):
		return "legality_proof_fingerprint_invalid"
	if str(proof.get("proof_fingerprint", "")) \
			!= fingerprint(proof, "proof_fingerprint"):
		return "legality_proof_fingerprint_mismatch"
	return ""


static func condition_proof_ref_error(value: Variant) -> String:
	if not (value is Dictionary) or not is_closed_data(value):
		return "condition_proof_not_closed_data"
	var proof := value as Dictionary
	if not exact_fields(proof, CONDITION_PROOF_REF_FIELDS):
		return "condition_proof_fields_invalid"
	if proof.get("schema_version") != SCHEMA_VERSION:
		return "condition_proof_schema_version_invalid"
	if not is_stable_id(proof.get("condition_binding_id")) \
			or not is_stable_id(proof.get("condition_id")):
		return "condition_proof_identity_invalid"
	if not is_nonnegative_integer(proof.get("rules_revision")) \
			or not is_nonnegative_integer(proof.get("world_revision")):
		return "condition_proof_revision_invalid"
	if not is_fingerprint(proof.get("proof_fingerprint")):
		return "condition_proof_fingerprint_invalid"
	if str(proof.get("proof_fingerprint", "")) \
			!= fingerprint(proof, "proof_fingerprint"):
		return "condition_proof_fingerprint_mismatch"
	return ""


static func resolved_target_binding_error(value: Variant) -> String:
	if not (value is Dictionary) or not is_closed_data(value):
		return "resolved_target_not_closed_data"
	var binding := value as Dictionary
	if not exact_fields(binding, RESOLVED_TARGET_BINDING_FIELDS):
		return "resolved_target_fields_invalid"
	if binding.get("schema_version") != SCHEMA_VERSION:
		return "resolved_target_schema_version_invalid"
	for field in ["target_binding_id", "target_id", "revalidation_policy_id"]:
		if not is_stable_id(binding.get(field)):
			return "resolved_target_identity_invalid"
	if not is_nonnegative_integer(binding.get("selection_revision")):
		return "resolved_target_revision_invalid"
	if not (binding.get("entity_refs") is Array) \
			or (binding.get("entity_refs") as Array).is_empty():
		return "resolved_target_entities_invalid"
	var seen: Array[String] = []
	for ref_variant in binding.get("entity_refs") as Array:
		var ref_error := entity_ref_error(ref_variant)
		if not ref_error.is_empty():
			return ref_error
		var ref := ref_variant as Dictionary
		var key := "%s|%s" % [ref.get("entity_type_id", ""), ref.get("entity_id", "")]
		if seen.has(key):
			return "resolved_target_entity_duplicate"
		seen.append(key)
	return ""


static func closed_payload_error(
	value: Variant,
	parameter_schema_id: String,
	parameter_schemas: Dictionary
) -> String:
	if not is_stable_id(parameter_schema_id):
		return "parameter_schema_id_invalid"
	if not parameter_schemas.has(parameter_schema_id):
		return "parameter_schema_unknown"
	var descriptor_variant: Variant = parameter_schemas.get(parameter_schema_id)
	if not (descriptor_variant is Dictionary) or not is_closed_data(descriptor_variant):
		return "parameter_schema_descriptor_invalid"
	var descriptor := descriptor_variant as Dictionary
	if not exact_fields(descriptor, PARAMETER_SCHEMA_DESCRIPTOR_FIELDS):
		return "parameter_schema_descriptor_fields_invalid"
	var required: Variant = descriptor.get("required_fields")
	var optional: Variant = descriptor.get("optional_fields")
	var kinds: Variant = descriptor.get("field_kinds")
	if stable_id_array_error(required, true, true) != "" \
			or stable_id_array_error(optional, true, true) != "" \
			or not (kinds is Dictionary):
		return "parameter_schema_descriptor_shape_invalid"
	var all_fields: Array = (required as Array).duplicate()
	for field_variant in optional as Array:
		if all_fields.has(field_variant):
			return "parameter_schema_field_duplicate"
		all_fields.append(field_variant)
	if not exact_fields(kinds as Dictionary, all_fields):
		return "parameter_schema_kind_fields_invalid"
	for field_variant in all_fields:
		if not PARAMETER_KIND_IDS.has(str((kinds as Dictionary).get(field_variant, ""))):
			return "parameter_schema_kind_invalid"
	if not (value is Dictionary) or not is_closed_data(value):
		return "parameters_not_closed_data"
	var payload := value as Dictionary
	if not exact_fields(payload, required as Array, optional as Array):
		return "parameters_fields_invalid"
	for field_variant in payload.keys():
		var field := str(field_variant)
		if not _parameter_value_matches(payload.get(field), str((kinds as Dictionary).get(field, ""))):
			return "parameters.%s.invalid" % field
	return ""


static func sorted_unique_ascii_references_error(value: Variant, allow_empty := false) -> String:
	if not (value is Array):
		return "not_array"
	var refs: Array[String] = []
	for item in value as Array:
		if not is_ascii_reference(item):
			return "reference_invalid"
		if refs.has(str(item)):
			return "duplicate"
		refs.append(str(item))
	if not allow_empty and refs.is_empty():
		return "empty"
	var sorted_refs := refs.duplicate()
	sorted_refs.sort()
	return "" if refs == sorted_refs else "not_sorted"


static func _parameter_value_matches(value: Variant, kind_id: String) -> bool:
	match kind_id:
		"stable_id":
			return is_stable_id(value)
		"safe_integer":
			return is_safe_integer(value)
		"nonnegative_integer":
			return is_nonnegative_integer(value)
		"positive_integer":
			return is_positive_integer(value)
		"boolean":
			return value is bool
		"fingerprint":
			return is_fingerprint(value)
		"stable_id_array":
			return stable_id_array_error(value) == ""
		"sorted_stable_id_array":
			return stable_id_array_error(value, true, true) == ""
	return false
