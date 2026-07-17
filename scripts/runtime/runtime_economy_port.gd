extends Node
class_name RuntimeEconomyPort

var _city_derivatives: CityGdpDerivativeRuntimeController
var _product_market: ProductMarketRuntimeController
var _commodity_flow: CommodityFlowRuntimeController
var _bankruptcy: BankruptcyNeutralEstateRuntimeController
var _player_mana: PlayerManaRuntimeController
var _session: GameSessionRuntimeController
var _scheduler: ForcedDecisionRuntimeScheduler
var _world_state: WorldSessionState


func bind_dependencies(
	city_derivatives: CityGdpDerivativeRuntimeController,
	product_market: ProductMarketRuntimeController,
	commodity_flow: CommodityFlowRuntimeController,
	bankruptcy: BankruptcyNeutralEstateRuntimeController,
	player_mana: PlayerManaRuntimeController,
	session: GameSessionRuntimeController,
	scheduler: ForcedDecisionRuntimeScheduler,
	world_state: WorldSessionState
) -> void:
	_city_derivatives = city_derivatives
	_product_market = product_market
	_commodity_flow = commodity_flow
	_bankruptcy = bankruptcy
	_player_mana = player_mana
	_session = session
	_scheduler = scheduler
	_world_state = world_state


func is_ready() -> bool:
	return is_instance_valid(_city_derivatives) and is_instance_valid(_product_market) \
		and is_instance_valid(_commodity_flow) and is_instance_valid(_bankruptcy) \
		and is_instance_valid(_player_mana) and is_instance_valid(_session) \
		and is_instance_valid(_scheduler) and is_instance_valid(_world_state)


func advance_city_gdp_derivative_timers() -> Dictionary:
	return _city_derivatives.update_timers() if _city_derivatives != null else {
		"updated": false,
		"reason": "city_gdp_derivative_runtime_missing",
	}


func advance_product_futures_timers() -> void:
	if _product_market != null:
		_product_market.update_futures_timers()


func advance_economic_boons(delta_seconds: float) -> void:
	if _product_market != null:
		_product_market.age_economic_boons(delta_seconds)


func tick_product_market_cycle(delta_seconds: float) -> Dictionary:
	return _product_market.tick_market_cycle(delta_seconds).duplicate(true) if _product_market != null else {
		"advanced": false,
		"reason": "product_market_runtime_missing",
	}


func advance_commodity_flow(delta_seconds: float, blocking_snapshot: Dictionary = {}) -> Dictionary:
	if _commodity_flow == null:
		return {"advanced": false, "reason": "commodity_flow_runtime_missing", "receipt_count": 0}
	var merged := blocking_snapshot.duplicate(true)
	merged["global_blocked"] = bool(merged.get("global_blocked", false)) or (_scheduler != null and _scheduler.blocks_global_time())
	merged["session_paused"] = bool(merged.get("session_paused", false)) or (_session != null and _session.session_state() == "paused")
	var flow_result := _commodity_flow.advance_world(delta_seconds, merged).duplicate(true)
	if not bool(flow_result.get("advanced", false)):
		return flow_result
	if _bankruptcy == null:
		flow_result["bankruptcy_checkpoint"] = {"finalized": false, "reason_code": "bankruptcy_checkpoint_missing"}
		return flow_result
	var bankruptcy := _bankruptcy.settle_checkpoint({
		"transaction_id": "bankruptcy:%s" % str(flow_result.get("batch_id", "")),
		"reason_code": "post_sale_receipt",
		"occurred_at": float(merged.get("game_time", 0.0)),
	})
	flow_result["bankruptcy_checkpoint"] = bankruptcy.duplicate(true)
	if not bool(bankruptcy.get("finalized", false)):
		return flow_result
	var color_gdp_by_player: Dictionary = {}
	for player_index in range(maxi(0, int(merged.get("player_count", 0)))):
		color_gdp_by_player[str(player_index)] = _commodity_flow.player_color_flow_snapshot(player_index)
	if _player_mana == null:
		flow_result["asset_recovery"] = {"advanced": false, "reason": "player_mana_runtime_missing"}
		return flow_result
	flow_result["asset_recovery"] = _player_mana.advance(
		maxi(1, int(round(delta_seconds * 1000.0))),
		float(merged.get("game_time", 0.0)),
		color_gdp_by_player
	).duplicate(true)
	return flow_result


func advance_runtime_commodity_flow(delta_seconds: float) -> bool:
	if _session == null or _session.is_finished() or delta_seconds <= 0.0:
		return true
	if _world_state == null:
		return false
	var result := advance_commodity_flow(delta_seconds, {
		"game_over": _session.is_finished(),
		"time_paused": _session.session_state() == "paused",
		"game_time": _world_state.game_time,
		"player_count": _world_state.players.size(),
	})
	var checkpoint: Dictionary = result.get("bankruptcy_checkpoint", {}) if result.get("bankruptcy_checkpoint", {}) is Dictionary else {}
	return bool(result.get("advanced", false)) and bool(checkpoint.get("finalized", false))


func debug_snapshot() -> Dictionary:
	return {"port_kind": "economy", "ready": is_ready(), "operation_count": 6, "owns_economy_state": false}
