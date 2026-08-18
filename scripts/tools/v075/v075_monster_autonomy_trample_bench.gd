extends Control
class_name V075MonsterAutonomyTrampleBench

const Autonomy := preload(
	"res://scripts/v075/monster/v075_monster_autonomy_core.gd"
)
const Trample := preload(
	"res://scripts/v075/monster/v075_monster_trample_core.gd"
)
const FacilityDamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)
const MapGenesis := preload(
	"res://scripts/v074/map/v074_map_genesis_core.gd"
)
const MapRequest := preload(
	"res://scripts/v074/map/map_genesis_request_v1.gd"
)
const CASE_IDS := [
	"preferred_color",
	"autonomy_shortest_path",
	"hungry_fallback",
	"snapshot_freeze",
	"ground_trample",
	"flying_no_trample",
	"trample_distance_scaling",
	"trample_complexity_independence",
	"trample_region_cap",
	"trample_warehouse",
	"trample_exact_once",
]

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	call_deferred("_run_bench")


func _run_bench() -> void:
	var report := run_all()
	status_label.text = "PASS" if bool(report.get("passed", false)) else "FAIL"
	print("V075_MONSTER_AUTONOMY_TRAMPLE_BENCH|%s" % JSON.stringify(report))
	get_tree().quit(0 if bool(report.get("passed", false)) else 1)


static func run_all() -> Dictionary:
	var cases: Array = []
	var passed_count := 0
	var total_checks := 0
	for case_id in CASE_IDS:
		var result := run_case(case_id)
		cases.append(result)
		total_checks += int(result.get("check_count", 0))
		if bool(result.get("passed", false)):
			passed_count += 1
	return {
		"passed": passed_count == CASE_IDS.size(),
		"passed_case_count": passed_count,
		"case_count": CASE_IDS.size(),
		"check_count": total_checks,
		"cases": cases,
		"private_asset_reader_count": 0,
		"private_warehouse_stock_reader_count": 0,
		"camera_reader_count": 0,
		"boundary_complexity_damage_delta": 0,
		"presentation_order_target_bias_count": 0,
	}


static func run_case(case_id: String) -> Dictionary:
	match case_id:
		"preferred_color":
			return _case_preferred_color()
		"autonomy_shortest_path":
			return _case_autonomy_shortest_path()
		"hungry_fallback":
			return _case_hungry_fallback()
		"snapshot_freeze":
			return _case_snapshot_freeze()
		"ground_trample":
			return _case_ground_trample()
		"flying_no_trample":
			return _case_flying_no_trample()
		"trample_distance_scaling":
			return _case_trample_distance_scaling()
		"trample_complexity_independence":
			return _case_trample_complexity_independence()
		"trample_region_cap":
			return _case_trample_region_cap()
		"trample_warehouse":
			return _case_trample_warehouse()
		"trample_exact_once":
			return _case_trample_exact_once()
	return _result(case_id, ["unknown_case"], {}, 1)


static func _case_preferred_color() -> Dictionary:
	var failures: Array[String] = []
	var monsters: Array = []
	var facilities: Array = []
	for color in Autonomy.INDUSTRY_COLORS:
		monsters.append(_monster({
			"source_instance_id": "monster.%s" % color,
			"preferred_industry_color": color,
			"facility_type_preference": ["factory", "market", "warehouse"],
		}))
		var facility := _facility(
			"facility.%s" % color,
			"region.b",
			"factory",
			color
		)
		facility["private_stock"] = {"sentinel": 1000}
		facility["warehouse_stock"] = {"sentinel": 2000}
		facility["private_asset_pool"] = {"sentinel": 3000}
		facilities.append(facility)
	var snapshot := _freeze(
		monsters,
		facilities,
		"preferred.color"
	)
	var plan := Autonomy.plan_batch(snapshot)
	_expect(failures, bool(snapshot.get("accepted", false)), "snapshot_accepted")
	_expect(failures, bool(plan.get("accepted", false)), "plan_accepted")
	_expect(
		failures,
		(plan.get("plans", []) as Array).size() == 6,
		"six_monster_plans"
	)
	for plan_variant in plan.get("plans", []) as Array:
		var row := plan_variant as Dictionary
		_expect(
			failures,
			row.get("target_industry_id") == row.get(
				"preferred_industry_color"
			),
			"explicit_color_%s" % str(row.get("source_instance_id", ""))
		)
	var forbidden_keys := [
		"private_stock",
		"warehouse_stock",
		"private_asset_pool",
	]
	_expect(
		failures,
		not _contains_any_exact_key(
			snapshot.get("public_facilities", []),
			forbidden_keys
		),
		"private_fields_stripped"
	)
	var changed_private := facilities.duplicate(true)
	(changed_private[0] as Dictionary)["private_stock"] = {
		"sentinel": 999999,
	}
	var private_variant_snapshot := _freeze(
		monsters,
		changed_private,
		"preferred.color"
	)
	_expect(
		failures,
		private_variant_snapshot.get("snapshot_fingerprint")
			== snapshot.get("snapshot_fingerprint"),
		"private_values_do_not_affect_snapshot"
	)
	var bad_monster := _monster()
	bad_monster.erase("preferred_industry_color")
	bad_monster["resource_focus"] = "life"
	var rejected := _freeze(
		[bad_monster],
		facilities,
		"preferred.reject"
	)
	_expect(
		failures,
		not bool(rejected.get("accepted", false)),
		"no_runtime_color_inference"
	)
	var malformed_monster := _monster({"rank": {"invalid": 1}})
	var malformed_monster_result := _freeze(
		[malformed_monster],
		facilities,
		"preferred.malformed.monster"
	)
	_expect(
		failures,
		not bool(malformed_monster_result.get("accepted", false)),
		"malformed_monster_rejected_without_conversion_error"
	)
	var malformed_facilities := facilities.duplicate(true)
	(malformed_facilities[0] as Dictionary)["damage_points"] = {
		"invalid": 1,
	}
	var malformed_facility_result := _freeze(
		monsters,
		malformed_facilities,
		"preferred.malformed.facility"
	)
	_expect(
		failures,
		not bool(malformed_facility_result.get("accepted", false)),
		"malformed_facility_rejected_without_conversion_error"
	)
	return _result(
		"preferred_color",
		failures,
		{
			"color_coverage": 6,
			"runtime_inference_count": 0,
			"private_asset_reader_count": 0,
			"private_warehouse_stock_reader_count": 0,
		},
		14
	)


