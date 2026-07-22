extends RefCounted
class_name AiBusinessCostDebitRequest

const SCHEMA_VERSION := 1
const SOURCE_AI_RUNTIME := &"ai_runtime_controller"

var schema_version := SCHEMA_VERSION
var request_id := ""
var player_index := -1
var business_action_id := ""
var product_id := ""
var public_region_id := ""
var business_cycle_revision := -1
var session_id := ""
var session_revision := -1
var simulation_step_index := -1
var cost_cents := 0
var policy_fingerprint := ""
var expected_availability_fingerprint := ""
var source: StringName = SOURCE_AI_RUNTIME
var request_fingerprint := ""


func seal() -> AiBusinessCostDebitRequest:
	request_fingerprint = recompute_fingerprint()
	return self


func canonical_payload() -> Dictionary:
	return {
		"schema_version": schema_version,
		"request_id": request_id,
		"player_index": player_index,
		"business_action_id": business_action_id,
		"product_id": product_id,
		"public_region_id": public_region_id,
		"business_cycle_revision": business_cycle_revision,
		"session_id": session_id,
		"session_revision": session_revision,
		"simulation_step_index": simulation_step_index,
		"cost_cents": cost_cents,
		"policy_fingerprint": policy_fingerprint,
		"expected_availability_fingerprint": expected_availability_fingerprint,
		"source": str(source),
	}


func recompute_fingerprint() -> String:
	return JSON.stringify(canonical_payload()).sha256_text()


func validation_report() -> Dictionary:
	var errors: Array[String] = []
	if schema_version != SCHEMA_VERSION:
		errors.append("ai_business_cost_schema_invalid")
	if not _canonical_identifier(request_id, 160):
		errors.append("ai_business_cost_request_id_invalid")
	if player_index < 0:
		errors.append("ai_business_cost_player_invalid")
	if not _canonical_identifier(business_action_id, 96):
		errors.append("ai_business_cost_action_id_invalid")
	if not _canonical_identifier(product_id, 96):
		errors.append("ai_business_cost_product_invalid")
	if not _canonical_identifier(public_region_id, 160):
		errors.append("ai_business_cost_region_invalid")
	if business_cycle_revision < 0:
		errors.append("ai_business_cost_cycle_invalid")
	if not _canonical_identifier(session_id, 160):
		errors.append("ai_business_cost_session_id_invalid")
	if session_revision < 0:
		errors.append("ai_business_cost_session_revision_invalid")
	if simulation_step_index <= 0:
		errors.append("ai_business_cost_simulation_step_invalid")
	if cost_cents <= 0:
		errors.append("ai_business_cost_amount_invalid")
	if not _is_sha256(policy_fingerprint):
		errors.append("ai_business_cost_policy_fingerprint_invalid")
	if not _is_sha256(expected_availability_fingerprint):
		errors.append("ai_business_cost_availability_fingerprint_invalid")
	if source != SOURCE_AI_RUNTIME:
		errors.append("ai_business_cost_source_invalid")
	if not _is_sha256(request_fingerprint) or request_fingerprint != recompute_fingerprint():
		errors.append("ai_business_cost_request_fingerprint_invalid")
	return {
		"valid": errors.is_empty(),
		"reason_code": "" if errors.is_empty() else errors[0],
		"errors": errors,
	}


func detached_copy() -> AiBusinessCostDebitRequest:
	var copy := AiBusinessCostDebitRequest.new()
	copy.schema_version = schema_version
	copy.request_id = request_id
	copy.player_index = player_index
	copy.business_action_id = business_action_id
	copy.product_id = product_id
	copy.public_region_id = public_region_id
	copy.business_cycle_revision = business_cycle_revision
	copy.session_id = session_id
	copy.session_revision = session_revision
	copy.simulation_step_index = simulation_step_index
	copy.cost_cents = cost_cents
	copy.policy_fingerprint = policy_fingerprint
	copy.expected_availability_fingerprint = expected_availability_fingerprint
	copy.source = source
	copy.request_fingerprint = request_fingerprint
	return copy


func _canonical_identifier(value: String, max_length: int) -> bool:
	return not value.is_empty() and value == value.strip_edges() and value.length() <= max_length


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value.to_lower().substr(index, 1)):
			return false
	return true
