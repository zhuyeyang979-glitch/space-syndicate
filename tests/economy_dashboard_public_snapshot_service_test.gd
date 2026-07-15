extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/EconomyDashboardPublicSnapshotService.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SERVICE_SCENE) as PackedScene
	_expect(packed != null, "service scene loads")
	var service := packed.instantiate() if packed != null else null
	_expect(service != null, "service scene instantiates")
	if service == null:
		_finish()
		return
	root.add_child(service)
	service.call("configure", {})
	var source := _source()
	var snapshot: Dictionary = service.call("compose", source)
	_expect(str(snapshot.get("summary_text", "")).contains("经济总览") and str(snapshot.get("summary_text", "")).contains("GDP趋势") and str(snapshot.get("summary_text", "")).contains("玩家经济流水"), "summary preserves the public economy read order")
	_expect((snapshot.get("overview_cards", []) as Array).size() == 4, "four overview cards are composed")
	var dashboard := snapshot.get("dashboard", {}) as Dictionary
	_expect((dashboard.get("chips", []) as Array).size() == 3 and (dashboard.get("kpis", []) as Array).size() == 4 and (dashboard.get("decisions", []) as Array).size() == 3 and (dashboard.get("lanes", []) as Array).size() == 6, "dashboard contract is complete")
	_expect(str(((dashboard.get("kpis", []) as Array)[0] as Dictionary).get("value", "")) == "240", "supplied GDP is displayed without recalculation")
	_expect(str(((dashboard.get("decisions", []) as Array)[0] as Dictionary).get("body", "")).contains("环晶电池"), "top product drives the supplied decision hint")
	_expect(str(((dashboard.get("lanes", []) as Array)[1] as Dictionary).get("lines", [""])[0]).contains("低温藻"), "cold lane is sorted from supplied cold scores")
	_expect(str(((dashboard.get("lanes", []) as Array)[0] as Dictionary).get("lines", [""])[0]).contains("天气价格增速+18%"), "product lane explains the public weather price-growth contribution")
	_expect(str(((dashboard.get("lanes", []) as Array)[2] as Dictionary).get("lines", [""])[0]).contains("ion_storm生产+20%"), "city lane explains the public weather income contribution")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(not bool(debug.get("calculates_product_prices", true)) and not bool(debug.get("calculates_city_income", true)) and not bool(debug.get("calculates_cashflow", true)) and not bool(debug.get("evaluates_private_truth", true)), "service owns no economy rules")
	_expect(_is_pure_data(snapshot) and not _contains_private_key(snapshot), "snapshot is viewer-safe pure data")
	var injected := source.duplicate(true)
	injected["hidden_owner"] = 3
	injected["private_plan"] = "secret-market-plan"
	var injected_snapshot: Dictionary = service.call("compose", injected)
	_expect(not _contains_private_key(injected_snapshot) and not JSON.stringify(injected_snapshot).contains("secret-market-plan"), "unknown private input is never copied")
	var empty_snapshot: Dictionary = service.call("compose", {"valid": false})
	_expect(str(empty_snapshot.get("summary_text", "")).contains("还没有当前局经济数据") and (empty_snapshot.get("overview_cards", []) as Array).size() == 1, "empty state is safe and actionable")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true, "selected_name": "测试玩家", "selected_gdp_per_minute": 240, "business_cycle_count": 3, "monster_count": 1, "weather_text": "太阳风：能源需求上升", "clue_count": 4,
		"kpi_columns": 4, "lane_columns": 3, "overview_columns": 4, "current_product_names": ["环晶电池", "低温藻"],
		"product_entries": [
			{"name": "环晶电池", "price": 92, "base_price": 70, "gap": 22, "trend": 8, "tier": "高价档", "supply": 2, "demand": 5, "disrupted": 1, "volatility": 4, "weather": "天气价格增速+18%（1区）", "status_tags": ["热门"], "path": "70→92", "heat_score": 100, "cold_score": -20},
			{"name": "低温藻", "price": 28, "base_price": 50, "gap": -22, "trend": -3, "tier": "低价档", "supply": 7, "demand": 1, "disrupted": 0, "volatility": 2, "weather": "无", "status_tags": ["供给压制"], "path": "50→28", "heat_score": -10, "cold_score": 120},
		],
		"city_entries": [{"name": "临港城", "owner_view": "己方", "intel_hint": "情报：已知", "income": 36, "last_income": 30, "gdp_trend": "GDP趋势：+6", "breakdown": "生产12+需求12+交通12", "weather_contributions": [{"weather_id": "ion_storm", "direction": "production", "multiplier": 1.20}], "status_tags": ["畅通"], "contract": "有效", "supplied": 1, "demand_count": 1, "disrupted": 0, "competition": 0, "flow": "畅通", "products": ["环晶电池"], "demands": ["低温藻"]}],
		"card_aftermath_entries": [{"resolved_time": 12.0, "style": "金融", "card": "轨道融资 I", "target": "临港城", "owner_known": false, "clue": "GDP上升", "tip_clue": "报价20"}],
		"city_clue_entries": [{"time": 14.0, "district": "临港区", "owner_visible": false, "kind": "市场", "clue_products": ["环晶电池"], "income": 36, "products": ["环晶电池"], "demands": ["低温藻"], "clue": "需求上升"}],
		"monster_clue_entries": [{"slot": 0, "name": "岩甲兽", "rank": 1, "owner_text": "归属未公开", "recent_loss": 5, "recent_damage": 10, "recent_source": "城市炮火", "recent_time": 18.0, "total_lost": 5, "cash_pool": 45, "cash_total": 50, "down": false, "clue": "受伤资金变化"}],
		"warehouse_entries": [{"name": "临港城", "owner_view": "业主未知", "intel_hint": "情报：无", "pressure": 7, "count": 2, "units": 4, "products": ["环晶电池"], "seconds_left": 18.0, "potential_income": 36, "latest_clue": "仓储公开"}],
		"player_cash_entries": [{"name": "测试玩家", "private": false, "eliminated": false, "score_label": "可见预估", "visible_score": 800, "visible_cash": 600, "city_count": 1, "intel_summary": "情报待结算", "last_cycle": 20, "role_income": 8, "gdp_per_minute": 240, "recent_delta": 12, "window_delta": 20, "path": "580→600", "ledger": "城市+20"}, {"name": "对手", "private": true, "eliminated": false}],
		"inference_lines": ["城市私标：临港城→玩家2", "公开卡牌归属：轨道融资待猜"],
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT: return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]): return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant): return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_discard"]: return true
			if _contains_private_key(value[key_variant]): return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant): return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("ECONOMY DASHBOARD PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("ECONOMY DASHBOARD PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("ECONOMY DASHBOARD PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)