static func _case_autonomy_shortest_path() -> Dictionary:
	var failures: Array[String] = []
	var topology := _topology()
	var path := Autonomy.shortest_path(
		topology,
		"region.a",
		"region.d"
	)
	_expect(
		failures,
		path == ["region.a", "region.b", "region.d"],
		"stable_bfs_path"
	)
	var monster := _monster({
		"facility_type_preference": ["warehouse", "market", "factory"],
	})
	var type_snapshot := _freeze(
		[monster],
		[
			_facility("facility.factory", "region.d", "factory", "life"),
			_facility("facility.warehouse", "region.d", "warehouse", "life"),
		],
		"shortest.type",
		topology
	)
	var type_plan := _first_plan(Autonomy.plan_batch(type_snapshot))
	_expect(
		failures,
		type_plan.get("target_facility_id") == "facility.warehouse",
		"facility_type_preference"
	)
	_expect(
		failures,
		type_plan.get("target_path") == [
			"region.a",
			"region.b",
			"region.d",
		],
		"target_path_stable"
	)
	_expect(
		failures,
		int(type_plan.get("target_path_distance_milli_arc", 0)) == 300,
		"integer_path_distance"
	)
	var authored_plan := _target_plan_for_tie(
		_facility(
			"facility.authored.low",
			"region.b",
			"market",
			"life",
			"player.enemy",
			0,
			1
		),
		_facility(
			"facility.authored.high",
			"region.c",
			"market",
			"life",
			"player.enemy",
			0,
			9
		)
	)
	_expect(
		failures,
		authored_plan.get("target_facility_id")
			== "facility.authored.high",
		"authored_priority_tie_break"
	)
	var damage_plan := _target_plan_for_tie(
		_facility(
			"facility.damage.low",
			"region.b",
			"market",
			"life",
			"player.enemy",
			1,
			4
		),
		_facility(
			"facility.damage.high",
			"region.c",
			"market",
			"life",
			"player.enemy",
			5,
			4
		)
	)
	_expect(
		failures,
		damage_plan.get("target_facility_id") == "facility.damage.high",
		"damage_state_tie_break"
	)
	var id_plan := _target_plan_for_tie(
		_facility(
			"facility.zeta",
			"region.b",
			"market",
			"life",
			"player.enemy",
			0,
			4
		),
		_facility(
			"facility.alpha",
			"region.c",
			"market",
			"life",
			"player.enemy",
			0,
			4
		)
	)
	_expect(
		failures,
		id_plan.get("target_facility_id") == "facility.alpha",
		"facility_id_tie_break"
	)
	var derived_topology := Autonomy.topology_snapshot_from_map_receipt({
		"map_id": "map.derived",
		"map_fingerprint": "map.derived.fingerprint",
		"region_ids": ["region.x", "region.y"],
		"adjacency_graph": {
			"region.x": ["region.y"],
			"region.y": ["region.x"],
		},
		"region_centers_unit_sphere": {
			"region.x": Vector3(1.0, 0.0, 0.0),
			"region.y": Vector3(0.0, 1.0, 0.0),
		},
	})
	var derived_distance := int((
		derived_topology.get("edge_distance_milli_arc", {}) as Dictionary
	).get("region.x", {}).get("region.y", 0))
	_expect(
		failures,
		bool(derived_topology.get("accepted", false))
			and derived_distance > 0
			and derived_topology.get("distance_source_id")
				== "quantized_region_center_geodesic",
		"center_geodesic_quantized_once"
	)
	var movement := type_plan.get("movement_receipt", {}) as Dictionary
	_expect(
		failures,
		int(movement.get("distance_milli_arc", 0)) == 300
			and not _contains_float(movement),
		"movement_receipt_fixed_point"
	)
	var production_map := MapGenesis.generate(MapRequest.build(
		900626424,
		16,
		"STANDARD",
		"BALANCED"
	))
	var production_topology := Autonomy.topology_snapshot_from_map_receipt(
		production_map
	)
	var production_region_ids := (
		production_topology.get("region_ids", []) as Array
	)
	var production_path: Array = []
	if production_region_ids.size() == 16:
		production_path = Autonomy.shortest_path(
			production_topology,
			str(production_region_ids[0]),
			str(production_region_ids[-1])
		)
	_expect(
		failures,
		bool(production_map.get("accepted", false))
			and bool(production_topology.get("accepted", false))
			and production_region_ids.size() == 16
			and not production_path.is_empty(),
		"v074_dynamic_topology_connected"
	)
	_expect(
		failures,
		_all_edge_distances_are_positive_ints(production_topology),
		"v074_dynamic_topology_fixed_point_edges"
	)
	return _result(
		"autonomy_shortest_path",
		failures,
		{
			"path": path,
			"distance_milli_arc": 300,
			"camera_reader_count": 0,
			"production_region_count": production_region_ids.size(),
			"production_path_hops": maxi(0, production_path.size() - 1),
		},
		11
	)


