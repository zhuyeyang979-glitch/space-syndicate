extends SceneTree

const DISTRICT := preload("res://scripts/runtime/district_purchase_runtime_controller.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

class QuoteAuthority:
	extends Node

	var quotes: Dictionary = {}
	var next_quote_sequence := 2
	var fail_restore_once := false

	func install(quote: Dictionary) -> void:
		quotes[str(quote.get("quote_id", ""))] = quote.duplicate(true)

	func export_quote_for_session(quote_id: String) -> Dictionary:
		return (quotes.get(quote_id, {}) as Dictionary).duplicate(true) if quotes.get(quote_id) is Dictionary else {}

	func export_quote_for_pending_session(quote_id: String) -> Dictionary:
		return export_quote_for_session(quote_id)

	func preflight_quote_from_session(snapshot: Dictionary) -> Dictionary:
		return {"accepted": not snapshot.is_empty(), "normalized_state": snapshot.duplicate(true), "reason_code": "fixture_quote_valid"}

	func restore_quote_from_session(snapshot: Dictionary) -> Dictionary:
		install(snapshot)
		return {"restored": true, "quote": snapshot.duplicate(true)}

	func restore_pending_quote_from_session(snapshot: Dictionary) -> Dictionary:
		return restore_quote_from_session(snapshot)

	func quote_snapshot(quote_id: String) -> Dictionary:
		return export_quote_for_session(quote_id)

	func capture_allocator_cursor() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence}

	func restore_allocator_cursor(cursor: Dictionary) -> Dictionary:
		next_quote_sequence = int(cursor.get("next_quote_sequence", 1))
		return {"restored": true}

	func capture_runtime_checkpoint() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": next_quote_sequence, "quotes_by_id": quotes.duplicate(true)}

	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		if fail_restore_once:
			fail_restore_once = false
			return {"restored": false, "reason_code": "fixture_quote_restore_failed"}
		if int(checkpoint.get("schema_version", 0)) != 1 \
				or not (checkpoint.get("quotes_by_id") is Dictionary) \
				or not (checkpoint.get("next_quote_sequence") is int):
			return {"restored": false, "reason_code": "fixture_quote_checkpoint_invalid"}
		quotes = (checkpoint.get("quotes_by_id", {}) as Dictionary).duplicate(true)
		next_quote_sequence = int(checkpoint.get("next_quote_sequence", 1))
		return {"restored": true}

	func reset_state() -> void:
		quotes.clear()
		next_quote_sequence = 1


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authority := QuoteAuthority.new()
	var purchase := DISTRICT.new() as DistrictPurchaseRuntimeController
	root.add_child(authority)
	root.add_child(purchase)
	purchase.set_quote_authority(authority)
	purchase.configure()
	var quote := {
		"quote_id": "market-quote-1000-1",
		"player_index": 0,
		"district_index": 2,
		"card_id": "fixture.card",
		"supply_revision": "fixture-r1",
	}
	authority.install(quote)
	var opened := purchase.open_window(0, 2, {"supply_revision": "fixture-r1"})
	var attached := purchase.attach_quote(0, 2, quote)
	var pending := purchase.reserve_pending_discard({
		"player_index": 0,
		"district_index": 2,
		"card_id": "fixture.card",
		"quote_id": "market-quote-1000-1",
		"price": 101,
		"opened_at": 12.125,
	})
	_expect(not opened.is_empty() and not attached.is_empty() and not pending.is_empty(), "real District controller enters pending discard")
	_expect(not purchase.pending_discard_private_snapshot(0).has("opened_at"), "presentation-only opened_at never enters authoritative pending state")
	var save := purchase.to_save_data()
	_expect(WIRE.is_closed_data(save) and not JSON.stringify(save).contains("opened_at"), "District persistent Save remains closed without metadata cleaning")

	var checkpoint_a := purchase.capture_runtime_checkpoint()
	var player_map := checkpoint_a.get("windows_by_player", {}) as Dictionary
	var entries := player_map.get("entries", {}) as Dictionary
	_expect(int(checkpoint_a.get("schema_version", 0)) == 2 and WIRE.is_closed_data(checkpoint_a), "District checkpoint v2 is strict closed data")
	_expect(entries.keys() == ["0"] and str(player_map.get("key_codec", "")) == "nonnegative_decimal_string_v1", "District int runtime key uses canonical string wire")

	purchase.close_window(0, "mutated")
	authority.next_quote_sequence = 9
	var restored := purchase.restore_runtime_checkpoint(checkpoint_a)
	_expect(bool(restored.get("restored", false)) and purchase.capture_runtime_checkpoint() == checkpoint_a, "District checkpoint A equals B after restore")

	var before_invalid := purchase.capture_runtime_checkpoint()
	var noncanonical := checkpoint_a.duplicate(true)
	var bad_map := (noncanonical.get("windows_by_player", {}) as Dictionary).duplicate(true)
	var bad_entries := (bad_map.get("entries", {}) as Dictionary).duplicate(true)
	bad_entries["01"] = bad_entries.get("0")
	bad_entries.erase("0")
	bad_map["entries"] = bad_entries
	noncanonical["windows_by_player"] = bad_map
	var noncanonical_result := purchase.restore_runtime_checkpoint(noncanonical)
	_expect(not bool(noncanonical_result.get("restored", true)) and purchase.capture_runtime_checkpoint() == before_invalid, "noncanonical player key fails before mutation")
	var v1 := {"schema_version": 1, "windows_by_player": {}, "decision_sequence": 0, "quote_checkpoint": {}}
	_expect(not bool(purchase.restore_runtime_checkpoint(v1).get("restored", true)), "District checkpoint v1 fails closed")

	authority.fail_restore_once = true
	var quote_failure := purchase.restore_runtime_checkpoint(checkpoint_a)
	_expect(not bool(quote_failure.get("restored", true)) and bool(quote_failure.get("rollback_complete", false)) and purchase.capture_runtime_checkpoint() == before_invalid, "quote restore failure rolls back with District state untouched")

	purchase.queue_free()
	authority.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("DISTRICT_PURCHASE_RUNTIME_CHECKPOINT_V2_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("District Purchase checkpoint v2 failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
