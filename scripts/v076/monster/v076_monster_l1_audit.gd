@tool
extends RefCounted
class_name V076MonsterL1Audit

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const ReplayRunner := preload("res://scripts/v076/simulation/v076_replay_runner.gd")
const PartitionCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")
const Codec := preload("res://scripts/v076/monster/v076_monster_l1_authority_codec_v1.gd")
const Metric := preload("res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd")
const Reducer := preload("res://scripts/v076/monster/v076_monster_l1_reducer_v1.gd")
const Validator := preload("res://scripts/v076/monster/v076_monster_l1_validator_v1.gd")

const REGION_COUNTS := [6, 8, 12, 16, 20, 24, 30]
const COMPLEXITIES := ["SIMPLE", "STANDARD", "COMPLEX"]


static func run_seed(root_seed: int, movement_class: String = "GROUND", replay_count: int = 2) -> Dictionary:
	if not Codec.MOVEMENT_CLASSES.has(movement_class) or replay_count < 1:
		return _failure("v076_monster_audit_request_invalid")
	var region_count := int(REGION_COUNTS[absi(root_seed) % REGION_COUNTS.size()])
	@warning_ignore("integer_division")
	var complexity := str(COMPLEXITIES[absi(root_seed / REGION_COUNTS.size()) % COMPLEXITIES.size()])
	var partition_rng := DomainRng.new()
	var rng_configured := partition_rng.configure(root_seed, PartitionCodec.DOMAIN_ID)
	if not bool(rng_configured.get("accepted", false)):
		return _failure("v076_monster_audit_partition_rng_failed")
	var generated := Partitioner.generate(root_seed, region_count, complexity, partition_rng)
	if not bool(generated.get("accepted", false)):
		return _failure(str(generated.get("reason", "v076_monster_audit_partition_failed")))
	var partition := generated.get("partition", {}) as Dictionary
	var start_face_id := absi(root_seed * 17 + 3) % 320
	var target_face_id := absi(root_seed * 97 + 157) % 320
	if target_face_id == start_face_id:
		target_face_id = (target_face_id + 137) % 320
	var target_point_result := Metric.canonical_target_point(target_face_id)
	if not bool(target_point_result.get("accepted", false)):
		return _failure(str(target_point_result.get("reason", "v076_monster_audit_target_point_failed")))
	var target_point := target_point_result.get("target_point", {}) as Dictionary
	var route_result := Metric.build_route(start_face_id, target_face_id, target_point)
	if not bool(route_result.get("accepted", false)):
		return _failure(str(route_result.get("reason", "v076_monster_audit_route_failed")))
	var route_distance_mu := int((route_result.get("route", {}) as Dictionary).get("total_distance_mu", 0))
	var maximum_distance_mu := mini(route_distance_mu, 2_500_000)
	var speed_mu := 375_000 + (absi(root_seed) % 5) * 25_000
	var state_result := Codec.build_initial_state(
		partition,
		[{
			"monster_id": "monster.audit",
			"movement_class": movement_class,
			"start_face_id": start_face_id,
			"trample_efficiency_ppm": 625_000,
		}],
		[{
			"asset_id": "asset.audit",
			"preferred_color": "amber",
			"quantity": 2,
			"cooldown_ticks": 4,
		}]
	)
	if not bool(state_result.get("accepted", false)):
		return _failure(str(state_result.get("reason", "v076_monster_audit_state_failed")))
	var kernel := Kernel.new()
	if not bool(kernel.configure(root_seed).get("accepted", false)):
		kernel.free()
		return _failure("v076_monster_audit_kernel_configure_failed")
	if not bool(kernel.register_domain(Codec.DOMAIN_ID, state_result.get("state", {}) as Dictionary, Reducer).get("accepted", false)):
		kernel.free()
		return _failure("v076_monster_audit_domain_register_failed")
	var command_result := AuthorityCommand.build(
		"monster.audit.root.%d.%s" % [root_seed, movement_class.to_lower()],
		Codec.DOMAIN_ID,
		Codec.START_COMMAND_TYPE,
		"player.audit",
		1,
		30,
		1,
		{
			"monster_id": "monster.audit",
			"target_face_id": target_face_id,
			"target_point": target_point,
			"max_geodesic_distance_mu": maximum_distance_mu,
			"speed_mu_per_tick": speed_mu,
			"asset_id": "asset.audit",
			"preferred_color": "amber",
			"trample_modifiers_ppm": [800_000, 750_000],
			"expected_move_revision": 0,
		}
	)
	if not bool(command_result.get("accepted", false)) or not bool(kernel.submit_command(command_result.get("command", {}) as Dictionary).get("accepted", false)):
		kernel.free()
		return _failure("v076_monster_audit_command_submit_failed")
	@warning_ignore("integer_division")
	var move_tick_count := (maximum_distance_mu + speed_mu - 1) / speed_mu
	var advance_result := kernel.advance_ticks(2 + move_tick_count)
	if not bool(advance_result.get("accepted", false)):
		var reason := str(advance_result.get("reason", "v076_monster_audit_advance_failed"))
		kernel.free()
		return _failure(reason)
	var terminal_state := kernel.domain_state(Codec.DOMAIN_ID)
	var terminal_validation := Validator.validate_terminal_state(terminal_state)
	var lineage_validation := Validator.validate_execution_lineage(kernel.execution_log(), kernel.derived_outbox())
	if not bool(terminal_validation.get("accepted", false)) or not bool(lineage_validation.get("accepted", false)):
		var reason := str(terminal_validation.get("reason", lineage_validation.get("reason", "v076_monster_audit_validation_failed")))
		kernel.free()
		return _failure(reason)
	var recipe_envelope := kernel.build_replay_recipe()
	var recipe := recipe_envelope.get("recipe", {}) as Dictionary
	var recipe_sha256 := str(recipe_envelope.get("recipe_sha256", ""))
	var replay_mismatch_count := 0
	for _replay_index in range(replay_count):
		var replay := ReplayRunner.new().verify(recipe, recipe_sha256, {Codec.DOMAIN_ID: Reducer})
		if str(replay.get("status", "")) != "PASS" or int(replay.get("replay_state_hash_mismatch_count", 1)) != 0:
			replay_mismatch_count += 1
	var monster := ((terminal_state.get("monsters", {}) as Dictionary).get("monster.audit", {}) as Dictionary)
	var asset := ((terminal_state.get("assets", {}) as Dictionary).get("asset.audit", {}) as Dictionary)
	var result := {
		"status": "PASS" if replay_mismatch_count == 0 else "FAIL",
		"reason": "" if replay_mismatch_count == 0 else "v076_monster_audit_replay_mismatch",
		"root_seed": root_seed,
		"region_count": region_count,
		"shape_complexity": complexity,
		"movement_class": movement_class,
		"topology_sha256": Codec.REQUIRED_TOPOLOGY_SHA256,
		"arc_class_table_sha256": Metric.ARC_CLASS_TABLE_SHA256,
		"partition_sha256": str(generated.get("partition_sha256", "")),
		"route_sha256": str(monster.get("route_sha256", "")),
		"target_point_sha256": str(target_point_result.get("target_point_sha256", "")),
		"terminal_state_sha256": kernel.state_fingerprint(),
		"root_command_count": kernel.root_commands().size(),
		"derived_command_count": kernel.derived_commands().size(),
		"derived_outbox_count": kernel.derived_outbox().size(),
		"authority_sequence_count": kernel.execution_log().size(),
		"deterministic_replay_count": replay_count,
		"replay_state_hash_mismatch_count": replay_mismatch_count,
		"movement_status": str(monster.get("status", "")),
		"travelled_distance_mu": int(monster.get("travelled_distance_mu", 0)),
		"region_crossing_count": int(monster.get("region_crossing_count", 0)),
		"trample_distance_by_region_mu": (monster.get("trample_distance_by_region_mu", {}) as Dictionary).duplicate(true),
		"trample_damage_by_region": (monster.get("trample_damage_by_region", {}) as Dictionary).duplicate(true),
		"total_trample_damage": int(monster.get("total_trample_damage", 0)),
		"effective_trample_efficiency_ppm": int(monster.get("effective_trample_efficiency_ppm", 0)),
		"asset_preferred_color": str(asset.get("preferred_color", "")),
		"asset_total_quantity": int(asset.get("total_quantity", 0)),
		"asset_quantity_remaining": int(asset.get("quantity_remaining", -1)),
		"asset_activation_count": int(asset.get("activation_count", 0)),
		"float_authority_field_count": int(terminal_validation.get("float_authority_field_count", -1)),
		"presentation_owns_authority": false,
	}
	kernel.free()
	return result


static func _failure(reason: String) -> Dictionary:
	return {"status": "FAIL", "reason": reason}
