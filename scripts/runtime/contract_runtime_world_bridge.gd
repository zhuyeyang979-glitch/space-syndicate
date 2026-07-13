@tool
extends Node
class_name ContractRuntimeWorldBridge

signal runtime_event_forwarded(event: Dictionary)

const REGION_LEVEL_MIN := 1
const REGION_LEVEL_MAX := 5
const ROUTE_FLOW_MULTIPLIER_MAX := 2.8
const HISTORY_LIMIT := 24

var _world: Node
var _product_market_runtime_controller: ProductMarketRuntimeController
var _world_call_count := 0
var _failed_world_call_count := 0


func bind_world(world: Node) -> void:
	_world = world


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func has_world() -> bool:
	return _world != null and is_instance_valid(_world)


func game_time() -> float:
	return float(_world.get("game_time")) if has_world() else 0.0


func player_count() -> int:
	var value: Variant = _world.get("players") if has_world() else []
	return (value as Array).size() if value is Array else 0


func can_view_private_player(viewer_index: int) -> bool:
	return has_world() and _world.has_method("_can_view_player_private_hand") and bool(_world.call("_can_view_player_private_hand", viewer_index))


func contract_facts(source_index: int, target_index: int, selected_product: String = "") -> Dictionary:
	return {
		"player_count": player_count(),
		"game_time": game_time(),
		"selected_product": selected_product,
		"product_catalog": _product_catalog(),
		"source": _district_fact(source_index),
		"target": _district_fact(target_index),
	}


func default_trade_product(district_index: int) -> String:
	var fact := _district_fact(district_index)
	var city: Dictionary = fact.get("city", {}) as Dictionary if fact.get("city", {}) is Dictionary else {}
	for values_variant in [city.get("demands", []), city.get("products", []), fact.get("products", []), fact.get("demands", [])]:
		if values_variant is Array and not (values_variant as Array).is_empty():
			return str((values_variant as Array)[0])
	return ""


func contract_history_entries(preferred_resolution_id: int = -1, limit: int = 1) -> Array:
	var result: Array = []
	if not has_world():
		return result
	if preferred_resolution_id >= 0:
		var preferred := _entry_by_id(preferred_resolution_id)
		if _is_contract_entry(preferred):
			result.append(preferred)
	var history_variant: Variant = _world.get("resolved_card_history")
	var history: Array = history_variant if history_variant is Array else []
	for index in range(history.size() - 1, -1, -1):
		if result.size() >= maxi(1, limit):
			break
		var entry_variant: Variant = history[index]
		if not (entry_variant is Dictionary):
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
		if resolution_id < 0 or resolution_id == preferred_resolution_id or not _is_contract_entry(entry):
			continue
		result.append(entry)
	return result


func remember_contract_parties(viewer_index: int, entry: Dictionary, source: String) -> bool:
	if not has_world():
		return false
	var players_variant: Variant = _world.get("players")
	var players: Array = players_variant if players_variant is Array else []
	if viewer_index < 0 or viewer_index >= players.size() or not (players[viewer_index] is Dictionary):
		return false
	var resolution_id := int(entry.get("resolution_id", entry.get("queued_order", -1)))
	var proposer := int(entry.get("player_index", -1))
	var target_controller := int(entry.get("contract_target_owner", -1))
	if resolution_id < 0 or proposer < 0 or proposer >= players.size() or target_controller < 0 or target_controller >= players.size():
		return false
	var viewer := (players[viewer_index] as Dictionary).duplicate(true)
	var known: Dictionary = (viewer.get("known_contract_parties", {}) as Dictionary).duplicate(true) if viewer.get("known_contract_parties", {}) is Dictionary else {}
	if known.has(str(resolution_id)):
		return false
	known[str(resolution_id)] = {
		"proposer": proposer,
		"target_owner": target_controller,
		"source_district": int(entry.get("contract_source_district", -1)),
		"target_district": int(entry.get("contract_target_district", -1)),
		"response": str(entry.get("contract_response", "")),
	}
	viewer["known_contract_parties"] = known
	players[viewer_index] = viewer
	_world.set("players", players)
	_call_world(&"_record_player_economic_event", [viewer_index, "情报", source, 0, "私下查明轨道#%d合约：出牌方玩家%d，目标商品控制者玩家%d。" % [resolution_id, proposer + 1, target_controller + 1]])
	return true


