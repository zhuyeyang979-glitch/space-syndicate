extends RefCounted
class_name V075MonsterAutonomyCore

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.5"
const TOPOLOGY_CONTRACT_ID := "V075MonsterPublicTopologySnapshotV1"
const WORLD_SNAPSHOT_CONTRACT_ID := "V075MonsterAutonomyFrozenSnapshotV1"
const BATCH_PLAN_CONTRACT_ID := "MonsterAutonomyPlanV1"
const MOVEMENT_RECEIPT_CONTRACT_ID := "MonsterMovementReceiptV1"
const CORE_AUTHORITY_ID := "v075.monster.autonomy.pure_core.v1"
const MILLI_ARC_PER_RADIAN := 1000000
const MAX_SAFE_INTEGER := 9007199254740991
const INDUSTRY_COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const MONSTER_STATUSES := ["active", "downed", "destroyed", "withdrawn"]
const FACILITY_STATUSES := ["active", "damaged", "destroyed"]
const MOVEMENT_PROFILES := [
	"ground_trample",
	"flying_no_trample",
	"teleport_no_trample",
]


static func topology_snapshot_from_map_receipt(map_receipt: Dictionary) -> Dictionary:
	var region_ids := _sorted_unique_ids(map_receipt.get("region_ids", []))
	if region_ids.is_empty():
		return _failure("topology_region_ids_invalid")
	var adjacency_result := _normalize_adjacency(
		region_ids,
		map_receipt.get("adjacency_graph")
	)
	if not bool(adjacency_result.get("accepted", false)):
		return adjacency_result
	var adjacency := adjacency_result.get("adjacency_graph", {}) as Dictionary
	var distance_result := _normalize_edge_distances(
		region_ids,
		adjacency,
		map_receipt
	)
	if not bool(distance_result.get("accepted", false)):
		return distance_result
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": TOPOLOGY_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"accepted": true,
		"reason_code": "public_topology_frozen",
		"map_id": str(map_receipt.get("map_id", "")),
		"map_fingerprint": str(map_receipt.get("map_fingerprint", "")),
		"region_ids": region_ids,
		"adjacency_graph": adjacency,
		"edge_distance_milli_arc": (
			distance_result.get("edge_distance_milli_arc", {}) as Dictionary
		).duplicate(true),
		"distance_source_id": str(distance_result.get("distance_source_id", "")),
		"distance_unit_id": "integer_milli_arc",
		"boundary_vertex_reader_count": 0,
		"microcell_reader_count": 0,
		"camera_reader_count": 0,
		"pixel_distance_reader_count": 0,
		"topology_fingerprint": "",
	}
	return _seal(snapshot, "topology_fingerprint")


static func freeze_public_snapshot(
	snapshot_id: String,
	batch_id: String,
	topology_snapshot: Dictionary,
	monster_sources: Array,
	public_facility_projection: Variant
) -> Dictionary:
	var topology_error := _topology_error(topology_snapshot)
	if topology_error != "":
		return _failure(topology_error)
	if not _stable_id(snapshot_id) or not _stable_id(batch_id):
		return _failure("autonomy_snapshot_identity_invalid")
	var region_ids := topology_snapshot.get("region_ids", []) as Array
	var region_set := {}
	for region_variant in region_ids:
		region_set[str(region_variant)] = true

	var monsters_by_id := {}
	for source_variant in monster_sources:
		if not (source_variant is Dictionary):
			return _failure("monster_source_not_dictionary")
		var normalized_result := _normalize_monster(
			source_variant as Dictionary,
			region_set
		)
		if not bool(normalized_result.get("accepted", false)):
			return normalized_result
		var normalized := normalized_result.get("monster", {}) as Dictionary
		var source_id := str(normalized.get("source_instance_id", ""))
		if monsters_by_id.has(source_id):
			return _failure("duplicate_monster_source_instance_id")
		monsters_by_id[source_id] = normalized
	var monster_ids: Array[String] = []
	for source_id_variant in monsters_by_id.keys():
		monster_ids.append(str(source_id_variant))
	monster_ids.sort()
	var monsters: Array = []
	for source_id in monster_ids:
		monsters.append((monsters_by_id.get(source_id) as Dictionary).duplicate(true))

	var facility_rows: Variant = _extract_facility_rows(public_facility_projection)
	if facility_rows == null:
		return _failure("public_facility_projection_invalid")
	var facilities_by_id := {}
	for facility_variant in facility_rows as Array:
		if not (facility_variant is Dictionary):
			return _failure("public_facility_not_dictionary")
		var facility_result := _normalize_facility(
			facility_variant as Dictionary,
			region_set
		)
		if not bool(facility_result.get("accepted", false)):
			return facility_result
		if bool(facility_result.get("skipped", false)):
			continue
		var facility := facility_result.get("facility", {}) as Dictionary
		var facility_id := str(facility.get("facility_id", ""))
		if facilities_by_id.has(facility_id):
			return _failure("duplicate_public_facility_id")
		facilities_by_id[facility_id] = facility
	var facility_ids: Array[String] = []
	for facility_id_variant in facilities_by_id.keys():
		facility_ids.append(str(facility_id_variant))
	facility_ids.sort()
	var facilities: Array = []
	for facility_id in facility_ids:
		facilities.append(
			(facilities_by_id.get(facility_id) as Dictionary).duplicate(true)
		)

	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": WORLD_SNAPSHOT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"accepted": true,
		"reason_code": "monster_autonomy_input_frozen",
		"snapshot_id": snapshot_id,
		"batch_id": batch_id,
		"topology": topology_snapshot.duplicate(true),
		"monsters": monsters,
		"public_facilities": facilities,
		"private_asset_reader_count": 0,
		"private_warehouse_stock_reader_count": 0,
		"future_plan_reader_count": 0,
		"snapshot_fingerprint": "",
	}
	return _seal(snapshot, "snapshot_fingerprint")


