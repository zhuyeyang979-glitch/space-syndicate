extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const OPTIONAL_SUMMON_FOCUSED_ARG := "--first-table-optional-summon-only"
const STAGE_ARG_PREFIX := "--commercial-stage="
const QA_SAVE_PATH := "user://test_runs/commercial_playability_gate.save"
const FIXED_SEED := 60623
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1600, 960),
	Vector2i(1920, 1080),
]
const STAGE_IDS := [
	"documentation",
	"layout_1280",
	"layout_1600",
	"layout_1920",
	"cta_open_rack",
	"cta_buy_recovery",
	"optional_summon",
	"action_chain",
]

const FORBIDDEN_PLAYER_FACING_TOKENS := [
	"ai_reason",
	"ai_utility_score",
	"route_plan_score",
	"pressure bucket",
	"decision_samples",
	"learning_bonus",
	"true_owner",
	"hidden_owner",
	"owner_truth",
	"opponent cash",
	"opponent hand",
	"rival exact hand",
	"private route plan",
	"ai private plan",
	"ai 私有计划",
	"对手现金",
	"对手手牌",
	"开发原则",
	"测试阶段优先",
	"prototype",
	"debug",
]

var _failures: Array[String] = []
var _active_stage_id := ""
var _active_stage_started_msec := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var requested_stage := _requested_stage_id()
	if _command_line_has(OPTIONAL_SUMMON_FOCUSED_ARG):
		requested_stage = "optional_summon"
	if not requested_stage.is_empty():
		if not STAGE_IDS.has(requested_stage):
			_expect(false, "commercial gate stage is known: %s" % requested_stage)
		else:
			await _run_stage(requested_stage)
		_finish()
		return
	for stage_id_variant in STAGE_IDS:
		await _run_stage(str(stage_id_variant))
	_finish()


func _run_stage(stage_id: String) -> void:
	_active_stage_id = stage_id
	_active_stage_started_msec = Time.get_ticks_msec()
	print("COMMERCIAL_GATE_STAGE_START|stage=%s" % stage_id)
	match stage_id:
		"documentation":
			_check_gate_documentation()
		"layout_1280":
			await _check_first_table_runtime_layout(Vector2i(1280, 720))
		"layout_1600":
			await _check_first_table_runtime_layout(Vector2i(1600, 960))
		"layout_1920":
			await _check_first_table_runtime_layout(Vector2i(1920, 1080))
		"cta_open_rack":
			await _check_first_run_open_rack_recovery()
		"cta_buy_recovery":
			await _check_first_run_buy_recovery()
		"optional_summon":
			await _check_first_table_optional_summon_after_economy()
		"action_chain":
			await _check_first_ten_minute_action_chain()
	print("COMMERCIAL_GATE_STAGE_END|stage=%s|duration_ms=%d|failures=%d" % [
		stage_id,
		Time.get_ticks_msec() - _active_stage_started_msec,
		_failures.size(),
	])
	_active_stage_id = ""
	_active_stage_started_msec = 0


func _requested_stage_id() -> String:
	for argument in _all_command_line_arguments():
		var text := str(argument)
		if text.begins_with(STAGE_ARG_PREFIX):
			return text.substr(STAGE_ARG_PREFIX.length()).strip_edges()
	return ""


func _command_line_has(expected: String) -> bool:
	return _all_command_line_arguments().has(expected)


func _all_command_line_arguments() -> Array[String]:
	var result: Array[String] = []
	for argument in OS.get_cmdline_args():
		var text := str(argument)
		if not result.has(text):
			result.append(text)
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if not result.has(text):
			result.append(text)
	return result


func _check_gate_documentation() -> void:
	_expect(FileAccess.file_exists("res://docs/commercial_playability_gate.md"), "commercial playability gate document exists")
	var source := FileAccess.get_file_as_string("res://docs/commercial_playability_gate.md")
	for marker in ["真人首局", "真实 RuntimeGameScreen", "单主 CTA", "隐藏信息", "1280×720"]:
		_expect(source.contains(marker), "commercial gate document explains %s" % marker)
	var transient_source := FileAccess.get_file_as_string("res://tests/transient_gameplay_windows_v06_test.gd")
	_expect(
		transient_source.contains("public_bid") and transient_source.contains("竞价"),
		"transient gameplay gate, not the base focus order, owns public-bid visibility",
	)


