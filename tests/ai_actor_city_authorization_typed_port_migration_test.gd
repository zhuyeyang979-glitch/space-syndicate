extends SceneTree

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


const MIGRATED_FUNCTIONS := [
	"_district_product_overlap_with_rival_cities",
	"_active_city_indices_for_player",
	"_competing_city_indices_for_product",
	"_ai_product_rival_city_count",
	"_ai_owned_city_product_count",
	"_ai_district_focus_score",
	"_ai_preferred_product",
	"_ai_city_product_overlap_score",
]

var _checks := 0
var _failures: Array[String] = []
var _city_inference_signal_count := 0


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
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var route_network := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	var route_bridge := coordinator.get_node_or_null("RouteNetworkWorldBridge") as RouteNetworkWorldBridge
	var ai_bridge := coordinator.get_node_or_null("AiRuntimeWorldBridge") as AiRuntimeWorldBridge
	_expect(world != null and ai != null and port != null and rng != null and catalog != null and infrastructure != null and game_session != null and route_network != null and route_bridge != null and ai_bridge != null, "production composition exposes world, session, AI, RNG, catalog, infrastructure, route network, route bridge, AI bridge, and the existing region port")
	if world == null or ai == null or port == null or rng == null or catalog == null or infrastructure == null or game_session == null or route_network == null or route_bridge == null or ai_bridge == null:
		_finish(coordinator)
		return

	world.city_inference_changed.connect(_on_city_inference_changed)
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
	var started := game_session.begin_session({"session_id": "ai-actor-city-authorization-focused", "scenario_id": "focused", "seed": 73, "player_count": 4})
	_expect(str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "fixture starts through GameSession authority")
	world.restore({
		"players": _players(catalog),
		"districts": _districts(),
		"game_time": 22.0,
	}, true)
	var infrastructure_config := infrastructure.configure(RULESET_PROFILE.debug_snapshot())
	_expect(bool(infrastructure_config.get("configured", false)), "formal RegionInfrastructure configures from the v0.6 ruleset")
	var region_init := infrastructure.initialize_regions(_region_definitions())
	_expect(bool(region_init.get("initialized", false)) and int(region_init.get("region_count", 0)) == 5, "formal RegionInfrastructure topology initializes all fixture regions")

	var capability := ai.get("_ai_region_knowledge_capability") as AiRegionKnowledgeCapability
	_expect(capability != null and port.is_ready(), "formal composition binds the existing opaque region capability")

	var world_before := world.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var ai_before := ai.debug_snapshot()
	var debug_before := port.debug_snapshot()
	var rows := port.actor_city_authorization_snapshot(capability, 1)
	var debug_after := port.debug_snapshot()
	_expect(rows.size() == 5, "authorization snapshot preserves one row per district")
	_expect(TablePresentationPureDataPolicy.is_pure_data(rows), "authorization snapshot is detached pure data")
	_expect(int(debug_after.get("private_query_count", -1)) == int(debug_before.get("private_query_count", -1)) + 1, "successful actor authorization query records one diagnostic query")
	_expect(int(debug_after.get("rejected_query_count", -1)) == int(debug_before.get("rejected_query_count", -1)), "successful query records no rejection")
	_expect(world.to_save_data() == world_before, "authorization query mutates no WorldSession state")
	_expect(rng.capture_plan_checkpoint() == rng_before, "authorization query consumes zero RNG")
	_expect(ai.debug_snapshot() == ai_before, "authorization query mutates no AI journal or policy state")
	_expect(_city_inference_signal_count == 0, "authorization query emits no inference mutation signal")

	for district_index in range(rows.size()):
		var row := rows[district_index] as Dictionary
		_expect(row.keys() == AiRegionKnowledgeQueryPort.ACTOR_CITY_AUTHORIZATION_FACT_KEYS, "authorization row %d uses the strict allowlist" % district_index)
		_expect(int(row.get("schema_version", 0)) == 1 and str(row.get("visibility_scope", "")) == "actor_private", "authorization row %d declares schema and privacy scope" % district_index)
		_expect(int(row.get("actor_index", -1)) == 1 and int(row.get("district_index", -1)) == district_index, "authorization row %d binds actor and district" % district_index)
		_expect(str(row.get("owner_revision", "")).length() == 64 and str(row.get("fingerprint", "")).length() == 64, "authorization row %d carries stable revisions" % district_index)

	var own := _fact(rows, 0)
	var unknown := _fact(rows, 1)
	var guess := _fact(rows, 2)
	var reveal := _fact(rows, 3)
	var absent := _fact(rows, 4)
	_expect(str(own.get("owner_knowledge", "")) == "actor_own" and int(own.get("perceived_owner_index", -1)) == 1, "own city exposes exact actor-own authorization")
	_expect(int(own.get("confidence", -1)) == 0 and not bool(own.get("authorized_reveal", true)), "actor-own authorization is not represented as a guess or reveal")
	_expect(str(unknown.get("owner_knowledge", "")) == "public_unknown" and int(unknown.get("perceived_owner_index", 99)) == -1, "foreign city without inference hides true owner")
	_expect(str(unknown.get("reason_kind", "")) == "none" and str(unknown.get("reason_id", "x")).is_empty(), "unknown owner carries no private reason")
	_expect(str(guess.get("owner_knowledge", "")) == "actor_guess" and int(guess.get("perceived_owner_index", -1)) == 3, "actor guess exposes only the actor's hypothesis")
	_expect(int(guess.get("confidence", 0)) == 2 and str(guess.get("reason_id", "")) == "route" and str(guess.get("reason_kind", "")) == "manual", "manual guess preserves confidence and reason")
	_expect(str(reveal.get("owner_knowledge", "")) == "authorized_reveal" and int(reveal.get("perceived_owner_index", -1)) == 3, "authorized reveal exposes the approved owner")
	_expect(int(reveal.get("confidence", 0)) == WorldSessionState.CITY_GUESS_AUTHORIZED_REVEAL and bool(reveal.get("authorized_reveal", false)), "authorized reveal preserves its sentinel")
	_expect(str(reveal.get("reason_id", "")) == "authorized-probe" and str(reveal.get("reason_kind", "")) == "public_reveal", "authorized reveal preserves its source reason")
	_expect(not bool(absent.get("present", true)) and not bool(absent.get("active", true)) and int(absent.get("perceived_owner_index", 99)) == -1, "district without a city fails closed")
	_expect(port.actor_city_authorization_for_district(capability, 1, 2) == guess, "single-district API returns the same strict fact")
	_expect(port.actor_city_authorization_for_district(capability, 1, 99).is_empty(), "invalid district lookup fails closed")

	var serialized := JSON.stringify(rows)
	for forbidden in ["actual_owner", "hidden_owner", "city_guesses", "players", "districts", "raw_city", "ai_memory", "ai_plan"]:
		_expect(not serialized.contains(forbidden), "authorization schema excludes %s" % forbidden)

	var detached := rows.duplicate(true)
	(detached[2] as Dictionary)["perceived_owner_index"] = 0
	_expect(int(_fact(port.actor_city_authorization_snapshot(capability, 1), 2).get("perceived_owner_index", -1)) == 3, "authorization rows are detached from returned mutations")
	var repeated := port.actor_city_authorization_snapshot(capability, 1)
	_expect(repeated == rows, "unchanged actor authority yields byte-equivalent authorization facts")

	var actor_two_rows := port.actor_city_authorization_snapshot(capability, 2)
	_expect(str(_fact(actor_two_rows, 2).get("owner_knowledge", "")) == "actor_own", "second actor sees only its own city as exact")
	_expect(str(_fact(actor_two_rows, 3).get("owner_knowledge", "")) == "actor_guess" and int(_fact(actor_two_rows, 3).get("perceived_owner_index", -1)) == 0, "second actor sees its own private guess")
	_expect(int(_fact(actor_two_rows, 3).get("perceived_owner_index", -1)) != int(reveal.get("perceived_owner_index", -1)), "actors do not share private guesses or reveals")

	var rejected_before := int(port.debug_snapshot().get("rejected_query_count", 0))
	_expect(port.actor_city_authorization_snapshot(AiRegionKnowledgeCapability.new(), 1).is_empty(), "forged capability fails closed")
	_expect(port.actor_city_authorization_snapshot(capability, 0).is_empty(), "human actor fails closed")
	_expect(port.actor_city_authorization_snapshot(capability, 3).is_empty(), "eliminated AI actor fails closed")
	_expect(port.actor_city_authorization_snapshot(capability, 99).is_empty(), "out-of-range actor fails closed")
	_expect(port.actor_city_authorization_snapshot(null, 1).is_empty(), "null capability fails closed")
	_expect(int(port.debug_snapshot().get("rejected_query_count", 0)) == rejected_before + 5, "each rejected query is recorded without gameplay mutation")
	_expect(world.to_save_data() == world_before and rng.capture_plan_checkpoint() == rng_before and _city_inference_signal_count == 0, "rejected queries leave world, RNG, and signals unchanged")

	var consumer_before := _consumer_snapshot(ai)

	_expect((consumer_before.get("active", []) as Array) == [0], "own-city enumeration uses actor-own authorization")
	_expect(int(consumer_before.get("district_overlap", -1)) == 1, "rival overlap combines authorization with public city products")
	_expect((consumer_before.get("competing", []) as Array) == [1], "competing city list excludes the actor's own city without identifying rivals")
	_expect(int(consumer_before.get("rival_count", -1)) == 3, "rival product count includes unknown foreign cities from public products and demands")
	_expect(int(consumer_before.get("owned_supply", -1)) == 1 and int(consumer_before.get("owned_demand", -1)) == 1, "owned product counts preserve public supply and demand behavior")
	_expect(int(consumer_before.get("focus_score", 0)) > 72, "district focus score preserves public district and city product terms")
	_expect(str(consumer_before.get("own_preferred", "")) == PRODUCT_A and str(consumer_before.get("rival_preferred", "")) == PRODUCT_A, "preferred product keeps actor-own and foreign candidate behavior")
	_expect(int(consumer_before.get("overlap_score", 0)) > 0, "city product overlap keeps the public product score")

	var hidden_owner_change := world.districts.duplicate(true)
	var changed_city := ((hidden_owner_change[1] as Dictionary).get("city", {}) as Dictionary).duplicate(true)
	changed_city["owner"] = 3
	(hidden_owner_change[1] as Dictionary)["city"] = changed_city
	world.replace_districts(hidden_owner_change, true)
	var unknown_after := _fact(port.actor_city_authorization_snapshot(capability, 1), 1)
	_expect(unknown_after == unknown, "changing hidden foreign truth leaves unknown authorization byte-equivalent")
	_expect(_consumer_snapshot(ai) == consumer_before, "changing hidden foreign truth leaves all eight migrated consumers unchanged")
	world.restore({"players": _players(catalog), "districts": _districts(), "game_time": 22.0}, true)

	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	for function_name in MIGRATED_FUNCTIONS:
		var body := _function_body(ai_source, function_name)
		_expect(not body.is_empty(), "%s remains present" % function_name)
		_expect(not body.contains("_district_city("), "%s has zero raw city fallback" % function_name)
		_expect(not body.contains("districts["), "%s has zero whole-district indexing" % function_name)
		_expect(not body.contains(".get(\"owner\""), "%s has zero hidden owner read" % function_name)
		_expect(not body.contains("_call_world"), "%s has zero Main fallback" % function_name)
	_expect(ai_source.count("_district_city(") == 51, "raw city calls decrease from 59 to 50 without hiding deferred consumers")
	_expect(_token_count(ai_source, "districts") <= 75, "whole districts tokens decrease from 80 to at most 75")
	_expect(ai_source.count("_call_world") == 39, "generic world token count does not increase")

	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	_expect(coordinator_scene.count("AiRegionKnowledgeQueryPort.tscn") == 1, "production composition retains exactly one region port")
	_expect(registry_scene.count("section_id = ") == 19, "Save Registry remains at 19 sections")
	_expect(not registry_scene.contains("actor_city_authorization"), "authorization projection creates no save owner or section")
	var debug := ai.debug_snapshot()
	_expect(bool(debug.get("typed_actor_city_authorization_bound", false)), "AI debug reports the typed actor-city boundary")
	_expect(not bool(debug.get("actor_city_authorization_uses_main", true)) and not bool(debug.get("actor_city_authorization_uses_hidden_owner_truth", true)), "AI debug reports zero Main and hidden-truth use")
	_expect(int(debug.get("actor_city_authorization_migrated_consumer_count", 0)) == 8 and bool(debug.get("actor_city_authorization_mixed_domain_consumers_deferred", false)), "AI debug records the narrow eight-consumer scope")

	var bound_port := ai.get("_ai_region_knowledge_query_port") as AiRegionKnowledgeQueryPort
	ai.set("_ai_region_knowledge_query_port", null)
	_expect(ai._actor_city_authorization_snapshot(1).is_empty(), "missing typed port returns no authorization snapshot")
	_expect(ai._active_city_indices_for_player(1).is_empty(), "missing typed port does not fall back to raw own-city truth")
	_expect(ai._district_product_overlap_with_rival_cities(1, 0) == 0 and ai._ai_product_rival_city_count(1, PRODUCT_A) == 0, "missing typed port fails rival product consumers closed")
	_expect(ai._ai_district_focus_score(1, 0) == 0 and ai._ai_city_product_overlap_score(1, 1) == 0, "missing typed port fails public combination consumers closed")
	ai.set("_ai_region_knowledge_query_port", bound_port)

	_finish(coordinator)


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
			"name": "玩家%d" % (player_index + 1),
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
				"economic_focus_reason": "fixture",
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
		{"region_id": "region.000", "name": "己方城", "destroyed": false, "terrain": "land", "products": [PRODUCT_A], "demands": [PRODUCT_D], "neighbors": [1], "city": {"active": true, "owner": 1, "products": [{"name": PRODUCT_A}], "demands": [PRODUCT_B]}},
		{"region_id": "region.001", "name": "未知城", "destroyed": false, "terrain": "land", "products": [PRODUCT_B], "demands": [PRODUCT_C], "neighbors": [0, 2], "city": {"active": true, "owner": 2, "products": [{"name": PRODUCT_A}], "demands": [PRODUCT_C]}},
		{"region_id": "region.002", "name": "猜测城", "destroyed": false, "terrain": "land", "products": [PRODUCT_C], "demands": [PRODUCT_A], "neighbors": [1, 3], "city": {"active": true, "owner": 2, "products": [{"name": PRODUCT_C}], "demands": [PRODUCT_A]}},
		{"region_id": "region.003", "name": "揭示城", "destroyed": false, "terrain": "land", "products": [PRODUCT_D], "demands": [PRODUCT_A], "neighbors": [2], "city": {"active": true, "owner": 3, "products": [{"name": PRODUCT_D}], "demands": [PRODUCT_A]}},
		{"region_id": "region.004", "name": "无城区域", "destroyed": false, "terrain": "ocean", "products": [], "demands": [], "neighbors": []},
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


func _function_body(source: String, function_name: String) -> String:
	var marker := "func %s(" % function_name
	var start := source.find(marker)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _token_count(source: String, token: String) -> int:
	var regex := RegEx.new()
	regex.compile("\\b%s\\b" % token)
	return regex.search_all(source).size()


func _on_city_inference_changed(_viewer_index: int, _region_id: String, _owner_revision: String) -> void:
	_city_inference_signal_count += 1


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(coordinator: Node) -> void:
	if coordinator != null:
		coordinator.queue_free()
	await process_frame
	if _failures.is_empty():
		print("AI actor city authorization typed-port migration passed (%d checks)." % _checks)
		print("AI_ACTOR_CITY_AUTHORIZATION_TYPED_PORT_MIGRATION_COMPLETE")
		quit(0)
		return
	for failure in _failures:
		push_error("AI actor city authorization migration failure: %s" % failure)
	push_error("AI actor city authorization typed-port migration failed (%d/%d)." % [_failures.size(), _checks])
	quit(1)