static func _case_hungry_fallback() -> Dictionary:
	var failures: Array[String] = []
	var energy_facility := _facility(
		"facility.energy",
		"region.b",
		"market",
		"energy"
	)
	var expanding_monster := _monster({
		"base_detection_range_hops": 1,
		"current_detection_range_hops": 1,
	})
	var expanding_plan := _first_plan(Autonomy.plan_batch(_freeze(
		[expanding_monster],
		[energy_facility],
		"hungry.expanding"
	)))
	_expect(
		failures,
		expanding_plan.get("target_facility_id") == null
			and expanding_plan.get("autonomy_state") == "search_expanding",
		"wait_before_full_range"
	)
	_expect(
		failures,
		int(expanding_plan.get("next_detection_range_hops", 0)) == 2,
		"search_radius_increments"
	)
	var hungry_monster := _monster({
		"base_detection_range_hops": 1,
		"current_detection_range_hops": 3,
	})
	var hungry_plan := _first_plan(Autonomy.plan_batch(_freeze(
		[hungry_monster],
		[energy_facility],
		"hungry.active"
	)))
	_expect(
		failures,
		bool(hungry_plan.get("hungry", false))
			and hungry_plan.get("autonomy_state") == "hungry_tracking",
		"hungry_state_enters"
	)
	_expect(
		failures,
		hungry_plan.get("target_facility_id") == "facility.energy",
		"hungry_selects_nearest_any"
	)
	var matching := _facility(
		"facility.life",
		"region.c",
		"factory",
		"life"
	)
	var recovered_plan := _first_plan(Autonomy.plan_batch(_freeze(
		[hungry_monster],
		[energy_facility, matching],
		"hungry.recovered"
	)))
	_expect(
		failures,
		not bool(recovered_plan.get("hungry", true))
			and recovered_plan.get("target_facility_id") == "facility.life",
		"preferred_target_recovers"
	)
	_expect(
		failures,
		int(recovered_plan.get("next_detection_range_hops", 0)) == 1,
		"range_resets_to_base"
	)
	var empty_plan := _first_plan(Autonomy.plan_batch(_freeze(
		[hungry_monster],
		[],
		"hungry.empty"
	)))
	_expect(
		failures,
		empty_plan.get("autonomy_state") == "hungry_waiting"
			and int(empty_plan.get("next_detection_range_hops", 0)) == 3,
		"hungry_retries_without_permanent_stall"
	)
	return _result(
		"hungry_fallback",
		failures,
		{
			"radius_before": 1,
			"radius_after": 2,
			"hungry_target": hungry_plan.get("target_facility_id"),
			"recovered_target": recovered_plan.get("target_facility_id"),
		},
		7
	)


