@tool
extends Node
class_name ProductMarketRuntimeWorldBridge

signal runtime_event_forwarded(event: Dictionary)

var _world: Node
var _rng_service: RunRngService
var _table_selection_state: TableSelectionState
var _world_session_state: WorldSessionState
var _cash_commitment_query_port: MonsterWagerCashCommitmentQueryPort
var _cash_mutation_port: PlayerCashMutationPort
var _world_call_count := 0
var _failed_world_call_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_rng_service(service: RunRngService) -> void:
	_rng_service = service


func set_table_selection_state(state: TableSelectionState) -> void:
	_table_selection_state = state


func set_world_session_state(state: WorldSessionState) -> void:
	_world_session_state = state


func set_cash_commitment_query_port(port: MonsterWagerCashCommitmentQueryPort) -> void:
	_cash_commitment_query_port = port


func set_cash_mutation_port(port: PlayerCashMutationPort) -> void:
	_cash_mutation_port = port


func world_session_state() -> WorldSessionState:
	return _world_session_state


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func shared_rng() -> RunRngService:
	return _rng_service


func table_selection_state() -> TableSelectionState:
	return _table_selection_state


func world_snapshot() -> Dictionary:
	if _world_session_state == null:
		return {}
	var districts_variant: Variant = _world_session_state.districts
	var players_variant: Variant = _world_session_state.players
	var selection := _table_selection_state
	return {
		"game_time": _world_session_state.game_time,
		"selected_player": selection.selected_player if selection != null else -1,
		"selected_district": selection.selected_district if selection != null else -1,
		"selected_trade_product": selection.selected_trade_product if selection != null else "",
		"districts": (districts_variant as Array).duplicate(true) if districts_variant is Array else [],
		"player_count": (players_variant as Array).size() if players_variant is Array else 0,
	}


func player_cash(player_index: int) -> int:
	var players_variant: Variant = _world_session_state.players if _world_session_state != null else []
	if not (players_variant is Array):
		return -1
	var players := players_variant as Array
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return -1
	if _cash_commitment_query_port != null:
		return _cash_commitment_query_port.available_cash_units(player_index)
	return int((players[player_index] as Dictionary).get("cash", 0))


func commit_player_cash_delta(transaction_id: String, player_index: int, cash_delta: int, source: String, product_name: String, reason_code: String, income_amount := 0, market_cycle := 0) -> Dictionary:
	if _cash_mutation_port == null or not _cash_mutation_port.is_ready():
		return {"committed": false, "reason": "player_cash_mutation_port_unavailable"}
	return _cash_mutation_port.commit_product_market_cash_delta(
		transaction_id,
		player_index,
		cash_delta,
		source,
		product_name,
		reason_code,
		maxi(0, income_amount),
		maxi(0, market_cycle)
	)


func cash_mutation_ready() -> bool:
	return _cash_mutation_port != null and _cash_mutation_port.is_ready()


func append_ai_business_public_clue(public_receipt: Dictionary) -> Dictionary:
	if _world_session_state == null or not _is_pure_data(public_receipt):
		return {"applied": false, "reason_code": "ai_business_public_clue_owner_missing"}
	if str(public_receipt.get("visibility_scope", "")) != "public" \
			or str(public_receipt.get("event_kind", "")) != "ai_business_market_pressure_resolved":
		return {"applied": false, "reason_code": "ai_business_public_clue_receipt_invalid"}
	var product_id := str(public_receipt.get("product_id", "")).strip_edges()
	var region_id := str(public_receipt.get("public_region_id", "")).strip_edges()
	var pressure_units := maxi(0, int(public_receipt.get("pressure_units", 0)))
	var price_before := maxi(0, int(public_receipt.get("price_before", 0)))
	var price_after := maxi(0, int(public_receipt.get("price_after", 0)))
	var market_revision := maxi(0, int(public_receipt.get("market_revision", 0)))
	var public_event_id := str(public_receipt.get("public_event_id", "")).strip_edges()
	if product_id.is_empty() or region_id.is_empty() or pressure_units <= 0 or public_event_id.is_empty():
		return {"applied": false, "reason_code": "ai_business_public_clue_terms_invalid"}
	return _world_session_state.append_ai_business_market_pressure_public_clue(
		public_event_id,
		region_id,
		product_id,
		pressure_units,
		price_before,
		price_after,
		market_revision,
		_world_session_state.game_time
	)


func can_append_ai_business_public_clue(public_receipt: Dictionary) -> Dictionary:
	if _world_session_state == null or not _is_pure_data(public_receipt):
		return {"ready": false, "reason_code": "ai_business_public_clue_owner_missing"}
	if str(public_receipt.get("visibility_scope", "")) != "public" \
			or str(public_receipt.get("event_kind", "")) != "ai_business_market_pressure_resolved":
		return {"ready": false, "reason_code": "ai_business_public_clue_receipt_invalid"}
	return _world_session_state.can_append_ai_business_market_pressure_public_clue(
		str(public_receipt.get("public_event_id", "")),
		str(public_receipt.get("public_region_id", "")),
		str(public_receipt.get("product_id", "")),
		maxi(0, int(public_receipt.get("pressure_units", 0))),
		maxi(0, int(public_receipt.get("market_revision", 0)))
	)


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
	return _rng_service.randf_range(30.0, 60.0) if _rng_service != null else 30.0


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
		"world_session_state_ready": _world_session_state != null,
		"cash_mutation_port_ready": cash_mutation_ready(),
		"monster_wager_cash_commitment_guard_bound": _cash_commitment_query_port != null,
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"owns_product_market_state": false,
		"owns_product_market_rules": false,
		"owns_shared_rng": false,
		"dynamic_main_cash_callback": false,
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
