@tool
extends Node
class_name PlayerManaRuntimeController

const RULESET_ID := "v0.6"
const STATE_VERSION := 1
const MILLIASSET_SCALE := 1000
const ASSET_IDS := ["life", "energy", "industry", "technology", "commerce", "shipping"]

var _configured := false
var _currency_scale := 100
var _pool_maximum_milliunits := 100 * MILLIASSET_SCALE
var _gdp_per_minute_divisor := 100
var _pools_by_player: Dictionary = {}
var _recovery_remainders_by_player: Dictionary = {}
var _reservations: Dictionary = {}
var _terminal_receipts: Dictionary = {}
var _current_game_time := 0.0
var _revision := 0
var _plan_count := 0
var _commit_count := 0
var _consume_count := 0
var _release_count := 0
var _last_reason := ""


func configure(profile_snapshot: Dictionary) -> Dictionary:
	var identity := _dictionary(profile_snapshot.get("identity", {}))
	var mana := _dictionary(profile_snapshot.get("mana", {}))
	var capabilities := _dictionary(profile_snapshot.get("capabilities", {}))
	_currency_scale = maxi(1, int(identity.get("currency_scale", 100)))
	_pool_maximum_milliunits = maxi(1, int(mana.get("per_color_maximum", 100))) * MILLIASSET_SCALE
	_gdp_per_minute_divisor = maxi(1, int(mana.get("gdp_per_minute_divisor", 100)))
	_configured = str(identity.get("ruleset_id", "")) == RULESET_ID \
		and bool(capabilities.get("six_color_mana_enabled", false)) \
		and not bool(capabilities.get("industry_capacity_reservations_enabled", true))
	reset_state()
	if not _configured:
		push_error("PlayerManaRuntimeController requires the v0.6 six-color asset profile.")
	return {
		"configured": _configured,
		"ruleset_id": RULESET_ID,
		"asset_ids": ASSET_IDS.duplicate(),
		"per_color_maximum": floori(float(_pool_maximum_milliunits) / float(MILLIASSET_SCALE)),
		"gdp_per_minute_divisor": _gdp_per_minute_divisor,
	}


func reset_state(player_count: int = 0) -> void:
	_pools_by_player.clear()
	_recovery_remainders_by_player.clear()
	_reservations.clear()
	_terminal_receipts.clear()
	_current_game_time = 0.0
	_revision += 1
	_plan_count = 0
	_commit_count = 0
	_consume_count = 0
	_release_count = 0
	_last_reason = ""
	for player_index in range(maxi(0, player_count)):
		_ensure_player(player_index)


func advance(delta_milliseconds: int, game_time: float, color_gdp_by_player: Dictionary) -> Dictionary:
	if not _configured or delta_milliseconds <= 0 or not _is_pure_data(color_gdp_by_player):
		return {"advanced": false, "reason": "invalid_asset_recovery_request"}
	var player_keys: Array = color_gdp_by_player.keys()
	player_keys.sort_custom(func(left: Variant, right: Variant) -> bool: return int(left) < int(right))
	var gained_by_player: Dictionary = {}
	for player_key_variant in player_keys:
		var player_index := int(player_key_variant)
		if player_index < 0:
			continue
		_ensure_player(player_index)
		var flow_snapshot_variant: Variant = color_gdp_by_player.get(player_key_variant, {})
		var flow_snapshot := _dictionary(flow_snapshot_variant)
		var colors := _dictionary(flow_snapshot.get("colors", flow_snapshot))
		var pools := _dictionary(_pools_by_player.get(str(player_index), {}))
		var remainders := _dictionary(_recovery_remainders_by_player.get(str(player_index), {}))
		var gained_row := _empty_asset_values()
		for asset_id_variant in ASSET_IDS:
			var asset_id := str(asset_id_variant)
			var color_row := _dictionary(colors.get(asset_id, {}))
			var gdp_per_minute := maxi(0, int(color_row.get("gdp_per_minute", 0)))
			if not color_row.has("gdp_per_minute") and color_row.has("gdp_per_minute_cents"):
				gdp_per_minute = maxi(0, int(round(float(int(color_row.get("gdp_per_minute_cents", 0))) / float(_currency_scale))))
			var numerator := gdp_per_minute * delta_milliseconds + int(remainders.get(asset_id, 0))
			var gained_milliunits := floori(float(numerator) / float(_gdp_per_minute_divisor))
			remainders[asset_id] = numerator - gained_milliunits * _gdp_per_minute_divisor
			var previous := maxi(0, int(pools.get(asset_id, 0)))
			var next_value := mini(_pool_maximum_milliunits, previous + gained_milliunits)
			pools[asset_id] = next_value
			gained_row[asset_id] = next_value - previous
		_pools_by_player[str(player_index)] = pools
		_recovery_remainders_by_player[str(player_index)] = remainders
		gained_by_player[str(player_index)] = gained_row
	_current_game_time = maxf(_current_game_time, game_time)
	_revision += 1
	_last_reason = ""
	return {
		"advanced": true,
		"reason": "",
		"delta_milliseconds": delta_milliseconds,
		"game_time": _current_game_time,
		"gained_milliunits_by_player": gained_by_player,
		"revision": _revision,
	}


