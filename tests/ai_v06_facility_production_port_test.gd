extends SceneTree

const GAME_ACTION_INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const GAME_ACTION_OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/ai_v06_facility_production_port.save"
const FACTORY_INDUSTRY_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_qa_save()
	var started: Dictionary = await SESSION_START_DRIVER.start_default_session(
		self,
		QA_SAVE_PATH,
		"ai-v06-facility-production-action-spine"
	)
	var main := started.get("main_root") as Node
	var coordinator := started.get("coordinator") as GameRuntimeCoordinator
	_expect(bool(started.get("started", false)), "production fixture starts through the formal SessionStartTransaction")
	_expect(bool(started.get("qa_save_override_ready", false)), "production fixture isolates its save path")
	_expect(coordinator != null, "real default session composes the production Coordinator")
	if main == null or coordinator == null or not bool(started.get("started", false)):
		if main != null:
			main.queue_free()
		await process_frame
		_remove_qa_save()
		_finish()
		return
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var infrastructure: Object = coordinator.call("region_infrastructure_runtime_controller")
	_expect(infrastructure != null and not (infrastructure.call("regions_snapshot") as Array).is_empty(), "first-table fixture uses the initialized RegionInfrastructure owner")
	var region_bridge := coordinator.get_node_or_null("RegionInfrastructureWorldBridge")
	_expect(region_bridge != null, "authoritative region commodity facts bridge is composed")
	var binding: Dictionary = coordinator.call("refresh_v06_production_player_bindings")
	print("AI_V06_PORT_STAGE|stage=bind|queue=%s|state=%s|inventory=%s|core=%s|demand=%s|monster=%s" % [
		bool(binding.get("facility_card_queue_adapter_ready", false)),
		bool(binding.get("state_adapter_ready", false)),
		bool(binding.get("inventory_ready", false)),
		bool(binding.get("core_economic_ready", false)),
		bool(binding.get("public_demand_ready", false)),
		bool(binding.get("monster_card_adapter_ready", false)),
	])
	_expect(bool(binding.get("facility_card_queue_adapter_ready", false)), "Coordinator configures the one scene-owned facility Queue adapter")
	var facility_chain_ready := bool(binding.get("ready", false)) \
		and bool(binding.get("state_adapter_ready", false)) \
		and bool(binding.get("inventory_ready", false)) \
		and bool(binding.get("core_economic_ready", false)) \
		and bool(binding.get("facility_card_queue_adapter_ready", false)) \
		and bool(binding.get("public_demand_ready", false)) \
		and bool(binding.get("monster_card_adapter_ready", false))
	_expect(facility_chain_ready, "focused fixture composes every production owner used by the facility chain")
	var action_flow := coordinator.get_node_or_null("TablePlayerActionApplicationFlowController") as TablePlayerActionApplicationFlowController
	var resolution_queue := coordinator.get_node_or_null("CardResolutionQueueRuntimeService") as CardResolutionQueueRuntimeService
	var facility_adapter := coordinator.call("facility_card_queue_adapter_v06") as FacilityCardQueueAdapterV06
	var action_debug: Dictionary = action_flow.debug_snapshot() if action_flow != null else {}
	_expect(
		action_flow != null and resolution_queue != null and facility_adapter != null
			and bool(action_debug.get("ai_capability_bound", false)),
		"production scene composes one formal Action Spine, one Queue, and one facility bridge"
	)

	var players: Array = coordinator.world_session_state().players \
		if coordinator.world_session_state().players is Array else []
	var identity: Dictionary = coordinator.call("actor_id_for_player_index", 0)
	var actor_id := str(identity.get("actor_id", ""))
	_expect(
		bool(identity.get("available", false)) and actor_id == "player.0"
			and not players.is_empty() and players[0] is Dictionary
			and str((players[0] as Dictionary).get("actor_id", "")) == actor_id,
		"formal session and CardPlayerState adapter agree on the stable actor binding"
	)
	var source_before: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(bool(source_before.get("available", false)) and not bool(source_before.get("has_source", true)), "source snapshot reads existing owners and starts empty")
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var flow: Object = coordinator.call("commodity_flow_runtime_controller")
	var core := coordinator.core_economic_card_runtime_adapter_v06()
	var player_before: Dictionary = inventory.player_snapshot(actor_id) if inventory != null else {}
	var card_count_before := _inventory_card_count(player_before)
	_expect(not player_before.is_empty() and player_before.get("inventory", {}) is Dictionary, "production Inventory exposes the authoritative player card state")
	var public_target := _first_public_factory_target(region_bridge)
	var facility_card_id := str(public_target.get("card_id", ""))
	var target_region_id := str(public_target.get("region_id", ""))
	_expect(not facility_card_id.is_empty() and not target_region_id.is_empty(), "public infrastructure facts select one canonical rank-I factory and target")
	var facilities_before: Array = infrastructure.call("facilities_snapshot", false)
	var installations_before: Array = flow.call("installations_snapshot", false)
	var journal_before: Dictionary = inventory.transaction_journal_snapshot() if inventory != null else {}
	var grant_transaction_id := "facility-action-spine-grant-player-0"
	var grant: Dictionary = inventory.grant_card(
		actor_id,
		facility_card_id,
		int(player_before.get("revision", -1)),
		grant_transaction_id,
		"focused_facility_action_spine"
	) if inventory != null else {}
	_expect(bool(grant.get("committed", false)), "focused setup grants the canonical facility through the existing Inventory owner")
	var player_after_grant: Dictionary = inventory.player_snapshot(actor_id) if inventory != null else {}
	var card_binding := _card_binding(player_after_grant, facility_card_id)
	_expect(
		not card_binding.is_empty()
			and _inventory_card_count(player_after_grant) == card_count_before + 1
			and int(player_after_grant.get("cash", 0)) == int(player_before.get("cash", -1)),
		"grant exposes one stable runtime facility card without masquerading as a purchase"
	)
	_expect((infrastructure.call("facilities_snapshot", false) as Array).size() == facilities_before.size(), "card acquisition alone never writes a facility")
	var grant_replay: Dictionary = inventory.grant_card(
		actor_id,
		facility_card_id,
		int(player_before.get("revision", -1)),
		grant_transaction_id,
		"focused_facility_action_spine"
	) if inventory != null else {}
	_expect(
		bool(grant_replay.get("committed", false))
			and bool(grant_replay.get("idempotent_replay", false))
			and _inventory_card_count(inventory.player_snapshot(actor_id)) == card_count_before + 1,
		"Inventory grant replay is exact-once"
	)
	var journal_after_grant: Dictionary = inventory.transaction_journal_snapshot() if inventory != null else {}
	_expect(journal_after_grant.size() == journal_before.size() + 1 and journal_after_grant.has(grant_transaction_id), "grant remains the only Inventory transaction before formal card submission")

	var source_after_grant: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(
		not bool(source_after_grant.get("has_source", true))
			and int(source_after_grant.get("owned_facility_count", -1)) == 0
			and int(source_after_grant.get("production_installation_count", -1)) == 0,
		"owning a card may refresh target facts but fabricates no facility or installation"
	)
	var target_preflight := core.preflight_facility_target(
		0,
		int(card_binding.get("slot_index", -1)),
		facility_card_id,
		target_region_id,
		coordinator.world_session_state().game_time
	)
	_expect(bool(target_preflight.get("ready", false)), "facility intent binds the public target accepted by the production preflight owner")
	coordinator.call("resume_session")
	_expect(not bool(coordinator.call("session_is_paused")) and not bool(coordinator.call("session_is_finished")), "formal facility submission runs only in the active session")
	var presentation_query := coordinator.get_node_or_null("TablePresentationViewModelQuery")
	var presentation_bundle: Dictionary = presentation_query.call("compose_table_state_bundle", 0, true) if presentation_query != null else {}
	var source_revision := int(presentation_query.call("current_action_offer_revision", 0)) if presentation_query != null else 0
	_expect(not presentation_bundle.is_empty() and source_revision > 0, "production presentation owner issues a current action-offer revision")
	var offer := action_flow.human_card_play_offer(
		0,
		int(card_binding.get("slot_index", -1)),
		source_revision,
		true,
		"none",
		target_region_id
	) if action_flow != null else {}
	var authorization := action_flow.human_actor_authorization("qa-driver") if action_flow != null else {}
	var intent := GAME_ACTION_INTENT.build({
		"schema_version": GAME_ACTION_INTENT.SCHEMA_VERSION,
		"request_id": "request.facility.production.player.0",
		"semantic_action_id": GAME_ACTION_INTENT.ACTION_CARD_PLAY,
		"source_revision": int(offer.get("source_revision", 0)),
		"actor_authorization": authorization,
		"target_ids": GAME_ACTION_OFFER.target_ids(offer),
		"parameters": {},
		"submission_kind": "human_click",
	})
	_expect(
		bool(GAME_ACTION_OFFER.validation_report(offer).get("valid", false))
			and bool(GAME_ACTION_INTENT.validation_report(intent).get("valid", false))
			and GAME_ACTION_OFFER.accepts_intent(offer, intent),
		"production facility card is bound to one closed offer and GameActionIntentV1"
	)

	var queue_count_before := _public_queue_count(resolution_queue)
	var adapter_before: Dictionary = facility_adapter.debug_snapshot() if facility_adapter != null else {}
	var mana := coordinator.get_node_or_null("PlayerManaRuntimeController") as PlayerManaRuntimeController
	var mana_before_submission: Dictionary = mana.call("availability_snapshot", 0) if mana != null else {}
	var receipt := action_flow.submit_intent(intent) if action_flow != null else {}
	var adapter_after_submission: Dictionary = facility_adapter.debug_snapshot() if facility_adapter != null else {}
	var player_after_submission: Dictionary = inventory.player_snapshot(actor_id) if inventory != null else {}
	var mana_after_submission: Dictionary = mana.call("availability_snapshot", 0) if mana != null else {}
	var queued_entry := _single_queued_entry(resolution_queue)
	var queued_binding: Dictionary = queued_entry.get("v06_facility_action", {}) if queued_entry.get("v06_facility_action", {}) is Dictionary else {}
	var reservation_ref: Dictionary = queued_binding.get("asset_reservation", {}) if queued_binding.get("asset_reservation", {}) is Dictionary else {}
	var reservation: Dictionary = mana.call("reservation_snapshot", str(reservation_ref.get("reservation_id", ""))) \
		if mana != null and bool(reservation_ref.get("required", false)) else {}
	var queued_asset_cost: Dictionary = queued_entry.get("asset_cost", {}) \
		if queued_entry.get("asset_cost", {}) is Dictionary else {}
	var queued_asset_total := _asset_total(queued_asset_cost)
	var cost_binding_valid := (
		queued_asset_total == 0
			and not bool(reservation_ref.get("required", false))
			and mana_after_submission == mana_before_submission
	) or (
		queued_asset_total > 0
			and bool(reservation_ref.get("required", false))
			and str(reservation.get("state", "")) == "reserved"
	)
	_expect(
		bool(receipt.get("accepted", false))
			and str(receipt.get("reason_id", "")) == "facility-card-queued"
			and queue_count_before == 0
			and _public_queue_count(resolution_queue) == 1,
		"formal Action Spine accepts the facility as one queued resolution"
	)
	_expect(
		int(adapter_after_submission.get("queued_count", 0)) == int(adapter_before.get("queued_count", 0)) + 1
			and int(adapter_after_submission.get("resolution_count", 0)) == int(adapter_before.get("resolution_count", 0))
			and str((queued_entry.get("skill", {}) as Dictionary).get("kind", "")) == "public_facility"
			and not queued_binding.is_empty(),
		"Queue entry carries the sealed facility binding without claiming resolution"
	)
	_expect(
		(infrastructure.call("facilities_snapshot", false) as Array) == facilities_before
			and (flow.call("installations_snapshot", false) as Array) == installations_before,
		"Queue submission performs no immediate facility or production-installation mutation"
	)
	_expect(
		_inventory_card_count(player_after_submission) == card_count_before
			and bool(mana_before_submission.get("valid", false))
			and bool(mana_after_submission.get("valid", false))
			and cost_binding_valid,
		"submission escrows one card and binds zero or nonzero activation cost without spending it twice"
	)

	var replay_before_resolution := action_flow.submit_intent(intent) if action_flow != null else {}
	_expect(
		bool(replay_before_resolution.get("accepted", false))
			and bool(replay_before_resolution.get("idempotent_replay", false))
			and _public_queue_count(resolution_queue) == 1
			and (facility_adapter.debug_snapshot() as Dictionary) == adapter_after_submission
			and (mana.call("availability_snapshot", 0) as Dictionary) == mana_after_submission,
		"duplicate intent replays without a second queue entry, escrow, or asset reservation"
	)

	var resolution_frame: Dictionary = coordinator.call("advance_card_resolution_frame", 0.0)
	var adapter_after_resolution: Dictionary = facility_adapter.debug_snapshot() if facility_adapter != null else {}
	var facilities_after_resolution: Array = infrastructure.call("facilities_snapshot", false)
	var installations_after_resolution: Array = flow.call("installations_snapshot", false)
	var player_after_resolution: Dictionary = inventory.player_snapshot(actor_id) if inventory != null else {}
	var mana_after_resolution: Dictionary = mana.call("availability_snapshot", 0) if mana != null else {}
	_expect(
		bool(resolution_frame.get("handled", false))
			and _public_queue_count(resolution_queue) == 0
			and int(adapter_after_resolution.get("resolution_count", 0)) == int(adapter_before.get("resolution_count", 0)) + 1,
		"one authorized resolution frame settles the queued facility exactly once"
	)
	_expect(
		facilities_after_resolution.size() == facilities_before.size() + 1
			and installations_after_resolution.size() == installations_before.size() + 1
			and _inventory_card_count(player_after_resolution) == card_count_before,
		"resolution creates one facility and one production installation while consuming one escrowed card"
	)
	var source_after_resolution: Dictionary = coordinator.call("economic_source_snapshot", actor_id)
	_expect(
		bool(source_after_resolution.get("has_source", false))
			and int(source_after_resolution.get("owned_facility_count", 0)) == 1
			and int(source_after_resolution.get("production_installation_count", 0)) == 1,
		"economic source projection derives the resolved facility from existing domain owners"
	)

	var replay_after_resolution := action_flow.submit_intent(intent) if action_flow != null else {}
	var duplicate_frame: Dictionary = coordinator.call("advance_card_resolution_frame", 0.0)
	var journal_after: Dictionary = inventory.transaction_journal_snapshot() if inventory != null else {}
	var player_after_duplicates: Dictionary = inventory.player_snapshot(actor_id) if inventory != null else {}
	_expect(
		bool(replay_after_resolution.get("idempotent_replay", false))
			and _public_queue_count(resolution_queue) == 0
			and (infrastructure.call("facilities_snapshot", false) as Array) == facilities_after_resolution
			and (flow.call("installations_snapshot", false) as Array) == installations_after_resolution,
		"post-resolution intent replay and an empty transition cannot duplicate facility owners"
	)
	_expect(
		_inventory_card_count(player_after_duplicates) == card_count_before
			and int(player_after_duplicates.get("cash", -1)) == int(player_after_grant.get("cash", -2))
			and (mana.call("availability_snapshot", 0) as Dictionary) == mana_after_resolution
			and journal_after == journal_after_grant,
		"duplicate transitions consume neither another card, cash payment, asset cost, nor Inventory transaction"
	)
	_expect(
		int((facility_adapter.debug_snapshot() as Dictionary).get("resolution_count", 0)) == int(adapter_after_resolution.get("resolution_count", 0))
			and not bool(duplicate_frame.get("resolved", false)),
		"empty follow-up frame leaves the facility bridge resolution counter unchanged"
	)

	main.queue_free()
	await process_frame
	_remove_qa_save()
	_finish()


