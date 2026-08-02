extends SceneTree

const EXECUTION_SAVE_CODEC := preload("res://scripts/runtime/card_resolution_execution_save_wire_codec_v4.gd")

const RULESET := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")
const QUEUE_SCENE := preload("res://scenes/runtime/CardResolutionQueueRuntimeService.tscn")
const INFRASTRUCTURE_SCENE := preload("res://scenes/runtime/RegionInfrastructureRuntimeController.tscn")
const CARD_STATE_SCRIPT := preload("res://scripts/cards/v06/production/card_player_state_production_adapter_v06.gd")
const MANA_SCRIPT := preload("res://scripts/runtime/player_mana_runtime_controller.gd")
const Binding := preload("res://scripts/cards/v06/queued_facility_card_action_v1.gd")
const StableTarget := preload("res://scripts/runtime/card_resolution_stable_target_envelope.gd")
const Wire := preload("res://scripts/semantic/semantic_wire_v1.gd")

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const CARD_ID := "facility.factory.life.rank_2"
const SESSION_ID := "session.facility.restore"
const REGION_ID := "region.alpha"
const ASSET_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const PUBLIC_SNAPSHOT_KEYS := [
	"active",
	"active_present",
	"current",
	"current_count",
	"next",
	"next_count",
]
const PUBLIC_ENTRY_KEYS := [
	"card_kind",
	"card_name",
	"group_id",
	"group_order",
	"group_position",
	"group_size",
	"queued_behind_resolution",
	"resolution_id",
	"selected_district",
]
const PRIVATE_PUBLIC_KEY_SENTINELS := [
	"actor",
	"player",
	"seat",
	"color",
	"runtime_instance",
	"card_instance",
	"slot",
	"reservation",
	"escrow",
	"fingerprint",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _fixture()
	if fixture.is_empty():
		_finish()
		return
	var queue := fixture.get("queue") as CardResolutionQueueRuntimeService
	var state := queue.to_save_data()
	var all_states := fixture.get("all_states") as Dictionary
	var baseline := _preflight_without_mutation(queue, state, all_states)
	_expect(bool(baseline.get("accepted", false)) \
		and int(baseline.get("facility_reference_count", 0)) == 1 \
		and int(baseline.get("facility_escrow_reference_count", 0)) == 1, "complete waiting facility bundle passes candidate-only dependency preflight: %s target=%s region=%s" % [JSON.stringify(baseline), JSON.stringify(_binding(state).get("prebound_target", {})), JSON.stringify(all_states.get("region_infrastructure", {}))])
	_test_public_snapshot_restore_privacy(queue, state, all_states)
	var empty_queue := state.duplicate(true)
	empty_queue["current_queue"] = []
	empty_queue["active_entry"] = {}
	empty_queue["next_queue"] = []
	empty_queue["resolution_sequence"] = 0
	empty_queue["last_group_window_sequence"] = -1
	_expect_rejected(queue, empty_queue, all_states.duplicate(true), "an active facility escrow without a Queue or execution reference is rejected")
	var orphan_reservation := all_states.duplicate(true)
	_candidate_player(orphan_reservation)["facility_card_escrows"] = {}
	_expect_rejected(queue, empty_queue, orphan_reservation, "a facility asset reservation without a Queue or execution reference is rejected")
	var no_facility_commitments := orphan_reservation.duplicate(true)
	(no_facility_commitments.get("player_mana") as Dictionary)["reservations"] = {}
	_expect(bool(_preflight_without_mutation(queue, empty_queue, no_facility_commitments).get("accepted", false)), "an empty facility reference set is accepted only when no active escrow or facility reservation remains")

	var missing_escrow := all_states.duplicate(true)
	var missing_player := _candidate_player(missing_escrow)
	missing_player["facility_card_escrows"] = {}
	_expect_rejected(queue, state, missing_escrow, "missing facility escrow is rejected")

	var occupied_source := all_states.duplicate(true)
	var occupied_player := _candidate_player(occupied_source)
	var escrow := _first_escrow(occupied_player)
	(occupied_player.get("slots") as Array)[0] = (escrow.get("card_record") as Dictionary).duplicate(true)
	_expect_rejected(queue, state, occupied_source, "occupied source slot cannot coexist with committed escrow")

	var missing_reservation := all_states.duplicate(true)
	(missing_reservation.get("player_mana") as Dictionary)["reservations"] = {}
	_expect_rejected(queue, state, missing_reservation, "missing required reservation is rejected")

	var terminal_reservation := all_states.duplicate(true)
	var mana_state := terminal_reservation.get("player_mana") as Dictionary
	var reservation_id := str(_binding(state).get("asset_reservation", {}).get("reservation_id", ""))
	var reservation := (mana_state.get("reservations") as Dictionary).get(reservation_id) as Dictionary
	var reservation_snapshot := _reservation_snapshot(reservation)
	(mana_state.get("reservations") as Dictionary).erase(reservation_id)
	(mana_state.get("terminal_receipts") as Dictionary)[reservation_id] = {
		"player_index": 0,
		"asset_debit": reservation_snapshot.get("asset_debit"),
		"debit_milliunits": reservation_snapshot.get("debit_milliunits"),
		"reservation_binding": reservation_snapshot,
		"reservation_reserved_at": 0.0,
	}
	_expect_rejected(queue, state, terminal_reservation, "waiting queue cannot bind a terminal reservation")

	var stale_target := all_states.duplicate(true)
	var target := _binding(state).get("prebound_target") as Dictionary
	(stale_target.get("region_infrastructure") as Dictionary).get("slot_generations")[str(target.get("target_slot_id", ""))] = int(target.get("target_slot_generation", 0)) + 1
	_expect_rejected(queue, state, stale_target, "stale target slot generation is rejected")
	var stale_region := all_states.duplicate(true)
	var stale_regions := (stale_region.get("region_infrastructure") as Dictionary).get("regions") as Array
	(stale_regions[0] as Dictionary)["revision"] = int((stale_regions[0] as Dictionary).get("revision", 0)) + 1
	_expect_rejected(queue, state, stale_region, "queued pre-effect target still requires the exact committed region revision")

	var half_finalized := all_states.duplicate(true)
	(half_finalized.get("region_infrastructure") as Dictionary)["facility_action_lifecycles"] = {
		"facility-resolution.1.test": {"state": "applied"},
	}
	_expect_rejected(queue, state, half_finalized, "applied-but-unfinalized facility lifecycle is not restorable")

	var stale_session := all_states.duplicate(true)
	(stale_session.get("session") as Dictionary).get("game_session_runtime")["seed"] = 99
	_expect_rejected(queue, state, stale_session, "persistent session identity drift is rejected")

	var consumed_pending := all_states.duplicate(true)
	var pending_player := _candidate_player(consumed_pending)
	var pending_escrow := _first_escrow(pending_player)
	pending_escrow["state_id"] = "consumed_pending_finalization"
	pending_escrow["predecessor_escrow_fingerprint"] = str(pending_escrow.get("escrow_fingerprint", ""))
	pending_escrow["escrow_fingerprint"] = _fingerprint(_without_field(pending_escrow, "escrow_fingerprint"))
	_expect_rejected(queue, state, consumed_pending, "consumed-pending escrow is rejected even when re-signed")

	var unknown_binding_field := state.duplicate(true)
	var hostile_entry := (unknown_binding_field.get("current_queue") as Array)[0] as Dictionary
	(hostile_entry.get("v06_facility_action") as Dictionary)["authorized"] = true
	_expect(not bool(queue.preflight_save_data(unknown_binding_field).get("accepted", true)), "caller-controlled authorization field fails local Queue schema preflight")

	var mutated_binding := state.duplicate(true)
	var mutated_entry := (mutated_binding.get("current_queue") as Array)[0] as Dictionary
	var unsealed := (mutated_entry.get("v06_facility_action") as Dictionary).duplicate(true)
	unsealed.erase("binding_fingerprint")
	unsealed["actor_player_index"] = 1
	unsealed["actor_id"] = "player.1"
	mutated_entry["v06_facility_action"] = Binding.build(unsealed)
	_expect(not bool(queue.preflight_save_data(mutated_binding).get("accepted", true)), "re-signed actor mirror mutation fails local Queue preflight")

	var validator := fixture.get("card_state") as CardPlayerStateProductionAdapterV06
	var session_world := (all_states.get("session") as Dictionary).get("world_session_state") as Dictionary
	var session_validation := validator.preflight_facility_card_escrow_world_state(session_world)
	_expect(bool(session_validation.get("accepted", false)), "Session escrow validator independently accepts the exact detached candidate")
	_test_post_effect_restore_semantics()
	_free_fixture(fixture)
	_finish()


func _test_post_effect_restore_semantics() -> void:
	var commitment_case := _post_effect_case("finalized", "consumed_pending")
	if not commitment_case.is_empty():
		var commitment_transaction := _post_effect_transaction(
			commitment_case.get("entry") as Dictionary,
			"finish_card_commitment",
			true
		)
		_install_inflight(commitment_case, commitment_transaction)
		var commitment_result := _preflight_without_mutation(
			commitment_case.get("queue") as CardResolutionQueueRuntimeService,
			commitment_case.get("queue_state") as Dictionary,
			commitment_case.get("all_states") as Dictionary
		)
		_expect(
			bool(commitment_result.get("accepted", false)),
			"finalized facility with consumed-pending card escrow restores at commitment retry: %s" % JSON.stringify(commitment_result)
		)
		_free_fixture(commitment_case)

	var history_case := _post_effect_case("finalized", "terminal")
	if not history_case.is_empty():
		var history_transaction := _post_effect_transaction(
			history_case.get("entry") as Dictionary,
			"append_history",
			true
		)
		_install_inflight(history_case, history_transaction)
		var history_result := _preflight_without_mutation(
			history_case.get("queue") as CardResolutionQueueRuntimeService,
			history_case.get("queue_state") as Dictionary,
			history_case.get("all_states") as Dictionary
		)
		_expect(
			bool(history_result.get("accepted", false)),
			"finalized facility with terminal commitments restores at history retry: %s" % JSON.stringify(history_result)
		)

		var stale_post_effect := (history_case.get("all_states") as Dictionary).duplicate(true)
		var stale_post_regions := (stale_post_effect.get("region_infrastructure") as Dictionary).get("regions") as Array
		(stale_post_regions[0] as Dictionary)["revision"] = int((stale_post_regions[0] as Dictionary).get("revision", 0)) + 1
		_expect_rejected(
			history_case.get("queue") as CardResolutionQueueRuntimeService,
			history_case.get("queue_state") as Dictionary,
			stale_post_effect,
			"post-effect restore rejects a stale current region that no longer matches the finalized lifecycle postimage"
		)

		var forged_post_effect := (history_case.get("all_states") as Dictionary).duplicate(true)
		_resign_forged_post_effect_owner(forged_post_effect, history_case.get("binding") as Dictionary)
		_expect_rejected(
			history_case.get("queue") as CardResolutionQueueRuntimeService,
			history_case.get("queue_state") as Dictionary,
			forged_post_effect,
			"re-signed post-effect lifecycle owner mutation cannot replace the Queue actor binding"
		)
		_free_fixture(history_case)

	var pending_case := _post_effect_case("finalized", "terminal")
	if not pending_case.is_empty():
		var pending_transaction := _post_effect_transaction(
			pending_case.get("entry") as Dictionary,
			"",
			true,
			true
		)
		_install_pending_settlement(pending_case, pending_transaction)
		var pending_result := _preflight_without_mutation(
			pending_case.get("queue") as CardResolutionQueueRuntimeService,
			pending_case.get("queue_state") as Dictionary,
			pending_case.get("all_states") as Dictionary
		)
		_expect(
			bool(pending_result.get("accepted", false)),
			"finalized facility remains restorable while execution settlement is pending: %s" % JSON.stringify(pending_result)
		)
		_free_fixture(pending_case)

	var rolled_back_case := _post_effect_case("rolled_back", "terminal")
	if not rolled_back_case.is_empty():
		var rolled_back_transaction := _post_effect_transaction(
			rolled_back_case.get("entry") as Dictionary,
			"finish_card_commitment",
			false
		)
		_install_inflight(rolled_back_case, rolled_back_transaction)
		var rolled_back_result := _preflight_without_mutation(
			rolled_back_case.get("queue") as CardResolutionQueueRuntimeService,
			rolled_back_case.get("queue_state") as Dictionary,
			rolled_back_case.get("all_states") as Dictionary
		)
		_expect(
			bool(rolled_back_result.get("accepted", false)),
			"rolled-back terminal facility lifecycle restores against its owner binding instead of the old region revision: %s" % JSON.stringify(rolled_back_result)
		)
		_free_fixture(rolled_back_case)


func _post_effect_case(lifecycle_outcome: String, escrow_outcome: String) -> Dictionary:
	var fixture := _fixture()
	if fixture.is_empty():
		return {}
	var queue := fixture.get("queue") as CardResolutionQueueRuntimeService
	var queue_state := queue.to_save_data()
	var entry := ((queue_state.get("current_queue") as Array)[0] as Dictionary).duplicate(true)
	var binding := (entry.get("v06_facility_action") as Dictionary).duplicate(true)
	var transaction_id := _facility_transaction_id(binding)
	var infrastructure := fixture.get("infrastructure") as RegionInfrastructureRuntimeController
	var effect_receipt := infrastructure.apply_facility_action({
		"transaction_id": transaction_id,
		"region_id": str((binding.get("prebound_target") as Dictionary).get("region_id", "")),
		"owner_kind": "player",
		"owner_player_index": int(binding.get("actor_player_index", -1)),
		"facility_type": str(binding.get("facility_kind_id", "")),
		"industry_id": str(binding.get("industry_id", "")),
		"rank": int(binding.get("rank", 0)),
		"occurred_at": float(int(binding.get("submitted_at_world_time", 0))) / 1000.0,
	})
	_expect(bool(effect_receipt.get("committed", false)), "post-effect fixture applies one authoritative facility action: %s" % JSON.stringify(effect_receipt))
	if not bool(effect_receipt.get("committed", false)):
		_free_fixture(fixture)
		return {}
	var lifecycle_receipt: Dictionary
	if lifecycle_outcome == "finalized":
		lifecycle_receipt = infrastructure.finalize_facility_action(effect_receipt)
		_expect(bool(lifecycle_receipt.get("finalized", false)), "post-effect fixture finalizes facility lifecycle")
	else:
		lifecycle_receipt = infrastructure.rollback_facility_action(effect_receipt)
		_expect(bool(lifecycle_receipt.get("rolled_back", false)), "post-effect fixture rolls facility lifecycle back")
	if not bool(lifecycle_receipt.get("finalized", false)) and not bool(lifecycle_receipt.get("rolled_back", false)):
		_free_fixture(fixture)
		return {}

	var card_state := fixture.get("card_state") as CardPlayerStateProductionAdapterV06
	var escrow_ref := binding.get("card_escrow") as Dictionary
	var escrow_id := str(escrow_ref.get("escrow_id", ""))
	if lifecycle_outcome == "finalized":
		var consumed := card_state.consume_facility_card_escrow(
			escrow_id,
			str(escrow_ref.get("escrow_fingerprint", ""))
		)
		_expect(bool(consumed.get("consumed", false)), "post-effect fixture consumes card escrow")
		if escrow_outcome == "terminal":
			var finalized := card_state.finalize_facility_card_escrow(
				escrow_id,
				str(consumed.get("escrow_fingerprint", ""))
			)
			_expect(bool(finalized.get("finalized", false)), "post-effect fixture finalizes card escrow")
	else:
		var released := card_state.release_facility_card_escrow(
			escrow_id,
			str(escrow_ref.get("escrow_fingerprint", "")),
			"post_effect_rollback"
		)
		_expect(bool(released.get("released", false)), "post-effect fixture releases rolled-back card escrow")

	var mana := fixture.get("mana") as PlayerManaRuntimeController
	var reservation_ref := binding.get("asset_reservation") as Dictionary
	if bool(reservation_ref.get("required", false)):
		var reservation_id := str(reservation_ref.get("reservation_id", ""))
		var mana_receipt := mana.consume_reservation(reservation_id, {"resolved": true}) \
				if lifecycle_outcome == "finalized" else mana.release_reservation(reservation_id, "post_effect_rollback")
		var expected_outcome := "consumed" if lifecycle_outcome == "finalized" else "released"
		_expect(str(mana_receipt.get("outcome", "")) == expected_outcome, "post-effect fixture settles asset reservation as %s" % expected_outcome)

	var all_states := fixture.get("all_states") as Dictionary
	var world := fixture.get("world") as WorldSessionState
	((all_states.get("session") as Dictionary).get("world_session_state") as Dictionary)["players"] = world.players.duplicate(true)
	all_states["player_mana"] = mana.to_save_data()
	all_states["region_infrastructure"] = infrastructure.to_save_data()
	queue_state["current_queue"] = []
	queue_state["active_entry"] = {}
	queue_state["next_queue"] = []
	fixture["queue_state"] = queue_state
	fixture["entry"] = entry
	fixture["binding"] = binding
	return fixture


func _post_effect_transaction(
	entry: Dictionary,
	next_intent_id: String,
	resolved: bool,
	pending_settlement: bool = false
) -> Dictionary:
	var resolution_id := int(entry.get("resolution_id", -1))
	var execution_id := 1
	var completed: Array = [
		"counter_check",
		"release_active",
		"finish_presentation",
		"revalidate_requirement",
		"revalidate_target",
		"dispatch_effect",
	]
	var commitment_checked := false
	var context_restored := false
	var history_appended := false
	if next_intent_id == "append_history" or pending_settlement:
		completed.append_array(["finish_card_commitment", "create_aftermath", "restore_context"])
		commitment_checked = true
		context_restored = true
	if pending_settlement:
		completed.append_array(["append_history", "finish_batch"])
		history_appended = true
	var next_intent := {}
	if not next_intent_id.is_empty():
		next_intent = {
			"intent_type": next_intent_id,
			"execution_id": execution_id,
			"resolution_id": resolution_id,
		}
	return {
		"status": "retryable" if not next_intent_id.is_empty() else "ready",
		"execution_id": execution_id,
		"resolution_id": resolution_id,
		"active_entry": entry.duplicate(true),
		"completed_intents": completed,
		"next_intent": next_intent,
		"active_released": true,
		"effect_dispatched": true,
		"resolved": resolved,
		"commitment_checked": commitment_checked,
		"context_restored": context_restored,
		"history_appended": history_appended,
	}


func _install_inflight(case_fixture: Dictionary, transaction: Dictionary) -> void:
	var execution := _execution_runtime_state(case_fixture)
	execution["inflight_resolution_ids"] = [int(transaction.get("resolution_id", -1))]
	execution["inflight_execution_transactions"] = [transaction.duplicate(true)]
	execution["pending_settlements"] = []
	_store_execution_runtime_state(case_fixture, execution)


func _install_pending_settlement(case_fixture: Dictionary, transaction: Dictionary) -> void:
	var execution := _execution_runtime_state(case_fixture)
	execution["completed_resolution_ids"] = [int(transaction.get("resolution_id", -1))]
	execution["inflight_resolution_ids"] = []
	execution["inflight_execution_transactions"] = []
	execution["pending_settlements"] = [{
		"resolution_id": int(transaction.get("resolution_id", -1)),
		"execution_id": int(transaction.get("execution_id", -1)),
		"transaction": transaction.duplicate(true),
		"finalized": {"completed": true},
	}]
	_store_execution_runtime_state(case_fixture, execution)


func _execution_runtime_state(case_fixture: Dictionary) -> Dictionary:
	var all_states := case_fixture.get("all_states") as Dictionary
	var decoded := EXECUTION_SAVE_CODEC.decode_save_state(all_states.get("card_resolution_execution") as Dictionary)
	return (decoded.get("value", {}) as Dictionary).duplicate(true) \
			if bool(decoded.get("ok", false)) and decoded.get("value") is Dictionary else {}


func _store_execution_runtime_state(case_fixture: Dictionary, runtime_state: Dictionary) -> void:
	var encoded := EXECUTION_SAVE_CODEC.encode_save_state(runtime_state)
	if bool(encoded.get("ok", false)) and encoded.get("value") is Dictionary:
		(case_fixture.get("all_states") as Dictionary)["card_resolution_execution"] = \
			(encoded.get("value") as Dictionary).duplicate(true)


func _resign_forged_post_effect_owner(all_states: Dictionary, binding: Dictionary) -> void:
	var infrastructure := all_states.get("region_infrastructure") as Dictionary
	var lifecycles := infrastructure.get("facility_action_lifecycles") as Dictionary
	var transaction_id := _facility_transaction_id(binding)
	var lifecycle := lifecycles.get(transaction_id) as Dictionary
	var owner_binding := (lifecycle.get("owner_binding") as Dictionary).duplicate(true)
	owner_binding["owner_player_index"] = 7
	owner_binding["intent_fingerprint"] = _owner_binding_fingerprint({
		"transaction_id": transaction_id,
		"region_id": str(owner_binding.get("region_id", "")),
		"owner_kind": "player",
		"owner_player_index": 7,
		"facility_type": str(owner_binding.get("facility_type", "")),
		"industry_id": str(owner_binding.get("industry_id", "")),
		"rank": int(binding.get("rank", 0)),
		"occurred_at": float(int(binding.get("submitted_at_world_time", 0))) / 1000.0,
	})
	var owner_fingerprint := _owner_binding_fingerprint(owner_binding)
	lifecycle["owner_binding"] = owner_binding
	lifecycle["owner_binding_fingerprint"] = owner_fingerprint
	lifecycle["intent_fingerprint"] = str(owner_binding.get("intent_fingerprint", ""))
	for receipt_id in ["original_receipt", "terminal_receipt"]:
		var receipt := (lifecycle.get(receipt_id) as Dictionary).duplicate(true)
		receipt["owner_player_index"] = 7
		receipt["owner_binding"] = owner_binding.duplicate(true)
		receipt["owner_binding_fingerprint"] = owner_fingerprint
		if receipt.has("intent_fingerprint"):
			receipt["intent_fingerprint"] = str(owner_binding.get("intent_fingerprint", ""))
		lifecycle[receipt_id] = receipt
	lifecycles[transaction_id] = lifecycle


func _facility_transaction_id(binding: Dictionary) -> String:
	return "facility-resolution.%d.%s" % [
		int(binding.get("resolution_id", 0)),
		str(binding.get("binding_fingerprint", "")).substr(0, 16),
	]


func _owner_binding_fingerprint(value: Variant) -> String:
	return str(hash(JSON.stringify(_canonicalize(value))))


func _fixture() -> Dictionary:
	var catalog: Resource = load(CATALOG_PATH)
	_expect(catalog != null and bool(catalog.call("reload").get("valid", false)), "facility restore catalog loads")
	if catalog == null:
		return {}
	var catalog_card: Dictionary = catalog.call("card_snapshot", CARD_ID)
	var card := catalog_card.duplicate(true)
	card["runtime_instance_id"] = "instance:facility:restore:1"
	var world := WorldSessionState.new()
	root.add_child(world)
	world.players = [{
		"id": 0,
		"actor_id": "player.0",
		"name": "Player",
		"seat_type": "human",
		"is_ai": false,
		"eliminated": false,
		"cash": 20,
		"cash_cents": 2000,
		"card_purchase_count": 0,
		"total_card_spend": 0,
		"slots": [card],
	}]
	var mana := MANA_SCRIPT.new() as PlayerManaRuntimeController
	root.add_child(mana)
	mana.configure(RULESET.debug_snapshot())
	var pools := {"0": {}}
	var remainders := {"0": {}}
	for asset_id in ASSET_IDS:
		(pools.get("0") as Dictionary)[asset_id] = 100000
		(remainders.get("0") as Dictionary)[asset_id] = 0
	_expect(bool(mana.apply_save_data({
		"state_version": 1,
		"ruleset_id": "v0.6",
		"current_game_time": 0.0,
		"revision": 1,
		"pools_by_player": pools,
		"recovery_remainders_by_player": remainders,
		"reservations": {},
		"terminal_receipts": {},
		"advance_once_journal": {},
		"advance_once_order": [],
	}).get("applied", false)), "facility restore mana fixture applies")
	var card_state := CARD_STATE_SCRIPT.new() as CardPlayerStateProductionAdapterV06
	root.add_child(card_state)
	card_state.configure(catalog, mana)
	card_state.set_world_session_state(world)

	var infrastructure := INFRASTRUCTURE_SCENE.instantiate() as RegionInfrastructureRuntimeController
	root.add_child(infrastructure)
	_expect(bool(infrastructure.configure(RULESET.debug_snapshot()).get("configured", false)), "facility restore infrastructure configures")
	_expect(bool(infrastructure.initialize_regions([{
		"region_id": REGION_ID,
		"terrain_id": "land",
		"neighbor_region_ids": [],
		"legacy_index": 0,
	}]).get("initialized", false)), "facility restore region initializes")
	var target := infrastructure.facility_target_binding_snapshot(REGION_ID, "factory", "life")
	_expect(not target.is_empty(), "facility restore target binding is authoritative")

	var queue := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	root.add_child(queue)
	queue.configure({"ruleset_id": "v0.6", "card_group": RULESET.card_group_rules()})
	var stable_target := _stable_target()
	_expect(bool(StableTarget.validate(stable_target).get("valid", false)), "facility restore stable target is valid")
	var machine := card.get("machine") as Dictionary
	var player_text := card.get("player") as Dictionary
	var payload := machine.get("effect_payload") as Dictionary
	var skill := {
		"name": str(player_text.get("name", CARD_ID)),
		"display_name": str(player_text.get("name", CARD_ID)),
		"kind": "public_facility",
		"rank": int(machine.get("rank", 1)),
		"persistent": false,
		"asset_cost": (machine.get("asset_cost") as Dictionary).duplicate(true),
		"display_seconds": 0,
	}
	var plan := queue.plan_submission({
		"player_index": 0,
		"slot_index": 0,
		"already_queued": false,
		"reactive_counter": false,
		"group_card_limit": 1,
		"play_cash_cost_cents": 0,
		"financial_margin_cents": 0,
		"financial_terms_version": "",
		"available_cash_cents": 0,
		"cash_revision": "0",
		"asset_cost": skill.get("asset_cost"),
		"skill": skill,
		"entry_context": {
			"selected_district": 0,
			"selected_trade_product": "",
			"selected_card_resolution_id": -1,
			"target_slot": -1,
			"target_monster_uid": -1,
			"target_player": -1,
			"play_requirement_district": -1,
			"queued_time": 0.0,
			"stable_target_envelope": stable_target,
		},
	}, {
		"player_count": 1,
		"counter_window_active": false,
		"batch_locked": false,
		"simultaneous_timer": 0.0,
		"lock_duration": 5.0,
		"public_bid_duration": 5.0,
		"window_sequence": 0,
		"reference_player": -1,
	})
	_expect(bool(plan.get("accepted", false)), "facility restore Queue plan accepts")
	if not bool(plan.get("accepted", false)):
		return {}
	var entry := (plan.get("entry") as Dictionary).duplicate(true)
	var resolution_id := int(entry.get("resolution_id", -1))
	var source_record_fingerprint := _fingerprint(catalog_card)
	var source_slot_fingerprint := _fingerprint(card)
	var escrow_id := "escrow.facility.restore"
	var request_id := "request.facility.restore"
	var intent_fingerprint := Wire.fingerprint({"request_id": request_id})
	var escrow_plan := card_state.plan_facility_card_escrow({
		"request_id": request_id,
		"intent_fingerprint": intent_fingerprint,
		"actor_id": "player.0",
		"actor_player_index": 0,
		"source_slot_index": 0,
		"hand_slot_id": "hand.slot.0",
		"card_semantic_id": CARD_ID,
		"runtime_instance_id": str(card.get("runtime_instance_id", "")),
		"source_record_fingerprint": source_record_fingerprint,
		"source_slot_fingerprint": source_slot_fingerprint,
		"escrow_id": escrow_id,
	})
	var escrow_commit := card_state.commit_facility_card_escrow(escrow_plan)
	_expect(bool(escrow_commit.get("committed", false)), "facility restore card enters escrow: %s / %s" % [JSON.stringify(escrow_plan), JSON.stringify(escrow_commit)])
	if not bool(escrow_commit.get("committed", false)):
		return {}
	var mana_plan := mana.plan_reservation({
		"transaction_id": "card-asset.1.%d" % resolution_id,
		"player_index": 0,
		"asset_cost": skill.get("asset_cost"),
		"generic_asset_allocation": {},
	})
	var mana_commit := mana.commit_reservation(mana_plan)
	_expect(bool(mana_commit.get("authorized", false)), "facility restore asset reservation commits")
	var reservation_required := bool(mana_plan.get("required", false))
	var reservation_id := str(mana_plan.get("transaction_id", "")) if reservation_required else ""
	var reservation_snapshot := mana.reservation_snapshot(reservation_id) if reservation_required else {}
	var game_state := _game_session_state()
	var binding := Binding.build({
		"schema_version": 1,
		"binding_kind_id": Binding.BINDING_KIND_ID,
		"resolution_id": resolution_id,
		"request_id": request_id,
		"intent_fingerprint": intent_fingerprint,
		"session_id": SESSION_ID,
		"session_revision": 1,
		"session_identity_fingerprint": Wire.fingerprint({
			"ruleset_id": game_state.get("ruleset_id"),
			"session_id": game_state.get("session_id"),
			"scenario_id": game_state.get("scenario_id"),
			"seed": str(game_state.get("seed")),
			"setup": game_state.get("setup"),
		}),
		"source_revision": 1,
		"actor_kind_id": "human",
		"actor_id": "player.0",
		"actor_player_index": 0,
		"card_instance_id": str(card.get("runtime_instance_id", "")),
		"runtime_instance_id": str(card.get("runtime_instance_id", "")),
		"card_semantic_id": CARD_ID,
		"hand_slot_id": "hand.slot.0",
		"source_slot_index": 0,
		"source_record_fingerprint": source_record_fingerprint,
		"source_slot_fingerprint": source_slot_fingerprint,
		"facility_kind_id": str(payload.get("facility_kind", "")),
		"industry_id": str(payload.get("industry_id", machine.get("industry_id", ""))),
		"rank": int(machine.get("rank", 1)),
		"prebound_target": target,
		"asset_reservation": {
			"schema_version": 1,
			"owner_id": "player_mana",
			"required": reservation_required,
			"reservation_id": reservation_id,
			"reservation_state_id": "reserved",
			"reservation_fingerprint": str(reservation_snapshot.get("fingerprint", "")) if reservation_required else Wire.fingerprint({"required": false, "player_index": 0}),
		},
		"card_escrow": {
			"schema_version": 1,
			"owner_id": "world_session_state",
			"escrow_id": escrow_id,
			"state_id": "committed_resolution_escrow",
			"escrow_fingerprint": str(escrow_commit.get("escrow_fingerprint", "")),
		},
		"submitted_at_world_time": 0,
		"queue_revision_at_commit": int(plan.get("expected_revision", 0)) + 1,
		"local_action_index": 0,
		"public_visibility": {
			"schema_version": 1,
			"owner_visibility_id": "anonymous",
			"card_visibility_id": "public",
			"target_visibility_id": "public",
		},
	})
	_expect(not binding.is_empty(), "facility restore binding seals: %s" % JSON.stringify(Binding.validation_report(binding)))
	if binding.is_empty():
		return {}
	entry["asset_reservation_id"] = reservation_id
	entry["asset_cost"] = (mana_plan.get("asset_cost") as Dictionary).duplicate(true)
	entry["asset_debit"] = (mana_plan.get("asset_debit") as Dictionary).duplicate(true)
	entry["asset_reservation_required"] = reservation_required
	entry["v06_facility_action"] = binding
	plan["entry"] = entry
	var queue_commit := queue.commit_submission(plan, {
		"authorized": true,
		"inventory_committed": true,
		"play_cost_authorized": true,
		"financial_margin_authorized": true,
		"asset_authorized": true,
	})
	_expect(bool(queue_commit.get("committed", false)), "facility restore Queue commit succeeds")
	var all_states := {
		"session": {
			"game_session_runtime": game_state,
			"world_session_state": {"players": world.players.duplicate(true)},
		},
		"player_mana": mana.to_save_data(),
		"region_infrastructure": infrastructure.to_save_data(),
		"card_resolution_execution": (EXECUTION_SAVE_CODEC.encode_save_state({
			"schema_version": 4,
			"execution_wire_version": 1,
			"ruleset_id": "v0.6",
			"transaction_sequence": 0,
			"completed_resolution_ids": [],
			"inflight_resolution_ids": [],
			"inflight_execution_transactions": [],
			"pending_settlements": [],
			"transition_controller": {},
		}).get("value", {}) as Dictionary).duplicate(true),
		"card_resolution_history": {"history": [], "appended_resolution_ids": []},
	}
	return {
		"queue": queue,
		"world": world,
		"mana": mana,
		"card_state": card_state,
		"infrastructure": infrastructure,
		"all_states": all_states,
	}


func _stable_target() -> Dictionary:
	var envelope := {
		"schema_version": 3,
		"session_id": SESSION_ID,
		"session_revision": 1,
		"selection_revision": 1,
		"region_id": REGION_ID,
		"region_public_index_at_capture": 0,
		"region_ordering_revision": "1".repeat(64),
		"region_ordering_fingerprint": "2".repeat(64),
		"product_id": "",
		"product_public_index_at_capture": -1,
		"product_ordering_revision": "3".repeat(64),
		"product_ordering_fingerprint": "4".repeat(64),
		"selected_card_resolution_id": -1,
		"target_kind": "none",
		"target_slot": -1,
		"target_monster_uid": -1,
		"target_player": -1,
		"play_requirement_region_id": "",
		"play_requirement_public_index_at_capture": -1,
		"capture_source": "facility_queue_test",
		"envelope_fingerprint": "",
	}
	envelope["envelope_fingerprint"] = JSON.stringify(_canonicalize(_without_field(envelope, "envelope_fingerprint"))).sha256_text()
	return envelope


func _game_session_state() -> Dictionary:
	return {
		"schema_version": 1,
		"ruleset_id": "v0.6",
		"session_state": "running",
		"session_id": SESSION_ID,
		"scenario_id": "scenario.alpha04c",
		"seed": 9_007_199_254_740_992,
		"setup": {"player_count": 1},
		"outcome_receipt": {},
		"world_effective_us": 0,
	}


func _candidate_player(all_states: Dictionary) -> Dictionary:
	return (((all_states.get("session") as Dictionary).get("world_session_state") as Dictionary).get("players") as Array)[0] as Dictionary


func _first_escrow(player: Dictionary) -> Dictionary:
	var escrows := player.get("facility_card_escrows") as Dictionary
	return escrows.get(escrows.keys()[0]) as Dictionary


func _binding(queue_state: Dictionary) -> Dictionary:
	return (((queue_state.get("current_queue") as Array)[0] as Dictionary).get("v06_facility_action") as Dictionary)


func _reservation_snapshot(record: Dictionary) -> Dictionary:
	var snapshot := {
		"schema_version": 1,
		"transaction_id": record.get("transaction_id"),
		"player_index": record.get("player_index"),
		"asset_cost": (record.get("asset_cost") as Dictionary).duplicate(true),
		"asset_debit": (record.get("asset_debit") as Dictionary).duplicate(true),
		"debit_milliunits": (record.get("debit_milliunits") as Dictionary).duplicate(true),
		"state": record.get("state"),
		"fingerprint": "",
	}
	snapshot["fingerprint"] = Wire.fingerprint(snapshot, "fingerprint")
	return snapshot


func _preflight_without_mutation(queue: CardResolutionQueueRuntimeService, state: Dictionary, all_states: Dictionary) -> Dictionary:
	var queue_before := queue.capture_runtime_checkpoint()
	var state_before := state.duplicate(true)
	var all_before := all_states.duplicate(true)
	var result := queue.preflight_restore_dependencies(state, all_states)
	_expect(queue.capture_runtime_checkpoint() == queue_before and state == state_before and all_states == all_before, "facility dependency preflight has zero owner/input mutation")
	return result


func _test_public_snapshot_restore_privacy(
	queue: CardResolutionQueueRuntimeService,
	state: Dictionary,
	all_states: Dictionary
) -> void:
	var public_before := queue.public_snapshot()
	_assert_public_snapshot_schema(public_before, "before restore")
	_assert_public_snapshot_privacy(public_before, state, all_states, "before restore")

	var restored := QUEUE_SCENE.instantiate() as CardResolutionQueueRuntimeService
	root.add_child(restored)
	restored.configure({"ruleset_id": "v0.6", "card_group": RULESET.card_group_rules()})
	var restore_receipt := restored.apply_save_data(state.duplicate(true))
	_expect(
		bool(restore_receipt.get("applied", false)),
		"fresh Queue owner restores the exact facility save state: %s" % JSON.stringify(restore_receipt)
	)
	var public_after := restored.public_snapshot()
	_assert_public_snapshot_schema(public_after, "after restore")
	_assert_public_snapshot_privacy(public_after, state, all_states, "after restore")
	_expect(
		public_after == public_before,
		"facility Queue public snapshot is byte-shape equivalent before and after restore"
	)
	restored.queue_free()


func _assert_public_snapshot_schema(snapshot: Dictionary, phase: String) -> void:
	_expect(
		_sorted_string_keys(snapshot) == PUBLIC_SNAPSHOT_KEYS,
		"facility Queue public snapshot uses exact root keys %s: %s" % [phase, JSON.stringify(snapshot.keys())]
	)
	var entries: Array = []
	for lane_id in ["current", "next"]:
		var lane_variant: Variant = snapshot.get(lane_id, [])
		_expect(lane_variant is Array, "facility Queue public %s lane is an Array %s" % [lane_id, phase])
		if lane_variant is Array:
			entries.append_array(lane_variant as Array)
	var active_variant: Variant = snapshot.get("active", {})
	_expect(active_variant is Dictionary, "facility Queue public active lane is a Dictionary %s" % phase)
	if active_variant is Dictionary and not (active_variant as Dictionary).is_empty():
		entries.append(active_variant)
	for entry_variant in entries:
		_expect(
			entry_variant is Dictionary \
				and _sorted_string_keys(entry_variant as Dictionary) == PUBLIC_ENTRY_KEYS,
			"facility Queue public entry uses exact keys %s: %s" % [
				phase,
				JSON.stringify((entry_variant as Dictionary).keys()) if entry_variant is Dictionary else "not_dictionary",
			]
		)


func _assert_public_snapshot_privacy(
	snapshot: Dictionary,
	state: Dictionary,
	all_states: Dictionary,
	phase: String
) -> void:
	var private_key_hits := _forbidden_public_key_paths(snapshot)
	_expect(
		private_key_hits.is_empty(),
		"facility Queue public snapshot excludes actor/player/seat/color/instance/slot/reservation/escrow/fingerprint keys %s: %s" % [phase, JSON.stringify(private_key_hits)]
	)
	var public_text := JSON.stringify(snapshot)
	var sentinels := _private_value_sentinels(state, all_states)
	for sentinel_id_variant in sentinels.keys():
		var sentinel_id := str(sentinel_id_variant)
		var sentinel_value := str(sentinels.get(sentinel_id, ""))
		_expect(
			not sentinel_value.is_empty() and not public_text.contains(sentinel_value),
			"facility Queue public snapshot excludes %s sentinel %s" % [sentinel_id, phase]
		)


func _forbidden_public_key_paths(value: Variant, path: String = "root") -> Array[String]:
	var result: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var lowered := key.to_lower()
			for sentinel_variant in PRIVATE_PUBLIC_KEY_SENTINELS:
				if lowered.contains(str(sentinel_variant)):
					result.append("%s.%s" % [path, key])
					break
			result.append_array(_forbidden_public_key_paths(
				(value as Dictionary).get(key_variant),
				"%s.%s" % [path, key]
			))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_forbidden_public_key_paths(
				(value as Array)[index],
				"%s[%d]" % [path, index]
			))
	return result


