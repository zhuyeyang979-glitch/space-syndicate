extends SceneTree

const COORDINATOR_SCENE := preload("res://scenes/runtime/GameRuntimeCoordinator.tscn")
const CARD_OWNER_SCENE := preload("res://scenes/runtime/CardInventorySaveOwner.tscn")
const BELT_OWNER_SCENE := preload("res://scenes/runtime/CommodityBeltVisibilitySaveOwner.tscn")
const RULESET_V04 := preload("res://resources/rules/space_syndicate_ruleset_v04.tres")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var coordinator := COORDINATOR_SCENE.instantiate() as GameRuntimeCoordinator
	root.add_child(coordinator)
	await process_frame
	coordinator.configure(RULESET_V04.debug_snapshot())
	var world := coordinator.world_session_state()
	var catalog := coordinator.get_node_or_null("RoleCatalogRuntimeService") as RoleCatalogRuntimeService
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var ai_port := coordinator.get_node_or_null("AiActorStatePort") as AiActorStatePort
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	_expect(world != null and catalog != null and session != null and ai != null and ai_port != null and rng != null, "production save-owner dependencies exist")
	if world == null or catalog == null or session == null or ai == null or ai_port == null or rng == null:
		_finish()
		return

	session.configure({"ruleset_id": "v0.6"}, {})
	session.begin_session({"session_id": "alpha04c-save-owner", "scenario_id": "focused", "seed": 904, "player_count": 4})
	world.restore({
		"players": [
			_player(catalog, 0, false, "human"),
			_player(catalog, 1, true, "ai-one"),
			_player(catalog, 2, true, "ai-two"),
			_player(catalog, 3, false, "human-two"),
		],
		"districts": [],
		"game_time": 12.0,
		"map_width_m": 1000.0,
		"map_height_m": 600.0,
		"world_geometry_revision": 2,
	}, true)

	await _verify_card_and_belt_owners(coordinator, world)
	_verify_ai_owner(ai, ai_port, world, rng)
	coordinator.queue_free()
	await process_frame
	_finish()