func availability_snapshot(player_index: int) -> Dictionary:
	if not _configured or player_index < 0:
		return {"valid": false, "reason": "invalid_player", "player_index": player_index}
	_ensure_player(player_index)
	var pools := _dictionary(_pools_by_player.get(str(player_index), {}))
	var reserved := _reserved_milliunits_for_player(player_index)
	var available_milliunits := _empty_asset_values()
	var available_assets := _empty_asset_values()
	var balances: Dictionary = {}
	for asset_id_variant in ASSET_IDS:
		var asset_id := str(asset_id_variant)
		var balance := maxi(0, int(pools.get(asset_id, 0)))
		var reserved_value := maxi(0, int(reserved.get(asset_id, 0)))
		var available := maxi(0, balance - reserved_value)
		available_milliunits[asset_id] = available
		available_assets[asset_id] = floori(float(available) / float(MILLIASSET_SCALE))
		balances[asset_id] = {
			"balance_milliunits": balance,
			"reserved_milliunits": reserved_value,
			"available_milliunits": available,
			"available_assets": int(available_assets[asset_id]),
		}
	return {
		"valid": true,
		"ruleset_id": RULESET_ID,
		"player_index": player_index,
		"asset_term": "six_color_assets",
		"assets": available_assets,
		"available_milliunits": available_milliunits,
		"balances": balances,
		"per_color_maximum": floori(float(_pool_maximum_milliunits) / float(MILLIASSET_SCALE)),
		"revision": _revision,
	}


func plan_reservation(request: Dictionary) -> Dictionary:
	_plan_count += 1
	if not _configured or not _is_pure_data(request):
		return _plan_rejection("invalid_asset_reservation_request")
	var player_index := int(request.get("player_index", -1))
	if player_index < 0:
		return _plan_rejection("invalid_player")
	_ensure_player(player_index)
	var normalized_cost := _normalize_cost(request.get("asset_cost", {}))
	if not bool(normalized_cost.get("valid", false)):
		return _plan_rejection(str(normalized_cost.get("reason", "invalid_asset_cost")))
	var cost := _dictionary(normalized_cost.get("cost", {}))
	var required := _asset_total(cost) > 0
	var transaction_id := str(request.get("transaction_id", "")).strip_edges()
	if required and transaction_id.is_empty():
		return _plan_rejection("asset_transaction_id_missing")
	if required and (_reservations.has(transaction_id) or _terminal_receipts.has(transaction_id)):
		return _plan_rejection("asset_transaction_duplicate")
	var availability := availability_snapshot(player_index)
	var preferred := _dictionary(request.get("generic_asset_allocation", {}))
	var payment := _plan_payment(_dictionary(availability.get("available_milliunits", {})), cost, preferred)
	if not bool(payment.get("accepted", false)):
		return _plan_rejection(str(payment.get("reason", "asset_insufficient")), payment)
	return {
		"accepted": true,
		"reason": "",
		"required": required,
		"transaction_id": transaction_id if required else "",
		"player_index": player_index,
		"asset_cost": cost,
		"asset_debit": _dictionary(payment.get("asset_debit", {})),
		"debit_milliunits": _dictionary(payment.get("debit_milliunits", {})),
		"expected_revision": _revision,
	}


