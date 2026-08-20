@tool
extends RefCounted
class_name V076PartitionReducerV1

const AuthorityCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")
const Validator := preload("res://scripts/v076/map/v076_partition_validator_v1.gd")


func v076_domain_contract(domain_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"domain_id": domain_id,
		"stateless_handler": true,
		"deterministic": true,
		"replay_safe": true,
		"external_side_effects_allowed": false,
		"owns_presentation": false,
		"derived_only_command_types": [],
	}


func v076_apply_command(
	state: Dictionary,
	command: Dictionary,
	rng: Variant
) -> Dictionary:
	var state_validation := AuthorityCodec.validate_domain_state(state)
	if not bool(state_validation.get("valid", false)):
		return _rejection(str(state_validation.get("reason", "v076_partition_state_invalid")), state)
	if int(state.get("generation_count", -1)) != 0:
		return _rejection("v076_partition_already_generated", state)
	if str(command.get("domain_id", "")) != AuthorityCodec.DOMAIN_ID:
		return _rejection("v076_partition_command_domain_mismatch", state)
	if str(command.get("command_type", "")) != AuthorityCodec.COMMAND_TYPE:
		return _rejection("v076_partition_command_type_unknown", state)
	var payload_validation := AuthorityCodec.validate_request_payload(command.get("payload"))
	if not bool(payload_validation.get("valid", false)):
		return _rejection(str(payload_validation.get("reason", "v076_partition_payload_invalid")), state)
	var payload := command.get("payload", {}) as Dictionary
	var rng_snapshot_variant: Variant = rng.call("snapshot") if rng != null and rng.has_method("snapshot") else null
	if not (rng_snapshot_variant is Dictionary):
		return _rejection("v076_partition_rng_contract_missing", state)
	var root_seed := int((rng_snapshot_variant as Dictionary).get("root_seed", 0))
	var generated := Partitioner.generate(
		root_seed,
		int(payload.get("region_count", 0)),
		str(payload.get("shape_complexity", "")),
		rng
	)
	if not bool(generated.get("accepted", false)):
		return _rejection(str(generated.get("reason", "v076_partition_generation_failed")), state)
	var partition := generated.get("partition", {}) as Dictionary
	var validation := Validator.validate_partition(partition)
	if not bool(validation.get("accepted", false)):
		return _rejection(str(validation.get("reason", "v076_partition_validation_failed")), state)
	var partition_sha256 := str(generated.get("partition_sha256", ""))
	var next_state := {
		"schema_version": AuthorityCodec.SCHEMA_VERSION,
		"generation_count": 1,
		"partition": partition,
		"partition_sha256": partition_sha256,
	}
	var next_state_validation := AuthorityCodec.validate_domain_state(next_state)
	if not bool(next_state_validation.get("valid", false)):
		return _rejection(str(next_state_validation.get("reason", "v076_partition_next_state_invalid")), state)
	return {
		"accepted": true,
		"reason": "",
		"outcome": "COMMIT",
		"state": next_state,
		"receipt": {
			"schema_version": AuthorityCodec.SCHEMA_VERSION,
			"receipt_type": "v076.partition.generated.v1",
			"region_count": int(partition.get("region_count", 0)),
			"shape_complexity": str(partition.get("shape_complexity", "")),
			"topology_sha256": str(partition.get("topology_sha256", "")),
			"partition_sha256": partition_sha256,
			"rng_draw_count": int((partition.get("rng_snapshot", {}) as Dictionary).get("draw_count", -1)),
			"land_region_count": _terrain_count(partition.get("terrain_by_region", []) as Array, "Land"),
			"ocean_region_count": _terrain_count(partition.get("terrain_by_region", []) as Array, "Ocean"),
			"terrain_feature_counts": _terrain_feature_counts(partition.get("terrain_features", {}) as Dictionary),
		},
		"derived_commands": [],
	}


static func initial_state() -> Dictionary:
	return AuthorityCodec.initial_domain_state()


static func _terrain_count(terrain_by_region: Array, target: String) -> int:
	var count := 0
	for terrain_variant in terrain_by_region:
		if str(terrain_variant) == target:
			count += 1
	return count


static func _terrain_feature_counts(features: Dictionary) -> Dictionary:
	return {
		"continent_count": (features.get("continents", []) as Array).size(),
		"bay_count": (features.get("bays", []) as Array).size(),
		"peninsula_count": (features.get("peninsulas", []) as Array).size(),
		"strait_count": (features.get("straits", []) as Array).size(),
		"archipelago_count": (features.get("archipelagos", []) as Array).size(),
	}


static func _rejection(reason: String, state: Dictionary) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"outcome": "REJECT",
		"state": state.duplicate(true),
		"receipt": {},
		"derived_commands": [],
	}
