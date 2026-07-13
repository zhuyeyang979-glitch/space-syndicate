@tool
extends Node
class_name DistrictPurchaseRuntimeController

signal window_opened(player_index: int, district_index: int)
signal window_closed(player_index: int, district_index: int, reason: String)
signal window_expired(player_index: int, district_index: int)

const STATE_VIEW_ONLY := "view_only"
const STATE_ACTIVE := "active"
const STATE_SUSPENDED := "suspended"
const STATE_PENDING_DISCARD := "pending_discard"
const STATE_EXPIRED := "expired"
const STATE_CLOSED := "closed"
const DEFAULT_PRICE_FLOOR := 0.5
const ACCESS_KINDS := ["landed", "adjacent", "extended", "global"]

var _purchase_window_seconds := 0.0
var _configured := false
var _windows_by_player: Dictionary = {}


func configure(timing_rules: Dictionary) -> void:
	_purchase_window_seconds = maxf(0.0, float(timing_rules.get("purchase_window_seconds", 0.0)))
	_configured = _purchase_window_seconds > 0.0


func reset_state() -> void:
	_windows_by_player.clear()


func build_qualification_snapshot(world_snapshot: Dictionary) -> Dictionary:
	if not _configured or not _is_data_only(world_snapshot):
		return {}
	var district_index := int(world_snapshot.get("district_index", -1))
	var player_index := int(world_snapshot.get("player_index", -1))
	var district_facts: Array = world_snapshot.get("districts", []) if world_snapshot.get("districts", []) is Array else []
	var monster_facts: Array = world_snapshot.get("monsters", []) if world_snapshot.get("monsters", []) is Array else []
	var access_effect: Dictionary = world_snapshot.get("access_effect", {}) if world_snapshot.get("access_effect", {}) is Dictionary else {}
	if district_index < 0 or district_index >= district_facts.size():
		return {"eligible": false, "access_kind": "none", "reason": "invalid_district"}
	var extended_multiplier := maxf(1.0, float(access_effect.get("extended_multiplier", 1.10)))
	var global_multiplier := maxf(1.0, float(access_effect.get("global_multiplier", 1.35)))
	var max_steps := 1 + maxi(0, int(access_effect.get("extra_hops", 0)))
	var nearby_monster_distance := _nearest_monster_distance(district_index, 1, district_facts, monster_facts)
	var nearest_distance := _nearest_monster_distance(district_index, max_steps, district_facts, monster_facts)
	var owned_distance := _nearest_monster_distance(district_index, max_steps, district_facts, monster_facts, player_index) if player_index >= 0 else -1
	var access_kind := "none"
	var base_multiplier := 1.0
	var source_kind := ""
	if nearest_distance >= 0:
		access_kind = "landed" if nearest_distance == 0 else ("adjacent" if nearest_distance == 1 else "extended")
		base_multiplier = 0.8 if nearest_distance == 0 else (1.0 if nearest_distance == 1 else extended_multiplier)
		source_kind = "monster"
	elif bool(access_effect.get("global", false)) and not bool((district_facts[district_index] as Dictionary).get("destroyed", false)):
		access_kind = "global"
		base_multiplier = global_multiplier
		source_kind = "ability"
	var source_bound := false
	if owned_distance >= 0:
		var owned_kind := "landed" if owned_distance == 0 else ("adjacent" if owned_distance == 1 else "extended")
		var owned_base := 0.8 if owned_distance == 0 else (1.0 if owned_distance == 1 else extended_multiplier)
		if access_kind == "none" or maxf(DEFAULT_PRICE_FLOOR, owned_base * 0.8) <= maxf(DEFAULT_PRICE_FLOOR, base_multiplier):
			access_kind = owned_kind
			base_multiplier = owned_base
			source_kind = "monster"
			source_bound = true
	var eligible := ACCESS_KINDS.has(access_kind)
	var channel_multiplier := 0.8 if source_bound else 1.0
	return {
		"eligible": eligible,
		"reason": "" if eligible else "no_purchase_channel",
		"access_kind": access_kind,
		"nearby_monster_distance": nearby_monster_distance,
		"opened_at": float(world_snapshot.get("opened_at", 0.0)),
		"base_access_multiplier": base_multiplier,
		"source_kind": source_kind,
		"source_bound_to_player": source_bound,
		"channel_discount_multiplier": channel_multiplier,
		"additional_multiplier": 1.0,
		"price_floor_multiplier": DEFAULT_PRICE_FLOOR,
		"locked_price_multiplier": maxf(DEFAULT_PRICE_FLOOR, base_multiplier * channel_multiplier),
		"extended_multiplier": extended_multiplier,
		"global_multiplier": global_multiplier,
		"supply_revision": str(world_snapshot.get("supply_revision", "")),
	}