func _verify_card_and_belt_owners(coordinator: GameRuntimeCoordinator, world: WorldSessionState) -> void:
	var commodity := coordinator.commodity_card_inventory_runtime_controller()
	var product_market := coordinator.get_node_or_null("ProductMarketRuntimeController") as ProductMarketRuntimeController
	var district_purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") as DistrictPurchaseRuntimeController
	_expect(commodity != null and product_market != null and district_purchase != null, "card-inventory child owners exist")
	if commodity == null or product_market == null or district_purchase == null:
		return
	var card: Dictionary = commodity.catalog().call("card_snapshot", "commodity.star_dew_berry.rank_1")
	var configured := commodity.configure_belt(7, [{
		"item_id": "belt:alpha",
		"card": card,
		"claimable": true,
		"visible_actor_ids": ["player.2", "player.1"],
	}])
	_expect(bool(configured.get("configured", false)), "real CardFlow belt fixture configures")
	var player_before := commodity.player_snapshot("player.1")
	var claim := commodity.claim_belt_card(
		"player.1",
		"belt:alpha",
		int(player_before.get("revision", -1)),
		7,
		"alpha04c:claim"
	)
	_expect(bool(claim.get("committed", false)) and (world.players[1] as Dictionary).get("slots", []).size() == 1, "real transaction creates a World-owned card instance and journal receipt")
	commodity.configure_belt(9, [{
		"item_id": "belt:visible",
		"card": card,
		"claimable": true,
		"visible_actor_ids": ["player.2", "player.1"],
	}])
	product_market.product_market = {"fixture.product": {"base_price": 10, "price": 10, "trend": 2, "futures_positions": []}}
	product_market.business_cycle_count = 4
	var owner := CARD_OWNER_SCENE.instantiate() as CardInventorySaveOwner
	root.add_child(owner)
	owner.configure_dependencies(commodity, product_market, district_purchase)
	var save := owner.to_save_data()
	_expect(not save.is_empty() and int(save.get("schema_version", 0)) == 3, "card-inventory v3 composite captures")
	var save_text := JSON.stringify(save)
	_expect(not save_text.contains("\"slots\"") and not save_text.contains("runtime_instance_id") and not save_text.contains("\"cash\"") and not save_text.contains("ai_profile") and not save_text.contains("ai_memory"), "card-inventory payload contains no World-owned slots, instances, cash, or AI state")
	var session_dependency := {"session": {"world_session_state": {"players": world.capture_envelope_save_data().get("normalized_state", {}).get("players", [])}}}
	var dependency_preflight := owner.preflight_restore_dependencies(save, session_dependency)
	_expect(bool(dependency_preflight.get("accepted", false)), "card-inventory dependency preflight accepts the restored session roster")
	var cursor_before_dependency_rejection := owner.to_save_data()
	var stale_cursor_dependencies := session_dependency.duplicate(true)
	stale_cursor_dependencies["region_supply"] = {
		"terminal_transactions": {
			"district-purchase:market-quote-1000000-9": {"transaction_id": "district-purchase:market-quote-1000000-9"},
		},
	}
	var stale_cursor := owner.preflight_restore_dependencies(save, stale_cursor_dependencies)
	_expect(not bool(stale_cursor.get("accepted", true)) \
			and str(stale_cursor.get("reason_code", "")) == "allocator_cursor_regressed" \
			and owner.to_save_data() == cursor_before_dependency_rejection, "card-inventory rejects a quote cursor behind Region Supply transaction lineage without mutation")

	var players_without_card := world.players.duplicate(true)
	(players_without_card[1] as Dictionary)["slots"] = []
	world.replace_players(players_without_card, true)
	product_market.business_cycle_count = 31
	commodity.configure_belt(10, [])
	var apply := owner.apply_save_data(save)
	_expect(bool(apply.get("applied", false)) and int(commodity.belt_snapshot().get("revision", -1)) == 9 and product_market.business_cycle_count == 4, "card-inventory exact apply restores every child")
	_expect((world.players[1] as Dictionary).get("slots", []).is_empty(), "card-inventory restore never overwrites the session-owned player slots")
	var roundtrip := owner.to_save_data()
	_expect(roundtrip == save, "card-inventory capture/apply/capture is byte-shape stable")

	commodity.configure_belt(11, [])
	product_market.business_cycle_count = 47
	var before_fault := owner.to_save_data()
	owner.arm_test_fault_once("product_market_after")
	var failed_apply := owner.apply_save_data(save)
	var after_fault := owner.to_save_data()
	_expect(not bool(failed_apply.get("applied", true)) and bool(failed_apply.get("rollback_attempted", false)) and bool(failed_apply.get("rollback_complete", false)), "card-inventory injected mid-apply failure reverses all touched children")
	_expect(after_fault == before_fault, "card-inventory rollback restores the exact pre-apply composite checkpoint")

	var belt_owner := BELT_OWNER_SCENE.instantiate() as CommodityBeltVisibilitySaveOwner
	root.add_child(belt_owner)
	belt_owner.configure_dependencies(commodity)
	var belt_attestation := belt_owner.to_save_data()
	_expect(_exact_keys(belt_attestation, ["schema_version", "ruleset_id", "belt_revision", "belt_item_ids", "visibility_acl_fingerprint"]), "belt visibility persists only its frozen five-field attestation")
	_expect(not JSON.stringify(belt_attestation).contains("visible_actor_ids"), "belt visibility attestation leaks no mutable ACL copy")
	var card_for_dependency := owner.to_save_data()
	var belt_dependency := belt_owner.preflight_restore_dependencies(belt_attestation, {"card_inventory": card_for_dependency})
	_expect(bool(belt_dependency.get("accepted", false)), "belt dependency preflight matches the CardFlow item-ID set and ACL fingerprint")
	var commodity_before_mismatch := commodity.to_save_data()
	var tampered := belt_attestation.duplicate(true)
	tampered["belt_revision"] = int(tampered.get("belt_revision", 0)) + 1
	var mismatch := belt_owner.apply_save_data(tampered)
	_expect(not bool(mismatch.get("applied", true)) and not bool(mismatch.get("mutated", true)) and commodity.to_save_data() == commodity_before_mismatch, "belt attestation mismatch fails without mutation")
	_expect(bool(belt_owner.apply_save_data(belt_attestation).get("applied", false)), "matching belt attestation applies immutably")
	belt_owner.queue_free()
	owner.queue_free()
	await process_frame


func _verify_ai_owner(
	ai: AiRuntimeController,
	port: AiActorStatePort,
	world: WorldSessionState,
	rng: RunRngService
) -> void:
	ai.configure({"ruleset_id": "v0.6"})
	ai._ensure_player_ai_state()
	var capability := ai.get("_ai_actor_state_capability") as AiActorStateCapability
	_expect(capability != null, "AI owner retains its opaque typed-port capability")
	var port_before := port.debug_snapshot()
	var rng_before := rng.capture_plan_checkpoint()
	var ai_save := ai.to_save_data()
	var port_after_capture := port.debug_snapshot()
	_expect(_exact_keys(ai_save, ["schema_version", "ruleset_id", "policy_profile_id", "policy_fingerprint", "request_sequence", "ai_card_decision_timer", "ai_auction_reaction_timer", "ai_intel_decision_timer", "ai_card_decision_enabled", "player_states"]), "AI v2 save uses the exact frozen field set")
	_expect((ai_save.get("player_states", []) as Array).map(func(row: Dictionary) -> int: return int(row.get("player_index", -1))) == [1, 2], "AI save rows are canonically sorted and exclude human seats")
	_expect(port_before == port_after_capture and rng.capture_plan_checkpoint() == rng_before, "AI capture mutates no typed-port telemetry and consumes no RNG")
	var envelope_capture := world.capture_envelope_save_data()
	var envelope := envelope_capture.get("normalized_state", {}) as Dictionary
	var envelope_text := JSON.stringify(envelope)
	_expect(bool(envelope_capture.get("accepted", false)) and not envelope_text.contains("ai_profile") and not envelope_text.contains("ai_memory"), "session foundation excludes mutable AI profile and memory")
	var migrated_v2 := envelope.duplicate(true)
	migrated_v2["schema_version"] = 2
	var migrated_players := (migrated_v2.get("players", []) as Array).duplicate(true)
	for player_variant in migrated_players:
		(player_variant as Dictionary)["ai_profile"] = {"legacy": true}
		(player_variant as Dictionary)["ai_memory"] = {"legacy": true}
	migrated_v2["players"] = migrated_players
	var migrated_preflight := world.preflight_envelope_save_data(migrated_v2)
	_expect(bool(migrated_preflight.get("accepted", false)) and int((migrated_preflight.get("normalized_state", {}) as Dictionary).get("schema_version", 0)) == 3 and not JSON.stringify(migrated_preflight.get("normalized_state", {})).contains("ai_memory"), "session v2 migrates by dropping its retired AI duplicate fields")
	var invalid_v3 := envelope.duplicate(true)
	var invalid_v3_players := (invalid_v3.get("players", []) as Array).duplicate(true)
	(invalid_v3_players[1] as Dictionary)["ai_memory"] = {"forbidden": true}
	invalid_v3["players"] = invalid_v3_players
	_expect(not bool(world.preflight_envelope_save_data(invalid_v3).get("accepted", true)), "session v3 rejects reintroduced AI state")
	var dependency_preflight := ai.preflight_restore_dependencies(ai_save, {"session": {"world_session_state": envelope}})
	_expect(bool(dependency_preflight.get("accepted", false)), "AI dependency preflight matches the session AI roster")
	var bad_roster := envelope.duplicate(true)
	var bad_players := (bad_roster.get("players", []) as Array).duplicate(true)
	(bad_players[2] as Dictionary)["is_ai"] = false
	(bad_players[2] as Dictionary)["seat_type"] = "human"
	bad_roster["players"] = bad_players
	_expect(not bool(ai.preflight_restore_dependencies(ai_save, {"session": {"world_session_state": bad_roster}}).get("accepted", true)), "AI dependency preflight rejects roster drift before mutation")

	var current_batch := port.capture_ai_state_batch_for_save(capability, true)
	var changed_rows := (current_batch.get("rows", []) as Array).duplicate(true)
	for row_variant in changed_rows:
		var row := row_variant as Dictionary
		(row.get("ai_memory", {}) as Dictionary)["last_plan"] = "mutated-after-capture"
	port.apply_ai_state_batch(capability, changed_rows)
	var foundation_apply := world.apply_envelope_save_data(envelope)
	_expect(bool(foundation_apply.get("applied", false)) and (world.players[1] as Dictionary).get("ai_profile", {}) == {} and (world.players[1] as Dictionary).get("ai_memory", {}) == {}, "session foundation restores empty AI placeholders before the AI phase")
	var port_before_restore := port.debug_snapshot()
	var ai_apply := ai.apply_save_data(ai_save)
	_expect(
		bool(ai_apply.get("applied", false)) and not ((world.players[1] as Dictionary).get("ai_profile", {}) as Dictionary).is_empty(),
		"AI phase restores profile and memory through the typed port after session foundation: %s" % JSON.stringify(ai_apply)
	)
	_expect(port.debug_snapshot() == port_before_restore, "AI restore changes no typed-port telemetry counters")
	var before_invalid := ai.to_save_data()
	var invalid_policy := ai_save.duplicate(true)
	invalid_policy["policy_fingerprint"] = "0".repeat(64)
	var invalid_apply := ai.apply_save_data(invalid_policy)
	_expect(not bool(invalid_apply.get("applied", true)) and ai.to_save_data() == before_invalid, "AI policy mismatch fails before mutation")


func _player(
	catalog: RoleCatalogRuntimeService,
	player_index: int,
	is_ai: bool,
	marker: String
) -> Dictionary:
	var role := catalog.definition_at(player_index)
	role["role_index"] = player_index
	return {
		"id": player_index,
		"name": "AI-%d" % player_index if is_ai else "Human-%d" % player_index,
		"seat_type": "ai" if is_ai else "human",
		"is_ai": is_ai,
		"ai_profile": {"profile_index": player_index, "private_marker": marker} if is_ai else {},
		"ai_memory": {"private_marker": marker, "decision_samples": [], "action_counts": {}},
		"role_index": player_index,
		"role_card": role,
		"base_starting_cash": 700,
		"role_starting_cash_delta": 0,
		"starting_cash_total": 700,
		"cash": 700,
		"cash_cents": 70000,
		"cash_history": [],
		"v06_transaction_ledger": [],
		"eliminated": false,
		"eliminated_at": -1.0,
		"elimination_reason": "",
		"economic_ledger": [],
		"city_guesses": {},
		"city_guess_confidence": {},
		"city_guess_reasons": {},
		"cities_built": 0,
		"total_card_spend": 0,
		"card_purchase_count": 0,
		"total_build_spend": 0,
		"total_card_income": 0,
		"total_role_income": 0,
		"total_business_spend": 0,
		"action_cooldown": 0.0,
		"queued_card_tip": 0,
		"slots": [],
	}


func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(str(key_variant)):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("ALPHA04C_CARD_INVENTORY_BELT_AI_SAVE_OWNER_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Alpha04C card inventory/belt/AI save owner test failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
