@tool
extends Node
class_name CommodityFlowWorldBridge

const CURRENCY_SCALE := 100
const PRODUCT_INDUSTRY_CATALOG := preload("res://resources/content/product_industry_catalog_v05.tres")

var _world: Node
var _controller: Node
var _region_infrastructure_controller: Node
var _product_market_controller: Node
var _route_network_controller: Node
var _capture_count := 0
var _apply_count := 0
var _applied_batch_ids: Dictionary = {}


func set_controller(controller: Node) -> void:
	_controller = controller


func set_runtime_dependencies(region_infrastructure_controller: Node, product_market_controller: Node, route_network_controller: Node) -> void:
	_region_infrastructure_controller = region_infrastructure_controller
	_product_market_controller = product_market_controller
	_route_network_controller = route_network_controller


func bind_world(world: Node) -> void:
	_world = world


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func reset_state() -> void:
	_capture_count = 0
	_apply_count = 0
	_applied_batch_ids.clear()


func enriched_installation_request(request: Dictionary) -> Dictionary:
	if not _is_pure_data(request) or _region_infrastructure_controller == null:
		return {}
	var facility_id := str(request.get("facility_id", ""))
	var facility: Dictionary = {}
	if _region_infrastructure_controller.has_method("facilities_snapshot"):
		for facility_variant in _region_infrastructure_controller.call("facilities_snapshot", false):
			if facility_variant is Dictionary and str((facility_variant as Dictionary).get("facility_id", "")) == facility_id:
				facility = (facility_variant as Dictionary).duplicate(true)
				break
	if facility.is_empty():
		return {}
	var region_id := str(facility.get("region_id", ""))
	var region: Dictionary = _region_infrastructure_controller.call("region_snapshot", region_id) if _region_infrastructure_controller.has_method("region_snapshot") else {}
	var result := request.duplicate(true)
	result["facility"] = facility
	result["region_id"] = region_id
	result["region_revision"] = maxi(0, int(region.get("revision", 0)))
	result["game_time"] = float(_world.get("game_time")) if has_world() else 0.0
	return result


func capture_flow_facts() -> Dictionary:
	if not has_world() or _region_infrastructure_controller == null or _product_market_controller == null:
		return {}
	_capture_count += 1
	var regions: Array = _region_infrastructure_controller.call("regions_snapshot") if _region_infrastructure_controller.has_method("regions_snapshot") else []
	var active_facilities: Array = _region_infrastructure_controller.call("facilities_snapshot", false) if _region_infrastructure_controller.has_method("facilities_snapshot") else []
	var all_facilities: Array = _region_infrastructure_controller.call("facilities_snapshot", true) if _region_infrastructure_controller.has_method("facilities_snapshot") else active_facilities
	var active_ids: Dictionary = {}
	for facility_variant in active_facilities:
		if facility_variant is Dictionary:
			active_ids[str((facility_variant as Dictionary).get("facility_id", ""))] = true
	var destroyed_facility_ids: Array = []
	for facility_variant in all_facilities:
		if not (facility_variant is Dictionary):
			continue
		var facility_id := str((facility_variant as Dictionary).get("facility_id", ""))
		if not facility_id.is_empty() and not active_ids.has(facility_id):
			destroyed_facility_ids.append(facility_id)
	var price_cents_by_commodity: Dictionary = {}
	if PRODUCT_INDUSTRY_CATALOG != null and PRODUCT_INDUSTRY_CATALOG.has_method("product_ids"):
		for commodity_id_variant in PRODUCT_INDUSTRY_CATALOG.call("product_ids"):
			var commodity_id := str(commodity_id_variant)
			var unit_price := int(_product_market_controller.call("product_price", commodity_id)) if _product_market_controller.has_method("product_price") else 0
			price_cents_by_commodity[commodity_id] = maxi(0, unit_price * CURRENCY_SCALE)
	var route_candidates: Array = []
	if _route_network_controller != null and _route_network_controller.has_method("all_route_candidates"):
		var route_variant: Variant = _route_network_controller.call("all_route_candidates", "*")
		if route_variant is Array:
			route_candidates = (route_variant as Array).duplicate(true)
	return {
		"game_time": float(_world.get("game_time")),
		"regions": regions.duplicate(true),
		"facilities": active_facilities.duplicate(true),
		"destroyed_facility_ids": destroyed_facility_ids,
		"price_cents_by_commodity": price_cents_by_commodity,
		"route_candidates": route_candidates,
	}


