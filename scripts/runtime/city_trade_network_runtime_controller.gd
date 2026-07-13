@tool
extends Node
class_name CityTradeNetworkRuntimeController

const PROJECT_STATE := preload("res://scripts/economy/city_product_project_state.gd")
const PROJECT_BRIDGE := preload("res://scripts/economy/city_product_project_bridge.gd")

const SAVE_TERMS_VERSION := "v0.5.project-slots.1"
const OCEAN_ROUTE_COST_MULTIPLIER := 0.88
const DESTROYED_ROUTE_COST_PENALTY := 4.0
const MIASMA_ROUTE_COST_PENALTY := 0.35
const PANIC_ROUTE_COST_PER_POINT := 0.002
const TRANSPORT_SCORE_MIN := 0.55
const TRANSPORT_SCORE_MAX := 2.4
const ROUTE_FLOW_MULTIPLIER_MAX := 2.8

@export var project_rules_profile: Resource

var _ruleset_id := ""
var _project_ruleset_id := ""
var _project_slot_counts: Dictionary = {}
var _maximum_project_rank := 0
var _configured := false
var _project_sequence := 1
var _generation_by_slot_id: Dictionary = {}
var _project_tombstones: Dictionary = {}
var _refresh_count := 0
var _cashflow_settlement_count := 0
var _disruption_count := 0
var _last_refresh_receipt: Dictionary = {}

var _world_bridge: Node
var _gdp_formula_controller: Node
var _cashflow_controller: Node
var _formula_service: Node


func set_world_bridge(bridge: Node) -> void:
	_world_bridge = bridge


func set_gdp_formula_controller(controller: Node) -> void:
	_gdp_formula_controller = controller


func set_cashflow_controller(controller: Node) -> void:
	_cashflow_controller = controller


func set_formula_service(service: Node) -> void:
	_formula_service = service


func configure(ruleset_snapshot: Dictionary) -> void:
	_ruleset_id = str(ruleset_snapshot.get("ruleset_id", ""))
	var project_rules := _project_rules_snapshot()
	_project_ruleset_id = str(project_rules.get("ruleset_id", ""))
	_project_slot_counts = (project_rules.get("project_slot_counts", {}) as Dictionary).duplicate(true) if project_rules.get("project_slot_counts", {}) is Dictionary else {}
	_maximum_project_rank = int(project_rules.get("maximum_project_rank", 0))
	var project_contract_valid := _project_ruleset_id == "v0.5" and _project_slot_counts == PROJECT_STATE.SLOT_COUNTS and _maximum_project_rank == PROJECT_STATE.MAX_PROJECT_RANK
	_configured = _ruleset_id in ["v0.4", "v0.5"] and project_contract_valid and _world_bridge != null and _gdp_formula_controller != null and _cashflow_controller != null and _formula_service != null
	if not _configured:
		push_error("CityTradeNetworkRuntimeController requires the v0.5 project contract plus WorldBridge, GDP, Cashflow, and Formula services.")


func reset_state() -> void:
	_project_sequence = 1
	_generation_by_slot_id.clear()
	_project_tombstones.clear()
	_refresh_count = 0
	_cashflow_settlement_count = 0
	_disruption_count = 0
	_last_refresh_receipt = {}


func project_sequence() -> int:
	return _project_sequence


func claim_project_sequence() -> int:
	var current := _project_sequence
	_project_sequence += 1
	return current


func claim_project_sequence_if(expected_sequence: int) -> Dictionary:
	if expected_sequence != _project_sequence:
		return {
			"claimed": false,
			"reason": "project_sequence_changed",
			"expected_sequence": expected_sequence,
			"current_sequence": _project_sequence,
		}
	var claimed_sequence := _project_sequence
	_project_sequence += 1
	return {
		"claimed": true,
		"reason": "",
		"claimed_sequence": claimed_sequence,
		"next_sequence": _project_sequence,
	}


func normalize_city(city_value: Dictionary, district_index: int) -> Dictionary:
	if city_value.is_empty():
		return {}
	var normalized: Dictionary = PROJECT_BRIDGE.normalize_city(city_value, district_index, _project_sequence, _generation_by_slot_id)
	_register_city_identity(normalized)
	for project_variant in normalized.get("projects", []):
		if project_variant is Dictionary:
			_project_sequence = maxi(_project_sequence, int((project_variant as Dictionary).get("created_order", 0)) + 1)
	_project_sequence = maxi(_project_sequence, int(normalized.get("project_sequence", 0)))
	return normalized


func city_has_project_shares(city: Dictionary) -> bool:
	return not PROJECT_BRIDGE.active_projects(city).is_empty()


func public_project_slot_snapshots(district_index: int) -> Array:
	var snapshot := _city_state_snapshot()
	var city := _district_city(snapshot.get("districts", []), district_index)
	return PROJECT_BRIDGE.public_slots(normalize_city(city, district_index)) if not city.is_empty() else []


func project_generation(stable_slot_id: String) -> int:
	return maxi(0, int(_generation_by_slot_id.get(stable_slot_id, 0)))


