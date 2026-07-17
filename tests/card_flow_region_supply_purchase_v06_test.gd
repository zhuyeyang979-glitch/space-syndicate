extends SceneTree

const CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const INVENTORY_SCENE := preload("res://scenes/runtime/CommodityCardInventoryRuntimeController.tscn")
const STATE_PORT_SCRIPT := preload("res://scripts/cards/v06/card_player_state_port_v06.gd")
const QUOTE_AUTHORITY_SCRIPT := preload("res://scripts/tools/card_market_quote_authority_fixture.gd")

const REGION_ID := "region.alpha"
const DISTRICT_INDEX := 0
const ACTOR_ID := "player.0"
const CARD_ID := "facility.road.rank_1"
const NEXT_CARD_ID := "facility.seaport.rank_1"
const OTHER_CARD_ID := "facility.orbital_warehouse.rank_1"

var _checks := 0
var _failures: Array[String] = []


class StatePortNode:
	extends Node

	var inner: Object = STATE_PORT_SCRIPT.new()
	var actor_ids: Array[String] = []
	var fail_commit := false
	var commit_calls := 0

	func register_fixture(actor_id: String, state: Dictionary) -> Dictionary:
		var result: Dictionary = inner.call("register_player", actor_id, state)
		if bool(result.get("configured", false)) and not actor_ids.has(actor_id):
			actor_ids.append(actor_id)
		return result

	func actor_player_indices() -> Dictionary:
		return inner.call("actor_player_indices") as Dictionary

	func register_player(actor_id: String, initial_state: Dictionary) -> Dictionary:
		return register_fixture(actor_id, initial_state)

	func read_player(actor_id: String) -> Dictionary:
		return inner.call("read_player", actor_id) as Dictionary

	func reserve_transaction(
		transaction_id: String,
		intent_hash: String,
		expected_revisions: Dictionary,
		actors: Array
	) -> Dictionary:
		return inner.call(
			"reserve_transaction",
			transaction_id,
			intent_hash,
			expected_revisions,
			actors
		) as Dictionary

	func prepare_reserved_mutations(
		_reservation_id: String,
		_next_states: Dictionary
	) -> Dictionary:
		return {"prepared": true, "reason_code": "prepared"}

	func commit_reserved(
		reservation_id: String,
		next_states: Dictionary,
		effect_receipt: Dictionary
	) -> Dictionary:
		commit_calls += 1
		if fail_commit:
			return {"committed": false, "reason_code": "player_revision_changed"}
		return inner.call(
			"commit_reserved",
			reservation_id,
			next_states,
			effect_receipt
		) as Dictionary

	func abort_reserved(
		reservation_id: String,
		reason_code := "reservation_aborted"
	) -> Dictionary:
		return inner.call("abort_reserved", reservation_id, reason_code) as Dictionary

	func replay_result(transaction_id: String, intent_hash: String) -> Dictionary:
		return inner.call("replay_result", transaction_id, intent_hash) as Dictionary

	func bind_world(_world: Node) -> void:
		pass

	func reset_state() -> void:
		inner = STATE_PORT_SCRIPT.new()
		actor_ids.clear()
		commit_calls = 0

	func to_save_data() -> Dictionary:
		var players: Dictionary = {}
		for actor_id in actor_ids:
			var read: Dictionary = inner.call("read_player", actor_id)
			if bool(read.get("found", false)):
				players[actor_id] = (read.get("player_state", {}) as Dictionary).duplicate(true)
		return {"players": players}

	func apply_save_data(data: Dictionary) -> Dictionary:
		var players: Dictionary = data.get("players", {}) \
			if data.get("players", {}) is Dictionary else {}
		var replacement: Object = STATE_PORT_SCRIPT.new()
		var replacement_actor_ids: Array[String] = []
		var keys: Array = players.keys()
		keys.sort()
		for actor_variant in keys:
			var actor_id := str(actor_variant)
			var state: Dictionary = players.get(actor_variant, {}) \
				if players.get(actor_variant, {}) is Dictionary else {}
			var registered: Dictionary = replacement.call("register_player", actor_id, state)
			if not bool(registered.get("configured", false)):
				return {"applied": false, "reason_code": "state_restore_failed"}
			replacement_actor_ids.append(actor_id)
		inner = replacement
		actor_ids = replacement_actor_ids
		return {"applied": true, "reason_code": "state_restored"}

	func debug_snapshot() -> Dictionary:
		return {
			"actor_count": actor_ids.size(),
			"commit_calls": commit_calls,
			"stores_inventory": true,
		}


class FlowFixture:
	extends Node

	func install_commodity(_request: Dictionary) -> Dictionary:
		return {}

	func finalize_commodity_installation(_receipt: Dictionary) -> Dictionary:
		return {}

	func rollback_commodity_installation(_transaction_id: String) -> Dictionary:
		return {}

	func card_effect_candidates_snapshot() -> Dictionary:
		return {"valid": true, "candidates": []}

	func prepare_card_effect_batch(_request: Dictionary) -> Dictionary:
		return {}

	func commit_card_effect_batch(_request: Dictionary) -> Dictionary:
		return {}

	func rollback_card_effect_batch(_request: Dictionary) -> Dictionary:
		return {}

	func finalize_card_effect_batch(_request: Dictionary) -> Dictionary:
		return {}


