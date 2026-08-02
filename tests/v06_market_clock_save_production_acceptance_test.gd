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
		_test_expired_pending_discard_roundtrip(coordinator)
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
	_expect(bool(registry_snapshot.get("valid", false)) and bool(registry_snapshot.get("resume_ready", false)) \
			and int(registry_snapshot.get("transactional_section_count", 0)) == 19 \
			and int(registry_snapshot.get("unsupported_section_count", -1)) == 0, "owner registry remains valid and resume-ready at the completed 19-of-19 transactional boundary")


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
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController")
	var expires_at_us := int(saved_quote.get("expires_at_world_us", -1))
	var purchase_checkpoint: Dictionary = purchase.call("capture_runtime_checkpoint")
	if clock != null:
		clock.call("restore_micros", expires_at_us - 1)
	var before_expiry_save: Dictionary = purchase.call("to_save_data")
	if clock != null:
		clock.call("restore_micros", expires_at_us)
	var at_expiry_save: Dictionary = purchase.call("to_save_data")
	var before_expiry_quote := _first_saved_purchase_quote(before_expiry_save)
	var at_expiry_quote := _first_saved_purchase_quote(at_expiry_save)
	_expect(expires_at_us > 0 and not before_expiry_quote.is_empty() and at_expiry_quote.is_empty() \
			and bool(purchase.call("preflight_save_data", at_expiry_save).get("accepted", false)) \
			and purchase.call("capture_runtime_checkpoint") == purchase_checkpoint, "quote save projection keeps t-1us and omits the half-open expiry boundary without runtime mutation")
	pricing.call("reset_state")
	purchase.call("reset_state")
	var at_expiry_apply: Dictionary = purchase.call("apply_save_data", at_expiry_save)
	_expect(bool(at_expiry_apply.get("applied", false)) \
			and int(at_expiry_apply.get("session_count", 0)) == 1 \
			and purchase.call("to_save_data") == at_expiry_save, "quote-free Generation 2 boundary applies and exact-recaptures like a fresh Process C")
	var purchase_checkpoint_restore: Dictionary = purchase.call("restore_runtime_checkpoint", purchase_checkpoint)
	_expect(bool(purchase_checkpoint_restore.get("applied", false)), "market-clock fixture restores its exact pre-boundary purchase and quote checkpoint")
	if clock != null:
		clock.call("restore_micros", 1_000_000)

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


