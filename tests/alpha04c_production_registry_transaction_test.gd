extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const GAME_ACTION_OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const FACILITY_BINDING := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")

const FACILITY_CARD_ID := "facility.factory.life.rank_2"
const FACILITY_INDUSTRY_ID := "life"
const SUBMISSION_WORLD_TIME_SECONDS := 12.3456
const EXPECTED_SUBMISSION_WORLD_TIME_MS := 12346

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MAIN_SCENE.instantiate()
	var lifecycle := main.get_node_or_null("RuntimeServices/MenuLifecycleApplicationFlowController")
	if lifecycle != null:
		lifecycle.set("open_root_on_ready", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var services := main.get_node_or_null("RuntimeServices")
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController")
	var draft := services.get_node_or_null("NewGameSetupDraftService") as NewGameSetupDraftService
	var transaction := services.get_node_or_null("SessionStartTransactionCoordinator") as SessionStartTransactionCoordinator
	var started := false
	if draft != null and transaction != null and session != null:
		draft.reset_to_defaults()
		var request := SessionStartRequest.create(
			"alpha04c-production-registry-session",
			draft.draft_snapshot(),
			session.session_start_revision(),
			"focused_test"
		)
		var start_receipt := transaction.start_session(request)
		started = start_receipt != null and start_receipt.applied
	_expect(started, "production transaction test starts a real default session")
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var registry := session.get_node_or_null("V06SaveOwnerRegistry") if session != null else null
	var handshake := session.get_node_or_null("GameSaveRuntimeCoordinator/RulesetSaveHandshakeService") if session != null else null
	_expect(registry != null and handshake != null, "production registry and handshake are composed")
	if registry == null or handshake == null:
		_finish()
		return

	var snapshot: Dictionary = registry.registry_snapshot()
	_expect(bool(snapshot.get("valid", false)), "production registry contract is valid")
	_expect(int(snapshot.get("required_section_count", 0)) == 19, "production manifest keeps all 19 semantic sections")
	_expect(int(snapshot.get("transactional_section_count", 0)) == 19 and int(snapshot.get("unsupported_section_count", -1)) == 0, "all 19 sections have transactional owners")
	_expect(bool(snapshot.get("resume_ready", false)) and bool(snapshot.get("restore_barrier_ready", false)), "production registry and global restore barrier are resume-ready")

	var facility_case := _prepare_rank_two_facility_queue(coordinator)
	_expect(bool(facility_case.get("ready", false)), "production fixture queues one nonzero-cost Rank-II facility bundle")
	if not bool(facility_case.get("ready", false)):
		main.queue_free()
		await process_frame
		_finish()
		return

	var capture: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-production-registry-base",
		"write_id": "alpha04c-production-registry-base-write",
	})
	var envelope: Dictionary = capture.get("envelope", {}) if capture.get("envelope") is Dictionary else {}
	_expect(bool(capture.get("ok", false)) and not envelope.is_empty() and (envelope.get("sections", {}) as Dictionary).size() == 19, "production composition captures a complete 19-owner envelope")
	var card_inventory_state := _decoded_section(handshake, envelope, "card_inventory")
	_expect(not card_inventory_state.is_empty() and int(card_inventory_state.get("schema_version", 0)) == 2, "production capture encodes one nonempty card-inventory v2 owner state")
	_assert_queued_facility_envelope(handshake, envelope, facility_case, "capture")
	_test_restore_barrier_blocks_facility(coordinator, facility_case)
	var preflight: Dictionary = registry.preflight_envelope(envelope)
	var preflight_debug: Dictionary = registry.debug_snapshot()
	var organization := coordinator.get_node_or_null("PlayerOrganizationRuntimeController")
	var organization_save: Dictionary = organization.to_save_data() if organization != null else {}
	print("ALPHA04C_ORGANIZATION_CAPTURE|actors=%d|players=%d|configured=%s|secret=%s" % [
		(organization_save.get("actor_ids", []) as Array).size(),
		(organization_save.get("players", {}) as Dictionary).size(),
		bool(organization_save.get("configured", false)),
		not str(organization_save.get("capability_secret", "")).is_empty(),
	])
	print("ALPHA04C_PRODUCTION_PREFLIGHT|ok=%s|reason=%s|count=%d|cross=%d|section=%s|internal=%s" % [
		bool(preflight.get("ok", false)),
		str(preflight.get("reason_code", "")),
		int(preflight.get("preflight_count", 0)),
		int(preflight.get("cross_section_check_count", 0)),
		str(preflight_debug.get("last_internal_preflight_failure_section", "")),
		str(preflight_debug.get("last_internal_preflight_failure_reason", "")),
	])
	_expect(bool(preflight.get("ok", false)) and bool(preflight.get("preflight_complete", false)) and int(preflight.get("preflight_count", 0)) == 19, "all-owner pure preflight accepts the production envelope")
	var baseline_sections := _canonical_sections(handshake, envelope)
	_expect(not baseline_sections.is_empty(), "baseline section fingerprint is available without exposing payloads")

	var fault_passes := 0
	var reverse_order_passes := 0
	for section_variant in registry.fixed_section_order():
		var section_id := str(section_variant)
		var armed := bool(registry.arm_test_apply_failure_once(section_id))
		var failure: Dictionary = registry.apply_envelope(envelope)
		var recapture: Dictionary = registry.capture_resume_envelope({
			"envelope_id": "alpha04c-fault-%s" % section_id,
			"write_id": "alpha04c-fault-%s-write" % section_id,
		})
		var after_envelope: Dictionary = recapture.get("envelope", {}) if recapture.get("envelope") is Dictionary else {}
		var exact := bool(recapture.get("ok", false)) and _canonical_sections(handshake, after_envelope) == baseline_sections
		if armed and not bool(failure.get("ok", true)) \
				and bool(failure.get("rollback_attempted", false)) \
				and bool(failure.get("rollback_complete", false)) \
				and int(failure.get("partial_restore_state_count", -1)) == 0 \
				and exact:
			fault_passes += 1
		var rollback_debug: Dictionary = registry.debug_snapshot()
		if rollback_debug.get("last_internal_rollback_order", []) == _expected_reverse_rollback_order(registry, section_id):
			reverse_order_passes += 1
	_expect(fault_passes == 19, "every production owner apply-fault rolls back to the exact pre-restore state")
	_expect(reverse_order_passes == 19, "every production fault rolls touched owners back in exact reverse DAG order")

	var success: Dictionary = registry.apply_envelope(envelope)
	var success_debug: Dictionary = registry.debug_snapshot()
	print("ALPHA04C_PRODUCTION_APPLY|ok=%s|reason=%s|apply=%d|registry=%d|phase=%d|preflight_section=%s|preflight_reason=%s" % [
		bool(success.get("ok", false)),
		str(success.get("reason_code", "")),
		int(success.get("apply_count", 0)),
		int(success.get("registry_apply_count", 0)),
		int(success_debug.get("last_restore_phase", 0)),
		str(success_debug.get("last_internal_preflight_failure_section", "")),
		str(success_debug.get("last_internal_preflight_failure_reason", "")),
	])
	_expect(bool(success.get("ok", false)) and int(success.get("registry_apply_count", 0)) == 1 and int(success.get("apply_count", 0)) == 19, "one registry load applies exactly 19 owners")
	_expect(int(success.get("restore_phase_count", 0)) == 10 and int(success.get("post_restore_rebind_count", 0)) == 1, "staged restore commits one barrier and one post-restore rebind")
	var restored_capture: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-production-registry-restored-facility",
		"write_id": "alpha04c-production-registry-restored-facility-write",
	})
	var restored_envelope: Dictionary = restored_capture.get("envelope", {}) if restored_capture.get("envelope") is Dictionary else {}
	_expect(bool(restored_capture.get("ok", false)) and _canonical_sections(handshake, restored_envelope) == baseline_sections, "restored queued facility envelope recaptures all 19 owner sections exactly")
	_assert_queued_facility_envelope(handshake, restored_envelope, facility_case, "restored")
	_test_facility_continues_once_after_restore(coordinator, registry, facility_case)
	_test_machine_readable_facility_dependencies()
	var debug: Dictionary = registry.debug_snapshot()
	_expect(int(debug.get("partial_restore_state_count", -1)) == 0 and bool(debug.get("global_preflight_before_apply", false)) and bool(debug.get("all_checkpoints_before_mutation", false)) and bool(debug.get("reverse_order_rollback", false)), "global preflight/checkpoint/reverse-rollback invariants remain true")

	main.queue_free()
	await process_frame
	_finish()