func _public_queue_count(queue: CardResolutionQueueRuntimeService) -> int:
	if queue == null:
		return -1
	var snapshot := queue.public_snapshot()
	return int(snapshot.get("current_count", 0)) \
		+ (1 if bool(snapshot.get("active_present", false)) else 0) \
		+ int(snapshot.get("next_count", 0))


func _single_queued_entry(queue: CardResolutionQueueRuntimeService) -> Dictionary:
	if queue == null:
		return {}
	var entries: Array = []
	entries.append_array(queue.current_queue())
	var active := queue.active_entry()
	if not active.is_empty():
		entries.append(active)
	entries.append_array(queue.next_queue())
	return (entries[0] as Dictionary).duplicate(true) \
		if entries.size() == 1 and entries[0] is Dictionary else {}


func _card_binding(player: Dictionary, card_id: String) -> Dictionary:
	var inventory: Dictionary = player.get("inventory", {}) \
		if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var card := slots[slot_index] as Dictionary
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			var result := card.duplicate(true)
			result["slot_index"] = slot_index
			return result
	return {}


func _inventory_card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) \
		if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	return slots.filter(func(slot: Variant) -> bool: return slot is Dictionary).size()


func _asset_total(cost: Dictionary) -> int:
	var total := 0
	for value in cost.values():
		total += maxi(0, int(value))
	return total


func _first_public_factory_target(region_bridge: Node) -> Dictionary:
	if region_bridge == null or not region_bridge.has_method("public_new_facility_target_candidates"):
		return {}
	for industry_id in FACTORY_INDUSTRY_IDS:
		var result: Dictionary = region_bridge.call(
			"public_new_facility_target_candidates",
			&"factory",
			StringName(industry_id)
		)
		var candidates: Array = result.get("candidates", []) if result.get("candidates", []) is Array else []
		if bool(result.get("available", false)) and not candidates.is_empty() and candidates[0] is Dictionary:
			return {
				"card_id": "facility.factory.%s.rank_1" % industry_id,
				"region_id": str((candidates[0] as Dictionary).get("region_id", "")),
			}
	return {}


func _remove_qa_save() -> void:
	var absolute := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("AI_V06_FACILITY_PRODUCTION_PORT_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(_failures.size())
