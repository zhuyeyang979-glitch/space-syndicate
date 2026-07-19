extends RefCounted
class_name PlayerBoardStrategyActionSnapshot

const SCHEMA_VERSION := 1
const FORBIDDEN_KEYS := [
	"players", "cash", "cash_cents", "hand", "slots", "discard", "owner",
	"owner_id", "owner_player_index", "hidden_owner", "city_guesses", "ai_plan",
	"ai_score", "utility_scores", "market", "listing", "quote",
]


static func compose(source: Dictionary) -> Array:
	if not _data_only(source) or _contains_forbidden_key(source):
		return []
	var result: Array = []
	var primary := _action(source.get("primary", {}))
	if not primary.is_empty():
		result.append(primary)
	if bool(source.get("has_economic_source", false)):
		var expansion_action := _route_action(
			"strategy_expand_gdp",
			"扩建GDP源",
			"expand_economic_source",
			"grow_gdp",
			"购买并打出另一张设施牌，在新区域增加持续生产与GDP。",
			"打开区域牌架；优先选择仍有合法设施槽位的区域。",
			"district_supply",
			not bool(source.get("expansion_available", false)),
			"至少还有一个合法设施区域" if bool(source.get("expansion_available", false)) else "当前没有可扩建设施槽位",
			"按当前公开报价"
		)
		expansion_action["source_revision"] = int(source.get("source_revision", 0))
		result.append(expansion_action)
		result.append(_route_action(
			"strategy_protect_routes",
			"护商路",
			"protect_route",
			"protect_routes",
			"突出当前区域的运输路径和天气风险。",
			"优先保护高收入路线，再考虑扩建。",
			"planet_routes"
		))
		var intel_action := _route_action(
			"intel",
			"压竞争",
			"pressure_competition",
			"pressure_competition",
			"打开情报档案，依据公开线索选择竞争目标。",
			"先确认公开证据，不读取对手私密状态。",
			"intel_dossier"
		)
		intel_action["application_intent"] = IntelApplicationIntent.open().to_dictionary()
		result.append(intel_action)
	for action_variant in source.get("context_actions", []):
		var context_action := _action(action_variant)
		if not context_action.is_empty() and not _has_id(result, str(context_action.get("id", ""))):
			result.append(context_action)
		if result.size() >= 5:
			break
	return result


static func _route_action(action_id: String, label: String, kind: String, route: String, consequence: String, suggested_action: String, focus_target: String, disabled := false, requirement := "已建立经济源", cost := "无直接费用") -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": action_id,
		"label": label,
		"state": "等待" if disabled else "可选",
		"active": not disabled,
		"disabled": disabled,
		"tooltip": "%s %s" % [consequence, suggested_action],
		"kind": kind,
		"strategy_route": route,
		"consequence": consequence,
		"suggested_action": suggested_action,
		"focus_target": focus_target,
		"relevant_cost": cost,
		"relevant_requirement": requirement,
	}


static func _action(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var action_id := str(source.get("id", "")).strip_edges()
	var label := str(source.get("label", source.get("text", ""))).strip_edges()
	if action_id.is_empty() or label.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"id": action_id,
		"label": label,
		"state": str(source.get("state", "就绪" if not bool(source.get("disabled", false)) else "等待")),
		"active": not bool(source.get("disabled", false)),
		"disabled": bool(source.get("disabled", false)),
		"tooltip": str(source.get("tooltip", source.get("detail", ""))),
		"kind": str(source.get("kind", "inspect")),
		"strategy_route": str(source.get("strategy_route", "")),
		"consequence": str(source.get("consequence", "")),
		"suggested_action": str(source.get("suggested_action", "")),
		"focus_target": str(source.get("focus_target", "")),
		"relevant_cost": str(source.get("relevant_cost", "")),
		"relevant_requirement": str(source.get("relevant_requirement", "")),
	}


static func _has_id(actions: Array, action_id: String) -> bool:
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")) == action_id:
			return true
	return false


static func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if FORBIDDEN_KEYS.has(str(key_variant).to_lower()) or _contains_forbidden_key((value as Dictionary).get(key_variant)):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_key(item_variant):
				return true
	return false


static func _data_only(value: Variant) -> bool:
	if value is Object or value is Callable:
		return false
	if value is Dictionary:
		for item_variant in (value as Dictionary).values():
			if not _data_only(item_variant):
				return false
	elif value is Array:
		for item_variant in value as Array:
			if not _data_only(item_variant):
				return false
	return true