func resolve_access_kind(player_index: int, district_index: int, live_qualification: Dictionary) -> String:
	var record := active_window(player_index)
	if not record.is_empty() and int(record.get("district_index", -1)) == district_index:
		return locked_access_kind(player_index, district_index)
	return str(live_qualification.get("access_kind", "none"))


func resolve_price_multiplier(player_index: int, district_index: int, live_qualification: Dictionary) -> float:
	var locked := locked_price_context(player_index, district_index)
	if not locked.is_empty():
		return maxf(0.01, float(locked.get("locked_price_multiplier", 1.0)))
	return maxf(0.01, float(live_qualification.get("locked_price_multiplier", 1.0)))


func access_text(access_kind: String, price_context: Dictionary = {}) -> String:
	var multiplier := float(price_context.get("locked_price_multiplier", 1.0))
	match access_kind:
		"landed": return "怪兽落地区：可购买，%s" % ("渠道优惠后×%.2f" % multiplier if multiplier < 0.79 else "八折")
		"adjacent": return "怪兽相邻区：可购买，%s" % ("渠道优惠后×%.2f" % multiplier if multiplier < 0.99 else "原价")
		"extended": return "远程补给区：可购买，×%.2f" % multiplier
		"global": return "全局采购区：可购买，×%.2f" % multiplier
	return "不可购买：需要怪兽落地、相邻或补给范围能力"


func open_window(player_index: int, district_index: int, qualification_snapshot: Dictionary) -> Dictionary:
	if not _configured or player_index < 0 or district_index < 0 or not _is_data_only(qualification_snapshot):
		return {}
	var access_kind := str(qualification_snapshot.get("access_kind", "none"))
	var eligible := bool(qualification_snapshot.get("eligible", ACCESS_KINDS.has(access_kind))) and ACCESS_KINDS.has(access_kind)
	var base_multiplier := maxf(0.01, float(qualification_snapshot.get("base_access_multiplier", _base_multiplier_for_access(access_kind, qualification_snapshot))))
	var channel_multiplier := 1.0
	if bool(qualification_snapshot.get("source_bound_to_player", false)) and str(qualification_snapshot.get("source_kind", "monster")) == "monster":
		channel_multiplier = 0.8
	if qualification_snapshot.has("channel_discount_multiplier"):
		channel_multiplier = clampf(float(qualification_snapshot.get("channel_discount_multiplier", channel_multiplier)), 0.01, 1.0)
	var additional_multiplier := maxf(0.01, float(qualification_snapshot.get("additional_multiplier", 1.0)))
	var break_price_floor := bool(qualification_snapshot.get("break_price_floor", false))
	var price_floor := 0.0 if break_price_floor else maxf(DEFAULT_PRICE_FLOOR, float(qualification_snapshot.get("price_floor_multiplier", DEFAULT_PRICE_FLOOR)))
	var locked_multiplier := maxf(price_floor, base_multiplier * channel_multiplier * additional_multiplier)
	var state := STATE_ACTIVE if eligible else STATE_VIEW_ONLY
	var record := {
		"player_index": player_index,
		"district_index": district_index,
		"state": state,
		"eligible": eligible,
		"access_kind": access_kind if eligible else "none",
		"opened_at": float(qualification_snapshot.get("opened_at", 0.0)),
		"duration_seconds": _purchase_window_seconds,
		"remaining_seconds": _purchase_window_seconds if eligible else 0.0,
		"base_access_multiplier": base_multiplier,
		"channel_discount_multiplier": channel_multiplier,
		"additional_multiplier": additional_multiplier,
		"locked_price_multiplier": locked_multiplier,
		"price_floor_multiplier": price_floor,
		"channel_discount_applied": channel_multiplier < 0.999,
		"extended_multiplier": float(qualification_snapshot.get("extended_multiplier", 1.10)),
		"global_multiplier": float(qualification_snapshot.get("global_multiplier", 1.35)),
		"supply_revision": str(qualification_snapshot.get("supply_revision", "")),
		"selected_card_id": "",
		"selected_supply_revision": "",
		"requires_reselection": false,
		"reserved_card_id": "",
		"close_reason": "" if eligible else str(qualification_snapshot.get("reason", "view_only")),
	}
	_windows_by_player[player_index] = record
	window_opened.emit(player_index, district_index)
	return _safe_window_snapshot(record, true)