func _private_value_sentinels(state: Dictionary, all_states: Dictionary) -> Dictionary:
	var binding := _binding(state)
	var reservation := binding.get("asset_reservation", {}) as Dictionary
	var escrow := binding.get("card_escrow", {}) as Dictionary
	var player := _candidate_player(all_states)
	var sentinels := {
		"actor": str(binding.get("actor_id", "")),
		"player": str(player.get("name", "")),
		"seat": str(binding.get("actor_kind_id", "")),
		"color": str(binding.get("industry_id", "")),
		"runtime_instance": str(binding.get("runtime_instance_id", "")),
		"slot": str(binding.get("hand_slot_id", "")),
		"reservation": str(reservation.get("reservation_id", "")),
		"escrow": str(escrow.get("escrow_id", "")),
		"fingerprint": str(binding.get("binding_fingerprint", "")),
	}
	return sentinels


func _sorted_string_keys(value: Dictionary) -> Array:
	var result: Array = []
	for key_variant in value.keys():
		result.append(str(key_variant))
	result.sort()
	return result


func _expect_rejected(queue: CardResolutionQueueRuntimeService, state: Dictionary, all_states: Dictionary, message: String) -> void:
	var result := _preflight_without_mutation(queue, state, all_states)
	_expect(not bool(result.get("accepted", true)) and not str(result.get("reason_code", "")).is_empty(), message)


func _without_field(source: Dictionary, field_id: String) -> Dictionary:
	var result := source.duplicate(true)
	result.erase(field_id)
	return result


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_canonicalize(value)).sha256_text().to_lower()


func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left) < str(right))
		var result: Dictionary = {}
		for key_variant in keys:
			result[str(key_variant)] = _canonicalize((value as Dictionary).get(key_variant))
		return result
	if value is Array:
		var result: Array = []
		for item_variant in value as Array:
			result.append(_canonicalize(item_variant))
		return result
	return value


func _free_fixture(fixture: Dictionary) -> void:
	for key in ["queue", "infrastructure", "card_state", "mana", "world"]:
		var node := fixture.get(key) as Node
		if node != null:
			node.queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	var passed := _failures.is_empty()
	print("FACILITY_CARD_QUEUE_RESTORE_DEPENDENCY_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if passed else "FAIL", _checks, _failures.size()])
	if not passed:
		push_error("Facility restore dependency failures: %s" % JSON.stringify(_failures))
	quit(0 if passed else 1)