func _check_first_table_runtime_layout(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_campaign_chapter", "01_first_table")
	await _wait_frames(16)
	_select_recommended_district(main)
	await _wait_frames(8)
	var runtime := main.find_child("RuntimeGameScreen", true, false) as Control
	_expect(runtime != null and runtime.visible, "%s first-table chapter enters real RuntimeGameScreen" % _size_label(viewport_size))
	if runtime != null:
		_check_core_table_regions(main, runtime, viewport_size)
		_check_runtime_focus_order(runtime, ["顶部状态", "牌轨", "星球地图", "右侧详情", "手牌", "当前行动"], "%s closed-rack table" % _size_label(viewport_size))
		_check_single_primary_campaign_cta(main, viewport_size)
		_check_player_facing_privacy(runtime, viewport_size)
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_first_table_optional_summon_after_economy() -> void:
	root.size = Vector2i(1600, 960)
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(12)
	main.set_process(false)
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	var monster_owner: Object = coordinator.call("monster_runtime_controller") if coordinator != null and coordinator.has_method("monster_runtime_controller") else null
	_expect(coordinator != null and monster_owner != null, "optional-summon gate composes current Coordinator and Monster owner")
	if coordinator == null or monster_owner == null:
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return

	var players: Array = main.get("players") as Array
	var actor_id := _actor_id(players, 0)
	var district := int(main.call("_first_run_recommended_start_district", 0))
	if district >= 0:
		main.call("_select_district", district)
		main.call("_open_district_supply_from_map", district)
	await _wait_frames(3)
	var monster_before: Dictionary = monster_owner.call("unit_card_snapshot_v06", "monster")
	var monster_save_before: Dictionary = monster_owner.call("to_save_data")
	var journal_before: Dictionary = monster_save_before.get("monster_card_atomic_terminal_journal", {}) if monster_save_before.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}
	var choice := _find_purchasable_region_supply_choice(main, coordinator)
	_expect(not choice.is_empty(), "first_table finds one current stable public RegionSupply listing before any summon")
	if choice.is_empty():
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	var listing: Dictionary = choice.get("listing", {}) if choice.get("listing", {}) is Dictionary else {}
	var purchase_district := int(choice.get("district_index", -1))
	var card_id := str(listing.get("card_id", ""))
	_expect(
		_is_stable_v06_card_id(card_id)
			and not (coordinator.call("v06_card_definition", card_id) as Dictionary).is_empty(),
		"the pre-summon listing is a current stable v0.6 card, not a side-market teaching card",
	)
	var player_before_purchase: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var inventory_before := JSON.stringify(player_before_purchase.get("inventory", {}))
	var purchased := bool(main.call(
		"_buy_card_for_player_from_district",
		0,
		purchase_district,
		card_id,
		false,
		true,
		-1,
		"",
	))
	var player_after_purchase: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	_expect(
		purchased
			and int(player_after_purchase.get("card_purchase_count", -1))
				== int(player_before_purchase.get("card_purchase_count", 0)) + 1,
		"first_table purchases one current stable RegionSupply card before any summon",
	)
	_expect(
		JSON.stringify(player_after_purchase.get("inventory", {})) != inventory_before,
		"the pre-summon purchase mutates the single production inventory owner",
	)
	var monster_after_economy: Dictionary = monster_owner.call("unit_card_snapshot_v06", "monster")
	_expect(int(monster_after_economy.get("monster_count", -1)) == int(monster_before.get("monster_count", -1)), "regional card purchase does not implicitly summon the held starter")

	main.call("_open_economy_overview_menu")
	await _wait_frames(3)
	var economy_title := main.find_child("MenuTitleLabel", true, false) as Label
	_expect(economy_title != null and economy_title.text == "经济总览", "economy review remains available after a regional purchase and before the optional summon")
	main.call("_close_menu")
	await _wait_frames(2)

	var starter_slot := int(main.call("_first_starter_monster_slot", players[0])) if not players.is_empty() and players[0] is Dictionary else -1
	var summon_submitted := starter_slot >= 0 and bool(main.call("_queue_skill_resolution", 0, starter_slot, -1))
	await _drain_card_resolution(main, 240)
	var monster_after: Dictionary = monster_owner.call("unit_card_snapshot_v06", "monster")
	var monster_save_after: Dictionary = monster_owner.call("to_save_data")
	var journal_after: Dictionary = monster_save_after.get("monster_card_atomic_terminal_journal", {}) if monster_save_after.get("monster_card_atomic_terminal_journal", {}) is Dictionary else {}
	var new_transactions := _new_dictionary_keys(journal_before, journal_after)
	var summon_finalized := new_transactions.size() == 1 and _monster_terminal_finalized(journal_after, str(new_transactions[0]))
	_expect(summon_submitted, "first_table can voluntarily submit the held starter after facility and economy actions")
	_expect(int(monster_after.get("monster_count", -1)) == int(monster_before.get("monster_count", -1)) + 1 and summon_finalized, "later voluntary summon finalizes exactly once in the current Monster owner")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_first_ten_minute_action_chain() -> void:
	root.size = Vector2i(1600, 960)
	var main := await _instantiate_main()
	if main == null:
		return
	_stage_checkpoint("main_ready")
	main.set("card_resolution_force_duration", 0.05)
	main.set("card_resolution_force_simultaneous_window", 0.0)
	for timer_name in ["monster_timer", "special_monster_timer"]:
		main.set(timer_name, 3600.0)
	var market_controller := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/ProductMarketRuntimeController")
	if market_controller != null:
		var market_state: Dictionary = market_controller.call("to_save_data")
		market_state["market_timer"] = 3600.0
		market_controller.call("apply_save_data", market_state)
	main.call("_start_scenario_from_menu", "first_table")
	await _wait_frames(16)
	_stage_checkpoint("scenario_started")
	_expect(str(_runtime_scenario_state(main).get("active_scenario_id", "")) == "first_table", "first ten-minute path starts the authored first_table scenario")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_select_district")), "first ten-minute path selects the recommended district from coach")
	await _wait_frames(4)
	var progress_before_purchase: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(not bool(progress_before_purchase.get("has_monster", false)), "first ten-minute path keeps the held starter unsummoned before facility purchase")
	_expect(bool(main.call("_first_run_should_defer_monster_wager")), "first_table defers monster wager freezes while the authored mission is active")
	_expect(str(main.call("_first_run_coach_stage", progress_before_purchase)) == "open_rack", "first_table moves from district selection directly to the real district rack without requiring a summon")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_open_rack")), "first ten-minute path can open district card rack while the starter remains unsummoned")
	await _wait_frames(8)
	var runtime := main.find_child("RuntimeGameScreen", true, false) as Control
	var ui_text := _node_text(runtime)
	_expect(ui_text.contains("牌架") and ui_text.contains("手牌"), "first ten-minute path keeps card rack and hand concepts visible together")
	_check_runtime_focus_order(runtime, ["顶部状态", "牌轨", "星球地图", "右侧详情", "区域牌架", "手牌", "当前行动"], "first ten-minute opened-rack table")
	var purchase_count_before := _local_card_purchase_count(main)
	var first_purchase_requested := bool(main.call("_activate_first_run_coach_action", "coach_buy_card"))
	_expect(first_purchase_requested, "first ten-minute path buys a real current public regional card from coach")
	if not first_purchase_requested:
		_stage_checkpoint("coach_buy_card_rejected")
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	await _wait_for_local_card_purchase(main, purchase_count_before)
	_stage_checkpoint("first_purchase_wait_complete")
	var progress_after_buy: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(_local_card_purchase_count(main) > purchase_count_before, "first ten-minute path records a real regional card purchase")
	_expect(bool(progress_after_buy.get("has_bought_card", false)), "first ten-minute path marks first purchase only after the development card enters hand")
	_expect(int(main.call("_first_actionable_hand_slot", 0)) >= 0, "first ten-minute purchase leaves a currently actionable public-rack card")
	var first_play_requested := bool(
		main.call("_activate_first_run_coach_action", "coach_play_card")
	)
	if not first_play_requested:
		var first_slot := int(main.call("_first_actionable_hand_slot", 0))
		var players_variant: Variant = main.get("players")
		var local_player: Dictionary = (
			players_variant[0]
			if players_variant is Array
				and not (players_variant as Array).is_empty()
				and players_variant[0] is Dictionary
			else {}
		)
		var local_slots: Array = (
			local_player.get("slots", []) as Array
			if local_player.get("slots", []) is Array
			else []
		)
		var first_card: Dictionary = (
			(local_slots[first_slot] as Dictionary).duplicate(true)
			if first_slot >= 0
				and first_slot < local_slots.size()
				and local_slots[first_slot] is Dictionary
			else {}
		)
		print(
			"COMMERCIAL_GATE_FIRST_PLAY_DIAG|selected=%d|slot=%d|card=%s|logs=%s"
			% [
				int(main.get("selected_district")),
				first_slot,
				JSON.stringify(first_card),
				JSON.stringify(main.get("log_lines")),
			]
		)
	_expect(first_play_requested, "first ten-minute path submits the purchased economic card through the existing card action")
	if not first_play_requested:
		_stage_checkpoint("coach_play_card_rejected")
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	var facility_resolved := await _wait_for_first_table_facility(main)
	_stage_checkpoint("first_project_wait_complete")
	await _drain_card_resolution(main)
	var progress_after_play: Dictionary = main.call("_first_run_coach_progress", 0)
	var facility_content: Dictionary = main.call("_first_table_runtime_content_snapshot", 0)
	var owned_facilities: Array = facility_content.get("owned_facilities", []) if facility_content.get("owned_facilities", []) is Array else []
	_expect(bool(progress_after_play.get("has_played_card", false)), "first ten-minute path marks the real development card play")
	_expect(facility_resolved and bool(facility_content.get("city_present", false)) and not owned_facilities.is_empty(), "first ten-minute path creates a real public facility owned by the local player")
	_expect(str(main.call("_first_run_coach_stage", progress_after_play)) == "check_economy", "first_table reaches economy review only after facility resolution")
	if market_controller != null:
		market_controller.call("market_tick")
	if main.has_method("_settle_city_cashflow_seconds"):
		main.call("_settle_city_cashflow_seconds", 120.0)
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_check_economy")), "first ten-minute path can open economy overview from coach")
	await _wait_frames(8)
	var progress_after_economy: Dictionary = main.call("_first_run_coach_progress", 0)
	var economy_title := main.find_child("MenuTitleLabel", true, false) as Label
	_expect(bool(progress_after_economy.get("has_checked_economy", false)), "first ten-minute path records economy overview inspection")
	_expect(economy_title != null and economy_title.text == "经济总览", "first ten-minute path opens the economy overview dashboard")
	facility_content = main.call("_first_table_runtime_content_snapshot", 0)
	_expect(facility_content.has("gdp_per_minute") and facility_content.has("cashflow_paid_total") and int(facility_content.get("gdp_per_minute", -1)) >= 0 and int(facility_content.get("cashflow_paid_total", -1)) >= 0, "first ten-minute economic review reports current GDP and cashflow even when the first random facility has not produced income yet")
	_expect(str(main.call("_first_run_coach_stage", progress_after_economy)) == "buy_followup", "first ten-minute path moves from first facility feedback to a second current-rack purchase")
	if main.has_method("_close_menu"):
		main.call("_close_menu")
	await _wait_frames(4)
	var followup_purchase_before := _local_card_purchase_count(main)
	var followup_purchase_requested := bool(main.call("_activate_first_run_coach_action", "coach_buy_card"))
	_expect(followup_purchase_requested, "first ten-minute path can buy a second currently public regional listing")
	if not followup_purchase_requested:
		_stage_checkpoint("followup_coach_buy_card_rejected")
		root.remove_child(main)
		main.queue_free()
		await _wait_frames(1)
		return
	await _wait_for_local_card_purchase(main, followup_purchase_before)
	_stage_checkpoint("followup_purchase_wait_complete")
	_expect(await _wait_for_scenario_signal(main, "followup_card_bought"), "first ten-minute path records a successful local-human second purchase without checking a fixed card name")
	_expect(int(main.call("_first_actionable_hand_slot", 0)) >= 0, "first ten-minute path keeps the newly bought current-rack card actionable")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_play_card")), "first ten-minute path can submit the second current-rack card")
	_expect(await _wait_for_scenario_signal(main, "followup_card_played"), "first ten-minute path records the successful second local-human queue submission")
	_stage_checkpoint("followup_play_signal_wait_complete")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_inspect_track")), "first ten-minute path can inspect the public card track after both real card submissions")
	await _wait_frames(8)
	var progress_after_track: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(bool(progress_after_track.get("has_seen_public_track", false)), "first ten-minute path records public-track inspection")
	_check_player_facing_privacy(runtime, Vector2i(1600, 960))
	_expect(str(main.call("_first_run_coach_stage", progress_after_track)) == "observe_ai_public_action", "first ten-minute path moves from the public track into a readable AI action")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_observe_ai_public_action")), "first ten-minute path can run an existing legal AI economy action without exposing policy details")
	await _wait_frames(8)
	var progress_after_ai: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(bool(progress_after_ai.get("has_seen_ai_public_action", false)) and str(main.call("_first_run_coach_stage", progress_after_ai)) == "inspect_clues", "first ten-minute path records AI public action and advances to public clues")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_inspect_clues")), "first ten-minute path can inspect public clues without revealing the real owner")
	await _wait_frames(8)
	var progress_after_clues: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(bool(progress_after_clues.get("has_seen_clues", false)) and str(main.call("_first_run_coach_stage", progress_after_clues)) == "inspect_monster_pressure", "first ten-minute path advances from clues to monster pressure")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_inspect_monster_pressure")), "first ten-minute path can focus the real monster pressure layer")
	await _wait_frames(8)
	var progress_after_pressure: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(bool(progress_after_pressure.get("has_seen_monster_pressure", false)) and str(main.call("_first_run_coach_stage", progress_after_pressure)) == "choose_route", "first ten-minute path reaches route choice after reading monster pressure")
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_choose_route_growth")), "first ten-minute path can choose the recommended GDP-growth route from coach")
	await _wait_frames(8)
	var progress_after_route: Dictionary = main.call("_first_run_coach_progress", 0)
	_expect(bool(progress_after_route.get("has_chosen_route", false)) and str(progress_after_route.get("route_choice", "")) == "grow_gdp", "first ten-minute path records the chosen route as runtime state")
	_expect(str(main.call("_first_run_coach_stage", progress_after_route)) == "done", "first ten-minute authored mission summarizes the route choice without ending the whole match")
	_expect(not bool(main.call("_first_run_should_defer_monster_wager")), "first_table releases deferred monster wager flow after the authored route summary")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_first_run_open_rack_recovery() -> void:
	root.size = Vector2i(1600, 960)
	var main := await _instantiate_main()
	if main == null:
		return
	main.call("_new_game")
	await _wait_frames(12)
	main.set("selected_district", -1)
	main.set("district_supply_open_district", -1)
	main.set("district_supply_open_player", -1)
	_expect(bool(main.call("_activate_first_run_coach_action", "coach_open_rack")), "first-run CTA can auto-select a recommended region before opening the rack")
	await _wait_frames(8)
	var selected := int(main.get("selected_district"))
	var open_district := int(main.get("district_supply_open_district"))
	var open_player := int(main.get("district_supply_open_player"))
	_expect(selected >= 0 and open_district == selected and open_player == 0, "first-run rack CTA lands on the selected recommended region for the local player selected=%d open=%d player=%d" % [selected, open_district, open_player])
	_expect_first_run_focus_pulse(main, "district_supply", "牌架", "first-run rack CTA enters a strong focus state on the opened card rack")
	await _expect_runtime_map_centered_on_district(main, open_district, "first-run rack CTA rotates the central planet to the opened region")
	root.remove_child(main)
	main.queue_free()
	await _wait_frames(1)


