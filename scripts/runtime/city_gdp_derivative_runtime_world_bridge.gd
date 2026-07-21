@tool
extends Node
class_name CityGdpDerivativeRuntimeWorldBridge

var _world: Node
var _world_session_state: WorldSessionState
var _cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort
var _world_call_count := 0
var _failed_world_call_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func set_cash_commitment_query_port(port: MonsterWagerCashCommitmentQueryPort) -> void:
	_cash_commitment_query_port = port


func world_session_state() -> WorldSessionState:
	return _world_session_state


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func world_snapshot() -> Dictionary:
	if not has_world():
		return {}
	var districts_variant: Variant = _world_session_state.districts if _world_session_state != null else []
	return {
		"game_time": _world_session_state.game_time if _world_session_state != null else 0.0,
		"district_count": (districts_variant as Array).size() if districts_variant is Array else 0,
	}


func city_snapshot(district_index: int) -> Dictionary:
	if not has_world():
		return {}
	var districts_variant: Variant = _world_session_state.districts if _world_session_state != null else []
	if not (districts_variant is Array):
		return {}
	var districts := districts_variant as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return {}
	var district := districts[district_index] as Dictionary
	var city_variant: Variant = district.get("city", {})
	return (city_variant as Dictionary).duplicate(true) if city_variant is Dictionary else {}


func city_gdp(district_index: int) -> int:
	if not has_world() or not _world.has_method("_city_cycle_income") or not _world.has_method("_city_competition_matches"):
		return 0
	var competition := int(_world.call("_city_competition_matches", district_index))
	return int(_world.call("_city_cycle_income", district_index, competition))


func district_name(district_index: int) -> String:
	if not has_world():
		return "城市"
	var districts_variant: Variant = _world_session_state.districts if _world_session_state != null else []
	if not (districts_variant is Array):
		return "城市"
	var districts := districts_variant as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return "城市"
	return str((districts[district_index] as Dictionary).get("name", "城市"))


func player_cash(player_index: int) -> int:
	if not has_world():
		return -1
	var players_variant: Variant = _world_session_state.players if _world_session_state != null else []
	if not (players_variant is Array):
		return -1
	var players := players_variant as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return -1
	if _cash_commitment_query_port != null:
		return _cash_commitment_query_port.available_cash_units(player_index)
	return int((players[player_index] as Dictionary).get("cash", 0))


func commit_player_cash_delta(player_index: int, cash_delta: int, card_id: String, district_index: int, reason_code: String, income_amount := 0) -> Dictionary:
	if cash_delta < 0 and _cash_commitment_query_port != null:
		var authorization := _cash_commitment_query_port.authorize_debit_units(player_index, -cash_delta)
		if not bool(authorization.get("authorized", false)):
			return {
				"committed": false,
				"reason": str(authorization.get("reason_code", "cash_reserved_for_monster_wager")),
				"cash_before": player_cash(player_index),
				"cash_required": -cash_delta,
			}
	var before_cash := _world_session_state.private_player_cash_snapshot(player_index) if _world_session_state != null else {}
	var value: Variant = call_world("_commit_city_gdp_derivative_cash_delta", [player_index, cash_delta, card_id, district_index, reason_code, maxi(0, income_amount)])
	var receipt := (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "cash_adapter_missing"}
	if bool(receipt.get("committed", false)) and _world_session_state != null:
		var reconciliation := _world_session_state.reconcile_private_player_cash_after_unit_mutation(player_index, before_cash)
		if not bool(reconciliation.get("reconciled", false)):
			return {"committed": false, "reason": str(reconciliation.get("reason_code", "cash_reconciliation_failed"))}
	return receipt


func append_public_clue(district_index: int, clue: String) -> bool:
	return bool(call_world("_append_city_gdp_derivative_public_clue", [district_index, clue]))


func present_open(position: Dictionary) -> void:
	call_world("_present_city_gdp_derivative_opened", [position.duplicate(true)])


func present_settlement(district_index: int, reason: String, public_receipts: Array) -> void:
	call_world("_present_city_gdp_derivative_settlement", [district_index, reason, public_receipts.duplicate(true)])


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		_failed_world_call_count += 1
		push_error("CityGdpDerivativeRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	_world_call_count += 1
	return _world.callv(method_name, arguments)


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"world_session_state_ready": _world_session_state != null,
		"cash_adapter_available": has_world() and _world.has_method("_commit_city_gdp_derivative_cash_delta"),
		"monster_wager_cash_commitment_guard_bound": _cash_commitment_query_port != null,
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"owns_derivative_state": false,
		"owns_derivative_rules": false,
	}