func _canonical_sections(handshake: Node, envelope: Dictionary) -> String:
	if handshake == null or not handshake.has_method("canonical_json") or not (envelope.get("sections") is Dictionary):
		return ""
	return str(handshake.call("canonical_json", envelope.get("sections")))


func _expected_reverse_rollback_order(registry: Node, failing_section_id: String) -> Array[String]:
	var touched: Array[String] = []
	for node_variant in registry.restore_dag_node_order():
		var node_id := str(node_variant)
		var section_id := "session" if node_id in ["session_foundation", "session_tail"] else node_id
		if not touched.has(section_id):
			touched.append(section_id)
		if section_id == failing_section_id and (failing_section_id != "session" or node_id == "session_tail"):
			break
	touched.reverse()
	return touched


func _prepare_rank_two_facility_queue(coordinator: GameRuntimeCoordinator) -> Dictionary:
	if coordinator == null:
		return {}
	var world := coordinator.world_session_state()
	var infrastructure := coordinator.region_infrastructure_runtime_controller() as RegionInfrastructureRuntimeController
	var region_bridge := coordinator.get_node_or_null("RegionInfrastructureWorldBridge")
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var mana := coordinator.get_node_or_null("PlayerManaRuntimeController") as PlayerManaRuntimeController
	var queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var execution := coordinator.get_node_or_null("CardResolutionExecutionRuntimeService") as CardResolutionExecutionRuntimeService
	var history := coordinator.get_node_or_null("CardResolutionHistoryRuntimeService") as CardResolutionHistoryRuntimeService
	var action_flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") as TablePlayerActionApplicationFlowController
	var adapter := coordinator.facility_card_queue_adapter_v06()
	var presentation := coordinator.get_node_or_null("TablePresentationViewModelQuery")
	var lifecycle_port := coordinator.get_node_or_null("RuntimeWorldPorts/RuntimeLifecyclePort") as RuntimeLifecyclePort
	if world == null or infrastructure == null or region_bridge == null or inventory == null or mana == null \
			or queue == null or execution == null or history == null or action_flow == null \
			or adapter == null or presentation == null or lifecycle_port == null:
		return {}

	var binding_refresh := coordinator.refresh_v06_production_player_bindings()
	_expect(bool(binding_refresh.get("ready", false)) and bool(binding_refresh.get("facility_card_queue_adapter_ready", false)), "production facility dependencies are bound before the Save fixture is authored")
	var time_receipt := lifecycle_port.advance_world_time(SUBMISSION_WORLD_TIME_SECONDS)
	_expect(int(time_receipt.get("world_effective_us", -1)) == 12_345_600 \
			and is_equal_approx(world.game_time, SUBMISSION_WORLD_TIME_SECONDS), "production world clock advances to a fractional-millisecond submission source time")
	for player_index in range(world.players.size()):
		mana.availability_snapshot(player_index)
	var mana_seed := mana.advance(1000, world.game_time, {
		"0": {
			"colors": {
				FACILITY_INDUSTRY_ID: {"gdp_per_minute": 200},
			},
		},
	})
	var funded := mana.availability_snapshot(0)
	_expect(bool(mana_seed.get("advanced", false)) and int((funded.get("assets", {}) as Dictionary).get(FACILITY_INDUSTRY_ID, 0)) == 2, "PlayerMana production owner funds exactly two life assets for Rank-II reservation")

	var target_region_id := _first_facility_target_region(region_bridge)
	var actor_id := str(coordinator.actor_id_for_player_index(0).get("actor_id", ""))
	var player_before := inventory.player_snapshot(actor_id)
	var card_count_before := _inventory_card_count(player_before)
	var grant := inventory.grant_card(
		actor_id,
		FACILITY_CARD_ID,
		int(player_before.get("revision", -1)),
		"alpha04c-save-envelope-rank-two-grant",
		"alpha04c_save_envelope"
	)
	var player_after_grant := inventory.player_snapshot(actor_id)
	var card := _card_binding(player_after_grant, FACILITY_CARD_ID)
	_expect(bool(grant.get("committed", false)) and not card.is_empty() and not target_region_id.is_empty(), "production Inventory grants one stable Rank-II facility instance and RegionInfrastructure supplies its target")
	if not bool(grant.get("committed", false)) or card.is_empty() or target_region_id.is_empty():
		return {}

	coordinator.resume_session()
	var presentation_bundle: Dictionary = presentation.call("compose_table_state_bundle", 0, true)
	var source_revision := int(presentation.call("current_action_offer_revision", 0))
	var offer := action_flow.human_card_play_offer(
		0,
		int(card.get("slot_index", -1)),
		source_revision,
		true,
		"none",
		target_region_id
	)
	var intent := GAME_ACTION_INTENT.build({
		"schema_version": GAME_ACTION_INTENT.SCHEMA_VERSION,
		"request_id": "request.alpha04c.save.facility.rank2",
		"semantic_action_id": GAME_ACTION_INTENT.ACTION_CARD_PLAY,
		"source_revision": int(offer.get("source_revision", 0)),
		"actor_authorization": action_flow.human_actor_authorization("alpha04c-save-envelope"),
		"target_ids": GAME_ACTION_OFFER.target_ids(offer),
		"parameters": {},
		"submission_kind": "human_click",
	})
	_expect(not presentation_bundle.is_empty() and source_revision > 0 \
			and bool(GAME_ACTION_OFFER.validation_report(offer).get("valid", false)) \
			and bool(GAME_ACTION_INTENT.validation_report(intent).get("valid", false)) \
			and GAME_ACTION_OFFER.accepts_intent(offer, intent), "production Player projection authors one valid prebound Rank-II facility intent")
	var adapter_before := adapter.debug_snapshot()
	var facilities_before := infrastructure.facilities_snapshot(false)
	var history_before := history.to_save_data()
	var execution_before := execution.to_save_data()
	var submitted := action_flow.submit_intent(intent)
	var entry := _single_queued_entry(queue)
	var facility_binding: Dictionary = entry.get("v06_facility_action", {}) if entry.get("v06_facility_action") is Dictionary else {}
	var reservation_ref: Dictionary = facility_binding.get("asset_reservation", {}) if facility_binding.get("asset_reservation") is Dictionary else {}
	var reservation := mana.reservation_snapshot(str(reservation_ref.get("reservation_id", "")))
	var player_after_submit := inventory.player_snapshot(actor_id)
	var funded_after_submit := mana.availability_snapshot(0)
	var life_balance: Dictionary = (funded_after_submit.get("balances", {}) as Dictionary).get(FACILITY_INDUSTRY_ID, {}) \
			if (funded_after_submit.get("balances", {}) as Dictionary).get(FACILITY_INDUSTRY_ID, {}) is Dictionary else {}
	var ready := bool(submitted.get("accepted", false)) \
		and str(submitted.get("reason_id", "")) == "facility-card-queued" \
		and _public_queue_count(queue) == 1 \
		and int(facility_binding.get("rank", 0)) == 2 \
		and int(facility_binding.get("submitted_at_world_time", -1)) == EXPECTED_SUBMISSION_WORLD_TIME_MS \
		and bool(reservation_ref.get("required", false)) \
		and str(reservation.get("state", "")) == "reserved" \
		and int((reservation.get("asset_cost", {}) as Dictionary).get(FACILITY_INDUSTRY_ID, 0)) == 2 \
		and int(life_balance.get("balance_milliunits", -1)) == 2000 \
		and int(life_balance.get("reserved_milliunits", -1)) == 2000 \
		and _inventory_card_count(player_after_submit) == card_count_before \
		and (history_before.get("history", []) as Array).is_empty() \
		and (execution_before.get("completed_resolution_ids", []) as Array).is_empty()
	_expect(ready, "queued Rank-II bundle binds escrow, target, request, millisecond timestamp, and a nonzero PlayerMana reservation without resolving")
	return {
		"ready": ready,
		"actor_id": actor_id,
		"target_region_id": target_region_id,
		"card_count_before": card_count_before,
		"facilities_before_count": facilities_before.size(),
		"resolution_id": int(entry.get("resolution_id", -1)),
		"queue_entry": entry.duplicate(true),
		"binding": facility_binding.duplicate(true),
		"reservation_id": str(reservation_ref.get("reservation_id", "")),
		"escrow_id": str((facility_binding.get("card_escrow", {}) as Dictionary).get("escrow_id", "")),
		"adapter_resolution_count_before": int(adapter_before.get("resolution_count", 0)),
		"world": world,
		"infrastructure": infrastructure,
		"inventory": inventory,
		"mana": mana,
		"queue": queue,
		"execution": execution,
		"history": history,
		"adapter": adapter,
	}


