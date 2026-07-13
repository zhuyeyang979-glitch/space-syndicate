extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/CodexPublicSnapshotService.tscn"

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
	var role_snapshot: Dictionary = service.call("compose_role", _role_source())
	_expect(str(role_snapshot.get("summary_text", "")).contains("星港金融团"), "role summary is composed")
	_expect(str(role_snapshot.get("economy_line", "")).contains("环晶电池区域购牌+1"), "role economy route is composed")
	_expect(str(role_snapshot.get("control_line", "")).contains("怪兽上限2"), "role control route is composed")
	var board: Dictionary = role_snapshot.get("board", {}) if role_snapshot.get("board", {}) is Dictionary else {}
	_expect((board.get("chips", []) as Array).size() >= 2 and (board.get("kpis", []) as Array).size() == 4 and (board.get("routes", []) as Array).size() == 6, "role board contract is stable")
	var region_snapshot: Dictionary = service.call("compose_region", _region_source())
	_expect(str(region_snapshot.get("summary_text", "")).contains("GDP趋势"), "region summary includes public GDP trend")
	var detail: Dictionary = region_snapshot.get("detail", {}) if region_snapshot.get("detail", {}) is Dictionary else {}
	_expect(str(detail.get("icon", "")) == "▣" and (detail.get("chips", []) as Array).size() == 6 and (detail.get("kpis", []) as Array).size() == 4 and (detail.get("clues", []) as Array).size() == 6, "region detail contract is stable")
	_expect(_is_pure_data(role_snapshot) and _is_pure_data(region_snapshot) and _is_pure_data(service.call("debug_snapshot")), "all service outputs are pure data")
	_expect(not _contains_private_key(role_snapshot) and not _contains_private_key(region_snapshot), "public snapshots exclude private owner and plan keys")
	service.queue_free()
	await process_frame
	_finish()


func _role_source() -> Dictionary:
	return {
		"role_card": {
			"name": "星港金融团", "species": "轨道商人", "trait": "融资网络", "flavor": "公开经营，隐藏收益。",
			"bonus_card_product": "环晶电池", "monster_control_limit_bonus": 1, "intel_card_trace_charges": 1,
		},
		"index": 0, "total": 8, "passive_text": "每轮第一次商品购牌获得折扣。", "starting_cash_delta": 50,
		"accent": Color("#38bdf8"), "kpi_columns": 4, "route_columns": 3,
		"face": {"name": "星港金融团", "effect": "测试", "type": "角色", "rank": "轨道商人"},
		"face_effect": "公开身份牌效果。",
	}


func _region_source() -> Dictionary:
	return {
		"valid": true, "index": 1, "total": 12, "name": "极光港", "terrain": "ice", "terrain_label": "冰原",
		"economic_focus_label": "工业", "destroyed": false, "selected": true, "hp_total": 12, "hp_now": 8, "panic": 2,
		"transport_speed": 1.15, "trade_route_load": 2, "card_count": 4, "city_present": true, "city_active": true,
		"city_level": 2, "city_last_income": 180, "supply_text": "环晶电池 ¥90", "demand_text": "深海菌毯 ¥120",
		"weather_text": "极光风暴", "connection_summary": "连接3区", "card_choice_summary": "轨道融资1、城市经营1",
		"monster_entries": [{"ordinal": 1, "name": "岩甲兽", "reason": "偏好仓储"}], "public_clue": "公开牌轨显示工业投资。",
		"card_names": ["轨道融资1", "城市经营1"], "route_flow_status": "稳定", "contract_status": "1份公开合约",
		"gdp_trend": "+20", "income_detail_lines": ["基础GDP 160", "商路加成 +20"], "products": ["环晶电池"],
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
			if str(key_variant).to_lower() in ["owner", "hidden_owner", "private_target", "private_discard", "private_plan", "ai_private_plan"]:
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
		push_error("CODEX PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("CODEX PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("CODEX PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)
