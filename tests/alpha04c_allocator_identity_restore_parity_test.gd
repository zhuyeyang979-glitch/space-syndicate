extends SceneTree

const PRICING_SCENE := preload("res://scenes/runtime/CardMarketPricingRuntimeController.tscn")
const PURCHASE_SCENE := preload("res://scenes/runtime/DistrictPurchaseRuntimeController.tscn")
const REGION_SUPPLY_SCRIPT := preload("res://scripts/runtime/region_supply_runtime_controller.gd")

const INITIAL_WORLD_US := 1_000_000
const DISTRICT_INDEX := 2
const REGION_ID := "region.alpha"

var _checks := 0
var _failures: Array[String] = []
var _fixture_roots: Array[Node] = []
var _evidence: Dictionary = {}


class ClockFixture extends Node:
	var current_us := INITIAL_WORLD_US


	func world_effective_micros() -> int:
		return current_us


class SolarFixture extends Node:
	func availability(
		_now_us: int,
		_source_center_x: float,
		_world_width: float,
		_source_destroyed: bool
	) -> Dictionary:
		return {
			"viewable": true,
			"purchasable": true,
			"availability_kind": "sunlit",
		}


class WorldBridgeFixture extends Node:
	func capture_market_facts(source_district_index: int) -> Dictionary:
		return {
			"source_district_index": source_district_index,
			"source_center_x": 10.0,
			"world_width": 100.0,
			"source_destroyed": false,
			"direct_neighbors": [],
			"monsters": [],
		}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_quote_and_purchase_transaction_parity()
	_test_listing_identity_parity()
	for fixture_root in _fixture_roots:
		if is_instance_valid(fixture_root):
			fixture_root.queue_free()
	await process_frame
	_finish()


func _test_quote_and_purchase_transaction_parity() -> void:
	var source := _market_fixture()
	var retained_quote := _open_quote(
		source,
		0,
		"card.qa.pending-retained",
		"revision-pending-retained",
		true
	)
	var omitted_quote := _open_quote(
		source,
		1,
		"card.qa.expired-omitted",
		"revision-expired-omitted"
	)
	var save_world_us := int(retained_quote.get("expires_at_world_us", -1))
	_clock(source).current_us = save_world_us
	var save := _purchase(source).to_save_data()
	var saved_quote_ids := _saved_quote_ids(save)
	var saved_cursor := _saved_quote_cursor(save)
	var retained_quote_id := str(retained_quote.get("quote_id", ""))
	var omitted_quote_id := str(omitted_quote.get("quote_id", ""))

	_expect(
		not retained_quote_id.is_empty() and not omitted_quote_id.is_empty(),
		"real pricing authority allocates distinct retained and omitted quote IDs"
	)
	_expect(
		saved_quote_ids == [retained_quote_id] and not saved_quote_ids.has(omitted_quote_id),
		"expired ordinary quote payload is omitted while expired pending quote remains retained"
	)
	_expect(saved_cursor == 3, "Save persists next_quote_sequence=3 after two consumed quote IDs")

	var future_request := _listing_request(
		2,
		"card.qa.after-restore",
		"revision-after-restore"
	)
	var uninterrupted_quote := _pricing(source).quote_listing(future_request)
	var restored := _market_fixture(save_world_us)
	var applied := _purchase(restored).apply_save_data(save)
	var recaptured_after_apply := _purchase(restored).to_save_data()
	var restored_cursor_after_apply := _saved_quote_cursor(recaptured_after_apply)
	var restored_quote := _pricing(restored).quote_listing(future_request)
	var restored_cursor_after_next_quote := _saved_quote_cursor(_purchase(restored).to_save_data())
	var uninterrupted_quote_id := str(uninterrupted_quote.get("quote_id", ""))
	var restored_quote_id := str(restored_quote.get("quote_id", ""))
	var uninterrupted_transaction_id := "district-purchase:%s" % uninterrupted_quote_id
	var restored_transaction_id := "district-purchase:%s" % restored_quote_id

	_expect(bool(applied.get("applied", false)), "cursor-bearing district-purchase state restores")
	_expect(
		recaptured_after_apply == save and restored_cursor_after_apply == saved_cursor,
		"restore exact-recaptures before any post-restore allocation"
	)
	_expect(
		not uninterrupted_quote_id.is_empty()
				and restored_quote_id == uninterrupted_quote_id
				and str(restored_quote.get("quote_fingerprint", ""))
						== str(uninterrupted_quote.get("quote_fingerprint", "")),
		"next quote ID and fingerprint match across uninterrupted and restored forks"
	)
	_expect(
		_quote_sequence(restored_quote_id) == saved_cursor,
		"first post-restore quote consumes the exact persisted cursor"
	)
	_expect(
		restored_cursor_after_next_quote == saved_cursor + 1,
		"one post-restore quote allocation advances the persisted cursor exactly once"
	)
	_expect(
		restored_quote_id != omitted_quote_id and uninterrupted_quote_id != omitted_quote_id,
		"omitted expired quote ID is never reused"
	)
	_expect(
		restored_transaction_id == uninterrupted_transaction_id
				and restored_transaction_id == "district-purchase:%s" % restored_quote_id,
		"district-purchase transaction identity remains the exact quote-derived identity"
	)

	_evidence["quote"] = {
		"saved_next_quote_sequence": saved_cursor,
		"restored_cursor_after_apply": restored_cursor_after_apply,
		"restored_cursor_after_next_quote": restored_cursor_after_next_quote,
		"retained_quote_id": retained_quote_id,
		"omitted_expired_quote_id": omitted_quote_id,
		"saved_quote_ids": saved_quote_ids,
		"uninterrupted_next_quote_id": uninterrupted_quote_id,
		"restored_next_quote_id": restored_quote_id,
		"next_quote_fingerprint": str(restored_quote.get("quote_fingerprint", "")),
		"reused_expired_id_count": 0 if restored_quote_id != omitted_quote_id else 1,
	}
	_evidence["district_purchase_transaction"] = {
		"derivation": "district-purchase:<quote_id>",
		"uninterrupted_transaction_id": uninterrupted_transaction_id,
		"restored_transaction_id": restored_transaction_id,
	}


func _test_listing_identity_parity() -> void:
	var source: RegionSupplyRuntimeController = REGION_SUPPLY_SCRIPT.new()
	root.add_child(source)
	_fixture_roots.append(source)
	var configured := source.configure(900626424, _regions(), _cards(), 3)
	_expect(bool(configured.get("configured", false)), "Region Supply source configures")
	var seed_refill := _advance_slot(source, 0, "allocator-parity-before-save")
	_expect(seed_refill, "Region Supply consumes one pre-Save listing identity")
	var save := source.to_save_data()
	var saved_refill_sequence := int(save.get("refill_sequence", -1))

	var restored: RegionSupplyRuntimeController = REGION_SUPPLY_SCRIPT.new()
	root.add_child(restored)
	_fixture_roots.append(restored)
	var applied := restored.apply_save_data(save)
	_expect(bool(applied.get("applied", false)), "Region Supply applies the cursor-bearing Save")
	_expect(
		_fingerprint(source.to_save_data()) == _fingerprint(restored.to_save_data()),
		"Region Supply restore starts from the exact listing/RNG/cursor state"
	)

	var source_listing := _slot(source, 1)
	var restored_listing := _slot(restored, 1)
	var transaction_id := "allocator-parity-after-restore"
	var source_plan := source.prepare_slot_refill(
		REGION_ID,
		1,
		str(source_listing.get("item_id", "")),
		str(source_listing.get("supply_revision", "")),
		transaction_id
	)
	var restored_plan := restored.prepare_slot_refill(
		REGION_ID,
		1,
		str(restored_listing.get("item_id", "")),
		str(restored_listing.get("supply_revision", "")),
		transaction_id
	)
	var source_next := source_plan.get("next_listing", {}) as Dictionary
	var restored_next := restored_plan.get("next_listing", {}) as Dictionary
	var source_item_id := str(source_next.get("item_id", ""))
	var restored_item_id := str(restored_next.get("item_id", ""))
	var source_revision := str(source_next.get("supply_revision", ""))
	var restored_revision := str(restored_next.get("supply_revision", ""))

	_expect(
		bool(source_plan.get("prepared", false)) and bool(restored_plan.get("prepared", false)),
		"both forks prepare the same next Region Supply refill"
	)
	_expect(
		not source_item_id.is_empty()
				and restored_item_id == source_item_id
				and restored_revision == source_revision
				and str(restored_next.get("card_id", "")) == str(source_next.get("card_id", ""))
				and _fingerprint(restored_next) == _fingerprint(source_next),
		"next listing item ID, supply revision, card, and payload match after restore"
	)
	_expect(
		_listing_sequence(restored_item_id) == saved_refill_sequence + 1,
		"first post-restore listing consumes refill_sequence+1 exactly"
	)

	var source_commit := source.commit_slot_refill(transaction_id)
	var restored_commit := restored.commit_slot_refill(transaction_id)
	var source_finalize := source.finalize_slot_refill(transaction_id)
	var restored_finalize := restored.finalize_slot_refill(transaction_id)
	_expect(
		bool(source_commit.get("committed", false))
				and bool(restored_commit.get("committed", false))
				and bool(source_finalize.get("finalized", false))
				and bool(restored_finalize.get("finalized", false)),
		"both listing forks commit and finalize exactly once"
	)
	_expect(
		_fingerprint(source.to_save_data()) == _fingerprint(restored.to_save_data()),
		"post-refill Region Supply states remain identical"
	)

	_evidence["listing"] = {
		"saved_refill_sequence": saved_refill_sequence,
		"uninterrupted_next_item_id": source_item_id,
		"restored_next_item_id": restored_item_id,
		"uninterrupted_next_supply_revision": source_revision,
		"restored_next_supply_revision": restored_revision,
		"next_listing_sequence": _listing_sequence(restored_item_id),
		"post_refill_sequence": int(restored.to_save_data().get("refill_sequence", -1)),
	}


func _market_fixture(world_us: int = INITIAL_WORLD_US) -> Dictionary:
	var fixture_root := Node.new()
	fixture_root.name = "AllocatorIdentityMarketFixture"
	root.add_child(fixture_root)
	_fixture_roots.append(fixture_root)

	var clock := ClockFixture.new()
	clock.name = "ClockFixture"
	clock.current_us = world_us
	fixture_root.add_child(clock)
	var solar := SolarFixture.new()
	solar.name = "SolarFixture"
	fixture_root.add_child(solar)
	var world_bridge := WorldBridgeFixture.new()
	world_bridge.name = "WorldBridgeFixture"
	fixture_root.add_child(world_bridge)

	var pricing := PRICING_SCENE.instantiate() as CardMarketPricingRuntimeController
	fixture_root.add_child(pricing)
	pricing.set_dependencies(clock, solar, world_bridge)
	pricing.configure()
	var purchase := PURCHASE_SCENE.instantiate() as DistrictPurchaseRuntimeController
	fixture_root.add_child(purchase)
	purchase.set_quote_authority(pricing)
	purchase.configure()
	return {
		"clock": clock,
		"pricing": pricing,
		"purchase": purchase,
	}


func _open_quote(
	fixture: Dictionary,
	player_index: int,
	card_id: String,
	revision: String,
	pending_discard: bool = false
) -> Dictionary:
	var purchase := _purchase(fixture)
	var opened := purchase.open_window(player_index, DISTRICT_INDEX, {"supply_revision": revision})
	var selected := purchase.acknowledge_card_selection(
		player_index,
		DISTRICT_INDEX,
		card_id,
		revision
	)
	var quote := _pricing(fixture).quote_listing(
		_listing_request(player_index, card_id, revision)
	)
	var attached := purchase.attach_quote(player_index, DISTRICT_INDEX, quote)
	var reserved: Dictionary = {}
	if pending_discard:
		reserved = purchase.reserve_pending_discard({
			"player_index": player_index,
			"district_index": DISTRICT_INDEX,
			"card_id": card_id,
			"quote_id": str(quote.get("quote_id", "")),
			"price": int(quote.get("final_price", -1)),
		})
	_expect(
		bool(opened.get("active", false))
				and not selected.is_empty()
				and not quote.is_empty()
				and not attached.is_empty()
				and (not pending_discard or not reserved.is_empty()),
		"fixture creates a real bound quote for player %d" % player_index
	)
	return quote


