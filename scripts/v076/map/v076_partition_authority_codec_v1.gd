@tool
extends RefCounted
class_name V076PartitionAuthorityCodecV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")

const SCHEMA_VERSION := 1
const GENERATOR_ID := "v076.shared_half_edge_spherical_partition.v1"
const DOMAIN_ID := "map.partition"
const COMMAND_TYPE := "generate_shared_half_edge_partition"
const REQUIRED_ACCEPTANCE_REGION_COUNTS := [6, 8, 12, 16, 20, 24, 30]
const SHAPE_COMPLEXITIES := ["SIMPLE", "STANDARD", "COMPLEX"]
const TERRAIN_TYPES := ["Land", "Ocean"]
const TERRAIN_FEATURE_FIELDS := [
	"continents",
	"bays",
	"peninsulas",
	"straits",
	"archipelagos",
]
const PARTITION_FIELDS := [
	"schema_version",
	"generator_id",
	"root_seed",
	"region_count",
	"shape_complexity",
	"topology_id",
	"topology_sha256",
	"topology_level",
	"microvertex_count",
	"microface_count",
	"mesh_edge_count",
	"half_edge_count",
	"region_ids",
	"seed_face_ids",
	"owner_by_face",
	"faces_by_region",
	"adjacency_by_region",
	"boundary_cycles_by_region",
	"shared_boundary_edges",
	"terrain_by_region",
	"terrain_by_face",
	"terrain_features",
	"rng_snapshot",
]
const DOMAIN_STATE_FIELDS := [
	"schema_version",
	"generation_count",
	"partition",
	"partition_sha256",
]


static func initial_domain_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"generation_count": 0,
		"partition": {},
		"partition_sha256": "",
	}


static func validate_request_payload(payload: Variant) -> Dictionary:
	if not (payload is Dictionary):
		return _invalid("v076_partition_payload_not_dictionary", "$.payload")
	var request := payload as Dictionary
	if request.size() != 2 or not request.has("region_count") or not request.has("shape_complexity"):
		return _invalid("v076_partition_payload_shape_invalid", "$.payload")
	if typeof(request.get("region_count")) != TYPE_INT:
		return _invalid("v076_partition_region_count_not_integer", "$.payload.region_count")
	if int(request.get("region_count", 0)) <= 0:
		return _invalid("v076_partition_region_count_not_positive", "$.payload.region_count")
	if typeof(request.get("shape_complexity")) != TYPE_STRING:
		return _invalid("v076_partition_shape_complexity_not_string", "$.payload.shape_complexity")
	if not SHAPE_COMPLEXITIES.has(str(request.get("shape_complexity", ""))):
		return _invalid("v076_partition_shape_complexity_unsupported", "$.payload.shape_complexity")
	return {"valid": true, "reason": "", "path": ""}


static func validate_partition_shape(partition: Variant) -> Dictionary:
	if not (partition is Dictionary):
		return _invalid("v076_partition_not_dictionary", "$.partition")
	var value := partition as Dictionary
	var fields := _validate_exact_fields(value, PARTITION_FIELDS, "$.partition")
	if not bool(fields.get("valid", false)):
		return fields
	var closed_data := StateCodec.validate(value, "$.partition")
	if not bool(closed_data.get("valid", false)):
		return closed_data
	for integer_field in [
		"schema_version", "root_seed", "region_count", "topology_level",
		"microvertex_count", "microface_count", "mesh_edge_count", "half_edge_count"
	]:
		if typeof(value.get(integer_field)) != TYPE_INT:
			return _invalid("v076_partition_integer_field_invalid", "$.partition.%s" % integer_field)
	for string_field in ["generator_id", "topology_id", "topology_sha256", "shape_complexity"]:
		if typeof(value.get(string_field)) != TYPE_STRING or str(value.get(string_field, "")).is_empty():
			return _invalid("v076_partition_string_field_invalid", "$.partition.%s" % string_field)
	if not SHAPE_COMPLEXITIES.has(str(value.get("shape_complexity", ""))):
		return _invalid("v076_partition_shape_complexity_unsupported", "$.partition.shape_complexity")
	for array_field in [
		"region_ids", "seed_face_ids", "owner_by_face", "faces_by_region",
		"adjacency_by_region", "boundary_cycles_by_region", "shared_boundary_edges",
		"terrain_by_region", "terrain_by_face"
	]:
		if not (value.get(array_field) is Array):
			return _invalid("v076_partition_array_field_invalid", "$.partition.%s" % array_field)
	var terrain_features: Variant = value.get("terrain_features")
	if not (terrain_features is Dictionary):
		return _invalid("v076_partition_terrain_features_not_dictionary", "$.partition.terrain_features")
	var terrain_feature_fields := _validate_exact_fields(
		terrain_features as Dictionary,
		TERRAIN_FEATURE_FIELDS,
		"$.partition.terrain_features"
	)
	if not bool(terrain_feature_fields.get("valid", false)):
		return terrain_feature_fields
	for feature_name in TERRAIN_FEATURE_FIELDS:
		if not ((terrain_features as Dictionary).get(feature_name) is Array):
			return _invalid("v076_partition_terrain_feature_not_array", "$.partition.terrain_features.%s" % feature_name)
	if not (value.get("rng_snapshot") is Dictionary):
		return _invalid("v076_partition_rng_snapshot_invalid", "$.partition.rng_snapshot")
	return {"valid": true, "reason": "", "path": ""}