static func plan_batch(frozen_snapshot: Dictionary) -> Dictionary:
	var snapshot_error := _snapshot_error(frozen_snapshot)
	if snapshot_error != "":
		return _failure(snapshot_error)
	var plans: Array = []
	for monster_variant in frozen_snapshot.get("monsters", []) as Array:
		plans.append(_plan_monster(frozen_snapshot, monster_variant as Dictionary))
	var presentation_order: Array[String] = []
	for plan_variant in plans:
		presentation_order.append(
			str((plan_variant as Dictionary).get("source_instance_id", ""))
		)
	var result := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": BATCH_PLAN_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"authority_id": CORE_AUTHORITY_ID,
		"accepted": true,
		"reason_code": "monster_autonomy_plan_frozen",
		"snapshot_id": frozen_snapshot.get("snapshot_id"),
		"batch_id": frozen_snapshot.get("batch_id"),
		"input_snapshot_fingerprint": frozen_snapshot.get(
			"snapshot_fingerprint"
		),
		"plans": plans,
		"presentation_order_source_instance_ids": presentation_order,
		"target_order_bias_count": 0,
		"gameplay_rng_draw_count": 0,
		"camera_reader_count": 0,
		"private_asset_reader_count": 0,
		"private_warehouse_stock_reader_count": 0,
		"plan_fingerprint": "",
	}
	return _seal(result, "plan_fingerprint")


static func shortest_path(
	topology_snapshot: Dictionary,
	start_region_id: String,
	destination_region_id: String
) -> Array:
	if _topology_error(topology_snapshot) != "":
		return []
	if start_region_id == destination_region_id:
		return [start_region_id]
	var search := _bfs(
		topology_snapshot.get("adjacency_graph", {}) as Dictionary,
		start_region_id
	)
	var predecessors := search.get("predecessors", {}) as Dictionary
	if not predecessors.has(destination_region_id):
		return []
	var reverse_path: Array[String] = [destination_region_id]
	var cursor := destination_region_id
	while cursor != start_region_id:
		cursor = str(predecessors.get(cursor, ""))
		if cursor.is_empty():
			return []
		reverse_path.append(cursor)
	reverse_path.reverse()
	return reverse_path


static func path_distance_milli_arc(
	topology_snapshot: Dictionary,
	ordered_region_path: Array
) -> int:
	if _topology_error(topology_snapshot) != "":
		return -1
	if ordered_region_path.is_empty():
		return -1
	var total := 0
	for index in range(ordered_region_path.size() - 1):
		var distance := _edge_distance(
			topology_snapshot,
			str(ordered_region_path[index]),
			str(ordered_region_path[index + 1])
		)
		if distance <= 0 or total > MAX_SAFE_INTEGER - distance:
			return -1
		total += distance
	return total