func _check_first_run_buy_recovery() -> void:
	root.size = Vector2i(1600, 960)
	var buy_main := await _instantiate_main()
	if buy_main == null:
		return
	buy_main.call("_new_game")
	await _wait_frames(12)
	var coordinator := buy_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	_expect(coordinator != null, "first-run Buy CTA uses the production RegionSupply coordinator")
	if coordinator == null:
		root.remove_child(buy_main)
		buy_main.queue_free()
		await _wait_frames(1)
		return
	var expected_choice := _find_purchasable_region_supply_choice(buy_main, coordinator)
	_expect(not expected_choice.is_empty(), "first-run Buy CTA has one current public rack listing with a legal quote state")
	if expected_choice.is_empty():
		root.remove_child(buy_main)
		buy_main.queue_free()
		await _wait_frames(1)
		return
	var wrong_district := _first_non_buyable_district(buy_main)
	_expect(wrong_district >= 0, "first-run Buy CTA fixture contains a public rack that is currently browse-only")
	if wrong_district >= 0:
		var expected_district := int(expected_choice.get("district_index", -1))
		var expected_listing: Dictionary = expected_choice.get("listing", {}) if expected_choice.get("listing", {}) is Dictionary else {}
		var expected_region_id := str(expected_listing.get("source_region_id", ""))
		var rack_before: Dictionary = coordinator.call(
			"region_supply_public_rack",
			expected_region_id
		)
		buy_main.set("selected_district", wrong_district)
		buy_main.set("district_supply_open_district", -1)
		buy_main.set("district_supply_open_player", -1)
		var hand_before := _local_hand_size(buy_main)
		var purchase_count_before := _local_card_purchase_count(buy_main)
		var recovery_requested := bool(buy_main.call("_activate_first_run_coach_action", "coach_buy_card"))
		_expect(recovery_requested, "first-run Buy CTA can recover from a browse-only selected region")
		if not recovery_requested:
			print(
				"COMMERCIAL_GATE_BUY_RECOVERY_DIAG|wrong=%d|expected=%s|fallback=%d|expected_target=%s|expected_card=%s|logs=%s"
				% [
					wrong_district,
					JSON.stringify(expected_choice),
					int(buy_main.call("_first_buyable_district_for_player", 0)),
					JSON.stringify(
						buy_main.call(
							"_first_run_coach_rack_purchase_target",
							0,
							expected_district
						)
					),
					str(
						buy_main.call(
							"_first_buyable_district_card",
							expected_district,
							0
						)
					),
					JSON.stringify(buy_main.get("log_lines")),
				]
			)
			_stage_checkpoint("cta_buy_recovery_rejected")
			root.remove_child(buy_main)
			buy_main.queue_free()
			await _wait_frames(1)
			return
		await _wait_frames(12)
		var selected_after := int(buy_main.get("selected_district"))
		var rack_after: Dictionary = coordinator.call("region_supply_public_rack", expected_region_id)
		_expect(
			selected_after == expected_district
				and _local_card_purchase_count(buy_main) == purchase_count_before + 1,
			"first-run Buy CTA rotates to a legal public listing and completes one production purchase",
		)
		_expect(
			_changed_region_supply_slot_count(
				rack_before,
				rack_after
			) == 1,
			"first-run Buy CTA consumes and refills only the selected public RegionSupply slot",
		)
		await _expect_runtime_map_centered_on_district(buy_main, expected_district, "first-run Buy CTA rotates the central planet to the purchased listing")
		_expect_first_run_focus_pulse(buy_main, "player_hand", "手牌", "first-run Buy CTA pulses the resulting hand")
		_expect(_local_hand_size(buy_main) >= hand_before, "first-run Buy CTA does not lose local hand cards while recovering from the wrong region")
	root.remove_child(buy_main)
	buy_main.queue_free()
	await _wait_frames(1)


