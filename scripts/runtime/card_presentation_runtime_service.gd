@tool
extends Node
class_name CardPresentationRuntimeService

const CARD_VIEW_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/card_view_snapshot.gd")

var _configured := false
var _compose_count := 0
var _hand_compose_count := 0
var _resolution_compose_count := 0
var _product_market_runtime_controller: ProductMarketRuntimeController
var _city_gdp_derivative_runtime_controller: CityGdpDerivativeRuntimeController


func configure(_config: Dictionary = {}) -> void:
	_configured = true


func set_product_market_runtime_controller(controller: ProductMarketRuntimeController) -> void:
	_product_market_runtime_controller = controller


func set_city_gdp_derivative_runtime_controller(controller: CityGdpDerivativeRuntimeController) -> void:
	_city_gdp_derivative_runtime_controller = controller


func compose_card(source: Dictionary) -> Dictionary:
	_compose_count += 1
	var skill := _dictionary(source.get("skill", {}))
	var card_name := str(source.get("card_name", skill.get("name", "")))
	if str(skill.get("kind", "")) == "product_futures" and _dictionary(skill.get("futures_terms", {})).is_empty() and _product_market_runtime_controller != null:
		skill = _product_market_runtime_controller.skill_with_terms(card_name, skill)
	if str(skill.get("kind", "")) == "city_gdp_derivative" and _dictionary(skill.get("gdp_derivative_terms", {})).is_empty() and _city_gdp_derivative_runtime_controller != null:
		skill = _city_gdp_derivative_runtime_controller.skill_with_terms(card_name, skill)
	var route_label := _strategy_route_label(skill)
	var category_id := _category_id(source, skill)
	var type_label := _primary_type_label(source, skill)
	var icon := _category_icon(category_id)
	var route_icon := _route_icon(route_label)
	var use_case := _use_case_text(source, skill, route_label)
	var rule_facts := _rule_facts(source, skill)
	var key_rule_facts := _key_rule_facts(rule_facts)
	var art_stats := _art_stats(source, skill, route_label)
	var display_text := str(source.get("display_text", skill.get("text", ""))).replace("\n", "｜").strip_edges()
	var quick_effect_full := _quick_effect_text(use_case, display_text, key_rule_facts, art_stats, false)
	var quick_effect_compact := _quick_effect_text(use_case, display_text, key_rule_facts, art_stats, true)
	var rules_text_full := _rules_text(display_text, key_rule_facts, art_stats, false)
	var rules_text_compact := _rules_text(display_text, key_rule_facts, art_stats, true)
	var icon_type_label := "%s %s" % [icon, type_label]
	var icon_route_label := "%s %s" % [route_icon, route_label]
	var presentation := {
		"card_name": card_name,
		"display_name": str(source.get("display_name", card_name)),
		"rank": maxi(1, int(source.get("rank", skill.get("rank", 1)))),
		"rank_label": _roman_rank(int(source.get("rank", skill.get("rank", 1)))),
		"price": maxi(0, int(source.get("price", 0))),
		"accent": _theme_color(skill),
		"category_id": category_id,
		"icon": icon,
		"type_label": type_label,
		"icon_type_label": icon_type_label,
		"route_label": route_label,
		"strategy_route_label": route_label,
		"route_icon": route_icon,
		"icon_route_label": icon_route_label,
		"subtype_label": _subtype_label(source, skill, route_label),
		"type_line": "%s / %s / %s" % [icon_type_label, icon_route_label, str(source.get("tag_text", ""))],
		"use_case": use_case,
		"table_use": use_case,
		"strategy_use_text": _strategy_use_text(skill, route_label),
		"strategy_summary": _strategy_summary(skill, route_label),
		"rule_facts": rule_facts,
		"key_rule_facts": key_rule_facts,
		"art_stats": art_stats,
		"rules_text_full": rules_text_full,
		"rules_text_compact": rules_text_compact,
		"quick_effect_full": quick_effect_full,
		"quick_effect_compact": quick_effect_compact,
		"face_route_full": "%s｜路线:%s" % [icon_type_label, icon_route_label],
		"face_route_compact": "%s｜路线:%s" % [_short_text(icon_type_label, 8), _short_text(icon_route_label, 8)],
		"chips": _face_chips(source, skill),
	}
	presentation["detail_tooltip"] = _detail_tooltip(source, presentation, display_text)
	return presentation


func compose_play_eligibility(eligibility: Dictionary, card_source: Dictionary = {}) -> Dictionary:
	var reason := str(eligibility.get("reason_code", "invalid_payload"))
	var args := _dictionary(eligibility.get("reason_args", {}))
	var requirement := _dictionary(eligibility.get("requirement_status", {}))
	var card_label := str(card_source.get("display_name", card_source.get("card_name", "卡牌")))
	if card_label == "":
		card_label = "卡牌"
	var state := {
		"label": "可打出",
		"detail": "满足当前出牌条件。",
		"actionable": bool(eligibility.get("actionable", eligibility.get("allowed", false))),
		"accent": Color("#22c55e"),
		"reason_code": reason,
		"log_message": "",
	}
	match reason:
		"playable":
			state["detail"] = _playable_detail(args)
		"invalid_payload", "service_missing":
			_set_play_state(state, "不可用", "合法性服务未就绪。", false, Color("#94a3b8"))
		"invalid_player":
			_set_play_state(state, "不可用", "没有有效玩家。", false, Color("#94a3b8"))
		"player_eliminated":
			_set_play_state(state, "已出局", "玩家已经破产出局，不能继续打出卡牌。", false, Color("#94a3b8"))
			state["log_message"] = "%s已经破产出局，不能继续打出卡牌。" % str(args.get("player_name", "玩家"))
		"game_over":
			_set_play_state(state, "已结束", "本局已结束。", false, Color("#94a3b8"))
		"already_queued":
			_set_play_state(state, "排队中", "这张牌已经进入匿名卡牌轨道。", false, Color("#facc15"))
		"pending_target_choice":
			_set_play_state(state, "先选目标", "先完成当前临时目标选择窗口。", false, Color("#facc15"))
		"monster_wager_freeze":
			_set_play_state(state, "赌局暂停", "怪兽赌局正在全场下注；下注结束后才能继续出牌。", false, Color("#facc15"))
		"forced_decision_pending":
			_set_play_state(state, "等待决策", "先完成当前强制决策，再继续提交卡牌。", false, Color("#facc15"))
		"player_action_cooldown":
			_set_play_state(state, "冷却中", "玩家行动冷却%.1fs。" % float(args.get("seconds", 0.0)), false, Color("#facc15"))
		"card_locked":
			_set_play_state(state, "被封锁", "还剩%.1fs才能打出。" % float(args.get("seconds", 0.0)), false, Color("#fb7185"))
		"card_cooldown":
			_set_play_state(state, "冷却中", "还剩%.1fs才能再次释放。" % float(args.get("seconds", 0.0)), false, Color("#facc15"))
		"starter_district_missing":
			_set_play_state(state, "选落点", "先在星球上选一个区域，再首召怪兽。", false, Color("#fb7185"))
		"starter_district_destroyed":
			_set_play_state(state, "换落点", "当前区域已毁，换一个区域首召。", false, Color("#fb7185"))
		"starter_ready":
			_set_play_state(state, "首召就绪", "落点：%s｜首召免GDP门槛，落地后附近开牌架。" % str(args.get("district_name", "区域")), true, Color("#fb7185"))
		"counter_conversion_ready":
			_set_play_state(state, "可否决", "可把这张怪兽牌作为相位否决响应当前互动牌。", true, Color("#a78bfa"))
		"counter_window_closed":
			_set_play_state(state, "等响应", "只能在直接玩家互动牌的相位响应沙漏内打出。", false, Color("#94a3b8"))
			state["log_message"] = "%s只能在相位响应窗口内打出。" % card_label
		"counter_target_invalid":
			_set_play_state(state, "无可否决", "当前没有可取消的直接玩家互动牌。", false, Color("#94a3b8"))
			state["log_message"] = "%s当前没有可取消的玩家互动牌。" % card_label
		"monster_target_unavailable":
			_set_play_state(state, "无目标", "需要场上有怪兽目标。", false, Color("#94a3b8"))
		"contract_invalid":
			_set_play_state(state, "需合约", _short_text(str(args.get("error", "合约端点无效")), 58), false, Color("#facc15"))
			state["log_message"] = str(args.get("error", "合约端点无效"))
		"city_development_invalid":
			_set_play_state(state, "发展限制", str(args.get("error", "城市发展目标无效")), false, Color("#facc15"))
			state["log_message"] = "城市发展牌无法打出：%s。" % str(args.get("error", "目标无效"))
		"military_unit_missing":
			_set_play_state(state, "无军队", "绑定军队不在场。", false, Color("#94a3b8"))
			state["log_message"] = "%s绑定的军队不在场。" % card_label
		"military_unit_cooldown":
			_set_play_state(state, "军队冷却", "军队还需%.1fs才能再行动。" % float(args.get("seconds", 0.0)), false, Color("#facc15"))
			state["log_message"] = "%s所属军队还在执行上一条军令，%.1fs后可再行动。" % [card_label, float(args.get("seconds", 0.0))]
		"military_deployment_invalid":
			_set_play_state(state, "部署限制", "需要%s。" % str(args.get("terrain_label", "有效地形")), false, Color("#facc15"))
			state["log_message"] = "%s部署限制：需要%s。" % [card_label, str(args.get("terrain_label", "有效地形"))]
		"gdp_share_insufficient":
			_set_play_state(state, "需份额", "%sGDP份额需达到%d%%。" % [str(args.get("scope_label", "任一经营区")), int(args.get("required_percent", 0))], false, Color("#facc15"))
			state["log_message"] = "%s无法打出：%sGDP份额需要达到%d%%。" % [card_label, str(args.get("scope_label", "任一经营区")), int(args.get("required_percent", 0))]
		"cash_insufficient":
			_set_play_state(state, "资金不足", "打出需额外¥%d；当前¥%d。" % [int(args.get("cash_cost", 0)), int(args.get("cash", 0))], false, Color("#fb7185"))
			state["log_message"] = "%s无法打出：额外费用¥%d，当前资金¥%d。" % [card_label, int(args.get("cash_cost", 0)), int(args.get("cash", 0))]
		"financial_margin_insufficient":
			_set_play_state(state, "保证金不足", "需费用¥%d + 可退保证金¥%d；当前¥%d。" % [int(args.get("cash_cost", 0)), int(args.get("margin_cash", 0)), int(args.get("cash", 0))], false, Color("#fb7185"))
			state["log_message"] = "%s无法打出：可退保证金¥%d未获授权，当前资金¥%d。" % [card_label, int(args.get("margin_cash", 0)), int(args.get("cash", 0))]
		"bid_reserve_insufficient":
			_set_play_state(state, "报价过高", "需预留打出¥%d + 保证金¥%d + 报价¥%d；当前¥%d。" % [int(args.get("cash_cost", 0)), int(args.get("margin_cash", 0)), int(args.get("bid", 0)), int(args.get("cash", 0))], false, Color("#fb7185"))
		"needs_monster_target":
			_set_play_state(state, "需怪兽目标", "%s｜点击后选择怪兽。" % _playable_detail(args), true, Color("#38bdf8"))
		"needs_player_target":
			_set_play_state(state, "需玩家目标", "%s｜点击后选择目标玩家。" % _playable_detail(args), true, Color("#38bdf8"))
		"catalog_only":
			_set_play_state(state, "仅图鉴", str(requirement.get("requirement_text", "条件：无")), false, Color("#94a3b8"))
		_:
			_set_play_state(state, "不可用", "当前不能打出这张牌。", false, Color("#94a3b8"))
	return state


