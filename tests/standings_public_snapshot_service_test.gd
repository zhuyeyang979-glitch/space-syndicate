extends SceneTree

const SERVICE_SCENE := "res://scenes/runtime/StandingsPublicSnapshotService.tscn"
const SCOREBOARD_SCENE := "res://scenes/ui/StandingsScoreboard.tscn"
const RIVAL_CASH_SENTINEL_CENTS := 98765432100
const RIVAL_CASH_SENTINEL_TEXT := "987654321.00"
const ASSET_SENTINEL := "forbidden-economic-asset-sentinel"

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
	var scoreboard_packed := load(SCOREBOARD_SCENE) as PackedScene
	_expect(scoreboard_packed != null, "scoreboard scene loads for rendered privacy scanning")
	var rendered_scoreboard := scoreboard_packed.instantiate() if scoreboard_packed != null else null
	_expect(rendered_scoreboard != null, "scoreboard scene instantiates for rendered privacy scanning")
	if rendered_scoreboard != null:
		root.add_child(rendered_scoreboard)
		await process_frame
	var source := _source()
	var snapshot: Dictionary = service.call("compose", source)
	_expect(str(snapshot.get("summary_text", "")).contains("局势排名") and str(snapshot.get("summary_text", "")).contains("Top-N个人归属GDP") and str(snapshot.get("summary_text", "")).contains("120秒公开审计"), "summary preserves the v0.5 victory-control read order")
	_expect((snapshot.get("overview_cards", []) as Array).size() == 3, "three overview cards are composed")
	var scoreboard := snapshot.get("scoreboard", {}) as Dictionary
	_expect((scoreboard.get("chips", []) as Array).size() == 4 and (scoreboard.get("kpis", []) as Array).size() == 4 and (scoreboard.get("seats", []) as Array).size() == 3, "scoreboard contract is complete")
	var seats := scoreboard.get("seats", []) as Array
	_expect(str((seats[0] as Dictionary).get("score", "")) == "Top-N 145" and JSON.stringify(seats[0]).contains("现金¥610") and not JSON.stringify(seats[0]).contains("账本¥0.00"), "selected player keeps self-private progress and cash without public-audit markers")
	_expect(str((seats[1] as Dictionary).get("score", "")) == "进度隐藏" and not JSON.stringify(seats[1]).contains("73000"), "opponent progress and assets stay private outside the audit roster")
	_expect(str((seats[2] as Dictionary).get("rank", "")) == "出局" and JSON.stringify(seats[2]).contains("已淘汰"), "public elimination remains visible")
	var debug: Dictionary = service.call("debug_snapshot")
	_expect(bool(debug.get("consumes_victory_snapshot", false)) and not bool(debug.get("calculates_region_control", true)) and not bool(debug.get("calculates_top_n_gdp", true)) and not bool(debug.get("sorts_final_rankings", true)) and not bool(debug.get("evaluates_private_truth", true)), "service owns no VictoryControl rules")
	_expect(_is_pure_data(snapshot) and not _contains_private_key(snapshot), "snapshot is viewer-safe pure data")
	var injected := source.duplicate(true)
	injected["hidden_owner"] = 2
	injected["private_plan"] = "secret-rival-plan"
	var injected_snapshot: Dictionary = service.call("compose", injected)
	_expect(not _contains_private_key(injected_snapshot) and not JSON.stringify(injected_snapshot).contains("secret-rival-plan"), "unknown private input is never copied")
	var empty_snapshot: Dictionary = service.call("compose", {"valid": false})
	_expect(str(empty_snapshot.get("summary_text", "")).contains("还没有可用玩家数据") and (empty_snapshot.get("overview_cards", []) as Array).size() == 1, "empty state is safe and actionable")

	var authorized := _authorized_opponent_source()
	var authorized_snapshot: Dictionary = service.call("compose", authorized)
	var authorized_text := JSON.stringify(authorized_snapshot)
	_expect(authorized_text.contains(RIVAL_CASH_SENTINEL_TEXT), "all authoritative markers expose the audited rival cash exactly once")
	_expect(not authorized_text.contains(ASSET_SENTINEL), "economic_assets are ignored even on an authorized cash row")

	var negative_cases: Array[Dictionary] = []
	var missing_top_level := authorized.duplicate(true)
	(missing_top_level.get("victory_control", {}) as Dictionary).erase("cash_visibility")
	negative_cases.append({"name": "missing top-level cash visibility", "source": missing_top_level})
	var missing_revealed := authorized.duplicate(true)
	(missing_revealed.get("victory_control", {}) as Dictionary).erase("audit_revealed_player_indices")
	negative_cases.append({"name": "missing revealed-player allowlist", "source": missing_revealed})
	var wrong_player := authorized.duplicate(true)
	(wrong_player.get("victory_control", {}) as Dictionary)["audit_revealed_player_indices"] = [0]
	negative_cases.append({"name": "wrong player allowlist", "source": wrong_player})
	var missing_row_marker := authorized.duplicate(true)
	(((missing_row_marker.get("victory_control", {}) as Dictionary).get("audit_entries", []) as Array)[0] as Dictionary).erase("cash_visibility")
	negative_cases.append({"name": "missing row cash visibility", "source": missing_row_marker})
	var non_integer_cash := authorized.duplicate(true)
	(((non_integer_cash.get("victory_control", {}) as Dictionary).get("audit_entries", []) as Array)[0] as Dictionary)["cash_ledger_cents"] = str(RIVAL_CASH_SENTINEL_CENTS)
	negative_cases.append({"name": "non-integer audit cash", "source": non_integer_cash})
	var duplicate_conflict := authorized.duplicate(true)
	var conflicting_row := (((duplicate_conflict.get("victory_control", {}) as Dictionary).get("audit_entries", []) as Array)[0] as Dictionary).duplicate(true)
	conflicting_row["cash_ledger_cents"] = RIVAL_CASH_SENTINEL_CENTS + 1
	((duplicate_conflict.get("victory_control", {}) as Dictionary).get("audit_entries", []) as Array).append(conflicting_row)
	negative_cases.append({"name": "conflicting duplicate audit rows", "source": duplicate_conflict})
	var terminal_non_authority := _markerless_opponent_source()
	terminal_non_authority["game_over"] = true
	var terminal_victory := terminal_non_authority.get("victory_control", {}) as Dictionary
	terminal_victory["state"] = "resolved"
	terminal_victory["outcome_receipt"] = {"winner_player_indices": [1], "cash_ledger_cents": RIVAL_CASH_SENTINEL_CENTS}
	negative_cases.append({"name": "game over and winner status are not cash authority", "source": terminal_non_authority})
	negative_cases.append({"name": "markerless economic assets are ignored", "source": _markerless_opponent_source()})

	for case_variant in negative_cases:
		var case_data := case_variant as Dictionary
		var case_snapshot: Dictionary = service.call("compose", case_data.get("source", {}) as Dictionary)
		var serialized := JSON.stringify(case_snapshot)
		var case_name := str(case_data.get("name", "privacy case"))
		_expect(not serialized.contains(RIVAL_CASH_SENTINEL_TEXT) and not serialized.contains(str(RIVAL_CASH_SENTINEL_CENTS)) and not serialized.contains("账本¥0.00") and not serialized.contains(ASSET_SENTINEL), "%s fails closed in serialized standings" % case_name)
		if rendered_scoreboard != null:
			rendered_scoreboard.call("set_scoreboard", case_snapshot.get("scoreboard", {}) as Dictionary)
			await process_frame
			var rendered_text := _rendered_text_and_tooltips(rendered_scoreboard)
			_expect(not rendered_text.contains(RIVAL_CASH_SENTINEL_TEXT) and not rendered_text.contains(str(RIVAL_CASH_SENTINEL_CENTS)) and not rendered_text.contains("账本¥0.00") and not rendered_text.contains(ASSET_SENTINEL), "%s fails closed in rendered text and tooltips" % case_name)
	if rendered_scoreboard != null:
		rendered_scoreboard.queue_free()
	service.queue_free()
	await process_frame
	_finish()