func _assert_queued_facility_envelope(handshake: Node, envelope: Dictionary, facility_case: Dictionary, phase: String) -> void:
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections") is Dictionary else {}
	var queue_state := _decoded_section(handshake, envelope, "card_resolution_queue")
	var session_state := _decoded_section(handshake, envelope, "session")
	var mana_state := _decoded_section(handshake, envelope, "player_mana")
	var infrastructure_state := _decoded_section(handshake, envelope, "region_infrastructure")
	var execution_state := _decoded_section(handshake, envelope, "card_resolution_execution")
	var history_state := _decoded_section(handshake, envelope, "card_resolution_history")
	var entries: Array = queue_state.get("current_queue", []) if queue_state.get("current_queue") is Array else []
	var entry: Dictionary = entries[0] if entries.size() == 1 and entries[0] is Dictionary else {}
	var binding: Dictionary = entry.get("v06_facility_action", {}) if entry.get("v06_facility_action") is Dictionary else {}
	var target: Dictionary = binding.get("prebound_target", {}) if binding.get("prebound_target") is Dictionary else {}
	var reservation_ref: Dictionary = binding.get("asset_reservation", {}) if binding.get("asset_reservation") is Dictionary else {}
	var escrow_ref: Dictionary = binding.get("card_escrow", {}) if binding.get("card_escrow") is Dictionary else {}
	var world_state: Dictionary = session_state.get("world_session_state", {}) if session_state.get("world_session_state") is Dictionary else {}
	var players: Array = world_state.get("players", []) if world_state.get("players") is Array else []
	var player: Dictionary = players[0] if not players.is_empty() and players[0] is Dictionary else {}
	var escrows: Dictionary = player.get("facility_card_escrows", {}) if player.get("facility_card_escrows") is Dictionary else {}
	var escrow: Dictionary = escrows.get(str(escrow_ref.get("escrow_id", "")), {}) if escrows.get(str(escrow_ref.get("escrow_id", "")), {}) is Dictionary else {}
	var reservations: Dictionary = mana_state.get("reservations", {}) if mana_state.get("reservations") is Dictionary else {}
	var reservation: Dictionary = reservations.get(str(reservation_ref.get("reservation_id", "")), {}) if reservations.get(str(reservation_ref.get("reservation_id", "")), {}) is Dictionary else {}
	var target_region := _saved_region(infrastructure_state, str(target.get("region_id", "")))
	var slots: Array = player.get("slots", []) if player.get("slots") is Array else []
	var source_slot_index := int(binding.get("source_slot_index", -1))
	var card_record: Dictionary = escrow.get("card_record", {}) if escrow.get("card_record") is Dictionary else {}
	var card_machine: Dictionary = card_record.get("machine", {}) if card_record.get("machine") is Dictionary else {}

	_expect(sections.size() == 19 and not queue_state.is_empty() and not session_state.is_empty() \
			and not mana_state.is_empty() and not infrastructure_state.is_empty() \
			and not execution_state.is_empty() and not history_state.is_empty(), "%s envelope contains the same fixed 19 Save sections, including every facility dependency owner" % phase)
	_expect(entries.size() == 1 and (queue_state.get("active_entry", {}) as Dictionary).is_empty() \
			and (queue_state.get("next_queue", []) as Array).is_empty() \
			and bool(FACILITY_BINDING.validation_report(binding).get("valid", false)) \
			and int(entry.get("resolution_id", -1)) == int(facility_case.get("resolution_id", -2)), "%s envelope preserves one sealed queued facility entry and Queue revision" % phase)
	_expect(str(binding.get("request_id", "")) == str(escrow.get("request_id", "")) \
			and str(binding.get("intent_fingerprint", "")) == str(escrow.get("intent_fingerprint", "")) \
			and str(binding.get("card_instance_id", "")) == str(escrow.get("runtime_instance_id", "")) \
			and str(card_machine.get("card_id", "")) == FACILITY_CARD_ID \
			and source_slot_index >= 0 and source_slot_index < slots.size() and slots[source_slot_index] == null, "%s envelope stores the exact card instance in session-owned escrow, not in its former hand slot" % phase)
	_expect(bool(reservation_ref.get("required", false)) \
			and str(reservation.get("state", "")) == "reserved" \
			and reservation.get("asset_cost", {}) == entry.get("asset_cost", {}) \
			and reservation.get("asset_debit", {}) == entry.get("asset_debit", {}) \
			and int((reservation.get("asset_cost", {}) as Dictionary).get(FACILITY_INDUSTRY_ID, 0)) == 2, "%s envelope preserves the nonzero Rank-II reservation under PlayerMana authority" % phase)
	_expect(not target_region.is_empty() \
			and int(target_region.get("revision", -1)) == int(target.get("region_revision", -2)) \
			and int((infrastructure_state.get("slot_generations", {}) as Dictionary).get(str(target.get("target_slot_id", "")), 0)) == int(target.get("target_slot_generation", -2)), "%s envelope target binding matches RegionInfrastructure revision and slot generation" % phase)
	_expect((execution_state.get("completed_resolution_ids", []) as Array).is_empty() \
			and (execution_state.get("inflight_resolution_ids", []) as Array).is_empty() \
			and (execution_state.get("inflight_execution_transactions", []) as Array).is_empty() \
			and (execution_state.get("pending_settlements", []) as Array).is_empty(), "%s envelope includes explicit collision-free pre-resolution execution state" % phase)
	_expect((history_state.get("history", []) as Array).is_empty() \
			and (history_state.get("appended_resolution_ids", []) as Array).is_empty(), "%s envelope proves public history absence for the still-queued resolution" % phase)
	_expect(int(binding.get("submitted_at_world_time", -1)) == EXPECTED_SUBMISSION_WORLD_TIME_MS \
			and is_equal_approx(float(EXPECTED_SUBMISSION_WORLD_TIME_MS) / 1000.0, 12.346), "%s envelope canonicalizes submitted_at_world_time to nearest milliseconds" % phase)


