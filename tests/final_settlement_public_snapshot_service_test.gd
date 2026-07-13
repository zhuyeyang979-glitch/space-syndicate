extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/FinalSettlementPublicSnapshotService.tscn"

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
	_expect(str(snapshot.get("summary_text", "")).contains("游戏结束") and str(snapshot.get("summary_text", "")).contains("赛后板"), "summary preserves the public postgame read order")
	var board := snapshot.get("board", {}) as Dictionary
	_expect((board.get("chips", []) as Array).size() == 3 and (board.get("kpis", []) as Array).size() == 4 and (board.get("money_sources", []) as Array).size() == 2 and (board.get("ranks", []) as Array).size() == 2 and (board.get("actions", []) as Array).size() == 3, "postgame board contract is complete")
	_expect(JSON.stringify(board).contains("测试玩家｜结算资金¥980") and JSON.stringify(board).contains("起手:基础¥500"), "supplied winner and money facts are rendered without recalculation")
	_expect(JSON.stringify(board).contains("关键城市") and JSON.stringify(board).contains("已结算3张匿名牌"), "map and public track events remain visible")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(not bool(debug.get("calculates_final_score", true)) and not bool(debug.get("sorts_final_rankings", true)) and not bool(debug.get("calculates_city_clearance", true)) and not bool(debug.get("calculates_intel_cash", true)) and not bool(debug.get("reads_private_hands", true)), "service owns no settlement rules")
	_expect(_is_pure_data(snapshot) and not _contains_private_key(snapshot), "snapshot is public pure data")
	var injected := source.duplicate(true)
	injected["private_hand"] = ["secret-card"]
	injected["ai_private_plan"] = "secret-route"
	var injected_snapshot: Dictionary = service.call("compose", injected)
	_expect(not _contains_private_key(injected_snapshot) and not JSON.stringify(injected_snapshot).contains("secret-card") and not JSON.stringify(injected_snapshot).contains("secret-route"), "unknown private input is never copied")
	var empty_snapshot: Dictionary = service.call("compose", {"valid": false, "reason": "无玩家"})
	_expect(str(empty_snapshot.get("summary_text", "")).contains("无玩家") and (((empty_snapshot.get("board", {}) as Dictionary).get("actions", []) as Array).size() == 3), "empty state remains actionable")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true, "reason": "终局倒计时结束", "winner_name": "测试玩家", "winner_score": 980,
		"cash_goal": 1200, "city_final_value": 100,
		"top_city_income_name": "测试玩家", "top_city_income_amount": 260,
		"top_card_income_name": "对手", "top_card_income_amount": 140,
		"top_role_income_name": "测试玩家", "top_role_income_amount": 90,
		"top_card_impact": "关键卡牌：轨道融资改变GDP", "monster_impact": "怪兽影响：岩甲兽破坏商路", "resolved_card_count": 3,
		"map_facts": {"active_city_count": 3, "destroyed_district_count": 1, "active_monster_count": 1, "monster_count": 2, "key_city": {"valid": true, "name": "关键城市", "owner_name": "测试玩家", "last_income": 88}},
		"money_source_entries": [
			{"rank": 0, "player_index": 0, "name": "测试玩家", "score": 980, "cash": 720, "base_start_cash": 500, "role_start_bonus": 20, "start_cash": 520, "city_income": 260, "card_income": 80, "role_income": 90, "card_spend": 120, "build_spend": 100, "business_spend": 40, "city_clearance": 200, "active_cities": 2, "gdp_per_minute": 180, "intel_cash": 60, "eliminated": false},
			{"rank": 1, "player_index": 1, "name": "对手", "score": 830, "cash": 630, "base_start_cash": 500, "role_start_bonus": 0, "start_cash": 500, "city_income": 180, "card_income": 140, "role_income": 40, "card_spend": 90, "build_spend": 100, "business_spend": 30, "city_clearance": 100, "active_cities": 1, "gdp_per_minute": 90, "intel_cash": 100, "eliminated": false},
		],
		"rank_entries": [
			{"player_index": 0, "name": "测试玩家", "score": 980, "cash": 720, "active_cities": 2, "gdp_per_minute": 180, "city_income": 260, "card_income": 80, "intel_cash": 60, "identity": "城市经营"},
			{"player_index": 1, "name": "对手", "score": 830, "cash": 630, "active_cities": 1, "gdp_per_minute": 90, "city_income": 180, "card_income": 140, "intel_cash": 100, "identity": "卡牌控制"},
		],
		"kpi_columns": 4, "money_columns": 2, "rank_columns": 2,
	}


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant: Variant in value:
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_hand", "private_discard"]:
				return true
			if _contains_private_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant: Variant in value:
			if _contains_private_key(item_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FINAL SETTLEMENT PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("FINAL SETTLEMENT PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("FINAL SETTLEMENT PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)