func apply_response_transaction(transaction: Dictionary) -> Dictionary:
	if not has_world():
		return {"applied": false, "reason": "world_missing"}
	if not _is_pure_data(transaction):
		return {"applied": false, "reason": "transaction_not_pure_data"}
	for method_name_variant in [
		"_remove_district_products", "_remove_city_products_from_city", "_remove_district_demands",
		"_remove_city_demands_from_city", "_add_district_products", "_add_city_products_to_city",
		"_add_district_demands", "_add_city_demands_to_city", "_append_city_public_clue",
		"_transport_score_from_level", "_district_economy_focus_label", "_refresh_city_networks",
		"_record_player_card_income", "_record_player_card_spend",
		"_pulse_district", "_add_action_callout", "_district_center", "_limited_name_list",
	]:
		if not _world.has_method(StringName(str(method_name_variant))):
			return {"applied": false, "reason": "world_contract_missing", "method": str(method_name_variant)}
	var source_index := int(transaction.get("contract_source_district", -1))
	var target_index := int(transaction.get("contract_target_district", -1))
	var target_controller := int(transaction.get("contract_target_owner", -1))
	var response := str(transaction.get("contract_response", ""))
	var products: Array = (transaction.get("contract_products", []) as Array).duplicate(true) if transaction.get("contract_products", []) is Array else []
	if not _valid_source(source_index):
		return {"applied": false, "reason": "source_district_invalid"}
	if not _valid_target(target_index):
		return {"applied": false, "reason": "target_district_invalid"}
	if target_controller < 0 or target_controller >= player_count():
		return {"applied": false, "reason": "target_controller_invalid"}
	if products.is_empty():
		return {"applied": false, "reason": "contract_products_missing"}
	var skill: Dictionary = (transaction.get("skill", {}) as Dictionary).duplicate(true) if transaction.get("skill", {}) is Dictionary else {}
	if skill.is_empty():
		return {"applied": false, "reason": "contract_skill_missing"}
	var receipt := _apply_accept(transaction, skill, products) if response == ContractRuntimeController.RESPONSE_ACCEPTED else _apply_decline(transaction, skill, products)
	if bool(receipt.get("applied", false)):
		forward_runtime_event({
			"kind": "contract_response_resolved",
			"public": true,
			"contract_offer_id": int(transaction.get("contract_offer_id", -1)),
			"response": response,
			"summary": str(receipt.get("public_summary", "")),
		})
	return receipt


func store_contract_result(entry: Dictionary) -> bool:
	if not has_world() or not _is_pure_data(entry):
		return false
	var stored := _entry_by_id(int(entry.get("resolution_id", entry.get("queued_order", -1))))
	if stored.is_empty():
		stored = entry.duplicate(true)
	else:
		for field_variant in [
			"contract_offer_id", "contract_target_owner", "contract_target_project_ids",
			"contract_response", "contract_response_player", "contract_response_time",
			"contract_decision_timer", "contract_decision_started_time", "contract_products",
			"contract_source_district", "contract_target_district", "contract_accept_summary",
			"contract_decline_summary", "contract_result_clue", "aftermath_clue",
			"aftermath_style", "resolved_time",
		]:
			var field := str(field_variant)
			if entry.has(field):
				stored[field] = entry[field]
	var presentation_variant: Variant = _call_world(&"_card_resolution_presentation_snapshot", [stored.get("skill", {}) as Dictionary, stored])
	if presentation_variant is Dictionary:
		stored["aftermath_style"] = str((presentation_variant as Dictionary).get("effect_style", stored.get("aftermath_style", "generic")))
	var stored_variant: Variant = _call_world(&"_store_card_resolution_entry", [stored])
	if bool(stored_variant):
		return true
	var history_variant: Variant = _world.get("resolved_card_history")
	var history: Array = history_variant if history_variant is Array else []
	history.append(stored.duplicate(true))
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	_world.set("resolved_card_history", history)
	return true


func refresh_ui() -> void:
	if has_world() and _world.has_method("_refresh_ui"):
		_world.call("_refresh_ui")


func log_message(message: String) -> void:
	if message != "":
		_call_world(&"_log", [message])


