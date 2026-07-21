@tool
extends Node
class_name CityGdpDerivativeRuntimeController

const CONTROLLER_ID := "city_gdp_derivative_runtime_v04"

@export var terms_catalog: CityGdpDerivativeTermsCatalogResource

var positions_by_district: Dictionary = {}
var position_sequence := 0

var _configured := false
var _ruleset_id := ""
var _world_bridge: CityGdpDerivativeRuntimeWorldBridge
var _formula_service: CardEconomyProductRouteFormulaRuntimeService
var _open_count := 0
var _settlement_count := 0
var _legacy_positions_normalized := 0
var _last_receipt: Dictionary = {}


func configure(ruleset_snapshot: Dictionary, formula_service: Node = null) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	_formula_service = formula_service as CardEconomyProductRouteFormulaRuntimeService
	var catalog_report := terms_catalog.validation_report() if terms_catalog != null else {"valid": false, "issues": ["catalog_missing"]}
	_configured = _ruleset_id == "v0.4" and _formula_service != null and bool(catalog_report.get("valid", false))
	if not _configured:
		push_error("City GDP derivative v0.4 terms catalog is required and must contain twelve valid cards: %s" % str(catalog_report.get("issues", [])))


func set_world_bridge(bridge: CityGdpDerivativeRuntimeWorldBridge) -> void:
	_world_bridge = bridge


func reset_state() -> Dictionary:
	positions_by_district = {}
	position_sequence = 0
	_open_count = 0
	_settlement_count = 0
	_legacy_positions_normalized = 0
	_last_receipt = {}
	return runtime_state_snapshot()


func terms_for_card_id(card_id: String) -> Dictionary:
	return terms_catalog.terms_for_card_id(card_id) if terms_catalog != null else {}


func all_terms() -> Array:
	return terms_catalog.all_terms() if terms_catalog != null else []


func skill_with_terms(card_id: String, skill: Dictionary) -> Dictionary:
	if terms_catalog == null:
		push_error("City GDP derivative terms catalog is unavailable: %s" % card_id)
		var failed := skill.duplicate(true)
		failed["gdp_derivative_terms_error"] = "catalog_missing"
		return failed
	return terms_catalog.enrich_skill(card_id, skill)


func derivative_terms(skill: Dictionary) -> Dictionary:
	var supplied: Dictionary = skill.get("gdp_derivative_terms", {}) if skill.get("gdp_derivative_terms", {}) is Dictionary else {}
	var card_id := str(skill.get("name", supplied.get("card_id", "")))
	return terms_for_card_id(card_id) if card_id != "" else {}


func duration_seconds(skill: Dictionary) -> float:
	return maxf(0.0, float(derivative_terms(skill).get("duration_seconds", 0.0)))


