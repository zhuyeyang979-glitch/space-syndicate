extends RefCounted
class_name AiCardInteractionPolicyCompatibilityV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const AUTHORIZED_ENVELOPE := preload(
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd"
)

const SCHEMA_VERSION := 1
const POLICY_COMPATIBILITY_ID := "legacy_ai_card_interaction_flat_fields_v1"
const SOURCE_KIND := "own_hand"
const VISIBILITY_SCOPE_ID := "actor_private"
const CORE_FIELDS := [
	"schema_version",
	"policy_compatibility_id",
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
	"static_record_fingerprint",
	"authorized_bundle_fingerprint",
	"policy_interaction_kind_id",
	"policy_discard_count",
	"policy_steal_count",
	"policy_lock_duration_microseconds",
	"policy_cash_penalty",
	"policy_steal_failure_cash",
]
const FIELDS := CORE_FIELDS + ["policy_compatibility_fingerprint"]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, CORE_FIELDS):
		return {}
	var viewer_ref_value: Variant = unsealed.get("viewer_ref")
	if not (viewer_ref_value is Dictionary):
		return {}
	var profile := unsealed.duplicate(true)
	profile["viewer_ref"] = (viewer_ref_value as Dictionary).duplicate(true)
	profile["policy_compatibility_fingerprint"] = WIRE.fingerprint(profile)
	return profile if bool(validate(profile).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.not_closed_data"
		)
	var profile := value as Dictionary
	if not WIRE.exact_fields(profile, FIELDS):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.fields_invalid"
		)
	if profile.get("schema_version") != SCHEMA_VERSION \
			or str(profile.get("policy_compatibility_id", "")) \
				!= POLICY_COMPATIBILITY_ID:
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.version_invalid"
		)
	if str(profile.get("source_kind", "")) != SOURCE_KIND \
			or str(profile.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID:
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.scope_invalid"
		)
	var viewer_error := AUTHORIZED_ENVELOPE.viewer_ref_error(
		profile.get("viewer_ref")
	)
	if not viewer_error.is_empty():
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.%s" % viewer_error
		)
	var viewer_ref := profile.get("viewer_ref", {}) as Dictionary
	var actor_index := int(viewer_ref.get("actor_index", -1))
	if str(viewer_ref.get("actor_ref_id", "")) != "player.%d" % actor_index:
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.viewer_binding_invalid"
		)
	if not _is_runtime_id(profile.get("session_id")) \
			or not _is_runtime_id(profile.get("instance_id")):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.runtime_id_invalid"
		)
	if not WIRE.is_nonnegative_integer(profile.get("session_revision")) \
			or not WIRE.is_nonnegative_integer(profile.get("source_slot")):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.revision_invalid"
		)
	if not WIRE.is_stable_id(profile.get("card_id")):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.card_id_invalid"
		)
	for field in [
		"source_revision",
		"instance_revision",
		"source_attestation_fingerprint",
		"static_record_fingerprint",
		"authorized_bundle_fingerprint",
	]:
		if not WIRE.is_fingerprint(profile.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_policy_compatibility.%s_invalid" % field
			)
	if not WIRE.is_stable_id(profile.get("policy_interaction_kind_id")):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.kind_invalid"
		)
	for field in [
		"policy_discard_count",
		"policy_steal_count",
		"policy_lock_duration_microseconds",
		"policy_cash_penalty",
		"policy_steal_failure_cash",
	]:
		if not WIRE.is_nonnegative_integer(profile.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_policy_compatibility.%s_invalid" % field
			)
	if not WIRE.is_fingerprint(profile.get(
		"policy_compatibility_fingerprint"
	)) or str(profile.get("policy_compatibility_fingerprint", "")) \
			!= WIRE.fingerprint(profile, "policy_compatibility_fingerprint"):
		return WIRE.invalid_result(
			"ai_card_interaction_policy_compatibility.fingerprint_invalid"
		)
	return WIRE.valid_result()


static func _is_runtime_id(value: Variant) -> bool:
	return WIRE.is_ascii_reference(value) \
		and str(value) == str(value).strip_edges()