func compose_hand_card(source: Dictionary) -> Dictionary:
	_hand_compose_count += 1
	var presentation := compose_card(_dictionary(source.get("card", {})))
	var skill := _dictionary(_dictionary(source.get("card", {})).get("skill", {}))
	var play_state := compose_play_eligibility(_dictionary(source.get("eligibility", {})), _dictionary(source.get("card", {})))
	var slot := int(source.get("slot", -1))
	var actionable := bool(play_state.get("actionable", false))
	var effect_text := str(presentation.get("quick_effect_compact", ""))
	if effect_text.strip_edges() == "":
		effect_text = _short_text(str(_dictionary(source.get("card", {})).get("display_text", "")), 44)
	var card_source := {
		"id": "hand_%d" % slot,
		"slot": slot,
		"name": str(presentation.get("display_name", "卡牌")),
		"rank": str(presentation.get("rank_label", "I")),
		"type": str(presentation.get("strategy_route_label", "即时战术")),
		"cost": str(skill.get("cost", skill.get("play_cash", ""))),
		"use_case": str(presentation.get("use_case", "")),
		"table_use": str(presentation.get("use_case", "")),
		"target": str(play_state.get("label", "")),
		"play_state": _hand_state_primary_text(play_state),
		"action_state": _hand_action_text(play_state, skill),
		"actionable": actionable,
		"drop_enabled": actionable,
		"drop_label": _hand_drop_label(play_state, _dictionary(source.get("card", {})), skill),
		"block_reason": str(play_state.get("detail", "")) if not actionable else "",
		"effect": effect_text,
		"why": str(play_state.get("detail", "")),
		"accent": presentation.get("accent", Color("#94a3b8")),
		"requirements": [
			{"text": str(play_state.get("label", "")), "tooltip": str(play_state.get("detail", ""))},
			{"text": str(_dictionary(source.get("card", {})).get("play_requirement_text", ""))},
		],
		"actions": [{
			"id": "play_%d" % slot,
			"label": "出牌",
			"disabled": not actionable,
			"tooltip": str(play_state.get("detail", "")),
		}],
	}
	return CARD_VIEW_SNAPSHOT_SCRIPT.new().apply_dictionary(card_source).to_ui_dictionary().merged(card_source, true)


func compose_resolution(source: Dictionary) -> Dictionary:
	_resolution_compose_count += 1
	var card := _dictionary(source.get("card", {}))
	var skill := _dictionary(card.get("skill", source.get("skill", {})))
	var facts := _dictionary(source.get("animation_facts", {}))
	var card_name := str(card.get("card_name", skill.get("name", "匿名卡牌")))
	var display_name := str(card.get("display_name", card_name))
	var seconds_left := float(source.get("seconds_left", -1.0))
	var display_duration := maxf(0.1, float(source.get("display_duration", 1.0)))
	var targets_monster := bool(card.get("targets_monster", source.get("targets_monster", false)))
	var target_text := _resolution_target_text(_dictionary(source.get("target_facts", {})))
	var stages := _resolution_animation_stages(card_name, skill, facts, display_name)
	var stage_index := _resolution_stage_index(seconds_left, display_duration)
	var stage_label := _resolution_stage_label(stage_index)
	var effect_style := str(source.get("effect_style", ""))
	if effect_style == "":
		effect_style = _resolution_effect_style(skill, targets_monster)
	var effect_style_label := _resolution_effect_style_label(effect_style)
	var display_progress := _resolution_display_progress(seconds_left, display_duration)
	var visual_cue := _resolution_visual_cue_text(effect_style, seconds_left, display_duration)
	var current_stage := str(stages[clampi(stage_index, 0, maxi(0, stages.size() - 1))]) if not stages.is_empty() else "卡面公开，效果等待结算。"
	var timing_text := "分镜：开场→结算→余波"
	if seconds_left >= 0.0:
		timing_text = "当前分镜：%s｜剩余%.1fs" % [stage_label, maxf(0.0, seconds_left)]
	var animation_text := "结算演出：%s\n%s\n%s\n落点：%s" % [current_stage, timing_text, visual_cue, target_text]
	var animation_catalog_text := "开场：卡面公开；结算：效果生效；余波：线索留在轨道。\n%s" % visual_cue
	if stages.size() >= 3:
		animation_catalog_text = "开场：%s\n结算：%s\n余波：%s\n%s" % [str(stages[0]), str(stages[1]), str(stages[2]), visual_cue]
	return {
		"animation_stages": stages,
		"animation_text": animation_text,
		"animation_catalog_text": animation_catalog_text,
		"stage_index": stage_index,
		"stage_label": stage_label,
		"display_progress": display_progress,
		"visual_cue_text": visual_cue,
		"target_text": target_text,
		"aftermath_clue": _resolution_aftermath_clue_text(skill, bool(source.get("resolved", true)), targets_monster),
		"effect_radius": _resolution_effect_radius(skill, float(facts.get("military_range", 0.0))),
		"effect_style": effect_style,
		"effect_style_label": effect_style_label,
		"stage_effect_label": _resolution_stage_effect_label(stage_label, effect_style),
	}


func icon_legend_text() -> String:
	return "图标：◆怪兽 ✦兽技 ⚔军队 ◎互动 ▣城市 ◇商品 △期货 ¥金融 ⇄合约 ◉情报 ◌新闻 ☄天气 ＋补给"


func category_icon(category_id: String) -> String:
	return _category_icon(category_id)


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"compose_count": _compose_count,
		"hand_compose_count": _hand_compose_count,
		"resolution_compose_count": _resolution_compose_count,
		"owns_card_color": true,
		"owns_card_icons": true,
		"owns_card_route": true,
		"owns_card_use_case": true,
		"owns_card_rules_copy": true,
		"owns_hand_card_viewmodel": true,
		"owns_resolution_presentation": true,
		"owns_eligibility_copy": true,
		"calculates_card_price": false,
		"calculates_play_legality": false,
		"mutates_game_state": false,
		"reads_runtime_nodes": false,
		"legacy_main_presentation_active": false,
	}


func _set_play_state(state: Dictionary, label: String, detail: String, actionable: bool, accent: Color) -> void:
	state["label"] = label
	state["detail"] = detail
	state["actionable"] = actionable
	state["accent"] = accent


