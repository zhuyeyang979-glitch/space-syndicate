extends SceneTree

const REGION_SUPPLY_SCENE_PATH := "res://scenes/runtime/RegionSupplyRuntimeController.tscn"
const REGION_SUPPLY_RANDOMIZATION_TEST_PATH := "res://tests/region_supply_full_randomization_v06_test.gd"
const RETIRED_MAIN_SUPPLY_SYMBOLS := [
	"FIRST_RUN_TEACHING_CARD_NAME",
	"FIRST_RUN_TEACHING_CARD_SOURCE",
	"FIRST_TABLE_FOLLOWUP_CARD_SOURCE",
	"func _first_table_resolved_content_catalog(",
	"func _first_table_followup_card_name(",
	"func _first_table_teaching_product_for_district(",
	"func _first_table_starter_monster_name(",
	"func _first_actionable_teachable_hand_slot(",
	"func _first_table_accessible_land_district(",
	"func _first_table_followup_hand_slot(",
	"func _buy_first_table_followup_card(",
	"func _first_teachable_buyable_district_card(",
	"func _first_run_teaching_card_name(",
	"func _ensure_first_run_teaching_card_supply(",
	"func _first_run_card_is_teachable_after_purchase(",
	"func _first_run_skill_has_direct_teaching_profile(",
	"func _first_run_skill_is_direct_teachable(",
	"func _ensure_first_run_teachable_hand_card(",
	"func _first_card_accessible_district_for_player(",
	"func _first_teachable_buyable_district_for_player(",
	"coach_buy_followup_card",
	"coach_play_followup_card",
	"func _assign_district_card_choices(",
	"func _normalize_card_supply_state(",
	"func _ensure_fixed_monster_card_supply(",
	"func _inject_first_table_followup_card_supply(",
	"\"card_choices\"",
	"\"card_sources\"",
	"\"monster_guarantee_card\"",
	"\"city_development_guarantee_card\"",
	"factory-first",
	"market-after-factory",
	"factory_before_market",
	"market_after_factory",
	"selected_market_skill := \"城市融资1\"",
]
const PUBLIC_SUPPLY_FORBIDDEN_KEY_FRAGMENTS := [
	"bag",
	"rng",
	"future",
	"private",
]
const PUBLIC_SUPPLY_FORBIDDEN_KEYS := [
	"gameplay_seed",
	"claimed_unique_keys",
	"pending_transactions",
	"terminal_transactions",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for card requirement policy")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_new_game")
	await process_frame
	await process_frame
	_check_catalog_policy(main)
	_check_region_share_boundary(main)
	_check_ai_metadata(main)
	_check_region_supply_randomization_contract(main)
	root.remove_child(main)
	main.free()
	_finish()


func _check_catalog_policy(main: Node) -> void:
	var coordinator := _coordinator(main)
	_expect(coordinator != null and coordinator.has_method("audit_card_play_requirements"), "Coordinator exposes the authoritative card requirement audit")
	if coordinator == null:
		return
	var audit_requests := _audit_requests(main)
	var report := coordinator.call("audit_card_play_requirements", audit_requests) as Dictionary
	_expect(bool(report.get("ok", false)), "card requirement audit passes: %s" % str(report.get("issues", [])))
	_expect(int(report.get("rank_one_count", 0)) >= 80, "requirement audit covers the real rank-I catalog")
	_expect(int(report.get("rank_one_free_count", 0)) * 2 > int(report.get("rank_one_count", 0)), "most rank-I cards have no GDP play gate")
	_expect((report.get("standard_gradient_percent", []) as Array) == [0, 15, 25, 35], "standard I-IV GDP gate is 0/15/25/35 percent")
	_expect((report.get("high_impact_gradient_percent", []) as Array) == [10, 20, 30, 40], "high-impact I-IV GDP gate is 10/20/30/40 percent")
	var facility := _requirement_fixture("facility", "facility", 4)
	facility["schema_version"] = "v0.6"
	facility["machine"] = {"category_id": "facility"}
	var facility_requirement := _requirement(main, 0, facility)
	_expect(int(facility_requirement.get("required_share_percent", -1)) == 0, "v0.6 facilities have no GDP play gate")
	_expect(String(facility_requirement.get("requirement_text", "")) == "条件：无", "v0.6 facility condition text stays concise")
	var normal_rank_one := _requirement_fixture("standard", "city_revenue_boost", 1)
	var normal_rank_two := _requirement_fixture("standard", "city_revenue_boost", 2)
	var high_impact := _requirement_fixture("high_impact", "card_counter", 1)
	_expect(int(_requirement(main, 0, normal_rank_one).get("required_share_percent", -1)) == 0, "normal rank-I card is condition-free")
	_expect(int(_requirement(main, 0, normal_rank_two).get("required_share_percent", -1)) == 15, "normal rank-II card requires 15 percent regional GDP share")
	_expect(int(_requirement(main, 0, high_impact).get("required_share_percent", -1)) == 10, "high-impact rank-I interaction retains a 10 percent GDP gate")