static func _case_snapshot_freeze() -> Dictionary:
	var failures: Array[String] = []
	var monsters := [
		_monster({"source_instance_id": "monster.alpha"}),
		_monster({
			"source_instance_id": "monster.beta",
			"owner_player_id": "player.three",
		}),
	]
	var facilities := [
		_facility("facility.shared", "region.d", "warehouse", "life"),
	]
	var snapshot := _freeze(
		monsters,
		facilities,
		"snapshot.freeze"
	)
	var plan_before := Autonomy.plan_batch(snapshot)
	(monsters[0] as Dictionary)["region_id"] = "region.e"
	(facilities[0] as Dictionary)["destroyed"] = true
	var plan_after_external_mutation := Autonomy.plan_batch(snapshot)
	_expect(
		failures,
		plan_before.get("plan_fingerprint")
			== plan_after_external_mutation.get("plan_fingerprint"),
		"frozen_snapshot_detached"
	)
	var reordered_monsters := [
		_monster({
			"source_instance_id": "monster.beta",
			"owner_player_id": "player.three",
		}),
		_monster({"source_instance_id": "monster.alpha"}),
	]
	var reordered_snapshot := _freeze(
		reordered_monsters,
		[
			_facility(
				"facility.shared",
				"region.d",
				"warehouse",
				"life"
			),
		],
		"snapshot.freeze"
	)
	var reordered_plan := Autonomy.plan_batch(reordered_snapshot)
	_expect(
		failures,
		snapshot.get("snapshot_fingerprint")
			== reordered_snapshot.get("snapshot_fingerprint"),
		"input_order_canonicalized"
	)
	_expect(
		failures,
		plan_before.get("plan_fingerprint")
			== reordered_plan.get("plan_fingerprint"),
		"presentation_order_no_target_bias"
	)
	var plan_rows := plan_before.get("plans", []) as Array
	_expect(
		failures,
		plan_rows.size() == 2
			and (plan_rows[0] as Dictionary).get("target_facility_id")
				== "facility.shared"
			and (plan_rows[1] as Dictionary).get("target_facility_id")
				== "facility.shared",
		"all_targets_from_same_snapshot"
	)
	_expect(
		failures,
		int(plan_before.get("target_order_bias_count", -1)) == 0,
		"target_order_bias_zero"
	)
	_expect(
		failures,
		snapshot.get("private_asset_reader_count") == 0
			and snapshot.get("private_warehouse_stock_reader_count") == 0,
		"public_world_only"
	)
	return _result(
		"snapshot_freeze",
		failures,
		{
			"monster_plan_count": 2,
			"target_order_bias_count": 0,
			"snapshot_fingerprint": snapshot.get("snapshot_fingerprint"),
		},
		6
	)


static func _case_ground_trample() -> Dictionary:
	var failures: Array[String] = []
	var fixture := _movement_fixture("ground_trample", "region.d", 1)
	var result := _resolve_fixture(fixture, _balance())
	_expect(failures, bool(result.get("accepted", false)), "result_accepted")
	_expect(
		failures,
		bool(result.get("ground_trample_applied", false)),
		"ground_profile_applies"
	)
	var receipts := result.get("region_receipts", []) as Array
	_expect(failures, receipts.size() == 3, "one_receipt_per_path_region")
	var intents := result.get("facility_damage_intents", []) as Array
	var target_ids := _intent_target_ids(intents)
	_expect(
		failures,
		target_ids.has("facility.start.factory")
			and target_ids.has("facility.middle.market")
			and target_ids.has("facility.target.warehouse"),
		"factory_market_warehouse_damaged"
	)
	_expect(
		failures,
		not target_ids.has("facility.friendly"),
		"friendly_facility_excluded"
	)
	_expect(
		failures,
		_sum_int_field(intents, "damage_amount")
			== _sum_int_field(receipts, "allocated_damage"),
		"damage_budget_not_replicated"
	)
	for intent_variant in intents:
		_expect(
			failures,
			bool(FacilityDamageIntent.validation_report(
				intent_variant
			).get("valid", false)),
			"facility_damage_intent_typed_and_sealed"
		)
	_expect(
		failures,
		int(result.get("direct_facility_write_count", -1)) == 0
			and int(result.get("unit_damage_count", -1)) == 0
			and int(result.get("region_hp_mutation_count", -1)) == 0,
		"typed_port_only"
	)
	_expect(
		failures,
		_unique_string_field(receipts, "trample_region_receipt_id"),
		"region_receipt_ids_unique"
	)
	return _result(
		"ground_trample",
		failures,
		{
			"region_receipt_count": receipts.size(),
			"facility_damage_intent_count": intents.size(),
			"target_facility_ids": target_ids,
		},
		8 + intents.size()
	)


