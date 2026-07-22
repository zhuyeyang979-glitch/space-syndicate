extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	await process_frame
	var draft := main.get_node_or_null("RuntimeServices/NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := main.get_node_or_null("RuntimeServices/SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") as GameSessionRuntimeController if coordinator != null else null
	var request := SessionStartRequest.create(
		"commodity-postcommit-envelope",
		draft.draft_snapshot() if draft != null else {},
		session.session_start_revision() if session != null else -1,
		"focused_test"
	)
	var start_receipt := transaction.start_session(request) if transaction != null else null
	_expect(start_receipt != null and start_receipt.applied, "formal session starts through the production transaction")
	await process_frame
	var world := coordinator.world_session_state() if coordinator != null else null
	var owner := coordinator.get_node_or_null("GameSessionRuntimeController/SessionEnvelopeSaveOwner") as SessionEnvelopeSaveOwner if coordinator != null else null
	_expect(world != null and owner != null and world.players.size() == 4 and not world.districts.is_empty(), "formal WorldSession and SessionEnvelope owners are available")
	if world == null or owner == null:
		main.queue_free()
		await process_frame
		_finish()
		return
	var district_index := 0
	var breakdown_one := _city_breakdown(21, 2100, 1)
	var binding_one := _binding(1)
	var binding_two := _binding(2)
	var city_one := world.apply_commodity_postcommit_city_gdp_snapshot(1, binding_one.batch_id, binding_one.batch_fingerprint, binding_one.city_breakdown_fingerprint, district_index, breakdown_one)
	var player_one := world.record_commodity_postcommit_cash_snapshot(1, binding_one.batch_id, binding_one.batch_fingerprint, 0)
	_expect(bool(city_one.get("applied", false)) and bool(player_one.get("applied", false)), "batch 1 applies both formal post-commit target lineages")
	var expected_history_size := _city_history_size(world, district_index)
	var capture := owner.capture_composite_state()
	var captured_state: Dictionary = capture.get("state", {}) if capture.get("state", {}) is Dictionary else {}
	var captured_world: Dictionary = captured_state.get("world_session_state", {}) if captured_state.get("world_session_state", {}) is Dictionary else {}
	_expect(
		bool(capture.get("captured", false))
		and int(((captured_world.get("commodity_postcommit_city_lineage_by_district", {}) as Dictionary).get("0", {}) as Dictionary).get("batch_sequence", 0)) == 1
		and int(((captured_world.get("commodity_postcommit_cash_lineage_by_player", {}) as Dictionary).get("0", {}) as Dictionary).get("batch_sequence", 0)) == 1,
		"formal SessionEnvelope capture preserves city and player-observation exact-once cursors"
	)

	world.apply_commodity_postcommit_city_gdp_snapshot(2, binding_two.batch_id, binding_two.batch_fingerprint, binding_two.city_breakdown_fingerprint, district_index, _city_breakdown(28, 2800, 1))
	world.record_commodity_postcommit_cash_snapshot(2, binding_two.batch_id, binding_two.batch_fingerprint, 0)
	_expect(_city_history_size(world, district_index) == expected_history_size + 1, "live state advances beyond the captured checkpoint")
	var restored := owner.apply_save_data(captured_state)
	var restored_internal := world.internal_snapshot()
	_expect(
		bool(restored.get("applied", false))
		and int(((restored_internal.get("commodity_postcommit_city_lineage_by_district", {}) as Dictionary).get("0", {}) as Dictionary).get("batch_sequence", 0)) == 1
		and int(((restored_internal.get("commodity_postcommit_cash_lineage_by_player", {}) as Dictionary).get("0", {}) as Dictionary).get("batch_sequence", 0)) == 1
		and _city_history_size(world, district_index) == expected_history_size,
		"formal SessionEnvelope apply restores target data and lineage atomically"
	)
	var replay_city := world.apply_commodity_postcommit_city_gdp_snapshot(1, binding_one.batch_id, binding_one.batch_fingerprint, binding_one.city_breakdown_fingerprint, district_index, breakdown_one)
	var replay_player := world.record_commodity_postcommit_cash_snapshot(1, binding_one.batch_id, binding_one.batch_fingerprint, 0)
	_expect(bool(replay_city.get("idempotent", false)) and bool(replay_player.get("idempotent", false)) and _city_history_size(world, district_index) == expected_history_size, "restored batch 1 is an idempotent replay")
	var next_city := world.apply_commodity_postcommit_city_gdp_snapshot(2, binding_two.batch_id, binding_two.batch_fingerprint, binding_two.city_breakdown_fingerprint, district_index, _city_breakdown(28, 2800, 1))
	_expect(bool(next_city.get("applied", false)) and not bool(next_city.get("idempotent", true)) and _city_history_size(world, district_index) == expected_history_size + 1, "restored lineage accepts the next batch exactly once")

	var malformed := captured_state.duplicate(true)
	var malformed_world: Dictionary = (malformed.get("world_session_state", {}) as Dictionary).duplicate(true)
	malformed_world["commodity_postcommit_city_lineage_by_district"] = {"999": binding_one}
	malformed["world_session_state"] = malformed_world
	_expect(not bool(owner.preflight_save_data(malformed).get("accepted", true)), "out-of-range formal lineage fails closed before mutation")

	var legacy := captured_state.duplicate(true)
	var legacy_world: Dictionary = (legacy.get("world_session_state", {}) as Dictionary).duplicate(true)
	legacy_world["schema_version"] = 1
	for key in [
		"commodity_postcommit_city_lineage_by_district",
		"commodity_postcommit_cash_lineage_by_player",
		"commodity_postcommit_city_mutation_count",
		"commodity_postcommit_cash_snapshot_count",
	]:
		legacy_world.erase(key)
	legacy["world_session_state"] = legacy_world
	var legacy_preflight := owner.preflight_save_data(legacy)
	var normalized_legacy_world: Dictionary = ((legacy_preflight.get("normalized_state", {}) as Dictionary).get("world_session_state", {}) as Dictionary) if legacy_preflight.get("normalized_state", {}) is Dictionary else {}
	_expect(
		bool(legacy_preflight.get("accepted", false))
		and (normalized_legacy_world.get("commodity_postcommit_city_lineage_by_district", {}) as Dictionary).is_empty()
		and (normalized_legacy_world.get("commodity_postcommit_cash_lineage_by_player", {}) as Dictionary).is_empty(),
		"legacy envelope without post-commit lineage migrates explicitly to empty cursors"
	)
	var truncated_current := captured_state.duplicate(true)
	var truncated_current_world: Dictionary = (truncated_current.get("world_session_state", {}) as Dictionary).duplicate(true)
	truncated_current_world.erase("commodity_postcommit_cash_snapshot_count")
	truncated_current["world_session_state"] = truncated_current_world
	_expect(not bool(owner.preflight_save_data(truncated_current).get("accepted", true)), "current envelope cannot masquerade as legacy when a lineage field is truncated")

	main.queue_free()
	await process_frame
	_finish()


func _city_history_size(world: WorldSessionState, district_index: int) -> int:
	var district: Dictionary = world.districts[district_index]
	var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
	return (city.get("gdp_history", []) as Array).size() if city.get("gdp_history", []) is Array else 0


func _binding(sequence: int) -> Dictionary:
	return {
		"batch_sequence": sequence,
		"batch_id": "commodity-flow-batch-%010d" % sequence,
		"batch_fingerprint": ("formal-envelope-batch-%d" % sequence).sha256_text(),
		"city_breakdown_fingerprint": ("formal-envelope-city-breakdown-%d" % sequence).sha256_text(),
	}


func _city_breakdown(net: int, net_cents: int, receipt_count: int) -> Dictionary:
	return {
		"net": net,
		"net_cents": net_cents,
		"receipt_count": receipt_count,
		"observation_window_seconds": 30.0,
		"competition_matches": 0,
		"product_lines": [],
		"route_lines": [],
		"transit_lines": [],
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("COMMODITY POSTCOMMIT FORMAL ENVELOPE: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("COMMODITY POSTCOMMIT FORMAL ENVELOPE PASS: %d/%d" % [_checks, _checks])
		quit(0)
		return
	push_error("COMMODITY POSTCOMMIT FORMAL ENVELOPE FAIL: %d/%d" % [_failures, _checks])
	quit(1)
