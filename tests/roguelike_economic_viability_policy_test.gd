extends SceneTree

const Policy := preload("res://scripts/runtime/roguelike_economic_viability_policy.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const QA_SAVE_PATH := "user://space_syndicate_design_qa/test_runs/roguelike_remote_trade_opportunity.save"

const CATALOG := ["land.alpha", "land.beta", "land.gamma", "ocean.alpha", "ocean.beta"]
const POOLS := {
	"land": ["land.alpha", "land.beta", "land.gamma"],
	"ocean": ["ocean.alpha", "ocean.beta"],
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_existing_non_direct_match_is_noop()
	_check_low_coverage_is_viable()
	_check_single_remote_repair()
	_check_two_region_repair()
	_check_no_legal_target_fails_closed()
	_check_invalid_inputs_fail_closed()
	_check_seeded_shapes()
	await _check_real_depth_one_seed_60610()
	_finish()


func _check_existing_non_direct_match_is_noop() -> void:
	var districts := [
		_district(0, "land", "land.alpha", "ocean.alpha", [1]),
		_district(1, "land", "land.beta", "ocean.beta", [0, 2]),
		_district(2, "ocean", "ocean.alpha", "land.alpha", [1]),
	]
	var request := _request(districts)
	var request_before := JSON.stringify(request)
	var result: Dictionary = Policy.normalize(request)
	var audit: Dictionary = result.get("audit", {}) as Dictionary
	_expect(bool(result.get("ok", false)), "non-direct remote opportunity is accepted")
	_expect(str(result.get("reason_code", "")) == "global_remote_trade_opportunity_already_satisfied", "existing opportunity returns the no-op reason")
	_expect(int(audit.get("global_remote_match_count", 0)) >= 1 and int(audit.get("direct_remote_match_count", -1)) == 0, "adjacency is informational and a non-direct match is viable")
	_expect(not bool(audit.get("changed", true)) and int(audit.get("mutation_count", -1)) == 0, "existing opportunity performs zero mutation")
	_expect(JSON.stringify(result.get("districts", [])) == JSON.stringify(districts), "no-op preserves every generated fact")
	_expect(JSON.stringify(request) == request_before, "normalization never mutates its request")
	_assert_relaxed_result("existing_non_direct", districts, result)


func _check_low_coverage_is_viable() -> void:
	var districts := [
		_district(0, "land", "land.alpha", "ocean.alpha", [1]),
		_district(1, "land", "land.beta", "land.alpha", [0, 2]),
		_district(2, "land", "land.gamma", "ocean.beta", [1]),
	]
	var result: Dictionary = Policy.normalize(_request(districts))
	var audit: Dictionary = result.get("audit", {}) as Dictionary
	_expect(bool(result.get("ok", false)) and bool(audit.get("viable", false)), "one planet-wide opportunity is sufficient")
	_expect(int(audit.get("source_with_remote_count", -1)) == 1 and int(audit.get("isolated_source_count", -1)) == 2, "audit reports isolated sources without rejecting the map")
	_expect(float(audit.get("coverage_ratio", 0.0)) > 0.0 and float(audit.get("coverage_ratio", 1.0)) < 1.0, "coverage ratio is informational rather than a 100 percent gate")
	_expect(int(audit.get("direct_remote_match_count", 0)) == 1, "direct matches remain observable without becoming mandatory")
	_expect(not bool(audit.get("changed", true)), "low-coverage viable map is not rewritten")


func _check_single_remote_repair() -> void:
	# Source 0 cannot use district 1 because both produce land.alpha. District 2
	# is not its neighbor, proving the repair does not depend on adjacency.
	var districts := [
		_district(0, "land", "land.alpha", "ocean.alpha", [1]),
		_district(1, "land", "land.alpha", "ocean.beta", [0]),
		_district(2, "land", "land.beta", "ocean.alpha", []),
	]
	var result: Dictionary = Policy.normalize(_request(districts))
	var audit: Dictionary = result.get("audit", {}) as Dictionary
	var output: Array = result.get("districts", []) as Array
	_expect(bool(result.get("ok", false)) and str(result.get("reason_code", "")) == "global_remote_trade_opportunity_repaired", "zero-intersection map repairs with a structured result")
	_expect(bool(audit.get("changed", false)) and int(audit.get("mutation_count", -1)) == 1, "repair changes exactly one demand slot")
	_expect(JSON.stringify(audit.get("changed_destination_indices", [])) == "[2]", "stable source/destination order chooses the first legal remote destination")
	_expect(_demand_id(output[2] as Dictionary) == "land.alpha" and _product_id(output[2] as Dictionary) != "land.alpha", "repair creates a non-self exact-product opportunity")
	_expect(int(audit.get("global_remote_match_count", 0)) >= 1 and int(audit.get("direct_remote_match_count", -1)) == 0, "repaired remote opportunity is viable even without a direct edge")
	_assert_relaxed_result("single_remote_repair", districts, result)


func _check_two_region_repair() -> void:
	var districts := [
		_district(0, "ocean", "ocean.alpha", "land.gamma", [1]),
		_district(1, "land", "land.alpha", "ocean.beta", [0]),
	]
	var result: Dictionary = Policy.normalize(_request(districts))
	var output: Array = result.get("districts", []) as Array
	_expect(bool(result.get("ok", false)) and int((result.get("audit", {}) as Dictionary).get("mutation_count", -1)) == 1, "two-region map needs at most one repair")
	_expect(_demand_id(output[1] as Dictionary) == "ocean.alpha", "two-region repair uses the other region's existing production")
	_assert_relaxed_result("two_region", districts, result)


func _check_no_legal_target_fails_closed() -> void:
	var districts := [
		_district(0, "land", "land.alpha", "ocean.alpha", [1, 2]),
		_district(1, "land", "land.alpha", "ocean.beta", [0, 2]),
		_district(2, "land", "land.alpha", "land.beta", [0, 1]),
	]
	var before := JSON.stringify(districts)
	var result: Dictionary = Policy.normalize(_request(districts))
	var audit: Dictionary = result.get("audit", {}) as Dictionary
	_expect(not bool(result.get("ok", true)), "same-production planet fails closed because every target would self-demand")
	_expect(str(result.get("reason_code", "")) == "global_remote_trade_destination_unavailable", "unrepairable map returns a structured reason")
	_expect(not bool(audit.get("changed", true)) and int(audit.get("mutation_count", -1)) == 0 and (audit.get("changed_destination_indices", []) as Array).is_empty(), "failed repair exposes no partial patch")
	_expect(JSON.stringify(result.get("districts", [])) == before, "failed repair preserves all input districts")


func _check_invalid_inputs_fail_closed() -> void:
	var self_demand := [
		_district(0, "land", "land.alpha", "land.alpha", [1]),
		_district(1, "land", "land.beta", "ocean.alpha", [0]),
	]
	var self_result: Dictionary = Policy.normalize(_request(self_demand))
	_expect(not bool(self_result.get("ok", true)) and str(self_result.get("reason_code", "")) == "district_self_demand", "self-demand input is rejected")

	var outside_catalog := [
		_district(0, "land", "catalog.fake", "ocean.alpha", [1]),
		_district(1, "land", "land.beta", "ocean.beta", [0]),
	]
	var outside_result: Dictionary = Policy.normalize(_request(outside_catalog))
	_expect(not bool(outside_result.get("ok", true)) and str(outside_result.get("reason_code", "")) == "district_product_outside_catalog", "catalog-external production is rejected")

	var duplicate_neighbor := [
		_district(0, "land", "land.alpha", "ocean.alpha", [1, 1]),
		_district(1, "land", "land.beta", "ocean.beta", [0]),
	]
	var neighbor_result: Dictionary = Policy.normalize(_request(duplicate_neighbor))
	_expect(not bool(neighbor_result.get("ok", true)) and str(neighbor_result.get("reason_code", "")) == "neighbor_index_invalid", "invalid topology is rejected without repair")


func _check_seeded_shapes() -> void:
	for seed_value in range(64):
		var districts := _seed_shape(seed_value)
		var request := _request(districts)
		var request_before := JSON.stringify(request)
		var first: Dictionary = Policy.normalize(request)
		var second: Dictionary = Policy.normalize(request)
		_expect(JSON.stringify(first) == JSON.stringify(second), "seed shape %d is deterministic" % seed_value)
		_expect(JSON.stringify(request) == request_before, "seed shape %d input remains immutable" % seed_value)
		_assert_relaxed_result("seed_%d" % seed_value, districts, first)


func _assert_relaxed_result(label: String, input_districts: Array, result: Dictionary) -> void:
	var audit: Dictionary = result.get("audit", {}) if result.get("audit", {}) is Dictionary else {}
	var output: Array = result.get("districts", []) if result.get("districts", []) is Array else []
	_expect(bool(result.get("ok", false)) and bool(audit.get("viable", false)), "%s has a planet-wide remote opportunity" % label)
	_expect(int(audit.get("global_remote_match_count", 0)) > 0, "%s audit proves a cross-district exact match" % label)
	_expect(int(audit.get("source_with_remote_count", -1)) + int(audit.get("isolated_source_count", -1)) == input_districts.size(), "%s audit partitions covered and isolated sources" % label)
	var expected_ratio := float(audit.get("source_with_remote_count", 0)) / float(maxi(1, input_districts.size()))
	_expect(is_equal_approx(float(audit.get("coverage_ratio", -1.0)), expected_ratio), "%s coverage ratio is source-based informational evidence" % label)
	_expect(int(audit.get("mutation_count", -1)) <= 1, "%s changes at most one demand slot" % label)
	_expect(output.size() == input_districts.size(), "%s preserves district count" % label)
	if output.size() != input_districts.size():
		return
	var changed_demands: Array = []
	var shape_valid := true
	var production_set: Dictionary = {}
	for district_variant: Variant in input_districts:
		production_set[_product_id(district_variant as Dictionary)] = true
	for district_index in range(output.size()):
		var before := input_districts[district_index] as Dictionary
		var after := output[district_index] as Dictionary
		var products: Array = after.get("products", []) if after.get("products", []) is Array else []
		var demands: Array = after.get("demands", []) if after.get("demands", []) is Array else []
		shape_valid = shape_valid \
			and str(after.get("region_id", "")) == str(before.get("region_id", "")) \
			and str(after.get("terrain", "")) == str(before.get("terrain", "")) \
			and JSON.stringify(after.get("neighbors", [])) == JSON.stringify(before.get("neighbors", [])) \
			and JSON.stringify(products) == JSON.stringify(before.get("products", [])) \
			and products.size() == 1 and demands.size() == 1
		if products.size() == 1 and demands.size() == 1:
			shape_valid = shape_valid and CATALOG.has(str(products[0])) and CATALOG.has(str(demands[0])) \
				and (POOLS.get(str(after.get("terrain", "")), []) as Array).has(str(products[0])) \
				and str(products[0]) != str(demands[0])
		if JSON.stringify(after.get("demands", [])) != JSON.stringify(before.get("demands", [])):
			changed_demands.append(district_index)
			shape_valid = shape_valid and production_set.has(_demand_id(after))
	_expect(shape_valid, "%s preserves topology, production, terrain pools, catalog, slot counts, and no-self-demand" % label)
	_expect(JSON.stringify(changed_demands) == JSON.stringify(audit.get("changed_destination_indices", [])), "%s reports the exact changed demand set" % label)
	_expect(changed_demands.size() == int(audit.get("mutation_count", -1)) and bool(audit.get("changed", false)) == (not changed_demands.is_empty()), "%s mutation metadata matches the output" % label)
	_expect(_audit_counts_match(output, audit), "%s audit counts and assignment proofs match the output" % label)
	_expect(_is_pure_data(result), "%s output remains pure data" % label)


func _audit_counts_match(districts: Array, audit: Dictionary) -> bool:
	var global_count := 0
	var direct_count := 0
	var covered_sources := 0
	for source_index in range(districts.size()):
		var source := districts[source_index] as Dictionary
		var matched := false
		for destination_index in range(districts.size()):
			if source_index == destination_index:
				continue
			var destination := districts[destination_index] as Dictionary
			if _demand_id(destination) == _product_id(source) and _product_id(destination) != _product_id(source):
				global_count += 1
				matched = true
				if (source.get("neighbors", []) as Array).has(destination_index):
					direct_count += 1
		if matched:
			covered_sources += 1
	return global_count == int(audit.get("global_remote_match_count", -1)) \
		and direct_count == int(audit.get("direct_remote_match_count", -1)) \
		and covered_sources == int(audit.get("source_with_remote_count", -1)) \
		and (audit.get("assignments", []) as Array).size() == covered_sources


func _seed_shape(seed_value: int) -> Array:
	var district_count := 2 + (seed_value % 8)
	var result: Array = []
	for district_index in range(district_count):
		var product := str(CATALOG[(seed_value + district_index) % CATALOG.size()])
		var terrain := "ocean" if product.begins_with("ocean.") else "land"
		var demand := str(CATALOG[(seed_value * 3 + district_index * 2 + 1) % CATALOG.size()])
		if demand == product:
			demand = str(CATALOG[(CATALOG.find(demand) + 1) % CATALOG.size()])
		var neighbors: Array = []
		if district_count > 1:
			neighbors.append((district_index + 1) % district_count)
			if district_count > 3 and seed_value % 2 == 0:
				neighbors.append((district_index + 2) % district_count)
		result.append(_district(district_index, terrain, product, demand, neighbors))
	return result


func _district(index: int, terrain: String, product: String, demand: String, neighbors: Array) -> Dictionary:
	return {
		"region_id": "region.%03d" % index,
		"terrain": terrain,
		"neighbors": neighbors.duplicate(),
		"products": [product],
		"demands": [demand],
	}


func _request(districts: Array) -> Dictionary:
	return {
		"districts": districts.duplicate(true),
		"catalog_products": CATALOG.duplicate(),
		"terrain_product_pools": POOLS.duplicate(true),
	}


func _product_id(district: Dictionary) -> String:
	var products: Array = district.get("products", []) as Array
	return str(products[0]) if products.size() == 1 else ""


func _demand_id(district: Dictionary) -> String:
	var demands: Array = district.get("demands", []) as Array
	return str(demands[0]) if demands.size() == 1 else ""


func _check_real_depth_one_seed_60610() -> void:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "real main scene loads")
	if packed == null:
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "real main exposes a pre-tree QA save override")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		main.free()
		return
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "real-main fixture is isolated from the default save")
	root.size = Vector2i(1600, 960)
	root.add_child(main)
	await _wait_frames(8)
	main.set("configured_player_count", 3)
	main.set("configured_ai_player_count", 2)
	main.set("configured_roguelike_depth", 1)
	main.set("configured_role_indices", [0, 1, 2])
	main.set("configured_starter_monster_indices", [0, 1, 2])
	var rng_variant: Variant = main.get("rng")
	if rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).seed = 60610
	main.call("_open_new_game_setup_menu")
	await _wait_frames(2)
	main.call("_on_new_game_setup_action_requested", "setup_start")
	main.set("time_scale", 0.0)
	await _wait_frames(8)

	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	var dev_variant: Variant = main.call("_roguelike_economic_viability_dev_snapshot")
	var dev: Dictionary = dev_variant if dev_variant is Dictionary else {}
	_expect(not districts.is_empty() and bool(dev.get("ok", false)) and bool(dev.get("viable", false)), "depth-I seed 60610 has a planet-wide exact-product opportunity")
	_expect(int(dev.get("global_remote_match_count", 0)) > 0 and int(dev.get("source_with_remote_count", 0)) > 0, "depth-I dev audit proves at least one remote source")
	_expect(int(dev.get("mutation_count", -1)) <= 1 and (dev.get("changed_destination_indices", []) as Array).size() <= 1, "depth-I seed 60610 is not rewritten across the whole map")
	_expect(float(dev.get("coverage_ratio", 0.0)) > 0.0 and float(dev.get("coverage_ratio", 0.0)) <= 1.0, "depth-I coverage remains informational")

	var map_shape_valid := not districts.is_empty()
	for district_variant: Variant in districts:
		if not (district_variant is Dictionary):
			map_shape_valid = false
			continue
		var district := district_variant as Dictionary
		var products: Array = district.get("products", []) if district.get("products", []) is Array else []
		var demands: Array = district.get("demands", []) if district.get("demands", []) is Array else []
		var terrain_pool_variant: Variant = main.call("_product_pool_for_terrain", str(district.get("terrain", "")))
		var terrain_pool: Array = terrain_pool_variant if terrain_pool_variant is Array else []
		map_shape_valid = map_shape_valid and products.size() == 1 and demands.size() == 1
		if products.size() == 1 and demands.size() == 1:
			map_shape_valid = map_shape_valid and products[0] != demands[0] and terrain_pool.has(products[0])
	_expect(map_shape_valid, "depth-I map preserves slots, no-self-demand, and terrain production pools")

	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var bridge: Object = coordinator.call("region_infrastructure_world_bridge") if coordinator != null and coordinator.has_method("region_infrastructure_world_bridge") else null
	_expect(bridge != null and bridge.has_method("public_commodity_region_facts"), "real RegionInfrastructure bridge exposes authoritative commodity facts")
	var authoritative_facts: Array = bridge.call("public_commodity_region_facts") as Array if bridge != null else []
	_expect(authoritative_facts.size() == districts.size(), "authoritative bridge covers every generated region")
	_expect(_bridge_facts_match_districts(authoritative_facts, districts), "authoritative production and demand facts equal the final map")
	_expect(str(save.call("default_save_path")) == QA_SAVE_PATH, "runtime save default remains the isolated QA path")

	_stop_audio(main)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(2)