static func _plan_monster(
	frozen_snapshot: Dictionary,
	monster: Dictionary
) -> Dictionary:
	var topology := frozen_snapshot.get("topology", {}) as Dictionary
	var source_id := str(monster.get("source_instance_id", ""))
	var start_region_id := str(monster.get("region_id", ""))
	var base_range := int(monster.get("base_detection_range_hops", 0))
	var current_range := int(monster.get("current_detection_range_hops", 0))
	var base_plan := {
		"source_instance_id": source_id,
		"source_generation": int(monster.get("source_generation", 0)),
		"owner_player_id": str(monster.get("owner_player_id", "")),
		"source_rank": int(monster.get("rank", 1)),
		"source_status": str(monster.get("status", "")),
		"start_region_id": start_region_id,
		"preferred_industry_color": str(
			monster.get("preferred_industry_color", "")
		),
		"detection_range_hops_used": current_range,
		"next_detection_range_hops": current_range,
		"maximum_reachable_hops": 0,
		"autonomy_state": "inactive",
		"hungry": false,
		"target_facility_id": null,
		"target_facility_generation": null,
		"target_owner_player_id": null,
		"target_region_id": null,
		"target_facility_type": null,
		"target_industry_id": null,
		"target_hop_distance": null,
		"target_path": [],
		"target_path_distance_milli_arc": 0,
		"movement_destination_region_id": start_region_id,
		"movement_receipt": {},
		"reached_target_region": false,
	}
	if str(monster.get("status", "")) != "active":
		return base_plan

	var search := _bfs(
		topology.get("adjacency_graph", {}) as Dictionary,
		start_region_id
	)
	var distances := search.get("distances", {}) as Dictionary
	var max_hops := 0
	for distance_variant in distances.values():
		max_hops = maxi(max_hops, int(distance_variant))
	current_range = mini(maxi(current_range, base_range), max_hops)
	base_range = mini(base_range, max_hops)
	base_plan["detection_range_hops_used"] = current_range
	base_plan["maximum_reachable_hops"] = max_hops

	var enemy_facilities: Array = []
	for facility_variant in frozen_snapshot.get("public_facilities", []) as Array:
		var facility := facility_variant as Dictionary
		if not _facility_is_enemy_target(monster, facility):
			continue
		var facility_region := str(facility.get("region_id", ""))
		if not distances.has(facility_region):
			continue
		enemy_facilities.append(facility)

	var preferred_candidates: Array = []
	var preferred_color := str(monster.get("preferred_industry_color", ""))
	for facility_variant in enemy_facilities:
		var facility := facility_variant as Dictionary
		var region_id := str(facility.get("region_id", ""))
		if (
			str(facility.get("industry_id", "")) == preferred_color
			and int(distances.get(region_id, MAX_SAFE_INTEGER)) <= current_range
		):
			preferred_candidates.append(facility)

	var selected := {}
	var autonomy_state := "search_expanding"
	var hungry := false
	var next_range := current_range
	if not preferred_candidates.is_empty():
		selected = _select_candidate(
			monster,
			preferred_candidates,
			distances
		)
		autonomy_state = "tracking_preferred"
		next_range = base_range
	elif current_range < max_hops:
		next_range = mini(current_range + 1, max_hops)
	else:
		selected = _select_candidate(monster, enemy_facilities, distances)
		hungry = true
		next_range = max_hops
		autonomy_state = (
			"hungry_tracking"
			if not selected.is_empty()
			else "hungry_waiting"
		)
	base_plan["next_detection_range_hops"] = next_range
	base_plan["autonomy_state"] = autonomy_state
	base_plan["hungry"] = hungry
	if selected.is_empty():
		return base_plan

	var target_region_id := str(selected.get("region_id", ""))
	var target_path := shortest_path(
		topology,
		start_region_id,
		target_region_id
	)
	if target_path.is_empty():
		base_plan["autonomy_state"] = "target_path_invalid"
		return base_plan
	var target_distance := path_distance_milli_arc(topology, target_path)
	base_plan["target_facility_id"] = selected.get("facility_id")
	base_plan["target_facility_generation"] = selected.get(
		"facility_generation"
	)
	base_plan["target_owner_player_id"] = selected.get("owner_player_id")
	base_plan["target_region_id"] = target_region_id
	base_plan["target_facility_type"] = selected.get("facility_type")
	base_plan["target_industry_id"] = selected.get("industry_id")
	base_plan["target_hop_distance"] = int(distances.get(target_region_id, 0))
	base_plan["target_path"] = target_path
	base_plan["target_path_distance_milli_arc"] = target_distance
	if target_path.size() == 1:
		base_plan["reached_target_region"] = true
		return base_plan

	var movement_path := _movement_path_within_budget(
		topology,
		target_path,
		int(monster.get("movement_budget_milli_arc", 0))
	)
	base_plan["movement_destination_region_id"] = movement_path[-1]
	base_plan["reached_target_region"] = (
		str(movement_path[-1]) == target_region_id
	)
	if movement_path.size() > 1:
		base_plan["movement_receipt"] = _build_movement_receipt(
			frozen_snapshot,
			monster,
			movement_path,
			target_region_id
		)
	return base_plan


