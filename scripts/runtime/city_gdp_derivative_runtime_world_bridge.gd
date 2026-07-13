@tool
extends Node
class_name CityGdpDerivativeRuntimeWorldBridge

var _world: Node
var _world_call_count := 0
var _failed_world_call_count := 0


func bind_world(world: Node) -> void:
	_world = world


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func world_snapshot() -> Dictionary:
	if not has_world():
		return {}
	var districts_variant: Variant = _world.get("districts")
	return {
		"game_time": float(_world.get("game_time")),
		"district_count": (districts_variant as Array).size() if districts_variant is Array else 0,
	}


func city_snapshot(district_index: int) -> Dictionary:
	if not has_world():
		return {}
	var districts_variant: Variant = _world.get("districts")
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
	var districts_variant: Variant = _world.get("districts")
	if not (districts_variant is Array):
		return "城市"
	var districts := districts_variant as Array
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return "城市"
	return str((districts[district_index] as Dictionary).get("name", "城市"))


func player_cash(player_index: int) -> int:
	if not has_world():
		return -1
	var players_variant: Variant = _world.get("players")
	if not (players_variant is Array):
		return -1
	var players := players_variant as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return -1
	return int((players[player_index] as Dictionary).get("cash", 0))


func commit_player_cash_delta(player_index: int, cash_delta: int, card_id: String, district_index: int, reason_code: String, income_amount := 0) -> Dictionary:
	var value: Variant = call_world("_commit_city_gdp_derivative_cash_delta", [player_index, cash_delta, card_id, district_index, reason_code, maxi(0, income_amount)])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "cash_adapter_missing"}


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
		"cash_adapter_available": has_world() and _world.has_method("_commit_city_gdp_derivative_cash_delta"),
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"owns_derivative_state": false,
		"owns_derivative_rules": false,
	}