func _test_restore_barrier_blocks_facility(coordinator: GameRuntimeCoordinator, facility_case: Dictionary) -> void:
	var barrier := coordinator.get_node_or_null("SaveRestoreRuntimeBarrier") as SaveRestoreRuntimeBarrier
	var runtime_loop := coordinator.get_node_or_null("RuntimeLoop") as RuntimeLoop
	var before := _facility_owner_evidence(facility_case)
	var operation_id := "alpha04c-facility-barrier-proof"
	var checkpoint := barrier.capture_global_checkpoint(operation_id) if barrier != null else {}
	var entered := barrier.enter_restore_barrier(operation_id, checkpoint.get("checkpoint", {})) \
			if barrier != null and bool(checkpoint.get("accepted", false)) else {}
	var blocked := runtime_loop.advance_frame_for_test(0.25) if runtime_loop != null and bool(entered.get("acquired", false)) else {}
	var during := _facility_owner_evidence(facility_case)
	var quiet := barrier.verify_restore_quiet(operation_id) if barrier != null and bool(entered.get("acquired", false)) else {}
	var rollback := barrier.rollback_restore_barrier(operation_id) if barrier != null and bool(entered.get("acquired", false)) else {}
	var after := _facility_owner_evidence(facility_case)
	_expect(bool(checkpoint.get("accepted", false)) and bool(entered.get("acquired", false)) \
			and str(blocked.get("stopped_reason", "")) == "save_restore_in_progress" \
			and not bool(blocked.get("frame_advanced", true)), "restore barrier rejects a real runtime frame while the queued facility is pending")
	_expect(before == during and bool(quiet.get("accepted", false)), "restore barrier produces zero Queue, escrow, reservation, target, execution, history, RNG, or world mutation")
	_expect(bool(rollback.get("applied", false)) and before == after, "barrier proof exits through exact global checkpoint rollback before registry apply")