func close_window(player_index: int, reason: String = "closed") -> Dictionary:
	if not _windows_by_player.has(player_index):
		return {}
	var record: Dictionary = (_windows_by_player[player_index] as Dictionary).duplicate(true)
	record["state"] = STATE_CLOSED
	record["eligible"] = false
	record["remaining_seconds"] = 0.0
	record["close_reason"] = reason
	_windows_by_player[player_index] = record
	window_closed.emit(player_index, int(record.get("district_index", -1)), reason)
	return _safe_window_snapshot(record, true)


func invalidate_window(player_index: int, reason: String = "invalidated") -> Dictionary:
	return close_window(player_index, reason)


func tick_window(delta: float, blocking_snapshot: Dictionary = {}) -> Array:
	var events: Array = []
	if delta <= 0.0 or not _configured:
		return events
	var global_blocked := bool(blocking_snapshot.get("global_blocked", false)) or bool(blocking_snapshot.get("session_paused", false))
	var blocked_players: Array = blocking_snapshot.get("blocked_player_indices", []) if blocking_snapshot.get("blocked_player_indices", []) is Array else []
	for player_variant in _windows_by_player.keys():
		var player_index := int(player_variant)
		var record: Dictionary = (_windows_by_player[player_variant] as Dictionary).duplicate(true)
		var state := str(record.get("state", STATE_CLOSED))
		if state == STATE_PENDING_DISCARD or not [STATE_ACTIVE, STATE_SUSPENDED].has(state):
			continue
		var blocked := global_blocked or blocked_players.has(player_index)
		if blocked:
			record["state"] = STATE_SUSPENDED
			_windows_by_player[player_index] = record
			continue
		record["state"] = STATE_ACTIVE
		var remaining := maxf(0.0, float(record.get("remaining_seconds", 0.0)) - delta)
		record["remaining_seconds"] = remaining
		if remaining <= 0.0:
			record["state"] = STATE_EXPIRED
			record["eligible"] = false
			record["close_reason"] = "expired"
			events.append({"event": "expired", "player_index": player_index, "district_index": int(record.get("district_index", -1))})
			window_expired.emit(player_index, int(record.get("district_index", -1)))
		_windows_by_player[player_index] = record
	return events


func active_window(player_index: int) -> Dictionary:
	if not _windows_by_player.has(player_index):
		return {}
	return (_windows_by_player[player_index] as Dictionary).duplicate(true)


func is_window_active(player_index: int, district_index: int = -1) -> bool:
	var record := active_window(player_index)
	if record.is_empty() or not [STATE_ACTIVE, STATE_SUSPENDED, STATE_PENDING_DISCARD].has(str(record.get("state", ""))):
		return false
	return district_index < 0 or int(record.get("district_index", -1)) == district_index


func remaining_seconds(player_index: int) -> float:
	return maxf(0.0, float(active_window(player_index).get("remaining_seconds", 0.0)))


func locked_access_kind(player_index: int, district_index: int) -> String:
	var record := active_window(player_index)
	if int(record.get("district_index", -1)) != district_index or not is_window_active(player_index, district_index):
		return "none"
	return str(record.get("access_kind", "none"))


func locked_price_context(player_index: int, district_index: int) -> Dictionary:
	var record := active_window(player_index)
	if int(record.get("district_index", -1)) != district_index or not is_window_active(player_index, district_index):
		return {}
	return {
		"access_kind": str(record.get("access_kind", "none")),
		"base_access_multiplier": float(record.get("base_access_multiplier", 1.0)),
		"channel_discount_multiplier": float(record.get("channel_discount_multiplier", 1.0)),
		"additional_multiplier": float(record.get("additional_multiplier", 1.0)),
		"locked_price_multiplier": float(record.get("locked_price_multiplier", 1.0)),
		"price_floor_multiplier": float(record.get("price_floor_multiplier", DEFAULT_PRICE_FLOOR)),
		"channel_discount_applied": bool(record.get("channel_discount_applied", false)),
	}


