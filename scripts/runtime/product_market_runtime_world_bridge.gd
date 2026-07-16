@tool
extends Node
class_name ProductMarketRuntimeWorldBridge

signal runtime_event_forwarded(event: Dictionary)

var _world: Node
var _rng_service: RunRngService
var _table_selection_state: TableSelectionState
var _world_call_count := 0
var _failed_world_call_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_rng_service(service: RunRngService) -> void:
	_rng_service = service


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func shared_rng() -> RunRngService:
	return _rng_service


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func world_snapshot() -> Dictionary:
	if not has_world():
		return {}
	var districts_variant: Variant = _world.get("districts")
	var players_variant: Variant = _world.get("players")
	var selection := _table_selection_state
	return {
		"game_time": float(_world.get("game_time")),
		"selected_player": selection.selected_player if selection != null else -1,
		"selected_district": selection.selected_district if selection != null else -1,
		"selected_trade_product": selection.selected_trade_product if selection != null else "",
		"districts": (districts_variant as Array).duplicate(true) if districts_variant is Array else [],
		"player_count": (players_variant as Array).size() if players_variant is Array else 0,
	}


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


func commit_player_cash_delta(player_index: int, cash_delta: int, source: String, product_name: String, reason_code: String, income_amount := 0) -> Dictionary:
	var value: Variant = call_world("_commit_product_market_cash_delta", [player_index, cash_delta, source, product_name, reason_code, maxi(0, income_amount)])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"committed": false, "reason": "cash_adapter_missing"}


func read_world_value(property_name: StringName, default_value: Variant = null) -> Variant:
	if not has_world():
		return default_value
	var value: Variant = _world.get(property_name)
	return default_value if value == null else value


func write_world_value(property_name: StringName, value: Variant) -> bool:
	if not has_world():
		return false
	_world.set(property_name, value)
	return true


func call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		_failed_world_call_count += 1
		push_error("ProductMarketRuntimeWorldBridge cannot route world method: %s" % method_name)
		return null
	_world_call_count += 1
	return _world.callv(method_name, arguments)


func price_model(base_price: int, supply: int, demand: int, disrupted: int, volatility: int, noise: float, growth_multiplier: float, weather_modifier := 0) -> Dictionary:
	var value: Variant = call_world("_balance_product_price_model", [base_price, supply, demand, disrupted, 0, weather_modifier, volatility, noise, growth_multiplier])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func price_step_cap(volatility: int, base_price: int) -> int:
	var value: Variant = call_world("_balance_product_price_step_cap", [volatility, base_price])
	return int(value) if value != null else maxi(1, volatility)


func next_market_interval() -> float:
	var value: Variant = call_world("_roll_timer", ["market"])
	return maxf(0.01, float(value)) if value != null else 8.0


func forward_runtime_event(event: Dictionary) -> void:
	if not _is_pure_data(event):
		push_error("Product market runtime event rejected because it is not pure data.")
		return
	runtime_event_forwarded.emit(event.duplicate(true))
	if has_world() and _world.has_method("_on_product_market_runtime_event"):
		_world.call("_on_product_market_runtime_event", event.duplicate(true))


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"shared_rng_available": shared_rng() != null,
		"table_selection_state_ready": _table_selection_state != null,
		"cash_adapter_available": has_world() and _world.has_method("_commit_product_market_cash_delta"),
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"owns_product_market_state": false,
		"owns_product_market_rules": false,
		"owns_shared_rng": false,
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary):
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	if value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