func _playable_detail(args: Dictionary) -> String:
	var required_percent := int(args.get("required_percent", 0))
	var detail := "%sGDP份额已达%d%%门槛。" % [str(args.get("scope_label", "任一经营区")), required_percent] if required_percent > 0 else "无前置GDP门槛。"
	var cash_cost := int(args.get("cash_cost", 0))
	if cash_cost > 0:
		detail = "%s｜额外¥%d" % [detail, cash_cost]
	return detail


func _face_chips(source: Dictionary, skill: Dictionary) -> Array:
	var entries := [
		{"text": "¥%d" % maxi(0, int(source.get("price", 0))), "fg": Color("#fef3c7"), "bg": Color("#713f12"), "tip": "购买价格；同系列升级仍按I级基准价。"},
		{"text": _roman_rank(int(source.get("rank", skill.get("rank", 1)))), "fg": Color("#dbeafe"), "bg": Color("#1e3a8a"), "tip": "卡牌等级。重复获得同系列牌会自动升级，最高IV。"},
	]
	var required_percent := maxi(0, int(source.get("required_share_percent", 0)))
	if required_percent > 0:
		entries.append({"text": "GDP≥%d%%" % required_percent, "fg": Color("#bbf7d0"), "bg": Color("#14532d"), "tip": str(source.get("play_requirement_text", ""))})
	else:
		entries.append({"text": "免门槛", "fg": Color("#cbd5e1"), "bg": Color("#334155"), "tip": "打出时不要求前置GDP份额。"})
	var cash_cost := maxi(0, int(source.get("play_cash_cost", 0)))
	if cash_cost > 0:
		entries.append({"text": "打出¥%d" % cash_cost, "fg": Color("#fed7aa"), "bg": Color("#7c2d12"), "tip": "打出时需要额外现金；购买费用另算。"})
	if bool(source.get("targets_monster", false)):
		entries.append({"text": "◆目标", "fg": Color("#fecaca"), "bg": Color("#7f1d1d"), "tip": "打出后需要指定一只在场怪兽。"})
	elif bool(source.get("targets_player", false)):
		entries.append({"text": "◎玩家", "fg": Color("#bfdbfe"), "bg": Color("#1e3a8a"), "tip": "打出后需要指定一名玩家。"})
	elif str(skill.get("kind", "")) == "area_trade_contract":
		entries.append({"text": "⇄两区", "fg": Color("#fde68a"), "bg": Color("#713f12"), "tip": "合约牌需要先选择供给区和需求区。"})
	else:
		entries.append({"text": "按选区", "fg": Color("#c4b5fd"), "bg": Color("#312e81"), "tip": "按当前选区、当前商品或卡面规则结算。"})
	entries.append({
		"text": "固定" if bool(skill.get("persistent", false)) else "一次",
		"fg": Color("#fef9c3") if bool(skill.get("persistent", false)) else Color("#e2e8f0"),
		"bg": Color("#854d0e") if bool(skill.get("persistent", false)) else Color("#1f2937"),
		"tip": "固定技能可重复使用；一次性牌结算后离手。",
	})
	return entries


func _hand_action_text(state: Dictionary, skill: Dictionary) -> String:
	var label := str(state.get("label", ""))
	if label == "排队中": return "排队中"
	if label == "首召就绪": return "首召"
	if label == "可否决": return "相位否决"
	if label in ["需怪兽目标", "需玩家目标"]: return "选目标"
	if bool(state.get("actionable", false)): return "释放" if bool(skill.get("persistent", false)) else "打出"
	return label if label != "" else "不可打"


func _hand_state_primary_text(state: Dictionary) -> String:
	var label := str(state.get("label", "不可用"))
	if label == "首召就绪": return "首召"
	if bool(state.get("actionable", false)):
		return "可选目标" if label.begins_with("需") else "可打"
	return label


func _hand_drop_label(play_state: Dictionary, source: Dictionary, skill: Dictionary) -> String:
	if not bool(play_state.get("actionable", false)):
		return "不能出：%s" % _short_text(str(play_state.get("label", "不可打")), 8)
	if bool(source.get("requires_target_monster", false)): return "松开选怪兽"
	if bool(source.get("requires_target_player", false)): return "松开选玩家"
	if bool(skill.get("starter_play_free", false)): return "松开首召"
	return "松开出牌"


func _theme_color(skill: Dictionary) -> Color:
	match str(skill.get("kind", "")):
		"player_role": return Color("#38bdf8")
		"monster_card": return Color("#fb7185")
		"monster_bound_action": return Color("#c084fc")
		"monster_takeover": return Color("#f472b6")
		"military_force", "military_command": return Color("#67e8f9")
		"card_counter": return Color("#a78bfa")
		"player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage": return Color("#60a5fa")
		"city_revenue_boost", "cash_gain", "product_speculation", "product_futures", "product_contract_boon", "area_trade_contract", "route_insurance", "city_product_upgrade", "city_product_shift", "city_demand_shift", "market_stabilize", "product_growth_boon", "route_flow_boon", "city_contract_boon", "region_economy_shift": return Color("#f59e0b")
		"intel_city_reveal", "intel_card_trace", "intel_contract_trace": return Color("#60a5fa")
		"news_event": return Color("#fb923c")
		"weather_control": return Color("#38bdf8")
		"card_access_boon": return Color("#2dd4bf")
		"panic_shift": return Color("#f97316")
		"move", "fly", "burrow": return Color("#22c55e")
		"attack", "charge_attack", "roll_attack": return Color("#ef4444")
		"area_damage", "mudslide", "route_sabotage": return Color("#eab308")
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath": return Color("#a855f7")
		"armor_gain", "guard": return Color("#38bdf8")
		"monster_lure", "special_monster_delay", "roar": return Color("#818cf8")
		"supply_draw": return Color("#14b8a6")
	return Color("#94a3b8")


func _strategy_route_label(skill: Dictionary) -> String:
	var kind := str(skill.get("kind", ""))
	var tags := str(skill.get("tag_text", " "))
	if tags.strip_edges() == "" and skill.get("tags", []) is Array:
		tags = " / ".join(skill.get("tags", []))
	var route_damage := int(skill.get("route_damage", 0)) + int(skill.get("decline_route_damage", 0))
	var repair_routes := int(skill.get("repair_routes", 0))
	var economy_delta := int(skill.get("production_delta", 0)) + int(skill.get("transport_delta", 0)) + int(skill.get("consumption_delta", 0))
	var accept_delta := int(skill.get("accept_production_delta", 0)) + int(skill.get("accept_transport_delta", 0)) + int(skill.get("accept_consumption_delta", 0))
	var decline_delta := int(skill.get("decline_production_delta", 0)) + int(skill.get("decline_transport_delta", 0)) + int(skill.get("decline_consumption_delta", 0))
	var market_pressure := int(skill.get("market_demand_pressure", 0)) + int(skill.get("market_supply_pressure", 0)) + int(skill.get("price_delta", 0))
	if kind == "card_counter": return "直接互动"
	if kind in ["military_force", "military_command"]: return "战斗破坏"
	if kind in ["monster_card", "monster_bound_action", "monster_lure", "monster_takeover"] or tags.contains("怪兽"): return "怪兽路线"
	if kind in ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"] or tags.contains("互动"): return "直接互动"
	if kind in ["intel_city_reveal", "intel_card_trace", "intel_contract_trace"] or tags.contains("情报"): return "情报推理"
	if kind == "news_event" or tags.contains("新闻"): return "新闻信息战"
	if kind == "weather_control" or tags.contains("天气"): return "天气博弈"
	if kind in ["area_trade_contract", "product_contract_boon"] or int(skill.get("contract_income", 0)) > 0 or accept_delta != 0 or decline_delta != 0 or int(skill.get("accept_cash", 0)) != 0 or int(skill.get("decline_cash_penalty", 0)) != 0: return "合约博弈"
	if route_damage > 0 or economy_delta < 0 or kind in ["route_sabotage", "area_damage"]: return "城市压制"
	if kind in ["city_gdp_derivative", "product_speculation", "market_stabilize"] or market_pressure != 0: return "金融投机"
	if kind in ["card_access_boon", "supply_draw"] or int(skill.get("draw_amount", 0)) > 0 or bool(skill.get("card_access_global", false)) or int(skill.get("card_access_extra_hops", 0)) > 0: return "补给构筑"
	if repair_routes > 0 or economy_delta > 0 or kind in ["city_revenue_boost", "cash_gain", "route_insurance", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "product_growth_boon", "city_contract_boon"] or float(skill.get("route_flow_multiplier", 1.0)) > 1.001 or float(skill.get("growth_multiplier", 1.0)) > 1.001 or int(skill.get("revenue_amount", 0)) > 0 or int(skill.get("cash", 0)) > 0: return "城市成长"
	if int(skill.get("damage", 0)) > 0 or kind in ["attack", "charge_attack", "roll_attack", "mudslide", "miasma_shot", "corrosive_breath"]: return "战斗破坏"
	if int(skill.get("panic", 0)) > 0 or kind == "panic_shift": return "怪兽诱导"
	return "即时战术"


func _use_case_text(source: Dictionary, skill: Dictionary, route_label: String) -> String:
	for key in ["use_case", "table_use", "purpose", "when_to_use"]:
		var explicit := str(skill.get(key, "")).strip_edges()
		if explicit != "": return _short_text(explicit, 12)
	var kind := str(skill.get("kind", ""))
	var futures_terms := _dictionary(skill.get("futures_terms", {}))
	var gdp_terms := _dictionary(skill.get("gdp_derivative_terms", {}))
	var direction := str(futures_terms.get("direction", gdp_terms.get("direction", "")))
	if bool(source.get("is_monster_card", false)) or kind == "monster_card": return "召唤/升级怪兽"
	var labels := {
		"monster_bound_action": "释放怪兽技能", "monster_lure": "诱导怪兽转向", "monster_takeover": "夺取怪兽归属",
		"military_force": "部署军队", "military_command": "指挥军队", "card_counter": "反制互动牌",
		"player_hand_disrupt": "拆对手手牌", "player_hand_steal": "偷取对手手牌", "city_control_dispute": "冻结城市归属", "global_barrage": "全场齐射压制",
		"city_revenue_boost": "加城市GDP", "cash_gain": "补现金", "city_product_upgrade": "升级城市商品", "city_product_shift": "换城市商品", "city_demand_shift": "改城市需求",
		"route_insurance": "修复商路", "route_sabotage": "破坏商路", "route_flow_boon": "加速商路", "city_contract_boon": "临时订单增收",
		"area_trade_contract": "连接两区供需", "product_contract_boon": "强化商品合约", "product_growth_boon": "推高商品增长", "region_economy_shift": "改区域经济",
		"product_speculation": "炒商品价格", "price_pump": "炒商品价格", "disaster_insurance": "保险防跌",
		"intel_city_reveal": "查城市业主", "intel_card_trace": "追溯出牌者", "intel_contract_trace": "追溯合约方",
		"news_event": "制造新闻热度", "weather_control": "改写天气预报", "card_access_boon": "扩大购牌范围", "supply_draw": "补手牌",
		"market_stabilize": "稳定市场价格", "panic_shift": "引怪到目标", "area_damage": "破坏区域", "move": "移动怪兽", "fly": "飞行位移", "burrow": "潜行位移",
		"guard": "怪兽格挡", "armor_gain": "给怪兽护甲", "special_monster_delay": "延后怪兽行动", "roar": "吼退怪兽", "miasma_bloom": "布置瘴气", "miasma_reclaim": "回收瘴气",
		"card_owner_guess": "猜卡牌归属", "city_owner_guess": "猜城市业主", "queue": "排队结算", "event": "制造公开事件",
	}
	if labels.has(kind): return str(labels[kind])
	if kind == "product_futures":
		if bool(futures_terms.get("requires_warehouse", false)) or int(futures_terms.get("units", 0)) > 1: return "囤货赌涨"
		return "押商品上涨" if direction == "up" else ("押商品下跌" if direction == "down" else "押商品涨跌")
	if kind == "city_gdp_derivative": return "保护城市GDP" if bool(gdp_terms.get("insurance", false)) else ("押城市GDP涨" if direction == "up" else ("押城市GDP跌" if direction == "down" else "押城市GDP"))
	if kind in ["attack", "charge_attack", "roll_attack", "mudslide", "miasma_shot", "corrosive_breath"]: return "造成战斗伤害"
	var route_uses := {"城市成长":"提高长期收入", "城市压制":"压低对手GDP", "金融投机":"把波动变现金", "合约博弈":"改写供需关系", "情报推理":"获取隐藏线索", "新闻信息战":"制造公开事件", "天气博弈":"改变区域天气", "直接互动":"干扰对手", "怪兽路线":"制造怪兽压力", "补给构筑":"加速拿牌升级", "战斗破坏":"制造破坏", "怪兽诱导":"引怪到目标"}
	return str(route_uses.get(route_label, "临场改局势"))


func _strategy_use_text(skill: Dictionary, route_label: String) -> String:
	match route_label:
		"城市成长": return "在安全城市建立长期GDP和现金流。"
		"城市压制": return "削弱高价值城市、商品或商路。"
		"金融投机": return "用公开波动和风险换取现金收益。"
		"合约博弈": return "连接或改写两区供需关系。"
		"情报推理": return "从公开牌轨和城市线索推断幕后玩家。"
		"新闻信息战": return "制造公开热度、事件与推理噪音。"
		"天气博弈": return "提前改写区域生产和运输窗口。"
		"直接互动": return "打断对手手牌、产权或行动节奏。"
		"怪兽路线": return "召唤、升级或引导怪兽形成地图压力。"
		"补给构筑": return "扩大牌架范围并加速同系列升级。"
		"战斗破坏": return "以伤害、军队或断路制造压力。"
		"怪兽诱导": return "改变怪兽关注目标和到达节奏。"
	return str(skill.get("text", "即时改变桌面局势。"))


func _strategy_summary(skill: Dictionary, route_label: String) -> String:
	return "%s｜%s" % [route_label, _short_text(_strategy_use_text(skill, route_label), 48)]


func _rules_text(display_text: String, key_facts: Array, art_stats: String, compact: bool) -> String:
	var key_text := _join_first_facts(key_facts, 1 if compact else 2)
	if key_text == "": key_text = art_stats
	if compact: return _short_text(key_text if key_text != "" else display_text, 44)
	var short_effect := _short_text(display_text, 56)
	var short_key := _short_text(key_text, 48)
	if short_key == "" or short_effect.contains(short_key) or short_key.contains(short_effect): return short_effect
	return "%s\n%s" % [short_effect, short_key]


func _quick_effect_text(use_case: String, display_text: String, key_facts: Array, art_stats: String, compact: bool) -> String:
	var effect_text := display_text if display_text != "" else art_stats
	var key_text := _join_first_facts(key_facts, 1)
	var combined := effect_text
	if key_text != "" and not effect_text.contains(key_text): combined = "%s｜%s" % [_short_text(effect_text, 22 if compact else 36), _short_text(key_text, 14 if compact else 24)]
	if use_case != "" and not combined.begins_with(use_case): combined = "%s｜%s" % [_short_text(use_case, 8 if compact else 12), combined]
	return _short_text(combined, 34 if compact else 58)


func _art_stats(source: Dictionary, skill: Dictionary, route_label: String) -> String:
	var kind := str(skill.get("kind", ""))
	if kind == "card_counter": return "%s｜响应%s｜强度%d" % [route_label, _duration_text(float(skill.get("counter_window_seconds", source.get("counter_window_default_seconds", 5.0)))), maxi(1, int(skill.get("counter_strength", 1)))]
	if kind == "military_force": return "%s｜%s｜HP%d｜伤%d｜%s" % [str(source.get("military_type_label", "行星防卫军")), str(source.get("military_domain_label", "通用")), int(source.get("military_hp", skill.get("military_hp", 0))), int(source.get("military_damage", skill.get("military_damage", 0))), _duration_text(float(source.get("military_duration", skill.get("military_duration_seconds", 0.0))))]
	if kind == "military_command": return "%s｜%s｜%s" % [route_label, str(source.get("military_command_label", "军令")), _meters_text(float(skill.get("range", 0.0)))]
	if kind == "city_gdp_derivative":
		var terms := _dictionary(skill.get("gdp_derivative_terms", {}))
		return "%s｜%s×%.2f｜%s｜保¥%d｜盈%d/亏%d" % [route_label, "保单" if bool(terms.get("insurance", false)) else ("买涨" if str(terms.get("direction", "up")) == "up" else "做空"), float(terms.get("multiplier", 1.0)), _duration_text(float(terms.get("duration_seconds", 1.0))), int(terms.get("margin_cash", 0)), int(terms.get("maximum_gain", 0)), int(terms.get("maximum_loss", 0))]
	if kind == "product_futures":
		var terms := _dictionary(skill.get("futures_terms", {}))
		return "%s｜%s×%.2f｜%s｜保¥%d｜盈%d/亏%d%s" % [route_label, "看涨" if str(terms.get("direction", "up")) == "up" else "看跌", float(terms.get("multiplier", 1.0)), _duration_text(float(terms.get("duration_seconds", source.get("product_futures_duration_seconds", 1.0)))), int(terms.get("margin_cash", 0)), int(terms.get("maximum_gain", 0)), int(terms.get("maximum_loss", 0)), "｜仓库" if bool(terms.get("requires_warehouse", false)) else ""]
	if kind == "player_hand_disrupt": return "%s｜拆%d%s" % [route_label, maxi(1, int(skill.get("hand_discard_count", 1))), "｜封%s" % _duration_text(float(skill.get("hand_lock_seconds", 0.0))) if float(skill.get("hand_lock_seconds", 0.0)) > 0.0 else ""]
	if kind == "player_hand_steal": return "%s｜牵%d%s" % [route_label, maxi(1, int(skill.get("hand_steal_count", 1))), "｜封%s" % _duration_text(float(skill.get("hand_lock_seconds", 0.0))) if float(skill.get("hand_lock_seconds", 0.0)) > 0.0 else ""]
	if kind == "city_control_dispute": return "%s｜冻结%s｜GDP-%d" % [route_label, _duration_text(float(skill.get("control_block_seconds", 0.0))), int(skill.get("control_gdp_penalty", 0))]
	if kind == "global_barrage": return "%s｜%d城×%d伤" % [route_label, maxi(1, int(skill.get("global_barrage_target_count", 1))), maxi(1, int(skill.get("global_barrage_damage", 1)))]
	if kind != "monster_card":
		if kind == "weather_control": return "%s｜%s｜%s后" % [route_label, str(source.get("weather_label", skill.get("weather_type", "天气"))), _duration_text(float(skill.get("weather_forecast_lead_seconds", source.get("weather_forecast_lead_min_seconds", 60.0))))]
		if int(skill.get("cash", 0)) > 0: return "%s｜+¥%d" % [route_label, int(skill.get("cash", 0))]
		if int(skill.get("revenue_amount", 0)) > 0: return "%s｜GDP+%d" % [route_label, int(skill.get("revenue_amount", 0))]
		if int(skill.get("route_damage", 0)) > 0: return "%s｜断路+%d" % [route_label, int(skill.get("route_damage", 0))]
		if int(skill.get("repair_routes", 0)) > 0: return "%s｜修路%d" % [route_label, int(skill.get("repair_routes", 0))]
		if int(skill.get("draw_amount", 0)) > 0: return "%s｜抽%d" % [route_label, int(skill.get("draw_amount", 0))]
		return route_label
	return "%s｜HP%d｜%s｜移%s｜%s" % [route_label, int(skill.get("hp", 0)), _monster_duration_text(skill, true), _meters_text(float(skill.get("move", 0.0))), _monster_region_text(skill, true)]


