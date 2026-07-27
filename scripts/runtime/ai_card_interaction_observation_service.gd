@tool
extends Node
class_name AiCardInteractionObservationService

const OBSERVATION := preload(
	"res://scripts/semantic/ai_card_interaction_observation_v1.gd"
)
const CARD_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const POLICY_COMPATIBILITY := preload(
	"res://scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd"
)
const OBSERVATION_CONSUMER_CAPABILITY := preload(
	"res://scripts/runtime/ai_card_interaction_observation_capability.gd"
)
const LEGACY_V04_SOURCE_BUNDLE := preload(
	"res://scripts/semantic/ai_card_interaction_legacy_source_bundle_v1.gd"
)

const ISSUED_OBSERVATION_LIMIT := 256
const REASON_READY := "none"
const REASON_DEPENDENCY_UNAVAILABLE := \
	"ai_card_interaction_observation.dependency_unavailable"
const REASON_CONSUMER_CAPABILITY_REJECTED := \
	"ai_card_interaction_observation.consumer_capability_rejected"
const REASON_AUTHORIZATION_REJECTED := \
	"ai_card_interaction_observation.authorization_rejected"
const REASON_BUNDLE_VALIDATION_REJECTED := \
	"ai_card_interaction_observation.bundle_validation_rejected"
const REASON_BUNDLE_SHAPE_INVALID := \
	"ai_card_interaction_observation.bundle_shape_invalid"
const REASON_SCOPE_INVALID := "ai_card_interaction_observation.scope_invalid"
const REASON_SEMANTIC_INVALID := \
	"ai_card_interaction_observation.semantic_invalid"
const REASON_EFFECT_OPS_INVALID := \
	"ai_card_interaction_observation.effect_ops_invalid"
const REASON_POLICY_COMPATIBILITY_REJECTED := \
	"ai_card_interaction_observation.policy_compatibility_rejected"
const REASON_POLICY_COMPATIBILITY_INVALID := \
	"ai_card_interaction_observation.policy_compatibility_invalid"
const REASON_OBSERVATION_BUILD_FAILED := \
	"ai_card_interaction_observation.build_failed"
const REASON_OBSERVATION_NOT_ISSUED := \
	"ai_card_interaction_observation.not_issued"
const REASON_OBSERVATION_BINDING_INVALID := \
	"ai_card_interaction_observation.issued_binding_invalid"

@export var source_authorization_port_path := NodePath(
	"../CardSemanticSourceAuthorizationPort"
)

var _observation_attempt_count := 0
var _authorization_success_count := 0
var _authorization_rejection_count := 0
var _bundle_validation_count := 0
var _bundle_validation_success_count := 0
var _bundle_validation_rejection_count := 0
var _semantic_derivation_count := 0
var _policy_compatibility_success_count := 0
var _policy_compatibility_rejection_count := 0
var _observation_success_count := 0
var _observation_validation_count := 0
var _observation_validation_success_count := 0
var _observation_validation_rejection_count := 0
var _issued_observation_eviction_count := 0
var _capability_bind_rejection_count := 0
var _rejection_count := 0
var _last_reason_id := REASON_DEPENDENCY_UNAVAILABLE
var _last_observation_fingerprint := ""
var _authorized_bundle_fingerprint_by_observation_fingerprint: Dictionary = {}
var _issued_observation_order: Array[String] = []
var _actor_capability_by_index: Dictionary = {}
var _actor_capabilities_bound := false
var _consumer_capability_by_actor: Dictionary = {}
var _consumer_capabilities_bound := false


func bind_consumer_capabilities(
	consumer_capabilities: Dictionary
) -> bool:
	if not _actor_capabilities_bound or consumer_capabilities.is_empty():
		_capability_bind_rejection_count += 1
		return false
	var normalized: Dictionary = {}
	for actor_index_variant in consumer_capabilities.keys():
		if not (actor_index_variant is int) or int(actor_index_variant) < 0:
			_capability_bind_rejection_count += 1
			return false
		var capability_variant: Variant = consumer_capabilities.get(
			actor_index_variant
		)
		if not (capability_variant is RefCounted) \
				or (capability_variant as RefCounted).get_script() \
					!= OBSERVATION_CONSUMER_CAPABILITY:
			_capability_bind_rejection_count += 1
			return false
		normalized[int(actor_index_variant)] = capability_variant
	if not _capability_values_are_unique(normalized):
		_capability_bind_rejection_count += 1
		return false
	if not _same_actor_indices(normalized, _actor_capability_by_index):
		_capability_bind_rejection_count += 1
		return false
	if _consumer_capabilities_bound:
		var matches := _same_capability_map(
			_consumer_capability_by_actor,
			normalized
		)
		if not matches:
			_capability_bind_rejection_count += 1
		return matches
	_consumer_capability_by_actor = normalized.duplicate()
	_consumer_capabilities_bound = true
	return true