func commit_reservation(plan: Dictionary) -> Dictionary:
	if not _configured or not _is_pure_data(plan) or not bool(plan.get("accepted", false)):
		return _commit_rejection("invalid_asset_reservation_plan")
	if not bool(plan.get("required", false)):
		return {"committed": true, "authorized": true, "required": false, "transaction_id": "", "duplicate": false}
	var transaction_id := str(plan.get("transaction_id", ""))
	if _terminal_receipts.has(transaction_id):
		var terminal := _dictionary(_terminal_receipts[transaction_id])
		terminal["duplicate"] = true
		return terminal
	if _reservations.has(transaction_id):
		var existing := _dictionary(_reservations[transaction_id])
		return {
			"committed": true,
			"authorized": true,
			"required": true,
			"transaction_id": transaction_id,
			"duplicate": true,
			"reservation": existing,
		}
	var player_index := int(plan.get("player_index", -1))
	var availability := availability_snapshot(player_index)
	var available := _dictionary(availability.get("available_milliunits", {}))
	var debit := _dictionary(plan.get("debit_milliunits", {}))
	for asset_id_variant in ASSET_IDS:
		var asset_id := str(asset_id_variant)
		if maxi(0, int(debit.get(asset_id, 0))) > maxi(0, int(available.get(asset_id, 0))):
			return _commit_rejection("asset_revision_drift", {"asset_id": asset_id})
	var reservation := {
		"transaction_id": transaction_id,
		"player_index": player_index,
		"asset_cost": _dictionary(plan.get("asset_cost", {})),
		"asset_debit": _dictionary(plan.get("asset_debit", {})),
		"debit_milliunits": debit,
		"reserved_at": _current_game_time,
		"state": "reserved",
	}
	_reservations[transaction_id] = reservation
	_revision += 1
	_commit_count += 1
	_last_reason = ""
	return {
		"committed": true,
		"authorized": true,
		"required": true,
		"transaction_id": transaction_id,
		"duplicate": false,
		"reservation": reservation.duplicate(true),
		"revision": _revision,
	}


func consume_reservation(transaction_id: String, effect_receipt: Dictionary) -> Dictionary:
	if not _configured or transaction_id.is_empty() or not _is_pure_data(effect_receipt):
		return _settlement_rejection("invalid_asset_consume_request", transaction_id)
	if _terminal_receipts.has(transaction_id):
		var terminal := _dictionary(_terminal_receipts[transaction_id])
		terminal["duplicate"] = true
		return terminal
	if not bool(effect_receipt.get("resolved", effect_receipt.get("committed", effect_receipt.get("success", false)))):
		return _settlement_rejection("effect_not_resolved", transaction_id)
	if not _reservations.has(transaction_id):
		return _settlement_rejection("asset_reservation_missing", transaction_id)
	var reservation := _dictionary(_reservations[transaction_id])
	var player_index := int(reservation.get("player_index", -1))
	var pools := _dictionary(_pools_by_player.get(str(player_index), {}))
	var debit := _dictionary(reservation.get("debit_milliunits", {}))
	for asset_id_variant in ASSET_IDS:
		var asset_id := str(asset_id_variant)
		if int(pools.get(asset_id, 0)) < maxi(0, int(debit.get(asset_id, 0))):
			return _settlement_rejection("reserved_asset_balance_missing", transaction_id)
	for asset_id_variant in ASSET_IDS:
		var asset_id := str(asset_id_variant)
		pools[asset_id] = int(pools.get(asset_id, 0)) - maxi(0, int(debit.get(asset_id, 0)))
	_pools_by_player[str(player_index)] = pools
	_reservations.erase(transaction_id)
	var receipt := _terminal_receipt(transaction_id, player_index, "consumed", reservation)
	_terminal_receipts[transaction_id] = receipt
	_revision += 1
	_consume_count += 1
	_last_reason = ""
	receipt["revision"] = _revision
	return receipt


