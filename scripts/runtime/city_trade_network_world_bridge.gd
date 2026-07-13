@tool
extends Node
class_name CityTradeNetworkWorldBridge

var _world: Node
var _capture_count := 0
var _network_apply_count := 0
var _cashflow_apply_count := 0
var _disruption_apply_count := 0
var _city_state_snapshot_cache: Dictionary = {}
var _economy_snapshot_cache: Dictionary = {}
var _snapshot_cache_frame := -1
var _city_state_cache_hits := 0
var _economy_cache_hits := 0


func bind_world(world: Node) -> void:
	_world = world
	invalidate_snapshot_cache()


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func capture_world_snapshot() -> Dictionary:
	if not has_world():
		return {}
	_capture_count += 1
	return _capture_snapshot(true)


func capture_economy_snapshot() -> Dictionary:
	if not has_world():
		return {}
	_refresh_snapshot_cache_frame()
	if not _economy_snapshot_cache.is_empty():
		_economy_cache_hits += 1
		return _economy_snapshot_cache
	_capture_count += 1
	_economy_snapshot_cache = _capture_snapshot(false)
	return _economy_snapshot_cache


func capture_city_state_snapshot() -> Dictionary:
	if not has_world():
		return {}
	_refresh_snapshot_cache_frame()
	if not _city_state_snapshot_cache.is_empty():
		_city_state_cache_hits += 1
		return _city_state_snapshot_cache
	_capture_count += 1
	_city_state_snapshot_cache = {
		"districts": _capture_districts(),
		"game_time": float(_world.get("game_time")),
	}
	return _city_state_snapshot_cache


func invalidate_snapshot_cache() -> void:
	_city_state_snapshot_cache = {}
	_economy_snapshot_cache = {}
	_snapshot_cache_frame = -1


func _refresh_snapshot_cache_frame() -> void:
	var current_frame := Engine.get_process_frames()
	if current_frame == _snapshot_cache_frame:
		return
	_snapshot_cache_frame = current_frame
	_city_state_snapshot_cache = {}
	_economy_snapshot_cache = {}


func _capture_snapshot(include_topology: bool) -> Dictionary:
	var districts := _capture_districts()
	var players_variant: Variant = _world.get("players")
	var players: Array = (players_variant as Array).duplicate(true) if players_variant is Array else []
	var centers := {}
	var distances := {}
	var transport_speed := {}
	var production_factor := {}
	var consumption_factor := {}
	var role_bonus := {}
	var eliminated := {}
	var product_ids := {}
	for player_index in range(players.size()):
		eliminated[str(player_index)] = bool(_world.call("_player_is_eliminated", player_index)) if _world.has_method("_player_is_eliminated") else false
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
		if include_topology:
			var center := Vector2.ZERO
			if _world.has_method("_district_center"):
				var center_variant: Variant = _world.call("_district_center", district_index)
				if center_variant is Vector2:
					center = center_variant
			centers[str(district_index)] = {"x": center.x, "y": center.y}
		transport_speed[str(district_index)] = float(_world.call("_district_transport_speed", district_index)) if _world.has_method("_district_transport_speed") else 1.0
		production_factor[str(district_index)] = float(_world.call("_district_production_factor", district_index)) if _world.has_method("_district_production_factor") else 1.0
		consumption_factor[str(district_index)] = float(_world.call("_district_consumption_factor", district_index)) if _world.has_method("_district_consumption_factor") else 1.0
		var city: Dictionary = district.get("city", {}) if district.get("city", {}) is Dictionary else {}
		var city_owner := int(city.get("owner", -1))
		role_bonus[str(district_index)] = int(_world.call("_role_market_income_bonus_amount", city_owner, district_index)) if _world.has_method("_role_market_income_bonus_amount") else 0
		_collect_product_ids(product_ids, district, city)
	if include_topology:
		for a in range(districts.size()):
			for b in range(districts.size()):
				var key := _edge_key(a, b)
				distances[key] = float(_world.call("_distance", a, b)) if _world.has_method("_distance") else INF
	var market_facts := {}
	for product_variant in product_ids.keys():
		var product_id := str(product_variant)
		market_facts[product_id] = {
			"price": int(_world.call("_product_market_price", product_id)) if _world.has_method("_product_market_price") else 0,
			"supply_demand_ratio": float(_world.call("_product_supply_demand_ratio", product_id)) if _world.has_method("_product_supply_demand_ratio") else 1.0,
			"supply_availability_ratio": float(_world.call("_product_supply_availability_ratio", product_id)) if _world.has_method("_product_supply_availability_ratio") else 1.0,
			"route_flow_multiplier": float(_world.call("_product_market_route_flow_multiplier", product_id)) if _world.has_method("_product_market_route_flow_multiplier") else 1.0,
		}
	return {
		"districts": districts,
		"players": players,
		"game_time": float(_world.get("game_time")),
		"center_by_district": centers,
		"distance_by_edge": distances,
		"transport_speed_by_district": transport_speed,
		"production_factor_by_district": production_factor,
		"consumption_factor_by_district": consumption_factor,
		"role_bonus_by_district": role_bonus,
		"eliminated_by_player": eliminated,
		"market_by_product": market_facts,
	}


func _capture_districts() -> Array:
	var districts_variant: Variant = _world.get("districts")
	var districts: Array = (districts_variant as Array).duplicate(true) if districts_variant is Array else []
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
		var city_variant: Variant = district.get("city", {})
		if city_variant is Dictionary and not (city_variant as Dictionary).is_empty():
			district["city"] = CityDevelopmentRuntimeController.normalize_city_runtime_fields_data((city_variant as Dictionary).duplicate(true), 30.0)
			districts[district_index] = district
	return districts