func tombstone_project(district_index: int, stable_slot_id: String, reason: String) -> Dictionary:
	if not _runtime_ready():
		return {"applied": false, "reason_code": "controller_not_ready"}
	var snapshot := _city_state_snapshot()
	var districts := _districts_from_snapshot(snapshot).duplicate(true)
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return {"applied": false, "reason_code": "district_invalid"}
	var district: Dictionary = (districts[district_index] as Dictionary).duplicate(true)
	var city_variant: Variant = district.get("city", {})
	if not (city_variant is Dictionary) or (city_variant as Dictionary).is_empty():
		return {"applied": false, "reason_code": "city_missing"}
	var result := PROJECT_BRIDGE.tombstone_project(city_variant as Dictionary, district_index, stable_slot_id, reason, _generation_by_slot_id)
	if not bool(result.get("applied", false)):
		return result
	var city: Dictionary = (result.get("city", {}) as Dictionary).duplicate(true)
	district["city"] = city
	districts[district_index] = district
	var apply_result: Dictionary = _world_bridge.call("apply_network_receipt", {"valid": true, "districts": districts, "ensure_city_development_supply": false})
	if not bool(apply_result.get("applied", false)):
		return {"applied": false, "reason_code": str(apply_result.get("reason", "apply_failed"))}
	_register_city_identity(city)
	return {
		"applied": true,
		"reason_code": "",
		"slot_id": stable_slot_id,
		"tombstone": (result.get("tombstone", {}) as Dictionary).duplicate(true),
	}


func public_project_snapshots(district_index: int) -> Array:
	var snapshot := _city_state_snapshot()
	var city := _district_city(snapshot.get("districts", []), district_index)
	return PROJECT_BRIDGE.public_projects(city) if not city.is_empty() else []


func private_project_snapshots(district_index: int, viewer_player_index: int) -> Array:
	var snapshot := _city_state_snapshot()
	var city := _district_city(snapshot.get("districts", []), district_index)
	return PROJECT_BRIDGE.private_projects(city, viewer_player_index) if not city.is_empty() else []


func active_city_district_indices() -> Array:
	return _active_city_indices(_districts_from_snapshot(_city_state_snapshot()))


func competition_matches(district_index: int) -> int:
	return _competition_matches(_districts_from_snapshot(_city_state_snapshot()), district_index)


func city_trade_routes(district_index: int) -> Array:
	var city := _district_city(_districts_from_snapshot(_city_state_snapshot()), district_index)
	return (city.get("trade_routes", []) as Array).duplicate(true) if _city_is_active(city) and city.get("trade_routes", []) is Array else []


func trade_routes_for_product(product_id: String) -> Array:
	var result: Array = []
	if product_id == "":
		return result
	var districts := _districts_from_snapshot(_city_state_snapshot())
	for district_index_variant in _active_city_indices(districts):
		var city := _district_city(districts, int(district_index_variant))
		for route_variant in city.get("trade_routes", []):
			if not (route_variant is Dictionary):
				continue
			var route: Dictionary = route_variant
			if str(route.get("product", "")) == product_id and route.get("path", []) is Array and not (route.get("path", []) as Array).is_empty():
				result.append(route.duplicate(true))
	return result


func player_region_gdp_share_basis_points(player_index: int, district_index: int) -> int:
	var snapshot := _economy_snapshot()
	var districts := _districts_from_snapshot(snapshot)
	var players: Array = snapshot.get("players", []) if snapshot.get("players", []) is Array else []
	if player_index < 0 or player_index >= players.size() or district_index < 0 or district_index >= districts.size():
		return 0
	if bool((districts[district_index] as Dictionary).get("destroyed", false)):
		return 0
	var city := _district_city(districts, district_index)
	if not _city_is_active(city):
		return 0
	var competition := int(city.get("competition_matches", _competition_matches(districts, district_index)))
	var breakdown := _city_gdp_breakdown_from_snapshot(district_index, competition, snapshot)
	var city_gdp := int(breakdown.get("net", 0))
	if city_gdp <= 0:
		return 0
	if city_has_project_shares(city):
		city = PROJECT_BRIDGE.assign_city_gdp(city, city_gdp)
		var player_gdp := PROJECT_STATE.player_gdp(city.get("projects", []) as Array, player_index)
		return clampi(int(round(float(player_gdp * PROJECT_STATE.SHARE_BASIS_POINTS) / float(city_gdp))), 0, PROJECT_STATE.SHARE_BASIS_POINTS)
	return 0


func gdp_formula_snapshot(district_index: int, competition_matches_value: int) -> Dictionary:
	return _city_gdp_formula_snapshot_from_snapshot(district_index, competition_matches_value, _economy_snapshot())


func city_gdp_breakdown(district_index: int, competition_matches_value: int) -> Dictionary:
	return _city_gdp_breakdown_from_snapshot(district_index, competition_matches_value, _economy_snapshot())


