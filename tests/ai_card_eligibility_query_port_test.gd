extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const BATTLE_LIFECYCLE_POLICY := preload("res://scripts/runtime/monster_battle_lifecycle_policy_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	var session := coordinator.get_node_or_null(
		"GameSessionRuntimeController"
	) as GameSessionRuntimeController
	var world := coordinator.world_session_state()
	var ai := coordinator.get_node_or_null(
		"AiRuntimeController"
	) as AiRuntimeController
	var port := coordinator.get_node_or_null(
		"AiCardEligibilityQueryPort"
	) as AiCardEligibilityQueryPort
	var bridge := coordinator.get_node_or_null(
		"CardPlayEligibilityWorldBridge"
	) as CardPlayEligibilityWorldBridge
	var service := coordinator.get_node_or_null(
		"CardPlayEligibilityRuntimeService"
	) as CardPlayEligibilityRuntimeService
	var flow := coordinator.get_node_or_null(
		"CommodityFlowRuntimeController"
	) as CommodityFlowRuntimeController
	var mana := coordinator.get_node_or_null(
		"PlayerManaRuntimeController"
	) as PlayerManaRuntimeController
	var selection := coordinator.get_node_or_null(
		"TableSelectionState"
	) as TableSelectionState
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	var queue := coordinator.get_node_or_null(
		"CardResolutionQueueRuntimeService"
	) as CardResolutionQueueRuntimeService
	var monster := coordinator.get_node_or_null(
		"MonsterRuntimeController"
	) as MonsterRuntimeController
	var cash_commitment := coordinator.get_node_or_null(
		"MonsterWagerCashCommitmentQueryPort"
	) as MonsterWagerCashCommitmentQueryPort
	_expect(
		session != null and world != null and ai != null and port != null
			and bridge != null and service != null and flow != null
			and mana != null and selection != null and rng != null
			and queue != null and monster != null and cash_commitment != null,
		"production composition owns eligibility query and existing authorities"
	)
	coordinator.configure({"ruleset_id": "v0.4"})
	session.configure({"ruleset_id": "v0.6"}, {})
	world.restore({
		"players": [
			_player("Human", false, 999),
			_player("AI-A", true, 500),
			_player("AI-B", true, 50),
		],
		"districts": [
			_district("region:a", "Region A"),
			_district("region:b", "Region B"),
		],
		"game_time": 12.0,
	}, true)
	session.begin_session({
		"session_id": "ai-card-eligibility-focused",
		"scenario_id": "focused",
		"seed": 149,
		"player_count": 3,
	})
	selection.selected_district = 1
	var flow_state := flow.to_save_data()
	flow_state["current_game_time"] = 12.0
	flow_state["receipt_sequence"] = 4
	flow_state["recent_sale_receipts"] = [
		_sale_receipt("receipt:a:ai", "region:a", 1, 5000),
		_sale_receipt("receipt:a:rival", "region:a", 2, 5000),
		_sale_receipt("receipt:b:ai", "region:b", 1, 10000),
		_sale_receipt("receipt:b:rival", "region:b", 2, 10000),
	]
	var flow_applied := flow.apply_save_data(flow_state)
	_expect(
		bool(flow_applied.get("applied", false)),
		"focused flow fixture applies through the authoritative save contract"
	)
	var capabilities := ai.get(
		"_ai_card_eligibility_capabilities"
	) as Dictionary
	var actor_capability := capabilities.get(1) as AiCardEligibilityCapability
	var rival_capability := capabilities.get(2) as AiCardEligibilityCapability
	_expect(
		capabilities.size() == 2 and not capabilities.has(0)
			and actor_capability != null and rival_capability != null,
		"composition issues eligibility capabilities only to current AI seats"
	)
	var skill := _skill(100)
	var world_before := world.to_save_data()
	var session_before := session.to_save_data()
	var queue_before := _queue_state(queue)
	var flow_before := flow.to_save_data()
	var mana_before := mana.to_save_data()
	var selection_before := selection.snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var actor_receipt := port.eligibility_snapshot(
		actor_capability,
		1,
		skill,
		"rule",
		-1
	)
	var rival_receipt := port.eligibility_snapshot(
		rival_capability,
		2,
		skill,
		"rule",
		-1
	)
	_expect(
		bool(actor_receipt.get("allowed", false))
			and str(actor_receipt.get("reason_code", "")) == "playable"
			and int(actor_receipt.get("actor_index", -1)) == 1
			and int(actor_receipt.get("selected_district", 99)) == -1,
		"actor receives a scoped eligibility receipt with explicit target context"
	)
	_expect(
		not bool(rival_receipt.get("allowed", true))
			and str(rival_receipt.get("reason_code", "")) == "cash_insufficient"
			and int(rival_receipt.get("actor_index", -1)) == 2,
		"each AI receives eligibility derived from only its own private cash"
	)
	var wager := _wager(21, 1, 500, 100, 20)
	monster.active_monster_wagers = [wager]
	monster.set("_monster_wager_settlement_revision", 1)
	var wager_state_before := monster.to_save_data()
	var reserved_cash := cash_commitment.private_cash_availability_snapshot(1)
	var reserved_skill := _skill(450)
	var reserved_receipt := port.eligibility_snapshot(
		actor_capability,
		1,
		reserved_skill,
		"rule",
		-1
	)
	_expect(
		int(reserved_cash.get("total_cents", -1)) == 50000
			and int(reserved_cash.get("reserved_cents", -1)) == 10000
			and int(reserved_cash.get("available_cents", -1)) == 40000
			and not bool(reserved_receipt.get("allowed", true))
			and str(reserved_receipt.get("reason_code", ""))
			== "cash_insufficient",
		"unresolved monster wager cash is unavailable to AI card eligibility"
	)
	_expect(
		monster.to_save_data() == wager_state_before,
		"wager-aware eligibility query leaves the commitment owner unchanged"
	)
	monster.active_monster_wagers = []
	monster.set("_monster_wager_settlement_revision", 0)
	var bridge_build_count_before_rejections := int(
		bridge.debug_snapshot().get("build_count", -1)
	)
	var service_evaluation_count_before_rejections := int(
		service.debug_snapshot().get("evaluation_count", -1)
	)
	_expect(
		port.eligibility_snapshot(
			rival_capability,
			1,
			skill,
			"rule",
			-1
		).is_empty()
			and port.eligibility_snapshot(
				AiCardEligibilityCapability.new(),
				1,
				skill,
				"rule",
				-1
			).is_empty()
			and port.eligibility_snapshot(
				actor_capability,
				0,
				skill,
				"rule",
				-1
			).is_empty(),
		"rival, forged, and human capability queries fail closed"
	)
	_expect(
		int(bridge.debug_snapshot().get("build_count", -2))
			== bridge_build_count_before_rejections
			and int(service.debug_snapshot().get("evaluation_count", -2))
			== service_evaluation_count_before_rejections,
		"rejected capabilities fail before reading facts or evaluating rules"
	)
	var requirement := port.requirement_snapshot(
		actor_capability,
		1,
		skill,
		-1
	)
	_expect(
		requirement.get("requirement_status", {}) is Dictionary
			and int(requirement.get("cash_cost", -1)) == 100
			and int(requirement.get("actor_index", -1)) == 1,
		"requirement query returns a narrow actor-scoped receipt"
	)
	var target_region_skill := _skill(0)
	target_region_skill["kind"] = "city_revenue_boost"
	target_region_skill["play_region_scope"] = "target_region"
	var explicit_requirement := port.requirement_snapshot(
		actor_capability,
		1,
		target_region_skill,
		0
	)
	var explicit_status: Dictionary = explicit_requirement.get(
		"requirement_status",
		{}
	) if explicit_requirement.get("requirement_status", {}) is Dictionary else {}
	_expect(
		int(explicit_requirement.get("selected_district", -1)) == 0
			and int(explicit_status.get("qualifying_district", -1)) == 0
			and selection.selected_district == 1,
		"explicit district zero overrides the different UI-selected district"
	)
	var facility_skill := _skill(0)
	facility_skill["kind"] = "public_facility"
	facility_skill["card_id"] = "facility:test"
	var facility_receipt := port.eligibility_snapshot(
		actor_capability,
		1,
		facility_skill,
		"rule",
		-1
	)
	_expect(
		str(facility_receipt.get("reason_code", ""))
			== "public_facility_target_unavailable"
			and int(facility_receipt.get("selected_district", 99)) == -1
			and selection.selected_district == 1,
		"explicit minus-one district never falls back to TableSelectionState"
	)
	var best_share := port.best_share_snapshot(actor_capability, 1)
	_expect(
		int(best_share.get("selected_district", 99)) == -1
			and int(best_share.get("best_share_district", -1)) == 1
			and not best_share.has("facts")
			and not best_share.has("districts"),
		"best-share query exposes only its narrow receipt"
	)
	var equal_gdp_state := flow.to_save_data()
	equal_gdp_state["receipt_sequence"] = 8
	equal_gdp_state["recent_sale_receipts"] = [
		_sale_receipt("receipt:equal:a:ai", "region:a", 1, 5000),
		_sale_receipt("receipt:equal:a:rival", "region:a", 2, 5000),
		_sale_receipt("receipt:equal:b:ai", "region:b", 1, 5000),
		_sale_receipt("receipt:equal:b:rival", "region:b", 2, 5000),
	]
	var equal_gdp_applied := flow.apply_save_data(equal_gdp_state)
	var equal_gdp_best := port.best_share_snapshot(actor_capability, 1)
	_expect(
		bool(equal_gdp_applied.get("applied", false))
			and int(equal_gdp_best.get("best_share_district", -1)) == 0,
		"equal share and GDP preserve the earliest district index"
	)
	var higher_share_state := flow.to_save_data()
	higher_share_state["receipt_sequence"] = 12
	higher_share_state["recent_sale_receipts"] = [
		_sale_receipt("receipt:share:a:ai", "region:a", 1, 9000),
		_sale_receipt("receipt:share:a:rival", "region:a", 2, 1000),
		_sale_receipt("receipt:share:b:ai", "region:b", 1, 6000),
		_sale_receipt("receipt:share:b:rival", "region:b", 2, 14000),
	]
	var higher_share_applied := flow.apply_save_data(higher_share_state)
	var higher_share_best := port.best_share_snapshot(actor_capability, 1)
	_expect(
		bool(higher_share_applied.get("applied", false))
			and int(higher_share_best.get("best_share_district", -1)) == 0,
		"higher GDP share wins before region GDP"
	)
	var original_flow_restored := flow.apply_save_data(flow_before)
	_expect(
		bool(original_flow_restored.get("applied", false))
			and flow.to_save_data() == flow_before,
		"tie-break characterization restores the original flow fixture"
	)
	for receipt in [actor_receipt, requirement, facility_receipt, best_share]:
		_expect(
			TablePresentationPureDataPolicy.is_pure_data(receipt)
				and not _contains_any_key(receipt, [
					"facts",
					"players",
					"districts",
					"share_basis_points_by_district",
					"current_queue",
					"next_queue",
					"active_entry",
				]),
			"actor receipt exposes no raw owner facts or object values"
		)
	var expected_facts := bridge.build_facts(
		1,
		skill,
		{"selected_district": -1}
	)
	expected_facts["commodity_color_flow"] = flow.player_color_flow_snapshot(1)
	expected_facts["player_mana"] = mana.availability_snapshot_read_only(1)
	var expected := service.evaluate_play({
		"player_index": 1,
		"skill": skill,
		"evaluation_mode": "rule",
	}, expected_facts)
	_expect(
		bool(expected.get("allowed", false))
			== bool(actor_receipt.get("allowed", false))
			and str(expected.get("reason_code", ""))
			== str(actor_receipt.get("reason_code", ""))
			and int(expected.get("cash_cost", -1))
			== int(actor_receipt.get("cash_cost", -2))
			and expected.get("requirement_status", {})
			== actor_receipt.get("requirement_status", {}),
		"typed query preserves the authoritative bridge and service result"
	)
	_expect(
		world.to_save_data() == world_before
			and session.to_save_data() == session_before
			and _queue_state(queue) == queue_before
			and flow.to_save_data() == flow_before
			and mana.to_save_data() == mana_before
			and selection.snapshot() == selection_before
			and rng.capture_plan_checkpoint() == rng_before,
		"eligibility queries mutate no gameplay, save-owned, selection, or RNG state"
	)
	var old_capability := actor_capability
	world.replace_players(world.players.duplicate(true), true)
	capabilities = ai.get("_ai_card_eligibility_capabilities") as Dictionary
	actor_capability = capabilities.get(1) as AiCardEligibilityCapability
	_expect(
		actor_capability != null and actor_capability != old_capability
			and port.eligibility_snapshot(
				old_capability,
				1,
				skill,
				"rule",
				-1
			).is_empty()
			and not port.eligibility_snapshot(
				actor_capability,
				1,
				skill,
				"rule",
				-1
			).is_empty(),
		"roster replacement revokes and reissues eligibility capabilities"
	)
	var prior_session_capability := actor_capability
	var prior_session_receipt := port.eligibility_snapshot(
		prior_session_capability,
		1,
		skill,
		"rule",
		-1
	)
	session.begin_session({
		"session_id": "ai-card-eligibility-next-session",
		"scenario_id": "focused",
		"seed": 151,
		"player_count": 3,
	})
	_expect(
		port.eligibility_snapshot(
			prior_session_capability,
			1,
			skill,
			"rule",
			-1
		).is_empty(),
		"same-roster capability expires when session identity changes"
	)
	capabilities = ai.get("_ai_card_eligibility_capabilities") as Dictionary
	actor_capability = capabilities.get(1) as AiCardEligibilityCapability
	var next_session_receipt := port.eligibility_snapshot(
		actor_capability,
		1,
		skill,
		"rule",
		-1
	)
	_expect(
		actor_capability != null
			and actor_capability != prior_session_capability
			and not next_session_receipt.is_empty()
			and str(next_session_receipt.get("state_revision", ""))
			!= str(prior_session_receipt.get("state_revision", "")),
		"new session reissues capability and receipt revision"
	)
	var ai_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_runtime_controller.gd"
	)
	for forbidden in [
		"_call_world(&\"_best_player_gdp_share_district\"",
		"_call_world(&\"_card_play_requirement_snapshot\"",
		"_call_world(&\"_card_play_eligibility_snapshot\"",
		"_call_world(&\"_log_card_play_rejection\"",
	]:
		_expect(
			not ai_source.contains(forbidden),
			"AI source retires %s" % forbidden
		)
	var port_source := FileAccess.get_file_as_string(
		"res://scripts/runtime/ai_card_eligibility_query_port.gd"
	)
	_expect(
		not port_source.contains("TableSelectionState")
			and not port_source.contains("scripts/main.gd")
			and not port_source.contains("request_run_save")
			and not port_source.contains("write_save"),
		"eligibility port has no UI selection, Main, or save dependency"
	)
	var debug := port.debug_snapshot()
	_expect(
		bool(debug.get("port_ready", false))
			and int(debug.get("actor_scoped_capability_count", 0)) == 2
			and bool(debug.get("session_scoped_capabilities", false))
			and str(debug.get("best_share_tie_break", ""))
			== "share_then_region_gdp_then_earliest_index"
			and bool(debug.get("uses_read_only_player_mana", false))
			and bool(debug.get("returns_actor_receipts_only", false))
			and not bool(debug.get("returns_raw_facts", true))
			and not bool(debug.get("reads_table_selection", true))
			and not bool(debug.get("mutates_world", true))
			and not bool(debug.get("consumes_rng", true))
			and not bool(debug.get("references_main", true))
			and not bool(debug.get("owns_state", true)),
		"debug evidence records actor scope, zero mutation, zero RNG, and zero Main"
	)
	coordinator.queue_free()
	await process_frame
	_finish()


func _player(name: String, is_ai: bool, cash: int) -> Dictionary:
	return {
		"id": name.hash(),
		"actor_id": "actor:%s" % name,
		"name": name,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"cash": cash,
		"cash_cents": cash * 100,
		"action_cooldown": 0.0,
		"slots": [],
		"role_card": {},
		"ai_profile": {},
		"ai_memory": {},
	}


func _district(region_id: String, name: String) -> Dictionary:
	return {
		"region_id": region_id,
		"name": name,
		"terrain": "land",
		"destroyed": false,
	}


func _queue_state(queue: CardResolutionQueueRuntimeService) -> Dictionary:
	return {
		"active": queue.active_entry(),
		"current": queue.current_queue(),
		"next": queue.next_queue(),
		"debug": queue.debug_snapshot(),
	}


func _sale_receipt(
	receipt_id: String,
	region_id: String,
	owner_index: int,
	gdp_value: int
) -> Dictionary:
	return {
		"receipt_id": receipt_id,
		"units": 1,
		"commodity_id": "commodity:test",
		"source_region_id": "region:source",
		"market_region_id": region_id,
		"base_unit_price_cents": gdp_value,
		"unit_price_cents": gdp_value,
		"distance_premium_basis_points": 0,
		"commodity_owner": owner_index,
		"settled_at": 12.0,
		"gdp_value": gdp_value,
	}


func _wager(
	wager_id: int,
	revision: int,
	opening_cash_units: int,
	stake_units: int,
	stake_percent: int
) -> Dictionary:
	var competitors := [
		{"side": "a", "name": "Monster A", "slot": 0, "uid": 100, "damage": 2},
		{"side": "b", "name": "Monster B", "slot": 1, "uid": 101, "damage": 1},
	]
	return {
		"wager_id": wager_id,
		"settlement_revision": revision,
		"base_percent": 5,
		"competitors": competitors,
		"damage_a": 2,
		"damage_b": 1,
		"bets": {
			"1": {
				"player_index": 1,
				"side": "a",
				"stake": stake_units,
				"stake_percent": stake_percent,
				"forced": false,
			},
		},
		"public_bets": [],
		"historical_public_pool": 0,
		"eligible_player_indices": [1],
		"opening_cash_units_by_player": {"1": opening_cash_units},
		"public_player_ids_by_index": {"1": "player.1"},
		"lifecycle_schema_version": BATTLE_LIFECYCLE_POLICY.SCHEMA_VERSION,
		"lifecycle_phase": BATTLE_LIFECYCLE_POLICY.PHASE_DECISION,
		"lifecycle_revision": 1,
		"decision_remaining_seconds": 15.0,
		"battle_limit_seconds": 60.0,
		"battle_remaining_seconds": 60.0,
		"locked_competitor_uids": [100, 101],
		"battle_roster_fingerprint":
			BATTLE_LIFECYCLE_POLICY.roster_fingerprint(competitors),
		"opening_attack_applied": true,
		"decision_open": true,
		"resolved": false,
	}


func _skill(play_cash: int) -> Dictionary:
	return {
		"schema_version": "v0.6",
		"card_id": "card:eligibility-focused",
		"name": "Eligibility Focused Card",
		"kind": "cash_gain",
		"play_cash": play_cash,
		"asset_cost": {
			"life": 0,
			"energy": 0,
			"industry": 0,
			"technology": 0,
			"commerce": 0,
			"shipping": 0,
			"generic": 0,
		},
	}


func _contains_any_key(value: Variant, forbidden: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if (
				forbidden.has(str(key_variant))
				or _contains_any_key(
					(value as Dictionary)[key_variant],
					forbidden
				)
			):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_any_key(item, forbidden):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI card eligibility query port passed (%d checks)." % _checks)
		print("AI_CARD_ELIGIBILITY_QUERY_PORT_COMPLETE")
		quit(0)
		return
	push_error(
		"AI card eligibility query port failures:\n- "
		+ "\n- ".join(_failures)
	)
	quit(1)