func forward_runtime_event(event: Dictionary) -> void:
	if not _is_pure_data(event):
		push_error("Contract runtime event rejected because it is not pure data.")
		return
	runtime_event_forwarded.emit(event.duplicate(true))
	if has_world() and _world.has_method("_on_contract_runtime_event"):
		_world.call("_on_contract_runtime_event", event.duplicate(true))


func debug_snapshot() -> Dictionary:
	return {
		"bridge_ready": has_world(),
		"world_call_count": _world_call_count,
		"failed_world_call_count": _failed_world_call_count,
		"owns_contract_state": false,
		"owns_contract_rules": false,
		"owns_contract_timer": false,
		"owns_ai_decisions": false,
	}


func _apply_accept(transaction: Dictionary, skill: Dictionary, products: Array) -> Dictionary:
	var source_index := int(transaction.get("contract_source_district", -1))
	var target_index := int(transaction.get("contract_target_district", -1))
	var target_controller := int(transaction.get("contract_target_owner", -1))
	var source_label := str(skill.get("name", "区域供需合约"))
	var add_products := maxi(0, int(skill.get("contract_add_products", 1)))
	var add_demands := maxi(0, int(skill.get("contract_add_demands", 1)))
	var remove_products := maxi(0, int(skill.get("contract_remove_products", 0)))
	var remove_demands := maxi(0, int(skill.get("contract_remove_demands", 0)))
	var source_city := _city(source_index)
	var target_city := _city(target_index)
	var removed_source_products := _array_call(&"_remove_district_products", [source_index, remove_products, products])
	var removed_source_city_products := _array_call(&"_remove_city_products_from_city", [source_city, remove_products, products])
	var removed_target_demands := _array_call(&"_remove_district_demands", [target_index, remove_demands, products])
	var removed_target_city_demands := _array_call(&"_remove_city_demands_from_city", [target_city, remove_demands, products])
	var added_district_products := _array_call(&"_add_district_products", [source_index, products, add_products])
	var added_city_products := _array_call(&"_add_city_products_to_city", [source_city, products, add_products])
	var added_district_demands := _array_call(&"_add_district_demands", [target_index, products, add_demands])
	var added_city_demands := _array_call(&"_add_city_demands_to_city", [target_city, products, add_demands])
	if _city_active(source_city):
		source_city = _append_city_clue(source_city, "%s签约后接入供给：%s。" % [source_label, _limited_names(products, 4)])
		_set_city(source_index, source_city)
	if _city_active(target_city):
		target_city = _append_city_clue(target_city, "%s签约后接入需求：%s；真实签约控制者不公开。" % [source_label, _limited_names(products, 4)])
		_set_city(target_index, target_city)
	var source_delta := _apply_region_delta(source_index, int(skill.get("accept_production_delta", 0)), 0, 0, source_label)
	var target_delta := _apply_region_delta(target_index, 0, int(skill.get("accept_transport_delta", 0)), int(skill.get("accept_consumption_delta", 0)), source_label)
	var route_flow_changed := _apply_route_flow(target_index, skill, source_label)
	var cash_gain := _grant_cash(target_controller, maxi(0, int(skill.get("accept_cash", 0))), "匿名签约奖励", "%s｜%s→%s" % [source_label, _district_name(source_index), _district_name(target_index)])
	_call_world(&"_refresh_city_networks")
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.refresh_prices()
	if not products.is_empty():
		_world.set("selected_trade_product", str(products[0]))
	_call_world(&"_pulse_district", [source_index, Color("#fbbf24")])
	_call_world(&"_pulse_district", [target_index, Color("#f59e0b")])
	_call_world(&"_add_action_callout", ["匿名合约", source_label, "%s→%s签约：%s。" % [_district_name(source_index), _district_name(target_index), _limited_names(products, 4)], Color("#fbbf24"), _district_center(target_index)])
	var changed := cash_gain > 0 or route_flow_changed or bool(source_delta.get("changed", false)) or bool(target_delta.get("changed", false))
	changed = changed or not added_district_products.is_empty() or not added_city_products.is_empty() or not added_district_demands.is_empty() or not added_city_demands.is_empty()
	changed = changed or not removed_source_products.is_empty() or not removed_source_city_products.is_empty() or not removed_target_demands.is_empty() or not removed_target_city_demands.is_empty()
	var summary := "%s匿名签约生效：%s供给区接入%s，%s需求区接入%s；签约奖励%s。出牌者和真实商品控制者仍按规则隐藏。" % [source_label, _district_name(source_index), _limited_names(added_district_products + added_city_products, 4, "无新增"), _district_name(target_index), _limited_names(added_district_demands + added_city_demands, 4, "无新增"), str(transaction.get("contract_accept_summary", "无额外奖励"))]
	log_message(summary)
	return {
		"applied": true,
		"reason": "accepted",
		"changed": changed,
		"cash_delta": cash_gain,
		"public_summary": summary,
		"city_refresh_count": 1,
		"market_refresh_count": 1,
	}


