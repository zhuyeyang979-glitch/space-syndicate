extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/IntelDossierPublicSnapshotService.tscn"

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
	_expect(str(snapshot.get("summary_text", "")).contains("公共卡牌履历") and str(snapshot.get("summary_text", "")).contains("不奖励现金或GDP"), "summary explains read-only history without revealing truth")
	var board := snapshot.get("board", {}) as Dictionary
	_expect((board.get("kpis", []) as Array).size() == 4 and (board.get("clues", []) as Array).size() == 7, "board composes KPI and focused evidence lanes")
	var action_ids := _action_ids(board)
	_expect(action_ids.has("history_return_42") and action_ids.has("history_subscribe_42") and action_ids.has("history_suspect_42_1") and action_ids.has("history_clear_42") and action_ids.has("track_open_轨道融资1"), "focused history exposes only private annotation and detail intents")
	_expect(action_ids.has("intel_city_mark_3_1") and action_ids.has("intel_city_clear_3") and action_ids.has("intel_city_confidence_3_3") and action_ids.has("intel_city_reason_3_card"), "city inference controls use data-only action ids")
	_expect(action_ids.has("intel_open_region_3") and action_ids.has("intel_open_card_轨道融资1") and action_ids.has("intel_open_monster_2") and action_ids.has("intel_open_product_活体芯片") and action_ids.has("intel_open_economy"), "public evidence links use data-only action ids")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("service_ready", false)) and bool(debug.get("service_authoritative", false)) and not bool(debug.get("mutates_city_guesses", true)) and not bool(debug.get("settles_intel_cash", true)) and not bool(debug.get("reveals_city_owner_truth", true)) and not bool(debug.get("reads_private_hands", true)) and bool(debug.get("action_id_controls", false)), "service owns presentation and intents, not rules or private truth")
	_expect(_is_pure_data(snapshot) and not _contains_private_key(snapshot), "snapshot is viewer-safe pure data")
	var injected := _source()
	injected["hidden_owner"] = 7
	injected["private_hand"] = ["secret-card"]
	injected["ai_private_plan"] = "secret-route"
	var injected_snapshot: Dictionary = service.call("compose", injected)
	var encoded := JSON.stringify(injected_snapshot)
	_expect(not _contains_private_key(injected_snapshot) and not encoded.contains("secret-card") and not encoded.contains("secret-route"), "unknown private input is dropped")
	var empty_snapshot: Dictionary = service.call("compose", {"valid": false, "reason": "无玩家"})
	_expect(str(empty_snapshot.get("summary_text", "")).contains("无玩家") and ((empty_snapshot.get("board", {}) as Dictionary).get("links", []) as Array).size() == 1, "empty state remains safe and actionable")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true,
		"viewer_index": 0,
		"viewer_name": "测试玩家",
		"business_cycle_count": 3,
		"correct_guess_cash": 120,
		"wrong_guess_cost": 60,
		"city_final_value": 200,
		"stats": {"total_foreign": 2, "guessed": 1, "unmarked": 1, "best_cash": 120, "worst_cash": -60},
		"player_options": [{"player_index": 1, "label": "标玩家2"}, {"player_index": 2, "label": "标玩家3"}],
		"confidence_options": [{"value": 1, "label": "低"}, {"value": 2, "label": "中"}, {"value": 3, "label": "高"}],
		"reason_options": [{"id": "product", "label": "商品竞争"}, {"id": "card", "label": "卡牌条件"}],
		"city_entries": [{"district_index": 3, "name": "环城港", "guess": 1, "marked": true, "confidence": 2, "confidence_label": "中", "reason": "card", "reason_label": "卡牌条件", "priority": 88, "potential_income": 210, "warehouse_pressure": 24, "latest_clue": "活体芯片需求上升"}],
		"card_entries": [{"resolution_id": 42, "history_entry_id": "card-history:42", "card": "轨道融资1", "card_name": "轨道融资1", "track_state": "已结算", "status": "我的私人标注", "target": "环城港", "requirement": "公开履历只记录已经发生的动作和结果", "tip": "公开证据复盘", "aftermath": "GDP上升", "style": "经济", "time": 12.5, "revealed": false, "focused": true}],
		"monster_entries": [{"slot": 0, "name": "吞星兽", "catalog_index": 2, "owner_text": "归属未公开", "recent_loss": 30, "total_lost": 60, "cash_pool": 140, "cash_total": 200, "clue": "受伤资金线索"}],
		"warehouse_entries": [{"name": "环城港", "owner_view": "未知业主", "pressure": 24, "count": 1, "units": 3, "products": ["活体芯片"], "latest_clue": "匿名仓储3单位"}],
		"city_clue_entries": [{"district": "环城港", "kind": "需求", "clue_products": ["活体芯片"], "linked_product": "活体芯片", "owner_visible": false, "income": 80, "clue": "需求上升"}],
		"kpi_columns": 4,
		"clue_columns": 3,
		"control_columns": 1,
		"link_columns": 2,
	}


func _action_ids(board: Dictionary) -> Array:
	var ids := []
	for entry_variant in board.get("actions", []) as Array:
		ids.append(str((entry_variant as Dictionary).get("id", "")))
	for group_variant in board.get("control_groups", []) as Array:
		for entry_variant in (group_variant as Dictionary).get("actions", []) as Array:
			ids.append(str((entry_variant as Dictionary).get("id", "")))
	for entry_variant in board.get("links", []) as Array:
		ids.append(str((entry_variant as Dictionary).get("id", "")))
	return ids


func _contains_private_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if key.contains("hidden_owner") or key.contains("private_hand") or key.contains("private_plan") or key.contains("ai_private"):
				return true
			if _contains_private_key((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for item in value:
			if _contains_private_key(item):
				return true
	return false


func _is_pure_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_COLOR:
			return true
		TYPE_ARRAY:
			for item in value as Array:
				if not _is_pure_data(item): return false
			return true
		TYPE_DICTIONARY:
			for key_variant in (value as Dictionary).keys():
				if not _is_pure_data(key_variant) or not _is_pure_data((value as Dictionary)[key_variant]): return false
			return true
		_:
			return false


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		print("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("INTEL DOSSIER PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	push_error("Intel Dossier public snapshot service failures: %s" % "; ".join(failures))
	quit(1)
