extends SceneTree

const Audit := preload("res://scripts/v076/map/v076_partition_audit.gd")

const SEED_TARGET := 2000


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var result := Audit.run_seed_suite(SEED_TARGET)
	var feature_counts := result.get("aggregate_terrain_feature_counts", {}) as Dictionary
	var matrix_distribution := result.get("sample_count_by_region_count_and_complexity", {}) as Dictionary
	var all_feature_counts_positive := true
	for feature_name_variant in feature_counts.keys():
		if int(feature_counts[feature_name_variant]) <= 0:
			all_feature_counts_positive = false
	var contract_pass: bool = (
		str(result.get("status", "FAIL")) == "PASS"
		and int(result.get("distinct_seed_count", 0)) == SEED_TARGET
		and int(result.get("same_seed_fresh_replay_count", 0)) == SEED_TARGET
		and int(result.get("generation_failure_count", -1)) == 0
		and int(result.get("validation_failure_count", -1)) == 0
		and int(result.get("replay_mismatch_count", -1)) == 0
		and int(result.get("terrain_replay_mismatch_count", -1)) == 0
		and matrix_distribution.size() == 21
		and bool(result.get("region_count_and_complexity_distribution_matches", false))
		and bool(result.get("all_terrain_features_observed", false))
		and all_feature_counts_positive
		and int(result.get("aggregate_land_region_count", 0)) > 0
		and int(result.get("aggregate_ocean_region_count", 0)) > 0
		and int(result.get("float_authority_field_count", -1)) == 0
	)
	result["test_contract_pass"] = contract_pass
	print("V076_SHARED_HALF_EDGE_PARTITION_2000_SEED_TEST|%s" % JSON.stringify(result))
	if not contract_pass:
		push_error("V076 shared half-edge 2000-seed gate failed: %s" % str(result.get("reason", "unknown")))
	quit(0 if contract_pass else 1)