func authorize_purchase(request_snapshot: Dictionary) -> Dictionary:
	if not _is_data_only(request_snapshot):
		return _authorization(false, "invalid_request", {})
	var player_index := int(request_snapshot.get("player_index", -1))
	var district_index := int(request_snapshot.get("district_index", -1))
	var card_id := str(request_snapshot.get("card_id", ""))
	var record := active_window(player_index)
	if card_id.is_empty() or int(record.get("district_index", -1)) != district_index:
		return _authorization(false, "window_mismatch", {})
	var state := str(record.get("state", STATE_CLOSED))
	var resume_pending := bool(request_snapshot.get("resume_pending_discard", false))
	if state == STATE_PENDING_DISCARD:
		if not resume_pending or str(record.get("reserved_card_id", "")) != card_id:
			return _authorization(false, "pending_discard", {})
	elif state != STATE_ACTIVE:
		return _authorization(false, "window_%s" % state, {})
	if float(record.get("remaining_seconds", 0.0)) <= 0.0:
		return _authorization(false, "expired", {})
	var current_revision := str(request_snapshot.get("supply_revision", record.get("supply_revision", "")))
	if current_revision != str(record.get("supply_revision", "")):
		mark_supply_revision(player_index, district_index, current_revision)
		record = active_window(player_index)
	if bool(record.get("requires_reselection", false)):
		var selected_card := str(record.get("selected_card_id", ""))
		var selected_revision := str(record.get("selected_supply_revision", ""))
		if selected_card != card_id or selected_revision != str(record.get("supply_revision", "")):
			return _authorization(false, "reselection_required", {})
	return _authorization(true, "authorized", locked_price_context(player_index, district_index))


func mark_supply_revision(player_index: int, district_index: int, revision: String) -> Dictionary:
	var record := active_window(player_index)
	if record.is_empty() or int(record.get("district_index", -1)) != district_index:
		return {}
	if str(record.get("supply_revision", "")) != revision:
		record["supply_revision"] = revision
		record["requires_reselection"] = true
		record["selected_card_id"] = ""
		record["selected_supply_revision"] = ""
		_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func acknowledge_card_selection(player_index: int, district_index: int, card_id: String, supply_revision: String) -> Dictionary:
	var record := active_window(player_index)
	if record.is_empty() or int(record.get("district_index", -1)) != district_index or card_id.is_empty():
		return {}
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
	if not is_window_active(player_index, district_index) or card_id.is_empty():
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
	if bool(result_snapshot.get("close_window", false)) or float(record.get("remaining_seconds", 0.0)) <= 0.0:
		record["state"] = STATE_CLOSED
		record["eligible"] = false
		record["close_reason"] = str(result_snapshot.get("reason", "discard_resolved"))
	else:
		record["state"] = STATE_ACTIVE
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func to_legacy_save_snapshot(player_index: int) -> Dictionary:
	var record := active_window(player_index)
	if record.is_empty() or not [STATE_ACTIVE, STATE_SUSPENDED, STATE_PENDING_DISCARD].has(str(record.get("state", ""))):
		return {}
	return {
		"player_index": player_index,
		"district_index": int(record.get("district_index", -1)),
		"access_kind": str(record.get("access_kind", "none")),
		"opened_at": float(record.get("opened_at", 0.0)),
		"extended_multiplier": float(record.get("extended_multiplier", 1.10)),
		"global_multiplier": float(record.get("global_multiplier", 1.35)),
		"remaining_seconds": float(record.get("remaining_seconds", 0.0)),
		"channel_discount_multiplier": float(record.get("channel_discount_multiplier", 1.0)),
		"locked_price_multiplier": float(record.get("locked_price_multiplier", 1.0)),
		"supply_revision": str(record.get("supply_revision", "")),
	}


func apply_legacy_save_snapshot(snapshot: Dictionary, current_game_time: float) -> Dictionary:
	if snapshot.is_empty():
		return {}
	var player_index := int(snapshot.get("player_index", -1))
	var district_index := int(snapshot.get("district_index", -1))
	var access_kind := str(snapshot.get("access_kind", "none"))
	if player_index < 0 or district_index < 0 or not ACCESS_KINDS.has(access_kind):
		return {}
	var opened_at := float(snapshot.get("opened_at", current_game_time))
	var remaining := float(snapshot.get("remaining_seconds", _purchase_window_seconds - maxf(0.0, current_game_time - opened_at)))
	var base_multiplier := _base_multiplier_for_access(access_kind, snapshot)
	var channel_multiplier := clampf(float(snapshot.get("channel_discount_multiplier", 1.0)), 0.01, 1.0)
	var locked_multiplier := maxf(DEFAULT_PRICE_FLOOR, float(snapshot.get("locked_price_multiplier", base_multiplier * channel_multiplier)))
	var record := {
		"player_index": player_index,
		"district_index": district_index,
		"state": STATE_ACTIVE if remaining > 0.0 else STATE_EXPIRED,
		"eligible": remaining > 0.0,
		"access_kind": access_kind,
		"opened_at": opened_at,
		"duration_seconds": _purchase_window_seconds,
		"remaining_seconds": maxf(0.0, remaining),
		"base_access_multiplier": base_multiplier,
		"channel_discount_multiplier": channel_multiplier,
		"additional_multiplier": 1.0,
		"locked_price_multiplier": locked_multiplier,
		"price_floor_multiplier": DEFAULT_PRICE_FLOOR,
		"channel_discount_applied": channel_multiplier < 0.999,
		"extended_multiplier": float(snapshot.get("extended_multiplier", 1.10)),
		"global_multiplier": float(snapshot.get("global_multiplier", 1.35)),
		"supply_revision": str(snapshot.get("supply_revision", "")),
		"selected_card_id": "",
		"selected_supply_revision": "",
		"requires_reselection": false,
		"reserved_card_id": "",
		"close_reason": "" if remaining > 0.0 else "expired_on_load",
	}
	_windows_by_player[player_index] = record
	return _safe_window_snapshot(record, true)


