extends RefCounted
class_name AiCardInteractionObservationV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AUTHORIZED_ENVELOPE := preload(
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd"
)
const POLICY_COMPATIBILITY := preload(
	"res://scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd"
)

const SCHEMA_VERSION := 1
const SOURCE_KIND := "own_hand"
const VISIBILITY_SCOPE_ID := "actor_private"
const INTERACTION_KIND_IDS := [
	"player_hand_disrupt",
	"player_hand_steal",
]
const CORE_FIELDS := [
	"schema_version",
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
	"semantic_fingerprint",
	"runtime_readiness_id",
	"semantic_interaction_kind_id",
	"semantic_discard_count",
	"semantic_steal_count",
	"semantic_lock_duration_seconds",
	"semantic_cash_penalty",
	"semantic_steal_failure_cash",
	"policy_compatibility_id",
	"policy_interaction_kind_id",
	"policy_discard_count",
	"policy_steal_count",
	"policy_lock_duration_microseconds",
	"policy_cash_penalty",
	"policy_steal_failure_cash",
	"policy_compatibility_fingerprint",
	"authorization_receipt_ref",
	"authorization_receipt_fingerprint",
	"authorized_bundle_fingerprint",
	"source_attestation_fingerprint",
]
const FIELDS := [
	"schema_version",
	"observation_id",
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
	"semantic_fingerprint",
	"runtime_readiness_id",
	"semantic_interaction_kind_id",
	"semantic_discard_count",
	"semantic_steal_count",
	"semantic_lock_duration_seconds",
	"semantic_cash_penalty",
	"semantic_steal_failure_cash",
	"policy_compatibility_id",
	"policy_interaction_kind_id",
	"policy_discard_count",
	"policy_steal_count",
	"policy_lock_duration_microseconds",
	"policy_cash_penalty",
	"policy_steal_failure_cash",
	"policy_compatibility_fingerprint",
	"authorization_receipt_ref",
	"authorization_receipt_fingerprint",
	"authorized_bundle_fingerprint",
	"source_attestation_fingerprint",
	"observation_fingerprint",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, CORE_FIELDS):
		return {}
	var viewer_ref_value: Variant = unsealed.get("viewer_ref")
	if not (viewer_ref_value is Dictionary):
		return {}
	var observation := {
		"schema_version": unsealed.get("schema_version"),
		"observation_id": _observation_id(unsealed),
		"viewer_ref": (viewer_ref_value as Dictionary).duplicate(true),
		"visibility_scope_id": unsealed.get("visibility_scope_id"),
		"source_kind": unsealed.get("source_kind"),
		"session_id": unsealed.get("session_id"),
		"session_revision": unsealed.get("session_revision"),
		"source_revision": unsealed.get("source_revision"),
		"source_slot": unsealed.get("source_slot"),
		"instance_id": unsealed.get("instance_id"),
		"instance_revision": unsealed.get("instance_revision"),
		"card_id": unsealed.get("card_id"),
		"semantic_fingerprint": unsealed.get("semantic_fingerprint"),
		"runtime_readiness_id": unsealed.get("runtime_readiness_id"),
		"semantic_interaction_kind_id": unsealed.get(
			"semantic_interaction_kind_id"
		),
		"semantic_discard_count": unsealed.get("semantic_discard_count"),
		"semantic_steal_count": unsealed.get("semantic_steal_count"),
		"semantic_lock_duration_seconds": unsealed.get(
			"semantic_lock_duration_seconds"
		),
		"semantic_cash_penalty": unsealed.get("semantic_cash_penalty"),
		"semantic_steal_failure_cash": unsealed.get(
			"semantic_steal_failure_cash"
		),
		"policy_compatibility_id": unsealed.get("policy_compatibility_id"),
		"policy_interaction_kind_id": unsealed.get(
			"policy_interaction_kind_id"
		),
		"policy_discard_count": unsealed.get("policy_discard_count"),
		"policy_steal_count": unsealed.get("policy_steal_count"),
		"policy_lock_duration_microseconds": unsealed.get(
			"policy_lock_duration_microseconds"
		),
		"policy_cash_penalty": unsealed.get("policy_cash_penalty"),
		"policy_steal_failure_cash": unsealed.get(
			"policy_steal_failure_cash"
		),
		"policy_compatibility_fingerprint": unsealed.get(
			"policy_compatibility_fingerprint"
		),
		"authorization_receipt_ref": unsealed.get(
			"authorization_receipt_ref"
		),
		"authorization_receipt_fingerprint": unsealed.get(
			"authorization_receipt_fingerprint"
		),
		"authorized_bundle_fingerprint": unsealed.get(
			"authorized_bundle_fingerprint"
		),
		"source_attestation_fingerprint": unsealed.get(
			"source_attestation_fingerprint"
		),
		"observation_fingerprint": "",
	}
	if str(observation.get("observation_id", "")).is_empty():
		return {}
	observation["observation_fingerprint"] = WIRE.fingerprint(
		observation,
		"observation_fingerprint"
	)
	return observation if bool(validate(observation).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.not_closed_data"
		)
	var observation := value as Dictionary
	if not WIRE.exact_fields(observation, FIELDS):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.fields_invalid"
		)
	if observation.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result(
			"ai_card_interaction_observation.schema_version_invalid"
		)
	if str(observation.get("source_kind", "")) != SOURCE_KIND \
			or str(observation.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID:
		return WIRE.invalid_result(
			"ai_card_interaction_observation.scope_invalid"
		)
	var viewer_error := AUTHORIZED_ENVELOPE.viewer_ref_error(
		observation.get("viewer_ref")
	)
	if not viewer_error.is_empty():
		return WIRE.invalid_result(
			"ai_card_interaction_observation.%s" % viewer_error
		)
	var viewer_ref := observation.get("viewer_ref", {}) as Dictionary
	var actor_index := int(viewer_ref.get("actor_index", -1))
	if str(viewer_ref.get("actor_ref_id", "")) != "player.%d" % actor_index:
		return WIRE.invalid_result(
			"ai_card_interaction_observation.viewer_ref_binding_invalid"
		)
	if not _is_runtime_id(observation.get("session_id")) \
			or not _is_runtime_id(observation.get("instance_id")) \
			or not _is_runtime_id(observation.get("authorization_receipt_ref")):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.runtime_id_invalid"
		)
	if not WIRE.is_nonnegative_integer(observation.get("session_revision")) \
			or not WIRE.is_nonnegative_integer(observation.get("source_slot")):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.revision_invalid"
		)
	if not WIRE.is_stable_id(observation.get("card_id")):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.card_id_invalid"
		)
	for field in [
		"source_revision",
		"instance_revision",
		"semantic_fingerprint",
		"authorization_receipt_fingerprint",
		"authorized_bundle_fingerprint",
		"source_attestation_fingerprint",
		"policy_compatibility_fingerprint",
	]:
		if not WIRE.is_fingerprint(observation.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_observation.%s_invalid" % field
			)
	if not WIRE.is_stable_id(observation.get("runtime_readiness_id")):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.readiness_invalid"
		)
	var interaction_kind_id := str(observation.get(
		"semantic_interaction_kind_id",
		""
	))
	if not INTERACTION_KIND_IDS.has(interaction_kind_id):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.semantic_kind_invalid"
		)
	for field in [
		"semantic_discard_count",
		"semantic_steal_count",
		"semantic_lock_duration_seconds",
		"semantic_cash_penalty",
		"semantic_steal_failure_cash",
	]:
		if not WIRE.is_nonnegative_integer(observation.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_observation.%s_invalid" % field
			)
	if not _semantic_values_match_kind(observation, interaction_kind_id):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.semantic_values_invalid"
		)
	if str(observation.get("policy_compatibility_id", "")) \
			!= POLICY_COMPATIBILITY.POLICY_COMPATIBILITY_ID \
			or not WIRE.is_stable_id(observation.get(
				"policy_interaction_kind_id"
			)):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.policy_compatibility_invalid"
		)
	for field in [
		"policy_discard_count",
		"policy_steal_count",
		"policy_lock_duration_microseconds",
		"policy_cash_penalty",
		"policy_steal_failure_cash",
	]:
		if not WIRE.is_nonnegative_integer(observation.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_observation.%s_invalid" % field
			)
	if not _is_runtime_id(observation.get("observation_id")) \
			or str(observation.get("observation_id", "")) \
				!= _expected_observation_id(observation):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.observation_id_invalid"
		)
	if not WIRE.is_fingerprint(observation.get("observation_fingerprint")) \
			or str(observation.get("observation_fingerprint", "")) \
				!= WIRE.fingerprint(observation, "observation_fingerprint"):
		return WIRE.invalid_result(
			"ai_card_interaction_observation.fingerprint_invalid"
		)
	return WIRE.valid_result()