func _rule_facts(source: Dictionary, skill: Dictionary) -> Array:
	var facts := []
	facts.append("目标:%s" % ("指定怪兽" if bool(source.get("targets_monster", false)) else ("指定玩家" if bool(source.get("targets_player", false)) else "无需指定怪兽")))
	facts.append("出牌:%s" % ("固定技能，不会消失" if bool(skill.get("persistent", false)) else "一次性，打出后消失"))
	facts.append(str(source.get("play_requirement_text", "条件：无")))
	if str(skill.get("kind", "")) == "monster_card":
		facts.append("生命:%d" % int(skill.get("hp", 0)))
		facts.append("在场:%s" % _monster_duration_text(skill, false))
		facts.append("召唤区域:%s" % _monster_region_text(skill, false))
	var numeric_facts := [
		["move", "移动", "meters"], ["range", "范围", "meters"], ["damage", "伤害", "int"], ["knockback", "击退", "meters"],
		["armor", "护甲", "plus"], ["guard", "格挡", "int"], ["ranged_guard", "远程抗性", "int"], ["panic", "热度", "plus"],
		["revenue_amount", "GDP/min", "plus"], ["cash", "资金", "plus"], ["draw_amount", "候选卡", "plus"], ["repair_routes", "修复商路", "int"],
		["product_level", "商品等级", "plus"], ["product_shift", "主营换线", "int"], ["demand_shift", "需求改造", "int"],
		["route_damage", "商路损伤", "plus"], ["production_delta", "生产", "signed"], ["transport_delta", "交通", "signed"], ["consumption_delta", "消费", "signed"],
		["miasma_count", "瘴气", "int"], ["reclaim_count", "回收瘴气", "int"], ["reveal_city_count", "查区域业主", "int"], ["trace_card_count", "追溯出牌", "int"], ["trace_contract_count", "追溯合约", "int"],
		["hand_discard_count", "拆牌", "int"], ["hand_steal_count", "牵牌", "int"], ["target_cash_penalty", "目标成本", "money"], ["control_gdp_penalty", "归属惩罚", "gdp"],
		["counter_strength", "反制强度", "int"], ["counter_refund", "成功返还", "money"], ["counter_trace", "反制线索", "int"],
	]
	for spec in numeric_facts:
		var value := float(skill.get(spec[0], 0.0))
		if is_zero_approx(value): continue
		match str(spec[2]):
			"meters": facts.append("%s:%s" % [spec[1], _meters_text(value)])
			"plus": facts.append("%s:+%d" % [spec[1], int(value)])
			"signed": facts.append("%s:%s" % [spec[1], _signed_int(int(value))])
			"money": facts.append("%s:¥%d" % [spec[1], int(value)])
			"gdp": facts.append("%s:%dGDP/min" % [spec[1], int(value)])
			_: facts.append("%s:%d" % [spec[1], int(value)])
	var duration_specs := [["hand_lock_seconds", "封锁手牌"], ["control_block_seconds", "产权冻结"], ["counter_window_seconds", "响应窗口"], ["weather_forecast_lead_seconds", "预告"], ["weather_duration_seconds", "持续"], ["military_duration_seconds", "军队在场"]]
	for spec in duration_specs:
		var seconds := float(skill.get(spec[0], 0.0))
		if seconds > 0.0: facts.append("%s:%s" % [spec[1], _duration_text(seconds)])
	var contract_seconds := _skill_duration_seconds(source, skill, "contract_seconds", "contract_turns", 0)
	if int(skill.get("contract_income", 0)) > 0: facts.append("临时合约:+%d/min/%s" % [int(skill.get("contract_income", 0)), _duration_text(contract_seconds)])
	var growth_seconds := _skill_duration_seconds(source, skill, "growth_seconds", "growth_turns", 0)
	if float(skill.get("growth_multiplier", 1.0)) > 1.001: facts.append("商品增速:×%.2f/%s" % [float(skill.get("growth_multiplier", 1.0)), _duration_text(growth_seconds)])
	var route_seconds := _skill_duration_seconds(source, skill, "route_flow_seconds", "route_flow_turns", int(ceil(growth_seconds / maxf(1.0, float(source.get("economy_legacy_turn_seconds", 30.0))))))
	if float(skill.get("route_flow_multiplier", 1.0)) > 1.001: facts.append("流通:×%.2f/%s" % [float(skill.get("route_flow_multiplier", 1.0)), _duration_text(route_seconds)])
	var gdp_terms := _dictionary(skill.get("gdp_derivative_terms", {}))
	if not gdp_terms.is_empty():
		facts.append("GDP方向:%s" % ("保单" if bool(gdp_terms.get("insurance", false)) else ("买涨" if str(gdp_terms.get("direction", "")) == "up" else "做空")))
		facts.append("GDP倍率:×%.2f" % float(gdp_terms.get("multiplier", 0.0)))
		facts.append("持续时间:%s" % _duration_text(float(gdp_terms.get("duration_seconds", 0.0))))
		facts.append("保证金:¥%d" % int(gdp_terms.get("margin_cash", 0)))
		facts.append("最大收益:¥%d" % int(gdp_terms.get("maximum_gain", 0)))
		facts.append("最大损失:¥%d" % int(gdp_terms.get("maximum_loss", 0)))
		if int(gdp_terms.get("destroy_bonus", 0)) > 0: facts.append("毁城加成:¥%d" % int(gdp_terms.get("destroy_bonus", 0)))
	var futures_terms := _dictionary(skill.get("futures_terms", {}))
	if not futures_terms.is_empty():
		facts.append("期货方向:%s" % ("看涨" if str(futures_terms.get("direction", "up")) == "up" else "看跌"))
		facts.append("持仓倍率:×%.2f" % float(futures_terms.get("multiplier", 1.0)))
		facts.append("持续时间:%s" % _duration_text(float(futures_terms.get("duration_seconds", 0.0))))
		facts.append("保证金:¥%d" % int(futures_terms.get("margin_cash", 0)))
		facts.append("最大收益:¥%d" % int(futures_terms.get("maximum_gain", 0)))
		facts.append("最大损失:¥%d" % int(futures_terms.get("maximum_loss", 0)))
		if bool(futures_terms.get("requires_warehouse", false)): facts.append("仓储:%d单位｜毁灭按剩余生命结算" % int(futures_terms.get("units", 1)))
	if str(skill.get("weather_type", "")) != "": facts.append("天气:%s" % str(source.get("weather_label", skill.get("weather_type", "天气"))))
	if int(skill.get("weather_zone_count", 0)) > 0: facts.append("覆盖:%d区" % int(skill.get("weather_zone_count", 0)))
	if int(skill.get("global_barrage_damage", 0)) > 0: facts.append("齐射伤害:%d×%d城" % [int(skill.get("global_barrage_damage", 0)), maxi(1, int(skill.get("global_barrage_target_count", 1)))])
	if int(skill.get("global_barrage_route_damage", 0)) > 0: facts.append("齐射断路:+%d" % int(skill.get("global_barrage_route_damage", 0)))
	if int(skill.get("military_hp", 0)) > 0:
		facts.append("兵种:%s/%s" % [str(source.get("military_type_label", "军队")), str(source.get("military_mobility_summary", "通用"))])
		facts.append("军队生命:%d" % int(skill.get("military_hp", 0)))
	if int(skill.get("military_damage", 0)) > 0: facts.append("军队火力:%d" % int(skill.get("military_damage", 0)))
	if str(skill.get("military_command", "")) != "": facts.append("军令:%s" % str(source.get("military_command_label", "军令")))
	return facts