class InfrastructureFixture:
	extends Node

	func facilities_snapshot(_public_only := true) -> Array:
		return []

	func region_snapshot(_region_id: String) -> Dictionary:
		return {}


class RegionSupplyFixture:
	extends RefCounted

	var slots: Array = []
	var pending: Dictionary = {}
	var terminal: Dictionary = {}
	var prepare_calls := 0
	var commit_calls := 0
	var rollback_calls := 0
	var finalize_calls := 0
	var fail_commit := false
	var fail_rollback := false
	var finalize_failures_remaining := 0

	func _init() -> void:
		slots = [
			_listing("item-road", CARD_ID, 0, "region:alpha:slot:0:1", 7),
			_listing("item-warehouse", OTHER_CARD_ID, 1, "region:alpha:slot:1:1", 9),
		]

	func public_rack_snapshot(region_id := "") -> Dictionary:
		if not region_id.is_empty() and region_id != REGION_ID:
			return {"available": false, "regions": []}
		return {
			"available": true,
			"reason_code": "region_supply_public_snapshot",
			"regions": [{
				"region_id": REGION_ID,
				"region_index": DISTRICT_INDEX,
				"rack_revision": "rack-fixture",
				"slots": slots.duplicate(true),
			}],
		}

	func prepare_slot_refill(
		region_id: String,
		slot_index: int,
		expected_item_id: String,
		expected_supply_revision: String,
		transaction_id: String
	) -> Dictionary:
		prepare_calls += 1
		if pending.has(transaction_id):
			return _receipt(pending[transaction_id] as Dictionary, true)
		if terminal.has(transaction_id):
			return (terminal[transaction_id] as Dictionary).duplicate(true)
		if region_id != REGION_ID or slot_index < 0 or slot_index >= slots.size():
			return {"prepared": false, "reason_code": "region_supply_slot_invalid"}
		var current: Dictionary = slots[slot_index] as Dictionary
		if str(current.get("item_id", "")) != expected_item_id \
				or str(current.get("supply_revision", "")) != expected_supply_revision:
			return {"prepared": false, "reason_code": "region_supply_listing_changed"}
		var row := {
			"stage": "prepared",
			"transaction_id": transaction_id,
			"region_id": region_id,
			"slot_index": slot_index,
			"expected_item_id": expected_item_id,
			"expected_supply_revision": expected_supply_revision,
			"pre_listing": current.duplicate(true),
			"post_listing": _listing(
				"item-seaport-%s" % transaction_id,
				NEXT_CARD_ID,
				slot_index,
				"region:alpha:slot:%d:2" % slot_index,
				8
			),
		}
		pending[transaction_id] = row
		return _receipt(row, false)

	func commit_slot_refill(transaction_id: String) -> Dictionary:
		commit_calls += 1
		if fail_commit:
			return {
				"committed": false,
				"reason_code": "simulated_region_supply_commit_failure",
			}
		if terminal.has(transaction_id):
			return (terminal[transaction_id] as Dictionary).duplicate(true)
		if not pending.has(transaction_id):
			return {"committed": false, "reason_code": "region_supply_transaction_missing"}
		var row: Dictionary = (pending[transaction_id] as Dictionary).duplicate(true)
		if str(row.get("stage", "")) == "prepared":
			slots[int(row.get("slot_index", -1))] = (row.get("post_listing", {}) as Dictionary).duplicate(true)
			row["stage"] = "committed"
			pending[transaction_id] = row
		return _receipt(row, false)

	func rollback_slot_refill(transaction_id: String) -> Dictionary:
		rollback_calls += 1
		if fail_rollback:
			return {
				"rolled_back": false,
				"reason_code": "simulated_region_supply_rollback_failure",
			}
		if terminal.has(transaction_id):
			return (terminal[transaction_id] as Dictionary).duplicate(true)
		if not pending.has(transaction_id):
			return {"rolled_back": false, "reason_code": "region_supply_transaction_missing"}
		var row: Dictionary = (pending[transaction_id] as Dictionary).duplicate(true)
		if str(row.get("stage", "")) == "committed":
			slots[int(row.get("slot_index", -1))] = (row.get("pre_listing", {}) as Dictionary).duplicate(true)
		row["stage"] = "rolled_back"
		var result := _receipt(row, false)
		terminal[transaction_id] = result.duplicate(true)
		pending.erase(transaction_id)
		return result

	func finalize_slot_refill(transaction_id: String) -> Dictionary:
		finalize_calls += 1
		if finalize_failures_remaining > 0:
			finalize_failures_remaining -= 1
			return {
				"finalized": false,
				"reason_code": "simulated_region_supply_finalize_failure",
			}
		if terminal.has(transaction_id):
			return (terminal[transaction_id] as Dictionary).duplicate(true)
		if not pending.has(transaction_id):
			return {"finalized": false, "reason_code": "region_supply_transaction_missing"}
		var row: Dictionary = (pending[transaction_id] as Dictionary).duplicate(true)
		if str(row.get("stage", "")) != "committed":
			return {"finalized": false, "reason_code": "region_supply_finalize_requires_commit"}
		row["stage"] = "finalized"
		var result := _receipt(row, false)
		terminal[transaction_id] = result.duplicate(true)
		pending.erase(transaction_id)
		return result

	func to_save_data() -> Dictionary:
		return {
			"slots": slots.duplicate(true),
			"pending": pending.duplicate(true),
			"terminal": terminal.duplicate(true),
		}

	func apply_save_data(data: Dictionary) -> Dictionary:
		slots = (data.get("slots", []) as Array).duplicate(true) \
			if data.get("slots", []) is Array else []
		pending = (data.get("pending", {}) as Dictionary).duplicate(true) \
			if data.get("pending", {}) is Dictionary else {}
		terminal = (data.get("terminal", {}) as Dictionary).duplicate(true) \
			if data.get("terminal", {}) is Dictionary else {}
		return {"applied": true}

	func _listing(
		item_id: String,
		card_id: String,
		slot_index: int,
		supply_revision: String,
		price_cash: int
	) -> Dictionary:
		return {
			"item_id": item_id,
			"card_id": card_id,
			"card": {"display_name": card_id},
			"source_region_id": REGION_ID,
			"source_district_index": DISTRICT_INDEX,
			"slot_index": slot_index,
			"price_cash": price_cash,
			"supply_revision": supply_revision,
		}

	func _receipt(row: Dictionary, replayed: bool) -> Dictionary:
		var stage := str(row.get("stage", ""))
		return {
			"prepared": stage == "prepared",
			"committed": stage in ["committed", "finalized"],
			"rolled_back": stage == "rolled_back",
			"finalized": stage == "finalized",
			"stage": stage,
			"reason_code": "region_supply_%s" % stage,
			"transaction_id": str(row.get("transaction_id", "")),
			"intent_fingerprint": "%s|%d|%s|%s" % [
				str(row.get("region_id", "")),
				int(row.get("slot_index", -1)),
				str(row.get("expected_item_id", "")),
				str(row.get("expected_supply_revision", "")),
			],
			"region_id": str(row.get("region_id", "")),
			"slot_index": int(row.get("slot_index", -1)),
			"source_item_id": str(row.get("expected_item_id", "")),
			"next_listing": (row.get("post_listing", {}) as Dictionary).duplicate(true),
			"replayed": replayed,
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(CATALOG_PATH) as CardRuntimeCatalogV06Resource
	_expect(catalog != null and bool(catalog.reload().get("valid", false)), "catalog is ready")
	if catalog == null:
		_finish()
		return
	await _verify_success_selected_slot_and_replay(catalog)
	await _verify_binding_failures_are_zero_effect(catalog)
	await _verify_state_commit_rollback_and_recovery(catalog)
	await _verify_finalize_retry_and_save_restore(catalog)
	await _verify_full_hand_discard_atomicity(catalog)
	_finish()


func _verify_success_selected_slot_and_replay(catalog: Resource) -> void:
	var setup := await _setup_controller(catalog)
	var controller: Node = setup.controller
	var state: StatePortNode = setup.state
	var source: RegionSupplyFixture = setup.source
	var quote_authority: Object = setup.quote_authority
	var before_other := JSON.stringify(source.slots[1])
	var quote := _bound_quote(quote_authority, source.slots[0] as Dictionary, 7)
	var result := _purchase(controller, source.slots[0] as Dictionary, 0, "tx-region-success", quote)
	_expect(bool(result.get("committed", false)), "region supply purchase commits")
	_expect(int(_player(controller).get("cash", -1)) == 93 and _card_count(_player(controller)) == 1, "cash debit and received card commit atomically")
	_expect(str((source.slots[0] as Dictionary).get("card_id", "")) == NEXT_CARD_ID, "selected slot is refilled")
	_expect(JSON.stringify(source.slots[1]) == before_other, "unselected slot is unchanged")
	_expect(source.prepare_calls == 1 and source.commit_calls == 1 and source.finalize_calls == 1, "source lifecycle runs prepare commit finalize once")
	var replay := _purchase(controller, {
		"item_id": "item-road",
		"card_id": CARD_ID,
		"source_region_id": REGION_ID,
		"source_district_index": DISTRICT_INDEX,
		"slot_index": 0,
		"supply_revision": "region:alpha:slot:0:1",
	}, 0, "tx-region-success", quote)
	_expect(bool(replay.get("committed", false)) and bool(replay.get("idempotent_replay", false)), "same purchase replays idempotently")
	_expect(int(_player(controller).get("cash", -1)) == 93 and _card_count(_player(controller)) == 1, "replay does not charge or receive twice")
	_expect(source.prepare_calls == 1 and source.commit_calls == 1 and source.finalize_calls == 1, "replay does not repeat a finalized source lifecycle")
	var collision := controller.call(
		"purchase_region_supply_card",
		ACTOR_ID,
		REGION_ID,
		1,
		"item-warehouse",
		OTHER_CARD_ID,
		0,
		"region:alpha:slot:1:1",
		"tx-region-success",
		_bound_quote(quote_authority, source.slots[1] as Dictionary, 9)
	) as Dictionary
	_expect(str(collision.get("reason_code", "")) == "transaction_intent_collision", "transaction id collision is rejected")
	var public_receipt: Dictionary = result.get("public_receipt", {}) \
		if result.get("public_receipt", {}) is Dictionary else {}
	var public_text := JSON.stringify(public_receipt)
	_expect(not public_text.contains("quote") and not JSON.stringify(result).contains("987654"), "public receipt leaks no quote secret or rival cash")
	_expect(not public_text.contains(CARD_ID) and not public_text.contains("price_cash") and not public_text.contains("actor"), "public receipt keeps the purchased card, buyer, and price private")
	await _cleanup_controller(controller, state)


func _verify_binding_failures_are_zero_effect(catalog: Resource) -> void:
	var setup := await _setup_controller(catalog)
	var controller: Node = setup.controller
	var state: StatePortNode = setup.state
	var source: RegionSupplyFixture = setup.source
	var quote_authority: Object = setup.quote_authority
	var listing: Dictionary = source.slots[0] as Dictionary
	var quote := _bound_quote(quote_authority, listing, 7)
	var before_state := JSON.stringify(_player(controller))
	var before_source := JSON.stringify(source.to_save_data())
	var cases := [
		["wrong-actor", "player.unknown", REGION_ID, 0, "item-road", CARD_ID, 0, "region:alpha:slot:0:1", quote],
		["wrong-region", ACTOR_ID, "region.other", 0, "item-road", CARD_ID, 0, "region:alpha:slot:0:1", quote],
		["wrong-slot", ACTOR_ID, REGION_ID, 1, "item-road", CARD_ID, 0, "region:alpha:slot:0:1", quote],
		["wrong-item", ACTOR_ID, REGION_ID, 0, "item-forged", CARD_ID, 0, "region:alpha:slot:0:1", quote],
		["wrong-card", ACTOR_ID, REGION_ID, 0, "item-road", OTHER_CARD_ID, 0, "region:alpha:slot:0:1", quote],
		["wrong-player-revision", ACTOR_ID, REGION_ID, 0, "item-road", CARD_ID, 9, "region:alpha:slot:0:1", quote],
		["wrong-supply-revision", ACTOR_ID, REGION_ID, 0, "item-road", CARD_ID, 0, "region:alpha:slot:0:999", quote],
	]
	for case_variant in cases:
		var case: Array = case_variant
		var result := controller.call(
			"purchase_region_supply_card",
			str(case[1]),
			str(case[2]),
			int(case[3]),
			str(case[4]),
			str(case[5]),
			int(case[6]),
			str(case[7]),
			"tx-bind-%s" % str(case[0]),
			(case[8] as Dictionary).duplicate(true)
		) as Dictionary
		_expect(not bool(result.get("committed", true)), "%s binding fails closed" % str(case[0]))
		_expect(JSON.stringify(_player(controller)) == before_state and JSON.stringify(source.to_save_data()) == before_source, "%s binding has zero side effects" % str(case[0]))
	var forged_quote := quote.duplicate(true)
	forged_quote["slot_index"] = 1
	var quote_failure := _purchase(controller, listing, 0, "tx-bind-quote", forged_quote)
	_expect(str(quote_failure.get("reason_code", "")) == "region_supply_quote_binding_mismatch", "quote region-slot binding is required")
	_expect(JSON.stringify(_player(controller)) == before_state and JSON.stringify(source.to_save_data()) == before_source, "forged quote has zero side effects")
	await _cleanup_controller(controller, state)


func _verify_state_commit_rollback_and_recovery(catalog: Resource) -> void:
	var rollback_setup := await _setup_controller(catalog)
	var rollback_controller: Node = rollback_setup.controller
	var rollback_state: StatePortNode = rollback_setup.state
	var rollback_source: RegionSupplyFixture = rollback_setup.source
	var rollback_quote := _bound_quote(rollback_setup.quote_authority, rollback_source.slots[0] as Dictionary, 7)
	rollback_state.fail_commit = true
	var before_player := JSON.stringify(_player(rollback_controller))
	var before_source := JSON.stringify(rollback_source.slots)
	var failed := _purchase(rollback_controller, rollback_source.slots[0] as Dictionary, 0, "tx-state-fail", rollback_quote)
	_expect(str(failed.get("reason_code", "")) == "player_state_commit_failed" and bool(failed.get("rolled_back", false)), "player state failure rolls the source back")
	_expect(JSON.stringify(_player(rollback_controller)) == before_player and JSON.stringify(rollback_source.slots) == before_source, "successful compensation restores player and source")
	_expect(rollback_source.commit_calls == 1 and rollback_source.rollback_calls == 1, "source commit is compensated exactly once")
	await _cleanup_controller(rollback_controller, rollback_state)

	var recovery_setup := await _setup_controller(catalog)
	var recovery_controller: Node = recovery_setup.controller
	var recovery_state: StatePortNode = recovery_setup.state
	var recovery_source: RegionSupplyFixture = recovery_setup.source
	var recovery_quote := _bound_quote(recovery_setup.quote_authority, recovery_source.slots[0] as Dictionary, 7)
	recovery_state.fail_commit = true
	recovery_source.fail_rollback = true
	var recovery_player_before := JSON.stringify(_player(recovery_controller))
	var recovery := _purchase(recovery_controller, recovery_source.slots[0] as Dictionary, 0, "tx-rollback-fail", recovery_quote)
	_expect(str(recovery.get("reason_code", "")) == "region_supply_compensation_failed" and bool(recovery.get("recovery_required", false)), "rollback failure is an explicit recovery state")
	_expect(not bool(recovery.get("rolled_back", true)) and bool(recovery.get("compensation_failed", false)), "rollback failure never pretends success")
	_expect(JSON.stringify(_player(recovery_controller)) == recovery_player_before and str((recovery_source.slots[0] as Dictionary).get("card_id", "")) == NEXT_CARD_ID, "player stays unchanged while the honest source divergence remains visible")
	_expect(not bool((recovery_controller.call("checkpoint_status") as Dictionary).get("can_checkpoint", true)), "compensation failure blocks checkpoint")
	await _cleanup_controller(recovery_controller, recovery_state)


func _verify_finalize_retry_and_save_restore(catalog: Resource) -> void:
	var retry_setup := await _setup_controller(catalog)
	var retry_controller: Node = retry_setup.controller
	var retry_state: StatePortNode = retry_setup.state
	var retry_source: RegionSupplyFixture = retry_setup.source
	var retry_quote := _bound_quote(retry_setup.quote_authority, retry_source.slots[0] as Dictionary, 7)
	retry_source.finalize_failures_remaining = 1
	var first := _purchase(retry_controller, retry_source.slots[0] as Dictionary, 0, "tx-finalize-retry", retry_quote)
	_expect(bool(first.get("committed", false)) and bool(first.get("recovery_required", false)), "finalize failure preserves the committed purchase as pending")
	var pending_checkpoint: Dictionary = retry_controller.call("checkpoint_status")
	_expect(not bool(pending_checkpoint.get("can_checkpoint", true)) and str(pending_checkpoint.get("reason_code", "")) == "region_supply_purchase_finalization_pending", "pending source finalization has a distinct checkpoint reason")
	var first_player := JSON.stringify(_player(retry_controller))
	var replay := _purchase(retry_controller, {
		"item_id": "item-road",
		"card_id": CARD_ID,
		"source_region_id": REGION_ID,
		"source_district_index": DISTRICT_INDEX,
		"slot_index": 0,
		"supply_revision": "region:alpha:slot:0:1",
	}, 0, "tx-finalize-retry", retry_quote)
	_expect(bool(replay.get("idempotent_replay", false)) and bool((replay.get("region_supply_finalization", {}) as Dictionary).get("finalized", false)), "same transaction retries only finalization")
	_expect(JSON.stringify(_player(retry_controller)) == first_player and retry_source.commit_calls == 1 and retry_source.finalize_calls == 2, "finalization replay never repeats charge, receive, or source commit")
	_expect(bool((retry_controller.call("checkpoint_status") as Dictionary).get("can_checkpoint", false)), "successful retry reopens checkpoint")
	await _cleanup_controller(retry_controller, retry_state)

	var save_setup := await _setup_controller(catalog)
	var save_controller: Node = save_setup.controller
	var save_state: StatePortNode = save_setup.state
	var save_source: RegionSupplyFixture = save_setup.source
	var save_quote := _bound_quote(save_setup.quote_authority, save_source.slots[0] as Dictionary, 7)
	save_source.finalize_failures_remaining = 5
	var pending := _purchase(save_controller, save_source.slots[0] as Dictionary, 0, "tx-save-pending", save_quote)
	_expect(bool(pending.get("committed", false)) and bool(pending.get("recovery_required", false)), "save fixture reaches committed pending finalization")
	var controller_save: Dictionary = save_controller.call("to_save_data")
	var source_save := save_source.to_save_data()
	var expected_player := JSON.stringify(_player(save_controller))
	await _cleanup_controller(save_controller, save_state)

	var restored_setup := await _setup_controller(catalog, false)
	var restored_controller: Node = restored_setup.controller
	var restored_state: StatePortNode = restored_setup.state
	var restored_source: RegionSupplyFixture = restored_setup.source
	restored_source.apply_save_data(source_save)
	restored_source.finalize_failures_remaining = 0
	var applied: Dictionary = restored_controller.call("apply_save_data", controller_save)
	_expect(bool(applied.get("applied", false)), "controller restores pending terminal operation and player state")
	var restored_replay := _purchase(restored_controller, {
		"item_id": "item-road",
		"card_id": CARD_ID,
		"source_region_id": REGION_ID,
		"source_district_index": DISTRICT_INDEX,
		"slot_index": 0,
		"supply_revision": "region:alpha:slot:0:1",
	}, 0, "tx-save-pending", save_quote)
	_expect(bool(restored_replay.get("idempotent_replay", false)) and bool((restored_replay.get("region_supply_finalization", {}) as Dictionary).get("finalized", false)), "save-loaded transaction resumes only source finalization")
	_expect(JSON.stringify(_player(restored_controller)) == expected_player and restored_source.commit_calls == 0 and restored_source.finalize_calls == 1, "save-load retry does not repeat player or source mutations")
	await _cleanup_controller(restored_controller, restored_state)


func _verify_full_hand_discard_atomicity(catalog: Resource) -> void:
	var full_hand := _distinct_full_hand(catalog)
	var required_setup := await _setup_controller(
		catalog,
		true,
		full_hand
	)
	var required_controller: Node = required_setup.controller
	var required_state: StatePortNode = required_setup.state
	var required_source: RegionSupplyFixture = required_setup.source
	var required_listing: Dictionary = required_source.slots[0] as Dictionary
	var required_quote := _bound_quote(
		required_setup.quote_authority,
		required_listing,
		7
	)
	var required_player_before := JSON.stringify(_player(required_controller))
	var required_source_before := JSON.stringify(required_source.to_save_data())
	var required := _purchase(
		required_controller,
		required_listing,
		0,
		"tx-discard-required",
		required_quote
	)
	if str(required.get("reason_code", "")) != "hand_full_discard_required":
		print("DISCARD_REQUIRED_DIAG|%s" % JSON.stringify(required))
	_expect(
		str(required.get("reason_code", "")) == "hand_full_discard_required",
		"full counted hand without a discard slot fails closed"
	)
	_expect(
		JSON.stringify(_player(required_controller)) == required_player_before
			and JSON.stringify(required_source.to_save_data())
				== required_source_before,
		"missing discard slot changes neither player nor RegionSupply"
	)
	await _cleanup_controller(required_controller, required_state)

	var success_setup := await _setup_controller(catalog, true, full_hand)
	var success_controller: Node = success_setup.controller
	var success_state: StatePortNode = success_setup.state
	var success_source: RegionSupplyFixture = success_setup.source
	var success_listing: Dictionary = success_source.slots[0] as Dictionary
	var success_quote := _bound_quote(
		success_setup.quote_authority,
		success_listing,
		7
	)
	var discarded_id := _slot_card_id(_player(success_controller), 2)
	var success := _purchase(
		success_controller,
		success_listing,
		0,
		"tx-discard-success",
		success_quote,
		2
	)
	if not bool(success.get("committed", false)):
		print("DISCARD_SUCCESS_DIAG|%s" % JSON.stringify(success))
	var success_player := _player(success_controller)
	var private_receipt: Dictionary = success.get("private_receipt", {}) \
		if success.get("private_receipt", {}) is Dictionary else {}
	_expect(
		bool(success.get("committed", false))
			and bool(private_receipt.get("discarded", false))
			and int(private_receipt.get("discard_slot", -1)) == 2,
		"legal private discard commits inside the RegionSupply purchase"
	)
	_expect(
		int(success_player.get("cash", -1)) == 93
			and _card_count(success_player) == 5
			and not _inventory_has_card(success_player, discarded_id)
			and _inventory_has_card(success_player, CARD_ID),
		"discard receive and cash debit form one player-state postimage"
	)
	var public_text := JSON.stringify(success.get("public_receipt", {}))
	_expect(
		not public_text.contains("discard")
			and not public_text.contains(CARD_ID)
			and not public_text.contains("hand")
			and not public_text.contains("cash")
			and not public_text.contains(ACTOR_ID),
		"public purchase receipt leaks no discard card hand cash or actor"
	)
	var replay := _purchase(
		success_controller,
		required_listing,
		0,
		"tx-discard-success",
		success_quote,
		2
	)
	_expect(
		bool(replay.get("committed", false))
			and bool(replay.get("idempotent_replay", false))
			and JSON.stringify(_player(success_controller))
				== JSON.stringify(success_player)
			and success_source.commit_calls == 1,
		"replay does not discard charge receive or refill twice"
	)
	var success_save: Dictionary = success_controller.call("to_save_data")
	var success_source_save := success_source.to_save_data()
	await _cleanup_controller(success_controller, success_state)
	var restored_setup := await _setup_controller(catalog, false)
	var restored_controller: Node = restored_setup.controller
	var restored_state: StatePortNode = restored_setup.state
	var restored_source: RegionSupplyFixture = restored_setup.source
	restored_source.apply_save_data(success_source_save)
	var restored_apply: Dictionary = restored_controller.call(
		"apply_save_data",
		success_save
	)
	var restored_replay := _purchase(
		restored_controller,
		required_listing,
		0,
		"tx-discard-success",
		success_quote,
		2
	)
	_expect(
		bool(restored_apply.get("applied", false))
			and bool(restored_replay.get("idempotent_replay", false))
			and JSON.stringify(_player(restored_controller))
				== JSON.stringify(success_player)
			and restored_source.commit_calls == 0,
		"save-loaded replay does not repeat the private discard or source commit"
	)
	await _cleanup_controller(restored_controller, restored_state)

	var invalid_setup := await _setup_controller(catalog, true, full_hand)
	var invalid_controller: Node = invalid_setup.controller
	var invalid_state: StatePortNode = invalid_setup.state
	var invalid_source: RegionSupplyFixture = invalid_setup.source
	var invalid_listing: Dictionary = invalid_source.slots[0] as Dictionary
	var invalid_quote := _bound_quote(
		invalid_setup.quote_authority,
		invalid_listing,
		7
	)
	var invalid_before := JSON.stringify(_player(invalid_controller))
	var invalid_source_before := JSON.stringify(invalid_source.to_save_data())
	var invalid := _purchase(
		invalid_controller,
		invalid_listing,
		0,
		"tx-discard-invalid",
		invalid_quote,
		99
	)
	if str(invalid.get("reason_code", "")) != "discard_slot_invalid":
		print("DISCARD_INVALID_DIAG|%s" % JSON.stringify(invalid))
	_expect(
		str(invalid.get("reason_code", "")) == "discard_slot_invalid"
			and JSON.stringify(_player(invalid_controller)) == invalid_before
			and JSON.stringify(invalid_source.to_save_data())
				== invalid_source_before,
		"invalid discard slot has zero player and source side effects"
	)
	await _cleanup_controller(invalid_controller, invalid_state)

	var merge_hand := _distinct_full_hand(catalog)
	merge_hand[0] = catalog.call("card_snapshot", CARD_ID) as Dictionary
	var merge_setup := await _setup_controller(catalog, true, merge_hand)
	var merge_controller: Node = merge_setup.controller
	var merge_state: StatePortNode = merge_setup.state
	var merge_source: RegionSupplyFixture = merge_setup.source
	var merge_listing: Dictionary = merge_source.slots[0] as Dictionary
	var merge_quote := _bound_quote(
		merge_setup.quote_authority,
		merge_listing,
		7
	)
	var protected_discard_id := _slot_card_id(_player(merge_controller), 3)
	var merged := _purchase(
		merge_controller,
		merge_listing,
		0,
		"tx-merge-before-discard",
		merge_quote,
		3
	)
	if not bool(merged.get("committed", false)):
		print("DISCARD_MERGE_DIAG|%s" % JSON.stringify(merged))
	var merged_player := _player(merge_controller)
	var merged_private: Dictionary = merged.get("private_receipt", {}) \
		if merged.get("private_receipt", {}) is Dictionary else {}
	_expect(
		bool(merged.get("committed", false))
			and not bool(merged_private.get("discarded", true))
			and _inventory_has_card(merged_player, "facility.road.rank_2")
			and _inventory_has_card(merged_player, protected_discard_id),
		"same-rank merge takes priority and ignores the supplied discard slot"
	)
	await _cleanup_controller(merge_controller, merge_state)

	var expiry_setup := await _setup_controller(catalog, true, full_hand)
	var expiry_controller: Node = expiry_setup.controller
	var expiry_state: StatePortNode = expiry_setup.state
	var expiry_source: RegionSupplyFixture = expiry_setup.source
	var expiry_listing: Dictionary = expiry_source.slots[0] as Dictionary
	var expiry_quote := _bound_quote(
		expiry_setup.quote_authority,
		expiry_listing,
		7
	)
	expiry_setup.quote_authority.now_world_us = 6_000_000
	var expiry_before := JSON.stringify(_player(expiry_controller))
	var expired := _purchase(
		expiry_controller,
		expiry_listing,
		0,
		"tx-discard-expired",
		expiry_quote,
		2
	)
	if str(expired.get("reason_code", "")) != "market_quote_unauthorized":
		print("DISCARD_EXPIRED_DIAG|%s" % JSON.stringify(expired))
	_expect(
		str(expired.get("reason_code", "")) == "market_quote_unauthorized"
			and JSON.stringify(_player(expiry_controller)) == expiry_before
			and expiry_source.commit_calls == 0,
		"expired quote never discards or commits the source"
	)
	await _cleanup_controller(expiry_controller, expiry_state)

	var source_fail_setup := await _setup_controller(
		catalog,
		true,
		full_hand
	)
	var source_fail_controller: Node = source_fail_setup.controller
	var source_fail_state: StatePortNode = source_fail_setup.state
	var source_fail_source: RegionSupplyFixture = source_fail_setup.source
	source_fail_source.fail_commit = true
	var source_fail_listing: Dictionary = source_fail_source.slots[0] as Dictionary
	var source_fail_quote := _bound_quote(
		source_fail_setup.quote_authority,
		source_fail_listing,
		7
	)
	var source_fail_before := JSON.stringify(_player(source_fail_controller))
	var source_failed := _purchase(
		source_fail_controller,
		source_fail_listing,
		0,
		"tx-discard-source-fail",
		source_fail_quote,
		2
	)
	_expect(
		not bool(source_failed.get("committed", true))
			and str(source_failed.get("reason_code", ""))
				== "simulated_region_supply_commit_failure"
			and JSON.stringify(_player(source_fail_controller))
				== source_fail_before
			and str((source_fail_source.slots[0] as Dictionary).get(
				"card_id",
				""
			)) == CARD_ID
			and source_fail_source.commit_calls == 1
			and source_fail_source.rollback_calls == 1,
		"source commit failure leaves the discard and player state untouched"
	)
	await _cleanup_controller(source_fail_controller, source_fail_state)

	var state_fail_setup := await _setup_controller(catalog, true, full_hand)
	var state_fail_controller: Node = state_fail_setup.controller
	var state_fail_state: StatePortNode = state_fail_setup.state
	var state_fail_source: RegionSupplyFixture = state_fail_setup.source
	state_fail_state.fail_commit = true
	var state_fail_listing: Dictionary = state_fail_source.slots[0] as Dictionary
	var state_fail_quote := _bound_quote(
		state_fail_setup.quote_authority,
		state_fail_listing,
		7
	)
	var state_fail_player_before := JSON.stringify(_player(state_fail_controller))
	var state_fail_source_before := JSON.stringify(state_fail_source.slots)
	var state_failed := _purchase(
		state_fail_controller,
		state_fail_listing,
		0,
		"tx-discard-state-fail",
		state_fail_quote,
		2
	)
	_expect(
		str(state_failed.get("reason_code", ""))
			== "player_state_commit_failed"
			and bool(state_failed.get("rolled_back", false))
			and JSON.stringify(_player(state_fail_controller))
				== state_fail_player_before
			and JSON.stringify(state_fail_source.slots)
				== state_fail_source_before
			and state_fail_source.pending.is_empty()
			and state_fail_source.commit_calls == 1
			and state_fail_source.rollback_calls == 1,
		"player commit failure restores the source without applying the discard"
	)
	await _cleanup_controller(state_fail_controller, state_fail_state)


func _setup_controller(
	catalog: Resource,
	register_players := true,
	initial_cards: Array = []
) -> Dictionary:
	var controller := INVENTORY_SCENE.instantiate() as CommodityCardInventoryRuntimeController
	root.add_child(controller)
	var state := StatePortNode.new()
	var flow := FlowFixture.new()
	var infrastructure := InfrastructureFixture.new()
	root.add_child(state)
	root.add_child(flow)
	root.add_child(infrastructure)
	var quote_authority := QUOTE_AUTHORITY_SCRIPT.new()
	var source := RegionSupplyFixture.new()
	controller.set_market_quote_authority(quote_authority)
	controller.set_region_supply_source_port(source)
	if register_players:
		state.register_fixture(ACTOR_ID, _state(100, 0, initial_cards))
		state.register_fixture("player.1", _state(987654, 1, [
			catalog.call("card_snapshot", OTHER_CARD_ID) as Dictionary,
		]))
	var configured: Dictionary = controller.configure(
		{"ruleset_id": "v0.6"},
		state,
		flow,
		infrastructure
	)
	_expect(bool(configured.get("configured", false)), "inventory controller configures")
	await process_frame
	return {
		"controller": controller,
		"state": state,
		"flow": flow,
		"infrastructure": infrastructure,
		"source": source,
		"quote_authority": quote_authority,
	}


func _bound_quote(authority: Object, listing: Dictionary, price_cash: int) -> Dictionary:
	var request: Dictionary = authority.call(
		"issue_quote",
		0,
		int(listing.get("source_district_index", -1)),
		str(listing.get("card_id", "")),
		str(listing.get("supply_revision", "")),
		price_cash
	)
	request["source_region_id"] = str(listing.get("source_region_id", ""))
	request["slot_index"] = int(listing.get("slot_index", -1))
	request["source_item_id"] = str(listing.get("item_id", ""))
	return request


func _purchase(
	controller: Node,
	listing: Dictionary,
	player_revision: int,
	transaction_id: String,
	quote_request: Dictionary,
	discard_slot: int = -1
) -> Dictionary:
	return controller.call(
		"purchase_region_supply_card",
		ACTOR_ID,
		str(listing.get("source_region_id", "")),
		int(listing.get("slot_index", -1)),
		str(listing.get("item_id", "")),
		str(listing.get("card_id", "")),
		player_revision,
		str(listing.get("supply_revision", "")),
		transaction_id,
		quote_request.duplicate(true),
		discard_slot
	) as Dictionary


func _state(cash: int, player_index: int, cards: Array) -> Dictionary:
	var normalized_cards: Array = []
	for slot_index in range(cards.size()):
		if not (cards[slot_index] is Dictionary):
			normalized_cards.append(cards[slot_index])
			continue
		var card: Dictionary = (cards[slot_index] as Dictionary).duplicate(true)
		if str(card.get("runtime_instance_id", "")).strip_edges().is_empty():
			var machine: Dictionary = card.get("machine", {}) \
				if card.get("machine", {}) is Dictionary else {}
			card["runtime_instance_id"] = "fixture:%d:%d:%s" % [
				player_index,
				slot_index,
				str(machine.get("card_id", "card")),
			]
		normalized_cards.append(card)
	return {
		"revision": 0,
		"cash": cash,
		"player_index": player_index,
		"assets": {
			"life": 0,
			"energy": 0,
			"industry": 0,
			"technology": 0,
			"commerce": 0,
			"shipping": 0,
		},
		"inventory": {"hand_limit": 5, "slots": normalized_cards},
	}


func _player(controller: Node) -> Dictionary:
	return controller.call("player_snapshot", ACTOR_ID) as Dictionary


func _card_count(player: Dictionary) -> int:
	var inventory: Dictionary = player.get("inventory", {}) \
		if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	var count := 0
	for slot_variant in slots:
		if slot_variant is Dictionary:
			count += 1
	return count


func _distinct_full_hand(catalog: Resource) -> Array:
	var result: Array = []
	for card_id in [
		"facility.factory.life.rank_1",
		"facility.market.life.rank_1",
		"facility.seaport.rank_1",
		"facility.spaceport.rank_1",
		"facility.orbital_warehouse.rank_1",
	]:
		result.append(catalog.call("card_snapshot", card_id) as Dictionary)
	return result


func _slot_card_id(player: Dictionary, slot_index: int) -> String:
	var inventory: Dictionary = player.get("inventory", {}) \
		if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) \
		if inventory.get("slots", []) is Array else []
	if slot_index < 0 \
			or slot_index >= slots.size() \
			or not (slots[slot_index] is Dictionary):
		return ""
	var machine: Dictionary = (slots[slot_index] as Dictionary).get(
		"machine",
		{}
	) if (slots[slot_index] as Dictionary).get("machine", {}) is Dictionary else {}
	return str(machine.get("card_id", ""))


func _inventory_has_card(player: Dictionary, card_id: String) -> bool:
	var inventory: Dictionary = player.get("inventory", {}) \
		if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) \
		if inventory.get("slots", []) is Array else []
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var machine: Dictionary = (slot_variant as Dictionary).get(
			"machine",
			{}
		) if (slot_variant as Dictionary).get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return true
	return false


func _cleanup_controller(controller: Node, state: Node) -> void:
	var parent_nodes: Array[Node] = []
	if is_instance_valid(controller):
		for sibling in [controller, state]:
			if is_instance_valid(sibling):
				parent_nodes.append(sibling)
	for node in parent_nodes:
		node.queue_free()
	await process_frame
	for child in root.get_children():
		if child is FlowFixture or child is InfrastructureFixture:
			child.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CARD_FLOW_REGION_SUPPLY_PURCHASE_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("CARD_FLOW_REGION_SUPPLY_PURCHASE_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(1)