static func _build_movement_receipt(
	frozen_snapshot: Dictionary,
	monster: Dictionary,
	movement_path: Array,
	target_region_id: String
) -> Dictionary:
	var topology := frozen_snapshot.get("topology", {}) as Dictionary
	var segments: Array = []
	var total_distance := 0
	for index in range(movement_path.size() - 1):
		var from_region := str(movement_path[index])
		var to_region := str(movement_path[index + 1])
		var edge_distance := _edge_distance(
			topology,
			from_region,
			to_region
		)
		@warning_ignore("integer_division")
		var from_distance: int = edge_distance / 2
		var to_distance := edge_distance - from_distance
		if from_distance > 0:
			segments.append({
				"region_id": from_region,
				"distance_milli_arc": from_distance,
			})
		if to_distance > 0:
			segments.append({
				"region_id": to_region,
				"distance_milli_arc": to_distance,
			})
		total_distance += edge_distance
	var identity := {
		"snapshot_id": frozen_snapshot.get("snapshot_id"),
		"batch_id": frozen_snapshot.get("batch_id"),
		"source_instance_id": monster.get("source_instance_id"),
		"source_generation": monster.get("source_generation"),
		"ordered_region_path": movement_path,
		"distance_milli_arc": total_distance,
	}
	var movement_id := "movement.%s" % _fingerprint(identity).substr(0, 24)
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": MOVEMENT_RECEIPT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"movement_id": movement_id,
		"snapshot_id": frozen_snapshot.get("snapshot_id"),
		"batch_id": frozen_snapshot.get("batch_id"),
		"source_instance_id": monster.get("source_instance_id"),
		"source_generation": monster.get("source_generation"),
		"source_rank": monster.get("rank"),
		"owner_player_id": monster.get("owner_player_id"),
		"movement_profile": monster.get("movement_profile"),
		"forced_movement": false,
		"forced_movement_trample": false,
		"start_region_id": movement_path[0],
		"destination_region_id": movement_path[-1],
		"target_region_id": target_region_id,
		"ordered_region_path": movement_path.duplicate(),
		"region_path_segments": segments,
		"movement_budget_milli_arc": monster.get(
			"movement_budget_milli_arc"
		),
		"distance_milli_arc": total_distance,
		"authoritative_position_mode": "region_id_atomic",
		"movement_receipt_fingerprint": "",
	}
	return _seal(receipt, "movement_receipt_fingerprint")


static func _movement_path_within_budget(
	topology: Dictionary,
	target_path: Array,
	movement_budget_milli_arc: int
) -> Array:
	var result: Array = [target_path[0]]
	var spent := 0
	for index in range(target_path.size() - 1):
		var distance := _edge_distance(
			topology,
			str(target_path[index]),
			str(target_path[index + 1])
		)
		if distance <= 0 or spent > movement_budget_milli_arc - distance:
			break
		spent += distance
		result.append(target_path[index + 1])
	return result


static func _select_candidate(
	monster: Dictionary,
	candidates: Array,
	distances: Dictionary
) -> Dictionary:
	var best := {}
	for candidate_variant in candidates:
		var candidate := candidate_variant as Dictionary
		if best.is_empty() or _candidate_is_better(
			monster,
			candidate,
			best,
			distances
		):
			best = candidate
	return best.duplicate(true)


