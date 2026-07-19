extends SceneTree

const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/v06_market_clock_save_production_acceptance.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_save()
	var start_result := await SESSION_START_DRIVER.start_default_session(
		self,
		QA_SAVE_PATH,
		"market-clock-production-session"
	)
	var main := start_result.get("main_root") as Node
	var coordinator := start_result.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(start_result.get("started", false)), "formal setup transaction starts the production market-clock session|reason=%s" % start_result.get("reason_code", ""))
	_expect(bool(start_result.get("qa_save_override_ready", false)), "market-clock production path isolates its QA save before tree entry")
	if coordinator != null and bool(start_result.get("started", false)):
		_test_nineteen_owner_registry_has_no_solar_section(coordinator)
		_test_session_clock_restore_reproduces_sunlight(coordinator)
		_test_purchase_session_restore_never_live_reprices(coordinator)
		_test_true_pause_and_open_market_clock_domain(coordinator)
	if main != null:
		main.queue_free()
		await _wait_frames(3)
	_cleanup_test_save()
	_finish()


func _test_nineteen_owner_registry_has_no_solar_section(coordinator: GameRuntimeCoordinator) -> void:
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
	_expect(manifest.size() == 19 and order.size() == 19 and owner_ids.size() == 19 and not owner_ids.has(""), "save manifest and fixed apply order retain exactly nineteen unique owners")
	_expect(not forbidden_solar_section, "solar and rotation phase remain derived facts instead of a twentieth save section")
	var registry_snapshot: Dictionary = registry.call("registry_snapshot")
	_expect(bool(registry_snapshot.get("valid", false)) and not bool(registry_snapshot.get("resume_ready", true)), "owner registry remains valid and explicitly fail-closed while restore coverage is incomplete")


func _test_session_clock_restore_reproduces_sunlight(coordinator: GameRuntimeCoordinator) -> void:
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	_expect(coordinator != null and session != null, "production world clock and GameSession owner are available")
	if coordinator == null or session == null:
		return

	coordinator.call("restore_world_effective_seconds", 1.25)
	var source_district := _first_public_district_index(coordinator)
	var before_clock: Dictionary = coordinator.call("world_effective_clock_snapshot")
	var before_sunlight: Dictionary = coordinator.call("card_market_listing_availability", source_district)
	var session_save: Dictionary = session.call("to_save_data")
	var payload: Dictionary = session_save.get("game_session_runtime", {}) if session_save.get("game_session_runtime", {}) is Dictionary else {}
	_expect(payload.get("world_effective_us") is int and int(payload.get("world_effective_us", -1)) == 1_250_000, "GameSession captures the authoritative integer world_effective_us")

	coordinator.call("restore_world_effective_seconds", 61.25)
	var opposite_sunlight: Dictionary = coordinator.call("card_market_listing_availability", source_district)
	var applied: Dictionary = session.call("apply_save_data", session_save)
	var restored_clock: Dictionary = coordinator.call("world_effective_clock_snapshot")
	var restored_sunlight: Dictionary = coordinator.call("card_market_listing_availability", source_district)
	_expect(source_district >= 0 and not before_sunlight.is_empty(), "formal world exposes one public source district for solar derivation")
	_expect(str(before_sunlight.get("availability_kind", "")) != str(opposite_sunlight.get("availability_kind", "")), "advancing half a rotation changes the production sunlight result")
	_expect(bool(applied.get("applied", false)) and restored_clock == before_clock and restored_sunlight == before_sunlight, "restoring GameSession world_effective_us reproduces the same sunlight without saved solar phase")