func _check_region_share_boundary(main: Node) -> void:
	var coordinator := _coordinator(main)
	_expect(coordinator != null, "share boundary uses the authoritative eligibility service")
	if coordinator == null:
		return
	var rank_two := _requirement_fixture("share_boundary", "city_revenue_boost", 2)
	var exact_facts := coordinator.call("card_play_world_facts", 0, rank_two, {"selected_district": 0}) as Dictionary
	exact_facts["selected_district"] = 0
	exact_facts["share_basis_points_by_district"] = {"0": 1500}
	var exact_status := coordinator.call("card_play_requirement_status", {"player_index": 0, "skill": rank_two}, exact_facts) as Dictionary
	_expect(int(exact_status.get("current_share_basis_points", -1)) == 1500, "regional GDP share uses exact basis points")
	_expect(bool(exact_status.get("requirement_satisfied", false)), "a share exactly equal to the threshold is playable")
	var below_facts := exact_facts.duplicate(true)
	below_facts["share_basis_points_by_district"] = {"0": 1499}
	var below_status := coordinator.call("card_play_requirement_status", {"player_index": 0, "skill": rank_two}, below_facts) as Dictionary
	_expect(not bool(below_status.get("requirement_satisfied", true)), "a share below the threshold is blocked")
	var below_eligibility := coordinator.call(
		"evaluate_card_play",
		{"player_index": 0, "skill": rank_two, "evaluation_mode": "rule"},
		below_facts
	) as Dictionary
	_expect(not bool(below_eligibility.get("allowed", true)), "authoritative play validation enforces the GDP share gate")
	var public_entry := {
		"skill": rank_two,
		"play_requirement_scope": "target_region",
		"play_requirement_gdp_share_percent": 15,
		"play_requirement_district": 0,
		"play_cash_cost": 0,
	}
	var public_text := String(main.call("_card_resolution_play_requirement_text", public_entry))
	_expect(public_text.contains("GDP份额≥15%"), "public resolution text exposes the printed threshold")
	_expect(not public_text.contains("10.0") and not public_text.contains("current_share"), "public resolution text does not expose the player's actual share")


func _check_ai_metadata(main: Node) -> void:
	var controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/AiRuntimeController")
	_expect(controller != null, "AiRuntimeController owns AI requirement and training metadata")
	if controller == null:
		return
	var skill := _requirement_fixture("ai_metadata", "city_revenue_boost", 2)
	var candidate := controller.call("_ai_play_requirement_metadata", 0, skill, 0) as Dictionary
	candidate["policy_kind"] = "city_revenue_boost"
	candidate["score"] = 100
	var training := controller.call("_ai_candidate_training_view", candidate) as Dictionary
	var decision := controller.call("_ai_card_decision_metadata", candidate, -1) as Dictionary
	for field_name in ["play_requirement_kind", "required_share_percent", "current_share_percent", "qualifying_district", "requirement_satisfied"]:
		_expect(training.has(field_name), "AI training metadata keeps %s" % field_name)
		_expect(decision.has(field_name), "AI decision metadata keeps %s" % field_name)
	var locked_skill := skill.duplicate(true)
	locked_skill["play_region_scope"] = "target_region"
	locked_skill["play_requirement_district"] = 0
	var locked_metadata := controller.call("_ai_play_requirement_metadata", 0, locked_skill, 1) as Dictionary
	_expect(int(locked_metadata.get("qualifying_district", -1)) == 0, "AI audits the card's locked GDP district instead of replacing it with another planned region")
	controller.call("_record_ai_decision", 1, "匿名出牌", 0, 100, "metadata envelope test", [candidate], {
		"kind": "city_revenue_boost",
		"policy_kind": "city_revenue_boost",
	})
	var ai_player := (((main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players as Array)[1] as Dictionary
	var samples := ((ai_player.get("ai_memory", {}) as Dictionary).get("decision_samples", []) as Array)
	_expect(not samples.is_empty(), "AI decision metadata writes a training sample")
	if not samples.is_empty():
		var sample := samples[samples.size() - 1] as Dictionary
		_expect(String(sample.get("kind", "")) == "匿名出牌", "candidate card kind cannot overwrite the AI decision envelope kind")
		_expect(String(sample.get("policy_kind", "")) == "city_revenue_boost", "candidate policy kind remains trainable metadata")


func _check_region_supply_randomization_contract(main: Node) -> void:
	_check_main_supply_retirement_contract()
	_check_authoritative_randomization_coverage()
	var owner := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/RegionSupplyRuntimeController")
	_expect(owner != null, "GameRuntimeCoordinator scene owns RegionSupplyRuntimeController")
	if owner == null:
		return
	_expect(owner.scene_file_path == REGION_SUPPLY_SCENE_PATH, "RegionSupply owner is instantiated from its editable runtime scene")
	_expect(owner.has_method("configure") and owner.has_method("public_rack_snapshot"), "RegionSupply scene owner exposes configuration and public rack APIs")
	var owner_debug: Dictionary = owner.call("debug_snapshot") if owner.has_method("debug_snapshot") else {}
	_expect(
		String(owner_debug.get("runtime_owner", "")) == "RegionSupplyRuntimeController"
			and bool(owner_debug.get("owns_deterministic_supply_bags", false))
			and not bool(owner_debug.get("public_snapshot_exposes_future_bag", true)),
		"RegionSupply owner keeps deterministic bags private"
	)
	var owner_public: Dictionary = owner.call("public_rack_snapshot")
	_expect(bool(owner_public.get("available", false)) and not (owner_public.get("regions", []) as Array).is_empty(), "new game exposes a configured public RegionSupply rack")
	var owner_leak := _first_forbidden_public_supply_key(owner_public)
	_expect(owner_leak.is_empty(), "production public RegionSupply snapshot omits bag/RNG/future/private fields%s" % ("" if owner_leak.is_empty() else ": " + owner_leak))
	_check_lightweight_randomized_supply_runtime()


func _check_main_supply_retirement_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_expect(not source.is_empty(), "main source is readable for stale supply-oracle retirement")
	if source.is_empty():
		return
	var stale_symbols: Array[String] = []
	for symbol in RETIRED_MAIN_SUPPLY_SYMBOLS:
		if source.contains(symbol):
			stale_symbols.append(symbol)
	_expect(stale_symbols.is_empty(), "main has no fixed-slot, category-order, or named teaching-card guarantee symbols: %s" % str(stale_symbols))
	_expect(
		source.contains("region_supply_public_rack")
			and source.contains("public_region_supply_rack_snapshot"),
		"main consumes the scene-owned public RegionSupply rack instead of shadow supply fields"
	)


func _check_authoritative_randomization_coverage() -> void:
	var source := FileAccess.get_file_as_string(REGION_SUPPLY_RANDOMIZATION_TEST_PATH)
	_expect(not source.is_empty(), "authoritative RegionSupply full-randomization test is present")
	if source.is_empty():
		return
	var required_coverage := [
		"func _verify_seed_determinism_and_diversity()",
		"func _verify_no_category_guarantees()",
		"func _verify_public_reads_do_not_refresh_or_leak_bags()",
		"func _verify_single_slot_atomic_refill()",
		"func _verify_save_roundtrip_preserves_next_draw()",
		"func _verify_global_unique_is_not_redealt()",
		"REGION_SUPPLY_FULL_RANDOMIZATION_V06_TEST|status=PASS",
	]
	var missing: Array[String] = []
	for marker in required_coverage:
		if not source.contains(marker):
			missing.append(marker)
	_expect(missing.is_empty(), "full-randomization authority retains deterministic, privacy, refill, save, and uniqueness coverage: %s" % str(missing))


func _check_lightweight_randomized_supply_runtime() -> void:
	var left := _region_supply_fixture_controller(7301)
	var right := _region_supply_fixture_controller(7301)
	_expect(left != null and right != null, "lightweight RegionSupply runtime fixture configures")
	if left == null or right == null:
		if left != null:
			left.free()
		if right != null:
			right.free()
		return
	var left_public: Dictionary = left.call("public_rack_snapshot")
	var right_public: Dictionary = right.call("public_rack_snapshot")
	_expect(_fingerprint(left_public) == _fingerprint(right_public), "the same gameplay seed produces the same public rack")
	var fixture_leak := _first_forbidden_public_supply_key(left_public)
	_expect(fixture_leak.is_empty(), "fixture public snapshot omits bag/RNG/future/private fields%s" % ("" if fixture_leak.is_empty() else ": " + fixture_leak))
	left.free()
	right.free()

	var first_types: Dictionary = {}
	var controller := _region_supply_fixture_controller(1)
	if controller == null:
		_expect(false, "category diversity fixture configures")
		return
	for sample_index in range(1, 1025):
		var seed_value := sample_index * 7919 + 17
		var configured := _configure_region_supply_fixture(controller, seed_value)
		if not bool(configured.get("configured", false)):
			_expect(false, "category diversity fixture reconfigures: %s" % str(configured))
			break
		var first_type := _first_supply_card_type(controller.call("public_rack_snapshot"))
		if first_type != "":
			first_types[first_type] = true
		if first_types.has("facility_market") and first_types.has("facility_factory") and first_types.has("route"):
			break
	controller.free()
	_expect(first_types.has("facility_market"), "one unified legal pool allows a market card in the first slot")
	_expect(first_types.has("facility_factory"), "one unified legal pool allows a factory card in the first slot")
	_expect(first_types.has("route"), "one unified legal pool allows another legal category in the first slot")


func _region_supply_fixture_controller(seed_value: int) -> Node:
	var packed := load(REGION_SUPPLY_SCENE_PATH) as PackedScene
	if packed == null:
		_expect(false, "RegionSupply runtime scene loads for the lightweight fixture")
		return null
	var controller := packed.instantiate()
	root.add_child(controller)
	var configured := _configure_region_supply_fixture(controller, seed_value)
	if not bool(configured.get("configured", false)):
		_expect(false, "RegionSupply lightweight fixture configures: %s" % str(configured))
		controller.free()
		return null
	return controller


func _configure_region_supply_fixture(controller: Node, seed_value: int) -> Dictionary:
	return controller.call(
		"configure",
		seed_value,
		[
			{
				"region_id": "fixture.region",
				"region_index": 0,
				"display_name": "Fixture Region",
				"terrain": "land",
				"active": true,
			},
		],
		[
			_region_supply_fixture_card("fixture.01.market", "facility_market"),
			_region_supply_fixture_card("fixture.02.factory", "facility_factory"),
			_region_supply_fixture_card("fixture.03.route", "route"),
			_region_supply_fixture_card("fixture.04.factory", "facility_factory"),
			_region_supply_fixture_card("fixture.05.market", "facility_market"),
			_region_supply_fixture_card("fixture.06.route", "route"),
		],
		1
	) as Dictionary


func _region_supply_fixture_card(card_id: String, card_type: String) -> Dictionary:
	return {
		"card_id": card_id,
		"family_id": card_id,
		"card_type": card_type,
		"rank": "I",
		"display_name": card_id,
		"price_cash": 10,
		"target_type": "region",
		"effect_text": "fixture",
		"enabled": true,
		"valid": true,
		"potential_target_exists": true,
		"region_supply_weight": 1,
	}


func _first_supply_card_type(snapshot: Dictionary) -> String:
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	if regions.is_empty():
		return ""
	var slots: Array = (regions[0] as Dictionary).get("slots", []) if (regions[0] as Dictionary).get("slots", []) is Array else []
	if slots.is_empty():
		return ""
	var listing: Dictionary = slots[0] if slots[0] is Dictionary else {}
	var card: Dictionary = listing.get("card", {}) if listing.get("card", {}) is Dictionary else {}
	return String(card.get("card_type", ""))


func _first_forbidden_public_supply_key(value: Variant, path := "public") -> String:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := String(key_variant)
			var normalized := key.to_lower()
			if PUBLIC_SUPPLY_FORBIDDEN_KEYS.has(normalized):
				return "%s/%s" % [path, key]
			for fragment in PUBLIC_SUPPLY_FORBIDDEN_KEY_FRAGMENTS:
				if normalized.contains(fragment):
					return "%s/%s" % [path, key]
			var nested := _first_forbidden_public_supply_key((value as Dictionary).get(key_variant), "%s/%s" % [path, key])
			if nested != "":
				return nested
	elif value is Array:
		for index in range((value as Array).size()):
			var nested := _first_forbidden_public_supply_key((value as Array)[index], "%s/%d" % [path, index])
			if nested != "":
				return nested
	return ""


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _coordinator(main: Node) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")


func _requirement(main: Node, player_index: int, skill: Dictionary) -> Dictionary:
	var coordinator := _coordinator(main)
	if coordinator == null:
		return {}
	var facts := coordinator.call("card_play_world_facts", player_index, skill, {}) as Dictionary
	return coordinator.call("card_play_requirement_status", {"player_index": player_index, "skill": skill}, facts) as Dictionary


func _eligibility(main: Node, player_index: int, skill: Dictionary) -> Dictionary:
	var coordinator := _coordinator(main)
	if coordinator == null:
		return {}
	var facts := coordinator.call("card_play_world_facts", player_index, skill, {}) as Dictionary
	return coordinator.call("evaluate_card_play", {"player_index": player_index, "skill": skill, "evaluation_mode": "rule"}, facts) as Dictionary


func _requirement_fixture(fixture_id: String, kind: String, rank: int) -> Dictionary:
	return {
		"name": "fixture.%s.rank.%d" % [fixture_id, rank],
		"kind": kind,
		"rank": rank,
		"cost": 0,
		"target": "region",
		"target_type": "region",
		"text": "fixture",
	}


func _audit_requests(main: Node) -> Array:
	var result: Array = []
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var names_variant: Variant = main.call("_card_codex_names", "all")
	var names: Array = (names_variant as Array).duplicate() if names_variant is Array else []
	var development_cards_variant: Variant = main.get("city_development_runtime_cards")
	if development_cards_variant is Dictionary:
		for card_name_variant in (development_cards_variant as Dictionary).keys():
			if not names.has(str(card_name_variant)):
				names.append(str(card_name_variant))
	for name_variant in names:
		var card_name := str(name_variant)
		var skill_variant: Variant = main.call("_make_skill", card_name)
		if skill_variant is Dictionary and not (skill_variant as Dictionary).is_empty():
			result.append({"card_name": card_name, "family": str(coordinator.call("card_family_id", card_name)) if coordinator != null else "", "skill": (skill_variant as Dictionary).duplicate(true)})
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card play requirement policy test passed.")
		quit(0)
		return
	push_error("Card play requirement policy test failed:\n- " + "\n- ".join(_failures))
	quit(1)