static func _candidate_is_better(
	monster: Dictionary,
	left: Dictionary,
	right: Dictionary,
	distances: Dictionary
) -> bool:
	var left_distance := int(distances.get(
		str(left.get("region_id", "")),
		MAX_SAFE_INTEGER
	))
	var right_distance := int(distances.get(
		str(right.get("region_id", "")),
		MAX_SAFE_INTEGER
	))
	if left_distance != right_distance:
		return left_distance < right_distance
	var preference := monster.get("facility_type_preference", []) as Array
	var left_type_index := preference.find(str(left.get("facility_type", "")))
	var right_type_index := preference.find(str(right.get("facility_type", "")))
	if left_type_index != right_type_index:
		return left_type_index < right_type_index
	var left_authored := int(left.get("authored_target_priority", 0))
	var right_authored := int(right.get("authored_target_priority", 0))
	if left_authored != right_authored:
		return left_authored > right_authored
	var left_damage := int(left.get("damage_points", 0))
	var right_damage := int(right.get("damage_points", 0))
	if left_damage != right_damage:
		return left_damage > right_damage
	var left_revision := int(left.get("damage_revision", 0))
	var right_revision := int(right.get("damage_revision", 0))
	if left_revision != right_revision:
		return left_revision > right_revision
	return str(left.get("facility_id", "")) < str(
		right.get("facility_id", "")
	)


static func _facility_is_enemy_target(
	monster: Dictionary,
	facility: Dictionary
) -> bool:
	return (
		str(facility.get("status", "")) != "destroyed"
		and str(facility.get("owner_player_id", ""))
			!= str(monster.get("owner_player_id", ""))
		and FACILITY_TYPES.has(str(facility.get("facility_type", "")))
		and INDUSTRY_COLORS.has(str(facility.get("industry_id", "")))
	)


static func _bfs(adjacency: Dictionary, start_region_id: String) -> Dictionary:
	if not adjacency.has(start_region_id):
		return {"distances": {}, "predecessors": {}}
	var distances := {start_region_id: 0}
	var predecessors := {}
	var queue: Array[String] = [start_region_id]
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for neighbor_variant in adjacency.get(current, []) as Array:
			var neighbor := str(neighbor_variant)
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances.get(current, 0)) + 1
			predecessors[neighbor] = current
			queue.append(neighbor)
	return {
		"distances": distances,
		"predecessors": predecessors,
	}


static func _normalize_monster(
	source: Dictionary,
	region_set: Dictionary
) -> Dictionary:
	var source_id := str(source.get("source_instance_id", ""))
	var owner_id := _first_stable_id(
		source,
		["owner_player_id", "owner_id"]
	)
	var region_id := str(source.get("region_id", ""))
	var status := str(source.get("status", "active"))
	var preferred_color := str(source.get("preferred_industry_color", ""))
	var rank_value: Variant = source.get("rank", 1)
	var generation: Variant = source.get("source_generation", 0)
	var base_range: Variant = source.get("base_detection_range_hops", 0)
	var current_range: Variant = source.get(
		"current_detection_range_hops",
		base_range
	)
	var movement_budget: Variant = source.get(
		"movement_budget_milli_arc",
		0
	)
	var movement_profile := str(source.get(
		"movement_profile",
		"ground_trample"
	))
	if (
		not _stable_id(source_id)
		or not _stable_id(owner_id)
		or not region_set.has(region_id)
		or not _nonnegative_integer(generation)
		or not _positive_integer(rank_value)
		or int(rank_value) > 4
		or not MONSTER_STATUSES.has(status)
		or not INDUSTRY_COLORS.has(preferred_color)
		or not _nonnegative_integer(base_range)
		or not _nonnegative_integer(current_range)
		or int(current_range) < int(base_range)
		or not _nonnegative_integer(movement_budget)
		or not MOVEMENT_PROFILES.has(movement_profile)
	):
		return _failure("monster_autonomy_source_invalid")
	var preference := _normalize_facility_preference(
		source.get("facility_type_preference", FACILITY_TYPES)
	)
	if preference.is_empty():
		return _failure("monster_facility_type_preference_invalid")
	return {
		"accepted": true,
		"reason_code": "monster_autonomy_source_normalized",
		"monster": {
			"source_instance_id": source_id,
			"source_generation": int(generation),
			"owner_player_id": owner_id,
			"region_id": region_id,
			"rank": int(rank_value),
			"status": status,
			"preferred_industry_color": preferred_color,
			"facility_type_preference": preference,
			"base_detection_range_hops": int(base_range),
			"current_detection_range_hops": int(current_range),
			"movement_profile": movement_profile,
			"movement_budget_milli_arc": int(movement_budget),
		},
	}