func bind_actor_capabilities(actor_capabilities: Dictionary) -> bool:
	if actor_capabilities.is_empty():
		_capability_bind_rejection_count += 1
		return false
	var normalized: Dictionary = {}
	for actor_index_variant in actor_capabilities.keys():
		if not (actor_index_variant is int) or int(actor_index_variant) < 0:
			_capability_bind_rejection_count += 1
			return false
		var capability_variant: Variant = actor_capabilities.get(
			actor_index_variant
		)
		if not (capability_variant is AiActorHandInventoryCapability):
			_capability_bind_rejection_count += 1
			return false
		normalized[int(actor_index_variant)] = capability_variant
	if _actor_capabilities_bound:
		var matches := _same_capability_map(
			_actor_capability_by_index,
			normalized
		)
		if not matches:
			_capability_bind_rejection_count += 1
		return matches
	_actor_capability_by_index = normalized.duplicate()
	_actor_capabilities_bound = true
	return true


func is_ready() -> bool:
	var source_port := _source_authorization_port()
	return _actor_capabilities_bound \
		and not _actor_capability_by_index.is_empty() \
		and _consumer_capabilities_bound \
		and _same_actor_indices(
			_consumer_capability_by_actor,
			_actor_capability_by_index
		) \
		and source_port != null \
		and source_port.is_ready()


func observe_own_hand_interaction(
	consumer_capability: RefCounted,
	actor_index: int,
	slot_index: int
) -> Dictionary:
	_observation_attempt_count += 1
	if not _consumer_capability_matches(actor_index, consumer_capability):
		return _reject(REASON_CONSUMER_CAPABILITY_REJECTED)
	var source_port := _source_authorization_port()
	if source_port == null or not is_ready() \
			or not _actor_capability_by_index.has(actor_index):
		return _reject(REASON_DEPENDENCY_UNAVAILABLE)
	var capability := _actor_capability_by_index.get(actor_index) \
		as AiActorHandInventoryCapability
	if capability == null:
		return _reject(REASON_DEPENDENCY_UNAVAILABLE)

	var bundle := source_port.authorize_own_hand_card(
		capability,
		actor_index,
		slot_index
	)
	if not bool(bundle.get("accepted", false)):
		var legacy_source_result := source_port \
			.authorize_own_hand_v04_interaction_observation_source(
				capability,
				actor_index,
				slot_index
			)
		if bool(legacy_source_result.get("accepted", false)):
			_authorization_success_count += 1
			return _observation_from_legacy_v04_source(
				legacy_source_result.get("source_bundle", {}) as Dictionary
			)
		_authorization_rejection_count += 1
		return _reject(_source_reason(
			REASON_AUTHORIZATION_REJECTED,
			str(bundle.get("reason_id", ""))
		))
	_authorization_success_count += 1

	_bundle_validation_count += 1
	var validated_bundle := bundle.duplicate(true)
	bundle.clear()
	if not bool(validated_bundle.get("accepted", false)) \
			or str(validated_bundle.get("reason_id", "")) != "authorized":
		_bundle_validation_rejection_count += 1
		return _reject(_source_reason(
			REASON_BUNDLE_VALIDATION_REJECTED,
			str(validated_bundle.get("reason_id", ""))
		))
	_bundle_validation_success_count += 1

	var envelope_value: Variant = validated_bundle.get("authorized_envelope_ref")
	var semantic_value: Variant = validated_bundle.get("semantic_spec")
	var state_value: Variant = validated_bundle.get("instance_decision_state")
	var receipt_value: Variant = validated_bundle.get("authorization_receipt")
	if not (envelope_value is Dictionary) \
			or not (semantic_value is Dictionary) \
			or not (state_value is Dictionary) \
			or not (receipt_value is Dictionary):
		return _reject(REASON_BUNDLE_SHAPE_INVALID)
	var envelope := envelope_value as Dictionary
	var semantic_spec := semantic_value as Dictionary
	var instance_state := state_value as Dictionary
	var receipt := receipt_value as Dictionary
	if str(envelope.get("source_kind", "")) != OBSERVATION.SOURCE_KIND \
			or str(envelope.get("visibility_scope_id", "")) \
				!= OBSERVATION.VISIBILITY_SCOPE_ID \
			or str(instance_state.get("source_kind", "")) \
				!= OBSERVATION.SOURCE_KIND \
			or str(instance_state.get("visibility_scope_id", "")) \
				!= OBSERVATION.VISIBILITY_SCOPE_ID:
		return _reject(REASON_SCOPE_INVALID)
	if not bool(CARD_SCHEMA.validate_semantic_spec(semantic_spec).get(
		"valid",
		false
	)):
		return _reject(REASON_SEMANTIC_INVALID)
	var policy_result := source_port \
		.authorize_own_hand_interaction_policy_compatibility(
			capability,
			actor_index,
			slot_index,
			validated_bundle
		)
	if not bool(policy_result.get("accepted", false)):
		_policy_compatibility_rejection_count += 1
		validated_bundle.clear()
		return _reject(_source_reason(
			REASON_POLICY_COMPATIBILITY_REJECTED,
			str(policy_result.get("reason_id", ""))
		))
	var policy_value: Variant = policy_result.get(
		"policy_compatibility_profile"
	)
	if not (policy_value is Dictionary):
		_policy_compatibility_rejection_count += 1
		validated_bundle.clear()
		return _reject(REASON_POLICY_COMPATIBILITY_INVALID)
	var policy_profile := policy_value as Dictionary
	if not bool(POLICY_COMPATIBILITY.validate(policy_profile).get(
		"valid",
		false
	)) or not _policy_profile_matches_bundle(
		policy_profile,
		envelope,
		instance_state,
		receipt,
		str(validated_bundle.get("bundle_fingerprint", ""))
	):
		_policy_compatibility_rejection_count += 1
		policy_result.clear()
		validated_bundle.clear()
		return _reject(REASON_POLICY_COMPATIBILITY_INVALID)
	_policy_compatibility_success_count += 1

	_semantic_derivation_count += 1
	var interaction_facts := _interaction_facts_from_effect_ops(
		semantic_spec.get("effect_ops")
	)
	if not bool(interaction_facts.get("valid", false)):
		return _reject(_source_reason(
			REASON_EFFECT_OPS_INVALID,
			str(interaction_facts.get("reason_id", ""))
		))
	var observation := OBSERVATION.build({
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"viewer_ref": (envelope.get("viewer_ref", {}) as Dictionary).duplicate(
			true
		),
		"visibility_scope_id": OBSERVATION.VISIBILITY_SCOPE_ID,
		"source_kind": OBSERVATION.SOURCE_KIND,
		"session_id": str(envelope.get("session_id", "")),
		"session_revision": int(envelope.get("session_revision", -1)),
		"source_revision": str(instance_state.get("source_revision", "")),
		"source_slot": int(instance_state.get("source_slot", -1)),
		"instance_id": str(instance_state.get("instance_id", "")),
		"instance_revision": str(instance_state.get("instance_revision", "")),
		"card_id": str(instance_state.get("card_id", "")),
		"semantic_fingerprint": str(semantic_spec.get(
			"semantic_fingerprint",
			""
		)),
		"runtime_readiness_id": str(semantic_spec.get(
			"runtime_readiness_id",
			""
		)),
		"semantic_interaction_kind_id": str(interaction_facts.get(
			"interaction_kind_id",
			""
		)),
		"semantic_discard_count": int(interaction_facts.get(
			"discard_count",
			-1
		)),
		"semantic_steal_count": int(interaction_facts.get(
			"steal_count",
			-1
		)),
		"semantic_lock_duration_seconds": int(interaction_facts.get(
			"lock_duration_seconds",
			-1
		)),
		"semantic_cash_penalty": int(interaction_facts.get(
			"cash_penalty",
			-1
		)),
		"semantic_steal_failure_cash": int(interaction_facts.get(
			"steal_failure_cash",
			-1
		)),
		"policy_compatibility_id": str(policy_profile.get(
			"policy_compatibility_id",
			""
		)),
		"policy_interaction_kind_id": str(policy_profile.get(
			"policy_interaction_kind_id",
			""
		)),
		"policy_discard_count": int(policy_profile.get(
			"policy_discard_count",
			-1
		)),
		"policy_steal_count": int(policy_profile.get(
			"policy_steal_count",
			-1
		)),
		"policy_lock_duration_microseconds": int(policy_profile.get(
			"policy_lock_duration_microseconds",
			-1
		)),
		"policy_cash_penalty": int(policy_profile.get(
			"policy_cash_penalty",
			-1
		)),
		"policy_steal_failure_cash": int(policy_profile.get(
			"policy_steal_failure_cash",
			-1
		)),
		"policy_compatibility_fingerprint": str(policy_profile.get(
			"policy_compatibility_fingerprint",
			""
		)),
		"authorization_receipt_ref": str(envelope.get(
			"authorization_receipt_ref",
			""
		)),
		"authorization_receipt_fingerprint": str(receipt.get(
			"receipt_fingerprint",
			""
		)),
		"authorized_bundle_fingerprint": str(validated_bundle.get(
			"bundle_fingerprint",
			""
		)),
		"source_attestation_fingerprint": str(receipt.get(
			"source_attestation_fingerprint",
			""
		)),
	})
	policy_result.clear()
	validated_bundle.clear()
	if observation.is_empty():
		return _reject(REASON_OBSERVATION_BUILD_FAILED)
	if not _remember_issued_observation(observation):
		return _reject(REASON_OBSERVATION_BINDING_INVALID)
	_observation_success_count += 1
	_last_reason_id = REASON_READY
	_last_observation_fingerprint = str(observation.get(
		"observation_fingerprint",
		""
	))
	return observation.duplicate(true)


func _observation_from_legacy_v04_source(source_bundle: Dictionary) -> Dictionary:
	_bundle_validation_count += 1
	if not bool(LEGACY_V04_SOURCE_BUNDLE.validate(source_bundle).get(
		"valid",
		false
	)):
		_bundle_validation_rejection_count += 1
		return _reject(REASON_BUNDLE_VALIDATION_REJECTED)
	_bundle_validation_success_count += 1
	var profile := source_bundle.get(
		"policy_compatibility_profile",
		{}
	) as Dictionary
	if not bool(POLICY_COMPATIBILITY.validate(profile).get("valid", false)):
		_policy_compatibility_rejection_count += 1
		return _reject(REASON_POLICY_COMPATIBILITY_INVALID)
	_policy_compatibility_success_count += 1
	_semantic_derivation_count += 1
	var interaction_facts := _interaction_facts_from_effect_ops(
		source_bundle.get("effect_ops")
	)
	if not bool(interaction_facts.get("valid", false)) \
			or not _semantic_facts_match_policy(interaction_facts, profile):
		return _reject(REASON_EFFECT_OPS_INVALID)
	var observation := OBSERVATION.build({
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"viewer_ref": (
			source_bundle.get("viewer_ref", {}) as Dictionary
		).duplicate(true),
		"visibility_scope_id": OBSERVATION.VISIBILITY_SCOPE_ID,
		"source_kind": OBSERVATION.SOURCE_KIND,
		"session_id": str(source_bundle.get("session_id", "")),
		"session_revision": int(source_bundle.get("session_revision", -1)),
		"source_revision": str(source_bundle.get("source_revision", "")),
		"source_slot": int(source_bundle.get("source_slot", -1)),
		"instance_id": str(source_bundle.get("instance_id", "")),
		"instance_revision": str(source_bundle.get("instance_revision", "")),
		"card_id": str(source_bundle.get("semantic_card_id", "")),
		"semantic_fingerprint": str(source_bundle.get(
			"semantic_fingerprint",
			""
		)),
		"runtime_readiness_id": str(source_bundle.get(
			"runtime_readiness_id",
			""
		)),
		"semantic_interaction_kind_id": str(interaction_facts.get(
			"interaction_kind_id",
			""
		)),
		"semantic_discard_count": int(interaction_facts.get(
			"discard_count",
			-1
		)),
		"semantic_steal_count": int(interaction_facts.get(
			"steal_count",
			-1
		)),
		"semantic_lock_duration_seconds": int(interaction_facts.get(
			"lock_duration_seconds",
			-1
		)),
		"semantic_cash_penalty": int(interaction_facts.get(
			"cash_penalty",
			-1
		)),
		"semantic_steal_failure_cash": int(interaction_facts.get(
			"steal_failure_cash",
			-1
		)),
		"policy_compatibility_id": str(profile.get(
			"policy_compatibility_id",
			""
		)),
		"policy_interaction_kind_id": str(profile.get(
			"policy_interaction_kind_id",
			""
		)),
		"policy_discard_count": int(profile.get("policy_discard_count", -1)),
		"policy_steal_count": int(profile.get("policy_steal_count", -1)),
		"policy_lock_duration_microseconds": int(profile.get(
			"policy_lock_duration_microseconds",
			-1
		)),
		"policy_cash_penalty": int(profile.get("policy_cash_penalty", -1)),
		"policy_steal_failure_cash": int(profile.get(
			"policy_steal_failure_cash",
			-1
		)),
		"policy_compatibility_fingerprint": str(profile.get(
			"policy_compatibility_fingerprint",
			""
		)),
		"authorization_receipt_ref": str(source_bundle.get(
			"source_bundle_id",
			""
		)),
		"authorization_receipt_fingerprint": str(source_bundle.get(
			"source_authorization_fingerprint",
			""
		)),
		"authorized_bundle_fingerprint": str(source_bundle.get(
			"source_authorization_fingerprint",
			""
		)),
		"source_attestation_fingerprint": str(source_bundle.get(
			"source_attestation_fingerprint",
			""
		)),
	})
	if observation.is_empty():
		return _reject(REASON_OBSERVATION_BUILD_FAILED)
	if not _remember_issued_observation(observation):
		return _reject(REASON_OBSERVATION_BINDING_INVALID)
	_observation_success_count += 1
	_last_reason_id = REASON_READY
	_last_observation_fingerprint = str(observation.get(
		"observation_fingerprint",
		""
	))
	return observation.duplicate(true)


func validate_observation(
	consumer_capability: RefCounted,
	actor_index: int,
	observation: Dictionary
) -> Dictionary:
	_observation_validation_count += 1
	if not _consumer_capability_matches(actor_index, consumer_capability):
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_CONSUMER_CAPABILITY_REJECTED)
	var schema_report := OBSERVATION.validate(observation)
	if not bool(schema_report.get("valid", false)):
		_observation_validation_rejection_count += 1
		return schema_report.duplicate(true)
	var observation_fingerprint := str(observation.get(
		"observation_fingerprint",
		""
	))
	if not _authorized_bundle_fingerprint_by_observation_fingerprint.has(
		observation_fingerprint
	):
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_OBSERVATION_NOT_ISSUED)
	if str(_authorized_bundle_fingerprint_by_observation_fingerprint.get(
		observation_fingerprint,
		""
	)) != str(observation.get("authorized_bundle_fingerprint", "")):
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_OBSERVATION_BINDING_INVALID)
	var viewer_ref := observation.get("viewer_ref", {}) as Dictionary
	var observed_actor_index := int(viewer_ref.get("actor_index", -1))
	var source_slot := int(observation.get("source_slot", -1))
	if observed_actor_index != actor_index \
			or not _actor_capability_by_index.has(actor_index):
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_OBSERVATION_BINDING_INVALID)
	var capability := _actor_capability_by_index.get(actor_index) \
		as AiActorHandInventoryCapability
	var source_port := _source_authorization_port()
	if capability == null or source_port == null:
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_DEPENDENCY_UNAVAILABLE)
	var current_bundle := source_port.authorize_own_hand_card(
		capability,
		actor_index,
		source_slot
	)
	if not bool(current_bundle.get("accepted", false)):
		var legacy_source_result := source_port \
			.authorize_own_hand_v04_interaction_observation_source(
				capability,
				actor_index,
				source_slot
			)
		var legacy_source_value: Variant = legacy_source_result.get(
			"source_bundle"
		)
		if bool(legacy_source_result.get("accepted", false)) \
				and legacy_source_value is Dictionary:
			var legacy_source := legacy_source_value as Dictionary
			var legacy_profile := legacy_source.get(
				"policy_compatibility_profile",
				{}
			) as Dictionary
			if bool(LEGACY_V04_SOURCE_BUNDLE.validate(legacy_source).get(
				"valid",
				false
			)) \
					and str(legacy_source.get(
						"source_authorization_fingerprint",
						""
					)) == str(observation.get(
						"authorized_bundle_fingerprint",
						""
					)) \
					and str(legacy_source.get("source_bundle_id", "")) \
						== str(observation.get(
							"authorization_receipt_ref",
							""
						)) \
					and str(legacy_source.get("semantic_card_id", "")) \
						== str(observation.get("card_id", "")) \
					and str(legacy_source.get(
						"semantic_fingerprint",
						""
					)) == str(observation.get(
						"semantic_fingerprint",
						""
					)) \
					and str(legacy_source.get(
						"runtime_readiness_id",
						""
					)) == str(observation.get(
						"runtime_readiness_id",
						""
					)) \
					and _policy_profile_matches_observation(
						legacy_profile,
						observation
					):
				_observation_validation_success_count += 1
				return WIRE.valid_result()
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_OBSERVATION_BINDING_INVALID)
	var validated_bundle := current_bundle.duplicate(true)
	current_bundle.clear()
	if not bool(validated_bundle.get("accepted", false)) \
			or str(validated_bundle.get("bundle_fingerprint", "")) \
				!= str(observation.get("authorized_bundle_fingerprint", "")):
		validated_bundle.clear()
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_OBSERVATION_BINDING_INVALID)
	var policy_result := source_port \
		.authorize_own_hand_interaction_policy_compatibility(
			capability,
			actor_index,
			source_slot,
			validated_bundle
		)
	var policy_value: Variant = policy_result.get(
		"policy_compatibility_profile"
	)
	if not bool(policy_result.get("accepted", false)) \
			or not (policy_value is Dictionary) \
			or not _policy_profile_matches_observation(
				policy_value as Dictionary,
				observation
			):
		policy_result.clear()
		validated_bundle.clear()
		_observation_validation_rejection_count += 1
		return WIRE.invalid_result(REASON_OBSERVATION_BINDING_INVALID)
	policy_result.clear()
	validated_bundle.clear()
	_observation_validation_success_count += 1
	return WIRE.valid_result()


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"service_ready": is_ready(),
		"observation_attempt_count": _observation_attempt_count,
		"authorization_success_count": _authorization_success_count,
		"authorization_rejection_count": _authorization_rejection_count,
		"bundle_validation_count": _bundle_validation_count,
		"bundle_validation_success_count": _bundle_validation_success_count,
		"bundle_validation_rejection_count": (
			_bundle_validation_rejection_count
		),
		"semantic_derivation_count": _semantic_derivation_count,
		"policy_compatibility_success_count": (
			_policy_compatibility_success_count
		),
		"policy_compatibility_rejection_count": (
			_policy_compatibility_rejection_count
		),
		"policy_compatibility_id": (
			POLICY_COMPATIBILITY.POLICY_COMPATIBILITY_ID
		),
		"observation_success_count": _observation_success_count,
		"observation_validation_count": _observation_validation_count,
		"observation_validation_success_count": (
			_observation_validation_success_count
		),
		"observation_validation_rejection_count": (
			_observation_validation_rejection_count
		),
		"issued_observation_fingerprint_count": (
			_issued_observation_order.size()
		),
		"issued_observation_fingerprint_limit": ISSUED_OBSERVATION_LIMIT,
		"issued_observation_eviction_count": (
			_issued_observation_eviction_count
		),
		"actor_capabilities_bound": _actor_capabilities_bound,
		"actor_capability_count": _actor_capability_by_index.size(),
		"consumer_capability_bound": _consumer_capabilities_bound,
		"consumer_capability_count": _consumer_capability_by_actor.size(),
		"exposes_consumer_capability": false,
		"capability_bind_rejection_count": _capability_bind_rejection_count,
		"exposes_actor_capabilities": false,
		"issued_observation_journal_fingerprint": (
			_issued_observation_journal_fingerprint()
		),
		"rejection_count": _rejection_count,
		"last_reason_id": _last_reason_id,
		"last_observation_fingerprint": _last_observation_fingerprint,
		"stores_observation_payloads": false,
		"stores_card_records": false,
		"owns_save_state": false,
		"owns_rng": false,
	}