func _source() -> Dictionary:
	return {
		"valid": true,
		"game_over": false,
		"selected_available": true,
		"selected_top_n_gdp_per_minute": 145,
		"selected_controlled_region_count": 4,
		"selected_cash": 610,
		"selected_city_count": 2,
		"selected_gdp_per_minute": 145,
		"selected_intel_summary": "情报待结算",
		"required_top_n_gdp_per_minute": 130,
		"required_controlled_region_count": 4,
		"victory_control": {"state": "audit", "audit_remaining_seconds": 90.0, "audit_roster": [0], "audit_entries": [{"player_index": 0, "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "cash_ledger_cents": 61000}]},
		"countdown_text": "公开审计剩余90.0秒",
		"public_shift_count": 5,
		"overview_columns": 3,
		"kpi_columns": 4,
		"seat_columns": 3,
		"seat_entries": [
			{"player_index": 0, "name": "测试玩家", "eliminated": false, "can_view_private": true, "cash": 610, "active_cities": 2, "top_n_gdp_per_minute": 145, "controlled_region_count": 4, "intel_summary": "情报待结算", "gdp_per_minute": 180},
			{"player_index": 1, "name": "对手", "eliminated": false, "can_view_private": false},
			{"player_index": 2, "name": "破产席位", "eliminated": true, "can_view_private": false},
		],
		"final_summary_text": "",
	}


func _authorized_opponent_source() -> Dictionary:
	var source := _source()
	var victory := source.get("victory_control", {}) as Dictionary
	victory["cash_visibility"] = "public_audit"
	victory["audit_revealed_player_indices"] = [1]
	victory["audit_roster"] = [1]
	victory["audit_entries"] = [{
		"player_index": 1,
		"cash_visibility": "public_audit",
		"top_n_gdp_per_minute": 122,
		"controlled_region_count": 3,
		"cash_ledger_cents": RIVAL_CASH_SENTINEL_CENTS,
		"economic_assets": {"project_positions": [ASSET_SENTINEL], "contracts": [ASSET_SENTINEL]},
	}]
	return source


func _markerless_opponent_source() -> Dictionary:
	var source := _source()
	var victory := source.get("victory_control", {}) as Dictionary
	victory["audit_roster"] = [1]
	victory["audit_entries"] = [{
		"player_index": 1,
		"top_n_gdp_per_minute": 122,
		"controlled_region_count": 3,
		"cash_ledger_cents": RIVAL_CASH_SENTINEL_CENTS,
		"economic_assets": {"project_positions": [ASSET_SENTINEL], "warehouses": [ASSET_SENTINEL]},
	}]
	return source


func _rendered_text_and_tooltips(node: Node) -> String:
	var values: Array[String] = []
	if node is Label:
		values.append((node as Label).text)
	elif node is RichTextLabel:
		values.append((node as RichTextLabel).text)
	elif node is Button:
		values.append((node as Button).text)
	if node is Control:
		values.append((node as Control).tooltip_text)
	for child in node.get_children():
		if child is Node:
			values.append(_rendered_text_and_tooltips(child as Node))
	return "\n".join(values)


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
			if str(key_variant).to_lower() in ["owner", "owner_index", "hidden_owner", "private_target", "private_plan", "ai_private_plan", "hand", "private_discard", "economic_assets"]:
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