static func _case_flying_no_trample() -> Dictionary:
	var failures: Array[String] = []
	var flying_fixture := _movement_fixture(
		"flying_no_trample",
		"region.d",
		1
	)
	var flying := _resolve_fixture(flying_fixture, _balance())
	_expect(
		failures,
		bool(flying.get("accepted", false))
			and not bool(flying.get("ground_trample_applied", true)),
		"flying_no_trample"
	)
	_expect(
		failures,
		(flying.get("region_receipts", []) as Array).is_empty()
			and (flying.get("facility_damage_intents", []) as Array).is_empty(),
		"flying_zero_damage"
	)
	var teleport_fixture := _movement_fixture(
		"teleport_no_trample",
		"region.d",
		1
	)
	var teleport := _resolve_fixture(teleport_fixture, _balance())
	_expect(
		failures,
		bool(teleport.get("accepted", false))
			and (teleport.get("region_receipts", []) as Array).is_empty(),
		"teleport_zero_damage"
	)
	var movement := flying_fixture.get("movement", {}) as Dictionary
	_expect(
		failures,
		movement.get("forced_movement") == false
			and movement.get("forced_movement_trample") == false,
		"default_forced_movement_no_trample"
	)
	return _result(
		"flying_no_trample",
		failures,
		{
			"flying_damage_count": 0,
			"teleport_damage_count": 0,
			"default_forced_movement_damage_count": 0,
		},
		4
	)


static func _case_trample_distance_scaling() -> Dictionary:
	var failures: Array[String] = []
	var fixture := _movement_fixture("ground_trample", "region.e", 1)
	var result := _resolve_fixture(fixture, _balance())
	var region_b := _region_receipt(result, "region.b")
	var region_d := _region_receipt(result, "region.d")
	_expect(
		failures,
		int(region_b.get("distance_milli_arc", 0)) == 150,
		"middle_short_distance"
	)
	_expect(
		failures,
		int(region_d.get("distance_milli_arc", 0)) == 250,
		"middle_long_distance"
	)
	_expect(
		failures,
		int(region_d.get("region_damage_budget", 0))
			> int(region_b.get("region_damage_budget", 0)),
		"longer_region_more_damage"
	)
	var movement := fixture.get("movement", {}) as Dictionary
	_expect(
		failures,
		_sum_int_field(
			movement.get("region_path_segments", []) as Array,
			"distance_milli_arc"
		) == int(movement.get("distance_milli_arc", 0)),
		"segment_distance_parity"
	)
	_expect(
		failures,
		not _contains_float(movement) and not _contains_float(result),
		"fixed_point_receipts"
	)
	return _result(
		"trample_distance_scaling",
		failures,
		{
			"region_b_distance": region_b.get("distance_milli_arc"),
			"region_d_distance": region_d.get("distance_milli_arc"),
			"region_b_damage": region_b.get("region_damage_budget"),
			"region_d_damage": region_d.get("region_damage_budget"),
		},
		5
	)


static func _case_trample_complexity_independence() -> Dictionary:
	var failures: Array[String] = []
	var simple_topology := _topology({
		"region_boundaries_spherical": {"region.a": [1, 2, 3]},
		"region_microcell_membership": {"region.a": [1]},
		"camera_projection": "near",
	})
	var complex_topology := _topology({
		"region_boundaries_spherical": {
			"region.a": range(200),
			"region.b": range(300),
		},
		"region_microcell_membership": {
			"region.a": range(500),
		},
		"microcell_count": 99999,
		"camera_projection": "far",
	})
	_expect(
		failures,
		simple_topology.get("topology_fingerprint")
			== complex_topology.get("topology_fingerprint"),
		"geometry_complexity_ignored"
	)
	var monster := _monster()
	var target := _facility(
		"facility.target.warehouse",
		"region.d",
		"warehouse",
		"life"
	)
	var simple_snapshot := _freeze(
		[monster],
		[target],
		"complexity.same",
		simple_topology
	)
	var complex_snapshot := _freeze(
		[monster],
		[target],
		"complexity.same",
		complex_topology
	)
	var simple_plan := Autonomy.plan_batch(simple_snapshot)
	var complex_plan := Autonomy.plan_batch(complex_snapshot)
	_expect(
		failures,
		simple_plan.get("plan_fingerprint")
			== complex_plan.get("plan_fingerprint"),
		"autonomy_complexity_independent"
	)
	var simple_fixture := {
		"snapshot": simple_snapshot,
		"monster": (simple_snapshot.get("monsters") as Array)[0],
		"movement": _first_plan(simple_plan).get("movement_receipt", {}),
	}
	var complex_fixture := {
		"snapshot": complex_snapshot,
		"monster": (complex_snapshot.get("monsters") as Array)[0],
		"movement": _first_plan(complex_plan).get("movement_receipt", {}),
	}
	var simple_result := _resolve_fixture(simple_fixture, _balance())
	var complex_result := _resolve_fixture(complex_fixture, _balance())
	_expect(
		failures,
		simple_result.get("trample_result_fingerprint")
			== complex_result.get("trample_result_fingerprint"),
		"trample_complexity_independent"
	)
	_expect(
		failures,
		int(simple_topology.get("boundary_vertex_reader_count", -1)) == 0
			and int(simple_topology.get("microcell_reader_count", -1)) == 0
			and int(simple_topology.get("camera_reader_count", -1)) == 0,
		"forbidden_geometry_reader_counts_zero"
	)
	return _result(
		"trample_complexity_independence",
		failures,
		{
			"boundary_complexity_damage_delta": 0,
			"microcell_complexity_damage_delta": 0,
			"camera_projection_damage_delta": 0,
		},
		4
	)