func _remember_issued_observation(observation: Dictionary) -> bool:
	var observation_fingerprint := str(observation.get(
		"observation_fingerprint",
		""
	))
	var bundle_fingerprint := str(observation.get(
		"authorized_bundle_fingerprint",
		""
	))
	if not WIRE.is_fingerprint(observation_fingerprint) \
			or not WIRE.is_fingerprint(bundle_fingerprint):
		return false
	if _authorized_bundle_fingerprint_by_observation_fingerprint.has(
		observation_fingerprint
	):
		return str(_authorized_bundle_fingerprint_by_observation_fingerprint.get(
			observation_fingerprint,
			""
		)) == bundle_fingerprint
	_authorized_bundle_fingerprint_by_observation_fingerprint[
		observation_fingerprint
	] = bundle_fingerprint
	_issued_observation_order.append(observation_fingerprint)
	while _issued_observation_order.size() > ISSUED_OBSERVATION_LIMIT:
		var evicted_fingerprint: String = _issued_observation_order.pop_front()
		_authorized_bundle_fingerprint_by_observation_fingerprint.erase(
			evicted_fingerprint
		)
		_issued_observation_eviction_count += 1
	return true


func _issued_observation_journal_fingerprint() -> String:
	return WIRE.fingerprint({
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"observation_fingerprints": _issued_observation_order,
	})


