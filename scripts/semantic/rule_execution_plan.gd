extends RefCounted
class_name RuleExecutionPlan

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const RANDOMNESS := preload("res://scripts/semantic/semantic_randomness_policy.gd")
const VISIBILITY := preload("res://scripts/semantic/semantic_visibility_policy.gd")
const SCHEMA_VERSION := 1
const BUILD_FIELDS := [
	"schema_version",
	"plan_id",
	"request_id",
	"ruleset_id",
	"rules_revision",
	"semantic_ref",
	"actor_ref",
	"source_instance_ref",
	"source_revision",
	"world_revision",
	"legality_proof_ref",
	"registry_fingerprint",
	"registry_revision",
	"resolved_target_bindings",
	"condition_proof_refs",
	"steps",
	"transaction_policy_id",
	"rng_precondition_revision",
	"visibility_policy_id",
]
const FIELDS := BUILD_FIELDS + ["plan_fingerprint"]
const STEP_FIELDS := [
	"schema_version",
	"operation_instance_id",
	"operation_id",
	"operation_version",
	"domain_id",
	"sequence_index",
	"atomic_group_id",
	"target_binding_refs",
	"condition_proof_refs",
	"parameter_schema_id",
	"parameters",
	"randomness_policy_id",
	"result_visibility_policy_id",
]
const OPERATION_CONTRACT_FIELDS := [
	"operation_version",
	"domain_id",
	"parameter_schema_id",
	"randomness_policy_id",
	"randomness_mode_id",
]


static func build(
	unsealed: Dictionary,
	operation_contracts: Dictionary,
	parameter_schemas: Dictionary,
	randomness_policies: Dictionary,
	visibility_policies: Dictionary
) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "plan_fingerprint")
	var report := validate(
		sealed,
		operation_contracts,
		parameter_schemas,
		randomness_policies,
		visibility_policies
	)
	return sealed if bool(report.get("valid", false)) else {}


