extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var world := coordinator.world_session_state() if coordinator != null else null
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController if coordinator != null else null
	var port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort if coordinator != null else null
	_expect(coordinator != null and world != null and ai != null and port != null, "real main scene exposes the production region boundary")
	if coordinator == null or world == null or ai == null or port == null:
		_finish()
		return

	world.replace_districts([
		{
			"region_id": "region.bench.alpha",
			"name": "Bench Alpha",
			"destroyed": false,
			"terrain": "land",
			"products": ["water"],
			"demands": ["power"],
			"neighbors": [1],
			"damage": 12,
			"panic": 14,
			"city": {
				"active": true,
				"owner": 3,
				"products": [{"name": "medicine", "private_marker": "PRIVATE"}],
				"demands": ["food"],
				"warehouse_stockpile_count": 9,
			},
		},
		{
			"region_id": "region.bench.ocean",
			"name": "Bench Ocean",
			"destroyed": false,
			"terrain": "ocean",
			"products": [],
			"demands": [],
			"neighbors": [0],
			"city": {"active": false, "owner": 2, "products": [], "demands": []},
		},
	], true)
	var debug_before := port.debug_snapshot()
	var rows := port.public_district_facts_snapshot()
	var debug_after := port.debug_snapshot()
	_expect(rows.size() == 2, "production port returns both regions in source order")
	_expect((rows[0] as Dictionary).keys() == AiRegionKnowledgeQueryPort.PUBLIC_DISTRICT_FACT_KEYS, "production row uses the exact typed schema")
	_expect(((rows[0] as Dictionary).get("city", {}) as Dictionary).keys() == AiRegionKnowledgeQueryPort.PUBLIC_DISTRICT_CITY_FACT_KEYS, "production city row uses the exact typed schema")
	_expect(TablePresentationPureDataPolicy.is_pure_data(rows), "production snapshot is pure data")
	var serialized := JSON.stringify(rows)
	for forbidden in ["owner", "damage", "panic", "warehouse", "private_marker"]:
		_expect(not serialized.contains(forbidden), "production snapshot excludes %s" % forbidden)
	_expect(debug_before == debug_after, "production query performs zero port mutation")
	_expect(ai._district_or_city_has_product(0, "water"), "production AI reads a district product through the port")
	_expect(ai._district_or_city_has_product(0, "medicine"), "production AI reads a city product through the port")
	_expect(ai._district_ocean_neighbor_count(0) == 1, "production AI reads typed neighbor terrain")
	_expect(ai._ai_business_public_region_id(0) == "region.bench.alpha", "production AI resolves an active public business region")
	_expect(ai._ai_business_public_region_id(1).is_empty(), "production AI rejects an inactive-city business region")
	_expect(ai._alive_district_indices() == [0, 1], "production AI preserves public district order")
	_expect(ai._ai_first_alive_district() == 0, "production AI preserves first-match tie behavior")
	_expect(ai._ai_counter_entry_target_city({"selected_district": 0}) == 0, "production counter target accepts public active city")
	_expect(ai._ai_counter_entry_target_city({"selected_district": 1}) == -1, "production counter target rejects public inactive city")

	_expect(bool(ai.debug_snapshot().get("typed_public_district_facts_bound", false)), "production AI reports the typed public district boundary")
	_expect(not bool(ai.debug_snapshot().get("public_district_facts_uses_main", true)), "production AI reports zero Main fallback")
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("AI_PUBLIC_DISTRICT_FACTS_TYPED_PORT_MIGRATION_BENCH|status=PASS|checks=%d|failures=0" % _checks)
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("AI public district Bench failure: %s" % failure)
	print("AI_PUBLIC_DISTRICT_FACTS_TYPED_PORT_MIGRATION_BENCH|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	get_tree().quit(1)