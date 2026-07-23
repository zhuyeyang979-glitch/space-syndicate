@tool
extends Node
class_name AiActorEconomyQueryPort

@export var world_session_state_path: NodePath
@export var game_session_runtime_controller_path: NodePath
@export var cash_commitment_query_port_path: NodePath
@export var product_market_runtime_controller_path: NodePath

var _capabilities_by_actor: Dictionary = {}
var _capability_binding_initialized := false
var _bound_actor_roster_revision := ""
var _capability_revision := 0
var _query_count := 0
var _rejected_query_count := 0


func bind_ai_capabilities(capabilities_by_actor: Dictionary) -> bool:
	var expected_actor_indices := _ai_player_indices()
	if capabilities_by_actor.size() != expected_actor_indices.size():
		return _reject_capability_binding()
	var normalized: Dictionary = {}
	var seen_tokens: Dictionary = {}
	for actor_index_variant in expected_actor_indices:
		var actor_index := int(actor_index_variant)
		var capability_variant: Variant = capabilities_by_actor.get(actor_index)
		if not (capability_variant is AiActorEconomyCapability):
			return _reject_capability_binding()
		var token_id := (capability_variant as AiActorEconomyCapability).get_instance_id()
		if seen_tokens.has(token_id):
			return _reject_capability_binding()
		seen_tokens[token_id] = true
		normalized[actor_index] = capability_variant
	_capabilities_by_actor = normalized
	_capability_binding_initialized = true
	_bound_actor_roster_revision = _actor_roster_revision()
	_capability_revision += 1
	return true


func is_ready() -> bool:
	return _world() != null \
		and _game_session() != null \
		and _cash_query() != null \
		and _cash_query().is_ready() \
		and _market() != null \
		and _capability_binding_initialized


func private_economy_snapshot(
	capability: AiActorEconomyCapability,
	actor_index: int
) -> Dictionary:
	_query_count += 1
	if not _authorized(capability, actor_index):
		_rejected_query_count += 1
		return {}
	var exact_cash := _world().private_player_cash_snapshot(actor_index)
	var cash_availability := _cash_query().private_cash_availability_snapshot(actor_index)
	var city_economy := _world().private_player_city_economy_snapshot(actor_index)
	var futures := _market().private_futures_positions_snapshot(actor_index)
	if not bool(exact_cash.get("valid", false)) \
			or not bool(cash_availability.get("valid", false)) \
			or not bool(city_economy.get("valid", false)) \
			or not bool(futures.get("valid", false)):
		_rejected_query_count += 1
		return {}
	var result := {
		"schema_version": 1,
		"visibility_scope": "actor_private",
		"actor_index": actor_index,
		"actor_id": str((_world().players[actor_index] as Dictionary).get(
			"actor_id",
			(_world().players[actor_index] as Dictionary).get("id", "player:%d" % actor_index)
		)),
		"cash": _cash_projection(exact_cash, cash_availability),
		"economy_summary": (city_economy.get("summary", {}) as Dictionary).duplicate(true),
		"own_cities": (city_economy.get("cities", []) as Array).duplicate(true),
		"own_futures": (futures.get("positions", []) as Array).duplicate(true),
	}
	result["state_revision"] = JSON.stringify([
		"ai_actor_economy_snapshot_v1",
		actor_index,
		_bound_actor_roster_revision,
		exact_cash.get("cash_cents", 0),
		cash_availability.get("availability_fingerprint", ""),
		city_economy.get("state_revision", ""),
		futures.get("state_revision", ""),
	]).sha256_text()
	if not TablePresentationPureDataPolicy.is_pure_data(result):
		_rejected_query_count += 1
		return {}
	return TablePresentationPureDataPolicy.detached_copy(result)


func debug_snapshot() -> Dictionary:
	return {
		"port_ready": is_ready(),
		"capability_revision": _capability_revision,
		"actor_scoped_capability_count": _capabilities_by_actor.size(),
		"query_count": _query_count,
		"rejected_query_count": _rejected_query_count,
		"returns_own_cash_only": true,
		"returns_own_city_economy_only": true,
		"returns_own_futures_only": true,
		"returns_rival_cash": false,
		"returns_rival_warehouse": false,
		"returns_rival_futures": false,
		"returns_whole_players": false,
		"returns_whole_districts": false,
		"mutates_world": false,
		"consumes_rng": false,
		"references_main": false,
	}


func _cash_projection(exact_snapshot: Dictionary, availability_snapshot: Dictionary) -> Dictionary:
	var scale := MonsterWagerCashCommitmentQueryPort.CURRENCY_SCALE
	var total_cents := int(exact_snapshot.get("cash_cents", 0))
	return {
		"total_cents": total_cents,
		"reserved_cents": int(availability_snapshot.get("reserved_cents", 0)),
		"available_cents": int(availability_snapshot.get("available_cents", 0)),
		"total_units": floori(float(total_cents) / float(scale)),
		"reserved_units": floori(float(int(availability_snapshot.get("reserved_cents", 0))) / float(scale)),
		"available_units": floori(float(int(availability_snapshot.get("available_cents", 0))) / float(scale)),
		"commitment_revision": int(availability_snapshot.get("commitment_revision", 0)),
		"availability_fingerprint": str(availability_snapshot.get("availability_fingerprint", "")),
	}


func _authorized(capability: AiActorEconomyCapability, actor_index: int) -> bool:
	return capability != null \
		and is_ready() \
		and _bound_actor_roster_revision == _actor_roster_revision() \
		and _capabilities_by_actor.get(actor_index) == capability \
		and not _game_session().is_finished() \
		and actor_index >= 0 \
		and actor_index < _world().players.size() \
		and _world().players[actor_index] is Dictionary \
		and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
			or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai")


func _ai_player_indices() -> Array:
	var result: Array = []
	if _world() == null:
		return result
	for actor_index in range(_world().players.size()):
		if _world().players[actor_index] is Dictionary \
				and (bool((_world().players[actor_index] as Dictionary).get("is_ai", false)) \
				or str((_world().players[actor_index] as Dictionary).get("seat_type", "human")) == "ai"):
			result.append(actor_index)
	return result


func _actor_roster_revision() -> String:
	var roster_identity: Array = []
	if _world() != null:
		for actor_index_variant in _ai_player_indices():
			var actor_index := int(actor_index_variant)
			var actor := _world().players[actor_index] as Dictionary
			roster_identity.append([
				actor_index,
				str(actor.get("actor_id", actor.get("id", actor_index))),
				str(actor.get("id", actor_index)),
				str(actor.get("name", "")),
				str(actor.get("seat_type", "ai")),
			])
	return JSON.stringify(["ai_actor_economy_roster_v1", roster_identity]).sha256_text()


func _reject_capability_binding() -> bool:
	_capabilities_by_actor.clear()
	_capability_binding_initialized = false
	_bound_actor_roster_revision = ""
	_capability_revision += 1
	return false


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _game_session() -> GameSessionRuntimeController:
	return get_node_or_null(game_session_runtime_controller_path) as GameSessionRuntimeController


func _cash_query() -> MonsterWagerCashCommitmentQueryPort:
	return get_node_or_null(cash_commitment_query_port_path) as MonsterWagerCashCommitmentQueryPort


func _market() -> ProductMarketRuntimeController:
	return get_node_or_null(product_market_runtime_controller_path) as ProductMarketRuntimeController
