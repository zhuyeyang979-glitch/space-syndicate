extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/ProductCodexPublicSnapshotService.tscn"

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
	var snapshot: Dictionary = service.call("compose", _source())
	_expect(str(snapshot.get("summary_text", "")).contains("环晶电池"), "summary names the product")
	_expect(str(snapshot.get("summary_text", "")).contains("策略摘要"), "summary includes supplied strategy presentation")
	_expect(str(snapshot.get("preview_text", "")).contains("私人仓储和期货持仓保持隐藏"), "preview states the public market boundary")
	var browser_entry := snapshot.get("browser_entry", {}) as Dictionary
	_expect(int(browser_entry.get("catalog_index", -1)) == 2 and bool(browser_entry.get("selected", false)), "browser entry contract is stable")
	var detail := snapshot.get("detail", {}) as Dictionary
	_expect((detail.get("chips", []) as Array).size() == 6, "detail exposes six read-only public market chips")
	_expect((detail.get("kpis", []) as Array).size() == 4, "detail exposes four KPI cards")
	_expect((detail.get("strategies", []) as Array).size() == 6, "detail exposes six public strategy cards")
	var strategies := detail.get("strategies", []) as Array
	_expect(str((strategies[0] as Dictionary).get("tooltip", "")).contains("看涨"), "strategy copy is composed from supplied public rankings")
	_expect(str((strategies[1] as Dictionary).get("body", "")).contains("价格、供需、天气与运输聚合可见"), "public market policy excludes private positions")
	var debug_snapshot := service.call("debug_snapshot") as Dictionary
	_expect(not bool(debug_snapshot.get("calculates_market_price", true)), "service does not calculate market prices")
	_expect(not bool(debug_snapshot.get("calculates_strategy_scores", true)), "service does not calculate strategy scores")
	_expect(_is_pure_data(snapshot) and _is_pure_data(debug_snapshot), "service outputs are pure data")
	_expect(not _contains_private_key(snapshot), "public product snapshot excludes private keys")
	var invalid := service.call("compose", {"valid": false}) as Dictionary
	_expect((invalid.get("detail", {}) as Dictionary).is_empty(), "invalid input returns a safe empty detail")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true,
		"index": 2,
		"total": 12,
		"selected": true,
		"name": "环晶电池",
		"profile": {
			"category": "能源",
			"route": "高波动能源线",
			"terrain": "陆地",
			"use": "连接生产城、需求城和怪兽压力。",
			"hook": "追踪需求与断路形成的价格窗口。",
			"glyph": "◇",
			"accent": Color("#22c55e"),
			"secondary": Color("#f8fafc"),
		},
		"market": {
			"current_price": 92,
			"base_price": 70,
			"tier": "高价档",
			"trend_text": "+8",
			"price_path_text": "70→78→92",
			"supply": 2,
			"demand": 5,
			"volatility": 4,
			"weather_text": "太阳风令能源需求上升。",
		},
		"strategy_rankings": [
			{"label": "看涨", "score": 88, "hint": "需求和断路正在支撑价格。"},
			{"label": "囤货", "score": 63, "hint": "仓储公开但仍有收益窗口。"},
		],
		"monster_focus_names": ["岩甲兽", "电弧兽"],
		"related_card_names": ["商品看涨1", "港仓囤货1"],
		"supply_district_names": ["临港区"],
		"demand_district_names": ["首都圈"],
		"public_clue_lines": ["T+30s｜临港城｜业主未知｜需求上升"],
		"public_clue_labels": ["临港城/市场"],
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
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "cash"]:
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
		push_error("PRODUCT CODEX PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("PRODUCT CODEX PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("PRODUCT CODEX PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)
