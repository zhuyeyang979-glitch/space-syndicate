extends RefCounted
class_name AiActionCandidate

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OUTCOME_VECTOR := preload("res://scripts/semantic/ai_outcome_vector.gd")
const SCHEMA_VERSION := 1
const BUILD_FIELDS := [
	"schema_version",
	"candidate_id",
	"action_id",
	"action_kind_id",
	"semantic_ref",
	"actor_ref",
	"source_instance_ref",
	"target_identities",
	"source_revision",
	"world_revision",
	"legality_revision",
	"legal",
	"rejection_reason_id",
	"activation_requirements",
	"outcome_vector",
	"uncertainty",
	"counter_risk",
	"information_scope_id",
	"explanation_token_ids",
	"plan_preview_fingerprint",
]
const FIELDS := BUILD_FIELDS + ["candidate_fingerprint"]
const FORBIDDEN_KEYS := [
	"raw_skill",
	"effect_payload",
	"semantic_spec_body",
	"rule_execution_plan",
	"ai_value",
	"policy_weight",
	"hidden_reasoning",
	"opponent_private_value",
	"opponent_private_hand",
	"opponent_hand",
	"private_hand",
	"hidden_card",
	"mutation_callback",
	"hidden_owner",
	"rival_private",
	"rival_hand",
	"save_payload",
	"rng_state",
]


static func build(unsealed: Dictionary, activation_schemas: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "candidate_fingerprint")
	var report := validate(sealed, activation_schemas)
	return sealed if bool(report.get("valid", false)) else {}


static func validate(value: Variant, activation_schemas: Dictionary) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("ai_action_candidate.not_closed_data")
	if WIRE.contains_key_recursive(value, FORBIDDEN_KEYS):
		return WIRE.invalid_result("ai_action_candidate.forbidden_information")
	var candidate := value as Dictionary
	if not WIRE.exact_fields(candidate, FIELDS):
		return WIRE.invalid_result("ai_action_candidate.fields_invalid")
	if candidate.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("ai_action_candidate.schema_version_invalid")
	for field in [
		"candidate_id",
		"action_id",
		"action_kind_id",
		"rejection_reason_id",
		"information_scope_id",
	]:
		if not WIRE.is_stable_id(candidate.get(field)):
			return WIRE.invalid_result("ai_action_candidate.%s_invalid" % field)
	if str(candidate.get("information_scope_id", "")) != "actor_private":
		return WIRE.invalid_result("ai_action_candidate.information_scope_invalid")
	var nested_error := WIRE.semantic_definition_ref_error(candidate.get("semantic_ref"))
	if nested_error.is_empty():
		nested_error = WIRE.entity_ref_error(candidate.get("actor_ref"))
	if nested_error.is_empty():
		nested_error = WIRE.entity_ref_error(candidate.get("source_instance_ref"))
	if not nested_error.is_empty():
		return WIRE.invalid_result("ai_action_candidate.%s" % nested_error)
	var target_value: Variant = candidate.get("target_identities")
	if not (target_value is Array):
		return WIRE.invalid_result("ai_action_candidate.targets_not_array")
	var target_ids: Array[String] = []
	for target_variant in target_value as Array:
		nested_error = WIRE.entity_ref_error(target_variant)
		if not nested_error.is_empty():
			return WIRE.invalid_result("ai_action_candidate.%s" % nested_error)
		var target := target_variant as Dictionary
		var target_key := "%s|%s" % [target.get("entity_type_id", ""), target.get("entity_id", "")]
		if target_ids.has(target_key):
			return WIRE.invalid_result("ai_action_candidate.target_duplicate")
		target_ids.append(target_key)
	for field in ["source_revision", "world_revision", "legality_revision"]:
		if not WIRE.is_nonnegative_integer(candidate.get(field)):
			return WIRE.invalid_result("ai_action_candidate.%s_invalid" % field)
	if not (candidate.get("legal") is bool):
		return WIRE.invalid_result("ai_action_candidate.legal_invalid")
	if bool(candidate.get("legal", false)) \
			and str(candidate.get("rejection_reason_id", "")) != "none":
		return WIRE.invalid_result("ai_action_candidate.legal_rejection_mismatch")
	if not bool(candidate.get("legal", false)) \
			and str(candidate.get("rejection_reason_id", "")) == "none":
		return WIRE.invalid_result("ai_action_candidate.rejection_reason_missing")
	var action_kind_id := str(candidate.get("action_kind_id", ""))
	var activation_error := WIRE.closed_payload_error(
		candidate.get("activation_requirements"), action_kind_id, activation_schemas
	)
	if not activation_error.is_empty():
		return WIRE.invalid_result("ai_action_candidate.%s" % activation_error)
	var outcome_report := OUTCOME_VECTOR.validate(candidate.get("outcome_vector"))
	if not bool(outcome_report.get("valid", false)):
		return WIRE.invalid_result("ai_action_candidate.outcome_vector_invalid")
	for field in ["uncertainty", "counter_risk"]:
		if not WIRE.is_nonnegative_integer(candidate.get(field)) \
				or int(candidate.get(field, -1)) > 100:
			return WIRE.invalid_result("ai_action_candidate.%s_invalid" % field)
	if int(candidate.get("counter_risk", -1)) \
			!= int((candidate.get("outcome_vector", {}) as Dictionary).get("counter_risk", -2)):
		return WIRE.invalid_result("ai_action_candidate.counter_risk_mismatch")
	var token_error := WIRE.stable_id_array_error(candidate.get("explanation_token_ids"), true)
	if not token_error.is_empty():
		return WIRE.invalid_result("ai_action_candidate.explanation_tokens_%s" % token_error)
	if not WIRE.is_fingerprint(candidate.get("plan_preview_fingerprint")):
		return WIRE.invalid_result("ai_action_candidate.plan_preview_fingerprint_invalid")
	if not WIRE.is_fingerprint(candidate.get("candidate_fingerprint")) \
			or str(candidate.get("candidate_fingerprint", "")) \
			!= WIRE.fingerprint(candidate, "candidate_fingerprint"):
		return WIRE.invalid_result("ai_action_candidate.fingerprint_invalid")
	return WIRE.valid_result()
