extends SceneTree

const PRICING_SCENE := preload("res://scenes/runtime/CardMarketPricingRuntimeController.tscn")
const PURCHASE_SCENE := preload("res://scenes/runtime/DistrictPurchaseRuntimeController.tscn")

const DISTRICT_INDEX := 2
const INITIAL_WORLD_US := 1_000_000
const EXPECTED_PURCHASE_SCHEMA_VERSION := 3
const CURSOR_FIELD := "next_quote_sequence"
const MISSING_CURSOR_REASON := "allocator_cursor_missing_requires_backup"
const INVALID_CURSOR_REASONS := [
	"allocator_cursor_invalid",
	"next_quote_sequence_invalid",
]
const REGRESSED_CURSOR_REASONS := [
	"allocator_cursor_regressed",
	"next_quote_sequence_regressed",
]

var _checks := 0
var _failures: Array[String] = []
var _fixture_roots: Array[Node] = []


class ClockFixture extends Node:
	var current_us := INITIAL_WORLD_US


	func world_effective_micros() -> int:
		return current_us


	func restore_micros(value: int) -> void:
		current_us = value


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
	_test_save_projection_retains_cursor()
	_test_cursor_validation_fails_closed()
	_test_repeated_apply_and_rollback_preserve_cursor()
	_test_next_quote_id_fork_parity()
	for fixture_root in _fixture_roots:
		if is_instance_valid(fixture_root):
			fixture_root.queue_free()
	await process_frame
	_finish()


func _test_save_projection_retains_cursor() -> void:
	var valid_fixture := _fixture()
	var valid_quote := _open_and_quote(valid_fixture, 0, "card.qa.valid", "revision-valid")
	var valid_save := _purchase(valid_fixture).to_save_data()
	var valid_payload := _purchase_payload(valid_save)
	_expect(not valid_quote.is_empty() and _saved_quote_ids(valid_save) == [str(valid_quote.get("quote_id", ""))], "an unexpired active quote is retained in the district-purchase Save projection")
	_expect(_payload_has_cursor_contract(valid_payload) and int(valid_payload.get(CURSOR_FIELD, -1)) == 2, "an unexpired quote Save retains next_quote_sequence=2 in district_purchase_runtime v3")

	var expired_fixture := _fixture()
	var expired_quote := _open_and_quote(expired_fixture, 0, "card.qa.expired", "revision-expired")
	_clock(expired_fixture).restore_micros(int(expired_quote.get("expires_at_world_us", -1)))
	var expired_save := _purchase(expired_fixture).to_save_data()
	var expired_payload := _purchase_payload(expired_save)
	_expect(not expired_quote.is_empty() and _saved_quote_ids(expired_save).is_empty(), "an ordinary quote is omitted exactly at its half-open expiry boundary")
	_expect(_payload_has_cursor_contract(expired_payload) and int(expired_payload.get(CURSOR_FIELD, -1)) == 2, "omitting an expired quote does not forget its consumed allocator sequence")

	var mixed := _mixed_fixture()
	var mixed_save := mixed.get("save") as Dictionary
	var mixed_payload := _purchase_payload(mixed_save)
	var retained_id := str((mixed.get("retained_quote") as Dictionary).get("quote_id", ""))
	var omitted_id := str((mixed.get("omitted_quote") as Dictionary).get("quote_id", ""))
	var saved_ids := _saved_quote_ids(mixed_save)
	_expect(saved_ids == [retained_id] and not saved_ids.has(omitted_id), "mixed expiry retains the pending-discard quote and omits the ordinary expired quote")
	_expect(_payload_has_cursor_contract(mixed_payload) and int(mixed_payload.get(CURSOR_FIELD, -1)) == 3, "mixed omission persists the allocator high-water cursor beyond both consumed quote IDs")
	_expect(int(mixed_payload.get(CURSOR_FIELD, -1)) == int(_pricing(mixed).capture_runtime_checkpoint().get(CURSOR_FIELD, -2)), "the formal Save field equals the quote authority runtime cursor without reconstructing it from retained quotes")


func _test_cursor_validation_fails_closed() -> void:
	var mixed := _mixed_fixture()
	var purchase := _purchase(mixed)
	var save := mixed.get("save") as Dictionary
	var retained_sequence := _quote_sequence(str((mixed.get("retained_quote") as Dictionary).get("quote_id", "")))
	var before := purchase.capture_runtime_checkpoint()

	var missing := save.duplicate(true)
	var missing_payload := _purchase_payload(missing).duplicate(true)
	missing_payload["schema_version"] = 2
	missing_payload.erase(CURSOR_FIELD)
	missing["district_purchase_runtime"] = missing_payload
	var missing_result := purchase.preflight_save_data(missing)
	_expect(not bool(missing_result.get("accepted", true)) \
			and str(missing_result.get("reason_code", "")) == MISSING_CURSOR_REASON \
			and bool(missing_result.get("requires_backup", false)), "legacy v2 payload without allocator cursor fails closed with allocator_cursor_missing_requires_backup")
	_expect(purchase.capture_runtime_checkpoint() == before, "missing-cursor preflight is mutation-free")

	var negative := _save_with_cursor(save, -1)
	var negative_result := purchase.preflight_save_data(negative)
	_expect(not bool(negative_result.get("accepted", true)) and str(negative_result.get("reason_code", "")) in INVALID_CURSOR_REASONS, "negative next_quote_sequence is rejected with a typed allocator-cursor reason")
	_expect(purchase.capture_runtime_checkpoint() == before, "negative-cursor preflight is mutation-free")

	var regressed := _save_with_cursor(save, retained_sequence)
	var regressed_result := purchase.preflight_save_data(regressed)
	_expect(not bool(regressed_result.get("accepted", true)) and str(regressed_result.get("reason_code", "")) in REGRESSED_CURSOR_REASONS, "next_quote_sequence cannot regress to the highest retained quote sequence")
	_expect(purchase.capture_runtime_checkpoint() == before, "regressed-cursor preflight is mutation-free")


func _test_repeated_apply_and_rollback_preserve_cursor() -> void:
	var mixed := _mixed_fixture()
	var save := mixed.get("save") as Dictionary
	var expected_cursor := int(_purchase_payload(save).get(CURSOR_FIELD, -1))
	var target := _fixture(int(mixed.get("save_world_us", INITIAL_WORLD_US)))
	var first_apply := _purchase(target).apply_save_data(save)
	var first_checkpoint := _pricing(target).capture_runtime_checkpoint()
	var second_apply := _purchase(target).apply_save_data(save)
	var second_checkpoint := _pricing(target).capture_runtime_checkpoint()
	_expect(bool(first_apply.get("applied", false)) and bool(second_apply.get("applied", false)), "the same cursor-bearing district-purchase Save applies repeatedly")
	_expect(expected_cursor >= 1 and int(first_checkpoint.get(CURSOR_FIELD, -1)) == expected_cursor and int(second_checkpoint.get(CURSOR_FIELD, -1)) == expected_cursor, "repeated apply restores the exact cursor without advancing it")
	_expect(_purchase(target).to_save_data() == save, "repeated apply exact-recaptures the same cursor-bearing Save payload")

	var active_source := _fixture()
	var active_quote := _open_and_quote(active_source, 0, "card.qa.rollback-source", "revision-rollback-source")
	var active_save := _purchase(active_source).to_save_data()
	var rollback_target := _fixture(int(active_quote.get("expires_at_world_us", INITIAL_WORLD_US)))
	_open_and_quote(rollback_target, 3, "card.qa.rollback-existing-a", "revision-rollback-existing-a")
	_open_and_quote(rollback_target, 4, "card.qa.rollback-existing-b", "revision-rollback-existing-b")
	var before_failed_apply := _purchase(rollback_target).capture_runtime_checkpoint()
	var failed_apply := _purchase(rollback_target).apply_save_data(active_save)
	var after_failed_apply := _purchase(rollback_target).capture_runtime_checkpoint()
	_expect(not bool(failed_apply.get("applied", true)) and bool(failed_apply.get("rollback_attempted", false)) and bool(failed_apply.get("rollback_complete", false)), "a quote that expires before restore triggers transactional rollback")
	_expect(after_failed_apply == before_failed_apply, "failed apply rolls back purchase sessions and the quote allocator cursor exactly")


func _test_next_quote_id_fork_parity() -> void:
	var source := _mixed_fixture()
	var save := source.get("save") as Dictionary
	var future_request := _listing("card.qa.after-save", "revision-after-save", 0)
	var uninterrupted := _pricing(source).quote_listing(future_request)

	var restored := _fixture(int(source.get("save_world_us", INITIAL_WORLD_US)))
	var applied := _purchase(restored).apply_save_data(save)
	var resumed := _pricing(restored).quote_listing(future_request)
	var uninterrupted_transaction_id := "district-purchase:%s" % str(uninterrupted.get("quote_id", ""))
	var resumed_transaction_id := "district-purchase:%s" % str(resumed.get("quote_id", ""))
	_expect(bool(applied.get("applied", false)), "cursor-bearing mixed Save restores before fork parity is measured")
	_expect(not uninterrupted.is_empty() and not resumed.is_empty() \
			and str(resumed.get("quote_id", "")) == str(uninterrupted.get("quote_id", "")) \
			and resumed_transaction_id == uninterrupted_transaction_id, "the next quote and its deterministic district-purchase transaction ID are identical across uninterrupted and restored forks")
	_expect(_quote_sequence(str(uninterrupted.get("quote_id", ""))) == 3 and _quote_sequence(str(resumed.get("quote_id", ""))) == 3, "the omitted expired quote sequence is never reused after restore")


func _fixture(world_us: int = INITIAL_WORLD_US) -> Dictionary:
	var fixture_root := Node.new()
	fixture_root.name = "CardMarketAllocatorCursorFixture"
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
		"root": fixture_root,
		"clock": clock,
		"pricing": pricing,
		"purchase": purchase,
	}


func _mixed_fixture() -> Dictionary:
	var fixture := _fixture()
	var retained_quote := _open_and_quote(fixture, 0, "card.qa.pending-retained", "revision-pending-retained", true)
	var omitted_quote := _open_and_quote(fixture, 1, "card.qa.ordinary-omitted", "revision-ordinary-omitted")
	var save_world_us := int(retained_quote.get("expires_at_world_us", INITIAL_WORLD_US))
	_clock(fixture).restore_micros(save_world_us)
	fixture["retained_quote"] = retained_quote
	fixture["omitted_quote"] = omitted_quote
	fixture["save_world_us"] = save_world_us
	fixture["save"] = _purchase(fixture).to_save_data()
	return fixture


func _open_and_quote(
	fixture: Dictionary,
	player_index: int,
	card_id: String,
	revision: String,
	pending_discard: bool = false
) -> Dictionary:
	var purchase := _purchase(fixture)
	var opened := purchase.open_window(player_index, DISTRICT_INDEX, {"supply_revision": revision})
	var selected := purchase.acknowledge_card_selection(player_index, DISTRICT_INDEX, card_id, revision)
	var quote := _pricing(fixture).quote_listing(_listing(card_id, revision, player_index))
	var attached := purchase.attach_quote(player_index, DISTRICT_INDEX, quote)
	if pending_discard:
		purchase.reserve_pending_discard({
			"player_index": player_index,
			"district_index": DISTRICT_INDEX,
			"card_id": card_id,
			"quote_id": str(quote.get("quote_id", "")),
			"price": int(quote.get("final_price", -1)),
		})
	_expect(bool(opened.get("active", false)) and not selected.is_empty() and not quote.is_empty() and not attached.is_empty(), "fixture creates a real bound quote for player %d" % player_index)
	return quote


func _listing(card_id: String, revision: String, player_index: int) -> Dictionary:
	return {
		"player_index": player_index,
		"district_index": DISTRICT_INDEX,
		"card_id": card_id,
		"supply_revision": revision,
		"base_price": 101,
	}


func _save_with_cursor(save: Dictionary, cursor: int) -> Dictionary:
	var candidate := save.duplicate(true)
	var payload := _purchase_payload(candidate).duplicate(true)
	payload["schema_version"] = EXPECTED_PURCHASE_SCHEMA_VERSION
	payload[CURSOR_FIELD] = cursor
	candidate["district_purchase_runtime"] = payload
	return candidate


func _purchase_payload(save: Dictionary) -> Dictionary:
	var payload: Variant = save.get("district_purchase_runtime", {})
	return (payload as Dictionary).duplicate(true) if payload is Dictionary else {}


func _payload_has_cursor_contract(payload: Dictionary) -> bool:
	return int(payload.get("schema_version", 0)) == EXPECTED_PURCHASE_SCHEMA_VERSION \
			and payload.has(CURSOR_FIELD) \
			and payload.get(CURSOR_FIELD) is int


func _saved_quote_ids(save: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var sessions: Variant = _purchase_payload(save).get("sessions", [])
	if not (sessions is Array):
		return ids
	for session_variant in sessions as Array:
		if not (session_variant is Dictionary):
			continue
		var quote: Variant = (session_variant as Dictionary).get("active_quote", {})
		if quote is Dictionary and not (quote as Dictionary).is_empty():
			ids.append(str((quote as Dictionary).get("quote_id", "")))
	return ids


func _quote_sequence(quote_id: String) -> int:
	var separator := quote_id.rfind("-")
	if separator < 0 or separator + 1 >= quote_id.length():
		return -1
	var sequence_text := quote_id.substr(separator + 1)
	return int(sequence_text) if sequence_text.is_valid_int() else -1


func _clock(fixture: Dictionary) -> ClockFixture:
	return fixture.get("clock") as ClockFixture


func _pricing(fixture: Dictionary) -> CardMarketPricingRuntimeController:
	return fixture.get("pricing") as CardMarketPricingRuntimeController


func _purchase(fixture: Dictionary) -> DistrictPurchaseRuntimeController:
	return fixture.get("purchase") as DistrictPurchaseRuntimeController


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("ALPHA04C CARD MARKET ALLOCATOR CURSOR SAVE: %s" % message)


func _finish() -> void:
	print("ALPHA04C_CARD_MARKET_ALLOCATOR_CURSOR_SAVE_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