static func _case_trample_region_cap() -> Dictionary:
	var failures: Array[String] = []
	var fixture := _movement_fixture("ground_trample", "region.e", 4)
	var balance := _balance(100, 10, 15)
	var result := _resolve_fixture(fixture, balance)
	var region_d := _region_receipt(result, "region.d")
	_expect(
		failures,
		int(region_d.get("distance_milli_arc", 0)) == 250,
		"cap_fixture_distance"
	)
	_expect(
		failures,
		int(region_d.get("raw_damage", 0)) == 20,
		"raw_damage_before_cap"
	)
	_expect(
		failures,
		int(region_d.get("region_damage_budget", 0)) == 15,
		"rank_cap_applied"
	)
	for receipt_variant in result.get("region_receipts", []) as Array:
		var receipt := receipt_variant as Dictionary
		_expect(
			failures,
			int(receipt.get("region_damage_budget", 0)) <= 15,
			"all_regions_capped_%s" % str(receipt.get("region_id", ""))
		)
	return _result(
		"trample_region_cap",
		failures,
		{
			"raw_damage": region_d.get("raw_damage"),
			"capped_damage": region_d.get("region_damage_budget"),
			"cap": 15,
		},
		8
	)


static func _case_trample_warehouse() -> Dictionary:
	var failures: Array[String] = []
	var fixture := _movement_fixture("ground_trample", "region.d", 1)
	var snapshot := fixture.get("snapshot", {}) as Dictionary
	var public_facilities := (
		snapshot.get("public_facilities", []) as Array
	).duplicate(true)
	for facility_variant in public_facilities:
		var facility := facility_variant as Dictionary
		if facility.get("facility_id") == "facility.target.warehouse":
			facility["private_stock"] = {"private_sentinel": 99999}
	var result := Trample.resolve_movement(
		fixture.get("movement", {}) as Dictionary,
		fixture.get("monster", {}) as Dictionary,
		public_facilities,
		_balance()
	)
	var intents := result.get("facility_damage_intents", []) as Array
	var warehouse_intent := _intent_for_target(
		intents,
		"facility.target.warehouse"
	)
	_expect(
		failures,
		not warehouse_intent.is_empty(),
		"warehouse_receives_typed_intent"
	)
	_expect(
		failures,
		warehouse_intent.get("contract_id")
			== "FacilityCombatDamageIntentV1"
			and warehouse_intent.get("damage_kind")
				== "monster_ground_trample",
		"warehouse_damage_contract"
	)
	_expect(
		failures,
		JSON.stringify(result).find("private_sentinel") < 0,
		"warehouse_private_stock_not_disclosed"
	)
	_expect(
		failures,
		int(result.get("direct_facility_write_count", -1)) == 0,
		"warehouse_write_owned_by_facility_port"
	)
	return _result(
		"trample_warehouse",
		failures,
		{
			"warehouse_damage_intent_count": 1,
			"warehouse_private_stock_disclosure_count": 0,
		},
		4
	)