static func _normalize_facility(
	source: Dictionary,
	region_set: Dictionary
) -> Dictionary:
	var occupancy := str(source.get("occupancy", "occupied"))
	if occupancy == "empty":
		return {
			"accepted": true,
			"reason_code": "empty_public_slot_skipped",
			"skipped": true,
		}
	var facility_id := str(source.get("facility_id", ""))
	var owner_id := _first_stable_id(
		source,
		["owner_player_id", "owner_id", "owner_public_id"]
	)
	var region_id := str(source.get("region_id", ""))
	var facility_type := str(source.get("facility_type", ""))
	var industry_id := str(source.get("industry_id", ""))
	var generation: Variant = source.get(
		"facility_generation",
		source.get("generation", 0)
	)
	var damage_revision: Variant = source.get("damage_revision", 0)
	var damage_points: Variant = source.get("damage_points", 0)
	var authored_priority: Variant = source.get(
		"authored_target_priority",
		0
	)
	var status := str(source.get("status", "active"))
	if bool(source.get("destroyed", false)):
		status = "destroyed"
	elif (
		status == "active"
		and _nonnegative_integer(damage_points)
		and int(damage_points) > 0
	):
		status = "damaged"
	if (
		not _stable_id(facility_id)
		or not _stable_id(owner_id)
		or not region_set.has(region_id)
		or not FACILITY_TYPES.has(facility_type)
		or not INDUSTRY_COLORS.has(industry_id)
		or not _nonnegative_integer(generation)
		or not _nonnegative_integer(damage_revision)
		or not _nonnegative_integer(damage_points)
		or not _safe_integer(authored_priority)
		or not FACILITY_STATUSES.has(status)
	):
		return _failure("public_facility_target_invalid")
	return {
		"accepted": true,
		"reason_code": "public_facility_target_normalized",
		"skipped": false,
		"facility": {
			"facility_id": facility_id,
			"facility_generation": int(generation),
			"owner_player_id": owner_id,
			"region_id": region_id,
			"facility_type": facility_type,
			"industry_id": industry_id,
			"status": status,
			"damage_revision": int(damage_revision),
			"damage_points": int(damage_points),
			"authored_target_priority": int(authored_priority),
		},
	}


static func _extract_facility_rows(value: Variant) -> Variant:
	if value is Array:
		return (value as Array).duplicate(true)
	if not (value is Dictionary):
		return null
	var source := value as Dictionary
	for field_name in [
		"public_facility_slots",
		"public_facilities",
		"facilities",
		"slots",
	]:
		if source.get(field_name) is Array:
			return (source.get(field_name) as Array).duplicate(true)
	return null


