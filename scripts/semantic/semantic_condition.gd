extends RefCounted
class_name SemanticCondition

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"condition_binding_id",
	"condition_id",
	"condition_version",
	"subject_binding_id",
	"parameter_schema_id",
	"parameters",
]


static func build(
	source: Dictionary,
	supported_condition_ids: Array,
	parameter_schemas: Dictionary
) -> Dictionary:
	var report := validate(source, supported_condition_ids, parameter_schemas)
	return source.duplicate(true) if bool(report.get("valid", false)) else {}


static func validate(
	value: Variant,
	supported_condition_ids: Array,
	parameter_schemas: Dictionary
) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_condition.not_closed_data")
	var condition := value as Dictionary
	if not WIRE.exact_fields(condition, FIELDS):
		return WIRE.invalid_result("semantic_condition.fields_invalid")
	if condition.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_condition.schema_version_invalid")
	for field in ["condition_binding_id", "condition_id", "subject_binding_id", "parameter_schema_id"]:
		if not WIRE.is_stable_id(condition.get(field)):
			return WIRE.invalid_result("semantic_condition.%s_invalid" % field)
	if not WIRE.is_positive_integer(condition.get("condition_version")):
		return WIRE.invalid_result("semantic_condition.condition_version_invalid")
	if not supported_condition_ids.has(str(condition.get("condition_id", ""))):
		return WIRE.invalid_result("semantic_condition.condition_id_unknown")
	var payload_error := WIRE.closed_payload_error(
		condition.get("parameters"),
		str(condition.get("parameter_schema_id", "")),
		parameter_schemas
	)
	if not payload_error.is_empty():
		return WIRE.invalid_result("semantic_condition.%s" % payload_error)
	return WIRE.valid_result()