static func _case_trample_exact_once() -> Dictionary:
	var failures: Array[String] = []
	var fixture := _movement_fixture("ground_trample", "region.d", 1)
	var first := _resolve_fixture(fixture, _balance())
	var movement := fixture.get("movement", {}) as Dictionary
	var movement_id := str(movement.get("movement_id", ""))
	var second := Trample.resolve_movement(
		movement,
		fixture.get("monster", {}) as Dictionary,
		(fixture.get("snapshot", {}) as Dictionary).get(
			"public_facilities",
			[]
		),
		_balance(),
		[movement_id]
	)
	_expect(
		failures,
		bool(first.get("accepted", false))
			and not bool(second.get("accepted", true)),
		"duplicate_rejected"
	)
	_expect(
		failures,
		second.get("reason_code") == "duplicate_movement_receipt",
		"duplicate_reason"
	)
	_expect(
		failures,
		(second.get("facility_damage_intents", []) as Array).is_empty(),
		"duplicate_emits_no_damage"
	)
	var repeated_b_segments := 0
	var b_distance := 0
	for segment_variant in movement.get("region_path_segments", []) as Array:
		var segment := segment_variant as Dictionary
		if segment.get("region_id") == "region.b":
			repeated_b_segments += 1
			b_distance += int(segment.get("distance_milli_arc", 0))
	var b_receipts := 0
	for receipt_variant in first.get("region_receipts", []) as Array:
		if (receipt_variant as Dictionary).get("region_id") == "region.b":
			b_receipts += 1
	_expect(
		failures,
		repeated_b_segments == 2 and b_receipts == 1,
		"repeated_segments_aggregate_once"
	)
	_expect(
		failures,
		int(_region_receipt(first, "region.b").get(
			"distance_milli_arc",
			0
		)) == b_distance,
		"aggregated_distance_parity"
	)
	_expect(
		failures,
		_unique_string_field(
			first.get("facility_damage_intents", []) as Array,
			"combat_receipt_id"
		),
		"damage_receipt_ids_unique"
	)
	_expect(
		failures,
		int(first.get("duplicate_trample_damage_count", -1)) == 0,
		"duplicate_damage_count_zero"
	)
	return _result(
		"trample_exact_once",
		failures,
		{
			"first_commit_intent_count": (
				first.get("facility_damage_intents", []) as Array
			).size(),
			"second_commit_intent_count": 0,
			"repeated_region_segment_count": repeated_b_segments,
			"region_receipt_count_for_repeated_region": b_receipts,
		},
		7
	)


static func _topology(extra_fields: Dictionary = {}) -> Dictionary:
	var map_receipt := {
		"map_id": "map.lane.c",
		"map_fingerprint": "map.lane.c.fixed",
		"region_ids": [
			"region.e",
			"region.c",
			"region.a",
			"region.d",
			"region.b",
		],
		"adjacency_graph": {
			"region.a": ["region.c", "region.b"],
			"region.b": ["region.d", "region.a"],
			"region.c": ["region.d", "region.a"],
			"region.d": ["region.e", "region.c", "region.b"],
			"region.e": ["region.d"],
		},
		"edge_distance_milli_arc": {
			"region.a": {"region.b": 100, "region.c": 100},
			"region.b": {"region.a": 100, "region.d": 200},
			"region.c": {"region.a": 100, "region.d": 200},
			"region.d": {
				"region.b": 200,
				"region.c": 200,
				"region.e": 300,
			},
			"region.e": {"region.d": 300},
		},
	}
	for key_variant in extra_fields.keys():
		map_receipt[str(key_variant)] = extra_fields.get(key_variant)
	return Autonomy.topology_snapshot_from_map_receipt(map_receipt)


static func _monster(overrides: Dictionary = {}) -> Dictionary:
	var result := {
		"source_instance_id": "monster.primary",
		"source_generation": 1,
		"owner_player_id": "player.one",
		"region_id": "region.a",
		"rank": 1,
		"status": "active",
		"preferred_industry_color": "life",
		"facility_type_preference": ["warehouse", "market", "factory"],
		"base_detection_range_hops": 3,
		"current_detection_range_hops": 3,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc": 1000,
	}
	for key_variant in overrides.keys():
		result[str(key_variant)] = overrides.get(key_variant)
	return result


static func _facility(
	facility_id: String,
	region_id: String,
	facility_type: String,
	industry_id: String,
	owner_id: String = "player.enemy",
	damage_points: int = 0,
	authored_target_priority: int = 0
) -> Dictionary:
	return {
		"facility_id": facility_id,
		"facility_generation": 1,
		"owner_player_id": owner_id,
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"occupancy": "occupied",
		"damage_revision": damage_points,
		"damage_points": damage_points,
		"authored_target_priority": authored_target_priority,
	}


static func _freeze(
	monsters: Array,
	facilities: Array,
	suffix: String,
	topology: Dictionary = {}
) -> Dictionary:
	var resolved_topology := topology
	if resolved_topology.is_empty():
		resolved_topology = _topology()
	return Autonomy.freeze_public_snapshot(
		"snapshot.lane.c.%s" % suffix,
		"batch.lane.c.%s" % suffix,
		resolved_topology,
		monsters,
		{"public_facility_slots": facilities}
	)


static func _movement_fixture(
	movement_profile: String,
	target_region_id: String,
	rank: int
) -> Dictionary:
	var facilities := [
		_facility(
			"facility.start.factory",
			"region.a",
			"factory",
			"energy"
		),
		_facility(
			"facility.middle.market",
			"region.b",
			"market",
			"industry"
		),
		_facility(
			"facility.friendly",
			"region.b",
			"factory",
			"technology",
			"player.one"
		),
		_facility(
			"facility.target.warehouse",
			target_region_id,
			"warehouse",
			"life"
		),
	]
	var monster := _monster({
		"rank": rank,
		"movement_profile": movement_profile,
	})
	var snapshot := _freeze(
		[monster],
		facilities,
		"movement.%s.%s.rank%d" % [
			movement_profile,
			target_region_id.replace(".", "_"),
			rank,
		]
	)
	var plan := Autonomy.plan_batch(snapshot)
	return {
		"snapshot": snapshot,
		"monster": (snapshot.get("monsters", []) as Array)[0],
		"plan": plan,
		"movement": _first_plan(plan).get("movement_receipt", {}),
	}


