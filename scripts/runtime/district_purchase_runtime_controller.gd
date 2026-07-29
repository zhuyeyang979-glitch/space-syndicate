@tool
extends Node
class_name DistrictPurchaseRuntimeController

signal window_opened(player_index: int, district_index: int)
signal window_closed(player_index: int, district_index: int, reason: String)

const STATE_ACTIVE := "active"
const STATE_PENDING_DISCARD := "pending_discard"
const STATE_CLOSED := "closed"
const ROOT_SAVE_FIELDS := ["district_purchase_runtime"]
const SAVE_PAYLOAD_FIELDS := ["schema_version", "sessions"]
const SESSION_SAVE_FIELDS := [
	"schema_version",
	"player_index",
	"district_index",
	"state",
	"supply_revision",
	"selected_card_id",
	"selected_supply_revision",
	"requires_reselection",
	"reserved_card_id",
	"decision_sequence",
	"pending_payload",
	"active_quote",
]
const FORBIDDEN_NESTED_FIELDS := ["slots", "player_slots", "cash", "player_cash", "ai_profile", "ai_memory"]

var _configured := false
var _quote_authority: Node
var _windows_by_player: Dictionary = {}
var _decision_sequence := 0


func set_quote_authority(authority: Node) -> void:
	_quote_authority = authority


func configure(_timing_rules: Dictionary = {}) -> void:
	_configured = _quote_authority != null \
		and _quote_authority.has_method("export_quote_for_session") \
		and _quote_authority.has_method("restore_quote_from_session")


func reset_state() -> void:
	_windows_by_player.clear()
	_decision_sequence = 0


func open_window(player_index: int, district_index: int, session_snapshot: Dictionary = {}) -> Dictionary:
	if not _configured or player_index < 0 or district_index < 0 or not _is_data_only(session_snapshot) or str(session_snapshot.get("supply_revision", "")).is_empty():
		return {}
	_decision_sequence += 1
	var record := {
		"player_index": player_index,
		"district_index": district_index,
		"state": STATE_ACTIVE,
		"supply_revision": str(session_snapshot.get("supply_revision", "")),
		"selected_card_id": "",
		"selected_supply_revision": "",
		"requires_reselection": false,
		"reserved_card_id": "",
		"active_quote_id": "",
		"active_quote": {},
		"close_reason": "",
		"decision_sequence": _decision_sequence,
		"pending_payload": {},
	}
	_windows_by_player[player_index] = record
	window_opened.emit(player_index, district_index)
	return _safe_window_snapshot(record, true)


func close_window(player_index: int, reason: String = "closed") -> Dictionary:
	var record := active_window(player_index)
	if record.is_empty():
		return {}
	record["state"] = STATE_CLOSED
	record["active_quote_id"] = ""
	record["active_quote"] = {}
	record["close_reason"] = reason
	_windows_by_player[player_index] = record
	window_closed.emit(player_index, int(record.get("district_index", -1)), reason)
	return _safe_window_snapshot(record, true)


func invalidate_window(player_index: int, reason: String = "invalidated") -> Dictionary:
	return close_window(player_index, reason)


func active_window(player_index: int) -> Dictionary:
	return (_windows_by_player.get(player_index, {}) as Dictionary).duplicate(true) if _windows_by_player.get(player_index, {}) is Dictionary else {}


func is_window_active(player_index: int, district_index: int = -1) -> bool:
	var record := active_window(player_index)
	return not record.is_empty() \
		and [STATE_ACTIVE, STATE_PENDING_DISCARD].has(str(record.get("state", STATE_CLOSED))) \
		and (district_index < 0 or int(record.get("district_index", -1)) == district_index)


