extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var rng := coordinator.run_rng_service()
	_expect(world != null and ai != null and port != null and rng != null, "production composition exposes WorldSession, AI, RNG, and the existing region port")
	if world == null or ai == null or port == null or rng == null:
		_finish(coordinator)
		return

	world.replace_districts(_district_fixture(), true)
	var rows := port.public_district_facts_snapshot()
	_expect(port.public_district_facts_ready(), "public district facts are ready from the authoritative WorldSession")
	_expect(rows.size() == 5, "snapshot preserves every source row including destroyed and inactive-city rows")
	_expect(TablePresentationPureDataPolicy.is_pure_data(rows), "snapshot is detached pure data")
	for index in range(rows.size()):
		var row := rows[index] as Dictionary
		_expect(row.keys() == AiRegionKnowledgeQueryPort.PUBLIC_DISTRICT_FACT_KEYS, "row %d uses the exact public schema allowlist" % index)
		_expect(int(row.get("district_index", -1)) == index and int(row.get("region_index", -1)) == index, "row %d preserves source order and indices" % index)
		_expect(str(row.get("visibility_scope", "")) == "public", "row %d declares public visibility" % index)
		_expect(str(row.get("source_revision", "")).length() == 64 and str(row.get("fingerprint", "")).length() == 64, "row %d carries deterministic revisions" % index)
	var row0 := rows[0] as Dictionary
	var city0 := row0.get("city", {}) as Dictionary
	_expect(city0.keys() == AiRegionKnowledgeQueryPort.PUBLIC_DISTRICT_CITY_FACT_KEYS, "nested city facts use the exact public allowlist")
	_expect(str(row0.get("region_id", "")) == "region.alpha" and str(row0.get("name", "")) == "阿尔法区", "public identity is preserved")
	_expect((row0.get("products", []) as Array) == ["水"] and (row0.get("demands", []) as Array) == ["电"], "district product and demand strings are preserved")
	_expect((city0.get("product_names", []) as Array) == ["药"] and (city0.get("demand_names", []) as Array) == ["粮"], "city product dictionaries are narrowed to public names")
	_expect(str((rows[4] as Dictionary).get("region_id", "")) == "region.004", "missing legacy region id keeps the existing deterministic fallback")
	_expect(str((rows[4] as Dictionary).get("terrain", "")) == "land", "missing terrain keeps the existing land fallback")
	var serialized := JSON.stringify(rows)
	for forbidden in ["owner", "hidden_owner", "owner_knowledge", "damage", "panic", "warehouse", "trade_route", "private_marker", "future_supply", "ai_plan"]:
		_expect(not serialized.contains(forbidden), "snapshot excludes %s" % forbidden)

	var repeated := port.public_district_facts_snapshot()
	_expect(repeated == rows, "same public authority produces an identical snapshot")
	_expect(str((repeated[0] as Dictionary).get("source_revision", "")) == str(row0.get("source_revision", "")), "same public authority preserves source revision")
	var detached := rows.duplicate(true)
	(((detached[0] as Dictionary).get("city", {}) as Dictionary).get("product_names", []) as Array)[0] = "篡改"
	_expect(str((((port.public_district_facts_snapshot()[0] as Dictionary).get("city", {}) as Dictionary).get("product_names", []) as Array)[0]) == "药", "nested city arrays are detached")

	var world_before_query := world.to_save_data()
	var rng_before_query := rng.capture_plan_checkpoint()
	var debug_before_query := port.debug_snapshot()
	port.public_district_facts_snapshot()
	port.public_district_fact(0)
	var debug_after_query := port.debug_snapshot()
	_expect(world.to_save_data() == world_before_query, "public district query mutates no WorldSession state")
	_expect(rng.capture_plan_checkpoint() == rng_before_query, "public district query consumes zero RNG")
	_expect(debug_after_query == debug_before_query, "public district query performs literal zero port mutation")
	_expect(int(debug_after_query.get("public_query_count", -1)) == 0, "new public district API does not reuse the diagnostic counter")
	_expect(bool(debug_after_query.get("public_district_facts_literal_zero_mutation", false)), "debug contract records zero query mutation")
	_expect(not bool(debug_after_query.get("public_district_facts_exposes_owner", true)), "debug contract records zero owner exposure")
	_expect(not bool(debug_after_query.get("public_district_facts_exposes_damage", true)) and not bool(debug_after_query.get("public_district_facts_exposes_panic", true)), "debug contract excludes deprecated damage and panic mirrors")

	var private_only := world.districts.duplicate(true)
	var private_city := ((private_only[0] as Dictionary).get("city", {}) as Dictionary).duplicate(true)
	private_city["owner"] = 99
	private_city["hidden_owner"] = 77
	private_city["warehouse_stockpile_count"] = 900
	private_city["trade_route_damage"] = 800
	private_city["private_marker"] = "PRIVATE_CITY"
	(private_only[0] as Dictionary)["city"] = private_city
	(private_only[0] as Dictionary)["damage"] = 600
	(private_only[0] as Dictionary)["panic"] = 500
	(private_only[0] as Dictionary)["future_supply"] = ["PRIVATE_FUTURE"]
	(private_only[0] as Dictionary)["ai_plan"] = {"target": 4}
	world.replace_districts(private_only, true)
	_expect(port.public_district_facts_snapshot() == repeated, "private and deprecated source changes leave public facts byte-equivalent")
	var public_change := private_only.duplicate(true)
	(public_change[0] as Dictionary)["name"] = "公开改名"
	world.replace_districts(public_change, true)
	var changed := port.public_district_facts_snapshot()
	_expect(str((changed[0] as Dictionary).get("name", "")) == "公开改名", "public field changes remain observable")
	_expect(str((changed[0] as Dictionary).get("source_revision", "")) != str(row0.get("source_revision", "")), "public field changes rotate source revision")
	world.replace_districts(_district_fixture(), true)

	_expect(ai._district_or_city_has_product(0, "水"), "district product lookup consumes typed public facts")
	_expect(ai._district_or_city_has_product(0, "药"), "city product lookup consumes typed public facts")
	_expect(ai._district_or_city_has_product(0, "粮"), "city demand lookup consumes typed public facts")
	_expect(not ai._district_or_city_has_product(0, "秘密"), "missing product fails closed")
	_expect(ai._alive_district_indices() == [0, 2, 3, 4], "alive district enumeration preserves source order")
	_expect(ai._district_ocean_neighbor_count(0) == 1, "ocean-neighbor count preserves public terrain behavior")
	_expect(ai._district_ocean_neighbor_count(-1) == 0 and ai._district_ocean_neighbor_count(99) == 0, "ocean-neighbor invalid indices fail closed")
	_expect(ai._ai_business_public_region_id(0) == "region.alpha", "business target resolves a public active region id")
	_expect(ai._ai_business_public_region_id(1).is_empty(), "destroyed business region fails closed")
	_expect(ai._ai_business_public_region_id(2).is_empty(), "missing-city business region fails closed")
	_expect(ai._ai_business_public_region_id(3).is_empty(), "inactive-city business region fails closed")
	_expect(ai._ai_business_public_region_id(4) == "region.004", "legacy missing id preserves deterministic target fallback")
	_expect(ai._ai_district_touches_product(0, "电"), "route scoring sees public district demand")
	_expect(ai._ai_district_touches_product(0, "药"), "route scoring sees public city product")
	_expect(not ai._ai_district_touches_product(0, "秘密"), "route scoring rejects absent product")
	_expect(ai._ai_first_alive_district() == 0, "first-alive tie order remains source order")
	var first_destroyed := world.districts.duplicate(true)
	(first_destroyed[0] as Dictionary)["destroyed"] = true
	world.replace_districts(first_destroyed, true)
	_expect(ai._ai_first_alive_district() == 2, "first-alive skips destroyed rows without sorting")
	world.replace_districts(_district_fixture(), true)
	_expect(ai._ai_counter_entry_target_city({"selected_district": 0}) == 0, "counter target accepts an active public city")
	_expect(ai._ai_counter_entry_target_city({"selected_district": 3}) == -1, "counter target rejects an inactive city")
	_expect(ai._ai_counter_entry_target_city({"selected_district": 99}) == -1, "counter target rejects an invalid district")

	var bound_port := ai.get("_ai_region_knowledge_query_port") as AiRegionKnowledgeQueryPort
	ai.set("_ai_region_knowledge_query_port", null)
	_expect(not ai._public_district_facts_ready(), "missing typed port reports not ready")
	_expect(ai._public_district_facts_snapshot().is_empty(), "missing typed port returns no fallback snapshot")
	_expect(not ai._district_or_city_has_product(0, "水"), "missing typed port does not fall back to raw districts")
	_expect(ai._alive_district_indices().is_empty() and ai._ai_first_alive_district() == -1, "missing typed port fails lifecycle queries closed")
	_expect(ai._ai_business_public_region_id(0).is_empty(), "missing typed port fails business targeting closed")
	ai.set("_ai_region_knowledge_query_port", bound_port)

	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	for function_name in [
		"_district_or_city_has_product",
		"_alive_district_indices",
		"_district_ocean_neighbor_count",
		"_ai_business_public_region_id",
		"_ai_district_touches_product",
		"_ai_first_alive_district",
		"_ai_counter_entry_target_city",
	]:
		var body := _function_body(ai_source, function_name)
		_expect(not body.is_empty(), "%s remains present" % function_name)
		_expect(not body.contains("districts[") and not body.contains("districts.size"), "%s no longer reads the whole districts collection" % function_name)
		_expect(not body.contains("_district_city(") and not body.contains("_call_world"), "%s has no Main or raw-city fallback" % function_name)

	_expect(coordinator_scene.count("AiRegionKnowledgeQueryPort.tscn") == 1, "production composition keeps exactly one existing region port")
	_expect(not registry_scene.contains("AiRegionKnowledgeQueryPort"), "public district facts add no save owner or registry section")
	_expect(str(ai.debug_snapshot().get("typed_public_district_facts_bound", false)) == "true", "AI debug snapshot declares the typed public district boundary")
	_expect(not bool(ai.debug_snapshot().get("public_district_facts_uses_main", true)), "AI debug snapshot declares zero Main routing")
	_expect(not bool(ai.debug_snapshot().get("public_district_facts_uses_whole_districts", true)), "AI debug snapshot declares zero whole-district consumption")

	_finish(coordinator)


