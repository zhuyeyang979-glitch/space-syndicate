@tool
extends Node
class_name DistrictPurchaseRuntimeController

signal window_opened(player_index: int, district_index: int)
signal window_closed(player_index: int, district_index: int, reason: String)

const STATE_ACTIVE := "active"
const STATE_PENDING_DISCARD := "pending_discard"
const STATE_CLOSED := "closed"
const SAVE_SCHEMA_VERSION := 3
const LEGACY_SAVE_SCHEMA_VERSION := 2
const RULESET_ID := "v0.6"
const RUNTIME_CHECKPOINT_VERSION := 2
const RUNTIME_CHECKPOINT_ID := "district_purchase_runtime_checkpoint_v2"
const PLAYER_INDEX_MAP := preload("res://scripts/runtime/canonical_player_index_map_v1.gd")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const ROOT_SAVE_FIELDS := ["district_purchase_runtime"]
const SAVE_PAYLOAD_FIELDS := ["schema_version", "next_quote_sequence", "sessions"]
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
const RUNTIME_CHECKPOINT_FIELDS := [
	"captured",
	"schema_version",
	"checkpoint_id",
	"ruleset_id",
	"captured_player_count",
	"windows_by_player",
	"decision_sequence",
	"quote_checkpoint",
]
const RUNTIME_WINDOW_FIELDS := [
	"player_index",
	"district_index",
	"state",
	"supply_revision",
	"selected_card_id",
	"selected_supply_revision",
	"requires_reselection",
	"reserved_card_id",
	"active_quote_id",
	"active_quote",
	"close_reason",
	"decision_sequence",
	"pending_payload",
]
const PRESENTATION_ONLY_PENDING_FIELDS := ["opened_at"]

var _configured := false
var _quote_authority: Node
var _world_session_state: WorldSessionState
var _windows_by_player: Dictionary = {}
var _decision_sequence := 0


func set_quote_authority(authority: Node) -> void:
	_quote_authority = authority


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func configure(_timing_rules: Dictionary = {}) -> void:
	_configured = _quote_authority != null \
			and _quote_authority.has_method("export_quote_for_session") \
			and _quote_authority.has_method("restore_quote_from_session") \
			and _quote_authority.has_method("capture_allocator_cursor") \
			and _quote_authority.has_method("restore_allocator_cursor")


func reset_state() -> void:
	_windows_by_player.clear()
	_decision_sequence = 0


func open_window(player_index: int, district_index: int, session_snapshot: Dictionary = {}) -> Dictionary:
	var player_count := _runtime_player_count()
	if not _configured or player_index < 0 \
			or (_world_session_state != null and player_count > 0 and player_index >= player_count) \
			or district_index < 0 or not _is_data_only(session_snapshot) \
			or str(session_snapshot.get("supply_revision", "")).is_empty():
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
	var expected_revision := _expected_quote_supply_revision(
		str(record.get("supply_revision", "")),
		str(record.get("selected_supply_revision", ""))
	)
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
	record["pending_payload"] = _authoritative_pending_payload(request_snapshot)
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
		var export_method := "export_quote_for_pending_session" \
				if str(record.get("state", "")) == STATE_PENDING_DISCARD \
				and _quote_authority.has_method("export_quote_for_pending_session") \
				else "export_quote_for_session"
		var quote_variant: Variant = _quote_authority.call(export_method, quote_id)
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
		var expected_quote_revision := _expected_quote_supply_revision(
			str(record.get("supply_revision", "")),
			str(record.get("selected_supply_revision", ""))
		)
		if int(quote_snapshot.get("player_index", -1)) != player_index \
				or int(quote_snapshot.get("district_index", -1)) != district_index \
				or str(quote_snapshot.get("supply_revision", "")) != expected_quote_revision \
				or (not str(record.get("selected_card_id", "")).is_empty() and str(quote_snapshot.get("card_id", "")) != str(record.get("selected_card_id", ""))):
			return {"restored": false, "reason": "quote_session_binding_invalid"}
		if _quote_authority == null or not _quote_authority.has_method("restore_quote_from_session"):
			return {"restored": false, "reason": "quote_authority_unavailable"}
		var restore_method := "restore_pending_quote_from_session" \
				if restored_state == STATE_PENDING_DISCARD \
				and _quote_authority.has_method("restore_pending_quote_from_session") \
				else "restore_quote_from_session"
		var restored_variant: Variant = _quote_authority.call(restore_method, quote_snapshot)
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
	var cursor_variant: Variant = _quote_authority.call("capture_allocator_cursor") \
			if _quote_authority != null and _quote_authority.has_method("capture_allocator_cursor") else {}
	var cursor: Dictionary = cursor_variant if cursor_variant is Dictionary else {}
	if not (cursor.get("next_quote_sequence") is int):
		return {}
	var candidate := {"district_purchase_runtime": {
		"schema_version": SAVE_SCHEMA_VERSION,
		"next_quote_sequence": int(cursor.get("next_quote_sequence", 0)),
		"sessions": sessions,
	}}
	var preflight := preflight_save_data(candidate)
	return (preflight.get("normalized_state", {}) as Dictionary).duplicate(true) \
			if bool(preflight.get("accepted", false)) else {}