func _bridge_facts_match_districts(facts: Array, districts: Array) -> bool:
	var by_region_id: Dictionary = {}
	for fact_variant: Variant in facts:
		if fact_variant is Dictionary:
			by_region_id[str((fact_variant as Dictionary).get("region_id", ""))] = fact_variant
	for district_variant: Variant in districts:
		if not (district_variant is Dictionary):
			return false
		var district := district_variant as Dictionary
		var region_id := str(district.get("region_id", ""))
		if not by_region_id.has(region_id):
			return false
		var fact := by_region_id.get(region_id, {}) as Dictionary
		if not bool(fact.get("available", false)) or not bool(fact.get("authoritative", false)):
			return false
		if _row_product_ids(fact.get("production_products", [])) != _string_array(district.get("products", [])):
			return false
		if _row_product_ids(fact.get("demand_products", [])) != _string_array(district.get("demands", [])):
			return false
	return true


func _row_product_ids(rows_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if rows_variant is Array:
		for row_variant: Variant in rows_variant as Array:
			if row_variant is Dictionary:
				result.append(str((row_variant as Dictionary).get("product_id", "")))
	result.sort()
	return result


func _string_array(values_variant: Variant) -> Array[String]:
	var result: Array[String] = []
	if values_variant is Array:
		for value_variant: Variant in values_variant as Array:
			result.append(str(value_variant))
	result.sort()
	return result


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant: Variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value.get(key_variant)):
				return false
		return true
	return false


func _stop_audio(node: Node) -> void:
	for audio_variant in node.find_children("*", "AudioStreamPlayer", true, false):
		var audio := audio_variant as AudioStreamPlayer
		if audio != null:
			audio.stop()
			audio.stream = null


func _wait_frames(count: int) -> void:
	for _index in range(maxi(1, count)):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("ROGUELIKE_ECONOMIC_VIABILITY_TEST: %s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ROGUELIKE_ECONOMIC_VIABILITY_TEST|status=%s|checks=%d|failures=%d" % [status, _checks, _failures.size()])
	if not _failures.is_empty():
		print("ROGUELIKE_ECONOMIC_VIABILITY_TEST|first_failure=%s" % _failures[0])
	quit(_failures.size())