func _listing_request(player_index: int, card_id: String, revision: String) -> Dictionary:
	return {
		"player_index": player_index,
		"district_index": DISTRICT_INDEX,
		"card_id": card_id,
		"supply_revision": revision,
		"base_price": 101,
	}


func _saved_quote_ids(save: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var payload := save.get("district_purchase_runtime", {}) as Dictionary
	for session_variant in payload.get("sessions", []) as Array:
		if not (session_variant is Dictionary):
			continue
		var quote_variant: Variant = (session_variant as Dictionary).get("active_quote", {})
		if quote_variant is Dictionary and not (quote_variant as Dictionary).is_empty():
			ids.append(str((quote_variant as Dictionary).get("quote_id", "")))
	return ids


func _saved_quote_cursor(save: Dictionary) -> int:
	var payload := save.get("district_purchase_runtime", {}) as Dictionary
	return int(payload.get("next_quote_sequence", -1))


func _quote_sequence(quote_id: String) -> int:
	var separator := quote_id.rfind("-")
	if separator < 0 or separator + 1 >= quote_id.length():
		return -1
	var sequence_text := quote_id.substr(separator + 1)
	return int(sequence_text) if sequence_text.is_valid_int() else -1


func _advance_slot(
	controller: RegionSupplyRuntimeController,
	slot_index: int,
	transaction_id: String
) -> bool:
	var listing := _slot(controller, slot_index)
	var prepared := controller.prepare_slot_refill(
		REGION_ID,
		slot_index,
		str(listing.get("item_id", "")),
		str(listing.get("supply_revision", "")),
		transaction_id
	)
	var committed := controller.commit_slot_refill(transaction_id)
	var finalized := controller.finalize_slot_refill(transaction_id)
	return bool(prepared.get("prepared", false)) \
			and bool(committed.get("committed", false)) \
			and bool(finalized.get("finalized", false))


func _slot(controller: RegionSupplyRuntimeController, slot_index: int) -> Dictionary:
	var snapshot := controller.public_rack_snapshot(REGION_ID)
	var regions: Array = snapshot.get("regions", [])
	if regions.is_empty():
		return {}
	var slots: Array = (regions[0] as Dictionary).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _listing_sequence(item_id: String) -> int:
	var prefix := "region-supply:%s:" % REGION_ID
	if not item_id.begins_with(prefix):
		return -1
	var parts := item_id.split(":", false)
	return int(parts[3]) if parts.size() >= 5 and str(parts[3]).is_valid_int() else -1


func _regions() -> Array:
	return [
		{
			"region_id": REGION_ID,
			"region_index": 0,
			"terrain": "land",
			"active": true,
		},
	]


func _cards() -> Array:
	var rows: Array = []
	for index in range(12):
		rows.append({
			"card_id": "card.%02d" % index,
			"family_id": "family.%02d" % index,
			"card_type": [
				"facility_factory",
				"facility_market",
				"route",
				"warehouse",
				"monster",
			][index % 5],
			"rank": "I",
			"display_name": "Allocator Card %02d" % index,
			"price_cash": 5 + index,
			"region_supply_weight": 1 + (index % 3),
			"enabled": true,
			"valid": true,
			"potential_target_exists": true,
		})
	return rows


func _clock(fixture: Dictionary) -> ClockFixture:
	return fixture.get("clock") as ClockFixture


func _pricing(fixture: Dictionary) -> CardMarketPricingRuntimeController:
	return fixture.get("pricing") as CardMarketPricingRuntimeController


func _purchase(fixture: Dictionary) -> DistrictPurchaseRuntimeController:
	return fixture.get("purchase") as DistrictPurchaseRuntimeController


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", true)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("ALPHA04C ALLOCATOR IDENTITY PARITY: %s" % message)


func _finish() -> void:
	print("ALPHA04C_ALLOCATOR_IDENTITY_RESTORE_PARITY_EVIDENCE|%s" % JSON.stringify(_evidence, "", true))
	print("ALPHA04C_ALLOCATOR_IDENTITY_RESTORE_PARITY_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
