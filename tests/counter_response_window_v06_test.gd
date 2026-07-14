extends SceneTree

const WINDOW := preload("res://scripts/cards/v06/interaction/counter_response_window_v06.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var windows = WINDOW.new()
	var rejected: Dictionary = windows.open_window(_request("bad", "economic", false, ["B"]))
	_expect(str(rejected.get("reason_code", "")) == "counter_window_incoming_scope_invalid" and int(windows.debug_snapshot().get("window_count", -1)) == 0, "non-direct effect opens no counter window and changes no state")
	var no_holder: Dictionary = windows.open_window(_request("none", "direct_player", true, []))
	_expect(str(no_holder.get("outcome", "")) == "no_eligible_responder", "no-holder case still produces an explainable state-machine result")
	var opened: Dictionary = windows.open_window(_request("main", "direct_player", true, ["B", "C"]))
	_expect(str(opened.get("state", "")) == "open" and is_equal_approx(float(opened.get("deadline_at", 0.0)), 105.0), "deadline comes from supplied rule configuration")
	var unauthorized: Dictionary = windows.submit_pass("main", "D", "r-unauthorized", 101.0)
	_expect(str(unauthorized.get("reason_code", "")) == "counter_responder_unauthorized", "unauthorized responder is rejected")
	var passed: Dictionary = windows.submit_pass("main", "B", "r-pass-b", 101.0)
	var pass_replay: Dictionary = windows.submit_pass("main", "B", "r-pass-b", 101.0)
	_expect(str(passed.get("state", "")) == "open" and bool(pass_replay.get("idempotent_replay", false)), "pass replay is exact-once")
	var duplicate_actor: Dictionary = windows.submit_pass("main", "B", "r-pass-b-2", 102.0)
	_expect(str(duplicate_actor.get("reason_code", "")) == "counter_responder_already_submitted", "same responder cannot submit twice")
	var responded: Dictionary = windows.submit_response("main", "C", "r-counter-c", _counter_intent("C"), 102.0)
	_expect(str(responded.get("outcome", "")) == "countered", "legal counter resolves the window")
	var closed: Dictionary = windows.submit_pass("main", "C", "r-after-close", 103.0)
	_expect(str(closed.get("reason_code", "")) == "counter_window_closed", "closed window rejects later responses")

	var timeout_open: Dictionary = windows.open_window(_request("timeout", "direct_player", true, ["B"]))
	var timeout_results := windows.resolve_timeouts(105.0)
	_expect(str(timeout_open.get("state", "")) == "open" and timeout_results.size() == 1 and str(timeout_results[0].get("outcome", "")) == "timeout", "timeout resolves deterministically")
	var cancelled_open: Dictionary = windows.open_window(_request("cancel", "direct_player", true, ["B"]))
	var cancelled: Dictionary = windows.cancel_window("cancel")
	_expect(str(cancelled_open.get("state", "")) == "open" and str(cancelled.get("state", "")) == "cancelled", "open window can be cancelled")

	var save_open: Dictionary = windows.open_window(_request("save", "direct_player", true, ["B"]))
	var saved := windows.to_save_data()
	var restored = WINDOW.new()
	var loaded: Dictionary = restored.apply_save_data(saved)
	_expect(str(save_open.get("state", "")) == "open" and bool(loaded.get("loaded", false)) and str(restored.window_snapshot("save").get("state", "")) == "open", "inflight window survives save/load")
	_expect(bool(restored.checkpoint_status().get("can_checkpoint", false)) and (restored.checkpoint_status().get("inflight_window_ids", []) as Array).has("save"), "checkpoint explicitly records inflight windows")
	var invalid_counter := _counter_intent("B")
	invalid_counter["target_kind"] = "incoming_weather_effect"
	var invalid_response: Dictionary = restored.submit_response("save", "B", "r-invalid-counter", invalid_counter, 101.0)
	_expect(str(invalid_response.get("reason_code", "")) == "counter_response_intent_invalid" and str(restored.window_snapshot("save").get("state", "")) == "open", "invalid counter has zero window side effects")
	_finish()


func _request(id: String, domain: String, direct: bool, responders: Array) -> Dictionary:
	return {"window_id": id, "transaction_id": "tx-%s" % id, "incoming_effect_kind": "player_hand_disrupt", "incoming_route_domain": domain, "incoming_direct_player_interaction": direct, "legal_responder_ids": responders, "opened_at": 100.0, "deadline_seconds": 5.0}


func _counter_intent(actor: String) -> Dictionary:
	return {"schema_version": "0.6", "transaction_id": "tx-counter-%s" % actor, "actor_id": actor, "card_id": "fixture.counter", "card_instance_id": "counter-%s" % actor, "effect_kind": "card_counter", "target_kind": "incoming_direct_player_interaction", "target_player_ids": [actor], "target_revision": 2, "effect_payload": {"target_scope": "direct_player_interaction", "response_depth": 1}, "target_hash": "incoming", "payload_hash": "counter", "intent_hash": "intent-counter-%s" % actor}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	print("COUNTER_RESPONSE_WINDOW_V06_TEST|status=%s|checks=%d|failures=%d" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
