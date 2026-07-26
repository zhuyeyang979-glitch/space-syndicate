extends RefCounted
class_name OperationHandlerDescriptor

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const BUILD_FIELDS := [
	"schema_version",
	"operation_id",
	"operation_version",
	"domain_id",
	"handler_owner_id",
	"mechanic_ids",
	"rule_source_refs",
	"parameter_schema_id",
	"supported_condition_ids",
	"supported_target_ids",
	"supported_randomness_policy_ids",
	"supported_transaction_policy_ids",
	"supported_plan_schema_versions",
	"supports_preflight",
	"supports_checkpoint",
	"supports_apply",
	"supports_rollback",
	"supports_rules_projection",
	"supports_player_projection",
	"supports_ai_projection",
]
const FIELDS := BUILD_FIELDS + ["descriptor_fingerprint"]
const BOOLEAN_FIELDS := [
	"supports_preflight",
	"supports_checkpoint",
	"supports_apply",
	"supports_rollback",
	"supports_rules_projection",
	"supports_player_projection",
	"supports_ai_projection",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "descriptor_fingerprint")
	return sealed if bool(validate(sealed).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("operation_handler_descriptor.not_closed_data")
	var descriptor := value as Dictionary
	if not WIRE.exact_fields(descriptor, FIELDS):
		return WIRE.invalid_result("operation_handler_descriptor.fields_invalid")
	if descriptor.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("operation_handler_descriptor.schema_version_invalid")
	for field in ["operation_id", "handler_owner_id", "parameter_schema_id"]:
		if not WIRE.is_stable_id(descriptor.get(field)):
			return WIRE.invalid_result("operation_handler_descriptor.%s_invalid" % field)
	if not WIRE.is_positive_integer(descriptor.get("operation_version")):
		return WIRE.invalid_result("operation_handler_descriptor.operation_version_invalid")
	if not WIRE.DOMAIN_IDS.has(str(descriptor.get("domain_id", ""))):
		return WIRE.invalid_result("operation_handler_descriptor.domain_id_unknown")
	for entry in [
		["mechanic_ids", false],
		["supported_condition_ids", true],
		["supported_target_ids", true],
		["supported_randomness_policy_ids", false],
		["supported_transaction_policy_ids", false],
	]:
		var ids_error := WIRE.stable_id_array_error(
			descriptor.get(entry[0]), bool(entry[1]), true
		)
		if not ids_error.is_empty():
			return WIRE.invalid_result(
				"operation_handler_descriptor.%s_%s" % [entry[0], ids_error]
			)
	var refs_error := WIRE.sorted_unique_ascii_references_error(
		descriptor.get("rule_source_refs"), false
	)
	if not refs_error.is_empty():
		return WIRE.invalid_result("operation_handler_descriptor.rule_source_refs_%s" % refs_error)
	var versions_error := WIRE.positive_integer_array_error(
		descriptor.get("supported_plan_schema_versions"), false
	)
	if not versions_error.is_empty():
		return WIRE.invalid_result(
			"operation_handler_descriptor.plan_schema_versions_%s" % versions_error
		)
	for field in BOOLEAN_FIELDS:
		if not (descriptor.get(field) is bool):
			return WIRE.invalid_result("operation_handler_descriptor.%s_invalid" % field)
	if not WIRE.is_fingerprint(descriptor.get("descriptor_fingerprint")) \
			or str(descriptor.get("descriptor_fingerprint", "")) \
			!= WIRE.fingerprint(descriptor, "descriptor_fingerprint"):
		return WIRE.invalid_result("operation_handler_descriptor.fingerprint_invalid")
	return WIRE.valid_result()
