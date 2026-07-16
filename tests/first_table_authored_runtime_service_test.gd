extends SceneTree

const SERVICE_SCENE_PATH := "res://scenes/runtime/FirstTableAuthoredRuntimeService.tscn"
const SCENARIO_PATH := "res://data/scenarios/first_table.json"
const SCENARIO_LOADER_SCRIPT := preload("res://scripts/scenarios/scenario_loader.gd")

const LEGACY_FIXED_KEYS := [
	"facility_market_source_district_index",
	"teaching_card_ids",
	"teaching_card_kind",
	"followup_card_ids",
	"featured_card_ids",
	"starter_monster_ids",
	"preferred_product_ids",
]

var _checks := 0
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
	var fixture: Dictionary = service.call("fixture_snapshot")
	_expect(bool(debug.get("service_ready", false)) and int(debug.get("phase_count", 0)) == 13, "real first_table definition configures thirteen unchanged success phases")
	_expect(_contains_none(fixture, LEGACY_FIXED_KEYS), "active fixture exposes no fixed card, monster, product, or source-district selectors")
	_expect(
		bool(debug.get("selects_from_current_public_rack_only", false))
		and not bool(debug.get("mutates_region_supply_rack", true))
		and not bool(debug.get("fixed_city_development_selection_active", true))
		and not bool(debug.get("fixed_monster_selection_active", true))
		and not bool(debug.get("followup_card_injection_active", true))
		and not bool(debug.get("factory_before_market_assumption_active", true)),
		"debug boundary declares public-rack-only, read-only recommendation ownership"
	)

	var legacy_definition := definition.duplicate(true)
	var legacy_fixture: Dictionary = (legacy_definition.get("fixture", {}) as Dictionary).duplicate(true)
	legacy_fixture["facility_market_source_district_index"] = 5
	legacy_fixture["followup_card_ids"] = ["城市融资1"]
	legacy_fixture["starter_monster_ids"] = ["固定怪兽"]
	legacy_fixture["preferred_product_ids"] = ["固定商品"]
	legacy_definition["fixture"] = legacy_fixture
	service.call("configure", {"scenario_definition": legacy_definition})
	var legacy_debug: Dictionary = service.call("debug_snapshot")
	_expect(
		_contains_none(service.call("fixture_snapshot"), LEGACY_FIXED_KEYS)
		and int(legacy_debug.get("legacy_fixed_fixture_field_count", 0)) == 4,
		"legacy fixed fixture fields are explicitly ignored instead of entering recommendation state"
	)
	service.call("configure", {"scenario_definition": definition})

	var catalog: Dictionary = service.call("resolve_content_catalog", {
		"card_ids": ["城市融资1", "card.market.green.rank_1", "card.factory.green.rank_1"],
		"monster_ids": ["固定怪兽"],
		"product_ids": ["固定商品"],
	})
	_expect(
		int(catalog.get("available_card_count", -1)) == 0
		and bool(catalog.get("catalog_input_ignored", false))
		and (catalog.get("catalog_card_ids", []) as Array).is_empty()
		and (catalog.get("runtime_card_ids", []) as Array).is_empty()
		and str(catalog.get("followup_card_id", "")).is_empty()
		and (catalog.get("starter_monster_ids", []) as Array).is_empty()
		and not bool(catalog.get("legacy_fixed_catalog_selection_active", true)),
		"catalog compatibility call records availability but authors no fixed teaching sequence"
	)

	var market_first := _rack([
		_card("card.market.green.rank_1", "市场 I", "facility", "market", 1),
		_card("card.factory.green.rank_1", "工厂 I", "facility", "factory", 1),
	], 11)
	var market_before_factory: Dictionary = service.call("recommend_rack_item", market_first)
	_expect(
		str(market_before_factory.get("card_id", "")) == "card.market.green.rank_1"
		and not bool(market_before_factory.get("mutates_rack", true)),
		"market may be recommended before a matching factory when that is the current rack order"
	)
	var factory_first := _rack([
		_card("card.factory.green.rank_1", "工厂 I", "facility", "factory", 1),
		_card("card.market.green.rank_1", "市场 I", "facility", "market", 1),
	], 12)
	_expect(
		str((service.call("recommend_rack_item", factory_first) as Dictionary).get("card_id", "")) == "card.factory.green.rank_1",
		"factory may also be recommended first without a category-order branch"
	)

	var tagged_rack := _rack([
		_card("card.route.rank_2", "普通路线牌", "strategy", "", 2),
		_card("card.weather.rank_2", "教学天气牌", "weather", "", 2, ["tutorial"]),
	], 13)
	_expect(
		str((service.call("recommend_rack_item", tagged_rack) as Dictionary).get("card_id", "")) == "card.weather.rank_2",
		"an explicit public tutorial tag may select a later current-rack item"
	)

	var no_suitable := _rack([
		_card("card.blocked.one", "暂不推荐", "strategy", "", 1, [], "", false),
	], 14)
	var generic: Dictionary = service.call("recommend_rack_item", no_suitable)
	_expect(
		not bool(generic.get("available", true))
		and str(generic.get("label", "")) == "浏览当前牌架"
		and str(generic.get("action_hint", "")) == "浏览当前牌架",
		"no suitable card returns the generic browse-current-rack hint"
	)

	var private_rack := market_first.duplicate(true)
	private_rack["purchase_window"] = {"quote": "private"}
	private_rack["player_cash"] = 999999
	var rejected_private: Dictionary = service.call("recommend_rack_item", private_rack)
	_expect(
		not bool(rejected_private.get("available", true))
		and str(rejected_private.get("reason_code", "")) == "public_rack_private_field_rejected"
		and not JSON.stringify(rejected_private).contains("999999"),
		"viewer-private purchase and cash fields fail closed without leaking into guidance"
	)

	var mutation_probe := tagged_rack.duplicate(true)
	var mutation_before := JSON.stringify(mutation_probe)
	service.call("recommend_rack_item", mutation_probe)
	_expect(JSON.stringify(mutation_probe) == mutation_before, "recommendation leaves the caller rack snapshot byte-equivalent as data")

	var composed_rack := _rack([
		_card("card.market.blue.rank_1", "蓝色市场", "facility", "market", 1, ["first_table"], "product.blue"),
		_card("card.route.rank_1", "短程商路", "route", "", 1),
	], 21)
	var content: Dictionary = service.call("compose_runtime_content", {
		"district_index": 2,
		"district_name": "曙光港",
		"public_region_supply_rack_snapshot": composed_rack,
		"city_present": true,
		"owned_facilities": [{"facility_type": "market", "industry_id": "blue", "rank": 1}],
		"public_projects": [{"product_id": "product.blue", "hidden_owner": 2, "ai_score": 99}],
		"gdp_per_minute": 72,
		"cashflow_paid_total": 18,
		"public_clue_count": 3,
		"visible_monster_name": "实际在场怪兽",
	}, catalog)
	_expect(
		str(content.get("teaching_card_id", "")) == "card.market.blue.rank_1"
		and str(content.get("followup_card_id", "")) == "card.route.rank_1"
		and str(content.get("teaching_product_id", "")) == "product.blue"
		and int(content.get("rack_public_revision", 0)) == 21,
		"runtime content derives first and second recommendations only from the current public rack"
	)
	_expect(
		(content.get("starter_monster_ids", []) as Array).is_empty()
		and str(content.get("starter_monster_id", "")).is_empty()
		and str(content.get("visible_monster_name", "")) == "实际在场怪兽",
		"content reports actual visible monster pressure without selecting a fixed starter slot"
	)
	_expect(not JSON.stringify(content.get("public_projects", [])).contains("hidden_owner") and not JSON.stringify(content).contains("\"ai_score\""), "composed public content sanitizes hidden owner and AI fields")

	var no_rack_content: Dictionary = service.call("compose_runtime_content", {
		"district_name": "无推荐区",
		"public_region_supply_rack_snapshot": _rack([], 22),
	}, catalog)
	_expect(
		str(no_rack_content.get("rack_guidance", "")).contains("浏览当前牌架")
		and str(no_rack_content.get("visible_monster_name", "")) == "场上怪兽",
		"empty current rack and absent monster facts produce generic non-fabricated guidance"
	)

	var buy_phase: Dictionary = service.call("contextualize_phase", {"id": "buy_development"}, content)
	var followup_phase: Dictionary = service.call("contextualize_phase", {"id": "buy_followup"}, no_rack_content)
	_expect(
		str(buy_phase.get("detail", "")).contains("蓝色市场")
		and str(followup_phase.get("detail", "")).contains("浏览当前牌架")
		and not str(followup_phase.get("detail", "")).contains("保证槽")
		and not str(followup_phase.get("detail", "")).contains("城市融资1"),
		"phase copy uses live recommendations or generic browsing and never promises a fixed follow-up"
	)

	var supply: Dictionary = service.call("supply_plan", composed_rack)
	var listing_plan: Dictionary = service.call("market_listing_plan")
	_expect(
		bool(supply.get("ready", false))
		and str(supply.get("operation", "")) == "read_only_recommendation"
		and str(supply.get("followup_card_id", "")).is_empty()
		and str(supply.get("inject_after_signal", "")).is_empty()
		and not bool(supply.get("mutates_rack", true))
		and not bool(listing_plan.get("ready", true))
		and not bool(listing_plan.get("mutates_rack", true)),
		"legacy supply and listing APIs are inert read-only boundaries with no injection or fixed source district"
	)

	var product_id := str(service.call("select_teaching_product", {"public_region_supply_rack_snapshot": composed_rack}, catalog))
	var rack_score := int(service.call("score_district", {"public_region_supply_rack_snapshot": composed_rack}, catalog))
	var no_rack_score := int(service.call("score_district", {"product_ids": ["固定商品"], "transport_score": 99.0}, catalog))
	_expect(product_id == "product.blue" and rack_score == 1 and no_rack_score == -1000000, "legacy product and district adapters now depend only on a public rack snapshot")

	var pacing: Dictionary = service.call("pacing_profile")
	var evaluation: Dictionary = service.call("evaluate_pacing", {
		"scenario_started_at": 100.0,
		"elapsed_seconds": 1200.0,
		"completed_signal_times": {
			"card_bought": 320.0,
			"economy_checked": 540.0,
			"followup_card_bought": 760.0,
			"public_clue_read": 980.0,
			"monster_pressure_observed": 1120.0,
			"route_chosen": 1300.0,
		},
	})
	_expect((pacing.get("milestones", []) as Array).size() == 6 and bool(evaluation.get("pacing_gate_passed", false)), "pacing and unchanged success-signal evaluation remain intact")

	var scenario_source := FileAccess.get_file_as_string(SCENARIO_PATH)
	var service_source := FileAccess.get_file_as_string("res://scripts/runtime/first_table_authored_runtime_service.gd")
	_expect(
		not scenario_source.contains("\"followup_card_ids\"")
		and not scenario_source.contains("\"starter_monster_ids\"")
		and not scenario_source.contains("城市融资1")
		and not scenario_source.contains("保证槽")
		and not service_source.contains("first_table_pacing_guarantee"),
		"active scenario and service contain no fixed supply, starter, guarantee-slot, or named injection payload"
	)
	_expect(
		_is_data_only(fixture)
		and _is_data_only(catalog)
		and _is_data_only(content)
		and _is_data_only(supply)
		and _is_data_only(debug),
		"all service outputs remain recursively pure data"
	)
	service.queue_free()
	await process_frame
	_finish()


func _rack(cards: Array, revision: int) -> Dictionary:
	return {
		"visibility_scope": "public",
		"public_snapshot": true,
		"region_id": "region.test",
		"public_revision": revision,
		"cards": cards.duplicate(true),
	}


func _card(
	card_id: String,
	display_name: String,
	kind: String,
	facility_type: String,
	rank: int,
	tags: Array = [],
	product_id := "",
	tutorial_eligible := true
) -> Dictionary:
	return {
		"card_id": card_id,
		"display_name": display_name,
		"kind": kind,
		"facility_type": facility_type,
		"rank": rank,
		"tutorial_tags": tags.duplicate(),
		"product_id": product_id,
		"tutorial_eligible": tutorial_eligible,
		"facts": "公开卡面条件",
	}


func _contains_none(value: Dictionary, keys: Array) -> bool:
	for key_variant in keys:
		if value.has(str(key_variant)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	print("FIRST_TABLE_PUBLIC_RACK_RECOMMENDATION_V06_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(_failures.size())


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