func _test_expired_pending_discard_roundtrip(coordinator: GameRuntimeCoordinator) -> void:
	var pricing := coordinator.get_node_or_null("CardMarketPricingRuntimeController") if coordinator != null else null
	var purchase := coordinator.get_node_or_null("DistrictPurchaseRuntimeController") if coordinator != null else null
	var clock := coordinator.get_node_or_null("WorldEffectiveClockRuntimeController") if coordinator != null else null
	_expect(pricing != null and purchase != null and clock != null, "pending-discard expiry fixture owns pricing, purchase, and world clock")
	if pricing == null or purchase == null or clock == null:
		return
	pricing.call("reset_state")
	purchase.call("reset_state")
	clock.call("restore_micros", 2_000_000)
	var source_district := _first_purchasable_district_index(coordinator)
	var prior_quote_a: Dictionary = coordinator.call("card_market_quote", _listing(source_district, "card.qa.prior-a", "qa-prior-a", 101, 0))
	var prior_quote_b: Dictionary = coordinator.call("card_market_quote", _listing(source_district, "card.qa.prior-b", "qa-prior-b", 101, 0))
	var aggregate_revision := "qa-pending-rack:2,4,6,8"
	var selected_revision := "qa-pending-rack:slot:2:revision:6"
	var card_id := "card.qa.pending-expiry"
	coordinator.call("open_district_purchase_window", 0, source_district, {"supply_revision": aggregate_revision})
	coordinator.call("acknowledge_district_purchase_selection", 0, source_district, card_id, selected_revision)
	var quote: Dictionary = coordinator.call("card_market_quote", _listing(source_district, card_id, selected_revision, 101, 0))
	var reserved: Dictionary = purchase.call("reserve_pending_discard", {
		"player_index": 0,
		"district_index": source_district,
		"skill_name": card_id,
		"card_id": card_id,
		"price": int(quote.get("final_price", -1)),
		"quote_id": str(quote.get("quote_id", "")),
		"opened_at": 2.0,
	})
	var expires_at_us := int(quote.get("expires_at_world_us", -1))
	clock.call("restore_micros", expires_at_us)
	var expired_pending_save: Dictionary = purchase.call("to_save_data")
	_expect(source_district >= 0 and not prior_quote_a.is_empty() and not prior_quote_b.is_empty() \
			and not quote.is_empty() and not reserved.is_empty() \
			and not expired_pending_save.is_empty() \
			and not _first_saved_purchase_quote(expired_pending_save).is_empty(), "expired pending-discard capture retains its already-authorized quote instead of producing an invalid empty Owner")
	var future_request := _listing(source_district, "card.qa.after-restore", "qa-after-restore", 101, 0)
	var uninterrupted_future_quote: Dictionary = coordinator.call("card_market_quote", future_request)
	pricing.call("reset_state")
	purchase.call("reset_state")
	var applied: Dictionary = purchase.call("apply_save_data", expired_pending_save)
	var pending_after: Dictionary = purchase.call("pending_discard_private_snapshot", 0)
	var quote_after: Dictionary = coordinator.call("card_market_active_quote", 0, source_district)
	var restored_future_quote: Dictionary = coordinator.call("card_market_quote", future_request)
	_expect(bool(applied.get("applied", false)) and int(applied.get("session_count", 0)) == 1 \
			and str(pending_after.get("quote_id", "")) == str(quote.get("quote_id", "")) \
			and str(quote_after.get("quote_id", "")) == str(quote.get("quote_id", "")) \
			and not bool(quote_after.get("quote_active", true)), "expired pending-discard restores exactly as a non-authorizable forced decision")
	_expect(not uninterrupted_future_quote.is_empty() \
			and str(restored_future_quote.get("quote_id", "")) == str(uninterrupted_future_quote.get("quote_id", "")) \
			and str(restored_future_quote.get("quote_fingerprint", "")) == str(uninterrupted_future_quote.get("quote_fingerprint", "")), "restored pending quote advances the private quote sequence so the next forked transaction identity remains exact")
	var post_future_save: Dictionary = purchase.call("to_save_data")
	var saved_runtime: Dictionary = expired_pending_save.get("district_purchase_runtime", {}) \
			if expired_pending_save.get("district_purchase_runtime", {}) is Dictionary else {}
	var post_future_runtime: Dictionary = post_future_save.get("district_purchase_runtime", {}) \
			if post_future_save.get("district_purchase_runtime", {}) is Dictionary else {}
	_expect(post_future_runtime.get("sessions", []) == saved_runtime.get("sessions", []) \
			and int(post_future_runtime.get("next_quote_sequence", 0)) \
				== int(saved_runtime.get("next_quote_sequence", 0)) + 1,
			"expired pending-discard restore preserves the session while one legal future quote advances the cursor exactly once")
	purchase.call("reset_state")
	pricing.call("reset_state")
	clock.call("restore_micros", 1_000_000)


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


func _first_saved_purchase_quote(save_data: Dictionary) -> Dictionary:
	var payload: Dictionary = save_data.get("district_purchase_runtime", {}) \
			if save_data.get("district_purchase_runtime", {}) is Dictionary else {}
	var sessions: Array = payload.get("sessions", []) if payload.get("sessions", []) is Array else []
	if sessions.is_empty() or not (sessions[0] is Dictionary):
		return {}
	var quote: Variant = (sessions[0] as Dictionary).get("active_quote", {})
	return (quote as Dictionary).duplicate(true) if quote is Dictionary else {}


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