func preflight_save_data(data: Dictionary) -> Dictionary:
	if not _configured or not SEMANTIC_WIRE.is_closed_data(data) \
			or not _is_data_only(data) or _contains_forbidden_nested_field(data):
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	var payload: Dictionary = {}
	if _has_exact_keys(data, ROOT_SAVE_FIELDS) and data.get("district_purchase_runtime") is Dictionary:
		payload = data.get("district_purchase_runtime", {}) as Dictionary
	elif data.has("schema_version") and data.has("sessions"):
		payload = data
	else:
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	if not (payload.get("schema_version") is int):
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	if int(payload.get("schema_version", 0)) == LEGACY_SAVE_SCHEMA_VERSION \
			and not payload.has("next_quote_sequence"):
		return {
			"accepted": false,
			"reason_code": "allocator_cursor_missing_requires_backup",
			"requires_backup": true,
		}
	if not _has_exact_keys(payload, SAVE_PAYLOAD_FIELDS) \
			or int(payload.get("schema_version", 0)) != SAVE_SCHEMA_VERSION \
			or not (payload.get("next_quote_sequence") is int) \
			or not (payload.get("sessions") is Array):
		return {"accepted": false, "reason_code": "purchase_session_save_invalid"}
	var next_quote_sequence := int(payload.get("next_quote_sequence", 0))
	if next_quote_sequence < 1:
		return {"accepted": false, "reason_code": "allocator_cursor_invalid"}
	var sessions_by_player: Dictionary = {}
	var maximum_retained_quote_sequence := 0
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
		var active_quote: Dictionary = normalized_session.get("active_quote", {}) \
				if normalized_session.get("active_quote", {}) is Dictionary else {}
		if not active_quote.is_empty():
			maximum_retained_quote_sequence = maxi(
				maximum_retained_quote_sequence,
				_quote_sequence(str(active_quote.get("quote_id", "")))
			)
	if next_quote_sequence <= maximum_retained_quote_sequence:
		return {"accepted": false, "reason_code": "allocator_cursor_regressed"}
	var player_indices: Array = sessions_by_player.keys()
	player_indices.sort()
	var normalized_sessions: Array = []
	for player_index_variant in player_indices:
		normalized_sessions.append((sessions_by_player.get(player_index_variant, {}) as Dictionary).duplicate(true))
	return {
		"accepted": true,
		"reason_code": "purchase_session_save_valid",
		"normalized_state": {"district_purchase_runtime": {
			"schema_version": SAVE_SCHEMA_VERSION,
			"next_quote_sequence": next_quote_sequence,
			"sessions": normalized_sessions,
		}},
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
	var cursor_restore_variant: Variant = _quote_authority.call("restore_allocator_cursor", {
		"schema_version": 1,
		"next_quote_sequence": int(payload.get("next_quote_sequence", 0)),
	}) if _quote_authority != null and _quote_authority.has_method("restore_allocator_cursor") else {}
	var cursor_restore: Dictionary = cursor_restore_variant if cursor_restore_variant is Dictionary else {}
	if not bool(cursor_restore.get("restored", false)):
		var cursor_rollback := restore_runtime_checkpoint(checkpoint)
		return {
			"applied": false,
			"session_count": 0,
			"reason_code": str(cursor_restore.get("reason_code", "allocator_cursor_restore_failed")),
			"reason": str(cursor_restore.get("reason_code", "allocator_cursor_restore_failed")),
			"rollback_attempted": true,
			"rollback_complete": bool(cursor_rollback.get("applied", false)),
		}
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
	var player_count := _runtime_player_count()
	var encoded_windows := PLAYER_INDEX_MAP.encode(_windows_by_player, player_count)
	if not bool(encoded_windows.get("ok", false)) or quote_checkpoint.is_empty():
		return {}
	var checkpoint := {
		"captured": true,
		"schema_version": RUNTIME_CHECKPOINT_VERSION,
		"checkpoint_id": RUNTIME_CHECKPOINT_ID,
		"ruleset_id": RULESET_ID,
		"captured_player_count": player_count,
		"windows_by_player": (encoded_windows.get("value", {}) as Dictionary).duplicate(true),
		"decision_sequence": _decision_sequence,
		"quote_checkpoint": quote_checkpoint.duplicate(true),
	}
	return checkpoint if SEMANTIC_WIRE.is_closed_data(checkpoint) else {}


func restore_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var preflight := _preflight_runtime_checkpoint(checkpoint)
	if not bool(preflight.get("accepted", false)):
		return {"applied": false, "restored": false, "reason_code": "district_purchase_checkpoint_v2_invalid"}
	if _quote_authority == null or not _quote_authority.has_method("capture_runtime_checkpoint") \
			or not _quote_authority.has_method("restore_runtime_checkpoint"):
		return {"applied": false, "restored": false, "reason_code": "district_purchase_checkpoint_v2_invalid"}
	var quote_backup_variant: Variant = _quote_authority.call("capture_runtime_checkpoint")
	var quote_backup: Dictionary = quote_backup_variant if quote_backup_variant is Dictionary else {}
	if quote_backup.is_empty():
		return {"applied": false, "restored": false, "reason_code": "district_purchase_checkpoint_v2_invalid"}
	var normalized := preflight.get("normalized_state", {}) as Dictionary
	var quote_restore_variant: Variant = _quote_authority.call(
		"restore_runtime_checkpoint",
		normalized.get("quote_checkpoint", {}) as Dictionary
	)
	var quote_restore: Dictionary = quote_restore_variant if quote_restore_variant is Dictionary else {}
	if not (bool(quote_restore.get("restored", false)) or bool(quote_restore.get("applied", false))):
		var rollback_variant: Variant = _quote_authority.call("restore_runtime_checkpoint", quote_backup)
		var rollback: Dictionary = rollback_variant if rollback_variant is Dictionary else {}
		return {
			"applied": false,
			"restored": false,
			"reason_code": "district_purchase_quote_checkpoint_restore_failed",
			"rollback_attempted": true,
			"rollback_complete": bool(rollback.get("restored", false)) or bool(rollback.get("applied", false)),
		}
	_windows_by_player = (normalized.get("windows_by_player", {}) as Dictionary).duplicate(true)
	_decision_sequence = int(normalized.get("decision_sequence", 0))
	return {"applied": true, "restored": true, "reason_code": "district_purchase_runtime_checkpoint_v2_restored"}


func _preflight_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not _configured or not _has_exact_keys(checkpoint, RUNTIME_CHECKPOINT_FIELDS) \
			or not SEMANTIC_WIRE.is_closed_data(checkpoint) \
			or not (checkpoint.get("captured") is bool) or not bool(checkpoint.get("captured", false)) \
			or not (checkpoint.get("schema_version") is int) \
			or int(checkpoint.get("schema_version", 0)) != RUNTIME_CHECKPOINT_VERSION \
			or not (checkpoint.get("checkpoint_id") is String) \
			or str(checkpoint.get("checkpoint_id", "")) != RUNTIME_CHECKPOINT_ID \
			or not (checkpoint.get("ruleset_id") is String) \
			or str(checkpoint.get("ruleset_id", "")) != RULESET_ID \
			or not (checkpoint.get("captured_player_count") is int) \
			or not (checkpoint.get("decision_sequence") is int) \
			or not SEMANTIC_WIRE.is_nonnegative_integer(checkpoint.get("decision_sequence")) \
			or not (checkpoint.get("quote_checkpoint") is Dictionary) \
			or not _quote_checkpoint_shape_valid(checkpoint.get("quote_checkpoint", {}) as Dictionary):
		return {"accepted": false, "reason_code": "district_purchase_checkpoint_v2_invalid"}
	var player_count := int(checkpoint.get("captured_player_count", -1))
	var decoded_windows := PLAYER_INDEX_MAP.decode(checkpoint.get("windows_by_player"), player_count)
	if not bool(decoded_windows.get("ok", false)):
		return {"accepted": false, "reason_code": str(decoded_windows.get("reason_code", "district_purchase_checkpoint_v2_invalid"))}
	var windows := decoded_windows.get("value", {}) as Dictionary
	var decision_sequence := int(checkpoint.get("decision_sequence", 0))
	for player_index_variant in windows.keys():
		var player_index := int(player_index_variant)
		if not (windows.get(player_index_variant) is Dictionary) \
				or not _runtime_window_valid(windows.get(player_index_variant, {}) as Dictionary, player_index, decision_sequence):
			return {"accepted": false, "reason_code": "district_purchase_window_record_invalid"}
	return {
		"accepted": true,
		"normalized_state": {
			"windows_by_player": windows.duplicate(true),
			"decision_sequence": decision_sequence,
			"quote_checkpoint": (checkpoint.get("quote_checkpoint", {}) as Dictionary).duplicate(true),
		},
	}


func preflight_runtime_checkpoint(checkpoint: Dictionary) -> Dictionary:
	return _preflight_runtime_checkpoint(checkpoint)


func _runtime_window_valid(record: Dictionary, player_index: int, maximum_decision_sequence: int) -> bool:
	if not _has_exact_keys(record, RUNTIME_WINDOW_FIELDS) \
			or not (record.get("player_index") is int) or int(record.get("player_index", -1)) != player_index \
			or not (record.get("district_index") is int) or int(record.get("district_index", -1)) < 0 \
			or not (record.get("state") is String) \
			or str(record.get("state", "")) not in [STATE_ACTIVE, STATE_PENDING_DISCARD, STATE_CLOSED] \
			or not (record.get("supply_revision") is String) \
			or not (record.get("selected_card_id") is String) \
			or not (record.get("selected_supply_revision") is String) \
			or not (record.get("requires_reselection") is bool) \
			or not (record.get("reserved_card_id") is String) \
			or not (record.get("active_quote_id") is String) \
			or not (record.get("active_quote") is Dictionary) \
			or not (record.get("close_reason") is String) \
			or not (record.get("decision_sequence") is int) \
			or int(record.get("decision_sequence", -1)) < 0 \
			or int(record.get("decision_sequence", -1)) > maximum_decision_sequence \
			or not (record.get("pending_payload") is Dictionary) \
			or _contains_presentation_only_pending_field(record.get("pending_payload", {}) as Dictionary):
		return false
	return true


func _quote_checkpoint_shape_valid(checkpoint: Dictionary) -> bool:
	if not (checkpoint.get("schema_version") is int) or int(checkpoint.get("schema_version", 0)) != 1 \
			or not (checkpoint.get("next_quote_sequence") is int) \
			or int(checkpoint.get("next_quote_sequence", 0)) < 1 \
			or not (checkpoint.get("quotes_by_id") is Dictionary):
		return false
	if checkpoint.has("quotes_by_key") and not (checkpoint.get("quotes_by_key") is Dictionary):
		return false
	for counter_field in ["quote_count", "authorization_count"]:
		if checkpoint.has(counter_field) \
				and (not (checkpoint.get(counter_field) is int) or int(checkpoint.get(counter_field, -1)) < 0):
			return false
	return true


func _runtime_player_count() -> int:
	if _world_session_state != null:
		var players_variant: Variant = _world_session_state.get("players")
		if players_variant is Array:
			var count := (players_variant as Array).size()
			if count >= PLAYER_INDEX_MAP.MIN_ACTIVE_PLAYER_COUNT \
					and count <= PLAYER_INDEX_MAP.MAX_ACTIVE_PLAYER_COUNT:
				return count
	if _windows_by_player.is_empty():
		return 0
	var maximum_index := -1
	for player_index_variant in _windows_by_player.keys():
		if player_index_variant is int:
			maximum_index = maxi(maximum_index, int(player_index_variant))
	return clampi(maximum_index + 1, PLAYER_INDEX_MAP.MIN_ACTIVE_PLAYER_COUNT, PLAYER_INDEX_MAP.MAX_ACTIVE_PLAYER_COUNT)


func _authoritative_pending_payload(request_snapshot: Dictionary) -> Dictionary:
	var result := request_snapshot.duplicate(true)
	for field_variant in PRESENTATION_ONLY_PENDING_FIELDS:
		result.erase(str(field_variant))
	return result


func _contains_presentation_only_pending_field(payload: Dictionary) -> bool:
	for field_variant in PRESENTATION_ONLY_PENDING_FIELDS:
		if payload.has(str(field_variant)):
			return true
	return false


func _quote_sequence(quote_id: String) -> int:
	var separator := quote_id.rfind("-")
	if separator < 0 or separator + 1 >= quote_id.length():
		return -1
	var sequence_text := quote_id.substr(separator + 1)
	return int(sequence_text) if sequence_text.is_valid_int() else -1


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
	if _contains_presentation_only_pending_field(pending_payload):
		return {"accepted": false, "reason_code": "purchase_session_pending_payload_invalid"}
	if state not in [STATE_ACTIVE, STATE_PENDING_DISCARD] or supply_revision.is_empty():
		return {"accepted": false, "reason_code": "purchase_session_binding_invalid"}
	if selected_card_id.is_empty() != selected_supply_revision.is_empty():
		return {"accepted": false, "reason_code": "purchase_session_selection_invalid"}
	if bool(snapshot.get("requires_reselection", false)) and (not selected_card_id.is_empty() or not selected_supply_revision.is_empty()):
		return {"accepted": false, "reason_code": "purchase_session_selection_invalid"}
	if not saved_active_quote.is_empty():
		var expected_quote_revision := _expected_quote_supply_revision(supply_revision, selected_supply_revision)
		if _quote_authority == null or not _quote_authority.has_method("preflight_quote_from_session"):
			return {"accepted": false, "reason_code": "quote_authority_preflight_unavailable"}
		var quote_preflight_variant: Variant = _quote_authority.call("preflight_quote_from_session", saved_active_quote)
		var quote_preflight: Dictionary = quote_preflight_variant if quote_preflight_variant is Dictionary else {}
		if not bool(quote_preflight.get("accepted", false)):
			return {"accepted": false, "reason_code": str(quote_preflight.get("reason_code", "quote_snapshot_invalid"))}
		saved_active_quote = (quote_preflight.get("normalized_state", {}) as Dictionary).duplicate(true)
		if int(saved_active_quote.get("player_index", -1)) != player_index \
				or int(saved_active_quote.get("district_index", -1)) != district_index \
				or str(saved_active_quote.get("supply_revision", "")) != expected_quote_revision \
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


func _expected_quote_supply_revision(supply_revision: String, selected_supply_revision: String) -> String:
	return selected_supply_revision if not selected_supply_revision.is_empty() else supply_revision


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
