extends SceneTree

const MapGenesis := preload(
	"res://scripts/v074/map/v074_map_genesis_core.gd"
)
const MapRequest := preload(
	"res://scripts/v074/map/map_genesis_request_v1.gd"
)
const FacilityRuntime := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const Autonomy := preload(
	"res://scripts/v075/monster/v075_monster_autonomy_core.gd"
)
const Trample := preload(
	"res://scripts/v075/monster/v075_monster_trample_core.gd"
)

const MAP_SEED := 900626424
const REGION_COUNT := 16


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var map_receipt := MapGenesis.generate(MapRequest.build(
		MAP_SEED,
		REGION_COUNT,
		"STANDARD",
		"BALANCED"
	))
	var region_ids := _sorted_ids(map_receipt.get("region_ids", []))
	var adjacency := map_receipt.get("adjacency_graph", {}) as Dictionary
	var centers := (
		map_receipt.get("region_centers_unit_sphere", {}) as Dictionary
	)
	_expect(
		failures,
		bool(map_receipt.get("accepted", false))
			and int(map_receipt.get("region_count", 0)) == REGION_COUNT
			and REGION_COUNT != 6,
		"real_dynamic_map_receipt"
	)
	_expect(
		failures,
		region_ids.size() == REGION_COUNT
			and adjacency.size() == REGION_COUNT
			and centers.size() == REGION_COUNT,
		"real_topology_fields"
	)

	var start_region := str(region_ids[0])
	var bfs := _bfs(adjacency, start_region)
	var distances := bfs.get("distances", {}) as Dictionary
	var far_region := _farthest_region(distances, start_region)
	var near_region := _nearest_same_color_target_region(
		distances,
		start_region,
		far_region
	)
	var near_hops := int(distances.get(near_region, -1))
	var far_hops := int(distances.get(far_region, -1))
	_expect(
		failures,
		distances.size() == REGION_COUNT
			and not near_region.is_empty()
			and near_hops > 0
			and near_hops < far_hops,
		"dynamic_graph_target_distances"
	)

	var slots := [
		FacilityRuntime.build_occupied_slot(
			near_region,
			1,
			"factory",
			"life",
			0,
			"facility.dynamic.near",
			1,
			"player.enemy",
			1,
			0,
			0
		),
		FacilityRuntime.build_occupied_slot(
			far_region,
			1,
			"warehouse",
			"life",
			0,
			"facility.dynamic.far",
			1,
			"player.enemy",
			1,
			0,
			0
		),
		FacilityRuntime.build_occupied_slot(
			start_region,
			1,
			"market",
			"energy",
			0,
			"facility.dynamic.distractor",
			1,
			"player.enemy",
			1,
			1,
			1
		),
	]
	var facility_state := FacilityRuntime.lock_batch(
		"batch.dynamic.map.facilities",
		["player.one", "player.enemy"],
		["player.one", "player.enemy"],
		{
			"player.one": [],
			"player.enemy": [],
		},
		slots
	)
	var facility_projection := FacilityRuntime.public_projection(
		facility_state
	)
	_expect(
		failures,
		not facility_state.is_empty()
			and bool(FacilityRuntime.validation_report(
				facility_state
			).get("valid", false))
			and (facility_projection.get(
				"public_facility_slots",
				[]
			) as Array).size() == 3,
		"real_facility_public_projection"
	)

	var topology_a := Autonomy.topology_snapshot_from_map_receipt(
		map_receipt
	)
	var topology_b := Autonomy.topology_snapshot_from_map_receipt(
		_visual_only_map_variant(map_receipt)
	)
	_expect(
		failures,
		bool(topology_a.get("accepted", false))
			and bool(topology_b.get("accepted", false))
			and topology_a.get("distance_source_id")
				== "quantized_region_center_geodesic",
		"dynamic_map_fixed_point_adapter"
	)
	_expect(
		failures,
		topology_a.get("topology_fingerprint")
			== topology_b.get("topology_fingerprint")
			and topology_a.get("edge_distance_milli_arc")
				== topology_b.get("edge_distance_milli_arc"),
		"visual_complexity_topology_independence"
	)

	var max_hops := 0
	for distance_variant in distances.values():
		max_hops = maxi(max_hops, int(distance_variant))
	var monster_alpha := _monster(
		"monster.dynamic.alpha",
		start_region,
		max_hops
	)
	var monster_beta := _monster(
		"monster.dynamic.beta",
		start_region,
		max_hops
	)
	var projection_a := _projection_with_private_sentinels(
		facility_projection,
		111,
		false
	)
	var projection_b := _projection_with_private_sentinels(
		facility_projection,
		999999,
		true
	)
	var snapshot_a := Autonomy.freeze_public_snapshot(
		"snapshot.dynamic.map.integration",
		"batch.dynamic.map.integration",
		topology_a,
		[monster_alpha, monster_beta],
		projection_a
	)
	var snapshot_b := Autonomy.freeze_public_snapshot(
		"snapshot.dynamic.map.integration",
		"batch.dynamic.map.integration",
		topology_b,
		[monster_beta, monster_alpha],
		projection_b
	)
	_expect(
		failures,
		bool(snapshot_a.get("accepted", false))
			and bool(snapshot_b.get("accepted", false)),
		"frozen_snapshots_accepted"
	)
	_expect(
		failures,
		snapshot_a.get("snapshot_fingerprint")
			== snapshot_b.get("snapshot_fingerprint"),
		"input_order_and_private_values_canonicalized"
	)
	_expect(
		failures,
		not _contains_forbidden_private_key(
			snapshot_a.get("public_facilities", [])
		)
			and JSON.stringify(snapshot_a).find("private.sentinel") < 0
			and JSON.stringify(snapshot_b).find("private.sentinel") < 0,
		"private_asset_and_warehouse_stock_not_read"
	)

	var plan_a := Autonomy.plan_batch(snapshot_a)
	var plan_b := Autonomy.plan_batch(snapshot_b)
	_expect(
		failures,
		bool(plan_a.get("accepted", false))
			and bool(plan_b.get("accepted", false)),
		"dynamic_map_plans_accepted"
	)
	_expect(
		failures,
		plan_a.get("plan_fingerprint") == plan_b.get("plan_fingerprint")
			and int(plan_a.get("target_order_bias_count", -1)) == 0,
		"same_frozen_snapshot_order_unbiased"
	)
	var alpha_a := _plan_for_source(plan_a, "monster.dynamic.alpha")
	var beta_a := _plan_for_source(plan_a, "monster.dynamic.beta")
	var alpha_b := _plan_for_source(plan_b, "monster.dynamic.alpha")
	var expected_path := _shortest_path(
		adjacency,
		start_region,
		near_region
	)
	_expect(
		failures,
		alpha_a.get("target_facility_id") == "facility.dynamic.near"
			and beta_a.get("target_facility_id") == "facility.dynamic.near",
		"nearest_same_color_target"
	)
	_expect(
		failures,
		alpha_a.get("target_facility_type") == "factory"
			and far_hops > near_hops,
		"distance_precedes_warehouse_type_preference"
	)
	_expect(
		failures,
		alpha_a.get("target_path") == expected_path
			and beta_a.get("target_path") == expected_path,
		"adjacency_shortest_path"
	)
	_expect(
		failures,
		expected_path.size() == near_hops + 1
			and expected_path[0] == start_region
			and expected_path[-1] == near_region,
		"shortest_path_hop_parity"
	)

	var movement_a := alpha_a.get("movement_receipt", {}) as Dictionary
	var movement_b := alpha_b.get("movement_receipt", {}) as Dictionary
	var segments_a := movement_a.get("region_path_segments", []) as Array
	_expect(
		failures,
		not movement_a.is_empty()
			and segments_a.size() >= near_hops + 1
			and int(movement_a.get("distance_milli_arc", 0)) > 0,
		"multi_region_fixed_point_movement"
	)
	_expect(
		failures,
		_sum_distance(segments_a)
			== int(movement_a.get("distance_milli_arc", -1))
			and not _contains_float(movement_a),
		"segment_distance_integer_parity"
	)
	_expect(
		failures,
		movement_a.get("movement_receipt_fingerprint")
			== movement_b.get("movement_receipt_fingerprint")
			and movement_a.get("region_path_segments")
				== movement_b.get("region_path_segments"),
		"camera_screen_polygon_independent_segments"
	)

	var monster_source_a := _monster_from_snapshot(
		snapshot_a,
		"monster.dynamic.alpha"
	)
	var monster_source_b := _monster_from_snapshot(
		snapshot_b,
		"monster.dynamic.alpha"
	)
	var trample_a := Trample.resolve_movement(
		movement_a,
		monster_source_a,
		snapshot_a.get("public_facilities", []),
		_balance()
	)
	var trample_b := Trample.resolve_movement(
		movement_b,
		monster_source_b,
		snapshot_b.get("public_facilities", []),
		_balance()
	)
	_expect(
		failures,
		bool(trample_a.get("accepted", false))
			and bool(trample_b.get("accepted", false)),
		"dynamic_map_trample_accepted"
	)
	_expect(
		failures,
		trample_a.get("trample_result_fingerprint")
			== trample_b.get("trample_result_fingerprint")
			and _trample_distance_parity(movement_a, trample_a),
		"fixed_point_trample_complexity_independence"
	)
	_expect(
		failures,
		int(plan_a.get("private_asset_reader_count", -1)) == 0
			and int(plan_a.get(
				"private_warehouse_stock_reader_count",
				-1
			)) == 0
			and int(plan_a.get("camera_reader_count", -1)) == 0
			and int(plan_a.get("gameplay_rng_draw_count", -1)) == 0,
		"authority_independence_counters"
	)
	_expect(
		failures,
		int(trample_a.get("direct_facility_write_count", -1)) == 0
			and int(trample_a.get("gameplay_rng_draw_count", -1)) == 0,
		"trample_typed_port_only"
	)

	var passed := failures.is_empty()
	var evidence := {
		"map_seed": MAP_SEED,
		"region_count": region_ids.size(),
		"start_region": start_region,
		"near_region": near_region,
		"near_hops": near_hops,
		"far_region": far_region,
		"far_hops": far_hops,
		"shortest_path": expected_path,
		"movement_distance_milli_arc": movement_a.get(
			"distance_milli_arc"
		),
		"movement_segment_count": segments_a.size(),
		"target_order_bias_count": plan_a.get("target_order_bias_count"),
		"private_asset_reader_count": plan_a.get(
			"private_asset_reader_count"
		),
		"private_warehouse_stock_reader_count": plan_a.get(
			"private_warehouse_stock_reader_count"
		),
		"camera_reader_count": plan_a.get("camera_reader_count"),
		"combat_catalog_present": false,
		"combat_catalog_note": "not present on isolated Lane C base",
		"failure_count": failures.size(),
		"failures": failures,
	}
	print(
		"V075_MONSTER_AUTONOMY_DYNAMIC_MAP_INTEGRATION_TEST"
		+ "|status=%s|checks=22|evidence=%s" % [
			"PASS" if passed else "FAIL",
			JSON.stringify(evidence),
		]
	)
	quit(0 if passed else 1)