func _apply_decline(transaction: Dictionary, skill: Dictionary, products: Array) -> Dictionary:
	var target_index := int(transaction.get("contract_target_district", -1))
	var target_controller := int(transaction.get("contract_target_owner", -1))
	var response := str(transaction.get("contract_response", ContractRuntimeController.RESPONSE_REJECTED))
	var source_label := str(skill.get("name", "区域供需合约"))
	var penalty_paid := _pay_penalty(target_controller, maxi(0, int(skill.get("decline_cash_penalty", 0))), "匿名拒签惩罚", "%s｜%s→%s" % [source_label, _district_name(int(transaction.get("contract_source_district", -1))), _district_name(target_index)])
	var target_delta := _apply_region_delta(target_index, int(skill.get("decline_production_delta", 0)), int(skill.get("decline_transport_delta", 0)), int(skill.get("decline_consumption_delta", 0)), source_label)
	var route_damage := maxi(0, int(skill.get("decline_route_damage", 0)))
	var city := _city(target_index)
	if _city_active(city):
		if route_damage > 0:
			city["trade_route_damage"] = int(city.get("trade_route_damage", 0)) + route_damage
		city = _append_city_clue(city, "%s被%s：拒签惩罚%s，商品线索%s。" % [source_label, "超时拒签" if response == ContractRuntimeController.RESPONSE_TIMEOUT else "拒签", str(transaction.get("contract_decline_summary", "无额外惩罚")), _limited_names(products, 4)])
		_set_city(target_index, city)
	_call_world(&"_refresh_city_networks")
	if _product_market_runtime_controller != null:
		_product_market_runtime_controller.refresh_prices()
	_call_world(&"_pulse_district", [target_index, Color("#fb7185")])
	_call_world(&"_add_action_callout", ["匿名合约", "超时拒签" if response == ContractRuntimeController.RESPONSE_TIMEOUT else "拒签惩罚", "%s拒绝%s，惩罚：%s。" % [_district_name(target_index), source_label, str(transaction.get("contract_decline_summary", "无额外惩罚"))], Color("#fb7185"), _district_center(target_index)])
	var summary := "%s匿名合约%s：%s未接入%s；拒签惩罚%s，实际罚款¥%d。出牌者仍不公开。" % [source_label, "超时拒签" if response == ContractRuntimeController.RESPONSE_TIMEOUT else "被拒签", _district_name(target_index), _limited_names(products, 4), str(transaction.get("contract_decline_summary", "无额外惩罚")), penalty_paid]
	log_message(summary)
	return {
		"applied": true,
		"reason": response,
		"changed": penalty_paid > 0 or route_damage > 0 or bool(target_delta.get("changed", false)),
		"cash_delta": -penalty_paid,
		"route_damage_delta": route_damage,
		"public_summary": summary,
		"city_refresh_count": 1,
		"market_refresh_count": 1,
	}


