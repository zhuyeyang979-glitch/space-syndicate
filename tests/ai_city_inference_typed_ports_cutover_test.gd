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
	var actor_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var region_port := coordinator.get_node_or_null("AiRegionKnowledgeQueryPort") as AiRegionKnowledgeQueryPort
	var command_port := coordinator.get_node_or_null("AiCityInferenceCommandPort") as AiCityInferenceCommandPort
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(world != null and ai != null and actor_port != null and region_port != null and command_port != null and game_session != null, "production composition owns the three typed AI ports and existing GameSession authority")
	_expect(actor_port.is_ready() and region_port.is_ready(), "typed AI ports bind authoritative production owners")
	var ai_debug := ai.debug_snapshot()
	_expect(bool(ai_debug.get("typed_actor_state_bound", false)) and bool(ai_debug.get("typed_region_knowledge_bound", false)) and bool(ai_debug.get("typed_city_inference_command_bound", false)), "AiRuntimeController receives typed port capabilities")
	var policy_groups: Dictionary = ai.policy_profile.call("parameter_groups") if ai.policy_profile != null else {}
	var policy_summary: Dictionary = ai.policy_profile.call("resource_summary") if ai.policy_profile != null else {}
	var city_inference_policy: Dictionary = policy_groups.get("city_inference", {}) if policy_groups.get("city_inference", {}) is Dictionary else {}
	_expect(int(policy_summary.get("tunable_count", 0)) == 38 and int(policy_summary.get("group_count", 0)) == 8 and int(policy_summary.get("personality_count", 0)) == 6, "AI policy Resource summary includes all 38 tunables, eight groups, and six personalities")
	_expect(city_inference_policy == {
		"warehouse_stockpile_count_pressure": 34,
		"warehouse_stockpile_unit_pressure": 8,
		"warehouse_stockpile_product_pressure": 10,
	}, "AI policy Resource preserves the three migrated warehouse-pressure weights")
	var capability: AiRegionKnowledgeCapability
	var capability_b: AiRegionKnowledgeCapability
	var capability_c: AiRegionKnowledgeCapability
	game_session.configure({"ruleset_id": "v0.6"}, {})
	var started_session := game_session.begin_session({"session_id": "ai-city-inference-session-a", "scenario_id": "focused", "seed": 17, "player_count": 4})
	_expect(str(started_session.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING, "focused fixture starts through the existing GameSession authority")

	world.restore({
		"players": [
			_player("人类", false, "HUMAN_PRIVATE"),
			_player("AI-A", true, "AI_A_PRIVATE"),
			_player("AI-B", true, "AI_B_PRIVATE"),
			_player("AI-C", true, "AI_C_PRIVATE"),
		],
		"districts": [
			_district("region.000", "自有港", 1, "生命", "能源", 20, 0, 0, 0),
			_district("region.001", "环城港", 3, "能源", "生命", 40, 1, 1, 2),
			_district("region.002", "对手城", 2, "信息", "能源", 10, 0, 0, 0),
			{
				"region_id": "region.003",
				"name": "已毁城市",
				"destroyed": true,
				"city": {"active": true, "owner": 2, "products": [{"name": "能源"}], "demands": ["生命"]},
			},
		],
		"game_time": 15.0,
	}, true)
	var capabilities := ai.get("_ai_region_knowledge_capabilities") as Dictionary
	capability = capabilities.get(1) as AiRegionKnowledgeCapability
	capability_b = capabilities.get(2) as AiRegionKnowledgeCapability
	capability_c = capabilities.get(3) as AiRegionKnowledgeCapability
	_expect(
		capability != null
			and capability_b != null
			and capability_c != null
			and capability != capability_b
			and capability != capability_c
			and capability_b != capability_c,
		"composition issues one distinct region capability per AI seat"
	)
	var roster := world.players.duplicate(true)
	var capability_before_elimination := capability
	(roster[3] as Dictionary)["eliminated"] = true
	world.replace_players(roster, true)
	capabilities = ai.get("_ai_region_knowledge_capabilities") as Dictionary
	capability = capabilities.get(1) as AiRegionKnowledgeCapability
	capability_b = capabilities.get(2) as AiRegionKnowledgeCapability
	capability_c = capabilities.get(3) as AiRegionKnowledgeCapability
	var eliminated_command := command_port.submit_guess(capability_c, "test:ai-city-inference:eliminated", 3, "region.002", 1, 2, "intuition", world.city_inference_owner_revision(3))
	_expect(
		not ai._typed_ai_player_indices().has(3)
			and not bool(eliminated_command.get("applied", true))
			and region_port.actor_intelligence_snapshot(
				capability_before_elimination,
				1
			).is_empty()
			and not region_port.actor_intelligence_snapshot(
				capability,
				1
			).is_empty(),
		"roster replacement reissues actor-scoped tokens and excludes eliminated commands"
	)
	var capability_before_reactivation := capability
	(roster[3] as Dictionary)["eliminated"] = false
	world.replace_players(roster, true)
	capabilities = ai.get("_ai_region_knowledge_capabilities") as Dictionary
	capability = capabilities.get(1) as AiRegionKnowledgeCapability
	capability_b = capabilities.get(2) as AiRegionKnowledgeCapability
	capability_c = capabilities.get(3) as AiRegionKnowledgeCapability
	_expect(
		capability != capability_before_reactivation
			and region_port.actor_intelligence_snapshot(
				capability_before_reactivation,
				1
			).is_empty(),
		"same roster with a changed seat lifecycle revokes prior region tokens"
	)
	var seeded := world.set_city_owner_guess(1, "region.001", 2, 2, "card", world.city_inference_owner_revision(1))
	_expect(bool(seeded.get("applied", false)), "fixture seeds AI-A private inference through WorldSessionState")
	game_session.pause_session()
	var paused_command := command_port.submit_guess(capability, "test:ai-city-inference:paused", 1, "region.001", 3, 2, "intuition", world.city_inference_owner_revision(1))
	_expect(not bool(paused_command.get("applied", true)), "typed command fails closed outside the running GameSession lifecycle")
	game_session.resume_session()

	var rng_before: Dictionary = rng.capture_plan_checkpoint() if rng != null else {}
	var players_before := world.players.duplicate(true)
	var mutation_before := int(world.debug_snapshot().get("city_inference_mutation_count", -1))
	var snapshot_a := region_port.actor_intelligence_snapshot(capability, 1)
	var snapshot_b := region_port.actor_intelligence_snapshot(capability_b, 2)
	var actor_a_own_city := (_region(snapshot_a, "region.000").get("city", {}) as Dictionary)
	var actor_a_rival_city := (_region(snapshot_a, "region.001").get("city", {}) as Dictionary)
	var actor_b_own_city := (_region(snapshot_b, "region.002").get("city", {}) as Dictionary)
	var public_rival_city := (region_port.public_region(1).get("city", {}) as Dictionary)
	_expect(
		actor_a_own_city.has("warehouse_stockpile_count")
			and actor_a_own_city.has("warehouse_stockpile_units")
			and actor_a_own_city.has("warehouse_stockpile_products")
			and actor_b_own_city.has("warehouse_stockpile_count")
			and not actor_a_rival_city.has("warehouse_stockpile_count")
			and not actor_a_rival_city.has("warehouse_stockpile_units")
			and not actor_a_rival_city.has("warehouse_stockpile_products")
			and not public_rival_city.has("warehouse_stockpile_count")
			and not public_rival_city.has("warehouse_stockpile_units")
			and not public_rival_city.has("warehouse_stockpile_products"),
		"region projection exposes warehouse facts only to the owning AI actor"
	)
	_expect(int(actor_a_own_city.get("trade_route_count", 0)) == 1 and (actor_a_own_city.get("active_trade_route_products", []) as Array).has("生命") and (actor_a_rival_city.get("disrupted_trade_route_products", []) as Array).has("能源"), "region projection exposes only public route count, product, and disruption summaries")
	_expect(not snapshot_a.is_empty() and str(snapshot_a.get("visibility_scope", "")) == "actor_private", "authorized AI receives an actor-private region snapshot")
	_expect(snapshot_b.get("regions", []) is Array and not (snapshot_b.get("regions", []) as Array).is_empty(), "second AI receives its own detached region snapshot")
	var cross_actor_snapshot := region_port.actor_intelligence_snapshot(capability, 2)
	var cross_actor_command := command_port.submit_guess(
		capability,
		"test:ai-city-inference:cross-actor",
		2,
		"region.001",
		1,
		2,
		"intuition",
		world.city_inference_owner_revision(2)
	)
	_expect(
		cross_actor_snapshot.is_empty()
			and not bool(cross_actor_command.get("applied", true)),
		"AI-A capability cannot query or mutate AI-B private inference"
	)
	_expect(world.players == players_before and int(world.debug_snapshot().get("city_inference_mutation_count", -1)) == mutation_before, "typed queries perform zero world mutation")
	_expect(rng == null or rng.capture_plan_checkpoint() == rng_before, "typed queries consume zero RNG")

	var region_a := _region(snapshot_a, "region.001")
	var region_b := _region(snapshot_b, "region.001")
	var city_a: Dictionary = region_a.get("city", {}) if region_a.get("city", {}) is Dictionary else {}
	var city_b: Dictionary = region_b.get("city", {}) if region_b.get("city", {}) is Dictionary else {}
	_expect(int(city_a.get("owner", -1)) == 2 and str(city_a.get("owner_knowledge", "")) == "actor_guess", "AI-A sees only its own guess rather than hidden owner truth")
	_expect(int(city_b.get("owner", -1)) == -1 and str(city_b.get("owner_knowledge", "")) == "public_unknown", "AI-B cannot see AI-A private inference")
	_expect(not JSON.stringify(snapshot_a).contains("AI_B_PRIVATE") and not JSON.stringify(snapshot_a).contains("AI_C_PRIVATE"), "actor snapshot excludes rival private markers")
	_expect(not JSON.stringify(snapshot_a).contains("CLUE_PRIVATE"), "public clue projection drops arbitrary pure-data private keys")
	_expect(not JSON.stringify(actor_port.public_players_snapshot()).contains("PRIVATE"), "public player facts exclude cash, hand, guesses, and AI memory")

	var detached := snapshot_a.duplicate(true)
	(detached.get("regions", []) as Array)[1]["name"] = "MUTATED_COPY"
	_expect(str(_region(region_port.actor_intelligence_snapshot(capability, 1), "region.001").get("name", "")) == "环城港", "query snapshots are detached pure data")
	_expect(TablePresentationPureDataPolicy.is_pure_data(snapshot_a), "query snapshot recursively contains pure data only")

	var entries := ai._intel_city_guess_entries(1, 12)
	var entry := _entry(entries, 1)
	_expect(not entry.is_empty() and str(entry.get("name", "")) == "环城港", "AI city inference consumes the typed region projection")
	_expect(int(entry.get("guess", -1)) == 2 and int(entry.get("confidence", 0)) == 2 and str(entry.get("latest_clue", "")).contains("能源"), "typed query preserves guess, confidence, and public clue semantics")
	_expect(
		int(entry.get("priority", -1)) == 54
			and int(entry.get("warehouse_pressure", -1)) == 0,
		"PRIVACY_CORRECTION removes rival warehouse pressure without changing public clues"
	)
	_expect(_entry(entries, 3).is_empty(), "typed city inference excludes destroyed regions even when a stale city active flag remains true")

	var owner_revision := str(snapshot_a.get("owner_revision", ""))
	var pre_command_save := world.to_save_data()
	var command_id := "test:ai-city-inference:exact-once"
	var command_mutations_before := int(world.debug_snapshot().get("city_inference_mutation_count", 0))
	var accepted := command_port.submit_guess(capability, command_id, 1, "region.001", 3, 3, "product", owner_revision)
	var replay := command_port.submit_guess(capability, command_id, 1, "region.001", 3, 3, "product", owner_revision)
	var conflict := command_port.submit_guess(capability, command_id, 1, "region.001", 2, 1, "route", owner_revision)
	_expect(bool(accepted.get("applied", false)) and bool(accepted.get("changed", false)), "typed AI command delegates one authoritative city inference mutation")
	_expect(bool(replay.get("applied", false)) and bool(replay.get("idempotent_replay", false)), "same command ID and payload returns the original receipt")
	_expect(not bool(conflict.get("applied", true)) and str(conflict.get("reason_code", "")) == "ai_city_inference_command_id_conflict", "same command ID with different payload fails closed")
	_expect(int(world.debug_snapshot().get("city_inference_mutation_count", 0)) == command_mutations_before + 1, "duplicate and conflicting commands create zero duplicate mutation")

	var stale := command_port.submit_guess(capability, "test:ai-city-inference:stale", 1, "region.001", 2, 2, "intuition", owner_revision)
	var forged := command_port.submit_guess(AiRegionKnowledgeCapability.new(), "test:ai-city-inference:forged", 1, "region.001", 2, 2, "intuition", world.city_inference_owner_revision(1))
	var human := command_port.submit_guess(capability, "test:ai-city-inference:human", 0, "region.001", 2, 2, "intuition", world.city_inference_owner_revision(0))
	_expect(not bool(stale.get("applied", true)) and str(stale.get("reason_code", "")) == "owner_revision_stale", "stale owner revision fails closed")
	_expect(not bool(forged.get("applied", true)) and not bool(human.get("applied", true)), "forged capability and human actor are rejected")
	_expect(int(world.debug_snapshot().get("city_inference_mutation_count", 0)) == command_mutations_before + 1, "all rejected commands preserve authoritative state")
	var capability_before_restore := capability
	var rewind := world.apply_save_data(pre_command_save)
	capabilities = ai.get("_ai_region_knowledge_capabilities") as Dictionary
	capability = capabilities.get(1) as AiRegionKnowledgeCapability
	capability_b = capabilities.get(2) as AiRegionKnowledgeCapability
	capability_c = capabilities.get(3) as AiRegionKnowledgeCapability
	var stale_restore_command := command_port.submit_guess(capability_before_restore, "test:ai-city-inference:stale-restore-capability", 1, "region.001", 3, 3, "product", owner_revision)
	var same_id_after_restore := command_port.submit_guess(capability, command_id, 1, "region.001", 3, 3, "product", owner_revision)
	_expect(
		bool(rewind.get("applied", false))
			and capability != capability_before_restore
			and not bool(stale_restore_command.get("applied", true))
			and bool(same_id_after_restore.get("applied", false))
			and bool(same_id_after_restore.get("changed", false))
			and not bool(same_id_after_restore.get("idempotent_replay", true)),
		"WorldSession restore revokes old tokens and clears the exact-once journal"
	)
	_expect(int((_region(region_port.actor_intelligence_snapshot(capability, 1), "region.001").get("city", {}) as Dictionary).get("owner", -1)) == 3, "post-restore same-ID command mutates the current WorldSession instead of returning a stale receipt")
	var reverted_for_session := world.set_city_owner_guess(1, "region.001", 2, 2, "card", world.city_inference_owner_revision(1))
	var capability_before_session := capability
	var next_session := game_session.begin_session({"session_id": "ai-city-inference-session-b", "scenario_id": "focused", "seed": 18, "player_count": 4})
	capabilities = ai.get("_ai_region_knowledge_capabilities") as Dictionary
	capability = capabilities.get(1) as AiRegionKnowledgeCapability
	capability_b = capabilities.get(2) as AiRegionKnowledgeCapability
	capability_c = capabilities.get(3) as AiRegionKnowledgeCapability
	var stale_session_command := command_port.submit_guess(capability_before_session, "test:ai-city-inference:stale-session-capability", 1, "region.001", 3, 3, "product", world.city_inference_owner_revision(1))
	var same_id_after_session := command_port.submit_guess(capability, command_id, 1, "region.001", 3, 3, "product", world.city_inference_owner_revision(1))
	_expect(
		bool(reverted_for_session.get("applied", false))
			and str(next_session.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING
			and capability != capability_before_session
			and not bool(stale_session_command.get("applied", true))
			and bool(same_id_after_session.get("changed", false))
			and not bool(same_id_after_session.get("idempotent_replay", true)),
		"new GameSession identity revokes old tokens and clears the command journal"
	)
	var reverted_for_capability := world.set_city_owner_guess(1, "region.001", 2, 2, "card", world.city_inference_owner_revision(1))
	var capability_before_roster_refresh := capability
	world.replace_players(world.players.duplicate(true), true)
	capabilities = ai.get("_ai_region_knowledge_capabilities") as Dictionary
	capability = capabilities.get(1) as AiRegionKnowledgeCapability
	capability_b = capabilities.get(2) as AiRegionKnowledgeCapability
	capability_c = capabilities.get(3) as AiRegionKnowledgeCapability
	var stale_roster_command := command_port.submit_guess(capability_before_roster_refresh, "test:ai-city-inference:stale-roster-capability", 1, "region.001", 3, 3, "product", world.city_inference_owner_revision(1))
	var same_id_after_capability := command_port.submit_guess(capability, command_id, 1, "region.001", 3, 3, "product", world.city_inference_owner_revision(1))
	_expect(
		bool(reverted_for_capability.get("applied", false))
			and capability != capability_before_roster_refresh
			and not bool(stale_roster_command.get("applied", true))
			and bool(same_id_after_capability.get("changed", false))
			and not bool(same_id_after_capability.get("idempotent_replay", true)),
		"same-roster capability refresh revokes old tokens and clears the journal"
	)

	var snapshot_b_after := region_port.actor_intelligence_snapshot(capability_b, 2)
	_expect(int((_region(snapshot_b_after, "region.001").get("city", {}) as Dictionary).get("owner", -1)) == -1, "AI-A command remains invisible to AI-B")
	var saved := world.to_save_data()
	var restored := WorldSessionState.new()
	root.add_child(restored)
	var restore_receipt := restored.apply_save_data(saved)
	var restored_records: Array = restored.city_inference_projection(1).get("records", [])
	_expect(bool(restore_receipt.get("applied", false)) and restored_records.size() == 1, "existing WorldSession save contract cold-restores the AI guess")
	if restored_records.size() == 1:
		var restored_record := restored_records[0] as Dictionary
		_expect(int(restored_record.get("suspected_player_index", -1)) == 3 and int(restored_record.get("confidence", 0)) == 3 and str(restored_record.get("reason_id", "")) == "product", "guess, confidence, and reason roundtrip without a new save section")

	_run_source_negative_gates()
	restored.queue_free()
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(name: String, is_ai: bool, private_marker: String) -> Dictionary:
	return {
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"cash": 700,
		"slots": [{"private_marker": private_marker}],
		"discard": [private_marker],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
		"ai_profile": {"private_marker": private_marker},
		"ai_memory": {"private_marker": private_marker, "learned_policy_values": {}},
	}


func _district(region_id: String, name: String, owner: int, product: String, demand: String, last_income: int, disrupted: int, warehouse_count: int, warehouse_units: int) -> Dictionary:
	return {
		"region_id": region_id,
		"name": name,
		"destroyed": false,
		"center": {"private_plan": "CLUE_PRIVATE_CENTER"},
		"polygon": [{"private_plan": "CLUE_PRIVATE_POLYGON"}],
		"products": [{"name": "CLUE_PRIVATE_DISTRICT_PRODUCT"}],
		"demands": [{"private_plan": "CLUE_PRIVATE_DISTRICT_DEMAND"}],
		"neighbors": [{"private_plan": "CLUE_PRIVATE_NEIGHBOR"}],
		"transport_score": {"private_plan": "CLUE_PRIVATE_TRANSPORT"},
		"damage": {"private_plan": "CLUE_PRIVATE_DAMAGE"},
		"panic": {"private_plan": "CLUE_PRIVATE_PANIC"},
		"city": {
			"active": true,
			"owner": owner,
			"last_income": last_income,
			"products": [{"name": product}],
			"demands": [demand],
			"trade_disrupted_routes": disrupted,
			"competition_matches": {"private_plan": "CLUE_PRIVATE_COMPETITION"},
			"trade_route_damage": {"private_plan": "CLUE_PRIVATE_ROUTE_DAMAGE"},
			"trade_routes": [{
				"product": product,
				"disrupted": disrupted > 0,
				"owner": "CLUE_PRIVATE_ROUTE_OWNER",
				"facility_id": "CLUE_PRIVATE_ROUTE_FACILITY",
			}],
			"public_clues": [{
				"text": "%s卡牌公开线索" % product,
				"products": [product],
				"private_plan": "CLUE_PRIVATE_PLAN",
				"owner_player_index": 3,
				"internal_fingerprint": "CLUE_PRIVATE_FINGERPRINT",
			}, {
				"text": {"private_plan": "CLUE_PRIVATE_TEXT_VALUE"},
				"products": [{"owner": "CLUE_PRIVATE_PRODUCT_VALUE"}],
			}],
			"last_public_clue": {"text": "%s卡牌公开线索" % product, "private_plan": "CLUE_PRIVATE_LAST"},
			"warehouse_stockpile_count": warehouse_count,
			"warehouse_stockpile_units": warehouse_units,
			"warehouse_stockpile_products": [product] if warehouse_count > 0 else [],
		},
	}


func _region(snapshot: Dictionary, region_id: String) -> Dictionary:
	for region_variant in snapshot.get("regions", []) as Array:
		if region_variant is Dictionary and str((region_variant as Dictionary).get("region_id", "")) == region_id:
			return (region_variant as Dictionary).duplicate(true)
	return {}


func _entry(entries: Array, district_index: int) -> Dictionary:
	for entry_variant in entries:
		if entry_variant is Dictionary and int((entry_variant as Dictionary).get("district_index", -1)) == district_index:
			return (entry_variant as Dictionary).duplicate(true)
	return {}


func _run_source_negative_gates() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/%s.%s" % ["main", "gd"])
	var controller_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var region_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_region_knowledge_query_port.gd")
	var command_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_city_inference_command_port.gd")
	var coordinator_scene := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var registry_scene := FileAccess.get_file_as_string("res://scenes/runtime/V06SaveOwnerRegistry.tscn")
	_expect(not main_source.contains("CITY_GUESS_CONFIDENCE_") and not main_source.contains("CITY_GUESS_REASON_"), "Main no longer owns AI city inference constants")
	_expect(not FileAccess.file_exists("res://scripts/runtime/ai_runtime_world_bridge.gd"), "generic AI world bridge is physically deleted")
	_expect(not controller_source.contains("_world_constant(&\"CITY_GUESS_"), "AI city inference no longer reads Main constant snapshots")
	_expect(
		not controller_source.contains("_ai_region_knowledge_capability:")
			and not region_source.contains("func bind_ai_capability(")
			and not command_source.contains("func bind_ai_capability("),
		"region query and city command have no shared all-actor capability"
	)
	_expect(
		region_source.contains("rival_warehouse_exposed\": false")
			and region_source.contains("actual_owner == actor_index"),
		"region projection permanently guards rival warehouse privacy"
	)
	var whole_districts_pattern := RegEx.new()
	whole_districts_pattern.compile("(^|[^A-Za-z0-9_])districts\\s*(\\[|\\.size\\()")
	_expect(not controller_source.contains("\nvar districts:") and not controller_source.contains("_world_value(&\"districts\"") and whole_districts_pattern.search(controller_source) == null, "AI controller has no whole-district collection read or write")
	_expect(not controller_source.contains("_call_monster(&\"_district_city\"") and not controller_source.contains("trade_routes"), "AI region reads use typed projections without Monster or raw city-route fallback")
	for function_name in ["_intel_city_guess_entries", "_ai_public_player_product_signal", "_ai_city_guess_owner_candidate", "_ai_city_guess_candidates", "_auto_ai_intel_decisions"]:
		var body := _function_body(controller_source, function_name)
		_expect(not body.contains("players") and not body.contains("districts") and not body.contains("_call_world"), "%s contains no whole-world or Main dynamic access" % function_name)
	_expect(coordinator_scene.count("AiActorStatePort.tscn") == 1 and coordinator_scene.count("AiRegionKnowledgeQueryPort.tscn") == 1 and coordinator_scene.count("AiCityInferenceCommandPort.tscn") == 1, "production composition contains exactly one of each typed AI port")
	_expect(not registry_scene.contains("AiActorStatePort") and not registry_scene.contains("AiRegionKnowledgeQueryPort") and not registry_scene.contains("AiCityInferenceCommandPort"), "typed AI ports add no save section or second state owner")


func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return "MISSING"
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI city inference typed ports cutover passed (%d checks)." % _checks)
		print("AI_CITY_INFERENCE_TYPED_PORTS_CUTOVER_COMPLETE")
		quit(0)
		return
	push_error("AI city inference typed ports cutover failed:\n- " + "\n- ".join(_failures))
	quit(1)