func _key_rule_facts(facts: Array) -> Array:
	var result := []
	for fact_variant in facts:
		var fact := str(fact_variant)
		if fact.begins_with("目标:") or fact.begins_with("出牌:") or fact.begins_with("打出条件："): continue
		if fact.strip_edges() != "": result.append(fact)
	return result


func _detail_tooltip(source: Dictionary, presentation: Dictionary, display_text: String) -> String:
	var key_text := _join_first_facts(_array(presentation.get("key_rule_facts", [])), 4)
	if key_text == "": key_text = str(presentation.get("art_stats", ""))
	return "%s｜%s｜¥%d\n%s\n%s\n%s" % [
		"%s %s" % [str(presentation.get("icon", "□")), str(presentation.get("display_name", source.get("card_name", "卡牌")))],
		str(presentation.get("icon_type_label", "卡牌")),
		int(presentation.get("price", 0)),
		str(presentation.get("icon_route_label", "通用路线")),
		_short_text(display_text, 96),
		key_text,
	]


func _category_id(source: Dictionary, skill: Dictionary) -> String:
	if bool(source.get("is_monster_card", false)) or str(skill.get("kind", "")) == "monster_card": return "monster"
	var kind := str(skill.get("kind", ""))
	if kind == "monster_bound_action" or bool(source.get("is_direct_monster_skill", false)) or kind in ["move", "fly", "burrow", "attack", "charge_attack", "roll_attack", "area_damage", "mudslide", "miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath", "armor_gain", "guard", "roar"]: return "monster_skill"
	if kind in ["military_force", "military_command"]: return "military"
	if kind in ["card_counter", "player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"]: return "interaction"
	if kind == "city_gdp_derivative": return "finance"
	if kind == "product_futures": return "futures"
	if kind in ["product_speculation", "product_contract_boon", "product_growth_boon", "market_stabilize", "cash_gain"]: return "commodity"
	if kind in ["area_trade_contract", "city_contract_boon"]: return "contract"
	if kind in ["city_revenue_boost", "route_insurance", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "route_sabotage", "region_economy_shift"]: return "city"
	if kind == "news_event": return "news"
	if kind == "weather_control": return "weather"
	if kind in ["monster_lure", "special_monster_delay", "monster_takeover", "panic_shift"] or bool(source.get("targets_monster", false)): return "tactic"
	if kind in ["supply_draw", "card_access_boon"]: return "supply"
	if kind in ["intel_city_reveal", "intel_card_trace", "intel_contract_trace"]: return "intel"
	return "other"


func _primary_type_label(source: Dictionary, skill: Dictionary) -> String:
	if bool(source.get("is_monster_card", false)) or str(skill.get("kind", "")) == "monster_card": return "怪兽牌"
	var labels := {"monster_bound_action":"怪兽技能牌", "military_force":"军队牌", "military_command":"军令技能牌", "card_counter":"玩家互动牌", "player_hand_disrupt":"玩家互动牌", "player_hand_steal":"玩家互动牌", "city_control_dispute":"玩家互动牌", "global_barrage":"玩家互动牌", "city_gdp_derivative":"金融牌", "product_futures":"期货牌", "product_speculation":"商品牌", "product_contract_boon":"商品牌", "product_growth_boon":"商品牌", "market_stabilize":"商品牌", "area_trade_contract":"合约牌", "city_contract_boon":"合约牌", "city_revenue_boost":"经营牌", "city_product_upgrade":"经营牌", "city_product_shift":"经营牌", "city_demand_shift":"经营牌", "route_insurance":"经营牌", "route_flow_boon":"经营牌", "route_sabotage":"经营牌", "region_economy_shift":"经营牌", "intel_city_reveal":"情报/补给牌", "intel_card_trace":"情报/补给牌", "intel_contract_trace":"情报/补给牌", "card_access_boon":"情报/补给牌", "supply_draw":"情报/补给牌", "news_event":"新闻牌", "weather_control":"天气牌", "monster_lure":"诱导牌", "monster_takeover":"诱导牌", "special_monster_delay":"诱导牌", "panic_shift":"诱导牌"}
	if labels.has(str(skill.get("kind", ""))): return str(labels[str(skill.get("kind", ""))])
	return "怪兽技能牌" if bool(source.get("is_direct_monster_skill", false)) else "战术牌"


func _subtype_label(source: Dictionary, skill: Dictionary, route_label: String) -> String:
	match str(skill.get("kind", "")):
		"city_gdp_derivative": return "GDP衍生品"
		"product_futures": return "商品期货"
		"card_counter": return "相位否决"
		"military_force": return "%s资产" % str(source.get("military_domain_label", "通用"))
		"military_command": return "可回收指令"
	return route_label


func _category_icon(category_id: String) -> String:
	return str({"monster":"◆", "monster_skill":"✦", "military":"⚔", "interaction":"◎", "city":"▣", "commodity":"◇", "futures":"△", "finance":"¥", "contract":"⇄", "intel":"◉", "news":"◌", "weather":"☄", "tactic":"⌁", "supply":"＋", "other":"□"}.get(category_id, "□"))


func _route_icon(route_label: String) -> String:
	return str({"城市成长":"▣", "城市压制":"▥", "金融投机":"¥", "合约博弈":"⇄", "情报推理":"◉", "新闻信息战":"◌", "天气博弈":"☄", "直接互动":"◎", "怪兽路线":"◆", "补给构筑":"＋", "战斗破坏":"⚔", "怪兽诱导":"⌁"}.get(route_label, "□"))


func _monster_duration_text(skill: Dictionary, compact: bool) -> String:
	var duration := float(skill.get("duration", -1.0))
	if duration < 0.0: return "常驻" if compact else "不限时（不会自然离场）"
	return "%.0fs" % duration if compact else "%.0f秒后自然离场" % duration


func _monster_region_text(skill: Dictionary, compact: bool) -> String:
	if bool(skill.get("starter_play_free", false)): return "不限区" if compact else "无（起始怪兽牌）"
	match str(skill.get("summon_access", "any")):
		"monster_zone": return "怪区邻接" if compact else "怪兽落地区或相邻区域"
		"land_monster_zone": return "陆地怪区" if compact else "陆地区域，且必须是怪兽落地区或相邻区域"
		"ocean_monster_zone": return "海洋怪区" if compact else "海洋区域，且必须是怪兽落地区或相邻区域"
		"land": return "仅陆地" if compact else "仅限陆地区域"
		"ocean": return "仅海洋" if compact else "仅限海洋区域"
		"any", "": return "不限区" if compact else "无"
	return str(skill.get("summon_access", "无"))


