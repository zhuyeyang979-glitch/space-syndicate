@tool
extends Node
class_name EconomyCashflowRuntimeController

@export_range(0.05, 10.0, 0.05) var tick_interval_seconds := 1.0
@export_range(1.0, 3600.0, 1.0) var basis_seconds := 60.0

var _configured := false
var _realtime_income_enabled := false
var _accumulator_seconds := 0.0
var _last_clock_state := "idle"
var _last_payout_total := 0
var _last_payout_event_count := 0
var _last_private_payouts: Dictionary = {}


func configure(ruleset_snapshot: Dictionary, cadence_config: Dictionary = {}) -> void:
	var capabilities_variant: Variant = ruleset_snapshot.get("capabilities", {})
	var capabilities: Dictionary = capabilities_variant if capabilities_variant is Dictionary else {}
	if not cadence_config.is_empty():
		tick_interval_seconds = maxf(0.05, float(cadence_config.get("tick_interval_seconds", tick_interval_seconds)))
		basis_seconds = maxf(1.0, float(cadence_config.get("basis_seconds", basis_seconds)))
	_realtime_income_enabled = bool(capabilities.get("realtime_income_enabled", false))
	_configured = str(ruleset_snapshot.get("ruleset_id", "")) == "v0.4" and tick_interval_seconds > 0.0 and basis_seconds > 0.0
	_last_clock_state = "ready" if _configured and _realtime_income_enabled else "disabled"


func reset_state() -> void:
	_accumulator_seconds = 0.0
	_last_clock_state = "ready" if _configured and _realtime_income_enabled else "disabled"
	_last_payout_total = 0
	_last_payout_event_count = 0
	_last_private_payouts.clear()


func advance_clock(delta_seconds: float, blocking_snapshot: Dictionary = {}) -> Array:
	var due_ticks: Array = []
	if not _configured or not _realtime_income_enabled or delta_seconds <= 0.0 or not _is_data_only(blocking_snapshot):
		return due_ticks
	if bool(blocking_snapshot.get("game_over", false)) or bool(blocking_snapshot.get("global_blocked", false)) or bool(blocking_snapshot.get("session_paused", false)) or bool(blocking_snapshot.get("time_paused", false)):
		_last_clock_state = "paused"
		return due_ticks
	_last_clock_state = "running"
	_accumulator_seconds += delta_seconds
	while _accumulator_seconds + 0.000001 >= tick_interval_seconds:
		due_ticks.append(tick_interval_seconds)
		_accumulator_seconds = maxf(0.0, _accumulator_seconds - tick_interval_seconds)
	return due_ticks


func settle_sources(seconds: float, income_source_snapshot: Dictionary) -> Dictionary:
	var result := {
		"seconds": maxf(0.0, seconds),
		"payout_total": 0,
		"payout_event_count": 0,
		"payout_events": [],
		"valid": false,
	}
	if not _configured or not _realtime_income_enabled or seconds <= 0.0 or not _is_data_only(income_source_snapshot):
		return result
	var sources_variant: Variant = income_source_snapshot.get("sources", [])
	if not (sources_variant is Array):
		return result
	var events: Array = []
	var payout_total := 0
	var private_payouts: Dictionary = {}
	for source_variant in sources_variant:
		if not (source_variant is Dictionary):
			continue
		var source: Dictionary = source_variant
		if not bool(source.get("eligible", false)):
			continue
		var source_id := str(source.get("source_id", ""))
		var source_kind := str(source.get("source_kind", ""))
		var district_index := int(source.get("district_index", -1))
		var player_index := int(source.get("player_index", -1))
		if source_id.is_empty() or district_index < 0 or player_index < 0 or source_kind != "project_share":
			continue
		var gdp_per_minute := maxi(0, int(source.get("gdp_per_minute", 0)))
		var remainder_before := maxf(0.0, float(source.get("remainder", 0.0)))
		var accrued := remainder_before + float(gdp_per_minute) * seconds / basis_seconds
		var paid_amount := int(floor(accrued))
		var remainder_after := accrued - float(paid_amount)
		var role_bonus_gdp := maxi(0, int(source.get("role_bonus_gdp_per_minute", 0)))
		var role_bonus_basis := maxi(1, int(source.get("role_bonus_basis_gdp_per_minute", gdp_per_minute)))
		var role_paid := mini(paid_amount, int(round(float(paid_amount) * float(role_bonus_gdp) / float(role_bonus_basis)))) if role_bonus_gdp > 0 and paid_amount > 0 else 0
		events.append({
			"source_id": source_id,
			"source_kind": source_kind,
			"district_index": district_index,
			"player_index": player_index,
			"gdp_per_minute": gdp_per_minute,
			"paid_amount": paid_amount,
			"role_paid_amount": role_paid,
			"remainder_before": remainder_before,
			"remainder_after": remainder_after,
		})
		payout_total += paid_amount
		var private_key := str(player_index)
		var private_entry: Dictionary = private_payouts.get(private_key, {"payout_amount": 0, "source_count": 0})
		private_entry["payout_amount"] = int(private_entry.get("payout_amount", 0)) + paid_amount
		private_entry["source_count"] = int(private_entry.get("source_count", 0)) + 1
		private_payouts[private_key] = private_entry
	_last_payout_total = payout_total
	_last_payout_event_count = events.size()
	_last_private_payouts = private_payouts
	result["payout_total"] = payout_total
	result["payout_event_count"] = events.size()
	result["payout_events"] = events
	result["valid"] = true
	return result


func accumulator_seconds() -> float:
	return _accumulator_seconds


func to_legacy_save_snapshot() -> Dictionary:
	return {"economy_cashflow_timer": _accumulator_seconds}


func apply_legacy_save_snapshot(snapshot: Dictionary) -> void:
	_accumulator_seconds = maxf(0.0, float(snapshot.get("economy_cashflow_timer", 0.0))) if _is_data_only(snapshot) else 0.0
	_last_clock_state = "restored" if _configured and _realtime_income_enabled else "disabled"


func private_ui_snapshot(viewer_index: int) -> Dictionary:
	var private_entry: Dictionary = _last_private_payouts.get(str(viewer_index), {})
	return {
		"enabled": _configured and _realtime_income_enabled,
		"clock_state": _last_clock_state,
		"next_tick_seconds": maxf(0.0, tick_interval_seconds - _accumulator_seconds),
		"last_payout_amount": int(private_entry.get("payout_amount", 0)),
		"last_source_count": int(private_entry.get("source_count", 0)),
	}


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured and _realtime_income_enabled,
		"realtime_income_enabled": _realtime_income_enabled,
		"tick_interval_seconds": tick_interval_seconds,
		"basis_seconds": basis_seconds,
		"accumulator_seconds": _accumulator_seconds,
		"clock_state": _last_clock_state,
		"last_payout_total": _last_payout_total,
		"last_payout_event_count": _last_payout_event_count,
	}


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is bool or value is int or value is float:
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
