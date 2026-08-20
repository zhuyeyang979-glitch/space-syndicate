extends SceneTree

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const Codec := preload("res://scripts/v076/monster/v076_monster_l1_authority_codec_v1.gd")
const Audit := preload("res://scripts/v076/monster/v076_monster_l1_audit.gd")

const DISTINCT_SEED_COUNT := 1000
const REPLAY_COUNT_PER_SEED := 2
const FIRST_SEED := 760_000


func _init() -> void:
	var receipt := _run_matrix()
	print("V076_MONSTER_L1_1000_SEED_TEST|%s" % JSON.stringify(receipt))
	quit(0 if str(receipt.get("status", "FAIL")) == "PASS" else 1)


func _run_matrix() -> Dictionary:
	var failure_count := 0
	var replay_state_hash_mismatch_count := 0
	var total_replay_count := 0
	var changed_seed_delta_count := 0
	var true_spherical_arc_contract_count := 0
	var preferred_color_asset_contract_count := 0
	var trample_damage_contract_count := 0
	var terminal_hashes := {}
	var movement_class_counts := {}
	var region_count_coverage := {}
	var complexity_coverage := {}
	var previous_terminal_sha256 := ""
	for seed_index in range(DISTINCT_SEED_COUNT):
		var root_seed := FIRST_SEED + seed_index
		var movement_class := str(Codec.MOVEMENT_CLASSES[seed_index % Codec.MOVEMENT_CLASSES.size()])
		var result := Audit.run_seed(root_seed, movement_class, REPLAY_COUNT_PER_SEED)
		if str(result.get("status", "FAIL")) != "PASS":
			failure_count += 1
			continue
		total_replay_count += int(result.get("deterministic_replay_count", 0))
		replay_state_hash_mismatch_count += int(result.get("replay_state_hash_mismatch_count", 0))
		movement_class_counts[movement_class] = int(movement_class_counts.get(movement_class, 0)) + 1
		var region_key := str(result.get("region_count", ""))
		var complexity_key := str(result.get("shape_complexity", ""))
		region_count_coverage[region_key] = int(region_count_coverage.get(region_key, 0)) + 1
		complexity_coverage[complexity_key] = int(complexity_coverage.get(complexity_key, 0)) + 1
		var terminal_sha256 := str(result.get("terminal_state_sha256", ""))
		if terminal_sha256.is_empty() or terminal_hashes.has(terminal_sha256):
			failure_count += 1
		else:
			terminal_hashes[terminal_sha256] = true
		if not previous_terminal_sha256.is_empty() and previous_terminal_sha256 != terminal_sha256:
			changed_seed_delta_count += 1
		previous_terminal_sha256 = terminal_sha256
		if int(result.get("float_authority_field_count", -1)) != 0 or bool(result.get("presentation_owns_authority", true)):
			failure_count += 1
		if (
			str(result.get("arc_class_table_sha256", "")) == "33ec702946b6d4bb5c417e4203b85ccb4d787547cb543c1f133f9c23ff1d07d5"
			and not str(result.get("target_point_sha256", "")).is_empty()
		):
			true_spherical_arc_contract_count += 1
		else:
			failure_count += 1
		if (
			str(result.get("asset_preferred_color", "")) == "amber"
			and int(result.get("asset_total_quantity", -1)) == 2
			and int(result.get("asset_quantity_remaining", -1)) == 1
			and int(result.get("asset_activation_count", -1)) == 1
		):
			preferred_color_asset_contract_count += 1
		else:
			failure_count += 1
		var total_trample_damage := int(result.get("total_trample_damage", -1))
		if (movement_class == "GROUND" and total_trample_damage > 0) or (movement_class != "GROUND" and total_trample_damage == 0):
			trample_damage_contract_count += 1
		else:
			failure_count += 1
	var coverage_green := (
		region_count_coverage.size() == 7
		and complexity_coverage.size() == 3
		and movement_class_counts.size() == 3
	)
	var status := "PASS" if (
		failure_count == 0
		and replay_state_hash_mismatch_count == 0
		and total_replay_count == DISTINCT_SEED_COUNT * REPLAY_COUNT_PER_SEED
		and terminal_hashes.size() == DISTINCT_SEED_COUNT
		and changed_seed_delta_count == DISTINCT_SEED_COUNT - 1
		and true_spherical_arc_contract_count == DISTINCT_SEED_COUNT
		and preferred_color_asset_contract_count == DISTINCT_SEED_COUNT
		and trample_damage_contract_count == DISTINCT_SEED_COUNT
		and coverage_green
	) else "FAIL"
	return {
		"status": status,
		"distinct_seed_count": DISTINCT_SEED_COUNT,
		"replay_count_per_seed": REPLAY_COUNT_PER_SEED,
		"total_replay_count": total_replay_count,
		"replay_state_hash_mismatch_count": replay_state_hash_mismatch_count,
		"failure_count": failure_count,
		"distinct_terminal_state_sha256_count": terminal_hashes.size(),
		"changed_seed_delta_count": changed_seed_delta_count,
		"true_spherical_arc_contract_count": true_spherical_arc_contract_count,
		"preferred_color_asset_contract_count": preferred_color_asset_contract_count,
		"trample_damage_contract_count": trample_damage_contract_count,
		"region_count_coverage": region_count_coverage,
		"shape_complexity_coverage": complexity_coverage,
		"movement_class_coverage": movement_class_counts,
		"topology_sha256": Codec.REQUIRED_TOPOLOGY_SHA256,
		"arc_class_table_sha256": "33ec702946b6d4bb5c417e4203b85ccb4d787547cb543c1f133f9c23ff1d07d5",
		"aggregate_receipt_sha256": StateCodec.fingerprint({
			"terminal_hashes": terminal_hashes,
			"region_count_coverage": region_count_coverage,
			"shape_complexity_coverage": complexity_coverage,
			"movement_class_coverage": movement_class_counts,
			"true_spherical_arc_contract_count": true_spherical_arc_contract_count,
			"preferred_color_asset_contract_count": preferred_color_asset_contract_count,
			"trample_damage_contract_count": trample_damage_contract_count,
			"arc_class_table_sha256": "33ec702946b6d4bb5c417e4203b85ccb4d787547cb543c1f133f9c23ff1d07d5",
		}),
		"float_authority_field_count": 0,
		"presentation_owns_authority": false,
	}