func _expect_first_run_focus_pulse(main: Node, expected_target: String, label_hint: String, message: String) -> void:
	var focus_layer := _find_node_with_method(main, "get_focus_debug_snapshot")
	_expect(focus_layer != null, "%s has a FocusGuideLayer debug snapshot" % message)
	if focus_layer == null:
		return
	var snapshot_variant: Variant = focus_layer.call("get_focus_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var label := str(snapshot.get("label", ""))
	_expect(bool(snapshot.get("visible", false)), "%s is visible" % message)
	_expect(bool(snapshot.get("pulse_focus", false)), "%s pulses the target frame" % message)
	_expect(str(snapshot.get("focus_target", "")) == expected_target, "%s targets %s" % [message, expected_target])
	_expect(label.contains("最短") and label.contains(label_hint), "%s uses shortest-action copy instead of long help text" % message)


func _instantiate_main() -> Node:
	var main_script := load(MAIN_SCRIPT_PATH) as Script
	_expect(main_script != null and main_script.can_instantiate(), "main.gd and its current dependencies compile for the commercial gate")
	if main_script == null or not main_script.can_instantiate():
		return null
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "main.tscn loads for commercial playability gate")
	if packed == null:
		return null
	var main := packed.instantiate()
	_expect(main.get_script() != null and main.has_method("_new_game"), "main.tscn instantiates the real scripted Main runtime")
	if main.get_script() == null or not main.has_method("_new_game"):
		main.free()
		return null
	var save := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator")
	_expect(save != null and bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "commercial gate installs an isolated QA run-save path before Main enters the tree")
	var rng_variant: Variant = main.get("rng")
	if rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).seed = FIXED_SEED
	root.add_child(main)
	await _wait_frames(8)
	rng_variant = main.get("rng")
	if rng_variant is RandomNumberGenerator:
		(rng_variant as RandomNumberGenerator).seed = FIXED_SEED
	main.set("campaign_completed_chapter_ids", [])
	main.set("selected_campaign_chapter_id", "")
	main.set("active_campaign_chapter_id", "")
	return main


