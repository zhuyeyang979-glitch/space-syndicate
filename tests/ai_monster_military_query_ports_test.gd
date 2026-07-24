extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")

var _checks := 0
var _failures: Array[String] = []


class MonsterCommandWorld:
	extends Node

	func _entity_has_linear_motion(_entity: Dictionary) -> bool:
		return false

	func _entity_world_position(entity: Dictionary) -> Vector2:
		var value: Variant = entity.get("world_position", Vector2.ZERO)
		return value if value is Vector2 else Vector2.ZERO

	func _wrapped_distance(from_position: Vector2, to_position: Vector2) -> float:
		return from_position.distance_to(to_position)


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
	var monster_bridge := coordinator.get_node_or_null("MonsterRuntimeWorldBridge") as MonsterRuntimeWorldBridge
	var military := coordinator.get_node_or_null("MilitaryRuntimeController") as MilitaryRuntimeController
	var military_bridge := coordinator.get_node_or_null("MilitaryRuntimeWorldBridge") as MilitaryRuntimeWorldBridge
	var route_bridge := coordinator.get_node_or_null("RouteNetworkWorldBridge") as RouteNetworkWorldBridge
	var monster_public := coordinator.get_node_or_null("AiMonsterPublicQueryPort") as AiMonsterPublicQueryPort
	var monster_actor := coordinator.get_node_or_null("AiMonsterActorQueryPort") as AiMonsterActorQueryPort
	var military_public := coordinator.get_node_or_null("AiMilitaryPublicQueryPort") as AiMilitaryPublicQueryPort
	var military_actor := coordinator.get_node_or_null("AiMilitaryActorQueryPort") as AiMilitaryActorQueryPort
	var infrastructure := coordinator.get_node_or_null("RegionInfrastructureRuntimeController") as RegionInfrastructureRuntimeController
	var route_network := coordinator.get_node_or_null("RouteNetworkRuntimeController") as RouteNetworkRuntimeController
	var selection := coordinator.get_node_or_null("TableSelectionState") as TableSelectionState
	var presentation_ports := coordinator.get_node_or_null("TablePresentationQueryPorts") as TablePresentationQueryPorts
	var public_log_owner := coordinator.get_node_or_null("TablePresentationQueryPorts/PublicLogPresentationOwner") as PublicLogPresentationOwner
	var public_log_port := coordinator.get_node_or_null("TablePresentationQueryPorts/PublicLogProducerPort") as PublicLogProducerPort
	var refresh_port := coordinator.get_node_or_null("TablePresentationRefreshPort") as TablePresentationRefreshPort
	var world_clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController") as WorldEffectiveClockRuntimeController
	var visual_owner := coordinator.get_node_or_null("VisualCueRuntimeOwner") as VisualCueRuntimeOwner
	_expect(
		world != null and game_session != null and rng != null and ai != null \
			and monster != null and monster_bridge != null \
			and military != null and military_bridge != null and route_bridge != null \
			and monster_public != null and monster_actor != null \
			and military_public != null and military_actor != null \
			and infrastructure != null and route_network != null and selection != null \
			and presentation_ports != null and public_log_owner != null and public_log_port != null \
			and refresh_port != null and world_clock != null and visual_owner != null,
		"production coordinator contains all four Monster/Military query ports and their authoritative owners"
	)
	if not _failures.is_empty():
		coordinator.queue_free()
		await process_frame
		_finish()
		return

	ai.set_route_network_runtime_controller(route_network)
	var command_world := MonsterCommandWorld.new()
	coordinator.add_child(command_world)
	monster_bridge.bind_world(command_world)
	monster.set_world_bridge(monster_bridge)
	military_bridge.set_world_session_state(world)
	military.set_world_bridge(military_bridge)
	route_bridge.set_world_session_state(world)
	route_bridge.set_region_infrastructure_controller(infrastructure)
	route_network.set_world_bridge(route_bridge)
	monster.set_table_presentation_ports(refresh_port, public_log_port, world_clock)
	military.set_table_presentation_ports(refresh_port, public_log_port, world_clock)
	monster.set_visual_cue_runtime_owner(visual_owner)
	military.set_visual_cue_runtime_owner(visual_owner)
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
			{
				"region_id": "region.000",
				"name": "甲区",
				"center": Vector2(10.0, 10.0),
				"terrain": "land",
				"products": ["晶矿"],
				"demands": [],
				"destroyed": false,
				"city": {
					"active": true,
					"owner": 1,
					"products": [],
					"demands": [],
					"warehouse_stockpile_count": 1,
					"warehouse_stockpile_units": 6,
					"warehouse_stockpile_products": ["AI_A_WAREHOUSE_PRIVATE", "AI_A_WAREHOUSE_SECOND"],
				},
			},
			{
				"region_id": "region.001",
				"name": "乙区",
				"center": Vector2(40.0, 10.0),
				"terrain": "land",
				"products": ["生物质"],
				"demands": [],
				"destroyed": false,
				"city": {
					"active": true,
					"owner": 2,
					"products": [],
					"demands": [],
					"warehouse_stockpile_count": 0,
					"warehouse_stockpile_units": 0,
					"warehouse_stockpile_products": [],
				},
			},
		],
		"game_time": 16.0,
	}, true)
	var infrastructure_configured := infrastructure.configure({
		"identity": {"ruleset_id": "v0.6"},
		"infrastructure": {
			"maximum_facility_rank": 4,
			"facility_hp_contribution_by_rank": {"I": 100, "II": 200, "III": 300, "IV": 400},
		},
	})
	var initialized_regions := infrastructure.initialize_regions([
		{"region_id": "region.000", "terrain_id": "land", "neighbor_region_ids": ["region.001"], "legacy_index": 0},
		{"region_id": "region.001", "terrain_id": "land", "neighbor_region_ids": ["region.000"], "legacy_index": 1},
	])
	var route_refresh := route_network.refresh_routes(true)
	var rival_guess := world.set_city_owner_guess(
		1,
		"region.001",
		2,
		WorldSessionState.CITY_GUESS_CONFIDENCE_MEDIUM,
		"intuition",
		world.city_inference_owner_revision(1)
	)
	_expect(
		bool(infrastructure_configured.get("configured", false)) \
			and bool(initialized_regions.get("initialized", false)) \
			and bool(route_refresh.get("refreshed", false)) \
			and bool(rival_guess.get("applied", false)),
		"fixture exposes active cities through real Infrastructure/RouteNetwork and gives AI-A one legal private rival-city inference"
	)
	coordinator._wire_ai_world_typed_ports()
	ai._ensure_player_ai_state()
	monster.auto_monsters = [
		_monster(101, 0, 1, "AI_A_MONSTER_TARGET", 1111),
		_monster(202, 1, 2, "AI_B_MONSTER_TARGET", 2222),
	]
	military.replace_runtime_state([
		_military_unit(301, 1, "AI_A_MILITARY_TARGET", ["AI_A_BOUND_1", "AI_A_BOUND_2"]),
		_military_unit(302, 2, "AI_B_MILITARY_TARGET", ["AI_B_BOUND"]),
	], 303)
	var own_event_weight := ai._district_event_weight(0, 1)
	var rival_event_weight_before := ai._district_event_weight(1, 1)
	var original_districts := world.districts.duplicate(true)
	var private_probe_districts := original_districts.duplicate(true)
	var rival_private_city := ((private_probe_districts[1] as Dictionary).get("city", {}) as Dictionary).duplicate(true)
	rival_private_city["warehouse_stockpile_count"] = 99
	rival_private_city["warehouse_stockpile_units"] = 999
	rival_private_city["warehouse_stockpile_products"] = ["RIVAL_WAREHOUSE_PRIVATE"]
	(private_probe_districts[1] as Dictionary)["city"] = rival_private_city
	world.replace_districts(private_probe_districts, true)
	var rival_event_weight_after := ai._district_event_weight(1, 1)
	world.replace_districts(original_districts, true)
	_expect(
		own_event_weight > rival_event_weight_before,
		"Monster-card target weighting may use the actor's own warehouse pressure through actor-scoped region facts"
	)
	_expect(
		rival_event_weight_after == rival_event_weight_before,
		"Monster-card target weighting ignores rival private warehouse pressure"
	)
	var clean_checkpoint := game_session.capture_new_session_checkpoint()
	clean_checkpoint["save_state"] = "clean"
	clean_checkpoint["dirty_reason"] = ""
	var clean_session := game_session.rollback_new_session_checkpoint(clean_checkpoint)
	_expect(
		bool(clean_session.get("restored", false)) and not bool(game_session.session_summary().get("dirty", true)),
		"fixture establishes a clean formal save-dirty observation point before pure queries"
	)

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
	var session_before := game_session.capture_new_session_checkpoint()
	var public_log_owner_before := public_log_owner.debug_snapshot()
	var public_log_port_before := public_log_port.debug_snapshot()
	var visual_cue_debug_before := visual_owner.debug_snapshot()
	var visual_cues_before := visual_owner.public_snapshot()

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
	monster._rebuild_monster_codex_public_catalog_cache_v06()
	var public_catalog_entry := monster_public.public_catalog_entry(0)
	_expect(
		not public_catalog_entry.is_empty() \
			and public_catalog_entry.get("resource_focus", []) is Array \
			and monster_public.can_summon_at_region({"starter_play_free": true}, 0) \
			and monster_public.can_summon_at_region({"summon_access": "land"}, 0) \
			and not monster_public.can_summon_at_region({"summon_access": "ocean"}, 0),
		"Monster public port owns catalog and summon-legality queries over detached public region facts"
	)
	_expect(
		monster_public.public_expected_damage_score(101) > 0 \
			and monster_public.public_expected_damage_score(-1) == 0,
		"Monster owner exposes expected damage only through a stable public Monster UID"
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
		int(military_actor.ready_owned_unit_by_uid(military_cap_a, 1, 301).get("uid", -1)) == 301 \
			and military_actor.ready_owned_unit_by_uid(military_cap_a, 1, 999).is_empty() \
			and military_actor.ready_owned_unit_by_uid(military_cap_a, 1, 0).is_empty(),
		"Military binding requires one positive exact unit UID and never falls back to another owned unit"
	)
	var public_unit_301 := _row_by_uid(public_units, 301)
	_expect(
		is_equal_approx(float((public_unit_301.get("terrain_move_multiplier", {}) as Dictionary).get("land", 0.0)), 1.25) \
			and str(public_unit_301.get("military_domain", "")) == "land" \
			and int(public_unit_301.get("military_gdp_penalty", -1)) == 7 \
			and int(public_unit_301.get("military_strike_route_damage", -1)) == 3,
		"Military public projection preserves every public movement and scoring field used by AI"
	)
	var warehouse_probe := {"resource_focus": ["AI_A_WAREHOUSE_PRIVATE"]}
	var public_resource_score := monster_public.public_resource_match_score_for_actor(warehouse_probe, 0)
	var ai_a_resource_score := ai._monster_resource_match_score(warehouse_probe, 0, 1)
	var ai_b_resource_score := ai._monster_resource_match_score(warehouse_probe, 0, 2)
	var capped_probe := {"resource_focus": ["晶矿", "AI_A_WAREHOUSE_PRIVATE", "AI_A_WAREHOUSE_SECOND"]}
	var capped_public_score := monster_public.public_resource_match_score_for_actor(capped_probe, 0)
	var capped_ai_a_score := ai._monster_resource_match_score(capped_probe, 0, 1)
	var capped_ai_b_score := ai._monster_resource_match_score(capped_probe, 0, 2)
	var ai_a_economy_text := JSON.stringify(ai._ai_actor_economy_snapshot(1))
	var ai_b_economy_text := JSON.stringify(ai._ai_actor_economy_snapshot(2))
	_expect(
		public_resource_score == 0 and ai_a_resource_score == 5 and ai_b_resource_score == 0 \
			and capped_public_score == 1 and capped_ai_a_score == 8 and capped_ai_b_score == 1 \
			and ai_a_economy_text.contains("AI_A_WAREHOUSE_PRIVATE") \
			and ai_a_economy_text.contains("AI_A_WAREHOUSE_SECOND") \
			and not ai_b_economy_text.contains("AI_A_WAREHOUSE_PRIVATE") \
			and not ai_b_economy_text.contains("AI_A_WAREHOUSE_SECOND"),
		"Monster resource scoring preserves exact public+own values, caps at eight, and redacts rival warehouses"
	)
	ai.set("_ai_monster_public_query_port", null)
	var disconnected_resource_score := ai._monster_resource_match_score(capped_probe, 0, 1)
	ai.set("_ai_monster_public_query_port", monster_public)
	_expect(disconnected_resource_score == 0, "Monster resource scoring fails closed when the required public query port is unavailable")

	var deploy_with_scoring_fields := {
		"name": "AI planner scoring probe",
		"kind": "military_force",
		"military_type": "bomber",
		"military_domain": "air",
		"military_deploy_terrain": "any",
		"movement_traits": ["air"],
		"terrain_move_multiplier": {"land": 1.0, "ocean": 1.0},
		"military_hp": 10,
		"military_damage": 2,
		"military_range": 100.0,
		"military_move": 50.0,
		"military_duration_seconds": 60.0,
		"military_gdp_penalty": 7,
		"military_strike_route_damage": 3,
	}
	var deploy_without_scoring_fields := deploy_with_scoring_fields.duplicate(true)
	deploy_without_scoring_fields["military_gdp_penalty"] = 0
	deploy_without_scoring_fields["military_strike_route_damage"] = 0
	var deploy_plan_with_fields := ai._ai_military_deploy_plan_for_district(1, deploy_with_scoring_fields, 1)
	var deploy_plan_without_fields := ai._ai_military_deploy_plan_for_district(1, deploy_without_scoring_fields, 1)
	var military_without_scoring_fields := public_unit_301.duplicate(true)
	military_without_scoring_fields["military_gdp_penalty"] = 0
	military_without_scoring_fields["military_strike_route_damage"] = 0
	var strike_plan_with_fields := ai._ai_military_strike_target(1, public_unit_301, 1000.0)
	var strike_plan_without_fields := ai._ai_military_strike_target(1, military_without_scoring_fields, 1000.0)


	_expect(
		int(deploy_plan_with_fields.get("district", -1)) == 1 \
			and int(deploy_plan_without_fields.get("district", -1)) == 1 \
			and str(deploy_plan_with_fields.get("military_deploy_role", "")) == "strike_rival_city" \
			and str(deploy_plan_without_fields.get("military_deploy_role", "")) == "strike_rival_city" \
			and int(deploy_plan_with_fields.get("score", 0)) - int(deploy_plan_without_fields.get("score", 0)) == 307,
		"formal Military deploy planner consumes public GDP and route-damage fields with the exact 307-point rival-city delta"
	)
	_expect(
		int(strike_plan_with_fields.get("district", -1)) == 1 \
			and int(strike_plan_without_fields.get("district", -1)) == 1 \
			and int(strike_plan_with_fields.get("score", 0)) - int(strike_plan_without_fields.get("score", 0)) == 251,
		"formal Military strike planner preserves the exact 251-point scoring-field delta on its selected rival district"
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
			and rng.capture_plan_checkpoint() == rng_before \
			and game_session.capture_new_session_checkpoint() == session_before \
			and not bool(game_session.session_summary().get("dirty", true)) \
			and public_log_owner.debug_snapshot() == public_log_owner_before \
			and public_log_port.debug_snapshot() == public_log_port_before \
			and visual_owner.debug_snapshot() == visual_cue_debug_before \
			and visual_owner.public_snapshot() == visual_cues_before,
		"pure Monster and Military queries produce zero owner, RNG, save-dirty, public-log attempt, or visual-cue delta"
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
	var rejected_missing_military_uid := military.trigger_command({
		"name": "缺失军令UID拒绝测试",
		"kind": "military_command",
		"military_command": "move",
	}, -1, 1, {"selected_district": 0})
	_expect(
		not rejected_monster_target \
			and not rejected_military_uid \
			and not rejected_missing_military_uid \
			and military.active_unit_for_player(1, 0).is_empty() \
			and monster.roster_snapshot(true) == stale_monster_before \
			and military.to_save_data() == stale_military_before \
			and rng.capture_plan_checkpoint() == stale_rng_before,
		"invalid frozen region and stale Military UID reject without owner mutation or RNG consumption"
	)

	var armor_before := int((monster.auto_monsters[0] as Dictionary).get("armor", 0))
	selection.selected_district = -1
	var direct_resolved := monster._trigger_auto_monster_card_command({
		"name": "冻结区域直接技能测试",
		"kind": "guard",
		"guard": 2,
	}, world.players[1] as Dictionary, 0, 0)
	_expect(
		direct_resolved \
			and int((monster.auto_monsters[0] as Dictionary).get("armor", 0)) == armor_before + 2 \
			and selection.selected_district == -1,
		"real Monster owner resolves the frozen region even after live UI focus drifts invalid"
	)

	var old_monster_capability := monster_cap_a
	var old_military_capability := military_cap_a
	var monster_capability_revision_before := int(monster_actor.debug_snapshot().get("capability_revision", -1))
	var military_capability_revision_before := int(military_actor.debug_snapshot().get("capability_revision", -1))
	var operation_sequence_before := int(game_session.capture_new_session_checkpoint().get("operation_sequence", -1))
	var rejected_save := game_session.request_save("user://test_runs/ai_monster_military_capability_probe.save", {}, {})
	var operation_sequence_after := int(game_session.capture_new_session_checkpoint().get("operation_sequence", -1))
	_expect(
		not bool(rejected_save.get("ok", true)) \
			and operation_sequence_after == operation_sequence_before + 1 \
			and int(monster_actor.debug_snapshot().get("capability_revision", -1)) == monster_capability_revision_before \
			and int(military_actor.debug_snapshot().get("capability_revision", -1)) == military_capability_revision_before \
			and not monster_actor.actor_roster_snapshot(old_monster_capability, 1).is_empty() \
			and not military_actor.actor_roster_snapshot(old_military_capability, 1).is_empty(),
		"save-operation bookkeeping cannot revoke stable Monster or Military actor capabilities"
	)
	var restarted := game_session.begin_session({
		"session_id": "ai-monster-military-query-next-session",
		"scenario_id": "focused-restarted",
		"seed": 8192,
		"player_count": 3,
	})
	var replacement_monster_capabilities := ai.get("_ai_monster_actor_capabilities") as Dictionary
	var replacement_military_capabilities := ai.get("_ai_military_actor_capabilities") as Dictionary
	var replacement_monster_capability := replacement_monster_capabilities.get(1) as AiMonsterActorCapability
	var replacement_military_capability := replacement_military_capabilities.get(1) as AiMilitaryActorCapability
	_expect(
		str(restarted.get("session_state", "")) == GameSessionRuntimeController.STATE_RUNNING \
			and replacement_monster_capability != old_monster_capability \
			and replacement_military_capability != old_military_capability \
			and int(monster_actor.debug_snapshot().get("capability_revision", -1)) == monster_capability_revision_before + 1 \
			and int(military_actor.debug_snapshot().get("capability_revision", -1)) == military_capability_revision_before + 1 \
			and monster_actor.actor_roster_snapshot(old_monster_capability, 1).is_empty() \
			and military_actor.actor_roster_snapshot(old_military_capability, 1).is_empty() \
			and not monster_actor.actor_roster_snapshot(replacement_monster_capability, 1).is_empty() \
			and not military_actor.actor_roster_snapshot(replacement_military_capability, 1).is_empty(),
		"new GameSession identity reissues capabilities exactly once and rejects both stale Monster/Military tokens"
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
	ai.set("_configured", false)
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
		"ai_memory": {
			"private_marker": marker,
			"decision_samples": [],
			"action_counts": {},
			"economic_focus_product": "星露莓",
			"economic_focus_cycle": 0,
			"economic_focus_score": 0,
		},
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
		"military_gdp_penalty": 7,
		"military_strike_route_damage": 3,
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
	var monster_public_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_monster_public_query_port.gd")
	var monster_actor_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_monster_actor_query_port.gd")
	var military_actor_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_military_actor_query_port.gd")
	for scene_name in [
		"AiMonsterPublicQueryPort.tscn",
		"AiMonsterActorQueryPort.tscn",
		"AiMilitaryPublicQueryPort.tscn",
		"AiMilitaryActorQueryPort.tscn",
	]:
		_expect(scene_source.contains(scene_name), "production coordinator composes %s" % scene_name)
	_expect(not ai_source.contains("var auto_monsters:") and not ai_source.contains("var military_units:"), "AI controller owns no broad Monster or Military roster property")
	_expect(
		not ai_source.contains("func _call_monster") \
			and not ai_source.contains("_call_monster(") \
			and not ai_source.contains("set_military_runtime_controller") \
			and monster_public_source.contains("func can_summon_at_region") \
			and monster_public_source.contains("func public_expected_damage_score") \
			and monster_public_source.contains("func public_region_attraction_snapshot"),
		"AI Monster queries use explicit typed methods with zero arbitrary Monster method dispatch"
	)
	_expect(
		monster_actor_source.contains("_session_identity_revision()") \
			and military_actor_source.contains("_session_identity_revision()") \
			and not monster_actor_source.contains("session_start_revision()") \
			and not military_actor_source.contains("session_start_revision()"),
		"actor capability fingerprints bind stable session identity and ignore save-operation sequence churn"
	)
	_expect(not ai_source.contains("owner_damage_cash_pool") or ai_source.contains("ownership_scope"), "AI scoring cannot use a rival Monster cash pool without actor authorization")
	_expect(
		router_source.contains("_summon_monster_from_card(player_index, skill, int(entry.get(\"selected_district\", -1)))") \
			and router_source.contains("_trigger_bound_monster_skill(skill, player, int(entry.get(\"selected_district\", -1)))") \
			and router_source.contains("summon_from_card(player_index, skill, int(entry.get(\"selected_district\", -1)))"),
		"card effect routing forwards the frozen queue region to Monster and Military owners"
	)
	_expect(
		not monster_source.contains("var target := selected_district") \
			and not monster_source.contains("var target: int = selected_district") \
			and monster_source.contains("var target := target_district_index") \
			and not monster_source.contains("target = _weighted_auto_monster_target(actor)") \
			and not military_source.contains("_world_bridge.table_selection_state()") \
			and military_source.contains("if bound_unit_uid <= 0:") \
			and not military_source.contains("unit_index < 0 and bound_unit_uid <= 0"),
		"card execution cannot re-read UI selection, resample an invalid frozen target, or reroute a missing or stale bound UID"
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