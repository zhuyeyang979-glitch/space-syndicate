extends RefCounted
class_name AiCardInteractionLegacySourceBundleV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const CARD_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const POLICY_COMPATIBILITY := preload(
	"res://scripts/semantic/ai_card_interaction_policy_compatibility_v1.gd"
)
const AUTHORIZED_ENVELOPE := preload(
	"res://scripts/cards/semantic/authorized_card_semantic_envelope_v1.gd"
)

const SCHEMA_VERSION := 1
const SOURCE_KIND := "own_hand"
const VISIBILITY_SCOPE_ID := "actor_private"
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
	"semantic_card_id",
	"semantic_fingerprint",
	"runtime_readiness_id",
	"effect_ops",
	"policy_compatibility_profile",
	"source_attestation_fingerprint",
	"legacy_definition_fingerprint",
	"effect_witness_fingerprint",
	"source_authorization_fingerprint",
]
const FIELDS := [
	"schema_version",
	"source_bundle_id",
	"viewer_ref",
	"visibility_scope_id",
	"source_kind",
	"session_id",
	"session_revision",
	"source_revision",
	"source_slot",
	"instance_id",
	"instance_revision",
	"semantic_card_id",
	"semantic_fingerprint",
	"runtime_readiness_id",
	"effect_ops",
	"policy_compatibility_profile",
	"source_attestation_fingerprint",
	"legacy_definition_fingerprint",
	"effect_witness_fingerprint",
	"source_authorization_fingerprint",
	"source_bundle_fingerprint",
]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, CORE_FIELDS):
		return {}
	if not (unsealed.get("viewer_ref") is Dictionary) \
			or not (unsealed.get("effect_ops") is Array) \
			or not (unsealed.get("policy_compatibility_profile") is Dictionary):
		return {}
	var source_authorization_fingerprint := str(unsealed.get(
		"source_authorization_fingerprint",
		""
	))
	if not WIRE.is_fingerprint(source_authorization_fingerprint):
		return {}
	var bundle := {
		"schema_version": unsealed.get("schema_version"),
		"source_bundle_id": "ai-card-v04-interaction-source:%s" \
			% source_authorization_fingerprint,
		"viewer_ref": (unsealed.get("viewer_ref", {}) as Dictionary).duplicate(
			true
		),
		"visibility_scope_id": unsealed.get("visibility_scope_id"),
		"source_kind": unsealed.get("source_kind"),
		"session_id": unsealed.get("session_id"),
		"session_revision": unsealed.get("session_revision"),
		"source_revision": unsealed.get("source_revision"),
		"source_slot": unsealed.get("source_slot"),
		"instance_id": unsealed.get("instance_id"),
		"instance_revision": unsealed.get("instance_revision"),
		"semantic_card_id": unsealed.get("semantic_card_id"),
		"semantic_fingerprint": unsealed.get("semantic_fingerprint"),
		"runtime_readiness_id": unsealed.get("runtime_readiness_id"),
		"effect_ops": (unsealed.get("effect_ops", []) as Array).duplicate(true),
		"policy_compatibility_profile": (
			unsealed.get("policy_compatibility_profile", {}) as Dictionary
		).duplicate(true),
		"source_attestation_fingerprint": unsealed.get(
			"source_attestation_fingerprint"
		),
		"legacy_definition_fingerprint": unsealed.get(
			"legacy_definition_fingerprint"
		),
		"effect_witness_fingerprint": unsealed.get(
			"effect_witness_fingerprint"
		),
		"source_authorization_fingerprint": (
			source_authorization_fingerprint
		),
		"source_bundle_fingerprint": "",
	}
	bundle["source_bundle_fingerprint"] = WIRE.fingerprint(
		bundle,
		"source_bundle_fingerprint"
	)
	return bundle if bool(validate(bundle).get("valid", false)) else {}


static func validate(bundle: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(bundle) or not WIRE.exact_fields(bundle, FIELDS):
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.fields_invalid"
		)
	if bundle.get("schema_version") != SCHEMA_VERSION \
			or str(bundle.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID \
			or str(bundle.get("source_kind", "")) != SOURCE_KIND:
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.identity_invalid"
		)
	var viewer_error := AUTHORIZED_ENVELOPE.viewer_ref_error(
		bundle.get("viewer_ref")
	)
	if not viewer_error.is_empty():
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.%s" % viewer_error
		)
	var viewer_ref := bundle.get("viewer_ref", {}) as Dictionary
	var actor_index := int(viewer_ref.get("actor_index", -1))
	if str(viewer_ref.get("actor_ref_id", "")) != "player.%d" % actor_index:
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.viewer_binding_invalid"
		)
	for field in ["source_bundle_id", "session_id", "instance_id"]:
		if not WIRE.is_ascii_reference(bundle.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_legacy_source_bundle.%s_invalid" % field
			)
	if not WIRE.is_nonnegative_integer(bundle.get("session_revision")) \
			or not WIRE.is_nonnegative_integer(bundle.get("source_slot")) \
			or not WIRE.is_stable_id(bundle.get("semantic_card_id")) \
			or not WIRE.is_stable_id(bundle.get("runtime_readiness_id")):
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.scalar_invalid"
		)
	for field in [
		"source_revision",
		"instance_revision",
		"semantic_fingerprint",
		"source_attestation_fingerprint",
		"legacy_definition_fingerprint",
		"effect_witness_fingerprint",
		"source_authorization_fingerprint",
		"source_bundle_fingerprint",
	]:
		if not WIRE.is_fingerprint(bundle.get(field)):
			return WIRE.invalid_result(
				"ai_card_interaction_legacy_source_bundle.%s_invalid" % field
			)
	var effect_ops_value: Variant = bundle.get("effect_ops")
	if not (effect_ops_value is Array) \
			or (effect_ops_value as Array).is_empty() \
			or (effect_ops_value as Array).size() > 2:
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.effect_ops_invalid"
		)
	for op_value in effect_ops_value as Array:
		if not (op_value is Dictionary) \
				or not bool(CARD_SCHEMA.validate_effect_op(op_value).get(
					"valid",
					false
				)):
			return WIRE.invalid_result(
				"ai_card_interaction_legacy_source_bundle.effect_op_invalid"
			)
	var profile_value: Variant = bundle.get("policy_compatibility_profile")
	if not (profile_value is Dictionary) \
			or not bool(POLICY_COMPATIBILITY.validate(
				profile_value as Dictionary
			).get("valid", false)):
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.policy_invalid"
		)
	var profile := profile_value as Dictionary
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
	]:
		if profile.get(field) != bundle.get(field):
			return WIRE.invalid_result(
				"ai_card_interaction_legacy_source_bundle.policy_binding_invalid"
			)
	if profile.get("card_id") != bundle.get("semantic_card_id") \
			or profile.get("source_attestation_fingerprint") \
				!= bundle.get("source_attestation_fingerprint") \
			or profile.get("static_record_fingerprint") \
				!= bundle.get("legacy_definition_fingerprint") \
			or profile.get("authorized_bundle_fingerprint") \
				!= bundle.get("source_authorization_fingerprint"):
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.policy_binding_invalid"
		)
	if str(bundle.get("source_bundle_fingerprint", "")) \
			!= WIRE.fingerprint(bundle, "source_bundle_fingerprint"):
		return WIRE.invalid_result(
			"ai_card_interaction_legacy_source_bundle.fingerprint_invalid"
		)
	return WIRE.valid_result()
