extends SceneTree

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const Kernel := preload("res://scripts/v076/simulation/v076_deterministic_kernel.gd")
const ReplayRunner := preload("res://scripts/v076/simulation/v076_replay_runner.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const PartitionCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const Partitioner := preload("res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd")
const Codec := preload("res://scripts/v076/monster/v076_monster_l1_authority_codec_v1.gd")
const Metric := preload("res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd")
const Reducer := preload("res://scripts/v076/monster/v076_monster_l1_reducer_v1.gd")
const Validator := preload("res://scripts/v076/monster/v076_monster_l1_validator_v1.gd")
const Audit := preload("res://scripts/v076/monster/v076_monster_l1_audit.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run()
	quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	_test_integer_route_and_segment_metric()
	_test_kernel_derived_movement_and_assets()
	_test_movement_class_trample_defaults()
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V076_MONSTER_L1_DIRECTIONAL_GEODESIC_MOVE_TEST|%s|%d/%d" % [status, _checks - _failures.size(), _checks])
	if not _failures.is_empty():
		push_error("\n- ".join(_failures))


func _test_integer_route_and_segment_metric() -> void:
	var target_point_result := Metric.canonical_target_point(319)
	var target_point := target_point_result.get("target_point", {}) as Dictionary
	var route_a := Metric.build_route(0, 319, target_point)
	var route_b := Metric.build_route(0, 319, target_point)
	_check(bool(route_a.get("accepted", false)) and route_a == route_b, "integer route is deterministic")
	var route := route_a.get("route", {}) as Dictionary
	_check(str(route.get("topology_sha256", "")) == Metric.REQUIRED_TOPOLOGY_SHA256, "metric binds exact Stage2 topology SHA")
	_check(str(route.get("arc_class_table_sha256", "")) == Metric.ARC_CLASS_TABLE_SHA256, "metric binds the sealed true spherical arc table")
	_check(_sum_array(route.get("segment_distance_mu_by_index", []) as Array) == int(route.get("total_distance_mu", -1)), "route distance is the integer sum of variable great-circle arcs")
	_check(_unique_int_count(route.get("segment_distance_mu_by_index", []) as Array) > 1, "canonical route uses physical variable arc lengths rather than a uniform hop budget")
	_check(bool(Metric.validate_target_point(target_point, 319).get("accepted", false)), "target is an exact sealed spherical face-center point")
	_check(StateCodec.count_float_fields(route) == 0, "route authority contains zero float fields")
	var allocation := Metric.interval_region_distance(0, 3, 155_593, 40_000, 120_000, [3, 0, 0, 8])
	var ledger := allocation.get("distance_by_region_mu", {}) as Dictionary
	_check(bool(allocation.get("accepted", false)) and int(ledger.get("3", 0)) == 37_796 and int(ledger.get("8", 0)) == 42_204, "physical arc interval splits at its exact quantized spherical midpoint")
	var tampered := route.duplicate(true)
	(tampered.get("face_path", []) as Array).reverse()
	_check(not bool(Metric.validate_route(tampered).get("accepted", true)), "synchronously changed route bytes fail canonical route validation")
	var tampered_point := target_point.duplicate(true)
	tampered_point["barycentric_numerators"] = [1, 2, 1]
	_check(not bool(Metric.validate_target_point(tampered_point, 319).get("accepted", true)), "synchronously resigned target-point geometry fails canonical validation")


func _test_kernel_derived_movement_and_assets() -> void:
	var partition := _partition(73001, 12, "COMPLEX")
	_check(not partition.is_empty(), "focused fixture generates a canonical Stage2 partition")
	if partition.is_empty():
		return
	var initial := Codec.build_initial_state(
		partition,
		[
			{"monster_id": "ground.alpha", "movement_class": "GROUND", "start_face_id": 0, "trample_efficiency_ppm": 600_000},
			{"monster_id": "ground.beta", "movement_class": "GROUND", "start_face_id": 17, "trample_efficiency_ppm": 500_000},
			{"monster_id": "flying.alpha", "movement_class": "FLYING", "start_face_id": 41, "trample_efficiency_ppm": 700_000},
			{"monster_id": "phase.alpha", "movement_class": "PHASE", "start_face_id": 83, "trample_efficiency_ppm": 900_000},
		],
		[
			{"asset_id": "asset.shared", "preferred_color": "amber", "quantity": 3, "cooldown_ticks": 10},
			{"asset_id": "asset.flying", "preferred_color": "azure", "quantity": 1, "cooldown_ticks": 0},
			{"asset_id": "asset.phase", "preferred_color": "violet", "quantity": 1, "cooldown_ticks": 0},
		]
	)
	_check(bool(initial.get("accepted", false)), "monster initial state closes over canonical Stage2 partition")
	if not bool(initial.get("accepted", false)):
		return
	var kernel := Kernel.new()
	_check(bool(kernel.configure(73001).get("accepted", false)), "kernel configures for focused monster fixture")
	_check(bool(kernel.register_domain(Codec.DOMAIN_ID, initial.get("state", {}) as Dictionary, Reducer).get("accepted", false)), "Script-only fresh monster reducer registers at tick zero")
	var forged_advance := AuthorityCommand.build(
		"root.forged.advance", Codec.DOMAIN_ID, Codec.ADVANCE_COMMAND_TYPE,
		"player.focused", 1, 30, 1,
		{"monster_id": "ground.alpha", "movement_revision": 1, "step_index": 1, "route_sha256": "f".repeat(64)}
	)
	_check(not bool(kernel.submit_command(forged_advance.get("command", {}) as Dictionary).get("accepted", true)) and kernel.root_commands().is_empty(), "derived-only advance type cannot be injected as a root source")
	var ground := _start_command("root.ground", "ground.alpha", 319, 450_000, 180_000, "asset.shared", "amber", [800_000, 750_000], 0, 1, 1)
	var flying := _start_command("root.flying", "flying.alpha", 202, 350_000, 170_000, "asset.flying", "azure", [900_000], 0, 1, 2)
	var phase := _start_command("root.phase", "phase.alpha", 277, 300_000, 160_000, "asset.phase", "violet", [700_000], 0, 1, 3)
	var cooldown := _start_command("root.cooldown", "ground.beta", 200, 300_000, 150_000, "asset.shared", "amber", [1_000_000], 0, 2, 4)
	var wrong_color := _start_command("root.wrong-color", "ground.beta", 200, 300_000, 180_000, "asset.shared", "violet", [900_000], 0, 11, 5)
	var reuse := _start_command("root.reuse", "ground.beta", 200, 300_000, 180_000, "asset.shared", "amber", [900_000], 0, 12, 6)
	for command_variant in [ground, flying, phase, cooldown, wrong_color, reuse]:
		_check(bool(kernel.submit_command(command_variant as Dictionary).get("accepted", false)), "root command enters root-only inventory")
	var advanced := kernel.advance_ticks(10)
	_check(bool(advanced.get("accepted", false)), "root and derived movement execute transactionally")
	var state := kernel.domain_state(Codec.DOMAIN_ID)
	var monsters := state.get("monsters", {}) as Dictionary
	var ground_state := monsters.get("ground.alpha", {}) as Dictionary
	var flying_state := monsters.get("flying.alpha", {}) as Dictionary
	var phase_state := monsters.get("phase.alpha", {}) as Dictionary
	_check(int(ground_state.get("accepted_tick", 0)) == 1 and int(ground_state.get("accepted_authority_sequence", 0)) > 0, "move binds accepted tick and Authority Sequence")
	_check(int(ground_state.get("travelled_distance_mu", 0)) == 450_000 and str(ground_state.get("status", "")) == "MAX_DISTANCE", "maximum true geodesic arc distance stops exactly inside a segment")
	_check(int(ground_state.get("segment_progress_mu", 0)) > 0, "sphere position retains exact integer arc progress")
	_check(_sum_values(ground_state.get("trample_distance_by_region_mu", {}) as Dictionary) == int(ground_state.get("travelled_distance_mu", 0)), "ground trample is physical in-region distance")
	var expected_ground_damage := Codec.compute_trample_damage_by_region(ground_state.get("trample_distance_by_region_mu", {}) as Dictionary, 360_000)
	_check(int(ground_state.get("effective_trample_efficiency_ppm", -1)) == 360_000 and ground_state.get("trample_damage_by_region", {}) == expected_ground_damage and int(ground_state.get("total_trample_damage", -1)) == _sum_values(expected_ground_damage), "ground trample damage equals distance times base efficiency times frozen modifiers")
	_check((flying_state.get("trample_distance_by_region_mu", {}) as Dictionary).is_empty() and (phase_state.get("trample_distance_by_region_mu", {}) as Dictionary).is_empty(), "FLYING and PHASE trample default to exact zero")
	var assets := state.get("assets", {}) as Dictionary
	_check(int((assets.get("asset.shared", {}) as Dictionary).get("activation_count", 0)) == 1 and int((assets.get("asset.shared", {}) as Dictionary).get("quantity_remaining", -1)) == 2 and (state.get("asset_activation_log", []) as Array).size() == 3, "preferred-color asset quantity decrements exact-once while the shared asset is cooling down")
	var fizzle_receipts := state.get("fizzle_receipts", []) as Array
	_check(fizzle_receipts.size() == 1 and str((fizzle_receipts[0] as Dictionary).get("reason", "")) == "asset_cooldown_active", "cooldown conflict is a consumed legal fizzle")
	_check(bool(kernel.advance_ticks(4).get("accepted", false)), "preferred-color asset can be reused after cooldown expiry")
	state = kernel.domain_state(Codec.DOMAIN_ID)
	assets = state.get("assets", {}) as Dictionary
	_check(int((assets.get("asset.shared", {}) as Dictionary).get("activation_count", 0)) == 2 and int((assets.get("asset.shared", {}) as Dictionary).get("quantity_remaining", -1)) == 1 and (state.get("asset_activation_log", []) as Array).size() == 4, "cooldown reuse consumes exactly one additional preferred-color quantity")
	fizzle_receipts = state.get("fizzle_receipts", []) as Array
	_check(fizzle_receipts.size() == 2 and str((fizzle_receipts[1] as Dictionary).get("reason", "")) == "asset_preferred_color_mismatch", "wrong preferred color fizzles without consuming asset quantity")
	var duplicate := kernel.submit_command(ground)
	_check(bool(duplicate.get("accepted", false)) and bool(duplicate.get("duplicate", false)), "executed root duplicate is idempotently acknowledged")
	_check(kernel.root_commands().size() == 6 and kernel.derived_commands().size() == kernel.derived_outbox().size(), "replay input roots and derived outbox are disjoint and cardinality-bound")
	_check(bool(Validator.validate_terminal_state(state).get("accepted", false)), "terminal monster state passes canonical semantic validation")
	_check(bool(Validator.validate_execution_lineage(kernel.execution_log(), kernel.derived_outbox()).get("accepted", false)), "every derived execution binds an outbox lineage SHA")
	var envelope := kernel.build_replay_recipe()
	var replay := ReplayRunner.new().verify(envelope.get("recipe", {}) as Dictionary, str(envelope.get("recipe_sha256", "")), {Codec.DOMAIN_ID: Reducer})
	_check(
		str(replay.get("status", "")) == "PASS" and int(replay.get("replay_state_hash_mismatch_count", 1)) == 0,
		"fresh replay regenerates derived commands without a second source: %s" % JSON.stringify(replay)
	)
	var tampered_state := state.duplicate(true)
	tampered_state["topology_sha256"] = "0".repeat(64)
	_check(not bool(Codec.validate_state(tampered_state).get("valid", true)), "topology binding tamper fails closed")
	var quantity_tamper := state.duplicate(true)
	var tampered_shared_asset := (quantity_tamper.get("assets", {}) as Dictionary).get("asset.shared", {}) as Dictionary
	tampered_shared_asset["quantity_remaining"] = 3
	_check(not bool(Validator.validate_terminal_state(quantity_tamper).get("accepted", true)), "preferred-color quantity tamper fails exact-once terminal validation")
	kernel.free()


func _test_movement_class_trample_defaults() -> void:
	for movement_class in Codec.MOVEMENT_CLASSES:
		var result := Audit.run_seed(73100 + Codec.MOVEMENT_CLASSES.find(movement_class), movement_class, 2)
		_check(str(result.get("status", "")) == "PASS" and int(result.get("deterministic_replay_count", 0)) == 2, "%s audit passes two fresh replays" % movement_class)
		var trample := result.get("trample_distance_by_region_mu", {}) as Dictionary
		if movement_class == "GROUND":
			_check(_sum_values(trample) == int(result.get("travelled_distance_mu", -1)), "GROUND audit preserves full physical trample distance")
			_check(int(result.get("total_trample_damage", -1)) == _sum_values(result.get("trample_damage_by_region", {}) as Dictionary), "GROUND audit preserves distance-derived trample damage")
		else:
			_check(trample.is_empty() and int(result.get("total_trample_damage", -1)) == 0, "%s audit preserves zero trample" % movement_class)


func _partition(root_seed: int, region_count: int, complexity: String) -> Dictionary:
	var rng := DomainRng.new()
	if not bool(rng.configure(root_seed, PartitionCodec.DOMAIN_ID).get("accepted", false)):
		return {}
	var generated := Partitioner.generate(root_seed, region_count, complexity, rng)
	return (generated.get("partition", {}) as Dictionary).duplicate(true) if bool(generated.get("accepted", false)) else {}


func _start_command(
	command_id: String,
	monster_id: String,
	target_face_id: int,
	maximum_distance_mu: int,
	speed_mu: int,
	asset_id: String,
	preferred_color: String,
	trample_modifiers_ppm: Array,
	expected_revision: int,
	scheduled_tick: int,
	producer_sequence: int
) -> Dictionary:
	var target_point_result := Metric.canonical_target_point(target_face_id)
	var built := AuthorityCommand.build(
		command_id,
		Codec.DOMAIN_ID,
		Codec.START_COMMAND_TYPE,
		"player.focused",
		scheduled_tick,
		30,
		producer_sequence,
		{
			"monster_id": monster_id,
			"target_face_id": target_face_id,
			"target_point": (target_point_result.get("target_point", {}) as Dictionary).duplicate(true),
			"max_geodesic_distance_mu": maximum_distance_mu,
			"speed_mu_per_tick": speed_mu,
			"asset_id": asset_id,
			"preferred_color": preferred_color,
			"trample_modifiers_ppm": trample_modifiers_ppm.duplicate(),
			"expected_move_revision": expected_revision,
		}
	)
	return (built.get("command", {}) as Dictionary).duplicate(true)


func _sum_values(values: Dictionary) -> int:
	var result := 0
	for value_variant in values.values():
		result += int(value_variant)
	return result


func _sum_array(values: Array) -> int:
	var result := 0
	for value_variant in values:
		result += int(value_variant)
	return result


func _unique_int_count(values: Array) -> int:
	var unique := {}
	for value_variant in values:
		unique[int(value_variant)] = true
	return unique.size()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
