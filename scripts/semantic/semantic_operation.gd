extends RefCounted
class_name SemanticOperation

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const RANDOMNESS := preload("res://scripts/semantic/semantic_randomness_policy.gd")
const VISIBILITY := preload("res://scripts/semantic/semantic_visibility_policy.gd")
const SCHEMA_VERSION := 1
const FIELDS := [
	"schema_version",
	"operation_instance_id",
	"operation_id",
	"operation_version",
	"domain_id",
	"target_binding_ids",
	"condition_binding_ids",
	"parameter_schema_id",
	"parameters",
	"randomness_policy_id",
	"result_visibility_policy_id",
	"atomic_group_id",
	"sequence_index",
]
const CONTRACT_FIELDS := [
	"operation_version",
	"domain_id",
	"parameter_schema_id",
	"randomness_mode_id",
]


static func build(
	source: Dictionary,
	operation_contracts: Dictionary,
	parameter_schemas: Dictionary,
	randomness_policies: Dictionary,
	visibility_policies: Dictionary
) -> Dictionary:
	var report := validate(
		source,
		operation_contracts,
		parameter_schemas,
		randomness_policies,
		visibility_policies
	)
	return source.duplicate(true) if bool(report.get("valid", false)) else {}


static func validate(
	value: Variant,
	operation_contracts: Dictionary,
	parameter_schemas: Dictionary,
	randomness_policies: Dictionary,
	visibility_policies: Dictionary
) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("semantic_operation.not_closed_data")
	var operation := value as Dictionary
	if not WIRE.exact_fields(operation, FIELDS):
		return WIRE.invalid_result("semantic_operation.fields_invalid")
	if operation.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("semantic_operation.schema_version_invalid")
	for field in [
		"operation_instance_id",
		"operation_id",
		"parameter_schema_id",
		"randomness_policy_id",
		"result_visibility_policy_id",
		"atomic_group_id",
	]:
		if not WIRE.is_stable_id(operation.get(field)):
			return WIRE.invalid_result("semantic_operation.%s_invalid" % field)
	if not WIRE.DOMAIN_IDS.has(str(operation.get("domain_id", ""))):
		return WIRE.invalid_result("semantic_operation.domain_id_unknown")
	if not WIRE.is_positive_integer(operation.get("operation_version")):
		return WIRE.invalid_result("semantic_operation.operation_version_invalid")
	if not WIRE.is_nonnegative_integer(operation.get("sequence_index")):
		return WIRE.invalid_result("semantic_operation.sequence_index_invalid")
	for field in ["target_binding_ids", "condition_binding_ids"]:
		var ids_error := WIRE.stable_id_array_error(operation.get(field), true)
		if not ids_error.is_empty():
			return WIRE.invalid_result("semantic_operation.%s_%s" % [field, ids_error])

	var operation_id := str(operation.get("operation_id", ""))
	if not operation_contracts.has(operation_id):
		return WIRE.invalid_result("semantic_operation.operation_id_unknown")
	var contract_variant: Variant = operation_contracts.get(operation_id)
	if not (contract_variant is Dictionary) or not WIRE.is_closed_data(contract_variant):
		return WIRE.invalid_result("semantic_operation.contract_invalid")
	var contract := contract_variant as Dictionary
	if not WIRE.exact_fields(contract, CONTRACT_FIELDS):
		return WIRE.invalid_result("semantic_operation.contract_fields_invalid")
	if not WIRE.is_positive_integer(contract.get("operation_version")) \
			or not WIRE.DOMAIN_IDS.has(str(contract.get("domain_id", ""))) \
			or not WIRE.is_stable_id(contract.get("parameter_schema_id")) \
			or not WIRE.is_stable_id(contract.get("randomness_mode_id")):
		return WIRE.invalid_result("semantic_operation.contract_values_invalid")
	if operation.get("operation_version") != contract.get("operation_version") \
			or operation.get("domain_id") != contract.get("domain_id") \
			or operation.get("parameter_schema_id") != contract.get("parameter_schema_id"):
		return WIRE.invalid_result("semantic_operation.contract_mismatch")

	var payload_error := WIRE.closed_payload_error(
		operation.get("parameters"),
		str(operation.get("parameter_schema_id", "")),
		parameter_schemas
	)
	if not payload_error.is_empty():
		return WIRE.invalid_result("semantic_operation.%s" % payload_error)
	var randomness_id := str(operation.get("randomness_policy_id", ""))
	if not randomness_policies.has(randomness_id):
		return WIRE.invalid_result("semantic_operation.randomness_policy_unknown")
	var randomness_variant: Variant = randomness_policies.get(randomness_id)
	var expected_mode_id := str(contract.get("randomness_mode_id", ""))
	if not (randomness_variant is Dictionary) \
			or not bool(RANDOMNESS.validate(
				randomness_variant,
				[randomness_id],
				[expected_mode_id]
			).get("valid", false)) \
			or str((randomness_variant as Dictionary).get("mode_id", "")) != expected_mode_id:
		return WIRE.invalid_result("semantic_operation.randomness_policy_mismatch")
	var visibility_id := str(operation.get("result_visibility_policy_id", ""))
	if not visibility_policies.has(visibility_id) \
			or not bool(VISIBILITY.validate(
				visibility_policies.get(visibility_id), [visibility_id]
			).get("valid", false)):
		return WIRE.invalid_result("semantic_operation.visibility_policy_unknown")
	return WIRE.valid_result()