func _first_non_buyable_district(main: Node) -> int:
	var districts: Array = main.get("districts") as Array
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator")
	if coordinator == null:
		return -1
	for i in range(districts.size()):
		if bool((districts[i] as Dictionary).get("destroyed", false)):
			continue
		var region_id := str((districts[i] as Dictionary).get("region_id", "region.%03d" % i))
		var rack: Dictionary = coordinator.call("region_supply_public_rack", region_id)
		if _region_supply_slots(rack).is_empty():
			continue
		var availability: Dictionary = coordinator.call("card_market_listing_availability", i)
		if not bool(availability.get("purchasable", false)):
			return i
	return -1


func _find_purchasable_region_supply_choice(main: Node, coordinator: Node) -> Dictionary:
	var players: Array = main.get("players") as Array
	if players.is_empty() or not (players[0] is Dictionary):
		return {}
	var actor_id := _actor_id(players, 0)
	var player: Dictionary = coordinator.call("v06_card_player_snapshot", actor_id)
	var available_cash := int(player.get("cash", (players[0] as Dictionary).get("cash", 0)))
	var districts: Array = main.get("districts") as Array
	for district_index in range(districts.size()):
		if not (districts[district_index] is Dictionary) or bool((districts[district_index] as Dictionary).get("destroyed", false)):
			continue
		var availability: Dictionary = coordinator.call("card_market_listing_availability", district_index)
		if not bool(availability.get("purchasable", false)):
			continue
		var region_id := str((districts[district_index] as Dictionary).get("region_id", "region.%03d" % district_index))
		var rack: Dictionary = coordinator.call("region_supply_public_rack", region_id)
		for listing_variant in _region_supply_slots(rack):
			if not (listing_variant is Dictionary):
				continue
			var listing: Dictionary = listing_variant
			var card_id := str(listing.get("card_id", ""))
			var preview_variant: Variant = main.call("_card_market_preview", card_id, district_index)
			var preview: Dictionary = preview_variant if preview_variant is Dictionary else {}
			if bool(preview.get("purchasable", preview.get("eligible", false))) \
					and int(preview.get("final_price", -1)) >= 0 \
					and int(preview.get("final_price", -1)) <= available_cash:
				return {
					"actor_id": actor_id,
					"district_index": district_index,
					"listing": listing.duplicate(true),
				}
	return {}


func _region_supply_slots(snapshot: Dictionary) -> Array:
	var regions: Array = snapshot.get("regions", []) if snapshot.get("regions", []) is Array else []
	if regions.is_empty() or not (regions[0] is Dictionary):
		return []
	return ((regions[0] as Dictionary).get("slots", []) as Array).duplicate(true) \
		if (regions[0] as Dictionary).get("slots", []) is Array else []


func _region_supply_slot(snapshot: Dictionary, slot_index: int) -> Dictionary:
	var slots := _region_supply_slots(snapshot)
	if slot_index < 0 or slot_index >= slots.size() or not (slots[slot_index] is Dictionary):
		return {}
	return (slots[slot_index] as Dictionary).duplicate(true)


func _changed_region_supply_slot_count(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary
) -> int:
	var before_slots := _region_supply_slots(before_snapshot)
	var after_slots := _region_supply_slots(after_snapshot)
	if before_slots.size() != after_slots.size():
		return maxi(before_slots.size(), after_slots.size())
	var changed := 0
	for slot_index in range(before_slots.size()):
		var before_item := (
			str((before_slots[slot_index] as Dictionary).get("item_id", ""))
			if before_slots[slot_index] is Dictionary
			else ""
		)
		var after_item := (
			str((after_slots[slot_index] as Dictionary).get("item_id", ""))
			if after_slots[slot_index] is Dictionary
			else ""
		)
		if before_item != after_item:
			changed += 1
	return changed


