@tool
extends RefCounted
class_name V076PartitionAudit

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const AuthorityCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Microgrid := preload("res://scripts/v076/map/v076_spherical_microgrid_index_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")
const Validator := preload("res://scripts/v076/map/v076_partition_validator_v1.gd")

const REQUIRED_ACCEPTANCE_REGION_COUNTS := [6, 8, 12, 16, 20, 24, 30]
const EXTENDED_POSITIVE_REGION_COUNTS := [31, 32]
const SHAPE_COMPLEXITIES := ["SIMPLE", "STANDARD", "COMPLEX"]
const SAMPLE_SEED_BASE := 760_200_001
const SAMPLE_SEED_STRIDE := 7_919


static func run_focused_suite() -> Dictionary:
	var failure_count := 0
	var replay_mismatch_count := 0
	var first_failure_reason := ""
	var focused_partition_shas := []
	var complexity_matrix_case_count := 0
	var shape_complexity_boundary_delta_count := 0
	for count_index in range(REQUIRED_ACCEPTANCE_REGION_COUNTS.size()):
		var region_count := int(REQUIRED_ACCEPTANCE_REGION_COUNTS[count_index])
		var map_seed := SAMPLE_SEED_BASE + count_index * SAMPLE_SEED_STRIDE
		var boundary_identities := {}
		for shape_complexity_variant in SHAPE_COMPLEXITIES:
			var shape_complexity := str(shape_complexity_variant)
			complexity_matrix_case_count += 1
			var primary := _generate_and_validate(map_seed, region_count, shape_complexity)
			var replay := _generate_and_validate(map_seed, region_count, shape_complexity)
			if not bool(primary.get("accepted", false)):
				failure_count += 1
				if first_failure_reason.is_empty():
					first_failure_reason = str(primary.get("reason", "focused_generation_failed"))
				continue
			if not bool(replay.get("accepted", false)):
				failure_count += 1
				if first_failure_reason.is_empty():
					first_failure_reason = str(replay.get("reason", "focused_replay_generation_failed"))
				continue
			var primary_sha := str(primary.get("partition_sha256", ""))
			var replay_sha := str(replay.get("partition_sha256", ""))
			focused_partition_shas.append(primary_sha)
			boundary_identities[shape_complexity] = str(primary.get("boundary_identity_sha256", ""))
			if primary_sha.is_empty() or primary_sha != replay_sha:
				replay_mismatch_count += 1
		if (
			boundary_identities.size() == SHAPE_COMPLEXITIES.size()
			and (
				str(boundary_identities.get("SIMPLE", "")) != str(boundary_identities.get("STANDARD", ""))
				or str(boundary_identities.get("SIMPLE", "")) != str(boundary_identities.get("COMPLEX", ""))
			)
		):
			shape_complexity_boundary_delta_count += 1
	for extended_index in range(EXTENDED_POSITIVE_REGION_COUNTS.size()):
		var region_count := int(EXTENDED_POSITIVE_REGION_COUNTS[extended_index])
		var map_seed := SAMPLE_SEED_BASE + 80_000 + extended_index * SAMPLE_SEED_STRIDE
		var primary := _generate_and_validate(map_seed, region_count, "STANDARD")
		var replay := _generate_and_validate(map_seed, region_count, "STANDARD")
		if not bool(primary.get("accepted", false)):
			failure_count += 1
			if first_failure_reason.is_empty():
				first_failure_reason = str(primary.get("reason", "focused_extended_generation_failed"))
			continue
		if not bool(replay.get("accepted", false)):
			failure_count += 1
			if first_failure_reason.is_empty():
				first_failure_reason = str(replay.get("reason", "focused_extended_replay_failed"))
			continue
		var primary_sha := str(primary.get("partition_sha256", ""))
		var replay_sha := str(replay.get("partition_sha256", ""))
		focused_partition_shas.append(primary_sha)
		if primary_sha.is_empty() or primary_sha != replay_sha:
			replay_mismatch_count += 1
	var changed_seed_a := _generate_and_validate(SAMPLE_SEED_BASE + 90_001, 16, "COMPLEX")
	var changed_seed_b := _generate_and_validate(SAMPLE_SEED_BASE + 90_002, 16, "COMPLEX")
	var changed_seed_delta := (
		bool(changed_seed_a.get("accepted", false))
		and bool(changed_seed_b.get("accepted", false))
		and str(changed_seed_a.get("partition_sha256", ""))
		!= str(changed_seed_b.get("partition_sha256", ""))
	)
	var changed_seed_terrain_delta := (
		bool(changed_seed_a.get("accepted", false))
		and bool(changed_seed_b.get("accepted", false))
		and str(changed_seed_a.get("terrain_identity_sha256", ""))
		!= str(changed_seed_b.get("terrain_identity_sha256", ""))
	)
	if not changed_seed_delta or not changed_seed_terrain_delta:
		failure_count += 1
		if first_failure_reason.is_empty():
			first_failure_reason = "focused_changed_seed_partition_or_terrain_delta_missing"
	if shape_complexity_boundary_delta_count != REQUIRED_ACCEPTANCE_REGION_COUNTS.size():
		failure_count += 1
		if first_failure_reason.is_empty():
			first_failure_reason = "focused_shape_complexity_boundary_delta_missing"
	var topology_result := Microgrid.build()
	var status := "PASS" if (
		failure_count == 0
		and replay_mismatch_count == 0
		and focused_partition_shas.size() == complexity_matrix_case_count + EXTENDED_POSITIVE_REGION_COUNTS.size()
	) else "FAIL"
	return {
		"status": status,
		"reason": first_failure_reason,
		"focused_region_count_case_count": REQUIRED_ACCEPTANCE_REGION_COUNTS.size(),
		"focused_complexity_matrix_case_count": complexity_matrix_case_count,
		"focused_extended_positive_region_count_case_count": EXTENDED_POSITIVE_REGION_COUNTS.size(),
		"focused_generation_failure_count": failure_count,
		"focused_replay_mismatch_count": replay_mismatch_count,
		"changed_seed_partition_delta": changed_seed_delta,
		"changed_seed_terrain_delta": changed_seed_terrain_delta,
		"shape_complexity_boundary_delta_count": shape_complexity_boundary_delta_count,
		"topology_sha256": str(topology_result.get("topology_sha256", "")),
		"actual_topology_sha256": str(topology_result.get("actual_topology_sha256", "")),
		"focused_partition_shas": focused_partition_shas,
	}