func _test_facility_continues_once_after_restore(coordinator: GameRuntimeCoordinator, registry: Node, facility_case: Dictionary) -> void:
	var queue := facility_case.get("queue") as CardResolutionQueueRuntimeService
	var infrastructure := facility_case.get("infrastructure") as RegionInfrastructureRuntimeController
	var inventory := facility_case.get("inventory") as CommodityCardInventoryRuntimeController
	var mana := facility_case.get("mana") as PlayerManaRuntimeController
	var execution := facility_case.get("execution") as CardResolutionExecutionRuntimeService
	var history := facility_case.get("history") as CardResolutionHistoryRuntimeService
	var adapter := facility_case.get("adapter") as FacilityCardQueueAdapterV06
	var world := facility_case.get("world") as WorldSessionState
	var resolution_id := int(facility_case.get("resolution_id", -1))
	var reservation_id := str(facility_case.get("reservation_id", ""))
	var escrow_id := str(facility_case.get("escrow_id", ""))
	var frame := coordinator.advance_card_resolution_frame(0.0)
	var after_first := _facility_owner_evidence(facility_case)
	var mana_settlement := mana.reservation_settlement_snapshot(reservation_id)
	var history_state := history.to_save_data()
	var execution_state := execution.to_save_data()
	var player: Dictionary = world.players[0] if not world.players.is_empty() and world.players[0] is Dictionary else {}
	var escrow_receipts: Dictionary = player.get("facility_card_escrow_receipts", {}) if player.get("facility_card_escrow_receipts") is Dictionary else {}
	var escrow_receipt: Dictionary = escrow_receipts.get(escrow_id, {}) if escrow_receipts.get(escrow_id, {}) is Dictionary else {}
	var facility_binding: Dictionary = facility_case.get("binding", {}) as Dictionary
	var transaction_id := "facility-resolution.%d.%s" % [resolution_id, str(facility_binding.get("binding_fingerprint", "")).substr(0, 16)]
	var lifecycle := infrastructure.facility_action_lifecycle_snapshot(transaction_id)
	var postimage: Dictionary = lifecycle.get("postimage", {}) if lifecycle.get("postimage") is Dictionary else {}
	var facility_after: Dictionary = postimage.get("facility_after", {}) if postimage.get("facility_after") is Dictionary else {}
	var balance: Dictionary = ((mana.availability_snapshot(0).get("balances", {}) as Dictionary).get(FACILITY_INDUSTRY_ID, {}) as Dictionary)
	_expect(bool(frame.get("handled", false)) and _public_queue_count(queue) == 0 \
			and infrastructure.facilities_snapshot(false).size() == int(facility_case.get("facilities_before_count", -1)) + 1 \
			and int(adapter.debug_snapshot().get("resolution_count", 0)) == int(facility_case.get("adapter_resolution_count_before", -1)) + 1, "first legal post-barrier resolution step creates exactly one facility and drains the Queue")
	_expect(str(mana_settlement.get("state_id", "")) == "terminal" \
			and str(mana_settlement.get("outcome_id", "")) == "consumed" \
			and int(balance.get("balance_milliunits", -1)) == 0 \
			and int(balance.get("reserved_milliunits", -1)) == 0, "post-restore continuation consumes the Rank-II reservation exactly once")
	_expect(str(escrow_receipt.get("state_id", "")) == "consumed_finalized" \
			and _inventory_card_count(inventory.player_snapshot(str(facility_case.get("actor_id", "")))) == int(facility_case.get("card_count_before", -1)), "post-restore continuation finalizes the escrowed card exactly once")
	_expect((history_state.get("history", []) as Array).size() == 1 \
			and (history_state.get("appended_resolution_ids", []) as Array) == [resolution_id] \
			and (execution_state.get("completed_resolution_ids", []) as Array) == [resolution_id], "post-restore continuation writes one execution completion and one history row")
	_expect(str(lifecycle.get("state", "")) == "finalized" \
			and is_equal_approx(float(facility_after.get("built_at", -1.0)), float(EXPECTED_SUBMISSION_WORLD_TIME_MS) / 1000.0) \
			and int(round(float(facility_after.get("built_at", -1.0)) * 1000.0)) == EXPECTED_SUBMISSION_WORLD_TIME_MS, "millisecond-rounded submitted_at_world_time is equivalent at authoritative facility resolution")
	var final_capture: Dictionary = registry.capture_resume_envelope({
		"envelope_id": "alpha04c-production-registry-facility-complete",
		"write_id": "alpha04c-production-registry-facility-complete-write",
	})
	var final_capture_debug: Dictionary = registry.debug_snapshot()
	_expect(bool(final_capture.get("ok", false)) and ((final_capture.get("envelope", {}) as Dictionary).get("sections", {}) as Dictionary).size() == 19, "completed facility continuation remains capturable in the same 19-owner envelope|reason=%s|section=%s|internal=%s" % [
		str(final_capture.get("reason_code", "")),
		str(final_capture_debug.get("last_internal_capture_failure_section", "")),
		str(final_capture_debug.get("last_internal_capture_failure_reason", "")),
	])
	var duplicate_frame := coordinator.advance_card_resolution_frame(0.0)
	var after_duplicate := _facility_owner_evidence(facility_case)
	var execution_after_first: Dictionary = after_first.get("execution", {}) as Dictionary
	var execution_after_duplicate: Dictionary = after_duplicate.get("execution", {}) as Dictionary
	var execution_lineage_unchanged: bool = int(execution_after_duplicate.get("transaction_sequence", -1)) == int(execution_after_first.get("transaction_sequence", -2)) \
			and execution_after_duplicate.get("completed_resolution_ids") == execution_after_first.get("completed_resolution_ids") \
			and execution_after_duplicate.get("inflight_resolution_ids") == execution_after_first.get("inflight_resolution_ids") \
			and execution_after_duplicate.get("inflight_execution_transactions") == execution_after_first.get("inflight_execution_transactions") \
			and execution_after_duplicate.get("pending_settlements") == execution_after_first.get("pending_settlements")
	var duplicate_side_effect_free: bool = after_duplicate.get("world") == after_first.get("world") \
			and after_duplicate.get("mana") == after_first.get("mana") \
			and after_duplicate.get("infrastructure") == after_first.get("infrastructure") \
			and execution_lineage_unchanged \
			and after_duplicate.get("history") == after_first.get("history") \
			and after_duplicate.get("rng") == after_first.get("rng")
	_expect(not bool(duplicate_frame.get("resolved", false)) and duplicate_side_effect_free \
			and _public_queue_count(queue) == 0 \
			and int(adapter.debug_snapshot().get("resolution_count", 0)) == int(facility_case.get("adapter_resolution_count_before", -1)) + 1, "a second frame cannot duplicate facility, cost, card movement, execution, or history")