func refresh_networks() -> Dictionary:
	if not _runtime_ready():
		return _failure("controller_not_ready")
	var snapshot := _world_snapshot()
	var districts := _districts_from_snapshot(snapshot)
	if districts.is_empty():
		return _failure("districts_empty")
	var refresh_order := ["competition", "routes", "gdp", "project_allocation", "supply_guarantee"]
	for district_index_variant in _active_city_indices(districts):
		var district_index := int(district_index_variant)
		var district: Dictionary = districts[district_index]
		var city := normalize_city(_district_city(districts, district_index), district_index)
		city["competition_matches"] = _competition_matches(districts, district_index)
		district["city"] = city
		districts[district_index] = district
	var route_snapshot := snapshot.duplicate(true)
	route_snapshot["districts"] = districts
	for district_index_variant in _active_city_indices(districts):
		var district_index := int(district_index_variant)
		var district: Dictionary = districts[district_index]
		var city := _district_city(districts, district_index)
		var routes: Array = []
		var route_damage_remaining := int(city.get("trade_route_damage", 0))
		var disrupted := 0
		var supplied := 0
		for demand_variant in city.get("demands", []):
			var product_id := str(demand_variant)
			var route := _trade_route_for_product(product_id, district_index, route_snapshot, districts)
			if route.is_empty():
				disrupted += 1
				routes.append({"product": product_id, "from": -1, "to": district_index, "path": [], "points": [], "disrupted": true, "source_type": "无供给"})
				continue
			if route_damage_remaining > 0:
				route["disrupted"] = true
				route_damage_remaining -= 1
			if bool(route.get("disrupted", false)):
				disrupted += 1
			else:
				supplied += 1
			routes.append(route)
		disrupted += route_damage_remaining
		city["trade_routes"] = routes
		city["trade_disrupted_routes"] = disrupted
		city["supplied_demands"] = supplied
		district["city"] = city
		districts[district_index] = district
		route_snapshot["districts"] = districts
	var gdp_snapshot := snapshot.duplicate(true)
	gdp_snapshot["districts"] = districts
	for district_index_variant in _active_city_indices(districts):
		var district_index := int(district_index_variant)
		var district: Dictionary = districts[district_index]
		var city := _district_city(districts, district_index)
		var city_gdp := 0
		if not bool(district.get("destroyed", false)):
			var breakdown := _city_gdp_breakdown_from_snapshot(district_index, int(city.get("competition_matches", 0)), gdp_snapshot)
			city_gdp = int(breakdown.get("net", 0))
		city = PROJECT_BRIDGE.assign_city_gdp(city, city_gdp)
		district["city"] = city
		districts[district_index] = district
		gdp_snapshot["districts"] = districts
	var receipt := {
		"valid": true,
		"reason": "",
		"districts": districts,
		"refresh_order": refresh_order,
		"ensure_city_development_supply": true,
		"active_city_count": _active_city_indices(districts).size(),
	}
	var apply_result: Dictionary = _world_bridge.call("apply_network_receipt", receipt)
	if not bool(apply_result.get("applied", false)):
		return _failure(str(apply_result.get("reason", "apply_failed")))
	_refresh_count += 1
	_last_refresh_receipt = _sanitize_receipt(receipt)
	return _last_refresh_receipt.duplicate(true)


func shortest_trade_path(source_index: int, destination_index: int) -> Array:
	var snapshot := _world_snapshot()
	return _shortest_path(source_index, destination_index, snapshot, _districts_from_snapshot(snapshot))


func trade_path_cost(path: Array) -> float:
	var snapshot := _world_snapshot()
	return _path_cost(path, snapshot, _districts_from_snapshot(snapshot))


func trade_node_cost_multiplier(district_index: int) -> float:
	var snapshot := _world_snapshot()
	return _node_cost_multiplier(district_index, snapshot, _districts_from_snapshot(snapshot))


func trade_path_is_disrupted(path: Array) -> bool:
	return _path_is_disrupted(path, _districts_from_snapshot(_world_snapshot()))


func apply_trade_disruption_from_destroyed_district(district_index: int, source: String) -> Dictionary:
	if not _runtime_ready():
		return _failure("controller_not_ready")
	var snapshot := _world_snapshot()
	var districts := _districts_from_snapshot(snapshot)
	if district_index < 0 or district_index >= districts.size():
		return _failure("district_invalid")
	var affected_cities := 0
	var log_intents: Array = []
	for city_index_variant in _active_city_indices(districts):
		var city_index := int(city_index_variant)
		var district: Dictionary = districts[city_index]
		var city := _district_city(districts, city_index)
		var affected_products: Array = []
		for route_variant in city.get("trade_routes", []):
			if not (route_variant is Dictionary):
				continue
			var route: Dictionary = route_variant
			var path: Array = route.get("path", []) if route.get("path", []) is Array else []
			var product_id := str(route.get("product", ""))
			if path.has(district_index) and product_id != "" and not affected_products.has(product_id):
				affected_products.append(product_id)
		if affected_products.is_empty():
			continue
		city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + affected_products.size()
		district["city"] = city
		districts[city_index] = district
		affected_cities += 1
		log_intents.append({"text": "%s破坏%s，影响%s的商路：%s。" % [source, _district_name(districts, district_index), _district_name(districts, city_index), "、".join(affected_products)]})
	var callout := {}
	if affected_cities > 0:
		callout = {
			"title": "商路警报",
			"badge": "运输受损",
			"detail": "%s被破坏，%d座城市的途经商路受影响。" % [_district_name(districts, district_index), affected_cities],
			"accent": "#fb7185",
			"position": _center_data(snapshot, district_index),
		}
	var receipt := {"valid": true, "reason": "", "districts": districts, "ensure_city_development_supply": false, "affected_city_count": affected_cities, "private_log_intents": log_intents, "callout_intent": callout}
	var apply_result: Dictionary = _world_bridge.call("apply_trade_disruption_receipt", receipt)
	if not bool(apply_result.get("applied", false)):
		return _failure(str(apply_result.get("reason", "apply_failed")))
	_disruption_count += 1
	return _sanitize_receipt(receipt)