func _resolution_animation_stages(_card_name: String, skill: Dictionary, facts: Dictionary, display_name: String) -> Array:
	var family := str(facts.get("family", ""))
	var label := display_name if display_name != "" else (family if family != "" else "匿名卡牌")
	var kind := str(skill.get("kind", ""))
	match kind:
		"monster_card":
			var monster_name := str(facts.get("monster_name", skill.get("monster_name", "")))
			if monster_name == "": monster_name = family.replace("怪兽·", "")
			return [
				"轨道上撕开匿名召唤窗，%s的巨影先于出牌者身份坠向星球。" % monster_name,
				"落点播报生命%d、移动%s、在场%s；若同名怪兽在场，则转为升级并刷新生命/时间。" % [int(skill.get("hp", 0)), str(facts.get("monster_move_text", "0m")), str(facts.get("monster_duration_text", "常驻"))],
				"怪兽归属仍隐藏；之后它受伤造成的资金损失才会把召唤者线索公开。",
			]
		"card_counter": return ["%s在相位响应窗口内翻开，紫色断层盖住上一张匿名牌。" % label, "系统公开宣布原牌被折叠取消；反制者身份仍隐藏，只留下GDP份额门槛与时机线索。", "如果由角色能力把怪兽牌改写而来，原怪兽牌会被消耗，轨道只显示这次匿名反制。"]
		"military_force":
			var unit_label := str(facts.get("military_unit_type_label", "防卫军"))
			return [
				"%s从近地轨道投下短时%s，军徽被匿名遮罩处理。" % [label, unit_label],
				"%s生命%d、火力%d、机动%s、在场%s写入地图；%s；同一玩家达到军队上限时只刷新较早军队。" % [unit_label, int(facts.get("military_hp", 0)), int(facts.get("military_damage", 0)), str(facts.get("military_move_text", "0m")), str(facts.get("military_duration_text", "0秒")), str(facts.get("military_mobility_summary", "按卡面移动"))],
				"军队不会自主行动；移动不造成怪兽式建筑破坏，但军事行动可能留下短时GDP压力。",
			]
		"military_command": return ["%s以匿名军令形式亮起，地图只显示防卫军行动，不显示下令者。" % label, "军令类型为%s：前进、保卫、摧毁或攻击怪兽之一；执行后进入短冷却。" % str(facts.get("military_command_label", "军令")), "军队受伤不会让操控者损失资金，因此它更像一次短时公开战术资产。"]
		"city_revenue_boost": return ["%s翻开时，目标城市上空亮起匿名投资光幕。" % label, "楼群、广告牌和隐形合同同步加码，GDP/min数字从城市边缘浮起。", "收益留在城市经营账本里，但出牌者身份仍只能靠城市业主与商品流向推测。"]
		"city_contract_boon": return ["%s盖下临时合约封印，城市航港短暂变成高价订单会场。" % label, "合约沙漏和额外GDP/min挂到城市卡片旁，持续效果逐步扣减。", "合同余波会继续影响GDP，其他玩家只能从该城收入异动反推匿名出牌者。"]
		"route_flow_boon", "route_insurance": return ["%s打开一条发光商路，运输节点像星港灯带一样被点亮。" % label, "受损路线被修补或加速，流通倍率贴到目标城市的商路状态上。", "持续时间内，途经商品会以更快速度转成GDP/min。"]
		"route_sabotage": return ["%s以黑客遮罩侵入公开城市商路，运输线先闪烁再断裂。" % label, "目标城市追加商路损伤压力，区域热度也会留下可观察的破坏痕迹。", "真实业主仍不公开，但被破坏商路会改变相关商品的运输和城市收入。"]
		"product_speculation": return ["%s把当前商品推上匿名交易屏，价格曲线先剧烈抖动。" % label, "卡牌不直接改价，而是写入临时供需压力，等待下一次市场重算兑现。", "现金收益立即进匿名玩家账本；市场波动则成为其他玩家的反推证据。"]
		"city_gdp_derivative": return ["%s翻面时，目标城市上方出现匿名买涨、做空或保单盘口。" % label, "系统锁定该城即时GDP、保证金、持续时间和最大盈亏；到期按真实GDP变化结算。", "城市毁灭会立即结算全部方向：做空/保单按条款获利，买涨承担封顶损失；收款人仍保持匿名。"]
		"product_contract_boon": return ["%s把远期合约钉到当前商品，订单影像沿商路扩散。" % label, "持续供需压力和可能的流通倍率进入商品天气，按秒衰减。", "商品价格不会被手动改写，只会在后续供需重算里体现这张牌的余波。"]
		"area_trade_contract": return ["%s公开翻面：供给区、需求区和合约商品被投到所有玩家屏幕中央。" % label, "公开展示结束后，目标城市真实业主会再获得独立签约/拒绝窗口；发起者仍保持匿名。", "签约会写入区域供需和流通奖励，拒签或超时会按卡面惩罚落到账本与商路。"]
		"player_hand_disrupt": return ["%s翻面时，目标玩家头像被短暂标蓝，出牌者仍被匿名遮罩盖住。" % label, "系统私下拆除目标的一张普通手牌；具体牌名只进入目标玩家自己的流水。", "公开轨道只留下“谁被拆牌”和GDP份额门槛，方便其他玩家反推谁最受益。"]
		"player_hand_steal": return ["%s打开一条隐形补给索，目标玩家与匿名出牌者之间闪过牵取轨迹。" % label, "目标的一张普通手牌会被私下牵走；若牵取方无法接收，则转化成拆牌和情报补偿。", "手牌内容不公开，但目标、时机和商品门槛会成为身份推理线索。"]
		"city_control_dispute": return ["%s把目标城市的产权登记切成多层匿名印章。" % label, "城市进入短暂产权争议，GDP/min受到归属惩罚；真实业主仍不公开。", "争议会留在城市公开线索中，可配合做空、怪兽破坏或归属竞猜。"]
		"global_barrage": return ["%s展开轨道齐射矩阵，数座高价值城市被依次锁定。" % label, "齐射优先打击非己方高GDP城市，造成区域/城市伤害，并可能追加商路损伤。", "所有目标都会公开，强压制同时也暴露出牌者可能想阻止谁领先。"]
		"product_growth_boon": return ["%s点燃当前商品的增长光环，相关商路出现短暂共鸣。" % label, "正向价格增速与流通倍率进入商品天气，并用沙漏显示持续窗口。", "如果城市依赖该商品，后续GDP会在生产、运输或消费端被放大。"]
		"market_stabilize": return ["%s把交易屏切成冷色，过热的供需噪声被逐层压平。" % label, "当前商品的临时供需压力被削减，长期波动参数也会下降。", "市场仍按供需重算，稳定痕迹会留在商品图鉴和经济天气里。"]
		"city_product_upgrade", "city_product_shift", "city_demand_shift": return ["%s投下城市产业蓝图，目标城市的商品/需求槽位被高亮。" % label, "主营商品升级、换线或需求改造逐项写入城市经营结构。", "城市之后的GDP会按新的生产、需求和商路匹配重新结算。"]
		"region_economy_shift": return ["%s把区域切成生产、交通、消费三层经济网格。" % label, "卡面改写对应区域参数：生产量、公共交通速度或消费需求会升降。", "区域GDP来源随之改变，商路和商品流速会在之后的秒级现金流中体现。"]
		"cash_gain": return ["%s从轨道金库投下匿名资金包，卡轨只显示金额不显示收款人。" % label, "资金立即进入出牌者私有账本，并记录为卡牌经济事件。", "其他玩家只能从后续竞价、建城和购牌节奏推测这笔钱去了谁手里。"]
		"panic_shift": return ["%s把目标区域推上星际热搜，新闻噪声覆盖地图。" % label, "区域热度上升，怪兽目标概率随之偏移；这不是被动新闻，只是卡牌制造的关注。", "如果热度过载，区域还可能因恐慌触发额外损伤。"]
		"news_event": return ["%s以匿名新闻源身份插入全屏播报，卡轨只显示新闻类型不显示出牌者。" % label, "目标区域热度、商品供需、商路或生产/消费会按卡面数值变化。", "新闻不会被动发生；这次公开余波会留给所有玩家反推谁最受益。"]
		"weather_control": return ["%s接入星球气象台，把下一条天气预报改写到目标区域附近。" % label, "所有玩家提前看到天气类型、预报沙漏、覆盖区域和持续时间，可以据此建城、买涨/做空或转移怪兽。", "到点后天气才生效，生产、交通和消费修正会体现在秒级GDP中。"]
		"supply_draw": return ["%s呼叫补给无人机，镜头从当前区域的卡池向手牌区拉线。" % label, "玩家从怪兽落地区/相邻区额外获得候选卡，重复牌会按规则合成升级。", "补给来源会留在卡牌记录里，但出牌者仍保持匿名。"]
		"monster_takeover": return ["%s在目标怪兽身上盖下新的匿名归属印记。" % label, "旧绑定技能被撤销，新归属者接收这只怪兽的后续资金线索和固定技能关系。", "夺取者不会公开；直到怪兽受伤造成资金损失，新的归属线索才浮出水面。"]
		"monster_lure", "special_monster_delay", "monster_bound_action": return ["%s锁定目标怪兽，中央卡面投出一次性诱导波形。" % label, "怪兽仍不是常驻可控单位；诱导牌只会改写下一次自动移动方向或延后一次特殊行动。", "指令结束后怪兽继续按自身概率自动行动，只留下匿名出牌痕迹。"]
		"move", "fly", "burrow": return ["%s在目标怪兽脚下画出移动轨迹，地图投影被拉成一条行动线。" % label, "怪兽沿路线移动，经过或落点区域会按移动破坏规则承受损伤。", "移动结束后区域伤害、城市受损和怪兽位置都会成为公开局势。"]
		"attack", "charge_attack", "roll_attack": return ["%s把目标怪兽推入近战镜头，攻击范围和击退方向同时亮起。" % label, "命中的怪兽承受伤害与击退；移动/击退路径会继续压坏途经城市和区域。", "战斗结果公开，但这次是谁借卡牌引导怪兽出手仍然匿名。"]
		"area_damage", "mudslide": return ["%s把地图缩到目标区域，危险半径像红色雷达圈一样展开。" % label, "区域HP、城市HP和热度按卡面数值结算，相关商路可能受到间接影响。", "破坏痕迹留在地图上，供玩家反推谁更想压低这里的GDP。"]
		"miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath": return ["%s释放紫色瘴气分镜，雾带沿怪兽与区域之间蔓延。" % label, "瘴气会被布置、回收或转成伤害/回复，影响后续怪兽目标判断。", "被污染区域在地图上保留状态，成为资源掠夺与怪兽聚集的新诱因。"]
		"armor_gain", "guard": return ["%s把目标怪兽包进防御镜头，护甲或格挡数值浮到怪兽旁。" % label, "后续受击时先消耗防御层，部分格挡还会影响远程伤害。", "防御来源不公开，但怪兽耐久变化会成为所有玩家都能观察的线索。"]
		"roar": return ["%s让目标怪兽的吼声扩散成冲击环。" % label, "范围内怪兽行动被延后，自动行动节奏在时间轴上后移。", "控场余波不会改变归属，只改变下一轮怪兽行为窗口。"]
	return ["%s在中央轨道翻开，卡面公开但出牌者保持匿名。" % label, "系统按卡面效果、目标和GDP份额条件进行结算。", "结算结果进入地图、经济账本或怪兽状态，供所有玩家继续推理。"]