func _test_purchase_session_restore_never_live_reprices(coordinator: GameRuntimeCoordinator) -> void:
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController") if coordinator != null else null
	var purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") if coordinator != null else null
	var monsters := coordinator.monster_runtime_controller() if coordinator != null else null
	_expect(coordinator != null and pricing != null and purchase != null and monsters != null, "production quote and purchase-session owners are available")
	if coordinator == null or pricing == null or purchase == null or monsters == null:
		return

	pricing.call("reset_state")
	purchase.call("reset_state")
	var original_monster_state: Dictionary = monsters.to_save_data()
	var empty_monster_state := original_monster_state.duplicate(true)
	empty_monster_state["auto_monsters"] = []
	empty_monster_state["next_auto_monster_uid"] = 1
	empty_monster_state["next_special_monster_slot"] = 0
	empty_monster_state["selected_auto_monster_slot"] = 0
	var empty_monster_apply: Dictionary = monsters.apply_save_data(empty_monster_state)
	_expect(bool(empty_monster_apply.get("applied", false)), "formal Monster owner accepts an isolated empty-roster checkpoint")
	coordinator.call("restore_world_effective_seconds", 1.0)
	var source_district := _first_purchasable_district_index(coordinator)
	_expect(source_district >= 0, "formal world exposes one currently purchasable market source")
	coordinator.call("open_district_purchase_window", 0, source_district, {"supply_revision": "qa-save-quote"})
	coordinator.call("acknowledge_district_purchase_selection", 0, source_district, "card.qa.save-quote", "qa-save-quote")
	var request := _listing(source_district, "card.qa.save-quote", "qa-save-quote", 101, 0)
	var original: Dictionary = coordinator.call("card_market_quote", request)
	var purchase_save: Dictionary = coordinator.call("district_purchase_legacy_save_snapshot", 0)
	var saved_quote: Dictionary = purchase_save.get("active_quote", {}) if purchase_save.get("active_quote", {}) is Dictionary else {}
	_expect(int(original.get("final_price", -1)) == 101 and not saved_quote.is_empty(), "purchase-session owner captures one active base-price quote")

	var pressured_monster_state := empty_monster_state.duplicate(true)
	pressured_monster_state["auto_monsters"] = [{
		"uid": 1,
		"position": source_district,
		"district_index": source_district,
		"down": false,
		"remaining_time": 10.0,
	}]
	pressured_monster_state["next_auto_monster_uid"] = 2
	var pressured_monster_apply: Dictionary = monsters.apply_save_data(pressured_monster_state)
	_expect(bool(pressured_monster_apply.get("applied", false)), "formal Monster owner accepts one isolated live pressure actor")
	var live_preview: Dictionary = coordinator.call("card_market_preview", request)
	_expect(int(live_preview.get("final_price", -1)) == 202, "changed live monster facts would produce a different new quote")
	pricing.call("reset_state")
	purchase.call("reset_state")
	var restored: Dictionary = coordinator.call("apply_district_purchase_legacy_save_snapshot", purchase_save, 1.0)
	var active: Dictionary = coordinator.call("card_market_active_quote", 0, source_district)
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
	var expired_active: Dictionary = coordinator.call("card_market_active_quote", 0, source_district)
	_expect(expires_at_us > 0 and not bool(expired_restore.get("quote_restored", false)) and expired_active.is_empty(), "a saved quote restored at its exact half-open expiry boundary fails closed")
	var monster_restore: Dictionary = monsters.apply_save_data(original_monster_state)
	_expect(bool(monster_restore.get("applied", false)), "formal Monster owner restores its exact pre-test state")


func _test_true_pause_and_open_market_clock_domain(coordinator: GameRuntimeCoordinator) -> void:
	var source_district := _first_public_district_index(coordinator)
	var opened: Dictionary = coordinator.call("open_district_purchase_window", 0, source_district, {"supply_revision": "qa-pause-open-market"}) if coordinator != null and source_district >= 0 else {}
	_expect(source_district >= 0, "formal public world projection exposes a legal district for the market window")
	_expect(coordinator != null and bool(opened.get("active", false)), "real production session opens a market window without changing the clock domain")
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


func _first_purchasable_district_index(coordinator: GameRuntimeCoordinator) -> int:
	if coordinator == null:
		return -1
	var projection := coordinator.presentation_public_world_projection()
	if projection == null:
		return -1
	for district_index in range(projection.districts.size()):
		var availability: Dictionary = coordinator.card_market_listing_availability(district_index)
		if bool(availability.get("purchasable", false)):
			return district_index
	return -1


func _first_public_district_index(coordinator: GameRuntimeCoordinator) -> int:
	if coordinator == null:
		return -1
	var projection := coordinator.presentation_public_world_projection()
	if projection == null:
		return -1
	for district_variant in projection.districts:
		if not (district_variant is Dictionary):
			continue
		var district := district_variant as Dictionary
		var district_index := int(district.get("region_index", -1))
		if district_index >= 0 and not bool(district.get("destroyed", false)):
			return district_index
	return -1


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


func _cleanup_test_save() -> void:
	for path in [QA_SAVE_PATH, QA_SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("V06 MARKET CLOCK SAVE PRODUCTION ACCEPTANCE: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V06_MARKET_CLOCK_SAVE_PRODUCTION_ACCEPTANCE_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