func _district_fixture() -> Array:
	return [
		{
			"region_id": "region.alpha",
			"name": "阿尔法区",
			"destroyed": false,
			"terrain": "land",
			"products": ["水"],
			"demands": ["电"],
			"neighbors": [1, 2],
			"damage": 11,
			"panic": 12,
			"private_marker": "PRIVATE_DISTRICT",
			"city": {
				"active": true,
				"owner": 3,
				"products": [{"name": "药", "owner": 3, "private_marker": "PRIVATE_PRODUCT"}],
				"demands": ["粮"],
				"warehouse_stockpile_count": 4,
				"trade_route_damage": 5,
				"private_marker": "PRIVATE_CITY",
			},
		},
		{
			"region_id": "region.beta",
			"name": "贝塔海",
			"destroyed": true,
			"terrain": "ocean",
			"products": ["矿"],
			"demands": [],
			"neighbors": [0],
			"city": {"active": true, "owner": 2, "products": [], "demands": []},
		},
		{
			"region_id": "region.gamma",
			"name": "伽马区",
			"destroyed": false,
			"terrain": "land",
			"products": [],
			"demands": [],
			"neighbors": [0],
		},
		{
			"region_id": "region.delta",
			"name": "德尔塔区",
			"destroyed": false,
			"terrain": "land",
			"products": [],
			"demands": [],
			"neighbors": [],
			"city": {"active": false, "owner": 1, "products": ["水"], "demands": []},
		},
		{
			"name": "旧式区域",
			"destroyed": false,
			"products": [],
			"demands": [],
			"neighbors": [],
			"city": {"active": true, "owner": 0, "products": [], "demands": []},
		},
	]


func _function_body(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next := source.find("
func ", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(coordinator: Node) -> void:
	if coordinator != null:
		coordinator.queue_free()
	await process_frame
	if _failures.is_empty():
		print("AI public district facts typed-port migration passed (%d checks)." % _checks)
		print("AI_PUBLIC_DISTRICT_FACTS_TYPED_PORT_MIGRATION_COMPLETE")
		quit(0)
		return
	for failure in _failures:
		push_error("AI public district facts migration failure: %s" % failure)
	push_error("AI public district facts typed-port migration failed (%d/%d)." % [_failures.size(), _checks])
	quit(1)