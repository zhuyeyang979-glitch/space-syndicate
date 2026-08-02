extends SceneTree

const CARD_INVENTORY_OWNER_SCENE := preload("res://scenes/runtime/CardInventorySaveOwner.tscn")
const DISTRICT_PURCHASE_SCENE := preload("res://scenes/runtime/DistrictPurchaseRuntimeController.tscn")

const SAVED_CURSOR := 8
const HIGH_SEQUENCE := 9
const HIGH_TRANSACTION_ID := "district-purchase:market-quote-1000000-9"
const MISSING_CURSOR_REASON := "allocator_cursor_missing_requires_backup"
const REGRESSED_CURSOR_REASON := "allocator_cursor_regressed"

var _checks := 0
var _failures: Array[String] = []
var _fixture_root: Node


class SaveChildFixture extends Node:
	var state: Dictionary


	func _init(initial_state: Dictionary) -> void:
		state = initial_state.duplicate(true)


	func checkpoint_status() -> Dictionary:
		return {"can_checkpoint": true, "reason_code": "fixture_checkpoint_ready"}


	func to_save_data() -> Dictionary:
		return state.duplicate(true)


	func preflight_save_data(data: Dictionary) -> Dictionary:
		return {
			"accepted": true,
			"reason_code": "fixture_save_valid",
			"normalized_state": data.duplicate(true),
		}


	func apply_save_data(data: Dictionary) -> Dictionary:
		state = data.duplicate(true)
		return {"applied": true, "reason_code": "fixture_save_applied"}


	func capture_runtime_checkpoint() -> Dictionary:
		return {"schema_version": 2, "state": state.duplicate(true)}


	func preflight_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		return {
			"accepted": int(checkpoint.get("schema_version", 0)) == 2 \
					and checkpoint.get("state") is Dictionary,
			"reason_code": "fixture_checkpoint_valid",
		}


	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		if not bool(preflight_runtime_checkpoint(checkpoint).get("accepted", false)):
			return {"restored": false, "reason_code": "fixture_checkpoint_invalid"}
		state = (checkpoint.get("state", {}) as Dictionary).duplicate(true)
		return {"restored": true, "applied": true, "reason_code": "fixture_checkpoint_restored"}


class QuoteAuthorityFixture extends Node:
	var next_quote_sequence := SAVED_CURSOR
	var quotes_by_id: Dictionary = {}


	func export_quote_for_session(quote_id: String) -> Dictionary:
		return (quotes_by_id.get(quote_id, {}) as Dictionary).duplicate(true) \
				if quotes_by_id.get(quote_id, {}) is Dictionary else {}


	func export_quote_for_pending_session(quote_id: String) -> Dictionary:
		return export_quote_for_session(quote_id)


	func preflight_quote_from_session(snapshot: Dictionary) -> Dictionary:
		return {
			"accepted": not str(snapshot.get("quote_id", "")).is_empty(),
			"reason_code": "quote_snapshot_valid",
			"normalized_state": snapshot.duplicate(true),
		}


	func restore_quote_from_session(snapshot: Dictionary) -> Dictionary:
		quotes_by_id[str(snapshot.get("quote_id", ""))] = snapshot.duplicate(true)
		return {"restored": true, "reason": "quote_restored", "quote": snapshot.duplicate(true)}


	func restore_pending_quote_from_session(snapshot: Dictionary) -> Dictionary:
		return restore_quote_from_session(snapshot)


	func quote_snapshot(quote_id: String) -> Dictionary:
		return export_quote_for_session(quote_id)


	func capture_allocator_cursor() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence}


	func restore_allocator_cursor(cursor: Dictionary) -> Dictionary:
		if int(cursor.get("schema_version", 0)) != 1 \
				or not (cursor.get("next_quote_sequence") is int) \
				or int(cursor.get("next_quote_sequence", 0)) < 1:
			return {"restored": false, "reason_code": "allocator_cursor_invalid"}
		next_quote_sequence = int(cursor.get("next_quote_sequence", 0))
		return {"restored": true, "reason_code": "allocator_cursor_restored"}


	func reset_state() -> void:
		next_quote_sequence = 1
		quotes_by_id.clear()


	func capture_runtime_checkpoint() -> Dictionary:
		return {
			"schema_version": 1,
			"next_quote_sequence": next_quote_sequence,
			"quotes_by_id": quotes_by_id.duplicate(true),
		}


	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		if int(checkpoint.get("schema_version", 0)) != 1 \
				or not (checkpoint.get("next_quote_sequence") is int) \
				or not (checkpoint.get("quotes_by_id") is Dictionary):
			return {"applied": false, "reason_code": "quote_checkpoint_invalid"}
		next_quote_sequence = int(checkpoint.get("next_quote_sequence", 1))
		quotes_by_id = (checkpoint.get("quotes_by_id", {}) as Dictionary).duplicate(true)
		return {"restored": true, "applied": true, "reason_code": "quote_checkpoint_restored"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := _fixture()
	var owner := fixture.get("owner") as CardInventorySaveOwner
	var purchase := fixture.get("purchase") as DistrictPurchaseRuntimeController
	var quote_authority := fixture.get("quote_authority") as QuoteAuthorityFixture
	var save := owner.to_save_data()
	_expect(not save.is_empty() and int(save.get("schema_version", 0)) == 4, "card-inventory outer Save captures strict v4")
	_expect(_saved_cursor(save) == SAVED_CURSOR, "card-inventory v4 captures the exact quote cursor")

	_test_card_inventory_journal_high_water(owner, save)
	_test_region_supply_cross_section_high_water(owner, save)
	_test_v2_requires_backup(owner, purchase, save)
	_test_repeated_apply_and_rollback(owner, quote_authority, save)

	_fixture_root.queue_free()
	await process_frame
	_finish()


func _test_card_inventory_journal_high_water(owner: CardInventorySaveOwner, save: Dictionary) -> void:
	for journal_kind in ["transaction_journal", "terminal_operations", "state_port_journal"]:
		var candidate := _save_with_journal_transaction(save, journal_kind)
		var preflight := owner.preflight_save_data(candidate)
		_expect(
			not bool(preflight.get("accepted", true))
					and str(preflight.get("reason_code", "")) == REGRESSED_CURSOR_REASON,
			"card-inventory rejects %s key above next_quote_sequence" % journal_kind
		)


func _test_region_supply_cross_section_high_water(owner: CardInventorySaveOwner, save: Dictionary) -> void:
	for journal_kind in ["pending_transactions", "terminal_transactions"]:
		var dependencies := _dependency_state()
		var region_supply := dependencies.get("region_supply", {}) as Dictionary
		var journal := region_supply.get(journal_kind, {}) as Dictionary
		journal[HIGH_TRANSACTION_ID] = {"transaction_id": HIGH_TRANSACTION_ID}
		region_supply[journal_kind] = journal
		dependencies["region_supply"] = region_supply
		var preflight := owner.preflight_restore_dependencies(save, dependencies)
		_expect(
			not bool(preflight.get("accepted", true))
					and str(preflight.get("reason_code", "")) == REGRESSED_CURSOR_REASON
					and str(preflight.get("failing_dependency", "")) == "region_supply",
			"card-inventory rejects Region Supply %s above next_quote_sequence" % journal_kind
		)


func _test_v2_requires_backup(
	owner: CardInventorySaveOwner,
	purchase: DistrictPurchaseRuntimeController,
	save: Dictionary
) -> void:
	var legacy_district := (save.get("district_purchase", {}) as Dictionary).duplicate(true)
	var legacy_payload := (legacy_district.get("district_purchase_runtime", {}) as Dictionary).duplicate(true)
	legacy_payload["schema_version"] = 2
	legacy_payload.erase("next_quote_sequence")
	legacy_district["district_purchase_runtime"] = legacy_payload
	var child_preflight := purchase.preflight_save_data(legacy_district)
	_expect(
		not bool(child_preflight.get("accepted", true))
				and str(child_preflight.get("reason_code", "")) == MISSING_CURSOR_REASON
				and bool(child_preflight.get("requires_backup", false)),
		"district-purchase v2 fails closed with requires_backup"
	)

	var legacy_outer := save.duplicate(true)
	legacy_outer["schema_version"] = 2
	legacy_outer["district_purchase"] = legacy_district
	var owner_preflight := owner.preflight_save_data(legacy_outer)
	_expect(
		not bool(owner_preflight.get("accepted", true))
				and str(owner_preflight.get("reason_code", "")) == MISSING_CURSOR_REASON
				and bool(owner_preflight.get("requires_backup", false)),
		"card-inventory outer v2 propagates allocator requires_backup"
	)


func _test_repeated_apply_and_rollback(
	owner: CardInventorySaveOwner,
	quote_authority: QuoteAuthorityFixture,
	save: Dictionary
) -> void:
	quote_authority.next_quote_sequence = 17
	var first_apply := owner.apply_save_data(save)
	var second_apply := owner.apply_save_data(save)
	_expect(
		bool(first_apply.get("applied", false)) and bool(second_apply.get("applied", false))
				and quote_authority.next_quote_sequence == SAVED_CURSOR,
		"repeated card-inventory v4 apply restores without advancing the quote cursor"
	)
	_expect(owner.to_save_data() == save, "repeated card-inventory v4 apply exact-recaptures")

	quote_authority.next_quote_sequence = 23
	var before_fault := owner.to_save_data()
	owner.arm_test_fault_once("district_purchase_after")
	var failed_apply := owner.apply_save_data(save)
	var after_fault := owner.to_save_data()
	_expect(
		not bool(failed_apply.get("applied", true))
				and bool(failed_apply.get("rollback_attempted", false))
				and bool(failed_apply.get("rollback_complete", false)),
		"district_purchase_after fault triggers composite rollback"
	)
	_expect(
		quote_authority.next_quote_sequence == 23 and after_fault == before_fault,
		"district_purchase_after rollback restores the exact pre-apply cursor and child state"
	)


func _fixture() -> Dictionary:
	_fixture_root = Node.new()
	_fixture_root.name = "Alpha04CAllocatorContractClosureFixture"
	root.add_child(_fixture_root)

	var quote_authority := QuoteAuthorityFixture.new()
	quote_authority.name = "QuoteAuthorityFixture"
	_fixture_root.add_child(quote_authority)
	var purchase := DISTRICT_PURCHASE_SCENE.instantiate() as DistrictPurchaseRuntimeController
	purchase.name = "DistrictPurchaseRuntimeController"
	_fixture_root.add_child(purchase)
	purchase.set_quote_authority(quote_authority)
	purchase.configure()

	var commodity := SaveChildFixture.new({
		"transaction_journal": {},
		"terminal_operations": {},
		"state_port": {"journal": {}},
	})
	commodity.name = "CommodityFixture"
	_fixture_root.add_child(commodity)
	var product_market := SaveChildFixture.new({"schema_version": 1, "market_revision": 0})
	product_market.name = "ProductMarketFixture"
	_fixture_root.add_child(product_market)
	var owner := CARD_INVENTORY_OWNER_SCENE.instantiate() as CardInventorySaveOwner
	owner.name = "CardInventorySaveOwner"
	_fixture_root.add_child(owner)
	owner.configure_dependencies(commodity, product_market, purchase)
	return {
		"owner": owner,
		"purchase": purchase,
		"quote_authority": quote_authority,
	}


func _save_with_journal_transaction(save: Dictionary, journal_kind: String) -> Dictionary:
	var candidate := save.duplicate(true)
	var commodity := (candidate.get("commodity_card_inventory", {}) as Dictionary).duplicate(true)
	var record := {"intent_hash": "allocator-closure-intent", "result": {}}
	match journal_kind:
		"transaction_journal":
			var journal := (commodity.get("transaction_journal", {}) as Dictionary).duplicate(true)
			journal[HIGH_TRANSACTION_ID] = record.duplicate(true)
			commodity["transaction_journal"] = journal
		"terminal_operations":
			var journal := (commodity.get("transaction_journal", {}) as Dictionary).duplicate(true)
			var terminal := (commodity.get("terminal_operations", {}) as Dictionary).duplicate(true)
			journal[HIGH_TRANSACTION_ID] = record.duplicate(true)
			terminal[HIGH_TRANSACTION_ID] = record.duplicate(true)
			commodity["transaction_journal"] = journal
			commodity["terminal_operations"] = terminal
		"state_port_journal":
			var state_port := (commodity.get("state_port", {}) as Dictionary).duplicate(true)
			var journal := (state_port.get("journal", {}) as Dictionary).duplicate(true)
			journal[HIGH_TRANSACTION_ID] = record.duplicate(true)
			state_port["journal"] = journal
			commodity["state_port"] = state_port
	candidate["commodity_card_inventory"] = commodity
	return candidate


func _dependency_state() -> Dictionary:
	return {
		"session": {"world_session_state": {"players": []}},
		"region_supply": {
			"pending_transactions": {},
			"terminal_transactions": {},
		},
	}


func _saved_cursor(save: Dictionary) -> int:
	var district := save.get("district_purchase", {}) as Dictionary
	var payload := district.get("district_purchase_runtime", {}) as Dictionary
	return int(payload.get("next_quote_sequence", -1))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("ALPHA04C ALLOCATOR CONTRACT CLOSURE: %s" % message)


func _finish() -> void:
	print("ALPHA04C_ALLOCATOR_CONTRACT_CLOSURE_EVIDENCE|%s" % JSON.stringify({
		"saved_next_quote_sequence": SAVED_CURSOR,
		"rejected_high_sequence": HIGH_SEQUENCE,
		"rejected_transaction_id": HIGH_TRANSACTION_ID,
		"reason_code": REGRESSED_CURSOR_REASON,
		"dictionary_key_paths": [
			"card_inventory.commodity_card_inventory.transaction_journal",
			"card_inventory.commodity_card_inventory.terminal_operations",
			"card_inventory.commodity_card_inventory.state_port.journal",
			"region_supply.pending_transactions",
			"region_supply.terminal_transactions",
		],
	}, "", true))
	print("ALPHA04C_ALLOCATOR_CONTRACT_CLOSURE_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