static func validation_error(value: Variant) -> String:
	var report := validate(value)
	return "" if bool(report.get("valid", false)) else str(report.get(
		"reason_id",
		"ai_card_interaction_observation.invalid"
	))


static func _semantic_values_match_kind(
	observation: Dictionary,
	interaction_kind_id: String
) -> bool:
	if interaction_kind_id == "player_hand_disrupt":
		return WIRE.is_positive_integer(observation.get(
			"semantic_discard_count"
		)) \
			and int(observation.get("semantic_steal_count", -1)) == 0 \
			and int(observation.get(
				"semantic_steal_failure_cash",
				-1
			)) == 0
	if interaction_kind_id == "player_hand_steal":
		return WIRE.is_positive_integer(observation.get(
			"semantic_steal_count"
		)) \
			and int(observation.get("semantic_discard_count", -1)) == 0 \
			and int(observation.get("semantic_cash_penalty", -1)) == 0
	return false


static func _observation_id(core: Dictionary) -> String:
	var fingerprint := WIRE.fingerprint(core)
	return "ai-card-interaction-observation:%s" % fingerprint \
		if not fingerprint.is_empty() else ""


static func _expected_observation_id(observation: Dictionary) -> String:
	var core := observation.duplicate(true)
	core.erase("observation_id")
	core.erase("observation_fingerprint")
	return _observation_id(core)


static func _is_runtime_id(value: Variant) -> bool:
	return WIRE.is_ascii_reference(value) \
		and str(value) == str(value).strip_edges()