func _resolution_target_text(facts: Dictionary) -> String:
	var pieces: Array[String] = []
	var monster_slot := int(facts.get("monster_slot", -1))
	if monster_slot >= 0:
		pieces.append("目标怪兽：怪%d·%s" % [monster_slot + 1, str(facts.get("monster_name", "怪兽"))])
	var player_index := int(facts.get("player_index", -1))
	if player_index >= 0:
		pieces.append("目标玩家：玩家%d" % (player_index + 1))
	if bool(facts.get("is_contract", false)):
		pieces.append("合约：%s→%s" % [str(facts.get("contract_source", "未选区")), str(facts.get("contract_target", "未选区"))])
		pieces.append("合约商品：%s" % str(facts.get("contract_product", "未选")))
	var district_name := str(facts.get("district_name", ""))
	if district_name != "":
		pieces.append("区域：%s" % district_name)
	var trade_product := str(facts.get("trade_product", ""))
	if trade_product != "":
		pieces.append("商品：%s" % trade_product)
	if pieces.is_empty():
		pieces.append("目标类型：%s" % ("指定怪兽" if bool(facts.get("requires_monster_target", false)) else "按当前区域/商品结算"))
	return "｜".join(pieces)


func _resolution_stage_index(seconds_left: float, display_duration: float) -> int:
	if seconds_left < 0.0:
		return 0
	var progress := _resolution_display_progress(seconds_left, display_duration)
	if progress < 0.34:
		return 0
	if progress < 0.68:
		return 1
	return 2


func _resolution_display_progress(seconds_left: float, display_duration: float) -> float:
	return clampf(1.0 - maxf(0.0, seconds_left) / maxf(0.1, display_duration), 0.0, 1.0)


func _resolution_stage_label(stage_index: int) -> String:
	return str({0:"开场", 1:"结算", 2:"余波"}.get(clampi(stage_index, 0, 2), "开场"))


func _resolution_visual_cue_text(style: String, seconds_left: float, display_duration: float) -> String:
	var style_label := _resolution_effect_style_label(style)
	if seconds_left >= 0.0:
		var stage_label := _resolution_stage_label(_resolution_stage_index(seconds_left, display_duration))
		return "视觉提示：%s演出｜地图播报：%s｜展示进度：%d%%" % [style_label, _resolution_stage_effect_label(stage_label, style), int(round(_resolution_display_progress(seconds_left, display_duration) * 100.0))]
	return "视觉提示：%s演出｜地图播报：%s / %s / %s" % [style_label, _resolution_stage_effect_label("开场", style), _resolution_stage_effect_label("结算", style), _resolution_stage_effect_label("余波", style)]


func _resolution_aftermath_clue_text(skill: Dictionary, resolved: bool, targets_monster: bool) -> String:
	if not resolved: return "结算失败也会暴露条件缺口"
	var kind := str(skill.get("kind", ""))
	if kind == "monster_card": return "怪兽HP/时间/落点成为公开线索"
	if targets_monster or kind in ["move", "fly", "burrow", "attack", "charge_attack", "roll_attack", "area_damage", "mudslide", "miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath", "armor_gain", "guard", "roar", "monster_lure", "special_monster_delay", "monster_takeover", "monster_bound_action"]: return "怪兽位置/耐久/状态变化可追踪"
	if kind in ["city_revenue_boost", "city_contract_boon", "city_product_upgrade", "city_product_shift", "city_demand_shift"]: return "城市经营结构和账本会持续变化"
	if kind == "area_trade_contract": return "匿名合约会改写区域供需与签拒线索"
	if kind in ["player_hand_disrupt", "player_hand_steal"]: return "目标玩家公开，手牌细节私密"
	if kind == "city_control_dispute": return "城市产权争议会压低GDP并留下归属线索"
	if kind == "global_barrage": return "多座目标城市公开受击，可反推压制意图"
	if kind in ["route_flow_boon", "route_insurance", "route_sabotage"]: return "商路速度或断损会影响后续GDP"
	if kind in ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize"]: return "商品天气和供需压力等待重算"
	if kind == "region_economy_shift": return "区域生产/交通/消费参数已改写"
	if kind == "news_event": return "匿名新闻改变热度/供需/商路线索"
	if kind == "weather_control": return "星球天气预报已被改写"
	if kind == "panic_shift": return "区域热度会偏移怪兽目标"
	if kind == "supply_draw": return "补给来源暴露卡牌获取半径"
	if kind == "cash_gain": return "资金流向隐藏但节奏可推理"
	return "公开结果留下匿名推理痕迹"


func _resolution_effect_radius(skill: Dictionary, military_range: float) -> float:
	var range_m := float(skill.get("range", 0.0))
	if range_m > 0.0: return clampf(range_m, 60.0, 340.0)
	var kind := str(skill.get("kind", ""))
	if kind == "monster_card": return 120.0
	if kind == "military_force": return clampf(military_range, 90.0, 360.0)
	if kind == "military_command": return clampf(float(skill.get("range", 220.0)), 80.0, 330.0)
	if kind == "card_counter": return 145.0
	if kind.contains("city") or kind in ["route_sabotage", "route_flow_boon", "route_insurance", "area_trade_contract", "news_event", "weather_control"]: return 105.0
	if kind.contains("product") or kind == "market_stabilize": return 90.0
	return 75.0


func _resolution_effect_style(skill: Dictionary, targets_monster: bool) -> String:
	var kind := str(skill.get("kind", ""))
	if kind == "monster_card": return "summon"
	if kind == "card_counter": return "counter"
	if kind in ["military_force", "military_command"]: return "military"
	if targets_monster or kind in ["move", "fly", "burrow", "attack", "charge_attack", "roll_attack", "area_damage", "mudslide", "miasma_shot", "miasma_bloom", "miasma_reclaim", "corrosive_breath", "armor_gain", "guard", "roar", "monster_lure", "special_monster_delay", "monster_takeover", "monster_bound_action"]: return "monster_command"
	if kind in ["city_revenue_boost", "city_contract_boon", "city_product_upgrade", "city_product_shift", "city_demand_shift", "route_flow_boon", "route_insurance", "route_sabotage", "area_trade_contract"]: return "city"
	if kind in ["player_hand_disrupt", "player_hand_steal", "city_control_dispute", "global_barrage"]: return "interaction"
	if kind in ["product_speculation", "product_futures", "product_contract_boon", "product_growth_boon", "market_stabilize"]: return "product"
	if kind == "region_economy_shift": return "region"
	if kind == "news_event": return "news"
	if kind == "weather_control": return "weather"
	if kind == "panic_shift": return "heat"
	if kind == "supply_draw": return "supply"
	if kind == "cash_gain": return "cash"
	return "generic"


func _resolution_effect_style_label(style: String) -> String:
	return str({"summon":"召唤", "counter":"反制", "military":"军队", "monster_command":"指令", "city":"城市", "product":"商品", "region":"区域", "news":"新闻", "weather":"天气", "interaction":"互动", "heat":"热度", "supply":"补给", "cash":"资金", "generic":"卡牌"}.get(style, "卡牌"))


func _resolution_stage_effect_label(stage_label: String, style: String) -> String:
	return "%s%s" % [_resolution_effect_style_label(style), stage_label]


func _skill_duration_seconds(source: Dictionary, skill: Dictionary, seconds_key: String, turns_key: String, default_turns: int) -> float:
	if skill.has(seconds_key): return maxf(0.0, float(skill.get(seconds_key, 0.0)))
	return float(maxi(0, int(skill.get(turns_key, default_turns)))) * maxf(1.0, float(source.get("economy_legacy_turn_seconds", 30.0)))


func _duration_text(seconds: float) -> String:
	var total := maxi(1, int(round(seconds)))
	if total < 60: return "%d秒" % total
	var minutes := int(float(total) / 60.0)
	var rest := total % 60
	return "%d分钟" % minutes if rest == 0 else "%d分%d秒" % [minutes, rest]


func _meters_text(value: float) -> String:
	return "%.1fkm" % (value / 1000.0) if value >= 1000.0 else "%.0fm" % value


func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else "%d" % value


func _roman_rank(rank: int) -> String:
	return str({1:"I", 2:"II", 3:"III", 4:"IV"}.get(clampi(rank, 1, 4), "I"))


func _join_first_facts(facts: Array, max_count: int) -> String:
	var pieces := []
	for fact_variant in facts:
		var fact := str(fact_variant).strip_edges()
		if fact == "": continue
		pieces.append(fact)
		if pieces.size() >= maxi(1, max_count): break
	return "｜".join(pieces)


func _short_text(value: String, limit: int) -> String:
	if limit <= 0 or value.length() <= limit: return value
	return value.substr(0, maxi(0, limit - 1)) + "…"


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []
