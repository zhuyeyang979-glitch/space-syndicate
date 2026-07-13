extends SceneTree

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")

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
	_check_fixed_region_supply(main)
	root.remove_child(main)
	main.queue_free()
	_finish()


func _check_catalog_policy(main: Node) -> void:
	var coordinator := _coordinator(main)
	_expect(coordinator != null and coordinator.has_method("audit_card_play_requirements"), "Coordinator exposes the authoritative card requirement audit")
	if coordinator == null:
		return
	var report := coordinator.call("audit_card_play_requirements", _audit_requests(main)) as Dictionary
	_expect(bool(report.get("ok", false)), "card requirement audit passes: %s" % str(report.get("issues", [])))
	_expect(int(report.get("rank_one_count", 0)) >= 80, "requirement audit covers the real rank-I catalog")
	_expect(int(report.get("rank_one_free_count", 0)) * 2 > int(report.get("rank_one_count", 0)), "most rank-I cards have no GDP play gate")
	_expect(int(report.get("city_development_card_count", 0)) > 0, "generated city-development cards are audited")
	_expect((report.get("standard_gradient_percent", []) as Array) == [0, 15, 25, 35], "standard I-IV GDP gate is 0/15/25/35 percent")
	_expect((report.get("high_impact_gradient_percent", []) as Array) == [10, 20, 30, 40], "high-impact I-IV GDP gate is 10/20/30/40 percent")
	var development := main.call("_make_skill", "活体芯片生产园1") as Dictionary
	if not development.is_empty():
		var development_requirement := _requirement(main, 0, development)
		_expect(int(development_requirement.get("required_share_percent", -1)) == 0, "city development has no GDP play gate")
		_expect(String(development_requirement.get("requirement_text", "")) == "条件：无", "city development condition text stays concise")
	var normal_rank_one := main.call("_make_skill", "城市融资1") as Dictionary
	var normal_rank_two := main.call("_make_skill", "城市融资2") as Dictionary
	var high_impact := main.call("_make_skill", "星链拆解1") as Dictionary
	_expect(int(_requirement(main, 0, normal_rank_one).get("required_share_percent", -1)) == 0, "normal rank-I card is condition-free")
	_expect(int(_requirement(main, 0, normal_rank_two).get("required_share_percent", -1)) == 15, "normal rank-II card requires 15 percent regional GDP share")
	_expect(int(_requirement(main, 0, high_impact).get("required_share_percent", -1)) == 10, "high-impact rank-I interaction retains a 10 percent GDP gate")
	var card_catalog_coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(card_catalog_coordinator != null and not bool(card_catalog_coordinator.call("card_exists", "异种置换1")), "异种置换 is absent from the playable catalog")


func _check_region_share_boundary(main: Node) -> void:
	var districts: Array = (main.get("districts") as Array).duplicate(true)
	var players: Array = main.get("players") as Array
	if districts.is_empty() or players.size() < 2:
		_expect(false, "share boundary fixture has a district and two players")
		return
	var district := districts[0] as Dictionary
	district["destroyed"] = false
	district["damage"] = 0
	district["panic"] = 0
	var exact_project := PROJECT_STATE.create_project(0, "活体芯片", "production", 0, 3, 1)
	exact_project = PROJECT_STATE.contribute(exact_project, 1, 17, 2)
	district["city"] = {
		"owner": 1,
		"active": true,
		"revenue_bonus": 200,
		"products": [],
		"demands": [],
		"trade_routes": [],
		"projects": [exact_project],
	}
	districts[0] = district
	main.set("districts", districts)
	main.set("selected_district", 0)
	var rank_two := main.call("_make_skill", "城市融资2") as Dictionary
	var exact_status := _requirement(main, 0, rank_two)
	_expect(int(exact_status.get("current_share_basis_points", -1)) == 1500, "regional GDP share uses exact basis points")
	_expect(bool(exact_status.get("requirement_satisfied", false)), "a share exactly equal to the threshold is playable")
	var below_project := PROJECT_STATE.create_project(0, "活体芯片", "production", 0, 2, 1)
	below_project = PROJECT_STATE.contribute(below_project, 1, 18, 2)
	district = (main.get("districts") as Array)[0] as Dictionary
	var city := district.get("city", {}) as Dictionary
	city["projects"] = [below_project]
	district["city"] = city
	districts = (main.get("districts") as Array).duplicate(true)
	districts[0] = district
	main.set("districts", districts)
	var below_status := _requirement(main, 0, rank_two)
	_expect(not bool(below_status.get("requirement_satisfied", true)), "a share below the threshold is blocked")
	_expect(not bool(_eligibility(main, 0, rank_two).get("allowed", true)), "authoritative play validation enforces the GDP share gate")
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
	var skill := main.call("_make_skill", "城市融资2") as Dictionary
	var candidate := controller.call("_ai_play_requirement_metadata", 0, skill, 0) as Dictionary
	candidate["policy_kind"] = "city_revenue_boost"
	candidate["score"] = 100
	var training := controller.call("_ai_candidate_training_view", candidate) as Dictionary
	var decision := controller.call("_ai_card_decision_metadata", candidate, -1, 0) as Dictionary
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
	var ai_player := (main.get("players") as Array)[1] as Dictionary
	var samples := ((ai_player.get("ai_memory", {}) as Dictionary).get("decision_samples", []) as Array)
	_expect(not samples.is_empty(), "AI decision metadata writes a training sample")
	if not samples.is_empty():
		var sample := samples[samples.size() - 1] as Dictionary
		_expect(String(sample.get("kind", "")) == "匿名出牌", "candidate card kind cannot overwrite the AI decision envelope kind")
		_expect(String(sample.get("policy_kind", "")) == "city_revenue_boost", "candidate policy kind remains trainable metadata")


func _check_fixed_region_supply(main: Node) -> void:
	var diagnostics := _diagnostics(main)
	_expect(diagnostics != null, "Coordinator exposes reserved region supply diagnostics")
	if diagnostics == null:
		return
	var report := diagnostics.district_reserved_supply_audit()
	_expect((report.get("issues", []) as Array).is_empty(), "every region has the required reserved slots and 4-5 cards: %s" % str(report.get("issues", [])))
	_expect(int(report.get("development_slot_count", 0)) == int(report.get("district_count", -1)), "every region has exactly one local-product city-development card")
	_expect(int(report.get("monster_slot_count", 0)) == int(report.get("district_count", -1)), "every region has exactly one fixed monster card")
	if int(report.get("monster_unique_capacity_shortfall", 0)) == 0:
		_expect((report.get("duplicate_monster_cards", []) as Array).is_empty(), "fixed monster cards do not repeat while catalog capacity is sufficient")


func _coordinator(main: Node) -> Node:
	return main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")


func _diagnostics(main: Node) -> GameplayBalanceDiagnosticsRuntimeService:
	var coordinator := _coordinator(main)
	return coordinator.gameplay_balance_diagnostics_service() if coordinator is GameRuntimeCoordinator else null


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