func private_ui_snapshot(viewer_index: int) -> Dictionary:
	if not _windows_by_player.has(viewer_index):
		return {}
	return _safe_window_snapshot(_windows_by_player[viewer_index] as Dictionary, true)


func debug_snapshot() -> Dictionary:
	var windows: Array = []
	for record_variant in _windows_by_player.values():
		if record_variant is Dictionary:
			windows.append(_safe_window_snapshot(record_variant as Dictionary, false))
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"purchase_window_seconds": _purchase_window_seconds,
		"window_count": windows.size(),
		"windows": windows,
	}


func _authorization(authorized: bool, reason: String, price_context: Dictionary) -> Dictionary:
	return {"authorized": authorized, "reason": reason, "price_context": price_context.duplicate(true)}


func _nearest_monster_distance(target_district: int, max_steps: int, district_facts: Array, monster_facts: Array, owner_filter: int = -2) -> int:
	var frontier: Array = []
	var seen: Dictionary = {}
	for monster_variant in monster_facts:
		if not (monster_variant is Dictionary):
			continue
		var monster: Dictionary = monster_variant
		if bool(monster.get("down", false)) or (owner_filter != -2 and int(monster.get("owner", -1)) != owner_filter):
			continue
		var start_district := int(monster.get("district_index", -1))
		if start_district < 0 or start_district >= district_facts.size():
			continue
		if start_district == target_district:
			return 0
		frontier.append({"district_index": start_district, "distance": 0})
		seen[start_district] = true
	var cursor := 0
	while cursor < frontier.size():
		var item: Dictionary = frontier[cursor]
		cursor += 1
		var current_district := int(item.get("district_index", -1))
		var distance := int(item.get("distance", 0))
		if distance >= max_steps:
			continue
		var district: Dictionary = district_facts[current_district] if district_facts[current_district] is Dictionary else {}
		for neighbor_variant in district.get("neighbors", []):
			var neighbor_index := int(neighbor_variant)
			if neighbor_index < 0 or neighbor_index >= district_facts.size() or seen.has(neighbor_index):
				continue
			var next_distance := distance + 1
			if neighbor_index == target_district:
				return next_distance
			seen[neighbor_index] = true
			frontier.append({"district_index": neighbor_index, "distance": next_distance})
	return -1


func _base_multiplier_for_access(access_kind: String, source: Dictionary) -> float:
	match access_kind:
		"landed":
			return 0.8
		"adjacent":
			return 1.0
		"extended":
			return maxf(1.0, float(source.get("extended_multiplier", 1.10)))
		"global":
			return maxf(1.0, float(source.get("global_multiplier", 1.35)))
	return 1.0


func _safe_window_snapshot(record: Dictionary, include_private_discount: bool) -> Dictionary:
	var snapshot := {
		"state": str(record.get("state", STATE_CLOSED)),
		"eligible": bool(record.get("eligible", false)),
		"active": [STATE_ACTIVE, STATE_SUSPENDED, STATE_PENDING_DISCARD].has(str(record.get("state", ""))),
		"district_index": int(record.get("district_index", -1)),
		"access_kind": str(record.get("access_kind", "none")),
		"duration_seconds": float(record.get("duration_seconds", _purchase_window_seconds)),
		"remaining_seconds": float(record.get("remaining_seconds", 0.0)),
		"requires_reselection": bool(record.get("requires_reselection", false)),
		"close_reason": str(record.get("close_reason", "")),
	}
	if include_private_discount:
		snapshot["channel_discount_applied"] = bool(record.get("channel_discount_applied", false))
		snapshot["locked_price_multiplier"] = float(record.get("locked_price_multiplier", 1.0))
	return snapshot


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_data_only(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not _is_data_only(key) or not _is_data_only(value[key]):
				return false
		return true
	return false
