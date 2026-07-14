extends RefCounted
class_name CounterResponseWindowV06

const SCHEMA := preload("res://scripts/cards/v06/interaction/anonymous_interaction_runtime_schema_v06.gd")
const SAVE_SCHEMA := 1

var _windows: Dictionary = {}
var _action_journal: Dictionary = {}
var _revision := 0


func open_window(request: Dictionary) -> Dictionary:
	var window_id := str(request.get("window_id", "")).strip_edges()
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if window_id.is_empty() or transaction_id.is_empty():
		return _reject("counter_window_identity_invalid")
	if _windows.has(window_id):
		var existing: Dictionary = _windows.get(window_id)
		if str(existing.get("transaction_id", "")) == transaction_id:
			return _with_replay(existing)
		return _reject("counter_window_identity_collision")
	if not bool(request.get("incoming_direct_player_interaction", false)) \
	or str(request.get("incoming_route_domain", "")) != "direct_player":
		return _reject("counter_window_incoming_scope_invalid")
	var deadline_seconds := float(request.get("deadline_seconds", 0.0))
	if deadline_seconds <= 0.0:
		return _reject("counter_window_deadline_invalid")
	var opened_at := float(request.get("opened_at", -1.0))
	if opened_at < 0.0:
		return _reject("counter_window_clock_invalid")
	var responders := _string_array(request.get("legal_responder_ids", []))
	var window := {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"window_id": window_id,
		"transaction_id": transaction_id,
		"incoming_effect_kind": str(request.get("incoming_effect_kind", "")),
		"incoming_route_domain": "direct_player",
		"response_depth": 1,
		"opened_at": opened_at,
		"deadline_seconds": deadline_seconds,
		"deadline_at": opened_at + deadline_seconds,
		"legal_responder_ids": responders,
		"responses_by_actor": {},
		"state": "open",
		"reason_code": "counter_window_open",
		"revision": _revision + 1,
	}
	_revision += 1
	if responders.is_empty():
		window["state"] = "resolved"
		window["outcome"] = "no_eligible_responder"
		window["reason_code"] = "counter_window_no_eligible_responder"
	_windows[window_id] = window
	return window.duplicate(true)


func submit_pass(window_id: String, responder_id: String, response_id: String, now: float) -> Dictionary:
	return _submit(window_id, responder_id, response_id, "pass", {}, now)


func submit_response(window_id: String, responder_id: String, response_id: String, counter_intent: Dictionary, now: float) -> Dictionary:
	return _submit(window_id, responder_id, response_id, "respond", counter_intent, now)


func resolve_timeouts(now: float) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ids := _windows.keys()
	ids.sort()
	for id_variant in ids:
		var window: Dictionary = _windows.get(id_variant)
		if str(window.get("state", "")) == "open" and now >= float(window.get("deadline_at", INF)):
			window["state"] = "resolved"
			window["outcome"] = "timeout"
			window["reason_code"] = "counter_window_timeout"
			window["resolved_at"] = now
			_revision += 1
			window["revision"] = _revision
			_windows[str(id_variant)] = window
			results.append(window.duplicate(true))
	return results


func cancel_window(window_id: String, reason_code: String = "counter_window_cancelled") -> Dictionary:
	if not _windows.has(window_id):
		return _reject("counter_window_missing")
	var window: Dictionary = _windows.get(window_id)
	if str(window.get("state", "")) != "open":
		return _with_replay(window)
	window["state"] = "cancelled"
	window["outcome"] = "cancelled"
	window["reason_code"] = reason_code
	_revision += 1
	window["revision"] = _revision
	_windows[window_id] = window
	return window.duplicate(true)


func window_snapshot(window_id: String) -> Dictionary:
	return (_windows.get(window_id, {}) as Dictionary).duplicate(true)


func checkpoint_status() -> Dictionary:
	var inflight: Array[String] = []
	for key_variant in _windows.keys():
		if str((_windows.get(key_variant) as Dictionary).get("state", "")) == "open":
			inflight.append(str(key_variant))
	inflight.sort()
	return {"can_checkpoint": true, "reason_code": "counter_windows_serializable", "inflight_window_ids": inflight, "revision": _revision}


func to_save_data() -> Dictionary:
	return {"schema_version": SAVE_SCHEMA, "revision": _revision, "windows": _windows.duplicate(true), "action_journal": _action_journal.duplicate(true)}


func apply_save_data(data: Dictionary) -> Dictionary:
	if int(data.get("schema_version", -1)) != SAVE_SCHEMA \
	or not (data.get("windows", {}) is Dictionary) \
	or not (data.get("action_journal", {}) is Dictionary):
		return {"loaded": false, "reason_code": "counter_window_save_invalid"}
	var windows: Dictionary = data.get("windows", {})
	for value_variant in windows.values():
		if not (value_variant is Dictionary):
			return {"loaded": false, "reason_code": "counter_window_save_invalid"}
		var window: Dictionary = value_variant
		if str(window.get("window_id", "")).is_empty() or str(window.get("transaction_id", "")).is_empty():
			return {"loaded": false, "reason_code": "counter_window_save_invalid"}
	_windows = windows.duplicate(true)
	_action_journal = (data.get("action_journal", {}) as Dictionary).duplicate(true)
	_revision = int(data.get("revision", 0))
	return {"loaded": true, "reason_code": "counter_window_save_loaded", "checkpoint": checkpoint_status()}


func debug_snapshot() -> Dictionary:
	return {"window_count": _windows.size(), "action_journal_count": _action_journal.size(), "revision": _revision, "checkpoint": checkpoint_status()}


func _submit(window_id: String, responder_id: String, response_id: String, action: String, counter_intent: Dictionary, now: float) -> Dictionary:
	var action_key := "%s:%s" % [window_id, response_id]
	var fingerprint := SCHEMA.canonical_hash({"window_id": window_id, "responder_id": responder_id, "action": action, "counter_intent": counter_intent})
	if _action_journal.has(action_key):
		var entry: Dictionary = _action_journal.get(action_key)
		if str(entry.get("fingerprint", "")) != fingerprint:
			return _reject("counter_response_id_collision")
		return _with_replay(entry.get("result", {}) as Dictionary)
	if not _windows.has(window_id):
		return _remember(action_key, fingerprint, _reject("counter_window_missing"))
	var window: Dictionary = _windows.get(window_id)
	if str(window.get("state", "")) != "open":
		return _remember(action_key, fingerprint, _reject("counter_window_closed"))
	if now >= float(window.get("deadline_at", INF)):
		resolve_timeouts(now)
		return _remember(action_key, fingerprint, _reject("counter_window_timeout"))
	if not (window.get("legal_responder_ids", []) as Array).has(responder_id):
		return _remember(action_key, fingerprint, _reject("counter_responder_unauthorized"))
	var responses: Dictionary = window.get("responses_by_actor", {})
	if responses.has(responder_id):
		return _remember(action_key, fingerprint, _reject("counter_responder_already_submitted"))
	if action == "respond":
		var validation := SCHEMA.validate_intent(counter_intent)
		if not bool(validation.get("valid", false)) or str(validation.get("route_domain", "")) != "counter_response":
			return _remember(action_key, fingerprint, _reject("counter_response_intent_invalid"))
		if str(counter_intent.get("actor_id", "")) != responder_id:
			return _remember(action_key, fingerprint, _reject("counter_response_actor_mismatch"))
		responses[responder_id] = {"action": "respond", "response_id": response_id, "submitted_at": now, "counter_transaction_id": str(counter_intent.get("transaction_id", ""))}
		window["responses_by_actor"] = responses
		window["state"] = "resolved"
		window["outcome"] = "countered"
		window["reason_code"] = "counter_window_countered"
		window["resolved_at"] = now
	else:
		responses[responder_id] = {"action": "pass", "response_id": response_id, "submitted_at": now}
		window["responses_by_actor"] = responses
		if responses.size() >= (window.get("legal_responder_ids", []) as Array).size():
			window["state"] = "resolved"
			window["outcome"] = "all_passed"
			window["reason_code"] = "counter_window_all_passed"
			window["resolved_at"] = now
	_revision += 1
	window["revision"] = _revision
	_windows[window_id] = window
	return _remember(action_key, fingerprint, window.duplicate(true))


func _remember(action_key: String, fingerprint: String, result: Dictionary) -> Dictionary:
	_action_journal[action_key] = {"fingerprint": fingerprint, "result": result.duplicate(true)}
	return result


func _reject(reason_code: String) -> Dictionary:
	return {"accepted": false, "reason_code": reason_code, "state_changed": false}


func _with_replay(result: Dictionary) -> Dictionary:
	var replay := result.duplicate(true)
	replay["idempotent_replay"] = true
	return replay


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value:
			var item := str(item_variant).strip_edges()
			if not item.is_empty() and not result.has(item):
				result.append(item)
	result.sort()
	return result