func release_reservation(transaction_id: String, reason: String = "released") -> Dictionary:
	if not _configured or transaction_id.is_empty():
		return _settlement_rejection("invalid_asset_release_request", transaction_id)
	if _terminal_receipts.has(transaction_id):
		var terminal := _dictionary(_terminal_receipts[transaction_id])
		terminal["duplicate"] = true
		return terminal
	if not _reservations.has(transaction_id):
		return _settlement_rejection("asset_reservation_missing", transaction_id)
	var reservation := _dictionary(_reservations[transaction_id])
	var player_index := int(reservation.get("player_index", -1))
	_reservations.erase(transaction_id)
	var receipt := _terminal_receipt(transaction_id, player_index, "released", reservation)
	receipt["reason"] = reason
	_terminal_receipts[transaction_id] = receipt
	_revision += 1
	_release_count += 1
	_last_reason = ""
	receipt["revision"] = _revision
	return receipt


func to_save_data() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"current_game_time": _current_game_time,
		"revision": _revision,
		"pools_by_player": _pools_by_player.duplicate(true),
		"recovery_remainders_by_player": _recovery_remainders_by_player.duplicate(true),
		"reservations": _reservations.duplicate(true),
		"terminal_receipts": _terminal_receipts.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	if not _configured or not _is_pure_data(data):
		return {"applied": false, "reason": "invalid_asset_save_payload"}
	if int(data.get("state_version", -1)) != STATE_VERSION or str(data.get("ruleset_id", "")) != RULESET_ID:
		return {"applied": false, "reason": "asset_save_header_invalid"}
	var saved_revision := int(data.get("revision", -1))
	if saved_revision < 0:
		return {"applied": false, "reason": "asset_save_revision_invalid"}
	var prepared_pools := _normalize_player_rows(data.get("pools_by_player", {}), true)
	var prepared_remainders := _normalize_player_rows(data.get("recovery_remainders_by_player", {}), false)
	if not bool(prepared_pools.get("valid", false)) or not bool(prepared_remainders.get("valid", false)):
		return {"applied": false, "reason": "asset_save_rows_invalid"}
	var reservations := _dictionary(data.get("reservations", {}))
	var terminal_receipts := _dictionary(data.get("terminal_receipts", {}))
	for reservation_variant in reservations.values():
		if not (reservation_variant is Dictionary) or str((reservation_variant as Dictionary).get("state", "")) != "reserved":
			return {"applied": false, "reason": "asset_save_reservation_invalid"}
	_pools_by_player = _dictionary(prepared_pools.get("rows", {}))
	_recovery_remainders_by_player = _dictionary(prepared_remainders.get("rows", {}))
	_reservations = reservations
	_terminal_receipts = terminal_receipts
	_current_game_time = maxf(0.0, float(data.get("current_game_time", 0.0)))
	_revision = saved_revision
	_last_reason = ""
	return {"applied": true, "reason": "", "player_count": _pools_by_player.size(), "reservation_count": _reservations.size(), "revision": _revision}


func private_snapshot(player_index: int) -> Dictionary:
	var snapshot := availability_snapshot(player_index)
	if not bool(snapshot.get("valid", false)):
		return snapshot
	var reservations: Array = []
	for reservation_variant in _reservations.values():
		if reservation_variant is Dictionary and int((reservation_variant as Dictionary).get("player_index", -1)) == player_index:
			reservations.append((reservation_variant as Dictionary).duplicate(true))
	snapshot["reservations"] = reservations
	return snapshot


func public_snapshot() -> Dictionary:
	return {
		"valid": _configured,
		"ruleset_id": RULESET_ID,
		"player_count": _pools_by_player.size(),
		"asset_balances_private": true,
		"reservation_count_hidden": true,
		"revision": _revision,
	}


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"ruleset_id": RULESET_ID,
		"state_version": STATE_VERSION,
		"asset_ids": ASSET_IDS.duplicate(),
		"player_count": _pools_by_player.size(),
		"reservation_count": _reservations.size(),
		"terminal_receipt_count": _terminal_receipts.size(),
		"per_color_maximum": floori(float(_pool_maximum_milliunits) / float(MILLIASSET_SCALE)),
		"gdp_per_minute_divisor": _gdp_per_minute_divisor,
		"plan_count": _plan_count,
		"commit_count": _commit_count,
		"consume_count": _consume_count,
		"release_count": _release_count,
		"revision": _revision,
		"last_reason": _last_reason,
		"commodity_flow_authority": false,
		"queue_authority": false,
		"asset_balance_authority": true,
		"legacy_industry_capacity_fallback_used": false,
	}


func _plan_payment(available_milliunits: Dictionary, cost: Dictionary, preferred: Dictionary) -> Dictionary:
	var remaining := available_milliunits.duplicate(true)
	var debit_milliunits := _empty_asset_values()
	var asset_debit := _empty_asset_values()
	for asset_id_variant in ASSET_IDS:
		var asset_id := str(asset_id_variant)
		var fixed_cost := maxi(0, int(cost.get(asset_id, 0)))
		var fixed_milliunits := fixed_cost * MILLIASSET_SCALE
		if int(remaining.get(asset_id, 0)) < fixed_milliunits:
			return {"accepted": false, "reason": "asset_insufficient", "asset_id": asset_id, "required_assets": fixed_cost, "available_assets": floori(float(int(remaining.get(asset_id, 0))) / float(MILLIASSET_SCALE))}
		remaining[asset_id] = int(remaining.get(asset_id, 0)) - fixed_milliunits
		debit_milliunits[asset_id] = fixed_milliunits
		asset_debit[asset_id] = fixed_cost
	var generic_needed := maxi(0, int(cost.get("generic", 0)))
	if generic_needed <= 0:
		return {"accepted": true, "reason": "", "asset_debit": asset_debit, "debit_milliunits": debit_milliunits}
	var preferred_valid := not preferred.is_empty()
	var preferred_total := 0
	if preferred_valid:
		for key_variant in preferred.keys():
			var asset_id := str(key_variant)
			var amount := int(preferred.get(key_variant, 0))
			if not ASSET_IDS.has(asset_id) or amount < 0 or amount * MILLIASSET_SCALE > int(remaining.get(asset_id, 0)):
				preferred_valid = false
				break
			preferred_total += amount
		preferred_valid = preferred_valid and preferred_total == generic_needed
	if preferred_valid:
		for asset_id_variant in ASSET_IDS:
			var asset_id := str(asset_id_variant)
			var amount := maxi(0, int(preferred.get(asset_id, 0)))
			debit_milliunits[asset_id] = int(debit_milliunits.get(asset_id, 0)) + amount * MILLIASSET_SCALE
			asset_debit[asset_id] = int(asset_debit.get(asset_id, 0)) + amount
		return {"accepted": true, "reason": "", "asset_debit": asset_debit, "debit_milliunits": debit_milliunits, "generic_allocation": preferred.duplicate(true)}
	var ordered_assets := ASSET_IDS.duplicate()
	ordered_assets.sort_custom(func(left: Variant, right: Variant) -> bool:
		var left_value := int(remaining.get(str(left), 0))
		var right_value := int(remaining.get(str(right), 0))
		if left_value != right_value:
			return left_value > right_value
		return ASSET_IDS.find(str(left)) < ASSET_IDS.find(str(right))
	)
	var missing := generic_needed
	for asset_id_variant in ordered_assets:
		var asset_id := str(asset_id_variant)
		var affordable := floori(float(int(remaining.get(asset_id, 0))) / float(MILLIASSET_SCALE))
		var amount := mini(missing, affordable)
		if amount <= 0:
			continue
		debit_milliunits[asset_id] = int(debit_milliunits.get(asset_id, 0)) + amount * MILLIASSET_SCALE
		asset_debit[asset_id] = int(asset_debit.get(asset_id, 0)) + amount
		missing -= amount
		if missing <= 0:
			break
	if missing > 0:
		return {"accepted": false, "reason": "generic_asset_insufficient", "required_assets": generic_needed, "missing_assets": missing}
	return {"accepted": true, "reason": "", "asset_debit": asset_debit, "debit_milliunits": debit_milliunits}


