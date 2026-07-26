extends RefCounted
class_name AuthorizedCardSemanticEnvelopeV1

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const SCHEMA_VERSION := 1
const SOURCE_KIND := "own_hand"
const VISIBILITY_SCOPE_ID := "actor_private"
const SOURCE_OWNER_ID := "world_session_state.actor_hand"
const ATTESTATION_PORT_ID := "ai_actor_hand_inventory_query_port"
const VIEWER_REF_FIELDS := [
	"schema_version",
	"actor_ref_id",
	"actor_index",
]
const BUILD_FIELDS := [
	"schema_version",
	"envelope_id",
	"request_id",
	"source_kind",
	"source_owner_id",
	"attestation_port_id",
	"visibility_scope_id",
	"viewer_ref",
	"session_id",
	"session_revision",
	"hand_source_revision",
	"hand_source_fingerprint",
	"card_id",
	"source_slot",
	"runtime_instance_id",
	"static_record_fingerprint",
	"source_definition_fingerprint",
	"semantic_fingerprint",
	"instance_revision",
	"instance_state_fingerprint",
	"authorization_receipt_ref",
]
const FIELDS := BUILD_FIELDS + ["envelope_fingerprint"]


static func build(unsealed: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) \
			or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "envelope_fingerprint")
	return sealed if bool(validate(sealed).get("valid", false)) else {}


static func validate(value: Variant) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.not_closed_data"
		)
	var envelope := value as Dictionary
	if not WIRE.exact_fields(envelope, FIELDS):
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.fields_invalid"
		)
	if envelope.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.schema_version_invalid"
		)
	if str(envelope.get("source_kind", "")) != SOURCE_KIND \
			or str(envelope.get("visibility_scope_id", "")) \
				!= VISIBILITY_SCOPE_ID \
			or str(envelope.get("source_owner_id", "")) != SOURCE_OWNER_ID \
			or str(envelope.get("attestation_port_id", "")) \
				!= ATTESTATION_PORT_ID:
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.authority_invalid"
		)
	for field in [
		"envelope_id",
		"request_id",
		"session_id",
		"runtime_instance_id",
		"authorization_receipt_ref",
	]:
		if not _is_runtime_id(envelope.get(field)):
			return WIRE.invalid_result(
				"authorized_card_semantic_envelope.%s_invalid" % field
			)
	var viewer_error := viewer_ref_error(envelope.get("viewer_ref"))
	if not viewer_error.is_empty():
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.%s" % viewer_error
		)
	if not WIRE.is_nonnegative_integer(envelope.get("session_revision")) \
			or not WIRE.is_nonnegative_integer(envelope.get("source_slot")):
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.revision_invalid"
		)
	if not WIRE.is_stable_id(envelope.get("card_id")):
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.card_id_invalid"
		)
	for field in [
		"hand_source_revision",
		"hand_source_fingerprint",
		"static_record_fingerprint",
		"source_definition_fingerprint",
		"semantic_fingerprint",
		"instance_revision",
		"instance_state_fingerprint",
	]:
		if not WIRE.is_fingerprint(envelope.get(field)):
			return WIRE.invalid_result(
				"authorized_card_semantic_envelope.%s_invalid" % field
			)
	if not WIRE.is_fingerprint(envelope.get("envelope_fingerprint")) \
			or str(envelope.get("envelope_fingerprint", "")) \
				!= WIRE.fingerprint(envelope, "envelope_fingerprint"):
		return WIRE.invalid_result(
			"authorized_card_semantic_envelope.fingerprint_invalid"
		)
	return WIRE.valid_result()


static func viewer_ref_error(value: Variant) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "viewer_ref_not_closed_data"
	var viewer_ref := value as Dictionary
	if not WIRE.exact_fields(viewer_ref, VIEWER_REF_FIELDS):
		return "viewer_ref_fields_invalid"
	if viewer_ref.get("schema_version") != SCHEMA_VERSION:
		return "viewer_ref_schema_version_invalid"
	if not WIRE.is_stable_id(viewer_ref.get("actor_ref_id")) \
			or not WIRE.is_nonnegative_integer(viewer_ref.get("actor_index")):
		return "viewer_ref_identity_invalid"
	return ""


static func _is_runtime_id(value: Variant) -> bool:
	return WIRE.is_ascii_reference(value) \
		and str(value) == str(value).strip_edges()
