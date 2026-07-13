@tool
extends Node
class_name GameplayBalanceDiagnosticsRuntimeService

const RuntimeBalanceModelScript := preload("res://scripts/balance/runtime_balance_model.gd")
const REQUIRED_ROUTE_IDS := ["city_growth", "contract_route", "finance_speculation", "monster_pressure", "intel_supply", "direct_interaction"]
const INTERACTION_FAMILIES := {
	"星链拆解": "player_hand_disrupt",
	"影仓牵引": "player_hand_steal",
	"产权冻结": "city_control_dispute",
	"轨道齐射": "global_barrage",
}

@export var route_catalog: DevelopmentRouteCatalogResource

var _world_bridge: GameplayBalanceDiagnosticsWorldBridge
var _runtime_balance_model: RefCounted = RuntimeBalanceModelScript.new()
var _configured := false
var _report_build_count := 0
var _last_snapshot: Dictionary = {}
var _last_snapshot_frame := -1
var _last_snapshot_sample_only := false
var _snapshot_cache_hits := 0


func _ready() -> void:
	if not _configured:
		configure(route_catalog, null)


func configure(catalog: Resource = null, runtime_balance_model: Variant = null) -> Dictionary:
	if catalog is DevelopmentRouteCatalogResource:
		route_catalog = catalog
	if runtime_balance_model is RefCounted:
		_runtime_balance_model = runtime_balance_model
	elif _runtime_balance_model == null:
		_runtime_balance_model = RuntimeBalanceModelScript.new()
	var validation := route_catalog.validation_report() if route_catalog != null else {"valid": false, "issues": ["route_catalog_missing"]}
	_configured = bool(validation.get("valid", false)) and _runtime_balance_model != null
	return {"configured": _configured, "route_catalog": validation}


func set_world_bridge(world_bridge: GameplayBalanceDiagnosticsWorldBridge) -> void:
	_world_bridge = world_bridge


func refresh_world_snapshot(sample_only := false) -> Dictionary:
	_last_snapshot = _world_bridge.build_world_snapshot(sample_only) if _world_bridge != null else {"world_ready": false, "reason": "bridge_missing"}
	_last_snapshot_frame = Engine.get_process_frames()
	_last_snapshot_sample_only = sample_only
	return _last_snapshot.duplicate(true)


func development_routes() -> Array:
	return route_catalog.all_routes() if route_catalog != null else []


func route_profile(route_id: String) -> Dictionary:
	if route_catalog == null:
		return {}
	return route_catalog.route_profile(route_id)


func route_for_card(card_facts: Dictionary) -> Dictionary:
	var skill := _dictionary(card_facts.get("skill", card_facts))
	var card_name := str(card_facts.get("card_name", card_facts.get("card_id", skill.get("name", ""))))
	var authored_route_label := str(card_facts.get("route_label", card_facts.get("strategy_route_label", "")))
	if authored_route_label == "" and card_name != "":
		var known := _card_fact(card_name, _snapshot(false))
		authored_route_label = str(known.get("route_label", ""))
	var route_id := route_catalog.route_id_for_strategy_label(authored_route_label) if route_catalog != null and authored_route_label != "" else _fallback_route_id(skill)
	var profile := route_profile(route_id)
	if profile.is_empty():
		profile = route_profile("tactical_support")
	return profile


func route_id_for_card(card_facts: Dictionary) -> String:
	return str(route_for_card(card_facts).get("id", "tactical_support"))


func route_label(route_id: String) -> String:
	return str(route_profile(route_id).get("label", "即时战术"))


func route_goal(route_id: String) -> String:
	return str(route_profile(route_id).get("goal", "补足当前局势。"))


func route_play_pattern(route_id: String) -> String:
	return str(route_profile(route_id).get("play_pattern", "按局势选择能转化成现金的行动。"))


func route_counterplay(route_id: String) -> String:
	return str(route_profile(route_id).get("counterplay", "观察公开线索，打断它的收益链。"))


func route_ai_plan_hint(route_id: String) -> String:
	return str(route_profile(route_id).get("ai_plan_hint", "按阶段和现金目标调整权重。"))


func card_budget_points_for_id(card_id: String, world_snapshot: Dictionary = {}) -> int:
	var card := _card_fact(card_id, _snapshot_or(world_snapshot, false))
	return card_budget_points(_dictionary(card.get("skill", {})))


func card_budget_points(skill: Dictionary) -> int:
	var points := maxi(2, int(skill.get("cost", 2))) * 10
	points += int(float(abs(int(skill.get("cash", 0)))) / 35.0)
	points += int(float(abs(int(skill.get("revenue_amount", 0)))) / 10.0)
	points += int(float(abs(int(skill.get("contract_income", 0)))) / 12.0)
	points += int(float(abs(int(skill.get("accept_cash", 0)))) / 30.0)
	points += int(float(abs(int(skill.get("decline_cash_penalty", 0)))) / 35.0)
	for key in [
		"production_delta", "transport_delta", "consumption_delta",
		"accept_production_delta", "accept_transport_delta", "accept_consumption_delta",
		"decline_production_delta", "decline_transport_delta", "decline_consumption_delta",
		"price_delta", "market_demand_pressure", "market_supply_pressure",
		"product_level", "product_shift", "demand_shift",
		"contract_add_products", "contract_add_demands", "contract_remove_products", "contract_remove_demands",
		"repair_routes", "route_damage", "decline_route_damage", "draw_amount",
		"damage", "armor", "guard", "ranged_guard", "miasma_count", "reclaim_count", "fixed_skill_count",
		"weather_zone_count", "hand_discard_count", "hand_steal_count",
		"target_cash_penalty", "control_gdp_penalty", "global_barrage_damage", "global_barrage_target_count", "global_barrage_route_damage",
		"counter_strength", "counter_refund", "counter_trace",
		"military_hp", "military_damage", "military_gdp_penalty", "military_strike_gdp_penalty", "military_strike_route_damage",
	]:
		points += abs(int(skill.get(key, 0))) * 7
	points += int(round(absf(float(skill.get("move", 0.0))) / 90.0))
	points += int(round(absf(float(skill.get("range", 0.0))) / 110.0))
	points += int(round(absf(float(skill.get("military_move", 0.0))) / 90.0))
	points += int(round(absf(float(skill.get("military_range", 0.0))) / 110.0))
	points += int(round(absf(float(skill.get("knockback", 0.0))) / 120.0))
	points += int(round(absf(float(skill.get("delay", 0.0))) * 5.0))
	points += int(round(absf(float(skill.get("duration", 0.0))) / 40.0))
	points += int(round(absf(float(skill.get("military_duration_seconds", 0.0))) / 24.0))
	points += int(round(absf(float(skill.get("counter_window_seconds", 0.0))) / 2.0))
	points += int(round(absf(float(skill.get("weather_duration_seconds", 0.0))) / 20.0))
	points += int(round(absf(float(skill.get("hand_lock_seconds", 0.0))) / 3.0))
	points += int(round(absf(float(skill.get("control_block_seconds", 0.0))) / 5.0))
	points += int(round(maxf(0.0, float(skill.get("growth_multiplier", 1.0)) - 1.0) * 24.0))
	points += int(round(maxf(0.0, float(skill.get("route_flow_multiplier", 1.0)) - 1.0) * 24.0))
	points += int(round(maxf(0.0, float(skill.get("accept_route_flow_multiplier", 1.0)) - 1.0) * 18.0))
	var futures_terms := _dictionary(skill.get("futures_terms", {}))
	if str(skill.get("kind", "")) == "product_futures":
		points += int(float(maxi(0, int(futures_terms.get("maximum_gain", 0)))) / 30.0)
		points += int(float(maxi(0, int(futures_terms.get("maximum_loss", 0)))) / 40.0)
		points += maxi(1, int(futures_terms.get("units", 1))) * 5
		points += int(round(maxf(0.0, float(futures_terms.get("multiplier", 1.0)) - 1.0) * 18.0))
	var derivative_terms := _dictionary(skill.get("gdp_derivative_terms", {}))
	if str(skill.get("kind", "")) == "city_gdp_derivative":
		points += int(float(maxi(0, int(derivative_terms.get("maximum_gain", 0)))) / 30.0)
		points += int(float(maxi(0, int(derivative_terms.get("maximum_loss", 0)))) / 40.0)
		points += int(round(maxf(0.0, float(derivative_terms.get("multiplier", 1.0)) - 1.0) * 18.0))
	if str(skill.get("kind", "")) == "monster_card":
		points += int(float(int(skill.get("hp", 0))) / 5.0)
		points += maxi(0, int(skill.get("fixed_skill_count", 0))) * 8
		if str(skill.get("summon_access", "any")) != "any":
			points -= 5
	return maxi(1, points)


func card_budget_band_text(points: int) -> String:
	if points <= 44:
		return "基础频用"
	if points <= 76:
		return "效率扩张"
	if points <= 112:
		return "路线核心"
	return "终端压力"


func card_budget_report(card_facts: Dictionary) -> Dictionary:
	var skill := _dictionary(card_facts.get("skill", card_facts))
	var card_name := str(card_facts.get("card_name", card_facts.get("card_id", skill.get("name", ""))))
	var rank := maxi(1, int(card_facts.get("rank", skill.get("rank", 1))))
	var points := card_budget_points(skill)
	return {
		"card_name": card_name,
		"rank": rank,
		"points": points,
		"band": card_budget_band_text(points),
		"rank_role": _rank_budget_role_text(rank),
		"drivers": _card_budget_driver_facts(skill),
		"gates": _card_budget_gate_facts(card_facts),
	}


func card_budget_text(card_id: String, skill: Dictionary, compact := false, world_snapshot: Dictionary = {}) -> String:
	var snapshot := _snapshot_or(world_snapshot, false)
	var fact := _card_fact(card_id, snapshot)
	if fact.is_empty():
		fact = {"card_name": card_id, "skill": skill, "rank": int(skill.get("rank", 1))}
	var report := card_budget_report(fact)
	var drivers := _join_first(report.get("drivers", []) as Array, 3)
	var gates := _join_first(report.get("gates", []) as Array, 3)
	if compact:
		return "预算:%s｜主强度:%s" % [str(report.get("band", "基础频用")), _short_text(drivers, 34)]
	return "强度预算:%s（%d分）｜%s｜主强度:%s｜制衡:%s" % [
		str(report.get("band", "基础频用")), int(report.get("points", 0)), str(report.get("rank_role", "")), drivers, gates,
	]


