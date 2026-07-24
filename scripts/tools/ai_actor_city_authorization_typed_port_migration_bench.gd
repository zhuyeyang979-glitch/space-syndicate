@tool
extends Node

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const PRODUCT_A := "星露莓"
const PRODUCT_B := "磁核榴莲"
const PRODUCT_C := "月壤葡萄"
const PRODUCT_D := "量子蜜瓜"


class AiConsumerWorldProbe:
	extends Node

	func _player_product_flow(_player_index: int, _product_name: String) -> int:
		return 1


var _checks := 0
var _failures: Array[String] = []
var validation_snapshot: Dictionary = {
	"status": "pending",
	"checks": 0,
	"privacy_leaks": 0,
	"hidden_owner_output_deltas": 0,
	"migrated_consumer_count": 0,
}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	add_child(coordinator)
	await get_tree().process_frame
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var rng := coordinator.run_rng_service()
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var route_network := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	var route_bridge := coordinator.get_node_or_null("RouteNetworkWorldBridge") as RouteNetworkWorldBridge
	var ai_bridge := coordinator.get_node_or_null("AiRuntimeWorldBridge") as AiRuntimeWorldBridge
	_check(world != null and ai != null and port != null and rng != null and catalog != null and infrastructure != null and game_session != null and route_network != null and route_bridge != null and ai_bridge != null, "production_composition")
	if not _failures.is_empty():
		_finish()
		return

	var consumer_world := AiConsumerWorldProbe.new()
	coordinator.add_child(consumer_world)
	ai_bridge.bind_world(consumer_world)
	ai_bridge.set_rng_service(rng)
	ai_bridge.set_world_session_state(world)
	ai.set_world_bridge(ai_bridge)
	ai.configure({"ruleset_id": "v0.6"})
	game_session.configure({"ruleset_id": "v0.6"}, {})
	route_bridge.set_region_infrastructure_controller(infrastructure)
	route_network.set_world_bridge(route_bridge)
	route_network.configure(RULESET_PROFILE.debug_snapshot())
	ai.set_route_network_runtime_controller(route_network)
	var started := game_session.begin_session({
		"session_id": "ai-actor-city-authorization-bench",
		"scenario_id": "bench",
		"seed": 73,
		"player_count": 4,
	})
	_check(str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "game_session_running")
	world.restore({"players": _players(catalog), "districts": _districts(), "game_time": 22.0}, true)
	var infrastructure_config := infrastructure.configure(RULESET_PROFILE.debug_snapshot())
	var region_init := infrastructure.initialize_regions(_region_definitions())
	_check(bool(infrastructure_config.get("configured", false)) and bool(region_init.get("initialized", false)), "formal_route_topology_ready")

	var capability := ai.get("_ai_region_knowledge_capability") as AiRegionKnowledgeCapability
	_check(capability != null and port.is_ready(), "opaque_capability_ready")
	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var rows := port.actor_city_authorization_snapshot(capability, 1)
	_check(rows.size() == 5 and TablePresentationPureDataPolicy.is_pure_data(rows), "detached_pure_authorization_rows")
	_check(world.to_save_data() == world_before and rng.capture_plan_checkpoint() == rng_before, "query_zero_world_mutation_and_rng")
	var own := _fact(rows, 0)
	var unknown := _fact(rows, 1)
	var guess := _fact(rows, 2)
	var reveal := _fact(rows, 3)
	var absent := _fact(rows, 4)
	_check(str(own.get("owner_knowledge", "")) == "actor_own" and int(own.get("perceived_owner_index", -1)) == 1, "actor_own")
	_check(str(unknown.get("owner_knowledge", "")) == "public_unknown" and int(unknown.get("perceived_owner_index", 99)) == -1, "public_unknown")
	_check(str(guess.get("owner_knowledge", "")) == "actor_guess" and int(guess.get("perceived_owner_index", -1)) == 3 and int(guess.get("confidence", 0)) == 2, "actor_guess")
	_check(str(reveal.get("owner_knowledge", "")) == "authorized_reveal" and int(reveal.get("perceived_owner_index", -1)) == 3 and bool(reveal.get("authorized_reveal", false)), "authorized_reveal")
	_check(not bool(absent.get("present", true)) and not bool(absent.get("active", true)), "absent_city_fail_closed")
	var serialized := JSON.stringify(rows)
	var privacy_leaks := 0
	for forbidden in ["actual_owner", "hidden_owner", "city_guesses", "players", "districts", "raw_city", "ai_memory", "ai_plan"]:
		if serialized.contains(forbidden):
			privacy_leaks += 1
	_check(privacy_leaks == 0, "privacy_allowlist")
	_check(port.actor_city_authorization_snapshot(AiRegionKnowledgeCapability.new(), 1).is_empty(), "forged_capability_rejected")
	_check(port.actor_city_authorization_snapshot(capability, 0).is_empty() and port.actor_city_authorization_snapshot(capability, 3).is_empty(), "human_and_eliminated_rejected")

	var consumer_before := _consumer_snapshot(ai)
	_check((consumer_before.get("active", []) as Array) == [0], "own_city_consumer")
	_check(int(consumer_before.get("district_overlap", -1)) == 1 and (consumer_before.get("competing", []) as Array) == [1], "rival_overlap_consumers")
	_check(int(consumer_before.get("rival_count", -1)) == 3, "rival_count_consumer")
	_check(int(consumer_before.get("owned_supply", -1)) == 1 and int(consumer_before.get("owned_demand", -1)) == 1, "owned_product_consumers")
	_check(int(consumer_before.get("focus_score", 0)) > 72 and int(consumer_before.get("overlap_score", 0)) > 0, "public_product_score_consumers")
	_check(str(consumer_before.get("own_preferred", "")) == PRODUCT_A and str(consumer_before.get("rival_preferred", "")) == PRODUCT_A, "preferred_product_consumer")

	var changed_districts := world.districts.duplicate(true)
	var changed_city := ((changed_districts[1] as Dictionary).get("city", {}) as Dictionary).duplicate(true)
	changed_city["owner"] = 3
	(changed_districts[1] as Dictionary)["city"] = changed_city
	world.replace_districts(changed_districts, true)
	var hidden_owner_output_deltas := 0
	if _fact(port.actor_city_authorization_snapshot(capability, 1), 1) != unknown:
		hidden_owner_output_deltas += 1
	if _consumer_snapshot(ai) != consumer_before:
		hidden_owner_output_deltas += 1
	_check(hidden_owner_output_deltas == 0, "hidden_owner_invariance")
	var debug := ai.debug_snapshot()
	_check(bool(debug.get("typed_actor_city_authorization_bound", false)), "typed_boundary_debug")
	_check(not bool(debug.get("actor_city_authorization_uses_main", true)) and not bool(debug.get("actor_city_authorization_uses_hidden_owner_truth", true)), "zero_main_and_hidden_truth_debug")
	_check(int(debug.get("actor_city_authorization_migrated_consumer_count", 0)) == 8 and bool(debug.get("actor_city_authorization_mixed_domain_consumers_deferred", false)), "narrow_eight_consumer_scope")
	_finish(privacy_leaks, hidden_owner_output_deltas)


func _consumer_snapshot(ai: AiRuntimeController) -> Dictionary:
	return {
		"active": ai._active_city_indices_for_player(1),
		"district_overlap": ai._district_product_overlap_with_rival_cities(1, 0),
		"competing": ai._competing_city_indices_for_product(1, PRODUCT_A),
		"rival_count": ai._ai_product_rival_city_count(1, PRODUCT_A),
		"owned_supply": ai._ai_owned_city_product_count(1, PRODUCT_A),
		"owned_demand": ai._ai_owned_city_product_count(1, PRODUCT_B, true),
		"focus_score": ai._ai_district_focus_score(1, 0),
		"own_preferred": ai._ai_preferred_product(1),
		"rival_preferred": ai._ai_preferred_product(1, true),
		"overlap_score": ai._ai_city_product_overlap_score(1, 1),
	}


func _players(catalog: RoleCatalogRuntimeService) -> Array:
	var result: Array = []
	for player_index in range(4):
		var role := catalog.definition_at(player_index)
		role["role_index"] = player_index
		var is_ai := player_index > 0
		var player := {
			"id": player_index,
			"name": "Human" if player_index == 0 else "AI-%d" % player_index,
			"is_ai": is_ai,
			"seat_type": "ai" if is_ai else "human",
			"role_index": player_index,
			"role_card": role,
			"eliminated": player_index == 3,
			"eliminated_at": 12.0 if player_index == 3 else -1.0,
			"elimination_reason": "fixture" if player_index == 3 else "",
			"city_guesses": {},
			"city_guess_confidence": {},
			"city_guess_reasons": {},
		}
		if is_ai:
			player["ai_profile"] = {}
			player["ai_memory"] = {
				"economic_focus_product": PRODUCT_A if player_index == 1 else "",
				"economic_focus_score": 100 if player_index == 1 else 0,
				"economic_focus_reason": "bench",
				"economic_focus_cycle": 0,
				"economic_focus_rankings": [],
			}
		if player_index == 1:
			player["city_guesses"] = {2: 3, 3: 3}
			player["city_guess_confidence"] = {2: 2, 3: WorldSessionState.CITY_GUESS_AUTHORIZED_REVEAL}
			player["city_guess_reasons"] = {2: "route", 3: "authorized-probe"}
		elif player_index == 2:
			player["city_guesses"] = {3: 0}
			player["city_guess_confidence"] = {3: 1}
			player["city_guess_reasons"] = {3: "card"}
		result.append(player)
	return result


func _districts() -> Array:
	return [
		{"region_id": "region.000", "name": "Own City", "destroyed": false, "terrain": "land", "products": [PRODUCT_A], "demands": [PRODUCT_D], "neighbors": [1], "city": {"active": true, "owner": 1, "products": [{"name": PRODUCT_A}], "demands": [PRODUCT_B]}},
		{"region_id": "region.001", "name": "Unknown City", "destroyed": false, "terrain": "land", "products": [PRODUCT_B], "demands": [PRODUCT_C], "neighbors": [0, 2], "city": {"active": true, "owner": 2, "products": [{"name": PRODUCT_A}], "demands": [PRODUCT_C]}},
		{"region_id": "region.002", "name": "Guessed City", "destroyed": false, "terrain": "land", "products": [PRODUCT_C], "demands": [PRODUCT_A], "neighbors": [1, 3], "city": {"active": true, "owner": 2, "products": [{"name": PRODUCT_C}], "demands": [PRODUCT_A]}},
		{"region_id": "region.003", "name": "Revealed City", "destroyed": false, "terrain": "land", "products": [PRODUCT_D], "demands": [PRODUCT_A], "neighbors": [2], "city": {"active": true, "owner": 3, "products": [{"name": PRODUCT_D}], "demands": [PRODUCT_A]}},
		{"region_id": "region.004", "name": "No City", "destroyed": false, "terrain": "ocean", "products": [], "demands": [], "neighbors": []},
	]


func _region_definitions() -> Array:
	return [
		{"region_id": "region.000", "terrain_id": "unknown", "neighbor_region_ids": ["region.001"], "legacy_index": 0},
		{"region_id": "region.001", "terrain_id": "unknown", "neighbor_region_ids": ["region.000", "region.002"], "legacy_index": 1},
		{"region_id": "region.002", "terrain_id": "unknown", "neighbor_region_ids": ["region.001", "region.003"], "legacy_index": 2},
		{"region_id": "region.003", "terrain_id": "unknown", "neighbor_region_ids": ["region.002"], "legacy_index": 3},
		{"region_id": "region.004", "terrain_id": "unknown", "neighbor_region_ids": [], "legacy_index": 4},
	]


func _fact(rows: Array, district_index: int) -> Dictionary:
	for row_variant in rows:
		if row_variant is Dictionary and int((row_variant as Dictionary).get("district_index", -1)) == district_index:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _check(condition: bool, check_id: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(check_id)


func _finish(privacy_leaks := 0, hidden_owner_output_deltas := 0) -> void:
	if _failures.is_empty():
		validation_snapshot = {
			"status": "PASS",
			"checks": _checks,
			"privacy_leaks": privacy_leaks,
			"hidden_owner_output_deltas": hidden_owner_output_deltas,
			"migrated_consumer_count": 8,
		}
		print("AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION_BENCH|status=PASS|checks=%d|privacy_leaks=0|hidden_owner_output_deltas=0|migrated_consumers=8" % _checks)
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
		else:
			print("AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION_BENCH|event=awaiting_mcp_stop")
		return
	validation_snapshot = {
		"status": "FAIL",
		"checks": _checks,
		"failures": _failures.duplicate(),
		"privacy_leaks": privacy_leaks,
		"hidden_owner_output_deltas": hidden_owner_output_deltas,
		"migrated_consumer_count": 8,
	}
	push_error("AI actor city authorization Bench failed: %s" % ", ".join(_failures))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
