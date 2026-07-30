extends SceneTree

const PURCHASE_SCENE := preload("res://scenes/runtime/DistrictPurchaseRuntimeController.tscn")

const AGGREGATE_REVISION := "region:region.002:38,0,3,9"
const SELECTED_REVISION := "region:region.002:slot:2:revision:3"
const CARD_ID := "facility.factory.energy.rank_1"

var _checks := 0
var _failures: Array[String] = []


class QuoteAuthorityFixture extends Node:
	var _quotes_by_id: Dictionary = {}
	var _next_quote_sequence := 2


	func install_quote(quote: Dictionary) -> void:
		_quotes_by_id[str(quote.get("quote_id", ""))] = quote.duplicate(true)


	func export_quote_for_session(quote_id: String) -> Dictionary:
		return (_quotes_by_id.get(quote_id, {}) as Dictionary).duplicate(true) \
				if _quotes_by_id.get(quote_id, {}) is Dictionary else {}


	func preflight_quote_from_session(snapshot: Dictionary) -> Dictionary:
		if str(snapshot.get("quote_id", "")).is_empty() \
				or int(snapshot.get("player_index", -1)) < 0 \
				or int(snapshot.get("district_index", -1)) < 0 \
				or str(snapshot.get("card_id", "")).is_empty() \
				or str(snapshot.get("supply_revision", "")).is_empty():
			return {"accepted": false, "reason_code": "quote_snapshot_invalid"}
		return {
			"accepted": true,
			"reason_code": "quote_snapshot_valid",
			"normalized_state": snapshot.duplicate(true),
		}


	func restore_quote_from_session(snapshot: Dictionary) -> Dictionary:
		var preflight := preflight_quote_from_session(snapshot)
		if not bool(preflight.get("accepted", false)):
			return {"restored": false, "reason": str(preflight.get("reason_code", "quote_snapshot_invalid"))}
		var normalized := (preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
		install_quote(normalized)
		return {"restored": true, "reason": "quote_restored", "quote": normalized}


	func quote_snapshot(quote_id: String) -> Dictionary:
		return export_quote_for_session(quote_id)


	func reset_state() -> void:
		_quotes_by_id.clear()
		_next_quote_sequence = 1


	func capture_allocator_cursor() -> Dictionary:
		return {"schema_version": 1, "next_quote_sequence": _next_quote_sequence}


	func restore_allocator_cursor(cursor: Dictionary) -> Dictionary:
		if int(cursor.get("schema_version", 0)) != 1 \
				or not (cursor.get("next_quote_sequence") is int) \
				or int(cursor.get("next_quote_sequence", 0)) < 1:
			return {"restored": false, "reason_code": "allocator_cursor_invalid"}
		_next_quote_sequence = int(cursor.get("next_quote_sequence", 0))
		return {"restored": true, "reason_code": "allocator_cursor_restored"}


	func capture_runtime_checkpoint() -> Dictionary:
		return {"schema_version": 1, "quotes_by_id": _quotes_by_id.duplicate(true), "next_quote_sequence": _next_quote_sequence}


	func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
		if int(checkpoint.get("schema_version", 0)) != 1 or not (checkpoint.get("quotes_by_id") is Dictionary) \
				or not (checkpoint.get("next_quote_sequence") is int):
			return {"restored": false, "reason_code": "quote_checkpoint_invalid"}
		_quotes_by_id = (checkpoint.get("quotes_by_id", {}) as Dictionary).duplicate(true)
		_next_quote_sequence = int(checkpoint.get("next_quote_sequence", 1))
		return {"restored": true, "reason_code": "quote_checkpoint_restored"}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := _purchase_fixture()
	var purchase := source.get("purchase") as DistrictPurchaseRuntimeController
	var quote_authority := source.get("quote_authority") as QuoteAuthorityFixture
	_expect(purchase != null and quote_authority != null, "source purchase fixture configures")
	if purchase == null or quote_authority == null:
		_finish()
		return

	var opened := purchase.open_window(0, 2, {"supply_revision": AGGREGATE_REVISION})
	var selected := purchase.acknowledge_card_selection(0, 2, CARD_ID, SELECTED_REVISION)
	var quote := {
		"quote_id": "quote:selected-slot-revision",
		"player_index": 0,
		"district_index": 2,
		"card_id": CARD_ID,
		"supply_revision": SELECTED_REVISION,
	}
	quote_authority.install_quote(quote)
	var attached := purchase.attach_quote(0, 2, quote)
	var active_source := purchase.active_window(0)
	_expect(bool(opened.get("active", false)) and not selected.is_empty() \
			and str(active_source.get("selected_supply_revision", "")) == SELECTED_REVISION \
			and not attached.is_empty(), "active window binds its quote to the selected slot revision")

	var source_before_preflight := purchase.capture_runtime_checkpoint()
	var save := purchase.to_save_data()
	var preflight := purchase.preflight_save_data(save)
	_expect(not save.is_empty() and bool(preflight.get("accepted", false)) \
			and str(preflight.get("reason_code", "")) == "purchase_session_save_valid" \
			and purchase.capture_runtime_checkpoint() == source_before_preflight, "selected slot quote survives pure save preflight with zero mutation when the aggregate rack revision differs")

	var target := _purchase_fixture()
	var restored := target.get("purchase") as DistrictPurchaseRuntimeController
	var apply := restored.apply_save_data(save) if restored != null else {}
	var restored_window := restored.active_window(0) if restored != null else {}
	_expect(bool(apply.get("applied", false)) and int(apply.get("session_count", 0)) == 1 \
			and int(apply.get("quote_restore_failures", -1)) == 0, "selected slot quote applies through the transactional save surface")
	_expect(str(restored_window.get("supply_revision", "")) == AGGREGATE_REVISION \
			and str(restored_window.get("selected_supply_revision", "")) == SELECTED_REVISION \
			and str((restored_window.get("active_quote", {}) as Dictionary).get("supply_revision", "")) == SELECTED_REVISION, "restore preserves distinct aggregate and selected revisions without live rebinding")
	_expect(restored.to_save_data() == save, "selected slot quote capture/apply/capture roundtrip is exact")

	var sessions: Array = ((save.get("district_purchase_runtime", {}) as Dictionary).get("sessions", []) as Array) \
			if save.get("district_purchase_runtime", {}) is Dictionary else []
	if sessions.is_empty():
		_expect(false, "quote revision that matches only the aggregate rack is rejected once a selected slot revision exists")
	else:
		var tampered := save.duplicate(true)
		var payload := tampered.get("district_purchase_runtime", {}) as Dictionary
		var tampered_sessions := (payload.get("sessions", []) as Array).duplicate(true)
		var tampered_session := (tampered_sessions[0] as Dictionary).duplicate(true)
		var tampered_quote := (tampered_session.get("active_quote", {}) as Dictionary).duplicate(true)
		tampered_quote["supply_revision"] = AGGREGATE_REVISION
		tampered_session["active_quote"] = tampered_quote
		tampered_sessions[0] = tampered_session
		payload["sessions"] = tampered_sessions
		tampered["district_purchase_runtime"] = payload
		var target_before_rejection := restored.capture_runtime_checkpoint()
		var rejected := restored.preflight_save_data(tampered)
		_expect(not bool(rejected.get("accepted", true)) \
				and str(rejected.get("reason_code", "")) == "quote_session_binding_invalid" \
				and restored.capture_runtime_checkpoint() == target_before_rejection, "quote revision that matches only the aggregate rack is rejected without mutation once a selected slot revision exists")

	(source.get("root") as Node).queue_free()
	(target.get("root") as Node).queue_free()
	await process_frame
	_finish()


func _purchase_fixture() -> Dictionary:
	var fixture_root := Node.new()
	root.add_child(fixture_root)
	var quote_authority := QuoteAuthorityFixture.new()
	quote_authority.name = "QuoteAuthorityFixture"
	fixture_root.add_child(quote_authority)
	var purchase := PURCHASE_SCENE.instantiate() as DistrictPurchaseRuntimeController
	fixture_root.add_child(purchase)
	purchase.set_quote_authority(quote_authority)
	purchase.configure()
	return {"root": fixture_root, "purchase": purchase, "quote_authority": quote_authority}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("DISTRICT PURCHASE SAVE REVISION BINDING: %s" % message)


func _finish() -> void:
	print("DISTRICT_PURCHASE_SAVE_REVISION_BINDING_TEST|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
		JSON.stringify(_failures),
	])
	quit(0 if _failures.is_empty() else 1)