static func validate_domain_state(state: Variant) -> Dictionary:
	if not (state is Dictionary):
		return _invalid("v076_partition_domain_state_not_dictionary", "$.state")
	var value := state as Dictionary
	var fields := _validate_exact_fields(value, DOMAIN_STATE_FIELDS, "$.state")
	if not bool(fields.get("valid", false)):
		return fields
	var closed_data := StateCodec.validate(value, "$.state")
	if not bool(closed_data.get("valid", false)):
		return closed_data
	if typeof(value.get("schema_version")) != TYPE_INT or int(value.get("schema_version", 0)) != SCHEMA_VERSION:
		return _invalid("v076_partition_domain_state_schema_invalid", "$.state.schema_version")
	if typeof(value.get("generation_count")) != TYPE_INT:
		return _invalid("v076_partition_generation_count_not_integer", "$.state.generation_count")
	var generation_count := int(value.get("generation_count", -1))
	if generation_count == 0:
		if not (value.get("partition") is Dictionary) or not (value.get("partition") as Dictionary).is_empty():
			return _invalid("v076_partition_initial_state_partition_not_empty", "$.state.partition")
		if typeof(value.get("partition_sha256")) != TYPE_STRING or not str(value.get("partition_sha256", "")).is_empty():
			return _invalid("v076_partition_initial_state_hash_not_empty", "$.state.partition_sha256")
		return {"valid": true, "reason": "", "path": ""}
	if generation_count != 1:
		return _invalid("v076_partition_generation_count_invalid", "$.state.generation_count")
	var partition_validation := validate_partition_shape(value.get("partition"))
	if not bool(partition_validation.get("valid", false)):
		return partition_validation
	if typeof(value.get("partition_sha256")) != TYPE_STRING:
		return _invalid("v076_partition_state_hash_not_string", "$.state.partition_sha256")
	var expected_sha := StateCodec.fingerprint(value.get("partition"))
	if expected_sha.is_empty() or str(value.get("partition_sha256", "")) != expected_sha:
		return _invalid("v076_partition_state_hash_mismatch", "$.state.partition_sha256")
	return {"valid": true, "reason": "", "path": ""}


static func fingerprint_partition(partition: Dictionary) -> String:
	var validation := validate_partition_shape(partition)
	return StateCodec.fingerprint(partition) if bool(validation.get("valid", false)) else ""


static func _validate_exact_fields(value: Dictionary, expected: Array, path: String) -> Dictionary:
	if value.size() != expected.size():
		return _invalid("v076_partition_field_count_mismatch", path)
	for key_variant in value.keys():
		if typeof(key_variant) != TYPE_STRING or not expected.has(str(key_variant)):
			return _invalid("v076_partition_unknown_field", "%s.%s" % [path, str(key_variant)])
	for field_name in expected:
		if not value.has(field_name):
			return _invalid("v076_partition_required_field_missing", "%s.%s" % [path, field_name])
	return {"valid": true, "reason": "", "path": ""}


static func _invalid(reason: String, path: String) -> Dictionary:
	return {"valid": false, "reason": reason, "path": path}