func apply_network_receipt(receipt: Dictionary) -> Dictionary:
	if not has_world() or not bool(receipt.get("valid", false)):
		return {"applied": false, "reason": "world_or_receipt_invalid"}
	var districts_variant: Variant = receipt.get("districts", [])
	if not (districts_variant is Array):
		return {"applied": false, "reason": "districts_missing"}
	_world.set("districts", _materialize_route_points((districts_variant as Array).duplicate(true)))
	invalidate_snapshot_cache()
	if bool(receipt.get("ensure_city_development_supply", false)) and _world.has_method("_ensure_city_development_card_supply"):
		_world.call("_ensure_city_development_card_supply")
	_network_apply_count += 1
	return {"applied": true, "reason": "", "district_count": (districts_variant as Array).size()}


func apply_trade_disruption_receipt(receipt: Dictionary) -> Dictionary:
	var apply_result := apply_network_receipt(receipt)
	if not bool(apply_result.get("applied", false)):
		return apply_result
	for event_variant in receipt.get("private_log_intents", []):
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		if _world.has_method("_log"):
			_world.call("_log", str(event.get("text", "")))
	var callout_variant: Variant = receipt.get("callout_intent", {})
	if callout_variant is Dictionary and not (callout_variant as Dictionary).is_empty() and _world.has_method("_add_action_callout"):
		var callout: Dictionary = callout_variant
		_world.call(
			"_add_action_callout",
			str(callout.get("title", "")),
			str(callout.get("badge", "")),
			str(callout.get("detail", "")),
			Color.from_string(str(callout.get("accent", "#fb7185")), Color("#fb7185")),
			_point_from_data(callout.get("position", {}))
		)
	_disruption_apply_count += 1
	return {"applied": true, "reason": "", "affected_city_count": int(receipt.get("affected_city_count", 0))}


func apply_cashflow_receipt(receipt: Dictionary) -> Dictionary:
	if not has_world() or not bool(receipt.get("valid", false)):
		return {"applied": false, "reason": "world_or_receipt_invalid"}
	var players_variant: Variant = receipt.get("players", [])
	var districts_variant: Variant = receipt.get("districts", [])
	if not (players_variant is Array) or not (districts_variant is Array):
		return {"applied": false, "reason": "world_state_missing"}
	_world.set("players", (players_variant as Array).duplicate(true))
	_world.set("districts", _materialize_route_points((districts_variant as Array).duplicate(true)))
	invalidate_snapshot_cache()
	for event_variant in receipt.get("economic_event_intents", []):
		if not (event_variant is Dictionary) or not _world.has_method("_record_player_economic_event"):
			continue
		var event: Dictionary = event_variant
		_world.call(
			"_record_player_economic_event",
			int(event.get("player_index", -1)),
			str(event.get("category", "")),
			str(event.get("source", "")),
			int(event.get("amount", 0)),
			str(event.get("detail", ""))
		)
	for player_variant in receipt.get("cash_snapshot_players", []):
		if _world.has_method("_record_player_cash_snapshot"):
			_world.call("_record_player_cash_snapshot", int(player_variant))
	_cashflow_apply_count += 1
	return {"applied": true, "reason": "", "payout_total": int(receipt.get("payout_total", 0))}


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"world_bound": has_world(),
		"capture_count": _capture_count,
		"snapshot_cache_frame": _snapshot_cache_frame,
		"city_state_cache_hits": _city_state_cache_hits,
		"economy_cache_hits": _economy_cache_hits,
		"network_apply_count": _network_apply_count,
		"cashflow_apply_count": _cashflow_apply_count,
		"disruption_apply_count": _disruption_apply_count,
		"owns_runtime_state": false,
		"owns_rules": false,
	}


func _collect_product_ids(target: Dictionary, district: Dictionary, city: Dictionary) -> void:
	for value_variant in district.get("products", []):
		var product_id := str(value_variant)
		if product_id != "":
			target[product_id] = true
	for value_variant in district.get("demands", []):
		var product_id := str(value_variant)
		if product_id != "":
			target[product_id] = true
	for value_variant in city.get("products", []):
		if value_variant is Dictionary:
			var product_id := str((value_variant as Dictionary).get("name", ""))
			if product_id != "":
				target[product_id] = true
	for value_variant in city.get("demands", []):
		var product_id := str(value_variant)
		if product_id != "":
			target[product_id] = true


func _materialize_route_points(source: Array) -> Array:
	var districts := source.duplicate(true)
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary):
			continue
		var district: Dictionary = districts[district_index]
		var city_variant: Variant = district.get("city", {})
		if not (city_variant is Dictionary):
			continue
		var city := (city_variant as Dictionary).duplicate(true)
		var routes: Array = city.get("trade_routes", []) if city.get("trade_routes", []) is Array else []
		for route_index in range(routes.size()):
			if not (routes[route_index] is Dictionary):
				continue
			var route := (routes[route_index] as Dictionary).duplicate(true)
			var points: Array = []
			for point_variant in route.get("points", []):
				points.append(_point_from_data(point_variant))
			route["points"] = points
			routes[route_index] = route
		city["trade_routes"] = routes
		district["city"] = city
		districts[district_index] = district
	return districts


func _point_from_data(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", 0.0)), float((value as Dictionary).get("y", 0.0)))
	return Vector2.ZERO


func _edge_key(a: int, b: int) -> String:
	return "%d:%d" % [a, b]
