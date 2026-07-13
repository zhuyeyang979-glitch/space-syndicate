extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/StandingsPublicSnapshotService.tscn"

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
	_expect(str(snapshot.get("summary_text", "")).contains("局势排名") and str(snapshot.get("summary_text", "")).contains("预估结算资金"), "summary preserves the public standings read order")
	_expect((snapshot.get("overview_cards", []) as Array).size() == 3, "three overview cards are composed")
	var scoreboard := snapshot.get("scoreboard", {}) as Dictionary
	_expect((scoreboard.get("chips", []) as Array).size() == 4 and (scoreboard.get("kpis", []) as Array).size() == 4 and (scoreboard.get("seats", []) as Array).size() == 3, "scoreboard contract is complete")
	var seats := scoreboard.get("seats", []) as Array
	_expect(str((seats[0] as Dictionary).get("score", "")) == "¥860", "selected player receives the supplied visible score")
	_expect(str((seats[1] as Dictionary).get("score", "")) == "资金隐私" and not JSON.stringify(seats[1]).contains("730"), "opponent cash and score stay private")
	_expect(str((seats[2] as Dictionary).get("score", "")) == "出局" and JSON.stringify(seats[2]).contains("破产出局"), "public bankruptcy remains visible")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(not bool(debug.get("calculates_settlement_score", true)) and not bool(debug.get("calculates_city_income", true)) and not bool(debug.get("sorts_final_rankings", true)) and not bool(debug.get("evaluates_private_truth", true)), "service owns no scoring or economy rules")
	_expect(_is_pure_data(snapshot) and not _contains_private_key(snapshot), "snapshot is viewer-safe pure data")
	var injected := source.duplicate(true)
	injected["hidden_owner"] = 2
	injected["private_plan"] = "secret-rival-plan"
	var injected_snapshot: Dictionary = service.call("compose", injected)
	_expect(not _contains_private_key(injected_snapshot) and not JSON.stringify(injected_snapshot).contains("secret-rival-plan"), "unknown private input is never copied")
	var empty_snapshot: Dictionary = service.call("compose", {"valid": false})
	_expect(str(empty_snapshot.get("summary_text", "")).contains("还没有可用玩家数据") and (empty_snapshot.get("overview_cards", []) as Array).size() == 1, "empty state is safe and actionable")
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true,
		"game_over": false,
		"selected_available": true,
		"selected_score": 860,
		"selected_cash": 610,
		"selected_city_count": 2,
		"selected_gdp_per_minute": 145,
		"selected_intel_summary": "情报待结算",
		"cash_goal": 1200,
		"city_final_value": 100,
		"intel_correct_reward": 120,
		"intel_wrong_cost": 40,
		"countdown_text": "距离终局沙漏还差¥340",
		"public_shift_count": 5,
		"overview_columns": 3,
		"kpi_columns": 4,
		"seat_columns": 3,
		"seat_entries": [
			{"player_index": 0, "name": "测试玩家", "eliminated": false, "can_view_private": true, "cash": 610, "active_cities": 2, "score": 860, "score_label": "可见预估", "intel_summary": "情报待结算", "gdp_per_minute": 145},
			{"player_index": 1, "name": "对手", "eliminated": false, "can_view_private": false},
			{"player_index": 2, "name": "破产席位", "eliminated": true, "can_view_private": false},
		],
		"final_summary_text": "",
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
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_discard"]:
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
		push_error("STANDINGS PUBLIC SNAPSHOT SERVICE: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("STANDINGS PUBLIC SNAPSHOT SERVICE PASS")
		quit(0)
		return
	print("STANDINGS PUBLIC SNAPSHOT SERVICE FAIL: %d" % failures.size())
	quit(1)