func _apply_region_delta(index: int, production_delta: int, transport_delta: int, consumption_delta: int, source: String) -> Dictionary:
	var result := {"changed": false}
	var districts := _districts()
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return result
	var district := (districts[index] as Dictionary).duplicate(true)
	var before_production := clampi(int(district.get("production_level", 2)), REGION_LEVEL_MIN, REGION_LEVEL_MAX)
	var before_transport := clampi(int(district.get("transport_level", 2)), REGION_LEVEL_MIN, REGION_LEVEL_MAX)
	var before_consumption := clampi(int(district.get("consumption_level", 2)), REGION_LEVEL_MIN, REGION_LEVEL_MAX)
	var after_production := clampi(before_production + production_delta, REGION_LEVEL_MIN, REGION_LEVEL_MAX)
	var after_transport := clampi(before_transport + transport_delta, REGION_LEVEL_MIN, REGION_LEVEL_MAX)
	var after_consumption := clampi(before_consumption + consumption_delta, REGION_LEVEL_MIN, REGION_LEVEL_MAX)
	district["production_level"] = after_production
	district["transport_level"] = after_transport
	district["consumption_level"] = after_consumption
	var transport_variant: Variant = _call_world(&"_transport_score_from_level", [after_transport, str(district.get("terrain", "land")) == "ocean"])
	district["transport_score"] = float(transport_variant) if transport_variant != null else float(district.get("transport_score", 1.0))
	var focus_variant: Variant = _call_world(&"_district_economy_focus_label", [str(district.get("economic_focus", "balanced"))])
	district["economic_focus_label"] = str(focus_variant) if focus_variant != null else str(district.get("economic_focus_label", ""))
	var city: Dictionary = district.get("city", {}) as Dictionary
	if _city_active(city):
		city = _append_city_clue(city, "%s使区域经营参数变化：生产%d→%d、交通%d→%d、消费%d→%d。" % [source, before_production, after_production, before_transport, after_transport, before_consumption, after_consumption])
		district["city"] = city
	districts[index] = district
	_world.set("districts", districts)
	result = {
		"changed": before_production != after_production or before_transport != after_transport or before_consumption != after_consumption,
		"before_production": before_production, "after_production": after_production,
		"before_transport": before_transport, "after_transport": after_transport,
		"before_consumption": before_consumption, "after_consumption": after_consumption,
	}
	return result


func _apply_route_flow(target_index: int, skill: Dictionary, source: String) -> bool:
	var city := _city(target_index)
	if not _city_active(city):
		return false
	var flow_multiplier := clampf(float(skill.get("accept_route_flow_multiplier", skill.get("route_flow_multiplier", 1.0))), 1.0, ROUTE_FLOW_MULTIPLIER_MAX)
	if flow_multiplier <= 1.001:
		return false
	var duration_variant: Variant = _call_world(&"_skill_duration_seconds", [skill, "route_flow_seconds", "route_flow_turns", 1])
	var result_variant: Variant = _call_world(&"_card_economy_product_route_formula_result", ["city_route_flow_boon", {"city": city, "route_flow_multiplier": flow_multiplier, "route_flow_seconds": float(duration_variant), "source": source}])
	if not (result_variant is Dictionary) or not bool((result_variant as Dictionary).get("ok", false)):
		return false
	_set_city(target_index, (result_variant as Dictionary).get("city", {}) as Dictionary)
	return bool((result_variant as Dictionary).get("changed", false))


func _grant_cash(player_index: int, amount: int, label: String, detail: String) -> int:
	var players := _players()
	if player_index < 0 or player_index >= players.size() or amount <= 0 or not (players[player_index] is Dictionary):
		return 0
	var player := (players[player_index] as Dictionary).duplicate(true)
	player["cash"] = int(player.get("cash", 0)) + amount
	players[player_index] = player
	_world.set("players", players)
	_call_world(&"_record_player_card_income", [player_index, amount, label, detail])
	return amount


func _pay_penalty(player_index: int, amount: int, label: String, detail: String) -> int:
	var players := _players()
	if player_index < 0 or player_index >= players.size() or amount <= 0 or not (players[player_index] is Dictionary):
		return 0
	var player := (players[player_index] as Dictionary).duplicate(true)
	var paid := mini(amount, maxi(0, int(player.get("cash", 0))))
	if paid <= 0:
		return 0
	player["cash"] = int(player.get("cash", 0)) - paid
	players[player_index] = player
	_world.set("players", players)
	_call_world(&"_record_player_card_spend", [player_index, paid, label, detail])
	return paid