static func validate(
	value: Variant,
	operation_contracts: Dictionary,
	parameter_schemas: Dictionary,
	randomness_policies: Dictionary,
	visibility_policies: Dictionary
) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("rule_execution_plan.not_closed_data")
	var plan := value as Dictionary
	if not WIRE.exact_fields(plan, FIELDS):
		return WIRE.invalid_result("rule_execution_plan.fields_invalid")
	if plan.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("rule_execution_plan.schema_version_invalid")
	for field in ["plan_id", "request_id", "ruleset_id", "transaction_policy_id", "visibility_policy_id"]:
		if not WIRE.is_stable_id(plan.get(field)):
			return WIRE.invalid_result("rule_execution_plan.%s_invalid" % field)
	var plan_visibility_id := str(plan.get("visibility_policy_id", ""))
	if not visibility_policies.has(plan_visibility_id) \
			or not bool(VISIBILITY.validate(
				visibility_policies.get(plan_visibility_id), [plan_visibility_id]
			).get("valid", false)):
		return WIRE.invalid_result("rule_execution_plan.visibility_policy_unknown")
	var nested_error := WIRE.semantic_definition_ref_error(plan.get("semantic_ref"))
	if nested_error.is_empty():
		nested_error = WIRE.entity_ref_error(plan.get("actor_ref"))
	if nested_error.is_empty():
		nested_error = WIRE.entity_ref_error(plan.get("source_instance_ref"))
	if nested_error.is_empty():
		nested_error = WIRE.legality_proof_ref_error(plan.get("legality_proof_ref"))
	if not nested_error.is_empty():
		return WIRE.invalid_result("rule_execution_plan.%s" % nested_error)
	for field in [
		"rules_revision",
		"source_revision",
		"world_revision",
		"registry_revision",
		"rng_precondition_revision",
	]:
		if not WIRE.is_nonnegative_integer(plan.get(field)):
			return WIRE.invalid_result("rule_execution_plan.%s_invalid" % field)
	if not WIRE.is_fingerprint(plan.get("registry_fingerprint")):
		return WIRE.invalid_result("rule_execution_plan.registry_fingerprint_invalid")
	var binding_error := _legality_binding_error(plan)
	if not binding_error.is_empty():
		return WIRE.invalid_result("rule_execution_plan.%s" % binding_error)

	var target_bindings: Variant = plan.get("resolved_target_bindings")
	if not (target_bindings is Array):
		return WIRE.invalid_result("rule_execution_plan.targets_not_array")
	var target_binding_ids: Array[String] = []
	for target_variant in target_bindings as Array:
		nested_error = WIRE.resolved_target_binding_error(target_variant)
		if not nested_error.is_empty():
			return WIRE.invalid_result("rule_execution_plan.%s" % nested_error)
		var target_id := str((target_variant as Dictionary).get("target_binding_id", ""))
		if target_binding_ids.has(target_id):
			return WIRE.invalid_result("rule_execution_plan.target_binding_duplicate")
		target_binding_ids.append(target_id)

	var proof_values: Variant = plan.get("condition_proof_refs")
	if not (proof_values is Array):
		return WIRE.invalid_result("rule_execution_plan.condition_proofs_not_array")
	var proof_binding_ids: Array[String] = []
	for proof_variant in proof_values as Array:
		nested_error = WIRE.condition_proof_ref_error(proof_variant)
		if not nested_error.is_empty():
			return WIRE.invalid_result("rule_execution_plan.%s" % nested_error)
		var proof_id := str((proof_variant as Dictionary).get("condition_binding_id", ""))
		if proof_binding_ids.has(proof_id):
			return WIRE.invalid_result("rule_execution_plan.condition_proof_duplicate")
		proof_binding_ids.append(proof_id)

	var steps_value: Variant = plan.get("steps")
	if not (steps_value is Array) or (steps_value as Array).is_empty():
		return WIRE.invalid_result("rule_execution_plan.steps_invalid")
	var operation_instance_ids: Array[String] = []
	for index in range((steps_value as Array).size()):
		var step_error := _step_error(
			(steps_value as Array)[index],
			index,
			operation_contracts,
			parameter_schemas,
			randomness_policies,
			visibility_policies,
			target_binding_ids,
			proof_binding_ids
		)
		if not step_error.is_empty():
			return WIRE.invalid_result("rule_execution_plan.%s" % step_error)
		var instance_id := str(((steps_value as Array)[index] as Dictionary).get("operation_instance_id", ""))
		if operation_instance_ids.has(instance_id):
			return WIRE.invalid_result("rule_execution_plan.operation_instance_duplicate")
		operation_instance_ids.append(instance_id)
	if not WIRE.is_fingerprint(plan.get("plan_fingerprint")) \
			or str(plan.get("plan_fingerprint", "")) != WIRE.fingerprint(plan, "plan_fingerprint"):
		return WIRE.invalid_result("rule_execution_plan.fingerprint_invalid")
	return WIRE.valid_result()


static func _legality_binding_error(plan: Dictionary) -> String:
	var proof := plan.get("legality_proof_ref", {}) as Dictionary
	var semantic_ref := plan.get("semantic_ref", {}) as Dictionary
	var actor_ref := plan.get("actor_ref", {}) as Dictionary
	var source_instance_ref := plan.get("source_instance_ref", {}) as Dictionary
	for pair in [
		["request_id", plan.get("request_id")],
		["ruleset_id", plan.get("ruleset_id")],
		["rules_revision", plan.get("rules_revision")],
		["source_revision", plan.get("source_revision")],
		["world_revision", plan.get("world_revision")],
		["registry_revision", plan.get("registry_revision")],
		["rng_precondition_revision", plan.get("rng_precondition_revision")],
		["semantic_definition_revision", semantic_ref.get("definition_revision")],
		["actor_revision", actor_ref.get("revision")],
		["source_instance_revision", source_instance_ref.get("revision")],
		["semantic_fingerprint", semantic_ref.get("semantic_fingerprint")],
		["registry_fingerprint", plan.get("registry_fingerprint")],
	]:
		if proof.get(pair[0]) != pair[1]:
			return "legality_proof_%s_mismatch" % pair[0]
	if plan.get("source_revision") != source_instance_ref.get("revision"):
		return "source_instance_revision_mismatch"
	return ""