static func run_seed_suite(sample_count: int = 2000) -> Dictionary:
	if sample_count <= 0:
		return {"status": "FAIL", "reason": "sample_count_invalid"}
	var generation_failure_count := 0
	var validation_failure_count := 0
	var replay_mismatch_count := 0
	var terrain_replay_mismatch_count := 0
	var first_failure_reason := ""
	var distinct_seeds := {}
	var sample_count_by_region_count := {}
	var sample_count_by_shape_complexity := {}
	var sample_count_by_region_count_and_complexity := {}
	var aggregate_terrain_feature_counts := {
		"continent_count": 0,
		"bay_count": 0,
		"peninsula_count": 0,
		"strait_count": 0,
		"archipelago_count": 0,
	}
	var aggregate_land_region_count := 0
	var aggregate_ocean_region_count := 0
	for region_count_variant in REQUIRED_ACCEPTANCE_REGION_COUNTS:
		sample_count_by_region_count[str(int(region_count_variant))] = 0
		for shape_complexity_variant in SHAPE_COMPLEXITIES:
			var pair_key := "%d|%s" % [int(region_count_variant), str(shape_complexity_variant)]
			sample_count_by_region_count_and_complexity[pair_key] = 0
	for shape_complexity_variant in SHAPE_COMPLEXITIES:
		sample_count_by_shape_complexity[str(shape_complexity_variant)] = 0
	for sample_index in range(sample_count):
		var matrix_case := _matrix_case(sample_index)
		var region_count := int(matrix_case.get("region_count", 0))
		var shape_complexity := str(matrix_case.get("shape_complexity", ""))
		var map_seed := SAMPLE_SEED_BASE + sample_index * SAMPLE_SEED_STRIDE
		distinct_seeds[map_seed] = true
		var count_key := str(region_count)
		sample_count_by_region_count[count_key] = int(sample_count_by_region_count[count_key]) + 1
		sample_count_by_shape_complexity[shape_complexity] = int(sample_count_by_shape_complexity[shape_complexity]) + 1
		var pair_key := "%d|%s" % [region_count, shape_complexity]
		sample_count_by_region_count_and_complexity[pair_key] = int(sample_count_by_region_count_and_complexity[pair_key]) + 1
		var primary := _generate_and_validate(map_seed, region_count, shape_complexity)
		if not bool(primary.get("accepted", false)):
			if str(primary.get("phase", "generation")) == "validation":
				validation_failure_count += 1
			else:
				generation_failure_count += 1
			if first_failure_reason.is_empty():
				first_failure_reason = str(primary.get("reason", "sample_generation_failed"))
			continue
		var replay := _generate_and_validate(map_seed, region_count, shape_complexity)
		if not bool(replay.get("accepted", false)):
			if str(replay.get("phase", "generation")) == "validation":
				validation_failure_count += 1
			else:
				generation_failure_count += 1
			if first_failure_reason.is_empty():
				first_failure_reason = str(replay.get("reason", "sample_replay_generation_failed"))
			continue
		if str(primary.get("partition_sha256", "")).is_empty() or (
			str(primary.get("partition_sha256", ""))
			!= str(replay.get("partition_sha256", ""))
		):
			replay_mismatch_count += 1
		if str(primary.get("terrain_identity_sha256", "")).is_empty() or (
			str(primary.get("terrain_identity_sha256", ""))
			!= str(replay.get("terrain_identity_sha256", ""))
		):
			terrain_replay_mismatch_count += 1
		aggregate_land_region_count += int(primary.get("land_region_count", 0))
		aggregate_ocean_region_count += int(primary.get("ocean_region_count", 0))
		var feature_counts := primary.get("terrain_feature_counts", {}) as Dictionary
		for feature_name_variant in aggregate_terrain_feature_counts.keys():
			var feature_name := str(feature_name_variant)
			aggregate_terrain_feature_counts[feature_name] = (
				int(aggregate_terrain_feature_counts[feature_name])
				+ int(feature_counts.get(feature_name, 0))
			)
	var expected_distributions := _expected_distributions(sample_count)
	var distribution_matches: bool = (
		sample_count_by_region_count == expected_distributions.get("by_region_count", {})
		and sample_count_by_shape_complexity == expected_distributions.get("by_shape_complexity", {})
		and sample_count_by_region_count_and_complexity == expected_distributions.get("by_pair", {})
	)
	var all_terrain_features_observed := true
	for feature_name_variant in aggregate_terrain_feature_counts.keys():
		if int(aggregate_terrain_feature_counts[feature_name_variant]) <= 0:
			all_terrain_features_observed = false
	var status := "PASS" if (
		generation_failure_count == 0
		and validation_failure_count == 0
		and replay_mismatch_count == 0
		and terrain_replay_mismatch_count == 0
		and distinct_seeds.size() == sample_count
		and distribution_matches
		and all_terrain_features_observed
		and aggregate_land_region_count > 0
		and aggregate_ocean_region_count > 0
	) else "FAIL"
	if not distribution_matches and first_failure_reason.is_empty():
		first_failure_reason = "sample_region_count_complexity_distribution_mismatch"
	elif not all_terrain_features_observed and first_failure_reason.is_empty():
		first_failure_reason = "sample_terrain_feature_support_incomplete"
	return {
		"status": status,
		"reason": first_failure_reason,
		"requested_seed_count": sample_count,
		"executed_seed_count": sample_count,
		"distinct_seed_count": distinct_seeds.size(),
		"same_seed_fresh_replay_count": sample_count,
		"generation_failure_count": generation_failure_count,
		"validation_failure_count": validation_failure_count,
		"replay_mismatch_count": replay_mismatch_count,
		"terrain_replay_mismatch_count": terrain_replay_mismatch_count,
		"sample_count_by_region_count": sample_count_by_region_count,
		"sample_count_by_shape_complexity": sample_count_by_shape_complexity,
		"sample_count_by_region_count_and_complexity": sample_count_by_region_count_and_complexity,
		"expected_sample_count_by_region_count": expected_distributions.get("by_region_count", {}),
		"expected_sample_count_by_shape_complexity": expected_distributions.get("by_shape_complexity", {}),
		"expected_sample_count_by_region_count_and_complexity": expected_distributions.get("by_pair", {}),
		"region_count_and_complexity_distribution_matches": distribution_matches,
		"aggregate_land_region_count": aggregate_land_region_count,
		"aggregate_ocean_region_count": aggregate_ocean_region_count,
		"aggregate_terrain_feature_counts": aggregate_terrain_feature_counts,
		"all_terrain_features_observed": all_terrain_features_observed,
		"float_authority_field_count": 0,
	}