func _is_stable_v06_card_id(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var allowed := "abcdefghijklmnopqrstuvwxyz0123456789._-"
	for index in range(card_id.length()):
		if not allowed.contains(card_id.substr(index, 1)):
			return false
	return true


func _local_hand_size(main: Node) -> int:
	var players: Array = main.get("players") as Array
	if players.is_empty() or not (players[0] is Dictionary):
		return 0
	return ((players[0] as Dictionary).get("slots", []) as Array).size()


func _local_card_purchase_count(main: Node) -> int:
	var players: Array = main.get("players") as Array
	if players.is_empty() or not (players[0] is Dictionary):
		return 0
	return int((players[0] as Dictionary).get("card_purchase_count", 0))


func _wait_for_local_card_purchase(main: Node, count_before: int, max_frames: int = 180) -> bool:
	for _frame_index in range(maxi(1, max_frames)):
		if _local_card_purchase_count(main) > count_before:
			return true
		if _frame_index > 0 and _frame_index % 60 == 0:
			_stage_wait_heartbeat("local_card_purchase", _frame_index, max_frames)
		await process_frame
	return false


func _wait_for_first_table_facility(main: Node, max_frames: int = 480) -> bool:
	for _frame_index in range(maxi(1, max_frames)):
		var content_variant: Variant = main.call("_first_table_runtime_content_snapshot", 0)
		var content: Dictionary = content_variant if content_variant is Dictionary else {}
		var owned_facilities: Array = content.get("owned_facilities", []) if content.get("owned_facilities", []) is Array else []
		var signals: Dictionary = _runtime_scenario_state(main).get("completed_signals", {})
		if bool(content.get("city_present", false)) and not owned_facilities.is_empty() and bool(signals.get("public_facility_committed", false)):
			return true
		if main.has_method("_update_card_resolution_queue"):
			main.call("_update_card_resolution_queue", 0.5)
		if _frame_index > 0 and _frame_index % 60 == 0:
			_stage_wait_heartbeat("first_table_facility", _frame_index, max_frames)
		await process_frame
	return false


func _wait_for_scenario_signal(main: Node, signal_id: String, max_frames: int = 180) -> bool:
	for _frame_index in range(maxi(1, max_frames)):
		var signals: Dictionary = _runtime_scenario_state(main).get("completed_signals", {})
		if bool(signals.get(signal_id, false)):
			return true
		if _frame_index > 0 and _frame_index % 60 == 0:
			_stage_wait_heartbeat("scenario_signal:%s" % signal_id, _frame_index, max_frames)
		await process_frame
	return false


func _drain_card_resolution(main: Node, frame_count: int = 24) -> void:
	for _frame_index in range(maxi(1, frame_count)):
		if _card_resolution_queue_idle(main):
			return
		if main.has_method("_update_card_resolution_queue"):
			main.call("_update_card_resolution_queue", 0.5)
		if _frame_index > 0 and _frame_index % 60 == 0:
			_stage_wait_heartbeat("card_resolution_drain", _frame_index, frame_count)
		await process_frame


func _card_resolution_queue_idle(main: Node) -> bool:
	var active: Variant = main.get("active_card_resolution")
	var queue: Variant = main.get("card_resolution_queue")
	var next_queue: Variant = main.get("next_card_resolution_queue")
	return (not (active is Dictionary) or (active as Dictionary).is_empty()) \
		and (not (queue is Array) or (queue as Array).is_empty()) \
		and (not (next_queue is Array) or (next_queue as Array).is_empty()) \
		and not bool(main.get("card_resolution_batch_locked"))


func _new_dictionary_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_variant in after.keys():
		var key := str(key_variant)
		if not before.has(key):
			result.append(key)
	result.sort()
	return result


func _monster_terminal_finalized(journal: Dictionary, transaction_id: String) -> bool:
	var terminal: Dictionary = journal.get(transaction_id, {}) if journal.get(transaction_id, {}) is Dictionary else {}
	var receipt: Dictionary = terminal.get("receipt", {}) if terminal.get("receipt", {}) is Dictionary else {}
	return str(terminal.get("stage", "")) == "finalized" and bool(receipt.get("finalized", false))


func _find_v06_card_slot(player: Dictionary, card_id: String) -> int:
	var inventory: Dictionary = player.get("inventory", {}) if player.get("inventory", {}) is Dictionary else {}
	var slots: Array = inventory.get("slots", []) if inventory.get("slots", []) is Array else []
	for slot_index in range(slots.size()):
		if not (slots[slot_index] is Dictionary):
			continue
		var slot: Dictionary = slots[slot_index]
		var machine: Dictionary = slot.get("machine", {}) if slot.get("machine", {}) is Dictionary else {}
		if str(machine.get("card_id", "")) == card_id:
			return slot_index
	return -1


func _selected_region_id(main: Node) -> String:
	var districts: Array = main.get("districts") as Array
	var district_index := int(main.get("selected_district"))
	if district_index < 0 or district_index >= districts.size() or not (districts[district_index] is Dictionary):
		return ""
	return str((districts[district_index] as Dictionary).get("region_id", "")).strip_edges()


func _actor_id(players: Array, player_index: int) -> String:
	if player_index < 0 or player_index >= players.size() or not (players[player_index] is Dictionary):
		return ""
	var configured := str((players[player_index] as Dictionary).get("actor_id", "")).strip_edges()
	return configured if not configured.is_empty() else "player.%d" % player_index


func _expect_runtime_map_centered_on_district(main: Node, district_index: int, message: String) -> void:
	var map_node := _find_node_with_method(main, "get_projection_debug_snapshot")
	_expect(map_node != null, "%s has a runtime MapView debug snapshot" % message)
	if map_node == null or district_index < 0:
		return
	var districts: Array = main.get("districts") as Array
	if district_index >= districts.size() or not (districts[district_index] is Dictionary):
		_expect(false, "%s has a valid target district" % message)
		return
	var snapshot_variant: Variant = map_node.call("get_projection_debug_snapshot")
	var snapshot: Dictionary = snapshot_variant if snapshot_variant is Dictionary else {}
	var center: Vector2 = snapshot.get("view_center_m", Vector2(-999999.0, -999999.0))
	var target: Vector2 = (districts[district_index] as Dictionary).get("center", Vector2.ZERO)
	var focus_target: Vector2 = snapshot.get("focus_target_center_m", Vector2(-999999.0, -999999.0))
	_expect(int(snapshot.get("focus_target_district", -1)) == district_index, "%s records the target district for a visible planet rotation" % message)
	_expect(focus_target.distance_to(target) <= 1.0, "%s records the target region center before the rotation finishes" % message)
	if center.distance_to(target) > 1.0:
		_expect(bool(snapshot.get("focus_rotation_active", false)), "%s starts an animated planet rotation instead of silently jumping" % message)
	for _frame in range(180):
		await process_frame
		snapshot_variant = map_node.call("get_projection_debug_snapshot")
		snapshot = snapshot_variant if snapshot_variant is Dictionary else {}
		center = snapshot.get("view_center_m", Vector2(-999999.0, -999999.0))
		if center.distance_to(target) <= 1.0 and not bool(snapshot.get("focus_rotation_active", false)):
			break
	snapshot_variant = map_node.call("get_projection_debug_snapshot")
	snapshot = snapshot_variant if snapshot_variant is Dictionary else {}
	center = snapshot.get("view_center_m", Vector2(-999999.0, -999999.0))
	_expect(center.distance_to(target) <= 1.0, message)
	_expect(not bool(snapshot.get("focus_rotation_active", false)), "%s finishes the region rotation" % message)


func _find_node_with_method(node: Node, method_name: String) -> Node:
	if node == null:
		return null
	if node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null


func _check_core_table_regions(main: Node, runtime: Control, viewport_size: Vector2i) -> void:
	var label := _size_label(viewport_size)
	var top_bar := _control(main, "TopBar")
	var public_track := _control(main, "PublicTrack")
	var planet_board := _control(main, "PlanetBoard")
	var stage := _control(main, "PlanetStageViewport")
	var map_host := _control(main, "MapHost")
	var inspector := _control(main, "RightInspector")
	var player_board := _control(main, "PlayerBoard")
	var hand_rack := _control(main, "HandRack")
	var action_dock := _control(main, "PlayerMainActionDock")
	for pair in [
		["TopBar", top_bar],
		["PublicTrack", public_track],
		["PlanetBoard", planet_board],
		["PlanetStageViewport", stage],
		["MapHost", map_host],
		["RightInspector", inspector],
		["PlayerBoard", player_board],
		["HandRack", hand_rack],
		["PlayerMainActionDock", action_dock],
	]:
		_expect(pair[1] != null and (pair[1] as Control).is_visible_in_tree(), "%s %s is visible on the live table" % [label, pair[0]])
	if planet_board == null or public_track == null or player_board == null or stage == null or map_host == null:
		return
	var runtime_rect := runtime.get_global_rect()
	var track_rect := public_track.get_global_rect()
	var planet_rect := planet_board.get_global_rect()
	var stage_rect := stage.get_global_rect()
	var map_rect := map_host.get_global_rect()
	var player_rect := player_board.get_global_rect()
	_expect(_rect_inside(public_track, runtime_rect), "%s public track stays inside the table safe area" % label)
	_expect(_rect_inside(planet_board, runtime_rect), "%s planet board stays inside the table safe area" % label)
	_expect(_rect_inside(player_board, runtime_rect), "%s player board stays inside the table safe area" % label)
	_expect(track_rect.size.y <= float(viewport_size.y) * 0.085, "%s card/event timeline remains a thin table rail" % label)
	_expect(player_rect.size.y >= 168.0 and player_rect.size.y <= float(viewport_size.y) * 0.34, "%s hand/action board is visible but does not consume the table" % label)
	_expect(planet_rect.size.y >= float(viewport_size.y) * 0.38, "%s planet board keeps the main visual weight" % label)
	_expect(stage_rect.size.y >= float(viewport_size.y) * 0.30, "%s planet stage has playable vertical space" % label)
	_expect(map_rect.size.x >= minf(stage_rect.size.x, stage_rect.size.y) * 0.62 and map_rect.size.y >= minf(stage_rect.size.x, stage_rect.size.y) * 0.62, "%s globe/map remains prominent inside the planet stage" % label)
	_expect(not track_rect.intersects(player_rect), "%s timeline does not overlap the hand board" % label)
	_expect(not planet_rect.intersects(player_rect), "%s planet board does not overlap the hand board" % label)
	if inspector != null:
		_expect(inspector.get_global_rect().size.x <= 330.0, "%s campaign focus keeps the right detail drawer compact" % label)


func _check_runtime_focus_order(runtime: Control, expected_labels: Array[String], message: String) -> void:
	_expect(runtime != null and runtime.has_method("runtime_focus_order_snapshot"), "%s exposes runtime focus-order snapshot" % message)
	if runtime == null or not runtime.has_method("runtime_focus_order_snapshot"):
		return
	var snapshot: Array = runtime.call("runtime_focus_order_snapshot")
	_expect(snapshot.size() == expected_labels.size(), "%s has exactly the expected table focus regions" % message)
	var seen := {}
	for index in range(expected_labels.size()):
		var item: Dictionary = snapshot[index] if index < snapshot.size() and snapshot[index] is Dictionary else {}
		var label := str(item.get("label", ""))
		_expect(label == expected_labels[index], "%s focus slot %d is %s" % [message, index + 1, expected_labels[index]])
		_expect(not seen.has(label), "%s focus slot %d is not duplicated" % [message, index + 1])
		seen[label] = true
		_expect(int(item.get("index", -1)) == index, "%s focus slot %d keeps a stable index" % [message, index + 1])
		_expect(int(item.get("focus_mode", Control.FOCUS_NONE)) == Control.FOCUS_ALL, "%s focus slot %d is keyboard/gamepad reachable" % [message, index + 1])
		_expect(str(item.get("focus_next", "")) != "" and str(item.get("focus_previous", "")) != "", "%s focus slot %d links next/previous focus" % [message, index + 1])
		_expect(bool(item.get("visible", false)), "%s focus slot %d is visible" % [message, index + 1])


func _check_single_primary_campaign_cta(main: Node, viewport_size: Vector2i) -> void:
	var label := _size_label(viewport_size)
	var coach := _control(main, "ScenarioCoach")
	_expect(coach != null and coach.visible, "%s scenario coach is visible" % label)
	if coach == null:
		return
	var visible_buttons := _visible_buttons(coach)
	_expect(visible_buttons.size() == 1, "%s scenario coach exposes one primary CTA, not a button wall" % label)
	var goal_label := coach.find_child("ScenarioCoachGoal", true, false) as Label
	var primary_button := coach.find_child("ScenarioCoachPrimaryButton", true, false) as Button
	_expect(goal_label != null and goal_label.text.length() > 0 and goal_label.text.length() <= 42, "%s current objective is short enough to read at a glance" % label)
	_expect(primary_button != null and primary_button.text.length() > 0 and primary_button.text.length() <= 10, "%s primary CTA label is short" % label)


func _check_player_facing_privacy(runtime: Control, viewport_size: Vector2i) -> void:
	if runtime == null:
		return
	var label := _size_label(viewport_size)
	var ui_text := _node_text(runtime).to_lower()
	for forbidden in FORBIDDEN_PLAYER_FACING_TOKENS:
		_expect(not ui_text.contains(forbidden.to_lower()), "%s player-facing runtime hides %s" % [label, forbidden])


func _select_recommended_district(main: Node) -> void:
	var district_index := int(main.call("_first_run_recommended_start_district", 0))
	_expect(district_index >= 0, "commercial gate finds a recommended playable district")
	if district_index >= 0:
		main.call("_select_district", district_index)


func _control(root_node: Node, node_name: String) -> Control:
	return root_node.find_child(node_name, true, false) as Control


func _rect_inside(control: Control, parent_rect: Rect2) -> bool:
	if control == null:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= parent_rect.position.x - 1.0 \
		and rect.position.y >= parent_rect.position.y - 1.0 \
		and rect.end.x <= parent_rect.end.x + 1.0 \
		and rect.end.y <= parent_rect.end.y + 1.0


func _visible_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button and (node as Button).is_visible_in_tree():
		result.append(node as Button)
	for child in node.get_children():
		result.append_array(_visible_buttons(child))
	return result


func _node_text(node: Node) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	if node is Label:
		parts.append((node as Label).text)
	if node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		parts.append(_node_text(child))
	return "\n".join(parts)


func _size_label(viewport_size: Vector2i) -> String:
	return "%dx%d" % [viewport_size.x, viewport_size.y]


func _runtime_scenario_state(main: Node) -> Dictionary:
	var coordinator := main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if main != null else null
	var value: Variant = coordinator.call("runtime_scenario_state", float(main.get("game_time"))) if coordinator != null else {}
	return value as Dictionary if value is Dictionary else {}


func _wait_frames(count: int) -> void:
	for _i in range(maxi(1, count)):
		await process_frame


func _stage_checkpoint(checkpoint_id: String) -> void:
	print("COMMERCIAL_GATE_CHECKPOINT|stage=%s|checkpoint=%s|elapsed_ms=%d" % [
		_active_stage_id,
		checkpoint_id,
		Time.get_ticks_msec() - _active_stage_started_msec,
	])


func _stage_wait_heartbeat(wait_id: String, current_frame: int, max_frames: int) -> void:
	print("COMMERCIAL_GATE_WAIT|stage=%s|wait=%s|frame=%d|max_frames=%d|elapsed_ms=%d" % [
		_active_stage_id,
		wait_id,
		current_frame,
		max_frames,
		Time.get_ticks_msec() - _active_stage_started_msec,
	])


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Commercial playability gate passed.")
	else:
		push_error("Commercial playability gate failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
