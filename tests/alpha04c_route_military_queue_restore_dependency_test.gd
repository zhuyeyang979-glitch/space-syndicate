extends SceneTree

const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const ROUTE_SCENE := preload("res://scenes/runtime/RouteNetworkRuntimeController.tscn")
const ROUTE_BRIDGE_SCENE := preload("res://scenes/runtime/RouteNetworkWorldBridge.tscn")
const INFRASTRUCTURE_SCENE := preload("res://scenes/runtime/RegionInfrastructureRuntimeController.tscn")
const MILITARY_SCENE := preload("res://scenes/runtime/MilitaryRuntimeController.tscn")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const EXECUTION_SCENE := preload("res://scenes/runtime/CardResolutionExecutionRuntimeService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _world_fixture()
	_test_route_dependencies(fixture)
	_test_military_dependencies(fixture)
	_test_queue_dependencies(fixture)
	_fixture_node(fixture, "route_bridge").queue_free()
	_fixture_node(fixture, "world_state").queue_free()
	_fixture_node(fixture, "infrastructure").queue_free()
	_finish()


func _world_fixture() -> Dictionary:
	var infrastructure := INFRASTRUCTURE_SCENE.instantiate() as RegionInfrastructureRuntimeController
	root.add_child(infrastructure)
	_expect(bool(infrastructure.configure(RULESET_PROFILE.debug_snapshot()).get("configured", false)), "Cross-section infrastructure fixture configures")
	_expect(bool(infrastructure.initialize_regions([
		{"region_id": "region.alpha", "terrain_id": "unknown", "neighbor_region_ids": ["region.beta"], "legacy_index": 0},
		{"region_id": "region.beta", "terrain_id": "unknown", "neighbor_region_ids": ["region.alpha"], "legacy_index": 1},
	]).get("initialized", false)), "Cross-section infrastructure fixture initializes")
	var facility_receipt := infrastructure.apply_facility_action({
		"transaction_id": "restore-dependency:facility",
		"region_id": "region.alpha",
		"owner_kind": "player",
		"owner_player_index": 0,
		"facility_type": "factory",
		"industry_id": "life",
		"rank": 2,
		"occurred_at": 1.0,
	})
	_expect(bool(facility_receipt.get("committed", false)), "Cross-section topology fixture seeds an active facility")
	_expect(bool(infrastructure.finalize_facility_action(facility_receipt).get("finalized", false)), "Cross-section topology fixture finalizes its facility lifecycle")
	var world_state := WorldSessionState.new()
	root.add_child(world_state)
	var districts := [
		{"region_id": "region.alpha", "terrain": "land", "city": {}},
		{"region_id": "region.beta", "terrain": "land", "city": {}},
	]
	world_state.districts = districts.duplicate(true)
	var route_bridge := ROUTE_BRIDGE_SCENE.instantiate() as RouteNetworkWorldBridge
	root.add_child(route_bridge)
	route_bridge.set_world_session_state(world_state)
	route_bridge.set_region_infrastructure_controller(infrastructure)
	return {
		"infrastructure": infrastructure,
		"world_state": world_state,
		"route_bridge": route_bridge,
		"infrastructure_state": infrastructure.to_save_data(),
		"session_state": {
			"game_session_runtime": {
				"ruleset_id": "v0.6",
				"session_id": "session.restore.dependencies",
				"scenario_id": "scenario.restore.dependencies",
				"seed": 1,
				"setup": {},
			},
			"world_session_state": {
				"players": [
					{"id": 0, "slots": [null, null]},
					{"id": 1, "slots": [null, null]},
					{"id": 2, "slots": [null, null]},
				],
				"districts": districts.duplicate(true),
			},
		},
		"weather_state": _empty_weather_state(),
	}


func _test_route_dependencies(fixture: Dictionary) -> void:
	var routes := ROUTE_SCENE.instantiate() as RouteNetworkRuntimeController
	root.add_child(routes)
	routes.set_world_bridge(_fixture_node(fixture, "route_bridge"))
	_expect(bool(routes.configure(RULESET_PROFILE.debug_snapshot()).get("configured", false)), "Routes dependency fixture configures")
	_expect(bool(routes.refresh_routes(true).get("rebuilt", false)), "Routes dependency fixture builds its live reference manifest")
	var saved := routes.to_save_data()
	var all_states := _base_states(fixture)
	var accepted := _dependency_receipt_is_pure(routes, saved, all_states)
	_expect(bool(accepted.get("accepted", false)) \
		and str(accepted.get("topology_revision", "")) == str(saved.get("saved_topology_revision", "")), "Routes accept a candidate-only topology and manifest match")
	var valid_weather := all_states.duplicate(true)
	(valid_weather.get("weather") as Dictionary)["events"] = [{"region_indices": [1], "districts": [1]}]
	var weather_accepted := _dependency_receipt_is_pure(routes, saved, valid_weather)
	_expect(bool(weather_accepted.get("accepted", false)) \
		and int(weather_accepted.get("weather_reference_count", 0)) == 1, "Routes validate candidate weather references without folding weather into the base manifest")
	var forged_manifest := saved.duplicate(true)
	forged_manifest["rebuilt_route_fingerprint"] = "0".repeat(64)
	_expect_dependency_rejected_without_mutation(routes, forged_manifest, all_states, "Routes reject a candidate-only rebuilt manifest mismatch")

	var changed_infrastructure := all_states.duplicate(true)
	var infrastructure_state := changed_infrastructure.get("region_infrastructure") as Dictionary
	((infrastructure_state.get("regions") as Array)[0] as Dictionary)["revision"] = 99
	_expect_dependency_rejected_without_mutation(routes, saved, changed_infrastructure, "Routes reject a candidate infrastructure topology revision mismatch")
	var changed_session := all_states.duplicate(true)
	var world_state := (changed_session.get("session") as Dictionary).get("world_session_state") as Dictionary
	((world_state.get("districts") as Array)[0] as Dictionary)["terrain"] = "ocean"
	_expect_dependency_rejected_without_mutation(routes, saved, changed_session, "Routes include candidate session terrain in the topology revision")
	var changed_weather := all_states.duplicate(true)
	(changed_weather.get("weather") as Dictionary)["events"] = [{"region_indices": [99], "districts": [99]}]
	_expect_dependency_rejected_without_mutation(routes, saved, changed_weather, "Routes reject dangling candidate weather region references")
	var missing_weather := all_states.duplicate(true)
	missing_weather.erase("weather")
	_expect_dependency_rejected_without_mutation(routes, saved, missing_weather, "Routes fail closed when the weather dependency is missing")
	routes.queue_free()


func _test_military_dependencies(fixture: Dictionary) -> void:
	var military := MILITARY_SCENE.instantiate() as MilitaryRuntimeController
	root.add_child(military)
	var state := military.to_save_data()
	state["military_units"] = [_military_unit(1)]
	state["next_military_unit_uid"] = 2
	var all_states := _base_states(fixture)
	var accepted := _dependency_receipt_is_pure(military, state, all_states)
	_expect(bool(accepted.get("accepted", false)) and int(accepted.get("referenced_unit_count", 0)) == 1, "Military resolves a saved unit against candidate player, district, and region rosters")

	var missing_owner := state.duplicate(true)
	((missing_owner.get("military_units") as Array)[0] as Dictionary)["owner"] = 9
	_expect_dependency_rejected_without_mutation(military, missing_owner, all_states, "Military rejects a unit owner absent from the candidate player roster")
	var missing_district := state.duplicate(true)
	((missing_district.get("military_units") as Array)[0] as Dictionary)["position"] = 9
	_expect_dependency_rejected_without_mutation(military, missing_district, all_states, "Military rejects a unit district absent from candidate session and infrastructure")
	var mismatched_region := all_states.duplicate(true)
	var session_world := (mismatched_region.get("session") as Dictionary).get("world_session_state") as Dictionary
	((session_world.get("districts") as Array)[0] as Dictionary)["region_id"] = "region.other"
	_expect_dependency_rejected_without_mutation(military, state, mismatched_region, "Military rejects candidate district-to-region identity drift")
	var dangling_motion := state.duplicate(true)
	var moving_unit := (dangling_motion.get("military_units") as Array)[0] as Dictionary
	moving_unit.merge({
		"linear_move_target_position": Vector2(200.0, 100.0),
		"linear_move_target_district": 9,
		"linear_move_speed_mps": 10.0,
		"linear_move_source": "test",
		"linear_move_mode": "land",
		"linear_move_damaged_districts": [],
		"linear_move_started_at": 1.0,
		"linear_move_arrival_action": "military_move",
	}, true)
	_expect(bool(military.preflight_save_data(dangling_motion).get("accepted", false)), "Military local preflight leaves cross-section motion references to dependency preflight")
	_expect_dependency_rejected_without_mutation(military, dangling_motion, all_states, "Military rejects a dangling candidate motion target")
	var dangling_journal := state.duplicate(true)
	(dangling_journal.get("bankruptcy_estate_journal") as Dictionary)["estate:test"] = {
		"state": "finalized",
		"player_indices": [9],
		"expected_hash": "0".repeat(64),
		"estate_counts": {"military_units_removed": 0},
	}
	_expect(bool(military.preflight_save_data(dangling_journal).get("accepted", false)), "Military local preflight accepts structurally valid bankruptcy lineage")
	_expect_dependency_rejected_without_mutation(military, dangling_journal, all_states, "Military rejects bankruptcy lineage for an absent candidate player")
	military.queue_free()


func _test_queue_dependencies(fixture: Dictionary) -> void:
	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	root.add_child(queue)
	queue.configure({"ruleset_id": "v0.6", "card_group": RULESET_PROFILE.card_group_rules()})
	var plan := queue.plan_submission(_queue_request(), {"player_count": 3, "simultaneous_timer": 45.0, "window_sequence": 0})
	queue.commit_submission(plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	})
	var state := queue.to_save_data()
	var all_states := _base_states(fixture)
	var accepted := _dependency_receipt_is_pure(queue, state, all_states)
	_expect(bool(accepted.get("accepted", false)) and int(accepted.get("queue_reference_count", 0)) == 1, "Queue resolves a consumed card against the candidate player and slot roster")

	var missing_player := state.duplicate(true)
	((missing_player.get("current_queue") as Array)[0] as Dictionary)["player_index"] = 9
	_expect_dependency_rejected_without_mutation(queue, missing_player, all_states, "Queue rejects a candidate player reference outside the restored roster")
	var missing_slot := state.duplicate(true)
	((missing_slot.get("current_queue") as Array)[0] as Dictionary)["slot_index"] = 9
	_expect_dependency_rejected_without_mutation(queue, missing_slot, all_states, "Queue rejects a candidate slot outside the restored player inventory")
	var persistent_missing := state.duplicate(true)
	((persistent_missing.get("current_queue") as Array)[0] as Dictionary)["consumed_on_queue"] = false
	_expect_dependency_rejected_without_mutation(queue, persistent_missing, all_states, "Queue requires a non-consumed card to remain queued in the candidate slot")

	var completed_overlap := all_states.duplicate(true)
	(completed_overlap.get("card_resolution_execution") as Dictionary)["completed_resolution_ids"] = [1]
	_expect_dependency_rejected_without_mutation(queue, state, completed_overlap, "Queue rejects an execution-completed resolution that remains queued")
	var execution_ahead := all_states.duplicate(true)
	(execution_ahead.get("card_resolution_execution") as Dictionary)["completed_resolution_ids"] = [2]
	_expect_dependency_rejected_without_mutation(queue, state, execution_ahead, "Queue rejects execution lineage ahead of its authoritative resolution cursor")

	var terminal_state := state.duplicate(true)
	terminal_state["current_queue"] = []
	var terminal_states := all_states.duplicate(true)
	(terminal_states.get("card_resolution_execution") as Dictionary)["completed_resolution_ids"] = [1]
	(terminal_states.get("card_resolution_history") as Dictionary)["appended_resolution_ids"] = [1]
	(terminal_states.get("card_resolution_history") as Dictionary)["history"] = [{"resolution_id": 1}]
	var terminal_accepted := _dependency_receipt_is_pure(queue, terminal_state, terminal_states)
	_expect(bool(terminal_accepted.get("accepted", false)), "Queue accepts history backed by completed execution lineage")
	var orphan_history := terminal_states.duplicate(true)
	(orphan_history.get("card_resolution_execution") as Dictionary)["completed_resolution_ids"] = []
	_expect_dependency_rejected_without_mutation(queue, terminal_state, orphan_history, "Queue rejects history without completed or history-appended inflight execution lineage")

	var active_state := state.duplicate(true)
	active_state["active_entry"] = ((active_state.get("current_queue") as Array)[0] as Dictionary).duplicate(true)
	active_state["current_queue"] = []
	var execution := EXECUTION_SCENE.instantiate() as CardResolutionExecutionRuntimeService
	root.add_child(execution)
	execution.configure()
	execution.plan_execution({
		"active_entry": (active_state.get("active_entry") as Dictionary).duplicate(true),
		"skill": ((active_state.get("active_entry") as Dictionary).get("skill") as Dictionary).duplicate(true),
	})
	var active_states := all_states.duplicate(true)
	active_states["card_resolution_execution"] = execution.to_save_data()
	var active_accepted := _dependency_receipt_is_pure(queue, active_state, active_states)
	_expect(bool(active_accepted.get("accepted", false)), "Queue accepts an active entry bound to candidate inflight execution lineage")
	var forged_active := active_states.duplicate(true)
	(((forged_active.get("card_resolution_execution") as Dictionary).get("inflight_execution_transactions") as Array)[0] as Dictionary)["entry_fingerprint"] = "0".repeat(64)
	_expect_dependency_rejected_without_mutation(queue, active_state, forged_active, "Queue rejects an active entry fingerprint mismatch in candidate execution lineage")
	execution.queue_free()
	queue.queue_free()


func _base_states(fixture: Dictionary) -> Dictionary:
	return {
		"region_infrastructure": (fixture.get("infrastructure_state") as Dictionary).duplicate(true),
		"session": (fixture.get("session_state") as Dictionary).duplicate(true),
		"player_mana": {
			"reservations": {},
			"terminal_receipts": {},
			"pools_by_player": {},
		},
		"weather": (fixture.get("weather_state") as Dictionary).duplicate(true),
		"card_resolution_execution": _empty_execution_state(),
		"card_resolution_history": _empty_history_state(),
	}


func _empty_weather_state() -> Dictionary:
	return {"events": [], "queue": [], "history": [], "region_history": {}}


func _empty_execution_state() -> Dictionary:
	return {
		"completed_resolution_ids": [],
		"inflight_resolution_ids": [],
		"inflight_execution_transactions": [],
		"pending_settlements": [],
	}


func _empty_history_state() -> Dictionary:
	return {"history": [], "appended_resolution_ids": []}


func _military_unit(uid: int) -> Dictionary:
	return {
		"uid": uid,
		"owner": 0,
		"position": 0,
		"world_position": Vector2(120.0, 80.0),
		"cooldown_left": 1.5,
		"public_owner_revealed": false,
		"rank": 1,
		"name": "行星防卫军",
		"source_card": "行星防卫军1",
		"military_type": "defense",
		"military_domain": "mixed",
		"movement_traits": ["land"],
		"terrain_move_multiplier": {"land": 1.0, "ocean": 0.25},
		"military_gdp_penalty": 0,
		"military_gdp_pressure_seconds": 0.0,
		"military_strike_gdp_penalty": 0,
		"military_strike_route_damage": 0,
		"hp": 8,
		"max_hp": 8,
		"damage": 1,
		"range": 220.0,
		"move": 260.0,
		"duration": 28.0,
		"remaining_time": 24.0,
	}


func _queue_request() -> Dictionary:
	return {
		"player_index": 0,
		"slot_index": 0,
		"already_queued": false,
		"available_cash_cents": 50000,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"financial_terms_version": "none",
		"cash_revision": "cash:0",
		"skill": {"name": "测试策略", "kind": "strategy", "rank": 1, "persistent": false},
	}


func _dependency_receipt_is_pure(owner: Node, section_state: Dictionary, all_states: Dictionary) -> Dictionary:
	var owner_before: Dictionary = owner.call("capture_runtime_checkpoint")
	var section_before := section_state.duplicate(true)
	var all_before := all_states.duplicate(true)
	var receipt: Dictionary = owner.call("preflight_restore_dependencies", section_state, all_states)
	_expect(owner.call("capture_runtime_checkpoint") == owner_before \
		and section_state == section_before and all_states == all_before, "%s dependency preflight has zero owner/input mutation" % owner.name)
	return receipt


func _expect_dependency_rejected_without_mutation(
	owner: Node,
	section_state: Dictionary,
	all_states: Dictionary,
	message: String
) -> void:
	var receipt := _dependency_receipt_is_pure(owner, section_state, all_states)
	_expect(not bool(receipt.get("accepted", true)) and not str(receipt.get("reason_code", "")).is_empty(), message)


func _fixture_node(fixture: Dictionary, key: String) -> Node:
	return fixture.get(key) as Node


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("RESTORE_DEPENDENCY_PREFLIGHT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if passed else "FAIL", _checks, _failures.size()])
	if not passed:
		push_error("Restore dependency failures: %s" % JSON.stringify(_failures))
	quit(0 if passed else 1)
