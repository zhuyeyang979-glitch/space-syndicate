extends SceneTree

const SERVICE_SCENE_PATH := "res://scenes/runtime/FirstTableAuthoredRuntimeService.tscn"
const SCENARIO_LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")
const CARD_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v04.tres"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SERVICE_SCENE_PATH) as PackedScene
	_expect(packed != null, "service scene loads")
	var service := packed.instantiate() if packed != null else null
	if service == null:
		_finish()
		return
	root.add_child(service)
	var definition: Dictionary = SCENARIO_LOADER_SCRIPT.new().load_by_id("first_table")
	service.call("configure", {"scenario_definition": definition})
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("service_ready", false)) and int(debug.get("phase_count", 0)) == 14, "real first_table definition configures fourteen phases")
	var catalog: Dictionary = service.call("resolve_content_catalog", _catalog())
	_expect((catalog.get("runtime_card_ids", []) as Array).has("活体芯片生产1") and (catalog.get("runtime_card_ids", []) as Array).has("环晶电池生产城1") and (catalog.get("runtime_card_ids", []) as Array).has("城市融资1"), "catalog resolves preferred, local-product, and follow-up cards")
	_expect((catalog.get("featured_card_ids", []) as Array).size() == 20 and (catalog.get("followup_card_ids", []) as Array).size() == 4 and (catalog.get("starter_monster_ids", []) as Array).size() == 4 and (catalog.get("preferred_product_ids", []) as Array).size() == 3, "catalog resolves the authored core set, teaching sequence, monsters, and products")
	var product_id := str(service.call("select_teaching_product", {"district_product_ids": ["普通矿"], "district_demand_ids": ["轨迹墨水"], "remote_demand_product_ids": ["普通矿"]}, catalog))
	_expect(product_id == "轨迹墨水", "authored preferred product wins over generic trade-chain fallback")
	var content: Dictionary = service.call("compose_runtime_content", {
		"district_index": 2,
		"district_name": "曙光港",
		"teaching_product_id": "活体芯片",
		"teaching_card_id": "活体芯片生产1",
		"starter_monster_id": "镜像猎兵",
		"city_present": true,
		"city_product_ids": ["活体芯片"],
		"city_demand_ids": ["轨迹墨水"],
		"public_projects": [{"product_id": "活体芯片", "hidden_owner": 2}],
		"own_project_shares": [{"product_id": "活体芯片", "direction_label": "生产", "own_share_percent": 25.0}],
		"gdp_per_minute": 72,
		"cashflow_paid_total": 18,
		"public_clue_count": 3,
		"monster_pressure_visible": true,
		"visible_monster_name": "镜像猎兵",
	}, catalog)
	_expect(str(content.get("urbanization_share_text", "")).contains("25.00%") and int(content.get("gdp_per_minute", 0)) == 72 and bool(content.get("positive_income_observed", false)), "content composes private share and income summary")
	_expect(not JSON.stringify(content.get("public_projects", [])).contains("hidden_owner"), "public project payload removes hidden ownership")
	var phase: Dictionary = service.call("contextualize_phase", {"id": "check_economy", "label": "收入"}, content)
	_expect(str(phase.get("detail", "")).contains("72") and str(phase.get("detail", "")).contains("18"), "phase context uses real GDP and payout facts")
	_expect(str(service.call("completion_summary", content)).contains("整局仍继续"), "completion copy preserves mission-not-match boundary")
	var pacing: Dictionary = service.call("pacing_profile")
	_expect(float(pacing.get("recommended_min_seconds", 0.0)) == 900.0 and float(pacing.get("target_duration_seconds", 0.0)) == 1200.0 and float(pacing.get("recommended_max_seconds", 0.0)) == 1800.0 and (pacing.get("milestones", []) as Array).size() == 6, "first_table authors a 15-30 minute pacing profile")
	var evaluation: Dictionary = service.call("evaluate_pacing", {"scenario_started_at": 100.0, "elapsed_seconds": 1200.0, "completed_signal_times": {"card_bought": 320.0, "economy_checked": 540.0, "followup_card_bought": 760.0, "public_clue_read": 980.0, "monster_pressure_observed": 1120.0, "route_chosen": 1300.0}})
	_expect(bool(evaluation.get("pacing_gate_passed", false)) and str(evaluation.get("recommended_window_status", "")) == "within_window", "pacing evaluation accepts an ordered twenty-minute playthrough")
	var supply: Dictionary = service.call("supply_plan", catalog)
	_expect(bool(supply.get("ready", false)) and str(supply.get("followup_card_id", "")) == "城市融资1" and str(supply.get("inject_after_signal", "")) == "city_development_resolved", "authored supply plan prepositions the second card after project resolution")
	var score := int(service.call("score_district", {"build_allowed": true, "product_ids": ["活体芯片"], "demand_ids": ["轨迹墨水"], "transport_score": 1.5, "remote_demand_product_ids": ["活体芯片"]}, catalog))
	_expect(score == 194, "district authored score preserves characterized weights")
	_expect(_is_data_only(catalog) and _is_data_only(content) and _is_data_only(pacing) and _is_data_only(evaluation) and _is_data_only(supply) and _is_data_only(debug), "all service outputs stay pure data")
	service.queue_free()
	_finish()


func _catalog() -> Dictionary:
	var catalog_resource: Resource = load(CARD_CATALOG_PATH)
	var card_ids: Array = catalog_resource.call("ordered_card_ids") if catalog_resource != null else []
	if not card_ids.has("活体芯片生产1"):
		card_ids.append("活体芯片生产1")
	if not card_ids.has("环晶电池生产城1"):
		card_ids.append("环晶电池生产城1")
	return {
		"card_ids": card_ids,
		"city_development_cards": [{"card_id": "活体芯片生产1", "rank": 1, "product_id": "活体芯片"}, {"card_id": "环晶电池生产城1", "rank": 1, "product_id": "环晶电池"}],
		"monster_ids": ["镜像猎兵", "蓝锋骑士", "流星哨兵", "绿洲修复体"],
		"product_ids": ["活体芯片", "轨迹墨水", "等离子米"],
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("FirstTableAuthoredRuntimeServiceTest: PASS")
	else:
		print("FirstTableAuthoredRuntimeServiceTest: FAIL (%d)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item_variant in value:
			if not _is_data_only(item_variant):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