func _test_machine_readable_facility_dependencies() -> void:
	var graph := _json_document("res://docs/save/v06_restore_dependency_graph.json")
	var ledger := _json_document("res://docs/save/alpha04c_save_field_ownership_ledger.json")
	var graph_contract: Dictionary = graph.get("queued_facility_bundle_contract", {}) if graph.get("queued_facility_bundle_contract") is Dictionary else {}
	var queue_owner := _ledger_section(ledger, "card_resolution_queue")
	var authoritative_fields: Array = queue_owner.get("authoritative_fields", []) if queue_owner.get("authoritative_fields") is Array else []
	var transaction_metadata_fields: Array = queue_owner.get("transaction_metadata_fields", []) if queue_owner.get("transaction_metadata_fields") is Array else []
	var restore_dependencies: Array = queue_owner.get("restore_dependencies", []) if queue_owner.get("restore_dependencies") is Array else []
	var cross_dependencies: Array = queue_owner.get("cross_section_dependencies", []) if queue_owner.get("cross_section_dependencies") is Array else []
	_expect(int((ledger.get("gates", {}) as Dictionary).get("required_section_count", 0)) == 19 \
			and (ledger.get("sections", []) as Array).size() == 19 \
			and int(graph_contract.get("save_section_count", 0)) == 19 \
			and int(graph_contract.get("new_save_section_count", -1)) == 0, "machine-readable Save ownership remains exactly 19 sections after facility Queue integration")
	_expect(_has_all(restore_dependencies, ["session_foundation", "region_infrastructure", "player_mana", "card_inventory"]) \
			and _has_all(cross_dependencies, ["card_resolution_execution", "card_resolution_history"]) \
			and _graph_has_edge(graph, "region_infrastructure", "card_resolution_queue") \
			and _graph_has_edge(graph, "player_mana", "card_resolution_queue") \
			and _graph_has_edge(graph, "card_resolution_queue", "card_resolution_execution") \
			and _graph_has_edge(graph, "card_resolution_execution", "card_resolution_history"), "machine-readable DAG and cross-section contract name every queued facility dependency")
	_expect(not authoritative_fields.has("queued_facility_action_bindings") \
			and _has_all(transaction_metadata_fields, [
				"current_queue[].v06_facility_action",
				"next_queue[].v06_facility_action",
				"active_entry.v06_facility_action",
			]), "machine-readable ownership names the exact persisted nested facility binding paths without aliases")
	_expect(_restore_graph_matches_production_order(graph), "the full dependency graph is acyclic and its topological order exactly matches the production Registry constant")


