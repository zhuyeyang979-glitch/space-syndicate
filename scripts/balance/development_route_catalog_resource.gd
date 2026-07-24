@tool
extends Resource
class_name DevelopmentRouteCatalogResource

@export var catalog_id := "development_routes_v04"
@export var display_name := "Space Syndicate Development Routes v0.4"
@export_multiline var design_note := "Inspector-editable metadata for the seven player development routes. Runtime rules and balance formulas remain owned by their existing services."
@export var route_resources: Array[Resource] = []


func all_routes() -> Array:
	var result: Array = []
	for route_resource in route_resources:
		if route_resource == null or not route_resource.has_method("to_runtime_dictionary"):
			continue
		var payload: Variant = route_resource.call("to_runtime_dictionary")
		if payload is Dictionary:
			result.append((payload as Dictionary).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("sort_order", 0)) < int(right.get("sort_order", 0))
	)
	return result


func route_profile(route_id: String) -> Dictionary:
	for route_variant in all_routes():
		var route: Dictionary = route_variant
		if str(route.get("id", "")) == route_id:
			return route.duplicate(true)
	return {}


func route_id_for_strategy_label(strategy_label: String) -> String:
	for route_variant in all_routes():
		var route: Dictionary = route_variant
		var labels: Array = route.get("strategy_labels", []) if route.get("strategy_labels", []) is Array else []
		if labels.has(strategy_label):
			return str(route.get("id", "tactical_support"))
	return "tactical_support"


func strategy_label_for_skill(skill: Dictionary) -> String:
	var kind := str(skill.get("kind", ""))
	var tags := str(skill.get("tag_text", " "))
	if tags.strip_edges() == "" and skill.get("tags", []) is Array:
		tags = " / ".join(skill.get("tags", []))
	var route_damage := int(skill.get("route_damage", 0))
	var repair_routes := int(skill.get("repair_routes", 0))
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
	var market_pressure := int(skill.get("market_demand_pressure", 0)) + int(skill.get("market_supply_pressure", 0)) + int(skill.get("price_delta", 0))
	if kind == "public_facility": return "城市成长"
	if kind == "card_counter": return "直接互动"
	if kind in ["military_force", "military_command"]: return "战斗破坏"
	if kind in ["monster_card", "monster_bound_action", "monster_lure", "monster_takeover"] or tags.contains("怪兽"): return "怪兽路线"
	if kind in ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"] or tags.contains("互动"): return "直接互动"
	if kind in ["intel_city_reveal", "card_history_public_review", "card_history_subscription"] or tags.contains("情报"): return "情报推理"
	if kind == "news_event" or tags.contains("新闻"): return "新闻信息战"
	if kind == "weather_control" or tags.contains("天气"): return "天气博弈"
	if kind == "product_contract_boon" or int(skill.get("contract_income", 0)) > 0: return "订单经济"
	if route_damage > 0 or economy_delta < 0 or kind in ["route_sabotage", "area_damage"]: return "城市压制"
	if kind in ["city_gdp_derivative", "product_speculation", "market_stabilize"] or market_pressure != 0: return "金融投机"
	if kind == "supply_draw" or int(skill.get("draw_amount", 0)) > 0: return "补给构筑"
	if repair_routes > 0 or economy_delta > 0 or kind in ["city_revenue_boost", "cash_gain", "route_insurance", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "product_growth_boon", "city_contract_boon"] or float(skill.get("route_flow_multiplier", 1.0)) > 1.001 or float(skill.get("growth_multiplier", 1.0)) > 1.001 or int(skill.get("revenue_amount", 0)) > 0 or int(skill.get("cash", 0)) > 0: return "城市成长"
	if int(skill.get("damage", 0)) > 0 or kind in ["attack", "charge_attack", "roll_attack", "mudslide", "miasma_shot", "corrosive_breath"]: return "战斗破坏"
	if int(skill.get("panic", 0)) > 0 or kind == "panic_shift": return "怪兽诱导"
	return "即时战术"


func route_id_for_card(card_facts: Dictionary) -> String:
	var skill: Dictionary = (card_facts.get("skill", card_facts) as Dictionary).duplicate(true) if card_facts.get("skill", card_facts) is Dictionary else {}
	var authored_route_label := str(card_facts.get("route_label", card_facts.get("strategy_route_label", "")))
	var strategy_label := authored_route_label if authored_route_label != "" else strategy_label_for_skill(skill)
	var route_id := route_id_for_strategy_label(strategy_label)
	return route_id if not route_profile(route_id).is_empty() else "tactical_support"


func route_label(route_id: String) -> String:
	return str(route_profile(route_id).get("label", "即时战术"))


func validation_report() -> Dictionary:
	var issues: Array = []
	var route_ids: Array[String] = []
	var sort_orders: Array[int] = []
	for route_resource in route_resources:
		if route_resource == null or not route_resource.has_method("to_runtime_dictionary"):
			issues.append("invalid_route_resource")
			continue
		var payload: Dictionary = route_resource.call("to_runtime_dictionary")
		var route_id := str(payload.get("id", ""))
		var sort_order := int(payload.get("sort_order", -1))
		if route_id == "" or route_ids.has(route_id):
			issues.append("duplicate_or_missing_route:%s" % route_id)
		else:
			route_ids.append(route_id)
		if sort_orders.has(sort_order):
			issues.append("duplicate_sort_order:%d" % sort_order)
		else:
			sort_orders.append(sort_order)
		if route_resource.has_method("validation_issues"):
			for issue_variant in route_resource.call("validation_issues"):
				issues.append("%s:%s" % [route_id, str(issue_variant)])
	return {
		"catalog_id": catalog_id,
		"route_count": route_ids.size(),
		"route_ids": route_ids,
		"valid": issues.is_empty() and route_ids.size() == 7,
		"issues": issues,
	}


func debug_snapshot() -> Dictionary:
	var report := validation_report()
	report["routes"] = all_routes()
	return report
