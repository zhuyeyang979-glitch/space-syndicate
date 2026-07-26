@tool
extends Node
class_name AiCardSemanticProjectionService

# Orchestrates validated semantic specs, authorized observations, and neutral
# outcome projection. It owns no card rules, legality, policy score, or mutation.
const CARD_SEMANTIC_SCHEMA_V1 := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const INPUT_V1 := preload("res://scripts/runtime/ai_card_semantic_projection_input_v1.gd")
const OUTCOME_VECTOR_V1 := preload("res://scripts/runtime/ai_outcome_vector_v1.gd")
const SCHEMA_VERSION := 1
const INFORMATION_SCOPE_ID := "actor_private"
const ACTIVATION_COST_KEYS := CARD_SEMANTIC_SCHEMA_V1.ASSET_KEYS
const OUTCOME_DIMENSIONS := OUTCOME_VECTOR_V1.DIMENSIONS
const CANDIDATE_KEYS := [
	"schema_version", "action_id", "card_id", "source_slot", "source_revision",
	"world_revision", "target_identity", "legal", "rejection_reason_id",
	"activation_cost", "projected_outcomes", "uncertainty", "counter_risk",
	"information_scope_id", "explanation_tokens", "candidate_fingerprint",
]

var _projection_request_count := 0
var _projection_success_count := 0
var _candidate_emission_count := 0
var _invalid_spec_count := 0
var _non_executable_readiness_count := 0
var _invalid_instance_count := 0
var _invalid_world_projection_count := 0
var _unauthorized_provenance_count := 0
var _stale_revision_count := 0
var _unavailable_instance_count := 0


func project_candidates(
	semantic_spec: Dictionary,
	instance_state: Dictionary,
	world_projection: Dictionary
) -> Array:
	_projection_request_count += 1
	var semantic_validation: Dictionary = CARD_SEMANTIC_SCHEMA_V1.validate_semantic_spec(
		semantic_spec
	)
	if not CARD_SEMANTIC_SCHEMA_V1.is_pure_data(semantic_spec) \
			or not bool(semantic_validation.get("valid", false)):
		_invalid_spec_count += 1
		return []
	if str(semantic_spec.get("runtime_readiness_id", "")) != "active":
		_non_executable_readiness_count += 1
		return []
	if not INPUT_V1.instance_state_error(instance_state).is_empty():
		_invalid_instance_count += 1
		return []
	var observation_error: String = INPUT_V1.observation_error(world_projection)
	if not observation_error.is_empty():
		_count_boundary_error(observation_error, true)
		return []
	var boundary_error: String = INPUT_V1.cross_boundary_error(
		semantic_spec, instance_state, world_projection
	)
	if not boundary_error.is_empty():
		_count_boundary_error(boundary_error, false)
		return []
	if not INPUT_V1.instance_is_available(instance_state):
		_unavailable_instance_count += 1
		return []
	var candidates: Array = []
	for target_variant in world_projection.get("legal_targets", []) as Array:
		candidates.append(_candidate_for_target(
			semantic_spec,
			instance_state,
			world_projection,
			target_variant as Dictionary
		))
	_sort_candidates(candidates)
	_projection_success_count += 1
	_candidate_emission_count += candidates.size()
	return candidates.duplicate(true)


func debug_counters() -> Dictionary:
	return {
		"projection_request_count": _projection_request_count,
		"projection_success_count": _projection_success_count,
		"candidate_emission_count": _candidate_emission_count,
		"invalid_spec_count": _invalid_spec_count,
		"non_executable_readiness_count": _non_executable_readiness_count,
		"invalid_instance_count": _invalid_instance_count,
		"invalid_world_projection_count": _invalid_world_projection_count,
		"unauthorized_provenance_count": _unauthorized_provenance_count,
		"stale_revision_count": _stale_revision_count,
		"unavailable_instance_count": _unavailable_instance_count,
	}


func debug_snapshot() -> Dictionary:
	return debug_counters()


static func fingerprint_record(record: Dictionary, fingerprint_key: String) -> String:
	return CARD_SEMANTIC_SCHEMA_V1.fingerprint(record, fingerprint_key)


func _count_boundary_error(error_id: String, observation_validation: bool) -> void:
	if error_id.begins_with("stale_"):
		_stale_revision_count += 1
	elif error_id.begins_with("unauthorized_"):
		_unauthorized_provenance_count += 1
	elif observation_validation:
		_invalid_world_projection_count += 1
	else:
		_unauthorized_provenance_count += 1


func _candidate_for_target(
	spec: Dictionary,
	instance: Dictionary,
	world: Dictionary,
	target_fact: Dictionary
) -> Dictionary:
	var projection: Dictionary = OUTCOME_VECTOR_V1.project(spec, target_fact)
	var target_identity := (
		target_fact.get("target_identity", {}) as Dictionary
	).duplicate(true)
	var action_seed := [
		"ai_card_action_candidate_v1",
		str(instance.get("instance_id", "")),
		world.get("source_revision"),
		int(world.get("world_revision", -1)),
		str(spec.get("semantic_fingerprint", "")),
		target_identity,
	]
	var action_hash := CARD_SEMANTIC_SCHEMA_V1.canonical_json(action_seed).sha256_text()
	var activation_cost := (
		((spec.get("cost", {}) as Dictionary).get("activation", {}) as Dictionary)
	).duplicate(true)
	var candidate := {
		"schema_version": SCHEMA_VERSION,
		"action_id": "card_action.%s" % action_hash.substr(0, 24),
		"card_id": str(instance.get("card_id", "")),
		"source_slot": int(instance.get("source_slot", -1)),
		"source_revision": world.get("source_revision"),
		"world_revision": int(world.get("world_revision", -1)),
		"target_identity": target_identity,
		"legal": true,
		"rejection_reason_id": "none",
		"activation_cost": activation_cost,
		"projected_outcomes": (
			projection.get("projected_outcomes", {}) as Dictionary
		).duplicate(true),
		"uncertainty": int(projection.get("uncertainty", 0)),
		"counter_risk": int(projection.get("counter_risk", 0)),
		"information_scope_id": INFORMATION_SCOPE_ID,
		"explanation_tokens": (projection.get("explanation_tokens", []) as Array).duplicate(),
		"candidate_fingerprint": "",
	}
	candidate["candidate_fingerprint"] = CARD_SEMANTIC_SCHEMA_V1.fingerprint(
		candidate, "candidate_fingerprint"
	)
	return candidate


func _sort_candidates(candidates: Array) -> void:
	for index in range(1, candidates.size()):
		var current := candidates[index] as Dictionary
		var cursor := index - 1
		while cursor >= 0 and _candidate_sort_key(current) \
				< _candidate_sort_key(candidates[cursor] as Dictionary):
			candidates[cursor + 1] = candidates[cursor]
			cursor -= 1
		candidates[cursor + 1] = current


func _candidate_sort_key(candidate: Dictionary) -> String:
	var identity := candidate.get("target_identity", {}) as Dictionary
	return "%s|%s|%s|%s" % [
		str(identity.get("target_id", "")),
		str(identity.get("stable_id", "")),
		str(candidate.get("action_id", "")),
		str(candidate.get("candidate_fingerprint", "")),
	]
