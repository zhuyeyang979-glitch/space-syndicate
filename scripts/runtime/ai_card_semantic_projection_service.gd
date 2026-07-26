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
const AUTHORIZED_SOURCE_RESULT_KEYS := [
	"schema_version", "accepted", "reason_id", "authorized_envelope_ref",
	"semantic_spec", "instance_decision_state", "authorization_receipt",
	"bundle_fingerprint",
]
const CANDIDATE_KEYS := [
	"schema_version", "action_id", "card_id", "source_slot", "source_revision",
	"world_revision", "target_identity", "legal", "rejection_reason_id",
	"activation_cost", "projected_outcomes", "uncertainty", "counter_risk",
	"information_scope_id", "explanation_tokens", "candidate_fingerprint",
]

@export var semantic_catalog_path := NodePath("../CardSemanticCatalogService")
@export var source_authorization_port_path: NodePath

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
var _semantic_catalog_service: CardSemanticCatalogService
var _source_authorization_port: CardSemanticSourceAuthorizationPort


func _ready() -> void:
	_resolve_semantic_catalog_service()
	_resolve_source_authorization_port()


func project_authorized_source(
	authorized_bundle: Dictionary,
	clipped_world_projection: Dictionary
) -> Array:
	_projection_request_count += 1
	var source_authorization_port := _resolve_source_authorization_port()
	if source_authorization_port == null:
		_unauthorized_provenance_count += 1
		return []
	var authorization := source_authorization_port.validate_authorized_bundle(
		authorized_bundle
	)
	if not _authorized_source_result_is_accepted(authorization):
		_unauthorized_provenance_count += 1
		return []
	var envelope := authorization.get("authorized_envelope_ref", {}) as Dictionary
	var semantic_spec := authorization.get("semantic_spec", {}) as Dictionary
	var decision_state := authorization.get(
		"instance_decision_state", {}
	) as Dictionary
	if not CARD_SEMANTIC_SCHEMA_V1.is_pure_data(semantic_spec):
		_invalid_spec_count += 1
		return []
	var state_error: String = CardInstanceDecisionStateV1.validation_error(
		decision_state
	)
	if not state_error.is_empty():
		_invalid_instance_count += 1
		return []
	var instance_state: Dictionary = CardInstanceDecisionStateV1.to_ai_projection_input(
		decision_state
	)
	return _project_neutral_candidates(
		semantic_spec,
		instance_state,
		clipped_world_projection,
		CardInstanceDecisionStateV1.is_available(decision_state),
		envelope,
		decision_state
	)


func project_candidates(
	semantic_spec: Dictionary,
	instance_state: Dictionary,
	world_projection: Dictionary
) -> Array:
	# Compatibility/test-only entry point for legacy detached fixtures.
	_projection_request_count += 1
	if not CARD_SEMANTIC_SCHEMA_V1.is_pure_data(semantic_spec):
		_invalid_spec_count += 1
		return []
	var catalog_service := _resolve_semantic_catalog_service()
	if catalog_service == null:
		_unauthorized_provenance_count += 1
		return []
	var authorization := catalog_service.authorize_semantic_spec(semantic_spec)
	if not bool(authorization.get("ok", false)):
		_unauthorized_provenance_count += 1
		return []
	var authorized_spec := authorization.get("spec", {}) as Dictionary
	return _project_neutral_candidates(
		authorized_spec,
		instance_state,
		world_projection,
		INPUT_V1.instance_is_available(instance_state)
	)