func apply_sale_receipt_batch(batch: Dictionary) -> Dictionary:
	if not has_world() or not _is_pure_data(batch):
		return {"applied": false, "reason": "world_or_batch_invalid"}
	var batch_id := str(batch.get("batch_id", ""))
	if batch_id.is_empty():
		return {"applied": false, "reason": "batch_id_missing"}
	if _applied_batch_ids.has(batch_id):
		return {"applied": true, "duplicate": true, "batch_id": batch_id, "receipt_count": int(_applied_batch_ids[batch_id])}
	var players_variant: Variant = _world.get("players")
	if not (players_variant is Array):
		return {"applied": false, "reason": "players_missing"}
	var prepared_players: Array = (players_variant as Array).duplicate(true)
	var deltas_by_player: Dictionary = {}
	var ledger_rows_by_player: Dictionary = {}
	var receipt_ids: Dictionary = {}
	var receipts: Array = batch.get("receipts", []) if batch.get("receipts", []) is Array else []
	for receipt_variant in receipts:
		if not (receipt_variant is Dictionary):
			return {"applied": false, "reason": "receipt_invalid"}
		var receipt: Dictionary = receipt_variant
		var receipt_id := str(receipt.get("receipt_id", ""))
		var owner_index := int(receipt.get("commodity_owner", -1))
		var rent_rows_variant: Variant = receipt.get("rent_rows", [])
		var neutral_local_market := str(receipt.get("trade_kind", "")) == "local_market_baseline" \
			and str(receipt.get("economic_owner_kind", "")) == "public_local" \
			and owner_index == -1 \
			and int(receipt.get("owner_net_cash", -1)) == 0 \
			and rent_rows_variant is Array \
			and (rent_rows_variant as Array).is_empty()
		if receipt_id.is_empty() or receipt_ids.has(receipt_id) or (not neutral_local_market and (owner_index < 0 or owner_index >= prepared_players.size())):
			return {"applied": false, "reason": "receipt_identity_invalid"}
		receipt_ids[receipt_id] = true
		if not neutral_local_market:
			_append_player_delta(deltas_by_player, ledger_rows_by_player, owner_index, int(receipt.get("owner_net_cash", 0)), receipt_id, "commodity_sale")
		for rent_variant in receipt.get("rent_rows", []):
			if not (rent_variant is Dictionary):
				return {"applied": false, "reason": "rent_row_invalid"}
			var rent: Dictionary = rent_variant
			var recipient_index := int(rent.get("recipient_player_index", -1))
			if recipient_index < 0 or recipient_index >= prepared_players.size():
				return {"applied": false, "reason": "rent_recipient_invalid"}
			_append_player_delta(deltas_by_player, ledger_rows_by_player, recipient_index, int(rent.get("amount", 0)), receipt_id, "facility_rent")
	for player_key_variant in deltas_by_player.keys():
		var player_index := int(player_key_variant)
		if not (prepared_players[player_index] is Dictionary):
			return {"applied": false, "reason": "player_record_invalid"}
		var player: Dictionary = (prepared_players[player_index] as Dictionary).duplicate(true)
		var cash_cents := int(player.get("cash_cents", int(player.get("cash", 0)) * CURRENCY_SCALE))
		cash_cents += int(deltas_by_player[player_index])
		if cash_cents < 0:
			return {"applied": false, "reason": "cash_would_be_negative"}
		player["cash_cents"] = cash_cents
		player["cash"] = int(floor(float(cash_cents) / float(CURRENCY_SCALE)))
		var ledger: Array = player.get("v06_transaction_ledger", []) if player.get("v06_transaction_ledger", []) is Array else []
		for row_variant in ledger_rows_by_player.get(player_index, []):
			ledger.append((row_variant as Dictionary).duplicate(true))
		player["v06_transaction_ledger"] = ledger
		prepared_players[player_index] = player
	_world.set("players", prepared_players)
	_applied_batch_ids[batch_id] = receipts.size()
	_apply_count += 1
	return {"applied": true, "duplicate": false, "batch_id": batch_id, "receipt_count": receipts.size(), "player_delta_count": deltas_by_player.size()}


func notify_sale_receipt_batch_committed(batch: Dictionary) -> void:
	if has_world() and _world.has_method("_on_commodity_flow_receipt_batch"):
		_world.call("_on_commodity_flow_receipt_batch", batch.duplicate(true))


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world() and _controller != null and _region_infrastructure_controller != null and _product_market_controller != null and _route_network_controller != null,
		"runtime_owner": "none",
		"bridge_role": "commodity_flow_world_facts_and_atomic_cash_apply",
		"capture_count": _capture_count,
		"apply_count": _apply_count,
		"applied_batch_count": _applied_batch_ids.size(),
		"owns_flow_rules": false,
		"owns_installations": false,
		"owns_routes": false,
		"route_runtime_dependency": "RouteNetworkRuntimeController",
		"owns_sale_receipts": false,
		"pure_data": true,
	}


func _append_player_delta(deltas: Dictionary, ledger_rows: Dictionary, player_index: int, amount_cents: int, receipt_id: String, category: String) -> void:
	deltas[player_index] = int(deltas.get(player_index, 0)) + amount_cents
	if not ledger_rows.has(player_index):
		ledger_rows[player_index] = []
	(ledger_rows[player_index] as Array).append({
		"transaction_id": receipt_id,
		"category": category,
		"ledger_delta_cents": amount_cents,
	})


func _is_pure_data(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
		return true
	if value is Array:
		for item_variant in value:
			if not _is_pure_data(item_variant):
				return false
		return true
	return false