static func _normalize_facility_preference(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result: Array[String] = []
	for item_variant in value as Array:
		var item := str(item_variant)
		if not FACILITY_TYPES.has(item) or result.has(item):
			return []
		result.append(item)
	for facility_type in FACILITY_TYPES:
		if not result.has(facility_type):
			result.append(facility_type)
	return result


static func _normalize_adjacency(
	region_ids: Array,
	adjacency_variant: Variant
) -> Dictionary:
	if not (adjacency_variant is Dictionary):
		return _failure("topology_adjacency_not_dictionary")
	var source := adjacency_variant as Dictionary
	var region_set := {}
	for region_variant in region_ids:
		region_set[str(region_variant)] = true
	var adjacency := {}
	for region_variant in region_ids:
		var region_id := str(region_variant)
		if not (source.get(region_id) is Array):
			return _failure("topology_adjacency_row_invalid")
		var neighbors := _sorted_unique_ids(source.get(region_id))
		if neighbors.is_empty() and region_ids.size() > 1:
			return _failure("topology_region_isolated")
		for neighbor_variant in neighbors:
			var neighbor := str(neighbor_variant)
			if neighbor == region_id or not region_set.has(neighbor):
				return _failure("topology_adjacency_reference_invalid")
		adjacency[region_id] = neighbors
	for region_variant in region_ids:
		var region_id := str(region_variant)
		for neighbor_variant in adjacency.get(region_id, []) as Array:
			var neighbor := str(neighbor_variant)
			if not (adjacency.get(neighbor, []) as Array).has(region_id):
				return _failure("topology_adjacency_asymmetric")
	var visited := _bfs(adjacency, str(region_ids[0])).get(
		"distances",
		{}
	) as Dictionary
	if visited.size() != region_ids.size():
		return _failure("topology_adjacency_disconnected")
	return {
		"accepted": true,
		"reason_code": "topology_adjacency_normalized",
		"adjacency_graph": adjacency,
	}


static func _normalize_edge_distances(
	region_ids: Array,
	adjacency: Dictionary,
	map_receipt: Dictionary
) -> Dictionary:
	var explicit_variant: Variant = map_receipt.get(
		"edge_distance_milli_arc",
		{}
	)
	if explicit_variant is Dictionary and not (
		explicit_variant as Dictionary
	).is_empty():
		var explicit := explicit_variant as Dictionary
		var normalized := {}
		for region_variant in region_ids:
			var region_id := str(region_variant)
			if not (explicit.get(region_id) is Dictionary):
				return _failure("topology_edge_distance_row_invalid")
			var source_row := explicit.get(region_id) as Dictionary
			var row := {}
			for neighbor_variant in adjacency.get(region_id, []) as Array:
				var neighbor := str(neighbor_variant)
				var distance: Variant = source_row.get(neighbor)
				if not _positive_integer(distance):
					return _failure("topology_edge_distance_invalid")
				row[neighbor] = int(distance)
			normalized[region_id] = row
		for region_variant in region_ids:
			var region_id := str(region_variant)
			for neighbor_variant in adjacency.get(region_id, []) as Array:
				var neighbor := str(neighbor_variant)
				if int((normalized.get(region_id) as Dictionary).get(neighbor, 0)) != int(
					(normalized.get(neighbor) as Dictionary).get(region_id, -1)
				):
					return _failure("topology_edge_distance_asymmetric")
		return {
			"accepted": true,
			"reason_code": "topology_edge_distances_normalized",
			"edge_distance_milli_arc": normalized,
			"distance_source_id": "authoritative_edge_distance_milli_arc",
		}

	var centers_variant: Variant = map_receipt.get(
		"region_centers_unit_sphere",
		{}
	)
	if not (centers_variant is Dictionary):
		return _failure("topology_distance_source_missing")
	var centers := centers_variant as Dictionary
	var derived := {}
	for region_variant in region_ids:
		derived[str(region_variant)] = {}
	for region_variant in region_ids:
		var region_id := str(region_variant)
		var center_variant: Variant = centers.get(region_id)
		if not (center_variant is Vector3):
			return _failure("topology_region_center_invalid")
		var center := (center_variant as Vector3).normalized()
		if center.is_zero_approx():
			return _failure("topology_region_center_invalid")
		for neighbor_variant in adjacency.get(region_id, []) as Array:
			var neighbor := str(neighbor_variant)
			if region_id > neighbor:
				continue
			var neighbor_variant_center: Variant = centers.get(neighbor)
			if not (neighbor_variant_center is Vector3):
				return _failure("topology_region_center_invalid")
			var neighbor_center := (
				neighbor_variant_center as Vector3
			).normalized()
			if neighbor_center.is_zero_approx():
				return _failure("topology_region_center_invalid")
			var radians := atan2(
				center.cross(neighbor_center).length(),
				clampf(center.dot(neighbor_center), -1.0, 1.0)
			)
			var distance := maxi(
				1,
				roundi(radians * float(MILLI_ARC_PER_RADIAN))
			)
			(derived.get(region_id) as Dictionary)[neighbor] = distance
			(derived.get(neighbor) as Dictionary)[region_id] = distance
	return {
		"accepted": true,
		"reason_code": "topology_edge_distances_derived",
		"edge_distance_milli_arc": derived,
		"distance_source_id": "quantized_region_center_geodesic",
	}


static func _edge_distance(
	topology: Dictionary,
	from_region_id: String,
	to_region_id: String
) -> int:
	var rows := topology.get("edge_distance_milli_arc", {}) as Dictionary
	if not (rows.get(from_region_id) is Dictionary):
		return -1
	return int((rows.get(from_region_id) as Dictionary).get(
		to_region_id,
		-1
	))


static func _topology_error(topology: Dictionary) -> String:
	if (
		topology.get("contract_id") != TOPOLOGY_CONTRACT_ID
		or topology.get("ruleset_id") != RULESET_ID
		or topology.get("accepted") != true
		or not _fingerprint_matches(topology, "topology_fingerprint")
	):
		return "public_topology_snapshot_invalid"
	var region_ids := _sorted_unique_ids(topology.get("region_ids", []))
	if region_ids.is_empty():
		return "public_topology_regions_invalid"
	var adjacency_result := _normalize_adjacency(
		region_ids,
		topology.get("adjacency_graph")
	)
	if not bool(adjacency_result.get("accepted", false)):
		return str(adjacency_result.get("reason_code", "public_topology_invalid"))
	var distance_result := _normalize_edge_distances(
		region_ids,
		adjacency_result.get("adjacency_graph", {}) as Dictionary,
		{
			"edge_distance_milli_arc": topology.get(
				"edge_distance_milli_arc",
				{}
			),
		}
	)
	if not bool(distance_result.get("accepted", false)):
		return str(distance_result.get("reason_code", "public_topology_invalid"))
	return ""


static func _snapshot_error(snapshot: Dictionary) -> String:
	if (
		snapshot.get("contract_id") != WORLD_SNAPSHOT_CONTRACT_ID
		or snapshot.get("ruleset_id") != RULESET_ID
		or snapshot.get("accepted") != true
		or not _fingerprint_matches(snapshot, "snapshot_fingerprint")
		or _topology_error(snapshot.get("topology", {}) as Dictionary) != ""
		or not (snapshot.get("monsters") is Array)
		or not (snapshot.get("public_facilities") is Array)
		or not _is_pure_data(snapshot)
	):
		return "monster_autonomy_frozen_snapshot_invalid"
	return ""


static func _first_stable_id(
	source: Dictionary,
	fields: Array
) -> String:
	for field_variant in fields:
		var value: Variant = source.get(str(field_variant))
		if _stable_id(value):
			return str(value)
	return ""


static func _sorted_unique_ids(value: Variant) -> Array:
	if not (value is Array):
		return []
	var result: Array[String] = []
	for item_variant in value as Array:
		if not _stable_id(item_variant):
			return []
		var item := str(item_variant)
		if result.has(item):
			return []
		result.append(item)
	result.sort()
	return result


static func _failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
	}