func _project_neutral_candidates(
	authorized_spec: Dictionary,
	instance_state: Dictionary,
	world_projection: Dictionary,
	instance_available: bool,
	authorized_envelope_ref: Dictionary = {},
	decision_state: Dictionary = {}
) -> Array:
	if str(authorized_spec.get("runtime_readiness_id", "")) != "active":
		_non_executable_readiness_count += 1
		return []
	if not INPUT_V1.instance_state_error(instance_state).is_empty():
		_invalid_instance_count += 1
		return []
	var observation_error: String = INPUT_V1.observation_error(world_projection)
	if not observation_error.is_empty():
		_count_boundary_error(observation_error, true)
		return []
	if not authorized_envelope_ref.is_empty():
		var source_boundary_error := _authorized_source_boundary_error(
			authorized_envelope_ref,
			decision_state,
			instance_state,
			world_projection
		)
		if not source_boundary_error.is_empty():
			_count_boundary_error(source_boundary_error, false)
			return []
	var boundary_error: String = INPUT_V1.cross_boundary_error(
		authorized_spec, instance_state, world_projection
	)
	if not boundary_error.is_empty():
		_count_boundary_error(boundary_error, false)
		return []
	if not instance_available:
		_unavailable_instance_count += 1
		return []
	var candidates: Array = []
	for target_variant in world_projection.get("legal_targets", []) as Array:
		candidates.append(_candidate_for_target(
			authorized_spec,
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


func _resolve_semantic_catalog_service() -> CardSemanticCatalogService:
	if _semantic_catalog_service != null and is_instance_valid(_semantic_catalog_service):
		return _semantic_catalog_service
	if semantic_catalog_path.is_empty():
		return null
	_semantic_catalog_service = get_node_or_null(
		semantic_catalog_path
	) as CardSemanticCatalogService
	return _semantic_catalog_service


func _resolve_source_authorization_port() -> CardSemanticSourceAuthorizationPort:
	if _source_authorization_port != null and is_instance_valid(
		_source_authorization_port
	):
		return _source_authorization_port
	if source_authorization_port_path.is_empty():
		return null
	_source_authorization_port = get_node_or_null(
		source_authorization_port_path
	) as CardSemanticSourceAuthorizationPort
	return _source_authorization_port


func _authorized_source_result_is_accepted(result: Dictionary) -> bool:
	if not CARD_SEMANTIC_SCHEMA_V1.is_pure_data(result) \
			or not _exact_keys(result, AUTHORIZED_SOURCE_RESULT_KEYS) \
			or not (result.get("schema_version") is int) \
			or int(result.get("schema_version", -1)) != SCHEMA_VERSION \
			or not (result.get("accepted") is bool) \
			or not bool(result.get("accepted", false)) \
			or str(result.get("reason_id", "")) != "authorized":
		return false
	for key in [
		"authorized_envelope_ref", "semantic_spec",
		"instance_decision_state", "authorization_receipt",
	]:
		if not (result.get(key) is Dictionary) \
				or (result.get(key) as Dictionary).is_empty():
			return false
	return result.get("bundle_fingerprint") is String


func _authorized_source_boundary_error(
	envelope: Dictionary,
	decision_state: Dictionary,
	instance: Dictionary,
	world: Dictionary
) -> String:
	var envelope_viewer := envelope.get("viewer_ref", {}) as Dictionary
	var state_viewer := decision_state.get("viewer_ref", {}) as Dictionary
	var viewer_actor_id := str(world.get("viewer_actor_id", ""))
	if viewer_actor_id != str(envelope_viewer.get("actor_ref_id", "")) \
			or viewer_actor_id != str(state_viewer.get("actor_ref_id", "")):
		return "unauthorized_viewer_identity"
	if str(world.get("source_kind", "")) != str(envelope.get("source_kind", "")) \
			or str(world.get("source_kind", "")) \
				!= str(decision_state.get("source_kind", "")):
		return "unauthorized_source_kind"
	if world.get("source_revision") != envelope.get("hand_source_revision") \
			or world.get("source_revision") != decision_state.get("source_revision"):
		return "stale_source_revision"
	if str(world.get("card_id", "")) != str(envelope.get("card_id", "")) \
			or str(world.get("card_id", "")) \
				!= str(decision_state.get("card_id", "")) \
			or str(world.get("card_id", "")) != str(instance.get("card_id", "")):
		return "unauthorized_card_identity"
	if str(world.get("instance_id", "")) \
			!= str(envelope.get("runtime_instance_id", "")) \
			or str(world.get("instance_id", "")) \
				!= str(decision_state.get("instance_id", "")) \
			or str(world.get("instance_id", "")) \
				!= str(instance.get("instance_id", "")):
		return "unauthorized_instance_identity"
	if int(world.get("source_slot", -1)) != int(envelope.get("source_slot", -2)) \
			or int(world.get("source_slot", -1)) \
				!= int(decision_state.get("source_slot", -2)) \
			or int(world.get("source_slot", -1)) \
				!= int(instance.get("source_slot", -2)):
		return "stale_source_slot"
	if world.get("instance_revision") != envelope.get("instance_revision") \
			or world.get("instance_revision") \
				!= decision_state.get("instance_revision") \
			or world.get("instance_revision") != instance.get("instance_revision"):
		return "stale_instance_revision"
	return ""


func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(str(key)):
			return false
	return true


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