func attach_quote(player_index: int, district_index: int, quote: Dictionary) -> Dictionary:
	var record := active_window(player_index)
	if not is_window_active(player_index, district_index) or not _is_data_only(quote) or str(quote.get("quote_id", "")).is_empty():
		return {}
	var selected_revision := str(record.get("selected_supply_revision", ""))
	var expected_revision := selected_revision if not selected_revision.is_empty() else str(record.get("supply_revision", ""))
	if int(quote.get("district_index", -1)) != district_index or str(quote.get("supply_revision", "")) != expected_revision:
		return {}
	var selected_card_id := str(record.get("selected_card_id", ""))
	if not selected_card_id.is_empty() and selected_card_id != str(quote.get("card_id", "")):
		return {}
	record["active_quote_id"] = str(quote.get("quote_id", ""))
	record["active_quote"] = quote.duplicate(true)
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func active_quote(player_index: int, district_index: int) -> Dictionary:
	var record := active_window(player_index)
	if not is_window_active(player_index, district_index):
		return {}
	var quote_id := str(record.get("active_quote_id", ""))
	if quote_id.is_empty() or _quote_authority == null or not _quote_authority.has_method("quote_snapshot"):
		return {}
	var value: Variant = _quote_authority.call("quote_snapshot", quote_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func mark_supply_revision(player_index: int, district_index: int, revision: String) -> Dictionary:
	var record := active_window(player_index)
	if not is_window_active(player_index, district_index):
		return {}
	if str(record.get("supply_revision", "")) != revision:
		record["supply_revision"] = revision
		record["requires_reselection"] = true
		record["selected_card_id"] = ""
		record["selected_supply_revision"] = ""
		record["active_quote_id"] = ""
		record["active_quote"] = {}
		_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func acknowledge_card_selection(player_index: int, district_index: int, card_id: String, supply_revision: String) -> Dictionary:
	var record := active_window(player_index)
	if not is_window_active(player_index, district_index) or card_id.is_empty():
		return {}
	if str(record.get("selected_card_id", "")) != card_id or str(record.get("selected_supply_revision", "")) != supply_revision:
		record["active_quote_id"] = ""
		record["active_quote"] = {}
	record["selected_card_id"] = card_id
	record["selected_supply_revision"] = supply_revision
	record["requires_reselection"] = false
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func reserve_pending_discard(request_snapshot: Dictionary) -> Dictionary:
	var player_index := int(request_snapshot.get("player_index", -1))
	var district_index := int(request_snapshot.get("district_index", -1))
	var card_id := str(request_snapshot.get("card_id", ""))
	var record := active_window(player_index)
	if not is_window_active(player_index, district_index) or card_id.is_empty() or str(record.get("active_quote_id", "")).is_empty():
		return {}
	record["state"] = STATE_PENDING_DISCARD
	record["reserved_card_id"] = card_id
	record["pending_payload"] = request_snapshot.duplicate(true)
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func resolve_pending_discard(result_snapshot: Dictionary) -> Dictionary:
	var player_index := int(result_snapshot.get("player_index", -1))
	var record := active_window(player_index)
	if str(record.get("state", "")) != STATE_PENDING_DISCARD:
		return {}
	record["reserved_card_id"] = ""
	record["pending_payload"] = {}
	if bool(result_snapshot.get("close_window", false)):
		record["state"] = STATE_CLOSED
		record["active_quote_id"] = ""
		record["active_quote"] = {}
		record["close_reason"] = str(result_snapshot.get("reason", "discard_resolved"))
	else:
		record["state"] = STATE_ACTIVE
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func pending_discard_private_snapshot(viewer_index: int) -> Dictionary:
	var record := active_window(viewer_index)
	if str(record.get("state", "")) != STATE_PENDING_DISCARD:
		return {}
	var payload: Dictionary = record.get("pending_payload", {}) if record.get("pending_payload", {}) is Dictionary else {}
	return payload.duplicate(true)


func forced_decision_candidates() -> Array:
	var result: Array = []
	for player_variant in _windows_by_player.keys():
		var player_index := int(player_variant)
		var record := active_window(player_index)
		if str(record.get("state", "")) != STATE_PENDING_DISCARD:
			continue
		var sequence := int(record.get("decision_sequence", 0))
		result.append({
			"id": "discard_choice_%d" % sequence,
			"kind": "discard_purchase",
			"priority_group": "other_choice",
			"owner_player_index": player_index,
			"visibility_scope": "private",
			"presentation_surface": "overlay",
			"opened_sequence": float(sequence),
			"blocks_global_time": false,
			"blocks_player_actions": true,
			"blocks_card_resolution": false,
			"source_ref": "discard_purchase",
			"notes": "Private replacement discard; card identity remains owner-only.",
		})
	return result


func to_legacy_save_snapshot(player_index: int) -> Dictionary:
	var record := active_window(player_index)
	if record.is_empty() or not is_window_active(player_index):
		return {}
	var quote_id := str(record.get("active_quote_id", ""))
	var quote_snapshot: Dictionary = {}
	if not quote_id.is_empty() and _quote_authority != null and _quote_authority.has_method("export_quote_for_session"):
		var quote_variant: Variant = _quote_authority.call("export_quote_for_session", quote_id)
		quote_snapshot = (quote_variant as Dictionary).duplicate(true) if quote_variant is Dictionary else {}
	return {
		"schema_version": 2,
		"player_index": player_index,
		"district_index": int(record.get("district_index", -1)),
		"state": str(record.get("state", STATE_ACTIVE)),
		"supply_revision": str(record.get("supply_revision", "")),
		"selected_card_id": str(record.get("selected_card_id", "")),
		"selected_supply_revision": str(record.get("selected_supply_revision", "")),
		"requires_reselection": bool(record.get("requires_reselection", false)),
		"reserved_card_id": str(record.get("reserved_card_id", "")),
		"decision_sequence": int(record.get("decision_sequence", 0)),
		"pending_payload": (record.get("pending_payload", {}) as Dictionary).duplicate(true) if record.get("pending_payload", {}) is Dictionary else {},
		"active_quote": quote_snapshot.duplicate(true),
	}


func apply_legacy_save_snapshot(snapshot: Dictionary, _current_game_time: float = 0.0) -> Dictionary:
	if snapshot.is_empty():
		return {}
	if not _is_data_only(snapshot) or int(snapshot.get("schema_version", 0)) != 2:
		return {"restored": false, "reason": "purchase_session_snapshot_invalid"}
	var player_index := int(snapshot.get("player_index", -1))
	var district_index := int(snapshot.get("district_index", -1))
	if player_index < 0 or district_index < 0:
		return {"restored": false, "reason": "purchase_session_binding_invalid"}
	var restored_state := str(snapshot.get("state", STATE_ACTIVE))
	if restored_state not in [STATE_ACTIVE, STATE_PENDING_DISCARD]:
		return {"restored": false, "reason": "purchase_session_state_invalid"}
	var record := {
		"player_index": player_index,
		"district_index": district_index,
		"state": restored_state,
		"supply_revision": str(snapshot.get("supply_revision", "")),
		"selected_card_id": str(snapshot.get("selected_card_id", "")),
		"selected_supply_revision": str(snapshot.get("selected_supply_revision", "")),
		"requires_reselection": bool(snapshot.get("requires_reselection", false)),
		"reserved_card_id": str(snapshot.get("reserved_card_id", "")),
		"active_quote_id": "",
		"active_quote": {},
		"close_reason": "",
		"decision_sequence": int(snapshot.get("decision_sequence", 0)),
		"pending_payload": (snapshot.get("pending_payload", {}) as Dictionary).duplicate(true) if snapshot.get("pending_payload", {}) is Dictionary else {},
	}
	var quote_snapshot: Dictionary = snapshot.get("active_quote", {}) if snapshot.get("active_quote", {}) is Dictionary else {}
	if not quote_snapshot.is_empty():
		if int(quote_snapshot.get("player_index", -1)) != player_index \
				or int(quote_snapshot.get("district_index", -1)) != district_index \
				or str(quote_snapshot.get("supply_revision", "")) != str(record.get("supply_revision", "")) \
				or (not str(record.get("selected_card_id", "")).is_empty() and str(quote_snapshot.get("card_id", "")) != str(record.get("selected_card_id", ""))):
			return {"restored": false, "reason": "quote_session_binding_invalid"}
		if _quote_authority == null or not _quote_authority.has_method("restore_quote_from_session"):
			return {"restored": false, "reason": "quote_authority_unavailable"}
		var restored_variant: Variant = _quote_authority.call("restore_quote_from_session", quote_snapshot)
		var restored: Dictionary = restored_variant if restored_variant is Dictionary else {}
		if not bool(restored.get("restored", false)):
			record["state"] = STATE_ACTIVE
			record["close_reason"] = str(restored.get("reason", "quote_restore_failed"))
		else:
			record["active_quote_id"] = str(quote_snapshot.get("quote_id", ""))
			record["active_quote"] = (restored.get("quote", {}) as Dictionary).duplicate(true) if restored.get("quote", {}) is Dictionary else {}
	if restored_state == STATE_PENDING_DISCARD:
		if str(record.get("reserved_card_id", "")).is_empty() or str(record.get("active_quote_id", "")).is_empty() or str(record.get("reserved_card_id", "")) != str(quote_snapshot.get("card_id", "")):
			return {"restored": false, "reason": "pending_discard_quote_invalid"}
	_windows_by_player[player_index] = record
	_decision_sequence = maxi(_decision_sequence, int(record.get("decision_sequence", 0)))
	return {"restored": true, "quote_restored": not str(record.get("active_quote_id", "")).is_empty(), "window": _safe_window_snapshot(record, true)}


func to_save_data() -> Dictionary:
	var sessions: Array = []
	var player_indices: Array = _windows_by_player.keys()
	player_indices.sort()
	for player_variant: Variant in player_indices:
		var snapshot := to_legacy_save_snapshot(int(player_variant))
		if not snapshot.is_empty():
			sessions.append(snapshot)
	var candidate := {"district_purchase_runtime": {"schema_version": 2, "sessions": sessions}}
	var preflight := preflight_save_data(candidate)
	return (preflight.get("normalized_state", {}) as Dictionary).duplicate(true) \
			if bool(preflight.get("accepted", false)) else {}


func preflight_save_data(data: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(data) or _contains_forbidden_nested_field(data):
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	var payload: Dictionary = {}
	if _has_exact_keys(data, ROOT_SAVE_FIELDS) and data.get("district_purchase_runtime") is Dictionary:
		payload = data.get("district_purchase_runtime", {}) as Dictionary
	elif _has_exact_keys(data, SAVE_PAYLOAD_FIELDS):
		payload = data
	else:
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	if not _has_exact_keys(payload, SAVE_PAYLOAD_FIELDS) \
			or not (payload.get("schema_version") is int) or int(payload.get("schema_version", 0)) != 2 \
			or not (payload.get("sessions") is Array):
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	var sessions_by_player: Dictionary = {}
	for snapshot_variant in payload.get("sessions", []) as Array:
		if not (snapshot_variant is Dictionary):
			return {"accepted": false, "reason_code": "purchase_session_snapshot_invalid"}
		var session_preflight := _preflight_session(snapshot_variant as Dictionary)
		if not bool(session_preflight.get("accepted", false)):
			return session_preflight
		var normalized_session := session_preflight.get("normalized_state", {}) as Dictionary
		var player_index := int(normalized_session.get("player_index", -1))
		if sessions_by_player.has(player_index):
			return {"accepted": false, "reason_code": "purchase_session_player_duplicate"}
		sessions_by_player[player_index] = normalized_session
	var player_indices: Array = sessions_by_player.keys()
	player_indices.sort()
	var normalized_sessions: Array = []
	for player_index_variant in player_indices:
		normalized_sessions.append((sessions_by_player.get(player_index_variant, {}) as Dictionary).duplicate(true))
	return {
		"accepted": true,
		"reason_code": "purchase_session_save_valid",
		"normalized_state": {"district_purchase_runtime": {"schema_version": 2, "sessions": normalized_sessions}},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var preflight := preflight_save_data(data)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "reason_code": str(preflight.get("reason_code", "purchase_session_save_invalid")), "reason": str(preflight.get("reason_code", "purchase_session_save_invalid")), "rollback_attempted": false, "rollback_complete": true}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	var payload := normalized.get("district_purchase_runtime", {}) as Dictionary
	var checkpoint := capture_runtime_checkpoint()
	reset_state()
	if _quote_authority != null and _quote_authority.has_method("reset_state"):
		_quote_authority.call("reset_state")
	var restored_count := 0
	for snapshot_variant: Variant in payload.get("sessions", []):
		var result := apply_legacy_save_snapshot(snapshot_variant as Dictionary)
		var saved_active_quote := (snapshot_variant as Dictionary).get("active_quote", {}) as Dictionary
		if not bool(result.get("restored", false)) \
				or (not saved_active_quote.is_empty() and not bool(result.get("quote_restored", false))):
			var rollback := restore_runtime_checkpoint(checkpoint)
			return {"applied": false, "session_count": 0, "reason_code": str(result.get("reason", "purchase_session_restore_failed")), "reason": str(result.get("reason", "purchase_session_restore_failed")), "rollback_attempted": true, "rollback_complete": bool(rollback.get("applied", false))}
		restored_count += 1
	return {"applied": true, "session_count": restored_count, "quote_restore_failures": 0, "invalid_session_count": 0, "reason_code": "purchase_sessions_restored", "reason": "purchase_sessions_restored", "rollback_attempted": false, "rollback_complete": true}


func capture_runtime_checkpoint() -> Dictionary:
	var quote_checkpoint: Dictionary = _quote_authority.call("capture_runtime_checkpoint") \
			if _quote_authority != null and _quote_authority.has_method("capture_runtime_checkpoint") else {}
	return {
		"schema_version": 1,
		"windows_by_player": _windows_by_player.duplicate(true),
		"decision_sequence": _decision_sequence,
		"quote_checkpoint": quote_checkpoint.duplicate(true),
		"quote_checkpoint_supported": _quote_authority != null and _quote_authority.has_method("restore_runtime_checkpoint"),
	}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if int(checkpoint.get("schema_version", 0)) != 1 or not (checkpoint.get("windows_by_player") is Dictionary) \
			or not (checkpoint.get("quote_checkpoint") is Dictionary):
		return {"applied": false, "reason_code": "purchase_runtime_checkpoint_invalid"}
	var quote_restored := true
	if bool(checkpoint.get("quote_checkpoint_supported", false)):
		if _quote_authority == null or not _quote_authority.has_method("restore_runtime_checkpoint"):
			quote_restored = false
		else:
			var quote_restore_variant: Variant = _quote_authority.call("restore_runtime_checkpoint", checkpoint.get("quote_checkpoint", {}))
			quote_restored = quote_restore_variant is Dictionary \
					and (bool((quote_restore_variant as Dictionary).get("restored", false)) \
					or bool((quote_restore_variant as Dictionary).get("applied", false)))
	_windows_by_player = (checkpoint.get("windows_by_player", {}) as Dictionary).duplicate(true)
	_decision_sequence = int(checkpoint.get("decision_sequence", 0))
	return {"applied": quote_restored, "reason_code": "purchase_runtime_checkpoint_restored" if quote_restored else "purchase_quote_checkpoint_restore_failed"}


func private_ui_snapshot(viewer_index: int) -> Dictionary:
	var record := active_window(viewer_index)
	var snapshot := _safe_window_snapshot(record, false)
	if not snapshot.is_empty():
		snapshot["quote"] = active_quote(viewer_index, int(record.get("district_index", -1)))
	return snapshot


func debug_snapshot() -> Dictionary:
	var windows: Array = []
	for record_variant: Variant in _windows_by_player.values():
		if record_variant is Dictionary:
			windows.append(_safe_window_snapshot(record_variant as Dictionary, false))
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"session_authority_only": true,
		"pricing_authority": false,
		"access_authority": false,
		"legacy_monster_gate_retired": true,
		"window_count": windows.size(),
		"windows": windows,
	}


func _preflight_session(snapshot: Dictionary) -> Dictionary:
	if not _has_exact_keys(snapshot, SESSION_SAVE_FIELDS) or not _is_data_only(snapshot):
		return {"accepted": false, "reason_code": "purchase_session_snapshot_invalid"}
	if not (snapshot.get("schema_version") is int) or int(snapshot.get("schema_version", 0)) != 2 \
			or not (snapshot.get("player_index") is int) or int(snapshot.get("player_index", -1)) < 0 \
			or not (snapshot.get("district_index") is int) or int(snapshot.get("district_index", -1)) < 0 \
			or not (snapshot.get("decision_sequence") is int) or int(snapshot.get("decision_sequence", -1)) < 0 \
			or not (snapshot.get("requires_reselection") is bool) \
			or not (snapshot.get("pending_payload") is Dictionary) \
			or not (snapshot.get("active_quote") is Dictionary):
		return {"accepted": false, "reason_code": "purchase_session_field_type_invalid"}
	for string_field in [
		"state",
		"supply_revision",
		"selected_card_id",
		"selected_supply_revision",
		"reserved_card_id",
	]:
		if not (snapshot.get(string_field) is String):
			return {"accepted": false, "reason_code": "purchase_session_field_type_invalid"}
	var player_index := int(snapshot.get("player_index", -1))
	var district_index := int(snapshot.get("district_index", -1))
	var state := str(snapshot.get("state", ""))
	var supply_revision := str(snapshot.get("supply_revision", "")).strip_edges()
	var selected_card_id := str(snapshot.get("selected_card_id", "")).strip_edges()
	var selected_supply_revision := str(snapshot.get("selected_supply_revision", "")).strip_edges()
	var reserved_card_id := str(snapshot.get("reserved_card_id", "")).strip_edges()
	var pending_payload := snapshot.get("pending_payload", {}) as Dictionary
	var saved_active_quote := snapshot.get("active_quote", {}) as Dictionary
	if state not in [STATE_ACTIVE, STATE_PENDING_DISCARD] or supply_revision.is_empty():
		return {"accepted": false, "reason_code": "purchase_session_binding_invalid"}
	if selected_card_id.is_empty() != selected_supply_revision.is_empty():
		return {"accepted": false, "reason_code": "purchase_session_selection_invalid"}
	if bool(snapshot.get("requires_reselection", false)) and (not selected_card_id.is_empty() or not selected_supply_revision.is_empty()):
		return {"accepted": false, "reason_code": "purchase_session_selection_invalid"}
	if not saved_active_quote.is_empty():
		if _quote_authority == null or not _quote_authority.has_method("preflight_quote_from_session"):
			return {"accepted": false, "reason_code": "quote_authority_preflight_unavailable"}
		var quote_preflight_variant: Variant = _quote_authority.call("preflight_quote_from_session", saved_active_quote)
		var quote_preflight: Dictionary = quote_preflight_variant if quote_preflight_variant is Dictionary else {}
		if not bool(quote_preflight.get("accepted", false)):
			return {"accepted": false, "reason_code": str(quote_preflight.get("reason_code", "quote_snapshot_invalid"))}
		saved_active_quote = (quote_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
		if int(saved_active_quote.get("player_index", -1)) != player_index \
				or int(saved_active_quote.get("district_index", -1)) != district_index \
				or str(saved_active_quote.get("supply_revision", "")) != supply_revision \
				or (not selected_card_id.is_empty() and str(saved_active_quote.get("card_id", "")) != selected_card_id):
			return {"accepted": false, "reason_code": "quote_session_binding_invalid"}
	if state == STATE_PENDING_DISCARD:
		if reserved_card_id.is_empty() or saved_active_quote.is_empty() \
				or reserved_card_id != str(saved_active_quote.get("card_id", "")) \
				or pending_payload.is_empty() \
				or int(pending_payload.get("player_index", -1)) != player_index \
				or int(pending_payload.get("district_index", -1)) != district_index \
				or str(pending_payload.get("card_id", "")) != reserved_card_id:
			return {"accepted": false, "reason_code": "pending_discard_quote_invalid"}
	elif not reserved_card_id.is_empty() or not pending_payload.is_empty():
		return {"accepted": false, "reason_code": "purchase_session_pending_payload_invalid"}
	var normalized := snapshot.duplicate(true)
	normalized["supply_revision"] = supply_revision
	normalized["selected_card_id"] = selected_card_id
	normalized["selected_supply_revision"] = selected_supply_revision
	normalized["reserved_card_id"] = reserved_card_id
	normalized["active_quote"] = saved_active_quote.duplicate(true)
	return {"accepted": true, "reason_code": "purchase_session_snapshot_valid", "normalized_state": normalized}


func _contains_forbidden_nested_field(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key in FORBIDDEN_NESTED_FIELDS or _contains_forbidden_nested_field((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_nested_field(item_variant):
				return true
	return false


func _has_exact_keys(dictionary: Dictionary, fields: Array) -> bool:
	if dictionary.size() != fields.size():
		return false
	for field_variant in fields:
		if not dictionary.has(str(field_variant)):
			return false
	return true


func _safe_window_snapshot(record: Dictionary, include_quote: bool) -> Dictionary:
	if record.is_empty():
		return {}
	var snapshot := {
		"state": str(record.get("state", STATE_CLOSED)),
		"active": [STATE_ACTIVE, STATE_PENDING_DISCARD].has(str(record.get("state", STATE_CLOSED))),
		"district_index": int(record.get("district_index", -1)),
		"requires_reselection": bool(record.get("requires_reselection", false)),
		"close_reason": str(record.get("close_reason", "")),
	}
	if include_quote:
		snapshot["quote"] = (record.get("active_quote", {}) as Dictionary).duplicate(true) if record.get("active_quote", {}) is Dictionary else {}
	return snapshot


func _is_data_only(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is float and not is_finite(value):
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_data_only(key) or not _is_data_only((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in (value as Array):
			if not _is_data_only(item):
				return false
	return true
