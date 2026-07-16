extends SceneTree

const STRATEGY_SNAPSHOT := preload("res://scripts/viewmodels/player_board_strategy_action_snapshot.gd")
const ACTION_DOCK_SNAPSHOT := preload("res://scripts/viewmodels/action_dock_snapshot.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const QA_SAVE_PATH := "user://test_runs/player_board_strategy_action_port.save"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pure_public_contract()
	await _test_real_player_board_route()
	_finish()


func _test_pure_public_contract() -> void:
	var build_actions := STRATEGY_SNAPSHOT.compose({
		"primary": {
			"id": "strategy_build_gdp_source",
			"label": "建立GDP源",
			"state": "可建",
			"kind": "build_economic_source",
			"strategy_route": "grow_gdp",
			"consequence": "建立持续生产与GDP来源。",
			"suggested_action": "购买并打出I级城市设施牌。",
			"focus_target": "district_supply",
			"relevant_cost": "按当前公开报价",
			"relevant_requirement": "选择区域",
		},
		"has_economic_source": false,
	})
	_expect(build_actions.size() == 1 and str((build_actions[0] as Dictionary).get("kind", "")) == "build_economic_source", "no-source snapshot exposes one explicit GDP-source action")
	var normalized: Array = ACTION_DOCK_SNAPSHOT.new().apply_actions(build_actions).to_action_array()
	var action: Dictionary = normalized[0] if not normalized.is_empty() else {}
	_expect(str(action.get("id", "")) == "strategy_build_gdp_source" and str(action.get("strategy_route", "")) == "grow_gdp", "ActionDock preserves stable id and GDP strategy semantics")
	_expect(str(action.get("consequence", "")).contains("GDP") and str(action.get("focus_target", "")) == "district_supply", "ActionDock preserves consequence and focus target")

	var established := STRATEGY_SNAPSHOT.compose({
		"primary": {"id": "primary_summon_monster", "label": "可选：召唤怪兽", "kind": "summon_monster"},
		"has_economic_source": true,
		"expansion_available": true,
		"source_revision": 7,
	})
	var ids: Array[String] = []
	for entry_variant in established:
		ids.append(str((entry_variant as Dictionary).get("id", "")))
	_expect(ids.has("strategy_expand_gdp") and ids.has("strategy_protect_routes") and ids.has("strategy_pressure_competition"), "established source exposes GDP expansion, route defense, and competition pressure")
	var expansion := _find_action(established, "strategy_expand_gdp")
	_expect(str(expansion.get("kind", "")) == "expand_economic_source" and int(expansion.get("source_revision", 0)) == 7 and not bool(expansion.get("disabled", true)), "GDP expansion carries the owner revision and remains actionable while legal slots exist")
	_expect(STRATEGY_SNAPSHOT.compose({"primary": {"id": "unsafe", "label": "unsafe"}, "cash": 999999}).is_empty(), "private economy input fails closed before presentation")


func _test_real_player_board_route() -> void:
	var main := MAIN_SCENE.instantiate()
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var session := coordinator.get_node_or_null("GameSessionRuntimeController") if coordinator != null else null
	var save_coordinator := session.get_node_or_null("GameSaveRuntimeCoordinator") if session != null else null
	if save_coordinator != null and save_coordinator.has_method("set_qa_default_save_path_override"):
		save_coordinator.call("set_qa_default_save_path_override", QA_SAVE_PATH)
	root.add_child(main)
	await process_frame
	await process_frame
	main.set("configured_player_count", 4)
	main.set("configured_ai_player_count", 3)
	main.set("configured_role_indices", [0, 1, 2, 3])
	main.set("configured_starter_monster_indices", [0, 1, 2, 3])
	main.call("_confirm_start_new_run_from_setup")
	for _frame in range(8):
		await process_frame
	var playable_district := _first_playable_district(main)
	main.call("_select_district", playable_district)
	await process_frame
	var actions: Array = main.call("_runtime_snapshot_action_entries", 0)
	var build := _find_action(actions, "strategy_build_gdp_source")
	_expect(not build.is_empty() and str(build.get("kind", "")) == "build_economic_source", "real PlayerBoard prioritizes the owner-backed GDP source action")
	_expect(str(build.get("relevant_cost", "")) != "" and str(build.get("suggested_action", "")) != "", "real build action explains cost and next step")
	main.call("_sync_runtime_game_screen", true)
	var runtime_screen := main.get_node_or_null("RuntimeGameScreen")
	_expect(runtime_screen != null and runtime_screen.has_signal("action_requested"), "real GameScreen exposes the public PlayerBoard action signal")
	var ui: Dictionary = runtime_screen.get("current_ui_data") if runtime_screen != null and runtime_screen.get("current_ui_data") is Dictionary else {}
	var ui_player_board: Dictionary = ui.get("player_board", {}) if ui.get("player_board", {}) is Dictionary else {}
	var ui_build := _find_action(ui_player_board.get("actions", []) as Array, "strategy_build_gdp_source")
	_expect(str(ui_build.get("kind", "")) == "build_economic_source" and not str(ui_build.get("state", "")).is_empty(), "real GameScreen retains the action kind and readable state")
	runtime_screen.emit_signal("action_requested", "strategy_build_gdp_source")
	await process_frame
	var overlay: Control = main.get("district_supply_overlay") as Control
	_expect(overlay != null and overlay.visible, "stable PlayerBoard build action opens the real DistrictSupplyDrawer")
	var drawer_snapshot: Dictionary = overlay.call("debug_snapshot") if overlay != null and overlay.has_method("debug_snapshot") else {}
	var drawer_cards: Array = drawer_snapshot.get("cards", []) if drawer_snapshot.get("cards", []) is Array else []
	var first_drawer_card: Dictionary = drawer_cards[0] if not drawer_cards.is_empty() and drawer_cards[0] is Dictionary else {}
	var drawer_preview: Dictionary = drawer_snapshot.get("preview", {}) if drawer_snapshot.get("preview", {}) is Dictionary else {}
	_expect(str(first_drawer_card.get("kind", "")) == "facility_v06", "GDP action places the real facility card first instead of hiding it below the generic rack")
	_expect(str(drawer_preview.get("card_name", "")) == str(first_drawer_card.get("card_name", "")) and not str(drawer_preview.get("status_text", "")).is_empty() and not str(drawer_preview.get("buy_text", "")).is_empty(), "GDP action opens directly on the facility preview with an owner-backed purchase state")
	var facility_found := false
	var facility_purchase_state: Dictionary = {}
	for card_variant in drawer_cards:
		if card_variant is Dictionary and str((card_variant as Dictionary).get("kind", "")) == "facility_v06":
			facility_found = true
			facility_purchase_state = ((card_variant as Dictionary).get("purchase_state", {}) as Dictionary).duplicate(true)
	_expect(facility_found, "real drawer exposes the owner-backed v0.6 facility card for the GDP route")
	_expect(not facility_purchase_state.has("cash") and not facility_purchase_state.has("hand") and not facility_purchase_state.has("owner"), "drawer purchase state does not expose private economy or ownership fields")
	if save_coordinator != null and save_coordinator.has_method("clear_qa_default_save_path_override"):
		save_coordinator.call("clear_qa_default_save_path_override")
	main.queue_free()
	await process_frame


func _find_action(actions: Array, action_id: String) -> Dictionary:
	for action_variant in actions:
		if action_variant is Dictionary and str((action_variant as Dictionary).get("id", "")) == action_id:
			return (action_variant as Dictionary).duplicate(true)
	return {}


func _first_playable_district(main: Node) -> int:
	var districts: Array = main.get("districts") if main.get("districts") is Array else []
	for index in range(districts.size()):
		var district: Dictionary = districts[index] if districts[index] is Dictionary else {}
		if not bool(district.get("is_ocean", false)) and not str(district.get("region_id", "")).is_empty():
			return index
	return -1


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("PLAYER_BOARD_STRATEGY_ACTION_PORT_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("PLAYER_BOARD_STRATEGY_ACTION_PORT_TEST: %s" % failure)
	print("PLAYER_BOARD_STRATEGY_ACTION_PORT_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)