func _facility_owner_evidence(facility_case: Dictionary) -> Dictionary:
	var world := facility_case.get("world") as WorldSessionState
	var world_capture := world.capture_envelope_save_data() if world != null else {}
	var coordinator := world.get_parent() as GameRuntimeCoordinator if world != null else null
	var rng := coordinator.get_node_or_null("RunRngService") if coordinator != null else null
	return {
		"queue": (facility_case.get("queue") as CardResolutionQueueRuntimeService).to_save_data(),
		"world": (world_capture.get("normalized_state", {}) as Dictionary).duplicate(true),
		"mana": (facility_case.get("mana") as PlayerManaRuntimeController).to_save_data(),
		"infrastructure": (facility_case.get("infrastructure") as RegionInfrastructureRuntimeController).to_save_data(),
		"execution": (facility_case.get("execution") as CardResolutionExecutionRuntimeService).to_save_data(),
		"history": (facility_case.get("history") as CardResolutionHistoryRuntimeService).to_save_data(),
		"rng": (rng.call("to_save_data") as Dictionary).duplicate(true) if rng != null else {},
	}


func _decoded_section(handshake: Node, envelope: Dictionary, section_id: String) -> Dictionary:
	var sections: Dictionary = envelope.get("sections", {}) if envelope.get("sections") is Dictionary else {}
	var wrapper: Dictionary = sections.get(section_id, {}) if sections.get(section_id) is Dictionary else {}
	if handshake == null or wrapper.is_empty() or not handshake.has_method("decode_codec_value"):
		return {}
	var decoded: Dictionary = handshake.call("decode_codec_value", wrapper.get("owner_state"))
	return (decoded.get("value", {}) as Dictionary).duplicate(true) \
			if bool(decoded.get("ok", false)) and decoded.get("value") is Dictionary else {}


