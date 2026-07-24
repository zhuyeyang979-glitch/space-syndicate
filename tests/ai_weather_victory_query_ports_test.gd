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
	var game_session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var weather_owner := coordinator.get_node_or_null("WeatherRuntimeController") as WeatherRuntimeController
	var victory_owner := coordinator.get_node_or_null("VictoryControlRuntimeController") as VictoryControlRuntimeController
	var weather_query := coordinator.get_node_or_null("AiWeatherPublicQueryPort") as AiWeatherPublicQueryPort
	var victory_public := coordinator.get_node_or_null("AiVictoryPublicQueryPort") as AiVictoryPublicQueryPort
	var victory_actor := coordinator.get_node_or_null("AiActorVictoryQueryPort") as AiActorVictoryQueryPort
	_expect(
		world != null and game_session != null and rng != null and ai != null \
			and weather_owner != null and victory_owner != null \
			and weather_query != null and victory_public != null and victory_actor != null,
		"production coordinator composes all Weather/Victory typed query ports with authoritative owners"
	)
	if not _failures.is_empty():
		coordinator.queue_free()
		await process_frame
		_finish()
		return

	game_session.configure({"ruleset_id": "v0.6"}, {})
	var started := game_session.begin_session({
		"session_id": "ai-weather-victory-query-focused",
		"scenario_id": "focused",
		"seed": 9923,
		"player_count": 3,
	})
	world.restore({
		"players": [
			_player("人类", false, "human.actor"),
			_player("AI-A", true, "ai.a"),
			_player("AI-B", true, "ai.b"),
		],
		"districts": [
			_district("region.000", "甲区", Vector2(10.0, 10.0)),
			_district("region.001", "乙区", Vector2(40.0, 10.0)),
		],
		"game_time": 25.0,
	}, true)
	coordinator._wire_ai_world_typed_ports()
	ai._ensure_player_ai_state()
	_expect(
		str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING \
			and weather_query.is_ready() and victory_public.is_ready() and victory_actor.is_ready(),
		"formal session and all three typed query ports become ready"
	)

	var rng_before := rng.capture_plan_checkpoint()
	var world_before := world.to_save_data()
	var weather_before := weather_owner.to_save_data()
	var session_before := game_session.capture_new_session_checkpoint()
	var weather_snapshot := weather_query.public_snapshot()
	var weather_rules := weather_query.rules_snapshot()
	var ion_storm := weather_query.definition_snapshot("ion_storm")
	var preview := weather_query.preview_districts(0, 1)
	var invalid_preview := weather_query.preview_districts(99, 1)
	_expect(
		TablePresentationPureDataPolicy.is_pure_data(weather_snapshot) \
			and TablePresentationPureDataPolicy.is_pure_data(weather_rules) \
			and str(ion_storm.get("id", "")) == "ion_storm" \
			and float(ion_storm.get("demand_multiplier", 0.0)) > 0.0 \
			and preview == [0] and invalid_preview.is_empty(),
		"weather query returns detached public definitions and deterministic valid-region preview"
	)
	_expect(
		rng.capture_plan_checkpoint() == rng_before \
			and world.to_save_data() == world_before \
			and weather_owner.to_save_data() == weather_before \
			and game_session.capture_new_session_checkpoint() == session_before,
		"weather query and invalid preview consume zero RNG and mutate no owner"
	)
	var ai_weather := ai._weather_template("ion_storm")
	_expect(
		str(ai_weather.get("id", "")) == "ion_storm" \
			and ai._weather_preview_districts(0, 1) == [0],
		"AI Weather consumer reads only through the typed public query port"
	)

	victory_owner.configure()
	victory_owner.advance_world_effective(10.0, _victory_world_snapshot())
	var public_victory := victory_public.public_snapshot()
	var public_text := JSON.stringify(public_victory)
	_expect(
		str(public_victory.get("visibility_scope", "")) == "public" \
			and TablePresentationPureDataPolicy.is_pure_data(public_victory) \
			and not public_text.contains("HUMAN_PRIVATE_CARD") \
			and not public_text.contains("AI_A_PRIVATE_CARD") \
			and not public_text.contains("AI_B_PRIVATE_CARD") \
			and not _contains_key_recursive(public_victory, "own_economic_assets"),
		"victory public query preserves public audit facts without private asset envelopes"
	)
	var capabilities := ai.get("_ai_actor_victory_capabilities") as Dictionary
	var cap_a := capabilities.get(1) as AiActorVictoryCapability
	var cap_b := capabilities.get(2) as AiActorVictoryCapability
	_expect(
		capabilities.size() == 2 and not capabilities.has(0) \
			and cap_a != null and cap_b != null and cap_a != cap_b,
		"composition issues unique Victory capabilities only for AI seats"
	)
	var actor_a := victory_actor.actor_snapshot(cap_a, 1)
	var actor_b := victory_actor.actor_snapshot(cap_b, 2)
	var actor_a_text := JSON.stringify(actor_a)
	_expect(
		int(actor_a.get("actor_index", -1)) == 1 \
			and int((actor_a.get("own_candidate", {}) as Dictionary).get("player_index", -1)) == 1 \
			and int(actor_b.get("actor_index", -1)) == 2 \
			and not _contains_key_recursive(actor_a, "own_economic_assets") \
			and not _contains_key_recursive(actor_a, "cash_ledger_cents") \
			and not actor_a_text.contains("AI_B_PRIVATE_CARD"),
		"actor Victory query returns only the authorized AI candidate and no private asset inventory"
	)
	var own_visible_candidate := victory_actor.candidate_visible_to_actor(cap_a, 1, 1)
	var public_rival_candidate := victory_actor.candidate_visible_to_actor(cap_b, 2, 1)
	var visible_rankings := ai._victory_visible_rankings(1)
	var own_visible_ranking: Dictionary = visible_rankings[0] as Dictionary \
		if visible_rankings.size() == 1 and visible_rankings[0] is Dictionary else {}
	_expect(
		int(own_visible_candidate.get("cash_ledger_cents", -1)) == 91_000_000 \
			and int(public_rival_candidate.get("cash_ledger_cents", -1)) == 91_000_000 \
			and int(own_visible_ranking.get("cash_ledger_cents", -1)) == 91_000_000 \
			and victory_actor.candidate_visible_to_actor(cap_a, 1, 2).is_empty(),
		"public audit cash remains sortable while an unaudited rival candidate stays private"
	)

	_expect(
		victory_actor.actor_snapshot(cap_a, 2).is_empty() \
			and victory_actor.actor_snapshot(AiActorVictoryCapability.new(), 1).is_empty() \
			and victory_actor.actor_snapshot(null, 0).is_empty(),
		"rival, forged, and human Victory capability queries fail closed"
	)
	_expect(
		ai._victory_top_n_gdp(1) == int((actor_a.get("own_candidate", {}) as Dictionary).get("top_n_gdp_per_minute", 0)) \
			and ai._victory_top_n_gdp(1) > 0 \
			and ai._victory_top_n_gdp(1, 2) == 0 \
			and ai._victory_top_n_gdp(2, 1) > 0,
		"AI Victory scoring sees own candidate plus public audit, never a rival private candidate"
	)

	var victory_saved := victory_owner.to_save_data()
	var cold_apply := victory_owner.apply_save_data(victory_saved)
	var cold_public := victory_public.public_snapshot()
	_expect(
		bool(cold_apply.get("applied", false)) \
			and not bool(cold_public.get("available", true)) \
			and victory_actor.actor_snapshot(cap_a, 1).is_empty() \
			and ai._ai_game_phase(1) != "endgame",
		"cold-restored Victory cache fails closed until fresh authoritative world facts arrive"
	)
	victory_owner.advance_world_effective(0.0, _victory_world_snapshot())
	_expect(
		bool(victory_public.public_snapshot().get("available", false)) \
			and not victory_actor.actor_snapshot(cap_a, 1).is_empty(),
		"fresh post-restore world facts reopen the actor-scoped Victory query"
	)

	var capability_revision_before := int(victory_actor.debug_snapshot().get("capability_revision", -1))
	var operation_sequence_before := int(game_session.capture_new_session_checkpoint().get("operation_sequence", -1))
	var rejected_save := game_session.request_save("user://test_runs/ai_weather_victory_capability_probe.save", {}, {})
	var operation_sequence_after := int(game_session.capture_new_session_checkpoint().get("operation_sequence", -1))
	_expect(
		not bool(rejected_save.get("ok", true)) \
			and operation_sequence_after == operation_sequence_before + 1 \
			and int(victory_actor.debug_snapshot().get("capability_revision", -1)) == capability_revision_before \
			and not victory_actor.actor_snapshot(cap_a, 1).is_empty(),
		"save-operation bookkeeping does not revoke a stable Victory actor capability"
	)
	var restarted := game_session.begin_session({
		"session_id": "ai-weather-victory-query-next-session",
		"scenario_id": "focused-restarted",
		"seed": 9924,
		"player_count": 3,
	})
	var replacement_capabilities := ai.get("_ai_actor_victory_capabilities") as Dictionary
	var replacement_cap_a := replacement_capabilities.get(1) as AiActorVictoryCapability
	_expect(
		str(restarted.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING \
			and replacement_cap_a != null and replacement_cap_a != cap_a \
			and victory_actor.actor_snapshot(cap_a, 1).is_empty() \
			and not victory_actor.actor_snapshot(replacement_cap_a, 1).is_empty(),
		"new GameSession identity reissues Victory capabilities and rejects stale tokens"
	)

	var ai_debug := ai.debug_snapshot()
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var coordinator_source := FileAccess.get_file_as_string("res://scripts/runtime/game_runtime_coordinator.gd")
	_expect(
		bool(ai_debug.get("typed_weather_public_query_bound", false)) \
			and bool(ai_debug.get("typed_victory_public_query_bound", false)) \
			and bool(ai_debug.get("typed_actor_victory_query_bound", false)) \
			and not ai_source.contains("_weather_runtime_controller") \
			and not ai_source.contains("_victory_control_runtime_controller") \
			and not ai_source.contains("set_weather_runtime_controller") \
			and not ai_source.contains("set_victory_control_runtime_controller") \
			and not ai_source.contains("_victory_top_n_gdp(i)") \
			and not ai_source.contains("_player_active_city_count(i)") \
			and not ai_source.contains("_ai_owned_active_monster_count(i)") \
			and ai_source.contains("_visible_active_city_count_for_actor(player_index, i)") \
			and ai_source.contains("_visible_active_monster_count_for_actor(player_index, i)") \
			and not coordinator_source.contains('ai_controller.call("set_weather_runtime_controller"') \
			and not coordinator_source.contains('ai_controller.call("set_victory_control_runtime_controller"'),
		"production AI has no direct Weather/Victory owner path or Coordinator fallback"
	)

	coordinator.queue_free()
	await process_frame
	_finish()


func _player(display_name: String, is_ai: bool, actor_id: String) -> Dictionary:
	return {
		"name": display_name,
		"actor_id": actor_id,
		"is_ai": is_ai,
		"seat_type": "ai" if is_ai else "human",
		"cash": 100,
		"hand": [],
		"ai_profile": {},
		"ai_memory": {},
	}


func _district(region_id: String, display_name: String, center: Vector2) -> Dictionary:
	return {
		"region_id": region_id,
		"name": display_name,
		"center": center,
		"destroyed": false,
		"terrain": "land",
		"products": [],
		"demands": [],
		"city": {"active": true, "owner": -1, "products": [], "demands": []},
	}


func _victory_world_snapshot() -> Dictionary:
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [
			_victory_player(0, 99_000_000, "HUMAN_PRIVATE_CARD"),
			_victory_player(1, 91_000_000, "AI_A_PRIVATE_CARD"),
			_victory_player(2, 81_000_000, "AI_B_PRIVATE_CARD"),
		],
		"regions": [
			_victory_region(0, 7200, {"1": 3600}),
			_victory_region(1, 7200, {"1": 3600}),
			_victory_region(2, 0, {}),
			_victory_region(3, 0, {}),
			_victory_region(4, 0, {}),
		],
		"clock_pause": {},
		"settlement_checkpoint": "post_world_settlement",
	}


func _victory_player(player_index: int, cash_cents: int, private_card: String) -> Dictionary:
	return {
		"player_index": player_index,
		"eliminated": false,
		"cash_ledger_cents": cash_cents,
		"audit_assets": {
			"available_cents": cash_cents - 1000,
			"escrow_cents": 1000,
			"cash_ledger_cents": cash_cents,
			"ordinary_hand": [{"card_id": private_card}],
			"facilities": [],
			"installations": [],
			"commodity_inventory": [],
			"color_gdp": {},
			"units": [],
			"financial_positions": [],
		},
	}


func _victory_region(index: int, gdp_cents: int, player_gdp: Dictionary) -> Dictionary:
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": gdp_cents,
		"player_gdp_by_index": player_gdp.duplicate(true),
	}


func _contains_key_recursive(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == target_key \
					or _contains_key_recursive((value as Dictionary).get(key_variant), target_key):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_key_recursive(item, target_key):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("AI_WEATHER_VICTORY_QUERY_PORTS_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