static func _seal(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if not _is_pure_data(unsealed) or unsealed.has(fingerprint_field) and not str(
		unsealed.get(fingerprint_field, "")
	).is_empty():
		return {}
	var sealed := unsealed.duplicate(true)
	sealed.erase(fingerprint_field)
	sealed[fingerprint_field] = _fingerprint(sealed)
	return sealed


static func _fingerprint_matches(
	value: Dictionary,
	fingerprint_field: String
) -> bool:
	var expected := str(value.get(fingerprint_field, ""))
	if expected.length() != 64:
		return false
	var unsealed := value.duplicate(true)
	unsealed.erase(fingerprint_field)
	return expected == _fingerprint(unsealed)


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if value == null or value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item_variant in value as Array:
			parts.append(_canonical_json(item_variant))
		return "[" + ",".join(parts) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(
			JSON.stringify(key) + ":" + _canonical_json(source.get(key))
		)
	return "{" + ",".join(members) + "}"


static func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is String or value is bool:
		return true
	if value is int:
		return _safe_integer(value)
	if value is Array:
		for item_variant in value as Array:
			if not _is_pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if (
				not (key_variant is String)
				or not _is_pure_data(
					(value as Dictionary).get(key_variant),
					depth + 1
				)
			):
				return false
		return true
	return false


static func _safe_integer(value: Variant) -> bool:
	return (
		value is int
		and int(value) >= -MAX_SAFE_INTEGER
		and int(value) <= MAX_SAFE_INTEGER
	)


static func _nonnegative_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) >= 0


static func _positive_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) > 0


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160:
		return false
	var previous_separator := false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code == 46 or code == 95 or code == 45
		if index == 0 and not lower:
			return false
		if not lower and not digit and not separator:
			return false
		if separator and previous_separator:
			return false
		previous_separator = separator
	return not previous_separator