func _policy_profile_matches_bundle(
	profile: Dictionary,
	envelope: Dictionary,
	state: Dictionary,
	receipt: Dictionary,
	bundle_fingerprint: String
) -> bool:
	return bool(POLICY_COMPATIBILITY.validate(profile).get("valid", false)) \
		and profile.get("viewer_ref") == envelope.get("viewer_ref") \
		and profile.get("visibility_scope_id") \
			== envelope.get("visibility_scope_id") \
		and profile.get("source_kind") == envelope.get("source_kind") \
		and profile.get("session_id") == envelope.get("session_id") \
		and profile.get("session_revision") \
			== envelope.get("session_revision") \
		and profile.get("source_revision") \
			== state.get("source_revision") \
		and profile.get("source_slot") == state.get("source_slot") \
		and profile.get("instance_id") == state.get("instance_id") \
		and profile.get("instance_revision") \
			== state.get("instance_revision") \
		and profile.get("card_id") == state.get("card_id") \
		and profile.get("source_attestation_fingerprint") \
			== receipt.get("source_attestation_fingerprint") \
		and profile.get("static_record_fingerprint") \
			== receipt.get("static_record_fingerprint") \
		and str(profile.get("authorized_bundle_fingerprint", "")) \
			== bundle_fingerprint


func _policy_profile_matches_observation(
	profile: Dictionary,
	observation: Dictionary
) -> bool:
	if not bool(POLICY_COMPATIBILITY.validate(profile).get("valid", false)):
		return false
	for field in [
		"viewer_ref",
		"visibility_scope_id",
		"source_kind",
		"session_id",
		"session_revision",
		"source_revision",
		"source_slot",
		"instance_id",
		"instance_revision",
		"card_id",
		"source_attestation_fingerprint",
		"authorized_bundle_fingerprint",
		"policy_compatibility_id",
		"policy_interaction_kind_id",
		"policy_discard_count",
		"policy_steal_count",
		"policy_lock_duration_microseconds",
		"policy_cash_penalty",
		"policy_steal_failure_cash",
		"policy_compatibility_fingerprint",
	]:
		if profile.get(field) != observation.get(field):
			return false
	return true