static func _generate_and_validate(
	root_seed: int,
	region_count: int,
	shape_complexity: String
) -> Dictionary:
	var rng := DomainRng.new()
	var configured := rng.configure(root_seed, AuthorityCodec.DOMAIN_ID)
	if not bool(configured.get("accepted", false)):
		return {"accepted": false, "phase": "generation", "reason": "audit_rng_configure_failed"}
	var generated := Partitioner.generate(root_seed, region_count, shape_complexity, rng)
	if not bool(generated.get("accepted", false)):
		return {
			"accepted": false,
			"phase": "generation",
			"reason": str(generated.get("reason", "audit_partition_generation_failed")),
			"actual_topology_sha256": str(generated.get("actual_topology_sha256", "")),
		}
	var partition := generated.get("partition", {}) as Dictionary
	var validation := Validator.validate_partition(partition)
	if not bool(validation.get("accepted", false)):
		return {
			"accepted": false,
			"phase": "validation",
			"reason": str(validation.get("reason", "audit_partition_validation_failed")),
		}
	var partition_sha256 := str(generated.get("partition_sha256", ""))
	if partition_sha256 != str(validation.get("partition_sha256", "")):
		return {"accepted": false, "phase": "validation", "reason": "audit_partition_sha_cross_binding_failed"}
	if StateCodec.count_float_fields(partition) != 0:
		return {"accepted": false, "phase": "validation", "reason": "audit_float_authority_field_detected"}
	var terrain_identity := {
		"terrain_by_region": partition.get("terrain_by_region", []),
		"terrain_by_face": partition.get("terrain_by_face", []),
		"terrain_features": partition.get("terrain_features", {}),
	}
	var boundary_identity := {
		"owner_by_face": partition.get("owner_by_face", []),
		"boundary_cycles_by_region": partition.get("boundary_cycles_by_region", []),
		"shared_boundary_edges": partition.get("shared_boundary_edges", []),
	}
	return {
		"accepted": true,
		"phase": "complete",
		"reason": "",
		"partition_sha256": partition_sha256,
		"terrain_identity_sha256": StateCodec.fingerprint(terrain_identity),
		"boundary_identity_sha256": StateCodec.fingerprint(boundary_identity),
		"land_region_count": int(validation.get("land_region_count", 0)),
		"ocean_region_count": int(validation.get("ocean_region_count", 0)),
		"terrain_feature_counts": validation.get("terrain_feature_counts", {}),
	}