func _monster(
	source_instance_id: String,
	region_id: String,
	detection_range_hops: int
) -> Dictionary:
	return {
		"source_instance_id": source_instance_id,
		"source_generation": 1,
		"owner_player_id": "player.one",
		"region_id": region_id,
		"rank": 1,
		"status": "active",
		"preferred_industry_color": "life",
		"facility_type_preference": ["warehouse", "market", "factory"],
		"base_detection_range_hops": detection_range_hops,
		"current_detection_range_hops": detection_range_hops,
		"movement_profile": "ground_trample",
		"movement_budget_milli_arc": 1000000000,
	}


func _visual_only_map_variant(map_receipt: Dictionary) -> Dictionary:
	var variant := map_receipt.duplicate(true)
	var reversed_adjacency := (
		map_receipt.get("adjacency_graph", {}) as Dictionary
	).duplicate(true)
	for region_variant in reversed_adjacency.keys():
		var neighbors := (
			reversed_adjacency.get(region_variant, []) as Array
		).duplicate()
		neighbors.reverse()
		reversed_adjacency[region_variant] = neighbors
	variant["adjacency_graph"] = reversed_adjacency
	variant["camera_zoom"] = 9876.5
	variant["camera_projection"] = "screen.sentinel"
	variant["screen_size"] = Vector2(8192.0, 4320.0)
	variant["region_boundaries_spherical"] = {
		"visual.sentinel": range(2048),
	}
	variant["region_boundary_lods_spherical"] = {
		"visual.sentinel": [range(512), range(1024)],
	}
	variant["microgrid"] = {
		"visual_only_microcell_count": 999999,
		"visual_only_vertices": range(4096),
	}
	return variant


func _projection_with_private_sentinels(
	projection: Dictionary,
	sentinel_value: int,
	reverse_rows: bool
) -> Dictionary:
	var result := projection.duplicate(true)
	result["asset_pool"] = {
		"life": sentinel_value,
		"private_marker": "private.sentinel.%d" % sentinel_value,
	}
	var rows := (
		result.get("public_facility_slots", []) as Array
	).duplicate(true)
	for row_variant in rows:
		var row := row_variant as Dictionary
		row["private_stock"] = {
			"life": sentinel_value,
			"marker": "private.sentinel.%d" % sentinel_value,
		}
		row["warehouse_private_stock"] = {
			"shipping": sentinel_value,
		}
		row["private_logistics_plan"] = {
			"future_region": "private.sentinel.%d" % sentinel_value,
		}
	if reverse_rows:
		rows.reverse()
	result["public_facility_slots"] = rows
	return result


func _bfs(adjacency: Dictionary, start_region: String) -> Dictionary:
	var distances := {start_region: 0}
	var predecessors := {}
	var queue: Array[String] = [start_region]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		var neighbors := _sorted_ids(adjacency.get(current, []))
		for neighbor in neighbors:
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances.get(current, 0)) + 1
			predecessors[neighbor] = current
			queue.append(neighbor)
	return {
		"distances": distances,
		"predecessors": predecessors,
	}