func _normalize_cost(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"valid": false, "reason": "asset_cost_not_dictionary"}
	var source := value as Dictionary
	var cost := _empty_asset_values()
	cost["generic"] = 0
	for key_variant in source.keys():
		var key := str(key_variant)
		if not ASSET_IDS.has(key) and key != "generic":
			return {"valid": false, "reason": "unknown_asset_cost_key"}
		var amount := int(source.get(key_variant, 0))
		if amount < 0:
			return {"valid": false, "reason": "negative_asset_cost"}
		cost[key] = amount
	return {"valid": true, "reason": "", "cost": cost}


func _normalize_player_rows(value: Variant, enforce_pool_cap: bool) -> Dictionary:
	if not (value is Dictionary):
		return {"valid": false, "rows": {}}
	var rows: Dictionary = {}
	for player_key_variant in (value as Dictionary).keys():
		var player_index := int(player_key_variant)
		if player_index < 0 or not ((value as Dictionary)[player_key_variant] is Dictionary):
			return {"valid": false, "rows": {}}
		var source := (value as Dictionary)[player_key_variant] as Dictionary
		var row := _empty_asset_values()
		for asset_id_variant in ASSET_IDS:
			var asset_id := str(asset_id_variant)
			var amount := int(source.get(asset_id, 0))
			if amount < 0 or (enforce_pool_cap and amount > _pool_maximum_milliunits):
				return {"valid": false, "rows": {}}
			row[asset_id] = amount
		rows[str(player_index)] = row
	return {"valid": true, "rows": rows}


func _ensure_player(player_index: int) -> void:
	var key := str(player_index)
	if not _pools_by_player.has(key):
		_pools_by_player[key] = _empty_asset_values()
	if not _recovery_remainders_by_player.has(key):
		_recovery_remainders_by_player[key] = _empty_asset_values()


func _reserved_milliunits_for_player(player_index: int) -> Dictionary:
	var result := _empty_asset_values()
	for reservation_variant in _reservations.values():
		if not (reservation_variant is Dictionary):
			continue
		var reservation := reservation_variant as Dictionary
		if int(reservation.get("player_index", -1)) != player_index:
			continue
		var debit := _dictionary(reservation.get("debit_milliunits", {}))
		for asset_id_variant in ASSET_IDS:
			var asset_id := str(asset_id_variant)
			result[asset_id] = int(result.get(asset_id, 0)) + maxi(0, int(debit.get(asset_id, 0)))
	return result


func _terminal_receipt(transaction_id: String, player_index: int, outcome: String, reservation: Dictionary) -> Dictionary:
	return {
		"committed": true,
		"authorized": true,
		"settled": true,
		"duplicate": false,
		"transaction_id": transaction_id,
		"player_index": player_index,
		"outcome": outcome,
		"asset_debit": _dictionary(reservation.get("asset_debit", {})),
		"debit_milliunits": _dictionary(reservation.get("debit_milliunits", {})),
		"settled_at": _current_game_time,
		"reason": "",
	}


func _plan_rejection(reason: String, details: Dictionary = {}) -> Dictionary:
	_last_reason = reason
	var result := {"accepted": false, "reason": reason, "required": false, "expected_revision": _revision}
	result.merge(details.duplicate(true), false)
	return result


func _commit_rejection(reason: String, details: Dictionary = {}) -> Dictionary:
	_last_reason = reason
	var result := {"committed": false, "authorized": false, "reason": reason, "revision": _revision}
	result.merge(details.duplicate(true), false)
	return result


func _settlement_rejection(reason: String, transaction_id: String) -> Dictionary:
	_last_reason = reason
	return {"committed": false, "settled": false, "reason": reason, "transaction_id": transaction_id, "revision": _revision}


func _asset_total(cost: Dictionary) -> int:
	var total := maxi(0, int(cost.get("generic", 0)))
	for asset_id_variant in ASSET_IDS:
		total += maxi(0, int(cost.get(str(asset_id_variant), 0)))
	return total


func _empty_asset_values() -> Dictionary:
	var result: Dictionary = {}
	for asset_id_variant in ASSET_IDS:
		result[str(asset_id_variant)] = 0
	return result


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
		return true
	return false