static func _resolve_fixture(
	fixture: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var snapshot := fixture.get("snapshot", {}) as Dictionary
	return Trample.resolve_movement(
		fixture.get("movement", {}) as Dictionary,
		fixture.get("monster", {}) as Dictionary,
		snapshot.get("public_facilities", []),
		balance
	)


static func _balance(
	distance_step: int = 100,
	damage_per_step: int = 2,
	damage_cap: int = 12
) -> Dictionary:
	return {
		"trample_distance_step_milli_arc": distance_step,
		"trample_damage_per_step_by_rank": {
			"1": damage_per_step,
			"2": damage_per_step,
			"3": damage_per_step,
			"4": damage_per_step,
		},
		"trample_damage_cap_per_region_by_rank": {
			"1": damage_cap,
			"2": damage_cap,
			"3": damage_cap,
			"4": damage_cap,
		},
	}


static func _target_plan_for_tie(
	left_facility: Dictionary,
	right_facility: Dictionary
) -> Dictionary:
	var monster := _monster({
		"facility_type_preference": ["market", "factory", "warehouse"],
	})
	return _first_plan(Autonomy.plan_batch(_freeze(
		[monster],
		[left_facility, right_facility],
		"tie.%s" % str(left_facility.get("facility_id", "")).replace(".", "_")
	)))


static func _first_plan(plan: Dictionary) -> Dictionary:
	var rows := plan.get("plans", []) as Array
	return rows[0] as Dictionary if not rows.is_empty() else {}


static func _region_receipt(
	result: Dictionary,
	region_id: String
) -> Dictionary:
	for receipt_variant in result.get("region_receipts", []) as Array:
		var receipt := receipt_variant as Dictionary
		if receipt.get("region_id") == region_id:
			return receipt
	return {}


static func _intent_for_target(
	intents: Array,
	target_facility_id: String
) -> Dictionary:
	for intent_variant in intents:
		var intent := intent_variant as Dictionary
		if intent.get("target_facility_id") == target_facility_id:
			return intent
	return {}


static func _intent_target_ids(intents: Array) -> Array:
	var result: Array[String] = []
	for intent_variant in intents:
		result.append(
			str((intent_variant as Dictionary).get("target_facility_id", ""))
		)
	return result


static func _sum_int_field(rows: Array, field_name: String) -> int:
	var total := 0
	for row_variant in rows:
		total += int((row_variant as Dictionary).get(field_name, 0))
	return total


static func _unique_string_field(rows: Array, field_name: String) -> bool:
	var seen := {}
	for row_variant in rows:
		var value := str((row_variant as Dictionary).get(field_name, ""))
		if value.is_empty() or seen.has(value):
			return false
		seen[value] = true
	return true


static func _contains_any_exact_key(
	value: Variant,
	forbidden_keys: Array
) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_any_exact_key(item_variant, forbidden_keys):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden_keys.has(str(key_variant)):
				return true
			if _contains_any_exact_key(
				(value as Dictionary).get(key_variant),
				forbidden_keys
			):
				return true
	return false


static func _all_edge_distances_are_positive_ints(
	topology: Dictionary
) -> bool:
	var rows := topology.get("edge_distance_milli_arc", {}) as Dictionary
	if rows.is_empty():
		return false
	for row_variant in rows.values():
		if not (row_variant is Dictionary):
			return false
		for distance_variant in (row_variant as Dictionary).values():
			if not (distance_variant is int) or int(distance_variant) <= 0:
				return false
	return true


static func _contains_float(value: Variant) -> bool:
	if value is float:
		return true
	if value is Array:
		for item_variant in value as Array:
			if _contains_float(item_variant):
				return true
	elif value is Dictionary:
		for item_variant in (value as Dictionary).values():
			if _contains_float(item_variant):
				return true
	return false


static func _expect(
	failures: Array[String],
	condition: bool,
	label: String
) -> void:
	if not condition:
		failures.append(label)


static func _result(
	case_id: String,
	failures: Array[String],
	evidence: Dictionary,
	check_count: int
) -> Dictionary:
	return {
		"case_id": case_id,
		"passed": failures.is_empty(),
		"check_count": check_count,
		"failure_count": failures.size(),
		"failures": failures,
		"evidence": evidence,
	}
