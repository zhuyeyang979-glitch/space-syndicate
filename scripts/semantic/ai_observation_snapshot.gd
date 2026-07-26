extends RefCounted
class_name AiObservationSnapshot

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SCHEMA_VERSION := 1
const BUILD_FIELDS := [
	"schema_version",
	"observation_id",
	"viewer_actor_ref",
	"session_revision",
	"world_revision",
	"projection_manifest_fingerprint",
	"public_slices",
	"actor_private_slices",
	"authorized_action_source_refs",
	"visibility_receipt_ref",
]
const FIELDS := BUILD_FIELDS + ["snapshot_fingerprint"]
const SLICE_BUILD_FIELDS := [
	"schema_version",
	"domain_id",
	"schema_id",
	"slice_schema_version",
	"source_revision",
	"facts",
]
const SLICE_FIELDS := SLICE_BUILD_FIELDS + ["slice_fingerprint"]
const SLICE_SCHEMA_FIELDS := [
	"slice_schema_version",
	"visibility_scope_id",
	"required_fields",
	"optional_fields",
	"field_kinds",
]
const FORBIDDEN_INFORMATION_KEYS := [
	"opponent_private_hand",
	"opponent_hand",
	"opponent_hidden_card_identity",
	"opponent_private_card",
	"private_hand",
	"private_card",
	"hidden_card",
	"hidden_monster_control",
	"rival_ai_state",
	"rival_hand",
	"authorization_capability",
	"authorization_token",
	"capability_token",
	"save_payload",
	"rng_state",
	"unclipped_owner_snapshot",
	"hidden_owner",
	"private_owner",
	"rival_private",
]


static func build(unsealed: Dictionary, slice_schemas: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "snapshot_fingerprint")
	var report := validate(sealed, slice_schemas)
	return sealed if bool(report.get("valid", false)) else {}


static func build_slice(unsealed: Dictionary, slice_schemas: Dictionary) -> Dictionary:
	if not WIRE.is_closed_data(unsealed) or not WIRE.exact_fields(unsealed, SLICE_BUILD_FIELDS):
		return {}
	var sealed := WIRE.sealed_copy(unsealed, "slice_fingerprint")
	return sealed if _slice_error(sealed, slice_schemas, "").is_empty() else {}


static func validate(value: Variant, slice_schemas: Dictionary) -> Dictionary:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return WIRE.invalid_result("ai_observation.not_closed_data")
	if WIRE.contains_key_recursive(value, FORBIDDEN_INFORMATION_KEYS):
		return WIRE.invalid_result("ai_observation.forbidden_information_before_projection")
	var snapshot := value as Dictionary
	if not WIRE.exact_fields(snapshot, FIELDS):
		return WIRE.invalid_result("ai_observation.fields_invalid")
	if snapshot.get("schema_version") != SCHEMA_VERSION:
		return WIRE.invalid_result("ai_observation.schema_version_invalid")
	if not WIRE.is_stable_id(snapshot.get("observation_id")) \
			or not WIRE.is_stable_id(snapshot.get("visibility_receipt_ref")):
		return WIRE.invalid_result("ai_observation.identity_invalid")
	var actor_error := WIRE.entity_ref_error(snapshot.get("viewer_actor_ref"))
	if not actor_error.is_empty():
		return WIRE.invalid_result("ai_observation.%s" % actor_error)
	for field in ["session_revision", "world_revision"]:
		if not WIRE.is_nonnegative_integer(snapshot.get(field)):
			return WIRE.invalid_result("ai_observation.%s_invalid" % field)
	if not WIRE.is_fingerprint(snapshot.get("projection_manifest_fingerprint")):
		return WIRE.invalid_result("ai_observation.projection_manifest_fingerprint_invalid")

	var observed_slice_keys: Array[String] = []
	for slice_group in [
		["public_slices", "public"],
		["actor_private_slices", "actor_private"],
	]:
		var slices: Variant = snapshot.get(slice_group[0])
		if not (slices is Array):
			return WIRE.invalid_result("ai_observation.%s_not_array" % slice_group[0])
		for slice_variant in slices as Array:
			var slice_error := _slice_error(slice_variant, slice_schemas, str(slice_group[1]))
			if not slice_error.is_empty():
				return WIRE.invalid_result("ai_observation.%s" % slice_error)
			var observation_slice := slice_variant as Dictionary
			var slice_key := "%s|%s|%s" % [
				observation_slice.get("domain_id", ""),
				observation_slice.get("schema_id", ""),
				observation_slice.get("source_revision", 0),
			]
			if observed_slice_keys.has(slice_key):
				return WIRE.invalid_result("ai_observation.slice_duplicate")
			observed_slice_keys.append(slice_key)

	var source_refs: Variant = snapshot.get("authorized_action_source_refs")
	if not (source_refs is Array):
		return WIRE.invalid_result("ai_observation.action_source_refs_not_array")
	var source_ids: Array[String] = []
	for ref_variant in source_refs as Array:
		var ref_error := WIRE.entity_ref_error(ref_variant)
		if not ref_error.is_empty():
			return WIRE.invalid_result("ai_observation.%s" % ref_error)
		var ref := ref_variant as Dictionary
		var source_id := "%s|%s" % [ref.get("entity_type_id", ""), ref.get("entity_id", "")]
		if source_ids.has(source_id):
			return WIRE.invalid_result("ai_observation.action_source_ref_duplicate")
		source_ids.append(source_id)
	if not WIRE.is_fingerprint(snapshot.get("snapshot_fingerprint")) \
			or str(snapshot.get("snapshot_fingerprint", "")) \
			!= WIRE.fingerprint(snapshot, "snapshot_fingerprint"):
		return WIRE.invalid_result("ai_observation.fingerprint_invalid")
	return WIRE.valid_result()