static func _step_error(
	value: Variant,
	expected_sequence_index: int,
	operation_contracts: Dictionary,
	parameter_schemas: Dictionary,
	randomness_policies: Dictionary,
	visibility_policies: Dictionary,
	known_target_binding_ids: Array[String],
	known_condition_binding_ids: Array[String]
) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "step_not_closed_data"
	var step := value as Dictionary
	if not WIRE.exact_fields(step, STEP_FIELDS):
		return "step_fields_invalid"
	if step.get("schema_version") != SCHEMA_VERSION:
		return "step_schema_version_invalid"
	for field in [
		"operation_instance_id",
		"operation_id",
		"atomic_group_id",
		"parameter_schema_id",
		"randomness_policy_id",
		"result_visibility_policy_id",
	]:
		if not WIRE.is_stable_id(step.get(field)):
			return "step_%s_invalid" % field
	if not WIRE.DOMAIN_IDS.has(str(step.get("domain_id", ""))):
		return "step_domain_id_unknown"
	if not WIRE.is_positive_integer(step.get("operation_version")) \
			or step.get("sequence_index") != expected_sequence_index:
		return "step_sequence_or_version_invalid"
	for pair in [
		["target_binding_refs", known_target_binding_ids],
		["condition_proof_refs", known_condition_binding_ids],
	]:
		var ids_error := WIRE.stable_id_array_error(step.get(pair[0]), true)
		if not ids_error.is_empty():
			return "step_%s_%s" % [pair[0], ids_error]
		for ref_id in step.get(pair[0]) as Array:
			if not (pair[1] as Array).has(str(ref_id)):
				return "step_%s_unknown" % pair[0]
	var operation_id := str(step.get("operation_id", ""))
	if not operation_contracts.has(operation_id):
		return "step_operation_id_unknown"
	var contract_variant: Variant = operation_contracts.get(operation_id)
	if not (contract_variant is Dictionary) \
			or not WIRE.exact_fields(contract_variant as Dictionary, OPERATION_CONTRACT_FIELDS):
		return "step_operation_contract_invalid"
	var contract := contract_variant as Dictionary
	if not WIRE.is_positive_integer(contract.get("operation_version")) \
			or not WIRE.DOMAIN_IDS.has(str(contract.get("domain_id", ""))) \
			or not WIRE.is_stable_id(contract.get("parameter_schema_id")) \
			or not WIRE.is_stable_id(contract.get("randomness_policy_id")) \
			or not WIRE.is_stable_id(contract.get("randomness_mode_id")):
		return "step_operation_contract_values_invalid"
	if step.get("operation_version") != contract.get("operation_version") \
			or step.get("domain_id") != contract.get("domain_id") \
			or step.get("parameter_schema_id") != contract.get("parameter_schema_id"):
		return "step_operation_contract_mismatch"
	var payload_error := WIRE.closed_payload_error(
		step.get("parameters"), str(step.get("parameter_schema_id", "")), parameter_schemas
	)
	if not payload_error.is_empty():
		return "step_%s" % payload_error
	var randomness_id := str(step.get("randomness_policy_id", ""))
	if randomness_id != str(contract.get("randomness_policy_id", "")):
		return "step_randomness_policy_contract_mismatch"
	if not randomness_policies.has(randomness_id):
		return "step_randomness_policy_invalid"
	var randomness_variant: Variant = randomness_policies.get(randomness_id)
	var expected_mode_id := str(contract.get("randomness_mode_id", ""))
	if not (randomness_variant is Dictionary) \
			or not bool(RANDOMNESS.validate(
				randomness_variant,
				[randomness_id],
				[expected_mode_id]
			).get("valid", false)) \
			or str((randomness_variant as Dictionary).get("mode_id", "")) != expected_mode_id:
		return "step_randomness_policy_invalid"
	var visibility_id := str(step.get("result_visibility_policy_id", ""))
	if str((randomness_variant as Dictionary).get("result_visibility_policy_id", "")) \
			!= visibility_id:
		return "step_randomness_result_visibility_mismatch"
	if not visibility_policies.has(visibility_id) \
			or not bool(VISIBILITY.validate(
				visibility_policies.get(visibility_id), [visibility_id]
			).get("valid", false)):
		return "step_visibility_policy_unknown"
	return ""