func _interaction_facts_from_effect_ops(value: Variant) -> Dictionary:
	if not (value is Array):
		return _invalid_facts("not_array")
	var effect_ops := value as Array
	if effect_ops.is_empty() or effect_ops.size() > 2:
		return _invalid_facts("operation_count_invalid")
	var interaction_kind_id := ""
	var discard_count := 0
	var steal_count := 0
	var lock_duration_seconds := 0
	var cash_penalty := 0
	var steal_failure_cash := 0
	var primary_seen := false
	var lock_seen := false
	for index in range(effect_ops.size()):
		var op_value: Variant = effect_ops[index]
		if not (op_value is Dictionary) \
				or not bool(CARD_SCHEMA.validate_effect_op(op_value).get(
					"valid",
					false
				)):
			return _invalid_facts("operation_invalid")
		var op := op_value as Dictionary
		var op_id := str(op.get("op_id", ""))
		if op_id == "discard_random":
			if primary_seen or lock_seen or index != 0:
				return _invalid_facts("primary_operation_duplicate_or_misordered")
			primary_seen = true
			interaction_kind_id = "player_hand_disrupt"
			discard_count = int(op.get("count", 0))
			cash_penalty = int(op.get("target_cash_penalty", 0))
		elif op_id == "steal_random":
			if primary_seen or lock_seen or index != 0:
				return _invalid_facts("primary_operation_duplicate_or_misordered")
			primary_seen = true
			interaction_kind_id = "player_hand_steal"
			steal_count = int(op.get("count", 0))
			steal_failure_cash = int(op.get("steal_fail_cash", 0))
		elif op_id == "lock_random":
			if not primary_seen or lock_seen or index != effect_ops.size() - 1:
				return _invalid_facts("lock_operation_duplicate_or_misordered")
			lock_seen = true
			lock_duration_seconds = int(op.get("duration_seconds", 0))
		else:
			return _invalid_facts("operation_not_supported")
	if not primary_seen or interaction_kind_id.is_empty():
		return _invalid_facts("primary_operation_missing")
	return {
		"valid": true,
		"reason_id": REASON_READY,
		"interaction_kind_id": interaction_kind_id,
		"discard_count": discard_count,
		"steal_count": steal_count,
		"lock_duration_seconds": lock_duration_seconds,
		"cash_penalty": cash_penalty,
		"steal_failure_cash": steal_failure_cash,
	}


func _semantic_facts_match_policy(
	semantic_facts: Dictionary,
	policy_profile: Dictionary
) -> bool:
	return str(semantic_facts.get("interaction_kind_id", "")) \
			== str(policy_profile.get("policy_interaction_kind_id", "")) \
		and int(semantic_facts.get("discard_count", -1)) \
			== int(policy_profile.get("policy_discard_count", -2)) \
		and int(semantic_facts.get("steal_count", -1)) \
			== int(policy_profile.get("policy_steal_count", -2)) \
		and int(semantic_facts.get("lock_duration_seconds", -1)) * 1000000 \
			== int(policy_profile.get(
				"policy_lock_duration_microseconds",
				-2
			)) \
		and int(semantic_facts.get("cash_penalty", -1)) \
			== int(policy_profile.get("policy_cash_penalty", -2)) \
		and int(semantic_facts.get("steal_failure_cash", -1)) \
			== int(policy_profile.get("policy_steal_failure_cash", -2))


func _source_authorization_port() -> CardSemanticSourceAuthorizationPort:
	return get_node_or_null(source_authorization_port_path) \
		as CardSemanticSourceAuthorizationPort


func _same_capability_map(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for actor_index_variant in left.keys():
		if not right.has(actor_index_variant) \
				or left.get(actor_index_variant) != right.get(actor_index_variant):
			return false
	return true


func _same_actor_indices(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for actor_index_variant in left.keys():
		if not right.has(actor_index_variant):
			return false
	return true


func _capability_values_are_unique(capabilities: Dictionary) -> bool:
	var seen: Array[RefCounted] = []
	for capability_variant in capabilities.values():
		var capability := capability_variant as RefCounted
		if capability == null or seen.has(capability):
			return false
		seen.append(capability)
	return true


func _consumer_capability_matches(
	actor_index: int,
	capability: RefCounted
) -> bool:
	return actor_index >= 0 \
		and capability != null \
		and _consumer_capabilities_bound \
		and _consumer_capability_by_actor.has(actor_index) \
		and _consumer_capability_by_actor.get(actor_index) == capability


func _reject(reason_id: String) -> Dictionary:
	_rejection_count += 1
	_last_reason_id = reason_id
	return {}


func _invalid_facts(reason_id: String) -> Dictionary:
	return {
		"valid": false,
		"reason_id": reason_id,
	}


func _source_reason(prefix: String, source_reason_id: String) -> String:
	if source_reason_id.is_empty() or source_reason_id == REASON_READY:
		return prefix
	return "%s.%s" % [prefix, source_reason_id]