func _shortest_path(
	adjacency: Dictionary,
	start_region: String,
	destination_region: String
) -> Array:
	var search := _bfs(adjacency, start_region)
	var predecessors := search.get("predecessors", {}) as Dictionary
	if start_region == destination_region:
		return [start_region]
	if not predecessors.has(destination_region):
		return []
	var reverse_path: Array[String] = [destination_region]
	var cursor := destination_region
	while cursor != start_region:
		cursor = str(predecessors.get(cursor, ""))
		if cursor.is_empty():
			return []
		reverse_path.append(cursor)
	reverse_path.reverse()
	return reverse_path


func _farthest_region(
	distances: Dictionary,
	start_region: String
) -> String:
	var best_region := ""
	var best_distance := -1
	var region_ids := _sorted_ids(distances.keys())
	for region_id in region_ids:
		if region_id == start_region:
			continue
		var distance := int(distances.get(region_id, -1))
		if distance > best_distance:
			best_distance = distance
			best_region = region_id
	return best_region


func _nearest_same_color_target_region(
	distances: Dictionary,
	start_region: String,
	far_region: String
) -> String:
	var far_distance := int(distances.get(far_region, -1))
	var best_region := ""
	var best_distance := -1
	for region_id in _sorted_ids(distances.keys()):
		if region_id == start_region or region_id == far_region:
			continue
		var distance := int(distances.get(region_id, -1))
		if distance > 0 and distance < far_distance and distance > best_distance:
			best_distance = distance
			best_region = region_id
	return best_region


func _plan_for_source(plan: Dictionary, source_id: String) -> Dictionary:
	for row_variant in plan.get("plans", []) as Array:
		var row := row_variant as Dictionary
		if row.get("source_instance_id") == source_id:
			return row
	return {}


func _monster_from_snapshot(
	snapshot: Dictionary,
	source_id: String
) -> Dictionary:
	for row_variant in snapshot.get("monsters", []) as Array:
		var row := row_variant as Dictionary
		if row.get("source_instance_id") == source_id:
			return row
	return {}


func _balance() -> Dictionary:
	return {
		"trample_distance_step_milli_arc": 100000,
		"trample_damage_per_step_by_rank": {
			"1": 2,
			"2": 3,
			"3": 4,
			"4": 5,
		},
		"trample_damage_cap_per_region_by_rank": {
			"1": 12,
			"2": 16,
			"3": 20,
			"4": 24,
		},
	}


func _trample_distance_parity(
	movement: Dictionary,
	trample: Dictionary
) -> bool:
	var expected := {}
	for segment_variant in movement.get("region_path_segments", []) as Array:
		var segment := segment_variant as Dictionary
		var region_id := str(segment.get("region_id", ""))
		expected[region_id] = (
			int(expected.get(region_id, 0))
			+ int(segment.get("distance_milli_arc", 0))
		)
	var receipts := trample.get("region_receipts", []) as Array
	if receipts.size() != expected.size():
		return false
	for receipt_variant in receipts:
		var receipt := receipt_variant as Dictionary
		var region_id := str(receipt.get("region_id", ""))
		if int(receipt.get("distance_milli_arc", -1)) != int(
			expected.get(region_id, -2)
		):
			return false
	return true


func _contains_forbidden_private_key(value: Variant) -> bool:
	var forbidden := [
		"asset_pool",
		"private_stock",
		"warehouse_private_stock",
		"private_logistics_plan",
	]
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_private_key(item_variant):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)):
				return true
			if _contains_forbidden_private_key(
				(value as Dictionary).get(key_variant)
			):
				return true
	return false


func _sum_distance(segments: Array) -> int:
	var total := 0
	for segment_variant in segments:
		total += int((segment_variant as Dictionary).get(
			"distance_milli_arc",
			0
		))
	return total


func _contains_float(value: Variant) -> bool:
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


func _sorted_ids(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item_variant in value as Array:
		result.append(str(item_variant))
	result.sort()
	return result


func _expect(
	failures: Array[String],
	condition: bool,
	label: String
) -> void:
	if not condition:
		failures.append(label)
