@tool
extends Node
class_name DistrictPurchaseRuntimeController

signal window_opened(player_index: int, district_index: int)
signal window_closed(player_index: int, district_index: int, reason: String)

const STATE_ACTIVE := "active"
const STATE_PENDING_DISCARD := "pending_discard"
const STATE_CLOSED := "closed"

var _configured := false
var _quote_authority: Node
var _windows_by_player: Dictionary = {}


func set_quote_authority(authority: Node) -> void:
	_quote_authority = authority


func configure(_timing_rules: Dictionary = {}) -> void:
	_configured = _quote_authority != null \
		and _quote_authority.has_method("export_quote_for_session") \
		and _quote_authority.has_method("restore_quote_from_session")


func reset_state() -> void:
	_windows_by_player.clear()


func open_window(player_index: int, district_index: int, session_snapshot: Dictionary = {}) -> Dictionary:
	if not _configured or player_index < 0 or district_index < 0 or not _is_data_only(session_snapshot) or str(session_snapshot.get("supply_revision", "")).is_empty():
		return {}
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
	if int(quote.get("district_index", -1)) != district_index or str(quote.get("supply_revision", "")) != str(record.get("supply_revision", "")):
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
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func resolve_pending_discard(result_snapshot: Dictionary) -> Dictionary:
	var player_index := int(result_snapshot.get("player_index", -1))
	var record := active_window(player_index)
	if str(record.get("state", "")) != STATE_PENDING_DISCARD:
		return {}
	record["reserved_card_id"] = ""
	if bool(result_snapshot.get("close_window", false)):
		record["state"] = STATE_CLOSED
		record["active_quote_id"] = ""
		record["active_quote"] = {}
		record["close_reason"] = str(result_snapshot.get("reason", "discard_resolved"))
	else:
		record["state"] = STATE_ACTIVE
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


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
	return {"restored": true, "quote_restored": not str(record.get("active_quote_id", "")).is_empty(), "window": _safe_window_snapshot(record, true)}


func to_save_data() -> Dictionary:
	var sessions: Array = []
	for player_variant: Variant in _windows_by_player.keys():
		var snapshot := to_legacy_save_snapshot(int(player_variant))
		if not snapshot.is_empty():
			sessions.append(snapshot)
	return {"district_purchase_runtime": {"schema_version": 2, "sessions": sessions}}


func apply_save_data(data: Dictionary) -> Dictionary:
	var payload: Dictionary = data.get("district_purchase_runtime", data) if data.get("district_purchase_runtime", data) is Dictionary else {}
	if payload.is_empty():
		reset_state()
		return {"applied": true, "session_count": 0}
	if not _is_data_only(payload) or int(payload.get("schema_version", 0)) != 2 or not (payload.get("sessions", []) is Array):
		return {"applied": false, "reason": "purchase_session_save_invalid"}
	reset_state()
	var restored_count := 0
	var quote_restore_failures := 0
	var invalid_session_count := 0
	for snapshot_variant: Variant in payload.get("sessions", []):
		if not (snapshot_variant is Dictionary):
			invalid_session_count += 1
			continue
		var result := apply_legacy_save_snapshot(snapshot_variant as Dictionary)
		if bool(result.get("restored", false)):
			restored_count += 1
			var active_quote_variant: Variant = (snapshot_variant as Dictionary).get("active_quote", {})
			if not bool(result.get("quote_restored", false)) and active_quote_variant is Dictionary and not (active_quote_variant as Dictionary).is_empty():
				quote_restore_failures += 1
		else:
			invalid_session_count += 1
	if quote_restore_failures > 0 or invalid_session_count > 0:
		reset_state()
		return {"applied": false, "session_count": 0, "quote_restore_failures": quote_restore_failures, "invalid_session_count": invalid_session_count, "reason": "quote_restore_failed" if quote_restore_failures > 0 else "purchase_session_restore_failed"}
	return {"applied": true, "session_count": restored_count, "quote_restore_failures": 0, "invalid_session_count": 0, "reason": "purchase_sessions_restored"}


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
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_data_only(key) or not _is_data_only((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in (value as Array):
			if not _is_data_only(item):
				return false
	return true