func _district_fact(index: int) -> Dictionary:
	var districts := _districts()
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return {"index": index, "valid": false, "name": "未设", "destroyed": true, "terrain": "", "products": [], "demands": [], "city": {}}
	var district := districts[index] as Dictionary
	var city: Dictionary = district.get("city", {}) as Dictionary
	var city_products: Array = []
	for product_variant in city.get("products", []):
		if product_variant is Dictionary:
			city_products.append(str((product_variant as Dictionary).get("name", "")))
		else:
			city_products.append(str(product_variant))
	var projects: Array = []
	for project_variant in city.get("projects", []):
		if not (project_variant is Dictionary):
			continue
		var project := project_variant as Dictionary
		projects.append({
			"project_id": str(project.get("project_id", "")),
			"product_id": str(project.get("product_id", "")),
			"direction": str(project.get("direction", "")),
			"active": bool(project.get("active", true)),
			"controller_player_index": int(project.get("controller_player_index", -1)),
		})
	return {
		"index": index,
		"valid": true,
		"name": str(district.get("name", "区域")),
		"destroyed": bool(district.get("destroyed", false)),
		"terrain": str(district.get("terrain", "land")),
		"products": _string_array(district.get("products", [])),
		"demands": _string_array(district.get("demands", [])),
		"city": {
			"active": _city_active(city),
			"products": city_products,
			"demands": _string_array(city.get("demands", [])),
			"projects": projects,
		},
	}


func _valid_source(index: int) -> bool:
	var fact := _district_fact(index)
	return bool(fact.get("valid", false)) and not bool(fact.get("destroyed", true)) and str(fact.get("terrain", "")) != "ocean"


func _valid_target(index: int) -> bool:
	var fact := _district_fact(index)
	return bool(fact.get("valid", false)) and not bool(fact.get("destroyed", true)) and bool((fact.get("city", {}) as Dictionary).get("active", false))


func _product_catalog() -> Array:
	var value: Variant = _call_world(&"_product_catalog_names")
	return _string_array(value)


func _districts() -> Array:
	var value: Variant = _world.get("districts") if has_world() else []
	return (value as Array).duplicate(true) if value is Array else []


func _players() -> Array:
	var value: Variant = _world.get("players") if has_world() else []
	return (value as Array).duplicate(true) if value is Array else []


func _city(index: int) -> Dictionary:
	var districts := _districts()
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return {}
	return ((districts[index] as Dictionary).get("city", {}) as Dictionary).duplicate(true)


func _set_city(index: int, city: Dictionary) -> void:
	var districts := _districts()
	if index < 0 or index >= districts.size() or not (districts[index] is Dictionary):
		return
	var district := (districts[index] as Dictionary).duplicate(true)
	district["city"] = city.duplicate(true)
	districts[index] = district
	_world.set("districts", districts)


func _city_active(city: Dictionary) -> bool:
	return not city.is_empty() and bool(city.get("active", true))


func _append_city_clue(city: Dictionary, clue: String) -> Dictionary:
	var value: Variant = _call_world(&"_append_city_public_clue", [city, clue])
	return (value as Dictionary).duplicate(true) if value is Dictionary else city.duplicate(true)


func _district_name(index: int) -> String:
	return str(_district_fact(index).get("name", "未设"))


func _district_center(index: int) -> Vector2:
	var value: Variant = _call_world(&"_district_center", [index])
	return value as Vector2 if value is Vector2 else Vector2.ZERO


func _limited_names(values: Array, limit: int, fallback: String = "") -> String:
	var value: Variant = _call_world(&"_limited_name_list", [values, limit, fallback])
	return str(value) if value != null else fallback


func _entry_by_id(resolution_id: int) -> Dictionary:
	var value: Variant = _call_world(&"_card_resolution_entry_by_id", [resolution_id])
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _is_contract_entry(entry: Dictionary) -> bool:
	return not entry.is_empty() and str((entry.get("skill", {}) as Dictionary).get("kind", "")) == "area_trade_contract"


func _array_call(method_name: StringName, arguments: Array = []) -> Array:
	var value: Variant = _call_world(method_name, arguments)
	return (value as Array).duplicate(true) if value is Array else []


func _call_world(method_name: StringName, arguments: Array = []) -> Variant:
	if not has_world() or not _world.has_method(method_name):
		_failed_world_call_count += 1
		return null
	_world_call_count += 1
	return _world.callv(method_name, arguments)


func _string_array(value: Variant) -> Array:
	var result: Array = []
	if value is Array:
		for item in value:
			var text := str(item)
			if text != "" and not result.has(text):
				result.append(text)
	return result


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