static func _slice_error(
	value: Variant,
	slice_schemas: Dictionary,
	expected_visibility_scope_id: String
) -> String:
	if not (value is Dictionary) or not WIRE.is_closed_data(value):
		return "slice_not_closed_data"
	if WIRE.contains_key_recursive(value, FORBIDDEN_INFORMATION_KEYS):
		return "forbidden_information_before_projection"
	var observation_slice := value as Dictionary
	if not WIRE.exact_fields(observation_slice, SLICE_FIELDS):
		return "slice_fields_invalid"
	if observation_slice.get("schema_version") != SCHEMA_VERSION:
		return "slice_schema_version_invalid"
	if not WIRE.DOMAIN_IDS.has(str(observation_slice.get("domain_id", ""))) \
			or not WIRE.is_stable_id(observation_slice.get("schema_id")):
		return "slice_identity_invalid"
	if not WIRE.is_positive_integer(observation_slice.get("slice_schema_version")) \
			or not WIRE.is_nonnegative_integer(observation_slice.get("source_revision")):
		return "slice_revision_invalid"
	var schema_id := str(observation_slice.get("schema_id", ""))
	if not slice_schemas.has(schema_id):
		return "slice_schema_unknown"
	var descriptor_variant: Variant = slice_schemas.get(schema_id)
	if not (descriptor_variant is Dictionary) or not WIRE.is_closed_data(descriptor_variant):
		return "slice_schema_descriptor_invalid"
	var descriptor := descriptor_variant as Dictionary
	if not WIRE.exact_fields(descriptor, SLICE_SCHEMA_FIELDS):
		return "slice_schema_descriptor_fields_invalid"
	if observation_slice.get("slice_schema_version") != descriptor.get("slice_schema_version"):
		return "slice_schema_version_mismatch"
	if not expected_visibility_scope_id.is_empty() \
			and str(descriptor.get("visibility_scope_id", "")) != expected_visibility_scope_id:
		return "slice_visibility_scope_mismatch"
	var parameter_descriptor := {
		"required_fields": (descriptor.get("required_fields", []) as Array).duplicate(),
		"optional_fields": (descriptor.get("optional_fields", []) as Array).duplicate(),
		"field_kinds": (descriptor.get("field_kinds", {}) as Dictionary).duplicate(true),
	}
	var facts_error := WIRE.closed_payload_error(
		observation_slice.get("facts"), schema_id, {schema_id: parameter_descriptor}
	)
	if not facts_error.is_empty():
		return "slice_%s" % facts_error
	if not WIRE.is_fingerprint(observation_slice.get("slice_fingerprint")) \
			or str(observation_slice.get("slice_fingerprint", "")) \
			!= WIRE.fingerprint(observation_slice, "slice_fingerprint"):
		return "slice_fingerprint_invalid"
	return ""