func open_position(player_index: int, skill: Dictionary, district_index: int) -> Dictionary:
	var card_id := str(skill.get("name", "城市GDP衍生品"))
	var terms := derivative_terms(skill)
	if not _configured:
		return _receipt(false, "controller_not_configured", card_id, district_index)
	if terms.is_empty() or str(terms.get("card_id", "")) != card_id:
		return _receipt(false, "terms_missing", card_id, district_index)
	if _world_bridge == null or not _world_bridge.has_world():
		return _receipt(false, "world_bridge_missing", card_id, district_index)
	var city := _world_bridge.city_snapshot(district_index)
	if city.is_empty() or not bool(city.get("active", false)):
		return _receipt(false, "city_not_active", card_id, district_index)
	if str(terms.get("target_scope", "any_active_city")) == "owned_active_city" and int(city.get("owner", -1)) != player_index:
		return _receipt(false, "insurance_owner_mismatch", card_id, district_index)
	var baseline_gdp := _world_bridge.city_gdp(district_index)
	var margin_cash := maxi(0, int(terms.get("margin_cash", 0)))
	var cash_before := _world_bridge.player_cash(player_index)
	if cash_before < margin_cash:
		return _receipt(false, "financial_margin_insufficient", card_id, district_index, {"cash_before": cash_before, "cash_required": margin_cash})
	position_sequence += 1
	var position_id := position_sequence
	var cash_transaction_id := "city-gdp:%d:%d:open" % [player_index, position_id]
	var cash_receipt := _world_bridge.commit_player_cash_delta(cash_transaction_id, player_index, -margin_cash, card_id, district_index, "derivative_open", 0)
	if not bool(cash_receipt.get("committed", false)):
		position_sequence -= 1
		return _receipt(false, str(cash_receipt.get("reason", "cash_commit_failed")), card_id, district_index)
	var game_time := float(_world_bridge.world_snapshot().get("game_time", 0.0))
	var position := {
		"position_id": position_id,
		"owner": player_index,
		"card_id": card_id,
		"source": card_id,
		"district_index": district_index,
		"direction": str(terms.get("direction", "up")),
		"insurance": bool(terms.get("insurance", false)),
		"baseline_gdp": baseline_gdp,
		"opened_at": game_time,
		"expires_at": game_time + float(terms.get("duration_seconds", 0.0)),
		"duration_seconds": float(terms.get("duration_seconds", 0.0)),
		"multiplier": float(terms.get("multiplier", 1.0)),
		"destroy_bonus": int(terms.get("destroy_bonus", 0)),
		"locked_margin": margin_cash,
		"maximum_gain": maxi(0, int(terms.get("maximum_gain", 0))),
		"maximum_loss": mini(margin_cash, maxi(0, int(terms.get("maximum_loss", 0)))),
		"terms_version": str(terms.get("terms_version", "v0.4")),
		"settlement_formula_id": str(terms.get("settlement_formula_id", "city_gdp_derivative_v04_settlement")),
		"destruction_formula_id": str(terms.get("destruction_formula_id", "city_gdp_derivative_v04_destruction")),
		"settled": false,
	}
	var positions := _positions_for(district_index)
	positions.append(position)
	positions_by_district[str(district_index)] = positions
	_world_bridge.append_public_clue(district_index, "%s匿名%s本城GDP，基准%d，持仓%s；出资方不公开。" % [card_id, "投保" if bool(terms.get("insurance", false)) else ("买涨" if str(terms.get("direction", "up")) == "up" else "做空"), baseline_gdp, _duration_text(float(terms.get("duration_seconds", 0.0)))])
	_world_bridge.present_open(_sanitize_position(position))
	_open_count += 1
	return _receipt(true, "", card_id, district_index, {
		"position_id": position_id,
		"position": position.duplicate(true),
		"cash_before": cash_before,
		"cash_after": int(cash_receipt.get("cash_after", cash_before - margin_cash)),
		"cash_delta": -margin_cash,
		"locked_margin": margin_cash,
	})


func settle_district(district_index: int, current_gdp: int, source := "实时GDP", force_all := false) -> Dictionary:
	var positions := _positions_for(district_index)
	if positions.is_empty():
		return {"committed": false, "reason": "no_positions", "settled_count": 0, "receipts": []}
	var game_time := float(_world_bridge.world_snapshot().get("game_time", 0.0)) if _world_bridge != null else 0.0
	var remaining: Array = []
	var public_receipts: Array = []
	for position_variant in positions:
		if not (position_variant is Dictionary):
			continue
		var position := (position_variant as Dictionary).duplicate(true)
		if not force_all and game_time < float(position.get("expires_at", game_time)):
			remaining.append(position)
			continue
		var formula_id := str(position.get("settlement_formula_id", "city_gdp_derivative_v04_settlement"))
		var settlement := _formula(formula_id, {"current_gdp": current_gdp, "position": position})
		var receipt := _commit_settlement(district_index, position, settlement, "expiry") if bool(settlement.get("ok", false)) else {"committed": false}
		if bool(receipt.get("committed", false)):
			public_receipts.append(_public_receipt(receipt))
		else:
			remaining.append(position)
	positions_by_district[str(district_index)] = remaining
	if remaining.is_empty():
		positions_by_district.erase(str(district_index))
	if not public_receipts.is_empty() and _world_bridge != null:
		_world_bridge.present_settlement(district_index, source, public_receipts)
	return {"committed": not public_receipts.is_empty(), "reason": "" if not public_receipts.is_empty() else "no_due_positions", "settled_count": public_receipts.size(), "receipts": public_receipts}


func settle_destroyed_city(district_index: int, source: String) -> Dictionary:
	var positions := _positions_for(district_index)
	if positions.is_empty():
		return {"committed": false, "reason": "no_positions", "settled_count": 0, "receipts": []}
	var remaining: Array = []
	var public_receipts: Array = []
	for position_variant in positions:
		if not (position_variant is Dictionary):
			continue
		var position := (position_variant as Dictionary).duplicate(true)
		var formula_id := str(position.get("destruction_formula_id", "city_gdp_derivative_v04_destruction"))
		var settlement := _formula(formula_id, {"position": position})
		var receipt := _commit_settlement(district_index, position, settlement, "city_destroyed") if bool(settlement.get("ok", false)) else {"committed": false}
		if bool(receipt.get("committed", false)):
			public_receipts.append(_public_receipt(receipt))
		else:
			remaining.append(position)
	positions_by_district[str(district_index)] = remaining
	if remaining.is_empty():
		positions_by_district.erase(str(district_index))
	if not public_receipts.is_empty() and _world_bridge != null:
		_world_bridge.present_settlement(district_index, "%s摧毁城市" % source, public_receipts)
	return {"committed": not public_receipts.is_empty(), "reason": "" if not public_receipts.is_empty() else "settlement_failed", "settled_count": public_receipts.size(), "receipts": public_receipts}


func update_timers() -> Dictionary:
	if _world_bridge == null:
		return {"settled_count": 0}
	var total := 0
	for district_key_variant in positions_by_district.keys().duplicate():
		var district_index := int(str(district_key_variant))
		var receipt := settle_district(district_index, _world_bridge.city_gdp(district_index), "持仓到期", false)
		total += int(receipt.get("settled_count", 0))
	return {"settled_count": total}


func positions_for_district(district_index: int, include_private := false) -> Array:
	var result: Array = []
	for position_variant in _positions_for(district_index):
		if position_variant is Dictionary:
			result.append((position_variant as Dictionary).duplicate(true) if include_private else _sanitize_position(position_variant as Dictionary))
	return result


func public_positions_snapshot() -> Dictionary:
	var districts := {}
	for district_key_variant in positions_by_district.keys():
		var district_key := str(district_key_variant)
		var summary := {"position_count": 0, "long_count": 0, "short_count": 0, "insurance_count": 0}
		for position_variant in _positions_for(int(district_key)):
			if not (position_variant is Dictionary): continue
			var position := position_variant as Dictionary
			summary["position_count"] = int(summary["position_count"]) + 1
			if bool(position.get("insurance", false)): summary["insurance_count"] = int(summary["insurance_count"]) + 1
			elif str(position.get("direction", "up")) == "up": summary["long_count"] = int(summary["long_count"]) + 1
			else: summary["short_count"] = int(summary["short_count"]) + 1
		districts[district_key] = summary
	return {"districts": districts, "position_count": _position_count()}


func to_save_data() -> Dictionary:
	return {"positions_by_district": positions_by_district.duplicate(true), "position_sequence": position_sequence}


func apply_save_data(data: Dictionary, legacy_positions_by_district: Dictionary = {}) -> Dictionary:
	positions_by_district = {}
	position_sequence = maxi(0, int(data.get("position_sequence", 0)))
	var source_positions: Dictionary = data.get("positions_by_district", {}) if data.get("positions_by_district", {}) is Dictionary else {}
	if source_positions.is_empty():
		source_positions = legacy_positions_by_district.duplicate(true)
	for district_key_variant in source_positions.keys():
		var district_key := str(district_key_variant)
		var raw_positions: Variant = source_positions.get(district_key_variant, [])
		if not (raw_positions is Array):
			continue
		var normalized: Array = []
		for position_variant in raw_positions as Array:
			if not (position_variant is Dictionary):
				continue
			var position := _normalize_loaded_position(position_variant as Dictionary, int(district_key))
			if not position.is_empty():
				normalized.append(position)
		if not normalized.is_empty():
			positions_by_district[district_key] = normalized
	return runtime_state_snapshot()


func restore_new_session_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if not (checkpoint.get("positions_by_district", {}) is Dictionary):
		return {"restored": false, "reason_code": "city_gdp_new_session_checkpoint_invalid"}
	apply_save_data(checkpoint)
	return {"restored": true, "reason_code": "city_gdp_new_session_checkpoint_restored"}


func runtime_state_snapshot() -> Dictionary:
	return {"positions_by_district": positions_by_district.duplicate(true), "position_sequence": position_sequence}


func debug_snapshot(_viewer_index := -1) -> Dictionary:
	var last_receipt := _last_receipt.duplicate(true)
	last_receipt.erase("player_index")
	return {
		"controller_id": CONTROLLER_ID,
		"ruleset_id": _ruleset_id,
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"position_count": _position_count(),
		"district_count": positions_by_district.size(),
		"position_sequence": position_sequence,
		"open_count": _open_count,
		"settlement_count": _settlement_count,
		"legacy_positions_normalized": _legacy_positions_normalized,
		"last_receipt": last_receipt,
		"public_positions": public_positions_snapshot(),
		"terms_catalog": terms_catalog.validation_report() if terms_catalog != null else {"valid": false},
		"world_bridge_ready": _world_bridge != null and _world_bridge.has_world(),
		"owns_derivative_state": true,
		"owns_derivative_rules": true,
	}


func _commit_settlement(district_index: int, position: Dictionary, settlement: Dictionary, reason: String) -> Dictionary:
	if bool(position.get("settled", false)):
		return _receipt(false, "position_already_settled", str(position.get("card_id", "城市GDP衍生品")), district_index)
	var cash_return := maxi(0, int(settlement.get("cash_return", 0)))
	var gain := maxi(0, int(settlement.get("gain", 0)))
	var player_index := int(position.get("owner", -1))
	var position_id := int(position.get("position_id", -1))
	var cash_transaction_id := "city-gdp:%d:%d:%s" % [player_index, position_id, reason]
	var cash_receipt := _world_bridge.commit_player_cash_delta(cash_transaction_id, player_index, cash_return, str(position.get("card_id", "城市GDP衍生品")), district_index, "derivative_%s" % reason, gain) if _world_bridge != null else {"committed": false, "reason": "world_bridge_missing"}
	if not bool(cash_receipt.get("committed", false)):
		return _receipt(false, str(cash_receipt.get("reason", "cash_commit_failed")), str(position.get("card_id", "城市GDP衍生品")), district_index)
	position["settled"] = true
	_settlement_count += 1
	return _receipt(true, "", str(position.get("card_id", "城市GDP衍生品")), district_index, {
		"position_id": int(position.get("position_id", -1)),
		"player_index": int(position.get("owner", -1)),
		"settlement_reason": reason,
		"direction": str(position.get("direction", "up")),
		"insurance": bool(position.get("insurance", false)),
		"gain": gain,
		"loss": maxi(0, int(settlement.get("loss", 0))),
		"margin_refund": maxi(0, int(settlement.get("margin_refund", 0))),
		"cash_return": cash_return,
		"net_pnl": int(settlement.get("net_pnl", 0)),
		"cash_after": int(cash_receipt.get("cash_after", 0)),
	})


