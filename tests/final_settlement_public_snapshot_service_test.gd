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
	_expect(str(snapshot.get("summary_text", "")).contains("游戏结束") and str(snapshot.get("summary_text", "")).contains("胜者：测试玩家") and str(snapshot.get("summary_text", "")).contains("Top-K个人归属GDP"), "summary preserves the outcome-receipt read order")
	var board := snapshot.get("board", {}) as Dictionary
	_expect((board.get("chips", []) as Array).size() == 3 and (board.get("kpis", []) as Array).size() == 4 and (board.get("money_sources", []) as Array).size() == 2 and (board.get("ranks", []) as Array).size() == 2 and (board.get("actions", []) as Array).size() == 3, "postgame board contract is complete")
	var board_text := JSON.stringify(board)
	_expect(board_text.contains("Top-K归属GDP 145/min") and board_text.contains("现金为最终并列判定项，数值保密") and not board_text.contains("610.00") and not board_text.contains("730.00"), "VictoryControl order and public comparisons render without exposing exact cash")
	_expect(JSON.stringify(board).contains("存活城市3座") and JSON.stringify(board).contains("已结算3张匿名牌"), "map and public track events remain visible")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("consumes_outcome_receipt", false)) and not bool(debug.get("calculates_final_score", true)) and not bool(debug.get("sorts_final_rankings", true)) and not bool(debug.get("calculates_city_clearance", true)) and not bool(debug.get("calculates_intel_cash", true)) and bool(debug.get("protects_private_cash", false)) and bool(debug.get("recursively_sanitizes_public_output", false)) and str(debug.get("cash_visibility_policy", "")) == "authoritative_public_audit_allowlist" and bool(debug.get("cash_disclosure_fail_closed", false)) and not bool(debug.get("reads_private_hands", true)), "service consumes a receipt, owns no settlement rules, and enforces the state-aware cash boundary")
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
		"valid": true, "reason": "公开审计完成", "winner_names": ["测试玩家"], "co_victory": false,
		"required_top_n_gdp_per_minute": 130, "required_controlled_region_count": 4,
		"outcome_receipt": {"outcome_id": "victory.v05.fixture.1", "reason_code": "public_audit_complete", "winner_player_indices": [0], "co_victory": false, "comparison_order": ["top_n_gdp_per_minute", "controlled_region_count", "cash_ledger_cents"]},
		"top_city_income_name": "测试玩家", "top_city_income_amount": 260,
		"top_card_income_name": "对手", "top_card_income_amount": 140,
		"top_role_income_name": "测试玩家", "top_role_income_amount": 90,
		"top_card_impact": "关键卡牌：轨道融资改变GDP", "monster_impact": "怪兽影响：岩甲兽破坏商路", "resolved_card_count": 3,
		"map_facts": {"active_city_count": 3, "destroyed_district_count": 1, "active_monster_count": 1, "monster_count": 2, "key_city": {"valid": true, "name": "关键城市", "owner_name": "测试玩家", "last_income": 88}},
		"money_source_entries": [
			{"rank": 0, "player_index": 0, "name": "测试玩家", "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "cash_ledger_cents": 61000, "winner": true, "cash": 610, "city_income": 260, "card_income": 80, "role_income": 90, "gdp_per_minute": 180, "eliminated": false},
			{"rank": 1, "player_index": 1, "name": "对手", "top_n_gdp_per_minute": 120, "controlled_region_count": 3, "cash_ledger_cents": 73000, "winner": false, "cash": 730, "city_income": 180, "card_income": 140, "role_income": 40, "gdp_per_minute": 150, "eliminated": false},
		],
		"rank_entries": [
			{"player_index": 0, "name": "测试玩家", "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "cash_ledger_cents": 61000, "winner": true, "cash": 610, "gdp_per_minute": 180, "identity": "城市经营"},
			{"player_index": 1, "name": "对手", "top_n_gdp_per_minute": 120, "controlled_region_count": 3, "cash_ledger_cents": 73000, "winner": false, "cash": 730, "gdp_per_minute": 150, "identity": "卡牌控制"},
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
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_hand", "private_discard", "cash", "cash_cents", "cash_ledger_cents", "available", "available_cents", "escrow", "escrow_cents"]:
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
