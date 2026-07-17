extends SceneTree

const PRODUCTION_BENCH := preload("res://scenes/tools/DistrictPurchaseRuntimeCutoverBench.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bench := PRODUCTION_BENCH.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	bench.call("_prepare_runtime")
	bench.call("_reset_policy")

	_test_eighteen_owner_registry_has_no_solar_section(bench)
	_test_session_clock_restore_reproduces_sunlight(bench)
	_test_purchase_session_restore_never_live_reprices(bench)

	bench.queue_free()
	await process_frame
	await _test_true_pause_and_open_market_clock_domain()
	_finish()


func _test_eighteen_owner_registry_has_no_solar_section(bench: Node) -> void:
	var coordinator := bench.get_node_or_null("%GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	_expect(session != null and save != null and handshake != null and registry != null, "production session composes one save handshake and owner registry")
	if handshake == null or registry == null:
		return

	var manifest: Dictionary = handshake.call("required_section_manifest")
	var order: Array = registry.call("fixed_section_order")
	var owner_ids: Dictionary = {}
	var forbidden_solar_section := false
	for section_variant: Variant in manifest.keys():
		var section_id := str(section_variant)
		var contract: Dictionary = manifest.get(section_variant, {}) if manifest.get(section_variant, {}) is Dictionary else {}
		owner_ids[str(contract.get("owner_id", ""))] = true
		var lowered := section_id.to_lower()
		for token in ["solar", "sunlight", "planet_rotation", "rotation_phase"]:
			forbidden_solar_section = forbidden_solar_section or lowered.contains(token)
	_expect(manifest.size() == 18 and order.size() == 18 and owner_ids.size() == 18 and not owner_ids.has(""), "save manifest and fixed apply order retain exactly eighteen unique owners")
	_expect(not forbidden_solar_section, "solar and rotation phase remain derived facts instead of a nineteenth save section")
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	_expect(bool(registry_snapshot.get("valid", false)) and not bool(registry_snapshot.get("resume_ready", true)), "owner registry remains valid and explicitly fail-closed while restore coverage is incomplete")


func _test_session_clock_restore_reproduces_sunlight(bench: Node) -> void:
	var coordinator := bench.get_node_or_null("%GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	_expect(coordinator != null and session != null, "production world clock and GameSession owner are available")
	if coordinator == null or session == null:
		return

	coordinator.call("restore_world_effective_seconds", 1.25)
	var before_clock: Dictionary = coordinator.call("world_effective_clock_snapshot")
	var before_sunlight: Dictionary = coordinator.call("card_market_listing_availability", 0)
	var session_save: Dictionary = session.call("to_save_data")
	var payload: Dictionary = session_save.get("game_session_runtime", {}) if session_save.get("game_session_runtime", {}) is Dictionary else {}
	_expect(payload.get("world_effective_us") is int and int(payload.get("world_effective_us", -1)) == 1_250_000, "GameSession captures the authoritative integer world_effective_us")

	coordinator.call("restore_world_effective_seconds", 61.25)
	var opposite_sunlight: Dictionary = coordinator.call("card_market_listing_availability", 0)
	var applied: Dictionary = session.call("apply_save_data", session_save)
	var restored_clock: Dictionary = coordinator.call("world_effective_clock_snapshot")
	var restored_sunlight: Dictionary = coordinator.call("card_market_listing_availability", 0)
	_expect(str(before_sunlight.get("availability_kind", "")) != str(opposite_sunlight.get("availability_kind", "")), "advancing half a rotation changes the production sunlight result")
	_expect(bool(applied.get("applied", false)) and restored_clock == before_clock and restored_sunlight == before_sunlight, "restoring GameSession world_effective_us reproduces the same sunlight without saved solar phase")


func _test_purchase_session_restore_never_live_reprices(bench: Node) -> void:
	bench.call("_reset_policy")
	var coordinator := bench.get_node_or_null("%GameRuntimeCoordinator")
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController") if coordinator != null else null
	var purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") if coordinator != null else null
	var world: Node = bench.get("_world") as Node
	var monsters: Node = world.get("monster_runtime_controller") as Node if world != null else null
	_expect(coordinator != null and pricing != null and purchase != null and monsters != null, "production quote and purchase-session owners are available")
	if coordinator == null or pricing == null or purchase == null or monsters == null:
		return

	monsters.set("entries", [])
	coordinator.call("restore_world_effective_seconds", 1.0)
	coordinator.call("open_district_purchase_window", 0, 0, {"supply_revision": "qa-save-quote"})
	coordinator.call("acknowledge_district_purchase_selection", 0, 0, "card.qa.save-quote", "qa-save-quote")
	var request := _listing(0, "card.qa.save-quote", "qa-save-quote", 101, 0)
	var original: Dictionary = coordinator.call("card_market_quote", request)
	var purchase_save: Dictionary = coordinator.call("district_purchase_legacy_save_snapshot", 0)
	var saved_quote: Dictionary = purchase_save.get("active_quote", {}) if purchase_save.get("active_quote", {}) is Dictionary else {}
	_expect(int(original.get("final_price", -1)) == 101 and not saved_quote.is_empty(), "purchase-session owner captures one active base-price quote")

	monsters.set("entries", [{"district_index": 0, "down": false, "remaining_time": 10.0, "owner": "PRIVATE_OWNER"}])
	var live_preview: Dictionary = coordinator.call("card_market_preview", request)
	_expect(int(live_preview.get("final_price", -1)) == 202, "changed live monster facts would produce a different new quote")
	pricing.call("reset_state")
	purchase.call("reset_state")
	var restored: Dictionary = coordinator.call("apply_district_purchase_legacy_save_snapshot", purchase_save, 1.0)
	var active: Dictionary = coordinator.call("card_market_active_quote", 0, 0)
	var restored_locked := bool(restored.get("quote_restored", false)) \
		and int(active.get("final_price", -1)) == int(original.get("final_price", -2)) \
		and str(active.get("quote_fingerprint", "")) == str(original.get("quote_fingerprint", "")) \
		and int(active.get("final_price", -1)) != int(live_preview.get("final_price", -1))
	var failed_closed := not bool(restored.get("quote_restored", false)) and active.is_empty()
	_expect(restored_locked or failed_closed, "active quote restore preserves its locked public facts or fails closed; it never live-reprices")

	pricing.call("reset_state")
	purchase.call("reset_state")
	var expires_at_us := int(saved_quote.get("expires_at_world_us", -1))
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController")
	if clock != null:
		clock.call("restore_micros", expires_at_us)
	var expired_restore: Dictionary = coordinator.call("apply_district_purchase_legacy_save_snapshot", purchase_save, float(expires_at_us) / 1_000_000.0)
	var expired_active: Dictionary = coordinator.call("card_market_active_quote", 0, 0)
	_expect(expires_at_us > 0 and not bool(expired_restore.get("quote_restored", false)) and expired_active.is_empty(), "a saved quote restored at its exact half-open expiry boundary fails closed")


func _test_true_pause_and_open_market_clock_domain() -> void:
	var main := MAIN_SCENE.instantiate() as Control
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await _wait_frames(3)
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(4)
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var fixture: Dictionary = coordinator.call("first_table_fixture_snapshot") if coordinator != null else {}
	var source_district := int(fixture.get("facility_market_source_district_index", -1))
	var opened: Dictionary = coordinator.call("open_district_purchase_window", 0, source_district, {"supply_revision": "qa-pause-open-market"}) if coordinator != null and source_district >= 0 else {}
	_expect(coordinator != null and bool(opened.get("active", false)), "real first-table composition opens a market window without changing the clock domain")
	if coordinator != null and bool(opened.get("active", false)):
		var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
		var before_pause: Dictionary = coordinator.call("world_effective_clock_snapshot")
		coordinator.call("pause_session")
		runtime_loop.advance_frame_for_test(0.25)
		var after_pause: Dictionary = coordinator.call("world_effective_clock_snapshot")
		coordinator.call("resume_session")
		runtime_loop.advance_frame_for_test(0.25)
		var after_market_tick: Dictionary = coordinator.call("world_effective_clock_snapshot")
		_expect(after_pause == before_pause, "true pause freezes world_effective time")
		_expect(int(after_market_tick.get("world_effective_us", 0)) > int(after_pause.get("world_effective_us", 0)), "an open market does not freeze world_effective time")
	main.queue_free()
	await _wait_frames(3)


func _listing(district_index: int, card_id: String, supply_revision: String, base_price: int, player_index: int) -> Dictionary:
	return {
		"player_index": player_index,
		"district_index": district_index,
		"card_id": card_id,
		"supply_revision": supply_revision,
		"base_price": base_price,
	}


func _wait_frames(count: int) -> void:
	for _index in range(maxi(0, count)):
		await process_frame


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("V06 MARKET CLOCK SAVE PRODUCTION ACCEPTANCE: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V06_MARKET_CLOCK_SAVE_PRODUCTION_ACCEPTANCE_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
