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
	var monster := coordinator.get_node_or_null("MonsterRuntimeController") as MonsterRuntimeController
	var military := coordinator.get_node_or_null("MilitaryRuntimeController") as MilitaryRuntimeController
	var monster_public := coordinator.get_node_or_null("AiMonsterPublicQueryPort") as AiMonsterPublicQueryPort
	var monster_actor := coordinator.get_node_or_null("AiMonsterActorQueryPort") as AiMonsterActorQueryPort
	var military_public := coordinator.get_node_or_null("AiMilitaryPublicQueryPort") as AiMilitaryPublicQueryPort
	var military_actor := coordinator.get_node_or_null("AiMilitaryActorQueryPort") as AiMilitaryActorQueryPort
	_expect(
		world != null and game_session != null and rng != null and ai != null \
			and monster != null and military != null \
			and monster_public != null and monster_actor != null \
			and military_public != null and military_actor != null,
		"production coordinator contains all four Monster/Military query ports and their authoritative owners"
	)
	if not _failures.is_empty():
		coordinator.queue_free()
		await process_frame
		_finish()
		return

	ai.configure({"ruleset_id": "v0.6"})
	game_session.configure({"ruleset_id": "v0.6"}, {})
	var started := game_session.begin_session({
		"session_id": "ai-monster-military-query-focused",
		"scenario_id": "focused",
		"seed": 8191,
		"player_count": 3,
	})
	_expect(
		str(started.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING,
		"fixture starts through GameSession authority"
	)
	world.restore({
		"players": [
			_player("人类", false, "HUMAN_PRIVATE"),
			_player("AI-A", true, "AI_A_PRIVATE"),
			_player("AI-B", true, "AI_B_PRIVATE"),
		],
		"districts": [
			{"region_id": "region.000", "name": "甲区", "center": Vector2(10.0, 10.0), "products": ["晶矿"], "demands": [], "destroyed": false},
			{"region_id": "region.001", "name": "乙区", "center": Vector2(40.0, 10.0), "products": ["生物质"], "demands": [], "destroyed": false},
		],
		"game_time": 16.0,
	}, true)
	ai._ensure_player_ai_state()
	monster.auto_monsters = [
		_monster(101, 0, 1, "AI_A_MONSTER_TARGET", 1111),
		_monster(202, 1, 2, "AI_B_MONSTER_TARGET", 2222),
	]
	military.replace_runtime_state([
		_military_unit(301, 1, "AI_A_MILITARY_TARGET", ["AI_A_BOUND_1", "AI_A_BOUND_2"]),
		_military_unit(302, 2, "AI_B_MILITARY_TARGET", ["AI_B_BOUND"]),
	], 303)

	var monster_capabilities := ai.get("_ai_monster_actor_capabilities") as Dictionary
	var military_capabilities := ai.get("_ai_military_actor_capabilities") as Dictionary
	var monster_cap_a := monster_capabilities.get(1) as AiMonsterActorCapability
	var monster_cap_b := monster_capabilities.get(2) as AiMonsterActorCapability
	var military_cap_a := military_capabilities.get(1) as AiMilitaryActorCapability
	var military_cap_b := military_capabilities.get(2) as AiMilitaryActorCapability
	_expect(
		monster_capabilities.size() == 2 and military_capabilities.size() == 2 \
			and not monster_capabilities.has(0) and not military_capabilities.has(0) \
			and monster_cap_a != null and monster_cap_b != null \
			and military_cap_a != null and military_cap_b != null,
		"composition issues unique opaque capabilities only for current AI seats"
	)

	var rng_before := rng.capture_plan_checkpoint()
	var world_before := world.to_save_data()
	var monster_before := monster.roster_snapshot(true)
	var military_before := military.to_save_data()

	var public_monsters := monster_public.public_roster_snapshot()
	var public_monster_text := JSON.stringify(public_monsters)
	_expect(
		public_monsters.size() == 2 and TablePresentationPureDataPolicy.is_pure_data(public_monsters),
		"Monster public snapshot is detached pure data"
	)
	_expect(
		not public_monster_text.contains("AI_A_MONSTER_TARGET") \
			and not public_monster_text.contains("AI_B_MONSTER_TARGET") \
			and not public_monster_text.contains("owner_damage_cash_pool") \
			and not _contains_key_recursive(public_monsters, "owner"),
		"Monster public snapshot omits hidden owner, private target, and owner cash pool"
	)
	var public_monster_101 := _row_by_uid(public_monsters, 101)
	_expect(
		bool(public_monster_101.get("bracelet_active", false)) \
			and is_equal_approx(float(public_monster_101.get("weather_resistance", 0.0)), 0.25) \
			and is_equal_approx(float(public_monster_101.get("weather_exploitation_multiplier", 0.0)), 1.4),
		"Monster public projection preserves public combat and weather traits used by candidate scoring"
	)
	var monster_a_snapshot := monster_actor.actor_roster_snapshot(monster_cap_a, 1)
	var monster_a_own := _row_by_uid(monster_a_snapshot.get("roster", []) as Array, 101)
	var monster_a_rival := _row_by_uid(monster_a_snapshot.get("roster", []) as Array, 202)
	_expect(
		str(monster_a_own.get("ownership_scope", "")) == "actor_own" \
			and int(monster_a_own.get("owner_index", -1)) == 1 \
			and int(monster_a_own.get("owner_damage_cash_pool", -1)) == 1111,
		"AI-A sees only its own hidden Monster ownership and private damage pool"
	)
	_expect(
		str(monster_a_rival.get("ownership_scope", "")) == "public_unknown" \
			and not monster_a_rival.has("owner_index") \
			and not monster_a_rival.has("owner_damage_cash_pool"),
		"AI-A receives no AI-B hidden Monster ownership or private pool"
	)
	_expect(
		monster_actor.actor_roster_snapshot(monster_cap_b, 1).is_empty() \
			and monster_actor.actor_roster_snapshot(AiMonsterActorCapability.new(), 1).is_empty() \
			and monster_actor.actor_roster_snapshot(monster_cap_a, 0).is_empty(),
		"Monster rival, forged, and human capability queries fail closed"
	)

	var public_units := military_public.public_roster_snapshot()
	var public_unit_text := JSON.stringify(public_units)
	_expect(
		public_units.size() == 2 and TablePresentationPureDataPolicy.is_pure_data(public_units),
		"Military public snapshot is detached pure data"
	)
	_expect(
		not public_unit_text.contains("AI_A_MILITARY_TARGET") \
			and not public_unit_text.contains("AI_B_MILITARY_TARGET") \
			and not public_unit_text.contains("AI_A_BOUND") \
			and not public_unit_text.contains("AI_B_BOUND") \
			and not _contains_key_recursive(public_units, "owner"),
		"Military public snapshot omits hidden owner, private target, and bound-skill details"
	)
	var military_a_snapshot := military_actor.actor_roster_snapshot(military_cap_a, 1)
	var military_a_own := _row_by_uid(military_a_snapshot.get("roster", []) as Array, 301)
	var military_a_rival := _row_by_uid(military_a_snapshot.get("roster", []) as Array, 302)
	_expect(
		str(military_a_own.get("ownership_scope", "")) == "actor_own" \
			and int(military_a_own.get("owner_index", -1)) == 1 \
			and int(military_a_own.get("bound_skill_count", -1)) == 2,
		"AI-A sees its own Military ownership and summarized private capability"
	)
	_expect(
		str(military_a_rival.get("ownership_scope", "")) == "public_unknown" \
			and not military_a_rival.has("owner_index") \
			and not military_a_rival.has("bound_skill_count"),
		"AI-A receives no AI-B hidden Military ownership or private capability"
	)
	_expect(
		military_actor.actor_roster_snapshot(military_cap_b, 1).is_empty() \
			and military_actor.actor_roster_snapshot(AiMilitaryActorCapability.new(), 1).is_empty() \
			and military_actor.actor_roster_snapshot(military_cap_a, 0).is_empty(),
		"Military rival, forged, and human capability queries fail closed"
	)

	var bound_monster := ai._ai_monster_actor_for_skill(1, {
		"kind": "monster_bound_action",
		"bound_monster_uid": 101,
	})
	_expect(
		int(bound_monster.get("uid", -1)) == 101 \
			and ai._ai_monster_actor_for_skill(1, {
				"kind": "monster_bound_action",
				"bound_monster_uid": 999,
			}).is_empty(),
		"positive Monster binding selects its exact actor row and stale UID fails closed"
	)
	_expect(
		int(military_actor.first_ready_owned_unit(military_cap_a, 1, 301).get("uid", -1)) == 301 \
			and military_actor.first_ready_owned_unit(military_cap_a, 1, 999).is_empty(),
		"positive Military binding selects its exact unit and never falls back to another owned unit"
	)
	var public_unit_301 := _row_by_uid(public_units, 301)
	_expect(
		is_equal_approx(float((public_unit_301.get("terrain_move_multiplier", {}) as Dictionary).get("land", 0.0)), 1.25) \
			and str(public_unit_301.get("military_domain", "")) == "land",
		"Military public projection preserves public terrain movement traits used by AI scoring"
	)
	var stale_rng_before := rng.capture_plan_checkpoint()
	var stale_monster_before := monster.roster_snapshot(true)
	var stale_military_before := military.to_save_data()
	var rejected_monster_target := monster._trigger_bound_monster_skill({
		"name": "冻结区域拒绝测试",
		"kind": "monster_bound_action",
		"bound_monster_uid": 101,
		"action": {"name": "测试兽技", "damage": 1},
	}, world.players[1] as Dictionary, -1)
	var rejected_military_uid := military.trigger_command({
		"name": "失效军令拒绝测试",
		"kind": "military_command",
		"military_command": "move",
		"bound_military_uid": 999,
	}, -1, 1, {"selected_district": 0})
	_expect(
		not rejected_monster_target \
			and not rejected_military_uid \
			and monster.roster_snapshot(true) == stale_monster_before \
			and military.to_save_data() == stale_military_before \
			and rng.capture_plan_checkpoint() == stale_rng_before,
		"invalid frozen region and stale Military UID reject without owner mutation or RNG consumption"
	)
	(public_monsters[0] as Dictionary)["name"] = "MUTATED_MONSTER_COPY"
	(public_units[0] as Dictionary)["name"] = "MUTATED_MILITARY_COPY"
	_expect(
		str(monster_public.public_monster_by_uid(101).get("name", "")) != "MUTATED_MONSTER_COPY" \
			and str(military_public.public_unit_by_uid(301).get("name", "")) != "MUTATED_MILITARY_COPY",
		"public Monster and Military snapshots are detached from live owners"
	)
	_expect(
		world.to_save_data() == world_before \
			and monster.roster_snapshot(true) == monster_before \
			and military.to_save_data() == military_before \
			and rng.capture_plan_checkpoint() == rng_before,
		"Monster and Military query ports perform zero owner mutation and consume zero RNG"
	)

	var old_monster_capability := monster_cap_a
	var old_military_capability := military_cap_a
	world.replace_players(world.players.duplicate(true), true)
	var replacement_monster_capabilities := ai.get("_ai_monster_actor_capabilities") as Dictionary
	var replacement_military_capabilities := ai.get("_ai_military_actor_capabilities") as Dictionary
	_expect(
		replacement_monster_capabilities.get(1) != old_monster_capability \
			and replacement_military_capabilities.get(1) != old_military_capability \
			and monster_actor.actor_roster_snapshot(old_monster_capability, 1).is_empty() \
			and military_actor.actor_roster_snapshot(old_military_capability, 1).is_empty(),
		"players replacement reissues capabilities and stale Monster/Military tokens fail closed"
	)

	var monster_debug := monster_public.debug_snapshot()
	var military_debug := military_public.debug_snapshot()
	_expect(
		not bool(monster_debug.get("mutates_world", true)) \
			and not bool(monster_debug.get("consumes_rng", true)) \
			and not bool(military_debug.get("mutates_world", true)) \
			and not bool(military_debug.get("consumes_rng", true)),
		"debug evidence records save-neutral, RNG-neutral query boundaries"
	)
	_run_source_negative_gates()
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(name: String, is_ai: bool, marker: String) -> Dictionary:
	return {
		"actor_id": "actor.%s" % name,
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"eliminated": false,
		"cash": 700,
		"slots": [{"private_marker": marker}],
		"discard": [marker],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
		"ai_profile": {"private_marker": marker},
		"ai_memory": {"private_marker": marker, "decision_samples": [], "action_counts": {}},
	}


func _monster(uid: int, slot: int, owner: int, private_target: String, cash_pool: int) -> Dictionary:
	return {
		"uid": uid,
		"slot": slot,
		"catalog_index": slot,
		"name": "怪兽-%d" % uid,
		"rank": 1,
		"hp": 120,
		"max_hp": 120,
		"armor": 4,
		"guard": 0,
		"ranged_guard": 0,
		"tether": 0,
		"remaining_time": 90.0,
		"move": 5.0,
		"position": slot,
		"world_position": Vector2(10.0 + slot * 30.0, 10.0),
		"down": false,
		"bracelet_active": slot == 0,
		"weather_resistance": 0.25,
		"weather_exploitation_multiplier": 1.4,
		"owner": owner,
		"owner_revealed": false,
		"owner_damage_cash_pool": cash_pool,
		"owner_damage_cash_total": cash_pool,
		"private_target": private_target,
		"resource_focus": ["晶矿" if slot == 0 else "生物质"],
		"movement_traits": ["land"],
		"terrain_move_multiplier": {"land": 1.0},
		"actor_revision_v06": 1,
	}


func _military_unit(uid: int, owner: int, private_target: String, bound_skills: Array) -> Dictionary:
	return {
		"uid": uid,
		"name": "军队-%d" % uid,
		"rank": 1,
		"military_type": "defense",
		"military_domain": "land",
		"movement_traits": ["land"],
		"terrain_move_multiplier": {"land": 1.25, "ocean": 0.5},
		"position": uid - 301,
		"world_position": Vector2(20.0 + (uid - 301) * 25.0, 15.0),
		"hp": 80,
		"max_hp": 80,
		"damage": 12,
		"range": 80.0,
		"move": 4.0,
		"remaining_time": 120.0,
		"cooldown_left": 0.0,
		"owner": owner,
		"public_owner_revealed": false,
		"private_target": private_target,
		"bound_skill_names": bound_skills.duplicate(true),
	}


func _row_by_uid(rows: Array, uid: int) -> Dictionary:
	for row_variant in rows:
		if row_variant is Dictionary and int((row_variant as Dictionary).get("uid", -1)) == uid:
			return (row_variant as Dictionary).duplicate(true)
	return {}


func _contains_key_recursive(value: Variant, forbidden_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == forbidden_key \
					or _contains_key_recursive((value as Dictionary).get(key_variant), forbidden_key):
				return true
	elif value is Array:
		for child in value as Array:
			if _contains_key_recursive(child, forbidden_key):
				return true
	return false


func _run_source_negative_gates() -> void:
	var scene_source := FileAccess.get_file_as_string("res://scenes/runtime/GameRuntimeCoordinator.tscn")
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var router_source := FileAccess.get_file_as_string("res://scripts/runtime/card_effect_runtime_router.gd")
	var monster_source := FileAccess.get_file_as_string("res://scripts/runtime/monster_runtime_controller.gd")
	var military_source := FileAccess.get_file_as_string("res://scripts/runtime/military_runtime_controller.gd")
	for scene_name in [
		"AiMonsterPublicQueryPort.tscn",
		"AiMonsterActorQueryPort.tscn",
		"AiMilitaryPublicQueryPort.tscn",
		"AiMilitaryActorQueryPort.tscn",
	]:
		_expect(scene_source.contains(scene_name), "production coordinator composes %s" % scene_name)
	_expect(not ai_source.contains("var auto_monsters:") and not ai_source.contains("var military_units:"), "AI controller owns no broad Monster or Military roster property")
	_expect(not ai_source.contains("owner_damage_cash_pool") or ai_source.contains("ownership_scope"), "AI scoring cannot use a rival Monster cash pool without actor authorization")
	_expect(
		router_source.contains("_summon_monster_from_card(player_index, skill, int(entry.get(\"selected_district\", -1)))") \
			and router_source.contains("_trigger_bound_monster_skill(skill, player, int(entry.get(\"selected_district\", -1)))") \
			and router_source.contains("summon_from_card(player_index, skill, int(entry.get(\"selected_district\", -1)))"),
		"card effect routing forwards the frozen queue region to Monster and Military owners"
	)
	_expect(
		not monster_source.contains("var target := selected_district") \
			and not monster_source.contains("target = _weighted_auto_monster_target(actor)") \
			and not military_source.contains("_world_bridge.table_selection_state()") \
			and military_source.contains("bound_unit_uid <= 0"),
		"card execution cannot re-read UI selection, resample an invalid frozen target, or reroute a stale bound UID"
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI Monster/Military query ports passed (%d checks)." % _checks)
		print("AI_MONSTER_MILITARY_QUERY_PORTS_COMPLETE")
		quit(0)
		return
	push_error("AI Monster/Military query port failures:\n- " + "\n- ".join(_failures))
	quit(1)