func settle_cashflow_seconds(seconds: float) -> int:
	var safe_seconds := maxf(0.0, seconds)
	if safe_seconds <= 0.0 or not _runtime_ready():
		return 0
	var snapshot := _world_snapshot()
	var districts := _districts_from_snapshot(snapshot)
	var players: Array = snapshot.get("players", []) if snapshot.get("players", []) is Array else []
	if districts.is_empty() or players.is_empty():
		return 0
	var eliminated: Dictionary = snapshot.get("eliminated_by_player", {}) if snapshot.get("eliminated_by_player", {}) is Dictionary else {}
	var sources: Array = []
	var contexts := {}
	for district_index_variant in _active_city_indices(districts):
		var district_index := int(district_index_variant)
		var district: Dictionary = districts[district_index]
		var city := _district_city(districts, district_index)
		if bool(district.get("destroyed", false)):
			city["last_cashflow_rate"] = 0
			city["last_income"] = 0
			city["last_gdp_reason"] = "区域已毁，城市现金流停止结算"
			district["city"] = city
			districts[district_index] = district
			continue
		var competition := _competition_matches(districts, district_index)
		var cash_snapshot := snapshot.duplicate(true)
		cash_snapshot["districts"] = districts
		var breakdown := _city_gdp_breakdown_from_snapshot(district_index, competition, cash_snapshot)
		var gdp_per_minute := int(breakdown.get("net", 0))
		var uses_projects := city_has_project_shares(city)
		var context := {"city": city, "competition": competition, "gdp_per_minute": gdp_per_minute, "project_remainders": {}, "uses_projects": uses_projects}
		if uses_projects:
			city = PROJECT_BRIDGE.assign_city_gdp(city, gdp_per_minute)
			var allocations: Dictionary = city.get("project_gdp_by_player", {}) if city.get("project_gdp_by_player", {}) is Dictionary else {}
			var remainders: Dictionary = (city.get("project_cashflow_remainder_by_player", {}) as Dictionary).duplicate(true) if city.get("project_cashflow_remainder_by_player", {}) is Dictionary else {}
			context["city"] = city
			context["project_remainders"] = remainders
			contexts[str(district_index)] = context
			for player_key_variant in allocations.keys():
				var player_index := int(str(player_key_variant))
				if player_index < 0 or player_index >= players.size() or bool(eliminated.get(str(player_index), false)):
					continue
				sources.append({"source_id": "project:%d:%d" % [district_index, player_index], "source_kind": "project_share", "district_index": district_index, "player_index": player_index, "gdp_per_minute": maxi(0, int(allocations.get(player_key_variant, 0))), "remainder": float(remainders.get(str(player_index), 0.0)), "role_bonus_gdp_per_minute": int(breakdown.get("role_bonus", 0)), "role_bonus_basis_gdp_per_minute": gdp_per_minute, "eligible": true})
			continue
		city["last_cashflow_rate"] = 0
		city["last_income"] = 0
		city["last_gdp_reason"] = "共享城市尚无项目份额，不能按城市 owner 派息"
		district["city"] = city
		districts[district_index] = district
	var settlement_variant: Variant = _cashflow_controller.call("settle_sources", safe_seconds, {"sources": sources})
	var settlement: Dictionary = settlement_variant if settlement_variant is Dictionary else {}
	if not bool(settlement.get("valid", false)):
		return 0
	var paid_players := {}
	var economic_event_intents: Array = []
	for event_variant in settlement.get("payout_events", []):
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant
		var district_index := int(event.get("district_index", -1))
		var player_index := int(event.get("player_index", -1))
		var context_key := str(district_index)
		if not contexts.has(context_key) or player_index < 0 or player_index >= players.size():
			continue
		var context: Dictionary = contexts[context_key]
		var city: Dictionary = context.get("city", {}) if context.get("city", {}) is Dictionary else {}
		var source_kind := str(event.get("source_kind", ""))
		var paid := int(event.get("paid_amount", 0))
		if source_kind == "project_share":
			var remainders: Dictionary = context.get("project_remainders", {}) if context.get("project_remainders", {}) is Dictionary else {}
			remainders[str(player_index)] = float(event.get("remainder_after", 0.0))
			context["project_remainders"] = remainders
		else:
			city["cashflow_remainder"] = float(event.get("remainder_after", 0.0))
		if paid > 0:
			var player: Dictionary = players[player_index] if players[player_index] is Dictionary else {}
			player["cash"] = int(player.get("cash", 0)) + paid
			player["last_cycle_income"] = int(player.get("last_cycle_income", 0)) + paid
			player["last_cashflow_income"] = int(player.get("last_cashflow_income", 0)) + paid
			player["total_city_income"] = int(player.get("total_city_income", 0)) + paid
			player["total_role_income"] = int(player.get("total_role_income", 0)) + int(event.get("role_paid_amount", 0))
			players[player_index] = player
			city["cashflow_paid_total"] = int(city.get("cashflow_paid_total", 0)) + paid
			paid_players[str(player_index)] = true
			economic_event_intents.append({"player_index": player_index, "category": "项目分红" if source_kind == "project_share" else "城市收入", "source": "实时现金流", "amount": paid, "detail": "%s｜%sGDP/min %d" % [_district_name(districts, district_index), "我的项目" if source_kind == "project_share" else "", int(event.get("gdp_per_minute", 0))]})
		context["city"] = city
		contexts[context_key] = context
	for context_key_variant in contexts.keys():
		var district_index := int(str(context_key_variant))
		var context: Dictionary = contexts[context_key_variant]
		var city: Dictionary = context.get("city", {}) if context.get("city", {}) is Dictionary else {}
		if bool(context.get("uses_projects", false)):
			var remainders: Dictionary = context.get("project_remainders", {}) if context.get("project_remainders", {}) is Dictionary else {}
			city["project_cashflow_remainder_by_player"] = remainders
			var remainder_total := 0.0
			for remainder_variant in remainders.values():
				remainder_total += float(remainder_variant)
			city["cashflow_remainder"] = remainder_total
		city["last_cashflow_rate"] = int(context.get("gdp_per_minute", 0))
		city["last_income"] = int(context.get("gdp_per_minute", 0))
		city["competition_matches"] = int(context.get("competition", 0))
		var district: Dictionary = districts[district_index]
		district["city"] = city
		districts[district_index] = district
	var receipt := {"valid": true, "reason": "", "players": players, "districts": districts, "economic_event_intents": economic_event_intents, "cash_snapshot_players": paid_players.keys(), "payout_total": int(settlement.get("payout_total", 0))}
	var apply_result: Dictionary = _world_bridge.call("apply_cashflow_receipt", receipt)
	if not bool(apply_result.get("applied", false)):
		return 0
	_cashflow_settlement_count += 1
	return int(settlement.get("payout_total", 0))