static func _expected_distributions(sample_count: int) -> Dictionary:
	var by_region_count := {}
	var by_shape_complexity := {}
	var by_pair := {}
	for region_count_variant in REQUIRED_ACCEPTANCE_REGION_COUNTS:
		by_region_count[str(int(region_count_variant))] = 0
		for shape_complexity_variant in SHAPE_COMPLEXITIES:
			by_pair["%d|%s" % [int(region_count_variant), str(shape_complexity_variant)]] = 0
	for shape_complexity_variant in SHAPE_COMPLEXITIES:
		by_shape_complexity[str(shape_complexity_variant)] = 0
	for sample_index in range(sample_count):
		var matrix_case := _matrix_case(sample_index)
		var region_count := int(matrix_case.get("region_count", 0))
		var shape_complexity := str(matrix_case.get("shape_complexity", ""))
		var count_key := str(region_count)
		by_region_count[count_key] = int(by_region_count[count_key]) + 1
		by_shape_complexity[shape_complexity] = int(by_shape_complexity[shape_complexity]) + 1
		var pair_key := "%d|%s" % [region_count, shape_complexity]
		by_pair[pair_key] = int(by_pair[pair_key]) + 1
	return {
		"by_region_count": by_region_count,
		"by_shape_complexity": by_shape_complexity,
		"by_pair": by_pair,
	}


static func _matrix_case(sample_index: int) -> Dictionary:
	var matrix_index := posmod(
		sample_index,
		REQUIRED_ACCEPTANCE_REGION_COUNTS.size() * SHAPE_COMPLEXITIES.size()
	)
	var region_index := 0
	while matrix_index >= SHAPE_COMPLEXITIES.size():
		matrix_index -= SHAPE_COMPLEXITIES.size()
		region_index += 1
	return {
		"region_count": int(REQUIRED_ACCEPTANCE_REGION_COUNTS[region_index]),
		"shape_complexity": str(SHAPE_COMPLEXITIES[matrix_index]),
	}