func _single_queued_entry(queue: CardResolutionQueueRuntimeService) -> Dictionary:
	if queue == null:
		return {}
	var entries: Array = []
	entries.append_array(queue.current_queue())
	var active := queue.active_entry()
	if not active.is_empty():
		entries.append(active)
	entries.append_array(queue.next_queue())
	return (entries[0] as Dictionary).duplicate(true) if entries.size() == 1 and entries[0] is Dictionary else {}


func _public_queue_count(queue: CardResolutionQueueRuntimeService) -> int:
	if queue == null:
		return -1
	var public := queue.public_snapshot()
	return int(public.get("current_count", 0)) + int(public.get("next_count", 0)) \
			+ (1 if bool(public.get("active_present", false)) else 0)


func _card_binding(player: Dictionary, card_id: String) -> Dictionary:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory") is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots") is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var card := slots[slot_index] as Dictionary
		var machine: Dictionary = card.get("machine", {}) if card.get("machine") is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			var result := card.duplicate(true)
			result["slot_index"] = slot_index
			return result
	return {}


func _inventory_card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory") is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots") is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _first_facility_target_region(region_bridge: Node) -> String:
	if region_bridge == null or not region_bridge.has_method("public_new_facility_target_candidates"):
		return ""
	var result: Dictionary = region_bridge.call("public_new_facility_target_candidates", &"factory", StringName(FACILITY_INDUSTRY_ID))
	var candidates: Array = result.get("candidates", []) if result.get("candidates") is Array else []
	return str((candidates[0] as Dictionary).get("region_id", "")) \
			if bool(result.get("available", false)) and not candidates.is_empty() and candidates[0] is Dictionary else ""


func _saved_region(infrastructure_state: Dictionary, region_id: String) -> Dictionary:
	var regions: Array = infrastructure_state.get("regions", []) if infrastructure_state.get("regions") is Array else []
	for region_variant in regions:
		if region_variant is Dictionary and str((region_variant as Dictionary).get("region_id", "")) == region_id:
			return (region_variant as Dictionary).duplicate(true)
	return {}


func _json_document(path: String) -> Dictionary:
	var parser := JSON.new()
	return (parser.data as Dictionary).duplicate(true) \
			if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary else {}


func _ledger_section(ledger: Dictionary, section_id: String) -> Dictionary:
	var sections: Array = ledger.get("sections", []) if ledger.get("sections") is Array else []
	for section_variant in sections:
		if section_variant is Dictionary and str((section_variant as Dictionary).get("section_id", "")) == section_id:
			return (section_variant as Dictionary).duplicate(true)
	return {}


func _graph_has_edge(graph: Dictionary, source_id: String, target_id: String) -> bool:
	var edges: Array = graph.get("edges", []) if graph.get("edges") is Array else []
	for edge_variant in edges:
		if edge_variant is Array and (edge_variant as Array).size() == 2 \
				and str((edge_variant as Array)[0]) == source_id and str((edge_variant as Array)[1]) == target_id:
			return true
	return false


func _restore_graph_matches_production_order(graph: Dictionary) -> bool:
	var nodes: Array = graph.get("nodes", []) if graph.get("nodes") is Array else []
	var edges: Array = graph.get("edges", []) if graph.get("edges") is Array else []
	var order: Array = graph.get("topological_order", []) if graph.get("topological_order") is Array else []
	var node_ids: Array = []
	for node_variant in nodes:
		if not (node_variant is Dictionary):
			return false
		node_ids.append(str((node_variant as Dictionary).get("id", "")))
	if node_ids != V06SaveOwnerRegistry.RESTORE_DAG_NODE_ORDER \
			or order != V06SaveOwnerRegistry.RESTORE_DAG_NODE_ORDER:
		return false
	var index_by_id: Dictionary = {}
	for index in range(order.size()):
		var node_id := str(order[index])
		if node_id.is_empty() or index_by_id.has(node_id):
			return false
		index_by_id[node_id] = index
	var seen_edges: Dictionary = {}
	for edge_variant in edges:
		if not (edge_variant is Array) or (edge_variant as Array).size() != 2:
			return false
		var edge := edge_variant as Array
		var source_id := str(edge[0])
		var target_id := str(edge[1])
		var edge_id := "%s->%s" % [source_id, target_id]
		if not index_by_id.has(source_id) or not index_by_id.has(target_id) \
				or int(index_by_id[source_id]) >= int(index_by_id[target_id]) \
				or seen_edges.has(edge_id):
			return false
		seen_edges[edge_id] = true
	return true


func _has_all(values: Array, expected: Array) -> bool:
	for item in expected:
		if not values.has(item):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("ALPHA04C_PRODUCTION_REGISTRY_TRANSACTION_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	quit(0 if _failures.is_empty() else 1)