func card_balance_pillars(skill: Dictionary, card_facts: Dictionary = {}) -> Array:
	var pillars: Array = []
	var kind := str(skill.get("kind", ""))
	var requirement := _dictionary(card_facts.get("requirement", {}))
	var target := _dictionary(card_facts.get("target", {}))
	var tags := str(skill.get("tags", ""))
	var derivative_terms := _dictionary(skill.get("gdp_derivative_terms", {}))
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0)) + int(skill.get("accept_production_delta", 0)) + int(skill.get("accept_transport_delta", 0)) + int(skill.get("accept_consumption_delta", 0)) + int(skill.get("contract_add_products", 0)) + int(skill.get("contract_add_demands", 0))
	if int(skill.get("cash", 0)) > 0 or int(skill.get("revenue_amount", 0)) > 0 or int(skill.get("contract_income", 0)) > 0 or int(skill.get("accept_cash", 0)) > 0 or economy_delta > 0 or float(skill.get("growth_multiplier", 1.0)) > 1.001 or float(skill.get("route_flow_multiplier", 1.0)) > 1.001 or kind == "product_futures" or (kind == "city_gdp_derivative" and str(derivative_terms.get("direction", "up")) == "up"):
		_append_unique(pillars, "收益")
	if int(skill.get("damage", 0)) > 0 or int(skill.get("route_damage", 0)) > 0 or economy_delta < 0 or int(skill.get("hand_discard_count", 0)) > 0 or int(skill.get("hand_steal_count", 0)) > 0 or int(skill.get("control_gdp_penalty", 0)) > 0 or int(skill.get("global_barrage_damage", 0)) > 0 or kind in ["route_sabotage", "area_damage", "mudslide", "miasma_shot", "corrosive_breath", "panic_shift", "news_event", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage", "military_force", "military_command"]:
		_append_unique(pillars, "压制")
	if int(skill.get("repair_routes", 0)) > 0 or int(skill.get("armor", 0)) > 0 or int(skill.get("guard", 0)) > 0 or int(skill.get("ranged_guard", 0)) > 0 or int(skill.get("counter_strength", 0)) > 0 or int(skill.get("military_hp", 0)) > 0 or kind in ["route_insurance", "market_stabilize", "special_monster_delay", "armor_gain", "card_counter", "military_force"] or bool(derivative_terms.get("insurance", false)):
		_append_unique(pillars, "防御")
	if kind in ["intel_city_reveal", "intel_card_trace", "intel_contract_trace"] or tags.contains("情报"):
		_append_unique(pillars, "信息")
	if tags.contains("互动") or kind in ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage", "card_counter"]:
		_append_unique(pillars, "互动")
	if int(skill.get("draw_amount", 0)) > 0 or int(skill.get("card_access_extra_hops", 0)) > 0 or bool(skill.get("card_access_global", false)) or kind in ["card_access_boon", "supply_draw"]:
		_append_unique(pillars, "补给")
	if kind in ["monster_card", "monster_bound_action", "monster_lure", "monster_takeover"] or tags.contains("怪兽"):
		_append_unique(pillars, "怪兽")
	if kind in ["military_force", "military_command"] or tags.contains("军队") or tags.contains("军令"):
		_append_unique(pillars, "军队")
	if kind in ["area_trade_contract", "product_contract_boon"] or int(skill.get("contract_add_products", 0)) > 0 or int(skill.get("contract_add_demands", 0)) > 0 or int(skill.get("accept_cash", 0)) != 0 or int(skill.get("decline_cash_penalty", 0)) != 0:
		_append_unique(pillars, "合约")
	if kind in ["product_speculation", "product_futures", "market_stabilize", "product_growth_boon", "product_contract_boon"] or int(skill.get("market_demand_pressure", 0)) != 0 or int(skill.get("market_supply_pressure", 0)) != 0:
		_append_unique(pillars, "市场")
	if kind == "city_gdp_derivative":
		_append_unique(pillars, "GDP金融")
	if int(requirement.get("required_share_percent", skill.get("play_region_gdp_share_required", 0))) > 0 or int(requirement.get("cash_cost", skill.get("play_cash", 0))) > 0 or bool(target.get("targets_monster", skill.get("target_monster_required", false))) or kind in ["area_trade_contract", "card_counter", "weather_control"] or (kind == "monster_card" and not bool(skill.get("starter_play_free", false)) and str(skill.get("summon_access", "any")) != "any"):
		_append_unique(pillars, "公开门槛")
	if pillars.is_empty():
		pillars.append("临场")
	return pillars


func development_route_audit(world_snapshot: Dictionary = {}) -> Array:
	var snapshot := _snapshot_or(world_snapshot, false)
	var route_entries := {}
	for route_variant in development_routes():
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		var route_id := str(route.get("id", "tactical_support"))
		route.merge({"card_count": 0, "budget_total": 0, "budget_min": 999999, "budget_max": 0, "avg_budget": 0, "budget_band_counts": {}, "pillar_counts": {}, "balance_notes": [], "balance_status": "待审计", "complete_rank_ladders": 0, "rank_counts": {}, "sample_cards": []}, true)
		route_entries[route_id] = route
	var card_ids := _card_id_set(snapshot)
	var seen_complete := {}
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant
		var skill := _dictionary(card.get("skill", {}))
		var route_id := route_id_for_card(card)
		if not route_entries.has(route_id):
			route_id = "tactical_support"
		var entry: Dictionary = route_entries[route_id]
		var points := card_budget_points(skill)
		entry["card_count"] = int(entry.get("card_count", 0)) + 1
		entry["budget_total"] = int(entry.get("budget_total", 0)) + points
		entry["budget_min"] = mini(int(entry.get("budget_min", points)), points)
		entry["budget_max"] = maxi(int(entry.get("budget_max", points)), points)
		_increment(entry, "budget_band_counts", card_budget_band_text(points))
		_increment(entry, "rank_counts", _roman_rank(int(card.get("rank", 1))))
		for pillar_variant in card_balance_pillars(skill, card):
			_increment(entry, "pillar_counts", str(pillar_variant))
		var samples: Array = entry.get("sample_cards", [])
		if samples.size() < 5:
			samples.append(str(card.get("card_name", "")))
		var family := str(card.get("family", ""))
		var ladder_key := "%s:%s" % [route_id, family]
		if family != "" and not seen_complete.has(ladder_key) and _family_complete(family, card_ids):
			entry["complete_rank_ladders"] = int(entry.get("complete_rank_ladders", 0)) + 1
			seen_complete[ladder_key] = true
		route_entries[route_id] = entry
	var result: Array = []
	for route_variant in development_routes():
		var route_id := str((route_variant as Dictionary).get("id", "tactical_support"))
		var entry: Dictionary = route_entries.get(route_id, {})
		var count := int(entry.get("card_count", 0))
		entry["avg_budget"] = int(round(float(entry.get("budget_total", 0)) / float(count))) if count > 0 else 0
		if count <= 0:
			entry["budget_min"] = 0
		var notes := _development_route_balance_notes(route_id, entry)
		entry["balance_notes"] = notes
		entry["balance_status"] = "健康" if notes.is_empty() else ("可调" if notes.size() <= 2 else "待补强")
		result.append(entry)
	return result


func development_route_pillar_summary(entry: Dictionary) -> String:
	var counts := _dictionary(entry.get("pillar_counts", {}))
	var pieces: Array = []
	for pillar in ["收益", "压制", "防御", "互动", "信息", "补给", "怪兽", "合约", "市场", "GDP金融", "公开门槛", "临场"]:
		var count := int(counts.get(pillar, 0))
		if count > 0:
			pieces.append("%s×%d" % [pillar, count])
		if pieces.size() >= 5:
			break
	return " / ".join(pieces) if not pieces.is_empty() else "暂无"


func development_route_balance_summary(route_id: String, world_snapshot: Dictionary = {}) -> String:
	for entry_variant in development_route_audit(world_snapshot):
		var entry: Dictionary = entry_variant
		if str(entry.get("id", "")) != route_id:
			continue
		var min_budget := int(entry.get("budget_min", 0))
		var max_budget := int(entry.get("budget_max", 0))
		return "强度区间:%s-%s（%d-%d分，均%d）｜预算分布:%s｜支点:%s｜平衡:%s｜检查:%s｜打法:%s｜反制:%s" % [card_budget_band_text(min_budget), card_budget_band_text(max_budget), min_budget, max_budget, int(entry.get("avg_budget", 0)), _budget_band_summary(entry), development_route_pillar_summary(entry), str(entry.get("balance_status", "待审计")), _balance_note_summary(entry), route_play_pattern(route_id), route_counterplay(route_id)]
	return "强度区间:暂无｜预算分布:暂无｜支点:暂无｜平衡:待补强｜打法:%s｜反制:%s" % [route_play_pattern(route_id), route_counterplay(route_id)]


func direct_interaction_balance_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var families := {}
	var entries: Array = []
	var issues: Array = []
	for family_variant in INTERACTION_FAMILIES.keys():
		var family := str(family_variant)
		var expected_kind := str(INTERACTION_FAMILIES[family])
		var summary := {"kind": expected_kind, "cards": [], "max_effect_score": 0, "max_gate_score": 0, "max_public_clue_score": 0, "max_share_required": 0, "counter_available": bool(snapshot.get("counter_card_exists", false))}
		var previous_effect := -1
		var previous_gate := -1
		for rank in range(1, 5):
			var card_name := "%s%d" % [family, rank]
			var card := _card_fact(card_name, snapshot)
			if card.is_empty():
				issues.append("%s缺少%d级" % [family, rank])
				continue
			var skill := _dictionary(card.get("skill", {}))
			var entry := _direct_interaction_entry(card)
			entries.append(entry)
			(summary["cards"] as Array).append(card_name)
			for field in ["effect_score", "gate_score", "public_clue_score", "required_share_percent"]:
				var summary_field := "max_share_required" if field == "required_share_percent" else "max_%s" % field
				summary[summary_field] = maxi(int(summary.get(summary_field, 0)), int(entry.get(field, 0)))
			var effect_score := int(entry.get("effect_score", 0))
			var gate_score := int(entry.get("gate_score", 0))
			if str(skill.get("kind", "")) != expected_kind:
				issues.append("%s类型错误:%s" % [card_name, str(skill.get("kind", ""))])
			if previous_effect >= 0 and effect_score < previous_effect:
				issues.append("%s效果压力梯度倒退" % card_name)
			if previous_gate >= 0 and gate_score < previous_gate:
				issues.append("%s门槛梯度倒退" % card_name)
			if int(entry.get("required_share_percent", 0)) <= 0:
				issues.append("%s缺少地区GDP份额门槛" % card_name)
			if effect_score >= 150 and gate_score < 120:
				issues.append("%s强效果门槛过低" % card_name)
			if effect_score >= 150 and int(entry.get("public_clue_score", 0)) < 78:
				issues.append("%s强效果公开线索不足" % card_name)
			previous_effect = effect_score
			previous_gate = gate_score
		families[family] = summary
	return {"ok": issues.is_empty(), "issues": issues, "families": families, "entries": entries, "summary": "直接互动护栏：点名玩家或公开城市、地区GDP份额门槛、相位响应沙漏、公开结果线索，强效果随等级提高但门槛和线索同步提高。"}


func role_budget(role_card: Dictionary) -> Dictionary:
	var report := {"points": 0, "drivers": [], "tags": [], "positive_field_count": 0, "band": "未配置", "summary": ""}
	var starting_cash := int(role_card.get("starting_cash_delta", role_card.get("starting_cash_bonus", 0)))
	if starting_cash != 0:
		_role_budget_add(report, "开局资金" if starting_cash > 0 else "开局资金代价", maxi(1, int(ceil(absf(float(starting_cash)) / 5.0))), "opening")
	var components := [
		["resource_cash_amount", "商品现金流", 1.0, "economy"], ["monster_upgrade_cash", "升兽现金", 0.25, "monster"],
		["intel_city_reveal_charges", "城市归属侦测", 42.0, "intel"], ["intel_card_trace_charges", "卡牌追帧", 48.0, "intel"],
		["intel_contract_trace_charges", "合约回溯", 40.0, "intel"], ["city_guess_reward_bonus", "城市竞猜奖励", 0.25, "intel"],
		["card_owner_guess_discount", "卡牌竞猜折扣", 0.8, "intel"], ["card_owner_guess_bonus", "卡牌竞猜奖励", 0.8, "intel"],
		["contract_flow_discount", "合约GDP门槛折扣", 34.0, "contract"], ["card_access_extra_hops", "远程购牌", 44.0, "supply"],
		["monster_control_limit_bonus", "怪兽归属上限", 58.0, "monster"], ["military_control_limit_bonus", "军队归属上限", 52.0, "military"],
	]
	for component in components:
		var raw := int(role_card.get(str(component[0]), 0))
		if raw > 0:
			_role_budget_add(report, str(component[1]), maxi(1, int(ceil(float(raw) * float(component[2])))), str(component[3]))
	if str(role_card.get("bonus_card_product", "")) != "":
		_role_budget_add(report, "区域赠牌", 42, "supply")
	if bool(role_card.get("card_access_global", false)):
		_role_budget_add(report, "全图购牌", 90, "supply")
	if bool(role_card.get("monster_cards_as_counter", false)):
		_role_budget_add(report, "怪兽牌否决", 64, "counter")
	var points := int(report.get("points", 0))
	report["positive_field_count"] = (report.get("drivers", []) as Array).size()
	report["band"] = _role_budget_band(points)
	report["summary"] = "%s｜强度预算%d｜%s" % [str(role_card.get("name", "角色卡")), points, str(report.get("band", "未配置"))]
	return report


func apply_role_balance_metadata(role: Dictionary) -> Dictionary:
	var result := role.duplicate(true)
	var budget := role_budget(result)
	result["balance_budget"] = int(budget.get("points", 0))
	result["balance_band"] = str(budget.get("band", "未配置"))
	result["balance_tags"] = _array(budget.get("tags", []))
	result["balance_drivers"] = _array(budget.get("drivers", []))
	result["balance_summary"] = str(budget.get("summary", ""))
	return result


func role_balance_audit(world_snapshot: Dictionary = {}) -> Dictionary:
	var roles := _array(_snapshot_or(world_snapshot, false).get("roles", []))
	var entries: Array = []
	var duplicate_names: Array = []
	var missing_budget_roles: Array = []
	var missing_positive_roles: Array = []
	var seen_names := {}
	var band_counts := {}
	var min_budget := 0
	var max_budget := 0
	var total_budget := 0
	for role_index in range(roles.size()):
		var role: Dictionary = roles[role_index] if roles[role_index] is Dictionary else {}
		var enriched := apply_role_balance_metadata(role)
		var role_name := str(enriched.get("name", "角色卡%d" % role_index))
		if seen_names.has(role_name):
			duplicate_names.append(role_name)
		seen_names[role_name] = true
		var budget := role_budget(enriched)
		var points := int(budget.get("points", 0))
		min_budget = points if role_index == 0 else mini(min_budget, points)
		max_budget = points if role_index == 0 else maxi(max_budget, points)
		total_budget += points
		var band := str(budget.get("band", "未配置"))
		band_counts[band] = int(band_counts.get(band, 0)) + 1
		if int(enriched.get("balance_budget", 0)) <= 0 or _array(enriched.get("balance_drivers", [])).is_empty():
			missing_budget_roles.append(role_name)
		if points <= 0 or _array(budget.get("drivers", [])).is_empty() or _array(budget.get("tags", [])).is_empty():
			missing_positive_roles.append(role_name)
		entries.append({"index": role_index, "name": role_name, "points": points, "band": band, "tags": _array(budget.get("tags", [])), "drivers": _array(budget.get("drivers", []))})
	return {"role_count": roles.size(), "entries": entries, "duplicate_names": duplicate_names, "missing_budget_roles": missing_budget_roles, "missing_positive_roles": missing_positive_roles, "budget_min": min_budget, "budget_max": max_budget, "budget_average": float(total_budget) / float(roles.size()) if not roles.is_empty() else 0.0, "budget_band_counts": band_counts}


func role_balance_audit_summary(report: Dictionary = {}) -> String:
	var audit := report if not report.is_empty() else role_balance_audit()
	var band_counts := _dictionary(audit.get("budget_band_counts", {}))
	var parts: Array = []
	for band in ["轻量", "标准", "强力", "高风险强力", "未配置"]:
		if int(band_counts.get(band, 0)) > 0:
			parts.append("%s×%d" % [band, int(band_counts.get(band, 0))])
	return "角色预算审计：%d张｜强度%d-%d｜均值%.1f｜分布%s｜重复%d｜缺预算%d" % [int(audit.get("role_count", 0)), int(audit.get("budget_min", 0)), int(audit.get("budget_max", 0)), float(audit.get("budget_average", 0.0)), "，".join(parts), _array(audit.get("duplicate_names", [])).size(), _array(audit.get("missing_budget_roles", [])).size()]


func development_route_pressure_audit(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var route_entries := {}
	var primary_counts := _dictionary(snapshot.get("ai_primary_route_counts", {}))
	for route_variant in development_routes():
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		var route_id := str(route.get("id", "tactical_support"))
		route.merge({"card_count": 0, "families": [], "complete_rank_ladders": 0, "money_score": 0, "disruption_score": 0, "protection_score": 0, "intel_supply_score": 0, "gate_score": 0, "public_clue_score": 0, "counterplay_score": 0, "total_pressure": 0, "max_single_card_pressure": 0, "sample_cards": [], "primary_ai_profiles": int(primary_counts.get(route_id, 0)), "notes": [], "status": "待审计", "pillar_counts": {}}, true)
		route_entries[route_id] = route
	var card_ids := _card_id_set(snapshot)
	var seen_ladders := {}
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant
		var card_entry := _pressure_card_entry(card)
		var route_id := str(card_entry.get("route_id", "tactical_support"))
		if not route_entries.has(route_id):
			route_id = "tactical_support"
		var entry: Dictionary = route_entries[route_id]
		entry["card_count"] = int(entry.get("card_count", 0)) + 1
		for field in ["money_score", "disruption_score", "protection_score", "intel_supply_score", "gate_score", "public_clue_score", "total_pressure"]:
			entry[field] = int(entry.get(field, 0)) + int(card_entry.get(field, 0))
		entry["max_single_card_pressure"] = maxi(int(entry.get("max_single_card_pressure", 0)), int(card_entry.get("total_pressure", 0)))
		for pillar_variant in _array(card_entry.get("pillars", [])):
			_increment(entry, "pillar_counts", str(pillar_variant))
		var family := str(card.get("family", ""))
		var families: Array = entry.get("families", [])
		if family != "" and not families.has(family):
			families.append(family)
		var samples: Array = entry.get("sample_cards", [])
		if samples.size() < 6:
			samples.append(str(card.get("card_name", "")))
		var ladder_key := "%s:%s" % [route_id, family]
		if family != "" and not seen_ladders.has(ladder_key) and _family_complete(family, card_ids):
			entry["complete_rank_ladders"] = int(entry.get("complete_rank_ladders", 0)) + 1
			seen_ladders[ladder_key] = true
		route_entries[route_id] = entry
	var routes: Array = []
	var issues: Array = []
	var required_ok := true
	for route_variant in development_routes():
		var route_id := str((route_variant as Dictionary).get("id", "tactical_support"))
		var entry: Dictionary = route_entries.get(route_id, {})
		var counterplay_score := int(entry.get("public_clue_score", 0)) + int(round(float(entry.get("gate_score", 0)) * 0.45))
		if str(entry.get("counterplay", "")) != "":
			counterplay_score += 90
		if _has_pillar(entry, "防御"):
			counterplay_score += 40
		entry["counterplay_score"] = counterplay_score
		var notes := _pressure_notes(route_id, entry)
		entry["notes"] = notes
		entry["status"] = "可追目标" if notes.is_empty() else ("需观察" if notes.size() <= 2 else "需补强")
		if bool(entry.get("required_for_ai_baseline", false)) and not notes.is_empty():
			required_ok = false
			for note_variant in notes:
				issues.append("%s:%s" % [route_label(route_id), str(note_variant)])
		routes.append(entry)
	return {"ok": required_ok, "issues": issues, "routes": routes, "summary": _pressure_summary(routes)}


func development_route_pressure_card_entry(card_name: String, skill: Dictionary, world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var card := _card_fact(card_name, snapshot)
	if card.is_empty():
		card = {
			"card_id": card_name,
			"card_name": card_name,
			"rank": int(skill.get("rank", 1)),
			"skill": skill.duplicate(true),
		}
	if not card.has("skill"):
		card["skill"] = skill.duplicate(true)
	return _pressure_card_entry(card)


func product_ecosystem_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var run_products := _array(snapshot.get("run_products", []))
	var route_counts := {}
	var category_counts := {}
	var strategy_counts := {}
	var hotspots: Array = []
	var ocean_catalog_count := 0
	var run_ocean_count := 0
	var related_count := 0
	var monster_focus_count := 0
	var complete_count := 0
	var product_by_name := {}
	for product_variant in _array(snapshot.get("products", [])):
		var product: Dictionary = product_variant if product_variant is Dictionary else {}
		var product_name := str(product.get("name", ""))
		product_by_name[product_name] = product
		var profile := _dictionary(product.get("profile", {}))
		if str(profile.get("terrain", "land")) == "ocean":
			ocean_catalog_count += 1
		if bool(product.get("profile_complete", false)):
			complete_count += 1
	for product_variant in run_products:
		var product_name := str(product_variant)
		var product: Dictionary = product_by_name.get(product_name, {})
		var profile := _dictionary(product.get("profile", {}))
		if str(profile.get("terrain", "land")) == "ocean":
			run_ocean_count += 1
		var route := str(profile.get("route", "通用商业线"))
		var category := str(profile.get("category", "商品"))
		route_counts[route] = int(route_counts.get(route, 0)) + 1
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		var primary := _dictionary(product.get("primary_strategy", {}))
		var strategy := str(primary.get("label", "观察"))
		strategy_counts[strategy] = int(strategy_counts.get(strategy, 0)) + 1
		hotspots.append({"product": product_name, "label": strategy, "score": int(primary.get("score", 0))})
		if int(product.get("related_card_count", 0)) > 0:
			related_count += 1
		if int(product.get("monster_focus_count", 0)) > 0:
			monster_focus_count += 1
	hotspots.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := int(left.get("score", 0)); var right_score := int(right.get("score", 0))
		return left_score > right_score if left_score != right_score else str(left.get("product", "")) < str(right.get("product", ""))
	)
	var top_hotspots: Array = []
	for index in range(mini(5, hotspots.size())):
		var hotspot: Dictionary = hotspots[index]
		top_hotspots.append("%s/%s%d" % [str(hotspot.get("product", "商品")), str(hotspot.get("label", "观察")), int(hotspot.get("score", 0))])
	var district_product_slots := 0
	var district_demand_slots := 0
	var city_product_slots := 0
	var city_demand_slots := 0
	for district_variant in _array(snapshot.get("districts", [])):
		var district: Dictionary = district_variant if district_variant is Dictionary else {}
		district_product_slots += _array(district.get("products", [])).size()
		district_demand_slots += _array(district.get("demands", [])).size()
		if bool(district.get("city_active", false)):
			city_product_slots += _array(district.get("city_products", [])).size()
			city_demand_slots += _array(district.get("city_demands", [])).size()
	return {"catalog_count": product_by_name.size(), "ocean_catalog_count": ocean_catalog_count, "run_product_count": run_products.size(), "run_ocean_count": run_ocean_count, "run_land_count": maxi(0, run_products.size() - run_ocean_count), "district_product_slots": district_product_slots, "district_demand_slots": district_demand_slots, "active_city_product_slots": city_product_slots, "active_city_demand_slots": city_demand_slots, "route_counts": route_counts, "category_counts": category_counts, "strategy_counts": strategy_counts, "strategy_hotspots": hotspots, "top_hotspots": top_hotspots, "related_card_product_count": related_count, "monster_focus_product_count": monster_focus_count, "profile_complete_count": complete_count}


func card_supply_product_filter_audit(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var run_products := _array(snapshot.get("run_products", []))
	var run_pool := _array(snapshot.get("run_pool", []))
	var allowed_fixed: Array = []
	var excluded_fixed: Array = []
	var current_product_cards: Array = []
	var violations: Array = []
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant
		if int(card.get("rank", 1)) != 1:
			continue
		var card_name := str(card.get("card_name", ""))
		var skill := _dictionary(card.get("skill", {}))
		var required := _fixed_product_requirements(skill)
		if not required.is_empty():
			if _products_available(required, run_products):
				_append_unique(allowed_fixed, card_name)
				if not run_pool.has(card_name):
					violations.append("%s需要%s且本局存在，但未进入本局卡池" % [card_name, "、".join(required)])
			else:
				_append_unique(excluded_fixed, card_name)
				if run_pool.has(card_name):
					violations.append("%s需要%s，但本局商品不存在仍进入卡池" % [card_name, "、".join(required)])
		elif _uses_current_product(skill):
			_append_unique(current_product_cards, card_name)
	var monster_cards := _array(snapshot.get("monster_cards", []))
	var allowed_monster_cards := _array(snapshot.get("allowed_monster_cards", []))
	var district_card_count := 0
	var local_product_cards := 0
	var fixed_fallbacks := 0
	for district_variant in _array(snapshot.get("districts", [])):
		var district: Dictionary = district_variant if district_variant is Dictionary else {}
		var local_products := _district_products(district)
		for card_name_variant in _array(district.get("card_choices", [])):
			var card_name := str(card_name_variant)
			var card := _card_fact(card_name, snapshot)
			if card.is_empty():
				continue
			district_card_count += 1
			if not run_pool.has(card_name):
				violations.append("%s出现在%s，但不属于本局卡池" % [card_name, str(district.get("name", "区域"))])
			var skill := _dictionary(card.get("skill", {}))
			if str(skill.get("kind", "")) == "monster_card":
				if str(district.get("monster_guarantee_card", "")) == card_name:
					fixed_fallbacks += 1
				else:
					local_product_cards += 1
			else:
				var required := _fixed_product_requirements(skill)
				if not required.is_empty() and _products_available(required, local_products):
					local_product_cards += 1
				elif _uses_current_product(skill) and not local_products.is_empty():
					local_product_cards += 1
	return {"run_products": run_products, "run_card_count": run_pool.size(), "district_card_count": district_card_count, "local_product_card_count": local_product_cards, "fixed_monster_ecology_fallback_count": fixed_fallbacks, "allowed_fixed_cards": allowed_fixed, "excluded_fixed_cards": excluded_fixed, "current_product_cards": current_product_cards, "monster_allowed_cards": allowed_monster_cards, "monster_excluded_cards": [], "monster_fallback_active": false, "violations": violations, "monster_catalog_count": monster_cards.size()}


func card_supply_layer_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var audit := card_supply_product_filter_audit(snapshot)
	var unique_cards: Array = []
	var district_count := 0
	var accessible_count := 0
	var source_counts := {}
	for district_variant in _array(snapshot.get("districts", [])):
		var district: Dictionary = district_variant if district_variant is Dictionary else {}
		var accessible := ["landed", "adjacent", "extended", "global"].has(str(district.get("access_kind", "")))
		var sources := _dictionary(district.get("card_sources", {}))
		for card_variant in _array(district.get("card_choices", [])):
			var card_name := str(card_variant)
			district_count += 1
			_append_unique(unique_cards, card_name)
			if accessible:
				accessible_count += 1
			var source := str(sources.get(card_name, "区域补给"))
			source_counts[source] = int(source_counts.get(source, 0)) + 1
	return {"codex_count": _cards(snapshot).size(), "run_pool_count": _array(snapshot.get("run_pool", [])).size(), "district_supply_count": district_count, "district_unique_count": unique_cards.size(), "accessible_supply_count": accessible_count, "run_product_count": _array(audit.get("run_products", [])).size(), "local_product_card_count": int(audit.get("local_product_card_count", 0)), "filtered_fixed_count": _array(audit.get("excluded_fixed_cards", [])).size(), "filtered_monster_count": 0, "filter_violation_count": _array(audit.get("violations", [])).size(), "source_counts": source_counts}


func district_reserved_supply_audit(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var issues: Array = []
	var monster_occurrences := {}
	var development_slots := 0
	var land_development_slots := 0
	var districts := _array(snapshot.get("districts", []))
	for district_variant in districts:
		var district: Dictionary = district_variant if district_variant is Dictionary else {}
		var city_cards: Array = _array(district.get("city_development_cards", []))
		var monster_cards: Array = _array(district.get("monster_cards", []))
		var guaranteed_city_card := str(district.get("city_development_guarantee_card", ""))
		var guaranteed_monster_card := str(district.get("monster_guarantee_card", ""))
		for card_variant in _array(district.get("card_choices", [])):
			var card_name := str(card_variant)
			if city_cards.has(card_name) or monster_cards.has(card_name):
				continue
			var skill := _dictionary(_card_fact(card_name, snapshot).get("skill", {}))
			if card_name == guaranteed_city_card or str(skill.get("kind", "")) == "city_development":
				city_cards.append(card_name)
			elif card_name == guaranteed_monster_card or str(skill.get("kind", "")) == "monster_card":
				monster_cards.append(card_name)
		development_slots += city_cards.size()
		if str(district.get("terrain", "land")) == "land":
			land_development_slots += city_cards.size()
		if city_cards.size() != 1:
			issues.append("%s城市发展固定槽=%d" % [str(district.get("name", "区域")), city_cards.size()])
		if monster_cards.size() != 1:
			issues.append("%s固定怪兽槽=%d" % [str(district.get("name", "区域")), monster_cards.size()])
		elif not monster_cards.is_empty():
			monster_occurrences[monster_cards[0]] = int(monster_occurrences.get(monster_cards[0], 0)) + 1
		var choice_count := _array(district.get("card_choices", [])).size()
		if choice_count < 4 or choice_count > 5:
			issues.append("%s牌架数量=%d" % [str(district.get("name", "区域")), choice_count])
	var duplicate_monsters: Array = []
	for card_variant in monster_occurrences.keys():
		if int(monster_occurrences[card_variant]) > 1:
			duplicate_monsters.append(str(card_variant))
	var capacity_shortfall := maxi(0, districts.size() - _array(snapshot.get("allowed_monster_cards", [])).size())
	return {"ok": issues.is_empty() and (capacity_shortfall > 0 or duplicate_monsters.is_empty()), "issues": issues, "district_count": districts.size(), "development_slot_count": development_slots, "land_development_slot_count": land_development_slots, "monster_slot_count": _sum_dictionary_values(monster_occurrences), "unique_monster_card_count": monster_occurrences.size(), "duplicate_monster_cards": duplicate_monsters, "monster_unique_capacity_shortfall": capacity_shortfall, "monster_uniqueness_capacity_limited": capacity_shortfall > 0}


func card_one_glance_audit_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var failures: Array = []
	var generic: Array = []
	var route_counts := {}
	var use_case_counts := {}
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant
		if int(card.get("rank", 1)) != 1:
			continue
		var use_case := str(card.get("use_case", "")).strip_edges()
		var quick_effect := str(card.get("quick_effect", "")).strip_edges()
		var route := str(card.get("route_label", "")).strip_edges()
		var art_stats := str(card.get("art_stats", "")).strip_edges()
		var chip_texts := _array(card.get("chip_texts", []))
		var entry_failures: Array = []
		if use_case == "": entry_failures.append("缺用途")
		if use_case.length() > 14: entry_failures.append("用途过长")
		if quick_effect == "" or not quick_effect.begins_with(use_case): entry_failures.append("短效果未以用途开头")
		if route == "": entry_failures.append("缺路线")
		if art_stats == "": entry_failures.append("缺视觉/数值锚点")
		var generic_use_case := ["临场改局势", "即时改变局势", "即时战术"].has(use_case)
		var entry := {"card_name": str(card.get("card_name", "")), "use_case": use_case, "quick_effect": quick_effect, "route": route, "chips": chip_texts, "generic_use_case": generic_use_case, "passed": entry_failures.is_empty() and not generic_use_case, "failures": entry_failures}
		route_counts[route] = int(route_counts.get(route, 0)) + 1
		use_case_counts[use_case] = int(use_case_counts.get(use_case, 0)) + 1
		if generic_use_case: generic.append(entry)
		if not bool(entry.get("passed", false)): failures.append(entry)
	return {"checked_count": route_counts.values().reduce(func(total, value): return int(total) + int(value), 0), "passed": failures.is_empty() and generic.is_empty(), "failure_count": failures.size(), "generic_use_case_count": generic.size(), "failures": failures.slice(0, 16), "generic_examples": generic.slice(0, 16), "route_counts": route_counts, "use_case_counts": use_case_counts}


func card_one_glance_source(card_name: String, world_snapshot: Dictionary = {}) -> Dictionary:
	var card := _card_fact(card_name, _snapshot_or(world_snapshot, false))
	if card.is_empty():
		return {}
	return {
		"card_name": card_name,
		"use_case": str(card.get("use_case", "")),
		"quick_effect": str(card.get("quick_effect", "")),
		"route": str(card.get("route_label", "")),
		"route_label": str(card.get("route_label", "")),
		"art_stats": str(card.get("art_stats", "")),
		"chip_texts": _array(card.get("chip_texts", [])),
		"requirement": _dictionary(card.get("requirement", {})),
		"target": _dictionary(card.get("target", {})),
	}


func monster_ecology_balance_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var entries: Array = []
	var issues: Array = []
	var movement_counts := {}
	var signatures := {}
	var role_tag_counts := {}
	var resource_goods := {}
	var focus_count := 0
	var boon_count := 0
	var art_count := 0
	var late_shift_count := 0
	var bound_ladder_count := 0
	for monster_variant in _array(snapshot.get("monsters", [])):
		var entry := _monster_ecology_entry(monster_variant if monster_variant is Dictionary else {})
		entries.append(entry)
		var monster_name := str(entry.get("name", "怪兽"))
		var movement := str(entry.get("movement_archetype", "通用"))
		movement_counts[movement] = int(movement_counts.get(movement, 0)) + 1
		var signature := str(entry.get("action_signature", ""))
		if signature != "": signatures[signature] = int(signatures.get(signature, 0)) + 1
		for tag_variant in _array(entry.get("role_tags", [])):
			var tag := str(tag_variant); role_tag_counts[tag] = int(role_tag_counts.get(tag, 0)) + 1
		for product_variant in _array(entry.get("resource_focus", [])):
			if str(product_variant) != "": resource_goods[str(product_variant)] = true
		if int(entry.get("resource_focus_count", 0)) > 0: focus_count += 1
		if bool(entry.get("has_economy_boon", false)): boon_count += 1
		if bool(entry.get("has_art_profile", false)): art_count += 1
		if int(entry.get("late_shift_score", 0)) > 0: late_shift_count += 1
		var bound_counts := _array(entry.get("bound_skill_counts", []))
		var bound_ok := bound_counts.size() == 4 and _array(entry.get("bound_skill_missing", [])).is_empty()
		for rank in range(1, 5):
			if rank - 1 >= bound_counts.size() or int(bound_counts[rank - 1]) < rank: bound_ok = false
		if bound_ok: bound_ladder_count += 1
		if int(entry.get("action_count", 0)) < 6: issues.append("%s行动少于6个" % monster_name)
		if int(entry.get("active_early_actions", 0)) < 3: issues.append("%s早期行动过少" % monster_name)
		if int(entry.get("active_escalated_actions", 0)) < 5: issues.append("%s升级/破坏后行动过少" % monster_name)
		if _array(entry.get("role_tags", [])).size() < 3: issues.append("%s行动定位过窄" % monster_name)
		if int(entry.get("resource_focus_count", 0)) < 2: issues.append("%s缺商品偏好" % monster_name)
		if not bool(entry.get("has_economy_boon", false)): issues.append("%s缺经济牌路" % monster_name)
		if not bool(entry.get("has_art_profile", false)): issues.append("%s缺画像档案" % monster_name)
		if not _array(entry.get("missing_special_cards", [])).is_empty(): issues.append("%s带入卡缺定义" % monster_name)
		if not _array(entry.get("bound_skill_missing", [])).is_empty(): issues.append("%s固定技能缺定义" % monster_name)
	var catalog_count := entries.size()
	if catalog_count < 8: issues.append("怪兽数量不足:%d" % catalog_count)
	if int(movement_counts.get("飞行", 0)) <= 0: issues.append("缺飞行怪兽生态位")
	if int(movement_counts.get("水栖/海域", 0)) <= 0: issues.append("缺水栖/海域怪兽生态位")
	if int(movement_counts.get("陆行", 0)) <= 0: issues.append("缺陆行怪兽生态位")
	if resource_goods.size() < mini(12, catalog_count * 2): issues.append("怪兽商品偏好池过窄:%d" % resource_goods.size())
	if signatures.size() < maxi(5, catalog_count - 1): issues.append("怪兽行动签名同质化:%d/%d" % [signatures.size(), catalog_count])
	if role_tag_counts.size() < 8: issues.append("怪兽行动标签过少:%d" % role_tag_counts.size())
	return {"ok": issues.is_empty(), "issues": issues, "catalog_count": catalog_count, "entries": entries, "movement_counts": movement_counts, "action_signature_count": signatures.size(), "action_signatures": signatures, "role_tag_count": role_tag_counts.size(), "role_tag_counts": role_tag_counts, "resource_good_count": resource_goods.size(), "resource_goods": resource_goods.keys(), "monsters_with_resource_focus": focus_count, "monsters_with_economy_boon": boon_count, "monsters_with_art": art_count, "monsters_with_late_shift": late_shift_count, "monsters_with_bound_ladder": bound_ladder_count, "summary": _monster_ecology_summary(entries, movement_counts, role_tag_counts, resource_goods.size(), issues)}


func monster_ecology_identity_entry(monster_index: int, world_snapshot: Dictionary = {}) -> Dictionary:
	for monster_variant in _array(_snapshot_or(world_snapshot, false).get("monsters", [])):
		if monster_variant is Dictionary and int((monster_variant as Dictionary).get("index", -1)) == monster_index:
			return _monster_ecology_entry(monster_variant as Dictionary)
	return {}


func temporary_economy_seconds_audit(world_snapshot: Dictionary = {}) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, false)
	var duration_pairs := [{"turns": "contract_turns", "seconds": "contract_seconds"}, {"turns": "route_flow_turns", "seconds": "route_flow_seconds"}, {"turns": "market_contract_turns", "seconds": "market_contract_seconds"}, {"turns": "growth_turns", "seconds": "growth_seconds"}]
	var violations: Array = []
	var seconds_cards: Array = []
	var mirrors: Array = []
	var legacy_seconds := float(snapshot.get("economy_legacy_turn_seconds", 30.0))
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant
		var card_name := str(card.get("card_name", ""))
		var skill := _dictionary(card.get("authored_skill", {}))
		var text := str(skill.get("text", ""))
		if text.contains("经营周期") or text.contains("经济周期") or text.contains("/周期"):
			violations.append("%s的玩家文本仍含周期口径" % card_name)
		for pair_variant in duration_pairs:
			var pair: Dictionary = pair_variant
			var turns_key := str(pair.get("turns", "")); var seconds_key := str(pair.get("seconds", ""))
			var has_turns := skill.has(turns_key) and int(skill.get(turns_key, 0)) > 0
			var has_seconds := skill.has(seconds_key) and float(skill.get(seconds_key, 0.0)) > 0.0
			if has_turns and not has_seconds: violations.append("%s使用%s但缺少%s" % [card_name, turns_key, seconds_key])
			if has_seconds:
				_append_unique(seconds_cards, card_name)
				if has_turns:
					_append_unique(mirrors, "%s:%s" % [card_name, turns_key])
					if abs(float(skill.get(seconds_key, 0.0)) - float(int(skill.get(turns_key, 0))) * legacy_seconds) > 0.01:
						violations.append("%s的%s与兼容镜像%s不一致" % [card_name, seconds_key, turns_key])
	var futures_terms := _array(snapshot.get("futures_terms", []))
	if futures_terms.size() != 12: violations.append("商品期货条款应为12张，实际%d张" % futures_terms.size())
	for terms_variant in futures_terms:
		var terms: Dictionary = terms_variant if terms_variant is Dictionary else {}
		if float(terms.get("duration_seconds", 0.0)) > 0.0: _append_unique(seconds_cards, str(terms.get("card_id", "")))
	return {"violations": violations, "seconds_card_count": seconds_cards.size(), "compatibility_mirror_count": mirrors.size(), "seconds_cards": seconds_cards, "compatibility_mirrors": mirrors}


func playable_card_resolution_coverage_report(world_snapshot: Dictionary = {}) -> Dictionary:
	var missing: Array = []
	var checked := 0
	for card_variant in _cards(_snapshot_or(world_snapshot, false)):
		var card: Dictionary = card_variant
		checked += 1
		if not bool(card.get("resolution_handler", false)):
			missing.append("%s：kind=%s 未接入结算器" % [str(card.get("card_name", "")), str(_dictionary(card.get("skill", {})).get("kind", ""))])
	return {"checked": checked, "missing": missing}


func build_developer_panel_snapshot(world_snapshot: Dictionary = {}, sample_only := true) -> Dictionary:
	var snapshot := _snapshot_or(world_snapshot, sample_only)
	var runtime_snapshot := _runtime_balance_snapshot(snapshot)
	var report: Variant = _runtime_balance_model.call("statistics_hub_report", runtime_snapshot, sample_only)
	return (report as Dictionary).duplicate(true) if report is Dictionary else {}


func build_balance_report(world_snapshot: Dictionary = {}) -> Dictionary:
	_report_build_count += 1
	var snapshot := _snapshot_or(world_snapshot, false)
	return {
		"version": "gameplay_balance_diagnostics_v1",
		"development_routes": development_route_audit(snapshot),
		"development_route_pressure": development_route_pressure_audit(snapshot),
		"direct_interaction": direct_interaction_balance_report(snapshot),
		"roles": role_balance_audit(snapshot),
		"monster_ecology": monster_ecology_balance_report(snapshot),
		"product_ecosystem": product_ecosystem_report(snapshot),
		"card_supply": card_supply_product_filter_audit(snapshot),
		"reserved_supply": district_reserved_supply_audit(snapshot),
		"card_one_glance": card_one_glance_audit_report(snapshot),
		"temporary_economy": temporary_economy_seconds_audit(snapshot),
		"resolution_coverage": playable_card_resolution_coverage_report(snapshot),
		"developer_panel": build_developer_panel_snapshot(snapshot, true),
	}


func debug_snapshot() -> Dictionary:
	var catalog_report := route_catalog.validation_report() if route_catalog != null else {"valid": false, "route_count": 0}
	return {"service_ready": _configured, "route_catalog_valid": bool(catalog_report.get("valid", false)), "route_count": int(catalog_report.get("route_count", 0)), "world_bridge_ready": _world_bridge != null, "report_build_count": _report_build_count, "snapshot_cache_hits": _snapshot_cache_hits, "runtime_balance_model_owner": "res://scripts/balance/runtime_balance_model.gd", "diagnostic_authority": true, "formula_authority": false, "world_mutation_authority": false, "pure_data_outputs": true}


func _snapshot(sample_only: bool) -> Dictionary:
	if _world_bridge == null:
		return _last_snapshot.duplicate(true)
	if not _last_snapshot.is_empty() and _last_snapshot_frame == Engine.get_process_frames() and _last_snapshot_sample_only == sample_only:
		_snapshot_cache_hits += 1
		return _last_snapshot.duplicate(true)
	return refresh_world_snapshot(sample_only)


func _snapshot_or(snapshot: Dictionary, sample_only: bool) -> Dictionary:
	return snapshot if not snapshot.is_empty() else _snapshot(sample_only)


func _cards(snapshot: Dictionary) -> Array:
	return _array(snapshot.get("cards", []))


func _card_fact(card_name: String, snapshot: Dictionary) -> Dictionary:
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant if card_variant is Dictionary else {}
		if str(card.get("card_name", card.get("card_id", ""))) == card_name:
			return card
	return {}


func _card_id_set(snapshot: Dictionary) -> Dictionary:
	var result := {}
	for card_variant in _cards(snapshot): result[str((card_variant as Dictionary).get("card_name", ""))] = true
	return result


func _family_complete(family: String, ids: Dictionary) -> bool:
	for rank in range(1, 5):
		if not ids.has("%s%d" % [family, rank]): return false
	return true


func _fallback_route_id(skill: Dictionary) -> String:
	var kind := str(skill.get("kind", ""))
	if kind in ["city_development", "city_revenue_boost", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "route_insurance"]: return "city_growth"
	if kind in ["area_trade_contract", "product_contract_boon", "city_contract_boon"]: return "contract_route"
	if kind in ["product_speculation", "product_futures", "city_gdp_derivative", "market_stabilize", "product_growth_boon"]: return "finance_speculation"
	if kind in ["monster_card", "monster_bound_action", "monster_lure", "monster_takeover", "route_sabotage", "weather_control", "news_event", "military_force", "military_command"]: return "monster_pressure"
	if kind.begins_with("intel_") or kind in ["supply_draw", "card_access_boon"]: return "intel_supply"
	if kind in ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage", "card_counter"]: return "direct_interaction"
	return "tactical_support"


func _runtime_balance_snapshot(snapshot: Dictionary) -> Dictionary:
	var cards: Array = []
	for card_variant in _cards(snapshot):
		var card: Dictionary = card_variant
		cards.append({"card_name": str(card.get("card_name", "")), "skill": _dictionary(card.get("skill", {})), "rank": int(card.get("rank", 1)), "rank_label": _roman_rank(int(card.get("rank", 1))), "family": str(card.get("family", "")), "price": int(card.get("price", 0)), "price_anchor": "%s1" % str(card.get("family", "")), "route_id": route_id_for_card(card), "route_label": route_label(route_id_for_card(card))})
	var products: Array = []
	for product_variant in _array(snapshot.get("products", [])):
		var product: Dictionary = product_variant if product_variant is Dictionary else {}
		var profile := _dictionary(product.get("profile", {})); var market := _dictionary(product.get("market", {}))
		products.append({"name": str(product.get("name", "")), "category": str(profile.get("category", "未分类")), "terrain": str(profile.get("terrain", "通用")), "base_price": int(market.get("base_price", market.get("price", 100))), "price": int(market.get("price", market.get("base_price", 100))), "volatility": int(market.get("volatility", profile.get("volatility", 4)))})
	var monsters: Array = []
	for monster_variant in _array(snapshot.get("monsters", [])):
		var monster: Dictionary = monster_variant if monster_variant is Dictionary else {}; var entry := _dictionary(monster.get("entry", {}))
		monsters.append({"name": str(entry.get("name", "怪兽")), "rank": int(entry.get("rank", 1)), "move": float(entry.get("move", 180.0)), "movement_mode": str(entry.get("movement_mode", "walk")), "movement_traits": _array(entry.get("movement_traits", [])), "terrain_move_multiplier": 1.0, "terrain_move_multipliers": _dictionary(entry.get("terrain_move_multiplier", {})), "move_damage": int(entry.get("move_damage", 0)), "actions": _array(monster.get("actions", []))})
	return {"cards": cards, "products": products, "monsters": monsters, "ai_routes": development_routes(), "region_rows": _dictionary(snapshot.get("region_rows", {})), "sample_only": bool(snapshot.get("sample_only", false)), "model_version": "runtime_balance_v1"}


func _pressure_card_entry(card: Dictionary) -> Dictionary:
	var skill := _dictionary(card.get("skill", {}))
	var kind := str(skill.get("kind", ""))
	var requirement := _dictionary(card.get("requirement", {}))
	var target := _dictionary(card.get("target", {}))
	var pillars := card_balance_pillars(skill, card)
	var required_share := int(requirement.get("required_share_percent", skill.get("play_region_gdp_share_required", 0)))
	var money := int(float(maxi(0, int(skill.get("cash", 0)))) / 35.0) + int(float(maxi(0, int(skill.get("revenue_amount", 0)))) / 8.0) + int(float(maxi(0, int(skill.get("contract_income", 0)))) / 10.0) + int(float(maxi(0, int(skill.get("accept_cash", 0)))) / 30.0)
	money += maxi(0, int(skill.get("production_delta", 0))) * 44 + maxi(0, int(skill.get("transport_delta", 0))) * 42 + maxi(0, int(skill.get("consumption_delta", 0))) * 42
	money += maxi(0, int(skill.get("accept_production_delta", 0))) * 38 + maxi(0, int(skill.get("accept_transport_delta", 0))) * 36 + maxi(0, int(skill.get("accept_consumption_delta", 0))) * 36
	money += maxi(0, int(skill.get("contract_add_products", 0))) * 34 + maxi(0, int(skill.get("contract_add_demands", 0))) * 34
	money += int(round(maxf(0.0, float(skill.get("growth_multiplier", 1.0)) - 1.0) * 120.0)) + int(round(maxf(0.0, float(skill.get("route_flow_multiplier", 1.0)) - 1.0) * 110.0))
	var disruption := maxi(0, int(skill.get("damage", 0))) * 42 + maxi(0, int(skill.get("route_damage", 0))) * 68 + maxi(0, int(skill.get("decline_route_damage", 0))) * 64
	disruption += maxi(0, -int(skill.get("production_delta", 0))) * 48 + maxi(0, -int(skill.get("transport_delta", 0))) * 48 + maxi(0, -int(skill.get("consumption_delta", 0))) * 48
	disruption += maxi(0, int(skill.get("panic", 0))) * 3 + maxi(0, int(skill.get("hand_discard_count", 0))) * 86 + maxi(0, int(skill.get("hand_steal_count", 0))) * 118
	disruption += int(float(maxi(0, int(skill.get("target_cash_penalty", 0)))) / 2.0) + int(round(maxf(0.0, float(skill.get("control_block_seconds", 0.0))) * maxi(0, int(skill.get("control_gdp_penalty", 0))) / 18.0))
	disruption += maxi(0, int(skill.get("global_barrage_target_count", 0))) * (maxi(0, int(skill.get("global_barrage_damage", 0))) * 70 + maxi(0, int(skill.get("global_barrage_route_damage", 0))) * 46)
	var protection := maxi(0, int(skill.get("repair_routes", 0))) * 62 + maxi(0, int(skill.get("armor", 0))) * 18 + maxi(0, int(skill.get("guard", 0))) * 18 + maxi(0, int(skill.get("ranged_guard", 0))) * 18 + maxi(0, int(skill.get("counter_strength", 0))) * 80 + maxi(0, int(skill.get("stabilize_amount", 0))) * 36
	var intel_supply := maxi(0, int(skill.get("trace_card_count", 0))) * 84 + maxi(0, int(skill.get("trace_contract_count", 0))) * 88 + maxi(0, int(skill.get("reveal_city_count", 0))) * 92 + maxi(0, int(skill.get("draw_amount", 0))) * 72 + maxi(0, int(skill.get("card_access_extra_hops", 0))) * 68
	if bool(skill.get("card_access_global", false)): intel_supply += 140
	var gate := maxi(0, int(skill.get("cost", 0))) * 8 + required_share * 4 + _card_budget_gate_facts(card).size() * 18
	var clue := 0
	if str(card.get("play_product", "")) != "": clue += 18
	if required_share > 0: clue += 26
	if bool(target.get("targets_player", false)): gate += 28; clue += 54
	if bool(target.get("targets_monster", false)): gate += 24; clue += 42
	if kind in ["city_control_dispute", "global_barrage", "area_trade_contract", "weather_control", "military_force"]: clue += 44
	if not bool(skill.get("persistent", false)): gate += 8
	else: protection += 18
	if pillars.has("公开门槛"): clue += 18
	var futures := _dictionary(skill.get("futures_terms", {}))
	if kind == "product_futures":
		money += int(float(maxi(0, int(futures.get("maximum_gain", 0)))) / 18.0)
		if str(futures.get("direction", "up")) == "down": disruption += int(float(maxi(0, int(futures.get("maximum_gain", 0)))) / 26.0)
		clue += 24 + clampi(int(futures.get("rank", card.get("rank", 1))), 1, 4) * 10
		if bool(futures.get("requires_warehouse", false)): gate += 70; clue += 46
	var derivative := _dictionary(skill.get("gdp_derivative_terms", {}))
	if kind == "city_gdp_derivative":
		var derivative_score := int(float(maxi(0, int(derivative.get("maximum_gain", 0)))) / 3.0) + int(float(maxi(0, int(derivative.get("maximum_loss", 0)))) / 6.0)
		if bool(derivative.get("insurance", false)): protection += derivative_score
		elif str(derivative.get("direction", "up")) == "down": disruption += derivative_score
		else: money += derivative_score
		clue += 30
	if kind == "monster_card": disruption += int(float(maxi(0, int(skill.get("hp", 0)))) / 3.0) + maxi(0, int(skill.get("fixed_skill_count", 0))) * 45; clue += 34
	if kind == "monster_lure": disruption += int(round(maxf(0.0, float(skill.get("lure_speedup", 0.0))) * 18.0)); clue += 36
	if kind == "monster_takeover": disruption += 160; clue += 48
	if kind in ["military_force", "military_command"]: disruption += maxi(0, int(skill.get("military_damage", 0))) * 40 + maxi(0, int(skill.get("military_gdp_penalty", 0))) * 24; protection += maxi(0, int(skill.get("military_hp", 0))) * 5; clue += 42
	if kind == "weather_control": disruption += maxi(1, int(skill.get("weather_zone_count", 1))) * 16 + int(round(float(skill.get("weather_duration_seconds", 75.0)) / 10.0)); clue += 56
	var total := money + disruption + int(round(float(protection) * 0.65)) + int(round(float(intel_supply) * 0.70))
	return {"name": str(card.get("card_name", "")), "route_id": route_id_for_card(card), "route_label": str(card.get("route_label", "")), "kind": kind, "rank": int(card.get("rank", 1)), "budget": card_budget_points(skill), "pillars": pillars, "money_score": money, "disruption_score": disruption, "protection_score": protection, "intel_supply_score": intel_supply, "gate_score": gate, "public_clue_score": clue, "total_pressure": total}


func _pressure_notes(route_id: String, entry: Dictionary) -> Array:
	var notes: Array = []
	var card_count := int(entry.get("card_count", 0))
	if bool(entry.get("required_for_ai_baseline", false)) and card_count < 6: notes.append("牌量不足")
	if int(entry.get("complete_rank_ladders", 0)) <= 0: notes.append("缺少完整I-IV梯度")
	if int(entry.get("money_score", 0)) + int(entry.get("disruption_score", 0)) + int(entry.get("intel_supply_score", 0)) <= 0: notes.append("缺少能转化为现金的收益/压制/情报支点")
	if int(entry.get("total_pressure", 0)) < 160: notes.append("路线压力过低")
	if bool(entry.get("required_for_ai_baseline", false)) and int(entry.get("gate_score", 0)) < maxi(120, card_count * 22): notes.append("门槛偏低或不可读")
	if bool(entry.get("required_for_ai_baseline", false)) and int(entry.get("public_clue_score", 0)) < maxi(80, card_count * 12): notes.append("公开线索不足")
	if int(entry.get("counterplay_score", 0)) < 130: notes.append("反制支撑不足")
	if bool(entry.get("required_for_ai_baseline", false)) and int(entry.get("primary_ai_profiles", 0)) <= 0: notes.append("没有AI主路线")
	match route_id:
		"city_growth":
			if int(entry.get("money_score", 0)) <= 0: notes.append("城市成长缺收益引擎")
		"contract_route":
			if int(entry.get("money_score", 0)) <= 0 or int(entry.get("gate_score", 0)) <= 0: notes.append("合约路线缺收益或谈判门槛")
		"finance_speculation":
			if int(entry.get("money_score", 0)) <= 0 or int(entry.get("public_clue_score", 0)) <= 0: notes.append("金融路线缺兑现或公开价格/GDP线索")
		"monster_pressure":
			if int(entry.get("disruption_score", 0)) <= 0: notes.append("怪兽路线缺压制破坏")
		"intel_supply":
			if int(entry.get("intel_supply_score", 0)) <= 0: notes.append("情报补给路线缺线索或购牌范围支撑")
		"direct_interaction":
			if int(entry.get("disruption_score", 0)) <= 0 or int(entry.get("public_clue_score", 0)) <= 0: notes.append("直接互动缺压制或公开目标线索")
	return notes


func _pressure_summary(routes: Array) -> String:
	var pieces: Array = []
	for route_variant in routes:
		var route: Dictionary = route_variant if route_variant is Dictionary else {}
		if bool(route.get("required_for_ai_baseline", false)):
			pieces.append("%s:%s/压%d/门%d/线%d/AI%d" % [str(route.get("label", "路线")), str(route.get("status", "待审计")), int(route.get("total_pressure", 0)), int(route.get("gate_score", 0)), int(route.get("public_clue_score", 0)), int(route.get("primary_ai_profiles", 0))])
	return "核心路线压力审计｜%s" % ("；".join(pieces) if not pieces.is_empty() else "暂无核心路线")


func _direct_interaction_entry(card: Dictionary) -> Dictionary:
	var skill := _dictionary(card.get("skill", {})); var kind := str(skill.get("kind", "")); var requirement := _dictionary(card.get("requirement", {}))
	var effect := maxi(0, int(skill.get("hand_discard_count", 0))) * 85 + maxi(0, int(skill.get("hand_steal_count", 0))) * 120 + int(round(maxf(0.0, float(skill.get("hand_lock_seconds", 0.0))) * 3.6)) + int(float(maxi(0, int(skill.get("target_cash_penalty", 0)))) / 2.0) + int(float(maxi(0, int(skill.get("steal_fail_cash", 0)))) / 3.0)
	effect += int(round(maxf(0.0, float(skill.get("control_block_seconds", 0.0))) * maxi(0, int(skill.get("control_gdp_penalty", 0))) / 18.0)) + maxi(0, int(skill.get("global_barrage_target_count", 0))) * maxi(0, int(skill.get("global_barrage_damage", 0))) * 74 + maxi(0, int(skill.get("global_barrage_target_count", 0))) * maxi(0, int(skill.get("global_barrage_route_damage", 0))) * 52
	if kind == "global_barrage" and int(skill.get("global_barrage_target_count", 0)) >= 4: effect += 28
	if kind == "player_hand_steal": effect += 22
	if kind == "city_control_dispute": effect += 18
	var gate := maxi(0, int(skill.get("cost", 0))) * 9 + int(requirement.get("required_share_percent", 0)) * 6
	if str(card.get("play_product", "")) != "": gate += 18
	if bool(skill.get("target_player_required", false)): gate += 18
	if kind in ["city_control_dispute", "global_barrage"]: gate += 24
	if not bool(skill.get("persistent", false)): gate += 10
	if int(skill.get("global_barrage_target_count", 0)) >= 4: gate += 24
	var clue := 0
	if bool(skill.get("target_player_required", false)): clue += 48
	if kind in ["city_control_dispute", "global_barrage"]: clue += 52
	if int(requirement.get("required_share_percent", 0)) > 0: clue += 22
	if str(card.get("play_product", "")) != "": clue += 18
	if int(skill.get("global_barrage_target_count", 0)) > 1: clue += 12
	if int(skill.get("hand_discard_count", 0)) > 0 or int(skill.get("hand_steal_count", 0)) > 0: clue += 8
	if int(skill.get("control_gdp_penalty", 0)) > 0 or int(skill.get("global_barrage_damage", 0)) > 0: clue += 12
	return {"name": str(card.get("card_name", "")), "family": str(card.get("family", "")), "rank": int(card.get("rank", 1)), "kind": kind, "target_kind": "玩家" if bool(skill.get("target_player_required", false)) else "公开城市/全场", "effect_score": maxi(1, effect), "gate_score": gate, "public_clue_score": clue, "counter_available": true, "play_flow_required": 0, "play_requirement_kind": str(requirement.get("kind", "none")), "required_share_percent": int(requirement.get("required_share_percent", 0)), "play_product": str(card.get("play_product", "")), "hand_discard_count": int(skill.get("hand_discard_count", 0)), "hand_steal_count": int(skill.get("hand_steal_count", 0)), "hand_lock_seconds": float(skill.get("hand_lock_seconds", 0.0)), "target_cash_penalty": int(skill.get("target_cash_penalty", 0)), "control_gdp_penalty": int(skill.get("control_gdp_penalty", 0)), "control_block_seconds": float(skill.get("control_block_seconds", 0.0)), "global_barrage_damage": int(skill.get("global_barrage_damage", 0)), "global_barrage_target_count": int(skill.get("global_barrage_target_count", 0)), "global_barrage_route_damage": int(skill.get("global_barrage_route_damage", 0))}


func _monster_ecology_entry(monster_fact: Dictionary) -> Dictionary:
	var entry := _dictionary(monster_fact.get("entry", {})); var actions := _array(monster_fact.get("actions", [])); var early := _array(monster_fact.get("early_weights", [])); var escalated := _array(monster_fact.get("escalated_weights", [])); var rank_iv := _array(monster_fact.get("rank_iv_weights", [])); var tags_by_action := _array(monster_fact.get("action_role_tags", []))
	var role_tags: Array = []; var action_names: Array = []; var active_early := 0; var active_escalated := 0; var late_shift := 0; var max_damage := 0; var max_range := 0.0; var max_move := 0.0
	for index in range(actions.size()):
		var action: Dictionary = actions[index] if actions[index] is Dictionary else {}; action_names.append(str(action.get("name", "招式")))
		if index < early.size() and int(early[index]) > 0: active_early += 1
		if index < escalated.size() and int(escalated[index]) > 0: active_escalated += 1
		if index < rank_iv.size() and index < early.size() and int(rank_iv[index]) > int(early[index]): late_shift += int(rank_iv[index]) - int(early[index])
		max_damage = maxi(max_damage, maxi(int(action.get("damage", 0)), int(action.get("close_damage", 0)))); max_range = maxf(max_range, float(action.get("range", 0.0))); max_move = maxf(max_move, float(action.get("move_override", 0.0)))
		if index < tags_by_action.size():
			for tag_variant in _array(tags_by_action[index]): _append_unique(role_tags, str(tag_variant))
	var signature := role_tags.duplicate(); signature.sort()
	var resource_focus := _array(entry.get("resource_focus", [])); var special_cards := _array(monster_fact.get("special_cards", []))
	var ecology_score := actions.size() * 12 + role_tags.size() * 24 + resource_focus.size() * 18 + special_cards.size() * 7 + late_shift * 6 + max_damage * 11 + int(round(max_range / 35.0)) + int(round(max_move / 45.0))
	if not _dictionary(entry.get("economy_boon", {})).is_empty(): ecology_score += 34
	if bool(monster_fact.get("has_art_profile", false)): ecology_score += 18
	return {"index": int(monster_fact.get("index", 0)), "name": str(entry.get("name", "怪兽")), "hp": int(entry.get("hp", 0)), "armor": int(entry.get("armor", 0)), "move": float(entry.get("move", 0.0)), "resource_focus": resource_focus, "resource_focus_count": resource_focus.size(), "movement_archetype": _monster_movement_archetype(entry), "has_economy_boon": not _dictionary(entry.get("economy_boon", {})).is_empty(), "has_art_profile": bool(monster_fact.get("has_art_profile", false)), "special_cards": special_cards, "missing_special_cards": _array(monster_fact.get("missing_special_cards", [])), "action_count": actions.size(), "action_names": action_names, "active_early_actions": active_early, "active_escalated_actions": active_escalated, "role_tags": role_tags, "action_signature": "+".join(signature), "late_shift_score": late_shift, "bound_skill_counts": _array(monster_fact.get("bound_skill_counts", [])), "bound_skill_missing": _array(monster_fact.get("bound_skill_missing", [])), "max_damage": max_damage, "max_range": max_range, "max_move": max_move, "ecology_score": ecology_score}


func _monster_movement_archetype(entry: Dictionary) -> String:
	var traits := _array(entry.get("movement_traits", [])); var terrain := _dictionary(entry.get("terrain_move_multiplier", {})); var access := str(entry.get("summon_access", "monster_zone"))
	if traits.has("flying"): return "飞行"
	if traits.has("aquatic") or float(terrain.get("ocean", 1.0)) > float(terrain.get("land", 1.0)) + 0.25 or access == "ocean_monster_zone": return "水栖/海域"
	if access == "land_monster_zone" or float(terrain.get("land", 1.0)) >= float(terrain.get("ocean", 1.0)): return "陆行"
	return "通用"


func _monster_ecology_summary(entries: Array, movement_counts: Dictionary, role_tag_counts: Dictionary, goods: int, issues: Array) -> String:
	var movement: Array = []
	for key in movement_counts.keys():
		movement.append("%s×%d" % [str(key), int(movement_counts[key])])
	return "怪兽生态审计：%d只｜移动:%s｜行动标签%d类｜商品偏好%d种%s" % [entries.size(), " / ".join(movement), role_tag_counts.size(), goods, "" if issues.is_empty() else "｜问题:%s" % "、".join(issues)]


func _development_route_balance_notes(route_id: String, entry: Dictionary) -> Array:
	var notes: Array = []
	if bool(entry.get("required_for_ai_baseline", false)) and int(entry.get("card_count", 0)) < 6: notes.append("牌量偏少")
	if int(entry.get("complete_rank_ladders", 0)) <= 0: notes.append("缺I-IV梯度")
	for pillar_variant in _expected_pillars(route_id):
		if not _has_pillar(entry, str(pillar_variant)): notes.append("缺%s支点" % str(pillar_variant))
	var bands := _dictionary(entry.get("budget_band_counts", {}))
	if bool(entry.get("required_for_ai_baseline", false)):
		if int(bands.get("基础频用", 0)) <= 0: notes.append("缺低门槛I级")
		if int(bands.get("路线核心", 0)) + int(bands.get("终端压力", 0)) <= 0: notes.append("缺核心/终端牌")
	if int(entry.get("avg_budget", 0)) > 0 and int(entry.get("budget_max", 0)) > int(entry.get("avg_budget", 0)) * 3: notes.append("终端跳跃过大")
	return notes


func _expected_pillars(route_id: String) -> Array:
	return {"city_growth": ["收益", "防御", "公开门槛"], "contract_route": ["合约", "收益", "公开门槛"], "finance_speculation": ["GDP金融", "市场", "防御", "公开门槛"], "monster_pressure": ["怪兽", "压制", "公开门槛"], "intel_supply": ["信息", "补给", "公开门槛"], "direct_interaction": ["互动", "压制", "公开门槛"]}.get(route_id, ["临场"])


func _has_pillar(entry: Dictionary, pillar: String) -> bool:
	return int(_dictionary(entry.get("pillar_counts", {})).get(pillar, 0)) > 0


func _budget_band_summary(entry: Dictionary) -> String:
	var counts := _dictionary(entry.get("budget_band_counts", {})); var pieces: Array = []
	for band in ["基础频用", "效率扩张", "路线核心", "终端压力"]:
		if int(counts.get(band, 0)) > 0: pieces.append("%s×%d" % [band, int(counts.get(band, 0))])
	return " / ".join(pieces) if not pieces.is_empty() else "暂无"


func _balance_note_summary(entry: Dictionary) -> String:
	var notes := _array(entry.get("balance_notes", [])); return "健康：收益/反制/门槛有支撑" if notes.is_empty() else " / ".join(notes.slice(0, mini(3, notes.size())))


func _card_budget_driver_facts(skill: Dictionary) -> Array:
	var result: Array = []
	if str(skill.get("kind", "")) == "monster_card": result.append("怪兽HP%d/固定技能%d" % [int(skill.get("hp", 0)), int(skill.get("fixed_skill_count", 0))])
	if int(skill.get("cash", 0)) != 0: result.append("现金¥%s" % _signed_int(int(skill.get("cash", 0))) )
	if int(skill.get("revenue_amount", 0)) > 0: result.append("城市GDP+%d" % int(skill.get("revenue_amount", 0)))
	if int(skill.get("route_damage", 0)) > 0: result.append("断路+%d" % int(skill.get("route_damage", 0)))
	if int(skill.get("repair_routes", 0)) > 0: result.append("修路%d" % int(skill.get("repair_routes", 0)))
	if int(skill.get("damage", 0)) > 0: result.append("伤害%d" % int(skill.get("damage", 0)))
	if int(skill.get("draw_amount", 0)) > 0: result.append("补牌%d" % int(skill.get("draw_amount", 0)))
	if int(skill.get("hand_discard_count", 0)) > 0: result.append("拆牌%d" % int(skill.get("hand_discard_count", 0)))
	if int(skill.get("hand_steal_count", 0)) > 0: result.append("牵牌%d" % int(skill.get("hand_steal_count", 0)))
	if str(skill.get("kind", "")) == "city_gdp_derivative": result.append("GDP衍生品")
	if result.is_empty(): result.append("按效果文字结算")
	return result


func _card_budget_gate_facts(card_facts: Dictionary) -> Array:
	var skill := _dictionary(card_facts.get("skill", card_facts)); var requirement := _dictionary(card_facts.get("requirement", {})); var target := _dictionary(card_facts.get("target", {})); var result: Array = []
	var required := int(requirement.get("required_share_percent", skill.get("play_region_gdp_share_required", 0))); if required > 0: result.append("GDP份额%d%%" % required)
	var cash := int(requirement.get("cash_cost", skill.get("play_cash", 0))); if cash > 0: result.append("打出¥%d" % cash)
	if bool(target.get("targets_monster", skill.get("target_monster_required", false))): result.append("公开指定怪兽")
	if bool(target.get("targets_player", skill.get("target_player_required", false))): result.append("公开指定玩家")
	if str(skill.get("kind", "")) == "area_trade_contract": result.append("先选供需两区")
	result.append("固定技能冷却" if bool(skill.get("persistent", false)) else "一次性")
	return result


func _rank_budget_role_text(rank: int) -> String:
	return {1: "I级基础：低门槛、常用试探或开路线。", 2: "II级效率：提高数值、范围或持续时间。", 3: "III级核心：足以围绕它组织一条经济/破坏路线。", 4: "IV级终端：强力但应留下公开线索、门槛或反制窗口。"}.get(clampi(rank, 1, 4), "I级基础：低门槛、常用试探或开路线。")


func _role_budget_add(report: Dictionary, label: String, points: int, tag: String) -> void:
	if points <= 0: return
	report["points"] = int(report.get("points", 0)) + points; (report["drivers"] as Array).append("%s+%d" % [label, points]); _append_unique(report["tags"] as Array, tag)


func _role_budget_band(points: int) -> String:
	if points <= 0: return "未配置"
	if points <= 55: return "轻量"
	if points <= 95: return "标准"
	if points <= 135: return "强力"
	return "高风险强力"


func _fixed_product_requirements(skill: Dictionary) -> Array:
	var result: Array = []; _append_unique(result, str(skill.get("supply_product", skill.get("play_product", ""))))
	for value in _array(skill.get("contract_products", [])): _append_unique(result, str(value))
	return result


func _products_available(required: Array, available: Array) -> bool:
	if required.is_empty() or available.is_empty(): return true
	for value in required:
		if not available.has(str(value)): return false
	return true


func _uses_current_product(skill: Dictionary) -> bool:
	var kind := str(skill.get("kind", "")); return kind in ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize", "city_product_shift", "city_demand_shift"] or (kind == "area_trade_contract" and str(skill.get("contract_product_mode", "selected")) != "fixed") or int(skill.get("market_demand_pressure", 0)) != 0 or int(skill.get("market_supply_pressure", 0)) != 0


func _district_products(district: Dictionary) -> Array:
	var result: Array = []
	for value in _array(district.get("products", [])) + _array(district.get("demands", [])) + _array(district.get("city_products", [])) + _array(district.get("city_demands", [])): _append_unique(result, str(value))
	return result


func _increment(container: Dictionary, field: String, key: String) -> void:
	var counts := _dictionary(container.get(field, {})); counts[key] = int(counts.get(key, 0)) + 1; container[field] = counts


func _sum_dictionary_values(values: Dictionary) -> int:
	var result := 0
	for value in values.values():
		result += int(value)
	return result


func _append_unique(values: Array, value: String) -> void:
	if value != "" and not values.has(value): values.append(value)


func _join_first(values: Array, limit: int) -> String:
	var result: Array = []
	for value in values:
		if str(value).strip_edges() != "": result.append(str(value))
		if result.size() >= limit: break
	return "｜".join(result)


func _short_text(value: String, limit: int) -> String:
	return value if value.length() <= limit else value.substr(0, maxi(0, limit - 1)) + "…"


func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func _roman_rank(rank: int) -> String:
	return str({1: "I", 2: "II", 3: "III", 4: "IV"}.get(clampi(rank, 1, 4), "I"))


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []
