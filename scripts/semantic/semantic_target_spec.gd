extends RefCounted
class_name SemanticTargetSpec

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"target_binding_id",
	"target_id",
	"target_version",
	"selection_mode_id",
	"minimum_count",
	"maximum_count",
	"allowed_entity_type_ids",
	"filter_condition_binding_ids",
	"revalidation_policy_id",
	"target_visibility_policy_id",
]


static func build(source: Dictionary, supported_target_ids: Array) -> Dictionary:
	var report := validate(source, supported_target_ids)
	return source.duplicate(true) if bool(report.get("valid", false)) else {}


static func validate(value: Variant, supported_target_ids: Array) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_target.not_closed_data")
	var target := value as Dictionary
	if not WIRE.exact_fields(target, FIELDS):
		return WIRE.invalid_result("semantic_target.fields_invalid")
	if target.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_target.schema_version_invalid")
	for field in [
		"target_binding_id",
		"target_id",
		"selection_mode_id",
		"revalidation_policy_id",
		"target_visibility_policy_id",
	]:
		if not WIRE.is_stable_id(target.get(field)):
			return WIRE.invalid_result("semantic_target.%s_invalid" % field)
	if not supported_target_ids.has(str(target.get("target_id", ""))):
		return WIRE.invalid_result("semantic_target.target_id_unknown")
	if not WIRE.is_positive_integer(target.get("target_version")):
		return WIRE.invalid_result("semantic_target.target_version_invalid")
	if not WIRE.is_nonnegative_integer(target.get("minimum_count")) \
			or not WIRE.is_nonnegative_integer(target.get("maximum_count")) \
			or int(target.get("maximum_count", -1)) < int(target.get("minimum_count", 0)):
		return WIRE.invalid_result("semantic_target.cardinality_invalid")
	var ids_error := WIRE.stable_id_array_error(target.get("allowed_entity_type_ids"), false)
	if not ids_error.is_empty():
		return WIRE.invalid_result("semantic_target.allowed_entity_type_ids_%s" % ids_error)
	ids_error = WIRE.stable_id_array_error(target.get("filter_condition_binding_ids"), true)
	if not ids_error.is_empty():
		return WIRE.invalid_result("semantic_target.filter_condition_binding_ids_%s" % ids_error)
	return WIRE.valid_result()