func _normalize_loaded_position(raw_position: Dictionary, district_index: int) -> Dictionary:
	var position := raw_position.duplicate(true)
	var card_id := str(position.get("card_id", position.get("source", "")))
	var terms := terms_for_card_id(card_id)
	if terms.is_empty():
		push_error("Cannot normalize city GDP derivative without authored terms: %s" % card_id)
		return {}
	if not position.has("terms_version"):
		position["terms_version"] = str(terms.get("terms_version", "v0.4"))
		position["locked_margin"] = 0
		position["maximum_loss"] = 0
		position["maximum_gain"] = maxi(0, int(terms.get("maximum_gain", 0)))
		_legacy_positions_normalized += 1
	position["card_id"] = card_id
	position["source"] = card_id
	position["district_index"] = district_index
	position["direction"] = str(position.get("direction", terms.get("direction", "up")))
	position["insurance"] = bool(position.get("insurance", terms.get("insurance", false)))
	position["duration_seconds"] = float(position.get("duration_seconds", terms.get("duration_seconds", 0.0)))
	position["multiplier"] = float(position.get("multiplier", terms.get("multiplier", 1.0)))
	position["destroy_bonus"] = int(position.get("destroy_bonus", terms.get("destroy_bonus", 0)))
	position["settlement_formula_id"] = str(position.get("settlement_formula_id", terms.get("settlement_formula_id", "city_gdp_derivative_v04_settlement")))
	position["destruction_formula_id"] = str(position.get("destruction_formula_id", terms.get("destruction_formula_id", "city_gdp_derivative_v04_destruction")))
	position["settled"] = false
	if not position.has("expires_at"):
		var game_time := float(_world_bridge.world_snapshot().get("game_time", 0.0)) if _world_bridge != null else 0.0
		position["opened_at"] = game_time
		position["expires_at"] = game_time + float(position.get("duration_seconds", 0.0))
	if int(position.get("position_id", 0)) <= 0:
		position_sequence += 1
		position["position_id"] = position_sequence
	else:
		position_sequence = maxi(position_sequence, int(position.get("position_id", 0)))
	return position


func _positions_for(district_index: int) -> Array:
	var value: Variant = positions_by_district.get(str(district_index), [])
	return (value as Array).duplicate(true) if value is Array else []


func _position_count() -> int:
	var count := 0
	for positions_variant in positions_by_district.values():
		if positions_variant is Array:
			count += (positions_variant as Array).size()
	return count


func _formula(formula_id: String, input_snapshot: Dictionary) -> Dictionary:
	if _formula_service == null:
		return {"ok": false, "reason": "formula_service_missing"}
	return _formula_service.calculate(formula_id, input_snapshot)


func _receipt(committed: bool, reason: String, card_id: String, district_index: int, details: Dictionary = {}) -> Dictionary:
	var receipt := {"committed": committed, "reason": reason, "card_id": card_id, "district_index": district_index}
	receipt.merge(details.duplicate(true), true)
	_last_receipt = receipt.duplicate(true)
	return receipt


func _sanitize_position(position: Dictionary) -> Dictionary:
	return {
		"position_id": int(position.get("position_id", -1)),
		"card_id": str(position.get("card_id", "")),
		"district_index": int(position.get("district_index", -1)),
		"direction": str(position.get("direction", "up")),
		"insurance": bool(position.get("insurance", false)),
		"baseline_gdp": int(position.get("baseline_gdp", 0)),
		"duration_seconds": float(position.get("duration_seconds", 0.0)),
		"expires_at": float(position.get("expires_at", 0.0)),
		"maximum_gain": int(position.get("maximum_gain", 0)),
		"maximum_loss": int(position.get("maximum_loss", 0)),
		"terms_version": str(position.get("terms_version", "")),
	}


func _public_receipt(receipt: Dictionary) -> Dictionary:
	return {
		"card_id": str(receipt.get("card_id", "")),
		"district_index": int(receipt.get("district_index", -1)),
		"settlement_reason": str(receipt.get("settlement_reason", "")),
		"direction": str(receipt.get("direction", "")),
		"insurance": bool(receipt.get("insurance", false)),
		"gain": int(receipt.get("gain", 0)),
		"loss": int(receipt.get("loss", 0)),
	}


func _duration_text(seconds: float) -> String:
	var total := maxi(1, int(round(seconds)))
	return "%d秒" % total if total < 60 else ("%d分钟" % int(float(total) / 60.0) if total % 60 == 0 else "%d分%d秒" % [int(float(total) / 60.0), total % 60])