func to_save_data() -> Dictionary:
	return {
		"city_trade_network_runtime": {
			"terms_version": SAVE_TERMS_VERSION,
			"project_schema_version": PROJECT_STATE.PROJECT_SCHEMA_VERSION,
			"project_sequence": _project_sequence,
			"generation_by_slot_id": _generation_by_slot_id.duplicate(true),
			"project_tombstones": _project_tombstones.values(),
			"project_slot_counts": _project_slot_counts.duplicate(true),
			"maximum_project_rank": _maximum_project_rank,
		},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	var runtime_variant: Variant = data.get("city_trade_network_runtime", {})
	var runtime_data: Dictionary = runtime_variant if runtime_variant is Dictionary else {}
	var legacy_migration := runtime_data.is_empty() or str(runtime_data.get("terms_version", "")) != SAVE_TERMS_VERSION
	_project_sequence = maxi(1, int(runtime_data.get("project_sequence", data.get("city_product_project_sequence", _project_sequence))))
	_generation_by_slot_id = (runtime_data.get("generation_by_slot_id", {}) as Dictionary).duplicate(true) if runtime_data.get("generation_by_slot_id", {}) is Dictionary else {}
	_project_tombstones.clear()
	var saved_tombstones: Array = runtime_data.get("project_tombstones", []) if runtime_data.get("project_tombstones", []) is Array else []
	for tombstone_variant in saved_tombstones:
		if tombstone_variant is Dictionary:
			var tombstone: Dictionary = tombstone_variant
			var stable_project_id := str(tombstone.get("project_id", ""))
			if stable_project_id != "":
				_project_tombstones[stable_project_id] = tombstone.duplicate(true)
	var snapshot: Dictionary = _city_state_snapshot().duplicate(true)
	var districts := _districts_from_snapshot(snapshot)
	for district_index in range(districts.size()):
		var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
		var city_variant: Variant = district.get("city", {})
		if not (city_variant is Dictionary) or (city_variant as Dictionary).is_empty():
			continue
		district["city"] = normalize_city(city_variant as Dictionary, district_index)
		districts[district_index] = district
	if _world_bridge != null and _world_bridge.has_method("apply_network_receipt"):
		_world_bridge.call("apply_network_receipt", {"valid": true, "districts": districts, "ensure_city_development_supply": false})
	return {
		"applied": true,
		"project_sequence": _project_sequence,
		"migration_applied": legacy_migration,
		"legacy_flat_key_used": runtime_data.is_empty() and data.has("city_product_project_sequence"),
		"generation_count": _generation_by_slot_id.size(),
		"tombstone_count": _project_tombstones.size(),
	}


func debug_snapshot(_viewer_index: int = -1) -> Dictionary:
	return {
		"controller_ready": _runtime_ready(),
		"controller_authoritative": _runtime_ready(),
		"runtime_owner": "CityTradeNetworkRuntimeController",
		"runtime_cutover_enabled": true,
		"ruleset_id": _ruleset_id,
		"project_ruleset_id": _project_ruleset_id,
		"project_schema_version": PROJECT_STATE.PROJECT_SCHEMA_VERSION,
		"project_slot_counts": _project_slot_counts.duplicate(true),
		"maximum_project_rank": _maximum_project_rank,
		"project_sequence": _project_sequence,
		"generation_count": _generation_by_slot_id.size(),
		"tombstone_count": _project_tombstones.size(),
		"refresh_count": _refresh_count,
		"cashflow_settlement_count": _cashflow_settlement_count,
		"disruption_count": _disruption_count,
		"last_refresh": _last_refresh_receipt.duplicate(true),
		"legacy_route_engine_active": false,
		"legacy_product_identity_active": false,
		"legacy_city_owner_project_authority": false,
	}


func _trade_route_for_product(product_id: String, destination_index: int, snapshot: Dictionary, districts: Array) -> Dictionary:
	if product_id == "" or destination_index < 0 or destination_index >= districts.size():
		return {}
	var best_route: Dictionary = {}
	var best_cost := INF
	for source_index in range(districts.size()):
		if not _district_supplies_product(districts, source_index, product_id, destination_index):
			continue
		var path := _shortest_path(source_index, destination_index, snapshot, districts)
		if path.is_empty():
			continue
		var raw_cost := _path_cost(path, snapshot, districts)
		var public_speed := _path_transport_speed(path, snapshot, districts)
		var destination_city := _district_city(districts, destination_index)
		var market_fact := _market_fact(snapshot, product_id)
		var flow_multiplier := _formula_value("route_flow_multiplier", {"city_multiplier": float(destination_city.get("route_flow_multiplier", 1.0)), "product_multiplier": float(market_fact.get("route_flow_multiplier", 1.0))}, 1.0)
		var min_speed := TRANSPORT_SCORE_MIN
		var max_speed := TRANSPORT_SCORE_MAX * ROUTE_FLOW_MULTIPLIER_MAX
		var flow_speed := clampf(public_speed * flow_multiplier, min_speed, max_speed)
		var flow_amount := _formula_value("route_base_flow", {"source_factor": _district_factor(snapshot, "production_factor_by_district", source_index), "destination_factor": _district_factor(snapshot, "consumption_factor_by_district", destination_index), "relation": minf(float(market_fact.get("supply_demand_ratio", 1.0)), float(market_fact.get("supply_availability_ratio", 1.0)))}, 0.35)
		var cost := raw_cost / maxf(min_speed, flow_speed)
		if cost < best_cost:
			best_cost = cost
			best_route = {"product": product_id, "from": source_index, "to": destination_index, "path": path, "points": _path_points(path, snapshot), "disrupted": _path_is_disrupted(path, districts), "source_type": _trade_source_type(districts, source_index, product_id, destination_index), "cost": cost, "raw_cost": raw_cost, "flow_multiplier": flow_multiplier, "public_speed": public_speed, "flow_speed": flow_speed, "flow_amount": flow_amount}
	return best_route


func _district_supplies_product(districts: Array, district_index: int, product_id: String, destination_index: int) -> bool:
	if district_index < 0 or district_index >= districts.size():
		return false
	var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
	if bool(district.get("destroyed", false)):
		return false
	var city := _district_city(districts, district_index)
	if district_index != destination_index and _city_is_active(city) and _city_product_names(city).has(product_id):
		return true
	return str(district.get("terrain", "land")) == "land" and district.get("products", []) is Array and (district.get("products", []) as Array).has(product_id)


func _trade_source_type(districts: Array, district_index: int, product_id: String, destination_index: int) -> String:
	var city := _district_city(districts, district_index)
	return "城市" if district_index != destination_index and _city_is_active(city) and _city_product_names(city).has(product_id) else "产区"


func _shortest_path(source_index: int, destination_index: int, snapshot: Dictionary, districts: Array) -> Array:
	if source_index < 0 or source_index >= districts.size() or destination_index < 0 or destination_index >= districts.size():
		return []
	if source_index == destination_index:
		return [source_index]
	var distances := {}
	var previous := {}
	var open: Array = []
	for district_index in range(districts.size()):
		distances[district_index] = INF
		open.append(district_index)
	distances[source_index] = 0.0
	while not open.is_empty():
		var current := -1
		var current_distance := INF
		for index_variant in open:
			var district_index := int(index_variant)
			var distance := float(distances.get(district_index, INF))
			if distance < current_distance:
				current_distance = distance
				current = district_index
		if current < 0 or is_inf(current_distance):
			break
		open.erase(current)
		if current == destination_index:
			break
		var current_district: Dictionary = districts[current] if districts[current] is Dictionary else {}
		for neighbor_variant in current_district.get("neighbors", []):
			var neighbor := int(neighbor_variant)
			if neighbor < 0 or neighbor >= districts.size():
				continue
			var next_distance := current_distance + _edge_cost(current, neighbor, snapshot, districts)
			if next_distance < float(distances.get(neighbor, INF)):
				distances[neighbor] = next_distance
				previous[neighbor] = current
	if not previous.has(destination_index):
		return []
	var path: Array = [destination_index]
	var cursor := destination_index
	var guard := 0
	while cursor != source_index and guard < districts.size() + 2:
		guard += 1
		if not previous.has(cursor):
			return []
		cursor = int(previous[cursor])
		path.push_front(cursor)
	return path


func _edge_cost(a: int, b: int, snapshot: Dictionary, districts: Array) -> float:
	var distance_map: Dictionary = snapshot.get("distance_by_edge", {}) if snapshot.get("distance_by_edge", {}) is Dictionary else {}
	var distance := float(distance_map.get("%d:%d" % [a, b], INF))
	if is_inf(distance):
		return INF
	return distance * (_node_cost_multiplier(a, snapshot, districts) + _node_cost_multiplier(b, snapshot, districts)) * 0.5


func _node_cost_multiplier(district_index: int, snapshot: Dictionary, districts: Array) -> float:
	if district_index < 0 or district_index >= districts.size():
		return 2.0
	var district: Dictionary = districts[district_index] if districts[district_index] is Dictionary else {}
	var multiplier := OCEAN_ROUTE_COST_MULTIPLIER if str(district.get("terrain", "land")) == "ocean" else 1.0
	multiplier /= maxf(TRANSPORT_SCORE_MIN, _district_factor(snapshot, "transport_speed_by_district", district_index))
	if bool(district.get("destroyed", false)):
		multiplier += DESTROYED_ROUTE_COST_PENALTY
	if bool(district.get("miasma", false)):
		multiplier += MIASMA_ROUTE_COST_PENALTY
	multiplier += float(district.get("panic", 0)) * PANIC_ROUTE_COST_PER_POINT
	return multiplier


func _path_transport_speed(path: Array, snapshot: Dictionary, districts: Array) -> float:
	if path.is_empty():
		return 1.0
	var total := 0.0
	var count := 0
	for district_index_variant in path:
		var district_index := int(district_index_variant)
		if district_index < 0 or district_index >= districts.size():
			continue
		total += _district_factor(snapshot, "transport_speed_by_district", district_index)
		count += 1
	return clampf(total / maxf(1.0, float(count)), TRANSPORT_SCORE_MIN, TRANSPORT_SCORE_MAX)


func _path_cost(path: Array, snapshot: Dictionary, districts: Array) -> float:
	if path.size() <= 1:
		return 0.0
	var cost := 0.0
	for path_index in range(path.size() - 1):
		cost += _edge_cost(int(path[path_index]), int(path[path_index + 1]), snapshot, districts)
	return cost


func _path_points(path: Array, snapshot: Dictionary) -> Array:
	var points: Array = []
	for district_index_variant in path:
		points.append(_center_data(snapshot, int(district_index_variant)))
	return points


func _path_is_disrupted(path: Array, districts: Array) -> bool:
	if path.is_empty():
		return true
	for district_index_variant in path:
		var district_index := int(district_index_variant)
		if district_index < 0 or district_index >= districts.size() or bool((districts[district_index] as Dictionary).get("destroyed", false)):
			return true
	return false


func _city_gdp_breakdown_from_snapshot(district_index: int, competition_matches_value: int, snapshot: Dictionary) -> Dictionary:
	if _gdp_formula_controller == null or not _gdp_formula_controller.has_method("calculate_city_gdp"):
		return {}
	var value: Variant = _gdp_formula_controller.call("calculate_city_gdp", _city_gdp_formula_snapshot_from_snapshot(district_index, competition_matches_value, snapshot))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _city_gdp_formula_snapshot_from_snapshot(district_index: int, competition_matches_value: int, snapshot: Dictionary) -> Dictionary:
	var districts := _districts_from_snapshot(snapshot)
	if district_index < 0 or district_index >= districts.size():
		return {"active": false}
	var city := _district_city(districts, district_index)
	if not _city_is_active(city):
		return {"active": false}
	var products: Array = []
	for product_variant in city.get("products", []):
		if not (product_variant is Dictionary):
			continue
		var product: Dictionary = product_variant
		var product_id := str(product.get("name", ""))
		var market_fact := _market_fact(snapshot, product_id)
		products.append({"product_id": product_id, "price": int(market_fact.get("price", 0)), "level": int(product.get("level", 1)), "production_factor": _district_factor(snapshot, "production_factor_by_district", district_index), "supply_demand_ratio": float(market_fact.get("supply_demand_ratio", 1.0)), "transport_speed": _district_factor(snapshot, "transport_speed_by_district", district_index)})
	var routes: Array = []
	for route_variant in city.get("trade_routes", []):
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		var product_id := str(route.get("product", ""))
		var market_fact := _market_fact(snapshot, product_id)
		routes.append({"product_id": product_id, "price": int(market_fact.get("price", 0)), "flow_amount": float(route.get("flow_amount", 1.0)), "consumption_factor": _district_factor(snapshot, "consumption_factor_by_district", district_index), "supply_availability_ratio": float(market_fact.get("supply_availability_ratio", 1.0)), "flow_speed": float(route.get("flow_speed", 1.0)), "disrupted": bool(route.get("disrupted", false))})
	var transit_routes: Array = []
	var public_speed := _district_factor(snapshot, "transport_speed_by_district", district_index)
	for city_index_variant in _active_city_indices(districts):
		var other_city := _district_city(districts, int(city_index_variant))
		for route_variant in other_city.get("trade_routes", []):
			if not (route_variant is Dictionary):
				continue
			var route: Dictionary = route_variant
			var product_id := str(route.get("product", ""))
			var path: Array = route.get("path", []) if route.get("path", []) is Array else []
			transit_routes.append({"product_id": product_id, "price": int(_market_fact(snapshot, product_id).get("price", 0)), "flow_amount": float(route.get("flow_amount", 1.0)), "transport_speed": public_speed, "disrupted": bool(route.get("disrupted", false)), "destination_is_district": int(route.get("to", -1)) == district_index, "path_contains_district": path.has(district_index)})
	var role_bonus_map: Dictionary = snapshot.get("role_bonus_by_district", {}) if snapshot.get("role_bonus_by_district", {}) is Dictionary else {}
	var game_time := float(snapshot.get("game_time", 0.0))
	var district: Dictionary = districts[district_index]
	return {"active": true, "revenue_bonus": int(city.get("revenue_bonus", 0)), "role_bonus": int(role_bonus_map.get(str(district_index), 0)), "contract_income": int(city.get("contract_income_bonus", 0)), "products": products, "routes": routes, "transit_routes": transit_routes, "competition_matches": competition_matches_value, "disrupted_route_count": int(city.get("trade_disrupted_routes", 0)), "district_damage": int(district.get("damage", 0)), "control_gdp_penalty": int(city.get("control_gdp_penalty", 0)), "control_pressure_active": float(city.get("control_dispute_until", 0.0)) > game_time, "military_gdp_penalty": int(city.get("military_gdp_penalty", 0)), "military_pressure_active": float(city.get("military_pressure_until", 0.0)) > game_time}


func _active_city_indices(districts: Array) -> Array:
	var result: Array = []
	for district_index in range(districts.size()):
		if _city_is_active(_district_city(districts, district_index)):
			result.append(district_index)
	return result


func _competition_matches(districts: Array, district_index: int) -> int:
	var city := _district_city(districts, district_index)
	if not _city_is_active(city):
		return 0
	var city_owner := int(city.get("owner", -1))
	var own_products := _city_product_names(city)
	var matches := 0
	for other_index_variant in _active_city_indices(districts):
		var other_index := int(other_index_variant)
		if other_index == district_index:
			continue
		var other_city := _district_city(districts, other_index)
		if int(other_city.get("owner", -1)) == city_owner:
			continue
		var other_products := _city_product_names(other_city)
		for product_variant in own_products:
			if other_products.has(product_variant):
				matches += 1
	return matches


func _district_city(districts: Array, district_index: int) -> Dictionary:
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return {}
	var city_variant: Variant = (districts[district_index] as Dictionary).get("city", {})
	return city_variant as Dictionary if city_variant is Dictionary else {}


func _city_is_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _city_product_names(city: Dictionary) -> Array:
	var result: Array = []
	for product_variant in city.get("products", []):
		if product_variant is Dictionary:
			result.append(str((product_variant as Dictionary).get("name", "")))
	return result


func _districts_from_snapshot(snapshot: Dictionary) -> Array:
	var value: Variant = snapshot.get("districts", [])
	return value as Array if value is Array else []


func _world_snapshot() -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("capture_world_snapshot"):
		return {}
	var value: Variant = _world_bridge.call("capture_world_snapshot")
	# The non-owning bridge constructs a fresh pure-data snapshot for every call.
	return value as Dictionary if value is Dictionary else {}


func _economy_snapshot() -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("capture_economy_snapshot"):
		return _world_snapshot()
	var value: Variant = _world_bridge.call("capture_economy_snapshot")
	return value as Dictionary if value is Dictionary else {}


func _city_state_snapshot() -> Dictionary:
	if _world_bridge == null or not _world_bridge.has_method("capture_city_state_snapshot"):
		return _world_snapshot()
	var value: Variant = _world_bridge.call("capture_city_state_snapshot")
	return value as Dictionary if value is Dictionary else {}


func _market_fact(snapshot: Dictionary, product_id: String) -> Dictionary:
	var market: Dictionary = snapshot.get("market_by_product", {}) if snapshot.get("market_by_product", {}) is Dictionary else {}
	var value: Variant = market.get(product_id, {})
	return value as Dictionary if value is Dictionary else {}


func _district_factor(snapshot: Dictionary, key: String, district_index: int) -> float:
	var values: Dictionary = snapshot.get(key, {}) if snapshot.get(key, {}) is Dictionary else {}
	return float(values.get(str(district_index), 1.0))


func _formula_value(formula_id: String, input_snapshot: Dictionary, fallback: float) -> float:
	if _formula_service == null or not _formula_service.has_method("calculate"):
		push_error("CityTradeNetworkRuntimeController formula service unavailable: %s" % formula_id)
		return fallback
	var result_variant: Variant = _formula_service.call("calculate", formula_id, input_snapshot)
	var result: Dictionary = result_variant if result_variant is Dictionary else {}
	if not bool(result.get("ok", false)):
		push_error("CityTradeNetworkRuntimeController formula failed: %s / %s" % [formula_id, str(result.get("reason", "unknown"))])
		return fallback
	return float(result.get("value", fallback))


func _project_rules_snapshot() -> Dictionary:
	if project_rules_profile == null or not project_rules_profile.has_method("validation_snapshot"):
		return {}
	var value: Variant = project_rules_profile.call("validation_snapshot")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _register_city_identity(city: Dictionary) -> void:
	for slot_variant in city.get("project_slots", []):
		if not (slot_variant is Dictionary):
			continue
		var slot: Dictionary = slot_variant
		var stable_slot_id := str(slot.get("slot_id", ""))
		if stable_slot_id != "":
			_generation_by_slot_id[stable_slot_id] = maxi(
				int(_generation_by_slot_id.get(stable_slot_id, 0)),
				int(slot.get("generation", 0))
			)
	for tombstone_variant in city.get("project_tombstones", []):
		if not (tombstone_variant is Dictionary):
			continue
		var tombstone: Dictionary = tombstone_variant
		var stable_project_id := str(tombstone.get("project_id", ""))
		if stable_project_id != "":
			_project_tombstones[stable_project_id] = tombstone.duplicate(true)


func _center_data(snapshot: Dictionary, district_index: int) -> Dictionary:
	var centers: Dictionary = snapshot.get("center_by_district", {}) if snapshot.get("center_by_district", {}) is Dictionary else {}
	var value: Variant = centers.get(str(district_index), {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {"x": 0.0, "y": 0.0}


func _district_name(districts: Array, district_index: int) -> String:
	return str((districts[district_index] as Dictionary).get("name", "区域")) if district_index >= 0 and district_index < districts.size() and districts[district_index] is Dictionary else "区域"


func _runtime_ready() -> bool:
	return _configured and _world_bridge != null and bool(_world_bridge.call("has_world"))


func _failure(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason, "districts": [], "refresh_order": []}


func _sanitize_receipt(receipt: Dictionary) -> Dictionary:
	return {
		"valid": bool(receipt.get("valid", false)),
		"reason": str(receipt.get("reason", "")),
		"refresh_order": (receipt.get("refresh_order", []) as Array).duplicate(true) if receipt.get("refresh_order", []) is Array else [],
		"active_city_count": int(receipt.get("active_city_count", 0)),
		"affected_city_count": int(receipt.get("affected_city_count", 0)),
	}
